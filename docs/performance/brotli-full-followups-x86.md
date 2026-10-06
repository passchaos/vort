# x86-64 Brotli full-tier follow-up experiments

Date: 2026-10-06. Baseline: `b1c327d1`. Host: Intel Core i7-10700K,
Linux x86-64, Zig 0.16.0, ReleaseFast, CPU 2, one codec thread. Reference
context: local libbrotli 1.2.0-dev (`558fc647`).

## Scope

The retained full-tier UTF-8 and direct-distance-context changes leave the
roadmap q9/q5 rows at about 0.78x/0.79x local libbrotli. This follow-up compared
the generated paired payload with libbrotli's `ProcessCommands` loop and tested
five adjacent ways to reduce reader, distance, or literal-loop work.

All measurements use the frozen 1,251,399-byte roadmap input and its unchanged
335,220/350,069-byte q9/q5 frames. Each process performs 500 decodes, launch
order alternates on CPU 2, and a 0.2-second `ps -C zig` monitor rejects every
attempt that overlaps another Zig process. The benchmark verifies decoded size
and checksum on every run.

## Results

| Candidate | Code shape | q9 median / geometric, wins | q5 median / geometric, wins | Decision |
| --- | --- | ---: | ---: | --- |
| payload-local reader copy | selected `0x14c0` -> `0x1c40`; paired +4,032 B | 1.0039x / 1.0035x, 5/7 | 0.9990x / 0.9966x, 3/7 | reject |
| outlined reader byte tail | selected `0x14c0` -> `0x1381`; paired -640 B | 0.9998x / 0.9991x, 3/6 | 0.9932x / 0.9980x, 1/5 | reject |
| full-tier zero postfix | zero-postfix instance `0x14b0`; paired +5,424 B | 0.9944x / 0.9957x, 2/7 | 0.9992x / 1.0011x, 3/7 | reject |
| isolated zero-postfix fallback | target only +128 B in address; separate 5,312 B fallback | 0.9972x / 0.9956x, 1/5 | 0.9912x / 0.9949x, 1/5 | reject |
| literal countdown first | selected +45 B; downstream sections unchanged | 0.9919x / 0.9937x, 1/7 | 0.9974x / 0.9973x, 2/7 | reject |

The payload-local reader did reduce possible pointer aliasing, but synchronizing
the private reader across every error exit expanded both payload instances by
roughly two KiB. Its small q9 movement did not survive q5.

Outlining the byte-at-a-time logical tail reduced every wide decoder section,
but that tail is already cold and the new call/layout did not improve complete
decode. The partial campaign is sufficient to reject it: four of five q5 pairs
lose, with a `0.9932x` median. Extensive external `spectra` builds contaminated
8 q9 and 17 q5 attempts; none of those attempts appears in the table.

Both roadmap frames use `NPOSTFIX=0, NDIRECT=0`, so the zero-postfix instance
removed the dynamic `shlx` just as the retained middle-tier specialization
does. In full-tier, however, adding another instance lost q9. Moving the
nonzero-postfix UTF-8 fallback into a separate section restored the target to
within 128 bytes of its original address but still lost both qualities. The
result therefore is not merely an instance-address artifact.

Finally, checking the local literal countdown before `block_type_count` had
helped the middle tier, but the full-tier code grew and lost consistently.
This rules out mechanically transferring that branch layout between tiers.

All production candidates were removed. Exact hashes, raw nanosecond pairs,
discarded-attempt counts, and section sizes are in
[brotli-full-followups-x86-20261006.json](data/brotli-full-followups-x86-20261006.json).

## Correctness and next direction

The reader candidate passed all six exhaustive mixed-width/logical-tail reader
tests. The zero-postfix candidates passed the three full-wide transition and
boundary tests, the exhaustive prepared-distance and truncated-suffix test,
and all 551 direct ReleaseFast Brotli tests. The rejected changes did not alter
wire output, but throughput evidence does not justify retaining them.

Further full-tier work should change the command/distance execution model
rather than add another instance or reorder a small branch. In particular, a
credible design must keep the reservoir live without duplicating exit-state
synchronization and must reduce actual regular-distance work without enlarging
`InsertCopyLengths` or introducing a hot call boundary.

The subsequent no-copy solution expresses the wrapper-owned reader's existing
non-aliasing invariant directly. Its retained implementation and measurements
are in [brotli-full-noalias-reader-x86.md](brotli-full-noalias-reader-x86.md).
