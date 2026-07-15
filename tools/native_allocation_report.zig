const std = @import("std");
const vort = @import("vort");

const CaseStats = struct {
    name: []const u8,
    input_bytes: usize,
    output_bytes: usize,
    allocations: usize,
    deallocations: usize,
    allocated_bytes: usize,
    freed_bytes: usize,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const deflate_rle_stream = try buildDeflateRleStream(allocator);
    defer allocator.free(deflate_rle_stream);
    const dict_stream = try buildEmbeddedDictionaryPatchStream(allocator);
    defer allocator.free(dict_stream);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("case,input_bytes,output_bytes,allocations,deallocations,allocated_bytes,freed_bytes\n", .{});

    try printStats(stdout, try measureConcatAlloc(allocator, deflate_rle_stream));
    try printStats(stdout, try measureConcatInto(allocator, deflate_rle_stream));
    try printStats(stdout, try measureConcatAutoInto(allocator, dict_stream));
    try printStats(stdout, try measureLimitedReject(allocator, deflate_rle_stream));
    try stdout.flush();
}

fn printStats(writer: *std.Io.Writer, row: CaseStats) !void {
    try writer.print("{s},{d},{d},{d},{d},{d},{d}\n", .{
        row.name,
        row.input_bytes,
        row.output_bytes,
        row.allocations,
        row.deallocations,
        row.allocated_bytes,
        row.freed_bytes,
    });
}

fn buildDeflateRleStream(allocator: std.mem.Allocator) ![]u8 {
    const first = "hello hello hello hello";
    const second = "aaaaabbbbbbbbbbbbbcccccccc";
    const first_frame = try vort.storeEncodeDeflateAlloc(allocator, first);
    defer allocator.free(first_frame);
    const second_frame = try vort.storeEncodeRleAlloc(allocator, second);
    defer allocator.free(second_frame);
    var stream = std.ArrayList(u8).empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, first_frame);
    try stream.appendSlice(allocator, second_frame);
    return stream.toOwnedSlice(allocator);
}

fn buildEmbeddedDictionaryPatchStream(allocator: std.mem.Allocator) ![]u8 {
    const dict = "alpha beta gamma";
    const payload = try embeddedDictionaryPayloadAlloc(allocator, dict);
    defer allocator.free(payload);
    const dict_frame = try vort.storeEncodeSkippableAlloc(allocator, payload);
    defer allocator.free(dict_frame);
    const data_frame = try vort.storeEncodeDictionaryPatchAlloc(allocator, dict, "alpha beta", 5);
    defer allocator.free(data_frame);
    var stream = std.ArrayList(u8).empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, dict_frame);
    try stream.appendSlice(allocator, data_frame);
    return stream.toOwnedSlice(allocator);
}

fn embeddedDictionaryPayloadAlloc(allocator: std.mem.Allocator, dict: []const u8) ![]u8 {
    const header_len = 20;
    const out = try allocator.alloc(u8, header_len + dict.len);
    errdefer allocator.free(out);
    @memcpy(out[0..4], "VDIC");
    const id = vort.DictionaryId.fromBytes(dict);
    std.mem.writeInt(u64, out[4..12], id.asInt(), .little);
    std.mem.writeInt(u32, out[12..16], @intCast(dict.len), .little);
    std.mem.writeInt(u32, out[16..20], 0, .little);
    @memcpy(out[header_len..], dict);
    return out;
}

fn measureConcatAlloc(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const allocator = failing.allocator();
    const decoded = try vort.storeDecodeConcatenatedAlloc(allocator, stream);
    const output_len = decoded.len;
    allocator.free(decoded);
    return stats("concat_alloc", stream.len, output_len, failing);
}

fn measureConcatInto(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const summary = try vort.storeInspectConcatenated(stream);
    const output_len = std.math.cast(usize, summary.total_uncompressed) orelse return error.IntegerOverflow;
    const out = try backing.alloc(u8, output_len);
    defer backing.free(out);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeConcatenatedInto(failing.allocator(), stream, out);
    return stats("concat_into", stream.len, result.output_written, failing);
}

fn measureConcatAutoInto(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    const summary = try vort.storeInspectConcatenated(stream);
    const output_len = std.math.cast(usize, summary.total_uncompressed) orelse return error.IntegerOverflow;
    const out = try backing.alloc(u8, output_len);
    defer backing.free(out);
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const result = try vort.storeDecodeConcatenatedAutoInto(failing.allocator(), stream, out);
    return stats("concat_auto_into_embedded_dict", stream.len, result.output_written, failing);
}

fn measureLimitedReject(backing: std.mem.Allocator, stream: []const u8) !CaseStats {
    var failing = std.testing.FailingAllocator.init(backing, .{});
    const summary = try vort.storeInspectConcatenated(stream);
    const output_len = std.math.cast(usize, summary.total_uncompressed) orelse return error.IntegerOverflow;
    try std.testing.expectError(error.OutputLimitExceeded, vort.storeDecodeConcatenatedAllocLimited(failing.allocator(), stream, output_len - 1));
    return stats("concat_limited_reject", stream.len, 0, failing);
}

fn stats(name: []const u8, input_len: usize, output_len: usize, failing: std.testing.FailingAllocator) CaseStats {
    return .{
        .name = name,
        .input_bytes = input_len,
        .output_bytes = output_len,
        .allocations = failing.allocations,
        .deallocations = failing.deallocations,
        .allocated_bytes = failing.allocated_bytes,
        .freed_bytes = failing.freed_bytes,
    };
}
