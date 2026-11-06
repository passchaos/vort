const std = @import("std");
const h = @import("driver.zig");
const ref = @import("reference.zig");

pub fn run(a: std.mem.Allocator, counts: *h.Counts) !void {
    inline for (.{ ref.Wrapper.zlib, ref.Wrapper.gzip }) |wrapper| {
        const first = try ref.deflate(a, wrapper, h.payload, null);
        defer a.free(first);
        const second = try ref.deflate(a, wrapper, h.second_payload, null);
        defer a.free(second);
        const member_end = first.len + second.len;
        const prefix: u8 = if (wrapper == .zlib) 0x78 else 0x1f;
        const rejected = [_]u8{ prefix, 0xff, 0x55 };
        const plausible = [_]u8{prefix};
        for ([_][]const u8{ "garbage", &rejected, &plausible, "" }) |tail| {
            const wire = try std.mem.concat(a, u8, &.{ first, second, tail });
            defer a.free(wire);
            for (0..3) |schedule| {
                var history: [32768]u8 = undefined;
                var output: [h.payload.len + h.second_payload.len]u8 = undefined;
                var decoder = try h.Decoder(wrapper).init(.{ .allow_concatenated = true, .allow_trailing_data = true, .expected_output_len = output.len }, &history);
                var cursor: h.Cursor = .{};
                if (schedule == 2) try h.pump(&decoder, wire, &output, &cursor, @min(wire.len, member_end + 1), wire.len, counts);
                try h.pump(&decoder, wire, &output, &cursor, wire.len, if (schedule == 0) 1 else wire.len, counts);
                try decoder.finish();
                try h.equal(h.payload ++ h.second_payload, output[0..cursor.written]);
                try h.hash(wrapper, &decoder, h.second_payload);
                try h.require(decoder.memberEndOffset() == member_end);
                const restored = try std.mem.concat(a, u8, &.{ decoder.trailingPrefix(), wire[cursor.read..] });
                defer a.free(restored);
                try h.equal(tail, restored);
                try h.require(cursor.read == decoder.snapshot().total_input and cursor.written == decoder.snapshot().total_output);
                if (wrapper == .zlib) try h.require(decoder.snapshot().stream_count == 2) else try h.require(decoder.snapshot().member_count == 2);
                try h.sealed(&decoder, counts);
                counts.tails += 1;
            }
        }
    }
    try recognizedGzip(a, counts);
}

fn recognizedGzip(a: std.mem.Allocator, counts: *h.Counts) !void {
    const first = try ref.deflate(a, .gzip, "", null);
    defer a.free(first);
    const valid = try ref.deflate(a, .gzip, h.second_payload, null);
    defer a.free(valid);
    for (0..4) |kind| {
        const second = if (kind == 3) try a.dupe(u8, valid[0..2]) else if (kind == 2) blk: {
            const changed = try a.alloc(u8, valid.len + 2);
            @memcpy(changed[0..10], valid[0..10]);
            changed[3] |= 2;
            // FHCRC is the independent CRC32 of the changed header, low 16
            // bits. Flip one bit so failure cannot depend on an accidental
            // all-zero expected checksum.
            std.mem.writeInt(u16, changed[10..12], @as(u16, @truncate(ref.crc(changed[0..10]))) ^ 1, .little);
            @memcpy(changed[12..], valid[10..]);
            break :blk changed;
        } else blk: {
            const changed = try a.dupe(u8, valid);
            if (kind == 0) changed[2] = 0 else changed[3] |= 0x80;
            break :blk changed;
        };
        defer a.free(second);
        try h.require(second[0] == 0x1f and second[1] == 0x8b);
        const verdict = try ref.inflate(.gzip, second);
        try h.require(verdict == if (kind == 3) ref.Verdict.truncated else ref.Verdict.data);
        const wire = try std.mem.concat(a, u8, &.{ first, second });
        defer a.free(wire);
        for ([_]usize{ 1, wire.len }) |quota| {
            var history: [32768]u8 = undefined;
            var output: [h.second_payload.len]u8 = undefined;
            var decoder = try h.D.GzipIncrementalDecoder.init(.{ .allow_concatenated = true, .allow_trailing_data = true, .ignore_crc32 = true, .ignore_isize = true }, &history);
            var cursor: h.Cursor = .{};
            const advanced = h.pump(&decoder, wire, &output, &cursor, wire.len, quota, counts);
            if (kind == 3) {
                try advanced;
                if (decoder.finish()) |_| return error.ExpectedRecognizedHeaderTruncation else |err| try h.require(err == error.TruncatedFrame);
                try h.sealed(&decoder, counts);
            } else {
                if (advanced) |_| return error.ExpectedRecognizedHeaderRefusal else |err| try h.require(err == error.BadGzipHeader);
            }
            try h.require(decoder.memberEndOffset() == first.len and decoder.snapshot().member_count == 1);
            try h.require(decoder.trailingPrefix().len == 0 and decoder.snapshot().last_error_member_index == 1);
            try h.require(decoder.snapshot().last_error_member_offset == first.len);
            counts.recognized_headers += 1;
        }
    }
}
