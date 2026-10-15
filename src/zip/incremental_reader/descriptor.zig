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
    compressed_size_prefix: usize,
    buffer: [wire.zip64_data_descriptor_len]u8 = undefined,
    payload_buffer: [wire.zip64_data_descriptor_len]u8 = undefined,
    buffer_len: usize = 0,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    payload_size: usize = 0,
    result_descriptor: ?Descriptor = null,
    next_prefix: [4]u8 = undefined,
    next_prefix_len: usize = 0,

    const Self = @This();

    pub fn init(layout: Layout, max_output_len: usize) Self {
        return initWithCompressedSizePrefix(layout, max_output_len, 0);
    }

    pub fn initWithCompressedSizePrefix(
        layout: Layout,
        max_output_len: usize,
        compressed_size_prefix: usize,
    ) Self {
        return .{
            .layout = layout,
            .max_output_len = max_output_len,
            .compressed_size_prefix = compressed_size_prefix,
        };
    }

    pub fn reset(self: *Self, layout: Layout, max_output_len: usize) void {
        self.deinit();
        self.* = init(layout, max_output_len);
    }

    pub fn deinit(self: *Self) void {
        std.crypto.secureZero(u8, &self.payload_buffer);
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
        return self.stepPaired(input, input, output);
    }

    /// `raw_input` owns ZIP descriptor bytes while `payload_input` contains
    /// the byte-for-byte codec view. They differ only for encrypted entries.
    pub fn stepPaired(
        self: *Self,
        raw_input: []const u8,
        payload_input: []const u8,
        output: []u8,
    ) error{OutputLimitExceeded}!StepResult {
        std.debug.assert(raw_input.len == payload_input.len);
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
                const byte = self.payload_buffer[0];
                output[output_written] = byte;
                output_written += 1;
                self.crc.update(self.payload_buffer[0..1]);
                self.payload_size += 1;
                std.mem.copyForwards(u8, self.buffer[0 .. capacity - 1], self.buffer[1..capacity]);
                std.mem.copyForwards(
                    u8,
                    self.payload_buffer[0 .. capacity - 1],
                    self.payload_buffer[1..capacity],
                );
                self.buffer_len -= 1;
                continue;
            }

            if (input_read == raw_input.len)
                return result(input_read, output_written, .need_input);
            self.buffer[self.buffer_len] = raw_input[input_read];
            self.payload_buffer[self.buffer_len] = payload_input[input_read];
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
        const compressed_size = std.math.add(
            usize,
            self.payload_size,
            self.compressed_size_prefix,
        ) catch return false;
        return candidate.crc32 == self.crc.digest() and
            candidate.compressed_size == compressed_size and
            candidate.uncompressed_size == self.payload_size;
    }

    fn result(input_read: usize, output_written: usize, status: StepResult.Status) StepResult {
        return .{
            .progress = .{ .input_read = input_read, .output_written = output_written },
            .status = status,
        };
    }
};

pub const ParsedBoundary = struct {
    descriptor: Descriptor,
    next_prefix: [4]u8 = undefined,
    next_prefix_len: usize = 0,

    pub fn retainedRecordPrefix(self: *const ParsedBoundary) []const u8 {
        return self.next_prefix[0..self.next_prefix_len];
    }
};

pub const ParserStep = struct {
    input_read: usize,
    boundary: ?ParsedBoundary = null,
};

/// Descriptor parser used after a self-delimiting codec (Deflate, Bzip2, or
/// Zstandard) has established its compressed and decoded byte counts.
pub const Parser = struct {
    buffer: [wire.zip64_data_descriptor_len]u8 = undefined,
    buffer_len: usize = 0,
    target_len: usize = 4,
    layout: Layout = .zip32,
    expected_crc32: u32 = 0,
    expected_compressed_size: usize = 0,
    expected_uncompressed_size: usize = 0,

    const Self = @This();

    pub fn reset(self: *Self) void {
        self.* = .{};
    }

    pub fn begin(
        self: *Self,
        layout: Layout,
        crc32: u32,
        compressed_size: usize,
        uncompressed_size: usize,
        buffered_suffix: []const u8,
    ) error{InvalidZipArchive}!void {
        if (buffered_suffix.len >= layout.unsignedLen() or buffered_suffix.len > self.buffer.len)
            return error.InvalidZipArchive;
        self.* = .{
            .layout = layout,
            .expected_crc32 = crc32,
            .expected_compressed_size = compressed_size,
            .expected_uncompressed_size = uncompressed_size,
        };
        @memcpy(self.buffer[0..buffered_suffix.len], buffered_suffix);
        self.buffer_len = buffered_suffix.len;
    }

    pub fn step(self: *Self, input: []const u8) error{InvalidZipArchive}!ParserStep {
        var input_read: usize = 0;
        while (true) {
            if (self.target_len == 4 and self.buffer_len >= 4) {
                self.target_len = if (std.mem.readInt(u32, self.buffer[0..4], .little) == wire.data_descriptor_signature)
                    self.layout.signedLen()
                else
                    self.layout.unsignedLen();
                continue;
            }
            while (self.buffer_len < self.target_len and input_read < input.len) {
                self.buffer[self.buffer_len] = input[input_read];
                self.buffer_len += 1;
                input_read += 1;
            }
            if (self.buffer_len != self.target_len) return .{ .input_read = input_read };
            if (self.target_len == 4) continue;
            break;
        }

        const signed_prefix = std.mem.readInt(u32, self.buffer[0..4], .little) == wire.data_descriptor_signature;
        var parsed = parseDescriptor(
            self.layout,
            self.buffer[0..self.target_len],
            signed_prefix,
        );
        var boundary: ParsedBoundary = .{ .descriptor = parsed };
        if (!self.matches(parsed)) {
            if (!signed_prefix) return error.InvalidZipArchive;
            const unsigned_len = self.layout.unsignedLen();
            parsed = parseDescriptor(self.layout, self.buffer[0..unsigned_len], false);
            if (!self.matches(parsed) or
                !isFollowingRecordSignature(self.buffer[unsigned_len..][0..4]))
                return error.InvalidZipArchive;
            boundary.descriptor = parsed;
            @memcpy(&boundary.next_prefix, self.buffer[unsigned_len..][0..4]);
            boundary.next_prefix_len = 4;
        }
        return .{ .input_read = input_read, .boundary = boundary };
    }

    fn matches(self: *const Self, parsed: Descriptor) bool {
        return parsed.crc32 == self.expected_crc32 and
            parsed.compressed_size == self.expected_compressed_size and
            parsed.uncompressed_size == self.expected_uncompressed_size;
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
