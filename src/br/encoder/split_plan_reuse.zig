//! Transfer completed split results within one immutable original command group.
//! Returned descriptors borrow payload; only successful publication transfers
//! ownership. Retire before leaving the original distance-family scope.
const std = @import("std");
const command_plan = @import("command_plan.zig");
const command_split = @import("command_block_split.zig");
const distance_split = @import("distance_block_split.zig");
const block = @import("block_split_plan.zig");
const literal = @import("literal_entropy_plan.zig");

pub const budget_bytes: usize = 64 * 1024;
pub const SymbolPlans = struct {
    command: command_split.Proposals = .{},
    adaptive_command: ?block.Plan = null,
    distance: distance_split.Proposals = .{},
    adaptive_distance: ?block.Plan = null,

    pub fn deinit(self: *SymbolPlans, allocator: std.mem.Allocator) void {
        if (self.adaptive_command) |plan| plan.deinit(allocator);
        self.adaptive_command = null;
        if (self.adaptive_distance) |plan| plan.deinit(allocator);
        self.adaptive_distance = null;
    }
};

fn keyType(comptime WireContext: type) type {
    return struct {
        use_recent_distances: bool,
        try_command_split: bool,
        try_adaptive_command_split: bool,
        try_distance_split: bool,
        try_adaptive_distance_split: bool,
        distance_split_min_commands: usize,
        wire_context: WireContext,
    };
}

pub fn Key(comptime WireContext: type) type {
    return keyType(WireContext);
}

const CounterFields = struct {
    literal_hits: usize = 0,
    joint_hits: usize = 0,
    symbol_hits: usize = 0,
    literal_null_hits: usize = 0,
    joint_null_hits: usize = 0,
    symbol_empty_hits: usize = 0,
    literal_captures: usize = 0,
    joint_captures: usize = 0,
    symbol_captures: usize = 0,
    cap_refusals: usize = 0,
    symbol_capacity_refusals: usize = 0,
    retained_payload_bytes: usize = 0,
    retained_requested_bytes: usize = 0,
};

pub const Counters = CounterFields;

pub fn Owner(comptime WireContext: type) type {
    return struct {
        const Self = @This();
        pub const Key = SymbolKey;
        pub const Counters = CounterFields;
        const SymbolKey = keyType(WireContext);
        pub const LiteralResult = struct { plan: ?block.Plan };
        pub const JointResult = struct { plan: ?literal.Plan };
        const SymbolSlot = struct { key: Self.Key, plans: SymbolPlans };

        input: []const u8,
        commands: []const command_plan.Command,
        cap_bytes: usize,
        active: bool,
        literal_ready: bool = false,
        literal_plan: ?block.Plan = null,
        joint_ready: bool = false,
        joint_plan: ?literal.Plan = null,
        symbols: [2]SymbolSlot = undefined,
        symbol_count: usize = 0,
        payload_bytes: usize = 0,
        counters: Self.Counters = .{},

        pub fn init(input: []const u8, commands: []const command_plan.Command, cap_bytes: usize) Self {
            const cap = @min(cap_bytes, budget_bytes);
            const active = commands.len != 0 and @sizeOf(Self) <= cap;
            return .{ .input = input, .commands = commands, .cap_bytes = cap, .active = active, .counters = .{ .retained_requested_bytes = if (active) @sizeOf(Self) else 0 } };
        }

        pub fn matches(self: *const Self, input: []const u8, commands: []const command_plan.Command) bool {
            return self.active and self.input.ptr == input.ptr and self.input.len == input.len and
                self.commands.ptr == commands.ptr and self.commands.len == commands.len;
        }

        pub fn getLiteral(self: *Self, input: []const u8, commands: []const command_plan.Command) ?LiteralResult {
            if (!self.matches(input, commands) or !self.literal_ready) return null;
            self.counters.literal_hits += 1;
            if (self.literal_plan == null) self.counters.literal_null_hits += 1;
            return .{ .plan = self.literal_plan };
        }

        pub fn publishLiteral(self: *Self, input: []const u8, commands: []const command_plan.Command, plan: ?block.Plan) bool {
            if (!self.matches(input, commands) or self.literal_ready) return false;
            const bytes = if (plan) |value| planRequestedBytes(value) catch return self.refuse() else 0;
            if (!self.admit(bytes)) return false;
            self.literal_plan = plan;
            self.literal_ready = true;
            self.counters.literal_captures += 1;
            return true;
        }

        fn literalMatches(self: *const Self, value: block.Plan) bool {
            const cached = self.literal_plan orelse return false;
            return self.literal_ready and sameLiteral(cached, value);
        }

        pub fn getJoint(self: *Self, input: []const u8, commands: []const command_plan.Command, source: block.Plan) ?JointResult {
            if (!self.matches(input, commands) or !self.joint_ready or !self.literalMatches(source)) return null;
            self.counters.joint_hits += 1;
            if (self.joint_plan == null) self.counters.joint_null_hits += 1;
            return .{ .plan = self.joint_plan };
        }

        pub fn publishJoint(self: *Self, input: []const u8, commands: []const command_plan.Command, source: block.Plan, result: ?literal.Plan) bool {
            if (!self.matches(input, commands) or self.joint_ready or !self.literalMatches(source)) return false;
            const bytes = if (result) |value| jointRequestedBytes(value) catch return self.refuse() else 0;
            if (!self.admit(bytes)) return false;
            self.joint_plan = result;
            self.joint_ready = true;
            self.counters.joint_captures += 1;
            return true;
        }

        pub fn getSymbols(self: *Self, input: []const u8, commands: []const command_plan.Command, key: Self.Key) ?SymbolPlans {
            if (!self.matches(input, commands)) return null;
            for (self.symbols[0..self.symbol_count]) |slot| {
                if (std.meta.eql(slot.key, key)) {
                    self.counters.symbol_hits += 1;
                    if (std.meta.eql(slot.plans, SymbolPlans{})) self.counters.symbol_empty_hits += 1;
                    return slot.plans;
                }
            }
            return null;
        }

        pub fn publishSymbols(self: *Self, input: []const u8, commands: []const command_plan.Command, key: Self.Key, value: SymbolPlans) bool {
            if (!self.matches(input, commands)) return false;
            for (self.symbols[0..self.symbol_count]) |slot| if (std.meta.eql(slot.key, key)) return false;
            if (self.symbol_count == self.symbols.len) {
                self.counters.symbol_capacity_refusals += 1;
                return false;
            }
            const bytes = symbolRequestedBytes(value) catch return self.refuse();
            if (!self.admit(bytes)) return false;
            self.symbols[self.symbol_count] = .{ .key = key, .plans = value };
            self.symbol_count += 1;
            self.counters.symbol_captures += 1;
            return true;
        }

        fn refuse(self: *Self) bool {
            self.counters.cap_refusals += 1;
            return false;
        }

        fn admit(self: *Self, bytes: usize) bool {
            const payload = std.math.add(usize, self.payload_bytes, bytes) catch return self.refuse();
            const requested = std.math.add(usize, @sizeOf(Self), payload) catch return self.refuse();
            if (requested > self.cap_bytes) return self.refuse();
            self.payload_bytes = payload;
            self.counters.retained_payload_bytes = payload;
            self.counters.retained_requested_bytes = requested;
            return true;
        }

        pub fn retainedRequestedBytes(self: *const Self) usize {
            return self.counters.retained_requested_bytes;
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            if (!self.active) return;
            if (self.joint_plan) |plan| plan.deinit(allocator);
            if (self.literal_plan) |plan| plan.deinit(allocator);
            for (self.symbols[0..self.symbol_count]) |*slot| slot.plans.deinit(allocator);
            self.joint_plan = null;
            self.literal_plan = null;
            self.joint_ready = false;
            self.literal_ready = false;
            self.symbol_count = 0;
            self.payload_bytes = 0;
            self.counters.retained_payload_bytes = 0;
            self.counters.retained_requested_bytes = 0;
            self.active = false;
        }
    };
}

pub fn sameLiteral(a: block.Plan, b: block.Plan) bool {
    return a.lengths.ptr == b.lengths.ptr and a.lengths.len == b.lengths.len and
        a.types.ptr == b.types.ptr and a.types.len == b.types.len and
        a.type_count == b.type_count and a.estimated_bits == b.estimated_bits;
}

pub fn planRequestedBytes(plan: block.Plan) error{IntegerOverflow}!usize {
    const lengths = std.math.mul(usize, plan.lengths.len, @sizeOf(u32)) catch return error.IntegerOverflow;
    return std.math.add(usize, lengths, plan.types.len) catch error.IntegerOverflow;
}

pub fn jointRequestedBytes(plan: literal.Plan) error{IntegerOverflow}!usize {
    const base = try planRequestedBytes(plan.block_plan);
    const modes = std.math.mul(usize, plan.context_modes.len, @sizeOf(u2)) catch return error.IntegerOverflow;
    const subtotal = std.math.add(usize, base, modes) catch return error.IntegerOverflow;
    return std.math.add(usize, subtotal, plan.context_map.len) catch error.IntegerOverflow;
}

pub fn symbolRequestedBytes(plans: SymbolPlans) error{IntegerOverflow}!usize {
    const command_bytes = if (plans.adaptive_command) |plan| try planRequestedBytes(plan) else 0;
    const distance_bytes = if (plans.adaptive_distance) |plan| try planRequestedBytes(plan) else 0;
    return std.math.add(usize, command_bytes, distance_bytes) catch error.IntegerOverflow;
}
