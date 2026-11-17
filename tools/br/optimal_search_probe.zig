const std = @import("std");
const vort = @import("vort");

/// Profile the Brotli optimal search on one input prefix. The counters are the
/// same ones the production q10/q11 path collects when traced; this probe
/// keeps the timing isolated from the planned encoder's other candidates.
pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingInput;
    const limit = try std.fmt.parseInt(usize, args.next() orelse "131072", 10);
    const max_chain = try std.fmt.parseInt(usize, args.next() orelse "512", 10);
    const max_candidates = try std.fmt.parseInt(usize, args.next() orelse "256", 10);
    const nice_len = try std.fmt.parseInt(usize, args.next() orelse "258", 10);

    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    const read_len: usize = @intCast(@min(stat.size, limit));
    if (read_len == 0) return error.InputTooSmall;
    const input = try init.gpa.alloc(u8, read_len);
    defer init.gpa.free(input);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(init.io, &buffer);
    if (try reader.interface.readSliceShort(input) != read_len) return error.InputTooSmall;

    var profile: vort.lz77.OptimalSearchProfile = .{};
    const plan = try vort.lz77.optimalPlanAllocProfiled(init.gpa, input, .{
        .window_len = @min(input.len, 32 * 1024),
        .max_chain = max_chain,
        .nice_len = nice_len,
        .max_candidates = max_candidates,
        .min_match = 4,
        .max_match = 258,
    }, init.io, &profile);
    defer plan.deinit(init.gpa);

    std.debug.print(
        "input={d} chain={d} candidates={d} nice={d} tokens={d} literals={d} matches={d} matched={d}\n",
        .{ input.len, max_chain, max_candidates, nice_len, plan.tokens.len, plan.stats.literals, plan.stats.matches, plan.stats.matched_bytes },
    );
    std.debug.print(
        "index_ns={d} search_ns={d} reconstruct_ns={d} total_ns={d} index_bytes={d}\n",
        .{ profile.index_ns, profile.search_ns, profile.reconstruct_ns, profile.total_ns, profile.index_bytes },
    );
    std.debug.print(
        "positions={d} chain_nodes={d} prefix_rejections={d} bound_rejections={d} match_length_calls={d} valid_matches={d} length_choices={d} budget_stops={d}\n",
        .{ profile.positions, profile.chain_nodes, profile.prefix_rejections, profile.bound_rejections, profile.match_length_calls, profile.valid_match_candidates, profile.length_choices_built, profile.candidate_budget_stops },
    );
}
