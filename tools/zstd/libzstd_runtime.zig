const std = @import("std");

const CompressBoundFn = *const fn (usize) callconv(.c) usize;
const CompressFn = *const fn (
    [*]u8,
    usize,
    [*]const u8,
    usize,
    c_int,
) callconv(.c) usize;
const DecompressFn = *const fn (
    [*]u8,
    usize,
    [*]const u8,
    usize,
) callconv(.c) usize;
const IsErrorFn = *const fn (usize) callconv(.c) c_uint;
const VersionStringFn = *const fn () callconv(.c) [*:0]const u8;

pub const Runtime = struct {
    library: std.DynLib,
    compress_bound: CompressBoundFn,
    compress: CompressFn,
    decompress: DecompressFn,
    is_error: IsErrorFn,
    version_string: VersionStringFn,

    pub fn open() !Runtime {
        const names = [_][:0]const u8{
            "libzstd.so.1",
            "/lib/x86_64-linux-gnu/libzstd.so.1",
            "/usr/lib/x86_64-linux-gnu/libzstd.so.1",
            "libzstd.dylib",
        };
        for (names) |name| {
            var library = std.DynLib.openZ(name.ptr) catch continue;
            const compress_bound = library.lookup(
                CompressBoundFn,
                "ZSTD_compressBound",
            ) orelse {
                library.close();
                continue;
            };
            const compress = library.lookup(
                CompressFn,
                "ZSTD_compress",
            ) orelse {
                library.close();
                continue;
            };
            const decompress = library.lookup(
                DecompressFn,
                "ZSTD_decompress",
            ) orelse {
                library.close();
                continue;
            };
            const is_error = library.lookup(
                IsErrorFn,
                "ZSTD_isError",
            ) orelse {
                library.close();
                continue;
            };
            const version_string = library.lookup(
                VersionStringFn,
                "ZSTD_versionString",
            ) orelse {
                library.close();
                continue;
            };
            return .{
                .library = library,
                .compress_bound = compress_bound,
                .compress = compress,
                .decompress = decompress,
                .is_error = is_error,
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

    pub fn encodeAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        input: []const u8,
        level: c_int,
    ) ![]u8 {
        const bound = self.compress_bound(input.len);
        if (self.is_error(bound) != 0) return error.ReferenceEncodeFailed;
        const output = try allocator.alloc(u8, bound);
        errdefer allocator.free(output);
        const written = self.compress(
            output.ptr,
            output.len,
            input.ptr,
            input.len,
            level,
        );
        if (self.is_error(written) != 0) return error.ReferenceEncodeFailed;
        return allocator.realloc(output, written);
    }

    pub fn decode(
        self: Runtime,
        encoded: []const u8,
        output: []u8,
    ) !void {
        const written = self.decompress(
            output.ptr,
            output.len,
            encoded.ptr,
            encoded.len,
        );
        if (self.is_error(written) != 0) return error.ReferenceDecodeFailed;
        if (written != output.len) return error.SizeMismatch;
    }
};
