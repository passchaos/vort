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

The optimized path consumes complete words directly, batches up to 4096 accepted
source bytes, and scans 64-byte zero spans without adding owned input storage.
It packs literals four at a time and emits reservoir words into valid pending
capacity; stores may overlap unused queue bytes, while only complete bytes are
published. Adler is updated before those accepted source bytes can be affected
by caller output writes. Already-proven all-zero batches use the equivalent
recurrence `b += n*a (mod 65521)`; mixed batches use the existing checksum kernel.
No context fields, heap allocation, pending capacity or input carry limits grow.
The frozen scalar state machine and independent fdeflate framing tests compare
all output bytes, including identical explicit flush schedules. The full real
benchmark under `tools/png_ultrafast_performance` uses an immutable 90,083,998-byte
15-image corpus, both adaptive and Up, and one unchanged imx consumer/harness.

Core v2 uses batch-local reservoir and zero-run fields. With sufficient disjoint
caller output, complete bytes are emitted directly; small output and overlapping
source/output use the same bounded queue. The token scan also computes Adler
from its already-loaded words, using eight-byte u16 weighted folds and zero-span
recurrence within the same4096-byte/NMAX bound. A native-lane conversion preserves
byte order on big-endian targets. No fields, owned buffers or heap allocations
are added. Frozen published52byte/schedule/snapshot controls and independent
fdeflate/zlib tests cover this path alongside the original scalar reference.

Zero-word prefixes now scan once up to the current 4096-byte Adler batch limit,
using complete 64-byte folds followed by complete scalar words. The first
nonzero word and partial tail remain with the normal token/carry logic. A single
equivalent `b += n*a` recurrence covers the proven prefix. Encoder fields,
reported progress, token decisions, flush framing and requested heap stay exact.
The incremental test registry imports this owning module explicitly. Debug and
ReleaseFast run all fourteen core/reference/boundary checks; baseline x86 and
big-endian PowerPC compile the same controls. The independent fdeflate/zlib
producer additionally passes 544 cases and 1727 partition/flush checks.

Five paired process-CPU rounds through the unchanged imx batch-row consumer
measure 1.156058x geomean and 1.137714x aggregate complete-encode speedup over
the fused-word core, with all thirty PNG buffers and allocator records exact.
Transparency/Up improves 2.212539x and the 128-pixel icon/Up 1.247436x; the
smallest case ratio is 1.009652x. This is the complete real-corpus fastest-stream
scope, not a result for every compression level or platform. Frozen samples,
source/binary hashes and original reference reports are retained under
`/nav_env/Temp/imx-png-small-up/`; imx's evidence records default integration.
