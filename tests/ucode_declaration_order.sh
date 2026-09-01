#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_declared_before_first_call() {
  local file="$1"
  local function_name="$2"
  local declaration_line first_call_line

  declaration_line="$(grep -n -m1 "^function ${function_name}(" "$file" | cut -d: -f1)"
  first_call_line="$(grep -n "${function_name}(" "$file" |
    grep -v ":function ${function_name}(" | head -n1 | cut -d: -f1)"

  [[ -n "$declaration_line" ]] || fail "$function_name has no declaration in $file"
  [[ -n "$first_call_line" ]] || fail "$function_name has no call in $file"
  (( declaration_line < first_call_line )) ||
    fail "$function_name is called on line $first_call_line before its declaration on line $declaration_line in $file"
}

assert_declared_before_first_call "$ROOT_DIR/loghorizon/files/usr/lib/server/service.uc" safe_filename_string
assert_declared_before_first_call "$ROOT_DIR/loghorizon/files/usr/lib/service/initd.uc" release_runtime_dir_lock
assert_declared_before_first_call "$ROOT_DIR/loghorizon/files/usr/lib/service/initd.uc" owner_pid_value
assert_declared_before_first_call "$ROOT_DIR/loghorizon/files/usr/lib/service/state.uc" release_runtime_dir_lock
assert_declared_before_first_call "$ROOT_DIR/loghorizon/files/usr/lib/service/ui.uc" release_dir_lock

echo "ucode declaration order checks passed"
