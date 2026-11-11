# Completed-match static-codegen prototype

This package preserves the rejected optional completed ordinary-match prototype.
No A/B, benchmark or perf run was performed: the benefit condition failed before
throughput measurement. The completed word remained at RBP[-0xa4] with its tag at
[-0x3c] and word/tag pointers, while scalar length in RBX and scalar distance in
R8 remained live across refill. The carrier did not eliminate the competing
scalar state; no speed, parity, heap or leadership result is asserted.

| Static property | Synchronized boundary baseline | Prototype |
|---|---:|---:|
| Generic aligned symbol bytes | 3669 | 4001 |
| Explicit stack reservation | 296 | 328 |
| Whole-symbol instruction lines, including padding | 896 | 969 |
| ELF .text bytes | 927961 | 928473 |
| Negative RBP operand references | 131 | 128 |

The last row is a whole-symbol text count, not dynamic spill frequency or a
performance improvement. Copy/tail/error paths and padding remain in the static
scope. Unlike earlier message-derived summaries, this packet retains the actual
CPU 0 nm, full aligned-entity objdump and section output files byte-for-byte.
The offline verifier independently recounts mnemonic/instruction/RBP references,
checks nm symbol sizes and section totals, and preserves their static limits.

`prototype-packet.tar.gz` contains all 36 original files: 35 checksum-covered
producer files plus the checksum file itself, including four
synchronized before-source files, six candidate-source files, exact baseline and
candidate executables, test executables/logs, install copy, raw static outputs,
commands, candidate-only patch, registry, producer README and validation receipt.
Original bytes and EOFs are unchanged. Sorted GNU tar/gzip9 use zero uid/gid/mtime,
empty owners/filename and modes 0644/0755. `archive-bindings.json` records all
member hashes and origins; the original producer SHA256SUMS is also retained.

Immutable base is `492a0a74535992cd4a7e3ad3182777414c8c0fac`. The synchronized
wide-copy baseline uses the four retained before-source files and executable
`e8377941221a13c0a0030b10ae083bb73cf17bc58f81ea8d55ad98c5eb66cb5c`.
Candidate executable is
`ff60e8d12b1b0d75128595a3f5c24b1460113d2e39961f15898c99550c40055f`.
Candidate-only.patch contains only semantic decoder plus completed_match and its
tests; already synchronized main changes remain outside that patch. Other
registered source bytes are read from immutable 492 Git blobs, never live source.

The 2765-path registry SHA is
`41137fffc8422ffb73e27c3891a2aab40d96fcb1b7304a29a9f4f9d1c66fd40a`.
It is the producer-defined registered scope; it is not automatically a complete
compiler-open/input trace. The producer README's broader wording is retained as
original text, while this archive uses the explicit narrower interpretation.

Recorded validation is helper 2 tests over all 8388608 legal length/distance pairs,
filtered private/public 11 tests, full Deflate 739 tests and ReleaseFast 7/7 build
steps, all exit 0. Tests are recorded evidence and are not rerun by archival tools.
The exhaustive domain is 256 lengths 3..258 times 32768 distances 1..32768. The
candidate source and binaries remain independent of subsequent production work,
and the prototype is not adopted into main.

From the repository root, run only the standard-library offline byte/source/diff
and static-output validator on CPU 0:

```sh
taskset -c 0 python3 -B \
  docs/performance/deflate/completed-match-codegen-20261112/verify.py \
  --original-bytes
```

It reads pinned Git objects and retained original files; it launches no compiler,
codec, test executable, benchmark or perf command. `validation-receipt.json`
records the archival check and `SHA256SUMS` binds final package files.
