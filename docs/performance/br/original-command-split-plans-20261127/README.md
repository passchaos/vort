# Original-command split-plan evidence package

Root accepted this slice at source commit
`11effbb7f1344897736a9de50b0f65f9c0d77b20`, using the gate fixed before sampling.
Root has pushed implementation commit `11effbb7` to main successfully.
This evidence package awaits its separate docs commit/push.
The library goal remains active. This is not industry best, and the historical
regression is not fixed. Raw independent receipts remain unchanged; they verify
recorded data and do not themselves authorize adoption.

The semantic baseline remains `742f4663d914cd2814f2c1267572a00e7b18bfbf`.
The sampled candidate snapshot retains manifest SHA256
`371b18cb02745c41f357adcda35fcbafb0b98530233e9e23e4b190d2372c6cc2`.
The accepted commit identifies the saved implementation; it does not relabel the
older frozen source epoch or alter any original source/hash/build receipt.

| Recorded scope | Result |
| --- | --- |
| Formal all-row GM | 1.0312916722332623, CI [1.0297344815763332, 1.0327249356711294] |
| Predeclared secondary primary-six GM | 1.0292433572443302; below 1.03, disclosed without changing the gate |
| 15 control rows | Every point floor passes; min small XML 0.9951913215955942, CI lower 0.9831635967699703 |
| Historical fixed-parameter comparison | Candidate elapsed 3.0917714010799577x, wire ratio 0.9565808633658663 |
| libbrotli 1.2.0 fixed-parameter comparison | Candidate elapsed 59.710103763936324x, wire ratio 0.9438865172371007 |
| Independent followups | 270 pairs, 540 processes, 15,984 calls; all record/replay matches |
| Actual whole-library gate | Exit 0, 414/414 steps; 6085/6087 tests with two skipped; source unchanged |

History and reference rows use fixed source/corpus/requested parameters and a
matched owning lifecycle. They do not define an industry ranking or a matched
quality frontier. All requested samples remain included, including the high MR
round; no sample is removed to strengthen acceptance.

The package retains Owner final Native/WASI 10/10 and original compile failures,
Choice final Native/WASI 12/12 and earlier source versions/failures, public
Native/WASI 35/35 and complete 681/688 OOM sweeps plus retries, Root's initial
missing joint-test-file compile failure, parameter-pair Native-only 27/27, joint
Native/WASI 31/31, successful whole-gate output and its three live diagnostics,
and the complete pilot/formal/control/history/reference epochs. A failed-command
warning in whole-gate stderr is not substituted for the actual terminal exit.

The three live Debug perf diagnostics show test progression only. They are not
benchmark or ROI evidence, and they cannot establish that preceding tests passed.
The final current whole-test ELF is bound by its recorded diagnostic SHA. The
original standalone Owner Native ELF was not explicitly retained; final whole-test
coverage does not invent an old standalone binary hash. No archival codec/build
or new diagnostic/timing run is performed.

Every source epoch remains distinct. Public SOURCE and the final candidate have
only `src/br.zig` different in the recorded manifests; the retained source diff
and deferred token audit show joint/Choice test declaration imports. They are
not byte-identical full trees. Owner and Choice snapshots, old comparator sources
and the accepted commit retain their separate scopes. Selected whole-gate source
hashes match the final candidate but are not silently upgraded to a complete
original whole-gate snapshot.

`archive-release.json` records Root's explicit final release after all timing
windows closed. `primary-verdict.json` records accepted=true, goal_active=true,
industry_leadership=false and the limitations above. Collection and compression
are data-only. Full source, ELF/object, initial wires/raw records, reference libs,
verifiers and all failed attempts are copied without rewriting original receipts.

The portable payload manifest maps original absolute paths to relative package
paths. `scripts/verify.py` verifies an extracted payload from its sealed inline
Root release and archived verdict, without requiring the old `/tmp` directories.
Collection/audit scripts use original-host paths; no compiled probe is rerun by
these tools. `archive-envelope.json` records the final compressed artifact hash.

The complete 185,506,284-byte XZ archive is stored as three <=64MiB parts to avoid
a large single Git blob. `archive-envelope.json` binds their ordered concatenation.
Reconstruct with `python3 scripts/join_archive.py --output /tmp/evidence.tar.xz`,
extract it, then run `python3 data/scripts/verify.py` inside the extracted root.
Both staged and fresh-extracted verification already passed for all 19,127 files.
`portable-seal.json` records the actual exits and final H0 state.
