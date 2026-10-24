const std = @import("std");
const vort = @import("vort");

const Case = struct {
    label: []const u8,
    category: []const u8,
    path: []const u8,
};

const CountingAllocator = struct {
    child: std.mem.Allocator,
    live_bytes: usize = 0,
    peak_bytes: usize = 0,

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(context));
        const result = self.child.rawAlloc(len, alignment, return_address) orelse
            return null;
        self.live_bytes += len;
        self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
        return result;
    }

    fn resize(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(context));
        if (!self.child.rawResize(memory, alignment, new_len, return_address))
            return false;
        self.adjust(memory.len, new_len);
        return true;
    }

    fn remap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(context));
        const result = self.child.rawRemap(memory, alignment, new_len, return_address) orelse
            return null;
        self.adjust(memory.len, new_len);
        return result;
    }

    fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, return_address: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(context));
        self.child.rawFree(memory, alignment, return_address);
        std.debug.assert(self.live_bytes >= memory.len);
        self.live_bytes -= memory.len;
    }

    fn adjust(self: *CountingAllocator, old_len: usize, new_len: usize) void {
        if (new_len >= old_len)
            self.live_bytes += new_len - old_len
        else
            self.live_bytes -= old_len - new_len;
        self.peak_bytes = @max(self.peak_bytes, self.live_bytes);
    }

    const vtable: std.mem.Allocator.VTable = .{
        .alloc = alloc,
        .resize = resize,
        .remap = remap,
        .free = free,
    };
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var cases: std.ArrayList(Case) = .empty;
    defer cases.deinit(init.gpa);
    var limit: usize = 16 * 1024;
    var chunk_len: usize = 256;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--limit")) {
            limit = try std.fmt.parseInt(usize, args.next() orelse
                return error.InvalidTrainingOptions, 10);
        } else if (std.mem.eql(u8, arg, "--chunk")) {
            chunk_len = try std.fmt.parseInt(usize, args.next() orelse
                return error.InvalidTrainingOptions, 10);
        } else if (std.mem.eql(u8, arg, "--case")) {
            try cases.append(init.gpa, .{
                .label = args.next() orelse return error.InvalidTrainingOptions,
                .category = args.next() orelse return error.InvalidTrainingOptions,
                .path = args.next() orelse return error.InvalidTrainingOptions,
            });
        } else {
            return error.InvalidTrainingOptions;
        }
    }
    if (cases.items.len == 0 or limit < chunk_len or chunk_len < 64)
        return error.InvalidTrainingOptions;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const output = &stdout_writer.interface;
    try output.writeAll(
        "label\tcategory\tinput_bytes\ttraining_samples\tvalidation_samples" ++
            "\tbaseline_frames\ttrained_frames\tdictionary_bytes\ttotal_bytes" ++
            "\tsavings\tratio_ppm\twinner\tword_profile\tword_min\tword_max" ++
            "\tmax_words_per_length\tword_bucket_candidates\tsparse_profile" ++
            "\tword_pruning_steps\tword_caps" ++
            "\tcover_d\tcover_hash_log" ++
            "\tcontext_profile\tcontext_mode\tcontext_cutoff\tcontext_clusters" ++
            "\ttransform_profile\ttransform_lists\tshift_parameters" ++
            "\tshadow_winner\tshadow_frames\tshadow_dictionary_bytes" ++
            "\tshadow_frame_savings\tbreak_even_batches\tbreak_even_frames" ++
            "\tshadow_word_profile\tshadow_word_min\tshadow_word_max" ++
            "\tshadow_max_words_per_length\tshadow_word_bucket_candidates" ++
            "\tshadow_sparse_profile\tshadow_word_pruning_steps\tshadow_word_caps" ++
            "\tshadow_cover_d\tshadow_cover_hash_log" ++
            "\ttrain_ns\tshadow_train_ns\tpeak_bytes" ++
            "\tworst_sample_delta\tshadow_worst_sample_delta\n",
    );
    for (cases.items) |case| try reportCase(init, output, case, limit, chunk_len);
    try output.flush();
}

fn reportCase(
    init: std.process.Init,
    output: *std.Io.Writer,
    case: Case,
    limit: usize,
    chunk_len: usize,
) !void {
    const payload = try readFilePrefixAlloc(init, case.path, limit);
    defer init.gpa.free(payload);
    var training: std.ArrayList([]const u8) = .empty;
    defer training.deinit(init.gpa);
    var validation: std.ArrayList([]const u8) = .empty;
    defer validation.deinit(init.gpa);
    var offset: usize = 0;
    var chunk_index: usize = 0;
    while (offset + chunk_len <= payload.len) : ({
        offset += chunk_len;
        chunk_index += 1;
    }) {
        const chunk = payload[offset..][0..chunk_len];
        if (chunk_index % 2 == 1)
            try validation.append(init.gpa, chunk)
        else
            try training.append(init.gpa, chunk);
    }
    if (training.items.len < 5 or validation.items.len == 0)
        return error.InvalidTrainingOptions;

    const baseline = try frameBytes(init.gpa, validation.items, null);
    var train_options: vort.BrotliSerializedSharedDictionaryTrainOptions = .{
        .min_word_len = 4,
        .max_word_len = 16,
        .max_words_per_length = 8,
        .max_phrases_per_length = 64,
        .cover_dmer_sizes = &.{ 6, 8 },
        .cover_hash_logs = &.{12},
        .max_cover_candidates = 2,
        .context_cutoffs = &.{32},
        .context_modes = &.{ 0, 2 },
        .train_context_clustering = false,
        .train_prefix_suffix_transforms = false,
        .train_shift_transforms = false,
        .max_transform_cluster_dictionaries = 2,
        .quality = 5,
    };
    if (std.mem.eql(u8, case.category, "structured")) {
        train_options.optimize_word_bucket_caps = true;
        train_options.max_word_bucket_pruning_steps = 2;
    }
    var counting = CountingAllocator{ .child = init.gpa };
    const training_allocator = counting.allocator();
    const started = std.Io.Clock.awake.now(init.io);
    const trained = try vort.brTrainSerializedSharedDictionaryAlloc(
        training_allocator,
        training.items,
        validation.items,
        train_options,
    );
    const elapsed_ns: u64 = @intCast(started.untilNow(init.io, .awake).toNanoseconds());
    const peak_bytes = counting.peak_bytes;
    defer if (trained) |result| result.deinit(training_allocator);
    const repeated = try vort.brTrainSerializedSharedDictionaryAlloc(
        init.gpa,
        training.items,
        validation.items,
        train_options,
    );
    defer if (repeated) |result| result.deinit(init.gpa);
    try verifyDeterministic(trained, repeated);

    var shadow_options = train_options;
    shadow_options.include_dictionary_size = false;
    const shadow_started = std.Io.Clock.awake.now(init.io);
    const shadow = try vort.brTrainSerializedSharedDictionaryAlloc(
        init.gpa,
        training.items,
        validation.items,
        shadow_options,
    );
    const shadow_elapsed_ns: u64 = @intCast(
        shadow_started.untilNow(init.io, .awake).toNanoseconds(),
    );
    defer if (shadow) |result| result.deinit(init.gpa);
    const shadow_repeated = try vort.brTrainSerializedSharedDictionaryAlloc(
        init.gpa,
        training.items,
        validation.items,
        shadow_options,
    );
    defer if (shadow_repeated) |result| result.deinit(init.gpa);
    try verifyDeterministic(shadow, shadow_repeated);

    var trained_frames = baseline;
    var dictionary_bytes: usize = 0;
    var savings: usize = 0;
    var worst_delta: i64 = 0;
    if (trained) |*result| {
        trained_frames = result.trained_frame_bytes;
        dictionary_bytes = result.charged_dictionary_bytes;
        savings = result.total_savings_bytes;
        worst_delta = try worstDeltaForDictionary(init, validation.items, result);
    }
    const total_bytes = trained_frames + dictionary_bytes;
    if (total_bytes > baseline or baseline - total_bytes != savings)
        return error.TestUnexpectedResult;
    const ratio_ppm: usize = @intCast(
        @as(u128, total_bytes) * 1_000_000 / baseline,
    );

    var shadow_frames = baseline;
    var shadow_dictionary_bytes: usize = 0;
    var shadow_frame_savings: usize = 0;
    var break_even_batches: usize = 0;
    var break_even_frames: usize = 0;
    var shadow_worst_delta: i64 = 0;
    if (shadow) |*result| {
        if (result.charged_dictionary_bytes != 0)
            return error.TestUnexpectedResult;
        shadow_frames = result.trained_frame_bytes;
        shadow_dictionary_bytes = result.bytes.len;
        shadow_frame_savings = baseline - shadow_frames;
        if (shadow_frame_savings == 0) return error.TestUnexpectedResult;
        break_even_batches = divCeil(shadow_dictionary_bytes, shadow_frame_savings);
        const scaled_dictionary_bytes = std.math.mul(
            usize,
            shadow_dictionary_bytes,
            validation.items.len,
        ) catch return error.IntegerOverflow;
        break_even_frames = divCeil(
            scaled_dictionary_bytes,
            shadow_frame_savings,
        );
        shadow_worst_delta = try worstDeltaForDictionary(
            init,
            validation.items,
            result,
        );
    }

    try output.print(
        "{s}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}",
        .{
            case.label,
            case.category,
            payload.len,
            training.items.len,
            validation.items.len,
            baseline,
            trained_frames,
            dictionary_bytes,
            total_bytes,
            savings,
            ratio_ppm,
            @intFromBool(trained != null),
        },
    );
    if (trained) |result| {
        try output.print("\t{s}\t{d}\t{d}\t{d}\t{d}", .{
            @tagName(result.word_selection_profile),
            result.selected_min_word_len,
            result.selected_max_word_len,
            result.selected_max_words_per_length,
            result.word_bucket_candidates_evaluated,
        });
        try printOptional(output, result.selected_sparse_word_profile);
        try output.print("\t{d}", .{result.word_bucket_pruning_steps});
        try printWordCaps(
            output,
            result.selected_word_count_caps_by_length,
            result.selected_min_word_len,
            result.selected_max_word_len,
        );
        try printOptional(output, result.cover_dmer_size);
        try printOptional(output, result.cover_hash_log);
        try output.print("\t{s}", .{@tagName(result.context_profile)});
        try printOptional(output, result.trained_context_mode);
        try printOptional(output, result.context_cutoff);
        try output.print(
            "\t{d}\t{s}\t{d}\t{d}",
            .{
                result.context_cluster_count,
                @tagName(result.transform_profile),
                result.transform_list_count,
                result.learned_shift_parameter_count,
            },
        );
    } else {
        try output.writeAll("\tnone\t0\t0\t0\t0\t-\t0\t-\t-\t-\tnone\t-\t-\t0\tnone\t0\t0");
    }
    try output.print("\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}", .{
        @intFromBool(shadow != null),
        shadow_frames,
        shadow_dictionary_bytes,
        shadow_frame_savings,
        break_even_batches,
        break_even_frames,
    });
    if (shadow) |result| {
        try output.print("\t{s}\t{d}\t{d}\t{d}\t{d}", .{
            @tagName(result.word_selection_profile),
            result.selected_min_word_len,
            result.selected_max_word_len,
            result.selected_max_words_per_length,
            result.word_bucket_candidates_evaluated,
        });
        try printOptional(output, result.selected_sparse_word_profile);
        try output.print("\t{d}", .{result.word_bucket_pruning_steps});
        try printWordCaps(
            output,
            result.selected_word_count_caps_by_length,
            result.selected_min_word_len,
            result.selected_max_word_len,
        );
        try printOptional(output, result.cover_dmer_size);
        try printOptional(output, result.cover_hash_log);
    } else {
        try output.writeAll("\tnone\t0\t0\t0\t0\t-\t0\t-\t-\t-");
    }
    try output.print("\t{d}\t{d}\t{d}\t{d}\t{d}\n", .{
        elapsed_ns,
        shadow_elapsed_ns,
        peak_bytes,
        worst_delta,
        shadow_worst_delta,
    });
}

fn verifyDeterministic(
    first: ?vort.BrotliOwnedTrainedSerializedSharedDictionary,
    second: ?vort.BrotliOwnedTrainedSerializedSharedDictionary,
) !void {
    if ((first == null) != (second == null)) return error.TestUnexpectedResult;
    if (first) |a| {
        const b = second.?;
        if (!std.mem.eql(u8, a.bytes, b.bytes) or
            a.id.asInt() != b.id.asInt() or
            a.baseline_frame_bytes != b.baseline_frame_bytes or
            a.trained_frame_bytes != b.trained_frame_bytes or
            a.charged_dictionary_bytes != b.charged_dictionary_bytes or
            a.total_savings_bytes != b.total_savings_bytes or
            a.selected_min_word_len != b.selected_min_word_len or
            a.selected_max_word_len != b.selected_max_word_len or
            a.selected_max_words_per_length != b.selected_max_words_per_length or
            !std.meta.eql(
                a.selected_word_count_caps_by_length,
                b.selected_word_count_caps_by_length,
            ) or
            a.word_bucket_pruning_steps != b.word_bucket_pruning_steps or
            a.word_bucket_candidates_evaluated != b.word_bucket_candidates_evaluated or
            a.selected_sparse_word_profile != b.selected_sparse_word_profile or
            a.word_selection_profile != b.word_selection_profile or
            a.cover_dmer_size != b.cover_dmer_size or
            a.cover_hash_log != b.cover_hash_log or
            a.cover_candidates_evaluated != b.cover_candidates_evaluated or
            a.context_profile != b.context_profile or
            a.transform_profile != b.transform_profile)
        {
            return error.TestUnexpectedResult;
        }
    }
}

fn worstDeltaForDictionary(
    init: std.process.Init,
    samples: []const []const u8,
    result: *const vort.BrotliOwnedTrainedSerializedSharedDictionary,
) !i64 {
    const parsed = try result.parse();
    var worst_delta: i64 = std.math.minInt(i64);
    for (samples) |sample| {
        const plain = try vort.brEncodePlannedStreamWithOptionsAlloc(
            init.gpa,
            sample,
            .{ .quality = 5 },
        );
        defer init.gpa.free(plain);
        const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(
            init.gpa,
            sample,
            .{
                .quality = 5,
                .shared_dictionary = .{ .serialized = &parsed },
            },
        );
        defer init.gpa.free(encoded);
        const decoded = try vort.brDecodeStreamAllocExactSizeWithOptions(
            init.gpa,
            encoded,
            sample.len,
            .{ .shared_dictionary = .{ .serialized = &parsed } },
        );
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, sample, decoded)) return error.RoundTripMismatch;
        const delta = @as(i64, @intCast(encoded.len)) -
            @as(i64, @intCast(plain.len));
        worst_delta = @max(worst_delta, delta);
    }
    return worst_delta;
}

fn divCeil(numerator: usize, denominator: usize) usize {
    std.debug.assert(denominator != 0);
    return numerator / denominator + @intFromBool(numerator % denominator != 0);
}

fn printOptional(output: *std.Io.Writer, value: anytype) !void {
    if (value) |active|
        try output.print("\t{d}", .{active})
    else
        try output.writeAll("\t-");
}

fn printWordCaps(
    output: *std.Io.Writer,
    maybe_caps: ?[32]u16,
    min_word_len: u5,
    max_word_len: u5,
) !void {
    const caps = maybe_caps orelse {
        try output.writeAll("\t-");
        return;
    };
    try output.writeByte('\t');
    for (min_word_len..max_word_len + 1) |word_len| {
        if (word_len != min_word_len) try output.writeByte(',');
        try output.print("{d}:{d}", .{ word_len, caps[word_len] });
    }
}

fn frameBytes(
    allocator: std.mem.Allocator,
    samples: []const []const u8,
    shared: ?vort.BrotliSharedDictionary,
) !usize {
    var total: usize = 0;
    for (samples) |sample| {
        const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(
            allocator,
            sample,
            .{
                .quality = 5,
                .shared_dictionary = shared orelse .{},
            },
        );
        defer allocator.free(encoded);
        total += encoded.len;
    }
    return total;
}

fn readFilePrefixAlloc(init: std.process.Init, path: []const u8, limit: usize) ![]u8 {
    const stat = try std.Io.Dir.cwd().statFile(init.io, path, .{});
    const file_len = std.math.cast(usize, stat.size) orelse limit;
    const prefix_len = @min(file_len, limit);
    const payload = try init.gpa.alloc(u8, prefix_len);
    errdefer init.gpa.free(payload);
    var file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const read_len = try file.readPositionalAll(init.io, payload, 0);
    return init.gpa.realloc(payload, read_len);
}
