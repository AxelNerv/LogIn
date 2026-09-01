#!/usr/bin/env ucode

let fs = require("fs");
let uci = require("core.uci");

const CONFIG_NAME = getenv("LOGHORIZON_CONFIG_NAME") || "loghorizon";
const SERVICE_INIT = getenv("LOGHORIZON_BLOCKCHECK_SERVICE_INIT") || "/etc/init.d/loghorizon";
const CURL_BIN = getenv("LOGHORIZON_BLOCKCHECK_CURL_BIN") || "curl";
const PGREP_BIN = getenv("LOGHORIZON_BLOCKCHECK_PGREP_BIN") || "pgrep";
const SLEEP_BIN = getenv("LOGHORIZON_BLOCKCHECK_SLEEP_BIN") || "sleep";
const LOCK_DIR = getenv("LOGHORIZON_BLOCKCHECK_LOCK_DIR") || "/var/run/loghorizon-blockcheck.lock";
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
        hosts: "discord.com,www.youtube.com",
        count: 8,
        settle: 22,
        control_url: DEFAULT_CONTROL_URL,
        help: false
    };

    for (let i = 0; i < length(args); i++) {
        let arg = as_string(args[i]);
        if (arg == "-h" || arg == "--help") {
            options.help = true;
            continue;
        }
        if (arg != "-s" && arg != "-f" && arg != "-t" && arg != "-n" && arg != "-w" && arg != "-c")
            fail("unknown argument: " + arg);
        if (++i >= length(args))
            fail(arg + " requires a value");
        let value = as_string(args[i]);
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
        return { action, option: "nfqws_opt", process: "nfqws" };
    if (action == "zapret2")
        return { action, option: "nfqws2_opt", process: "nfqws2" };
    if (action == "byedpi")
        return { action, option: "byedpi_cmd_opts", process: "ciadpi" };
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
    return true;
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
        let output = command_output([ CURL_BIN, "-sS", "--fail", "-o", "/dev/null",
            "--connect-timeout", "3", "--max-time", "6", "-w", "%{time_total}",
            "https://" + host + "/favicon.ico" ]);
        if (output == null)
            continue;
        let seconds = +trim(output);
        if (seconds < 0)
            continue;
        total_ms += int(seconds * 1000);
        ok++;
    }
    return ok > 0
        ? ok + "/" + count + " avg=" + int(total_ms / ok) + "ms"
        : "0/" + count + " avg=n/a";
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
        state.restore_needed = true;
        if (!set_strategy(state.section, state.option, row.strategy, true))
            fail("failed to save candidate " + row.name);
        if (!restart_service()) {
            printf("%-30s rejected: service refused to restart\n", row.name);
            if (!restore_original(state)) fail("failed to restore after rejected strategy");
            continue;
        }
        if (command_status([ SLEEP_BIN, "" + options.settle ], true) != 0)
            fail("settle wait failed");
        if (command_status([ PGREP_BIN, "-x", plan.process ], true) != 0) {
            printf("%-30s rejected: engine did not start\n", row.name);
            if (!restore_original(state)) fail("failed to restore after engine failure");
            continue;
        }
        if (!connectivity_ok(options.control_url)) {
            printf("%-30s rolled back: external connectivity was lost\n", row.name);
            if (!restore_original(state)) fail("failed to restore after connectivity loss");
            continue;
        }

        let line = sprintf("%-30s", row.name);
        for (let host in split(options.hosts, ",")) {
            host = trim(host);
            if (!valid_host(host)) fail("invalid test host: " + host);
            line += " " + host + "=" + probe_host(host, options.count);
        }
        print(line, "\n");
    }
}

function main(args) {
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
        restore_needed: false
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
