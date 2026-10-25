//! Persistent parallel XZ through the public root and incremental ZIP writer.
const std = @import("std");
const crypto = @import("vail_archive_crypto").zipcrypto;
const threaded = @import("../xz/parallel/types.zig").target_supports_parallel;
const a = std.testing.allocator;
const block_size: usize = 1024;
const input = (("abcdefg|" ** 512) ++ "end").*;
const stream_header = "\xfd7zXZ\x00\x00\x04\xe6\xd6\xb4\x46";

pub fn contracts(comptime V: type) !void {
    try zipRoundTrips(V);
    try encryptedFailure(V);
    try rootMove(V);
    try rootAbort(V);
}

fn options(comptime V: type, profile: *V.XzParallelProfile, workers: usize) V.XzIncrementalEncoder.Options {
    return .{ .block_size = block_size, .chunk_size = block_size, .dictionary_size = 4096, .parallel = .{
        .io = std.testing.io,
        .worker_count = workers,
        .max_inflight_blocks = 2,
        .max_inflight_bytes = 2 * block_size,
        .max_working_memory = 64 * 1024 * 1024,
        .profile = profile,
    } };
}

fn crc32(bytes: []const u8) u32 {
    var crc: u32 = 0xffffffff;
    for (bytes) |byte| {
        crc ^= byte;
        for (0..8) |_| crc = (crc >> 1) ^ (0xedb88320 & (0 -% (crc & 1)));
    }
    return ~crc;
}

fn countStep(calls: *usize) !void {
    calls.* += 1;
    try std.testing.expect(calls.* < 20000);
}

fn observe(comptime V: type, writer: anytype, seen: *V.XzIncrementalParallelSnapshot) !void {
    if (writer.current) |*entry| {
        const state = entry.codec.xz.snapshot().parallel;
        try std.testing.expect(state.enabled);
        try std.testing.expect(state.inflight_blocks <= 2 and state.inflight_bytes <= 2 * block_size);
        try std.testing.expect(state.live_requested_bytes >= state.control_bytes);
        if (state.accepted_blocks >= seen.accepted_blocks) seen.* = state;
    }
}

fn completeProfile(comptime V: type, profile: V.XzParallelProfile, blocks: usize, workers: usize) !void {
    try std.testing.expectEqual(blocks, profile.completed_blocks);
    try std.testing.expectEqual(blocks, profile.published_blocks);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expect(profile.peak_requested_bytes > 0 and profile.peak_requested_bytes <= 64 * 1024 * 1024);
    try std.testing.expectEqual(@as(usize, if (threaded and workers > 1) workers else 0), profile.workers_started);
    try std.testing.expectEqual(!threaded or workers == 1, profile.serial_fallback);
}

fn zipRoundTrips(comptime V: type) !void {
    const Entry = struct { name: []const u8, data: []const u8, known: bool, comment: []const u8 };
    const entries = [_]Entry{ .{ .name = "known.xz", .data = &input, .known = true, .comment = "known size" }, .{ .name = "unknown.xz", .data = input[0..2061], .known = false, .comment = "unknown size" } };
    const modified: V.zip.DosTimestamp = .{ .date = 0x5a3f, .time = 0xbf7d };
    for ([_]bool{ false, true }) |sized| {
        var profile: V.XzParallelProfile = .{};
        var settings = options(V, &profile, 2);
        settings.include_block_sizes = sized;
        var writer = try V.zip.incremental_writer.Writer.initWithOptions(a, .{ .zip64 = .never, .archive_comment = "parallel XZ", .xz_options = settings });
        defer writer.deinit();
        var bytes: std.ArrayList(u8) = .empty;
        defer bytes.deinit(a);
        var staging: [37]u8 = undefined;
        var output: [7]u8 = undefined;
        var blocked: usize = 0;
        var calls: usize = 0;
        for (entries) |entry| {
            try writer.beginEntry(.{ .name = entry.name, .comment = entry.comment, .method = .xz, .expected_size = if (entry.known) @as(u64, entry.data.len) else null, .modified = modified, .creator_system = .unix, .external_attributes = 0o100640 << 16 });
            var read: usize = 0;
            var seen: V.XzIncrementalParallelSnapshot = .{};
            while (read < entry.data.len) {
                const n = @min(staging.len, entry.data.len - read);
                @memcpy(staging[0..n], entry.data[read..][0..n]);
                const step = try writer.step(staging[0..n], &output);
                @memset(&staging, 0xa5); // Accepted bytes must already be owned by the codec.
                try countStep(&calls);
                read += step.progress.input_read;
                try bytes.appendSlice(a, output[0..step.progress.output_written]);
                try observe(V, &writer, &seen);
                if (step.status == .need_output) blocked += 1;
                try std.testing.expect(step.progress.input_read > 0 or step.progress.output_written > 0);
            }
            try writer.finishEntry();
            while (writer.snapshot().phase != .ready) {
                const step = try writer.step("", &output);
                try countStep(&calls);
                try bytes.appendSlice(a, output[0..step.progress.output_written]);
                try observe(V, &writer, &seen);
            }
            const blocks = (entry.data.len + block_size - 1) / block_size;
            try std.testing.expect(seen.started and seen.accepted_blocks == blocks and seen.encoded_blocks == blocks);
            try completeProfile(V, profile, blocks, 2);
        }
        try writer.finishArchive();
        while (true) {
            const step = try writer.step("", &output);
            try countStep(&calls);
            try bytes.appendSlice(a, output[0..step.progress.output_written]);
            if (step.status == .done) break;
        }
        try std.testing.expect(blocked > 0);
        const archive = try V.zip.parse(bytes.items);
        try std.testing.expectEqual(entries.len, archive.entry_count);
        try std.testing.expectEqualStrings("parallel XZ", archive.comment);
        for (entries, 0..) |expected, i| {
            const entry = try archive.entryAt(i);
            try std.testing.expectEqualStrings(expected.name, entry.name);
            try std.testing.expectEqualStrings(expected.comment, entry.comment);
            try std.testing.expectEqual(modified, entry.modified);
            try std.testing.expectEqual(@as(?u16, 0o100640), entry.unixMode());
            try std.testing.expectEqual(V.zip.CompressionMethod.xz, entry.method);
            try std.testing.expectEqual(crc32(expected.data), entry.crc32);
            try std.testing.expectEqual(expected.data.len, entry.uncompressed_size);
            const compressed = try archive.compressedData(entry);
            try std.testing.expectEqual((expected.data.len + block_size - 1) / block_size, (try V.xz.inspect(a, compressed)).block_count);
            try std.testing.expectEqual(@as(u8, if (sized) 0xc0 else 0), compressed[13]);
            const decoded = try archive.extractAlloc(a, entry);
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, expected.data, decoded);
        }
    }
}

fn encryptedFailure(comptime V: type) !void {
    var backing = std.testing.FailingAllocator.init(a, .{});
    var profile: V.XzParallelProfile = .{};
    var settings = options(V, &profile, 2);
    settings.include_block_sizes = true;
    settings.match_options = .{ .max_working_memory = 0 };
    var writer = try V.zip.incremental_writer.Writer.initWithOptions(backing.allocator(), .{ .zip64 = .never, .xz_options = settings });
    var released = false;
    defer if (!released) writer.deinit();
    const random = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    try writer.beginEntry(.{ .name = "failed.xz", .method = .xz, .traditional_encryption = .{ .password = "parallel failure", .header_random = random } });
    var prefix: [256]u8 = undefined;
    const header = try writer.step("", &prefix);
    const before = writer.snapshot();
    try std.testing.expectEqual(.entry_data, before.phase);
    try std.testing.expectEqual(@as(u64, 12), before.current_compressed_size);
    var staging: [block_size]u8 = input[0..block_size].*;
    var output: [64]u8 = @splat(0xa5);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, writer.step(&staging, &output));
    const failed = writer.snapshot();
    const codec = writer.current.?.codec.xz.snapshot().parallel;
    @memset(&staging, 0xa5);
    try std.testing.expect(codec.failed and codec.started and codec.accepted_blocks == 1);
    try std.testing.expectEqual(@as(usize, if (threaded) 2 else 0), codec.workers_started);
    try std.testing.expectEqual(@as(usize, block_size), codec.last_step_progress.input_read);
    try std.testing.expectEqual(stream_header.len, codec.last_step_progress.output_written);
    try std.testing.expectEqual(before.input_read + block_size, failed.input_read);
    try std.testing.expectEqual(@as(u64, block_size), failed.current_uncompressed_size);
    try std.testing.expectEqual(crc32(input[0..block_size]), writer.current.?.crc.digest());
    try std.testing.expectEqual(before.output_written + stream_header.len, failed.output_written);
    try std.testing.expectEqual(before.current_compressed_size + stream_header.len, failed.current_compressed_size);
    try std.testing.expectEqual(before.central_metadata_size, failed.central_metadata_size);
    try std.testing.expectEqual(.poisoned, failed.phase);
    var decryptor = crypto.Cipher.init("parallel failure");
    defer decryptor.deinit();
    var encryption_header: [12]u8 = undefined;
    decryptor.decrypt(prefix[header.progress.output_written - 12 .. header.progress.output_written], &encryption_header);
    try std.testing.expectEqualSlices(u8, &random, encryption_header[0..11]);
    try std.testing.expectEqual(@as(u8, 0), encryption_header[11]);
    var decoded_header: [12]u8 = undefined;
    decryptor.decrypt(output[0..12], &decoded_header);
    try std.testing.expectEqualSlices(u8, stream_header, &decoded_header);
    try std.testing.expectEqualDeep(decryptor, writer.current.?.encryption.?.traditional.cipher);
    for (output[12..]) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
    const committed = output;
    try std.testing.expectError(error.ZipWriterPoisoned, writer.step(&staging, &output));
    try std.testing.expectEqualDeep(failed, writer.snapshot());
    try std.testing.expectEqualDeep(decryptor, writer.current.?.encryption.?.traditional.cipher);
    try std.testing.expectEqualSlices(u8, &committed, &output);
    try std.testing.expectError(error.ZipWriterPoisoned, writer.finishEntry());
    try std.testing.expectError(error.ZipWriterPoisoned, writer.finishArchive());
    writer.deinit();
    released = true;
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
}

fn finishRoot(comptime V: type, encoder: *V.XzIncrementalEncoder, bytes: *std.ArrayList(u8), start: usize) !void {
    var read = start;
    var staging: [37]u8 = undefined;
    var output: [7]u8 = undefined;
    var calls: usize = 0;
    while (true) {
        const n = @min(staging.len, input.len - read);
        @memcpy(staging[0..n], input[read..][0..n]);
        if (n == 0) encoder.finish();
        const step = try encoder.step(staging[0..n], &output);
        @memset(&staging, 0xa5);
        try countStep(&calls);
        read += step.progress.input_read;
        try bytes.appendSlice(a, output[0..step.progress.output_written]);
        if (step.status == .done) break;
        try std.testing.expect(step.progress.input_read > 0 or step.progress.output_written > 0);
    }
    try std.testing.expectEqual(input.len, read);
}

fn rootMove(comptime V: type) !void {
    try std.testing.expect(V.XzIncrementalParallelSnapshot == V.XzIncrementalEncoder.ParallelSnapshot);
    try std.testing.expect((@as(V.XzIncrementalEncoder.Options, .{})).parallel == null);
    var first_profile: V.XzParallelProfile = .{};
    var original = try V.XzIncrementalEncoder.initExactSize(a, options(V, &first_profile, 2), input.len);
    var transferred = false;
    defer if (!transferred) original.deinit();
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(a);
    var header: [12]u8 = undefined;
    const head = try original.step("", &header);
    try bytes.appendSlice(a, header[0..head.progress.output_written]);
    var output: [1]u8 = undefined;
    var staging: [2 * block_size]u8 = input[0 .. 2 * block_size].*;
    const first = try original.step(&staging, &output);
    @memset(&staging, 0xa5);
    try bytes.appendSlice(a, output[0..first.progress.output_written]);
    const before = original.snapshot();
    try std.testing.expect(before.parallel.started and before.parallel.accepted_blocks == 2 and before.parallel.inflight_bytes > 0);
    const published_profile = first_profile;
    try std.testing.expectEqual(before.parallel.workers_started, published_profile.workers_started);
    try std.testing.expect(published_profile.peak_inflight_bytes <= 2 * block_size);
    var moved = original;
    original = undefined;
    transferred = true;
    var released = false;
    defer if (!released) moved.deinit();
    try std.testing.expectEqualDeep(published_profile, first_profile); // Moving the value never publishes a new profile.
    try finishRoot(V, &moved, &bytes, first.progress.input_read);
    try std.testing.expect(moved.snapshot().done);
    const decoded = try V.xz.decodeAlloc(a, bytes.items);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
    moved.deinit();
    released = true;
    try completeProfile(V, first_profile, (input.len + block_size - 1) / block_size, 2);
}

fn rootAbort(comptime V: type) !void {
    for ([_]usize{ 1, 2 }) |workers| {
        var backing = std.testing.FailingAllocator.init(a, .{});
        var profile: V.XzParallelProfile = .{};
        var settings = options(V, &profile, workers);
        if (workers == 1) settings.parallel.?.io = .failing;
        var encoder = try V.XzIncrementalEncoder.initWithOptions(backing.allocator(), settings);
        var released = false;
        defer if (!released) encoder.deinit();
        var header: [12]u8 = undefined;
        _ = try encoder.step("", &header);
        var staging: [2 * block_size]u8 = input[0 .. 2 * block_size].*;
        const step = try encoder.step(&staging, &.{});
        @memset(&staging, 0xa5);
        const snapshot = encoder.snapshot().parallel;
        try std.testing.expectEqual(staging.len, step.progress.input_read);
        try std.testing.expect(snapshot.started and snapshot.accepted_blocks == 2 and snapshot.inflight_blocks == 2);
        try std.testing.expectEqual(staging.len, snapshot.owned_input_bytes);
        try std.testing.expectEqual(@as(usize, if (threaded and workers > 1) workers else 0), snapshot.workers_started);
        try std.testing.expect(snapshot.workers_live <= snapshot.workers_started);
        encoder.deinit(); // Join outstanding work and free undelivered owned storage.
        released = true;
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
    }
}
