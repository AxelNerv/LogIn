#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CATALOG="$ROOT_DIR/loghorizon/files/usr/lib/dpi-presets.json"
LIB="$ROOT_DIR/loghorizon/files/usr/lib"
FIXTURE="$ROOT_DIR/tests/fixtures/dpi_presets.uc"

ucode -L "$LIB" -- "$FIXTURE" "$CATALOG"
