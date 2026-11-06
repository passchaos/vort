const std = @import("std");
const checksum = @import("../../checksum.zig");
const core = @import("../../core.zig");
const descriptor = @import("descriptor.zig");
const wire = @import("../wire.zig");

pub const Error = std.mem.Allocator.Error || error{
    InvalidZipArchive,
    SizeMismatch,
    IntegerOverflow,
};

/// A narrow codec pledge is checked at its concrete decoder entry point.
pub fn toOptionalLocal(value: ?core.StreamCount) error{IntegerOverflow}!?usize {
    return if (value) |expected| try core.stream_count.toLocal(expected) else null;
}

/// Clamp physical windows before a decoder can mutate caller bytes or counters.
/// Decoder diagnostics preserve partial progress when a step ends in an error.
pub const DecodeWindow = struct {
    input: []const u8,
    output: []u8,
    input_clipped: bool,
    output_clipped: bool,
    before: core.StreamingDiagnostics,

    pub fn init(
        decoder: anytype,
        input_total: core.StreamCount,
        output_total: core.StreamCount,
        input: []const u8,
        output: []u8,
    ) DecodeWindow {
        const Decoder = @TypeOf(decoder.*);
        var input_room = std.math.maxInt(core.StreamCount) - input_total;
        var output_room = std.math.maxInt(core.StreamCount) - output_total;
        if (@hasField(Decoder, "total_input")) {
            input_room = @min(input_room, counterRoom(decoder.total_input));
        } else if (@hasField(Decoder, "input_received")) {
            input_room = @min(input_room, counterRoom(decoder.input_received));
        } else if (@hasField(Decoder, "input_read")) {
            input_room = @min(input_room, counterRoom(decoder.input_read));
        }
        if (@hasField(Decoder, "total_output")) {
            output_room = @min(output_room, counterRoom(decoder.total_output));
        } else if (@hasField(Decoder, "output_written")) {
            output_room = @min(output_room, counterRoom(decoder.output_written));
        }
        const input_len = core.stream_count.bounded(input_room, input.len);
        const output_len = core.stream_count.bounded(output_room, output.len);
        return .{
            .input = input[0..input_len],
            .output = output[0..output_len],
            .input_clipped = input_len != input.len,
            .output_clipped = output_len != output.len,
            .before = decoder.diagnostics(),
        };
    }

    pub fn errorProgress(self: DecodeWindow, decoder: anytype) error{IntegerOverflow}!core.Progress {
        const after = decoder.diagnostics();
        if (after.last_step_progress) |progress| return progress;
        const before_input = self.before.input_read orelse self.before.frame_input_read orelse 0;
        const after_input = after.input_read orelse after.frame_input_read orelse 0;
        return .{
            .input_read = try core.stream_count.toLocal(after_input - before_input),
            .output_written = try core.stream_count.toLocal(after.output_written - self.before.output_written),
        };
    }

    pub fn overflowed(self: DecodeWindow, stepped: core.StepResult) bool {
        return (self.input_clipped and stepped.status == .need_input) or
            (self.output_clipped and stepped.status == .need_output);
    }

    fn counterRoom(value: anytype) core.StreamCount {
        return @as(core.StreamCount, std.math.maxInt(@TypeOf(value))) - value;
    }
};

/// Account the bytes a decoder committed even when it returns an error.
pub fn decode(
    comptime DecodeError: type,
    adapter: anytype,
    decoder: anytype,
    input: []const u8,
    output: []u8,
    aggregate: *core.Progress,
    comptime account: anytype,
) DecodeError!core.StepResult {
    const window = DecodeWindow.init(decoder, adapter.compressed_size, adapter.uncompressed_size, input, output);
    const stepped = decoder.step(window.input, window.output) catch |err| {
        try account(adapter, try window.errorProgress(decoder), window.output, aggregate);
        return err;
    };
    if (window.overflowed(stepped)) {
        try account(adapter, stepped.progress, window.output, aggregate);
        return error.IntegerOverflow;
    }
    return stepped;
}

// A stalled legacy bit reader retains at most fifteen useful bits after one
// withheld byte is added. Even a just-completed maximum match expands far less
// than this fixed guard for Reduce or Implode.
const max_speculative_output: usize = 8 * 1024;

/// Adapter for a non-self-delimiting codec whose final byte may contain valid
/// padding prefixes. `Codec` supplies Config, Workspace, Decoder, Error and an
/// `initDecoder` function; Decoder supplies step/finish/setExpectedOutputLen.
pub fn State(comptime Codec: type) type {
    return struct {
        const max_authentication_code_len: usize = 10;

        allocator: std.mem.Allocator,
        workspace: *Codec.Workspace,
        trial_workspace: *Codec.Workspace,
        speculative_output: []u8,
        decoder: Codec.Decoder,
        descriptor_layout: ?descriptor.Layout,
        expected_compressed_size: ?core.StreamCount,
        compressed_size_prefix: usize,
        authentication_code_len: usize,
        verify_crc32: bool,
        finish_requested: bool = false,
        probe: [wire.zip64_data_descriptor_len + 1 + max_authentication_code_len]u8 = undefined,
        payload_probe: [wire.zip64_data_descriptor_len + 1 + max_authentication_code_len]u8 = undefined,
        probe_len: usize = 0,
        pending_pos: usize = 0,
        pending_len: usize = 0,
        result_descriptor: ?descriptor.Descriptor = null,
        next_prefix: [4]u8 = undefined,
        next_prefix_len: usize = 0,
        result_authentication: [max_authentication_code_len]u8 = undefined,
        crc: checksum.Crc32Best = checksum.Crc32Best.init(),
        compressed_size: core.StreamCount = 0,
        uncompressed_size: core.StreamCount = 0,
        last_step_progress: core.Progress = .{},

        const Self = @This();
        const AdapterError = Error || Codec.Error;

        pub fn init(
            allocator: std.mem.Allocator,
            config: Codec.Config,
            entry_limit: core.StreamCount,
            expected_compressed_size: ?core.StreamCount,
            expected_uncompressed_size: ?core.StreamCount,
            descriptor_layout: ?descriptor.Layout,
            compressed_size_prefix: usize,
            authentication_code_len: usize,
            verify_crc32: bool,
        ) AdapterError!Self {
            if (expected_compressed_size != null and descriptor_layout != null)
                return error.InvalidZipArchive;
            const workspace = try allocator.create(Codec.Workspace);
            errdefer allocator.destroy(workspace);
            const trial_workspace = try allocator.create(Codec.Workspace);
            errdefer allocator.destroy(trial_workspace);
            const speculative_output = try allocator.alloc(u8, max_speculative_output);
            errdefer allocator.free(speculative_output);
            return .{
                .allocator = allocator,
                .workspace = workspace,
                .trial_workspace = trial_workspace,
                .speculative_output = speculative_output,
                .decoder = try Codec.initDecoder(
                    workspace,
                    config,
                    entry_limit,
                    expected_uncompressed_size,
                ),
                .descriptor_layout = descriptor_layout,
                .expected_compressed_size = expected_compressed_size,
                .compressed_size_prefix = compressed_size_prefix,
                .authentication_code_len = authentication_code_len,
                .verify_crc32 = verify_crc32,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.destroy(self.workspace);
            self.allocator.destroy(self.trial_workspace);
            self.allocator.free(self.speculative_output);
            self.* = undefined;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) AdapterError!core.StepResult {
            return self.stepPaired(input, input, output);
        }

        pub fn stepPaired(
            self: *Self,
            raw_input: []const u8,
            payload_input: []const u8,
            output: []u8,
        ) AdapterError!core.StepResult {
            self.last_step_progress = .{};
            std.debug.assert(raw_input.len == payload_input.len);
            return if (self.descriptor_layout == null)
                self.stepKnown(payload_input, output)
            else
                self.stepDescriptor(raw_input, payload_input, output);
        }

        pub fn layout(self: *const Self) ?descriptor.Layout {
            return self.descriptor_layout;
        }

        pub fn descriptorValue(self: *const Self) ?descriptor.Descriptor {
            return self.result_descriptor;
        }

        pub fn retainedRecordPrefix(self: *const Self) []const u8 {
            return self.next_prefix[0..self.next_prefix_len];
        }

        pub fn authenticationCode(self: *const Self) []const u8 {
            return self.result_authentication[0..self.authentication_code_len];
        }

        pub fn actualCompressedSize(self: *const Self) core.StreamCount {
            return self.compressed_size;
        }

        pub fn outputSize(self: *const Self) core.StreamCount {
            return self.uncompressed_size;
        }

        pub fn crc32(self: *const Self) u32 {
            return self.crc.digest();
        }

        pub fn setExpectedOutputLen(self: *Self, expected: core.StreamCount) AdapterError!void {
            try self.decoder.setExpectedOutputLen(try core.stream_count.toLocal(expected));
        }

        fn stepKnown(self: *Self, input: []const u8, output: []u8) AdapterError!core.StepResult {
            var progress: core.Progress = .{};
            defer self.last_step_progress = progress;
            while (true) {
                const drained = try self.decode("", output[progress.output_written..], &progress);
                try self.accountKnown(drained.progress, output[progress.output_written..], &progress);
                if (drained.status == .done or drained.status == .need_output)
                    return .{ .progress = progress, .status = drained.status };

                const expected = self.expected_compressed_size orelse {
                    const offer_len = input.len - progress.input_read;
                    if (offer_len == 0)
                        return .{ .progress = progress, .status = .need_input };
                    const output_offset = progress.output_written;
                    const supplied = try self.decode(input[progress.input_read..][0..offer_len], output[output_offset..], &progress);
                    try self.accountKnown(supplied.progress, output[output_offset..], &progress);
                    if (supplied.status == .done or supplied.status == .need_output)
                        return .{ .progress = progress, .status = supplied.status };
                    continue;
                };
                if (self.compressed_size == expected) {
                    if (!self.finish_requested) {
                        self.decoder.finish();
                        self.finish_requested = true;
                        continue;
                    }
                    return Codec.truncatedError();
                }
                if (self.compressed_size > expected) return error.SizeMismatch;
                const offer_len = core.stream_count.bounded(expected - self.compressed_size, input.len - progress.input_read);
                if (offer_len == 0)
                    return .{ .progress = progress, .status = .need_input };
                const output_offset = progress.output_written;
                const supplied = try self.decode(input[progress.input_read..][0..offer_len], output[output_offset..], &progress);
                try self.accountKnown(supplied.progress, output[output_offset..], &progress);
                if (supplied.status == .done or supplied.status == .need_output)
                    return .{ .progress = progress, .status = supplied.status };
            }
        }

        fn stepDescriptor(
            self: *Self,
            raw_input: []const u8,
            payload_input: []const u8,
            output: []u8,
        ) AdapterError!core.StepResult {
            var input_read: usize = 0;
            var output_written: usize = 0;
            defer self.last_step_progress = .{ .input_read = input_read, .output_written = output_written };
            const capacity = self.descriptor_layout.?.signedLen() + 1 +
                self.authentication_code_len;

            while (true) {
                if (self.pending_pos != self.pending_len) {
                    const take = @min(
                        self.pending_len - self.pending_pos,
                        output.len - output_written,
                    );
                    @memcpy(
                        output[output_written..][0..take],
                        self.speculative_output[self.pending_pos..][0..take],
                    );
                    self.pending_pos += take;
                    output_written += take;
                    if (self.pending_pos != self.pending_len)
                        return result(input_read, output_written, .need_output);
                    self.pending_pos = 0;
                    self.pending_len = 0;
                }

                const drained = try self.decodeBuffered("", output[output_written..], &output_written);
                try self.accountBuffered(drained.progress, output[output_written..], &output_written);
                if (drained.status == .done)
                    return result(input_read, output_written, .done);
                if (drained.status == .need_output)
                    return result(input_read, output_written, .need_output);

                if (self.result_descriptor != null) return error.InvalidZipArchive;
                if (self.probe_len == capacity) {
                    if (try self.detectBoundary()) continue;

                    const supplied = try self.decodeBuffered(self.payload_probe[0..1], output[output_written..], &output_written);
                    try self.accountBuffered(
                        supplied.progress,
                        output[output_written..],
                        &output_written,
                    );
                    if (supplied.progress.input_read != 1)
                        return error.InvalidZipArchive;
                    std.mem.copyForwards(u8, self.probe[0 .. capacity - 1], self.probe[1..capacity]);
                    std.mem.copyForwards(
                        u8,
                        self.payload_probe[0 .. capacity - 1],
                        self.payload_probe[1..capacity],
                    );
                    self.probe_len -= 1;
                    if (supplied.status == .need_output)
                        return result(input_read, output_written, .need_output);
                    continue;
                }

                if (input_read == raw_input.len)
                    return result(input_read, output_written, .need_input);
                const take = @min(capacity - self.probe_len, raw_input.len - input_read);
                @memcpy(self.probe[self.probe_len..][0..take], raw_input[input_read..][0..take]);
                @memcpy(
                    self.payload_probe[self.probe_len..][0..take],
                    payload_input[input_read..][0..take],
                );
                self.probe_len += take;
                input_read += take;
            }
        }

        fn detectBoundary(self: *Self) AdapterError!bool {
            const layout_value = self.descriptor_layout.?;
            const authentication_offset: usize = 1;
            const descriptor_offset = authentication_offset + self.authentication_code_len;
            const capacity = layout_value.signedLen() + descriptor_offset;
            std.debug.assert(self.probe_len == capacity);

            if (std.mem.readInt(u32, self.probe[descriptor_offset..][0..4], .little) == wire.data_descriptor_signature) {
                const candidate = descriptor.parseDescriptor(
                    layout_value,
                    self.probe[descriptor_offset..][0..layout_value.signedLen()],
                    true,
                );
                if (try self.tryCandidate(candidate)) {
                    @memcpy(
                        self.result_authentication[0..self.authentication_code_len],
                        self.probe[authentication_offset..descriptor_offset],
                    );
                    self.result_descriptor = candidate;
                    self.probe_len = 0;
                    return true;
                }
            }

            const unsigned_len = layout_value.unsignedLen();
            if (!descriptor.isFollowingRecordSignature(
                self.probe[descriptor_offset + unsigned_len ..][0..4],
            )) return false;
            const candidate = descriptor.parseDescriptor(
                layout_value,
                self.probe[descriptor_offset..][0..unsigned_len],
                false,
            );
            if (!try self.tryCandidate(candidate)) return false;
            @memcpy(
                self.result_authentication[0..self.authentication_code_len],
                self.probe[authentication_offset..descriptor_offset],
            );
            self.result_descriptor = candidate;
            @memcpy(
                &self.next_prefix,
                self.probe[descriptor_offset + unsigned_len ..][0..4],
            );
            self.next_prefix_len = 4;
            self.probe_len = 0;
            return true;
        }

        fn tryCandidate(self: *Self, candidate: descriptor.Descriptor) AdapterError!bool {
            const candidate_compressed = std.math.cast(core.StreamCount, candidate.compressed_size) orelse
                return false;
            if (candidate_compressed != try core.stream_count.addLocal(
                try core.stream_count.addLocal(self.compressed_size, 1),
                self.compressed_size_prefix,
            ))
                return false;
            const candidate_output = std.math.cast(core.StreamCount, candidate.uncompressed_size) orelse
                return false;
            if (candidate_output < self.uncompressed_size or
                candidate_output - self.uncompressed_size > self.speculative_output.len)
                return false;

            self.trial_workspace.* = self.workspace.*;
            var trial = self.decoder;
            trial.workspace = self.trial_workspace;
            const candidate_local = core.stream_count.toLocal(candidate_output) catch return false;
            trial.setExpectedOutputLen(candidate_local) catch return false;

            var written: usize = 0;
            const supplied = trial.step(self.payload_probe[0..1], self.speculative_output) catch return false;
            if (supplied.progress.input_read != 1 or supplied.status == .need_output)
                return false;
            written = supplied.progress.output_written;
            trial.finish();
            while (true) {
                const drained = trial.step("", self.speculative_output[written..]) catch return false;
                written = try checkedAdd(written, drained.progress.output_written);
                if (drained.status == .done) break;
                if (drained.status != .need_output) return false;
                if (written == self.speculative_output.len) return false;
            }
            if (written != candidate_output - self.uncompressed_size) return false;

            var trial_crc = self.crc;
            trial_crc.update(self.speculative_output[0..written]);
            if (self.verify_crc32 and trial_crc.digest() != candidate.crc32) return false;

            const committed_workspace = self.trial_workspace;
            self.trial_workspace = self.workspace;
            self.workspace = committed_workspace;
            self.decoder = trial;
            self.decoder.workspace = self.workspace;
            self.crc = trial_crc;
            self.compressed_size = try core.stream_count.addLocal(self.compressed_size, 1);
            self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, written);
            self.pending_pos = 0;
            self.pending_len = written;
            return true;
        }

        fn decode(self: *Self, input: []const u8, output: []u8, aggregate: *core.Progress) AdapterError!core.StepResult {
            return @import("terminal_byte_codec.zig").decode(AdapterError, self, &self.decoder, input, output, aggregate, Self.accountKnown);
        }

        fn decodeBuffered(self: *Self, input: []const u8, output: []u8, output_written: *usize) AdapterError!core.StepResult {
            var partial: core.Progress = .{};
            return self.decode(input, output, &partial) catch |err| {
                output_written.* = try checkedAdd(output_written.*, partial.output_written);
                return err;
            };
        }

        fn accountKnown(
            self: *Self,
            decoder_progress: core.Progress,
            output: []const u8,
            aggregate: *core.Progress,
        ) Error!void {
            self.compressed_size = try core.stream_count.addLocal(self.compressed_size, decoder_progress.input_read);
            self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, decoder_progress.output_written);
            self.crc.update(output[0..decoder_progress.output_written]);
            aggregate.input_read = try checkedAdd(aggregate.input_read, decoder_progress.input_read);
            aggregate.output_written = try checkedAdd(aggregate.output_written, decoder_progress.output_written);
        }

        fn accountBuffered(
            self: *Self,
            decoder_progress: core.Progress,
            output: []const u8,
            output_written: *usize,
        ) Error!void {
            self.compressed_size = try core.stream_count.addLocal(self.compressed_size, decoder_progress.input_read);
            self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, decoder_progress.output_written);
            self.crc.update(output[0..decoder_progress.output_written]);
            output_written.* = try checkedAdd(output_written.*, decoder_progress.output_written);
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
    };
}

fn checkedAdd(a: usize, b: usize) error{IntegerOverflow}!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

test "ZIP codec adapter terminal trial retains wide compressed counts and local pending output" {
    const reduce = @import("../reduce.zig");
    const reduce_codec = @import("reduce_codec.zig");
    const allocator = std.testing.allocator;
    const payload = "terminal wide counts";
    const encoded = try reduce.encodeAlloc(allocator, payload, .factor_1, .{});
    defer allocator.free(encoded);
    var state = try reduce_codec.State.init(allocator, .factor_1, std.math.maxInt(core.StreamCount), null, null, .zip64, 7, 0, true);
    defer state.deinit();
    var prefix_output: [payload.len]u8 = undefined;
    const primed = try state.decoder.step(encoded[0 .. encoded.len - 1], &prefix_output);
    try std.testing.expectEqual(encoded.len - 1, primed.progress.input_read);
    try std.testing.expectEqual(core.StepResult.Status.need_input, primed.status);
    state.crc.update(prefix_output[0..primed.progress.output_written]);
    state.uncompressed_size = primed.progress.output_written;
    const boundary = @as(core.StreamCount, 1) << 32;
    state.compressed_size = boundary + primed.progress.input_read;
    state.payload_probe[0] = encoded[encoded.len - 1];
    const candidate: descriptor.Descriptor = .{
        .crc32 = checksum.crc32Best(payload),
        .compressed_size = boundary + encoded.len + 7,
        .uncompressed_size = payload.len,
        .signed = true,
        .zip64 = true,
    };
    try std.testing.expect(try state.tryCandidate(candidate));
    try std.testing.expectEqual(boundary + encoded.len, state.actualCompressedSize());
    try std.testing.expectEqual(@as(core.StreamCount, payload.len), state.outputSize());
    try std.testing.expectEqual(candidate.crc32, state.crc32());
    try std.testing.expect(@FieldType(@TypeOf(state), "pending_len") == usize);
    try std.testing.expectEqual(payload.len - primed.progress.output_written, state.pending_len);
    try std.testing.expectEqualSlices(u8, payload[primed.progress.output_written..], state.speculative_output[0..state.pending_len]);
    const pending_len = state.pending_len;
    try std.testing.expect(pending_len != 0);
    state.decoder.phase = .failed;
    var final_output: [payload.len]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidReduceStream, state.stepPaired("", "", &final_output));
    try std.testing.expectEqualDeep(core.Progress{ .output_written = pending_len }, state.last_step_progress);
    try std.testing.expectEqual(@as(core.StreamCount, payload.len), state.outputSize());
    try std.testing.expectEqualSlices(u8, payload[primed.progress.output_written..], final_output[0..pending_len]);
    try std.testing.expectError(error.InvalidReduceStream, state.stepPaired("", "", &final_output));
    try std.testing.expectEqualDeep(core.Progress{}, state.last_step_progress);
}
