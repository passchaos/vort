# Zstd magicless functional evidence

The baseline source is `89fae5d6cf5b98facf9b899a79eea93e60fb4e0f`.
`new-source-manifest.json` binds 1912 codec/tool files to
`eb6cb40d35d4ba73fcab2ee3e245aaf8be7c22a5`. Source, tool and executable
identities are separate from documentation commits and ordinary run durations.

Each `native-final.tar.xz` / `x86-final.tar.xz` preserves all 2460 original
campaign files. The matching `*-files.json` contains their uncompressed sizes,
SHA-256 and archive identity. Reports remain available as plain JSON. Archive
compression is packaging and does not measure Vort throughput or ratio.

```sh
tar -xJf native-final.tar.xz
tar -xJf x86-final.tar.xz
```

Each campaign passes 609 cases: 284 target encodes forming 142 standard/bare
pairs; five default-standard checks; 45 reference streams through six decoder
routes; six prevalidated concatenation checks; 36 malformed checks; eight
quota/dictionary checks. Every paired bare output is exactly the corresponding
standard frame after removing its first four bytes. Explicit magicless handles
ordinary concatenated data frames; skippable recognition remains standard-only.
Physical header, block, checksum and progress offsets refer to actual input.

The actual reference is the local libzstd 1.6.0 file recorded in the reports.
Experimental C/D parameter values are parsed from its local header rather than
assumed from unrelated examples; loaded symbol owners, library/header hashes,
version and complete content/consumption results are retained. The reference
Python process is native while the x86 Vort executable is actually 32-bit.
Cross-target comparison preserves target identity and memory dimensions.

Focused tests comprise 19 codec/layout executions and 111 root/consumer
executions, not 130 independent format fixtures. They cover dictionary IDs,
raw/full dictionaries, suspended dictionary requests before payload admission,
unknown content sizes, stop-first/trailing input, caller-output aliasing,
checksums, malformed input and resource failures. ZFS tests compare its current
payload against the former standard-frame-minus-magic construction and refuse
the old full compressed-input clone request. Output allocation still occurs.

Failed compilation and QA logs are intentionally preserved. A self-generated
raw frame initially shifted a `@min`-inferred `u18` before widening, producing
zero for the 128KiB block header; the repaired independent fixture widens first
and retains exact byte checks. One-shot wrong-dictionary-ID expectations were
corrected to the established `NeedDictionary`, while incremental dictionary
provision still checks `DictionaryMismatch`. These were QA corrections, not
changes to accepted codec wire. See `qa-fixture-audit.md`.

The new allocator-first WithOptions Into/Append APIs stage decoded bytes and
publish only after successful full decoding/checksum verification. They borrow
compressed frames without copying or prepending magic. Size queries retain
their existing structural/entropy/size semantics and do not hash plaintext.
Legacy standard fast paths remain available. No throughput, RSS, total-stack
or universal memory leadership is established by this increment.

Reproduce with Zig 0.16.0:

```sh
zig build test-zstd-magicless --summary all
zig build test-zstd-magicless -Doptimize=ReleaseFast --summary all
zig build test-zstd-magicless -Dtarget=x86-linux-gnu -Doptimize=ReleaseFast --summary all
zig build test-zstd -Doptimize=ReleaseFast --summary all
zig build check --summary all
zig build run --summary all -- --help
zig build run-zstd-magicless-diff -- --directory /tmp/vort-magicless-native \
  --reference /home/passchaos/Work/zstd/lib/libzstd.so.1.6.0 \
  --reference-header /home/passchaos/Work/zstd/lib/zstd.h
```

Use the same differential step with `-Dtarget=x86-linux-gnu` for the x86
campaign. Full family, build and rebase checks are recorded in `validation.json`
and their logs with exact scopes.

`standard-parity.tar.xz` preserves the old/new standard wires, inputs,
dictionary files, configurations and exact old-API harness for the 96-case
parity comparison. Its file manifest has individual uncompressed hashes.
Both outputs in each comparison received complete libzstd checks, and the
existing default alloc/reusable/into methods also decoded them. This matrix
uses no format bridge or feature backport, and its quality/input scope is
recorded explicitly in `standard-parity/standard-parity.json`.
