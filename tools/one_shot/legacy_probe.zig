const std = @import("std");
const codec = @import("codec");

const Report = struct {
    count: usize = 0,
    @"error": ?[]const u8 = null,
    unchanged: bool = true,
    decoded_sha256: ?[64]u8 = null,
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const mode = args.next() orelse return error.MissingMode;
    const input_path = args.next() orelse return error.MissingInput;
    const expected = try std.fmt.parseInt(usize, args.next() orelse return error.MissingExpected, 10);
    const dictionary = try std.fmt.parseInt(usize, args.next() orelse return error.MissingDictionary, 10);
    const capacity = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCapacity, 10);
    const report_path = args.next() orelse return error.MissingReport;
    const input = try std.Io.Dir.cwd().readFileAlloc(init.io, input_path, init.gpa, .limited(64 * 1024 * 1024));
    defer init.gpa.free(input);
    const output = try init.gpa.alloc(u8, capacity);
    defer init.gpa.free(output);
    @memset(output, 0xa5);
    var report: Report = .{};
    report.count = run(init.gpa, mode, input, expected, dictionary, output) catch |err| blk: {
        report.@"error" = @errorName(err);
        break :blk 0;
    };
    for (output) |byte| if (byte != 0xa5) {
        report.unchanged = false;
        break;
    };
    if (report.@"error" == null and !std.mem.endsWith(u8, mode, "size")) {
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(output[0..report.count], &digest, .{});
        report.decoded_sha256 = std.fmt.bytesToHex(digest, .lower);
    }
    const json = try std.json.Stringify.valueAlloc(init.gpa, report, .{});
    defer init.gpa.free(json);
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = report_path, .data = json });
}

fn run(gpa: std.mem.Allocator, mode: []const u8, input: []const u8, expected: usize, dictionary: usize, output: []u8) !usize {
    if (std.mem.eql(u8, mode, "into")) return codec.decodeInto(gpa, input, output);
    if (std.mem.eql(u8, mode, "size")) return codec.decodedSizeLimited(gpa, input, output.len);
    if (comptime @hasDecl(codec, "decodeMicroInto")) {
        if (std.mem.eql(u8, mode, "micro")) {
            try codec.decodeMicroInto(gpa, input, output, @intCast(dictionary));
            return output.len;
        }
        if (std.mem.eql(u8, mode, "zip-eos")) return codec.decodeZipPayloadInto(gpa, input, expected, output, dictionary, true);
        if (std.mem.eql(u8, mode, "zip-known")) return codec.decodeZipPayloadInto(gpa, input, expected, output, dictionary, false);
    }
    if (comptime @hasDecl(codec, "decodeConcatenatedInto")) {
        if (std.mem.eql(u8, mode, "concat-into")) return codec.decodeConcatenatedInto(gpa, input, output);
        if (std.mem.eql(u8, mode, "concat-size")) return codec.decodedSizeConcatenatedLimited(gpa, input, output.len);
    }
    return error.InvalidMode;
}
