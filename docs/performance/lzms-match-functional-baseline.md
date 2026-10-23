# LZMS greedy match functional baseline

Date: 2026-10-23. Zig 0.16.0, Linux x86-64, ReleaseFast native probe. Reference:
wimlib 1.14.5, pinned commit `cd5e231c348c255ae5088873b5a66ee0eb96fa07`, level 50.
This report covers wire correctness and compressed sizes, not encode/decode
throughput, cross-platform leadership or wimlib optimal-parser parity.

```sh
zig build run-lzms-match-diff -Doptimize=ReleaseFast -- \
  --wimlib-dir /path/to/pinned-wimlib --report /tmp/lzms-match-report.json
```

The complete JSON includes 39 input/strategy rows with input/encoded hashes,
selected literal/reference state, LZ/delta/repeat counts, maximum offsets and
logical peak working allocation. Every probe internally decodes output, reruns
deterministically and enforces `encoded <= literal_reference`. Thirty non-tiny
rows additionally decode through the unmodified wimlib library.

| Family | Input bytes | Literal reference | Vort greedy | wimlib level 50 |
| --- | ---: | ---: | ---: | ---: |
| repeated text | 66000 | 39398 | 38 | 40 |
| JSON | 58702 | 36406 | 2166 | 2650 |
| arithmetic delta | 32768 | 25364 | 12 | 14 |
| row/column matrix | 32768 | 30998 | 16 | 18 |
| binary repetition | 32768 | 33072 | 8296 | 8296 |
| random | 65536 | 66114 | 66114 | 66116 |
| x86 calls | 51032 | 17390 | 42 | 40 |
| decoder source | 12774 | 8020 | 3520 | 3038 |
| mixed text/binary | 38096 | 21830 | 4186 | 4188 |

The binary family repeats an irreducible 8 KiB random prefix four times. The
gate charges up to 512 bytes beyond that prefix and requires the complete
24 KiB tail to be matched at distance 8192. Its raw 4x size floor would have
ignored framing/entropy overhead. Retaining an in-window anchor plus the latest
position per fixed bucket prevents one later collision from losing the first
prefix match.

Default hash storage requests 2.25 MiB across one LZ and eight delta families;
the recorded whole-encoder peaks are roughly 2.3--2.6 MiB on these families.
The small greedy mode uses an integer bit-cost estimate followed by complete
literal-wire arbitration. It wins several selected families and loses source
and x86 size against wimlib; broader standard corpora, quality levels, memory
calibration and throughput remain future work.

Ten independent hand-planned streams cover LZ/repeat, each delta power and a
106,685,608-byte stream containing 30-bit length/offset fields. All decode through
wimlib. The pinned reference faults while initializing offset Huffman codes
for one-/two-byte outputs, including unchanged literal output. The wrapper
reports that limitation without patching the library. Vort's native tiny tests
and explicit literal-reference equality remain required.

Exact observations and source/executable hashes are in
[the retained JSON](data/lzms-matching-x86-20261023.json).
