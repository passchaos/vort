//! Same public-API harness for isolated historical/current Brotli sources.
const std = @import("std");
const br = @import("vort_br");
const provenance = @import("provenance");

const Sample = struct {
    index: usize,
    owned_encode_free_ns: u64,
    wire_bytes: usize,
    mix: usize,
};

fn elapsed(io: std.Io, start: std.Io.Timestamp) u64 {
    return @intCast(start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds());
}

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    var input_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var wire_path: ?[]const u8 = null;
    var revision: ?[]const u8 = null;
    var iterations: usize = 1;
    var window_bits: ?u5 = 16;
    while (args.next()) |arg| {
        const value = args.next() orelse return error.MissingArgument;
        if (std.mem.eql(u8, arg, "--input")) {
            input_path = value;
        } else if (std.mem.eql(u8, arg, "--output")) {
            output_path = value;
        } else if (std.mem.eql(u8, arg, "--wire-output")) {
            wire_path = value;
        } else if (std.mem.eql(u8, arg, "--source-revision")) {
            revision = value;
        } else if (std.mem.eql(u8, arg, "--iterations")) {
            iterations = try std.fmt.parseInt(usize, value, 10);
        } else if (std.mem.eql(u8, arg, "--window")) {
            if (std.mem.eql(u8, value, "default")) {
                window_bits = null;
            } else if (std.mem.eql(u8, value, "16")) {
                window_bits = 16;
            } else return error.InvalidWindow;
        } else return error.UnknownArgument;
    }
    if (iterations > 3) return error.InvalidIterations;
    const source = revision orelse return error.MissingRevision;
    const path = input_path orelse return error.MissingInput;
    const output = output_path orelse return error.MissingOutput;
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const size = (try file.stat(init.io)).size;
    if (size != 65536) return error.InvalidInputSize;
    const input = try init.gpa.alloc(u8, @intCast(size));
    defer init.gpa.free(input);
    var read_buffer: [4096]u8 = undefined;
    var reader = file.reader(init.io, &read_buffer);
    if (try reader.interface.readSliceShort(input) != input.len) return error.ShortInput;
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    const input_sha = provenance.sha256Hex(input);
    const options: br.PlannedEncodeOptions = .{ .quality = 8, .mode = .generic, .window_bits = window_bits };
    var samples: std.ArrayList(Sample) = .empty;
    defer samples.deinit(init.gpa);
    try samples.ensureTotalCapacity(init.gpa, iterations);

    // Exactly one ordinary encode/free warmup per process. Hashing and saving
    // its complete wire are outside every measured interval.
    const warm_wire = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, options);
    const warm_size = warm_wire.len;
    const warm_sha = provenance.sha256Hex(warm_wire);
    if (wire_path) |wire_output| try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = wire_output, .data = warm_wire });
    init.gpa.free(warm_wire);

    var mix: usize = 0;
    for (0..iterations) |index| {
        const start = std.Io.Clock.awake.now(init.io);
        const wire = try br.encodePlannedStreamWithOptionsAlloc(init.gpa, input, options);
        const wire_size = wire.len;
        mix +%= wire_size;
        init.gpa.free(wire);
        const duration = elapsed(init.io, start);
        if (wire_size != warm_size) return error.WireLengthChanged;
        samples.appendAssumeCapacity(.{
            .index = index,
            .owned_encode_free_ns = duration,
            .wire_bytes = wire_size,
            .mix = mix,
        });
    }
    if (!std.mem.eql(u8, &input_sha, &provenance.sha256Hex(input))) return error.InputChanged;
    const json = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.q8-source-history-ab.process.v1",
        .source_revision = source,
        .provenance = info,
        .allocator = "std.process.Init.gpa",
        .input_path = path,
        .input_bytes = input.len,
        .input_sha256 = input_sha,
        .quality = options.quality,
        .mode = @tagName(options.mode),
        .requested_window_bits = options.window_bits,
        .warmup_owned_encode_free_calls = 1,
        .warm_wire_bytes = warm_size,
        .warm_wire_sha256 = warm_sha,
        .iterations = iterations,
        .timing_scope = "Continuous owned allocating public encode, wire-length mix and free. SHA256 and cross-library decode validate only the initial complete wire, outside timing.",
        .wire_identity_scope = "initial_wire_only; timed outputs check lengths/mix, not complete SHA256",
        .samples = samples.items,
    }, .{});
    defer init.gpa.free(json);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output, .data = json });
}
