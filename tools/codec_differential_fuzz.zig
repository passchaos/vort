//! Structure-aware differential fuzzing for the common compression codecs.
//!
//! The deterministic generator builds valid Vort wires for raw Deflate, zlib,
//! gzip, standard Zstd and RFC Brotli across content patterns and boundary
//! sizes. Beyond the baseline encoder matrix it exercises format features that
//! raw-byte fuzzing cannot reach:
//!
//!   - raw/zlib preset dictionaries (deep mode);
//!   - gzip optional headers: FEXTRA, FNAME, FCOMMENT and FHCRC;
//!   - Zstd content checksums, unknown content size, concatenated frames and
//!     skippable frames in leading/trailing/interspersed positions;
//!   - Brotli explicit window widths, disabled literal context modeling and the
//!     opt-in Large Window extension;
//!   - RNG-driven random input sizes (deep mode).
//!
//! Every valid wire is checked three ways:
//!
//!   1. Vort one-shot and exact-size decode reproduces the source exactly.
//!   2. The installed system reference libraries (zlib, libzstd, libbrotli)
//!      accept the same wire and reproduce the source exactly. This is direct
//!      wire-interoperability evidence rather than an internal oracle.
//!   3. Systematic truncation and byte mutations never produce a successful
//!      decode whose output disagrees with the reference decoder.
//!
//! Truncated prefixes must be classified the same way by Vort and the
//! reference: both reject, or both accept and emit identical bytes (the only
//! accepted-complete case in practice is a prefix that already holds the
//! codec end marker). Mutated streams may be accepted by either
//! implementation; when both accept they must agree byte-for-byte. Panics,
//! hangs and mismatched outputs fail the process. The fixed seed makes every
//! run reproducible; `--seed`, `--only`, `--deep` and `--max-size` widen or
//! focus the campaign.

const std = @import("std");
const vort = @import("vort");

const c = @cImport({
    @cInclude("zlib.h");
    @cInclude("zstd.h");
    @cInclude("brotli/decode.h");
});

const Codec = enum {
    raw,
    zlib,
    gzip,
    zstd,
    br,

    fn label(self: Codec) []const u8 {
        return switch (self) {
            .raw => "raw-deflate",
            .zlib => "zlib",
            .gzip => "gzip",
            .zstd => "zstd",
            .br => "brotli",
        };
    }
};

const Pattern = enum {
    rle_zero,
    rle_ff,
    periodic2,
    periodic16,
    random,
    text,
    mixed,
    sparse_binary,

    fn label(self: Pattern) []const u8 {
        return switch (self) {
            .rle_zero => "rle-zero",
            .rle_ff => "rle-ff",
            .periodic2 => "periodic2",
            .periodic16 => "periodic16",
            .random => "random",
            .text => "text",
            .mixed => "mixed",
            .sparse_binary => "sparse-binary",
        };
    }
};

const Rng = struct {
    state: u64,

    fn next(self: *Rng) u64 {
        // SplitMix64: enough structure diversity for a deterministic harness.
        self.state +%= 0x9e3779b97f4a7c15;
        var z = self.state;
        z = (z ^ (z >> 30)) *% 0xbf58476d1ce4e5b9;
        z = (z ^ (z >> 27)) *% 0x94d049bb133111eb;
        return z ^ (z >> 31);
    }

    fn bounded(self: *Rng, limit: usize) usize {
        if (limit <= 1) return 0;
        return @as(usize, @truncate(self.next())) % limit;
    }

    fn byte(self: *Rng) u8 {
        return @truncate(self.next() >> 32);
    }

    fn fill(self: *Rng, buffer: []u8) void {
        var i: usize = 0;
        while (i + 8 <= buffer.len) : (i += 8) {
            std.mem.writeInt(u64, buffer[i..][0..8], self.next(), .little);
        }
        while (i < buffer.len) : (i += 1) buffer[i] = self.byte();
    }
};

/// One generated wire under test plus everything the decoders need to route
/// it correctly. `dictionary` and `source` borrow buffers owned by the
/// harness case and stay valid for the whole `checkWire` call.
const WireCase = struct {
    label: []const u8,
    wire: []u8,
    /// Expected decoded bytes; aliases the case input except concatenated
    /// Zstd frames, whose source is the joined member payloads.
    source: []const u8,
    dictionary: ?[]const u8 = null,
    /// Brotli Large Window extension: Vort must opt in and libbrotli only
    /// accepts the wire through a streaming decoder with the same parameter.
    brotli_large_window: bool = false,
    /// Zstd skippable/concatenated wires are rejected by the libzstd one-shot
    /// API but accepted by its streaming API, which is the matching reference
    /// contract for Vort's frame-loop decoder.
    zstd_stream_reference: bool = false,
    /// Concatenated gzip members need a per-member inflate state: a single
    /// inflate call stops at the first member's Z_STREAM_END without
    /// auto-continuing into the next member.
    gzip_multi_member: bool = false,
    /// Brotli RAW shared-prefix dictionary, attached to both Vort encode and
    /// decode. The installed system libbrotli (1.0.9) exports no attach API,
    /// so the reference side is skipped for this variant and both Vort paths
    /// must agree; a no-dictionary Vort decode must reject the wire.
    brotli_shared_dictionary: bool = false,
    /// Owned serialized Zstd standard dictionary. Unlike `dictionary` (raw
    /// bytes fed to every codec), this carries the full standard header and
    /// is freed by `runCase` after the wire checks complete.
    standard_dictionary_bytes: ?[]u8 = null,
    /// Vort-native magicless Zstd frame with no standard magic number. The
    /// system libzstd rejects it as an unknown frame descriptor, so it is a
    /// Vort-to-Vort contract: both Vort decode paths must agree, and a
    /// standard-format Vort decode must reject the wire.
    zstd_magicless: bool = false,
};

const Stats = struct {
    wires: u64 = 0,
    variant_wires: u64 = 0,
    vort_roundtrip_ok: u64 = 0,
    exact_size_ok: u64 = 0,
    reference_ok: u64 = 0,
    reference_rejected_valid: u64 = 0,
    truncation_cuts: u64 = 0,
    truncation_both_rejected: u64 = 0,
    truncation_agreed: u64 = 0,
    mutations_xor: u64 = 0,
    mutations_overwrite: u64 = 0,
    mutations_insert: u64 = 0,
    mutations_delete: u64 = 0,
    mutation_rejected: u64 = 0,
    one_sided_divergence: u64 = 0,
};

const Failure = struct {
    codec: Codec,
    pattern: Pattern,
    variant: []const u8,
    input_len: usize,
    wire_len: usize,
    stage: []const u8,
    detail: []const u8,
};

const Harness = struct {
    allocator: std.mem.Allocator,
    rng: Rng,
    stats: Stats = .{},
    failures: std.ArrayList(Failure),
    only: ?Codec,
    deep: bool,
    max_mutation_wire: usize = 2048,
    hq_br_limit: usize = 1024,

    fn fail(
        self: *Harness,
        codec: Codec,
        pattern: Pattern,
        variant: []const u8,
        input_len: usize,
        wire_len: usize,
        stage: []const u8,
        comptime fmt: []const u8,
        args: anytype,
    ) error{ FuzzMismatch, OutOfMemory }!void {
        const detail = try std.fmt.allocPrint(self.allocator, fmt, args);
        // Retain the first failures only; the process still exits nonzero, so
        // later violations are represented by the aggregate counters.
        if (self.failures.items.len < 16) {
            try self.failures.append(self.allocator, .{
                .codec = codec,
                .pattern = pattern,
                .variant = variant,
                .input_len = input_len,
                .wire_len = wire_len,
                .stage = stage,
                .detail = detail,
            });
        } else {
            self.allocator.free(detail);
        }
    }

    fn writePattern(self: *Harness, pattern: Pattern, buffer: []u8) void {
        switch (pattern) {
            .rle_zero => @memset(buffer, 0),
            .rle_ff => @memset(buffer, 0xff),
            .periodic2 => {
                for (buffer, 0..) |*byte, index| byte.* = if (index % 2 == 0) 0x55 else 0xaa;
            },
            .periodic16 => {
                const period = [_]u8{
                    0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77,
                    0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee, 0xff,
                };
                for (buffer, 0..) |*byte, index| byte.* = period[index % period.len];
            },
            .random => self.rng.fill(buffer),
            .text => {
                const alphabet = "abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ 0123456789\n.,;";
                for (buffer) |*byte| byte.* = alphabet[self.rng.bounded(alphabet.len)];
            },
            .mixed => {
                var offset: usize = 0;
                while (offset < buffer.len) {
                    const remaining = buffer.len - offset;
                    const chunk = @min(remaining, 1 + self.rng.bounded(@min(64, remaining) + 1));
                    const kind = self.rng.bounded(3);
                    const slice = buffer[offset .. offset + chunk];
                    switch (kind) {
                        0 => @memset(slice, self.rng.byte()),
                        1 => self.rng.fill(slice),
                        else => {
                            const word = "the quick brown fox ";
                            for (slice, 0..) |*byte, index| byte.* = word[index % word.len];
                        },
                    }
                    offset += chunk;
                }
            },
            .sparse_binary => {
                @memset(buffer, 0);
                var offset: usize = 0;
                while (offset < buffer.len) {
                    offset += 1 + self.rng.bounded(16);
                    if (offset < buffer.len) buffer[offset] = self.rng.byte();
                }
            },
        }
    }

    /// Concatenated gzip members go through the streaming decoder with
    /// `allow_concatenated`, since the one-shot gzip facade validates exactly
    /// one member and rejects the suffix as trailing data. `upper_bound` is
    /// the full-wire expected output size (an upper bound for truncated
    /// prefixes) and keeps the output allocation bounded.
    fn vortGzipConcatDecode(self: *Harness, wire: []const u8, upper_bound: usize) ?[]u8 {
        const a = self.allocator;
        if (wire.len == 0) return null;
        const history = a.alloc(u8, 32 * 1024) catch return null;
        defer a.free(history);
        var decoder = vort.GzipIncrementalDecoder.init(.{
            .allow_concatenated = true,
        }, history) catch return null;
        // Match the reference's 4x/1 MiB headroom so mutated RLE expansion
        // cannot turn into an output-buffer artifact.
        const cap = @min(@max(upper_bound *% 4, 4096), 1 << 20);
        var output = a.alloc(u8, cap + 1) catch return null;
        errdefer a.free(output);
        var read: usize = 0;
        var written: usize = 0;
        while (read < wire.len) {
            const result = decoder.step(wire[read..], output[written..]) catch {
                a.free(output);
                return null;
            };
            read += result.progress.input_read;
            written += result.progress.output_written;
            if (result.status == .done) break;
            if (result.progress.input_read == 0 and result.progress.output_written == 0) {
                a.free(output);
                return null;
            }
        }
        decoder.finish() catch {
            a.free(output);
            return null;
        };
        if (read != wire.len) {
            a.free(output);
            return null;
        }
        return a.realloc(output, written) catch output[0..written];
    }

    /// Magicless frames have no magic-aware exact-size entry point, so decode
    /// through the formatted options API and verify the length against the
    /// caller-supplied expectation.
    fn magiclessExactDecode(a: std.mem.Allocator, wire: []const u8, expected: usize) ?[]u8 {
        const decoded = vort.zstd.decodeFrameAllocWithOptions(a, wire, .{
            .format = .magicless,
            .expected_output_len = expected,
        }) catch return null;
        if (decoded.len != expected) {
            a.free(decoded);
            return null;
        }
        return decoded;
    }

    fn vortDecode(self: *Harness, codec: Codec, wire_case: WireCase) ?[]u8 {
        const a = self.allocator;
        const wire = wire_case.wire;
        const dict = wire_case.dictionary;
        if (codec == .gzip and wire_case.gzip_multi_member) {
            return self.vortGzipConcatDecode(wire, wire_case.source.len);
        }
        const decoded = switch (codec) {
            .raw => if (dict) |preset|
                vort.decodeRawDeflateAllocWithDictionary(a, wire, preset) catch return null
            else
                vort.decodeRawDeflateAlloc(a, wire) catch return null,
            .zlib, .gzip => if (dict) |preset|
                vort.decodeZlibOrGzipAllocWithDictionary(a, wire, preset) catch return null
            else
                vort.decodeZlibOrGzipAlloc(a, wire) catch return null,
            .zstd => if (wire_case.zstd_magicless)
                vort.zstd.decodeFrameAllocWithOptions(a, wire, .{ .format = .magicless }) catch return null
            else if (wire_case.standard_dictionary_bytes) |bytes| blk: {
                const view = vort.zstd.NativeDictionary.initFromStandardDictionary(bytes) catch break :blk null;
                break :blk vort.zstd.decodeFrameAllocWithDictionary(a, wire, view.dictionary) catch null;
            } else if (dict) |preset|
                vort.zstd.decodeFrameAllocWithDictionary(
                    a,
                    wire,
                    vort.zstd.NativeDictionary.initRawContent(preset),
                ) catch return null
            else
                vort.zstd.decodeFrameAlloc(a, wire) catch return null,
            .br => if (wire_case.brotli_shared_dictionary)
                vort.br.decodeStreamAllocWithOptions(a, wire, .{
                    .shared_dictionary = .{ .raw_prefixes = &.{dict.?} },
                }) catch return null
            else if (wire_case.brotli_large_window)
                vort.br.decodeStreamAllocWithOptions(a, wire, .{ .allow_large_window = true }) catch return null
            else
                vort.br.decodeStreamAlloc(a, wire) catch return null,
        };
        return decoded;
    }

    fn vortDecodeExact(self: *Harness, codec: Codec, wire_case: WireCase, expected: usize) ?[]u8 {
        const a = self.allocator;
        const wire = wire_case.wire;
        const dict = wire_case.dictionary;
        if (codec == .gzip and wire_case.gzip_multi_member) {
            const decoded = self.vortGzipConcatDecode(wire, expected) orelse return null;
            if (decoded.len != expected) {
                a.free(decoded);
                return null;
            }
            return decoded;
        }
        return switch (codec) {
            .raw => if (dict) |preset|
                vort.decodeRawDeflateAllocWithDictionaryExactSize(a, wire, preset, expected) catch return null
            else
                vort.decodeRawDeflateAllocExactSize(a, wire, expected) catch return null,
            .zlib, .gzip => if (dict) |preset|
                vort.decodeZlibOrGzipAllocWithDictionaryExactSize(a, wire, preset, expected) catch return null
            else
                vort.decodeZlibOrGzipAllocExactSize(a, wire, expected) catch return null,
            .zstd => if (wire_case.zstd_magicless)
                magiclessExactDecode(a, wire, expected)
            else if (wire_case.standard_dictionary_bytes) |bytes|
                vort.zstd.decodeFrameAllocWithDictionaryExactSize(
                    a,
                    wire,
                    (vort.zstd.NativeDictionary.initFromStandardDictionary(bytes) catch return null).dictionary,
                    expected,
                ) catch return null
            else if (dict) |preset|
                vort.zstd.decodeFrameAllocWithDictionaryExactSize(
                    a,
                    wire,
                    vort.zstd.NativeDictionary.initRawContent(preset),
                    expected,
                ) catch return null
            else
                vort.zstd.decodeFrameAllocExactSize(a, wire, expected) catch return null,
            .br => if (wire_case.brotli_shared_dictionary)
                vort.br.decodeStreamAllocExactSizeWithOptions(a, wire, expected, .{
                    .shared_dictionary = .{ .raw_prefixes = &.{dict.?} },
                }) catch return null
            else if (wire_case.brotli_large_window)
                vort.br.decodeStreamAllocExactSizeWithOptions(a, wire, expected, .{ .allow_large_window = true }) catch return null
            else
                vort.br.decodeStreamAllocExactSize(a, wire, expected) catch return null,
        };
    }

    fn referenceDecode(self: *Harness, codec: Codec, wire_case: WireCase, capacity: usize) ?[]u8 {
        const a = self.allocator;
        // One byte of slack keeps zero-length outputs addressable and lets
        // overrun-prone implementations fail loudly instead of aliasing. The
        // 4x headroom tolerates RLE-style expansion in mutated wires while a
        // fixed ceiling bounds every reference allocation.
        const target_cap = @min(@max(capacity *% 4, 4096), 1 << 20);
        const dst = a.alloc(u8, target_cap + 1) catch return null;
        switch (codec) {
            .raw => return zlibInflate(a, dst, wire_case.wire, -15, wire_case.dictionary),
            .zlib => return zlibInflate(a, dst, wire_case.wire, 15, wire_case.dictionary),
            .gzip => if (wire_case.gzip_multi_member)
                return gzipInflateMembers(a, dst, wire_case.wire)
            else
                return zlibInflate(a, dst, wire_case.wire, 31, null),
            .zstd => {
                if (wire_case.zstd_stream_reference) {
                    return zstdDecompressStream(a, dst, wire_case.wire);
                }
                // A standard dictionary passes its full serialized bytes; a
                // raw-content dictionary passes just the history bytes.
                const dict_source = wire_case.standard_dictionary_bytes orelse wire_case.dictionary;
                const dict_ptr = if (dict_source) |preset| preset.ptr else null;
                const dict_len = if (dict_source) |preset| preset.len else 0;
                const dctx = c.ZSTD_createDCtx() orelse {
                    a.free(dst);
                    return null;
                };
                defer _ = c.ZSTD_freeDCtx(dctx);
                const result = c.ZSTD_decompress_usingDict(
                    dctx,
                    dst.ptr,
                    dst.len,
                    wire_case.wire.ptr,
                    wire_case.wire.len,
                    dict_ptr,
                    dict_len,
                );
                if (c.ZSTD_isError(result) != 0) {
                    a.free(dst);
                    return null;
                }
                return a.realloc(dst, result) catch dst[0..result];
            },
            .br => {
                if (wire_case.brotli_large_window) {
                    return brotliDecompressStream(a, dst, wire_case.wire, true);
                }
                var decoded_size: usize = dst.len;
                const result = c.BrotliDecoderDecompress(
                    wire_case.wire.len,
                    wire_case.wire.ptr,
                    &decoded_size,
                    dst.ptr,
                );
                if (result != c.BROTLI_DECODER_RESULT_SUCCESS) {
                    a.free(dst);
                    return null;
                }
                return a.realloc(dst, decoded_size) catch dst[0..decoded_size];
            },
        }
    }

    fn zlibInflate(
        a: std.mem.Allocator,
        dst: []u8,
        wire: []const u8,
        window_bits: c_int,
        dictionary: ?[]const u8,
    ) ?[]u8 {
        var stream: c.z_stream = std.mem.zeroes(c.z_stream);
        if (c.inflateInit2(&stream, window_bits) != c.Z_OK) {
            a.free(dst);
            return null;
        }
        // Raw Deflate has no FDICT marker, so inflate cannot signal
        // Z_NEED_DICT: the dictionary must be installed before the first
        // inflate call. zlib-wrapped streams advertise the need and get the
        // dictionary reactively on Z_NEED_DICT instead.
        if (window_bits < 0) {
            if (dictionary) |preset| {
                if (c.inflateSetDictionary(&stream, preset.ptr, @intCast(preset.len)) != c.Z_OK) {
                    _ = c.inflateEnd(&stream);
                    a.free(dst);
                    return null;
                }
            }
        }
        stream.next_in = @constCast(wire.ptr);
        stream.avail_in = @intCast(wire.len);
        stream.next_out = dst.ptr;
        stream.avail_out = @intCast(dst.len);
        var code = c.inflate(&stream, c.Z_FINISH);
        if (code == c.Z_NEED_DICT) {
            const preset = dictionary orelse {
                _ = c.inflateEnd(&stream);
                a.free(dst);
                return null;
            };
            if (c.inflateSetDictionary(&stream, preset.ptr, @intCast(preset.len)) != c.Z_OK) {
                _ = c.inflateEnd(&stream);
                a.free(dst);
                return null;
            }
            code = c.inflate(&stream, c.Z_FINISH);
        }
        _ = c.inflateEnd(&stream);
        if (code != c.Z_STREAM_END) {
            a.free(dst);
            return null;
        }
        const written = dst.len - stream.avail_out;
        return a.realloc(dst, written) catch dst[0..written];
    }

    /// Multi-member gzip reference. One inflate stream stops at the first
    /// Z_STREAM_END, so each member gets its own inflate state over the
    /// remaining bytes. Any member that cannot reach Z_STREAM_END (a cut
    /// inside a header, deflate body, CRC or ISIZE) rejects the whole wire,
    /// matching Vort's strict full-consumption decode.
    fn gzipInflateMembers(a: std.mem.Allocator, dst: []u8, wire: []const u8) ?[]u8 {
        if (wire.len == 0) {
            a.free(dst);
            return null;
        }
        var offset: usize = 0;
        var total: usize = 0;
        while (offset < wire.len) {
            var stream: c.z_stream = std.mem.zeroes(c.z_stream);
            if (c.inflateInit2(&stream, 31) != c.Z_OK) {
                a.free(dst);
                return null;
            }
            stream.next_in = @constCast(wire.ptr + offset);
            stream.avail_in = @intCast(wire.len - offset);
            stream.next_out = dst.ptr + total;
            stream.avail_out = @intCast(dst.len - total);
            const code = c.inflate(&stream, c.Z_FINISH);
            const consumed = (wire.len - offset) - @as(usize, stream.avail_in);
            const produced = (dst.len - total) - @as(usize, stream.avail_out);
            _ = c.inflateEnd(&stream);
            if (code != c.Z_STREAM_END) {
                a.free(dst);
                return null;
            }
            offset += consumed;
            total += produced;
            if (total > dst.len) {
                a.free(dst);
                return null;
            }
        }
        return a.realloc(dst, total) catch dst[0..total];
    }

    /// Streaming libzstd reference. The one-shot API rejects skippable frames
    /// and trailing concatenated members, while Vort's frame loop accepts them,
    /// so the streaming API is the matching interoperability contract. A
    /// truncated stream that makes zero progress on the final call is treated
    /// as a rejection.
    fn zstdDecompressStream(a: std.mem.Allocator, dst: []u8, wire: []const u8) ?[]u8 {
        // Match ZSTD_decompress, which accepts an empty input as a zero-byte
        // result; Vort's frame loop takes the same empty-output shortcut.
        const dctx = c.ZSTD_createDCtx() orelse {
            a.free(dst);
            return null;
        };
        defer _ = c.ZSTD_freeDCtx(dctx);
        var input = c.ZSTD_inBuffer{ .src = wire.ptr, .size = wire.len, .pos = 0 };
        var total: usize = 0;
        // Match ZSTD_decompress, which accepts an empty input as a zero-byte
        // result; Vort's frame loop takes the same empty-output shortcut.
        if (input.size == 0) {
            return a.realloc(dst, 0) catch dst[0..0];
        }
        // ZSTD_decompressStream returns 0 at every frame boundary, including
        // skippable frames and concatenated members, even when input remains.
        // A positive final return means the last frame is still waiting for
        // bytes, so completion requires both full consumption and a zero hint.
        var last_hint: usize = 1;
        while (input.pos < input.size) {
            var output = c.ZSTD_outBuffer{
                .dst = dst.ptr + total,
                .size = dst.len - total,
                .pos = 0,
            };
            const before_in = input.pos;
            last_hint = c.ZSTD_decompressStream(dctx, &output, &input);
            if (c.ZSTD_isError(last_hint) != 0) {
                a.free(dst);
                return null;
            }
            total += output.pos;
            if (total > dst.len) {
                a.free(dst);
                return null;
            }
            if (input.pos == before_in and output.pos == 0) {
                // No forward progress with a frame still pending: truncated.
                a.free(dst);
                return null;
            }
        }
        if (last_hint != 0) {
            a.free(dst);
            return null;
        }
        return a.realloc(dst, total) catch dst[0..total];
    }

    /// Streaming libbrotli reference, optionally enabling the Large Window
    /// extension, which the one-shot BrotliDecoderDecompress entrypoint never
    /// accepts.
    fn brotliDecompressStream(
        a: std.mem.Allocator,
        dst: []u8,
        wire: []const u8,
        large_window: bool,
    ) ?[]u8 {
        const state = c.BrotliDecoderCreateInstance(null, null, null) orelse {
            a.free(dst);
            return null;
        };
        defer c.BrotliDecoderDestroyInstance(state);
        if (large_window) {
            if (c.BrotliDecoderSetParameter(state, c.BROTLI_DECODER_PARAM_LARGE_WINDOW, 1) == 0) {
                a.free(dst);
                return null;
            }
        }
        var avail_in: usize = wire.len;
        var next_in: [*c]const u8 = wire.ptr;
        var avail_out: usize = dst.len;
        var next_out: [*c]u8 = dst.ptr;
        var total_out: usize = 0;
        while (true) {
            const in_before = avail_in;
            const out_before = avail_out;
            const result = c.BrotliDecoderDecompressStream(
                state,
                &avail_in,
                &next_in,
                &avail_out,
                &next_out,
                &total_out,
            );
            switch (result) {
                c.BROTLI_DECODER_RESULT_ERROR => {
                    a.free(dst);
                    return null;
                },
                c.BROTLI_DECODER_RESULT_SUCCESS => {
                    if (avail_in != 0) {
                        a.free(dst);
                        return null;
                    }
                    return a.realloc(dst, total_out) catch dst[0..total_out];
                },
                else => {
                    // NEEDS_MORE_INPUT / NEEDS_MORE_OUTPUT: zero progress on
                    // both sides means the wire is truncated or output-bound.
                    if (avail_in == in_before and avail_out == out_before) {
                        a.free(dst);
                        return null;
                    }
                },
            }
        }
    }

    fn buildBaselineWire(self: *Harness, codec: Codec, input: []const u8, level: u4) ![]u8 {
        const a = self.allocator;
        return switch (codec) {
            .raw => try vort.deflate.encodeRawLevelAlloc(a, input, level),
            .zlib => {
                const options = try vort.zlibEncodeOptionsForLevel(level, 15);
                return try vort.encodeZlibFrameAlloc(a, input, options);
            },
            .gzip => {
                if (level == 0) return try vort.encodeGzipStoredAlloc(a, input);
                const compression = try vort.deflate.optionsForZlibLevel(level);
                return try vort.encodeGzipBestWithHeaderAlloc(
                    a,
                    input,
                    compression,
                    .{},
                );
            },
            .zstd => return try vort.zstd.encodeFrameWithLevelAlloc(a, input, @intCast(level)),
            .br => {
                return try vort.br.encodePlannedStreamWithOptionsAlloc(a, input, .{
                    .quality = level,
                });
            },
        };
    }

    /// Build a deterministic 256-byte text-like preset dictionary. The content
    /// mixes common words and RNG bytes so dictionary-backed matches are
    /// realistic while every campaign stays reproducible.
    /// Train a Vort standard full dictionary on a deterministic corpus whose
    /// samples overlap the case input, then encode a dictionary-ID frame. The
    /// returned WireCase owns the serialized dictionary through
    /// `standard_dictionary_bytes`, which `runCase` frees after checks.
    fn buildStandardDictionaryCase(
        self: *Harness,
        a: std.mem.Allocator,
        input: []const u8,
        level: u4,
        cases: *std.ArrayList(WireCase),
        source_owner: *std.ArrayList([]u8),
    ) !?WireCase {
        _ = cases;
        _ = source_owner;
        // Training needs a real corpus: eight short overlapping samples give
        // the COVER selector enough boundary-safe phrases without the
        // quadratic substring scan dominating the campaign. Tiny inputs are
        // skipped rather than fed to the trainer.
        if (input.len < 64) return null;
        var samples: [8][]u8 = undefined;
        var owned: usize = 0;
        errdefer for (samples[0..owned]) |sample| a.free(sample);
        const shared = input[0..@min(input.len, 32)];
        for (0..samples.len) |index| {
            const suffix_len = 8 + (index * 5) % 16;
            const sample = try a.alloc(u8, shared.len + suffix_len);
            samples[owned] = sample;
            owned += 1;
            @memcpy(sample[0..shared.len], shared);
            var rng = Rng{ .state = self.rng.state +% @as(u64, index) *% 0x9e3779b97f4a7c15 };
            for (sample[shared.len..]) |*byte| byte.* = rng.byte();
        }
        defer for (samples) |sample| a.free(sample);

        const dictionary_id: u32 = 0x766f_7274; // "vort"
        const trained = vort.zstd.trainStandardDictionaryAlloc(a, &samples, .{
            .target_size = 128,
            .min_phrase_len = 4,
            .max_phrase_len = 8,
            .max_phrases = 64,
        }, dictionary_id) catch return null;
        const dict_wire = vort.zstd.encodeFrameWithLevelAndOptionsAndDictionaryAlloc(
            a,
            input,
            @intCast(level),
            .{},
            trained.asDictionary(),
        ) catch |err| switch (err) {
            else => {
                trained.deinit(a);
                return null;
            },
        };
        return WireCase{
            .label = "standard-trained-dictionary",
            .wire = dict_wire,
            .source = input,
            .standard_dictionary_bytes = trained.bytes,
        };
    }

    fn buildDictionary(self: *Harness) ![]u8 {
        const a = self.allocator;
        const dict = try a.alloc(u8, 256);
        errdefer a.free(dict);
        const words = "the quick brown fox jumps over shared history words ";
        for (dict, 0..) |*byte, index| {
            byte.* = if (index % 3 == 0) self.rng.byte() else words[index % words.len];
        }
        return dict;
    }

    fn buildGzipHeaderOptions(self: *Harness) vort.GzipHeaderOptions {
        const extra_len = self.rng.bounded(20);
        return .{
            .text = self.rng.bounded(2) == 0,
            .mtime = @truncate(self.rng.next()),
            .xfl = if (self.rng.bounded(2) == 0) 0x04 else 0x02,
            .os = @intCast(self.rng.bounded(14)),
            .extra = blk: {
                const extra = self.allocator.alloc(u8, extra_len) catch break :blk null;
                self.rng.fill(extra);
                break :blk extra;
            },
            .filename = if (self.rng.bounded(2) == 0) "vort-fuzz-input.txt" else null,
            .comment = if (self.rng.bounded(2) == 0) "structure-aware differential fuzz" else null,
            .header_crc = self.rng.bounded(2) == 0,
        };
    }

    fn freeGzipHeaderOptions(self: *Harness, options: vort.GzipHeaderOptions) void {
        if (options.extra) |extra| self.allocator.free(extra);
    }

    /// Feature variants for one codec/level. Baseline callers own the returned
    /// wires; each slice is freed after its `checkWire` run. `source_owner`
    /// receives any joined expected-output buffer (Zstd concat) so the caller
    /// can free it.
    fn buildVariants(
        self: *Harness,
        codec: Codec,
        input: []const u8,
        level: u4,
        cases: *std.ArrayList(WireCase),
        source_owner: *std.ArrayList([]u8),
    ) !void {
        const a = self.allocator;
        switch (codec) {
            .raw, .zlib => if (self.deep and level != 0) {
                const dictionary = try self.buildDictionary();
                const wire = if (codec == .raw)
                    try vort.deflate.encodeRawLevelWithDictionaryAlloc(a, input, dictionary, level)
                else
                    try vort.encodeZlibLevelWithDictionaryAlloc(a, input, dictionary, level);
                try cases.append(a, .{
                    .label = "preset-dictionary",
                    .wire = wire,
                    .source = input,
                    .dictionary = dictionary,
                });
            },
            .gzip => {
                // Smoke covers one rich-header level; deep exercises every
                // level including the stored-block encoder.
                if (!self.deep and level != 6) return;
                const header = self.buildGzipHeaderOptions();
                defer self.freeGzipHeaderOptions(header);
                const wire = if (level == 0)
                    try vort.encodeGzipStoredWithHeaderAlloc(a, input, header)
                else
                    try vort.encodeGzipBestWithHeaderAlloc(
                        a,
                        input,
                        try vort.deflate.optionsForZlibLevel(level),
                        header,
                    );
                try cases.append(a, .{
                    .label = "rich-gzip-header",
                    .wire = wire,
                    .source = input,
                });
                // Deep-only two-member stream at one representative level;
                // each member carries an independent history and CRC.
                if (self.deep and level == 6) {
                    try self.buildGzipConcatVariant(input, cases, source_owner);
                }
            },
            .zstd => try self.buildZstdVariants(input, level, cases, source_owner),
            .br => try self.buildBrotliVariants(input, level, cases),
        }
    }

    fn buildGzipConcatVariant(
        self: *Harness,
        input: []const u8,
        cases: *std.ArrayList(WireCase),
        source_owner: *std.ArrayList([]u8),
    ) !void {
        const a = self.allocator;
        const first = try self.buildBaselineWire(.gzip, input, 6);
        errdefer a.free(first);
        const second = try self.buildBaselineWire(.gzip, input, 1);
        defer a.free(second);
        var joined: std.ArrayList(u8) = .empty;
        errdefer joined.deinit(a);
        try joined.appendSlice(a, first);
        try joined.appendSlice(a, second);

        const kept_source = try a.alloc(u8, input.len * 2);
        try source_owner.append(a, kept_source);
        @memcpy(kept_source[0..input.len], input);
        @memcpy(kept_source[input.len..], input);
        try cases.append(a, .{
            .label = "concatenated-gzip-members",
            .wire = try joined.toOwnedSlice(a),
            .source = kept_source,
            .gzip_multi_member = true,
        });
    }

    fn buildZstdVariants(
        self: *Harness,
        input: []const u8,
        level: u4,
        cases: *std.ArrayList(WireCase),
        source_owner: *std.ArrayList([]u8),
    ) !void {
        const a = self.allocator;
        // Checksum coverage at one level in smoke and every level in deep.
        if (self.deep or level == 3) {
            const checksum_wire = try vort.zstd.encodeFrameWithOptionsAlloc(a, input, .{
                .content_checksum = true,
            });
            try cases.append(a, .{
                .label = "content-checksum",
                .wire = checksum_wire,
                .source = input,
            });
        }
        if (!self.deep) return;
        // Unknown content size changes the frame header layout while keeping
        // the same block payload contract.
        const unsized_wire = try vort.zstd.encodeFrameWithOptionsAlloc(a, input, .{
            .include_content_size = false,
        });
        try cases.append(a, .{
            .label = "unknown-content-size",
            .wire = unsized_wire,
            .source = input,
        });
        // Raw-content dictionary frame: the dictionary is not declared in the
        // frame header, so both decoders must be handed the same bytes. The
        // reference rejects the wire without the dictionary, pinning the
        // dictionary contract rather than accidentally matching plain frames.
        {
            const dictionary = try self.buildDictionary();
            const dict_wire = try vort.zstd.encodeFrameWithDictionaryAlloc(
                a,
                input,
                vort.zstd.NativeDictionary.initRawContent(dictionary),
            );
            try cases.append(a, .{
                .label = "raw-content-dictionary",
                .wire = dict_wire,
                .source = input,
                .dictionary = dictionary,
            });
        }
        // Standard full dictionary trained from a deterministic corpus. The
        // frame header carries the Dictionary_ID, so the reference decoder can
        // select the dictionary from the handed bytes itself; without them it
        // rejects the frame with a dictionary mismatch. Training has a
        // quadratic substring scan, so it runs once per case at the
        // representative level and only on bounded inputs; larger inputs keep
        // every other variant without paying the training cost.
        if (level == 3 and input.len <= self.max_mutation_wire) {
            const trained = try self.buildStandardDictionaryCase(a, input, level, cases, source_owner);
            if (trained) |entry| {
                try cases.append(a, entry);
            }
        }

        // Structural variants use one representative level so the campaign
        // cost stays bounded.
        if (level != 3) return;
        // Magicless frame: Vort-native format with no standard magic number.
        // libzstd rejects it as an unknown frame descriptor, so this is a
        // Vort-to-Vort contract variant with its own truncation and mutation
        // rules.
        {
            const encoded = try vort.zstd.encodeNativeFrameWithOptionsAlloc(a, input, .{
                .format = .magicless,
            });
            try cases.append(a, .{
                .label = "magicless-frame",
                .wire = encoded.frame,
                .source = input,
                .zstd_magicless = true,
            });
        }
        // A small explicit Window_Log forces a non-single-segment frame with
        // a window descriptor once the content exceeds the window, exercising
        // cross-block history that single-segment frames never reach.
        const small_window = try vort.zstd.encodeFrameWithOptionsAlloc(a, input, .{
            .window_log = 10,
            .include_content_size = false,
        });
        try cases.append(a, .{
            .label = "explicit-window-log-10",
            .wire = small_window,
            .source = input,
        });
        const frame = try vort.zstd.encodeFrameWithLevelAlloc(a, input, 3);
        defer a.free(frame);
        const skip_payload = "vort skippable frame payload";
        const skip_id: u4 = 7;

        // Two concatenated data frames: expected output is the payload twice.
        {
            const joined_source = try a.alloc(u8, input.len * 2);
            defer a.free(joined_source);
            @memcpy(joined_source[0..input.len], input);
            @memcpy(joined_source[input.len..], input);
            const kept_source = try a.dupe(u8, joined_source);
            try source_owner.append(a, kept_source);
            const second = try vort.zstd.encodeFrameWithLevelAlloc(a, input, 1);
            defer a.free(second);
            var concat: std.ArrayList(u8) = .empty;
            errdefer concat.deinit(a);
            try concat.appendSlice(a, frame);
            try concat.appendSlice(a, second);
            try cases.append(a, .{
                .label = "concatenated-frames",
                .wire = try concat.toOwnedSlice(a),
                .source = kept_source,
                .zstd_stream_reference = true,
            });
        }

        // Leading skippable frame before the data frame.
        {
            var out: std.ArrayList(u8) = .empty;
            errdefer out.deinit(a);
            try vort.zstd.encodeSkippableFrameAppend(a, &out, skip_id, skip_payload);
            try out.appendSlice(a, frame);
            try cases.append(a, .{
                .label = "skippable-leading",
                .wire = try out.toOwnedSlice(a),
                .source = input,
                .zstd_stream_reference = true,
            });
        }

        // Trailing skippable frame after the data frame.
        {
            var out: std.ArrayList(u8) = .empty;
            errdefer out.deinit(a);
            try out.appendSlice(a, frame);
            try vort.zstd.encodeSkippableFrameAppend(a, &out, skip_id, skip_payload);
            try cases.append(a, .{
                .label = "skippable-trailing",
                .wire = try out.toOwnedSlice(a),
                .source = input,
                .zstd_stream_reference = true,
            });
        }

        // Skippable frame sandwiched between two data frames.
        {
            const joined_source = try a.alloc(u8, input.len * 2);
            defer a.free(joined_source);
            @memcpy(joined_source[0..input.len], input);
            @memcpy(joined_source[input.len..], input);
            const kept_source = try a.dupe(u8, joined_source);
            try source_owner.append(a, kept_source);
            const second = try vort.zstd.encodeFrameWithLevelAlloc(a, input, 1);
            defer a.free(second);
            var out: std.ArrayList(u8) = .empty;
            errdefer out.deinit(a);
            try out.appendSlice(a, frame);
            try vort.zstd.encodeSkippableFrameAppend(a, &out, skip_id, skip_payload);
            try out.appendSlice(a, second);
            try cases.append(a, .{
                .label = "skippable-between-frames",
                .wire = try out.toOwnedSlice(a),
                .source = kept_source,
                .zstd_stream_reference = true,
            });
        }
    }

    fn buildBrotliVariants(
        self: *Harness,
        input: []const u8,
        level: u4,
        cases: *std.ArrayList(WireCase),
    ) !void {
        const a = self.allocator;
        // Keep structural Brotli variants on the mid quality; smoke gets the
        // narrow window, deep gets the full standard-window range.
        if (level != 5) return;
        const widths: []const u5 = if (self.deep) &.{ 10, 16, 24 } else &.{10};
        for (widths) |window_bits| {
            const wire = try vort.br.encodePlannedStreamWithOptionsAlloc(a, input, .{
                .quality = level,
                .window_bits = window_bits,
            });
            try cases.append(a, .{
                .label = "explicit-window",
                .wire = wire,
                .source = input,
            });
        }
        if (self.deep) {
            // RAW shared-prefix dictionary. RFC 7932 makes the dictionary an
            // explicit decoder parameter: the same wire must fail without it
            // and reproduce the source with it, so this is a Vort-to-Vort
            // contract variant rather than a libbrotli interop one (the linked
            // libbrotli headers expose no attach-dictionary entry point). The
            // payload is built to overlap the dictionary so the encoder has a
            // real match to emit; a payload with no overlap would not need the
            // dictionary and decode without it.
            const br_dictionary = try self.buildDictionary();
            const br_payload = try a.alloc(u8, @max(br_dictionary.len * 3, 64));
            for (br_payload, 0..) |*byte, index| {
                byte.* = br_dictionary[index % br_dictionary.len];
            }
            const with_shared_dict = try vort.br.encodePlannedStreamWithOptionsAlloc(a, br_payload, .{
                .quality = level,
                .shared_dictionary = .{ .raw_prefixes = &.{br_dictionary} },
            });
            try cases.append(a, .{
                .label = "raw-shared-dictionary",
                .wire = with_shared_dict,
                .source = br_payload,
                .dictionary = br_dictionary,
                .brotli_shared_dictionary = true,
            });
            const no_context = try vort.br.encodePlannedStreamWithOptionsAlloc(a, input, .{
                .quality = level,
                .disable_literal_context_modeling = true,
            });
            try cases.append(a, .{
                .label = "no-literal-context-model",
                .wire = no_context,
                .source = input,
            });
            // A metadata meta-block is emitted before the payload and skipped
            // by every compliant decoder, so the decoded output must still
            // equal the source while the wire carries extra bytes.
            const with_metadata = try vort.br.encodePlannedStreamWithOptionsAlloc(a, input, .{
                .quality = level,
                .metadata = "vort brotli metadata meta-block probe",
            });
            try cases.append(a, .{
                .label = "metadata-meta-block",
                .wire = with_metadata,
                .source = input,
            });
            // The Large Window extension requires explicit decoder opt-in on
            // both sides; bound it to the HQ size limit to keep campaigns
            // tractable.
            if (input.len <= self.hq_br_limit) {
                const large = try vort.br.encodePlannedStreamWithOptionsAlloc(a, input, .{
                    .quality = level,
                    .window_bits = 30,
                    .large_window = true,
                });
                try cases.append(a, .{
                    .label = "large-window-30",
                    .wire = large,
                    .source = input,
                    .brotli_large_window = true,
                });
            }
        }
    }

    fn cutPositions(self: *Harness, len: usize) ![]usize {
        var cuts = std.ArrayList(usize).empty;
        defer cuts.deinit(self.allocator);
        if (len == 0) return try self.allocator.alloc(usize, 0);
        if (len <= 96) {
            var prefix: usize = 0;
            while (prefix < len) : (prefix += 1) try cuts.append(self.allocator, prefix);
            return self.allocator.dupe(usize, cuts.items);
        }
        var prefix: usize = 0;
        while (prefix < 10 and prefix < len) : (prefix += 1) {
            try cuts.append(self.allocator, prefix);
        }
        var shifted: usize = len;
        while (shifted > 10) {
            shifted >>= 1;
            if (shifted < len) try cuts.append(self.allocator, shifted);
        }
        var tail: usize = 1;
        while (tail <= 9 and tail < len) : (tail += 1) {
            try cuts.append(self.allocator, len - tail);
        }
        std.mem.sort(usize, cuts.items, {}, struct {
            fn lessThan(_: void, lhs: usize, rhs: usize) bool {
                return lhs < rhs;
            }
        }.lessThan);
        // The geometric and tail series overlap on small wires; dedupe after
        // sorting so every cut is exercised exactly once.
        var unique = std.ArrayList(usize).empty;
        defer unique.deinit(self.allocator);
        var previous: ?usize = null;
        for (cuts.items) |position| {
            if (previous == null or position != previous.?) {
                try unique.append(self.allocator, position);
                previous = position;
            }
        }
        return self.allocator.dupe(usize, unique.items);
    }

    fn checkWire(
        self: *Harness,
        codec: Codec,
        pattern: Pattern,
        wire_case: WireCase,
        level: u4,
    ) !void {
        const a = self.allocator;
        const input = wire_case.source;
        const wire = wire_case.wire;
        self.stats.wires += 1;
        if (!std.mem.eql(u8, wire_case.label, "baseline")) self.stats.variant_wires += 1;

        // 1. Vort one-shot round trip.
        {
            const decoded = self.vortDecode(codec, wire_case) orelse {
                try self.fail(codec, pattern, wire_case.label, input.len, wire.len, "vort-roundtrip", "level={d} rejected its own valid wire", .{level});
                return;
            };
            defer a.free(decoded);
            if (!std.mem.eql(u8, decoded, input)) {
                try self.fail(codec, pattern, wire_case.label, input.len, wire.len, "vort-roundtrip", "level={d} decoded {d} bytes, expected {d}", .{ level, decoded.len, input.len });
                return;
            }
            self.stats.vort_roundtrip_ok += 1;
        }

        // 2. Exact-size contract, including the zero-length destination case.
        {
            const exact = self.vortDecodeExact(codec, wire_case, input.len) orelse {
                try self.fail(codec, pattern, wire_case.label, input.len, wire.len, "vort-exact-size", "level={d} exact-size decode failed on a valid wire", .{level});
                return;
            };
            defer a.free(exact);
            if (!std.mem.eql(u8, exact, input)) {
                try self.fail(codec, pattern, wire_case.label, input.len, wire.len, "vort-exact-size", "level={d} exact-size output mismatch", .{level});
                return;
            }
            self.stats.exact_size_ok += 1;
        }

        // 3. System reference interop on the complete valid wire. Brotli
        //    shared-dictionary wires have no reference implementation in the
        //    installed libbrotli 1.0.9 (no AttachDictionary export), and
        //    magicless Zstd frames are rejected outright by libzstd as unknown
        //    frame descriptors; both rely on the two Vort decode contracts
        //    plus the no-reference rejection check below.
        if (!wire_case.brotli_shared_dictionary and !wire_case.zstd_magicless) {
            const reference = self.referenceDecode(codec, wire_case, input.len) orelse {
                self.stats.reference_rejected_valid += 1;
                try self.fail(codec, pattern, wire_case.label, input.len, wire.len, "reference-interop", "level={d} system reference rejected Vort wire", .{level});
                return;
            };
            defer a.free(reference);
            if (!std.mem.eql(u8, reference, input)) {
                try self.fail(codec, pattern, wire_case.label, input.len, wire.len, "reference-interop", "level={d} reference decoded {d} bytes, expected {d}", .{ level, reference.len, input.len });
                return;
            }
            self.stats.reference_ok += 1;
        } else if (wire_case.brotli_shared_dictionary) {
            // Without the attached prefix the wire must not decode: otherwise
            // the encoder emitted a stream that does not actually need the
            // advertised dictionary, weakening the contract variant.
            var no_dict_case = wire_case;
            no_dict_case.dictionary = null;
            no_dict_case.brotli_shared_dictionary = false;
            if (self.vortDecode(codec, no_dict_case)) |decoded| {
                a.free(decoded);
                try self.fail(codec, pattern, wire_case.label, input.len, wire.len, "reference-interop", "level={d} brotli wire decoded without its shared dictionary", .{level});
                return;
            }
            self.stats.reference_ok += 1;
        } else {
            // The standard-format decoder must not accept a magicless wire:
            // otherwise the format-specific opt-in would not be load-bearing.
            var standard_case = wire_case;
            standard_case.zstd_magicless = false;
            if (self.vortDecode(codec, standard_case)) |decoded| {
                a.free(decoded);
                try self.fail(codec, pattern, wire_case.label, input.len, wire.len, "reference-interop", "level={d} magicless wire decoded through the standard format", .{level});
                return;
            }
            self.stats.reference_ok += 1;
        }

        // 4. Truncation with cross-decoder agreement. Every prefix is fed to
        //    both Vort and the system reference. Both rejecting is the normal
        //    incomplete-stream outcome; both accepting must yield identical
        //    bytes (the zero-byte prefix is a valid empty stream for some
        //    codecs). A one-sided accept is a strictness or interop gap: a
        //    lenient Vort decode could publish data the reference refuses, or
        //    Vort could reject a stream the reference completes.
        const cuts = try self.cutPositions(wire.len);
        defer a.free(cuts);
        for (cuts) |cut| {
            var prefix_case = wire_case;
            prefix_case.wire = wire[0..cut];
            self.stats.truncation_cuts += 1;
            const vort_result = self.vortDecode(codec, prefix_case);
            defer if (vort_result) |decoded| a.free(decoded);
            // Vort-only variants (Brotli shared dictionary, magicless Zstd)
            // have no system reference; the truncation contract is that a
            // prefix can never decode further than the full wire and any
            // accepted prefix must reproduce the source prefix exactly.
            if (wire_case.brotli_shared_dictionary or wire_case.zstd_magicless) {
                if (vort_result) |decoded| {
                    if (decoded.len > input.len or !std.mem.eql(u8, decoded, input[0..decoded.len])) {
                        try self.fail(codec, pattern, wire_case.label, input.len, cut, "truncation", "prefix of {d} bytes: shared-dictionary decode output mismatch", .{cut});
                        return;
                    }
                    self.stats.truncation_agreed += 1;
                } else {
                    self.stats.truncation_both_rejected += 1;
                }
                continue;
            }
            const reference_result = self.referenceDecode(codec, prefix_case, input.len);
            defer if (reference_result) |decoded| a.free(decoded);
            if (vort_result == null and reference_result == null) {
                self.stats.truncation_both_rejected += 1;
                continue;
            }
            if (vort_result != null and reference_result != null) {
                if (!std.mem.eql(u8, vort_result.?, reference_result.?)) {
                    try self.fail(codec, pattern, wire_case.label, input.len, cut, "truncation", "prefix of {d} bytes: Vort/reference outputs differ ({d} vs {d} bytes)", .{ cut, vort_result.?.len, reference_result.?.len });
                    return;
                }
                self.stats.truncation_agreed += 1;
                continue;
            }
            try self.fail(codec, pattern, wire_case.label, input.len, cut, "truncation", "prefix of {d} bytes one-sided accept: vort={s} reference={s}", .{
                cut,
                if (vort_result != null) "accept" else "reject",
                if (reference_result != null) "accept" else "reject",
            });
            return;
        }

        try self.mutateWire(codec, pattern, wire_case);
    }

    /// Byte-level mutation matrix. Short wires get the full operator set
    /// (XOR, overwrite, insert, delete); long wires get sampled XOR positions
    /// so campaign cost stays linear rather than quadratic.
    fn mutateWire(
        self: *Harness,
        codec: Codec,
        pattern: Pattern,
        wire_case: WireCase,
    ) !void {
        const a = self.allocator;
        const input = wire_case.source;
        const wire = wire_case.wire;
        if (wire.len == 0) return;

        const positions = [_]usize{
            0,
            wire.len / 4,
            wire.len / 2,
            (wire.len * 3) / 4,
            wire.len - 1,
        };
        const masks = [_]u8{ 0x01, 0x80, 0xff };

        // XOR flips run at every wire length; the sampled five-position
        // schedule keeps the long-wire surface covered without exploding cost.
        for (positions) |position| {
            for (masks) |mask| {
                const mutated = try a.dupe(u8, wire);
                defer a.free(mutated);
                mutated[position] ^= mask;
                self.stats.mutations_xor += 1;
                try self.compareMutation(codec, pattern, wire_case, mutated, input.len, "xor");
            }
        }

        if (wire.len > self.max_mutation_wire) return;

        const overwrite_positions = [_]usize{ 0, wire.len / 2, wire.len - 1 };
        for (overwrite_positions) |position| {
            const values = [_]u8{ 0x00, 0xff, self.rng.byte() };
            for (values) |value| {
                const mutated = try a.dupe(u8, wire);
                defer a.free(mutated);
                mutated[position] = value;
                self.stats.mutations_overwrite += 1;
                try self.compareMutation(codec, pattern, wire_case, mutated, input.len, "overwrite");
            }
        }

        const insert_positions = [_]usize{ 0, wire.len / 2, wire.len };
        for (insert_positions) |position| {
            const mutated = try a.alloc(u8, wire.len + 1);
            defer a.free(mutated);
            @memcpy(mutated[0..position], wire[0..position]);
            mutated[position] = self.rng.byte();
            @memcpy(mutated[position + 1 ..], wire[position..]);
            self.stats.mutations_insert += 1;
            try self.compareMutation(codec, pattern, wire_case, mutated, input.len, "insert");
        }

        if (wire.len <= 1) return;
        const delete_positions = [_]usize{ 0, wire.len / 2, wire.len - 1 };
        for (delete_positions) |position| {
            const mutated = try a.alloc(u8, wire.len - 1);
            defer a.free(mutated);
            @memcpy(mutated[0..position], wire[0..position]);
            @memcpy(mutated[position..], wire[position + 1 ..]);
            self.stats.mutations_delete += 1;
            try self.compareMutation(codec, pattern, wire_case, mutated, input.len, "delete");
        }
    }

    fn compareMutation(
        self: *Harness,
        codec: Codec,
        pattern: Pattern,
        wire_case: WireCase,
        mutated: []u8,
        expected_len: usize,
        operator: []const u8,
    ) !void {
        const a = self.allocator;
        var mutated_case = wire_case;
        mutated_case.wire = mutated;
        const vort_result = self.vortDecode(codec, mutated_case);
        defer if (vort_result) |decoded| a.free(decoded);
        // Without a system reference, mutation evidence is the one-sided
        // divergence count: a corrupted shared-dictionary wire may still
        // decode because the attached prefix can legitimately supply some
        // corrupted sequences. Only a full-output mismatch is a real defect;
        // accepted mutations are recorded rather than failing the campaign.
        // Magicless frames use the same rule since libzstd cannot parse them.
        if (wire_case.brotli_shared_dictionary or wire_case.zstd_magicless) {
            if (vort_result) |decoded| {
                if (decoded.len != expected_len) {
                    try self.fail(codec, pattern, wire_case.label, expected_len, mutated.len, "mutation", "{s}: Vort-only decode changed output length", .{operator});
                    return;
                }
                if (!std.mem.eql(u8, decoded, wire_case.source)) {
                    self.stats.one_sided_divergence += 1;
                }
            } else {
                self.stats.mutation_rejected += 1;
            }
            return;
        }
        const reference_result = self.referenceDecode(codec, mutated_case, expected_len);
        defer if (reference_result) |decoded| a.free(decoded);
        if (vort_result == null) self.stats.mutation_rejected += 1;
        if (vort_result != null and reference_result != null) {
            if (!std.mem.eql(u8, vort_result.?, reference_result.?)) {
                try self.fail(codec, pattern, wire_case.label, expected_len, mutated.len, "mutation", "{s}: Vort and reference outputs differ ({d} vs {d} bytes)", .{ operator, vort_result.?.len, reference_result.?.len });
                return;
            }
        } else if (vort_result != null or reference_result != null) {
            self.stats.one_sided_divergence += 1;
        }
    }

    fn levelsFor(self: *Harness, codec: Codec, input_len: usize) []const u4 {
        return switch (codec) {
            .raw => &.{ 0, 1, 6, 9 },
            .zlib => &.{ 0, 6, 9 },
            .gzip => &.{ 0, 6, 9 },
            .zstd => &.{ 1, 3, 9 },
            .br => if (input_len <= self.hq_br_limit) &.{ 0, 5, 11 } else &.{ 0, 5 },
        };
    }

    fn runCase(self: *Harness, codec: Codec, pattern: Pattern, input: []const u8) !void {
        if (self.only != null and self.only.? != codec) return;
        const a = self.allocator;
        for (self.levelsFor(codec, input.len)) |level| {
            const baseline_wire = try self.buildBaselineWire(codec, input, level);
            defer a.free(baseline_wire);
            try self.checkWire(codec, pattern, .{
                .label = "baseline",
                .wire = baseline_wire,
                .source = input,
            }, level);

            var variant_cases: std.ArrayList(WireCase) = .empty;
            defer {
                for (variant_cases.items) |wire_case| {
                    a.free(wire_case.wire);
                    if (wire_case.dictionary) |dictionary| a.free(dictionary);
                    if (wire_case.standard_dictionary_bytes) |bytes| a.free(bytes);
                }
                variant_cases.deinit(a);
            }
            var source_owner: std.ArrayList([]u8) = .empty;
            defer {
                for (source_owner.items) |source| a.free(source);
                source_owner.deinit(a);
            }
            try self.buildVariants(codec, input, level, &variant_cases, &source_owner);
            for (variant_cases.items) |wire_case| {
                try self.checkWire(codec, pattern, wire_case, level);
            }
        }
    }
};

const smoke_sizes = [_]usize{
    0,    1,    2,    3,    4,    7,   8,   15,  16,  31,
    32,   63,   64,   127,  128,  255, 256, 511, 512, 1023,
    1024, 4095, 4096, 8191, 8192,
};

const deep_extra_sizes = [_]usize{ 16383, 16384, 32767, 32768, 65535, 65536 };

/// Deep campaigns add RNG-driven sizes between the fixed boundary schedule so
/// non-boundary lengths and odd block transitions get coverage too.
const random_size_count = 8;

const patterns = [_]Pattern{
    .rle_zero,
    .rle_ff,
    .periodic2,
    .periodic16,
    .random,
    .text,
    .mixed,
    .sparse_binary,
};

const codecs = [_]Codec{ .raw, .zlib, .gzip, .zstd, .br };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var seed: u64 = 0x766f72742d667a7a;
    var only: ?Codec = null;
    var deep = false;
    var max_size: usize = 8192;
    while (args.next()) |arg| {
        if (std.mem.startsWith(u8, arg, "--seed=")) {
            seed = try std.fmt.parseInt(u64, arg["--seed=".len..], 0);
        } else if (std.mem.eql(u8, arg, "--deep")) {
            deep = true;
            max_size = 65536;
        } else if (std.mem.startsWith(u8, arg, "--max-size=")) {
            max_size = try std.fmt.parseInt(usize, arg["--max-size=".len..], 0);
        } else if (std.mem.startsWith(u8, arg, "--only=")) {
            const name = arg["--only=".len..];
            inline for (codecs) |codec| {
                if (std.mem.eql(u8, name, codec.label())) only = codec;
            }
            if (only == null) return error.UnknownCodecFilter;
        } else if (std.mem.eql(u8, arg, "--help")) {
            try printUsage(init);
            return;
        } else {
            return error.UnknownArgument;
        }
    }

    // The C reference libraries allocate through libc; use the same allocator
    // so cross-allocator ownership never enters the comparison.
    const allocator = std.heap.c_allocator;
    var harness = Harness{
        .allocator = allocator,
        .rng = .{ .state = seed },
        .failures = .empty,
        .only = only,
        .deep = deep,
    };
    defer {
        for (harness.failures.items) |failure| allocator.free(failure.detail);
        harness.failures.deinit(allocator);
    }

    const input = try allocator.alloc(u8, max_size);
    defer allocator.free(input);

    for (patterns) |pattern| {
        for (smoke_sizes) |size| {
            if (size > max_size) continue;
            try runPatternCase(&harness, pattern, size, seed, input);
        }
        if (deep) {
            for (deep_extra_sizes) |size| {
                if (size > max_size) continue;
                try runPatternCase(&harness, pattern, size, seed, input);
            }
            // Independent RNG stream per pattern keeps random-size draws
            // stable regardless of which fixed sizes were filtered out.
            var size_rng = Rng{ .state = seed ^ (@as(u64, @intFromEnum(pattern)) *% 0x9e3779b97f4a7c15 +% 0xdeadbeef) };
            var draw: usize = 0;
            while (draw < random_size_count) : (draw += 1) {
                const size = size_rng.bounded(max_size + 1);
                try runPatternCase(&harness, pattern, size, seed, input);
            }
        }
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        \\codec differential fuzz: seed={d} deep={} only={s}
        \\  valid wires={d} (variants={d}) vort_roundtrip={d} exact_size={d} reference_interop={d}
        \\  truncation cuts={d} (both_rejected={d} agreed_accept={d})
        \\  mutations xor={d} overwrite={d} insert={d} delete={d} (rejected={d} one_sided_divergence={d})
        \\
    , .{
        seed,
        deep,
        if (only) |codec| codec.label() else "all",
        harness.stats.wires,
        harness.stats.variant_wires,
        harness.stats.vort_roundtrip_ok,
        harness.stats.exact_size_ok,
        harness.stats.reference_ok,
        harness.stats.truncation_cuts,
        harness.stats.truncation_both_rejected,
        harness.stats.truncation_agreed,
        harness.stats.mutations_xor,
        harness.stats.mutations_overwrite,
        harness.stats.mutations_insert,
        harness.stats.mutations_delete,
        harness.stats.mutation_rejected,
        harness.stats.one_sided_divergence,
    });
    for (harness.failures.items) |failure| {
        try stdout.print("FAIL [{s}] pattern={s} variant={s} input={d} wire={d} stage={s}: {s}\n", .{
            failure.codec.label(),
            failure.pattern.label(),
            failure.variant,
            failure.input_len,
            failure.wire_len,
            failure.stage,
            failure.detail,
        });
    }
    try stdout.flush();
    if (harness.failures.items.len != 0) return error.FuzzMismatch;
}

fn runPatternCase(harness: *Harness, pattern: Pattern, size: usize, seed: u64, input: []u8) !void {
    const slice = input[0..size];
    harness.rng = .{ .state = seed ^ (@as(u64, size) *% 0x9e3779b97f4a7c15 +% @intFromEnum(pattern)) };
    harness.writePattern(pattern, slice);
    for (codecs) |codec| try harness.runCase(codec, pattern, slice);
}

fn printUsage(init: std.process.Init) !void {
    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        \\Usage: vort-codec-differential-fuzz [--seed=N] [--deep] [--max-size=N]
        \\                                   [--only=raw-deflate|zlib|gzip|zstd|brotli]
        \\
    , .{});
    try stdout.flush();
}
