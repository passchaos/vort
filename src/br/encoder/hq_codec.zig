//! Brotli HQ format state. Owned heap objects have stable addresses so a
//! caller can move the encoder without invalidating budget allocator contexts.
const std = @import("std");
const options = @import("hq_options.zig");
const prices = @import("hq_parser/prices.zig");
const dictionary = @import("hq_dictionary.zig");
const shared_dictionary = @import("../shared_dictionary.zig");
const types = @import("hq_types.zig");
const tree = @import("hq_tree.zig");
pub const alias = @import("hq_codec/alias.zig");
pub const Model = prices.Model;
pub const Budget = dictionary.Budget;
pub const Error = dictionary.Error;
pub const publication = @import("hq_codec/transaction.zig");
pub const huffman_model = @import("hq_codec/huffman_model.zig");
pub const native = @import("hq_codec/native.zig");
pub const wire = @import("hq_codec/wire.zig");
pub const history = @import("hq_codec/history.zig");
pub const frame = @import("hq_codec/frame.zig");
pub const legacy = @import("hq_codec/legacy.zig");

pub const State = struct {
    budget: ?*Budget = null,
    provider: ?dictionary.Provider = null,
    model: ?*Model = null,
    matcher: ?tree.Matcher = null,
    alias_snapshot: ?alias.Snapshot = null,
    frame_offset: u64 = 0,
    raw_prefixes: [shared_dictionary.max_raw_prefixes][]const u8 = @splat(&.{}),
    raw_prefix_count: usize = 0,
    serialized_dictionary: ?*const @import("../serialized_dictionary.zig").Dictionary = null,
    configured_literal_mode: u2 = 0,

    pub fn deinit(self: *State) void {
        if (self.budget) |budget| {
            const a = budget.allocator();
            if (self.provider) |*provider| provider.deinit();
            if (self.matcher) |*matcher| matcher.deinit(a);
            if (self.model) |model| a.destroy(model);
            if (self.alias_snapshot) |*snapshot| snapshot.deinit();
            const backing = budget.backing;
            backing.destroy(budget);
        }
        self.* = .{};
    }

    pub fn ensureBudget(self: *State, allocator: std.mem.Allocator, limit: usize) Error!void {
        if (self.budget) |budget| {
            if (budget.live > limit) return error.WorkingMemoryLimitExceeded;
            budget.limit = limit;
            return;
        }
        if (limit < @sizeOf(Budget)) return error.WorkingMemoryLimitExceeded;
        const budget = try allocator.create(Budget);
        budget.* = Budget.init(allocator, limit);
        budget.live = @sizeOf(Budget);
        budget.peak = budget.live;
        self.budget = budget;
    }

    pub fn ensure(self: *State, allocator: std.mem.Allocator, resolved: options.Resolved, shared: shared_dictionary.Dictionary, profile: ?*options.HqProfile, literal_mode: u2) Error!void {
        if (self.model) |model| {
            if (!std.meta.eql(model.distance_parameters, resolved.distance_parameters) or model.format != resolved.format or
                self.configured_literal_mode != literal_mode or self.raw_prefix_count != shared.raw_prefixes.len or
                self.serialized_dictionary != shared.serialized) return error.InvalidBlockPlan;
            for (self.raw_prefixes[0..self.raw_prefix_count], shared.raw_prefixes) |prior, current|
                if (prior.ptr != current.ptr or prior.len != current.len) return error.InvalidBlockPlan;
            try self.ensureBudget(allocator, resolved.max_working_memory);
            if (self.provider) |*provider| provider.profile = profile;
            return;
        }
        const created_budget = self.budget == null;
        const original = self.*;
        try self.ensureBudget(allocator, resolved.max_working_memory);
        errdefer if (created_budget) {
            self.deinit();
            self.* = original;
        };
        const budget = self.budget.?;
        defer if (profile) |p| p.recordPeak(budget.peak);
        var provider = try dictionary.Provider.init(budget, shared, profile);
        errdefer provider.deinit();
        const model = budget.allocator().create(Model) catch |err| {
            if (budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
            return err;
        };
        model.* = Model.initForFormat(resolved.distance_parameters, literal_mode, resolved.format);
        self.provider = provider;
        self.model = model;
        self.raw_prefix_count = shared.raw_prefixes.len;
        @memcpy(self.raw_prefixes[0..shared.raw_prefixes.len], shared.raw_prefixes);
        self.serialized_dictionary = shared.serialized;
        self.configured_literal_mode = literal_mode;
    }

    /// The first block seeds once. Later passes fork this detached numeric
    /// checkpoint and rebind their current source instead of replaying history.
    pub fn prepareMatcher(self: *State, source: types.Source, resolved: options.Resolved, profile: ?*options.HqProfile) !void {
        if (self.matcher != null) return;
        const budget = self.budget orelse return error.InvalidBlockPlan;
        var matcher = try tree.Matcher.init(budget.allocator(), source, resolved, profile);
        matcher.detachSource();
        self.matcher = matcher;
    }

    pub fn forkMatcher(self: *const State, source: types.Source, resolved: options.Resolved, profile: ?*options.HqProfile) !tree.Matcher {
        const budget = self.budget orelse return error.InvalidBlockPlan;
        const original = self.matcher orelse return error.InvalidBlockPlan;
        var branch = try original.fork(budget.allocator(), resolved.max_working_memory, profile);
        errdefer branch.deinit(budget.allocator());
        try branch.rebindSource(budget.allocator(), source, resolved, profile);
        return branch;
    }

    /// Prepare plaintext index advancement before publication. Stored blocks
    /// use this too while retaining the entering entropy model and distance ring.
    pub fn nextMatcher(self: *const State, source: types.Source, resolved: options.Resolved, profile: ?*options.HqProfile) !tree.Matcher {
        var branch = try self.forkMatcher(source, resolved, profile);
        errdefer branch.deinit(self.budget.?.allocator());
        try branch.advanceTo(source.input.len);
        branch.detachSource();
        return branch;
    }
};
