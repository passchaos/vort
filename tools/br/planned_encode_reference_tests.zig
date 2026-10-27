//! CLI contracts and actual libbrotli streams for reference parameter evidence.
const std = @import("std");
const br = @import("vort_br");
const libbrotli = @import("libbrotli_runtime.zig");
const reference_options = @import("reference_encode_options.zig");

pub fn contracts(parseOptions: anytype) !void {
    const empty = [_][*:0]const u8{};
    var empty_args = try std.process.Args.Iterator.initAllocator(.{ .vector = &empty }, std.testing.allocator);
    defer empty_args.deinit();
    var defaults = try parseOptions(std.testing.allocator, &empty_args);
    defer defaults.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(libbrotli.Runtime.OneShotOptions{ .quality = 3 }, try defaults.reference_parameters.resolve(3));
    for ([_][]const u8{ "generic", "text", "font" }, 0..) |name, mode| {
        const mode_flag = try std.fmt.allocPrintSentinel(std.testing.allocator, "--reference-mode={s}", .{name}, 0);
        defer std.testing.allocator.free(mode_flag);
        const argv = [_][*:0]const u8{ "--reference-lgwin", "16", mode_flag.ptr, "--planned-quality=8" };
        var args = try std.process.Args.Iterator.initAllocator(.{ .vector = &argv }, std.testing.allocator);
        defer args.deinit();
        var options = try parseOptions(std.testing.allocator, &args);
        defer options.deinit(std.testing.allocator);
        try std.testing.expectEqualDeep(libbrotli.Runtime.OneShotOptions{ .quality = 8, .lgwin = 16, .mode = @intCast(mode) }, try options.reference_parameters.resolve(8));
    }
    const invalid = [_][*:0]const u8{
        "--reference-lgwin=9",          "--reference-lgwin=25",  "--reference-lgwin=-1",
        "--reference-lgwin=2147483648", "--reference-lgwin=",    "--reference-lgwin=text",
        "--reference-mode=0",           "--reference-mode=TEXT", "--reference-mode=",
        "--reference-mode=invalid",
    };
    for (invalid) |flag| {
        const argv = [_][*:0]const u8{flag};
        var args = try std.process.Args.Iterator.initAllocator(.{ .vector = &argv }, std.testing.allocator);
        defer args.deinit();
        try std.testing.expectError(error.InvalidReferenceParameters, parseOptions(std.testing.allocator, &args));
    }
    for ([_][*:0]const u8{ "--reference-lgwin", "--reference-mode" }) |flag| {
        const argv = [_][*:0]const u8{flag};
        var args = try std.process.Args.Iterator.initAllocator(.{ .vector = &argv }, std.testing.allocator);
        defer args.deinit();
        try std.testing.expectError(error.MissingLimit, parseOptions(std.testing.allocator, &args));
    }
    const split = [_][*:0]const u8{ "--reference-lgwin=24", "--reference-mode", "font" };
    var split_args = try std.process.Args.Iterator.initAllocator(.{ .vector = &split }, std.testing.allocator);
    defer split_args.deinit();
    var split_options = try parseOptions(std.testing.allocator, &split_args);
    defer split_options.deinit(std.testing.allocator);
    try std.testing.expectEqualDeep(libbrotli.Runtime.OneShotOptions{ .quality = 3, .lgwin = 24, .mode = 2 }, try split_options.reference_parameters.resolve(3));
}

pub fn actualWires() !void {
    const allocator = std.testing.allocator;
    var runtime = libbrotli.Runtime.open() catch return error.SkipZigTest;
    defer runtime.deinit();
    const input = "Brotli reference window and mode roundtrip. Compression dictionary information.\n" ** 16;
    const invalid = [_]libbrotli.Runtime.OneShotOptions{
        .{ .quality = -1 },             .{ .quality = 12 },            .{ .quality = 8, .lgwin = 9 },
        .{ .quality = 8, .lgwin = 31 }, .{ .quality = 8, .mode = -1 }, .{ .quality = 8, .mode = 3 },
    };
    for (invalid) |settings| {
        var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
        try std.testing.expectError(error.InvalidReferenceParameters, runtime.encodeWithOptionsAlloc(failing.allocator(), input, settings));
        try std.testing.expect(!failing.has_induced_failure);
    }
    try (libbrotli.Runtime.OneShotOptions{ .quality = 8, .lgwin = 30 }).validate();

    for ([_]br.PlannedMode{ .generic, .text, .font }) |mode| {
        const vort_wire = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, .{ .quality = 8, .mode = mode });
        defer allocator.free(vort_wire);
        const vort_window = (try br.summarizeStreamAlloc(allocator, vort_wire)).window_bits;
        for ([_]c_int{ 10, 16, 22, 24 }) |lgwin| {
            const settings: libbrotli.Runtime.OneShotOptions = .{ .quality = 8, .lgwin = lgwin, .mode = try reference_options.parseMode(@tagName(mode)) };
            const wire = try runtime.encodeWithOptionsAlloc(allocator, input, settings);
            defer allocator.free(wire);
            const window = (try br.summarizeStreamAlloc(allocator, wire)).window_bits;
            try std.testing.expectEqual(@as(u5, @intCast(lgwin)), window);
            try std.testing.expectEqual(lgwin == vort_window, reference_options.match(8, @tagName(mode), vort_window, settings, window));
            const decoded = try br.decodeStreamAllocExactSize(allocator, wire, input.len);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
            var reference_decoded: [input.len]u8 = undefined;
            try runtime.decode(wire, &reference_decoded);
            try std.testing.expectEqualSlices(u8, input, &reference_decoded);

            // Compare with the public C function directly, using the requested
            // settings, to cover the option-bearing adapter's actual call.
            const direct = try allocator.alloc(u8, runtime.max_compressed_size(input.len));
            defer allocator.free(direct);
            var written = direct.len;
            try std.testing.expect(runtime.compress(8, lgwin, settings.mode, input.len, input.ptr, &written, direct.ptr) != 0);
            try std.testing.expectEqualSlices(u8, wire, direct[0..written]);
        }
    }
    for ([_]u4{ 0, 1 }) |quality| {
        const settings: libbrotli.Runtime.OneShotOptions = .{ .quality = quality, .lgwin = 16 };
        const wire = try runtime.encodeWithOptionsAlloc(allocator, input, settings);
        defer allocator.free(wire);
        const window = (try br.summarizeStreamAlloc(allocator, wire)).window_bits;
        try std.testing.expectEqual(@as(u5, 18), window);
        const vort_wire = try br.encodePlannedStreamWithOptionsAlloc(allocator, input, .{ .quality = quality, .window_bits = 16 });
        defer allocator.free(vort_wire);
        const vort_window = (try br.summarizeStreamAlloc(allocator, vort_wire)).window_bits;
        try std.testing.expect(!reference_options.match(quality, "generic", vort_window, settings, window));
        const decoded = try br.decodeStreamAllocExactSize(allocator, wire, input.len);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
    try std.testing.expect(!reference_options.match(null, "generic", 16, .{ .quality = 8, .lgwin = 16 }, 16));
    try std.testing.expect(!reference_options.match(8, "text", 16, .{ .quality = 8, .lgwin = 16 }, 16));
    try std.testing.expect(!reference_options.match(7, "generic", 16, .{ .quality = 8, .lgwin = 16 }, 16));
}
