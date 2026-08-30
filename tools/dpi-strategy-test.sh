#!/bin/sh
# Measures DPI bypass strategies against real hosts, on the router itself.
#
# Which strategy defeats a block depends on the operator, so the only way to
# choose one is to try them. Every strategy is applied the way logIn applies
# it - through UCI and a service restart - because the section's lists and the
# nftables rules are what put traffic into the queue in the first place.
# Driving nfqws by hand skips all of that and measures something else.
#
# Usage:
#   sh dpi-strategy-test.sh -s <section> -f <file> [-t hosts] [-n count]
#
#   -s  section to test, e.g. dpiDS
#   -f  file of strategies: name, a TAB, then the strategy line
#   -t  comma separated hosts (default: discord.com,www.youtube.com)
#   -n  requests per host (default: 8; fewer than 8 is not worth reading)
#
# The section's original strategy is restored on exit, including on Ctrl+C.

set -e

SECTION=""
FILE=""
HOSTS="discord.com,www.youtube.com"
COUNT=8

# sing-box keeps loading its rule sets for a while after a restart, and until
# it has, part of the traffic never reaches the queue. Measuring inside that
# window produces good numbers that have nothing to do with the strategy.
SETTLE=22

while [ $# -gt 0 ]; do
    case "$1" in
        -s) SECTION="$2"; shift 2 ;;
        -f) FILE="$2"; shift 2 ;;
        -t) HOSTS="$2"; shift 2 ;;
        -n) COUNT="$2"; shift 2 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
    esac
done

[ -n "$SECTION" ] || { printf 'A section is required: -s dpiDS\n' >&2; exit 2; }
[ -n "$FILE" ] || { printf 'A strategy file is required: -f strategies.txt\n' >&2; exit 2; }
[ -r "$FILE" ] || { printf 'Cannot read %s\n' "$FILE" >&2; exit 2; }

ACTION="$(uci -q get "loghorizon.$SECTION.action" || true)"
case "$ACTION" in
    zapret) OPTION="nfqws_opt"; ENGINE="nfqws" ;;
    zapret2) OPTION="nfqws2_opt"; ENGINE="nfqws2" ;;
    byedpi) OPTION="byedpi_cmd_opts"; ENGINE="byedpi" ;;
    "") printf 'No section named %s\n' "$SECTION" >&2; exit 2 ;;
    *) printf 'Section %s has action %s, which carries no strategy\n' "$SECTION" "$ACTION" >&2; exit 2 ;;
esac

ORIGINAL="$(uci -q get "loghorizon.$SECTION.$OPTION" || true)"

restore() {
    printf '\nRestoring the original strategy\n'
    if [ -n "$ORIGINAL" ]; then
        uci set "loghorizon.$SECTION.$OPTION=$ORIGINAL"
    else
        uci -q delete "loghorizon.$SECTION.$OPTION" || true
    fi
    uci commit loghorizon
    /etc/init.d/loghorizon restart >/dev/null 2>&1 || true
}
trap 'restore; exit 130' INT TERM
trap restore EXIT

probe() {
    _host="$1"; _ok=0; _i=0
    while [ "$_i" -lt "$COUNT" ]; do
        if curl -s -o /dev/null -m 6 "https://$_host/favicon.ico" >/dev/null 2>&1; then
            _ok=$((_ok + 1))
        fi
        _i=$((_i + 1))
    done
    printf '%s' "$_ok"
}

printf 'Section %s (%s), %s requests per host, hosts: %s\n\n' \
    "$SECTION" "$ACTION" "$COUNT" "$HOSTS"

while IFS="	" read -r name strategy; do
    [ -n "$name" ] || continue
    case "$name" in \#*) continue ;; esac

    uci set "loghorizon.$SECTION.$OPTION=$strategy"
    uci commit loghorizon

    if ! /etc/init.d/loghorizon restart >/dev/null 2>&1; then
        printf '%-30s service refused to restart\n' "$name"
        continue
    fi
    sleep "$SETTLE"

    # A rejected strategy leaves the engine down, and every host then fails
    # for a reason that has nothing to do with the strategy being any good.
    if ! pgrep "$ENGINE" >/dev/null 2>&1; then
        printf '%-30s engine did not start (strategy refused)\n' "$name"
        continue
    fi

    line="$(printf '%-30s' "$name")"
    for host in $(printf '%s' "$HOSTS" | tr ',' ' '); do
        line="$line $(printf '%s=%s/%s' "$host" "$(probe "$host")" "$COUNT")"
    done
    printf '%s\n' "$line"
done < "$FILE"
