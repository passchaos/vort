const std = @import("std");
const command_plan = @import("command_plan.zig");
const compound_wire = @import("compound_wire.zig");
const shared_dictionary = @import("../shared_dictionary.zig");
const serialized_dictionary = @import("../serialized_dictionary.zig");
const static_dictionary = @import("../static_dictionary.zig");
const static_matcher = @import("static_dictionary_matcher.zig");
const compound_matcher = @import("compound_dictionary_matcher.zig");
const serialized_matcher = @import("serialized_dictionary_matcher.zig");
const options = @import("hq_options.zig");
const types = @import("hq_types.zig");
const working = @import("../../io/working_allocator.zig");

pub const Budget = working.WorkingAllocator;
pub const Error = std.mem.Allocator.Error || shared_dictionary.ValidationError || serialized_dictionary.Error || types.Error || error{WorkingMemoryLimitExceeded};

/// Dictionary coordinates retain every semantic tuple. copy_len is the raw
/// static word length; output_len is the transformed length that advances input.
pub const Candidate = struct {
    source: command_plan.Source,
    copy_len: usize,
    output_len: usize,
    address: usize,

    pub fn command(self: Candidate, insert_start: usize, insert_len: usize) command_plan.Command {
        return .{ .insert_start = insert_start, .insert_len = insert_len, .copy_len = self.copy_len, .has_copy = true, .source = self.source, .dictionary_address = self.address, .dictionary_output_len = if (self.source == .static) self.output_len else 0 };
    }
};

/// An explicit owner of managed dictionary indices, borrowing dictionary
/// bytes and a caller-owned budget. The budget must outlive this owner and
/// any candidate lists allocated from it. No process-wide shared index is used.
pub const Provider = struct {
    budget: *Budget,
    dictionary: shared_dictionary.Dictionary,
    profile: ?*options.HqProfile,
    builtin: ?static_matcher.CandidateIndex = null,
    compound: compound_matcher.Matcher,
    serialized: serialized_matcher.Matcher,

    pub fn init(budget: *Budget, dictionary: shared_dictionary.Dictionary, profile: ?*options.HqProfile) Error!Provider {
        return initInternal(budget, dictionary, profile) catch |err| {
            if (err == error.OutOfMemory and budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
            return err;
        };
    }
    fn initInternal(budget: *Budget, dictionary: shared_dictionary.Dictionary, profile: ?*options.HqProfile) Error!Provider {
        try dictionary.validate();
        if (!dictionary.hasSerializedStatic() and static_matcher.CandidateIndex.requiredWorkingMemory() > budget.limit - @min(budget.live, budget.limit))
            return error.WorkingMemoryLimitExceeded;
        const a = budget.allocator();
        var result: Provider = .{ .budget = budget, .dictionary = dictionary, .profile = profile, .compound = compound_matcher.Matcher.init(a), .serialized = serialized_matcher.Matcher.init(a) };
        errdefer result.deinit();
        defer if (profile) |p| p.recordPeak(budget.peak);
        try result.compound.prepare(dictionary);
        if (dictionary.hasSerializedStatic()) {
            try result.serialized.prepare(dictionary.serialized.?);
        } else {
            result.builtin = try static_matcher.CandidateIndex.init(a, budget.limit - @min(budget.live, budget.limit));
        }
        return result;
    }
    pub fn deinit(self: *Provider) void {
        if (self.builtin) |*index| index.deinit();
        self.compound.deinit();
        self.serialized.deinit();
        self.* = undefined;
    }
    pub fn dictionarySize(self: *const Provider) usize {
        return self.compound.dictionarySize();
    }
    pub fn wireDistance(self: *const Provider, candidate: Candidate, source: types.Source, input_position: usize) Error!usize {
        return compound_wire.wireDistance(candidate.source, candidate.address, try source.maxBackward(input_position), self.dictionarySize());
    }

    /// Append a deterministic full frontier without clearing existing entries.
    /// Existing list storage and its deinit must use budget.allocator(), too.
    /// Any failure restores the original list length; work counters retain real
    /// lookups. No candidate truncation is substituted for a resource error.
    pub fn appendCandidates(self: *const Provider, input: []const u8, position: usize, context: usize, max_len: usize, output: *std.ArrayList(Candidate)) Error!void {
        const original_len = output.items.len;
        errdefer output.items.len = original_len;
        defer if (self.profile) |p| p.recordPeak(self.budget.peak);
        return self.appendInternal(input, position, context, max_len, output) catch |err| {
            if (err == error.OutOfMemory and self.budget.last_failure_was_limit) return error.WorkingMemoryLimitExceeded;
            return err;
        };
    }
    fn appendInternal(self: *const Provider, input: []const u8, position: usize, context: usize, max_len: usize, output: *std.ArrayList(Candidate)) Error!void {
        if (position > input.len) return error.InvalidBlockPlan;
        const available = @min(max_len, input.len - position);
        if (available == 0) return;
        const tail = input[position..][0..available];
        const a = self.budget.allocator();
        var static_visitor = StaticVisitor{ .allocator = a, .output = output, .profile = self.profile };
        if (self.profile) |p| p.add("static_probes", 1);
        if (self.builtin) |*index| {
            try index.visitMatches(tail, &static_visitor);
        } else {
            var scratch: [serialized_dictionary.max_transformed_word_len]u8 = undefined;
            var visitor = SerializedVisitor{ .allocator = a, .output = output, .profile = self.profile };
            try self.serialized.visitMatches(context, tail, &scratch, &visitor);
        }
        if (self.dictionarySize() != 0 and available >= 2) {
            if (self.profile) |p| p.add("compound_probes", 1);
            var visitor = CompoundVisitor{ .allocator = a, .output = output, .profile = self.profile };
            try self.compound.visitMatches(input, position, available, &visitor);
        }
    }
};

const StaticVisitor = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(Candidate),
    profile: ?*options.HqProfile,

    pub fn visit(self: *StaticVisitor, match: static_dictionary.Match) std.mem.Allocator.Error!bool {
        if (self.profile) |p| p.add("static_candidates", 1);
        try self.output.append(self.allocator, .{ .source = .static, .copy_len = match.copy_len, .output_len = match.output_len, .address = match.address });
        return true;
    }
};

const SerializedVisitor = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(Candidate),
    profile: ?*options.HqProfile,

    pub fn visit(self: *SerializedVisitor, match: serialized_dictionary.Match) std.mem.Allocator.Error!bool {
        if (self.profile) |p| p.add("static_candidates", 1);
        try self.output.append(self.allocator, .{ .source = .static, .copy_len = match.copy_len, .output_len = match.output_len, .address = match.address });
        return true;
    }
};

const CompoundVisitor = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(Candidate),
    profile: ?*options.HqProfile,

    pub fn visit(self: *CompoundVisitor, match: compound_matcher.Match) std.mem.Allocator.Error!bool {
        if (self.profile) |p| p.add("compound_candidates", 1);
        try self.output.append(self.allocator, .{ .source = .compound, .copy_len = match.length, .output_len = match.length, .address = match.address });
        return true;
    }
};

test {
    _ = @import("hq_dictionary/options_tests.zig");
    _ = @import("hq_dictionary/types_tests.zig");
    _ = @import("hq_dictionary/provider_tests.zig");
}
