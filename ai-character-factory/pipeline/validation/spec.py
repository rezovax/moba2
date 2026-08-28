from __future__ import annotations

import re
from pathlib import Path
from typing import Any

from pipeline.common import ROOT, read_json


REQUIRED_ANIMATIONS = (
    "idle",
    "run",
    "attack_01",
    "hit",
    "death",
    "cast_01",
    "cast_02",
    "cast_03",
    "cast_ultimate",
)


def validate_character_spec(path: Path) -> dict[str, Any]:
    spec = read_json(path)
    schema = read_json(ROOT / "characters" / "character_spec.schema.json")
    _validate_value(spec, schema, schema, "$")
    missing = [name for name in REQUIRED_ANIMATIONS if name not in spec["animations"]]
    if missing:
        raise ValueError(f"Missing animation contract entries: {', '.join(missing)}")
    source = spec["source"]
    if source["mode"] == "fixture" and not source.get("path"):
        raise ValueError("Fixture source requires source.path")
    return spec


def _validate_value(value: Any, schema: dict[str, Any], root: dict[str, Any], path: str) -> None:
    if "$ref" in schema:
        reference = str(schema["$ref"])
        if not reference.startswith("#/"):
            raise ValueError(f"Unsupported schema reference at {path}: {reference}")
        target: Any = root
        for part in reference[2:].split("/"):
            target = target[part]
        _validate_value(value, target, root, path)
        return
    if "const" in schema and value != schema["const"]:
        raise ValueError(f"{path} must equal {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        raise ValueError(f"{path} must be one of {schema['enum']}")
    expected = schema.get("type")
    if expected is not None and not _matches_type(value, str(expected)):
        raise ValueError(f"{path} must be {expected}")
    if isinstance(value, dict):
        _validate_object(value, schema, root, path)
    elif isinstance(value, list):
        _validate_array(value, schema, root, path)
    elif isinstance(value, str):
        _validate_string(value, schema, path)
    elif isinstance(value, (int, float)) and not isinstance(value, bool):
        _validate_number(float(value), schema, path)


def _validate_object(value: dict[str, Any], schema: dict[str, Any], root: dict[str, Any], path: str) -> None:
    missing = [str(key) for key in schema.get("required", []) if key not in value]
    if missing:
        raise ValueError(f"{path} missing required fields: {', '.join(missing)}")
    properties = schema.get("properties", {})
    additional = schema.get("additionalProperties", True)
    for key, child in value.items():
        child_schema = properties.get(key)
        if child_schema is None:
            if additional is False:
                raise ValueError(f"{path}.{key} is not allowed")
            if isinstance(additional, dict):
                _validate_value(child, additional, root, f"{path}.{key}")
            continue
        _validate_value(child, child_schema, root, f"{path}.{key}")


def _validate_array(value: list[Any], schema: dict[str, Any], root: dict[str, Any], path: str) -> None:
    if len(value) < int(schema.get("minItems", 0)):
        raise ValueError(f"{path} has too few items")
    if "maxItems" in schema and len(value) > int(schema["maxItems"]):
        raise ValueError(f"{path} has too many items")
    item_schema = schema.get("items")
    if isinstance(item_schema, dict):
        for index, item in enumerate(value):
            _validate_value(item, item_schema, root, f"{path}[{index}]")


def _validate_string(value: str, schema: dict[str, Any], path: str) -> None:
    if len(value) < int(schema.get("minLength", 0)):
        raise ValueError(f"{path} is too short")
    if "maxLength" in schema and len(value) > int(schema["maxLength"]):
        raise ValueError(f"{path} is too long")
    if "pattern" in schema and re.fullmatch(str(schema["pattern"]), value) is None:
        raise ValueError(f"{path} does not match {schema['pattern']}")


def _validate_number(value: float, schema: dict[str, Any], path: str) -> None:
    if "minimum" in schema and value < float(schema["minimum"]):
        raise ValueError(f"{path} is below minimum")
    if "maximum" in schema and value > float(schema["maximum"]):
        raise ValueError(f"{path} is above maximum")
    if "exclusiveMinimum" in schema and value <= float(schema["exclusiveMinimum"]):
        raise ValueError(f"{path} must be greater than {schema['exclusiveMinimum']}")


def _matches_type(value: Any, expected: str) -> bool:
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "boolean":
        return isinstance(value, bool)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    return False
