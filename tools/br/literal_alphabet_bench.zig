//! Complete supported-symbol collection and rank ordering comparison.
//! Pool construction and exact output checks precede every timed loop.
const std = @import("std");
const alphabet = @import("literal_alphabet");
const provenance = @import("benchmark_provenance");
const Rank = struct { symbols: [256]u16, len: usize };
const Symbols = struct { symbols: [256]u8, len: u16 };
const Input = struct { frequencies: [256]u32, support: [256]u8, support_len: usize };
const Case = struct { name: []const u8, inputs: [32]Input, input_sha256: [64]u8 };
const Sample = struct { ns: u64, mix: u64 };
const Round = struct { reference_ns: u64, candidate_ns: u64, reference_first: bool, mix: u64 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |value| try std.fmt.parseInt(usize, value, 10) else 50000;
    if (iterations == 0 or args.next() != null) return error.InvalidArguments;
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    const cases = try init.gpa.alloc(Case, 8);
    defer init.gpa.free(cases);
    var state: u32 = 0x6a09e667;
    for (cases, 0..) |*case, shape| {
        case.name = switch (shape) {
            0 => "small16",
            1 => "threshold64",
            2 => "medium96",
            3 => "boundary128",
            4 => "dense_mixed",
            5 => "dense_ties",
            6 => "ascending_weights",
            else => "sparse_dense_support",
        };
        var hash = std.crypto.hash.sha2.Sha256.init(.{});
        for (&case.inputs, 0..) |*input, index| {
            input.frequencies = @splat(0);
            input.support_len = switch (shape) {
                0 => 16,
                1 => 64,
                2 => 96,
                3 => 128,
                else => 256,
            };
            for (&input.support, 0..) |*symbol, i| symbol.* = @intCast(i);
            for (0..input.support_len) |i| {
                state = state *% 1664525 +% 1013904223;
                input.frequencies[i] = switch (shape) {
                    5 => 17,
                    6 => @intCast(i + 1 + index),
                    7 => if ((i + index) % 3 == 0) 1 + (state % 65536) else 0,
                    else => 1 + (state % 65536),
                };
            }
            // The kernel must ignore frequencies outside its caller support.
            for (input.frequencies[input.support_len..]) |*frequency| frequency.* = std.math.maxInt(u32);
            hash.update(std.mem.asBytes(&input.frequencies));
            hash.update(input.support[0..input.support_len]);
            var old_rank: Rank = undefined;
            var new_rank: Rank = undefined;
            var old_symbols: Symbols = undefined;
            var new_symbols: Symbols = undefined;
            try alphabet.reference(&input.frequencies, input.support[0..input.support_len], &old_rank, &old_symbols);
            try alphabet.build(&input.frequencies, input.support[0..input.support_len], &new_rank, &new_symbols);
            if (old_rank.len != old_symbols.len or new_rank.len != new_symbols.len or
                old_rank.len != new_rank.len or old_symbols.len != new_symbols.len or
                !std.mem.eql(u16, old_rank.symbols[0..old_rank.len], new_rank.symbols[0..new_rank.len]) or
                !std.mem.eql(u8, old_symbols.symbols[0..old_symbols.len], new_symbols.symbols[0..new_symbols.len])) return error.AlphabetMismatch;
        }
        case.input_sha256 = std.fmt.bytesToHex(hash.finalResult(), .lower);
    }
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll("{\"schema\":\"vort.brotli.literal-alphabet-bench.v1\",\"provenance\":");
    try std.json.Stringify.value(info, .{}, &stdout.interface);
    try stdout.interface.print(",\"iterations\":{d},\"input_pool_size\":32,\"sort_threshold\":{d},\"exact_outputs_equal\":true,\"rows\":[", .{ iterations, alphabet.sort_threshold });
    for (cases, 0..) |*case, index| {
        if (index != 0) try stdout.interface.writeByte(',');
        _ = try measure(true, init.io, case, 128);
        _ = try measure(false, init.io, case, 128);
        var rounds: [5]Round = undefined;
        var reference_times: [5]u64 = undefined;
        var candidate_times: [5]u64 = undefined;
        for (&rounds, 0..) |*round, r| {
            const a = if (r % 2 == 0) try measure(true, init.io, case, iterations) else try measure(false, init.io, case, iterations);
            const b = if (r % 2 == 0) try measure(false, init.io, case, iterations) else try measure(true, init.io, case, iterations);
            if (a.mix != b.mix) return error.AlphabetMismatch;
            round.* = .{ .reference_ns = if (r % 2 == 0) a.ns else b.ns, .candidate_ns = if (r % 2 == 0) b.ns else a.ns, .reference_first = r % 2 == 0, .mix = a.mix };
            reference_times[r] = round.reference_ns;
            candidate_times[r] = round.candidate_ns;
        }
        std.mem.sort(u64, &reference_times, {}, std.sort.asc(u64));
        std.mem.sort(u64, &candidate_times, {}, std.sort.asc(u64));
        try stdout.interface.print("{{\"case\":\"{s}\",\"input_sha256\":\"{s}\",\"reference_median_ns\":{d},\"candidate_median_ns\":{d},\"rounds\":", .{ case.name, case.input_sha256, reference_times[2], candidate_times[2] });
        try std.json.Stringify.value(rounds, .{}, &stdout.interface);
        try stdout.interface.writeByte('}');
    }
    try stdout.interface.writeAll("]}\n");
    try stdout.interface.flush();
}

noinline fn encode(comptime reference: bool, input: *const Input) !u64 {
    var rank: Rank = undefined;
    var symbols: Symbols = undefined;
    if (reference) try alphabet.reference(&input.frequencies, input.support[0..input.support_len], &rank, &symbols) else try alphabet.build(&input.frequencies, input.support[0..input.support_len], &rank, &symbols);
    var mix: u64 = @as(u64, @intCast(rank.len)) * 65537 + symbols.len;
    for (rank.symbols[0..rank.len], symbols.symbols[0..symbols.len], 0..) |symbol, sparse_symbol, i| mix +%= (@as(u64, symbol) * 257 + sparse_symbol + 1) * (i + 1);
    return mix;
}
fn measure(comptime reference: bool, io: std.Io, case: *const Case, iterations: usize) !Sample {
    var mix: u64 = 0;
    var state: u32 = 0xbb67ae85;
    const start = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        state = state *% 1664525 +% 1013904223;
        mix +%= try encode(reference, &case.inputs[(state >> 16) & 31]);
    }
    const elapsed = start.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    std.mem.doNotOptimizeAway(mix);
    return .{ .ns = @intCast(elapsed), .mix = mix };
}
