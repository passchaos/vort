//! Produce comparable standard gzip streams through the public incremental API.
const std = @import("std");
const codec = @import("codec");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const mode = args.next() orelse return error.MissingMode;
    const rsyncable = if (std.mem.eql(u8, mode, "rsyncable")) true else if (std.mem.eql(u8, mode, "plain")) false else return error.InvalidMode;
    if (args.next() != null) return error.UnexpectedArgument;

    const dir = std.Io.Dir.cwd();
    const input = try dir.readFileAlloc(init.io, input_path, init.gpa, .limited(16 * 1024 * 1024));
    defer init.gpa.free(input);
    var encoder = codec.GzipIncrementalBestEncoder.initWithOptions(init.gpa, .{ .raw = .{
        .compression = codec.optionsForLevel(.default),
        .rsyncable = rsyncable,
    } });
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(init.gpa);

    var output: [4096]u8 = undefined;
    var offset: usize = 0;
    while (offset < input.len) {
        const chunk = input[offset..][0..@min(7777, input.len - offset)];
        const result = try encoder.step(chunk, &output);
        try wire.appendSlice(init.gpa, output[0..result.progress.output_written]);
        offset += result.progress.input_read;
        if (result.progress.input_read == 0 and result.progress.output_written == 0) return error.NoProgress;
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step("", &output);
        try wire.appendSlice(init.gpa, output[0..result.progress.output_written]);
        if (result.status == .done) break;
        if (result.progress.output_written == 0) return error.NoProgress;
    }
    try dir.writeFile(init.io, .{ .sub_path = output_path, .data = wire.items });
}
