const std = @import("std");
const plan_module = @import("../plan.zig");
const clusters = @import("../clusters.zig");
const cursor_module = @import("../cluster_cursor.zig");
const options_module = @import("../options.zig");
const tree = @import("../tree.zig");
const source_module = @import("../../../io/source.zig");

test "EROFS cluster cursor preserves prefix payload bytes indexes and progress" {
    const allocator = std.testing.allocator;
    var data: [16384 + 619]u8 = undefined;
    var random = std.Random.DefaultPrng.init(0x434c_5553_5445_5253);
    random.random().bytes(data[0..8192]);
    @memcpy(data[8192..16384], data[0..8192]);
    @memcpy(data[16384..], data[0..619]);
    for ([_]options_module.Compression{ .lz4, .lzma, .deflate, .zstandard }) |compression| {
        for ([_]?usize{ null, 4096, 8192, 12288 }) |capacity| {
            const options = options_module.Options{ .compression = compression, .compression_extent_size = 32768, .max_pcluster_size = capacity };
            var reference = try plan_module.Plan.init(allocator, &.{.{ .path = "data", .data = &data }}, options, false, true);
            defer reference.deinit();
            var input = source_module.SliceSource{ .bytes = &data };
            var source = input.source();
            source.max_read_size = 127;
            var actual = try plan_module.Plan.init(allocator, &.{.{ .path = "data", .source = source }}, options, false, true);
            defer actual.deinit();
            const expected_node = &reference.filesystem.nodes[1];
            const node = &actual.filesystem.nodes[1];
            try clusters.prepareNode(allocator, expected_node, &reference.encoder.?, options.compression_extent_size, options.max_pcluster_size);
            var cursor = try cursor_module.Cursor.init(allocator, node, &actual.encoder.?, options.compression_extent_size, options.max_pcluster_size);
            defer cursor.deinit();
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(allocator);
            var previous: usize = 0;
            while (try cursor.next()) |group| {
                try std.testing.expect(cursor.position > previous);
                previous = cursor.position;
                try output.appendNTimes(allocator, 0, group.leading_zeroes);
                try output.appendSlice(allocator, group.bytes);
                try output.appendNTimes(allocator, 0, group.trailing_zeroes);
                try std.testing.expectEqual(output.items.len, cursor.physical_bytes);
            }
            try std.testing.expectEqual(data.len, cursor.position);
            try std.testing.expectEqualSlices(u8, expected_node.compressed_data.?, output.items);
            try std.testing.expectEqualDeep(expected_node.compressed_indexes.?, node.compressed_indexes.?);
            try std.testing.expectEqual(expected_node.compressed_block_count, node.compressed_block_count);
        }
    }
}

test "EROFS cluster cursor frees source scratch and codec allocation failures" {
    const allocator = std.testing.allocator;
    const data = "cursor source allocation failure\n" ** 600;
    const Test = struct {
        fn run(work: std.mem.Allocator, bytes: []const u8) !void {
            var input = source_module.SliceSource{ .bytes = bytes };
            var plan = try plan_module.Plan.init(work, &.{.{ .path = "data", .source = input.source() }}, .{ .compression = .lzma, .compression_extent_size = 32768, .max_pcluster_size = 4096 }, false, true);
            defer plan.deinit();
            var cursor = try cursor_module.Cursor.init(work, &plan.filesystem.nodes[1], &plan.encoder.?, 32768, 4096);
            defer cursor.deinit();
            while (try cursor.next()) |_| {}
        }
    };
    try std.testing.checkAllAllocationFailures(allocator, Test.run, .{data});
}
