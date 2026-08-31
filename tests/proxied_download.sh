#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
UPDATES_UC="$LOGHORIZON_LIB/components/updates.uc"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

direct="$(ucode -L "$LOGHORIZON_LIB" "$UPDATES_UC" download-command \
  'https://example.com/list.srs' '/tmp/list.srs' '')"
proxy="$(ucode -L "$LOGHORIZON_LIB" "$UPDATES_UC" download-command \
  'https://example.com/list.srs' '/tmp/list.srs' '127.0.0.1:4534')"

grep -Fq "wget" <<<"$direct" || fail "direct downloads must keep using wget"
grep -Fq "https://example.com/list.srs" <<<"$direct" || fail "direct download lost its URL"
grep -Fq "curl" <<<"$proxy" || fail "proxied downloads must use curl"
grep -Fq "socks5h://127.0.0.1:4534" <<<"$proxy" || fail "proxied download must resolve names through SOCKS5"
grep -Fq -- "--fail" <<<"$proxy" || fail "proxied download must reject HTTP failures"
grep -Fq -- "--max-time" <<<"$proxy" || fail "proxied download must have a total timeout"
grep -Fq -- "--connect-timeout" <<<"$proxy" || fail "proxied download must have a connect timeout"
if grep -Fq "http_proxy=" <<<"$proxy"; then
  fail "proxied downloads must not use BusyBox wget's broken HTTP proxy path"
fi

# The proxied path has no downloader at all unless curl ships with the package.
grep -Fq '+curl' "$ROOT_DIR/loghorizon/Makefile" ||
  fail "curl must be a package dependency"

echo "proxied download checks passed"
