//! Public ZIP composition of persistent parallel Zstandard and failure progress.
const std = @import("std");
const crypto = @import("vail_archive_crypto").zipcrypto;
const winzip_crypto = @import("vail_archive_crypto").winzip_aes;
const full_dictionary = @import("../zstd/encode/hq_test_helpers.zig").fullDictionary;
const a = std.testing.allocator;
const input = ("persistent Zstd ZIP alpha beta gamma 0123456789\n" ** 23).*;
const password = "persistent ZIP password";

pub fn contracts(comptime V: type) !void {
    try typedSurfaces(V);
    try defaultWire(V);
    try encryptedEntries(V);
    try dictionaries(V);
    try rejectedOptions(V);
    try failedProgress(V);
    try rootMove(V);
    try abortEntry(V);
    try widePledge(V);
}

fn typedSurfaces(comptime V: type) !void {
    try std.testing.expect(V.ZstdIncrementalParallelOptions == V.zstd.IncrementalParallelOptions);
    try std.testing.expect(V.ZstdIncrementalParallelProfile == V.zstd.IncrementalParallelProfile);
    try std.testing.expect(V.ZstdNativeIncrementalParallelFrameEncoder == V.zstd.NativeIncrementalParallelFrameEncoder);
    try std.testing.expect(@FieldType(V.zip.incremental_writer.Options, "zstd_parallel_options") == ?V.ZstdIncrementalParallelOptions);
    try std.testing.expect(@FieldType(V.ZstdIncrementalParallelProfile, "accepted_input_bytes") == V.StreamCount);
    try std.testing.expect(@FieldType(V.ZstdNativeIncrementalParallelFrameEncoder.Options, "max_job_count") == V.StreamCount);
}

fn policy(comptime V: type, profile: ?*V.ZstdIncrementalParallelProfile) V.ZstdIncrementalParallelOptions {
    return .{ .io = std.testing.io, .worker_count = 2, .job_size = 256, .max_inflight_jobs = 2, .max_inflight_bytes = 512, .max_working_memory = 64 * 1024 * 1024, .profile = profile };
}

fn native(comptime V: type) V.ZstdNativeFrameOptions {
    return .{ .strategy = .fast, .block_size_max = 128, .window_log = 10, .max_match_history_len = 1024, .content_checksum = true };
}

fn calls(n: *usize) !void {
    n.* += 1;
    try std.testing.expect(n.* < 20000);
}

fn finishEntry(writer: anytype, bytes: *std.ArrayList(u8), out_len: usize, n: *usize) !void {
    try writer.finishEntry();
    var output: [257]u8 = undefined;
    while (writer.snapshot().phase != .ready) {
        const result = try writer.step("", output[0..out_len]);
        try calls(n);
        try bytes.appendSlice(a, output[0..result.progress.output_written]);
    }
}

fn feed(writer: anytype, bytes: *std.ArrayList(u8), data: []const u8, in_len: usize, out_len: usize, n: *usize) !void {
    var staging: [257]u8 = undefined;
    var output: [257]u8 = undefined;
    var offset: usize = 0;
    while (offset < data.len) {
        const take = @min(in_len, data.len - offset);
        @memcpy(staging[0..take], data[offset..][0..take]);
        const result = try writer.step(staging[0..take], output[0..out_len]);
        try calls(n);
        try std.testing.expect(result.progress.input_read <= take and result.progress.output_written <= out_len);
        offset += result.progress.input_read;
        @memset(&staging, 0xa5);
        try bytes.appendSlice(a, output[0..result.progress.output_written]);
        try std.testing.expect(result.progress.input_read != 0 or result.progress.output_written != 0);
    }
}

fn finishArchive(writer: anytype, bytes: *std.ArrayList(u8), out_len: usize, n: *usize) !void {
    try writer.finishArchive();
    var output: [257]u8 = undefined;
    while (true) {
        const result = try writer.step("", output[0..out_len]);
        try calls(n);
        try bytes.appendSlice(a, output[0..result.progress.output_written]);
        if (result.status == .done) break;
    }
}

fn encode(comptime V: type, options: V.zip.incremental_writer.Options, entries: []const V.zip.incremental_writer.EntryOptions, data: []const []const u8, in_len: usize, out_len: usize) ![]u8 {
    var writer = try V.zip.incremental_writer.Writer.initWithOptions(a, options);
    defer writer.deinit();
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(a);
    var n: usize = 0;
    for (entries, data) |entry, payload| {
        try writer.beginEntry(entry);
        try feed(&writer, &bytes, payload, in_len, out_len, &n);
        try finishEntry(&writer, &bytes, out_len, &n);
    }
    try finishArchive(&writer, &bytes, out_len, &n);
    return bytes.toOwnedSlice(a);
}

fn defaultWire(comptime V: type) !void {
    const entries = [_]V.zip.incremental_writer.EntryOptions{
        .{ .name = "known.zst", .method = .zstandard, .expected_size = input.len },
        .{ .name = "unknown.zst", .method = .zstandard_legacy },
    };
    const data = [_][]const u8{ &input, input[0..513] };
    const original = try encode(V, .{ .zstd_options = native(V) }, &entries, &data, 257, 257);
    defer a.free(original);
    const explicit_null = try encode(V, .{ .zstd_options = native(V), .zstd_parallel_options = null }, &entries, &data, 1, 1);
    defer a.free(explicit_null);
    try std.testing.expectEqualSlices(u8, original, explicit_null);
    const archive = try V.zip.parse(original);
    for (data, 0..) |payload, index| {
        const frame = try archive.compressedData(try archive.entryAt(index));
        var serial = if (index == 0)
            try V.zstd.NativeIncrementalFrameEncoder.initExactSize(a, native(V), payload.len)
        else blk: {
            var settings = native(V);
            settings.include_content_size = false;
            break :blk try V.zstd.NativeIncrementalFrameEncoder.init(a, settings);
        };
        defer serial.deinit();
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(a);
        var buffer: [257]u8 = undefined;
        var offset: usize = 0;
        var n: usize = 0;
        while (true) {
            if (offset == payload.len) serial.finish();
            const step = try serial.step(payload[offset..], &buffer);
            try calls(&n);
            offset += step.progress.input_read;
            try expected.appendSlice(a, buffer[0..step.progress.output_written]);
            if (step.status == .done) break;
        }
        try std.testing.expectEqualSlices(u8, expected.items, frame);
    }
}

fn encryptedEntries(comptime V: type) !void {
    const random = [_]u8{0x35} ** 11;
    const salt = [_]u8{0x57} ** 16;
    for (0..5) |kind| {
        var profile: V.ZstdIncrementalParallelProfile = .{};
        var work: V.ZstdEncoderControlProfile = .{};
        var memory: V.zstd.EncodeMemoryProfile = .{};
        var frame = native(V);
        frame.control_profile = &work;
        frame.memory_profile = &memory;
        var entries = [_]V.zip.incremental_writer.EntryOptions{
            .{ .name = "known.zst", .comment = "known size", .method = .zstandard, .expected_size = input.len },
            .{ .name = "unknown.zst", .comment = "unknown size", .method = .zstandard_legacy },
        };
        for (&entries) |*entry| switch (kind) {
            1 => entry.traditional_encryption = .{ .password = password, .header_random = random },
            2, 3, 4 => entry.winzip_aes = .{ .password = password, .strength = switch (kind) {
                2 => .aes128,
                3 => .aes192,
                else => .aes256,
            }, .salt = salt[0..switch (kind) {
                2 => @as(usize, 8),
                3 => 12,
                else => 16,
            }], .version = .ae1 },
            else => {},
        };
        const data = [_][]const u8{ &input, input[0..513] };
        const encoded = try encode(V, .{ .zstd_options = frame, .zstd_parallel_options = policy(V, &profile), .archive_comment = "parallel Zstd" }, &entries, &data, 37, 7);
        defer a.free(encoded);
        try std.testing.expectEqual(@as(usize, 0), profile.workers_live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try std.testing.expect(profile.accepted_jobs > 1 and profile.accepted_jobs == profile.delivered_jobs);
        try std.testing.expect(work.available and work.controls_used);
        try std.testing.expectEqual(@as(usize, 0), memory.live_requested_bytes);
        const archive = try V.zip.parse(encoded);
        try std.testing.expectEqual(@as(usize, 2), archive.entry_count);
        for (entries, data, 0..) |metadata, payload, index| {
            const entry = try archive.entryAt(index);
            try std.testing.expectEqualStrings(metadata.name, entry.name);
            try std.testing.expectEqualStrings(metadata.comment, entry.comment);
            try std.testing.expectEqual(metadata.method, entry.method);
            const decoded = try archive.extractAllocWithOptions(a, entry, .{ .password = if (kind == 0) null else password });
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, payload, decoded);
            if (kind == 0) {
                const header = try V.zstd.inspectNativeFrameHeader(try archive.compressedData(entry));
                try std.testing.expectEqual(if (index == 0) @as(?u64, payload.len) else null, header.content_size);
                try std.testing.expect(header.has_checksum);
            }
        }
    }
}

fn dictionaries(comptime V: type) !void {
    const bytes = try full_dictionary(a);
    defer a.free(bytes);
    const presets = [_]V.ZstdNativeDictionary{ V.ZstdNativeDictionary.init(77, input[0..256]), V.ZstdNativeDictionary.initRawContent(input[0..256]), (try V.ZstdNativeDictionary.initFromStandardDictionary(bytes)).dictionary };
    for (presets) |dictionary| {
        var profile: V.ZstdIncrementalParallelProfile = .{};
        const entries = [_]V.zip.incremental_writer.EntryOptions{
            .{ .name = "known", .method = .zstandard, .expected_size = input.len },
            .{ .name = "unknown", .method = .zstandard_legacy },
        };
        const data = [_][]const u8{ &input, input[0..513] };
        const encoded = try encode(V, .{ .zstd_options = native(V), .zstd_dictionary = dictionary, .zstd_parallel_options = policy(V, &profile) }, &entries, &data, 63, 19);
        defer a.free(encoded);
        const archive = try V.zip.parse(encoded);
        for (data, 0..) |payload, index| {
            const entry = try archive.entryAt(index);
            const header = try V.zstd.inspectNativeFrameHeader(try archive.compressedData(entry));
            try std.testing.expectEqual(dictionary.id, header.dictionary_id);
            const decoded = try archive.extractAllocWithOptions(a, entry, .{ .zstd_dictionary = dictionary });
            defer a.free(decoded);
            try std.testing.expectEqualSlices(u8, payload, decoded);
        }
        try std.testing.expectEqual(@as(usize, 0), profile.workers_live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    }
}

fn rejectedOptions(comptime V: type) !void {
    var profile: V.ZstdIncrementalParallelProfile = .{};
    var invalid = policy(V, &profile);
    invalid.worker_count = 0;
    var frame = native(V);
    frame.format = .magicless;
    var writer = try V.zip.incremental_writer.Writer.initWithOptions(a, .{ .zstd_options = frame, .zstd_parallel_options = invalid });
    defer writer.deinit();
    try std.testing.expectError(error.InvalidBlockPlan, writer.beginEntry(.{ .name = "invalid", .method = .zstandard }));
    try std.testing.expectEqual(.ready, writer.snapshot().phase);
    try std.testing.expectEqual(@as(usize, 0), profile.workers_started);
    writer.options.zstd_options = native(V);
    try std.testing.expectError(error.InvalidBlockPlan, writer.beginEntry(.{ .name = "invalid", .method = .zstandard }));
    writer.options.zstd_parallel_options = policy(V, &profile);
    writer.options.zstd_options.dictionary_id = 7;
    try std.testing.expectError(error.InvalidBlockPlan, writer.beginEntry(.{ .name = "dictionary", .method = .zstandard }));
    writer.options.zstd_options = native(V);
    writer.options.zstd_options.max_total_working_memory = 0;
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, writer.beginEntry(.{ .name = "quota", .method = .zstandard }));
    try std.testing.expectEqual(.ready, writer.snapshot().phase);
    try std.testing.expectEqual(@as(usize, 0), profile.workers_started);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
}

fn failedProgress(comptime V: type) !void {
    const Mode = enum { traditional, winzip_aes, pkware_strong };
    const random = [_]u8{0x31} ** 11;
    const salt = [_]u8{0x57} ** 16;
    const iv = [_]u8{0x53} ** 16;
    const strong_random = [_]u8{0x63} ** 32;
    const validation = [_]u8{0x73} ** 12;
    for ([_]Mode{ .traditional, .winzip_aes, .pkware_strong }) |mode| {
        var backing = std.testing.FailingAllocator.init(a, .{});
        var profile: V.ZstdIncrementalParallelProfile = .{};
        var work: V.ZstdEncoderControlProfile = .{};
        var frame = native(V);
        frame.strategy = .btopt;
        frame.hq = .{ .max_price_evaluations = 0 };
        frame.control_profile = &work;
        var writer = try V.zip.incremental_writer.Writer.initWithOptions(backing.allocator(), .{ .zstd_options = frame, .zstd_parallel_options = policy(V, &profile) });
        var released = false;
        defer if (!released) writer.deinit();
        var entry: V.zip.incremental_writer.EntryOptions = .{ .name = "failed", .method = .zstandard };
        switch (mode) {
            .traditional => entry.traditional_encryption = .{ .password = password, .header_random = random },
            .winzip_aes => entry.winzip_aes = .{ .password = password, .strength = .aes256, .salt = &salt, .version = .ae1 },
            .pkware_strong => entry.pkware_strong_encryption = .{ .password = password, .strength = .aes256, .iv = iv, .random_data = &strong_random, .validation_data = &validation },
        }
        try writer.beginEntry(entry);
        var buffer: [256]u8 = undefined;
        var header: std.ArrayList(u8) = .empty;
        defer header.deinit(a);
        while (writer.snapshot().phase != .entry_data) {
            const step = try writer.step("", &buffer);
            try header.appendSlice(a, buffer[0..step.progress.output_written]);
        }
        var traditional = crypto.Cipher.init(password);
        defer traditional.deinit();
        var aes = try winzip_crypto.Cipher.init(password, &salt, .aes256);
        defer aes.deinit();
        if (mode == .traditional) {
            var decrypted_header: [12]u8 = undefined;
            traditional.decrypt(header.items[header.items.len - 12 ..], &decrypted_header);
        }
        var offset: usize = 0;
        var n: usize = 0;
        var failed = false;
        while (!failed) {
            if (offset == input.len) try writer.finishEntry();
            const before = writer.snapshot();
            const offered = input[offset..];
            const step = writer.step(offered, &buffer) catch |err| {
                try std.testing.expectEqual(error.SearchLimitExceeded, err);
                const progress = writer.current.?.codec.failedProgress() orelse return error.TestUnexpectedResult;
                const after = writer.snapshot();
                try std.testing.expectEqual(before.input_read + progress.input_read, after.input_read);
                offset += progress.input_read;
                switch (mode) {
                    .traditional => {
                        try std.testing.expectEqual(before.output_written + progress.output_written, after.output_written);
                        try std.testing.expectEqual(before.current_compressed_size + progress.output_written, after.current_compressed_size);
                        var plain: [256]u8 = undefined;
                        traditional.decrypt(buffer[0..progress.output_written], plain[0..progress.output_written]);
                        try std.testing.expectEqualDeep(traditional, writer.current.?.encryption.?.traditional.cipher);
                    },
                    .winzip_aes => {
                        try std.testing.expectEqual(before.output_written + progress.output_written, after.output_written);
                        try std.testing.expectEqual(before.current_compressed_size + progress.output_written, after.current_compressed_size);
                        var plain: [256]u8 = undefined;
                        aes.decrypt(buffer[0..progress.output_written], plain[0..progress.output_written]);
                        try std.testing.expectEqualDeep(aes, writer.current.?.encryption.?.winzip_aes.cipher);
                    },
                    .pkware_strong => {
                        const state = writer.current.?.encryption.?.pkwareState().?;
                        try std.testing.expectEqual(progress.output_written, state.codec_output_len);
                        try std.testing.expectEqual(@as(usize, 0), state.codec_output_pos);
                        try std.testing.expectEqual(before.output_written, after.output_written);
                        try std.testing.expectEqual(before.current_compressed_size, after.current_compressed_size);
                    },
                }
                try std.testing.expectEqual(.poisoned, after.phase);
                try std.testing.expectEqual(before.central_metadata_size, after.central_metadata_size);
                failed = true;
                break;
            };
            try calls(&n);
            offset += step.progress.input_read;
            switch (mode) {
                .traditional => {
                    var plain: [256]u8 = undefined;
                    traditional.decrypt(buffer[0..step.progress.output_written], plain[0..step.progress.output_written]);
                },
                .winzip_aes => {
                    var plain: [256]u8 = undefined;
                    aes.decrypt(buffer[0..step.progress.output_written], plain[0..step.progress.output_written]);
                },
                .pkware_strong => {},
            }
        }
        try std.testing.expect(failed and offset != 0);
        try std.testing.expect(work.price_limit_refusals > 0);
        try std.testing.expectEqual(@as(u64, 0), work.max_plan_price_evaluations);
        try std.testing.expect(profile.peak_requested_bytes <= 64 * 1024 * 1024);
        var crc = V.checksum.Crc32Best.init();
        crc.update(input[0..offset]);
        try std.testing.expectEqual(crc.digest(), writer.current.?.crc.digest());
        const snapshot = writer.snapshot();
        try std.testing.expectError(error.ZipWriterPoisoned, writer.step("not accepted", &buffer));
        try std.testing.expectEqualDeep(snapshot, writer.snapshot());
        writer.deinit();
        released = true;
        try std.testing.expectEqual(@as(usize, 0), profile.workers_live);
        try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
        try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
    }
}

fn rootMove(comptime V: type) !void {
    var profile: V.ZstdIncrementalParallelProfile = .{};
    const E = V.ZstdNativeIncrementalParallelFrameEncoder;
    var frame = native(V);
    frame.include_content_size = false;
    var original = try E.init(a, .{ .frame = frame, .parallel = policy(V, &profile) });
    var output: [257]u8 = undefined;
    const first = try original.step(input[0..256], &output);
    var moved = original;
    original = undefined;
    var released = false;
    defer if (!released) moved.deinit();
    var read = first.progress.input_read;
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(a);
    try bytes.appendSlice(a, output[0..first.progress.output_written]);
    var n: usize = 0;
    while (true) {
        if (read == input.len) moved.finish();
        const step = try moved.step(input[read..], &output);
        try calls(&n);
        read += step.progress.input_read;
        try bytes.appendSlice(a, output[0..step.progress.output_written]);
        if (step.status == .done) break;
    }
    moved.deinit();
    released = true;
    try std.testing.expectEqual(@as(usize, 0), profile.workers_live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    const decoded = try V.zstdDecodeNativeFrameAlloc(a, bytes.items);
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
}

fn abortEntry(comptime V: type) !void {
    var backing = std.testing.FailingAllocator.init(a, .{});
    var profile: V.ZstdIncrementalParallelProfile = .{};
    var writer = try V.zip.incremental_writer.Writer.initWithOptions(backing.allocator(), .{ .zstd_options = native(V), .zstd_parallel_options = policy(V, &profile) });
    var released = false;
    defer if (!released) writer.deinit();
    try writer.beginEntry(.{ .name = "abort", .method = .zstandard });
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(a);
    var n: usize = 0;
    try feed(&writer, &bytes, input[0..513], 257, 257, &n);
    const snapshot = writer.current.?.codec.zstd.parallel.snapshot();
    try std.testing.expect(snapshot.parallel.profile.accepted_input_bytes > 0);
    writer.deinit();
    released = true;
    try std.testing.expectEqual(@as(usize, 0), profile.workers_live);
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    try std.testing.expectEqual(backing.allocated_bytes, backing.freed_bytes);
}

fn widePledge(comptime V: type) !void {
    // A real wide Header only: no large payload is allocated or accepted.
    const pledge: V.StreamCount = (@as(V.StreamCount, 1) << 32) + 3;
    var profile: V.ZstdIncrementalParallelProfile = .{};
    var writer = try V.zip.incremental_writer.Writer.initWithOptions(a, .{ .zstd_options = native(V), .zstd_parallel_options = policy(V, &profile) });
    defer writer.deinit();
    try writer.beginEntry(.{ .name = "wide", .method = .zstandard, .expected_size = pledge });
    var prefix: [128]u8 = undefined;
    _ = try writer.step("", &prefix);
    var frame_header: [32]u8 = undefined;
    // Offering one byte lets the codec drain its Header, then own the byte.
    const step = try writer.step("x", &frame_header);
    const header = try V.zstd.inspectNativeFrameHeader(frame_header[0..step.progress.output_written]);
    try std.testing.expectEqual(@as(?u64, pledge), header.content_size);
    try std.testing.expectEqual(@as(V.StreamCount, step.progress.input_read), writer.snapshot().input_read);
    try std.testing.expect(step.progress.input_read <= 1);
}
