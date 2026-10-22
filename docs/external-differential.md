# External differential validation

Vort has black-box differential smoke coverage against Python `zlib` and the
system `gzip` CLI, plus library-level interoperability probes against other
system codecs including libsnappy, liblz4, libbrotli, and libzstd.
The native LZ4 library probe additionally compares public Vort LZ4HC blocks
byte-for-byte with `LZ4_compress_HC_destSize` at levels 1, 3, 5, 9, 10, 11,
12, and an above-maximum level. It compares independent and 300 KiB linked HC
frames with `LZ4F_compressFrame` for upstream HC levels 3 and above, plus
independent/linked preset-dictionary frames at levels 3, 9, and 12 through
`LZ4F_compressFrame_usingCDict`. Dictionary frames are also decoded in both
directions through Vort and `LZ4F_decompress_usingDict`; Vort's incremental HC
encoder must reproduce the same linked/CDict frame bytes under tiny output
backpressure.
The required libbrotli probe also generates Large Window streams for every
25...30-bit window. It requires strict Vort entrypoints to reject the reserved
header and verifies explicit opt-in one-shot, split-input, buffered-incremental,
and byte-progressive decoding against libbrotli's own Large Window decoder. A
seventh generated stream performs an actual 16 MiB backward copy, just beyond
RFC 7932's maximum window, and is independently decoded by libbrotli.

```sh
zig build run-checksum-zlib-diff
zig build run-python-zlib-diff
zig build run-gzip-cli-diff
zig build run-rust-deflate-diff
zig build run-snappy-interop-probe
zig build run-qcow2-diff
zig build run-vmdk-diff
zig build run-ewf-diff
zig build run-chd-diff
zig build run-vhd-diff
zig build run-vhdx-diff
zig build run-cso-diff
zig build run-dax-diff
zig build run-gcz-diff
zig build run-wia-diff
zig build run-android-sparse-diff
zig build run-android-ota-diff
zig build -Doptimize=ReleaseFast run-br-real-corpus-diff
zig build -Doptimize=ReleaseFast ci-smoke
```

The EROFS differential generates plain, compact/full LZ4, compact/full raw
Deflate, and compact Zstandard images with current `mkfs.erofs`. Repeated
`user.*` values exceed the default inline tolerance and therefore exercise real
shared-xattr IDs as well as unique inline entries. An additional plain image
uses `--xattr-prefix=user.vort.` so shared and inline entries both reconstruct
through the incompatible long-prefix table. Vort must list every name and
byte-exact value. LZ4 ordinary/all-fragment, Deflate-fragment, and
Zstandard-fragment cases require byte-exact extraction through whole and
partial references, compressed/plain/interlaced packed inodes, and bounded
range reads. Separate LZ4/Deflate/Zstandard cases exercise compressed inline
tail packing. In the other direction, deterministic stored/LZ4/MicroLZMA/Deflate/Zstd
Vort images carry root, regular-file, inline-tail, and directory attributes
through a caller-selected plain prefix table. Four additional Vort writers
combine those codecs with whole and last-block fragments; their packed inode
must remain hidden while `fsck.erofs --xattrs` validates, extracts, and restores
all files and attributes through the host API. Four more writers enable
compressed inline tails for the same codecs and require the same byte-exact
extraction. Local chunk block-map, forced local chunk-index, and external
blob-device images additionally verify merged chunks, device tables, borrowed
device extraction, and the missing-device error. Vort also writes deterministic
local maps and owning external metadata/blob pairs; both must preserve xattrs,
deduplicate repeated chunks, encode holes, and extract byte-exactly through
`fsck.erofs`. Six forced-48bit reference images cover stored, LZ4, Deflate,
Zstandard, local chunk, and external chunk layouts; six matching Vort writer
modes plus MicroLZMA must also pass fsck and byte-exact extraction. Two LZ4 metabox references
separately place inode metadata and inode+directory
metadata in the hidden stream; Vort must list/extract all files and reconstruct
source shared/long xattrs, while fsck independently validates and extracts file
bytes. Five Vort MZi writers use stored, LZ4, MicroLZMA, raw Deflate, and Zstandard hidden
metadata inodes, must remain deterministic, and are self-decoded byte-exactly;
fsck validates every image and independently extracts physical/compressed file
extents. The stored-MZi check excludes flat-inline regular-file tails because
erofs-utils 1.9.4's extractor zero-fills that layout even for its own MZi
images, although its `dump --cat` path and Vort both read it correctly. All 108
Vort writer modes also move one repeated long-prefix name/value pair to the
primary shared-xattr region while retaining distinct inline attributes.
Vort must reconstruct both sources in every mode; the 87 non-metabox cases
additionally require host-restored xattrs from `fsck.erofs --xattrs`. Three
erofs-utils `--zD` references and four Vort directory writers cover
LZ4, MicroLZMA, raw Deflate, and Zstandard whole-directory fragments, including the shared
packed-inode path used by ordinary file fragments. Four forced-extended
erofs-utils references and five Vort stored/LZ4/MicroLZMA/Deflate/Zstandard writers cover
64-byte inode layout and fsck validation. Supply explicit tools with
`-- --mkfs /path/to/mkfs.erofs --fsck /path/to/fsck.erofs`; the summary reports
`xattr_reader`, `xattr_writer`, `long_prefix_reader`, `fragment_reader`,
`fragment_writer`, `ztailpacking_reader`, `ztailpacking_writer`, `chunk_reader`,
`external_chunk_reader`, `chunk_writer`, `external_chunk_writer`,
`address48_reader`, `address48_writer`, `metabox_reader`, `metabox_writer`, and
`shared_xattr_writer`, `directory_reader`, `directory_writer`,
`extended_inode_reader`, `extended_inode_writer`, and `lzma_writer` separately.

The QCOW2 differential always exercises the Vort v2/v3 writer and reader for
uncompressed, raw-DEFLATE, and Zstandard clusters plus v2/v3 raw-backing
overlays. Overlay fixtures distinguish inherited, modified, and explicit-zero
clusters and require the `raw` backing-format extension. A two-output v3 writer
fixture separately requires QEMU's raw external-data feature, `DATA` extension,
and byte-exact conversion. When `qemu-img` is available, it checks both
directions and adds sparse/zero clusters, extended L2 subclusters, raw backing
files, and external data files. When `7zz` or `7z` is
available, it independently extracts Vort's v2/v3 uncompressed and
raw-DEFLATE images. Explicit tool paths can be supplied with
`-- --qemu-img <path> --seven-zip <path>`; the summary reports unavailable
oracles as skipped instead of counting them as evidence.

The VMDK differential validates deterministic monolithicSparse and standard
footer-bearing streamOptimized output through both `qemu-img` and 7-Zip. In the
reverse direction it decodes QEMU-generated sparse, zero-grain, compressed
direct-directory, and backing-chain layouts. A pinned QEMU iotest version-3
streamOptimized image keeps real footer/marker and large virtual-address range
coverage available without an installed oracle. Explicit tool paths use the
same `-- --qemu-img <path> --seven-zip <path>` form.

The EWF differential always checks Vort raw/zlib/automatic E01 round trips and
decodes pinned libewf EnCase-6 single- and four-segment fixtures. When
`ewfinfo`, `ewfverify`, `ewfexport`, and `ewfacquirestream` are available, all
three Vort writer modes are inspected, verified, and exported byte-exactly by
libewf. The reverse direction generates both mixed compressed/raw single-file
and explicit multi-segment sets. A locally built tool directory can be supplied
with `-- --libewf-dir <path>`.

The CHD differential always checks all six Vort writer modes, per-hunk automatic
selection, checked metadata, a Vort-written parent delta, a partial final hunk,
and pinned chdman 0.289
LZMA/Huffman/Zstandard plus metadata/aligned-parent/unit-shifted-parent
fixtures.
When `chdman` is available, it verifies and extracts Vort output byte-exactly;
the reverse direction creates fresh none/zlib/LZMA/Huffman/Zstandard images
and a parent-only delta image. An explicit binary can be supplied with
`-- --chdman <path>`.

The VHD differential always checks fixed/dynamic writer round trips, a
differencing parent chain, malformed structures, and a pinned QEMU 9.2 dynamic
fixture. When `qemu-img` is available it decodes both Vort layouts and creates
fresh fixed/dynamic images for Vort; 7-Zip independently extracts both Vort
layouts. Explicit tools use
`-- --qemu-img <path> --seven-zip <path>`.

The VHDX differential always checks dynamic/fixed round trips, redundant-copy
and BAT corruption, a differencing parent/sector-bitmap chain, and a pinned
QEMU 9.2 image. With external tools, QEMU
checks and extracts both Vort modes and generates both modes for Vort, while
7-Zip independently extracts all three Vort modes, including parent sector
overrides. It accepts the same explicit QEMU and 7-Zip arguments as the VHD
differential.

The CISO/ZISO differential always checks deterministic CISO v1, CISO v2, and
ZISO writer round trips, raw fallback, per-block DEFLATE/LZ4 selection, shifted
indexes, bounded ranges, and malformed structures. When `maxcso` is available,
it decodes every Vort layout and generates fresh v1/v2/ZSO images for Vort.
Use `-- --maxcso /path/to/maxcso --seven-zip /path/to/7zz` for explicit tools.
7-Zip is counted only if the installed release actually recognizes and
byte-exactly extracts the image; lack of a CSO handler is reported as skipped.

The DAX differential always checks deterministic zlib-only version-0, raw and
automatic version-1 output, canonical non-compressed areas, partial tails,
bounded ranges, and malformed metadata. When `maxcso` is available, it decodes
all three Vort writer modes and creates a fresh DAX image for Vort. Supply an
explicit oracle with `-- --maxcso /path/to/maxcso`.

The GCZ differential always checks raw, forced-zlib, and automatic output
against an independent Python zlib reader and generates a reference GCZ for
Vort. It also covers partial tails, bounded ranges, stored-payload Adler-32,
and malformed pointers. When `dolphin-tool` is installed, all Vort writer modes
are converted back to ISO and DolphinTool creates a fresh GCZ for Vort. Supply
an explicit binary with `-- --dolphin-tool /path/to/dolphin-tool`.

The WIA/RVZ differential always checks ten Vort raw-data writer modes across
none, purge, Bzip2, LZMA, LZMA2, and Zstandard. Pinned current-Dolphin WIA
LZMA2 and RVZ Zstandard files preserve external coverage. Independently
generated WIA and RVZ partition fixtures exercise Wii SHA-1 hash regeneration,
hash exceptions, AES re-encryption, and both 2 MiB and 128 KiB chunks. With
DolphinTool, all ten raw-data outputs, all ten partition outputs, and both
partition fixtures are converted byte-exactly back to ISO. Two additional
outputs exercise automatic partition discovery and common-key title-key
decryption. Vort also decodes four fresh WIA codecs, RVZ Zstandard, and a
junk-packed RVZ. Select an explicit tool with
`-- --dolphin-tool /path/to/dolphin-tool`.

The WBFS differential checks sparse and full single-disc writers byte-for-byte
against an independent Python implementation, then decodes ranges crossing
stored, omitted, partial-tail, and high logical blocks. It also exercises
malformed headers, size equations, and range bounds. When DolphinTool is
available, both Vort images must be recognized as WBFS with the expected block
size. Select an explicit oracle with
`-- --dolphin-tool /path/to/dolphin-tool`.

The WDF differential checks WDF1 and WDF2 in sparse and full modes
byte-for-byte against an independent Python implementation, including logical
holes, partial tails, ranges, and malformed metadata. When Wiimms tools are
available, `wdf` must decode all four Vort outputs and Vort must decode both
versions produced by `wit --raw`. Select explicit tools with
`-- --wdf /path/to/wdf --wit /path/to/wit`.

The WUX differential checks deduplicated and store-all Vort output byte-for-byte
against an independent Python implementation, including repeated sectors,
partial/range handling, and malformed metadata. When the original WudCompress
binary is available, it must decode both Vort modes and Vort must decode its
generated WUX output. Select it explicitly with
`-- --wudcompress /path/to/WudCompress`.

The Android sparse differential checks four Vort writer configurations
byte-for-byte against an independent Python implementation, covering RAW,
FILL, DONT_CARE, CRC32 chunks, the header checksum, bounded ranges, malformed
metadata, and deterministic mutation samples. When AOSP libsparse tools are
available, `simg2img` expands every Vort output byte-exactly and Vort expands a
fresh `img2simg` image. Select explicit tools with
`-- --simg2img /path/to/simg2img --img2simg /path/to/img2simg`.

The Android OTA differential decodes all four Vort writer modes with an
independent Python protobuf/Bzip2/XZ implementation, compares the raw writer's
complete wire image byte-for-byte, and feeds Vort a separately generated
RAW/Bzip2/XZ/ZERO payload plus a Python-generated BSDIFF40/SOURCE_BSDIFF delta.
It also covers cross-operation and cross-patch ranges, corrupt hashes,
malformed headers, and deterministic mutations. When an upstream-compatible
`bspatch` is available, it applies the independent patch byte-exactly. When the Rust
`payload_dumper` binary is available, it extracts every Vort output and must
produce byte-identical partition images. Select it explicitly with
`-- --payload-dumper /path/to/payload_dumper`. An AOSP update-engine checkout
can be supplied with `--aosp-update-engine /path/to/update_engine`; its pinned
full payload must extract both partitions byte-exactly, its XZ-only delta
partition and genuine BSDF2/BROTLI_BSDIFF kernel partition must both extract
byte-exactly. Select an explicit patch oracle with
`--bspatch /path/to/bspatch`.
The same driver applies the pinned AOSP update-engine PUF1/PUFFDIFF fixture as a
complete OTA operation, including bounded range extraction. With
`--puff-codec-oracle /path/to/oracle`, an independently built AOSP Puffin codec
must produce byte-identical puff streams and exact huffed Deflate bytes for
stored, fixed-Huffman, and dynamic-Huffman multi-block cases. A full AOSP
`puffin` command may instead be supplied with `--puffin /path/to/puffin` to
apply the pinned patch directly.
When a system liblz4 is discoverable, the driver uses its
`LZ4_compress_destSize` and `LZ4_compress_HC_destSize` as independent encoder
oracles, builds both
LZ4DIFF_BSDIFF and LZ4DIFF_PUFFDIFF payloads, covers ordinary trailing padding
and EROFS-style leading zero padding, and requires byte-identical whole-cluster
and range output. LZ4HC fixtures exercise levels 5, 9, 10, and 12 so both the
hash-chain and optimal parsers are covered. The pure-Zig fill-output encoders
are also compared directly against pinned liblz4 1.9.3 vectors in focused
tests.
With Python's Brotli module, the driver independently serializes Zucchini v1
headers, a canonical NoOp element, equivalence streams, and raw byte deltas;
it then applies the required Brotli OTA envelope and requires byte-identical
whole-partition and range output. A patch-reader fixture copied from AOSP's
Zucchini tests separately pins the little-endian v1 wire layout.
The independent generator also builds a synthetic but structurally valid
AArch64 ELF and an `EA64` patch whose target pool and reference delta retarget
a `B` immediate. AOSP-derived fixed vectors cover all three AArch64 branch
immediate encodings, while focused tests cover relocation and 64-bit absolute
reference groups. Separate ELF32 and ELF64 generators emit `Ex86` and `Ex64`
patches that jointly exercise relative relocations, absolute pointers, and
Intel rel32 correction. Independent PE32 and PE32+ generators exercise the
same three reference pools through `Px86` and `Px64` base-relocation tables,
image-base-adjusted pointers, and executable sections. All six Zucchini
fixtures plus an `EA32` ELF generator must match through complete,
source-backed, and bounded-range OTA extraction. The AArch32 fixture covers
`R_ARM_RELATIVE`, absolute pointers, ARM-mode detection, and A24 branch
correction; AOSP-derived fixed vectors separately pin all five ARM/Thumb-2
branch encodings. A valid DEX 039 generator carries correct SHA-1 and Adler-32,
splits block-tail padding into a NoOp element, applies raw integrity deltas, and
retargets a Dalvik `const-string` through the DEX string-ID pool. All eight
fixtures plus an independently generated ZTF reference patch exercise complete,
source-backed, and bounded-range extraction. Byte-pinned AOSP `old.ztf` and
`new.ztf` fixtures separately validate the full textual parser and writers.

`run-br-real-corpus-diff` reads the repository-owned
`tools/br/real_corpus_manifest.json` and requires source, documentation,
structured JSON, and binary dictionary inputs. Each file is encoded by
libbrotli at four representative quality/mode/window combinations and decoded
byte-exactly by both Vort's allocating and byte-progressive paths. The driver
checks the probe's structured counters, so a missing file, missing category,
ignored argument, or skipped progressive case fails the gate. Additional local
corpora can be appended without weakening the required set, for example with
`-- --extra-file ~/Work/godot/thirdparty/ufbx/ufbx.c`.

The checksum zlib-family smoke checks Vort's CLI checksum output against Python
zlib, then verifies Python zlib Adler-32 trailers and system gzip CRC-32
trailers. The `ci-smoke` aggregate includes that checksum harness, the Python
zlib and gzip CLI deflate/gzip harnesses, match-heavy dynamic/split/adaptive
payloads, split-best gzip output checks against system `gzip -dc`, optional
zlib-ng/zlib-rs family coverage, fdeflate/miniz_oxide source-checkout
differential smoke, the external-tool probe, fuzz smoke entrypoints, and bounded
benchmark reports.

The Python zlib harness uses inline text/hex CLI commands for small cases and
automatically switches large README/roadmap corpus entries to file-based
encode/decode commands. This keeps the black-box coverage portable across
platform-specific per-argument limits while still exercising both CLI surfaces.

The optional zlib-family harness detects locally built zlib-ng/zlib-rs minigzip
binaries and reports explicit skip status when they are not available:

```sh
zig build run-zlib-family-diff
```

If competitor binaries are not built, output is explicit about skipped coverage. After building zlib-ng `minigzip` in `~/Work/zlib-ng/build`, expected output includes zlib-ng coverage:

```text
zlib family differential harness:
- zlib-ng-minigzip: ok (/home/passchaos/Work/zlib-ng/build/minigzip)
- zlib-rs-minigzip: skipped (binary not built)
zlib family differential summary: used=1 skipped=1
```

To turn this into real coverage, build compatible `minigzip`-style binaries or the zlib-rs `compress` example in
one of the paths listed in `tools/zlib_family_diff.py`, then rerun the build
step. Skip output must not be counted as compatibility evidence for that implementation.

The hosted GitHub Actions smoke workflow builds the zlib-rs `compress` example
under `~/Work/zlib-rs` and reruns `run-zlib-family-diff`, so zlib-rs binary
coverage is a required CI signal rather than only an optional local probe.

The Snappy interoperability probe dynamically loads libsnappy's C ABI and is
also required by `ci-smoke`. It exercises both directions for raw blocks:
libsnappy compression followed by Vort one-shot/caller-buffer/split-input
decode, and Vort compression followed by libsnappy validation/size preflight/
decode. The matrix requires both encoders to produce copy-bearing blocks rather
than proving only literal compatibility, and requires both implementations to
reject every truncated reference block. Because libsnappy does not expose a
framed-stream API, the probe also uses genuine libsnappy-compressed blocks
inside standard checksummed Snappy framing and exercises Vort's one-shot,
caller-buffer, split-input, and incremental frame decoders. Conversely, it
parses every Vort-generated frame and asks libsnappy to validate and decode each
compressed data chunk while checking framing CRC-32C independently. CI installs
`libsnappy-dev` explicitly, so a missing reference library cannot turn this
required evidence into a skip.

Additional Rust deflate baselines are expected under `~/Work/fdeflate` and
`~/Work/miniz_oxide` when available. They are tracked by `run-external-probe`
as local source checkouts, including their current git revision when available,
and `run-rust-deflate-diff` builds a temporary Cargo runner with path
dependencies to both checkouts. That smoke verifies Rust-generated zlib frames
decode through Vort and Vort-generated zlib frames decode through both Rust
implementations. It also covers raw deflate streams where the Rust APIs expose
them: fdeflate and miniz_oxide raw encoders must decode through Vort, and
miniz_oxide raw inflate must decode the wrapper-independent raw deflate payload
inside Vort's raw/zlib output. The same smoke also checks Vort gzip file output
through Python's gzip module so raw, zlib, and gzip file encoders stay covered
by one Rust-baseline-oriented command. Passing that smoke is compatibility
evidence for its small payload set; it is not yet throughput or ratio evidence,
so dedicated benchmark harnesses are still required before making performance
claims. The
`run-rust-deflate-bench` step is the first such decode-throughput smoke. Its
Vort helper is pinned to ReleaseFast, and it builds one stable Cargo release
runner with `-C target-cpu=native` before directly executing that binary against
both Rust checkouts. It prints
CSV rows comparing Vort, fdeflate, and miniz_oxide zlib decode throughput on
generated tiny, repetitive, text, and binary payloads plus real project
README/roadmap files. It also reports raw-deflate rows for Vort and
miniz_oxide, separating wrapper overhead from the inflate core where the Rust
baseline exposes a public raw API. Each engine performs one warmup decode before
timing to reduce cold-start noise. Use
`run-rust-deflate-bench-csv` to persist the same rows to
`zig-out/vort-rust-deflate-decode-bench.csv`. The Vort decode rows include raw
allocator/exact-size/caller-buffer APIs (`vort-raw`, `vort-raw-exact`,
`vort-raw-into`), the zlib allocator-returning API (`vort`), the zlib
exact-size and caller-owned output-buffer APIs (`vort-exact`, `vort-into`), and
matching gzip wrapper rows (`vort-gzip`, `vort-gzip-exact`,
`vort-gzip-into`) so regressions can distinguish inflate/checksum work, wrapper
format overhead, exact allocation overhead, and per-iteration growable
allocation overhead.
Use `run-rust-deflate-bench-gate` for the formal median-of-3 CSV. The gate
recomputes every input hash and the ten-artifact provenance manifest, including
the Python driver/interpreter/shared modules, Vort helper, generated Rust runner
source/binary, and full fdeflate/miniz_oxide source trees with Git state.
Vort's timed allocator-returning rows use `std.heap.c_allocator`, matching the
process allocator behind the Rust `Vec` results on the Linux benchmark host;
the manifest records this policy explicitly. Caller-buffer rows keep allocation
outside the timed loop and remain the allocator-independent core comparison.

`run-rust-deflate-encode-bench` provides the matching encode-side smoke. It
prints CSV rows for zlib and raw-deflate frame size, ratio, and encode
throughput for Vort, fdeflate, and miniz_oxide on the same generated payloads.
Vort is reported at fastest, fast, default, best, dynamic-default,
dynamic-literal, fixed-fast, split-default, and adaptive-default zlib modes, plus
raw fastest/fast/default/best, raw-dynamic-default, raw-fixed-fast,
raw-split-default, and raw-adaptive-default modes, so speed/ratio tradeoffs,
dynamic-only cost, literal-only wrapper cost, best-selection overhead, wrapper
split/adaptive overhead, raw core encode cost, and raw strongest-size behavior
are visible next to the Rust baselines. The best rows use fewer iterations
because they currently exercise the
slower optimal parser; each row records its actual iteration count. It also
includes real project README/roadmap files. The formal helper remains
ReleaseFast regardless of the outer build mode. Use
`run-rust-deflate-encode-bench-csv` to persist the same rows to
`zig-out/vort-rust-deflate-encode-bench.csv`.
`run-rust-deflate-encode-bench-gate` validates the corresponding median-of-3
210-row matrix, exact input/artifact hashes, and recomputed timing/ratio fields.
`run-rust-deflate-benchmark-summary` consumes both CSV files and writes
`zig-out/vort-rust-deflate-benchmark-summary.md`. It starts with a geomean
overview of the key throughput and size ratios so each run has an immediate
whole-suite gap signal and weakest-case pointer before the per-case tables. The detailed decode table
then highlights per-case Vort zlib allocator and caller-buffer throughput
ratios against the best Rust baseline. Raw-deflate Vort/miniz_oxide rows, gzip
decode rows, and decode allocation overhead are summarized separately because
the Rust baseline harness does not expose identical APIs for every wrapper. The
zlib encode table also reports the Vort default/dynamic-default throughput ratio to expose
best-selection overhead, literal-only dynamic speed/size ratios against Vort
default, plus split-default/adaptive-default speed and size ratios against Vort
default to expose wrapper block-planning overhead and split-induced size
changes. The same table adds notes when literal-only, split, or adaptive rows
are much larger than the default row, making benchmark-only modes harder to
mistake for production compression choices. It also reports Vort default and Vort best-preset
compressed-size ratios against the best Rust size so the production preset and
strongest-size preset can be tracked separately. A separate raw encode table
compares Vort raw modes with fdeflate/miniz_oxide raw modes so wrapper bytes and
checksum work do not hide core encoder gaps.

The dynamic plan report section compares the default dynamic plan with the
best-preset plan on the same files, including best/default compressed-size and
token-count ratios. Those fields are intended to identify which best-preset
parser improvements are worth moving into production presets. It also includes
average match length/distance and short-match counts for both plans, making it
easier to distinguish “more but shorter matches” from genuinely longer or
farther back-references. The same section breaks dynamic bit cost into header,
literal, match-symbol, length-extra, distance-extra, and total extra-bit ratios
for best versus default, which helps separate Huffman header overhead from
payload coding improvements. The CSV and Markdown summary also include compact
`;`-separated length-extra and distance-extra histograms for default and
best-preset plans so parser experiments can target the exact extra-bit buckets
that differ. The dynamic-plan CSV additionally records length-symbol and
distance-symbol histograms for exact RFC-code distribution analysis, and the
Markdown summary calls out the largest best-minus-default symbol-count deltas.

The MicroLZMA driver also encodes with Vort's literal-only, greedy, and lazy
modes and requires XZ Utils to consume every compressed byte and reproduce the
exact original payload. Seven cases cover empty, tiny, repeated, delta,
mixed, source, and a repeated suffix more than 80 KiB away, with independent
lc/lp/pb and dictionary settings. XZ Utils 5.8.4 (source commit 3b1efb0) passes
all 21 Vort-writer comparisons; a deterministic fixture brings native writer
coverage to 22 cases (`external=7`, `writer=22`, `external_writer=21`).
Run `zig build run-microlzma-diff -- --xz-source /path/to/xz
--xz-build /path/to/build` to build the probe against that checkout.

The EROFS writer matrix additionally covers seven MicroLZMA modes: ordinary
clusters, fragments, compressed inline tails, 48-bit features, metabox,
compressed directories, and extended inodes. They carry the standard 32 KiB
MicroLZMA configuration and pass erofs-utils 1.9.4-g5fcb2f76 fsck and exact
extraction, bringing the matrix to 36 writer modes (`lzma_writer=7`,
`external_writer=36`).

The MicroLZMA capacity differential uses a fresh XZ Utils probe with an
`encode-limit` mode. Capacities from the six-byte minimum through complete
input cover all seven payload classes and Vort's three parser modes. XZ Utils
independently consumes and decodes 186 Vort prefixes; Vort likewise decodes
62 XZ Utils prefixes. Both directions require exact source-prefix bytes,
compressed-input consumption, destination bounds, and declared progress;
Vort additionally requires nondecreasing consumed prefixes across capacities.
The driver reports `limited_writer=186`, `limited_reference=62`, and
`malformed=5`, preserving separate complete-stream counters. These checks
establish interoperable prefix behavior rather than identical parser choices
or encoded bytes between implementations.

Eight additional EROFS references end with a physical cluster spanning more
than one 4 KiB block. A deterministic 8 KiB xorshift32 prefix repeated twice
is built with a 64 KiB physical-cluster limit in LZ4, MicroLZMA, raw Deflate,
and Zstandard, under both full and compact index modes. fsck and Vort must
list and extract the exact 16 KiB payload (`final_big_pcluster_reader=8`).
This exercises explicit CBLKCNT handling at EOF, independently of the distance
to a following HEAD. Existing fragment and inline-tail references remain in
the same matrix to pin their legitimate zero-physical-block markers.

Thirty-two additional Vort modes use 64 KiB decoded groups in all four
EROFS codecs, including ordinary data, fragments, inline tails, 48-bit
features, metabox, directories, extended inodes, and directory + extended +
metabox combinations. Every mode includes a 16 KiB mixed file (8 KiB random
prefix repeated twice) that requires a multi-block physical pcluster when
compression is selected. Vort's deterministic output, extraction, and xattrs
are checked for all 68 writer modes; fsck independently extracts every mode
(`grouped_writer=32`, `external_writer=68`, `xattr_writer=55`,
`directory_writer=12`, `extended_inode_writer=13`). The stored-MZi host
extractor exception continues to apply only to affected inline tails.

MicroLZMA aligned-prefix verification adds 315 XZ Utils decode checks over
seven payload classes, three parser modes, and 16/512/4096-byte alignment.
Capacities include six bytes, partial prefixes, and complete streams. Every
partial consumed length must align; only complete input may end unaligned.
Zero-consumption results must decode as valid empty streams, and increasing
capacity must preserve monotonic progress (`aligned_writer=315`). Existing
complete and unaligned capacity counters remain separate.

The EROFS matrix adds 40 bounded writers. Every codec uses a 4 KiB physical
limit with ordinary, fragments, inline, 48-bit, metabox, directories, extended,
and combined directory/extended/metabox layouts; ordinary modes also exercise
8 KiB and non-power-of-two 12 KiB limits. Self-decode, deterministic reruns,
xattrs, and independent fsck extraction cover all 108 modes
(`bounded_writer=40`, `external_writer=108`, `xattr_writer=87`). This gate
retains the eight final-big-pcluster references and earlier unbounded modes.

The EROFS source matrix duplicates all 108 memory writer modes with borrowed
slice sources and 4 KiB callback request bounds. Each source image/device must
match the corresponding memory image/device byte-for-byte, remain deterministic,
extract exactly through Vort, and pass fsck. Thirteen CLI cases independently
use actual regular files through positional FileByteSource adapters. Current
coverage reports `writer=216`, `source_writer=108`, `file_source_writer=13`,
`external_writer=216`, and `xattr_writer=174`. Stored-MZi exclusions remain
limited to host extractor behavior on affected inline tails. Generic byte-source
and file-adapter tests run with `zig build test-byte-source`.
