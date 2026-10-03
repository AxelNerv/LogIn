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
for (const engine of ['zapret', 'zapret2']) {
  const events = [];
  const node = { nodeName: 'TEXTAREA', value: '', dispatchEvent: event => events.push(event.type) };
  nodes.set(`widget.${engine}`, node);
  const preset = catalog.presets.find(item => item.engine === engine);
  assert.ok(preset);
  assert.equal(context.setDpiStrategyValue({cbid: id => id}, engine, preset.strategy), true);
  assert.equal(node.value, preset.strategy);
  assert.deepEqual(events, ['input', 'change']);
}
assert.equal(context.setDpiStrategyValue({cbid: id => id}, 'missing', 'new'), false);
assert.equal(context.setDpiStrategyValue(null, 'zapret', 'new'), false);
console.log('DPI preset textarea regression checks passed');
