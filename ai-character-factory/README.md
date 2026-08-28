# AI Character Factory V1

CLI-first character production pipeline for Meshy → Blender → Godot 4. No manual Blender or
Godot Editor work is required.

## One-command build

From this directory:

```bash
python3 -m pipeline.orchestrator build characters/test_hero/character_spec.json
```

The included `test_hero` is a no-credit CC0 smoke fixture. A spec whose `source.mode` starts
with `meshy_` performs real paid Meshy calls, resumes/retries only the failed stage, merges all
animation GLBs in Blender, imports the result into Godot, creates the hero scene, runs the arena,
and writes a build report.

Builds are stored under `builds/<character-id>/<UTC timestamp>/` with source, generated,
processed, renders, Godot artifacts, logs, and `report.json`.

## First setup

Blender and both MCP launchers are already configured in this checkout. On a fresh machine:

```bash
scripts/setup/install_blender.sh
scripts/setup/configure_codex_mcp.sh
```

For Meshy, copy `.env.example` to `.env` and set `MESHY_API_KEY`. Verify authentication without
spending generation credits:

```bash
python3 scripts/tests/test_meshy.py
```

See [setup](docs/setup.md), [pipeline](docs/character_pipeline.md), and
[known automation gaps](AUTOMATION_GAPS.md).
