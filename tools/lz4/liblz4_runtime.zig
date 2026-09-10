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

const FrameInfo = extern struct {
    block_size_id: c_int = 0,
    block_mode: c_int = 0,
    content_checksum_flag: c_int = 0,
    frame_type: c_int = 0,
    content_size: c_ulonglong = 0,
    dictionary_id: c_uint = 0,
    block_checksum_flag: c_int = 0,
};

const Preferences = extern struct {
    frame_info: FrameInfo = .{},
    compression_level: c_int = 0,
    auto_flush: c_uint = 0,
    favor_decompression_speed: c_uint = 0,
    reserved: [3]c_uint = .{ 0, 0, 0 },
};

const CompressFrameBoundFn = *const fn (usize, ?*const Preferences) callconv(.c) usize;
const CompressFrameFn = *const fn (?*anyopaque, usize, ?*const anyopaque, usize, ?*const Preferences) callconv(.c) usize;
const DecompressOptions = extern struct {
    stable_destination: c_uint = 0,
    skip_checksums: c_uint = 0,
    reserved_1: c_uint = 0,
    reserved_0: c_uint = 0,
};
const CreateDecompressionContextFn = *const fn (*?*anyopaque, c_uint) callconv(.c) usize;
const FreeDecompressionContextFn = *const fn (?*anyopaque) callconv(.c) usize;
const DecompressFrameFn = *const fn (?*anyopaque, ?*anyopaque, *usize, ?*const anyopaque, *usize, ?*const DecompressOptions) callconv(.c) usize;
const IsErrorFn = *const fn (usize) callconv(.c) c_uint;
const frame_api_version: c_uint = 100;

pub const FrameOptions = struct {
    include_content_size: bool = true,
    content_checksum: bool = true,
    block_checksum: bool = false,
    block_size_id: c_int = 7,
    block_independent: bool = false,
    compression_level: c_int = 0,
    auto_flush: bool = false,
    favor_decompression_speed: bool = false,
};

pub const Runtime = struct {
    library: std.DynLib,
    decompress_safe: DecompressSafeFn,
    compress_bound: CompressBoundFn,
    compress_default: CompressDefaultFn,
    compress_frame_bound: CompressFrameBoundFn,
    compress_frame: CompressFrameFn,
    create_decompression_context: CreateDecompressionContextFn,
    free_decompression_context: FreeDecompressionContextFn,
    decompress_frame: DecompressFrameFn,
    is_error: IsErrorFn,
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
            const compress_frame_bound = library.lookup(
                CompressFrameBoundFn,
                "LZ4F_compressFrameBound",
            ) orelse {
                library.close();
                continue;
            };
            const compress_frame = library.lookup(
                CompressFrameFn,
                "LZ4F_compressFrame",
            ) orelse {
                library.close();
                continue;
            };
            const is_error = library.lookup(IsErrorFn, "LZ4F_isError") orelse {
                library.close();
                continue;
            };
            const create_decompression_context = library.lookup(
                CreateDecompressionContextFn,
                "LZ4F_createDecompressionContext",
            ) orelse {
                library.close();
                continue;
            };
            const free_decompression_context = library.lookup(
                FreeDecompressionContextFn,
                "LZ4F_freeDecompressionContext",
            ) orelse {
                library.close();
                continue;
            };
            const decompress_frame = library.lookup(
                DecompressFrameFn,
                "LZ4F_decompress",
            ) orelse {
                library.close();
                continue;
            };
            return .{
                .library = library,
                .decompress_safe = decompress_safe,
                .compress_bound = compress_bound,
                .compress_default = compress_default,
                .compress_frame_bound = compress_frame_bound,
                .compress_frame = compress_frame,
                .create_decompression_context = create_decompression_context,
                .free_decompression_context = free_decompression_context,
                .decompress_frame = decompress_frame,
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

    pub fn encodeFrameAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        input: []const u8,
        options: FrameOptions,
    ) ![]u8 {
        var preferences: Preferences = .{
            .frame_info = .{
                .block_size_id = options.block_size_id,
                .block_mode = @intFromBool(options.block_independent),
                .content_checksum_flag = @intFromBool(options.content_checksum),
                .content_size = if (options.include_content_size) input.len else 0,
                .block_checksum_flag = @intFromBool(options.block_checksum),
            },
            .compression_level = options.compression_level,
            .auto_flush = @intFromBool(options.auto_flush),
            .favor_decompression_speed = @intFromBool(options.favor_decompression_speed),
        };
        const bound = self.compress_frame_bound(input.len, &preferences);
        if (self.is_error(bound) != 0) return error.ReferenceEncodeFailed;
        const output = try allocator.alloc(u8, bound);
        errdefer allocator.free(output);
        const written = self.compress_frame(
            output.ptr,
            output.len,
            input.ptr,
            input.len,
            &preferences,
        );
        if (self.is_error(written) != 0) return error.ReferenceEncodeFailed;
        return allocator.realloc(output, written);
    }

    pub fn decodeFrame(self: Runtime, frame: []const u8, output: []u8) !void {
        var context: ?*anyopaque = null;
        const create_result = self.create_decompression_context(&context, frame_api_version);
        if (self.is_error(create_result) != 0 or context == null) return error.ReferenceDecodeFailed;
        defer _ = self.free_decompression_context(context);

        var input_offset: usize = 0;
        var output_offset: usize = 0;
        while (true) {
            var input_len = frame.len - input_offset;
            var output_len = output.len - output_offset;
            const result = self.decompress_frame(
                context,
                @ptrCast(output.ptr + output_offset),
                &output_len,
                @ptrCast(frame.ptr + input_offset),
                &input_len,
                null,
            );
            if (self.is_error(result) != 0) return error.ReferenceDecodeFailed;
            input_offset += input_len;
            output_offset += output_len;
            if (result == 0) break;
            if (input_len == 0 and output_len == 0) return error.ReferenceDecodeFailed;
        }
        if (input_offset != frame.len or output_offset != output.len) return error.SizeMismatch;
    }
};
