//! Bounded positional reader for one 7z packed branch, with optional AES.

const std = @import("std");
const archive_mod = @import("../archive.zig");
const aes = @import("../aes.zig");
const checksum = @import("../../checksum.zig");
const crypto = @import("vail_archive_crypto").seven_zip;
const packed_input = @import("../packed_input.zig");
const source_mod = @import("../source.zig");
const streams_mod = @import("../streams.zig");

pub const Error = archive_mod.Error || source_mod.Error || aes.Error ||
    crypto.Error || std.mem.Allocator.Error;

pub const Reader = struct {
    allocator: std.mem.Allocator,
    source: source_mod.Source,
    source_offset: u64,
    packed_remaining: usize,
    plain_size: usize,
    plain_remaining: usize,
    crc_expected: ?u32,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    buffer: []u8,
    start: usize = 0,
    len: usize = 0,
    decryptor: ?crypto.Decryptor = null,
    validated: bool = false,

    pub fn init(
        allocator: std.mem.Allocator,
        source: source_mod.Source,
        streams: *const streams_mod.Streams,
        packed_data_limit: u64,
        pack_index: usize,
        aes_coder: ?streams_mod.Coder,
        aes_plain_size: ?u64,
        password: ?[]const u8,
        max_kdf_cycles_power: u6,
        max_packed_stream_size: usize,
        requested_buffer_size: usize,
    ) Error!Reader {
        if (requested_buffer_size == 0) return error.OutputLimitExceeded;
        const packed_source = packed_input.Input.fromSource(
            source,
            packed_data_limit,
            max_packed_stream_size,
        );
        const stream_range = try packed_input.packRange(packed_source, streams, pack_index);
        const packed_size = std.math.cast(usize, stream_range.size) orelse
            return error.OutputLimitExceeded;
        if (packed_size > max_packed_stream_size) return error.OutputLimitExceeded;

        var buffer_size = requested_buffer_size;
        var decryptor: ?crypto.Decryptor = null;
        var plain_size = packed_size;
        if (aes_coder) |coder| {
            buffer_size &= ~(crypto.block_len - 1);
            if (buffer_size < crypto.block_len) return error.OutputLimitExceeded;
            const properties = aes.parseProperties(coder.propertyBytes()) catch
                return error.Invalid7zArchive;
            plain_size = std.math.cast(usize, aes_plain_size orelse return error.Invalid7zArchive) orelse
                return error.OutputLimitExceeded;
            if (packed_size & (crypto.block_len - 1) != 0 or
                plain_size > packed_size or packed_size - plain_size >= crypto.block_len)
                return error.Invalid7zArchive;
            const password_bytes = password orelse return error.PasswordRequired;
            var key = try aes.deriveKey(
                allocator,
                password_bytes,
                properties,
                max_kdf_cycles_power,
            );
            defer std.crypto.secureZero(u8, &key);
            decryptor = crypto.Decryptor.init(key, properties.iv);
        }
        errdefer if (decryptor) |*state| state.deinit();
        const buffer = try allocator.alloc(u8, buffer_size);
        return .{
            .allocator = allocator,
            .source = source,
            .source_offset = stream_range.start,
            .packed_remaining = packed_size,
            .plain_size = plain_size,
            .plain_remaining = if (decryptor != null) plain_size else 0,
            .crc_expected = streams.pack_crcs[pack_index],
            .buffer = buffer,
            .decryptor = decryptor,
        };
    }

    pub fn deinit(self: *Reader) void {
        if (self.decryptor) |*decryptor| decryptor.deinit();
        self.allocator.free(self.buffer);
        self.* = undefined;
    }

    pub fn available(self: *const Reader) []const u8 {
        return self.buffer[self.start..self.len];
    }

    pub fn totalPlainSize(self: *const Reader) usize {
        return self.plain_size;
    }

    pub fn consume(self: *Reader, count: usize) Error!void {
        if (count > self.len - self.start) return error.Invalid7zArchive;
        self.start += count;
        if (self.start == self.len) {
            self.start = 0;
            self.len = 0;
        }
    }

    pub fn fill(self: *Reader) Error!usize {
        try self.compact();
        if (self.packed_remaining == 0) return 0;
        const available_capacity = self.buffer.len - self.len;
        var count = @min(available_capacity, self.packed_remaining);
        if (self.decryptor != null) {
            count &= ~(crypto.block_len - 1);
            if (count == 0) return error.OutputLimitExceeded;
        }
        const destination = self.buffer[self.len..][0..count];
        try self.source.readExact(self.source_offset, destination);
        self.crc.update(destination);
        self.source_offset = std.math.add(u64, self.source_offset, count) catch
            return error.IntegerOverflow;
        self.packed_remaining -= count;
        const exposed = if (self.decryptor) |*decryptor| decrypted: {
            decryptor.decryptBlocks(destination, destination) catch
                return error.Invalid7zArchive;
            const plain = @min(count, self.plain_remaining);
            self.plain_remaining -= plain;
            break :decrypted plain;
        } else count;
        self.len += exposed;
        return count;
    }

    pub fn readByte(self: *Reader, source_read: *usize) Error!u8 {
        if (self.start == self.len) {
            source_read.* = std.math.add(usize, source_read.*, try self.fill()) catch
                return error.IntegerOverflow;
            if (self.start == self.len) return error.TruncatedFrame;
        }
        const byte = self.buffer[self.start];
        try self.consume(1);
        return byte;
    }

    pub fn readExact(
        self: *Reader,
        output: []u8,
        source_read: *usize,
    ) Error!void {
        var written: usize = 0;
        while (written < output.len) {
            if (self.start == self.len) {
                source_read.* = std.math.add(usize, source_read.*, try self.fill()) catch
                    return error.IntegerOverflow;
                if (self.start == self.len) return error.TruncatedFrame;
            }
            const count = @min(output.len - written, self.len - self.start);
            @memcpy(output[written..][0..count], self.buffer[self.start..][0..count]);
            try self.consume(count);
            written += count;
        }
    }

    pub fn hasRemaining(self: *const Reader) bool {
        return self.start != self.len or self.packed_remaining != 0 or
            self.plain_remaining != 0;
    }

    pub fn finish(self: *Reader) Error!void {
        if (self.validated) return;
        if (self.hasRemaining()) return error.SizeMismatch;
        if (self.crc_expected) |expected|
            if (self.crc.digest() != expected) return error.ChecksumMismatch;
        self.validated = true;
    }

    fn compact(self: *Reader) Error!void {
        if (self.start == 0) return;
        const remaining = self.len - self.start;
        std.mem.copyForwards(u8, self.buffer[0..remaining], self.buffer[self.start..self.len]);
        self.start = 0;
        self.len = remaining;
    }
};
