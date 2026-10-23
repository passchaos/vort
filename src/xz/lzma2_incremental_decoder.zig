//! Symbol-progressive raw LZMA2 decoding for XZ and out-of-band 7z properties.
const std = @import("std");
const core = @import("../core.zig");
const lzma_decoder = @import("../lzma/decoder.zig");
const working = @import("../io/working_allocator.zig");
const options_mod = @import("lzma2/options.zig");
const dictionary_capacity = @import("lzma2/dictionary_capacity.zig");

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    budget: working.WorkingAllocator,
    phase: Phase = .control,
    control: u8 = 0,
    header: [5]u8 = undefined,
    header_len: usize = 0,
    header_needed: usize = 0,
    uncompressed_remaining: usize = 0,
    chunk_unpacked_size: usize = 0,
    compressed: std.ArrayList(u8) = .empty,
    compressed_expected: usize = 0,
    compressed_received: usize = 0,
    compressed_consumed: usize = 0,
    compressed_offset: usize = 0,
    lzma: ?std.compress.lzma.Decode = null,
    /// Opt-in one-shot reuse; ordinary incremental streams keep their existing
    /// single-model allocation and replacement behavior.
    retain_property_workspaces: bool = false,
    property_workspaces: [5]?std.compress.lzma.Decode = @splat(null),
    range_decoder: ?std.compress.lzma.RangeDecoder = null,
    dictionary: lzma_decoder.CircularBuffer,
    chunk_dictionary_end: usize = 0,
    staging: [options_mod.max_symbol_output]u8 = undefined,
    staging_len: usize = 0,
    staging_offset: usize = 0,
    decoded_total: usize = 0,
    input_read: usize = 0,
    output_written: usize = 0,
    input_finished: bool = false,
    dictionary_initialized: bool = false,
    properties_defined: bool = false,
    state_initialized: bool = false,
    failure: ?Error = null,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .control,
    last_step_progress: core.Progress = .{},
    error_input_offset: ?usize = null,
    error_output_offset: ?usize = null,

    pub const Error = core.Error || lzma_decoder.Error || std.mem.Allocator.Error || options_mod.Error || error{WorkingMemoryLimitExceeded};
    pub const Options = options_mod.Options;
    pub const Phase = enum { control, header, uncompressed, compressed_input, compressed_decode, output, done };
    pub const Snapshot = struct {
        phase: Phase,
        input_read: usize,
        decoded_total: usize,
        output_written: usize,
        buffered_compressed_bytes: usize,
        pending_output: usize,
        dictionary_size: usize,
        retained_dictionary_capacity: usize,
        retained_compressed_capacity: usize,
        retained_output_capacity: usize,
        working_bytes: usize,
        peak_working_bytes: usize,
        input_finished: bool,
        properties_defined: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
        last_step_progress: core.Progress,
        error_input_offset: ?usize,
        error_output_offset: ?usize,
    };

    /// Initialization validates limits without allocating or retaining a
    /// pointer to the returned value's budget. Allocators bind only during calls.
    pub fn init(allocator: std.mem.Allocator, options: Options) Error!Decoder {
        const dictionary_size = try options.validate();
        return .{
            .allocator = allocator,
            .options = options,
            .budget = working.WorkingAllocator.init(allocator, options.max_working_memory),
            .dictionary = lzma_decoder.CircularBuffer.init(dictionary_size, options.max_output_len),
        };
    }
    pub fn deinit(self: *Decoder) void {
        self.deinitBuffers();
        self.* = undefined;
    }
    fn deinitBuffers(self: *Decoder) void {
        if (self.lzma) |*decoder| decoder.deinit(self.budget.allocator());
        for (&self.property_workspaces) |*cached| if (cached.*) |*decoder| decoder.deinit(self.budget.allocator());
        self.dictionary.deinit(self.budget.allocator());
        self.compressed.deinit(self.budget.allocator());
        std.debug.assert(self.budget.live == 0);
    }
    /// Start a fresh logical stream while retaining all allocated capacities,
    /// including the current literal probability workspace.
    pub fn reset(self: *Decoder) void {
        var dictionary = self.dictionary;
        dictionary.bytes.clearRetainingCapacity();
        dictionary.cursor = 0;
        dictionary.len = 0;
        dictionary.output_limit = self.options.max_output_len;
        var compressed = self.compressed;
        compressed.clearRetainingCapacity();
        var state = self.lzma;
        const property_workspaces = self.property_workspaces;
        if (state) |*decoder| decoder.resetState(self.budget.allocator(), decoder.properties) catch unreachable;
        var budget = self.budget;
        budget.peak = budget.live;
        budget.hit_limit = false;
        budget.last_failure_was_limit = false;
        self.* = .{ .allocator = self.allocator, .options = self.options, .budget = budget, .dictionary = dictionary, .compressed = compressed, .lzma = state, .retain_property_workspaces = self.retain_property_workspaces, .property_workspaces = property_workspaces };
    }
    /// Reconfigure an independent raw payload while preserving warmed buffers.
    /// Validation happens before the old logical state changes.
    pub fn resetRetainingWithOptions(self: *Decoder, options: Options) Error!void {
        const size = try options.validate();
        self.reset();
        self.options = options;
        self.dictionary.dictionary_size = size;
        self.dictionary.output_limit = options.max_output_len;
        self.budget.limit = options.max_working_memory;
    }
    pub fn resetWithOptions(self: *Decoder, options: Options) Error!void {
        _ = try options.validate();
        const allocator = self.allocator;
        self.deinitBuffers();
        self.* = try init(allocator, options);
    }
    pub fn finish(self: *Decoder) void {
        self.input_finished = true;
    }
    pub fn workingMemoryBytes(self: *const Decoder) usize {
        return self.budget.live;
    }
    pub fn peakWorkingMemoryBytes(self: *const Decoder) usize {
        return self.budget.peak;
    }
    pub fn compressedBufferedBytes(self: *const Decoder) usize {
        return self.bufferedCompressedLen();
    }
    pub fn compressedBufferCapacity(self: *const Decoder) usize {
        return self.compressed.capacity;
    }
    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.input_read,
            .decoded_total = self.decoded_total,
            .output_written = self.output_written,
            .buffered_compressed_bytes = self.bufferedCompressedLen(),
            .pending_output = self.staging_len - self.staging_offset,
            .dictionary_size = self.dictionary.dictionary_size,
            .retained_dictionary_capacity = self.dictionary.bytes.capacity,
            .retained_compressed_capacity = self.compressed.capacity,
            .retained_output_capacity = self.staging.len,
            .working_bytes = self.budget.live,
            .peak_working_bytes = self.budget.peak,
            .input_finished = self.input_finished,
            .properties_defined = self.properties_defined,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
            .last_step_progress = self.last_step_progress,
            .error_input_offset = self.error_input_offset,
            .error_output_offset = self.error_output_offset,
        };
    }
    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .input_read = self.input_read,
            .frame_input_read = self.input_read,
            .output_written = self.output_written,
            .expected_output_len = self.options.expected_output_len,
            .payload_remaining = self.staging_len - self.staging_offset,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
            .last_step_progress = self.last_step_progress,
            .error_input_offset = self.error_input_offset,
            .error_output_offset = self.error_output_offset,
            .recoverability_hint_name = if (self.failure) |err| switch (err) {
                error.TruncatedFrame => "truncated_input",
                error.WorkingMemoryLimitExceeded => "raise_working_memory_limit",
                error.CompressedBufferLimitExceeded => "raise_compressed_buffer_limit",
                error.OutputLimitExceeded => "raise_output_or_dictionary_limit",
                error.OutOfMemory => "allocation_failure",
                else => "payload_corrupt",
            } else "none",
        };
    }
    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        self.last_step_progress = .{};
        if (self.failure) |err| return err;
        self.budget.last_failure_was_limit = false;
        const before = core.Progress{ .input_read = self.input_read, .output_written = self.output_written };
        const decoded = self.stepInternal(input, output) catch |original| {
            const err: Error = if (original == error.OutOfMemory and self.budget.last_failure_was_limit) error.WorkingMemoryLimitExceeded else original;
            self.last_step_progress = .{ .input_read = self.input_read - before.input_read, .output_written = self.output_written - before.output_written };
            self.failure = err;
            self.last_error_name = @errorName(err);
            self.last_error_phase = self.phase;
            self.error_input_offset = self.input_read;
            self.error_output_offset = self.output_written;
            return err;
        };
        self.last_step_progress = decoded.progress;
        return decoded;
    }
    fn stepInternal(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (!self.options.stop_after_end_marker and input.len != 0) return error.TrailingData;
            return result(0, 0, .done);
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;
        if (input.len > std.math.maxInt(usize) - self.input_read) return error.IntegerOverflow;
        var read: usize = 0;
        var written: usize = 0;
        while (true) switch (self.phase) {
            .control => {
                if (read == input.len) return self.needInput(read, written);
                self.control = input[read];
                try self.noteInput(1);
                read += 1;
                if (self.control == 0) {
                    if (self.options.expected_output_len) |expected|
                        if (self.decoded_total != expected) return error.SizeMismatch;
                    if (!self.options.stop_after_end_marker and read != input.len) return error.TrailingData;
                    self.phase = .done;
                    return result(read, written, .done);
                }
                if (self.control > 2 and self.control & 0x80 == 0) return error.InvalidLzma2Stream;
                self.header_len = 0;
                self.header_needed = if (self.control <= 2) 2 else if ((self.control >> 5) & 3 >= 2) 5 else 4;
                self.phase = .header;
            },
            .header => {
                const take = @min(self.header_needed - self.header_len, input.len - read);
                try self.noteInput(take);
                @memcpy(self.header[self.header_len..][0..take], input[read..][0..take]);
                self.header_len += take;
                read += take;
                if (self.header_len != self.header_needed) return self.needInput(read, written);
                try self.acceptHeader();
            },
            .uncompressed => {
                if (self.uncompressed_remaining == 0) {
                    self.phase = .control;
                    continue;
                }
                if (written == output.len) return result(read, written, .need_output);
                if (read == input.len) return self.needInput(read, written);
                const take = @min(self.uncompressed_remaining, @min(input.len - read, output.len - written));
                try self.reserveDictionary(take);
                const next_input = try add(self.input_read, take);
                for (input[read..][0..take]) |byte| {
                    if (self.dictionary.cursor < self.dictionary.bytes.items.len)
                        self.dictionary.bytes.items[self.dictionary.cursor] = byte
                    else
                        self.dictionary.bytes.appendAssumeCapacity(byte);
                    self.dictionary.cursor += 1;
                    if (self.dictionary.cursor == self.dictionary.dictionary_size) self.dictionary.cursor = 0;
                    self.dictionary.len += 1;
                }
                @memcpy(output[written..][0..take], input[read..][0..take]);
                read += take;
                self.input_read = next_input;
                self.uncompressed_remaining -= take;
                self.decoded_total += take;
                written += take;
                self.output_written += take;
            },
            .compressed_input => {
                if (!try self.ensureCompressed(5, input, &read)) return self.needInput(read, written);
                var reader: std.Io.Reader = .fixed(self.compressedInput());
                self.range_decoder = std.compress.lzma.RangeDecoder.init(&reader) catch |err| return mapProcessError(err);
                self.advanceCompressed(reader.seek);
                self.phase = .compressed_decode;
            },
            .compressed_decode => {
                if (self.dictionary.len == self.chunk_dictionary_end) {
                    if (self.compressed_consumed != self.compressed_expected) return error.SizeMismatch;
                    if (!self.range_decoder.?.isFinished()) return error.InvalidLzma2Stream;
                    self.compressed.clearRetainingCapacity();
                    self.compressed_offset = 0;
                    self.range_decoder = null;
                    self.phase = .control;
                    continue;
                }
                if (written == output.len) return result(read, written, .need_output);
                // No range/probability mutation occurs on a resumable input
                // shortage. The declared chunk boundary supplies a finite EOF
                // transaction when fewer than 64 lookahead bytes remain.
                const guard = @min(options_mod.symbol_input_guard, self.compressed_expected - self.compressed_consumed);
                if (!try self.ensureCompressed(guard, input, &read)) return self.needInput(read, written);
                const remaining_output = self.chunk_dictionary_end - self.dictionary.len;
                try self.reserveDictionary(@min(options_mod.max_symbol_output, remaining_output));
                var staging: std.Io.Writer.Allocating = .{
                    .allocator = self.budget.allocator(),
                    .writer = .fixed(&self.staging),
                    .alignment = .of(u8),
                };
                var reader: std.Io.Reader = .fixed(self.compressedInput());
                var bytes_read: u64 = 0;
                const status = self.lzma.?.process(&reader, &staging, &self.dictionary, &self.range_decoder.?, &bytes_read) catch |err| {
                    self.advanceCompressed(reader.seek);
                    return if (err == error.OutputLimitExceeded) error.SizeMismatch else mapProcessError(err);
                };
                self.advanceCompressed(reader.seek);
                if (status == .finished) return error.InvalidLzma2Stream;
                const staged = staging.writer.buffered().len;
                if (staged == 0 or staged > options_mod.max_symbol_output) return error.InvalidLzma2Stream;
                self.decoded_total = try add(self.decoded_total, staged);
                self.staging_len = staged;
                self.staging_offset = 0;
                self.phase = .output;
            },
            .output => {
                const take = @min(output.len - written, self.staging_len - self.staging_offset);
                @memcpy(output[written..][0..take], self.staging[self.staging_offset..][0..take]);
                written += take;
                self.output_written += take;
                self.staging_offset += take;
                if (self.staging_offset != self.staging_len) return result(read, written, .need_output);
                self.staging_len = 0;
                self.staging_offset = 0;
                self.phase = .compressed_decode;
            },
            .done => unreachable,
        };
    }
    fn acceptHeader(self: *Decoder) Error!void {
        if (self.control <= 2) {
            self.uncompressed_remaining = @as(usize, std.mem.readInt(u16, self.header[0..2], .big)) + 1;
            try self.reserveDecoded(self.uncompressed_remaining);
            if (self.control == 1) {
                self.dictionary_initialized = true;
                self.resetDictionary();
            } else if (!self.dictionary_initialized) return error.InvalidLzma2Stream;
            self.dictionary.output_limit = try add(self.dictionary.len, self.uncompressed_remaining);
            self.state_initialized = false;
            self.phase = .uncompressed;
            return;
        }
        self.chunk_unpacked_size = ((@as(usize, self.control & 0x1f) << 16) | @as(usize, std.mem.readInt(u16, self.header[0..2], .big))) + 1;
        self.compressed_expected = @as(usize, std.mem.readInt(u16, self.header[2..4], .big)) + 1;
        if (self.compressed_expected < 5) return error.InvalidLzma2Stream;
        const required_guard = @max(@as(usize, 5), @min(options_mod.symbol_input_guard, self.compressed_expected - 5));
        if (self.options.max_compressed_buffer_len < required_guard) return error.CompressedBufferLimitExceeded;
        const reset_mode = (self.control >> 5) & 3;
        if (reset_mode == 3) {
            self.dictionary_initialized = true;
            self.resetDictionary();
        }
        if (!self.dictionary_initialized) return error.InvalidLzma2Stream;
        if (reset_mode < 2 and !self.properties_defined) return error.InvalidLzma2Stream;
        if (reset_mode == 0 and !self.state_initialized) return error.InvalidLzma2Stream;
        try self.reserveDecoded(self.chunk_unpacked_size);
        if (reset_mode != 0) {
            const properties = if (reset_mode >= 2) try parseProperties(self.header[4]) else if (self.lzma) |decoder| decoder.properties else return error.InvalidLzma2Stream;
            try self.resetLzmaState(properties);
            self.properties_defined = true;
            self.state_initialized = true;
        } else if (self.lzma == null) return error.InvalidLzma2Stream;
        self.chunk_dictionary_end = try add(self.dictionary.len, self.chunk_unpacked_size);
        self.dictionary.output_limit = self.chunk_dictionary_end;
        self.compressed.clearRetainingCapacity();
        self.compressed_received = 0;
        self.compressed_consumed = 0;
        self.compressed_offset = 0;
        self.phase = .compressed_input;
    }
    fn reserveDecoded(self: *const Decoder, additional: usize) Error!void {
        const next = try add(self.decoded_total, additional);
        if (next > self.options.max_output_len) return error.OutputLimitExceeded;
        if (self.options.expected_output_len) |expected|
            if (next > expected) return error.SizeMismatch;
    }
    fn resetDictionary(self: *Decoder) void {
        self.dictionary.bytes.clearRetainingCapacity();
        self.dictionary.cursor = 0;
        self.dictionary.len = 0;
        self.dictionary.output_limit = self.options.max_output_len -| self.decoded_total;
    }
    fn reserveDictionary(self: *Decoder, additional: usize) Error!void {
        const needed = dictionary_capacity.needed(usize, self.dictionary.bytes.items.len, self.dictionary.dictionary_size, additional);
        if (needed > self.dictionary.bytes.capacity) {
            const grown = std.math.add(usize, self.dictionary.bytes.capacity, self.dictionary.bytes.capacity / 2 + 8) catch self.dictionary.dictionary_size;
            try self.dictionary.bytes.ensureTotalCapacityPrecise(self.budget.allocator(), @min(self.dictionary.dictionary_size, @max(needed, grown)));
        }
    }
    fn resetLzmaState(self: *Decoder, properties: std.compress.lzma.Decode.Properties) Error!void {
        if (self.retain_property_workspaces) {
            const shape = properties.lc + properties.lp;
            if (self.lzma) |*decoder| {
                if (decoder.properties.lc + decoder.properties.lp == shape) {
                    decoder.resetState(self.budget.allocator(), properties) catch |err| return mapProcessError(err);
                    return;
                }
            }
            // A missing shape is allocated transactionally while the old
            // active model and cached tables remain live and budgeted.
            var replacement = self.property_workspaces[shape] orelse
                (std.compress.lzma.Decode.init(self.budget.allocator(), properties) catch |err| return mapProcessError(err));
            replacement.resetState(self.budget.allocator(), properties) catch |err| return mapProcessError(err);
            if (self.lzma) |decoder| {
                const old_shape = decoder.properties.lc + decoder.properties.lp;
                std.debug.assert(self.property_workspaces[old_shape] == null);
                self.property_workspaces[old_shape] = decoder;
            }
            self.property_workspaces[shape] = null;
            self.lzma = replacement;
            return;
        }
        if (self.lzma) |*decoder| {
            if (decoder.properties.lc + decoder.properties.lp == properties.lc + properties.lp) {
                decoder.resetState(self.budget.allocator(), properties) catch |err| return mapProcessError(err);
                return;
            }
            // Allocate a replacement before freeing the old probability table
            // so a failed change leaves a valid object for reset/deinit.
            const replacement = std.compress.lzma.Decode.init(self.budget.allocator(), properties) catch |err| return mapProcessError(err);
            decoder.deinit(self.budget.allocator());
            self.lzma = replacement;
        } else self.lzma = std.compress.lzma.Decode.init(self.budget.allocator(), properties) catch |err| return mapProcessError(err);
    }
    fn bufferedCompressedLen(self: *const Decoder) usize {
        return self.compressed.items.len - self.compressed_offset;
    }
    fn compressedInput(self: *const Decoder) []const u8 {
        return self.compressed.items[self.compressed_offset..];
    }
    fn ensureCompressed(self: *Decoder, target: usize, input: []const u8, read: *usize) Error!bool {
        if (target > self.options.max_compressed_buffer_len) return error.CompressedBufferLimitExceeded;
        if (self.bufferedCompressedLen() >= target) return true;
        self.compactCompressed();
        const take = @min(target - self.compressed.items.len, @min(input.len - read.*, self.compressed_expected - self.compressed_received));
        if (take != 0) {
            const needed = self.compressed.items.len + take;
            if (needed > self.options.max_compressed_buffer_len) return error.CompressedBufferLimitExceeded;
            const next_input = try add(self.input_read, take);
            try self.compressed.ensureTotalCapacityPrecise(self.budget.allocator(), needed);
            self.compressed.appendSliceAssumeCapacity(input[read.*..][0..take]);
            read.* += take;
            self.input_read = next_input;
            self.compressed_received += take;
        }
        return self.compressed.items.len >= target;
    }
    fn compactCompressed(self: *Decoder) void {
        if (self.compressed_offset == 0) return;
        const len = self.bufferedCompressedLen();
        std.mem.copyForwards(u8, self.compressed.items[0..len], self.compressedInput());
        self.compressed.items.len = len;
        self.compressed_offset = 0;
    }
    fn advanceCompressed(self: *Decoder, count: usize) void {
        std.debug.assert(count <= self.bufferedCompressedLen());
        self.compressed_offset += count;
        self.compressed_consumed += count;
        if (self.compressed_offset == self.compressed.items.len) {
            self.compressed.clearRetainingCapacity();
            self.compressed_offset = 0;
        }
    }
    fn noteInput(self: *Decoder, count: usize) Error!void {
        self.input_read = try add(self.input_read, count);
    }
    fn needInput(self: *const Decoder, read: usize, written: usize) Error!core.StepResult {
        if (self.input_finished) return error.TruncatedFrame;
        return result(read, written, .need_input);
    }
};

pub const dictionarySizeFromProperty = options_mod.dictionarySizeFromProperty;
fn parseProperties(encoded: u8) Decoder.Error!std.compress.lzma.Decode.Properties {
    if (encoded >= 225) return error.InvalidLzma2Stream;
    const lc: u4 = @intCast(encoded % 9);
    const remainder = encoded / 9;
    const lp: u3 = @intCast(remainder % 5);
    const pb: u3 = @intCast(remainder / 5);
    if (lc + lp > 4) return error.InvalidLzma2Stream;
    return .{ .lc = lc, .lp = lp, .pb = pb };
}
fn mapProcessError(err: anyerror) Decoder.Error {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        error.EndOfStream => error.TruncatedFrame,
        error.Overflow => error.IntegerOverflow,
        error.OutputLimitExceeded => error.OutputLimitExceeded,
        else => error.InvalidLzma2Stream,
    };
}
fn add(a: usize, b: usize) Decoder.Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}
fn result(read: usize, written: usize, status: core.StepResult.Status) core.StepResult {
    return .{ .progress = .{ .input_read = read, .output_written = written }, .status = status };
}
test {
    _ = @import("lzma2/tests.zig");
}
