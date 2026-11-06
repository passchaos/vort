const std = @import("std");
const h = @import("common.zig");
const Z = h.codec.zstd;
pub const Receipt = struct {
    refused: bool = false,
    output_written: u64 = 0,
    input_read: u64 = 0,
    calls: u64 = 0,
    direct_phase_seen: bool = false,
    streamed_sequences: u64 = 0,
    decoded_buffer_capacity: usize = 0,
    peak_compressed_buffered: usize = 0,
    frame_count: u64 = 0,
    atomic_failure_checked: bool = false,
};

pub fn run(init: std.process.Init, config: h.Config) !Receipt {
    const payload = try h.read(init, config.payload_path);
    defer init.gpa.free(payload);
    const frame = try h.read(init, config.frame_path orelse return error.MissingFrame);
    defer init.gpa.free(frame);
    const dictionary = if (config.dictionary_path) |path| try h.read(init, path) else null;
    defer if (dictionary) |bytes| init.gpa.free(bytes);
    const dict: ?Z.NativeDictionary = if (dictionary) |bytes| Z.NativeDictionary.initRawContent(bytes) else null;
    const options: Z.FrameDecodeOptions = .{ .format = if (config.magicless) .magicless else .standard, .dictionary = dict, .expected_output_len = payload.len, .max_output_len = payload.len, .ignore_content_checksum = config.ignore_content_checksum };
    var receipt: Receipt = .{};
    if (std.mem.startsWith(u8, config.api, "incremental_")) return incremental(init, config, frame, payload, dict);
    var reusable = Z.NativeFrameDecoder.initWithOptions(init.gpa, options);
    defer reusable.deinit();
    if (std.mem.eql(u8, config.api, "alloc") or std.mem.eql(u8, config.api, "reuse_alloc")) {
        const result = if (std.mem.eql(u8, config.api, "alloc")) Z.decodeFrameAllocWithOptions(init.gpa, frame, options) else reusable.decodeAlloc(frame);
        if (config.expected_error != null) {
            receipt.refused = try h.expectedError(config, result);
        } else {
            const output = try result;
            defer init.gpa.free(output);
            try h.require(std.mem.eql(u8, payload, output));
            receipt.output_written = output.len;
        }
    } else if (std.mem.eql(u8, config.api, "into") or std.mem.eql(u8, config.api, "reuse_into")) {
        const output = try init.gpa.alloc(u8, payload.len + 19);
        defer init.gpa.free(output);
        @memset(output, 0xa5);
        const result = if (std.mem.eql(u8, config.api, "into")) Z.decodeFrameIntoWithOptions(init.gpa, frame, output[0..payload.len], options) else reusable.decodeIntoSlice(frame, output[0..payload.len]);
        if (config.expected_error != null) {
            receipt.refused = try h.expectedError(config, result);
            for (output) |byte| try h.require(byte == 0xa5);
            receipt.atomic_failure_checked = true;
        } else {
            const count = try result;
            try h.require(count == payload.len and std.mem.eql(u8, payload, output[0..count]));
            for (output[count..]) |byte| try h.require(byte == 0xa5);
            receipt.output_written = count;
        }
    } else if (std.mem.eql(u8, config.api, "append") or std.mem.eql(u8, config.api, "reuse_append")) {
        var output = std.ArrayList(u8).fromOwnedSlice(try init.gpa.dupe(u8, "prefix"));
        defer output.deinit(init.gpa);
        const pointer = output.items.ptr;
        const capacity = output.capacity;
        const result = if (std.mem.eql(u8, config.api, "append")) Z.decodeFrameAppendWithOptions(init.gpa, &output, frame, options) else reusable.decodeAppend(&output, frame);
        if (config.expected_error != null) {
            receipt.refused = try h.expectedError(config, result);
            try h.require(output.items.ptr == pointer and output.capacity == capacity and std.mem.eql(u8, output.items, "prefix"));
            receipt.atomic_failure_checked = true;
        } else {
            const count = try result;
            try h.require(count == payload.len and std.mem.eql(u8, payload, output.items[6..]) and std.mem.eql(u8, output.items[0..6], "prefix"));
            receipt.output_written = count;
        }
    } else if (std.mem.eql(u8, config.api, "reuse_scratch")) {
        const warm_frame = if (config.warm_frame_path) |path| try h.read(init, path) else null;
        defer if (warm_frame) |bytes| init.gpa.free(bytes);
        const warm = try reusable.decodeScratchWithOptions(warm_frame orelse frame, .{ .format = options.format, .dictionary = dict, .ignore_content_checksum = true });
        const pointer = warm.ptr;
        const capacity = reusable.scratch.capacity;
        const saved = try init.gpa.dupe(u8, warm);
        defer init.gpa.free(saved);
        const result = reusable.decodeScratch(frame);
        if (config.expected_error != null) {
            receipt.refused = try h.expectedError(config, result);
            try h.require(reusable.scratch.items.ptr == pointer and reusable.scratch.capacity == capacity and std.mem.eql(u8, saved, reusable.scratch.items));
            receipt.atomic_failure_checked = true;
        } else {
            const output = try result;
            try h.require(std.mem.eql(u8, payload, output));
            receipt.output_written = output.len;
        }
    } else return error.UnknownApi;
    return receipt;
}

fn incremental(init: std.process.Init, config: h.Config, frame: []const u8, payload: []const u8, dict: ?Z.NativeDictionary) !Receipt {
    const options: Z.NativeIncrementalFrameDecoder.Options = .{
        .format = if (config.magicless) .magicless else .standard,
        .ignore_content_checksum = config.ignore_content_checksum,
        .input_policy = if (std.mem.eql(u8, config.api, "incremental_prevalidated")) .prevalidated_frame else .block_stream,
        .expected_output_len = payload.len,
        .max_output_len = payload.len,
    };
    var decoder = if (dict) |dictionary| Z.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(init.gpa, dictionary, options) else Z.NativeIncrementalFrameDecoder.initWithOptions(init.gpa, options);
    defer decoder.deinit();
    var receipt: Receipt = .{};
    const direct = std.mem.eql(u8, config.api, "incremental_direct");
    const result = drive(&decoder, frame, payload, if (direct) frame.len else config.input_chunk, config.output_chunk, &receipt);
    receipt.refused = try h.expectedError(config, result);
    receipt.streamed_sequences = decoder.streamedSequenceBlockCount();
    receipt.decoded_buffer_capacity = decoder.decodedBufferCapacity();
    receipt.frame_count = decoder.snapshot().data_frame_count;
    return receipt;
}

fn drive(decoder: *Z.NativeIncrementalFrameDecoder, frame: []const u8, payload: []const u8, input_chunk: usize, output_chunk: usize, receipt: *Receipt) !void {
    try h.require(input_chunk != 0 and output_chunk != 0 and output_chunk <= 65536);
    for (0..(frame.len + payload.len) * 4 + 128) |_| {
        var output: [65536]u8 = undefined;
        const read: usize = @intCast(receipt.input_read);
        const written: usize = @intCast(receipt.output_written);
        const end = @min(frame.len, read + input_chunk);
        const available = @min(output_chunk, payload.len - written);
        const before = decoder.snapshot();
        receipt.peak_compressed_buffered = @max(receipt.peak_compressed_buffered, decoder.compressedBufferedBytes());
        const result = decoder.step(frame[read..end], output[0..available]) catch |err| {
            const progress = decoder.snapshot().last_step_progress;
            receipt.input_read += progress.input_read;
            receipt.output_written += progress.output_written;
            receipt.calls += 1;
            try h.require(std.mem.eql(u8, output[0..progress.output_written], payload[written..][0..progress.output_written]));
            return err;
        };
        receipt.input_read += result.progress.input_read;
        receipt.output_written += result.progress.output_written;
        receipt.calls += 1;
        const after = decoder.snapshot();
        receipt.peak_compressed_buffered = @max(receipt.peak_compressed_buffered, decoder.compressedBufferedBytes());
        try h.require(after.input_received == before.input_received + result.progress.input_read and after.output_written == before.output_written + result.progress.output_written);
        if (after.phase == .direct_output) receipt.direct_phase_seen = true;
        try h.require(std.mem.eql(u8, output[0..result.progress.output_written], payload[written..][0..result.progress.output_written]));
        if (result.status == .done and receipt.input_read == frame.len) {
            try decoder.finish();
            try h.require(receipt.output_written == payload.len);
            return;
        }
        if (receipt.input_read == frame.len and result.status == .need_input) {
            try decoder.finish();
            try h.require(receipt.output_written == payload.len);
            return;
        }
        if (result.progress.input_read == 0 and result.progress.output_written == 0) return error.NoProgress;
    }
    return error.NoProgress;
}
