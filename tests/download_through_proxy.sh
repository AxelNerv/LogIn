#!/usr/bin/env bash
set -eo pipefail

# Downloads that travel through the service proxy used busybox wget with
# http_proxy set. On a redirect wget loses the address and asks the proxy
# itself for "/", which answers 400. Every GitHub release download redirects,
# so nothing that had to go through the tunnel ever arrived - community rule
# sets and user lists alike, quietly, for as long as the option was enabled.
#
# Measured on a live router against the same URL and the same proxy:
#   wget with http_proxy : Redirected to / on 127.0.0.1, HTTP error 400
#   curl over socks5h    : 264 bytes, success
#
# Direct downloads keep using wget: it works there, and curl gains nothing.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATES="$ROOT_DIR/loghorizon/files/usr/lib/components/updates.uc"
MAKEFILE="$ROOT_DIR/loghorizon/Makefile"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

grep -Fq 'function download_command(' "$UPDATES" ||
  fail "the download command must be chosen by whether a proxy is in play"

# Nothing may set http_proxy for wget any more: that is the broken path.
if grep -Fq 'http_proxy=' "$UPDATES"; then
  fail "wget must not be pointed at the proxy through the environment"
fi

awk '
  /function download_command\(/ { inside = 1 }
  inside && /"socks5h:\/\/"/ { socks = 1 }
  inside && /"curl"/ { curl = 1 }
  inside && /"--fail"/ { strict = 1 }
  inside && /^}/ { exit }
  END { exit (socks && curl && strict) ? 0 : 1 }
' "$UPDATES" ||
  fail "a proxied download must use curl over SOCKS and fail on an HTTP error"

# A hung download must not hold the update job open for ever.
awk '
  /function download_command\(/ { inside = 1 }
  inside && /--connect-timeout/ { connect = 1 }
  inside && /--max-time/ { total = 1 }
  inside && /^}/ { exit }
  END { exit (connect && total) ? 0 : 1 }
' "$UPDATES" ||
  fail "a proxied download must carry both a connect and a total timeout"

# Without a proxy the direct path stays on wget.
awk '
  /function download_command\(/ { inside = 1 }
  inside && /"wget"/ { wget = 1 }
  inside && /^}/ { exit }
  END { exit wget ? 0 : 1 }
' "$UPDATES" ||
  fail "a direct download must still use wget"

grep -Fq '+curl' "$MAKEFILE" ||
  fail "curl must be a package dependency, or the proxied path has no downloader"

printf 'proxied download checks passed\n'
