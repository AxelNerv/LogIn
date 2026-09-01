#!/bin/sh

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)" || exit 1
LIB_DIR="$ROOT_DIR/loghorizon/files/usr/lib"
exec ucode -L "$LIB_DIR" "$LIB_DIR/diagnostics/blockcheck.uc" run "$@"
