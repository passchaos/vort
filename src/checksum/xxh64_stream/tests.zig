const std = @import("std");
const stream = @import("../xxh64_stream.zig");
const vectors = @import("vectors.zig");

test "XXH64 stream canonical vectors cover seeds and portable public aliases" {
    for (vectors.vectors) |vector| {
        try std.testing.expectEqual(vector.expected, stream.WideXxHash64.hash(vector.seed, vector.bytes));
        try std.testing.expectEqual(vector.expected, stream.XxHash64.hash(vector.seed, vector.bytes));
        var state = stream.WideXxHash64.init(vector.seed);
        for (vector.bytes) |*byte| state.update(@as(*const [1]u8, @ptrCast(byte)));
        try std.testing.expectEqual(vector.expected, state.final());
        state.update("");
        try std.testing.expectEqual(vector.expected, state.final());
    }
}

fn checkChunks(input: []const u8, seed: u64, chunk_len: usize) !void {
    const expected = std.hash.XxHash64.hash(seed, input);
    var wide = stream.WideXxHash64.init(seed);
    var public = stream.XxHash64.init(seed);
    var offset: usize = 0;
    while (offset < input.len) {
        const end = offset + @min(chunk_len, input.len - offset);
        wide.update(input[offset..end]);
        public.update(input[offset..end]);
        offset = end;
    }
    const total_before = wide.total_len;
    const lanes_before = wide.lanes;
    const tail_len_before = wide.tail_len;
    try std.testing.expectEqual(expected, wide.final());
    try std.testing.expectEqual(expected, wide.final());
    try std.testing.expectEqual(expected, public.final());
    try std.testing.expectEqual(total_before, wide.total_len);
    try std.testing.expectEqual(lanes_before, wide.lanes);
    try std.testing.expectEqual(tail_len_before, wide.tail_len);
    try std.testing.expectEqual(@as(u64, input.len), wide.total_len);
    try std.testing.expect(wide.tail_len < 32);
}

test "XXH64 stream tails unaligned stripes and arbitrary chunks match native standard reference" {
    var storage: [4104]u8 = undefined;
    var random: u64 = 0x719afb23405;
    for (&storage) |*byte| {
        random = random *% 6364136223846793005 +% 1442695040888963407;
        byte.* = @truncate(random >> 32);
    }
    for ([_]u64{ 0, 1, 0x0123456789abcdef, std.math.maxInt(u64) }) |seed| {
        for (0..130) |length| {
            const input = storage[0..length];
            try std.testing.expectEqual(std.hash.XxHash64.hash(seed, input), stream.WideXxHash64.hash(seed, input));
            for ([_]usize{ 1, 2, 7, 31, 32, 33, 64 }) |chunk|
                try checkChunks(input, seed, chunk);
        }
        for (0..8) |alignment| {
            for ([_]usize{ 31, 32, 33, 63, 64, 65, 257, 1023, 4097 }) |length|
                try checkChunks(storage[alignment..][0..length], seed, 37);
        }
    }
    var original = stream.WideXxHash64.init(93);
    original.update(storage[0..33]);
    var moved = original;
    original = undefined;
    moved.update(storage[33..]);
    try std.testing.expectEqual(std.hash.XxHash64.hash(93, &storage), moved.final());
}

fn setPublicStripeCount(state: *stream.XxHash64, bytes: u64) void {
    if (comptime @bitSizeOf(usize) == 64) {
        state.byte_count = @intCast(bytes);
    } else {
        state.total_len = bytes;
    }
}

test "XXH64 stream legitimate fixed point stripes preserve all length bits across four GiB" {
    const tail = "abcdefghijklmnopqrstuvwxyz0123456";
    const prefix_bytes: u64 = (@as(u64, 1) << 32) - 32;
    for (vectors.large) |vector| {
        var wide = stream.WideXxHash64.init(vector.seed);
        const initial_lanes = wide.lanes;
        wide.update(&vector.stripe);
        // Independent reference constructs these words by inverting XXH64's
        // round; actual C reference updates also prove all four fixed points.
        // Repeating this stripe yields a real legal prefix of any multiple of
        // 32 bytes while keeping the lanes unchanged. No 4 GiB loop is needed.
        try std.testing.expectEqual(initial_lanes, wide.lanes);
        try std.testing.expect(wide.large_input and wide.tail_len == 0);
        wide.total_len = prefix_bytes;
        wide.update(tail[0..31]);
        try std.testing.expectEqual(@as(u64, 0xffffffff), wide.total_len);
        try std.testing.expectEqual(vector.before, wide.final());
        wide.update(tail[31..]);
        try std.testing.expectEqual(@as(u64, 0x100000001), wide.total_len);
        try std.testing.expectEqual(@as(u8, 1), wide.tail_len);
        try std.testing.expectEqual(vector.after, wide.final());
        var exact = stream.WideXxHash64.init(vector.seed);
        exact.update(&vector.stripe);
        exact.total_len = prefix_bytes;
        exact.update(&vector.stripe);
        try std.testing.expectEqual(@as(u64, 0x100000000), exact.total_len);
        try std.testing.expectEqual(vector.exact, exact.final());

        var public = stream.XxHash64.init(vector.seed);
        public.update(&vector.stripe);
        setPublicStripeCount(&public, prefix_bytes);
        public.update(tail[0..31]);
        try std.testing.expectEqual(vector.before, public.final());
        public.update(tail[31..]);
        try std.testing.expectEqual(vector.after, public.final());
        // Truncating the length to the 32-bit low word produces a distinct
        // canonical result, even when the lane state and tail are unchanged.
        var truncated = wide;
        truncated.total_len = 1;
        try std.testing.expect(truncated.final() != vector.after);
    }
}

test "XXH64 stream native alias retains standard state and narrow targets use explicit u64" {
    if (comptime @bitSizeOf(usize) == 64) {
        try std.testing.expect(stream.XxHash64 == std.hash.XxHash64);
        try std.testing.expectEqual(@sizeOf(std.hash.XxHash64), @sizeOf(stream.XxHash64));
    } else {
        try std.testing.expect(stream.XxHash64 == stream.WideXxHash64);
    }
    try std.testing.expect(@FieldType(stream.WideXxHash64, "total_len") == u64);
    inline for (@typeInfo(stream.WideXxHash64).@"struct".fields) |field|
        try std.testing.expect(@typeInfo(field.type) != .pointer);
}
