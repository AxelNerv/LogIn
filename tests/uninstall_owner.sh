#!/usr/bin/env bash
set -eo pipefail

# Removal has to leave a router that another routing package can be installed
# on. `loghorizon uninstall` stops the service and hands dnsmasq back, but it
# leaves the package entry, the components logIn installed on demand and the
# firewall tables behind — and those are exactly what collides with whatever
# gets installed next.
#
# Verified on OpenWrt 24.10.5: after this script nothing of logIn remains and
# podkop installs cleanly on the same system.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNINSTALL="$ROOT_DIR/uninstall.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -r "$UNINSTALL" ] || fail "uninstall.sh is missing"

# --- It hands the runtime back before taking the binary away ----------------

awk '
  /"\$BIN_PATH" uninstall/ { own = NR }
  /remove_package "loghorizon"/ { pkg = NR }
  END { exit (own > 0 && pkg > 0 && own < pkg) ? 0 : 1 }
' "$UNINSTALL" ||
  fail "logIn must remove its own runtime before its binary is removed"

# --- Everything the package manager knows about -----------------------------

grep -Fq 'remove_packages_by_prefix "luci-i18n-loghorizon"' "$UNINSTALL" ||
  fail "translation packages must be removed"
for package in luci-app-loghorizon loghorizon; do
  grep -Fq "remove_package \"$package\"" "$UNINSTALL" ||
    fail "$package must be removed"
done

# --- The components logIn installs on demand --------------------------------

for component in sing-box sing-box-extended sing-box-tiny zapret zapret2 byedpi; do
  grep -Fq "$component" "$UNINSTALL" ||
    fail "component $component must be removed unless it is kept explicitly"
done
grep -Fq 'KEEP_COMPONENTS' "$UNINSTALL" ||
  fail "there must be a way to keep the components"

# --- Firewall state, or the network looks broken afterwards -----------------

for table in LogHorizonTable zapret zapret2; do
  grep -Fq "$table" "$UNINSTALL" ||
    fail "the $table firewall table must be dropped"
done

# --- Name resolution must work when the script returns ----------------------

grep -Fq '/etc/init.d/dnsmasq' "$UNINSTALL" ||
  fail "dnsmasq must be restarted so DNS works after removal"

# --- Configuration goes unless asked otherwise ------------------------------

grep -Fq 'KEEP_CONFIG' "$UNINSTALL" ||
  fail "there must be a way to keep the configuration"
grep -Fq 'rm -f /etc/config/loghorizon' "$UNINSTALL" ||
  fail "the configuration must be removed by default"

# --- Documented in both languages -------------------------------------------

grep -Fq 'uninstall.sh' "$ROOT_DIR/README.md" ||
  fail "removal must be documented in the Russian README"
grep -Fq 'uninstall.sh' "$ROOT_DIR/README.en.md" ||
  fail "removal must be documented in the English README"

printf 'uninstall checks passed\n'
