//! Time one explicit-HQ Brotli encode and print the parser work counters.
//! The input file is read whole and must already be the intended prefix.
const std = @import("std");
const br = @import("vort_br");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingInput;
    const quality: u4 = @intCast(try std.fmt.parseInt(u8, args.next() orelse "11", 10));
    var hq: br.HqOptions = .{};
    hq.block_len = try std.fmt.parseInt(usize, args.next() orelse "65536", 10);
    hq.beam_width = try std.fmt.parseInt(u8, args.next() orelse "16", 10);
    hq.iterations = try std.fmt.parseInt(u8, args.next() orelse "2", 10);
    hq.search_depth = try std.fmt.parseInt(u32, args.next() orelse "64", 10);
    hq.nice_len = try std.fmt.parseInt(u32, args.next() orelse "128", 10);
    var profile: br.HqProfile = .{};
    hq.profile = &profile;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(8 * 1024 * 1024));
    defer init.gpa.free(input);
    const options: br.PlannedEncodeOptions = .{ .quality = quality, .hq = hq };
    const start = std.Io.Clock.awake.now(init.io);
    const encoded = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, options);
    defer init.gpa.free(encoded);
    const ns = start.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds;
    std.debug.print(
        "input={d} bytes={d} ns={d} tree_nodes={d} match_probes={d} price_evaluations={d} passes={d} max_parse_positions={d} peak_working_memory={d} emitted_metablocks={d} emitted_commands={d}\n",
        .{
            input.len,                   encoded.len,                @max(ns, 0),              profile.tree_nodes,
            profile.match_probes,        profile.price_evaluations,  profile.passes,           profile.max_parse_positions,
            profile.peak_working_memory, profile.emitted_metablocks, profile.emitted_commands,
        },
    );
}
