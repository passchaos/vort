//! Stable allocator slots and private codec work, independent of the public
//! frame owner. Codec output remains isolated until ordered publication.
const std = @import("std");
const memory = @import("../../io/threaded_working_memory.zig");

pub const Worker = struct {
    slot: memory.Slot,
    thread: ?std.Thread = null,
};

pub const NativeSpawner = struct {
    pub fn spawn(_: *NativeSpawner, config: std.Thread.SpawnConfig, comptime function: anytype, args: anytype) std.Thread.SpawnError!std.Thread {
        return std.Thread.spawn(config, function, args);
    }
};

pub fn Result(comptime Codec: type) type {
    return struct {
        block_count: usize = 0,
        work: Codec.Profile = .{},
        first_error: ?Codec.Error = null,
    };
}

pub fn encode(comptime Codec: type, slot: *memory.Slot, output: *std.ArrayList(u8), input: []const u8, start: usize, end: usize, options: Codec.Options, dictionary: ?Codec.Dictionary) Result(Codec) {
    var result: Result(Codec) = .{};
    slot.clearFailure();
    Codec.encodeJob(slot.allocator(), output, input, start, end, options, dictionary, &result.work) catch |err| {
        result.first_error = slot.mapError(err);
        return result;
    };
    result.block_count = Codec.blockCount(output.items) catch |err| {
        result.first_error = slot.mapError(err);
        return result;
    };
    return result;
}
