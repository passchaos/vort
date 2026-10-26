//! Only coordinator public touchpoints write borrowed caller observations.
const std = @import("std");
const types = @import("types.zig");

pub fn capture(comptime Codec: type, self: anytype) void {
    self.work_baseline = if (self.options.frame.control_profile) |profile| profile.* else .{};
    Codec.profileOptions(self.config.frame_options, &self.work_baseline);
}

pub fn workValue(comptime Codec: type, self: anytype) Codec.Profile {
    return Codec.publishWork(self.work_baseline, self.queue.workSnapshot(), self.adapter_work, self.delivered_emitted);
}

pub fn emittedDelta(comptime Codec: type, before: Codec.Profile.Emitted, after: Codec.Profile.Emitted) Codec.Profile.Emitted {
    var delta: Codec.Profile.Emitted = .{};
    inline for (std.meta.fields(Codec.Profile.Emitted)) |field| {
        if (comptime std.mem.eql(u8, field.name, "max_distance"))
            @field(delta, field.name) = @field(after, field.name)
        else
            @field(delta, field.name) = @field(after, field.name) - @field(before, field.name);
    }
    return delta;
}

pub fn mergeDelivered(comptime Codec: type, self: anytype) void {
    var value: Codec.Profile = .{};
    value.restoreEmitted(self.delivered_emitted);
    value.mergeEmitted(self.front_emitted);
    self.delivered_emitted = value.emitted();
}

pub fn snapshot(self: anytype) types.Snapshot {
    var result = self.queue.snapshot();
    const heap = self.control.snapshot();
    result.profile.live_requested_bytes = heap.live_requested_bytes;
    result.profile.peak_requested_bytes = heap.peak_requested_bytes;
    result.retained_front_capacity = self.state.front.capacity;
    result.control_bytes = heap.control_bytes;
    result.failed = self.failure != null or result.failed;
    if (self.failure) |err| {
        result.last_error = err;
    } else if (self.last_call_error) |err| {
        result.last_error = err;
    }
    result.last_step_progress = self.last_step_progress;
    return result;
}

pub fn publish(comptime Codec: type, self: anytype) void {
    const observed = snapshot(self);
    publishObserved(Codec, self, observed);
}

pub fn publishObserved(comptime Codec: type, self: anytype, observed: types.Snapshot) void {
    if (self.options.parallel.profile) |destination| destination.* = observed.profile;
    if (self.options.frame.control_profile) |destination| destination.* = workValue(Codec, self);
    if (self.options.frame.memory_profile) |destination| {
        const heap = self.control.snapshot();
        destination.record(observed.profile.live_requested_bytes, heap.limit);
        destination.peak_requested_bytes = @max(destination.peak_requested_bytes, observed.profile.peak_requested_bytes);
    }
}
