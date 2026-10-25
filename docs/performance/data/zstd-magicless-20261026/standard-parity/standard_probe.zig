//! Same old-public-API source compiled with old and new modules. No format bridge.
const std = @import("std");
const builtin = @import("builtin");
const zstd = @import("zstd");
const Config = struct {
    api: enum { one_shot, reuse, into, incremental } = .one_shot,
    mode: enum { native, level } = .native,
    level: c_int = 3,
    selection: zstd.NativeFrameSelection = .auto,
    checksum: bool = true,
    content_size: bool = true,
    dictionary_path: ?[]const u8 = null,
    full_dictionary: bool = false,
};
pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const wire_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path);
    defer init.gpa.free(input);
    const json = try read(init, config_path);
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{});
    defer parsed.deinit();
    const c = parsed.value;
    const dictionary_bytes = if (c.dictionary_path) |path| try read(init, path) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(dictionary_bytes);
    const dictionary: ?zstd.NativeDictionary = if (c.dictionary_path == null) null else if (c.full_dictionary)
        (try zstd.NativeDictionary.initFromStandardDictionary(dictionary_bytes)).dictionary
    else
        zstd.NativeDictionary.initRawContent(dictionary_bytes);
    var failure: ?[]const u8 = null;
    const wire: ?[]u8 = encode(init.gpa, input, c, dictionary) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (wire) |bytes| init.gpa.free(bytes);
    var decoded = false;
    if (wire) |bytes| {
        const restored = if (dictionary) |dict| try zstd.decodeNativeFrameAllocWithDictionary(init.gpa, bytes, dict) else try zstd.decodeNativeFrameAlloc(init.gpa, bytes);
        defer init.gpa.free(restored);
        if (!std.mem.eql(u8, restored, input)) return error.OldDefaultAllocDecodeMismatch;
        var reusable = zstd.NativeFrameDecoder.init(init.gpa);
        defer reusable.deinit();
        const reused = if (dictionary) |dict| try reusable.decodeAllocWithDictionary(bytes, dict) else try reusable.decodeAlloc(bytes);
        defer init.gpa.free(reused);
        if (!std.mem.eql(u8, reused, input)) return error.OldDefaultReusableDecodeMismatch;
        const output = try init.gpa.alloc(u8, input.len + 16);
        defer init.gpa.free(output);
        @memset(output, 0xa5);
        const written = if (dictionary) |dict| try zstd.decodeNativeFrameIntoWithDictionary(bytes, output[8..][0..input.len], dict) else try zstd.decodeNativeFrameInto(bytes, output[8..][0..input.len]);
        try guards(output, written);
        if (written != input.len or !std.mem.eql(u8, output[8..][0..written], input)) return error.OldDefaultIntoDecodeMismatch;
        decoded = true;
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = wire_path, .data = bytes });
    }
    const input_sha = digest(input);
    const dictionary_sha = digest(dictionary_bytes);
    const wire_sha: ?[64]u8 = if (wire) |bytes| digest(bytes) else null;
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{ .@"error" = failure, .config = c, .input_bytes = input.len, .input_sha256 = input_sha[0..], .dictionary_sha256 = dictionary_sha[0..], .wire_bytes = if (wire) |bytes| bytes.len else 0, .wire_sha256 = if (wire_sha) |*hash| hash[0..] else null, .old_default_alloc_reuse_into_decode_verified = decoded, .caller_guards_verified = true, .target = @tagName(builtin.cpu.arch), .cpu_model = builtin.cpu.model.name, .build_mode = @tagName(builtin.mode), .zig_version = builtin.zig_version_string }, .{});
    defer init.gpa.free(report);
    try std.Io.File.stdout().writeStreamingAll(init.io, report);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
fn encode(a: std.mem.Allocator, input: []const u8, c: Config, dictionary: ?zstd.NativeDictionary) ![]u8 {
    if (c.mode == .level) return zstd.encodeFrameWithLevelAndOptionsAlloc(a, input, c.level, .{ .content_checksum = c.checksum, .include_content_size = c.content_size });
    var options: zstd.NativeFrameOptions = .{ .selection = c.selection, .content_checksum = c.checksum, .include_content_size = c.content_size, .block_size_max = 65536 };
    if (c.api == .one_shot) return if (dictionary) |dict| (try zstd.encodeNativeFrameWithDictionaryAlloc(a, input, options, dict)).frame else (try zstd.encodeNativeFrameWithOptionsAlloc(a, input, options)).frame;
    if (c.api == .into) {
        const bound = if (dictionary) |dict| try zstd.encodedNativeFrameBoundWithDictionary(input.len, options, dict) else try zstd.encodedNativeFrameBoundWithOptions(input.len, options);
        const output = try a.alloc(u8, bound + 16);
        defer a.free(output);
        @memset(output, 0xa5);
        const written = if (dictionary) |dict| (try zstd.encodeNativeFrameIntoSliceWithDictionary(a, input, options, dict, output[8..][0..bound])).written else (try zstd.encodeNativeFrameIntoSlice(a, input, options, output[8..][0..bound])).written;
        try guards(output, written);
        return a.dupe(u8, output[8..][0..written]);
    }
    if (c.api == .reuse) {
        var encoder = zstd.NativeFrameEncoder.init(a);
        defer encoder.deinit();
        const first = if (dictionary) |dict| try encoder.encodeWithDictionaryAlloc(input, options, dict) else try encoder.encodeWithOptionsAlloc(input, options);
        errdefer a.free(first.frame);
        const second = if (dictionary) |dict| try encoder.encodeWithDictionaryAlloc(input, options, dict) else try encoder.encodeWithOptionsAlloc(input, options);
        defer a.free(second.frame);
        if (!std.mem.eql(u8, first.frame, second.frame)) return error.ReusableWireChanged;
        return first.frame;
    }
    if (dictionary) |dict| options.dictionary_id = dict.id;
    var encoder = if (dictionary) |dict| blk: {
        if (c.content_size) break :blk try zstd.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(a, options, input.len, dict);
        break :blk try zstd.NativeIncrementalFrameEncoder.initWithPresetDictionary(a, options, dict);
    } else if (c.content_size) try zstd.NativeIncrementalFrameEncoder.initExactSize(a, options, input.len) else try zstd.NativeIncrementalFrameEncoder.init(a, options);
    defer encoder.deinit();
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(a);
    var offset: usize = 0;
    var finishing = false;
    var step: usize = 0;
    var buffer: [4112]u8 = undefined;
    while (step < input.len * 8 + 8192) : (step += 1) {
        if (offset == input.len and !finishing) {
            encoder.finish();
            finishing = true;
        }
        const offered = input[offset .. offset + @min(input.len - offset, if (step % 3 == 0) @as(usize, 0) else 4096)];
        const capacity: usize = if (step % 5 == 0) 0 else 4096;
        @memset(&buffer, 0xa5);
        const result = try encoder.step(offered, buffer[8..][0..capacity]);
        try guards(&buffer, result.progress.output_written);
        if (result.progress.input_read > offered.len or result.progress.output_written > capacity) return error.InvalidProgress;
        offset += result.progress.input_read;
        try out.appendSlice(a, buffer[8..][0..result.progress.output_written]);
        if (result.status == .done) {
            if (offset != input.len) return error.InvalidProgress;
            return out.toOwnedSlice(a);
        }
    }
    return error.IncrementalDidNotFinish;
}
fn guards(buffer: []const u8, written: usize) !void {
    for (buffer[0..8]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
    for (buffer[8 + written ..]) |byte| if (byte != 0xa5) return error.OutputGuardChanged;
}
fn digest(data: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(2 * 1024 * 1024));
}
