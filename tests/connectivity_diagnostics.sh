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
assert_contains "$success" '"available": 1' 'successful HTTPS probe'
assert_contains "$success" '"stage": "ok"' 'successful HTTPS stage'
assert_contains "$success" '"tcp_ms": 20' 'TCP timing'
assert_contains "$success" '"tls_ms": 45' 'TLS timing'
assert_contains "$success" '"total_ms": 80' 'total timing'

server_response="$(run_fixture '{"status":0,"output":"403\t0.010\t0.030\t0.040"}')"
assert_contains "$server_response" '"available": 1' 'HTTP response proves path availability'
assert_contains "$server_response" '"http_code": 403' 'HTTP status is reported without treating it as blocking'

tcp_timeout="$(run_fixture '{"status":28,"output":"000\t0.000\t0.000\t4.001"}')"
assert_contains "$tcp_timeout" '"stage": "tcp"' 'TCP timeout stage'
assert_contains "$tcp_timeout" '"reason": "tcp_timeout"' 'TCP timeout reason'

tls_failure="$(run_fixture '{"status":35,"output":"000\t0.018\t0.000\t0.031"}')"
assert_contains "$tls_failure" '"stage": "tls"' 'TLS failure stage'
assert_contains "$tls_failure" '"reason": "tls_failed"' 'TLS failure reason'

http_timeout="$(run_fixture '{"status":28,"output":"000\t0.015\t0.055\t8.001"}')"
assert_contains "$http_timeout" '"stage": "http"' 'HTTP timeout stage'
assert_contains "$http_timeout" '"reason": "http_timeout"' 'HTTP timeout reason'

dns_failure="$(run_fixture '{"status":6,"output":"000\t0.000\t0.000\t0.002"}')"
assert_contains "$dns_failure" '"stage": "dns"' 'DNS failure stage'

resources="$(printf '%s\n' '{"before":{"cpu":{"total":1000,"idle":800},"memory":{"total_kib":262144,"available_kib":131072},"load":{"one":"0.10","five":"0.20","fifteen":"0.30"},"conntrack":{"count":100,"max":16384},"nfqueue":{"available":1,"queues":2,"queued":0,"kernel_dropped":10,"userspace_dropped":3},"interfaces":[{"name":"wan","rx_dropped":20,"tx_dropped":5,"qdisc":{"available":1,"backlog_bytes":0,"backlog_packets":0,"requeues":0}}]},"after":{"cpu":{"total":1200,"idle":940},"memory":{"total_kib":262144,"available_kib":126976},"load":{"one":"0.20","five":"0.20","fifteen":"0.30"},"conntrack":{"count":110,"max":16384},"nfqueue":{"available":1,"queues":2,"queued":1,"kernel_dropped":12,"userspace_dropped":4},"interfaces":[{"name":"wan","rx_dropped":21,"tx_dropped":5,"qdisc":{"available":1,"backlog_bytes":1200,"backlog_packets":2,"requeues":1}}]}}' | ucode -L "$LOGHORIZON_LIB" "$DIAGNOSTICS_UC" connectivity-resource-fixture)"
assert_contains "$resources" '"cpu_percent": 30' 'CPU usage across diagnostic window'
assert_contains "$resources" '"kernel_dropped_delta": 2' 'NFQUEUE kernel drop delta'
assert_contains "$resources" '"userspace_dropped_delta": 1' 'NFQUEUE userspace drop delta'
assert_contains "$resources" '"rx_dropped_delta": 1' 'interface drop delta'
assert_contains "$resources" '"backlog_packets": 2' 'qdisc backlog snapshot'

grep -Fq 'check_connectivity_path: [ "diagnostics/runtime.uc", "check-connectivity-path", 0 ]' "$CLI" ||
  fail 'CLI must expose the bounded connectivity path diagnostic'

printf 'Connectivity diagnostics tests passed\n'
