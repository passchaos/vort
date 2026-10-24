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

pub const Entry = struct {
    name: []const u8,
    data: []const u8 = "",
    symbols: []const []const u8 = &.{},
    timestamp: u64 = 0,
    owner: u32 = 0,
    group: u32 = 0,
    mode: u32 = 0o100644,
};

pub const SymbolIndexFormat = enum {
    auto,
    bsd32,
    bsd32_sorted,
    bsd64,
    bsd64_sorted,
};

pub const Options = struct {
    symbol_index_format: SymbolIndexFormat = .auto,
};

pub fn shouldUse(entries: []const Entry, options: Options) bool {
    if (options.symbol_index_format != .auto) return true;
    for (entries) |entry| if (entry.symbols.len != 0) return true;
    return false;
}

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entries: []const Entry,
    options: Options,
) Error!usize {
    const start = output.items.len;
    errdefer output.items.len = start;
    const stats = try collectStats(entries);
    const offsets = try allocator.alloc(usize, entries.len);
    defer allocator.free(offsets);

    var format = requestedFormat(options.symbol_index_format) orelse
        symbol_table.Format.bsd32;
    var layout = try plan(entries, stats, format, offsets);
    if (options.symbol_index_format == .auto and !layout.fits_word) {
        format = .bsd64;
        layout = try plan(entries, stats, format, offsets);
    }
    if (!layout.fits_word) return error.ArSymbolIndexOverflow;

    const symbols = try allocator.alloc(SymbolRef, stats.symbol_count);
    defer allocator.free(symbols);
    fillSymbolRefs(entries, symbols);
    if (format.sorted()) std.mem.sort(SymbolRef, symbols, {}, symbolLessThan);

    try output.appendSlice(allocator, archive.signature);
    try appendSymbolTable(
        allocator,
        output,
        layout,
        offsets,
        symbols,
    );
    for (entries, offsets) |entry, header_offset| {
        const name_storage_len = try nameStorageLen(header_offset, entry.name.len);
        try appendMemberHeader(
            allocator,
            output,
            entry.name,
            name_storage_len,
            entry.timestamp,
            entry.owner,
            entry.group,
            entry.mode,
            entry.data.len,
        );
        try output.appendSlice(allocator, entry.data);
        const stored_size = std.math.add(usize, name_storage_len, entry.data.len) catch
            return error.IntegerOverflow;
        if (stored_size & 1 != 0) try output.append(allocator, '\n');
    }
    return output.items.len - start;
}

const Stats = struct {
    symbol_count: usize,
    symbol_names_len: usize,
};

const Layout = struct {
    format: symbol_table.Format,
    symbol_payload_len: usize,
    symbol_name_storage_len: usize,
    fits_word: bool,
};

const SymbolRef = struct {
    name: []const u8,
    entry_index: usize,
    ordinal: usize,
};

fn collectStats(entries: []const Entry) Error!Stats {
    var symbol_count: usize = 0;
    var symbol_names_len: usize = 0;
    for (entries) |entry| {
        try validateEntryName(entry.name);
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
    return .{
        .symbol_count = symbol_count,
        .symbol_names_len = symbol_names_len,
    };
}

fn requestedFormat(requested: SymbolIndexFormat) ?symbol_table.Format {
    return switch (requested) {
        .auto => null,
        .bsd32 => .bsd32,
        .bsd32_sorted => .bsd32_sorted,
        .bsd64 => .bsd64,
        .bsd64_sorted => .bsd64_sorted,
    };
}

fn plan(
    entries: []const Entry,
    stats: Stats,
    format: symbol_table.Format,
    offsets: []usize,
) Error!Layout {
    const word_len = format.wordLen();
    const record_words = std.math.mul(usize, stats.symbol_count, 2) catch
        return error.IntegerOverflow;
    const record_bytes = std.math.mul(usize, record_words, word_len) catch
        return error.IntegerOverflow;
    var raw_payload_len = std.math.add(usize, word_len, record_bytes) catch
        return error.IntegerOverflow;
    raw_payload_len = std.math.add(usize, raw_payload_len, word_len) catch
        return error.IntegerOverflow;
    raw_payload_len = std.math.add(usize, raw_payload_len, stats.symbol_names_len) catch
        return error.IntegerOverflow;
    const symbol_payload_len = try alignForward(raw_payload_len, 8);
    const symbol_name_storage_len = try nameStorageLen(
        archive.signature.len,
        format.memberName().len,
    );
    const symbol_stored_size = std.math.add(
        usize,
        symbol_name_storage_len,
        symbol_payload_len,
    ) catch return error.IntegerOverflow;
    var position = std.math.add(
        usize,
        archive.signature.len + archive.header_size,
        symbol_stored_size,
    ) catch return error.IntegerOverflow;
    position = std.math.add(usize, position, symbol_stored_size & 1) catch
        return error.IntegerOverflow;

    var fits_word = if (word_len == 4)
        stats.symbol_count <= std.math.maxInt(u32) and
            stats.symbol_names_len <= std.math.maxInt(u32) and
            record_bytes <= std.math.maxInt(u32)
    else
        true;
    for (entries, offsets) |entry, *offset| {
        offset.* = position;
        if (word_len == 4 and position > std.math.maxInt(u32)) fits_word = false;
        const stored_name_len = try nameStorageLen(position, entry.name.len);
        const stored_size = std.math.add(usize, stored_name_len, entry.data.len) catch
            return error.IntegerOverflow;
        position = std.math.add(usize, position, archive.header_size) catch
            return error.IntegerOverflow;
        position = std.math.add(usize, position, stored_size) catch
            return error.IntegerOverflow;
        position = std.math.add(usize, position, stored_size & 1) catch
            return error.IntegerOverflow;
    }
    return .{
        .format = format,
        .symbol_payload_len = symbol_payload_len,
        .symbol_name_storage_len = symbol_name_storage_len,
        .fits_word = fits_word,
    };
}

fn fillSymbolRefs(entries: []const Entry, symbols: []SymbolRef) void {
    var symbol_index: usize = 0;
    for (entries, 0..) |entry, entry_index| {
        for (entry.symbols, 0..) |name, ordinal| {
            symbols[symbol_index] = .{
                .name = name,
                .entry_index = entry_index,
                .ordinal = ordinal,
            };
            symbol_index += 1;
        }
    }
}

fn symbolLessThan(_: void, a: SymbolRef, b: SymbolRef) bool {
    return switch (std.mem.order(u8, a.name, b.name)) {
        .lt => true,
        .gt => false,
        .eq => if (a.entry_index != b.entry_index)
            a.entry_index < b.entry_index
        else
            a.ordinal < b.ordinal,
    };
}

fn appendSymbolTable(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    layout: Layout,
    member_offsets: []const usize,
    symbols: []const SymbolRef,
) Error!void {
    try appendMemberHeader(
        allocator,
        output,
        layout.format.memberName(),
        layout.symbol_name_storage_len,
        0,
        0,
        0,
        0,
        layout.symbol_payload_len,
    );
    const payload_start = output.items.len;
    const record_bytes = std.math.mul(
        usize,
        symbols.len,
        layout.format.wordLen() * 2,
    ) catch return error.IntegerOverflow;
    try appendLittleWord(allocator, output, layout.format, record_bytes);

    var string_offset: usize = 0;
    for (symbols) |symbol| {
        try appendLittleWord(allocator, output, layout.format, string_offset);
        try appendLittleWord(
            allocator,
            output,
            layout.format,
            member_offsets[symbol.entry_index],
        );
        string_offset = std.math.add(usize, string_offset, symbol.name.len + 1) catch
            return error.IntegerOverflow;
    }
    try appendLittleWord(allocator, output, layout.format, string_offset);
    for (symbols) |symbol| {
        try output.appendSlice(allocator, symbol.name);
        try output.append(allocator, 0);
    }
    try output.appendNTimes(
        allocator,
        0,
        layout.symbol_payload_len - (output.items.len - payload_start),
    );
    std.debug.assert(output.items.len - payload_start == layout.symbol_payload_len);
}

fn appendMemberHeader(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    name: []const u8,
    name_storage_len: usize,
    timestamp: u64,
    owner: u32,
    group: u32,
    mode: u32,
    data_size: usize,
) Error!void {
    const stored_size = std.math.add(usize, name_storage_len, data_size) catch
        return error.IntegerOverflow;
    var name_field: [16]u8 = undefined;
    const header_name = std.fmt.bufPrint(&name_field, "#1/{d}", .{name_storage_len}) catch
        return error.ArHeaderFieldOverflow;
    try appendTextField(allocator, output, header_name, 16);
    try appendDecimalField(allocator, output, timestamp, 12);
    try appendDecimalField(allocator, output, owner, 6);
    try appendDecimalField(allocator, output, group, 6);
    try appendOctalField(allocator, output, mode, 8);
    try appendDecimalField(allocator, output, stored_size, 10);
    try output.appendSlice(allocator, "`\n");
    try output.appendSlice(allocator, name);
    try output.appendNTimes(allocator, 0, name_storage_len - name.len);
}

fn nameStorageLen(header_offset: usize, name_len: usize) Error!usize {
    const header_end = std.math.add(usize, header_offset, archive.header_size) catch
        return error.IntegerOverflow;
    const name_end = std.math.add(usize, header_end, name_len) catch
        return error.IntegerOverflow;
    const aligned = try alignForward(name_end, 8);
    return std.math.add(usize, name_len, aligned - name_end) catch
        return error.IntegerOverflow;
}

fn alignForward(value: usize, alignment: usize) Error!usize {
    const remainder = value & (alignment - 1);
    const padding = if (remainder == 0) 0 else alignment - remainder;
    return std.math.add(usize, value, padding) catch error.IntegerOverflow;
}

fn appendLittleWord(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    format: symbol_table.Format,
    value: usize,
) Error!void {
    switch (format) {
        .bsd32, .bsd32_sorted => {
            const narrowed = std.math.cast(u32, value) orelse
                return error.ArSymbolIndexOverflow;
            var bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &bytes, narrowed, .little);
            try output.appendSlice(allocator, &bytes);
        },
        .bsd64, .bsd64_sorted => {
            const narrowed = std.math.cast(u64, value) orelse
                return error.ArSymbolIndexOverflow;
            var bytes: [8]u8 = undefined;
            std.mem.writeInt(u64, &bytes, narrowed, .little);
            try output.appendSlice(allocator, &bytes);
        },
        else => unreachable,
    }
}

fn validateEntryName(name: []const u8) Error!void {
    if (name.len == 0 or std.mem.indexOfScalar(u8, name, 0) != null or
        std.mem.indexOfScalar(u8, name, '\n') != null)
        return error.InvalidArEntryName;
}

fn validateSymbolName(name: []const u8) Error!void {
    if (name.len == 0 or std.mem.indexOfScalar(u8, name, 0) != null)
        return error.InvalidArSymbolName;
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
