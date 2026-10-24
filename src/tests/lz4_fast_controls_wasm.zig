//! Actual public LZ4 controls exercised through exported wasm functions.
const std = @import("std");
const vort = @import("vort");
const a = std.heap.page_allocator;
var measured: [5]vort.Lz4FastEncodeProfile = @splat(.{});

fn unmatched() [512]u8 {
    // Four-byte windows are unique: each contains consecutive pair indices.
    var bytes: [512]u8 = undefined;
    for (0..256) |index| {
        bytes[index * 2] = 0;
        bytes[index * 2 + 1] = @intCast(index);
    }
    return bytes;
}

fn rawRoundtrip(bytes: []const u8, input: []const u8) bool {
    const restored = vort.lz4DecodeBlockAlloc(a, bytes, input.len) catch return false;
    defer a.free(restored);
    return std.mem.eql(u8, input, restored);
}

export fn lz4FastWasmDefaultSmoke() callconv(.c) u32 {
    const input = "LZ4 Wasm default acceleration abcdefghabcdefgh!\n" ** 3;
    const legacy = vort.lz4EncodeBlockAlloc(a, input) catch return 10;
    defer a.free(legacy);
    var profile: vort.Lz4FastEncodeProfile = .{};
    const options: vort.Lz4BlockEncodeOptions = .{ .acceleration = 1, .profile = &profile };
    const explicit = vort.lz4EncodeBlockWithOptionsAlloc(a, input, options) catch return 11;
    defer a.free(explicit);
    if (!std.mem.eql(u8, legacy, explicit) or !rawRoundtrip(explicit, input)) return 12;
    if (profile.resolved_acceleration != 1 or profile.resolved_chain_depth != vort.lz4NativeMaxChainDepth or profile.blocks_attempted != 1 or profile.positions_inspected == 0) return 13;
    measured[0] = profile;
    var normalized: vort.Lz4FastEncodeProfile = .{};
    const zero = vort.lz4EncodeBlockWithOptionsAlloc(a, input, .{ .acceleration = 0, .profile = &normalized }) catch return 14;
    defer a.free(zero);
    if (!std.mem.eql(u8, legacy, zero) or normalized.resolved_acceleration != 1) return 15;
    const minimum = vort.lz4EncodeBlockWithOptionsAlloc(a, input, .{ .acceleration = std.math.minInt(i32) }) catch return 16;
    defer a.free(minimum);
    if (!std.mem.eql(u8, legacy, minimum)) return 17;
    const default_frame = vort.lz4EncodePureFrameWithOptionsAlloc(a, input, .{}) catch return 18;
    defer a.free(default_frame);
    profile.reset();
    const frame = vort.lz4EncodePureFrameWithOptionsAlloc(a, input, .{ .acceleration = 1, .profile = &profile }) catch return 19;
    defer a.free(frame);
    if (!std.mem.eql(u8, default_frame, frame) or profile.resolved_acceleration != 1) return 20;
    const restored = vort.lz4DecodeFrameAlloc(a, frame) catch return 21;
    defer a.free(restored);
    return if (std.mem.eql(u8, input, restored)) 0 else 22;
}

export fn lz4FastWasmMissSmoke() callconv(.c) u32 {
    const input = unmatched();
    var profile: vort.Lz4FastEncodeProfile = .{};
    const encoded = vort.lz4EncodeBlockWithOptionsAlloc(a, &input, .{ .acceleration = 8, .chain_depth = 0, .profile = &profile }) catch return 30;
    defer a.free(encoded);
    if (!rawRoundtrip(encoded, &input)) return 31;
    // Independent finite miss witness: 501 searchable positions, first stride
    // one then sixty-two strides eight and a final clipped stride four.
    if (profile.resolved_acceleration != 8 or profile.resolved_chain_depth != 0 or profile.positions_inspected != 64 or profile.positions_skipped != 437 or profile.max_skip_step != 8) return 32;
    if (profile.chain_candidates != 0 or profile.match_positions_seeded != 0 or profile.history_positions_seeded != 0 or profile.blocks_attempted != 1) return 33;
    measured[1] = profile;
    const quiet = vort.lz4EncodeBlockWithOptionsAlloc(a, &input, .{ .acceleration = 8, .chain_depth = 0 }) catch return 34;
    defer a.free(quiet);
    if (!std.mem.eql(u8, encoded, quiet)) return 35;
    profile.reset();
    const frame_options: vort.Lz4NativeFrameOptions = .{ .acceleration = 8, .chain_depth = 0, .profile = &profile };
    const frame = vort.lz4EncodePureFrameWithOptionsAlloc(a, &input, frame_options) catch return 36;
    defer a.free(frame);
    if (profile.resolved_acceleration != 8 or profile.positions_inspected != 64 or profile.positions_skipped != 437 or profile.max_skip_step != 8 or profile.blocks_attempted != 1) return 37;
    measured[2] = profile;
    const quiet_frame = vort.lz4EncodePureFrameWithOptionsAlloc(a, &input, .{ .acceleration = 8, .chain_depth = 0 }) catch return 38;
    defer a.free(quiet_frame);
    if (!std.mem.eql(u8, frame, quiet_frame)) return 39;
    const restored = vort.lz4DecodeFrameAlloc(a, frame) catch return 40;
    defer a.free(restored);
    return if (std.mem.eql(u8, &input, restored)) 0 else 41;
}

export fn lz4FastWasmMaximumPrefixSmoke() callconv(.c) u32 {
    const input = unmatched();
    var profile: vort.Lz4FastEncodeProfile = .{};
    const maximum = vort.lz4EncodeBlockWithOptionsAlloc(a, &input, .{ .acceleration = std.math.maxInt(i32), .chain_depth = 0, .profile = &profile }) catch return 50;
    defer a.free(maximum);
    if (!rawRoundtrip(maximum, &input)) return 51;
    // The 65537 requested skip is clipped before usize addition on wasm32.
    if (profile.resolved_acceleration != 65537 or profile.positions_inspected != 2 or profile.positions_skipped != 499 or profile.max_skip_step != 500 or profile.blocks_attempted != 1) return 52;
    measured[3] = profile;
    const clamped = vort.lz4EncodeBlockWithOptionsAlloc(a, &input, .{ .acceleration = 65537, .chain_depth = 0 }) catch return 53;
    defer a.free(clamped);
    if (!std.mem.eql(u8, maximum, clamped)) return 54;
    var prefix: [128]u8 = undefined;
    for (&prefix, 0..) |*byte, index| byte.* = @intCast(index);
    const prefixed_input = prefix[0..96];
    profile.reset();
    const options: vort.Lz4BlockEncodeOptions = .{ .acceleration = std.math.maxInt(i32), .chain_depth = 16, .profile = &profile };
    const encoded = vort.lz4EncodeBlockWithPrefixAndOptionsAlloc(a, prefixed_input, &prefix, options) catch return 55;
    defer a.free(encoded);
    if (profile.resolved_acceleration != 65537 or profile.resolved_chain_depth != 16 or profile.history_positions_seeded == 0 or profile.match_positions_seeded == 0 or profile.chain_candidates == 0 or profile.blocks_attempted != 1) return 56;
    measured[4] = profile;
    const quiet = vort.lz4EncodeBlockWithPrefixAndOptionsAlloc(a, prefixed_input, &prefix, .{ .acceleration = std.math.maxInt(i32), .chain_depth = 16 }) catch return 57;
    defer a.free(quiet);
    if (!std.mem.eql(u8, encoded, quiet)) return 58;
    const restored = vort.lz4DecodeBlockWithPrefixAlloc(a, encoded, prefixed_input.len, &prefix) catch return 59;
    defer a.free(restored);
    return if (std.mem.eql(u8, prefixed_input, restored)) 0 else 60;
}

/// Report only the actual measurements captured by the preceding public runs.
export fn lz4FastWasmProfileValue(index: u32, field: u32) callconv(.c) u64 {
    if (index >= measured.len) return std.math.maxInt(u64);
    const profile = measured[index];
    return switch (field) {
        0 => profile.resolved_acceleration,
        1 => profile.resolved_chain_depth,
        2 => profile.positions_inspected,
        3 => profile.positions_skipped,
        4 => profile.chain_candidates,
        5 => profile.history_positions_seeded,
        6 => profile.match_positions_seeded,
        7 => profile.blocks_attempted,
        8 => profile.max_skip_step,
        else => std.math.maxInt(u64),
    };
}

export fn lz4FastWasmPointerBits() callconv(.c) u32 {
    return @bitSizeOf(usize);
}
