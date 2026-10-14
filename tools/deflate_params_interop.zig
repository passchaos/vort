const std = @import("std");
const vort = @import("vort");
const zlib = @import("zlib");

const tiny_output_len = 3;
const segment_len = 2_049;

const schedule = [_]vort.DeflateParams{
    .{ .level = 6, .strategy = .default },
    .{ .level = 1, .strategy = .default },
    .{ .level = 0, .strategy = .default },
    .{ .level = 6, .strategy = .default },
    .{ .level = 6, .strategy = .filtered },
    .{ .level = 6, .strategy = .huffman_only },
    .{ .level = 6, .strategy = .rle },
    .{ .level = 6, .strategy = .fixed },
    .{ .level = 6, .strategy = .default },
    .{ .level = 1, .strategy = .default },
    .{ .level = 3, .strategy = .default },
    .{ .level = 1, .strategy = .default },
    .{ .level = 4, .strategy = .default },
    .{ .level = 9, .strategy = .default },
    .{ .level = 4, .strategy = .default },
};

const Wrapper = enum {
    raw,
    zlib,
    gzip,

    fn name(self: Wrapper) []const u8 {
        return switch (self) {
            .raw => "raw",
            .zlib => "zlib",
            .gzip => "gzip",
        };
    }

    fn windowBits(self: Wrapper) c_int {
        return switch (self) {
            .raw => -15,
            .zlib => 15,
            .gzip => 15 + 16,
        };
    }
};

const Counts = struct {
    vort_to_libz: usize = 0,
    libz_to_vort: usize = 0,
    params_changes: usize = 0,
    same_family_changes: usize = 0,
    vort_observed_changes: usize = 0,
    vort_boundary_requests: usize = 0,
    vort_tiny_steps: usize = 0,
    libz_tiny_calls: usize = 0,
    z_buf_errors: usize = 0,
    compressed_bytes: usize = 0,
};

pub fn main(init: std.process.Init) !void {
    var payload: [schedule.len * segment_len]u8 = undefined;
    fillPayload(&payload);

    var counts: Counts = .{};
    inline for (.{ Wrapper.raw, Wrapper.zlib, Wrapper.gzip }) |wrapper| {
        const vort_wire = try encodeVort(init.gpa, wrapper, &payload, &counts);
        defer init.gpa.free(vort_wire);
        const libz_plain = try inflateLibz(init.gpa, wrapper, vort_wire, &counts);
        defer init.gpa.free(libz_plain);
        try expectEqual(wrapper, "vort-to-libz", &payload, libz_plain);
        counts.vort_to_libz += 1;
        counts.compressed_bytes += vort_wire.len;
        if (wrapper == .raw) {
            const profile = try vort.profileDeflateBlocks(vort_wire);
            if (profile.stored_blocks == 0 or profile.fixed_blocks == 0 or
                profile.dynamic_blocks == 0)
                return error.MissingVortBlockModeCoverage;
        }

        const libz_wire = try deflateLibz(init.gpa, wrapper, &payload, &counts);
        defer init.gpa.free(libz_wire);
        const vort_plain = try decodeVort(init.gpa, wrapper, libz_wire, payload.len);
        defer init.gpa.free(vort_plain);
        try expectEqual(wrapper, "libz-to-vort", &payload, vort_plain);
        counts.libz_to_vort += 1;
        counts.compressed_bytes += libz_wire.len;
    }

    if (counts.z_buf_errors == 0) return error.MissingZBufErrorPressure;

    const version_pointer = zlib.zlibVersion();
    if (version_pointer == null) return error.ZlibFailure;
    const runtime_version = std.mem.span(version_pointer);
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        "deflate_params_interop_reference zlib_version={s}\n" ++
            "deflate_params_interop_ok cases={d} wrappers={d} params_changes={d} " ++
            "same_family_changes={d} vort_to_libz={d} libz_to_vort={d} " ++
            "vort_observed_changes={d} vort_boundary_requests={d} " ++
            "tiny_output_bytes={d} vort_tiny_steps={d} libz_tiny_calls={d} " ++
            "z_buf_errors={d} input_bytes_per_case={d} compressed_bytes={d}\n",
        .{
            runtime_version,
            counts.vort_to_libz + counts.libz_to_vort,
            std.meta.tags(Wrapper).len,
            counts.params_changes,
            counts.same_family_changes,
            counts.vort_to_libz,
            counts.libz_to_vort,
            counts.vort_observed_changes,
            counts.vort_boundary_requests,
            tiny_output_len,
            counts.vort_tiny_steps,
            counts.libz_tiny_calls,
            counts.z_buf_errors,
            payload.len,
            counts.compressed_bytes,
        },
    );
    try stdout.flush();
}

fn fillPayload(payload: *[schedule.len * segment_len]u8) void {
    const phrase = "Vort deflateParams interoperability payload 0123456789\n";
    for (0..schedule.len) |segment_index| {
        const segment = payload[segment_index * segment_len ..][0..segment_len];
        var random: u32 = 0x9e37_79b9 ^ @as(u32, @intCast(segment_index *% 0x45d9_f3b));
        for (segment, 0..) |*byte, offset| {
            byte.* = if (offset < 768)
                phrase[(offset + segment_index * 7) % phrase.len]
            else if (offset < 1_280)
                @as(u8, 'A') + @as(u8, @intCast(segment_index % 7))
            else if (offset < 1_792)
                @as(u8, @intCast((offset / 17 + segment_index * 11) % 251))
            else
                randomByte(&random);
        }
    }
}

fn randomByte(state: *u32) u8 {
    state.* = state.* *% 1_664_525 +% 1_013_904_223;
    return @truncate(state.* >> 16);
}

fn encodeVort(
    allocator: std.mem.Allocator,
    comptime wrapper: Wrapper,
    payload: []const u8,
    counts: *Counts,
) ![]u8 {
    return switch (wrapper) {
        .raw => encodeVortWith(vort.RawDeflateIncrementalBestEncoder, allocator, wrapper, payload, counts),
        .zlib => encodeVortWith(vort.ZlibIncrementalBestEncoder, allocator, wrapper, payload, counts),
        .gzip => encodeVortWith(vort.GzipIncrementalBestEncoder, allocator, wrapper, payload, counts),
    };
}

fn encodeVortWith(
    comptime Encoder: type,
    allocator: std.mem.Allocator,
    wrapper: Wrapper,
    payload: []const u8,
    counts: *Counts,
) ![]u8 {
    var encoder = Encoder.init(allocator);
    defer encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);

    try requestVortParams(&encoder, schedule[0], allocator, &wire, counts);
    for (schedule, 0..) |params, index| {
        if (index != 0) {
            try requestVortParams(&encoder, params, allocator, &wire, counts);
            counts.params_changes += 1;
            if (isRequiredSameFamilyTransition(schedule[index - 1], params))
                counts.same_family_changes += 1;
        }
        const segment = payload[index * segment_len ..][0..segment_len];
        try feedVort(&encoder, segment, allocator, &wire, counts);
    }

    encoder.finish();
    var iterations: usize = 0;
    while (true) {
        iterations += 1;
        if (iterations > payload.len * 8) return error.NoProgress;
        var tiny: [tiny_output_len]u8 = undefined;
        const result = try encoder.step("", &tiny);
        counts.vort_tiny_steps += 1;
        try wire.appendSlice(allocator, tiny[0..result.progress.output_written]);
        if (result.status == .done) break;
        if (result.progress.output_written == 0) {
            std.log.err("vort finish made no progress wrapper={s}", .{wrapper.name()});
            return error.NoProgress;
        }
    }
    return try wire.toOwnedSlice(allocator);
}

fn requestVortParams(
    encoder: anytype,
    params: vort.DeflateParams,
    allocator: std.mem.Allocator,
    wire: *std.ArrayList(u8),
    counts: *Counts,
) !void {
    const before = encoder.snapshot();
    try encoder.requestParams(params);
    const requested = encoder.snapshot();
    const expected_boundary = if (before.active_params) |active|
        active.strategy != params.strategy or paramsFamily(active.level) != paramsFamily(params.level)
    else
        false;
    if (requested.params_boundary_pending != expected_boundary)
        return error.UnexpectedVortParamsBoundary;
    if (expected_boundary) counts.vort_boundary_requests += 1;
    var iterations: usize = 0;
    while (true) {
        iterations += 1;
        if (iterations > segment_len * 8) return error.NoProgress;
        var tiny: [tiny_output_len]u8 = undefined;
        const result = try encoder.step("", &tiny);
        counts.vort_tiny_steps += 1;
        try wire.appendSlice(allocator, tiny[0..result.progress.output_written]);
        const snapshot = encoder.snapshot();
        if (snapshot.requested_params == null and result.status == .need_input) {
            if (snapshot.active_params == null or !std.meta.eql(snapshot.active_params.?, params))
                return error.VortParamsNotApplied;
            if (snapshot.params_change_count != before.params_change_count + 1)
                return error.VortParamsChangeCountMismatch;
            counts.vort_observed_changes += 1;
            return;
        }
        if (result.progress.output_written == 0) return error.NoProgress;
    }
}

fn paramsFamily(level: u4) u2 {
    return if (level == 0) 0 else if (level <= 3) 1 else 2;
}

fn feedVort(
    encoder: anytype,
    input: []const u8,
    allocator: std.mem.Allocator,
    wire: *std.ArrayList(u8),
    counts: *Counts,
) !void {
    var offset: usize = 0;
    while (offset != input.len) {
        var tiny: [tiny_output_len]u8 = undefined;
        const result = try encoder.step(input[offset..], &tiny);
        counts.vort_tiny_steps += 1;
        try wire.appendSlice(allocator, tiny[0..result.progress.output_written]);
        offset += result.progress.input_read;
        if (result.status == .done) return error.EarlyStreamEnd;
        if (result.progress.input_read == 0 and result.progress.output_written == 0)
            return error.NoProgress;
    }
}

fn deflateLibz(
    allocator: std.mem.Allocator,
    wrapper: Wrapper,
    payload: []const u8,
    counts: *Counts,
) ![]u8 {
    var stream: zlib.z_stream = std.mem.zeroes(zlib.z_stream);
    if (zlib.deflateInit2_(
        &stream,
        6,
        zlib.Z_DEFLATED,
        wrapper.windowBits(),
        8,
        zlib.Z_DEFAULT_STRATEGY,
        zlib.ZLIB_VERSION,
        @sizeOf(zlib.z_stream),
    ) != zlib.Z_OK) return error.ZlibFailure;
    defer _ = zlib.deflateEnd(&stream);

    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);
    for (schedule, 0..) |params, index| {
        if (index != 0) {
            try changeLibzParams(&stream, params, index == 1, allocator, &wire, counts);
            counts.params_changes += 1;
            if (isRequiredSameFamilyTransition(schedule[index - 1], params))
                counts.same_family_changes += 1;
        }
        const segment = payload[index * segment_len ..][0..segment_len];
        try feedLibz(&stream, segment, allocator, &wire, counts);
    }

    var iterations: usize = 0;
    while (true) {
        iterations += 1;
        if (iterations > payload.len * 8) return error.NoProgress;
        var tiny: [tiny_output_len]u8 = undefined;
        stream.next_out = &tiny;
        stream.avail_out = tiny.len;
        const result = zlib.deflate(&stream, zlib.Z_FINISH);
        counts.libz_tiny_calls += 1;
        const written = tiny.len - @as(usize, @intCast(stream.avail_out));
        try wire.appendSlice(allocator, tiny[0..written]);
        if (result == zlib.Z_STREAM_END) break;
        if (result != zlib.Z_OK) return error.ZlibFailure;
        if (written == 0) return error.NoProgress;
    }
    return try wire.toOwnedSlice(allocator);
}

fn changeLibzParams(
    stream: *zlib.z_stream,
    params: vort.DeflateParams,
    pressure_z_buf_error: bool,
    allocator: std.mem.Allocator,
    wire: *std.ArrayList(u8),
    counts: *Counts,
) !void {
    const level: c_int = @intCast(params.level);
    const strategy = zlibStrategy(params.strategy);
    if (pressure_z_buf_error) {
        var sentinel: u8 = undefined;
        stream.next_out = &sentinel;
        stream.avail_out = 0;
        const pressured = zlib.deflateParams(stream, level, strategy);
        counts.libz_tiny_calls += 1;
        if (pressured != zlib.Z_BUF_ERROR) return error.MissingZBufErrorPressure;
        counts.z_buf_errors += 1;
    }

    var iterations: usize = 0;
    while (true) {
        iterations += 1;
        if (iterations > segment_len * 8) return error.NoProgress;
        var tiny: [tiny_output_len]u8 = undefined;
        stream.next_out = &tiny;
        stream.avail_out = tiny.len;
        const result = zlib.deflateParams(stream, level, strategy);
        counts.libz_tiny_calls += 1;
        const written = tiny.len - @as(usize, @intCast(stream.avail_out));
        try wire.appendSlice(allocator, tiny[0..written]);
        if (result == zlib.Z_OK) return;
        if (result != zlib.Z_BUF_ERROR) return error.ZlibFailure;
        counts.z_buf_errors += 1;
        if (written == 0) return error.NoProgress;
    }
}

fn feedLibz(
    stream: *zlib.z_stream,
    input: []const u8,
    allocator: std.mem.Allocator,
    wire: *std.ArrayList(u8),
    counts: *Counts,
) !void {
    stream.next_in = @constCast(input.ptr);
    stream.avail_in = @intCast(input.len);
    while (stream.avail_in != 0) {
        const before_input = stream.avail_in;
        var tiny: [tiny_output_len]u8 = undefined;
        stream.next_out = &tiny;
        stream.avail_out = tiny.len;
        if (zlib.deflate(stream, zlib.Z_NO_FLUSH) != zlib.Z_OK)
            return error.ZlibFailure;
        counts.libz_tiny_calls += 1;
        const written = tiny.len - @as(usize, @intCast(stream.avail_out));
        try wire.appendSlice(allocator, tiny[0..written]);
        if (before_input == stream.avail_in and written == 0) return error.NoProgress;
    }
}

fn inflateLibz(
    allocator: std.mem.Allocator,
    wrapper: Wrapper,
    wire: []const u8,
    counts: *Counts,
) ![]u8 {
    var stream: zlib.z_stream = std.mem.zeroes(zlib.z_stream);
    if (zlib.inflateInit2_(
        &stream,
        wrapper.windowBits(),
        zlib.ZLIB_VERSION,
        @sizeOf(zlib.z_stream),
    ) != zlib.Z_OK) return error.ZlibFailure;
    defer _ = zlib.inflateEnd(&stream);

    stream.next_in = @constCast(wire.ptr);
    stream.avail_in = @intCast(wire.len);
    var plain: std.ArrayList(u8) = .empty;
    errdefer plain.deinit(allocator);
    var iterations: usize = 0;
    while (true) {
        iterations += 1;
        if (iterations > schedule.len * segment_len * 8) return error.NoProgress;
        const before_input = stream.avail_in;
        var tiny: [tiny_output_len]u8 = undefined;
        stream.next_out = &tiny;
        stream.avail_out = tiny.len;
        const result = zlib.inflate(&stream, zlib.Z_NO_FLUSH);
        counts.libz_tiny_calls += 1;
        const written = tiny.len - @as(usize, @intCast(stream.avail_out));
        try plain.appendSlice(allocator, tiny[0..written]);
        if (result == zlib.Z_STREAM_END) break;
        if (result != zlib.Z_OK and result != zlib.Z_BUF_ERROR)
            return error.ZlibFailure;
        if (before_input == stream.avail_in and written == 0) return error.NoProgress;
    }
    if (stream.avail_in != 0) return error.TrailingCompressedData;
    return try plain.toOwnedSlice(allocator);
}

fn decodeVort(
    allocator: std.mem.Allocator,
    wrapper: Wrapper,
    wire: []const u8,
    expected_len: usize,
) ![]u8 {
    return switch (wrapper) {
        .raw => vort.decodeRawDeflateAllocExactSize(allocator, wire, expected_len),
        .zlib => vort.decodeZlibAllocExactSize(allocator, wire, expected_len),
        .gzip => vort.decodeGzipAllocExactSize(allocator, wire, expected_len),
    };
}

fn zlibStrategy(strategy: vort.DeflateParams.Strategy) c_int {
    return switch (strategy) {
        .default => zlib.Z_DEFAULT_STRATEGY,
        .filtered => zlib.Z_FILTERED,
        .huffman_only => zlib.Z_HUFFMAN_ONLY,
        .rle => zlib.Z_RLE,
        .fixed => zlib.Z_FIXED,
    };
}

fn isRequiredSameFamilyTransition(before: vort.DeflateParams, after: vort.DeflateParams) bool {
    if (before.strategy != .default or after.strategy != .default) return false;
    return (before.level == 1 and after.level == 3) or
        (before.level == 3 and after.level == 1) or
        (before.level == 4 and after.level == 9) or
        (before.level == 9 and after.level == 4);
}

fn expectEqual(wrapper: Wrapper, direction: []const u8, expected: []const u8, actual: []const u8) !void {
    if (!std.mem.eql(u8, expected, actual)) {
        std.log.err(
            "deflate params mismatch wrapper={s} direction={s} expected={d} actual={d}",
            .{ wrapper.name(), direction, expected.len, actual.len },
        );
        return error.DecodeMismatch;
    }
}
