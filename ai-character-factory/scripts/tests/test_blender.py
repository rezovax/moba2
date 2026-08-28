from __future__ import annotations

import os
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def main() -> int:
    configured = os.environ.get("BLENDER_PATH", "")
    blender = Path(configured) if configured else ROOT / "tools" / "blender" / "current" / "blender"
    if not blender.is_file():
        print("FAIL: Blender is missing; run scripts/setup/install_blender.sh")
        return 2
    command = [
        str(blender), "--background", "-noaudio", "--factory-startup",
        "--python-expr", "import bpy; print('BLENDER_API_PASS', bpy.app.version_string)",
    ]
    completed = subprocess.run(command, text=True, capture_output=True, check=False, timeout=60)
    output = completed.stdout + completed.stderr
    if completed.returncode != 0 or "BLENDER_API_PASS" not in output:
        print(f"FAIL: Blender API test failed\n{output}")
        return 1
    print(next(line for line in output.splitlines() if "BLENDER_API_PASS" in line))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
