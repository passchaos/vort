//! Structure-aware differential fuzzing for the common compression codecs.
//!
//! The deterministic generator builds valid Vort wires for raw Deflate, zlib,
//! gzip, standard Zstd and RFC Brotli across content patterns and boundary
//! sizes. Every valid wire is checked three ways:
//!
//!   1. Vort one-shot and exact-size decode reproduces the source exactly.
//!   2. The installed system reference libraries (zlib, libzstd, libbrotli)
//!      accept the same wire and reproduce the source exactly. This is direct
//!      wire-interoperability evidence rather than an internal oracle.
//!   3. Systematic truncation and single-byte mutation never produce a
//!      successful decode whose output disagrees with the reference decoder.
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

const Stats = struct {
    wires: u64 = 0,
    vort_roundtrip_ok: u64 = 0,
    exact_size_ok: u64 = 0,
    reference_ok: u64 = 0,
    reference_rejected_valid: u64 = 0,
    truncation_cuts: u64 = 0,
    truncation_both_rejected: u64 = 0,
    truncation_agreed: u64 = 0,
    mutations: u64 = 0,
    mutation_rejected: u64 = 0,
    one_sided_divergence: u64 = 0,
};

const Failure = struct {
    codec: Codec,
    pattern: Pattern,
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
    max_mutation_wire: usize = 2048,
    hq_br_limit: usize = 1024,

    fn fail(
        self: *Harness,
        codec: Codec,
        pattern: Pattern,
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

    fn vortDecode(self: *Harness, codec: Codec, wire: []const u8) ?[]u8 {
        const a = self.allocator;
        const decoded = switch (codec) {
            .raw => vort.decodeRawDeflateAlloc(a, wire) catch return null,
            .zlib, .gzip => vort.decodeZlibOrGzipAlloc(a, wire) catch return null,
            .zstd => vort.zstd.decodeFrameAlloc(a, wire) catch return null,
            .br => vort.br.decodeStreamAlloc(a, wire) catch return null,
        };
        return decoded;
    }

    fn vortDecodeExact(self: *Harness, codec: Codec, wire: []const u8, expected: usize) ?[]u8 {
        const a = self.allocator;
        return switch (codec) {
            .raw => vort.decodeRawDeflateAllocExactSize(a, wire, expected) catch return null,
            .zlib, .gzip => vort.decodeZlibOrGzipAllocExactSize(a, wire, expected) catch return null,
            .zstd => vort.zstd.decodeFrameAllocExactSize(a, wire, expected) catch return null,
            .br => vort.br.decodeStreamAllocExactSize(a, wire, expected) catch return null,
        };
    }

    fn referenceDecode(self: *Harness, codec: Codec, wire: []const u8, capacity: usize) ?[]u8 {
        const a = self.allocator;
        // One byte of slack keeps zero-length outputs addressable and lets
        // overrun-prone implementations fail loudly instead of aliasing. The
        // 4x headroom tolerates RLE-style expansion in mutated wires while a
        // fixed ceiling bounds every reference allocation.
        const target_cap = @min(@max(capacity *% 4, 4096), 1 << 20);
        const dst = a.alloc(u8, target_cap + 1) catch return null;
        errdefer a.free(dst);
        switch (codec) {
            .raw => return zlibInflate(a, dst, wire, -15),
            .zlib => return zlibInflate(a, dst, wire, 15),
            .gzip => return zlibInflate(a, dst, wire, 31),
            .zstd => {
                const result = c.ZSTD_decompress(dst.ptr, dst.len, wire.ptr, wire.len);
                if (c.ZSTD_isError(result) != 0) {
                    a.free(dst);
                    return null;
                }
                return a.realloc(dst, result) catch dst[0..result];
            },
            .br => {
                var decoded_size: usize = dst.len;
                const result = c.BrotliDecoderDecompress(
                    wire.len,
                    wire.ptr,
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
    ) ?[]u8 {
        var stream: c.z_stream = std.mem.zeroes(c.z_stream);
        if (c.inflateInit2(&stream, window_bits) != c.Z_OK) {
            a.free(dst);
            return null;
        }
        stream.next_in = @constCast(wire.ptr);
        stream.avail_in = @intCast(wire.len);
        stream.next_out = dst.ptr;
        stream.avail_out = @intCast(dst.len);
        const code = c.inflate(&stream, c.Z_FINISH);
        _ = c.inflateEnd(&stream);
        if (code != c.Z_STREAM_END) {
            a.free(dst);
            return null;
        }
        const written = dst.len - stream.avail_out;
        return a.realloc(dst, written) catch dst[0..written];
    }

    fn buildWire(self: *Harness, codec: Codec, input: []const u8, level: u4) ![]u8 {
        const a = self.allocator;
        switch (codec) {
            .raw => return try vort.deflate.encodeRawLevelAlloc(a, input, level),
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
        input: []const u8,
        wire: []u8,
        level: u4,
    ) !void {
        const a = self.allocator;
        self.stats.wires += 1;

        // 1. Vort one-shot round trip.
        {
            const decoded = self.vortDecode(codec, wire) orelse {
                try self.fail(codec, pattern, input.len, wire.len, "vort-roundtrip", "level={d} rejected its own valid wire", .{level});
                return;
            };
            defer a.free(decoded);
            if (!std.mem.eql(u8, decoded, input)) {
                try self.fail(codec, pattern, input.len, wire.len, "vort-roundtrip", "level={d} decoded {d} bytes, expected {d}", .{ level, decoded.len, input.len });
                return;
            }
            self.stats.vort_roundtrip_ok += 1;
        }

        // 2. Exact-size contract, including the zero-length destination case.
        {
            const exact = self.vortDecodeExact(codec, wire, input.len) orelse {
                try self.fail(codec, pattern, input.len, wire.len, "vort-exact-size", "level={d} exact-size decode failed on a valid wire", .{level});
                return;
            };
            defer a.free(exact);
            if (!std.mem.eql(u8, exact, input)) {
                try self.fail(codec, pattern, input.len, wire.len, "vort-exact-size", "level={d} exact-size output mismatch", .{level});
                return;
            }
            self.stats.exact_size_ok += 1;
        }

        // 3. System reference interop on the complete valid wire.
        {
            const reference = self.referenceDecode(codec, wire, input.len) orelse {
                self.stats.reference_rejected_valid += 1;
                try self.fail(codec, pattern, input.len, wire.len, "reference-interop", "level={d} system reference rejected Vort wire", .{level});
                return;
            };
            defer a.free(reference);
            if (!std.mem.eql(u8, reference, input)) {
                try self.fail(codec, pattern, input.len, wire.len, "reference-interop", "level={d} reference decoded {d} bytes, expected {d}", .{ level, reference.len, input.len });
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
            const prefix = wire[0..cut];
            self.stats.truncation_cuts += 1;
            const vort_result = self.vortDecode(codec, prefix);
            const reference_result = self.referenceDecode(codec, prefix, input.len);
            defer if (vort_result) |decoded| a.free(decoded);
            defer if (reference_result) |decoded| a.free(decoded);
            if (vort_result == null and reference_result == null) {
                self.stats.truncation_both_rejected += 1;
                continue;
            }
            if (vort_result != null and reference_result != null) {
                if (!std.mem.eql(u8, vort_result.?, reference_result.?)) {
                    try self.fail(codec, pattern, input.len, cut, "truncation", "prefix of {d} bytes: Vort/reference outputs differ ({d} vs {d} bytes)", .{ cut, vort_result.?.len, reference_result.?.len });
                    return;
                }
                self.stats.truncation_agreed += 1;
                continue;
            }
            try self.fail(codec, pattern, input.len, cut, "truncation", "prefix of {d} bytes one-sided accept: vort={s} reference={s}", .{
                cut,
                if (vort_result != null) "accept" else "reject",
                if (reference_result != null) "accept" else "reject",
            });
            return;
        }

        // 5. Single-byte mutations: when Vort and the reference both accept,
        //    their decoded outputs must agree. One-sided acceptance is counted
        //    as divergence evidence but not treated as a contract violation.
        if (wire.len <= self.max_mutation_wire and wire.len > 0) {
            const positions = [_]usize{
                0,
                wire.len / 4,
                wire.len / 2,
                (wire.len * 3) / 4,
                wire.len - 1,
            };
            const masks = [_]u8{ 0x01, 0x80, 0xff };
            for (positions) |position| {
                for (masks) |mask| {
                    const mutated = try a.dupe(u8, wire);
                    defer a.free(mutated);
                    mutated[position] ^= mask;
                    self.stats.mutations += 1;
                    const vort_result = self.vortDecode(codec, mutated);
                    const reference_result = self.referenceDecode(codec, mutated, input.len);
                    defer if (vort_result) |decoded| a.free(decoded);
                    defer if (reference_result) |decoded| a.free(decoded);
                    if (vort_result == null) self.stats.mutation_rejected += 1;
                    if (vort_result != null and reference_result != null) {
                        if (!std.mem.eql(u8, vort_result.?, reference_result.?)) {
                            try self.fail(codec, pattern, input.len, wire.len, "mutation", "position={d} mask=0x{x:0>2}: Vort and reference outputs differ ({d} vs {d} bytes)", .{ position, mask, vort_result.?.len, reference_result.?.len });
                            return;
                        }
                    } else if (vort_result != null or reference_result != null) {
                        self.stats.one_sided_divergence += 1;
                    }
                }
            }
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
        for (self.levelsFor(codec, input.len)) |level| {
            const wire = try self.buildWire(codec, input, level);
            defer self.allocator.free(wire);
            try self.checkWire(codec, pattern, input, wire, level);
        }
    }
};

const smoke_sizes = [_]usize{
    0,    1,    2,    3,    4,    7,   8,   15,  16,  31,
    32,   63,   64,   127,  128,  255, 256, 511, 512, 1023,
    1024, 4095, 4096, 8191, 8192,
};

const deep_extra_sizes = [_]usize{ 16383, 16384, 32767, 32768, 65535, 65536 };

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
            const slice = input[0..size];
            harness.rng = .{ .state = seed ^ (@as(u64, size) *% 0x9e3779b97f4a7c15 +% @intFromEnum(pattern)) };
            harness.writePattern(pattern, slice);
            for (codecs) |codec| try harness.runCase(codec, pattern, slice);
        }
        if (deep) {
            for (deep_extra_sizes) |size| {
                if (size > max_size) continue;
                const slice = input[0..size];
                harness.rng = .{ .state = seed ^ (@as(u64, size) *% 0x9e3779b97f4a7c15 +% @intFromEnum(pattern)) };
                harness.writePattern(pattern, slice);
                for (codecs) |codec| try harness.runCase(codec, pattern, slice);
            }
        }
    }

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        \\codec differential fuzz: seed={d} deep={} only={s}
        \\  valid wires={d} vort_roundtrip={d} exact_size={d} reference_interop={d}
        \\  truncation cuts={d} (both_rejected={d} agreed_accept={d})
        \\  mutations={d} (rejected={d} one_sided_divergence={d})
        \\
    , .{
        seed,
        deep,
        if (only) |codec| codec.label() else "all",
        harness.stats.wires,
        harness.stats.vort_roundtrip_ok,
        harness.stats.exact_size_ok,
        harness.stats.reference_ok,
        harness.stats.truncation_cuts,
        harness.stats.truncation_both_rejected,
        harness.stats.truncation_agreed,
        harness.stats.mutations,
        harness.stats.mutation_rejected,
        harness.stats.one_sided_divergence,
    });
    for (harness.failures.items) |failure| {
        try stdout.print("FAIL [{s}] pattern={s} input={d} wire={d} stage={s}: {s}\n", .{
            failure.codec.label(),
            failure.pattern.label(),
            failure.input_len,
            failure.wire_len,
            failure.stage,
            failure.detail,
        });
    }
    try stdout.flush();
    if (harness.failures.items.len != 0) return error.FuzzMismatch;
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
