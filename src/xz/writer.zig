const std = @import("std");
const builtin = @import("builtin");
const container = @import("container.zig");
const filters = @import("filters.zig");
const lzma_encoder = @import("../lzma/encoder.zig");
const lzma2_writer = @import("lzma2_writer.zig");
const parallel_types = @import("parallel/types.zig");
const parallel_stream = @import("parallel/stream.zig");

pub const Error = container.Error || lzma_encoder.Error || std.Thread.SpawnError;
pub const Check = container.Check;
pub const Filter = filters.Filter;
pub const Parser = lzma2_writer.Parser;
pub const Properties = lzma2_writer.Properties;
pub const MatchOptions = lzma2_writer.MatchOptions;
const encode_settings = @import("../lzma/encode_options.zig");

const lazy_text_section = switch (builtin.object_format) {
    .elf => ".vort_xz_lazy",
    .macho => "__TEXT,__vort_xz_lazy",
    .coff => ".text$vort_xz_lazy",
    else => ".text",
};

pub const EncodeOptions = struct {
    check: Check = .crc64,
    block_size: usize = 1024 * 1024,
    dictionary_size: usize = lzma2_writer.dictionary_size,
    chunk_size: usize = lzma2_writer.max_stored_chunk_len,
    filters: []const Filter = &.{},
    parser: Parser = .greedy,
    properties: Properties = .{},
    match_options: ?MatchOptions = null,
    /// Null preserves the serial writer. Parallel mode borrows the caller's
    /// I/O implementation for blocking worker coordination.
    parallel: ?parallel_types.Options = null,

    pub fn fromPreset(level: u32, extreme: bool) Error!EncodeOptions {
        const preset = try encode_settings.resolvePreset(level, extreme);
        return .{ .dictionary_size = preset.dictionary_size, .parser = preset.mode, .properties = preset.properties, .match_options = preset.match_options };
    }
    pub fn validate(self: EncodeOptions) Error!void {
        try validateOptions(self);
    }
    pub fn recordEffectiveSettings(self: EncodeOptions) void {
        if (self.match_options) |options| options.recordEffectiveSettings();
    }
    pub fn lzma2Options(self: EncodeOptions) lzma2_writer.EncodeOptions {
        return .{ .dictionary_size = self.dictionary_size, .chunk_size = self.chunk_size, .parser = self.parser, .properties = self.properties, .match_options = self.match_options };
    }
};

const stream_magic = [_]u8{ 0xfd, '7', 'z', 'X', 'Z', 0x00 };
const stream_footer_magic = [_]u8{ 'Y', 'Z' };
const max_vli: u64 = (@as(u64, 1) << 63) - 1;

pub const BlockRecord = struct {
    unpadded_size: u64,
    uncompressed_size: u64,
};

pub const PayloadEncoding = enum { stored, compressed };

pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8, options: EncodeOptions) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeLazyAlloc(allocator: std.mem.Allocator, input: []const u8, options: EncodeOptions) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeLazyAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeLazyInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) !usize {
    if (options.parallel) |parallel| {
        var forced = options;
        forced.parser = .lazy;
        try validateOptions(forced);
        forced.recordEffectiveSettings();
        return parallel_stream.encodeInto(allocator, output, input, forced, .compressed, parallel);
    }
    const encoded = try encodeLazyAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodeLazyAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    return encodeLazyWithPayload(allocator, out, input, options);
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) !usize {
    if (options.parallel) |parallel| {
        try validateOptions(options);
        options.recordEffectiveSettings();
        return parallel_stream.encodeInto(allocator, output, input, options, .compressed, parallel);
    }
    const encoded = try encodeAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    return encodeWithPayload(allocator, out, input, options, .compressed);
}

pub fn encodeStoredAlloc(allocator: std.mem.Allocator, input: []const u8, options: EncodeOptions) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeStoredAppend(allocator, &output, input, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeStoredInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    options: EncodeOptions,
) !usize {
    if (options.parallel) |parallel| {
        try validateOptions(options);
        options.recordEffectiveSettings();
        return parallel_stream.encodeInto(allocator, output, input, options, .stored, parallel);
    }
    const encoded = try encodeStoredAlloc(allocator, input, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

/// Append a deterministic XZ stream without changing `out.items` on error.
pub fn encodeStoredAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) !usize {
    return encodeWithPayload(allocator, out, input, options, .stored);
}

fn encodeWithPayload(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
    payload_encoding: PayloadEncoding,
) !usize {
    try validateOptions(options);
    options.recordEffectiveSettings();
    if (options.parallel) |parallel|
        return parallel_stream.encodeAppend(allocator, out, input, options, payload_encoding, parallel);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try appendStreamHeader(allocator, &encoded, options.check);

    var records: std.ArrayList(BlockRecord) = .empty;
    defer records.deinit(allocator);
    var input_offset: usize = 0;
    while (input_offset < input.len) {
        const block_len = @min(options.block_size, input.len - input_offset);
        const block = input[input_offset..][0..block_len];
        try records.append(
            allocator,
            try appendBlock(allocator, &encoded, block, options, payload_encoding),
        );
        input_offset += block_len;
    }

    try appendStreamEnd(allocator, &encoded, options.check, records.items);

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

noinline fn encodeLazyWithPayload(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) linksection(lazy_text_section) !usize {
    var forced = options;
    forced.parser = .lazy;
    return encodeWithPayload(allocator, out, input, forced, .compressed);
}

pub fn validateOptions(options: EncodeOptions) Error!void {
    if (options.block_size == 0) return error.InvalidBlockPlan;
    _ = try lzma2_writer.dictionaryProperty(options.dictionary_size);
    try options.lzma2Options().validate();
    try filters.validateChain(options.filters);
    _ = try checkSize(options.check);
    if (options.parallel) |parallel| try parallel.validate();
}

pub fn appendStreamHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    check: Check,
) !void {
    _ = try checkSize(check);
    try output.ensureUnusedCapacity(allocator, 12);
    output.appendSliceAssumeCapacity(&stream_magic);
    const stream_flags = [_]u8{ 0, @intFromEnum(check) };
    try output.appendSlice(allocator, &stream_flags);
    try appendU32(allocator, output, std.hash.Crc32.hash(&stream_flags));
}

pub fn appendBlock(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
    payload_encoding: PayloadEncoding,
) !BlockRecord {
    try validateOptions(options);
    options.recordEffectiveSettings();
    const original_len = output.items.len;
    errdefer output.shrinkRetainingCapacity(original_len);
    if (input.len == 0 or input.len > options.block_size) return error.InvalidBlockPlan;
    try filters.validateChain(options.filters);
    const dictionary_property = try lzma2_writer.dictionaryProperty(options.dictionary_size);
    const check_size = try checkSize(options.check);
    const block_start = output.items.len;
    const header_size = try appendBlockHeader(
        allocator,
        output,
        options.filters,
        dictionary_property,
    );
    var filtered_storage: ?[]u8 = null;
    defer if (filtered_storage) |bytes| allocator.free(bytes);
    const filtered = if (options.filters.len == 0)
        input
    else blk: {
        const bytes = try allocator.dupe(u8, input);
        filtered_storage = bytes;
        filters.encodeChain(bytes, options.filters);
        break :blk bytes;
    };
    const packed_size = switch (payload_encoding) {
        .stored => try lzma2_writer.appendStoredPayload(allocator, output, filtered),
        .compressed => try lzma2_writer.appendCompressedPayloadWithAdvancedOptions(
            allocator,
            output,
            filtered,
            options.lzma2Options(),
        ),
    };
    const padding_len = (4 - ((header_size + packed_size) % 4)) % 4;
    try output.appendNTimes(allocator, 0, padding_len);
    try appendCheck(allocator, output, options.check, input);
    const unpadded_size = std.math.add(
        u64,
        @as(u64, @intCast(header_size + packed_size)),
        check_size,
    ) catch return error.IntegerOverflow;
    std.debug.assert(output.items.len > block_start);
    return .{
        .unpadded_size = unpadded_size,
        .uncompressed_size = try usizeToVli(input.len),
    };
}

pub noinline fn appendBlockLazy(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    options: EncodeOptions,
) linksection(lazy_text_section) !BlockRecord {
    var forced = options;
    forced.parser = .lazy;
    return appendBlock(allocator, output, input, forced, .compressed);
}

pub fn appendStreamEnd(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    check: Check,
    records: []const BlockRecord,
) !void {
    const original_len = output.items.len;
    errdefer output.shrinkRetainingCapacity(original_len);
    _ = try checkSize(check);
    const index_start = output.items.len;
    try output.append(allocator, 0);
    try appendVli(allocator, output, try usizeToVli(records.len));
    for (records) |record| {
        try appendVli(allocator, output, record.unpadded_size);
        try appendVli(allocator, output, record.uncompressed_size);
    }
    while ((output.items.len - index_start) % 4 != 0) try output.append(allocator, 0);
    try appendU32(allocator, output, std.hash.Crc32.hash(output.items[index_start..]));
    const index_size = output.items.len - index_start;
    if (index_size % 4 != 0 or index_size / 4 == 0 or index_size / 4 - 1 > std.math.maxInt(u32))
        return error.IntegerOverflow;

    const stream_flags = [_]u8{ 0, @intFromEnum(check) };
    var footer_fields: [6]u8 = undefined;
    std.mem.writeInt(u32, footer_fields[0..4], @intCast(index_size / 4 - 1), .little);
    @memcpy(footer_fields[4..6], &stream_flags);
    try appendU32(allocator, output, std.hash.Crc32.hash(&footer_fields));
    try output.appendSlice(allocator, &footer_fields);
    try output.appendSlice(allocator, &stream_footer_magic);
}

fn appendBlockHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    filter_chain: []const Filter,
    dictionary_property: u8,
) !usize {
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(allocator);
    try header.append(allocator, 0);
    try header.append(allocator, @intCast(filter_chain.len));
    for (filter_chain) |filter| {
        try appendVli(allocator, &header, filters.id(filter));
        const properties_len = filters.propertiesSize(filter);
        try appendVli(allocator, &header, properties_len);
        if (properties_len != 0) {
            var properties: [4]u8 = undefined;
            filters.writeProperties(filter, properties[0..properties_len]);
            try header.appendSlice(allocator, properties[0..properties_len]);
        }
    }
    try appendVli(allocator, &header, 0x21);
    try appendVli(allocator, &header, 1);
    try header.append(allocator, dictionary_property);
    while (header.items.len % 4 != 0) try header.append(allocator, 0);
    if (header.items.len / 4 > std.math.maxInt(u8)) return error.IntegerOverflow;
    header.items[0] = @intCast(header.items.len / 4);
    try output.appendSlice(allocator, header.items);
    try appendU32(allocator, output, std.hash.Crc32.hash(header.items));
    return header.items.len + 4;
}

fn appendCheck(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    check: Check,
    input: []const u8,
) !void {
    switch (check) {
        .none => {},
        .crc32 => try appendU32(allocator, output, std.hash.Crc32.hash(input)),
        .crc64 => try appendU64(allocator, output, std.hash.crc.Crc64Xz.hash(input)),
        .sha256 => {
            var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
            std.crypto.hash.sha2.Sha256.hash(input, &digest, .{});
            try output.appendSlice(allocator, &digest);
        },
        else => return error.UnsupportedXzFeature,
    }
}

fn checkSize(check: Check) Error!u64 {
    return switch (check) {
        .none => 0,
        .crc32 => 4,
        .crc64 => 8,
        .sha256 => std.crypto.hash.sha2.Sha256.digest_length,
        else => error.UnsupportedXzFeature,
    };
}

fn appendVli(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value_arg: u64) !void {
    if (value_arg > max_vli) return error.IntegerOverflow;
    var value = value_arg;
    while (value >= 0x80) {
        try output.append(allocator, @as(u8, @truncate(value)) | 0x80);
        value >>= 7;
    }
    try output.append(allocator, @truncate(value));
}

fn usizeToVli(value: usize) Error!u64 {
    const converted = std.math.cast(u64, value) orelse return error.IntegerOverflow;
    if (converted > max_vli) return error.IntegerOverflow;
    return converted;
}

fn appendU32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendU64(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u64) !void {
    var bytes: [8]u8 = undefined;
    std.mem.writeInt(u64, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test "XZ stored writer round trips checks and multiple blocks" {
    const allocator = std.testing.allocator;
    const input = "XZ uncompressed LZMA2 chunks " ** 300;
    inline for (.{ Check.none, Check.crc32, Check.crc64, Check.sha256 }) |check| {
        const encoded = try encodeStoredAlloc(allocator, input, .{ .check = check, .block_size = 1024 });
        defer allocator.free(encoded);
        const decoded = try container.decodeAlloc(allocator, encoded);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        const info = try container.inspect(allocator, encoded);
        try std.testing.expectEqual(check, info.check);
        try std.testing.expectEqual(@as(usize, (input.len + 1023) / 1024), info.block_count);
        try std.testing.expectEqual(@as(u64, 4096), info.max_dictionary_size);
    }
}

test "XZ compressed writer selects match coding and round trips filters" {
    const allocator = std.testing.allocator;
    const input = "XZ literal-coded LZMA2 payload\n" ** 512;
    const chain = [_]Filter{ Filter.x86(0), try Filter.delta(4) };
    const encoded = try encodeAlloc(allocator, input, .{
        .check = .crc32,
        .block_size = 8192,
        .dictionary_size = 128 * 1024,
        .filters = &chain,
    });
    defer allocator.free(encoded);
    try std.testing.expect(encoded.len < input.len);
    const repeated = try encodeAlloc(allocator, input, .{
        .check = .crc32,
        .block_size = 8192,
        .dictionary_size = 128 * 1024,
        .filters = &chain,
    });
    defer allocator.free(repeated);
    try std.testing.expectEqualSlices(u8, encoded, repeated);
    const decoded = try container.decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    const lazy = try encodeLazyAlloc(allocator, input, .{
        .check = .crc32,
        .block_size = 8192,
        .dictionary_size = 128 * 1024,
        .filters = &chain,
    });
    defer allocator.free(lazy);
    try std.testing.expect(lazy.len <= encoded.len);
    const lazy_decoded = try container.decodeAlloc(allocator, lazy);
    defer allocator.free(lazy_decoded);
    try std.testing.expectEqualSlices(u8, input, lazy_decoded);
    const info = try container.inspect(allocator, encoded);
    try std.testing.expectEqual(@as(u64, 128 * 1024), info.max_dictionary_size);

    const output = try allocator.alloc(u8, encoded.len);
    defer allocator.free(output);
    try std.testing.expectEqual(encoded.len, try encodeInto(allocator, input, output, .{
        .check = .crc32,
        .block_size = 8192,
        .dictionary_size = 128 * 1024,
        .filters = &chain,
    }));
    try std.testing.expectEqualSlices(u8, encoded, output);

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const prefix_len = appended.items.len;
    try std.testing.expectEqual(encoded.len, try encodeAppend(allocator, &appended, input, .{
        .check = .crc32,
        .block_size = 8192,
        .dictionary_size = 128 * 1024,
        .filters = &chain,
    }));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0..prefix_len]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[prefix_len..]);
}

test "XZ stored writer caller-owned and append APIs are transactional" {
    const allocator = std.testing.allocator;
    const input = "transactional XZ output";
    const encoded = try encodeStoredAlloc(allocator, input, .{});
    defer allocator.free(encoded);

    const output = try allocator.alloc(u8, encoded.len);
    defer allocator.free(output);
    try std.testing.expectEqual(encoded.len, try encodeStoredInto(allocator, input, output, .{}));
    try std.testing.expectEqualSlices(u8, encoded, output);
    try std.testing.expectError(error.OutputTooSmall, encodeStoredInto(allocator, input, output[0 .. output.len - 1], .{}));

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(allocator);
    try appended.appendSlice(allocator, "prefix:");
    const prefix_len = appended.items.len;
    try std.testing.expectEqual(encoded.len, try encodeStoredAppend(allocator, &appended, input, .{}));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0..prefix_len]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[prefix_len..]);

    const before = try allocator.dupe(u8, appended.items);
    defer allocator.free(before);
    try std.testing.expectError(
        error.InvalidBlockPlan,
        encodeStoredAppend(allocator, &appended, input, .{ .block_size = 0 }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
    try std.testing.expectError(
        error.InvalidBlockPlan,
        encodeStoredAppend(allocator, &appended, input, .{ .dictionary_size = 4095 }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
    try std.testing.expectError(
        error.InvalidBlockPlan,
        encodeStoredAppend(allocator, &appended, input, .{ .dictionary_size = lzma2_writer.max_dictionary_size + 1 }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}

test "XZ stored writer round trips x86 and delta filter chain" {
    const allocator = std.testing.allocator;
    const input = "\x90\xe8\x10\x00\x00\x00\x90\xe9\xf0\xff\xff\xff" ** 128;
    const filter_chain = [_]Filter{
        Filter.x86(4096),
        try Filter.delta(4),
    };
    const encoded = try encodeStoredAlloc(allocator, input, .{
        .block_size = 1024,
        .filters = &filter_chain,
    });
    defer allocator.free(encoded);
    const decoded = try container.decodeAlloc(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    const info = try container.inspect(allocator, encoded);
    try std.testing.expect(info.block_count > 1);
    try std.testing.expectEqual(info.block_count, info.delta_filter_blocks);
    try std.testing.expectEqual(info.block_count, info.x86_filter_blocks);
}

test "XZ writer round trips ARM64 and RISC-V branch filters" {
    const allocator = std.testing.allocator;
    const cases = [_]struct {
        filter: Filter,
        payload: []const u8,
        kind: filters.Kind,
    }{
        .{
            .filter = try Filter.arm64(4096),
            .payload = "\x00\x00\x00\x94\x00\x00\x00\x90" ** 1024,
            .kind = .arm64,
        },
        .{
            .filter = try Filter.riscv(4096),
            .payload = "\xef\x00\x00\x00\x13\x00\x00\x00\x97\x01\x00\x00\xe7\x80\x01\x00" ** 512,
            .kind = .riscv,
        },
    };
    for (cases) |case| {
        const encoded = try encodeAlloc(allocator, case.payload, .{
            .check = .crc64,
            .block_size = 16 * 1024,
            .filters = &.{case.filter},
        });
        defer allocator.free(encoded);
        const decoded = try container.decodeAlloc(allocator, encoded);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case.payload, decoded);
        const info = try container.inspect(allocator, encoded);
        switch (case.kind) {
            .arm64 => try std.testing.expectEqual(@as(usize, 1), info.arm64_filter_blocks),
            .riscv => try std.testing.expectEqual(@as(usize, 1), info.riscv_filter_blocks),
            else => unreachable,
        }
    }
}

test {
    _ = @import("encoder/preset_tests.zig");
    _ = @import("encoder/large_chunk_tests.zig");
}
