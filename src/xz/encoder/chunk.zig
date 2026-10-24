//! Shared LZMA2 chunk framing and committed model state for one-shot and
//! incremental writers. Match planning remains in the LZMA encoder.
const std = @import("std");
const core = @import("../../core.zig");
const settings = @import("../../lzma/encode_options.zig");
const encoder = @import("../../lzma/encoder.zig");

pub const max_chunk_len: usize = 65536;
pub const ValidationError = core.Error || encoder.Error;
pub const Error = ValidationError || std.mem.Allocator.Error;
pub const Parser = settings.Mode;
pub const Properties = settings.Properties;
pub const MatchOptions = settings.MatchOptions;

pub const Options = struct {
    dictionary_size: usize = 4096,
    parser: Parser = .greedy,
    properties: Properties = .{},
    match_options: ?MatchOptions = null,

    pub fn fromPreset(level: u32, extreme: bool) ValidationError!Options {
        const preset = try settings.resolvePreset(level, extreme);
        return .{ .dictionary_size = preset.dictionary_size, .parser = preset.mode, .properties = preset.properties, .match_options = preset.match_options };
    }
    pub fn validate(self: Options) ValidationError!void {
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
        if (input.len == 0 or input.len > max_chunk_len) return error.InvalidBlockPlan;
        if (history.len > stream_position) return error.InvalidLzmaOptions;
        const lzma_options = options.coreOptions();
        var working_model = if (self.model_valid) self.model else try encoder.initModel(lzma_options);
        const reset_kind: u2 = if (stream_position == 0) 3 else if (!self.properties_initialized) 2 else if (!self.model_valid) 1 else 0;
        candidate.clearRetainingCapacity();
        _ = try encoder.encodeChunkAppendWithModel(allocator, candidate, input, history, stream_position, lzma_options, legacy_plan, &working_model);
        const property_extra: usize = if (reset_kind >= 2) 1 else 0;
        const header_delta = 2 + property_extra;
        if (candidate.items.len <= max_chunk_len and candidate.items.len + header_delta < input.len) {
            const packet_len = 5 + property_extra + candidate.items.len;
            try output.ensureUnusedCapacity(allocator, packet_len);
            output.appendAssumeCapacity(0x80 | (@as(u8, reset_kind) << 5));
            appendU16(output, @intCast(input.len - 1));
            appendU16(output, @intCast(candidate.items.len - 1));
            if (property_extra != 0) output.appendAssumeCapacity(try encoder.propertyByte(options.properties));
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

pub fn appendStored(allocator: std.mem.Allocator, output: *std.ArrayList(u8), input: []const u8, reset_dictionary: bool) Error!usize {
    if (input.len == 0 or input.len > max_chunk_len) return error.InvalidBlockPlan;
    const packet_len = 3 + input.len;
    try output.ensureUnusedCapacity(allocator, packet_len);
    output.appendAssumeCapacity(if (reset_dictionary) 1 else 2);
    appendU16(output, @intCast(input.len - 1));
    output.appendSliceAssumeCapacity(input);
    return packet_len;
}
fn appendU16(output: *std.ArrayList(u8), value: u16) void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .big);
    output.appendSliceAssumeCapacity(&bytes);
}
