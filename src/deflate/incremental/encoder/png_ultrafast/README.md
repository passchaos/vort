# Incremental PNG ultrafast

`vort.ZlibIncrementalPngUltraFastEncoder` (also `vort.deflate` namespace) provides
`init`, `initWithOptions`, `initExactSize`, `step`, `flush`, `finish`, `snapshot`,
`reset`, and `deinit` with the same caller-buffer progress convention as the
existing incremental zlib encoders. `Options.max_input_len` is a hard input cap.
An exact pledge above that cap, excess offered input, arithmetic overflow and
premature finish are typed errors. No preset dictionary is accepted; no FDICT
or CRC is emitted, and Adler covers accepted input only.

The core uses the actual existing PNG-trained dynamic Huffman tree and
distance-one zero run encoding. It carries the full stream's eight-byte source
grouping between calls, including up to seven tail bytes and an uncommitted zero
run count. No-flush output is exactly independent of input/output partitions.
Tail literals and zero run token choices follow the original full-slice encoder,
which matches a single full-source `write_data` call in pinned fdeflate.

Framing differs from old one-shot output: the dynamic block starts with
`BFINAL=0`. Finish writes its EOB then an empty final stored block before Adler.
This lets `flush` close a dynamic block, emit an empty non-final stored block at
a byte boundary, and resume the same trained tree without restarting zlib.
After flush, empty-input steps drain to `need_input` before new source is
offered. Accepted bytes are then immediately inflatable by an independent zlib
decoder. Explicit flush is a block boundary and can change bytes/token choices;
the deterministic no-flush contract does not compare different flush schedules.

All mutable state is inline: `pending_capacity=128`, `input_carry_bytes=8`,
scalar reservoir/run/accounting fields, and streaming Adler. The allocator
parameter keeps constructor compatibility but the core allocates zero heap
bytes (`heap_workspace_bytes=0`) and has no separate scratch array
(`stack_scratch_bytes=0`). An owning container charges `@sizeOf(Encoder)` as part
of its own context. There are no input-sized block buffers, match tables,
tokens, retained full input, output frame, or address-sensitive allocator links.

The original one-shot numeric implementation and goldens remain unchanged.
Only a read-only syntax namespace exposes the canonical header, lengths, codes
and RFC length selection to this module.

Independent reference tools under `tools/png_incremental_ultrafast` call clean
pinned fdeflate once per full source, parse actual RFC1951 bits through the EOB,
clear only the first BFINAL bit, insert the final stored header before original
padding, realign and retain original Adler. New expected bytes never come from
this core. 544 source cases cover every literal, zero run/word/tail boundaries,
large runs and all eight EOB bit alignments. Python system zlib validates all
expected/actual streams and explicit flush prefixes. Near tests retain 30 actual
reference vectors alongside partition/limit/flush checks.
