# Same-harness q8 source regression, 2026-11-25

Current q8 requires **3.8338x the elapsed time** of the exact historical source across the fixed twelve-row 64KiB matrix; the descriptive 95% paired round-block interval is **3.8176–3.8523x**. Encoded-size geometric mean is **0.95658x**, or **4.34% smaller**. Every row is slower. This is a development-host observation with the original collector active on CPU15, not a quiet-host acceptance result or an industry ranking.

## Source and API identity

- Exact historical source: `0a673757ea6a1e88b90794ad44dce1a8a824f371`.
- Current source: `c2c8f250302ca2f223740076482dd95b1788eeb1`.
- Both clean detached checkouts were rebuilt with one common Zig 0.16.0 ReleaseFast probe, target `x86_64-linux-gnu`, CPU features `skylake+pku+sgx`. Each tree links its own `record_optimal_object` object; no production source or API was adapted to make the older tree build.
- Both call public `encodePlannedStreamWithOptionsAlloc` with quality8, generic mode and **explicit window16**, using `std.process.Init.gpa`. Timed codec processes are pinned to **CPU2**, one codec thread, on an Intel Core i7-10700K host.
- This evidence publication changes no main-source quality policy.

The exact old source identity is supported by the separate [historical source audit](../../performance-history-audit-20261125/source/old-q8/git-bindings.json), which binds the archived source-final contents to that Git revision. The old source archive is retained in that package and is not duplicated here. Both new builds and their original clean-source identity checks are retained in `raw.tar.gz`; `source-identity.json` exposes the same receipt for review. Offline packaging verification does **not** rebuild either source or rerun Git.

The intermediate pre-feedback `7ef1c609...` and feedback-enabled `cf4e870c...` revisions were not built or sampled here. They remain possible future controls for attributing the mechanism. In particular, the pre-feedback snapshot is not the exact historical binary/source. This comparison uses the exact older source above rebuilt with the common probe, not the original historical benchmark ELF.

## Matched lifecycle and output checks

Each measured process reads and hashes its input and captures provenance outside timing, then performs exactly one symmetric allocating encode/free warmup. Its timed iteration encloses **encode + wire-length mix + owned free in one continuous interval**. No SHA, copy, JSON, fixture I/O or cross-library decode occurs between encode and free. There is one timed call per process; the shortest recorded call is 23.10ms, so all variants/rows keep the same iteration count.

Complete SHA256 and pinned libbrotli1.2.0 decode checks apply to **initial wires only**. Before any timed sample, all 24 complete initial wires (two sources x twelve fixtures) decoded exactly. Every later process initial-wire hash matches this preflight. Timed output bytes are checked by **length/mix only**, not full SHA256; the scope is explicitly `initial_wire_only`. Decoder/common binary identities and the Brotli LICENSE are in the raw archive. Their hashes match the historical reference-loader closure. The offline verifier hashes these retained binaries and validates the original decode assertions without loading or executing a codec.

The old explicit16 source exactly reproduces the supplied three historical complete golden wires:

| Input | Historical/old bytes | SHA256 |
|---|---:|---|
| Dickens | 24,723 | `2d5a260a0e470c49372ad983dc6ef7ffb5a50658a16a2839e1dddc83381d9342` |
| NCI | 4,390 | `fc61d8a4ab072fddd1c345f5ceaa2f66c2416b7d39f6e3351d85d52b01f38a87` |
| Mozilla | 14,216 | `0edaa9cf782d41223ce9cca5f4811d94e2bcfe58185ab88a513d297b210f6209` |

Historical invocation requested a null/default window while producing wire16. This primary comparison normalizes both sides to explicit16; the three exact golden matches demonstrate wire reproduction under that policy, not identical historical invocation settings or reproduction of historical timing. No default-window lane was added.

## Fixed-row paired results

The twelve primary inputs each receive **six alternating AB/BA pairs**, with three pairs per order. Dickens, Mozilla and NCI receive a second balanced six-pair group, for **twelve pairs** each. There are **90 pairs / 180 timed calls** in total. The main twelve-row number uses **only the first six rounds for every row**; weak-row additions do not alter that matrix weighting.

| Input | Pairs | Old bytes | Current bytes | Old median ms/call | Current median ms/call | Paired current/old elapsed | 95% CI |
|---|---:|---:|---:|---:|---:|---:|---|
| dickens | 12 | 24,723 | 22,367 | 33.171 | 117.616 | 3.5556x | 3.5151–3.5925x |
| mozilla | 12 | 14,216 | 13,924 | 36.975 | 168.848 | 4.5986x | 4.5424–4.6435x |
| mr | 6 | 15,482 | 15,438 | 43.661 | 187.552 | 4.3104x | 4.2708–4.3665x |
| nci | 12 | 4,390 | 4,206 | 25.089 | 95.965 | 3.8170x | 3.8014–3.8336x |
| ooffice | 6 | 30,895 | 30,682 | 46.939 | 165.884 | 3.5385x | 3.5272–3.5498x |
| osdb | 6 | 25,634 | 25,418 | 40.179 | 155.297 | 3.8649x | 3.7739–3.9361x |
| reymont | 6 | 17,484 | 17,128 | 31.762 | 109.444 | 3.4689x | 3.4118–3.5504x |
| samba | 6 | 21,033 | 18,744 | 31.489 | 115.275 | 3.6734x | 3.6437–3.7030x |
| sao | 6 | 47,226 | 46,709 | 50.129 | 186.610 | 3.7688x | 3.7124–3.8222x |
| webster | 6 | 21,623 | 19,555 | 30.805 | 110.859 | 3.5974x | 3.5792–3.6152x |
| x-ray | 6 | 42,611 | 41,180 | 42.289 | 160.474 | 3.8063x | 3.7826–3.8422x |
| xml | 6 | 4,723 | 4,407 | 23.289 | 98.241 | 4.2120x | 4.1869–4.2313x |

Ratios above one mean current is slower. Paired ratios are geometric means of matched per-round elapsed ratios, rather than ratios of separate medians. Intervals use 20,000 deterministic percentile-bootstrap draws stratified by AB/BA order. For the **fixed twelve-row matrix**, the reducer resamples common paired primary-round blocks and does not resample corpus rows. Per-row weak-input intervals use their twelve recorded pairs. These are descriptive development-host intervals, with concurrent CPU15 activity and a small number of temporal blocks; they are not a corpus-population guarantee or an acceptance gate.

These same-harness numbers must not be mixed with the separate cross-epoch audit result. The large source regression is established under the normalized API here; attributing it to a particular intervening feedback commit requires the subsequent control comparison.

## Input identities

All twelve source/process pairs use the corresponding same 65,536-byte fixture, frozen from `/tmp/vort-current-decode-matrix-20261111/fixtures`. Exact input bytes, including original whitespace and line endings, are compressed in `raw.tar.gz` and never normalized.

| Input | SHA256 |
|---|---|
| dickens | `134ad989a7b8b40c900a3b9c0f4895317dfd827d9e6e933895b08d2f4a8a8293` |
| mozilla | `b0050240663f54371d372303eeaba0a59ab0758bcd565f4f639d06561e6bc996` |
| mr | `cab7b6408934009a4bbfedb57beb4943bf5478cf8b3688d01f004e0422ebc651` |
| nci | `b01b411ac3b5ce2fbf37242c0c59d2d236d2f7039937c1b1a0f18f4cc02549fe` |
| ooffice | `9d30521922187d0a26f56cf2df85001f9585d0d4ec6a0a8797466afcc367f825` |
| osdb | `f8fe629325a07588118ba0b65880a87ded43ef249ccbc91f0e977bbacae0c125` |
| reymont | `a5ecaaabb133f1adf8de6062be6381d143e87f9f8050eea9b5be6f92b88c3c22` |
| samba | `3e0420984c0f260ea7350734600cea9d8500b745e2e4b7dbd4d1da1d1adac421` |
| sao | `17cbd7166a47786139f60ba33b4e771ce0154f6fa56986883d129bc23f78ebee` |
| webster | `262258811321382f9e4f44d2184b6b7fed0336cf831446d8336c47d6ccc2b32e` |
| x-ray | `b5a07146616bcd7c2d10071d41e07d204de0ac629c4ca37d8e867ff00574d0d8` |
| xml | `e32aff2bebf00105a17dd57f5490c1986d17543cee837b42eb56b3e0e6f8e7f1` |

## Retained artifacts and offline verification

| Root artifact | Contents |
|---|---|
| `raw.tar.gz` | Exact raw process JSON, argv/exit metadata, stdout/stderr, all fixtures and complete initial wires; common probe/provenance/build/run/analyze scripts; both final ELF gzip members and record objects; original build/source/decoder receipts; decoder/common binaries and Brotli LICENSE; superseded build logs and explicit unsampled scope. |
| `archive-bindings.json` | Exact tar membership and every member byte length/SHA256, original origins, and uncompressed final ELF identities. |
| `source-identity.json` | Original successful clean-source/Git-tree, common probe/provenance, record-object and final ELF identity receipt. This is retained build evidence, not a packaging-time rebuild. |
| `summary.json`, `raw-pairs.csv` | Full source sizes, per-call medians, all raw ns pairs, ratios and descriptive CI. CSV uses LF. |
| `verify.py`, `verification-receipt.json`, `SHA256SUMS` | Portable offline verifier, its result, and complete published-file inventory. |

The two final ELF identities are:

- old: `b216632c3b3a7925790a5210313c795ece992310686d330abc2f3bb755ea5cda`;
- current: `f634b02f8e63bf497c5eb3dcd17acbc791b2db46b5a6d534d73ef0ca3a047df5`.

Source worktrees, compiler caches, and superseded unsampled ELF files are excluded. The earlier segmented-timer probes compiled successfully but were never sampled; their logs, metadata, discarded probe source and scope are retained only to explain why the final common probe was rebuilt with continuous encode/free timing. No superseded timing contributes to these results.

From any directory, with this package copied to any location:

```sh
python3 /path/to/q8-source-regression-20261125/verify.py
```

The verifier checks the complete published inventory and all original tar member bytes, both final ELF and record-object identities, common probe/provenance hashes, pinned decoder/common identity and LICENSE, every fixture/initial-wire SHA, original source/build receipts, all process source/options/CPU bindings, AB/BA order, exact primary/weak round coverage, and timed length/mix. It then replays the archived pure-Python reducer against retained raw nanoseconds, recomputing **12 rows x 6 primary rounds**, all three **12-pair weak rows**, medians, ratios, bootstrap CI and the LF raw-pair ledger.

No original ELF, codec, Zig compiler, Git command or original `/tmp` path is used by this verifier. Original absolute paths stay intact inside raw evidence; only temporary local copies of statistical input files are used. Original cross-library decode checks and clean-source rebuild checks are audited as retained assertions. Floating statistical outputs allow a 1e-12 comparison tolerance; integer raw nanoseconds and all byte identities are exact.
