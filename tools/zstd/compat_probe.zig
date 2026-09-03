const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

const levels = [_]c_int{ 1, 3, 9, 19, 22 };
const sizes = [_]usize{ 0, 1, 15, 64, 255, 1024, 8192, 65536, 131073, 524288 };
const optional_golden_root = "../../Work/zstd/tests/golden-decompression";

const Shape = enum { text, structured, binary, random };

pub fn main(init: std.process.Init) !void {
    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();
    var checked: usize = 0;
    var unsupported: usize = 0;
    var corpus_cases: usize = 0;
    var golden_cases: usize = 0;
    var golden_error_cases: usize = 0;
    var advanced_cases: usize = 0;
    var streaming_cases: usize = 0;
    for (std.meta.tags(Shape)) |shape| {
        for (sizes) |size| {
            const payload = try init.gpa.alloc(u8, size);
            defer init.gpa.free(payload);
            fill(shape, payload);
            for (levels) |level| {
                const encoded = try runtime.encodeAlloc(init.gpa, payload, level);
                defer init.gpa.free(encoded);
                const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
                    unsupported += 1;
                    std.debug.print(
                        "zstd_compat_unsupported shape={s} size={d} level={d} encoded={d} error={s}\n",
                        .{ @tagName(shape), size, level, encoded.len, @errorName(err) },
                    );
                    continue;
                };
                defer init.gpa.free(decoded);
                if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
                checked += 1;
            }
        }
    }
    const advanced_payload = try init.gpa.alloc(u8, 2 * 1024 * 1024);
    defer init.gpa.free(advanced_payload);
    fillAdvanced(advanced_payload);
    const advanced_options = [_]libzstd.Runtime.AdvancedOptions{
        .{ .level = 1, .content_size = false },
        .{ .level = 9, .checksum = true },
        .{ .level = 19, .content_size = false, .checksum = true },
        .{ .level = 3, .window_log = 10 },
        .{ .level = 19, .window_log = 21 },
        .{ .level = 19, .long_distance_matching = true },
        .{ .level = 3, .strategy = 1 },
        .{ .level = 3, .strategy = 2 },
        .{ .level = 3, .strategy = 3 },
        .{ .level = 3, .strategy = 4 },
        .{ .level = 3, .strategy = 5 },
        .{ .level = 3, .strategy = 6 },
        .{ .level = 3, .strategy = 7 },
        .{ .level = 3, .strategy = 8 },
        .{ .level = 3, .strategy = 9 },
    };
    for (advanced_options) |options| {
        const encoded = try runtime.encodeAdvancedAlloc(init.gpa, advanced_payload, options);
        defer init.gpa.free(encoded);
        const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
            std.debug.print("zstd_compat_unsupported advanced level={d} content_size={} checksum={} window_log={any} strategy={any} ldm={} encoded={d} error={s}\n", .{ options.level, options.content_size, options.checksum, options.window_log, options.strategy, options.long_distance_matching, encoded.len, @errorName(err) });
            return err;
        };
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, advanced_payload, decoded)) return error.SizeMismatch;
        checked += 1;
        advanced_cases += 1;
    }
    const streaming_options = [_]struct {
        options: libzstd.Runtime.AdvancedOptions,
        chunk_len: usize,
        flush_each_chunk: bool,
    }{
        .{ .options = .{ .level = 1, .content_size = false }, .chunk_len = 7777, .flush_each_chunk = false },
        .{ .options = .{ .level = 3, .content_size = false, .checksum = true }, .chunk_len = 32 * 1024, .flush_each_chunk = true },
        .{ .options = .{ .level = 9, .content_size = false }, .chunk_len = 96 * 1024, .flush_each_chunk = true },
        .{ .options = .{ .level = 19, .content_size = false, .checksum = true, .strategy = 9 }, .chunk_len = 128 * 1024, .flush_each_chunk = true },
    };
    for (streaming_options) |case| {
        const encoded = try runtime.encodeStreamingAlloc(init.gpa, advanced_payload, case.options, case.chunk_len, case.flush_each_chunk);
        defer init.gpa.free(encoded);
        const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
            std.debug.print("zstd_compat_unsupported streaming level={d} checksum={} strategy={any} chunk={d} flush={} encoded={d} error={s}\n", .{ case.options.level, case.options.checksum, case.options.strategy, case.chunk_len, case.flush_each_chunk, encoded.len, @errorName(err) });
            return err;
        };
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, advanced_payload, decoded)) return error.SizeMismatch;
        checked += 1;
        streaming_cases += 1;
    }
    const corpus_paths = [_][]const u8{
        "README.md",
        "docs/roadmap.md",
        "../../Work/zstd/tests/fuzzer.c",
        "../../Work/zstd/tests/zstreamtest.c",
    };
    for (corpus_paths) |path| {
        const payload = std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(2 * 1024 * 1024)) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer init.gpa.free(payload);
        for (levels) |level| {
            const encoded = try runtime.encodeAlloc(init.gpa, payload, level);
            defer init.gpa.free(encoded);
            const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
                std.debug.print("zstd_compat_unsupported path={s} size={d} level={d} encoded={d} error={s}\n", .{ path, payload.len, level, encoded.len, @errorName(err) });
                return err;
            };
            defer init.gpa.free(decoded);
            if (!std.mem.eql(u8, payload, decoded)) return error.SizeMismatch;
            checked += 1;
            corpus_cases += 1;
        }
    }
    const GoldenCase = struct { name: []const u8, expected: enum { empty, zeros_128k, zeros_1m, hello } };
    const golden_cases_to_try = [_]GoldenCase{
        .{ .name = "block-128k.zst", .expected = .zeros_128k },
        .{ .name = "empty-block.zst", .expected = .empty },
        .{ .name = "rle-first-block.zst", .expected = .zeros_1m },
        .{ .name = "zeroSeq_2B.zst", .expected = .hello },
    };
    for (golden_cases_to_try) |case| {
        var path_buffer: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buffer, "{s}/{s}", .{ optional_golden_root, case.name });
        const encoded = std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(2 * 1024 * 1024)) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer init.gpa.free(encoded);
        const expected_size = try vort.zstdDecodedFrameSize(encoded);
        const decoded = vort.zstdDecodeFrameAlloc(init.gpa, encoded) catch |err| {
            std.debug.print("zstd_compat_unsupported golden={s} decoded={d} encoded={d} error={s}\n", .{ path, expected_size, encoded.len, @errorName(err) });
            return err;
        };
        defer init.gpa.free(decoded);
        switch (case.expected) {
            .empty => if (decoded.len != 0) return error.SizeMismatch,
            .zeros_128k => if (decoded.len != 131068 or !allBytesEqual(decoded, 0)) return error.SizeMismatch,
            .zeros_1m => if (decoded.len != 1024 * 1024 or !allBytesEqual(decoded, 0)) return error.SizeMismatch,
            .hello => if (!std.mem.eql(u8, decoded, "Hello World!\n")) return error.SizeMismatch,
        }
        checked += 1;
        golden_cases += 1;
    }
    const golden_error_names = [_][]const u8{
        "off0.bin.zst",
        "truncated_huff_state.zst",
        "zeroSeq_extraneous.zst",
    };
    for (golden_error_names) |name| {
        var path_buffer: [256]u8 = undefined;
        const path = try std.fmt.bufPrint(&path_buffer, "../../Work/zstd/tests/golden-decompression-errors/{s}", .{name});
        const encoded = std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(2 * 1024 * 1024)) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        defer init.gpa.free(encoded);
        if (vort.zstdDecodedFrameSize(encoded)) |decoded_size| {
            std.debug.print("zstd_compat_invalid_accepted golden={s} decoded={d} encoded={d}\n", .{ path, decoded_size, encoded.len });
            return error.CorruptFrame;
        } else |_| {}
        if (vort.zstdDecodeFrameAlloc(init.gpa, encoded)) |decoded| {
            defer init.gpa.free(decoded);
            std.debug.print("zstd_compat_invalid_decoded golden={s} decoded={d} encoded={d}\n", .{ path, decoded.len, encoded.len });
            return error.CorruptFrame;
        } else |_| {}
        checked += 1;
        golden_error_cases += 1;
    }
    if (unsupported != 0) return error.UnsupportedZstdFeature;
    std.debug.print(
        "zstd_compat_probe checked={d} unsupported={d} advanced_cases={d} streaming_cases={d} corpus_cases={d} golden_cases={d} golden_error_cases={d} version={s}\n",
        .{ checked, unsupported, advanced_cases, streaming_cases, corpus_cases, golden_cases, golden_error_cases, runtime.version() },
    );
}

fn fillAdvanced(payload: []u8) void {
    var state: u32 = 0x71c3_95ad;
    for (payload, 0..) |*byte, index| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = if (index % 32_768 < 24_576)
            @truncate((index * 17 + index / 97) % 251)
        else
            @truncate(state >> 16);
    }
    // Repeat two distant regions so the high levels/LDM case has a real
    // opportunity to emit offsets across ordinary block boundaries.
    @memcpy(payload[1024 * 1024 ..][0 .. 256 * 1024], payload[0 .. 256 * 1024]);
    @memcpy(payload[1536 * 1024 ..][0 .. 256 * 1024], payload[384 * 1024 ..][0 .. 256 * 1024]);
}

fn allBytesEqual(bytes: []const u8, expected: u8) bool {
    for (bytes) |byte| if (byte != expected) return false;
    return true;
}

fn fill(shape: Shape, payload: []u8) void {
    switch (shape) {
        .text => {
            const unit = "Zstandard compatibility corpus with repeated words and punctuation.\n";
            for (payload, 0..) |*byte, index| byte.* = unit[index % unit.len];
        },
        .structured => {
            const unit = "{\"service\":\"vort\",\"value\":12345,\"ok\":true}\n";
            for (payload, 0..) |*byte, index| byte.* = unit[index % unit.len];
        },
        .binary => for (payload, 0..) |*byte, index| {
            byte.* = if (index % 64 < 48) @truncate(index * 17) else @truncate(index * 73 + index / 31);
        },
        .random => {
            var state: u32 = 0x7a57_1b5d;
            for (payload) |*byte| {
                state = state *% 1_664_525 +% 1_013_904_223;
                byte.* = @truncate(state >> 16);
            }
        },
    }
}
