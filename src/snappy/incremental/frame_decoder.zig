const std = @import("std");
const core = @import("../../core.zig");
const working = @import("../../io/working_allocator.zig");
const raw = @import("block_decoder.zig");

/// Framed Snappy validates complete compressed tokens and the masked CRC before
/// publishing. Only encoded chunk storage and the largest copy dependency are
/// retained; identifier/skippable payloads consume caller input directly.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        budget: working.WorkingAllocator,
        phase: Phase = .header,
        header: [4]u8 = undefined,
        header_len: usize = 0,
        chunk_type: u8 = 0,
        chunk_len: usize = 0,
        chunk_received: usize = 0,
        chunk: std.ArrayList(u8) = .empty,
        cursor: raw.Cursor = .{},
        decoded_offset: usize = 0,
        decoded_len: usize = 0,
        saw_identifier: bool = false,
        input_finished: bool = false,
        total_output: usize = 0,
        stream_output: usize = 0,
        stream_count: usize = 0,
        input_read: usize = 0,
        total_input_read: usize = 0,
        skippable_output: []u8 = &.{},
        skippable_written: usize = 0,
        skippable_total: usize = 0,
        skippable_events: []SkippableEvent = &.{},
        skippable_event_count: usize = 0,
        skippable_captured: usize = 0,
        failure: ?Error = null,
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .header,
        error_input_offset: ?usize = null,
        error_output_offset: ?usize = null,
        last_step_progress: core.Progress = .{},

        const Self = @This();
        pub const Error = Codec.Error || raw.Error || error{WorkingMemoryLimitExceeded};
        pub const Options = struct {
            max_chunk_payload_len: usize = 0x00ff_ffff,
            /// Output allowance for one caller-delimited member.
            max_output_len: usize = std.math.maxInt(usize),
            /// Cumulative output allowance, preserved/narrowed by nextStream.
            max_total_output_len: usize = std.math.maxInt(usize),
            /// All live requested allocations, including retained capacities.
            max_working_memory: usize = std.math.maxInt(usize),
            expected_output_len: ?usize = null,
            skippable_output: []u8 = &.{},
            skippable_events: []SkippableEvent = &.{},

            pub fn validate(self: Options) Error!void {
                if (self.expected_output_len) |expected|
                    if (expected > self.max_output_len or expected > self.max_total_output_len) return error.InvalidBlockPlan;
            }
        };
        pub const SkippableEvent = struct { chunk_type: u8, payload_len: usize };
        pub const Phase = enum { header, payload, output, done };
        pub const Snapshot = struct {
            phase: Phase,
            header_received: usize,
            chunk_payload_received: usize,
            chunk_payload_expected: usize,
            output_written: usize,
            payload_remaining: usize,
            saw_identifier: bool,
            total_output: usize,
            stream_count: usize,
            stream_index: usize,
            input_read: usize,
            total_input_read: usize,
            skippable_written: usize,
            skippable_total: usize,
            skippable_truncated: bool,
            skippable_event_count: usize,
            skippable_events_captured: usize,
            retained_chunk_capacity: usize,
            history_capacity: usize,
            retained_decoded_capacity: usize,
            working_bytes: usize,
            peak_working_bytes: usize,
            last_step_progress: core.Progress,
            error_input_offset: ?usize,
            error_output_offset: ?usize,
            last_error_name: []const u8,
            last_error_phase: Phase,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options, .budget = working.WorkingAllocator.init(allocator, options.max_working_memory), .skippable_output = options.skippable_output, .skippable_events = options.skippable_events };
        }
        pub fn deinit(self: *Self) void {
            self.chunk.deinit(self.budget.allocator());
            self.cursor.deinit(self.budget.allocator());
            std.debug.assert(self.budget.live == 0);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            var chunk = self.chunk;
            var cursor = self.cursor;
            var budget = self.budget;
            chunk.clearRetainingCapacity();
            cursor.reset(.{ .decoded_len = 0, .body_offset = 0, .max_offset = 0 });
            budget.peak = budget.live;
            budget.hit_limit = false;
            budget.last_failure_was_limit = false;
            self.* = initWithOptions(self.allocator, self.options);
            self.chunk = chunk;
            self.cursor = cursor;
            self.budget = budget;
        }
        pub fn resetWithOptions(self: *Self, options: Options) Error!void {
            try options.validate();
            const allocator = self.allocator;
            self.deinit();
            self.* = initWithOptions(allocator, options);
        }
        pub fn nextStream(self: *Self, options: Options) Error!void {
            if (self.phase != .done or self.failure != null) return error.InvalidBlockPlan;
            var effective = options;
            effective.max_total_output_len = @min(self.options.max_total_output_len, options.max_total_output_len);
            effective.max_working_memory = @min(self.budget.limit, options.max_working_memory);
            try effective.validate();
            if (self.stream_output > effective.max_total_output_len) return error.OutputLimitExceeded;
            if (self.budget.live > effective.max_working_memory) return error.WorkingMemoryLimitExceeded;
            if (effective.expected_output_len) |expected|
                if (expected > effective.max_total_output_len - self.stream_output) return error.InvalidBlockPlan;
            const cumulative_output = self.stream_output;
            const count = self.stream_count;
            const input = self.total_input_read;
            const peak = self.budget.peak;
            self.reset();
            self.options = effective;
            self.budget.limit = effective.max_working_memory;
            // reset starts a new session; nextStream preserves its resource and
            // publication ledger, including the previous highwater allocation.
            self.stream_output = cumulative_output;
            self.stream_count = count;
            self.total_input_read = input;
            self.budget.peak = @max(peak, self.budget.live);
            self.skippable_output = effective.skippable_output;
            self.skippable_events = effective.skippable_events;
        }
        pub fn workingMemoryBytes(self: *const Self) usize {
            return self.budget.live;
        }
        pub fn peakWorkingMemoryBytes(self: *const Self) usize {
            return self.budget.peak;
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .header_received = self.header_len,
                .chunk_payload_received = self.chunk_received,
                .chunk_payload_expected = self.chunk_len,
                .output_written = self.total_output,
                .payload_remaining = self.decoded_len - self.decoded_offset,
                .saw_identifier = self.saw_identifier,
                .total_output = self.stream_output + if (self.phase == .done) 0 else self.total_output,
                .stream_count = self.stream_count,
                .stream_index = if (self.phase == .done and self.stream_count != 0) self.stream_count - 1 else self.stream_count,
                .input_read = self.input_read,
                .total_input_read = self.total_input_read,
                .skippable_written = self.skippable_written,
                .skippable_total = self.skippable_total,
                .skippable_truncated = self.skippable_written != self.skippable_total,
                .skippable_event_count = self.skippable_event_count,
                .skippable_events_captured = @min(self.skippable_event_count, self.skippable_events.len),
                .retained_chunk_capacity = self.chunk.capacity,
                .history_capacity = self.cursor.historyCapacity(),
                .retained_decoded_capacity = 0,
                .working_bytes = self.budget.live,
                .peak_working_bytes = self.budget.peak,
                .last_step_progress = self.last_step_progress,
                .error_input_offset = self.error_input_offset,
                .error_output_offset = self.error_output_offset,
                .last_error_name = self.last_error_name,
                .last_error_phase = self.last_error_phase,
            };
        }
        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            const snap = self.snapshot();
            return .{
                .phase_name = @tagName(snap.phase),
                .input_read = self.total_input_read,
                .frame_input_read = self.input_read,
                .header_received = self.header_len,
                .output_written = snap.output_written,
                .expected_output_len = self.options.expected_output_len,
                .payload_remaining = snap.payload_remaining,
                .last_error_name = self.last_error_name,
                .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
                .last_step_progress = self.last_step_progress,
                .error_input_offset = self.error_input_offset,
                .error_output_offset = self.error_output_offset,
                .recoverability_hint_name = if (std.mem.eql(u8, self.last_error_name, "TruncatedFrame")) "truncated_input" else if (std.mem.eql(u8, self.last_error_name, "WorkingMemoryLimitExceeded")) "raise_working_memory_limit" else if (std.mem.eql(u8, self.last_error_name, "OutOfMemory")) "allocation_failure" else if (self.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }
        /// Invalid/short input boundaries remain recoverable and do not seal
        /// input. A validated chunk awaiting output is a valid end position.
        pub fn finish(self: *Self) Error!void {
            if (self.failure) |err| return err;
            self.last_error_name = "";
            self.error_input_offset = null;
            self.error_output_offset = null;
            if (self.phase == .done) return;
            if (!self.saw_identifier or self.phase == .payload or self.header_len != 0) {
                self.recordError(error.TruncatedFrame);
                return error.TruncatedFrame;
            }
            const final_size = std.math.add(usize, self.total_output, self.decoded_len - self.decoded_offset) catch return error.IntegerOverflow;
            if (self.options.expected_output_len) |expected| {
                if (final_size != expected) {
                    self.recordError(error.SizeMismatch);
                    return error.SizeMismatch;
                }
            }
            self.input_finished = true;
            if (self.phase == .header) {
                self.phase = .done;
                self.completeStream();
            }
        }
        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            self.last_step_progress = .{};
            if (self.failure) |err| return err;
            self.last_error_name = "";
            self.error_input_offset = null;
            self.error_output_offset = null;
            self.budget.last_failure_was_limit = false;
            const before_input = self.total_input_read;
            const before_output = self.total_output;
            const decoded = self.stepChecked(input, output) catch |original| {
                const err = if (original == error.OutOfMemory and self.budget.last_failure_was_limit) error.WorkingMemoryLimitExceeded else original;
                self.last_step_progress = .{ .input_read = self.total_input_read - before_input, .output_written = self.total_output - before_output };
                self.recordError(err);
                self.failure = err;
                return err;
            };
            self.last_step_progress = decoded.progress;
            return decoded;
        }
        fn stepChecked(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (input.len > std.math.maxInt(usize) - self.total_input_read) return error.IntegerOverflow;
            try self.options.validate();
            if (self.phase == .done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if (self.input_finished and input.len != 0) return error.TrailingData;
            var read: usize = 0;
            var written: usize = 0;
            while (true) {
                if (self.phase == .output) {
                    if (self.chunk_type == Codec.uncompressed_data_chunk_type) {
                        const n = @min(output.len - written, self.decoded_len - self.decoded_offset);
                        @memcpy(output[written..][0..n], self.chunk.items[4 + self.decoded_offset ..][0..n]);
                        self.decoded_offset += n;
                        self.total_output += n;
                        written += n;
                    } else {
                        const before = self.cursor.decoded_written;
                        const decoded = self.cursor.step(self.budget.allocator(), self.chunk.items[4..], output[written..]) catch |err| {
                            const published = self.cursor.decoded_written - before;
                            self.decoded_offset += published;
                            self.total_output += published;
                            return err;
                        };
                        self.decoded_offset += decoded.output_written;
                        self.total_output += decoded.output_written;
                        written += decoded.output_written;
                    }
                    if (self.decoded_offset != self.decoded_len) return result(read, written, .need_output);
                    self.chunk.clearRetainingCapacity();
                    self.cursor.reset(.{ .decoded_len = 0, .body_offset = 0, .max_offset = 0 });
                    self.decoded_offset = 0;
                    self.decoded_len = 0;
                    self.phase = .header;
                    if (self.input_finished) {
                        self.phase = .done;
                        self.completeStream();
                        return result(read, written, .done);
                    }
                }
                if (self.phase == .header) {
                    const n = @min(4 - self.header_len, input.len - read);
                    @memcpy(self.header[self.header_len..][0..n], input[read..][0..n]);
                    self.header_len += n;
                    self.noteInput(n);
                    read += n;
                    if (self.header_len != 4) return result(read, written, .need_input);
                    self.chunk_type = self.header[0];
                    self.chunk_len = Codec.readChunkLen(self.header[1..4]);
                    self.header_len = 0;
                    self.chunk_received = 0;
                    if (self.chunk_len > self.options.max_chunk_payload_len) return error.OutputLimitExceeded;
                    if (self.chunk_type == Codec.stream_identifier_chunk_type) {
                        if (self.chunk_len != Codec.stream_identifier_payload.len) return error.InvalidMagic;
                    } else {
                        if (!self.isData() and self.chunk_type < Codec.min_skippable_chunk_type) return error.UnsupportedSnappyFeature;
                        if (!self.saw_identifier) return error.InvalidMagic;
                    }
                    self.chunk.clearRetainingCapacity();
                    self.skippable_captured = 0;
                    if (self.isData()) try self.chunk.ensureTotalCapacityPrecise(self.budget.allocator(), self.chunk_len);
                    self.phase = .payload;
                }
                if (self.phase == .payload) {
                    const n = @min(self.chunk_len - self.chunk_received, input.len - read);
                    const bytes = input[read..][0..n];
                    if (self.isData()) {
                        self.chunk.appendSliceAssumeCapacity(bytes);
                    } else if (self.chunk_type == Codec.stream_identifier_chunk_type) {
                        for (bytes) |byte| {
                            const index = self.chunk_received;
                            self.chunk_received += 1;
                            self.noteInput(1);
                            read += 1;
                            if (byte != Codec.stream_identifier_payload[index]) return error.InvalidMagic;
                        }
                    } else {
                        const offset = self.skippable_written + self.skippable_captured;
                        const copy_len = @min(bytes.len, self.skippable_output.len -| offset);
                        @memcpy(self.skippable_output[offset..][0..copy_len], bytes[0..copy_len]);
                        self.skippable_captured += copy_len;
                    }
                    if (self.chunk_type != Codec.stream_identifier_chunk_type) {
                        self.noteInput(n);
                        read += n;
                        self.chunk_received += n;
                    }
                    if (self.chunk_received != self.chunk_len) return result(read, written, .need_input);
                    try self.processChunk();
                    if (self.phase == .output) continue;
                    self.phase = .header;
                    if (read == input.len) return result(read, written, .need_input);
                }
            }
        }
        fn isData(self: *const Self) bool {
            return self.chunk_type == Codec.compressed_data_chunk_type or self.chunk_type == Codec.uncompressed_data_chunk_type;
        }
        fn processChunk(self: *Self) Error!void {
            if (self.chunk_type == Codec.stream_identifier_chunk_type) {
                self.saw_identifier = true;
                return;
            }
            if (!self.isData()) {
                self.skippable_written += self.skippable_captured;
                self.skippable_total += self.chunk_len;
                if (self.skippable_event_count < self.skippable_events.len) self.skippable_events[self.skippable_event_count] = .{ .chunk_type = self.chunk_type, .payload_len = self.chunk_len };
                self.skippable_event_count += 1;
                return;
            }
            const payload = self.chunk.items;
            if (payload.len < 4) return error.TruncatedFrame;
            const expected = std.mem.readInt(u32, payload[0..4], .little);
            if (self.chunk_type == Codec.uncompressed_data_chunk_type) {
                const n = payload.len - 4;
                if (n > Codec.max_uncompressed_chunk_len) return error.CorruptFrame;
                try self.reserveOutput(n);
                try Codec.verifyChecksum(payload[4..], expected);
                self.decoded_len = n;
            } else {
                const block = payload[4..];
                const block_plan = try raw.plan(block);
                if (block_plan.decoded_len > Codec.max_uncompressed_chunk_len) return error.CorruptFrame;
                try self.reserveOutput(block_plan.decoded_len);
                self.cursor.reset(block_plan);
                var crc = std.hash.crc.Crc32Iscsi.init();
                var scratch: [256]u8 = undefined;
                while (true) {
                    const scanned = try self.cursor.step(self.budget.allocator(), block, &scratch);
                    crc.update(scratch[0..scanned.output_written]);
                    if (scanned.done) break;
                }
                try Codec.verifyChecksumHash(crc.final(), expected);
                self.cursor.reset(block_plan);
                self.decoded_len = block_plan.decoded_len;
            }
            self.decoded_offset = 0;
            self.phase = .output;
        }
        fn reserveOutput(self: *const Self, n: usize) Error!void {
            const member = std.math.add(usize, self.total_output, n) catch return error.IntegerOverflow;
            if (member > self.options.max_output_len) return error.OutputLimitExceeded;
            const cumulative = std.math.add(usize, self.stream_output, member) catch return error.IntegerOverflow;
            if (cumulative > self.options.max_total_output_len) return error.OutputLimitExceeded;
            if (self.options.expected_output_len) |expected|
                if (member > expected) return error.SizeMismatch;
        }
        fn noteInput(self: *Self, n: usize) void {
            self.input_read += n;
            self.total_input_read += n;
        }
        fn completeStream(self: *Self) void {
            self.stream_output += self.total_output;
            self.stream_count += 1;
        }
        fn recordError(self: *Self, err: Error) void {
            self.last_error_name = @errorName(err);
            self.last_error_phase = self.phase;
            self.error_input_offset = self.total_input_read;
            self.error_output_offset = self.stream_output + if (self.phase == .done) 0 else self.total_output;
        }
        fn result(read: usize, written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = read, .output_written = written }, .status = status };
        }
    };
}
