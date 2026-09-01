#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT_DIR/tests/helpers/check_ucode_declaration_order.js"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

node "$CHECKER" "$ROOT_DIR/loghorizon/files/usr/lib"

cat >"$WORK_DIR/bad.uc" <<'UCODE'
function caller() {
    called_late();
}

function called_late() {
    return true;
}
UCODE

if node "$CHECKER" "$WORK_DIR/bad.uc" >"$WORK_DIR/bad.stdout" 2>"$WORK_DIR/bad.stderr"; then
  echo "FAIL: checker accepted a local function call before its declaration" >&2
  exit 1
fi
grep -Fq 'called_late() is called before its declaration' "$WORK_DIR/bad.stderr" || {
  echo "FAIL: checker did not identify the late local function" >&2
  exit 1
}

cat >"$WORK_DIR/module-method.uc" <<'UCODE'
function caller(runtime) {
    return runtime.state_set();
}

function state_set() {
    return true;
}
UCODE

node "$CHECKER" "$WORK_DIR/module-method.uc" >/dev/null || {
  echo "FAIL: checker treated a module method as a local function call" >&2
  exit 1
}
