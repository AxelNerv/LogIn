#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/loghorizon/files/usr/lib"
ucode -L "$LIB" "$LIB/config/migration.uc" migrate-fixture "$ROOT_DIR/tests/fixtures/plain_ruleset_migration.json" | node -e '
const assert = require("node:assert/strict");
let input = "";
process.stdin.on("data", data => input += data);
process.stdin.on("end", () => {
  const result = JSON.parse(input);
  const rules = result.config.rule || result.config.section;
  const rule = rules.find(item => item[".name"] === "discord");
  assert.deepEqual(rule.rule_set, ["https://example.com/valid.srs", "https://example.com/download"]);
  assert.deepEqual(rule.rule_set_with_subnets, ["https://example.com/subnets.json"]);
  assert.deepEqual(rule.domain_ip_lists, ["https://example.com/domains.TXT?token=1#x", "/etc/ips.list"]);
  const plain = rules.find(item => item[".name"] === "plain-only");
  assert.equal(plain.rule_set, undefined);
  assert.deepEqual(plain.domain_ip_lists, ["https://example.com/all.lst"]);
  assert.ok(result.config.settings.applied_migrations.includes("plain_ruleset_references"));
  console.log("Misplaced plain rule-set migration checks passed");
});'
for reference in 'https://example.org/domains.txt' '/etc/ips.list'; do
  if ucode -L "$LIB" "$LIB/config/validator.uc" ruleset-reference-valid "$reference"; then
    echo "Plain list unexpectedly accepted as binary rule set" >&2
    exit 1
  fi
  ucode -L "$LIB" "$LIB/config/validator.uc" plain-domain-ip-list-reference-valid "$reference"
done
