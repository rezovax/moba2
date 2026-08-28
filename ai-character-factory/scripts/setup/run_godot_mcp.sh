#!/usr/bin/env bash
set -euo pipefail

FACTORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export GODOT_PATH="${GODOT_PATH:-godot}"
exec npx -y @yanhuifair/godot-mcp@1.11.2 -p "${FACTORY_ROOT}/godot_project"
