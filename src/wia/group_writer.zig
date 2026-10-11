const std = @import("std");
const codec = @import("codec.zig");
const format = @import("format.zig");

pub const Error = format.Error || codec.Error || std.mem.Allocator.Error;

pub const Settings = struct {
    container: format.Container,
    compression: format.Compression,
    compression_level: i32,
    max_groups: usize,
};

pub fn appendRaw(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    groups: *std.ArrayList(format.GroupEntry),
    plain: []const u8,
    settings: Settings,
) Error!void {
    if (plain.len == 0) return error.InvalidWia;
    if (std.mem.allEqual(u8, plain, 0))
        return appendZero(allocator, groups, settings);

    const encoded = try codec.encodeAlloc(
        allocator,
        plain,
        settings.compression,
        settings.compression_level,
    );
    defer allocator.free(encoded);
    const use_compressed = settings.container == .wia or
        settings.compression == .none or encoded.len < plain.len;
    return appendStored(
        allocator,
        output,
        groups,
        if (use_compressed) encoded else plain,
        use_compressed and settings.compression != .none,
        settings,
    );
}

pub fn appendPartition(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    groups: *std.ArrayList(format.GroupEntry),
    exception_lists: []const u8,
    main_data: []const u8,
    settings: Settings,
) Error!void {
    if (exception_lists.len == 0 or main_data.len == 0)
        return error.InvalidWia;
    if (std.mem.allEqual(u8, exception_lists, 0) and
        std.mem.allEqual(u8, main_data, 0))
        return appendZero(allocator, groups, settings);

    var fallback: std.ArrayList(u8) = .empty;
    defer fallback.deinit(allocator);
    try fallback.appendSlice(allocator, exception_lists);
    try appendAlignment(allocator, &fallback, 4);
    const prefix_len = fallback.items.len;
    try fallback.appendSlice(allocator, main_data);

    switch (settings.compression) {
        .none => return appendStored(
            allocator,
            output,
            groups,
            fallback.items,
            false,
            settings,
        ),
        .purge => {
            if (settings.container != .wia)
                return error.UnsupportedWiaCodec;
            const encoded_main = try codec.encodePurgeWithHashPrefixAlloc(
                allocator,
                main_data,
                fallback.items[0..prefix_len],
            );
            defer allocator.free(encoded_main);
            var stored: std.ArrayList(u8) = .empty;
            defer stored.deinit(allocator);
            try stored.appendSlice(allocator, fallback.items[0..prefix_len]);
            try stored.appendSlice(allocator, encoded_main);
            return appendStored(
                allocator,
                output,
                groups,
                stored.items,
                true,
                settings,
            );
        },
        .bzip2, .lzma, .lzma2, .zstd => {
            var combined: std.ArrayList(u8) = .empty;
            defer combined.deinit(allocator);
            try combined.appendSlice(allocator, exception_lists);
            try combined.appendSlice(allocator, main_data);
            const encoded = try codec.encodeAlloc(
                allocator,
                combined.items,
                settings.compression,
                settings.compression_level,
            );
            defer allocator.free(encoded);
            const use_compressed = settings.container == .wia or
                encoded.len < fallback.items.len;
            return appendStored(
                allocator,
                output,
                groups,
                if (use_compressed) encoded else fallback.items,
                use_compressed,
                settings,
            );
        },
    }
}

fn appendZero(
    allocator: std.mem.Allocator,
    groups: *std.ArrayList(format.GroupEntry),
    settings: Settings,
) Error!void {
    try ensureGroupCapacity(groups.items.len, settings.max_groups);
    try groups.append(allocator, .{
        .data_offset = 0,
        .stored_size = 0,
        .compressed = settings.container == .wia and
            settings.compression != .none,
        .rvz_packed_size = 0,
    });
}

fn appendStored(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    groups: *std.ArrayList(format.GroupEntry),
    stored: []const u8,
    compressed: bool,
    settings: Settings,
) Error!void {
    try ensureGroupCapacity(groups.items.len, settings.max_groups);
    if (stored.len > 0x7fff_ffff) return error.OutputLimitExceeded;
    try appendAlignment(allocator, output, 4);
    if (output.items.len / 4 > std.math.maxInt(u32))
        return error.OutputLimitExceeded;
    try groups.append(allocator, .{
        .data_offset = output.items.len,
        .stored_size = stored.len,
        .compressed = compressed,
        .rvz_packed_size = 0,
    });
    try output.appendSlice(allocator, stored);
}

fn ensureGroupCapacity(group_count: usize, max_groups: usize) Error!void {
    if (group_count >= max_groups or group_count >= std.math.maxInt(u32))
        return error.OutputLimitExceeded;
}

fn appendAlignment(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    alignment: usize,
) std.mem.Allocator.Error!void {
    const remainder = output.items.len % alignment;
    if (remainder != 0)
        try output.appendNTimes(allocator, 0, alignment - remainder);
}
