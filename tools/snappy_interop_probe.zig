const std = @import("std");
const vort = @import("vort");
const libsnappy = @import("snappy/libsnappy_runtime.zig");

const stream_identifier = [_]u8{
    0xff, 0x06, 0x00, 0x00, 's', 'N', 'a', 'P', 'p', 'Y',
};
const compressed_chunk_type: u8 = 0x00;
const uncompressed_chunk_type: u8 = 0x01;
const min_skippable_chunk_type: u8 = 0x80;

const Case = struct {
    name: []const u8,
    payload: []const u8,
};

const FrameCounts = struct {
    lib_generated_blocks: usize = 0,
    vort_generated_blocks: usize = 0,
    vort_compressed_blocks: usize = 0,
};

const RawCounts = struct {
    lib_copy_blocks: usize = 0,
    vort_copy_blocks: usize = 0,
};

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(
        init.io,
        &stdout_buffer,
    );
    const stdout = &stdout_writer.interface;

    var runtime = try libsnappy.Runtime.open();
    defer runtime.deinit();

    var sequential: [4096]u8 = undefined;
    for (&sequential, 0..) |*byte, index| byte.* = @intCast(index % 251);

    var randomish: [64 * 1024]u8 = undefined;
    var random_state: u32 = 0x51a7_c0de;
    for (&randomish) |*byte| {
        random_state = random_state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(random_state >> 16);
    }

    const multi_chunk = try init.gpa.alloc(u8, 160 * 1024 + 123);
    defer init.gpa.free(multi_chunk);
    for (multi_chunk, 0..) |*byte, index| {
        byte.* = if (index % 4096 < 3584)
            @intCast((index / 31) % 17 + 'a')
        else
            @truncate((index *% 73 +% index / 7) >> 3);
    }

    const cases = [_]Case{
        .{ .name = "empty", .payload = "" },
        .{ .name = "tiny", .payload = "hello snappy" },
        .{ .name = "text", .payload = "Snappy cross-library interoperability payload. " ** 1024 },
        .{ .name = "structured", .payload = "{\"service\":\"vort\",\"codec\":\"snappy\",\"value\":12345}\n" ** 768 },
        .{ .name = "repetitive", .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 512 },
        .{ .name = "sequential", .payload = &sequential },
        .{ .name = "random64k", .payload = &randomish },
        .{ .name = "multi-chunk", .payload = multi_chunk },
    };

    var frame_counts: FrameCounts = .{};
    var raw_counts: RawCounts = .{};
    for (cases) |case| {
        const raw = try checkRawBlock(init.gpa, runtime, case);
        raw_counts.lib_copy_blocks += raw.lib_copy_blocks;
        raw_counts.vort_copy_blocks += raw.vort_copy_blocks;
        const counts = try checkFramedStream(init.gpa, runtime, case);
        frame_counts.lib_generated_blocks += counts.lib_generated_blocks;
        frame_counts.vort_generated_blocks += counts.vort_generated_blocks;
        frame_counts.vort_compressed_blocks += counts.vort_compressed_blocks;
    }
    if (raw_counts.lib_copy_blocks == 0 or
        raw_counts.vort_copy_blocks == 0 or
        frame_counts.vort_compressed_blocks == 0)
        return error.SnappyInteropMismatch;

    try stdout.print(
        "snappy_interop_probe_reference library=libsnappy version_api=unavailable raw_cases={d} frame_cases={d} lib_copy_blocks={d} vort_copy_blocks={d} lib_frame_blocks={d} vort_frame_blocks={d} vort_compressed_blocks={d}\n",
        .{ cases.len, cases.len, raw_counts.lib_copy_blocks, raw_counts.vort_copy_blocks, frame_counts.lib_generated_blocks, frame_counts.vort_generated_blocks, frame_counts.vort_compressed_blocks },
    );
    try stdout.print("snappy_interop_probe_ok cases={d}\n", .{cases.len * 2});
    try stdout.print("snappy_interop_probe_coverage capability=bidirectional-raw cases={d}\n", .{cases.len});
    try stdout.print("snappy_interop_probe_coverage capability=lib-generated-frame-blocks cases={d}\n", .{cases.len});
    try stdout.print("snappy_interop_probe_coverage capability=chunked cases={d}\n", .{cases.len});
    try stdout.print("snappy_interop_probe_coverage capability=incremental cases={d}\n", .{cases.len});
    try stdout.print("snappy_interop_probe_coverage capability=malformed cases={d}\n", .{cases.len});
    try stdout.flush();
}

fn checkRawBlock(
    allocator: std.mem.Allocator,
    runtime: libsnappy.Runtime,
    case: Case,
) !RawCounts {
    const reference_block = try runtime.encodeAlloc(allocator, case.payload);
    defer allocator.free(reference_block);
    try runtime.validate(reference_block);
    if (try runtime.decodedLength(reference_block) != case.payload.len)
        return reportMismatch(case, "reference raw decoded length");
    const truncated = reference_block[0 .. reference_block.len - 1];
    const reference_rejected = rejected: {
        runtime.validate(truncated) catch break :rejected true;
        break :rejected false;
    };
    const vort_rejected = rejected: {
        _ = vort.snappySummarizeBlock(truncated) catch break :rejected true;
        break :rejected false;
    };
    if (!reference_rejected or !vort_rejected)
        return reportMismatch(case, "truncated raw rejection");

    const summary = try vort.snappySummarizeBlock(reference_block);
    if (summary.decoded_bytes != case.payload.len)
        return reportMismatch(case, "Vort raw summary length");
    if (try vort.snappyDecodedBlockSize(reference_block) != case.payload.len)
        return reportMismatch(case, "Vort raw preflight length");

    const decoded = try vort.snappyDecodeBlockAllocExactSize(
        allocator,
        reference_block,
        case.payload.len,
    );
    defer allocator.free(decoded);
    try expectPayload(case, decoded);

    const into = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(into);
    const written = try vort.snappyDecodeBlockIntoExactSize(
        reference_block,
        into,
        case.payload.len,
    );
    if (written != case.payload.len)
        return reportMismatch(case, "Vort raw caller-buffer length");
    try expectPayload(case, into);

    const split_a: usize = @min(reference_block.len, 1);
    const split_b: usize = @min(reference_block.len, split_a + 7);
    const chunks = [_][]const u8{
        reference_block[0..split_a],
        reference_block[split_a..split_b],
        reference_block[split_b..],
    };
    const join = try allocator.alloc(u8, reference_block.len);
    defer allocator.free(join);
    const chunked_written = try vort.snappyDecodeBlockChunksIntoExactSize(
        &chunks,
        join,
        into,
        case.payload.len,
    );
    if (chunked_written != case.payload.len)
        return reportMismatch(case, "Vort raw chunked length");
    try expectPayload(case, into);

    const vort_block = try vort.snappyEncodeBlockAlloc(allocator, case.payload);
    defer allocator.free(vort_block);
    const vort_summary = try vort.snappySummarizeBlock(vort_block);
    try runtime.validate(vort_block);
    if (try runtime.decodedLength(vort_block) != case.payload.len)
        return reportMismatch(case, "libsnappy raw decoded length");
    try runtime.decode(vort_block, into);
    try expectPayload(case, into);
    return .{
        .lib_copy_blocks = @intFromBool(summary.copy_count != 0),
        .vort_copy_blocks = @intFromBool(vort_summary.copy_count != 0),
    };
}

fn checkFramedStream(
    allocator: std.mem.Allocator,
    runtime: libsnappy.Runtime,
    case: Case,
) !FrameCounts {
    const reference = try buildReferenceFrame(allocator, runtime, case.payload);
    defer allocator.free(reference.frame);

    const summary = try vort.snappySummarizeFrame(reference.frame);
    if (summary.decoded_bytes != case.payload.len or
        summary.stream_identifier_count != 1 or
        summary.compressed_chunk_count != reference.block_count or
        summary.uncompressed_chunk_count != 0)
    {
        return reportMismatch(case, "libsnappy-block frame summary");
    }

    const decoded = try vort.snappyDecodeFrameAllocExactSize(
        allocator,
        reference.frame,
        case.payload.len,
    );
    defer allocator.free(decoded);
    try expectPayload(case, decoded);

    const into = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(into);
    const written = try vort.snappyDecodeFrameIntoExactSize(
        reference.frame,
        into,
        case.payload.len,
    );
    if (written != case.payload.len)
        return reportMismatch(case, "Vort frame caller-buffer length");
    try expectPayload(case, into);

    const split_a: usize = @min(reference.frame.len, 3);
    const split_b: usize = @min(reference.frame.len, split_a + 11);
    const split_c: usize = @min(reference.frame.len, split_b + 67);
    const chunks = [_][]const u8{
        reference.frame[0..split_a],
        reference.frame[split_a..split_b],
        reference.frame[split_b..split_c],
        reference.frame[split_c..],
    };
    const join = try allocator.alloc(u8, reference.frame.len);
    defer allocator.free(join);
    const chunked_written = try vort.snappyDecodeFrameChunksIntoExactSize(
        &chunks,
        join,
        into,
        case.payload.len,
    );
    if (chunked_written != case.payload.len)
        return reportMismatch(case, "Vort frame chunked length");
    try expectPayload(case, into);
    try checkIncrementalFrame(allocator, case, reference.frame);

    const vort_frame = try vort.snappyEncodeFrameAlloc(allocator, case.payload);
    defer allocator.free(vort_frame);
    const vort_block_count = try validateVortFrameWithLib(
        allocator,
        runtime,
        case,
        vort_frame,
    );
    const expected_blocks = if (case.payload.len == 0) 0 else (case.payload.len + vort.snappyMaxUncompressedChunkLen - 1) /
        vort.snappyMaxUncompressedChunkLen;
    if (reference.block_count != expected_blocks or
        vort_block_count.data_blocks != expected_blocks)
        return reportMismatch(case, "frame block count");
    return .{
        .lib_generated_blocks = reference.block_count,
        .vort_generated_blocks = vort_block_count.data_blocks,
        .vort_compressed_blocks = vort_block_count.compressed_blocks,
    };
}

const ReferenceFrame = struct { frame: []u8, block_count: usize };

fn buildReferenceFrame(
    allocator: std.mem.Allocator,
    runtime: libsnappy.Runtime,
    payload: []const u8,
) !ReferenceFrame {
    var frame: std.ArrayList(u8) = .empty;
    errdefer frame.deinit(allocator);
    try frame.appendSlice(allocator, &stream_identifier);

    var offset: usize = 0;
    var block_count: usize = 0;
    while (offset < payload.len) {
        const chunk_len = @min(payload.len - offset, vort.snappyMaxUncompressedChunkLen);
        const plain = payload[offset..][0..chunk_len];
        const block = try runtime.encodeAlloc(allocator, plain);
        defer allocator.free(block);

        var checksum_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &checksum_bytes, maskedCrc32c(plain), .little);
        try appendChunkHeader(allocator, &frame, compressed_chunk_type, checksum_bytes.len + block.len);
        try frame.appendSlice(allocator, &checksum_bytes);
        try frame.appendSlice(allocator, block);
        offset += chunk_len;
        block_count += 1;
    }
    return .{ .frame = try frame.toOwnedSlice(allocator), .block_count = block_count };
}

const VortFrameCounts = struct { data_blocks: usize = 0, compressed_blocks: usize = 0 };

fn validateVortFrameWithLib(
    allocator: std.mem.Allocator,
    runtime: libsnappy.Runtime,
    case: Case,
    frame: []const u8,
) !VortFrameCounts {
    var index: usize = 0;
    var output_offset: usize = 0;
    var saw_identifier = false;
    var counts: VortFrameCounts = .{};
    while (index < frame.len) {
        if (frame.len - index < 4) return error.TruncatedFrame;
        const chunk_type = frame[index];
        const chunk_len = readU24(frame[index + 1 ..][0..3]);
        index += 4;
        if (frame.len - index < chunk_len) return error.TruncatedFrame;
        const chunk = frame[index..][0..chunk_len];
        index += chunk_len;

        switch (chunk_type) {
            0xff => {
                if (!std.mem.eql(u8, chunk, "sNaPpY")) return error.InvalidMagic;
                saw_identifier = true;
            },
            compressed_chunk_type => {
                if (!saw_identifier or chunk.len < 4) return error.InvalidMagic;
                const block = chunk[4..];
                try runtime.validate(block);
                const decoded_len = try runtime.decodedLength(block);
                if (output_offset > case.payload.len or
                    decoded_len > vort.snappyMaxUncompressedChunkLen or
                    case.payload.len - output_offset < decoded_len)
                    return reportMismatch(case, "Vort frame compressed chunk length");
                const decoded = try allocator.alloc(u8, decoded_len);
                defer allocator.free(decoded);
                try runtime.decode(block, decoded);
                if (std.mem.readInt(u32, chunk[0..4], .little) != maskedCrc32c(decoded))
                    return error.ChecksumMismatch;
                if (!std.mem.eql(u8, decoded, case.payload[output_offset..][0..decoded_len]))
                    return reportMismatch(case, "libsnappy frame-block decode");
                output_offset += decoded_len;
                counts.data_blocks += 1;
                counts.compressed_blocks += 1;
            },
            uncompressed_chunk_type => {
                if (!saw_identifier or chunk.len < 4) return error.InvalidMagic;
                const plain = chunk[4..];
                if (output_offset > case.payload.len or
                    plain.len > vort.snappyMaxUncompressedChunkLen or
                    case.payload.len - output_offset < plain.len)
                    return reportMismatch(case, "Vort frame uncompressed chunk length");
                if (std.mem.readInt(u32, chunk[0..4], .little) != maskedCrc32c(plain))
                    return error.ChecksumMismatch;
                if (!std.mem.eql(u8, plain, case.payload[output_offset..][0..plain.len]))
                    return reportMismatch(case, "Vort frame uncompressed payload");
                output_offset += plain.len;
                counts.data_blocks += 1;
            },
            else => {
                if (chunk_type < min_skippable_chunk_type)
                    return error.UnsupportedSnappyFeature;
            },
        }
    }
    if (!saw_identifier or output_offset != case.payload.len)
        return reportMismatch(case, "Vort frame total length");
    return counts;
}

fn checkIncrementalFrame(
    allocator: std.mem.Allocator,
    case: Case,
    frame: []const u8,
) !void {
    var decoder = vort.SnappyIncrementalFrameDecoder.initWithOptions(allocator, .{
        .max_output_len = case.payload.len,
        .expected_output_len = case.payload.len,
    });
    defer decoder.deinit();
    const output = try allocator.alloc(u8, case.payload.len);
    defer allocator.free(output);

    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (input_offset < frame.len or decoder.snapshot().payload_remaining != 0) {
        const input_len = @min(frame.len - input_offset, 13);
        const output_len = @min(output.len - output_offset, 97);
        const result = try decoder.step(
            frame[input_offset..][0..input_len],
            output[output_offset..][0..output_len],
        );
        input_offset += result.progress.input_read;
        output_offset += result.progress.output_written;
        if (result.progress.input_read == 0 and result.progress.output_written == 0) {
            if (result.status == .need_input and input_offset == frame.len) break;
            return reportMismatch(case, "incremental progress");
        }
    }
    if (input_offset != frame.len or output_offset != case.payload.len)
        return reportMismatch(case, "incremental length");
    try decoder.finish();
    if (decoder.snapshot().phase != .done)
        return reportMismatch(case, "incremental finish");
    try expectPayload(case, output);
}

fn appendChunkHeader(
    allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    chunk_type: u8,
    payload_len: usize,
) !void {
    if (payload_len > 0x00ff_ffff) return error.OutputLimitExceeded;
    try out.append(allocator, chunk_type);
    try out.append(allocator, @intCast(payload_len & 0xff));
    try out.append(allocator, @intCast((payload_len >> 8) & 0xff));
    try out.append(allocator, @intCast((payload_len >> 16) & 0xff));
}

fn readU24(bytes: *const [3]u8) usize {
    return @as(usize, bytes[0]) |
        (@as(usize, bytes[1]) << 8) |
        (@as(usize, bytes[2]) << 16);
}

fn maskedCrc32c(payload: []const u8) u32 {
    // Keep framing validation independent of Vort's checksum implementation.
    // 0x82f63b78 is the reflected Castagnoli polynomial used by Snappy.
    var crc: u32 = 0xffff_ffff;
    for (payload) |byte| {
        crc ^= byte;
        for (0..8) |_|
            crc = (crc >> 1) ^ (0x82f6_3b78 & (0 -% (crc & 1)));
    }
    crc = ~crc;
    return ((crc >> 15) | (crc << 17)) +% 0xa282_ead8;
}

fn expectPayload(case: Case, actual: []const u8) !void {
    if (!std.mem.eql(u8, case.payload, actual))
        return reportMismatch(case, "payload");
}

fn reportMismatch(case: Case, phase: []const u8) error{SnappyInteropMismatch} {
    std.debug.print(
        "snappy_interop_mismatch case={s} phase={s} payload={d}\n",
        .{ case.name, phase, case.payload.len },
    );
    return error.SnappyInteropMismatch;
}
