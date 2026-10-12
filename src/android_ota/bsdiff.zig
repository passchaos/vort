const std = @import("std");
const br = @import("../br.zig");
const bzip2 = @import("../bzip2.zig");
const format = @import("format.zig");

pub const Error = format.Error || br.Error || bzip2.Error ||
    std.mem.Allocator.Error;

pub const ApplyOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_control_bytes: usize = 64 * 1024 * 1024,
};

const Compressor = enum(u8) {
    bzip2 = 1,
    brotli = 2,
};

const Header = struct {
    compressors: [3]Compressor,
    control: []const u8,
    diff: []const u8,
    extra: []const u8,
    output_len: usize,
};

pub fn applyAlloc(
    allocator: std.mem.Allocator,
    source: []const u8,
    patch: []const u8,
    expected_output_len: usize,
    options: ApplyOptions,
) Error![]u8 {
    if (expected_output_len > options.max_output_len)
        return error.OutputLimitExceeded;
    const header = try parseHeader(patch);
    if (header.output_len != expected_output_len)
        return error.SizeMismatch;
    const control_limit_from_output = std.math.mul(
        usize,
        expected_output_len,
        24,
    ) catch options.max_control_bytes;
    const control_limit = @min(
        options.max_control_bytes,
        control_limit_from_output,
    );
    const control = try decompressAlloc(
        allocator,
        header.compressors[0],
        header.control,
        control_limit,
    );
    defer allocator.free(control);
    const diff = try decompressAlloc(
        allocator,
        header.compressors[1],
        header.diff,
        expected_output_len,
    );
    defer allocator.free(diff);
    const extra = try decompressAlloc(
        allocator,
        header.compressors[2],
        header.extra,
        expected_output_len,
    );
    defer allocator.free(extra);
    if (control.len % 24 != 0) return error.InvalidBsdiffPatch;

    const output = try allocator.alloc(u8, expected_output_len);
    errdefer allocator.free(output);
    var control_offset: usize = 0;
    var diff_offset: usize = 0;
    var extra_offset: usize = 0;
    var output_offset: usize = 0;
    var source_offset: i64 = 0;
    while (output_offset < output.len) {
        if (control.len - control_offset < 24)
            return error.TruncatedFrame;
        const diff_size_i64 = parseSignedMagnitude(control[control_offset..][0..8]);
        const extra_size_i64 = parseSignedMagnitude(control[control_offset + 8 ..][0..8]);
        const source_advance = parseSignedMagnitude(control[control_offset + 16 ..][0..8]);
        control_offset += 24;
        if (diff_size_i64 < 0 or extra_size_i64 < 0)
            return error.InvalidBsdiffPatch;
        const diff_size: usize = @intCast(diff_size_i64);
        const extra_size: usize = @intCast(extra_size_i64);
        if (diff_size == 0 and extra_size == 0)
            return error.InvalidBsdiffPatch;
        const after_diff = std.math.add(
            usize,
            output_offset,
            diff_size,
        ) catch return error.IntegerOverflow;
        const after_extra = std.math.add(
            usize,
            after_diff,
            extra_size,
        ) catch return error.IntegerOverflow;
        if (after_extra > output.len or diff_size > diff.len -| diff_offset or
            extra_size > extra.len -| extra_offset)
            return error.InvalidBsdiffPatch;

        for (output[output_offset..after_diff], 0..) |*byte, index| {
            const patch_byte = diff[diff_offset + index];
            const old_position = @as(i128, source_offset) + @as(i128, @intCast(index));
            byte.* = if (old_position >= 0 and old_position < source.len)
                patch_byte +% source[@intCast(old_position)]
            else
                patch_byte;
        }
        diff_offset += diff_size;
        source_offset = std.math.add(
            i64,
            source_offset,
            diff_size_i64,
        ) catch return error.IntegerOverflow;
        output_offset = after_diff;

        @memcpy(
            output[output_offset..after_extra],
            extra[extra_offset..][0..extra_size],
        );
        extra_offset += extra_size;
        output_offset = after_extra;
        source_offset = std.math.add(
            i64,
            source_offset,
            source_advance,
        ) catch return error.IntegerOverflow;
    }
    if (control_offset != control.len or diff_offset != diff.len or
        extra_offset != extra.len)
        return error.TrailingData;
    return output;
}

fn parseHeader(patch: []const u8) Error!Header {
    if (patch.len < 32) return error.TruncatedFrame;
    var compressors: [3]Compressor = undefined;
    if (std.mem.eql(u8, patch[0..8], "BSDIFF40")) {
        compressors = .{ .bzip2, .bzip2, .bzip2 };
    } else if (std.mem.eql(u8, patch[0..5], "BSDF2")) {
        for (patch[5..8], 0..) |raw, index|
            compressors[index] = std.enums.fromInt(Compressor, raw) orelse
                return error.UnsupportedBsdiffCompression;
    } else {
        return error.InvalidBsdiffPatch;
    }
    const control_len_i64 = parseSignedMagnitude(patch[8..16]);
    const diff_len_i64 = parseSignedMagnitude(patch[16..24]);
    const output_len_i64 = parseSignedMagnitude(patch[24..32]);
    if (control_len_i64 < 0 or diff_len_i64 < 0 or output_len_i64 < 0)
        return error.InvalidBsdiffPatch;
    const control_len = std.math.cast(usize, control_len_i64) orelse
        return error.OutputLimitExceeded;
    const diff_len = std.math.cast(usize, diff_len_i64) orelse
        return error.OutputLimitExceeded;
    const output_len = std.math.cast(usize, output_len_i64) orelse
        return error.OutputLimitExceeded;
    const diff_start = std.math.add(usize, 32, control_len) catch
        return error.IntegerOverflow;
    const extra_start = std.math.add(usize, diff_start, diff_len) catch
        return error.IntegerOverflow;
    if (extra_start > patch.len) return error.TruncatedFrame;
    return .{
        .compressors = compressors,
        .control = patch[32..diff_start],
        .diff = patch[diff_start..extra_start],
        .extra = patch[extra_start..],
        .output_len = output_len,
    };
}

fn decompressAlloc(
    allocator: std.mem.Allocator,
    compressor: Compressor,
    input: []const u8,
    max_output_len: usize,
) Error![]u8 {
    return switch (compressor) {
        .bzip2 => bzip2.decodeAllocLimited(allocator, input, max_output_len),
        .brotli => br.decodeStreamAllocLimited(allocator, input, max_output_len),
    };
}

fn parseSignedMagnitude(bytes: *const [8]u8) i64 {
    const raw = std.mem.readInt(u64, bytes, .little);
    const magnitude = raw & std.math.maxInt(i64);
    const value: i64 = @intCast(magnitude);
    return if (raw >> 63 != 0) -value else value;
}

test "Android OTA bsdiff signed-magnitude integers cover boundaries" {
    inline for (.{
        @as(i64, 0),
        @as(i64, 1),
        @as(i64, -1),
        std.math.maxInt(i64),
        -std.math.maxInt(i64),
    }) |value| {
        var encoded: [8]u8 = undefined;
        appendSignedMagnitude(&encoded, value);
        try std.testing.expectEqual(value, parseSignedMagnitude(&encoded));
    }
}

fn appendSignedMagnitude(
    output: *[8]u8,
    value: i64,
) void {
    const magnitude: u64 = if (value < 0)
        @intCast(-@as(i128, value))
    else
        @intCast(value);
    std.mem.writeInt(
        u64,
        output,
        magnitude | if (value < 0) @as(u64, 1) << 63 else 0,
        .little,
    );
}

test "Android OTA BSDF2 applies mixed Brotli and Bzip2 streams" {
    const allocator = std.testing.allocator;
    const source = "abcdefghijklmnop";
    const expected = "abcXYZghij++mnopTAIL";
    const patch = try testPatchAlloc(
        allocator,
        .{ .bzip2, .brotli, .brotli },
        &.{
            .{ .diff_size = 10, .extra_size = 2, .source_advance = 2 },
            .{ .diff_size = 4, .extra_size = 4, .source_advance = 0 },
        },
        &.{ 0, 0, 0, 244, 244, 244, 0, 0, 0, 0, 0, 0, 0, 0 },
        "++TAIL",
        expected.len,
    );
    defer allocator.free(patch);
    try std.testing.expectError(
        error.SizeMismatch,
        applyAlloc(
            allocator,
            source,
            patch,
            expected.len - 1,
            .{ .max_output_len = 1024, .max_control_bytes = 1024 },
        ),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        applyAlloc(
            allocator,
            source,
            patch,
            expected.len,
            .{ .max_output_len = 1024, .max_control_bytes = 47 },
        ),
    );
    const decoded = try applyAlloc(
        allocator,
        source,
        patch,
        expected.len,
        .{ .max_output_len = 1024, .max_control_bytes = 1024 },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

test "Android OTA BSDIFF40 supports out of range source bytes" {
    const allocator = std.testing.allocator;
    const patch = try testPatchAlloc(
        allocator,
        .{ .bzip2, .bzip2, .bzip2 },
        &.{
            .{ .diff_size = 2, .extra_size = 0, .source_advance = -4 },
            .{ .diff_size = 4, .extra_size = 0, .source_advance = 0 },
        },
        "ABCDEF",
        "",
        6,
    );
    defer allocator.free(patch);
    @memcpy(patch[0..8], "BSDIFF40");
    const decoded = try applyAlloc(
        allocator,
        "\x01\x02",
        patch,
        6,
        .{ .max_output_len = 6, .max_control_bytes = 1024 },
    );
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(
        u8,
        &.{ 'B', 'D', 'C', 'D', 'F', 'H' },
        decoded,
    );
}

test "Android OTA bsdiff rejects malformed and unbounded patches" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.TruncatedFrame,
        applyAlloc(
            allocator,
            "",
            "BSDF2",
            0,
            .{ .max_output_len = 0, .max_control_bytes = 0 },
        ),
    );
    var bad_type = [_]u8{0} ** 32;
    @memcpy(bad_type[0..5], "BSDF2");
    bad_type[5] = 99;
    try std.testing.expectError(
        error.UnsupportedBsdiffCompression,
        applyAlloc(
            allocator,
            "",
            &bad_type,
            0,
            .{ .max_output_len = 0, .max_control_bytes = 0 },
        ),
    );
}

const TestControl = struct {
    diff_size: i64,
    extra_size: i64,
    source_advance: i64,
};

fn testPatchAlloc(
    allocator: std.mem.Allocator,
    compressors: [3]Compressor,
    controls: []const TestControl,
    diff: []const u8,
    extra: []const u8,
    output_len: usize,
) ![]u8 {
    var control_bytes: std.ArrayList(u8) = .empty;
    defer control_bytes.deinit(allocator);
    for (controls) |control| {
        var encoded: [24]u8 = undefined;
        appendSignedMagnitude(encoded[0..8], control.diff_size);
        appendSignedMagnitude(encoded[8..16], control.extra_size);
        appendSignedMagnitude(encoded[16..24], control.source_advance);
        try control_bytes.appendSlice(allocator, &encoded);
    }
    const inputs = [3][]const u8{ control_bytes.items, diff, extra };
    var compressed: [3][]u8 = undefined;
    var initialized: usize = 0;
    defer for (compressed[0..initialized]) |bytes| allocator.free(bytes);
    for (inputs, compressors, 0..) |input, compressor, index| {
        compressed[index] = switch (compressor) {
            .bzip2 => try bzip2.encodeAlloc(allocator, input, .{}),
            .brotli => try br.encodeStoredStreamAlloc(allocator, input),
        };
        initialized += 1;
    }
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    try output.appendSlice(allocator, "BSDF2");
    for (compressors) |compressor|
        try output.append(allocator, @intFromEnum(compressor));
    var header_values: [24]u8 = undefined;
    appendSignedMagnitude(header_values[0..8], @intCast(compressed[0].len));
    appendSignedMagnitude(header_values[8..16], @intCast(compressed[1].len));
    appendSignedMagnitude(header_values[16..24], @intCast(output_len));
    try output.appendSlice(allocator, &header_values);
    for (compressed) |bytes| try output.appendSlice(allocator, bytes);
    return output.toOwnedSlice(allocator);
}
