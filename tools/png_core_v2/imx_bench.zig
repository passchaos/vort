const std = @import("std");
const imx = @import("imx");
const Counter = @import("counter.zig").Counter;
const Implementation = enum { old, stream };
fn imageFor(allocator: std.mem.Allocator, raw: []u8, width: usize, height: usize, color: []const u8) !imx.DynamicImage {
    if (std.mem.eql(u8, color, "l8")) return .{ .luma8 = .{ .allocator = allocator, .width = width, .height = height, .data = std.mem.bytesAsSlice(imx.Luma8, raw) } };
    if (std.mem.eql(u8, color, "rgb8")) return .{ .rgb8 = .{ .allocator = allocator, .width = width, .height = height, .data = std.mem.bytesAsSlice(imx.Rgb8, raw) } };
    if (std.mem.eql(u8, color, "rgba8")) return .{ .rgba8 = .{ .allocator = allocator, .width = width, .height = height, .data = std.mem.bytesAsSlice(imx.Rgba8, raw) } };
    return error.InvalidColor;
}
fn once(allocator: std.mem.Allocator, image: imx.DynamicImage, implementation: Implementation, filter: imx.PngFilter, workspace_peak: ?*usize) ![]u8 {
    var encoded: std.Io.Writer.Allocating = .init(allocator);
    errdefer encoded.deinit();
    const options = imx.PngEncodeOptions{ .filter = filter, .compression = .ultrafast };
    if (implementation == .old) {
        try imx.codecs.png.encodeCompressedWithOptions(allocator, image, options, &encoded.writer);
    } else {
        const writer = try imx.PngRowWriter.create(allocator, &encoded.writer, .{ .width = image.width(), .height = image.height(), .bit_depth = 8, .color_type = switch (image) {
            .luma8 => 0,
            .rgb8 => 2,
            .rgba8 => 6,
            else => unreachable,
        } }, options, .{ .image = .unlimited(), .max_workspace_bytes = 64 * 1024 * 1024, .idat_chunk_bytes = 4096 });
        defer writer.destroy();
        const row = image.bytes().len / image.height();
        for (0..image.height()) |y| try writer.writeRow(image.bytes()[y * row ..][0..row]);
        _ = try writer.finish();
        if (workspace_peak) |peak| peak.* = writer.workspaceStats().peak_bytes;
    }
    return encoded.toOwnedSlice() catch return error.OutOfMemory;
}
pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse return error.MissingMode;
    const impl = std.meta.stringToEnum(Implementation, args.next() orelse return error.MissingImplementation) orelse return error.InvalidImplementation;
    const path = args.next() orelse return error.MissingRaw;
    const width = try std.fmt.parseInt(usize, args.next() orelse return error.MissingWidth, 10);
    const height = try std.fmt.parseInt(usize, args.next() orelse return error.MissingHeight, 10);
    const color = args.next() orelse return error.MissingColor;
    const filter_name = args.next() orelse return error.MissingFilter;
    const filter: imx.PngFilter = if (std.mem.eql(u8, filter_name, "up")) .up else .adaptive;
    const iterations = try std.fmt.parseInt(usize, args.next() orelse return error.MissingIterations, 10);
    const destination = args.next() orelse return error.MissingOutput;
    if (args.next() != null) return error.InvalidArgs;
    const raw = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(raw);
    const image = try imageFor(init.gpa, raw, width, height, color);
    if (image.bytes().len != width * height * image.colorType().bytesPerPixel()) return error.InvalidRaw;
    if (std.mem.eql(u8, mode, "dump")) {
        const output = try once(init.gpa, image, impl, filter, null);
        defer init.gpa.free(output);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = destination, .data = output });
        std.debug.print("{{\"encoded_bytes\":{d}}}\n", .{output.len});
        return;
    }
    if (std.mem.eql(u8, mode, "memory")) {
        var counter = Counter{ .backing = init.gpa };
        var work_peak: usize = 0;
        const output = try once(counter.allocator(), image, impl, filter, &work_peak);
        const size = output.len;
        counter.allocator().free(output);
        std.debug.print("{{\"encoded_bytes\":{d},\"heap_peak_requested\":{d},\"allocations\":{d},\"allocated_total\":{d},\"heap_live_after_destroy\":{d},\"bounded_workspace_peak\":{d}}}\n", .{ size, counter.peak, counter.allocations, counter.total, counter.live, work_peak });
        return;
    }
    if (!std.mem.eql(u8, mode, "time") or iterations == 0) return error.InvalidMode;
    init.gpa.free(try once(init.gpa, image, impl, filter, null));
    var total: usize = 0;
    const started = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        std.mem.doNotOptimizeAway(raw.ptr);
        const output = try once(init.gpa, image, impl, filter, null);
        total +%= output.len;
        std.mem.doNotOptimizeAway(output.ptr);
        init.gpa.free(output);
    }
    const elapsed = started.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds;
    std.mem.doNotOptimizeAway(total);
    std.debug.print("{{\"elapsed_ns\":{d},\"iterations\":{d},\"output_bytes_total\":{d},\"input_bytes\":{d}}}\n", .{ elapsed, iterations, total, raw.len });
}
