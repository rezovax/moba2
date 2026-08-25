#!/usr/bin/env python3
"""Fail the build when production GDScript crosses anti-slop limits."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from gdtoolkit.gd2py import convert_code
from radon.complexity import cc_rank, cc_visit
from radon.visitors import Function

MAX_CYCLOMATIC_COMPLEXITY = 5

FORBIDDEN_PATTERNS: tuple[tuple[re.Pattern[str], str], ...] = (
    (
        re.compile(r"^\s*@warning_ignore(?:_start|_restore)?\b", re.MULTILINE),
        "warning suppression is forbidden; fix the cause",
    ),
    (
        re.compile(r"#\s*gdlint\s*:\s*(?:disable|ignore)\s*=", re.IGNORECASE),
        "gdlint suppression is forbidden; fix the cause",
    ),
    (
        re.compile(r"^\s*pass\s*(?:#.*)?$", re.MULTILINE),
        "placeholder 'pass' is forbidden in production code",
    ),
    (
        re.compile(r"#.*\b(?:TODO|FIXME|HACK|XXX)\b", re.IGNORECASE),
        "unfinished-work markers are forbidden in production code",
    ),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+", type=Path)
    return parser.parse_args()


def find_scripts(paths: list[Path]) -> list[Path]:
    scripts: set[Path] = set()
    for path in paths:
        if path.is_file() and path.suffix == ".gd":
            scripts.add(path)
        elif path.is_dir():
            scripts.update(path.rglob("*.gd"))
        else:
            raise ValueError(f"GDScript path does not exist: {path}")
    return sorted(scripts)


def check_forbidden_patterns(path: Path, source: str) -> list[str]:
    failures: list[str] = []
    for pattern, message in FORBIDDEN_PATTERNS:
        for match in pattern.finditer(source):
            line_number = source.count("\n", 0, match.start()) + 1
            failures.append(f"{path}:{line_number}: {message}")
    return failures


def check_complexity(path: Path, source: str) -> list[str]:
    failures: list[str] = []
    try:
        blocks = cc_visit(convert_code(source))
    except Exception as error:  # gdtoolkit exposes multiple parser exception types.
        return [f"{path}: complexity analysis failed: {error}"]

    for block in blocks:
        if not isinstance(block, Function):
            continue
        if block.complexity > MAX_CYCLOMATIC_COMPLEXITY:
            failures.append(
                f"{path}:{block.lineno}: {block.name} has cyclomatic complexity "
                f"{block.complexity} ({cc_rank(block.complexity)}); maximum is "
                f"{MAX_CYCLOMATIC_COMPLEXITY} (A)"
            )
    return failures


def main() -> int:
    args = parse_args()
    try:
        scripts = find_scripts(args.paths)
    except ValueError as error:
        print(error, file=sys.stderr)
        return 2

    failures: list[str] = []
    for script in scripts:
        source = script.read_text(encoding="utf-8")
        failures.extend(check_forbidden_patterns(script, source))
        failures.extend(check_complexity(script, source))

    if failures:
        print("GDScript anti-slop quality gate failed:", file=sys.stderr)
        for failure in failures:
            print(f"  {failure}", file=sys.stderr)
        return 1

    print(
        f"GDScript anti-slop quality gate passed: {len(scripts)} files, "
        f"complexity <= {MAX_CYCLOMATIC_COMPLEXITY} (A), no suppressions/placeholders."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
