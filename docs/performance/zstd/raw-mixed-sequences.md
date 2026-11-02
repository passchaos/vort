# Raw predefined/compressed/predefined sequences, 2026-11-02

Raw literal blocks with predefined literal/match tables and a compressed
offset table now select a fixed-mode executor once per block. This removes
the generic reader's repeated mode selection from each sequence. The shared
literal and history-copy helpers retain their output, dictionary and error
rules; continuation tables and repcodes commit only after the complete block.

The cohesive `src/zstd/sequence/raw_mixed.zig` module owns fixed-mode entropy
reads and block execution. A proved 64-bit suffix can supply a field group of
at most 56 bits. Each field separately advances the reader before offset
resolution and transitions, matching generic progress on errors. Larger
groups and physical tails use exact checked reads. This adds no allocation or
persistent state and leaves other sequence shapes on their existing routes.

## Workload and protocol

The Mozilla 1 MiB level-3 frame contains sixteen raw literal blocks in mode
`0x20` (LL predefined, OF compressed, ML predefined), totaling 804 sequences.
They formerly ran through the generic sequence reader. The frame's four dense
split-Huffman blocks contain 15,260 sequences and remain separate targets.

Baseline codec source: `1614d6bf`. Both sides use the existing public
`tools/zstd/reference_bench.zig` harness, Zig 0.16.0 ReleaseFast,
`x86_64-linux-gnu -mcpu=skylake+pku+sgx`, logical CPU2 on an Intel Core
i7-10700K. Decoding uses one thread, input/output address offsets 1 modulo 128.
Reference: native libzstd 1.6.0, clean source
`01b7154f1172432f8abe9b3bb9909e14a1176b7d`, GCC 11.4.0
`-O3 -march=skylake`, x86 assembly enabled.

Each process alternates Vort/reference timing five times at 64 iterations,
retaining each side's minimum; loading, allocation and full output comparison
are outside the decode interval. Five outer sweeps alternate baseline/candidate
process order. Twelve Silesia sources, 64 KiB/1 MiB prefixes, levels 3/9 and
one-shot/reusable APIs give 96 rows and 960 verified processes. Every process
checks complete input/reference output and input SHA/encoded-size bindings.

## Results

| Mozilla 1 MiB level 3 | Baseline ns | Candidate ns | Median paired time ratio | Wins |
| --- | ---: | ---: | ---: | ---: |
| One-shot | 459,322 | 445,545 | 0.97018 | 5/5 |
| Reusable | 460,558 | 443,785 | 0.96770 | 5/5 |

Target latency improves about 3.0%/3.2%. Whole-matrix group geometric ratios
range from 0.99433 to 1.00082, so the larger target gain is limited to blocks
with this sequence shape. [Per-row CSV](raw-mixed-sequences-20261102.csv)
retains all medians and paired win counts, including noisy controls.
The target's candidate latency remains approximately 1.72x native libzstd
in the same-process reference rows.

Two initial controls were 1.01097 (MR 64 KiB level 3 one-shot) and 1.01296
(NCI 1 MiB level 9 reusable). Fifteen longer pairs at 512 iterations resolve
them to 1.00276/1.00186 and 1.00227/1.00109 median/geometric latency,
respectively. NCI has no generic raw mixed blocks, so its small remaining
movement is a control rather than direct executor work. The same long screen
confirms Mozilla at 0.96911 median / 0.96965 geometric latency, all 15 wins.

Before module extraction, fifteen pure caller-buffer decoder pairs at 1,000
iterations improved Mozilla by 0.96409 median / 0.95876 geometric latency,
with 15/15 wins. The public matrix above measures the retained modular code.
Neither comparison establishes broader Zstd leadership.

## Reference validation

An independent generic reader/block loop compares decoded fields, reader bits,
LL/ML/OF states, repcodes, committed output and continuation tables. Debug,
ReleaseSafe and ReleaseFast selected runs each pass 10/10 tests, comprising
one named oracle plus imported anonymous tests. The oracle covers:

- 32,078 sequence pairs and 1,336 reader error pairs;
- 592 bit modifications and 715 truncations, invalid states and a grouped
  repcode error with exact reader progress;
- 1,322 block executor pairs, including every short-output length, output
  guards, prefix history, dictionaries, zero literals and offset extras;
- an equivalent serialized raw `0x20` frame through one-shot and two calls
  of the same reusable decoder, requiring actual path selection each time.

The complete ReleaseSafe Zstd suite passes 1,261/1,261 tests. All nine upstream
decodecorpus campaigns pass 9,900 frames and 64/64 sequence modes, with 5,376
bounded block-stream cases and zero decoded scratch length/capacity.
The complete `check check-wasm` compile gate passes 212/212 steps for the
retained source.

## Evidence and reproduction

Generated evidence is retained in `zig-out/zstd-raw-mixed-20261102`: pure and
public-harness binaries, `matrix.py`, raw observations, long controls, static
Mozilla block-shape records and validation logs. After final tests were added,
a rebuild has identical bytes in all 23 executable sections to the measured
candidate.

| Binding | SHA-256 |
| --- | --- |
| Public-harness baseline | `26310a48c566b18b54e15a0395f670b4a8a5455ca1c70e485e14cd990cbfd312` |
| Public-harness candidate | `dbaccca3fe392c81cf01d80fd93fe4f464ab7da0d2724fdc8027475004bb8e89` |
| Input/wire manifest | `580d147612aa0cd664587e88f2c61f7009e27d5b33722e61af1c6750709025ee` |
| Full matrix report | `6955c360d5985c6c38079ca96b6d8e5c0a7c8f7ea3b18daab97838b5da075743` |

The normal build surface uses the same public harness:

```sh
taskset -c 2 zig build -Dtarget=x86_64-linux-gnu -Dcpu=skylake+pku+sgx run-zstd-reference-bench -- \
  --input zig-out/deflate-lazy-20261102/corpus/mozilla.1m.bin \
  --encoded-input zig-out/zstd-small-fse-20261102/corpus/mozilla.1m.zstd.3.zst \
  --name mozilla-1m-l3 --level 3 --iterations 512 \
  --libzstd zig-out/zstd-raw-mixed-20261102/libzstd.so.1.6.0 \
  --input-offset 1 --output-offset 1
```

Remaining targets include the dense split-Huffman executor, Deflate's
one-shot constant factors and Brotli payload work. The full three-format
industry-best objective remains active.
