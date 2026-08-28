# Environment report

Observed on 2026-08-28 in `/home/re7ov/moba2`.

| Component | Result | Evidence |
|---|---|---|
| OS | PASS | Fedora Linux 44 Workstation, kernel 7.1.9-200.fc44.x86_64 |
| CPU | PASS | x86_64, AMD Ryzen 5 3500X, 6 CPUs |
| Git | PASS | `/usr/bin/git`, 2.55.0 |
| Python | PASS | `/usr/bin/python3`, 3.14.7 |
| Node.js | PASS | Node 24.16.0, npm 11.13.0 |
| Blender | PASS | Portable Blender 5.2.1 LTS under `tools/blender/current`; official archive SHA-256 verified as `a31f524fa99a527d3d52b7f5aaa68c34e1a19d5a1c9473f79c5cc610fd5b10e9`; `bpy` probe passed |
| Godot | PASS | `/home/re7ov/.local/bin/godot`, 4.7.1 stable |
| Codex | PASS | `codex-cli 0.149.1` |
| Meshy API key | FAIL | `MESHY_API_KEY` is absent; the no-cost balance smoke test reports the missing credential |

## MCP servers

`codex mcp list` reports these enabled servers:

- `codegraph` — configured; `.codegraph/` exists. The CLI status probe did not return within 10s,
  so index health is not claimed.
- `gbrain` — configured; semantic search returned the MOBA2 project page successfully.
- `godot` — current MOBA2 client connector. `get_status` returned 386 tools and a real
  `list_scenes` call succeeded.
- `character-factory-godot` — registered with the pinned project launcher. The 1.11.2 editor
  plugin is installed and enabled; import logs prove the editor bridge listened on 127.0.0.1:9876,
  and runtime logs prove the bridge listened on 127.0.0.1:9877.
- `meshy` — registered with a wrapper that reads `.env` at runtime. Package 0.5.1 starts and exits
  with the expected missing-key diagnostic until the key is supplied.
- `mongodb` — pre-existing HTTP MCP at 127.0.0.1:3000; enabled, auth status unknown.

System Blender was initially absent. The portable install avoids changing Fedora packages.
