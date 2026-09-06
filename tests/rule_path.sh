#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UCODE_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
CHECK="$UCODE_LIB/diagnostics/rule_path.uc"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir -p "$WORK_DIR/bin"

cat >"$WORK_DIR/uci.uc" <<'UCODE'
function get(path) {
    if (path == "loghorizon.wanted.enabled") return "1";
    if (path == "loghorizon.wanted.action") return "connection";
    if (path == "loghorizon.dpi.enabled") return "1";
    if (path == "loghorizon.dpi.action") return "zapret";
    return null;
}
return { get };
UCODE

cat >"$WORK_DIR/config.json" <<JSON
{
  "route": {
    "rules": [
      { "action": "route", "inbound": ["tproxy-in"], "outbound": "other-out", "rule_set": "other-set" },
      { "action": "route", "inbound": ["tproxy-in"], "outbound": "wanted-out", "rule_set": "wanted-set" },
      { "action": "route", "inbound": ["tproxy-in"], "outbound": "dpi-out", "domain_suffix": "dpi.example" }
    ],
    "rule_set": [
      { "type": "local", "tag": "other-set", "format": "source", "path": "$WORK_DIR/other.json" },
      { "type": "local", "tag": "wanted-set", "format": "binary", "path": "$WORK_DIR/wanted.srs" }
    ]
  },
  "dns": {
    "rules": [
      { "action": "route", "server": "fakeip-server", "rule_set": "wanted-set" },
      { "action": "route", "server": "dnsmasq-server", "domain_suffix": "dpi.example" }
    ]
  },
  "outbounds": [
    { "type": "selector", "tag": "wanted-out" },
    { "type": "direct", "tag": "dpi-out" },
    { "type": "direct", "tag": "other-out" }
  ]
}
JSON
printf '{}\n' >"$WORK_DIR/other.json"
printf 'binary\n' >"$WORK_DIR/wanted.srs"

cat >"$WORK_DIR/bin/sing-box" <<'SH'
#!/bin/sh
case "$*" in
  *wanted.srs*wanted.example*) echo 'match rules.[0]' ;;
  *other.json*intercepted.example*) echo 'match rules.[0]' ;;
esac
exit 0
SH
cat >"$WORK_DIR/bin/dig" <<'SH'
#!/bin/sh
case "$*" in
  *dpi.example*) echo 198.18.0.5 ;;
  *) echo 198.18.1.10 ;;
esac
SH
cat >"$WORK_DIR/bin/loghorizon" <<'SH'
#!/bin/sh
printf '{"delay":42}\n'
SH
chmod +x "$WORK_DIR/bin/"*

run_check() {
  LOGHORIZON_RULE_PATH_CONFIG="$WORK_DIR/config.json" \
  LOGHORIZON_RULE_PATH_SING_BOX="$WORK_DIR/bin/sing-box" \
  LOGHORIZON_RULE_PATH_DIG="$WORK_DIR/bin/dig" \
  LOGHORIZON_RULE_PATH_BIN="$WORK_DIR/bin/loghorizon" \
    ucode -L "$UCODE_LIB" -L "$WORK_DIR" -- "$CHECK" run "$1" "$2"
}

if ! output="$(run_check wanted wanted.example 2>&1)"; then
  printf '%s\n' "$output" >&2
  fail "valid route failed"
fi
grep -Fq '"success":true' <<<"$output" || fail "success result missing"
grep -Fq 'rule_set:wanted-set' <<<"$output" || fail "ruleset matcher missing"
grep -Fq '"delay":42' <<<"$output" || fail "API delay missing"

if output="$(run_check wanted intercepted.example 2>&1)"; then
  fail "intercepted route passed"
fi
grep -Fq 'intercepted by another section' <<<"$output" || fail "interception was not reported"
grep -Fq '"actual_outbound":"other-out"' <<<"$output" || fail "intercepting outbound missing"

if output="$(run_check dpi dpi.example 2>&1)"; then
  fail "unexpected FakeIP answer passed"
fi
grep -Fq 'stale or unexpected FakeIP' <<<"$output" || fail "FakeIP mismatch missing"

printf 'Rule path tests passed\n'
