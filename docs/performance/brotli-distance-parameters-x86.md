# Brotli distance parameter search

Date: 2026-10-14. Host: Intel Core i7-10700K, Linux x86-64, Zig 0.16.0,
ReleaseFast, CPU affinity 2, one codec thread.

## Functional result

The ratio encoder can now search all 64 legal RFC 7932 distance alphabet
shapes rather than fixing optimal command plans to `(NPOSTFIX=0, NDIRECT=0)`:

- all four postfix widths and all sixteen scaled direct-distance fields use the
  shared, independently verified distance inversion;
- recent-distance symbols 0--15 remain parameter-independent;
- repeated semantic explicit distances are frequency-aggregated before the
  64-shape scan;
- every shape is scored with its actual Huffman payload, extra bits, and exact
  simple or complex prefix-tree declaration cost;
- only the best estimated alternative is materialized, and it replaces the
  historical complete wire only when the final byte length is strictly lower;
- equal estimates and equal complete wires retain `(0, 0)` deterministically.

Nonzero postfix widths route to a separate noinline 520-symbol-capacity writer
in the `.vort_br_distance_params` cold text section. The existing 79-symbol
instance remains authoritative for fast, balanced, ordinary ratio, same-last,
legacy distance split, and adaptive distance split paths. Unsupported
wide-plus-split combinations are rejected rather than silently ignored.

The focused production fixture cycles five explicit distances so they fall out
of the four-entry recent-distance ring. Parameter search reduces its wire from
6,775 to 5,140 bytes for an 81,920-byte payload, a 24.13% reduction. The
selected nonzero-postfix stream decodes byte-exactly through Vort, Node,
runtime libbrotli 1.0.9, and Vort's 17-byte-input/31-byte-output progressive
decoder. The upstream differential reports
`planned_distance_parameter_cases=1`.

The score module separately checks all 64 shapes against an independent
tree-writing oracle, includes a stable nonzero-postfix winner, retains the
baseline on an exact tie, rejects invalid/empty streams, and unwinds every
allocation failure. The complete production selector and wide writer also have
allocation-failure and unsupported-combination coverage.

## Automatic policy and performance

`PlannedEncodeOptions.distance_parameter_search` is nullable:

- `null` automatically searches the stable record-optimal family;
- `false` disables parameter search;
- `true` also searches the general bounded optimal candidate.

This policy follows the measured Pareto result. Eleven alternating independent
baseline/current process pairs, ten encodes per process, compared commit
`f30b4ee0` with the retained implementation:

| Case | Baseline bytes | Current bytes | Size change | Current wins | Baseline/current paired throughput | Baseline median ns | Current median ns |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `records_q8` | 3,132 | 2,865 | -8.52% | 0/11 | 0.975238x | 128,739,238 | 131,413,840 |
| `source32k` | 6,645 | 6,645 | 0 | 3/11 | 0.994133x | 94,324,910 | 94,886,021 |

The record row accepts about 2.5% encode-throughput cost for an 8.5% size
reduction. General source search is disabled automatically: a forced current
binary run kept the same 6,645-byte wire while measuring about `0.8806x` of the
disabled path. Callers can still force it when their own corpus justifies the
tradeoff. The ordinary default source row retains identical wire/checksum and
is treated as no-regression evidence, not a speed improvement claim.
