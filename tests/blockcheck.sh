#!/bin/sh
set -eu

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
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
printf '%s\n' 10 >"$WORK_DIR/packets"
printf '%s\n' \
  'loghorizon.test.action=zapret' \
  'loghorizon.test.nfqws_opt=original' >"$WORK_DIR/uci-state"

cat >"$WORK_DIR/bin/service" <<'SH'
#!/bin/sh
count=0
[ ! -f "$BLOCKCHECK_TEST_DIR/restarts" ] || count="$(cat "$BLOCKCHECK_TEST_DIR/restarts")"
count=$((count + 1))
printf '%s\n' "$count" >"$BLOCKCHECK_TEST_DIR/restarts"
sed -n 's/^loghorizon\.test\.nfqws_opt=//p' "$LOGHORIZON_UCI_STATE_FILE" \
  >"$BLOCKCHECK_TEST_DIR/current"
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
  *)
    if [ "${BLOCKCHECK_NO_QUEUE_GROWTH:-0}" != 1 ]; then
      packets="$(cat "$BLOCKCHECK_TEST_DIR/packets")"
      printf '%s\n' "$((packets + 1))" >"$BLOCKCHECK_TEST_DIR/packets"
    fi
    printf '0.125000'
    ;;
esac
SH

cat >"$WORK_DIR/bin/loghorizon" <<'SH'
#!/bin/sh
case "$1" in
  blockcheck)
    shift
    exec ucode -L "$BLOCKCHECK_TEST_UCODE_LIB" -L "$BLOCKCHECK_TEST_DIR" -- \
      "$BLOCKCHECK_TEST_SCRIPT" run "$@"
    ;;
  check_rule_path)
    [ "${BLOCKCHECK_ROUTE_MISMATCH:-0}" != 1 ] || exit 1
    printf '{"success":true}\n'
    ;;
  get_zapret_status)
    packets="$(cat "$BLOCKCHECK_TEST_DIR/packets")"
    section="${BLOCKCHECK_COUNTER_SECTION:-test}"
    printf '{"ready":true,"queue_counters":[{"section":"%s","rule_present":true,"total_packets":%s}]}\n' \
      "$section" "$packets"
    ;;
  *) exit 1 ;;
esac
SH

cat >"$WORK_DIR/bin/pgrep" <<'SH'
#!/bin/sh
exit 0
SH

cat >"$WORK_DIR/bin/sleep" <<'SH'
#!/bin/sh
if [ "${BLOCKCHECK_HOLD_SLEEP:-0}" = 1 ] && [ "${1:-}" = 20 ]; then
  printf '%s\n' "$PPID" >"$BLOCKCHECK_TEST_DIR/worker-pid"
  /bin/sleep 30
elif [ "${BLOCKCHECK_HOLD_SLEEP:-0}" = 1 ]; then
  /bin/sleep 1
fi
exit 0
SH

chmod +x "$WORK_DIR/bin/"*
printf 'candidate\t--dpi-desync=fake\n' >"$WORK_DIR/strategies.tsv"

run_blockcheck() {
  BLOCKCHECK_TEST_DIR="$WORK_DIR" \
  LOGHORIZON_UCI_STATE_FILE="$WORK_DIR/uci-state" \
  LOGHORIZON_BLOCKCHECK_LOCK_DIR="$WORK_DIR/lock" \
  LOGHORIZON_BLOCKCHECK_SERVICE_INIT="$WORK_DIR/bin/service" \
  LOGHORIZON_BLOCKCHECK_CURL_BIN="$WORK_DIR/bin/curl" \
  LOGHORIZON_BLOCKCHECK_LOGHORIZON_BIN="$WORK_DIR/bin/loghorizon" \
  BLOCKCHECK_TEST_UCODE_LIB="$UCODE_LIB" \
  BLOCKCHECK_TEST_SCRIPT="$BLOCKCHECK" \
  LOGHORIZON_BLOCKCHECK_PGREP_BIN="$WORK_DIR/bin/pgrep" \
  LOGHORIZON_BLOCKCHECK_SLEEP_BIN="$WORK_DIR/bin/sleep" \
  LOGHORIZON_BLOCKCHECK_RECOVERY_FILE="$WORK_DIR/recovery.json" \
  LOGHORIZON_BLOCKCHECK_WATCHDOG_ENABLED="${LOGHORIZON_BLOCKCHECK_WATCHDOG_ENABLED:-0}" \
    ucode -L "$UCODE_LIB" -L "$WORK_DIR" -- "$BLOCKCHECK" run \
      -s test -f "$WORK_DIR/strategies.tsv" -t example.com -n 8 -w 20
}

output="$(run_blockcheck)" || fail "successful test failed"
printf '%s\n' "$output" | grep -Fq 'example.com=http:8/8 http_avg=125ms' || fail "HTTP request timing missing"
printf '%s\n' "$output" | grep -Fq 'verified:nfqueue+8' || fail "selected NFQUEUE traffic was not verified"
printf '%s\n' "$output" | grep -Fq 'original strategy restored successfully' || fail "restore confirmation missing"
[ "$(cat "$WORK_DIR/current")" = original ] || fail "strategy was not restored"
[ "$(cat "$WORK_DIR/restarts")" = 2 ] || fail "unexpected restart count"
[ ! -e "$WORK_DIR/recovery.json" ] || fail "recovery journal was not cleared"

printf '%s\n' original >"$WORK_DIR/current"
printf '%s\n' 10 >"$WORK_DIR/packets"
rm -f "$WORK_DIR/restarts"
output="$(BLOCKCHECK_NO_QUEUE_GROWTH=1 run_blockcheck)" || fail "zero-counter test failed"
printf '%s\n' "$output" | grep -Fq 'unverified:selected-nfqueue+0' || fail "zero counter growth was accepted"
if printf '%s\n' "$output" | grep -Fq ' verified:nfqueue+'; then
  fail "unverified DPI path was reported as verified"
fi

printf '%s\n' original >"$WORK_DIR/current"
printf '%s\n' 10 >"$WORK_DIR/packets"
rm -f "$WORK_DIR/restarts"
output="$(BLOCKCHECK_COUNTER_SECTION=another run_blockcheck)" || fail "wrong-section test failed"
printf '%s\n' "$output" | grep -Fq 'rejected: selected engine section is not ready' ||
  fail "another NFQUEUE section masked the selected section"

printf '%s\n' original >"$WORK_DIR/current"
rm -f "$WORK_DIR/restarts"
output="$(BLOCKCHECK_DROP_CONTROL=1 run_blockcheck)" || fail "connectivity rollback failed"
printf '%s\n' "$output" | grep -Fq 'rolled back: external connectivity was lost' || fail "rollback was not reported"
[ "$(cat "$WORK_DIR/current")" = original ] || fail "connectivity rollback did not restore strategy"

printf '%s\n' original >"$WORK_DIR/current"
rm -f "$WORK_DIR/restarts"
if output="$(BLOCKCHECK_FAIL_RESTORE=1 run_blockcheck 2>&1)"; then
  fail "restore failure was swallowed"
fi
printf '%s\n' "$output" | grep -Fq 'CRITICAL: failed to restore the original strategy' ||
  fail "restore failure was not reported"

printf '%s\n' candidate >"$WORK_DIR/current"
printf '%s\n' '{"version":1,"config":"loghorizon","section":"test","option":"nfqws_opt","original":"original","original_present":true}' \
  >"$WORK_DIR/recovery.json"
mkdir -p "$WORK_DIR/lock"
rm -f "$WORK_DIR/restarts"
output="$(
  BLOCKCHECK_TEST_DIR="$WORK_DIR" \
  LOGHORIZON_UCI_STATE_FILE="$WORK_DIR/uci-state" \
  LOGHORIZON_BLOCKCHECK_LOCK_DIR="$WORK_DIR/lock" \
  LOGHORIZON_BLOCKCHECK_RECOVERY_FILE="$WORK_DIR/recovery.json" \
  LOGHORIZON_BLOCKCHECK_SERVICE_INIT="$WORK_DIR/bin/service" \
    ucode -L "$UCODE_LIB" -L "$WORK_DIR" -- "$BLOCKCHECK" run --recover
)" || fail "crash recovery failed"
printf '%s\n' "$output" | grep -Fq 'stale test strategy restored successfully' || fail "recovery was not reported"
[ "$(cat "$WORK_DIR/current")" = original ] || fail "crash recovery did not restore strategy"
[ ! -e "$WORK_DIR/recovery.json" ] || fail "crash recovery journal was not cleared"
[ ! -d "$WORK_DIR/lock" ] || fail "stale BlockCheck lock was not cleared"

printf '%s\n' original >"$WORK_DIR/current"
printf '%s\n' 10 >"$WORK_DIR/packets"
rm -f "$WORK_DIR/restarts" "$WORK_DIR/worker-pid" "$WORK_DIR/recovery.json"
BLOCKCHECK_HOLD_SLEEP=1 \
LOGHORIZON_BLOCKCHECK_WATCHDOG_ENABLED=1 \
run_blockcheck >"$WORK_DIR/crash.out" 2>&1 &
crash_job=$!
attempt=0
while [ ! -s "$WORK_DIR/worker-pid" ] && [ "$attempt" -lt 20 ]; do
  /bin/sleep 1
  attempt=$((attempt + 1))
done
[ -s "$WORK_DIR/worker-pid" ] || fail "crash test worker did not reach candidate state"
kill -9 "$(cat "$WORK_DIR/worker-pid")" 2>/dev/null || true
attempt=0
while [ -e "$WORK_DIR/recovery.json" ] && [ "$attempt" -lt 10 ]; do
  /bin/sleep 1
  attempt=$((attempt + 1))
done
wait "$crash_job" 2>/dev/null || true
[ "$(cat "$WORK_DIR/current")" = original ] || fail "watchdog did not restore strategy after worker crash"
[ ! -e "$WORK_DIR/recovery.json" ] || fail "watchdog did not clear recovery journal"
[ ! -d "$WORK_DIR/lock" ] || fail "watchdog did not clear BlockCheck lock"

if BLOCKCHECK_TEST_DIR="$WORK_DIR" ucode -L "$UCODE_LIB" -L "$WORK_DIR" \
  -- "$BLOCKCHECK" run -s test -f "$WORK_DIR/strategies.tsv" -n 7 >/dev/null 2>&1; then
  fail "unreliable request count was accepted"
fi

printf 'BlockCheck tests passed\n'
