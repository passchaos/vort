//! Paired raw decoder timings on producer-built, identical encoded fixtures.
//! Raw observations are authoritative. No compression or best-of-N selection.
const std = @import("std");
const builtin = @import("builtin");
const vort = @import("vort");
const benchmark_provenance = @import("benchmark_provenance");
const sampling = @import("sampling.zig");
const perf = @import("perf_group.zig");
const libdeflate = @import("libdeflate_runtime.zig");
const libzstd = @import("libzstd_runtime");
const libbrotli = @import("libbrotli_runtime");

const max_file_size = 256 * 1024 * 1024;
const max_pairs = 1024 * 1024;
const Reference = union(sampling.Codec) {
    deflate: libdeflate.Runtime,
    zstd: libzstd.Runtime,
    brotli: libbrotli.Runtime,

    fn open(options: sampling.Options) !Reference {
        return switch (options.codec) {
            .deflate => .{ .deflate = try libdeflate.Runtime.openPath(options.reference.?) },
            .zstd => .{ .zstd = try libzstd.Runtime.openPath(options.reference.?) },
            .brotli => .{ .brotli = try libbrotli.Runtime.openPaths(.{
                .encoder = options.brotli_encoder.?,
                .decoder = options.brotli_decoder.?,
                .common = options.brotli_common.?,
            }) },
        };
    }

    fn deinit(self: *Reference) void {
        switch (self.*) {
            inline else => |*runtime| runtime.deinit(),
        }
    }
};

const State = struct {
    io: std.Io,
    options: sampling.Options,
    input: sampling.GuardedBuffer,
    wire: sampling.GuardedBuffer,
    vort_output: sampling.GuardedBuffer,
    reference_output: sampling.GuardedBuffer,
    original_input: []const u8,
    original_wire: []const u8,
    deflate_context: ?*libdeflate.Decompressor = null,
    zstd_context: ?*anyopaque = null,
    zstd_decoder: *vort.ZstdNativeFrameDecoder,
    counters: ?*perf.Group = null,

    fn validateBatch(self: State, output: sampling.GuardedBuffer, consumed: ?usize) !void {
        try self.input.validate();
        try self.wire.validate();
        try output.validate();
        if (!std.mem.eql(u8, self.input.data, self.original_input) or
            !std.mem.eql(u8, self.wire.data, self.original_wire)) return error.InputChanged;
        if (!std.mem.eql(u8, self.original_input, output.data)) return error.OutputMismatch;
        if (consumed) |count| if (count != self.wire.data.len) return error.InputConsumptionMismatch;
    }
};

pub fn main(init: std.process.Init) !void {
    if (comptime builtin.os.tag != .linux) return error.LinuxLoaderProvenanceRequired;
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var arguments: std.ArrayList([]const u8) = .empty;
    defer arguments.deinit(init.gpa);
    while (args.next()) |argument| try arguments.append(init.gpa, argument);
    if (arguments.items.len == 1 and std.mem.eql(u8, arguments.items[0], "--help")) {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
        try stdout.interface.writeAll(
            "decode-compare --codec deflate|zstd|brotli --input FILE --encoded-input FILE\n" ++
                "  --iterations N --rounds N --warmup N --lifecycle cold|prepared\n" ++
                "  --reference ABSOLUTE_LIB [--reference-version PINNED_HEADER_VERSION]\n" ++
                "  --brotli-encoder ABSOLUTE_LIB --brotli-decoder ABSOLUTE_LIB --brotli-common ABSOLUTE_LIB\n" ++
                "  [--output JSONPATH] [--perf-group branches|branch-misses]\n" ++
                "Rounds must be even and >=2; warmup counts paired batches and must be even (0 allowed).\n" ++
                "Deflate requires --reference-version, declared from a pinned header; Zstd/Brotli query versions.\n" ++
                "Brotli supports cold only. Deflate prepared reuses only the reference context.\n",
        );
        try stdout.interface.flush();
        return;
    }
    const options = try sampling.parseOptions(arguments.items);
    const pair_count = try std.math.add(usize, options.warmup, options.rounds);
    if (pair_count > max_pairs) return error.TooManyPairs;
    var protected_paths: [6][]const u8 = undefined;
    protected_paths[0] = options.input_path;
    protected_paths[1] = options.encoded_path;
    const protected_count: usize = if (options.codec == .brotli) blk: {
        protected_paths[2] = options.brotli_encoder.?;
        protected_paths[3] = options.brotli_decoder.?;
        protected_paths[4] = options.brotli_common.?;
        protected_paths[5] = "/proc/self/exe";
        break :blk 6;
    } else blk: {
        protected_paths[2] = options.reference.?;
        protected_paths[3] = "/proc/self/exe";
        break :blk 4;
    };
    try sampling.rejectOutputAliases(init.io, init.gpa, options.output_path, protected_paths[0..protected_count]);
    var reference = try Reference.open(options);
    defer reference.deinit();
    var version_buffer: [64]u8 = undefined;
    var encoder_abi_version: ?u32 = null;
    var decoder_abi_version: ?u32 = null;
    const reference_version = switch (reference) {
        .deflate => options.reference_version.?,
        .zstd => |runtime| runtime.version(),
        .brotli => |runtime| blk: {
            const encoder_version = runtime.encoder_version();
            const decoder_version = runtime.decoder_version();
            if (encoder_version != decoder_version) return error.ReferenceVersionMismatch;
            encoder_abi_version = encoder_version;
            decoder_abi_version = decoder_version;
            break :blk try std.fmt.bufPrint(&version_buffer, "{d}.{d}.{d}", .{
                decoder_version >> 24,
                (decoder_version >> 12) & 0xfff,
                decoder_version & 0xfff,
            });
        },
    };
    const provenance = try benchmark_provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer provenance.deinit(init.gpa);
    const original_input = try std.Io.Dir.cwd().readFileAlloc(init.io, options.input_path, init.gpa, .limited(max_file_size));
    defer init.gpa.free(original_input);
    const original_wire = try std.Io.Dir.cwd().readFileAlloc(init.io, options.encoded_path, init.gpa, .limited(max_file_size));
    defer init.gpa.free(original_wire);
    const input = try sampling.GuardedBuffer.init(init.gpa, original_input.len);
    defer input.deinit(init.gpa);
    @memcpy(input.data, original_input);
    const wire = try sampling.GuardedBuffer.init(init.gpa, original_wire.len);
    defer wire.deinit(init.gpa);
    @memcpy(wire.data, original_wire);
    const vort_output = try sampling.GuardedBuffer.init(init.gpa, original_input.len);
    defer vort_output.deinit(init.gpa);
    const reference_output = try sampling.GuardedBuffer.init(init.gpa, original_input.len);
    defer reference_output.deinit(init.gpa);
    const pairs = try init.gpa.alloc(sampling.Pair, pair_count);
    defer init.gpa.free(pairs);
    var decoder = vort.ZstdNativeFrameDecoder.init(init.gpa);
    defer decoder.deinit();
    var state = State{
        .io = init.io,
        .options = options,
        .input = input,
        .wire = wire,
        .vort_output = vort_output,
        .reference_output = reference_output,
        .original_input = original_input,
        .original_wire = original_wire,
        .zstd_decoder = &decoder,
    };
    if (options.lifecycle == .prepared) {
        switch (reference) {
            .deflate => |runtime| state.deflate_context = runtime.allocate() orelse return error.ReferenceUnavailable,
            .zstd => |runtime| state.zstd_context = runtime.create_dctx() orelse return error.ReferenceUnavailable,
            .brotli => unreachable,
        }
    }
    defer switch (reference) {
        .deflate => |runtime| if (state.deflate_context) |context| runtime.free(context),
        .zstd => |runtime| if (state.zstd_context) |context| {
            _ = runtime.free_dctx(context);
        },
        .brotli => {},
    };
    // A retained workspace is primed outside timing, even with --warmup 0.
    // Cold contexts and the reference Brotli one-shot state remain per-call.
    if (options.lifecycle == .prepared) try primePrepared(reference, &state);
    var counters = if (options.perf_group) |kind| try perf.Group.open(kind) else null;
    defer if (counters) |*group| group.deinit();
    if (counters) |*group| state.counters = group;
    for (pairs, 0..) |*pair, pair_id| {
        const first = sampling.firstForPair(pair_id);
        const first_sample = try measureChecked(init.gpa, reference, &state, first, pair_id);
        const second_sample = try measureChecked(init.gpa, reference, &state, if (first == .vort) .reference else .vort, pair_id);
        pair.* = sampling.makePair(pair_id, if (first == .vort) first_sample else second_sample, if (first == .reference) first_sample else second_sample);
    }
    // procfs reports st_size=0; a size-based whole-file read loses the maps.
    const maps_file = try std.Io.Dir.openFileAbsolute(init.io, "/proc/self/maps", .{});
    defer maps_file.close(init.io);
    var maps_buffer: [4096]u8 = undefined;
    var maps_reader = maps_file.readerStreaming(init.io, &maps_buffer);
    const maps = try maps_reader.interface.allocRemaining(init.gpa, .limited(16 * 1024 * 1024));
    defer init.gpa.free(maps);
    const mapped_libraries = try sampling.mappedLibrariesAlloc(init.gpa, maps);
    defer {
        for (mapped_libraries) |path| init.gpa.free(path);
        init.gpa.free(mapped_libraries);
    }
    if (mapped_libraries.len == 0) return error.LoaderProvenanceUnavailable;
    var paths: [3][]const u8 = undefined;
    const path_count: usize = if (options.codec == .brotli) blk: {
        paths = .{ options.brotli_encoder.?, options.brotli_decoder.?, options.brotli_common.? };
        break :blk 3;
    } else blk: {
        paths[0] = options.reference.?;
        break :blk 1;
    };
    const measured = pairs[options.warmup..];
    const input_sha256 = benchmark_provenance.sha256Hex(original_input);
    const encoded_sha256 = benchmark_provenance.sha256Hex(original_wire);
    const report = .{
        .schema = "vort.decode-compare.v1",
        .codec = options.codec,
        .lifecycle = options.lifecycle,
        .lifecycle_match = if (options.lifecycle == .cold) "matched-cold" else if (options.codec == .deflate) "reference-only-prepared" else "matched-prepared",
        .vort_api = vortApi(options),
        .reference_api = referenceApi(options),
        .iterations = options.iterations,
        .rounds = options.rounds,
        .warmup = options.warmup,
        .warmup_unit = "paired-batches-with-iterations-decodes-per-side",
        .input_path = options.input_path,
        .encoded_input_path = options.encoded_path,
        .input_bytes = original_input.len,
        .encoded_bytes = original_wire.len,
        .input_sha256 = input_sha256[0..],
        .encoded_sha256 = encoded_sha256[0..],
        .reference_version = reference_version,
        .reference_version_origin = switch (options.codec) {
            .deflate => "declared-pinned-header",
            .zstd => "queried-ZSTD_versionString",
            .brotli => "queried-BrotliEncoderVersion+BrotliDecoderVersion",
        },
        .reference_abi = switch (options.codec) {
            .deflate => "opaque-libdeflate_decompressor;LIBDEFLATE_SUCCESS=0;decompress_ex",
            .zstd => "ZSTD-public-C-ABI",
            .brotli => "Brotli-public-C-ABI",
        },
        .brotli_encoder_abi_version = encoder_abi_version,
        .brotli_decoder_abi_version = decoder_abi_version,
        .reference_paths = paths[0..path_count],
        .loaded_shared_library_paths = mapped_libraries,
        .alignment = .{
            .guard_bytes = sampling.GuardedBuffer.guard_bytes,
            .input_mod64 = @intFromPtr(input.data.ptr) % 64,
            .encoded_mod64 = @intFromPtr(wire.data.ptr) % 64,
            .vort_output_mod64 = @intFromPtr(vort_output.data.ptr) % 64,
            .reference_output_mod64 = @intFromPtr(reference_output.data.ptr) % 64,
        },
        .exact_consumption = .{ .vort = options.codec == .deflate, .reference = options.codec == .deflate },
        .validation = .{
            .every_iteration_count = true,
            .full_output_per_batch = true,
            .guards_per_batch = true,
            .input_unchanged_per_batch = true,
            .exact_consumption_per_batch = options.codec == .deflate,
            .prepared_priming = options.lifecycle == .prepared,
        },
        .warmup_pairs = pairs[0..options.warmup],
        .pairs = measured,
        .summary = .{
            .vort_median_ns = try sampling.median(init.gpa, measured, .vort),
            .reference_median_ns = try sampling.median(init.gpa, measured, .reference),
        },
        .provenance = provenance,
        .sampling_mode = if (options.perf_group != null) "pmu-diagnostic-with-batch-control-overhead" else "paired-wall-time",
        .pmu = if (options.perf_group) |kind| .{
            .group = kind,
            .scope = "Vort public decode batch and loop/count/mix bookkeeping; userspace boundary ioctl setup; timers and full validation outside counters",
            .thread_policy = "calling-thread-only; no inheritance",
            .exclude_kernel = true,
            .exclude_hypervisor = true,
            .scaled = false,
            .reference_counted = false,
            .header_time_scope = "cumulative per open group; reset clears counts only",
            .hardware = perf.metadata(kind),
        } else null,
    };
    // Publish only after every decode, output, guard, version, and map check.
    const json = try std.json.Stringify.valueAlloc(init.gpa, report, .{ .whitespace = .indent_2 });
    defer init.gpa.free(json);
    if (options.output_path) |path| {
        try sampling.rejectOutputAliases(init.io, init.gpa, path, protected_paths[0..protected_count]);
        try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = json });
    }
    var stdout_buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

const Outcome = struct { written: usize, consumed: ?usize = null };

fn decodeOnce(comptime codec: sampling.Codec, comptime implementation: sampling.Implementation, comptime prepared: bool, runtime: anytype, state: *State, output: []u8) !Outcome {
    const encoded = state.wire.data;
    if (implementation == .vort) {
        switch (codec) {
            .deflate => {
                const result = try vort.decodeRawDeflate(encoded, output);
                return .{ .written = result.output_written, .consumed = result.input_read };
            },
            .zstd => return .{ .written = if (prepared) try state.zstd_decoder.decodeIntoSlice(encoded, output) else try vort.zstdDecodeFrameInto(encoded, output) },
            .brotli => return .{ .written = try vort.brDecodeStreamInto(encoded, output) },
        }
    } else {
        switch (codec) {
            .deflate => {
                const context = if (prepared) state.deflate_context.? else runtime.allocate() orelse return error.ReferenceUnavailable;
                defer if (!prepared) runtime.free(context);
                const result = try runtime.decode(context, encoded, output);
                return .{ .written = result.output_written, .consumed = result.input_consumed };
            },
            .zstd => {
                const written = if (prepared)
                    runtime.decompress_dctx(state.zstd_context.?, output.ptr, output.len, encoded.ptr, encoded.len)
                else
                    runtime.decompress(output.ptr, output.len, encoded.ptr, encoded.len);
                if (runtime.is_error(written) != 0) return error.ReferenceDecodeFailed;
                return .{ .written = written };
            },
            .brotli => {
                var written = output.len;
                if (runtime.decompress(encoded.len, encoded.ptr, &written, output.ptr) != 1) return error.ReferenceDecodeFailed;
                return .{ .written = written };
            },
        }
    }
}

fn measureOnce(comptime codec: sampling.Codec, comptime implementation: sampling.Implementation, comptime prepared: bool, runtime: anytype, state: *State) !sampling.Sample {
    const output = if (implementation == .vort) state.vort_output else state.reference_output;
    @memset(output.data, if (implementation == .vort) 0xa5 else 0x5a);
    var mix: u64 = 0;
    var consumed: ?usize = null;
    const start = std.Io.Clock.awake.now(state.io);
    const group = if (comptime implementation == .vort) state.counters else null;
    if (group) |counter| try counter.begin();
    errdefer if (group) |counter| counter.stopQuietly();
    for (0..state.options.iterations) |_| {
        const outcome = try decodeOnce(codec, implementation, prepared, runtime, state, output.data);
        if (outcome.written != state.original_input.len) return error.OutputSizeMismatch;
        consumed = outcome.consumed;
        mix +%= outcome.written;
        if (output.data.len > 0) mix +%= output.data[0];
    }
    if (group) |counter| try counter.stop();
    const duration = start.durationTo(std.Io.Clock.awake.now(state.io)).nanoseconds;
    if (duration <= 0) return error.InvalidTimerDuration;
    const counts = if (group) |counter| try counter.read() else null;
    try state.validateBatch(output, consumed);
    return .{ .ns = @intCast(duration), .mix = mix, .counters = counts };
}

fn measureForCodec(comptime codec: sampling.Codec, runtime: anytype, state: *State, implementation: sampling.Implementation) !sampling.Sample {
    if (state.options.lifecycle == .prepared) {
        return if (implementation == .vort)
            measureOnce(codec, .vort, true, runtime, state)
        else
            measureOnce(codec, .reference, true, runtime, state);
    }
    return if (implementation == .vort)
        measureOnce(codec, .vort, false, runtime, state)
    else
        measureOnce(codec, .reference, false, runtime, state);
}

fn measure(reference: Reference, state: *State, implementation: sampling.Implementation) !sampling.Sample {
    return switch (reference) {
        inline else => |runtime, codec| measureForCodec(codec, runtime, state, implementation),
    };
}

fn measureChecked(allocator: std.mem.Allocator, reference: Reference, state: *State, implementation: sampling.Implementation, pair_id: usize) !sampling.Sample {
    return measure(reference, state, implementation) catch |err| {
        if (implementation == .vort) {
            if (state.counters) |group| {
                // Keep failed raw reads in stderr; successful output is still
                // published only after all codec and counter validation passes.
                const diagnostic = .{
                    .schema = "vort.decode-pmu-failure.v1",
                    .error_name = @errorName(err),
                    .pair_id = pair_id,
                    .implementation = implementation,
                    .group = state.options.perf_group.?,
                    .diagnostic = group.diagnostic(),
                };
                const json = std.json.Stringify.valueAlloc(allocator, diagnostic, .{}) catch return err;
                defer allocator.free(json);
                std.debug.print("{s}\n", .{json});
            }
        }
        return err;
    };
}

fn primePrepared(reference: Reference, state: *State) !void {
    switch (reference) {
        .deflate, .zstd => {
            inline for (.{ sampling.Implementation.vort, sampling.Implementation.reference }) |implementation| {
                const output = if (implementation == .vort) state.vort_output else state.reference_output;
                @memset(output.data, if (implementation == .vort) 0xa5 else 0x5a);
                const result = switch (reference) {
                    .deflate => |runtime| try decodeOnce(.deflate, implementation, true, runtime, state, output.data),
                    .zstd => |runtime| try decodeOnce(.zstd, implementation, true, runtime, state, output.data),
                    .brotli => unreachable,
                };
                if (result.written != state.original_input.len) return error.OutputSizeMismatch;
                try state.validateBatch(output, result.consumed);
            }
        },
        .brotli => unreachable,
    }
}

fn vortApi(options: sampling.Options) []const u8 {
    return switch (options.codec) {
        .deflate => "decodeRawDeflate",
        .zstd => if (options.lifecycle == .prepared) "NativeFrameDecoder.decodeIntoSlice" else "decodeFrameInto",
        .brotli => "brDecodeStreamInto",
    };
}

fn referenceApi(options: sampling.Options) []const u8 {
    return switch (options.codec) {
        .deflate => if (options.lifecycle == .prepared) "libdeflate_deflate_decompress_ex;retained-decompressor" else "libdeflate_alloc_decompressor+libdeflate_deflate_decompress_ex+libdeflate_free_decompressor",
        .zstd => if (options.lifecycle == .prepared) "ZSTD_decompressDCtx;retained-DCtx" else "ZSTD_decompress",
        .brotli => "BrotliDecoderDecompress;one-shot-state-and-internal-heap-per-call",
    };
}
