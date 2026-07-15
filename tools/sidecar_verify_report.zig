const std = @import("std");
const vort = @import("vort");

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();

    var markdown_path: ?[]const u8 = null;
    var json_path: ?[]const u8 = null;
    var case_limit: ?usize = null;
    var validation_mode: vort.SidecarValidationMode = .full;
    var keep_going = false;
    var corrupt_self_test = false;
    var pairs: std.ArrayList(Pair) = .empty;
    defer {
        for (pairs.items) |pair| pair.deinit(init.gpa);
        pairs.deinit(init.gpa);
    }
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--self-test-corrupt")) {
            corrupt_self_test = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--markdown")) {
            markdown_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--json")) {
            json_path = args.next() orelse return error.MissingCorpusPath;
            continue;
        }
        if (std.mem.eql(u8, arg, "--limit")) {
            case_limit = try std.fmt.parseInt(usize, args.next() orelse return error.MissingCorpusPath, 10);
            continue;
        }
        if (std.mem.eql(u8, arg, "--mode")) {
            validation_mode = try parseValidationMode(args.next() orelse return error.MissingCorpusPath);
            continue;
        }
        if (std.mem.eql(u8, arg, "--metadata-only")) {
            validation_mode = .metadata;
            continue;
        }
        if (std.mem.eql(u8, arg, "--full")) {
            validation_mode = .full;
            continue;
        }
        if (std.mem.eql(u8, arg, "--keep-going")) {
            keep_going = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--dir")) {
            try appendDirectoryPairs(init, &pairs, args.next() orelse return error.MissingCorpusPath);
            continue;
        }
        const sidecar_path = args.next() orelse return error.MissingCorpusPath;
        try pairs.append(init.gpa, .{ .stream = arg, .sidecar = sidecar_path });
    }
    if (corrupt_self_test) {
        try runCorruptSelfTest(init, markdown_path, json_path);
        return;
    }
    if (pairs.items.len == 0) return error.MissingCorpusPath;

    var rows: std.ArrayList(ReportRow) = .empty;
    defer rows.deinit(init.gpa);

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print("stream,sidecar,mode,status,error,recoverability_hint,validation_stage,frame_index,frame_offset,uncompressed_offset,frame_flags,frame_mode,stream_bytes,sidecar_bytes,entries,total_uncompressed,combined_checksum,crc32\n", .{});
    for (pairs.items, 0..) |pair, i| {
        if (case_limit) |limit| if (i >= limit) break;
        const row = verifyPair(init, pair.stream, pair.sidecar, validation_mode, keep_going) catch |err| row: {
            if (!keep_going) return err;
            break :row ReportRow{ .stream = pair.stream, .sidecar = pair.sidecar, .validation_mode = @tagName(validation_mode), .status = "error", .error_name = @errorName(err) };
        };
        try rows.append(init.gpa, row);
        try printCsvRow(stdout, row);
    }
    try stdout.flush();
    if (markdown_path) |path| try writeMarkdown(init, path, rows.items);
    if (json_path) |path| try writeJson(init, path, rows.items);
}

const Pair = struct {
    stream: []const u8,
    sidecar: []const u8,
    owned: bool = false,

    fn deinit(self: Pair, allocator: std.mem.Allocator) void {
        if (self.owned) {
            allocator.free(self.stream);
            allocator.free(self.sidecar);
        }
    }
};

const ReportRow = struct {
    stream: []const u8,
    sidecar: []const u8,
    validation_mode: []const u8,
    stream_bytes: usize = 0,
    sidecar_bytes: usize = 0,
    entries: usize = 0,
    total_uncompressed: u64 = 0,
    combined_checksum: ?u32 = null,
    crc32: u32 = 0,
    status: []const u8 = "ok",
    error_name: []const u8 = "",
    recoverability_hint: []const u8 = "",
    validation_stage: []const u8 = "",
    frame_index: ?usize = null,
    frame_offset: ?usize = null,
    uncompressed_offset: ?u64 = null,
    frame_flags: ?u8 = null,
    frame_mode: []const u8 = "",
};

fn parseValidationMode(text: []const u8) !vort.SidecarValidationMode {
    if (std.mem.eql(u8, text, "metadata") or std.mem.eql(u8, text, "fast")) return .metadata;
    if (std.mem.eql(u8, text, "full")) return .full;
    return error.InvalidSidecarValidationMode;
}

fn runCorruptSelfTest(init: std.process.Init, markdown_path: ?[]const u8, json_path: ?[]const u8) !void {
    var stdout_buffer: [512]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    var cases: std.ArrayList(CorruptCase) = .empty;
    defer {
        for (cases.items) |case| case.deinit(init.gpa);
        cases.deinit(init.gpa);
    }
    try appendCorruptCase(init.gpa, &cases, try makeCorruptCase(init.gpa, "store", try vort.storeEncodeAlloc(init.gpa, "alpha"), null));
    try appendCorruptCase(init.gpa, &cases, try makeCorruptCase(init.gpa, "deflate", try vort.storeEncodeDeflateAlloc(init.gpa, ("hello hello hello hello " ** 16)), null));
    try appendCorruptCase(init.gpa, &cases, try makeCorruptCase(init.gpa, "rle", try vort.storeEncodeRleAlloc(init.gpa, ("a" ** 96)), null));

    const dict = "dictionary-only phrase with enough length to beat stored framing";
    try appendCorruptCase(init.gpa, &cases, try makeCorruptCase(init.gpa, "dictionary", try vort.storeEncodeDictionaryPatchAlloc(init.gpa, dict, dict ++ "!", 8), dict));

    const ldm_prefix = "abcd" ** 9000;
    const ldm_input = ldm_prefix ++ "----" ++ ldm_prefix[0..64].*;
    try appendCorruptCase(init.gpa, &cases, try makeCorruptCase(init.gpa, "ldm", try vort.storeEncodeLongDistanceAlloc(init.gpa, ldm_input, .{ .min_distance = 32769, .min_length = 16 }), null));

    const self_dict_phrase = "self-contained sidecar dictionary phrase";
    const self_dict_input = (self_dict_phrase ++ "!") ** 4;
    try appendCorruptCase(init.gpa, &cases, try makeCorruptCaseFromSidecar(
        init.gpa,
        "self-dict-sidecar",
        try vort.storeEncodeSidecarSelfContainedDictionaryStreamAlloc(init.gpa, self_dict_input, self_dict_phrase.len + 1, 256, 8),
        null,
    ));

    const seekable_phrase = "seekable native sidecar dictionary phrase";
    const seekable_input = (seekable_phrase ++ "!") ** 4;
    try appendCorruptCase(init.gpa, &cases, try makeCorruptCaseFromSidecar(
        init.gpa,
        "seekable-sidecar",
        try vort.storeEncodeSeekableNativeSidecarStreamAlloc(init.gpa, seekable_input, .{
            .block_len = seekable_phrase.len + 1,
            .dictionary = .{ .enable = true, .target_size = 256, .min_match_len = 8 },
        }),
        null,
    ));

    try appendCorruptCase(init.gpa, &cases, try makeEmbeddedCorruptCase(
        init.gpa,
        "embedded-index",
        try vort.storeEncodeIndexedStreamAlloc(init.gpa, &.{ "alpha", "beta", "gamma" }),
        null,
    ));

    var rows: std.ArrayList(CorruptReportRow) = .empty;
    defer rows.deinit(init.gpa);
    var metadata_ok: usize = 0;
    var full_rejected: usize = 0;
    for (cases.items) |case| {
        const full_error_name = try validateCorruptCase(init.gpa, case);
        metadata_ok += 1;
        full_rejected += 1;
        try rows.append(init.gpa, .{
            .case_name = case.name,
            .full_error_name = full_error_name,
            .stream_bytes = case.stream.len,
            .sidecar_bytes = case.sidecar_index.len,
        });
        try stdout.print("corrupt_case={s} metadata_ok=true full_rejected=true full_error={s} stream_bytes={d} sidecar_bytes={d}\n", .{
            case.name,
            full_error_name,
            case.stream.len,
            case.sidecar_index.len,
        });
    }

    try stdout.print("corrupt_self_test=true cases={d} metadata_ok={d} full_rejected={d}\n", .{
        cases.items.len,
        metadata_ok,
        full_rejected,
    });
    try stdout.flush();
    if (markdown_path) |path| try writeCorruptMarkdown(init, path, rows.items);
    if (json_path) |path| try writeCorruptJson(init, path, rows.items);
}

const CorruptCase = struct {
    name: []const u8,
    stream: []u8,
    sidecar_index: []u8,
    dictionary: ?[]const u8 = null,
    embedded_index: bool = false,

    fn deinit(self: CorruptCase, allocator: std.mem.Allocator) void {
        allocator.free(self.stream);
        if (!self.embedded_index) allocator.free(self.sidecar_index);
    }
};

const CorruptReportRow = struct {
    case_name: []const u8,
    metadata_ok: bool = true,
    full_rejected: bool = true,
    full_error_name: []const u8,
    stream_bytes: usize,
    sidecar_bytes: usize,
};

fn makeCorruptCase(allocator: std.mem.Allocator, name: []const u8, frame: []u8, dictionary: ?[]const u8) !CorruptCase {
    errdefer allocator.free(frame);
    const index = try vort.storeBuildFrameIndexAlloc(allocator, frame);
    defer allocator.free(index);
    const sidecar_index = try vort.storeEncodeFrameIndexAlloc(allocator, index);
    errdefer allocator.free(sidecar_index);
    return .{ .name = name, .stream = frame, .sidecar_index = sidecar_index, .dictionary = dictionary };
}

fn makeEmbeddedCorruptCase(allocator: std.mem.Allocator, name: []const u8, stream: []u8, dictionary: ?[]const u8) !CorruptCase {
    errdefer allocator.free(stream);
    return .{ .name = name, .stream = stream, .sidecar_index = "", .dictionary = dictionary, .embedded_index = true };
}

fn makeCorruptCaseFromSidecar(allocator: std.mem.Allocator, name: []const u8, sidecar: vort.store.SidecarIndexedStream, dictionary: ?[]const u8) !CorruptCase {
    errdefer sidecar.deinit(allocator);
    return .{ .name = name, .stream = sidecar.stream, .sidecar_index = sidecar.sidecar_index, .dictionary = dictionary };
}

fn appendCorruptCase(allocator: std.mem.Allocator, cases: *std.ArrayList(CorruptCase), case: CorruptCase) !void {
    errdefer case.deinit(allocator);
    try cases.append(allocator, case);
}

fn validateCorruptCase(allocator: std.mem.Allocator, case: CorruptCase) ![]const u8 {
    try validateCaseStream(allocator, case, .metadata);
    try validateCaseStream(allocator, case, .full);

    const entries = if (case.embedded_index) blk: {
        const embedded = try vort.store.parseEmbeddedIndexAlloc(allocator, case.stream);
        break :blk embedded.entries;
    } else try vort.storeDecodeFrameIndexAlloc(allocator, case.sidecar_index);
    if (entries.len == 0) return error.CorruptFrame;
    defer allocator.free(entries);

    const tampered = try allocator.dupe(u8, case.stream);
    defer allocator.free(tampered);
    const payload_offset = entries[0].frame_offset + vort.store.header_len;
    if (payload_offset >= tampered.len) return error.TruncatedFrame;
    // Flip a payload byte rather than the header or sidecar bytes. The
    // metadata-only verifier should still accept this by contract, while full
    // verification must reject it through the frame's decode/checksum path.
    tampered[payload_offset] ^= 1;

    try validateCaseBytes(allocator, case, tampered, .metadata);
    var full_error_name: []const u8 = "";
    validateCaseBytes(allocator, case, tampered, .full) catch |err| {
        full_error_name = @errorName(err);
    };
    if (full_error_name.len == 0) return error.CorruptFrame;
    return full_error_name;
}

fn validateCaseStream(allocator: std.mem.Allocator, case: CorruptCase, mode: vort.SidecarValidationMode) !void {
    return validateCaseBytes(allocator, case, case.stream, mode);
}

fn validateCaseBytes(allocator: std.mem.Allocator, case: CorruptCase, stream: []const u8, mode: vort.SidecarValidationMode) !void {
    if (case.embedded_index) {
        return vort.storeValidateEmbeddedIndexWithOptionsAlloc(allocator, stream, .{ .mode = mode, .dictionary = case.dictionary });
    }
    return vort.storeValidateSidecarIndexWithOptionsAlloc(allocator, stream, case.sidecar_index, .{ .mode = mode, .dictionary = case.dictionary });
}

fn writeCorruptMarkdown(init: std.process.Init, path: []const u8, rows: []const CorruptReportRow) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    var metadata_ok: usize = 0;
    var full_rejected: usize = 0;
    for (rows) |row| {
        if (row.metadata_ok) metadata_ok += 1;
        if (row.full_rejected) full_rejected += 1;
    }
    try w.print("# Sidecar corrupt-payload smoke report\n\n", .{});
    try w.print("- rows: {d}\n- metadata-ok rows: {d}\n- full-rejected rows: {d}\n\n", .{ rows.len, metadata_ok, full_rejected });
    try w.print("| case | metadata ok | full rejected | full error | stream bytes | sidecar bytes |\n", .{});
    try w.print("| --- | --- | --- | --- | ---: | ---: |\n", .{});
    for (rows) |row| {
        try w.print("| {s} | {} | {} | {s} | {d} | {d} |\n", .{
            row.case_name,
            row.metadata_ok,
            row.full_rejected,
            row.full_error_name,
            row.stream_bytes,
            row.sidecar_bytes,
        });
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}

fn writeCorruptJson(init: std.process.Init, path: []const u8, rows: []const CorruptReportRow) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    var metadata_ok: usize = 0;
    var full_rejected: usize = 0;
    for (rows) |row| {
        if (row.metadata_ok) metadata_ok += 1;
        if (row.full_rejected) full_rejected += 1;
    }
    try w.print("{{\n  \"schema\": \"vort.sidecar_corrupt_smoke_report\",\n  \"schema_version\": 1,\n  \"rows\": {d},\n  \"metadata_ok_rows\": {d},\n  \"full_rejected_rows\": {d},\n  \"items\": [\n", .{ rows.len, metadata_ok, full_rejected });
    for (rows, 0..) |row, i| {
        try w.print("    {{\"case\": ", .{});
        try std.json.Stringify.value(row.case_name, .{}, w);
        try w.print(", \"metadata_ok\": {}, \"full_rejected\": {}, \"full_error\": ", .{ row.metadata_ok, row.full_rejected });
        try std.json.Stringify.value(row.full_error_name, .{}, w);
        try w.print(", \"stream_bytes\": {d}, \"sidecar_bytes\": {d}}}{s}\n", .{
            row.stream_bytes,
            row.sidecar_bytes,
            if (i + 1 == rows.len) "" else ",",
        });
    }
    try w.print("  ]\n}}\n", .{});
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}

fn appendDirectoryPairs(init: std.process.Init, pairs: *std.ArrayList(Pair), dir_path: []const u8) !void {
    var dir = try std.Io.Dir.cwd().openDir(init.io, dir_path, .{ .iterate = true });
    defer dir.close(init.io);
    var walker = try dir.walk(init.gpa);
    defer walker.deinit();
    while (try walker.next(init.io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.path, ".vort")) continue;
        const relative_sidecar = try replaceExtension(init.gpa, entry.path, ".vidx");
        defer init.gpa.free(relative_sidecar);
        const sidecar = try std.fs.path.join(init.gpa, &.{ dir_path, relative_sidecar });
        errdefer init.gpa.free(sidecar);
        _ = std.Io.Dir.cwd().statFile(init.io, sidecar, .{}) catch {
            init.gpa.free(sidecar);
            continue;
        };
        const stream = try std.fs.path.join(init.gpa, &.{ dir_path, entry.path });
        errdefer init.gpa.free(stream);
        try pairs.append(init.gpa, .{ .stream = stream, .sidecar = sidecar, .owned = true });
    }
}

fn replaceExtension(allocator: std.mem.Allocator, path: []const u8, extension: []const u8) ![]u8 {
    const dot = std.mem.lastIndexOfScalar(u8, path, '.') orelse path.len;
    return std.fmt.allocPrint(allocator, "{s}{s}", .{ path[0..dot], extension });
}

fn verifyPair(init: std.process.Init, stream_path: []const u8, sidecar_path: []const u8, validation_mode: vort.SidecarValidationMode, keep_going: bool) !ReportRow {
    const stream = try std.Io.Dir.cwd().readFileAlloc(init.io, stream_path, init.gpa, .limited(128 * 1024 * 1024));
    defer init.gpa.free(stream);
    const sidecar = try std.Io.Dir.cwd().readFileAlloc(init.io, sidecar_path, init.gpa, .limited(16 * 1024 * 1024));
    defer init.gpa.free(sidecar);
    const validation = vort.storeValidateSidecarIndexReportAlloc(init.gpa, stream, sidecar, .{ .mode = validation_mode });
    if (!validation.ok and !keep_going) return error.CorruptFrame;
    const entries = vort.storeDecodeFrameIndexAlloc(init.gpa, sidecar) catch |err| {
        if (validation.ok) return err;
        return reportRowFromValidation(stream_path, sidecar_path, validation_mode, stream.len, sidecar.len, validation);
    };
    defer init.gpa.free(entries);
    var total_uncompressed: u64 = 0;
    for (entries) |entry| total_uncompressed += entry.uncompressed_len;
    var row = reportRowFromValidation(stream_path, sidecar_path, validation_mode, stream.len, sidecar.len, validation);
    row.entries = entries.len;
    row.total_uncompressed = total_uncompressed;
    row.combined_checksum = validation.combined_checksum;
    row.crc32 = vort.crc32(sidecar);
    return row;
}

fn reportRowFromValidation(stream_path: []const u8, sidecar_path: []const u8, validation_mode: vort.SidecarValidationMode, stream_len: usize, sidecar_len: usize, validation: vort.ValidationReport) ReportRow {
    return .{
        .stream = stream_path,
        .sidecar = sidecar_path,
        .validation_mode = @tagName(validation_mode),
        .stream_bytes = stream_len,
        .sidecar_bytes = sidecar_len,
        .status = if (validation.ok) "ok" else "error",
        .error_name = validation.error_name,
        .recoverability_hint = if (validation.ok) "" else @tagName(validation.recoverability_hint),
        .validation_stage = if (validation.ok) "" else @tagName(validation.stage),
        .frame_index = validation.frame_index,
        .frame_offset = validation.frame_offset,
        .uncompressed_offset = validation.uncompressed_offset,
        .frame_flags = validation.frame_flags,
        .frame_mode = validation.frame_mode,
        .entries = validation.frame_count,
        .total_uncompressed = validation.total_uncompressed,
        .combined_checksum = validation.combined_checksum,
    };
}

fn printCsvRow(stdout: *std.Io.Writer, row: ReportRow) !void {
    try stdout.print("{s},{s},{s},{s},{s},{s},{s},", .{
        row.stream,
        row.sidecar,
        row.validation_mode,
        row.status,
        row.error_name,
        row.recoverability_hint,
        row.validation_stage,
    });
    try printOptionalUsize(stdout, row.frame_index);
    try stdout.print(",", .{});
    try printOptionalUsize(stdout, row.frame_offset);
    try stdout.print(",", .{});
    try printOptionalU64(stdout, row.uncompressed_offset);
    try stdout.print(",", .{});
    try printOptionalU8(stdout, row.frame_flags);
    try stdout.print(",{s},{d},{d},{d},{d},", .{
        row.frame_mode,
        row.stream_bytes,
        row.sidecar_bytes,
        row.entries,
        row.total_uncompressed,
    });
    try printOptionalU32(stdout, row.combined_checksum);
    try stdout.print(",{d}\n", .{row.crc32});
}

fn printOptionalUsize(writer: *std.Io.Writer, value: ?usize) !void {
    if (value) |v| try writer.print("{d}", .{v});
}

fn printOptionalU64(writer: *std.Io.Writer, value: ?u64) !void {
    if (value) |v| try writer.print("{d}", .{v});
}

fn printOptionalU8(writer: *std.Io.Writer, value: ?u8) !void {
    if (value) |v| try writer.print("{d}", .{v});
}

fn printOptionalU32(writer: *std.Io.Writer, value: ?u32) !void {
    if (value) |v| try writer.print("{d}", .{v});
}

fn writeMarkdown(init: std.process.Init, path: []const u8, rows: []const ReportRow) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    var total_stream: usize = 0;
    var total_sidecar: usize = 0;
    var total_entries: usize = 0;
    var total_uncompressed: u64 = 0;
    var ok_rows: usize = 0;
    var error_rows: usize = 0;
    for (rows) |row| {
        if (std.mem.eql(u8, row.status, "ok")) ok_rows += 1 else error_rows += 1;
        total_stream += row.stream_bytes;
        total_sidecar += row.sidecar_bytes;
        total_entries += row.entries;
        total_uncompressed += row.total_uncompressed;
    }
    try w.print("# Sidecar verification report\n\n", .{});
    try w.print("- rows: {d}\n- ok rows: {d}\n- error rows: {d}\n- total stream bytes: {d}\n- total sidecar bytes: {d}\n- total entries: {d}\n- total uncompressed bytes: {d}\n\n", .{ rows.len, ok_rows, error_rows, total_stream, total_sidecar, total_entries, total_uncompressed });
    try w.print("| stream | sidecar | mode | status | error | hint | stage | frame index | frame offset | uncompressed offset | frame flags | frame mode | stream bytes | sidecar bytes | entries | total uncompressed | combined crc32 | sidecar crc32 |\n", .{});
    try w.print("| --- | --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |\n", .{});
    for (rows) |row| {
        try w.print("| {s} | {s} | {s} | {s} | {s} | {s} | {s} | ", .{ row.stream, row.sidecar, row.validation_mode, row.status, row.error_name, row.recoverability_hint, row.validation_stage });
        try printOptionalUsize(w, row.frame_index);
        try w.print(" | ", .{});
        try printOptionalUsize(w, row.frame_offset);
        try w.print(" | ", .{});
        try printOptionalU64(w, row.uncompressed_offset);
        try w.print(" | ", .{});
        try printOptionalU8(w, row.frame_flags);
        try w.print(" | {s} | {d} | {d} | {d} | {d} | ", .{ row.frame_mode, row.stream_bytes, row.sidecar_bytes, row.entries, row.total_uncompressed });
        try printOptionalU32(w, row.combined_checksum);
        try w.print(" | {d} |\n", .{row.crc32});
    }
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}

fn writeJson(init: std.process.Init, path: []const u8, rows: []const ReportRow) !void {
    var writer = std.Io.Writer.Allocating.init(init.gpa);
    defer writer.deinit();
    const w = &writer.writer;
    var total_stream: usize = 0;
    var total_sidecar: usize = 0;
    var total_entries: usize = 0;
    var total_uncompressed: u64 = 0;
    var ok_rows: usize = 0;
    var error_rows: usize = 0;
    for (rows) |row| {
        if (std.mem.eql(u8, row.status, "ok")) ok_rows += 1 else error_rows += 1;
        total_stream += row.stream_bytes;
        total_sidecar += row.sidecar_bytes;
        total_entries += row.entries;
        total_uncompressed += row.total_uncompressed;
    }
    try w.print("{{\n  \"schema\": \"vort.sidecar_verify_report\",\n  \"schema_version\": 1,\n  \"rows\": {d},\n  \"ok_rows\": {d},\n  \"error_rows\": {d},\n  \"total_stream_bytes\": {d},\n  \"total_sidecar_bytes\": {d},\n  \"total_entries\": {d},\n  \"total_uncompressed_bytes\": {d},\n  \"items\": [\n", .{ rows.len, ok_rows, error_rows, total_stream, total_sidecar, total_entries, total_uncompressed });
    for (rows, 0..) |row, i| {
        try w.print("    {{\"stream\": ", .{});
        try std.json.Stringify.value(row.stream, .{}, w);
        try w.print(", \"sidecar\": ", .{});
        try std.json.Stringify.value(row.sidecar, .{}, w);
        try w.print(", \"mode\": ", .{});
        try std.json.Stringify.value(row.validation_mode, .{}, w);
        try w.print(", \"status\": ", .{});
        try std.json.Stringify.value(row.status, .{}, w);
        try w.print(", \"error\": ", .{});
        try std.json.Stringify.value(row.error_name, .{}, w);
        try w.print(", \"recoverability_hint\": ", .{});
        try std.json.Stringify.value(row.recoverability_hint, .{}, w);
        try w.print(", \"validation_stage\": ", .{});
        try std.json.Stringify.value(row.validation_stage, .{}, w);
        try w.print(", \"frame_index\": ", .{});
        try writeOptionalJson(usize, w, row.frame_index);
        try w.print(", \"frame_offset\": ", .{});
        try writeOptionalJson(usize, w, row.frame_offset);
        try w.print(", \"uncompressed_offset\": ", .{});
        try writeOptionalJson(u64, w, row.uncompressed_offset);
        try w.print(", \"frame_flags\": ", .{});
        try writeOptionalJson(u8, w, row.frame_flags);
        try w.print(", \"frame_mode\": ", .{});
        try std.json.Stringify.value(row.frame_mode, .{}, w);
        try w.print(", \"stream_bytes\": {d}, \"sidecar_bytes\": {d}, \"entries\": {d}, \"total_uncompressed\": {d}, \"combined_checksum\": ", .{
            row.stream_bytes,
            row.sidecar_bytes,
            row.entries,
            row.total_uncompressed,
        });
        try writeOptionalJson(u32, w, row.combined_checksum);
        try w.print(", \"crc32\": {d}}}{s}\n", .{
            row.crc32,
            if (i + 1 == rows.len) "" else ",",
        });
    }
    try w.print("  ]\n}}\n", .{});
    try std.Io.Dir.cwd().writeFile(init.io, .{ .sub_path = path, .data = writer.written() });
}

fn writeOptionalJson(comptime T: type, writer: *std.Io.Writer, value: ?T) !void {
    if (value) |v| {
        try writer.print("{d}", .{v});
    } else {
        try writer.print("null", .{});
    }
}
