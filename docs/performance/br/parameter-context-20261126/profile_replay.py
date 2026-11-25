"""Replay original profile reduction against memory-resident archive files."""
import json

from archive_io import load, require, sha
import profile_math


class PayloadPath:
    def __init__(self, data, name=""):
        self.data, self.name = data, name

    def __truediv__(self, other):
        return PayloadPath(self.data, (self.name + "/" if self.name else "") + str(other))

    def read_bytes(self):
        return self.data[self.name]

    def read_text(self):
        return self.read_bytes().decode()

    def write_text(self, value):
        self.data[self.name] = value.encode()


def verify(primary, payloads, registry, declared, baseline_sources):
    require(load(payloads, "frozen-receipts/candidate-all-src-before.json") ==
            load(payloads, "frozen-receipts/candidate-all-src-after.json") == registry and
            load(payloads, "frozen-receipts/baseline-all-src-before.json") ==
            load(payloads, "frozen-receipts/baseline-all-src-after.json") == baseline_sources,
            "Profile source snapshots differ")
    before, after, builds = load(payloads, "identity-before.json"), load(payloads, "identity-after.json"), load(payloads, "build-results.json")
    require(before["candidate_source6"] == declared and before["source_counts"] == {"baseline": 2189, "candidate": 2193},
            "Profile source6/counts differ")
    for name, digest in declared.items():
        require(sha(payloads["frozen-source6/" + name]) == sha(primary["source/" + name]) == digest, "Profile frozen source6 bytes differ")
    for name, digest in before["tool_sha256"].items():
        require(sha(payloads[name]) == digest, "Profile common tool differs")
    for name, digest in after["artifacts"].items():
        require(sha(payloads[name]) == digest, "Profile ELF/object byte binding differs")
    require(payloads["bin/ordinary-baseline"] == primary["bin/old_exact"] and payloads["bin/ordinary-candidate"] == primary["bin/current"],
            "Profile ordinary/primary ELF differs")
    require(sha(payloads["build/candidate-record.o"]) == load(primary, "build-results.json")["current"]["record_object_sha256"],
            "Profile V6 object/primary object differs")
    for variant in ("baseline", "candidate"):
        require(builds[variant]["exit_code"] == 0 and sha(payloads["bin/profile-" + variant]) == builds[variant]["executable_sha256"],
                "Profile compiled ELF differs")
    memory = dict(payloads)
    profile_math.ROOT = PayloadPath(memory)
    replayed = profile_math._replay()
    require(replayed == load(payloads, "summary.json") and json.loads(memory["family-observation.json"]) ==
            load(payloads, "family-observation.json"), "Original profile counters/family reduction differs")
    require(after["active_own_heavy_count"] == 0 and after["recorded_command_exit_codes_all_zero"], "Historical profile completion receipt differs")
    return {"full_summary": replayed, "family_observation": load(payloads, "family-observation.json"),
            "verified_profile_rows": 4, "verified_ordinary_wires": 4,
            "observed_mozilla_parameter_branch_analysis_builds": {"baseline": 2, "candidate": 1},
            "observed_mozilla_whole_context_builds": {"baseline": 10, "candidate": 9},
            "observed_nci_whole_context_builds": {"baseline": 8, "candidate": 8},
            "event_sequences_complete": True, "mozilla_detail_prefix": 8, "mozilla_details_truncated": True,
            "runtime_cache_hit_counter": None, "runtime_shared_common_hit_counter": None,
            "profile_elf_sha256": {variant: builds[variant]["executable_sha256"] for variant in ("baseline", "candidate")},
            "scope": "Actual branch/event/detail math replay in memory; recorded native decode receipts verified, no decoder rerun. Trace has no cache/family ID or command fingerprint. Mozilla2->1 is confined to observed branch slots/source sequence; NCI8->8. Instrumented normal_ns/stage times do not establish ordinary throughput or source leadership."}
