//! Profiling only: production row filter and ultrafast core without PNG sink.
const std = @import("std");
const imx = @import("imx");
const vort = @import("vort");
const Discard = struct {
    bytes: usize = 0,
    pub fn feedFiltered(self: *Discard, input: []const u8) imx.ImageError!void {
        self.bytes += input.len;
        std.mem.doNotOptimizeAway(input.ptr);
    }
};
fn coreOnce(allocator: std.mem.Allocator, input: []const u8, fragment: usize) !usize {
    var encoder = vort.ZlibIncrementalPngUltraFastEncoder.initExactSize(allocator, .{ .max_input_len = input.len }, input.len);
    defer encoder.deinit();
    var buffer: [4096]u8 = undefined;
    var used: usize = 0;
    var total: usize = 0;
    var offset: usize = 0;
    while (offset < input.len) {
        const end = @min(input.len, offset + fragment);
        while (offset < end) {
            const next = try encoder.step(input[offset..end], buffer[used..]);
            offset += next.progress.input_read;
            used += next.progress.output_written;
            if (used == buffer.len) {
                std.mem.doNotOptimizeAway(&buffer);
                total += used;
                used = 0;
            }
        }
    }
    encoder.finish();
    while (true) {
        const next = try encoder.step(&.{}, buffer[used..]);
        used += next.progress.output_written;
        if (used == buffer.len) {
            std.mem.doNotOptimizeAway(&buffer);
            total += used;
            used = 0;
        }
        if (next.status == .done) break;
    }
    std.mem.doNotOptimizeAway(&buffer);
    return total + used;
}
pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const stage = args.next() orelse return error.Arg;
    const path = args.next() orelse return error.Arg;
    const width = try std.fmt.parseInt(usize, args.next() orelse return error.Arg, 10);
    const height = try std.fmt.parseInt(usize, args.next() orelse return error.Arg, 10);
    const color = args.next() orelse return error.Arg;
    const filter_name = args.next() orelse return error.Arg;
    const iterations = try std.fmt.parseInt(usize, args.next() orelse return error.Arg, 10);
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(input);
    var total: usize = 0;
    if (std.mem.eql(u8, stage, "core")) {
        const fragment = input.len / height;
        _ = try coreOnce(init.gpa, input, fragment);
        const started = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| total += try coreOnce(init.gpa, input, fragment);
        const ns = started.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds;
        std.mem.doNotOptimizeAway(total);
        std.debug.print("{{\"stage\":\"core+Adler+row-partition+4KiB-output\",\"elapsed_ns\":{d},\"iterations\":{d},\"output_total\":{d}}}\n", .{ ns, iterations, total });
        return;
    }
    const row_len = input.len / height;
    var output: std.Io.Writer.Allocating = .init(init.gpa);
    defer output.deinit();
    const writer = try imx.PngRowWriter.create(init.gpa, &output.writer, .{ .width = width, .height = height, .bit_depth = 8, .color_type = if (std.mem.eql(u8, color, "rgba8")) 6 else if (std.mem.eql(u8, color, "rgb8")) 2 else 0 }, .{ .filter = if (std.mem.eql(u8, filter_name, "up")) .up else .adaptive, .compression = .ultrafast }, .{ .image = .unlimited(), .max_workspace_bytes = 64 * 1024 * 1024, .idat_chunk_bytes = 4096 });
    defer writer.destroy();
    var discard = Discard{};
    const started = std.Io.Clock.awake.now(init.io);
    for (0..iterations) |_| {
        writer.rows.?.reset();
        for (0..height) |y| {
            @memcpy(writer.rows.?.current(), input[y * row_len ..][0..row_len]);
            try writer.rows.?.submit(&discard, row_len);
        }
    }
    const ns = started.durationTo(std.Io.Clock.awake.now(init.io)).nanoseconds;
    std.mem.doNotOptimizeAway(discard.bytes);
    std.debug.print("{{\"stage\":\"row-copy+selection+materialization-reused-scratch\",\"elapsed_ns\":{d},\"iterations\":{d},\"filtered_bytes\":{d}}}\n", .{ ns, iterations, discard.bytes });
}
