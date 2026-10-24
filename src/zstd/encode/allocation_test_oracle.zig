//! Independent requested-heap accounting for allocation regression tests.
const std = @import("std");
const builtin = @import("builtin");
const lz77 = @import("../../lz77.zig");

pub const Ledger = @import("../../tests/zstd_stream_counter_helpers.zig").TrackingAllocator;
pub const Error = error{IntegerOverflow};

const BeamState = @typeInfo(@TypeOf(@as(lz77.RepBeamScratch, .{}).states.items)).pointer.child;

/// Physical geometry used by the independently audited native 64-bit pins.
pub fn sameNativeAuditGeometry() bool {
    return builtin.os.tag == .linux and builtin.cpu.arch == .x86_64 and
        @sizeOf(*const u8) == 8 and @sizeOf(usize) == 8 and std.atomic.cache_line == 128 and
        @sizeOf(lz77.Token) == 6 and @sizeOf(BeamState) == 16;
}

/// Physical geometry used by the independently audited x86 32-bit pins.
pub fn sameX86AuditGeometry() bool {
    return builtin.os.tag == .linux and builtin.cpu.arch == .x86 and
        @sizeOf(*const u8) == 4 and @sizeOf(usize) == 4 and std.atomic.cache_line == 64 and
        @sizeOf(lz77.Token) == 6 and @sizeOf(BeamState) == 16;
}

/// Bytes requested when an ArrayList must grow to at least `minimum` items.
/// This follows Zig 0.16's geometric rule, including its saturating capacity
/// addition. The caller must establish that a capacity increase is needed;
/// `ensureTotalCapacity` itself does nothing when the existing capacity fits.
pub fn growRequestBytes(comptime T: type, minimum: usize) Error!usize {
    if (@sizeOf(T) == 0) return 0;
    const initial = @max(1, std.atomic.cache_line / @sizeOf(T));
    const capacity = minimum +| (minimum / 2 + initial);
    return std.math.mul(usize, capacity, @sizeOf(T)) catch error.IntegerOverflow;
}

/// Initial requested bytes for the four cold arrays in an accepted nonempty
/// repeat-beam probe. The fixture must fit the reversed-token initial reserve;
/// later growth of that array is deliberately not included in this formula.
/// Fixed index heads and parser metadata remain caller-owned state.
pub fn redundantRepeatBeamProbeBytes(input_len: usize) Error!usize {
    const positions = std.math.add(usize, input_len, 1) catch return error.IntegerOverflow;
    const states = std.math.mul(usize, positions, 2) catch return error.IntegerOverflow;
    var bytes: usize = 0;
    // RepBeamIndex.build: prev.resize(input.len).
    bytes = try add(bytes, try growRequestBytes(u16, input_len));
    // optimalRepBeamPlanZstdReuse: states.resize(2 * (input.len + 1)).
    bytes = try add(bytes, try growRequestBytes(BeamState, states));
    // optimalRepBeamPlanZstdReuse: lengths.resize(input.len + 1).
    bytes = try add(bytes, try growRequestBytes(u8, positions));
    // finishRepBeamPlan: reversed.ensureTotalCapacity(min(input.len, 4096)).
    return add(bytes, try growRequestBytes(lz77.Token, @min(input_len, 4096)));
}

fn add(first: usize, second: usize) Error!usize {
    return std.math.add(usize, first, second) catch error.IntegerOverflow;
}

test "Zstd allocation oracle redundant beam formula matches independent requested heap" {
    const input = "abcd" ** (16 * 1024 / 4);
    const expected = try redundantRepeatBeamProbeBytes(input.len);
    var ledger = Ledger.init(std.testing.allocator);
    ledger.force_copy_reallocation = true;
    {
        var scratch: lz77.RepBeamScratch = .{};
        defer scratch.deinit(ledger.allocator());
        _ = try lz77.optimalRepBeamPlanZstdReuse(&scratch, ledger.allocator(), input);
        try std.testing.expectEqual(@as(usize, 4), ledger.alloc_attempts);
        try std.testing.expectEqual(expected, ledger.allocated_bytes);
        try std.testing.expectEqual(expected, ledger.live);
        try std.testing.expectEqual(expected, ledger.peak);
        const token_capacity = (try growRequestBytes(lz77.Token, @min(input.len, 4096))) / @sizeOf(lz77.Token);
        try std.testing.expectEqual(token_capacity, scratch.reversed.capacity);
        try std.testing.expect(scratch.reversed.items.len <= token_capacity);
    }
    try std.testing.expectEqual(@as(usize, 0), ledger.live);
    try std.testing.expectEqual(ledger.allocated_bytes, ledger.freed_bytes);
    // Reproduce the independently pinned legacy fixture using source-derived
    // shapes. The formula above supplies each target's physical request sizes.
    if (sameNativeAuditGeometry())
        try std.testing.expectEqual(@as(usize, 897_583), expected);
}

test "Zstd allocation oracle checks requested byte and probe shape overflow" {
    try std.testing.expectEqual(@as(usize, 0), try growRequestBytes(void, 37));
    try std.testing.expectEqual(std.math.maxInt(usize), try growRequestBytes(u8, std.math.maxInt(usize)));
    try std.testing.expectError(error.IntegerOverflow, growRequestBytes(u16, std.math.maxInt(usize)));
    try std.testing.expectError(error.IntegerOverflow, redundantRepeatBeamProbeBytes(std.math.maxInt(usize)));
    try std.testing.expectError(error.IntegerOverflow, redundantRepeatBeamProbeBytes(std.math.maxInt(usize) / 2));
}
