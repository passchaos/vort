# Frozen Reymont level-6 public Deflate profile

This package preserves the completed profile at
`8adfb3bae74409bae146fed2ed9b6594a1d3cdb8`, before the new public-linear
test hooks. Its 2,062 source hashes are byte-equivalent to the reused main
baseline, and the exact executable SHA remains
`2527c72112f19ac34d08d8f199f38e76dc4a9883ad25466f2f83ff193da21f14`.
Later test/documentation commits do not replace this epoch.

The captured workload is the frozen **Reymont 64 KiB raw Deflate level-6
wire**, cold `decodeRawDeflate` against libdeflate 1.26. Each batch performs
30,000 decodes per side, with two warmup and two measured paired batches.
Both sides use CPU 15 and one thread on the i7-10700K. Vort was built with
Zig 0.16.0 ReleaseFast for x86_64 Linux GNU, `skylake+pku+sgx`. Reference
libdeflate 1.26 used the recorded GCC 11.4 build with
`-O3 -DNDEBUG -march=skylake`; the full manifest preserves that provenance.
Source/input/probe/reference hashes,
complete output, count, exact consumed input, 64-byte alignment/guards and
input immutability were checked by the original capture.

Perf used `cycles:u`, frequency **199 Hz**, and `dwarf,65528`. The original
recording is **175,713,164 bytes**, and perf reported **2,681 samples**. The
successful physical-symbol report has period **65,407,305,645** and zero
reported lost samples. The recording includes both implementations, startup,
warmups, measured work, output initialization and post-batch validation.

The physical report assigns **58.02% of whole-process sampled period** to
`deflate.semantic.linear_entry.aligned` and **36.53%** to the reference
`deflate_decompress_bmi2`. These are physical symbol self percentages, not
Vort-only total time or instruction fractions. The capture does not provide
a complete public-root denominator or codec-only heap measurement. Profile
clocks are excluded from every candidate A/B acceptance result.

## Exact artifacts and reused identity

| File | Contents |
| --- | --- |
| `raw-profile.tar.gz` | All 12 original retained profile files: perf.data, successful physical report/empty stderr, cached 7/7 build log, capture runner, manifest/command/execution, raw probe stdout/stderr, capture log and validation. |
| `fixture-bytes.tar.gz` | Exact 65,536-byte plain and 18,792-byte producer wire: 84,328 retained bytes. |
| `runner-dependencies.tar.gz` | Exact imported evidence/fixtures modules and original Sao profile seed manifest. |
| `capture-validation.json` | Exact readable copy of the successful original capture receipt. |
| `archive-bindings.json`, `verify.py`, `validation-receipt.json`, `SHA256SUMS` | Member hashes/origins, independent offline verification, receipt, and complete checksum inventory. |

The reused baseline source and binary come from the existing
`br/decode-mozilla-distributions-20261112` package. The exact reference shared
library comes from `modern-decode-current-20261111/reference-libraries.tar.gz`,
SHA-256 `1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28`.
No large duplicate baseline source or executable is stored here.

Archives use sorted GNU tar regular files, uid/gid/mtime zero, empty owner
names and gzip level 9 with empty filename/mtime zero. The original bytes,
including log whitespace and EOF, are preserved. The cached build observation
is retained; the package does not claim a different rebuilt binary identity.

## Offline verification

Packaging and archive verification use **CPU 0**, separately from performance
work on CPU 15. From this directory:

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

The standard-library verifier reconstructs the frozen baseline source from
the reused archive, checks all source/probe/reference and fixture hashes,
raw JSON/command/exit/validation bindings, full captured pair statistics,
perf file identity, sample/report totals and whole-process scope. Optional
checks compare every retained original byte and base Git blob. It does not
compile, decompress, resample, or run a benchmark.

For later reproduction, restore the original fixture bytes and exact baseline
binary in a separate directory, then use archived `capture.py` and its
dependencies. Absolute paths name the recorded checkout; alter only a derived
runner copy and create a new capture epoch. Preserve its own raw stdout,
stderr, source hashes, command, host observations and validation receipt.
