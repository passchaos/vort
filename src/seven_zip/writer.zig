const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const coders = @import("coders.zig");
const number = @import("number.zig");
const types = @import("types.zig");

pub const Error = core.Error || number.Error || coders.Error || error{
    Invalid7zEntry,
};

pub const EncodeEntry = types.EncodeEntry;
pub const Compression = coders.Compression;
pub const Filter = coders.Filter;
pub const EncodeOptions = coders.Options;

const signature = [_]u8{ '7', 'z', 0xbc, 0xaf, 0x27, 0x1c };

const Nid = struct {
    const end: u8 = 0x00;
    const header: u8 = 0x01;
    const main_streams: u8 = 0x04;
    const files: u8 = 0x05;
    const pack_info: u8 = 0x06;
    const unpack_info: u8 = 0x07;
    const substreams_info: u8 = 0x08;
    const size: u8 = 0x09;
    const crc: u8 = 0x0a;
    const folder: u8 = 0x0b;
    const coders_unpack_size: u8 = 0x0c;
    const empty_stream: u8 = 0x0e;
    const empty_file: u8 = 0x0f;
    const name: u8 = 0x11;
};

const EncodedStream = struct {
    packed_size: u64,
    unpacked_size: u64,
    crc32: u32,
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, entries, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    output: []u8,
    options: EncodeOptions,
) !usize {
    const encoded = try encodeAlloc(allocator, entries, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !usize {
    try coders.validate(options);
    var packed_data: std.ArrayList(u8) = .empty;
    defer packed_data.deinit(allocator);
    var header: std.ArrayList(u8) = .empty;
    defer header.deinit(allocator);
    try validateEntries(entries);

    var stream_count: usize = 0;
    for (entries) |entry| stream_count += @intFromBool(hasStream(entry));
    const streams = try allocator.alloc(EncodedStream, stream_count);
    defer allocator.free(streams);
    var stream_index: usize = 0;
    for (entries) |entry| {
        if (!hasStream(entry)) continue;
        const packed_size = try coders.appendPayload(allocator, &packed_data, entry.data, options);
        streams[stream_index] = .{
            .packed_size = std.math.cast(u64, packed_size) orelse return error.IntegerOverflow,
            .unpacked_size = std.math.cast(u64, entry.data.len) orelse return error.IntegerOverflow,
            .crc32 = checksum.crc32Best(entry.data),
        };
        stream_index += 1;
    }
    std.debug.assert(stream_index == streams.len);
    try writeNextHeader(allocator, &header, entries, streams, options);

    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    try encoded.appendSlice(allocator, &signature);
    try encoded.appendSlice(allocator, &.{ 0, 4 });
    var start_header: [20]u8 = undefined;
    std.mem.writeInt(u64, start_header[0..8], packed_data.items.len, .little);
    std.mem.writeInt(u64, start_header[8..16], header.items.len, .little);
    std.mem.writeInt(u32, start_header[16..20], checksum.crc32Best(header.items), .little);
    try appendU32(allocator, &encoded, checksum.crc32Best(&start_header));
    try encoded.appendSlice(allocator, &start_header);
    try encoded.appendSlice(allocator, packed_data.items);
    try encoded.appendSlice(allocator, header.items);

    try out.ensureUnusedCapacity(allocator, encoded.items.len);
    out.appendSliceAssumeCapacity(encoded.items);
    return encoded.items.len;
}

pub fn encodeStoredAlloc(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    options: EncodeOptions,
) ![]u8 {
    try validateStoredOptions(options);
    return encodeAlloc(allocator, entries, options);
}

pub fn encodeStoredInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    output: []u8,
    options: EncodeOptions,
) !usize {
    try validateStoredOptions(options);
    return encodeInto(allocator, entries, output, options);
}

pub fn encodeStoredAppend(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    options: EncodeOptions,
) !usize {
    try validateStoredOptions(options);
    return encodeAppend(allocator, out, entries, options);
}

fn validateStoredOptions(options: EncodeOptions) Error!void {
    if (options.compression != .copy or options.filters.len != 0)
        return error.Invalid7zOptions;
}

fn validateEntries(entries: []const EncodeEntry) Error!void {
    for (entries) |entry| {
        if (entry.name.len == 0 or std.mem.indexOfScalar(u8, entry.name, 0) != null)
            return error.Invalid7zEntry;
        if (!std.unicode.utf8ValidateSlice(entry.name)) return error.Invalid7zEntry;
        if (entry.kind == .directory and entry.data.len != 0) return error.Invalid7zEntry;
    }
}

fn hasStream(entry: EncodeEntry) bool {
    return entry.kind == .file and entry.data.len != 0;
}

fn writeNextHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
    streams: []const EncodedStream,
    options: EncodeOptions,
) !void {
    try output.append(allocator, Nid.header);
    if (streams.len != 0) try writeStreamsInfo(allocator, output, streams, options);
    try writeFilesInfo(allocator, output, entries);
    try output.append(allocator, Nid.end);
}

fn writeStreamsInfo(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    streams: []const EncodedStream,
    options: EncodeOptions,
) !void {
    try output.append(allocator, Nid.main_streams);
    try output.append(allocator, Nid.pack_info);
    try number.append(allocator, output, 0);
    try number.append(allocator, output, streams.len);
    try output.append(allocator, Nid.size);
    for (streams) |stream| try number.append(allocator, output, stream.packed_size);
    try output.append(allocator, Nid.end);

    try output.append(allocator, Nid.unpack_info);
    try output.append(allocator, Nid.folder);
    try number.append(allocator, output, streams.len);
    try output.append(allocator, 0);
    for (streams) |_| try coders.writeFolder(allocator, output, options);
    try output.append(allocator, Nid.coders_unpack_size);
    for (streams) |stream|
        for (0..coders.coderCount(options)) |_| try number.append(allocator, output, stream.unpacked_size);
    try output.append(allocator, Nid.crc);
    try output.append(allocator, 1);
    for (streams) |stream| try appendU32(allocator, output, stream.crc32);
    try output.append(allocator, Nid.end);

    try output.append(allocator, Nid.substreams_info);
    try output.append(allocator, Nid.end);
    try output.append(allocator, Nid.end);
}

fn writeFilesInfo(allocator: std.mem.Allocator, output: *std.ArrayList(u8), entries: []const EncodeEntry) !void {
    try output.append(allocator, Nid.files);
    try number.append(allocator, output, entries.len);

    var empty_count: usize = 0;
    for (entries) |entry| empty_count += @intFromBool(!hasStream(entry));
    if (empty_count != 0) {
        try output.append(allocator, Nid.empty_stream);
        try number.append(allocator, output, (entries.len + 7) / 8);
        try appendBitVector(allocator, output, entries.len, entries, struct {
            fn get(entry: EncodeEntry) bool {
                return !hasStream(entry);
            }
        }.get);

        try output.append(allocator, Nid.empty_file);
        try number.append(allocator, output, (empty_count + 7) / 8);
        var bits: std.ArrayList(bool) = .empty;
        defer bits.deinit(allocator);
        try bits.ensureTotalCapacity(allocator, empty_count);
        for (entries) |entry| if (!hasStream(entry))
            bits.appendAssumeCapacity(entry.kind == .file);
        try appendBools(allocator, output, bits.items);
    }

    var names: std.ArrayList(u8) = .empty;
    defer names.deinit(allocator);
    try names.append(allocator, 0);
    for (entries) |entry| {
        const utf16 = std.unicode.utf8ToUtf16LeAlloc(allocator, entry.name) catch |err| switch (err) {
            error.InvalidUtf8 => return error.Invalid7zEntry,
            error.OutOfMemory => return error.OutOfMemory,
        };
        defer allocator.free(utf16);
        for (utf16) |unit| try appendU16(allocator, &names, unit);
        try appendU16(allocator, &names, 0);
    }
    try output.append(allocator, Nid.name);
    try number.append(allocator, output, names.items.len);
    try output.appendSlice(allocator, names.items);
    try output.append(allocator, Nid.end);
}

fn appendBitVector(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    count: usize,
    entries: []const EncodeEntry,
    comptime predicate: fn (EncodeEntry) bool,
) !void {
    var byte: u8 = 0;
    for (0..count) |index| {
        if (predicate(entries[index])) byte |= @as(u8, 0x80) >> @intCast(index & 7);
        if (index & 7 == 7) {
            try output.append(allocator, byte);
            byte = 0;
        }
    }
    if (count & 7 != 0) try output.append(allocator, byte);
}

fn appendBools(allocator: std.mem.Allocator, output: *std.ArrayList(u8), values: []const bool) !void {
    var byte: u8 = 0;
    for (values, 0..) |value, index| {
        if (value) byte |= @as(u8, 0x80) >> @intCast(index & 7);
        if (index & 7 == 7) {
            try output.append(allocator, byte);
            byte = 0;
        }
    }
    if (values.len & 7 != 0) try output.append(allocator, byte);
}

fn appendU16(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendU32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

test "7z stored writer emits deterministic signature and metadata" {
    const entries = [_]EncodeEntry{
        .{ .name = "hello.txt", .data = "hello seven zip\n" },
        .{ .name = "empty.txt" },
        .{ .name = "folder", .kind = .directory },
        .{ .name = "utf8-数据.txt", .data = "payload" },
    };
    const first = try encodeStoredAlloc(std.testing.allocator, &entries, .{});
    defer std.testing.allocator.free(first);
    const second = try encodeStoredAlloc(std.testing.allocator, &entries, .{});
    defer std.testing.allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    try std.testing.expectEqualSlices(u8, &signature, first[0..signature.len]);

    const out = try std.testing.allocator.alloc(u8, first.len);
    defer std.testing.allocator.free(out);
    try std.testing.expectEqual(first.len, try encodeStoredInto(std.testing.allocator, &entries, out, .{}));
    try std.testing.expectEqualSlices(u8, first, out);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeStoredInto(std.testing.allocator, &entries, out[0 .. out.len - 1], .{}),
    );

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    const prefix_len = appended.items.len;
    try std.testing.expectEqual(first.len, try encodeStoredAppend(std.testing.allocator, &appended, &entries, .{}));
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0..prefix_len]);
    try std.testing.expectEqualSlices(u8, first, appended.items[prefix_len..]);

    const before = try std.testing.allocator.dupe(u8, appended.items);
    defer std.testing.allocator.free(before);
    const invalid = [_]EncodeEntry{.{ .name = "", .data = "bad" }};
    try std.testing.expectError(
        error.Invalid7zEntry,
        encodeStoredAppend(std.testing.allocator, &appended, &invalid, .{}),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
    try std.testing.expectError(
        error.Invalid7zOptions,
        encodeStoredAppend(std.testing.allocator, &appended, &entries, .{ .compression = .deflate }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}

test "7z compressed writer supports caller-owned and transactional append APIs" {
    const entries = [_]EncodeEntry{.{
        .name = "payload.txt",
        .data = "compressible 7z payload\n" ** 64,
    }};
    const options = EncodeOptions{ .compression = .deflate };
    const encoded = try encodeAlloc(std.testing.allocator, &entries, options);
    defer std.testing.allocator.free(encoded);

    const output = try std.testing.allocator.alloc(u8, encoded.len);
    defer std.testing.allocator.free(output);
    try std.testing.expectEqual(encoded.len, try encodeInto(std.testing.allocator, &entries, output, options));
    try std.testing.expectEqualSlices(u8, encoded, output);
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeInto(std.testing.allocator, &entries, output[0 .. output.len - 1], options),
    );

    var appended: std.ArrayList(u8) = .empty;
    defer appended.deinit(std.testing.allocator);
    try appended.appendSlice(std.testing.allocator, "prefix:");
    const prefix_len = appended.items.len;
    try std.testing.expectEqual(
        encoded.len,
        try encodeAppend(std.testing.allocator, &appended, &entries, options),
    );
    try std.testing.expectEqualSlices(u8, "prefix:", appended.items[0..prefix_len]);
    try std.testing.expectEqualSlices(u8, encoded, appended.items[prefix_len..]);

    const before = try std.testing.allocator.dupe(u8, appended.items);
    defer std.testing.allocator.free(before);
    try std.testing.expectError(
        error.Invalid7zOptions,
        encodeAppend(std.testing.allocator, &appended, &entries, .{
            .compression = .deflate,
            .deflate_level = 10,
        }),
    );
    try std.testing.expectEqualSlices(u8, before, appended.items);
}
