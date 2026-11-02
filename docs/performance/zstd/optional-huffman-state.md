# Caller-owned optional Huffman state, 2026-11-02

Raw and RLE literal sections now represent an absent Huffman decoder with an
optional pointer. The one-shot and reusable sequence consumers provide local
state storage and initialize it only for compressed/treeless literals. This
avoids materializing a large absent optional value for each raw section.

The shared initializer lives in `src/zstd/literals/state_init.zig`. It writes
the tree, lookup, cursor and decoded count into caller storage, returning that
same pointer after successful initialization. Raw/RLE leave storage untouched.
The owned optional-value wrapper remains available for persistent incremental
state. There is no added allocation or public API/handle-layout change.

## Evidence for the cost

A pure caller-buffer decoder times 8,000 warmed Mozilla 1 MiB level-3 calls.
Input loading, allocation, complete content verification, SHA-256 and output
guard checks are outside the interval. `perf record` samples the same decoder
on logical CPU2. Baseline codec source is `a6d8e410`, Zig 0.16.0 ReleaseFast,
`x86_64-linux-gnu -mcpu=skylake+pku+sgx`, Intel Core i7-10700K, one thread.

The baseline `initHuffmanLiteralDecodeState` raw/RLE return path tail-calls
`compiler_rt.memset` with length `0x1488` (5,256 bytes). Its optional payload is
unused, but constructing the large null result still writes it. Disassembly
and sampled caller addresses identify this call, rather than attributing the
cost to RLE literal/block data, which this frame does not contain.

| Sampled symbol | Before | After |
| --- | ---: | ---: |
| Dense split-Huffman sequence loop | 35.89% | 40.47% |
| `compiler_rt.memset` | 19.66% | 10.83% |
| `compiler_rt.memcpy.memcpyFast` | 11.89% | 12.27% |
| Generic sequence reader | 6.17% | 6.02% |

These are sample shares of each entire run, rather than independent speed
ratios. Other observed clearing remains: the all-predefined sequence-spec
shortcut writes `0x3030` bytes, and the raw literal-section local optional
tree writes `0x402` bytes. Related prior experiments were neutral or negative;
this increment targets the independently confirmed Huffman-state null result.

## End-to-end comparison

The existing public `tools/zstd/reference_bench.zig` harness compares identical
Silesia inputs and encoded frames with native libzstd 1.6.0. The reference is
clean source `01b7154f1172432f8abe9b3bb9909e14a1176b7d`, GCC 11.4.0
`-O3 -march=skylake`, with x86 assembly enabled. Each process uses five
alternating Vort/reference rounds at 64 iterations and retains each side's
minimum. The outer screen alternates baseline/candidate process order over
five sweeps. Input/output address offsets are both 1 modulo 128.

The 96 rows cover twelve sources, 64 KiB/1 MiB, levels 3/9 and one-shot/reusable
APIs. All 960 processes verify full content against both the original input
and reference output, as well as input SHA/encoded-size bindings.
[The per-row CSV](optional-huffman-state-20261102.csv) retains medians and wins.

| Mozilla 1 MiB level 3 | Baseline ns | Candidate ns | Median paired time ratio | Wins |
| --- | ---: | ---: | ---: | ---: |
| One-shot | 524,231 | 462,517 | 0.87681 | 5/5 |
| Reusable | 525,079 | 461,214 | 0.88053 | 5/5 |

Target latency falls about 12.3%/11.9%. The twelve-source 1 MiB level-3 group
improves 1.30% one-shot and 1.38% reusable geometrically; the other groups stay
within roughly 0.3% of baseline. This remains workload-dependent. Current
target latency is still approximately 1.79x native libzstd in-process.

An initial Samba 64 KiB level-9 reusable row measured 1.01783 paired latency.
Fifteen longer pairs at 1,024 iterations resolve it to 1.00035 median /
1.00004 geometric latency, with 6/15 wins. The initial observation is preserved
in the CSV and the longer raw control is retained separately.

Before module extraction, fifteen pure-decoder pairs at 1,000 iterations
measured 0.87957 median / 0.87968 geometric latency, all 15 wins. The public API
matrix above verifies the retained modular implementation.

## Validation and reproduction

Three dependency-injected reference groups compare independent local
tree/lookup/cursor construction with the caller-owned initializer. Debug,
ReleaseSafe and ReleaseFast each pass 12/12 selected tests, including:

- poisoned raw/RLE storage and real guards, plus transitions back to raw/RLE;
- three compressed and one treeless block, one single-stream and three
  four-stream sections, byte/cursor/decoded parity after partial and full
  decoding, same-pointer ownership and reset/reuse;
- twelve initialization CorruptFrame pairs, four TruncatedFrame pairs and two
  decode CorruptFrame pairs with untouched state guards.

The complete ReleaseSafe Zstd suite passes 1,260/1,260. All nine upstream
decodecorpus campaigns pass: 9,900 frames, 64/64 sequence modes, and 5,376
bounded block-stream cases with zero decoded scratch length/capacity.
The complete `check check-wasm` compile gate passes 212/212 steps for the
retained source.

Generated evidence is in `zig-out/zstd-sequence-20261102`: pure-decoder source,
before/after perf samples, static route probe, public-harness binaries,
`matrix.py`, raw matrix rows, long Samba control and validation logs.

| Binding | SHA-256 |
| --- | --- |
| Public-harness baseline | `c96faf13f4f087601650a1a8f7a7fcb04a9f46e1caa836bfcfdb48836d2fce77` |
| Public-harness candidate | `26310a48c566b18b54e15a0395f670b4a8a5455ca1c70e485e14cd990cbfd312` |
| Input/wire manifest | `580d147612aa0cd664587e88f2c61f7009e27d5b33722e61af1c6750709025ee` |
| Full matrix report | `835417ce25ee2d14f48dd09bd9e012951421246758a1eca62805aea9a9faec3a` |

The normal build surface calls the same public API harness:

```sh
taskset -c 2 zig build -Dtarget=x86_64-linux-gnu -Dcpu=skylake+pku+sgx run-zstd-reference-bench -- \
  --input zig-out/deflate-lazy-20261102/corpus/mozilla.1m.bin \
  --encoded-input zig-out/zstd-small-fse-20261102/corpus/mozilla.1m.zstd.3.zst \
  --name mozilla-1m-l3 --level 3 --iterations 512 \
  --libzstd zig-out/zstd-sequence-20261102/libzstd.so.1.6.0 \
  --input-offset 1 --output-offset 1
```

Future sequence work can target the sixteen raw-literal
predefined/compressed/predefined blocks (804 generic sequences) and the dense
split-Huffman executor. Neither is claimed optimized by this increment.
