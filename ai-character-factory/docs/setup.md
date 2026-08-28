# Setup

Requirements already present here are Git, Python 3.11+, Node 18+, and Godot 4.x.

On a fresh checkout:

```bash
scripts/setup/install_blender.sh
scripts/setup/configure_codex_mcp.sh
cp .env.example .env
```

Then add only `MESHY_API_KEY` to `.env`. The file is ignored by Git. Test each backend:

```bash
python3 scripts/tests/test_blender.py
scripts/tests/test_godot.sh
python3 scripts/tests/test_meshy.py
```

The Blender installer downloads the official 5.2.1 LTS portable archive into the ignored
`tools/blender/` directory. It does not use `sudo` or modify system packages.

The pinned official Meshy MCP is `@meshy-ai/meshy-mcp-server@0.5.1` (MIT, Node ≥18, no install
hook). The Godot MCP is `@yanhuifair/godot-mcp@1.11.2` (AGPL-3.0-or-later). Godot MCP can write
project files and run Godot; its bridge binds loopback only. Meshy MCP can call paid API operations
and download files; its key remains in the process environment.

Official references: [Meshy AI integration](https://docs.meshy.ai/en/api/ai),
[Meshy OpenAPI](https://docs.meshy.ai/openapi.yaml),
[Blender releases](https://www.blender.org/releases/), and
[Godot command line](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html).
