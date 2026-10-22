const std = @import("std");
const ztf = @import("ztf.zig");

const all_types =
    "ZTxt\n" ++
    "Target\n" ++
    "<1,1> <01,01> <001,001> <+0,+0> <+00,+00> <+000,+000>\n" ++
    "{1,1} {01,01} {001,001} {+0,+0} {+00,+00} {+000,+000}\n" ++
    "[1,1] [01,01] [001,001] [+0,+0] [+00,+00] [+000,+000]\n" ++
    "(1,1) (01,01) (001,001) (+0,+0) (+00,+00) (+000,+000)\n" ++
    "txTZ\n";

test "Android OTA Zucchini ZTF covers all AOSP reference groups" {
    var executable = try ztf.Executable.initAlloc(
        std.testing.allocator,
        all_types,
        .{},
    );
    defer executable.deinit();
    var rewritten: [all_types.len]u8 = all_types.*;
    for (std.enums.values(ztf.ReferenceType), 0..) |reference_type, index| {
        const references = executable.references[@intFromEnum(reference_type)];
        try std.testing.expectEqual(@as(usize, 1), references.len);
        try std.testing.expectEqual(@as(u8, @intCast(index / 6)), reference_type.pool());
        try executable.writeReference(&rewritten, reference_type, references[0]);
    }
    try std.testing.expectEqualSlices(u8, all_types, &rewritten);
}

test "Android OTA Zucchini ZTF matches pinned AOSP fixtures" {
    inline for (.{
        @embedFile("testdata/aosp-old.ztf"),
        @embedFile("testdata/aosp-new.ztf"),
    }) |fixture| {
        var executable = try ztf.Executable.initAlloc(
            std.testing.allocator,
            fixture,
            .{},
        );
        defer executable.deinit();
        var total: usize = 0;
        for (executable.references) |references| total += references.len;
        try std.testing.expect(total != 0);
        const rewritten = try std.testing.allocator.dupe(u8, fixture);
        defer std.testing.allocator.free(rewritten);
        for (std.enums.values(ztf.ReferenceType)) |reference_type|
            for (executable.references[@intFromEnum(reference_type)]) |reference|
                try executable.writeReference(rewritten, reference_type, reference);
        try std.testing.expectEqualSlices(u8, fixture, rewritten);
    }
}
