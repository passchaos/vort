//! File-driven public incremental parallel protocol and JSON artifact report.
const std = @import("std");
const builtin = @import("builtin");
const zstd = @import("zstd");
const Config = @import("incremental_parallel_probe/config.zig").Config;
const Runner = @import("incremental_parallel_probe/driver.zig").Runner;
const ControlRun = @import("incremental_parallel_probe/event_state.zig").ControlRun;

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const input_path = args.next() orelse return error.MissingInput;
    const output_path = args.next() orelse return error.MissingOutput;
    const config_path = args.next() orelse return error.MissingConfig;
    if (args.next() != null) return error.TooManyArguments;
    const input = try read(init, input_path);
    defer init.gpa.free(input);
    const json = try read(init, config_path);
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{});
    defer parsed.deinit();
    const c = parsed.value;
    const dictionary_bytes = if (c.dictionary_path) |path| try read(init, path) else try init.gpa.alloc(u8, 0);
    defer init.gpa.free(dictionary_bytes);
    const input_sha = digest(input);
    const dictionary_sha = digest(dictionary_bytes);
    const dictionary: ?zstd.NativeDictionary = switch (c.dictionary_kind) {
        .none => null,
        .raw => zstd.NativeDictionary.init(c.dictionary_id, dictionary_bytes),
        .full => (try zstd.NativeDictionary.initFromStandardDictionary(dictionary_bytes)).dictionary,
        .metadata => zstd.NativeDictionary.init(c.dictionary_id, ""),
    };
    const dictionaries = [_]zstd.NativeDictionary{dictionary orelse zstd.NativeDictionary.initRawContent("")};
    var runner: Runner = .{ .state = .{ .init = init, .c = c, .input = input, .dictionary = dictionary, .set = zstd.NativeDictionarySet.init(&.{}) } };
    defer runner.deinit();
    if (c.use_dictionary_set) {
        runner.state.set = zstd.NativeDictionarySet.initChecked(&dictionaries) catch |err| blk: {
            runner.state.terminal = err;
            break :blk zstd.NativeDictionarySet.init(&.{});
        };
    }
    if (runner.state.terminal == null) runner.run(false) catch |err| {
        runner.state.terminal = err;
    };
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = output_path, .data = runner.state.wire.items });
    var control_runs: [2]?ControlRun = .{ null, null };
    if (runner.state.terminal == null) {
        for ([_][]const u8{ "worker1", "failing_io" }, 0..) |name, index| {
            var control_c = c;
            if (index == 0) control_c.worker_count = 1;
            var control: Runner = .{ .state = .{ .init = init, .c = control_c, .input = input, .dictionary = dictionary, .set = runner.state.set, .controls = true } };
            defer control.deinit();
            var failure: ?anyerror = null;
            control.run(index == 1) catch |err| {
                failure = err;
            };
            const equal = std.mem.eql(u8, runner.state.wire.items, control.state.wire.items);
            const snapshot = if (control.state.encoder) |*encoder| encoder.snapshot() else null;
            control_runs[index] = .{ .name = name, .failure = failure, .wire_equal = equal, .configured_workers = control_c.worker_count, .output_bytes = control.state.wire.items.len, .public_step_calls = control.state.calls, .snapshot = snapshot, .control_profile = control.state.control };
            if (failure != null) {
                runner.state.terminal = error.ControlRunFailed;
            } else if (!equal) {
                runner.state.terminal = error.SameGeometryControlWireMismatch;
            } else if (snapshot) |observed| {
                const p = observed.parallel.profile;
                if (!p.serial_fallback or p.workers_started != 0 or p.peak_active_workers != 0 or p.configured_workers != control_c.worker_count)
                    runner.state.terminal = error.ControlDidNotUseRealSerialFallback;
            }
            const path = try std.fmt.allocPrint(init.gpa, "{s}.{s}.zst", .{ output_path, name });
            defer init.gpa.free(path);
            try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = control.state.wire.items });
        }
    }
    const input_after = digest(input);
    const dictionary_after = digest(dictionary_bytes);
    if (!std.mem.eql(u8, &input_sha, &input_after) or !std.mem.eql(u8, &dictionary_sha, &dictionary_after)) return error.BorrowedDictionaryOrInputMutated;
    const output_sha = digest(runner.state.wire.items);
    const report = try std.json.Stringify.valueAlloc(init.gpa, .{
        .schema = "vort.zstd.incremental-parallel-probe.v1",
        .config = c,
        .@"error" = if (runner.state.terminal) |err| @errorName(err) else null,
        .initialized = runner.state.initialized,
        .invariants = runner.state.invariants,
        .input_bytes = input.len,
        .input_sha256 = input_sha[0..],
        .dictionary_bytes = dictionary_bytes.len,
        .dictionary_sha256 = dictionary_sha[0..],
        .dictionary_id = if (dictionary) |dict| dict.id else c.dictionary_id,
        .borrowed_input_and_dictionary_preserved = true,
        .output_bytes = runner.state.wire.items.len,
        .output_sha256 = output_sha[0..],
        .frames = runner.state.frames.items,
        .skippable = runner.state.skippable.items,
        .actual_flush_input_offsets = runner.state.flushes.items,
        .same_geometry_controls = control_runs,
        .recoveries = runner.state.recoveries.items,
        .events = runner.state.events.items,
        .public_step_calls = runner.state.calls,
        .record_every = c.record_every,
        .trace_scope = "Every step checked; sampled events plus all errors, completion, delivery transitions and explicit controls retained",
        .poisoned_accepted_input_bytes = runner.state.poisoned_bytes,
        .zero_output_calls = runner.state.zero_output_calls,
        .parallel_profile = runner.state.profile,
        .control_profile = runner.state.control,
        .control_emitted = runner.state.control.emitted(),
        .final_snapshot = if (runner.state.encoder) |*encoder| encoder.snapshot() else null,
        .self_decode_verified = runner.state.self_decode_verified,
        .observed_peak_active_workers = runner.state.observed_peak_active_workers,
        .target_supports_parallel = !builtin.single_threaded and (builtin.os.tag == .linux or builtin.os.tag == .windows or std.Thread.use_pthreads),
        .target = @tagName(builtin.cpu.arch),
        .cpu_model = builtin.cpu.model.name,
        .build_mode = @tagName(builtin.mode),
        .zig_version = builtin.zig_version_string,
        .scope = "Real incremental caller ownership and bounded single-frame jobs. Same explicit geometry worker1/failing-Io controls; no timing, RSS, or legacy serial wire claim.",
    }, .{});
    defer init.gpa.free(report);
    try std.Io.File.stdout().writeStreamingAll(init.io, report);
    try std.Io.File.stdout().writeStreamingAll(init.io, "\n");
}
fn digest(data: []const u8) [64]u8 {
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(data, &hash, .{});
    return std.fmt.bytesToHex(hash, .lower);
}
fn read(init: std.process.Init, path: []const u8) ![]u8 {
    return std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(128 * 1024 * 1024));
}
