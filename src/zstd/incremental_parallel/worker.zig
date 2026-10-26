//! A private codec operation over immutable queue-owned bytes.
const std = @import("std");
const memory = @import("../../io/threaded_working_memory.zig");
const views = @import("../parallel/job_view.zig");

pub const Worker = @import("../parallel/worker.zig").Worker;
pub const NativeSpawner = @import("../parallel/worker.zig").NativeSpawner;

pub fn Result(comptime Codec: type) type {
    return struct {
        block_count: usize = 0,
        work: Codec.Profile = .{},
        first_error: ?Codec.Error = null,
    };
}

pub fn encode(comptime Codec: type, slot: *memory.Slot, output: *std.ArrayList(u8), view: views.View, options: Codec.Options, dictionary: ?Codec.Dictionary) Result(Codec) {
    var result: Result(Codec) = .{};
    slot.clearFailure();
    Codec.encodeOwnedJob(slot.allocator(), output, view, options, dictionary, &result.work) catch |err| {
        result.first_error = slot.mapError(err);
        return result;
    };
    result.block_count = Codec.blockCount(output.items) catch |err| {
        result.first_error = slot.mapError(err);
        return result;
    };
    return result;
}
