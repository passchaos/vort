const std = @import("std");
const vort = @import("vort");

pub const Controls = struct {
    selection: vort.ZstdNativeFrameSelection = .auto,
    checksum: bool = true,
    content_size: bool = true,
    level: ?c_int = null,
    strategy: ?vort.zstd.Strategy = null,
    fast_acceleration: ?u32 = null,

    pub fn resolved(self: Controls) !vort.ZstdNativeFrameOptions {
        if (self.level == null and self.strategy == null and self.fast_acceleration == null) {
            return .{ .selection = self.selection, .content_checksum = self.checksum, .include_content_size = self.content_size };
        }
        var options = try vort.zstd.resolveFrameOptionsForLevel(self.level orelse vort.zstdDefaultCompressionLevel, .{
            .strategy = self.strategy orelse .auto,
            .fast_acceleration = self.fast_acceleration,
            .content_checksum = self.checksum,
            .include_content_size = self.content_size,
        });
        if (self.selection != .auto) {
            if (options.selection != .auto and options.selection != self.selection) return error.InvalidBlockPlan;
            options.selection = self.selection;
        }
        try options.validate();
        return options;
    }
};

pub fn parse(args: *std.process.Args.Iterator, first: ?[]const u8) !Controls {
    var result = Controls{};
    var positional: usize = 0;
    var pending = first;
    while (true) {
        const arg = pending orelse args.next() orelse break;
        pending = null;
        if (try optionValue("--level", arg, args)) |value| {
            if (result.level != null) return error.DuplicateZstdOption;
            result.level = try std.fmt.parseInt(c_int, value, 10);
        } else if (try optionValue("--strategy", arg, args)) |value| {
            if (result.strategy != null) return error.DuplicateZstdOption;
            result.strategy = try parseStrategy(value);
        } else if (try optionValue("--fast-acceleration", arg, args)) |value| {
            if (result.fast_acceleration != null) return error.DuplicateZstdOption;
            result.fast_acceleration = try std.fmt.parseInt(u32, value, 10);
        } else if (std.mem.startsWith(u8, arg, "--")) {
            return error.UnknownZstdOption;
        } else {
            switch (positional) {
                0 => result.selection = try parseSelection(arg),
                1 => result.checksum = try parseBool(arg),
                2 => result.content_size = try parseBool(arg),
                else => return error.UnexpectedZstdArgument,
            }
            positional += 1;
        }
    }
    return result;
}

pub fn parseStrategy(value: []const u8) !vort.zstd.Strategy {
    if (std.mem.eql(u8, value, "double-fast")) return .double_fast;
    return std.meta.stringToEnum(vort.zstd.Strategy, value) orelse error.InvalidZstdStrategy;
}

pub fn isControlArgument(arg: []const u8) bool {
    inline for (.{ "--level", "--strategy", "--fast-acceleration" }) |name| {
        if (std.mem.eql(u8, arg, name) or std.mem.startsWith(u8, arg, name ++ "=")) return true;
    }
    return false;
}

fn optionValue(comptime name: []const u8, arg: []const u8, args: *std.process.Args.Iterator) !?[]const u8 {
    if (std.mem.eql(u8, arg, name)) return args.next() orelse error.MissingZstdOptionValue;
    if (std.mem.startsWith(u8, arg, name ++ "=")) return arg[name.len + 1 ..];
    return null;
}

fn parseSelection(value: []const u8) !vort.ZstdNativeFrameSelection {
    if (std.mem.eql(u8, value, "auto")) return .auto;
    if (std.mem.eql(u8, value, "raw_or_rle") or std.mem.eql(u8, value, "raw-rle")) return .raw_or_rle;
    if (std.mem.eql(u8, value, "literal_only") or std.mem.eql(u8, value, "literal-only")) return .literal_only;
    if (std.mem.eql(u8, value, "fast_compressed") or std.mem.eql(u8, value, "fast-compressed")) return .fast_compressed;
    return error.InvalidZstdNativeSelection;
}

fn parseBool(value: []const u8) !bool {
    if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1") or std.mem.eql(u8, value, "yes")) return true;
    if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0") or std.mem.eql(u8, value, "no")) return false;
    return error.InvalidBoolean;
}

pub fn encodeTextHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const first = args.next();
    const option_first = if (first) |arg| isControlArgument(arg) else false;
    const payload = if (option_first) "" else first orelse "";
    const options = try (try parse(args, if (option_first) first else null)).resolved();
    const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, options);
    defer init.gpa.free(result.frame);
    try printHex(stdout, result.frame);
}

pub fn encodeBytesHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const hex = args.next() orelse return error.MissingHexInput;
    if (hex.len & 1 != 0) return error.InvalidHexInput;
    const payload = try init.gpa.alloc(u8, hex.len / 2);
    defer init.gpa.free(payload);
    for (payload, 0..) |*byte, index| byte.* = try std.fmt.parseInt(u8, hex[index * 2 ..][0..2], 16);
    const options = try (try parse(args, null)).resolved();
    const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, options);
    defer init.gpa.free(result.frame);
    try printHex(stdout, result.frame);
}

pub fn encodeFileHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const path = args.next() orelse return error.MissingCorpusPath;
    const options = try (try parse(args, null)).resolved();
    const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(payload);
    const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, options);
    defer init.gpa.free(result.frame);
    try printHex(stdout, result.frame);
}

pub fn encodeFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    if (isControlArgument(output_path)) return error.MissingCorpusPath;
    const options = try (try parse(args, null)).resolved();
    const payload = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(payload);
    const result = try vort.zstdEncodeNativeFrameWithOptionsAlloc(init.gpa, payload, options);
    defer init.gpa.free(result.frame);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = result.frame });
    try stdout.print("zstd_native_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ result.frame.len, payload.len, output_path });
}

fn printHex(stdout: *std.Io.Writer, bytes: []const u8) !void {
    for (bytes) |byte| try stdout.print("{x:0>2}", .{byte});
    try stdout.writeByte('\n');
}
