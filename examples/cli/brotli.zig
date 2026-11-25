const std = @import("std");
const vort = @import("vort");
const controls = @import("brotli_controls.zig");
const stream_files = @import("stream_files.zig");
const decode_stdio = @import("decode_stdio.zig");
const raw_dictionary = @import("brotli_dictionary.zig");

pub fn encodeFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer, streaming: bool) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const parsed = try controls.parse(args);
    var profile: vort.BrotliHqProfile = .{};
    var memory_profile: vort.BrotliEncodeMemoryProfile = .{};
    const caller_profile = if (parsed.profile) &profile else null;
    const caller_memory_profile = if (parsed.memory_profile) &memory_profile else null;
    // Public bounds validate scalar settings before reading or touching files.
    var one_shot = try parsed.resolveWithMemoryProfile(vort.br.PlannedEncodeOptions, caller_profile, caller_memory_profile);
    var stream = try parsed.resolveWithMemoryProfile(vort.br.PlannedStreamChunksOptions, caller_profile, caller_memory_profile);
    if (streaming) {
        _ = try vort.br.encodedPlannedStreamChunksBoundWithOptions(&.{}, stream);
    } else {
        if (parsed.hasStreamLimits()) return error.UnsupportedBrotliStreamLimit;
        _ = try vort.br.encodedPlannedStreamBoundWithOptions(0, one_shot);
    }
    const dictionary = try parsed.dictionary.load(init.io, init.gpa);
    defer dictionary.deinit(init.gpa);
    if (streaming) {
        stream.shared_dictionary = dictionary.shared();
        return encodeStreamingFile(init, input_path, output_path, parsed, stream, &profile, &memory_profile, stdout);
    }
    one_shot.shared_dictionary = dictionary.shared();
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(input);
    const encoded = try vort.br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, one_shot);
    defer init.gpa.free(encoded);
    try writeAtomic(init, output_path, encoded);
    try stdout.print("br_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ encoded.len, input.len, output_path });
    try printEncodeProfiles(stdout, parsed, profile, memory_profile);
}

pub fn encodeHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const first = args.next();
    const starts_with_option = if (first) |value| std.mem.startsWith(u8, value, "--") else false;
    const input = if (starts_with_option) "" else first orelse "";
    const parsed = try controls.parseWithFirst(args, if (starts_with_option) first else null);
    if (parsed.hasStreamLimits()) return error.UnsupportedBrotliStreamLimit;
    var profile: vort.BrotliHqProfile = .{};
    var memory_profile: vort.BrotliEncodeMemoryProfile = .{};
    var options = try parsed.resolveWithMemoryProfile(vort.br.PlannedEncodeOptions, if (parsed.profile) &profile else null, if (parsed.memory_profile) &memory_profile else null);
    _ = try vort.br.encodedPlannedStreamBoundWithOptions(0, options);
    const dictionary = try parsed.dictionary.load(init.io, init.gpa);
    defer dictionary.deinit(init.gpa);
    options.shared_dictionary = dictionary.shared();
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

pub fn fileSizeCounter(size: u64) !vort.StreamCount {
    return stream_files.fileSizeCounter(size);
}

fn encodeStreamingFile(init: std.process.Init, input_path: []const u8, output_path: []const u8, parsed: controls.Controls, options: vort.br.PlannedStreamChunksOptions, profile: *vort.BrotliHqProfile, memory_profile: *vort.BrotliEncodeMemoryProfile, stdout: *std.Io.Writer) !void {
    const from_stdin = stream_files.isStdio(input_path);
    const use_stdio = from_stdin or stream_files.isStdio(output_path);
    const input_file = if (from_stdin) std.Io.File.stdin() else try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    var input_open = !from_stdin;
    defer if (input_open) input_file.close(init.io);
    if (!from_stdin) {
        const input_size = try fileSizeCounter((try input_file.stat(init.io)).size);
        if (parsed.max_input_len) |limit| if (input_size > limit) return error.OutputLimitExceeded;
    }
    {
        var encoder = vort.br.IncrementalPlannedStreamEncoder.initWithOptions(init.gpa, .{
            .stream = options,
            .max_input_len = parsed.max_input_len orelse std.math.maxInt(vort.StreamCount),
        });
        defer encoder.deinit();
        if (use_stdio) {
            _ = try stream_files.pumpStdio(init.io, input_file, output_path, &encoder, .{
                .max_input = parsed.max_input_len,
                .max_output = parsed.max_output_len,
            });
        } else {
            var atomic = try std.Io.Dir.cwd().createFileAtomic(init.io, output_path, .{ .replace = true });
            defer atomic.deinit(init.io);
            var write_buffer: [32 * 1024]u8 = undefined;
            var writer = atomic.file.writerStreaming(init.io, &write_buffer);
            const totals = try stream_files.pump(init, input_file, &writer.interface, &encoder, parsed.max_input_len, parsed.max_output_len);
            input_file.close(init.io);
            input_open = false;
            try writer.interface.flush();
            try atomic.replace(init.io);
            try stdout.print("br_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ totals.output_written, totals.input_read, output_path });
        }
    }
    if (!use_stdio) return printEncodeProfiles(stdout, parsed, profile.*, memory_profile.*);
    if (parsed.profile or parsed.memory_profile) {
        var buffer: [2048]u8 = undefined;
        var diagnostic = std.Io.File.stderr().writerStreaming(init.io, &buffer);
        try printEncodeProfiles(&diagnostic.interface, parsed, profile.*, memory_profile.*);
        try diagnostic.interface.flush();
    }
}

fn printEncodeProfiles(writer: *std.Io.Writer, parsed: controls.Controls, profile: vort.BrotliHqProfile, memory_profile: vort.BrotliEncodeMemoryProfile) !void {
    if (parsed.profile) {
        try controls.printProfile(writer, profile);
        try controls.printFormatProfile(writer, profile);
        try controls.printParseProfile(writer, parsed.parse_mode, profile);
        try controls.printLengthProfile(writer, parsed.copy_lengths, profile);
    }
    if (parsed.memory_profile) try controls.printMemoryProfile(writer, memory_profile);
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
    const parsed = try controls.parseStored(args);
    var memory_profile: vort.BrotliEncodeMemoryProfile = .{};
    const options = try parsed.storedOptionsWithMemoryProfile(if (parsed.memory_profile) &memory_profile else null);
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(input);
    {
        const encoded = try vort.br.encodeStoredStreamWithOptionsAlloc(init.gpa, input, options);
        defer init.gpa.free(encoded);
        try writeAtomic(init, output_path, encoded);
        try stdout.print("br_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ encoded.len, input.len, output_path });
    }
    if (parsed.memory_profile) try controls.printMemoryProfile(stdout, memory_profile);
}

pub fn encodeStoredHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const first = args.next();
    const option_first = if (first) |value| controls.isStoredControlArgument(value) else false;
    const input = if (option_first) "" else first orelse "";
    const parsed = try controls.parseStoredWithFirst(args, if (option_first) first else null);
    var memory_profile: vort.BrotliEncodeMemoryProfile = .{};
    const options = try parsed.storedOptionsWithMemoryProfile(if (parsed.memory_profile) &memory_profile else null);
    {
        const encoded = try vort.br.encodeStoredStreamWithOptionsAlloc(init.gpa, input, options);
        defer init.gpa.free(encoded);
        for (encoded) |byte| try stdout.print("{x:0>2}", .{byte});
        try stdout.writeByte('\n');
    }
    if (parsed.memory_profile) try controls.printMemoryProfile(stdout, memory_profile);
}

pub const DecodeArguments = struct {
    max_output_len: ?vort.StreamCount = null,
    options: vort.BrotliDecodeOptions = .{},
    dictionary: raw_dictionary.Arguments = .{},
};

pub fn parseDecodeArguments(args: *std.process.Args.Iterator) !DecodeArguments {
    var parsed: DecodeArguments = .{};
    while (args.next()) |arg| {
        if (try parsed.dictionary.consume(arg, args)) continue;
        if (std.mem.eql(u8, arg, "--large-window")) {
            if (parsed.options.allow_large_window) return error.DuplicateBrotliOption;
            parsed.options.allow_large_window = true;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownBrotliOption;
        } else {
            if (parsed.max_output_len != null) return error.DuplicateBrotliOption;
            parsed.max_output_len = try controls.parseLogicalLimit(arg);
        }
    }
    return parsed;
}

pub fn decodeFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    var arguments = try parseDecodeArguments(args);
    const dictionary = try arguments.dictionary.load(init.io, init.gpa);
    defer dictionary.deinit(init.gpa);
    arguments.options.shared_dictionary = dictionary.shared();
    if (decode_stdio.isStdio(input_path) or decode_stdio.isStdio(output_path)) {
        const Decoder = vort.BrotliIncrementalStreamDecoder;
        var options: Decoder.Options = .{
            .decode = arguments.options,
            .max_output_len = arguments.max_output_len orelse std.math.maxInt(vort.StreamCount),
        };
        if (options.decode.allow_large_window) options.max_history_len = (@as(usize, 1) << 30) - 16;
        var decoder = Decoder.initWithOptions(init.gpa, options);
        defer decoder.deinit();
        return decode_stdio.decode(init.io, input_path, output_path, &decoder);
    }

    const dir = std.Io.Dir.cwd();
    const compressed = try dir.readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(compressed);
    const decoded = try decodeAlloc(init.gpa, compressed, arguments);
    defer init.gpa.free(decoded);
    try dir.writeFile(init.io, .{ .sub_path = output_path, .data = decoded });
    try stdout.print("br_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, output_path });
}

pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8, arguments: DecodeArguments) ![]u8 {
    if (try controls.localLimit(arguments.max_output_len)) |limit|
        return vort.brDecodeStreamAllocLimitedWithOptions(allocator, input, limit, arguments.options);
    return vort.brDecodeStreamAllocWithOptions(allocator, input, arguments.options);
}
