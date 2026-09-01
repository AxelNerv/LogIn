#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UCODE_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
BLOCKCHECK="$UCODE_LIB/diagnostics/blockcheck.uc"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

mkdir -p "$WORK_DIR/bin"
printf '%s\n' original >"$WORK_DIR/current"

cat >"$WORK_DIR/uci.uc" <<'UCODE'
let fs = require("fs");
let state = {
    action: "zapret",
    nfqws_opt: "original"
};

function write_current() {
    fs.writefile(getenv("BLOCKCHECK_TEST_DIR") + "/current", "" + (state.nfqws_opt || "") + "\n");
}

function cursor() {
    return {
        load: function(_package_name) { return true; },
        get: function(package_name, section_name, option_name) {
            if (package_name != "loghorizon" || section_name != "test") return null;
            return state["" + option_name];
        },
        set: function(package_name, section_name, option_name, value) {
            if (package_name != "loghorizon" || section_name != "test") return false;
            state["" + option_name] = value;
            write_current();
            return true;
        },
        delete: function(package_name, section_name, option_name) {
            if (package_name != "loghorizon" || section_name != "test") return false;
            delete state["" + option_name];
            write_current();
            return true;
        },
        commit: function(_package_name) { return true; }
    };
}

return { cursor };
UCODE

cat >"$WORK_DIR/bin/service" <<'SH'
#!/bin/sh
count=0
[ ! -f "$BLOCKCHECK_TEST_DIR/restarts" ] || count="$(cat "$BLOCKCHECK_TEST_DIR/restarts")"
count=$((count + 1))
printf '%s\n' "$count" >"$BLOCKCHECK_TEST_DIR/restarts"
if [ "${BLOCKCHECK_FAIL_RESTORE:-0}" = 1 ] &&
   [ "$count" -gt 1 ] &&
   [ "$(cat "$BLOCKCHECK_TEST_DIR/current")" = original ]; then
  exit 1
fi
exit 0
SH

cat >"$WORK_DIR/bin/curl" <<'SH'
#!/bin/sh
case "${*}" in
  *connectivitycheck*) [ "${BLOCKCHECK_DROP_CONTROL:-0}" != 1 ] ;;
  *) printf '0.125000' ;;
esac
SH

cat >"$WORK_DIR/bin/pgrep" <<'SH'
#!/bin/sh
exit 0
SH

cat >"$WORK_DIR/bin/sleep" <<'SH'
#!/bin/sh
exit 0
SH

chmod +x "$WORK_DIR/bin/"*
printf 'candidate\t--dpi-desync=fake\n' >"$WORK_DIR/strategies.tsv"

run_blockcheck() {
  BLOCKCHECK_TEST_DIR="$WORK_DIR" \
  LOGHORIZON_BLOCKCHECK_LOCK_DIR="$WORK_DIR/lock" \
  LOGHORIZON_BLOCKCHECK_SERVICE_INIT="$WORK_DIR/bin/service" \
  LOGHORIZON_BLOCKCHECK_CURL_BIN="$WORK_DIR/bin/curl" \
  LOGHORIZON_BLOCKCHECK_PGREP_BIN="$WORK_DIR/bin/pgrep" \
  LOGHORIZON_BLOCKCHECK_SLEEP_BIN="$WORK_DIR/bin/sleep" \
    ucode -L "$UCODE_LIB" -L "$WORK_DIR" -- "$BLOCKCHECK" run \
      -s test -f "$WORK_DIR/strategies.tsv" -t example.com -n 8 -w 20
}

output="$(run_blockcheck)" || fail "successful test failed"
grep -Fq 'example.com=8/8 avg=125ms' <<<"$output" || fail "success metrics missing"
grep -Fq 'original strategy restored successfully' <<<"$output" || fail "restore confirmation missing"
[ "$(cat "$WORK_DIR/current")" = original ] || fail "strategy was not restored"
[ "$(cat "$WORK_DIR/restarts")" = 2 ] || fail "unexpected restart count"

printf '%s\n' original >"$WORK_DIR/current"
rm -f "$WORK_DIR/restarts"
output="$(BLOCKCHECK_DROP_CONTROL=1 run_blockcheck)" || fail "connectivity rollback failed"
grep -Fq 'rolled back: external connectivity was lost' <<<"$output" || fail "rollback was not reported"
[ "$(cat "$WORK_DIR/current")" = original ] || fail "connectivity rollback did not restore strategy"

printf '%s\n' original >"$WORK_DIR/current"
rm -f "$WORK_DIR/restarts"
if output="$(BLOCKCHECK_FAIL_RESTORE=1 run_blockcheck 2>&1)"; then
  fail "restore failure was swallowed"
fi
grep -Fq 'CRITICAL: failed to restore the original strategy' <<<"$output" ||
  fail "restore failure was not reported"

if BLOCKCHECK_TEST_DIR="$WORK_DIR" ucode -L "$UCODE_LIB" -L "$WORK_DIR" \
  -- "$BLOCKCHECK" run -s test -f "$WORK_DIR/strategies.tsv" -n 7 >/dev/null 2>&1; then
  fail "unreliable request count was accepted"
fi

printf 'BlockCheck tests passed\n'
