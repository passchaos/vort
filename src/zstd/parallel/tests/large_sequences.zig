//! Exercise the large sequence representation across independently coded jobs.
const std = @import("std");
const h = @import("helpers.zig");
const a = std.testing.allocator;

pub fn run(comptime Z: type) type {
    return struct {
        test "Zstd parallel frame more than 512 sequences rebase across a job boundary" {
            const block_size = 8192;
            const input = try a.alloc(u8, 3 * block_size);
            defer a.free(input);
            h.noise(input[0..block_size], 0x3710_2626);
            // The middle job commits a long history match, changing the
            // global repeated offsets and FSE tables before the large job.
            @memcpy(input[block_size .. 2 * block_size], input[0..block_size]);
            var position: usize = 2 * block_size;
            var index: usize = 0;
            while (input.len - position >= 6) : (index += 1) {
                const word = (index * 977 + 13) % (block_size / 4);
                @memcpy(input[position..][0..4], input[word * 4 ..][0..4]);
                std.mem.writeInt(u16, input[position + 4 ..][0..2], @truncate(index), .little);
                position += 6;
            }
            h.noise(input[position..], 0x4135);
            var work: Z.EncoderControlProfile = .{};
            const options: Z.NativeFrameOptions = .{
                .strategy = .fast,
                .block_size_max = block_size,
                .window_log = 15,
                .max_match_history_len = 32768,
                .control_profile = &work,
            };
            var profile: Z.ParallelProfile = .{};
            const parallel: Z.ParallelOptions = .{
                .io = std.testing.io,
                .worker_count = 2,
                .job_size = block_size,
                .max_inflight_jobs = 2,
                .max_inflight_bytes = 2 * block_size,
                .max_working_memory = 64 * 1024 * 1024,
                .profile = &profile,
            };
            const frame = try Z.encodeNativeParallelFrameAlloc(a, input, options, parallel);
            defer a.free(frame);
            const summary = try h.verify(Z, frame, input, options, null);
            try std.testing.expectEqual(summary.blocks, profile.encoded_blocks);
            try std.testing.expectEqual(summary.blocks, profile.published_blocks);
            try std.testing.expectEqual(@as(usize, 3), profile.published_jobs);
            try std.testing.expect(work.history_sequences > 512);
            try std.testing.expect(try maximumSequences(Z, frame) > 512);
            var single = parallel;
            single.worker_count = 1;
            single.io = .failing;
            single.profile = null;
            var unprofiled = options;
            unprofiled.control_profile = null;
            const expected = try Z.encodeNativeParallelFrameAlloc(a, input, unprofiled, single);
            defer a.free(expected);
            try std.testing.expectEqualSlices(u8, expected, frame);
        }
    };
}

fn maximumSequences(comptime Z: type, frame: []const u8) !usize {
    const header = try Z.inspectNativeFrameHeader(frame);
    var offset = header.payload_offset;
    var maximum: usize = 0;
    while (true) {
        if (frame.len - offset < 3) return error.InvalidFixture;
        const block_header = std.mem.readInt(u24, frame[offset..][0..3], .little);
        offset += 3;
        const kind = (block_header >> 1) & 3;
        const size: usize = @intCast(block_header >> 3);
        const length: usize = if (kind == 1) 1 else size;
        if (length > frame.len - offset or kind == 3) return error.InvalidFixture;
        if (kind == 2) maximum = @max(maximum, try sequenceCount(frame[offset..][0..length]));
        offset += length;
        if (block_header & 1 != 0) break;
    }
    try std.testing.expectEqual(frame.len, offset + @as(usize, if (header.has_checksum) 4 else 0));
    return maximum;
}

fn sequenceCount(payload: []const u8) !usize {
    if (payload.len == 0) return error.InvalidFixture;
    const kind = payload[0] & 3;
    const size_format = (payload[0] >> 2) & 3;
    const header_len: usize = if (kind < 2) switch (size_format) {
        0, 2 => 1,
        1 => 2,
        else => 3,
    } else switch (size_format) {
        0, 1 => 3,
        2 => 4,
        else => 5,
    };
    if (payload.len < header_len) return error.InvalidFixture;
    var value: u64 = 0;
    for (payload[0..header_len], 0..) |byte, index|
        value |= @as(u64, byte) << @intCast(index * 8);
    const payload_len: usize = if (kind == 1) 1 else if (kind == 0) @intCast(value >> (if (header_len == 1) @as(u6, 3) else 4)) else switch (size_format) {
        0, 1 => @intCast((value >> 14) & 0x3ff),
        2 => @intCast((value >> 18) & 0x3fff),
        else => @intCast((value >> 22) & 0x3ffff),
    };
    if (payload_len >= payload.len - header_len) return error.InvalidFixture;
    const offset = header_len + payload_len;
    const first = payload[offset];
    if (first < 128) return first;
    if (first != 255) {
        if (payload.len - offset < 2) return error.InvalidFixture;
        return (@as(usize, first) - 128) * 256 + payload[offset + 1];
    }
    if (payload.len - offset < 3) return error.InvalidFixture;
    return 0x7f00 + @as(usize, std.mem.readInt(u16, payload[offset + 1 ..][0..2], .little));
}
