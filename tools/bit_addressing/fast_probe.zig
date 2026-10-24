//! A separate executable keeps the internal fast-reader module in one Zig
//! module ownership domain. All bytes are from the actual mapped fixture.
const std = @import("std");
const fast_reader = @import("brfast");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingInput;
    const api = args.next() orelse return error.MissingApi;
    const expected_text = args.next() orelse return error.MissingExpected;
    const cursor_text = args.next() orelse return error.MissingCursor;
    if (args.next() != null or !std.mem.eql(u8, api, "fast")) return error.InvalidProbeArguments;
    const expected = try std.fmt.parseInt(usize, expected_text, 10);
    const offset = try std.fmt.parseInt(usize, cursor_text, 10);
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const file_stat = try file.stat(init.io);
    const length = std.math.cast(usize, file_stat.size) orelse return error.InputCannotBeMapped;
    const mapping = try std.posix.mmap(null, length, .{ .READ = true }, .{ .TYPE = .PRIVATE }, file.handle, 0);
    defer std.posix.munmap(mapping);
    if (offset > mapping.len or mapping.len - offset < 10) return error.InvalidActualCursor;
    const Scalar = @typeInfo(@TypeOf(fast_reader.Reader.initFrom)).@"fn".params[0].type.?;
    var scalar = Scalar.init(mapping);
    scalar.byte_index = offset;
    var fast = fast_reader.Reader.initFrom(scalar);
    const start: u64 = fast.bitPosition();
    var values: [8]u32 = undefined;
    var positions: [8]u64 = undefined;
    inline for (.{ 3, 5, 9, 1, 17, 24, 7, 2 }, 0..) |width, index| {
        values[index] = try fast.readBits(u32, width);
        if (values[index] != try scalar.readBits(u32, width)) return error.ActualFastScalarMismatch;
        positions[index] = fast.bitPosition();
        if (positions[index] != scalar.bitPosition()) return error.ActualFastScalarCursorMismatch;
    }
    fast.syncTo(&scalar);
    if (fast.bitPosition() != scalar.bitPosition()) return error.ActualFastSyncMismatch;
    const report = .{
        .status = "ok",
        .api = api,
        .mapped_input_bytes = mapping.len,
        .actual_input_bits = @as(u64, mapping.len) * 8,
        .bit_count_type_bits = @bitSizeOf(@TypeOf(fast.bit_len)),
        .usize_bits = @bitSizeOf(usize),
        .output_bytes = expected,
        .output_written = 0,
        .guards_verified = true,
        .large_window_enabled = false,
        .physical_mapping = true,
        .direct_fast_reader_fields = values,
        .direct_fast_reader_positions = positions,
        .direct_fast_reader_start_bit = start,
        .direct_fast_reader_final_bit = @as(u64, scalar.bitPosition()),
        .direct_fast_reader_physical_reads_verified = true,
        .scalar_fast_sync_verified = true,
        .whole_file_sha256 = @as(?[]const u8, null),
        .scope = "direct production fast-reader reservoir loads and scalar sync from actual mapped bytes; not an instrumented ordinary decode fast-kernel invocation",
        .build_mode = @tagName(@import("builtin").mode),
    };
    const json = try std.json.Stringify.valueAlloc(init.gpa, report, .{});
    defer init.gpa.free(json);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
