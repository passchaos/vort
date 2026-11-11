//! Minimal dynamic ABI for an explicitly selected libdeflate decoder.
//! libdeflate has no runtime version query; the CLI records the pinned-header
//! version declared by the fixture producer separately from this ABI.
const std = @import("std");

pub const Decompressor = opaque {};
pub const success: c_int = 0; // LIBDEFLATE_SUCCESS in the public libdeflate ABI.
const AllocateFn = *const fn () callconv(.c) ?*Decompressor;
const FreeFn = *const fn (?*Decompressor) callconv(.c) void;
const DecompressExFn = *const fn (
    *Decompressor,
    [*]const u8,
    usize,
    [*]u8,
    usize,
    *usize,
    *usize,
) callconv(.c) c_int;

pub const Result = struct { input_consumed: usize, output_written: usize };

pub const Runtime = struct {
    library: std.DynLib,
    allocate: AllocateFn,
    free: FreeFn,
    decompress_ex: DecompressExFn,

    pub fn openPath(path: []const u8) !Runtime {
        if (!std.fs.path.isAbsolute(path) or std.mem.indexOfScalar(u8, path, 0) != null)
            return error.InvalidReferencePath;
        var library = try std.DynLib.open(path);
        errdefer library.close();
        return .{
            .library = library,
            .allocate = library.lookup(AllocateFn, "libdeflate_alloc_decompressor") orelse return error.ReferenceUnavailable,
            .free = library.lookup(FreeFn, "libdeflate_free_decompressor") orelse return error.ReferenceUnavailable,
            .decompress_ex = library.lookup(DecompressExFn, "libdeflate_deflate_decompress_ex") orelse return error.ReferenceUnavailable,
        };
    }

    pub fn deinit(self: *Runtime) void {
        self.library.close();
        self.* = undefined;
    }

    pub fn decode(self: Runtime, context: *Decompressor, encoded: []const u8, output: []u8) !Result {
        var consumed: usize = 0;
        var written: usize = 0;
        const result = self.decompress_ex(context, encoded.ptr, encoded.len, output.ptr, output.len, &consumed, &written);
        if (result != success) return error.ReferenceDecodeFailed;
        return .{ .input_consumed = consumed, .output_written = written };
    }
};
