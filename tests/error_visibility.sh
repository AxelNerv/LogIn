#!/usr/bin/env bash
set -eo pipefail

# A failure the user cannot see is worse than a crash: the interface keeps
# looking healthy while the router does nothing. These checks pin the places
# where a swallowed error used to turn a dead backend into a clean-looking
# empty installation.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VIEW_DIR="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon"
ENTRY_JS="$VIEW_DIR/loghorizon.js"
INSTALLER="$ROOT_DIR/install.sh"
LIFECYCLE="$ROOT_DIR/loghorizon/files/usr/lib/service/lifecycle.uc"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- The entry point never discards a rejection without telling anyone -------

if grep -Fq 'catch(() => null)' "$ENTRY_JS"; then
  fail "loghorizon.js still discards a rejected promise without reporting it"
fi
if grep -Eq 'catch\(\(\) => \{\}\)' "$ENTRY_JS"; then
  fail "loghorizon.js still has an empty catch handler"
fi

# --- Losing every capability probe is an error, not an empty installation ---

grep -Fq 'no logIn capability probe answered' "$ENTRY_JS" ||
  fail "the fallback probe must fail when no probe answered, instead of reporting nothing installed"

grep -Fq 'ui.addNotification' "$ENTRY_JS" ||
  fail "a failed state load must raise a visible notification"

for message in \
  'Could not read the logIn service state' \
  'the service state could not be re-read'; do
  grep -Fq "$message" "$ENTRY_JS" ||
    fail "missing user-visible message: $message"
done

# --- Those messages reach the user in Russian too ---------------------------

for po in "$ROOT_DIR/fe-app-loghorizon/locales/loghorizon.ru.po" \
  "$ROOT_DIR/luci-app-loghorizon/po/ru/loghorizon.po"; do
  awk '
    /^msgid "Could not read the logIn service state/ {
      getline
      if ($0 != "msgstr \"\"")
        found = 1
    }
    END { exit found ? 0 : 1 }
  ' "$po" || fail "the state-load error must be translated in $po"
done

# --- The installer does not claim a restore it did not verify ---------------

if grep -Fq 'cp "$LEGACY_CONFIG_BACKUP" /etc/config/loghorizon 2>/dev/null || true' "$INSTALLER"; then
  fail "install.sh restores the legacy configuration without checking the result"
fi
grep -Fq 'could not be restored' "$INSTALLER" ||
  fail "install.sh must report a failed restore instead of claiming success"

# --- The service still shouts when it cannot start --------------------------

for message in \
  'Failed to start sing-box. Aborted.' \
  'Runtime config validation failed. Aborted.' \
  'Failed to start DNS failover runtime'; do
  grep -Fq "$message" "$LIFECYCLE" ||
    fail "lifecycle lost its fatal message: $message"
done

printf 'error visibility checks passed\n'
