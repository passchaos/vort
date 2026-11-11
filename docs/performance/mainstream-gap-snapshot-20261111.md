# Mainstream codec performance evidence, 2026-11-11

The subsequent [current-source modern decode epoch](modern-decode-current-20261111.md)
now supersedes the older decoder table below for its declared whole-buffer
scope: cold-context Vort/reference time is Deflate 1.457x, Zstd 1.312x and
Brotli 1.211x, with raw paired samples and 64 KiB/1 MiB/full inputs. Encoding
rows here remain historical and require their own refreshed matrix.

This assessment summarizes the latest reproducible reports available in the
repository. It does not measure the 2026-11-11 HEAD or establish an industry-best
ranking. Recent work closes functional resource/ownership defects; those test
receipts must not be substituted for throughput measurements. The long-term
Deflate/Zstd/Brotli objective remains open.

## Decompression

The latest matrices use twelve Silesia sources at 64 KiB and 1 MiB prefixes,
two levels/qualities, allocating or caller-buffer one-shot reference APIs as
specified by each report, Zig 0.16.0 ReleaseFast, Skylake code generation and
an i7-10700K pinned to logical CPU 15. These are 48-row geometric summaries.
The competitors in these latest decode reports are older installed libraries.

| Format | Vort/reference time | Vort/reference throughput | Reference | Latest report |
| --- | ---: | ---: | --- | --- |
| Raw Deflate, L6/L9 reference wires | 1.060x | 0.9437x | libdeflate 1.10 | [2026-11-10 update](deflate-decode-current-20261109.md) |
| Zstd, L3/L19 reference wires | 1.320x | 0.7573x | libzstd 1.4.8 | [2026-11-10](zstd-decode-current-20261110.md) |
| Brotli, q6/q11 reference wires | 1.275x | 0.7843x | libbrotli 1.0.9 | [2026-11-09/10 update](brotli-decode-current-20261109.md) |

Deflate is closest to these references. Zstd and Brotli still require roughly
28-32% more decode time overall. Results differ substantially by input: Brotli
64 KiB q6 takes 1.388x reference time, while 1 MiB q11 takes 1.192x. Some rows
beat the corresponding reference; that does not establish overall parity.

The ledger's older full-file comparisons against libzstd 1.6.0 and libbrotli
1.2.0 are separate earlier epochs. They must not be combined with subsequent
internal A/B gains to synthesize a latest-library current-HEAD comparison.

## Compression

Encoding evidence is less recent and spans different policies, windows,
effort budgets and lifecycles. The rows below are dated snapshots, not one
common quality frontier. Time and output-size ratios are Vort/reference;
lower is better. A smaller output does not imply a better speed/size tradeoff.

| Scope | Time ratio | Output-size ratio | Reference and evidence |
| --- | ---: | ---: | --- |
| Deflate L9, twelve 4/16/64 KiB prefixes | 1.85-1.92x | 1.0007-1.0124x | libdeflate 1.26 L12; [2026-10-31 BT epoch](deflate-bt-optimal.md) |
| Deflate refined best, twelve 1 MiB prefixes | Timing not refreshed for complete final five-pass policy | 0.9987-1.0106x | libdeflate 1.26 L12; [2026-11-05/06](deflate/refined-history-chunks.md) |
| Zstd native btultra2, twelve 64/128 KiB prefixes | 3.012/3.066x | 1.00480/1.00514x | libzstd 1.6.0; [first-price-components epoch](zstd/first-price-components.md) |
| Same Zstd policy, three actual 1 MiB inputs | 4.497x | 0.99280x | Same separate multi-block epoch |
| Brotli q8/generic/window16, twelve 4/16/64 KiB prefixes | 30.086x | 0.995561x | libbrotli 1.2.0; [2026-11-03 matched epoch](br/command-model-lifetime.md) |
| Brotli q8, six files up to 8 MiB each | 3.601x | 0.9828x | libbrotli 1.0.9; [separate 2026-11-03 screen](br/full-file-q8-20261103.md) |

The full-file Brotli screen's `vort_over_reference` CSV field is a throughput
ratio (`reference_ns/vort_ns`). Its original Markdown "Time ratio" headings
have been corrected. The 0.2777 value means about 3.601x time, not faster encoding.

Deflate's recorded high-ratio output is close to libdeflate L12, but speed
remains a major gap. Its full SAO/X-ray 4.87/4.42-second timings belong to the
earlier three-pass build; the final fourth/fifth passes and later suffix-only
optimization must be timed directly rather than combined arithmetically.
Zstd HQ can obtain similar output sizes with substantially more parser work.
Brotli q8's small-prefix comparison buys roughly 0.44% smaller output with
about thirty times the reference latency; its large-file screen is a different
reference/workload comparison. Later q10/q11 quality improvements supersede
older size rows, without a corresponding current matched speed/size matrix.

The [2026-11-10 HQ-auto package](zstd-hq-auto-level-policy.md) adds a newer
64 KiB preset comparison against libzstd 1.6.0, but its 95-state legacy
snapshot was subsequently withdrawn for wire incompatibility. Its HQ effort
remains valid as archived evidence; the complete table is not a current-default
ranking. High-quality level names alone do not align actual search algorithms.

## Next evidence and optimization

After functional gates, refresh one frozen-source full matrix against the
available modern libdeflate 1.26/libzstd 1.6.0/libbrotli 1.2.0 builds. Include
whole files, small payloads, dictionaries, streaming schedules, cold and warmed
contexts, output size and scoped memory, with raw paired samples and controls.

The measured structural priorities remain prepared/shared candidate analysis
and winner-only emission for encoding, Zstd executor/FSE representation fusion,
and Brotli payload phase-machine fusion for decoding. Any adopted change needs
whole-operation improvement and the architecture's non-regression gates.
