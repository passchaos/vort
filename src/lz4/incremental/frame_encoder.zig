const std = @import("std");
const core = @import("../../core.zig");

/// Build a no-content-size incremental LZ4 frame encoder. At most one frame
/// block plus the 64 KiB linked-history window are retained. Encoded blocks and
/// footer bytes drain through arbitrary caller output.
pub fn Encoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Codec.Options,
        block_encoder: Codec.EncoderState,
        block: std.ArrayList(u8) = .empty,
        history: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        hasher: std.hash.XxHash32 = std.hash.XxHash32.init(0),
        header_written: bool = false,
        finishing: bool = false,
        footer_written: bool = false,
        done: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        expected_input_len: ?usize = null,
        dictionary_id: ?u32 = null,
        dictionary: []const u8 = &.{},

        const Self = @This();
        pub const Error = Codec.Error;

        pub fn init(allocator: std.mem.Allocator, options: Codec.Options) Error!Self {
            try Codec.validate(options, null, null);
            return .{ .allocator = allocator, .options = options, .block_encoder = try Codec.EncoderState.init(allocator) };
        }
        pub fn initExactSize(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: usize) Error!Self {
            try Codec.validate(options, expected_input_len, null);
            return .{ .allocator = allocator, .options = options, .block_encoder = try Codec.EncoderState.init(allocator), .expected_input_len = expected_input_len };
        }
        pub fn initWithDictionary(allocator: std.mem.Allocator, options: Codec.Options, dictionary_id: u32, dictionary: []const u8) Error!Self {
            if (dictionary_id == 0) return error.NeedDictionary;
            try Codec.validate(options, null, dictionary_id);
            return .{ .allocator = allocator, .options = options, .block_encoder = try Codec.EncoderState.init(allocator), .dictionary_id = dictionary_id, .dictionary = dictionary };
        }
        pub fn initExactSizeWithDictionary(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: usize, dictionary_id: u32, dictionary: []const u8) Error!Self {
            if (dictionary_id == 0) return error.NeedDictionary;
            try Codec.validate(options, expected_input_len, dictionary_id);
            return .{ .allocator = allocator, .options = options, .block_encoder = try Codec.EncoderState.init(allocator), .expected_input_len = expected_input_len, .dictionary_id = dictionary_id, .dictionary = dictionary };
        }
        pub fn initWithDictionarySet(allocator: std.mem.Allocator, options: Codec.Options, dictionary_set: anytype, dictionary_id: u32) Error!Self {
            const dictionary = dictionary_set.find(dictionary_id) orelse return error.NeedDictionary;
            return initWithDictionary(allocator, options, dictionary.id, dictionary.content);
        }
        pub fn initExactSizeWithDictionarySet(allocator: std.mem.Allocator, options: Codec.Options, expected_input_len: usize, dictionary_set: anytype, dictionary_id: u32) Error!Self {
            const dictionary = dictionary_set.find(dictionary_id) orelse return error.NeedDictionary;
            return initExactSizeWithDictionary(allocator, options, expected_input_len, dictionary.id, dictionary.content);
        }
        pub fn deinit(self: *Self) void {
            self.block_encoder.deinit();
            self.block.deinit(self.allocator);
            self.history.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            const expected_input_len = self.expected_input_len;
            self.block.clearRetainingCapacity();
            self.history.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            self.hasher = std.hash.XxHash32.init(0);
            self.header_written = false;
            self.finishing = false;
            self.footer_written = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
            self.expected_input_len = expected_input_len;
        }
        pub fn finish(self: *Self) void {
            self.finishing = true;
        }
        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if (self.finishing and input.len != 0) return error.TrailingData;
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.pending_offset != self.pending.items.len) {
                    const remaining = self.pending.items[self.pending_offset..];
                    const n = @min(output.len - output_written, remaining.len);
                    @memcpy(output[output_written..][0..n], remaining[0..n]);
                    self.pending_offset += n;
                    output_written += n;
                    self.total_output += n;
                    if (self.pending_offset != self.pending.items.len) return result(input_read, output_written, .need_output);
                    self.pending.clearRetainingCapacity();
                    self.pending_offset = 0;
                    if (output_written == output.len and output.len != 0) return result(input_read, output_written, .need_output);
                }
                if (!self.header_written) {
                    try Codec.writeHeader(self.allocator, &self.pending, self.options, self.expected_input_len, self.dictionary_id);
                    self.header_written = true;
                    continue;
                }
                const room = Codec.maxBlockLen(self.options) - self.block.items.len;
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    const bytes = input[input_read..][0..n];
                    try self.block.appendSlice(self.allocator, bytes);
                    if (self.options.content_checksum) self.hasher.update(bytes);
                    input_read += n;
                    self.total_input += n;
                    if (self.expected_input_len) |expected| {
                        if (self.total_input > expected) return error.SizeMismatch;
                    }
                }
                if (self.block.items.len == Codec.maxBlockLen(self.options) or (self.finishing and self.block.items.len != 0)) {
                    const prefix = if (self.history.items.len != 0) self.history.items else if (self.dictionary.len != 0) self.dictionary else &.{};
                    try Codec.writeBlock(&self.block_encoder, &self.pending, self.block.items, prefix, self.options);
                    if (self.options.block_mode == .linked) {
                        self.history.clearRetainingCapacity();
                        const keep = @min(self.block.items.len, 64 * 1024);
                        try self.history.appendSlice(self.allocator, self.block.items[self.block.items.len - keep ..]);
                    }
                    self.block.clearRetainingCapacity();
                    continue;
                }
                if (self.finishing and !self.footer_written) {
                    if (self.expected_input_len) |expected| {
                        if (self.total_input != expected) return error.SizeMismatch;
                    }
                    try Codec.writeFooter(self.allocator, &self.pending, self.options, &self.hasher);
                    self.footer_written = true;
                    continue;
                }
                if (self.finishing) {
                    self.done = true;
                    return result(input_read, output_written, .done);
                }
                return result(input_read, output_written, .need_input);
            }
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
