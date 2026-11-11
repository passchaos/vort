# Mozilla multi-block decode profiling plan, 2026-11-11

Status: read-only routing; no production change or new measurement.
Finish the incremental Deflate borrow increment and its gates first.

The complete `ea193be2` [modern decode refresh](../modern-decode-refresh-20261111.md)
measures mozilla full q11 at 2.0556x Vort/reference time. Its six paired calls
are approximately 263–267 ms versus 128–130 ms for libbrotli 1.2.0. The same
source's 1 MiB q11 row is near parity (recorded median time ratio about
0.9713x); full q6's median ratio is about 1.6447x. These conditions use
different producer frames, so length alone is
not an isolated cause. Do not use the quotient of timing medians (2.0508x)
in place of the retained paired geometric result.

## First comparison

Use three frozen rows: full mozilla q11 as target, 1 MiB mozilla q11 as the
near-parity control, and full mozilla q6 as the size/control condition.
Load their complete frame/plain hashes and producer metadata from the archive.
Preserve generic mode, window 22, cold public operation, caller buffers and
64-byte alignment, one codec thread, CPU 15, two warmup plus six AB/BA pairs.
The existing full-file batch uses one iteration; 1 MiB uses twenty.
Bind the new source, binaries and actual host state before timing. Run after
all builds finish; this development-host pilot does not replace fixed-host
acceptance or the complete 72-row competitor matrix.

## Attribute the actual production route

The public caller-buffer route is:

`brDecodeStreamInto` → `br.decodeStreamInto` → `decodeStreamPrefixInto`
→ `decodeLargeStreamPrefixInto` → `processLargeCompressedMetaBlock`
→ `processPreparedCompressedMetaBlock`.

`readMinimalCompressedHeaderInto` prepares each compressed header. Header tree
counts and auxiliary eligibility select each block's payload family. Record
that selection; the Mozilla row is not established to use the
previous NCI auxiliary path. Capture separate function-root-filtered perf
call graphs for `brDecodeStreamInto` and `BrotliDecoderDecompress`, then add a
diagnostic per-meta-block breakdown of header parsing, table/lookup setup,
payload execution, block sizes and selected payload family. Record tree/block
counts, NPOSTFIX/NDIRECT and fallback reasons; weight routes by both calls and
decoded bytes. Payload sampling can separate command/extra bits, literals/
context, distance/block switching, LZ copy and dictionary transforms. Record
token/copy distributions without reading a clock for every symbol.

In `tools/decode/compare.zig`, caller-output clearing around line 313 and
`validateBatch` around line 326 are outside the timer. Whole-process profiles
include that work and must not label it as codec time. Vort's Into route uses
automatic entropy/lookups and direct caller output without staging or heap
allocation. The foreign cold API includes state setup, its internal scratch/
ring allocation and cleanup inside the timed operation.

The current clustered stage profiler in `src/br.zig` accepts a single final
compressed block, so it cannot directly attribute the full Mozilla frame.
`profileCompressedHeaders` supports multi-block discovery, but its
`collectCompressedHeaderStarts` materializes output through an ArrayList;
those diagnostic allocations are not production Into allocations. Keep
diagnostic instrumentation separate from unchanged whole-operation timing.

After route attribution, choose a bounded structural/kernel candidate and
compare interleaved complete operations. Retain exact outputs, raw samples,
memory scope, negative controls and the repository's confidence/0.98x control
floor. No phase-fusion or auxiliary-path gain is predicted by this plan.
