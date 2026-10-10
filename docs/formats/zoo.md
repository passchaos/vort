# ZOO archive support

Vort provides a dependency-free pure Zig reader and deterministic writer for
the common Zoo 2.10 archive format. The implementation follows the original
Zoo 2.10 source layout rather than assuming that directory entries are stored
sequentially: both directory and data locations are absolute offsets, and the
directory is an explicit linked list ending in a null entry.

Supported compression methods are:

- method 0, stored;
- method 1, Zoo LZD/LZW with LSB-first codes, explicit CLEAR/EOF controls,
  widths from 9 through 13 bits, and the format's 8192-entry dictionary;
- method 2, Zoo's LH5 stream, including its trailing zero block marker.

`encodeZooAlloc`, `encodeZooAppend`, and `encodeZooInto` write type-2 directory
entries and can mix all three methods. The LZD writer is currently a
literal-only compatibility baseline, while LH5 uses the same deterministic
literal-block core as the public LHA API. This deliberately puts complete wire
compatibility before compression-ratio optimization.

## Metadata and validation

The reader supports both legacy type-1 and extended type-2 directory entries.
For type 2, it parses the 16-bit variable-directory length, timezone, long
filename, directory name, system ID, 24-bit attributes, and version metadata.
Names are exposed through `ZooName`; path separators normalize to `/` when the
name is materialized or compared.

The parser validates:

- archive and directory tags plus the start-offset negation check;
- every linked-list target and data/comment extent with checked arithmetic;
- the `@)#(` file-data leader;
- type-2 directory CRC-16 with the stored CRC field zeroed;
- uncompressed file CRC-16 after extraction;
- exact decoded size, method controls, code ranges, and trailing data;
- caller-selected extraction limits before allocating output.

Writer input rejects empty, absolute, dot-component, parent-component, and
NUL-containing paths. The reader rejects unsafe archived base names and strips
unsafe archived directory components at the API boundary, matching the safe
behavior of patched Zoo tools without exposing traversal paths. Vort does not
itself write files to paths from an archive.

Deleted entries remain visible while iterating but `find` skips them and
extraction rejects them. Nonzero Zoo file-structure modes are reported but not
decoded because record-oriented reconstruction has not yet been implemented.
Archive/file comments and generation metadata are parsed, but the baseline
writer currently emits no comments or generations.

## CLI

The shared example CLI exposes the public library API:

```sh
zig build run -- create-zoo-file output.zoo payload.bin input.bin lzd
zig build run -- list-zoo-file output.zoo
zig build run -- extract-zoo-file output.zoo payload.bin decoded.bin 1048576
```

The create method is `stored`, `lzd` (or `lzw`), or `lh5`; the default is
`lzd`.

## Differential validation

`tools/zoo/diff.py` exercises deterministic/self extraction, all three Vort
writers against the original Zoo utility, all three original Zoo writers
against Vort, the unarc-rs fixtures, content-CRC corruption, and directory-CRC
corruption:

```sh
python3 tools/zoo/diff.py \
  --cli path/to/vort \
  --zoo path/to/zoo \
  --unarc path/to/unarc \
  --fixtures path/to/unarc-rs/crates/unarc-rs/tests/zoo \
  --license path/to/unarc-rs/LICENSE
```

The original Zoo utility is the authoritative method-1 interoperability
oracle. unarc-rs 0.7.2 limits its generic variable-LZW implementation to
12 bits/4096 entries, while the original format and Zoo 2.10 implementation
use 13 bits/8192 entries. Therefore the differential harness uses unarc-rs for
Vort's stored and LH5 writer output, but does not misreport its LZD limitation
as a Vort failure.

Future ratio work should add match finding to the LZD writer and a match-aware
LH5 planner without changing the archive API or the strict decoder behavior.
