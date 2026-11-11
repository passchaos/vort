const std = @import("std");
const sampling = @import("sampling.zig");

const shape = [_][]const u8{
    "--input",  "payload", "--encoded-input", "wire", "--iterations", "3",
    "--rounds", "4",       "--warmup",        "2",    "--lifecycle",  "cold",
};
const deflate = [_][]const u8{ "--codec", "deflate", "--reference", "/pinned/libdeflate.so", "--reference-version", "1.26" };
const zstd = [_][]const u8{ "--codec", "zstd", "--reference", "/pinned/libzstd.so" };
const brotli = [_][]const u8{
    "--codec",          "brotli",                  "--brotli-encoder", "/pinned/libbrotlienc.so",
    "--brotli-decoder", "/pinned/libbrotlidec.so", "--brotli-common",  "/pinned/libbrotlicommon.so",
};

fn setValue(arguments: [][]const u8, flag: []const u8, value: []const u8) void {
    for (arguments, 0..) |argument, i| {
        if (std.mem.eql(u8, argument, flag)) {
            arguments[i + 1] = value;
            return;
        }
    }
    unreachable;
}

test "raw paired samples preserve both orders, warmup boundary, and every outlier" {
    const warmup = 2;
    const rounds = 4;
    var pairs: [warmup + rounds]sampling.Pair = undefined;
    const durations = [_]u64{ 50, 40, 2, 1000, 4, 6 };
    for (&pairs, durations, 0..) |*pair, ns, pair_id| {
        pair.* = sampling.makePair(pair_id, .{ .ns = ns, .mix = 11 }, .{ .ns = 1001 - ns, .mix = 11 });
    }
    var warmup_vort_first: usize = 0;
    var measured_vort_first: usize = 0;
    for (pairs[0..warmup]) |pair| warmup_vort_first += @intFromBool(pair.first == .vort);
    for (pairs[warmup..]) |pair| measured_vort_first += @intFromBool(pair.first == .vort);
    try std.testing.expectEqual(warmup / 2, warmup_vort_first);
    try std.testing.expectEqual(rounds / 2, measured_vort_first);
    try std.testing.expectEqual(@as(usize, 2), pairs[warmup].pair_id);
    try std.testing.expectEqual(@as(usize, 5), pairs[pairs.len - 1].pair_id);
    const original = pairs;
    try std.testing.expectEqual(@as(f64, 5), try sampling.median(std.testing.allocator, pairs[warmup..], .vort));
    try std.testing.expectEqual(@as(f64, 996), try sampling.median(std.testing.allocator, pairs[warmup..], .reference));
    try std.testing.expectEqualDeep(original, pairs);
    try std.testing.expectEqual(@as(u64, 1000), pairs[3].vort_ns);
}

test "median handles odd counts and maximum timer values without integer overflow" {
    const maximum = std.math.maxInt(u64);
    const pairs = [_]sampling.Pair{
        sampling.makePair(0, .{ .ns = maximum, .mix = 0 }, .{ .ns = 1, .mix = 0 }),
        sampling.makePair(1, .{ .ns = maximum - 2, .mix = 0 }, .{ .ns = 9, .mix = 0 }),
        sampling.makePair(2, .{ .ns = 7, .mix = 0 }, .{ .ns = 2, .mix = 0 }),
    };
    try std.testing.expectEqual(@as(f64, 2), try sampling.median(std.testing.allocator, &pairs, .reference));
    const median = try sampling.median(std.testing.allocator, pairs[0..2], .vort);
    try std.testing.expect(std.math.isFinite(median) and median > 1e19);
    try std.testing.expectError(error.EmptySamples, sampling.median(std.testing.allocator, &.{}, .vort));
}

test "CLI accepts explicit cold lifecycles and declared Deflate version" {
    const d = try sampling.parseOptions(&(shape ++ deflate));
    try std.testing.expectEqual(sampling.Codec.deflate, d.codec);
    try std.testing.expectEqualStrings("1.26", d.reference_version.?);
    const z = try sampling.parseOptions(&(shape ++ zstd));
    try std.testing.expectEqual(sampling.Codec.zstd, z.codec);
    try std.testing.expect(z.reference_version == null);
    const br = try sampling.parseOptions(&(shape ++ brotli));
    try std.testing.expectEqual(sampling.Codec.brotli, br.codec);
    try std.testing.expectEqualStrings("/pinned/libbrotlicommon.so", br.brotli_common.?);
}

test "CLI rejects ambiguous timing settings, implicit libraries, and unsupported prepared Brotli" {
    var argv = shape ++ deflate;
    setValue(&argv, "--rounds", "3");
    try std.testing.expectError(error.InvalidRounds, sampling.parseOptions(&argv));
    setValue(&argv, "--rounds", "4");
    setValue(&argv, "--iterations", "0");
    try std.testing.expectError(error.InvalidIterations, sampling.parseOptions(&argv));
    setValue(&argv, "--iterations", "3");
    setValue(&argv, "--warmup", "1");
    try std.testing.expectError(error.InvalidWarmup, sampling.parseOptions(&argv));
    setValue(&argv, "--warmup", "2");
    setValue(&argv, "--reference", "libdeflate.so");
    try std.testing.expectError(error.ReferencePathMustBeAbsolute, sampling.parseOptions(&argv));
    try std.testing.expectError(error.DuplicateOption, sampling.parseOptions(&(shape ++ deflate ++ .{ "--rounds", "4" })));
    try std.testing.expectError(error.MissingReferenceVersion, sampling.parseOptions(&(shape ++ deflate[0..4].*)));
    try std.testing.expectError(error.UnexpectedReferenceVersion, sampling.parseOptions(&(shape ++ zstd ++ .{ "--reference-version", "1.6.0" })));
    var br_argv = shape ++ brotli;
    setValue(&br_argv, "--lifecycle", "prepared");
    try std.testing.expectError(error.UnsupportedPreparedLifecycle, sampling.parseOptions(&br_argv));
    var prepared = shape ++ zstd;
    setValue(&prepared, "--lifecycle", "prepared");
    setValue(&prepared, "--warmup", "0");
    try std.testing.expectEqual(sampling.Lifecycle.prepared, (try sampling.parseOptions(&prepared)).lifecycle);
    try std.testing.expectError(error.UnknownOption, sampling.parseOptions(&(shape ++ zstd ++ .{ "--best-of", "5" })));
}

test "Linux loader maps preserve versioned paths and distinguish common-library origins" {
    const maps =
        "001-002 r--p 0 00:00 1 /run/probe\n" ++
        "002-003 r-xp 0 00:00 2 /pinned build/libbrotlidec.so.1.2.0\n" ++
        "003-004 r--p 0 00:00 2 /pinned build/libbrotlidec.so.1.2.0\n" ++
        "004-005 r-xp 0 00:00 3 /usr/lib/libbrotlicommon.so.1.0.9\n" ++
        "005-006 r--p 0 00:00 4 /pinned build/libbrotlicommon.so.1.2.0\n" ++
        "006-007 rw-p 0 00:00 0 [heap]\n";
    const paths = try sampling.mappedLibrariesAlloc(std.testing.allocator, maps);
    defer {
        for (paths) |path| std.testing.allocator.free(path);
        std.testing.allocator.free(paths);
    }
    try std.testing.expectEqual(@as(usize, 3), paths.len);
    try std.testing.expectEqualStrings("/pinned build/libbrotlicommon.so.1.2.0", paths[0]);
    try std.testing.expectEqualStrings("/pinned build/libbrotlidec.so.1.2.0", paths[1]);
    try std.testing.expectEqualStrings("/usr/lib/libbrotlicommon.so.1.0.9", paths[2]);
}

test "aligned guards detect both sides including empty and non-aligned payloads" {
    for ([_]usize{ 0, 1, 64, 65 }) |len| {
        const guarded = try sampling.GuardedBuffer.init(std.testing.allocator, len);
        defer guarded.deinit(std.testing.allocator);
        try std.testing.expectEqual(@as(usize, 0), @intFromPtr(guarded.data.ptr) % 64);
        @memset(guarded.data, 0x5a);
        try guarded.validate();
        guarded.storage[63] = 0;
        try std.testing.expectError(error.GuardCorrupted, guarded.validate());
        guarded.storage[63] = 0xc7;
        guarded.storage[64 + len] = 0;
        try std.testing.expectError(error.GuardCorrupted, guarded.validate());
    }
}

test "output aliases reject exact paths, symlinks, and hardlinks without changing sentinels" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const sentinel = "frozen fixture sentinel\x00\xff";
    try tmp.dir.writeFile(io, .{ .sub_path = "source", .data = sentinel });
    try tmp.dir.writeFile(io, .{ .sub_path = "other", .data = "existing artifact" });
    try tmp.dir.symLink(io, "source", "symbolic", .{});
    try tmp.dir.hardLink("source", tmp.dir, "hard", io, .{});
    const source = try tmp.dir.realPathFileAlloc(io, "source", allocator);
    defer allocator.free(source);
    const directory = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(directory);
    for ([_][]const u8{ "source", "symbolic", "hard" }) |name| {
        const output = try std.fs.path.join(allocator, &.{ directory, name });
        defer allocator.free(output);
        try std.testing.expectError(error.OutputAliasesProtectedFile, sampling.rejectOutputAliases(io, allocator, output, &.{source}));
        const actual = try tmp.dir.readFileAlloc(io, "source", allocator, .limited(1024));
        defer allocator.free(actual);
        try std.testing.expectEqualStrings(sentinel, actual);
    }
    const distinct = try std.fs.path.join(allocator, &.{ directory, "other" });
    defer allocator.free(distinct);
    try sampling.rejectOutputAliases(io, allocator, distinct, &.{source});
    const absent = try std.fs.path.join(allocator, &.{ directory, "new.json" });
    defer allocator.free(absent);
    try sampling.rejectOutputAliases(io, allocator, absent, &.{source});
    try sampling.rejectOutputAliases(io, allocator, null, &.{"nonexistent-protected-path"});
    try std.testing.expectError(error.FileNotFound, tmp.dir.statFile(io, "new.json", .{}));
}
