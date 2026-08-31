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

# --- The interface can trigger it too ---------------------------------------

UI="$ROOT_DIR/loghorizon/files/usr/lib/service/ui.uc"
INITD="$ROOT_DIR/loghorizon/files/etc/init.d/loghorizon"
ACTIONS_TS="$ROOT_DIR/fe-app-loghorizon/src/loghorizon/tabs/diagnostic/partials/renderAvailableActions.ts"
DIAG_TS="$ROOT_DIR/fe-app-loghorizon/src/loghorizon/tabs/diagnostic/initController.ts"

# The UI runs service actions through the init script, not the CLI, so the
# action has to exist there or the button fails with nothing to explain why.
grep -Fq 'EXTRA_COMMANDS="retry_start_on_wan_up handle_wan_up reset_fakeip"' "$INITD" ||
  fail "the action must be declared, or rc.common will not dispatch it"
grep -Fq '/usr/bin/loghorizon reset_fakeip' "$INITD" ||
  fail "the init script must run the command"

grep -Fq 'action == "reset_fakeip"' "$UI" ||
  fail "the backend must accept the action from the interface"

# The service is up again when it finishes, so the UI must expect it running or
# it reports a success as a failure.
awk '
  /function service_action_expected_running\(/ { inside = 1 }
  inside && /reset_fakeip/ { found = 1 }
  inside && /^}/ { exit }
  END { exit found ? 0 : 1 }
' "$UI" ||
  fail "the action must be expected to leave the service running"

grep -Fq "text: _('Clear the FakeIP cache')," "$ACTIONS_TS" ||
  fail "the diagnostics panel must offer the button"
grep -Fq "action: 'reset_fakeip'," "$DIAG_TS" ||
  fail "the button must trigger the service action"

printf 'reset fakeip interface checks passed\n'
