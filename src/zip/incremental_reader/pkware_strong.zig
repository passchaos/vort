//! Fragmented PKWARE Strong decryption-header and CBC state for ZIP reading.

const std = @import("std");
const descriptor = @import("descriptor.zig");
const types = @import("../types.zig");
const strong_wire = @import("../pkware_strong.zig");
const strong_stream = @import("vail_archive_crypto").pkware_strong_decrypt_stream;

pub const Error = strong_wire.Error || std.mem.Allocator.Error || error{
    InvalidZipArchive,
    OutputLimitExceeded,
};

pub const State = struct {
    header: std.ArrayList(u8) = .empty,
    header_target: usize = 2,
    header_stage: HeaderStage = .iv_size,
    decryptor: ?strong_stream.Decryptor = null,
    info: ?types.PkwareStrongEncryptionInfo = null,
    outer_compressed_size: ?usize,
    descriptor_layout: ?descriptor.Layout,
    ciphertext_remaining: ?usize = null,
    ciphertext_consumed: usize = 0,
    decrypted_size: usize = 0,
    plaintext: [256]u8 = undefined,
    plaintext_pos: usize = 0,
    plaintext_len: usize = 0,
    decrypt_done: bool = false,
    codec_input_finished: bool = false,
    codec_done: bool = false,
    pending_codec_validation: ?CodecValidation = null,
    descriptor_probe: [28]u8 = undefined,
    descriptor_probe_len: usize = 0,
    result_descriptor: ?descriptor.Descriptor = null,
    next_prefix: [4]u8 = undefined,
    next_prefix_len: usize = 0,

    const Self = @This();

    const HeaderStage = enum {
        iv_size,
        remaining_size,
        body,
        ready,
    };

    pub const CodecValidation = struct {
        crc32: u32,
        compressed_size: usize,
        uncompressed_size: usize,
    };

    pub fn init(
        outer_compressed_size: ?usize,
        descriptor_layout: ?descriptor.Layout,
    ) Self {
        return .{
            .outer_compressed_size = outer_compressed_size,
            .descriptor_layout = descriptor_layout,
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.decryptor) |*decryptor| decryptor.deinit();
        std.crypto.secureZero(u8, self.header.items);
        self.header.deinit(allocator);
        std.crypto.secureZero(u8, &self.plaintext);
        std.crypto.secureZero(u8, &self.descriptor_probe);
        self.* = undefined;
    }

    pub fn feedHeader(
        self: *Self,
        allocator: std.mem.Allocator,
        input: []const u8,
        max_header_size: usize,
        password: []const u8,
        crc32: ?u32,
        uncompressed_size: ?usize,
    ) Error!usize {
        if (self.header_stage == .ready) return 0;
        var input_read: usize = 0;
        while (self.header_stage != .ready and input_read < input.len) {
            if (self.header_target > max_header_size) return error.OutputLimitExceeded;
            const take = @min(
                self.header_target - self.header.items.len,
                input.len - input_read,
            );
            try self.header.appendSlice(allocator, input[input_read..][0..take]);
            input_read += take;
            if (self.header.items.len != self.header_target) break;
            switch (self.header_stage) {
                .iv_size => {
                    const iv_size = std.mem.readInt(u16, self.header.items[0..2], .little);
                    if (iv_size != 0 and iv_size != strong_wire.explicit_iv_len)
                        return error.UnsupportedStrongEncryptionFeature;
                    self.header_target = try checkedAdd(
                        @sizeOf(u16) + @as(usize, iv_size),
                        @sizeOf(u32),
                    );
                    self.header_stage = .remaining_size;
                },
                .remaining_size => {
                    const remaining_size: usize = std.mem.readInt(
                        u32,
                        self.header.items[self.header.items.len - 4 ..][0..4],
                        .little,
                    );
                    if (remaining_size < strong_wire.fixed_remaining_len or
                        remaining_size > strong_wire.max_remaining_len)
                        return error.InvalidStrongEncryptionHeader;
                    self.header_target = try checkedAdd(self.header.items.len, remaining_size);
                    self.header_stage = .body;
                },
                .body => {
                    var prepared = try strong_wire.prepareStreamDecryptAlloc(
                        allocator,
                        self.header.items,
                        password,
                        null,
                        crc32,
                        if (uncompressed_size) |size| @intCast(size) else null,
                    );
                    errdefer prepared.deinit();
                    if (self.outer_compressed_size) |outer_size| {
                        const minimum = try checkedAdd(prepared.header_len, strong_wire.block_len);
                        if (outer_size < minimum) return error.InvalidZipArchive;
                        const ciphertext_len = outer_size - prepared.header_len;
                        if (ciphertext_len % strong_wire.block_len != 0)
                            return error.InvalidZipArchive;
                        self.ciphertext_remaining = ciphertext_len;
                    }
                    self.info = .{ .strength = prepared.strength };
                    self.decryptor = prepared.decryptor;
                    prepared = undefined;
                    self.header_stage = .ready;
                },
                .ready => unreachable,
            }
        }
        return input_read;
    }

    pub fn ready(self: *const Self) bool {
        return self.header_stage == .ready;
    }

    pub fn headerLen(self: *const Self) usize {
        std.debug.assert(self.ready());
        return self.header.items.len;
    }

    pub fn outerSize(self: *const Self) Error!usize {
        return checkedAdd(self.headerLen(), self.ciphertext_consumed);
    }

    pub fn remainingKnownCiphertext(self: *const Self) Error!usize {
        return self.ciphertext_remaining orelse error.InvalidZipArchive;
    }

    pub fn descriptorProbeTarget(self: *const Self) Error!usize {
        return (self.descriptor_layout orelse return error.InvalidZipArchive).signedLen();
    }

    pub fn appendDescriptorProbe(self: *Self, input: []const u8) Error!usize {
        const target = try self.descriptorProbeTarget();
        const take = @min(target - self.descriptor_probe_len, input.len);
        @memcpy(self.descriptor_probe[self.descriptor_probe_len..][0..take], input[0..take]);
        self.descriptor_probe_len += take;
        return take;
    }

    pub fn detectDescriptor(self: *Self) Error!bool {
        const layout = self.descriptor_layout orelse return error.InvalidZipArchive;
        const target = layout.signedLen();
        if (self.descriptor_probe_len != target) return false;
        const expected_compressed_size = try self.outerSize();
        if (std.mem.readInt(u32, self.descriptor_probe[0..4], .little) ==
            @import("../wire.zig").data_descriptor_signature)
        {
            const candidate = descriptor.parseDescriptor(
                layout,
                self.descriptor_probe[0..target],
                true,
            );
            if (candidate.compressed_size == expected_compressed_size) {
                self.result_descriptor = candidate;
                self.descriptor_probe_len = 0;
                return true;
            }
        }
        const unsigned_len = layout.unsignedLen();
        if (!descriptor.isFollowingRecordSignature(
            self.descriptor_probe[unsigned_len..][0..4],
        )) return false;
        const candidate = descriptor.parseDescriptor(
            layout,
            self.descriptor_probe[0..unsigned_len],
            false,
        );
        if (candidate.compressed_size != expected_compressed_size) return false;
        self.result_descriptor = candidate;
        @memcpy(&self.next_prefix, self.descriptor_probe[unsigned_len..][0..4]);
        self.next_prefix_len = 4;
        self.descriptor_probe_len = 0;
        return true;
    }

    pub fn shiftCiphertextBlock(self: *Self) Error![strong_wire.block_len]u8 {
        if (self.descriptor_probe_len < strong_wire.block_len)
            return error.InvalidZipArchive;
        const block = self.descriptor_probe[0..strong_wire.block_len].*;
        const retained = self.descriptor_probe_len - strong_wire.block_len;
        std.mem.copyForwards(
            u8,
            self.descriptor_probe[0..retained],
            self.descriptor_probe[strong_wire.block_len..self.descriptor_probe_len],
        );
        self.descriptor_probe_len = retained;
        return block;
    }

    pub fn retainedRecordPrefix(self: *const Self) []const u8 {
        return self.next_prefix[0..self.next_prefix_len];
    }
};

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}
