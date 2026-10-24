# LZMA/XZ encoder controls functional baseline

Date: 2026-10-24. Core and CLI revision: `326184d2`.
Independent tools revision: `37dee0fc`.

Vort implements the liblzma 5.8.4 parameter table for all twenty standard and
extreme presets, five genuine HC/BT matchers, fast/normal parsing and explicit
nice/depth controls. The same settings reach LZMA-Alone, ZIP-LZMA, MicroLZMA,
raw LZMA2, XZ and the supported incremental APIs. These are functional and
parameter-effect claims. This increment does not establish competing encoder
ratio, throughput or memory leadership.

## Behavior and ownership

The [public contract](../formats/lzma-encode-controls.md) describes concrete
`fromPreset` results, explicit overrides, modern nice-length semantics,
automatic depth, requested matcher/parser budgets and accumulating work
profiles. Algorithms retain their actual distinctions: greedy selects locally,
fast probes the next position and all repeat distances, lazy compares prices
over a common endpoint, and normal searches 4096 positions with up to eight
state/repeat paths per position. Ordinary two-byte matches and one-byte rep0
are encoded and independently decoded.

Incremental LZMA preserves range, probability and repeat state across bounded
lookahead. Failed header, token-prefix and finish transactions restore their
commit state. Earlier accepted input or emitted output from the same step stays
visible in its snapshot, so retry drivers resume using cumulative differences.
Legacy hash insertion uses a caller-owned undo journal instead of copying an
entire matcher at each window. Profile counters describe actual attempts,
including failed range coding and discarded compressed candidates.

Legacy NULL narrow options preserve established bytes, including noncanonical
5000-byte Alone dictionary requests. New wide/advanced Alone requests round the
advertised dictionary upward while retaining the requested actual history;
70000 bytes advertises 98304. ZIP retains its requested dictionary size.
Stored raw LZMA2 append snapshots input only when it overlaps the output
allocation, preserving borrowed input through output growth.

## Final validation

[The archived contract report](data/lzma-xz-encode-controls-contracts-x86-20261024.json)
records final Debug results, actual ELF `TestFn` names, before/after source
hashes, ReleaseFast results, complete family/consumer checks and cross-target
compilation.

| Gate | Final result | Scope |
| --- | ---: | --- |
| Debug controls | 100/100; 5/5 build steps | 87 named tests plus 13 anonymous imports; all 77 recorded source/build hashes match before/after |
| ReleaseFast controls | 100/100; 5/5 build steps | LZMA 72 and XZ 28 executions with the corrected matcher/journal filters |
| ReleaseFast families and consumers | 443/443; 19/19 build steps | LZMA 137, XZ 114, zlib streaming 30, XZ consumers 84, stream-contract consumers 78 |
| wasm32-wasi library compile | 6/6 build steps | Complete library build surface |
| ARM64 / big-endian PowerPC | Compile exits 0 | LZMA public controls, advanced/fast parsing, matcher and journal test bodies instantiated; not runtime measurements |
| Complete build check | 140/140 build steps | Main library/tests, CLI, tools, consumers and wasm build surface |

Named control coverage includes the 24 independently written public API tests,
14 LZMA wrapper regressions, ten XZ/LZMA2 producer contracts, nine independent
price/path oracles, eight core contracts, six fast-parser regressions, seven
matcher oracles, eight journal contracts and one preset-settings test.

Independent mathematical expectations do not call production price, state or
matcher code. Eighteen small uniform/skewed graphs enumerate all legal paths,
prove each position has at most eight reachable states, and compare the normal
plan to the exact best cost. Graphs exceeding the beam validate legal replay
without claiming exhaustive optimality. Fixed prices cover literal and matched
literal trees, all four repeats, short rep, length borders, inverse distance
trees, direct bits and alignment.

The earlier 85-test aggregate omitted matcher and journal names. Its evidence
is retained outside this final report; the corrected final gate explicitly
includes all fifteen additional named tests. Import roots are not counted as
new behavior tests.

## Independent liblzma campaign

[The versioned reference campaign](data/lzma-xz-encode-controls-functional-x86-20261024.json)
passes 1277 groups against liblzma 5.8.4, with matching headers/runtime ABI and
an isolated dynamic-loader namespace. It records 636 Vort-to-liblzma groups,
576 liblzma-to-Vort groups, ten exact/below matcher-parser quota groups and
55 rejected scalar configurations preserving an existing output. All 956
source/tool hashes match before/after and at integration.

The campaign covers fifty frozen legacy wires, all twenty presets across five
formats, seven synthetic corpus families across ten mode/finder combinations,
eleven tail/window boundaries, wide and stored-history inputs, four XZ checks
and profile byte equality. The ten ZIP legacy rows explicitly derive the
standard method-14 prefix from the old public Alone EOS payload; they are not
represented as calls to a previously exported ZIP payload facade. Corpus,
wire, binary/compiler/reference/helper/header hashes and commands are archived.
This probe verifies public one-shot encode/decode; caller-buffer, append and
incremental ownership/retry contracts are independently covered by the named
control gates and the CLI campaigns above.

## CLI evidence

[The final CLI report](data/lzma-xz-cli-controls-x86-20261024.json) records one
fresh Debug campaign against Python 3.10.12 / liblzma 5.2.5: 99 encoding
round-trips, 97 rejected calls preserving an existing destination, five flag
order comparisons and twenty profile-on/off byte comparisons. Its build
target passes all seven steps.

All 1365 before/after snapshot hashes match. An additional compiler-manifest
check verifies 970 actual compilation inputs against the same bytes used for
SHA-256. The original snapshot omitted the unchanged shared filter parser;
its exact compiler input digest is separately verified and documented.
The final binary SHA-256 is
`0fd692480823f08d1fea3da8dc00463233f3fc0b8bf423dfe7833d36cf002970`.
The actual full Debug CLI help smoke also exposes the new flags.

## Reproduction and remaining gaps

```sh
zig build test-lzma-xz-encode-controls -j2 --summary all
zig build test-lzma-xz-encode-controls -Doptimize=ReleaseFast -j2 --summary all
zig build test-lzma test-xz test-zlib-stream test-xz-consumers test-stream-contract-consumers -Doptimize=ReleaseFast -j4 --summary all
zig build test-lzma-xz-cli-controls -j2 --summary all
zig build check-wasm -j2 --summary all
zig build check -j4 --summary all
zig build run -- --help
zig build run-lzma-xz-encode-controls-diff -Doptimize=ReleaseFast -- --reference-helper /tmp/vort-lzma-controls-reference.so --prepared /tmp/vort-lzma-controls-prepared2 --work-dir /tmp/lzma-controls-validation --report /tmp/lzma-controls.json
```

The native measurements here use Linux x86-64 on Intel Core i7-10700K and Zig
0.16.0. Validation durations and process maxima are not a competitor benchmark.
Requested matcher/parser memory excludes input/history/output ownership,
fixed coding state, OS and allocator overhead; it is not process RSS.

Vort's 64 MiB custom encoder dictionary limit covers all standard presets but
remains below liblzma's full 1.5 GiB range. Compressed LZMA2 chunks retain a
64 KiB plaintext limit versus the format's 2 MiB maximum. XZ's unchanged default
1 MiB independent blocks constrain effective long history. Full liblzma
algorithm/quality parity and broad current-reference speed/ratio/memory
comparisons remain open, alongside the broader Brotli/Zstd HQ work.
