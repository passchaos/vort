const std = @import("std");
const checksum = @import("../checksum.zig");
const format = @import("format.zig");

pub const Error = format.Error || std.mem.Allocator.Error;

pub const magic = "Zucc";
pub const major_version: u16 = 1;
pub const header_size: usize = 24;
pub const element_header_size: usize = 22;

pub const ExecutableType = enum(u32) {
    no_op = fourCc("NoOp"),
    win32_x86 = fourCc("Px86"),
    win32_x64 = fourCc("Px64"),
    elf_x86 = fourCc("Ex86"),
    elf_x64 = fourCc("Ex64"),
    elf_aarch32 = fourCc("EA32"),
    elf_aarch64 = fourCc("EA64"),
    dex = fourCc("DEX "),
    ztf = fourCc("ZTF "),
    _,
};

pub const Header = struct {
    major: u16,
    minor: u16,
    old_size: usize,
    old_crc32: u32,
    new_size: usize,
    new_crc32: u32,
};

pub const TargetPool = struct {
    tag: u8,
    targets: []const u8,
};

pub const Element = struct {
    old_offset: usize,
    old_length: usize,
    new_offset: usize,
    new_length: usize,
    executable_type: ExecutableType,
    version: u16,
    source_skips: []const u8,
    destination_skips: []const u8,
    copy_lengths: []const u8,
    extra_data: []const u8,
    raw_delta_skips: []const u8,
    raw_delta_diffs: []const u8,
    reference_deltas: []const u8,
    pool_start: usize,
    pool_count: usize,
};

pub const ParseOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_elements: usize = 1 << 20,
    max_equivalences: usize = 1 << 24,
    max_target_pools: usize = 1 << 20,
};

pub const ApplyOptions = ParseOptions;

pub const Patch = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    header: Header,
    elements: []Element,
    target_pools: []TargetPool,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        bytes: []const u8,
        options: ParseOptions,
    ) Error!Patch {
        return parseAlloc(allocator, bytes, options);
    }

    pub fn deinit(self: *Patch) void {
        self.allocator.free(self.elements);
        self.allocator.free(self.target_pools);
        self.* = undefined;
    }

    pub fn applyAlloc(
        self: Patch,
        allocator: std.mem.Allocator,
        source: []const u8,
        expected_output_len: usize,
        options: ApplyOptions,
    ) Error![]u8 {
        if (expected_output_len != self.header.new_size)
            return error.SizeMismatch;
        if (expected_output_len > options.max_output_len)
            return error.OutputLimitExceeded;
        if (source.len != self.header.old_size)
            return error.SizeMismatch;
        if (checksum.crc32(source) != self.header.old_crc32)
            return error.ChecksumMismatch;

        const output = try allocator.alloc(u8, expected_output_len);
        errdefer allocator.free(output);
        for (self.elements) |element| {
            switch (element.executable_type) {
                .no_op => try applyNoOpElement(
                    source[element.old_offset..][0..element.old_length],
                    output[element.new_offset..][0..element.new_length],
                    element,
                    options.max_equivalences,
                ),
                else => return error.UnsupportedZucchiniPatch,
            }
        }
        if (checksum.crc32(output) != self.header.new_crc32)
            return error.ChecksumMismatch;
        return output;
    }
};

pub fn parseAlloc(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    options: ParseOptions,
) Error!Patch {
    if (bytes.len < header_size + 4) return error.TruncatedFrame;
    if (!std.mem.eql(u8, bytes[0..4], magic))
        return error.InvalidZucchiniPatch;
    const major = readU16(bytes, 4);
    if (major != major_version) return error.UnsupportedVersion;
    const old_size: usize = readU32(bytes, 8);
    const new_size: usize = readU32(bytes, 16);
    if (new_size > options.max_output_len)
        return error.OutputLimitExceeded;
    const header = Header{
        .major = major,
        .minor = readU16(bytes, 6),
        .old_size = old_size,
        .old_crc32 = readU32(bytes, 12),
        .new_size = new_size,
        .new_crc32 = readU32(bytes, 20),
    };
    var offset: usize = header_size;
    const element_count: usize = try readU32Advance(bytes, &offset);
    if (element_count > options.max_elements)
        return error.OutputLimitExceeded;
    var elements: std.ArrayList(Element) = .empty;
    errdefer elements.deinit(allocator);
    try elements.ensureTotalCapacity(allocator, element_count);
    var pools: std.ArrayList(TargetPool) = .empty;
    errdefer pools.deinit(allocator);
    var expected_new_offset: usize = 0;
    for (0..element_count) |_| {
        if (bytes.len - offset < element_header_size)
            return error.TruncatedFrame;
        const old_offset: usize = readU32(bytes, offset);
        const old_length: usize = readU32(bytes, offset + 4);
        const new_offset: usize = readU32(bytes, offset + 8);
        const new_length: usize = readU32(bytes, offset + 12);
        const executable_type = knownExecutableType(readU32(bytes, offset + 16)) orelse
            return error.InvalidZucchiniPatch;
        const version = readU16(bytes, offset + 20);
        offset += element_header_size;
        if (version != 1 or old_length == 0 or new_length == 0)
            return error.InvalidZucchiniPatch;
        if (!rangeFits(old_offset, old_length, old_size) or
            !rangeFits(new_offset, new_length, new_size) or
            new_offset != expected_new_offset)
            return error.InvalidZucchiniPatch;
        expected_new_offset = std.math.add(
            usize,
            new_offset,
            new_length,
        ) catch return error.IntegerOverflow;

        const source_skips = try readBuffer(bytes, &offset);
        const destination_skips = try readBuffer(bytes, &offset);
        const copy_lengths = try readBuffer(bytes, &offset);
        const extra_data = try readBuffer(bytes, &offset);
        const raw_delta_skips = try readBuffer(bytes, &offset);
        const raw_delta_diffs = try readBuffer(bytes, &offset);
        const reference_deltas = try readBuffer(bytes, &offset);
        const pool_count: usize = try readU32Advance(bytes, &offset);
        if (pool_count > options.max_target_pools -| pools.items.len)
            return error.OutputLimitExceeded;
        const pool_start = pools.items.len;
        for (0..pool_count) |_| {
            if (offset >= bytes.len) return error.TruncatedFrame;
            const tag = bytes[offset];
            offset += 1;
            if (tag == 0xff) return error.InvalidZucchiniPatch;
            for (pools.items[pool_start..]) |pool|
                if (pool.tag == tag) return error.InvalidZucchiniPatch;
            try pools.append(allocator, .{
                .tag = tag,
                .targets = try readBuffer(bytes, &offset),
            });
        }
        const element = Element{
            .old_offset = old_offset,
            .old_length = old_length,
            .new_offset = new_offset,
            .new_length = new_length,
            .executable_type = executable_type,
            .version = version,
            .source_skips = source_skips,
            .destination_skips = destination_skips,
            .copy_lengths = copy_lengths,
            .extra_data = extra_data,
            .raw_delta_skips = raw_delta_skips,
            .raw_delta_diffs = raw_delta_diffs,
            .reference_deltas = reference_deltas,
            .pool_start = pool_start,
            .pool_count = pool_count,
        };
        _ = try validateElement(element, options.max_equivalences);
        elements.appendAssumeCapacity(element);
    }
    if (expected_new_offset != new_size)
        return error.InvalidZucchiniPatch;
    if (offset != bytes.len) return error.TrailingData;
    const owned_elements = try elements.toOwnedSlice(allocator);
    errdefer allocator.free(owned_elements);
    const owned_pools = try pools.toOwnedSlice(allocator);
    return .{
        .allocator = allocator,
        .bytes = bytes,
        .header = header,
        .elements = owned_elements,
        .target_pools = owned_pools,
    };
}

pub fn applyAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    patch_bytes: []const u8,
    expected_output_len: usize,
    options: ApplyOptions,
) Error![]u8 {
    var patch = try parseAlloc(allocator, patch_bytes, options);
    defer patch.deinit();
    return patch.applyAlloc(
        allocator,
        source,
        expected_output_len,
        options,
    );
}

const Equivalence = struct {
    source_offset: usize,
    destination_offset: usize,
    length: usize,
};

const EquivalenceIterator = struct {
    source_skips: Stream,
    destination_skips: Stream,
    copy_lengths: Stream,
    previous_source_end: i64 = 0,
    previous_destination_end: usize = 0,

    fn init(element: Element) EquivalenceIterator {
        return .{
            .source_skips = .{ .bytes = element.source_skips },
            .destination_skips = .{ .bytes = element.destination_skips },
            .copy_lengths = .{ .bytes = element.copy_lengths },
        };
    }

    fn next(self: *EquivalenceIterator) Error!?Equivalence {
        const source_done = self.source_skips.done();
        const destination_done = self.destination_skips.done();
        const length_done = self.copy_lengths.done();
        if (source_done or destination_done or length_done) {
            if (!(source_done and destination_done and length_done))
                return error.InvalidZucchiniPatch;
            return null;
        }
        const length: usize = try self.copy_lengths.readVarUInt();
        if (length == 0) return error.InvalidZucchiniPatch;
        const source_diff = try self.source_skips.readVarInt();
        const source_offset_i64 = std.math.add(
            i64,
            self.previous_source_end,
            source_diff,
        ) catch return error.IntegerOverflow;
        if (source_offset_i64 < 0) return error.InvalidZucchiniPatch;
        const source_offset: usize = @intCast(source_offset_i64);
        self.previous_source_end = std.math.add(
            i64,
            source_offset_i64,
            @as(i64, @intCast(length)),
        ) catch return error.IntegerOverflow;
        const destination_skip: usize = try self.destination_skips.readVarUInt();
        const destination_offset = std.math.add(
            usize,
            self.previous_destination_end,
            destination_skip,
        ) catch return error.IntegerOverflow;
        self.previous_destination_end = std.math.add(
            usize,
            destination_offset,
            length,
        ) catch return error.IntegerOverflow;
        return .{
            .source_offset = source_offset,
            .destination_offset = destination_offset,
            .length = length,
        };
    }
};

fn validateElement(element: Element, max_equivalences: usize) Error!usize {
    var iterator = EquivalenceIterator.init(element);
    var count: usize = 0;
    var copied: usize = 0;
    var previous_destination_end: usize = 0;
    while (try iterator.next()) |equivalence| {
        if (count >= max_equivalences)
            return error.OutputLimitExceeded;
        count += 1;
        if (!rangeFits(
            equivalence.source_offset,
            equivalence.length,
            element.old_length,
        ) or !rangeFits(
            equivalence.destination_offset,
            equivalence.length,
            element.new_length,
        ) or equivalence.destination_offset < previous_destination_end)
            return error.InvalidZucchiniPatch;
        previous_destination_end = equivalence.destination_offset +
            equivalence.length;
        copied = std.math.add(usize, copied, equivalence.length) catch
            return error.IntegerOverflow;
    }
    if (copied > element.new_length or
        element.extra_data.len != element.new_length - copied)
        return error.InvalidZucchiniPatch;
    try validateRawDeltas(element, copied);
    return copied;
}

fn validateRawDeltas(element: Element, copied_length: usize) Error!void {
    var skips = Stream{ .bytes = element.raw_delta_skips };
    var diffs = Stream{ .bytes = element.raw_delta_diffs };
    var compensation: usize = 0;
    while (!skips.done() or !diffs.done()) {
        if (skips.done() or diffs.done())
            return error.InvalidZucchiniPatch;
        const skip: usize = try skips.readVarUInt();
        const copy_offset = std.math.add(usize, compensation, skip) catch
            return error.IntegerOverflow;
        const diff = try diffs.readByte();
        if (diff == 0 or copy_offset >= copied_length)
            return error.InvalidZucchiniPatch;
        compensation = std.math.add(usize, copy_offset, 1) catch
            return error.IntegerOverflow;
    }
}

fn applyNoOpElement(
    source: []const u8,
    output: []u8,
    element: Element,
    max_equivalences: usize,
) Error!void {
    if (element.reference_deltas.len != 0 or element.pool_count != 0)
        return error.InvalidZucchiniPatch;
    var iterator = EquivalenceIterator.init(element);
    var extra_offset: usize = 0;
    var output_offset: usize = 0;
    var equivalence_count: usize = 0;
    while (try iterator.next()) |equivalence| {
        if (equivalence_count >= max_equivalences)
            return error.OutputLimitExceeded;
        equivalence_count += 1;
        const gap = equivalence.destination_offset - output_offset;
        @memcpy(
            output[output_offset..][0..gap],
            element.extra_data[extra_offset..][0..gap],
        );
        extra_offset += gap;
        output_offset = equivalence.destination_offset;
        @memcpy(
            output[output_offset..][0..equivalence.length],
            source[equivalence.source_offset..][0..equivalence.length],
        );
        output_offset += equivalence.length;
    }
    const tail = output.len - output_offset;
    @memcpy(
        output[output_offset..],
        element.extra_data[extra_offset..][0..tail],
    );
    extra_offset += tail;
    if (extra_offset != element.extra_data.len)
        return error.InvalidZucchiniPatch;

    iterator = EquivalenceIterator.init(element);
    var current_equivalence = try iterator.next();
    var copied_before: usize = 0;
    var skips = Stream{ .bytes = element.raw_delta_skips };
    var diffs = Stream{ .bytes = element.raw_delta_diffs };
    var compensation: usize = 0;
    while (!skips.done()) {
        const skip: usize = try skips.readVarUInt();
        const copy_offset = std.math.add(usize, compensation, skip) catch
            return error.IntegerOverflow;
        const diff = try diffs.readByte();
        while (current_equivalence) |equivalence| {
            if (copied_before + equivalence.length > copy_offset) break;
            copied_before += equivalence.length;
            current_equivalence = try iterator.next();
        }
        const equivalence = current_equivalence orelse
            return error.InvalidZucchiniPatch;
        const within = copy_offset - copied_before;
        output[equivalence.destination_offset + within] +%= diff;
        compensation = copy_offset + 1;
    }
    if (!diffs.done()) return error.InvalidZucchiniPatch;
}

const Stream = struct {
    bytes: []const u8,
    offset: usize = 0,

    fn done(self: Stream) bool {
        return self.offset == self.bytes.len;
    }

    fn readByte(self: *Stream) Error!u8 {
        if (self.offset >= self.bytes.len) return error.TruncatedFrame;
        const value = self.bytes[self.offset];
        self.offset += 1;
        return value;
    }

    fn readVarUInt(self: *Stream) Error!u32 {
        var value: u32 = 0;
        var shift: u5 = 0;
        for (0..5) |index| {
            const byte = try self.readByte();
            if (index == 4 and byte > 0x0f)
                return error.InvalidZucchiniPatch;
            value |= @as(u32, byte & 0x7f) << shift;
            if (byte & 0x80 == 0) return value;
            shift += 7;
        }
        return error.InvalidZucchiniPatch;
    }

    fn readVarInt(self: *Stream) Error!i32 {
        const encoded = try self.readVarUInt();
        const magnitude: i32 = @bitCast(encoded >> 1);
        return if (encoded & 1 != 0) ~magnitude else magnitude;
    }
};

fn readBuffer(bytes: []const u8, offset: *usize) Error![]const u8 {
    const length: usize = try readU32Advance(bytes, offset);
    if (length > bytes.len - offset.*) return error.TruncatedFrame;
    const result = bytes[offset.*..][0..length];
    offset.* += length;
    return result;
}

fn readU32Advance(bytes: []const u8, offset: *usize) Error!u32 {
    if (bytes.len - offset.* < 4) return error.TruncatedFrame;
    const value = readU32(bytes, offset.*);
    offset.* += 4;
    return value;
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn rangeFits(offset: usize, length: usize, total: usize) bool {
    return offset <= total and length <= total - offset;
}

fn knownExecutableType(raw: u32) ?ExecutableType {
    return switch (@as(ExecutableType, @enumFromInt(raw))) {
        .no_op,
        .win32_x86,
        .win32_x64,
        .elf_x86,
        .elf_x64,
        .elf_aarch32,
        .elf_aarch64,
        .dex,
        .ztf,
        => |value| value,
        else => null,
    };
}

fn fourCc(comptime text: *const [4]u8) u32 {
    return @as(u32, text[0]) |
        (@as(u32, text[1]) << 8) |
        (@as(u32, text[2]) << 16) |
        (@as(u32, text[3]) << 24);
}

test "Android OTA Zucchini v1 applies NoOp equivalences extra data and raw deltas" {
    const allocator = std.testing.allocator;
    const source = "0123456789abcdefghijklmnopqrstuvwxyz";
    const expected = "HEAD3456789abc!TAIL";
    const patch_bytes = try testNoOpPatchAlloc(
        allocator,
        source,
        expected,
    );
    defer allocator.free(patch_bytes);
    var patch = try parseAlloc(allocator, patch_bytes, .{});
    defer patch.deinit();
    try std.testing.expectEqual(@as(usize, 1), patch.elements.len);
    try std.testing.expectEqual(ExecutableType.no_op, patch.elements[0].executable_type);
    const output = try patch.applyAlloc(
        allocator,
        source,
        expected.len,
        .{},
    );
    defer allocator.free(output);
    try std.testing.expectEqualSlices(u8, expected, output);
}

test "Android OTA Zucchini rejects bounds CRC truncation and unsupported executable elements" {
    const allocator = std.testing.allocator;
    const source = "0123456789abcdefghijklmnopqrstuvwxyz";
    const expected = "HEAD3456789abc!TAIL";
    const encoded = try testNoOpPatchAlloc(allocator, source, expected);
    defer allocator.free(encoded);
    try std.testing.expectError(
        error.TruncatedFrame,
        parseAlloc(allocator, encoded[0..23], .{}),
    );
    const corrupt = try allocator.dupe(u8, encoded);
    defer allocator.free(corrupt);
    corrupt[12] ^= 1;
    try std.testing.expectError(
        error.ChecksumMismatch,
        applyAlloc(allocator, source, corrupt, expected.len, .{}),
    );
    @memcpy(corrupt, encoded);
    corrupt[36] = 1;
    try std.testing.expectError(
        error.InvalidZucchiniPatch,
        parseAlloc(allocator, corrupt, .{}),
    );
    @memcpy(corrupt, encoded);
    @memcpy(corrupt[44..48], "EA64");
    try std.testing.expectError(
        error.UnsupportedZucchiniPatch,
        applyAlloc(allocator, source, corrupt, expected.len, .{}),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        parseAlloc(allocator, encoded, .{ .max_output_len = expected.len - 1 }),
    );
}

test "Android OTA Zucchini releases parser and output allocation failures" {
    const source = "0123456789abcdefghijklmnopqrstuvwxyz";
    const expected = "HEAD3456789abc!TAIL";
    const encoded = try testNoOpPatchAlloc(
        std.testing.allocator,
        source,
        expected,
    );
    defer std.testing.allocator.free(encoded);
    const Test = struct {
        fn run(
            allocator: std.mem.Allocator,
            patch_bytes: []const u8,
            old_bytes: []const u8,
            new_bytes: []const u8,
        ) !void {
            var patch = try parseAlloc(allocator, patch_bytes, .{});
            defer patch.deinit();
            const output = try patch.applyAlloc(
                allocator,
                old_bytes,
                new_bytes.len,
                .{},
            );
            defer allocator.free(output);
            try std.testing.expectEqualSlices(u8, new_bytes, output);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{ encoded, source, expected },
    );
}

test "Android OTA Zucchini parses the pinned AOSP patch reader fixture" {
    var patch = try parseAlloc(
        std.testing.allocator,
        &test_aosp_reader_fixture,
        .{},
    );
    defer patch.deinit();
    try std.testing.expectEqual(@as(u16, 1), patch.header.major);
    try std.testing.expectEqual(@as(usize, 0x7654_3210), patch.header.old_size);
    try std.testing.expectEqual(@as(usize, 1), patch.header.new_size);
    try std.testing.expectEqual(@as(usize, 1), patch.elements.len);
    try std.testing.expectEqual(
        ExecutableType.win32_x86,
        patch.elements[0].executable_type,
    );
}

pub const test_aosp_reader_fixture = [_]u8{
    0x5a, 0x75, 0x63, 0x63, 0x01, 0x00, 0x00, 0x00,
    0x10, 0x32, 0x54, 0x76, 0x00, 0x11, 0x22, 0x33,
    0x01, 0x00, 0x00, 0x00, 0x44, 0x55, 0x66, 0x77,
    0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0x00, 0x00, 0x00, 0x50, 0x78, 0x38, 0x36,
    0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00,
    0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00,
};

pub fn testNoOpPatchAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    expected: []const u8,
) ![]u8 {
    // HEAD + source[3..14], with one copied byte adjusted from 'd' to '!'
    // + TAIL. This exercises gaps, one equivalence, and one raw delta.
    std.debug.assert(std.mem.eql(u8, expected, "HEAD3456789abc!TAIL"));
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, magic);
    try appendU16(allocator, &output, major_version);
    try appendU16(allocator, &output, 0);
    try appendU32(allocator, &output, @intCast(source.len));
    try appendU32(allocator, &output, checksum.crc32(source));
    try appendU32(allocator, &output, @intCast(expected.len));
    try appendU32(allocator, &output, checksum.crc32(expected));
    try appendU32(allocator, &output, 1);
    try appendU32(allocator, &output, 0);
    try appendU32(allocator, &output, @intCast(source.len));
    try appendU32(allocator, &output, 0);
    try appendU32(allocator, &output, @intCast(expected.len));
    try output.appendSlice(allocator, "NoOp");
    try appendU16(allocator, &output, 1);
    try appendBuffer(allocator, &output, &.{6}); // zigzag(+3)
    try appendBuffer(allocator, &output, &.{4}); // destination gap
    try appendBuffer(allocator, &output, &.{11}); // copied length
    try appendBuffer(allocator, &output, "HEADTAIL");
    try appendBuffer(allocator, &output, &.{10}); // copied offset 10
    try appendBuffer(allocator, &output, &.{0xbd}); // '!' - 'd' modulo 256
    try appendBuffer(allocator, &output, "");
    try appendU32(allocator, &output, 0);
    return output.toOwnedSlice(allocator);
}

pub fn testLiteralPatchAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    expected: []const u8,
) ![]u8 {
    if (source.len == 0 or expected.len == 0)
        return error.TestUnexpectedResult;
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, magic);
    try appendU16(allocator, &output, major_version);
    try appendU16(allocator, &output, 0);
    try appendU32(allocator, &output, @intCast(source.len));
    try appendU32(allocator, &output, checksum.crc32(source));
    try appendU32(allocator, &output, @intCast(expected.len));
    try appendU32(allocator, &output, checksum.crc32(expected));
    try appendU32(allocator, &output, 1);
    try appendU32(allocator, &output, 0);
    try appendU32(allocator, &output, @intCast(source.len));
    try appendU32(allocator, &output, 0);
    try appendU32(allocator, &output, @intCast(expected.len));
    try output.appendSlice(allocator, "NoOp");
    try appendU16(allocator, &output, 1);
    try appendBuffer(allocator, &output, "");
    try appendBuffer(allocator, &output, "");
    try appendBuffer(allocator, &output, "");
    try appendBuffer(allocator, &output, expected);
    try appendBuffer(allocator, &output, "");
    try appendBuffer(allocator, &output, "");
    try appendBuffer(allocator, &output, "");
    try appendU32(allocator, &output, 0);
    return output.toOwnedSlice(allocator);
}

fn appendBuffer(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    bytes: []const u8,
) !void {
    try appendU32(allocator, output, @intCast(bytes.len));
    try output.appendSlice(allocator, bytes);
}

fn appendU16(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u16,
) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}

fn appendU32(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: u32,
) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try output.appendSlice(allocator, &bytes);
}
