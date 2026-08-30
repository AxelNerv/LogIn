#!/usr/bin/env bash
set -eo pipefail

# podkop kept list references in options of its own: remote_domain_lists,
# local_domain_lists and their subnet counterparts. logIn expresses the same
# thing through rule sets for the binary formats and plain-text lists
# otherwise, and the sing-box config generator refuses a section that still
# carries the old names.
#
# The validator does not reject them, so a router migrated from podkop passed
# every check and then never started, with only "section has unsupported
# matcher remote_domain_lists" in the log to explain it.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGHORIZON_LIB="$ROOT_DIR/loghorizon/files/usr/lib"
MIGRATION="$LOGHORIZON_LIB/config/migration.uc"
GENERATOR="$LOGHORIZON_LIB/singbox/generator.uc"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# --- Everything the generator refuses must have a migration -----------------

# If the generator gains another refused option without a conversion, a
# migrated router will fail to start the same way. Keep the two lists paired.
for option_name in remote_domain_lists local_domain_lists \
  remote_subnet_lists local_subnet_lists; do
  grep -Fq "\"$option_name\"" "$GENERATOR" ||
    fail "the generator no longer mentions $option_name; check this pairing"
  grep -Fq "\"$option_name\"" "$MIGRATION" ||
    fail "$option_name is refused by the generator but no migration converts it"
done

grep -Fq '{ id: "legacy_list_options", run: migrate_legacy_list_options }' "$MIGRATION" ||
  fail "the migration must be registered so it runs once per configuration"

# --- Run it over a configuration that carries the old options ---------------

cat >"$WORK_DIR/fixture.json" <<'JSON'
{
  "settings": {
    ".name": "settings",
    ".type": "settings",
    "config_version": "1.0.5"
  },
  "section": [
    {
      ".name": "mixed",
      ".type": "section",
      "enabled": "1",
      "action": "block",
      "rule_set": [ "https://example.com/existing.srs" ],
      "domain_ip_lists": [ "https://example.com/existing.lst" ],
      "remote_domain_lists": [
        "https://example.com/rules.srs",
        "https://example.com/list.lst",
        "https://example.com/tagged.srs?token=1"
      ],
      "remote_subnet_lists": [ "https://example.com/subnets.json" ],
      "local_domain_lists": [ "/etc/lists/local.lst" ],
      "local_subnet_lists": [ "/etc/lists/local.srs" ]
    },
    {
      ".name": "untouched",
      ".type": "section",
      "enabled": "1",
      "action": "block",
      "rule_set": [ "https://example.com/only.srs" ]
    }
  ]
}
JSON

LOGHORIZON_LIB="$LOGHORIZON_LIB" ucode -L "$LOGHORIZON_LIB" "$MIGRATION" \
  migrate-fixture "$WORK_DIR/fixture.json" >"$WORK_DIR/output.json" ||
  fail "the migration failed to run over the fixture"

node - "$WORK_DIR/output.json" <<'NODE'
const fs = require('fs');
const out = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const sections = Object.fromEntries(
  out.config.section.map((section) => [section['.name'], section]),
);

const fail = (message) => {
  process.stderr.write(`FAIL: ${message}\n`);
  process.exit(1);
};

const list = (section, key) => {
  const value = section[key];
  if (value === undefined) return [];
  return Array.isArray(value) ? value : [value];
};

const mixed = sections.mixed;
if (!mixed) fail('the migrated section disappeared');

for (const legacy of [
  'remote_domain_lists',
  'local_domain_lists',
  'remote_subnet_lists',
  'local_subnet_lists',
]) {
  if (mixed[legacy] !== undefined) {
    fail(`${legacy} survived the migration; the generator will still refuse it`);
  }
}

const ruleSets = list(mixed, 'rule_set');
for (const expected of [
  'https://example.com/existing.srs',
  'https://example.com/rules.srs',
  'https://example.com/tagged.srs?token=1',
]) {
  if (!ruleSets.includes(expected)) fail(`rule_set is missing ${expected}`);
}

// Subnet lists carry addresses, so a binary one belongs with the rule sets
// allowed to contain them, whatever its extension.
const subnetRuleSets = list(mixed, 'rule_set_with_subnets');
for (const expected of [
  'https://example.com/subnets.json',
  '/etc/lists/local.srs',
]) {
  if (!subnetRuleSets.includes(expected)) {
    fail(`rule_set_with_subnets is missing ${expected}`);
  }
}

const plain = list(mixed, 'domain_ip_lists');
for (const expected of [
  'https://example.com/existing.lst',
  'https://example.com/list.lst',
  '/etc/lists/local.lst',
]) {
  if (!plain.includes(expected)) fail(`domain_ip_lists is missing ${expected}`);
}

if (new Set(ruleSets).size !== ruleSets.length) {
  fail('rule_set gained duplicate entries');
}

const untouched = list(sections.untouched, 'rule_set');
if (untouched.length !== 1 || untouched[0] !== 'https://example.com/only.srs') {
  fail('a section without legacy options must be left alone');
}

const applied = out.config.settings?.applied_migrations ?? [];
const appliedList = Array.isArray(applied) ? applied : [applied];
if (!appliedList.includes('legacy_list_options')) {
  fail('the migration must record itself so it does not run twice');
}

process.stdout.write('fixture checks passed\n');
NODE

printf 'legacy list migration checks passed\n'
