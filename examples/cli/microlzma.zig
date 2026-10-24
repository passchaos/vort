const std = @import("std");
const vort = @import("vort");
const controls = @import("lzma_controls.zig");

pub fn encode(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const parsed = try parseOptions(args);
    var options = parsed.options;
    var profile: vort.LzmaEncodeWorkProfile = .{};
    try parsed.controls.apply(&options, "mode", if (parsed.controls.profile) &profile else null);
    try options.validate();
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
    defer init.gpa.free(input);
    const encoded = try vort.encodeMicroLzmaAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("input_bytes={d} microlzma_bytes={d} dictionary={d} path={s}\n", .{
        input.len, encoded.len, options.dictionary_size, output_path,
    });
    if (parsed.controls.profile) try controls.printProfile(stdout, profile);
}

pub fn encodeLimited(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    return encodePrefix(init, args, stdout, false);
}

pub fn encodeAlignedLimited(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    return encodePrefix(init, args, stdout, true);
}

fn encodePrefix(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer, aligned: bool) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const capacity_text = args.next() orelse return error.MissingCorpusPath;
    const capacity = try std.fmt.parseInt(usize, capacity_text, 10);
    const alignment = if (aligned)
        try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10)
    else
        1;
    const parsed = try parseOptions(args);
    var options = parsed.options;
    var profile: vort.LzmaEncodeWorkProfile = .{};
    try parsed.controls.apply(&options, "mode", if (parsed.controls.profile) &profile else null);
    try options.validate();
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
    defer init.gpa.free(input);
    var encoded = if (aligned)
        try vort.encodeMicroLzmaAlignedDestSizeAlloc(init.gpa, input, capacity, alignment, options)
    else
        try vort.encodeMicroLzmaDestSizeAlloc(init.gpa, input, capacity, options);
    defer encoded.deinit(init.gpa);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded.bytes });
    try stdout.print("input_bytes={d} consumed={d} microlzma_bytes={d} capacity={d} alignment={d} dictionary={d} path={s}\n", .{
        input.len, encoded.consumed, encoded.bytes.len, capacity, alignment, options.dictionary_size, output_path,
    });
    if (parsed.controls.profile) try controls.printProfile(stdout, profile);
}

pub fn decode(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const expected_size_text = args.next() orelse return error.MissingCorpusPath;
    const expected_size = try std.fmt.parseInt(usize, expected_size_text, 10);
    const dictionary_size = try parseNumber(u32, args, 8 * 1024 * 1024);
    const compressed = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(8 * 1024 * 1024));
    defer init.gpa.free(compressed);
    const decoded = try vort.decodeMicroLzmaAllocLimited(init.gpa, compressed, expected_size, dictionary_size, 12 * 1024 * 1024);
    defer init.gpa.free(decoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("microlzma_compressed_bytes={d} decoded_bytes={d} dictionary={d} path={s}\n", .{
        compressed.len, decoded.len, dictionary_size, output_path,
    });
}

fn parseNumber(comptime T: type, args: *std.process.Args.Iterator, default: T) !T {
    return if (args.next()) |value| try std.fmt.parseInt(T, value, 10) else default;
}

const ParsedOptions = struct {
    options: vort.MicroLzmaEncodeOptions,
    controls: controls.Controls,
};

fn parseOptions(args: *std.process.Args.Iterator) !ParsedOptions {
    const parsed = try controls.parse(args, 5);
    var options = try parsed.controls.baseOptions(vort.MicroLzmaEncodeOptions);
    options.dictionary_size = try controls.parseNumber(u32, parsed.positionals[0], options.dictionary_size);
    options.properties.lc = try controls.parseNumber(u4, parsed.positionals[1], options.properties.lc);
    options.properties.lp = try controls.parseNumber(u3, parsed.positionals[2], options.properties.lp);
    options.properties.pb = try controls.parseNumber(u3, parsed.positionals[3], options.properties.pb);
    if (parsed.positionals[4]) |value| options.mode = try controls.convertMode(@TypeOf(options.mode), try controls.parseMode(value));
    return .{ .options = options, .controls = parsed.controls };
}
