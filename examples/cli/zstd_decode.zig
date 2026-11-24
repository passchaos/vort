const std = @import("std");
const vort = @import("vort");
const decoded_output = @import("decode_output.zig");
const controls = @import("zstd_controls.zig");
const stdio = @import("zstd_stdio.zig");

const Mode = enum { hex, file, file_to, size_hex, size_file };
const modes = std.StaticStringMap(Mode).initComptime(.{
    .{ "decode-zstd-native-hex", .hex },
    .{ "decode-zstd-native-file", .file },
    .{ "decode-zstd-native-file-to", .file_to },
    .{ "size-zstd-native-hex", .size_hex },
    .{ "size-zstd-native-file", .size_file },
});

const Options = struct {
    max_output: ?vort.StreamCount = null,
    max_window_size: ?vort.StreamCount = null,

    fn parse(args: *std.process.Args.Iterator) !Options {
        var options: Options = .{};
        const name = "--max-window-size";
        while (args.next()) |arg| {
            const window = if (std.mem.eql(u8, arg, name))
                args.next() orelse return error.InvalidZstdDecodeOption
            else if (std.mem.startsWith(u8, arg, name ++ "="))
                arg[name.len + 1 ..]
            else
                null;
            if (window) |text| {
                if (options.max_window_size != null or text.len == 0) return error.InvalidZstdDecodeOption;
                for (text) |char| if (!std.ascii.isDigit(char)) return error.InvalidZstdDecodeOption;
                options.max_window_size = try std.fmt.parseInt(vort.StreamCount, text, 10);
            } else {
                if (std.mem.startsWith(u8, arg, "--") or options.max_output != null)
                    return error.InvalidZstdDecodeOption;
                options.max_output = try controls.parseLogicalLimit(arg);
            }
        }
        return options;
    }

    fn frameOptions(self: Options, window: vort.StreamCount) vort.ZstdFrameDecodeOptions {
        return .{
            .max_window_size = window,
            .max_output_len = self.max_output orelse std.math.maxInt(vort.StreamCount),
        };
    }

    fn decodedSize(self: Options, compressed: []const u8) !vort.StreamCount {
        if (self.max_window_size) |window|
            return vort.zstdDecodedFrameSizeWithOptions(compressed, self.frameOptions(window));
        if (self.max_output) |limit|
            return vort.zstdDecodedNativeFrameSizeLimited(compressed, limit);
        return vort.zstdDecodedNativeFrameSize(compressed);
    }

    fn decodeAlloc(self: Options, allocator: std.mem.Allocator, compressed: []const u8, legacy_limit: ?usize) ![]u8 {
        if (self.max_window_size) |window|
            return vort.zstdDecodeFrameAllocWithOptions(allocator, compressed, self.frameOptions(window));
        if (legacy_limit) |limit|
            return vort.zstdDecodeNativeFrameAllocLimited(allocator, compressed, limit);
        return vort.zstdDecodeNativeFrameAlloc(allocator, compressed);
    }

    fn reportLimit(self: Options, io: std.Io, err: anyerror) void {
        if (err != error.OutputLimitExceeded) return;
        const window = self.max_window_size orelse return;
        // The library uses the same error for both limits. Report configured
        // limits rather than attributing the refusal to the wrong one.
        var buffer: [160]u8 = undefined;
        var writer = std.Io.File.stderr().writerStreaming(io, &buffer);
        writer.interface.print("zstd_decode_limit_exceeded max_window_size={d}", .{window}) catch return;
        if (self.max_output) |limit| writer.interface.print(" max_output={d}", .{limit}) catch return;
        writer.interface.writeAll("\n") catch return;
        writer.interface.flush() catch {};
    }
};

pub fn dispatch(command: []const u8, init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !bool {
    const mode = modes.get(command) orelse return false;
    const is_hex = mode == .hex or mode == .size_hex;
    const is_size = mode == .size_hex or mode == .size_file;
    const input = args.next() orelse return if (is_hex) error.MissingHexInput else error.MissingCorpusPath;
    const output_path = if (mode == .file_to) args.next() orelse return error.MissingCorpusPath else null;
    const options = try Options.parse(args);
    if (output_path) |path| {
        if (stdio.isStdio(input) or stdio.isStdio(path)) {
            const window = options.max_window_size orelse stdio.default_window_size;
            stdio.decode(init, input, path, .{
                .max_output_len = options.max_output orelse std.math.maxInt(vort.StreamCount),
                .max_window_size = window,
            }) catch |err| {
                const pipe_options: Options = .{ .max_window_size = window, .max_output = options.max_output };
                pipe_options.reportLimit(init.io, err);
                return err;
            };
            return true;
        }
    }
    const legacy_limit = if (!is_size and options.max_window_size == null) try controls.localLimit(options.max_output) else null;
    const compressed = if (is_hex)
        try decoded_output.hexToOwnedBytes(init.gpa, input)
    else
        try std.Io.Dir.cwd().readFileAlloc(init.io, input, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(compressed);

    if (is_size) {
        const size = options.decodedSize(compressed) catch |err| {
            options.reportLimit(init.io, err);
            return err;
        };
        try stdout.print("zstd_native_compressed_bytes={d} decoded_bytes={d}\n", .{ compressed.len, size });
    } else {
        const decoded = options.decodeAlloc(init.gpa, compressed, legacy_limit) catch |err| {
            options.reportLimit(init.io, err);
            return err;
        };
        defer init.gpa.free(decoded);
        if (output_path) |path| {
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = decoded });
            try stdout.print("zstd_native_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ compressed.len, decoded.len, path });
        } else try decoded_output.printDecoded(stdout, "zstd_native", compressed.len, decoded);
    }
    return true;
}
