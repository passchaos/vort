# Current three-codec decode gap

This epoch re-measures the public one-shot decoders against the pinned
references after the committed Brotli and shared decoder increments. It replaces
the stale gap estimates in the decoder-priority audit for the one-shot API.

## Protocol

All 216 reference frames are used: twelve Silesia sources at 64 KiB, 1 MiB and
actual full lengths for raw Deflate levels 6/9, Zstd levels 3/19 and Brotli
qualities 6/11. Each process times one public one-shot decode call
(`decodeRawAuto`, `decodeFrameInto` or `decodeStreamInto`); loading, warmup,
output checks, SHA and guards stay outside the interval. Two alternating sweeps
give 1,296 processes. The run is pinned to logical CPU2 of an Intel i7-10700K
with Zig 0.16.0 ReleaseFast, GNU target `skylake+pku+sgx` and an 8 MiB stack
limit. Reference libraries are libdeflate (pinned build), libzstd 1.6.0 and
libbrotli 1.2.0 with different lifecycle costs.

## Results

Lower is faster. `current/baseline` compares the committed source with the
frozen decoder-priority baseline; `current/reference` compares it with the
pinned library. This table is the 2026-11-01 epoch after the Zstd copy,
incremental Brotli short-span and Deflate litlen live-range increments.

| Codec / level / scope | Current / baseline | Current / reference |
| --- | ---: | ---: |
| Deflate 6 / 64 KiB | 0.8598 | 1.6890 |
| Deflate 6 / 1 MiB | 0.8850 | 1.5975 |
| Deflate 6 / full | 0.8736 | 1.6084 |
| Deflate 9 / 64 KiB | 0.8508 | 1.6725 |
| Deflate 9 / 1 MiB | 0.8854 | 1.5825 |
| Deflate 9 / full | 0.8761 | 1.6089 |
| Zstd 3 / 64 KiB | 0.8843 | 1.5608 |
| Zstd 3 / 1 MiB | 0.8584 | 1.5463 |
| Zstd 3 / full | 0.8517 | 1.4703 |
| Zstd 19 / 64 KiB | 0.8312 | 1.5606 |
| Zstd 19 / 1 MiB | 0.8652 | 1.5537 |
| Zstd 19 / full | 0.8666 | 1.5145 |
| Brotli 6 / 64 KiB | 0.7627 | 1.4888 |
| Brotli 6 / 1 MiB | 0.9831 | 1.1421 |
| Brotli 6 / full | 0.8299 | 1.2109 |
| Brotli 11 / 64 KiB | 0.7254 | 1.3899 |
| Brotli 11 / 1 MiB | 0.8641 | 1.1242 |
| Brotli 11 / full | 0.8039 | 1.2258 |

The current source is 11–27% faster than the frozen baseline for every group.
The remaining reference gaps are largest for raw Deflate (1.58–1.69x), then
Zstd (1.47–1.56x), then Brotli (1.12–1.49x); Brotli 1 MiB is the closest at
1.12–1.14x. Small 64 KiB frames have the largest Brotli gap because fixed
per-call setup dominates.

These ratios use different reference lifecycles and describe warmed one-shot
calls only. They do not establish cold-start, streaming, dictionary or peak-memory
leadership.

A follow-up [one-shot fallback lookup](brotli-oneshot-fallback-lut.md) moved the
standard and large-window literal fallbacks to the prepared lookup, a
[further command/distance increment](brotli-oneshot-command-distance-lut.md)
extended it to the command and distance readers, and the
[standard packed literal cache](brotli-standard-packed-cache.md) removed repeated
packed-tree expansion from the one-shot standard path. The epoch before the
Deflate overcopy gives Brotli current/reference
`1.5093/1.1563/1.1727` for q6 and `1.3869/1.1271/1.2267` for q11 at
64 KiB/1 MiB/full. Raw Deflate remains the largest gap at about 1.69–1.77x,
followed by Zstd at about 1.52–1.61x. Brotli has the smallest gap at 1 MiB and
full.

## Epoch after the Deflate overcopy

A further 1,296-process epoch with the sixteen-byte Deflate overcopy gives
current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.7863 | 1.6890 | 1.7115 |
| Deflate 9 | 1.8288 | 1.6807 | 1.7030 |
| Zstd 3 | 1.6016 | 1.5921 | 1.5200 |
| Zstd 19 | 1.6089 | 1.5731 | 1.5632 |
| Brotli 6 | 1.4935 | 1.1073 | 1.2234 |
| Brotli 11 | 1.4017 | 1.1353 | 1.2296 |

Epoch-to-epoch variation is 1–3%, larger than the about 1% paired Deflate gain,
so this table describes the current gap rather than proving the increment. The
paired screens in [the overcopy evidence](deflate-sixteen-byte-overcopy.md)
remain the adoption authority. The largest gap is still raw Deflate at about
1.68–1.83x, then Zstd at about 1.52–1.61x, then Brotli at about 1.11–1.49x.

## Epoch after the Zstd field-group consolidation

A 1,296-process epoch with the consolidated Zstd sequence branch gives
current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.7937 | 1.6811 | 1.7021 |
| Deflate 9 | 1.8070 | 1.6870 | 1.7034 |
| Zstd 3 | 1.5596 | 1.5999 | 1.4876 |
| Zstd 19 | 1.5971 | 1.5636 | 1.5437 |
| Brotli 6 | 1.4995 | 1.1460 | 1.2147 |
| Brotli 11 | 1.4012 | 1.1320 | 1.2267 |

The Zstd level-3 full gap moves from 1.5200 to 1.4876 and level-19 full from
1.5632 to 1.5437, consistent with the paired about 1% win; the 1 MiB rows
remain inside epoch noise. The paired screens in [the field-group
evidence](zstd-sequence-field-group-branch.md) remain the adoption authority.
The largest gap is still raw Deflate at about 1.68–1.81x, then Zstd at about
1.49–1.60x, then Brotli at about 1.13–1.50x.

## Epoch after the Brotli wide match copy

A 1,296-process epoch with the wide tail-lookup match copy gives
current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.7987 | 1.6875 | 1.7129 |
| Deflate 9 | 1.8133 | 1.6868 | 1.7100 |
| Zstd 3 | 1.5607 | 1.5730 | 1.5159 |
| Zstd 19 | 1.5690 | 1.5556 | 1.5480 |
| Brotli 6 | 1.4891 | 1.1332 | 1.2171 |
| Brotli 11 | 1.3949 | 1.1254 | 1.2295 |

Brotli moves from `1.4995/1.1460` to `1.4891/1.1332` for q6 and from
`1.4012/1.1320` to `1.3949/1.1254` for q11 at 64 KiB/1 MiB, consistent with the
paired 0.5–1.3% win; full-file rows stay inside epoch noise. The paired screens
in [the wide-copy evidence](brotli-wide-match-copy.md) remain the adoption
authority. The largest gap is still raw Deflate at about 1.69–1.81x, then Zstd
at about 1.52–1.57x, then Brotli at about 1.13–1.49x.

## Epoch after the generic Deflate overcopy

A 1,296-process epoch with the guarded 16-byte overcopy in the generic
semantic loop gives current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.7249 | 1.6221 | 1.6316 |
| Deflate 9 | 1.7119 | 1.6138 | 1.6057 |
| Zstd 3 | 1.5575 | 1.5750 | 1.4983 |
| Zstd 19 | 1.5881 | 1.5549 | 1.5315 |
| Brotli 6 | 1.4847 | 1.1803 | 1.1705 |
| Brotli 11 | 1.3931 | 1.1222 | 1.2312 |

Raw Deflate moves from `1.7987/1.6875/1.7129` and `1.8133/1.6868/1.7100`
to `1.7249/1.6221/1.6316` and `1.7119/1.6138/1.6057`, consistent with the
paired 3.5–5.2% win. The Deflate gap is now about 1.61–1.72x, down from
1.69–1.81x. Zstd remains about 1.50–1.59x and Brotli about 1.12–1.48x, both
inside their epoch noise. The paired screens in [the overcopy
evidence](deflate-generic-sixteen-byte-overcopy.md) remain the adoption
authority.

## Epoch after the Zstd copy alignment

A 1,296-process epoch with the 16-byte wildcopy and the 16-byte literal copy
gives current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.7359 | 1.6420 | 1.6368 |
| Deflate 9 | 1.6962 | 1.6147 | 1.6233 |
| Zstd 3 | 1.5429 | 1.5486 | 1.4620 |
| Zstd 19 | 1.5625 | 1.5400 | 1.4974 |
| Brotli 6 | 1.4297 | 1.1401 | 1.2140 |
| Brotli 11 | 1.3981 | 1.0931 | 1.2231 |

Zstd moves from `1.5575/1.5750/1.4983` and `1.5881/1.5549/1.5315` to
`1.5429/1.5486/1.4620` and `1.5625/1.5400/1.4974`, consistent with the paired
1–3% wins. The Zstd gap is now about 1.46–1.56x, down from 1.50–1.59x. Deflate
remains about 1.61–1.74x and Brotli about 1.09–1.43x, both inside their epoch
noise. The paired screens in [the wildcopy evidence](zstd-sixteen-byte-wildcopy.md)
and [the literal-copy evidence](zstd-sixteen-byte-literal-copy.md) remain the
adoption authority.

Raw records, comparison and process intervals stay local under
`/tmp/vort-br-lookup-20261101/` under the lean-evidence policy.

## Next work

The largest remaining gap is still raw Deflate at about 1.61–1.74x, then the
Zstd sequence decode at about 1.46–1.56x. Brotli's 1 MiB gap is already small;
its 64 KiB gap needs per-call setup work. Each target requires its own
current-source epoch and must keep the compatibility and malformed-input
contracts.

## Epoch after the Deflate litlen live-range

A 1,296-process epoch after the [Deflate litlen live-range
change](deflate-litlen-width-live-range.md) gives current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.6890 | 1.5975 | 1.6084 |
| Deflate 9 | 1.6725 | 1.5825 | 1.6089 |
| Zstd 3 | 1.5608 | 1.5463 | 1.4703 |
| Zstd 19 | 1.5606 | 1.5537 | 1.5145 |
| Brotli 6 | 1.4888 | 1.1421 | 1.2109 |
| Brotli 11 | 1.3899 | 1.1242 | 1.2258 |

The Deflate 64 KiB gap moves from about 1.81 to 1.67–1.69 and the 1 MiB gap
from about 1.69 to 1.58–1.60, consistent with the paired about 6% win. The
largest gap is still raw Deflate at about 1.58–1.69x, then Zstd at about
1.47–1.56x, then Brotli at about 1.12–1.49x. The [incremental short-span
copy](brotli-short-span-copy.md) also improves the streaming API by about 5%
without moving these one-shot rows.

## Epoch after the Deflate reservoir-position and length-entry changes

A 1,296-process epoch after the [derived bit position](deflate-derived-consumed-bits.md)
and the [length-entry live range](deflate-length-entry-live-range.md) gives
current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.6264 | 1.5331 | 1.5589 |
| Deflate 9 | 1.6153 | 1.5178 | 1.5545 |
| Zstd 3 | 1.5536 | 1.5625 | 1.4793 |
| Zstd 19 | 1.5590 | 1.5446 | 1.5137 |
| Brotli 6 | 1.4799 | 1.1381 | 1.2099 |
| Brotli 11 | 1.4006 | 1.1268 | 1.2273 |

The Deflate 1 MiB and full gaps move from about 1.58–1.60 to about
1.52–1.56, and the 64 KiB gap from about 1.67–1.69 to about 1.62–1.63,
consistent with the paired about 4% win. Zstd and Brotli are unchanged inside
epoch noise. The largest gap is still raw Deflate at about 1.52–1.63x, then
Zstd at about 1.48–1.56x, then Brotli at about 1.13–1.48x.

## Epoch after the Deflate distance-entry live range

A 1,296-process epoch after the [packed distance entry](deflate-distance-entry-live-range.md)
gives current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.5607 | 1.4696 | 1.4793 |
| Deflate 9 | 1.5429 | 1.4687 | 1.4759 |
| Zstd 3 | 1.5293 | 1.5437 | 1.4774 |
| Zstd 19 | 1.5839 | 1.5415 | 1.5263 |
| Brotli 6 | 1.4870 | 1.1376 | 1.2169 |
| Brotli 11 | 1.3926 | 1.1283 | 1.2309 |

The Deflate gap moves from about 1.52–1.63 to about 1.47–1.56, consistent with
the paired about 4.5% win. Raw Deflate, Zstd and the Brotli 64 KiB rows are now
within about 1.47–1.58x of their references; Brotli at 1 MiB remains the
closest at 1.13x.

## Epoch after the Zstd offset-add and literal-bound changes

A 1,296-process epoch after the [plain offset adds](zstd-plain-offset-adds.md)
and the [folded wildcopy literal bound](zstd-wildcopy-literal-bound.md) gives
current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.5649 | 1.4661 | 1.4807 |
| Deflate 9 | 1.5381 | 1.4675 | 1.4657 |
| Zstd 3 | 1.5187 | 1.4993 | 1.4638 |
| Zstd 19 | 1.4930 | 1.4914 | 1.5166 |
| Brotli 6 | 1.4501 | 1.1376 | 1.2184 |
| Brotli 11 | 1.4004 | 1.1241 | 1.2231 |

Zstd moves from about 1.53–1.58 to about 1.46–1.52, with the largest change on
level 19 at 64 KiB (`1.5839` to `1.4930`), consistent with the paired screens.
Deflate and Brotli are unchanged inside epoch noise. The three codecs are now
within about 1.46–1.56x (Deflate), 1.46–1.52x (Zstd) and 1.12–1.45x (Brotli).

## Epoch after the Deflate loop alignment

A 1,296-process epoch after the [64-byte loop alignment](deflate-loop-alignment.md)
gives current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.5586 | 1.4702 | 1.4759 |
| Deflate 9 | 1.5515 | 1.4636 | 1.4660 |
| Zstd 3 | 1.5000 | 1.4753 | 1.4501 |
| Zstd 19 | 1.4817 | 1.4999 | 1.5040 |
| Brotli 6 | 1.4798 | 1.1445 | 1.2170 |
| Brotli 11 | 1.3920 | 1.1274 | 1.2251 |

The alignment is below epoch noise (about 0.3% on the paired screen), so the
table matches the previous epoch within 1–2% variation. The current gaps are
about 1.46–1.56x (Deflate), 1.45–1.50x (Zstd) and 1.13–1.48x (Brotli).

## Epoch after the Deflate preload-before-refill change

A 1,296-process epoch after the [preload-before-refill change](deflate-preload-before-refill.md)
gives current/reference:

| Codec / level | 64 KiB | 1 MiB | full |
| --- | ---: | ---: | ---: |
| Deflate 6 | 1.5458 | 1.4383 | 1.4523 |
| Deflate 9 | 1.5328 | 1.4332 | 1.4417 |
| Zstd 3 | 1.5097 | 1.4966 | 1.4688 |
| Zstd 19 | 1.4868 | 1.4804 | 1.5208 |
| Brotli 6 | 1.4857 | 1.1356 | 1.2138 |
| Brotli 11 | 1.3945 | 1.1201 | 1.2615 |

The Deflate 1 MiB gap moves from about 1.47 to about 1.43–1.44 and the 64 KiB
gap from about 1.56 to about 1.55, consistent with the paired 4–5% win inside
epoch noise. The current gaps are about 1.43–1.55x (Deflate), 1.47–1.52x
(Zstd) and 1.12–1.49x (Brotli).
