//! Paged source preflight contracts on the long-copy fixture.
const std = @import("std");
const h = @import("helpers.zig");
const t = std.testing;
const guard = 0xa5;

const Sparse = struct {
    const base: u64 = (1 << 32) + 37;
    const max_request = 31;

    bytes: []const u8,
    limits: [2]usize = .{ 0, 0 },
    fault: ?usize = null,
    calls: usize = 0,
    passes: usize = 0,
    short_read: bool = false,
    out_of_bounds: bool = false,

    fn begin(self: *Sparse, first: usize, replay: usize) !void {
        try t.expect(!self.out_of_bounds);
        self.* = .{ .bytes = self.bytes, .limits = .{ first, replay } };
    }

    fn readAt(raw: *anyopaque, offset: u64, dest: []u8) error{SourceReadFailed}!usize {
        const self: *Sparse = @ptrCast(@alignCast(raw));
        self.calls += 1;
        if (offset == base) self.passes += 1;
        const relative = offset -| base;
        const end = if (self.passes > 0 and self.passes <= self.limits.len) self.limits[self.passes - 1] else 0;
        if (offset < base or relative >= end or dest.len == 0 or dest.len > max_request or dest.len > end - relative) {
            self.out_of_bounds = true;
            return error.SourceReadFailed;
        }
        const start: usize = @intCast(relative);
        const fault = self.fault orelse self.bytes.len;
        if (start >= fault) return error.SourceReadFailed;
        const len = @min(dest.len, 11, fault - start);
        self.short_read = self.short_read or len < dest.len;
        @memcpy(dest[0..len], self.bytes[start..][0..len]);
        return len;
    }
};

pub fn contracts(comptime B: type, wire: []u8, plain: []const u8, history: []u8) !void {
    const W = B.DirectChunkPreflightWorkspace;
    const workspace = try h.a.create(W);
    defer h.a.destroy(workspace);
    const joined = try std.mem.concat(h.a, u8, &.{ wire, "tail" });
    defer h.a.free(joined);
    var sparse: Sparse = .{ .bytes = joined };
    const tailed: W.SourceRange = .{ .offset = Sparse.base, .source = .{
        .context = &sparse,
        .len = Sparse.base + joined.len,
        .read_at = Sparse.readAt,
        .max_read_size = Sparse.max_request,
    } };
    var exact = tailed;
    exact.length = wire.len;

    const n = plain.len;
    const output = try h.a.alloc(u8, n + 1);
    defer h.a.free(output);
    var page_storage: [263]u8 = undefined;
    // The final compressed byte should be inside a page, not on its edge.
    var page_len: usize = page_storage.len;
    while (wire.len % page_len == 0) page_len -= 1;
    const page = page_storage[0..page_len];
    var profile: B.DecodeMemoryProfile = .{};
    const opts: W.Options = .{ .preflight = .{
        .history = history,
        .max_output_len = n,
        .expected_output_len = n,
        .decode = .{ .max_total_working_memory = 0, .memory_profile = &profile },
    } };
    @memset(output, guard);
    @memset(history, guard);
    const workspace_bytes = std.mem.asBytes(workspace);
    @memset(workspace_bytes, guard);
    for ([_][]u8{ history, output, workspace_bytes[0..page.len], std.mem.asBytes(&profile) }) |alias| {
        try t.expectError(error.InvalidBlockPlan, workspace.decodeSourcePrefixInto(tailed, output, alias, opts));
    }
    try t.expectError(error.InvalidBlockPlan, workspace.decodedSourceSize(exact, history, opts));
    var refused = opts;
    refused.compressed_header_scratch = page;
    try t.expectError(error.InvalidBlockPlan, workspace.decodeSourceInto(exact, output, page, refused));
    try t.expect(std.mem.allEqual(u8, history, guard));
    try t.expect(std.mem.allEqual(u8, workspace_bytes, guard));
    try t.expectEqual(B.DecodeMemoryProfile{}, profile);

    var invalid = exact;
    invalid.length = std.math.maxInt(u64);
    try t.expectError(error.RangeOutOfBounds, workspace.decodeSourceInto(invalid, output, page, opts));
    invalid = tailed;
    invalid.offset = tailed.source.len + 1;
    try t.expectError(error.RangeOutOfBounds, workspace.decodedSourcePrefixSize(invalid, page, opts));
    try t.expectEqual(@as(usize, 0), sparse.calls);

    var truncated = exact;
    truncated.length = wire.len - 1;
    try sparse.begin(wire.len - 1, 0);
    try t.expectError(error.TruncatedFrame, workspace.decodeSourceInto(truncated, output, page, opts));
    try sparse.begin(wire.len, 0);
    sparse.fault = wire.len - 1;
    try t.expectError(error.SourceReadFailed, workspace.decodeSourceInto(exact, output, page, opts));
    try t.expectEqual(@as(usize, 1), sparse.passes);
    try sparse.begin(joined.len, 0);
    try t.expectError(error.TrailingData, workspace.decodeSourceInto(tailed, output, page, opts));
    try t.expect(std.mem.allEqual(u8, output, guard));

    try sparse.begin(wire.len, 0);
    profile.reset();
    try t.expectEqual(@as(B.Counter, n), try workspace.decodedSourceSize(exact, page, opts));
    try t.expect(sparse.short_read);
    try h.zeroProfile(profile, 0);
    try sparse.begin(joined.len, 0);
    profile.reset();
    const size = try workspace.decodedSourcePrefixSize(tailed, page, opts);
    try t.expectEqual(@as(u64, wire.len), size.input_read);
    try t.expectEqual(@as(B.Counter, n), size.decoded_bytes);
    try h.zeroProfile(profile, 0);

    try sparse.begin(joined.len, wire.len); // Only preflight is allowed to see the suffix.
    profile.reset();
    const prefix = try workspace.decodeSourcePrefixInto(tailed, output, page, opts);
    try t.expectEqual(@as(u64, wire.len), prefix.input_read);
    try t.expectEqual(n, prefix.output_written);
    try t.expectEqual(@as(usize, 2), sparse.passes);
    try t.expectEqualSlices(u8, plain, output[0..n]);
    try t.expectEqual(@as(u8, guard), output[n]);
    try h.zeroProfile(profile, 0);

    try sparse.begin(wire.len, wire.len);
    @memset(output, guard);
    profile.reset();
    try t.expectEqual(n, try workspace.decodeSourceInto(exact, output, page, opts));
    try t.expect(!sparse.out_of_bounds);
    try t.expectEqualSlices(u8, plain, output[0..n]);
    try t.expectEqual(@as(u8, guard), output[n]);
    try h.zeroProfile(profile, 0);
}
