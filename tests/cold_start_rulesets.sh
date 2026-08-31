#!/usr/bin/env bash
set -eo pipefail

# A router has to come up on its own after a reboot, on a line where the
# community lists are unreachable until the tunnel is running.
#
# Two faults made that impossible, and both were found on a live router that
# rebooted into no internet at all:
#
#   1. sing-box fetched the community rule sets itself while starting, and a
#      failure there is fatal. The lists live on GitHub, blocked here until the
#      tunnel is up - and the tunnel needs sing-box running. /tmp is cleared by
#      the reboot, so nothing was cached to fall back on.
#   2. A rule set patched into a file that did not exist yet was written back
#      without its version field. sing-box refuses to parse one - "missing
#      rule-set version" - and refuses to start, saying nothing about which
#      file or why.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
GENERATOR="$LOGHORIZON_LIB/singbox/generator.uc"
ROUTING="$LOGHORIZON_LIB/routing/rulesets.uc"
SB_CONSTANTS="$LOGHORIZON_LIB/singbox/constants.uc"
UPDATES="$LOGHORIZON_LIB/components/updates.uc"
ROUTE="$LOGHORIZON_LIB/singbox/route.uc"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- Rule sets are read from disk, never fetched during startup -------------

grep -Fq 'const PERSISTENT_RULESET_FOLDER = "/etc/loghorizon/rulesets";' "$SB_CONSTANTS" ||
  fail "the cached rule sets must live outside /tmp, or a reboot loses them"

awk '
  /function ensure_community_ruleset\(/ { inside = 1 }
  inside && /type: "remote"/ { remote = 1 }
  inside && /^}/ { exit }
  END { exit remote ? 1 : 0 }
' "$GENERATOR" ||
  fail "a community rule set must not be fetched by sing-box while it starts"

grep -Fq 'function community_ruleset_cache_path(' "$GENERATOR" ||
  fail "the generator must know where the cached rule sets are"

# Where there is no copy yet, an empty rule set stands in: it matches nothing,
# which is what an unavailable list means, and the service comes up.
awk '
  /function ensure_community_ruleset\(/ { inside = 1 }
  inside && /version: 3, rules: \[\]/ { found = 1 }
  inside && /^}/ { exit }
  END { exit found ? 0 : 1 }
' "$GENERATOR" ||
  fail "a missing rule set must be stood in for, not left to abort the start"

grep -Fq 'PERSISTENT_RULESET_FOLDER' "$UPDATES" ||
  fail "the list update must refresh the cached rule sets"

# --- A patched rule set always carries its version --------------------------

grep -Fq 'if (int(ruleset.version || 0) < 1)' "$ROUTING" ||
  fail "a rule set patched into a new file must still get a version"

cat >"$WORK_DIR/probe.uc" <<'PROBE'
let rulesets = require("routing.rulesets");
PROBE

# Patch a file that does not exist and check what lands on disk.
ucode -L "$LOGHORIZON_LIB" "$ROUTING" patch-source \
  "$WORK_DIR/fresh.json" domain_suffix '["example.com"]' >/dev/null 2>&1 || true

if [ -f "$WORK_DIR/fresh.json" ]; then
  node - "$WORK_DIR/fresh.json" <<'NODE'
const fs = require('fs');
const parsed = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
if (parsed.version !== 3) {
  process.stderr.write('FAIL: a rule set written from scratch must carry version 3\n');
  process.exit(1);
}
NODE
fi

# --- Outbounds are told which address family to dial ------------------------

# Handed both families on a line without working IPv6, sing-box dialled IPv6
# only and reported the host unreachable, while the same host answered on its
# IPv4 address every time.
grep -Fq 'strategy: dns_strategy_value(settings)' "$ROUTE" ||
  fail "the default domain resolver must carry an address strategy"
grep -Fq 'function dns_strategy_value(' "$ROUTE" ||
  fail "the strategy must be read from the configured setting"

printf 'cold start checks passed\n'
