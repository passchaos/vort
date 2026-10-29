# PNG long Huffman match refill, 2026-10-30

A valid dynamic DEFLATE block can place two literal-pair entries before a
long length/distance token. The semantic loop previously refilled its bit
buffer only after that token. Four literal bytes can consume 22 bits, followed
by a 47-bit match: 14 length-code bits, 5 length-extra bits, 15 distance-code
bits, and 13 distance-extra bits. The 69-bit sequence exceeds both the declared
56..63-bit reservoir and a single 64-bit lookahead word.

The independent regression vector uses complete 14/15-bit Huffman trees,
257-byte matches at distance 32768, and initialized stored-block history.
Python zlib and pinned image-png decode its PNG correctly. The pre-change imx
decoder returns `InvalidFormat`; the focused pre-change semantic test panics
after the bit state is corrupted. The fixed decoder produces all 33,291 RGB
bytes with SHA256
`6d0b1f1baece005bd42f9f4b71e2ebd9ce551fe15fb2a07fcb1fd5e8fa19c1b5`.

## Implementation and contracts

The linear, bounded-window, and sink semantic loops now establish sufficient
staged bits before reading the length-extra and distance fields. A buffer with
at least 48 bits already covers the maximum complete match token. Smaller
buffers use the current length code and the distance-tree bound to decide
whether to refill. Input tails resume through the checked decoder with the
length code still unconsumed. Canonical RLE1 retains its existing proven bound.

The shared staging helper lives in `src/deflate/semantic/match_bits.zig`.
Independent vectors and their stored/dynamic wire fixture live beside it.
No allocation, output layout, checksum policy, or wire encoding is added.
The bounded PNG window's existing row-size admission remains explicit;
larger rows continue through the public PNG facade's full-scratch path.

## Complete PNG measurements

The same frozen public imx PNG worker measures before/after Vort sources and
the pinned image-png peer serially on AArch64 CPU 12. Nine alternating rounds
use process CPU time and shared native counts calibrated toward 300 ms.
Decoder construction and codec workspace stay in timing; input reads, initial
output storage, full pixel validation, and heap observation stay outside it.

| Policy | Native MiB/s | image-png MiB/s | Before/after aggregate | Native/reference aggregate |
| --- | ---: | ---: | ---: | ---: |
| Strict CRC and Adler | 779.102 | 804.204 | 1.005603x | 0.968787x |
| Checked CRC, ignored Adler | 807.657 | 804.204 | 1.005429x | 1.004294x |

All 75 complete native/reference outputs match the fifteen frozen original
rasters. Native requested heap records remain exact, and the complete native
process RSS maximum stays at 27,918,336 bytes (26.625 MiB). Runtime samples
exit normally with zero swaps under a 1024-MiB address-space limit.

Kodak02 improves 1.008690x strict / 1.009356x no-Adler; Kodak17 improves
1.006197x / 1.003365x; Kodak23 improves 1.015491x / 1.017278x. This is a small
complete-decode improvement accompanying the compatibility fix. Kodak17 still
reaches only 0.715483x / 0.728967x of Rust. Strict aggregate remains below
parity; matched aggregate parity does not establish per-image leadership.

Fifteen-round, 700-ms controls retain Kodak17 gains of 1.004753x strict /
1.003269x no-Adler. The 128-pixel address-book icon remains at 0.991957x /
0.995778x before/after. That small-image regression is explicit: this increment
repairs a legal-input compatibility defect and improves the complete corpus,
while leaving per-image performance work outstanding.

## Verification and provenance

Focused tests cover full byte results through checked, linear, window, sink,
and public raw decode paths; logical cursors and guarded resume; 48-bit match
field bounds; input tails; and truncation. Public PNG regressions separately
cover the wide RGB fallback and a supported four-row bounded-window image.
The 31-test native gate and 36-test filtered imx gate pass. Generic AArch64
executes seven focused tests; x86_64 and big-endian AArch64 pass compile-only
checks. Thirty-five new framing/checksum/truncation controls and 144 existing
PNG controls pass with exact accepted pixels and preserved existing errors.
The original Huffman validation, RLE, streamed scanline, and zlib/gzip cases
remain part of the focused gate.

```sh
zig test src/deflate.zig -OReleaseSafe \
  --test-filter semantic --test-filter 'PNG windowed' \
  --test-filter 'png streaming' --test-filter 'raw dynamic Huffman' \
  --test-filter 'dynamic Huffman decoder rejects' \
  --test-filter 'zlib and gzip dynamic'
```

Full build commands, source/binary identities, every timing sample, resource
records, independent wire/pixel oracles, and rejected candidate records are in
the imx evidence record `docs/evidence/png-long-huffman-match/` and its local
archive `/nav_env/Temp/imx-png-long-match-20261030`. Compiler runs use a
4096-MiB address-space limit. The broader codec performance and functionality
goal remains active.
