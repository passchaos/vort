const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const format = args.next() orelse return error.MissingFormat;
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const input = try std.Io.Dir.cwd().readFileAlloc(
        init.io,
        input_path,
        init.gpa,
        .limited(128 * 1024 * 1024),
    );
    defer init.gpa.free(input);
    const options = vort.optionsForCompressionLevel(.default);
    const encoded = if (std.mem.eql(u8, format, "raw"))
        try vort.encodeRawBestAdaptiveSplitAlloc(init.gpa, input, options, options.split_options)
    else if (std.mem.eql(u8, format, "zlib"))
        try vort.encodeZlibBestAdaptiveSplitAlloc(init.gpa, input, options, options.split_options)
    else if (std.mem.eql(u8, format, "gzip"))
        try vort.encodeGzipBestAdaptiveSplitAlloc(init.gpa, input, options, options.split_options)
    else
        return error.InvalidFormat;
    defer init.gpa.free(encoded);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = encoded });
}
