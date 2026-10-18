const std = @import("std");
const br = @import("br_internal");

const Case = struct {
    name: []const u8,
    payload: []const u8,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var iterations: usize = 3;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--iterations")) {
            iterations = try std.fmt.parseInt(
                usize,
                args.next() orelse return error.MissingLimit,
                10,
            );
            if (iterations == 0) return error.InvalidBlockPlan;
        } else return error.UnknownArgument;
    }

    const cases = [_]Case{
        .{ .name = "omit_first", .payload = "quot;" },
        .{ .name = "literal_prefix", .payload = "zzzzquot;" },
        .{
            .name = "dictionary_phrase",
            .payload = " information follows the information",
        },
    };
    const index_entries = try br.plannedCompleteStaticDictionaryIndexEntries();
    const index_bytes = try br.plannedCompleteStaticDictionaryIndexBytes();
    var stdout_buffer: [2048]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(
        "case,input_bytes,index_entries,index_bytes,encoded_bytes,iterations,indexed_ns,reference_ns,speedup,checksum\n",
    );
    for (cases) |case| {
        const indexed_wire = try br.encodePlannedStreamStaticDictionaryAlloc(
            init.gpa,
            case.payload,
        );
        defer init.gpa.free(indexed_wire);
        const reference_wire = try br.encodePlannedStreamStaticDictionaryReferenceAlloc(
            init.gpa,
            case.payload,
        );
        defer init.gpa.free(reference_wire);
        if (!std.mem.eql(u8, indexed_wire, reference_wire)) return error.SizeMismatch;
        const decoded = try br.decodeStreamAllocExactSize(
            init.gpa,
            indexed_wire,
            case.payload.len,
        );
        defer init.gpa.free(decoded);
        if (!std.mem.eql(u8, decoded, case.payload)) return error.SizeMismatch;

        var checksum: usize = 0;
        const indexed_start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            const encoded = try br.encodePlannedStreamStaticDictionaryAlloc(
                init.gpa,
                case.payload,
            );
            checksum +%= encoded.len;
            init.gpa.free(encoded);
        }
        const indexed_ns = indexed_start.durationTo(
            std.Io.Clock.awake.now(init.io),
        ).toNanoseconds();

        const reference_start = std.Io.Clock.awake.now(init.io);
        for (0..iterations) |_| {
            const encoded = try br.encodePlannedStreamStaticDictionaryReferenceAlloc(
                init.gpa,
                case.payload,
            );
            checksum +%= encoded.len;
            init.gpa.free(encoded);
        }
        const reference_ns = reference_start.durationTo(
            std.Io.Clock.awake.now(init.io),
        ).toNanoseconds();
        try stdout.print(
            "{s},{d},{d},{d},{d},{d},{d},{d},{d:.3},{d}\n",
            .{
                case.name,
                case.payload.len,
                index_entries,
                index_bytes,
                indexed_wire.len,
                iterations,
                indexed_ns,
                reference_ns,
                @as(f64, @floatFromInt(reference_ns)) /
                    @as(f64, @floatFromInt(indexed_ns)),
                checksum,
            },
        );
    }
    try stdout.flush();
}
