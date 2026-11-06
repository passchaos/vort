//! Root-public stream clone probe. Fixtures and outputs are bounded files;
//! the report counts bytes actually consumed and delivered on both branches.
const std = @import("std");
const codec = @import("codec");
const common = @import("common.zig");
const encoders = @import("encoders.zig");
const decoders = @import("decoders.zig");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const config_path = args.next() orelse return error.MissingConfig;
    const json = try common.load(init, config_path);
    defer init.gpa.free(json);
    const config_json = try std.json.parseFromSlice(common.Config, init.gpa, json, .{});
    defer config_json.deinit();
    const config = config_json.value;
    if (config.window_bits != 9 and config.window_bits != 15) return error.InvalidConfig;
    const prefix = try common.load(init, config.prefix_path);
    defer init.gpa.free(prefix);
    const tail_a = try common.load(init, config.tail_a_path);
    defer init.gpa.free(tail_a);
    const tail_b = try common.load(init, config.tail_b_path);
    defer init.gpa.free(tail_b);
    const dictionary: []const u8 = if (config.dictionary_path) |path| try common.load(init, path) else &.{};
    defer if (config.dictionary_path != null) init.gpa.free(dictionary);
    const receipt = if (config.direction == .encode)
        try encoders.run(init, config, prefix, tail_a, tail_b, dictionary)
    else
        try decoders.run(init, config, prefix, tail_a, tail_b, dictionary);
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.deflate.clone-probe.v1",
        .family = config.family,
        .direction = config.direction,
        .stage = config.stage,
        .pointer_bits = @bitSizeOf(usize),
        .counter_bits = @bitSizeOf(codec.StreamCount),
        .build_mode = @tagName(@import("builtin").mode),
        .receipt = receipt,
    }, .{});
    defer init.gpa.free(report);
    try common.save(init, config.report_path, report);
}
