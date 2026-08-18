const std = @import("std");

const MaxCompressedSizeFn = *const fn (usize) callconv(.c) usize;
const CompressFn = *const fn (
    c_int,
    c_int,
    c_int,
    usize,
    [*]const u8,
    *usize,
    [*]u8,
) callconv(.c) bool;
const DecompressFn = *const fn (
    usize,
    [*]const u8,
    *usize,
    [*]u8,
) callconv(.c) c_int;
const VersionFn = *const fn () callconv(.c) u32;

pub const Runtime = struct {
    encoder: std.DynLib,
    decoder: std.DynLib,
    max_compressed_size: MaxCompressedSizeFn,
    compress: CompressFn,
    decompress: DecompressFn,
    encoder_version: VersionFn,
    decoder_version: VersionFn,

    pub fn open() !Runtime {
        var encoder = try openLibrary(&.{
            "libbrotlienc.so.1",
            "/lib/x86_64-linux-gnu/libbrotlienc.so.1",
            "/usr/lib/x86_64-linux-gnu/libbrotlienc.so.1",
            "libbrotlienc.dylib",
        });
        errdefer encoder.close();
        var decoder = try openLibrary(&.{
            "libbrotlidec.so.1",
            "/lib/x86_64-linux-gnu/libbrotlidec.so.1",
            "/usr/lib/x86_64-linux-gnu/libbrotlidec.so.1",
            "libbrotlidec.dylib",
        });
        errdefer decoder.close();
        return .{
            .encoder = encoder,
            .decoder = decoder,
            .max_compressed_size = encoder.lookup(MaxCompressedSizeFn, "BrotliEncoderMaxCompressedSize") orelse return error.ReferenceUnavailable,
            .compress = encoder.lookup(CompressFn, "BrotliEncoderCompress") orelse return error.ReferenceUnavailable,
            .decompress = decoder.lookup(DecompressFn, "BrotliDecoderDecompress") orelse return error.ReferenceUnavailable,
            .encoder_version = encoder.lookup(VersionFn, "BrotliEncoderVersion") orelse return error.ReferenceUnavailable,
            .decoder_version = decoder.lookup(VersionFn, "BrotliDecoderVersion") orelse return error.ReferenceUnavailable,
        };
    }

    pub fn deinit(self: *Runtime) void {
        self.encoder.close();
        self.decoder.close();
        self.* = undefined;
    }

    pub fn version(self: Runtime) u32 {
        const encoder = self.encoder_version();
        std.debug.assert(encoder == self.decoder_version());
        return encoder;
    }

    pub fn encodeAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        input: []const u8,
        quality: c_int,
    ) ![]u8 {
        const bound = self.max_compressed_size(input.len);
        if (bound == 0) return error.ReferenceEncodeFailed;
        const output = try allocator.alloc(u8, bound);
        errdefer allocator.free(output);
        var written = output.len;
        if (!self.compress(quality, 22, 0, input.len, input.ptr, &written, output.ptr)) {
            return error.ReferenceEncodeFailed;
        }
        return allocator.realloc(output, written);
    }

    pub fn decode(self: Runtime, encoded: []const u8, output: []u8) !void {
        var written = output.len;
        if (self.decompress(encoded.len, encoded.ptr, &written, output.ptr) != 1) {
            return error.ReferenceDecodeFailed;
        }
        if (written != output.len) return error.SizeMismatch;
    }
};

fn openLibrary(names: []const [:0]const u8) !std.DynLib {
    for (names) |name| {
        if (std.DynLib.openZ(name.ptr)) |library| return library else |_| {}
    }
    return error.ReferenceUnavailable;
}
