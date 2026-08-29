#!/usr/bin/env bash
set -eo pipefail

# A failed start used to schedule another attempt 30 seconds later, whatever
# the reason. On a fresh install there are no sections yet, so the config
# generator fails, and the service looped forever: attempt, dnsmasq rollback,
# log, attempt. While a retry was in flight a manual stop had to fight it for
# the runtime lock and did not return.
#
# Configuration failures now exit with a dedicated status and are not retried.
# Transient ones - no WAN, sing-box not up, subscription caches not ready -
# keep the old behaviour.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$ROOT_DIR/loghorizon/files/usr/lib"
INITD_UC="$LIB_DIR/service/initd.uc"
LIFECYCLE_UC="$LIB_DIR/service/lifecycle.uc"
RUNTIME_UC="$LIB_DIR/singbox/runtime.uc"
CACHE_UC="$LIB_DIR/subscription/cache.uc"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- All three modules agree on the status ----------------------------------

status_value() {
  sed -n 's/^const CONFIG_ERROR_EXIT_STATUS = \([0-9]\+\);$/\1/p' "$1"
}

initd_status="$(status_value "$INITD_UC")"
[ -n "$initd_status" ] ||
  fail "service/initd.uc does not define CONFIG_ERROR_EXIT_STATUS"

for module in "$LIFECYCLE_UC" "$RUNTIME_UC"; do
  value="$(status_value "$module")"
  [ "$value" = "$initd_status" ] ||
    fail "$module declares CONFIG_ERROR_EXIT_STATUS $value, expected $initd_status"
done

# --- It does not collide with a status another module already returns -------

if grep -qE "(exit|return) *\(?${initd_status}\)?;" "$CACHE_UC"; then
  fail "subscription/cache.uc already uses status $initd_status for something else"
fi

# --- Configuration failures use it ------------------------------------------

grep -Fq 'exit(CONFIG_ERROR_EXIT_STATUS);' "$RUNTIME_UC" ||
  fail "a failed config generation must exit with the configuration status"
[ "$(grep -cF 'exit(CONFIG_ERROR_EXIT_STATUS);' "$RUNTIME_UC")" -ge 2 ] ||
  fail "both the generator failure and the invalid-config check must use it"
grep -Fq 'return CONFIG_ERROR_EXIT_STATUS;' "$LIFECYCLE_UC" ||
  fail "failed runtime validation must report the configuration status"

# --- The service manager stops retrying on it -------------------------------

grep -Fq 'else if (status == CONFIG_ERROR_EXIT_STATUS)' "$INITD_UC" ||
  fail "start_service must handle the configuration status separately"

awk '
  /else if \(status == CONFIG_ERROR_EXIT_STATUS\)/ { inside = 1; next }
  inside && /schedule_start_retry/ { found = 1 }
  inside && /^    else/ { exit }
  END { exit found ? 1 : 0 }
' "$INITD_UC" ||
  fail "a configuration failure must not schedule a retry"

awk '
  /else if \(status == CONFIG_ERROR_EXIT_STATUS\)/ { inside = 1; next }
  inside && /cancel_scheduled_start_retry/ { found = 1 }
  inside && /^    else/ { exit }
  END { exit found ? 0 : 1 }
' "$INITD_UC" ||
  fail "a configuration failure must cancel any retry already scheduled"

# --- Transient failures still retry -----------------------------------------

grep -Fq 'schedule_start_retry(START_RETRY_PID_FILE, START_RETRY_DELAY_SECONDS);' "$INITD_UC" ||
  fail "transient failures must keep scheduling a retry"

printf 'start retry policy checks passed\n'
