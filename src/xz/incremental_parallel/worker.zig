//! One captured Block codec operation and stable worker storage. Scheduling,
//! caller output and Index publication belong to the queue and stream owner.
const std = @import("std");
const writer = @import("../writer.zig");
const settings = @import("../../lzma/encode_options.zig");
const memory = @import("memory.zig");
const types = @import("types.zig");

pub const Worker = struct {
    slot: memory.Slot,
    thread: ?std.Thread = null,
};

pub const NativeSpawner = struct {
    pub fn spawn(_: *NativeSpawner, config: std.Thread.SpawnConfig, comptime function: anytype, args: anytype) std.Thread.SpawnError!std.Thread {
        return std.Thread.spawn(config, function, args);
    }
};

pub const Result = struct {
    record: writer.BlockRecord = undefined,
    work: settings.EncodeWorkProfile = .{},
    failure: ?types.Error = null,
};

/// Statistics remain private to the result. The captured options have already
/// had external profile pointers removed; disabled work counting stays off.
pub fn encode(slot: *memory.Slot, plain: []const u8, output: *std.ArrayList(u8), captured_options: writer.EncodeOptions, payload_encoding: writer.PayloadEncoding, track_work: bool) Result {
    var result: Result = .{};
    var options = captured_options;
    if (track_work) {
        if (options.match_options) |*matching| matching.profile = &result.work;
    }
    slot.clearFailure();
    result.record = writer.appendBlock(slot.allocator(), output, plain, options, payload_encoding) catch |err| {
        result.failure = slot.mapError(err);
        return result;
    };
    return result;
}
