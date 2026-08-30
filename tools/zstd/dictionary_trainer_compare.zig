const std = @import("std");
const vort = @import("vort");
const libzstd = @import("libzstd_runtime.zig");

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
    const reference_path = args.next() orelse return error.MissingCorpusPath;
    const generated_path = args.next() orelse return error.MissingCorpusPath;
    const target_size = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const training_count = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const selector_count = try parseCount(args.next() orelse return error.InvalidBlockPlan);
    const heldout_count = try parseCount(args.next() orelse return error.InvalidBlockPlan);

    var training: Corpus = .{};
    defer training.deinit(init.gpa);
    var selector: Corpus = .{};
    defer selector.deinit(init.gpa);
    var heldout: Corpus = .{};
    defer heldout.deinit(init.gpa);
    try training.read(init.io, init.gpa, &args, training_count);
    try selector.read(init.io, init.gpa, &args, selector_count);
    try heldout.read(init.io, init.gpa, &args, heldout_count);
    if (args.next() != null or training_count == 0 or selector_count == 0 or heldout_count == 0) return error.InvalidBlockPlan;

    const reference_bytes = try std.Io.Dir.cwd().readFileAlloc(init.io, reference_path, init.gpa, .limited(1 << 20));
    defer init.gpa.free(reference_bytes);
    const reference = try vort.ZstdNativeDictionary.initFromStandardDictionary(reference_bytes);
    const dictionary_id = if (reference.view.id == std.math.maxInt(u32)) 1 else reference.view.id + 1;
    const trained = try vort.zstdTrainValidatedStandardDictionaryAlloc(
        init.gpa,
        training.slices.items,
        selector.slices.items,
        .{ .target_size = target_size },
        dictionary_id,
    );
    defer trained.deinit(init.gpa);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = generated_path, .data = trained.bytes });

    var runtime = try libzstd.Runtime.open();
    defer runtime.deinit();
    var vort_sizes: [3]usize = @splat(0);
    var reference_sizes: [3]usize = @splat(0);
    const levels = [_]c_int{ 1, 3, 9 };
    for (heldout.slices.items) |payload| {
        for (levels, 0..) |level, level_index| {
            const vort_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, trained.bytes, level);
            defer init.gpa.free(vort_encoded);
            const reference_encoded = try runtime.encodeUsingDictAlloc(init.gpa, payload, reference_bytes, level);
            defer init.gpa.free(reference_encoded);
            vort_sizes[level_index] += vort_encoded.len;
            reference_sizes[level_index] += reference_encoded.len;

            const vort_decoded = try vort.zstdDecodeFrameAllocWithDictionary(init.gpa, vort_encoded, trained.asDictionary());
            defer init.gpa.free(vort_decoded);
            if (!std.mem.eql(u8, payload, vort_decoded)) return error.SizeMismatch;
            const reference_decoded = try vort.zstdDecodeFrameAllocWithDictionary(init.gpa, reference_encoded, reference.dictionary);
            defer init.gpa.free(reference_decoded);
            if (!std.mem.eql(u8, payload, reference_decoded)) return error.SizeMismatch;

            const reference_output = try init.gpa.alloc(u8, payload.len);
            defer init.gpa.free(reference_output);
            try runtime.decodeUsingDict(vort_encoded, reference_output, trained.bytes);
            if (!std.mem.eql(u8, payload, reference_output)) return error.SizeMismatch;
        }
    }

    var buffer: [512]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.print(
        "zstd_dictionary_trainer_compare=ok case={s} samples={d}/{d}/{d} target={d} content={d}/{d} dict={d}/{d} level1={d}/{d} level3={d}/{d} level9={d}/{d}\n",
        .{ case_name, training_count, selector_count, heldout_count, target_size, trained.view.content.len, reference.view.content.len, trained.bytes.len, reference_bytes.len, vort_sizes[0], reference_sizes[0], vort_sizes[1], reference_sizes[1], vort_sizes[2], reference_sizes[2] },
    );
    try stdout.interface.flush();
}

fn parseCount(bytes: []const u8) !usize {
    return std.fmt.parseUnsigned(usize, bytes, 10) catch return error.InvalidBlockPlan;
}
