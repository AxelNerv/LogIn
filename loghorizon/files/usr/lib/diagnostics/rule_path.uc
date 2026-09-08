#!/usr/bin/env ucode

let fs = require("fs");
let uci = require("core.uci");

const CONFIG_NAME = getenv("LOGHORIZON_CONFIG_NAME") || "loghorizon";
const CONFIG_PATH = getenv("LOGHORIZON_RULE_PATH_CONFIG") || "/etc/sing-box/config.json";
const SING_BOX_BIN = getenv("LOGHORIZON_RULE_PATH_SING_BOX") || "/usr/bin/sing-box";
const DIG_BIN = getenv("LOGHORIZON_RULE_PATH_DIG") || "dig";
const LOGHORIZON_BIN = getenv("LOGHORIZON_RULE_PATH_BIN") || "/usr/bin/loghorizon";
const TEST_TIMEOUT = getenv("LOGHORIZON_RULE_PATH_TIMEOUT") || "8000";

function as_string(value) {
    return value == null ? "" : "" + value;
}

function as_array(value) {
    if (type(value) == "array") return value;
    if (value == null) return [];
    return [ value ];
}

function shell_quote(value) {
    return "'" + replace(as_string(value), /'/g, "'\\''") + "'";
}

function command_from_args(args) {
    let parts = [];
    for (let arg in args) push(parts, shell_quote(arg));
    return join(" ", parts);
}

function command_capture(args, merge_stderr) {
    let command = command_from_args(args) + (merge_stderr ? " 2>&1" : " 2>/dev/null");
    let pipe = fs.popen(command, "r");
    if (!pipe) return { status: 127, output: "" };
    let output = as_string(pipe.read("all"));
    let status = int(pipe.close());
    if (status > 255) status = int(status / 256);
    return { status, output: trim(output) };
}

function step(name, success, message, details) {
    let value = { name, success: success === true, message: as_string(message) };
    if (details != null) value.details = details;
    return value;
}

function valid_domain(domain) {
    return domain != "" && length(domain) <= 253 && match(domain, /[^A-Za-z0-9.-]/) == null &&
        substr(domain, 0, 1) != "." && substr(domain, length(domain) - 1) != ".";
}

function contains(values, needle) {
    needle = as_string(needle);
    for (let value in as_array(values))
        if (as_string(value) == needle) return true;
    return false;
}

function suffix_match(domain, suffix) {
    domain = lc(domain);
    suffix = lc(as_string(suffix));
    return suffix != "" && (domain == suffix ||
        (length(domain) > length(suffix) && substr(domain, length(domain) - length(suffix) - 1) == "." + suffix));
}

function direct_domain_match(rule, domain) {
    domain = lc(domain);
    for (let value in as_array(rule.domain))
        if (lc(as_string(value)) == domain) return "domain";
    for (let value in as_array(rule.domain_suffix))
        if (suffix_match(domain, value)) return "domain_suffix";
    for (let value in as_array(rule.domain_keyword))
        if (index(domain, lc(as_string(value))) >= 0) return "domain_keyword";
    for (let value in as_array(rule.domain_regex))
        if (match(domain, regexp(as_string(value))) != null) return "domain_regex";
    return "";
}

function ruleset_map(config) {
    let result = {};
    for (let item in as_array(config.route && config.route.rule_set))
        if (type(item) == "object" && as_string(item.tag) != "") result[item.tag] = item;
    return result;
}

function ruleset_match(item, domain) {
    if (type(item) != "object") return { matched: false, error: "rule set is missing from generated config" };
    if (as_string(item.type) != "local") return { matched: false, error: "remote rule set has no local test path" };
    let path = as_string(item.path);
    let format = as_string(item.format || "source");
    let stat = fs.stat(path);
    if (stat == null || int(stat.size || 0) <= 0)
        return { matched: false, error: "rule set file is missing or empty", path, format };
    let result = command_capture([ SING_BOX_BIN, "rule-set", "match", path, domain, "-f", format ], true);
    if (result.status != 0)
        return { matched: false, error: result.output != "" ? result.output : "sing-box rule-set match failed", path, format };
    return { matched: result.output != "", path, format };
}

function rule_allows_tproxy(rule) {
    let inbounds = as_array(rule.inbound);
    return length(inbounds) == 0 || contains(inbounds, "tproxy-in") || contains(inbounds, "tproxy6-in");
}

function unsupported_rule_keys(rule, allowed) {
    let result = [];
    for (let key in keys(rule)) {
        if (key == "invert" && rule[key] !== true) continue;
        if (!allowed[key]) push(result, key);
    }
    return result;
}

function value_matches(values, expected) {
    expected = as_string(expected);
    for (let value in as_array(values))
        if (as_string(value) == expected) return true;
    return false;
}

function port_range_matches(values, port) {
    port = int(port);
    for (let value in as_array(values)) {
        let bounds = split(as_string(value), ":");
        if (length(bounds) == 2 && port >= int(bounds[0]) && port <= int(bounds[1])) return true;
    }
    return false;
}

function rule_matches_flow_context(rule, context) {
    if (rule.network != null && !value_matches(rule.network, context.network)) return false;
    if (rule.protocol != null && !value_matches(rule.protocol, context.protocol)) return false;
    if (rule.port != null && !value_matches(rule.port, context.port)) return false;
    if (rule.port_range != null && !port_range_matches(rule.port_range, context.port)) return false;
    if (rule.ip_version != null && !value_matches(rule.ip_version, context.ip_version)) return false;
    return true;
}

function has_domain_matchers(rule) {
    return length(as_array(rule.domain)) > 0 || length(as_array(rule.domain_suffix)) > 0 ||
        length(as_array(rule.domain_keyword)) > 0 || length(as_array(rule.domain_regex)) > 0 ||
        length(as_array(rule.rule_set)) > 0;
}

const ROUTE_RULE_KEYS = {
    action: true, outbound: true, inbound: true,
    domain: true, domain_suffix: true, domain_keyword: true, domain_regex: true, rule_set: true,
    network: true, protocol: true, port: true, port_range: true, ip_version: true,
    method: true, no_drop: true
};

const DNS_RULE_KEYS = {
    action: true, server: true, query_type: true,
    domain: true, domain_suffix: true, domain_keyword: true, domain_regex: true, rule_set: true,
    disable_cache: true, rewrite_ttl: true, client_subnet: true
};

function find_route(config, domain, context) {
    let sets = ruleset_map(config);
    let checked_sets = [];
    let index_value = -1;
    for (let rule in as_array(config.route && config.route.rules)) {
        index_value++;
        if (type(rule) != "object" || !rule_allows_tproxy(rule))
            continue;
        let action = as_string(rule.action);
        if (action != "route" && action != "reject") continue;
        let direct = direct_domain_match(rule, domain);
        let matcher = direct;
        for (let tag in as_array(rule.rule_set)) {
            tag = as_string(tag);
            let result = ruleset_match(sets[tag], domain);
            push(checked_sets, { tag, matched: result.matched, error: result.error || "", path: result.path || "" });
            if (result.error != null && result.error != "")
                return { found: false, error: "cannot inspect rule set " + tag + ": " + result.error, checked_sets };
            if (result.matched && matcher == "") matcher = "rule_set:" + tag;
        }
        if (!rule_matches_flow_context(rule, context)) continue;
        let unsupported = unsupported_rule_keys(rule, ROUTE_RULE_KEYS);
        if (matcher == "" && has_domain_matchers(rule)) continue;
        if (length(unsupported) > 0)
            return { found: false, indeterminate: true, index: index_value,
                error: "cannot verify route rule with unsupported conditions: " + join(", ", unsupported), checked_sets };
        if (action == "reject")
            return { found: false, rejected: true, index: index_value,
                error: "traffic is rejected by an earlier generated route rule", matcher, checked_sets };
        return { found: true, index: index_value, outbound: as_string(rule.outbound), matcher, checked_sets };
    }
    return { found: false, checked_sets };
}

function find_dns_route(config, domain) {
    let sets = ruleset_map(config);
    let index_value = -1;
    for (let rule in as_array(config.dns && config.dns.rules)) {
        index_value++;
        if (type(rule) != "object") continue;
        let action = as_string(rule.action);
        if (action != "route" && action != "reject") continue;
        let query_types = as_array(rule.query_type);
        if (length(query_types) > 0 && !contains(query_types, "A") && !contains(query_types, 1)) continue;
        let direct = direct_domain_match(rule, domain);
        let matcher = direct;
        for (let tag in as_array(rule.rule_set)) {
            tag = as_string(tag);
            let result = ruleset_match(sets[tag], domain);
            if (result.error != null && result.error != "")
                return { found: false, error: "cannot inspect DNS rule set " + tag + ": " + result.error };
            if (result.matched && matcher == "") matcher = "rule_set:" + tag;
        }
        let unsupported = unsupported_rule_keys(rule, DNS_RULE_KEYS);
        if (matcher == "" && has_domain_matchers(rule)) continue;
        if (length(unsupported) > 0)
            return { found: false, indeterminate: true, index: index_value,
                error: "cannot verify DNS rule with unsupported conditions: " + join(", ", unsupported) };
        if (action == "reject")
            return { found: false, rejected: true, index: index_value,
                error: "DNS query is rejected by an earlier generated rule", matcher };
        return { found: true, index: index_value, server: as_string(rule.server), matcher };
    }
    return { found: false };
}

function outbound_exists(config, tag) {
    for (let outbound in as_array(config.outbounds))
        if (type(outbound) == "object" && as_string(outbound.tag) == tag) return true;
    return false;
}

function dns_result(domain) {
    let result = command_capture([ DIG_BIN, "+short", domain, "A" ], false);
    let addresses = [];
    for (let line in split(result.output, "\n")) {
        line = trim(line);
        if (match(line, /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) != null) push(addresses, line);
    }
    let fakeip = false;
    for (let address in addresses)
        if (match(address, /^198\.(18|19)\./) != null) fakeip = true;
    return { success: result.status == 0 && length(addresses) > 0, addresses, fakeip };
}

function latency_result(tag, domain) {
    let result = command_capture([ LOGHORIZON_BIN, "clash_api", "get_proxy_latency", tag,
        TEST_TIMEOUT, "https://" + domain + "/" ], false);
    let value = null;
    try { value = json(result.output); } catch (e) { }
    let delay = type(value) == "object" ? int(value.delay || 0) : 0;
    return { success: result.status == 0 && delay > 0, delay, output: result.output };
}

function main(section, domain) {
    section = as_string(section);
    domain = lc(as_string(domain));
    let steps = [];
    if (section == "" || match(section, /[^A-Za-z0-9_-]/) != null || !valid_domain(domain)) {
        print(sprintf("%J\n", { success: false, section, domain, steps: [ step("input", false, "Invalid section or domain", null) ] }));
        return 1;
    }

    let enabled = as_string(uci.get(CONFIG_NAME + "." + section + ".enabled")) != "0";
    let action = as_string(uci.get(CONFIG_NAME + "." + section + ".action"));
    push(steps, step("section", enabled && action != "", enabled ? "Section is enabled" : "Section is disabled", { action }));

    let config = null;
    try { config = json(as_string(fs.readfile(CONFIG_PATH))); } catch (e) { }
    if (type(config) != "object") {
        push(steps, step("config", false, "Generated sing-box config is unavailable", { path: CONFIG_PATH }));
        print(sprintf("%J\n", { success: false, section, domain, steps }));
        return 1;
    }
    push(steps, step("config", true, "Generated sing-box config loaded", null));

    let flow_context = { network: "tcp", protocol: "tls", port: 443, ip_version: 4 };
    let route = find_route(config, domain, flow_context);
    let expected = section + "-out";
    let route_ok = route.found === true && route.outbound == expected;
    let route_message = route.error || (route.found ?
        (route_ok ? "Domain selects the requested section" : "Domain is intercepted by another section") :
        "No matching route rule was found");
    push(steps, step("route", route_ok, route_message, {
        expected_outbound: expected,
        actual_outbound: route.outbound || "",
        matcher: route.matcher || "",
        rule_index: route.index != null ? route.index : null,
        flow_context,
        checked_rule_sets: route.checked_sets || []
    }));

    let outbound_ok = outbound_exists(config, expected);
    push(steps, step("outbound", outbound_ok, outbound_ok ? "Requested outbound exists" : "Requested outbound is missing", { tag: expected }));

    let dns = dns_result(domain);
    let dns_route = find_dns_route(config, domain);
    let expected_fakeip = dns_route.found === true ? dns_route.server == "fakeip-server" : null;
    let dns_ok = dns.success && !dns_route.error &&
        (expected_fakeip == null || dns.fakeip == expected_fakeip);
    dns.expected_fakeip = expected_fakeip;
    dns.server = dns_route.server || "";
    dns.matcher = dns_route.matcher || "";
    push(steps, step("dns", dns_ok, !dns.success ? "Domain did not resolve" :
        (dns_route.error || (dns_ok ? "DNS answer matches the generated DNS rule" :
        (expected_fakeip ? "Generated rule expects FakeIP but DNS returned a real address" :
        "DNS returned a stale or unexpected FakeIP address"))), dns));

    let latency = outbound_ok ? latency_result(expected, domain) : { success: false, delay: 0, output: "" };
    push(steps, step("api", latency.success, latency.success ? "Outbound answered through Clash API" : "Outbound health request failed", latency));

    let success = enabled && action != "" && route_ok && outbound_ok && dns_ok && latency.success;
    print(sprintf("%J\n", { success, section, domain, action, expected_outbound: expected, steps }));
    return success ? 0 : 2;
}

exit(main(ARGV[1], ARGV[2]));
