const std = @import("std");
const vort = @import("vort");
const libbrotli = @import("libbrotli_runtime.zig");

const max_raw_attachments = 15;
const fixture = [_]u8{ 0xa1, 0xa8, 0x00, 0xc0, 0x2f, 0x01, 0x10, 0xc4, 0x44, 0x09, 0x00 };
const fixture_dictionary_output = "Kot lomom kolol slona!";
const fixture_without_dictionary_output = "alternate\" type=\"appli";

const streaming_options: libbrotli.Runtime.StreamingOptions = .{
    .quality = 11,
    .lgwin = 22,
    .lgblock = 0,
};

pub fn main(init: std.process.Init) !void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    defer stdout.interface.flush() catch {};

    var fifteen: [max_raw_attachments][]const u8 = @splat("");
    fifteen[0] = fixture_dictionary_output[0..4];
    fifteen[5] = fixture_dictionary_output[4..13];
    fifteen[14] = fixture_dictionary_output[13..];

    try validateVortFixtureDecode(
        init.gpa,
        &.{},
        fixture_without_dictionary_output,
        false,
    );
    try validateVortFixtureDecode(
        init.gpa,
        &.{fixture_dictionary_output},
        fixture_dictionary_output,
        true,
    );
    try validateVortFixtureDecode(
        init.gpa,
        &.{ fixture_dictionary_output[0..13], fixture_dictionary_output[13..] },
        fixture_dictionary_output,
        true,
    );
    try validateVortFixtureDecode(
        init.gpa,
        &fifteen,
        fixture_dictionary_output,
        true,
    );
    try validateDescriptorErrors();

    var runtime = libbrotli.Runtime.open() catch {
        try stdout.interface.writeAll(
            "br_compound_dictionary_diff=ok fixture_cases=4 descriptor_errors=3 " ++
                "reference_shared_dictionary=skipped reason=libbrotli_unavailable " ++
                "vort_encode=skipped reason=public_encoder_shared_dictionary_not_exposed\n",
        );
        return;
    };
    defer runtime.deinit();

    if (!runtime.supportsSharedDictionary()) {
        try expectError(
            error.ReferenceUnavailable,
            runtime.encodeWithRawDictionariesAlloc(
                init.gpa,
                fixture_dictionary_output,
                &.{fixture_dictionary_output},
                streaming_options,
            ),
        );
        try stdout.interface.print(
            "br_compound_dictionary_diff=ok fixture_cases=4 descriptor_errors=3 " ++
                "reference_shared_dictionary=skipped reason=libbrotli_missing_symbols " ++
                "reference_version={x} vort_encode=skipped " ++
                "reason=public_encoder_shared_dictionary_not_exposed\n",
            .{runtime.version()},
        );
        return;
    }

    try validateReferenceEncode(init.gpa, runtime, &.{}, "zero attachment payload", false);
    try validateReferenceEncode(
        init.gpa,
        runtime,
        &.{fixture_dictionary_output},
        fixture_dictionary_output,
        true,
    );
    try validateReferenceEncode(
        init.gpa,
        runtime,
        &.{ fixture_dictionary_output[0..13], fixture_dictionary_output[13..] },
        fixture_dictionary_output,
        true,
    );
    try validateReferenceEncode(
        init.gpa,
        runtime,
        &fifteen,
        fixture_dictionary_output,
        true,
    );
    try validateReferenceAttachmentLimit(init.gpa, runtime);

    const vort_encode_cases = try validateVortEncodeIfExposed(init.gpa, runtime, &fifteen);
    if (vort_encode_cases == 0) {
        try stdout.interface.print(
            "br_compound_dictionary_diff=ok fixture_cases=4 reference_encode_cases=4 " ++
                "descriptor_errors=3 reference_version={x} vort_encode=skipped " ++
                "reason=public_encoder_shared_dictionary_not_exposed\n",
            .{runtime.version()},
        );
    } else {
        try stdout.interface.print(
            "br_compound_dictionary_diff=ok fixture_cases=4 reference_encode_cases=4 " ++
                "vort_encode_cases={d} descriptor_errors=3 reference_version={x}\n",
            .{ vort_encode_cases, runtime.version() },
        );
    }
}

fn validateVortFixtureDecode(
    allocator: std.mem.Allocator,
    raw_dictionaries: []const []const u8,
    expected: []const u8,
    expect_dictionary_copy: bool,
) !void {
    const options = decodeOptions(raw_dictionaries);
    const decoded = try vort.brDecodeStreamAllocExactSizeWithOptions(
        allocator,
        &fixture,
        expected.len,
        options,
    );
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, expected, decoded)) return error.ReferenceDecodeFailed;

    const summary = try vort.brSummarizeStreamWithOptions(&fixture, options);
    if (summary.uses_shared_dictionary != expect_dictionary_copy)
        return error.ReferenceDecodeFailed;
    if (expect_dictionary_copy and
        (summary.shared_dictionary_copy_count == 0 or
            summary.shared_dictionary_bytes != expected.len))
        return error.ReferenceDecodeFailed;
}

fn validateReferenceEncode(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    raw_dictionaries: []const []const u8,
    input: []const u8,
    expect_dictionary_copy: bool,
) !void {
    const encoded = try runtime.encodeWithRawDictionariesAlloc(
        allocator,
        input,
        raw_dictionaries,
        streaming_options,
    );
    defer allocator.free(encoded);

    const decoded = try vort.brDecodeStreamAllocExactSizeWithOptions(
        allocator,
        encoded,
        input.len,
        decodeOptions(raw_dictionaries),
    );
    defer allocator.free(decoded);
    if (!std.mem.eql(u8, input, decoded)) return error.ReferenceDecodeFailed;

    const reference_output = try allocator.alloc(u8, input.len);
    defer allocator.free(reference_output);
    try runtime.decodeWithRawDictionaries(encoded, reference_output, raw_dictionaries);
    if (!std.mem.eql(u8, input, reference_output)) return error.ReferenceDecodeFailed;

    const summary = try vort.brSummarizeStreamWithOptions(
        encoded,
        decodeOptions(raw_dictionaries),
    );
    if (expect_dictionary_copy and !summary.uses_shared_dictionary)
        return error.ReferenceEncodeFailed;
}

fn validateDescriptorErrors() !void {
    const too_many: [max_raw_attachments + 1][]const u8 = @splat("");
    const too_many_dictionary = vort.BrotliSharedDictionary{ .raw_prefixes = &too_many };
    try expectError(error.TooManyRawPrefixes, too_many_dictionary.validate());

    const sentinel: [*]const u8 = @ptrFromInt(1);
    const max_raw_size = @as(usize, 1) << (23 + @sizeOf(usize));
    const too_large_dictionary = vort.BrotliSharedDictionary{
        .raw_prefixes = &.{sentinel[0 .. max_raw_size + 1]},
    };
    try expectError(error.RawDictionaryTooLarge, too_large_dictionary.validate());

    const overflow_dictionary = vort.BrotliSharedDictionary{
        .raw_prefixes = &.{ sentinel[0..std.math.maxInt(usize)], "x" },
    };
    try expectError(error.IntegerOverflow, overflow_dictionary.validate());

    var output: [32]u8 = @splat(0xa5);
    try expectError(
        error.CorruptFrame,
        vort.brDecodeStreamIntoWithOptions(
            &fixture,
            &output,
            .{ .shared_dictionary = too_many_dictionary },
        ),
    );
    if (!std.mem.allEqual(u8, &output, 0xa5)) return error.OutputMutated;

    try expectError(
        error.CorruptFrame,
        vort.brDecodeStreamIntoWithOptions(
            &fixture,
            &output,
            .{ .shared_dictionary = too_large_dictionary },
        ),
    );
    if (!std.mem.allEqual(u8, &output, 0xa5)) return error.OutputMutated;

    try expectError(
        error.IntegerOverflow,
        vort.brDecodeStreamIntoWithOptions(
            &fixture,
            &output,
            .{ .shared_dictionary = overflow_dictionary },
        ),
    );
    if (!std.mem.allEqual(u8, &output, 0xa5)) return error.OutputMutated;
}

fn validateReferenceAttachmentLimit(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
) !void {
    const too_many: [max_raw_attachments + 1][]const u8 = @splat("");
    try expectError(
        error.ReferenceEncodeFailed,
        runtime.encodeWithRawDictionariesAlloc(
            allocator,
            fixture_dictionary_output,
            &too_many,
            streaming_options,
        ),
    );
    var output: [fixture_dictionary_output.len]u8 = undefined;
    try expectError(
        error.ReferenceDecodeFailed,
        runtime.decodeWithRawDictionaries(&fixture, &output, &too_many),
    );
}

fn validateVortEncodeIfExposed(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    fifteen: []const []const u8,
) !usize {
    if (comptime @hasField(vort.BrotliPlannedEncodeOptions, "shared_dictionary")) {
        try validateVortEncode(allocator, runtime, &.{}, "zero attachment payload");
        try validateVortEncode(
            allocator,
            runtime,
            &.{fixture_dictionary_output},
            fixture_dictionary_output,
        );
        try validateVortEncode(
            allocator,
            runtime,
            &.{ fixture_dictionary_output[0..13], fixture_dictionary_output[13..] },
            fixture_dictionary_output,
        );
        try validateVortEncode(
            allocator,
            runtime,
            fifteen,
            fixture_dictionary_output,
        );
        return 4;
    }
    return 0;
}

fn validateVortEncode(
    allocator: std.mem.Allocator,
    runtime: libbrotli.Runtime,
    raw_dictionaries: []const []const u8,
    input: []const u8,
) !void {
    if (comptime @hasField(vort.BrotliPlannedEncodeOptions, "shared_dictionary")) {
        var options: vort.BrotliPlannedEncodeOptions = .{ .quality = 11 };
        @field(options, "shared_dictionary") = .{ .raw_prefixes = raw_dictionaries };
        const encoded = try vort.brEncodePlannedStreamWithOptionsAlloc(
            allocator,
            input,
            options,
        );
        defer allocator.free(encoded);

        const output = try allocator.alloc(u8, input.len);
        defer allocator.free(output);
        try runtime.decodeWithRawDictionaries(encoded, output, raw_dictionaries);
        if (!std.mem.eql(u8, input, output)) return error.ReferenceDecodeFailed;
    }
}

fn decodeOptions(raw_dictionaries: []const []const u8) vort.BrotliDecodeOptions {
    return .{ .shared_dictionary = .{ .raw_prefixes = raw_dictionaries } };
}

fn expectError(expected: anyerror, result: anytype) anyerror!void {
    if (result) |_| {
        return error.ExpectedFailure;
    } else |actual| {
        if (actual != expected) return actual;
    }
}
