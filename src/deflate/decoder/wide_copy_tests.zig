//! Direct tests for the exact, non-overlapping wide-copy facade and core.
//! Every slice has exactly length bytes; backing storage checks also protect
//! the source and all bytes outside the destination span.
const std = @import("std");
const kernel = @import("shortcopy.zig");

const CopyKernel = enum { facade, at_least_16 };

fn minimumLength(comptime selected: CopyKernel) usize {
    return switch (selected) {
        .facade => 3,
        .at_least_16 => 16,
    };
}

inline fn runKernel(comptime selected: CopyKernel, destination: []u8, source: []const u8, length: usize) void {
    switch (selected) {
        .facade => kernel.copyWide(destination, source, length),
        .at_least_16 => kernel.copyWideAtLeast16(destination, source, length),
    }
}

/// A byte-at-a-time oracle independent of the kernel's width and dispatch.
fn scalarCopy(destination: []u8, source: []const u8) void {
    for (destination, 0..) |*byte, i| byte.* = source[i];
}

fn fill(bytes: []u8, salt: usize) void {
    for (bytes, 0..) |*byte, i| byte.* = @truncate(i * 131 + i / 7 + salt);
}

fn checkSeparateBuffers(comptime selected: CopyKernel) !void {
    var source: [512]u8 align(16) = undefined;
    fill(&source, 0x31);
    const original_source = source;

    for (minimumLength(selected)..259) |length| {
        for (0..16) |source_offset| {
            for (0..16) |destination_offset| {
                var actual: [512]u8 align(16) = undefined;
                fill(&actual, 0xa5);
                var expected = actual;
                const source_start = 32 + source_offset;
                const destination_start = 32 + destination_offset;
                scalarCopy(
                    expected[destination_start..][0..length],
                    original_source[source_start..][0..length],
                );

                runKernel(
                    selected,
                    actual[destination_start..][0..length],
                    source[source_start..][0..length],
                    length,
                );

                try std.testing.expectEqualSlices(u8, &expected, &actual);
                try std.testing.expectEqualSlices(u8, &original_source, &source);
            }
        }
    }
}

fn checkAdjacentSpans(comptime selected: CopyKernel) !void {
    for (minimumLength(selected)..259) |length| {
        for (0..16) |offset| {
            // Exercise both address orders without any source/destination
            // overlap. Each pair shares one backing allocation and one edge.
            for ([_]bool{ true, false }) |source_first| {
                var actual: [1024]u8 align(16) = undefined;
                fill(&actual, 0xa5);
                const first_start = 32 + offset;
                const second_start = first_start + length;
                const source_start = if (source_first) first_start else second_start;
                const destination_start = if (source_first) second_start else first_start;
                fill(actual[source_start..][0..length], 0x31);
                const before = actual;
                var expected = before;
                scalarCopy(
                    expected[destination_start..][0..length],
                    before[source_start..][0..length],
                );

                runKernel(
                    selected,
                    actual[destination_start..][0..length],
                    actual[source_start..][0..length],
                    length,
                );

                try std.testing.expectEqualSlices(u8, &expected, &actual);
                try std.testing.expectEqualSlices(
                    u8,
                    before[source_start..][0..length],
                    actual[source_start..][0..length],
                );
            }
        }
    }
}

pub fn check() !void {
    inline for ([_]CopyKernel{ .facade, .at_least_16 }) |selected| {
        try checkSeparateBuffers(selected);
        try checkAdjacentSpans(selected);
    }
}

test "wide copy exact contracts" {
    try check();
}
