#!/usr/bin/env bash
set -euo pipefail

FACTORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_HOME="$(mktemp -d)"
trap 'rm -rf "${TEST_HOME}"' EXIT
XDG_DATA_HOME="${TEST_HOME}/data" XDG_CONFIG_HOME="${TEST_HOME}/config" \
  godot --headless --path "${FACTORY_ROOT}/godot_project" --editor --quit 2>&1 | tee "${TEST_HOME}/godot.log"
if rg -q 'SCRIPT ERROR|Parse Error|Failed to load script' "${TEST_HOME}/godot.log"; then
  echo "FAIL: Godot parser errors"
  exit 1
fi
echo "PASS: Godot project imported and scripts parsed"
