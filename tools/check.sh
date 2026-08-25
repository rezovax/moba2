#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

uv sync --locked
uv run gdformat --check client/scripts
uv run gdlint client/scripts
uv run python tools/check_gdscript_quality.py client/scripts

while IFS= read -r script_path; do
	(relative_path="${script_path#client/}"; cd client; godot --headless --check-only --script "$relative_path")
done < <(find client -type f -name '*.gd' -not -path 'client/addons/*' -print | sort)

godot --headless --path client --quit-after 2

echo "Godot validation and strict anti-slop quality checks passed."
