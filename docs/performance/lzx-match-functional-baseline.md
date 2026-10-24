# LZX adaptive match functional baseline

Date: 2026-10-23. Zig 0.16.0, Linux x86-64, ReleaseFast probe. The independent
references are unmodified wimlib 1.14.5 at `cd5e231c`, libmspack at `55d50197`,
and system libarchive. This records wire correctness and compressed sizes;
throughput, peak-memory parity and optimal-parser leadership are not claimed.

```sh
zig build run-lzx-match-diff -Doptimize=ReleaseFast -- \
  --wimlib-dir /path/to/pinned-wimlib \
  --mspack-dir /path/to/libmspack --report /tmp/lzx-matches.json
```

The 136-row matrix includes 42 CAB frames independently decoded by both
libarchive and libmspack, 85 WIM chunks decoded by wimlib, six WOF streams whose
compressed chunks decode through wimlib, and three matched multi-cabinet sets
decoded by libmspack. All paths also verify native bytes and deterministic
re-encoding. CAB set parts are at most 2 KiB, forcing compressed CFDATA fragments
to continue across cabinets. The WIM matrix includes every 15...21-bit window,
one/two/three-byte outputs, odd/partial chunks, aligned offsets, mixed
raw/compressed transitions, E8 boundary targets and a complete 2 MiB chunk.

For WIM, every selected complete stream is no larger than the retained Vort
reference which used 3...8-byte explicit matches and a fixed main tree. CAB
chooses the complete compressed/raw frame representation; WOF retains raw
chunks unless compression saves bytes. These are size-selection contracts,
not claims that Vort beats wimlib's compressor.

| WIM case | Window bits | Input bytes | Old Vort reference | Adaptive matched output |
| --- | ---: | ---: | ---: | ---: |
| repeated text | 15 | 32768 | 6858 | 120 |
| aligned offset records | 15 | 20480 | 12928 | 9520 |
| binary prefix repetition | 15 | 32768 | 17750 | 8404 |
| repeated text, multiple plans | 17 | 66000 | 13616 | 246 |
| complete wide chunk | 21 | 2097152 | 1521290 | 70816 |

The 66,000-byte repeated text produces a 348-byte CAB and a 334-byte WOF
backing stream. A mixed 98,318-byte family produces a 33,158-byte CAB and a
33,034-byte WOF stream, retaining the irreducible 32 KiB random block. WOF's
independent 32 KiB chunks intentionally reset match history, unlike CAB folder
history. Comparing their total sizes without that distinction would hide a
different framing/history contract.

The bounded matcher requests 512 KiB of two-/three-byte hash storage and stores
items for one 32 KiB plan. CAB borrows selected-window history; WIM additionally
owns its transformed chunk and candidate/reference output. Default throughput,
quality levels, optimal parsing, persistent hash reuse and cross-reference
memory measurements remain future work.

Exact input/output hashes, reference versions/commits, probe hash and source
digests are retained in [the JSON](data/lzx-matching-x86-20261023.json).
