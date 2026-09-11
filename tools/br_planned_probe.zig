const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse return error.InvalidBlockPlan;
    const lazy = std.mem.startsWith(u8, mode, "lazy-");
    const ratio = std.mem.startsWith(u8, mode, "ratio-");
    const static_dictionary = std.mem.startsWith(u8, mode, "dictionary-");
    const stable_fast = std.mem.startsWith(u8, mode, "stable-fast-");
    const stable_balanced = std.mem.startsWith(u8, mode, "stable-balanced-");
    const dictionary_index_bytes = std.mem.eql(u8, mode, "dictionary-index-bytes");
    if (dictionary_index_bytes) {
        var text: [32]u8 = undefined;
        const written = try std.fmt.bufPrint(&text, "{d}\n", .{vort.brPlannedStaticDictionaryIndexBytes()});
        try std.Io.File.stdout().writeStreamingAll(init.io, written);
        return;
    }
    if (std.mem.eql(u8, mode, "chunked-multiblock")) {
        const first = "alpha beta gamma delta alpha beta gamma delta " ** 64;
        const middle = "qzxwvbnm1234567890QZXWVBNM!@#$%^&*";
        const last = "omega theta lambda omega theta lambda " ** 64;
        const chunks = [_][]const u8{ "", first, middle, "", last };
        const encoded = try vort.brEncodePlannedStreamChunksAlloc(init.gpa, &chunks);
        defer init.gpa.free(encoded);
        try std.Io.File.stdout().writeStreamingAll(init.io, encoded);
        return;
    }
    if (std.mem.eql(u8, mode, "chunked-large")) {
        const payload = "abcdefghijklmnopqrstuvwxyz012345" ** 2049;
        const chunks = [_][]const u8{payload};
        const encoded = try vort.brEncodePlannedStreamChunksAlloc(init.gpa, &chunks);
        defer init.gpa.free(encoded);
        try std.Io.File.stdout().writeStreamingAll(init.io, encoded);
        return;
    }
    if (std.mem.eql(u8, mode, "ratio-oversized")) {
        const input_len = vort.brotliMaxUncompressedMetaBlockLen + 17;
        const payload = try init.gpa.alloc(u8, input_len);
        defer init.gpa.free(payload);
        for (payload, 0..) |*byte, i| byte.* = "abcd0123"[i & 7];
        const encoded = try vort.brEncodePlannedStreamRatioAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        try std.Io.File.stdout().writeStreamingAll(init.io, encoded);
        return;
    }
    if (std.mem.eql(u8, mode, "ratio-literal-split")) {
        const payload = try init.gpa.alloc(u8, 96 * 1024);
        defer init.gpa.free(payload);
        var state: u32 = 0x1234_5678;
        for (payload, 0..) |*byte, i| {
            state = state *% 1_664_525 +% 1_013_904_223;
            const nibble: u8 = @truncate(state >> 28);
            byte.* = if (i < payload.len / 6) nibble else 240 + nibble;
        }
        const encoded = try vort.brEncodePlannedStreamRatioAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const summary = try vort.brSummarizeStream(encoded);
        if (summary.max_literal_block_types != 2 or summary.max_literal_context_trees != 2)
            return error.InvalidBlockPlan;
        try std.Io.File.stdout().writeStreamingAll(init.io, encoded);
        return;
    }
    if (std.mem.eql(u8, mode, "ratio-command-split")) {
        const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, "src/br/dictionary.bin", init.gpa, .limited(128 * 1024));
        defer init.gpa.free(payload);
        const encoded = try vort.brEncodePlannedStreamRatioAlloc(init.gpa, payload);
        defer init.gpa.free(encoded);
        const summary = try vort.brSummarizeStreamAlloc(init.gpa, encoded);
        if (summary.max_command_block_types != 2 or
            summary.max_distance_block_types != 2 or
            summary.max_distance_context_trees != 2) return error.InvalidBlockPlan;
        try std.Io.File.stdout().writeStreamingAll(init.io, encoded);
        return;
    }
    if (std.mem.eql(u8, mode, "incremental-planned")) {
        var payload: [1024]u8 = undefined;
        @memset(payload[0..512], 'a');
        var state: u32 = 0x1234_5678;
        for (payload[512..]) |*byte| {
            state = state *% 1_664_525 +% 1_013_904_223;
            byte.* = @truncate(state >> 24);
        }
        var encoder = vort.BrotliIncrementalPlannedStreamEncoder.initWithOptions(init.gpa, .{ .block_len = 512 });
        defer encoder.deinit();
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(init.gpa);
        var scratch: [7]u8 = undefined;
        var offset: usize = 0;
        while (offset < payload.len) {
            const end = @min(payload.len, offset + 73);
            const result = try encoder.step(payload[offset..end], &scratch);
            offset += result.progress.input_read;
            try encoded.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
        }
        try encoder.finish();
        while (true) {
            const result = try encoder.step("", &scratch);
            try encoded.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
            if (result.status == .done) break;
        }
        try std.Io.File.stdout().writeStreamingAll(init.io, encoded.items);
        return;
    }
    if (std.mem.eql(u8, mode, "incremental-planned-history")) {
        var first: [4096]u8 = undefined;
        var state: u32 = 0x9e37_79b9;
        for (&first) |*byte| {
            state = state *% 1_664_525 +% 1_013_904_223;
            byte.* = @truncate(state >> 24);
        }
        const payload = first ++ first;
        var encoder = vort.BrotliIncrementalPlannedStreamEncoder.initWithOptions(init.gpa, .{ .block_len = first.len });
        defer encoder.deinit();
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(init.gpa);
        var scratch: [11]u8 = undefined;
        var offset: usize = 0;
        while (offset < payload.len) {
            const result = try encoder.step(payload[offset..], &scratch);
            offset += result.progress.input_read;
            try encoded.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
        }
        try encoder.finish();
        while (true) {
            const result = try encoder.step("", &scratch);
            try encoded.appendSlice(init.gpa, scratch[0..result.progress.output_written]);
            if (result.status == .done) break;
        }
        try std.Io.File.stdout().writeStreamingAll(init.io, encoded.items);
        return;
    }
    const name = if (lazy) mode["lazy-".len..] else if (ratio) mode["ratio-".len..] else if (static_dictionary) mode["dictionary-".len..] else if (stable_fast) mode["stable-fast-".len..] else if (stable_balanced) mode["stable-balanced-".len..] else mode;
    const payload = if (std.mem.eql(u8, name, "json"))
        "{\"kind\":\"event\",\"active\":true,\"values\":[1,2,3,5,8,13]}\n" ** 48
    else if (std.mem.eql(u8, name, "source"))
        "pub fn update(state: *State, value: u32) void { state.total += value; state.count += 1; }\n" ** 40
    else if (std.mem.eql(u8, name, "log"))
        "2026-08-21T02:00:00Z level=info service=vort request=compress status=ok bytes=4096\n" ** 40
    else if (std.mem.eql(u8, name, "words"))
        " information follows the information"
    else if (std.mem.eql(u8, name, "dictionary-short"))
        "Information about compression performance and dictionary support."
    else if (std.mem.eql(u8, name, "dictionary-mixed"))
        "abcdefghabcdefgh information follows abcdefghabcdefgh"
    else if (std.mem.eql(u8, name, "dictionary-word"))
        "information"
    else if (std.mem.eql(u8, name, "dictionary-uppercase"))
        "INFORMATION"
    else if (std.mem.eql(u8, name, "dictionary-unmatched"))
        "qzxwvbnm"
    else if (std.mem.eql(u8, name, "ratio-incompressible"))
        "qzxwvbnm1234567890QZXWVBNM!@#$%^&*"
    else if (std.mem.eql(u8, name, "incompressible"))
        "qzxwvbnm1234567890QZXWVBNM!@#$%^&*"
    else if (std.mem.eql(u8, name, "tiny"))
        "abcd"
    else
        return error.InvalidBlockPlan;
    const encoded = if (stable_fast)
        try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, payload, .{ .level = .fast })
    else if (stable_balanced)
        try vort.brEncodePlannedStreamWithOptionsAlloc(init.gpa, payload, .{ .level = .balanced })
    else if (lazy)
        try vort.brEncodePlannedStreamLazyAlloc(init.gpa, payload)
    else if (ratio)
        try vort.brEncodePlannedStreamRatioAlloc(init.gpa, payload)
    else if (static_dictionary)
        try vort.brEncodePlannedStreamStaticDictionaryAlloc(init.gpa, payload)
    else
        try vort.brEncodePlannedStreamAlloc(init.gpa, payload);
    defer init.gpa.free(encoded);
    var buffer: [256]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try writer.interface.writeAll(encoded);
    try writer.interface.flush();
}
