const std = @import("std");
const vort = @import("vort");
const lz4 = vort.lz4;
const Profile = if (@hasDecl(lz4, "FastEncodeProfile")) lz4.FastEncodeProfile else struct {};
const BlockOptions = if (@hasDecl(lz4, "BlockEncodeOptions")) lz4.BlockEncodeOptions else struct { chain_depth: u8 = 16 };
const Resolved = struct {
    format: []const u8,
    api: []const u8,
    acceleration: u32,
    chain_depth: u8,
};

const Config = struct {
    operation: []const u8 = "encode",
    format: []const u8 = "frame",
    api: []const u8 = "one_shot",
    acceleration: ?i32 = null,
    chain_depth: ?u8 = null,
    profile_enabled: bool = true,
    dictionary_path: ?[]const u8 = null,
    dictionary_id: u32 = 7,
    block_mode: []const u8 = "independent",
    block_size_id: u8 = 4,
    content_size: bool = true,
    content_checksum: bool = true,
    block_checksum: bool = false,
    expected_size: ?usize = null,
    input_chunk: usize = 4096,
    output_chunk: usize = 4096,
    max_output_size: usize = 1024 * 1024,
    output_capacity: ?usize = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path, 128 * 1024);
    defer init.gpa.free(input);
    const json = try read(init, config_path, 65536);
    defer init.gpa.free(json);
    const parsed = std.json.parseFromSlice(Config, init.gpa, json, .{}) catch |err| {
        try reportJson(init, .{ .@"error" = @errorName(err), .input_bytes = input.len, .output_bytes = 0, .resolved = @as(?Resolved, null), .profile = Profile{}, .output_preserved_on_error = true, .build_mode = @tagName(@import("builtin").mode) });
        return;
    };
    defer parsed.deinit();
    var failure: ?[]const u8 = null;
    var profile: Profile = .{};
    var resolved: ?Resolved = null;
    const bytes: ?[]u8 = operation(init, input, parsed.value, &profile, &resolved) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (bytes) |output| init.gpa.free(output);
    if (bytes) |output| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = output });
    try reportJson(init, .{
        .@"error" = failure,
        .input_bytes = input.len,
        .output_bytes = if (bytes) |output| output.len else 0,
        .resolved = resolved,
        .profile = profile,
        .output_preserved_on_error = failure != null,
        .build_mode = @tagName(@import("builtin").mode),
    });
}
fn reportJson(init: std.process.Init, value: anytype) !void {
    const report = try std.json.Stringify.valueAlloc(init.gpa, value, .{});
    defer init.gpa.free(report);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(report);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn blockOptions(config: Config, profile: ?*Profile, resolved: *?Resolved) !BlockOptions {
    var options: BlockOptions = .{};
    if (config.chain_depth) |depth| options.chain_depth = depth;
    if (@hasField(BlockOptions, "acceleration")) {
        options.acceleration = config.acceleration orelse 1;
        options.profile = profile;
        const actual = try options.resolve();
        resolved.* = .{ .format = config.format, .api = config.api, .acceleration = actual.acceleration, .chain_depth = actual.chain_depth };
    } else {
        if (config.acceleration != null) return error.UnsupportedAccelerationControls;
        resolved.* = .{ .format = config.format, .api = config.api, .acceleration = 1, .chain_depth = options.chain_depth };
    }
    return options;
}
fn frameOptions(config: Config, profile: ?*Profile) !lz4.NativeFrameOptions {
    var options: lz4.NativeFrameOptions = .{
        .include_content_size = config.content_size,
        .content_checksum = config.content_checksum,
        .block_checksum = config.block_checksum,
        .block_mode = std.meta.stringToEnum(lz4.BlockMode, config.block_mode) orelse return error.InvalidBlockPlan,
        .block_size_id = switch (config.block_size_id) {
            4 => .max64kb,
            5 => .max256kb,
            6 => .max1mb,
            7 => .max4mb,
            else => return error.InvalidBlockPlan,
        },
    };
    if (config.chain_depth) |depth| options.chain_depth = depth;
    if (@hasField(lz4.NativeFrameOptions, "acceleration")) {
        options.acceleration = config.acceleration orelse 1;
        options.profile = profile;
    } else if (config.acceleration != null) return error.UnsupportedAccelerationControls;
    return options;
}
fn operation(init: std.process.Init, input: []const u8, config: Config, profile: *Profile, resolved: *?Resolved) ![]u8 {
    const prefix = if (config.dictionary_path) |path| try read(init, path, 128 * 1024) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(prefix);
    const dictionary: ?lz4.NativeDictionary = if (config.dictionary_path != null) lz4.NativeDictionary.init(config.dictionary_id, prefix) else null;
    if (std.mem.eql(u8, config.operation, "decode")) {
        if (std.mem.eql(u8, config.format, "raw")) {
            if (dictionary != null) return lz4.decodeBlockWithPrefixAlloc(init.gpa, input, config.expected_size, prefix);
            return lz4.decodeBlockAlloc(init.gpa, input, config.expected_size);
        }
        if (std.mem.eql(u8, config.format, "frame")) {
            if (dictionary) |dict| return lz4.decodeFrameAllocLimitedWithDictionary(init.gpa, input, config.max_output_size, dict);
            return lz4.decodeFrameAllocLimited(init.gpa, input, config.max_output_size);
        }
        return error.UnsupportedFormat;
    }
    if (!std.mem.eql(u8, config.operation, "encode")) return error.UnsupportedOperation;
    const selected_profile = if (config.profile_enabled) profile else null;
    const settings = try blockOptions(config, selected_profile, resolved);
    if (std.mem.eql(u8, config.format, "raw")) {
        if (std.mem.eql(u8, config.api, "reusable")) {
            var encoder = try lz4.BlockEncoder.init(init.gpa);
            defer encoder.deinit();
            if (@hasDecl(lz4.BlockEncoder, "encodeWithOptionsAlloc")) {
                if (dictionary != null) return encoder.encodeWithPrefixAndOptionsAlloc(input, prefix, settings);
                return encoder.encodeWithOptionsAlloc(input, settings);
            }
            if (dictionary != null) {
                if (config.chain_depth) |depth| return encoder.encodeWithPrefixAndChainDepthAlloc(input, prefix, depth);
                return encoder.encodeWithPrefixAlloc(input, prefix);
            }
            if (config.chain_depth) |depth| return encoder.encodeWithChainDepthAlloc(input, depth);
            return encoder.encodeAlloc(input);
        }
        if (std.mem.eql(u8, config.api, "into")) {
            if (@hasDecl(lz4, "encodeBlockIntoSliceWithOptions")) {
                const output = try init.gpa.alloc(u8, config.output_capacity orelse try lz4.encodedBlockBound(input.len));
                defer init.gpa.free(output);
                const written = if (dictionary != null) try lz4.encodeBlockWithPrefixIntoSliceAndOptions(init.gpa, input, prefix, output, settings) else try lz4.encodeBlockIntoSliceWithOptions(init.gpa, input, output, settings);
                return init.gpa.dupe(u8, output[0..written]);
            }
            return error.UnsupportedOperation;
        }
        if (!std.mem.eql(u8, config.api, "one_shot")) return error.UnsupportedOperation;
        if (@hasDecl(lz4, "encodeBlockWithOptionsAlloc")) {
            if (dictionary != null) return lz4.encodeBlockWithPrefixAndOptionsAlloc(init.gpa, input, prefix, settings);
            return lz4.encodeBlockWithOptionsAlloc(init.gpa, input, settings);
        }
        if (dictionary != null) {
            if (config.chain_depth) |depth| return lz4.encodeBlockWithPrefixAndChainDepthAlloc(init.gpa, input, prefix, depth);
            return lz4.encodeBlockWithPrefixAlloc(init.gpa, input, prefix);
        }
        if (config.chain_depth) |depth| return lz4.encodeBlockWithChainDepthAlloc(init.gpa, input, depth);
        return lz4.encodeBlockAlloc(init.gpa, input);
    }
    if (!std.mem.eql(u8, config.format, "frame")) return error.UnsupportedFormat;
    var options = try frameOptions(config, selected_profile);
    if (std.mem.eql(u8, config.api, "into")) {
        const output = try init.gpa.alloc(u8, config.output_capacity orelse try lz4.encodedNativeFrameBoundWithOptions(input.len, options));
        defer init.gpa.free(output);
        const written = if (dictionary) |dict| try lz4.encodeNativeFrameIntoSliceWithDictionary(init.gpa, input, options, dict, output) else try lz4.encodeNativeFrameIntoSlice(init.gpa, input, options, output);
        return init.gpa.dupe(u8, output[0..written]);
    }
    if (std.mem.eql(u8, config.api, "reusable")) {
        var encoder = try lz4.NativeFrameEncoder.init(init.gpa);
        defer encoder.deinit();
        if (dictionary) |dict| return encoder.encodeWithDictionaryAlloc(input, options, dict);
        return encoder.encodeWithOptionsAlloc(input, options);
    }
    if (std.mem.eql(u8, config.api, "incremental") or std.mem.eql(u8, config.api, "chunks")) {
        if (dictionary) |dict| options.dictionary_id = dict.id;
        var encoder = if (dictionary) |dict| blk: {
            if (options.include_content_size) break :blk try lz4.NativeIncrementalFrameEncoder.initExactSizeWithDictionary(init.gpa, options, input.len, dict.id, dict.content);
            break :blk try lz4.NativeIncrementalFrameEncoder.initWithDictionary(init.gpa, options, dict.id, dict.content);
        } else if (options.include_content_size) try lz4.NativeIncrementalFrameEncoder.initExactSize(init.gpa, options, input.len) else try lz4.NativeIncrementalFrameEncoder.init(init.gpa, options);
        defer encoder.deinit();
        return pump(init, input, config, &encoder);
    }
    if (!std.mem.eql(u8, config.api, "one_shot")) return error.UnsupportedOperation;
    if (dictionary) |dict| return lz4.encodeNativeFrameWithDictionaryAlloc(init.gpa, input, options, dict);
    return lz4.encodeNativeFrameWithOptionsAlloc(init.gpa, input, options);
}
fn pump(init: std.process.Init, input: []const u8, config: Config, encoder: anytype) ![]u8 {
    if (config.input_chunk == 0 or config.output_chunk == 0 or config.output_chunk > 1024 * 1024) return error.InvalidChunkSize;
    const buffer = try init.gpa.alloc(u8, config.output_chunk);
    defer init.gpa.free(buffer);
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(init.gpa);
    var offset: usize = 0;
    var finished = false;
    var steps: usize = 0;
    while (steps < input.len * 4 + config.max_output_size + 1024) : (steps += 1) {
        if (offset == input.len and !finished) {
            encoder.finish();
            finished = true;
        }
        const end = offset + @min(input.len - offset, config.input_chunk);
        const progress = try encoder.step(input[offset..end], buffer);
        offset += progress.progress.input_read;
        if (progress.progress.output_written > config.max_output_size - output.items.len) return error.OutputLimitExceeded;
        try output.appendSlice(init.gpa, buffer[0..progress.progress.output_written]);
        if (progress.status == .done) {
            if (offset != input.len) return error.InputAccountingMismatch;
            return output.toOwnedSlice(init.gpa);
        }
    }
    return error.IncrementalDidNotFinish;
}
fn read(init: std.process.Init, path: []const u8, limit: usize) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(limit));
}
