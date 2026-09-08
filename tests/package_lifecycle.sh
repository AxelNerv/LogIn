#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_BIN="$ROOT_DIR/loghorizon/files/usr/bin/loghorizon"
LOGHORIZON_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
PACKAGE_UC="$LOGHORIZON_LIB/service/package.uc"
LOGHORIZON_MAKEFILE="$ROOT_DIR/loghorizon/Makefile"
LUCI_UCI_DEFAULTS="$ROOT_DIR/luci-app-loghorizon/root/etc/uci-defaults/50_luci-loghorizon"
BUILD_SCRIPT="$ROOT_DIR/build.sh"
WORK_DIR="$(mktemp -d)"
export LOGHORIZON_PACKAGE_UPGRADE_STATE="$WORK_DIR/package-was-running"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

[ -r "$PACKAGE_UC" ] ||
  fail "service/package.uc must own package lifecycle logic"
if grep -n -E 'require\("uci"\)\.cursor|uci -q|uci", "-q"' "$PACKAGE_UC" >/dev/null 2>&1; then
  fail "service/package.uc must use core.uci instead of direct UCI cursor or CLI access"
fi
grep -Fq 'require("core.uci")' "$PACKAGE_UC" ||
  fail "service/package.uc must import core.uci"
grep -Fq 'package_prerm: [ "service/package.uc", "prerm", 1 ]' "$LOGHORIZON_BIN" ||
  fail "loghorizon entrypoint must dispatch package prerm cleanup through service/package.uc"
grep -Fq 'package_postinst: [ "service/package.uc", "postinst", 0 ]' "$LOGHORIZON_BIN" ||
  fail "loghorizon entrypoint must dispatch package postinst recovery through service/package.uc"
grep -Fq 'luci_postinst: [ "service/package.uc", "luci-postinst", 0 ]' "$LOGHORIZON_BIN" ||
  fail "loghorizon entrypoint must dispatch LuCI postinstall cleanup through service/package.uc"
grep -Fq '#!/bin/sh' "$LUCI_UCI_DEFAULTS" ||
  fail "LuCI uci-defaults must remain a shell script because OpenWrt default_postinst runs it through shell"
grep -Fq '/usr/bin/loghorizon luci_postinst' "$LUCI_UCI_DEFAULTS" ||
  fail "LuCI uci-defaults must delegate cache/rpcd handling to ucode"
if grep -E 'rm -f /var/luci-indexcache|rm -f /tmp/luci-indexcache|logger -t "loghorizon"' "$LUCI_UCI_DEFAULTS" >/dev/null; then
  fail "LuCI uci-defaults must not own cache/logger shell logic"
fi

if grep -n -E 'grep -q "105 loghorizon"|sed -i "/105 loghorizon|loghorizon_dont_touch_dhcp=.*uci|cp /etc/config/loghorizon|rm -f /tmp/luci-indexcache|killall -HUP rpcd' "$LOGHORIZON_MAKEFILE" "$BUILD_SCRIPT" >/dev/null; then
  fail "package scripts must not keep backend/LuCI lifecycle business logic in shell"
fi
grep -Fq '#!/usr/bin/ucode' "$LOGHORIZON_MAKEFILE" ||
  fail "loghorizon Makefile package hooks must use ucode entrypoints"
grep -Fq '/usr/bin/loghorizon package_prerm' "$LOGHORIZON_MAKEFILE" ||
  fail "loghorizon Makefile prerm must delegate cleanup to package_prerm"
grep -Fq '/usr/bin/loghorizon package_postinst' "$LOGHORIZON_MAKEFILE" ||
  fail "loghorizon Makefile postinst must restore a service that was running before upgrade"
grep -Fq '/usr/bin/loghorizon package_prerm upgrade' "$BUILD_SCRIPT" ||
  fail "manual APK pre-upgrade must record and stop the running service"
grep -Fq '/usr/bin/loghorizon package_postinst' "$BUILD_SCRIPT" ||
  fail "manual packages must restore a service that was running before upgrade"
if grep -Fq '/usr/bin/loghorizon luci_postinst' "$BUILD_SCRIPT"; then
  fail "manual package hooks must let default_postinst run luci_postinst exactly once through uci-defaults"
fi
if grep -n -E 'Package/loghorizon/preinst|copy_legacy_config|LOGHORIZON_LEGACY_CONFIG|mode == "preinst"' \
  "$LOGHORIZON_MAKEFILE" "$BUILD_SCRIPT" "$PACKAGE_UC" >/dev/null 2>&1; then
  fail "package hooks and runtime service must not own configuration migration"
fi

rt_tables="$WORK_DIR/rt_tables"
cat >"$rt_tables" <<'EOF'
100 main
105 loghorizon
200 custom
EOF
LOGHORIZON_PACKAGE_TEST_MODE=1 LOGHORIZON_RT_TABLES="$rt_tables" \
  ucode -L "$LOGHORIZON_LIB" "$PACKAGE_UC" prerm
if grep -Fq '105 loghorizon' "$rt_tables"; then
  fail "package prerm must remove the logIn routing table entry"
fi
grep -Fq '200 custom' "$rt_tables" ||
  fail "package prerm must preserve unrelated rt_tables entries"

cat >"$WORK_DIR/loghorizon-init" <<'SH'
#!/usr/bin/env bash
grep -Fq '105 loghorizon' "${LOGHORIZON_RT_TABLES:?}" || exit 1
printf '%s\n' 'stop-with-route-table' >>"${LOGHORIZON_STOP_LOG:?}"
SH
chmod 0755 "$WORK_DIR/loghorizon-init"
cat >"$WORK_DIR/stop-order.state" <<'EOF_UCI'
loghorizon.settings=settings
loghorizon.settings.dont_touch_dhcp=1
EOF_UCI
printf '105 loghorizon\n' >"$WORK_DIR/rt_tables_stop_order"
: >"$WORK_DIR/stop-order.log"
LOGHORIZON_UCI_STATE_FILE="$WORK_DIR/stop-order.state" \
LOGHORIZON_INIT="$WORK_DIR/loghorizon-init" \
LOGHORIZON_STOP_LOG="$WORK_DIR/stop-order.log" \
LOGHORIZON_BIN="$WORK_DIR/missing-loghorizon-bin" \
LOGHORIZON_DNS_APPLY_UC="$WORK_DIR/missing-dns-apply.uc" \
LOGHORIZON_SING_BOX_INIT="$WORK_DIR/missing-sing-box-init" \
LOGHORIZON_SING_BOX_BIN="$WORK_DIR/missing-sing-box-bin" \
LOGHORIZON_SING_BOX_CRONET="$WORK_DIR/missing-cronet" \
LOGHORIZON_RT_TABLES="$WORK_DIR/rt_tables_stop_order" \
  ucode -L "$LOGHORIZON_LIB" "$PACKAGE_UC" prerm
grep -Fxq 'stop-with-route-table' "$WORK_DIR/stop-order.log" ||
  fail "package prerm must stop logIn before removing its routing table name"
[ ! -s "$WORK_DIR/rt_tables_stop_order" ] ||
  fail "package prerm must remove the routing table name after logIn stops"

touch "$WORK_DIR/luci-indexcache.one" "$WORK_DIR/luci-indexcache.two"
LOGHORIZON_PACKAGE_TEST_MODE=1 LOGHORIZON_LUCI_CACHE_GLOBS="$WORK_DIR/luci-indexcache*" \
  ucode -L "$LOGHORIZON_LIB" "$PACKAGE_UC" luci-postinst
if compgen -G "$WORK_DIR/luci-indexcache*" >/dev/null; then
  fail "luci-postinst must remove LuCI index cache files"
fi

cat >"$WORK_DIR/loghorizon-bin" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${LOGHORIZON_RESTORE_LOG:?}"
SH
chmod 0755 "$WORK_DIR/loghorizon-bin"

cat >"$WORK_DIR/dont-touch.state" <<'EOF_UCI'
loghorizon.settings=settings
loghorizon.settings.dont_touch_dhcp=1
EOF_UCI
printf '105 loghorizon\n' >"$WORK_DIR/rt_tables_dont_touch"
: >"$WORK_DIR/restore-dont-touch.log"
LOGHORIZON_UCI_STATE_FILE="$WORK_DIR/dont-touch.state" \
LOGHORIZON_RESTORE_LOG="$WORK_DIR/restore-dont-touch.log" \
LOGHORIZON_BIN="$WORK_DIR/loghorizon-bin" \
LOGHORIZON_DNS_APPLY_UC="$WORK_DIR/missing-dns-apply.uc" \
LOGHORIZON_SING_BOX_INIT="$WORK_DIR/missing-sing-box-init" \
LOGHORIZON_SING_BOX_BIN="$WORK_DIR/missing-sing-box-bin" \
LOGHORIZON_SING_BOX_CRONET="$WORK_DIR/missing-cronet" \
LOGHORIZON_RT_TABLES="$WORK_DIR/rt_tables_dont_touch" \
  ucode -L "$LOGHORIZON_LIB" "$PACKAGE_UC" prerm
[ ! -s "$WORK_DIR/restore-dont-touch.log" ] ||
  fail "package prerm must skip dnsmasq restore when dont_touch_dhcp is enabled"

cat >"$WORK_DIR/restore.state" <<'EOF_UCI'
loghorizon.settings=settings
loghorizon.settings.dont_touch_dhcp=0
EOF_UCI
printf '105 loghorizon\n' >"$WORK_DIR/rt_tables_restore"
: >"$WORK_DIR/restore.log"
LOGHORIZON_UCI_STATE_FILE="$WORK_DIR/restore.state" \
LOGHORIZON_RESTORE_LOG="$WORK_DIR/restore.log" \
LOGHORIZON_BIN="$WORK_DIR/loghorizon-bin" \
LOGHORIZON_DNS_APPLY_UC="$WORK_DIR/missing-dns-apply.uc" \
LOGHORIZON_SING_BOX_INIT="$WORK_DIR/missing-sing-box-init" \
LOGHORIZON_SING_BOX_BIN="$WORK_DIR/missing-sing-box-bin" \
LOGHORIZON_SING_BOX_CRONET="$WORK_DIR/missing-cronet" \
LOGHORIZON_RT_TABLES="$WORK_DIR/rt_tables_restore" \
  ucode -L "$LOGHORIZON_LIB" "$PACKAGE_UC" prerm
grep -Fxq 'restore_dnsmasq' "$WORK_DIR/restore.log" ||
  fail "package prerm must restore dnsmasq when dont_touch_dhcp is disabled"

cat >"$WORK_DIR/upgrade-init" <<'SH'
#!/usr/bin/env bash
case "$1" in
  status) exit "${LOGHORIZON_FAKE_STATUS:-0}" ;;
  start) printf '%s\n' start >>"${LOGHORIZON_START_LOG:?}" ;;
  *) exit 1 ;;
esac
SH
chmod 0755 "$WORK_DIR/upgrade-init"
: >"$WORK_DIR/upgrade-start.log"
: >"$WORK_DIR/rt_tables_upgrade"
LOGHORIZON_PACKAGE_TEST_MODE=1 \
LOGHORIZON_INIT="$WORK_DIR/upgrade-init" \
LOGHORIZON_START_LOG="$WORK_DIR/upgrade-start.log" \
LOGHORIZON_RT_TABLES="$WORK_DIR/rt_tables_upgrade" \
  ucode -L "$LOGHORIZON_LIB" "$PACKAGE_UC" prerm upgrade
[ -f "$LOGHORIZON_PACKAGE_UPGRADE_STATE" ] ||
  fail "package pre-upgrade must remember a running service"
LOGHORIZON_PACKAGE_TEST_MODE=1 \
LOGHORIZON_INIT="$WORK_DIR/upgrade-init" \
LOGHORIZON_START_LOG="$WORK_DIR/upgrade-start.log" \
  ucode -L "$LOGHORIZON_LIB" "$PACKAGE_UC" postinst
grep -Fxq start "$WORK_DIR/upgrade-start.log" ||
  fail "package postinst must restart a service that was running before upgrade"
[ ! -e "$LOGHORIZON_PACKAGE_UPGRADE_STATE" ] ||
  fail "package postinst must clear the consumed upgrade state"

# OpenWrt opkg can implement a local IPK replacement as remove + install,
# without an upgrade argument or PKG_UPGRADE=1. It must still restore a service
# that was running before package replacement.
: >"$WORK_DIR/upgrade-start.log"
LOGHORIZON_PACKAGE_TEST_MODE=1 \
LOGHORIZON_INIT="$WORK_DIR/upgrade-init" \
LOGHORIZON_START_LOG="$WORK_DIR/upgrade-start.log" \
LOGHORIZON_RT_TABLES="$WORK_DIR/rt_tables_upgrade" \
  ucode -L "$LOGHORIZON_LIB" "$PACKAGE_UC" prerm remove
[ -f "$LOGHORIZON_PACKAGE_UPGRADE_STATE" ] ||
  fail "package remove hook must remember a running service for opkg local-IPK replacement"
LOGHORIZON_PACKAGE_TEST_MODE=1 \
LOGHORIZON_INIT="$WORK_DIR/upgrade-init" \
LOGHORIZON_START_LOG="$WORK_DIR/upgrade-start.log" \
  ucode -L "$LOGHORIZON_LIB" "$PACKAGE_UC" postinst
grep -Fxq start "$WORK_DIR/upgrade-start.log" ||
  fail "package postinst must restart a running service after opkg remove + install replacement"
[ ! -e "$LOGHORIZON_PACKAGE_UPGRADE_STATE" ] ||
  fail "package postinst must consume remove + install replacement state"

LOGHORIZON_PACKAGE_TEST_MODE=1 \
LOGHORIZON_FAKE_STATUS=1 \
LOGHORIZON_INIT="$WORK_DIR/upgrade-init" \
LOGHORIZON_RT_TABLES="$WORK_DIR/rt_tables_upgrade" \
  ucode -L "$LOGHORIZON_LIB" "$PACKAGE_UC" prerm upgrade
[ ! -e "$LOGHORIZON_PACKAGE_UPGRADE_STATE" ] ||
  fail "package pre-upgrade must not mark an already stopped service"

printf 'package lifecycle checks passed\n'
