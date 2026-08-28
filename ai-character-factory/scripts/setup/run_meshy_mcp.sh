#!/usr/bin/env bash
set -euo pipefail

FACTORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
if [[ -f "${FACTORY_ROOT}/.env" ]]; then
  set -a
  source "${FACTORY_ROOT}/.env"
  set +a
fi
if [[ -z "${MESHY_API_KEY:-}" ]]; then
  echo "MESHY_API_KEY is missing in ${FACTORY_ROOT}/.env" >&2
  exit 2
fi
exec npx -y @meshy-ai/meshy-mcp-server@0.5.1
