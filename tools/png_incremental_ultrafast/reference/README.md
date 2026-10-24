# PNG UltraFast independent reference

All files in this bundle live in the owned Temp directory. No repository or
reference source was modified. The reference is clean local fdeflate at
`a713d02c560526c82e2b97519ed6720bdbc8a47a`.

Reproduce offline:

```sh
python3 /nav_env/Temp/vort-png-incremental-ultrafast-reference/generate.py
python3 /nav_env/Temp/vort-png-incremental-ultrafast-reference/convert_stream.py
```

`src/main.rs` performs exactly one actual
`UltraFastCompressor::write_data(full_slice)` and then `finish`, even for empty
input. `fixtures.jsonl` contains 544 legacy one-shot vectors. Its `expected_hex`
is the complete actual fdeflate zlib output. No Zig/native output is used.
Two separate Rust runs produced identical bytes. Python system zlib independently
inflates every result and checks exact source bytes, end-of-stream, no extra
input and Adler32.

For the new continuable encoder, consume **`stream-fixtures.jsonl` and the
`stream_expected_hex` field**. `derived_expected_hex` is the same value.
`old_expected_hex` and the inherited `expected_hex` remain the legacy bytes;
they are not the expected framing for the new encoder. Each row provides the
source as `source_hex` and individual old/derived compressed SHA-256 values.

The independent RFC1951 parser reads the actual dynamic Huffman tables and all
literal/length/distance symbols through EOB. It also independently reconstructs
the original bytes. The converter preserves all original bits through EOB
except the original first BFINAL at zlib bit offset16, which it clears. It then
appends a final empty stored block: numeric three-bit header value1, transmitted
LSB-first as bits1,0,0; zero byte alignment; LEN bytes00,00 and NLEN bytesff,ff;
and the unchanged actual Adler32. Every prefix bit is checked and every derived
stream is independently inflated with system zlib.

`parsed_rfc1951.deflate_eob_bit_end` counts bits from the first deflate byte,
after the two-byte zlib header. `zlib_eob_bit_end` counts from the zlib stream
start and equals the former plus16. Both point immediately after EOB. All eight
EOB residues modulo8 are covered. The trained header is HLIT286, HDIST1,
HCLEN18 and ends at deflate bit413, or zlib bit429.

Coverage includes:

- Empty input (`zero_run_0`) and zero runs0..8,257/258/259/516/600, plus
  4095/4096/4097/4103/8192/8193/10000.
- The same run lengths surrounded by nonzero literals, forcing exact run
  boundaries inside the next eight-byte word.
- All36 legal zero-prefix/zero-suffix word combinations, in four contexts:
  alone, prior run, following run, and both.
- Final tails0..7: zeros, nonzero literals, mixed bytes and zeros after a
  partial-word run.
- Runs4097/8193 at every eight-byte stream alignment, with suggested input
  cuts around run, word and4096-byte boundaries.
- Every nonzero singleton literal, twelve nonzero permutations/rotations,
  ascending/descending all-byte sequences and short/long Huffman-code mixtures.

`suggested_cuts` are source byte offsets for a candidate encoder to partition
the source. For every unflushed partition, compare against the same derived
`stream_expected_hex`. The Rust oracle must never receive those partitions:
fdeflate's per-call local run and per-call literal tail can change its bytes.

These vectors describe no explicit sync flush. Explicit sync-flush block
transitions belong to the owning core tests.

`manifest.json` records legacy provenance, all tracked fdeflate source hashes,
Cargo.lock, compiler/platform, binary and helper hashes. `stream-manifest.json`
records converter/source-manifest hashes, both aggregate fixture hashes and
the RFC parsing/conversion checks. Cargo artifacts remain under this directory.
