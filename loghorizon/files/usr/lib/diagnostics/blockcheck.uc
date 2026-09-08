#!/usr/bin/env ucode

let fs = require("fs");
let uci = require("core.uci");

const CONFIG_NAME = getenv("LOGHORIZON_CONFIG_NAME") || "loghorizon";
const SERVICE_INIT = getenv("LOGHORIZON_BLOCKCHECK_SERVICE_INIT") || "/etc/init.d/loghorizon";
const CURL_BIN = getenv("LOGHORIZON_BLOCKCHECK_CURL_BIN") || "curl";
const PGREP_BIN = getenv("LOGHORIZON_BLOCKCHECK_PGREP_BIN") || "pgrep";
const SLEEP_BIN = getenv("LOGHORIZON_BLOCKCHECK_SLEEP_BIN") || "sleep";
const LOGHORIZON_BIN = getenv("LOGHORIZON_BLOCKCHECK_LOGHORIZON_BIN") || "/usr/bin/loghorizon";
const LOCK_DIR = getenv("LOGHORIZON_BLOCKCHECK_LOCK_DIR") || "/var/run/loghorizon-blockcheck.lock";
const RECOVERY_FILE = getenv("LOGHORIZON_BLOCKCHECK_RECOVERY_FILE") ||
    "/var/run/loghorizon-blockcheck-recovery.json";
const WATCHDOG_ENABLED = getenv("LOGHORIZON_BLOCKCHECK_WATCHDOG_ENABLED") != "0";
const DEFAULT_CONTROL_URL = getenv("LOGHORIZON_BLOCKCHECK_CONTROL_URL") ||
    "https://connectivitycheck.gstatic.com/generate_204";

function as_string(value) {
    return value == null ? "" : "" + value;
}

function shell_quote(value) {
    return "'" + replace(as_string(value), /'/g, "'\\''") + "'";
}

function command_from_args(args) {
    let result = [];
    for (let arg in args)
        push(result, shell_quote(arg));
    return join(" ", result);
}

function command_status(args, quiet) {
    let command = command_from_args(args);
    if (quiet)
        command += " >/dev/null 2>&1";
    let status = int(system(command));
    return status > 255 ? int(status / 256) : status;
}

function command_output(args) {
    let pipe = fs.popen(command_from_args(args), "r");
    if (!pipe)
        return null;
    let output = pipe.read("all");
    let status = pipe.close();
    return status == 0 && output != null ? as_string(output) : null;
}

function fail(message) {
    die({ blockcheck_error: as_string(message) });
}

function error_message(error) {
    if (type(error) == "object" && error.blockcheck_error != null)
        return as_string(error.blockcheck_error);
    return as_string(error);
}

function uint_value(value, label, minimum, maximum) {
    value = as_string(value);
    if (value == "" || match(value, /[^0-9]/) != null)
        fail(label + " must be an integer");
    let result = int(value);
    if (result < minimum || result > maximum)
        fail(label + " must be between " + minimum + " and " + maximum);
    return result;
}

function usage() {
    print("Usage: loghorizon blockcheck -s <section> -f <file> [-t hosts] [-n count]\n");
    print("  -s  DPI section name\n");
    print("  -f  TAB-separated file: name, strategy\n");
    print("  -t  comma-separated HTTPS hosts\n");
    print("  -n  requests per host (minimum 8)\n");
    print("  -w  settle time after restart (minimum 20 seconds)\n");
    print("  -c  neutral connectivity-check URL\n");
}

function parse_args(args) {
    let options = {
        section: "",
        file: "",
        hosts: "www.youtube.com",
        count: 8,
        settle: 22,
        control_url: DEFAULT_CONTROL_URL,
        help: false
    };

    let i = 0;
    while (i < length(args)) {
        let arg = as_string(args[i]);
        i = i + 1;
        if (arg == "-h" || arg == "--help") {
            options.help = true;
            continue;
        }
        if (arg != "-s" && arg != "-f" && arg != "-t" && arg != "-n" && arg != "-w" && arg != "-c")
            fail("unknown argument: " + arg);
        if (i >= length(args))
            fail(arg + " requires a value");
        let value = as_string(args[i]);
        i = i + 1;
        if (arg == "-s") options.section = value;
        else if (arg == "-f") options.file = value;
        else if (arg == "-t") options.hosts = value;
        else if (arg == "-n") options.count = uint_value(value, "request count", 8, 30);
        else if (arg == "-w") options.settle = uint_value(value, "settle time", 20, 120);
        else if (arg == "-c") options.control_url = value;
    }

    if (options.help)
        return options;
    if (options.section == "" || match(options.section, /[^A-Za-z0-9_-]/) != null)
        fail("a valid section is required");
    if (options.file == "" || fs.readfile(options.file) == null)
        fail("a readable strategy file is required");
    if (options.hosts == "")
        fail("at least one test host is required");
    if (substr(options.control_url, 0, 8) != "https://")
        fail("connectivity-check URL must use HTTPS");
    return options;
}

function engine_plan(section) {
    let action = as_string(uci.get(CONFIG_NAME + "." + section + ".action"));
    if (action == "zapret")
        return { action, option: "nfqws_opt", process: "nfqws", status_command: "get_zapret_status", queue_proof: true };
    if (action == "zapret2")
        return { action, option: "nfqws2_opt", process: "nfqws2", status_command: "get_zapret2_status", queue_proof: true };
    if (action == "byedpi")
        return { action, option: "byedpi_cmd_opts", process: "ciadpi", status_command: "get_byedpi_status", queue_proof: false };
    if (action == "")
        fail("section " + section + " does not exist");
    fail("section " + section + " does not use a DPI engine");
}

function acquire_lock() {
    if (command_status([ "mkdir", LOCK_DIR ], true) != 0)
        fail("another BlockCheck is already running");
}

function release_lock() {
    return command_status([ "rmdir", LOCK_DIR ], true) == 0;
}

function read_json_file(path) {
    let data = fs.readfile(path);
    if (data == null)
        return null;
    try { return json(as_string(data)); } catch (error) { return null; }
}

function write_recovery_journal(state) {
    let temporary = RECOVERY_FILE + ".tmp";
    let value = {
        version: 1,
        config: CONFIG_NAME,
        section: state.section,
        option: state.option,
        original: state.original,
        original_present: state.original_present
    };
    if (fs.writefile(temporary, sprintf("%J\n", value)) == null)
        return false;
    if (command_status([ "chmod", "0600", temporary ], true) != 0 ||
        !fs.rename(temporary, RECOVERY_FILE)) {
        fs.unlink(temporary);
        return false;
    }
    return true;
}

function clear_recovery_journal() {
    if (fs.stat(RECOVERY_FILE) != null)
        fs.unlink(RECOVERY_FILE);
    return fs.stat(RECOVERY_FILE) == null;
}

function start_recovery_watchdog() {
    if (!WATCHDOG_ENABLED)
        return true;
    let body = "parent=$PPID; while kill -0 \"$parent\" >/dev/null 2>&1; do " +
        shell_quote(SLEEP_BIN) + " 2; done; [ ! -f " + shell_quote(RECOVERY_FILE) +
        " ] || " + shell_quote(LOGHORIZON_BIN) + " blockcheck --recover";
    return command_status([ "sh", "-c", "(" + body + ") >/dev/null 2>&1 &" ], true) == 0;
}

function valid_recovery_state(value) {
    if (type(value) != "object" || int(value.version || 0) != 1 ||
        as_string(value.config) != CONFIG_NAME ||
        match(as_string(value.section), /[^A-Za-z0-9_-]/) != null)
        return false;
    return value.option == "nfqws_opt" || value.option == "nfqws2_opt" ||
        value.option == "byedpi_cmd_opts";
}

function set_strategy(section, option, value, present) {
    let path = CONFIG_NAME + "." + section + "." + option;
    let changed = present ? uci.set(path, value) : uci.delete(path);
    if (!changed && present)
        return false;
    return uci.commit(CONFIG_NAME);
}

function restart_service() {
    return command_status([ SERVICE_INIT, "restart" ], true) == 0;
}

function restore_original(state) {
    if (!state.restore_needed)
        return true;
    if (!set_strategy(state.section, state.option, state.original, state.original_present))
        return false;
    if (!restart_service())
        return false;
    state.restore_needed = false;
    return clear_recovery_journal();
}

function recover_stale_test() {
    let value = read_json_file(RECOVERY_FILE);
    if (!valid_recovery_state(value)) {
        warn("BlockCheck: recovery journal is missing or invalid\n");
        return 1;
    }
    let state = {
        section: as_string(value.section),
        option: as_string(value.option),
        original: as_string(value.original),
        original_present: value.original_present === true,
        restore_needed: true
    };
    if (!restore_original(state)) {
        warn("BlockCheck: CRITICAL: failed to restore the strategy from the recovery journal\n");
        return 1;
    }
    command_status([ "rmdir", LOCK_DIR ], true);
    print("BlockCheck: stale test strategy restored successfully\n");
    return 0;
}

function connectivity_ok(url) {
    for (let attempt = 0; attempt < 2; attempt++)
        if (command_status([ CURL_BIN, "-sS", "--fail", "-o", "/dev/null",
                "--connect-timeout", "4", "--max-time", "8", url ], true) == 0)
            return true;
    return false;
}

function valid_host(host) {
    return host != "" && match(host, /[^A-Za-z0-9.-]/) == null;
}

function probe_host(host, count) {
    let ok = 0;
    let total_ms = 0;
    for (let attempt = 0; attempt < count; attempt++) {
        let output = command_output([ CURL_BIN, "-s", "--fail", "-o", "/dev/null",
            "--connect-timeout", "3", "--max-time", "6", "-w", "%{time_total}",
            "https://" + host + "/" ]);
        if (output == null)
            continue;
        let seconds = +trim(output);
        if (seconds < 0)
            continue;
        total_ms += int(seconds * 1000);
        ok++;
    }
    return {
        ok,
        count,
        average_ms: ok > 0 ? int(total_ms / ok) : null
    };
}

function route_path_ok(section, host) {
    let output = command_output([ LOGHORIZON_BIN, "check_rule_path", section, host ]);
    if (output == null)
        return false;
    let value = null;
    try { value = json(output); } catch (error) { return false; }
    return type(value) == "object" && value.success === true;
}

function provider_status(plan) {
    let output = command_output([ LOGHORIZON_BIN, plan.status_command ]);
    if (output == null)
        return null;
    try { return json(output); } catch (error) { return null; }
}

function selected_queue_packets(plan, section) {
    let status = provider_status(plan);
    if (type(status) != "object" || status.ready !== true)
        return null;
    if (!plan.queue_proof)
        return -1;
    for (let counter in (status.queue_counters || []))
        if (as_string(counter.section) == section && counter.rule_present === true)
            return int(counter.total_packets || 0);
    return null;
}

function strategy_rows(path) {
    let rows = [];
    for (let line in split(as_string(fs.readfile(path)), "\n")) {
        line = replace(line, /\r$/, "");
        if (line == "" || substr(line, 0, 1) == "#")
            continue;
        let tab = index(line, "\t");
        if (tab < 1) {
            push(rows, { name: line, strategy: "" });
            continue;
        }
        push(rows, { name: substr(line, 0, tab), strategy: substr(line, tab + 1) });
    }
    return rows;
}

function run_tests(options, plan, state) {
    print("BlockCheck: section=", options.section, " engine=", plan.action,
        " requests=", options.count, " settle=", options.settle, "s hosts=", options.hosts, "\n");

    for (let row in strategy_rows(options.file)) {
        if (row.strategy == "") {
            printf("%-30s rejected: empty strategy\n", row.name);
            continue;
        }
        if (!write_recovery_journal(state))
            fail("failed to persist the recovery journal before changing the strategy");
        state.restore_needed = true;
        if (!state.watchdog_started) {
            if (!start_recovery_watchdog())
                fail("failed to start the strategy recovery watchdog");
            state.watchdog_started = true;
        }
        if (!set_strategy(state.section, state.option, row.strategy, true))
            fail("failed to save candidate " + row.name);
        if (!restart_service()) {
            printf("%-30s rejected: service refused to restart\n", row.name);
            if (!restore_original(state)) fail("failed to restore after rejected strategy");
            continue;
        }
        if (command_status([ SLEEP_BIN, "" + options.settle ], true) != 0)
            fail("settle wait failed");
        // BusyBox pgrep -x matches the complete command line on some OpenWrt
        // builds, so a process with arguments is missed despite an exact comm.
        if (command_status([ PGREP_BIN, "^" + plan.process + "$" ], true) != 0) {
            printf("%-30s rejected: engine did not start\n", row.name);
            if (!restore_original(state)) fail("failed to restore after engine failure");
            continue;
        }
        if (!connectivity_ok(options.control_url)) {
            printf("%-30s rolled back: external connectivity was lost\n", row.name);
            if (!restore_original(state)) fail("failed to restore after connectivity loss");
            continue;
        }

        let before_packets = selected_queue_packets(plan, options.section);
        if (before_packets == null) {
            printf("%-30s rejected: selected engine section is not ready\n", row.name);
            if (!restore_original(state)) fail("failed to restore after provider status failure");
            continue;
        }

        let line = sprintf("%-30s", row.name);
        let probes_ok = true;
        for (let host in split(options.hosts, ",")) {
            host = trim(host);
            if (!valid_host(host)) fail("invalid test host: " + host);
            if (!route_path_ok(options.section, host)) {
                line += " " + host + "=route-mismatch";
                probes_ok = false;
                continue;
            }
            let probe = probe_host(host, options.count);
            line += " " + host + "=http:" + probe.ok + "/" + probe.count +
                " http_avg=" + (probe.average_ms == null ? "n/a" : probe.average_ms + "ms");
            if (probe.ok == 0)
                probes_ok = false;
        }
        let after_packets = selected_queue_packets(plan, options.section);
        if (plan.queue_proof) {
            let delta = after_packets == null ? 0 : after_packets - before_packets;
            line += delta > 0 && probes_ok
                ? " verified:nfqueue+" + delta
                : " unverified:selected-nfqueue+" + delta;
        }
        else {
            line += probes_ok
                ? " route-only:no-per-section-packet-counter"
                : " unverified:no-per-section-packet-counter";
        }
        print(line, "\n");
    }
}

function main(args) {
    if (length(args) == 1 && as_string(args[0]) == "--recover")
        return recover_stale_test();

    let options = parse_args(args);
    if (options.help) {
        usage();
        return 0;
    }

    let plan = engine_plan(options.section);
    let original_value = uci.get(CONFIG_NAME + "." + options.section + "." + plan.option);
    let state = {
        section: options.section,
        option: plan.option,
        original: as_string(original_value),
        original_present: original_value != null,
        restore_needed: false,
        watchdog_started: false
    };
    let failure = "";
    let locked = false;

    try {
        acquire_lock();
        locked = true;
        run_tests(options, plan, state);
    }
    catch (error) {
        failure = error_message(error);
    }

    if (!restore_original(state))
        failure = "CRITICAL: failed to restore the original strategy";
    if (locked && !release_lock())
        failure = failure != "" ? failure + "; failed to release test lock" : "failed to release test lock";
    if (failure != "") {
        warn("BlockCheck: ", failure, "\n");
        return 1;
    }

    print("BlockCheck: original strategy restored successfully\n");
    return 0;
}

exit(main(slice(ARGV, 1)));
