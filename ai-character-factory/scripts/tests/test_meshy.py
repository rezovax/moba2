from __future__ import annotations

import json
import os
import sys
from datetime import UTC, datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from pipeline.common import load_dotenv  # noqa: E402
from pipeline.meshy.client import MeshyClient, MeshyError  # noqa: E402


def main() -> int:
    load_dotenv()
    output = ROOT / "output" / "meshy_smoke_metadata.json"
    key = os.environ.get("MESHY_API_KEY", "")
    if not key:
        print("FAIL: MESHY_API_KEY is missing. Copy .env.example to .env and set the key.")
        return 2
    try:
        balance = MeshyClient(key).get_balance()
    except MeshyError as error:
        print(f"FAIL: {error}")
        return 1
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps({"status": "PASS", "checked_at": datetime.now(UTC).isoformat(), "response": balance}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"PASS: authenticated Meshy balance request; metadata={output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
