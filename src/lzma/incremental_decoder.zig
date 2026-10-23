const std = @import("std");
const core = @import("../core.zig");
const lzma_decoder = @import("decoder.zig");
const options_mod = @import("incremental/options.zig");
const working = @import("../io/working_allocator.zig");

/// True symbol-progressive LZMA-Alone decoder. The compressed staging window is
/// bounded and compacted as range-coded bytes are consumed; decoded staging is
/// limited to one committed literal/match before caller-output backpressure.
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    budget: working.WorkingAllocator,
    phase: Phase = .header,
    header_bytes: [13]u8 = undefined,
    header_len: usize = 0,
    header: ?lzma_decoder.Header = null,
    declared_size: ?usize = null,
    compressed: std.ArrayList(u8) = .empty,
    compressed_start: usize = 0,
    decoder: ?std.compress.lzma.Decode = null,
    range_decoder: ?std.compress.lzma.RangeDecoder = null,
    dictionary: ?lzma_decoder.CircularBuffer = null,
    staging: [options_mod.max_symbol_output]u8 = undefined,
    staging_len: usize = 0,
    staging_offset: usize = 0,
    validated_output: usize = 0,
    output_written: usize = 0,
    input_read: usize = 0,
    input_finished: bool = false,
    saw_end_marker: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .header,
    failure: ?Error = null,
    error_input_offset: ?usize = null,
    error_output_offset: ?usize = null,
    last_step_progress: core.Progress = .{},

    const header_size: usize = 13;
    const range_prefix_len: usize = 5;
    // One LZMA symbol reads at most the match/length flags, a 10-bit length
    // tree, a 6-bit position slot, 26 direct bits, and a 4-bit align tree.
    // Range normalization consumes at most one byte per bit, so 64 bytes is a
    // conservative non-final transaction guard.
    const symbol_input_guard: usize = options_mod.symbol_input_guard;

    pub const Error = lzma_decoder.Error || std.mem.Allocator.Error || error{WorkingMemoryLimitExceeded};
    pub const Options = options_mod.Options;
    pub const Phase = enum {
        header,
        range_prefix,
        decode,
        output,
        known_size_complete,
        end_marker,
        done,
    };
    pub const Snapshot = struct {
        phase: Phase,
        header_received: usize,
        buffered_compressed_bytes: usize,
        pending_output: usize,
        validated_output: usize,
        output_written: usize,
        input_read: usize,
        declared_output_len: ?usize,
        dictionary_size: ?u32,
        retained_compressed_capacity: usize,
        retained_dictionary_capacity: usize,
        retained_output_capacity: usize,
        input_finished: bool,
        saw_end_marker: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
        trailing_input_bytes: usize,
        working_bytes: usize,
        peak_working_bytes: usize,
        last_step_progress: core.Progress,
        error_input_offset: ?usize,
        error_output_offset: ?usize,
    };

    pub fn init(allocator: std.mem.Allocator) Decoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Decoder {
        return .{
            .allocator = allocator,
            .options = options,
            .budget = working.WorkingAllocator.init(allocator, options.max_working_memory),
        };
    }

    pub fn deinit(self: *Decoder) void {
        if (self.decoder) |*state| state.deinit(self.budget.allocator());
        if (self.dictionary) |*dictionary| dictionary.deinit(self.budget.allocator());
        self.compressed.deinit(self.budget.allocator());
        std.debug.assert(self.budget.live == 0);
        self.* = undefined;
    }

    pub fn reset(self: *Decoder) void {
        var state = self.decoder;
        var dictionary = self.dictionary;
        var compressed = self.compressed;
        var budget = self.budget;
        if (state) |*model| model.resetState(self.budget.allocator(), model.properties) catch unreachable;
        if (dictionary) |*history| {
            history.bytes.clearRetainingCapacity();
            history.cursor = 0;
            history.len = 0;
            history.output_limit = self.options.max_output_len;
        }
        compressed.clearRetainingCapacity();
        budget.peak = budget.live;
        budget.hit_limit = false;
        budget.last_failure_was_limit = false;
        self.* = initWithOptions(self.allocator, self.options);
        self.decoder = state;
        self.dictionary = dictionary;
        self.compressed = compressed;
        self.budget = budget;
    }

    pub fn resetWithOptions(self: *Decoder, options: Options) void {
        options.validate() catch |err| {
            self.recordError(self.phase, err);
            return;
        };
        const allocator = self.allocator;
        self.deinit();
        self.* = initWithOptions(allocator, options);
    }

    pub fn workingMemoryBytes(self: *const Decoder) usize {
        return self.budget.live;
    }
    pub fn peakWorkingMemoryBytes(self: *const Decoder) usize {
        return self.budget.peak;
    }

    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .header_received = self.header_len,
            .buffered_compressed_bytes = self.bufferedCompressedLen(),
            .pending_output = self.staging_len - self.staging_offset,
            .validated_output = self.validated_output,
            .output_written = self.output_written,
            .input_read = self.input_read,
            .declared_output_len = self.declared_size,
            .dictionary_size = if (self.header) |header| header.dictionary_size else null,
            .retained_compressed_capacity = self.compressed.capacity,
            .retained_dictionary_capacity = if (self.dictionary) |dictionary| dictionary.bytes.capacity else 0,
            .retained_output_capacity = options_mod.max_symbol_output,
            .input_finished = self.input_finished,
            .saw_end_marker = self.saw_end_marker,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
            .trailing_input_bytes = self.trailingInput().len,
            .working_bytes = self.budget.live,
            .peak_working_bytes = self.budget.peak,
            .last_step_progress = self.last_step_progress,
            .error_input_offset = self.error_input_offset,
            .error_output_offset = self.error_output_offset,
        };
    }

    pub fn trailingInput(self: *const Decoder) []const u8 {
        if (!self.options.stop_after_end_marker or self.phase != .done or !self.saw_end_marker)
            return &.{};
        return self.compressed.items[self.compressed_start..];
    }

    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
            .input_read = snap.input_read,
            .frame_input_read = snap.input_read,
            .header_received = snap.header_received,
            .output_written = snap.output_written,
            .expected_output_len = self.options.expected_output_len,
            .payload_remaining = snap.pending_output,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0) "" else @tagName(snap.last_error_phase),
            .error_input_offset = snap.error_input_offset,
            .error_output_offset = snap.error_output_offset,
            .last_step_progress = snap.last_step_progress,
            .recoverability_hint_name = if (std.mem.eql(u8, snap.last_error_name, @errorName(error.TruncatedFrame)))
                "truncated_input"
            else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.WorkingMemoryLimitExceeded)))
                "raise_working_memory_limit"
            else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.OutOfMemory)))
                "allocation_failure"
            else if (std.mem.eql(u8, snap.last_error_name, @errorName(error.OutputLimitExceeded)))
                "raise_input_output_or_dictionary_limit"
            else if (snap.last_error_name.len == 0)
                "none"
            else
                "payload_corrupt",
        };
    }

    /// Declare that no more compressed input will arrive. Remaining range
    /// symbols and caller-output staging drain through `step("", output)`.
    pub fn finish(self: *Decoder) void {
        self.input_finished = true;
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        self.last_step_progress = .{};
        if (self.failure) |err| return err;
        self.budget.last_failure_was_limit = false;
        const before = core.Progress{ .input_read = self.input_read, .output_written = self.output_written };
        const stepped = self.stepChecked(input, output) catch |original| {
            const err = if (original == error.OutOfMemory and self.budget.last_failure_was_limit) error.WorkingMemoryLimitExceeded else original;
            self.last_step_progress = .{ .input_read = self.input_read - before.input_read, .output_written = self.output_written - before.output_written };
            self.recordError(self.phase, err);
            return err;
        };
        self.last_step_progress = stepped.progress;
        return stepped;
    }
    fn stepChecked(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (input.len > std.math.maxInt(usize) - self.input_read) return error.IntegerOverflow;
        try self.options.validate();
        return self.stepInternal(input, output);
    }

    fn stepInternal(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (self.options.stop_after_end_marker) return .{ .status = .done };
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .header => {
                const take = @min(header_size - self.header_len, input.len - input_read);
                @memcpy(self.header_bytes[self.header_len..][0..take], input[input_read..][0..take]);
                self.header_len += take;
                input_read += take;
                self.input_read += take;
                if (self.header_len != header_size) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                try self.acceptHeader();
                self.phase = .range_prefix;
            },
            .range_prefix => {
                if (!try self.ensureCompressed(range_prefix_len, input, &input_read)) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                var reader: std.Io.Reader = .fixed(self.compressed.items[self.compressed_start..]);
                self.range_decoder = std.compress.lzma.RangeDecoder.init(&reader) catch |err| {
                    self.advanceCompressed(reader.seek);
                    return switch (err) {
                        error.EndOfStream => error.TruncatedFrame,
                        else => error.InvalidLzmaStream,
                    };
                };
                self.advanceCompressed(reader.seek);
                self.phase = .decode;
            },
            .decode => {
                const dictionary = &(self.dictionary.?);
                if (self.declared_size) |size| {
                    if (dictionary.len == size) {
                        self.phase = .known_size_complete;
                        continue;
                    }
                }

                const input_guard = if (self.options.stop_after_end_marker and
                    self.options.end_marker_input_guard != 0)
                    self.options.end_marker_input_guard
                else
                    symbol_input_guard;
                const probe_needed = output_written == output.len or input_guard < symbol_input_guard;
                if (!probe_needed and !self.input_finished and self.bufferedCompressedLen() < input_guard) {
                    if (input_read == input.len)
                        return result(input_read, output_written, .need_input);
                    try self.appendCompressedGuard(input_guard, input, &input_read);
                    continue;
                }

                if (probe_needed) {
                    if (input_guard < symbol_input_guard and !self.input_finished and self.bufferedCompressedLen() < input_guard) {
                        if (input_read == input.len) return result(input_read, output_written, .need_input);
                        try self.appendCompressedGuard(input_guard, input, &input_read);
                        continue;
                    }
                    const probed = self.probeSymbol() catch |err| {
                        if (err == error.EndOfStream and !self.input_finished) {
                            if (self.bufferedCompressedLen() >= symbol_input_guard) return error.InvalidLzmaStream;
                            if (input_read == input.len) return result(input_read, output_written, .need_input);
                            try self.appendCompressedGuard(self.bufferedCompressedLen() + 1, input, &input_read);
                            continue;
                        }
                        return self.mapProcessError(err);
                    };
                    if (probed.end_marker) {
                        self.decoder = probed.state;
                        self.range_decoder = probed.range;
                        self.advanceCompressed(probed.consumed);
                        self.saw_end_marker = true;
                        self.validated_output = dictionary.len;
                        if (self.declared_size) |size| if (dictionary.len != size) return error.SizeMismatch;
                        self.phase = .end_marker;
                        continue;
                    }
                    if (output_written == output.len) return result(input_read, output_written, .need_output);
                }

                try self.reserveDictionary(@min(options_mod.max_symbol_output, dictionary.output_limit - dictionary.len));
                var staging: std.Io.Writer.Allocating = .{
                    .allocator = self.budget.allocator(),
                    .writer = .fixed(&self.staging),
                    .alignment = .of(u8),
                };

                var reader: std.Io.Reader = .fixed(self.compressed.items[self.compressed_start..]);
                var bytes_read: u64 = 0;
                const status = (&self.decoder.?).process(
                    &reader,
                    &staging,
                    dictionary,
                    &self.range_decoder.?,
                    &bytes_read,
                ) catch |err| {
                    self.advanceCompressed(reader.seek);
                    self.validated_output = dictionary.len;
                    return self.mapProcessError(err);
                };
                self.advanceCompressed(reader.seek);
                switch (status) {
                    .more => {
                        self.staging_len = staging.writer.buffered().len;
                        if (self.staging_len == 0) return error.InvalidLzmaStream;
                        self.validated_output = dictionary.len;
                        self.staging_offset = 0;
                        self.phase = .output;
                    },
                    .finished => {
                        self.saw_end_marker = true;
                        self.validated_output = dictionary.len;
                        if (self.declared_size) |size|
                            if (dictionary.len != size) return error.SizeMismatch;
                        self.staging_offset = 0;
                        self.staging_len = staging.writer.buffered().len;
                        self.phase = if (self.staging_len == 0) .end_marker else .output;
                    },
                }
            },
            .output => {
                const remaining = self.staging[self.staging_offset..self.staging_len];
                const take = @min(output.len - output_written, remaining.len);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.staging_offset += take;
                output_written += take;
                self.output_written += take;
                if (self.staging_offset != self.staging_len)
                    return result(input_read, output_written, .need_output);
                self.staging_len = 0;
                self.staging_offset = 0;
                self.phase = if (self.saw_end_marker) .end_marker else .decode;
            },
            .known_size_complete => {
                self.compressed.clearRetainingCapacity();
                self.compressed_start = 0;
                self.input_read += input.len - input_read;
                input_read = input.len;
                if (!self.input_finished)
                    return result(input_read, output_written, .need_input);
                try self.validateFinalSize();
                self.phase = .done;
                return result(input_read, output_written, .done);
            },
            .end_marker => {
                if (self.options.stop_after_end_marker) {
                    try self.validateFinalSize();
                    self.phase = .done;
                    return result(input_read, output_written, .done);
                }
                if (self.bufferedCompressedLen() != 0) return error.TrailingData;
                if (input.len != input_read) return error.TrailingData;
                if (!self.input_finished)
                    return result(input_read, output_written, .need_input);
                try self.validateFinalSize();
                self.phase = .done;
                return result(input_read, output_written, .done);
            },
            .done => return result(input_read, output_written, .done),
        };
    }

    fn acceptHeader(self: *Decoder) Error!void {
        const parsed = try lzma_decoder.parseHeader(&self.header_bytes);
        if (parsed.dictionary_size > self.options.max_dictionary_size)
            return error.OutputLimitExceeded;
        const declared_size: ?usize = if (parsed.uncompressed_size) |size|
            std.math.cast(usize, size) orelse return error.OutputLimitExceeded
        else
            null;
        if (declared_size) |size| {
            if (size > self.options.max_output_len) return error.OutputLimitExceeded;
            if (self.options.expected_output_len) |expected|
                if (size != expected) return error.SizeMismatch;
        } else if (self.options.expected_output_len) |expected| {
            if (expected > self.options.max_output_len) return error.OutputLimitExceeded;
        }
        const output_limit = declared_size orelse self.options.expected_output_len orelse self.options.max_output_len;
        const properties = std.compress.lzma.Decode.Properties{
            .lc = parsed.lc,
            .lp = parsed.lp,
            .pb = parsed.pb,
        };
        if (self.decoder) |*state| {
            if (state.properties.lc + state.properties.lp == properties.lc + properties.lp) {
                state.resetState(self.budget.allocator(), properties) catch |err| return self.mapProcessError(err);
            } else {
                const replacement = std.compress.lzma.Decode.init(self.budget.allocator(), properties) catch |err| return self.mapProcessError(err);
                state.deinit(self.budget.allocator());
                self.decoder = replacement;
            }
        } else self.decoder = std.compress.lzma.Decode.init(self.budget.allocator(), properties) catch |err| return self.mapProcessError(err);
        if (self.dictionary) |*history| {
            history.bytes.clearRetainingCapacity();
            history.dictionary_size = parsed.dictionary_size;
            history.output_limit = output_limit;
            history.cursor = 0;
            history.len = 0;
        } else self.dictionary = lzma_decoder.CircularBuffer.init(parsed.dictionary_size, output_limit);
        self.header = parsed;
        self.declared_size = declared_size;
    }

    fn validateFinalSize(self: *Decoder) Error!void {
        if (self.options.expected_output_len) |expected|
            if (self.validated_output != expected) return error.SizeMismatch;
        if (self.declared_size == null and !self.saw_end_marker)
            return error.InvalidLzmaStream;
    }

    fn reserveDictionary(self: *Decoder, additional: usize) Error!void {
        const dictionary = &self.dictionary.?;
        const active = @min(dictionary.bytes.items.len, dictionary.dictionary_size);
        const needed = active + @min(additional, dictionary.dictionary_size - active);
        if (needed > dictionary.bytes.capacity) {
            const grown = std.math.add(usize, dictionary.bytes.capacity, dictionary.bytes.capacity / 2 + 8) catch dictionary.dictionary_size;
            try dictionary.bytes.ensureTotalCapacityPrecise(self.budget.allocator(), @min(dictionary.dictionary_size, @max(needed, grown)));
        }
    }

    const Probe = struct {
        state: std.compress.lzma.Decode,
        range: std.compress.lzma.RangeDecoder,
        consumed: usize,
        end_marker: bool,
    };

    /// A small enclosing-format guard cannot justify mutating a partial
    /// symbol. Only its active literal context can be touched by process(),
    /// so shadow that row and all inline state; history stays read-only.
    fn probeSymbol(self: *Decoder) !Probe {
        const original = self.decoder.?;
        const dictionary = &self.dictionary.?;
        const properties = original.properties;
        const previous: usize = dictionary.lastOr(0);
        const context = ((dictionary.len & ((@as(usize, 1) << properties.lp) - 1)) << properties.lc) +
            (previous >> @intCast(8 - @as(usize, properties.lc)));
        var probabilities: [0x300]u16 = undefined;
        @memcpy(&probabilities, original.literal_probs.data[context * probabilities.len ..][0..probabilities.len]);
        var state = original;
        state.literal_probs = .{ .data = &probabilities, .cols = probabilities.len };
        state.properties.lc = 0;
        state.properties.lp = 0;
        var range = self.range_decoder.?;
        var history = ProbeHistory{
            .original = dictionary,
            .len = dictionary.len,
            .output_limit = dictionary.output_limit,
            .allow_partial = dictionary.allow_partial,
        };
        var output: [options_mod.max_symbol_output]u8 = undefined;
        var staging: std.Io.Writer.Allocating = .{
            .allocator = self.budget.allocator(),
            .writer = .fixed(&output),
            .alignment = .of(u8),
        };
        var reader: std.Io.Reader = .fixed(self.compressed.items[self.compressed_start..]);
        var bytes_read: u64 = 0;
        const status = try state.process(&reader, &staging, &history, &range, &bytes_read);
        // An EOS commit may use this inline copy, but must never install the
        // row's stack address or its temporary row-selector properties.
        state.literal_probs = original.literal_probs;
        state.properties = original.properties;
        return .{ .state = state, .range = range, .consumed = reader.seek, .end_marker = status == .finished };
    }

    fn mapProcessError(self: *const Decoder, err: anyerror) Error {
        return switch (err) {
            error.EndOfStream => if (self.input_finished) error.TruncatedFrame else error.InvalidLzmaStream,
            error.OutputLimitExceeded => if (self.declared_size != null or self.options.expected_output_len != null) error.SizeMismatch else error.OutputLimitExceeded,
            error.OutOfMemory, error.WriteFailed => error.OutOfMemory,
            error.Overflow => error.IntegerOverflow,
            else => error.InvalidLzmaStream,
        };
    }

    fn ensureCompressed(
        self: *Decoder,
        target: usize,
        input: []const u8,
        input_read: *usize,
    ) Error!bool {
        if (self.bufferedCompressedLen() >= target) return true;
        self.compactCompressed();
        const take = @min(target - self.bufferedCompressedLen(), input.len - input_read.*);
        if (take != 0) {
            if (self.bufferedCompressedLen() + take > self.options.max_compressed_buffer_len)
                return error.OutputLimitExceeded;
            try self.compressed.ensureTotalCapacityPrecise(self.budget.allocator(), self.compressed.items.len + take);
            self.compressed.appendSliceAssumeCapacity(input[input_read.*..][0..take]);
            input_read.* += take;
            self.input_read += take;
        }
        return self.bufferedCompressedLen() >= target;
    }

    fn appendCompressedGuard(
        self: *Decoder,
        guard_len: usize,
        input: []const u8,
        input_read: *usize,
    ) Error!void {
        self.compactCompressed();
        const buffered = self.bufferedCompressedLen();
        if (buffered >= self.options.max_compressed_buffer_len)
            return error.OutputLimitExceeded;
        const target = @min(guard_len, self.options.max_compressed_buffer_len);
        if (target <= buffered) return error.OutputLimitExceeded;
        const take = @min(target - buffered, input.len - input_read.*);
        if (take == 0) return error.OutputLimitExceeded;
        try self.compressed.ensureTotalCapacityPrecise(self.budget.allocator(), self.compressed.items.len + take);
        self.compressed.appendSliceAssumeCapacity(input[input_read.*..][0..take]);
        input_read.* += take;
        self.input_read += take;
    }

    fn advanceCompressed(self: *Decoder, count: usize) void {
        std.debug.assert(count <= self.bufferedCompressedLen());
        self.compressed_start += count;
        if (self.compressed_start == self.compressed.items.len) {
            self.compressed.clearRetainingCapacity();
            self.compressed_start = 0;
        }
    }

    fn compactCompressed(self: *Decoder) void {
        if (self.compressed_start == 0) return;
        const remaining = self.compressed.items.len - self.compressed_start;
        std.mem.copyForwards(
            u8,
            self.compressed.items[0..remaining],
            self.compressed.items[self.compressed_start..],
        );
        self.compressed.items.len = remaining;
        self.compressed_start = 0;
    }

    fn bufferedCompressedLen(self: *const Decoder) usize {
        return self.compressed.items.len - self.compressed_start;
    }

    fn recordError(self: *Decoder, phase: Phase, err: Error) void {
        self.failure = err;
        self.last_error_name = @errorName(err);
        self.last_error_phase = phase;
        self.error_input_offset = self.input_read;
        self.error_output_offset = self.output_written;
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
    }
};

/// process() never reads history again after appending its single symbol.
/// Validate exactly like CircularBuffer and count the shadow output, while
/// preserving the original bytes, cursor, and sparse allocation state.
const ProbeHistory = struct {
    original: *const lzma_decoder.CircularBuffer,
    len: usize,
    output_limit: usize,
    allow_partial: bool,

    pub fn lastOr(self: ProbeHistory, default: u8) u8 {
        return self.original.lastOr(default);
    }
    pub fn lastN(self: ProbeHistory, distance: usize) !u8 {
        return self.original.lastN(distance);
    }
    pub fn appendLiteral(self: *ProbeHistory, allocator: std.mem.Allocator, byte: u8, writer: *std.Io.Writer) !void {
        _ = allocator;
        if (self.len >= self.output_limit) return error.OutputLimitExceeded;
        try writer.writeByte(byte);
        self.len += 1;
    }
    pub fn appendLz(self: *ProbeHistory, allocator: std.mem.Allocator, length: usize, distance: usize, writer: *std.Io.Writer) !void {
        _ = allocator;
        if (distance == 0 or distance > self.original.dictionary_size or distance > self.len) return error.CorruptInput;
        const remaining = self.output_limit -| self.len;
        if (!self.allow_partial and length > remaining) return error.OutputLimitExceeded;
        const take = @min(length, remaining);
        for (0..take) |_| try writer.writeByte(0);
        self.len += take;
    }
};
