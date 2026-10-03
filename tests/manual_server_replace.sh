#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT_DIR/loghorizon/files/usr/lib"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT
node - "$WORK_DIR" <<'JS'
const fs = require('node:fs');
const root = process.argv[2];
const fixture = {
  settings:{'.name':'settings','.type':'settings',dns_server:'1.1.1.1'},
  section:[{'.name':'main','.type':'section',enabled:'1',action:'connection',
    selector_proxy_links:['hysteria2://test@192.0.2.1:443?insecure=1#first',
      'vless://00000000-0000-4000-8000-000000000001@192.0.2.2:443?type=tcp#old-vless']}],
};
fs.writeFileSync(root+'/before.json', JSON.stringify(fixture));
fixture.section[0].selector_proxy_links[1] = 'hysteria2://test@192.0.2.2:443?insecure=1#replacement';
fixture.section[0].selector_proxy_links.push('hysteria2://test@192.0.2.3:443?insecure=1#third');
fs.writeFileSync(root+'/after.json', JSON.stringify(fixture));
JS
ucode -L "$LIB" "$LIB/singbox/generator.uc" generate-config-fixture "$WORK_DIR/before.json" "$WORK_DIR/out.json" 127.0.0.1 false true
ucode -L "$LIB" "$LIB/singbox/generator.uc" generate-config-fixture "$WORK_DIR/after.json" "$WORK_DIR/out.json" 127.0.0.1 false true
node - "$WORK_DIR" <<'JS'
const fs = require('node:fs');
const assert = require('node:assert/strict');
const root = process.argv[2];
const config = JSON.parse(fs.readFileSync(root+'/out.json'));
const cache = JSON.parse(fs.readFileSync(root+'/out.json.section-cache/main.json'));
const servers = config.outbounds.filter(item => /^main-\d+-out$/.test(item.tag));
assert.equal(servers.length, 3);
assert.ok(servers.every(item=>item.type==='hysteria2'));
assert.equal(cache.outboundMetadata.names['main-2-out'], 'replacement');
assert.equal(cache.outboundMetadata.names['main-3-out'], 'third');
assert.equal(cache.outboundMetadata.protocols['main-2-out'], 'hysteria2');
assert.equal(Object.keys(cache.links).length, 3);
console.log('Manual server replacement and third server checks passed');
JS
