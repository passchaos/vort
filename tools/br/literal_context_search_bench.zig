//! Ordinary proposal-search timing, with exhaustive and profiled equality
//! checks outside every measured interval. One insert command isolates search.
const std = @import("std");
const context = @import("context_bench");
const provenance = @import("benchmark_provenance");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var paths: std.ArrayList([]const u8) = .empty;
    defer paths.deinit(init.gpa);
    var limit: usize = 65536;
    var rounds: usize = 9;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--path")) {
            try paths.append(init.gpa, args.next() orelse return error.MissingArgument);
        } else if (std.mem.eql(u8, arg, "--limit")) {
            limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--rounds")) {
            rounds = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else return error.UnknownArgument;
    }
    if (paths.items.len == 0 or limit == 0 or limit > 1 << 24 or rounds == 0 or rounds > 31)
        return error.InvalidArguments;
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    var json: std.Io.Writer.Allocating = .init(init.gpa);
    defer json.deinit();
    try json.writer.writeAll("{\"schema\":\"vort.brotli.literal-context-search.v1\",\"provenance\":");
    try std.json.Stringify.value(info, .{}, &json.writer);
    try json.writer.writeAll(",\"command_layout\":\"single_insert\",\"rows\":[");
    const profile = try init.gpa.create(context.search.Profile);
    defer init.gpa.destroy(profile);
    for (paths.items, 0..) |path, index| {
        if (index != 0) try json.writer.writeByte(',');
        const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
        defer file.close(init.io);
        const stat = try file.stat(init.io);
        const input = try init.gpa.alloc(u8, @intCast(@min(stat.size, limit)));
        defer init.gpa.free(input);
        var buffer: [4096]u8 = undefined;
        var reader = file.reader(init.io, &buffer);
        if (try reader.interface.readSliceShort(input) != input.len) return error.InputTooSmall;
        const commands = [_]context.Command{.{ .insert_start = 0, .insert_len = input.len }};
        const expected = try context.search.chooseProposalsReference(init.gpa, input, &commands);
        const observed = try context.search.chooseProposalsProfiled(init.gpa, input, &commands, init.io, profile);
        if (!std.meta.eql(expected, observed)) return error.ProposalMismatch;
        const warm = try context.search.chooseProposals(init.gpa, input, &commands);
        if (!std.meta.eql(expected, warm)) return error.ProposalMismatch;
        var elapsed: [31]u64 = undefined;
        for (elapsed[0..rounds]) |*ns| {
            const start = std.Io.Clock.awake.now(init.io);
            const actual = try context.search.chooseProposals(init.gpa, input, &commands);
            ns.* = @intCast(start.durationTo(std.Io.Clock.awake.now(init.io)).toNanoseconds());
            if (!std.meta.eql(expected, actual)) return error.ProposalMismatch;
        }
        const hash = provenance.sha256Hex(input);
        try std.json.Stringify.value(.{
            .path = path,
            .input_bytes = input.len,
            .input_sha256 = &hash,
            .reference_equal = true,
            .profile_equal = true,
            .proposals = expected,
            .normal_ns = elapsed[0..rounds],
            .profile_total_ns = profile.total_ns,
            .profile_suffix_ns = profile.suffix_ns,
            .suffix_payload_scores = profile.suffix_payload_scores,
            .suffix_lb_pruned = profile.suffix_lb_pruned,
        }, .{}, &json.writer);
    }
    try json.writer.writeAll("]}\n");
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll(json.written());
    try stdout.interface.flush();
}
