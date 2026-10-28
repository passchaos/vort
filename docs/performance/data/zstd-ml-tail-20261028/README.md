# Sampled ML tail-stop evidence

Baseline is `bdae5ce7128e30fee20e20e16612844a818cf1ff`; the measured candidate
adds only `if (lower >= maximum) break` inside sampled ML interval enumeration.
The shared baseline and inputs are retained in the adjacent
`zstd-prepared-pricing-20261028` directory. No prepared-pricing prototype is
part of this candidate.

`screen.tar.xz` preserves the runner, screen driver, changed candidate source,
diff/proof, original compile/run commands and terminal status, raw timing and
profile JSON, every wire, assembly and identities. `results.json.xz` separately
contains the full result for convenient extraction. Compiled binaries/caches
are excluded; their measured SHA-256 identities are recorded.

`reference-decode.json` records independent decoding of all 24 screen wires
through the local libzstd 1.6.0, including the library's exact identity.
`manifest.json` records the archive/member hashes and parent source, timing,
wire/profile and reference-record audit. Run this directory's `audit.py` to
verify the frozen records and source diff without repeating benchmarks.

For reproduction, extract the shared baseline, overlay the candidate source
from `screen.tar.xz`, and rewrite the archived structured compile/run command
arguments to the new directories. Use Zig 0.16.0 LLVM ReleaseFast, Skylake code
generation, the shared Huffman object build command in the adjacent pricing
manifest, and CPU 2. The archived driver specifies the two-round AB/BA order
and computes median candidate time divided by median baseline time. One early
copied-binary execution-permission setup failure is retained separately and
does not contribute to any effective measurement.

`large-trained` preserves a separate one-round epoch on Mozilla 16 KiB and
an 8 KiB input with the previously trained 4096-byte standard dictionary. Its
archive includes actual input/dictionary bytes, training provenance, the
unchanged large-input runner, commands, terminal records and complete results.
Its own reference record verifies all eight wires through libzstd 1.6.0,
including dictionary decoding. This directory's `audit.py` checks both epochs.

`frozen-oracle-validation.json` records the independent native Debug,
ReleaseFast and x86 Debug runs against the frozen old edge module.
`interoperability.tar.xz` and its manifest retain the 52 HQ/41 expanded-search
bidirectional reference groups, raw wires/profiles and exact source identities.

`current-validation.json` records the retained source's native/RF/Wasm,
369-test, reference and 210-step build-check terminal statuses and source
identities. The complete check report is compressed separately. The compiled
standalone WASI test image and its Node runner are also retained for execution.
`source-contracts.tar.xz` freezes the final nine source/test files, including
the explanatory comment and test registration added after timing. Overlay it
onto the shared baseline to reproduce the retained contract tests.
