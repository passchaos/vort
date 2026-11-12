"""Reject missing, scaled or ambiguously scoped per-thread PMU batch evidence."""

SCOPE = "Vort public decode batch and loop/count/mix bookkeeping; userspace boundary ioctl setup; timers and full validation outside counters"
THREAD_POLICY = "calling-thread-only; no inheritance"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def u64(value, positive=False):
    return type(value) is int and (0 < value if positive else 0 <= value) and value < 1 << 64


def validate_pmu(report, config):
    selected = config.get("perf_group")
    pairs = report["warmup_pairs"] + report["pairs"]
    if selected is None:
        require(report.get("pmu") is None, "Undeclared PMU collection")
        require(all(pair.get("vort_counters") is None and pair.get("reference_counters") is None for pair in pairs), "Undeclared PMU counters")
        require(report.get("sampling_mode", "paired-wall-time") == "paired-wall-time", "Wrong wall-time sampling mode")
        return
    require(type(selected) is str and selected in {"branches", "branch-misses"}, "Unknown PMU group")
    require(report.get("sampling_mode") == "pmu-diagnostic-with-batch-control-overhead", "PMU control overhead not declared")
    pmu = report.get("pmu")
    require(type(pmu) is dict, "Missing PMU scope")
    require(pmu.get("group") == selected.replace("-", "_"), "Wrong PMU group")
    require(pmu.get("scope") == SCOPE and pmu.get("thread_policy") == THREAD_POLICY, "Wrong PMU scope")
    require(pmu.get("exclude_kernel") is True and pmu.get("exclude_hypervisor") is True, "PMU privilege scope missing")
    require(pmu.get("scaled") is False and pmu.get("reference_counted") is False, "Scaled or mixed PMU collection")
    require(pmu.get("header_time_scope") == "cumulative per open group; reset clears counts only", "PMU header time scope missing")
    hardware = pmu.get("hardware")
    require(type(hardware) is dict, "Missing PMU configuration")
    configs = hardware.get("hardware_configs")
    require(type(configs) is list and all(u64(value) for value in configs) and configs == [0, 1, 4 if selected == "branches" else 5], "Wrong hardware events")
    require(hardware.get("events") == ["cycles", "instructions", selected], "Wrong hardware event labels")
    require(all(type(hardware.get(field)) is int for field in ("read_format", "pid_argument", "cpu_argument")) and hardware.get("read_format") == 15 and hardware.get("pid_argument") == 0 and hardware.get("cpu_argument") == -1, "Wrong PMU read or thread attachment")
    require(hardware.get("disabled_at_open") is True and hardware.get("inherit") is False and hardware.get("exclude_kernel") is True and hardware.get("exclude_hv") is True, "Wrong hardware privilege or inheritance scope")
    require(hardware.get("values_scaled") is False and hardware.get("strict_full_running_time") is True, "Hardware scheduling policy missing")
    expected_ids = None
    previous_enabled = 0
    for pair in pairs:
        counters = pair.get("vort_counters")
        require(type(counters) is dict, "Missing Vort PMU batch")
        words = counters.get("raw_words")
        ids = counters.get("event_ids")
        require(type(words) is list and len(words) == 9 and all(u64(word) for word in words), "Invalid raw PMU group read")
        require(words[0] == 3, "Wrong PMU event count")
        require(type(ids) is list and len(ids) == 3 and all(u64(i, True) for i in ids) and len(set(ids)) == 3, "Invalid PMU event IDs")
        if expected_ids is None:
            expected_ids = ids
        require(ids == expected_ids, "PMU event IDs changed between batches")
        observed = dict(zip(words[4::2], words[3::2]))
        require(len(observed) == 3 and set(observed) == set(ids), "Raw PMU IDs missing or duplicated")
        for field, event_id in zip(("cycles", "instructions", "third_event"), ids):
            value = counters.get(field)
            require(u64(value, field != "third_event") and value == observed[event_id], "PMU semantic count does not match raw event")
        enabled, running = counters.get("time_enabled"), counters.get("time_running")
        require(u64(enabled, True) and u64(running, True) and enabled == words[1] and running == words[2], "PMU timing does not match raw read")
        require(enabled == running, "PMU group did not run for the complete enabled interval")
        require(enabled > previous_enabled, "Cumulative PMU enabled time did not advance")
        previous_enabled = enabled
        require(pair.get("reference_counters") is None, "Reference PMU counters in Vort-only scope")
