const std = @import("std");
const settings = @import("../encode_options.zig");
const mf = @import("../match_finder.zig");
const working = @import("../../io/working_allocator.zig");
const types = @import("types.zig");
const fast = @import("fast.zig");
const normal = @import("normal.zig");

pub fn plan(allocator: std.mem.Allocator, model: anytype, history: []const u8, input: []const u8, stream_start: usize, dictionary_size: usize, mode: settings.Mode, match_options: settings.MatchOptions, final_input: bool) !types.Plan {
    if (!final_input and input.len < types.window_len + types.guard_len) return .{ .tokens = try allocator.alloc(types.Token, 0), .consumed = 0, .final_state = types.State.fromModel(model) };
    const look = @min(input.len, types.window_len + types.guard_len);
    const goal = @min(look, types.window_len);
    _ = std.math.add(usize, stream_start, look) catch return error.IntegerOverflow;
    if (goal == 0) return .{ .tokens = try allocator.alloc(types.Token, 0), .consumed = 0, .final_state = types.State.fromModel(model) };
    var budget = working.WorkingAllocator.init(allocator, match_options.max_working_memory);
    defer if (match_options.profile) |profile| {
        profile.peak_working_memory = @max(profile.peak_working_memory, budget.peak);
    };
    const source = mf.Source.init(history, input[0..look], dictionary_size);
    if (match_options.profile) |profile| profile.parser_windows +|= 1;
    return (if (mode == .normal)
        normal.plan(budget.allocator(), &budget, model, source, stream_start, goal, match_options)
    else
        fast.plan(budget.allocator(), &budget, model, source, stream_start, goal, match_options, mode)) catch |err| {
        if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
        return err;
    };
}
