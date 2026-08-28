from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import time
import traceback
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Callable

from pipeline.common import ROOT, load_dotenv, read_json, utc_build_stamp, write_json
from pipeline.godot.generate import generate_character_scene
from pipeline.meshy.client import MeshyClient, MeshyError, MeshyTaskFailed
from pipeline.validation.spec import validate_character_spec


class CharacterBuild:
    def __init__(self, spec_path: Path) -> None:
        self.spec_path = spec_path.resolve()
        self.spec: dict[str, Any] = {}
        self.build_dir = ROOT / "builds" / "unknown" / utc_build_stamp()
        self.report: dict[str, Any] = {
            "status": "running",
            "started_at": datetime.now(UTC).isoformat(),
            "stages": {},
            "artifacts": {},
        }

    def run(self) -> int:
        load_dotenv()
        try:
            self.spec = validate_character_spec(self.spec_path)
            self.build_dir = ROOT / "builds" / str(self.spec["id"]) / utc_build_stamp()
            self._create_layout()
            shutil.copy2(self.spec_path, self.build_dir / "source" / "character_spec.json")
            input_model = self._stage("source", self._obtain_source, 1)
            processed = self._stage("blender", lambda: self._run_blender(Path(input_model)), 2)
            scene = self._stage("godot_generate", lambda: self._prepare_godot(Path(processed)), 1)
            self._stage("godot_test", lambda: self._run_godot(Path(scene)), 1)
            self.report["status"] = "pass"
        except Exception as error:
            self.report["status"] = "fail"
            self.report["error"] = str(error)
            self._log("orchestrator_error.log", traceback.format_exc())
        self.report["finished_at"] = datetime.now(UTC).isoformat()
        write_json(self.build_dir / "report.json", self.report)
        print(f"BUILD_{self.report['status'].upper()} {self.build_dir / 'report.json'}")
        return 0 if self.report["status"] == "pass" else 1

    def _create_layout(self) -> None:
        for name in ("source", "generated", "processed", "renders", "godot", "logs"):
            (self.build_dir / name).mkdir(parents=True, exist_ok=True)

    def _stage(self, name: str, operation: Callable[[], Any], attempts: int) -> Any:
        errors: list[str] = []
        for attempt in range(1, attempts + 1):
            try:
                result = operation()
                self.report["stages"][name] = {"status": "pass", "attempt": attempt}
                return result
            except Exception as error:
                errors.append(str(error))
                self._log(f"{name}_attempt_{attempt}.log", traceback.format_exc())
        self.report["stages"][name] = {"status": "fail", "attempts": attempts, "errors": errors}
        raise RuntimeError(f"Stage {name} failed after {attempts} attempts: {errors[-1]}")

    def _obtain_source(self) -> Path:
        source = self.spec["source"]
        if source["mode"] == "fixture":
            fixture = (self.spec_path.parent / str(source["path"])).resolve()
            if not fixture.is_file():
                raise FileNotFoundError(f"Fixture not found: {fixture}")
            destination = self.build_dir / "generated" / f"source{fixture.suffix.lower()}"
            shutil.copy2(fixture, destination)
            self.report["artifacts"]["source_model"] = str(destination)
            self.report["stages"]["meshy"] = {"status": "skipped", "reason": "local no-credit smoke fixture"}
            return destination
        key = os.environ.get("MESHY_API_KEY", "")
        client = MeshyClient(key)
        return self._run_meshy(client)

    def _run_meshy(self, client: MeshyClient) -> Path:
        source = self.spec["source"]
        visual = self.spec["visual"]
        mode = str(source["mode"])
        endpoint = "/openapi/v1/image-to-3d"
        if mode == "meshy_text":
            task_id, task = self._stage(
                "meshy_generation",
                lambda: self._meshy_task(client, "generation", "/openapi/v2/text-to-3d", lambda: client.create_text_to_3d(str(visual["prompt"]))),
                3,
            )
            refine_id, task = self._stage(
                "meshy_texture",
                lambda: self._meshy_task(
                    client, "texture", "/openapi/v2/text-to-3d",
                    lambda: client.create_text_refine(task_id, str(self.spec["model"].get("texture_resolution", "2k"))),
                ),
                3,
            )
            task_id = refine_id
            endpoint = "/openapi/v2/text-to-3d"
        elif mode == "meshy_image":
            task_id, task = self._stage(
                "meshy_generation",
                lambda: self._meshy_task(client, "generation", endpoint, lambda: client.create_image_to_3d(str(source["image_urls"][0]))),
                3,
            )
        else:
            endpoint = "/openapi/v1/multi-image-to-3d"
            task_id, task = self._stage(
                "meshy_generation",
                lambda: self._meshy_task(
                    client, "generation", endpoint,
                    lambda: client.create_multi_image_to_3d([str(url) for url in source["image_urls"]]),
                ),
                3,
            )
        self._save_task("generation", task)
        remesh_id, remesh = self._stage(
            "meshy_remesh",
            lambda: self._meshy_task(
                client, "remesh", "/openapi/v1/remesh",
                lambda: client.create_remesh(task_id, int(self.spec["model"]["triangle_target"])),
            ),
            3,
        )
        self._save_task("remesh", remesh)
        model_url = self._glb_url(remesh)
        rig_id, rig = self._stage(
            "meshy_rig",
            lambda: self._meshy_task(
                client, "rig", "/openapi/v1/rigging",
                lambda: client.create_rig_from_url(model_url, float(visual["height_m"])),
            ),
            3,
        )
        self._save_task("rig", rig)
        animation_map = self._generate_meshy_animations(client, rig_id)
        write_json(self.build_dir / "generated" / "meshy_animation_tasks.json", animation_map)
        rig_url = str(rig["result"]["rigged_character_glb_url"])
        destination = self.build_dir / "generated" / "rigged_character.glb"
        client.download(rig_url, destination)
        self.report["artifacts"]["source_model"] = str(destination)
        self.report["stages"]["meshy"] = {"status": "pass", "endpoint": endpoint}
        return destination

    def _generate_meshy_animations(self, client: MeshyClient, rig_id: str) -> dict[str, Any]:
        results: dict[str, Any] = {}
        for contract, definition in self.spec["animations"].items():
            motion_id, _motion = self._stage(
                f"meshy_motion_{contract}",
                lambda contract=contract, definition=definition: self._meshy_task(
                    client, f"motion_{contract}", "/openapi/v1/text-to-motion",
                    lambda: client.create_motion(str(definition["motion_prompt"]), float(definition.get("duration", 2.0))),
                ),
                3,
            )
            animation_id, task = self._stage(
                f"meshy_animation_{contract}",
                lambda contract=contract, motion_id=motion_id: self._meshy_task(
                    client, f"animation_{contract}", "/openapi/v1/animations",
                    lambda: client.create_animation(rig_id, motion_id),
                ),
                3,
            )
            output = self.build_dir / "generated" / "animations" / f"{contract}.glb"
            client.download(str(task["result"]["animation_glb_url"]), output)
            results[str(contract)] = {"motion_task_id": motion_id, "animation_task_id": animation_id, "path": str(output)}
        return results

    def _run_blender(self, input_model: Path) -> Path:
        blender = self._blender_path()
        output = self.build_dir / "processed" / "processed_character.glb"
        validation = self.build_dir / "processed" / "validation_report.json"
        animation_map = {str(name): str(value.get("source_name", name)) for name, value in self.spec["animations"].items()}
        map_path = self.build_dir / "source" / "animation_map.json"
        write_json(map_path, animation_map)
        command = [
            str(blender), "--background", "-noaudio", "--factory-startup", "--python",
            str(ROOT / "pipeline" / "blender" / "process_character.py"), "--", str(input_model),
            "--output", str(output), "--validation", str(validation), "--renders", str(self.build_dir / "renders"),
            "--height", str(self.spec["visual"]["height_m"]), "--animation-map", str(map_path),
            "--triangle-target", str(self.spec["model"]["triangle_target"]),
        ]
        if bool(self.spec["model"]["require_textures"]):
            command.append("--require-textures")
        manifest_path = self.build_dir / "generated" / "meshy_animation_tasks.json"
        if manifest_path.is_file():
            tasks = read_json(manifest_path)
            clip_paths = {name: str(value["path"]) for name, value in tasks.items()}
            clip_manifest = self.build_dir / "source" / "animation_files.json"
            write_json(clip_manifest, clip_paths)
            command.extend(["--animation-manifest", str(clip_manifest)])
        output_text = self._command(command, "blender.log", 300)
        if "BLENDER_PIPELINE_" not in output_text or not validation.is_file():
            raise RuntimeError("Blender script did not produce its completion marker and validation report")
        report = read_json(validation)
        if report["status"] != "pass":
            raise RuntimeError(f"Blender validation failed: {report['retry']}")
        self.report["artifacts"].update({"processed_glb": str(output), "validation": str(validation)})
        return output

    def _prepare_godot(self, processed: Path) -> Path:
        project = ROOT / "godot_project"
        character_id = str(self.spec["id"])
        asset_dir = project / "assets" / "generated" / character_id
        asset_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(processed, asset_dir / "character.glb")
        animation_map = {str(name): str(value.get("source_name", name)) for name, value in self.spec["animations"].items()}
        scene = generate_character_scene(project, self.spec, animation_map)
        shutil.copy2(scene, self.build_dir / "godot" / scene.name)
        self.report["artifacts"]["godot_scene"] = str(scene)
        return scene

    def _run_godot(self, scene: Path) -> bool:
        godot = os.environ.get("GODOT_PATH", "godot")
        project = ROOT / "godot_project"
        environment = os.environ.copy()
        environment["XDG_DATA_HOME"] = str(self.build_dir / "godot" / "xdg_data")
        environment["XDG_CONFIG_HOME"] = str(self.build_dir / "godot" / "xdg_config")
        self._command(
            [godot, "--headless", "--path", str(project), "--import"],
            "godot_import.log", 120, environment,
        )
        relative_scene = "res://" + scene.relative_to(project).as_posix()
        environment["FACTORY_HERO_SCENE"] = relative_scene
        environment.pop("FACTORY_CAPTURE_DIR", None)
        output = self._command(
            [godot, "--headless", "--path", str(project), "--scene", "res://tests/CharacterTestArena.tscn"],
            "godot_test.log", 90, environment,
        )
        if "CHARACTER_TEST_PASS" not in output:
            raise RuntimeError("Godot test did not emit CHARACTER_TEST_PASS")
        if "SCRIPT ERROR" in output or "ERROR:" in output:
            raise RuntimeError("Godot headless test emitted errors")
        self._run_godot_visual(project, relative_scene, environment)
        return True

    def _run_godot_visual(self, project: Path, relative_scene: str, environment: dict[str, str]) -> None:
        xvfb = shutil.which("Xvfb")
        if xvfb is None:
            self.report["stages"]["godot_screenshots"] = {"status": "skipped", "reason": "Xvfb unavailable"}
            return
        display = self._free_display()
        xvfb_log = self.build_dir / "logs" / "xvfb.log"
        with xvfb_log.open("w", encoding="utf-8") as log_file:
            server = subprocess.Popen(
                [xvfb, display, "-screen", "0", "960x540x24", "-nolisten", "tcp"],
                stdout=log_file, stderr=subprocess.STDOUT, text=True,
            )
            try:
                time.sleep(0.4)
                visual_env = environment.copy()
                visual_env["DISPLAY"] = display
                visual_env["FACTORY_HERO_SCENE"] = relative_scene
                visual_env["FACTORY_CAPTURE_DIR"] = str(self.build_dir / "renders")
                output = self._command(
                    ["godot", "--path", str(project), "--rendering-method", "gl_compatibility",
                     "--scene", "res://tests/CharacterTestArena.tscn"],
                    "godot_visual_test.log", 90, visual_env,
                )
                if "CHARACTER_TEST_PASS" not in output or "SCRIPT ERROR" in output or "ERROR:" in output:
                    raise RuntimeError("Godot visual test failed or emitted errors")
                captures = sorted((self.build_dir / "renders").glob("godot_*.png"))
                if len(captures) != 6:
                    raise RuntimeError(f"Expected 6 Godot captures, found {len(captures)}")
                self.report["stages"]["godot_screenshots"] = {"status": "pass", "count": len(captures)}
            finally:
                server.terminate()
                server.wait(timeout=5)

    @staticmethod
    def _free_display() -> str:
        for number in range(90, 120):
            if not Path(f"/tmp/.X11-unix/X{number}").exists():
                return f":{number}"
        raise RuntimeError("No free X11 display number")

    def _command(self, command: list[str], log_name: str, timeout: int, env: dict[str, str] | None = None) -> str:
        completed = subprocess.run(command, cwd=ROOT, env=env, text=True, capture_output=True, timeout=timeout, check=False)
        output = completed.stdout + completed.stderr
        self._log(log_name, "$ " + " ".join(command) + "\n" + output)
        if completed.returncode != 0:
            raise RuntimeError(f"Command failed ({completed.returncode}): {' '.join(command)}")
        return output

    def _blender_path(self) -> Path:
        configured = os.environ.get("BLENDER_PATH", "")
        candidates = [Path(configured)] if configured else []
        candidates.append(ROOT / "tools" / "blender" / "current" / "blender")
        system = shutil.which("blender")
        if system:
            candidates.append(Path(system))
        for candidate in candidates:
            if candidate.is_file() and os.access(candidate, os.X_OK):
                return candidate
        raise FileNotFoundError("Blender not found; run scripts/setup/install_blender.sh")

    def _save_task(self, name: str, task: dict[str, Any]) -> None:
        write_json(self.build_dir / "generated" / f"meshy_{name}.json", task)

    def _meshy_task(
        self,
        client: MeshyClient,
        name: str,
        endpoint: str,
        create: Callable[[], str],
    ) -> tuple[str, dict[str, Any]]:
        state_path = self.build_dir / "generated" / f"{name}_state.json"
        state = read_json(state_path) if state_path.is_file() else {}
        task_id = str(state.get("task_id", ""))
        if not task_id or state.get("status") == "failed":
            task_id = create()
            state = {"task_id": task_id, "endpoint": endpoint, "status": "created"}
            write_json(state_path, state)
        try:
            task = client.wait(endpoint, task_id)
        except MeshyTaskFailed as error:
            state["status"] = "failed"
            state["error"] = str(error)
            write_json(state_path, state)
            raise
        state["status"] = "succeeded"
        state["task"] = task
        write_json(state_path, state)
        return task_id, task

    def _log(self, name: str, content: str) -> None:
        path = self.build_dir / "logs" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    @staticmethod
    def _glb_url(task: dict[str, Any]) -> str:
        model_urls = task.get("model_urls") or task.get("result", {}).get("model_urls")
        if not isinstance(model_urls, dict) or not isinstance(model_urls.get("glb"), str):
            raise MeshyError("Meshy task has no GLB URL")
        return str(model_urls["glb"])
