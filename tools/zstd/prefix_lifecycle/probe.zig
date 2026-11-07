//! Run explicit public-handle lifecycle scripts against independent C receipts.
const std = @import("std");
const builtin = @import("builtin");
const h = @import("probe_helpers/common.zig");
const resources = @import("probe_helpers/resources.zig");
const runner = @import("probe_helpers/runner.zig");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const json = try h.read(init, config_path);
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(h.Config, init.gpa, json, .{});
    defer parsed.deinit();
    const config = parsed.value;
    try h.require(config.input_chunk > 0 and config.output_chunk <= 65536);
    const assets = try resources.load(init, config.stages);
    defer resources.deinit(init.gpa, assets);
    const initial_bytes = if (config.initial_dictionary_path) |path| try h.read(init, path) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(initial_bytes);
    const initial_hash = h.digest(initial_bytes);
    const initial_dictionary = if (config.initial_dictionary_path != null) try h.dictionary(initial_bytes, config.initial_full_dictionary) else null;
    const events = try runner.run(init, config, assets, initial_bytes, initial_dictionary);
    defer resources.freeEvents(init.gpa, events);
    try resources.verify(assets);
    const initial_after_hash = h.digest(initial_bytes);
    try h.require(std.mem.eql(u8, &initial_hash, &initial_after_hash));
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.zstd.prefix-lifecycle.probe.v1",
        .config = config,
        .borrowed_assets_preserved = true,
        .events = events,
        .target = @tagName(builtin.cpu.arch),
        .pointer_bits = @bitSizeOf(usize),
        .cpu_model = builtin.cpu.model.name,
        .build_mode = @tagName(builtin.mode),
        .zig_version = builtin.zig_version_string,
        .completed = true,
    }, .{});
    defer init.gpa.free(report);
    try std.Io.File.stdout().writeStreamingAll(init.io, report);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
