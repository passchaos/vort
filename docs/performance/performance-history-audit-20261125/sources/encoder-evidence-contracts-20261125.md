# Allocating encoder measurement contracts, 2026-11-25

Before refreshing the three-codec encoder matrix, the existing Deflate tool
selected independent fastest rounds and initialized its libdeflate compressor
outside the batch timer. The new data path retains chronological samples and
puts state creation/free inside every reference call, matching the ordinary
allocating Vort/zlib lifecycle.

Deflate's CSV now reports medians of all measured rounds. `--samples-json`
records every round's order, duration and output-length mix, plus separate
warmups. Six encoder permutations are repeated, with `--rounds` a positive
multiple of six and `--warmup` zero or a multiple of six (both default to six).
The JSON binds input and initial wire hashes, API scopes, levels and compiler
provenance. `--libdeflate-level` optionally selects 0–12 independently of the
Vort/zlib 0–9 level; equal numeric levels do not prove equal quality.

Initial wires from all three encoders are fully decoded by Vort and by
`libdeflate_deflate_decompress_ex`, including exact input consumption. Timed
iterations check the initial encoded length and retained mixes, not complete
wire identity. Input SHA-256 is checked again after timing. The JSON explicitly
labels this validation scope rather than claiming every timed wire was decoded.

The Brotli tool previously passed explicit HQ options only to timing, while
the initial wire and its recorded hash were generated without HQ. It now
uses one option constructor for both phases and records the requested window
and HQ-enabled flag. Reference and Vort numeric-quality rounds both perform
one untimed encode before the timer; the raw report declares that policy.
Historical Brotli/Zstd CSV minima remain legacy fields: new comparisons must
use their complete raw samples rather than those minima.

The Deflate build registration moved from the large root build script to
`build/deflate_encode_bench.zig`. All three allocating tools now have explicit
build-only install steps, so compiling and loading are separate from sampling.
Deflate offers matching header/library paths for both zlib and libdeflate.
Declaration translation does not perform linker discovery; the executable
owns foreign library linkage, including explicit GNU-target search paths.

## Validation

- Deflate sample tests pass **5/5**, covering all permutations, raw chronology,
  non-minimum medians, warmup exclusion, invalid counts and wrapping length
  mixes. The complete allocating probe builds against pinned libdeflate 1.26
  and system zlib 1.2.11.
- Brotli reference-parameter tests pass **13/13** and their existing Python
  gates pass. The new case preserves explicit HQ and window controls through
  primary option construction.
- Deflate integration smoke checks cold state, median CSV values, retained
  warmups and refusal of a five-round run. Zstd and a bounded Brotli HQ smoke
  pass the existing raw sample validator with explicit modern references.
- The bounded HQ smoke uses 64 bytes, one parser iteration, beam width one,
  depth two and nice length four. A preceding 2,048-byte HQ smoke with two
  parser iterations exceeded the harness's 120-second process deadline. It
  produced no completed measurement row and is not counted as a codec error
  or throughput result; explicit HQ runtime remains a performance concern.
- Changed Zig files pass format checks; the shared encoder evidence validator
  passes **9/9** tests. No production codec implementation is changed.

This increment repairs measurement contracts. It does not establish an
encoding speedup, matched-quality frontier, prepared/streaming comparison,
or competitor memory advantage. References remain pinned separately, with
runtime library identity distinguished from header version or requested path.

## Build and exercise

```sh
zig build -j2 --prefix "$scratch/install" -Dtarget=x86_64-linux-gnu \
  -Dcpu=skylake+pku+sgx -Doptimize=ReleaseFast \
  -Ddeflate-reference-dir="$libdeflate_dir" \
  -Ddeflate-reference-include="$libdeflate_include" \
  -Ddeflate-zlib-dir="$zlib_dir" -Ddeflate-zlib-include="$zlib_include" \
  build-deflate-encode-bench build-zstd-encode-bench build-br-planned-encode-bench \
  test-deflate-encode-evidence test-br-reference-parameters
"$scratch/install/bin/vort-deflate-encode-bench" --input "$input" \
  --level 9 --libdeflate-level 12 --iterations 1 --rounds 6 --warmup 6 \
  --csv "$scratch/deflate.csv" --samples-json "$scratch/deflate.json"
```

For current numeric Brotli qualities, explicitly match the actual window
(`--window-bits=16 --reference-lgwin=16`). The command-state override of eight
KiB is valid for q10/q11; q8 retains the quality schedule's sentinel default.
Only recorded `parameters_match=true` supports the quality/mode/window match.
