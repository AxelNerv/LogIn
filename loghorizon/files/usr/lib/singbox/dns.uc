#!/usr/bin/env ucode

let common = require("core.common");
let core_ip = require("core.ip");
let runtime_constants = require("singbox.constants");
let runtime_url = require("core.url");

let as_string = common.as_string;
let bool_option = common.bool_option;
let list_option = common.list_option;
let object_or_empty = common.object_or_empty;
let option = common.option;
let read_json_file = common.read_json_file;

const DNS_FAILOVER_STATE_FILE = getenv("LOGHORIZON_DNS_FAILOVER_STATE_FILE") || "/var/run/loghorizon/dns-failover.json";
const DNS_HEALTH_ADDRESS = getenv("LOGHORIZON_DNS_HEALTH_ADDRESS") || "127.0.0.42";
const DNS_HEALTH_PORT_BASE = int(getenv("LOGHORIZON_DNS_HEALTH_PORT_BASE") || "10053");

function server_list(settings, key, fallback) {
    let result = [];
    for (let value in list_option(settings, key)) {
        value = trim(as_string(value));
        if (value != "")
            push(result, value);
    }
    if (length(result) == 0)
        push(result, fallback);
    return result;
}

function arrays_equal(left, right) {
    if (length(left || []) != length(right || []))
        return false;
    for (let i = 0; i < length(left); i++)
        if (as_string(left[i]) != as_string(right[i]))
            return false;
    return true;
}

function detour_tag(settings) {
    if (!bool_option(settings, "dns_detour_enabled", false))
        return "";
    let section_name = option(settings, "dns_detour_section", "");
    return section_name == "" ? "" : runtime_constants.outbound_tag(section_name);
}

function state_template(settings) {
    return {
        version: 1,
        dns_type: option(settings, "dns_type", "udp"),
        dns_ech: bool_option(settings, "dns_ech_enabled", false),
        dns_detour: detour_tag(settings),
        main_servers: server_list(settings, "dns_server", "77.88.8.8"),
        bootstrap_servers: server_list(settings, "bootstrap_dns_server", "77.88.8.8"),
        main_index: 0,
        bootstrap_index: 0
    };
}

function state_matches(template, state) {
    state = object_or_empty(state);
    return int(state.version || 0) == 1 &&
        as_string(state.dns_type) == template.dns_type &&
        state.dns_ech === template.dns_ech &&
        as_string(state.dns_detour) == template.dns_detour &&
        arrays_equal(state.main_servers, template.main_servers) &&
        arrays_equal(state.bootstrap_servers, template.bootstrap_servers);
}

function bounded_index(value, values) {
    let index_value = int(value || 0);
    return index_value >= 0 && index_value < length(values) ? index_value : 0;
}

function normalize_state(settings, state) {
    let result = state_template(settings);
    if (!state_matches(result, state))
        return result;

    result.main_index = bounded_index(object_or_empty(state).main_index, result.main_servers);
    result.bootstrap_index = bounded_index(object_or_empty(state).bootstrap_index, result.bootstrap_servers);
    return result;
}

function runtime_state(settings, override_state) {
    let state = override_state;
    if (state == null)
        state = read_json_file(DNS_FAILOVER_STATE_FILE);
    return normalize_state(settings, state);
}

function active_values(settings, override_state) {
    let state = runtime_state(settings, override_state);
    return {
        state,
        main: state.main_servers[state.main_index],
        bootstrap: state.bootstrap_servers[state.bootstrap_index]
    };
}

function encrypted_dns_type(dns_type) {
    return dns_type == "dot" || dns_type == "doh" ||
        dns_type == "doq" || dns_type == "doh3";
}

function dns_type_from_scheme(value, fallback) {
    let scheme = runtime_url.scheme(value);
    if (scheme == "udp" || scheme == "dns") return "udp";
    if (scheme == "tcp") return "tcp";
    if (scheme == "tls" || scheme == "dot") return "dot";
    if (scheme == "https" || scheme == "doh") return "doh";
    if (scheme == "quic" || scheme == "doq") return "doq";
    if (scheme == "h3" || scheme == "doh3") return "doh3";
    return scheme == "" ? fallback : "";
}

function endpoint_options(dns_type, value) {
    let query = runtime_url.query_params(value);
    let logical_host = runtime_url.host(value);
    let address = trim(as_string(query.address || ""));
    let server_name = trim(as_string(query.server_name || query.sni || ""));
    return {
        dns_type: dns_type_from_scheme(value, dns_type),
        logical_host,
        server: address != "" ? address : logical_host,
        server_name: server_name != "" ? server_name :
            (address != "" && !core_ip.valid_ip(logical_host) ? logical_host : ""),
        pinned_address: address != ""
    };
}

function server_from_options(tag_name, dns_type, dns_server, detour, ech, resolver_tag) {
    let endpoint = endpoint_options(dns_type, dns_server);
    dns_type = endpoint.dns_type;
    let server = endpoint.server;
    let port = runtime_url.port(dns_server);
    let result = {
        type: "udp",
        tag: tag_name,
        server,
        server_port: 53
    };

    if (dns_type == "udp") {
        if (port != "")
            result.server_port = int(port, 10);
    }
    else if (dns_type == "tcp") {
        result.type = "tcp";
        result.server_port = port != "" ? int(port, 10) : 53;
    }
    else if (dns_type == "dot") {
        result.type = "tls";
        result.server_port = port != "" ? int(port, 10) : 853;
    }
    else if (dns_type == "doh") {
        result.type = "https";
        result.server_port = port != "" ? int(port, 10) : 443;
        let path = runtime_url.path(dns_server);
        if (path != "")
            result.path = path;
    }
    else if (dns_type == "doq") {
        // RFC 9250. Runs over QUIC on its own port, so DPI that kills DoT/DoH
        // by inspecting the TLS ClientHello on 853/443 does not see it.
        result.type = "quic";
        result.server_port = port != "" ? int(port, 10) : 853;
    }
    else if (dns_type == "doh3") {
        // DoH carried over HTTP/3 instead of TCP+TLS, same 443 endpoint.
        result.type = "h3";
        result.server_port = port != "" ? int(port, 10) : 443;
        let path = runtime_url.path(dns_server);
        if (path != "")
            result.path = path;
    }
    else {
        return { unsupported: "unsupported dns_type " + dns_type };
    }

    if (!core_ip.valid_ip(server)) {
        let resolver = resolver_tag == null
            ? runtime_constants.BOOTSTRAP_DNS_SERVER_TAG
            : as_string(resolver_tag);
        if (resolver == "")
            return { unsupported: "bootstrap DNS endpoint " + endpoint.logical_host +
                " needs ?address=<IP> to avoid a resolver cycle" };
        result.domain_resolver = resolver;
    }
    if (as_string(detour) != "")
        result.detour = as_string(detour);

    // Encrypted Client Hello hides the resolver name that DPI matches on.
    // It only means anything for the encrypted transports; plain UDP has no
    // handshake to hide.
    if (endpoint.server_name != "" && encrypted_dns_type(dns_type))
        result.tls = { enabled: true, server_name: endpoint.server_name };
    if (ech && encrypted_dns_type(dns_type)) {
        if (type(result.tls) != "object")
            result.tls = { enabled: true };
        result.tls.ech = { enabled: true };
    }

    return result;
}

function bootstrap_server(tag_name, value) {
    return server_from_options(tag_name, "udp", value, "", false, "");
}

function server_config(settings, override_state) {
    let active = active_values(settings, override_state);
    return server_from_options(
        runtime_constants.DNS_SERVER_TAG,
        active.state.dns_type,
        active.main,
        active.state.dns_detour,
        active.state.dns_ech
    );
}

function bootstrap_config(settings, override_state) {
    let active = active_values(settings, override_state);
    return bootstrap_server(runtime_constants.BOOTSTRAP_DNS_SERVER_TAG, active.bootstrap);
}

// Domains whose HTTPS records must stay reachable: that is where the ECH
// keys live, and the generator otherwise rejects every HTTPS query.
function ech_resolver_domains(settings) {
    let state = state_template(settings);
    let result = [];

    if (!state.dns_ech || !encrypted_dns_type(state.dns_type))
        return result;

    for (let value in state.main_servers) {
        let host = runtime_url.host(value);
        if (host == "")
            host = as_string(value);
        if (host != "" && !core_ip.valid_ip(host))
            push(result, host);
    }
    return result;
}

function failover_enabled(settings) {
    let state = state_template(settings);
    return length(state.main_servers) > 1 || length(state.bootstrap_servers) > 1;
}

function health_tag(kind, index_value, suffix) {
    return "dns-health-" + as_string(kind) + "-" + as_string(index_value + 1) + "-" + as_string(suffix);
}

function health_port(kind, index_value) {
    if (kind == "active")
        return DNS_HEALTH_PORT_BASE + 2000;
    return DNS_HEALTH_PORT_BASE + int(index_value) * 2 + (kind == "bootstrap" ? 1 : 0);
}

function add_active_health_inbound(result) {
    let inbound_tag = "dns-health-active-main-in";
    push(result.inbounds, {
        type: "direct",
        tag: inbound_tag,
        listen: DNS_HEALTH_ADDRESS,
        listen_port: health_port("active", 0)
    });
    push(result.rules, {
        action: "route",
        inbound: inbound_tag,
        server: runtime_constants.DNS_SERVER_TAG,
        disable_cache: true
    });
    push(result.sniff_inbounds, inbound_tag);
}

function add_health_candidate(result, kind, index_value, server) {
    let server_tag = health_tag(kind, index_value, "server");
    let inbound_tag = health_tag(kind, index_value, "in");
    let dns_server = kind == "main"
        ? server_from_options(server_tag, result.state.dns_type, server,
            result.state.dns_detour, result.state.dns_ech)
        : bootstrap_server(server_tag, server);

    if (dns_server.unsupported) {
        result.unsupported = dns_server.unsupported;
        return;
    }

    push(result.servers, dns_server);
    push(result.inbounds, {
        type: "direct",
        tag: inbound_tag,
        listen: DNS_HEALTH_ADDRESS,
        listen_port: health_port(kind, index_value)
    });
    push(result.rules, {
        action: "route",
        inbound: inbound_tag,
        server: server_tag,
        disable_cache: true
    });
    push(result.sniff_inbounds, inbound_tag);
}

function config(settings, override_state) {
    let state = runtime_state(settings, override_state);
    let main = server_config(settings, state);
    if (main.unsupported)
        return { unsupported: main.unsupported };

    let bootstrap = bootstrap_config(settings, state);
    if (bootstrap.unsupported)
        return { unsupported: bootstrap.unsupported };

    let result = {
        state,
        servers: [ bootstrap, main ],
        inbounds: [],
        rules: [],
        sniff_inbounds: []
    };

    if (length(state.main_servers) > 1 || length(state.bootstrap_servers) > 1)
        add_active_health_inbound(result);

    if (length(state.main_servers) > 1)
        for (let i = 0; i < length(state.main_servers); i++)
            add_health_candidate(result, "main", i, state.main_servers[i]);

    // Keep a local probe for every bootstrap, including a singleton. Direct
    // `dig @value` cannot test DoH/DoT/DoQ and used to silently fall back to
    // an unrelated system resolver for URL-shaped values.
    for (let i = 0; i < length(state.bootstrap_servers); i++)
        add_health_candidate(result, "bootstrap", i, state.bootstrap_servers[i]);

    return result;
}

function default_domain_resolver(settings) {
    return bool_option(settings, "dns_detour_enabled", false)
        ? runtime_constants.BOOTSTRAP_DNS_SERVER_TAG
        : runtime_constants.DNS_SERVER_TAG;
}

return {
    DNS_FAILOVER_STATE_FILE,
    DNS_HEALTH_ADDRESS,
    active_values,
    arrays_equal,
    bootstrap_config,
    bootstrap_server,
    config,
    default_domain_resolver,
    detour_tag,
    failover_enabled,
    ech_resolver_domains,
    health_port,
    normalize_state,
    runtime_state,
    server_config,
    server_from_options,
    dns_type_from_scheme,
    endpoint_options,
    server_list,
    state_matches,
    state_template
};
