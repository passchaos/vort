//! Atomic one-shot publication surrounds the bounded parallel block pipeline.
//! The budget owns all temporary heap; caller destination storage is separate.
const std = @import("std");
const writer = @import("../writer.zig");
const memory = @import("memory.zig");
const types = @import("types.zig");
const encoder = @import("encoder.zig");

pub fn encodeAppend(
    caller_allocator: std.mem.Allocator,
    out: *std.ArrayList(u8),
    input: []const u8,
    options: writer.EncodeOptions,
    payload_encoding: writer.PayloadEncoding,
    parallel: types.Options,
) !usize {
    return encode(caller_allocator, .{ .append = out }, input, options, payload_encoding, parallel);
}

pub fn encodeInto(
    allocator: std.mem.Allocator,
    output: []u8,
    input: []const u8,
    options: writer.EncodeOptions,
    payload_encoding: writer.PayloadEncoding,
    parallel: types.Options,
) !usize {
    return encode(allocator, .{ .into = output }, input, options, payload_encoding, parallel);
}

const Destination = union(enum) { append: *std.ArrayList(u8), into: []u8 };

fn encode(
    caller_allocator: std.mem.Allocator,
    destination: Destination,
    input: []const u8,
    options: writer.EncodeOptions,
    payload_encoding: writer.PayloadEncoding,
    parallel: types.Options,
) !usize {
    // Reject an impossible admission before allocating or starting workers.
    if (@min(options.block_size, input.len) > parallel.max_inflight_bytes)
        return error.WorkingMemoryLimitExceeded;
    if (parallel.profile) |profile| profile.* = .{};
    var budget = memory.Budget.init(caller_allocator, parallel.max_working_memory);
    var coordinator: memory.Slot = .{ .budget = &budget };
    defer if (parallel.profile) |profile| {
        profile.peak_requested_bytes = budget.peakRequestedBytes();
        profile.live_requested_bytes = budget.liveRequestedBytes();
    };
    const allocator = coordinator.allocator();
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);
    var records: std.ArrayList(writer.BlockRecord) = .empty;
    defer records.deinit(allocator);
    writer.appendStreamHeader(allocator, &encoded, options.check) catch |err|
        return coordinator.mapError(err);
    try encoder.appendBlocks(&coordinator, &encoded, &records, input, options, payload_encoding, parallel);
    writer.appendStreamEnd(allocator, &encoded, options.check, records.items) catch |err|
        return coordinator.mapError(err);

    // Workers are joined and input has been consumed before a caller-owned
    // allocation can relocate aliased input. Capacity admission is atomic.
    switch (destination) {
        .append => |out| {
            try out.ensureUnusedCapacity(caller_allocator, encoded.items.len);
            out.appendSliceAssumeCapacity(encoded.items);
        },
        .into => |output| {
            if (output.len < encoded.items.len) return error.OutputTooSmall;
            @memcpy(output[0..encoded.items.len], encoded.items);
        },
    }
    return encoded.items.len;
}
