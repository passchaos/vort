//! Chunk-bounded raw LZMA2 encoder for container formats such as 7z.

const std = @import("std");
const core = @import("../core.zig");
const lzma_encoder = @import("../lzma/encoder.zig");
const writer = @import("lzma2_writer.zig");
const chunk_encoder = @import("encoder/chunk.zig");

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    chunk_state: chunk_encoder.State,
    input: std.ArrayList(u8) = .empty,
    history: std.ArrayList(u8) = .empty,
    candidate: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    expected_input_len: ?usize = null,
    total_input: usize = 0,
    encoded_input: usize = 0,
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
        dictionary_size: usize = writer.dictionary_size,
        /// Compressed input group size. Stored mode retains 64KiB packets.
        chunk_size: usize = writer.max_uncompressed_chunk,
        parser: writer.Parser = .greedy,
        properties: writer.Properties = .{},
        match_options: ?writer.MatchOptions = null,
        max_input_len: usize = std.math.maxInt(usize),
        /// Null derives a complete group's bound; the default 64KiB group keeps
        /// the historical 65552-byte limit. An explicit cap is never raised.
        max_pending_output_len: ?usize = null,

        pub fn fromPreset(level: u32, extreme: bool) Error!Options {
            const preset = try writer.EncodeOptions.fromPreset(level, extreme);
            return .{ .dictionary_size = preset.dictionary_size, .chunk_size = preset.chunk_size, .parser = preset.parser, .properties = preset.properties, .match_options = preset.match_options };
        }
        pub fn validate(self: Options) Error!void {
            try validateOptions(self);
        }
        pub fn chunkOptions(self: Options) chunk_encoder.Options {
            return .{ .dictionary_size = self.dictionary_size, .chunk_size = self.chunk_size, .parser = self.parser, .properties = self.properties, .match_options = self.match_options };
        }
        pub fn inputGroupSize(self: Options) usize {
            return if (self.mode == .compressed) self.chunk_size else writer.max_uncompressed_chunk;
        }
        pub fn effectiveMaxPendingOutputLen(self: Options) Error!usize {
            if (self.max_pending_output_len) |explicit| return explicit;
            const stored_size = (try writer.storedPayloadSize(self.inputGroupSize())) - 1;
            return std.math.add(usize, stored_size, 13) catch error.IntegerOverflow;
        }
    };

    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        encoded_input: usize,
        buffered_input: usize,
        buffered_history: usize,
        pending_output: usize,
        retained_input_capacity: usize,
        retained_history_capacity: usize,
        retained_candidate_capacity: usize,
        retained_output_capacity: usize,
        configured_chunk_size: usize,
        input_group_size: usize,
        model_valid: bool,
        properties_initialized: bool,
        finishing: bool,
        terminator_written: bool,
        done: bool,
    };

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!Encoder {
        try validateOptions(options);
        return .{
            .allocator = allocator,
            .options = options,
            .chunk_state = try chunk_encoder.State.init(options.chunkOptions()),
        };
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) Error!Encoder {
        var state = try init(allocator, options);
        if (expected_input_len > options.max_input_len) return error.OutputLimitExceeded;
        state.expected_input_len = expected_input_len;
        return state;
    }

    pub fn deinit(self: *Encoder) void {
        self.input.deinit(self.allocator);
        self.history.deinit(self.allocator);
        self.candidate.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    /// Start another raw payload with the same validated settings and retained
    /// buffer capacity. Work profiles accumulate independently of stream state.
    pub fn reset(self: *Encoder) Error!void {
        try validateOptions(self.options);
        try self.chunk_state.reset(self.options.chunkOptions());
        self.input.clearRetainingCapacity();
        self.history.clearRetainingCapacity();
        self.candidate.clearRetainingCapacity();
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        self.total_input = 0;
        self.encoded_input = 0;
        self.total_output = 0;
        self.finishing = false;
        self.terminator_written = false;
        self.done = false;
    }

    pub fn finish(self: *Encoder) void {
        if (!self.done) self.finishing = true;
    }

    /// Accepted input and delivered output are distinct from committed groups.
    /// On an emission error the buffered input is retained: restoring a limit
    /// and retrying with empty input continues without accepting it twice.
    pub fn snapshot(self: *const Encoder) Snapshot {
        return .{
            .input_read = self.total_input,
            .output_written = self.total_output,
            .encoded_input = self.encoded_input,
            .buffered_input = self.input.items.len,
            .buffered_history = self.history.items.len,
            .pending_output = self.pending.items.len - self.pending_offset,
            .retained_input_capacity = self.input.capacity,
            .retained_history_capacity = self.history.capacity,
            .retained_candidate_capacity = self.candidate.capacity,
            .retained_output_capacity = self.pending.capacity,
            .configured_chunk_size = self.options.chunk_size,
            .input_group_size = self.options.inputGroupSize(),
            .model_valid = self.chunk_state.model_valid,
            .properties_initialized = self.chunk_state.properties_initialized,
            .finishing = self.finishing,
            .terminator_written = self.terminator_written,
            .done = self.done,
        };
    }

    pub fn step(self: *Encoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            self.options.chunkOptions().recordEffectiveSettings();
            return .{ .status = .done };
        }
        if (self.finishing and input.len != 0) return error.TrailingData;
        if (self.finishing) if (self.expected_input_len) |expected| {
            if (self.total_input != expected) return error.SizeMismatch;
        };
        self.options.chunkOptions().recordEffectiveSettings();

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.pending_offset != self.pending.items.len) {
                const remaining = self.pending.items[self.pending_offset..];
                const take = @min(remaining.len, output.len - output_written);
                const next_output = std.math.add(usize, self.total_output, take) catch
                    return error.IntegerOverflow;
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.pending_offset += take;
                output_written += take;
                self.total_output = next_output;
                if (self.pending_offset != self.pending.items.len)
                    return result(input_read, output_written, .need_output);
                self.pending.clearRetainingCapacity();
                self.pending_offset = 0;
                if (output_written == output.len and output.len != 0)
                    return result(input_read, output_written, .need_output);
            }

            if (input_read < input.len) {
                const room = self.options.inputGroupSize() - self.input.items.len;
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

            if (self.input.items.len == self.options.inputGroupSize() or
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
                    const end_len = std.math.add(usize, self.pending.items.len, 1) catch return error.IntegerOverflow;
                    if (end_len - self.pending_offset > try self.options.effectiveMaxPendingOutputLen()) return error.OutputLimitExceeded;
                    try self.pending.append(self.allocator, 0);
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
        const next_encoded_input = std.math.add(usize, self.encoded_input, self.input.items.len) catch return error.IntegerOverflow;
        const history_len = @min(self.options.dictionary_size, std.math.add(usize, self.history.items.len, self.input.items.len) catch return error.IntegerOverflow);
        try self.history.ensureTotalCapacity(self.allocator, history_len);
        const original_pending_len = self.pending.items.len;
        errdefer self.pending.shrinkRetainingCapacity(original_pending_len);
        var trial_state = self.chunk_state;
        switch (self.options.mode) {
            .compressed => _ = try trial_state.append(self.allocator, &self.pending, &self.candidate, self.input.items, self.history.items, self.encoded_input, self.options.chunkOptions(), null),
            .stored => _ = try trial_state.appendUncompressed(self.allocator, &self.pending, self.input.items, self.encoded_input == 0),
        }
        try self.checkPendingLimit();
        self.retainHistory(self.input.items);
        self.chunk_state = trial_state;
        self.encoded_input = next_encoded_input;
        self.input.clearRetainingCapacity();
    }

    fn retainHistory(self: *Encoder, chunk: []const u8) void {
        const dictionary_size = self.options.dictionary_size;
        if (chunk.len >= dictionary_size) {
            self.history.clearRetainingCapacity();
            self.history.appendSliceAssumeCapacity(chunk[chunk.len - dictionary_size ..]);
            return;
        }
        const keep = @min(self.history.items.len, dictionary_size - chunk.len);
        if (keep != self.history.items.len)
            std.mem.copyForwards(
                u8,
                self.history.items[0..keep],
                self.history.items[self.history.items.len - keep ..],
            );
        self.history.items.len = keep;
        self.history.appendSliceAssumeCapacity(chunk);
    }

    fn checkPendingLimit(self: *const Encoder) Error!void {
        if (self.pending.items.len - self.pending_offset > try self.options.effectiveMaxPendingOutputLen())
            return error.OutputLimitExceeded;
    }
};

fn validateOptions(options: Encoder.Options) Encoder.Error!void {
    try options.chunkOptions().validate();
    _ = try writer.dictionaryProperty(options.dictionary_size);
    const minimum = @min(options.inputGroupSize(), writer.max_uncompressed_chunk) + 3;
    if (try options.effectiveMaxPendingOutputLen() < minimum)
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

test {
    _ = @import("large_chunk_stream_tests.zig");
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
        var expected: std.ArrayList(u8) = .empty;
        defer expected.deinit(std.testing.allocator);
        switch (mode) {
            .compressed => _ = try writer.appendCompressedPayload(
                std.testing.allocator,
                &expected,
                input,
            ),
            .stored => _ = try writer.appendStoredPayload(
                std.testing.allocator,
                &expected,
                input,
            ),
        }
        try std.testing.expectEqualSlices(u8, expected.items, baseline.?);
        if (mode == .compressed) {
            const first_packed_size = @as(
                usize,
                std.mem.readInt(u16, baseline.?[3..5], .big),
            ) + 1;
            const second_chunk = 6 + first_packed_size;
            try std.testing.expectEqual(@as(u8, 0x80), baseline.?[second_chunk]);
        }
    }
}
