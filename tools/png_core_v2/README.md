# PNG incremental core v2

The before binary uses published52b6ce3 plus the exact frozen row-v1 source from
the root combined benchmark. The candidate changes only incremental core files.
The full 15-image90,083,998-byte corpus and both adaptive/Up filters are preserved.
Four independent rounds reverse case/implementation order and pair fresh Rust
from the same immutable executable. Encoder/output creation, full encode, finish
and destroy are in the timer; input I/O/decode/SHA/allocator counters are outside.
CPU13 was held exclusively by this worker; row-v2 timers waited for release.

Batch-local reservoir/run state reduces repeated encoder field accesses.
When caller output has at least128bytes and is disjoint from the current source,
encoded bytes go directly to that valid output span; small/overlapping slices
use the original128byte queue. A fused Adler accumulator reuses the token scan's
loaded word: eight-byte u16 weighted sums or zero-span recurrence are reduced
once per at-most4096-byte accepted batch. The little-endian word is converted
to native byte lanes on big-endian targets. Caller source is never checksummed
beyond reported accepted input, and context/queue/carry/heap limits do not grow.

All streams preserve static tree, zeroRLE, first block BFINAL0, noFDICT, sync
flush EOB/stored framing, final stored block and Adler. Frozen69scalar and52v1
control compare exact output for equal flush schedules; guards and progress/
snapshots are tested for direct and queued capacities. Public fdeflate RFC EOB
framing/zlib checks pass544cases/1727checks in Debug and ReleaseFast.

| Scope | Geometric speedup | Aggregate speedup | New/Rust ratio |
|---|---:|---:|---:|
| all | 1.1800x | 1.1808x | 0.7122 |
| adaptive | 1.1417x | 1.1530x | 0.8068 |
| up | 1.2195x | 1.2205x | 0.6288 |

The all-case fresh Rust speed ratio improves from0.6036
to0.7122; a remaining gap is explicit. These are directly
measured core-v2 effects, without row-v2 code or multiplied older batch ratios.
All30complete PNG bytes, sizes, independent libpng/image-png pixel outputs and
requested heap/workspace peaks are exact to before; live allocation after destroy
is zero. Mutable context remains the same size with128pending/8carry/noheap.

Evidence in `/nav_env/Temp/vort-png-core-v2/full-real/`: samples.json360records,
validation.json, summary.json. Source binding and current52weak profiles are in
the parent. SummarySHA `62653f15810b8daa38d344897998f155fbf26a594a166e57403638abf7657295`.

Reproduction uses run.py validate then bench with --old/--new and --rounds4.
The frozen row1consumer verification uses verify_consumer.py; it does not edit
consumer source. Only clean Vort clone Git delivery is performed by this worker;
primary's2WIP and published pin stay untouched for central integration.
