//! Two feedback proposals retain separate models, plans and arbitration slots.
//! The bounded paired solver shares only their input-dependent match scan.
const std = @import("std");

pub fn runExtra(
    comptime Api: type,
    comptime traced: bool,
    trace: Api.Recorder(traced),
    allocator: std.mem.Allocator,
    input: []const u8,
    options: Api.Options,
    seed_commands: []const Api.Command,
    wire_options: Api.WireOptions,
    best: *[]u8,
) Api.Error!void {
    var model = blk: {
        var timer = trace.begin(.other, input.len, seed_commands.len);
        defer timer.finish();
        errdefer |err| timer.failure(err);
        break :blk try Api.buildModel(allocator, input, seed_commands, options.window_len);
    };
    defer model.deinit(allocator);

    if (Api.pairAllowed(input, options, &model, wire_options)) {
        var bonus = try buildBonus(Api, traced, trace, allocator, input, seed_commands, options.window_len);
        defer bonus.deinit(allocator);
        const plans = blk: {
            // One actual scan and two independently priced DPs, not two
            // fabricated parser events or a reused cost frontier.
            var timer = trace.begin(.optimal_parse, input.len, 0);
            defer timer.finish();
            errdefer |err| timer.failure(err);
            break :blk try Api.planPair(allocator, input, options, .{ model.lz77Model(), bonus.lz77Model() });
        };
        defer plans[0].deinit(allocator);
        defer plans[1].deinit(allocator);
        // Preserve the original first-proposal then bonus-proposal slots and
        // strict byte-size comparison even when the second plan is ready.
        try emit(Api, traced, trace, allocator, input, plans[0], wire_options, best);
        try emit(Api, traced, trace, allocator, input, plans[1], wire_options, best);
        return;
    }

    const first = try planSingle(Api, traced, trace, allocator, input, options, model.lz77Model());
    defer first.deinit(allocator);
    try emit(Api, traced, trace, allocator, input, first, wire_options, best);
    var bonus = try buildBonus(Api, traced, trace, allocator, input, seed_commands, options.window_len);
    defer bonus.deinit(allocator);
    const second = try planSingle(Api, traced, trace, allocator, input, options, bonus.lz77Model());
    defer second.deinit(allocator);
    try emit(Api, traced, trace, allocator, input, second, wire_options, best);
}

fn buildBonus(comptime Api: type, comptime traced: bool, trace: Api.Recorder(traced), allocator: std.mem.Allocator, input: []const u8, commands: []const Api.Command, window: usize) Api.Error!Api.Model {
    var timer = trace.begin(.other, input.len, commands.len);
    defer timer.finish();
    errdefer |err| timer.failure(err);
    return Api.buildBonus(allocator, input, commands, window);
}

fn planSingle(comptime Api: type, comptime traced: bool, trace: Api.Recorder(traced), allocator: std.mem.Allocator, input: []const u8, options: Api.Options, model: Api.CostModel) Api.Error!Api.Plan {
    var timer = trace.begin(.optimal_parse, input.len, 0);
    defer timer.finish();
    errdefer |err| timer.failure(err);
    return Api.planSingle(allocator, input, options, model);
}

fn emit(comptime Api: type, comptime traced: bool, trace: Api.Recorder(traced), allocator: std.mem.Allocator, input: []const u8, plan: Api.Plan, options: Api.WireOptions, best: *[]u8) Api.Error!void {
    if (plan.stats.matches == 0) return;
    const commands = blk: {
        var timer = trace.begin(.optimal_commands, input.len, plan.tokens.len);
        defer timer.finish();
        errdefer |err| timer.failure(err);
        break :blk try Api.buildCommands(allocator, input, plan.tokens);
    };
    defer commands.deinit(allocator);
    var stats: Api.Stats = .{};
    const candidate = try Api.encodeCandidate(traced, trace, allocator, input, commands.commands, &stats, options);
    Api.retain(traced, trace, allocator, best, candidate);
}
