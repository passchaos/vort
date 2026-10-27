//! Independent trace contracts; no codec, output allocation, or fake slices.
const std = @import("std");

pub fn run(comptime Trace: type) !void {
    try references(Trace);
    try truncation(Trace);
    try disabled(Trace);
}

fn references(comptime Trace: type) !void {
    var profile: Trace.Profile = .{};
    const trace: Trace.Active = .{ .io = std.testing.io, .profile = &profile };
    var outer = trace.begin(.outer, 100, 2);
    var primary: [10]u8 = @splat(1);
    var first = trace.begin(.wire, 100, 2);
    first.wire(&primary);
    first.finish();
    const real = trace.reference(&primary);
    try std.testing.expect(real.id != null and real.bytes == 10);
    var evaluation = trace.withOrigin(.optimal).variant().begin(.evaluate, 100, 2);
    const candidate = evaluation.evaluated(8);
    evaluation.finish();
    const eval_id = candidate.id.?;
    try std.testing.expectEqual(@as(?usize, 8), profile.events[eval_id].evaluated_wire_bytes);
    try std.testing.expectEqual(@as(?usize, null), profile.events[eval_id].wire_bytes);
    try std.testing.expectEqual(@as(usize, 0), profile.wire_addresses[eval_id]);
    try std.testing.expect(!profile.wire_live[eval_id]);
    try std.testing.expect(profile.events[eval_id].origin == .optimal and profile.events[eval_id].variant);
    try std.testing.expect(trace.preferReferences(candidate, real));
    const selection = profile.events[profile.event_count - 1];
    try std.testing.expectEqual(candidate.id, selection.candidate_event_id);
    try std.testing.expectEqual(real.id, selection.incumbent_event_id);
    try std.testing.expectEqual(@as(usize, 2), selection.gain_bytes);
    var tie_scope = trace.begin(.evaluate, 100, 2);
    const tied = tie_scope.evaluated(8);
    tie_scope.finish();
    try std.testing.expect(!trace.preferReferences(tied, candidate));
    var output: [8]u8 = @splat(2);
    var emitted = trace.begin(.wire, 100, 2);
    emitted.emissionOf(candidate);
    emitted.wire(&output);
    emitted.finish();
    const emitted_ref = trace.reference(&output);
    try std.testing.expect(emitted_ref.id != candidate.id);
    const emitted_id = emitted_ref.id.?;
    try std.testing.expectEqual(candidate.id, profile.events[emitted_id].evaluation_event_id);
    try std.testing.expectEqual(@as(?usize, 8), profile.events[emitted_id].wire_bytes);
    try std.testing.expectEqual(@as(?usize, 8), profile.events[emitted_id].evaluated_wire_bytes);
    try std.testing.expectEqual(@intFromPtr(&output), profile.wire_addresses[emitted_id]);
    try std.testing.expect(profile.wire_live[emitted_id]);
    trace.returned(&output);
    try std.testing.expectEqual(emitted_ref.id, profile.returned_wire_event_id);
    try std.testing.expectEqual(@as(usize, 2), profile.wire_attempts);
    try std.testing.expectEqual(@as(usize, 2), profile.evaluation_attempts);
    trace.forgetWire(&primary);
    try std.testing.expectEqual(@as(?usize, null), trace.reference(&primary).id);
    outer.finish();
    const json = try std.json.Stringify.valueAlloc(std.testing.allocator, profile, .{});
    defer std.testing.allocator.free(json);
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json, .{});
    defer parsed.deinit();
    try std.testing.expectEqual(@as(i64, 2), parsed.value.object.get("evaluation_attempts").?.integer);
    try std.testing.expect(parsed.value.object.get("exclusive_ns").?.object.contains("evaluate"));
}

fn truncation(comptime Trace: type) !void {
    for ([_]usize{ 0, 1, 2, 3, 4, 5, Trace.event_capacity }) |limit| {
        var profile: Trace.Profile = .{};
        profile.request.event_limit = limit;
        const trace: Trace.Active = .{ .io = std.testing.io, .profile = &profile };
        var outer = trace.begin(.outer, 100, 2);
        var primary: [10]u8 = @splat(1);
        var wire_scope = trace.begin(.wire, 100, 2);
        wire_scope.wire(&primary);
        wire_scope.finish();
        var best = trace.reference(&primary);
        for ([_]usize{ 8, 8, 9, 7 }) |bytes| {
            var evaluation = trace.begin(.evaluate, 100, 2);
            const recorded = evaluation.slot != null;
            const candidate = evaluation.evaluated(bytes);
            try std.testing.expectEqual(recorded, candidate.id != null);
            evaluation.finish();
            if (trace.preferReferences(candidate, best)) best = candidate;
        }
        try std.testing.expectEqual(@as(usize, 7), best.bytes);
        var output: [7]u8 = @splat(2);
        var emission = trace.begin(.wire, 100, 2);
        // Also cover association after real bytes were registered.
        emission.wire(&output);
        emission.emissionOf(best);
        emission.finish();
        trace.returned(&output);
        outer.finish();
        try std.testing.expectEqual(@as(usize, 2), profile.wire_attempts);
        try std.testing.expectEqual(@as(usize, 4), profile.evaluation_attempts);
        try std.testing.expect(profile.event_count <= limit);
        for (profile.recordedEvents(), 0..) |event, index| {
            if (event.stage == .evaluate) {
                try std.testing.expect(!profile.wire_live[index]);
                try std.testing.expectEqual(@as(usize, 0), profile.wire_addresses[index]);
                try std.testing.expectEqual(@as(?usize, null), event.wire_bytes);
            }
        }
        if (limit < Trace.event_capacity) {
            try std.testing.expect(profile.events_truncated);
            try std.testing.expectEqual(@as(?usize, null), profile.returned_wire_event_id);
        } else try std.testing.expect(profile.returned_wire_event_id != null);
    }
}

fn disabled(comptime Trace: type) !void {
    const trace: Trace.Disabled = .{};
    var real: [10]u8 = @splat(1);
    var scope = trace.begin(.evaluate, 100, 2);
    const candidate = scope.evaluated(8);
    try std.testing.expectEqual(@as(?usize, null), candidate.id);
    try std.testing.expectEqual(@as(?usize, null), trace.reference(&real).id);
    try std.testing.expect(trace.preferReferences(candidate, trace.reference(&real)));
    try std.testing.expect(!trace.preferReferences(candidate, .{ .bytes = 8, .id = 999 }));
    try std.testing.expect(!trace.prefer(&real, &real));
    scope.emissionOf(candidate);
    scope.finish();
}
