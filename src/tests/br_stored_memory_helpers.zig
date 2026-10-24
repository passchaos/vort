//! Independent stored API drivers and wires captured only from git archive
//! 3703184975920d44ed3e781f0e562f45cfe31fa5, never pending production.
const std = @import("std");
const br = @import("../br.zig");
pub const TrackingAllocator = @import("br_total_memory_helpers.zig").TrackingAllocator;
pub const total = @import("../br/encoder/total_budget.zig");
pub const plain = "stored memory | abcdefghabcdefghXabcdefgh | tail\n" ** 2;
pub const metadata = "stored-meta";
pub const Setting = enum { standard10, standard16, large25, large30 };
pub const Api = enum { contiguous, chunks, empty, reusable, incremental };
pub const Wire = struct { setting: Setting, api: Api, hex: []const u8 };
pub const frozen_wires = [_]Wire{
    .{ .setting = .standard10, .api = .contiguous, .hex = "214b0173746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .standard10, .api = .chunks, .hex = "214b0173746f7265642d6d65746180000873746f726564206d656d6f7279207c2061380108626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d400108656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .standard10, .api = .empty, .hex = "a101" },
    .{ .setting = .standard10, .api = .reusable, .hex = "214b0173746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .standard10, .api = .incremental, .hex = "214b0173746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .standard16, .api = .contiguous, .hex = "2c0573746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .standard16, .api = .chunks, .hex = "2c0573746f7265642d6d65746180000873746f726564206d656d6f7279207c2061380108626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d400108656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .standard16, .api = .empty, .hex = "06" },
    .{ .setting = .standard16, .api = .reusable, .hex = "2c0573746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .standard16, .api = .incremental, .hex = "2c0573746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .large25, .api = .contiguous, .hex = "1199a50073746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .large25, .api = .chunks, .hex = "1199a50073746f7265642d6d65746180000873746f726564206d656d6f7279207c2061380108626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d400108656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .large25, .api = .empty, .hex = "11d9" },
    .{ .setting = .large25, .api = .reusable, .hex = "1199a50073746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .large25, .api = .incremental, .hex = "1199a50073746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .large30, .api = .contiguous, .hex = "119ea50073746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .large30, .api = .chunks, .hex = "119ea50073746f7265642d6d65746180000873746f726564206d656d6f7279207c2061380108626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d400108656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .large30, .api = .empty, .hex = "11de" },
    .{ .setting = .large30, .api = .reusable, .hex = "119ea50073746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
    .{ .setting = .large30, .api = .incremental, .hex = "119ea50073746f7265642d6d65746108030873746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a73746f726564206d656d6f7279207c2061626364656667686162636465666768586162636465666768207c207461696c0a03" },
};
pub const Boundary = struct { incremental: bool, len: usize, sha256: []const u8 };
pub const frozen_boundary = [_]Boundary{
    .{ .incremental = false, .len = 65542, .sha256 = "c333df45d1e451af906c515d4ba10a76df52dea7f0ddced0dedf5e73fe2d2be0" },
    .{ .incremental = true, .len = 65544, .sha256 = "69a01b5ac8932be58a4dbec38e421f676cce0c94b98742fe92f011dea8a2b618" },
};
pub fn options(setting: Setting) br.StoredStreamOptions {
    return switch (setting) {
        .standard10 => .{ .window_bits = 10, .metadata = metadata },
        .standard16 => .{ .window_bits = 16, .metadata = metadata },
        .large25 => .{ .large_window = true, .window_bits = 25, .metadata = metadata },
        .large30 => .{ .large_window = true, .window_bits = 30, .metadata = metadata },
    };
}
pub fn chunks() [4][]const u8 {
    return .{ plain[0..17], "", plain[17..57], plain[57..] };
}
pub fn frozenAlloc(a: std.mem.Allocator, sample: Wire) ![]u8 {
    const result = try a.alloc(u8, sample.hex.len / 2);
    errdefer a.free(result);
    _ = try std.fmt.hexToBytes(result, sample.hex);
    return result;
}
pub fn frozen(setting: Setting, api: Api) Wire {
    for (frozen_wires) |sample| if (sample.setting == setting and sample.api == api) return sample;
    unreachable;
}
pub fn expectWire(actual: []const u8, setting: Setting, api: Api) !void {
    const expected = try frozenAlloc(std.testing.allocator, frozen(setting, api));
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualSlices(u8, expected, actual);
}
pub fn untouched(bytes: []const u8) !void {
    for (bytes) |b| try std.testing.expectEqual(@as(u8, 0xa5), b);
}
pub fn expectProfile(profile: br.EncodeMemoryProfile, tracked: *const TrackingAllocator, live: usize) !void {
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(tracked.peak, profile.peak_requested_bytes);
    try std.testing.expectEqual(live, profile.live_requested_bytes);
}
pub fn decode(actual: []const u8, expected: []const u8, large: bool) !void {
    const decoded = try br.decodeStreamAllocWithOptions(std.testing.allocator, actual, .{ .allow_large_window = large });
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, expected, decoded);
}
/// Collect only through ordinary QA backing; this allocation is not encoder work.
/// Check physical step progress against both wide cumulative and frame counters.
pub fn drive(a: std.mem.Allocator, encoder: *br.IncrementalStoredStreamEncoder, input: []const u8, input_quota: usize, output_quota: usize) ![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(a);
    const initial = encoder.snapshot();
    var offset: usize = @intCast(initial.stream_input);
    var finishing = initial.finishing;
    var output: [257]u8 = undefined;
    for (0..input.len * 16 + 4096) |call| {
        if (offset == input.len and !finishing) {
            try encoder.finish();
            finishing = true;
        }
        const end = @min(input.len, offset + input_quota);
        @memset(&output, 0xa5);
        const before = encoder.snapshot();
        const result = try encoder.step(input[offset..end], output[0..if (call % 7 == 0) 0 else output_quota]);
        const after = encoder.snapshot();
        try std.testing.expectEqual(@as(br.IncrementalStoredStreamEncoder.Counter, result.progress.input_read), after.stream_input - before.stream_input);
        try std.testing.expectEqual(@as(br.IncrementalStoredStreamEncoder.Counter, result.progress.input_read), after.input_read - before.input_read);
        try std.testing.expectEqual(@as(br.IncrementalStoredStreamEncoder.Counter, result.progress.output_written), after.stream_output - before.stream_output);
        try std.testing.expectEqual(@as(br.IncrementalStoredStreamEncoder.Counter, result.progress.output_written), after.output_written - before.output_written);
        try untouched(output[result.progress.output_written..]);
        offset += result.progress.input_read;
        try bytes.appendSlice(a, output[0..result.progress.output_written]);
        if (result.status == .done) return bytes.toOwnedSlice(a);
    }
    return error.TestUnexpectedResult;
}
pub fn drainFlush(a: std.mem.Allocator, encoder: *br.IncrementalStoredStreamEncoder, bytes: *std.ArrayList(u8)) !void {
    var output: [11]u8 = undefined;
    for (0..4096) |_| {
        const result = try encoder.step("", &output);
        try std.testing.expectEqual(@as(usize, 0), result.progress.input_read);
        try bytes.appendSlice(a, output[0..result.progress.output_written]);
        if (result.status == .need_input) return;
    }
    return error.TestUnexpectedResult;
}
pub fn boundaryInput() [65537]u8 {
    var result: [65537]u8 = undefined;
    for (&result, 0..) |*b, i| b.* = @truncate(i *% 37 +% (i >> 8));
    return result;
}
