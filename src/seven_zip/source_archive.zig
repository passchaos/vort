//! Random-access 7z archive facade.
//!
//! Parsing reads only the fixed signature header, the tail Next Header, and
//! any packed metadata streams referenced by that header. Entry extraction
//! then reads only the selected folder's packed ranges. Codec decoding remains
//! folder-buffered; symbol-progressive decoding is a separate data-plane step.

const std = @import("std");
const archive_mod = @import("archive.zig");
const checksum = @import("../checksum.zig");
const packed_input = @import("packed_input.zig");
const source_mod = @import("source.zig");
const streams_mod = @import("streams.zig");

pub const Error = archive_mod.Error || source_mod.Error;
pub const Entry = archive_mod.Entry;
pub const DecodeOptions = archive_mod.DecodeOptions;
pub const ParseOptions = archive_mod.ParseOptions;
pub const Source = source_mod.Source;

const signature_header_size: usize = 32;

pub const Archive = struct {
    allocator: std.mem.Allocator,
    source: Source,
    entries: []Entry,
    streams: streams_mod.Streams,
    next_header_start: u64,
    next_header_size: usize,
    packed_data_limit: u64,

    pub fn deinit(self: Archive) void {
        for (self.entries) |entry| self.allocator.free(entry.name);
        self.allocator.free(self.entries);
        self.streams.deinit();
    }

    pub fn entryAt(self: Archive, index: usize) Error!Entry {
        if (index >= self.entries.len) return error.EntryNotFound;
        return self.entries[index];
    }

    pub fn find(self: Archive, name: []const u8) ?Entry {
        for (self.entries) |entry| if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }

    pub fn extractEntryInto(self: Archive, entry: Entry, output: []u8) !usize {
        const size = std.math.cast(usize, entry.size) orelse return error.OutputTooSmall;
        if (output.len < size) return error.OutputTooSmall;
        const decoded = try self.decodeEntryAllocWithOptions(self.allocator, entry, .{
            .max_output_len = output.len,
        });
        defer self.allocator.free(decoded);
        @memcpy(output[0..decoded.len], decoded);
        return decoded.len;
    }

    pub fn extractEntryAlloc(self: Archive, allocator: std.mem.Allocator, entry: Entry) ![]u8 {
        return self.extractEntryAllocLimited(allocator, entry, std.math.maxInt(usize));
    }

    pub fn extractEntryAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        max_output_len: usize,
    ) ![]u8 {
        return self.decodeEntryAllocWithOptions(allocator, entry, .{
            .max_output_len = max_output_len,
        });
    }

    pub fn decodeEntryAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        options: DecodeOptions,
    ) ![]u8 {
        return archive_mod.decodeEntryFromInputAlloc(
            allocator,
            entry,
            &self.streams,
            packed_input.Input.fromSource(
                self.source,
                self.packed_data_limit,
                options.max_packed_stream_size,
            ),
            options,
        );
    }

    pub fn extractByNameAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        max_output_len: usize,
    ) ![]u8 {
        const entry = self.find(name) orelse return error.EntryNotFound;
        return self.extractEntryAllocLimited(allocator, entry, max_output_len);
    }

    pub fn extractByNameAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
    ) ![]u8 {
        return self.extractByNameAllocLimited(allocator, name, std.math.maxInt(usize));
    }
};

pub fn parseAlloc(allocator: std.mem.Allocator, source: Source) !Archive {
    return parseAllocWithOptions(allocator, source, .{});
}

pub fn parseAllocWithOptions(
    allocator: std.mem.Allocator,
    source: Source,
    options: ParseOptions,
) !Archive {
    var signature_header: [signature_header_size]u8 = undefined;
    try source.readExact(0, &signature_header);
    const layout = try archive_mod.parseSignatureHeader(&signature_header, source.len, options);

    const next_header = try allocator.alloc(u8, layout.next_header_size);
    defer allocator.free(next_header);
    try source.readExact(layout.next_header_start, next_header);
    if (checksum.crc32Best(next_header) != layout.next_header_crc)
        return error.ChecksumMismatch;

    const parsed = try archive_mod.parseBodyAlloc(
        allocator,
        next_header,
        packed_input.Input.fromSource(
            source,
            layout.next_header_start,
            options.max_packed_stream_size,
        ),
        options,
    );
    return .{
        .allocator = allocator,
        .source = source,
        .entries = parsed.entries,
        .streams = parsed.streams,
        .next_header_start = layout.next_header_start,
        .next_header_size = layout.next_header_size,
        .packed_data_limit = parsed.packed_data_limit,
    };
}

test "7z source archive skips unrelated packed folders and completes short reads" {
    const writer = @import("writer.zig");
    const first = "selected payload";
    const second = "unrelated payload block" ** 4096;
    const entries = [_]writer.EncodeEntry{
        .{ .name = "first.bin", .data = first },
        .{ .name = "second.bin", .data = second },
    };
    const encoded = try writer.encodeAlloc(std.testing.allocator, &entries, .{ .compression = .copy });
    defer std.testing.allocator.free(encoded);

    const Context = struct {
        bytes: []const u8,
        max_chunk: usize,
        bytes_read: usize = 0,

        fn readAt(context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(context));
            const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
            if (start >= self.bytes.len) return 0;
            const count = @min(output.len, @min(self.max_chunk, self.bytes.len - start));
            @memcpy(output[0..count], self.bytes[start..][0..count]);
            self.bytes_read += count;
            return count;
        }
    };
    var context = Context{ .bytes = encoded, .max_chunk = 3 };
    const source = Source{
        .context = &context,
        .len = encoded.len,
        .read_at = Context.readAt,
    };
    const parsed = try parseAlloc(std.testing.allocator, source);
    defer parsed.deinit();
    const metadata_bytes = signature_header_size + parsed.next_header_size;
    try std.testing.expectEqual(metadata_bytes, context.bytes_read);
    try std.testing.expectEqual(@as(usize, 2), parsed.entries.len);

    const decoded = try parsed.extractByNameAlloc(std.testing.allocator, "first.bin");
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first, decoded);
    try std.testing.expectEqual(metadata_bytes + first.len, context.bytes_read);
    try std.testing.expect(context.bytes_read < encoded.len);

    try std.testing.expectError(
        error.OutputLimitExceeded,
        parsed.decodeEntryAllocWithOptions(std.testing.allocator, parsed.entries[0], .{
            .max_packed_stream_size = first.len - 1,
        }),
    );
    const borrowed = try archive_mod.parseAlloc(std.testing.allocator, encoded);
    defer borrowed.deinit();
    try std.testing.expectError(
        error.OutputLimitExceeded,
        borrowed.decodeEntryAllocWithOptions(std.testing.allocator, borrowed.entries[0], .{
            .max_packed_stream_size = first.len - 1,
        }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parseAllocWithOptions(std.testing.allocator, source, .{
            .max_next_header_size = parsed.next_header_size - 1,
        }),
    );
}

test "7z source archive composes encoded metadata and encrypted BCJ2" {
    const writer = @import("writer.zig");
    const aes = @import("aes.zig");
    const payload = "\x90\xe8\x10\x00\x00\x00\xe9\xf0\xff\xff\xff\x90" ** 32;
    const entries = [_]writer.EncodeEntry{.{
        .name = "source-数据.bin",
        .data = payload,
        .modification_time = 116_444_736_030_000_000,
        .attributes = 0x81a4_0020,
    }};
    const encryption = writer.EncryptionOptions{
        .password = "source-password-密码",
        .iv = [_]u8{0x42} ** 16,
        .salt = [_]u8{0x24} ** 16,
        .salt_len = 8,
        .num_cycles_power = aes.direct_key_power,
    };
    const encoded = try writer.encodeAlloc(std.testing.allocator, &entries, .{
        .compression = .lzma2,
        .header_compression = .copy,
        .external_names = .copy,
        .external_metadata = .copy,
        .encryption = encryption,
        .encrypt_header = true,
        .bcj2 = true,
    });
    defer std.testing.allocator.free(encoded);

    const Context = struct {
        bytes: []const u8,
        max_chunk: usize,
        bytes_read: usize = 0,

        fn readAt(context: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(context));
            const start = std.math.cast(usize, offset) orelse return error.SourceReadFailed;
            if (start >= self.bytes.len) return 0;
            const count = @min(output.len, @min(self.max_chunk, self.bytes.len - start));
            @memcpy(output[0..count], self.bytes[start..][0..count]);
            self.bytes_read += count;
            return count;
        }
    };
    var context = Context{ .bytes = encoded, .max_chunk = 5 };
    const source = Source{
        .context = &context,
        .len = encoded.len,
        .read_at = Context.readAt,
    };
    try std.testing.expectError(
        error.PasswordRequired,
        parseAlloc(std.testing.allocator, source),
    );
    const parsed = try parseAllocWithOptions(std.testing.allocator, source, .{
        .password = encryption.password,
    });
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 1), parsed.entries.len);
    try std.testing.expectEqualStrings(entries[0].name, parsed.entries[0].name);
    try std.testing.expectEqual(entries[0].modification_time, parsed.entries[0].modification_time);
    try std.testing.expectEqual(entries[0].attributes, parsed.entries[0].attributes);
    try std.testing.expectEqual(@as(u3, 6), parsed.streams.folders[0].coder_count);

    const decoded = try parsed.decodeEntryAllocWithOptions(
        std.testing.allocator,
        parsed.entries[0],
        .{ .password = encryption.password },
    );
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);

    const ParseFailureTest = struct {
        fn run(allocator: std.mem.Allocator, input: Source, password: []const u8) !void {
            const archive = try parseAllocWithOptions(allocator, input, .{ .password = password });
            archive.deinit();
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        ParseFailureTest.run,
        .{ source, encryption.password },
    );

    const DecodeFailureTest = struct {
        fn run(
            allocator: std.mem.Allocator,
            archive: *const Archive,
            password: []const u8,
        ) !void {
            const result = try archive.decodeEntryAllocWithOptions(
                allocator,
                archive.entries[0],
                .{ .password = password },
            );
            allocator.free(result);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        DecodeFailureTest.run,
        .{ &parsed, encryption.password },
    );
}
