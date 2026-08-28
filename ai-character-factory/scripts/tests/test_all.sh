#!/usr/bin/env bash
set -euo pipefail

FACTORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${FACTORY_ROOT}"
python3 -m compileall -q pipeline scripts/tests
python3 scripts/tests/test_blender.py
scripts/tests/test_godot.sh
python3 scripts/tests/test_meshy.py
