const std = @import("std");
const vort = @import("vort");
const controls = @import("lzma_controls.zig");

pub fn encode(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const parsed = try controls.parse(args, 1);
    var options = try parsed.controls.baseOptions(vort.LzmaEncodeOptions);
    if (parsed.positionals[0]) |value| options.size_mode = try parseSizeMode(value);
    var profile: vort.LzmaEncodeWorkProfile = .{};
    try parsed.controls.apply(&options, "mode", if (parsed.controls.profile) &profile else null);
    try options.validate();
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
    defer init.gpa.free(input);
    const encoded = try vort.encodeLzmaAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("lzma_size_mode={s} input_bytes={d} compressed_bytes={d} path={s}\n", .{
        @tagName(options.size_mode), input.len, encoded.len, output_path,
    });
    if (parsed.controls.profile) try controls.printProfile(stdout, profile);
}

pub fn parseSizeMode(value: []const u8) !vort.LzmaSizeMode {
    if (std.mem.eql(u8, value, "end-marker") or std.mem.eql(u8, value, "unknown")) return .end_marker;
    if (std.mem.eql(u8, value, "known")) return .known;
    return error.InvalidLzmaSizeMode;
}
