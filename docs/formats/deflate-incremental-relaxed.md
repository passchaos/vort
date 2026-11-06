# Incremental Deflate wrapper checks and member tails

`ZlibIncrementalDecoder.Options` exposes `ignore_adler` and
`allow_trailing_data`. `GzipIncrementalDecoder.Options` exposes
`ignore_crc32`, `ignore_isize` and `allow_trailing_data`. All defaults remain
strict. The three comparison switches are independent: ignoring CRC does not
ignore ISIZE, and ignoring Adler does not skip preset dictionary verification.
Gzip FHCRC, header rules and metadata limits remain strict.

Even with every comparison disabled, the wrapper must receive its complete
footer: four bytes for zlib, eight for gzip. Hashes and output counters continue
to update. Caller output limits and `expected_output_len` remain enforced,
including cumulative limits across concatenated and empty members.

## Recognizing another member

In single-member mode, trailing allowance stops at the completed member and
leaves subsequent input with the caller. With `allow_concatenated = true`, the
decoder first recognizes the following two-byte prefix:

- zlib: DEFLATE CMF, a valid CINFO and FCHECK in CMF/FLG;
- gzip: the complete `1f 8b` magic.

A recognized prefix commits another member. Its remaining header, DICTID,
optional metadata, FHCRC, payload and footer must then validate. A damaged
member is not ordinary trailing data. History and checksum state reset only
when the next member is committed; output limits remain cumulative.

This rule also applies to whole-input concatenated decoders, their stored
prechecks, alloc/append/exact/chunked facades and probes. It corrects earlier
trailing allowance that caught every next-header error, including a real
second member's `NeedDictionary` or corrupt FHCRC. Probe summaries now report
the last accepted member's offset rather than the trailing suffix's offset.

System libz 1.2.11 `gzread` confirms strict errors after complete gzip magic
for a bad method, reserved flags, bad FHCRC and truncated header. It ignores
ordinary trailing bytes and a lone `1f` at EOF. Gzip CLI 1.10 is stricter for
that lone-byte EOF case. The library follows `gzread` for this boundary.

## Returning a split tail

Recognition retains at most one unconfirmed byte across calls. If that byte
could start a member, `step` accepts it and returns `need_input`; a later
nonmatching byte stays unconsumed. On completion:

- `memberEndOffset()` returns the absolute end of the last footer accepted
  under the selected checks, or null before any member completes;
- `trailingPrefix()` borrows the already accepted, unconfirmed tail prefix;
- the current call's `input[progress.input_read..]` holds the remaining tail.

Concatenate `trailingPrefix()` with that unconsumed suffix to recover the tail
exactly. The prefix remains borrowed from decoder state until reset or reuse.
`total_input` counts accepted input, so it may exceed `memberEndOffset()` by
one. Snapshot `stream_input` / `member_input` exclude this tail byte from the
completed member's size. Header recognition uses two fixed bytes and adds no
heap allocation or unbounded metadata retention.

After input ends with one unconfirmed byte, `finish()` completes the validated
members and makes that byte available as trailing prefix. A complete recognized
prefix followed by a missing header/body/footer is still truncated input.
`finish()` seals further input; nonempty input afterward is rejected. Zlib's
unresolved dictionary request still returns `NeedDictionary` without sealing,
so the caller can supply the dictionary and resubmit its unconsumed suffix.

## Progress and errors

Gzip now reports `last_step_progress` and `last_error_output_offset`, matching
zlib's progress contract. Raw decoding can consume input or produce an output
prefix before returning an error. The wrapper records those bytes and updates
CRC before publishing its error and diagnostics. Each step's progress equals
the difference in cumulative counters. Reset clears progress and diagnostics.

The metadata state machine also continues from filename to comment while input
is still available; it no longer requests more input before processing the
current call's remaining comment and FHCRC bytes. Existing raw block-boundary
stepping and empty-output EOB/footer draining remain available.

## Validation

```sh
zig build -j4 test-deflate-incremental-relaxed
zig build -j4 run-deflate-incremental-relaxed-interop
zig build -j4 test-deflate-incremental-relaxed-wasm
zig test src/deflate.zig -lc
zig build -j4 run-zlib-relaxed-report-gate run-zlib-dictionary-resume-diff
zig build -j4 run-python-zlib-diff run-gzip-cli-diff
zig build -j8 check
```

The permanent libz gate generates compressed frames with system libz 1.2.11,
then tests Vort with one-byte input, three-byte output and empty output drains.
It passes 593 cases: 143 valid splits, 328 footer comparisons, 80 partial
footers, two malformed payloads, 24 tails, eight dictionary cases and eight
recognized gzip-header cases. C inflate independently checks committed member
errors; C Adler/CRC provide footer references. The report also checks 256
finish seals and 57,230 steps, including 952 zero-output steps.

The wasm32-wasi consumer checks the same public policies on a 32-bit target,
including split-tail reconstruction, member end versus accepted input, header
and dictionary errors, raw error output/CRC accounting and reset. Its Node
report records source and artifact hashes in
`zig-out/deflate-incremental-relaxed-wasm.json`. These are functional and
interoperability checks, not throughput measurements.

Final Zig 0.16.0 validation passes 631 complete Deflate tests, 13 dedicated
relaxed tests and 216 build-check steps, including the full wasm32-wasi
library. The existing relaxed report and dictionary-resume differential pass;
Python zlib records 265 successful CLI calls and 60 expected failures, and
system gzip CLI interoperability also passes. The permanent WASI gate runs
all four footer/member/header/progress groups successfully.
