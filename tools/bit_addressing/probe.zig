const std = @import("std");
const vort = @import("vort");
const br = vort.br;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingInput;
    const api = args.next() orelse return error.MissingApi;
    const expected_text = args.next() orelse return error.MissingExpected;
    if (args.next() != null) return error.TooManyArguments;
    const expected = try std.fmt.parseInt(usize, expected_text, 10);
    if (expected > 64) return error.InvalidExpectedSize;
    const file = try std.Io.Dir.cwd().openFile(init.io, path, .{});
    defer file.close(init.io);
    const file_stat = try file.stat(init.io);
    const length = std.math.cast(usize, file_stat.size) orelse return error.InputCannotBeMapped;
    const mapping = try std.posix.mmap(null, length, .{ .READ = true }, .{ .TYPE = .PRIVATE }, file.handle, 0);
    defer std.posix.munmap(mapping);
    var summary: ?br.StreamSummary = null;
    var profile: ?br.CompressedHeaderProfile = null;
    var storage: [80]u8 = @splat(0xa5);
    var written: usize = 0;
    const output = storage[8..72];
    if (std.mem.eql(u8, api, "alloc")) {
        const decoded = try br.decodeStreamAlloc(init.gpa, mapping);
        defer init.gpa.free(decoded);
        written = decoded.len;
        if (written > output.len) return error.UnexpectedDecodedSize;
        @memcpy(output[0..written], decoded);
    } else if (std.mem.eql(u8, api, "into")) {
        written = try br.decodeStreamInto(mapping, output);
    } else if (std.mem.eql(u8, api, "size")) {
        written = try br.decodedStreamSize(mapping);
    } else if (std.mem.eql(u8, api, "summary")) {
        summary = try br.summarizeStream(mapping);
        written = summary.?.decoded_bytes;
    } else if (std.mem.eql(u8, api, "headers")) {
        profile = try br.profileCompressedHeaders(init.io, init.gpa, mapping, 1);
        if (profile.?.compressed_meta_block_count != 1 or profile.?.input_bits == 0) return error.InvalidHighOffsetHeaderProfile;
        written = expected;
    } else return error.InvalidProbeApi;
    if (written != expected) return error.UnexpectedDecodedSize;
    for (storage[0..8]) |byte| if (byte != 0xa5) return error.CallerGuardModified;
    for (storage[72..]) |byte| if (byte != 0xa5) return error.CallerGuardModified;
    const decodes = std.mem.eql(u8, api, "alloc") or std.mem.eql(u8, api, "into");
    if (decodes) {
        for (output[0..written]) |byte| if (byte != 'R') return error.InvalidDecodedBytes;
        for (output[written..]) |byte| if (byte != 0xa5) return error.CallerGuardModified;
    }
    var output_digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(if (decodes) output[0..written] else "", &output_digest, .{});
    const report = .{
        .status = "ok",
        .api = api,
        .mapped_input_bytes = mapping.len,
        .actual_input_bits = @as(vort.BitCount, mapping.len) * 8,
        .bit_count_type_bits = @bitSizeOf(vort.BitCount),
        .usize_bits = @bitSizeOf(usize),
        .output_bytes = written,
        .output_sha256 = if (decodes) std.fmt.bytesToHex(output_digest, .lower) else null,
        .guards_verified = true,
        .summary = summary,
        .header_profile = profile,
        .large_window_enabled = false,
        .physical_mapping = true,
        .whole_file_sha256 = @as(?[]const u8, null),
        .public_decode_fast_kernel_invocation_observed = false,
        .scope = "actual mapped file and public complete-input API; header profile proves high-offset compressed header parsing, without a public fast-kernel invocation counter",
        .build_mode = @tagName(@import("builtin").mode),
    };
    const json = try std.json.Stringify.valueAlloc(init.gpa, report, .{});
    defer init.gpa.free(json);
    var stdout = std.Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll(json);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}
