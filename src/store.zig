const std = @import("std");
const checksum = @import("checksum.zig");
const deflate = @import("deflate.zig");
const dictionary = @import("dictionary.zig");
const long_distance = @import("long_distance.zig");
const core = @import("core.zig");

pub const Error = core.Error;
pub const FrameInfo = core.FrameInfo;
pub const Progress = core.Progress;
pub const StepResult = core.StepResult;

pub const magic = [_]u8{ 'V', 'O', 'R', 'T' };
pub const current_version: u8 = 0;
pub const header_len: usize = 32;
pub const max_chunk_len: usize = std.math.maxInt(u32);
pub const skippable_magic = [_]u8{ 'V', 'S', 'K', 'P' };
pub const skippable_header_len: usize = 8;
const ldm_summary_magic = [_]u8{ 'V', 'L', 'D', 'M' };
const ldm_summary_len: usize = 28;
const embedded_dictionary_magic = [_]u8{ 'V', 'D', 'I', 'C' };
const embedded_dictionary_header_len: usize = 20;

const flags_none: u8 = 0;
const flags_deflate: u8 = 1;
const flags_rle: u8 = 2;
const flags_dictionary_patch: u8 = 3;
const flags_ldm: u8 = 4;
const flags_dictionary_deflate: u8 = 5;

pub fn frameModeName(flags: u8) []const u8 {
    return switch (flags) {
        flags_none => "store",
        flags_deflate => "deflate",
        flags_rle => "rle",
        flags_dictionary_patch => "dictionary_patch",
        flags_ldm => "ldm",
        flags_dictionary_deflate => "dictionary_deflate",
        else => "unknown",
    };
}

pub const FrameInspection = struct {
    info: FrameInfo,
    frame_len: usize,
    payload_len: usize,
    mode: []const u8,
    requires_dictionary: bool,
};

pub fn inspectHeader(input: []const u8) Error!FrameInspection {
    const info = try parseHeader(input);
    const payload_len = try storedPayloadLenFromInfo(info);
    const frame_len = try encodedSize(payload_len);
    return .{
        .info = info,
        .frame_len = frame_len,
        .payload_len = payload_len,
        .mode = frameModeName(info.flags),
        .requires_dictionary = info.flags == flags_dictionary_patch or info.flags == flags_dictionary_deflate,
    };
}

pub fn inspectFrame(input: []const u8) Error!FrameInspection {
    const inspection = try inspectHeader(input);
    if (input.len < inspection.frame_len) return error.TruncatedFrame;
    return inspection;
}

pub fn skippableEncodedSize(payload_len: usize) Error!usize {
    if (payload_len > std.math.maxInt(u32)) return error.IntegerOverflow;
    return std.math.add(usize, skippable_header_len, payload_len) catch error.IntegerOverflow;
}

pub fn encodeSkippable(payload: []const u8, output: []u8) Error!usize {
    const required = try skippableEncodedSize(payload.len);
    if (output.len < required) return error.OutputTooSmall;
    @memcpy(output[0..4], &skippable_magic);
    std.mem.writeInt(u32, output[4..8], @intCast(payload.len), .little);
    @memcpy(output[8..required], payload);
    return required;
}

pub fn encodeSkippableAlloc(allocator: std.mem.Allocator, payload: []const u8) ![]u8 {
    const required = try skippableEncodedSize(payload.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encodeSkippable(payload, out);
    std.debug.assert(written == out.len);
    return out;
}

pub fn parseSkippable(input: []const u8) Error![]const u8 {
    if (input.len < skippable_header_len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..4], &skippable_magic)) return error.InvalidMagic;
    const payload_len: usize = std.mem.readInt(u32, input[4..8], .little);
    if (input.len - skippable_header_len < payload_len) return error.TruncatedFrame;
    return input[skippable_header_len..][0..payload_len];
}

fn skippableTotalLen(input: []const u8) Error!usize {
    if (input.len < skippable_header_len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..4], &skippable_magic)) return error.InvalidMagic;
    const payload_len: usize = std.mem.readInt(u32, input[4..8], .little);
    return skippableEncodedSize(payload_len);
}

/// Header-only capacity calculation for the bootstrap store frame.
pub fn encodedSize(input_len: usize) Error!usize {
    return std.math.add(usize, header_len, input_len) catch error.IntegerOverflow;
}

/// Encode a native Vort store frame. This deliberately performs no compression;
/// it validates the frame plumbing, size accounting, and checksum contract that
/// later compressed blocks will reuse.
pub fn encode(input: []const u8, output: []u8) Error!usize {
    const required = try encodedSize(input.len);
    if (output.len < required) return error.OutputTooSmall;
    if (input.len > std.math.maxInt(u64)) return error.IntegerOverflow;

    writeHeader(output[0..header_len], .{
        .version = current_version,
        .flags = flags_none,
        .uncompressed_size = @intCast(input.len),
        .stored_size = @intCast(input.len),
        .checksum = checksum.crc32(input),
    });
    @memcpy(output[header_len..required], input);
    return required;
}

/// Allocate and encode a store frame. The caller owns the returned slice.
pub fn encodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const required = try encodedSize(input.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encode(input, out);
    std.debug.assert(written == out.len);
    return out;
}

fn encodeRlePayloadAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < input.len) {
        const byte = input[i];
        var run: usize = 1;
        while (i + run < input.len and input[i + run] == byte and run < 255) run += 1;
        try out.append(allocator, @intCast(run));
        try out.append(allocator, byte);
        i += run;
    }
    return out.toOwnedSlice(allocator);
}

fn decodeRlePayloadAlloc(allocator: std.mem.Allocator, payload: []const u8, expected_len: usize) ![]u8 {
    const out = try allocator.alloc(u8, expected_len);
    errdefer allocator.free(out);
    const written = try decodeRlePayloadInto(payload, out);
    std.debug.assert(written == expected_len);
    return out;
}

fn decodeRlePayloadInto(payload: []const u8, output: []u8) Error!usize {
    if ((payload.len & 1) != 0) return error.CorruptFrame;
    var written: usize = 0;
    var i: usize = 0;
    while (i < payload.len) : (i += 2) {
        const run: usize = payload[i];
        const byte = payload[i + 1];
        if (run == 0) return error.CorruptFrame;
        if (written > output.len) return error.SizeMismatch;
        if (run > output.len - written) return error.SizeMismatch;
        @memset(output[written..][0..run], byte);
        written += run;
    }
    if (written != output.len) return error.SizeMismatch;
    return written;
}

pub fn encodeRleAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const compressed = try encodeRlePayloadAlloc(allocator, input);
    defer allocator.free(compressed);
    const required = try encodedSize(compressed.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    writeHeader(out[0..header_len], .{
        .version = current_version,
        .flags = flags_rle,
        .uncompressed_size = @intCast(input.len),
        .stored_size = @intCast(compressed.len),
        .checksum = checksum.crc32(input),
    });
    @memcpy(out[header_len..], compressed);
    return out;
}

pub fn encodeDeflateAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const compressed = try deflate.encodeRawBestAlloc(allocator, input, .{});
    defer allocator.free(compressed);
    const required = try encodedSize(compressed.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    writeHeader(out[0..header_len], .{
        .version = current_version,
        .flags = flags_deflate,
        .uncompressed_size = @intCast(input.len),
        .stored_size = @intCast(compressed.len),
        .checksum = checksum.crc32(input),
    });
    @memcpy(out[header_len..], compressed);
    return out;
}

pub fn encodeDictionaryPatchAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, min_match_len: usize) ![]u8 {
    const patch = try dictionary.encodePatchAlloc(allocator, dict, input, min_match_len);
    defer allocator.free(patch);
    const required = try encodedSize(patch.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    writeHeader(out[0..header_len], .{
        .version = current_version,
        .flags = flags_dictionary_patch,
        .uncompressed_size = @intCast(input.len),
        .stored_size = @intCast(patch.len),
        .checksum = checksum.crc32(input),
    });
    @memcpy(out[header_len..], patch);
    return out;
}

pub fn encodeDictionaryDeflateAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, min_match_len: usize) ![]u8 {
    const patch = try dictionary.encodePatchAlloc(allocator, dict, input, min_match_len);
    defer allocator.free(patch);
    const compressed = try deflate.encodeRawBestAlloc(allocator, patch, deflate.optionsForLevel(.fastest));
    defer allocator.free(compressed);
    const required = try encodedSize(compressed.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    writeHeader(out[0..header_len], .{
        .version = current_version,
        .flags = flags_dictionary_deflate,
        .uncompressed_size = @intCast(input.len),
        .stored_size = @intCast(compressed.len),
        .checksum = checksum.crc32(input),
    });
    @memcpy(out[header_len..], compressed);
    return out;
}

pub fn encodeLongDistanceAlloc(allocator: std.mem.Allocator, input: []const u8, options: long_distance.Options) ![]u8 {
    const payload = try encodeLongDistancePayloadAlloc(allocator, input, options);
    defer allocator.free(payload);
    const required = try encodedSize(payload.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    writeHeader(out[0..header_len], .{
        .version = current_version,
        .flags = flags_ldm,
        .uncompressed_size = @intCast(input.len),
        .stored_size = @intCast(payload.len),
        .checksum = checksum.crc32(input),
    });
    @memcpy(out[header_len..], payload);
    return out;
}

fn encodeLongDistancePayloadAlloc(allocator: std.mem.Allocator, input: []const u8, options: long_distance.Options) ![]u8 {
    const candidates = try long_distance.findCandidatesAlloc(allocator, input, options);
    defer allocator.free(candidates);
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    if (candidates.len == 0) {
        try appendLiteralOp(allocator, &out, input);
        return out.toOwnedSlice(allocator);
    }
    var offset: usize = 0;
    for (candidates) |candidate| {
        if (candidate.position < offset) continue;
        try appendLiteralOp(allocator, &out, input[offset..candidate.position]);
        try out.append(allocator, 1);
        appendIntLE(u32, allocator, &out, @intCast(candidate.distance)) catch |err| return err;
        appendIntLE(u32, allocator, &out, @intCast(candidate.length)) catch |err| return err;
        offset = candidate.position + candidate.length;
    }
    try appendLiteralOp(allocator, &out, input[offset..]);
    return out.toOwnedSlice(allocator);
}

fn appendLiteralOp(allocator: std.mem.Allocator, out: *std.ArrayList(u8), literal: []const u8) !void {
    if (literal.len == 0) return;
    try out.append(allocator, 0);
    try appendIntLE(u32, allocator, out, @intCast(literal.len));
    try out.appendSlice(allocator, literal);
}

fn appendIntLE(comptime T: type, allocator: std.mem.Allocator, out: *std.ArrayList(u8), value: T) !void {
    var buf: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &buf, value, .little);
    try out.appendSlice(allocator, &buf);
}

pub fn encodeBestWithDictionaryAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, min_match_len: usize) ![]u8 {
    const native_best = try encodeBestAlloc(allocator, input);
    errdefer allocator.free(native_best);
    const dict_frame = try encodeDictionaryPatchAlloc(allocator, dict, input, min_match_len);
    errdefer allocator.free(dict_frame);
    const dict_deflate_frame = try encodeDictionaryDeflateAlloc(allocator, dict, input, min_match_len);
    errdefer allocator.free(dict_deflate_frame);
    if (dict_frame.len <= dict_deflate_frame.len and dict_frame.len < native_best.len) {
        allocator.free(dict_deflate_frame);
        allocator.free(native_best);
        return dict_frame;
    }
    allocator.free(dict_frame);
    if (dict_deflate_frame.len < native_best.len) {
        allocator.free(native_best);
        return dict_deflate_frame;
    }
    allocator.free(dict_deflate_frame);
    return native_best;
}

pub fn encodeBestWithLongDistanceAlloc(allocator: std.mem.Allocator, input: []const u8, options: long_distance.Options) ![]u8 {
    const native_best = try encodeBestAlloc(allocator, input);
    errdefer allocator.free(native_best);
    const ldm_frame = try encodeLongDistanceAlloc(allocator, input, options);
    errdefer allocator.free(ldm_frame);
    if (ldm_frame.len < native_best.len) {
        allocator.free(native_best);
        return ldm_frame;
    }
    allocator.free(ldm_frame);
    return native_best;
}

pub fn encodeBestAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const store_frame = try encodeAlloc(allocator, input);
    errdefer allocator.free(store_frame);
    const deflate_frame = try encodeDeflateAlloc(allocator, input);
    errdefer allocator.free(deflate_frame);
    const rle_frame = try encodeRleAlloc(allocator, input);
    errdefer allocator.free(rle_frame);
    if (store_frame.len <= deflate_frame.len and store_frame.len <= rle_frame.len) {
        allocator.free(deflate_frame);
        allocator.free(rle_frame);
        return store_frame;
    }
    allocator.free(store_frame);
    if (deflate_frame.len <= rle_frame.len) {
        allocator.free(rle_frame);
        return deflate_frame;
    }
    allocator.free(deflate_frame);
    return rle_frame;
}

pub fn decodeAnyAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const info = try parseHeader(input);
    if (info.flags == flags_dictionary_patch or info.flags == flags_dictionary_deflate) return error.InvalidDictionaryTraining;
    const payload = try payloadSliceFromInfo(input, info);
    const output_len = try decodeAnyOutputLen(info);
    return decodeAnyPayloadAllocKnownLen(allocator, info, payload, output_len);
}

pub fn decodeAnyAllocExactSize(allocator: std.mem.Allocator, input: []const u8, expected_output_len: usize) ![]u8 {
    const info = try parseHeader(input);
    if (info.flags == flags_dictionary_patch or info.flags == flags_dictionary_deflate) return error.InvalidDictionaryTraining;
    const payload = try payloadSliceFromInfo(input, info);
    const output_len = try decodeAnyOutputLen(info);
    if (output_len != expected_output_len) return error.SizeMismatch;
    return decodeAnyPayloadAllocKnownLen(allocator, info, payload, output_len);
}

pub fn decodeAnyAllocLimited(allocator: std.mem.Allocator, input: []const u8, max_output_len: usize) ![]u8 {
    const info = try parseHeader(input);
    if (info.flags == flags_dictionary_patch or info.flags == flags_dictionary_deflate) return error.InvalidDictionaryTraining;
    const payload = try payloadSliceFromInfo(input, info);
    const output_len = try decodeAnyOutputLen(info);
    if (output_len > max_output_len) return error.OutputLimitExceeded;
    return decodeAnyPayloadAllocKnownLen(allocator, info, payload, output_len);
}

fn decodeAnyPayloadAllocKnownLen(allocator: std.mem.Allocator, info: FrameInfo, payload: []const u8, output_len: usize) ![]u8 {
    const decoded = try allocator.alloc(u8, output_len);
    errdefer allocator.free(decoded);
    const written = try decodeAnyPayloadInto(info, payload, decoded);
    std.debug.assert(written == decoded.len);
    return decoded;
}

pub fn decodeAnyInto(input: []const u8, output: []u8) Error!usize {
    const info = try parseHeader(input);
    const payload = try payloadSliceFromInfo(input, info);
    return decodeAnyPayloadInto(info, payload, output);
}

fn payloadSliceFromInfo(input: []const u8, info: FrameInfo) Error![]const u8 {
    const payload_len = std.math.cast(usize, info.stored_size) orelse return error.IntegerOverflow;
    const total_len = try encodedSize(payload_len);
    if (input.len < total_len) return error.TruncatedFrame;
    return input[header_len..total_len];
}

fn decodeAnyOutputLen(info: FrameInfo) Error!usize {
    if (info.flags == flags_none and info.uncompressed_size != info.stored_size) return error.CorruptFrame;
    return std.math.cast(usize, info.uncompressed_size) orelse return error.IntegerOverflow;
}

fn decodeAnyPayloadInto(info: FrameInfo, payload: []const u8, output: []u8) Error!usize {
    const output_len = try decodeAnyOutputLen(info);
    if (output.len < output_len) return error.OutputTooSmall;
    const target = output[0..output_len];
    switch (info.flags) {
        flags_none => {
            if (payload.len != target.len) return error.CorruptFrame;
            @memcpy(target, payload);
        },
        flags_deflate => {
            const decoded = deflate.decodeRawAuto(payload, target) catch |err| switch (err) {
                error.OutputTooSmall => return error.SizeMismatch,
                else => return err,
            };
            if (decoded.output_written != output_len) return error.SizeMismatch;
            if (decoded.input_read != payload.len) return error.TrailingData;
        },
        flags_rle => {
            const written = try decodeRlePayloadInto(payload, target);
            if (written != output_len) return error.SizeMismatch;
        },
        flags_dictionary_patch => return error.InvalidDictionaryTraining,
        flags_dictionary_deflate => return error.InvalidDictionaryTraining,
        flags_ldm => {
            const written = try decodeLongDistancePayloadInto(payload, target);
            if (written != output_len) return error.SizeMismatch;
        },
        else => return error.CorruptFrame,
    }
    if (checksum.crc32(target) != info.checksum) return error.ChecksumMismatch;
    return output_len;
}

pub fn decodeRleInto(input: []const u8, output: []u8) Error!usize {
    const info = try parseHeader(input);
    if (info.flags != flags_rle) return error.CorruptFrame;
    const output_len = std.math.cast(usize, info.uncompressed_size) orelse return error.IntegerOverflow;
    if (output.len < output_len) return error.OutputTooSmall;
    const payload_len = std.math.cast(usize, info.stored_size) orelse return error.IntegerOverflow;
    const total_len = try encodedSize(payload_len);
    if (input.len < total_len) return error.TruncatedFrame;
    const payload = input[header_len..total_len];
    const written = try decodeRlePayloadInto(payload, output[0..output_len]);
    if (written != output_len) return error.SizeMismatch;
    if (checksum.crc32(output[0..output_len]) != info.checksum) return error.ChecksumMismatch;
    return output_len;
}

pub fn decodeLongDistanceInto(input: []const u8, output: []u8) Error!usize {
    const info = try parseHeader(input);
    if (info.flags != flags_ldm) return error.CorruptFrame;
    const output_len = std.math.cast(usize, info.uncompressed_size) orelse return error.IntegerOverflow;
    if (output.len < output_len) return error.OutputTooSmall;
    const payload_len = std.math.cast(usize, info.stored_size) orelse return error.IntegerOverflow;
    const total_len = try encodedSize(payload_len);
    if (input.len < total_len) return error.TruncatedFrame;
    const payload = input[header_len..total_len];
    const written = try decodeLongDistancePayloadInto(payload, output[0..output_len]);
    if (written != output_len) return error.SizeMismatch;
    if (checksum.crc32(output[0..output_len]) != info.checksum) return error.ChecksumMismatch;
    return output_len;
}

fn decodeLongDistancePayloadAlloc(allocator: std.mem.Allocator, payload: []const u8, expected_len: usize) ![]u8 {
    const out = try allocator.alloc(u8, expected_len);
    errdefer allocator.free(out);
    const written = try decodeLongDistancePayloadInto(payload, out);
    std.debug.assert(written == expected_len);
    return out;
}

fn decodeLongDistancePayloadInto(payload: []const u8, output: []u8) Error!usize {
    const expected_len = output.len;
    var written: usize = 0;
    var offset: usize = 0;
    while (offset < payload.len) {
        const tag = payload[offset];
        offset += 1;
        switch (tag) {
            0 => {
                if (payload.len - offset < 4) return error.TruncatedFrame;
                const len: usize = std.mem.readInt(u32, payload[offset..][0..4], .little);
                offset += 4;
                if (payload.len - offset < len) return error.TruncatedFrame;
                try copyLongDistanceLiteral(output, &written, payload[offset..][0..len]);
                offset += len;
            },
            1 => {
                if (payload.len - offset < 8) return error.TruncatedFrame;
                const distance: usize = std.mem.readInt(u32, payload[offset..][0..4], .little);
                const len: usize = std.mem.readInt(u32, payload[offset + 4 ..][0..4], .little);
                offset += 8;
                try copyLongDistanceMatch(output, &written, distance, len);
            },
            else => return error.CorruptFrame,
        }
    }
    if (written != expected_len) return error.SizeMismatch;
    return written;
}

fn copyLongDistanceLiteral(output: []u8, written: *usize, source: []const u8) Error!void {
    if (written.* > output.len) return error.SizeMismatch;
    if (source.len > output.len - written.*) return error.SizeMismatch;
    @memcpy(output[written.*..][0..source.len], source);
    written.* += source.len;
}

fn copyLongDistanceMatch(output: []u8, written: *usize, distance: usize, len: usize) Error!void {
    if (distance == 0 or distance > written.*) return error.InvalidMatch;
    if (written.* > output.len) return error.SizeMismatch;
    if (len > output.len - written.*) return error.SizeMismatch;

    // Matches intentionally copy one byte at a time instead of using @memcpy:
    // when len > distance the source range overlaps bytes produced earlier in
    // the same match, mirroring LZ-style repeated back-reference semantics.
    for (0..len) |i| {
        const dest_index = written.* + i;
        output[dest_index] = output[dest_index - distance];
    }
    written.* += len;
}

pub fn decodeDictionaryPatchAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8) ![]u8 {
    const info = try parseHeader(input);
    const output_len = try dictionaryFrameOutputLen(info);
    return decodeDictionaryPatchAllocKnownLen(allocator, dict, input, output_len);
}

pub fn decodeDictionaryPatchAllocExactSize(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, expected_output_len: usize) ![]u8 {
    const info = try parseHeader(input);
    const output_len = try dictionaryFrameOutputLen(info);
    if (output_len != expected_output_len) return error.SizeMismatch;
    return decodeDictionaryPatchAllocKnownLen(allocator, dict, input, output_len);
}

pub fn decodeDictionaryPatchAllocLimited(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, max_output_len: usize) ![]u8 {
    const info = try parseHeader(input);
    const output_len = try dictionaryFrameOutputLen(info);
    if (output_len > max_output_len) return error.OutputLimitExceeded;
    return decodeDictionaryPatchAllocKnownLen(allocator, dict, input, output_len);
}

fn dictionaryFrameOutputLen(info: FrameInfo) Error!usize {
    if (info.flags != flags_dictionary_patch and info.flags != flags_dictionary_deflate) return error.CorruptFrame;
    return std.math.cast(usize, info.uncompressed_size) orelse return error.IntegerOverflow;
}

fn decodeDictionaryPatchAllocKnownLen(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, output_len: usize) ![]u8 {
    const decoded = try allocator.alloc(u8, output_len);
    errdefer allocator.free(decoded);
    const written = try decodeDictionaryPatchInto(allocator, dict, input, decoded);
    std.debug.assert(written == decoded.len);
    return decoded;
}

pub fn decodeDictionaryPatchInto(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, output: []u8) !usize {
    const info = try parseHeader(input);
    const output_len = std.math.cast(usize, info.uncompressed_size) orelse return error.IntegerOverflow;
    if (output.len < output_len) return error.OutputTooSmall;
    const payload_len = std.math.cast(usize, info.stored_size) orelse return error.IntegerOverflow;
    const total_len = try encodedSize(payload_len);
    if (input.len < total_len) return error.TruncatedFrame;
    const payload = input[header_len..total_len];
    switch (info.flags) {
        flags_dictionary_patch => {
            const written = try dictionary.decodePatchInto(dict, payload, output[0..output_len]);
            if (written != output_len) return error.SizeMismatch;
        },
        flags_dictionary_deflate => {
            // A deflate-wrapped dictionary frame still has to inflate the patch
            // payload first because the patch header is inside the compressed
            // stream. The final patch materialization nevertheless writes into
            // the caller-owned frame output buffer instead of allocating the
            // decoded user payload.
            const patch_limit = try dictionary.maxPatchSizeForDecodedLen(output_len);
            const patch = try deflate.decodeRawAutoAllocLimited(allocator, payload, patch_limit);
            defer allocator.free(patch);
            const written = try dictionary.decodePatchInto(dict, patch, output[0..output_len]);
            if (written != output_len) return error.SizeMismatch;
        },
        else => return error.CorruptFrame,
    }
    if (checksum.crc32(output[0..output_len]) != info.checksum) return error.ChecksumMismatch;
    return output_len;
}

pub fn decode(input: []const u8, output: []u8) Error!usize {
    const info = try parseHeader(input);
    const payload_len = try payloadLenFromInfo(info);
    const total_len = try encodedSize(payload_len);
    if (input.len < total_len) return error.TruncatedFrame;
    if (output.len < payload_len) return error.OutputTooSmall;

    const payload = input[header_len..total_len];
    if (checksum.crc32(payload) != info.checksum) return error.ChecksumMismatch;
    @memcpy(output[0..payload_len], payload);
    return payload_len;
}

/// Allocate and decode a store frame. The caller owns the returned slice.
pub fn decodeAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    const info = try parseHeader(input);
    const output_len = std.math.cast(usize, info.uncompressed_size) orelse return error.IntegerOverflow;
    const out = try allocator.alloc(u8, output_len);
    errdefer allocator.free(out);
    const written = try decode(input, out);
    std.debug.assert(written == out.len);
    return out;
}

pub fn parseHeader(input: []const u8) Error!FrameInfo {
    if (input.len < header_len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..4], &magic)) return error.InvalidMagic;
    const version = input[4];
    if (version != current_version) return error.UnsupportedVersion;
    const flags = input[5];
    if (flags != flags_none and flags != flags_deflate and flags != flags_rle and flags != flags_dictionary_patch and flags != flags_dictionary_deflate and flags != flags_ldm) return error.CorruptFrame;
    if (input[6] != 0 or input[7] != 0) return error.CorruptFrame;
    if (std.mem.readInt(u32, input[28..32], .little) != 0) return error.CorruptFrame;

    return .{
        .version = version,
        .flags = flags,
        .uncompressed_size = std.mem.readInt(u64, input[8..16], .little),
        .stored_size = std.mem.readInt(u64, input[16..24], .little),
        .checksum = std.mem.readInt(u32, input[24..28], .little),
    };
}

fn payloadLenFromInfo(info: FrameInfo) Error!usize {
    if (info.uncompressed_size != info.stored_size) return error.CorruptFrame;
    return std.math.cast(usize, info.stored_size) orelse error.IntegerOverflow;
}

fn storedPayloadLenFromInfo(info: FrameInfo) Error!usize {
    return std.math.cast(usize, info.stored_size) orelse error.IntegerOverflow;
}

fn frameLenFromInfo(info: FrameInfo) Error!usize {
    return encodedSize(try storedPayloadLenFromInfo(info));
}

fn writeHeader(header: []u8, info: FrameInfo) void {
    std.debug.assert(header.len >= header_len);
    @memcpy(header[0..4], &magic);
    header[4] = info.version;
    header[5] = info.flags;
    header[6] = 0;
    header[7] = 0;
    std.mem.writeInt(u64, header[8..16], info.uncompressed_size, .little);
    std.mem.writeInt(u64, header[16..24], info.stored_size, .little);
    std.mem.writeInt(u32, header[24..28], info.checksum, .little);
    std.mem.writeInt(u32, header[28..32], 0, .little);
}

/// Bounded-buffer streaming encoder for one store frame.
pub const Encoder = struct {
    input: []const u8,
    phase: Phase = .header,
    offset: usize = 0,
    header: [header_len]u8 = undefined,

    const Phase = enum { header, payload, done };

    pub fn init(input: []const u8) Encoder {
        var self = Encoder{ .input = input };
        writeHeader(&self.header, .{
            .version = current_version,
            .flags = flags_none,
            .uncompressed_size = @intCast(input.len),
            .stored_size = @intCast(input.len),
            .checksum = checksum.crc32(input),
        });
        return self;
    }

    pub fn step(self: *Encoder, output: []u8) StepResult {
        if (self.phase == .done) return .{ .status = .done };
        if (output.len == 0) return .{ .status = .need_output };

        var written: usize = 0;
        while (written < output.len) {
            switch (self.phase) {
                .header => {
                    const remaining = self.header[self.offset..];
                    const n = @min(output.len - written, remaining.len);
                    @memcpy(output[written..][0..n], remaining[0..n]);
                    written += n;
                    self.offset += n;
                    if (self.offset == self.header.len) {
                        self.phase = .payload;
                        self.offset = 0;
                    } else break;
                },
                .payload => {
                    const remaining = self.input[self.offset..];
                    const n = @min(output.len - written, remaining.len);
                    @memcpy(output[written..][0..n], remaining[0..n]);
                    written += n;
                    self.offset += n;
                    if (self.offset == self.input.len) {
                        self.phase = .done;
                        self.offset = 0;
                        break;
                    } else break;
                },
                .done => break,
            }
        }
        return .{
            .progress = .{ .output_written = written },
            .status = if (self.phase == .done) .done else .need_output,
        };
    }
};

/// Incremental input/output store-frame decoder.
///
/// Unlike `Decoder`, this type accepts the frame bytes in arbitrary chunks and
/// emits payload bytes into caller-provided output chunks. Checksum validation
/// happens when the final payload byte is consumed; callers should treat output
/// from a frame that later reports `ChecksumMismatch` as untrusted.
pub const IncrementalDecoder = struct {
    phase: Phase = .header,
    header: [header_len]u8 = undefined,
    header_received: usize = 0,
    info: FrameInfo = undefined,
    payload_remaining: usize = 0,
    crc: checksum.Crc32 = .{},

    const Phase = enum { header, payload, done };

    pub fn init() IncrementalDecoder {
        return .{ .crc = checksum.Crc32.init() };
    }

    pub fn step(self: *IncrementalDecoder, input: []const u8, output: []u8) Error!StepResult {
        if (self.phase == .done) return .{ .status = .done };

        var read: usize = 0;
        var written: usize = 0;

        while (true) {
            switch (self.phase) {
                .header => {
                    if (read == input.len) {
                        return .{
                            .progress = .{ .input_read = read, .output_written = written },
                            .status = .need_input,
                        };
                    }
                    const needed = header_len - self.header_received;
                    const n = @min(needed, input.len - read);
                    @memcpy(self.header[self.header_received..][0..n], input[read..][0..n]);
                    self.header_received += n;
                    read += n;
                    if (self.header_received != header_len) continue;

                    self.info = try parseHeader(&self.header);
                    self.payload_remaining = try payloadLenFromInfo(self.info);
                    self.crc = checksum.Crc32.init();
                    self.phase = .payload;
                },
                .payload => {
                    if (self.payload_remaining == 0) {
                        if (self.crc.digest() != self.info.checksum) return error.ChecksumMismatch;
                        self.phase = .done;
                        return .{
                            .progress = .{ .input_read = read, .output_written = written },
                            .status = .done,
                        };
                    }
                    if (written == output.len) {
                        return .{
                            .progress = .{ .input_read = read, .output_written = written },
                            .status = .need_output,
                        };
                    }
                    if (read == input.len) {
                        return .{
                            .progress = .{ .input_read = read, .output_written = written },
                            .status = .need_input,
                        };
                    }

                    const n = @min(self.payload_remaining, @min(input.len - read, output.len - written));
                    const source = input[read..][0..n];
                    @memcpy(output[written..][0..n], source);
                    self.crc.update(source);
                    self.payload_remaining -= n;
                    read += n;
                    written += n;
                },
                .done => {
                    return .{
                        .progress = .{ .input_read = read, .output_written = written },
                        .status = .done,
                    };
                },
            }
        }
    }
};

pub const FrameSpan = struct {
    offset: usize,
    frame: []const u8,
    payload: []const u8,
    info: FrameInfo,
};

/// Iterator over concatenated native store frames.
pub const ConcatIterator = struct {
    input: []const u8,
    offset: usize = 0,

    pub fn init(input: []const u8) ConcatIterator {
        return .{ .input = input };
    }

    pub fn next(self: *ConcatIterator) Error!?FrameSpan {
        while (true) {
            if (self.offset == self.input.len) return null;
            const tail = self.input[self.offset..];
            if (tail.len >= 4 and std.mem.eql(u8, tail[0..4], &skippable_magic)) {
                const total = try skippableTotalLen(tail);
                if (tail.len < total) return error.TruncatedFrame;
                self.offset += total;
                continue;
            }
            const info = try parseHeader(tail);
            const total_len = try frameLenFromInfo(info);
            if (tail.len < total_len) return error.TruncatedFrame;

            const start = self.offset;
            const frame = tail[0..total_len];
            self.offset += total_len;
            return .{
                .offset = start,
                .frame = frame,
                .payload = frame[header_len..total_len],
                .info = info,
            };
        }
    }
};

pub const FrameIndexEntry = struct {
    frame_offset: usize,
    frame_len: usize,
    uncompressed_offset: u64,
    uncompressed_len: u64,
    checksum: u32,
};

pub fn buildFrameIndexAlloc(allocator: std.mem.Allocator, input: []const u8) ![]FrameIndexEntry {
    var entries: std.ArrayList(FrameIndexEntry) = .empty;
    errdefer entries.deinit(allocator);
    var iterator = ConcatIterator.init(input);
    var uncompressed_offset: u64 = 0;
    while (try iterator.next()) |span| {
        try entries.append(allocator, .{
            .frame_offset = span.offset,
            .frame_len = span.frame.len,
            .uncompressed_offset = uncompressed_offset,
            .uncompressed_len = span.info.uncompressed_size,
            .checksum = span.info.checksum,
        });
        uncompressed_offset = std.math.add(u64, uncompressed_offset, span.info.uncompressed_size) catch return error.IntegerOverflow;
    }
    return entries.toOwnedSlice(allocator);
}

pub const serialized_index_magic = [_]u8{ 'V', 'I', 'D', 'X' };
pub const serialized_index_header_len: usize = 8;
pub const serialized_index_entry_len: usize = 40;

pub fn serializedFrameIndexSize(entry_count: usize) Error!usize {
    const entries_len = std.math.mul(usize, entry_count, serialized_index_entry_len) catch return error.IntegerOverflow;
    return std.math.add(usize, serialized_index_header_len, entries_len) catch error.IntegerOverflow;
}

pub fn encodeFrameIndex(entries: []const FrameIndexEntry, output: []u8) Error!usize {
    const required = try serializedFrameIndexSize(entries.len);
    if (output.len < required) return error.OutputTooSmall;
    @memcpy(output[0..4], &serialized_index_magic);
    std.mem.writeInt(u32, output[4..8], @intCast(entries.len), .little);
    var offset: usize = serialized_index_header_len;
    for (entries) |entry| {
        std.mem.writeInt(u64, output[offset..][0..8], @intCast(entry.frame_offset), .little);
        std.mem.writeInt(u64, output[offset + 8 ..][0..8], @intCast(entry.frame_len), .little);
        std.mem.writeInt(u64, output[offset + 16 ..][0..8], entry.uncompressed_offset, .little);
        std.mem.writeInt(u64, output[offset + 24 ..][0..8], entry.uncompressed_len, .little);
        std.mem.writeInt(u32, output[offset + 32 ..][0..4], entry.checksum, .little);
        std.mem.writeInt(u32, output[offset + 36 ..][0..4], 0, .little);
        offset += serialized_index_entry_len;
    }
    return required;
}

pub fn encodeFrameIndexAlloc(allocator: std.mem.Allocator, entries: []const FrameIndexEntry) ![]u8 {
    const required = try serializedFrameIndexSize(entries.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    const written = try encodeFrameIndex(entries, out);
    std.debug.assert(written == out.len);
    return out;
}

pub fn decodeFrameIndexAlloc(allocator: std.mem.Allocator, input: []const u8) ![]FrameIndexEntry {
    if (input.len < serialized_index_header_len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..4], &serialized_index_magic)) return error.InvalidMagic;
    const count: usize = std.mem.readInt(u32, input[4..8], .little);
    const required = try serializedFrameIndexSize(count);
    if (input.len < required) return error.TruncatedFrame;
    if (input.len != required) return error.TrailingData;
    const entries = try allocator.alloc(FrameIndexEntry, count);
    errdefer allocator.free(entries);
    var offset: usize = serialized_index_header_len;
    for (entries) |*entry| {
        const frame_offset = std.mem.readInt(u64, input[offset..][0..8], .little);
        const frame_len = std.mem.readInt(u64, input[offset + 8 ..][0..8], .little);
        entry.* = .{
            .frame_offset = std.math.cast(usize, frame_offset) orelse return error.IntegerOverflow,
            .frame_len = std.math.cast(usize, frame_len) orelse return error.IntegerOverflow,
            .uncompressed_offset = std.mem.readInt(u64, input[offset + 16 ..][0..8], .little),
            .uncompressed_len = std.mem.readInt(u64, input[offset + 24 ..][0..8], .little),
            .checksum = std.mem.readInt(u32, input[offset + 32 ..][0..4], .little),
        };
        if (std.mem.readInt(u32, input[offset + 36 ..][0..4], .little) != 0) return error.CorruptFrame;
        offset += serialized_index_entry_len;
    }
    return entries;
}

pub fn validateFrameIndex(index: []const FrameIndexEntry) Error!void {
    var expected_uncompressed: u64 = 0;
    var previous_frame_end: usize = 0;
    for (index) |entry| {
        if (entry.frame_len < header_len) return error.CorruptFrame;
        if (entry.uncompressed_len == 0) return error.CorruptFrame;
        if (entry.uncompressed_offset != expected_uncompressed) return error.CorruptFrame;
        if (entry.frame_offset < previous_frame_end) return error.CorruptFrame;
        previous_frame_end = std.math.add(usize, entry.frame_offset, entry.frame_len) catch return error.IntegerOverflow;
        expected_uncompressed = std.math.add(u64, expected_uncompressed, entry.uncompressed_len) catch return error.IntegerOverflow;
    }
}

/// Compose a whole-stream payload CRC from independently indexed frame CRCs.
///
/// Frame headers already store the CRC-32 of each uncompressed frame payload.
/// For indexed/blocked streams this helper computes the CRC-32 of the logical
/// concatenated payload by combining those per-frame checksums instead of
/// decoding or rereading every payload byte. Callers should still use the normal
/// index/frame validation paths when they need to prove the stream bytes match
/// the index; this helper is purely the checksum-composition primitive.
pub fn frameIndexCombinedChecksum(index: []const FrameIndexEntry) Error!u32 {
    return (try summarizeFrameIndex(index)).combined_checksum;
}

pub const FrameIndexSummary = struct {
    frame_count: usize,
    total_uncompressed: u64,
    combined_checksum: u32,
};

pub fn summarizeFrameIndex(index: []const FrameIndexEntry) Error!FrameIndexSummary {
    try validateFrameIndex(index);
    var combined = checksum.crc32("");
    for (index) |entry| {
        combined = checksum.crc32Combine(combined, entry.checksum, entry.uncompressed_len);
    }
    return .{
        .frame_count = index.len,
        .total_uncompressed = if (index.len == 0) 0 else index[index.len - 1].uncompressed_offset + index[index.len - 1].uncompressed_len,
        .combined_checksum = combined,
    };
}

fn validateFrameIndexSummaryExpectations(summary: FrameIndexSummary, options: SidecarValidationOptions) Error!void {
    if (options.expected_total_uncompressed) |expected| {
        if (summary.total_uncompressed != expected) return error.SizeMismatch;
    }
    if (options.expected_checksum) |expected| {
        if (summary.combined_checksum != expected) return error.ChecksumMismatch;
    }
}

pub fn findFrameForOffset(index: []const FrameIndexEntry, uncompressed_offset: u64) ?usize {
    for (index, 0..) |entry, i| {
        if (uncompressed_offset >= entry.uncompressed_offset and uncompressed_offset < entry.uncompressed_offset + entry.uncompressed_len) return i;
    }
    return null;
}

pub fn decodeRangeAlloc(allocator: std.mem.Allocator, input: []const u8, index: []const FrameIndexEntry, offset: u64, length: usize) ![]u8 {
    return decodeRangeWithDictionaryAlloc(allocator, null, input, index, offset, length);
}

pub const RangeDecodeResult = struct {
    bytes: []u8,
    offset: u64,
    crc32: u32,

    pub fn deinit(self: RangeDecodeResult, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
    }
};

pub const RangeDecodeIntoResult = struct {
    output_written: usize,
    offset: u64,
    crc32: u32,
};

pub const RangeRequest = struct {
    offset: u64,
    length: usize,
};

pub const RangeIntoRequest = struct {
    offset: u64,
    length: usize,
    output: []u8,
};

pub const RangeBatchDecodeResult = struct {
    ranges: []RangeDecodeResult,

    pub fn deinit(self: RangeBatchDecodeResult, allocator: std.mem.Allocator) void {
        for (self.ranges) |range| range.deinit(allocator);
        allocator.free(self.ranges);
    }
};

pub fn decodeRangeWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, index: []const FrameIndexEntry, offset: u64, length: usize) !RangeDecodeResult {
    return decodeRangeWithDictionarySummaryAlloc(allocator, null, input, index, offset, length);
}

pub fn decodeRangeWithDictionarySummaryAlloc(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, index: []const FrameIndexEntry, offset: u64, length: usize) !RangeDecodeResult {
    if (length == 0) {
        return .{
            .bytes = try allocator.alloc(u8, 0),
            .offset = offset,
            .crc32 = checksum.crc32(""),
        };
    }
    const bytes = try allocator.alloc(u8, length);
    errdefer allocator.free(bytes);
    const result = try decodeRangeWithDictionaryInto(allocator, dict, input, index, offset, length, bytes);
    return .{
        .bytes = bytes,
        .offset = result.offset,
        .crc32 = result.crc32,
    };
}

pub fn decodeRangesWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, index: []const FrameIndexEntry, requests: []const RangeRequest) !RangeBatchDecodeResult {
    return decodeRangesWithDictionarySummaryAlloc(allocator, null, input, index, requests);
}

pub fn decodeRangesWithDictionarySummaryAlloc(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, index: []const FrameIndexEntry, requests: []const RangeRequest) !RangeBatchDecodeResult {
    try validateFrameIndex(index);
    try validateBatchRangeRequests(index, requests);
    const ranges = try allocator.alloc(RangeDecodeResult, requests.len);
    errdefer allocator.free(ranges);
    var initialized: usize = 0;
    errdefer {
        for (ranges[0..initialized]) |range| range.deinit(allocator);
    }

    const into_requests = try allocator.alloc(RangeIntoRequest, requests.len);
    defer allocator.free(into_requests);
    const into_results = try allocator.alloc(RangeDecodeIntoResult, requests.len);
    defer allocator.free(into_results);

    for (requests, 0..) |request, i| {
        const bytes = try allocator.alloc(u8, request.length);
        ranges[i] = .{
            .bytes = bytes,
            .offset = request.offset,
            .crc32 = 0,
        };
        initialized += 1;
        into_requests[i] = .{
            .offset = request.offset,
            .length = request.length,
            .output = bytes,
        };
    }
    try decodeRangesWithDictionaryInto(allocator, dict, input, index, into_requests, into_results);
    for (into_results, 0..) |result, i| {
        ranges[i].offset = result.offset;
        ranges[i].crc32 = result.crc32;
    }
    return .{ .ranges = ranges };
}

fn validateBatchRangeRequests(index: []const FrameIndexEntry, requests: []const RangeRequest) Error!void {
    const total_uncompressed = if (index.len == 0) 0 else index[index.len - 1].uncompressed_offset + index[index.len - 1].uncompressed_len;
    for (requests) |request| {
        if (request.length == 0) continue;
        const end = std.math.add(u64, request.offset, request.length) catch return error.IntegerOverflow;
        if (end > total_uncompressed) return error.RangeOutOfBounds;
        _ = findFrameForOffset(index, request.offset) orelse return error.RangeOutOfBounds;
    }
}

pub fn decodeRangeInto(allocator: std.mem.Allocator, input: []const u8, index: []const FrameIndexEntry, offset: u64, length: usize, output: []u8) !RangeDecodeIntoResult {
    return decodeRangeWithDictionaryInto(allocator, null, input, index, offset, length, output);
}

pub fn decodeRangesInto(allocator: std.mem.Allocator, input: []const u8, index: []const FrameIndexEntry, requests: []const RangeIntoRequest, results: []RangeDecodeIntoResult) !void {
    return decodeRangesWithDictionaryInto(allocator, null, input, index, requests, results);
}

pub fn decodeRangesWithDictionaryInto(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, index: []const FrameIndexEntry, requests: []const RangeIntoRequest, results: []RangeDecodeIntoResult) !void {
    // Decode many ranges with one structural index validation and one decoded
    // copy per referenced frame. This matters for small random reads over
    // indexed streams where several logical ranges often land in the same
    // compressed frame.
    try validateFrameIndex(index);
    try validateBatchRangeIntoRequests(index, requests, results);
    var decoded_cache = LazyDecodedFrameCache.init(allocator, index.len);
    defer decoded_cache.deinit();
    for (requests, 0..) |request, i| {
        results[i] = try decodeRangeWithDictionaryIntoValidated(allocator, dict, input, index, request.offset, request.length, request.output, &decoded_cache);
    }
}

const LazyDecodedFrameCache = struct {
    allocator: std.mem.Allocator,
    frame_count: usize,
    entries: ?[]?[]u8 = null,

    fn init(allocator: std.mem.Allocator, frame_count: usize) LazyDecodedFrameCache {
        return .{ .allocator = allocator, .frame_count = frame_count };
    }

    fn deinit(self: *LazyDecodedFrameCache) void {
        if (self.entries) |entries| {
            for (entries) |maybe_decoded| {
                if (maybe_decoded) |decoded| self.allocator.free(decoded);
            }
            self.allocator.free(entries);
            self.entries = null;
        }
    }

    fn slice(self: *LazyDecodedFrameCache) ![]?[]u8 {
        if (self.entries) |entries| return entries;
        const entries = try self.allocator.alloc(?[]u8, self.frame_count);
        @memset(entries, null);
        self.entries = entries;
        return entries;
    }
};

fn validateBatchRangeIntoRequests(index: []const FrameIndexEntry, requests: []const RangeIntoRequest, results: []RangeDecodeIntoResult) Error!void {
    if (results.len < requests.len) return error.OutputTooSmall;
    const total_uncompressed = if (index.len == 0) 0 else index[index.len - 1].uncompressed_offset + index[index.len - 1].uncompressed_len;
    for (requests) |request| {
        if (request.output.len < request.length) return error.OutputTooSmall;
        if (request.length == 0) continue;
        const end = std.math.add(u64, request.offset, request.length) catch return error.IntegerOverflow;
        if (end > total_uncompressed) return error.RangeOutOfBounds;
        _ = findFrameForOffset(index, request.offset) orelse return error.RangeOutOfBounds;
    }
}

pub fn decodeRangeWithDictionaryInto(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, index: []const FrameIndexEntry, offset: u64, length: usize, output: []u8) !RangeDecodeIntoResult {
    if (output.len < length) return error.OutputTooSmall;
    try validateFrameIndex(index);
    return decodeRangeWithDictionaryIntoValidated(allocator, dict, input, index, offset, length, output, null);
}

fn decodeRangeWithDictionaryIntoValidated(
    allocator: std.mem.Allocator,
    dict: ?[]const u8,
    input: []const u8,
    index: []const FrameIndexEntry,
    offset: u64,
    length: usize,
    output: []u8,
    decoded_cache: ?*LazyDecodedFrameCache,
) !RangeDecodeIntoResult {
    var crc = checksum.Crc32.init();
    if (length == 0) {
        return .{
            .output_written = 0,
            .offset = offset,
            .crc32 = crc.digest(),
        };
    }
    const end = std.math.add(u64, offset, length) catch return error.IntegerOverflow;
    const start_i = findFrameForOffset(index, offset) orelse return error.RangeOutOfBounds;
    var written: usize = 0;
    var i = start_i;
    while (i < index.len and written < length) : (i += 1) {
        const entry = index[i];
        if (entry.uncompressed_offset >= end) break;
        if (try copyStoredRangeIntoIfPossible(input, entry, offset, end, output, &written, &crc)) continue;
        if (try copyRleRangeIntoIfPossible(input, entry, offset, end, output, &written, &crc)) continue;
        if (try copyFullDeflateRangeIntoIfPossible(input, entry, offset, end, output, &written, &crc)) continue;
        if (try copyFullDictionaryRangeIntoIfPossible(allocator, dict, input, entry, offset, end, output, &written, &crc)) continue;
        if (try copyFullLongDistanceRangeIntoIfPossible(input, entry, offset, end, output, &written, &crc)) continue;
        const decoded = try decodedFrameForRange(allocator, dict, input, entry, i, decoded_cache);
        defer if (decoded_cache == null) allocator.free(decoded);
        const frame_start = entry.uncompressed_offset;
        const frame_end = entry.uncompressed_offset + entry.uncompressed_len;
        const copy_start = if (offset > frame_start) offset - frame_start else 0;
        const copy_end_global = @min(end, frame_end);
        const copy_end = copy_end_global - frame_start;
        if (copy_end > copy_start) {
            const slice = decoded[@intCast(copy_start)..@intCast(copy_end)];
            @memcpy(output[written..][0..slice.len], slice);
            crc.update(slice);
            written += slice.len;
        }
    }
    if (written != length) return error.RangeOutOfBounds;
    return .{
        .output_written = written,
        .offset = offset,
        .crc32 = crc.digest(),
    };
}

fn copyStoredRangeIntoIfPossible(
    input: []const u8,
    entry: FrameIndexEntry,
    range_offset: u64,
    range_end: u64,
    output: []u8,
    written: *usize,
    crc: *checksum.Crc32,
) !bool {
    if (input.len - entry.frame_offset < entry.frame_len) return error.TruncatedFrame;
    const frame = input[entry.frame_offset..][0..entry.frame_len];
    const frame_info = try parseHeader(frame);
    if (frame_info.flags != flags_none) return false;
    if (entry.frame_len != try frameLenFromInfo(frame_info)) return error.CorruptFrame;
    if (entry.checksum != frame_info.checksum) return error.ChecksumMismatch;
    if (entry.uncompressed_len != frame_info.uncompressed_size) return error.CorruptFrame;

    const payload_len = try payloadLenFromInfo(frame_info);
    const payload = frame[header_len..][0..payload_len];
    if (checksum.crc32(payload) != frame_info.checksum) return error.ChecksumMismatch;

    const frame_start = entry.uncompressed_offset;
    const frame_end = entry.uncompressed_offset + entry.uncompressed_len;
    const copy_start = if (range_offset > frame_start) range_offset - frame_start else 0;
    const copy_end_global = @min(range_end, frame_end);
    const copy_end = copy_end_global - frame_start;
    if (copy_end > copy_start) {
        const slice = payload[@intCast(copy_start)..@intCast(copy_end)];
        @memcpy(output[written.*..][0..slice.len], slice);
        crc.update(slice);
        written.* += slice.len;
    }
    return true;
}

fn copyRleRangeIntoIfPossible(
    input: []const u8,
    entry: FrameIndexEntry,
    range_offset: u64,
    range_end: u64,
    output: []u8,
    written: *usize,
    range_crc: *checksum.Crc32,
) !bool {
    if (input.len - entry.frame_offset < entry.frame_len) return error.TruncatedFrame;
    const frame = input[entry.frame_offset..][0..entry.frame_len];
    const frame_info = try parseHeader(frame);
    if (frame_info.flags != flags_rle) return false;
    if (entry.frame_len != try frameLenFromInfo(frame_info)) return error.CorruptFrame;
    if (entry.checksum != frame_info.checksum) return error.ChecksumMismatch;
    if (entry.uncompressed_len != frame_info.uncompressed_size) return error.CorruptFrame;

    const expected_len = std.math.cast(usize, entry.uncompressed_len) orelse return error.IntegerOverflow;
    const payload_len = std.math.cast(usize, frame_info.stored_size) orelse return error.IntegerOverflow;
    const payload = frame[header_len..][0..payload_len];
    if ((payload.len & 1) != 0) return error.CorruptFrame;

    const frame_start = entry.uncompressed_offset;
    const frame_end = entry.uncompressed_offset + entry.uncompressed_len;
    const copy_start = std.math.cast(usize, if (range_offset > frame_start) range_offset - frame_start else 0) orelse return error.IntegerOverflow;
    const copy_end_global = @min(range_end, frame_end);
    const copy_end = std.math.cast(usize, copy_end_global - frame_start) orelse return error.IntegerOverflow;

    var frame_crc = checksum.Crc32.init();
    var decoded_pos: usize = 0;
    var offset: usize = 0;
    var run_buf: [255]u8 = undefined;
    while (offset < payload.len) : (offset += 2) {
        const run: usize = payload[offset];
        const byte = payload[offset + 1];
        if (run == 0) return error.CorruptFrame;
        if (decoded_pos > expected_len) return error.SizeMismatch;
        if (run > expected_len - decoded_pos) return error.SizeMismatch;
        @memset(run_buf[0..run], byte);
        frame_crc.update(run_buf[0..run]);

        const run_start = decoded_pos;
        const run_end = decoded_pos + run;
        const overlap_start = @max(copy_start, run_start);
        const overlap_end = @min(copy_end, run_end);
        if (overlap_end > overlap_start) {
            const copy_len = overlap_end - overlap_start;
            @memset(output[written.*..][0..copy_len], byte);
            range_crc.update(output[written.*..][0..copy_len]);
            written.* += copy_len;
        }
        decoded_pos = run_end;
    }
    if (decoded_pos != expected_len) return error.SizeMismatch;
    if (frame_crc.digest() != frame_info.checksum) return error.ChecksumMismatch;
    return true;
}

fn copyFullDeflateRangeIntoIfPossible(
    input: []const u8,
    entry: FrameIndexEntry,
    range_offset: u64,
    range_end: u64,
    output: []u8,
    written: *usize,
    crc: *checksum.Crc32,
) !bool {
    if (range_offset > entry.uncompressed_offset) return false;
    if (range_end < entry.uncompressed_offset + entry.uncompressed_len) return false;
    if (input.len - entry.frame_offset < entry.frame_len) return error.TruncatedFrame;
    const frame = input[entry.frame_offset..][0..entry.frame_len];
    const frame_info = try parseHeader(frame);
    if (frame_info.flags != flags_deflate) return false;
    if (entry.frame_len != try frameLenFromInfo(frame_info)) return error.CorruptFrame;
    if (entry.checksum != frame_info.checksum) return error.ChecksumMismatch;
    if (entry.uncompressed_len != frame_info.uncompressed_size) return error.CorruptFrame;

    const output_len = std.math.cast(usize, entry.uncompressed_len) orelse return error.IntegerOverflow;
    const payload_len = std.math.cast(usize, frame_info.stored_size) orelse return error.IntegerOverflow;
    const payload = frame[header_len..][0..payload_len];
    const target = output[written.*..][0..output_len];
    const decoded = try deflate.decodeRawAuto(payload, target);
    if (decoded.output_written != output_len) return error.SizeMismatch;
    if (decoded.input_read != payload.len) return error.TrailingData;
    const actual_crc = checksum.crc32(target);
    if (actual_crc != frame_info.checksum) return error.ChecksumMismatch;
    crc.update(target);
    written.* += target.len;
    return true;
}

fn copyFullDictionaryRangeIntoIfPossible(
    allocator: std.mem.Allocator,
    dict: ?[]const u8,
    input: []const u8,
    entry: FrameIndexEntry,
    range_offset: u64,
    range_end: u64,
    output: []u8,
    written: *usize,
    crc: *checksum.Crc32,
) !bool {
    if (range_offset > entry.uncompressed_offset) return false;
    if (range_end < entry.uncompressed_offset + entry.uncompressed_len) return false;
    if (input.len - entry.frame_offset < entry.frame_len) return error.TruncatedFrame;
    const frame = input[entry.frame_offset..][0..entry.frame_len];
    const frame_info = try parseHeader(frame);
    if (frame_info.flags != flags_dictionary_patch and frame_info.flags != flags_dictionary_deflate) return false;
    const dictionary_bytes = dict orelse return error.InvalidDictionaryTraining;
    if (entry.frame_len != try frameLenFromInfo(frame_info)) return error.CorruptFrame;
    if (entry.checksum != frame_info.checksum) return error.ChecksumMismatch;
    if (entry.uncompressed_len != frame_info.uncompressed_size) return error.CorruptFrame;

    const output_len = std.math.cast(usize, entry.uncompressed_len) orelse return error.IntegerOverflow;
    const target = output[written.*..][0..output_len];
    const decoded = try decodeDictionaryPatchInto(allocator, dictionary_bytes, frame, target);
    if (decoded != output_len) return error.SizeMismatch;
    crc.update(target);
    written.* += target.len;
    return true;
}

fn copyFullLongDistanceRangeIntoIfPossible(
    input: []const u8,
    entry: FrameIndexEntry,
    range_offset: u64,
    range_end: u64,
    output: []u8,
    written: *usize,
    crc: *checksum.Crc32,
) !bool {
    if (range_offset > entry.uncompressed_offset) return false;
    if (range_end < entry.uncompressed_offset + entry.uncompressed_len) return false;
    if (input.len - entry.frame_offset < entry.frame_len) return error.TruncatedFrame;
    const frame = input[entry.frame_offset..][0..entry.frame_len];
    const frame_info = try parseHeader(frame);
    if (frame_info.flags != flags_ldm) return false;
    if (entry.frame_len != try frameLenFromInfo(frame_info)) return error.CorruptFrame;
    if (entry.checksum != frame_info.checksum) return error.ChecksumMismatch;
    if (entry.uncompressed_len != frame_info.uncompressed_size) return error.CorruptFrame;

    const output_len = std.math.cast(usize, entry.uncompressed_len) orelse return error.IntegerOverflow;
    const target = output[written.*..][0..output_len];
    const decoded = try decodeLongDistanceInto(frame, target);
    if (decoded != output_len) return error.SizeMismatch;
    crc.update(target);
    written.* += target.len;
    return true;
}

fn decodedFrameForRange(
    allocator: std.mem.Allocator,
    dict: ?[]const u8,
    input: []const u8,
    entry: FrameIndexEntry,
    index_position: usize,
    decoded_cache: ?*LazyDecodedFrameCache,
) ![]u8 {
    if (decoded_cache) |lazy_cache| {
        const cache = try lazy_cache.slice();
        if (cache[index_position]) |decoded| return decoded;
        const decoded = try decodeIndexedFramePayloadAlloc(allocator, dict, input, entry);
        cache[index_position] = decoded;
        return decoded;
    }
    return decodeIndexedFramePayloadAlloc(allocator, dict, input, entry);
}

fn decodeIndexedFramePayloadAlloc(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, entry: FrameIndexEntry) ![]u8 {
    if (input.len - entry.frame_offset < entry.frame_len) return error.TruncatedFrame;
    const frame = input[entry.frame_offset..][0..entry.frame_len];
    const frame_info = try parseHeader(frame);
    if (entry.frame_len != try frameLenFromInfo(frame_info)) return error.CorruptFrame;
    if (entry.checksum != frame_info.checksum) return error.ChecksumMismatch;
    if (entry.uncompressed_len != frame_info.uncompressed_size) return error.CorruptFrame;
    return if (frame_info.flags == flags_dictionary_patch or frame_info.flags == flags_dictionary_deflate) blk: {
        const dictionary_bytes = dict orelse return error.InvalidDictionaryTraining;
        break :blk try decodeDictionaryPatchAlloc(allocator, dictionary_bytes, frame);
    } else try decodeAnyAlloc(allocator, frame);
}

pub fn decodeRangeWithDictionaryAlloc(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, index: []const FrameIndexEntry, offset: u64, length: usize) ![]u8 {
    if (length == 0) return allocator.alloc(u8, 0);
    const out = try allocator.alloc(u8, length);
    errdefer allocator.free(out);
    const result = try decodeRangeWithDictionaryInto(allocator, dict, input, index, offset, length, out);
    std.debug.assert(result.output_written == out.len);
    return out;
}

pub const SidecarIndexedStream = struct {
    stream: []u8,
    sidecar_index: []u8,

    pub fn deinit(self: SidecarIndexedStream, allocator: std.mem.Allocator) void {
        allocator.free(self.stream);
        allocator.free(self.sidecar_index);
    }
};

pub const SeekableNativeOptions = struct {
    block_len: usize = 8192,
    deflate_options: deflate.CompressionOptions = .{},
    dictionary: Dictionary = .{},
    long_distance: LongDistance = .{},

    pub const Dictionary = struct {
        enable: bool = false,
        target_size: usize = 256,
        min_match_len: usize = 8,
        max_phrase_len: usize = 24,
        max_phrases: usize = 512,
    };

    pub const LongDistance = struct {
        enable: bool = false,
        options: long_distance.Options = .{},
        align_blocks: bool = true,
        embed_summary: bool = true,
    };
};

pub fn encodeSeekableNativeStreamAlloc(allocator: std.mem.Allocator, input: []const u8, options: SeekableNativeOptions) ![]u8 {
    var sidecar = try encodeSeekableNativeSidecarStreamAlloc(allocator, input, options);
    defer sidecar.deinit(allocator);
    return embedSidecarIndexAlloc(allocator, sidecar.stream, sidecar.sidecar_index);
}

pub fn encodeSeekableNativeSidecarStreamAlloc(allocator: std.mem.Allocator, input: []const u8, options: SeekableNativeOptions) !SidecarIndexedStream {
    if (options.block_len == 0) return error.InvalidBlockPlan;
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);

    var trained_dict: ?[]u8 = null;
    defer if (trained_dict) |dict| allocator.free(dict);
    if (options.dictionary.enable) {
        trained_dict = try dictionary.trainAlloc(allocator, &.{input}, .{
            .target_size = options.dictionary.target_size,
            .min_phrase_len = options.dictionary.min_match_len,
            .max_phrase_len = options.dictionary.max_phrase_len,
            .max_phrases = options.dictionary.max_phrases,
        });
        if (trained_dict) |dict| {
            if (dict.len != 0) {
                const dict_payload = try encodeEmbeddedDictionaryBytesAlloc(allocator, dict);
                defer allocator.free(dict_payload);
                const dict_frame = try encodeSkippableAlloc(allocator, dict_payload);
                defer allocator.free(dict_frame);
                try stream.appendSlice(allocator, dict_frame);
            }
        }
    }

    const blocks = if (options.long_distance.enable and options.long_distance.align_blocks)
        try @import("planner.zig").planBlocksAligningLongDistanceAlloc(allocator, input, .{ .block_len = options.block_len, .worker_count = 1 }, options.long_distance.options)
    else
        try @import("planner.zig").planBlocksAlloc(allocator, input.len, .{ .block_len = options.block_len, .worker_count = 1 });
    defer allocator.free(blocks);

    for (blocks) |block| {
        const chunk = input[block.input_offset..][0..block.input_len];
        const frame = try encodeSeekableNativeBlockAlloc(allocator, trained_dict, chunk, options);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    if (input.len == 0) {
        const frame = try encodeSeekableNativeBlockAlloc(allocator, trained_dict, "", options);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }

    if (options.long_distance.enable and options.long_distance.embed_summary) {
        const summary = try long_distance.summarizeAlloc(allocator, input, options.long_distance.options);
        const summary_bytes = encodeLdmSummaryBytes(summary);
        const summary_frame = try encodeSkippableAlloc(allocator, &summary_bytes);
        defer allocator.free(summary_frame);
        try stream.appendSlice(allocator, summary_frame);
    }

    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const sidecar_index = try encodeFrameIndexAlloc(allocator, index);
    errdefer allocator.free(sidecar_index);
    return .{ .stream = try stream.toOwnedSlice(allocator), .sidecar_index = sidecar_index };
}

fn encodeSeekableNativeBlockAlloc(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, options: SeekableNativeOptions) ![]u8 {
    const native_best = try encodeBlockBestAlloc(allocator, input, options.deflate_options);
    errdefer allocator.free(native_best);
    var best = native_best;

    if (dict) |dictionary_bytes| {
        if (dictionary_bytes.len != 0) {
            const dict_frame = try encodeBestWithDictionaryAlloc(allocator, dictionary_bytes, input, options.dictionary.min_match_len);
            errdefer allocator.free(dict_frame);
            if (dict_frame.len < best.len) {
                allocator.free(best);
                best = dict_frame;
            } else {
                allocator.free(dict_frame);
            }
        }
    }

    if (options.long_distance.enable) {
        const ldm_frame = try encodeLongDistanceAlloc(allocator, input, options.long_distance.options);
        errdefer allocator.free(ldm_frame);
        if (ldm_frame.len < best.len) {
            allocator.free(best);
            best = ldm_frame;
        } else {
            allocator.free(ldm_frame);
        }
    }

    return best;
}

fn embedSidecarIndexAlloc(allocator: std.mem.Allocator, stream_bytes: []const u8, sidecar_index: []const u8) ![]u8 {
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, stream_bytes);
    const index_frame = try encodeSkippableAlloc(allocator, sidecar_index);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

pub fn encodeSidecarIndexedStreamAlloc(allocator: std.mem.Allocator, frames: []const []const u8) !SidecarIndexedStream {
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    for (frames) |payload| {
        const frame = try encodeAlloc(allocator, payload);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const sidecar_index = try encodeFrameIndexAlloc(allocator, index);
    errdefer allocator.free(sidecar_index);
    return .{ .stream = try stream.toOwnedSlice(allocator), .sidecar_index = sidecar_index };
}

pub fn encodeIndexedStreamAlloc(allocator: std.mem.Allocator, frames: []const []const u8) ![]u8 {
    var sidecar = try encodeSidecarIndexedStreamAlloc(allocator, frames);
    defer sidecar.deinit(allocator);
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, sidecar.stream);
    const index_frame = try encodeSkippableAlloc(allocator, sidecar.sidecar_index);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

pub fn encodeIndexedDeflateStreamAlloc(allocator: std.mem.Allocator, frames: []const []const u8) ![]u8 {
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    for (frames) |payload| {
        const frame = try encodeBestAlloc(allocator, payload);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const index_bytes = try encodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try encodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

pub fn encodeIndexedLongDistanceStreamAlloc(allocator: std.mem.Allocator, frames: []const []const u8, options: long_distance.Options) ![]u8 {
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    for (frames) |payload| {
        const frame = try encodeBestWithLongDistanceAlloc(allocator, payload, options);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const index_bytes = try encodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try encodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

pub fn encodeBlockedDeflateStreamAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize) ![]u8 {
    if (block_len == 0) return error.InvalidBlockPlan;
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const n = @min(block_len, input.len - offset);
        const frame = try encodeBestAlloc(allocator, input[offset..][0..n]);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
        offset += n;
    }
    if (input.len == 0) {
        const frame = try encodeBestAlloc(allocator, "");
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const index_bytes = try encodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try encodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

pub fn encodeBlockedBestStreamAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize) ![]u8 {
    return encodeBlockedBestStreamWithOptionsAlloc(allocator, input, block_len, .{});
}

pub fn encodeSidecarBlockedBestStreamWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: deflate.CompressionOptions) !SidecarIndexedStream {
    if (block_len == 0) return error.InvalidBlockPlan;
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    var offset: usize = 0;
    while (offset < input.len) {
        const n = @min(block_len, input.len - offset);
        const frame = try encodeBlockBestAlloc(allocator, input[offset..][0..n], options);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
        offset += n;
    }
    if (input.len == 0) {
        const frame = try encodeBlockBestAlloc(allocator, "", options);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const sidecar_index = try encodeFrameIndexAlloc(allocator, index);
    errdefer allocator.free(sidecar_index);
    return .{ .stream = try stream.toOwnedSlice(allocator), .sidecar_index = sidecar_index };
}

pub fn encodeSidecarBlockedBestStreamAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize) !SidecarIndexedStream {
    return encodeSidecarBlockedBestStreamWithOptionsAlloc(allocator, input, block_len, .{});
}

pub fn encodeBlockedBestStreamWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: deflate.CompressionOptions) ![]u8 {
    var sidecar = try encodeSidecarBlockedBestStreamWithOptionsAlloc(allocator, input, block_len, options);
    defer sidecar.deinit(allocator);
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, sidecar.stream);
    const index_frame = try encodeSkippableAlloc(allocator, sidecar.sidecar_index);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

pub fn encodeSidecarBlockedBestStreamWithLdmAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: deflate.CompressionOptions, ldm_options: long_distance.Options) !SidecarIndexedStream {
    var stream = try std.ArrayList(u8).initCapacity(allocator, 0);
    errdefer stream.deinit(allocator);
    const plan = try @import("planner.zig").planBlocksAlloc(allocator, input.len, .{ .block_len = block_len, .worker_count = 1 });
    defer allocator.free(plan);
    for (plan) |block| {
        const frame = try encodeBlockBestWithLdmAlloc(allocator, input[block.input_offset..][0..block.input_len], options, ldm_options);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    if (input.len == 0) {
        const frame = try encodeBlockBestWithLdmAlloc(allocator, "", options, ldm_options);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const sidecar_index = try encodeFrameIndexAlloc(allocator, index);
    errdefer allocator.free(sidecar_index);
    return .{ .stream = try stream.toOwnedSlice(allocator), .sidecar_index = sidecar_index };
}

pub fn encodeBlockedBestStreamWithLdmAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: deflate.CompressionOptions, ldm_options: long_distance.Options) ![]u8 {
    var sidecar = try encodeSidecarBlockedBestStreamWithLdmAlloc(allocator, input, block_len, options, ldm_options);
    defer sidecar.deinit(allocator);
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, sidecar.stream);
    const index_frame = try encodeSkippableAlloc(allocator, sidecar.sidecar_index);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

pub fn encodeBlockedBestStreamWithLdmSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, options: deflate.CompressionOptions, ldm_options: long_distance.Options) ![]u8 {
    var stream = try std.ArrayList(u8).initCapacity(allocator, 0);
    errdefer stream.deinit(allocator);
    const plan = try @import("planner.zig").planBlocksAligningLongDistanceAlloc(allocator, input, .{ .block_len = block_len, .worker_count = 1 }, ldm_options);
    defer allocator.free(plan);
    for (plan) |block| {
        const frame = try encodeBlockBestAlloc(allocator, input[block.input_offset..][0..block.input_len], options);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    if (input.len == 0) {
        const frame = try encodeBlockBestAlloc(allocator, "", options);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const index_bytes = try encodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try encodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    const summary = try long_distance.summarizeAlloc(allocator, input, ldm_options);
    const summary_bytes = encodeLdmSummaryBytes(summary);
    const summary_frame = try encodeSkippableAlloc(allocator, &summary_bytes);
    defer allocator.free(summary_frame);
    try stream.appendSlice(allocator, summary_frame);
    return stream.toOwnedSlice(allocator);
}

fn encodeLdmSummaryBytes(summary: long_distance.Summary) [ldm_summary_len]u8 {
    var out: [ldm_summary_len]u8 = undefined;
    @memcpy(out[0..4], &ldm_summary_magic);
    std.mem.writeInt(u64, out[4..12], @intCast(summary.candidates), .little);
    std.mem.writeInt(u64, out[12..20], @intCast(summary.longest), .little);
    std.mem.writeInt(u64, out[20..28], @intCast(summary.max_distance), .little);
    return out;
}

pub fn parseLdmSummary(input: []const u8) Error!long_distance.Summary {
    if (input.len != ldm_summary_len) return error.TruncatedFrame;
    if (!std.mem.eql(u8, input[0..4], &ldm_summary_magic)) return error.InvalidMagic;
    return .{
        .candidates = std.math.cast(usize, std.mem.readInt(u64, input[4..12], .little)) orelse return error.IntegerOverflow,
        .longest = std.math.cast(usize, std.mem.readInt(u64, input[12..20], .little)) orelse return error.IntegerOverflow,
        .max_distance = std.math.cast(usize, std.mem.readInt(u64, input[20..28], .little)) orelse return error.IntegerOverflow,
    };
}

fn encodeEmbeddedDictionaryBytesAlloc(allocator: std.mem.Allocator, dict: []const u8) ![]u8 {
    if (dict.len > std.math.maxInt(u32)) return error.IntegerOverflow;
    const out = try allocator.alloc(u8, embedded_dictionary_header_len + dict.len);
    errdefer allocator.free(out);
    @memcpy(out[0..4], &embedded_dictionary_magic);
    const id = dictionary.DictionaryId.fromBytes(dict);
    std.mem.writeInt(u64, out[4..12], id.asInt(), .little);
    std.mem.writeInt(u32, out[12..16], @intCast(dict.len), .little);
    std.mem.writeInt(u32, out[16..20], 0, .little);
    @memcpy(out[embedded_dictionary_header_len..], dict);
    return out;
}

pub fn parseEmbeddedDictionaryAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var offset: usize = 0;
    var found: ?[]const u8 = null;
    while (offset < input.len) {
        const tail = input[offset..];
        if (tail.len >= 4 and std.mem.eql(u8, tail[0..4], &skippable_magic)) {
            const payload = try parseSkippable(tail);
            if (payload.len >= embedded_dictionary_header_len and std.mem.eql(u8, payload[0..4], &embedded_dictionary_magic)) {
                if (std.mem.readInt(u32, payload[16..20], .little) != 0) return error.CorruptFrame;
                const len: usize = std.mem.readInt(u32, payload[12..16], .little);
                if (payload.len - embedded_dictionary_header_len < len) return error.TruncatedFrame;
                const dict = payload[embedded_dictionary_header_len..][0..len];
                const expected_id = std.mem.readInt(u64, payload[4..12], .little);
                if (dictionary.DictionaryId.fromBytes(dict).asInt() != expected_id) return error.ChecksumMismatch;
                found = dict;
            }
            const total = try skippableTotalLen(tail);
            if (tail.len < total) return error.TruncatedFrame;
            offset += total;
        } else {
            const info = try parseHeader(tail);
            const total = try frameLenFromInfo(info);
            if (tail.len < total) return error.TruncatedFrame;
            offset += total;
        }
    }
    const dict = found orelse return error.InvalidMagic;
    return allocator.dupe(u8, dict);
}

pub fn parseEmbeddedLdmSummary(input: []const u8) Error!long_distance.Summary {
    var offset: usize = 0;
    var found: ?long_distance.Summary = null;
    while (offset < input.len) {
        const tail = input[offset..];
        if (tail.len >= 4 and std.mem.eql(u8, tail[0..4], &skippable_magic)) {
            const payload = try parseSkippable(tail);
            if (payload.len >= 4 and std.mem.eql(u8, payload[0..4], &ldm_summary_magic)) found = try parseLdmSummary(payload);
            const total = try skippableTotalLen(tail);
            if (tail.len < total) return error.TruncatedFrame;
            offset += total;
        } else {
            const info = try parseHeader(tail);
            const total = try frameLenFromInfo(info);
            if (tail.len < total) return error.TruncatedFrame;
            offset += total;
        }
    }
    return found orelse error.InvalidMagic;
}

pub fn encodeBlockedBestWithDictionaryStreamAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, block_len: usize, min_match_len: usize) ![]u8 {
    return encodeBlockedBestWithDictionaryStreamInternalAlloc(allocator, dict, input, block_len, min_match_len, false);
}

pub fn encodeSidecarSelfContainedDictionaryStreamAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, target_size: usize, min_match_len: usize) !SidecarIndexedStream {
    const dict = try dictionary.trainAlloc(allocator, &.{input}, .{ .target_size = target_size, .min_phrase_len = min_match_len, .max_phrase_len = 24 });
    defer allocator.free(dict);
    return encodeBlockedBestWithDictionarySidecarStreamInternalAlloc(allocator, dict, input, block_len, min_match_len, true);
}

pub fn encodeSelfContainedDictionaryStreamAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, target_size: usize, min_match_len: usize) ![]u8 {
    const dict = try dictionary.trainAlloc(allocator, &.{input}, .{ .target_size = target_size, .min_phrase_len = min_match_len, .max_phrase_len = 24 });
    defer allocator.free(dict);
    return encodeBlockedBestWithDictionaryStreamInternalAlloc(allocator, dict, input, block_len, min_match_len, true);
}

pub fn encodeBestTrainedDictionaryStreamAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, target_size: usize, min_match_len: usize) ![]u8 {
    const native_best = try encodeBlockedBestStreamAlloc(allocator, input, block_len);
    errdefer allocator.free(native_best);
    const dict_stream = try encodeSelfContainedDictionaryStreamAlloc(allocator, input, block_len, target_size, min_match_len);
    errdefer allocator.free(dict_stream);
    if (dict_stream.len < native_best.len) {
        allocator.free(native_best);
        return dict_stream;
    }
    allocator.free(dict_stream);
    return native_best;
}

fn encodeBlockedBestWithDictionarySidecarStreamInternalAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, block_len: usize, min_match_len: usize, embed_dict: bool) !SidecarIndexedStream {
    if (block_len == 0) return error.InvalidBlockPlan;
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    if (embed_dict) {
        const dict_payload = try encodeEmbeddedDictionaryBytesAlloc(allocator, dict);
        defer allocator.free(dict_payload);
        const dict_frame = try encodeSkippableAlloc(allocator, dict_payload);
        defer allocator.free(dict_frame);
        try stream.appendSlice(allocator, dict_frame);
    }
    var offset: usize = 0;
    while (offset < input.len) {
        const n = @min(block_len, input.len - offset);
        const frame = try encodeBestWithDictionaryAlloc(allocator, dict, input[offset..][0..n], min_match_len);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
        offset += n;
    }
    if (input.len == 0) {
        const frame = try encodeBestWithDictionaryAlloc(allocator, dict, "", min_match_len);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const sidecar_index = try encodeFrameIndexAlloc(allocator, index);
    errdefer allocator.free(sidecar_index);
    return .{ .stream = try stream.toOwnedSlice(allocator), .sidecar_index = sidecar_index };
}

fn encodeBlockedBestWithDictionaryStreamInternalAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, block_len: usize, min_match_len: usize, embed_dict: bool) ![]u8 {
    var sidecar = try encodeBlockedBestWithDictionarySidecarStreamInternalAlloc(allocator, dict, input, block_len, min_match_len, embed_dict);
    defer sidecar.deinit(allocator);
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    try stream.appendSlice(allocator, sidecar.stream);
    const index_frame = try encodeSkippableAlloc(allocator, sidecar.sidecar_index);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

fn encodeBlockBestWithLdmAlloc(allocator: std.mem.Allocator, input: []const u8, options: deflate.CompressionOptions, ldm_options: long_distance.Options) ![]u8 {
    const native_best = try encodeBlockBestAlloc(allocator, input, options);
    errdefer allocator.free(native_best);
    const ldm_frame = try encodeLongDistanceAlloc(allocator, input, ldm_options);
    errdefer allocator.free(ldm_frame);
    if (ldm_frame.len < native_best.len) {
        allocator.free(native_best);
        return ldm_frame;
    }
    allocator.free(ldm_frame);
    return native_best;
}

fn encodeBlockBestAlloc(allocator: std.mem.Allocator, input: []const u8, options: deflate.CompressionOptions) ![]u8 {
    const store_frame = try encodeAlloc(allocator, input);
    errdefer allocator.free(store_frame);
    const deflate_frame = try encodeDeflateSplitFrameAlloc(allocator, input, options);
    errdefer allocator.free(deflate_frame);
    const rle_frame = try encodeRleAlloc(allocator, input);
    errdefer allocator.free(rle_frame);
    if (store_frame.len <= deflate_frame.len and store_frame.len <= rle_frame.len) {
        allocator.free(deflate_frame);
        allocator.free(rle_frame);
        return store_frame;
    }
    allocator.free(store_frame);
    if (deflate_frame.len <= rle_frame.len) {
        allocator.free(rle_frame);
        return deflate_frame;
    }
    allocator.free(deflate_frame);
    return rle_frame;
}

fn encodeDeflateSplitFrameAlloc(allocator: std.mem.Allocator, input: []const u8, options: deflate.CompressionOptions) ![]u8 {
    const compressed = try deflate.encodeRawBestSplitAlloc(allocator, input, deflate.max_stored_block_len, options);
    defer allocator.free(compressed);
    const required = try encodedSize(compressed.len);
    const out = try allocator.alloc(u8, required);
    errdefer allocator.free(out);
    writeHeader(out[0..header_len], .{
        .version = current_version,
        .flags = flags_deflate,
        .uncompressed_size = @intCast(input.len),
        .stored_size = @intCast(compressed.len),
        .checksum = checksum.crc32(input),
    });
    @memcpy(out[header_len..], compressed);
    return out;
}

pub fn encodePlannedDeflateStreamAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, worker_count: usize) ![]u8 {
    const plan = try @import("planner.zig").planBlocksAlloc(allocator, input.len, .{ .block_len = block_len, .worker_count = worker_count });
    defer allocator.free(plan);
    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    for (plan) |block| {
        const frame = try encodeBestAlloc(allocator, input[block.input_offset..][0..block.input_len]);
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    if (input.len == 0) {
        const frame = try encodeBestAlloc(allocator, "");
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const index_bytes = try encodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try encodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

const ParallelBlockResult = struct {
    allocator: std.mem.Allocator,
    input: []const u8,
    frame: ?[]u8 = null,
    err: ?anyerror = null,

    fn run(self: *ParallelBlockResult) void {
        self.frame = encodeBestAlloc(self.allocator, self.input) catch |err| {
            self.err = err;
            return;
        };
    }
};

pub fn encodeParallelDeflateStreamAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, worker_count: usize) ![]u8 {
    const plan = try @import("planner.zig").planBlocksAlloc(allocator, input.len, .{ .block_len = block_len, .worker_count = worker_count });
    defer allocator.free(plan);
    if (plan.len == 0) return encodePlannedDeflateStreamAlloc(allocator, input, block_len, worker_count);

    const results = try allocator.alloc(ParallelBlockResult, plan.len);
    defer allocator.free(results);
    for (plan, 0..) |block, i| {
        results[i] = .{ .allocator = allocator, .input = input[block.input_offset..][0..block.input_len] };
    }

    const threads = try allocator.alloc(std.Thread, plan.len);
    defer allocator.free(threads);
    for (threads, 0..) |*thread, i| {
        thread.* = try std.Thread.spawn(.{}, ParallelBlockResult.run, .{&results[i]});
    }
    for (threads) |thread| thread.join();
    for (results) |result| if (result.err) |err| return err;

    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    for (results) |*result| {
        const frame = result.frame.?;
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const index_bytes = try encodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try encodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

const WorkerContext = struct {
    worker_index: usize,
    plan: []const @import("planner.zig").Block,
    results: []ParallelBlockResult,

    fn run(self: *WorkerContext) void {
        for (self.plan, 0..) |block, i| {
            if (block.worker_index != self.worker_index) continue;
            self.results[i].run();
        }
    }
};

pub fn encodeThreadPoolDeflateStreamAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, worker_count: usize) ![]u8 {
    const plan = try @import("planner.zig").planBlocksAlloc(allocator, input.len, .{ .block_len = block_len, .worker_count = worker_count });
    defer allocator.free(plan);
    if (plan.len == 0) return encodePlannedDeflateStreamAlloc(allocator, input, block_len, worker_count);

    const results = try allocator.alloc(ParallelBlockResult, plan.len);
    defer allocator.free(results);
    for (plan, 0..) |block, i| results[i] = .{ .allocator = allocator, .input = input[block.input_offset..][0..block.input_len] };

    const contexts = try allocator.alloc(WorkerContext, worker_count);
    defer allocator.free(contexts);
    const threads = try allocator.alloc(std.Thread, worker_count);
    defer allocator.free(threads);
    for (contexts, 0..) |*ctx, worker| {
        ctx.* = .{ .worker_index = worker, .plan = plan, .results = results };
        threads[worker] = try std.Thread.spawn(.{}, WorkerContext.run, .{ctx});
    }
    for (threads) |thread| thread.join();
    for (results) |result| if (result.err) |err| return err;

    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    for (results) |*result| {
        const frame = result.frame.?;
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const index_bytes = try encodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try encodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

const WorkQueueContext = struct {
    next: std.atomic.Value(usize),
    plan: []const @import("planner.zig").Block,
    results: []ParallelBlockResult,

    fn run(self: *WorkQueueContext) void {
        while (true) {
            const i = self.next.fetchAdd(1, .monotonic);
            if (i >= self.plan.len) break;
            self.results[i].run();
        }
    }
};

pub fn encodeWorkStealingDeflateStreamAlloc(allocator: std.mem.Allocator, input: []const u8, block_len: usize, worker_count: usize) ![]u8 {
    const plan = try @import("planner.zig").planBlocksAlloc(allocator, input.len, .{ .block_len = block_len, .worker_count = worker_count });
    defer allocator.free(plan);
    if (plan.len == 0) return encodePlannedDeflateStreamAlloc(allocator, input, block_len, worker_count);

    const results = try allocator.alloc(ParallelBlockResult, plan.len);
    defer allocator.free(results);
    for (plan, 0..) |block, i| results[i] = .{ .allocator = allocator, .input = input[block.input_offset..][0..block.input_len] };

    var context = WorkQueueContext{ .next = std.atomic.Value(usize).init(0), .plan = plan, .results = results };
    const threads = try allocator.alloc(std.Thread, worker_count);
    defer allocator.free(threads);
    for (threads) |*thread| thread.* = try std.Thread.spawn(.{}, WorkQueueContext.run, .{&context});
    for (threads) |thread| thread.join();
    for (results) |result| if (result.err) |err| return err;

    var stream: std.ArrayList(u8) = .empty;
    errdefer stream.deinit(allocator);
    for (results) |*result| {
        const frame = result.frame.?;
        defer allocator.free(frame);
        try stream.appendSlice(allocator, frame);
    }
    const index = try buildFrameIndexAlloc(allocator, stream.items);
    defer allocator.free(index);
    const index_bytes = try encodeFrameIndexAlloc(allocator, index);
    defer allocator.free(index_bytes);
    const index_frame = try encodeSkippableAlloc(allocator, index_bytes);
    defer allocator.free(index_frame);
    try stream.appendSlice(allocator, index_frame);
    return stream.toOwnedSlice(allocator);
}

pub const EmbeddedIndex = struct {
    entries: []FrameIndexEntry,
    payload_offset: usize,

    pub fn deinit(self: EmbeddedIndex, allocator: std.mem.Allocator) void {
        allocator.free(self.entries);
    }
};

pub fn parseEmbeddedIndexAlloc(allocator: std.mem.Allocator, input: []const u8) !EmbeddedIndex {
    var offset: usize = 0;
    var last_payload: ?[]const u8 = null;
    var last_payload_offset: usize = 0;
    while (offset < input.len) {
        const tail = input[offset..];
        if (tail.len >= 4 and std.mem.eql(u8, tail[0..4], &skippable_magic)) {
            const payload = try parseSkippable(tail);
            if (payload.len >= 4 and std.mem.eql(u8, payload[0..4], &serialized_index_magic)) {
                last_payload = payload;
                last_payload_offset = offset + skippable_header_len;
            }
            const total = try skippableTotalLen(tail);
            if (tail.len < total) return error.TruncatedFrame;
            offset += total;
        } else {
            const info = try parseHeader(tail);
            const total = try frameLenFromInfo(info);
            if (tail.len < total) return error.TruncatedFrame;
            offset += total;
        }
    }
    const payload = last_payload orelse return error.InvalidMagic;
    return .{ .entries = try decodeFrameIndexAlloc(allocator, payload), .payload_offset = last_payload_offset };
}

pub fn decodeIndexedRangeAlloc(allocator: std.mem.Allocator, input: []const u8, offset: u64, length: usize) ![]u8 {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    return decodeRangeAlloc(allocator, input, embedded.entries, offset, length);
}

pub fn decodeIndexedRangeWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, offset: u64, length: usize) !RangeDecodeResult {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    return decodeRangeWithSummaryAlloc(allocator, input, embedded.entries, offset, length);
}

pub fn decodeIndexedRangesWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, requests: []const RangeRequest) !RangeBatchDecodeResult {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    return decodeRangesWithSummaryAlloc(allocator, input, embedded.entries, requests);
}

pub fn decodeIndexedRangeInto(allocator: std.mem.Allocator, input: []const u8, offset: u64, length: usize, output: []u8) !RangeDecodeIntoResult {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    return decodeRangeInto(allocator, input, embedded.entries, offset, length, output);
}

pub fn decodeIndexedRangesInto(allocator: std.mem.Allocator, input: []const u8, requests: []const RangeIntoRequest, results: []RangeDecodeIntoResult) !void {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    return decodeRangesInto(allocator, input, embedded.entries, requests, results);
}

pub const SidecarValidationMode = enum {
    /// Check only sidecar/index structure, frame spans, frame headers, and the
    /// checksum values recorded in frame headers. This is intentionally cheap
    /// for large corpus dashboards, but it cannot detect payload bytes changed
    /// without updating the header.
    metadata,
    /// Decode every indexed frame through the normal per-mode decoder and
    /// checksum path. This is the corruption-detection mode callers should use
    /// before trusting sidecars for recovery or archival workflows.
    full,
};

pub const SidecarValidationOptions = struct {
    mode: SidecarValidationMode = .full,
    dictionary: ?[]const u8 = null,
    /// Optional logical payload byte count expected from the frame index.
    /// This is checked from metadata before optional full payload decoding.
    expected_total_uncompressed: ?u64 = null,
    /// Optional CRC-32 of the logical concatenated payload expected from the
    /// frame index. The value is computed with frameIndexCombinedChecksum, so
    /// metadata mode can validate whole-stream checksum policy without reading
    /// every payload byte. Full mode still decodes frames to prove the indexed
    /// frame bytes match their headers.
    expected_checksum: ?u32 = null,
};

pub const ValidationStage = enum {
    index_decode,
    index_structure,
    dictionary_parse,
    frame_bounds,
    frame_header,
    frame_metadata,
    payload_decode,
};

pub const ValidationHint = enum {
    none,
    index_mismatch,
    payload_corrupt,
    retry_with_dictionary,
    truncated_input,
};

pub const ValidationReport = struct {
    ok: bool = true,
    mode: SidecarValidationMode,
    stage: ValidationStage = .index_decode,
    error_name: []const u8 = "",
    recoverability_hint: ValidationHint = .none,
    frame_index: ?usize = null,
    frame_offset: ?usize = null,
    uncompressed_offset: ?u64 = null,
    frame_flags: ?u8 = null,
    frame_mode: []const u8 = "",
    frame_count: usize = 0,
    total_uncompressed: u64 = 0,
    combined_checksum: ?u32 = null,
};

pub fn validateSidecarIndexAlloc(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8) !void {
    return validateSidecarIndexWithOptionsAlloc(allocator, input, sidecar_index, .{});
}

pub fn validateSidecarIndexMetadataAlloc(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8) !void {
    return validateSidecarIndexWithOptionsAlloc(allocator, input, sidecar_index, .{ .mode = .metadata });
}

pub fn validateSidecarIndexWithDictionaryAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, sidecar_index: []const u8) !void {
    return validateSidecarIndexWithOptionsAlloc(allocator, input, sidecar_index, .{ .dictionary = dict });
}

pub fn validateSidecarIndexWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, options: SidecarValidationOptions) !void {
    if (options.mode == .metadata) return validateSidecarIndexInternalAlloc(allocator, options.dictionary, input, sidecar_index, options);
    if (options.dictionary) |dict| return validateSidecarIndexInternalAlloc(allocator, dict, input, sidecar_index, options);
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return validateSidecarIndexInternalAlloc(allocator, dict, input, sidecar_index, options);
    } else |err| switch (err) {
        error.InvalidMagic => return validateSidecarIndexInternalAlloc(allocator, null, input, sidecar_index, options),
        else => return err,
    }
}

pub fn validateSidecarIndexReportAlloc(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, options: SidecarValidationOptions) ValidationReport {
    if (options.mode == .metadata) return validateSidecarIndexReportInternalAlloc(allocator, options.dictionary, input, sidecar_index, options);
    if (options.dictionary) |dict| return validateSidecarIndexReportInternalAlloc(allocator, dict, input, sidecar_index, options);
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return validateSidecarIndexReportInternalAlloc(allocator, dict, input, sidecar_index, options);
    } else |err| switch (err) {
        error.InvalidMagic => return validateSidecarIndexReportInternalAlloc(allocator, null, input, sidecar_index, options),
        else => return validationFailure(options.mode, .dictionary_parse, err, null, null, null),
    }
}

pub fn validateEmbeddedIndexAlloc(allocator: std.mem.Allocator, input: []const u8) !void {
    return validateEmbeddedIndexWithOptionsAlloc(allocator, input, .{});
}

pub fn validateEmbeddedIndexMetadataAlloc(allocator: std.mem.Allocator, input: []const u8) !void {
    return validateEmbeddedIndexWithOptionsAlloc(allocator, input, .{ .mode = .metadata });
}

pub fn validateEmbeddedIndexWithOptionsAlloc(allocator: std.mem.Allocator, input: []const u8, options: SidecarValidationOptions) !void {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    if (options.mode == .metadata) return validateFrameIndexEntriesInternalAlloc(allocator, options.dictionary, input, embedded.entries, options);
    if (options.dictionary) |dict| return validateFrameIndexEntriesInternalAlloc(allocator, dict, input, embedded.entries, options);
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return validateFrameIndexEntriesInternalAlloc(allocator, dict, input, embedded.entries, options);
    } else |err| switch (err) {
        error.InvalidMagic => return validateFrameIndexEntriesInternalAlloc(allocator, null, input, embedded.entries, options),
        else => return err,
    }
}

pub fn validateEmbeddedIndexReportAlloc(allocator: std.mem.Allocator, input: []const u8, options: SidecarValidationOptions) ValidationReport {
    const embedded = parseEmbeddedIndexAlloc(allocator, input) catch |err| {
        return validationFailure(options.mode, .index_decode, err, null, null, null);
    };
    defer embedded.deinit(allocator);
    if (options.mode == .metadata) return validateFrameIndexEntriesReportInternalAlloc(allocator, options.dictionary, input, embedded.entries, options);
    if (options.dictionary) |dict| return validateFrameIndexEntriesReportInternalAlloc(allocator, dict, input, embedded.entries, options);
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return validateFrameIndexEntriesReportInternalAlloc(allocator, dict, input, embedded.entries, options);
    } else |err| switch (err) {
        error.InvalidMagic => return validateFrameIndexEntriesReportInternalAlloc(allocator, null, input, embedded.entries, options),
        else => return validationFailure(options.mode, .dictionary_parse, err, null, null, null),
    }
}

fn validateSidecarIndexInternalAlloc(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, sidecar_index: []const u8, options: SidecarValidationOptions) !void {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return validateFrameIndexEntriesInternalAlloc(allocator, dict, input, index, options);
}

fn validateFrameIndexEntriesInternalAlloc(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, index: []const FrameIndexEntry, options: SidecarValidationOptions) !void {
    try validateFrameIndex(index);
    const summary = try summarizeFrameIndex(index);
    try validateFrameIndexSummaryExpectations(summary, options);
    var scratch: std.ArrayList(u8) = .empty;
    defer scratch.deinit(allocator);
    for (index) |entry| {
        if (input.len - entry.frame_offset < entry.frame_len) return error.TruncatedFrame;
        const frame = input[entry.frame_offset..][0..entry.frame_len];
        const info = try parseHeader(frame);
        if (entry.frame_len != try frameLenFromInfo(info)) return error.CorruptFrame;
        if (entry.uncompressed_len != info.uncompressed_size) return error.CorruptFrame;
        if (entry.checksum != info.checksum) return error.ChecksumMismatch;
        if (options.mode == .metadata) continue;
        // A sidecar can outlive and travel separately from its stream, so
        // structural agreement with frame headers is not enough: a payload byte
        // could be modified while both the frame header and sidecar checksum
        // remain unchanged. Decode each referenced frame once to force the
        // normal per-mode checksum and size verification paths to run before a
        // verifier reports the pair as reusable for range reads.
        try scratch.resize(allocator, std.math.cast(usize, info.uncompressed_size) orelse return error.IntegerOverflow);
        const written = if (info.flags == flags_dictionary_patch or info.flags == flags_dictionary_deflate) blk: {
            const dictionary_bytes = dict orelse return error.InvalidDictionaryTraining;
            break :blk try decodeDictionaryPatchInto(allocator, dictionary_bytes, frame, scratch.items);
        } else try decodeAnyInto(frame, scratch.items);
        if (written != scratch.items.len) return error.SizeMismatch;
    }
}

fn validateSidecarIndexReportInternalAlloc(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, sidecar_index: []const u8, options: SidecarValidationOptions) ValidationReport {
    const index = decodeFrameIndexAlloc(allocator, sidecar_index) catch |err| {
        return validationFailure(options.mode, .index_decode, err, null, null, null);
    };
    defer allocator.free(index);
    return validateFrameIndexEntriesReportInternalAlloc(allocator, dict, input, index, options);
}

fn validateFrameIndexEntriesReportInternalAlloc(allocator: std.mem.Allocator, dict: ?[]const u8, input: []const u8, index: []const FrameIndexEntry, options: SidecarValidationOptions) ValidationReport {
    validateFrameIndex(index) catch |err| return validationFailure(options.mode, .index_structure, err, null, null, null);
    const summary = summarizeFrameIndex(index) catch |err| return validationFailure(options.mode, .index_structure, err, null, null, null);
    validateFrameIndexSummaryExpectations(summary, options) catch |err| return validationFailure(options.mode, .frame_metadata, err, null, null, null);
    var scratch: std.ArrayList(u8) = .empty;
    defer scratch.deinit(allocator);
    for (index, 0..) |entry, i| {
        if (input.len - entry.frame_offset < entry.frame_len) return validationFailure(options.mode, .frame_bounds, error.TruncatedFrame, i, entry, null);
        const frame = input[entry.frame_offset..][0..entry.frame_len];
        const info = parseHeader(frame) catch |err| return validationFailure(options.mode, .frame_header, err, i, entry, null);
        if (entry.frame_len != (frameLenFromInfo(info) catch |err| return validationFailure(options.mode, .frame_metadata, err, i, entry, info.flags))) return validationFailure(options.mode, .frame_metadata, error.CorruptFrame, i, entry, info.flags);
        if (entry.uncompressed_len != info.uncompressed_size) return validationFailure(options.mode, .frame_metadata, error.CorruptFrame, i, entry, info.flags);
        if (entry.checksum != info.checksum) return validationFailure(options.mode, .frame_metadata, error.ChecksumMismatch, i, entry, info.flags);
        if (options.mode == .metadata) continue;
        scratch.resize(allocator, std.math.cast(usize, info.uncompressed_size) orelse return validationFailure(options.mode, .frame_metadata, error.IntegerOverflow, i, entry, info.flags)) catch |err| return validationFailure(options.mode, .payload_decode, err, i, entry, info.flags);
        const written = if (info.flags == flags_dictionary_patch or info.flags == flags_dictionary_deflate) blk: {
            const dictionary_bytes = dict orelse return validationFailure(options.mode, .payload_decode, error.InvalidDictionaryTraining, i, entry, info.flags);
            break :blk decodeDictionaryPatchInto(allocator, dictionary_bytes, frame, scratch.items) catch |err| return validationFailure(options.mode, .payload_decode, err, i, entry, info.flags);
        } else decodeAnyInto(frame, scratch.items) catch |err| return validationFailure(options.mode, .payload_decode, err, i, entry, info.flags);
        if (written != scratch.items.len) return validationFailure(options.mode, .payload_decode, error.SizeMismatch, i, entry, info.flags);
    }
    return .{
        .ok = true,
        .mode = options.mode,
        .stage = if (options.mode == .metadata) .frame_metadata else .payload_decode,
        .frame_count = summary.frame_count,
        .total_uncompressed = summary.total_uncompressed,
        .combined_checksum = summary.combined_checksum,
    };
}

fn validationFailure(mode: SidecarValidationMode, stage: ValidationStage, err: anyerror, frame_index: ?usize, entry: ?FrameIndexEntry, frame_flags: ?u8) ValidationReport {
    return .{
        .ok = false,
        .mode = mode,
        .stage = stage,
        .error_name = @errorName(err),
        .recoverability_hint = validationHint(stage, err),
        .frame_index = frame_index,
        .frame_offset = if (entry) |e| e.frame_offset else null,
        .uncompressed_offset = if (entry) |e| e.uncompressed_offset else null,
        .frame_flags = frame_flags,
        .frame_mode = if (frame_flags) |flags| frameModeName(flags) else "",
    };
}

fn validationHint(stage: ValidationStage, err: anyerror) ValidationHint {
    return switch (stage) {
        .index_decode, .index_structure, .frame_metadata => .index_mismatch,
        .frame_bounds => .truncated_input,
        .frame_header => if (err == error.TruncatedFrame) .truncated_input else .index_mismatch,
        .dictionary_parse => .payload_corrupt,
        .payload_decode => if (err == error.InvalidDictionaryTraining) .retry_with_dictionary else .payload_corrupt,
    };
}

pub fn decodeSidecarIndexedRangeAlloc(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, offset: u64, length: usize) ![]u8 {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return decodeRangeAlloc(allocator, input, index, offset, length);
}

pub fn decodeSidecarIndexedRangeWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, offset: u64, length: usize) !RangeDecodeResult {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return decodeRangeWithSummaryAlloc(allocator, input, index, offset, length);
}

pub fn decodeSidecarIndexedRangesWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, requests: []const RangeRequest) !RangeBatchDecodeResult {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return decodeRangesWithSummaryAlloc(allocator, input, index, requests);
}

pub fn decodeSidecarIndexedRangeInto(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, offset: u64, length: usize, output: []u8) !RangeDecodeIntoResult {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return decodeRangeInto(allocator, input, index, offset, length, output);
}

pub fn decodeSidecarIndexedRangesInto(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, requests: []const RangeIntoRequest, results: []RangeDecodeIntoResult) !void {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return decodeRangesInto(allocator, input, index, requests, results);
}

pub fn decodeSidecarIndexedRangeWithDictionaryAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, sidecar_index: []const u8, offset: u64, length: usize) ![]u8 {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return decodeRangeWithDictionaryAlloc(allocator, dict, input, index, offset, length);
}

pub fn decodeSidecarIndexedRangeWithDictionarySummaryAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, sidecar_index: []const u8, offset: u64, length: usize) !RangeDecodeResult {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return decodeRangeWithDictionarySummaryAlloc(allocator, dict, input, index, offset, length);
}

pub fn decodeSidecarIndexedRangesWithDictionarySummaryAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, sidecar_index: []const u8, requests: []const RangeRequest) !RangeBatchDecodeResult {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return decodeRangesWithDictionarySummaryAlloc(allocator, dict, input, index, requests);
}

pub fn decodeSidecarIndexedRangeWithDictionaryInto(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, sidecar_index: []const u8, offset: u64, length: usize, output: []u8) !RangeDecodeIntoResult {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return decodeRangeWithDictionaryInto(allocator, dict, input, index, offset, length, output);
}

pub fn decodeSidecarIndexedRangesWithDictionaryInto(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, sidecar_index: []const u8, requests: []const RangeIntoRequest, results: []RangeDecodeIntoResult) !void {
    const index = try decodeFrameIndexAlloc(allocator, sidecar_index);
    defer allocator.free(index);
    return decodeRangesWithDictionaryInto(allocator, dict, input, index, requests, results);
}

pub fn decodeSidecarIndexedRangeAutoAlloc(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, offset: u64, length: usize) ![]u8 {
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return decodeSidecarIndexedRangeWithDictionaryAlloc(allocator, dict, input, sidecar_index, offset, length);
    } else |err| switch (err) {
        error.InvalidMagic => return decodeSidecarIndexedRangeAlloc(allocator, input, sidecar_index, offset, length),
        else => return err,
    }
}

pub fn decodeSidecarIndexedRangeAutoWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, offset: u64, length: usize) !RangeDecodeResult {
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return decodeSidecarIndexedRangeWithDictionarySummaryAlloc(allocator, dict, input, sidecar_index, offset, length);
    } else |err| switch (err) {
        error.InvalidMagic => return decodeSidecarIndexedRangeWithSummaryAlloc(allocator, input, sidecar_index, offset, length),
        else => return err,
    }
}

pub fn decodeSidecarIndexedRangesAutoWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, requests: []const RangeRequest) !RangeBatchDecodeResult {
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return decodeSidecarIndexedRangesWithDictionarySummaryAlloc(allocator, dict, input, sidecar_index, requests);
    } else |err| switch (err) {
        error.InvalidMagic => return decodeSidecarIndexedRangesWithSummaryAlloc(allocator, input, sidecar_index, requests),
        else => return err,
    }
}

pub fn decodeSidecarIndexedRangeAutoInto(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, offset: u64, length: usize, output: []u8) !RangeDecodeIntoResult {
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return decodeSidecarIndexedRangeWithDictionaryInto(allocator, dict, input, sidecar_index, offset, length, output);
    } else |err| switch (err) {
        error.InvalidMagic => return decodeSidecarIndexedRangeInto(allocator, input, sidecar_index, offset, length, output),
        else => return err,
    }
}

pub fn decodeSidecarIndexedRangesAutoInto(allocator: std.mem.Allocator, input: []const u8, sidecar_index: []const u8, requests: []const RangeIntoRequest, results: []RangeDecodeIntoResult) !void {
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return decodeSidecarIndexedRangesWithDictionaryInto(allocator, dict, input, sidecar_index, requests, results);
    } else |err| switch (err) {
        error.InvalidMagic => return decodeSidecarIndexedRangesInto(allocator, input, sidecar_index, requests, results),
        else => return err,
    }
}

pub fn decodeIndexedRangeWithDictionaryAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, offset: u64, length: usize) ![]u8 {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    return decodeRangeWithDictionaryAlloc(allocator, dict, input, embedded.entries, offset, length);
}

pub fn decodeIndexedRangeWithDictionarySummaryAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, offset: u64, length: usize) !RangeDecodeResult {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    return decodeRangeWithDictionarySummaryAlloc(allocator, dict, input, embedded.entries, offset, length);
}

pub fn decodeIndexedRangesWithDictionarySummaryAlloc(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, requests: []const RangeRequest) !RangeBatchDecodeResult {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    return decodeRangesWithDictionarySummaryAlloc(allocator, dict, input, embedded.entries, requests);
}

pub fn decodeIndexedRangeWithDictionaryInto(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, offset: u64, length: usize, output: []u8) !RangeDecodeIntoResult {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    return decodeRangeWithDictionaryInto(allocator, dict, input, embedded.entries, offset, length, output);
}

pub fn decodeIndexedRangesWithDictionaryInto(allocator: std.mem.Allocator, dict: []const u8, input: []const u8, requests: []const RangeIntoRequest, results: []RangeDecodeIntoResult) !void {
    const embedded = try parseEmbeddedIndexAlloc(allocator, input);
    defer embedded.deinit(allocator);
    return decodeRangesWithDictionaryInto(allocator, dict, input, embedded.entries, requests, results);
}

pub fn decodeSelfContainedDictionaryRangeAlloc(allocator: std.mem.Allocator, input: []const u8, offset: u64, length: usize) ![]u8 {
    const dict = try parseEmbeddedDictionaryAlloc(allocator, input);
    defer allocator.free(dict);
    return decodeIndexedRangeWithDictionaryAlloc(allocator, dict, input, offset, length);
}

pub fn decodeSelfContainedDictionaryRangeWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, offset: u64, length: usize) !RangeDecodeResult {
    const dict = try parseEmbeddedDictionaryAlloc(allocator, input);
    defer allocator.free(dict);
    return decodeIndexedRangeWithDictionarySummaryAlloc(allocator, dict, input, offset, length);
}

pub fn decodeSelfContainedDictionaryRangesWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, requests: []const RangeRequest) !RangeBatchDecodeResult {
    const dict = try parseEmbeddedDictionaryAlloc(allocator, input);
    defer allocator.free(dict);
    return decodeIndexedRangesWithDictionarySummaryAlloc(allocator, dict, input, requests);
}

pub fn decodeSelfContainedDictionaryRangeInto(allocator: std.mem.Allocator, input: []const u8, offset: u64, length: usize, output: []u8) !RangeDecodeIntoResult {
    const dict = try parseEmbeddedDictionaryAlloc(allocator, input);
    defer allocator.free(dict);
    return decodeIndexedRangeWithDictionaryInto(allocator, dict, input, offset, length, output);
}

pub fn decodeSelfContainedDictionaryRangesInto(allocator: std.mem.Allocator, input: []const u8, requests: []const RangeIntoRequest, results: []RangeDecodeIntoResult) !void {
    const dict = try parseEmbeddedDictionaryAlloc(allocator, input);
    defer allocator.free(dict);
    return decodeIndexedRangesWithDictionaryInto(allocator, dict, input, requests, results);
}

pub fn decodeIndexedRangeAutoAlloc(allocator: std.mem.Allocator, input: []const u8, offset: u64, length: usize) ![]u8 {
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return decodeIndexedRangeWithDictionaryAlloc(allocator, dict, input, offset, length);
    } else |err| switch (err) {
        error.InvalidMagic => return decodeIndexedRangeAlloc(allocator, input, offset, length),
        else => return err,
    }
}

pub fn decodeIndexedRangeAutoWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, offset: u64, length: usize) !RangeDecodeResult {
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return decodeIndexedRangeWithDictionarySummaryAlloc(allocator, dict, input, offset, length);
    } else |err| switch (err) {
        error.InvalidMagic => return decodeIndexedRangeWithSummaryAlloc(allocator, input, offset, length),
        else => return err,
    }
}

pub fn decodeIndexedRangesAutoWithSummaryAlloc(allocator: std.mem.Allocator, input: []const u8, requests: []const RangeRequest) !RangeBatchDecodeResult {
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return decodeIndexedRangesWithDictionarySummaryAlloc(allocator, dict, input, requests);
    } else |err| switch (err) {
        error.InvalidMagic => return decodeIndexedRangesWithSummaryAlloc(allocator, input, requests),
        else => return err,
    }
}

pub fn decodeIndexedRangeAutoInto(allocator: std.mem.Allocator, input: []const u8, offset: u64, length: usize, output: []u8) !RangeDecodeIntoResult {
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return decodeIndexedRangeWithDictionaryInto(allocator, dict, input, offset, length, output);
    } else |err| switch (err) {
        error.InvalidMagic => return decodeIndexedRangeInto(allocator, input, offset, length, output),
        else => return err,
    }
}

pub fn decodeIndexedRangesAutoInto(allocator: std.mem.Allocator, input: []const u8, requests: []const RangeIntoRequest, results: []RangeDecodeIntoResult) !void {
    if (parseEmbeddedDictionaryAlloc(allocator, input)) |dict| {
        defer allocator.free(dict);
        return decodeIndexedRangesWithDictionaryInto(allocator, dict, input, requests, results);
    } else |err| switch (err) {
        error.InvalidMagic => return decodeIndexedRangesInto(allocator, input, requests, results),
        else => return err,
    }
}

pub const ModeSummary = struct {
    store: usize = 0,
    deflate: usize = 0,
    rle: usize = 0,
    dictionary_patch: usize = 0,
    dictionary_deflate: usize = 0,
    ldm: usize = 0,
};

pub fn summarizeModes(input: []const u8) Error!ModeSummary {
    var summary = ModeSummary{};
    var offset: usize = 0;
    while (offset < input.len) {
        const tail = input[offset..];
        if (tail.len >= 4 and std.mem.eql(u8, tail[0..4], &skippable_magic)) {
            const total = try skippableTotalLen(tail);
            if (tail.len < total) return error.TruncatedFrame;
            offset += total;
            continue;
        }
        const info = try parseHeader(tail);
        switch (info.flags) {
            flags_none => summary.store += 1,
            flags_deflate => summary.deflate += 1,
            flags_rle => summary.rle += 1,
            flags_dictionary_patch => summary.dictionary_patch += 1,
            flags_dictionary_deflate => summary.dictionary_deflate += 1,
            flags_ldm => summary.ldm += 1,
            else => return error.CorruptFrame,
        }
        const total = try frameLenFromInfo(info);
        if (tail.len < total) return error.TruncatedFrame;
        offset += total;
    }
    return summary;
}

pub fn countConcatenatedFrames(input: []const u8) Error!usize {
    var iterator = ConcatIterator.init(input);
    var count: usize = 0;
    while (try iterator.next()) |_| {
        count = std.math.add(usize, count, 1) catch return error.IntegerOverflow;
    }
    return count;
}

/// Decode all concatenated store frames into one owned buffer.
pub fn decodeConcatenatedAlloc(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var iterator = ConcatIterator.init(input);
    while (try iterator.next()) |span| {
        if (checksum.crc32(span.payload) != span.info.checksum) return error.ChecksumMismatch;
        try out.appendSlice(allocator, span.payload);
    }

    return out.toOwnedSlice(allocator);
}

/// Bounded-buffer streaming decoder for one complete input frame. The input is
/// provided up-front while output may be drained across multiple calls.
pub const Decoder = struct {
    payload: []const u8 = &.{},
    checksum_value: u32 = 0,
    offset: usize = 0,
    verified: bool = false,
    done: bool = false,

    pub fn init(frame: []const u8) Error!Decoder {
        const info = try parseHeader(frame);
        const payload_len = try payloadLenFromInfo(info);
        const total_len = try encodedSize(payload_len);
        if (frame.len < total_len) return error.TruncatedFrame;
        return .{
            .payload = frame[header_len..total_len],
            .checksum_value = info.checksum,
        };
    }

    pub fn step(self: *Decoder, output: []u8) Error!StepResult {
        if (self.done) return .{ .status = .done };
        if (!self.verified) {
            if (checksum.crc32(self.payload) != self.checksum_value) return error.ChecksumMismatch;
            self.verified = true;
        }
        if (output.len == 0) return .{ .status = .need_output };

        const remaining = self.payload[self.offset..];
        const n = @min(output.len, remaining.len);
        @memcpy(output[0..n], remaining[0..n]);
        self.offset += n;
        if (self.offset == self.payload.len) self.done = true;
        return .{
            .progress = .{ .input_read = if (self.done) header_len + self.payload.len else 0, .output_written = n },
            .status = if (self.done) .done else .need_output,
        };
    }
};

test "store frame round trips edge and representative inputs" {
    const cases = [_][]const u8{
        "",
        "a",
        "hello vort",
        "The quick brown fox jumps over the lazy dog" ** 16,
    };
    for (cases) |case| {
        const encoded = try encodeAlloc(std.testing.allocator, case);
        defer std.testing.allocator.free(encoded);
        const decoded = try decodeAlloc(std.testing.allocator, encoded);
        defer std.testing.allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, case, decoded);
    }
}

test "store header exposes size and checksum metadata" {
    const input = "metadata contract";
    var encoded: [128]u8 = undefined;
    const written = try encode(input, &encoded);
    const info = try parseHeader(encoded[0..written]);
    try std.testing.expectEqual(current_version, info.version);
    try std.testing.expectEqual(@as(u64, input.len), info.uncompressed_size);
    try std.testing.expectEqual(@as(u64, input.len), info.stored_size);
    try std.testing.expectEqual(checksum.crc32(input), info.checksum);
}

test "native frame inspection exposes mode sizes and dictionary requirement" {
    const store_frame = try encodeAlloc(std.testing.allocator, "inspect");
    defer std.testing.allocator.free(store_frame);
    const store_inspection = try inspectFrame(store_frame);
    try std.testing.expectEqualStrings("store", store_inspection.mode);
    try std.testing.expectEqual(store_frame.len, store_inspection.frame_len);
    try std.testing.expectEqual(@as(usize, "inspect".len), store_inspection.payload_len);
    try std.testing.expect(!store_inspection.requires_dictionary);
    try std.testing.expectEqual(@as(u64, "inspect".len), store_inspection.info.uncompressed_size);
    const header_inspection = try inspectHeader(store_frame[0..header_len]);
    try std.testing.expectEqual(store_inspection.frame_len, header_inspection.frame_len);
    try std.testing.expectEqual(store_inspection.payload_len, header_inspection.payload_len);
    try std.testing.expectEqualStrings(store_inspection.mode, header_inspection.mode);

    const dict = "alpha beta gamma";
    const input = "zz alpha beta yy gamma";
    const dict_frame = try encodeDictionaryPatchAlloc(std.testing.allocator, dict, input, 5);
    defer std.testing.allocator.free(dict_frame);
    const dict_inspection = try inspectFrame(dict_frame);
    try std.testing.expectEqualStrings("dictionary_patch", dict_inspection.mode);
    try std.testing.expect(dict_inspection.requires_dictionary);
    try std.testing.expectEqual(dict_frame.len, dict_inspection.frame_len);

    try std.testing.expectError(error.TruncatedFrame, inspectFrame(store_frame[0 .. store_frame.len - 1]));
}

test "store frame reports malformed and corrupt data" {
    try std.testing.expectError(error.TruncatedFrame, parseHeader("short"));

    var encoded: [128]u8 = undefined;
    const written = try encode("payload", &encoded);

    encoded[0] = 'X';
    try std.testing.expectError(error.InvalidMagic, parseHeader(encoded[0..written]));
    encoded[0] = 'V';

    encoded[4] = current_version + 1;
    try std.testing.expectError(error.UnsupportedVersion, parseHeader(encoded[0..written]));
    encoded[4] = current_version;

    encoded[header_len] ^= 0xff;
    var out: [16]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, decode(encoded[0..written], &out));
}

test "native frame mode names cover known flags" {
    try std.testing.expectEqualStrings("store", frameModeName(flags_none));
    try std.testing.expectEqualStrings("deflate", frameModeName(flags_deflate));
    try std.testing.expectEqualStrings("rle", frameModeName(flags_rle));
    try std.testing.expectEqualStrings("dictionary_patch", frameModeName(flags_dictionary_patch));
    try std.testing.expectEqualStrings("ldm", frameModeName(flags_ldm));
    try std.testing.expectEqualStrings("dictionary_deflate", frameModeName(flags_dictionary_deflate));
    try std.testing.expectEqualStrings("unknown", frameModeName(255));
}

test "store frame checks output capacity and truncation" {
    var encoded: [128]u8 = undefined;
    const written = try encode("payload", &encoded);
    var short_out: [3]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decode(encoded[0..written], &short_out));
    try std.testing.expectError(error.TruncatedFrame, decode(encoded[0 .. written - 1], encoded[0..16]));
}

test "streaming encoder and decoder handle tiny output buffers" {
    const input = "chunked store streaming validates progress accounting";
    var encoder = Encoder.init(input);
    var encoded: [256]u8 = undefined;
    var encoded_len: usize = 0;
    while (true) {
        var scratch: [5]u8 = undefined;
        const step_result = encoder.step(&scratch);
        @memcpy(encoded[encoded_len..][0..step_result.progress.output_written], scratch[0..step_result.progress.output_written]);
        encoded_len += step_result.progress.output_written;
        if (step_result.status == .done) break;
        try std.testing.expectEqual(StepResult.Status.need_output, step_result.status);
    }

    var decoder = try Decoder.init(encoded[0..encoded_len]);
    var decoded: [input.len]u8 = undefined;
    var decoded_len: usize = 0;
    while (true) {
        var scratch: [7]u8 = undefined;
        const step_result = try decoder.step(&scratch);
        @memcpy(decoded[decoded_len..][0..step_result.progress.output_written], scratch[0..step_result.progress.output_written]);
        decoded_len += step_result.progress.output_written;
        if (step_result.status == .done) break;
        try std.testing.expectEqual(StepResult.Status.need_output, step_result.status);
    }
    try std.testing.expectEqualSlices(u8, input, decoded[0..decoded_len]);
}

test "incremental decoder accepts single-byte input and tiny output" {
    const input = "incremental input and output streaming";
    var encoded: [128]u8 = undefined;
    const encoded_len = try encode(input, &encoded);

    var decoder = IncrementalDecoder.init();
    var decoded: [input.len]u8 = undefined;
    var decoded_len: usize = 0;
    var input_offset: usize = 0;
    var guard: usize = 0;
    while (guard < 512) : (guard += 1) {
        var scratch: [3]u8 = undefined;
        const chunk_end = @min(encoded_len, input_offset + 1);
        const step_result = try decoder.step(encoded[input_offset..chunk_end], &scratch);
        input_offset += step_result.progress.input_read;
        @memcpy(decoded[decoded_len..][0..step_result.progress.output_written], scratch[0..step_result.progress.output_written]);
        decoded_len += step_result.progress.output_written;
        if (step_result.status == .done) break;
        if (step_result.status == .need_input) {
            try std.testing.expect(input_offset < encoded_len);
        }
    } else return error.TestUnexpectedResult;

    try std.testing.expectEqual(encoded_len, input_offset);
    try std.testing.expectEqualSlices(u8, input, decoded[0..decoded_len]);
}

test "incremental decoder reports checksum mismatch after corrupt payload" {
    var encoded: [128]u8 = undefined;
    const encoded_len = try encode("payload", &encoded);
    encoded[encoded_len - 1] ^= 0x55;

    var decoder = IncrementalDecoder.init();
    var out: [32]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, decoder.step(encoded[0..encoded_len], &out));
}

test "concatenated frame iterator and decode helper" {
    const first = "first";
    const second = "second frame";
    var buffer: [128]u8 = undefined;
    const first_len = try encode(first, &buffer);
    const second_len = try encode(second, buffer[first_len..]);
    const concatenated = buffer[0 .. first_len + second_len];

    try std.testing.expectEqual(@as(usize, 2), try countConcatenatedFrames(concatenated));

    var iterator = ConcatIterator.init(concatenated);
    const one = (try iterator.next()).?;
    try std.testing.expectEqual(@as(usize, 0), one.offset);
    try std.testing.expectEqualSlices(u8, first, one.payload);
    const two = (try iterator.next()).?;
    try std.testing.expectEqual(first_len, two.offset);
    try std.testing.expectEqualSlices(u8, second, two.payload);
    try std.testing.expectEqual(@as(?FrameSpan, null), try iterator.next());

    const decoded = try decodeConcatenatedAlloc(std.testing.allocator, concatenated);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, first ++ second, decoded);
}

test "concat iterator rejects trailing partial frame" {
    var buffer: [128]u8 = undefined;
    const first_len = try encode("ok", &buffer);
    @memcpy(buffer[first_len..][0..3], "VOR");
    try std.testing.expectError(error.TruncatedFrame, countConcatenatedFrames(buffer[0 .. first_len + 3]));
}

test "skippable frames encode parse and are ignored by concat decoder" {
    const skip = try encodeSkippableAlloc(std.testing.allocator, "metadata");
    defer std.testing.allocator.free(skip);
    try std.testing.expectEqualSlices(u8, "metadata", try parseSkippable(skip));

    const first = try encodeAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const second = try encodeAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);

    var combined: std.ArrayList(u8) = .empty;
    defer combined.deinit(std.testing.allocator);
    try combined.appendSlice(std.testing.allocator, first);
    try combined.appendSlice(std.testing.allocator, skip);
    try combined.appendSlice(std.testing.allocator, second);

    try std.testing.expectEqual(@as(usize, 2), try countConcatenatedFrames(combined.items));
    const decoded = try decodeConcatenatedAlloc(std.testing.allocator, combined.items);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "firstsecond", decoded);
}

test "skippable frame parser rejects truncation" {
    try std.testing.expectError(error.TruncatedFrame, parseSkippable(&.{ 'V', 'S', 'K', 'P', 4, 0, 0, 0, 'x' }));
}

test "frame index records offsets sizes and skips metadata" {
    const first = try encodeAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const skip = try encodeSkippableAlloc(std.testing.allocator, "meta");
    defer std.testing.allocator.free(skip);
    const second = try encodeAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);

    var combined: std.ArrayList(u8) = .empty;
    defer combined.deinit(std.testing.allocator);
    try combined.appendSlice(std.testing.allocator, first);
    try combined.appendSlice(std.testing.allocator, skip);
    try combined.appendSlice(std.testing.allocator, second);

    const index = try buildFrameIndexAlloc(std.testing.allocator, combined.items);
    defer std.testing.allocator.free(index);
    try std.testing.expectEqual(@as(usize, 2), index.len);
    try std.testing.expectEqual(@as(usize, 0), index[0].frame_offset);
    try std.testing.expectEqual(first.len, index[0].frame_len);
    try std.testing.expectEqual(@as(u64, 0), index[0].uncompressed_offset);
    try std.testing.expectEqual(@as(u64, 5), index[0].uncompressed_len);
    try std.testing.expectEqual(checksum.crc32("first"), index[0].checksum);
    try std.testing.expectEqual(first.len + skip.len, index[1].frame_offset);
    try std.testing.expectEqual(second.len, index[1].frame_len);
    try std.testing.expectEqual(@as(u64, 5), index[1].uncompressed_offset);
    try std.testing.expectEqual(@as(u64, 6), index[1].uncompressed_len);
    try std.testing.expectEqual(checksum.crc32("second"), index[1].checksum);
}

test "frame index serializes and decodes as sidecar" {
    const first = try encodeAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const second = try encodeAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);
    var combined: std.ArrayList(u8) = .empty;
    defer combined.deinit(std.testing.allocator);
    try combined.appendSlice(std.testing.allocator, first);
    try combined.appendSlice(std.testing.allocator, second);

    const index = try buildFrameIndexAlloc(std.testing.allocator, combined.items);
    defer std.testing.allocator.free(index);
    const encoded = try encodeFrameIndexAlloc(std.testing.allocator, index);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeFrameIndexAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(index.len, decoded.len);
    for (index, decoded) |expected, actual| {
        try std.testing.expectEqual(expected.frame_offset, actual.frame_offset);
        try std.testing.expectEqual(expected.frame_len, actual.frame_len);
        try std.testing.expectEqual(expected.uncompressed_offset, actual.uncompressed_offset);
        try std.testing.expectEqual(expected.uncompressed_len, actual.uncompressed_len);
        try std.testing.expectEqual(expected.checksum, actual.checksum);
    }
}

test "frame index combines frame checksums into whole payload checksum" {
    const payloads = [_][]const u8{
        "first block",
        "second block with more entropy",
        "third block",
    };
    var expected_payload = std.ArrayList(u8).empty;
    defer expected_payload.deinit(std.testing.allocator);
    var combined_stream = std.ArrayList(u8).empty;
    defer combined_stream.deinit(std.testing.allocator);
    for (payloads) |payload| {
        try expected_payload.appendSlice(std.testing.allocator, payload);
        const frame = try encodeBestAlloc(std.testing.allocator, payload);
        defer std.testing.allocator.free(frame);
        try combined_stream.appendSlice(std.testing.allocator, frame);
    }

    const index = try buildFrameIndexAlloc(std.testing.allocator, combined_stream.items);
    defer std.testing.allocator.free(index);
    try std.testing.expectEqual(checksum.crc32(expected_payload.items), try frameIndexCombinedChecksum(index));
    const summary = try summarizeFrameIndex(index);
    try std.testing.expectEqual(index.len, summary.frame_count);
    try std.testing.expectEqual(@as(u64, expected_payload.items.len), summary.total_uncompressed);
    try std.testing.expectEqual(checksum.crc32(expected_payload.items), summary.combined_checksum);

    const encoded = try encodeFrameIndexAlloc(std.testing.allocator, index);
    defer std.testing.allocator.free(encoded);
    const decoded = try decodeFrameIndexAlloc(std.testing.allocator, encoded);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqual(checksum.crc32(expected_payload.items), try frameIndexCombinedChecksum(decoded));
}

test "frame index supports seek and range decode" {
    const parts = [_][]const u8{ "alpha", "beta", "gamma" };
    var combined: std.ArrayList(u8) = .empty;
    defer combined.deinit(std.testing.allocator);
    for (parts) |part| {
        const frame = try encodeAlloc(std.testing.allocator, part);
        defer std.testing.allocator.free(frame);
        try combined.appendSlice(std.testing.allocator, frame);
    }
    const index = try buildFrameIndexAlloc(std.testing.allocator, combined.items);
    defer std.testing.allocator.free(index);
    try std.testing.expectEqual(@as(?usize, 0), findFrameForOffset(index, 0));
    try std.testing.expectEqual(@as(?usize, 1), findFrameForOffset(index, 5));
    try std.testing.expectEqual(@as(?usize, 2), findFrameForOffset(index, 9));
    try std.testing.expectEqual(@as(?usize, null), findFrameForOffset(index, 14));

    const range = try decodeRangeAlloc(std.testing.allocator, combined.items, index, 3, 8);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, "habetaga", range);
    const summary = try decodeRangeWithSummaryAlloc(std.testing.allocator, combined.items, index, 3, 8);
    defer summary.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 3), summary.offset);
    try std.testing.expectEqualSlices(u8, "habetaga", summary.bytes);
    try std.testing.expectEqual(checksum.crc32("habetaga"), summary.crc32);
    const batch = try decodeRangesWithSummaryAlloc(std.testing.allocator, combined.items, index, &.{
        .{ .offset = 0, .length = 5 },
        .{ .offset = 3, .length = 8 },
        .{ .offset = 9, .length = 5 },
    });
    defer batch.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), batch.ranges.len);
    try std.testing.expectEqualSlices(u8, "alpha", batch.ranges[0].bytes);
    try std.testing.expectEqual(checksum.crc32("alpha"), batch.ranges[0].crc32);
    try std.testing.expectEqualSlices(u8, "habetaga", batch.ranges[1].bytes);
    try std.testing.expectEqual(checksum.crc32("habetaga"), batch.ranges[1].crc32);
    try std.testing.expectEqualSlices(u8, "gamma", batch.ranges[2].bytes);
    try std.testing.expectEqual(checksum.crc32("gamma"), batch.ranges[2].crc32);
    try std.testing.expectError(error.RangeOutOfBounds, decodeRangesWithSummaryAlloc(std.testing.allocator, combined.items, index, &.{
        .{ .offset = 0, .length = 5 },
        .{ .offset = 12, .length = 8 },
    }));
    try std.testing.expectError(error.RangeOutOfBounds, decodeRangesWithSummaryAlloc(std.testing.failing_allocator, combined.items, index, &.{
        .{ .offset = 0, .length = 5 },
        .{ .offset = 12, .length = 8 },
    }));
    var buffer: [8]u8 = undefined;
    const into = try decodeRangeInto(std.testing.allocator, combined.items, index, 3, buffer.len, buffer[0..]);
    try std.testing.expectEqual(buffer.len, into.output_written);
    try std.testing.expectEqual(@as(u64, 3), into.offset);
    try std.testing.expectEqualSlices(u8, "habetaga", &buffer);
    try std.testing.expectEqual(checksum.crc32(&buffer), into.crc32);
    var batch_a: [5]u8 = undefined;
    var batch_b: [8]u8 = undefined;
    var batch_results: [2]RangeDecodeIntoResult = undefined;
    try decodeRangesInto(std.testing.allocator, combined.items, index, &.{
        .{ .offset = 0, .length = batch_a.len, .output = batch_a[0..] },
        .{ .offset = 3, .length = batch_b.len, .output = batch_b[0..] },
    }, batch_results[0..]);
    try std.testing.expectEqualSlices(u8, "alpha", &batch_a);
    try std.testing.expectEqual(checksum.crc32(&batch_a), batch_results[0].crc32);
    try std.testing.expectEqualSlices(u8, "habetaga", &batch_b);
    try std.testing.expectEqual(checksum.crc32(&batch_b), batch_results[1].crc32);
    const corrupt_store = try std.testing.allocator.dupe(u8, combined.items);
    defer std.testing.allocator.free(corrupt_store);
    corrupt_store[header_len] ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeRangeInto(std.testing.allocator, corrupt_store, index, 0, batch_a.len, batch_a[0..]));
    @memset(batch_a[0..], '!');
    @memset(batch_b[0..], '!');
    try std.testing.expectError(error.OutputTooSmall, decodeRangesInto(std.testing.allocator, combined.items, index, &.{
        .{ .offset = 0, .length = batch_a.len, .output = batch_a[0..] },
        .{ .offset = 3, .length = batch_b.len, .output = batch_b[0..] },
    }, batch_results[0..1]));
    try std.testing.expectEqualSlices(u8, "!!!!!", &batch_a);
    try std.testing.expectEqualSlices(u8, "!!!!!!!!", &batch_b);
    try std.testing.expectError(error.OutputTooSmall, decodeRangesInto(std.testing.allocator, combined.items, index, &.{
        .{ .offset = 0, .length = batch_a.len, .output = batch_a[0..] },
        .{ .offset = 3, .length = batch_b.len, .output = batch_b[0..7] },
    }, batch_results[0..]));
    try std.testing.expectEqualSlices(u8, "!!!!!", &batch_a);
    try std.testing.expectEqualSlices(u8, "!!!!!!!!", &batch_b);
    try std.testing.expectError(error.RangeOutOfBounds, decodeRangesInto(std.testing.allocator, combined.items, index, &.{
        .{ .offset = 0, .length = batch_a.len, .output = batch_a[0..] },
        .{ .offset = 12, .length = batch_b.len, .output = batch_b[0..] },
    }, batch_results[0..]));
    try std.testing.expectEqualSlices(u8, "!!!!!", &batch_a);
    try std.testing.expectEqualSlices(u8, "!!!!!!!!", &batch_b);
    try std.testing.expectError(error.OutputTooSmall, decodeRangeInto(std.testing.allocator, combined.items, index, 3, buffer.len, buffer[0..7]));
}

test "range decode rejects out of bounds" {
    const frame = try encodeAlloc(std.testing.allocator, "short");
    defer std.testing.allocator.free(frame);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);
    try std.testing.expectError(error.RangeOutOfBounds, decodeRangeAlloc(std.testing.allocator, frame, index, 4, 4));
}

test "zero-length range decode succeeds for empty indexed stream" {
    const stream = try encodeBlockedBestStreamAlloc(std.testing.allocator, "", 8);
    defer std.testing.allocator.free(stream);
    const range = try decodeIndexedRangeAlloc(std.testing.allocator, stream, 0, 0);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqual(@as(usize, 0), range.len);
}

test "range decode validates sidecar index checksum" {
    const frame = try encodeAlloc(std.testing.allocator, "indexed checksum guard");
    defer std.testing.allocator.free(frame);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);
    try std.testing.expect(index.len == 1);

    const tampered = try std.testing.allocator.dupe(FrameIndexEntry, index);
    defer std.testing.allocator.free(tampered);
    tampered[0].checksum ^= 1;
    try std.testing.expectError(error.ChecksumMismatch, decodeRangeAlloc(std.testing.allocator, frame, tampered, 0, 4));

    tampered[0].checksum = index[0].checksum;
    tampered[0].uncompressed_len += 1;
    try std.testing.expectError(error.CorruptFrame, decodeRangeAlloc(std.testing.allocator, frame, tampered, 0, 4));

    tampered[0].uncompressed_len = index[0].uncompressed_len;
    tampered[0].frame_len -= 1;
    try std.testing.expectError(error.CorruptFrame, decodeRangeAlloc(std.testing.allocator, frame, tampered, 0, 4));
}

test "frame index validation rejects gaps overlaps and empty frames" {
    const first = try encodeAlloc(std.testing.allocator, "first");
    defer std.testing.allocator.free(first);
    const second = try encodeAlloc(std.testing.allocator, "second");
    defer std.testing.allocator.free(second);
    var combined: std.ArrayList(u8) = .empty;
    defer combined.deinit(std.testing.allocator);
    try combined.appendSlice(std.testing.allocator, first);
    try combined.appendSlice(std.testing.allocator, second);
    const index = try buildFrameIndexAlloc(std.testing.allocator, combined.items);
    defer std.testing.allocator.free(index);
    try validateFrameIndex(index);

    const tampered = try std.testing.allocator.dupe(FrameIndexEntry, index);
    defer std.testing.allocator.free(tampered);
    tampered[1].uncompressed_offset += 1;
    try std.testing.expectError(error.CorruptFrame, validateFrameIndex(tampered));

    tampered[1].uncompressed_offset = index[1].uncompressed_offset;
    tampered[1].frame_offset = index[0].frame_offset;
    try std.testing.expectError(error.CorruptFrame, validateFrameIndex(tampered));

    tampered[1].frame_offset = index[1].frame_offset;
    tampered[1].uncompressed_len = 0;
    try std.testing.expectError(error.CorruptFrame, validateFrameIndex(tampered));
}

test "indexed stream embeds sidecar index as skippable frame" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const stream = try encodeIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer std.testing.allocator.free(stream);
    const embedded = try parseEmbeddedIndexAlloc(std.testing.allocator, stream);
    defer embedded.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 3), embedded.entries.len);
    try std.testing.expect(embedded.payload_offset > 0);
    const range = try decodeIndexedRangeAlloc(std.testing.allocator, stream, 3, 8);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, "habetaga", range);
}

test "sidecar indexed stream encoder keeps index external" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const sidecar = try encodeSidecarIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer sidecar.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidMagic, parseEmbeddedIndexAlloc(std.testing.allocator, sidecar.stream));
    const range = try decodeSidecarIndexedRangeAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, 3, 8);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, "habetaga", range);
}

test "sidecar index bytes support range decode without embedded index" {
    const first = try encodeAlloc(std.testing.allocator, "alpha");
    defer std.testing.allocator.free(first);
    const second = try encodeAlloc(std.testing.allocator, "beta");
    defer std.testing.allocator.free(second);
    var stream: std.ArrayList(u8) = .empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, second);
    const index = try buildFrameIndexAlloc(std.testing.allocator, stream.items);
    defer std.testing.allocator.free(index);
    const sidecar = try encodeFrameIndexAlloc(std.testing.allocator, index);
    defer std.testing.allocator.free(sidecar);
    const range = try decodeSidecarIndexedRangeAlloc(std.testing.allocator, stream.items, sidecar, 3, 5);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, "habet", range);
    const summary = try decodeSidecarIndexedRangeWithSummaryAlloc(std.testing.allocator, stream.items, sidecar, 3, 5);
    defer summary.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(u64, 3), summary.offset);
    try std.testing.expectEqualSlices(u8, "habet", summary.bytes);
    try std.testing.expectEqual(checksum.crc32("habet"), summary.crc32);
    var buffer: [5]u8 = undefined;
    const into = try decodeSidecarIndexedRangeInto(std.testing.allocator, stream.items, sidecar, 3, buffer.len, buffer[0..]);
    try std.testing.expectEqual(buffer.len, into.output_written);
    try std.testing.expectEqual(@as(u64, 3), into.offset);
    try std.testing.expectEqualSlices(u8, "habet", &buffer);
    try std.testing.expectEqual(checksum.crc32(&buffer), into.crc32);
}

test "sidecar index range decode rejects tampered checksum" {
    const frame = try encodeAlloc(std.testing.allocator, "checksum sidecar");
    defer std.testing.allocator.free(frame);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);
    const tampered = try std.testing.allocator.dupe(FrameIndexEntry, index);
    defer std.testing.allocator.free(tampered);
    tampered[0].checksum ^= 1;
    const sidecar = try encodeFrameIndexAlloc(std.testing.allocator, tampered);
    defer std.testing.allocator.free(sidecar);
    try std.testing.expectError(error.ChecksumMismatch, decodeSidecarIndexedRangeAlloc(std.testing.allocator, frame, sidecar, 0, 8));
    try std.testing.expectError(error.ChecksumMismatch, validateSidecarIndexAlloc(std.testing.allocator, frame, sidecar));
}

test "sidecar index validator decodes frames to catch payload tampering" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const sidecar = try encodeSidecarIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer sidecar.deinit(std.testing.allocator);

    const tampered = try std.testing.allocator.dupe(u8, sidecar.stream);
    defer std.testing.allocator.free(tampered);
    tampered[header_len] ^= 1;

    try std.testing.expectError(error.ChecksumMismatch, validateSidecarIndexAlloc(std.testing.allocator, tampered, sidecar.sidecar_index));
}

test "sidecar validator reuses payload scratch during full decode" {
    const payloads = [_][]const u8{
        "alpha frame",
        "beta frame",
        "gamma frame",
    };
    const sidecar = try encodeSidecarIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer sidecar.deinit(std.testing.allocator);
    const index = try decodeFrameIndexAlloc(std.testing.allocator, sidecar.sidecar_index);
    defer std.testing.allocator.free(index);

    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    try validateFrameIndexEntriesInternalAlloc(failing.allocator(), null, sidecar.stream, index, .{ .mode = .full });
    try std.testing.expectEqual(@as(usize, 1), failing.allocations);

    var report_failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const report = validateFrameIndexEntriesReportInternalAlloc(report_failing.allocator(), null, sidecar.stream, index, .{ .mode = .full });
    try std.testing.expect(report.ok);
    try std.testing.expectEqual(@as(usize, 1), report_failing.allocations);
}

test "sidecar index metadata validation skips payload decode by design" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const sidecar = try encodeSidecarIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer sidecar.deinit(std.testing.allocator);

    const tampered = try std.testing.allocator.dupe(u8, sidecar.stream);
    defer std.testing.allocator.free(tampered);
    tampered[header_len] ^= 1;

    try validateSidecarIndexMetadataAlloc(std.testing.allocator, tampered, sidecar.sidecar_index);
    try validateSidecarIndexWithOptionsAlloc(std.testing.allocator, tampered, sidecar.sidecar_index, .{ .mode = .metadata });
    try std.testing.expectError(error.ChecksumMismatch, validateSidecarIndexWithOptionsAlloc(std.testing.allocator, tampered, sidecar.sidecar_index, .{ .mode = .full }));
}

test "sidecar index report captures frame failure context" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const sidecar = try encodeSidecarIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer sidecar.deinit(std.testing.allocator);

    const ok_report = validateSidecarIndexReportAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, .{ .mode = .metadata });
    try std.testing.expect(ok_report.ok);
    try std.testing.expectEqual(SidecarValidationMode.metadata, ok_report.mode);
    try std.testing.expectEqual(@as(usize, 3), ok_report.frame_count);
    try std.testing.expectEqual(@as(u64, "alphabetagamma".len), ok_report.total_uncompressed);
    try std.testing.expectEqual(checksum.crc32("alphabetagamma"), ok_report.combined_checksum.?);

    const tampered = try std.testing.allocator.dupe(u8, sidecar.stream);
    defer std.testing.allocator.free(tampered);
    tampered[header_len] ^= 1;

    const report = validateSidecarIndexReportAlloc(std.testing.allocator, tampered, sidecar.sidecar_index, .{ .mode = .full });
    try std.testing.expect(!report.ok);
    try std.testing.expectEqual(SidecarValidationMode.full, report.mode);
    try std.testing.expectEqual(ValidationStage.payload_decode, report.stage);
    try std.testing.expectEqualStrings("ChecksumMismatch", report.error_name);
    try std.testing.expectEqual(ValidationHint.payload_corrupt, report.recoverability_hint);
    try std.testing.expectEqual(@as(?usize, 0), report.frame_index);
    try std.testing.expectEqual(@as(?usize, 0), report.frame_offset);
    try std.testing.expectEqual(@as(?u64, 0), report.uncompressed_offset);
    try std.testing.expectEqual(@as(?u8, flags_none), report.frame_flags);
    try std.testing.expectEqualStrings("store", report.frame_mode);
}

test "sidecar validation options enforce expected logical checksum and length" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const sidecar = try encodeSidecarIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer sidecar.deinit(std.testing.allocator);

    const expected_payload = "alphabetagamma";
    const expected_checksum = checksum.crc32(expected_payload);
    try validateSidecarIndexWithOptionsAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, .{
        .mode = .metadata,
        .expected_total_uncompressed = expected_payload.len,
        .expected_checksum = expected_checksum,
    });

    try std.testing.expectError(error.SizeMismatch, validateSidecarIndexWithOptionsAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, .{
        .mode = .metadata,
        .expected_total_uncompressed = expected_payload.len + 1,
        .expected_checksum = expected_checksum,
    }));
    try std.testing.expectError(error.ChecksumMismatch, validateSidecarIndexWithOptionsAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, .{
        .mode = .metadata,
        .expected_total_uncompressed = expected_payload.len,
        .expected_checksum = expected_checksum ^ 1,
    }));

    const report = validateSidecarIndexReportAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, .{
        .mode = .metadata,
        .expected_checksum = expected_checksum ^ 1,
    });
    try std.testing.expect(!report.ok);
    try std.testing.expectEqual(ValidationStage.frame_metadata, report.stage);
    try std.testing.expectEqualStrings("ChecksumMismatch", report.error_name);
    try std.testing.expectEqual(ValidationHint.index_mismatch, report.recoverability_hint);
}

test "embedded index report includes combined checksum summary" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const stream = try encodeIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer std.testing.allocator.free(stream);
    const report = validateEmbeddedIndexReportAlloc(std.testing.allocator, stream, .{ .mode = .full });
    try std.testing.expect(report.ok);
    try std.testing.expectEqual(SidecarValidationMode.full, report.mode);
    try std.testing.expectEqual(@as(usize, 3), report.frame_count);
    try std.testing.expectEqual(@as(u64, "alphabetagamma".len), report.total_uncompressed);
    try std.testing.expectEqual(checksum.crc32("alphabetagamma"), report.combined_checksum.?);
}

test "embedded validation options enforce expected logical checksum and length" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const stream = try encodeIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer std.testing.allocator.free(stream);

    const expected_payload = "alphabetagamma";
    const expected_checksum = checksum.crc32(expected_payload);
    try validateEmbeddedIndexWithOptionsAlloc(std.testing.allocator, stream, .{
        .mode = .metadata,
        .expected_total_uncompressed = expected_payload.len,
        .expected_checksum = expected_checksum,
    });
    try std.testing.expectError(error.SizeMismatch, validateEmbeddedIndexWithOptionsAlloc(std.testing.allocator, stream, .{
        .mode = .metadata,
        .expected_total_uncompressed = expected_payload.len + 1,
    }));
    const report = validateEmbeddedIndexReportAlloc(std.testing.allocator, stream, .{
        .mode = .metadata,
        .expected_checksum = expected_checksum ^ 1,
    });
    try std.testing.expect(!report.ok);
    try std.testing.expectEqual(ValidationStage.frame_metadata, report.stage);
    try std.testing.expectEqualStrings("ChecksumMismatch", report.error_name);
}

test "embedded index validation supports metadata and full modes" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const stream = try encodeIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer std.testing.allocator.free(stream);

    try validateEmbeddedIndexAlloc(std.testing.allocator, stream);
    const tampered = try std.testing.allocator.dupe(u8, stream);
    defer std.testing.allocator.free(tampered);
    tampered[header_len] ^= 1;

    try validateEmbeddedIndexMetadataAlloc(std.testing.allocator, tampered);
    try validateEmbeddedIndexWithOptionsAlloc(std.testing.allocator, tampered, .{ .mode = .metadata });
    try std.testing.expectError(error.ChecksumMismatch, validateEmbeddedIndexWithOptionsAlloc(std.testing.allocator, tampered, .{ .mode = .full }));
}

test "embedded index report captures frame failure context" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const stream = try encodeIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer std.testing.allocator.free(stream);

    const tampered = try std.testing.allocator.dupe(u8, stream);
    defer std.testing.allocator.free(tampered);
    tampered[header_len] ^= 1;

    const report = validateEmbeddedIndexReportAlloc(std.testing.allocator, tampered, .{ .mode = .full });
    try std.testing.expect(!report.ok);
    try std.testing.expectEqual(SidecarValidationMode.full, report.mode);
    try std.testing.expectEqual(ValidationStage.payload_decode, report.stage);
    try std.testing.expectEqualStrings("ChecksumMismatch", report.error_name);
    try std.testing.expectEqual(ValidationHint.payload_corrupt, report.recoverability_hint);
    try std.testing.expectEqual(@as(?usize, 0), report.frame_index);
    try std.testing.expectEqual(@as(?usize, 0), report.frame_offset);
    try std.testing.expectEqual(@as(?u64, 0), report.uncompressed_offset);
    try std.testing.expectEqual(@as(?u8, flags_none), report.frame_flags);
    try std.testing.expectEqualStrings("store", report.frame_mode);
}

test "embedded index validation auto-loads embedded dictionaries" {
    const phrase = "self-contained dictionary phrase for native streams";
    const input = (phrase ++ "!") ** 4;
    const stream = try encodeSelfContainedDictionaryStreamAlloc(std.testing.allocator, input, phrase.len + 1, 256, 8);
    defer std.testing.allocator.free(stream);

    try validateEmbeddedIndexAlloc(std.testing.allocator, stream);
    const tampered = try std.testing.allocator.dupe(u8, stream);
    defer std.testing.allocator.free(tampered);
    const embedded = try parseEmbeddedIndexAlloc(std.testing.allocator, stream);
    defer embedded.deinit(std.testing.allocator);
    tampered[embedded.entries[0].frame_offset + header_len] ^= 1;

    try validateEmbeddedIndexMetadataAlloc(std.testing.allocator, tampered);
    validateEmbeddedIndexAlloc(std.testing.allocator, tampered) catch |err| switch (err) {
        error.ChecksumMismatch,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.InvalidHuffmanCode,
        error.SizeMismatch,
        => return,
        else => return err,
    };
    try std.testing.expect(false);
}

test "sidecar index validator accepts matching stream" {
    const payloads = [_][]const u8{ "alpha", "beta", "gamma" };
    const sidecar = try encodeSidecarIndexedStreamAlloc(std.testing.allocator, &payloads);
    defer sidecar.deinit(std.testing.allocator);
    try validateSidecarIndexAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index);
}

test "sidecar index bytes support dictionary range decode" {
    const dict = "dictionary-only phrase with enough length to beat stored framing";
    const input = (dict ++ "!") ** 2;
    const frame = try encodeBestWithDictionaryAlloc(std.testing.allocator, dict, input, 8);
    defer std.testing.allocator.free(frame);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);
    const sidecar = try encodeFrameIndexAlloc(std.testing.allocator, index);
    defer std.testing.allocator.free(sidecar);
    const range = try decodeSidecarIndexedRangeWithDictionaryAlloc(std.testing.allocator, dict, frame, sidecar, 5, 40);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[5..45], range);
}

test "sidecar index validator supports caller-supplied dictionaries" {
    const dict = "dictionary-only phrase with enough length to beat stored framing";
    const input = (dict ++ "!") ** 2;
    const frame = try encodeBestWithDictionaryAlloc(std.testing.allocator, dict, input, 8);
    defer std.testing.allocator.free(frame);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);
    const sidecar = try encodeFrameIndexAlloc(std.testing.allocator, index);
    defer std.testing.allocator.free(sidecar);

    try validateSidecarIndexWithDictionaryAlloc(std.testing.allocator, dict, frame, sidecar);
    try validateSidecarIndexWithOptionsAlloc(std.testing.allocator, frame, sidecar, .{ .dictionary = dict });
    try validateSidecarIndexWithOptionsAlloc(std.testing.allocator, frame, sidecar, .{ .mode = .metadata });
    try std.testing.expectError(error.InvalidDictionaryTraining, validateSidecarIndexAlloc(std.testing.allocator, frame, sidecar));
}

test "sidecar index auto range decode uses embedded dictionary when present" {
    const phrase = "self-contained dictionary phrase for native streams";
    const input = (phrase ++ "!") ** 3;
    const stream = try encodeSelfContainedDictionaryStreamAlloc(std.testing.allocator, input, phrase.len + 1, 256, 8);
    defer std.testing.allocator.free(stream);
    const embedded = try parseEmbeddedIndexAlloc(std.testing.allocator, stream);
    defer embedded.deinit(std.testing.allocator);
    const sidecar = try encodeFrameIndexAlloc(std.testing.allocator, embedded.entries);
    defer std.testing.allocator.free(sidecar);
    const range = try decodeSidecarIndexedRangeAutoAlloc(std.testing.allocator, stream, sidecar, 7, 64);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[7..71], range);
}

test "sidecar index validator auto-loads embedded dictionary and catches corrupt dictionary payloads" {
    const phrase = "self-contained dictionary phrase for native streams";
    const input = (phrase ++ "!") ** 3;
    const stream = try encodeSelfContainedDictionaryStreamAlloc(std.testing.allocator, input, phrase.len + 1, 256, 8);
    defer std.testing.allocator.free(stream);
    const embedded = try parseEmbeddedIndexAlloc(std.testing.allocator, stream);
    defer embedded.deinit(std.testing.allocator);
    const sidecar = try encodeFrameIndexAlloc(std.testing.allocator, embedded.entries);
    defer std.testing.allocator.free(sidecar);

    try validateSidecarIndexAlloc(std.testing.allocator, stream, sidecar);

    const tampered = try std.testing.allocator.dupe(u8, stream);
    defer std.testing.allocator.free(tampered);
    const entry = embedded.entries[0];
    tampered[entry.frame_offset + header_len] ^= 1;
    validateSidecarIndexAlloc(std.testing.allocator, tampered, sidecar) catch |err| switch (err) {
        error.ChecksumMismatch,
        error.TruncatedFrame,
        error.CorruptFrame,
        error.InvalidHuffmanCode,
        error.SizeMismatch,
        => return,
        else => return err,
    };
    try std.testing.expect(false);
}

test "native deflate frame round trips and records compressed flag" {
    const input = "hello hello hello hello";
    const frame = try encodeDeflateAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_deflate, info.flags);
    try std.testing.expect(info.stored_size < info.uncompressed_size);
    const decoded = try decodeAnyAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "full deflate frame range decodes into caller buffer without allocation" {
    const input = "hello hello hello hello";
    const frame = try encodeDeflateAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_deflate, info.flags);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);

    var out: [input.len]u8 = undefined;
    const result = try decodeRangeInto(std.testing.failing_allocator, frame, index, 0, out.len, out[0..]);
    try std.testing.expectEqual(out.len, result.output_written);
    try std.testing.expectEqual(@as(u64, 0), result.offset);
    try std.testing.expectEqualSlices(u8, input, &out);
    try std.testing.expectEqual(checksum.crc32(input), result.crc32);
}

test "range alloc reuses range-into fast path for full deflate frames" {
    const input = "hello hello hello hello";
    const frame = try encodeDeflateAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_deflate, info.flags);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);

    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 1 });
    const decoded = try decodeRangeAlloc(failing.allocator(), frame, index, 0, input.len);
    defer failing.allocator().free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expectEqual(@as(usize, 1), failing.allocations);
}

test "batch range into avoids cache allocation when fast paths satisfy requests" {
    const first_input = "hello hello hello hello";
    const second_input = "bye bye bye bye bye";
    const first = try encodeDeflateAlloc(std.testing.allocator, first_input);
    defer std.testing.allocator.free(first);
    const second = try encodeDeflateAlloc(std.testing.allocator, second_input);
    defer std.testing.allocator.free(second);

    var stream = std.ArrayList(u8).empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, first);
    try stream.appendSlice(std.testing.allocator, second);
    const index = try buildFrameIndexAlloc(std.testing.allocator, stream.items);
    defer std.testing.allocator.free(index);
    try std.testing.expectEqual(@as(usize, 2), index.len);

    var first_out: [first_input.len]u8 = undefined;
    var second_out: [second_input.len]u8 = undefined;
    var results: [2]RangeDecodeIntoResult = undefined;
    try decodeRangesInto(std.testing.failing_allocator, stream.items, index, &.{
        .{ .offset = 0, .length = first_out.len, .output = first_out[0..] },
        .{ .offset = first_input.len, .length = second_out.len, .output = second_out[0..] },
    }, results[0..]);
    try std.testing.expectEqualSlices(u8, first_input, &first_out);
    try std.testing.expectEqualSlices(u8, second_input, &second_out);
    try std.testing.expectEqual(checksum.crc32(first_input), results[0].crc32);
    try std.testing.expectEqual(checksum.crc32(second_input), results[1].crc32);
}

test "decodeAnyAlloc preserves old store frames" {
    const frame = try encodeAlloc(std.testing.allocator, "store");
    defer std.testing.allocator.free(frame);
    const decoded = try decodeAnyAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, "store", decoded);
}

test "decodeAnyAlloc exact-size and limited variants bound native output" {
    const input = "hello hello hello hello";
    const frame = try encodeDeflateAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(frame);

    const exact = try decodeAnyAllocExactSize(std.testing.allocator, frame, input.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, input, exact);

    const limited = try decodeAnyAllocLimited(std.testing.allocator, frame, input.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, input, limited);

    try std.testing.expectError(error.SizeMismatch, decodeAnyAllocExactSize(std.testing.allocator, frame, input.len - 1));
    try std.testing.expectError(error.SizeMismatch, decodeAnyAllocExactSize(std.testing.allocator, frame, input.len + 1));
    try std.testing.expectError(error.OutputLimitExceeded, decodeAnyAllocLimited(std.testing.allocator, frame, input.len - 1));
}

test "decodeAnyInto covers non-dictionary native frame modes" {
    const store_frame = try encodeAlloc(std.testing.allocator, "store payload");
    defer std.testing.allocator.free(store_frame);
    var store_out: ["store payload".len]u8 = undefined;
    try std.testing.expectEqual(store_out.len, try decodeAnyInto(store_frame, &store_out));
    try std.testing.expectEqualSlices(u8, "store payload", &store_out);

    const deflate_input = "hello hello hello hello";
    const deflate_frame = try encodeDeflateAlloc(std.testing.allocator, deflate_input);
    defer std.testing.allocator.free(deflate_frame);
    var deflate_out: [deflate_input.len]u8 = undefined;
    try std.testing.expectEqual(deflate_out.len, try decodeAnyInto(deflate_frame, &deflate_out));
    try std.testing.expectEqualSlices(u8, deflate_input, &deflate_out);

    const rle_input = "aaaaabbbbbbbbbbbbbcccccccccccccccc";
    const rle_frame = try encodeRleAlloc(std.testing.allocator, rle_input);
    defer std.testing.allocator.free(rle_frame);
    var rle_out: [rle_input.len]u8 = undefined;
    try std.testing.expectEqual(rle_out.len, try decodeAnyInto(rle_frame, &rle_out));
    try std.testing.expectEqualSlices(u8, rle_input, &rle_out);

    const prefix = deterministicLdmPrefix();
    const ldm_input = prefix ++ "----" ++ prefix[0..64].*;
    const ldm_frame = try encodeLongDistanceAlloc(std.testing.allocator, ldm_input, .{ .min_distance = 32769, .min_length = 16 });
    defer std.testing.allocator.free(ldm_frame);
    var ldm_out: [ldm_input.len]u8 = undefined;
    try std.testing.expectEqual(ldm_out.len, try decodeAnyInto(ldm_frame, &ldm_out));
    try std.testing.expectEqualSlices(u8, ldm_input, &ldm_out);

    var short: ["store payload".len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeAnyInto(store_frame, &short));
}

test "indexed deflate stream supports embedded range decode" {
    const payloads = [_][]const u8{ "alpha alpha", "beta beta", "gamma gamma" };
    const stream = try encodeIndexedDeflateStreamAlloc(std.testing.allocator, &payloads);
    defer std.testing.allocator.free(stream);
    const range = try decodeIndexedRangeAlloc(std.testing.allocator, stream, 6, 10);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, "alphabeta ", range);
}

test "indexed long-distance stream supports embedded range decode" {
    const prefix = deterministicLdmPrefix();
    const payloads = [_][]const u8{
        prefix ++ "----" ++ prefix[0..1024].*,
        "tail",
    };
    const stream = try encodeIndexedLongDistanceStreamAlloc(std.testing.allocator, &payloads, .{ .min_distance = 32769, .min_length = 16 });
    defer std.testing.allocator.free(stream);
    const summary = try summarizeModes(stream);
    try std.testing.expect(summary.ldm > 0);
    const range = try decodeIndexedRangeAlloc(std.testing.allocator, stream, prefix.len + 4, 16);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, prefix[0..16], range);
    const batch = try decodeIndexedRangesWithSummaryAlloc(std.testing.allocator, stream, &.{
        .{ .offset = prefix.len + 4, .length = 16 },
        .{ .offset = prefix.len + 20, .length = 16 },
    });
    defer batch.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, prefix[0..16], batch.ranges[0].bytes);
    try std.testing.expectEqual(checksum.crc32(prefix[0..16]), batch.ranges[0].crc32);
    try std.testing.expectEqualSlices(u8, prefix[16..32], batch.ranges[1].bytes);
    try std.testing.expectEqual(checksum.crc32(prefix[16..32]), batch.ranges[1].crc32);
    var first: [16]u8 = undefined;
    var second: [16]u8 = undefined;
    var results: [2]RangeDecodeIntoResult = undefined;
    try decodeIndexedRangesInto(std.testing.allocator, stream, &.{
        .{ .offset = prefix.len + 4, .length = first.len, .output = first[0..] },
        .{ .offset = prefix.len + 20, .length = second.len, .output = second[0..] },
    }, results[0..]);
    try std.testing.expectEqualSlices(u8, prefix[0..16], &first);
    try std.testing.expectEqual(checksum.crc32(&first), results[0].crc32);
    try std.testing.expectEqualSlices(u8, prefix[16..32], &second);
    try std.testing.expectEqual(checksum.crc32(&second), results[1].crc32);
    @memset(first[0..], '!');
    @memset(second[0..], '!');
    try std.testing.expectError(error.RangeOutOfBounds, decodeIndexedRangesInto(std.testing.allocator, stream, &.{
        .{ .offset = prefix.len + 4, .length = first.len, .output = first[0..] },
        .{ .offset = @as(u64, prefix.len + 2048), .length = second.len, .output = second[0..] },
    }, results[0..]));
    try std.testing.expectEqualSlices(u8, "!!!!!!!!!!!!!!!!", &first);
    try std.testing.expectEqualSlices(u8, "!!!!!!!!!!!!!!!!", &second);
}

test "blocked deflate stream splits input and supports range decode" {
    const input = "abcdefghijklmnopqrstuvwxyz";
    const stream = try encodeBlockedDeflateStreamAlloc(std.testing.allocator, input, 7);
    defer std.testing.allocator.free(stream);
    const embedded = try parseEmbeddedIndexAlloc(std.testing.allocator, stream);
    defer embedded.deinit(std.testing.allocator);
    try std.testing.expectEqual(@as(usize, 4), embedded.entries.len);
    const range = try decodeIndexedRangeAlloc(std.testing.allocator, stream, 5, 12);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, "fghijklmnopq", range);
}

test "blocked best stream selects native modes and supports range decode" {
    const input = "abcdefghijklmnopqrstuvwxyz" ++ ("aaaaaaaaaaaaaaaa" ** 2) ++ ("abcabcabcabc" ** 2);
    const stream = try encodeBlockedBestStreamAlloc(std.testing.allocator, input, 16);
    defer std.testing.allocator.free(stream);
    const summary = try summarizeModes(stream);
    try std.testing.expect(summary.store + summary.deflate + summary.rle >= 2);
    try std.testing.expect(summary.rle >= 1);
    const range = try decodeIndexedRangeAlloc(std.testing.allocator, stream, 10, 32);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[10..42], range);
    const embedded = try parseEmbeddedIndexAlloc(std.testing.allocator, stream);
    defer embedded.deinit(std.testing.allocator);
    try std.testing.expectEqual(checksum.crc32(input), try frameIndexCombinedChecksum(embedded.entries));
}

test "sidecar blocked best stream keeps index external" {
    const input = "abcdefghijklmnopqrstuvwxyz" ++ ("aaaaaaaaaaaaaaaa" ** 2) ++ ("abcabcabcabc" ** 2);
    const sidecar = try encodeSidecarBlockedBestStreamAlloc(std.testing.allocator, input, 16);
    defer sidecar.deinit(std.testing.allocator);
    try std.testing.expectError(error.InvalidMagic, parseEmbeddedIndexAlloc(std.testing.allocator, sidecar.stream));
    const range = try decodeSidecarIndexedRangeAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, 10, 32);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[10..42], range);
}

test "blocked best stream can embed long-distance summary metadata" {
    const prefix = "abcd" ** 9000;
    const input = prefix ++ "----" ++ prefix[0..64].*;
    const stream = try encodeBlockedBestStreamWithLdmSummaryAlloc(std.testing.allocator, input, 8192, .{}, .{ .min_distance = 32769, .min_length = 16 });
    defer std.testing.allocator.free(stream);
    const summary = try parseEmbeddedLdmSummary(stream);
    try std.testing.expect(summary.candidates > 0);
    try std.testing.expect(summary.longest >= 16);
    try std.testing.expect(summary.max_distance >= 32769);
    const range = try decodeIndexedRangeAlloc(std.testing.allocator, stream, 5, 12);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[5..17], range);
}

test "blocked best stream can select long-distance frames" {
    const prefix = deterministicLdmPrefix();
    const input = prefix ++ "----" ++ prefix[0..1024].*;
    const stream = try encodeBlockedBestStreamWithLdmAlloc(std.testing.allocator, input, input.len, .{}, .{ .min_distance = 32769, .min_length = 16 });
    defer std.testing.allocator.free(stream);
    const summary = try summarizeModes(stream);
    try std.testing.expect(summary.ldm > 0);
    const range = try decodeIndexedRangeAlloc(std.testing.allocator, stream, prefix.len + 4, 32);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, prefix[0..32], range);
}

test "sidecar blocked LDM stream keeps index external" {
    const prefix = deterministicLdmPrefix();
    const input = prefix ++ "----" ++ prefix[0..1024].*;
    const sidecar = try encodeSidecarBlockedBestStreamWithLdmAlloc(std.testing.allocator, input, input.len, .{}, .{ .min_distance = 32769, .min_length = 16 });
    defer sidecar.deinit(std.testing.allocator);
    const summary = try summarizeModes(sidecar.stream);
    try std.testing.expect(summary.ldm > 0);
    const range = try decodeSidecarIndexedRangeAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, prefix.len + 4, 32);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, prefix[0..32], range);
}

test "planned deflate stream is deterministic across worker counts" {
    const input = "abcdefghijklmnopqrstuvwxyz";
    const one = try encodePlannedDeflateStreamAlloc(std.testing.allocator, input, 7, 1);
    defer std.testing.allocator.free(one);
    const three = try encodePlannedDeflateStreamAlloc(std.testing.allocator, input, 7, 3);
    defer std.testing.allocator.free(three);
    try std.testing.expectEqualSlices(u8, one, three);
    const range = try decodeIndexedRangeAlloc(std.testing.allocator, three, 5, 12);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, "fghijklmnopq", range);
}

test "parallel deflate stream matches planned deterministic output" {
    const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
    const planned = try encodePlannedDeflateStreamAlloc(std.testing.allocator, input, 13, 3);
    defer std.testing.allocator.free(planned);
    const parallel = try encodeParallelDeflateStreamAlloc(std.testing.allocator, input, 13, 3);
    defer std.testing.allocator.free(parallel);
    try std.testing.expectEqualSlices(u8, planned, parallel);
    const range = try decodeIndexedRangeAlloc(std.testing.allocator, parallel, 10, 20);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[10..30], range);
}

test "thread-pool deflate stream matches planned deterministic output" {
    const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
    const planned = try encodePlannedDeflateStreamAlloc(std.testing.allocator, input, 13, 3);
    defer std.testing.allocator.free(planned);
    const pooled = try encodeThreadPoolDeflateStreamAlloc(std.testing.allocator, input, 13, 3);
    defer std.testing.allocator.free(pooled);
    try std.testing.expectEqualSlices(u8, planned, pooled);
}

test "parallel stream encoders reject zero worker count" {
    const input = "abcdefghijklmnopqrstuvwxyz";
    try std.testing.expectError(error.InvalidBlockPlan, encodePlannedDeflateStreamAlloc(std.testing.allocator, input, 13, 0));
    try std.testing.expectError(error.InvalidBlockPlan, encodeParallelDeflateStreamAlloc(std.testing.allocator, input, 13, 0));
    try std.testing.expectError(error.InvalidBlockPlan, encodeThreadPoolDeflateStreamAlloc(std.testing.allocator, input, 13, 0));
    try std.testing.expectError(error.InvalidBlockPlan, encodeWorkStealingDeflateStreamAlloc(std.testing.allocator, input, 13, 0));
}

test "work-stealing deflate stream supports worker-count sweep" {
    const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
    const one = try encodeWorkStealingDeflateStreamAlloc(std.testing.allocator, input, 13, 1);
    defer std.testing.allocator.free(one);
    const four = try encodeWorkStealingDeflateStreamAlloc(std.testing.allocator, input, 13, 4);
    defer std.testing.allocator.free(four);
    try std.testing.expectEqualSlices(u8, one, four);
}

test "native RLE frame round trips repeated payloads" {
    const input = "aaaaabbbbbbbbbbbbbcccccccccccccccc";
    const frame = try encodeRleAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_rle, info.flags);
    try std.testing.expect(info.stored_size < info.uncompressed_size);
    const decoded = try decodeAnyAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "native RLE frame decodes into caller buffer without allocation" {
    const input = "aaaaabbbbbbbbbbbbbcccccccccccccccc";
    const frame = try encodeRleAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_rle, info.flags);

    var out: [input.len]u8 = undefined;
    const written = try decodeRleInto(frame, &out);
    try std.testing.expectEqual(out.len, written);
    try std.testing.expectEqualSlices(u8, input, &out);

    var short: [input.len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeRleInto(frame, &short));
}

test "RLE frame range decodes into caller buffer without allocation" {
    const input = "aaaaabbbbbbbbbbbbbcccccccccccccccc";
    const frame = try encodeRleAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_rle, info.flags);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);

    var full: [input.len]u8 = undefined;
    const full_result = try decodeRangeInto(std.testing.failing_allocator, frame, index, 0, full.len, full[0..]);
    try std.testing.expectEqual(full.len, full_result.output_written);
    try std.testing.expectEqualSlices(u8, input, &full);
    try std.testing.expectEqual(checksum.crc32(input), full_result.crc32);

    var partial: [20]u8 = undefined;
    const partial_result = try decodeRangeInto(std.testing.failing_allocator, frame, index, 3, partial.len, partial[0..]);
    try std.testing.expectEqual(partial.len, partial_result.output_written);
    try std.testing.expectEqualSlices(u8, input[3..23], &partial);
    try std.testing.expectEqual(checksum.crc32(input[3..23]), partial_result.crc32);
}

test "native long-distance frame round trips beyond-window repetitions" {
    const prefix = deterministicLdmPrefix();
    const input = prefix ++ "----" ++ prefix[0..64].*;
    const frame = try encodeLongDistanceAlloc(std.testing.allocator, input, .{ .min_distance = 32769, .min_length = 16 });
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_ldm, info.flags);
    try std.testing.expect(info.stored_size < info.uncompressed_size);
    const decoded = try decodeAnyAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "native long-distance frame decodes into caller buffer without allocation" {
    const prefix = deterministicLdmPrefix();
    const input = prefix ++ "----" ++ prefix[0..64].*;
    const frame = try encodeLongDistanceAlloc(std.testing.allocator, input, .{ .min_distance = 32769, .min_length = 16 });
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_ldm, info.flags);

    var out: [input.len]u8 = undefined;
    const written = try decodeLongDistanceInto(frame, &out);
    try std.testing.expectEqual(out.len, written);
    try std.testing.expectEqualSlices(u8, input, &out);

    var short: [input.len - 1]u8 = undefined;
    try std.testing.expectError(error.OutputTooSmall, decodeLongDistanceInto(frame, &short));
}

test "full long-distance frame range decodes into caller buffer without allocation" {
    const prefix = deterministicLdmPrefix();
    const input = prefix ++ "----" ++ prefix[0..64].*;
    const frame = try encodeLongDistanceAlloc(std.testing.allocator, input, .{ .min_distance = 32769, .min_length = 16 });
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_ldm, info.flags);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);

    var out: [input.len]u8 = undefined;
    const result = try decodeRangeInto(std.testing.failing_allocator, frame, index, 0, out.len, out[0..]);
    try std.testing.expectEqual(out.len, result.output_written);
    try std.testing.expectEqual(@as(u64, 0), result.offset);
    try std.testing.expectEqualSlices(u8, input, &out);
    try std.testing.expectEqual(checksum.crc32(input), result.crc32);
}

test "native best frame selects RLE for repeated data" {
    const input = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    const frame = try encodeBestAlloc(std.testing.allocator, input);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_rle, info.flags);
    const decoded = try decodeAnyAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "native best frame can select LDM for long-distance repetitions" {
    const prefix = deterministicLdmPrefix();
    const input = prefix ++ "----" ++ prefix[0..1024].*;
    const frame = try encodeBestWithLongDistanceAlloc(std.testing.allocator, input, .{ .min_distance = 32769, .min_length = 16 });
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_ldm, info.flags);
    const decoded = try decodeAnyAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

fn deterministicLdmPrefix() [33_000]u8 {
    var out: [33_000]u8 = undefined;
    var x: u32 = 0x1234_5678;
    for (&out) |*byte| {
        x = x *% 1664525 +% 1013904223;
        byte.* = @truncate(x >> 24);
    }
    return out;
}

test "native dictionary patch frame decodes with caller dictionary" {
    const dict = "alpha beta gamma";
    const input = "zz alpha beta yy gamma";
    const frame = try encodeDictionaryPatchAlloc(std.testing.allocator, dict, input, 5);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_dictionary_patch, info.flags);
    const decoded = try decodeDictionaryPatchAlloc(std.testing.allocator, dict, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    try std.testing.expectError(error.InvalidDictionaryTraining, decodeAnyAlloc(std.testing.allocator, frame));
}

test "native dictionary patch frame decodes into caller buffer without allocation" {
    const dict = "alpha beta gamma";
    const input = "zz alpha beta yy gamma";
    const frame = try encodeDictionaryPatchAlloc(std.testing.allocator, dict, input, 5);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_dictionary_patch, info.flags);

    var out: [input.len]u8 = undefined;
    const written = try decodeDictionaryPatchInto(std.testing.failing_allocator, dict, frame, &out);
    try std.testing.expectEqual(out.len, written);
    try std.testing.expectEqualSlices(u8, input, &out);
}

test "native dictionary patch alloc exact-size and limited variants bound output" {
    const dict = "alpha beta gamma";
    const input = "zz alpha beta yy gamma";
    const frame = try encodeDictionaryPatchAlloc(std.testing.allocator, dict, input, 5);
    defer std.testing.allocator.free(frame);

    const exact = try decodeDictionaryPatchAllocExactSize(std.testing.allocator, dict, frame, input.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, input, exact);

    const limited = try decodeDictionaryPatchAllocLimited(std.testing.allocator, dict, frame, input.len);
    defer std.testing.allocator.free(limited);
    try std.testing.expectEqualSlices(u8, input, limited);

    try std.testing.expectError(error.SizeMismatch, decodeDictionaryPatchAllocExactSize(std.testing.allocator, dict, frame, input.len - 1));
    try std.testing.expectError(error.OutputLimitExceeded, decodeDictionaryPatchAllocLimited(std.testing.allocator, dict, frame, input.len - 1));
}

test "full dictionary patch frame range decodes into caller buffer without allocation" {
    const dict = "alpha beta gamma";
    const input = "zz alpha beta yy gamma";
    const frame = try encodeDictionaryPatchAlloc(std.testing.allocator, dict, input, 5);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_dictionary_patch, info.flags);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);

    var out: [input.len]u8 = undefined;
    const result = try decodeRangeWithDictionaryInto(std.testing.failing_allocator, dict, frame, index, 0, out.len, out[0..]);
    try std.testing.expectEqual(out.len, result.output_written);
    try std.testing.expectEqual(@as(u64, 0), result.offset);
    try std.testing.expectEqualSlices(u8, input, &out);
    try std.testing.expectEqual(checksum.crc32(input), result.crc32);
}

test "native dictionary deflate frame decodes with caller dictionary" {
    const dict = "alpha beta gamma";
    const input = "zz alpha beta yy gamma";
    const frame = try encodeDictionaryDeflateAlloc(std.testing.allocator, dict, input, 5);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_dictionary_deflate, info.flags);
    const decoded = try decodeDictionaryPatchAlloc(std.testing.allocator, dict, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}

test "native dictionary deflate frame decodes into caller buffer" {
    const dict = "alpha beta gamma";
    const input = "zz alpha beta yy gamma";
    const frame = try encodeDictionaryDeflateAlloc(std.testing.allocator, dict, input, 5);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_dictionary_deflate, info.flags);

    var out: [input.len]u8 = undefined;
    const written = try decodeDictionaryPatchInto(std.testing.allocator, dict, frame, &out);
    try std.testing.expectEqual(out.len, written);
    try std.testing.expectEqualSlices(u8, input, &out);

    const exact = try decodeDictionaryPatchAllocExactSize(std.testing.allocator, dict, frame, input.len);
    defer std.testing.allocator.free(exact);
    try std.testing.expectEqualSlices(u8, input, exact);

    try std.testing.expectError(error.OutputLimitExceeded, decodeDictionaryPatchAllocLimited(std.testing.allocator, dict, frame, input.len - 1));
}

test "native dictionary deflate patch inflate is bounded by decoded size" {
    const patch = try dictionary.encodePatchAlloc(std.testing.allocator, "", "", 1);
    defer std.testing.allocator.free(patch);
    var oversized_patch = std.ArrayList(u8).empty;
    defer oversized_patch.deinit(std.testing.allocator);
    try oversized_patch.appendSlice(std.testing.allocator, patch);
    try oversized_patch.append(std.testing.allocator, 0);
    try appendIntLE(u16, std.testing.allocator, &oversized_patch, 0);

    const compressed = try deflate.encodeRawStoredAlloc(std.testing.allocator, oversized_patch.items);
    defer std.testing.allocator.free(compressed);
    const frame = try std.testing.allocator.alloc(u8, try encodedSize(compressed.len));
    defer std.testing.allocator.free(frame);
    writeHeader(frame[0..header_len], .{
        .version = current_version,
        .flags = flags_dictionary_deflate,
        .uncompressed_size = 0,
        .stored_size = @intCast(compressed.len),
        .checksum = checksum.crc32(""),
    });
    @memcpy(frame[header_len..], compressed);

    var out: [0]u8 = .{};
    try std.testing.expectError(error.OutputLimitExceeded, decodeDictionaryPatchInto(std.testing.allocator, "", frame, &out));
}

test "full dictionary deflate frame range decodes into caller buffer" {
    const dict = "alpha beta gamma";
    const input = "zz alpha beta yy gamma";
    const frame = try encodeDictionaryDeflateAlloc(std.testing.allocator, dict, input, 5);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_dictionary_deflate, info.flags);
    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);

    var out: [input.len]u8 = undefined;
    const result = try decodeRangeWithDictionaryInto(std.testing.allocator, dict, frame, index, 0, out.len, out[0..]);
    try std.testing.expectEqual(out.len, result.output_written);
    try std.testing.expectEqual(@as(u64, 0), result.offset);
    try std.testing.expectEqualSlices(u8, input, &out);
    try std.testing.expectEqual(checksum.crc32(input), result.crc32);
}

test "dictionary deflate indexed stream supports batch range summaries" {
    const dict = "alpha beta gamma dictionary deflate phrase";
    const input = (dict ++ " -- payload ") ** 3;
    const frame = try encodeDictionaryDeflateAlloc(std.testing.allocator, dict, input, 8);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expectEqual(flags_dictionary_deflate, info.flags);

    const index = try buildFrameIndexAlloc(std.testing.allocator, frame);
    defer std.testing.allocator.free(index);
    const index_bytes = try encodeFrameIndexAlloc(std.testing.allocator, index);
    defer std.testing.allocator.free(index_bytes);
    const index_frame = try encodeSkippableAlloc(std.testing.allocator, index_bytes);
    defer std.testing.allocator.free(index_frame);
    var stream = std.ArrayList(u8).empty;
    defer stream.deinit(std.testing.allocator);
    try stream.appendSlice(std.testing.allocator, frame);
    try stream.appendSlice(std.testing.allocator, index_frame);

    const batch = try decodeIndexedRangesWithDictionarySummaryAlloc(std.testing.allocator, dict, stream.items, &.{
        .{ .offset = 0, .length = 16 },
        .{ .offset = 9, .length = 32 },
    });
    defer batch.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, input[0..16], batch.ranges[0].bytes);
    try std.testing.expectEqual(checksum.crc32(input[0..16]), batch.ranges[0].crc32);
    try std.testing.expectEqualSlices(u8, input[9..41], batch.ranges[1].bytes);
    try std.testing.expectEqual(checksum.crc32(input[9..41]), batch.ranges[1].crc32);

    var first: [16]u8 = undefined;
    var second: [32]u8 = undefined;
    var results: [2]RangeDecodeIntoResult = undefined;
    try decodeIndexedRangesWithDictionaryInto(std.testing.allocator, dict, stream.items, &.{
        .{ .offset = 0, .length = first.len, .output = first[0..] },
        .{ .offset = 9, .length = second.len, .output = second[0..] },
    }, results[0..]);
    try std.testing.expectEqualSlices(u8, input[0..16], &first);
    try std.testing.expectEqual(checksum.crc32(&first), results[0].crc32);
    try std.testing.expectEqualSlices(u8, input[9..41], &second);
    try std.testing.expectEqual(checksum.crc32(&second), results[1].crc32);
    try std.testing.expectError(error.InvalidDictionaryTraining, decodeIndexedRangesWithSummaryAlloc(std.testing.allocator, stream.items, &.{
        .{ .offset = 0, .length = 16 },
        .{ .offset = 9, .length = 32 },
    }));
    @memset(first[0..], '!');
    @memset(second[0..], '!');
    try std.testing.expectError(error.InvalidDictionaryTraining, decodeIndexedRangesInto(std.testing.allocator, stream.items, &.{
        .{ .offset = 0, .length = first.len, .output = first[0..] },
        .{ .offset = 9, .length = second.len, .output = second[0..] },
    }, results[0..]));
    try std.testing.expectEqualSlices(u8, "!!!!!!!!!!!!!!!!", &first);
    try std.testing.expectEqualSlices(u8, "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!", &second);
}

test "native dictionary best encoder chooses patch only when smaller" {
    const dict = "dictionary-only phrase with enough length to beat stored framing";
    const input = dict ++ "!";
    const frame = try encodeBestWithDictionaryAlloc(std.testing.allocator, dict, input, 8);
    defer std.testing.allocator.free(frame);
    const info = try parseHeader(frame);
    try std.testing.expect(info.flags == flags_dictionary_patch or info.flags == flags_dictionary_deflate);
    const decoded = try decodeDictionaryPatchAlloc(std.testing.allocator, dict, frame);
    defer std.testing.allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);

    const fallback = try encodeBestWithDictionaryAlloc(std.testing.allocator, dict, "no useful match", 8);
    defer std.testing.allocator.free(fallback);
    const fallback_info = try parseHeader(fallback);
    try std.testing.expect(fallback_info.flags != flags_dictionary_patch);
    try std.testing.expect(fallback_info.flags != flags_dictionary_deflate);
}

test "blocked dictionary best stream supports dictionary range decode" {
    const dict = "dictionary-only phrase with enough length to beat stored framing";
    const input = (dict ++ "!") ** 3;
    const stream = try encodeBlockedBestWithDictionaryStreamAlloc(std.testing.allocator, dict, input, dict.len + 1, 8);
    defer std.testing.allocator.free(stream);
    const summary = try summarizeModes(stream);
    try std.testing.expect(summary.dictionary_patch + summary.dictionary_deflate > 0);
    const range = try decodeIndexedRangeWithDictionaryAlloc(std.testing.allocator, dict, stream, 5, 40);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[5..45], range);
    const summary_range = try decodeIndexedRangeWithDictionarySummaryAlloc(std.testing.allocator, dict, stream, 5, 40);
    defer summary_range.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, input[5..45], summary_range.bytes);
    try std.testing.expectEqual(checksum.crc32(input[5..45]), summary_range.crc32);
    const batch = try decodeIndexedRangesWithDictionarySummaryAlloc(std.testing.allocator, dict, stream, &.{
        .{ .offset = 0, .length = 8 },
        .{ .offset = 5, .length = 40 },
    });
    defer batch.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, input[0..8], batch.ranges[0].bytes);
    try std.testing.expectEqual(checksum.crc32(input[0..8]), batch.ranges[0].crc32);
    try std.testing.expectEqualSlices(u8, input[5..45], batch.ranges[1].bytes);
    try std.testing.expectEqual(checksum.crc32(input[5..45]), batch.ranges[1].crc32);
    var buffer: [40]u8 = undefined;
    const into = try decodeIndexedRangeWithDictionaryInto(std.testing.allocator, dict, stream, 5, buffer.len, buffer[0..]);
    try std.testing.expectEqual(buffer.len, into.output_written);
    try std.testing.expectEqualSlices(u8, input[5..45], &buffer);
    try std.testing.expectEqual(checksum.crc32(input[5..45]), into.crc32);
    try std.testing.expectError(error.InvalidDictionaryTraining, decodeIndexedRangeAlloc(std.testing.allocator, stream, 5, 40));
}

test "self-contained dictionary stream embeds dictionary and supports range decode" {
    const phrase = "self-contained dictionary phrase for native streams";
    const input = (phrase ++ "!") ** 4;
    const stream = try encodeSelfContainedDictionaryStreamAlloc(std.testing.allocator, input, phrase.len + 1, 256, 8);
    defer std.testing.allocator.free(stream);
    const dict = try parseEmbeddedDictionaryAlloc(std.testing.allocator, stream);
    defer std.testing.allocator.free(dict);
    try std.testing.expect(dict.len > 0);
    const summary = try summarizeModes(stream);
    try std.testing.expect(summary.dictionary_patch + summary.dictionary_deflate > 0);
    const range = try decodeSelfContainedDictionaryRangeAlloc(std.testing.allocator, stream, 7, 64);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[7..71], range);
    const summary_range = try decodeSelfContainedDictionaryRangeWithSummaryAlloc(std.testing.allocator, stream, 7, 64);
    defer summary_range.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, input[7..71], summary_range.bytes);
    try std.testing.expectEqual(checksum.crc32(input[7..71]), summary_range.crc32);
    var buffer: [64]u8 = undefined;
    const into = try decodeSelfContainedDictionaryRangeInto(std.testing.allocator, stream, 7, buffer.len, buffer[0..]);
    try std.testing.expectEqual(buffer.len, into.output_written);
    try std.testing.expectEqualSlices(u8, input[7..71], &buffer);
    try std.testing.expectEqual(checksum.crc32(input[7..71]), into.crc32);
}

test "sidecar self-contained dictionary stream keeps index external" {
    const phrase = "self-contained dictionary phrase for native streams";
    const input = (phrase ++ "!") ** 4;
    const sidecar = try encodeSidecarSelfContainedDictionaryStreamAlloc(std.testing.allocator, input, phrase.len + 1, 256, 8);
    defer sidecar.deinit(std.testing.allocator);
    const range = try decodeSidecarIndexedRangeAutoAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, 7, 64);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[7..71], range);
    const summary_range = try decodeSidecarIndexedRangeAutoWithSummaryAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, 7, 64);
    defer summary_range.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, input[7..71], summary_range.bytes);
    try std.testing.expectEqual(checksum.crc32(input[7..71]), summary_range.crc32);
    const batch = try decodeSidecarIndexedRangesAutoWithSummaryAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, &.{
        .{ .offset = 0, .length = 8 },
        .{ .offset = 7, .length = 64 },
    });
    defer batch.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(u8, input[0..8], batch.ranges[0].bytes);
    try std.testing.expectEqual(checksum.crc32(input[0..8]), batch.ranges[0].crc32);
    try std.testing.expectEqualSlices(u8, input[7..71], batch.ranges[1].bytes);
    try std.testing.expectEqual(checksum.crc32(input[7..71]), batch.ranges[1].crc32);
    var buffer: [64]u8 = undefined;
    const into = try decodeSidecarIndexedRangeAutoInto(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, 7, buffer.len, buffer[0..]);
    try std.testing.expectEqual(buffer.len, into.output_written);
    try std.testing.expectEqualSlices(u8, input[7..71], &buffer);
    try std.testing.expectEqual(checksum.crc32(input[7..71]), into.crc32);
    var batch_a: [8]u8 = undefined;
    var batch_b: [64]u8 = undefined;
    var batch_results: [2]RangeDecodeIntoResult = undefined;
    try decodeSidecarIndexedRangesAutoInto(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, &.{
        .{ .offset = 0, .length = batch_a.len, .output = batch_a[0..] },
        .{ .offset = 7, .length = batch_b.len, .output = batch_b[0..] },
    }, batch_results[0..]);
    try std.testing.expectEqualSlices(u8, input[0..8], &batch_a);
    try std.testing.expectEqual(checksum.crc32(input[0..8]), batch_results[0].crc32);
    try std.testing.expectEqualSlices(u8, input[7..71], &batch_b);
    try std.testing.expectEqual(checksum.crc32(input[7..71]), batch_results[1].crc32);
}

test "trained dictionary best stream falls back safely and auto range decodes" {
    const phrase = "self-contained dictionary phrase for native streams";
    const input = (phrase ++ "!") ** 4;
    const stream = try encodeBestTrainedDictionaryStreamAlloc(std.testing.allocator, input, phrase.len + 1, 256, 8);
    defer std.testing.allocator.free(stream);
    const range = try decodeIndexedRangeAutoAlloc(std.testing.allocator, stream, 7, 64);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[7..71], range);

    const plain = try encodeBestTrainedDictionaryStreamAlloc(std.testing.allocator, "plain text without trained benefits", 8, 256, 8);
    defer std.testing.allocator.free(plain);
    const plain_range = try decodeIndexedRangeAutoAlloc(std.testing.allocator, plain, 0, 10);
    defer std.testing.allocator.free(plain_range);
    try std.testing.expectEqualSlices(u8, "plain text", plain_range);
}

test "seekable native stream integrates native modes trained dictionary and LDM" {
    const phrase = "production dictionary phrase for seekable native streams";
    const dict_input = (phrase ++ "!") ** 4;
    const dict_stream = try encodeSeekableNativeStreamAlloc(std.testing.allocator, dict_input, .{
        .block_len = phrase.len + 1,
        .dictionary = .{ .enable = true, .target_size = 256, .min_match_len = 8 },
    });
    defer std.testing.allocator.free(dict_stream);
    const dict_modes = try summarizeModes(dict_stream);
    try std.testing.expect(dict_modes.dictionary_patch + dict_modes.dictionary_deflate > 0);
    const dict_range = try decodeIndexedRangeAutoAlloc(std.testing.allocator, dict_stream, 7, 64);
    defer std.testing.allocator.free(dict_range);
    try std.testing.expectEqualSlices(u8, dict_input[7..71], dict_range);

    const mixed_input = "abcdefghijklmnopqrstuvwxyz" ++ ("aaaaaaaaaaaaaaaa" ** 2) ++ ("abcabcabcabc" ** 2);
    const mixed_stream = try encodeSeekableNativeStreamAlloc(std.testing.allocator, mixed_input, .{ .block_len = 16 });
    defer std.testing.allocator.free(mixed_stream);
    const mixed_modes = try summarizeModes(mixed_stream);
    try std.testing.expect(mixed_modes.store + mixed_modes.deflate + mixed_modes.rle >= 2);
    const mixed_range = try decodeIndexedRangeAutoAlloc(std.testing.allocator, mixed_stream, 10, 32);
    defer std.testing.allocator.free(mixed_range);
    try std.testing.expectEqualSlices(u8, mixed_input[10..42], mixed_range);

    const prefix = deterministicLdmPrefix();
    const ldm_input = prefix ++ "----" ++ prefix[0..1024].*;
    const ldm_stream = try encodeSeekableNativeStreamAlloc(std.testing.allocator, ldm_input, .{
        .block_len = ldm_input.len,
        .long_distance = .{ .enable = true, .options = .{ .min_distance = 32769, .min_length = 16 }, .align_blocks = false },
    });
    defer std.testing.allocator.free(ldm_stream);
    const ldm_modes = try summarizeModes(ldm_stream);
    try std.testing.expect(ldm_modes.ldm > 0);
    const ldm_summary = try parseEmbeddedLdmSummary(ldm_stream);
    try std.testing.expect(ldm_summary.candidates > 0);
    const ldm_range = try decodeIndexedRangeAutoAlloc(std.testing.allocator, ldm_stream, prefix.len + 4, 32);
    defer std.testing.allocator.free(ldm_range);
    try std.testing.expectEqualSlices(u8, prefix[0..32], ldm_range);
}

test "seekable native sidecar stream supports auto range decode" {
    const phrase = "sidecar trained dictionary phrase";
    const input = (phrase ++ "!") ** 4;
    const sidecar = try encodeSeekableNativeSidecarStreamAlloc(std.testing.allocator, input, .{
        .block_len = phrase.len + 1,
        .dictionary = .{ .enable = true, .target_size = 128, .min_match_len = 8 },
    });
    defer sidecar.deinit(std.testing.allocator);
    try validateSidecarIndexAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index);
    const range = try decodeSidecarIndexedRangeAutoAlloc(std.testing.allocator, sidecar.stream, sidecar.sidecar_index, 7, 48);
    defer std.testing.allocator.free(range);
    try std.testing.expectEqualSlices(u8, input[7..55], range);
}

test "work-stealing deflate stream matches planned deterministic output" {
    const input = "abcdefghijklmnopqrstuvwxyz" ** 4;
    const planned = try encodePlannedDeflateStreamAlloc(std.testing.allocator, input, 13, 3);
    defer std.testing.allocator.free(planned);
    const stolen = try encodeWorkStealingDeflateStreamAlloc(std.testing.allocator, input, 13, 3);
    defer std.testing.allocator.free(stolen);
    try std.testing.expectEqualSlices(u8, planned, stolen);
}

test "mode summary counts native best frames" {
    const payloads = [_][]const u8{ "plain", "aaaaaaaaaaaaaaaa", "abcabcabcabc" };
    const stream = try encodeIndexedDeflateStreamAlloc(std.testing.allocator, &payloads);
    defer std.testing.allocator.free(stream);
    const summary = try summarizeModes(stream);
    try std.testing.expectEqual(@as(usize, 3), summary.store + summary.deflate + summary.rle);
    try std.testing.expect(summary.rle >= 1);
}
