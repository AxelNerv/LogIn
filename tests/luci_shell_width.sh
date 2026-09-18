#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STYLES_TS="$ROOT_DIR/fe-app-loghorizon/src/styles.ts"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

grep -Fq '.container:has(.lh-shell) {' "$STYLES_TS" ||
  fail 'the LuCI container override must remain scoped to logIn pages'
grep -Fq 'width: calc(100% - 32px) !important;' "$STYLES_TS" ||
  fail 'desktop shell must override fixed-width vendor themes'
grep -Fq 'width: calc(100% - 16px) !important;' "$STYLES_TS" ||
  fail 'mobile shell must keep a small viewport gutter'

printf 'LuCI shell width checks passed\n'
