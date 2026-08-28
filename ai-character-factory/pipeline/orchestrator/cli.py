from __future__ import annotations

import argparse
from pathlib import Path

from pipeline.orchestrator.runner import CharacterBuild


def main() -> int:
    parser = argparse.ArgumentParser(prog="python -m pipeline.orchestrator")
    subparsers = parser.add_subparsers(dest="command", required=True)
    build_parser = subparsers.add_parser("build", help="build one character")
    build_parser.add_argument("character_spec", type=Path)
    arguments = parser.parse_args()
    if arguments.command == "build":
        return CharacterBuild(arguments.character_spec).run()
    return 2
