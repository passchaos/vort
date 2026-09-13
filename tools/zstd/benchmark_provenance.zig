const std = @import("std");
const builtin = @import("builtin");

pub const csv_columns = "provenance_version,optimize,zig_version,target_arch,target_os,target_abi,target_cpu,cpu_model,cpu_affinity,affinity_cpu_count,benchmark_threads,codec_thread_policy,executable_sha256,command";

pub const Info = struct {
    provenance_version: u8 = 1,
    optimize: []const u8 = @tagName(builtin.mode),
    zig_version: []const u8 = builtin.zig_version_string,
    target_arch: []const u8 = @tagName(builtin.target.cpu.arch),
    target_os: []const u8 = @tagName(builtin.target.os.tag),
    target_abi: []const u8 = @tagName(builtin.target.abi),
    target_cpu: []u8,
    cpu_model: []u8,
    cpu_affinity: []u8,
    affinity_cpu_count: usize,
    benchmark_threads: usize = 1,
    codec_thread_policy: []const u8,
    executable_sha256: []u8,
    command: []u8,

    pub fn deinit(info: Info, allocator: std.mem.Allocator) void {
        allocator.free(info.target_cpu);
        allocator.free(info.cpu_model);
        allocator.free(info.cpu_affinity);
        allocator.free(info.executable_sha256);
        allocator.free(info.command);
    }

    pub fn writeCsvFields(info: Info, writer: *std.Io.Writer) !void {
        try writer.print(",{d},{s},{s},{s},{s},{s},{s},{s},{s},{d},{d},{s},{s},{s}", .{
            info.provenance_version,
            info.optimize,
            info.zig_version,
            info.target_arch,
            info.target_os,
            info.target_abi,
            info.target_cpu,
            info.cpu_model,
            info.cpu_affinity,
            info.affinity_cpu_count,
            info.benchmark_threads,
            info.codec_thread_policy,
            info.executable_sha256,
            info.command,
        });
    }
};

pub fn capture(io: std.Io, allocator: std.mem.Allocator, process_args: std.process.Args, codec_thread_policy: []const u8) !Info {
    const target_cpu = try std.zig.serializeCpuAlloc(allocator, builtin.cpu);
    errdefer allocator.free(target_cpu);
    const cpu_model = try cpuModelAlloc(io, allocator);
    errdefer allocator.free(cpu_model);
    const affinity = try cpuAffinity(allocator);
    errdefer allocator.free(affinity.text);
    const executable_sha256 = try executableSha256Alloc(io, allocator);
    errdefer allocator.free(executable_sha256);
    return .{
        .target_cpu = target_cpu,
        .cpu_model = cpu_model,
        .cpu_affinity = affinity.text,
        .affinity_cpu_count = affinity.count,
        .codec_thread_policy = codec_thread_policy,
        .executable_sha256 = executable_sha256,
        .command = try commandLineAlloc(allocator, process_args),
    };
}

pub fn sha256Hex(bytes: []const u8) [std.crypto.hash.sha2.Sha256.digest_length * 2]u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn executableSha256Alloc(io: std.Io, allocator: std.mem.Allocator) ![]u8 {
    const path = std.process.executablePathAlloc(io, allocator) catch
        return allocator.dupe(u8, "unavailable");
    defer allocator.free(path);
    const file = std.Io.Dir.openFileAbsolute(io, path, .{}) catch
        return allocator.dupe(u8, "unavailable");
    defer file.close(io);
    var reader_buffer: [16 * 1024]u8 = undefined;
    var reader = file.readerStreaming(io, &reader_buffer);
    var hash_buffer: [16 * 1024]u8 = undefined;
    var hashing_writer: std.Io.Writer.Hashing(std.crypto.hash.sha2.Sha256) = .init(&hash_buffer);
    _ = reader.interface.streamRemaining(&hashing_writer.writer) catch
        return allocator.dupe(u8, "unavailable");
    try hashing_writer.writer.flush();
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    hashing_writer.hasher.final(&digest);
    const hex = std.fmt.bytesToHex(digest, .lower);
    return allocator.dupe(u8, &hex);
}

fn commandLineAlloc(allocator: std.mem.Allocator, process_args: std.process.Args) ![]u8 {
    var iterator = try std.process.Args.Iterator.initAllocator(process_args, allocator);
    defer iterator.deinit();
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    var first = true;
    while (iterator.next()) |argument| {
        if (!first) try output.writer.writeByte(' ');
        try writePercentEncoded(&output.writer, argument);
        first = false;
    }
    return output.toOwnedSlice();
}

fn writePercentEncoded(writer: *std.Io.Writer, bytes: []const u8) !void {
    const hex = "0123456789ABCDEF";
    for (bytes) |byte| {
        if (std.ascii.isAlphanumeric(byte) or std.mem.indexOfScalar(u8, "-._/:=", byte) != null) {
            try writer.writeByte(byte);
        } else {
            try writer.writeByte('%');
            try writer.writeByte(hex[byte >> 4]);
            try writer.writeByte(hex[byte & 0x0f]);
        }
    }
}

fn cpuModelAlloc(io: std.Io, allocator: std.mem.Allocator) ![]u8 {
    if (comptime builtin.os.tag == .linux) {
        const file = std.Io.Dir.openFileAbsolute(io, "/proc/cpuinfo", .{}) catch
            return allocator.dupe(u8, "unavailable");
        defer file.close(io);
        var buffer: [4096]u8 = undefined;
        var reader = file.readerStreaming(io, &buffer);
        const cpuinfo = reader.interface.allocRemaining(allocator, .limited(1024 * 1024)) catch
            return allocator.dupe(u8, "unavailable");
        defer allocator.free(cpuinfo);
        var lines = std.mem.splitScalar(u8, cpuinfo, '\n');
        while (lines.next()) |line| {
            const separator = std.mem.indexOfScalar(u8, line, ':') orelse continue;
            const key = std.mem.trim(u8, line[0..separator], " \t");
            if (!std.mem.eql(u8, key, "model name") and !std.mem.eql(u8, key, "Hardware")) continue;
            const value = std.mem.trim(u8, line[separator + 1 ..], " \t\r");
            if (value.len == 0) continue;
            const copy = try allocator.dupe(u8, value);
            std.mem.replaceScalar(u8, copy, ',', ';');
            return copy;
        }
    }
    return allocator.dupe(u8, "unavailable");
}

const Affinity = struct { text: []u8, count: usize };

fn cpuAffinity(allocator: std.mem.Allocator) !Affinity {
    if (comptime builtin.os.tag == .linux) {
        const set = std.posix.sched_getaffinity(0) catch return .{ .text = try allocator.dupe(u8, "unavailable"), .count = 0 };
        var selected: [@bitSizeOf(std.posix.cpu_set_t)]bool = @splat(false);
        for (0..selected.len) |cpu| {
            const word = cpu / @bitSizeOf(usize);
            const bit: std.math.Log2Int(usize) = @intCast(cpu % @bitSizeOf(usize));
            selected[cpu] = set[word] & (@as(usize, 1) << bit) != 0;
        }
        return .{ .text = try formatAffinityAlloc(allocator, &selected), .count = @intCast(std.posix.CPU_COUNT(set)) };
    }
    return .{ .text = try allocator.dupe(u8, "unavailable"), .count = 0 };
}

fn formatAffinityAlloc(allocator: std.mem.Allocator, selected: []const bool) ![]u8 {
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    var first = true;
    var cpu: usize = 0;
    while (cpu < selected.len) {
        if (!selected[cpu]) {
            cpu += 1;
            continue;
        }
        const start = cpu;
        while (cpu + 1 < selected.len and selected[cpu + 1]) cpu += 1;
        if (!first) try output.writer.writeByte(';');
        if (cpu == start)
            try output.writer.print("{d}", .{start})
        else
            try output.writer.print("{d}-{d}", .{ start, cpu });
        first = false;
        cpu += 1;
    }
    if (first) try output.writer.writeAll("unavailable");
    return output.toOwnedSlice();
}

test "benchmark provenance compacts CPU affinity ranges" {
    const selected = [_]bool{ false, true, true, true, false, true, false, true, true };
    const formatted = try formatAffinityAlloc(std.testing.allocator, &selected);
    defer std.testing.allocator.free(formatted);
    try std.testing.expectEqualStrings("1-3;5;7-8", formatted);
}

test "benchmark provenance percent-encodes command arguments for CSV" {
    var output: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer output.deinit();
    try writePercentEncoded(&output.writer, "a path,with%quotes\n");
    try std.testing.expectEqualStrings("a%20path%2Cwith%25quotes%0A", output.written());
}

test "benchmark provenance hashes exact input bytes" {
    try std.testing.expectEqualStrings(
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
        &sha256Hex("abc"),
    );
}

test "benchmark provenance reports compile target and runtime affinity" {
    if (comptime builtin.os.tag == .windows or builtin.os.tag == .wasi) return error.SkipZigTest;
    const argv = [_][*:0]const u8{"vort-benchmark"};
    const process_args: std.process.Args = .{ .vector = &argv };
    const info = try capture(std.testing.io, std.testing.allocator, process_args, "single");
    defer info.deinit(std.testing.allocator);
    try std.testing.expect(info.optimize.len != 0);
    try std.testing.expect(info.zig_version.len != 0);
    try std.testing.expect(info.target_arch.len != 0);
    try std.testing.expect(info.target_os.len != 0);
    try std.testing.expect(info.target_abi.len != 0);
    try std.testing.expect(info.target_cpu.len != 0);
    try std.testing.expect(info.cpu_model.len != 0);
    try std.testing.expect(info.cpu_affinity.len != 0);
    if (!std.mem.eql(u8, info.cpu_affinity, "unavailable")) try std.testing.expect(info.affinity_cpu_count != 0);
    try std.testing.expectEqual(@as(usize, 1), info.benchmark_threads);
    try std.testing.expectEqualStrings("single", info.codec_thread_policy);
    try std.testing.expect(info.executable_sha256.len == 64);
    try std.testing.expect(info.command.len != 0);
    try std.testing.expect(std.mem.indexOfScalar(u8, info.cpu_affinity, ',') == null);
}
