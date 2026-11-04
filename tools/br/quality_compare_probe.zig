//! Compare Vort and libbrotli quality-preset wire structure on one prefix.
const std = @import("std");
const br = @import("vort_br");
const libbrotli = @import("libbrotli_runtime.zig");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingInput;
    const limit = try std.fmt.parseInt(usize, args.next() orelse "65536", 10);
    const quality: u4 = @intCast(try std.fmt.parseInt(u8, args.next() orelse "11", 10));

    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const stat = try file.stat(init.io);
    const read_len: usize = @intCast(@min(stat.size, limit));
    if (read_len == 0) return error.InputTooSmall;
    const bytes = try init.gpa.alloc(u8, read_len);
    defer init.gpa.free(bytes);
    var buffer: [4096]u8 = undefined;
    var reader = file.reader(init.io, &buffer);
    if (try reader.interface.readSliceShort(bytes) != read_len) return error.InputTooSmall;

    const vort_stream = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, bytes, .{ .quality = quality });
    defer init.gpa.free(vort_stream);
    const vort_summary = try br.summarizeStreamAlloc(init.gpa, vort_stream);

    var reference = try libbrotli.Runtime.open();
    defer reference.deinit();
    const reference_stream = try reference.encodeWithOptionsAlloc(init.gpa, bytes, .{
        .quality = @intCast(quality),
        .lgwin = 22,
        .mode = 0,
    });
    defer init.gpa.free(reference_stream);
    const reference_summary = try br.summarizeStreamAlloc(init.gpa, reference_stream);

    std.debug.print("quality={d} input={d}\n", .{ quality, bytes.len });
    printSummary("vort", vort_stream.len, vort_summary);
    printSummary("reference", reference_stream.len, reference_summary);
}

fn printSummary(label: []const u8, bytes: usize, summary: br.StreamSummary) void {
    std.debug.print(
        "{s} bytes={d} meta_blocks={d} commands={d} lz77_copies={d} lz77_copy_bytes={d} zero_insert={d} implicit_dist={d} short_dist={d} direct_dist={d} regular_dist={d} literal_trees={d} command_types={d} distance_types={d} distance_context_trees={d} context_mode_bytes={any} static_dict_copies={d} static_dict_bytes={d}\n",
        .{
            label,                              bytes,                                summary.meta_block_count,
            summary.command_count,              summary.lz77_copy_count,              summary.lz77_copy_bytes,
            summary.zero_insert_command_count,  summary.implicit_distance_copy_count, summary.short_distance_copy_count,
            summary.direct_distance_copy_count, summary.regular_distance_copy_count,  summary.max_literal_context_trees,
            summary.max_command_block_types,    summary.max_distance_block_types,     summary.max_distance_context_trees,
            summary.literal_context_mode_bytes, summary.static_dictionary_copy_count, summary.static_dictionary_bytes,
        },
    );
}
