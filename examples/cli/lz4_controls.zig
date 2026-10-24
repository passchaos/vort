const std = @import("std");
const vort = @import("vort");

/// Command-line values remain explicit until the public codec resolves them.
/// Profile collection never changes acceleration or chain depth.
pub const Controls = struct {
    acceleration: ?i32 = null,
    chain_depth: ?u8 = null,
    profile: bool = false,

    pub fn blockOptions(self: Controls, profile: ?*vort.Lz4FastEncodeProfile) !vort.Lz4BlockEncodeOptions {
        const options: vort.Lz4BlockEncodeOptions = .{
            .acceleration = self.acceleration orelse 1,
            .chain_depth = self.chain_depth orelse vort.lz4NativeMaxChainDepth,
            .profile = if (self.profile) profile else null,
        };
        try options.validate();
        return options;
    }

    pub fn nativeOptions(self: Controls, profile: ?*vort.Lz4FastEncodeProfile) !vort.Lz4NativeFrameOptions {
        const block = try self.blockOptions(profile);
        const options: vort.Lz4NativeFrameOptions = .{
            .acceleration = block.acceleration,
            .chain_depth = block.chain_depth,
            .profile = block.profile,
        };
        _ = try vort.lz4EncodedNativeFrameBoundWithOptions(0, options);
        return options;
    }
};

pub fn parse(args: anytype) !Controls {
    var result: Controls = .{};
    while (args.next()) |argument| {
        if (try optionValue("--acceleration", argument, args)) |value| {
            if (result.acceleration != null) return error.DuplicateLz4Option;
            result.acceleration = try std.fmt.parseInt(i32, value, 10);
        } else if (try optionValue("--chain-depth", argument, args)) |value| {
            if (result.chain_depth != null) return error.DuplicateLz4Option;
            result.chain_depth = try std.fmt.parseInt(u8, value, 10);
        } else if (std.mem.eql(u8, argument, "--profile")) {
            if (result.profile) return error.DuplicateLz4Option;
            result.profile = true;
        } else if (std.mem.startsWith(u8, argument, "--")) {
            return error.UnknownLz4Option;
        } else return error.UnexpectedLz4Argument;
    }
    return result;
}

fn optionValue(comptime name: []const u8, argument: []const u8, args: anytype) !?[]const u8 {
    if (std.mem.eql(u8, argument, name)) return args.next() orelse error.MissingLz4OptionValue;
    if (std.mem.startsWith(u8, argument, name ++ "=")) return argument[name.len + 1 ..];
    return null;
}

test {
    _ = @import("lz4_controls_tests.zig");
}

pub fn encodeNativeFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer, streaming: bool) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const control = try parse(args);
    var profile: vort.Lz4FastEncodeProfile = .{};
    const options = try control.nativeOptions(if (control.profile) &profile else null);
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = if (streaming) try encodeStream(init.gpa, input, options) else try vort.lz4EncodeNativeFrameWithOptionsAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    try writeAtomic(init, output_path, encoded);
    try stdout.print("lz4_native_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ encoded.len, input.len, output_path });
    if (control.profile) try printProfile(stdout, profile);
}

pub fn encodeBlockFile(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const input_path = args.next() orelse return error.MissingCorpusPath;
    const output_path = args.next() orelse return error.MissingCorpusPath;
    const control = try parse(args);
    var profile: vort.Lz4FastEncodeProfile = .{};
    const options = try control.blockOptions(if (control.profile) &profile else null);
    const input = try readFile(init, input_path);
    defer init.gpa.free(input);
    const encoded = try vort.lz4EncodeBlockWithOptionsAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    try writeAtomic(init, output_path, encoded);
    try stdout.print("lz4_block_compressed_bytes={d} decoded_bytes={d} path={s}\n", .{ encoded.len, input.len, output_path });
    if (control.profile) try printProfile(stdout, profile);
}

pub fn encodeBlockHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer, with_prefix: bool) !void {
    const text = args.next() orelse return error.MissingHexInput;
    const prefix_text = if (with_prefix) args.next() orelse return error.MissingHexInput else "";
    const control = try parse(args);
    var profile: vort.Lz4FastEncodeProfile = .{};
    const options = try control.blockOptions(if (control.profile) &profile else null);
    const input = try decodeHex(init.gpa, text);
    defer init.gpa.free(input);
    const prefix = try decodeHex(init.gpa, prefix_text);
    defer init.gpa.free(prefix);
    const encoded = if (with_prefix) try vort.lz4EncodeBlockWithPrefixAndOptionsAlloc(init.gpa, input, prefix, options) else try vort.lz4EncodeBlockWithOptionsAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    for (encoded) |byte| try stdout.print("{x:0>2}", .{byte});
    try stdout.writeByte('\n');
    if (control.profile) try printProfile(stdout, profile);
}

pub fn printProfile(stdout: *std.Io.Writer, profile: vort.Lz4FastEncodeProfile) !void {
    try stdout.print("lz4_fast_profile acceleration={d} chain_depth={d} positions_inspected={d} positions_skipped={d} chain_candidates={d} history_positions_seeded={d} match_positions_seeded={d} blocks_attempted={d} max_skip_step={d}\n", .{
        profile.resolved_acceleration, profile.resolved_chain_depth,     profile.positions_inspected,    profile.positions_skipped,
        profile.chain_candidates,      profile.history_positions_seeded, profile.match_positions_seeded, profile.blocks_attempted,
        profile.max_skip_step,
    });
}

fn encodeStream(allocator: std.mem.Allocator, input: []const u8, options: vort.Lz4NativeFrameOptions) ![]u8 {
    var encoder = try vort.Lz4NativeIncrementalFrameEncoder.initExactSize(allocator, options, input.len);
    defer encoder.deinit();
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(allocator);
    var output: [4096]u8 = undefined;
    var offset: usize = 0;
    while (offset != input.len) {
        const result = try encoder.step(input[offset..][0..@min(97, input.len - offset)], &output);
        offset += result.progress.input_read;
        try encoded.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.progress.input_read == 0 and result.progress.output_written == 0) return error.InvalidBlockPlan;
    }
    encoder.finish();
    while (true) {
        const result = try encoder.step(&.{}, &output);
        try encoded.appendSlice(allocator, output[0..result.progress.output_written]);
        if (result.status == .done) break;
        if (result.progress.output_written == 0) return error.InvalidBlockPlan;
    }
    return encoded.toOwnedSlice(allocator);
}

fn readFile(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
}
fn decodeHex(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    if (text.len % 2 != 0) return error.InvalidHexInput;
    const bytes = try allocator.alloc(u8, text.len / 2);
    errdefer allocator.free(bytes);
    _ = try std.fmt.hexToBytes(bytes, text);
    return bytes;
}
fn writeAtomic(init: std.process.Init, path: []const u8, bytes: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFileAtomic(init.io, path, .{ .replace = true });
    defer file.deinit(init.io);
    var buffer: [4096]u8 = undefined;
    var writer = file.file.writerStreaming(init.io, &buffer);
    try writer.interface.writeAll(bytes);
    try writer.interface.flush();
    try file.replace(init.io);
}

/// Thin validation adapter for raw block decode, including the existing empty
/// slice API convention and canonical one-byte LZ4 empty blocks.
pub fn decodeBlockHex(init: std.process.Init, args: *std.process.Args.Iterator, stdout: *std.Io.Writer) !void {
    const text = args.next() orelse return error.MissingHexInput;
    if (args.next() != null) return error.UnexpectedLz4Argument;
    const block = try decodeHex(init.gpa, text);
    defer init.gpa.free(block);
    const decoded = try vort.lz4DecodeBlockAlloc(init.gpa, block, null);
    defer init.gpa.free(decoded);
    for (decoded) |byte| try stdout.print("{x:0>2}", .{byte});
    try stdout.writeByte('\n');
}
