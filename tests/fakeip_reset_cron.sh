#!/usr/bin/env bash
set -eo pipefail

# sing-box remembers which fake address it handed out for each domain and keeps
# that across restarts. Once the mapping goes stale - the DNS settings changed,
# a section's lists changed - clients are sent to an address that no longer
# leads anywhere and pages stop loading, with nothing on screen to explain it.
# Podkop cleared it nightly; this is the same thing, owned by the service so it
# survives a reinstall instead of living in a hand-written crontab line.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
UPDATES="$LOGHORIZON_LIB/components/updates.uc"
LIFECYCLE="$LOGHORIZON_LIB/service/lifecycle.uc"
SETTINGS_JS="$ROOT_DIR/luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/settings.js"
CONFIG_TEMPLATE="$ROOT_DIR/loghorizon/files/etc/config/loghorizon"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

grep -Fq 'FAKEIP_RESET_CRON_MARKER' "$LIFECYCLE" ||
  fail "the reset job needs a marker of its own so it can be replaced and removed"
grep -Fq '# loghorizon-fakeip-reset' "$LIFECYCLE" ||
  fail "the marker must be a comment the crontab can carry"

for option_name in fakeip_reset_enabled fakeip_reset_hour; do
  grep -Fq "\"$option_name\"" "$SETTINGS_JS" ||
    fail "the interface must offer $option_name"
  grep -Fq "option $option_name " "$CONFIG_TEMPLATE" ||
    fail "the config template must ship $option_name"
done

# --- The plan produces a daily job at the configured hour -------------------

plan() {
  printf '%s' "$1" >"$WORK_DIR/fixture.json"
  ucode -L "$LOGHORIZON_LIB" "$UPDATES" cron-refresh-plan-fixture \
    "$WORK_DIR/fixture.json" /usr/bin/loghorizon \
    '# lists' '# subs' '# components' '# fakeip' 2>/dev/null || true
}

enabled="$(plan '{"settings":{"fakeip_reset_enabled":"1","fakeip_reset_hour":"5"},"section":[]}')"
printf '%s' "$enabled" | grep -Fq 'fakeip	0 5 * * * /usr/bin/loghorizon reset_fakeip # fakeip' ||
  fail "an enabled reset must schedule the command daily at the configured hour, got: $enabled"

other="$(plan '{"settings":{"fakeip_reset_enabled":"1","fakeip_reset_hour":"23"},"section":[]}')"
printf '%s' "$other" | grep -Fq '0 23 * * *' ||
  fail "the configured hour must be honoured, got: $other"

off="$(plan '{"settings":{"fakeip_reset_enabled":"0","fakeip_reset_hour":"5"},"section":[]}')"
if printf '%s' "$off" | grep -q '^fakeip'; then
  fail "no job may be scheduled while the setting is off"
fi

# An hour outside the clock is a mistake worth reporting, not rounding into a
# schedule the user never asked for.
bad="$(plan '{"settings":{"fakeip_reset_enabled":"1","fakeip_reset_hour":"25"},"section":[]}')"
printf '%s' "$bad" | grep -Fq 'fakeip-error' ||
  fail "an hour outside 0-23 must be refused, got: $bad"

printf 'fakeip reset cron checks passed\n'
