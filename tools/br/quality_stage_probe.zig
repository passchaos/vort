//! Reports the traced quality-scheduled candidate stages for one prefix.
//! The instrumented call is a diagnostic, not a throughput sample.

const std = @import("std");
const br = @import("vort_br");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var path: ?[]const u8 = null;
    var limit: usize = 128 * 1024;
    var quality: u4 = 11;
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--limit")) {
            limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--quality")) {
            quality = try std.fmt.parseInt(u4, args.next() orelse return error.MissingArgument, 10);
        } else if (path == null) {
            path = arg;
        } else {
            return error.UnknownArgument;
        }
    }
    const input_path = path orelse return error.MissingArgument;
    if (limit == 0) return error.InvalidArguments;

    const file = try std.Io.Dir.cwd().openFile(init.io, input_path, .{});
    defer file.close(init.io);
    const read_len: usize = @intCast(@min(limit, (try file.stat(init.io)).size));
    if (read_len == 0) return error.InputTooSmall;
    const input = try init.gpa.alloc(u8, read_len);
    defer init.gpa.free(input);
    var read_buffer: [64 * 1024]u8 = undefined;
    var reader = file.reader(init.io, &read_buffer);
    if (try reader.interface.readSliceShort(input) != read_len) return error.InputTooSmall;

    const profile = try init.gpa.create(br.QualityQ8Profile);
    defer init.gpa.destroy(profile);
    profile.* = .{};
    const wire = try br.benchmarkQualityProfileAlloc(init.gpa, input, init.io, .{
        .quality = quality,
        .mode = .generic,
    }, profile);
    defer init.gpa.free(wire);

    const total_ns = @max(profile.outer_elapsed_ns, 1);
    std.debug.print(
        "quality={d} input={d} wire={d} outer_ns={d} unaccounted_ns={d} wire_attempts={d} eval_attempts={d} events={d}/{d} truncated={}\n",
        .{
            quality,
            input.len,
            wire.len,
            profile.outer_elapsed_ns,
            profile.unaccounted_ns,
            profile.wire_attempts,
            profile.evaluation_attempts,
            profile.event_count,
            profile.events_total,
            profile.events_truncated,
        },
    );
    const exclusive = profile.exclusive_ns;
    inline for (std.meta.fields(@TypeOf(exclusive))) |field| {
        if (comptime std.mem.eql(u8, field.name, "total")) continue;
        const value = @field(exclusive, field.name);
        std.debug.print("  stage {s: <22} ns={d: <12} share={d:.1}%\n", .{
            field.name,
            value,
            @as(f64, @floatFromInt(value)) * 100.0 / @as(f64, @floatFromInt(total_ns)),
        });
    }

    var candidates: [128]br.QualityQ8ProfileEvent = undefined;
    var candidate_count: usize = 0;
    for (profile.recordedEvents()) |event| {
        if (event.wire_bytes == null) continue;
        if (candidate_count == candidates.len) break;
        candidates[candidate_count] = event;
        candidate_count += 1;
    }
    std.mem.sort(br.QualityQ8ProfileEvent, candidates[0..candidate_count], {}, struct {
        fn lessThan(_: void, left: br.QualityQ8ProfileEvent, right: br.QualityQ8ProfileEvent) bool {
            return left.wire_bytes.? < right.wire_bytes.?;
        }
    }.lessThan);
    for (candidates[0..candidate_count]) |event| {
        std.debug.print(
            "  wire id={d} origin={s} stage={s} bytes={d} accepted={?} gain={d}\n",
            .{
                event.id,
                @tagName(event.origin),
                @tagName(event.stage),
                event.wire_bytes.?,
                event.accepted,
                event.gain_bytes,
            },
        );
    }
}
