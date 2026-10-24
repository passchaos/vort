const std = @import("std");
const vort = @import("vort");
const controls = @import("lzma_controls.zig");
const filters_cli = @import("filters.zig");

pub fn encode(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer, stored_only: bool) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const parsed = try controls.parse(args, 5);
    var options = try parsed.controls.baseOptions(vort.XzEncodeOptions);
    if (parsed.positionals[0]) |value| options.check = try parseCheck(value);
    options.block_size = try controls.parseNumber(usize, parsed.positionals[1], options.block_size);
    var filter_storage: [3]vort.XzFilter = undefined;
    options.filters = try filters_cli.parse(parsed.positionals[2], &filter_storage);
    options.dictionary_size = try controls.parseNumber(usize, parsed.positionals[3], options.dictionary_size);
    if (parsed.positionals[4]) |value| options.parser = try controls.convertMode(@TypeOf(options.parser), try controls.parseMode(value));
    var profile: vort.LzmaEncodeWorkProfile = .{};
    try parsed.controls.apply(&options, "parser", if (parsed.controls.profile) &profile else null);
    try options.validate();
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(512 * 1024 * 1024));
    defer init.gpa.free(input);
    const encoded = if (stored_only)
        try vort.encodeXzStoredAlloc(init.gpa, input, options)
    else
        try vort.encodeXzAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
    try stdout.print("xz_mode={s} input_bytes={d} compressed_bytes={d} blocks={d} dictionary={d} parser={s} path={s}\n", .{
        if (stored_only) "stored" else "compressed",
        input.len,
        encoded.len,
        if (input.len == 0) 0 else 1 + (input.len - 1) / options.block_size,
        options.dictionary_size,
        @tagName(options.parser),
        output_path,
    });
    if (parsed.controls.profile) try controls.printProfile(stdout, profile);
}

pub fn parseCheck(value: []const u8) !vort.XzCheck {
    return std.meta.stringToEnum(vort.XzCheck, value) orelse error.InvalidChecksumMode;
}
