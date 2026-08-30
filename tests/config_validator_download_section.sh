#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
VALIDATOR="$ROOT_DIR/loghorizon/files/usr/lib/config/validator.uc"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

rows() {
  printf '%s\t%s\t%s\n' "$@"
}

assert_accepts() {
  local target="$1"
  local byedpi="$2"
  local zapret="$3"
  local zapret2="$4"
  shift 4

  rows "$@" | ucode -L "$LOGHORIZON_LIB" "$VALIDATOR" validate-download-section "$target" "$byedpi" "$zapret" "$zapret2"
}

assert_rejects() {
  local label="$1"
  local expected="$2"
  local target="$3"
  local byedpi="$4"
  local zapret="$5"
  local zapret2="$6"
  shift 6
  local output

  if output="$(rows "$@" | ucode -L "$LOGHORIZON_LIB" "$VALIDATOR" validate-download-section "$target" "$byedpi" "$zapret" "$zapret2" 2>/dev/null)"; then
    fail "$label should be rejected"
  fi

  printf '%s\n' "$output" | grep -Fq "$expected" ||
    fail "$label: expected message containing '$expected', got '$output'"
}

assert_accepts proxy 0 0 0 proxy 1 proxy
assert_accepts outbound 0 0 0 outbound 1 outbound
assert_accepts vpn 0 0 0 vpn 1 vpn
# ByeDPI runs a local proxy, but it is still a bypass engine that comes up
# with the service rather than before it, so downloads may not ride on it.
assert_rejects "byedpi is not a tunnel" "cannot provide an outbound" bye 1 0 0 bye 1 byedpi

assert_rejects "empty target" "no download section is selected" "" 0 0 0 proxy 1 proxy
assert_rejects "missing target" "references missing rule 'missing'" missing 0 0 0 proxy 1 proxy
assert_rejects "disabled target" "references disabled rule 'proxy'" proxy 0 0 0 proxy 0 proxy
# Zapret mangles packets on the direct path and offers no outbound at all, so
# it is refused whether or not the provider is installed. Routing the rule-set
# downloads through one stopped sing-box from starting on a live router.
assert_rejects "zapret is not an outbound" "cannot provide an outbound" zap 0 1 0 zap 1 zapret
assert_rejects "zapret2 is not an outbound" "cannot provide an outbound" zap2 0 0 1 zap2 1 zapret2
assert_rejects "unsupported action" "cannot provide an outbound" bypass 0 0 0 bypass 1 bypass

printf 'config validator download section checks passed\n'
