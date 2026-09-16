#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
DIAGNOSTICS_UC="$LOGHORIZON_LIB/diagnostics/runtime.uc"
CLI="$ROOT_DIR/loghorizon/files/usr/bin/loghorizon"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

run_fixture() {
  printf '%s\n' "$1" | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-probe-classify-fixture
}

assert_contains() {
  local output="$1"
  local expected="$2"
  local label="$3"
  printf '%s\n' "$output" | grep -Fq "$expected" || fail "$label: expected $expected, got $output"
}

success="$(run_fixture '{"status":0,"output":"204\t0.020\t0.065\t0.080\n"}')"
assert_contains "$success" '"available":1' 'successful HTTPS probe'
assert_contains "$success" '"stage":"ok"' 'successful HTTPS stage'
assert_contains "$success" '"tcp_ms":20' 'TCP timing'
assert_contains "$success" '"tls_ms":45' 'TLS timing'
assert_contains "$success" '"total_ms":80' 'total timing'

server_response="$(run_fixture '{"status":0,"output":"403\t0.010\t0.030\t0.040"}')"
assert_contains "$server_response" '"available":1' 'HTTP response proves path availability'
assert_contains "$server_response" '"http_code":403' 'HTTP status is reported without treating it as blocking'

tcp_timeout="$(run_fixture '{"status":28,"output":"000\t0.000\t0.000\t4.001"}')"
assert_contains "$tcp_timeout" '"stage":"tcp"' 'TCP timeout stage'
assert_contains "$tcp_timeout" '"reason":"tcp_timeout"' 'TCP timeout reason'

tls_failure="$(run_fixture '{"status":35,"output":"000\t0.018\t0.000\t0.031"}')"
assert_contains "$tls_failure" '"stage":"tls"' 'TLS failure stage'
assert_contains "$tls_failure" '"reason":"tls_failed"' 'TLS failure reason'

http_timeout="$(run_fixture '{"status":28,"output":"000\t0.015\t0.055\t8.001"}')"
assert_contains "$http_timeout" '"stage":"http"' 'HTTP timeout stage'
assert_contains "$http_timeout" '"reason":"http_timeout"' 'HTTP timeout reason'

dns_failure="$(run_fixture '{"status":6,"output":"000\t0.000\t0.000\t0.002"}')"
assert_contains "$dns_failure" '"stage":"dns"' 'DNS failure stage'

grep -Fq 'check_connectivity_path: [ "diagnostics/runtime.uc", "check-connectivity-path", 0 ]' "$CLI" ||
  fail 'CLI must expose the bounded connectivity path diagnostic'

printf 'Connectivity diagnostics tests passed\n'
