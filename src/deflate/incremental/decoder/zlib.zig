const std = @import("std");
const core = @import("../../../core.zig");
const count = core.stream_count;
const Count = core.StreamCount;
const member_prefix = @import("member_prefix.zig");
const wrapper_count = @import("wrapper_count.zig");
const clone_storage = @import("../clone_storage.zig");
const step_borrows = @import("step_borrows.zig");
const dictionary_borrows = @import("dictionary_borrows.zig");

/// Incremental zlib wrapper around the raw stored/fixed/dynamic decoder. The
/// raw decoder stops at the final DEFLATE block and leaves the Adler footer
/// unconsumed for this wrapper.
pub fn Decoder(comptime Codec: type) type {
    return struct {
        options: Options,
        raw: Codec.RawDecoder,
        phase: Phase = .header,
        /// One-shot request set by `stepToBlockBoundary`; only the raw deflate
        /// payload honors it, and it is cleared when the step returns.
        pause_requested: bool = false,
        header: [2]u8 = undefined,
        header_received: usize = 0,
        footer: [4]u8 = undefined,
        footer_received: usize = 0,
        dictid: [4]u8 = undefined,
        dictid_received: usize = 0,
        required_dictionary_id: ?u32 = null,
        dictionary: []const u8 = &.{},
        dictionary_available: bool = false,
        dictionaries: ?Codec.DictionarySet = null,
        adler: Codec.Adler32 = Codec.Adler32.init(),
        input_finished: bool = false,
        total_input: Count = 0,
        total_output: Count = 0,
        stream_output: Count = 0,
        stream_count: Count = 0,
        stream_offset: Count = 0,
        member_end_offset: ?Count = null,
        next_member_prefix: member_prefix.Prefix = member_prefix.Prefix.init(),
        last_error_name: []const u8 = "",
        last_error_phase: Phase = .header,
        last_error_stream_index: ?Count = null,
        last_error_stream_offset: ?Count = null,
        last_error_input_offset: ?Count = null,
        last_error_output_offset: ?Count = null,
        last_step_progress: core.Progress = .{},

        const Self = @This();
        pub const Error = Codec.Error;
        pub const CloneError = Codec.RawDecoder.CloneError;
        pub const CloneStorage = Codec.RawDecoder.CloneStorage;
        pub const Options = struct {
            max_output_len: Count = std.math.maxInt(Count),
            expected_output_len: ?Count = null,
            allow_concatenated: bool = false,
            /// Ignore the Adler comparison while still reading a full footer
            /// and maintaining the checksum of all produced bytes.
            ignore_adler: bool = false,
            /// Leave a nonmember suffix unconsumed. With concatenation, commit
            /// to the next member after its complete CMF/FLG pair is valid.
            allow_trailing_data: bool = false,
        };
        pub const Phase = enum { header, dictid, raw, footer, between_streams, done };
        pub const Snapshot = struct {
            phase: Phase,
            total_input: Count,
            total_output: Count,
            stream_output: Count,
            stream_count: Count,
            stream_index: Count,
            stream_offset: Count,
            stream_input: Count,
            member_end_offset: ?Count,
            trailing_prefix_len: usize,
            header_received: usize,
            dictid_received: usize,
            footer_received: usize,
            last_error_name: []const u8,
            last_error_phase: ?Phase,
            last_error_stream_index: ?Count,
            last_error_stream_offset: ?Count,
            last_error_input_offset: ?Count,
            last_error_output_offset: ?Count,
            last_step_progress: core.Progress,
            done: bool,
        };

        pub fn init(options: Options, history: []u8) Error!Self {
            return .{
                .options = options,
                .raw = try Codec.RawDecoder.initWithHistory(.{
                    .max_output_len = initialRawLimit(options),
                    .expected_output_len = if (options.allow_concatenated) null else options.expected_output_len,
                    .allow_trailing_data = true,
                }, history),
            };
        }
        pub fn cloneHistoryLen(self: *const Self) usize {
            return self.raw.cloneHistoryLen();
        }
        /// Preserve header/DICTID/footer progress and checksum state. Configured
        /// dictionaries and set entries remain immutable borrows shared by both
        /// copies until neither copy will decode or reset with that configuration.
        /// Destination, history and attached workspace must stay at stable,
        /// independent addresses. Failure leaves all caller storage unchanged.
        pub fn cloneInto(self: *const Self, destination: *Self, storage: CloneStorage) CloneError!void {
            try clone_storage.validateWrapper(self, destination, storage);
            try clone_storage.rejectDestinationOverlap(destination, storage, self.dictionary);
            if (self.dictionaries) |dictionaries| {
                try clone_storage.rejectDestinationOverlap(destination, storage, std.mem.sliceAsBytes(dictionaries.entries));
                for (dictionaries.entries) |entry|
                    try clone_storage.rejectDestinationOverlap(destination, storage, entry.bytes);
            }
            var raw_copy: Codec.RawDecoder = undefined;
            try self.raw.cloneInto(&raw_copy, storage);
            destination.* = self.*;
            destination.raw = raw_copy;
            clone_storage.rebindRaw(&destination.raw);
        }
        /// Keep the configured dictionary borrowed for DICTID validation on
        /// this stream, reset, and later concatenated members. After a member
        /// is seeded, decoding uses its copied history suffix rather than the
        /// borrowed bytes; retain the configuration for any future reuse.
        pub fn initWithDictionary(options: Options, history: []u8, dictionary: []const u8) Error!Self {
            return .{
                .options = options,
                .raw = try Codec.RawDecoder.initWithHistory(.{
                    .max_output_len = initialRawLimit(options),
                    .expected_output_len = if (options.allow_concatenated) null else options.expected_output_len,
                    .allow_trailing_data = true,
                }, history),
                .dictionary = dictionary,
                .dictionary_available = true,
            };
        }
        /// The set and its dictionary bytes remain borrowed for member lookup.
        /// A missing entry may be supplied explicitly for the current member.
        pub fn initWithDictionarySet(options: Options, history: []u8, dictionaries: Codec.DictionarySet) Error!Self {
            return .{
                .options = options,
                .raw = try Codec.RawDecoder.initWithHistory(.{
                    .max_output_len = initialRawLimit(options),
                    .expected_output_len = if (options.allow_concatenated) null else options.expected_output_len,
                    .allow_trailing_data = true,
                }, history),
                .dictionaries = dictionaries,
            };
        }
        pub fn reset(self: *Self) void {
            self.raw.reset();
            self.phase = .header;
            self.header_received = 0;
            self.footer_received = 0;
            self.dictid_received = 0;
            self.required_dictionary_id = null;
            self.adler = Codec.Adler32.init();
            self.input_finished = false;
            self.total_input = 0;
            self.total_output = 0;
            self.stream_output = 0;
            self.stream_count = 0;
            self.stream_offset = 0;
            self.member_end_offset = null;
            self.next_member_prefix.reset();
            self.configureRawForStream();
            self.clearError();
            self.last_step_progress = .{};
        }

        /// Available only after all four DICTID bytes were accepted and while
        /// that request remains unresolved. Success, reset, and a new member
        /// clear it; a partial DICTID or a stream without FDICT returns null.
        pub fn requiredDictionaryId(self: *const Self) ?u32 {
            if (self.phase != .dictid or self.dictid_received != self.dictid.len) return null;
            return self.required_dictionary_id;
        }

        /// End of the last complete member whose footer passed the configured
        /// validation. Accepted bytes probing a suffix are excluded.
        pub fn memberEndOffset(self: *const Self) ?Count {
            return self.member_end_offset;
        }

        /// A possible next header accepted on an earlier step becomes trailing
        /// data only after the probe rejects the suffix or `finish` declares EOF.
        /// Prepend these borrowed bytes to the caller's unconsumed input suffix
        /// to recover all trailing data.
        pub fn trailingPrefix(self: *const Self) []const u8 {
            if (self.phase != .done) return &.{};
            return self.next_member_prefix.bytes[0..self.next_member_prefix.received];
        }

        /// Borrow bytes only during this call, verify their Adler-32 ID, and
        /// copy the required suffix into caller-owned raw history. The bytes
        /// may be released after return: this override is not cached for reset
        /// or later members. On mismatch the same request remains resumable.
        /// Supply the unconsumed input suffix again after successful provision.
        pub fn provideDictionary(self: *Self, dictionary: []const u8) Error!void {
            const id = self.requiredDictionaryId() orelse return error.InvalidStreamState;
            if (self.input_finished) return error.InvalidStreamState;
            try dictionary_borrows.validateSeed(std.mem.asBytes(self), self.raw.history, dictionary);
            if (Codec.Adler32.hash(dictionary) != id) return self.fail(.dictid, error.DictionaryMismatch);
            try self.acceptDictionary(dictionary);
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .phase = self.phase,
                .total_input = self.total_input,
                .total_output = self.total_output,
                .stream_output = self.stream_output,
                .stream_count = self.stream_count,
                .stream_index = self.diagnosticStreamIndex(self.phase),
                .stream_offset = self.stream_offset,
                .stream_input = self.streamInput(),
                .member_end_offset = self.member_end_offset,
                .trailing_prefix_len = self.trailingPrefix().len,
                .header_received = self.header_received,
                .dictid_received = self.dictid_received,
                .footer_received = self.footer_received,
                .last_error_name = self.last_error_name,
                .last_error_phase = if (self.last_error_name.len == 0) null else self.last_error_phase,
                .last_error_stream_index = self.last_error_stream_index,
                .last_error_stream_offset = self.last_error_stream_offset,
                .last_error_input_offset = self.last_error_input_offset,
                .last_error_output_offset = self.last_error_output_offset,
                .last_step_progress = self.last_step_progress,
                .done = self.phase == .done,
            };
        }
        pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
            return .{
                .phase_name = @tagName(self.phase),
                .input_read = self.total_input,
                .header_received = self.header_received,
                .frame_input_read = self.total_input,
                .output_written = self.total_output,
                .expected_output_len = self.options.expected_output_len,
                .last_error_name = self.last_error_name,
                .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
                .error_input_offset = self.last_error_input_offset,
                .error_output_offset = self.last_error_output_offset,
                .last_step_progress = self.last_step_progress,
                .recoverability_hint_name = if (std.mem.eql(u8, self.last_error_name, @errorName(error.TruncatedFrame))) "truncated_input" else if (std.mem.eql(u8, self.last_error_name, @errorName(error.NeedDictionary)) or std.mem.eql(u8, self.last_error_name, @errorName(error.DictionaryMismatch))) "retry_with_dictionary" else if (self.last_error_name.len == 0) "none" else "payload_corrupt",
            };
        }
        /// A complete unresolved DICTID takes precedence over EOF: return
        /// NeedDictionary without sealing input, so the caller may supply the
        /// dictionary and resubmit bytes this decoder has not accepted. Call
        /// finish again after recovery and input consumption. All other finish
        /// calls seal input; nonempty input afterward is rejected.
        pub fn finish(self: *Self) Error!void {
            if (self.requiredDictionaryId() != null) return self.fail(.dictid, error.NeedDictionary);
            self.input_finished = true;
            if (self.options.allow_concatenated and self.phase == .between_streams) {
                try self.validateExpectedOutput();
                self.phase = .done;
                return;
            }
            if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
            try self.validateExpectedOutput();
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            return self.stepAdmitted(input, output, false);
        }

        fn stepAdmitted(self: *Self, input: []const u8, output: []u8, boundary: bool) Error!core.StepResult {
            const semantic_admitted = try self.admitStep(input, output);
            if (boundary) self.pause_requested = true;
            defer if (boundary) {
                self.pause_requested = false;
            };
            // Retain the attachment, while keeping an unsafe optional workspace
            // inactive for every raw drain and member transition in this call.
            const workspace = self.raw.semantic_decoder;
            if (!semantic_admitted) self.raw.semantic_decoder = null;
            defer self.raw.semantic_decoder = workspace;
            self.last_step_progress = .{};
            const before = wrapper_count.Before.init(self.total_input, self.total_output);
            const stepped = self.stepInternal(input, output) catch |err| {
                self.last_step_progress = try before.progress(self.total_input, self.total_output);
                return self.fail(self.phase, err);
            };
            self.last_step_progress = stepped.progress;
            return stepped;
        }

        /// Advance through wrapper header/dictionary phases until the next
        /// compressed-block boundary, an input/output wait, or completion.
        /// `block_boundary` reports a stop between blocks with remaining input.
        pub fn stepToBlockBoundary(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            return self.stepAdmitted(input, output, true);
        }
        pub fn atBlockBoundary(self: *const Self) bool {
            return self.phase == .done or (self.phase == .raw and self.raw.atBlockBoundary());
        }

        fn admitStep(self: *const Self, input: []const u8, output: []u8) Error!bool {
            const writers = if (self.input_finished or self.phase == .done)
                output[0..0]
            else
                step_borrows.outputPrefix(self.options, self.total_output, output);
            const receiver = std.mem.asBytes(self);
            var admitted = try step_borrows.rawAdmission(receiver, &self.raw, input, writers);
            if (self.dictionary_available) {
                const dictionary_admitted = try step_borrows.dictionaryAdmission(receiver, &self.raw, writers, self.dictionary);
                admitted = admitted and dictionary_admitted;
            }
            if (self.dictionaries) |dictionaries| {
                const set_admitted = try step_borrows.setAdmission(receiver, &self.raw, writers, dictionaries);
                admitted = admitted and set_admitted;
            }
            return admitted;
        }

        fn stepInternal(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.input_finished) {
                if (input.len != 0) return self.fail(self.phase, error.TrailingData);
                if (self.phase != .done) return self.fail(self.phase, error.TruncatedFrame);
                return .{ .status = .done };
            }
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) switch (self.phase) {
                .header => {
                    const n = @min(self.header.len - self.header_received, input.len - input_read);
                    if (n != 0) {
                        const next_input = try count.addLocal(self.total_input, n);
                        @memcpy(self.header[self.header_received..][0..n], input[input_read..][0..n]);
                        self.header_received += n;
                        input_read += n;
                        self.total_input = next_input;
                    }
                    if (self.header_received != self.header.len) return result(input_read, output_written, .need_input);
                    try self.validateHeader();
                    self.phase = if ((self.header[1] & 0x20) != 0) .dictid else .raw;
                },
                .dictid => {
                    const n = @min(self.dictid.len - self.dictid_received, input.len - input_read);
                    if (n != 0) {
                        const next_input = try count.addLocal(self.total_input, n);
                        @memcpy(self.dictid[self.dictid_received..][0..n], input[input_read..][0..n]);
                        self.dictid_received += n;
                        input_read += n;
                        self.total_input = next_input;
                    }
                    if (self.dictid_received != self.dictid.len) return result(input_read, output_written, .need_input);
                    const id = std.mem.readInt(u32, &self.dictid, .big);
                    self.required_dictionary_id = id;
                    if (self.dictionaries) |dictionaries| {
                        if (dictionaries.find(id)) |dictionary| {
                            if (Codec.Adler32.hash(dictionary) == id) {
                                try self.acceptDictionary(dictionary);
                                continue;
                            }
                        }
                    } else if (self.dictionary_available and id == Codec.Adler32.hash(self.dictionary)) {
                        try self.acceptDictionary(self.dictionary);
                        continue;
                    }
                    return self.fail(.dictid, error.NeedDictionary);
                },
                .raw => {
                    // Drain the raw bit reservoir before supplying another byte.
                    // In particular, when the caller's output slice filled
                    // exactly on the final literal/match, the EOB may already
                    // be buffered and can advance us to the Adler footer
                    // without asking for an unnecessary extra output buffer.
                    const drained = try self.stepRaw("", output, &input_read, &output_written);
                    if (drained.status == .done) {
                        self.phase = .footer;
                        continue;
                    }
                    if (drained.status == .need_output) {
                        // A match copy can fill this output slice exactly and
                        // then return need_output after normalizing back to the
                        // symbol phase. Re-enter once to let an already-buffered
                        // EOB advance to the footer; zero-progress need_output
                        // below is the real request for caller space.
                        if (drained.progress.output_written != 0) continue;
                        if (self.remainingRawLimit() == 0) return self.fail(.raw, self.cumulativeLimitError());
                        return result(input_read, output_written, .need_output);
                    }
                    if (drained.block_boundary) {
                        var paused = result(input_read, output_written, .need_input);
                        paused.block_boundary = true;
                        return paused;
                    }
                    if (input_read == input.len) return result(input_read, output_written, .need_input);

                    const supplied = try self.stepRaw(input[input_read..], output, &input_read, &output_written);
                    if (supplied.status == .done) {
                        self.phase = .footer;
                        continue;
                    }
                    if (supplied.block_boundary) {
                        var paused = result(input_read, output_written, .need_input);
                        paused.block_boundary = true;
                        return paused;
                    }
                    if (supplied.status == .need_output) continue;
                    if (input_read == input.len) return result(input_read, output_written, .need_input);
                },
                .footer => {
                    const n = @min(self.footer.len - self.footer_received, input.len - input_read);
                    if (n != 0) {
                        const next_input = try count.addLocal(self.total_input, n);
                        @memcpy(self.footer[self.footer_received..][0..n], input[input_read..][0..n]);
                        self.footer_received += n;
                        input_read += n;
                        self.total_input = next_input;
                    }
                    if (self.footer_received != self.footer.len) return result(input_read, output_written, .need_input);
                    try Codec.validateFooter(self.footer, self.adler.digest(), self.options.ignore_adler);
                    try count.advance(&self.stream_count, 1);
                    self.member_end_offset = self.total_input;
                    self.next_member_prefix.reset();
                    self.phase = if (self.options.allow_concatenated) .between_streams else .done;
                },
                .between_streams => {
                    if (input_read == input.len) return result(input_read, output_written, .need_input);
                    if (self.options.allow_trailing_data) {
                        const probed = try wrapper_count.probe(&self.next_member_prefix, .zlib, &self.total_input, input[input_read..]);
                        input_read += probed.accepted;
                        switch (probed.decision) {
                            .need_input => return result(input_read, output_written, .need_input),
                            .trailing => {
                                self.phase = .done;
                                return result(input_read, output_written, .done);
                            },
                            .member => {
                                self.beginStream();
                                self.stream_offset = self.total_input - count.fromLocal(self.header.len);
                                self.header = self.next_member_prefix.bytes;
                                self.header_received = self.header.len;
                                self.next_member_prefix.reset();
                                continue;
                            },
                        }
                    }
                    self.beginStream();
                },
                .done => {
                    if (!self.options.allow_trailing_data and input_read != input.len) return self.fail(.done, error.TrailingData);
                    return result(input_read, output_written, .done);
                },
            };
        }

        fn validateHeader(self: *Self) Error!void {
            const cmf = self.header[0];
            const flg = self.header[1];
            if ((cmf & 0x0f) != 8 or (cmf >> 4) > 7) return self.fail(.header, error.BadZlibHeader);
            if ((@as(u16, cmf) << 8 | flg) % 31 != 0) return self.fail(.header, error.BadZlibHeader);
        }
        fn beginStream(self: *Self) void {
            self.raw.reset();
            self.configureRawForStream();
            self.phase = .header;
            self.header_received = 0;
            self.footer_received = 0;
            self.dictid_received = 0;
            self.required_dictionary_id = null;
            self.dictionary = if (self.dictionaries == null) self.dictionary else "";
            self.adler = Codec.Adler32.init();
            self.stream_output = 0;
            self.stream_offset = self.total_input;
        }
        fn configureRawForStream(self: *Self) void {
            self.raw.options.max_output_len = self.remainingRawLimit();
            self.raw.options.expected_output_len = if (self.options.allow_concatenated) null else self.options.expected_output_len;
        }
        fn remainingRawLimit(self: *const Self) Count {
            return rawLimit(self.options, self.total_output);
        }
        fn validateExpectedOutput(self: *Self) Error!void {
            if (self.options.expected_output_len) |expected|
                if (self.total_output != expected) return self.fail(self.phase, error.SizeMismatch);
        }
        fn acceptDictionary(self: *Self, dictionary: []const u8) Error!void {
            try self.raw.seedDictionary(dictionary);
            self.required_dictionary_id = null;
            self.phase = .raw;
            self.clearError();
        }
        fn clearError(self: *Self) void {
            self.last_error_name = "";
            self.last_error_phase = .header;
            self.last_error_stream_index = null;
            self.last_error_stream_offset = null;
            self.last_error_input_offset = null;
            self.last_error_output_offset = null;
        }
        fn stepRaw(self: *Self, input: []const u8, output: []u8, input_read: *usize, output_written: *usize) Error!core.StepResult {
            // Raw decoding may consume input or write output before returning
            // an error. Bound both windows before handing them to the raw state.
            const supplied = wrapper_count.inputWindow(self.total_input, input);
            const available_output = output[output_written.*..];
            const destination = wrapper_count.outputWindow(self.total_output, self.stream_output, available_output);
            const before = wrapper_count.Before.init(self.raw.total_input, self.raw.total_output);
            const stepped = (if (self.pause_requested)
                self.raw.stepToBlockBoundary(supplied, destination)
            else
                self.raw.step(supplied, destination)) catch |err| {
                const partial: core.StepResult = .{ .progress = try before.progress(self.raw.total_input, self.raw.total_output) };
                try self.recordRawProgress(partial, output, input_read, output_written);
                return self.failRaw(err);
            };
            try self.recordRawProgress(stepped, output, input_read, output_written);
            if (stepped.status == .need_input and supplied.len < input.len and stepped.progress.input_read == supplied.len)
                return error.IntegerOverflow;
            // Re-enter once after a nonempty copy so a buffered EOB can still
            // complete a stream whose last byte filled the counter exactly.
            if (stepped.status == .need_output and stepped.progress.output_written == 0 and
                (self.total_output == std.math.maxInt(Count) or self.stream_output == std.math.maxInt(Count)))
                return error.IntegerOverflow;
            return stepped;
        }
        fn recordRawProgress(self: *Self, raw_result: core.StepResult, output: []const u8, input_read: *usize, output_written: *usize) Error!void {
            const next_input = try count.addLocal(self.total_input, raw_result.progress.input_read);
            const next_output = try count.addLocal(self.total_output, raw_result.progress.output_written);
            const next_member_output = try count.addLocal(self.stream_output, raw_result.progress.output_written);
            input_read.* += raw_result.progress.input_read;
            self.total_input = next_input;
            if (raw_result.progress.output_written == 0) return;
            const produced = output[output_written.*..][0..raw_result.progress.output_written];
            self.adler.update(produced);
            output_written.* += produced.len;
            self.total_output = next_output;
            self.stream_output = next_member_output;
        }
        fn cumulativeLimitError(self: *const Self) Error {
            if (self.options.expected_output_len) |expected| {
                if (expected <= self.options.max_output_len) return error.SizeMismatch;
            }
            return error.OutputLimitExceeded;
        }
        fn failRaw(self: *Self, err: Error) Error {
            // In concatenated mode the raw decoder's per-stream limit is the
            // remaining cumulative allowance. Reaching a caller-pledged exact
            // size is a size mismatch, not a configured safety-limit failure.
            if (self.options.allow_concatenated and err == error.OutputLimitExceeded)
                return self.fail(.raw, self.cumulativeLimitError());
            return self.fail(.raw, err);
        }
        fn diagnosticStreamIndex(self: *const Self, phase: Phase) Count {
            if ((phase == .between_streams or phase == .done) and self.stream_count != 0) return self.stream_count - 1;
            return self.stream_count;
        }
        fn streamInput(self: *const Self) Count {
            const end = if (self.phase == .between_streams or self.phase == .done)
                self.member_end_offset orelse self.total_input
            else
                self.total_input;
            return end - self.stream_offset;
        }
        fn fail(self: *Self, phase: Phase, err: Error) Error {
            self.last_error_name = @errorName(err);
            self.last_error_phase = phase;
            self.last_error_stream_index = self.diagnosticStreamIndex(phase);
            self.last_error_stream_offset = self.stream_offset;
            self.last_error_input_offset = self.total_input;
            self.last_error_output_offset = self.total_output;
            return err;
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}

fn initialRawLimit(options: anytype) Count {
    return rawLimit(options, 0);
}

fn rawLimit(options: anytype, total_output: Count) Count {
    const max_remaining = if (total_output < options.max_output_len) options.max_output_len - total_output else 0;
    if (!options.allow_concatenated) return max_remaining;
    if (options.expected_output_len) |expected| {
        const expected_remaining = if (total_output < expected) expected - total_output else 0;
        return @min(max_remaining, expected_remaining);
    }
    return max_remaining;
}
