# Physical Brotli wire accounting, 2026-11-25

The q8 profile gate now reduces actual complete wire events separately from
evaluated lengths and intermediate selection outcomes. A wire that wins one
comparison but is replaced later is still a materialized loser. Conversely,
a counted `evaluate` candidate is never counted as a physical output.

Each validated run reports `physical_wires`:

- successful complete wire events and their summed encoded lengths;
- failed and unclassified attempts;
- the final returned physical event ID;
- exact losing materializations and origins when coverage permits.

The exact losing count is successful physical wire events minus the final
returned wire. It is available only when wire coverage is complete, the final
identity is present and no attempt lacks its completion/failure information.
Incomplete cases report a null losing count. Encoded-length sums are neither
peak heap nor complete memory traffic. No production encoder changes.

## Independent coverage rules

The original gate still requires complete context details by default. Context
detail storage is independently capped at eight records; its truncation does
not imply the complete wire event log lost entries. An explicit
`--wire-counts-only` mode accepts the reported context-detail prefix and labels
`context_detail_coverage_complete=false`, while retaining the original wire
identity, full event topology, non-overlapping timing and no-event-truncation
checks. This mode does not prove all context-search observations were captured.
Historical reports without context details label their coverage as null.
Invalid non-boolean coverage/truncation flags are rejected.

```sh
python3 tools/br/quality_profile_gate.py --json "$profile" --executable "$probe" \
  --wire-counts-only --output "$wire_counts"
```

The diagnostic producer must still use the same explicit window16 settings as
the [current encoder matrix](../modern-encode-refresh-20261125/README.md).
Its pending normal/trace option-binding correction is independent of this
Python evidence reducer. Actual current losing-wire counts are not claimed
until the instrumented output hash matches the frozen matrix and event
coverage checks pass.

## Validation

The original **19** malformed-evidence tests pass. **Nine** focused tests
cover earlier winners being replaced, counted versus emitted candidates,
failed/unclassified attempts, explicit context-prefix mode, default full
context refusal, event truncation, invalid coverage/error types, and retained
origin/length accounting. These are synthetic evidence-schema regressions,
not measurements or codec round trips. They run without compiling or
interrupting the live complete-file timing campaign.

```sh
PYTHONDONTWRITEBYTECODE=1 taskset -c 0 python3 tools/br/quality_profile_gate_smoke.py
PYTHONDONTWRITEBYTECODE=1 taskset -c 0 python3 tools/br/quality_profile_wire_counts_tests.py
```
