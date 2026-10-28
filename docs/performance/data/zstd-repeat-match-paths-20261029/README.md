# Isolated repeat matching experiments

Baseline is `b3c40946`. This package records two 48-entry full-associative
lookup shapes, vector32 mismatch masks and four-byte prefix rejection. None
is adopted from these screens. The manifest points to the identical shared
source/build snapshot in the preceding ML-loop package, which is checked
against all 1536 members.

Each `*-small`/`assoc-*` archive contains its exact candidate source, ordinary
runner, raw two-round timing and wire/profile records, commands and identities.
The two `*-large` archives separately record single balanced larger/trained
matrices and actual input/dictionary bytes. Compiled native runners and caches
are excluded; the executed binary SHA-256 identities remain recorded. The
second cache shape reuses the exact verified baseline binary of the first.

Contract archives preserve frozen current DP/resources/HQ oracles, lane and
actual-work ledgers, quota/resource checks, public fixture and successful target
records. Vector32's big-endian object compilation is recorded without claiming
execution. Prefix byte counts represent executed four-byte prechecks plus the
original comparison path, not replayed legacy counts.

`reference-decode.json` records independent decoding of all 120 ordinary wire
artifacts through libzstd 1.6.0 and retains its library hash. Run this directory's
`audit.py` to verify archive/source identities, raw timing summaries, full wires,
profile exclusions and probe accounting, contract terminal records and reference
decodes. It also requires both cache variants' complete work profiles to agree.

Replay extracts the shared baseline and one exact candidate/test overlay,
rewrites structured archived paths, and preserves compiler flags, input
identities, timing scope and AB/BA order. Do not combine the isolated candidates
when assessing their measured results. The main report retains the mixed and
slow observations and the stack/heap tradeoffs.
