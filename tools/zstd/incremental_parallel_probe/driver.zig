//! Incremental pumps, explicit boundaries, recovery and lifecycle scenarios.
const std = @import("std");
const zstd = @import("zstd");
const configuration = @import("config.zig");
const observations = @import("event_state.zig");
const Count = configuration.Count;
const Result = observations.Result;
const Status = observations.Status;

pub const Runner = struct {
    state: observations.State,

    pub fn deinit(self: *Runner) void {
        self.state.deinit();
    }
    fn recover(self: *Runner, result: Result) anyerror!bool {
        const err = result.failure orelse return false;
        if ((self.state.c.scenario == .input_retry or self.state.c.scenario == .output_retry or self.state.c.scenario == .jobs_retry) and
            err == error.OutputLimitExceeded and !self.state.encoder.?.snapshot().parallel.failed and !self.state.invariants.stream_limit_recovery)
        {
            switch (self.state.c.scenario) {
                .input_retry => self.state.encoder.?.options.max_input_len = std.math.maxInt(Count),
                .output_retry => self.state.encoder.?.options.max_output_len = std.math.maxInt(Count),
                .jobs_retry => self.state.encoder.?.options.max_job_count = std.math.maxInt(Count),
                else => unreachable,
            }
            self.state.invariants.stream_limit_recovery = true;
            try self.state.recoveries.append(self.state.init.gpa, "OutputLimitExceeded: raised explicit cumulative input/output or current-frame job cap");
            return true;
        }
        if (self.state.c.scenario == .pending_retry and !self.state.encoder.?.snapshot().parallel.failed and !self.state.invariants.front_retry_no_reencode) {
            if (err != error.OutputLimitExceeded) return err;
            const encoded = self.state.encoder.?.snapshot().parallel.profile.encoded_jobs;
            self.state.encoder.?.options.max_pending_output_len = 16 * 1024 * 1024;
            const retry = try self.state.call("", 0);
            if (retry.failure) |failure| return failure;
            if (self.state.encoder.?.snapshot().parallel.profile.encoded_jobs != encoded) return error.RetryReencodedFrontJob;
            self.state.invariants.front_retry_no_reencode = true;
            try self.state.recoveries.append(self.state.init.gpa, "OutputLimitExceeded: raised pending publication cap; front encoded job reused");
            return true;
        }
        if (self.state.c.scenario == .partial_credit and err == error.WorkingMemoryLimitExceeded and !self.state.encoder.?.snapshot().parallel.failed) {
            try self.flush();
            self.state.invariants.partial_credit_recovery = true;
            try self.state.recoveries.append(self.state.init.gpa, "WorkingMemoryLimitExceeded: explicit partial flush at original job geometry");
            return true;
        }
        try self.state.sticky(err);
        return err;
    }
    fn drain(self: *Runner, expected: Status) !void {
        for (0..4 * 1024 * 1024) |i| {
            const quota = self.state.c.output_chunks[i % self.state.c.output_chunks.len];
            const result = try self.state.call("", quota);
            if (try self.recover(result)) continue;
            if (result.status == expected) return;
            if (result.status != .need_output) return error.UnexpectedDrainStatus;
        }
        return error.DrainDidNotConverge;
    }
    fn flush(self: *Runner) !void {
        const before = self.state.encoder.?.snapshot();
        self.state.encoder.?.flush();
        self.state.encoder.?.flush();
        try self.state.touch("flush twice", before);
        try self.state.flushes.append(self.state.init.gpa, before.frame_input);
        try self.drain(.need_input);
        const length = self.state.wire.items.len;
        const count = self.state.encoder.?.snapshot().parallel.profile.accepted_jobs;
        self.state.encoder.?.flush();
        try self.drain(.need_input);
        if (length != self.state.wire.items.len or count != self.state.encoder.?.snapshot().parallel.profile.accepted_jobs) return error.FlushNotIdempotent;
        self.state.invariants.flush_idempotent = true;
    }
    fn move(self: *Runner) !void {
        const before = self.state.encoder.?.snapshot();
        if (before.done or before.parallel.inflight_jobs == 0) return;
        var moved = self.state.encoder.?;
        self.state.encoder = null;
        self.state.encoder = moved;
        moved = undefined;
        const after = self.state.encoder.?.snapshot();
        if (before.input_read != after.input_read or before.output_written != after.output_written or before.parallel.inflight_bytes != after.parallel.inflight_bytes) return error.MoveLostState;
        self.state.invariants.active_move = true;
        try self.state.touch("active value move", before);
    }
    fn feed(self: *Runner, bytes: []const u8) !void {
        var offset: usize = 0;
        const max_calls = 4 * bytes.len + 65536;
        for (0..max_calls) |i| {
            const len = @min(self.state.c.input_chunks[i % self.state.c.input_chunks.len], bytes.len - offset);
            const offer = bytes[offset..][0..len];
            var quota = self.state.c.output_chunks[i % self.state.c.output_chunks.len];
            if (self.state.c.scenario == .credit and !self.state.invariants.last_byte_credit) {
                quota = 1;
                const before = self.state.encoder.?.snapshot();
                if (before.parallel.delivering_job and before.parallel.delivering_output_bytes == 1) {
                    const blocked = try self.state.call(offer, 0);
                    if (blocked.failure != null or blocked.progress.input_read != 0 or blocked.progress.output_written != 0 or
                        self.state.encoder.?.snapshot().parallel.profile.delivered_jobs != before.parallel.profile.delivered_jobs or
                        self.state.encoder.?.snapshot().parallel.inflight_bytes != before.parallel.inflight_bytes) return error.JobCreditReleasedBeforeLastByte;
                    const released = try self.state.call(offer, 1);
                    if (released.failure) |err| return err;
                    if (released.progress.output_written != 1 or self.state.encoder.?.snapshot().parallel.profile.delivered_jobs != before.parallel.profile.delivered_jobs + 1) return error.LastByteDidNotReleaseCredit;
                    offset += released.progress.input_read;
                    self.state.invariants.last_byte_credit = true;
                    continue;
                }
            }
            const result = try self.state.call(offer, quota);
            offset += result.progress.input_read;
            if (try self.recover(result)) continue;
            if (self.state.c.scenario == .move and !self.state.invariants.active_move and self.state.encoder.?.snapshot().parallel.profile.workers_started != 0) try self.move();
            if (offset == bytes.len and result.status == .need_input) return;
            if (result.status == .done) return error.FrameFinishedWhileFeeding;
        }
        return error.FeedDidNotConverge;
    }
    fn dataFrame(self: *Runner, expected: ?Count) !void {
        const start = self.state.wire.items.len;
        const header = configuration.headerLen(self.state.c, self.state.dictionary, expected);
        var input_offset: usize = 0;
        const zero = try self.state.call(self.state.input[0..@min(self.state.input.len, 1)], 0);
        input_offset += zero.progress.input_read;
        _ = try self.recover(zero);
        while (self.state.encoder.?.snapshot().frame_output < header) {
            const offered = self.state.input[input_offset..][0..@min(self.state.input.len - input_offset, 1)];
            const result = try self.state.call(offered, 1);
            // State.call already checked and poisoned this accepted prefix.
            // The final Header byte opens admission in the same public call.
            input_offset += result.progress.input_read;
            if (try self.recover(result)) continue;
            if (result.progress.output_written != 1) return error.HeaderTinyDrain;
            const after = self.state.encoder.?.snapshot();
            if (after.frame_output < header and (result.progress.input_read != 0 or after.parallel.profile.workers_started != 0 or
                after.parallel.owned_input_bytes != 0)) return error.HeaderTinyDrain;
        }
        if (self.state.c.scenario == .seal or self.state.c.scenario == .pledge_lookahead or self.state.c.scenario == .input_lookahead) {
            if (self.state.input.len != self.state.encoder.?.snapshot().parallel.profile.effective_job_size) return error.SealFixtureGeometry;
            const accepted = try self.state.call(self.state.input[input_offset..], 0);
            input_offset += accepted.progress.input_read;
            if (accepted.failure) |err| return err;
            if (input_offset != self.state.input.len) return error.SealFixtureGeometry;
            const full = self.state.encoder.?.snapshot();
            const waiting = try self.state.call("", 257);
            if (waiting.failure != null or waiting.progress.input_read != 0 or waiting.progress.output_written != 0 or waiting.status != .need_input or
                full.parallel.profile.encoded_jobs != 0 or self.state.encoder.?.snapshot().parallel.profile.encoded_jobs != 0 or full.parallel.active_jobs != 0) return error.FullJobEncodedBeforeSeal;
            self.state.invariants.full_job_wait = true;
            if (self.state.c.scenario != .seal) {
                const invalid = try self.state.call("!", 257);
                const wanted: anyerror = if (self.state.c.scenario == .pledge_lookahead) error.SizeMismatch else error.OutputLimitExceeded;
                const actual_error: anyerror = invalid.failure orelse return error.InvalidLookaheadSealedFullJob;
                const unchanged = self.state.encoder.?.snapshot();
                if (actual_error != wanted or invalid.progress.input_read != 0 or invalid.progress.output_written != 0 or
                    unchanged.parallel.failed or unchanged.parallel.profile.encoded_jobs != 0 or unchanged.parallel.active_jobs != 0 or
                    unchanged.frame_input != full.frame_input) return error.InvalidLookaheadSealedFullJob;
                self.state.invariants.invalid_offer_did_not_seal = true;
                try self.state.recoveries.append(self.state.init.gpa, "invalid nonempty lookahead refused without sealing the retained full job");
            }
        } else {
            var offset: usize = input_offset;
            for (self.state.c.flush_offsets) |boundary| {
                if (boundary < offset or boundary > self.state.input.len) return error.InvalidFlushOffset;
                try self.feed(self.state.input[offset..boundary]);
                offset = boundary;
                try self.flush();
            }
            try self.feed(self.state.input[offset..]);
        }
        if (self.state.c.scenario == .move and !self.state.invariants.active_move) try self.move();
        const before = self.state.encoder.?.snapshot();
        self.state.encoder.?.finish();
        self.state.encoder.?.finish();
        try self.state.touch("finish twice", before);
        try self.drain(.done);
        const snapshot = self.state.encoder.?.snapshot();
        const wire = self.state.wire.items[start..];
        const decoded = try zstd.decodeFrameAllocWithOptions(self.state.init.gpa, wire, .{
            .format = self.state.c.format,
            .dictionary = self.state.dictionary,
            .max_output_len = self.state.input.len + 1,
            .expected_output_len = self.state.input.len,
        });
        defer self.state.init.gpa.free(decoded);
        if (!std.mem.eql(u8, decoded, self.state.input)) return error.PublicFullDecodeMismatch;
        try self.state.frames.append(self.state.init.gpa, .{ .wire_start = start, .wire_bytes = wire.len, .input_bytes = self.state.input.len, .pledged_input_len = expected, .snapshot = snapshot });
        self.state.self_decode_verified = true;
        const done = try self.state.call("", 0);
        if (done.failure != null or done.status != .done or done.progress.input_read != 0 or done.progress.output_written != 0) return error.DoneNotIdempotent;
    }
    pub fn run(self: *Runner, fallback: bool) !void {
        if (self.state.c.record_every == 0 or self.state.c.input_chunks.len == 0 or self.state.c.output_chunks.len == 0 or self.state.c.frames == 0) return error.InvalidProbeConfig;
        var in_max: usize = @max(self.state.input.len, 1);
        // A full seal fixture is one offered slice; ordinary feed quotas are
        // independently bounded and copied into this reusable caller buffer.
        if (self.state.c.scenario != .seal and self.state.c.scenario != .pledge_lookahead and self.state.c.scenario != .input_lookahead) {
            in_max = 1;
            for (self.state.c.input_chunks) |quota| {
                if (quota == 0) return error.InvalidProbeInputQuota;
                in_max = @max(in_max, quota);
            }
        }
        var out_max: usize = 257;
        var nonzero = false;
        for (self.state.c.output_chunks) |quota| {
            out_max = @max(out_max, quota);
            nonzero = nonzero or quota != 0;
        }
        if (!nonzero) return error.InvalidProbeOutputQuota;
        self.state.borrowed = try self.state.init.gpa.alloc(u8, in_max);
        self.state.output = try self.state.init.gpa.alloc(u8, out_max + 16);
        const options = configuration.encoderOptions(self.state.init, self.state.c, self.state.dictionary, &self.state.control, &self.state.profile, fallback);
        const expected = try configuration.pledge(self.state.c, self.state.input.len);
        self.state.encoder = try configuration.create(self.state.init.gpa, self.state.c, self.state.dictionary, self.state.set, options, expected);
        self.state.initialized = true;
        const repetitions = if (self.state.c.scenario == .reset) @as(usize, 2) else self.state.c.frames;
        for (0..repetitions) |frame_index| {
            if (frame_index != 0) {
                if (self.state.c.scenario == .reset) {
                    const before = self.state.encoder.?.snapshot();
                    self.state.encoder.?.reset();
                    const after = self.state.encoder.?.snapshot();
                    if (after.input_read != 0 or after.output_written != 0 or after.frame_count != 0 or after.done) return error.ResetKeptStreamProgress;
                    self.state.invariants.reset_reuse = true;
                    try self.state.touch("reset", before);
                } else {
                    const before = self.state.encoder.?.snapshot();
                    try configuration.next(&self.state.encoder.?, self.state.c, self.state.dictionary, self.state.set, options, expected);
                    const after = self.state.encoder.?.snapshot();
                    if (after.input_read != before.input_read or after.output_written != before.output_written or after.frame_input != 0) return error.NextFrameResetStreamTotals;
                    try self.state.touch("nextFrame", before);
                }
            }
            try self.dataFrame(expected);
            if (self.state.c.scenario == .skippable and frame_index + 1 < repetitions) {
                const start = self.state.wire.items.len;
                const before = self.state.encoder.?.snapshot();
                try self.state.encoder.?.writeSkippable(7, "incremental metadata");
                try self.state.touch("writeSkippable", before);
                try self.drain(.done);
                const after = self.state.encoder.?.snapshot();
                if (after.input_read != before.input_read or after.frame_count != before.frame_count) return error.SkippableChangedInputOrDataFrameCount;
                try self.state.skippable.append(self.state.init.gpa, .{ .wire_start = start, .wire_bytes = self.state.wire.items.len - start, .id = 7, .payload_bytes = 20 });
            }
        }
    }
};
