const std = @import("std");
const h = @import("helpers.zig");

pub const Kind = enum { raw, zlib, gzip };

fn init(comptime E: type, allocator: std.mem.Allocator) E {
    var options: E.Options = .{};
    if (@hasField(E.Options, "raw")) {
        options.raw.block_len = 31;
        if (@hasField(E.Options, "header")) options.header = .{
            .extra = "clone-extra",
            .filename = "clone.bin",
            .comment = "independent branches",
            .header_crc = true,
        };
    } else options.block_len = 31;
    return E.initWithOptions(allocator, options);
}

fn expectDecoded(comptime D: type, allocator: std.mem.Allocator, comptime kind: Kind, wire: []const u8, expected: []const u8) !void {
    const decoded = switch (kind) {
        .raw => try D.decodeRawAutoAlloc(allocator, wire),
        .zlib => try D.decodeZlibAlloc(allocator, wire),
        .gzip => try D.decodeGzipAlloc(allocator, wire),
    };
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}

fn oom(comptime E: type, allocator: std.mem.Allocator, source: *const E) !void {
    var frozen = try source.clone(allocator);
    defer frozen.deinit();
    var destination = init(E, allocator);
    defer destination.deinit();
    const before_destination = destination;
    var failures: usize = 0;
    for (0..64) |index| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = index });
        if (source.clone(failing.allocator())) |value| {
            var copy = value;
            try h.expectEncoder(source, &copy, true);
            copy.deinit();
            try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
            try std.testing.expect(failures != 0);
            return;
        } else |err| {
            try std.testing.expectEqual(error.OutOfMemory, err);
            try std.testing.expect(failing.has_induced_failure);
            try std.testing.expectEqual(failing.allocated_bytes, failing.freed_bytes);
            try h.expectEncoder(source, &frozen, true);
            try h.expectEncoder(&before_destination, &destination, false);
            failures += 1;
        }
    }
    return error.TestUnexpectedResult;
}

fn branch(comptime D: type, comptime E: type, allocator: std.mem.Allocator, comptime kind: Kind) !void {
    try std.testing.expectEqual(std.mem.Allocator.Error, E.CloneError);
    var source = init(E, allocator);
    var source_alive = true;
    defer if (source_alive) source.deinit();
    if (@hasDecl(E, "supports_runtime_params") and E.supports_runtime_params)
        try source.requestParams(.{ .level = 6 });
    var prefix_wire: std.ArrayList(u8) = .empty;
    defer prefix_wire.deinit(allocator);
    var prefix_plain: std.ArrayList(u8) = .empty;
    defer prefix_plain.deinit(allocator);
    try prefix_plain.appendSlice(allocator, h.prefix);
    try h.feed(allocator, &source, h.prefix, &prefix_wire, 7);
    source.partialFlush();
    try h.drain(allocator, &source, &prefix_wire, 3, false);
    if (source.snapshot().pending_bits == 0) {
        try h.feed(allocator, &source, "\x90", &prefix_wire, 7);
        try prefix_plain.append(allocator, 0x90);
        source.partialFlush();
        try h.drain(allocator, &source, &prefix_wire, 3, false);
    }
    try std.testing.expect(source.snapshot().pending_bits != 0);
    var bits_copy = try source.clone(allocator);
    try h.expectEncoder(&source, &bits_copy, true);
    bits_copy.deinit();

    const buffered = "unpublished";
    try h.feed(allocator, &source, buffered, &prefix_wire, 7);
    try prefix_plain.appendSlice(allocator, buffered);
    if (@hasDecl(E, "supports_runtime_params") and E.supports_runtime_params) {
        try source.requestParams(.{ .level = 0 });
        try std.testing.expect(source.snapshot().params_boundary_pending);
    } else source.partialFlush();
    var one: [1]u8 = undefined;
    const pending = try source.step("", &one);
    try prefix_wire.appendSlice(allocator, one[0..pending.progress.output_written]);
    try std.testing.expect(source.snapshot().pending_output != 0);
    try oom(E, allocator, &source);
    var copy = try source.clone(allocator);
    defer copy.deinit();
    try h.expectEncoder(&source, &copy, true);
    if (@hasField(E.Options, "header")) {
        try std.testing.expectEqual(source.options.header.extra.?.ptr, copy.options.header.extra.?.ptr);
        try std.testing.expectEqual(source.options.header.filename.?.ptr, copy.options.header.filename.?.ptr);
    }
    var left_wire: std.ArrayList(u8) = .empty;
    defer left_wire.deinit(allocator);
    var right_wire: std.ArrayList(u8) = .empty;
    defer right_wire.deinit(allocator);
    try left_wire.appendSlice(allocator, prefix_wire.items);
    try right_wire.appendSlice(allocator, prefix_wire.items);
    try h.drain(allocator, &source, &left_wire, 1, false);
    source.fullFlush();
    try h.drain(allocator, &source, &left_wire, 3, false);
    try h.feed(allocator, &source, h.left, &left_wire, 2);
    try h.finish(allocator, &source, &left_wire, 1);
    const left_input = source.snapshot().input_read;
    source.deinit();
    source_alive = false;

    // The other stream is continued only after every source-owned allocation
    // is released, exercising allocator, matcher and bit-writer independence.
    try h.drain(allocator, &copy, &right_wire, 13, false);
    if (@hasDecl(E, "supports_runtime_params") and E.supports_runtime_params)
        try copy.requestParams(.{ .level = 1, .strategy = .rle });
    try h.drain(allocator, &copy, &right_wire, 13, false);
    try h.feed(allocator, &copy, h.right, &right_wire, 11);
    copy.partialFlush();
    try h.drain(allocator, &copy, &right_wire, 5, false);
    try h.finish(allocator, &copy, &right_wire, 17);
    try std.testing.expectEqual(prefix_plain.items.len + h.left.len, left_input);
    try std.testing.expectEqual(prefix_plain.items.len + h.right.len, copy.snapshot().input_read);
    const left_plain = try std.mem.concat(allocator, u8, &.{ prefix_plain.items, h.left });
    defer allocator.free(left_plain);
    const right_plain = try std.mem.concat(allocator, u8, &.{ prefix_plain.items, h.right });
    defer allocator.free(right_plain);
    try expectDecoded(D, allocator, kind, left_wire.items, left_plain);
    try expectDecoded(D, allocator, kind, right_wire.items, right_plain);
}

fn retainedEmpty(comptime E: type, allocator: std.mem.Allocator) !void {
    var source = init(E, allocator);
    defer source.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(allocator);
    try h.feed(allocator, &source, h.prefix, &wire, 17);
    try h.finish(allocator, &source, &wire, 17);
    source.reset();
    var copy = try source.clone(allocator);
    defer copy.deinit();
    try h.expectEncoder(&source, &copy, true);
    try std.testing.expectEqual(@as(usize, 0), h.rawOf(&copy).plain.items.len);
    try std.testing.expect(h.rawOf(&copy).plain.capacity != 0);
    // Allocation failures must also clean up reserved, currently empty lists.
    try oom(E, allocator, &source);
}

fn dictionary(comptime D: type, comptime E: type, allocator: std.mem.Allocator, comptime wrapped: bool) !void {
    const literal = "immutable raw and zlib preset dictionary";
    const bytes: []const u8 = literal;
    const payload = literal ** 3;
    var source = E.initWithDictionary(allocator, .{}, bytes);
    var source_alive = true;
    defer if (source_alive) source.deinit();
    var source_wire: std.ArrayList(u8) = .empty;
    defer source_wire.deinit(allocator);
    try h.feed(allocator, &source, payload, &source_wire, 5);
    var copy = try source.clone(allocator);
    defer copy.deinit();
    try std.testing.expectEqual(bytes.ptr, h.rawOf(&copy).dictionary.ptr);
    try std.testing.expectEqual(h.rawOf(&source).dictionary.ptr, h.rawOf(&copy).dictionary.ptr);
    var copy_wire: std.ArrayList(u8) = .empty;
    defer copy_wire.deinit(allocator);
    try copy_wire.appendSlice(allocator, source_wire.items);
    try h.finish(allocator, &source, &source_wire, 1);
    source.deinit();
    source_alive = false;
    try h.finish(allocator, &copy, &copy_wire, 13);
    try std.testing.expectEqualSlices(u8, source_wire.items, copy_wire.items);
    const decoded = if (wrapped)
        try D.decodeZlibAllocWithDictionary(allocator, copy_wire.items, bytes)
    else
        try D.decodeRawAutoAllocWithDictionary(allocator, copy_wire.items, bytes);
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, payload, decoded);
    copy.reset();
    try std.testing.expectEqual(bytes.ptr, h.rawOf(&copy).dictionary.ptr);
    copy_wire.clearRetainingCapacity();
    try h.feed(allocator, &copy, payload, &copy_wire, 17);
    try h.finish(allocator, &copy, &copy_wire, 17);
    try std.testing.expectEqualSlices(u8, source_wire.items, copy_wire.items);
}

pub fn contracts(comptime D: type, allocator: std.mem.Allocator) !void {
    inline for (.{
        .{ D.RawDeflateIncrementalStoredEncoder, Kind.raw },
        .{ D.RawDeflateIncrementalFixedEncoder, Kind.raw },
        .{ D.RawDeflateIncrementalBestEncoder, Kind.raw },
        .{ D.ZlibIncrementalFixedEncoder, Kind.zlib },
        .{ D.ZlibIncrementalBestEncoder, Kind.zlib },
        .{ D.GzipIncrementalFixedEncoder, Kind.gzip },
        .{ D.GzipIncrementalBestEncoder, Kind.gzip },
    }) |entry| {
        try branch(D, entry[0], allocator, entry[1]);
        try retainedEmpty(entry[0], allocator);
    }
    inline for (.{ D.RawDeflateIncrementalFixedEncoder, D.RawDeflateIncrementalBestEncoder }) |E|
        try dictionary(D, E, allocator, false);
    inline for (.{ D.ZlibIncrementalFixedEncoder, D.ZlibIncrementalBestEncoder }) |E|
        try dictionary(D, E, allocator, true);
}
