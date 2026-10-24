const std = @import("std");
const serialized_dictionary = @import("serialized_dictionary.zig");

pub const max_transforms: usize = 16;
pub const max_candidates: usize = 64 * 1024;
pub const max_words: usize = 4096;
pub const max_positions: usize = 64 * 1024;

pub const Options = struct {
    max_transforms: u8 = 8,
    max_candidates: usize = 4096,
    max_words: usize = 256,
    max_positions: usize = 4096,
    min_occurrences: u16 = 2,
};

pub const Error = error{
    InvalidTrainingOptions,
    IntegerOverflow,
};

pub const Spec = struct {
    kind: u8,
    parameter: u16,
    count: u32,
    matched_bytes: u64,
};

pub const Plan = struct {
    specs: []Spec,

    pub fn deinit(self: Plan, allocator: std.mem.Allocator) void {
        allocator.free(self.specs);
    }
};

const Stat = struct {
    count: u32 = 0,
    matched_bytes: u64 = 0,
};

const Scalar = struct {
    value: u32,
    modulus: u32,
};

pub fn learnAlloc(
    allocator: std.mem.Allocator,
    dictionary: *const serialized_dictionary.Dictionary,
    samples: []const []const u8,
    options: Options,
) (Error || std.mem.Allocator.Error)!?Plan {
    try validateOptions(options);
    if (samples.len == 0) return null;

    var seen: std.StringHashMapUnmanaged(void) = .empty;
    defer seen.deinit(allocator);
    var words: std.ArrayList([]const u8) = .empty;
    defer words.deinit(allocator);
    outer: for (dictionary.word_lists[0..dictionary.word_list_count]) |*word_list| {
        for (serialized_dictionary.min_word_len..serialized_dictionary.max_word_len + 1) |word_len| {
            for (0..word_list.wordCount(word_len)) |word_index| {
                const word = word_list.word(word_len, word_index) orelse
                    return error.InvalidTrainingOptions;
                const entry = try seen.getOrPut(allocator, word);
                if (!entry.found_existing)
                    try words.append(allocator, word);
                if (words.items.len == options.max_words) break :outer;
            }
        }
    }
    if (words.items.len == 0) return null;

    var total_positions: usize = 0;
    for (samples) |sample|
        total_positions = std.math.add(usize, total_positions, sample.len) catch
            return error.IntegerOverflow;
    if (total_positions == 0) return null;
    const rounded = std.math.add(
        usize,
        total_positions,
        options.max_positions - 1,
    ) catch return error.IntegerOverflow;
    const stride = @max(@as(usize, 1), rounded / options.max_positions);

    var stats: std.AutoHashMapUnmanaged(u32, Stat) = .empty;
    defer stats.deinit(allocator);
    var ordinal: usize = 0;
    var sampled: usize = 0;
    outer_samples: for (samples) |sample| {
        for (0..sample.len) |position| {
            if (ordinal % stride == 0) {
                for (words.items) |word| {
                    if (word.len > sample.len - position) continue;
                    const target = sample[position..][0..word.len];
                    const parameter = inferParameter(word, target) orelse continue;
                    if (parameter == 0) continue;
                    for ([_]bool{ false, true }) |all| {
                        var shifted: [serialized_dictionary.max_word_len]u8 = undefined;
                        @memcpy(shifted[0..word.len], word);
                        serialized_dictionary.applyShiftUtf8(
                            shifted[0..word.len],
                            parameter,
                            all,
                        );
                        if (!std.mem.eql(u8, shifted[0..word.len], target))
                            continue;
                        try record(
                            allocator,
                            &stats,
                            if (all) 22 else 21,
                            parameter,
                            word.len,
                            options.max_candidates,
                        );
                    }
                }
                sampled += 1;
                if (sampled == options.max_positions) break :outer_samples;
            }
            ordinal += 1;
        }
    }

    var ranked = try allocator.alloc(Spec, stats.count());
    defer allocator.free(ranked);
    var ranked_count: usize = 0;
    var iterator = stats.iterator();
    while (iterator.next()) |entry| {
        if (entry.value_ptr.count < options.min_occurrences) continue;
        ranked[ranked_count] = .{
            .kind = @intCast(entry.key_ptr.* >> 16),
            .parameter = @truncate(entry.key_ptr.*),
            .count = entry.value_ptr.count,
            .matched_bytes = entry.value_ptr.matched_bytes,
        };
        ranked_count += 1;
    }
    ranked = try allocator.realloc(ranked, ranked_count);
    if (ranked.len == 0) return null;
    std.mem.sort(Spec, ranked, {}, rankedLessThan);
    const selected_count = @min(ranked.len, options.max_transforms);
    const specs = try allocator.dupe(Spec, ranked[0..selected_count]);
    return .{ .specs = specs };
}

fn validateOptions(options: Options) Error!void {
    if (options.max_transforms == 0 or options.max_transforms > max_transforms or
        options.max_candidates < options.max_transforms or
        options.max_candidates > max_candidates or
        options.max_words == 0 or options.max_words > max_words or
        options.max_positions == 0 or options.max_positions > max_positions or
        options.min_occurrences == 0)
    {
        return error.InvalidTrainingOptions;
    }
}

fn inferParameter(source: []const u8, target: []const u8) ?u16 {
    const source_scalar = decodeFirst(source) orelse return null;
    const target_scalar = decodeFirst(target) orelse return null;
    if (source_scalar.modulus != target_scalar.modulus) return null;
    const raw = @as(i64, target_scalar.value) - source_scalar.value;
    const modulus: i64 = source_scalar.modulus;
    var best: ?i16 = null;
    for ([_]i64{ raw, raw - modulus, raw + modulus }) |candidate| {
        if (candidate < std.math.minInt(i16) or
            candidate > std.math.maxInt(i16)) continue;
        const value: i16 = @intCast(candidate);
        if (best == null or absI16(value) < absI16(best.?) or
            (absI16(value) == absI16(best.?) and value < best.?))
        {
            best = value;
        }
    }
    return if (best) |value| @bitCast(value) else null;
}

fn decodeFirst(bytes: []const u8) ?Scalar {
    if (bytes.len == 0) return null;
    const first = bytes[0];
    if (first < 0x80) return .{ .value = first, .modulus = 1 << 7 };
    if (first < 0xc0) return null;
    if (first < 0xe0) {
        if (bytes.len < 2) return null;
        return .{
            .value = (bytes[1] & 0x3f) |
                (@as(u32, first & 0x1f) << 6),
            .modulus = 1 << 11,
        };
    }
    if (first < 0xf0) {
        if (bytes.len < 3) return null;
        return .{
            .value = (bytes[2] & 0x3f) |
                (@as(u32, bytes[1] & 0x3f) << 6) |
                (@as(u32, first & 0x0f) << 12),
            .modulus = 1 << 16,
        };
    }
    if (first < 0xf8) {
        if (bytes.len < 4) return null;
        return .{
            .value = (bytes[3] & 0x3f) |
                (@as(u32, bytes[2] & 0x3f) << 6) |
                (@as(u32, bytes[1] & 0x3f) << 12) |
                (@as(u32, first & 0x07) << 18),
            .modulus = 1 << 21,
        };
    }
    return null;
}

fn record(
    allocator: std.mem.Allocator,
    stats: *std.AutoHashMapUnmanaged(u32, Stat),
    kind: u8,
    parameter: u16,
    matched_bytes: usize,
    limit: usize,
) std.mem.Allocator.Error!void {
    const key = (@as(u32, kind) << 16) | parameter;
    if (stats.getPtr(key)) |stat| {
        stat.count +|= 1;
        stat.matched_bytes +|= matched_bytes;
        return;
    }
    if (stats.count() == limit) return;
    try stats.put(allocator, key, .{
        .count = 1,
        .matched_bytes = matched_bytes,
    });
}

fn rankedLessThan(_: void, a: Spec, b: Spec) bool {
    if (a.matched_bytes != b.matched_bytes)
        return a.matched_bytes > b.matched_bytes;
    if (a.count != b.count) return a.count > b.count;
    if (a.kind != b.kind) return a.kind < b.kind;
    const a_signed: i16 = @bitCast(a.parameter);
    const b_signed: i16 = @bitCast(b.parameter);
    if (absI16(a_signed) != absI16(b_signed))
        return absI16(a_signed) < absI16(b_signed);
    return a_signed < b_signed;
}

fn absI16(value: i16) u16 {
    const wide: i32 = value;
    return @intCast(if (wide < 0) -wide else wide);
}

test "serialized shift trainer learns first and all signed deltas" {
    try std.testing.expectEqual(
        @as(u16, 0xffff),
        inferParameter("bcde", "acde").?,
    );
    const builder = @import("serialized_dictionary_builder.zig");
    var size_bits: [32]u8 = @splat(0);
    size_bits[4] = 1;
    const word_lists = [_]builder.WordListSpec{.{
        .size_bits_by_length = size_bits,
        .data = "abcdwxyz",
    }};
    const transforms = [_]builder.TransformListSpec{.{
        .prefix_suffix = &.{0},
        .transforms = &.{ 0, 0, 0 },
    }};
    const choices = [_]serialized_dictionary.DictionaryChoice{.{
        .word_list_index = 0,
        .transform_list_index = 0,
    }};
    const encoded = try builder.serializeAlloc(std.testing.allocator, .{
        .word_lists = &word_lists,
        .transform_lists = &transforms,
        .dictionaries = &choices,
    });
    defer std.testing.allocator.free(encoded);
    const dictionary = try serialized_dictionary.parse(encoded);
    const samples = [_][]const u8{
        "bbcd bcde xx y",
        "bbcd bcde xx y",
        "xxyz xyz{ bbcd bcde",
        "xxyz xyz{ bbcd bcde",
    };
    const plan = (try learnAlloc(
        std.testing.allocator,
        &dictionary,
        &samples,
        .{
            .max_transforms = 4,
            .max_candidates = 32,
            .max_words = 8,
            .max_positions = 128,
        },
    )).?;
    defer plan.deinit(std.testing.allocator);
    var saw_first = false;
    var saw_all = false;
    for (plan.specs) |spec| {
        if (spec.parameter != 1) continue;
        saw_first = saw_first or spec.kind == 21;
        saw_all = saw_all or spec.kind == 22;
    }
    try std.testing.expect(saw_first);
    try std.testing.expect(saw_all);
}

test "serialized shift trainer validates bounds and releases failures" {
    var invalid_dictionary: serialized_dictionary.Dictionary = undefined;
    try std.testing.expectError(
        error.InvalidTrainingOptions,
        learnAlloc(std.testing.allocator, &invalid_dictionary, &.{}, .{
            .max_transforms = 0,
        }),
    );

    const Test = struct {
        fn run(allocator: std.mem.Allocator) !void {
            const builder = @import("serialized_dictionary_builder.zig");
            var size_bits: [32]u8 = @splat(0);
            size_bits[4] = 1;
            const word_lists = [_]builder.WordListSpec{.{
                .size_bits_by_length = size_bits,
                .data = "abcdwxyz",
            }};
            const transforms = [_]builder.TransformListSpec{.{
                .prefix_suffix = &.{0},
                .transforms = &.{ 0, 0, 0 },
            }};
            const choices = [_]serialized_dictionary.DictionaryChoice{.{
                .word_list_index = 0,
                .transform_list_index = 0,
            }};
            const encoded = try builder.serializeAlloc(allocator, .{
                .word_lists = &word_lists,
                .transform_lists = &transforms,
                .dictionaries = &choices,
            });
            defer allocator.free(encoded);
            const dictionary = try serialized_dictionary.parse(encoded);
            const plan = (try learnAlloc(
                allocator,
                &dictionary,
                &.{ "bbcd bcde xxyz xyz{", "bbcd bcde xxyz xyz{" },
                .{
                    .max_transforms = 4,
                    .max_candidates = 32,
                    .max_words = 8,
                    .max_positions = 64,
                },
            )) orelse return error.TestUnexpectedResult;
            defer plan.deinit(allocator);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        Test.run,
        .{},
    );
}
