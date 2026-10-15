const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/section.js'), 'utf8');
const helper = source.slice(source.indexOf('function setDpiStrategyValue('), source.indexOf('\nfunction rejectStrategyValidation('));
const catalog = JSON.parse(fs.readFileSync(path.join(__dirname, '../loghorizon/files/usr/lib/dpi-presets.json'), 'utf8'));
const nodes = new Map();
const context = { Event, document: { getElementById: id => nodes.get(id) || null }, getOptionTextarea: () => null };
vm.createContext(context);
vm.runInContext(helper, context);
// Real LuCI Textarea lacks setValue(); input/change must still reach the form
// and the strategy annotations, without updating UCI before Save.
assert.deepEqual(catalog.presets.map(item => item.id), ['login-youtube-mgts', 'login-discord-mgts']);
assert.ok(catalog.presets.every(item => item.engine === 'zapret'));
const discord = catalog.presets.find(item => item.id === 'login-discord-mgts');
const voice = discord.strategy.split(' --new ').at(-1);
assert.ok(voice.includes('--dpi-desync-any-protocol=1'));
assert.ok(voice.includes('--dpi-desync-cutoff=d6'));
assert.ok(voice.includes('--dpi-desync-repeats=2'));
assert.ok(!voice.includes('--filter-l7='));
for (const preset of catalog.presets) {
  const engine = preset.id;
  const events = [];
  const node = { nodeName: 'TEXTAREA', value: '', dispatchEvent: event => events.push(event.type) };
  nodes.set(`widget.${engine}`, node);
  assert.equal(context.setDpiStrategyValue({cbid: id => id}, engine, preset.strategy), true);
  assert.equal(node.value, preset.strategy);
  assert.deepEqual(events, ['input', 'change']);
}
assert.equal(context.setDpiStrategyValue({cbid: id => id}, 'missing', 'new'), false);
assert.equal(context.setDpiStrategyValue(null, 'zapret', 'new'), false);
console.log('DPI preset textarea regression checks passed');
