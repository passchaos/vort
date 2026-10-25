//! Complete PrefixAlphabet comparison, including compact frequency/scatter work.
//! Generated pools and exact array checks run outside timed passes.
const std = @import("std");
const plan = @import("command_plan");
const provenance = @import("benchmark_provenance");
const Alphabet = plan.PrefixAlphabetFor(256);
const Input = struct { alphabet: Alphabet, frequencies: [256]u32 };
const Case = struct { name: []const u8, inputs: [32]Input, fallback_inputs: usize = 0, input_sha256: [64]u8 = undefined };
const Sample = struct { ns: u64, mix: u64 };
const Round = struct { reference_ns: u64, candidate_ns: u64, reference_first: bool, mix: u64 };

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const iterations = if (args.next()) |text| try std.fmt.parseInt(usize, text, 10) else 20000;
    if (iterations == 0 or args.next() != null) return error.InvalidArguments;
    const info = try provenance.capture(init.io, init.gpa, init.minimal.args, "single");
    defer info.deinit(init.gpa);
    const cases = try init.gpa.alloc(Case, 4);
    defer init.gpa.free(cases);
    var state: u32 = 0x6a09e667;
    for (cases, 0..) |*case, shape| {
        case.name = switch (shape) {
            0 => "dense_ties",
            1 => "dense_mixed",
            2 => "depth_fallback",
            else => "medium_control",
        };
        case.fallback_inputs = 0;
        var input_hash = std.crypto.hash.sha2.Sha256.init(.{});
        for (&case.inputs, 0..) |*input, index| {
            input.frequencies = @splat(0);
            const active = if (shape == 3) 65 + (index * 13) % 64 else 129 + (index * 17) % 128;
            var fibonacci: [34]u32 = undefined;
            fibonacci[0] = 1;
            fibonacci[1] = 1;
            for (2..34) |i| fibonacci[i] = fibonacci[i - 1] + fibonacci[i - 2];
            for (0..active) |i| {
                state = state *% 1664525 +% 1013904223;
                const frequency: u32 = switch (shape) {
                    0 => 1 + (state % 8),
                    1 => 1 + (state % 4096),
                    2 => if (i < 34) fibonacci[33 - i] else 1,
                    else => 1 + (state % 1024),
                };
                input.frequencies[(i * 149 + index * 7) % 256] = frequency;
            }
            input.alphabet = try plan.alphabetFromFrequencies(256, &input.frequencies);
            input_hash.update(std.mem.asBytes(&input.frequencies));
            const reference = try encode(true, input);
            const candidate = try encode(false, input);
            if (!std.mem.eql(u4, &reference, &candidate)) return error.CodeLengthMismatch;
            var profile: plan.CodeLengthsBuildProfile = .{};
            const observed = try input.alphabet.codeLengthsProfiled(&input.frequencies, init.io, &profile);
            if (!std.mem.eql(u4, &candidate, &observed) or profile.calls != 1) return error.CodeLengthMismatch;
            if (profile.package_merge_calls != profile.failures) return error.DispatchMismatch;
            case.fallback_inputs += profile.package_merge_calls;
        }
        case.input_sha256 = std.fmt.bytesToHex(input_hash.finalResult(), .lower);
        if ((shape == 2 and case.fallback_inputs != case.inputs.len) or (shape == 0 and case.fallback_inputs != 0)) return error.DispatchMismatch;
    }
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try stdout.interface.writeAll("{\"schema\":\"vort.brotli.dense-huffman-bench.v1\",\"provenance\":");
    try std.json.Stringify.value(info, .{}, &stdout.interface);
    try stdout.interface.print(",\"iterations\":{d},\"input_pool_size\":32,\"all_exact_lengths_equal\":true,\"rows\":[", .{iterations});
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
            if (a.mix != b.mix) return error.CodeLengthMismatch;
            round.* = .{ .reference_ns = if (r % 2 == 0) a.ns else b.ns, .candidate_ns = if (r % 2 == 0) b.ns else a.ns, .reference_first = r % 2 == 0, .mix = a.mix };
            reference_times[r] = round.reference_ns;
            candidate_times[r] = round.candidate_ns;
        }
        std.mem.sort(u64, &reference_times, {}, std.sort.asc(u64));
        std.mem.sort(u64, &candidate_times, {}, std.sort.asc(u64));
        try stdout.interface.print("{{\"case\":\"{s}\",\"input_sha256\":\"{s}\",\"fallback_inputs\":{d},\"reference_median_ns\":{d},\"candidate_median_ns\":{d},\"rounds\":", .{ case.name, case.input_sha256, case.fallback_inputs, reference_times[2], candidate_times[2] });
        try std.json.Stringify.value(rounds, .{}, &stdout.interface);
        try stdout.interface.writeByte('}');
    }
    try stdout.interface.writeAll("]}\n");
    try stdout.interface.flush();
}

noinline fn encode(comptime reference: bool, input: *const Input) ![256]u4 {
    return if (reference) input.alphabet.codeLengthsReference(&input.frequencies) else input.alphabet.codeLengths(&input.frequencies);
}
fn measure(comptime reference: bool, io: std.Io, case: *const Case, iterations: usize) !Sample {
    var mix: u64 = 0;
    var state: u32 = 0xbb67ae85;
    const before = std.Io.Clock.awake.now(io);
    for (0..iterations) |_| {
        state = state *% 1664525 +% 1013904223;
        const lengths = try encode(reference, &case.inputs[(state >> 16) & 31]);
        for (lengths, 0..) |bits, index| mix +%= (@as(u64, bits) + 1) * (index + 1);
    }
    const elapsed = before.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    std.mem.doNotOptimizeAway(mix);
    return .{ .ns = @intCast(elapsed), .mix = mix };
}
