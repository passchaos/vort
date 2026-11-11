# Deflate exact wide-copy contracts

The final frozen boundary implements the declared internal `copyWide` range
of **3..258 bytes** and retains the original wide loop behind a separately
validated **16..258-byte** core. This packet preserves three distinct epochs
based on `492a0a74535992cd4a7e3ad3182777414c8c0fac`: the original kernel with a
new direct test, the first full-range fallback, and the final caller boundary.
It archives existing completed correctness evidence; it does not establish a
throughput gain or strict machine-code equality.

The before ReleaseSafe run aborts on its first direct three-byte case with
integer overflow in the old `length - 16` tail calculation. The only original
production call already supplied **length >=17**, so this demonstrates an
internal declared-range defect, not a newly discovered public wire defect.
The v1 fallback fixes direct low lengths but remains in the generic aligned
kernel. The final source places that fallback in `copyWide` and changes the
existing production call to `copyWideAtLeast16`; its 16-byte loop and tail body
are byte-identical source to the original body.

The four final frozen source files were later saved byte-identically in
commit `fe75d21fa10a45b204347cce8d52be97f534d718` (`fix(deflate): preserve the complete
wide-copy length contract`). `saved-source-commit.json` records that additional
identity; it does not relabel earlier captures or the pre-fix profiles.

## Completed functional validation

| Epoch | Existing completed observations |
| --- | --- |
| Before | ReleaseSafe first direct three-byte case aborts, test driver exit 1 and ABRT. |
| V1 full facade | Debug, ReleaseSafe, x86 ReleaseSafe and WASI ReleaseSafe each pass one direct aggregate; full Deflate ReleaseSafe passes 736/736. |
| Final validated boundary | The same four focused configurations each pass one aggregate; full Deflate ReleaseSafe passes 736/736. |

The final aggregate compares every output byte against an independent scalar
copy and checks unchanged source and all backing bytes outside the destination.
Exact-length slices cover all source/destination offsets modulo 16 in separate
buffers, plus adjacent non-overlapping spans in both address orders. There are
`256 * (16*16 + 16*2) = 73,728` facade cases and
`243 * (16*16 + 16*2) = 69,984` core cases, **143,712 scalar cases** in total.
A single aggregate test is not 143,712 separately reported Zig tests. The
736-test suite also includes existing tests and anonymous import tests; the
verifier classifies their retained log rows separately.

## Static code summary and its limits

| Frozen executable epoch | Whole-symbol text bytes | Stack reservation | Static instructions including padding | Negative-rbp references |
| --- | ---: | ---: | ---: | ---: |
| Equivalent baseline `2527c721…` | 3637 | 296 | 898 | 131 |
| V1 `650927b7…` | 3701 | 312 | 900 | 122 |
| Final boundary `e8377941…` | 3669 | 296 | 896 | 131 |

`codegen-comparison.json` is a **main-authored derived summary of read-only
audit messages**. Original nm/objdump stdout was not retained. Whole-symbol
counts include copies, tail/error paths and padding, and negative-rbp counts
are static references rather than dynamic spills. Final stack reservation
returns to 296 bytes while text grows by 32 bytes; wide-loop entry/tail and
block layout still differ. These observations do not prove machine-code or
performance equality. Any later performance screen or changed source must
keep its own epoch and acceptance scope.

## Final-boundary nonregression and all-wire smoke

The later completed **12-row nonregression pilot** uses the exact final
boundary probe `e8377941…` against the frozen Git 492a0a74 baseline `2527c721…`.
It contains 96 process events: four alternating baseline/candidate outer
pairs per row, each child with two warmup pairs and two measured Vort/reference
pairs. The child iterations are 500 at 64 KiB and 100 at 1 MiB. Inputs are
frozen producer wires for Reymont, NCI and XML at levels 6 and 9; CPU 15,
Zig 0.16.0 ReleaseFast `skylake+pku+sgx`, libdeflate 1.26, one codec thread
and the original development-host observations are recorded per event.

| Selected row | Geometric mean baseline/candidate speed ratio |
| --- | ---: |
| `deflate_reymont_65536_6_cold` | 1.006009255x |
| `deflate_reymont_65536_9_cold` | 1.011160077x |
| `deflate_nci_65536_6_cold` | 1.012205155x |
| `deflate_nci_65536_9_cold` | 1.002170307x |
| `deflate_xml_65536_6_cold` | 1.009302102x |
| `deflate_xml_65536_9_cold` | 1.019230385x |
| `deflate_reymont_1048576_6_cold` | 1.010381551x |
| `deflate_reymont_1048576_9_cold` | 0.997107276x |
| `deflate_nci_1048576_6_cold` | 0.998640437x |
| `deflate_nci_1048576_9_cold` | 0.984858663x |
| `deflate_xml_1048576_6_cold` | 0.998619184x |
| `deflate_xml_1048576_9_cold` | 0.994342668x |

The selected twelve-row geometric mean is **1.003627731641238x**. The weakest
row is **NCI 1 MiB/L9, 0.9848586630321882x**. All selected **row geometric
means** pass the 0.98 floor. Individual outer-pair ratios can fall below that
floor; the archive retains them unchanged. This is a functional correction
nonregression pilot, not a dedicated-host gain result or full-matrix acceptance.
`independent-stats.json` is the original main-authored standard-library
recomputation; the archive verifier independently rebuilds ratios and medians
from the captured measured Vort pairs.

The separately completed **72-wire smoke** covers the frozen Deflate corpus
at levels 6/9 and 64 KiB/1 MiB/full sizes. All child exits are zero, with one
call per batch, two alternating measured pairs and zero warmups. Original
reports validate full output, exact consumption, returned count, unchanged
input and guards. Smoke times are not matrix performance evidence. Its source
registry is the final frozen baseline plus the four final source overlays,
2064 files; it is not the v1 epoch.

`fixture-replay-bindings.json` preserves all fixture paths, exact hashes,
sizes and producer metadata. The 108 distinct plain/wire files total
**371,820,359 bytes**; those large original bytes remain external and are
checked by `--originals`. Standard offline verification checks the captured
fixture descriptors and report bindings. The separate profile packets retain
their tiny exact plain/wire bytes. Replay runners, imported helpers and both
original pilot seed manifests are archived; reproducing measurements creates
a new epoch.

## Frozen source and artifact identity

| File | Contents |
| --- | --- |
| `before-source-overlay.tar.gz` | Original kernel plus first direct test; two frozen files. |
| `v1-source-overlay.tar.gz` | First full facade, unchanged direct test and Deflate test wiring; three frozen files. |
| `final-boundary-source-overlay.tar.gz` | Final facade/core, caller boundary, expanded aggregate and test wiring; four frozen files. |
| `raw-validation.tar.gz` | Exact failure/success/build logs, freeze/hash receipts, final validation, message-derived code summary and WASI runner. |
| `nonregression-raw.tar.gz` | All 306 original completed screen files, including 303 row artifacts, runner/log and independent stats. |
| `smoke-raw.tar.gz` | All 221 original smoke files, including 219 per-wire/event/manifest/receipt files and runner/log. |
| `screen-runner-dependencies.tar.gz` | Exact pilot and matrix/evidence/fixtures imports with both original seed manifests. |
| `independent-stats.json`, `fixture-replay-bindings.json` | Exact readable original stats and separate descriptors for external frozen inputs. |
| `test-executables.tar.gz` | All 13 retained before/v1/final native/WASI test and comparator binaries. |
| `base-source-registry.json`, `build-source-addendum.json` | Extracted original 2048-record capture source object and separately attributed later 15-module build reconstruction. |
| `boundary-validation.json`, `codegen-comparison.json` | Exact readable copies of their archived raw originals. |
| `saved-source-commit.json` | Later saved commit identity for the same four final frozen source files; separate from capture epoch. |
| `archive-bindings.json`, `verify.py`, `validation-receipt.json`, `SHA256SUMS` | Member hashes/origins, independent offline verifier, successful receipt and complete checksum inventory. |

The unchanged NCI capture manifest records **2048 source files**, digest
`ca749da163882c8d358b32e95602110b71b4987fafbebc96330dbbb7aaacf529`.
Its `matrix.source_state` registry omitted 15 `build/*.zig` modules compared
with the earlier manually supplemented registry. A later main-authored
reconstruction extracts those modules from immutable Git 492a0a74 blobs;
they match earlier recorded baseline hashes. The combined replay inventory
has **2063 files**, digest
`32546e939bea56b5b2122482e0383a2bce3769e4f6146bcf0684d31128692075`.
The original 2048 records are not a complete compiler-input claim, and the
later addendum is not a capture-time observation.

The verifier reconstructs those 2063 baseline files from the existing
`br/decode-mozilla-distributions-20261112/shared-dispatch-source.tar.gz` and
`public-linear-contracts-20261112/source-overlay.tar.gz`, then applies each
separate epoch overlay. No current modified production source is used.
The baseline comparator binary is reused from the earlier probe archive;
its exact SHA-256 is
`2527c72112f19ac34d08d8f199f38e76dc4a9883ad25466f2f83ff193da21f14`.
Frozen test sources and binary/log bindings are retained; direct-test build
argv were not saved as separate original command receipts. Comparator build
logs retain their 7/7 result and compiler RSS, which is not codec heap usage.

Archives use sorted GNU tar, uid/gid/mtime zero, empty owner names and gzip
level 9 with empty filename/mtime zero. Raw bytes, whitespace and EOF remain
unchanged. Packaging and verification use **CPU 0**.

## Offline verification

From this directory:

```sh
taskset -c 0 sha256sum -c SHA256SUMS
taskset -c 0 python3 verify.py
taskset -c 0 python3 verify.py --originals --git-repo /home/passchaos/project-z/vort
```

The standard-library verifier checks archive metadata and byte identities,
reconstructs frozen source, validates the preserved before/v1/final source
and probe bindings, checks original failure and all successful test log rows,
recomputes scalar-case counts, checks final receipts and static-summary
attribution, and independently recomputes complete nonregression statistics
and the 72-wire smoke report/source/fixture/command bindings. Optional checks compare retained originals, all 108 external fixture files
and frozen Git blobs.
It does not compile, decode, sample, or run a benchmark.
