#!/usr/bin/env bash
set -eo pipefail

# podkop-plus is the ancestor this codebase was forked from; plain podkop is a
# different package that nevertheless drives the same sing-box, nftables and
# DNS machinery. Detection used to look only for podkop-plus, so a router
# running plain podkop got logIn installed beside a live podkop and the two
# fought over routing. Both must now be found, stopped and removed.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/install.sh"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- The shell layer looks for the base package and its configuration -------

grep -Fq 'if ! pkg_is_installed "$LEGACY_BACKEND_PACKAGE" && ! pkg_is_installed "$LEGACY_BRAND"; then' "$INSTALLER" ||
  fail "detect_legacy_installation must also look for the base legacy package"
grep -Fq '"/etc/config/$LEGACY_BRAND"' "$INSTALLER" ||
  fail "detect_legacy_installation must also consider the base legacy configuration"

# --- The ucode layer detects, deactivates and removes it --------------------

grep -Fq 'function installer_legacy_base_present()' "$INSTALLER" ||
  fail "the installer must be able to detect a plain legacy installation"
grep -Fq 'if ((legacy_installed || legacy_base_installed) && !installer_deactivate_legacy_base())' "$INSTALLER" ||
  fail "deactivation must not depend on the plus package alone"
grep -Fq 'if (!installer_remove_package(LEGACY_BRAND))' "$INSTALLER" ||
  fail "the base legacy package must be removed"
grep -Fq 'installer_remove_package("luci-app-" + LEGACY_BRAND)' "$INSTALLER" ||
  fail "the base legacy LuCI app must be removed"

# --- Its dnsmasq entries are handed back before the files go ----------------

grep -Fq 'owner == "legacy-base"' "$INSTALLER" ||
  fail "the dnsmasq owner must have a mode for the base legacy package"
grep -Fq 'installer_restore_dnsmasq(INSTALLER_LEGACY_BASE_BIN, "legacy-base")' "$INSTALLER" ||
  fail "stopping the base legacy service must restore dnsmasq"

# --- Either one is reported to the shell as a legacy installation -----------

grep -Fq '(legacy_installed || legacy_base_installed) ? "1" : "0"' "$INSTALLER" ||
  fail "either legacy flavour must be reported as detected"

# --- The embedded helper still compiles -------------------------------------

awk '
  /cat > "\$helper_path" <<.EOF./ { capture = 1; next }
  capture && $0 == "EOF" { exit }
  capture { print }
' "$INSTALLER" > "$WORK_DIR/install-json.uc"

[ -s "$WORK_DIR/install-json.uc" ] ||
  fail "could not extract the embedded installer helper"

if command -v ucode >/dev/null 2>&1; then
  ucode -c -o /dev/null "$WORK_DIR/install-json.uc" ||
    fail "the embedded installer helper does not compile"
  ucode -S -c -o /dev/null "$WORK_DIR/install-json.uc" ||
    fail "the embedded installer helper does not compile in strict mode"
fi

printf 'legacy podkop detection checks passed\n'
