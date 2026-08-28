from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

import bpy
import bmesh
from mathutils import Vector


def inspect_model() -> dict[str, Any]:
    mesh_data = inspect_mesh()
    return {
        "objects": len(bpy.context.scene.objects),
        "meshes": mesh_data["mesh_count"],
        "materials": inspect_materials(),
        "skeleton": inspect_skeleton(),
        "animations": inspect_animations(),
        "bounds": _bounds_dict(),
    }


def normalize_transform() -> None:
    for obj in _root_objects():
        obj.rotation_euler = (0.0, 0.0, 0.0)


def normalize_scale(target_height: float) -> float:
    bounds = _world_bounds()
    current_height = bounds[1].z - bounds[0].z
    if current_height <= 0.000001:
        raise RuntimeError("Model height is zero")
    factor = target_height / current_height
    for obj in _root_objects():
        obj.location *= factor
        obj.scale *= factor
    bpy.context.view_layer.update()
    return factor


def place_feet_on_ground() -> float:
    minimum_z = _world_bounds()[0].z
    for obj in _root_objects():
        obj.location.z -= minimum_z
    bpy.context.view_layer.update()
    return minimum_z


def inspect_mesh() -> dict[str, int]:
    mesh_objects = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    vertices = sum(len(obj.data.vertices) for obj in mesh_objects)
    triangles = 0
    degenerate_faces = 0
    non_manifold_edges = 0
    for obj in mesh_objects:
        triangles += sum(max(0, len(polygon.vertices) - 2) for polygon in obj.data.polygons)
        degenerate_faces += sum(1 for polygon in obj.data.polygons if polygon.area <= 0.00000001)
        editable_mesh = bmesh.new()
        editable_mesh.from_mesh(obj.data)
        non_manifold_edges += sum(1 for edge in editable_mesh.edges if not edge.is_manifold)
        editable_mesh.free()
    return {
        "mesh_count": len(mesh_objects),
        "vertices": vertices,
        "triangles": triangles,
        "degenerate_faces": degenerate_faces,
        "non_manifold_edges": non_manifold_edges,
    }


def inspect_materials() -> dict[str, int]:
    texture_images: set[str] = set()
    material_count = 0
    for material in bpy.data.materials:
        material_count += 1
        if material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None:
                texture_images.add(node.image.name)
    return {"count": material_count, "texture_images": len(texture_images)}


def inspect_skeleton() -> dict[str, Any]:
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    bone_count = sum(len(obj.data.bones) for obj in armatures)
    return {"present": bool(armatures), "armatures": len(armatures), "bones": bone_count}


def inspect_animations() -> list[dict[str, Any]]:
    fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    result: list[dict[str, Any]] = []
    for action in bpy.data.actions:
        start, end = action.frame_range
        duration = max(0.0, float(end - start) / fps)
        result.append({"name": action.name, "duration_seconds": round(duration, 4)})
    return sorted(result, key=lambda value: str(value["name"]).lower())


def merge_animation_clips(manifest: dict[str, str]) -> None:
    armature = next((obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"), None)
    if armature is None:
        raise RuntimeError("Cannot merge animations without an armature")
    animation_data = armature.animation_data_create()
    for contract_name, file_name in manifest.items():
        objects_before = set(bpy.data.objects)
        actions_before = set(bpy.data.actions)
        _import_model(Path(file_name).resolve())
        new_actions = [action for action in bpy.data.actions if action not in actions_before]
        if not new_actions:
            raise RuntimeError(f"Animation file has no action: {file_name}")
        action = max(new_actions, key=lambda value: float(value.frame_range[1] - value.frame_range[0]))
        action.name = contract_name
        track = animation_data.nla_tracks.new()
        track.name = contract_name
        track.strips.new(contract_name, int(action.frame_range[0]), action)
        for obj in [value for value in bpy.data.objects if value not in objects_before]:
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.context.view_layer.update()


def render_turntable(render_dir: Path, resolution: int) -> list[Path]:
    views = {
        "front": Vector((0.0, -1.0, 0.0)),
        "back": Vector((0.0, 1.0, 0.0)),
        "side": Vector((1.0, 0.0, 0.0)),
    }
    return [_render_view(name, direction, render_dir, resolution, False) for name, direction in views.items()]


def render_moba_view(render_dir: Path, resolution: int) -> Path:
    return _render_view("moba", Vector((0.8, -0.8, 1.0)), render_dir, resolution, True)


def export_glb(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        export_animations=True,
        export_cameras=False,
        export_lights=False,
        export_yup=True,
        export_nla_strips=True,
    )


def validate(
    required_map: dict[str, str],
    target_height: float,
    triangle_target: int,
    require_textures: bool,
) -> dict[str, Any]:
    mesh = inspect_mesh()
    materials = inspect_materials()
    skeleton = inspect_skeleton()
    animations = inspect_animations()
    animation_names = {str(item["name"]).lower() for item in animations}
    minimum, maximum = _world_bounds()
    height = maximum.z - minimum.z
    missing_animations = [contract for contract, source in required_map.items() if source.lower() not in animation_names]
    zero_scale = any(abs(axis) < 0.000001 for obj in bpy.context.scene.objects for axis in obj.scale)
    checks: dict[str, dict[str, Any]] = {
        "readable": _check(True, "model imported"),
        "mesh": _check(mesh["mesh_count"] > 0, mesh),
        "mesh_non_empty": _check(mesh["vertices"] > 0 and mesh["triangles"] > 0, mesh),
        "triangle_count": _check(mesh["triangles"] > 0, mesh["triangles"]),
        "triangle_budget": _check(mesh["triangles"] <= int(triangle_target * 1.25), {"actual": mesh["triangles"], "target": triangle_target}),
        "topology": _check(
            mesh["degenerate_faces"] <= max(5, int(mesh["triangles"] * 0.001)),
            {"degenerate_faces": mesh["degenerate_faces"], "non_manifold_edges": mesh["non_manifold_edges"]},
        ),
        "bounding_box": _check(height > 0.0, _bounds_dict()),
        "height": _check(abs(height - target_height) <= 0.03, round(height, 5)),
        "ground": _check(abs(minimum.z) <= 0.02, round(minimum.z, 5)),
        "materials": _check(materials["count"] > 0, materials),
        "textures": _texture_check(materials["texture_images"], require_textures),
        "skeleton": _check(bool(skeleton["present"]), skeleton),
        "bones": _check(int(skeleton["bones"]) > 0, skeleton["bones"]),
        "zero_scale": _check(not zero_scale, zero_scale),
        "animations": _check(not missing_animations, {"missing": missing_animations, "clips": animations}),
        "animation_durations": _check(all(float(item["duration_seconds"]) > 0 for item in animations), animations),
    }
    hard_failures = [name for name, check in checks.items() if check["status"] == "fail"]
    return {"status": "fail" if hard_failures else "pass", "checks": checks, "retry": _retry_decision(hard_failures)}


def _texture_check(count: int, required: bool) -> dict[str, Any]:
    if count > 0:
        return {"status": "pass", "detail": count}
    if required:
        return {"status": "fail", "detail": "no texture images"}
    return {"status": "warn", "detail": "fixture permits material-only rendering"}


def _retry_decision(failures: list[str]) -> dict[str, Any]:
    meshy_retry = {"mesh", "mesh_non_empty", "textures", "skeleton", "bones", "animations"}
    if any(name in meshy_retry for name in failures):
        return {"action": "retry_upstream_stage", "failed_checks": failures}
    if failures:
        return {"action": "retry_blender_stage", "failed_checks": failures}
    return {"action": "continue", "failed_checks": []}


def _check(condition: bool, detail: Any) -> dict[str, Any]:
    return {"status": "pass" if condition else "fail", "detail": detail}


def _world_bounds() -> tuple[Vector, Vector]:
    points: list[Vector] = []
    for obj in bpy.context.scene.objects:
        if obj.type != "MESH":
            continue
        points.extend(obj.matrix_world @ Vector(corner) for corner in obj.bound_box)
    if not points:
        raise RuntimeError("No mesh bounds available")
    minimum = Vector((min(point.x for point in points), min(point.y for point in points), min(point.z for point in points)))
    maximum = Vector((max(point.x for point in points), max(point.y for point in points), max(point.z for point in points)))
    return minimum, maximum


def _bounds_dict() -> dict[str, Any]:
    minimum, maximum = _world_bounds()
    return {
        "min": [round(value, 5) for value in minimum],
        "max": [round(value, 5) for value in maximum],
        "size": [round(value, 5) for value in maximum - minimum],
    }


def _root_objects() -> list[bpy.types.Object]:
    return [obj for obj in bpy.context.scene.objects if obj.parent is None]


def _reset_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for data_collection in (bpy.data.meshes, bpy.data.armatures, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for block in list(data_collection):
            if block.users == 0:
                data_collection.remove(block)


def _import_model(path: Path) -> None:
    if path.suffix.lower() not in {".glb", ".gltf"}:
        raise RuntimeError(f"Unsupported input format: {path.suffix}")
    result = bpy.ops.import_scene.gltf(filepath=str(path))
    if "FINISHED" not in result:
        raise RuntimeError(f"glTF import failed: {result}")


def _look_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def _prepare_render_scene(resolution: int) -> bpy.types.Object:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = resolution
    scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = False
    scene.world.color = (0.035, 0.045, 0.065)
    camera_data = bpy.data.cameras.get("FactoryCamera") or bpy.data.cameras.new("FactoryCamera")
    camera = bpy.data.objects.get("FactoryCamera") or bpy.data.objects.new("FactoryCamera", camera_data)
    if camera.name not in scene.collection.objects:
        scene.collection.objects.link(camera)
    camera.data.lens = 55
    scene.camera = camera
    if bpy.data.objects.get("FactoryKey") is None:
        light_data = bpy.data.lights.new("FactoryKey", "AREA")
        light_data.energy = 1200
        light_data.shape = "DISK"
        light_data.size = 4.0
        light = bpy.data.objects.new("FactoryKey", light_data)
        scene.collection.objects.link(light)
        light.location = (3.0, -4.0, 6.0)
        _look_at(light, Vector((0.0, 0.0, 1.0)))
    return camera


def _render_view(name: str, direction: Vector, render_dir: Path, resolution: int, moba: bool) -> Path:
    render_dir.mkdir(parents=True, exist_ok=True)
    camera = _prepare_render_scene(resolution)
    minimum, maximum = _world_bounds()
    center = (minimum + maximum) * 0.5
    height = maximum.z - minimum.z
    distance = max(3.2, height * (2.2 if moba else 1.8))
    camera.location = center + direction.normalized() * distance
    if moba:
        camera.location.z = maximum.z + height * 1.3
    _look_at(camera, center + Vector((0.0, 0.0, height * 0.05)))
    output = render_dir / f"{name}.png"
    bpy.context.scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)
    return output


def _arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--validation", type=Path, required=True)
    parser.add_argument("--renders", type=Path, required=True)
    parser.add_argument("--height", type=float, required=True)
    parser.add_argument("--triangle-target", type=int, required=True)
    parser.add_argument("--animation-map", type=Path, required=True)
    parser.add_argument("--animation-manifest", type=Path)
    parser.add_argument("--require-textures", action="store_true")
    parser.add_argument("--resolution", type=int, default=512)
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return parser.parse_args(argv)


def main() -> int:
    args = _arguments()
    _reset_scene()
    _import_model(args.input.resolve())
    required_map = json.loads(args.animation_map.read_text(encoding="utf-8"))
    if args.animation_manifest is not None:
        manifest = json.loads(args.animation_manifest.read_text(encoding="utf-8"))
        merge_animation_clips(manifest)
    initial = inspect_model()
    normalize_transform()
    scale_factor = normalize_scale(args.height)
    ground_offset = place_feet_on_ground()
    report = validate(required_map, args.height, args.triangle_target, args.require_textures)
    report["input"] = str(args.input.resolve())
    report["normalization"] = {"scale_factor": scale_factor, "ground_offset": ground_offset}
    report["before"] = initial
    report["after"] = inspect_model()
    render_turntable(args.renders, args.resolution)
    render_moba_view(args.renders, args.resolution)
    export_glb(args.output)
    args.validation.parent.mkdir(parents=True, exist_ok=True)
    args.validation.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"BLENDER_PIPELINE_{report['status'].upper()} {args.validation}")
    return 0 if report["status"] == "pass" else 2


if __name__ == "__main__":
    raise SystemExit(main())
