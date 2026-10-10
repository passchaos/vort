const std = @import("std");
const archive = @import("archive.zig");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidArEntryName,
    ArHeaderFieldOverflow,
};

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    timestamp: u64 = 0,
    owner: u32 = 0,
    group: u32 = 0,
    mode: u32 = 0o100644,
};

pub fn encodeAlloc(allocator: std.mem.Allocator, entries: []const EncodeEntry) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, entries);
    return output.toOwnedSlice(allocator);
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const EncodeEntry,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    try output.appendSlice(allocator, archive.signature);
    for (entries) |entry| try appendEntry(allocator, output, entry);
    return output.items.len - start;
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    entries: []const EncodeEntry,
    output: []u8,
) Error!usize {
    const encoded = try encodeAlloc(allocator, entries);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

fn appendEntry(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EncodeEntry,
) Error!void {
    try validateName(entry.name);
    const simple = simpleName(entry.name);
    var name_field: [16]u8 = @splat(' ');
    const stored_size = if (simple)
        entry.data.len
    else
        std.math.add(usize, entry.name.len, entry.data.len) catch return error.IntegerOverflow;
    if (simple) {
        @memcpy(name_field[0..entry.name.len], entry.name);
        name_field[entry.name.len] = '/';
    } else {
        var prefix_buffer: [16]u8 = undefined;
        const prefix = std.fmt.bufPrint(&prefix_buffer, "#1/{d}", .{entry.name.len}) catch
            return error.ArHeaderFieldOverflow;
        if (prefix.len > name_field.len) return error.ArHeaderFieldOverflow;
        @memcpy(name_field[0..prefix.len], prefix);
    }
    try output.appendSlice(allocator, &name_field);
    try appendDecimalField(allocator, output, entry.timestamp, 12);
    try appendDecimalField(allocator, output, entry.owner, 6);
    try appendDecimalField(allocator, output, entry.group, 6);
    try appendOctalField(allocator, output, entry.mode, 8);
    try appendDecimalField(allocator, output, stored_size, 10);
    try output.appendSlice(allocator, "`\n");
    if (!simple) try output.appendSlice(allocator, entry.name);
    try output.appendSlice(allocator, entry.data);
    if (stored_size & 1 != 0) try output.append(allocator, '\n');
}

fn validateName(name: []const u8) Error!void {
    if (name.len == 0 or std.mem.indexOfScalar(u8, name, 0) != null or
        std.mem.indexOfScalar(u8, name, '\n') != null)
        return error.InvalidArEntryName;
}

fn simpleName(name: []const u8) bool {
    return name.len <= 15 and std.mem.indexOfAny(u8, name, "/ ") == null and
        !std.mem.startsWith(u8, name, "#1/");
}

fn appendDecimalField(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: anytype,
    width: usize,
) Error!void {
    var buffer: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{d}", .{value}) catch
        return error.ArHeaderFieldOverflow;
    try appendTextField(allocator, output, text, width);
}

fn appendOctalField(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    value: anytype,
    width: usize,
) Error!void {
    var buffer: [32]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "{o}", .{value}) catch
        return error.ArHeaderFieldOverflow;
    try appendTextField(allocator, output, text, width);
}

fn appendTextField(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    text: []const u8,
    width: usize,
) Error!void {
    if (text.len > width) return error.ArHeaderFieldOverflow;
    try output.appendSlice(allocator, text);
    try output.appendNTimes(allocator, ' ', width - text.len);
}

test "ar writer round trips simple long and odd-sized entries" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{
        .{ .name = "short.o", .data = "even", .mode = 0o100600 },
        .{ .name = "path/long archive member name.txt", .data = "odd" },
    };
    const encoded = try encodeAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    try std.testing.expectEqual(entries.len, parsed.entry_count);
    for (entries, 0..) |expected, index| {
        const entry = try parsed.entryAt(index);
        try std.testing.expectEqualStrings(expected.name, entry.name);
        const data = try parsed.extractAlloc(allocator, entry);
        defer allocator.free(data);
        try std.testing.expectEqualSlices(u8, expected.data, data);
    }
    var too_small: [8]u8 = undefined;
    try std.testing.expectError(
        error.OutputTooSmall,
        encodeInto(allocator, &entries, &too_small),
    );
}
