//! Value-only admission before an incremental encoder mutates any borrowed bytes.
const std = @import("std");
const stable = @import("../../decode/stable_output.zig");

pub const Error = error{InvalidBlockPlan};

pub const Admission = struct {
    input: []const u8,
    output: []const u8,
    // Three public profiles plus a retained allocator profile. Two captured
    // dictionaries each contribute content, standard bytes and prepared state.
    observers: [4][]const u8 = @splat(&.{}),
    reads: [6][]const u8 = @splat(&.{}),
    observer_count: usize = 0,
    read_count: usize = 0,

    pub fn init(input: []const u8, output: []u8, options: anytype) Error!Admission {
        try disjoint(input, output);
        var admission: Admission = .{ .input = input, .output = output };
        if (comptime @hasField(@TypeOf(options), "frame")) {
            try admission.frameObservers(options.frame);
            if (options.parallel.profile) |profile| try admission.observer(std.mem.asBytes(profile));
        } else try admission.frameObservers(options);
        return admission;
    }

    fn frameObservers(self: *Admission, options: anytype) Error!void {
        if (comptime @hasField(@TypeOf(options), "memory_profile"))
            if (options.memory_profile) |profile| try self.observer(std.mem.asBytes(profile));
        if (comptime @hasField(@TypeOf(options), "control_profile"))
            if (options.control_profile) |profile| try self.observer(std.mem.asBytes(profile));
    }

    /// A retained allocator may still publish to its previous profile binding.
    pub fn observer(self: *Admission, bytes: []const u8) Error!void {
        try disjoint(bytes, self.input);
        try disjoint(bytes, self.output);
        for (self.observers[0..self.observer_count]) |existing| {
            if (existing.ptr == bytes.ptr and existing.len == bytes.len) return;
            try disjoint(bytes, existing);
        }
        for (self.reads[0..self.read_count]) |read| try disjoint(bytes, read);
        if (self.observer_count == self.observers.len) return error.InvalidBlockPlan;
        self.observers[self.observer_count] = bytes;
        self.observer_count += 1;
    }

    pub fn dictionary(self: *Admission, value: anytype) Error!void {
        if (comptime @hasField(@TypeOf(value), "content")) try self.readBorrow(value.content);
        if (comptime @hasField(@TypeOf(value), "standard_bytes"))
            if (value.standard_bytes) |bytes| try self.readBorrow(bytes);
        if (comptime @hasField(@TypeOf(value), "prepared"))
            if (value.prepared) |prepared| try self.readBorrow(std.mem.asBytes(prepared));
    }

    fn readBorrow(self: *Admission, bytes: []const u8) Error!void {
        if (bytes.len == 0) return;
        try disjoint(self.output, bytes);
        for (self.observers[0..self.observer_count]) |observer_bytes| try disjoint(observer_bytes, bytes);
        for (self.reads[0..self.read_count]) |existing|
            if (existing.ptr == bytes.ptr and existing.len == bytes.len) return;
        if (self.read_count == self.reads.len) return error.InvalidBlockPlan;
        self.reads[self.read_count] = bytes;
        self.read_count += 1;
    }

    /// Every allocation's complete capacity is private mutable storage, even
    /// after reset or when its logical length is zero.
    pub fn owned(self: *const Admission, bytes: []const u8) Error!void {
        try disjoint(self.input, bytes);
        try disjoint(self.output, bytes);
        for (self.observers[0..self.observer_count]) |observer_bytes| try disjoint(observer_bytes, bytes);
        for (self.reads[0..self.read_count]) |read| try disjoint(read, bytes);
    }

    pub fn list(self: *const Admission, value: anytype) Error!void {
        try self.owned(std.mem.sliceAsBytes(value.allocatedSlice()));
    }

    pub fn parallelState(self: *const Admission, state: anytype) Error!void {
        try self.list(state.values);
        try self.list(state.literals);
        try self.list(state.candidate);
        inline for (std.meta.fields(@TypeOf(state.scratch))) |field|
            if (comptime field.type != bool) try self.list(@field(state.scratch, field.name));
    }
};

fn disjoint(first: []const u8, second: []const u8) Error!void {
    if (stable.overlaps(first, second)) return error.InvalidBlockPlan;
}
