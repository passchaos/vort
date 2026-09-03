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
const CreateCCtxFn = *const fn () callconv(.c) ?*anyopaque;
const FreeCCtxFn = *const fn (?*anyopaque) callconv(.c) usize;
const CCtxSetParameterFn = *const fn (?*anyopaque, c_int, c_int) callconv(.c) usize;
const Compress2Fn = *const fn (?*anyopaque, [*]u8, usize, [*]const u8, usize) callconv(.c) usize;
const InBuffer = extern struct { src: ?*const anyopaque, size: usize, pos: usize };
const OutBuffer = extern struct { dst: ?*anyopaque, size: usize, pos: usize };
const CompressStream2Fn = *const fn (?*anyopaque, *OutBuffer, *InBuffer, c_int) callconv(.c) usize;
pub const Sequence = extern struct { offset: u32, literal_length: u32, match_length: u32, rep: u32 = 0 };
const CompressSequencesFn = *const fn (?*anyopaque, [*]u8, usize, [*]const Sequence, usize, [*]const u8, usize) callconv(.c) usize;
const CompressUsingDictFn = *const fn (?*anyopaque, [*]u8, usize, [*]const u8, usize, [*]const u8, usize, c_int) callconv(.c) usize;
const CreateDCtxFn = *const fn () callconv(.c) ?*anyopaque;
const FreeDCtxFn = *const fn (?*anyopaque) callconv(.c) usize;
const DecompressUsingDictFn = *const fn (?*anyopaque, [*]u8, usize, [*]const u8, usize, [*]const u8, usize) callconv(.c) usize;
const TrainDictionaryFn = *const fn ([*]u8, usize, [*]const u8, [*]const usize, c_uint) callconv(.c) usize;
const DictionaryIsErrorFn = *const fn (usize) callconv(.c) c_uint;
const DictionaryIdFn = *const fn ([*]const u8, usize) callconv(.c) c_uint;

pub const Runtime = struct {
    library: std.DynLib,
    compress_bound: CompressBoundFn,
    compress: CompressFn,
    decompress: DecompressFn,
    is_error: IsErrorFn,
    version_string: VersionStringFn,
    create_cctx: CreateCCtxFn,
    free_cctx: FreeCCtxFn,
    cctx_set_parameter: CCtxSetParameterFn,
    compress2: Compress2Fn,
    compress_stream2: CompressStream2Fn,
    compress_sequences: CompressSequencesFn,
    compress_using_dict: CompressUsingDictFn,
    create_dctx: CreateDCtxFn,
    free_dctx: FreeDCtxFn,
    decompress_using_dict: DecompressUsingDictFn,
    train_dictionary: TrainDictionaryFn,
    dictionary_is_error: DictionaryIsErrorFn,
    dictionary_id: DictionaryIdFn,

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
            const create_cctx = library.lookup(CreateCCtxFn, "ZSTD_createCCtx") orelse {
                library.close();
                continue;
            };
            const free_cctx = library.lookup(FreeCCtxFn, "ZSTD_freeCCtx") orelse {
                library.close();
                continue;
            };
            const cctx_set_parameter = library.lookup(CCtxSetParameterFn, "ZSTD_CCtx_setParameter") orelse {
                library.close();
                continue;
            };
            const compress2 = library.lookup(Compress2Fn, "ZSTD_compress2") orelse {
                library.close();
                continue;
            };
            const compress_stream2 = library.lookup(CompressStream2Fn, "ZSTD_compressStream2") orelse {
                library.close();
                continue;
            };
            const compress_sequences = library.lookup(CompressSequencesFn, "ZSTD_compressSequences") orelse {
                library.close();
                continue;
            };
            const compress_using_dict = library.lookup(CompressUsingDictFn, "ZSTD_compress_usingDict") orelse {
                library.close();
                continue;
            };
            const create_dctx = library.lookup(CreateDCtxFn, "ZSTD_createDCtx") orelse {
                library.close();
                continue;
            };
            const free_dctx = library.lookup(FreeDCtxFn, "ZSTD_freeDCtx") orelse {
                library.close();
                continue;
            };
            const decompress_using_dict = library.lookup(DecompressUsingDictFn, "ZSTD_decompress_usingDict") orelse {
                library.close();
                continue;
            };
            const train_dictionary = library.lookup(TrainDictionaryFn, "ZDICT_trainFromBuffer") orelse {
                library.close();
                continue;
            };
            const dictionary_is_error = library.lookup(DictionaryIsErrorFn, "ZDICT_isError") orelse {
                library.close();
                continue;
            };
            const dictionary_id = library.lookup(DictionaryIdFn, "ZDICT_getDictID") orelse {
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
                .create_cctx = create_cctx,
                .free_cctx = free_cctx,
                .cctx_set_parameter = cctx_set_parameter,
                .compress2 = compress2,
                .compress_stream2 = compress_stream2,
                .compress_sequences = compress_sequences,
                .compress_using_dict = compress_using_dict,
                .create_dctx = create_dctx,
                .free_dctx = free_dctx,
                .decompress_using_dict = decompress_using_dict,
                .train_dictionary = train_dictionary,
                .dictionary_is_error = dictionary_is_error,
                .dictionary_id = dictionary_id,
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

    pub fn encodeUsingDictAlloc(self: Runtime, allocator: std.mem.Allocator, input: []const u8, dictionary: []const u8, level: c_int) ![]u8 {
        const context = self.create_cctx() orelse return error.ReferenceUnavailable;
        defer _ = self.free_cctx(context);
        const output = try allocator.alloc(u8, self.compress_bound(input.len));
        errdefer allocator.free(output);
        const written = self.compress_using_dict(context, output.ptr, output.len, input.ptr, input.len, dictionary.ptr, dictionary.len, level);
        if (self.is_error(written) != 0) return error.ReferenceEncodeFailed;
        return allocator.realloc(output, written);
    }

    pub const AdvancedOptions = struct {
        level: c_int = 3,
        content_size: bool = true,
        checksum: bool = false,
        window_log: ?c_int = null,
        min_match: ?c_int = null,
        target_length: ?c_int = null,
        strategy: ?c_int = null,
        long_distance_matching: bool = false,
    };

    pub fn encodeAdvancedAlloc(self: Runtime, allocator: std.mem.Allocator, input: []const u8, options: AdvancedOptions) ![]u8 {
        const context = self.create_cctx() orelse return error.ReferenceUnavailable;
        defer _ = self.free_cctx(context);
        try self.setParameter(context, 100, options.level); // ZSTD_c_compressionLevel
        try self.setParameter(context, 200, @intFromBool(options.content_size)); // ZSTD_c_contentSizeFlag
        try self.setParameter(context, 201, @intFromBool(options.checksum)); // ZSTD_c_checksumFlag
        if (options.window_log) |value| try self.setParameter(context, 101, value); // ZSTD_c_windowLog
        if (options.min_match) |value| try self.setParameter(context, 105, value); // ZSTD_c_minMatch
        if (options.target_length) |value| try self.setParameter(context, 106, value); // ZSTD_c_targetLength
        if (options.strategy) |value| try self.setParameter(context, 107, value); // ZSTD_c_strategy
        if (options.long_distance_matching) try self.setParameter(context, 160, 1); // ZSTD_c_enableLongDistanceMatching

        const output = try allocator.alloc(u8, self.compress_bound(input.len));
        errdefer allocator.free(output);
        const written = self.compress2(context, output.ptr, output.len, input.ptr, input.len);
        if (self.is_error(written) != 0) return error.ReferenceEncodeFailed;
        return allocator.realloc(output, written);
    }

    fn setParameter(self: Runtime, context: ?*anyopaque, parameter: c_int, value: c_int) !void {
        if (self.is_error(self.cctx_set_parameter(context, parameter, value)) != 0)
            return error.ReferenceEncodeFailed;
    }

    pub fn encodeStreamingAlloc(self: Runtime, allocator: std.mem.Allocator, input: []const u8, options: AdvancedOptions, chunk_len: usize, flush_each_chunk: bool) ![]u8 {
        if (chunk_len == 0) return error.ReferenceEncodeFailed;
        const context = self.create_cctx() orelse return error.ReferenceUnavailable;
        defer _ = self.free_cctx(context);
        try self.setParameter(context, 100, options.level);
        try self.setParameter(context, 200, @intFromBool(options.content_size));
        try self.setParameter(context, 201, @intFromBool(options.checksum));
        if (options.window_log) |value| try self.setParameter(context, 101, value);
        if (options.min_match) |value| try self.setParameter(context, 105, value);
        if (options.target_length) |value| try self.setParameter(context, 106, value);
        if (options.strategy) |value| try self.setParameter(context, 107, value);
        if (options.long_distance_matching) try self.setParameter(context, 160, 1);

        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(allocator);
        var offset: usize = 0;
        while (offset < input.len) {
            const end = @min(input.len, offset + chunk_len);
            var in_buffer = InBuffer{ .src = input[offset..end].ptr, .size = end - offset, .pos = 0 };
            const directive: c_int = if (flush_each_chunk) 1 else 0;
            while (in_buffer.pos < in_buffer.size) _ = try self.streamStep(allocator, context, &output, &in_buffer, directive);
            if (flush_each_chunk) {
                var empty = InBuffer{ .src = null, .size = 0, .pos = 0 };
                while (try self.streamStep(allocator, context, &output, &empty, 1) != 0) {}
            }
            offset = end;
        }
        var empty = InBuffer{ .src = null, .size = 0, .pos = 0 };
        while (try self.streamStep(allocator, context, &output, &empty, 2) != 0) {}
        return output.toOwnedSlice(allocator);
    }

    fn streamStep(self: Runtime, allocator: std.mem.Allocator, context: ?*anyopaque, output: *std.ArrayList(u8), input: *InBuffer, directive: c_int) !usize {
        try output.ensureUnusedCapacity(allocator, 128 * 1024);
        var out_buffer = OutBuffer{ .dst = output.unusedCapacitySlice().ptr, .size = output.unusedCapacitySlice().len, .pos = 0 };
        const remaining = self.compress_stream2(context, &out_buffer, input, directive);
        if (self.is_error(remaining) != 0) return error.ReferenceEncodeFailed;
        output.items.len += out_buffer.pos;
        return remaining;
    }

    pub fn encodeSequencesAlloc(self: Runtime, allocator: std.mem.Allocator, input: []const u8, sequences: []const Sequence, level: c_int) ![]u8 {
        if (sequences.len == 0) return error.ReferenceEncodeFailed;
        const context = self.create_cctx() orelse return error.ReferenceUnavailable;
        defer _ = self.free_cctx(context);
        try self.setParameter(context, 100, level);
        try self.setParameter(context, 105, 3); // ZSTD_c_minMatch
        try self.setParameter(context, 1009, 1); // ZSTD_c_validateSequences

        const output = try allocator.alloc(u8, self.compress_bound(input.len));
        errdefer allocator.free(output);
        const written = self.compress_sequences(context, output.ptr, output.len, sequences.ptr, sequences.len, input.ptr, input.len);
        if (self.is_error(written) != 0) return error.ReferenceEncodeFailed;
        return allocator.realloc(output, written);
    }

    pub fn decodeUsingDict(self: Runtime, encoded: []const u8, output: []u8, dictionary: []const u8) !void {
        const context = self.create_dctx() orelse return error.ReferenceUnavailable;
        defer _ = self.free_dctx(context);
        const written = self.decompress_using_dict(context, output.ptr, output.len, encoded.ptr, encoded.len, dictionary.ptr, dictionary.len);
        if (self.is_error(written) != 0) return error.ReferenceDecodeFailed;
        if (written != output.len) return error.SizeMismatch;
    }

    pub fn trainDictionaryAlloc(self: Runtime, allocator: std.mem.Allocator, samples: []const []const u8, capacity: usize) ![]u8 {
        if (samples.len == 0 or capacity < 256) return error.ReferenceEncodeFailed;
        var joined: std.ArrayList(u8) = .empty;
        defer joined.deinit(allocator);
        var sizes = try allocator.alloc(usize, samples.len);
        defer allocator.free(sizes);
        for (samples, 0..) |sample, index| {
            sizes[index] = sample.len;
            try joined.appendSlice(allocator, sample);
        }
        const dictionary = try allocator.alloc(u8, capacity);
        errdefer allocator.free(dictionary);
        const written = self.train_dictionary(dictionary.ptr, dictionary.len, joined.items.ptr, sizes.ptr, @intCast(sizes.len));
        if (self.dictionary_is_error(written) != 0 or written == 0) return error.ReferenceEncodeFailed;
        return allocator.realloc(dictionary, written);
    }

    pub fn dictionaryId(self: Runtime, dictionary: []const u8) ?u32 {
        const id = self.dictionary_id(dictionary.ptr, dictionary.len);
        return if (id == 0) null else id;
    }
};
