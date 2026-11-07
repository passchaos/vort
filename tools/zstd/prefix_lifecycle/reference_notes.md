# Prefix lifecycle reference

This is an independent libzstd oracle, not a model of Vort implementation
internals. It loads an existing library and matching local header without
building or modifying the shared zstd checkout. The observed library is 1.6.0.
`fixtures.generate(root, library)` replays the retained audit and writes a JSON
receipt, fixed bytes, staged results and decoded outputs into the supplied root.

## Retained observations

Hooke's `/tmp/vort-zstd-prefix-audit-c1c6206e/probe.py` produced 188 observation
records plus a summary, with all assertions passing. `reference/audit_probe.py`
retains that program; only the library and testdata paths are parameterized,
with a module docstring and `sys` import added. `audit_baseline.jsonl` retains
the original 189 lines verbatim. The comparison normalizes only the spelling
of `environment.lib`, because resolving a library symlink changes that path.
All other record fields must match, including return codes, exact errors,
accepted byte counts, output lengths and follow-up correctness.

Original audit source SHA256:
`4bfd87969ff2dd7bb745fee9485b683f35d2ed77f3e960c292b391c6926380ff`

Original/retained observation SHA256:
`8e719160c1726ba5778652c3f4b55c5082b2f5e16c09ee43a3854f60ec036be8`

Actual library SHA256:
`c76f4c4457df67a5e0c7bb6bb4f58b9857cf4f2cdd7925bfb9345daac4e6b83e`

Matching `zstd.h` SHA256:
`17d279cd45a6881e87eb1801e08d2d29be200ff47811a1ff3168947cad2029bd`

## Empirical lifecycle facts

- Default `CCtx_refPrefix` and `DCtx_refPrefix` interpret even standard
  dictionary-looking bytes as RAW. Advanced auto/full interpretation decodes
  the archived full-entropy frame; default RAW does not.
- Prefix selection invalidates the previous persistent dictionary. After the
  once prefix is consumed, that persistent dictionary does not return. Loading
  a persistent dictionary replaces a pending prefix, and persistence permits
  repeated frames. A NULL/zero prefix clears both kinds of previous selection.
- A successful encoder frame consumes its prefix. Even an empty `continue`
  initializes compression; resetting that session does not restore the prefix.
  An invalid compression directive is rejected before initialization, so its
  pending prefix survives session reset. Small one-shot destinations and bad
  source pledges fail after initialization and do not restore the prefix.
- One `decompressDCtx` call shares the selected prefix across all concatenated
  data frames in that call, including standard skippable metadata before data.
  Separate one-shot calls cannot reuse it. Even empty input or a rejected
  header in a one-shot attempt removes that pending prefix.
- Streaming consumes the prefix when its first valid complete header is
  initialized, including a standard skippable header and an empty data frame.
  A partial header or invalid header keeps the pending prefix through a
  session-only reset. A complete header, checksum failure or truncated footer
  after frame initialization does not restore it. Error output may already
  equal the payload even though checksum verification failed.
- Streaming stops at a frame boundary with return 0; the recorded input count
  identifies the unaccepted next member. Following dependent frames fail unless
  rearmed. One-shot concatenation and streaming have different prefix scopes.
- Standard skippable bytes supplied in **magicless mode** are parsed as
  magicless data. The actual records include dictionary/source-size errors and
  incomplete data; they are not evidence of successful metadata skipping.
- Session reset preserves pending selection and format/checksum parameters.
  Parameter reset and combined reset clear pending selection and restore the
  default format. Parameter reset and refPrefix are rejected during an active
  stream. Persistent dictionaries survive fatal checksum errors plus a
  session-only reset. `initDStream` clears dictionaries, whereas `resetDStream`
  preserves a pending prefix.
- Invalid FULL bytes are accepted by C refPrefix and rejected when compression
  initializes. D refPrefix rejects them immediately with the actual error
  `Allocation error : not enough memory`, after losing its old persistent
  dictionary. These two recipes are C ABI facts. Vort's typed setter accepts
  an already validated `NativeDictionary`; it must not manufacture an invalid
  typed dictionary merely to reproduce the C byte-input boundary.

## Driver interfaces and comparisons

`Library.context("C" | "D", format="standard" | "magicless")` owns one
context. Its low-level `ref_prefix`, `load_dictionary`, `reset`, `set_parameter`,
`pledge`, `encode_one_shot`, `decode_one_shot`, `encode_step`, `decode_step`,
`drive_encode` and `drive_decode` return actual C result dictionaries; coding
operations also return bytes. Errors are retained so recovery stages can run.
`drive_decode(..., stop_at_frame=True)` returns at the first boundary. A
nonzero hint after all input is exhausted is recorded as `incomplete`, while
the underlying C result still has no error.

Snapshots contain only public `getParameter` results and actual API progress
counters. They contain no invented pending-prefix fields. Each recipe records
`semantic_inference` separately and labels that inference explicitly. The
driver should retain C snapshots as observations and compare Vort's public
prefix snapshot to lifecycle consequences established by follow-up calls.

The fixture receipt exposes `assets`, `frames`, `cases`, `audit` and
`receipt_path`. Each case includes provider, side, format, streaming, kind,
preflight, vort_supported and typed_boundary. Each stage includes operation,
arguments with input paths, provider, frames, observable_result, expected and
snapshot. Error categories help adaptation; exact C error strings remain in
the receipt. The 188 audit observations and the curated recipe count are
separate measurements, not the number of Vort cases.

Encoded C frame hashes document the C oracle's deterministic result. A Vort
encoder may produce different valid block bytes. Use
`Library.validate_prefix_wire(wire, prefix, payload, kind=..., format=...)` to
check its generated bytes with C: correct prefix must reproduce the payload,
missing prefix must fail or change output, and changed history must fail or
change output. For FULL, the latter control preserves all header bytes,
dictionary ID, entropy tables and repcodes and XORs only dictionary history.
All 18 fixed C prefix frames pass this stronger history-dependency control.
A valid Vort FULL frame may instead require initial dictionary entropy tables
while encoding history matches independently. `history_dependency` retains its
specific meaning; `entropy_dependency` records a separate strong control and
`prefix_dependency` is their union. RAW still requires history dependence.

The entropy control removes only the frame Dictionary_ID field and clears its
descriptor bits, then verifies a successful normalized FULL decode. It loads
exactly the same dictionary history with advanced `rawContent=1` and requires
an actual decode-stage corruption/checksum error. FULL repcodes are parsed from
the final 12 dictionary-header bytes and must equal RAW defaults `[1,4,8]`.
Those defaults and their reset copy are recorded from matching local reference
source when available. Raw binding failures, ID mismatches, limits and truncated
input cannot prove entropy dependence. No production entropy mode is guessed.

Library/header/reference/helper/fixture/note hashes, actual decode hashes,
retained/observed audit hashes and errors are recorded by the live preflight.
