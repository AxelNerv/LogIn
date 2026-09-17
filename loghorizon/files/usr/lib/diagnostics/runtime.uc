#!/usr/bin/env ucode

let fs = require("fs");
let constants = require("core.constants");
let core_ip = require("core.ip");
let uci_core = require("core.uci");
let runtime_dns = require("singbox.dns");
let netstat = require("core.netstat");

const CONFIG_NAME = getenv("LOGHORIZON_CONFIG_NAME") || constants.LOGHORIZON_CONFIG_NAME || "loghorizon";
const LIB_DIR = getenv("LOGHORIZON_LIB") || "/usr/lib/loghorizon";
const LOGHORIZON_VERSION = getenv("LOGHORIZON_VERSION") || constants.LOGHORIZON_VERSION || "";
const LOGHORIZON_CONFIG = getenv("LOGHORIZON_CONFIG") || constants.LOGHORIZON_CONFIG || "/etc/config/" + CONFIG_NAME;
const LOGHORIZON_SERVICE_NAME = getenv("LOGHORIZON_SERVICE_NAME") || constants.LOGHORIZON_SERVICE_NAME || "loghorizon";
const LOGHORIZON_RELEASE_REPO = getenv("LOGHORIZON_RELEASE_REPO") || constants.LOGHORIZON_RELEASE_REPO || "AxelNerv/LogIn";
const LOGHORIZON_LUCI_VIEW_DIR = getenv("LOGHORIZON_LUCI_VIEW_DIR") || constants.LOGHORIZON_LUCI_VIEW_DIR || "/www/luci-static/resources/view/loghorizon";
const RUNTIME_STATE_DIR = getenv("LOGHORIZON_RUNTIME_STATE_DIR") || "/var/run/loghorizon";
const SYSTEM_INFO_CACHE_FILE = getenv("LOGHORIZON_SYSTEM_INFO_CACHE_FILE") || RUNTIME_STATE_DIR + "/system-info.json";
const SYSTEM_INFO_CACHE_TTL = int(getenv("LOGHORIZON_SYSTEM_INFO_CACHE_TTL") || "3600");
const CONNECTIVITY_HISTORY_FILE = getenv("LOGHORIZON_DIAGNOSTICS_HISTORY_FILE") || "/etc/loghorizon/connectivity-history.json";
const CONNECTIVITY_HISTORY_MAX_ENTRIES = int(getenv("LOGHORIZON_DIAGNOSTICS_HISTORY_MAX_ENTRIES") || "32");
const TMP_SING_BOX_FOLDER = getenv("TMP_SING_BOX_FOLDER") || constants.TMP_SING_BOX_FOLDER || "/tmp/sing-box";
const TMP_RULESET_FOLDER = getenv("TMP_RULESET_FOLDER") || constants.TMP_RULESET_FOLDER || TMP_SING_BOX_FOLDER + "/rulesets";
const TMP_SUBSCRIPTION_FOLDER = getenv("TMP_SUBSCRIPTION_FOLDER") || constants.TMP_SUBSCRIPTION_FOLDER || TMP_SING_BOX_FOLDER + "/subscriptions";
const SECTION_CACHE_DIR = getenv("LOGHORIZON_SECTION_CACHE_DIR") || RUNTIME_STATE_DIR + "/section-cache";
const CHECK_PROXY_IP_DOMAIN = getenv("CHECK_PROXY_IP_DOMAIN") || constants.CHECK_PROXY_IP_DOMAIN || "ip.podkop.fyi";
const FAKEIP_TEST_DOMAIN = getenv("FAKEIP_TEST_DOMAIN") || constants.FAKEIP_TEST_DOMAIN || "fakeip.podkop.fyi";
const RT_TABLE_NAME = getenv("RT_TABLE_NAME") || constants.RT_TABLE_NAME || "loghorizon";
const NFT_TABLE_NAME = getenv("NFT_TABLE_NAME") || constants.NFT_TABLE_NAME || "LogHorizonTable";
const NFT_FAKEIP_MARK = getenv("NFT_FAKEIP_MARK") || constants.NFT_FAKEIP_MARK || "0x04000000";
const NFT_COMMON_SET_NAME = getenv("NFT_COMMON_SET_NAME") || constants.NFT_COMMON_SET_NAME || "loghorizon_subnets";
const NFT_PORT_SET_NAME = getenv("NFT_PORT_SET_NAME") || constants.NFT_PORT_SET_NAME || "loghorizon_ports";
const NFT_IP_PORT_SET_NAME = getenv("NFT_IP_PORT_SET_NAME") || constants.NFT_IP_PORT_SET_NAME || "loghorizon_ip_ports";
const NFT_INTERFACE_SET_NAME = getenv("NFT_INTERFACE_SET_NAME") || constants.NFT_INTERFACE_SET_NAME || "loghorizon_interfaces";
const NFT_DISCORD_SET_NAME = getenv("NFT_DISCORD_SET_NAME") || constants.NFT_DISCORD_SET_NAME || "loghorizon_discord_subnets";
const NFT_LOCALV4_SET_NAME = getenv("NFT_LOCALV4_SET_NAME") || constants.NFT_LOCALV4_SET_NAME || "localv4";
const SB_DNS_INBOUND_ADDRESS = getenv("SB_DNS_INBOUND_ADDRESS") || constants.SB_DNS_INBOUND_ADDRESS || "127.0.0.42";
const SB_TPROXY_INBOUND6_ADDRESS = getenv("SB_TPROXY_INBOUND6_ADDRESS") || constants.SB_TPROXY_INBOUND6_ADDRESS || "::1";
const SB_TPROXY_INBOUND_PORT = getenv("SB_TPROXY_INBOUND_PORT") || constants.SB_TPROXY_INBOUND_PORT || "1602";
const SB_CLASH_API_CONTROLLER_PORT = getenv("SB_CLASH_API_CONTROLLER_PORT") || constants.SB_CLASH_API_CONTROLLER_PORT || "9090";
const SB_VARIANT_STATE_FILE = getenv("SB_VARIANT_STATE_FILE") || constants.SB_VARIANT_STATE_FILE || "/etc/loghorizon/sing-box-variant";
const SING_BOX_BIN_PATH = getenv("LOGHORIZON_DIAGNOSTICS_SING_BOX_BIN_PATH") || "/usr/bin/sing-box";
const SING_BOX_CONFIG_PATH = getenv("LOGHORIZON_SING_BOX_CONFIG_PATH") || "/etc/sing-box/config.json";
const CLOUDFLARE_OCTETS = getenv("CLOUDFLARE_OCTETS") || constants.CLOUDFLARE_OCTETS || "8.47 162.159 188.114";
const ZAPRET_LEGACY_DEFAULT_NFQWS_OPT = getenv("ZAPRET_LEGACY_DEFAULT_NFQWS_OPT") || constants.ZAPRET_LEGACY_DEFAULT_NFQWS_OPT || "";
const DEFAULT_LATENCY_TEST_URL = getenv("DEFAULT_LATENCY_TEST_URL") || "https://www.gstatic.com/generate_204";
const RUNTIME_STABLE_MIN_AGE = getenv("LOGHORIZON_RUNTIME_STABLE_MIN_AGE") || "2";

const STATUS_UC = LIB_DIR + "/diagnostics/status.uc";
const HELPERS_UC = LIB_DIR + "/core/helpers.uc";
const PACKAGES_UC = LIB_DIR + "/core/packages.uc";
const DNS_APPLY_UC = LIB_DIR + "/dns/apply.uc";
const SERVICE_STATE_UC = LIB_DIR + "/service/state.uc";
const SERVICE_UI_UC = LIB_DIR + "/service/ui.uc";
const SUBSCRIPTION_CACHE_UC = LIB_DIR + "/subscription/cache.uc";
const PROVIDERS_STATUS_UC = LIB_DIR + "/providers/status.uc";
const SINGBOX_RUNTIME_UC = LIB_DIR + "/singbox/runtime.uc";
const ZAPRET_RUNTIME_UC = LIB_DIR + "/providers/zapret/runtime.uc";
const ZAPRET2_RUNTIME_UC = LIB_DIR + "/providers/zapret2/runtime.uc";
const BYEDPI_RUNTIME_UC = LIB_DIR + "/providers/byedpi/runtime.uc";
const ZAPRET_VALIDATOR_UC = LIB_DIR + "/providers/zapret/validator.uc";
const ZAPRET2_VALIDATOR_UC = LIB_DIR + "/providers/zapret2/validator.uc";

function as_string(value) {
    return value == null ? "" : "" + value;
}

function arg_number(value) {
    value = as_string(value);
    return value == "" || match(value, /[^0-9-]/) != null ? 0 : int(value, 10);
}

function arg_bool(value) {
    value = lc(as_string(value));
    return value == "1" || value == "true" || value == "yes" || value == "on";
}

function shell_quote(value) {
    return "'" + replace(as_string(value), /'/g, "'\\''") + "'";
}

function command_from_args(args) {
    let parts = [];
    for (let arg in args)
        push(parts, shell_quote(arg));
    return join(" ", parts);
}

function normalize_status(status) {
    status = int(status);
    return status > 255 ? int(status / 256) : status;
}

function command_status(command) {
    return normalize_status(system(command));
}

function command_capture(command) {
    let pipe = fs.popen(command, "r");
    if (!pipe)
        return { status: 1, output: "" };

    let data = pipe.read("all");
    let status = normalize_status(pipe.close());
    return { status, output: data == null ? "" : as_string(data) };
}

function command_output(command) {
    let result = command_capture(command);
    return result.status == 0 ? result.output : "";
}

function command_success(command) {
    return command_status(command + " >/dev/null 2>&1") == 0;
}

function command_output_from_args(args) {
    return command_output(command_from_args(args) + " 2>/dev/null");
}

function command_success_from_args(args) {
    return command_success(command_from_args(args));
}

function command_exists(name) {
    return command_success_from_args([ "command", "-v", as_string(name) ]);
}

function module_args(module_path, args) {
    let result = [ "ucode", "-L", LIB_DIR, module_path ];
    for (let arg in args)
        push(result, arg);
    return result;
}

function module_capture(module_path, args) {
    return command_capture(command_from_args(module_args(module_path, args)));
}

function module_capture_stdin(module_path, args, input) {
    let tmp = trim(command_output_from_args([ "mktemp" ]));
    if (tmp == "")
        return { status: 1, output: "" };

    if (!fs.writefile(tmp, as_string(input))) {
        fs.unlink(tmp);
        return { status: 1, output: "" };
    }

    let result = command_capture(command_from_args(module_args(module_path, args)) + " < " + shell_quote(tmp));
    fs.unlink(tmp);
    return result;
}

function module_output(module_path, args) {
    let result = module_capture(module_path, args);
    return result.status == 0 ? result.output : "";
}

function module_output_stdin(module_path, args, input) {
    let result = module_capture_stdin(module_path, args, input);
    return result.status == 0 ? result.output : "";
}

function module_success(module_path, args) {
    return command_success(command_from_args(module_args(module_path, args)));
}

function module_passthrough(module_path, args) {
    let result = module_capture(module_path, args);
    if (result.output != "")
        print(result.output);
    return result.status;
}

function status_capture(args, input) {
    if (input != null)
        return module_capture_stdin(STATUS_UC, args, input);
    return command_capture(command_from_args(module_args(STATUS_UC, args)));
}

function status_output(args, input) {
    let result = status_capture(args, input);
    return result.status == 0 ? result.output : "";
}

function status_success(args, input) {
    return status_capture(args, input).status == 0;
}

function write_json(value) {
    print(sprintf("%J", value), "\n");
}

function read_stdin() {
    let input = fs.open("/dev/stdin", "r");
    if (!input)
        return "";
    let data = input.read("all");
    input.close();
    return data == null ? "" : as_string(data);
}

function read_json_file(path) {
    let data = fs.readfile(as_string(path));
    if (data == null)
        return null;
    try {
        return json(data);
    }
    catch (e) {
        return null;
    }
}

function parse_json_or_null(value) {
    try {
        return json(as_string(value));
    }
    catch (e) {
        return null;
    }
}

function object_or_empty(value) {
    return type(value) == "object" ? value : {};
}

function array_or_empty(value) {
    return type(value) == "array" ? value : [];
}

function option(section, key, fallback) {
    if (fallback == null)
        fallback = "";
    let value = object_or_empty(section)[key];
    if (value == null)
        return as_string(fallback);
    if (type(value) == "array")
        return join(" ", value);
    return as_string(value);
}

function list_option(section, key) {
    let value = object_or_empty(section)[key];
    if (type(value) == "array")
        return value;
    if (as_string(value) != "")
        return [ as_string(value) ];
    return [];
}

function bool_option(section, key, fallback) {
    return arg_bool(option(section, key, fallback ? "1" : "0"));
}

function settings() {
    return object_or_empty(uci_core.get_all(CONFIG_NAME, "settings"));
}

function uci_sections(type_name) {
    return uci_core.section_objects(CONFIG_NAME, type_name);
}

function uci_get(path) {
    return uci_core.get(path);
}

function uci_show(path) {
    return uci_core.exists(path);
}

function append_unique(values, value) {
    value = as_string(value);
    if (value == "")
        return;
    for (let item in values)
        if (item == value)
            return;
    push(values, value);
}

function config_section_types(config_path) {
    let data = as_string(fs.readfile(config_path) || "");
    let result = [];

    for (let line in split(data, "\n")) {
        line = trim(as_string(line));
        if (substr(line, 0, 7) != "config ")
            continue;

        let fields = split(line, /[ \t\r\n]+/);
        if (length(fields) >= 2)
            append_unique(result, replace(as_string(fields[1]), /['"]/g, ""));
    }

    return result;
}

function uci_show_quote(value) {
    return "'" + replace(as_string(value), /'/g, "'\\''") + "'";
}

function append_uci_show_option(lines, package_name, section_name, key, value) {
    if (key == ".name" || key == ".type")
        return;

    let path = as_string(package_name) + "." + as_string(section_name) + "." + as_string(key) + "=";
    if (type(value) == "array") {
        for (let item in value)
            push(lines, path + uci_show_quote(item));
    }
    else {
        push(lines, path + uci_show_quote(value));
    }
}

function uci_show_data(package_name, config_path) {
    let lines = [];
    package_name = as_string(package_name);
    for (let type_name in config_section_types(config_path)) {
        for (let section in uci_core.section_objects(package_name, type_name)) {
            let name = as_string(section[".name"] || "");
            if (name == "")
                continue;
            push(lines, package_name + "." + name + "=" + as_string(section[".type"] || type_name));
            for (let key, value in section)
                append_uci_show_option(lines, package_name, name, key, value);
        }
    }
    return join("\n", lines) + "\n";
}

function network_show_data() {
    return uci_show_data("network", "/etc/config/network");
}

function firewall_show_data() {
    return uci_show_data("firewall", "/etc/config/firewall");
}

function file_exists(path) {
    return fs.stat(as_string(path)) != null;
}

function file_executable(path) {
    return command_success_from_args([ "test", "-x", as_string(path) ]);
}

function ensure_dir(path) {
    return command_success_from_args([ "mkdir", "-p", as_string(path) ]);
}

function remove_file(path) {
    try {
        fs.unlink(as_string(path));
    }
    catch (e) {
    }
}

function first_line_value(path, fallback) {
    let data = fs.readfile(as_string(path));
    if (data == null)
        return as_string(fallback);
    let line = split(as_string(data), "\n")[0];
    line = replace(as_string(line), /\r$/, "");
    return line != "" ? line : as_string(fallback);
}

function stdout_is_tty() {
    return command_success_from_args([ "test", "-t", "1" ]);
}

function nolog(message) {
    if (!stdout_is_tty())
        return;
    let timestamp = replace(command_output_from_args([ "date", "+%Y-%m-%d %H:%M:%S" ]), /[\r\n]+$/g, "");
    print("\033[0;36m[", timestamp, "]\033[0m \033[0;32m", as_string(message), "\033[0m\n");
}

function log_message(message, level) {
    level = as_string(level || "info");
    command_success_from_args([ "logger", "-t", "loghorizon", "[" + level + "] " + as_string(message) ]);
}

function valid_ipv4(value) {
    return core_ip.valid_ipv4(value, true, false);
}

function valid_public_ipv4(value) {
    value = as_string(value);
    if (!valid_ipv4(value))
        return false;

    let parts = split(value, ".");
    let a = int(parts[0], 10);
    let b = int(parts[1], 10);

    if (a == 0 || a == 10 || a == 127 || a >= 224)
        return false;
    if (a == 169 && b == 254)
        return false;
    if (a == 192 && (b == 168 || b == 0 || b == 2))
        return false;
    if (a == 198 && (b == 18 || b == 19 || b == 51))
        return false;
    if (a == 203 && b == 0)
        return false;
    if (a == 100 && b >= 64 && b <= 127)
        return false;
    if (a == 172 && b >= 16 && b <= 31)
        return false;

    return true;
}

function valid_public_ipv6(value) {
    value = lc(as_string(value));
    if (!core_ip.valid_ipv6(value))
        return false;
    if (value == "::" || value == "::1")
        return false;
    if (substr(value, 0, 4) == "fe80" || substr(value, 0, 2) == "ff")
        return false;
    if (substr(value, 0, 2) == "fc" || substr(value, 0, 2) == "fd")
        return false;
    if (substr(value, 0, 4) == "2001" && index(value, "2001:db8") == 0)
        return false;
    return true;
}

function valid_public_ip(value) {
    return valid_public_ipv4(value) || valid_public_ipv6(value);
}

function words(value) {
    value = trim(as_string(value));
    return value == "" ? [] : split(value, /[ \t\r\n]+/);
}

function allowed_ips_default_routes(value) {
    let result = [];
    for (let allowed in words(value)) {
        if (allowed == "0.0.0.0/0" || allowed == "::/0")
            push(result, allowed);
    }
    return result;
}

function push_unique(result, seen, value) {
    value = as_string(value);
    if (value == "" || seen[value])
        return;
    seen[value] = true;
    push(result, value);
}

function network_status_ip_addresses(data, key) {
    let value = parse_json_or_null(data);
    let addresses = type(value) == "object" ? value[key] : null;
    let result = [];
    let seen = {};
    if (type(addresses) == "array") {
        for (let item in addresses) {
            if (type(item) == "object")
                push_unique(result, seen, item.address || "");
        }
    }
    return result;
}

function get_wan_ip_addresses() {
    let result = [];
    let seen = {};

    for (let interface in [ "wan", "wwan" ]) {
        let data = command_output_from_args([
            "ubus", "-S", "call", "network.interface." + interface, "status"
        ]);
        for (let ip in network_status_ip_addresses(data, "ipv4-address"))
            push_unique(result, seen, ip);
        for (let ip in network_status_ip_addresses(data, "ipv6-address"))
            push_unique(result, seen, ip);
    }

    let route = command_output_from_args([ "ip", "-4", "route", "show", "default" ]);
    let fields = words(route);
    let iface = "";
    for (let i = 0; i + 1 < length(fields); i++) {
        if (fields[i] == "dev") {
            iface = fields[i + 1];
            break;
        }
    }
    if (iface == "")
        return "";

    let addr = command_output_from_args([ "ip", "-4", "addr", "show", "dev", iface ]);
    for (let line in split(addr, "\n")) {
        line = trim(as_string(line));
        let matched = match(line, /^inet[ \t]+([0-9.]+)\//);
        if (matched != null)
            push_unique(result, seen, matched[1]);
    }

    route = command_output_from_args([ "ip", "-6", "route", "show", "default" ]);
    fields = words(route);
    iface = "";
    for (let i = 0; i + 1 < length(fields); i++) {
        if (fields[i] == "dev") {
            iface = fields[i + 1];
            break;
        }
    }
    if (iface != "") {
        addr = command_output_from_args([ "ip", "-6", "addr", "show", "dev", iface, "scope", "global" ]);
        for (let line in split(addr, "\n")) {
            line = trim(as_string(line));
            let matched = match(line, /^inet6[ \t]+([^\/ \t]+)\//);
            if (matched != null)
                push_unique(result, seen, matched[1]);
        }
    }

    return join(" ", result);
}

function helper_output(mode, args) {
    let full = [ mode ];
    for (let arg in args)
        push(full, arg);
    return replace(module_output(HELPERS_UC, full), /[\r\n]+$/g, "");
}

function server_inbound_tag(section) {
    return helper_output("server-inbound-tag", [ section ]);
}

function server_required_inbound_proto(protocol) {
    protocol = as_string(protocol);
    if (protocol == "json_inbound")
        return "";
    return protocol == "hysteria2" ? "udp" : "tcp";
}

function server_runtime_type_for_protocol(protocol) {
    protocol = as_string(protocol);
    if (protocol == "json_inbound")
        return "";
    if (protocol == "mtproto")
        return "mtproxy";
    return protocol;
}

function server_listen_requires_firewall(listen, wan_ip) {
    listen = as_string(listen);
    if (listen == "0.0.0.0" || listen == "::" || valid_public_ip(listen))
        return true;
    for (let ip in words(wan_ip))
        if (ip == listen)
            return true;
    return false;
}

function firewall_required_protocols_open(port, required_proto) {
    let firewall = firewall_show_data();
    return status_success([ "firewall-required-protocols-open", port, required_proto ], firewall);
}

function server_required_port_conflict_owners(listen, port, required_proto) {
    return replace(status_output(
        [ "server-required-port-conflict-owners", listen, port, required_proto ],
        command_output_from_args([ "netstat", "-lnp" ])
    ), /[\r\n]+$/g, "");
}

function server_required_ports_listening(listen, port, required_proto) {
    return status_success(
        [ "server-required-ports-listening", listen, port, required_proto ],
        command_output_from_args([ "netstat", "-ln" ])
    );
}

function resolve_public_host_ips(host) {
    host = as_string(host);
    if (substr(host, 0, 1) == "[" && substr(host, length(host) - 1, 1) == "]")
        host = substr(host, 1, length(host) - 2);
    if (host == "")
        return "";
    if (valid_ipv4(host))
        return host;
    if (core_ip.valid_ipv6(host))
        return host;

    let seen = {};
    for (let line in split(command_output_from_args([
        "dig", "+short", "A", host, "+timeout=2", "+tries=1"
    ]), "\n")) {
        line = trim(as_string(line));
        if (valid_ipv4(line))
            seen[line] = true;
    }
    for (let line in split(command_output_from_args([
        "dig", "+short", "AAAA", host, "+timeout=2", "+tries=1"
    ]), "\n")) {
        line = trim(as_string(line));
        if (core_ip.valid_ipv6(line))
            seen[line] = true;
    }

    return join(" ", sort(keys(seen)));
}

function public_host_flags(public_host, public_host_ips, wan_ip, wan_public) {
    return replace(status_output(
        [ "public-host-flags", public_host, public_host_ips, wan_ip, wan_public ],
        null
    ), /[\r\n]+$/g, "");
}

function check_inbounds_config() {
    let count = 0;
    for (let section in uci_sections("server"))
        if (bool_option(section, "enabled", false))
            count++;
    write_json({ enabled_count: count });
    return 0;
}

function check_inbounds() {
    let cfg = settings();
    let sing_box_config_path = option(cfg, "config_path", "");
    let wan_ip = get_wan_ip_addresses();
    let wan_public = 0;
    for (let ip in words(wan_ip)) {
        if (valid_public_ip(ip)) {
            wan_public = 1;
            break;
        }
    }
    let items = [];
    let enabled_count = 0;

    for (let section in uci_sections("server")) {
        if (!bool_option(section, "enabled", false))
            continue;
        enabled_count++;

        let section_name = as_string(section[".name"] || "");
        let label = option(section, "label", section_name);
        let protocol = option(section, "protocol", "vless");
        let listen = option(section, "listen", "0.0.0.0");
        let listen_port = option(section, "listen_port", "");
        let public_host = option(section, "public_host", "");
        let routing_mode = option(section, "routing_mode", "rules");
        let inbound_tag = server_inbound_tag(section_name);
        let expected_type = server_runtime_type_for_protocol(protocol);
        let required_proto = server_required_inbound_proto(protocol);
        let runtime_json = protocol == "tailscale"
            ? module_output(PROVIDERS_STATUS_UC, [ "endpoint-summary", sing_box_config_path, inbound_tag ])
            : module_output(PROVIDERS_STATUS_UC, [ "inbound-summary", sing_box_config_path, inbound_tag ]);

        let listening = -1;
        let firewall_required = 0;
        let firewall_open = -1;
        let port_conflict = 0;
        let port_conflict_owners = "";
        if (protocol != "tailscale" && protocol != "json_inbound") {
            port_conflict_owners = server_required_port_conflict_owners(listen, listen_port, required_proto);
            if (port_conflict_owners != "")
                port_conflict = 1;
            listening = server_required_ports_listening(listen, listen_port, required_proto) ? 1 : 0;
            if (server_listen_requires_firewall(listen, wan_ip)) {
                firewall_required = 1;
                firewall_open = firewall_required_protocols_open(listen_port, required_proto) ? 1 : 0;
            }
        }

        let routes_configured = module_success(PROVIDERS_STATUS_UC, [
            "has-route-rule-for-inbound", sing_box_config_path, inbound_tag
        ]) ? 1 : 0;

        let public_host_ips = protocol == "json_inbound" ? "" : resolve_public_host_ips(public_host);
        let flags = words(public_host_flags(public_host, public_host_ips, wan_ip, wan_public));
        while (length(flags) < 3)
            push(flags, "-1");

        let item_json = status_output([
            "inbound-item-json",
            runtime_json,
            section_name,
            label,
            protocol,
            routing_mode,
            inbound_tag,
            listen,
            listen_port,
            public_host,
            public_host_ips,
            expected_type,
            required_proto,
            listening,
            firewall_required,
            firewall_open,
            port_conflict,
            port_conflict_owners,
            routes_configured,
            flags[0],
            flags[1],
            flags[2]
        ], null);
        let item = parse_json_or_null(item_json);
        push(items, type(item) == "object" ? item : {});
    }

    write_json({
        enabled_count,
        config_path: sing_box_config_path,
        wan_ip,
        wan_public,
        items
    });
    return 0;
}

function cleanup_check_proxy_dir(dir) {
    dir = as_string(dir);
    let prefix = TMP_SING_BOX_FOLDER + "/check-proxy-";
    if (substr(dir, 0, length(prefix)) == prefix)
        command_success_from_args([ "rm", "-rf", dir ]);
}

function check_proxy() {
    let sing_box_config_path = option(settings(), "config_path", "");
    if (!command_exists("sing-box")) {
        nolog("sing-box is not installed");
        return 1;
    }
    if (!file_exists(sing_box_config_path)) {
        nolog("Configuration file not found");
        return 1;
    }

    nolog("Checking sing-box configuration...");
    if (!command_success_from_args([ "sing-box", "-c", sing_box_config_path, "check" ])) {
        nolog("Invalid configuration");
        return 1;
    }

    print(status_output([ "mask-sing-box-config", sing_box_config_path ], null));
    nolog("Checking proxy connection...");

    let check_proxy_dir = TMP_SING_BOX_FOLDER + "/check-proxy-" + clock()[0] + "-" + clock()[1];
    let check_proxy_config = check_proxy_dir + "/config.json";
    let check_proxy_cache = check_proxy_dir + "/cache.db";

    cleanup_check_proxy_dir(check_proxy_dir);
    ensure_dir(check_proxy_dir);
    if (!status_success([ "prepare-check-proxy-config", sing_box_config_path, check_proxy_config, check_proxy_cache ], null)) {
        nolog("Failed to prepare temporary configuration");
        cleanup_check_proxy_dir(check_proxy_dir);
        return 1;
    }

    let outbound_tag = replace(status_output(
        [ "check-proxy-outbound-tag", check_proxy_config, CHECK_PROXY_IP_DOMAIN ],
        null
    ), /[\r\n]+$/g, "");

    let response = "";
    for (let attempt = 1; attempt <= 5; attempt++) {
        let args = [ "sing-box", "tools", "fetch", "ifconfig.me", "-c", check_proxy_config, "-D", check_proxy_dir, "--disable-color" ];
        if (outbound_tag != "") {
            push(args, "-o");
            push(args, outbound_tag);
        }
        response = command_output(command_from_args(args) + " 2>/dev/null");
        if (status_success([ "proxy-response-is-retryable-error" ], response))
            continue;

        let masked_response_ip = replace(status_output([ "proxy-response-ip-mask" ], response), /[\r\n]+$/g, "");
        if (masked_response_ip != "") {
            nolog(masked_response_ip + " - should match proxy IP");
            cleanup_check_proxy_dir(check_proxy_dir);
            return 0;
        }

        if (attempt == 5) {
            nolog("Failed to get valid IP address after 5 attempts");
            nolog(response == "" ? "Error: Empty response" : "Error response: " + response);
            cleanup_check_proxy_dir(check_proxy_dir);
            return 1;
        }
    }

    cleanup_check_proxy_dir(check_proxy_dir);
    return 1;
}

function domain_lists_contain_cloud_provider() {
    for (let section in uci_sections("section")) {
        if (!bool_option(section, "domain_list_enabled", false))
            continue;
        for (let value in list_option(section, "domain_list"))
            if (value == "hetzner" || value == "ovh")
                return true;
    }
    return false;
}

function check_nft() {
    if (!command_exists("nft")) {
        nolog("nft is not installed");
        return 1;
    }

    nolog("Checking " + NFT_TABLE_NAME + " rules...");
    if (!command_success_from_args([ "nft", "list", "table", "inet", NFT_TABLE_NAME ])) {
        nolog("❌ " + NFT_TABLE_NAME + " not found");
        return 1;
    }

    if (domain_lists_contain_cloud_provider()) {
        nolog("Sets statistics:");
        for (let set_name in [
            NFT_COMMON_SET_NAME,
            NFT_PORT_SET_NAME,
            NFT_IP_PORT_SET_NAME,
            NFT_INTERFACE_SET_NAME,
            NFT_DISCORD_SET_NAME,
            NFT_LOCALV4_SET_NAME
        ]) {
            if (!command_success_from_args([ "nft", "list", "set", "inet", NFT_TABLE_NAME, set_name ]))
                continue;
            let count = replace(status_output(
                [ "nft-set-element-count" ],
                command_output_from_args([ "nft", "-j", "list", "set", "inet", NFT_TABLE_NAME, set_name ])
            ), /[\r\n]+$/g, "");
            print("- ", set_name, ": ", count, " elements\n");
        }

        nolog("Chain configurations:");
        print(status_output(
            [ "nft-chain-config-blocks", "mangle", "proxy" ],
            command_output_from_args([ "nft", "list", "table", "inet", NFT_TABLE_NAME ])
        ));
    }
    else {
        nolog("Sets configuration:");
        print(command_output_from_args([ "nft", "list", "table", "inet", NFT_TABLE_NAME ]));
    }

    nolog("NFT check completed");
    return 0;
}

function check_logs() {
    if (!command_exists("logread")) {
        nolog("Error: logread command not found");
        return 1;
    }
    let rendered = status_capture([ "loghorizon-logs" ], command_output_from_args([ "logread" ]));
    if (rendered.output != "")
        print(rendered.output);
    if (rendered.status != 0) {
        nolog("Logs not found");
        return 1;
    }
    return 0;
}

function check_sing_box_logs() {
    if (!command_exists("logread")) {
        nolog("Error: logread command not found");
        return 1;
    }
    let rendered = status_capture([ "matching-log-tail", "sing-box", "100" ], command_output_from_args([ "logread" ]));
    if (rendered.output != "")
        print(rendered.output);
    if (rendered.status != 0) {
        nolog("sing-box logs not found");
        return 1;
    }
    return 0;
}

function loghorizon_logs_fixture() {
    let rendered = status_capture([ "loghorizon-logs" ], read_stdin());
    if (rendered.output != "")
        print(rendered.output);
    return rendered.status;
}

function show_sing_box_config(visibility) {
    visibility = as_string(visibility || "masked");
    let sing_box_config_path = option(settings(), "config_path", "");
    nolog("Current sing-box configuration:");
    if (!file_exists(sing_box_config_path)) {
        nolog("Configuration file not found");
        return 1;
    }
    if (visibility == "raw")
        print(as_string(fs.readfile(sing_box_config_path)));
    else
        print(status_output([ "mask-sing-box-config", sing_box_config_path ], null));
    return 0;
}

function show_config(visibility) {
    visibility = as_string(visibility || "masked");
    if (!file_exists(LOGHORIZON_CONFIG)) {
        nolog("Configuration file not found");
        return 1;
    }
    if (visibility == "raw")
        print(as_string(fs.readfile(LOGHORIZON_CONFIG)));
    else
        print(status_output([ "loghorizon-config-masked", LOGHORIZON_CONFIG ], null));
    return 0;
}

function show_version() {
    print(LOGHORIZON_VERSION, "\n");
    return 0;
}

function show_sing_box_version() {
    print(replace(module_output(SINGBOX_RUNTIME_UC, [ "version" ]), /[\r\n]+$/g, ""), "\n");
    return 0;
}

function get_luci_app_version() {
    let path = LOGHORIZON_LUCI_VIEW_DIR + "/main.js";
    let data = fs.readfile(path);
    if (data == null)
        return "not installed";

    for (let line in split(as_string(data), "\n")) {
        let matched = match(line, /^[ \t]*var[ \t]+([^ \t=]+)[ \t]*=[ \t]*"([^"]*)"/);
        if (matched != null && matched[1] == "LOGHORIZON_LUCI_APP_VERSION")
            return as_string(matched[2]);
    }
    return "";
}

function system_info_cache_is_valid() {
    let cache = read_json_file(SYSTEM_INFO_CACHE_FILE);
    if (type(cache) != "object")
        return false;
    let now = int(clock()[0]);
    let generated_at = arg_number(cache.generated_at || 0);
    if (now > 0 && generated_at > 0 && SYSTEM_INFO_CACHE_TTL > 0 && now - generated_at >= SYSTEM_INFO_CACHE_TTL)
        return false;
    return cache.loghorizon_version == LOGHORIZON_VERSION && cache.luci_app_version == get_luci_app_version();
}

function ensure_subscription_runtime_dirs() {
    module_success(SUBSCRIPTION_CACHE_UC, [
        "ensure-runtime-dirs"
    ]);
    ensure_dir(RUNTIME_STATE_DIR);
}

function write_system_info_cache(value) {
    ensure_subscription_runtime_dirs();
    let tmpfile = SYSTEM_INFO_CACHE_FILE + "." + clock()[0] + "." + clock()[1] + ".tmp";
    if (fs.writefile(tmpfile, as_string(value) + "\n") == null)
        return false;
    remove_file(SYSTEM_INFO_CACHE_FILE);
    if (!fs.rename(tmpfile, SYSTEM_INFO_CACHE_FILE)) {
        remove_file(tmpfile);
        return false;
    }
    return true;
}

function sing_box_marker_is(expected) {
    return module_success(SINGBOX_RUNTIME_UC, [ "marker-is", expected ]);
}

function sing_box_component_action_running() {
    return module_success(SERVICE_UI_UC, [ "component-action-running-for", "sing_box" ]);
}

function sing_box_live_probe_disabled() {
    return sing_box_marker_is("extended") ||
        sing_box_marker_is("extended-compressed") ||
        sing_box_component_action_running();
}

function sing_box_tiny_package_installed() {
    return module_success(PACKAGES_UC, [ "installed", "sing-box-tiny" ]);
}

function sing_box_capability_flags(sing_box_version, sing_box_version_output) {
    let extended = 0;
    let tiny = 0;
    let tailscale = 0;

    if (sing_box_marker_is("extended") ||
        sing_box_marker_is("extended-compressed") ||
        module_success(SINGBOX_RUNTIME_UC, [ "is-extended", sing_box_version ]))
        extended = 1;

    if (extended == 0 && (sing_box_marker_is("tiny") || sing_box_tiny_package_installed()))
        tiny = 1;

    if (extended == 1)
        tailscale = 1;
    else if (as_string(sing_box_version_output) != "") {
        if (module_success(SINGBOX_RUNTIME_UC, [ "supports-tailscale", sing_box_version, sing_box_version_output ]))
            tailscale = 1;
    }
    else if (tiny == 0 && sing_box_component_action_running())
        tailscale = 1;

    return { extended, tiny, tailscale };
}

function provider_installed(runtime_uc) {
    return module_success(runtime_uc, [ "installed" ]);
}

function provider_version(runtime_uc) {
    let value = replace(module_output(runtime_uc, [ "package-version" ]), /[\r\n]+$/g, "");
    return value != "" ? value : "unknown";
}

function openwrt_release() {
    let data = fs.readfile("/etc/os-release");
    if (data == null)
        return "unknown";
    for (let line in split(as_string(data), "\n")) {
        if (substr(line, 0, length("OPENWRT_RELEASE=")) != "OPENWRT_RELEASE=")
            continue;
        let value = substr(line, length("OPENWRT_RELEASE="));
        if (length(value) >= 2) {
            let quote = substr(value, 0, 1);
            if ((quote == "\"" || quote == "'") && substr(value, length(value) - 1) == quote)
                value = substr(value, 1, length(value) - 2);
        }
        return value != "" ? value : "unknown";
    }
    return "unknown";
}

function build_system_info() {
    let loghorizon_latest_version = first_line_value("/tmp/loghorizon.latest-version.cache", "unknown");
    let luci_app_version = get_luci_app_version();
    let sing_box_version = "";
    let sing_box_version_output = "";

    if (command_exists("sing-box")) {
        if (sing_box_live_probe_disabled()) {
            sing_box_version = replace(module_output(SINGBOX_RUNTIME_UC, [ "read-version-state" ]), /[\r\n]+$/g, "");
            sing_box_version_output = "";
        }
        else {
            sing_box_version_output = module_output(SINGBOX_RUNTIME_UC, [ "version-output" ]);
            sing_box_version = replace(module_output_stdin(SINGBOX_RUNTIME_UC, [ "version-from-output" ], sing_box_version_output), /[\r\n]+$/g, "");
        }
        if (sing_box_version == "")
            sing_box_version = "unknown";
    }
    else {
        sing_box_version = "not installed";
        sing_box_version_output = "";
    }

    let flags = sing_box_capability_flags(sing_box_version, sing_box_version_output);
    let sing_box_compressed = flags.extended == 1 && sing_box_marker_is("extended-compressed") ? 1 : 0;

    let zapret_installed = provider_installed(ZAPRET_RUNTIME_UC) ? 1 : 0;
    let zapret_version = zapret_installed ? provider_version(ZAPRET_RUNTIME_UC) : "not installed";
    let zapret2_installed = provider_installed(ZAPRET2_RUNTIME_UC) ? 1 : 0;
    let zapret2_version = zapret2_installed ? provider_version(ZAPRET2_RUNTIME_UC) : "not installed";
    let byedpi_installed = provider_installed(BYEDPI_RUNTIME_UC) ? 1 : 0;
    let byedpi_version = byedpi_installed ? provider_version(BYEDPI_RUNTIME_UC) : "not installed";
    let device_model = first_line_value("/tmp/sysinfo/model", "unknown");

    return {
        loghorizon_version: LOGHORIZON_VERSION,
        loghorizon_latest_version: loghorizon_latest_version || "unknown",
        luci_app_version,
        sing_box_version,
        sing_box_extended: flags.extended,
        sing_box_tiny: flags.tiny,
        sing_box_compressed,
        sing_box_tailscale: flags.tailscale,
        zapret_version,
        zapret_installed,
        zapret2_version,
        zapret2_installed,
        byedpi_version,
        byedpi_installed,
        openwrt_version: openwrt_release(),
        device_model,
        generated_at: int(clock()[0])
    };
}

function get_system_info() {
    if (system_info_cache_is_valid()) {
        print(as_string(fs.readfile(SYSTEM_INFO_CACHE_FILE)));
        return 0;
    }

    let system_info = sprintf("%J", build_system_info());
    write_system_info_cache(system_info);
    print(system_info, "\n");
    return 0;
}

function get_server_capabilities() {
    if (!file_executable(SING_BOX_BIN_PATH)) {
        write_json({
            sing_box_extended: 0,
            sing_box_tiny: 0,
            sing_box_tailscale: 0
        });
        return 0;
    }

    let sing_box_version_output = "";
    let sing_box_version = "";
    if (sing_box_live_probe_disabled())
        sing_box_version = replace(module_output(SINGBOX_RUNTIME_UC, [ "read-version-state" ]), /[\r\n]+$/g, "");
    else {
        sing_box_version_output = module_output(SINGBOX_RUNTIME_UC, [ "version-output" ]);
        sing_box_version = replace(module_output_stdin(SINGBOX_RUNTIME_UC, [ "version-from-output" ], sing_box_version_output), /[\r\n]+$/g, "");
    }
    let flags = sing_box_capability_flags(sing_box_version, sing_box_version_output);
    write_json({
        sing_box_extended: flags.extended,
        sing_box_tiny: flags.tiny,
        sing_box_tailscale: flags.tailscale
    });
    return 0;
}

function neutralize_zapret_defaults() {
    log_message("Standalone zapret is not neutralized automatically; logIn uses /opt/zapret/nfq/nfqws as an external provider and manages only its own NFQUEUE range.", "info");
    return 0;
}

function sing_box_process_is_running() {
    return command_success_from_args([ "pgrep", "-x", "sing-box" ]) ||
        command_success_from_args([ "pgrep", "-f", "^/usr/bin/sing-box[[:space:]]" ]);
}

function service_status_label(running, enabled) {
    if (arg_number(running) == 1)
        return arg_number(enabled) == 1 ? "running & enabled" : "running but disabled";
    return arg_number(enabled) == 1 ? "stopped but enabled" : "stopped & disabled";
}

function write_service_status(running, enabled, dns_configured) {
    write_json({
        running,
        enabled,
        status: service_status_label(running, enabled),
        dns_configured
    });
}

function dnsmasq_has_loghorizon_dns() {
    return module_success(DNS_APPLY_UC, [ "has-loghorizon-dns" ]);
}

function get_sing_box_status() {
    let running = module_success(SERVICE_STATE_UC, [
        "sing-box-service-stable",
        RUNTIME_STABLE_MIN_AGE
    ]) ? 1 : 0;
    let enabled = file_executable("/etc/rc.d/S99sing-box") ? 1 : 0;
    let dns_configured = dnsmasq_has_loghorizon_dns() ? 1 : 0;
    write_service_status(running, enabled, dns_configured);
    return 0;
}

function get_status() {
    let running = module_success(SERVICE_STATE_UC, [
        "loghorizon-stably-running", RT_TABLE_NAME, NFT_TABLE_NAME, NFT_FAKEIP_MARK, RUNTIME_STABLE_MIN_AGE
    ]) ? 1 : 0;
    let enabled = file_executable("/etc/rc.d/S99" + LOGHORIZON_SERVICE_NAME) ? 1 : 0;
    let dns_configured = dnsmasq_has_loghorizon_dns() ? 1 : 0;
    write_service_status(running, enabled, dns_configured);
    return 0;
}

function subscription_cache(args) {
    return module_capture(SUBSCRIPTION_CACHE_UC, args);
}

function print_subscription_result(result, fallback) {
    if (result.status == 0 && result.output != "") {
        print(result.output);
        return 0;
    }
    print(as_string(fallback));
    return 0;
}

function section_safe(section) {
    section = as_string(section);
    return section != "" && index(section, "/") < 0 && index(section, "..") < 0;
}

function get_outbound_metadata(section) {
    subscription_cache([ "ensure-runtime-dirs" ]);
    if (!section_safe(section))
        return print_subscription_result(subscription_cache([ "empty-outbound-metadata" ]), "");
    let metadata_path = replace(module_output(SUBSCRIPTION_CACHE_UC, [ "outbound-metadata-path", section ]), /[\r\n]+$/g, "");
    if (metadata_path == "")
        return print_subscription_result(subscription_cache([ "empty-outbound-metadata" ]), "");
    let result = subscription_cache([ "get-outbound-metadata", SECTION_CACHE_DIR, section, metadata_path ]);
    if (result.status != 0)
        result = subscription_cache([ "empty-outbound-metadata" ]);
    return print_subscription_result(result, "");
}

function get_subscription_metadata(section) {
    subscription_cache([ "ensure-runtime-dirs" ]);
    if (!section_safe(section)) {
        print("{}\n");
        return 0;
    }
    let metadata_path = replace(module_output(SUBSCRIPTION_CACHE_UC, [ "subscription-metadata-path", section ]), /[\r\n]+$/g, "");
    if (metadata_path == "") {
        print("{}\n");
        return 0;
    }
    let result = subscription_cache([ "get-subscription-metadata", SECTION_CACHE_DIR, section, metadata_path ]);
    return print_subscription_result(result, "{}\n");
}

function validate_nfqws_strategy_json(raw_opt) {
    let result = module_capture(ZAPRET_VALIDATOR_UC, [
        "validate-json", "nfqws", as_string(raw_opt), ZAPRET_LEGACY_DEFAULT_NFQWS_OPT
    ]);
    if (result.output != "")
        print(result.output);
    return 0;
}

function validate_nfqws2_strategy_json(raw_opt) {
    let result = module_capture(ZAPRET2_VALIDATOR_UC, [ "validate-json", "nfqws2", as_string(raw_opt) ]);
    if (result.output != "")
        print(result.output);
    return 0;
}

function url_host(value) {
    return helper_output("url-get-host", [ value ]);
}

function device_ipv4_address(interface) {
    let value = replace(module_output(SINGBOX_RUNTIME_UC, [ "device-ipv4-address", interface ]), /[\r\n]+$/g, "");
    if (value != "")
        return value;

    let output = command_output_from_args([ "ip", "-4", "addr", "show", "dev", interface ]);
    for (let line in split(output, "\n")) {
        line = trim(as_string(line));
        let matched = match(line, /^inet[ \t]+([0-9.]+)\//);
        if (matched != null)
            return as_string(matched[1]);
    }
    return "";
}

function dns_check_router_resolver_available(domain) {
    for (let address in [ "127.0.0.1", SB_DNS_INBOUND_ADDRESS ]) {
        if (address != "" && command_success_from_args([ "dig", "@" + address, domain, "+timeout=2", "+tries=1" ]))
            return true;
    }

    let listen_address = replace(module_output(SINGBOX_RUNTIME_UC, [ "service-listen-address" ]), /[\r\n]+$/g, "");
    if (listen_address != "" && command_success_from_args([ "dig", "@" + listen_address, domain, "+timeout=2", "+tries=1" ]))
        return true;

    let source_interfaces = option(settings(), "source_network_interfaces", "br-lan");
    for (let interface in words(source_interfaces)) {
        let address = device_ipv4_address(interface);
        if (address != "" && command_success_from_args([ "dig", "@" + address, domain, "+timeout=2", "+tries=1" ]))
            return true;
    }

    return false;
}

function dns_check_timeout_seconds(value) {
    let rest = as_string(value);
    let milliseconds = 0.0;
    let units = { ns: 0.000001, us: 0.001, ms: 1, s: 1000, m: 60000, h: 3600000, d: 86400000 };
    while (rest != "") {
        let matched = match(rest, /^([0-9]+(\.[0-9]+)?)(ns|us|ms|s|m|h|d)/);
        if (!matched)
            return 2;
        milliseconds += (matched[1] * 1) * units[matched[3]];
        rest = substr(rest, length(matched[0]));
    }
    return milliseconds > 0 ? int((milliseconds + 999) / 1000) : 2;
}

function check_dns_available() {
    let cfg = settings();
    let active = runtime_dns.active_values(cfg);
    let dns_type = runtime_dns.dns_type_from_scheme(active.main, option(cfg, "dns_type", ""));
    let dns_server = active.main;
    let bootstrap_dns_server = active.bootstrap;
    let dont_touch_dhcp = bool_option(cfg, "dont_touch_dhcp", false) ? 1 : 0;
    let domain = "example.com";
    let timeout_seconds = dns_check_timeout_seconds(option(cfg, "dns_check_timeout", "2s"));
    let dns_status = 0;
    let dns_on_router = 0;
    let bootstrap_dns_status = 0;
    let dhcp_config_status = 1;

    let active_dns_args = [ "dig" ];
    if (runtime_dns.failover_enabled(cfg)) {
        push(active_dns_args, "-p");
        push(active_dns_args, as_string(runtime_dns.health_port("active", 0)));
    }
    push(active_dns_args, "@" + SB_DNS_INBOUND_ADDRESS);
    push(active_dns_args, domain);
    push(active_dns_args, "A");
    push(active_dns_args, "+short");
    push(active_dns_args, "+timeout=" + as_string(timeout_seconds));
    push(active_dns_args, "+tries=1");
    for (let line in split(command_output_from_args(active_dns_args), "\n"))
        if (valid_ipv4(trim(as_string(line)))) {
            dns_status = 1;
            break;
        }

    if (dns_check_router_resolver_available(domain))
        dns_on_router = 1;

    if (bootstrap_dns_server != "") {
        for (let line in split(command_output_from_args([
            "dig", "-p", as_string(runtime_dns.health_port("bootstrap", active.state.bootstrap_index)),
            "@" + runtime_dns.DNS_HEALTH_ADDRESS, domain, "A", "+short",
            "+timeout=" + as_string(timeout_seconds), "+tries=1"
        ]), "\n"))
            if (valid_ipv4(trim(as_string(line)))) {
                bootstrap_dns_status = 1;
                break;
            }
    }

    if (!module_success(DNS_APPLY_UC, [ "default-config-complete" ]))
        dhcp_config_status = 0;

    let display_dns_server = replace(status_output([ "mask-dns-server", dns_server ], null), /[\r\n]+$/g, "");
    write_json({
        dns_type,
        dns_server: display_dns_server,
        dns_server_index: active.state.main_index,
        dns_server_count: length(active.state.main_servers),
        dns_status,
        dns_on_router,
        bootstrap_dns_server,
        bootstrap_dns_server_index: active.state.bootstrap_index,
        bootstrap_dns_server_count: length(active.state.bootstrap_servers),
        bootstrap_dns_status,
        dhcp_config_status,
        dont_touch_dhcp,
        // Whether the provider can still see the DNS traffic at all. Detoured
        // requests go inside the tunnel, where there is nothing left to read.
        dns_detoured: as_string(active.state.dns_detour) != "" ? 1 : 0,
        dns_ech: active.state.dns_ech ? 1 : 0
    });
    return 0;
}

function connectivity_probe_number(value) {
    value = trim(as_string(value));
    return value != "" ? value * 1 : 0;
}

function connectivity_probe_milliseconds(value) {
    return int((connectivity_probe_number(value) * 1000) + 0.5);
}

function classify_connectivity_probe(status, output) {
    let fields = split(replace(as_string(output), /[\r\n]+$/g, ""), "\t");
    let http_code = int(fields[0] || "0", 10);
    let connect_seconds = connectivity_probe_number(fields[1]);
    let tls_seconds = connectivity_probe_number(fields[2]);
    let total_seconds = connectivity_probe_number(fields[3]);
    let stage = "ok";
    let reason = "server_responded";
    let available = status == 0 && http_code > 0;

    if (!available) {
        if (status == 6) {
            stage = "dns";
            reason = "dns_failed";
        }
        else if (connect_seconds <= 0) {
            stage = "tcp";
            reason = status == 28 ? "tcp_timeout" : "tcp_failed";
        }
        else if (tls_seconds <= 0) {
            stage = "tls";
            reason = status == 28 ? "tls_timeout" : "tls_failed";
        }
        else {
            stage = "http";
            reason = status == 28 ? "http_timeout" : "http_failed";
        }
    }

    return {
        available: available ? 1 : 0,
        stage,
        reason,
        curl_status: status,
        http_code,
        tcp_ms: connectivity_probe_milliseconds(connect_seconds),
        tls_ms: connectivity_probe_milliseconds(tls_seconds > connect_seconds ? tls_seconds - connect_seconds : 0),
        total_ms: connectivity_probe_milliseconds(total_seconds)
    };
}

function connectivity_probe_classify_fixture() {
    let input = parse_json_or_null(read_stdin());
    if (type(input) != "object")
        return 1;
    write_json(classify_connectivity_probe(int(input.status || 0, 10), as_string(input.output)));
    return 0;
}

function diagnostic_uint_file(path) {
    let value = trim(as_string(fs.readfile(path)));
    return match(value, /^[0-9]+$/) != null ? int(value, 10) : null;
}

function connectivity_cpu_sample(data) {
    let first = split(as_string(data), "\n")[0] || "";
    let fields = words(first);
    if (length(fields) < 5 || fields[0] != "cpu")
        return null;
    let total = 0;
    for (let i = 1; i < length(fields) && i <= 8; i++)
        total += arg_number(fields[i]);
    return { total, idle: arg_number(fields[4]) + arg_number(fields[5]) };
}

function connectivity_memory_sample(data) {
    let total_kib = null;
    let available_kib = null;
    for (let line in split(as_string(data), "\n")) {
        let matched = match(line, /^(MemTotal|MemAvailable):[ \t]+([0-9]+)[ \t]+kB$/);
        if (!matched)
            continue;
        if (matched[1] == "MemTotal")
            total_kib = int(matched[2], 10);
        else
            available_kib = int(matched[2], 10);
    }
    return { total_kib, available_kib };
}

function connectivity_nfqueue_sample(data) {
    let result = { available: data != null ? 1 : 0, queues: 0, queued: 0, kernel_dropped: 0, userspace_dropped: 0 };
    if (data == null)
        return result;
    for (let line in split(as_string(data), "\n")) {
        let fields = words(line);
        if (length(fields) < 7)
            continue;
        result.queues++;
        result.queued += arg_number(fields[2]);
        result.kernel_dropped += arg_number(fields[5]);
        result.userspace_dropped += arg_number(fields[6]);
    }
    return result;
}

function connectivity_default_interfaces() {
    let seen = {};
    for (let family in [ "-4", "-6" ]) {
        for (let line in split(command_output_from_args([ "ip", family, "route", "show", "default" ]), "\n")) {
            let fields = words(line);
            for (let i = 0; i + 1 < length(fields); i++)
                if (fields[i] == "dev" && match(fields[i + 1], /^[A-Za-z0-9_.:@-]+$/) != null)
                    seen[fields[i + 1]] = true;
        }
    }
    return sort(keys(seen));
}

function connectivity_qdisc_sample(interface) {
    if (!command_exists("tc"))
        return { available: 0, backlog_bytes: 0, backlog_packets: 0, requeues: 0 };
    let result = { available: 1, backlog_bytes: 0, backlog_packets: 0, requeues: 0 };
    for (let line in split(command_output_from_args([ "tc", "-s", "qdisc", "show", "dev", interface ]), "\n")) {
        let matched = match(line, /backlog[ \t]+([0-9]+)b[ \t]+([0-9]+)p[ \t]+requeues[ \t]+([0-9]+)/);
        if (!matched)
            continue;
        result.backlog_bytes += int(matched[1], 10);
        result.backlog_packets += int(matched[2], 10);
        result.requeues += int(matched[3], 10);
    }
    return result;
}

function connectivity_resource_snapshot() {
    let interfaces = [];
    for (let interface in connectivity_default_interfaces()) {
        let base = "/sys/class/net/" + interface + "/statistics/";
        push(interfaces, {
            name: interface,
            rx_dropped: diagnostic_uint_file(base + "rx_dropped") || 0,
            tx_dropped: diagnostic_uint_file(base + "tx_dropped") || 0,
            qdisc: connectivity_qdisc_sample(interface)
        });
    }
    let load = words(as_string(fs.readfile("/proc/loadavg")));
    return {
        cpu: connectivity_cpu_sample(fs.readfile("/proc/stat")),
        memory: connectivity_memory_sample(fs.readfile("/proc/meminfo")),
        load: { one: load[0] || "", five: load[1] || "", fifteen: load[2] || "" },
        conntrack: {
            count: diagnostic_uint_file("/proc/sys/net/netfilter/nf_conntrack_count"),
            max: diagnostic_uint_file("/proc/sys/net/netfilter/nf_conntrack_max")
        },
        nfqueue: connectivity_nfqueue_sample(fs.readfile("/proc/net/netfilter/nfnetlink_queue")),
        interfaces
    };
}

function nonnegative_delta(after, before) {
    after = after == null ? 0 : after;
    before = before == null ? 0 : before;
    return after >= before ? after - before : 0;
}

function connectivity_resource_result(before, after) {
    let cpu_percent = null;
    if (before.cpu && after.cpu) {
        let total_delta = nonnegative_delta(after.cpu.total, before.cpu.total);
        let idle_delta = nonnegative_delta(after.cpu.idle, before.cpu.idle);
        if (total_delta > 0)
            cpu_percent = int((((total_delta - idle_delta) * 1000) / total_delta) + 0.5) / 10;
    }

    let before_interfaces = {};
    for (let item in before.interfaces || [])
        before_interfaces[item.name] = item;
    let interfaces = [];
    for (let item in after.interfaces || []) {
        let previous = before_interfaces[item.name] || {};
        push(interfaces, {
            name: item.name,
            rx_dropped_delta: nonnegative_delta(item.rx_dropped, previous.rx_dropped),
            tx_dropped_delta: nonnegative_delta(item.tx_dropped, previous.tx_dropped),
            qdisc: item.qdisc
        });
    }

    return {
        cpu_percent,
        memory: after.memory,
        load: after.load,
        conntrack: after.conntrack,
        nfqueue: {
            available: after.nfqueue.available,
            queues: after.nfqueue.queues,
            queued: after.nfqueue.queued,
            kernel_dropped_delta: nonnegative_delta(after.nfqueue.kernel_dropped, before.nfqueue.kernel_dropped),
            userspace_dropped_delta: nonnegative_delta(after.nfqueue.userspace_dropped, before.nfqueue.userspace_dropped)
        },
        interfaces
    };
}

function connectivity_resource_fixture() {
    let input = parse_json_or_null(read_stdin());
    if (type(input) != "object" || type(input.before) != "object" || type(input.after) != "object")
        return 1;
    write_json(connectivity_resource_result(input.before, input.after));
    return 0;
}

function connectivity_resolve(host, query_type) {
    let active = runtime_dns.active_values(settings());
    let args = [
        "dig", "-p", as_string(runtime_dns.health_port("bootstrap", active.state.bootstrap_index)),
        "@" + runtime_dns.DNS_HEALTH_ADDRESS, host, query_type, "+short", "+timeout=2", "+tries=1"
    ];
    for (let line in split(command_output_from_args(args), "\n")) {
        let address = trim(as_string(line));
        if ((query_type == "A" && valid_ipv4(address)) || (query_type == "AAAA" && core_ip.valid_ipv6(address)))
            return address;
    }
    return "";
}

function connectivity_https_probe(host, url, address) {
    if (address == "")
        return {
            available: 0,
            stage: "dns",
            reason: "dns_failed",
            curl_status: 6,
            http_code: 0,
            tcp_ms: 0,
            tls_ms: 0,
            total_ms: 0
        };

    let resolve_address = index(address, ":") >= 0 ? "[" + address + "]" : address;
    let args = [
        "curl", "-sS", "--connect-timeout", "3", "--max-time", "5",
        "--resolve", host + ":443:" + resolve_address,
        "-o", "/dev/null", "-w", "%{http_code}\\t%{time_connect}\\t%{time_appconnect}\\t%{time_total}\\n",
        url
    ];
    let result = command_capture(command_from_args(args) + " 2>/dev/null");
    return classify_connectivity_probe(result.status, result.output);
}

function connectivity_family_probe(family, route_available, host, url) {
    let address = connectivity_resolve(host, family == "ipv6" ? "AAAA" : "A");
    let fake_address = index(address, "198.18.") == 0 || index(address, "198.19.") == 0 || index(lc(address), "fc") == 0 || index(lc(address), "fd") == 0;
    if (!route_available && !fake_address)
        return { available: 0, skipped: 1, stage: "route", reason: "no_default_route", curl_status: 0, http_code: 0, tcp_ms: 0, tls_ms: 0, total_ms: 0, dns_available: address != "" ? 1 : 0 };

    let result = connectivity_https_probe(host, url, address);
    result.skipped = 0;
    result.dns_available = address != "" ? 1 : 0;
    return result;
}

function connectivity_doq_classify(status, output, log_output) {
    let response = as_string(output);
    let logs = lc(as_string(log_output));
    let timing = match(response, /Query time:[ \t]+([0-9]+)[ \t]+msec/);
    let available = status == 0 && match(response, /status:[ \t]+NOERROR/) != null;
    let reason = "doq_available";
    if (!available) {
        if (index(logs, "certificate") >= 0 || index(logs, "tls handshake") >= 0)
            reason = "doq_tls_failed";
        else if (index(logs, "network is unreachable") >= 0 || index(logs, "no route to host") >= 0)
            reason = "doq_route_unavailable";
        else if (index(logs, "timeout") >= 0 || index(logs, "deadline exceeded") >= 0 || status == 9)
            reason = "doq_timeout";
        else if (status == 0)
            reason = "doq_dns_response_error";
        else
            reason = "doq_failed";
    }
    return {
        available: available ? 1 : 0,
        reason,
        latency_ms: timing ? int(timing[1], 10) : 0
    };
}

function connectivity_doq_classify_fixture() {
    let input = parse_json_or_null(read_stdin());
    if (type(input) != "object")
        return 1;
    write_json(connectivity_doq_classify(int(input.status || 0, 10), input.output, input.log_output));
    return 0;
}

function connectivity_doq_config(target, port) {
    return {
        log: { level: "error", timestamp: false },
        dns: {
            servers: [ {
                type: "quic",
                tag: "doq-control",
                server: target.address,
                server_port: 853,
                tls: { enabled: true, server_name: target.server_name }
            } ],
            final: "doq-control",
            strategy: "ipv4_only"
        },
        inbounds: [ { type: "direct", tag: "dns-in", listen: "127.0.0.1", listen_port: port } ],
        outbounds: [ { type: "direct", tag: "direct" } ],
        route: {
            rules: [ { action: "hijack-dns", inbound: "dns-in" } ],
            final: "direct",
            auto_detect_interface: true
        }
    };
}

function connectivity_doq_target(target, port, work_dir) {
    let config_path = work_dir + "/" + target.name + ".json";
    let log_path = work_dir + "/" + target.name + ".log";
    if (fs.writefile(config_path, sprintf("%J\n", connectivity_doq_config(target, port))) == null)
        return { name: target.name, available: 0, reason: "doq_setup_failed", latency_ms: 0 };

    command_success_from_args([ "chmod", "600", config_path ]);
    let script = command_from_args([ SING_BOX_BIN_PATH, "run", "-c", config_path ]) +
        " >" + shell_quote(log_path) + " 2>&1 & pid=$!; " +
        "trap 'kill $pid 2>/dev/null; wait $pid 2>/dev/null' EXIT INT TERM; " +
        "sleep 1; " +
        command_from_args([ "dig", "@127.0.0.1", "-p", as_string(port), "www.gstatic.com", "A", "+time=4", "+tries=1", "+stats" ]) +
        " 2>&1; rc=$?; exit $rc";
    let captured = command_capture(command_from_args([ "sh", "-c", script ]));
    let result = connectivity_doq_classify(captured.status, captured.output, fs.readfile(log_path));
    result.name = target.name;
    return result;
}

function connectivity_quic_probe() {
    let version = command_output_from_args([ SING_BOX_BIN_PATH, "version" ]);
    if (version == "" || index(version, "with_quic") < 0)
        return { supported: 0, available: 0, skipped: 1, degraded: 0, reason: "diagnostic_core_has_no_quic", targets: [] };

    let work_dir = trim(command_output_from_args([ "mktemp", "-d", "/tmp/loghorizon-doq.XXXXXX" ]));
    if (work_dir == "")
        return { supported: 1, available: 0, skipped: 1, degraded: 0, reason: "doq_setup_failed", targets: [] };

    let pid_fields = words(as_string(fs.readfile("/proc/self/stat")));
    let base_port = 20000 + (arg_number(pid_fields[0]) % 30000);
    let targets = [];
    let controls = [
        { name: "adguard", address: "94.140.14.14", server_name: "dns.adguard-dns.com" },
        { name: "alidns", address: "223.5.5.5", server_name: "dns.alidns.com" }
    ];
    for (let i = 0; i < length(controls); i++)
        push(targets, connectivity_doq_target(controls[i], base_port + i, work_dir));

    for (let target in controls) {
        fs.unlink(work_dir + "/" + target.name + ".json");
        fs.unlink(work_dir + "/" + target.name + ".log");
    }
    command_success_from_args([ "rmdir", work_dir ]);
    let successful = 0;
    for (let target in targets)
        if (target.available)
            successful++;
    return {
        supported: 1,
        available: successful > 0 ? 1 : 0,
        skipped: 0,
        degraded: successful > 0 && successful < length(targets) ? 1 : 0,
        reason: successful == length(targets) ? "doq_available" : (successful > 0 ? "doq_degraded" : "doq_failed"),
        successful_targets: successful,
        target_count: length(targets),
        targets
    };
}

function connectivity_summary(ipv4, ipv6, quic) {
    if (ipv4.available || ipv6.available)
        return quic.supported && !quic.available ? "https_ok_quic_failed" : "https_ok";
    if ((!ipv4.skipped && ipv4.stage == "dns") || (!ipv6.skipped && ipv6.stage == "dns"))
        return "dns_failed";
    if ((!ipv4.skipped && ipv4.stage == "tcp") || (!ipv6.skipped && ipv6.stage == "tcp"))
        return "tcp_failed";
    if ((!ipv4.skipped && ipv4.stage == "tls") || (!ipv6.skipped && ipv6.stage == "tls"))
        return "tls_failed";
    return "unknown";
}

function connectivity_clash_api_url() {
    let address = replace(module_output(SINGBOX_RUNTIME_UC, [ "service-listen-address" ]), /[\r\n]+$/g, "");
    if (address == "")
        address = "127.0.0.1";
    return address + ":" + SB_CLASH_API_CONTROLLER_PORT;
}

function connectivity_clash_auth_args() {
    let cfg = settings();
    if (!bool_option(cfg, "enable_yacd_wan_access", false))
        return [];
    return [ "--header", "Authorization: Bearer " + option(cfg, "yacd_secret_key", "") ];
}

function connectivity_clash_urlencode(value) {
    return replace(status_output([ "url-encode", value ], null), /[\r\n]+$/g, "");
}

function connectivity_route_roots(config) {
    let route = object_or_empty(object_or_empty(config).route);
    let roots = [];
    let seen = {};
    let final_tag = as_string(route.final);
    if (final_tag != "") {
        push(roots, final_tag);
        seen[final_tag] = true;
    }
    for (let rule in array_or_empty(route.rules)) {
        let tag = as_string(object_or_empty(rule).outbound);
        if (tag != "" && !seen[tag]) {
            push(roots, tag);
            seen[tag] = true;
        }
    }
    return roots;
}

function connectivity_user_proxy_leaf(proxies, root) {
    let current = as_string(root);
    let visited = {};
    for (let depth = 0; depth < 16 && current != ""; depth++) {
        if (visited[current])
            return null;
        visited[current] = true;
        let proxy = object_or_empty(object_or_empty(proxies)[current]);
        if (length(keys(proxy)) == 0)
            return null;
        let selected = as_string(proxy.now);
        if (selected != "" && selected != current) {
            current = selected;
            continue;
        }
        let proxy_type = as_string(proxy.type);
        let ignored = lc(proxy_type);
        if (ignored == "" || ignored == "direct" || ignored == "reject" || ignored == "block" ||
            ignored == "dns" || ignored == "compatible" || ignored == "selector" ||
            ignored == "fallback" || ignored == "urltest")
            return null;
        return { tag: current, type: proxy_type };
    }
    return null;
}

function connectivity_user_server_selection(config, proxies) {
    let servers = [];
    let seen = {};
    for (let root in connectivity_route_roots(config)) {
        let leaf = connectivity_user_proxy_leaf(proxies, root);
        if (leaf == null || seen[leaf.tag])
            continue;
        seen[leaf.tag] = true;
        push(servers, leaf);
        if (length(servers) >= 4)
            break;
    }
    return servers;
}

function connectivity_user_server_delay(base_url, auth, server, url) {
    let endpoint = base_url + "/proxies/" + connectivity_clash_urlencode(server.tag) + "/delay";
    let args = [ "curl", "-G", "-sS", "--max-time", "4", endpoint ];
    for (let item in auth) push(args, item);
    push(args, "--data-urlencode");
    push(args, "url=" + url);
    push(args, "--data-urlencode");
    push(args, "timeout=2500");
    let captured = command_capture(command_from_args(args) + " 2>/dev/null");
    let value = parse_json_or_null(captured.output);
    let delay = arg_number(object_or_empty(value).delay);
    return {
        available: captured.status == 0 && delay > 0 ? 1 : 0,
        delay_ms: delay,
        curl_status: captured.status
    };
}

function connectivity_user_server_classify(server, primary, fallback) {
    if (primary.available)
        return { name: server.tag, type: server.type, available: 1, degraded: 0, reason: "primary_available", delay_ms: primary.delay_ms };
    if (fallback.available)
        return { name: server.tag, type: server.type, available: 1, degraded: 1, reason: "fallback_available", delay_ms: fallback.delay_ms };
    return { name: server.tag, type: server.type, available: 0, degraded: 0, reason: "server_unavailable", delay_ms: 0 };
}

function connectivity_user_servers_probe() {
    let config = read_json_file(SING_BOX_CONFIG_PATH);
    if (config == null)
        return { available: 0, skipped: 1, degraded: 0, reason: "config_unavailable", servers: [] };

    let base_url = connectivity_clash_api_url();
    let auth = connectivity_clash_auth_args();
    let args = [ "curl", "-sS", "--max-time", "3" ];
    for (let item in auth) push(args, item);
    push(args, base_url + "/proxies");
    let response = command_capture(command_from_args(args) + " 2>/dev/null");
    let payload = parse_json_or_null(response.output);
    if (response.status != 0 || payload == null)
        return { available: 0, skipped: 1, degraded: 0, reason: "clash_api_unavailable", servers: [] };

    let selected = connectivity_user_server_selection(config, object_or_empty(object_or_empty(payload).proxies));
    if (length(selected) == 0)
        return { available: 0, skipped: 1, degraded: 0, reason: "no_active_user_server", servers: [] };

    let servers = [];
    let successful = 0;
    let degraded = 0;
    for (let server in selected) {
        let primary = connectivity_user_server_delay(base_url, auth, server, "https://www.gstatic.com/generate_204");
        let fallback = primary.available
            ? { available: 0, delay_ms: 0, curl_status: 0 }
            : connectivity_user_server_delay(base_url, auth, server, "https://cp.cloudflare.com/generate_204");
        let result = connectivity_user_server_classify(server, primary, fallback);
        push(servers, result);
        if (result.available)
            successful++;
        if (result.degraded)
            degraded = 1;
    }
    return {
        available: successful > 0 ? 1 : 0,
        skipped: 0,
        degraded: degraded || successful < length(servers) ? 1 : 0,
        reason: successful == length(servers) && !degraded ? "servers_available" : (successful > 0 ? "servers_degraded" : "servers_unavailable"),
        successful_servers: successful,
        server_count: length(servers),
        servers
    };
}

function connectivity_user_server_selection_fixture() {
    let fixture = object_or_empty(parse_json_or_null(read_stdin()));
    write_json(connectivity_user_server_selection(object_or_empty(fixture.config), object_or_empty(fixture.proxies)));
    return 0;
}

function connectivity_user_server_classify_fixture() {
    let fixture = object_or_empty(parse_json_or_null(read_stdin()));
    write_json(connectivity_user_server_classify(
        object_or_empty(fixture.server),
        object_or_empty(fixture.primary),
        object_or_empty(fixture.fallback)
    ));
    return 0;
}

function connectivity_history_safe_token(value, fallback) {
    value = as_string(value);
    return value != "" && length(value) <= 32 && match(value, /^[A-Za-z0-9._+-]+$/) != null
        ? value
        : as_string(fallback);
}

function connectivity_history_probe(probe) {
    probe = object_or_empty(probe);
    return {
        available: probe.available ? 1 : 0,
        skipped: probe.skipped ? 1 : 0,
        stage: connectivity_history_safe_token(probe.stage, "unknown"),
        reason: connectivity_history_safe_token(probe.reason, "unknown"),
        curl_status: arg_number(probe.curl_status),
        http_code: arg_number(probe.http_code),
        tcp_ms: arg_number(probe.tcp_ms),
        tls_ms: arg_number(probe.tls_ms),
        total_ms: arg_number(probe.total_ms)
    };
}

function connectivity_history_quic(quic) {
    quic = object_or_empty(quic);
    let targets = [];
    for (let target in array_or_empty(quic.targets)) {
        target = object_or_empty(target);
        push(targets, {
            name: connectivity_history_safe_token(target.name, "control"),
            available: target.available ? 1 : 0,
            reason: connectivity_history_safe_token(target.reason, "unknown"),
            latency_ms: arg_number(target.latency_ms)
        });
        if (length(targets) >= 4)
            break;
    }
    return {
        supported: quic.supported ? 1 : 0,
        available: quic.available ? 1 : 0,
        skipped: quic.skipped ? 1 : 0,
        degraded: quic.degraded ? 1 : 0,
        reason: connectivity_history_safe_token(quic.reason, "unknown"),
        targets
    };
}

function connectivity_history_user_servers(user_servers) {
    user_servers = object_or_empty(user_servers);
    let servers = [];
    for (let server in array_or_empty(user_servers.servers)) {
        server = object_or_empty(server);
        push(servers, {
            type: connectivity_history_safe_token(server.type, "unknown"),
            available: server.available ? 1 : 0,
            degraded: server.degraded ? 1 : 0,
            reason: connectivity_history_safe_token(server.reason, "unknown"),
            delay_ms: arg_number(server.delay_ms)
        });
        if (length(servers) >= 4)
            break;
    }
    return {
        available: user_servers.available ? 1 : 0,
        skipped: user_servers.skipped ? 1 : 0,
        degraded: user_servers.degraded ? 1 : 0,
        reason: connectivity_history_safe_token(user_servers.reason, "unknown"),
        successful_servers: arg_number(user_servers.successful_servers),
        server_count: arg_number(user_servers.server_count),
        servers
    };
}

function connectivity_history_resources(resources) {
    resources = object_or_empty(resources);
    let memory = object_or_empty(resources.memory);
    let load = object_or_empty(resources.load);
    let conntrack = object_or_empty(resources.conntrack);
    let nfqueue = object_or_empty(resources.nfqueue);
    let interface_rx_drops = 0;
    let interface_tx_drops = 0;
    let qdisc_backlog_packets = 0;
    for (let interface in array_or_empty(resources.interfaces)) {
        interface = object_or_empty(interface);
        interface_rx_drops += arg_number(interface.rx_dropped_delta);
        interface_tx_drops += arg_number(interface.tx_dropped_delta);
        qdisc_backlog_packets += arg_number(object_or_empty(interface.qdisc).backlog_packets);
    }
    return {
        cpu_percent: resources.cpu_percent == null ? null : resources.cpu_percent,
        memory_total_kib: memory.total_kib == null ? null : arg_number(memory.total_kib),
        memory_available_kib: memory.available_kib == null ? null : arg_number(memory.available_kib),
        load_one: connectivity_history_safe_token(load.one, "unknown"),
        load_five: connectivity_history_safe_token(load.five, "unknown"),
        load_fifteen: connectivity_history_safe_token(load.fifteen, "unknown"),
        conntrack_count: conntrack.count == null ? null : arg_number(conntrack.count),
        conntrack_max: conntrack.max == null ? null : arg_number(conntrack.max),
        nfqueue_kernel_drops: arg_number(nfqueue.kernel_dropped_delta),
        nfqueue_userspace_drops: arg_number(nfqueue.userspace_dropped_delta),
        interface_rx_drops,
        interface_tx_drops,
        qdisc_backlog_packets
    };
}

function connectivity_history_entry(result, timestamp) {
    result = object_or_empty(result);
    return {
        timestamp: arg_number(timestamp),
        available: result.available ? 1 : 0,
        summary: connectivity_history_safe_token(result.summary, "unknown"),
        ipv4: connectivity_history_probe(result.ipv4),
        ipv6: connectivity_history_probe(result.ipv6),
        quic: connectivity_history_quic(result.quic),
        user_servers: connectivity_history_user_servers(result.user_servers),
        resources: connectivity_history_resources(result.resources)
    };
}

function connectivity_history_limit() {
    return CONNECTIVITY_HISTORY_MAX_ENTRIES > 0 && CONNECTIVITY_HISTORY_MAX_ENTRIES <= 128
        ? CONNECTIVITY_HISTORY_MAX_ENTRIES
        : 32;
}

function connectivity_history_updated(history, result, timestamp) {
    history = object_or_empty(history);
    let entries = array_or_empty(history.entries);
    let next_entries = [];
    let max_entries = connectivity_history_limit();
    let keep_from = length(entries) >= max_entries ? length(entries) - max_entries + 1 : 0;
    for (let i = keep_from; i < length(entries); i++)
        push(next_entries, entries[i]);
    push(next_entries, connectivity_history_entry(result, timestamp));
    return { format_version: 1, max_entries, entries: next_entries };
}

function connectivity_history_store(result) {
    let parent = trim(command_output_from_args([ "dirname", CONNECTIVITY_HISTORY_FILE ]));
    if (parent == "" || !ensure_dir(parent))
        return { saved: 0, reason: "history_directory_failed" };

    let history = null;
    if (file_exists(CONNECTIVITY_HISTORY_FILE)) {
        history = read_json_file(CONNECTIVITY_HISTORY_FILE);
        if (history == null || type(object_or_empty(history).entries) != "array")
            return { saved: 0, reason: "history_invalid" };
    }
    let updated = connectivity_history_updated(history, result, int(clock()[0]));
    let temporary = CONNECTIVITY_HISTORY_FILE + ".tmp." + as_string(int(clock()[0])) + "." + as_string(int(clock()[1]));
    if (fs.writefile(temporary, sprintf("%J\n", updated)) == null)
        return { saved: 0, reason: "history_write_failed" };
    if (!command_success_from_args([ "chmod", "600", temporary ]) || !fs.rename(temporary, CONNECTIVITY_HISTORY_FILE)) {
        remove_file(temporary);
        return { saved: 0, reason: "history_commit_failed" };
    }
    return { saved: 1, reason: "history_saved" };
}

function connectivity_history_get() {
    if (!file_exists(CONNECTIVITY_HISTORY_FILE)) {
        write_json({ format_version: 1, max_entries: connectivity_history_limit(), entries: [] });
        return 0;
    }
    let history = read_json_file(CONNECTIVITY_HISTORY_FILE);
    if (history == null || type(object_or_empty(history).entries) != "array") {
        write_json({ available: 0, reason: "history_invalid" });
        return 1;
    }
    write_json(history);
    return 0;
}

function connectivity_history_entry_fixture() {
    write_json(connectivity_history_entry(object_or_empty(parse_json_or_null(read_stdin())), 1700000000));
    return 0;
}

function connectivity_history_updated_fixture() {
    let fixture = object_or_empty(parse_json_or_null(read_stdin()));
    write_json(connectivity_history_updated(fixture.history, object_or_empty(fixture.result), 1700000000));
    return 0;
}

function check_connectivity_path() {
    if (!command_exists("curl") || !command_exists("dig")) {
        let result = { available: 0, summary: "diagnostic_tools_missing", curl_available: command_exists("curl") ? 1 : 0, dig_available: command_exists("dig") ? 1 : 0 };
        let history = connectivity_history_store(result);
        result.history_saved = history.saved;
        result.history_reason = history.reason;
        write_json(result);
        return 0;
    }

    let resources_before = connectivity_resource_snapshot();
    let ipv4_route = trim(command_output_from_args([ "ip", "-4", "route", "show", "default" ])) != "";
    let ipv6_route = trim(command_output_from_args([ "ip", "-6", "route", "show", "default" ])) != "";
    let host = "www.gstatic.com";
    let url = "https://www.gstatic.com/generate_204";
    let ipv4 = connectivity_family_probe("ipv4", ipv4_route, host, url);
    let ipv6 = connectivity_family_probe("ipv6", ipv6_route, host, url);
    let quic = connectivity_quic_probe();
    let user_servers = connectivity_user_servers_probe();

    let result = {
        available: ipv4.available || ipv6.available ? 1 : 0,
        summary: connectivity_summary(ipv4, ipv6, quic),
        target: "gstatic_generate_204",
        ipv4,
        ipv6,
        quic,
        user_servers,
        resources: connectivity_resource_result(resources_before, connectivity_resource_snapshot())
    };
    let history = connectivity_history_store(result);
    result.history_saved = history.saved;
    result.history_reason = history.reason;
    write_json(result);
    return 0;
}

function nft_chain_counter_status(chain) {
    let output = command_output_from_args([ "nft", "list", "chain", "inet", NFT_TABLE_NAME, chain ]);
    let status = words(status_output([ "nft-chain-counter-status" ], output));
    while (length(status) < 2)
        push(status, "0");
    return [ arg_number(status[0]), arg_number(status[1]) ];
}

function nft_table_has_other_mark_rules(family, table_name) {
    let output = command_output_from_args([ "nft", "list", "table", family, table_name ]);
    return status_success([ "stdin-contains", "meta mark set" ], output);
}

function flow_offloading_status() {
    let defaults = uci_core.section_objects("firewall", "defaults");
    let config = length(defaults) > 0 ? object_or_empty(defaults[0]) : {};
    return {
        software: bool_option(config, "flow_offloading", false) ? 1 : 0,
        hardware: bool_option(config, "flow_offloading_hw", false) ? 1 : 0
    };
}

function check_nft_rules() {
    command_status("sh -c " + shell_quote(
        "curl -m 3 -s " + shell_quote("https://" + CHECK_PROXY_IP_DOMAIN + "/check") + " >/dev/null 2>&1 & pid1=$!; " +
        "curl -m 3 -s " + shell_quote("https://" + FAKEIP_TEST_DOMAIN + "/check") + " >/dev/null 2>&1 & pid2=$!; " +
        "wait $pid1 2>/dev/null; wait $pid2 2>/dev/null; sleep 1"
    ));

    let table_exist = 0;
    let rules_mangle_exist = 0;
    let rules_mangle_counters = 0;
    let rules_mangle_output_exist = 0;
    let rules_mangle_output_counters = 0;
    let rules_proxy_exist = 0;
    let rules_proxy_counters = 0;
    let rules_other_mark_exist = 0;
    let flow_offloading = flow_offloading_status();

    if (command_success_from_args([ "nft", "list", "table", "inet", NFT_TABLE_NAME ])) {
        table_exist = 1;
        if (command_success_from_args([ "nft", "list", "chain", "inet", NFT_TABLE_NAME, "mangle" ])) {
            let status = nft_chain_counter_status("mangle");
            rules_mangle_exist = status[0];
            rules_mangle_counters = status[1];
        }
        if (command_success_from_args([ "nft", "list", "chain", "inet", NFT_TABLE_NAME, "mangle_output" ])) {
            let status = nft_chain_counter_status("mangle_output");
            rules_mangle_output_exist = status[0];
            rules_mangle_output_counters = status[1];
        }
        if (command_success_from_args([ "nft", "list", "chain", "inet", NFT_TABLE_NAME, "proxy" ])) {
            let status = nft_chain_counter_status("proxy");
            rules_proxy_exist = status[0];
            rules_proxy_counters = status[1];
        }
    }

    for (let line in split(command_output_from_args([ "nft", "list", "tables" ]), "\n")) {
        let fields = words(line);
        if (length(fields) < 3)
            continue;
        let family = fields[1];
        let table_name = fields[2];
        if (table_name == NFT_TABLE_NAME)
            continue;
        if (nft_table_has_other_mark_rules(family, table_name)) {
            rules_other_mark_exist = 1;
            break;
        }
    }

    write_json({
        table_exist,
        rules_mangle_exist,
        rules_mangle_counters,
        rules_mangle_output_exist,
        rules_mangle_output_counters,
        rules_proxy_exist,
        rules_proxy_counters,
        rules_other_mark_exist,
        flow_offloading_enabled: flow_offloading.software,
        flow_offloading_hw_enabled: flow_offloading.hardware
    });
    return 0;
}

function strip_leading_v(value) {
    value = as_string(value);
    return substr(value, 0, 1) == "v" ? substr(value, 1) : value;
}

function sing_box_standard_ports_listening(netstat_data) {
    return netstat.sing_box_standard_ports_listening(
        netstat_data,
        SB_DNS_INBOUND_ADDRESS,
        SB_TPROXY_INBOUND_PORT,
        SB_TPROXY_INBOUND6_ADDRESS
    );
}

function sing_box_standard_ports_listening_fixture() {
    exit(sing_box_standard_ports_listening(read_stdin()) ? 0 : 1);
}

function tls_public_key_pin_configured(tls) {
    let pins = object_or_empty(tls).certificate_public_key_sha256;
    if (type(pins) == "array")
        return length(pins) > 0;
    return trim(as_string(pins)) != "";
}

function tls_security_summary(config) {
    let insecure = [];
    let unpinned = [];

    for (let outbound in (type(object_or_empty(config).outbounds) == "array" ? config.outbounds : [])) {
        if (type(outbound) != "object" || type(outbound.tls) != "object" || outbound.tls.insecure !== true)
            continue;

        let tag = trim(as_string(outbound.tag));
        if (tag == "")
            tag = trim(as_string(outbound.type));
        if (tag == "")
            tag = "unnamed-outbound";

        push(insecure, tag);
        if (!tls_public_key_pin_configured(outbound.tls))
            push(unpinned, tag);
    }

    return {
        tls_insecure_outbounds: insecure,
        tls_unpinned_insecure_outbounds: unpinned
    };
}

function config_file_private(path) {
    let info = fs.stat(as_string(path));
    return type(info) == "object" && info.uid == 0 && info.gid == 0 && info.mode == 384;
}

function tls_security_summary_fixture() {
    let config = parse_json_or_null(read_stdin());
    if (type(config) != "object")
        return 1;
    write_json(tls_security_summary(config));
    return 0;
}

function check_sing_box() {
    let sing_box_installed = 0;
    let sing_box_version_ok = 0;
    let sing_box_extended = 0;
    let sing_box_service_exist = 0;
    let sing_box_autostart_disabled = 0;
    let sing_box_process_running = 0;
    let sing_box_ports_listening = 0;

    if (command_exists("sing-box")) {
        sing_box_installed = 1;
        let version = strip_leading_v(replace(module_output(SINGBOX_RUNTIME_UC, [ "version" ]), /[\r\n]+$/g, ""));
        if (version != "") {
            if (sing_box_marker_is("extended-compressed") || module_success(SINGBOX_RUNTIME_UC, [ "is-extended", version ]))
                sing_box_extended = 1;
            if (module_success(HELPERS_UC, [ "version-at-least", version, "1.12.4" ]))
                sing_box_version_ok = 1;
        }
        else if (sing_box_marker_is("extended-compressed"))
            sing_box_extended = 1;
    }

    if (file_exists("/etc/init.d/sing-box")) {
        sing_box_service_exist = 1;
        if (!command_success_from_args([ "/etc/init.d/sing-box", "enabled" ]))
            sing_box_autostart_disabled = 1;
    }

    if (sing_box_process_is_running())
        sing_box_process_running = 1;

    if (sing_box_standard_ports_listening(command_output_from_args([ "netstat", "-ln" ])))
        sing_box_ports_listening = 1;

    let tls_security = tls_security_summary(read_json_file(SING_BOX_CONFIG_PATH));

    write_json({
        sing_box_installed,
        sing_box_version_ok,
        sing_box_extended,
        sing_box_service_exist,
        sing_box_autostart_disabled,
        sing_box_process_running,
        sing_box_ports_listening,
        config_file_private: config_file_private(LOGHORIZON_CONFIG) ? 1 : 0,
        tls_insecure_outbounds: tls_security.tls_insecure_outbounds,
        tls_unpinned_insecure_outbounds: tls_security.tls_unpinned_insecure_outbounds
    });
    return 0;
}

function check_fakeip() {
    let fakeip_address = "";
    let fakeip6_address = "";
    for (let line in split(command_output_from_args([
        "dig", "+short", "@" + SB_DNS_INBOUND_ADDRESS, FAKEIP_TEST_DOMAIN, "A", "+timeout=2", "+tries=1"
    ]), "\n")) {
        line = trim(as_string(line));
        if (valid_ipv4(line)) {
            fakeip_address = line;
            break;
        }
    }
    for (let line in split(command_output_from_args([
        "dig", "+short", "@" + SB_DNS_INBOUND_ADDRESS, FAKEIP_TEST_DOMAIN, "AAAA", "+timeout=2", "+tries=1"
    ]), "\n")) {
        line = lc(trim(as_string(line)));
        if (core_ip.valid_ipv6(line)) {
            fakeip6_address = line;
            break;
        }
    }
    write_json({
        fakeip: match(fakeip_address, /^198\.(18|19)\./) != null || match(fakeip6_address, /^fc[0-3][0-9a-f]:/) != null,
        IP: fakeip_address != "" ? fakeip_address : fakeip6_address,
        IPv4: fakeip_address,
        IPv6: fakeip6_address
    });
    return 0;
}

function clash_json_output(args) {
    let result = status_capture([ "stdin-json" ], command_output(command_from_args(args)));
    if (result.output != "")
        print(result.output);
    return result.status;
}

function clash_api_url() {
    let address = replace(module_output(SINGBOX_RUNTIME_UC, [ "service-listen-address" ]), /[\r\n]+$/g, "");
    if (address == "")
        address = "127.0.0.1";
    return address + ":" + SB_CLASH_API_CONTROLLER_PORT;
}

function clash_auth_args() {
    let cfg = settings();
    if (!bool_option(cfg, "enable_yacd_wan_access", false))
        return [];
    return [ "--header", "Authorization: Bearer " + option(cfg, "yacd_secret_key", "") ];
}

function clash_urlencode(value) {
    return replace(status_output([ "url-encode", value ], null), /[\r\n]+$/g, "");
}

function clash_json_error(message) {
    let result = status_capture([ "json-error", message ], null);
    if (result.output != "")
        print(result.output);
    return 1;
}

function clash_proxy_type_map(base_url, auth) {
    let args = [ "curl", "-s" ];
    for (let item in auth) push(args, item);
    push(args, base_url + "/proxies");

    let value = {};
    try {
        value = json(command_output(command_from_args(args)));
    }
    catch (e) {
        return {};
    }

    let result = {};
    for (let tag, proxy in object_or_empty(value.proxies))
        result[tag] = as_string(object_or_empty(proxy).type || "");
    return result;
}

function clash_latency_endpoint(base_url, proxy_tag, proxy_type) {
    proxy_type = as_string(proxy_type);
    if (lc(proxy_type) == "urltest")
        return base_url + "/group/" + clash_urlencode(proxy_tag) + "/delay";
    return base_url + "/proxies/" + clash_urlencode(proxy_tag) + "/delay";
}

function latency_test_url() {
    let value = option(settings(), "latency_test_url", DEFAULT_LATENCY_TEST_URL);
    return value == "" ? DEFAULT_LATENCY_TEST_URL : value;
}

function clash_api(action, arg1, arg2, arg3) {
    let base_url = clash_api_url();
    let test_url = latency_test_url();
    let auth = clash_auth_args();

    if (action == "get_proxies") {
        let args = [ "curl", "-s" ];
        for (let item in auth) push(args, item);
        push(args, base_url + "/proxies");
        return clash_json_output(args);
    }

    if (action == "get_connections") {
        let args = [ "curl", "-s" ];
        for (let item in auth) push(args, item);
        push(args, base_url + "/connections");
        return clash_json_output(args);
    }

    if (action == "get_proxy_latency") {
        if (as_string(arg1) == "")
            return clash_json_error("proxy_tag required");
        let url = as_string(arg3 || "");
        if (url == "")
            url = test_url;
        let args = [ "curl", "-G", "-s", base_url + "/proxies/" + clash_urlencode(arg1) + "/delay" ];
        for (let item in auth) push(args, item);
        push(args, "--data-urlencode");
        push(args, "url=" + url);
        push(args, "--data-urlencode");
        push(args, "timeout=" + as_string(arg2 || "2000"));
        return clash_json_output(args);
    }

    if (action == "get_proxy_latencies") {
        if (as_string(arg1) == "")
            return clash_json_error("proxy_tags_json required");
        let tags = status_capture([ "clash-proxy-tags-lines", arg1 ], null);
        if (tags.status != 0)
            return clash_json_error("proxy_tags_json must be a JSON array of non-empty strings");
        let proxy_tags = [];
        for (let proxy_tag in split(tags.output, "\n")) {
            proxy_tag = as_string(proxy_tag);
            if (proxy_tag != "")
                push(proxy_tags, proxy_tag);
        }

        let count = 0;
        let failed = 0;
        let progress_path = as_string(arg3);
        let total = length(proxy_tags);
        if (progress_path != "")
            module_success(SERVICE_UI_UC, [ "latency-progress-state", progress_path, count, total, failed ]);

        let proxy_types = clash_proxy_type_map(base_url, auth);
        let ordered_proxy_tags = [];
        for (let proxy_tag in proxy_tags)
            if (lc(as_string(proxy_types[proxy_tag])) != "urltest")
                push(ordered_proxy_tags, proxy_tag);
        for (let proxy_tag in proxy_tags)
            if (lc(as_string(proxy_types[proxy_tag])) == "urltest")
                push(ordered_proxy_tags, proxy_tag);

        for (let proxy_tag in ordered_proxy_tags) {
            let args = [ "curl", "-G", "-s", clash_latency_endpoint(base_url, proxy_tag, proxy_types[proxy_tag]) ];
            for (let item in auth) push(args, item);
            push(args, "--data-urlencode");
            push(args, "url=" + test_url);
            push(args, "--data-urlencode");
            push(args, "timeout=" + as_string(arg2 || "5000"));
            if (status_capture([ "stdin-json" ], command_output(command_from_args(args))).status != 0)
                failed++;
            count++;
            if (progress_path != "")
                module_success(SERVICE_UI_UC, [ "latency-progress-state", progress_path, count, total, failed ]);
        }
        let result = status_capture([ "clash-proxy-latencies-result", count, failed ], null);
        if (result.output != "")
            print(result.output);
        return result.status;
    }

    if (action == "get_group_latency") {
        if (as_string(arg1) == "")
            return clash_json_error("group_tag required");
        let args = [ "curl", "-G", "-s", base_url + "/group/" + clash_urlencode(arg1) + "/delay" ];
        for (let item in auth) push(args, item);
        push(args, "--data-urlencode");
        push(args, "url=" + test_url);
        push(args, "--data-urlencode");
        push(args, "timeout=" + as_string(arg2 || "5000"));
        return clash_json_output(args);
    }

    if (action == "set_group_proxy") {
        if (as_string(arg1) == "" || as_string(arg2) == "")
            return clash_json_error("group_tag and proxy_tag required");
        let payload = status_output([ "clash-set-group-proxy-payload", arg2 ], null);
        let args = [ "curl", "-X", "PUT", "-s", "-w", "\n%{http_code}", base_url + "/proxies/" + clash_urlencode(arg1) ];
        for (let item in auth) push(args, item);
        push(args, "--data-raw");
        push(args, payload);
        let result = status_capture([ "clash-set-group-proxy-result", arg1, arg2 ], command_output(command_from_args(args)));
        if (result.output != "")
            print(result.output);
        return result.status;
    }

    if (action == "close_connection") {
        if (as_string(arg1) == "")
            return clash_json_error("connection_id required");
        let args = [ "curl", "-X", "DELETE", "-s", "-w", "\n%{http_code}", base_url + "/connections/" + clash_urlencode(arg1) ];
        for (let item in auth) push(args, item);
        let result = status_capture([ "clash-close-connection-result", arg1 ], command_output(command_from_args(args)));
        if (result.output != "")
            print(result.output);
        return result.status;
    }

    if (action == "close_all_connections") {
        let args = [ "curl", "-X", "DELETE", "-s", "-w", "\n%{http_code}", base_url + "/connections" ];
        for (let item in auth) push(args, item);
        let result = status_capture([ "clash-close-all-connections-result" ], command_output(command_from_args(args)));
        if (result.output != "")
            print(result.output);
        return result.status;
    }

    let unknown = status_capture([ "clash-unknown-action" ], null);
    if (unknown.output != "")
        print(unknown.output);
    return 1;
}

function print_global(message) {
    print(as_string(message), "\n");
}

function render_or_fail(mode_args, input, fail_message, ok_statuses) {
    let result = status_capture(mode_args, input);
    if (result.output != "")
        print(result.output);
    for (let status in ok_statuses)
        if (result.status == status)
            return result.status;
    print_global(fail_message);
    return result.status;
}

function global_check(arg1, arg2) {
    let visibility = as_string(arg2 || "masked");
    if (as_string(arg1) == "raw" || as_string(arg1) == "masked")
        visibility = as_string(arg1);

    print_global("📡 Global check run!");
    print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print_global("🛠️ System info");

    let system_info_json = sprintf("%J", build_system_info());
    render_or_fail([ "global-system-info" ], system_info_json, "❌ Failed to parse system info", [ 0 ]);

    print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print_global("➡️ DNS status");

    let dns_check_capture = command_capture(command_from_args(module_args(LIB_DIR + "/diagnostics/runtime.uc", [ "check-dns-available" ])));
    if (dns_check_capture.output != "") {
        let dns_render = render_or_fail(
            [ "global-dns-check", bool_option(settings(), "dont_touch_dhcp", false) ? "1" : "0" ],
            dns_check_capture.output,
            "❌ Failed to parse DNS info",
            [ 0, 10 ]
        );
        if (dns_render == 10)
            print(status_output([ "dhcp-dnsmasq-config", "/etc/config/dhcp" ], null));
    }
    else
        print_global("❌ Failed to get DNS info");

    print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print_global("📦 Sing-box status");
    let singbox_check_json = command_capture(command_from_args(module_args(LIB_DIR + "/diagnostics/runtime.uc", [ "check-sing-box" ]))).output;
    if (singbox_check_json != "")
        render_or_fail([ "global-sing-box-check" ], singbox_check_json, "❌ Failed to parse sing-box info", [ 0 ]);
    else
        print_global("❌ Failed to get sing-box info");

    print_global("---------------------------");
    print_global("Inbounds checks");
    let inbounds_check_json = command_capture(command_from_args(module_args(LIB_DIR + "/diagnostics/runtime.uc", [ "check-inbounds" ]))).output;
    if (inbounds_check_json != "")
        render_or_fail([ "global-inbounds-check" ], inbounds_check_json, "[FAIL] Failed to parse inbounds check details", [ 0 ]);
    else
        print_global("[FAIL] Failed to get inbounds info");

    print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print_global("🧱 NFT rules status");
    let nft_check_json = command_capture(command_from_args(module_args(LIB_DIR + "/diagnostics/runtime.uc", [ "check-nft-rules" ]))).output;
    if (nft_check_json != "") {
        let nft_render = render_or_fail([ "global-nft-check" ], nft_check_json, "❌ Failed to parse NFT rules info", [ 0 ]);
        if (nft_render == 0 && status_success([ "global-nft-other-mark-exists" ], nft_check_json))
            print(status_output([ "nft-ruleset-other-mark-lines", NFT_TABLE_NAME ], command_output_from_args([ "nft", "list", "ruleset" ])));
        let nft_info = object_or_empty(parse_json_or_null(nft_check_json));
        if (arg_bool(nft_info.flow_offloading_enabled))
            print_global("⚠️ Software flow offloading is enabled. Established flows may bypass packet inspection.");
        if (arg_bool(nft_info.flow_offloading_hw_enabled))
            print_global("⚠️ Hardware flow offloading is enabled. DPI traffic may bypass NFQUEUE entirely.");
    }
    else
        print_global("❌ Failed to get NFT rules info");

    print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print_global("📄 logIn config");
    show_config(visibility);

    print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print_global("📄 WAN config");
    if (uci_show("network.wan")) {
        if (visibility == "raw")
            print(as_string(fs.readfile("/etc/config/network")));
        else
            print(status_output([ "wan-config-masked", "/etc/config/network" ], null));
    }
    else
        print_global("❌ WAN configuration not found");

    let network_show = network_show_data();
    for (let line in split(status_output([ "network-endpoint-host-warnings", CLOUDFLARE_OCTETS ], network_show), "\n")) {
        if (line == "")
            continue;
        let fields = split(line, "\t");
        if (length(fields) < 2)
            continue;
        if (fields[0] == "engage")
            print_global("⚠️ WARP detected: " + fields[1]);
        else if (fields[0] == "prefix") {
            print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            print_global("⚠️ WARP detected: " + fields[1]);
        }
    }

    for (let peer_section in split(status_output([ "network-wireguard-route-allowed-peers" ], network_show), "\n")) {
        peer_section = as_string(peer_section);
        if (peer_section == "")
            continue;
        let default_routes = allowed_ips_default_routes(uci_get(peer_section + ".allowed_ips"));
        if (length(default_routes) > 0) {
            print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            print_global("⚠️ WG Route allowed IP enabled with " + join(", ", default_routes));
        }
    }

    if (file_executable("/etc/init.d/zapret") && command_success_from_args([ "/etc/init.d/zapret", "status" ])) {
        print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        print_global("⚠️ Standalone zapret service is active. logIn uses separate queues, but packet-level policy overlap is possible.");
    }
    else if (file_executable("/etc/init.d/zapret") && command_success_from_args([ "/etc/init.d/zapret", "enabled" ])) {
        print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        print_global("⚠️ Standalone zapret autostart is enabled. logIn will not modify /etc/config/zapret.");
    }

    if (file_executable("/etc/init.d/zapret2") && command_success_from_args([ "/etc/init.d/zapret2", "status" ])) {
        print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        print_global("⚠️ Standalone zapret2 service is active. logIn uses separate queues, but packet-level policy overlap is possible.");
    }
    else if (file_executable("/etc/init.d/zapret2") && command_success_from_args([ "/etc/init.d/zapret2", "enabled" ])) {
        print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
        print_global("⚠️ Standalone zapret2 autostart is enabled. logIn will not modify /etc/config/zapret2.");
    }

    print_global("━━━━━━━━━━━━━━━━━━━━━━━━━━━");
    print_global("🥸 FakeIP status");
    let fakeip_check_json = command_capture(command_from_args(module_args(LIB_DIR + "/diagnostics/runtime.uc", [ "check-fakeip" ]))).output;
    if (fakeip_check_json != "")
        render_or_fail([ "global-fakeip-check" ], fakeip_check_json, "❌ Failed to parse FakeIP info", [ 0 ]);
    else
        print_global("❌ Failed to get FakeIP info");

    return 0;
}

let mode = ARGV[0] || "";

if (mode == "check-proxy")
    exit(check_proxy());
else if (mode == "check-nft")
    exit(check_nft());
else if (mode == "check-nft-rules")
    exit(check_nft_rules());
else if (mode == "flow-offloading-fixture")
    write_json(flow_offloading_status());
else if (mode == "check-sing-box")
    exit(check_sing_box());
else if (mode == "sing-box-standard-ports-listening-fixture")
    sing_box_standard_ports_listening_fixture();
else if (mode == "tls-security-summary-fixture")
    exit(tls_security_summary_fixture());
else if (mode == "config-file-private")
    exit(config_file_private(ARGV[1]) ? 0 : 1);
else if (mode == "check-inbounds-config")
    exit(check_inbounds_config());
else if (mode == "check-inbounds")
    exit(check_inbounds());
else if (mode == "check-logs")
    exit(check_logs());
else if (mode == "check-sing-box-logs")
    exit(check_sing_box_logs());
else if (mode == "loghorizon-logs-fixture")
    exit(loghorizon_logs_fixture());
else if (mode == "check-fakeip")
    exit(check_fakeip());
else if (mode == "check-zapret-runtime")
    exit(module_passthrough(ZAPRET_RUNTIME_UC, [ "check" ]));
else if (mode == "check-zapret2-runtime")
    exit(module_passthrough(ZAPRET2_RUNTIME_UC, [ "check" ]));
else if (mode == "check-byedpi-runtime")
    exit(module_passthrough(BYEDPI_RUNTIME_UC, [ "check" ]));
else if (mode == "neutralize-zapret-defaults")
    exit(neutralize_zapret_defaults());
else if (mode == "clash-api")
    exit(clash_api(ARGV[1], ARGV[2], ARGV[3], ARGV[4]));
else if (mode == "show-config")
    exit(show_config(ARGV[1] || "masked"));
else if (mode == "show-version")
    exit(show_version());
else if (mode == "show-sing-box-config")
    exit(show_sing_box_config(ARGV[1] || "masked"));
else if (mode == "show-sing-box-version")
    exit(show_sing_box_version());
else if (mode == "get-status")
    exit(get_status());
else if (mode == "get-outbound-metadata")
    exit(get_outbound_metadata(ARGV[1]));
else if (mode == "get-subscription-metadata")
    exit(get_subscription_metadata(ARGV[1]));
else if (mode == "get-sing-box-status")
    exit(get_sing_box_status());
else if (mode == "get-zapret-status")
    exit(module_passthrough(ZAPRET_RUNTIME_UC, [ "status" ]));
else if (mode == "get-zapret2-status")
    exit(module_passthrough(ZAPRET2_RUNTIME_UC, [ "status" ]));
else if (mode == "get-byedpi-status")
    exit(module_passthrough(BYEDPI_RUNTIME_UC, [ "status" ]));
else if (mode == "get-system-info")
    exit(get_system_info());
else if (mode == "get-server-capabilities")
    exit(get_server_capabilities());
else if (mode == "check-dns-available")
    exit(check_dns_available());
else if (mode == "check-connectivity-path")
    exit(check_connectivity_path());
else if (mode == "connectivity-probe-classify-fixture")
    exit(connectivity_probe_classify_fixture());
else if (mode == "connectivity-doq-classify-fixture")
    exit(connectivity_doq_classify_fixture());
else if (mode == "connectivity-resource-fixture")
    exit(connectivity_resource_fixture());
else if (mode == "connectivity-user-server-selection-fixture")
    exit(connectivity_user_server_selection_fixture());
else if (mode == "connectivity-user-server-classify-fixture")
    exit(connectivity_user_server_classify_fixture());
else if (mode == "connectivity-history-entry-fixture")
    exit(connectivity_history_entry_fixture());
else if (mode == "connectivity-history-updated-fixture")
    exit(connectivity_history_updated_fixture());
else if (mode == "get-connectivity-history")
    exit(connectivity_history_get());
else if (mode == "global-check")
    exit(global_check(ARGV[1] || "", ARGV[2] || ""));
else if (mode == "validate-nfqws-strategy-json")
    exit(validate_nfqws_strategy_json(ARGV[1] || ""));
else if (mode == "validate-nfqws2-strategy-json")
    exit(validate_nfqws2_strategy_json(ARGV[1] || ""));
else {
    warn("Usage: diagnostics/runtime.uc <operation> ...\n");
    exit(1);
}
