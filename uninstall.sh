#!/bin/sh
# shellcheck shell=dash
#
# Removes logIn from an OpenWrt router and leaves it ready for something else
# to be installed in its place.
#
# `loghorizon uninstall` already stops the service, hands dnsmasq back and
# deletes the files, but it leaves three things behind: the package entry in
# the package manager, the components it installed on demand (sing-box and the
# DPI engines), and the configuration. Those are exactly what gets in the way
# of installing another routing package afterwards, so this removes them too.
#
#   sh uninstall.sh                 remove everything
#   sh uninstall.sh --keep-config   keep /etc/config/loghorizon and /etc/loghorizon
#   sh uninstall.sh --keep-components  keep sing-box and the DPI engines

set -e

KEEP_CONFIG=0
KEEP_COMPONENTS=0
BIN_PATH="/usr/bin/loghorizon"
INIT_PATH="/etc/init.d/loghorizon"

usage() {
    cat <<EOF
Usage: uninstall.sh [--keep-config] [--keep-components]

  --keep-config      leave /etc/config/loghorizon and /etc/loghorizon in place
  --keep-components  leave sing-box, Zapret, Zapret2 and ByeDPI installed
EOF
}

msg() {
    printf '%s\n' "$1"
}

warn() {
    printf 'Warning: %s\n' "$1" >&2
}

fail() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --keep-config) KEEP_CONFIG=1 ;;
        --keep-components) KEEP_COMPONENTS=1 ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; fail "unknown option: $1" ;;
    esac
    shift
done

[ "$(id -u)" = "0" ] || fail "run this as root"

if command -v apk >/dev/null 2>&1 && [ -d /lib/apk/db ]; then
    PKG_REMOVE="apk del"
    PKG_LIST="apk info"
else
    PKG_REMOVE="opkg remove --force-depends"
    PKG_LIST="opkg list-installed"
fi

package_installed() {
    $PKG_LIST 2>/dev/null | cut -d' ' -f1 | grep -Fxq "$1"
}

remove_package() {
    package_installed "$1" || return 0
    msg "Removing package $1"
    # A package whose files are already gone still fails to remove cleanly on
    # some versions; the entry disappears either way, so a failure here is
    # reported and not fatal.
    $PKG_REMOVE "$1" >/dev/null 2>&1 || warn "package manager reported an error removing $1"
}

remove_packages_by_prefix() {
    $PKG_LIST 2>/dev/null | cut -d' ' -f1 | grep "^$1" | while read -r name; do
        [ -n "$name" ] && remove_package "$name"
    done
}

# --- Let logIn take itself apart first --------------------------------------
# This is the part that hands dnsmasq back and drops the routing rules. Doing
# it before removing packages matters: afterwards the binary is gone.

if [ -x "$BIN_PATH" ]; then
    msg "Asking logIn to remove its own runtime"
    "$BIN_PATH" uninstall >/dev/null 2>&1 ||
        warn "logIn could not remove its runtime cleanly; continuing"
elif [ -x "$INIT_PATH" ]; then
    "$INIT_PATH" stop >/dev/null 2>&1 || true
    "$INIT_PATH" disable >/dev/null 2>&1 || true
fi

# --- Packages ---------------------------------------------------------------

remove_packages_by_prefix "luci-i18n-loghorizon"
remove_package "luci-app-loghorizon"
remove_package "loghorizon"

if [ "$KEEP_COMPONENTS" -eq 0 ]; then
    # Installed by logIn on demand rather than as dependencies. Left in place
    # they collide with whatever gets installed next, which is the usual reason
    # for running this script at all.
    for component in sing-box sing-box-extended sing-box-tiny zapret zapret2 byedpi; do
        remove_package "$component"
    done
fi

# --- Leftovers the package manager does not own -----------------------------

for path in \
    /usr/bin/loghorizon \
    /usr/lib/loghorizon \
    /etc/init.d/loghorizon \
    /www/luci-static/resources/view/loghorizon \
    /usr/share/luci/menu.d/luci-app-loghorizon.json \
    /usr/share/rpcd/acl.d/luci-app-loghorizon.json \
    /etc/uci-defaults/50_luci-loghorizon \
    /var/run/loghorizon \
    /tmp/loghorizon; do
    [ -e "$path" ] && rm -rf "$path"
done

if [ "$KEEP_CONFIG" -eq 0 ]; then
    rm -f /etc/config/loghorizon
    rm -rf /etc/loghorizon
else
    msg "Keeping /etc/config/loghorizon and /etc/loghorizon"
fi

# Firewall tables belonging to logIn and to the DPI engines it drove. Left
# behind they keep marking or queueing packets for processes that no longer
# exist, which looks like a broken network rather than a removed package.
if command -v nft >/dev/null 2>&1; then
    for table in LogHorizonTable zapret zapret2; do
        nft list table inet "$table" >/dev/null 2>&1 &&
            nft delete table inet "$table" >/dev/null 2>&1 || true
    done
fi

ip rule del fwmark 0x08000000 lookup 100 2>/dev/null || true
ip route flush table 100 2>/dev/null || true

crontab -l 2>/dev/null | grep -v loghorizon | crontab - 2>/dev/null || true

rm -f /var/luci-indexcache* /tmp/luci-indexcache* 2>/dev/null || true
[ -x /etc/init.d/rpcd ] && /etc/init.d/rpcd reload >/dev/null 2>&1

# --- Make sure name resolution is working before we walk away ---------------

if [ -x /etc/init.d/dnsmasq ]; then
    /etc/init.d/dnsmasq restart >/dev/null 2>&1 ||
        warn "could not restart dnsmasq; check DNS on the router"
fi

msg ""
msg "logIn removed."
if [ "$KEEP_CONFIG" -eq 0 ]; then
    msg "Configuration and state are gone as well."
else
    msg "Configuration kept at /etc/config/loghorizon."
fi
msg "The router is ready for another routing package to be installed."
