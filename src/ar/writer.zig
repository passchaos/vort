const std = @import("std");
const archive = @import("archive.zig");
const core = @import("../core.zig");
const symbol_table = @import("symbol_table.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidArEntryName,
    InvalidArSymbolName,
    ArHeaderFieldOverflow,
    ArSymbolIndexOverflow,
};

pub const EncodeEntry = struct {
    name: []const u8,
    data: []const u8 = "",
    timestamp: u64 = 0,
    owner: u32 = 0,
    group: u32 = 0,
    mode: u32 = 0o100644,
};

pub const ThinEncodeEntry = struct {
    name: []const u8,
    size: usize,
    symbols: []const []const u8 = &.{},
    timestamp: u64 = 0,
    owner: u32 = 0,
    group: u32 = 0,
    mode: u32 = 0o100644,
};

pub const ThinSymbolIndexFormat = enum {
    auto,
    gnu32,
    gnu64,
};

pub const ThinEncodeOptions = struct {
    symbol_index_format: ThinSymbolIndexFormat = .auto,
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

pub fn encodeThinAlloc(
    allocator: std.mem.Allocator,
    entries: []const ThinEncodeEntry,
) Error![]u8 {
    return encodeThinAllocWithOptions(allocator, entries, .{});
}

pub fn encodeThinAllocWithOptions(
    allocator: std.mem.Allocator,
    entries: []const ThinEncodeEntry,
    options: ThinEncodeOptions,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeThinAppendWithOptions(allocator, &output, entries, options);
    return output.toOwnedSlice(allocator);
}

pub fn encodeThinAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const ThinEncodeEntry,
) Error!usize {
    return encodeThinAppendWithOptions(allocator, output, entries, .{});
}

pub fn encodeThinAppendWithOptions(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const ThinEncodeEntry,
    options: ThinEncodeOptions,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    const layout = try planThin(entries, options);
    try output.appendSlice(allocator, archive.thin_signature);
    if (entries.len == 0) return output.items.len - start;

    if (layout.symbol_format) |format| {
        try appendHeader(
            allocator,
            output,
            format.memberName(),
            0,
            0,
            0,
            0,
            layout.symbol_payload_len,
        );
        const payload_start = output.items.len;
        try appendSymbolWord(allocator, output, format, layout.symbol_count);
        for (entries, 0..) |entry, entry_index| {
            const member_offset = layout.first_member_offset + entry_index * archive.header_size;
            for (entry.symbols) |_| try appendSymbolWord(
                allocator,
                output,
                format,
                member_offset,
            );
        }
        for (entries) |entry| for (entry.symbols) |symbol| {
            try output.appendSlice(allocator, symbol);
            try output.append(allocator, 0);
        };
        if ((output.items.len - payload_start) & 1 != 0)
            try output.append(allocator, 0);
        std.debug.assert(output.items.len - payload_start == layout.symbol_payload_len);
    }

    try appendHeader(allocator, output, "//", 0, 0, 0, 0, layout.string_table_len);
    for (entries) |entry| {
        try output.appendSlice(allocator, entry.name);
        try output.appendSlice(allocator, "/\n");
    }
    if (layout.string_table_len & 1 != 0) try output.append(allocator, '\n');

    var name_offset: usize = 0;
    for (entries) |entry| {
        var name_buffer: [16]u8 = undefined;
        const name = std.fmt.bufPrint(&name_buffer, "/{d}", .{name_offset}) catch
            return error.ArHeaderFieldOverflow;
        try appendHeader(
            allocator,
            output,
            name,
            entry.timestamp,
            entry.owner,
            entry.group,
            entry.mode,
            entry.size,
        );
        name_offset += entry.name.len + 2;
    }
    return output.items.len - start;
}

pub fn encodeThinInto(
    allocator: std.mem.Allocator,
    entries: []const ThinEncodeEntry,
    output: []u8,
) Error!usize {
    return encodeThinIntoWithOptions(allocator, entries, .{}, output);
}

pub fn encodeThinIntoWithOptions(
    allocator: std.mem.Allocator,
    entries: []const ThinEncodeEntry,
    options: ThinEncodeOptions,
    output: []u8,
) Error!usize {
    const encoded = try encodeThinAllocWithOptions(allocator, entries, options);
    defer allocator.free(encoded);
    if (output.len < encoded.len) return error.OutputTooSmall;
    @memcpy(output[0..encoded.len], encoded);
    return encoded.len;
}

const ThinLayout = struct {
    string_table_len: usize,
    symbol_count: usize,
    symbol_format: ?symbol_table.Format,
    symbol_payload_len: usize,
    first_member_offset: usize,
};

fn planThin(entries: []const ThinEncodeEntry, options: ThinEncodeOptions) Error!ThinLayout {
    var string_table_len: usize = 0;
    var symbol_count: usize = 0;
    var symbol_names_len: usize = 0;
    for (entries) |entry| {
        try validateName(entry.name);
        const table_name_len = std.math.add(usize, entry.name.len, 2) catch
            return error.IntegerOverflow;
        string_table_len = std.math.add(usize, string_table_len, table_name_len) catch
            return error.IntegerOverflow;
        symbol_count = std.math.add(usize, symbol_count, entry.symbols.len) catch
            return error.IntegerOverflow;
        for (entry.symbols) |symbol| {
            try validateSymbolName(symbol);
            const terminated_len = std.math.add(usize, symbol.len, 1) catch
                return error.IntegerOverflow;
            symbol_names_len = std.math.add(usize, symbol_names_len, terminated_len) catch
                return error.IntegerOverflow;
        }
    }

    const string_member_len = try paddedMemberLen(string_table_len);
    if (symbol_count == 0) return .{
        .string_table_len = string_table_len,
        .symbol_count = 0,
        .symbol_format = null,
        .symbol_payload_len = 0,
        .first_member_offset = std.math.add(
            usize,
            archive.thin_signature.len,
            string_member_len,
        ) catch return error.IntegerOverflow,
    };

    const gnu32_payload_len = try symbolPayloadLen(symbol_count, symbol_names_len, .gnu32);
    const gnu32_first_member = try firstThinMemberOffset(gnu32_payload_len, string_member_len);
    const gnu32_fits = symbol_count <= std.math.maxInt(u32) and
        memberOffsetsFit(entries.len, gnu32_first_member, std.math.maxInt(u32));
    const format: symbol_table.Format = switch (options.symbol_index_format) {
        .auto => if (gnu32_fits) .gnu32 else .gnu64,
        .gnu32 => if (gnu32_fits) .gnu32 else return error.ArSymbolIndexOverflow,
        .gnu64 => .gnu64,
    };
    const symbol_payload_len = if (format == .gnu32)
        gnu32_payload_len
    else
        try symbolPayloadLen(symbol_count, symbol_names_len, .gnu64);
    const first_member_offset = if (format == .gnu32)
        gnu32_first_member
    else
        try firstThinMemberOffset(symbol_payload_len, string_member_len);
    if (!memberOffsetsFit(entries.len, first_member_offset, std.math.maxInt(u64)))
        return error.ArSymbolIndexOverflow;
    return .{
        .string_table_len = string_table_len,
        .symbol_count = symbol_count,
        .symbol_format = format,
        .symbol_payload_len = symbol_payload_len,
        .first_member_offset = first_member_offset,
    };
}

fn symbolPayloadLen(
    symbol_count: usize,
    symbol_names_len: usize,
    format: symbol_table.Format,
) Error!usize {
    const word_count = std.math.add(usize, symbol_count, 1) catch
        return error.IntegerOverflow;
    const words_len = std.math.mul(usize, word_count, format.wordLen()) catch
        return error.IntegerOverflow;
    const unpadded = std.math.add(usize, words_len, symbol_names_len) catch
        return error.IntegerOverflow;
    return std.math.add(usize, unpadded, unpadded & 1) catch
        return error.IntegerOverflow;
}

fn paddedMemberLen(payload_len: usize) Error!usize {
    const padded_payload_len = std.math.add(usize, payload_len, payload_len & 1) catch
        return error.IntegerOverflow;
    return std.math.add(usize, archive.header_size, padded_payload_len) catch
        return error.IntegerOverflow;
}

fn firstThinMemberOffset(symbol_payload_len: usize, string_member_len: usize) Error!usize {
    const symbol_member_len = try paddedMemberLen(symbol_payload_len);
    const metadata_len = std.math.add(usize, symbol_member_len, string_member_len) catch
        return error.IntegerOverflow;
    return std.math.add(usize, archive.thin_signature.len, metadata_len) catch
        return error.IntegerOverflow;
}

fn memberOffsetsFit(entry_count: usize, first: usize, maximum: u64) bool {
    if (entry_count == 0) return @as(u64, @intCast(first)) <= maximum;
    const delta = std.math.mul(usize, entry_count - 1, archive.header_size) catch
        return false;
    const last = std.math.add(usize, first, delta) catch return false;
    return @as(u64, @intCast(last)) <= maximum;
}

fn appendSymbolWord(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    format: symbol_table.Format,
    value: usize,
) Error!void {
    switch (format) {
        .gnu32 => {
            const narrowed = std.math.cast(u32, value) orelse
                return error.ArSymbolIndexOverflow;
            var bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &bytes, narrowed, .big);
            try output.appendSlice(allocator, &bytes);
        },
        .gnu64 => {
            const narrowed = std.math.cast(u64, value) orelse
                return error.ArSymbolIndexOverflow;
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &bytes, narrowed, .big);
            try output.appendSlice(allocator, &bytes);
        },
    }
}

fn appendHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    timestamp: u64,
    owner: u32,
    group: u32,
    mode: u32,
    size: usize,
) Error!void {
    if (name.len == 0 or name.len > 16) return error.ArHeaderFieldOverflow;
    try output.appendSlice(allocator, name);
    try output.appendNTimes(allocator, ' ', 16 - name.len);
    try appendDecimalField(allocator, output, timestamp, 12);
    try appendDecimalField(allocator, output, owner, 6);
    try appendDecimalField(allocator, output, group, 6);
    try appendOctalField(allocator, output, mode, 8);
    try appendDecimalField(allocator, output, size, 10);
    try output.appendSlice(allocator, "`\n");
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

fn validateSymbolName(name: []const u8) Error!void {
    if (name.len == 0 or std.mem.indexOfScalar(u8, name, 0) != null)
        return error.InvalidArSymbolName;
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

test "thin ar writer stores external metadata without embedding payloads" {
    const allocator = std.testing.allocator;
    const entries = [_]ThinEncodeEntry{
        .{ .name = "short.o", .size = 4 },
        .{ .name = "path/very-long-member-name.o", .size = 3 },
    };
    const encoded = try encodeThinAlloc(allocator, &entries);
    defer allocator.free(encoded);
    const parsed = try archive.parse(encoded);
    try std.testing.expect(parsed.thin);
    try std.testing.expectEqual(entries.len, parsed.entry_count);
    for (entries, 0..) |expected, index| {
        const entry = try parsed.entryAt(index);
        try std.testing.expect(entry.external);
        try std.testing.expectEqualStrings(expected.name, entry.name);
        try std.testing.expectEqual(expected.size, entry.size);
        try std.testing.expectEqual(@as(usize, 0), entry.stored_size);
        try std.testing.expectError(
            error.ArEntryRequiresResolver,
            parsed.extractAlloc(allocator, entry),
        );
    }
    const resolved = try parsed.extractThinAllocLimited(
        allocator,
        try parsed.entryAt(0),
        "data ignored suffix",
        4,
    );
    defer allocator.free(resolved);
    try std.testing.expectEqualStrings("data", resolved);
}
