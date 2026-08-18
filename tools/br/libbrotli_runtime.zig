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
const Dictionary = extern struct {
    size_bits_by_length: [32]u8,
    offsets_by_length: [32]u32,
    data_size: usize,
    data: [*]const u8,
};
const GetDictionaryFn = *const fn () callconv(.c) *const Dictionary;
const GetTransformsFn = *const fn () callconv(.c) *const anyopaque;
const TransformDictionaryWordFn = *const fn (
    [*]u8,
    [*]const u8,
    c_int,
    *const anyopaque,
    c_int,
) callconv(.c) c_int;

pub const Runtime = struct {
    encoder: std.DynLib,
    decoder: std.DynLib,
    common: std.DynLib,
    max_compressed_size: MaxCompressedSizeFn,
    compress: CompressFn,
    decompress: DecompressFn,
    encoder_version: VersionFn,
    decoder_version: VersionFn,
    get_dictionary: GetDictionaryFn,
    get_transforms: GetTransformsFn,
    transform_dictionary_word: TransformDictionaryWordFn,

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
        var common = try openLibrary(&.{
            "libbrotlicommon.so.1",
            "/lib/x86_64-linux-gnu/libbrotlicommon.so.1",
            "/usr/lib/x86_64-linux-gnu/libbrotlicommon.so.1",
            "libbrotlicommon.dylib",
        });
        errdefer common.close();
        return .{
            .encoder = encoder,
            .decoder = decoder,
            .common = common,
            .max_compressed_size = encoder.lookup(MaxCompressedSizeFn, "BrotliEncoderMaxCompressedSize") orelse return error.ReferenceUnavailable,
            .compress = encoder.lookup(CompressFn, "BrotliEncoderCompress") orelse return error.ReferenceUnavailable,
            .decompress = decoder.lookup(DecompressFn, "BrotliDecoderDecompress") orelse return error.ReferenceUnavailable,
            .encoder_version = encoder.lookup(VersionFn, "BrotliEncoderVersion") orelse return error.ReferenceUnavailable,
            .decoder_version = decoder.lookup(VersionFn, "BrotliDecoderVersion") orelse return error.ReferenceUnavailable,
            .get_dictionary = common.lookup(GetDictionaryFn, "BrotliGetDictionary") orelse return error.ReferenceUnavailable,
            .get_transforms = common.lookup(GetTransformsFn, "BrotliGetTransforms") orelse return error.ReferenceUnavailable,
            .transform_dictionary_word = common.lookup(TransformDictionaryWordFn, "BrotliTransformDictionaryWord") orelse return error.ReferenceUnavailable,
        };
    }

    pub fn deinit(self: *Runtime) void {
        self.encoder.close();
        self.decoder.close();
        self.common.close();
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

    pub fn transformDictionary(
        self: Runtime,
        address: usize,
        word_len: usize,
        output: []u8,
    ) ![]const u8 {
        const dictionary = self.get_dictionary();
        if (word_len >= dictionary.size_bits_by_length.len) return error.ReferenceDecodeFailed;
        const bits = dictionary.size_bits_by_length[word_len];
        if (bits == 0) return error.ReferenceDecodeFailed;
        const mask = (@as(usize, 1) << @intCast(bits)) - 1;
        const word_index = address & mask;
        const transform_index = address >> @intCast(bits);
        const start = @as(usize, dictionary.offsets_by_length[word_len]) + word_index * word_len;
        if (start > dictionary.data_size or dictionary.data_size - start < word_len) return error.ReferenceDecodeFailed;
        const written = self.transform_dictionary_word(
            output.ptr,
            dictionary.data + start,
            @intCast(word_len),
            self.get_transforms(),
            @intCast(transform_index),
        );
        if (written < 0 or @as(usize, @intCast(written)) > output.len) return error.ReferenceDecodeFailed;
        return output[0..@intCast(written)];
    }
};

fn openLibrary(names: []const [:0]const u8) !std.DynLib {
    for (names) |name| {
        if (std.DynLib.openZ(name.ptr)) |library| return library else |_| {}
    }
    return error.ReferenceUnavailable;
}
