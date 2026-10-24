const std = @import("std");

const StreamBufferBoundFn = *const fn (usize) callconv(.c) usize;
const EasyBufferEncodeFn = *const fn (
    u32,
    c_int,
    ?*const anyopaque,
    [*]const u8,
    usize,
    [*]u8,
    *usize,
    usize,
) callconv(.c) c_int;
const StreamBufferDecodeFn = *const fn (
    *u64,
    u32,
    ?*const anyopaque,
    [*]const u8,
    *usize,
    usize,
    [*]u8,
    *usize,
    usize,
) callconv(.c) c_int;
const VersionStringFn = *const fn () callconv(.c) [*:0]const u8;

pub const Runtime = struct {
    library: std.DynLib,
    stream_buffer_bound: StreamBufferBoundFn,
    easy_buffer_encode: EasyBufferEncodeFn,
    stream_buffer_decode: StreamBufferDecodeFn,
    version_string: VersionStringFn,

    pub fn open() !Runtime {
        const names = [_][:0]const u8{
            "liblzma.so.5",
            "/lib/x86_64-linux-gnu/liblzma.so.5",
            "/usr/lib/x86_64-linux-gnu/liblzma.so.5",
            "/lib/aarch64-linux-gnu/liblzma.so.5",
            "/usr/lib/aarch64-linux-gnu/liblzma.so.5",
            "liblzma.dylib",
            "/opt/homebrew/opt/xz/lib/liblzma.dylib",
            "/usr/local/opt/xz/lib/liblzma.dylib",
        };
        for (names) |name| {
            var library = std.DynLib.openZ(name.ptr) catch continue;
            const stream_buffer_bound = library.lookup(
                StreamBufferBoundFn,
                "lzma_stream_buffer_bound",
            ) orelse {
                library.close();
                continue;
            };
            const easy_buffer_encode = library.lookup(
                EasyBufferEncodeFn,
                "lzma_easy_buffer_encode",
            ) orelse {
                library.close();
                continue;
            };
            const stream_buffer_decode = library.lookup(
                StreamBufferDecodeFn,
                "lzma_stream_buffer_decode",
            ) orelse {
                library.close();
                continue;
            };
            const version_string = library.lookup(
                VersionStringFn,
                "lzma_version_string",
            ) orelse {
                library.close();
                continue;
            };
            return .{
                .library = library,
                .stream_buffer_bound = stream_buffer_bound,
                .easy_buffer_encode = easy_buffer_encode,
                .stream_buffer_decode = stream_buffer_decode,
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
        preset: u32,
    ) ![]u8 {
        const output = try allocator.alloc(u8, self.stream_buffer_bound(input.len));
        errdefer allocator.free(output);
        var output_position: usize = 0;
        const result = self.easy_buffer_encode(
            preset,
            4,
            null,
            input.ptr,
            input.len,
            output.ptr,
            &output_position,
            output.len,
        );
        if (result != 0) return error.ReferenceEncodeFailed;
        return allocator.realloc(output, output_position);
    }

    pub fn decode(
        self: Runtime,
        encoded: []const u8,
        output: []u8,
    ) !void {
        var memory_limit: u64 = std.math.maxInt(u64);
        var input_position: usize = 0;
        var output_position: usize = 0;
        const result = self.stream_buffer_decode(
            &memory_limit,
            0,
            null,
            encoded.ptr,
            &input_position,
            encoded.len,
            output.ptr,
            &output_position,
            output.len,
        );
        if (result != 0) return error.ReferenceDecodeFailed;
        if (input_position != encoded.len or output_position != output.len)
            return error.SizeMismatch;
    }
};
