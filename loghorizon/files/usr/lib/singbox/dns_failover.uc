#!/usr/bin/env ucode

let fs = require("fs");
let uci_core = require("core.uci");
let common = require("core.common");
let core_ip = require("core.ip");
let runtime_dns = require("singbox.dns");

const CONFIG_NAME = getenv("LOGHORIZON_CONFIG_NAME") || "loghorizon";
const LIB_DIR = getenv("LOGHORIZON_LIB") || "/usr/lib/loghorizon";
const RUNTIME_STATE_DIR = getenv("LOGHORIZON_RUNTIME_STATE_DIR") || "/var/run/loghorizon";
const STATE_FILE = getenv("LOGHORIZON_DNS_FAILOVER_STATE_FILE") || RUNTIME_STATE_DIR + "/dns-failover.json";
const PID_FILE = getenv("LOGHORIZON_DNS_FAILOVER_PID_FILE") || RUNTIME_STATE_DIR + "/dns-failover.pid";
const DNS_FAILOVER_UC = getenv("LOGHORIZON_DNS_FAILOVER_UC") || LIB_DIR + "/singbox/dns_failover.uc";
const SERVICE_BIN = getenv("LOGHORIZON_BIN") || "/usr/bin/loghorizon";
const CHECK_DOMAIN = "example.com";

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

function command_status(command) {
    let status = int(system(command));
    return status > 255 ? int(status / 256) : status;
}

function command_success_from_args(args) {
    return command_status(command_from_args(args) + " >/dev/null 2>&1") == 0;
}

function command_output_from_args(args) {
    let pipe = fs.popen(command_from_args(args), "r");
    if (!pipe)
        return "";
    let data = pipe.read("all");
    let status = pipe.close();
    return status == 0 && data != null ? as_string(data) : "";
}

function settings() {
    return common.object_or_empty(uci_core.get_all(CONFIG_NAME, "settings"));
}

function ensure_dir(path) {
    return command_success_from_args([ "mkdir", "-p", path ]);
}

function remove_file(path) {
    try {
        fs.unlink(as_string(path));
    }
    catch (e) {
    }
}

function write_state(path, value) {
    if (!ensure_dir(RUNTIME_STATE_DIR))
        return false;
    let stamp = clock();
    let temporary = as_string(path) + ".tmp." + as_string(stamp[0]) + "." + as_string(stamp[1]);
    if (!common.write_json_file(temporary, value))
        return false;
    if (!fs.rename(temporary, path)) {
        remove_file(temporary);
        return false;
    }
    return true;
}

function log_message(message, level) {
    command_success_from_args([ "logger", "-t", "loghorizon", "[" + as_string(level || "info") + "] DNS failover: " + as_string(message) ]);
}

function duration_milliseconds(value, fallback) {
    let rest = as_string(value);
    let total = 0.0;
    let units = { ns: 0.000001, us: 0.001, ms: 1, s: 1000, m: 60000, h: 3600000, d: 86400000 };
    while (rest != "") {
        let matched = match(rest, /^([0-9]+(\.[0-9]+)?)(ns|us|ms|s|m|h|d)/);
        if (!matched)
            return fallback;
        total += (matched[1] * 1) * units[matched[3]];
        rest = substr(rest, length(matched[0]));
    }
    return total > 0 ? int(total + 0.5) : fallback;
}

function duration_seconds(value, fallback) {
    let milliseconds = duration_milliseconds(value, fallback * 1000);
    return int((milliseconds + 999) / 1000);
}

function probe_timeout(settings_value) {
    return duration_seconds(settings_value, 2);
}

function probe_port(kind, index_value, timeout_seconds) {
    let args = [
        "dig", "-p", as_string(runtime_dns.health_port(kind, index_value)),
        "@" + runtime_dns.DNS_HEALTH_ADDRESS,
        CHECK_DOMAIN, "A", "+short",
        "+timeout=" + as_string(timeout_seconds), "+tries=1"
    ];
    for (let line in split(command_output_from_args(args), "\n"))
        if (core_ip.valid_ipv4(trim(as_string(line))))
            return true;
    return false;
}

function probe_canonical_main(timeout_seconds) {
    let args = [
        "dig", "-p", as_string(runtime_dns.health_port("active", 0)),
        "@" + runtime_dns.DNS_HEALTH_ADDRESS, CHECK_DOMAIN, "A", "+short",
        "+timeout=" + as_string(timeout_seconds), "+tries=1"
    ];
    for (let line in split(command_output_from_args(args), "\n"))
        if (core_ip.valid_ipv4(trim(as_string(line))))
            return true;
    return false;
}

function verification_plan(previous, candidate) {
    previous = common.object_or_empty(previous);
    candidate = common.object_or_empty(candidate);
    return {
        main: int(candidate.main_index || 0) != int(previous.main_index || 0),
        bootstrap: int(candidate.bootstrap_index || 0) != int(previous.bootstrap_index || 0) &&
            length(candidate.bootstrap_servers || []) > 1
    };
}

function verify_state(path) {
    let cfg = settings();
    let state = common.read_json_file(path);
    let expected = runtime_dns.state_template(cfg);
    if (!runtime_dns.state_matches(expected, state))
        return false;

    state = runtime_dns.normalize_state(cfg, state);
    let previous = runtime_dns.normalize_state(cfg, common.read_json_file(STATE_FILE));
    let plan = verification_plan(previous, state);
    let timeout_seconds = probe_timeout(common.option(cfg, "dns_check_timeout", "2s"));
    if (plan.main && !probe_canonical_main(timeout_seconds))
        return false;
    if (plan.bootstrap && !probe_port("bootstrap", state.bootstrap_index, timeout_seconds))
        return false;
    return true;
}

function commit_state(path) {
    let cfg = settings();
    let state = common.read_json_file(path);
    if (!runtime_dns.state_matches(runtime_dns.state_template(cfg), state))
        return false;
    return fs.rename(path, STATE_FILE);
}

function now_seconds() {
    return int(clock()[0]);
}

function bounded_positive_int(value, fallback, maximum) {
    let parsed = int(value || fallback, 10);
    if (parsed < 1)
        return fallback;
    if (parsed > maximum)
        return maximum;
    return parsed;
}

function reset_confirmation(tracker, recovery) {
    let prefix = recovery ? "recovery" : "failure";
    tracker[prefix + "Candidate"] = -1;
    tracker[prefix + "Count"] = 0;
}

function confirmation_tracker(now) {
    return {
        failureCandidate: -1,
        failureCount: 0,
        recoveryCandidate: -1,
        recoveryCount: 0,
        lastSwitchAt: int(now || 0)
    };
}

function confirmed_selection(current_index, selected, tracker, recovery, threshold) {
    selected = common.object_or_empty(selected);
    let prefix = recovery ? "recovery" : "failure";

    if (!selected.alive || int(selected.index) == int(current_index)) {
        reset_confirmation(tracker, recovery);
        return selected;
    }

    let candidate_key = prefix + "Candidate";
    let count_key = prefix + "Count";
    if (int(tracker[candidate_key]) == int(selected.index))
        tracker[count_key]++;
    else {
        tracker[candidate_key] = int(selected.index);
        tracker[count_key] = 1;
    }

    if (tracker[count_key] >= threshold)
        return selected;

    return {
        index: int(current_index),
        reason: "pending_" + as_string(selected.reason),
        alive: true,
        pending: true,
        candidate_index: int(selected.index),
        confirmation_count: tracker[count_key]
    };
}

function recovery_allowed(tracker, now, minimum_hold_seconds) {
    return int(now) - int(tracker.lastSwitchAt || 0) >= int(minimum_hold_seconds);
}

function choose_index(kind, state, current_index, timeout_seconds, recovery, probe) {
    let values = kind == "main" ? state.main_servers : state.bootstrap_servers;
    if (length(values) <= 1)
        return { index: 0, reason: "single", alive: true };

    probe = probe || function(index_value) {
        return probe_port(kind, index_value, timeout_seconds);
    };

    if (recovery && current_index > 0) {
        for (let i = 0; i < current_index; i++)
            if (probe(i))
                return { index: i, reason: "recovery", alive: true };
        return { index: current_index, reason: "unchanged", alive: true };
    }

    if (probe(current_index))
        return { index: current_index, reason: "alive", alive: true };

    for (let i = 0; i < length(values); i++) {
        if (i == current_index)
            continue;
        if (probe(i))
            return { index: i, reason: i < current_index ? "recovery" : "active_dead", alive: true };
    }
    return { index: current_index, reason: "all_down", alive: false };
}

function clone_state(value) {
    return json(sprintf("%J", value));
}

function apply_selections(state, selections) {
    let candidate = clone_state(state);
    let changed = [];
    for (let kind in [ "bootstrap", "main" ]) {
        let selected = common.object_or_empty(common.object_or_empty(selections)[kind]);
        if (selected.index == null)
            continue;
        let key = kind == "main" ? "main_index" : "bootstrap_index";
        if (int(candidate[key]) == int(selected.index))
            continue;
        candidate[key] = int(selected.index);
        push(changed, { kind, selected });
    }
    if (length(changed) == 0)
        return true;

    let stamp = clock();
    let candidate_path = STATE_FILE + ".candidate." + as_string(stamp[0]) + "." + as_string(stamp[1]);
    if (!write_state(candidate_path, candidate)) {
        log_message("failed to write candidate DNS state", "warn");
        return false;
    }

    let status = command_status(command_from_args([ SERVICE_BIN, "dns_failover_apply", candidate_path ]) + " >/dev/null 2>&1");
    remove_file(candidate_path);
    if (status != 0) {
        log_message("failed to apply candidate DNS state (status " + as_string(status) + ")", "warn");
        return false;
    }

    state.main_index = candidate.main_index;
    state.bootstrap_index = candidate.bootstrap_index;
    for (let item in changed) {
        let values = item.kind == "main" ? state.main_servers : state.bootstrap_servers;
        let selected = item.selected;
        log_message("switched " + item.kind + " DNS to priority " + as_string(selected.index + 1) + " (" + values[selected.index] + ", " + selected.reason + ")", "info");
    }
    return true;
}

function worker() {
    let cfg = settings();
    let state = runtime_dns.normalize_state(cfg, common.read_json_file(STATE_FILE));
    if (length(state.main_servers) <= 1 && length(state.bootstrap_servers) <= 1)
        return 0;
    if (!write_state(STATE_FILE, state))
        return 1;

    let active_interval = duration_seconds(common.option(cfg, "dns_check_interval", "10s"), 10);
    let recovery_interval = duration_seconds(common.option(cfg, "dns_recovery_check_interval", "60s"), 60);
    let timeout_seconds = probe_timeout(common.option(cfg, "dns_check_timeout", "2s"));
    let failure_threshold = bounded_positive_int(common.option(cfg, "dns_failure_threshold", "3"), 3, 20);
    let recovery_threshold = bounded_positive_int(common.option(cfg, "dns_recovery_threshold", "3"), 3, 20);
    let minimum_hold_seconds = duration_seconds(common.option(cfg, "dns_minimum_hold_time", "60s"), 60);
    let started_at = now_seconds();
    let next_active = started_at;
    let next_recovery = started_at + recovery_interval;
    let all_down = { main: false, bootstrap: false };
    let trackers = {
        main: confirmation_tracker(started_at),
        bootstrap: confirmation_tracker(started_at)
    };

    while (true) {
        let now = now_seconds();
        let current_cfg = settings();
        if (!runtime_dns.state_matches(runtime_dns.state_template(current_cfg), state))
            return 0;

        if (now >= next_active) {
            let raw = {};
            let selections = {};
            for (let kind in [ "bootstrap", "main" ]) {
                let key = kind == "main" ? "main_index" : "bootstrap_index";
                raw[kind] = choose_index(kind, state, int(state[key]), timeout_seconds, false);
                if (!raw[kind].alive && !all_down[kind])
                    log_message("all configured " + kind + " DNS servers are unavailable", "warn");
                all_down[kind] = !raw[kind].alive;
                selections[kind] = confirmed_selection(
                    int(state[key]), raw[kind], trackers[kind], false, failure_threshold
                );
            }

            let changes = {};
            for (let kind in [ "bootstrap", "main" ]) {
                let key = kind == "main" ? "main_index" : "bootstrap_index";
                changes[kind] = int(selections[kind].index) != int(state[key]);
            }
            let applied = apply_selections(state, selections);
            if (applied)
                for (let kind in [ "bootstrap", "main" ])
                    if (changes[kind]) {
                        trackers[kind] = confirmation_tracker(now_seconds());
                        all_down[kind] = false;
                    }
            next_active = now_seconds() + active_interval;
        }

        if (now >= next_recovery) {
            let selections = {};
            for (let kind in [ "bootstrap", "main" ]) {
                let key = kind == "main" ? "main_index" : "bootstrap_index";
                if (!recovery_allowed(trackers[kind], now, minimum_hold_seconds)) {
                    selections[kind] = { index: int(state[key]), reason: "hold", alive: true };
                    continue;
                }
                let selected = choose_index(kind, state, int(state[key]), timeout_seconds, true);
                selections[kind] = confirmed_selection(
                    int(state[key]), selected, trackers[kind], true, recovery_threshold
                );
            }
            let bootstrap = selections.bootstrap;
            let main = selections.main;
            let changes = {
                bootstrap: bootstrap.index != int(state.bootstrap_index),
                main: main.index != int(state.main_index)
            };
            let has_changes = changes.bootstrap || changes.main;
            let applied = apply_selections(state, { bootstrap, main });
            let completed = now_seconds();
            if (has_changes && applied) {
                if (changes.bootstrap)
                    trackers.bootstrap = confirmation_tracker(completed);
                if (changes.main)
                    trackers.main = confirmation_tracker(completed);
                next_active = completed + active_interval;
            }
            next_recovery = completed + recovery_interval;
        }

        command_success_from_args([ "sleep", "1" ]);
    }
}

function file_first_line(path) {
    let data = fs.readfile(path);
    if (data == null)
        return "";
    return trim(split(as_string(data), "\n")[0]);
}

function process_running(pid) {
    return match(as_string(pid), /^[0-9]+$/) != null && command_success_from_args([ "kill", "-0", pid ]);
}

function stop_runtime() {
    let pid = file_first_line(PID_FILE);
    if (process_running(pid))
        command_success_from_args([ "kill", pid ]);
    remove_file(PID_FILE);
    return 0;
}

function start_runtime() {
    let cfg = settings();
    stop_runtime();
    if (!runtime_dns.failover_enabled(cfg)) {
        remove_file(STATE_FILE);
        return 0;
    }
    if (!ensure_dir(RUNTIME_STATE_DIR))
        return 1;

    let command = command_from_args([ "ucode", "-L", LIB_DIR, DNS_FAILOVER_UC, "worker" ]) +
        " >/dev/null 2>&1 1000>&- & echo $! >" + shell_quote(PID_FILE);
    return command_status(command);
}

function select_fixture(state_path, alive_path, kind, recovery) {
    let state = common.object_or_empty(common.read_json_file(state_path));
    let alive = common.object_or_empty(common.read_json_file(alive_path));
    let key = kind == "main" ? "main_index" : "bootstrap_index";
    let values = kind == "main" ? state.main_servers : state.bootstrap_servers;
    let current = int(state[key] || 0);
    let selected = { index: current, reason: "all_down", alive: false };
    let probe = function(index_value) { return alive[as_string(index_value)] === true || alive[as_string(index_value)] == 1; };

    if (as_string(recovery) == "1" && current > 0) {
        for (let i = 0; i < current; i++)
            if (probe(i)) {
                selected = { index: i, reason: "recovery", alive: true };
                break;
            }
    }
    else if (probe(current)) {
        selected = { index: current, reason: "alive", alive: true };
    }
    else {
        for (let i = 0; i < length(values); i++)
            if (i != current && probe(i)) {
                selected = { index: i, reason: i < current ? "recovery" : "active_dead", alive: true };
                break;
            }
    }
    common.write_json(selected);
}

function confirmation_fixture(path) {
    let fixture = common.object_or_empty(common.read_json_file(path));
    let current = int(fixture.current_index || 0);
    let recovery = fixture.recovery === true || fixture.recovery == 1;
    let threshold = bounded_positive_int(fixture.threshold, 3, 20);
    let tracker = confirmation_tracker(int(fixture.started_at || 0));
    let results = [];
    for (let selected in common.array_or_empty(fixture.selections)) {
        let result = confirmed_selection(current, selected, tracker, recovery, threshold);
        push(results, result);
        if (int(result.index) != current && !result.pending)
            current = int(result.index);
    }
    common.write_json({ current_index: current, tracker, results });
}

function hold_fixture(last_switch_at, now, minimum_hold_time) {
    let tracker = confirmation_tracker(int(last_switch_at || 0));
    common.write_json({ allowed: recovery_allowed(
        tracker,
        int(now || 0),
        duration_seconds(minimum_hold_time || "60s", 60)
    ) });
}

let mode = ARGV[0] || "";

if (mode == "start-runtime")
    exit(start_runtime());
else if (mode == "stop-runtime")
    exit(stop_runtime());
else if (mode == "worker")
    exit(worker());
else if (mode == "verify-state")
    exit(verify_state(ARGV[1]) ? 0 : 1);
else if (mode == "commit-state")
    exit(commit_state(ARGV[1]) ? 0 : 1);
else if (mode == "select-fixture")
    select_fixture(ARGV[1], ARGV[2], ARGV[3], ARGV[4]);
else if (mode == "verification-plan-fixture")
    common.write_json(verification_plan(common.read_json_file(ARGV[1]), common.read_json_file(ARGV[2])));
else if (mode == "confirmation-fixture")
    confirmation_fixture(ARGV[1]);
else if (mode == "hold-fixture")
    hold_fixture(ARGV[1], ARGV[2], ARGV[3]);
else {
    warn("Usage: singbox/dns_failover.uc <start-runtime|stop-runtime|worker|verify-state|commit-state|select-fixture|verification-plan-fixture|confirmation-fixture|hold-fixture> ...\n");
    exit(1);
}
