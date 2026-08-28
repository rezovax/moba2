#!/usr/bin/env bash
set -euo pipefail

FACTORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BLENDER_VERSION="5.2.1"
ARCHIVE="blender-${BLENDER_VERSION}-linux-x64.tar.xz"
URL="https://download.blender.org/release/Blender5.2/${ARCHIVE}"
EXPECTED_SHA256="a31f524fa99a527d3d52b7f5aaa68c34e1a19d5a1c9473f79c5cc610fd5b10e9"
TOOLS_DIR="${FACTORY_ROOT}/tools/blender"
INSTALL_DIR="${TOOLS_DIR}/blender-${BLENDER_VERSION}-linux-x64"

mkdir -p "${TOOLS_DIR}"
if [[ ! -f "${TOOLS_DIR}/${ARCHIVE}" ]]; then
  curl --fail --location --retry 3 --output "${TOOLS_DIR}/${ARCHIVE}" "${URL}"
fi
echo "${EXPECTED_SHA256}  ${TOOLS_DIR}/${ARCHIVE}" | sha256sum --check --status
if [[ ! -x "${INSTALL_DIR}/blender" ]]; then
  tar -xJf "${TOOLS_DIR}/${ARCHIVE}" -C "${TOOLS_DIR}"
fi
ln -sfn "${INSTALL_DIR}" "${TOOLS_DIR}/current"
"${TOOLS_DIR}/current/blender" --background --factory-startup --version
