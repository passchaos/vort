//! Shared LZMA2 chunk framing and committed model state for one-shot and
//! incremental writers. Match planning remains in the LZMA encoder.
const std = @import("std");
const core = @import("../../core.zig");
const settings = @import("../../lzma/encode_options.zig");
const encoder = @import("../../lzma/encoder.zig");

pub const max_stored_chunk_len: usize = 65536;
pub const max_compressed_payload_len: usize = 65536;
pub const max_compressed_plain_len: usize = settings.max_lzma2_chunk_plain;
/// Compatibility constant for the original stored-chunk bound.
pub const max_chunk_len: usize = max_stored_chunk_len;
pub const ValidationError = core.Error || encoder.Error;
pub const Error = ValidationError || std.mem.Allocator.Error;
pub const Parser = settings.Mode;
pub const Properties = settings.Properties;
pub const MatchOptions = settings.MatchOptions;

pub const Options = struct {
    dictionary_size: usize = 4096,
    chunk_size: usize = max_stored_chunk_len,
    parser: Parser = .greedy,
    properties: Properties = .{},
    match_options: ?MatchOptions = null,

    pub fn fromPreset(level: u32, extreme: bool) ValidationError!Options {
        const preset = try settings.resolvePreset(level, extreme);
        return .{ .dictionary_size = preset.dictionary_size, .parser = preset.mode, .properties = preset.properties, .match_options = preset.match_options };
    }
    pub fn validate(self: Options) ValidationError!void {
        if (self.chunk_size == 0 or self.chunk_size > max_compressed_plain_len) return error.InvalidBlockPlan;
        if (self.dictionary_size < 4096 or self.dictionary_size > settings.max_dictionary_size) return error.InvalidBlockPlan;
        _ = try encoder.propertyByte(self.properties);
        if (self.match_options) |options| try options.validate();
    }
    pub fn recordEffectiveSettings(self: Options) void {
        if (self.match_options) |options| options.recordEffectiveSettings();
    }
    pub fn advanced(self: Options) bool {
        return self.match_options != null or !std.meta.eql(self.properties, Properties{}) or
            (self.parser != .greedy and self.parser != .lazy);
    }
    pub fn coreOptions(self: Options) encoder.EncodeOptions {
        return .{
            .dictionary_size = self.dictionary_size,
            .properties = self.properties,
            .mode = self.parser,
            .match_options = if (self.match_options) |options| options else if (!std.meta.eql(self.properties, Properties{}) and (self.parser == .greedy or self.parser == .lazy)) MatchOptions{} else null,
        };
    }
};

pub const State = struct {
    model: encoder.Model,
    model_valid: bool = false,
    properties_initialized: bool = false,

    pub fn init(options: Options) ValidationError!State {
        try options.validate();
        options.recordEffectiveSettings();
        return .{ .model = try encoder.initModel(options.coreOptions()) };
    }
    pub fn reset(self: *State, options: Options) ValidationError!void {
        self.* = try init(options);
    }
    /// Append one complete packet. Candidate model changes become visible only
    /// after packet capacity is reserved and all output bytes are committed.
    pub fn append(self: *State, allocator: std.mem.Allocator, output: *std.ArrayList(u8), candidate: *std.ArrayList(u8), input: []const u8, history: []const u8, stream_position: usize, options: Options, legacy_plan: ?encoder.WideStreamPlan) Error!usize {
        try options.validate();
        if (input.len == 0 or input.len > options.chunk_size) return error.InvalidBlockPlan;
        if (history.len > stream_position) return error.InvalidLzmaOptions;
        const stored_size = try storedGroupSize(input.len);
        _ = std.math.add(usize, output.items.len, stored_size) catch return error.IntegerOverflow;
        const property_byte = try encoder.propertyByte(options.properties);
        const lzma_options = options.coreOptions();
        var working_model = if (self.model_valid) self.model else try encoder.initModel(lzma_options);
        const reset_kind: u2 = if (stream_position == 0) 3 else if (!self.properties_initialized) 2 else if (!self.model_valid) 1 else 0;
        candidate.clearRetainingCapacity();
        var payload_fits = true;
        _ = encoder.encodeChunkAppendWithModelLimit(allocator, candidate, input, history, stream_position, lzma_options, legacy_plan, &working_model, max_compressed_payload_len) catch |err| switch (err) {
            error.CompressedPayloadLimitExceeded => blk: {
                payload_fits = false;
                break :blk 0;
            },
            else => return err,
        };
        const property_extra: usize = if (reset_kind >= 2) 1 else 0;
        const packet_len = std.math.add(usize, 5 + property_extra, candidate.items.len) catch return error.IntegerOverflow;
        if (payload_fits and candidate.items.len != 0 and candidate.items.len <= max_compressed_payload_len and packet_len < stored_size) {
            _ = std.math.add(usize, output.items.len, packet_len) catch return error.IntegerOverflow;
            try output.ensureUnusedCapacity(allocator, packet_len);
            const plain_minus_one: u32 = @intCast(input.len - 1);
            const plain_high: u8 = @intCast(plain_minus_one >> 16);
            output.appendAssumeCapacity(0x80 | (@as(u8, reset_kind) << 5) | plain_high);
            appendU16(output, @truncate(plain_minus_one));
            appendU16(output, @intCast(candidate.items.len - 1));
            if (property_extra != 0) output.appendAssumeCapacity(property_byte);
            output.appendSliceAssumeCapacity(candidate.items);
            self.model = working_model;
            self.model_valid = true;
            self.properties_initialized = true;
            return packet_len;
        }
        const written = try appendStored(allocator, output, input, stream_position == 0);
        self.model_valid = false;
        return written;
    }
    pub fn appendUncompressed(self: *State, allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, reset_dictionary: bool) Error!usize {
        const written = try appendStored(allocator, output, input, reset_dictionary);
        self.model_valid = false;
        return written;
    }
};

/// Serialized size of a nonempty caller group without the terminal marker.
pub fn storedGroupSize(input_len: usize) ValidationError!usize {
    if (input_len == 0 or input_len > max_compressed_plain_len) return error.InvalidBlockPlan;
    const chunks = 1 + (input_len - 1) / max_stored_chunk_len;
    const overhead = std.math.mul(usize, chunks, 3) catch return error.IntegerOverflow;
    return std.math.add(usize, input_len, overhead) catch return error.IntegerOverflow;
}

/// Commit the entire stored fallback group, including every 64 KiB packet.
/// A borrowed output span is copied before reserve can relocate its owner.
pub fn appendStored(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, reset_dictionary: bool) Error!usize {
    const packet_len = try storedGroupSize(input.len);
    _ = std.math.add(usize, output.items.len, packet_len) catch return error.IntegerOverflow;
    var owned_input: ?[]u8 = null;
    defer if (owned_input) |bytes| allocator.free(bytes);
    const source = if (try inputOverlapsOutputAllocation(input, output)) blk: {
        const bytes = try allocator.dupe(u8, input);
        owned_input = bytes;
        break :blk bytes;
    } else input;
    try output.ensureUnusedCapacity(allocator, packet_len);
    var offset: usize = 0;
    while (offset < source.len) {
        const len = @min(max_stored_chunk_len, source.len - offset);
        output.appendAssumeCapacity(if (reset_dictionary and offset == 0) 1 else 2);
        appendU16(output, @intCast(len - 1));
        output.appendSliceAssumeCapacity(source[offset..][0..len]);
        offset += len;
    }
    return packet_len;
}

pub fn inputOverlapsOutputAllocation(input: []const u8, output: *const std.ArrayList(u8)) core.Error!bool {
    if (input.len == 0 or output.capacity == 0) return false;
    const input_start = @intFromPtr(input.ptr);
    const output_start = @intFromPtr(output.items.ptr);
    const input_end = std.math.add(usize, input_start, input.len) catch return error.IntegerOverflow;
    const output_end = std.math.add(usize, output_start, output.capacity) catch return error.IntegerOverflow;
    return input_start < output_end and output_start < input_end;
}

fn appendU16(output: *std.ArrayList(u8), value: u16) void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .big);
    output.appendSliceAssumeCapacity(&bytes);
}
