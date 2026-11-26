# Shared literal model prototype, 2026-11-26

Status: frozen source passes the declared performance, control and functional
gates; integration commit and remote handoff are pending.
This follows the [opportunity audit](literal-model-opportunity-20261126/README.md)
and [structural boundary](q8-structural-followup-20261126.md). It does not alter
q8 models, candidate order, strict wire ties, distance parameters or presets.

An owner lives only in the immutable final command group. Up to five complete
literal models retain active alphabets, lengths, normalized context and pure
literal counts/bit costs. Normal and counted adaptive-distance writers reuse
these facts; command/distance preparation, headers, full payload costs and final
alignment are recomputed. Short-match mutation, temporal/joint literal shapes,
HQ output, metadata and other excluded routes retain their original builders.
The public enablement is q8/generic/explicit window16 without HQ/shared data.

The owner allocates active trees only, publishes after both allocations and
copies succeed, and frees all models before returning the owned wire. Its
256 KiB internal cap includes metadata. Actual maximum five-slot/320-tree
size is 249,656 B native and 248,208 B WASI; these include stack-resident owner
metadata and are not whole-operation heap or stack measurements.

Functional evidence so far:

- Independent owner contracts: Native and actual WASI 15/15 each.
- Actual writer smoke: Native 25/25.
- Model/writer oracles: Native and actual WASI 25/25; 162 complete wire/stats/
  model comparisons, 126 fresh-frame decodes and 36 seeded-history model cases.
- Mozilla/Xray/NCI/XML public gold and scope cases pass inside both recorded
  37/38 initial campaigns. Their remaining writer failure was a test mixing
  nonzero prior history with a fresh zero-history decoder. The original failed
  source/results/wasm remain saved; the subsequent diagnostic confirms uncached
  and cached decoding had the same mismatch. Valid fresh cases were added
  without removing the seeded wire/model oracles.
- Native public resource gate: 35/35, Mozilla 625 induced OOMs plus 625 active
  retries, exact-D success, D-minus-one quota refusal and complete cleanup.
  Actual WASI resource gate also passes 35/35, with 658 induced OOMs and 658
  active retries. Both targets preserve the two observed requested-heap peaks.

Native requested-heap observations, with output freed by the caller:

| Input | Disabled / enabled peak B | Allocation count | Cumulative allocated B |
| --- | ---: | ---: | ---: |
| Mozilla 64 KiB | 5,115,910 / 5,115,910 | 557 / 625 | 22,667,591 / 22,731,223 |
| Xray 64 KiB | 7,901,911 / 7,901,911 | 734 / 806 | 36,683,602 / 36,813,970 |

Peak is unchanged in these two observations, while allocation count and
cumulative bytes increase. All capture/free costs must remain inside the public
operation timing. These figures do not establish a throughput or RSS benefit.

The WASI peaks are 4,430,770 B for Mozilla and 6,930,055 B for Xray, unchanged
with reuse. Their allocation counts increase 590 to 658 and 801 to 873;
cumulative requested bytes increase 23,457,543 to 23,520,847 and 41,499,259 to
41,628,955. Caller wire release and every controlled failure/retry balance the
backing allocator; the sweep totals use u128 accumulation on the 32-bit target.

The frozen 2,218-source-file manifest is
`a3cc7ac8e424db04added9be220465f3428adc563b57f4b1de474a3ca6577153`.
Original validation and intermediate failures are retained under
`/tmp/vort-br-literal-model-validation.6km4y0gx`; the new benchmark epoch is
`/tmp/vort-br-shared-literal-model-ab.p9wbbc7q`. After all builds and the 54-wire
untimed preflight stopped, Root released a new pilot window. It completed all
24 pairs / 48 calls with GM 1.0381130413183461x, every row at least 0.98x and
CI null. The Mozilla pairs are 1.266924997x and 1.002671175x; both remain in
the raw observations. This point estimate permits the next screen but does not
prove adoption or attribute sample variation. Independent data verification
passes. Root approved a separate full campaign, which completes 90 pairs /
180 calls: primary GM 1.0320069538939025x, paired 95% CI
[1.0286014769465641, 1.0354237056386224], every row floor and wire identity
pass. This is the primary gate only; independent full replay, q4/q11/ratio,
4 KiB controls pass their predeclared point-estimate gates. Independent full
statistics/source/raw replay passes without importing the producer. The
whole-library `zig build -j2 test check check-wasm --summary all` completes with
actual exit0, 414/414 successful steps and 6,068/6,070 tests (two skipped).
Its `failed command` diagnostic lines do not establish subprocess failure;
the final authoritative summary is successful. The same Zstd WASM also passes
an independent exact-command rerun, 84/84, with unchanged SHA.

Public control speedups are q4 1.00329490x, q11 with explicit 8 KiB command-state
cap 1.00187501x and ratio 1.00392153x. All twelve 4 KiB controls pass their point
floor; NCI is 0.98538827044x with CI [0.97854051942, 0.99632292], so the CI does
not guarantee a 0.98 lower bound. XML is 0.99357515424x. These are control
observations, not claimed improvements. The control sampler's initial wrong
protocol-manifest lookup and subsequent authorized launch remain recorded;
correct source/ELF/protocol verification passes, with no sample retry/filter.
Require the frozen public
pilot/full 1.03 target, paired interval and every row/control at least 0.98x;
NCI/XML and all predeclared 4 KiB/q4/q11/ratio controls remain mandatory.
