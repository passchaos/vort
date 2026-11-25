//! Measures how much match coverage the Brotli ratio parser leaves on the
//! table because its search window is capped at 32 KiB. For each input
//! position the probe compares the longest hash-chain match inside the near
//! window with the longest match inside a wider window and reports how many
//! bytes the wider search would add.

const std = @import("std");
const lz77 = @import("lz77");

const Options = struct {
    limit: usize = 128 * 1024,
    near: usize = 32 * 1024,
    far: usize = 65520,
    chain: u16 = 512,
    top: usize = 8,
};

const Coverage = struct {
    positions_with_match: usize = 0,
    matched_bytes: usize = 0,
};

const Example = struct {
    position: usize,
    near: lz77.CollectedMatch,
    far: lz77.CollectedMatch,
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();
    _ = args.next();

    var options: Options = .{};
    var path: ?[]const u8 = null;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--limit")) {
            options.limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--near")) {
            options.near = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--far")) {
            options.far = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--chain")) {
            options.chain = try std.fmt.parseInt(u16, args.next() orelse return error.MissingLimit, 10);
        } else if (std.mem.eql(u8, arg, "--top")) {
            options.top = try std.fmt.parseInt(usize, args.next() orelse return error.MissingLimit, 10);
        } else if (path == null) {
            path = arg;
        } else {
            return error.UnknownArgument;
        }
    }
    const input_path = path orelse return error.MissingCorpusPath;
    if (options.near == 0 or options.far <= options.near or options.far > lz77.max_window_len)
        return error.InvalidBlockPlan;

    var file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer file.close(init.io);
    const read_len = @min(options.limit, (try file.stat(init.io)).size);
    const input = try allocator.alloc(u8, read_len);
    defer allocator.free(input);
    var reader_buffer: [64 * 1024]u8 = undefined;
    var reader = file.reader(init.io, &reader_buffer);
    if (try reader.interface.readSliceShort(input) != read_len) return error.InputTooSmall;

    const near = try lz77.collectHashMatchesAlloc(allocator, input, .{
        .window_len = options.near,
        .max_chain = options.chain,
        .nice_len = lz77.max_match_len,
        .min_match = 4,
    });
    defer allocator.free(near);
    const far = try lz77.collectHashMatchesAlloc(allocator, input, .{
        .window_len = options.far,
        .max_chain = options.chain,
        .nice_len = lz77.max_match_len,
        .min_match = 4,
    });
    defer allocator.free(far);

    var near_coverage: Coverage = .{};
    var far_coverage: Coverage = .{};
    var longer_positions: usize = 0;
    var extra_bytes: usize = 0;
    var extra_bytes_at_least_8: usize = 0;
    var far_only_positions: usize = 0;
    var examples: [16]Example = undefined;
    var example_count: usize = 0;

    for (near, far, 0..) |near_match, far_match, position| {
        if (near_match.length != 0) {
            near_coverage.positions_with_match += 1;
            near_coverage.matched_bytes += near_match.length;
        }
        if (far_match.length != 0) {
            far_coverage.positions_with_match += 1;
            far_coverage.matched_bytes += far_match.length;
        }
        if (far_match.length > near_match.length) {
            longer_positions += 1;
            const extra = far_match.length - near_match.length;
            extra_bytes += extra;
            if (extra >= 8) extra_bytes_at_least_8 += 1;
            if (near_match.length == 0) far_only_positions += 1;
            if (example_count < examples.len) {
                examples[example_count] = .{
                    .position = position,
                    .near = near_match,
                    .far = far_match,
                };
                example_count += 1;
            } else if (options.top != 0 and extra > examples[examples.len - 1].far.length - examples[examples.len - 1].near.length) {
                // Keep the examples with the largest absolute gain.
                examples[examples.len - 1] = .{
                    .position = position,
                    .near = near_match,
                    .far = far_match,
                };
                std.mem.sort(Example, examples[0..], {}, exampleLessThan);
            }
        }
    }
    std.mem.sort(Example, examples[0..example_count], {}, exampleLessThan);

    std.debug.print(
        "file={s} bytes={d} chain={d} near={d} far={d}\n" ++
            "near positions={d} matched_bytes={d}\n" ++
            "far  positions={d} matched_bytes={d}\n" ++
            "longer_positions={d} far_only_positions={d} extra_bytes={d} extra_positions_ge8={d}\n",
        .{
            input_path,
            input.len,
            options.chain,
            options.near,
            options.far,
            near_coverage.positions_with_match,
            near_coverage.matched_bytes,
            far_coverage.positions_with_match,
            far_coverage.matched_bytes,
            longer_positions,
            far_only_positions,
            extra_bytes,
            extra_bytes_at_least_8,
        },
    );
    const shown = @min(options.top, example_count);
    for (examples[0..shown]) |example| {
        std.debug.print(
            "  pos={d} near=({d},{d}) far=({d},{d}) gain={d}\n",
            .{
                example.position,
                example.near.length,
                example.near.distance,
                example.far.length,
                example.far.distance,
                @as(usize, example.far.length) - example.near.length,
            },
        );
    }
}

fn exampleLessThan(_: void, left: Example, right: Example) bool {
    const left_gain = @as(usize, left.far.length) - left.near.length;
    const right_gain = @as(usize, right.far.length) - right.near.length;
    if (left_gain != right_gain) return left_gain > right_gain;
    return left.position < right.position;
}
