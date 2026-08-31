#!/usr/bin/env bash
set -eo pipefail

# sing-box keeps the FakeIP map across restarts, which is the point of
# store_fakeip - until the mapping goes stale. After the DNS settings change,
# or after a section's lists change, clients keep being handed an address that
# no longer routes anywhere and pages simply stop loading. A plain restart
# does not clear it, nothing in the interface hints at it, and the fix is a
# file the user has no reason to know about.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIFECYCLE="$ROOT_DIR/loghorizon/files/usr/lib/service/lifecycle.uc"
CLI="$ROOT_DIR/loghorizon/files/usr/bin/loghorizon"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

grep -Fq 'function reset_fakeip() {' "$LIFECYCLE" ||
  fail "the service must be able to clear the FakeIP cache"
grep -Fq 'else if (mode == "reset-fakeip")' "$LIFECYCLE" ||
  fail "the operation must be reachable from the module entry point"
grep -Fq 'reset-fakeip' "$LIFECYCLE" ||
  fail "the usage line must mention the operation"

# The file is written back out on shutdown, so removing it under a running
# sing-box accomplishes nothing.
awk '
  /function reset_fakeip\(\) \{/ { inside = 1 }
  inside && /stop_impl\(\)/ { stopped = NR }
  inside && /remove_file\(cache_path\)/ { removed = NR }
  inside && /start_impl\(\)/ && started == 0 { started = NR }
  inside && /^}/ { exit }
  END { exit (stopped > 0 && removed > stopped && started > removed) ? 0 : 1 }
' "$LIFECYCLE" ||
  fail "the cache must be removed while sing-box is stopped, then the service started"

# A configured cache_path must win, or the wrong file is deleted.
grep -Fq 'config_get(CONFIG_NAME + ".settings.cache_path"' "$LIFECYCLE" ||
  fail "the configured cache path must be honoured"

grep -Fq 'reset_fakeip: [ "service/lifecycle.uc", "reset-fakeip", 0 ],' "$CLI" ||
  fail "the command must be dispatched from the CLI"
grep -Fq 'reset_fakeip            Clear the FakeIP cache' "$CLI" ||
  fail "the command must be listed in the help output"

printf 'reset fakeip checks passed\n'
