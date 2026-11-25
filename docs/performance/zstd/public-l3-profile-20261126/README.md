# Public Zstd level 3 profile — original NCI

The public default level 3 run places 72.62% of recorded leaf cycles in four
`controlled_search` functions. This points first to index construction and
match search work. This package preserves an instrumented diagnostic capture;
it is not a throughput gate or an implementation ranking.

The input is the original **33,553,445-byte NCI**, without truncation or
normalization. The captured public API policy is `level_policy`, with a resolved
primary of `greedy`, search budget **24**, `rep_beam_search=false`,
`fast_parser=auto`, and `selection=fast_compressed`. Primary metadata describes
the public preset, not every internal candidate the level policy might try.

The current ELF was built with Zig 0.16.0, ReleaseFast, x86_64-linux-gnu,
`skylake+pku+sgx`. The capture ran on CPU 15 of an Intel Core i7-10700K, with
`perf record --call-graph dwarf`, six alternating rounds and one iteration per
round. The process also includes libzstd reference compression, SHA work, and
cross-validation. Its recorded timings and CSV rates are retained as raw
observations, not interpreted as uninstrumented encoder throughput.

| Function | Leaf share of all captured cycles |
| --- | ---: |
| `controlled_search.matchAt` | 21.84% |
| `controlled_search.planReuse` | 20.43% |
| `controlled_search.findBest` | 17.09% |
| `controlled_search.Index.seed` | 13.26% |
| Four nonoverlapping leaf entries | **72.62%** |
| `compiler_rt.memset` | 6.49% |

`planReuse` self includes inlined helpers and must not be called a pure DP
phase. The denominator is the complete recorded process, including reference
and validation work; these percentages are not normalized to Vort encoding.
`memset` has multiple possible callers, so its complete 6.49% cannot be charged
to index initialization without more stack evidence.

The inclusive observations are `planReuse` **77.27%** and `writeBlockImpl`
**83.93%**. Inclusive entries overlap and cannot be added. The unresolved
`0xffffffffffffffff` root covers **98.94%** inclusively; zero reported lost
samples does not imply complete or correct call-stack coverage. Kernel maps and
vmlinux were unavailable, as the preserved warning logs state.

The next measured investigation should prioritize `Index.seed`, candidate
search/rejection and `matchAt` scanning, while retaining exact output and public
level-policy behavior. This capture does not establish automatic fallback as
the first optimization target.

## Identity and retained evidence

Vort's full-input wire metadata is **3,320,363 bytes**,
`ccf0e89d5c0a295c797553da8e0f72dcd6ec5aefc7805ffd04de6333338b75c0`.
The libzstd 1.6.0 reference is **2,833,843 bytes**,
`183c5f1b703ec2eaac76b4bc8c5c24647b0d5e4725f0cb9f49ccca9f4a228ede`.
These match the historical full-NCI wire observations. Initial wires were
cross-validated by the captured benchmark, but encoded frames were not saved
separately; the offline verifier checks JSON wire/hash observations and does
not independently re-encode or decode them.

An additional 64 KiB smoke retains explicit native `lazy`, budget **41**, and
`fast_compressed` flags. It is a separate `native_frame` API observation, not
the default level-policy capture, and its unpinned CPU affinity is retained.

`raw.tar.gz` contains the complete **201,940,120-byte perf.data**, the exact
10,987,256-byte sampled ELF, exact full and smoke input bytes, the requested
838,400-byte libzstd file, CSV/JSON, command receipts, reliable function-symbol
reports, and the original failed symbolization reports and stderr. The library
file path/SHA is bound; JSON reports `loaded_identity=null` and
`dependencies_verified=false`, so transitive runtime closure verification is
not claimed.

The initial addr2line reports repeatedly failed to read the first record and
were stopped with SIGTERM, exit **143**. The original successful capture was
not repeated. Replacement function reports disable inline expansion and
callgraphs and exited **0**. Their receipts were assembled from observed
terminal exits after completion; original report start timestamps were not
available. All errors, termination receipts and warnings remain in the archive.

Source HEAD is `7b575072ee104d78a3fd2e35b8a979a3af4de390`. The Source snapshot
retains the local literal import/embed closure for the codec and benchmark,
including syntactic test references, plus build metadata. Codec files are
checked against that Git tree. Dirty benchmark metadata helpers and the new
policy tests are retained at their current hashes. These source hashes were
checked before/after **archiving**, not measured before profiling began. The
original capture-time identity manifest binds ELF/input/library only.
Standard-library sources and compiler caches are excluded.

## Portable offline verification

```sh
python3 verify.py --root .
```

Only Python's standard library is required. The verifier reads the gzip tar
without extracting or executing it, checks every object SHA and all logical
bindings, validates input/ELF/library identities and Source snapshots, recomputes
the four-leaf sum, and checks raw JSON/CSV/policy/receipt observations. It never
runs perf, a codec, or an archived argv. Exit 0 prints a stable JSON result;
missing or altered evidence exits 1.

Large identical contents are stored once as `objects/<sha256>` inside the tar.
`archive-bindings.json` maps every logical file to its exact object, byte count,
SHA and original path. `SHA256SUMS` covers README, tar, bindings and verifier.
