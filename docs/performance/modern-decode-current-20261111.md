# Current-source decode against modern reference libraries, 2026-11-11

Vort still has a measurable decode throughput gap against the selected modern
libraries. This epoch replaces the older installed-library decoder gap table
for the input/lifecycle scope below. It does not establish an industry-best
ranking or a cross-platform result.

The frozen codec source is `4bca528b36e2c9ac9065826000b3ee66e6c65966`.
New benchmark tools are bound by the source overlay and executable hash in the
[evidence bundle](modern-decode-current-20261111/README.md). Production codec
files did not change during this epoch.

## Cold-context one-shot decode

Each value is the geometric mean of **Vort time / reference time**. Above one
means Vort takes longer. Each size has 24 rows: twelve Silesia files and two
reference frame levels/qualities. All-size summaries give each row equal
weight, rather than weighting by input bytes.

| Codec and reference | 64 KiB | 1 MiB | Whole file | All 72 rows | Vort/reference throughput |
| --- | ---: | ---: | ---: | ---: | ---: |
| Deflate / libdeflate 1.26 | 1.517x | 1.425x | 1.430x | **1.457x** | 0.686x |
| Zstd / libzstd 1.6.0 | 1.293x | 1.332x | 1.311x | **1.312x** | 0.762x |
| Brotli / libbrotli 1.2.0 | 1.240x | 1.160x | 1.235x | **1.211x** | 0.826x |

These cold-context operations reuse caller output buffers. Deflate reference
allocation, decode and decompressor release occur inside every timed call.
Zstd uses `ZSTD_decompress`; Brotli uses `BrotliDecoderDecompress`, whose state
initialization, internal workspace handling and cleanup are included. Vort
uses its public caller-buffer one-shot APIs. “Cold” describes the per-call
context lifecycle, not an unprimed machine cache or process startup.

Weakest cold rows are Deflate `reymont.64k` L6 (**1.660x**), Zstd `mozilla.1m`
L3 (**1.662x**) and Brotli full `mozilla` q11 (**2.039x**). Individual weaker
rows must remain visible alongside geometric means.

## Prepared-context comparisons

Zstd retains and primes both `NativeFrameDecoder` and `ZSTD_DCtx` outside
timing. Its time ratios are **1.204x / 1.339x / 1.320x** for 64 KiB / 1 MiB /
whole files. Context reuse helps the small group but does not guarantee an
improvement on every input size or API path.

Deflate's additional prepared rows retain only the reference decompressor;
Vort continues to use its same public one-shot entry point. Their ratios are
**1.525x / 1.425x / 1.429x**, and the artifacts explicitly label this
`reference-only-prepared`. They are not presented as a matched reusable Vort
context comparison. Brotli has no equivalent reset/reuse reference API in this
probe and is not assigned a fabricated prepared mode.

## Protocol and evidence

- Intel i7-10700K, x86_64-linux-gnu, logical CPU 15, Zig 0.16.0 ReleaseFast,
  `skylake+pku+sgx`; reference builds use recorded GCC Release/Skylake flags.
- 216 independently verified compressed fixtures: twelve Silesia files,
  64 KiB/1 MiB/full sizes, Deflate L6/L9, Zstd L3/L19 and Brotli q6/q11.
  Deflate wire generation uses recorded Python zlib raw mode; quality/window/
  mode and runtime version are retained for every generator.
- 360 lifecycle rows, 100/20/1 calls per batch for 64 KiB/1 MiB/full. Each row
  retains two warmup pairs and six measured pairs in balanced AB/BA order:
  **720 warmup and 2,160 measured pairs**. No minimum-of-N estimator is used.
- Output counts are checked for every call. Complete output, unchanged input,
  64-byte guards and available exact-consumption counts are checked per batch
  outside timing. Explicit library paths and actual process mappings prove the
  selected loaded library closure.
- Raw clocks determine paired log ratios. Confidence intervals use fixed-row,
  order-stratified bootstrap with recorded seeds and 2,000 resamples. They
  quantify sampling uncertainty for this host/matrix; they do not represent
  uncertainty over all possible workloads or hosts.
- Whole-child RSS includes loaded libraries, caller input/output buffers,
  validation and contexts. It is separately labeled and is not codec-only
  requested heap. The host uses `intel_pstate`/`powersave` with turbo enabled;
  this is an observational development-host screen, not a dedicated-host merge
  acceptance gate.

The old Deflate 1.06x comparison used libdeflate 1.10, a different wire and
sampling epoch. Its difference from 1.457x cannot be attributed solely to a
codec regression or solely to reference improvements. The new libraries,
fixed frames, lifecycle and all raw pairs define this current evidence.

Next investigate Deflate whole-call instruction/entry-loop work and Zstd/Brotli
prepared-executor structure using this frozen pilot, then broaden dictionary,
incremental/chunk schedules, allocation/heap, AArch64 and small-payload lanes.
Encoder gaps still require their own current-source matched-lifecycle matrix.
