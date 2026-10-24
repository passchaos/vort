const std = @import("std");
const br = @import("../br.zig");
const Model = @import("../br/encoder/hq_parser.zig").Model;

test "Brotli HQ bridge legacy inspection measures static physical distance and strict shape" {
    const parameters = br.HqDistanceParameters.init(0, 15);
    const input = "abcdabcdtime ";
    // RFC length pair (insert4, copy4), direct distance4, followed by word0
    // 'time' with transform1 (suffix space). The static distance is 8+1024+1.
    const encoded = try br.IncrementalTestSupport.encodeHqCommandPlan(std.testing.allocator, input, &.{
        .{ .insert_start = 0, .insert_len = 4, .copy_len = 4, .has_copy = true, .distance = 4, .hq_encoding = .{ .command_symbol = 162, .distance_code = 19, .distance_encoding = .{ .symbol = 19 }, .distance_parameters = parameters } },
        .{ .insert_start = 8, .insert_len = 0, .copy_len = 4, .has_copy = true, .source = .static, .dictionary_address = 1024, .dictionary_output_len = 5, .hq_encoding = .{ .command_symbol = 130, .distance_code = 1048, .distance_encoding = .{ .symbol = 46, .extra = 253, .extra_bits = 8 }, .distance_parameters = parameters } },
    }, .{ .window_bits = 16, .distance_parameters = parameters });
    defer std.testing.allocator.free(encoded.bytes);
    var options: br.PlannedStreamChunksOptions = .{ .quality = 10, .window_bits = 16, .hq = .{ .block_len = 32, .distance_parameters = parameters } };
    const emitted = (try br.IncrementalTestSupport.inspectHqLegacyWire(std.testing.allocator, encoded.bytes, options, input.len)).?;
    try std.testing.expectEqual(@as(usize, 1033), emitted.emitted_max_distance);
    try std.testing.expectEqual(@as(u64, 2), emitted.emitted_commands);
    try std.testing.expectEqual(@as(u64, 1), emitted.emitted_static_commands);
    try std.testing.expectEqual(@as(u64, 9), emitted.emitted_copy_bytes);
    options.hq.?.distance_parameters = br.HqDistanceParameters.init(0, 0);
    try std.testing.expect((try br.IncrementalTestSupport.inspectHqLegacyWire(std.testing.allocator, encoded.bytes, options, input.len)) == null);
    options.hq.?.distance_parameters = parameters;
    options.hq.?.block_len = input.len - 1;
    try std.testing.expect((try br.IncrementalTestSupport.inspectHqLegacyWire(std.testing.allocator, encoded.bytes, options, input.len)) == null);
}

const GuardModelFailure = struct {
    backing: std.mem.Allocator,
    profile: *const br.HqProfile,
    models_after_first_parse: usize = 0,
    armed: bool = true,
    failed: bool = false,

    fn allocator(self: *GuardModelFailure) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, ret: usize) ?[*]u8 {
        const self: *GuardModelFailure = @ptrCast(@alignCast(raw));
        if (self.armed and len == @sizeOf(Model) and self.profile.passes == 1) {
            self.models_after_first_parse += 1;
            // The first is the q10 artifact's actual model. The second is
            // q11's working model, after the q10 safeguard has completed.
            if (self.models_after_first_parse == 2) {
                self.failed = true;
                return null;
            }
        }
        return self.backing.rawAlloc(len, alignment, ret);
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) bool {
        const self: *GuardModelFailure = @ptrCast(@alignCast(raw));
        return self.backing.rawResize(memory, alignment, len, ret);
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, ret: usize) ?[*]u8 {
        const self: *GuardModelFailure = @ptrCast(@alignCast(raw));
        return self.backing.rawRemap(memory, alignment, len, ret);
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ret: usize) void {
        const self: *GuardModelFailure = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, ret);
    }
};

test "Brotli HQ bridge q11 model allocation failure reports the public effective quality" {
    var profile: br.HqProfile = .{};
    var failure: GuardModelFailure = .{ .backing = std.testing.allocator, .profile = &profile };
    var encoder = br.IncrementalPlannedStreamEncoder.initWithOptions(failure.allocator(), .{ .stream = .{ .quality = 11, .window_bits = 22, .hq = .{ .block_len = 32, .profile = &profile } } });
    defer encoder.deinit();
    const input = [_]u8{'a'} ** 32;
    _ = try encoder.step(&input, &.{});
    try encoder.finish();
    const before = encoder.snapshot();
    try std.testing.expectError(error.OutOfMemory, encoder.step(&.{}, &.{}));
    try std.testing.expect(failure.failed);
    try std.testing.expectEqual(@as(usize, 2), failure.models_after_first_parse);
    try std.testing.expectEqual(@as(u64, 1), profile.passes);
    try std.testing.expectEqual(@as(u8, 11), profile.effective.?.quality);
    try std.testing.expectEqualDeep(br.HqProfile.Emitted{}, profile.emitted());
    try std.testing.expectEqualDeep(before, encoder.snapshot());
    failure.armed = false;
    var result: std.ArrayList(u8) = .empty;
    defer result.deinit(std.testing.allocator);
    var output: [64]u8 = undefined;
    while (true) {
        const step = try encoder.step(&.{}, &output);
        try result.appendSlice(std.testing.allocator, output[0..step.progress.output_written]);
        if (step.status == .done) break;
    }
    const decoded = try br.decodeStreamAllocExactSize(std.testing.allocator, result.items, input.len);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, &input, decoded);
    try std.testing.expectEqual(@as(u8, 11), profile.effective.?.quality);
}
