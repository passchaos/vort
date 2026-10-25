//! Caller-owned diagnostics for the existing native q8 candidate pipeline.
//! Storage is fixed and reporting truncation never changes codec selection.
const std = @import("std");
const total = @import("total_budget.zig");
pub const event_capacity = 512;
const stack_capacity = 32;

pub const Stage = enum { outer, lazy_parse, lazy_commands, optimal_parse, optimal_commands, preferred_context, split_planning, wire, distance_parameters, selection, other };
pub const Origin = enum { other, lazy, optimal };
pub const Request = struct {
    max_total_working_memory: ?usize = null,
    memory_profile: ?*total.EncodeMemoryProfile = null,
    event_limit: usize = event_capacity,
};
pub const Exclusive = struct {
    lazy_parse: u64 = 0,
    lazy_commands: u64 = 0,
    optimal_parse: u64 = 0,
    optimal_commands: u64 = 0,
    preferred_context: u64 = 0,
    split_planning: u64 = 0,
    wire: u64 = 0,
    distance_parameters: u64 = 0,
    selection: u64 = 0,
    other: u64 = 0,
    pub fn total(self: Exclusive) u64 {
        var result: u64 = 0;
        inline for (std.meta.fields(Exclusive)) |field| result +|= @field(self, field.name);
        return result;
    }
    pub fn checkedTotal(self: Exclusive) ?u64 {
        var result: u64 = 0;
        inline for (std.meta.fields(Exclusive)) |field|
            result = std.math.add(u64, result, @field(self, field.name)) catch return null;
        return result;
    }
};
pub const Config = struct {
    window_bits: u5 = 16,
    large_window: bool = false,
    use_recent_distances: bool = false,
    npostfix: u8 = 0,
    ndirect_high: u8 = 0,
    context_mode: ?u2 = null,
    context_trees: usize = 0,
    context_cutoff: ?u6 = null,
    context_map: [64]u8 = @splat(0),
    literal_split: bool = false,
    adaptive_literal_split: bool = false,
    joint_literal_contexts: bool = false,
    command_split: bool = false,
    adaptive_command_split: bool = false,
    distance_split: bool = false,
    adaptive_distance_split: bool = false,
    literal_type_count: usize = 0,
    command_type_count: usize = 0,
    distance_type_count: usize = 0,
    joint_literal_tree_count: usize = 0,
    optimize_same_last_distance: bool = false,

    pub fn from(options: anytype) Config {
        var result: Config = .{
            .window_bits = options.window_bits,
            .large_window = options.large_window,
            .use_recent_distances = options.use_recent_distances,
            .npostfix = options.distance_parameters.npostfix,
            .ndirect_high = options.distance_parameters.ndirect_high,
            .literal_split = options.literal_split != null,
            .adaptive_literal_split = options.adaptive_literal_split != null,
            .joint_literal_contexts = options.literal_entropy_plan != null,
            .command_split = options.command_split != null,
            .adaptive_command_split = options.adaptive_command_split != null,
            .distance_split = options.distance_split != null,
            .adaptive_distance_split = options.adaptive_distance_split != null,
            .optimize_same_last_distance = options.optimize_same_last_distance,
        };
        if (options.literal_context_candidate) |context| {
            result.context_mode = context.mode;
            result.context_trees = context.tree_count;
            result.context_cutoff = context.suffixCutoff();
            result.context_map = context.context_map;
        }
        if (options.literal_split) |split| result.literal_type_count = split.typeCount();
        if (options.adaptive_literal_split) |split| result.literal_type_count = split.type_count;
        if (options.command_split) |split| result.command_type_count = split.typeCount();
        if (options.adaptive_command_split) |split| result.command_type_count = split.type_count;
        if (options.distance_split) |split| result.distance_type_count = split.typeCount();
        if (options.adaptive_distance_split) |split| result.distance_type_count = split.type_count;
        if (options.literal_entropy_plan) |plan| result.joint_literal_tree_count = plan.tree_count;
        return result;
    }
};
pub const Event = struct {
    id: usize,
    parent_id: ?usize = null,
    stage: Stage,
    origin: Origin = .other,
    variant: bool = false,
    inclusive_ns: u64 = 0,
    exclusive_ns: u64 = 0,
    input_bytes: usize = 0,
    command_count: usize = 0,
    wire_bytes: ?usize = null,
    error_name: []const u8 = "",
    accepted: ?bool = null,
    gain_bytes: usize = 0,
    incumbent_bytes: ?usize = null,
    candidate_event_id: ?usize = null,
    incumbent_event_id: ?usize = null,
    config: Config = .{},
};
const Frame = struct { id: usize, child_ns: u64 = 0 };
pub const Profile = struct {
    request: Request = .{},
    events: [event_capacity]Event = undefined,
    event_count: usize = 0,
    events_total: usize = 0,
    events_truncated: bool = false,
    wire_attempts: usize = 0,
    /// The first slice fully traces the lazy/optimal/context/split candidates.
    /// Native dictionary auxiliaries on inputs <=4096 remain coarse `other`
    /// work and explicitly mark their detailed wire coverage incomplete.
    wire_attempt_coverage_complete: bool = true,
    /// False for timestamp conversion overflow, saturated time sums, impossible
    /// child durations, or a stack deeper than the fixed timing-frame capacity.
    timing_complete: bool = true,
    outer_elapsed_ns: u64 = 0,
    exclusive_ns: Exclusive = .{},
    unaccounted_ns: u64 = 0,
    error_name: []const u8 = "",
    returned_wire_bytes: ?usize = null,
    returned_wire_event_id: ?usize = null,
    stack: [stack_capacity]Frame = undefined,
    depth: usize = 0,
    wire_addresses: [event_capacity]usize = @splat(0),
    wire_live: [event_capacity]bool = @splat(false),

    pub fn reset(self: *Profile) void {
        const request = self.request;
        self.* = .{ .request = request };
    }
    pub fn recordedEvents(self: *const Profile) []const Event {
        return self.events[0..self.event_count];
    }
    pub fn jsonStringify(self: *const Profile, writer: anytype) !void {
        try writer.write(.{
            .max_total_working_memory = self.request.max_total_working_memory,
            .event_limit = self.request.event_limit,
            .events = self.recordedEvents(),
            .event_count = self.event_count,
            .events_total = self.events_total,
            .events_truncated = self.events_truncated,
            .wire_attempts = self.wire_attempts,
            .wire_attempt_coverage_complete = self.wire_attempt_coverage_complete,
            .timing_complete = self.timing_complete,
            .outer_elapsed_ns = self.outer_elapsed_ns,
            .exclusive_ns = self.exclusive_ns,
            .unaccounted_ns = self.unaccounted_ns,
            .error_name = self.error_name,
            .returned_wire_bytes = self.returned_wire_bytes,
            .returned_wire_event_id = self.returned_wire_event_id,
        });
    }
};

pub fn Recorder(comptime enabled: bool) type {
    return if (enabled) Active else Disabled;
}
pub const Disabled = struct {
    pub fn withOrigin(self: Disabled, _: Origin) Disabled {
        return self;
    }
    pub fn variant(self: Disabled) Disabled {
        return self;
    }
    pub fn begin(_: Disabled, _: Stage, _: usize, _: usize) EmptyScope {
        return .{};
    }
    pub fn prefer(_: Disabled, candidate: []const u8, incumbent: []const u8) bool {
        return candidate.len < incumbent.len;
    }
    pub fn incompleteWires(_: Disabled) void {}
    pub fn returned(_: Disabled, _: []const u8) void {}
    pub fn forgetWire(_: Disabled, _: []const u8) void {}
};
pub const EmptyScope = struct {
    pub fn finish(_: *EmptyScope) void {}
    pub fn wire(_: *EmptyScope, _: []const u8) void {}
    pub fn failure(_: *EmptyScope, _: anyerror) void {}
    pub fn config(_: *EmptyScope, _: anytype) void {}
};

pub const Active = struct {
    io: std.Io,
    profile: *Profile,
    origin: Origin = .other,
    is_variant: bool = false,
    pub fn withOrigin(self: Active, origin: Origin) Active {
        var result = self;
        result.origin = origin;
        return result;
    }
    pub fn variant(self: Active) Active {
        var result = self;
        result.is_variant = true;
        return result;
    }
    fn append(self: Active, event: Event) ?usize {
        const p = self.profile;
        p.events_total +|= 1;
        if (p.event_count >= @min(event_capacity, p.request.event_limit)) {
            p.events_truncated = true;
            return null;
        }
        const index = p.event_count;
        p.events[index] = event;
        p.event_count += 1;
        return index;
    }
    pub fn begin(self: Active, stage: Stage, input: usize, commands: usize) Scope {
        const p = self.profile;
        const id = p.events_total;
        const parent = if (p.depth == 0) null else p.stack[p.depth - 1].id;
        const slot = self.append(.{ .id = id, .parent_id = parent, .stage = stage, .origin = self.origin, .variant = self.is_variant, .input_bytes = input, .command_count = commands });
        if (stage == .wire) p.wire_attempts +|= 1;
        const frame: ?usize = if (p.depth < stack_capacity) p.depth else null;
        if (frame) |index| {
            p.stack[index] = .{ .id = id };
            p.depth += 1;
        } else p.timing_complete = false;
        return .{ .recorder = self, .stage = stage, .slot = slot, .frame = frame, .start = std.Io.Clock.awake.now(self.io) };
    }
    fn wireId(self: Active, wire: []const u8) ?usize {
        if (self.profile.events_truncated or !self.profile.wire_attempt_coverage_complete) return null;
        var index = self.profile.event_count;
        while (index != 0) {
            index -= 1;
            const event = self.profile.events[index];
            if (self.profile.wire_live[index] and event.stage == .wire and event.error_name.len == 0 and event.wire_bytes == wire.len and self.profile.wire_addresses[index] == @intFromPtr(wire.ptr)) return event.id;
        }
        return null;
    }
    pub fn prefer(self: Active, candidate: []const u8, incumbent: []const u8) bool {
        const accepted = candidate.len < incumbent.len;
        _ = self.append(.{
            .id = self.profile.events_total,
            .parent_id = if (self.profile.depth == 0) null else self.profile.stack[self.profile.depth - 1].id,
            .stage = .selection,
            .origin = self.origin,
            .variant = self.is_variant,
            .wire_bytes = candidate.len,
            .incumbent_bytes = incumbent.len,
            .accepted = accepted,
            .gain_bytes = if (accepted) incumbent.len - candidate.len else 0,
            .candidate_event_id = self.wireId(candidate),
            .incumbent_event_id = self.wireId(incumbent),
        });
        return accepted;
    }
    pub fn incompleteWires(self: Active) void {
        self.profile.wire_attempt_coverage_complete = false;
    }
    pub fn forgetWire(self: Active, wire: []const u8) void {
        for (self.profile.events[0..self.profile.event_count], 0..) |event, index| {
            if (event.stage == .wire and event.wire_bytes == wire.len and self.profile.wire_addresses[index] == @intFromPtr(wire.ptr))
                self.profile.wire_live[index] = false;
        }
    }
    pub fn returned(self: Active, wire: []const u8) void {
        self.profile.returned_wire_bytes = wire.len;
        self.profile.returned_wire_event_id = self.wireId(wire);
    }
};
pub const Scope = struct {
    recorder: Active,
    stage: Stage,
    slot: ?usize,
    frame: ?usize,
    start: std.Io.Timestamp,
    pub fn wire(self: *Scope, bytes: []const u8) void {
        if (self.slot) |index| {
            self.recorder.profile.events[index].wire_bytes = bytes.len;
            self.recorder.profile.wire_addresses[index] = @intFromPtr(bytes.ptr);
            self.recorder.profile.wire_live[index] = self.stage == .wire;
        }
    }
    pub fn failure(self: *Scope, err: anyerror) void {
        if (self.slot) |index| self.recorder.profile.events[index].error_name = @errorName(err);
    }
    pub fn config(self: *Scope, options: anytype) void {
        if (self.slot) |index| self.recorder.profile.events[index].config = Config.from(options);
    }
    pub fn finish(self: *Scope) void {
        const p = self.recorder.profile;
        const elapsed = self.start.durationTo(std.Io.Clock.awake.now(self.recorder.io)).nanoseconds;
        const inclusive: u64 = if (elapsed < 0) blk: {
            p.timing_complete = false;
            break :blk 0;
        } else std.math.cast(u64, elapsed) orelse blk: {
            p.timing_complete = false;
            break :blk std.math.maxInt(u64);
        };
        var child: u64 = 0;
        if (self.frame) |index| {
            std.debug.assert(p.depth == index + 1);
            child = p.stack[index].child_ns;
            p.depth -= 1;
        }
        if (child > inclusive) p.timing_complete = false;
        const exclusive = inclusive -| child;
        if (self.slot) |index| {
            p.events[index].inclusive_ns = inclusive;
            p.events[index].exclusive_ns = exclusive;
        }
        if (p.depth != 0) addTime(p, &p.stack[p.depth - 1].child_ns, inclusive);
        switch (self.stage) {
            .outer => {
                p.outer_elapsed_ns = inclusive;
                const sum = p.exclusive_ns.checkedTotal() orelse blk: {
                    p.timing_complete = false;
                    break :blk std.math.maxInt(u64);
                };
                if (sum > inclusive) p.timing_complete = false;
                p.unaccounted_ns = inclusive -| sum;
            },
            inline else => |stage| addTime(p, &@field(p.exclusive_ns, @tagName(stage)), exclusive),
        }
    }
};

fn addTime(profile: *Profile, target: *u64, amount: u64) void {
    target.* = std.math.add(u64, target.*, amount) catch blk: {
        profile.timing_complete = false;
        break :blk std.math.maxInt(u64);
    };
}
