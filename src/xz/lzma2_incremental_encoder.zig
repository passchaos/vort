//! Chunk-bounded raw LZMA2 encoder for container formats such as 7z.

const std = @import("std");
const core = @import("../core.zig");
const lzma_encoder = @import("../lzma/encoder.zig");
const writer = @import("lzma2_writer.zig");

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    input: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    expected_input_len: ?usize = null,
    total_input: usize = 0,
    total_output: usize = 0,
    finishing: bool = false,
    terminator_written: bool = false,
    done: bool = false,

    pub const Error = core.Error || lzma_encoder.Error || std.mem.Allocator.Error;

    pub const Mode = enum {
        compressed,
        stored,
    };

    pub const Options = struct {
        mode: Mode = .compressed,
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = writer.max_uncompressed_chunk + 16,
    };

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!Encoder {
        try validateOptions(options);
        return .{ .allocator = allocator, .options = options };
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) Error!Encoder {
        try validateOptions(options);
        if (expected_input_len > options.max_input_len) return error.OutputLimitExceeded;
        return .{
            .allocator = allocator,
            .options = options,
            .expected_input_len = expected_input_len,
        };
    }

    pub fn deinit(self: *Encoder) void {
        self.input.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn finish(self: *Encoder) void {
        if (!self.done) self.finishing = true;
    }

    pub fn step(self: *Encoder, input: []const u8, output: []u8) Error!core.StepResult {
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
                const take = @min(remaining.len, output.len - output_written);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.pending_offset += take;
                output_written += take;
                self.total_output = std.math.add(usize, self.total_output, take) catch
                    return error.IntegerOverflow;
                if (self.pending_offset != self.pending.items.len)
                    return result(input_read, output_written, .need_output);
                self.pending.clearRetainingCapacity();
                self.pending_offset = 0;
                if (output_written == output.len and output.len != 0)
                    return result(input_read, output_written, .need_output);
            }

            if (input_read < input.len) {
                const room = writer.max_uncompressed_chunk - self.input.items.len;
                const take = @min(room, input.len - input_read);
                const next_total = std.math.add(usize, self.total_input, take) catch
                    return error.IntegerOverflow;
                if (next_total > self.options.max_input_len) return error.OutputLimitExceeded;
                if (self.expected_input_len) |expected|
                    if (next_total > expected) return error.SizeMismatch;
                try self.input.appendSlice(self.allocator, input[input_read..][0..take]);
                input_read += take;
                self.total_input = next_total;
            }

            if (self.input.items.len == writer.max_uncompressed_chunk or
                (self.finishing and self.input.items.len != 0))
            {
                try self.emitChunk();
                continue;
            }
            if (input_read < input.len) continue;

            if (self.finishing) {
                if (self.expected_input_len) |expected|
                    if (self.total_input != expected) return error.SizeMismatch;
                if (!self.terminator_written) {
                    try self.pending.append(self.allocator, 0);
                    try self.checkPendingLimit();
                    self.terminator_written = true;
                    continue;
                }
                self.done = true;
                return result(input_read, output_written, .done);
            }
            return result(input_read, output_written, .need_input);
        }
    }

    fn emitChunk(self: *Encoder) Error!void {
        std.debug.assert(self.input.items.len != 0);
        const start = self.pending.items.len;
        switch (self.options.mode) {
            .compressed => _ = try writer.appendCompressedPayload(
                self.allocator,
                &self.pending,
                self.input.items,
            ),
            .stored => _ = try writer.appendStoredPayload(
                self.allocator,
                &self.pending,
                self.input.items,
            ),
        }
        // Each bounded helper emits a complete one-chunk stream. Keep the
        // dictionary-reset chunk and defer the sole stream terminator to
        // `finish`, allowing subsequent chunks without retaining all input.
        std.debug.assert(self.pending.items.len > start and self.pending.items[self.pending.items.len - 1] == 0);
        self.pending.items.len -= 1;
        try self.checkPendingLimit();
        self.input.clearRetainingCapacity();
    }

    fn checkPendingLimit(self: *const Encoder) Error!void {
        if (self.pending.items.len - self.pending_offset > self.options.max_pending_output_len)
            return error.OutputLimitExceeded;
    }
};

fn validateOptions(options: Encoder.Options) Encoder.Error!void {
    if (options.max_pending_output_len < writer.max_uncompressed_chunk + 3)
        return error.InvalidBlockPlan;
}

fn result(
    input_read: usize,
    output_written: usize,
    status: core.StepResult.Status,
) core.StepResult {
    return .{
        .progress = .{ .input_read = input_read, .output_written = output_written },
        .status = status,
    };
}

test "raw LZMA2 incremental encoder is fragmentation independent" {
    const container = @import("container.zig");
    const input = ("chunk-bounded incremental LZMA2 payload\n" ** 2200) ++ "tail";
    inline for (.{ Encoder.Mode.compressed, Encoder.Mode.stored }) |mode| {
        var baseline: ?[]u8 = null;
        defer if (baseline) |bytes| std.testing.allocator.free(bytes);
        for ([_]usize{ 1, 7, 257, writer.max_uncompressed_chunk + 19 }) |input_chunk| {
            var encoder = try Encoder.initExactSize(
                std.testing.allocator,
                .{ .mode = mode },
                input.len,
            );
            defer encoder.deinit();
            var encoded: std.ArrayList(u8) = .empty;
            defer encoded.deinit(std.testing.allocator);
            var offset: usize = 0;
            while (offset < input.len) {
                const end = @min(input.len, offset + input_chunk);
                var output: [17]u8 = undefined;
                const stepped = try encoder.step(input[offset..end], &output);
                offset += stepped.progress.input_read;
                try encoded.appendSlice(std.testing.allocator, output[0..stepped.progress.output_written]);
            }
            encoder.finish();
            while (true) {
                var output: [17]u8 = undefined;
                const stepped = try encoder.step(&.{}, &output);
                try encoded.appendSlice(std.testing.allocator, output[0..stepped.progress.output_written]);
                if (stepped.status == .done) break;
            }
            if (baseline) |bytes|
                try std.testing.expectEqualSlices(u8, bytes, encoded.items)
            else
                baseline = try std.testing.allocator.dupe(u8, encoded.items);
            const decoded = try container.decode7zPayloadAllocLimited(
                std.testing.allocator,
                encoded.items,
                writer.dictionary_property,
                input.len,
                writer.dictionary_size,
            );
            defer std.testing.allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, input, decoded);
        }
    }
}
