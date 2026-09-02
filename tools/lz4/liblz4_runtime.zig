const std = @import("std");

const DecompressSafeFn = *const fn (
    [*]const u8,
    [*]u8,
    c_int,
    c_int,
) callconv(.c) c_int;
const CompressBoundFn = *const fn (c_int) callconv(.c) c_int;
const CompressDefaultFn = *const fn (
    [*]const u8,
    [*]u8,
    c_int,
    c_int,
) callconv(.c) c_int;
const VersionStringFn = *const fn () callconv(.c) [*:0]const u8;

pub const Runtime = struct {
    library: std.DynLib,
    decompress_safe: DecompressSafeFn,
    compress_bound: CompressBoundFn,
    compress_default: CompressDefaultFn,
    version_string: VersionStringFn,

    pub fn open() !Runtime {
        const names = [_][:0]const u8{
            "liblz4.so.1",
            "/lib/x86_64-linux-gnu/liblz4.so.1",
            "/usr/lib/x86_64-linux-gnu/liblz4.so.1",
            "liblz4.dylib",
        };
        for (names) |name| {
            var library = std.DynLib.openZ(name.ptr) catch continue;
            const decompress_safe = library.lookup(
                DecompressSafeFn,
                "LZ4_decompress_safe",
            ) orelse {
                library.close();
                continue;
            };
            const version_string = library.lookup(
                VersionStringFn,
                "LZ4_versionString",
            ) orelse {
                library.close();
                continue;
            };
            const compress_bound = library.lookup(
                CompressBoundFn,
                "LZ4_compressBound",
            ) orelse {
                library.close();
                continue;
            };
            const compress_default = library.lookup(
                CompressDefaultFn,
                "LZ4_compress_default",
            ) orelse {
                library.close();
                continue;
            };
            return .{
                .library = library,
                .decompress_safe = decompress_safe,
                .compress_bound = compress_bound,
                .compress_default = compress_default,
                .version_string = version_string,
            };
        }
        return error.ReferenceUnavailable;
    }

    pub fn deinit(self: *Runtime) void {
        self.library.close();
        self.* = undefined;
    }

    pub fn version(self: Runtime) []const u8 {
        return std.mem.span(self.version_string());
    }

    pub fn decode(
        self: Runtime,
        encoded: []const u8,
        output: []u8,
    ) !void {
        const encoded_len = std.math.cast(c_int, encoded.len) orelse
            return error.InputTooLarge;
        const output_len = std.math.cast(c_int, output.len) orelse
            return error.OutputLimitExceeded;
        const written = self.decompress_safe(
            encoded.ptr,
            output.ptr,
            encoded_len,
            output_len,
        );
        if (written < 0) return error.ReferenceDecodeFailed;
        if (written != output_len) return error.SizeMismatch;
    }

    pub fn encodeAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        input: []const u8,
    ) ![]u8 {
        const input_len = std.math.cast(c_int, input.len) orelse
            return error.InputTooLarge;
        const bound = self.compress_bound(input_len);
        if (bound <= 0) return error.ReferenceEncodeFailed;
        const output = try allocator.alloc(u8, @intCast(bound));
        errdefer allocator.free(output);
        const written = self.compress_default(
            input.ptr,
            output.ptr,
            input_len,
            bound,
        );
        if (written <= 0) return error.ReferenceEncodeFailed;
        return allocator.realloc(output, @intCast(written));
    }
};
