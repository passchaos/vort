const std = @import("std");
const core = @import("../../core.zig");

/// Build a no-content-size incremental Zstd raw/RLE frame encoder. One bounded
/// block is retained; completed encoded blocks drain through arbitrary caller
/// output. The final block bit is delayed until `finish`, as required by Zstd.
pub fn Encoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Codec.Options,
        block: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        hasher: std.hash.XxHash64 = std.hash.XxHash64.init(0),
        header_written: bool = false,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,

        const Self = @This();
        pub const Error = Codec.Error;
        pub fn init(allocator: std.mem.Allocator, options: Codec.Options) Error!Self {
            try Codec.validate(options);
            return .{ .allocator = allocator, .options = options };
        }
        pub fn deinit(self: *Self) void {
            self.block.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            self.block.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            self.hasher = std.hash.XxHash64.init(0);
            self.header_written = false;
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
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
                    try Codec.writeHeader(self.allocator, &self.pending, self.options);
                    self.header_written = true;
                    continue;
                }
                const room = Codec.blockLen(self.options) - self.block.items.len;
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    const bytes = input[input_read..][0..n];
                    try self.block.appendSlice(self.allocator, bytes);
                    if (self.options.content_checksum) self.hasher.update(bytes);
                    input_read += n;
                    self.total_input += n;
                }
                // A full block can be emitted only when another input byte proves
                // it is not final; otherwise retain it until finish.
                if (self.block.items.len == Codec.blockLen(self.options) and input_read < input.len) {
                    try Codec.writeBlock(self.allocator, &self.pending, self.block.items, false);
                    self.block.clearRetainingCapacity();
                    continue;
                }
                if (self.finishing and !self.final_written) {
                    try Codec.writeBlock(self.allocator, &self.pending, self.block.items, true);
                    self.block.clearRetainingCapacity();
                    try Codec.writeChecksum(self.allocator, &self.pending, self.options, &self.hasher);
                    self.final_written = true;
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
