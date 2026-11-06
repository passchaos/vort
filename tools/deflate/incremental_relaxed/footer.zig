const std = @import("std");
const h = @import("driver.zig");
const ref = @import("reference.zig");

pub fn run(a: std.mem.Allocator, counts: *h.Counts) !void {
    const raw = try ref.deflate(a, .raw, h.payload, null);
    defer a.free(raw);
    const raw_plain = try h.D.decodeRawAutoAlloc(a, raw);
    defer a.free(raw_plain);
    try h.equal(h.payload, raw_plain);
    counts.valid_splits += 1;
    inline for (.{ ref.Wrapper.zlib, ref.Wrapper.gzip }) |wrapper| {
        const wire = try ref.deflate(a, wrapper, h.payload, null);
        defer a.free(wire);
        try h.require(try ref.inflate(wrapper, wire) == .complete);
        const footer_len: usize = if (wrapper == .zlib) 4 else 8;
        const footer_at = wire.len - footer_len;
        if (wrapper == .zlib) {
            try h.require(std.mem.readInt(u32, wire[footer_at..][0..4], .big) == ref.adler(h.payload));
        } else {
            try h.require(std.mem.readInt(u32, wire[footer_at..][0..4], .little) == ref.crc(h.payload));
            try h.require(std.mem.readInt(u32, wire[footer_at + 4 ..][0..4], .little) == h.payload.len);
        }
        // Every external compressed/header/footer split, plus one-byte input.
        for (0..wire.len + 1) |split| try valid(wrapper, wire, split, wire.len, counts);
        try valid(wrapper, wire, wire.len, 1, counts);
        const combinations: usize = if (wrapper == .zlib) 2 else 4;
        for (0..combinations) |ignored| {
            for ([_]bool{ false, true }) |allow_trailing| {
                for (0..combinations) |corrupt| {
                    const changed = try a.dupe(u8, wire);
                    defer a.free(changed);
                    changed[footer_at] ^= @intFromBool(corrupt & 1 != 0);
                    if (wrapper == .gzip) changed[footer_at + 4] ^= @intFromBool(corrupt & 2 != 0);
                    const expected: ?anyerror = if (corrupt & 1 != 0 and ignored & 1 == 0) error.ChecksumMismatch else if (wrapper == .gzip and corrupt & 2 != 0 and ignored & 2 == 0) error.SizeMismatch else null;
                    if (corrupt != 0) try h.require(try ref.inflate(wrapper, changed) == .data);
                    for (0..footer_len + 1) |split| {
                        var history: [32768]u8 = undefined;
                        var output: [h.payload.len]u8 = undefined;
                        const Decoder = h.Decoder(wrapper);
                        var options: Decoder.Options = .{ .allow_trailing_data = allow_trailing };
                        if (wrapper == .zlib) options.ignore_adler = ignored & 1 != 0 else {
                            options.ignore_crc32 = ignored & 1 != 0;
                            options.ignore_isize = ignored & 2 != 0;
                        }
                        var decoder = try Decoder.init(options, &history);
                        var cursor: h.Cursor = .{};
                        const status = completeSplit(&decoder, changed, &output, &cursor, footer_at + split, counts);
                        if (expected) |err| {
                            if (status) |_| return error.ExpectedFooterRefusal else |actual| try h.require(actual == err);
                            try h.require(decoder.memberEndOffset() == null);
                        } else {
                            try status;
                            try decoder.finish();
                            try h.require(decoder.memberEndOffset() == wire.len);
                        }
                        try h.equal(h.payload, output[0..cursor.written]);
                        try h.hash(wrapper, &decoder, &output);
                        try h.require(cursor.read == wire.len and decoder.snapshot().total_input == wire.len);
                        try h.require(decoder.snapshot().footer_received == footer_len);
                        counts.footer_matrix += 1;
                    }
                }
                // Ignoring comparisons never exempts a partial footer.
                for (0..footer_len) |received| {
                    var history: [32768]u8 = undefined;
                    var output: [h.payload.len]u8 = undefined;
                    const Decoder = h.Decoder(wrapper);
                    var options: Decoder.Options = .{ .allow_trailing_data = allow_trailing };
                    if (wrapper == .zlib) options.ignore_adler = ignored & 1 != 0 else {
                        options.ignore_crc32 = ignored & 1 != 0;
                        options.ignore_isize = ignored & 2 != 0;
                    }
                    var decoder = try Decoder.init(options, &history);
                    var cursor: h.Cursor = .{};
                    try h.pump(&decoder, wire, &output, &cursor, footer_at + received, 1, counts);
                    try h.equal(h.payload, output[0..cursor.written]);
                    try h.hash(wrapper, &decoder, &output);
                    try h.require(decoder.snapshot().footer_received == received and decoder.memberEndOffset() == null);
                    if (decoder.finish()) |_| return error.ExpectedPartialFooterRefusal else |err| try h.require(err == error.TruncatedFrame);
                    try h.sealed(&decoder, counts);
                    counts.partial_footers += 1;
                }
            }
        }
        const bad = try a.dupe(u8, wire);
        defer a.free(bad);
        const offset: usize = if (wrapper == .zlib) 2 else 10;
        bad[offset] = (bad[offset] & ~@as(u8, 6)) | 6;
        try h.require(try ref.inflate(wrapper, bad) == .data);
        var history: [32768]u8 = undefined;
        var output: [h.payload.len]u8 = undefined;
        const Decoder = h.Decoder(wrapper);
        var options: Decoder.Options = .{ .allow_trailing_data = true };
        if (wrapper == .zlib) options.ignore_adler = true else {
            options.ignore_crc32 = true;
            options.ignore_isize = true;
        }
        var decoder = try Decoder.init(options, &history);
        var cursor: h.Cursor = .{};
        if (h.pump(&decoder, bad, &output, &cursor, bad.len, 1, counts)) |_| return error.ExpectedMalformedPayloadRefusal else |err| try h.require(err == error.InvalidDeflateBlockType);
        try h.require(decoder.memberEndOffset() == null);
        counts.malformed_payloads += 1;
    }
}

fn completeSplit(decoder: anytype, wire: []const u8, output: []u8, cursor: *h.Cursor, split: usize, counts: *h.Counts) !void {
    try h.pump(decoder, wire, output, cursor, split, wire.len, counts);
    try h.pump(decoder, wire, output, cursor, wire.len, wire.len, counts);
}
fn valid(comptime wrapper: ref.Wrapper, wire: []const u8, split: usize, quota: usize, counts: *h.Counts) !void {
    var history: [32768]u8 = undefined;
    var output: [h.payload.len]u8 = undefined;
    var decoder = try h.Decoder(wrapper).init(.{ .expected_output_len = h.payload.len }, &history);
    var cursor: h.Cursor = .{};
    try h.pump(&decoder, wire, &output, &cursor, split, quota, counts);
    try h.pump(&decoder, wire, &output, &cursor, wire.len, quota, counts);
    try decoder.finish();
    try h.require(cursor.read == wire.len and cursor.written == h.payload.len);
    try h.equal(h.payload, &output);
    try h.hash(wrapper, &decoder, &output);
    try h.require(decoder.memberEndOffset() == wire.len and decoder.snapshot().total_input == cursor.read);
    try h.require(decoder.snapshot().footer_received == if (wrapper == .zlib) @as(usize, 4) else @as(usize, 8));
    try h.sealed(&decoder, counts);
    counts.valid_splits += 1;
}
