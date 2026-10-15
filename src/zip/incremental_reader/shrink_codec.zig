const std = @import("std");
const checksum = @import("../../checksum.zig");
const core = @import("../../core.zig");
const descriptor = @import("descriptor.zig");
const shrink = @import("../shrink.zig");
const wire = @import("../wire.zig");

pub const Error = shrink.Error || std.mem.Allocator.Error || error{
    InvalidZipArchive,
    SizeMismatch,
    IntegerOverflow,
};

/// ZIP adapter for non-self-delimiting Shrink streams.
///
/// Known-size entries feed exactly the local-header compressed size. Descriptor
/// entries retain one descriptor-sized probe window and release disproven
/// bytes to the LZW decoder one at a time. This keeps false signatures byte-
/// exact without buffering the member or rolling decoder/output state back.
pub const State = struct {
    allocator: std.mem.Allocator,
    workspace: *shrink.IncrementalWorkspace,
    decoder: shrink.IncrementalDecoder,
    descriptor_layout: ?descriptor.Layout,
    expected_compressed_size: ?usize,
    compressed_size_prefix: usize,
    finish_requested: bool = false,
    probe: [wire.zip64_data_descriptor_len]u8 = undefined,
    payload_probe: [wire.zip64_data_descriptor_len]u8 = undefined,
    probe_len: usize = 0,
    result_descriptor: ?descriptor.Descriptor = null,
    next_prefix: [4]u8 = undefined,
    next_prefix_len: usize = 0,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: usize = 0,
    uncompressed_size: usize = 0,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        entry_limit: usize,
        expected_compressed_size: ?usize,
        expected_uncompressed_size: ?usize,
        descriptor_layout: ?descriptor.Layout,
        compressed_size_prefix: usize,
    ) Error!Self {
        if ((expected_compressed_size == null) != (descriptor_layout != null))
            return error.InvalidZipArchive;
        const workspace = try allocator.create(shrink.IncrementalWorkspace);
        errdefer allocator.destroy(workspace);
        return .{
            .allocator = allocator,
            .workspace = workspace,
            .decoder = shrink.IncrementalDecoder.initWithOptions(workspace, .{
                .max_output_len = entry_limit,
                .expected_output_len = expected_uncompressed_size,
            }),
            .descriptor_layout = descriptor_layout,
            .expected_compressed_size = expected_compressed_size,
            .compressed_size_prefix = compressed_size_prefix,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.destroy(self.workspace);
        self.* = undefined;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        return self.stepPaired(input, input, output);
    }

    pub fn stepPaired(
        self: *Self,
        raw_input: []const u8,
        payload_input: []const u8,
        output: []u8,
    ) Error!core.StepResult {
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

    fn stepKnown(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
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
                return error.TruncatedShrinkInput;
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
    ) Error!core.StepResult {
        var input_read: usize = 0;
        var output_written: usize = 0;
        const capacity = self.descriptor_layout.?.signedLen();

        while (true) {
            const drained = try self.decoder.step("", output[output_written..]);
            try self.accountBuffered(drained.progress, output[output_written..], &output_written);
            if (drained.status == .done)
                return result(input_read, output_written, .done);
            if (drained.status == .need_output)
                return result(input_read, output_written, .need_output);

            if (self.result_descriptor != null) return error.InvalidZipArchive;
            if (self.probe_len == capacity) {
                if (self.detectBoundary()) {
                    self.decoder.finish();
                    self.finish_requested = true;
                    continue;
                }

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

    fn detectBoundary(self: *Self) bool {
        const layout_value = self.descriptor_layout.?;
        const signed_len = layout_value.signedLen();
        std.debug.assert(self.probe_len == signed_len);
        if (!self.decoder.canFinish()) return false;

        if (std.mem.readInt(u32, self.probe[0..4], .little) == wire.data_descriptor_signature) {
            const candidate = descriptor.parseDescriptor(
                layout_value,
                self.probe[0..signed_len],
                true,
            );
            if (self.matches(candidate)) {
                self.result_descriptor = candidate;
                self.probe_len = 0;
                return true;
            }
        }

        const unsigned_len = layout_value.unsignedLen();
        if (!descriptor.isFollowingRecordSignature(self.probe[unsigned_len..][0..4]))
            return false;
        const candidate = descriptor.parseDescriptor(
            layout_value,
            self.probe[0..unsigned_len],
            false,
        );
        if (!self.matches(candidate)) return false;
        self.result_descriptor = candidate;
        @memcpy(&self.next_prefix, self.probe[unsigned_len..][0..4]);
        self.next_prefix_len = 4;
        self.probe_len = 0;
        return true;
    }

    fn matches(self: *const Self, candidate: descriptor.Descriptor) bool {
        const prefixed_size = checkedAdd(
            self.compressed_size,
            self.compressed_size_prefix,
        ) catch return false;
        const compressed_u64 = std.math.cast(u64, prefixed_size) orelse return false;
        const uncompressed_u64 = std.math.cast(u64, self.uncompressed_size) orelse return false;
        return candidate.crc32 == self.crc.digest() and
            candidate.compressed_size == compressed_u64 and
            candidate.uncompressed_size == uncompressed_u64;
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

fn checkedAdd(a: usize, b: usize) error{IntegerOverflow}!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}
