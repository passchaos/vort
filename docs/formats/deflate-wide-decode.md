# Wide incremental Deflate decode counters

Raw stored, raw full-block, zlib and gzip incremental decoders use
`core.StreamCount` for cumulative byte counts, output limits, exact output
pledges and absolute stream/member offsets. The raw full-block decoder is also
used by `Deflate64.IncrementalDecoder`, including its extended copy lengths and
64 KiB window.

`StreamCount` is `u64` on 32-bit targets and retains the original `usize` type
on 64-bit targets. Logical streams can therefore exceed 4 GiB on x86 and WASI
without requiring one buffer of that size. One-shot slice lengths remain
bounded by the platform's `usize`; they are separate from cumulative stream
lengths.

## Local and absolute coordinates

`core.Progress`, current input/output indices, block lengths, match distances,
history indices and bounded scratch capacities remain `usize`. A single call
still consumes and writes only its supplied buffers. Public counters,
snapshot offsets, error offsets, member counts and `memberEndOffset()` are
wide. Exact semantic block-start/completion statistics and their getters are
wide and checked too. `trailingPrefix()` distinguishes an accepted tail byte from
the last completed member.

Semantic generation positions are local to at most two bounded windows. They
remain `usize`; available output is first bounded by the physical window before
the wide remainder is narrowed. Counter-edge calls can continue through the
compact decoder, including buffered EOB and exact footer boundaries. Tests
verify the retained history with an actual subsequent back-reference, allowing
the semantic window to rebase its physical position.

ZIP's Deflate64 adapter converts its local optional expected size into the
shared counter type explicitly. Tests that collect a complete small fixture
likewise check a wide offset before using it as an array index. These
conversions do not impose a smaller cumulative decoder limit.

## Overflow and completion

Actual cumulative advances use checked addition. Input overflow is refused
before the failing byte/batch is accepted; output overflow is refused before
the selected token or copy span changes caller storage or history. Previously
completed work remains reflected in progress and diagnostics. At the largest
representable count, an already buffered EOB may still complete normally.

Configured smaller output limits retain their existing error or resumable
`stop_at_output_limit` behavior. Raw final stored blocks now enforce exact
output completion as fixed and semantic blocks already did. Gzip ISIZE keeps
its required modulo-2^32 representation; widening the logical output count
does not change the wire field or checksum rules.

## Validation

```sh
zig build -j4 test-deflate-wide-decode
zig build -j4 test-deflate-wide-decode -Dtarget=x86-linux
zig build -j4 test-deflate-wide-decode-wasm
zig build -j4 run-deflate-wide-decode-diff
zig build -j4 run-deflate-wide-decode-long-diff
zig test src/deflate.zig -lc
zig test src/deflate.zig -lc -target x86-linux
zig test src/deflate64.zig -target x86-linux
zig build -j8 check
```

The bounded contracts first replay small valid stored prefixes, then construct
equivalent large repeated-prefix state with independently computed Adler/CRC
and ring contents. Every suffix byte is physically decoded. Cases include
stored/fixed/dynamic, semantic and compact paths, Deflate64, dictionaries,
concatenated and empty members, member counts crossing 2^32, tail handoff,
sync/reset and synthetic counter-maximum refusal transactions. These same
contracts execute on native, x86 and wasm32-wasi.

The long driver separately processes real streams without counter seeding,
sparse plaintext files or full decoded collections. Zig 0.16.0 ReleaseFast
native and x86 probes use at most 64 KiB per input/output transfer. Python's
libz 1.2.11 generates and independently decodes the reference streams, checking
every output byte and CRC. The complete twelve-case campaign passes:

| Source and decoder | Actual compressed input | Actual decoded output |
| --- | ---: | ---: |
| Generated stored, raw stored/full | 4,295,295,003 | 4,294,967,313 |
| libz compressed raw, compact/semantic | 4,174,508 | 4,294,967,313 |
| libz compressed zlib | 4,174,514 | 4,294,967,313 |
| libz compressed gzip | 4,174,526 | 4,294,967,313 |

Each row runs on both native and 32-bit x86; raw compact and semantic are
separate cases. All output CRC values are `473974062`. The semantic run
actually completes 953 blocks. Both stored APIs cross the cumulative input
and output boundary; compressed fixtures cross the output boundary with
ordinary small files. The JSON report under
`zig-out/deflate-wide-decode-long/report.json` records actual commands,
versions, artifact/config/fixture hashes, transfer counts and reference
receipts. Decoder-owned heap peak is reported as unavailable because these
decoders have no allocator measurement hook; caller history/workspace sizes
are recorded separately.

Native and x86 complete Deflate suites each pass 654 tests; the x86 Deflate64
suite passes 118. Existing relaxed-wrapper, dictionary-resume, parameter,
Python zlib and system gzip checks remain relevant independent regressions.
This increment concerns the decoder family. Incremental encoder totals,
rolling-match positions and PNG long zero-run counters still require the
separate wide-encoder increment.

The complete x86 ZIP codec run records 2,375 passes, one platform skip and one
failure in the existing LZMA large-dictionary memory-threshold assertion. The
same assertion fails at baseline commit `4ea9d80b` in an isolated source
checkout. It is not a passed gate. Focused x86 ZIP incremental entry decoding
passes 118 tests, and the all-method owned entry test passes 93; the changed
Deflate64 size adapter is covered by those calls. LZMA code and tests are not
changed by this decoder increment.
