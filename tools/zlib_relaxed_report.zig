const std = @import("std");
const vort = @import("vort");

const Payload = "payload";

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var json_path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--json")) {
            json_path = args.next() orelse return error.MissingJsonPath;
            continue;
        }
        return error.UnknownArgument;
    }

    var strict_rejections: usize = 0;
    var relaxed_successes: usize = 0;
    var dictionary_successes: usize = 0;
    var limited_rejections: usize = 0;

    const frame = try vort.encodeZlibLevelAlloc(init.gpa, Payload, 6);
    defer init.gpa.free(frame);

    var bad_adler = try init.gpa.dupe(u8, frame);
    defer init.gpa.free(bad_adler);
    bad_adler[bad_adler.len - 1] ^= 1;
    try expectZlibError(error.ChecksumMismatch, bad_adler, .{});
    strict_rejections += 1;
    try expectZlibPayload(init.gpa, bad_adler, .{ .ignore_adler = true });
    relaxed_successes += 1;

    var trailing = try init.gpa.alloc(u8, frame.len + 1);
    defer init.gpa.free(trailing);
    @memcpy(trailing[0..frame.len], frame);
    trailing[frame.len] = 0xaa;
    try expectZlibError(error.TrailingData, trailing, .{});
    strict_rejections += 1;
    try expectZlibPayload(init.gpa, trailing, .{ .allow_trailing_data = true });
    relaxed_successes += 1;

    var combined = try init.gpa.alloc(u8, frame.len + 1);
    defer init.gpa.free(combined);
    @memcpy(combined[0..frame.len], frame);
    combined[combined.len - 2] ^= 1;
    combined[combined.len - 1] = 0xbb;
    try expectZlibPayload(init.gpa, combined, .{ .ignore_adler = true, .allow_trailing_data = true });
    relaxed_successes += 1;

    try expectAllocExact(init.gpa, combined, .{ .ignore_adler = true, .allow_trailing_data = true });
    relaxed_successes += 1;
    try expectAllocLimited(init.gpa, combined, .{ .ignore_adler = true, .allow_trailing_data = true });
    relaxed_successes += 1;
    try expectLimitExceeded(init.gpa, combined, .{ .ignore_adler = true, .allow_trailing_data = true });
    limited_rejections += 1;

    const dictionary = "pay";
    const dict_frame = try vort.encodeZlibLevelWithDictionaryAlloc(init.gpa, Payload, dictionary, 6);
    defer init.gpa.free(dict_frame);
    var dict_combined = try init.gpa.alloc(u8, dict_frame.len + 1);
    defer init.gpa.free(dict_combined);
    @memcpy(dict_combined[0..dict_frame.len], dict_frame);
    dict_combined[dict_frame.len - 1] ^= 1;
    dict_combined[dict_frame.len] = 0xcc;
    const relaxed = vort.ZlibDecodeOptions{ .ignore_adler = true, .allow_trailing_data = true };
    var dict_out: [Payload.len]u8 = undefined;
    const dict_written = try vort.decodeZlibWithDictionaryAndOptions(dict_combined, &dict_out, dictionary, relaxed);
    if (dict_written != Payload.len or !std.mem.eql(u8, Payload, &dict_out)) return error.PayloadMismatch;
    dictionary_successes += 1;
    const dict_alloc = try vort.decodeZlibAllocWithDictionaryAndOptionsLimited(init.gpa, dict_combined, dictionary, relaxed, Payload.len);
    defer init.gpa.free(dict_alloc);
    if (!std.mem.eql(u8, Payload, dict_alloc)) return error.PayloadMismatch;
    dictionary_successes += 1;

    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout_writer.interface.print("zlib relaxed report: strict_rejections={d} relaxed_successes={d} dictionary_successes={d} limited_rejections={d}\n", .{ strict_rejections, relaxed_successes, dictionary_successes, limited_rejections });
    try stdout_writer.interface.flush();

    if (json_path) |path| try writeJson(init, path, strict_rejections, relaxed_successes, dictionary_successes, limited_rejections);
}

fn expectZlibError(expected: anyerror, frame: []const u8, options: vort.ZlibDecodeOptions) !void {
    var out: [Payload.len]u8 = undefined;
    if (vort.decodeZlibWithOptions(frame, &out, options)) |_| return error.ExpectedFailure else |err| {
        if (err != expected) return err;
    }
}

fn expectZlibPayload(allocator: std.mem.Allocator, frame: []const u8, options: vort.ZlibDecodeOptions) !void {
    var out: [Payload.len]u8 = undefined;
    const written = try vort.decodeZlibWithOptions(frame, &out, options);
    if (written != Payload.len or !std.mem.eql(u8, Payload, &out)) return error.PayloadMismatch;
    const decoded = try vort.decodeZlibAllocWithOptions(allocator, frame, options);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, Payload, decoded)) return error.PayloadMismatch;
}

fn expectAllocExact(allocator: std.mem.Allocator, frame: []const u8, options: vort.ZlibDecodeOptions) !void {
    const decoded = try vort.decodeZlibAllocWithOptionsExactSize(allocator, frame, options, Payload.len);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, Payload, decoded)) return error.PayloadMismatch;
}

fn expectAllocLimited(allocator: std.mem.Allocator, frame: []const u8, options: vort.ZlibDecodeOptions) !void {
    const decoded = try vort.decodeZlibAllocWithOptionsLimited(allocator, frame, options, Payload.len);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, Payload, decoded)) return error.PayloadMismatch;
}

fn expectLimitExceeded(allocator: std.mem.Allocator, frame: []const u8, options: vort.ZlibDecodeOptions) !void {
    if (vort.decodeZlibAllocWithOptionsLimited(allocator, frame, options, Payload.len - 1)) |decoded| {
        allocator.free(decoded);
        return error.ExpectedFailure;
    } else |err| switch (err) {
        error.OutputLimitExceeded => return,
        else => return err,
    }
}

fn writeJson(init: std.process.Init, path: []const u8, strict_rejections: usize, relaxed_successes: usize, dictionary_successes: usize, limited_rejections: usize) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    try writer.writer.print(
        "{{\n  \"schema\": \"vort.zlib_relaxed_report\",\n  \"schema_version\": 1,\n  \"strict_rejections\": {d},\n  \"relaxed_successes\": {d},\n  \"dictionary_successes\": {d},\n  \"limited_rejections\": {d}\n}}\n",
        .{ strict_rejections, relaxed_successes, dictionary_successes, limited_rejections },
    );
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}
