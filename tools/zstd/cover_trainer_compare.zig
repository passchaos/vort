const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");
const train_rounds: usize = 3;

const Corpus = struct {
    slices: std.ArrayList([]const u8) = .empty,
    owned: std.ArrayList([]u8) = .empty,

    fn read(
        self: *Corpus,
        io: std.Io,
        allocator: std.mem.Allocator,
        args: *std.process.Args.Iterator,
        count: usize,
    ) !void {
        try self.slices.ensureUnusedCapacity(allocator, count);
        try self.owned.ensureUnusedCapacity(allocator, count);
        for (0..count) |_| {
            const path = args.next() orelse return error.MissingCorpusPath;
            const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1 << 20));
            self.owned.appendAssumeCapacity(bytes);
            self.slices.appendAssumeCapacity(bytes);
        }
    }

    fn deinit(self: *Corpus, allocator: std.mem.Allocator) void {
        for (self.owned.items) |bytes| allocator.free(bytes);
        self.owned.deinit(allocator);
        self.slices.deinit(allocator);
        self.* = .{};
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const case_name = args.next() orelse return error.InvalidBlockPlan;
    const cover_path = args.next() orelse return error.MissingCorpusPath;
    const fastcover_path = args.next() orelse return error.MissingCorpusPath;
    const generated_path = args.next() orelse return error.MissingCorpusPath;
    const target_size = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const training_count = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const selector_count = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const heldout_count = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const reference_cover_ns = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const reference_fastcover_ns = try parseCount(args.next() orelse return error.InvalidBlockPlan);

    var training: Corpus = .{};
    defer training.deinit(init.gpa);
    var selector: Corpus = .{};
    defer selector.deinit(init.gpa);
    var heldout: Corpus = .{};
    defer heldout.deinit(init.gpa);
    try training.read(init.io, init.gpa, &args, training_count);
    try selector.read(init.io, init.gpa, &args, selector_count);
    try heldout.read(init.io, init.gpa, &args, heldout_count);
    if (args.next() != null or training_count < 5 or selector_count == 0 or heldout_count == 0)
        return error.InvalidBlockPlan;

    const cover_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, cover_path, init.gpa, .limited(1 << 20));
    defer init.gpa.free(cover_bytes);
    const fastcover_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, fastcover_path, init.gpa, .limited(1 << 20));
    defer init.gpa.free(fastcover_bytes);
    const cover_reference = try vort.ZstdNativeDictionary.initFromStandardDictionary(cover_bytes);
    const fastcover_reference = try vort.ZstdNativeDictionary.initFromStandardDictionary(fastcover_bytes);
    const dictionary_id = nextDictionaryId(fastcover_reference.view.id);

    const vort_training = try trainVortBest(
        init,
        training.slices.items,
        selector.slices.items,
        target_size,
        dictionary_id,
    );
    const trained = vort_training.dictionary;
    const vort_train_ns = vort_training.best_ns;
    defer trained.deinit(init.gpa);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = generated_path, .data = trained.bytes });

    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();
    var vort_sizes: [3]usize = @splat(0);
    var cover_sizes: [3]usize = @splat(0);
    var fastcover_sizes: [3]usize = @splat(0);
    const levels = [_]c_int{ 1, 3, 9 };
    for (heldout.slices.items) |payload| {
        for (levels, 0..) |level, level_index| {
            const vort_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, trained.bytes, level);
            defer init.gpa.free(vort_encoded);
            const cover_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, cover_bytes, level);
            defer init.gpa.free(cover_encoded);
            const fastcover_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, fastcover_bytes, level);
            defer init.gpa.free(fastcover_encoded);
            vort_sizes[level_index] += vort_encoded.len;
            cover_sizes[level_index] += cover_encoded.len;
            fastcover_sizes[level_index] += fastcover_encoded.len;

            try expectDecoded(init.gpa, payload, vort_encoded, trained.asDictionary());
            try expectDecoded(init.gpa, payload, cover_encoded, cover_reference.dictionary);
            try expectDecoded(init.gpa, payload, fastcover_encoded, fastcover_reference.dictionary);

            const reference_output = try init.gpa.alloc(u8, payload.len);
            defer init.gpa.free(reference_output);
            try runtime.decodeUsingDict(vort_encoded, reference_output, trained.bytes);
            if (!std.mem.eql(u8, payload, reference_output)) return error.SizeMismatch;
        }

        const native = try vort.zstdEncodeNativeFrameWithDictionaryAlloc(
            init.gpa,
            payload,
            .{ .content_checksum = false },
            trained.asDictionary(),
        );
        defer init.gpa.free(native.frame);
        const reference_output = try init.gpa.alloc(u8, payload.len);
        defer init.gpa.free(reference_output);
        try runtime.decodeUsingDict(native.frame, reference_output, trained.bytes);
        if (!std.mem.eql(u8, payload, reference_output)) return error.SizeMismatch;
    }

    var buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print(
        "zstd_cover_trainer_compare=ok case={s} samples={d}/{d}/{d} target={d} candidates={d} selected={d}/{d}/{d} content={d}/{d}/{d} dict={d}/{d}/{d} level1={d}/{d}/{d} level3={d}/{d}/{d} level9={d}/{d}/{d} train_ns={d}/{d}/{d} rounds={d} version={s}\n",
        .{
            case_name,
            training_count,
            selector_count,
            heldout_count,
            target_size,
            trained.candidates_evaluated,
            trained.selected_options.segment_size.?,
            trained.selected_options.dmer_size,
            trained.selected_options.hash_log,
            trained.view.content.len,
            cover_reference.view.content.len,
            fastcover_reference.view.content.len,
            trained.bytes.len,
            cover_bytes.len,
            fastcover_bytes.len,
            vort_sizes[0],
            cover_sizes[0],
            fastcover_sizes[0],
            vort_sizes[1],
            cover_sizes[1],
            fastcover_sizes[1],
            vort_sizes[2],
            cover_sizes[2],
            fastcover_sizes[2],
            vort_train_ns,
            reference_cover_ns,
            reference_fastcover_ns,
            train_rounds,
            runtime.version(),
        },
    );
    try stdout.interface.flush();
}

const VortTraining = struct {
    dictionary: vort.ZstdOwnedOptimizedCoverStandardDictionary,
    best_ns: usize,
};

fn trainVortBest(
    init: std.process.Init,
    training: []const []const u8,
    selector: []const []const u8,
    target_size: usize,
    dictionary_id: u32,
) !VortTraining {
    var retained: ?vort.ZstdOwnedOptimizedCoverStandardDictionary = null;
    errdefer if (retained) |dictionary| dictionary.deinit(init.gpa);
    var best_ns: usize = std.math.maxInt(usize);
    for (0..train_rounds) |_| {
        const start = std.Io.Clock.awake.now(init.io);
        const candidate = try vort.zstdTrainOptimizedCoverStandardDictionaryAlloc(
            init.gpa,
            training,
            selector,
            .{
                .target_size = target_size,
                .segment_sizes = &.{ 32, 64, 128, 256, 352 },
                .dmer_sizes = &.{ 6, 8 },
                .hash_logs = &.{ 12, 16, 20 },
                .max_candidates = 32,
            },
            dictionary_id,
        );
        best_ns = @min(best_ns, elapsed(start, init.io));
        if (retained) |dictionary| {
            if (!std.mem.eql(u8, dictionary.bytes, candidate.bytes) or
                !std.meta.eql(dictionary.selected_options, candidate.selected_options) or
                !std.meta.eql(dictionary.validation_score, candidate.validation_score))
            {
                candidate.deinit(init.gpa);
                return error.InvalidDictionaryTraining;
            }
            candidate.deinit(init.gpa);
        } else retained = candidate;
    }
    return .{ .dictionary = retained.?, .best_ns = best_ns };
}

fn expectDecoded(
    allocator: std.mem.Allocator,
    expected: []const u8,
    encoded: []const u8,
    dictionary: vort.ZstdDictionary,
) !void {
    const decoded = try vort.zstdDecodeFrameAllocWithDictionary(allocator, encoded, dictionary);
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, expected, decoded)) return error.SizeMismatch;
}

fn nextDictionaryId(id: u32) u32 {
    return if (id == std.math.maxInt(u32)) 1 else id + 1;
}

fn elapsed(start: std.Io.Timestamp, io: std.Io) usize {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 1 else @intCast(ns);
}

fn parseCount(bytes: []const u8) !usize {
    return std.fmt.parseUnsigned(usize, bytes, 10) catch return error.InvalidBlockPlan;
}
