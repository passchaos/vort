//! Benchmark-only libbz2 facade; the production Bzip2 codec has no C dependency.
const std = @import("std");
const Compress = *const fn ([*]u8, *c_uint, [*]const u8, c_uint, c_int, c_int, c_int) callconv(.c) c_int;
const Version = *const fn () callconv(.c) [*:0]const u8;

pub const Runtime = struct {
    library: std.DynLib,
    compress: Compress,
    version: Version,

    pub fn open(path: [:0]const u8) !Runtime {
        var library = try std.DynLib.openZ(path.ptr);
        errdefer library.close();
        return .{
            .library = library,
            .compress = library.lookup(Compress, "BZ2_bzBuffToBuffCompress") orelse return error.ReferenceUnavailable,
            .version = library.lookup(Version, "BZ2_bzlibVersion") orelse return error.ReferenceUnavailable,
        };
    }

    pub fn deinit(self: *Runtime) void {
        self.library.close();
    }

    pub fn encodeAlloc(self: Runtime, allocator: std.mem.Allocator, input: []const u8, block_size: u4) ![]u8 {
        if (input.len > std.math.maxInt(c_uint) or block_size < 1 or block_size > 9) return error.InvalidArgument;
        // The documented one-shot bound. Allocation and final shrinking are
        // included in the native timer, matching Vort's allocating API scope.
        const overhead = std.math.add(usize, input.len / 100, 600) catch return error.InvalidArgument;
        const bound = std.math.add(usize, input.len, overhead) catch return error.InvalidArgument;
        if (bound > std.math.maxInt(c_uint)) return error.InvalidArgument;
        const output = try allocator.alloc(u8, bound);
        errdefer allocator.free(output);
        var size: c_uint = @intCast(output.len);
        if (self.compress(output.ptr, &size, input.ptr, @intCast(input.len), block_size, 0, 30) != 0)
            return error.ReferenceEncodeFailed;
        if (size > output.len) return error.ReferenceEncodeFailed;
        return allocator.realloc(output, size);
    }
};
