const std = @import("std");
const Runtime = @import("libzstd_runtime.zig").Runtime;
const dict_tests = @import("reference_dictionary_tests.zig");

pub const Report = struct { parameter_cases: usize, legacy_cases: usize, dictionary_cases: usize };

pub fn contracts(comptime Codec: type, allocator: std.mem.Allocator, runtime: Runtime) !Report {
    const defaults = try runtime.inspectAdvancedParameters(.{});
    try std.testing.expectEqual(@as(c_int, 3), defaults.level);
    inline for (.{ "window_log", "hash_log", "chain_log", "search_log", "min_match", "target_length", "strategy", "workers", "long_distance_matching", "checksum" }) |field|
        try std.testing.expectEqual(@as(c_int, 0), @field(defaults, field));
    try std.testing.expectEqual(@as(c_int, 1), defaults.content_size);
    try std.testing.expectEqual(@as(c_int, 1), defaults.dict_id);
    const context = runtime.create_cctx() orelse return error.ReferenceUnavailable;
    defer _ = runtime.free_cctx(context);
    try set(runtime, context, 202, 0); // ZSTD_c_dictIDFlag
    const suppressed_id = try runtime.readRequestedParameters(context);
    try std.testing.expectEqual(@as(c_int, 0), suppressed_id.dict_id);

    var parameter_cases: usize = 0;
    for ([_]c_int{ 7, 9 }) |strategy| {
        for ([_]c_int{ 15, 17 }) |window| {
            for ([_]bool{ false, true }) |flags| {
                const options: Runtime.AdvancedOptions = .{
                    .level = 3,
                    .strategy = strategy,
                    .window_log = window,
                    .hash_log = 12,
                    .chain_log = 13,
                    .search_log = 6,
                    .min_match = 3,
                    .target_length = 64,
                    .workers = 0,
                    .checksum = flags,
                    .content_size = flags,
                };
                const requested = try runtime.inspectAdvancedParameters(options);
                inline for (.{ "level", "strategy", "window_log", "hash_log", "chain_log", "search_log", "min_match", "target_length", "workers" }) |field| {
                    const value = @field(options, field);
                    try std.testing.expectEqual(if (@TypeOf(value) == c_int) value else value.?, @field(requested, field));
                }
                try std.testing.expectEqual(@as(c_int, @intFromBool(flags)), requested.checksum);
                try std.testing.expectEqual(@as(c_int, @intFromBool(flags)), requested.content_size);
                const frame = try runtime.encodeAdvancedAlloc(allocator, dict_tests.payload, options);
                defer allocator.free(frame);
                const header = try Codec.inspectNativeFrameHeader(frame);
                try std.testing.expectEqual(flags, header.has_checksum);
                try std.testing.expectEqual(if (flags) @as(?u64, dict_tests.payload.len) else null, header.content_size);
                const decoded = try Codec.decodeFrameAlloc(allocator, frame);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, dict_tests.payload, decoded);
                parameter_cases += 1;
            }
        }
    }
    const ldm = try runtime.inspectAdvancedParameters(.{ .long_distance_matching = true, .workers = 0 });
    try std.testing.expectEqual(@as(c_int, 1), ldm.long_distance_matching);
    try std.testing.expectError(error.ReferenceEncodeFailed, runtime.inspectAdvancedParameters(.{ .search_log = -1 }));
    try std.testing.expectError(error.ReferenceParametersUnavailable, runtime.readRequestedParameters(null));
    const stream = try runtime.encodeStreamingAlloc(allocator, dict_tests.payload, .{
        .strategy = 7,
        .window_log = 15,
        .search_log = 6,
        .min_match = 3,
        .target_length = 64,
        .workers = 0,
        .checksum = true,
    }, 127, false);
    defer allocator.free(stream);
    const stream_plain = try Codec.decodeFrameAlloc(allocator, stream);
    defer allocator.free(stream_plain);
    try std.testing.expectEqualSlices(u8, dict_tests.payload, stream_plain);

    const legacy = [_]Runtime.AdvancedOptions{
        .{},                                                                       .{ .level = 1, .content_size = false },                 .{ .level = 9, .checksum = true },
        .{ .strategy = 7, .window_log = 15, .min_match = 3, .target_length = 64 }, .{ .strategy = 9, .window_log = 17, .checksum = true },
    };
    for (legacy) |options| {
        const old = try frozenAdvanced(allocator, runtime, dict_tests.payload, options);
        defer allocator.free(old);
        const current = try runtime.encodeAdvancedAlloc(allocator, dict_tests.payload, options);
        defer allocator.free(current);
        try std.testing.expectEqualSlices(u8, old, current);
        var without_optional_symbols = runtime;
        without_optional_symbols.cctx_get_parameter = null;
        without_optional_symbols.cctx_load_dictionary = null;
        const optional = try without_optional_symbols.encodeAdvancedAlloc(allocator, dict_tests.payload, options);
        defer allocator.free(optional);
        try std.testing.expectEqualSlices(u8, old, optional);
        try std.testing.expectError(error.ReferenceParametersUnavailable, without_optional_symbols.inspectAdvancedParameters(options));
    }
    return .{
        .parameter_cases = parameter_cases + 6,
        .legacy_cases = legacy.len,
        .dictionary_cases = try dict_tests.contracts(Codec, allocator, runtime),
    };
}

// The old advanced CCtx setup, independent of configureAdvanced and new
// options. Compare exact wires for its existing options and defaults.
fn frozenAdvanced(allocator: std.mem.Allocator, runtime: Runtime, input: []const u8, options: Runtime.AdvancedOptions) ![]u8 {
    const context = runtime.create_cctx() orelse return error.ReferenceUnavailable;
    defer _ = runtime.free_cctx(context);
    try set(runtime, context, 100, options.level);
    try set(runtime, context, 200, @intFromBool(options.content_size));
    try set(runtime, context, 201, @intFromBool(options.checksum));
    if (options.window_log) |value| try set(runtime, context, 101, value);
    if (options.min_match) |value| try set(runtime, context, 105, value);
    if (options.target_length) |value| try set(runtime, context, 106, value);
    if (options.strategy) |value| try set(runtime, context, 107, value);
    if (options.long_distance_matching) try set(runtime, context, 160, 1);
    const output = try allocator.alloc(u8, runtime.compress_bound(input.len));
    errdefer allocator.free(output);
    const len = runtime.compress2(context, output.ptr, output.len, input.ptr, input.len);
    if (runtime.is_error(len) != 0) return error.ReferenceEncodeFailed;
    return allocator.realloc(output, len);
}

fn set(runtime: Runtime, context: ?*anyopaque, parameter: c_int, value: c_int) !void {
    if (runtime.is_error(runtime.cctx_set_parameter(context, parameter, value)) != 0) return error.ReferenceEncodeFailed;
}
