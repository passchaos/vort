# Vort

Vort is a Zig-first next-generation compression library project. Its long-term
objective is to surpass `zlib`, `zlib-ng`, `zlib-rs`, and `zstd` in both
functionality and performance while preserving explicit ownership, deterministic
behavior, robust validation, and library-first APIs.

The repository is currently in bootstrap form. The first implemented pieces are:

- zlib-compatible Adler-32;
- gzip/zip-compatible IEEE CRC-32;
- storage/network-oriented CRC-32C/Castagnoli;
- portable slice-by-4/slice-by-8/slice-by-16 IEEE CRC-32, slice-by-32 IEEE CRC-32, compile-time feature-gated ARMv8 CRC32 and x86 PCLMUL hardware dispatch, slice-by-8/slice-by-16/slice-by-32 CRC-32C fast paths, checksum dispatch reporting, and Adler-32/CRC-32/CRC-32C combine helpers for block/parallel checksum composition;
- shared progress/error/frame metadata types;
- pure Zig LZ4 frame/block
  decode/fallback encode plus byte-exact liblz4-1.9.3-compatible LZ4HC block
  encoding and independent/linked frame writing across levels 1...12, with
  allocating, caller-buffer, append, and reusable APIs, skippable/concatenated
  stream handling,
  optional content-size/checksum/block-checksum/Dictionary_ID fields,
  preset-dictionary and dictionary-set HC encoding, configurable frame block
  sizes, linked-block history encoding, encoded-block bounds, decoded-size
  preflight, bounded allocation for single/concatenated streams, bounded
  raw-block and skippable-frame encode-into/decoded-size preflight, inspectable
  native frame/block/skippable headers plus plain, standard-dictionary-aware, and dictionary-set-aware Zstd sequence-mode summaries, zero-allocation native stream/block
  iterators, reusable raw-block decoder, and
  caller-owned encode/decode-into/append, incremental fast/HC frame encode with
  optional pledged content size, resumable flush, linked history, preset
  dictionary, and dictionary-set resolution, plus reusable
  scratch encoder/decoder APIs; oversized incremental data frames release raw
  blocks directly, and compressed blocks use a resumable token cursor under
  arbitrary caller backpressure with no
  decoded-block scratch, including linked-block and preset-dictionary history;
  compressed-block checksums are validated before starting caller output;
  complete prevalidated frames switch to the same cursor instead of
  materializing the frame when a compressed block exceeds caller output;
  compressed blocks without block checksums also consume split input directly
  when the configured compressed-buffer cap is smaller than their payload;
  incremental skippable frames retain only their
  8-byte header while discarding or capturing arbitrary-size metadata directly
  from caller input,
  pure Zig native Zstandard frame encode/bounded/caller-owned decode with header
  options and decoded-size preflight, including explicit 10...41-bit
  `window_log` selection on both `FrameOptions` and `NativeFrameOptions` with
  `null` preserving the established wire, strict block/history/dictionary
  reach bounded by the selected window, an unchanged 8 MiB default history,
  and a 16 MiB default / caller-budgeted 64 MiB maximum sparse long-distance
  history for explicit windows of at least 24 bits, a
  dependency-free raw/RLE, literal-only compressed-block, single-/four-stream
  and treeless repeat Huffman-literals, minimal RLE-sequence, mixed
  RLE/predefined/FSE sequence-table, repeated sequence-table, and streaming
  default sequence compressed-block fallback encode/decode with exact
  RLE/predefined/compressed-FSE table arbitration, transactional cross-block
  sequence-table Repeat_Mode and repcode state, including wide blocks with more
  than 512 sequences, and
  frequency-aware single-/four-stream Huffman literal emission
  (covering the full direct-tree symbol range `0...128`, FSE-compressed
  high-byte weights, non-4-divisible four-stream splits, and treeless repeat
  trees across blocks), small-depth
  hash-chain large duplicate plus deeper duplicate
  candidate retention, RLE/predefined-table multi-duplicate, dictionary,
  repeated-pattern, and mixed duplicate/repeated/dictionary match emission with
  starts scanned up to 48 bytes and periods up to 64 bytes, exact
  RLE/predefined sequence-payload scoring for lookahead, size-aware
  dictionary/native-match-vs-Huffman arbitration,
  smallest native match-plan arbitration across independent bootstrap emitters,
  RLE-literals sections for same-byte sequence literals,
  Huffman-compressed literals inside sequence blocks when the literal payload is compressible,
  raw-block-cost-aware compressed-block selection
  (falling back to raw/RLE blocks when compressed blocks would expand, for
  broad zstd CLI compatibility), plus deterministic smallest-mode
  native selection, configurable native block size, optional content
  checksum/content-size header fields, skippable frame append/encode-into writer,
  decoded-size preflight, bounded allocation, explicit Dictionary_ID/preset
  history decode APIs, direct-output incremental decode for raw/RLE/compressed
  native frames (including dictionary, dictionary-set, no-content-size,
  bounded-history multi-block paths, per-block compressed-input retention when
  a frame exceeds the configured buffer limit, and resumable zero-scratch
  output for raw/RLE/Huffman literals and sequence execution across arbitrary
  caller output boundaries (including complete frames prevalidated by the direct
  path), plus header-only incremental discard/capture of arbitrarily large
  skippable-frame payloads), zero-allocation native stream/block iterators, and
  dependency-free standard full-dictionary generation from caller-selected
  history content using portable baseline entropy tables, plus first-stage
  corpus training of a complete literal Huffman alphabet and OF/ML/LL sequence
  FSE tables, plus measured first-sequence repcode selection that retains the
  baseline `1/4/8` values unless a retrained candidate strictly reduces the
  corpus's encoded bytes by at least 1%, with strict parsing and
  bidirectional libzstd interoperability validation,
  standardized seekable-stream encoding with output-bound, caller-owned-buffer, reusable encoder, and deterministic caller-selected parallel frame APIs, plus zero-allocation terminal seek-table parsing/iteration and bounded range decode (including preset-dictionary encoding, dictionary-set frame selection, optional per-frame checksum verification, decompressed-offset lookup, and a reusable caller-owned cumulative index with O(1) entry access and O(log n) offset lookup),
  caller-owned encode/decode-into/append, incremental raw/RLE frame encode with optional pledged content size and Dictionary_ID metadata, reusable native scratch encoder/decoder APIs, plus a reusable level-aware frame encoder that preserves adaptive selection policy while retaining primary scratch,
  used by downstream
  projects such as `../mcap` so compression algorithms stay centralized in
  Vort;
- pure Zig LZ4 legacy-frame parsing and deterministic writing with independent
  blocks up to 8 MiB, zero-allocation metadata iteration, decoded-size preflight,
  bounded/caller-owned decode, one-block-bounded incremental encode/decode, system
  `lz4 -l` interoperability, and automatic TAR/CPIO legacy-magic detection;
- pure Zig Windows LZNT1 encoding and decoding with 4 KiB chunks, dynamic
  length/displacement token partitions, overlapping-copy matches, stored-block
  fallback, optional end markers, inter-chunk zero padding, decoded-size
  preflight, bounded/caller-owned APIs, MS-XCA official vectors, and
  bidirectional differential validation against the pinned `lznt1` reference;
- pure Zig Windows XPRESS plain/LZ77 and XPRESS-Huffman encoding and decoding:
  plain streams provide MSB-first flag words, 8 KiB matches, overlapping copies,
  and shared half-byte plus byte/u16/u32 lengths; Huffman blocks provide adaptive
  512-symbol canonical tables, 64 KiB history, interwoven raw length bytes, and
  exact-size bounded decode. Both modes have caller-owned APIs, MS-XCA official
  vectors, fuzzing, and pinned Rust/Python plus wimlib interoperability;
- pure Zig Windows LZMS raw-block encoding and decoding with forward 16-bit
  range coding, backward adaptive canonical Huffman codes, mandatory x86
  address transforms, reusable decoder state, exact-size/caller-owned APIs,
  pinned fixtures, fuzzing, and bidirectional wimlib text, delta, mixed, source,
  and x86-code differentials. The reference encoder emits adaptive literal
  items today; LZ/delta match parsing remains ratio work;
- dependency-free WOF/CompactOS file-provider metadata and backing-stream
  support with XPRESS4K/8K/16K and WIM-LZX chunks, strict 32-/64-bit cumulative
  offset tables, raw-chunk fallback, bounded whole-file and random-range decode,
  deterministic XPRESS compression plus LZX raw writing, reparse/ioctl metadata
  parsing, pinned fixtures, fuzzing, and bidirectional wimlib differentials;
- pure Zig Apple LZFSE stream and raw LZVN support with `bvx-`, `bvxn`, `bvx1`,
  and `bvx2` decoding, compressed frequency-table and four-way literal FSE
  reconstruction, bounded/caller-owned APIs, deterministic LZVN-or-stored block
  writing, strict stream termination, and bidirectional Apple reference
  interoperability;
- pure Zig Apple `decmpfs` transparent-file decoding for inline types 1/3/7/9/11
  and resource-fork types 4/8/12, with strict 16-byte xattr headers, zlib
  resource descriptors, Apple LZVN/LZFSE offset tables, stored-block markers,
  bounded whole-file and 64 KiB-aware range decoding, a pinned `ditto` resource
  fork, fuzzing, and Python zlib plus Apple LZFSE interoperability;
- dependency-free Apple DMG/UDIF reading and deterministic single-partition
  writing with `koly` trailers, XML-plist/Base64 `blkx` maps, sparse/copy/ADC/
  zlib/Bzip2/LZFSE/XZ chunks, CRC verification, bounded whole-partition and
  random-range decoding, a standalone Apple ADC codec, a pinned `hdiutil`
  image, fuzzing, and 7-Zip plus dmg2img interoperability;
- dependency-free Apple PBZX reading/writing with the verified chunk-size
  header semantics, stored or independent XZ chunks, bounded whole-stream and
  random-range decoding, explicit XZ dictionary limits, fuzzing, and system-XZ
  plus independent PBZX interoperability;
- dependency-free XAR/XIP/PKG container reading and deterministic writing with
  nested files/directories/symlinks, stored/zlib/Bzip2/LZMA-Alone/XZ payloads,
  TOC and per-entry SHA-1/MD5/SHA-256/SHA-512 verification, explicit heap and
  dictionary limits, a pinned Apple `xar` fixture, fuzzing, and bidirectional
  libarchive plus 7-Zip interoperability;
- pure Zig ZFS on-disk block compression support for uncompressed/empty,
  LZJB, gzip-1...9, ZLE, ZFS-LZ4, and ZFS-Zstd, including physical-block
  padding semantics, Zstd level/version metadata, deterministic writers,
  a pinned OpenZFS LZJB fixture, fuzzing, and bidirectional OpenZFS plus system
  codec differentials;
- dependency-free QCOW2 v2/v3 image reading and deterministic writing with
  L1/L2 mapping, sparse and zero clusters, raw-DEFLATE and Zstandard compressed
  clusters, extended-L2 subclusters, caller-supplied raw backing/external data
  files, bounded whole-image and random-range decoding, fuzzing, and
  bidirectional QEMU plus 7-Zip interoperability;
- dependency-free hosted-sparse VMDK reading and deterministic monolithicSparse
  plus streamOptimized writing, with grain directory/table lookup, unallocated
  and explicit-zero grains, logical backing bytes, zlib-compressed embedded-LBA
  grains, standard GT/GD/footer/EOS markers, bounded whole-image and random-range
  decoding, a pinned QEMU version-3 fixture, fuzzing, and bidirectional QEMU plus
  7-Zip interoperability;
- dependency-free EWF1/E01 forensic-image reading and deterministic EnCase-6
  style writing, with explicit multi-segment sets, checked section chains,
  volume geometry, sectors/table/table2 chunk maps, raw chunks with Adler-32,
  zlib chunks, media MD5 verification, bounded whole-image and random-range
  decoding, pinned libewf single/multi-segment fixtures, fuzzing, and
  bidirectional libewf interoperability;
- dependency-free CHD v5 reading and deterministic writing, with simple and
  Huffman/RLE compressed maps, metadata chains, raw/self/parent hunks,
  raw-DEFLATE/LZMA/Huffman/Zstandard codecs in both directions, per-hunk
  automatic codec selection, checked metadata and parent-delta writing,
  CRC-16 and SHA-1 verification,
  bounded whole-image and random-range decoding, pinned chdman fixtures,
  fuzzing, and bidirectional chdman interoperability;
- dependency-free classic VHD reading and deterministic fixed/dynamic/
  differencing writing, with checked footer/dynamic headers, bounded BAT and
  sector bitmaps, sparse blocks, explicit parent UUID chains, whole-image and
  random-range decoding, a pinned QEMU fixture, fuzzing, and bidirectional
  QEMU plus 7-Zip interoperability;
- dependency-free VHDX reading and deterministic dynamic/fixed/differencing
  writing, with redundant CRC-32C headers and region tables, required metadata,
  interleaved BAT entries, sparse MiB-aligned payload blocks, parent locators,
  shared sector bitmaps, bounded whole and random-range reads, a pinned QEMU
  fixture, fuzzing, and bidirectional QEMU plus 7-Zip interoperability;
- dependency-free CISO v1/v2 and ZISO reading and deterministic writing, with
  raw, raw-DEFLATE, and LZ4 blocks, shifted indexes and alignment padding,
  per-block CISO v2 codec selection, raw fallback, exact partial tails,
  bounded whole-image and random-range decoding, fuzzing, and bidirectional
  maxcso interoperability;
- dependency-free DAX v0/v1 reading and deterministic writing, with fixed
  8192-byte zlib frames, canonical non-compressed area tables, automatic raw
  fallback, exact partial tails, bounded whole-image and random-range decoding,
  a pinned maxcso fixture, fuzzing, and bidirectional maxcso interoperability;
- dependency-free Dolphin GCZ reading and deterministic writing, with zlib/raw
  blocks, high-bit block pointers, stored-payload Adler-32 verification,
  automatic raw fallback, exact partial tails, bounded whole-image and
  random-range decoding, a pinned current-Dolphin fixture, fuzzing, and Python
  zlib plus DolphinTool differential coverage;
- pure-Zig WIA/RVZ reading and deterministic raw/explicit-partition writing,
  with none,
  purge, Bzip2, raw LZMA/LZMA2, and Zstandard codecs, dual SHA-1-protected
  headers, compressed metadata tables, per-group RVZ fallback/zero handling,
  RVZ junk-packing decode, Wii partition SHA-1 tree reconstruction, AES
  decrypt/re-encrypt, hash-exception generation, bounded standard-Wii partition
  discovery with caller-owned common keys, bounded range reads, independent
  partition fixtures, fuzzing, and bidirectional DolphinTool interoperability;
- pure-Zig WBFS reading and deterministic single-disc writing, with bounded
  WLBA validation, fixed dual-layer logical geometry, zero-filled sparse
  blocks, split-file byte-slice input, partial tails, bounded range reads,
  independent Python wire-format comparison, fuzzing, and DolphinTool
  recognition;
- pure-Zig WDF1/WDF2 reading and deterministic writing, with strict big-endian
  header/chunk validation, zero-filled logical holes, caller-provided split
  input, sparse/full modes, partial tails, bounded range reads, independent
  Python comparison, fuzzing, and bidirectional Wiimms `wdf`/`wit`
  interoperability;
- pure-Zig Wii U WUX reading and deterministic sector-deduplicating writing,
  with strict little-endian header/index validation, repeated-sector range
  reads, collision-safe SHA-256-assisted reuse, partial tails, independent
  Python comparison, fuzzing, and bidirectional original-WudCompress coverage;
- pure-Zig Android sparse image v1 reading and deterministic writing, with
  RAW/FILL/DONT_CARE/CRC32 chunks, extended headers, bounded whole-image and
  range reads, checkpoint and header CRC-32 verification, independent Python
  comparison, fuzzing, and bidirectional AOSP `simg2img`/`img2simg` coverage;
- dependency-free Android update-engine payload v2 reading and deterministic
  full-payload writing, with a bounded proto2 manifest parser, multi-partition
  RAW/Bzip2/XZ/ZERO operations, SOURCE_COPY/SOURCE_BSDIFF/BROTLI_BSDIFF delta
  extraction, PUFFDIFF with byte- and bit-aligned Deflate extents,
  LZ4DIFF_BSDIFF/LZ4DIFF_PUFFDIFF with liblz4-compatible fixed-output LZ4 and
  LZ4HC reconstruction plus postfix correction, bounded Zucchini v1 NoOp/raw
  and AArch64 ELF elements behind the Android Brotli envelope,
  BSDIFF40/BSDF2/PUF1 patch
  streams, SHA-256 checks, bounded range reads, fuzzing, independent
  Python/liblz4 validation, and Rust
  `payload_dumper` interoperability;
- dependency-free zchunk v1 parsing, verification, deterministic none/Zstd
  writing, SHA-1/SHA-256/SHA-512/SHA-512/128 chunk hashes, dictionaries,
  source hashes, optional/header-only metadata, stream-aware indexes, bounded
  full-stream and individual-chunk extraction, and `zck`/`unzck`
  interoperability;
- dependency-free SquashFS v4 reading with compressed metadata, short/long
  inode and directory layouts, nested path lookup, sparse/data/fragment blocks,
  regular-file and symlink extraction, gzip/LZMA/LZO/XZ/LZ4/Zstd codecs,
  explicit output limits, plus deterministic stored/gzip/LZMA/LZO/XZ/LZ4/Zstd
  writing for regular files, nested/empty directories, symlinks and packed
  fragments, with squashfs-tools interoperability;
- dependency-free EROFS reading with CRC-32C superblock verification,
  compact/extended inodes, flat plain/inline data, sorted directories,
  symlinks, legacy full and modern compact compression indexes, big pclusters,
  and LZ4/MicroLZMA/raw-Deflate/Zstandard extraction with explicit bounds, plus
  deterministic compact-inode stored/LZ4/raw-Deflate/Zstandard writing for
  regular files, nested and empty directories, symlinks, inline tails,
  multi-block directories, compression-configuration records, and per-cluster
  compressed-or-plain full-index selection with erofs-utils interoperability;
- dependency-free WIM/ESD/SWM parsing with strict 208-byte headers, compression
  and part geometry, resource headers, lookup tables, SHA-1 verification, raw
  UTF-16 XML access, bounded resource extraction, validated image-metadata
  security tables, borrowed dentry/extra-stream views, directory iteration,
  UTF-16LE path lookup, and bounded regular-file extraction by image/path.
  Stored, XPRESS-Huffman, WIM-flavored LZX, and LZMS chunks are decoded across
  multi-chunk resources; LZMS metadata chunks and alternate-table solid LZMS
  resources support bounded individual-blob extraction without materializing
  the whole solid stream. Pipable sequential extraction, caller-ordered SWM
  sets, encrypted/reparse/ADS path selectors, encrypted-ESD reconstruction,
  DOS short-name aliases, generic tagged metadata, typed object-ID/Unix/xattr
  helpers,
  and deterministic stored/XPRESS/LZX/LZMS one-/multi-image, packed LZMS/ESD,
  SWM, pipable and pipable-SWM writing plus ordinary/solid image append and
  deletion/replacement plus physical compaction are also available;
- raw deflate stored/fixed/dynamic/best encode and stored/fixed/dynamic decode,
  with zlib/gzip wrappers plus preset-dictionary-aware raw/zlib encode/decode;
  Zig-native incremental encoders provide `blockFlush()`/`partialFlush()` with
  zlib `Z_BLOCK`/`Z_PARTIAL_FLUSH` semantics for raw stored/fixed/best and
  zlib/gzip fixed/best streams, while
  raw/zlib/gzip Best encoders support asynchronous runtime level/strategy
  changes through `DeflateParams` and `requestParams()`; raw recovery APIs scan
  full-flush `00 00 ff ff` markers and decode or incrementally resume the next
  independent segment after payload corruption;
- dependency-free BGZF blocked-gzip parsing/writing with strict `BC`/`BSIZE`
  validation, per-block DEFLATE/CRC/ISIZE checks, bounded concatenated decode,
  canonical EOF markers, 48:16 virtual offsets, and cross-block virtual-range
  extraction;
- dependency-free ZIP32/ZIP64 archive reading and deterministic writing with
  EOCD/ZIP64-locator/central-directory iteration, exact entry lookup, stored,
  Shrink-method-1, Reduce-methods-2...5, Implode-method-6, raw-Deflate,
  Deflate64-method-9, DCL-Implode-method-10, Bzip2-method-12, LZMA-method-14,
  legacy/current Zstandard-method-20/93, XZ-method-95, and PPMd-method-98
  multi-entry encoding/extraction (including fixed-Huffman or stored
  Deflate64 output with the extended 64 KiB distance alphabet),
  transactional one-shot prefix append plus caller-output incremental
  writing for every listed method, including per-entry Traditional ZipCrypto,
  signed data descriptors, known or unknown size pledges, ZIP32/ZIP64 policy,
  SFX offsets, and payload-bounded memory;
  archive/entry comments, opaque Archive Extra Data Records with correct
  central-offset/size and atomic split placement, configurable validated DOS modification timestamps,
  Info-ZIP `0x5455` Unix times, NTFS `0x000a` 100 ns FILETIME values,
  Info-ZIP `0x7075` Unicode paths and `0x6375` Unicode comments with CRC-bound
  legacy-name fallback and preferred-name lookup,
  creator-system/internal/external attributes, Unix mode/symlink helpers,
  CRC-32/size validation, UTF-8 flags, per-entry
  Traditional ZipCrypto one-shot writing/reading plus known-size and descriptor-
  backed sequential reading backed by Vail's dedicated archive-crypto package
  with explicit caller-supplied header entropy and passwords; WinZip AE-1/AE-2
  AES-128/192/256 one-shot reading/writing, bounded incremental writing, and
  known-size/descriptor-backed sequential reading with explicit caller salt and Vail-backed
  PBKDF2/CTR/HMAC; password-based PKWARE Strong Encryption AES-128/192/256
  one-shot reading plus one-shot/bounded incremental writing with caller-owned
  IV/random/validation entropy,
  strict `0x0017`/bit-6/decryption-header validation, and Vail-backed SHA-1
  key derivation/AES-CBC/PKCS#7, plus known-size and signed/unsigned descriptor
  sequential reading; ordered split/multi-disk ZIP32/ZIP64 normalization with
  strict disk-coordinate and allocation limits, cross-volume payload/descriptor
  extraction through the ordinary archive codecs, plus an O(parts + entries)
  sparse metadata-patch stream and bounded sequential reader that avoid a
  joined archive copy, an on-demand `PartSource` reader that can release prior
  physical volumes, plus deterministic owned split writing that keeps all
  structural records atomic while allowing payloads to cross volumes, and an
  incremental split writer with bounded current-part/control storage plus
  explicit `part_done` sink transitions; and explicit unsupported certificate/
  non-AES strong-encryption and unknown-method errors;
- dependency-free Bzip2 `BZh1`...`BZh9` encoding and decoding with canonical Huffman,
  selector/inverse move-to-front, RUNA/RUNB, inverse BWT, first-stage RLE,
  legacy randomized-block reversal, multi-block and explicit
  concatenated-stream support, caller-owned/bounded allocation APIs,
  decoded-size preflight, and block/combined CRC validation,
  plus block-bounded caller-output incremental decoding with arbitrary input
  fragmentation, non-byte-aligned block continuation, zero-output
  backpressure, concatenated members, exact-size pledges, and reusable scratch,
  plus block-bounded incremental encoding with split-independent deterministic
  wire, cross-call RLE runs, flushable BWT blocks, concatenated continuation,
  pledged input sizes, and caller-output backpressure;
- dependency-free XZ decoding for LZMA2 streams with optional Delta and all
  eight BCJ filters including ARM64/RISC-V, strict stream/block/index/footer validation,
  none/CRC-32/CRC-64/SHA-256 checks, multi-block and concatenated-stream
  handling, bounded APIs and metadata inspection, plus deterministic
  filter-aware XZ writing with greedy LZMA matches, repeat distances, a stored
  fallback, caller-selected 4 KiB...64 MiB cross-chunk LZMA2 dictionary reuse,
  and separate greedy/lazy ratio encode APIs, plus block-bounded
  caller-output incremental decoding with
  arbitrary input fragmentation, zero-output backpressure, stream padding,
  concatenated members, independent compressed/decoded/dictionary/Index
  limits, exact-size pledges, and reusable container scratch, plus block-bounded
  incremental compressed/stored encoding with split-independent wire,
  Delta/BCJ filters, selectable checks, flushable blocks, Index/Footer
  generation, concatenated continuation, pledged input, and output backpressure,
  plus a chunk-bounded raw LZMA2 caller-output decoder with persistent
  probability/dictionary state for embedding formats such as 7z;
- dependency-free LZMA-Alone encoding and decoding with known-size or
  end-marker streams, caller-selected output/dictionary limits, caller-owned
  output, exact-size MicroLZMA decoding with inverted properties and strict
  compressed-size/range termination, and ZIP method-14 writing/extraction
  through the same LZMA core, plus symbol-progressive LZMA-Alone decoding with
  bounded compressed staging, rolling dictionary history, single-symbol output
  staging, arbitrary input/output splits, zero-output backpressure, exact-size
  pledges, and distinct known-size/end-marker completion semantics, plus
  symbol-progressive literal/greedy encoding with persistent probability/range/
  recent-distance state, bounded lookahead/history, split-independent wire,
  pledged known-size headers, end-marker streams, reset, and output backpressure;
- pure Zig Unix `compress` (`.Z`) LZW encoding and decoding with 9..16-bit
  variable-width LSB-first codes, block-mode dictionary clears, non-block
  dictionary freeze, caller-owned/bounded APIs, bit-progressive incremental
  encoding/decoding, and decoded-size preflight;
- pure Zig lzip v1 encoding and decoding with LZMA-302eos payloads, coded
  dictionary sizes, per-member CRC/data/member-size validation, deterministic
  concatenated writing, strict multimember handling, and caller-selected output
  and dictionary limits, plus bounded incremental multi-member encoding and decoding;
- pure Zig raw LZF block and standard `ZV` stream encoding/decoding with
  8 KiB match distances, 65,535-byte stored/compressed blocks, optional EOF markers,
  bounded/caller-owned APIs, one-block-bounded incremental encode/decode,
  decoded-size preflight, metadata inspection, and
  automatic `.tar.lzf` composition;
- dependency-free LHA/LZH level-0/1/2/3 and SFX-prefix reading plus deterministic
  level-0 writing with stored, LH1, LH4, LH5, LH6, LH7, LZ5, LZS, and directory
  entries, chained filename/path and common-CRC extended headers, payload CRC-16,
  bounded extraction, adaptive/fixed Huffman models, and legacy LArc histories;
- dependency-free Unix `ar` reading/writing with traditional, GNU string-table,
  and BSD inline long names, bounded extraction, GNU/LLVM thin archive metadata,
  explicit external-member resolution, allocation-free GNU and BSD/Darwin
  32/64-bit symbol-index lookup, deterministic regular BSD armap writing, and
  deterministic thin writing with linker-usable GNU armap output, plus
  Debian binary package parsing/writing with validated
  `debian-binary`, control/data TAR members, and none/gzip/Bzip2/LZMA/XZ/Zstd
  compression, validated bidirectionally with GNU `ar` and `dpkg-deb`, plus
  bounded RPM lead/signature/main-header parsing, MD5/SHA1/SHA256 integrity
  verification, deterministic unsigned writing, and CPIO payload extraction
  for none/gzip/Bzip2/LZMA/XZ/Zstd payloads with 7-Zip differential validation;
- dependency-free ARJ/SFX reading and deterministic writing with CRC-validated
  main/local/extended headers, stored and methods 1–4, no-data and directory
  entries, bounded extraction, encrypted/multi-volume rejection, and external
  ARJ plus 7-Zip interoperability;
- dependency-free ARC/PAK/SFX reading and deterministic ARC writing for stored,
  packed RLE90, Squeeze, old fixed-12-bit Crunch, dynamic Crunch, and Squash
  plus PAK Crushed and Distilled methods 1–11, including PAK trailers, CRC-16,
  bounded extraction, CLEAR/code-width transitions, and external ARC 5.21/
  unarc-rs interoperability;
- dependency-free ZOO reading and deterministic type-2 archive writing for
  stored, 9–13-bit/8192-entry LZD, and LH5 methods, with absolute directory
  chains, long names and paths, data leaders, directory/content CRC-16,
  bounded extraction, hostile-offset/path validation, and original Zoo 2.10
  bidirectional interoperability;
- pure Zig LZO1X encoding/decoding plus LZOP parsing and deterministic
  compressed-or-stored writing, including Adler-32/CRC-32 header, data, and
  compressed-block checks, legacy delta filters, concatenated streams, and
  bounded output/block APIs, plus caller-output incremental decoding with
  arbitrary input splits, zero-sized output backpressure, bounded header/block
  retention, exact-size pledges, reusable state, and checksum-before-output,
  plus block-bounded incremental compressed-or-stored/stored-only encoding with
  split-independent wire, Adler/CRC metadata, flushable blocks, concatenated
  continuation, pledged input sizes, and caller-output backpressure;
- pure Zig 7z parsing and deterministic independent-folder writing, with
  Copy/Deflate/Bzip2/LZMA/LZMA2/PPMd7 decode and encode,
  bounded linear Delta/BCJ filter chains including ARM64/RISC-V, BCJ2
  four-stream graphs in both directions, and independent 7zAES on all four
  BCJ2 packed branches,
  compressed Next Header reading and writing, solid substream reading and
  writing, bounded AdditionalStreamsInfo decoding, external folder/name
  references, inline/external FILETIME and platform attributes, optional
  seven-codec external name/metadata writing, 7zAES/SHA-256 data and encoded
  header reading/writing backed by Vail crypto with explicit password/KDF
  limits and caller-supplied IV material, CRC validation, UTF-16LE names,
  directories, empty files, and bounded extraction, plus source-backed
  positional parsing that avoids loading the complete archive and fetches only
  tail/auxiliary metadata plus selected-folder packed ranges, and a
  symbol-progressive source entry decoder for Copy/Deflate/Bzip2/LZMA/LZMA2/PPMd7,
  7zAES, solid-substream selection, Delta, all classic BCJ filters, and BCJ2's
  independently packed MAIN/CALL/JUMP/range branches, plus ordered standard
  `.7z.001` multi-volume slices or on-demand part callbacks without a joined
  archive allocation;
- deterministic TAR reading/writing with USTAR, PAX and GNU long-name support,
  old GNU plus PAX sparse 0.0/0.1/1.0 reading, deterministic PAX-1.0 and
  old-GNU writing with chained sparse extension headers,
  strict extent validation, logical hole reconstruction, safe-path
  classification, borrowed entry views, bounded caller-output incremental
  raw reading and writing for regular/link/PAX/sparse entries, direct incremental
  gzip/Bzip2/Brotli/Unix-compress/LZMA/XZ/modern+legacy-LZ4/LZF/lzip/
  Zstandard/LZOP-to-TAR reading, bounded 512-byte incremental auto-dispatch
  with streamed shared skippable frames, bounded gzip/Bzip2/Brotli/LZMA/XZ/
  Unix-compress/modern+legacy-LZ4/LZF/lzip/Zstandard/LZOP compressed-TAR
  writing, and automatic raw/gzip/Bzip2/Brotli/
  Unix-compress/LZMA-Alone/XZ/
  LZ4/lzip/LZF/Zstandard/LZOP tarball composition;
- dependency-free CPIO reading and deterministic writing for SVR4 newc/CRC,
  POSIX ODC, and little-/big-endian old binary archives, including regular,
  directory, symlink, and special-file metadata, strict per-format alignment,
  bounded extraction, bounded caller-output incremental reading and writing
  for all five formats, streamed CRC/alignment/trailer verification, exact
  entry events and progress, safe-path classification, GNU cpio bidirectional
  interoperability, bounded incremental composition with twelve gzip/Bzip2/
  Brotli/compress/LZMA/XZ/modern+legacy-LZ4/lzip/LZF/Zstd/LZOP wrappers,
  14-byte bounded incremental auto-dispatch with structural LZMA probing,
  Brotli fallback and streamed LZ4/Zstd skippable-frame handling, and
  bounded concatenated raw-CPIO sequences with explicit archive boundaries,
  mixed header families and initramfs zero padding, mixed raw/gzip/Bzip2/Brotli/
  LZMA/XZ/modern-LZ4/Zstd/EOF-marked-LZF/lzip/LZOP sequence dispatch with
  bounded suffix replay, plus explicitly sized Unix-compress/legacy-LZ4 members,
  plus automatic one-shot composition with the corresponding raw/wrapped modes;
- dependency-free RAR4/RAR5 container parsing plus deterministic stored-file
  and directory writing, non-solid RAR15 and RAR20/26 decompression including
  adaptive/ST-mode, dynamic Huffman, multiblock, table reuse, long-history and
  audio paths, ordinary and solid RAR29 LZ with dynamic/low-distance tables and
  4 MiB history, plus allocator-backed PPMd Variant H with bounded model memory,
  escape literals and match tokens, all six standard RAR VM filters and a
  bounded generic VM interpreter, SFX discovery, both header CRC variants,
  payload CRC-32,
  UTF-8 RAR5 names, RAR50 LZ and Delta/E8/E8E9/ARM filters, sequential solid
  sessions with pre-filter history, bounded extraction, RAR5 AES-256-CBC
  Stored/RAR50 file-data encryption through Vail with explicit PBKDF2 limits,
  password checks and keyed CRCs, owned RAR5 encrypted-header parsing and
  deterministic writing with independent per-header IVs, plus RAR4 salted or
  unsalted AES-128 data/header encryption with historical long-password KDF
  behavior, RAR15 byte-stream and RAR20/26 self-updating block decryption through
  Vail, and allocator-owned custom Unicode preferred names with deterministic
  UTF-16 writer fields, explicit redirection/unknown-size errors, sequential
  same-generation and mixed RAR15/RAR20 solid continuation, ordered RAR4/RAR5
  multi-volume reconstruction for stored/compressed/solid split entries, and
  deterministic RAR29 compatibility LZ writing with canonical tables,
  table-length RLE, multiblock output, 64 KiB through 4 MiB declared
  dictionaries and cross-member solid history, pure Zig RAR29 PPMd Variant H
  literal/escape writing with solid model continuation, RAR29 LZ writing with
  E8/E8E9/Delta/Itanium/RGB/Audio VM filters across ordinary and solid members,
  PPMd-attached VM records across
  ordinary/solid/encrypted/split members, and 7-Zip/unrar interoperability, plus
  deterministic RAR50 LZ writing with canonical tables, multiblock output, and
  Delta/E8/E8E9/ARM filters plus cross-member solid history, post-compression
  RAR5 file-data/header encryption, and deterministic stored/compressed/solid
  volume splitting including encrypted headers and arbitrarily fragmented
  ciphertext, with RAR, 7-Zip, and rars interoperability;
- dependency-free deterministic Microsoft CAB writing plus parsing and bounded
  extraction for Stored, MSZIP, 15–21 bit LZX, and 10–21 bit Quantum folders,
  including Stored/MSZIP, reference uncompressed-block LZX, and literal
  arithmetic Quantum writing, reserve areas, checksum validation, cross-block
  history, complete LZX decode modes, Intel E8 postprocessing, adaptive Quantum
  models, deterministic size-bounded multi-cabinet writing and explicitly
  ordered set decoding with split CFDATA, mixed-folder archives, and safe
  borrowed paths;
- dependency-free Brotli `br` stored/uncompressed and planner-backed fast encode/decode surfaces, including a Vort-native deterministic q0...q11 by generic/text/font preset matrix across one-shot, reusable, chunked, incremental, and larger-than-16-MiB multi-meta-block inputs (the [exact capability and gap table](docs/performance/brotli-quality-presets.md) does not claim libbrotli algorithm, byte, ratio, or throughput parity), explicit 10..16-bit one-shot planned windows at every level and the complete 10..24 range at ratio level with distance-bounded matching, exact-wire-selected bounded 2..6-region literal/command/distance entropy splitting and cyclic tree clustering for heterogeneous ratio inputs, adaptive literal context modeling across the complete 2..64 useful tree range with arbitrary clustered 64-entry maps, exact plain/MTF/zero-run map arbitration, and all RFC LSB6/MSB6/UTF8/Signed modes, one-shot planned metadata at every level, opt-in bounded static-dictionary probing for 257-byte through 4 KiB ratio inputs, arbitrarily large planned inputs encoded as one bounded-memory multi-meta-block stream, a caller-to-caller incremental planned encoder with flush/metadata, compressed-or-stored arbitration, quality/level policy, and bounded cross-block LZ77/recent-distance history, chunked encoding with the same history-aware block core plus 10..24-bit window and metadata options, strict-by-default RFC 7932 window bits 10..24 plus explicit opt-in decoding of the Large Window Brotli 10..30-bit extension across one-shot, chunked, summary, and symbol-progressive incremental APIs, borrowed RAW shared-prefix/compound-dictionary encoding and decoding with zero through fifteen ordered attachments across the planned surfaces, metadata meta-block skipping, caller-history stream summaries for large-window preflight without hidden allocation, an allocator-owned general incremental decoder with bounded history and grow-on-demand bounded compressed-header storage but no complete compressed or decoded frame buffer, byte-progressive stored-subset encode/decode, and bounded-header byte-progressive decoders for insert-only Huffman literals, single-command RLE, and copy streams with literal/distance context maps, entropy block switching across the complete 256-entry literal/command/distance block-type count range and literal/distance context-tree ranges, optional caller-owned compressed-header scratch beyond the default 16 KiB embedded capacity, dynamic direct/regular/recent distances, transformed static-dictionary references, non-final compressed blocks followed by metadata/stored blocks and a final-empty terminator, plus libbrotli streaming-operation differentials covering PROCESS accumulation, empty/repeated FLUSH, METADATA transitions, and FINISH with pending input; compressed output honors caller backpressure and copy history is explicit or allocator-owned according to the selected API;
- dependency-free Snappy raw block full decode plus greedy match raw/framed encode with reusable encoder state, encoded-bound helpers, raw-block and framed-stream summaries, split-input and exact-size decode helpers, decoded-size preflight, bounded allocation, masked CRC-32C validation, skippable framed chunks, and caller-owned incremental framed encode/decode with 64 KiB input chunking, optional pledged input/output sizes, split headers/payloads, bounded input/output memory, tiny-output draining, exact-output continuation through following skippable chunks, reset/next-stream reuse with cumulative and per-stream counters, snapshots, and diagnostics;
- Xerial Snappy version-1 and Hadoop BlockCompressorStream Snappy framing with
  deterministic multi-block writing, strict big-endian nested lengths,
  exact outer-block accounting, bounded allocation, caller-owned decode, and
  shared block-bounded incremental encoders/decoders with arbitrary
  input/output fragmentation, zero-output backpressure, pledged input/output
  sizes, deterministic one-shot-exact unflushed encoding, explicit flush,
  compressed/decoded chunk and pending-output limits, reset, snapshots, and
  diagnostics;
- Hadoop LZ4 `BlockCompressorStream` framing with raw inner LZ4 blocks,
  token-derived decoded-size validation, deterministic nested-block writing,
  bounded allocation, caller-owned decode, and block-bounded incremental
  encode/decode with arbitrary fragmentation, zero-output backpressure,
  one-shot-exact unflushed output, explicit outer-block flush, pledged sizes,
  compressed/decoded/pending limits, retained-scratch reset, snapshots, and
  diagnostics;
- Hadoop LZO `.lzo.index` parsing/generation with strict LZOP block-boundary
  validation, big-endian offset lookup, indexed block-range decode, filter and
  checksum handling, and explicit output limits;
- a native `VORT` store frame with skippable frames, concatenated streams, checksum-validated in-memory/serialized frame indexes, frame-index CRC composition, range CRC summaries, caller-owned and batch range decode APIs, and bounded streaming APIs;
- LZ77 greedy/lazy/optimal parser prototypes, dictionary metadata/training, match-coverage, patch-codec, native dictionary-patch frame, self-contained dictionary streams, native LDM reference frame, and dictionary-/LDM-aware native best-frame prototypes, long-distance match scanner, LDM-aware block planner, CLI smoke surfaces, fuzz corpus harnesses, and benchmark/report entrypoints.

Hosted CI runs on `main` pushes and pull requests through
`.github/workflows/ci.yml`, which installs Zig 0.16, checks formatting, runs
`ci-smoke`, and repeats the focused fuzz smoke entrypoints. The `ci-smoke`
target now includes `run-native-codec-probes-dashboard`, so the library-level
LZ4/Zstd frame and dictionary probes run together in CI and retain JSON/Markdown
artifacts rather than only existing as manual commands.
The standalone `check-wasm` gate compiles the complete library and its
out-of-line Brotli/Zstd optimized objects for baseline `wasm32-wasi`. Native
wide-Huffman decoding retains its 64-byte function alignment; WebAssembly uses
the same inlined decode body through a target-safe unaligned wrapper.

## Commands

```sh
zig build test
zig build check
zig build check-wasm
zig build -Doptimize=ReleaseFast ci-smoke
zig build run -- --help
zig build -Doptimize=ReleaseFast run-zstd-dictionary-trainer-compare -j1
zig build -Doptimize=ReleaseFast run-dictionary-train-bench-gate -j1
zig build -Doptimize=ReleaseFast run-zstd-native-encode-stage-bench-gate
zig build run -- checksum "hello vort"
zig build run -- store-roundtrip "hello vort"
zig build run -- vort-deflate-roundtrip "hello vort"
zig build run -- vort-blocked-range-demo
zig build run -- vort-blocked-best-range-demo
zig build run -- vort-sidecar-blocked-best-range-demo
zig build run -- vort-dict-blocked-range-demo
zig build run -- vort-self-dict-range-demo
zig build run -- vort-trained-dict-range-demo
zig build run -- vort-seekable-native-range-demo
zig build run -- vort-ldm-summary-demo
zig build run -- vort-ldm-blocked-range-demo
zig build run -- vort-sidecar-ldm-range-demo
zig build run -- vort-ldm-indexed-range-demo
zig build run -- store-range-demo
zig build run -- store-sidecar-range-demo
zig build run -- store-sidecar-dict-range-demo
zig build run -- encode-vort-sidecar-best-file README.md /tmp/readme.vort /tmp/readme.vidx 4096
zig build run -- encode-vort-embedded-best-file README.md /tmp/readme-embedded.vort 4096
zig build run -- encode-vort-embedded-dict-file README.md /tmp/readme-embedded-dict.vort 4096
zig build run -- verify-vort-sidecar-index-file /tmp/readme.vort /tmp/readme.vidx
zig build run -- verify-vort-sidecar-index-file /tmp/readme.vort /tmp/readme.vidx metadata
zig build run -- verify-vort-sidecar-index-file /tmp/readme.vort /tmp/readme.vidx full json
zig build run -- verify-vort-embedded-index-file /tmp/readme-embedded.vort
zig build run -- verify-vort-embedded-index-file /tmp/readme-embedded.vort metadata
zig build run -- verify-vort-embedded-index-file /tmp/readme-embedded.vort full json
zig build run-sidecar-verify-report -- /tmp/readme.vort /tmp/readme.vidx
zig build run-sidecar-verify-report -- --mode metadata /tmp/readme.vort /tmp/readme.vidx
zig build run-sidecar-corrupt-smoke
zig build run-sidecar-verify-report -- --self-test-corrupt --markdown /tmp/sidecar-corrupt.md --json /tmp/sidecar-corrupt.json
zig build run-sidecar-corrupt-dashboard
zig build run-validation-json-smoke
zig build run-validation-json-dashboard
zig build run-validation-json-docs-check
zig build run-dashboard-index  # writes zig-out/vort-dashboard-index.md/.json and enforces producer/smoke-gate mappings
zig build run-sidecar-verify-report -- --dir /tmp --limit 8 --keep-going
zig build run-sidecar-verify-report -- --markdown /tmp/sidecar-report.md --json /tmp/sidecar-report.json --dir /tmp
zig build run -- decode-vort-sidecar-range-file /tmp/readme.vort /tmp/readme.vidx /tmp/readme.range 32 64
zig build run -- decode-vort-embedded-range-file /tmp/readme-embedded.vort /tmp/readme-embedded.range 32 64
zig build run -- decode-vort-embedded-auto-range-file /tmp/readme-embedded-dict.vort /tmp/readme-embedded-dict.range 32 64
zig build run -- encode-vort-sidecar-dict-file README.md /tmp/readme-dict.vort /tmp/readme-dict.vidx 4096
zig build run -- decode-vort-sidecar-auto-range-file /tmp/readme-dict.vort /tmp/readme-dict.vidx /tmp/readme-dict.range 32 64
zig build run -- encode-vort-sidecar-ldm-file README.md /tmp/readme-ldm.vort /tmp/readme-ldm.vidx 4096
zig build run -- decode-vort-sidecar-range-file /tmp/readme-ldm.vort /tmp/readme-ldm.vidx /tmp/readme-ldm.range 32 64
zig build run -- zlib-store-roundtrip "hello vort"
zig build run -- gzip-store-roundtrip "hello vort"
zig build run -- list-zip-file /tmp/archive.zip
zig build run -- extract-zip-file /tmp/archive.zip path/in/archive.txt /tmp/archive.out 1048576
zig build run-zip-diff
zig build run -- encode-bzip2-file README.md /tmp/readme.bz2 9
zig build run -- decode-bzip2-file /tmp/archive.bz2 /tmp/archive.out 67108864
zig build run -- decode-bzip2-concat-file /tmp/members.bz2 /tmp/members.out 67108864
zig build run -- size-bzip2-file /tmp/archive.bz2 67108864
zig build run-bzip2-diff
zig build run -- encode-xz-file README.md /tmp/readme-compressed.xz crc64 1048576 delta:4
zig build run -- encode-xz-stored-file README.md /tmp/readme.xz crc64 1048576 delta:4
zig build run -- decode-xz-file /tmp/readme.xz /tmp/readme.out 67108864
zig build run -- inspect-xz-file /tmp/readme.xz
zig build run-xz-diff
zig build -Doptimize=ReleaseFast run-xz-encode-bench-gate
zig build -Doptimize=ReleaseFast run-xz-encode-bench -- --iterations 3 --rounds 5
zig build run -- encode-xz-file README.md /tmp/readme-lazy.xz crc64 1048576 none 131072 lazy
zig build run -- decode-lzma-file /tmp/archive.lzma /tmp/archive.out 67108864 67108864
zig build run -- size-lzma-file /tmp/archive.lzma 67108864
zig build run-lzma-diff
zig build run -- create-tar-file /tmp/archive.tar.gz payload.bin README.md gzip
zig build run -- create-tar-file /tmp/archive.tar.br payload.bin README.md brotli
zig build run -- create-tar-file /tmp/archive.tar.lzma payload.bin README.md lzma
zig build run -- list-tar-file /tmp/archive.tar.gz 67108864
zig build run -- extract-tar-file /tmp/archive.tar.gz payload.bin /tmp/payload.out 67108864
zig build run-tar-diff
zig build run -- list-cab-file /tmp/archive.cab
zig build run -- create-cab-file /tmp/archive.cab path\\file.bin README.md mszip 32768
zig build run -- extract-cab-file /tmp/archive.cab path\\file.bin /tmp/file.out 67108864 268435456
zig build run-cab-diff
zig build run -- encode-br-stored-hex "hello vort" 16 metadata
zig build run -- decode-br-hex 40001068656c6c6f03 5
zig build run-br-stored-corpus
zig build run-br-literal-cli-diff
zig build run-br-planned-node-diff
zig build -Doptimize=ReleaseFast run-br-planned-encode-bench-gate
zig build -Doptimize=ReleaseFast run-br-complete-dictionary-bench -- --iterations 10
zig build -Doptimize=ReleaseFast run-br-complete-dictionary-bench-gate
zig build -Doptimize=ReleaseFast run-br-context-tree-report
zig build -Doptimize=ReleaseFast run-br-context-tree-report-gate
zig build run-br-context-tree-report-dir-smoke
zig build -Doptimize=ReleaseFast run-br-context-tree-dashboard-gate
# Optional deterministic directory discovery, bounded by file count and prefix:
zig build -Doptimize=ReleaseFast run-br-context-tree-report -- \
  --dir ~/corpora/silesia --max-files 64 --limit 32768
zig build -Doptimize=ReleaseFast run-br-ratio-stage-profile-gate
zig build -Doptimize=ReleaseFast run-br-planned-chunks-bench-gate
zig build -Doptimize=ReleaseFast run-br-upstream-multiblock-diff
zig build -Doptimize=ReleaseFast run-br-real-corpus-diff
# Optional real-corpus prefixes from neighboring checkouts:
zig build -Doptimize=ReleaseFast run-br-real-corpus-diff -- \
  --extra-file ~/Work/godot/thirdparty/ufbx/ufbx.c \
  --extra-file ~/Work/opencv/data/haarcascades/haarcascade_frontalface_default.xml
zig build -Doptimize=ReleaseFast run-br-progressive-copy-bench-gate
zig build -Doptimize=ReleaseFast run-br-progressive-huffman-bench-gate
zig build -Doptimize=ReleaseFast run-br-incremental-planned-bench-gate
zig build run -- zlib-fixed-roundtrip "hello vort"
zig build run -- gzip-fixed-roundtrip "hello vort"
zig build run -- decode-raw-hex cb48cdc9c90700
zig build run -- decode-raw-hex cb48cdc9c90700 5
zig build run -- inspect-raw-header-hex cb48cdc9c90700
zig build run -- inspect-raw-header-hex cb48cdc9c90700 json
zig build run -- decode-raw-dict-hex cb402701 "hello "
python3 - <<'PY'
import zlib
co = zlib.compressobj(level=6, wbits=-15)
open("/tmp/vort.raw", "wb").write(co.compress(b"hello") + co.flush())
PY
zig build run -- decode-raw-file /tmp/vort.raw /tmp/vort-raw.out 5
printf "hello " > /tmp/vort.dict
printf "cb402701" | xxd -r -p > /tmp/vort-dict.raw
zig build run -- decode-raw-dict-file /tmp/vort-dict.raw /tmp/vort-raw-dict.out /tmp/vort.dict 17
zig build run -- decode-zlib-hex 7801cb48cdc9c90700062c0215
zig build run -- decode-zlib-concat-hex 7801cb48cdc9c90700062c02157801cb48cdc9c90700062c0215
zig build run -- inspect-zlib-header-hex 7801cb48cdc9c90700062c0215
zig build run -- inspect-zlib-header-hex 7801cb48cdc9c90700062c0215 json
zig build run -- inspect-zlib-deflate-header-hex 7801cb48cdc9c90700062c0215 json
zig build run -- inspect-zlib-dict-deflate-header-hex 78f908610235cb4027013a2e067d "hello " json
zig build run -- decode-zlib-dict-hex 78f908610235cb4027013a2e067d "hello "
zig build run -- decode-zlib-dict-concat-hex 78f908610235cb4027013a2e067d78f908610235cb4027013a2e067d "hello "
python3 - <<'PY'
import zlib
open("/tmp/vort.zlib", "wb").write(zlib.compress(b"hello"))
PY
zig build run -- decode-zlib-file /tmp/vort.zlib /tmp/vort-zlib.out 5
cat /tmp/vort.zlib /tmp/vort.zlib > /tmp/vort-cat.zlib
zig build run -- decode-zlib-concat-file /tmp/vort-cat.zlib /tmp/vort-zlib-cat.out 10
zig build run -- inspect-zlib-header-file /tmp/vort.zlib
zig build run -- inspect-zlib-deflate-header-file /tmp/vort.zlib json
printf "hello " > /tmp/vort.dict && python3 - <<'PY'
import zlib
d = b"hello "
p = b"hello hello hello"
co = zlib.compressobj(level=9, wbits=zlib.MAX_WBITS, zdict=d)
open("/tmp/vort-dict.zlib", "wb").write(co.compress(p) + co.flush())
PY
zig build run -- inspect-zlib-dict-deflate-header-file /tmp/vort-dict.zlib /tmp/vort.dict json
zig build run -- decode-zlib-dict-file /tmp/vort-dict.zlib /tmp/vort-dict.out /tmp/vort.dict
zig build run -- decode-zlib-dict-file /tmp/vort-dict.zlib /tmp/vort-dict-limited.out /tmp/vort.dict 17
cat /tmp/vort-dict.zlib /tmp/vort-dict.zlib > /tmp/vort-dict-cat.zlib
zig build run -- decode-zlib-dict-concat-file /tmp/vort-dict-cat.zlib /tmp/vort-dict-cat.out /tmp/vort.dict
zig build run -- encode-raw-dict-best-file /tmp/vort-dict.out /tmp/vort-dict.raw /tmp/vort.dict default
zig build run -- encode-raw-dict-best-split-file /tmp/vort-dict.out /tmp/vort-dict-split.raw /tmp/vort.dict 7 default
zig build run -- encode-raw-dict-best-adaptive-file /tmp/vort-dict.out /tmp/vort-dict-adaptive.raw /tmp/vort.dict default
zig build run -- encode-zlib-dict-best-file /tmp/vort-dict.out /tmp/vort-dict-encoded.zlib /tmp/vort.dict default
zig build run -- encode-zlib-dict-best-split-file /tmp/vort-dict.out /tmp/vort-dict-split.zlib /tmp/vort.dict 7 default
zig build run -- encode-zlib-dict-best-adaptive-file /tmp/vort-dict.out /tmp/vort-dict-adaptive.zlib /tmp/vort.dict default
zig build run -- decode-gzip-hex 1f8b0800000000000403cb48cdc9c9070086a6103605000000
zig build run -- inspect-gzip-header-hex 1f8b0800000000000403cb48cdc9c9070086a6103605000000
zig build run -- inspect-gzip-header-hex 1f8b0800000000000403cb48cdc9c9070086a6103605000000 json
zig build run -- inspect-gzip-deflate-header-hex 1f8b0800000000000403cb48cdc9c9070086a6103605000000 json
python3 - <<'PY'
import gzip
open("/tmp/vort.gz", "wb").write(gzip.compress(b"hello", mtime=0))
open("/tmp/vort-cat.gz", "wb").write(gzip.compress(b"hello ", mtime=0) + gzip.compress(b"world", mtime=0))
PY
zig build run -- decode-gzip-file /tmp/vort.gz /tmp/vort-gzip.out 5
zig build run -- inspect-gzip-header-file /tmp/vort.gz
zig build run -- inspect-gzip-deflate-header-file /tmp/vort.gz json
zig build run -- inspect-gzip-deflate-header-file /tmp/vort-cat.gz json  # first member
zig build run -- inspect-gzip-deflate-header-file /tmp/vort-cat.gz json 1
zig build run -- decode-gzip-file /tmp/vort-cat.gz /tmp/vort-gzip-cat.out 11
zig build run -- encode-raw-best-file-hex README.md default
zig build run -- encode-zlib-best-file-hex README.md default
zig build run -- encode-gzip-best-file-hex README.md default
zig build run -- encode-raw-best-split-hex "abcdefghijklmnopqrstuvwxyz" 7 fast
zig build run -- encode-raw-dict-best-hex "hello hello hello" "hello " default
zig build run -- encode-zlib-dict-best-hex "hello hello hello" "hello " default
zig build run -- encode-zlib-best-adaptive-hex "abcdefghijklmnopqrstuvwxyz" default
zig build run -- encode-zlib-best-split-hex "abcdefghijklmnopqrstuvwxyz" 7 default
zig build run -- encode-gzip-best-split-hex "abcdefghijklmnopqrstuvwxyz" 7 default
zig build run-fuzz-smoke
zig build run-fuzz-corpus
zig build run-fuzz-corpus -- --deflate 4b0400 4a0400
zig build run-fuzz-corpus -- --deflate --expect=reject 4a0400
zig build run-fuzz-corpus -- --deflate --expect-error=TrailingData 4b040058
zig build run-fuzz-corpus -- --zlib 7801cb48cdc9c90700062c0215 0000 --gzip 1f8b0800000000000403cb48cdc9c9070086a6103605000000 0000
zig build run-fuzz-corpus -- --file corpus/deflate-wrapper-smoke.hex
zig build run-deflate-wrapper-fuzz-corpus
zig build run-deflate-wrapper-fuzz-corpus-dashboard
zig build run-fuzz-corpus-coverage-smoke
zig build run-fuzz-target
zig build run-libfuzzer-smoke
zig build run-afl-smoke
zig build run-checksum-diff
zig build run-checksum-zlib-diff
zig build -Doptimize=ReleaseFast run-checksum-bench-gate
zig build -Doptimize=ReleaseFast run-huffman-length-bench-gate
zig build -Doptimize=ReleaseFast run-deflate-code-length-rle-bench-gate
zig build run-zlib-diff
zig build run-gzip-diff
zig build run-python-zlib-diff
zig build run-python-zlib-diff-dashboard
zig build run-gzip-cli-diff
# gzip concatenated decode has explicit aliases as well:
# decode-gzip-concat-hex / decode-gzip-concat-file
zig build run-native-codec-probes
zig build run-native-codec-probes-dashboard
zig build run-lz4-native-probe
zig build run-lz4-native-dictionary-probe
zig build run-lz4-native-summary-cli-probe
zig build run-lz4-native-summary-dashboard
zig build run -- encode-lznt1-file README.md /tmp/readme.lznt1
zig build run -- decode-lznt1-file /tmp/readme.lznt1 /tmp/readme-lznt1.out 1048576
zig build run -- inspect-lznt1-file /tmp/readme.lznt1 1048576
zig build run-lznt1-diff
zig build run -- encode-xpress-plain-file README.md /tmp/readme.xpress
zig build run -- decode-xpress-plain-file /tmp/readme.xpress /tmp/readme-xpress.out 1048576
zig build run -- inspect-xpress-plain-file /tmp/readme.xpress 1048576
zig build run -- encode-xpress-huffman-file README.md /tmp/readme.xpress-huff
zig build run -- decode-xpress-huffman-file /tmp/readme.xpress-huff /tmp/readme-xpress-huff.out $(wc -c < README.md)
zig build run -- inspect-xpress-huffman-file /tmp/readme.xpress-huff $(wc -c < README.md)
zig build run-xpress-diff
zig build run-native-summary-error-dashboard
zig build run-native-summary-error-negative-smoke
zig build run-lz4-native-probe -- --path README.md --limit 4096
zig build run-lz4-native-probe -- --dir docs --max-files 2 --limit 2048
zig build run -- encode-lz4-native-file README.md /tmp/vort-readme.lz4
zig build run -- summary-lz4-native-file /tmp/vort-readme.lz4
zig build run -- decode-lz4-native-file-to /tmp/vort-readme.lz4 /tmp/vort-readme-lz4.out 1048576
zig build run -- encode-lz4-block-hex 61626361626361626361
zig build run -- summary-lz4-block-hex 336162630300
zig build run -- decode-lz4-block-hex 336162630300 10
zig build run -- encode-lz4-block-prefix-hex 6d6e6f706d6e6f70 6162636465666768696a6b6c6d6e6f70
zig build run -- summary-lz4-block-prefix-hex 040400 6162636465666768696a6b6c6d6e6f70
zig build run -- decode-lz4-block-prefix-hex 040400 6162636465666768696a6b6c6d6e6f70 8
zig build run -- encode-snappy-block-hex 68656c6c6f
zig build run -- decode-snappy-block-hex 051068656c6c6f 5
zig build run -- summary-snappy-block-hex 051068656c6c6f
zig build run -- encode-snappy-block-file README.md /tmp/vort-readme.snappy-block
zig build run -- summary-snappy-block-file /tmp/vort-readme.snappy-block
zig build run -- decode-snappy-block-file-to /tmp/vort-readme.snappy-block /tmp/vort-readme-snappy.out 1048576
zig build run -- encode-snappy-frame-hex 68656c6c6f
zig build run -- decode-snappy-frame-hex ff060000734e6150705901090000bb1f1c1968656c6c6f 5
zig build run -- summary-snappy-frame-hex ff060000734e6150705901090000bb1f1c1968656c6c6f
zig build run -- encode-snappy-frame-file README.md /tmp/vort-readme.sz
zig build run -- summary-snappy-frame-file /tmp/vort-readme.sz
zig build run -- decode-snappy-frame-file-to /tmp/vort-readme.sz /tmp/vort-readme-snappy-frame.out 1048576
zig build run-snappy-block-cli-probe
zig build run-snappy-interop-probe
zig build run-snappy-report-gate
# Snappy encoded-bound, summary, split-input, and exact-size helpers are available from the library APIs:
# snappyEncodedBlockBound / snappySummarizeBlock / snappyDecodedBlockChunksSize / snappyDecodeBlockChunksIntoExactSize and
# snappyEncodedFrameBound / snappySummarizeFrame / snappyDecodedFrameChunksSize / snappyDecodeFrameChunksIntoExactSize.
zig build run -- encode-zstd-native-bytes-hex 68656c6c6f auto true true
zig build run -- encode-zstd-native-file-hex README.md literal_only true true
zig build run -- encode-zstd-native-file README.md /tmp/vort-readme.zst literal_only true true
zig build run -- decode-zstd-native-file-to /tmp/vort-readme.zst /tmp/vort-readme.out 1048576
zig build run -- summary-zstd-native-file /tmp/vort-readme.zst json
zig build run -- size-zstd-native-hex 28b52ffd240529000068656c6c6fa36d9f88 5
zig build run-zstd-native-cli-diff
zig build run-zstd-native-summary-cli-probe
zig build run-zstd-native-probe
zig build run-zstd-native-frame-probe
zig build run-zstd-native-dictionary-probe
zig build run-zstd-native-probe -- --path README.md --limit 4096
zig build run-zstd-native-probe -- --dir docs --max-files 2 --limit 2048
zig build run-header-inspect-smoke
zig build run-header-inspect-dashboard
zig build run-dashboard-category-smoke
zig build run-zlib-family-diff
zig build run-rust-deflate-diff
zig build run-external-probe
zig build run-cpu-features
zig build run-zstd-compare-gate
zig build run-zstd-compare-standard-gate
zig build run-zstd-compare-standard-releasefast-gate
zig build -Doptimize=ReleaseFast run-compat-benchmark
zig build -Doptimize=ReleaseFast run-standard-corpus-report
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --suite
zig build -Doptimize=ReleaseFast run-standard-corpus-suite
zig build -Doptimize=ReleaseFast run-standard-corpus-dashboard
zig build -Doptimize=ReleaseFast run-standard-corpus-full-dashboard
zig build -Doptimize=ReleaseFast run-standard-corpus-full-dashboard -- --paths README.md --limit 1
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --paths ~/Work/zlib-rs/silesia-small.tar
zig build -Doptimize=ReleaseFast run-standard-corpus-report -- --full
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-suite
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-dashboard -- --limit 3
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-full-suite
zig build -Doptimize=ReleaseFast run-standard-multi-corpus-full-dashboard
zig build run-compression-report
zig build run-level-report
zig build run-level-report-csv
zig build run-level-report-dashboard
zig build run-huffman-length-report-dashboard
zig build run-huffman-length-report-dashboard -- --iterations 1000
zig build run-level-report -- README.md docs/roadmap.md
zig build run-dictionary-report
zig build run-native-library-bench
zig build run-native-library-bench -- --iterations 50
zig build run-native-library-bench-csv
zig build run-native-library-bench-gate
zig build run-native-dictionary-report
zig build run-native-dictionary-report -- --path README.md --limit 4096 --dict-len 512
zig build run-native-dictionary-report -- --path README.md --limit 4096 --dict-len 512 --json zig-out/native-dict.json --markdown zig-out/native-dict.md
zig build run-dictionary-report -- README.md docs/roadmap.md
zig build run-dictionary-report -- --target 512 README.md docs/roadmap.md
zig build run-dictionary-deflate-report
zig build run-dictionary-deflate-report -- /tmp/vort.dict /tmp/vort-dict.out
zig build run-dictionary-deflate-report -- --dict /tmp/vort.dict README.md docs/roadmap.md
zig build run-dictionary-deflate-report -- --dict /tmp/vort.dict docs
zig build run-dictionary-deflate-report-csv
zig build run-dictionary-deflate-report-dashboard
zig build -Doptimize=ReleaseFast run-dictionary-corpus-report
zig build -Doptimize=ReleaseFast run-dictionary-corpus-report -- --per-file
zig build -Doptimize=ReleaseFast run-dictionary-corpus-dashboard
zig build -Doptimize=ReleaseFast run-dictionary-corpus-dashboard -- --targets 128,256,512
zig build run-level-report
zig build run-level-report-csv
zig build run-level-report-dashboard
zig build run-huffman-length-report-dashboard
zig build run-huffman-length-report-dashboard -- --iterations 1000
zig build run-dynamic-plan-report
zig build run-dynamic-plan-report-csv
zig build run-split-policy-report
zig build run-split-policy-report -- README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-split-policy-corpus-report
zig build run-native-range-report
zig build run-native-range-report -- README.md docs/roadmap.md
zig build run-native-range-report -- --offset 32 --length 64 README.md
zig build run-native-range-report -- --sweep README.md
zig build -Doptimize=ReleaseFast run-file-corpus-report -- README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- docs
zig build -Doptimize=ReleaseFast run-file-corpus-dashboard -- ~/Work/zlib-rs/silesia-small.tar
zig build -Doptimize=ReleaseFast run-file-corpus-standard-dashboard -- --limit 3
zig build -Doptimize=ReleaseFast run-file-corpus-standard-full-dashboard -- --limit 3
zig build bench-checksum -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseFast run-checksum-bench-gate
zig build -Doptimize=ReleaseFast run-snappy-report-gate
zig build -Doptimize=ReleaseFast run-snappy-reference-bench-gate  # optional runtime libsnappy comparison
zig build -Doptimize=ReleaseFast run-lz4-reference-bench-gate  # optional runtime liblz4 comparison
zig build -Doptimize=ReleaseFast run-zstd-reference-bench-gate  # optional runtime libzstd comparison
zig build -Doptimize=ReleaseFast run-zstd-reference-bench -- --libzstd /path/to/libzstd  # explicit reference library
zig build -Doptimize=ReleaseFast run-zstd-reference-bench -- --input path/to/file --name corpus_case --level 1  # same-frame in-process file decode comparison
zig build -Doptimize=ReleaseFast run-zstd-decode-profile -- --libzstd /path/to/libzstd  # pure-Vort decode shapes from explicit libzstd
zig build -Doptimize=ReleaseFast run-zstd-decode-profile -- --input path/to/file --name corpus_case --level 1  # file-backed match/literal shape profile
zig build -Doptimize=ReleaseFast run-zstd-sequence-decode-stage-bench  # prepared sequence bit/FSE ns per sequence on real source files
zig build -Doptimize=ReleaseFast run-zstd-sequence-decode-stage-bench -- --input path/to/file --name corpus_case --level 1  # file-backed sequence-stage timing
zig build -Doptimize=ReleaseFast run-zstd-interleaved-block-bench -- --input path/to/file --name corpus_case --level 1  # medium-block Huffman/FSE/copy kernel timing
zig build -Doptimize=ReleaseFast run-zstd-encode-bench-gate  # libzstd encode comparison and level-policy gate
zig build -Doptimize=ReleaseFast run-zstd-encode-bench -- --libzstd /path/to/libzstd  # explicit encode reference library
zig build -Doptimize=ReleaseFast run-zstd-native-encode-stage-bench-gate  # match-family timings plus single-beam search histograms
zig build -Doptimize=ReleaseFast run-zstd-level-schedule-bench-gate  # parallel-vs-serial multi-block scheduling
zig build run-zstd-large-sequence-probe  # >512-sequence single/cross-block encode plus Vort/libzstd decode
zig build test-zstd  # focused Zstandard codec suite
zig build test-zstd-far-window  # explicit >8 MiB match boundary
zig build run-zstd-compat-probe  # optional system-libzstd decode matrix
# Build and select the current local upstream reference explicitly:
make -C ~/Work/zstd/lib -j4 libzstd-release
zig build -Doptimize=ReleaseFast run-zstd-compat-probe -- \
  --libzstd ~/Work/zstd/lib/libzstd.so
# Optional deep zstd upstream decodecorpus differential (paired z*.zst / z* files):
zig build -Doptimize=ReleaseFast run-zstd-compat-probe -- \
  --decodecorpus /tmp/zstd-frames /tmp/zstd-plain --decodecorpus-count 1000
# Add --decodecorpus-dictionary /tmp/zstd-frames/dictionary for dictionary corpora.
# Reproduce the complete nine-campaign/9,900-frame suite and clean each temporary corpus:
zig build -Doptimize=ReleaseFast run-zstd-decodecorpus-gate -j1
# The same corpus can use an explicitly selected upstream shared library:
zig build -Doptimize=ReleaseFast run-zstd-decodecorpus-gate -j1 -- \
  --libzstd ~/Work/zstd/lib/libzstd.so
# Override discovery with -- --decodecorpus /path/to/zstd/tests/decodecorpus.
zig build bench-deflate-decode -Doptimize=ReleaseFast
zig build bench-deflate-incremental-encode -Doptimize=ReleaseFast -- 8
zig build run-deflate-incremental-encode-gate
zig build bench-deflate-incremental-decode -- 2000
zig build run-deflate-incremental-decode-gate
# Optional direct zlib-ng compat-library comparison:
zig build bench-deflate-incremental-encode -Doptimize=ReleaseFast \
  -Dzlib-ng-root=$HOME/Work/zlib-ng -- 8
zig build -Dzlib-ng-root=$HOME/Work/zlib-ng run-deflate-incremental-encode-gate
zig build -Dzlib-ng-root=$HOME/Work/zlib-ng bench-deflate-incremental-decode -- 2000
zig build -Dzlib-ng-root=$HOME/Work/zlib-ng run-deflate-incremental-decode-gate
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report -- --iterations 1000
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report-csv
zig build -Doptimize=ReleaseFast run-deflate-decode-stage-report-dashboard  # writes CSV/Markdown/JSON decode-stage artifacts
zig build run-zlib-relaxed-report-gate
zig build bench-corpus-decode -Doptimize=ReleaseFast
zig build bench-deflate-encode -Doptimize=ReleaseFast
zig build -Doptimize=ReleaseFast run-rust-deflate-bench
zig build -Doptimize=ReleaseFast run-rust-deflate-bench-csv
zig build -Doptimize=ReleaseFast run-rust-deflate-encode-bench
zig build -Doptimize=ReleaseFast run-rust-deflate-encode-bench-csv
zig build -Doptimize=ReleaseFast run-rust-deflate-benchmark-summary
zig build bench-native-parallel -Doptimize=ReleaseFast
zig build bench-native-parallel -Doptimize=ReleaseFast -- README.md 4096 2
zig build -Doptimize=ReleaseFast run-native-parallel-corpus-report
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard -- --workers 2 --block-len 4096 --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-native-parallel-dashboard -- --worker-sweep 1,2,4 --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-native-parallel-full-dashboard
zig build -Doptimize=ReleaseFast run-native-parallel-full-dashboard -- --workers 2 --paths README.md docs/roadmap.md
zig build -Doptimize=ReleaseFast run-native-parallel-multi-corpus-dashboard -- --limit 3
zig build -Doptimize=ReleaseFast run-native-parallel-multi-corpus-full-dashboard
zig build -Doptimize=ReleaseFast run-native-thread-pool-full-dashboard
zig build -Doptimize=ReleaseFast run-native-parallel-multi-corpus-full-dashboard -- --workers 2 --paths README.md docs/roadmap.md
```

## Current API sketch

```zig
const vort = @import("vort");

const adler = vort.adler32("payload");
const crc = vort.crc32("payload");
const encoded = try vort.storeEncodeAlloc(allocator, "payload");
defer allocator.free(encoded);
const decoded = try vort.storeDecodeAlloc(allocator, encoded);
defer allocator.free(decoded);

const raw = try vort.encodeRawFixedDeflateAlloc(allocator, "payload");
defer allocator.free(raw);
const raw_level_6 = try vort.encodeRawLevelAlloc(allocator, "payload", 6);
defer allocator.free(raw_level_6);
const raw_exact = try vort.decodeRawDeflateAllocExactSize(allocator, raw, "payload".len);
defer allocator.free(raw_exact);
const bounded = try vort.decodeRawDeflateAllocLimited(allocator, raw, 1024);
defer allocator.free(bounded);
const raw_chunks = [_][]const u8{ raw[0..1], raw[1..] };
var raw_join_scratch: [1024]u8 = undefined;
var raw_out: [1024]u8 = undefined;
const raw_chunk_header = try vort.parseRawDeflateHeaderInfoFromChunks(&raw_chunks, &raw_join_scratch);
_ = raw_chunk_header.block_type;
const raw_chunked = try vort.decodeRawDeflateChunks(&raw_chunks, &raw_join_scratch, &raw_out);
_ = raw_chunked;

// Native LZ4 APIs are available as alloc, append, caller-owned slice, and
// reusable scratch forms. Linked block mode can improve ratio when chunks share
// the previous 64 KiB of history.
const lz4_options: vort.Lz4NativeFrameOptions = .{ .block_mode = .linked };
var lz4_encoder = try vort.Lz4NativeFrameEncoder.init(allocator);
defer lz4_encoder.deinit();
const lz4_frame = try lz4_encoder.encodeScratch("payload payload", lz4_options);
const lz4_header = try vort.lz4InspectNativeFrameHeader(lz4_frame);
_ = lz4_header.block_independent;
const lz4_first_block = try vort.lz4InspectNativeFrameFirstBlock(lz4_frame);
_ = lz4_first_block;
_ = try vort.lz4InspectNativeFrameBlockAt(lz4_frame, lz4_first_block.?.header_offset);
const lz4_blocks = try vort.lz4SummarizeNativeFrameBlocks(lz4_frame);
_ = lz4_blocks.block_count;
const lz4_stream = try vort.lz4SummarizeNativeStream(lz4_frame);
_ = lz4_stream.frame_count;
const lz4_native_size = try vort.lz4DecodedNativeFrameSize(lz4_frame);
_ = try vort.lz4DecodedNativeFrameSizeLimited(lz4_frame, lz4_native_size);
const lz4_frame_chunks = [_][]const u8{ lz4_frame[0..4], lz4_frame[4..] };
var lz4_join_scratch: [1024]u8 = undefined;
_ = try vort.lz4DecodedNativeFrameChunksSize(&lz4_frame_chunks, &lz4_join_scratch);
var lz4_chunk_appended: std.ArrayList(u8) = .empty;
defer lz4_chunk_appended.deinit(allocator);
try lz4_chunk_appended.appendSlice(allocator, "prefix:");
_ = try vort.lz4DecodeNativeFrameChunksAppend(
    allocator,
    &lz4_chunk_appended,
    &lz4_frame_chunks,
    &lz4_join_scratch,
);
_ = try vort.lz4DecodeNativeFrameChunksAppendExactSize(
    allocator,
    &lz4_chunk_appended,
    &lz4_frame_chunks,
    &lz4_join_scratch,
    lz4_native_size,
);
var lz4_block_iter = try vort.lz4IterateNativeFrameBlocks(lz4_frame);
while (try lz4_block_iter.next()) |block| {
    _ = block.payload_len;
}
const lz4_skip = try vort.lz4EncodeSkippableFrameAlloc(allocator, 0, "metadata");
defer allocator.free(lz4_skip);
_ = try vort.lz4InspectNativeSkippableFrame(lz4_skip);
var lz4_stream_iter = vort.lz4IterateNativeStream(lz4_skip);
while (try lz4_stream_iter.next()) |element| switch (element) {
    .frame => |frame| _ = frame.header.block_size_max,
    .skippable => |skippable| _ = skippable.payload,
};
var lz4_decoder = vort.Lz4NativeFrameDecoder.init(allocator);
defer lz4_decoder.deinit();
const lz4_plain = try lz4_decoder.decodeScratch(lz4_frame);
_ = lz4_plain;
_ = try lz4_decoder.decodedChunksSize(&lz4_frame_chunks, &lz4_join_scratch);
const lz4_chunk_plain = try lz4_decoder.decodeChunksScratch(&lz4_frame_chunks, &lz4_join_scratch);
_ = lz4_chunk_plain;
var lz4_reusable_chunk_appended: std.ArrayList(u8) = .empty;
defer lz4_reusable_chunk_appended.deinit(allocator);
try lz4_reusable_chunk_appended.appendSlice(allocator, "prefix:");
_ = try lz4_decoder.decodeChunksAppendExactSize(
    &lz4_reusable_chunk_appended,
    &lz4_frame_chunks,
    &lz4_join_scratch,
    lz4_native_size,
);
var lz4_incremental = vort.Lz4NativeIncrementalFrameDecoder.init(allocator);
defer lz4_incremental.deinit();
var lz4_incremental_out: ["payload payload".len]u8 = undefined;
_ = try lz4_incremental.step(lz4_frame[0..4], lz4_incremental_out[0..0]);
_ = try lz4_incremental.step(lz4_frame[4..], &lz4_incremental_out);
// The same incremental decoder can continue through concatenated native
// streams and LZ4 skippable metadata frames; feed more bytes after `.done` to
// decode the next stream member without resetting cumulative diagnostics.
var lz4_bounded_incremental = vort.Lz4NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
    .max_compressed_buffer_len = 1 << 20,
    .max_decoded_buffer_len = 1 << 20,
    .expected_output_len = "payload payload".len,
});
defer lz4_bounded_incremental.deinit();
// Skippable frames retain only their 8-byte header; their metadata payload can
// exceed max_compressed_buffer_len and is discarded or copied into caller-owned
// skippable_output incrementally. Oversized data frames switch to block-bounded
// input. Compressed LZ4 blocks without block checksums can stream under a
// header-sized cap; checksummed blocks require the cap to hold one encoded
// block so checksum failure is reported before caller output is exposed.
// After feeding/draining the final frame, call finish() to validate exact-size EOF.
const lz4_dict = vort.Lz4NativeDictionary.init(0x1234, "previous lz4 history");
const lz4_dict_options: vort.Lz4NativeFrameOptions = .{ .content_checksum = false };
const lz4_dict_bound = try vort.lz4EncodedNativeFrameBoundWithDictionary(
    "previous lz4 history payload".len,
    lz4_dict_options,
    lz4_dict,
);
_ = lz4_dict_bound;
const lz4_dict_frame = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(
    allocator,
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict,
);
defer allocator.free(lz4_dict_frame);
const lz4_dict_plain = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, lz4_dict_frame, lz4_dict);
defer allocator.free(lz4_dict_plain);
const lz4_dicts = [_]vort.Lz4NativeDictionary{lz4_dict};
const lz4_dict_set = vort.Lz4NativeDictionarySet.init(&lz4_dicts);
const lz4_dict_set_bound = try vort.lz4EncodedNativeFrameBoundWithDictionarySet(
    "previous lz4 history payload".len,
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
);
_ = lz4_dict_set_bound;
const lz4_dict_set_frame = try vort.lz4EncodeNativeFrameWithDictionarySetAlloc(
    allocator,
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
);
defer allocator.free(lz4_dict_set_frame);
var lz4_dict_set_append: std.ArrayList(u8) = .empty;
defer lz4_dict_set_append.deinit(allocator);
try vort.lz4EncodeNativeFrameAppendWithDictionarySet(
    allocator,
    &lz4_dict_set_append,
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
);
const lz4_dict_set_into = try allocator.alloc(u8, lz4_dict_set_bound);
defer allocator.free(lz4_dict_set_into);
_ = try vort.lz4EncodeNativeFrameIntoSliceWithDictionarySet(
    allocator,
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
    lz4_dict_set_into,
);
const lz4_reusable_dict_set_frame = try lz4_encoder.encodeScratchWithDictionarySet(
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
);
_ = lz4_reusable_dict_set_frame;
const lz4_reusable_dict_set_owned = try lz4_encoder.encodeWithDictionarySetAlloc(
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
);
defer allocator.free(lz4_reusable_dict_set_owned);
_ = try lz4_encoder.encodeIntoSliceWithDictionarySet(
    "previous lz4 history payload",
    lz4_dict_options,
    lz4_dict_set,
    lz4_dict.id,
    lz4_dict_set_into,
);
const lz4_stream_plain = try vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySet(
    allocator,
    lz4_dict_frame,
    lz4_dict_set,
);
defer allocator.free(lz4_stream_plain);
const lz4_stream_exact = try vort.lz4DecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(
    allocator,
    lz4_dict_frame,
    lz4_dict_set,
    lz4_stream_plain.len,
);
defer allocator.free(lz4_stream_exact);
const lz4_chunks = [_][]const u8{ lz4_dict_frame[0..8], lz4_dict_frame[8..] };
const lz4_join = try allocator.alloc(u8, lz4_dict_frame.len);
defer allocator.free(lz4_join);
var lz4_chunk_out: ["previous lz4 history payload".len]u8 = undefined;
_ = try vort.lz4DecodeNativeFrameChunksIntoWithDictionarySet(
    &lz4_chunks,
    lz4_join,
    &lz4_chunk_out,
    lz4_dict_set,
);

var lz4_block_encoder = try vort.Lz4BlockEncoder.init(allocator);
defer lz4_block_encoder.deinit();
_ = vort.lz4NativeMaxChainDepth; // public upper bound for NativeFrameOptions.chain_depth.
const lz4_block_once = try vort.lz4EncodeBlockWithChainDepthAlloc(allocator, "payload", lz4_dict_options.chain_depth);
defer allocator.free(lz4_block_once);
const lz4_block = try lz4_block_encoder.encodeWithPrefixScratch("payload", "previous payload history");
_ = try lz4_block_encoder.encodeWithPrefixScratchAndChainDepth("payload", "previous payload history", lz4_dict_options.chain_depth);
var lz4_block_decoder = vort.Lz4BlockDecoder.init(allocator);
defer lz4_block_decoder.deinit();
const lz4_block_plain = try lz4_block_decoder.decodeWithPrefixScratch(lz4_block, "payload".len, "previous payload history");
_ = lz4_block_plain;

// Native-subset Zstd APIs expose the same alloc/append/into/scratch style plus
// mode reporting. The block size and match-search budget options let callers
// trade ratio, encode latency, and seekability without going through the CLI.
const zstd_options: vort.ZstdNativeFrameOptions = .{
    .selection = .auto,
    .block_size_max = 32 * 1024,
    // null preserves the legacy wire; 10...41 selects an explicit window.
    // Known content no larger than that window still uses a single segment.
    .window_log = 10,
    // 0 disables mixed dictionary/duplicate/repeated lookahead; values up to
    // the default keep more ratio-seeking branches at higher planning cost.
    // Dictionary-only matches remain available even when the budget is 0.
    .match_search_budget = vort.zstdNativeMaxMatchSearchBudget,
};
var zstd_encoder = vort.ZstdNativeFrameEncoder.init(allocator);
defer zstd_encoder.deinit();
const zstd_result = try zstd_encoder.encodeScratch("payload payload", zstd_options);
_ = zstd_result.mode;
const zstd_header = try vort.zstdInspectNativeFrameHeader(zstd_result.frame);
_ = zstd_header.content_size;
const zstd_first_block = try vort.zstdInspectNativeFrameFirstBlock(zstd_result.frame);
_ = zstd_first_block.block_type;
_ = try vort.zstdInspectNativeFrameBlockAt(zstd_result.frame, zstd_first_block.header_offset);
if (zstd_first_block.block_type == .compressed) {
    const modes = try vort.zstdInspectNativeFrameBlockSequenceModes(zstd_result.frame, zstd_first_block);
    _ = modes.literal_length_mode;
}
const zstd_blocks = try vort.zstdSummarizeNativeFrameBlocks(zstd_result.frame);
_ = zstd_blocks.block_count;
const zstd_stream = try vort.zstdSummarizeNativeStream(zstd_result.frame);
_ = zstd_stream.frame_count;
var zstd_block_iter = try vort.zstdIterateNativeFrameBlocks(zstd_result.frame);
while (try zstd_block_iter.next()) |block| {
    _ = block.block_type;
}
const zstd_skip = try vort.zstdEncodeSkippableFrameAlloc(allocator, 0, "metadata");
defer allocator.free(zstd_skip);
_ = try vort.zstdInspectNativeSkippableFrame(zstd_skip);
var zstd_stream_iter = vort.zstdIterateNativeStream(zstd_result.frame);
while (try zstd_stream_iter.next()) |element| switch (element) {
    .frame => |frame| _ = frame.header.block_size_max,
    .skippable => |skippable| _ = skippable.payload,
};
var zstd_decoder = vort.ZstdNativeFrameDecoder.init(allocator);
defer zstd_decoder.deinit();
const zstd_plain = try zstd_decoder.decodeScratch(zstd_result.frame);
_ = zstd_plain;
var zstd_incremental = vort.ZstdNativeIncrementalFrameDecoder.init(allocator);
defer zstd_incremental.deinit();
var zstd_incremental_out: ["payload payload".len]u8 = undefined;
_ = try zstd_incremental.step(zstd_result.frame[0..4], zstd_incremental_out[0..0]);
_ = try zstd_incremental.step(zstd_result.frame[4..], &zstd_incremental_out);
// Zstd native incremental decode likewise walks concatenated frames and
// skippable metadata frames through the same caller-owned StepResult API.
var zstd_bounded_incremental = vort.ZstdNativeIncrementalFrameDecoder.initWithOptions(allocator, .{
    .max_compressed_buffer_len = 1 << 20,
    .max_decoded_buffer_len = 1 << 20,
    .expected_output_len = "payload payload".len,
});
defer zstd_bounded_incremental.deinit();
// If a data frame exceeds max_compressed_buffer_len, Vort releases input one
// block at a time. isBlockStreaming() exposes that path and
// compressedBufferedBytes()/compressedBufferCapacity() report logical and
// allocated encoded-input storage; both stay within a finite configured cap.
// Sequence-bearing blocks retain their FSE/Huffman cursors and pending
// literal/match progress across calls without allocating decoded-block scratch,
// including when a prevalidated direct frame meets a tiny output slice;
// streamedSequenceBlockCount() reports path coverage.
// Skippable frames retain only their 8-byte header; metadata payloads are
// discarded or copied into caller-owned skippable_output storage incrementally.
// After feeding/draining the final frame, call finish() to validate exact-size EOF.
// Brotli's general incremental decoder owns its bounded history ring and emits
// stored/compressed bytes as symbols become available. It can pledge
// expected_compressed_len (or use initExactCompressedSize) for a transport
// boundary; max_history_len bounds owned LZ77 history. The wrapper parses at
// most two window-header bytes first, then allocates no more than the declared
// window (and often only expected_output_len), rather than a fixed maximum.
// Both it and the caller-history BrotliIncrementalCopyStreamDecoder use an
// embedded 16 KiB compressed-header buffer. The owned facade grows reusable
// header storage geometrically on demand up to max_compressed_header_len
// (default 1 MiB); exceeding the bound reports OutputLimitExceeded. Supplying
// Options.compressed_header_scratch avoids that allocation. The caller-history
// decoder remains allocation-free and therefore requires explicit scratch for
// an unusually large legal entropy header.
// Non-RFC Large Window streams remain rejected by default. Opt in explicitly
// on one-shot/chunked APIs with BrotliDecodeOptions, or on either general
// incremental decoder through Options.decode.
const br_large_window = vort.BrotliDecodeOptions{ .allow_large_window = true };
_ = try vort.brDecodeStreamIntoWithOptions(encoded_large_window, output, br_large_window);
const zstd_dict = vort.ZstdNativeDictionary.init(0x1234, "previous zstd history shared phrase");
var zstd_incremental_encoder = try vort.ZstdNativeIncrementalFrameEncoder.initWithPresetDictionary(allocator, .{
    .include_content_size = false,
    .selection = .literal_only,
    .dictionary_id = zstd_dict.id,
}, zstd_dict);
defer zstd_incremental_encoder.deinit();
// Feed split input with step(), call finish(), then drain until StepResult.done.
// The dictionary bytes are borrowed and may be referenced by emitted sequences;
// completed blocks also seed a bounded indexed rolling window for multiple later
// block matches without retaining the complete input stream.
// Call flush(), then step with empty input until need_input, to publish a
// non-final block before continuing the same frame. Repeated empty flushes are
// idempotent.
// LZ4 and framed Snappy incremental encoders expose the same resumable flush
// acknowledgement contract, as does the Brotli stored-stream encoder.
// RawDeflateIncrementalStoredEncoder provides the same split-input/tiny-output
// contract for RFC 1951 stored blocks, including pledged input size and flush.
// RawDeflateIncrementalFixedEncoder adds fixed-Huffman compression, a rolling
// 32 KiB history, and zlib-compatible empty stored sync-flush boundaries.
// blockFlush() publishes accepted input by ending the current non-final block,
// matching zlib Z_BLOCK without an empty sync marker. Fixed/best streams do not
// byte-align this boundary; stored blocks retain their inherent RFC alignment
// but add no separate marker. Match history and any wrapper Adler-32 or
// CRC-32/ISIZE state remain continuous. Raw fixed/best and wrapper snapshots
// expose pending_bits so callers can diagnose the live partial output byte.
// partialFlush() follows the published data with zlib's ten-bit empty fixed
// block. It deliberately stays non-byte-aligned but emits enough bits for a
// decoder to consume every accepted byte. Repeated requests are idempotent and
// history/checksums remain continuous. Pending flush requests upgrade in
// block < partial < sync < full order without duplicate boundaries, and
// finish() honors a boundary requested before finalization.
// Its fullFlush() method emits the same byte boundary and then drops retained
// history, rolling match indexes, and any preset dictionary for the remainder
// of the stream, matching Z_FULL_FLUSH. The best and zlib/gzip wrappers expose
// the same method; the stored encoder exposes the equivalent history-free
// non-final boundary. Wrapper Adler-32/CRC-32/ISIZE state remains continuous.
// ZlibIncrementalFixedEncoder adds CMF/FLG, optional preset DICTID, streaming
// Adler-32 and the footer while preserving the raw core's flush semantics.
// GzipIncrementalFixedEncoder adds optional RFC 1952 metadata/FHCRC plus
// streaming CRC-32 and ISIZE with the same split-input and sync-flush contract.
// RawDeflateSyncScanner finds full-flush LEN/NLEN markers across arbitrary
// caller chunks. findRawDeflateSyncPoint plus decodeRawDeflateAfterSync*, or
// RawDeflateIncrementalFixedLiteralDecoder.resumeAfterSync(), recover the raw
// independent suffix. Wrapped zlib/gzip checksums cannot be reconstructed after
// discarded corrupt output, so this recovery surface is intentionally raw.
// RawDeflateIncrementalBestEncoder evaluates stored, fixed, and dynamic Huffman
// representations per block while retaining the same rolling history core.
// Hash and lazy-parser levels additionally retain a bounded 32 KiB predecessor
// ring and epoch-tagged hash heads across blocks; reset reuses them in O(1).
// ZlibIncrementalBestEncoder and GzipIncrementalBestEncoder expose that selector
// through wrapper checksums/metadata; optionsForZlibLevel maps levels 1...9,
// while DeflateParams supplies the complete runtime level 0...9 domain.
// Their requestParams() method accepts DeflateParams levels 0...9 and
// default/filtered/huffman_only/rle/fixed strategies. Level 0 emits genuinely
// stored-only blocks; fixed permits stored/fixed selection but never dynamic.
// Request the initial pair before supplying data to apply it without output.
// A level change within the current stored/fast/slow algorithm family takes
// effect immediately when the strategy is unchanged, without cutting the
// buffered block. A family or strategy change is asynchronous: step("", out)
// first publishes already accepted input as one non-final, non-byte-aligned
// block with no sync marker, then commits the newest request. Do not offer more
// input until that drain acknowledges need_input.
// Repeating the same request is idempotent; newer queued requests replace older
// ones, and requesting the active pair cancels a queued change. Snapshots expose
// active_params, requested_params, params_boundary_pending,
// params_change_count, stored_only, and the combined flushing state. reset()
// preserves the active pair, clears a queued request and counters, and starts a
// fresh stream; resetWithOptions() explicitly returns to raw option control.
// Parameter boundaries preserve the 32 KiB history, rolling matcher, preset
// dictionary, and wrapper checksums. Only fullFlush() clears match/dictionary
// history; zlib Adler-32 and gzip CRC-32/ISIZE remain continuous either way.
// run-deflate-params-interop validates all three wrappers in both directions
// against the selected libz; the local run reports runtime zlib 1.2.11. Vort
// params streams inflate in libz, and libz deflateParams streams decode in
// Vort. Its six cases use 3-byte output, issue 84 requests including 24
// same-family requests, observe 45 Vort commits/30 implicit boundaries, and
// retry three Z_BUF_ERROR results without losing parameter or stream state.
// The same gate runs six bidirectional raw/zlib/gzip partial-flush cases under
// 3-byte output and independently decodes each stream across Vort and libz.
// Focused runtime-parameter tests pass 19/19 and the direct Deflate suite
// passes 479/479; the full repository test graph passes 2621/2621.
// Audited libz fixtures pin the exact fixed-Huffman raw/zlib/gzip wire across a
// block flush. Raw inflateSync-style recovery is provided by
// RawDeflateSyncScanner/findRawDeflateSyncPoint and the raw one-shot and
// incremental resume helpers described above.
// Set adaptive_blocks on a best encoder to use CompressionOptions.split_options
// for costed, bounded block-boundary selection instead of one fixed block size.
// Set lookahead_len to retain a bounded suffix and move normal block cuts to a
// complete LZ77 token boundary discovered with next-call prefix bytes.
// Set low_entropy_block_len to a larger bounded cap to amortize dynamic-tree
// headers for byte runs/tiny alphabets while retaining block_len for other data.
// RawDeflateIncrementalStoredDecoder is the caller-to-caller byte-progressive
// decode reference path for RFC 1951 stored blocks and bounded hostile input;
// aligned payload spans copy directly into caller output and the history ring.
// RawDeflateIncrementalFixedLiteralDecoder adds resumable fixed-Huffman bit
// decoding plus caller-owned 32 KiB history for split length/distance matches.
// The same decoder switches between stored, fixed, and dynamic blocks without
// losing bit-reservoir or history state. Fixed/dynamic Huffman symbols use
// bounded prefix lookups, and matches copy in resumable spans rather than one
// byte at a time.
// Dynamic blocks currently progress through HLIT/HDIST/HCLEN and the split
// code-length alphabet/repeats into byte-progressive payload literals and matches.
// ZlibIncrementalDecoder layers split CMF/FLG and streaming Adler/footer
// validation over that raw decoder. The raw core reports the exact compressed
// prefix at EOB, so wrappers can batch input without consuming footer bytes.
// Exact-size caller output can finish the raw match and consume EOB/footer in
// the same step.
// initWithDictionary validates split DICTID and seeds the raw 32 KiB history
// from the caller-owned preset dictionary.
// GzipIncrementalDecoder supports split FEXTRA/FNAME/FCOMMENT/FHCRC plus
// streaming CRC-32/ISIZE and batches raw input up to the exact member footer.
// Set allow_concatenated to continue through RFC 1952 members while enforcing
// max_output_len/expected_output_len cumulatively.
// snapshot() reports the active/last member index and compressed offset; after
// an error it preserves the failing member, phase, and detection offset.
const zstd_dict_options: vort.ZstdNativeFrameOptions = .{ .selection = .literal_only };
const zstd_dict_bound = try vort.zstdEncodedNativeFrameBoundWithDictionary(
    "prefix: previous zstd history payload, shared phrase tail".len,
    zstd_dict_options,
    zstd_dict,
);
_ = zstd_dict_bound;
const zstd_dict_frame = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(
    allocator,
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict,
);
defer allocator.free(zstd_dict_frame.frame);
const zstd_dict_plain = try vort.zstdDecodeNativeFrameAllocWithDictionary(
    allocator,
    zstd_dict_frame.frame,
    zstd_dict,
);
defer allocator.free(zstd_dict_plain);
_ = zstd_dict_plain;
const zstd_dicts = [_]vort.ZstdNativeDictionary{zstd_dict};
const zstd_dict_set = vort.ZstdNativeDictionarySet.init(&zstd_dicts);
const zstd_dict_set_bound = try vort.zstdEncodedNativeFrameBoundWithDictionarySet(
    "prefix: previous zstd history payload, shared phrase tail".len,
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
);
_ = zstd_dict_set_bound;
const zstd_dict_set_frame = try vort.zstdEncodeNativeFrameWithDictionarySetAlloc(
    allocator,
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
);
defer allocator.free(zstd_dict_set_frame.frame);
var zstd_dict_set_append: std.ArrayList(u8) = .empty;
defer zstd_dict_set_append.deinit(allocator);
_ = try vort.zstdEncodeNativeFrameAppendWithDictionarySet(
    allocator,
    &zstd_dict_set_append,
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
);
const zstd_dict_set_into = try allocator.alloc(u8, zstd_dict_set_bound);
defer allocator.free(zstd_dict_set_into);
_ = try vort.zstdEncodeNativeFrameIntoSliceWithDictionarySet(
    allocator,
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
    zstd_dict_set_into,
);
const zstd_reusable_dict_set_frame = try zstd_encoder.encodeScratchWithDictionarySet(
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
);
_ = zstd_reusable_dict_set_frame.mode;
const zstd_reusable_dict_set_owned = try zstd_encoder.encodeWithDictionarySetAlloc(
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
);
defer allocator.free(zstd_reusable_dict_set_owned.frame);
_ = try zstd_encoder.encodeIntoSliceWithDictionarySet(
    "prefix: previous zstd history payload, shared phrase tail",
    zstd_dict_options,
    zstd_dict_set,
    zstd_dict.id,
    zstd_dict_set_into,
);
const zstd_stream_plain = try vort.zstdDecodeNativeConcatenatedFrameAllocWithDictionarySet(
    allocator,
    zstd_dict_frame.frame,
    zstd_dict_set,
);
defer allocator.free(zstd_stream_plain);
const zstd_stream_exact = try vort.zstdDecodeNativeConcatenatedFrameAllocWithDictionarySetExactSize(
    allocator,
    zstd_dict_frame.frame,
    zstd_dict_set,
    zstd_stream_plain.len,
);
defer allocator.free(zstd_stream_exact);
const zstd_chunks = [_][]const u8{ zstd_dict_frame.frame[0..8], zstd_dict_frame.frame[8..] };
const zstd_join = try allocator.alloc(u8, zstd_dict_frame.frame.len);
defer allocator.free(zstd_join);
_ = try vort.zstdDecodedNativeFrameChunksSizeWithDictionarySet(
    &zstd_chunks,
    zstd_join,
    zstd_dict_set,
);
_ = try vort.zstdDecodedRawOrRleFrameChunksSizeWithDictionarySet(
    &zstd_chunks,
    zstd_join,
    zstd_dict_set,
);
_ = try zstd_decoder.decodedChunksSizeWithDictionarySet(&zstd_chunks, zstd_join, zstd_dict_set);
const zstd_chunk_plain = try zstd_decoder.decodeChunksScratchWithDictionarySet(&zstd_chunks, zstd_join, zstd_dict_set);
_ = zstd_chunk_plain;
var zstd_chunk_appended: std.ArrayList(u8) = .empty;
defer zstd_chunk_appended.deinit(allocator);
try zstd_chunk_appended.appendSlice(allocator, "prefix:");
_ = try vort.zstdDecodeNativeFrameChunksAppendWithDictionarySet(
    allocator,
    &zstd_chunk_appended,
    &zstd_chunks,
    zstd_join,
    zstd_dict_set,
);
_ = try vort.zstdDecodeNativeFrameChunksAppendExactSizeWithDictionarySet(
    allocator,
    &zstd_chunk_appended,
    &zstd_chunks,
    zstd_join,
    zstd_dict_set,
    zstd_stream_plain.len,
);
var zstd_chunk_out: ["prefix: previous zstd history payload, shared phrase tail".len]u8 = undefined;
_ = try vort.zstdDecodeNativeFrameChunksIntoWithDictionarySet(
    &zstd_chunks,
    zstd_join,
    &zstd_chunk_out,
    zstd_dict_set,
);
var zstd_reusable_chunk_appended: std.ArrayList(u8) = .empty;
defer zstd_reusable_chunk_appended.deinit(allocator);
try zstd_reusable_chunk_appended.appendSlice(allocator, "prefix:");
_ = try zstd_decoder.decodeChunksAppendExactSizeWithDictionarySet(
    &zstd_reusable_chunk_appended,
    &zstd_chunks,
    zstd_join,
    zstd_dict_set,
    zstd_stream_plain.len,
);

const zlib_bytes = try vort.encodeZlibFixedAlloc(allocator, "payload");
defer allocator.free(zlib_bytes);
const zlib_level_6 = try vort.encodeZlibLevelAlloc(allocator, "payload", 6);
defer allocator.free(zlib_level_6);
const zlib_level_options = try vort.optionsForZlibLevel(6);
_ = zlib_level_options; // numeric zlib levels 1..9; level 0 uses stored helpers
const zlib_header = try vort.parseZlibHeaderInfo(zlib_bytes);
_ = zlib_header.window_bits; // 15 for the default 32 KiB deflate window
const zlib_stream = try vort.inspectZlibStreamAlloc(allocator, zlib_bytes);
_ = zlib_stream.deflate_bytes; // exact raw DEFLATE byte count before Adler-32
_ = zlib_stream.adler32_matches; // diagnostic footer check
const zlib_exact = try vort.decodeZlibAllocExactSize(allocator, zlib_bytes, "payload".len);
defer allocator.free(zlib_exact);
const zlib_bounded = try vort.decodeZlibAllocLimited(allocator, zlib_bytes, 1024);
defer allocator.free(zlib_bounded);
const zlib_relaxed = try vort.decodeZlibAllocWithOptions(
    allocator,
    zlib_bytes,
    .{ .ignore_adler = true, .allow_trailing_data = true },
);
defer allocator.free(zlib_relaxed);
var zlib_out: [1024]u8 = undefined;
const zlib_written = try vort.decodeZlib(zlib_bytes, &zlib_out);
var zlib_decoder = try vort.ZlibDecoder.initWithOptionsExactSize(
    zlib_bytes,
    &zlib_out,
    .{ .ignore_adler = false },
    "payload".len,
);
var zlib_step_out: ["payload".len]u8 = undefined;
_ = try zlib_decoder.step(&zlib_step_out);
const zlib_chunks = [_][]const u8{ zlib_bytes[0..2], zlib_bytes[2..] };
var zlib_inspect_scratch: [1024]u8 = undefined;
const zlib_header_from_chunks = try vort.parseZlibHeaderInfoFromChunks(&zlib_chunks, &zlib_inspect_scratch);
_ = zlib_header_from_chunks.window_bits;
const zlib_chunk_info = try vort.inspectZlibStreamFromChunksAlloc(allocator, &zlib_chunks, &zlib_inspect_scratch);
_ = zlib_chunk_info.deflate_bytes;
const zlib_chunked_written = try vort.decodeZlibChunksInto(&zlib_chunks, &zlib_out);
_ = zlib_chunked_written;
var zlib_join_scratch: [1024]u8 = undefined;
const zlib_chunked_compat_written = try vort.decodeZlibChunks(&zlib_chunks, &zlib_join_scratch, &zlib_out);
_ = zlib_chunked_compat_written;
var zlib_chunked_decoder = try vort.ZlibDecoder.initFromChunksWithOptionsExactSize(
    &zlib_chunks,
    &zlib_join_scratch,
    &zlib_out,
    .{},
    "payload".len,
);
_ = try zlib_chunked_decoder.step(&zlib_step_out);
var zlib_cat: std.ArrayList(u8) = .empty;
defer zlib_cat.deinit(allocator);
try zlib_cat.appendSlice(allocator, zlib_bytes);
try zlib_cat.appendSlice(allocator, zlib_bytes);
const zlib_concatenated = try vort.decodeZlibConcatenatedAlloc(allocator, zlib_cat.items);
defer allocator.free(zlib_concatenated);
const zlib_cat_relaxed = try vort.decodeZlibConcatenatedAllocWithOptions(
    allocator,
    zlib_cat.items,
    .{ .ignore_adler = true, .allow_trailing_data = true },
);
defer allocator.free(zlib_cat_relaxed);
var zlib_cat_decoder = try vort.ZlibDecoder.initConcatenatedWithOptionsExactSize(
    zlib_cat.items,
    &zlib_out,
    .{},
    "payloadpayload".len,
);
var zlib_cat_step_out: ["payloadpayload".len]u8 = undefined;
_ = try zlib_cat_decoder.step(&zlib_cat_step_out);
const zlib_cat_chunks = [_][]const u8{ zlib_cat.items[0..2], zlib_cat.items[2..] };
var zlib_cat_join_scratch: [1024]u8 = undefined;
var zlib_cat_chunk_decoder = try vort.ZlibDecoder.initConcatenatedFromChunksExactSize(
    &zlib_cat_chunks,
    &zlib_cat_join_scratch,
    &zlib_out,
    "payloadpayload".len,
);
_ = try zlib_cat_chunk_decoder.step(&zlib_cat_step_out);
// FDICT concatenated streams can use the dictionary-aware variants:
// const zlib_dict_cat = try vort.decodeZlibConcatenatedAllocWithDictionary(
//     allocator, zlib_dict_bytes, "preset dictionary",
// );
// Dictionary-aware concatenated streams also have WithOptions variants when
// integrations need relaxed per-member Adler or trailing-data behavior.

const gzip_bytes = try vort.encodeGzipFixedAlloc(allocator, "payload");
defer allocator.free(gzip_bytes);
const gzip_level_6 = try vort.encodeGzipLevelAlloc(allocator, "payload", 6);
defer allocator.free(gzip_level_6);
const gzip_with_metadata = try vort.encodeGzipBestWithHeaderAlloc(
    allocator,
    "payload",
    vort.optionsForCompressionLevel(.default),
    .{
        .mtime = 0,
        .filename = "payload.txt",
        .comment = "deterministic Vort gzip stream",
        .header_crc = true,
    },
);
defer allocator.free(gzip_with_metadata);
const gzip_header = try vort.parseGzipHeaderInfo(gzip_with_metadata);
_ = gzip_header.filename; // "payload.txt"; slices alias gzip_with_metadata
const gzip_member = try vort.inspectGzipMemberAlloc(allocator, gzip_bytes, 0);
_ = gzip_member.deflate_bytes; // exact raw DEFLATE byte count for member 0
_ = gzip_member.crc32_matches; // diagnostic trailer check; false does not hide member offsets
const gzip_exact = try vort.decodeGzipAllocExactSize(allocator, gzip_bytes, "payload".len);
defer allocator.free(gzip_exact);
const gzip_cat_exact = try vort.decodeGzipConcatenatedAllocExactSize(allocator, gzip_bytes, "payload".len);
defer allocator.free(gzip_cat_exact);
const gzip_bounded = try vort.decodeGzipConcatenatedAllocLimited(allocator, gzip_bytes, 1024);
defer allocator.free(gzip_bounded);
var gzip_out: [1024]u8 = undefined;
const gzip_written = try vort.decodeGzip(gzip_bytes, &gzip_out);
const gzip_chunks = [_][]const u8{ gzip_bytes[0..4], gzip_bytes[4..] };
var gzip_join_scratch: [1024]u8 = undefined;
const gzip_header_from_chunks = try vort.parseGzipHeaderInfoFromChunks(&gzip_chunks, &gzip_join_scratch);
_ = gzip_header_from_chunks.data_offset;
const gzip_member_from_chunks = try vort.inspectGzipMemberFromChunksAlloc(allocator, &gzip_chunks, &gzip_join_scratch, 0);
_ = gzip_member_from_chunks.deflate_bytes;
const gzip_chunked_written = try vort.decodeGzipChunks(&gzip_chunks, &gzip_join_scratch, &gzip_out);
_ = gzip_chunked_written;
const gzip_chunked_exact = try vort.decodeGzipChunksAllocExactSize(
    allocator,
    &gzip_chunks,
    &gzip_join_scratch,
    "payload".len,
);
defer allocator.free(gzip_chunked_exact);
const gzip_cat_written = try vort.decodeGzipConcatenated(gzip_bytes, &gzip_out);
const gzip_cat_chunks = [_][]const u8{ gzip_bytes[0..4], gzip_bytes[4..] };
const gzip_cat_chunked_written = try vort.decodeGzipConcatenatedChunks(&gzip_cat_chunks, &gzip_join_scratch, &gzip_out);
_ = gzip_cat_chunked_written;

// Limited decode APIs return error.OutputLimitExceeded before allocating or
// appending beyond the caller's declared uncompressed-size budget. Dictionary
// variants are available for raw deflate and zlib streams that need preset
// history. The zlib dictionary encoders emit FDICT/DICTID and the raw/zlib
// planners can emit back-references into the preset history:
// const dict_decoded = try vort.decodeZlibAllocWithDictionaryLimited(
//     allocator,
//     zlib_with_dictionary,
//     dictionary,
//     1024,
// );
// defer allocator.free(dict_decoded);
// const dict_encoded = try vort.encodeZlibBestWithDictionaryAlloc(
//     allocator,
//     "payload",
//     dictionary,
//     vort.optionsForCompressionLevel(.default),
// );
// defer allocator.free(dict_encoded);
```

### ZIP incremental reader, entry decoder, and writer

After parsing an archive and selecting a canonical `ZipEntry`,
`archive.compressedData(entry)` returns its validated borrowed payload.
`ZipIncrementalEntryDecoder` then decodes Stored or raw-Deflate members under
arbitrary input/output fragmentation without consuming bytes after the
declared compressed payload. It enforces the central-directory compressed and
uncompressed sizes, applies `max_output_len`, and validates IEEE CRC-32 before
returning `.done`. Deflate uses a caller-owned 32 KiB history buffer;
`ZipOwnedIncrementalEntryDecoder` supplies an allocator-owned reusable buffer.
Both variants can `reset` across independent Stored and Deflate members, expose
snapshots/streaming diagnostics, and treat a `step` error as terminal until
reset. `finish` distinguishes truncated input when a source ends early.

`ZipIncrementalReader` builds the complete sequential archive state machine on
that data plane. It parses local headers and streams Stored, Shrink, all four
Reduce factors, traditional Implode, Deflate, Deflate64, Bzip2, DCL Implode,
LZMA, XZ, PPMd8, and legacy/current Zstandard payloads.
When `ZipIncrementalReaderOptions.password` is provided, the same codec paths
also stream known-size and descriptor-backed Traditional ZipCrypto entries.
The reader incrementally verifies the 12-byte encrypted header with the CRC-
high or DOS-time-high check byte, subtracts it from known codec pledges, and
advances Vail's cipher only for input the codec actually accepts. Descriptor
scanners receive paired raw/decrypted views, while self-delimiting codecs keep
at most a 24-byte raw tail so their retained descriptor suffix is never
mistaken for ciphertext.
ZIP32/ZIP64 descriptors with
or without the optional signature are accepted; the reader emits `entry_header`
and `entry_done` boundaries and validates every central record,
optional central-directory digital signature, ZIP64 EOCD/locator, legacy EOCD,
entry count, offset, size, CRC, and archive comment before returning `done`.
Stored unsigned descriptors use a bounded 16/24-byte lookbehind and require a
following ZIP record signature plus matching CRC and sizes, so payload copies
of `PK\x07\x08` do not create false boundaries. Deflate uses its final block as
the unambiguous compressed boundary; Deflate64 shares the resumable block
machine with a 64 KiB history, 32 distance symbols and extended code 285;
Bzip2 uses its validated stream terminator and Zstandard its validated frame
end. ZIP method 14 parses its 9-byte
properties prefix and uses the mandatory EOS marker in descriptor mode; XZ
stops after its validated Index/Footer before outer descriptor bytes can be
mistaken for stream padding.
PPMd method 98 parses its two-byte order/memory/restore properties, decodes one
symbol transactionally, and stops exactly at the range-coded EOS.
DCL Implode method 10 retains its partial fixed-Huffman code, LSB-first bit
reservoir, match continuation, and 1/2/4 KiB history until its explicit
length-519 end marker.
Shrink retains its 9...13-bit LSB-first LZW dictionary, partial-clear state,
and pending expanded string across calls. Because method 1 has no end marker,
descriptor entries hold one bounded 16/24-byte candidate window: disproven
bytes enter the decoder one at a time, while a boundary commits only after
zero pad bits, CRC-32, compressed size and output size agree; unsigned
descriptors additionally require a following ZIP record signature.
Reduce methods 2...5 retain their complete 256-context follower tables,
LSB-first reservoir, DLE command state, 512-byte...4 KiB circular history and
overlapping match continuation. Reduce also lacks an EOS marker, and padding
bits can themselves be valid one-bit follower selections. Descriptor mode
therefore withholds the final compressed byte, transactionally decodes it in a
second fixed workspace under the candidate descriptor's exact output size,
and commits the state plus output only after CRC-32 and both sizes match.
Traditional Implode method 6 incrementally parses its byte-aligned run-length
tree descriptions, preserves partial 1...16-bit Shannon–Fano codes, supports
raw or coded literals, and copies matches through a 4/8 KiB circular history.
It shares Reduce's final-byte transactional adapter because it also lacks an
EOS marker: descriptor size and CRC decide exactly which tail output commits.
Arbitrary input/output fragmentation,
zero-output backpressure, reset reuse, SFX `initial_offset`, strict or allowed
trailing data, and explicit entry/total-output, entry-count, metadata, central-
directory, and control-record limits share one API.

The sequential reader retains 32 KiB Deflate and 64 KiB Deflate64 histories,
at most one bounded Bzip2 block, bounded Zstandard frame/block scratch, LZMA
range/dictionary state, at most one bounded XZ block, entry names and compact
validation records, and the configured PPMd model arena until the central
directory. DCL Implode keeps a fixed 4 KiB maximum history and Shrink uses a
fixed 8,192-entry, approximately 40 KiB caller-owned LZW workspace. Reduce
uses two approximately 12 KiB workspaces plus an 8 KiB speculative tail
buffer only while a method-2...5 member is active. Traditional Implode uses
two approximately 10 KiB workspaces plus the same 8 KiB bounded tail. The
reader also retains the final archive comment and one bounded control record,
but never complete decoded payloads, compressed members, or the whole archive.

`ZipIncrementalWriter` streams Stored, Shrink, Reduce, traditional Implode,
DCL Implode, raw-Deflate, stored-block Deflate64, Bzip2, LZMA, XZ, PPMd8, and
legacy/current Zstandard entries into caller-owned output. `ZipIncrementalWriterOptions`
configures archive comment, UTF-8, ZIP64, SFX `initial_offset`, codec policy,
and resource limits;
`ZipIncrementalEntryOptions` supplies the copied name/comment, method, and an
optional exact `expected_size`. Every entry uses bit 3 and a signed data
descriptor. Known and unknown sizes, one-byte output, and zero-output
backpressure share the same `beginEntry` / `step` / `finishEntry` contract;
after the last entry, `finishArchive` drains the retained central metadata and
archive ending.

Stored payload and previously emitted bytes are not retained; Deflate keeps one
bounded planning block/lookahead, its 32 KiB history and match state, and one
encoded pending block. Bzip2 keeps one caller-selected 100...900 KiB RLE/BWT
block plus its bounded encoded pending output. `max_deflate_buffer_size`
defaults to 1 MiB and caps the retained Deflate input portion before an entry
starts; `bzip2_options` independently selects block size and input/pending
limits. Zstandard keeps one configured block, bounded rolling history, and
pending encoded block; `zstd_options` selects block/window/parser/checksum
policy, while content-size signaling is derived from each entry pledge.
LZMA retains its configured dictionary, bounded lookahead/input and pending
range output; the adapter replaces the internal 13-byte Alone header with ZIP's
9-byte properties prefix and always emits the mandatory EOS marker.
XZ retains one configured plaintext block, bounded encoded output and compact
Index records; `xz_options` selects LZMA2 dictionary/parser, check, payload
mode, block limits, and a writer-owned copy of the Delta/BCJ filter chain.
Deflate64 currently uses bounded stored blocks with no whole-member buffering;
the separate one-shot encoder remains available for fixed-Huffman matches and
extended 64 KiB distances.
PPMd8 owns one explicitly bounded 1...256 MiB model arena and small pending
range buffer; `ppmd_options` selects order, restart/cut-off restoration, model
memory, input and pending-output limits, while finish emits the range-coded EOS.
Shrink owns a fixed-capacity 8,192-code LZW dictionary and bounded pending
output; `shrink_options` selects input and pending-output limits. Its
deterministic encoder grows from 9 through 13 bits and freezes a full
dictionary rather than retaining the complete member.
DCL Implode retains its selected 1/2/4 KiB history, a 520-byte match lookahead,
rolling hash chains and at most 16 pending output bytes. Its options select raw
or fixed-Huffman literals, dictionary reach, match-chain depth and an input
limit.
Reduce methods 2...5 share one factor-parameterized encoder with a 512-byte...
4 KiB history, at most 387 bytes of lookahead, DLE matches and a complete
follower table. The default empty table enables a true bounded single pass;
`trainZipReduceFollowerTable` supplies an optional replayable prepass whose
result makes the incremental wire byte-identical to the trained one-shot path.
Traditional Implode retains its selected 4/8 KiB history, at most 323 bytes of
lookahead, fixed Shannon–Fano tree header, rolling matcher and bounded pending
bits. Raw/tree literal modes share the same single-pass core.
Encrypted incremental entries retain only Vail's three-key cipher state and
the 12-byte header; codec bytes are encrypted in place in caller output.
Memory therefore scales with those bounds plus central-directory
metadata, not with the complete archive.
Archive comments are copied by initialization, and names/comments by
`beginEntry`, so those caller slices need not outlive the successful call.

With `.auto`, unknown-size entries and every Shrink/Reduce/Implode/DCL-Implode/Deflate/
Deflate64/Bzip2/LZMA/XZ/PPMd/Zstandard entry conservatively use ZIP64 before its non-seekable local
header is emitted; a known-size Stored entry remains ZIP32 when its size and
local offset fit.
`.always` forces ZIP64.
`.never` rejects known entry overflow up front, while a late unknown entry-size
or codec overflow detected in `step` poisons the writer. After all descriptors
drain, `finishArchive` preflights count, central-directory/ending offsets and
sizes, and the archive-output limit; a failure there leaves the writer ready
and recoverable. `initial_offset` includes an already-written SFX prefix in
every ZIP offset but does not emit that prefix.

`step` errors are deliberately non-transactional because earlier output may
already be committed to an external sink; output from the failing call is
invalid and must not be committed. After an error, mutating calls return
`ZipWriterPoisoned` and the partial archive must be discarded. Direct
validation errors from `beginEntry` and a premature short `finishEntry` remain
recoverable. The existing one-shot `zipEncodeAppend` retains its transactional
guarantee and broader method support. Every compression method currently
supported by the sequential reader now has a bounded incremental writer.
The incremental writer and one-shot surface support per-entry Traditional
ZipCrypto. The sequential reader supports both known-size and descriptor-
backed forms. WinZip AES supports one-shot reading/writing, descriptor-backed
incremental writing, and both known-size and descriptor-backed sequential
reading. PKWARE Strong AES now has the same one-shot/bounded incremental writer
and known-size/descriptor sequential reader coverage. `parseSplitZipArchiveAlloc`
accepts explicitly ordered `.z01` ...
`.zip` disk slices, validates ZIP32/ZIP64 disk-local offsets, the leading split
marker, metadata-inconsistent missing/reordered layouts, part count and total
size, then exposes an owned normalized `ZipArchive`; compressed data and
descriptors are not rewritten. This compatibility surface allocates the
complete joined archive. `ZipSplitNormalizedStream` instead retains borrowed
part payloads plus O(parts + entries) disk bases/metadata patches, and
`ZipSplitIncrementalReader` feeds that view through the existing all-codec,
descriptor, ZipCrypto, WinZip AES, and PKWARE Strong sequential state machine with a bounded
32 KiB bridge buffer. All part payload slices must remain alive, but no second
joined archive is allocated. For non-resident media, `ZipSplitPartSource` plus
`ZipSplitIncrementalReader.initSourceAlloc` copies only part lengths and uses a
short-read callback, allowing the caller to open one volume and release the
previous one on disk switches. `zipEncodeSplitAlloc` adds a deterministic owned
writer for every one-shot method and all three supported encryption families. It
emits the conventional split marker, keeps local headers/descriptors/central
records/endings within one part, and exposes borrowed part slices over one
owned backing allocation. `ZipSplitIncrementalWriter` reuses every incremental
codec/encryption path, retains only the established codec state, central
metadata, one atomic control record and caller-selected current-part storage,
and reports `part_done` before output switches volumes. See
[the ZIP format status](docs/formats/zip.md) for the full state and wire
contract. Writer-specific additive errors are exposed separately as
`ZipIncrementalWriterError`; the established `ZipError` set is unchanged.

The incremental `run-zip-diff` matrix generates the same forty-five-entry
archive, including a known Deflate payload larger than 32 KiB that crosses a real
planning-block boundary, under one-byte and micro-chunk output schedules in
ZIP32 `.never` and ZIP64 `.always` modes. Python raw-wire checks, `zipfile`, and
system Info-ZIP validate their supported members, including known,
unknown-size, and empty Bzip2 method-12 entries with version-needed 4.6.
System `zstd` independently decodes known method-93, unknown-size legacy
method-20, and empty method-93 frames with version-needed 6.3. Python `zipfile`
independently reads known, unknown-size, and empty LZMA method-14 entries and verifies their bit-1
EOS flag plus version-needed 6.3. Python `lzma.FORMAT_XZ` and system `xz`
independently agree on known, unknown-size, and empty XZ method-95 streams.
Python zlib and Info-ZIP independently decode known, unknown-size, and empty
stored-block Deflate64 method-9 members; the fixed 7-Zip reference continues to
cover extended-distance reader semantics.
Known, unknown-size, and empty PPMd method-98 entries use order 12, 1 MiB and
cut-off restoration; Vort's complete sequential reader validates them, while
third-party extraction remains conditional on the unavailable 7z/7zz tool.
Known, unknown-size, and empty Shrink method-1 entries are decoded by Vort's
complete sequential reader and system Info-ZIP; Python validates their raw
method, flags, CRC, sizes, descriptors, version metadata, and ZIP64 fields but
does not provide a method-1 decoder. The ZIP32 and ZIP64 archives are 24,663
and 26,251 bytes respectively. Known, unknown-size, and empty DCL Implode
method-10 entries are decoded by the same Vort sequential path; Python pins
their `{literal-mode=1,dictionary-bits=6}` payload header and all outer ZIP
metadata. With those members the ZIP32 and ZIP64 archives are 25,208 and
26,964 bytes. Known, unknown-size, and empty entries for every Reduce factor
use the bounded single-pass table and pass Vort's sequential reader; Python
pins their zero follower headers plus outer metadata. The final ZIP32 and
ZIP64 archives are 29,787 and 32,215 bytes.
Known, unknown-size, and empty default 8 KiB/tree Implode members pass both
Vort's sequential reader and system Info-ZIP; Python pins flags, fixed tree
headers and outer metadata. The final ZIP32 and ZIP64 archives are 30,453 and
33,049 bytes before the entry-time compatibility fields; the current
`0x5455`/`0x000a` matrix is 30,551 and 33,147 bytes.
The aggregate reports 13/13 ZIP differential steps. The same gate incrementally decodes five
Python-generated Stored/Deflate entries, including non-seekable descriptors
and a forced-ZIP64 local header, with 3-byte input and 5-byte output. A separate
six-entry Python non-seekable archive passes through the complete sequential
reader with the same fragmentation, including Bzip2 method 12 and LZMA method
14 (`incremental_archive_reader_cases=6`). System-zstd frames wrapped as legacy
method 20 and current method 93 also pass the sequential path
(`incremental_archive_zstd_cases=2`), as does an independently generated XZ
method-95 member (`incremental_archive_xz_cases=1`). A fixed 7-Zip Deflate64
payload wrapped as method 9 also passes the required sequential path
(`incremental_archive_deflate64_cases=1`).
A fixed zlib-blast DCL Implode payload wrapped as method 10 passes the required
sequential path (`incremental_archive_dcl_cases=1`).
Both Apache Commons Compress `SHRUNK.ZIP` members pass the required sequential
path (`incremental_archive_shrink_cases=2`).
Four known-size and four descriptor-backed SFX Reduce members cover methods
2...5 through the required CLI path (`incremental_archive_reduce_cases=8`).
Four known-size and four descriptor-backed SFX members cover every traditional
Implode flag mode (`incremental_archive_implode_cases=8`); two Apache Commons
Compress fixtures independently cover the 4 KiB/two-tree and 8 KiB/three-tree
endpoints (`incremental_archive_implode_fixture_cases=2`).
Traditional ZipCrypto has four Vort-to-Python/Info-ZIP Stored/Deflate cases
covering CRC- and descriptor-time check bytes, plus two Info-ZIP-to-Vort cases.
Missing/wrong passwords, encrypted-header corruption, ciphertext corruption,
deterministic caller entropy and allocation failures are required coverage.
The reusable cipher and secure-memory handling come from `../vail/archive_crypto`;
Vort owns only ZIP wire policy and codec composition.
PKWARE Strong Encryption adds six deterministic password-based AES-128/192/256
one-shot cases across known-size and descriptor-backed entries. A locally built
7-Zip 26.04 at source commit `9128b80e3a471108678e2b3ec3c985861c8d7b0f`
independently decrypts all six Stored/Deflate/Bzip2 cases. Reader coverage also
includes APPNOTE's synthesized zero-length-IV form, wrong passwords, corrupt
validation/padding, malformed flags/algorithm metadata, and allocation failure.
The incremental writer adds six deterministic ZIP32/ZIP64 known/unknown/empty
cases (2,115/2,359 bytes) and uses a bounded 256-byte codec bridge plus two AES
blocks; fixed 7-Zip independently decrypts another 6/6. The bounded reader adds
twelve required one-shot/incremental-writer CLI cases plus all-codec
known/descriptor and signed/unsigned ZIP32/ZIP64 coverage. Certificate
recipients, non-AES algorithms and central-directory encryption remain explicit
gaps.
The incremental writer adds six known/unknown/empty ZIP32/ZIP64 cases in
separate deterministic archives (1,695/1,939 bytes), decoded independently by
Python, Vort's one-shot reader, and Info-ZIP.
All four Vort one-shot cases, both independently written Info-ZIP bit-3 cases,
and all six ZIP32/ZIP64 incremental-writer cases pass the sequential CLI reader
with a password (`incremental_reader_zipcrypto_cases=12`).
WinZip AES adds six OpenSSL/Python-verified one-shot cases, six deterministic
ZIP32/ZIP64 incremental-writer cases (1,797/2,041 bytes), and twelve
known-size/descriptor-backed sequential-reader cases. A committed Rust
`zip 8.6.0` archive independently
covers AE-1/AE-2, AES-128/192/256, Stored and Deflate, and Rust also extracts
both Vort writer surfaces.
The required Info-ZIP gate also generates a seven-part `zip -s 64k` archive:
one Deflate payload crosses six volume boundaries, a trailing Stored member
starts on the final disk, both extract through `parseSplitZipArchiveAlloc`, and
a first-two-disk reorder is rejected. Both entries also pass the sparse
sequential surface (`split_zip_parts=7`, `split_zip_cases=2`,
`split_zip_stream_cases=2`, `split_zip_boundaries=6`,
`split_zip_metadata_patches=8`).
The same Info-ZIP set passes `ZipSplitPartSource` extraction while the CLI
retains one physical part at a time; callback switch/release accounting is
required so the gate cannot silently fall back to resident multi-slice input
(`split_zip_source_cases=2`, `split_zip_source_switches=11`).
Vort's split writer independently produces four-part ZIP32 and forced-ZIP64
sets. Python wire parsing checks disk-local offsets and atomic record
boundaries, raw zlib plus CRC-32 independently validate both payloads, and both
Vort reader paths extract every member (`vort_split_writer_cases=8`, three
payload boundaries per mode, sparse patch counts 8/13).
The incremental split writer adds schedule-independent ZIP32/ZIP64 sets under
one-byte and micro output, including known/unknown/empty Stored and Deflate
members. Python independently verifies raw Deflate/CRC, disk-local metadata and
atomic record placement before 24 owned/sparse extraction cases
(`incremental_split_zip32_parts=10`, `incremental_split_zip64_parts=13`).
Focused writer tests pass 73/73; the DCL, Reduce and Legacy Implode encoder
suites pass 4/4 each, and the
incremental entry decoder suite passes
15/15, the DCL Implode, Shrink, Reduce and Legacy Implode incremental decoder
suites each pass 4/4, and the archive reader suite passes 28/28. Shrink covers known/signed/
unsigned-descriptor, empty, ZIP32/ZIP64 and output-limit paths; DCL Implode's
six literal/dictionary modes cover known/descriptor and ZIP32/ZIP64. Reduce
covers all four factors, signed/unsigned descriptors, ZIP32/ZIP64, empty
members and follower-coded padding ambiguity. Traditional Implode covers both
dictionary sizes, raw/tree literals,
signed/unsigned descriptors, ZIP32/ZIP64, arbitrary tree descriptions,
implicit-zero and overlapping matches. PPMd restart/cut-off,
descriptor and ZIP64 paths are required Vort coverage; third-party PPMd remains
unclaimed because this host has no 7z/7zz and Python has no method-98 codec.
The full repository graph passes 2719/2719 and `zig build check` passes 113/113.
The refactored one-shot writer remains byte-identical to HEAD across 14 probe
modes. The current host has no 7z/7zz, so that optional extraction branch is
reported as skipped rather than passed.

### Brotli RAW shared-prefix dictionaries

`BrotliSharedDictionary` describes zero through fifteen ordered RAW prefix
attachments. Non-empty attachments form one logical compound dictionary in
order. An empty attachment contributes no bytes but still occupies one of the
fifteen slots.

Encoding accepts the descriptor through three public option fields:

- `BrotliPlannedEncodeOptions.shared_dictionary` covers one-shot and
  `BrotliPlannedStreamEncoder` reusable frontends, including legacy
  fast/balanced/ratio and every Vort-native q0...q11 preset;
- `BrotliPlannedStreamChunksOptions.shared_dictionary` covers the chunked
  planner together with its `level` or q0...q11 `quality`/`mode` policy and
  optional `block_len` override;
- `BrotliIncrementalPlannedStreamEncoder.Options.stream.shared_dictionary`
  covers the incremental planner across flushes and meta-blocks, including its
  stream-level `level` or `quality`/`mode` selection.

`BrotliPlannedStreamChunksOptions` is now a distinct option type rather than an
alias of `BrotliStoredStreamOptions`, because a RAW dictionary has meaning only
for planned encoding. Callers that previously stored the latter type explicitly
before passing it to a planned chunked API must construct the planned option
value (or copy its `window_bits` and `metadata` fields) instead.

The default empty descriptor does not introduce compound references on
one-shot, reusable, chunked, or incremental paths. Chunked encoding now shares
the incremental core and can therefore improve its former independent-block
wire with bounded cross-block matches. Compound copies participate
in Brotli's recent-distance ring; explicit compound distances update it, while
an implicit rep0 reuses it in place. References to the built-in transformed
static dictionary remain separate and do not update that ring. Across
meta-blocks, a selected compressed candidate commits its actual output position
and recent ring; falling back to stored output rolls back the candidate ring
and advances only the output position.

The compound matcher allocates a fixed 32,768-bucket, four-way address index
after its first non-empty dictionary, about 1 MiB on a 64-bit target. Reusable
and incremental encoders retain this index for later streams; the attachment
bytes themselves are never flattened or owned. For a one-shot or chunked call,
the outer slice and all bytes must remain alive and unchanged for that call.
The same call-scoped rule applies to each reusable encode operation; retaining
and reusing the index for an identical descriptor requires those bytes to stay
unchanged across the calls. Incremental callers keep them valid through
`finish()` and draining; `reset()` reuses the same options, while a completed
stream may replace them through `nextStream`.

Decoding accepts the same descriptor through
`BrotliDecodeOptions.shared_dictionary`. The option is supported by the
one-shot allocating, append, caller-buffer, exact-size, and limited
`brDecodeStream*WithOptions` APIs;
`brDecodedStreamSize*WithOptions`; their chunked counterparts; the allocating,
caller-history, diagnostic, and chunked `brSummarizeStream*WithOptions`
families; and both
`BrotliIncrementalCopyStreamDecoder` and the allocator-owned
`BrotliIncrementalStreamDecoder` through their nested `.decode` option.
Summaries expose `uses_shared_dictionary`, `shared_dictionary_copy_count`, and
`shared_dictionary_bytes`.

The descriptor does not copy or own the outer attachment slice or any attached
bytes. Keep both alive and unchanged for the entire one-shot/chunked/summary
call. For progressive decoding, keep them alive and unchanged from decoder
initialization through completion and through any reset that reuses the same
options; an allocator-owned decoder may replace them only by installing new
options for a completed frame with `nextFrame`.

For example:

```zig
const raw_prefixes = [_][]const u8{ "shared ", "", "prefix" };
const shared_dictionary: vort.BrotliSharedDictionary = .{
    .raw_prefixes = &raw_prefixes,
};
const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(
    allocator,
    input,
    .{ .quality = 8, .shared_dictionary = shared_dictionary },
);
defer allocator.free(encoded);
const decoded = try vort.brDecodeStreamAllocWithOptions(
    allocator,
    encoded,
    .{ .shared_dictionary = shared_dictionary },
);
defer allocator.free(decoded);
const summary = try vort.brSummarizeStreamWithOptions(
    encoded,
    .{ .shared_dictionary = shared_dictionary },
);
_ = summary.shared_dictionary_copy_count;
```

The stable built-in RFC 7932 dictionary is also available through
`brEncodePlannedStreamStaticDictionaryAlloc`. This dedicated, ratio-oriented
surface combines the default canonical index with a lazy 59,904-entry
supplement for omit-first and short-core-plus-suffix shapes, and can emit every
one of the 121 standard transform families. The supplement occupies exactly
370,692 bytes and is never constructed by default q0...q11 presets. Diagnostic
helpers expose its entry and byte counts. The retained exhaustive reference
matcher remains available internally to the reproducible A/B benchmark and its
three-row gate.

`BrotliIncrementalStaticDictionaryStreamEncoder` exposes the same complete
121-family matcher through caller-owned resumable state. It accepts arbitrary
input and output fragmentation, retains command/output capacity across
`nextStream`, supports `flush` and in-stream metadata, and preserves Brotli
output position plus the recent-distance ring across meta-blocks. The default
block size is 65,520 bytes; callers can select any non-zero `block_len` through
the encoder's nested `Options`, up to Brotli's 16 MiB meta-block limit, and can
bound total accepted input with `max_input_len`. Default stream options and one
block of 5...65,520 bytes produce exactly the same wire as
`brEncodePlannedStreamStaticDictionaryAlloc`, including omit-first transforms.

```zig
var encoder = vort.BrotliIncrementalStaticDictionaryStreamEncoder.initWithOptions(
    allocator,
    .{ .block_len = 32 * 1024, .max_input_len = 8 * 1024 * 1024 },
);
defer encoder.deinit();

var encoded: std.ArrayList(u8) = .empty;
defer encoded.deinit(allocator);
var scratch: [256]u8 = undefined;
var input_offset: usize = 0;
while (input_offset < input.len) {
    const result = try encoder.step(input[input_offset..], &scratch);
    input_offset += result.progress.input_read;
    try encoded.appendSlice(allocator, scratch[0..result.progress.output_written]);
}
try encoder.finish();
while (true) {
    const result = try encoder.step("", &scratch);
    try encoded.appendSlice(allocator, scratch[0..result.progress.output_written]);
    if (result.status == .done) break;
}
const output = encoded.items;
```

This dedicated coverage surface emits a complete-planner compressed block even
when that block has no dictionary match; it does not perform the normal
q0...q11 compressed-versus-stored size arbitration. Use the ordinary planned
encoders when automatic size/speed policy is more important than guaranteed
complete-transform search.

One-shot callers can use
`brEncodePlannedStreamStaticDictionaryAppend`/`Into` with the same strict
5...65,520-byte, at-least-one-match contract as the original `Alloc` API.
For multiple blocks, the
`brEncodePlannedStreamStaticDictionaryChunks{Alloc,Append,Into}` family and its
`WithOptions` variants drive the same incremental core. Every non-empty chunk
is a meta-block boundary, empty chunks are ignored, and the final non-empty
chunk is emitted directly as the final block. Options use
`BrotliStaticDictionaryStreamOptions`, the same nested `stream`, `block_len`,
and `max_input_len` layout exposed by the incremental encoder. Append calls are
transactional on error. Into calls encode to internal temporary storage before
checking capacity, so `OutOfMemory` leaves the complete caller buffer
unchanged; callers that require retained scratch should use the reusable facade
below or drive the incremental encoder directly.

`BrotliStaticDictionaryStreamEncoder` is the reusable convenience layer for
callers that want atomic Alloc/Append/Into operations without manually driving
`step`. It retains both the incremental plain/pending/command state and the
complete encoded scratch result across calls. `encodeChunksScratch*` returns a
borrow invalidated by the next call; `encodeChunksInto*` copies only after a
complete successful encode, so undersized output remains unchanged. A warmed
three-meta-block regression succeeds with an allocator configured to fail its
first new allocation, proving that stable repeated shapes reuse all retained
capacity. Options may change between calls because each operation resets the
stream state while keeping capacity.

There is intentionally no guessed compressed-wire multiplier exposed as a
bound: the complete planner writes dynamically constructed Huffman trees, and a
strict general upper bound has not yet been derived. The stateless Into wrappers
therefore retain their internal temporary result for atomicity; use the reusable
encoder when repeated-call allocation behavior matters.

Upstream still marks serialized shared dictionaries as
`BROTLI_EXPERIMENTAL`/`DO NOT USE`; Vort does not claim that unstable wire.
Caller-supplied custom static dictionaries likewise remain unsupported. RAW
support makes no future API or wire-compatibility promise for either form.

The `run-br-compound-dictionary-diff` gate passes in Debug and ReleaseFast
against local libbrotli 1.2.0. It covers libbrotli encode to Vort decode for
0/1/2/15 attachments at q0/q5/q9/q11 (16 cases), plus Vort encode to libbrotli
decode for 16 one-shot, 16 reusable, four fast chunked, and four fast
incremental cases. Four additional runtime regressions cover WBITS=10 window
saturation and cross-block recent reuse, stored rollback followed by compound
copy, incremental metadata/backpressure, and static addressing after a
saturated compound region. A system libbrotli 1.0.9 without the optional shared-
dictionary symbols reports the whole runtime matrix as skipped instead of
silently reducing coverage.

### Brotli planned encoder controls

`BrotliPlannedEncodeOptions.quality` selects a deterministic Vort-native
quality schedule from `0...11`; `mode` selects `.generic`, `.text`, or `.font`.
The quality selector is mutually exclusive with the historical `level`
selector: keep `level` at its default `.fast` when `quality` is present.
Leaving `quality = null` preserves the established bounded one-shot
fast/balanced/ratio policy; streaming paths select their explicit/default
level. Generic and text currently use identical parser, context, and
dictionary policy. Font differs only from q4 onward, when it adds a complete
wire candidate using `NPOSTFIX=1, NDIRECT=12`; it does not replace the common
policy.
For example:

```zig
const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(
    allocator,
    input,
    .{ .quality = 8, .mode = .text },
);
defer allocator.free(encoded);
```

These are Vort policy presets that progressively increase bounded LZ search and
enable existing context, split, distance, and static-dictionary candidates.
They produce standard Brotli streams, but the numbers and modes do not select
libbrotli's internal encoders and do not promise libbrotli-equivalent bytes,
compressed size, memory use, or speed. In particular, specialized q0/q1
fragment encoders, q2/q3 entropy writers, q10/q11 Zopfli/HQ cost refinement,
contextual dictionary encoding and global exact-cost segmentation remain
future work. Inputs beyond the 16 MiB format limit keep one Brotli stream and
apply the selected policy independently to bounded 16/32/64 KiB blocks while
retaining window-bounded LZ77 history and the recent-distance ring. The exact
per-quality and per-mode behavior, input/window bounds, verification scope, and
benchmark command are recorded in
[the Brotli quality preset status](docs/performance/brotli-quality-presets.md).

`BrotliPlannedEncodeOptions.extended_dictionary_probes` lets ratio-mode callers
explicitly spend more CPU looking for RFC 7932 static-dictionary matches in
257-byte through 4 KiB inputs. The default is `0`, so the established automatic
search remains limited to inputs of at most 256 bytes and default wire output
and latency remain unchanged. Values `1...brotliMaxExtendedDictionaryProbes`
(`4096` currently) cap the number of literal positions examined; `64` is a
practical starting point for text-oriented workloads. A candidate replaces the
ordinary LZ/stored result only when its complete Brotli wire is strictly
smaller. In the historical level API, a non-zero budget requires `.ratio`.
Quality presets use the same extended path and their scheduled budget from q7
onward; q0...q6 do not schedule extended probing. Inputs above 4 KiB and
budgets above the maximum return `error.InvalidBlockPlan` under either selector.
The planned encode benchmark accepts `--extended-dictionary-probes N`, so this
opt-in path can be measured with the same built-in and repeatable `--path`
corpora as the default levels.
`BrotliPlannedEncodeOptions.adaptive_command_split` enables a second ratio-only
command-block candidate driven by a deterministic Viterbi assignment. Unlike
the default bounded fixed-grid splitter, it can place boundaries at arbitrary
command positions and reuse tree types in non-cyclic patterns such as
`A-B-A-C-A`. The candidate is retained only when its complete Brotli wire is
strictly smaller; the default remains `false` because the broader search costs
material CPU and has not yet improved the built-in/source corpus. Measure it
with `run-br-planned-encode-bench -- --adaptive-command-split ...`.
`BrotliPlannedEncodeOptions.adaptive_literal_split` enables the matching
ratio-only Viterbi search over the actual emitted literal stream. It supports
arbitrary boundaries, boundaries inside one insert run, non-cyclic type reuse,
and the complete 256 literal type/tree wire range. The production search also
selects one RFC context mode per block type and globally clusters all
`type_count * 64` context histograms into at most 256 shared trees using a
dynamic variable-length context map. Identity-tree and joint candidates both
remain in complete-wire arbitration. The default remains `false`
because current built-in and 128 KiB source/Markdown corpora show no size win.
Measure it with `--adaptive-literal-split` on the planned encode benchmark.
`BrotliPlannedEncodeOptions.adaptive_distance_split` is a nullable ratio-mode
override for the corresponding distance-symbol search. The default `null`
automatically evaluates inputs of at least 64 KiB whose derived stream has
2,048--32,768 explicit distance symbols; `false` disables the search and
`true` forces the same bounded symbol policy on smaller inputs. Its dynamic block/tree
writer supports arbitrary boundaries, non-cyclic type reuse, and the complete
256-type Brotli range. Complete-wire arbitration keeps the automatic result
size-monotonic. The benchmark accepts `--adaptive-distance-split` and
`--no-adaptive-distance-split` for explicit A/B runs.
`BrotliPlannedEncodeOptions.distance_parameter_search` controls the ratio
encoder's complete 64-shape RFC `NPOSTFIX/NDIRECT` search. The default `null`
enables it automatically for the stable record-optimal parser family, where
current evidence shows a material size win; `false` disables it and `true`
also enables it for the general bounded optimal proposal. A score-only pass
examines all legal shapes, at most one alternative complete wire is emitted,
and final byte length must strictly beat the historical `(0, 0)` candidate.
The planned benchmark exposes matching `--distance-parameter-search` and
`--no-distance-parameter-search` switches.
`brProfilePlannedRatioBlockAlloc` is the explicit diagnostic counterpart for
default-window 4--32 KiB ratio blocks. It reproduces the production wire while
reporting lazy/optimal plan, command, wire, and selection timings plus optimal
chain/search counters, first-prefix-mismatch buckets, and lower-bound
length/distance-cost/slack plus length-extension histograms;
normal encode entrypoints do not enable those counters.
`run-br-ratio-stage-profile-gate` writes and validates the corresponding
three-size source profile at `zig-out/vort-br-ratio-stage-profile.csv`, including
input/output hashes, stage/count identities, and independent libbrotli decode.

### Native LZ4/Zstd library knobs

The native LZ4/Zstd APIs are library-first.  CLI commands and probes call the
same public symbols shown above; applications should use the allocator/append,
caller-owned slice, reusable scratch, chunked, and incremental decoder APIs
directly.
Zstd native encoded-bound helpers account for the same header form and shortest
legal `Frame_Content_Size` width used by the writer. With an explicit window,
known content no larger than the window retains the compact single-segment
form; larger known content emits a non-single-segment `Window_Descriptor` plus
a two-, four-, or eight-byte content size, while unknown-size output emits the
selected descriptor without a content size.

| Codec | Option / symbol | Default / range | Use when | Tradeoff |
| --- | --- | --- | --- | --- |
| LZ4 native | `Lz4NativeFrameOptions.block_mode` | `.independent` or `.linked` | Consecutive frame blocks share recent history and ratio matters. | `.linked` can improve ratio across block boundaries; `.independent` is simpler for random block handling. |
| LZ4 native | `Lz4NativeFrameOptions.block_size_id` | `.max4mb`; `.max64kb` / `.max256kb` / `.max1mb` / `.max4mb` | You need a latency/working-set knob for frame block size. | Smaller blocks can reduce latency and direct-output burst size; larger blocks usually reduce framing overhead. |
| LZ4 native | `Lz4NativeFrameOptions.chain_depth` | `vort.lz4NativeMaxChainDepth` (`16` currently); `0...vort.lz4NativeMaxChainDepth` | You want to trade encode CPU for deeper hash-chain match search. | `0` disables match search and is fastest/least compact; the default enables the deeper parser used by the native bench ratio rows. |
| LZ4 native | `content_checksum` / `block_checksum` | content checksum on by default; block checksum off by default | You need frame or block corruption detection in the native frame itself. | Checksums add bytes and CPU but give earlier corruption reports. |
| LZ4 native | `Lz4NativeDictionary` | caller-owned bytes plus non-zero `id` | Payloads share a known prefix/history. | Encoder can emit dictionary references; decoder must be given the matching dictionary or dictionary set. |
| LZ4 native | `Lz4OwnedNativeDictionary.metadata()` / `Lz4NativeDictionary.initFromMetadata` / `encodeDictionaryMetadata*` / `decodeDictionaryMetadata*` / `*DictionaryMetadataCatalog*` | shared `DictionaryMetadata` plus 64 KiB history window; single records are 32 bytes and catalogs are versioned counted records with strict and prefix decoders | You want to persist trained dictionary catalog metadata from the same object returned by `lz4TrainNativeDictionaryAlloc`, then verify received bytes before decoding. | Metadata uses the wider shared dictionary fingerprint; frame `Dictionary_ID` is still derived from validated bytes; dictionary bytes are still distributed separately. |
| LZ4 native | `Lz4NativeDictionarySet` / `Lz4NativeDictionarySet.initFromMetadata` / `lz4NativeDictionarySetFromMetadataAlloc` | caller-owned slice of dictionaries or validated metadata+bytes catalog | Concatenated streams can carry different `Dictionary_ID` values, or a container provides versioned metadata records beside dictionary bytes. | Lets decoders resolve each frame without caller-side splitting; metadata construction validates bytes and duplicate IDs before decode; the alloc helper owns only the small catalog array. |
| Zstd native | `ZstdNativeFrameOptions.selection` | `.auto`; `.auto` / `.raw_or_rle` / `.literal_only` | You need deterministic native-subset frame selection. | `.auto` chooses the smaller implemented native mode; explicit modes are useful for tests and predictable behavior. |
| Zstd native | `ZstdNativeFrameOptions.block_size_max` | `std.compress.zstd.block_size_max`; `1...std.compress.zstd.block_size_max` | You need a latency/seekability/ratio knob. | Smaller blocks reduce per-block latency and direct-output bursts; larger blocks usually improve ratio and reduce headers. |
| Zstd native | `window_log` / `max_match_history_len` on `ZstdFrameOptions` and `ZstdNativeFrameOptions` | `null`; explicit window `10...41`; optional history `1 KiB...64 MiB` | You need a standards-compatible advertised window and an explicit encode-memory/ratio budget. | Null window is byte-identical to the prior writer and retains 8 MiB. Explicit windows default to `zstdNativeExplicitWindowMatchLenDefault` (16 MiB); logs 24+ use a separate 1/256-sampled long-distance index, and callers may raise history through `zstdNativeExplicitWindowMatchLenMax` (64 MiB). History may not exceed the advertised window, and a history override without `window_log` is rejected. |
| Zstd native | `ZstdNativeFrameOptions.match_search_budget` | `vort.zstdNativeMaxMatchSearchBudget` (`512` currently); `0...vort.zstdNativeMaxMatchSearchBudget` | You want to bound the bootstrap mixed-match planner. | `0` disables generic duplicate/repeated mixed planning while dictionary-only matches can still be used; the default searches more branches for ratio. |
| Zstd native | `vort.zstdNativeMaxDirectHuffmanSymbol` | `128` currently | You need to know when the bootstrap writer can use direct Huffman literal weights. | Byte values above this use FSE-compressed Huffman weights when the literal-only plan wins; incompressible shapes can still fall back to raw/RLE or another native plan. |
| Zstd native | `content_checksum` / `include_content_size` | both on by default | You want self-describing frames and content verification. | Disabling them saves bytes when a container already carries size/checksum metadata. |
| Zstd native | `ZstdNativeDictionary` / `ZstdNativeDictionary.initRawContent` | caller-owned bytes plus a non-zero ID, or explicit ID-less raw content | Payloads share preset history, including standard Zstd raw-content dictionary interoperability. | Non-zero IDs can be resolved through dictionary sets; ID-less frames require the caller to pass the raw dictionary explicitly, including through the `zstdDecodeNativeSeekableRange*WithDictionary` scan/index APIs, because the frame cannot select it from a set. |
| Zstd native | `zstdStandardDictionaryFromContentBound` / `zstdStandardDictionaryFromContentInto` / `zstdStandardDictionaryFromContentAlloc` | non-zero ID and at least 8 bytes of caller-selected history; generated header is `zstdStandardDictionaryHeaderLen` bytes | You need a dependency-free RFC 8878 full-dictionary container accepted by Vort and libzstd. | Uses stable portable baseline Huffman/FSE tables and repcodes `1/4/8`; it wraps selected history but does not train corpus-specific entropy statistics like COVER/FastCover. |
| Zstd native | `zstdTrainStandardDictionaryAlloc` | representative sample slices, native history `ZstdDictionaryTrainOptions`, and a non-zero ID | You want Vort to train selected history and first-block entropy models without libzstd. | Trains a complete 256-symbol Huffman table from raw sample-byte frequencies and OF/ML/LL FSE tables from dictionary-aware LZ77 sequence codes. It ranks the first two explicit offsets, retrains for that repcode candidate, and adopts it only when forced-compressed sample frames are strictly smaller by at least 1%; ties and sub-threshold changes retain `1/4/8`. The deterministic history selector is not COVER/FastCover. |
| Zstd native | `zstdTrainCoverStandardDictionaryAlloc` / `ZstdCoverDictionaryTrainOptions` | at least five samples, non-zero ID, `d=6/8`, `hash_log=8...20` | You want pure-Zig COVER-class history plus corpus-trained standard Zstd entropy tables and repcodes. | Uses the sample-boundary-safe deterministic COVER selector, then the same Huffman/FSE/repcode finalizer as the standard trainer. The result is an RFC 8878 full dictionary, but its bytes are not promised to match libzstd COVER/FastCover. |
| Zstd native | `zstdTrainOptimizedCoverStandardDictionaryAlloc` / `ZstdCoverDictionaryOptimizeOptions` | training and non-empty selector samples; automatic or explicit bounded `(d, k, hash_log)` grid | You want held-out COVER parameter selection plus a complete standard Zstd dictionary. | Minimizes the shared estimated dictionary/literal/match cost with stable enumeration-order ties, reports the selected parameters and candidate count, then trains entropy tables from both partitions. Reserve another corpus partition for unbiased evaluation. |
| Zstd native | `zstdTrainValidatedStandardDictionaryAlloc` | training samples, non-empty selector samples, history options, and non-zero ID | You can reserve representative payloads to select a better history without external trainers. | Evaluates total-frequency/cross-sample rankings, phrase configurations, ranked/reverse layouts, raw corpus-tail history, and five history sizes down to 25% using selector coverage plus estimated dictionary/literal/offset cost, then trains standard entropy tables from both input partitions; keep a separate held-out set for evaluation. This remains narrower than COVER/FastCover. |
| Shared dictionary | `dictionary.trainCoverAlloc` / `dictionary.CoverTrainOptions` | at least five sample slices; `d=6/8`, `hash_log=8...20`, default 256 MiB corpus limit | You need dependency-free, deterministic COVER-class history selection before codec-specific dictionary finalization. | Scores distinct d-mer hashes in sliding `k`-byte segments, clears selected frequencies, rotates COVER epochs, and places the best segments nearest the history tail. It preserves sample boundaries and does not claim byte-identical libzstd COVER/FastCover output. |
| Shared dictionary | `dictionary.trainOptimizedCoverAlloc` / `dictionary.CoverOptimizeOptions` | training and selector samples; default grid up to 16 candidates, caller cap up to 256 | You need deterministic held-out selection among COVER-class parameter sets. | Duplicate grid values collapse, incompatible `(d, k)` pairs are skipped, invalid or oversized grids fail before training, `max_corpus_size` bounds each input partition, and the owned result reports its exact score, selected concrete options, and evaluated count. |
| Shared dictionary | `dictionary.trainValidatedTargetsAlloc` | training samples, selector samples, ordered target sizes, and shared phrase options | You need several validation-selected history sizes from the same corpus. | Collects every phrase configuration once, then independently assembles and scores each requested target without changing candidate or tie order. The returned optional slices are owned by `OwnedValidatedDictionaries`; use `take(index)` to transfer one before `deinit`. The Zstd validated standard trainer uses this internally for its five-size ladder. |
| Shared dictionary | `summarizeDictionaryMatches` / `dictionary.validationScore` | borrowed dictionary, sample slices, and non-zero minimum match length | You need dictionary coverage/cost diagnostics without temporary allocation. | Streams the same greedy matches as `findDictionaryMatchesAlloc`; the legacy `summarizeDictionaryMatchesAlloc` and `dictionary.validationScoreAlloc` names remain compatible wrappers but no longer allocate. |
| Zstd native | `ZstdOwnedNativeDictionary.metadata()` / `ZstdNativeDictionary.initFromMetadata` / `encodeDictionaryMetadata*` / `decodeDictionaryMetadata*` / `*DictionaryMetadataCatalog*` | shared `DictionaryMetadata` plus `std.compress.zstd.default_window_len`; single records are 32 bytes and catalogs are versioned counted records with strict and prefix decoders | You want to persist trained dictionary catalog metadata from the same object returned by `zstdTrainNativeDictionaryAlloc`, then verify received bytes before decoding. | Metadata uses the wider shared dictionary fingerprint; frame `Dictionary_ID` is still derived from validated bytes; dictionary bytes are still distributed separately. |
| Zstd native | `ZstdNativeDictionarySet` / `ZstdNativeDictionarySet.initFromMetadata` / `zstdNativeDictionarySetFromMetadataAlloc` | caller-owned slice of dictionaries or validated metadata+bytes catalog | Concatenated streams can carry different `Dictionary_ID` values, or a container provides versioned metadata records beside dictionary bytes. | Shared decoder APIs resolve per-frame IDs and avoid manual stream splitting; metadata construction validates bytes and duplicate IDs before decode; the alloc helper owns only the small catalog array. |

The same explicit-window policy is threaded through one-shot, reusable,
incremental, explicit-dictionary, dictionary-set, and seekable native encoders;
those surfaces share header construction, block sizing, rolling history, and
dictionary-distance enforcement rather than maintaining separate window
rules. Interoperability evidence includes a fixed libzstd 1.6.0 2,050-byte
fixture with frame descriptor `0x44`, a 1 KiB `Window_Descriptor`, checksum,
and two-byte FCS. Vort decodes that fixture through allocating,
caller-buffer, chunked, and incremental APIs, while the runtime probe decodes
Vort's corresponding explicit-window frame with libzstd. The bidirectional
probe also verifies a raw dictionary's in-window suffix remains referenceable
and its expired prefix is not emitted as a dictionary match. This closes the
explicit-window slice; it does not imply complete Zstd format, ratio, or speed
parity.

For bounded-memory decode, prefer the `*Limited`, exact-size, chunked, append,
and incremental forms when the surrounding container knows the expected output
length or has an allocation budget. Chunked append helpers decode split
compressed input into an existing `ArrayList`, so containers can preserve their
own prefixes/sidecars without constructing a reusable decoder just to avoid an
alloc-returning API. `*AppendExactSize` variants additionally verify the decoded
byte count before extending the destination, returning `SizeMismatch` for
container-advertised lengths that do not match the stream. Reusable
`NativeFrameDecoder` values expose matching single-frame `decodeChunks*` and
concatenated `decodeConcatenatedChunks*` helpers, so callers can keep
decoder-owned scratch capacity while still appending into their own output
buffers. Native one-shot, chunked, concatenated, and reusable decoders also provide
`decode*Into*ExactSize` forms, including dictionary/dictionary-set variants, for
caller-owned slices when a container-advertised byte count must match exactly.
Incremental native decoders expose the shared `StepResult`
contract: feed compressed bytes, provide caller-owned output slices, then call
`finish()` when an exact EOF/size check matters. Direct-output paths are fastest
when the caller supplies a large enough output slice; if a slice is too small
for an atomic compressed block, the decoders intentionally fall back to bounded
scratch and continue draining without losing correctness. Dictionary-set
chunked APIs additionally accept caller-owned compressed join scratch so split
input can be decoded without hidden global state. Public dictionary probes also
pin error precedence for hostile frames that carry a missing or mismatched
`Dictionary_ID` plus another defect: LZ4 covers content checksum, block
checksum, and content-size conflicts across one-shot and incremental paths;
Zstd covers content checksum, content-size, malformed raw/RLE blocks, and
malformed compressed sequence-table blocks, including incremental diagnostics
where that path applies. Dictionary-set probes extend the same precedence to
skippable concatenated streams whose later frame needs a missing ID, including
chunked/reusable helpers and incremental dictionary-set drains. LZ4
dictionary-set fixtures now cover later-frame block checksum, content checksum,
content-size, and invalid-match conflicts; Zstd dictionary-set fixtures cover
malformed compressed sequence-table conflicts. In those cases callers see
`NeedDictionary` before deeper payload or checksum errors, while providing the
matching dictionary exposes the underlying `ChecksumMismatch`, `SizeMismatch`,
`InvalidMatch`, or `CorruptFrame`.

`run-lz4-native-probe` also dynamically calls liblz4's `LZ4F_compressFrame` for 120 frame option/level/payload combinations spanning all four block-size IDs, linked and independent modes, checksums, omitted content size, and a 300 KiB multi-block payload. It decodes those frames through Vort's one-shot, incremental, reusable, and chunked public APIs, and independently decodes matching Vort-generated frames through `LZ4F_decompress`, so LZ4 interoperability coverage is bidirectional and is not limited to CLI routing.

`run-snappy-interop-probe` dynamically calls the complete libsnappy raw-block C
API. Eight libsnappy-generated blocks, from empty and tiny data through a 64 KiB
incompressible block and a 160 KiB multi-chunk payload, are decoded through
Vort's one-shot, exact-size caller-buffer, and split-input APIs. Matching
Vort-generated raw blocks are validated and decoded by libsnappy; the fixed
matrix requires copy-bearing output from both encoders. The same
libsnappy blocks are wrapped in standard checksummed framed-stream chunks and
decoded through Vort's one-shot, caller-buffer, split-input, and incremental
APIs, while every compressed block in Vort-generated frames is independently
validated and decoded by libsnappy (currently seven compressed chunks across
nine data chunks). The runtime dependency exists only in the probe; truncating
every libsnappy block must also be rejected by both implementations. The
production Snappy implementation remains pure Zig.

The focused library benchmark/gate tracks these public surfaces directly:

```sh
zig build run-native-library-bench
zig build run-native-library-bench -- --path README.md --limit 4096 --iterations 1
zig build run-native-library-bench-path-gate
zig build run-native-library-bench-gate
zig build run-native-library-bench-releasefast-csv
zig build run-native-library-bench-releasefast-gate
zig build run-native-library-bench-releasefast-path-gate
```

The bench command accepts repeated `--path` arguments plus `--limit` for focused project-file payloads. The Debug and ReleaseFast gates currently require the LZ4 chain-depth, Zstd match-budget, high-byte
FSE Huffman, LZ4/Zstd lib/native lib-decode rows, Zstd sequence-Huffman literal, LZ4/Zstd lib-generated compatibility-frame/no-size/checksum/no-size+checksum/independent/full-independent, dictionary, trained-dictionary,
dictionary-set, chunked dictionary-set, chunked append, chunked append exact-size, reusable decoder,
reusable append exact-size, direct-output, and small-output rows to
round-trip and to preserve the expected size relationships. In addition to the
CSV rows, the bench executable now runs cheap pre-row smoke checks for
no-content-size multi-compressed Zstd frames (including checksum mismatch and
truncated-checksum limit precedence), LZ4 skippable streams followed by
malformed/truncated/checksum/trailing frames, and LZ4/Zstd dictionary-set
skippable streams in direct-output plus codec-specific small-output modes. These checks intentionally
do not add CSV rows, keeping the Debug gate bounded. The heavier limited
compressed-FSE sequence-table path is covered by
`run-zstd-native-dictionary-probe` for public inspect/decode of LL/OF/ML=FSE
blocks plus repeated sequence-table reuse, and `run-zstd-native-frame-probe` for
treeless repeat-Huffman literal reuse, mixed compressed-FSE sequence-table
layouts (for example OF+ML=FSE with predefined LL), repeat-offset selector variants
(zero-literal rep1/rep2, positive-literal rep2, invalid `rep0 - 1`, valid cross-block `rep0 - 1` including the minimum non-zero boundary after a direct-offset update plus Repeat_Mode replay, multi-sequence predefined-table state transitions, mixed RLE/predefined sequence modes, and repeated mixed-table modes across blocks, and pure library-level libzstd-generated frame differentials with incremental drains and chunked split-input helpers), and
malformed sequence bitstreams, mixed-table reserved-bit/truncated/short-bitstream paths, and short/corrupt LL/OF/ML compressed-FSE state streams,
while focused unit tests keep the writer-side ML=FSE construction covered
without adding the heavier path to the regular native library bench gate.

## Direction

See `docs/native-format.md` for the initial native Vort frame direction,
`docs/native-lz4-zstd-status.md` for the current native LZ4/Zstd implementation
audit, `docs/validation-json.md` for validation/report JSON schemas,
`docs/fuzzing.md` for parser fuzzing entrypoints, `docs/external-differential.md` for competitor
differential validation, `docs/checksum-dispatch.md` for checksum dispatch
status, `docs/zstd-gap.md` for current zstd comparison limitations, and
`docs/dynamic-encoder.md` for dynamic encoder status. QCOW2 support and its
storage-specific limits are documented in `docs/formats/qcow2.md`; VMDK support
is documented in `docs/formats/vmdk.md`, EWF/E01 support in
`docs/formats/ewf.md`, CHD v5 support in `docs/formats/chd.md`, and classic VHD
support in `docs/formats/vhd.md`, VHDX support in `docs/formats/vhdx.md`, and
CISO/ZISO support in `docs/formats/cso.md`, and DAX support in
`docs/formats/dax.md`.
GCZ support is documented in `docs/formats/gcz.md`.
The current WIA/RVZ reader, raw/partition writer, and caller-supplied common-key
model are documented in `docs/formats/wia-rvz.md`.
WBFS support and its explicit multi-disc/filesystem-scrubbing limits are
documented in `docs/formats/wbfs.md`.
WDF1/WDF2 support and its split-output/scrubbing limits are documented in
`docs/formats/wdf.md`.
WUX support and its raw-WUD/streaming limits are documented in
`docs/formats/wux.md`.
Local Rust deflate
baselines such as `~/Work/fdeflate` and `~/Work/miniz_oxide` should be treated
as required functionality/performance competitors once their executable harnesses
are wired into Vort validation.

Compatibility formats (`raw deflate`, `zlib`, `gzip`, `bzip2`, `XZ/LZMA2`,
LZMA-Alone, Unix `.Z`, lzip, LZOP, 7z, and selected zstd-facing workflows)
should be behavior-compatible where claimed.
Native Vort formats may innovate more aggressively, but they must be versioned,
documented, fuzzed, benchmarked, and differentially tested against reference
implementations where a reference exists.
