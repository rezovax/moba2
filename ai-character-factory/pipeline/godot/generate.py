from __future__ import annotations

import json
from pathlib import Path
from typing import Any


def generate_character_scene(project_dir: Path, spec: dict[str, Any], animation_map: dict[str, str]) -> Path:
    character_id = str(spec["id"])
    target_dir = project_dir / "generated" / character_id
    target_dir.mkdir(parents=True, exist_ok=True)
    scene_path = target_dir / f"{character_id}.tscn"
    stats = spec["gameplay"]
    map_literal = json.dumps(animation_map, ensure_ascii=False, separators=(", ", ": "))
    loop_map = {str(name): bool(value.get("loop", False)) for name, value in spec["animations"].items()}
    loop_literal = json.dumps(loop_map, ensure_ascii=False, separators=(", ", ": ")).replace("true", "true").replace("false", "false")
    content = f'''[gd_scene load_steps=4 format=3]\n\n'''
    content += '[ext_resource type="PackedScene" path="res://scenes/hero/HeroBase.tscn" id="1_base"]\n'
    content += f'[ext_resource type="PackedScene" path="res://assets/generated/{character_id}/character.glb" id="2_model"]\n'
    content += '[ext_resource type="Script" path="res://scripts/hero/hero_stats.gd" id="3_stats"]\n\n'
    content += '[sub_resource type="Resource" id="Stats"]\n'
    content += 'script = ExtResource("3_stats")\n'
    content += f'move_speed = {float(stats["move_speed"])}\n'
    content += f'attack_range = {float(stats["attack_range"])}\n'
    content += f'max_health = {float(stats["max_health"])}\n\n'
    content += f'[node name="{character_id}" instance=ExtResource("1_base")]\n'
    content += 'stats = SubResource("Stats")\n\n'
    content += '[node name="Model" parent="VisualRoot" index="0" instance=ExtResource("2_model")]\n\n'
    content += '[node name="AnimationController" parent="." index="7"]\n'
    content += f'animation_map = {map_literal}\n\n'
    content += f'loop_map = {loop_literal}\n\n'
    content += '[editable path="VisualRoot"]\n'
    scene_path.write_text(content, encoding="utf-8")
    (target_dir / "animation_map.json").write_text(
        json.dumps(animation_map, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return scene_path
