const std = @import("std");
const checksum = @import("../../checksum.zig");
const core = @import("../../core.zig");
const wire = @import("../wire.zig");

pub const Layout = enum {
    zip32,
    zip64,

    pub fn signedLen(self: Layout) usize {
        return switch (self) {
            .zip32 => wire.data_descriptor_len,
            .zip64 => wire.zip64_data_descriptor_len,
        };
    }

    pub fn unsignedLen(self: Layout) usize {
        return self.signedLen() - 4;
    }
};

pub const Descriptor = struct {
    crc32: u32,
    compressed_size: u64,
    uncompressed_size: u64,
    signed: bool,
    zip64: bool,
};

pub const StepResult = struct {
    progress: core.Progress = .{},
    status: Status,

    pub const Status = enum {
        need_input,
        need_output,
        done,
    };
};

/// Streaming boundary detector for Stored entries that use bit-3 data
/// descriptors. It holds at most one descriptor plus the following four-byte
/// record signature (16 bytes for ZIP32, 24 for ZIP64), so false descriptor
/// signatures in payload data remain byte-exact under arbitrary backpressure.
///
/// Signed descriptors are recognized directly. Unsigned descriptors are
/// accepted only when followed by a supported ZIP record signature and when
/// CRC/compressed/uncompressed values all match the payload released so far.
pub const StoredScanner = struct {
    layout: Layout,
    max_output_len: usize,
    buffer: [wire.zip64_data_descriptor_len]u8 = undefined,
    buffer_len: usize = 0,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    payload_size: usize = 0,
    result_descriptor: ?Descriptor = null,
    next_prefix: [4]u8 = undefined,
    next_prefix_len: usize = 0,

    const Self = @This();

    pub fn init(layout: Layout, max_output_len: usize) Self {
        return .{ .layout = layout, .max_output_len = max_output_len };
    }

    pub fn reset(self: *Self, layout: Layout, max_output_len: usize) void {
        self.* = init(layout, max_output_len);
    }

    pub fn descriptor(self: *const Self) ?Descriptor {
        return self.result_descriptor;
    }

    pub fn retainedRecordPrefix(self: *const Self) []const u8 {
        return self.next_prefix[0..self.next_prefix_len];
    }

    pub fn outputWritten(self: *const Self) usize {
        return self.payload_size;
    }

    pub fn finish(self: *const Self) error{TruncatedFrame}!void {
        if (self.result_descriptor == null) return error.TruncatedFrame;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) error{OutputLimitExceeded}!StepResult {
        if (self.result_descriptor != null) return .{ .status = .done };
        var input_read: usize = 0;
        var output_written: usize = 0;
        const capacity = self.layout.signedLen();

        while (true) {
            if (self.buffer_len == capacity) {
                if (self.detectBoundary())
                    return result(input_read, output_written, .done);
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
                if (self.payload_size == self.max_output_len)
                    return error.OutputLimitExceeded;
                const byte = self.buffer[0];
                output[output_written] = byte;
                output_written += 1;
                self.crc.update(self.buffer[0..1]);
                self.payload_size += 1;
                std.mem.copyForwards(u8, self.buffer[0 .. capacity - 1], self.buffer[1..capacity]);
                self.buffer_len -= 1;
                continue;
            }

            if (input_read == input.len)
                return result(input_read, output_written, .need_input);
            self.buffer[self.buffer_len] = input[input_read];
            self.buffer_len += 1;
            input_read += 1;
        }
    }

    fn detectBoundary(self: *Self) bool {
        const signed_len = self.layout.signedLen();
        std.debug.assert(self.buffer_len == signed_len);
        if (std.mem.readInt(u32, self.buffer[0..4], .little) == wire.data_descriptor_signature) {
            const candidate = parseDescriptor(self.layout, self.buffer[0..signed_len], true);
            if (self.matches(candidate)) {
                self.result_descriptor = candidate;
                self.buffer_len = 0;
                return true;
            }
        }

        const unsigned_len = self.layout.unsignedLen();
        if (!isFollowingRecordSignature(self.buffer[unsigned_len..][0..4])) return false;
        const candidate = parseDescriptor(self.layout, self.buffer[0..unsigned_len], false);
        if (!self.matches(candidate)) return false;
        self.result_descriptor = candidate;
        @memcpy(&self.next_prefix, self.buffer[unsigned_len..][0..4]);
        self.next_prefix_len = 4;
        self.buffer_len = 0;
        return true;
    }

    fn matches(self: *const Self, candidate: Descriptor) bool {
        return candidate.crc32 == self.crc.digest() and
            candidate.compressed_size == self.payload_size and
            candidate.uncompressed_size == self.payload_size;
    }

    fn result(input_read: usize, output_written: usize, status: StepResult.Status) StepResult {
        return .{
            .progress = .{ .input_read = input_read, .output_written = output_written },
            .status = status,
        };
    }
};

pub fn parseDescriptor(layout: Layout, bytes: []const u8, signed: bool) Descriptor {
    const prefix: usize = if (signed) 4 else 0;
    std.debug.assert(bytes.len == if (signed) layout.signedLen() else layout.unsignedLen());
    if (signed)
        std.debug.assert(std.mem.readInt(u32, bytes[0..4], .little) == wire.data_descriptor_signature);
    const crc = std.mem.readInt(u32, bytes[prefix..][0..4], .little);
    return switch (layout) {
        .zip32 => .{
            .crc32 = crc,
            .compressed_size = std.mem.readInt(u32, bytes[prefix + 4 ..][0..4], .little),
            .uncompressed_size = std.mem.readInt(u32, bytes[prefix + 8 ..][0..4], .little),
            .signed = signed,
            .zip64 = false,
        },
        .zip64 => .{
            .crc32 = crc,
            .compressed_size = std.mem.readInt(u64, bytes[prefix + 4 ..][0..8], .little),
            .uncompressed_size = std.mem.readInt(u64, bytes[prefix + 12 ..][0..8], .little),
            .signed = signed,
            .zip64 = true,
        },
    };
}

pub fn isFollowingRecordSignature(bytes: *const [4]u8) bool {
    return switch (std.mem.readInt(u32, bytes, .little)) {
        wire.local_file_signature,
        wire.central_file_signature,
        wire.zip64_end_of_central_signature,
        wire.end_of_central_signature,
        => true,
        else => false,
    };
}
