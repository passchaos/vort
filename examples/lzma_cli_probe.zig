//! Thin validation surface: the commands call the same modules as vort CLI.
const std = @import("std");
const vort = @import("vort");
const lzma = @import("cli/lzma.zig");
const xz = @import("cli/xz.zig");
const micro = @import("cli/microlzma.zig");

pub fn main(init: std.process.Init) !void {
    var buffer: [2048]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const command = args.next() orelse return error.MissingCommand;
    if (std.mem.eql(u8, command, "encode-lzma-file")) {
        try lzma.encode(init, &args, &writer.interface);
    } else if (std.mem.eql(u8, command, "encode-xz-file")) {
        try xz.encode(init, &args, &writer.interface, false);
    } else if (std.mem.eql(u8, command, "encode-xz-stored-file")) {
        try xz.encode(init, &args, &writer.interface, true);
    } else if (std.mem.eql(u8, command, "encode-microlzma-file")) {
        try micro.encode(init, &args, &writer.interface);
    } else if (std.mem.eql(u8, command, "encode-microlzma-prefix-file")) {
        try micro.encodeLimited(init, &args, &writer.interface);
    } else if (std.mem.eql(u8, command, "encode-microlzma-aligned-prefix-file")) {
        try micro.encodeAlignedLimited(init, &args, &writer.interface);
    } else if (std.mem.eql(u8, command, "decode-lzma-bounded-file")) {
        try decodeBounded(init, &args, &writer.interface);
    } else return error.UnknownCommand;
    try writer.interface.flush();
}

fn decodeBounded(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const expected_size = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const dictionary_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    const working_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
    if (args.next() != null) return error.UnexpectedLzmaArgument;
    if (expected_size > 1024 * 1024) return error.OutputLimitExceeded;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(1024 * 1024));
    defer init.gpa.free(input);
    const output = try init.gpa.alloc(u8, expected_size);
    defer init.gpa.free(output);
    var workspace = try vort.LzmaDecodeWorkspace.initWithOptions(init.gpa, .{
        .max_output_len = expected_size,
        .max_dictionary_size = dictionary_limit,
        .max_working_memory = working_limit,
    });
    defer workspace.deinit();
    const written = try workspace.decodeInto(input, output);
    if (written != expected_size) return error.SizeMismatch;
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = output });
    try stdout.print("decoded_bytes={d} dictionary_limit={d} working_memory_limit={d} peak_working_memory={d}\n", .{
        written, dictionary_limit, working_limit, workspace.peakWorkingMemoryBytes(),
    });
}
