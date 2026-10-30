# Zstd cross-pass repeat evidence diagnostic

After retaining the cold `btultra2` match frontier, this diagnostic measured
whether repeat-distance match lengths should also persist across its first and
refined DP passes. The candidate was intentionally diagnostic-only: it recorded
and classified evidence but still executed every original `matchLength`, so no
timing or wire claim depends on the prototype.

## Safety model

Evidence is keyed by global block position plus physical distance. Local DP
position is insufficient because refined prices can change bounded window
extensions and later `base` values.

Each value stores a 31-bit verified length and one exact bit:

- `length < first maximum` is exact because a mismatch was observed;
- reaching the physical block end is also exact;
- otherwise the value is truncated and proves only that the match reaches the
  first maximum.

For a later maximum, exact evidence returns the smaller of verified length and
the requested maximum. Truncated evidence is a full hit only when the later
maximum does not exceed the verified prefix; a larger request needs resumed
comparison. Selector order, price admission, node insertion and tie behavior
were not changed.

## Four-way simulation

The prototype retained the first four unique repeat distances at each global
position. Each slot is eight bytes, so a production implementation would add
32 bytes per position: 128 KiB at 4 KiB, 512 KiB at 16 KiB and 4 MiB at the
maximum Zstd block, all in addition to the retained frontier.

| Input | Second-pass requests | Full hits | Request hit rate | Hits / aggregate probes | Recorded entries |
| --- | ---: | ---: | ---: | ---: | ---: |
| Dickens 4 KiB | `38,634` | `15,888` | `41.12%` | `20.88%` | `16,318` |
| Mozilla 4 KiB | `44,900` | `14,916` | `33.22%` | `15.85%` | `16,351` |
| MR 4 KiB | `33,069` | `16,020` | `48.44%` | `24.08%` | `16,345` |
| Dickens 16 KiB | `170,896` | `64,023` | `37.46%` | `18.75%` | `65,461` |
| Mozilla 16 KiB | `175,840` | `58,904` | `33.50%` | `16.77%` | `65,436` |
| MR 16 KiB | `182,065` | `57,896` | `31.80%` | `15.51%` | `63,391` |

Only two Dickens 16 KiB requests needed continuation from a truncated prefix;
all other non-hits were absent distances. The table is nearly full in every
row, yet it eliminates only 15.5%–24.1% of aggregate actual probes. Crucially,
the two 16 KiB frontier-fallback rows achieve only 31.8%–33.5% request hits,
well below the pre-registered 50% threshold.

## Decision

The added memory is not justified. A larger table would approach or exceed the
entire match-frontier allocation while the encoder remains dominated by price
evaluation and state insertion. No production or test source was changed.
Future HQ work should reduce transition count or state-update cost instead of
caching more byte-comparison evidence.

Raw profile reports, the exact diagnostic overlay and replay commands are in
[`data/zstd-cross-pass-rep-diagnostic-20261030/`](data/zstd-cross-pass-rep-diagnostic-20261030/).
