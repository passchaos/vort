const std = @import("std");
const vort = @import("vort");
const controls = @import("brotli_controls.zig");

pub fn encodeFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer, streaming: bool) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const parsed = try controls.parse(args);
    var profile: vort.BrotliHqProfile = .{};
    var memory_profile: vort.BrotliEncodeMemoryProfile = .{};
    const caller_profile = if (parsed.profile) &profile else null;
    const caller_memory_profile = if (parsed.memory_profile) &memory_profile else null;
    // Public bounds validate scalar settings before reading or touching files.
    const one_shot = try parsed.resolveWithMemoryProfile(vort.br.PlannedEncodeOptions, caller_profile, caller_memory_profile);
    const stream = try parsed.resolveWithMemoryProfile(vort.br.PlannedStreamChunksOptions, caller_profile, caller_memory_profile);
    if (streaming) _ = try vort.br.encodedPlannedStreamChunksBoundWithOptions(&.{}, stream) else _ = try vort.br.encodedPlannedStreamBoundWithOptions(0, one_shot);
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(input);
    const encoded = if (streaming) try encodeStream(init.gpa, input, stream) else try vort.br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, one_shot);
    defer init.gpa.free(encoded);
    try writeAtomic(init, output_path, encoded);
    try stdout.print("br_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ encoded.len, input.len, output_path });
    if (parsed.profile) {
        try controls.printProfile(stdout, profile);
        try controls.printFormatProfile(stdout, profile);
        try controls.printParseProfile(stdout, parsed.parse_mode, profile);
        try controls.printLengthProfile(stdout, parsed.copy_lengths, profile);
    }
    if (parsed.memory_profile) try controls.printMemoryProfile(stdout, memory_profile);
}

pub fn encodeHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const first = args.next();
    const starts_with_option = if (first) |value| std.mem.startsWith(u8, value, "--") else false;
    const input = if (starts_with_option) "" else first orelse "";
    const parsed = try controls.parseWithFirst(args, if (starts_with_option) first else null);
    var profile: vort.BrotliHqProfile = .{};
    var memory_profile: vort.BrotliEncodeMemoryProfile = .{};
    const options = try parsed.resolveWithMemoryProfile(vort.br.PlannedEncodeOptions, if (parsed.profile) &profile else null, if (parsed.memory_profile) &memory_profile else null);
    _ = try vort.br.encodedPlannedStreamBoundWithOptions(0, options);
    const encoded = try vort.br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    for (encoded) |byte| try stdout.print("{x:0>2}", .{byte});
    try stdout.writeByte('\n');
    if (parsed.profile) {
        try controls.printProfile(stdout, profile);
        try controls.printFormatProfile(stdout, profile);
        try controls.printParseProfile(stdout, parsed.parse_mode, profile);
        try controls.printLengthProfile(stdout, parsed.copy_lengths, profile);
    }
    if (parsed.memory_profile) try controls.printMemoryProfile(stdout, memory_profile);
}

fn encodeStream(allocator: std.mem.Allocator, input: []const u8, options: vort.br.PlannedStreamChunksOptions) ![]u8 {
    var encoder = vort.br.IncrementalPlannedStreamEncoder.initWithOptions(allocator, .{ .stream = options });
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var output: [4096]u8 = undefined;
    var offset: usize = 0;
    while (offset != input.len) {
        const end = offset + @min(97, input.len - offset);
        const result = try encoder.step(input[offset..end], &output);
        offset += result.progress.input_read;
        try encoded.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.progress.input_read == 0 and result.progress.output_written == 0) return error.InvalidBlockPlan;
    }
    try encoder.finish();
    while (true) {
        const result = try encoder.step(&.{}, &output);
        try encoded.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == .done) break;
        if (result.progress.output_written == 0) return error.InvalidBlockPlan;
    }
    return encoded.toOwnedSlice(allocator);
}

fn writeAtomic(init: std.process.Init, path: []const u8, data: []const u8) !void {
    var atomic = try std.Io.Dir.cwd().createFileAtomic(init.io, path, .{ .replace = true });
    defer atomic.deinit(init.io);
    var buffer: [4096]u8 = undefined;
    var writer = atomic.file.writerStreaming(init.io, &buffer);
    try writer.interface.writeAll(data);
    try writer.interface.flush();
    try atomic.replace(init.io);
}

pub fn encodeStoredFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const options = try (try controls.parseStored(args)).storedOptions();
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(input);
    const encoded = try vort.br.encodeStoredStreamWithOptionsAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    try writeAtomic(init, output_path, encoded);
    try stdout.print("br_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ encoded.len, input.len, output_path });
}

pub fn encodeStoredHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const first = args.next();
    const option_first = if (first) |value| controls.isStoredControlArgument(value) else false;
    const input = if (option_first) "" else first orelse "";
    const options = try (try controls.parseStoredWithFirst(args, if (option_first) first else null)).storedOptions();
    const encoded = try vort.br.encodeStoredStreamWithOptionsAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    for (encoded) |byte| try stdout.print("{x:0>2}", .{byte});
    try stdout.writeByte('\n');
}
