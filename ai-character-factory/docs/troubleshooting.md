# Troubleshooting

## Meshy test says the key is missing

Copy `.env.example` to `.env`, set `MESHY_API_KEY`, then run
`python3 scripts/tests/test_meshy.py`. This calls the free balance endpoint and writes metadata under
`output/`.

## Blender is missing

Run `scripts/setup/install_blender.sh`. Override discovery with `BLENDER_PATH=/absolute/blender`.
In restrictive agent sandboxes Blender may hang while exiting; run the build with the normal user
permissions used by the terminal.

## A Meshy task fails

Inspect `builds/<id>/<timestamp>/generated/*_state.json` and the matching log. A terminal failed task
is replaced only for that stage. Successful upstream task IDs are retained within the build.

## Godot import or runtime fails

Inspect `logs/godot_import.log`, `logs/godot_test.log`, and `logs/godot_visual_test.log`. Import is
forced with `godot --headless --import`; runtime must print `CHARACTER_TEST_PASS`. The Xvfb run also
requires six `godot_*.png` files.

## MCP is configured but unavailable in the current chat

Codex discovers newly registered MCP servers at session start. Start a new Codex session after
running `scripts/setup/configure_codex_mcp.sh`. The CLI pipeline does not depend on that restart.
