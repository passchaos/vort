# Deflate short and medium/long match profiles, 2026-11-12

The frozen reymont 64 KiB L6 and new nci 64 KiB L9 recordings use the same
`2527c721...` compare binary and identical production kernel bytes. Reymont
uses 30,000 calls per batch; nci uses 60,000. Both capture complete cold public
calls against libdeflate 1.26 with two warmup and two measured paired batches,
CPU 15, i7-10700K, Zig 0.16.0 ReleaseFast and `skylake+pku+sgx`. The reference
uses recorded GCC 11.4 `-O3 -DNDEBUG -march=skylake` settings.

The new recording belongs to pre-correction `492a0a74`, with 1,244 samples and
no reported loss. Its original capture registry has 2,048 files. Fifteen build
modules omitted by that registry are separately preserved as a later Git-based
replay addendum, yielding 2,063 reconstructed files. Neither the manifest nor
its original validation bytes are rewritten to pretend those additions were
captured initially.

Whole-process physical kernel self weight is 58.02% for reymont and 46.93% for
nci. Those recordings include reference work and validation; these are not
Vort-only timing or instruction denominators. Within each observed generic
aligned root, the same physical address partition gives:

| Root-local sampled region | Reymont L6 | Nci L9 |
| --- | ---: | ---: |
| Literal chain | 28.58% | 23.84% |
| Match field decoding | 23.70% | 15.99% |
| Consume and next-entry preload/refill | 19.26% | 17.80% |
| Short-copy path including checks/dispatch | 12.79% | 7.25% |
| Wide-copy setup/kernel/fallback | 4.31% | 20.79% |

The pure wide-copy loop's observed share is 2.32% versus 16.79%. Stack-mov
loads have overlapping shares of 6.37% versus 6.93%; these must not be added
to the region partition. Per-instruction rounded totals are 99.94%/100.05%,
without renormalization. Cycle sampling skid and neighboring stalls prevent
assigning independent cost to a reload, comparison or padding instruction.

This supports separate short and medium/long-match diagnostics. It does not
convert token counts or sampling weight into throughput gains. Both profiles
precede the final wide-copy range correction and contribute no A/B samples.
Original reports and the explicitly main-authored derived partition summary
are bound in the [profile archive](match-path-profiles-20261112/README.md).

The following checked descriptor prototype tried to reduce copy parameters
carried across the common preload/refill region; its
[codegen result](completed-match-codegen-20261112.md) rejects that mechanism.
