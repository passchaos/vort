pub const default_acceleration: i32 = 1;
pub const max_fast_acceleration: u32 = 65537;
pub const max_chain_depth: u8 = 16;

pub fn normalizeFastAcceleration(value: i32) u32 {
    return if (value <= 0) 1 else @intCast(@min(value, max_fast_acceleration));
}

/// Caller-owned attempted parser work. Counters survive output/allocation
/// failures and compressed-block fallback to stored bytes. They do not count
/// published output, CPU cycles or elapsed time. A profile never changes wire.
pub const FastEncodeProfile = struct {
    resolved_acceleration: u32 = 1,
    resolved_chain_depth: u8 = max_chain_depth,
    positions_inspected: u64 = 0,
    positions_skipped: u64 = 0,
    chain_candidates: u64 = 0,
    history_positions_seeded: u64 = 0,
    match_positions_seeded: u64 = 0,
    blocks_attempted: u64 = 0,
    max_skip_step: usize = 0,

    pub fn reset(self: *FastEncodeProfile) void {
        self.* = .{};
    }
    pub fn add(self: *FastEncodeProfile, comptime field: []const u8, amount: usize) void {
        @field(self, field) +|= @as(u64, @intCast(amount));
    }
    pub fn merge(self: *FastEncodeProfile, other: FastEncodeProfile) void {
        inline for (.{ "positions_inspected", "positions_skipped", "chain_candidates", "history_positions_seeded", "match_positions_seeded", "blocks_attempted" }) |field|
            @field(self, field) +|= @field(other, field);
        self.max_skip_step = @max(self.max_skip_step, other.max_skip_step);
        self.resolved_acceleration = other.resolved_acceleration;
        self.resolved_chain_depth = other.resolved_chain_depth;
    }
};

pub const BlockEncodeOptions = struct {
    /// Nonpositive values normalize to one; values above 65537 clamp. One
    /// preserves Vort's existing bytewise scan. Larger values skip positions
    /// after misses and gradually increase that stride until the next match.
    acceleration: i32 = default_acceleration,
    /// Independent bound on candidates inspected at each searched position.
    chain_depth: u8 = max_chain_depth,
    profile: ?*FastEncodeProfile = null,

    pub fn validate(self: BlockEncodeOptions) error{InvalidBlockPlan}!void {
        if (self.chain_depth > max_chain_depth) return error.InvalidBlockPlan;
    }
    pub fn resolve(self: BlockEncodeOptions) error{InvalidBlockPlan}!FastResolvedOptions {
        try self.validate();
        return .{ .acceleration = normalizeFastAcceleration(self.acceleration), .chain_depth = self.chain_depth };
    }
    pub fn work(self: BlockEncodeOptions) error{InvalidBlockPlan}!Work {
        const resolved = try self.resolve();
        return .{ .acceleration = resolved.acceleration, .chain_depth = resolved.chain_depth, .profile = self.profile };
    }
};

pub const FastResolvedOptions = struct {
    acceleration: u32,
    chain_depth: u8,
};

pub const Work = struct {
    acceleration: u32,
    chain_depth: u8,
    profile: ?*FastEncodeProfile,

    pub fn count(self: Work, comptime field: []const u8, amount: usize) void {
        if (self.profile) |p| p.add(field, amount);
    }
    pub fn begin(self: Work) void {
        if (self.profile) |p| {
            p.resolved_acceleration = self.acceleration;
            p.resolved_chain_depth = self.chain_depth;
            p.add("blocks_attempted", 1);
        }
    }
};

/// Only unsuccessful searches advance this schedule. Position arithmetic is
/// clamped to the remaining legal search range, including on 32-bit targets.
pub const MissSchedule = struct {
    acceleration: u32,
    misses: u64,
    pub fn init(acceleration: u32) MissSchedule {
        return .{ .acceleration = acceleration, .misses = 0 };
    }
    pub fn reset(self: *MissSchedule) void {
        self.misses = 0;
    }
    pub fn advance(self: *MissSchedule, position: usize, last_search: usize, options: Work) usize {
        const remaining = last_search - position + 1;
        const requested: u64 = if (self.acceleration == 1 or self.misses == 0) 1 else @as(u64, self.acceleration) +| ((self.misses - 1) >> 6);
        const step: usize = @intCast(@min(@as(u64, remaining), requested));
        self.misses +|= 1;
        options.count("positions_skipped", step - 1);
        if (options.profile) |p| p.max_skip_step = @max(p.max_skip_step, step);
        return position + step;
    }
};
