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
) callconv(.c) c_int;
const DecompressFn = *const fn (
    usize,
    [*]const u8,
    *usize,
    [*]u8,
) callconv(.c) c_int;
const VersionFn = *const fn () callconv(.c) u32;
const EncoderState = opaque {};
const AllocFn = *const fn (?*anyopaque, usize) callconv(.c) ?*anyopaque;
const FreeFn = *const fn (?*anyopaque, ?*anyopaque) callconv(.c) void;
const CreateEncoderFn = *const fn (?AllocFn, ?FreeFn, ?*anyopaque) callconv(.c) ?*EncoderState;
const DestroyEncoderFn = *const fn (*EncoderState) callconv(.c) void;
const SetEncoderParameterFn = *const fn (*EncoderState, c_int, u32) callconv(.c) c_int;
const CompressStreamFn = *const fn (
    *EncoderState,
    c_int,
    *usize,
    *[*]const u8,
    *usize,
    *[*]u8,
    ?*usize,
) callconv(.c) c_int;
const EncoderHasMoreOutputFn = *const fn (*EncoderState) callconv(.c) c_int;
const EncoderIsFinishedFn = *const fn (*EncoderState) callconv(.c) c_int;
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

const StreamingOperationCode = enum(c_int) {
    flush = 1,
    finish = 2,
    metadata = 3,
};

pub const Runtime = struct {
    encoder: std.DynLib,
    decoder: std.DynLib,
    common: std.DynLib,
    max_compressed_size: MaxCompressedSizeFn,
    compress: CompressFn,
    decompress: DecompressFn,
    encoder_version: VersionFn,
    decoder_version: VersionFn,
    create_encoder: CreateEncoderFn,
    destroy_encoder: DestroyEncoderFn,
    set_encoder_parameter: SetEncoderParameterFn,
    compress_stream: CompressStreamFn,
    encoder_has_more_output: EncoderHasMoreOutputFn,
    encoder_is_finished: EncoderIsFinishedFn,
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
            .create_encoder = encoder.lookup(CreateEncoderFn, "BrotliEncoderCreateInstance") orelse return error.ReferenceUnavailable,
            .destroy_encoder = encoder.lookup(DestroyEncoderFn, "BrotliEncoderDestroyInstance") orelse return error.ReferenceUnavailable,
            .set_encoder_parameter = encoder.lookup(SetEncoderParameterFn, "BrotliEncoderSetParameter") orelse return error.ReferenceUnavailable,
            .compress_stream = encoder.lookup(CompressStreamFn, "BrotliEncoderCompressStream") orelse return error.ReferenceUnavailable,
            .encoder_has_more_output = encoder.lookup(EncoderHasMoreOutputFn, "BrotliEncoderHasMoreOutput") orelse return error.ReferenceUnavailable,
            .encoder_is_finished = encoder.lookup(EncoderIsFinishedFn, "BrotliEncoderIsFinished") orelse return error.ReferenceUnavailable,
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
        return self.encodeWithOptionsAlloc(allocator, input, .{ .quality = quality });
    }

    pub const OneShotOptions = struct {
        quality: c_int,
        lgwin: c_int = 22,
        /// BrotliEncoderMode: generic=0, text=1, font=2.
        mode: c_int = 0,
    };

    /// One-shot libbrotli encoder with the wire-shaping parameters used by
    /// compatibility matrices. This deliberately stays in the test harness;
    /// Vort's production encoder remains dependency-free.
    pub fn encodeWithOptionsAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        input: []const u8,
        options: OneShotOptions,
    ) ![]u8 {
        const bound = self.max_compressed_size(input.len);
        if (bound == 0) return error.ReferenceEncodeFailed;
        const output = try allocator.alloc(u8, bound);
        errdefer allocator.free(output);
        var written = output.len;
        if (self.compress(options.quality, options.lgwin, options.mode, input.len, input.ptr, &written, output.ptr) == 0) {
            return error.ReferenceEncodeFailed;
        }
        return allocator.realloc(output, written);
    }

    /// Encode caller chunks with a completed Brotli FLUSH between chunks. This
    /// uses libbrotli's public streaming API and is useful for compatibility
    /// tests that need genuine independently entropy-coded meta-blocks rather
    /// than synthetic Vort fixtures.
    pub fn encodeFlushedChunksAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        chunks: []const []const u8,
        quality: u32,
        lgwin: u32,
        lgblock: u32,
    ) ![]u8 {
        return self.encodeFlushedChunksWithOptionsAlloc(allocator, chunks, .{
            .quality = quality,
            .lgwin = lgwin,
            .lgblock = lgblock,
        });
    }

    pub const StreamingOptions = struct {
        quality: u32,
        lgwin: u32,
        lgblock: u32,
        /// BrotliEncoderMode: generic=0, text=1, font=2.
        mode: u32 = 0,
        disable_literal_context_modeling: bool = false,
        npostfix: ?u32 = null,
        ndirect: ?u32 = null,
    };
    pub const StreamingOperation = union(enum) {
        flush: []const u8,
        metadata: []const u8,
    };

    pub fn encodeFlushedChunksWithOptionsAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        chunks: []const []const u8,
        options: StreamingOptions,
    ) ![]u8 {
        const state = try self.createConfiguredEncoder(options);
        defer self.destroy_encoder(state);

        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(allocator);
        for (chunks) |chunk| try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.flush), chunk, &output);
        try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.finish), &.{}, &output);
        if (self.encoder_is_finished(state) == 0) return error.ReferenceEncodeFailed;
        return output.toOwnedSlice(allocator);
    }

    pub fn encodeOperationsAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        operations: []const StreamingOperation,
        options: StreamingOptions,
    ) ![]u8 {
        const state = try self.createConfiguredEncoder(options);
        defer self.destroy_encoder(state);

        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(allocator);
        for (operations) |operation| switch (operation) {
            .flush => |input| try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.flush), input, &output),
            .metadata => |input| try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.metadata), input, &output),
        };
        try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.finish), &.{}, &output);
        if (self.encoder_is_finished(state) == 0) return error.ReferenceEncodeFailed;
        return output.toOwnedSlice(allocator);
    }

    fn createConfiguredEncoder(self: Runtime, options: StreamingOptions) !*EncoderState {
        const state = self.create_encoder(null, null, null) orelse return error.ReferenceEncodeFailed;
        errdefer self.destroy_encoder(state);
        if (self.set_encoder_parameter(state, 0, options.mode) == 0 or
            self.set_encoder_parameter(state, 1, options.quality) == 0 or
            self.set_encoder_parameter(state, 2, options.lgwin) == 0 or
            self.set_encoder_parameter(state, 3, options.lgblock) == 0 or
            self.set_encoder_parameter(state, 4, @intFromBool(options.disable_literal_context_modeling)) == 0)
            return error.ReferenceEncodeFailed;
        if (options.npostfix) |value|
            if (self.set_encoder_parameter(state, 7, value) == 0) return error.ReferenceEncodeFailed;
        if (options.ndirect) |value|
            if (self.set_encoder_parameter(state, 8, value) == 0) return error.ReferenceEncodeFailed;
        return state;
    }

    fn pushOperation(
        self: Runtime,
        allocator: std.mem.Allocator,
        state: *EncoderState,
        operation: c_int,
        input: []const u8,
        output: *std.ArrayList(u8),
    ) !void {
        var available_in = input.len;
        var next_in: [*]const u8 = input.ptr;
        while (true) {
            var scratch: [4096]u8 = undefined;
            var available_out = scratch.len;
            var next_out: [*]u8 = &scratch;
            if (self.compress_stream(state, operation, &available_in, &next_in, &available_out, &next_out, null) == 0)
                return error.ReferenceEncodeFailed;
            const written = scratch.len - available_out;
            try output.appendSlice(allocator, scratch[0..written]);
            if (available_in == 0 and self.encoder_has_more_output(state) == 0) break;
            if (written == 0 and available_in != 0) return error.ReferenceEncodeFailed;
        }
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
