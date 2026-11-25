# Mainline cold decode hotspots, 2026-11-25

This six-row diagnostic profiles merged main at
`83bb442cad47093f2971df5e84f129ca69210038`. It reuses the frozen Silesia
wires and reference libraries from the [360-row matched refresh](../modern-decode-refresh-20261125/README.md)
but is not a new full matrix, an encoding comparison, or an acceptance run.
No production codec code changed.

## Ordinary cold timing and Vort-only counters

| Frozen Silesia row | Plain bytes | Wire bytes | Vort / ref MiB/s (batch medians) | Paired speed ratio | Vort cycles/B | Vort instructions/B | Vort branches/B | Vort branch misses/KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Deflate `mr` 64 KiB L9 | 65,536 | 17,092 | 991.06 / 1,632.17 | **0.6075×** | 4.59 | 12.04 | 1.90 | 58.25 |
| Deflate `mr` 64 KiB L6 | 65,536 | 17,155 | 954.01 / 1,497.44 | 0.6375× | 4.79 | 12.15 | 1.97 | 59.87 |
| Deflate `mr` 1 MiB L9 | 1,048,576 | 346,400 | 858.44 / 1,317.21 | 0.6513× | 5.20 | 13.95 | 2.17 | 60.07 |
| Brotli `mozilla` full q11 | 51,220,480 | 14,077,215 | 183.26 / 375.04 | **0.4861×** | 25.31 | 62.43 | 9.33 | 201.54 |
| Brotli `mozilla` 1 MiB q11 | 1,048,576 | 635,440 | 278.56 / 268.03 | 1.0410× | 16.59 | 39.41 | 5.86 | 54.78 |
| Brotli `mozilla` full q6 | 51,220,480 | 16,289,474 | 273.30 / 450.28 | 0.6033× | 16.97 | 40.01 | 6.94 | 171.71 |

- The Vort APIs are `decodeRawDeflate` and `brDecodeStreamInto`. References
  are libdeflate 1.26 (`alloc_decompressor` → `deflate_decompress_ex` →
  `free_decompressor`) and libbrotli 1.2.0 (`BrotliDecoderDecompress`). Each
  pair uses the same frozen wire and caller-supplied output buffers. Codec
  state creation inside the selected API is timed; loading, file I/O, caller
  buffer allocation and complete output/guard verification are outside the
  timed batches. The probe also checks exact consumed bytes for raw Deflate;
  the selected Brotli reference API does not expose them.
- Ordinary timing and each counter group are separate process runs: two warmup
  and six measured balanced AB/BA pairs per row, with 100/20/1 iterations
  per batch at 64 KiB/1 MiB/full size. The paired speed ratio is the geometric
  mean of `reference_ns / vort_ns` over the six ordinary pairs, not the ratio
  of the two batch medians. The two PMU groups (`cycles`, `instructions` and
  either `branches` or `branch-misses`) count only Vort batches. Values are
  medians normalized by decoded bytes; cycles and instructions in the table
  come from the `branches` group.
- Intel i7-10700K, Linux 6.8.0-79-generic/glibc 2.35, single-threaded children
  pinned to logical CPU 15 (SMT sibling 7); collector affinity 0,15.
  `intel_pstate` used the `powersave` governor with turbo enabled. Zig 0.16.0,
  `ReleaseFast`, `x86_64-linux-gnu`, `skylake+pku+sgx`. Both references were
  built with GCC 11.4.0, `-O3 -march=skylake`; their revisions, flags, hashes
  and actual loaded library closures are preserved in the raw reports. The
  host was not dedicated. There is no isolated per-codec peak-memory
  measurement and no attribution of performance changes across revisions.

## Where to optimize next

**Deflate: prioritize the shared semantic loop, not construction.**
`deflate.semantic.linear_entry.aligned` accounts for 54.36%, 54.47%, and
55.87% of the paired child’s period-weighted self samples in the three rows.
The literal and distance table builders together account for 2.03% on
`mr` 64 KiB L9. Its instruction annotation places the largest individual
weights near the refill threshold, the second-entry literal test, and
alignment of the match bits. Profile a change to the common refill and
literal-to-match handoff before screening further preparation-only changes.
Keep the bounded tail, exact input consumption and existing copy contracts as
controls; the sampled instruction offsets are leads, not causal attribution.

**Brotli: isolate packed distance tree expansion and reuse.** In full-file
`mozilla` q11, the wide external-literal executor accounts for 21.37% of the
paired child’s self period; `distancePrefixForDecode` and
`readMinimalDistance` account for another 9.45% and 7.35%, respectively. The
selector annotation shows samples in the packed expansion’s active-symbol
scan and canonical construction, not only at the tree bounds check. Full q6
has 1.18% in `distancePrefixForDecode`, and the 1 MiB q11 control instead puts
45.69% in the non-wide external-literal executor. The separate logical Brotli
probe confirms the difference in work shape:

| `mozilla` row | Commands/KiB | Prepared distance hits | Long fallbacks | Prepared distance builds | Max postfix bits |
| --- | ---: | ---: | ---: | ---: | ---: |
| Full q11 | 75.39 | 2,053,460 | 96,671 | 48,829 | 3 |
| 1 MiB q11 | 19.82 | 13,959 | 1,141 | 22 | 2 |
| Full q6 | 69.08 | 2,374,718 | 20,184 | 1,642 | 0 |

Prepared builds are diagnostic counters, not a direct count of packed-tree
expansions. First count resolutions and expansions by distance block type,
context and tree ID. Then screen bounded reuse of resolved trees for the
active block type and its four contexts. Different tree IDs can interleave
within one block type, and the current shared packed slot can be overwritten:
never cache a pointer across an overwrite. Use full q6 and 1 MiB q11 as
controls; retain parity for block switches, short/truncated input, and long
and implicit distances. This targets the packed path that the
[earlier inline-tree pointer trial](../br/decode-mozilla-profile-20261112.md#interleaved-baselinecandidate-screens)
left uncached, without committing to the earlier all-tree lookup planes.
Apply the whole-operation and fixed-host gates before adopting an optimization.

Symbol samples were collected separately with `perf record -e cycles:u
-F 997`: two paired rounds without warmups, and 10,000/10,000/800/4/128/4
iterations in the table’s row order. Symbol percentages are self samples
weighted by period over the **entire paired child** (Vort, reference,
verification and other sampled userspace); they are not Vort-only timings.
The annotation percentages are local to each annotated symbol. Hardware
sampling can skid. The logical payload counters come from
`vort-br-payload-counts`, not from the timed decoder or the PMU.

## Artifacts and verification

`capture.tar.gz` contains the source/fixture/reference/executable manifest and
commands, the raw timing/counter JSON and logs, all six `perf.data` recordings,
period and symbol/IP listings, two instruction annotations, three payload
reports, and host process snapshots. `build.log.gz` records both ReleaseFast
probe builds. `summary.json` derives from those samples; the reducer validates
probe contracts, unmodified period sequences and payload provenance. Corpus
and wire bytes are not stored in Git. The comparator hash matches the probe
archived by the [matched refresh](../modern-decode-refresh-20261125/README.md#artifacts-and-reproduction);
its source checkout and hash were independently recorded for this collection.

Offline validation, from the repository root:

```sh
epoch="$PWD/docs/performance/decode-hotspots-main-20261125"
(cd "$epoch" && sha256sum -c SHA256SUMS)
scratch=$(mktemp -d)
tar -xzf "$epoch/capture.tar.gz" -C "$scratch"
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$PWD/tools/decode" \
  python3 "$epoch/summarize.py" "$scratch/capture-v2" --verify "$epoch/summary.json"
```

To collect again, first restore the frozen files and reference binaries using
[the matched refresh instructions](../modern-decode-refresh-20261125/README.md#artifacts-and-reproduction).
Use its `prepare.py` from a clean worktree at the revision above, with the
newly built comparator, to generate the relocated `manifest.json` in the
scratch matrix directory. Keep `epoch` pointing to this archive in the newer
checkout, and `scratch` outside the measured worktree:

```sh
# Run in the clean measured worktree; scratch and epoch are absolute paths.
zig build -j3 --prefix "$scratch/install" -Dtarget=x86_64-linux-gnu \
  -Dcpu=skylake+pku+sgx -Doptimize=ReleaseFast \
  build-decode-compare build-br-payload-counts
# After prepare.py creates $scratch/matrix/manifest.json:
PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$PWD/tools/decode" taskset -c 0,15 \
  python3 "$epoch/collect.py" --frozen-manifest "$scratch/matrix/manifest.json" \
  --probe "$scratch/install/bin/vort-decode-compare" \
  --payload-probe "$scratch/install/bin/vort-br-payload-counts" \
  --out-dir "$scratch/capture"
```

Privileged PMU availability depends on the host’s perf policy. See the
archived manifest for the two additional `perf annotate` invocations.
