const std = @import("std");
const encoder = @import("encoder.zig");
const model = @import("model.zig");
const ppmd8 = @import("../ppmd8.zig");

test "PPMd8 incremental encoder streams restart and cut-off models" {
    const allocator = std.testing.allocator;
    const input = ("incremental PPMd8 encoder payload\n" ** 113) ++
        ("0123456789abcdef\n" ** 97);
    inline for (.{ model.RestoreMethod.restart, .cut_off }) |restore_method| {
        const expected = try encoder.encodeAlloc(
            allocator,
            input,
            8,
            1024 * 1024,
            restore_method,
        );
        defer allocator.free(expected);
        var state = try ppmd8.IncrementalEncoder.initExactSize(
            allocator,
            8,
            1024 * 1024,
            restore_method,
            .{},
            input.len,
        );
        defer state.deinit();
        var encoded: std.ArrayList(u8) = .empty;
        defer encoded.deinit(allocator);
        var scratch: [7]u8 = undefined;
        var offset: usize = 0;
        while (offset < input.len) {
            const end = @min(input.len, offset + 3);
            const stepped = try state.step(input[offset..end], &scratch);
            offset += stepped.progress.input_read;
            try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
        }
        state.finish();
        while (true) {
            const stepped = try state.step("", &scratch);
            try encoded.appendSlice(allocator, scratch[0..stepped.progress.output_written]);
            if (stepped.status == .done) break;
        }
        try std.testing.expectEqualSlices(u8, expected, encoded.items);
        const decoded = try allocator.alloc(u8, input.len);
        defer allocator.free(decoded);
        const zip_payload = try zipPayload(allocator, encoded.items, restore_method);
        defer allocator.free(zip_payload);
        try ppmd8.decodeZipInto(
            allocator,
            zip_payload,
            decoded,
            1024 * 1024,
        );
        try std.testing.expectEqualSlices(u8, input, decoded);
    }
}

test "PPMd8 incremental encoder handles empty backpressure limits and reset" {
    const allocator = std.testing.allocator;
    var state = try ppmd8.IncrementalEncoder.init(
        allocator,
        8,
        1024 * 1024,
        .restart,
    );
    defer state.deinit();
    const blocked = try state.step("payload", &.{});
    try std.testing.expectEqual(.need_output, blocked.status);
    try std.testing.expectEqual(@as(usize, 0), blocked.progress.input_read);

    state.finish();
    var scratch: [16]u8 = undefined;
    while ((try state.step("", &scratch)).status != .done) {}
    try state.reset();
    try std.testing.expectEqual(@as(usize, 0), state.snapshot().input_read);

    var limited = try ppmd8.IncrementalEncoder.initWithOptions(
        allocator,
        8,
        1024 * 1024,
        .restart,
        .{ .max_input_len = 3 },
    );
    defer limited.deinit();
    _ = try limited.step("abc", &scratch);
    try std.testing.expectError(error.OutputLimitExceeded, limited.step("d", &scratch));

    var pledged = try ppmd8.IncrementalEncoder.initExactSize(
        allocator,
        8,
        1024 * 1024,
        .restart,
        .{},
        4,
    );
    defer pledged.deinit();
    _ = try pledged.step("abc", &scratch);
    pledged.finish();
    try std.testing.expectError(error.SizeMismatch, pledged.step("", &scratch));
}

fn zipPayload(
    allocator: std.mem.Allocator,
    encoded: []const u8,
    restore_method: model.RestoreMethod,
) ![]u8 {
    const result = try allocator.alloc(u8, encoded.len + 2);
    const properties = ppmd8.ZipProperties{
        .order = 8,
        .memory_size = 1024 * 1024,
        .restore_method = restore_method,
    };
    std.mem.writeInt(u16, result[0..2], try ppmd8.propertyValue(properties), .little);
    @memcpy(result[2..], encoded);
    return result;
}
