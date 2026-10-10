# LZFSE and LZVN

Vort implements Apple's LZFSE stream format and its compact LZVN block codec in
pure Zig. No platform Compression.framework or C binding is required.

The stream decoder supports all public block magics:

- `bvx-`: uncompressed data;
- `bvxn`: LZVN-compressed data;
- `bvx1`: LZFSE FSE data with uncompressed frequency tables;
- `bvx2`: LZFSE FSE data with bit-packed frequency tables;
- `bvx$`: the mandatory end-of-stream marker.

LZFSE decoding reconstructs four interleaved literal FSE states and the L/M/D
value states, including repeated match distances and overlapping copies. Block
sizes, frequency sums, state ranges, match distances, payload boundaries,
decoded sizes, output limits, the final marker, and trailing bytes are checked.

The deterministic writer splits input into caller-selected independent blocks.
Each block uses the pure Zig LZVN encoder when that representation is smaller,
otherwise it emits a valid uncompressed block. Full ratio-oriented LZFSE FSE
encoding is intentionally deferred; all external V1/V2 streams are already
decodable.

```sh
zig build run -- encode-lzfse-file input.bin output.lzfse 65536 lzvn
zig build run -- inspect-lzfse-file output.lzfse 536870912
zig build run -- decode-lzfse-file output.lzfse restored.bin 536870912
zig build run-lzfse-diff
```

`run-lzfse-diff` exercises raw, LZVN, V1, and V2 streams bidirectionally against
the pinned Apple reference CLI when it is available. The checked-in V2 fixture
keeps the complete FSE path covered even without the external tool.
