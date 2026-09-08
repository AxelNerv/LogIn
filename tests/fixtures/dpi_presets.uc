#!/usr/bin/env ucode

let fs = require("fs");
let nfq = require("providers.nfqueue.validator");
let catalog = json(fs.readfile(ARGV[0]));

if (catalog.schema_version != 1 || type(catalog.presets) != "array" || length(catalog.presets) < 21)
    die("catalog is incomplete\n");

let ids = {};
let zapret = 0;
let zapret2 = 0;
for (let preset in catalog.presets) {
    if (type(preset) != "object" || preset.id == "" || preset.label == "" || preset.strategy == "")
        die("preset fields are incomplete\n");
    if (ids[preset.id]) die("duplicate preset id: " + preset.id + "\n");
    ids[preset.id] = true;
    if (preset.engine == "zapret") zapret++;
    else if (preset.engine == "zapret2") zapret2++;
    else die("unsupported preset engine: " + preset.engine + "\n");
    let result = nfq.validate_strategy(preset.engine == "zapret" ? "nfqws" : "nfqws2", preset.strategy, "");
    if (!result.valid) die("invalid preset " + preset.id + ": " + result.message + "\n");
}
if (zapret < 20 || zapret2 < 1) die("engine catalog coverage is incomplete\n");
print("DPI preset catalog checks passed\n");
