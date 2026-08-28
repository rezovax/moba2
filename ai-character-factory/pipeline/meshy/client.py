from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


class MeshyError(RuntimeError):
    pass


class MeshyTaskFailed(MeshyError):
    pass


class MeshyClient:
    def __init__(self, api_key: str, base_url: str = "https://api.meshy.ai") -> None:
        if not api_key:
            raise MeshyError("MESHY_API_KEY is missing")
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")

    def get_balance(self) -> dict[str, Any]:
        return self._request("GET", "/openapi/v1/balance")

    def create_text_to_3d(self, prompt: str) -> str:
        payload = {
            "mode": "preview",
            "prompt": prompt,
            "ai_model": "latest",
            "model_type": "lowpoly",
            "pose_mode": "t-pose",
            "target_formats": ["glb"],
        }
        return self._task_id(self._request("POST", "/openapi/v2/text-to-3d", payload))

    def create_text_refine(self, preview_task_id: str, texture_resolution: str) -> str:
        payload = {
            "mode": "refine",
            "preview_task_id": preview_task_id,
            "ai_model": "latest",
            "texture_resolution": texture_resolution,
            "enable_pbr": True,
            "target_formats": ["glb"],
        }
        return self._task_id(self._request("POST", "/openapi/v2/text-to-3d", payload))

    def create_image_to_3d(self, image_url: str) -> str:
        payload = {
            "image_url": image_url,
            "ai_model": "latest",
            "model_type": "lowpoly",
            "pose_mode": "t-pose",
            "target_formats": ["glb"],
        }
        return self._task_id(self._request("POST", "/openapi/v1/image-to-3d", payload))

    def create_multi_image_to_3d(self, image_urls: list[str]) -> str:
        payload = {
            "image_urls": image_urls,
            "ai_model": "latest",
            "model_type": "lowpoly",
            "pose_mode": "t-pose",
            "target_formats": ["glb"],
        }
        return self._task_id(self._request("POST", "/openapi/v1/multi-image-to-3d", payload))

    def create_remesh(self, input_task_id: str, target_polycount: int) -> str:
        payload = {"input_task_id": input_task_id, "target_polycount": target_polycount, "target_formats": ["glb"]}
        return self._task_id(self._request("POST", "/openapi/v1/remesh", payload))

    def create_rig(self, input_task_id: str, height_meters: float) -> str:
        payload = {"input_task_id": input_task_id, "height_meters": height_meters}
        return self._task_id(self._request("POST", "/openapi/v1/rigging", payload))

    def create_rig_from_url(self, model_url: str, height_meters: float) -> str:
        payload = {"model_url": model_url, "height_meters": height_meters}
        return self._task_id(self._request("POST", "/openapi/v1/rigging", payload))

    def create_motion(self, prompt: str, duration: float) -> str:
        payload = {"prompt": prompt, "mode": "swift", "duration": duration}
        return self._task_id(self._request("POST", "/openapi/v1/text-to-motion", payload))

    def create_animation(self, rig_task_id: str, motion_task_id: str) -> str:
        payload = {"rig_task_id": rig_task_id, "motion_task_id": motion_task_id}
        return self._task_id(self._request("POST", "/openapi/v1/animations", payload))

    def wait(self, endpoint: str, task_id: str, timeout: float = 1800, interval: float = 10) -> dict[str, Any]:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            task = self._request("GET", f"{endpoint}/{task_id}")
            status = str(task.get("status", ""))
            if status == "SUCCEEDED":
                return task
            if status in {"FAILED", "CANCELED"}:
                error = task.get("task_error", {}).get("message", "unknown Meshy error")
                raise MeshyTaskFailed(f"Task {task_id} {status}: {error}")
            time.sleep(interval)
        raise MeshyError(f"Task {task_id} timed out after {timeout}s")

    def download(self, url: str, destination: Path) -> None:
        destination.parent.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(url, headers={"User-Agent": "ai-character-factory/0.1"})
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                destination.write_bytes(response.read())
        except (urllib.error.URLError, TimeoutError) as error:
            raise MeshyError(f"Download failed: {error}") from error

    def _request(self, method: str, path: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
        body = json.dumps(payload).encode("utf-8") if payload is not None else None
        headers = {"Authorization": f"Bearer {self.api_key}", "Accept": "application/json"}
        if body is not None:
            headers["Content-Type"] = "application/json"
        request = urllib.request.Request(self.base_url + path, data=body, headers=headers, method=method)
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                result = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise MeshyError(f"Meshy HTTP {error.code}: {detail}") from error
        except (urllib.error.URLError, TimeoutError) as error:
            raise MeshyError(f"Meshy request failed: {error}") from error
        if not isinstance(result, dict):
            raise MeshyError("Meshy returned a non-object response")
        return result

    @staticmethod
    def _task_id(response: dict[str, Any]) -> str:
        task_id = response.get("result")
        if not isinstance(task_id, str) or not task_id:
            raise MeshyError(f"Meshy did not return a task id: {response}")
        return task_id
