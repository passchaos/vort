const std = @import("std");

const Status = enum(c_int) {
    ok = 0,
    invalid_input = 1,
    buffer_too_small = 2,
    _,
};

const CompressFn = *const fn (
    [*]const u8,
    usize,
    [*]u8,
    *usize,
) callconv(.c) Status;
const UncompressFn = CompressFn;
const MaxCompressedLengthFn = *const fn (usize) callconv(.c) usize;
const UncompressedLengthFn = *const fn (
    [*]const u8,
    usize,
    *usize,
) callconv(.c) Status;
const ValidateCompressedBufferFn = *const fn (
    [*]const u8,
    usize,
) callconv(.c) Status;

/// Test-only dynamically loaded libsnappy C ABI. Vort's production library
/// remains dependency-free; probes and benchmarks use this facade as an
/// independent compatibility oracle.
pub const Runtime = struct {
    library: std.DynLib,
    compress: CompressFn,
    uncompress: UncompressFn,
    max_compressed_length: MaxCompressedLengthFn,
    uncompressed_length: UncompressedLengthFn,
    validate_compressed_buffer: ValidateCompressedBufferFn,

    pub fn open() !Runtime {
        const names = [_][:0]const u8{
            "libsnappy.so.1",
            "/lib/x86_64-linux-gnu/libsnappy.so.1",
            "/usr/lib/x86_64-linux-gnu/libsnappy.so.1",
            "libsnappy.dylib",
        };
        for (names) |name| {
            var library = std.DynLib.openZ(name.ptr) catch continue;
            const compress = library.lookup(CompressFn, "snappy_compress") orelse {
                library.close();
                continue;
            };
            const uncompress = library.lookup(UncompressFn, "snappy_uncompress") orelse {
                library.close();
                continue;
            };
            const max_compressed_length = library.lookup(
                MaxCompressedLengthFn,
                "snappy_max_compressed_length",
            ) orelse {
                library.close();
                continue;
            };
            const uncompressed_length = library.lookup(
                UncompressedLengthFn,
                "snappy_uncompressed_length",
            ) orelse {
                library.close();
                continue;
            };
            const validate_compressed_buffer = library.lookup(
                ValidateCompressedBufferFn,
                "snappy_validate_compressed_buffer",
            ) orelse {
                library.close();
                continue;
            };
            return .{
                .library = library,
                .compress = compress,
                .uncompress = uncompress,
                .max_compressed_length = max_compressed_length,
                .uncompressed_length = uncompressed_length,
                .validate_compressed_buffer = validate_compressed_buffer,
            };
        }
        return error.ReferenceUnavailable;
    }

    pub fn deinit(self: *Runtime) void {
        self.library.close();
        self.* = undefined;
    }

    pub fn encodeAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        input: []const u8,
    ) ![]u8 {
        const bound = self.max_compressed_length(input.len);
        if (bound < input.len) return error.ReferenceEncodeFailed;
        const output = try allocator.alloc(u8, bound);
        errdefer allocator.free(output);
        var written = output.len;
        if (self.compress(input.ptr, input.len, output.ptr, &written) != .ok)
            return error.ReferenceEncodeFailed;
        if (written > output.len) return error.ReferenceEncodeFailed;
        return allocator.realloc(output, written);
    }

    pub fn decodedLength(self: Runtime, encoded: []const u8) !usize {
        var decoded_len: usize = 0;
        if (self.uncompressed_length(encoded.ptr, encoded.len, &decoded_len) != .ok)
            return error.ReferenceDecodeFailed;
        return decoded_len;
    }

    pub fn validate(self: Runtime, encoded: []const u8) !void {
        if (self.validate_compressed_buffer(encoded.ptr, encoded.len) != .ok)
            return error.ReferenceDecodeFailed;
    }

    pub fn decode(self: Runtime, encoded: []const u8, output: []u8) !void {
        var written = output.len;
        if (self.uncompress(encoded.ptr, encoded.len, output.ptr, &written) != .ok)
            return error.ReferenceDecodeFailed;
        if (written != output.len) return error.SizeMismatch;
    }
};
