# Deferred preferred q8 groups: focused functional evidence, 2026-11-27

This package preserves completed compile and focused functional attempts for the deferred-preferred Brotli experiment. It does not establish broader Brotli acceptance, throughput, RSS, a memory gate, historical performance recovery, or industry leadership.

| Frozen attempt | Original compiler outcome | Original focused execution |
| --- | --- | --- |
| v1 | Exit 1, 4/9 steps succeeded; six compiler errors per affected test artifact | Not run |
| v2 | Exit 0, 9/9 steps succeeded | Native **39/40**, actual WASI **39/40**; both exit 1 (`TestUnexpectedResult`) |
| v3 | Exit 0, 9/9 steps succeeded | Native **39/40**, actual WASI **39/40**; both exit 1 (`InvalidBlockPlan`) |
| v4 | Exit 1, 4/9 steps succeeded; `==` rejected for the optional error-union test expression | Not run |
| v5 | **Exit 0, 9/9 steps succeeded** | **Native 40/40 and actual WASI 40/40, both exit 0** |

The original receipts, stdout (including empty streams), stderr, and before/after full source maps for each listed execution are copied byte for byte under [`evidence/`](evidence/). Original release and result JSON preserve argv and artifact SHA bindings. v5's retained Node/WASI output reports forty passing tests and its actual wasm SHA; the configured 8 MiB harness stack is explicitly **not** measured stack use. No executable is included. No original failure is relabeled a success.

## Frozen source and provenance

[`source-overlay.tar.gz`](source-overlay.tar.gz) carries every byte in the **2,257-file v5 source registry**, `dd21162bfc7912cbc932781c9ccafd6ea7e2017b5d62037e11cdd7645b629eaf`. The closure is `src`, `build`, `build.zig`, `build.zig.zon`, and the additional executable-test source `tools/br/deferred_preferred_wasm_gate.js`. The overlay is from the isolated frozen tree, not the main worktree. Tar metadata is normalized; source bytes are unchanged.

[`historical-source-deltas.tar.gz`](historical-source-deltas.tar.gz) holds only the eight historical members whose bytes differ from v5. The v2/v3 changed sources and v4 failed test file come from their preserved original bytes. The two v1 files `src/br.zig` and `src/br/encoder/command_group_selection.zig` are **exact reconstructions, not original copies**. Both SHA values match v1's original complete registry; the initial preservation record and later reconstruction proof are retained separately. The other v1 test member uses the preserved v2 bytes with the same SHA. Original historical binary fingerprints are retained without packaging the large binaries. [`capture.json`](capture.json) identifies the bytes and the source-member roles.

## Offline verification

```sh
python3 -B /path/to/deferred-preferred-functional-20261127/verify.py
```

The verifier uses only local package bytes and the Python standard library. It checks the inventory, all original receipt/argv/release/log and source-map bindings, the v5 exact-member closure, and the historical deltas without extracting either tarball. Original absolute paths are provenance only. [`verification-receipt.json`](verification-receipt.json) records replay from a relocated copy and the corruption and missing-gate refusals. No compiler, codec, original producer, profiler, statistic, or timer runs during replay.

**Scope limit:** the separate broader `test-br` run (session 64996) is not credited as passed here and is not included. Benchmark and RSS/memory acceptance remain outside this evidence. Passing v5 establishes the recorded focused contracts only.
