const std = @import("std");
const archive_module = @import("../../archive.zig");
const devices_module = @import("../devices.zig");
const source_module = @import("../../../io/source.zig");
const format = @import("../../format.zig");
const fixture = @import("device_helpers.zig");

test "EROFS device byte regions preserve unaligned offsets and enforce complete spans" {
    const allocator = std.testing.allocator;
    var owner = try fixture.modern(allocator, 0, 16, 3);
    defer owner.deinit(allocator);
    const archive = try archive_module.Archive.initWithDevices(owner.image, &.{owner.blob});
    var devices = devices_module.Devices([]const u8){ .primary = .{ .slice = owner.image }, .devices = &.{owner.blob}, .superblock = archive.superblock };
    const region = try devices.resolveAt(0, fixture.mapping_start * @as(u64, 4096) + 3, 4096);
    try std.testing.expectEqual(@as(u64, 3), region.start);
    try std.testing.expectEqualSlices(u8, owner.blob, region.input.slice);
    const last = fixture.mapping_start * @as(u64, 4096) + owner.blob.len - 1;
    _ = try devices.resolveAt(0, last, 1);
    try std.testing.expectError(error.InvalidErofs, devices.resolveAt(0, last, 2));
    try std.testing.expectError(error.IntegerOverflow, devices.resolveAt(1, std.math.maxInt(u64), 2));
    try std.testing.expectError(error.InvalidErofs, devices.resolveAt(2, 0, 1));
    try std.testing.expectEqual(@as(u64, owner.blob.len), (try devices.resolveAt(1, owner.blob.len, 0)).start);
    devices.devices = &.{};
    try std.testing.expectError(error.ErofsMissingDevice, devices.resolveAt(0, fixture.mapping_start * @as(u64, 4096), 1));
}

test "EROFS zero unified addresses stay explicit-only and keep primary byte reads" {
    const allocator = std.testing.allocator;
    var owner = try fixture.modern(allocator, 0, 16, 3);
    defer owner.deinit(allocator);
    const table = @as(usize, format.readU16(owner.image, 1112)) * 128;
    std.mem.writeInt(u32, owner.image[table + 68 ..][0..4], 0, .little);
    fixture.refresh(owner.image);
    const archive = try archive_module.Archive.initWithDevices(owner.image, &.{owner.blob});
    const devices = devices_module.Devices([]const u8){ .primary = .{ .slice = owner.image }, .devices = &.{owner.blob}, .superblock = archive.superblock };
    const primary = try devices.resolveAt(0, 3, 4);
    try std.testing.expectEqualSlices(u8, owner.image, primary.input.slice);
    const external = try devices.resolveAt(1, 3, 4);
    try std.testing.expectEqualSlices(u8, owner.blob, external.input.slice);
    try std.testing.expectError(error.TruncatedFrame, archive_module.Archive.initWithDevices(owner.image, &.{owner.blob[0 .. owner.blob.len - 1]}));
}

test "EROFS Source device byte mapping retains u64 offsets without blob allocation" {
    const allocator = std.testing.allocator;
    var owner = try fixture.modern(allocator, 0, 16, 0);
    defer owner.deinit(allocator);
    const table = @as(usize, format.readU16(owner.image, 1112)) * 128;
    std.mem.writeInt(u32, owner.image[table + 64 ..][0..4], 0, .little);
    std.mem.writeInt(u16, owner.image[table + 72 ..][0..2], 1, .little);
    fixture.refresh(owner.image);
    const base = try archive_module.Archive.init(owner.image);
    const Virtual = struct {
        offset: u64 = 0,
        fn readAt(raw: *anyopaque, offset: u64, output: []u8) error{SourceReadFailed}!usize {
            const self: *@This() = @ptrCast(@alignCast(raw));
            self.offset = offset;
            @memset(output, 'V');
            return output.len;
        }
    };
    var input = Virtual{};
    const source = source_module.Source{ .context = &input, .len = (@as(u64, 1) << 32) * 4096, .read_at = Virtual.readAt };
    const devices = devices_module.Devices(source_module.Source){ .primary = .{ .slice = owner.image }, .devices = &.{source}, .superblock = base.superblock };
    try devices.validate();
    const global = (@as(u64, fixture.mapping_start) + (@as(u64, 1) << 31)) * 4096 + 7;
    const region = try devices.resolveAt(0, global, 8);
    var output: [8]u8 = undefined;
    try region.input.readAt(region.start, &output);
    try std.testing.expectEqual((@as(u64, 1) << 31) * 4096 + 7, input.offset);
    try std.testing.expectEqualStrings("VVVVVVVV", &output);
}

test "EROFS primary byte regions reject data beyond the declared image even with trailing bytes" {
    const allocator = std.testing.allocator;
    const original = try @import("partial_helpers.zig").fixtureAlloc(allocator, 0);
    defer allocator.free(original);
    const bytes = try allocator.alloc(u8, original.len + 4096);
    defer allocator.free(bytes);
    @memcpy(bytes[0..original.len], original);
    @memset(bytes[original.len..], 'X');
    const archive = try archive_module.Archive.init(bytes);
    const devices = devices_module.Devices([]const u8){ .primary = .{ .slice = bytes }, .devices = &.{}, .superblock = archive.superblock };
    try std.testing.expectEqual(@as(u64, original.len), (try devices.resolveAt(0, original.len, 0)).start);
    try std.testing.expectError(error.TruncatedFrame, devices.resolveAt(0, original.len, 1));
}
