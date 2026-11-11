# Incremental Deflate step borrows

Raw Deflate/Deflate64, the Stored-only decoder, zlib, gzip and automatic wrapper
decoding admit a complete public `step` or `stepToBlockBoundary` call before
changing pause flags, progress, diagnostics, checksums or caller memory.
Conflicting borrows return `InvalidBlockPlan` without modifying those values.
Ordinary malformed-data errors retain their established partial progress.

The complete offered input, effective caller-output prefix, complete public
decoder object and compact history must be disjoint. History means the full
format window, including currently empty slots: literals/stored output and
end-of-step ring recording can write them, and matches still read the previous
ring until recording. Output equal to a ring destination is not supported,
because the ring copier requires nonoverlapping ranges. Internal LZ recurrences
in already-produced caller output remain supported.

Writer bounds follow actual physical clipping and counter capacity. Raw
`stop_at_output_limit` permits an unused output tail to share input or state.
An ordinary max/expected option alone cannot prove that tail is unused: a
pending stored payload or match may have been accepted before the caller
changed the option. Empty slices carry no conflicting byte range.

Input is borrowed for the complete public call. A wrapper may first drain raw
pending output with empty input; that drain must still preserve the wrapper's
offered header/payload/footer suffix. Automatic detection similarly admits
the external call before publishing a selected decoder. Its internal prefix
bootstrap remains a valid parent-to-child read.

For standard Deflate, only the first 32 KiB of a supplied 64 KiB history buffer
is active in compact mode. Without a semantic workspace, the second half may
hold input or caller output, and caller output may be reused between steps.
An attached optional workspace does not by itself make the full scratch or
table storage a writer. Before dynamic fast-path initialization, a conflict
with input, output, the public receiver, history or a retained dictionary
selects compact decoding for the call. The workspace attachment is preserved.

Once a semantic generation is active, its complete 64 KiB scratch and table
workspace are live. Conflicts refuse before draining, generation, retaining or
normalizing; even empty caller output can permit private generation writes.
Scratch's intentional containment of the compact first window remains valid.
Wrapper/auto admission protects the outer receiver, not only its raw member.

Configured zlib dictionaries and dictionary-set descriptors/bytes stay borrowed
through resets and later members. Ring/output/state writers preserve all of
them, and optional semantic admission also respects those borrows. Descriptor
extent multiplication is checked before reading entries. `provideDictionary`
copies its override into history and does not retain that source after return.

Admission lives in `src/deflate/incremental/decoder/step_borrows.zig`, outside
symbol/match loops. Ordinary and boundary calls share one admission path; no
input-sized allocation or snapshot is introduced. Independent tests live under
`src/deflate/incremental/tests/step_borrows/` with RFC wire fixtures, full-state
refusal snapshots and successful independent retries.

The public-root before probe at `17058d81` decoded two valid Stored blocks as
`abcabc` instead of `abcdef` when the first output replaced the second unread
payload. This contract prevents that silent successful corruption.
