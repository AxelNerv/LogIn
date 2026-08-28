#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_FILES="$ROOT_DIR/loghorizon/files"
LOGHORIZON_BIN="$LOGHORIZON_FILES/usr/bin/loghorizon"
LOGHORIZON_LIB="$LOGHORIZON_FILES/usr/lib"
LOGHORIZON_INIT="$LOGHORIZON_FILES/etc/init.d/loghorizon"
LUCI_ROOT="$ROOT_DIR/luci-app-loghorizon/root"
LUCI_UCI_DEFAULTS="$LUCI_ROOT/etc/uci-defaults/50_luci-loghorizon"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -d "$LOGHORIZON_LIB" ] || fail "runtime library directory is missing"
[ -r "$LOGHORIZON_BIN" ] || fail "loghorizon ucode entrypoint is missing"
[ -r "$LOGHORIZON_INIT" ] || fail "loghorizon init.d entrypoint is missing"
[ -r "$LUCI_UCI_DEFAULTS" ] || fail "LuCI uci-defaults entrypoint is missing"

runtime_shell_files="$(find "$LOGHORIZON_LIB" -type f -name '*.sh' -print)"
[ -z "$runtime_shell_files" ] ||
  fail "runtime library must not contain shell owners: $runtime_shell_files"

legacy_shell_owners='runtime_state\.sh|rules_nft_runtime\.sh|config_validation\.sh|sing_box_runtime\.sh|updates_runtime\.sh|updater\.sh|status_diagnostics\.sh|helpers\.sh|constants\.sh|subscription_runtime\.sh|byedpi\.sh|zapret\.sh|zapret2\.sh'
if find "$LOGHORIZON_FILES" -type f -print | grep -E "$legacy_shell_owners" >/dev/null 2>&1; then
  fail "legacy runtime shell owner file returned under loghorizon/files"
fi

shell_scripts="$(
  find "$LOGHORIZON_FILES" "$LUCI_ROOT" -type f -print |
    while IFS= read -r file; do
      first_line="$(sed -n '1p' "$file")"
      case "$first_line" in
        '#!'*'/bin/sh'*|'#!'*'/bin/ash'*|'#!'*'rc.common'*|'#!'*' bash'*|'#!'*'/bash'*)
          printf '%s\n' "${file#$ROOT_DIR/}"
          ;;
      esac
    done |
    LC_ALL=C sort
)"

expected_shell_scripts="$(
  printf '%s\n' \
    'luci-app-loghorizon/root/etc/uci-defaults/50_luci-loghorizon' \
    'loghorizon/files/etc/init.d/loghorizon' |
    LC_ALL=C sort
)"

[ "$shell_scripts" = "$expected_shell_scripts" ] ||
  fail "unexpected packaged shell inventory:
expected:
$expected_shell_scripts
actual:
$shell_scripts"

grep -Fq '#!/usr/bin/ucode' "$LOGHORIZON_BIN" ||
  fail "/usr/bin/loghorizon must remain a direct ucode executable"
grep -Fq 'function command_spec(command)' "$LOGHORIZON_BIN" ||
  fail "/usr/bin/loghorizon must own command routing in ucode"
if grep -n -E '#!/bin/(ba)?sh|exec[[:space:]]+ucode|run_module\(|LOGHORIZON_COMMAND' "$LOGHORIZON_BIN" >/dev/null 2>&1; then
  fail "/usr/bin/loghorizon must not regress to a shell loader or shell router"
fi

grep -Fq 'LOGHORIZON_INITD_UC="$LOGHORIZON_LIB/service/initd.uc"' "$LOGHORIZON_INIT" ||
  fail "init.d must delegate service orchestration to service/initd.uc"
grep -Fq 'initd_ucode start-service' "$LOGHORIZON_INIT" ||
  fail "init.d start path must delegate to ucode"
grep -Fq 'initd_ucode stop-service' "$LOGHORIZON_INIT" ||
  fail "init.d stop path must delegate to ucode"
grep -Fq 'initd_ucode reload-service' "$LOGHORIZON_INIT" ||
  fail "init.d reload path must delegate to ucode"
grep -Fq 'initd_ucode trigger-plan' "$LOGHORIZON_INIT" ||
  fail "init.d trigger decisions must be produced by ucode"

if grep -n -E '(^|[^[:alnum:]_])(uci|config_load|config_get|config_foreach|jsonfilter|nft|iptables|ip6?tables|sing-box|dnsmasq|curl|wget|opkg|apk)([[:space:]]|$)' "$LOGHORIZON_INIT" >/dev/null 2>&1; then
  fail "init.d must not own UCI, routing, download, package, dnsmasq, nft, or sing-box decisions"
fi
if grep -n -E 'LOGHORIZON_RELOAD_LOCK|LOGHORIZON_URLTEST_SELECTOR_SWITCHES|capture_reload_state|populate_nft_runtime_sets|rebuild_nft_runtime|apply_pending_urltest_selector_switches' "$LOGHORIZON_INIT" >/dev/null 2>&1; then
  fail "init.d must not own runtime state or reload decisions"
fi

grep -Fq '/usr/bin/loghorizon luci_postinst' "$LUCI_UCI_DEFAULTS" ||
  fail "LuCI uci-defaults must delegate postinstall work to ucode"
if grep -n -E '(^|[^[:alnum:]_])(uci|rm|logger|rpcd|killall|jsonfilter|config_load|config_get)([[:space:]]|$)' "$LUCI_UCI_DEFAULTS" >/dev/null 2>&1; then
  fail "LuCI uci-defaults must not own cache, rpcd, logging, or UCI logic"
fi

printf 'shell inventory checks passed\n'
