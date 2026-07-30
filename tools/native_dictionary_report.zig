const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print("codec,case,input_bytes,dictionary_bytes,native_bytes,dictionary_bytes_out,savings_bytes,savings_percent\n", .{});
    try reportLz4(init.gpa, stdout);
    try reportZstd(init.gpa, stdout);
    try stdout.flush();
}

fn reportLz4(allocator: std.mem.Allocator, stdout: *std.Io.Writer) !void {
    const dict = vort.Lz4NativeDictionary.init(0x4c5a_4449, "abcdefghijklmnop");
    const payload = "pfx-abcdefghijklmnop-mid-abcdefghijklmnop-tail";
    const options: vort.Lz4NativeFrameOptions = .{
        .content_checksum = false,
        .block_checksum = true,
    };

    const native = try vort.lz4EncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(native);
    const with_dict = try vort.lz4EncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(with_dict);
    const decoded = try vort.lz4DecodeNativeFrameAllocWithDictionary(allocator, with_dict, dict);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.NativeDictionaryReportMismatch;
    if (with_dict.len >= native.len) return error.NativeDictionaryReportNoSavings;
    try printRow(stdout, "lz4", "repeated-prefix", payload.len, dict.content.len, native.len, with_dict.len);
}

fn reportZstd(allocator: std.mem.Allocator, stdout: *std.Io.Writer) !void {
    const dictionary_payload = "abcdefghijklmnopqrstuvwxyz0123456789" ** 8;
    const dict = vort.ZstdNativeDictionary.init(0x5a57_4449, dictionary_payload);
    const payload = "pfx-" ++ dictionary_payload ++ "-mid-" ++ dictionary_payload ++ "-tail";
    const options: vort.ZstdNativeFrameOptions = .{
        .selection = .literal_only,
        .content_checksum = false,
    };

    const native = try vort.zstdEncodeNativeFrameWithOptionsAlloc(allocator, payload, options);
    defer allocator.free(native.frame);
    const with_dict = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(allocator, payload, options, dict);
    defer allocator.free(with_dict.frame);
    const decoded = try vort.zstdDecodeNativeFrameAllocWithDictionary(allocator, with_dict.frame, dict);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, payload, decoded)) return error.NativeDictionaryReportMismatch;
    if (with_dict.frame.len >= native.frame.len) return error.NativeDictionaryReportNoSavings;
    try printRow(stdout, "zstd", "multi-dictionary", payload.len, dict.content.len, native.frame.len, with_dict.frame.len);
}

fn printRow(
    stdout: *std.Io.Writer,
    codec: []const u8,
    name: []const u8,
    input_len: usize,
    dictionary_len: usize,
    native_len: usize,
    dictionary_frame_len: usize,
) !void {
    const savings = native_len - dictionary_frame_len;
    const savings_percent = (@as(f64, @floatFromInt(savings)) * 100.0) / @as(f64, @floatFromInt(native_len));
    try stdout.print(
        "{s},{s},{d},{d},{d},{d},{d},{d:.2}\n",
        .{ codec, name, input_len, dictionary_len, native_len, dictionary_frame_len, savings, savings_percent },
    );
}
