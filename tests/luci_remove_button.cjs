const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const path = require('node:path');
const source = fs.readFileSync(path.join(__dirname, '../luci-app-loghorizon/htdocs/luci-static/resources/view/loghorizon/section.js'), 'utf8');
let methods;
vm.runInNewContext(source.slice(source.indexOf('const SettingsUIDynamicList ='), source.indexOf('const ButtonAddSettingsUIDynamicList =')), {
  ui: { DynamicList: { extend: value => { methods = value; }, prototype: {addItem(){}} } },
  _: value => value,
  E: (tag, attrs, text) => ({tag, attrs, text}),
  findDynamicListItemByValue: dl => dl.item,
});
for (const disabled of [false, true]) {
  const children = [];
  const item = {querySelector: () => null, appendChild: child => children.push(child)};
  const dl = {item};
  let removed = 0;
  const widget = {options:{disabled,hasSettings:()=>false},removeItem:(root,node)=>{assert.equal(root,dl);assert.equal(node,item);removed++;}};
  methods.addItem.call(widget, dl, 'subscription', null, false);
  const button = children.find(child => child.attrs.class === 'lgh-dynlist-remove');
  assert.ok(button);
  assert.equal(button.tag, 'button');
  assert.equal(button.attrs.type, 'button');
  assert.equal(button.attrs.disabled, disabled);
  button.attrs.click({preventDefault(){},stopPropagation(){}});
  assert.equal(removed, disabled ? 0 : 1);
}
assert.ok(source.includes('o.childLegacyOption = "subscription_urls";'));
console.log('Theme-independent DynamicList remove checks passed');
