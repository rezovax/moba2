#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

cargo fmt --check
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
cargo build --package moba_godot

uv sync --locked
uv run gdformat --check client/scripts client/tests
uv run gdlint client/scripts client/tests
uv run python tools/check_gdscript_quality.py client/scripts client/tests

while IFS= read -r script_path; do
	(relative_path="${script_path#client/}"; cd client; godot --headless --log-file /tmp/moba2-script-check.log --check-only --script "$relative_path")
done < <(find client -type f -name '*.gd' -not -path 'client/addons/*' -print | sort)

godot --headless --log-file /tmp/moba2-main-check.log --path client --quit-after 2
godot --headless --log-file /tmp/moba2-prediction-test.log --path client --script res://tests/prediction_world_runtime_test.gd

echo "Godot validation and strict anti-slop quality checks passed."
