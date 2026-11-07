const std = @import("std");
const builtin = @import("builtin");
const h = @import("probe_helpers/common.zig");
const run = @import("probe_helpers/runner.zig");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const wire_path = args.next() orelse return error.MissingWire;
    const payload_path = args.next() orelse return error.MissingPayload;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const wire = try h.read(init, wire_path);
    defer init.gpa.free(wire);
    const payload = try h.read(init, payload_path);
    defer init.gpa.free(payload);
    const json = try h.read(init, config_path);
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(h.Config, init.gpa, json, .{});
    defer parsed.deinit();
    const config = parsed.value;
    if (config.input_chunks.len == 0 or config.output_quanta.len == 0) return error.InvalidProbeSchedule;
    const dictionary_bytes = if (config.dictionary_path) |path| try h.read(init, path) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(dictionary_bytes);
    const dictionary: ?h.Z.NativeDictionary = if (config.dictionary_path != null) (try h.Z.NativeDictionary.initFromStandardDictionary(dictionary_bytes)).dictionary else null;
    const wire_hash = h.digest(wire);
    const payload_hash = h.digest(payload);
    const dict_hash = h.digest(dictionary_bytes);
    var state: run.State = .{};
    defer state.deinit(init.gpa);
    const output: ?[]u8 = run.run(init, wire, payload, config, dictionary, &state) catch |err| blk: {
        state.failure = @errorName(err);
        break :blk null;
    };
    defer if (output) |bytes| init.gpa.free(bytes);
    try h.require(state.requested_after_deinit == 0);
    const wire_after = h.digest(wire);
    const payload_after = h.digest(payload);
    const dict_after = h.digest(dictionary_bytes);
    try h.require(std.mem.eql(u8, &wire_hash, &wire_after) and std.mem.eql(u8, &payload_hash, &payload_after) and std.mem.eql(u8, &dict_hash, &dict_after));
    if (output) |bytes| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = bytes });
    const output_hash = if (output) |bytes| h.digest(bytes) else h.digest("");
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.zstd.stable_output.probe.v1",
        .@"error" = state.failure,
        .config = config,
        .wire_bytes = wire.len,
        .wire_sha256 = wire_hash[0..],
        .payload_bytes = payload.len,
        .payload_sha256 = payload_hash[0..],
        .dictionary_sha256 = dict_hash[0..],
        .borrowed_input_and_dictionary_preserved = true,
        .output_bytes = if (output) |bytes| bytes.len else 0,
        .output_sha256 = output_hash[0..],
        .state = state,
        .target = @tagName(builtin.cpu.arch),
        .pointer_bits = @bitSizeOf(usize),
        .cpu_model = builtin.cpu.model.name,
        .build_mode = @tagName(builtin.mode),
        .zig_version = builtin.zig_version_string,
        .memory_scope = "Decoder-only requested allocation bytes; caller destination and fixture buffers excluded; growth must relocate; no RSS comparison",
    }, .{});
    defer init.gpa.free(report);
    try std.Io.File.stdout().writeStreamingAll(init.io, report);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
