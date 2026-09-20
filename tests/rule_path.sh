#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UCODE_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
CHECK="$UCODE_LIB/diagnostics/rule_path.uc"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }
mkdir -p "$WORK_DIR/bin"

cat >"$WORK_DIR/uci.state" <<'STATE'
loghorizon.wanted.enabled=1
loghorizon.wanted.action=connection
loghorizon.dpi.enabled=1
loghorizon.dpi.action=zapret
STATE

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
  LOGHORIZON_UCI_STATE_FILE="$WORK_DIR/uci.state" \
  LOGHORIZON_RULE_PATH_SING_BOX="$WORK_DIR/bin/sing-box" \
  LOGHORIZON_RULE_PATH_DIG="$WORK_DIR/bin/dig" \
  LOGHORIZON_RULE_PATH_BIN="$WORK_DIR/bin/loghorizon" \
    ucode -L "$UCODE_LIB" -L "$WORK_DIR" -- "$CHECK" run "$1" "$2"
}

if ! output="$(run_check wanted wanted.example 2>&1)"; then
  printf '%s\n' "$output" >&2
  fail "valid route failed"
fi
grep -Fq '"success": true' <<<"$output" || fail "success result missing"
grep -Fq 'rule_set:wanted-set' <<<"$output" || fail "ruleset matcher missing"
grep -Fq '"delay": 42' <<<"$output" || fail "API delay missing"

if output="$(run_check wanted intercepted.example 2>&1)"; then
  fail "intercepted route passed"
fi
grep -Fq 'intercepted by another section' <<<"$output" || fail "interception was not reported"
grep -Fq '"actual_outbound": "other-out"' <<<"$output" || fail "intercepting outbound missing"

if output="$(run_check dpi dpi.example 2>&1)"; then
  fail "unexpected FakeIP answer passed"
fi
grep -Fq 'stale or unexpected FakeIP' <<<"$output" || fail "FakeIP mismatch missing"

cat >"$WORK_DIR/config.json" <<JSON
{
  "route": {
    "rules": [
      { "action": "reject", "domain": "blocked.example", "method": "drop" },
      { "action": "route", "outbound": "wanted-out", "domain": "blocked.example" }
    ]
  },
  "dns": { "rules": [{ "action": "route", "server": "fakeip-server", "domain": "blocked.example" }] },
  "outbounds": [{ "type": "selector", "tag": "wanted-out" }]
}
JSON
if output="$(run_check wanted blocked.example 2>&1)"; then
  fail "route hidden behind an earlier reject passed"
fi
grep -Fq 'rejected by an earlier generated route rule' <<<"$output" ||
  fail "preceding route reject was not reported"

cat >"$WORK_DIR/config.json" <<JSON
{
  "route": {
    "rules": [{
      "action": "route", "outbound": "wanted-out", "domain": "conditional.example",
      "source_ip_cidr": "192.0.2.10/32", "port": 443, "network": "tcp", "invert": false
    }]
  },
  "dns": { "rules": [{ "action": "route", "server": "fakeip-server", "domain": "conditional.example" }] },
  "outbounds": [{ "type": "selector", "tag": "wanted-out" }]
}
JSON
if output="$(run_check wanted conditional.example 2>&1)"; then
  fail "conditional route passed without the required flow context"
fi
grep -Fq 'cannot verify route rule with unsupported conditions' <<<"$output" ||
  fail "conditional route did not become indeterminate"
for condition in source_ip_cidr port network invert; do
  if [ "$condition" = source_ip_cidr ]; then
    grep -Fq "$condition" <<<"$output" || fail "missing unsupported condition: $condition"
  else
    grep -Fq "unsupported conditions: $condition" <<<"$output" &&
      fail "known HTTPS flow condition remained unsupported: $condition"
  fi
done

cat >"$WORK_DIR/config.json" <<JSON
{
  "route": {
    "rules": [
      { "action": "reject", "protocol": "quic", "method": "drop" },
      { "action": "route", "outbound": "wanted-out", "domain": "https.example", "network": "tcp", "protocol": "tls", "port": 443 }
    ]
  },
  "dns": { "rules": [{ "action": "route", "server": "fakeip-server", "domain": "https.example" }] },
  "outbounds": [{ "type": "selector", "tag": "wanted-out" }]
}
JSON
if ! output="$(run_check wanted https.example 2>&1)"; then
  printf '%s\n' "$output" >&2
  fail "HTTPS route was hidden by a QUIC-only reject"
fi
grep -Fq '"network": "tcp", "protocol": "tls", "port": 443' <<<"$output" ||
  fail "diagnostic result does not disclose its HTTPS flow context"

cat >"$WORK_DIR/config.json" <<JSON
{
  "route": {
    "rules": [{ "action": "route", "outbound": "wanted-out", "domain": "dns-error.example" }],
    "rule_set": []
  },
  "dns": {
    "rules": [{ "action": "route", "server": "fakeip-server", "rule_set": "missing" }]
  },
  "outbounds": [{ "type": "selector", "tag": "wanted-out" }]
}
JSON
if output="$(run_check wanted dns-error.example 2>&1)"; then
  fail "DNS ruleset inspection error passed because the domain resolved"
fi
grep -Fq 'cannot inspect DNS rule set missing' <<<"$output" ||
  fail "DNS ruleset inspection error was not reported"
grep -Fq '"name": "dns", "success": false' <<<"$output" ||
  fail "DNS inspection failure did not fail the DNS step"

cat >"$WORK_DIR/config.json" <<JSON
{
  "route": {
    "rules": [{ "action": "route", "outbound": "wanted-out", "domain": "health-shadow.example" }]
  },
  "dns": {
    "rules": [
      { "action": "route", "server": "health-server", "inbound": "dns-health-primary-in" },
      { "action": "route", "server": "fakeip-server", "domain": "health-shadow.example" }
    ]
  },
  "outbounds": [{ "type": "selector", "tag": "wanted-out" }]
}
JSON
if ! output="$(run_check wanted health-shadow.example 2>&1)"; then
  printf '%s\n' "$output" >&2
  fail "inbound-scoped DNS health rule hid the ordinary client rule"
fi
grep -Fq '"server": "fakeip-server"' <<<"$output" ||
  fail "ordinary client DNS rule was not selected after health rule"

printf 'Rule path tests passed\n'
