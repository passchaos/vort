# Mapped owner and normalized match-word handoff: rejected screen

**Both prototypes are rejected and remain outside mainline codec code.**
The owner-word variant reaches only 1.0002092237149147x aggregate speed,
with a confidence interval containing parity and a target gain below the
required 20%. The owner-only control regresses to 0.9696129246760212x and
fails control rows. This packet preserves exact failed/successful correctness
epochs, the original timing source, static evidence and terminal whole-operation
samples so the experiment is reproducible and searchable.

The baseline is `7aaa936142aafdebe8351962e8c49059571d42c5`, with no prototype
production code adopted. Isolated roots were
`/home/passchaos/project-z/vort-mapped-owner-20261112.7aaa9361` and the scalar
control `vort-mapped-owner-scalar-20261112.7aaa9361`. Archived source snapshots
and recorded hashes govern identity; current worktree files and earlier
conversation-summary hashes do not replace them.

## Completed screen and rejection gates

| Variant | Twelve-row speed GM | Fixed-row bootstrap 95% CI | Target Reymont 64 KiB/L6 | Weakest control | Result |
| --- | ---: | --- | ---: | --- | --- |
| Owner + normalized word | 1.0002092237149147x | [0.9960687882714572, 1.0044665189209887] | 1.0239784118597959x | Reymont 1 MiB/L9, 0.9852887655547395x | REJECT: target and aggregate gates fail. |
| Owner + scalar entry | 0.9696129246760212x | [0.9673505196994259, 0.972015704454312] | 1.042354522425546x | NCI 64 KiB/L9, 0.8911048953036738x | REJECT: target, control and aggregate gates fail. |

Protocol gates are target >=1.20x, every control row GM >=0.98x, and aggregate
GM >=1.03x with confidence lower bound above parity. These are development-host
screens, not dedicated-host acceptance or a full modern-reference/industry
matrix. Bootstrap uses the fixed 12 rows, balanced AB/BA process-order strata,
2000 resamples and seed `0x20261112`; its scope is conditional on those rows.

| Row | Owner-word GM | Owner-only GM |
| --- | ---: | ---: |
| `deflate_reymont_65536_6_cold` | 1.023978412x | 1.042354522x |
| `deflate_reymont_65536_9_cold` | 1.016213848x | 1.020188818x |
| `deflate_nci_65536_6_cold` | 0.993995689x | 0.904666352x |
| `deflate_nci_65536_9_cold` | 1.001566071x | 0.891104895x |
| `deflate_xml_65536_6_cold` | 0.989504942x | 0.906564246x |
| `deflate_xml_65536_9_cold` | 1.000924940x | 0.919227512x |
| `deflate_reymont_1048576_6_cold` | 0.997787681x | 1.015075738x |
| `deflate_reymont_1048576_9_cold` | 0.985288766x | 1.001335103x |
| `deflate_nci_1048576_6_cold` | 0.992016622x | 0.980283237x |
| `deflate_nci_1048576_9_cold` | 1.005702044x | 0.986562300x |
| `deflate_xml_1048576_6_cold` | 0.998134592x | 1.000883959x |
| `deflate_xml_1048576_9_cold` | 0.998048652x | 0.982444802x |

There are **96 baseline/candidate process pairs and 192 child events** total:
48 process pairs per variant, four AB/BA pairs per selected row. Each child
has two measured Vort/reference pairs and two warmup pairs, giving **384 raw
measured pairs and 384 warmup pairs**. Iterations are 500 at 64 KiB and 100
at 1 MiB, cold lifecycle, levels 6/9, Reymont/NCI/XML. The verifier recomputes
child medians, every outer ratio, row/group/size geometric means, bootstrap
intervals and target/control decisions from raw measured `vort_ns` values.

The recorded target is Zig 0.16.0 ReleaseFast, x86_64 Linux GNU,
`skylake+pku+sgx`, CPU 15 on an Intel Core i7-10700K, one codec/benchmark
thread. Vort calls `decodeRawDeflate`; libdeflate allocates, decodes with
`libdeflate_deflate_decompress_ex`, then frees its decompressor. Reference
libdeflate 1.26 is pinned at `92e6a0db9fa848d742f9eb286c92afc60f2c3dda`,
GCC 11.4.0, `-O3 -DNDEBUG -march=skylake`, library SHA-256
`1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28`.
The development-host powersave/intel_pstate environment and original per-process
observations are retained. All recorded compiler boundary observations are
empty; load1 spans [0.8720703125, 1.2158203125]. Process tick snapshots do not
locate timed-batch overlap. No codec heap or dynamic instruction cost is measured.

## Architecture examined and actual live match state

The prototype constructs canonical LL/DIST tables directly inside an
address-stable `MappedOwner`, then mints an opaque `MappedBorrow`. It retains
compact tables for fallback when semantic preparation declines. The borrow
cannot wrap an arbitrary caller-populated private semantic decoder; its owner
must stay at the initialization address and remain unchanged while borrowed.
Only metadata derived from those canonical tables reaches the normalized
word entry. Existing private full-width scalar APIs remain separate.

The source word uses `(length - 3) | ((distance - 1) << 8)` and reconstructs
length/distance through that normalized representation. The scalar owner-only
control differs by routing the ordinary mapped-owner call to `decodeBuffered`
instead of `decodeMappedBuffered`, retaining the same owner preparation.

The actual owner-word machine code carries **two values** across next-entry
and refill: a packed word in edx and normalized length in ecx. Post-refill
length comes from cl; full distance is restored from the word. It did not
achieve a single carried value. No forced materialization, compiler barrier or
inline assembly was introduced for the experiment.

| Whole-symbol static observation | Baseline aligned | Owner-word alignedMapped |
| --- | ---: | ---: |
| Text bytes | 3659 | 3729 |
| Stack reservation | 296 | 312 |
| Register pushes | 6 | 6 |
| Instruction lines including padding | 897 | 894 |
| Negative-rbp references | 131 | 129 |
| Static shrx / shlx / bzhi / call sites | 11 / 16 / 4 / 8 | 11 / 16 / 4 / 9 |

Text grows **70 bytes** and stack reservation grows **16 bytes**. Static
negative-rbp references are not dynamic spills, and call sites are not runtime
call counts. The complete symbol includes tail/cold/error paths and padding.
There is no measured runtime spill reduction or machine-code equivalence claim.

`codegen-audit.json` is a main-authored summary tracing an earlier read-only
static audit. Its raw nm/objdump files are a **new main CPU 0 capture**, not
recovered raw output from that earlier agent. The exact retained raw bytes,
addresses and hashes let the verifier independently parse static counters.
The candidate comparator does not emit the old aligned private full-width
symbol. Private correctness comes from separate shim tests, not that candidate
disassembly. Owner-only has no separately claimed raw static audit.

## Frozen source and correctness epochs

| Epoch | Frozen files | Evidence |
| --- | ---: | --- |
| Original timing | 7 | `timing-source` and `timing-freeze.json`, exact original candidate probe identity. |
| Handoff v1 | 9 | Safe/Debug reported 103 passed, 2 failed out of 105; original snapshots/binaries/logs retained. |
| Handoff v2 | 9 | Only two short-tail test expectations/comments change; native Safe/Debug and x86 Linux musl Safe each 105/105. |
| Owner-only control | 5 | Separate source freeze/probe, same shared production except ordinary entry selection. |

Authoritative original timing probe SHA-256 is
`2d2d18228696054e15296b760b2a7c5060a0e746032c20d119130eea339f2258`.
Baseline comparator SHA-256 is
`65b75eeec00bf7933d0baa3886e6097fc7275a813d72190f601be286944cce96`;
owner-only is `a081724939d287ef018fa650cd5e65b7e13b9829020b3bbd658fada02e0c6e16`.
All five production files in later handoff snapshots match original timing
source. Later test/shim files were not silently substituted into the original
build identity. Captured source registries are baseline **2069**, owner-word
**2075**, owner-only **2071** files. The replay union of baseline and original
timing snapshot has 2073 files and is an archive reconstruction, not an original
capture-time registry or complete compiler-input claim.

The original v1 failures wanted `InvalidHuffmanCode` while the scalar oracle
returned `TruncatedFrame` for short logical tails. Both executor results are
computed before that assertion; v2 corrects the tail expectations and verifies
the old/new errors match. Production code and input construction remain
byte-identical across that test correction. The original failure is preserved
rather than relabeled as a codec defect.

The corrected 105-log suite has **103 named tests and two anonymous imports**.
Exactly **17 new test declarations** come from three mapped modules: eight
owner, six handoff and three private full-width declarations; the other 88
entries are existing dependency tests/imports. Inner fixture loops are not
counted as 105 new behaviors. Tests compare scalar/mapped output, reader state,
guards and preserved input, including scalar replay and fixed-test scratch
backing equality. That does not create a public untouched-unused-tail contract.

The full `src/deflate.zig` ReleaseSafe test root passes 738/738, **725 named
plus 13 imports**, with none of the new shim modules imported. Its terminal
log and producer observation are retained; the old unified process handle was
unavailable after compaction. Constructor shim 11/11, public generic 8/8 and
distance-hole 10/10 observations are also preserved. Initial direct-module
`import of file outside module path` errors are excluded from runtime success.
WASI received **compile-only** checking with `-fno-emit-bin`; no WASI runtime
coverage or saved WASI executable is claimed. Unsaved test argv is not invented.

## Smoke, exact reused bytes and artifact contents

Both variants pass **72/72 original Deflate-wire smoke**, 144 child events,
one call per batch, two rounds and zero warmups. Every report validates returned
count, full output, exact consumption, immutable input and guards. Smoke source
registries/probe hashes match the final variant captures. Smoke clocks are
excluded from performance statistics.

The 108 ordinary plain/wire files total **371,820,359 bytes** and remain
external with exact path/hash/size/generator descriptors. `--originals` verifies
them. Tiny repository distance-hole inputs are durably reused from the prior
committed archive; the verifier opens that archive and checks actual member
bytes against the frozen baseline. Reused baseline/source/reference/probe
containers and the exact prior fixture seed manifest are also hash-bound and
opened, rather than trusted by filename alone.

| Artifact | Contents |
| --- | --- |
| Four `*-source-overlay.tar.gz` files | Exact timing, handoff-v1, handoff-v2 and owner-only snapshots, kept separate. |
| `retained-probes-tests.tar.gz` | All 11 retained native prototype/test binaries. |
| `raw-validation.tar.gz` | All original top-level logs/JSON, including final producer and independent-statistics receipts. |
| `raw-static-audit.tar.gz` | Original newly captured candidate nm, two objdump files and main static-audit JSON. |
| `screen-raw.tar.gz`, `smoke-raw.tar.gz` | All original per-child outputs/events, manifests/protocol/summary, runners and logs. |
| `runner-imports.tar.gz` | Frozen base7aaa tools/decode matrix/evidence/fixtures dependency closure; screen is smoke's protocol import. |
| Readable freeze/producer/static/statistics JSON files | Exact copies of their archived originals. |
| `fixture-replay-bindings.json`, `decision.json` | Original ordinary fixture descriptors and explicitly archive-derived rejection decision. |
| `pack.py`, `verify.py`, `archive-bindings.json`, `validation-receipt.json`, `SHA256SUMS` | Terminal-gated archive creation, independent verification, member/origin/container identity, successful receipt and complete checksum inventory. |

Archives use sorted GNU tar, regular modes0644/binaries0755, uid/gid/mtime zero,
empty owner names and gzip level9 with empty filename/mtime zero. Raw bytes,
whitespace and EOF are preserved. Packing and verification run on **CPU 0**.
Prototype modified/new files are uncommitted overlays verified by frozen hashes
and captured registries; immutable base7aaa source is verified through Git blobs.
No current modified production file is substituted as baseline source.

From this directory:

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

`pack.py` checks terminal/frozen inputs and writes archives only with explicit
`--finalize`; it refuses archive overwrite. Reproduction requires a clean output
folder and the original inputs. The offline verifier independently checks
source epochs, 103/105 failures and corrected test counts, static raw counters,
fixture/reference/probe bytes, all 192 screen events, fixed-row bootstrap/gates,
144 smoke events and source/command/count/content/consumption/guard bindings.
It invokes no compiler, codec, test, oracle or benchmark. Later measurements
must use a new capture epoch, preserving their own raw data and provenance.
