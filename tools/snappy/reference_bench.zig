const std = @import("std");
const vort = @import("vort");

const SnappyStatus = enum(c_int) {
    ok = 0,
    invalid_input = 1,
    buffer_too_small = 2,
    _,
};

const UncompressFn = *const fn (
    [*]const u8,
    usize,
    [*]u8,
    *usize,
) callconv(.c) SnappyStatus;

const Case = struct {
    name: []const u8,
    payload: []const u8,
};

const Row = struct {
    case_name: []const u8,
    input_bytes: usize,
    encoded_bytes: usize,
    iterations: usize,
    vort_ns: u64,
    reference_ns: u64,
    vort_mib_s: f64,
    reference_mib_s: f64,
    vort_over_reference: f64,
    checksum: u64,
    literal_count: usize,
    literal_bytes: usize,
    copy_count: usize,
    copy_bytes: usize,
    copy1_count: usize,
    copy2_count: usize,
    copy4_count: usize,
};

const Runtime = struct {
    library: std.DynLib,
    uncompress: UncompressFn,

    fn open() !Runtime {
        const names = [_][:0]const u8{
            "libsnappy.so.1",
            "/lib/x86_64-linux-gnu/libsnappy.so.1",
            "/usr/lib/x86_64-linux-gnu/libsnappy.so.1",
            "libsnappy.dylib",
        };
        for (names) |name| {
            var library = std.DynLib.openZ(name.ptr) catch continue;
            const uncompress = library.lookup(
                UncompressFn,
                "snappy_uncompress",
            ) orelse {
                library.close();
                continue;
            };
            return .{
                .library = library,
                .uncompress = uncompress,
            };
        }
        return error.ReferenceUnavailable;
    }

    fn deinit(self: *Runtime) void {
        self.library.close();
        self.* = undefined;
    }
};

const Options = struct {
    iterations: usize = 1000,
    csv_path: ?[]const u8 = null,
    only_case: ?[]const u8 = null,
    only_codec: ?[]const u8 = null,
};

const incompressible_payload = incompressiblePayload();
const rle_payload = [_]u8{0} ** (64 * 1024);

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(
        init.minimal.args,
        init.gpa,
    );
    defer args.deinit();
    _ = args.next();
    const options = try parseOptions(&args);
    var runtime = try Runtime.open();
    defer runtime.deinit();

    const cases = [_]Case{
        .{ .name = "tiny", .payload = "hello snappy" },
        .{
            .name = "text",
            .payload = "Snappy benchmark text payload. " ** 1024,
        },
        .{
            .name = "structured",
            .payload = "{\"service\":\"vort\",\"codec\":\"snappy\",\"value\":12345}\n" ** 768,
        },
        .{
            .name = "repetitive",
            .payload = ("abcdefghijklmnopqrstuvwxyz012345" ** 4) ** 256,
        },
        .{ .name = "incompressible", .payload = &incompressible_payload },
        .{ .name = "rle64k", .payload = &rle_payload },
    };

    var rows: std.ArrayList(Row) = .empty;
    defer rows.deinit(init.gpa);
    for (&cases) |case| {
        if (options.only_case) |wanted| {
            if (!std.mem.eql(u8, wanted, case.name)) continue;
        }
        try rows.append(
            init.gpa,
            try measureCase(
                init,
                &runtime,
                case,
                options.iterations,
                options.only_codec,
            ),
        );
    }

    var csv = std.Io.Writer.Allocating.init(init.gpa);
    defer csv.deinit();
    try writeCsv(&csv.writer, rows.items);
    if (options.csv_path) |path| {
        try std.Io.Dir.cwd().writeFile(
            init.io,
            .{ .sub_path = path, .data = csv.written() },
        );
    } else {
        var buffer: [1024]u8 = undefined;
        var stdout = std.Io.File.stdout().writerStreaming(
            init.io,
            &buffer,
        );
        try stdout.interface.writeAll(csv.written());
        try stdout.interface.flush();
    }
}

fn parseOptions(args: *std.process.Args.Iterator) !Options {
    var options: Options = .{};
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            options.iterations = try std.fmt.parseInt(
                usize,
                args.next() orelse return error.MissingLimit,
                10,
            );
        } else if (std.mem.eql(u8, arg, "--csv")) {
            options.csv_path =
                args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--case")) {
            options.only_case =
                args.next() orelse return error.MissingCorpusPath;
        } else if (std.mem.eql(u8, arg, "--codec")) {
            options.only_codec =
                args.next() orelse return error.MissingCorpusPath;
        } else {
            return error.UnknownArgument;
        }
    }
    if (options.iterations == 0) return error.InvalidBlockPlan;
    if (options.only_codec) |codec| {
        if (!std.mem.eql(u8, codec, "vort") and
            !std.mem.eql(u8, codec, "reference"))
        {
            return error.UnknownArgument;
        }
    }
    return options;
}

fn measureCase(
    init: std.process.Init,
    runtime: *const Runtime,
    case: Case,
    iterations: usize,
    only_codec: ?[]const u8,
) !Row {
    const encoded = try vort.snappyEncodeBlockAlloc(
        init.gpa,
        case.payload,
    );
    defer init.gpa.free(encoded);
    const summary = try vort.snappySummarizeBlock(encoded);
    const vort_out = try init.gpa.alloc(u8, case.payload.len);
    defer init.gpa.free(vort_out);
    const reference_out = try init.gpa.alloc(u8, case.payload.len);
    defer init.gpa.free(reference_out);

    _ = try vort.snappyDecodeBlockInto(encoded, vort_out);
    try referenceDecode(runtime, encoded, reference_out);
    if (!std.mem.eql(u8, case.payload, vort_out) or
        !std.mem.eql(u8, case.payload, reference_out))
    {
        return error.SizeMismatch;
    }

    const vort_sample = if (only_codec == null or
        std.mem.eql(u8, only_codec.?, "vort"))
        try measureRepeated(
            init.io,
            .vort,
            runtime,
            encoded,
            vort_out,
            iterations,
        )
    else
        Sample.placeholder;
    const reference_sample = if (only_codec == null or
        std.mem.eql(u8, only_codec.?, "reference"))
        try measureRepeated(
            init.io,
            .reference,
            runtime,
            encoded,
            reference_out,
            iterations,
        )
    else
        Sample.placeholder;
    const vort_ns = vort_sample.elapsed_ns;
    const reference_ns = reference_sample.elapsed_ns;

    const vort_mib_s = mibPerSecond(
        case.payload.len * iterations,
        vort_ns,
    );
    const reference_mib_s = mibPerSecond(
        case.payload.len * iterations,
        reference_ns,
    );
    return .{
        .case_name = case.name,
        .input_bytes = case.payload.len,
        .encoded_bytes = encoded.len,
        .iterations = iterations,
        .vort_ns = vort_ns,
        .reference_ns = reference_ns,
        .vort_mib_s = vort_mib_s,
        .reference_mib_s = reference_mib_s,
        .vort_over_reference = vort_mib_s / reference_mib_s,
        .checksum = vort_sample.mix +% reference_sample.mix,
        .literal_count = summary.literal_count,
        .literal_bytes = summary.literal_bytes,
        .copy_count = summary.copy_count,
        .copy_bytes = summary.copy_bytes,
        .copy1_count = summary.copy1_count,
        .copy2_count = summary.copy2_count,
        .copy4_count = summary.copy4_count,
    };
}

const Codec = enum { vort, reference };

const Sample = struct {
    elapsed_ns: u64,
    mix: u64,

    const placeholder = Sample{ .elapsed_ns = 1, .mix = 0 };
};

fn measureRepeated(
    io: std.Io,
    codec: Codec,
    runtime: *const Runtime,
    encoded: []const u8,
    output: []u8,
    iterations: usize,
) !Sample {
    var best = Sample{
        .elapsed_ns = std.math.maxInt(u64),
        .mix = 0,
    };
    for (0..5) |_| {
        var mix: u64 = 0;
        const start = std.Io.Clock.awake.now(io);
        for (0..iterations) |_| {
            switch (codec) {
                .vort => {
                    const written =
                        try vort.snappyDecodeBlockInto(encoded, output);
                    mix +%= written;
                },
                .reference => {
                    try referenceDecode(runtime, encoded, output);
                    mix +%= output.len;
                },
            }
            if (output.len != 0) mix +%= output[0];
        }
        const elapsed_ns = elapsedNs(io, start);
        if (elapsed_ns < best.elapsed_ns) {
            best = .{ .elapsed_ns = elapsed_ns, .mix = mix };
        }
    }
    return best;
}

fn referenceDecode(
    runtime: *const Runtime,
    encoded: []const u8,
    output: []u8,
) !void {
    var output_len = output.len;
    const status = runtime.uncompress(
        encoded.ptr,
        encoded.len,
        output.ptr,
        &output_len,
    );
    if (status != .ok) return error.ReferenceDecodeFailed;
    if (output_len != output.len) return error.SizeMismatch;
}

fn elapsedNs(io: std.Io, start: std.Io.Timestamp) u64 {
    const ns = start.durationTo(std.Io.Clock.awake.now(io)).nanoseconds;
    return if (ns <= 0) 0 else @intCast(ns);
}

fn mibPerSecond(bytes: usize, ns: u64) f64 {
    if (ns == 0) return 0;
    const mib = @as(f64, @floatFromInt(bytes)) / (1024 * 1024);
    return mib / (@as(f64, @floatFromInt(ns)) / 1_000_000_000);
}

fn writeCsv(writer: *std.Io.Writer, rows: []const Row) !void {
    try writer.writeAll(
        "case,input_bytes,encoded_bytes,iterations,vort_ns,reference_ns,vort_mib_s,reference_mib_s,vort_over_reference,checksum,literal_count,literal_bytes,copy_count,copy_bytes,copy1_count,copy2_count,copy4_count\n",
    );
    for (rows) |row| {
        try writer.print(
            "{s},{d},{d},{d},{d},{d},{d:.2},{d:.2},{d:.4},{d},{d},{d},{d},{d},{d},{d},{d}\n",
            .{
                row.case_name,
                row.input_bytes,
                row.encoded_bytes,
                row.iterations,
                row.vort_ns,
                row.reference_ns,
                row.vort_mib_s,
                row.reference_mib_s,
                row.vort_over_reference,
                row.checksum,
                row.literal_count,
                row.literal_bytes,
                row.copy_count,
                row.copy_bytes,
                row.copy1_count,
                row.copy2_count,
                row.copy4_count,
            },
        );
    }
}

fn incompressiblePayload() [1024]u8 {
    @setEvalBranchQuota(4096);
    var out: [1024]u8 = undefined;
    var state: u32 = 0x1234_5678;
    for (&out) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 16);
    }
    return out;
}
