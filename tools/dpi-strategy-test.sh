#!/bin/sh

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)" || exit 1
exec "$ROOT_DIR/loghorizon/files/usr/bin/loghorizon-blockcheck" "$@"
