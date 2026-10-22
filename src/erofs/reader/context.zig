const std = @import("std");
const metadata = @import("inode.zig");
const devices_module = @import("devices.zig");
const source_module = @import("../../io/source.zig");
const input_module = @import("input.zig");
const codec = @import("../codec.zig");
const format = @import("../format.zig");

pub const Error = metadata.Error || devices_module.Error || codec.Error || std.mem.Allocator.Error;
pub const Limits = struct {
    max_encoded_extent_size: usize = 8 * 1024 * 1024,
    max_decoded_extent_size: usize = 8 * 1024 * 1024,
    max_packed_extent_size: usize = 8 * 1024 * 1024,
};

pub const Context = struct {
    allocator: std.mem.Allocator,
    reader: metadata.Reader,
    devices: devices_module.Devices(source_module.Source),
    limits: Limits,

    pub fn encoded(self: Context, input: input_module.Input, start: u64, size: usize) Error![]u8 {
        if (size > self.limits.max_encoded_extent_size) return error.OutputLimitExceeded;
        _ = try input.endAt(start, size);
        const buffer = try self.allocator.alloc(u8, size);
        errdefer self.allocator.free(buffer);
        try input.readAt(start, buffer);
        return buffer;
    }

    pub fn decode(self: Context, algorithm: format.Compression, input: input_module.Input, start: u64, encoded_size: usize, decoded_size: usize) Error![]u8 {
        if (decoded_size > self.limits.max_decoded_extent_size) return error.OutputLimitExceeded;
        const encoded_bytes = try self.encoded(input, start, encoded_size);
        defer self.allocator.free(encoded_bytes);
        return codec.decodeExtentAlloc(self.allocator, algorithm, encoded_bytes, decoded_size, self.reader.superblock.feature_incompat & 1 != 0);
    }
};

pub fn add(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

pub fn offset(base: u64, delta: usize) Error!u64 {
    return std.math.add(u64, base, delta) catch error.IntegerOverflow;
}
