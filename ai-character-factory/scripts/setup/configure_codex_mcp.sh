#!/usr/bin/env bash
set -euo pipefail

FACTORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
codex mcp add character-factory-godot -- "${FACTORY_ROOT}/scripts/setup/run_godot_mcp.sh"
codex mcp add meshy -- "${FACTORY_ROOT}/scripts/setup/run_meshy_mcp.sh"
codex mcp list
