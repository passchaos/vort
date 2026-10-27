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
const PreparedDictionary = opaque {};
const PrepareDictionaryFn = *const fn (
    c_int,
    usize,
    [*]const u8,
    c_int,
    ?AllocFn,
    ?FreeFn,
    ?*anyopaque,
) callconv(.c) ?*PreparedDictionary;
const DestroyPreparedDictionaryFn = *const fn (*PreparedDictionary) callconv(.c) void;
const AttachPreparedDictionaryFn = *const fn (
    *EncoderState,
    *const PreparedDictionary,
) callconv(.c) c_int;
const DecoderState = opaque {};
const CreateDecoderFn = *const fn (?AllocFn, ?FreeFn, ?*anyopaque) callconv(.c) ?*DecoderState;
const DestroyDecoderFn = *const fn (*DecoderState) callconv(.c) void;
const SetDecoderParameterFn = *const fn (*DecoderState, c_int, u32) callconv(.c) c_int;
const DecompressStreamFn = *const fn (
    *DecoderState,
    *usize,
    *[*]const u8,
    *usize,
    *[*]u8,
    ?*usize,
) callconv(.c) c_int;
const DecoderAttachDictionaryFn = *const fn (
    *DecoderState,
    c_int,
    usize,
    [*]const u8,
) callconv(.c) c_int;
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
    process = 0,
    flush = 1,
    finish = 2,
    metadata = 3,
};

const max_raw_dictionaries = 15;
const raw_shared_dictionary_type = 0;
const serialized_shared_dictionary_type = 1;

/// File names passed to the dynamic loader. Their storage must outlive Runtime.
/// Canonical absolute paths avoid SONAME lookup when exact files are required.
pub const Paths = struct {
    encoder: []const u8,
    decoder: []const u8,
    common: []const u8,

    pub fn validate(self: Paths) !void {
        for ([_][]const u8{ self.encoder, self.decoder, self.common }) |path| {
            if (path.len == 0 or std.mem.indexOfScalar(u8, path, 0) != null)
                return error.InvalidReferencePaths;
        }
    }
};

pub const Runtime = struct {
    encoder: std.DynLib,
    decoder: std.DynLib,
    common: std.DynLib,
    /// Successful open arguments, not proof of the loader's dependency graph.
    opened_names: Paths,
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
    prepare_dictionary: ?PrepareDictionaryFn,
    destroy_prepared_dictionary: ?DestroyPreparedDictionaryFn,
    attach_prepared_dictionary: ?AttachPreparedDictionaryFn,
    create_decoder: CreateDecoderFn,
    destroy_decoder: DestroyDecoderFn,
    set_decoder_parameter: SetDecoderParameterFn,
    decompress_stream: DecompressStreamFn,
    decoder_attach_dictionary: ?DecoderAttachDictionaryFn,
    get_dictionary: GetDictionaryFn,
    get_transforms: GetTransformsFn,
    transform_dictionary_word: TransformDictionaryWordFn,

    pub fn open() !Runtime {
        var encoder = try openNamedLibrary(&.{
            "libbrotlienc.so.1",
            "/lib/x86_64-linux-gnu/libbrotlienc.so.1",
            "/usr/lib/x86_64-linux-gnu/libbrotlienc.so.1",
            "libbrotlienc.dylib",
        });
        errdefer encoder.library.close();
        var decoder = try openNamedLibrary(&.{
            "libbrotlidec.so.1",
            "/lib/x86_64-linux-gnu/libbrotlidec.so.1",
            "/usr/lib/x86_64-linux-gnu/libbrotlidec.so.1",
            "libbrotlidec.dylib",
        });
        errdefer decoder.library.close();
        var common = try openNamedLibrary(&.{
            "libbrotlicommon.so.1",
            "/lib/x86_64-linux-gnu/libbrotlicommon.so.1",
            "/usr/lib/x86_64-linux-gnu/libbrotlicommon.so.1",
            "libbrotlicommon.dylib",
        });
        errdefer common.library.close();
        return bind(encoder.library, decoder.library, common.library, .{
            .encoder = encoder.name,
            .decoder = decoder.name,
            .common = common.name,
        });
    }

    /// Open each supplied library without trying another file on failure.
    /// Callers wanting exact file identity should provide canonical paths;
    /// neither this method nor version symbols prove transitive dependencies.
    pub fn openPaths(paths: Paths) !Runtime {
        try paths.validate();
        var encoder = try std.DynLib.open(paths.encoder);
        errdefer encoder.close();
        var decoder = try std.DynLib.open(paths.decoder);
        errdefer decoder.close();
        var common = try std.DynLib.open(paths.common);
        errdefer common.close();
        return bind(encoder, decoder, common, paths);
    }

    fn bind(encoder_library: std.DynLib, decoder_library: std.DynLib, common_library: std.DynLib, opened_names: Paths) !Runtime {
        // DynLib.lookup takes a mutable handle even for symbol-only lookup.
        var encoder = encoder_library;
        var decoder = decoder_library;
        var common = common_library;
        return .{
            .encoder = encoder,
            .decoder = decoder,
            .common = common,
            .opened_names = opened_names,
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
            .prepare_dictionary = encoder.lookup(PrepareDictionaryFn, "BrotliEncoderPrepareDictionary"),
            .destroy_prepared_dictionary = encoder.lookup(DestroyPreparedDictionaryFn, "BrotliEncoderDestroyPreparedDictionary"),
            .attach_prepared_dictionary = encoder.lookup(AttachPreparedDictionaryFn, "BrotliEncoderAttachPreparedDictionary"),
            .create_decoder = decoder.lookup(CreateDecoderFn, "BrotliDecoderCreateInstance") orelse return error.ReferenceUnavailable,
            .destroy_decoder = decoder.lookup(DestroyDecoderFn, "BrotliDecoderDestroyInstance") orelse return error.ReferenceUnavailable,
            .set_decoder_parameter = decoder.lookup(SetDecoderParameterFn, "BrotliDecoderSetParameter") orelse return error.ReferenceUnavailable,
            .decompress_stream = decoder.lookup(DecompressStreamFn, "BrotliDecoderDecompressStream") orelse return error.ReferenceUnavailable,
            .decoder_attach_dictionary = decoder.lookup(DecoderAttachDictionaryFn, "BrotliDecoderAttachDictionary"),
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

    /// Whether the loaded encoder and decoder both expose the shared
    /// dictionary APIs. These symbols are optional so libbrotli 1.0.x can
    /// still be used for every operation that does not need a dictionary.
    pub fn supportsSharedDictionary(self: Runtime) bool {
        return self.prepare_dictionary != null and
            self.destroy_prepared_dictionary != null and
            self.attach_prepared_dictionary != null and
            self.decoder_attach_dictionary != null;
    }

    pub fn supportsSerializedDictionary(
        self: Runtime,
        encoded_dictionary: []const u8,
        quality: c_int,
    ) bool {
        const prepare_dictionary = self.prepare_dictionary orelse return false;
        const destroy_prepared_dictionary = self.destroy_prepared_dictionary orelse
            return false;
        const prepared = prepare_dictionary(
            serialized_shared_dictionary_type,
            encoded_dictionary.len,
            encoded_dictionary.ptr,
            quality,
            null,
            null,
            null,
        ) orelse return false;
        destroy_prepared_dictionary(prepared);
        return true;
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

        pub fn validate(self: OneShotOptions) !void {
            // The public one-shot API also supports the explicit Large Window
            // extension. Preserve that range for existing compatibility probes.
            if (self.quality < 0 or self.quality > 11 or
                self.lgwin < 10 or self.lgwin > 30 or
                self.mode < 0 or self.mode > 2)
                return error.InvalidReferenceParameters;
        }
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
        try options.validate();
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
        process: []const u8,
        flush: []const u8,
        metadata: []const u8,
        finish: []const u8,
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
        var finished = false;
        for (operations) |operation| switch (operation) {
            .process => |input| {
                if (finished) return error.ReferenceEncodeFailed;
                try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.process), input, &output);
            },
            .flush => |input| {
                if (finished) return error.ReferenceEncodeFailed;
                try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.flush), input, &output);
            },
            .metadata => |input| {
                if (finished) return error.ReferenceEncodeFailed;
                try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.metadata), input, &output);
            },
            .finish => |input| {
                if (finished) return error.ReferenceEncodeFailed;
                try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.finish), input, &output);
                finished = true;
            },
        };
        if (!finished)
            try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.finish), &.{}, &output);
        if (self.encoder_is_finished(state) == 0) return error.ReferenceEncodeFailed;
        return output.toOwnedSlice(allocator);
    }

    /// Encode after attaching the ordered RAW shared-prefix chunks. Empty
    /// chunks are deliberately prepared and attached too: attachment order
    /// and the upstream fifteen-slot limit are part of the API contract.
    pub fn encodeWithRawDictionariesAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        input: []const u8,
        raw_dictionaries: []const []const u8,
        options: StreamingOptions,
    ) ![]u8 {
        const prepare_dictionary = self.prepare_dictionary orelse return error.ReferenceUnavailable;
        const destroy_prepared_dictionary = self.destroy_prepared_dictionary orelse return error.ReferenceUnavailable;
        const attach_prepared_dictionary = self.attach_prepared_dictionary orelse return error.ReferenceUnavailable;
        if (raw_dictionaries.len > max_raw_dictionaries) return error.ReferenceEncodeFailed;

        var prepared: [max_raw_dictionaries]*PreparedDictionary = undefined;
        var prepared_count: usize = 0;
        defer {
            while (prepared_count != 0) {
                prepared_count -= 1;
                destroy_prepared_dictionary(prepared[prepared_count]);
            }
        }

        const state = try self.createConfiguredEncoder(options);
        defer self.destroy_encoder(state);

        for (raw_dictionaries) |dictionary| {
            const item = prepare_dictionary(
                raw_shared_dictionary_type,
                dictionary.len,
                dictionary.ptr,
                @intCast(options.quality),
                null,
                null,
                null,
            ) orelse return error.ReferenceEncodeFailed;
            prepared[prepared_count] = item;
            prepared_count += 1;
            if (attach_prepared_dictionary(state, item) == 0)
                return error.ReferenceEncodeFailed;
        }

        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(allocator);
        try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.process), input, &output);
        try self.pushOperation(allocator, state, @intFromEnum(StreamingOperationCode.finish), &.{}, &output);
        if (self.encoder_is_finished(state) == 0) return error.ReferenceEncodeFailed;
        return output.toOwnedSlice(allocator);
    }

    pub fn encodeWithSerializedDictionaryAlloc(
        self: Runtime,
        allocator: std.mem.Allocator,
        input: []const u8,
        encoded_dictionary: []const u8,
        options: StreamingOptions,
    ) ![]u8 {
        const prepare_dictionary = self.prepare_dictionary orelse
            return error.ReferenceUnavailable;
        const destroy_prepared_dictionary = self.destroy_prepared_dictionary orelse
            return error.ReferenceUnavailable;
        const attach_prepared_dictionary = self.attach_prepared_dictionary orelse
            return error.ReferenceUnavailable;
        const prepared = prepare_dictionary(
            serialized_shared_dictionary_type,
            encoded_dictionary.len,
            encoded_dictionary.ptr,
            @intCast(options.quality),
            null,
            null,
            null,
        ) orelse return error.ReferenceEncodeFailed;
        defer destroy_prepared_dictionary(prepared);

        const state = try self.createConfiguredEncoder(options);
        defer self.destroy_encoder(state);
        if (attach_prepared_dictionary(state, prepared) == 0)
            return error.ReferenceEncodeFailed;
        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(allocator);
        try self.pushOperation(
            allocator,
            state,
            @intFromEnum(StreamingOperationCode.process),
            input,
            &output,
        );
        try self.pushOperation(
            allocator,
            state,
            @intFromEnum(StreamingOperationCode.finish),
            &.{},
            &output,
        );
        if (self.encoder_is_finished(state) == 0)
            return error.ReferenceEncodeFailed;
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

    /// Decode through libbrotli's stateful API so the non-RFC Large Window
    /// extension can be enabled explicitly. The ordinary `decode` helper
    /// intentionally remains strict.
    pub fn decodeLargeWindow(self: Runtime, encoded: []const u8, output: []u8) !void {
        const state = self.create_decoder(null, null, null) orelse return error.ReferenceDecodeFailed;
        defer self.destroy_decoder(state);
        if (self.set_decoder_parameter(state, 1, 1) == 0) return error.ReferenceDecodeFailed;

        var available_in = encoded.len;
        var next_in: [*]const u8 = encoded.ptr;
        var available_out = output.len;
        var next_out: [*]u8 = output.ptr;
        const result = self.decompress_stream(
            state,
            &available_in,
            &next_in,
            &available_out,
            &next_out,
            null,
        );
        if (result != 1) return error.ReferenceDecodeFailed;
        if (available_in != 0 or available_out != 0) return error.SizeMismatch;
    }

    /// Decode after attaching the ordered RAW shared-prefix chunks. All
    /// attachments happen before the first decoder process call.
    pub fn decodeWithRawDictionaries(
        self: Runtime,
        encoded: []const u8,
        output: []u8,
        raw_dictionaries: []const []const u8,
    ) !void {
        const attach_dictionary = self.decoder_attach_dictionary orelse return error.ReferenceUnavailable;
        if (raw_dictionaries.len > max_raw_dictionaries) return error.ReferenceDecodeFailed;

        const state = self.create_decoder(null, null, null) orelse return error.ReferenceDecodeFailed;
        defer self.destroy_decoder(state);
        for (raw_dictionaries) |dictionary| {
            if (attach_dictionary(
                state,
                raw_shared_dictionary_type,
                dictionary.len,
                dictionary.ptr,
            ) == 0) return error.ReferenceDecodeFailed;
        }

        var available_in = encoded.len;
        var next_in: [*]const u8 = encoded.ptr;
        var available_out = output.len;
        var next_out: [*]u8 = output.ptr;
        const result = self.decompress_stream(
            state,
            &available_in,
            &next_in,
            &available_out,
            &next_out,
            null,
        );
        if (result != 1 or available_in != 0 or available_out != 0)
            return error.ReferenceDecodeFailed;
    }

    pub fn decodeWithSerializedDictionary(
        self: Runtime,
        encoded: []const u8,
        output: []u8,
        encoded_dictionary: []const u8,
    ) !void {
        const attach_dictionary = self.decoder_attach_dictionary orelse
            return error.ReferenceUnavailable;
        const state = self.create_decoder(null, null, null) orelse
            return error.ReferenceDecodeFailed;
        defer self.destroy_decoder(state);
        if (attach_dictionary(
            state,
            serialized_shared_dictionary_type,
            encoded_dictionary.len,
            encoded_dictionary.ptr,
        ) == 0) return error.ReferenceDecodeFailed;

        var available_in = encoded.len;
        var next_in: [*]const u8 = encoded.ptr;
        var available_out = output.len;
        var next_out: [*]u8 = output.ptr;
        const result = self.decompress_stream(
            state,
            &available_in,
            &next_in,
            &available_out,
            &next_out,
            null,
        );
        if (result != 1 or available_in != 0 or available_out != 0)
            return error.ReferenceDecodeFailed;
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

const NamedLibrary = struct { library: std.DynLib, name: []const u8 };

fn openNamedLibrary(names: []const [:0]const u8) !NamedLibrary {
    for (names) |name| {
        if (std.DynLib.openZ(name.ptr)) |library| return .{ .library = library, .name = name } else |_| {}
    }
    return error.ReferenceUnavailable;
}

test "libbrotli explicit paths reject empty and embedded NUL names before loading" {
    try std.testing.expectError(error.InvalidReferencePaths, Runtime.openPaths(.{ .encoder = "", .decoder = "decoder", .common = "common" }));
    try std.testing.expectError(error.InvalidReferencePaths, Runtime.openPaths(.{ .encoder = "encoder", .decoder = "decoder\x00suffix", .common = "common" }));
    try (Paths{ .encoder = "encoder", .decoder = "decoder", .common = "common" }).validate();
}
