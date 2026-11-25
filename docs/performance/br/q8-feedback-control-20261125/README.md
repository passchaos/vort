# q8 feedback control and negative reuse diagnostics, 2026-11-25

Enabling q8 entropy feedback requires **2.081300x** the feedback-off elapsed time on the fixed twelve-row 64KiB primary matrix, with descriptive paired round-block 95% CI **[2.076217, 2.086900]**. Encoded-size geometric mean is **0.984679x** (about **1.53% smaller**). Separate untimed diagnostics find **zero exact model-price or command reuse hits** across the same twelve inputs. These are mechanism/development-host observations, not a product optimization or acceptance/ranking result.

## Ordinary allocating control

The logical base is `e41aa51cc9e6df8f039187435a65c93371d717d6`. All **2,217** codec source/build blob entries under `src`, `build`, `build.zig` and `build.zig.zon` match `c2c8f250302ca2f223740076482dd95b1788eeb1` exactly; both complete blob listings and a read-only archive-time recheck are retained. This permits reuse of the c2c8 feedback-on ELF while keeping its **original binary source CID**. Only the off variant was rebuilt.

The isolated, uncommitted overlay changes one production value: `base_rows[q8].optimal.entropy_feedback` true to false. q9 remains true and every other source byte is unchanged. This is a control to isolate cost; it is not a proposal to turn off main policy. Eight rows produce larger outputs with feedback off.

Both sides use the same verified common probe/provenance, Zig0.16.0 ReleaseFast, GNU `x86_64-linux-gnu`, target `skylake+pku+sgx`, CPU2, one codec thread, public `encodePlannedStreamWithOptionsAlloc({quality=8,mode=generic,window_bits=16})`, and `std.process.Init.gpa`. Each process performs one symmetric warmup, then one timed allocating call. The timer is continuous through **encode + length mix + owned free**; no SHA or decode is inserted between encode and free.

The fixed twelve-row primary matrix has six alternating AB/BA pairs per row. Dickens, Mozilla and NCI receive an additional balanced six pairs each, for twelve pairs on those rows. All **90 pairs / 180 timed calls** are retained. The matrix aggregate uses only the primary six rounds for every row, so the weak-row additions do not change corpus weighting. Paired ratios are geometric means of matched raw elapsed ratios; intervals use 20,000 deterministic draws stratified by order and common primary-round blocks for the fixed matrix, rather than resampling corpus rows.

| Input | pairs | Off bytes | On bytes | Off median ms | On median ms | paired on/off time | 95% CI |
|---|---:|---:|---:|---:|---:|---:|---|
| dickens | 12 | 22,766 | 22,367 | 66.261 | 118.611 | 1.8355x | 1.7896–1.9160x |
| mozilla | 12 | 13,924 | 13,924 | 93.340 | 171.262 | 1.8398x | 1.8188–1.8578x |
| mr | 6 | 15,494 | 15,438 | 88.742 | 189.812 | 2.1377x | 2.1311–2.1449x |
| nci | 12 | 4,388 | 4,206 | 30.906 | 97.447 | 3.1683x | 3.1526–3.1900x |
| ooffice | 6 | 30,682 | 30,682 | 81.961 | 168.060 | 2.0551x | 2.0335–2.0758x |
| osdb | 6 | 25,602 | 25,418 | 85.057 | 154.189 | 1.8024x | 1.7914–1.8128x |
| reymont | 6 | 17,477 | 17,128 | 44.479 | 108.629 | 2.4998x | 2.4421–2.6118x |
| samba | 6 | 18,973 | 18,744 | 61.997 | 115.395 | 1.8622x | 1.8562–1.8668x |
| sao | 6 | 46,709 | 46,709 | 115.854 | 187.636 | 1.6248x | 1.5985–1.6543x |
| webster | 6 | 19,858 | 19,555 | 59.538 | 112.916 | 1.9026x | 1.8959–1.9088x |
| x-ray | 6 | 41,180 | 41,180 | 92.076 | 162.294 | 1.7591x | 1.7440–1.7744x |
| xml | 6 | 4,711 | 4,407 | 31.597 | 99.294 | 3.1486x | 3.1375–3.1643x |

Mozilla, ooffice, sao and x-ray retain identical complete on/off wire hashes. The other eight rows have smaller feedback-on outputs. All 24 complete initial wires were exactly decoded through the pinned libbrotli1.2.0 decoder/common closure before sampling; every later process initial hash matches preflight. Timed output checks are length/mix only: **initial_wire_only** complete-hash scope. Every input byte and initial wire is compressed as original data and is never newline-normalized.

The original full-file collector and a concurrent Zig compilation appear in all **90 / 90** pre-pair snapshots. One-minute load ranges **1.65–2.55**. Full-file Brotli and Deflate activity each appears in 27 snapshots as the preserved collector moves between rows. The final Dickens on call, 154.184ms, is retained; no outlier was discarded. These snapshots are observations, not continuous telemetry or proof assigning an individual outlier to a particular process.

## Negative exact-model/command evidence

The equality diagnostic runs one initial encode per row, with **iterations=0 and no ordinary timing samples**. Each of twelve stderr files has five complete `FEEDBACK_EVIDENCE` records, covering three modeled passes and their comparisons. Across rows:

- **36 direct exact model-price comparisons**, zero matches. The retained source compares actual literal, literal-context, length and distance price values.
- **60 direct command-field comparisons**, zero matches, including fixed/seed comparisons.
- **12 second/bonus fingerprint routing checks**, all different. Different deterministic fingerprints reject equality; a matching fingerprint alone would still require an exact comparison. It is never treated as a reuse authorization.

Thus the observed model/command identity shortcut has no hit in this corpus. The retained comparator helper is read-only and stateless; its caller must still hold immutable input, invocation geometry, successful modeled parsing and immutable dictionary/provider backing. Pointer/callback identity by itself does not establish immutable backing. Fixed-cost and modeled parsers are not interchangeable reuse surfaces.

The standalone helper was actually run with `zig test ... -OReleaseSafe --test-filter "feedback reuse"` and passed **12/12**, with seven named behavior contracts. `helper-validation.json` retains the parent tool-observed command, exit0, counts and all three helper source SHA256 values. Original stdout was not separately saved as a file. This archive audits that retained receipt; it does not rerun the tests. The helper/tests/gate source files remain diagnostic evidence and are not connected to production by this publication.

## Negative modeled-search work evidence

The search diagnostic also has **iterations=0 / samples=[]**, with four stderr `SEARCH_PROFILE` records per row: `fixed_seed`, `modeled_seed`, `modeled_second`, `repcode_bonus`. It calls profiled parser APIs; its nanoseconds are **not ordinary encoder timing** and must not be inserted into the control A/B.

For every row, the three modeled passes have identical values for all ten retained work fields: input length, index bytes, positions, chain nodes, match calls, valid matches, length choices, prefix rejections, bound rejections and budget stops. That repeated aggregate work does not establish equal price models, command streams or every candidate coordinate.

NCI has **3,251,387 match calls per modeled pass**, or **9,754,161 across the three modeled passes** in one initial diagnostic encode. These are three parser passes, not three benchmark rounds. Its modeled index time sums to **690,933ns** out of **62,840,571ns**, giving **1.0995%**, about **1.1%**. This denominator is NCI modeled passes only.

Across all twelve rows and all four profiled passes, summed index time is **14,883,327ns / 497,342,396ns = 2.9926%**. That is an aggregate of instrumented parser-phase time, not whole-encoder elapsed time. Both per-row denominators are retained in `diagnostic-counters.csv`; the 1.1% observation is not generalized to the matrix.

| Input | Modeled match calls, three passes | Modeled index share | All four pass index share |
|---|---:|---:|---:|
| dickens | 2,263,029 | 3.8027% | 4.8808% |
| mozilla | 3,085,773 | 2.5170% | 2.4947% |
| mr | 8,396,592 | 1.0060% | 1.3243% |
| nci | 9,754,161 | 1.0995% | 1.0410% |
| ooffice | 1,512,528 | 5.3372% | 7.5393% |
| osdb | 910,365 | 5.2333% | 4.9135% |
| reymont | 5,039,982 | 1.8284% | 2.4895% |
| samba | 2,906,619 | 3.0872% | 4.0104% |
| sao | 914,787 | 7.9860% | 7.9404% |
| webster | 2,765,007 | 3.2254% | 4.2195% |
| x-ray | 43,047 | 13.0124% | 18.4715% |
| xml | 8,191,191 | 0.9102% | 0.9608% |

These negatives reject exact cached-result reuse for the observed model/command keys and show that index-only reuse cannot address most NCI modeled work. They motivate keeping separate models/DP states while testing a bounded shared raw-match scan. They do not establish that the new dual-model solver is correct, fast, memory-bounded or mergeable; that requires its own wire/reference/resource and ordinary end-to-end evidence. No 16MiB saved frontier or production change is claimed here.

## Source and coverage boundaries

Both diagnostic ELF hashes are checked against every original process JSON, and all 24 diagnostic wires are compared byte-for-byte with the current feedback-on initial wires. The equality source is retained as the supplied `br-equality-source.zig.gz`. Search `source.zig.gz` and `source-sha256.json` were saved after the diagnostics and before restoring br.zig; their exact snapshot and ELF identities are verified. The snapshot is archival source evidence, not a new build or a claim of complete byte-reproducible compiler inputs. No changing worktree file is substituted for these frozen snapshots.

Search diagnostic wrappers use `std.Io.Threaded.global_single_threaded.io()` only in the temporary profile overlay. This global IO is not a production architecture addition. The diagnostic binary is not an ordinary encoder benchmark binary.

Auxiliary context-detail storage is independently capped at eight records. `context_details_truncated` is separate from event truncation and wire-attempt coverage. A detail prefix cannot be reported as complete context-search statistics. These search/equality reports contain no full auxiliary context-detail report; no completeness claim is inferred from raw search counts. The e41 `quality_profile` source and an explicit scope note are retained as separate constraints.

## Compressed members and offline verification

| Root artifact | Purpose |
|---|---|
| `control.tar.gz` | Exact original control evidence archive, including all raw process/metadata/ns, inputs, initial wires, on/off ELFs, off object, before/after schedule, source/build/equivalence receipts, common probe/provenance/build/run/analyze/verify, pinned decoder/common and Brotli LICENSE. |
| `diagnostics.tar.gz` | Both complete twelve-row diagnostic directories, original stdout/stderr/JSON/wires, frozen source gzip and helper receipt, helper/tests/gate sources, diagnostic ELF gzip/build metadata, both independent codec blob listings and context-detail constraints. |
| `archive-bindings.json` | Outer archive hashes and exact original diagnostic member byte bindings; control internal member bindings are verified too. |
| `summary.json`, `raw-pairs.csv`, `diagnostic-counters.csv` | Complete control results plus negative/host reductions; derived CSV uses LF. |
| `negative.py`, `verify.py`, `verification-receipt.json`, `SHA256SUMS` | Pure offline relationship/statistics checks, receipt and full published inventory. |

```sh
python3 /path/to/q8-feedback-control-20261125/verify.py
```

The package can be copied anywhere. Verification checks every compressed original member, the c2/e41 2,217-entry equality, the exact q8-only flag and q9 true, baseline/probe/ELF/object/input/initial-wire identities, all pair counts/order/mix, host observations, recorded helper tests/source identities, every stderr/summary event, zero equality/routing hits and per-row raw-counter vector equality. It replays the archived pure-Python paired reducer to regenerate the primary 12x6 matrix and all three twelve-pair weak rows. No original `/tmp` path, Git, compiler, codec, ELF or test execution is required. Original source-build/decode/test runs are verified as retained receipts, not rerun during archival checks.
