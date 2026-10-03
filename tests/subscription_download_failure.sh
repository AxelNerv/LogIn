#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/loghorizon/files/usr/lib"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
mkdir -p "$WORK_DIR/bin" "$WORK_DIR/cache"
cat >"$WORK_DIR/bin/curl" <<'SH'
#!/bin/sh
printf 'call\n' >> "$CURL_CALLS"
headers= output= max_time=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -D) headers=$2; shift 2;;
    -o) output=$2; shift 2;;
    --max-time) max_time=$2; shift 2;;
    *) shift;;
  esac
done
test "$max_time" = 20 || exit 99
printf 'HTTP/1.1 200 Connection established\r\n\r\nHTTP/2 %s\r\n\r\n' "$MOCK_HTTP" > "$headers"
printf 'error body\n' > "$output"
exit "$MOCK_CURL"
SH
chmod +x "$WORK_DIR/bin/curl"
cat >"$WORK_DIR/bin/logger" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >> "$SUB_TEST_LOG"
SH
chmod +x "$WORK_DIR/bin/logger"
export PATH="$WORK_DIR/bin:$PATH" CURL_CALLS="$WORK_DIR/calls"
export SUB_TEST_LOG="$WORK_DIR/log"
export TMP_SUBSCRIPTION_FOLDER="$WORK_DIR/cache" LOGHORIZON_LIB="$LIB"
for pair in '22 504' '28 000' '6 000' '60 000' '22 429'; do
  read -r MOCK_CURL MOCK_HTTP <<<"$pair"
  export MOCK_CURL MOCK_HTTP
  : > "$CURL_CALLS"
  : > "$SUB_TEST_LOG"
  printf '{"outbounds":[{"type":"hysteria2","tag":"previous"}]}\n' > "$WORK_DIR/previous.json"
  cp "$WORK_DIR/previous.json" "$WORK_DIR/expected.json"
  ucode -L "$LIB" "$LIB/subscription/cache.uc" download-source-check-fixture \
    'https://example.invalid/private-token' "$WORK_DIR/previous.json" >"$WORK_DIR/result" 2>"$WORK_DIR/stderr"
  grep -qx 1 "$WORK_DIR/result"
  test "$(wc -l < "$CURL_CALLS")" -eq 1
  cmp "$WORK_DIR/expected.json" "$WORK_DIR/previous.json"
  grep -Fq 'Subscription source unavailable' "$WORK_DIR/log"
  if grep -Eq 'private-token|No compatible subscription request profile' "$WORK_DIR/log"; then
    echo 'Unexpected secret or misleading compatibility error' >&2; exit 1
  fi
done
echo 'Subscription transient failure and cache preservation checks passed'
