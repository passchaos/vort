# Literal model reuse opportunity, 2026-11-26

Status: pure-data audit of the existing sealed q8 diagnostic. No new codec,
build or timing run, no encoder change, and no measured speedup. This is the
next boundary proposed in the [structural follow-up](../q8-structural-followup-20261126.md).

`audit.py` reads only `profile.json` from the adjacent historical/current-main
`diagnostic.tar.gz`. It uses standard-library JSON/tar readers without extracting
files or importing the producer. `summary.json` binds the exact archive/profile
bytes and retains every joined consumer event ID. `execution-receipt.json`
records Root's actual exit0, script/output hashes and UTC interval; it does not
reuse the architect's earlier query exits. Root consolidated the three existing
static-query algorithms without changing their metadata join or exclusions.

| Scope | Result |
| --- | ---: |
| Complete event streams | 36 across 12 inputs |
| Successful physical outputs | 1,029 |
| Nonrecent physical outputs | 417: 309 plain, 48 ordinary context, 48 adaptive-distance context, 12 adaptive-literal |
| First stored round per input: matching final model-building opportunity slots | 238, in 10 inputs; NCI/XML zero |
| Largest preferred group by metadata | 5 distinct slots; largest tree-count sum 27 |
| Context-detail prefixes truncated | 18; 87 reuses in recorded prefixes, complete reuse count unknown |

The opportunity joins a final non-temporal build slot with a preferred slot
under the same direct parent scope, comparing command count and complete
context mode/tree count/map. Physical emissions linked to prepared evaluations
are excluded. This does **not** establish command-list, input-content or
literal-histogram identity, cache hits, or recoverable time. Real reuse requires
the immutable command-group contract and complete literal-policy key described
in the follow-up. Slot/tree counts are metadata observations, not measured
allocation, stack or RSS sizes.

The 417 classification uses all complete event streams. The 238 join and slot
table use only stored round zero for each input; do not multiply or relabel
them as all-round counts. Truncated context details are not used by these joins.

```sh
python3 -B docs/performance/br/literal-model-opportunity-20261126/audit.py
```

The default input resolves relative to the script, so it also runs from another
working directory. Use `--package /copy/diagnostic.tar.gz` for a copied input.
The script writes JSON only to stdout and records no new measurement. The
already rejected local/global emission and ordinary nonrecent prototypes keep
their independent verdicts.
