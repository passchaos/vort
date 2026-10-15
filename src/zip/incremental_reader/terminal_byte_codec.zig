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

// A stalled legacy bit reader retains at most fifteen useful bits after one
// withheld byte is added. Even a just-completed maximum match expands far less
// than this fixed guard for Reduce or Implode.
const max_speculative_output: usize = 8 * 1024;

/// Adapter for a non-self-delimiting codec whose final byte may contain valid
/// padding prefixes. `Codec` supplies Config, Workspace, Decoder, Error and an
/// `initDecoder` function; Decoder supplies step/finish/setExpectedOutputLen.
pub fn State(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        workspace: *Codec.Workspace,
        trial_workspace: *Codec.Workspace,
        speculative_output: []u8,
        decoder: Codec.Decoder,
        descriptor_layout: ?descriptor.Layout,
        expected_compressed_size: ?usize,
        compressed_size_prefix: usize,
        finish_requested: bool = false,
        probe: [wire.zip64_data_descriptor_len + 1]u8 = undefined,
        payload_probe: [wire.zip64_data_descriptor_len + 1]u8 = undefined,
        probe_len: usize = 0,
        pending_pos: usize = 0,
        pending_len: usize = 0,
        result_descriptor: ?descriptor.Descriptor = null,
        next_prefix: [4]u8 = undefined,
        next_prefix_len: usize = 0,
        crc: checksum.Crc32Best = checksum.Crc32Best.init(),
        compressed_size: usize = 0,
        uncompressed_size: usize = 0,

        const Self = @This();
        const AdapterError = Error || Codec.Error;

        pub fn init(
            allocator: std.mem.Allocator,
            config: Codec.Config,
            entry_limit: usize,
            expected_compressed_size: ?usize,
            expected_uncompressed_size: ?usize,
            descriptor_layout: ?descriptor.Layout,
            compressed_size_prefix: usize,
        ) AdapterError!Self {
            if ((expected_compressed_size == null) != (descriptor_layout != null))
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
                .decoder = Codec.initDecoder(
                    workspace,
                    config,
                    entry_limit,
                    expected_uncompressed_size,
                ),
                .descriptor_layout = descriptor_layout,
                .expected_compressed_size = expected_compressed_size,
                .compressed_size_prefix = compressed_size_prefix,
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

        pub fn actualCompressedSize(self: *const Self) usize {
            return self.compressed_size;
        }

        pub fn outputSize(self: *const Self) usize {
            return self.uncompressed_size;
        }

        pub fn crc32(self: *const Self) u32 {
            return self.crc.digest();
        }

        fn stepKnown(self: *Self, input: []const u8, output: []u8) AdapterError!core.StepResult {
            var progress: core.Progress = .{};
            while (true) {
                const drained = try self.decoder.step("", output[progress.output_written..]);
                try self.accountKnown(drained.progress, output[progress.output_written..], &progress);
                if (drained.status == .done or drained.status == .need_output)
                    return .{ .progress = progress, .status = drained.status };

                const expected = self.expected_compressed_size orelse return error.InvalidZipArchive;
                if (self.compressed_size == expected) {
                    if (!self.finish_requested) {
                        self.decoder.finish();
                        self.finish_requested = true;
                        continue;
                    }
                    return Codec.truncatedError();
                }
                if (self.compressed_size > expected) return error.SizeMismatch;
                const offer_len = @min(input.len - progress.input_read, expected - self.compressed_size);
                if (offer_len == 0)
                    return .{ .progress = progress, .status = .need_input };
                const output_offset = progress.output_written;
                const supplied = try self.decoder.step(
                    input[progress.input_read..][0..offer_len],
                    output[output_offset..],
                );
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
            const capacity = self.descriptor_layout.?.signedLen() + 1;

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

                const drained = try self.decoder.step("", output[output_written..]);
                try self.accountBuffered(drained.progress, output[output_written..], &output_written);
                if (drained.status == .done)
                    return result(input_read, output_written, .done);
                if (drained.status == .need_output)
                    return result(input_read, output_written, .need_output);

                if (self.result_descriptor != null) return error.InvalidZipArchive;
                if (self.probe_len == capacity) {
                    if (try self.detectBoundary()) continue;

                    const supplied = try self.decoder.step(
                        self.payload_probe[0..1],
                        output[output_written..],
                    );
                    if (supplied.progress.input_read != 1)
                        return error.InvalidZipArchive;
                    try self.accountBuffered(
                        supplied.progress,
                        output[output_written..],
                        &output_written,
                    );
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
            const capacity = layout_value.signedLen() + 1;
            std.debug.assert(self.probe_len == capacity);

            if (std.mem.readInt(u32, self.probe[1..5], .little) == wire.data_descriptor_signature) {
                const candidate = descriptor.parseDescriptor(
                    layout_value,
                    self.probe[1..capacity],
                    true,
                );
                if (try self.tryCandidate(candidate)) {
                    self.result_descriptor = candidate;
                    self.probe_len = 0;
                    return true;
                }
            }

            const unsigned_len = layout_value.unsignedLen();
            if (!descriptor.isFollowingRecordSignature(
                self.probe[1 + unsigned_len ..][0..4],
            )) return false;
            const candidate = descriptor.parseDescriptor(
                layout_value,
                self.probe[1..][0..unsigned_len],
                false,
            );
            if (!try self.tryCandidate(candidate)) return false;
            self.result_descriptor = candidate;
            @memcpy(&self.next_prefix, self.probe[1 + unsigned_len ..][0..4]);
            self.next_prefix_len = 4;
            self.probe_len = 0;
            return true;
        }

        fn tryCandidate(self: *Self, candidate: descriptor.Descriptor) AdapterError!bool {
            const candidate_compressed = std.math.cast(usize, candidate.compressed_size) orelse
                return false;
            if (candidate_compressed != try checkedAdd(
                try checkedAdd(self.compressed_size, 1),
                self.compressed_size_prefix,
            ))
                return false;
            const candidate_output = std.math.cast(usize, candidate.uncompressed_size) orelse
                return false;
            if (candidate_output < self.uncompressed_size or
                candidate_output - self.uncompressed_size > self.speculative_output.len)
                return false;

            self.trial_workspace.* = self.workspace.*;
            var trial = self.decoder;
            trial.workspace = self.trial_workspace;
            trial.setExpectedOutputLen(candidate_output) catch return false;

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
            if (trial_crc.digest() != candidate.crc32) return false;

            const committed_workspace = self.trial_workspace;
            self.trial_workspace = self.workspace;
            self.workspace = committed_workspace;
            self.decoder = trial;
            self.decoder.workspace = self.workspace;
            self.crc = trial_crc;
            self.compressed_size = candidate_compressed - self.compressed_size_prefix;
            self.uncompressed_size = candidate_output;
            self.pending_pos = 0;
            self.pending_len = written;
            return true;
        }

        fn accountKnown(
            self: *Self,
            decoder_progress: core.Progress,
            output: []const u8,
            aggregate: *core.Progress,
        ) Error!void {
            self.compressed_size = try checkedAdd(self.compressed_size, decoder_progress.input_read);
            self.uncompressed_size = try checkedAdd(self.uncompressed_size, decoder_progress.output_written);
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
            self.compressed_size = try checkedAdd(self.compressed_size, decoder_progress.input_read);
            self.uncompressed_size = try checkedAdd(self.uncompressed_size, decoder_progress.output_written);
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
