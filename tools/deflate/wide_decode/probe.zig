//! Real wide decode receipts. All wire/plaintext transfers are bounded; no
//! counter seeding, whole decoded collection or virtual source is used.
const std = @import("std");
const codec = @import("codec");
const stored = @import("stored_source.zig");
const Raw = codec.RawDeflateIncrementalFixedLiteralDecoder;
const Crc = @FieldType(codec.GzipIncrementalDecoder, "crc");
const Family = enum { raw_stored, raw_all, zlib, gzip };
const Config = struct {
    operation: enum { generated_stored, decode_fixture },
    family: Family,
    count: u64,
    semantic: bool = false,
    fixture_path: ?[]const u8 = null,
};
const Receipt = struct {
    input_read: u64 = 0,
    output_written: u64 = 0,
    source_bytes: u64 = 0,
    calls: u64 = 0,
    zero_output_calls: u64 = 0,
    crc32: u32 = 0,
    completed: bool = false,
    counter_bits: usize = 0,
    step_progress_bits: usize = 0,
    semantic_blocks_started: u64 = 0,
    semantic_blocks_completed: u64 = 0,
    member_end_offset: ?u64 = null,
};
const Run = struct {
    expected: u64,
    receipt: Receipt = .{},
    checksum: Crc = Crc.init(),
    output: [stored.chunk_len]u8 = undefined,

    fn step(self: *Run, decoder: anytype, input: []const u8) !usize {
        const before_input = decoder.total_input;
        const before_output = decoder.total_output;
        const out_len: usize = @intCast(@min(self.expected - self.receipt.output_written, self.output.len));
        const result = try decoder.step(input, self.output[0..out_len]);
        if (result.progress.input_read > input.len or result.progress.output_written > out_len) return error.InvalidProgress;
        const written = result.progress.output_written;
        if (!std.mem.eql(u8, self.output[0..written], stored.repeated[0..written])) return error.OutputContentMismatch;
        self.checksum.update(self.output[0..written]);
        self.receipt.input_read = try std.math.add(u64, self.receipt.input_read, @intCast(result.progress.input_read));
        self.receipt.output_written = try std.math.add(u64, self.receipt.output_written, @intCast(written));
        self.receipt.calls += 1;
        if (out_len == 0) self.receipt.zero_output_calls += 1;
        self.receipt.completed = result.status == .done;
        self.receipt.counter_bits = @bitSizeOf(@TypeOf(decoder.total_input));
        self.receipt.step_progress_bits = @bitSizeOf(@TypeOf(result.progress.input_read));
        if (self.receipt.counter_bits != 64) return error.MissingWideCounterApi;
        if (decoder.total_input != before_input + result.progress.input_read or decoder.total_output != before_output + written) return error.SnapshotProgressMismatch;
        if (decoder.total_input != self.receipt.input_read or decoder.total_output != self.receipt.output_written) return error.SnapshotProgressMismatch;
        const diagnostics = decoder.diagnostics();
        if (diagnostics.frame_input_read != self.receipt.input_read or diagnostics.output_written != self.receipt.output_written) return error.DiagnosticProgressMismatch;
        if (@hasDecl(@TypeOf(decoder.*), "snapshot")) {
            const snapshot = decoder.snapshot();
            if (@hasField(@TypeOf(snapshot), "last_step_progress")) if (!std.meta.eql(snapshot.last_step_progress, result.progress)) return error.LastStepProgressMismatch;
        }
        if (result.status != .done and result.progress.input_read == 0 and written == 0) return error.NoProgress;
        return result.progress.input_read;
    }
    fn finish(self: *Run, decoder: anytype) !void {
        try decoder.finish();
        if (!self.receipt.completed or self.receipt.input_read != self.receipt.source_bytes or self.receipt.output_written != self.expected) return error.WrongReceipt;
        self.receipt.crc32 = self.checksum.digest();
        if (@hasDecl(@TypeOf(decoder.*), "memberEndOffset")) {
            self.receipt.member_end_offset = decoder.memberEndOffset();
            if (self.receipt.member_end_offset != self.receipt.input_read) return error.MemberEndMismatch;
        }
        if (@hasDecl(@TypeOf(decoder.*), "semanticBlocksStarted")) {
            self.receipt.semantic_blocks_started = @intCast(decoder.semanticBlocksStarted());
            self.receipt.semantic_blocks_completed = @intCast(decoder.semanticBlocksCompleted());
        }
    }
};

pub fn main(init: std.process.Init) !void {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, init.gpa);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse return error.MissingConfig;
    const json = try std.Io.Dir.cwd().readFileAlloc(init.io, path, init.gpa, .limited(65536));
    defer init.gpa.free(json);
    const parsed = try std.json.parseFromSlice(Config, init.gpa, json, .{});
    defer parsed.deinit();
    const config = parsed.value;
    const history_len: usize = if (config.semantic) Raw.recommended_history_len else Raw.required_history_len;
    const history = try init.gpa.alloc(u8, history_len);
    defer init.gpa.free(history);
    const workspace = if (config.semantic) try init.gpa.create(Raw.SemanticWorkspace) else null;
    defer if (workspace) |owned| init.gpa.destroy(owned);
    var receipt: Receipt = undefined;
    switch (config.family) {
        .raw_stored => {
            if (config.semantic) return error.InvalidConfig;
            var decoder = codec.RawDeflateIncrementalStoredDecoder.initWithOptions(.{ .expected_output_len = config.count, .max_output_len = config.count });
            receipt = try decode(init, config, &decoder);
        },
        .raw_all => {
            var decoder = try Raw.initWithHistory(.{ .expected_output_len = config.count, .max_output_len = config.count }, history);
            if (workspace) |work| try decoder.attachSemanticWorkspace(work);
            receipt = try decode(init, config, &decoder);
        },
        .zlib => {
            var decoder = try codec.ZlibIncrementalDecoder.init(.{ .expected_output_len = config.count, .max_output_len = config.count }, history);
            if (workspace) |work| try decoder.raw.attachSemanticWorkspace(work);
            receipt = try decode(init, config, &decoder);
            receipt.semantic_blocks_started = @intCast(decoder.raw.semanticBlocksStarted());
            receipt.semantic_blocks_completed = @intCast(decoder.raw.semanticBlocksCompleted());
        },
        .gzip => {
            var decoder = try codec.GzipIncrementalDecoder.init(.{ .expected_output_len = config.count, .max_output_len = config.count }, history);
            if (workspace) |work| try decoder.raw.attachSemanticWorkspace(work);
            receipt = try decode(init, config, &decoder);
            receipt.semantic_blocks_started = @intCast(decoder.raw.semanticBlocksStarted());
            receipt.semantic_blocks_completed = @intCast(decoder.raw.semanticBlocksCompleted());
        },
    }
    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try std.json.Stringify.value(.{
        .schema = "vort.deflate.wide-decode.v1",
        .operation = config.operation,
        .family = config.family,
        .semantic = config.semantic,
        .semantic_route_exercised = receipt.semantic_blocks_started != 0,
        .count = config.count,
        .receipt = receipt,
        .input_chunk_bytes = stored.chunk_len,
        .output_chunk_bytes = stored.chunk_len,
        .history_bytes = history_len,
        .workspace_bytes = if (workspace != null) @sizeOf(Raw.SemanticWorkspace) else @as(usize, 0),
        .decoder_owned_heap_peak = @as(?usize, null),
        .decoder_allocator_api = false,
        .heap_scope = "no allocator hook for a decoder heap measurement; explicit history/workspace and IO buffers are caller-owned",
        .all_output_bytes_checked = true,
        .pointer_bits = @bitSizeOf(usize),
        .build_mode = @tagName(@import("builtin").mode),
    }, .{}, &stdout.interface);
    try stdout.interface.writeByte('\n');
    try stdout.interface.flush();
}

fn decode(init: std.process.Init, config: Config, decoder: anytype) !Receipt {
    var run: Run = .{ .expected = config.count };
    if (config.operation == .generated_stored) {
        if (config.family != .raw_stored and config.family != .raw_all) return error.UnsupportedGeneratedWrapper;
        var source = stored.Source.init(config.count);
        while (true) {
            const offered = source.next();
            if (source.ended) break;
            if (run.receipt.completed) return error.DecoderCompletedBeforeSource;
            try source.consume(try run.step(decoder, offered));
        }
        if (source.emitted_payload != config.count or source.remaining != 0) return error.SourceReceiptMismatch;
        run.receipt.source_bytes = source.emitted_input;
    } else {
        const file = try std.Io.Dir.cwd().openFile(init.io, config.fixture_path orelse return error.MissingFixture, .{});
        defer file.close(init.io);
        var read_buffer: [stored.chunk_len]u8 = undefined;
        var reader = file.readerStreaming(init.io, &read_buffer);
        var input: [stored.chunk_len]u8 = undefined;
        while (true) {
            const len = try reader.interface.readSliceShort(&input);
            if (len == 0) break;
            run.receipt.source_bytes = try std.math.add(u64, run.receipt.source_bytes, @intCast(len));
            var offset: usize = 0;
            while (offset < len) {
                if (run.receipt.completed) return error.TrailingFixtureBytes;
                offset += try run.step(decoder, input[offset..len]);
            }
        }
    }
    while (!run.receipt.completed) _ = try run.step(decoder, &.{});
    try run.finish(decoder);
    return run.receipt;
}
