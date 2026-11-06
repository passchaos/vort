//! File-driven Dictionary_ID public API interoperability probe.
const std = @import("std");
const builtin = @import("builtin");
const h = @import("probe_helpers/common.zig");
const encode = @import("probe_helpers/encode.zig");
const decode = @import("probe_helpers/decode.zig");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try h.read(init, input_path);
    defer init.gpa.free(input);
    const json = try h.read(init, config_path);
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(h.Config, init.gpa, json, .{});
    defer parsed.deinit();
    const c = parsed.value;
    const dictionary_bytes = if (c.dictionary_path) |path| try h.read(init, path) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(dictionary_bytes);
    const input_hash = h.digest(input);
    const dictionary_hash = h.digest(dictionary_bytes);
    const dictionary: ?h.Z.NativeDictionary = if (c.dictionary_path != null) (try h.Z.NativeDictionary.initFromStandardDictionary(dictionary_bytes)).dictionary else null;
    const dictionaries = [_]h.Z.NativeDictionary{dictionary orelse h.Z.NativeDictionary.initRawContent("")};
    const set = try h.Z.NativeDictionarySet.initChecked(if (dictionary != null) &dictionaries else &.{});
    var state: h.State = .{};
    state.dictionary_kind = if (dictionary) |dict| dict.kind() else null;
    var failure: ?[]const u8 = null;
    const output: ?[]u8 = operation(init, input, c, dictionary, set, &state) catch |err| blk: {
        failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    const after_input = h.digest(input);
    const after_dictionary = h.digest(dictionary_bytes);
    try h.require(std.mem.eql(u8, &input_hash, &after_input) and std.mem.eql(u8, &dictionary_hash, &after_dictionary));
    state.borrowed_input_and_dictionary_preserved = true;
    if (output) |bytes| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    const output_hash = if (output) |bytes| h.digest(bytes) else h.digest("");
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.zstd.dictionary_id_control.probe.v1",
        .@"error" = failure,
        .config = c,
        .input_bytes = input.len,
        .input_sha256 = input_hash[0..],
        .dictionary_bytes = dictionary_bytes.len,
        .dictionary_sha256 = dictionary_hash[0..],
        .selected_dictionary_id = if (dictionary) |dict| h.selected(c, dict) else 0,
        .output_bytes = if (output) |bytes| bytes.len else 0,
        .output_sha256 = output_hash[0..],
        .state = state,
        .target = @tagName(builtin.cpu.arch),
        .pointer_bits = @bitSizeOf(usize),
        .cpu_model = builtin.cpu.model.name,
        .build_mode = @tagName(builtin.mode),
        .zig_version = builtin.zig_version_string,
    }, .{});
    defer init.gpa.free(report);
    try std.Io.File.stdout().writeStreamingAll(init.io, report);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
fn operation(init: std.process.Init, input: []const u8, c: h.Config, dictionary: ?h.Z.NativeDictionary, set: h.Z.NativeDictionarySet, state: *h.State) ![]u8 {
    if (c.input_chunk == 0 or c.output_chunk == 0 or c.output_chunk > 65536 or c.block_size == 0) return error.InvalidProbeConfig;
    if (c.operation == .decode) return decode.run(init, input, c, dictionary, set, state);
    const dict = dictionary orelse return error.NeedDictionary;
    const wire = try encode.run(init, input, c, dict, set, state);
    errdefer init.gpa.free(wire);
    if (state.encoded_bound) |bound| {
        try h.require(wire.len <= bound);
        state.bound_verified = true;
    }
    const restored = if (std.mem.startsWith(u8, c.api, "seekable_")) try h.Z.decodeNativeSeekableRangeAllocWithDictionary(init.gpa, wire, 0, input.len, dict) else try h.Z.decodeFrameAllocWithOptions(init.gpa, wire, .{ .format = c.format, .dictionary = dict, .max_output_len = input.len, .expected_output_len = input.len });
    defer init.gpa.free(restored);
    try h.require(std.mem.eql(u8, restored, input));
    state.self_decode_verified = true;
    return wire;
}
