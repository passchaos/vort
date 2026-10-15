const std = @import("std");
const api = @import("incremental_reader/api.zig");
const archive_records = @import("incremental_reader/archive_records.zig");
const codecs = @import("incremental_reader/codecs.zig");
const core = @import("../core.zig");
const descriptor = @import("incremental_reader/descriptor.zig");
const directory = @import("incremental_reader/directory.zig");
const entry_decoder = @import("incremental_entry_decoder.zig");
const types = @import("types.zig");
const traditional_encryption = @import("vail_archive_crypto").zipcrypto;
const wire = @import("wire.zig");

pub const CompressionMethod = api.CompressionMethod;

pub const Error = codecs.Error || entry_decoder.Error || archive_records.Error || traditional_encryption.Error || std.mem.Allocator.Error || error{
    ZipReaderFailed,
    UnsupportedZipCompressionMethod,
    EncryptedZipEntry,
    PasswordRequired,
};

pub const Options = api.Options;
pub const Phase = api.Phase;
pub const StepResult = api.StepResult;
pub const EntryInfo = api.EntryInfo;

/// Sequential ZIP32/ZIP64 reader for Stored and raw-Deflate members.
///
/// Local headers, payloads, signed or unsigned data descriptors, central
/// records, ZIP64 endings, and EOCD comments may cross arbitrary caller input
/// slices. Entry bytes stream directly to caller output. Only names and compact
/// per-entry validation records are retained until the central directory.
pub const Reader = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .record_signature,
    control: std.ArrayList(u8) = .empty,
    control_target: usize = 4,
    record_offset: usize = 0,
    history: []u8,
    directory: directory.State = .{},
    current_index: ?usize = null,
    current_state: ?EntryState = null,
    current_encryption: ?EncryptionState = null,
    descriptor_parser: descriptor.Parser = .{},
    total_input: usize = 0,
    total_output: usize = 0,
    zip64_end: ?archive_records.Zip64End = null,
    zip64_end_offset: usize = 0,
    zip64_locator_seen: bool = false,
    digital_signature_seen: bool = false,
    archive_comment: []u8 = &.{},
    last_error_name: []const u8 = "",

    const Self = @This();

    const EncryptionState = struct {
        cipher: traditional_encryption.Cipher,
        header: [traditional_encryption.header_len]u8 = undefined,
        header_len: usize = 0,
        check_byte: u8,

        fn init(password: []const u8, check_byte: u8) EncryptionState {
            return .{
                .cipher = traditional_encryption.Cipher.init(password),
                .check_byte = check_byte,
            };
        }

        fn deinit(self: *EncryptionState) void {
            self.cipher.deinit();
            std.crypto.secureZero(u8, &self.header);
            self.* = undefined;
        }
    };

    const EntryState = union(enum) {
        known: entry_decoder.Decoder,
        stored_descriptor: descriptor.StoredScanner,
        deflate_descriptor: codecs.DeflateState,
        shrink: codecs.ShrinkState,
        reduce: codecs.ReduceState,
        implode: codecs.ImplodeState,
        deflate64: codecs.Deflate64State,
        dcl_implode: codecs.DclImplodeState,
        bzip2: codecs.Bzip2State,
        lzma: codecs.LzmaZipState,
        ppmd: codecs.PpmdZipState,
        xz: codecs.XzState,
        zstd: codecs.ZstdState,

        fn deinit(self: *EntryState) void {
            switch (self.*) {
                .deflate_descriptor => |*state| state.deinit(),
                .shrink => |*state| state.deinit(),
                .reduce => |*state| state.deinit(),
                .implode => |*state| state.deinit(),
                .deflate64 => |*state| state.deinit(),
                .dcl_implode => |*state| state.deinit(),
                .bzip2 => |*state| state.deinit(),
                .lzma => |*state| state.deinit(),
                .ppmd => |*state| state.deinit(),
                .xz => |*state| state.deinit(),
                .zstd => |*state| state.deinit(),
                .known, .stored_descriptor => {},
            }
        }
    };

    pub const Snapshot = struct {
        phase: Phase,
        input_read: usize,
        output_written: usize,
        completed_entries: usize,
        retained_entries: usize,
        retained_metadata_size: usize,
        central_entries: usize,
        central_offset: ?usize,
        central_size: ?usize,
        current_entry: ?EntryInfo,
        last_error_name: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
        try validateOptions(options);
        const history = try allocator.alloc(u8, entry_decoder.Decoder.required_history_len);
        errdefer allocator.free(history);
        var control: std.ArrayList(u8) = .empty;
        errdefer control.deinit(allocator);
        try control.ensureTotalCapacity(allocator, wire.central_file_header_len);
        return .{
            .allocator = allocator,
            .options = options,
            .control = control,
            .history = history,
        };
    }

    /// Reuses history, control, and entry-list allocations for another archive.
    pub fn reset(self: *Self) void {
        self.resetWithOptions(self.options) catch unreachable;
    }

    pub fn resetWithOptions(self: *Self, options: Options) Error!void {
        try validateOptions(options);
        if (self.current_encryption) |*encryption| encryption.deinit();
        if (self.current_state) |*state| state.deinit();
        self.directory.reset(self.allocator);
        if (self.archive_comment.len != 0) self.allocator.free(self.archive_comment);
        self.options = options;
        self.phase = .record_signature;
        self.control.clearRetainingCapacity();
        self.control_target = 4;
        self.record_offset = 0;
        self.current_index = null;
        self.current_state = null;
        self.current_encryption = null;
        self.descriptor_parser.reset();
        self.total_input = 0;
        self.total_output = 0;
        self.zip64_end = null;
        self.zip64_end_offset = 0;
        self.zip64_locator_seen = false;
        self.digital_signature_seen = false;
        self.archive_comment = &.{};
        self.last_error_name = "";
    }

    pub fn deinit(self: *Self) void {
        if (self.current_encryption) |*encryption| encryption.deinit();
        if (self.current_state) |*state| state.deinit();
        self.directory.deinit(self.allocator);
        self.control.deinit(self.allocator);
        self.allocator.free(self.history);
        if (self.archive_comment.len != 0) self.allocator.free(self.archive_comment);
        self.* = undefined;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .completed_entries = self.directory.completed_entries,
            .retained_entries = self.directory.records.items.len,
            .retained_metadata_size = self.directory.retained_metadata_size,
            .central_entries = self.directory.central_entries,
            .central_offset = if (self.directory.central_started) self.directory.central_offset else null,
            .central_size = if (self.directory.central_started and self.phase != .central_fixed and self.phase != .central_variable) self.directory.central_size else null,
            .current_entry = self.currentEntry(),
            .last_error_name = self.last_error_name,
        };
    }

    pub fn currentEntry(self: *const Self) ?EntryInfo {
        const index = self.current_index orelse return null;
        return self.directory.records.items[index].info();
    }

    pub fn archiveComment(self: *const Self) []const u8 {
        return self.archive_comment;
    }

    pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .frame_input_read = self.total_input,
            .output_written = self.total_output,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.phase),
            .recoverability_hint_name = if (self.phase == .failed) "archive_corrupt" else "none",
        };
    }

    pub fn finish(self: *Self) Error!void {
        if (self.phase == .failed) return error.ZipReaderFailed;
        if (self.phase == .done) return;
        self.phase = .failed;
        self.last_error_name = @errorName(error.TruncatedFrame);
        return error.TruncatedFrame;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!StepResult {
        if (self.phase == .failed) return error.ZipReaderFailed;
        if (self.phase == .done) {
            if (input.len != 0 and !self.options.allow_trailing_data)
                return error.TrailingData;
            return .{ .status = .done };
        }
        return self.stepInner(input, output) catch |err| {
            self.phase = .failed;
            self.last_error_name = @errorName(err);
            return err;
        };
    }

    fn stepInner(self: *Self, input: []const u8, output: []u8) Error!StepResult {
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .record_signature => {
                if (self.control.items.len == 0) {
                    self.record_offset = try self.absoluteOffset();
                    self.control_target = 4;
                }
                try self.fillControl(input, &input_read);
                if (self.control.items.len != 4)
                    return result(input_read, output_written, .need_input);
                const signature = std.mem.readInt(u32, self.control.items[0..4], .little);
                switch (signature) {
                    wire.local_file_signature => {
                        if (self.directory.central_started or self.zip64_end != null)
                            return error.InvalidZipArchive;
                        self.phase = .local_fixed;
                        try self.setControlTarget(wire.local_file_header_len);
                    },
                    wire.central_file_signature => {
                        if (self.zip64_end != null) return error.InvalidZipArchive;
                        if (!self.directory.central_started) {
                            self.directory.central_started = true;
                            self.directory.central_offset = self.record_offset;
                        }
                        self.phase = .central_fixed;
                        try self.setControlTarget(wire.central_file_header_len);
                    },
                    wire.zip64_end_of_central_signature => {
                        if (self.zip64_end != null or self.zip64_locator_seen)
                            return error.InvalidZipArchive;
                        try self.directory.beginEnding(
                            self.record_offset,
                            self.options.max_central_directory_size,
                        );
                        self.zip64_end_offset = self.record_offset;
                        self.phase = .zip64_end_prefix;
                        try self.setControlTarget(12);
                    },
                    wire.zip64_end_of_central_locator_signature => {
                        if (self.zip64_end == null or self.zip64_locator_seen)
                            return error.InvalidZipArchive;
                        self.phase = .zip64_locator;
                        try self.setControlTarget(wire.zip64_end_of_central_locator_len);
                    },
                    wire.central_directory_digital_signature => {
                        if (self.digital_signature_seen or self.zip64_end != null or self.zip64_locator_seen)
                            return error.InvalidZipArchive;
                        try self.directory.beginEnding(
                            self.record_offset,
                            self.options.max_central_directory_size,
                        );
                        self.phase = .digital_signature_fixed;
                        try self.setControlTarget(wire.central_directory_digital_signature_len);
                    },
                    wire.end_of_central_signature => {
                        try self.directory.beginEnding(
                            self.record_offset,
                            self.options.max_central_directory_size,
                        );
                        self.phase = .end_fixed;
                        try self.setControlTarget(wire.end_of_central_len);
                    },
                    else => return error.InvalidZipArchive,
                }
            },
            .local_fixed => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != wire.local_file_header_len)
                    return result(input_read, output_written, .need_input);
                const fixed: *const [wire.local_file_header_len]u8 = self.control.items[0..wire.local_file_header_len];
                self.phase = .local_variable;
                try self.setControlTarget(try archive_records.localEncodedLen(fixed));
            },
            .local_variable => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != self.control_target)
                    return result(input_read, output_written, .need_input);
                try self.startEntry(try archive_records.parseLocal(self.control.items));
                self.clearControl();
                self.phase = .entry_data;
                return result(input_read, output_written, .entry_header);
            },
            .entry_data => {
                var entry_input_read: usize = 0;
                var entry_output_written: usize = 0;
                const status = try self.stepEntryData(
                    input[input_read..],
                    output[output_written..],
                    &entry_input_read,
                    &entry_output_written,
                );
                input_read = try checkedAdd(input_read, entry_input_read);
                output_written = try checkedAdd(output_written, entry_output_written);
                if (status) |finished_status|
                    return result(input_read, output_written, finished_status);
                if (input_read == input.len)
                    return result(input_read, output_written, .need_input);
            },
            .entry_descriptor => {
                const parsed = try self.descriptor_parser.step(input[input_read..]);
                input_read = try checkedAdd(input_read, parsed.input_read);
                self.total_input = try checkedAdd(self.total_input, parsed.input_read);
                if (parsed.boundary) |boundary| {
                    const descriptor_value = boundary.descriptor;
                    var record = &self.directory.records.items[self.current_index.?];
                    record.crc32 = descriptor_value.crc32;
                    record.compressed_size = try u64ToUsize(descriptor_value.compressed_size);
                    record.uncompressed_size = try u64ToUsize(descriptor_value.uncompressed_size);
                    const prefix = boundary.retainedRecordPrefix();
                    if (prefix.len != 0) try self.prepareRecordPrefix(prefix);
                    try self.completeCurrentEntry();
                    return result(input_read, output_written, .entry_done);
                }
                return result(input_read, output_written, .need_input);
            },
            .central_fixed => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != wire.central_file_header_len)
                    return result(input_read, output_written, .need_input);
                const fixed: *const [wire.central_file_header_len]u8 = self.control.items[0..wire.central_file_header_len];
                self.phase = .central_variable;
                try self.setControlTarget(try archive_records.centralEncodedLen(fixed));
            },
            .central_variable => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != self.control_target)
                    return result(input_read, output_written, .need_input);
                try self.directory.validateCentral(
                    try archive_records.parseCentral(self.control.items),
                    try self.absoluteOffset(),
                    self.options.max_central_directory_size,
                );
                self.clearControl();
                self.phase = .record_signature;
            },
            .zip64_end_prefix => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != 12)
                    return result(input_read, output_written, .need_input);
                self.phase = .zip64_end;
                try self.setControlTarget(try archive_records.zip64EndEncodedLen(self.control.items[0..12]));
            },
            .zip64_end => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != self.control_target)
                    return result(input_read, output_written, .need_input);
                const parsed = try archive_records.parseZip64End(self.control.items);
                try self.directory.validateZip64End(parsed);
                self.zip64_end = parsed;
                self.clearControl();
                self.phase = .record_signature;
            },
            .zip64_locator => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != wire.zip64_end_of_central_locator_len)
                    return result(input_read, output_written, .need_input);
                const parsed = try archive_records.parseZip64Locator(self.control.items[0..wire.zip64_end_of_central_locator_len]);
                if (parsed.disk != 0 or parsed.disk_count != 1 or
                    parsed.end_offset != self.zip64_end_offset)
                    return error.UnsupportedZipFeature;
                self.zip64_locator_seen = true;
                self.clearControl();
                self.phase = .record_signature;
            },
            .digital_signature_fixed => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != wire.central_directory_digital_signature_len)
                    return result(input_read, output_written, .need_input);
                const payload_len: usize = std.mem.readInt(u16, self.control.items[4..6], .little);
                self.phase = .digital_signature;
                try self.setControlTarget(try checkedAdd(
                    wire.central_directory_digital_signature_len,
                    payload_len,
                ));
            },
            .digital_signature => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != self.control_target)
                    return result(input_read, output_written, .need_input);
                self.digital_signature_seen = true;
                self.clearControl();
                self.phase = .record_signature;
            },
            .end_fixed => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != wire.end_of_central_len)
                    return result(input_read, output_written, .need_input);
                self.phase = .end_comment;
                try self.setControlTarget(try archive_records.endEncodedLen(self.control.items[0..wire.end_of_central_len]));
            },
            .end_comment => {
                try self.fillControl(input, &input_read);
                if (self.control.items.len != self.control_target)
                    return result(input_read, output_written, .need_input);
                const parsed = try archive_records.parseEnd(self.control.items);
                try self.directory.validateEnd(parsed, self.zip64_end, self.zip64_locator_seen);
                if (parsed.comment.len > self.options.max_metadata_size -| self.directory.retained_metadata_size)
                    return error.OutputLimitExceeded;
                if (parsed.comment.len != 0) {
                    self.archive_comment = try self.allocator.dupe(u8, parsed.comment);
                    self.directory.retained_metadata_size += parsed.comment.len;
                }
                self.clearControl();
                self.phase = .done;
                if (input_read != input.len and !self.options.allow_trailing_data)
                    return error.TrailingData;
                return result(input_read, output_written, .done);
            },
            .done, .failed => unreachable,
        };
    }

    fn startEntry(self: *Self, local_value: archive_records.LocalHeader) Error!void {
        var local = local_value;
        if (self.directory.records.items.len == self.options.max_entries)
            return error.OutputLimitExceeded;
        const encrypted = local.flags & wire.encrypted_flag != 0;
        if (encrypted and local.flags & (1 << 6) != 0)
            return error.UnsupportedZipFeature;
        if (encrypted and local.descriptor_layout != null)
            return error.EncryptedZipEntry;
        const outer_compressed_size = local.compressed_size;
        var encryption_state: ?EncryptionState = null;
        errdefer if (encryption_state) |*state| state.deinit();
        if (encrypted) {
            const password = self.options.password orelse return error.PasswordRequired;
            const compressed_size = local.compressed_size orelse return error.InvalidZipArchive;
            if (compressed_size < traditional_encryption.header_len)
                return error.TruncatedZipEncryptionHeader;
            local.compressed_size = compressed_size - traditional_encryption.header_len;
            encryption_state = EncryptionState.init(
                password,
                @truncate(local.crc32.? >> 24),
            );
        }
        switch (local.method) {
            .stored => {},
            .shrink => if (local.version_needed < wire.version_10)
                return error.InvalidZipArchive,
            .reduce_1, .reduce_2, .reduce_3, .reduce_4 => if (local.version_needed < wire.version_10)
                return error.InvalidZipArchive,
            .implode => if (local.version_needed < wire.version_10)
                return error.InvalidZipArchive,
            .deflate => if (local.version_needed < wire.version_20)
                return error.InvalidZipArchive,
            .deflate64 => if (local.version_needed < wire.version_21)
                return error.InvalidZipArchive,
            .dcl_implode => if (local.version_needed < wire.version_20)
                return error.InvalidZipArchive,
            .bzip2 => if (local.version_needed < wire.version_46)
                return error.InvalidZipArchive,
            .lzma, .xz, .ppmd, .zstandard_legacy, .zstandard => if (local.version_needed < wire.version_63)
                return error.InvalidZipArchive,
            else => return error.UnsupportedZipCompressionMethod,
        }
        if (local.name.len > self.options.max_metadata_size -| self.directory.retained_metadata_size)
            return error.OutputLimitExceeded;
        const name = try self.allocator.dupe(u8, local.name);
        errdefer self.allocator.free(name);
        try self.directory.records.ensureUnusedCapacity(self.allocator, 1);

        const entry_limit = @min(
            self.options.max_entry_output_len,
            self.options.max_total_output_len -| self.total_output,
        );
        const state: EntryState = if (local.descriptor_layout) |layout|
            switch (local.method) {
                .stored => .{ .stored_descriptor = descriptor.StoredScanner.init(layout, entry_limit) },
                .shrink => .{ .shrink = try codecs.ShrinkState.init(
                    self.allocator,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    layout,
                ) },
                .reduce_1, .reduce_2, .reduce_3, .reduce_4 => .{ .reduce = try codecs.ReduceState.init(
                    self.allocator,
                    reduceFactor(local.method).?,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    layout,
                ) },
                .implode => .{ .implode = try codecs.ImplodeState.init(
                    self.allocator,
                    local.flags,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    layout,
                ) },
                .deflate => .{ .deflate_descriptor = try codecs.DeflateState.init(
                    entry_limit,
                    self.history,
                    layout,
                ) },
                .deflate64 => .{ .deflate64 = try codecs.Deflate64State.init(
                    self.allocator,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    layout,
                ) },
                .dcl_implode => .{ .dcl_implode = codecs.DclImplodeState.init(
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    layout,
                ) },
                .bzip2 => .{ .bzip2 = codecs.Bzip2State.init(
                    self.allocator,
                    self.options,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    layout,
                ) },
                .lzma => .{ .lzma = try codecs.LzmaZipState.init(
                    self.allocator,
                    self.options,
                    entry_limit,
                    local.flags,
                    local.compressed_size,
                    local.uncompressed_size,
                    layout,
                ) },
                .ppmd => .{ .ppmd = codecs.PpmdZipState.init(
                    self.allocator,
                    self.options,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    layout,
                ) },
                .xz => .{ .xz = codecs.XzState.init(
                    self.allocator,
                    self.options,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    layout,
                ) },
                .zstandard_legacy, .zstandard => .{ .zstd = codecs.ZstdState.init(
                    self.allocator,
                    self.options,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    layout,
                ) },
                else => unreachable,
            }
        else blk: {
            if (local.method == .implode)
                break :blk .{ .implode = try codecs.ImplodeState.init(
                    self.allocator,
                    local.flags,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    null,
                ) };
            if (reduceFactor(local.method)) |factor|
                break :blk .{ .reduce = try codecs.ReduceState.init(
                    self.allocator,
                    factor,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    null,
                ) };
            if (local.method == .shrink)
                break :blk .{ .shrink = try codecs.ShrinkState.init(
                    self.allocator,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    null,
                ) };
            if (local.method == .bzip2)
                break :blk .{ .bzip2 = codecs.Bzip2State.init(
                    self.allocator,
                    self.options,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    null,
                ) };
            if (local.method == .deflate64)
                break :blk .{ .deflate64 = try codecs.Deflate64State.init(
                    self.allocator,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    null,
                ) };
            if (local.method == .dcl_implode)
                break :blk .{ .dcl_implode = codecs.DclImplodeState.init(
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    null,
                ) };
            if (local.method == .lzma)
                break :blk .{ .lzma = try codecs.LzmaZipState.init(
                    self.allocator,
                    self.options,
                    entry_limit,
                    local.flags,
                    local.compressed_size,
                    local.uncompressed_size,
                    null,
                ) };
            if (local.method == .ppmd)
                break :blk .{ .ppmd = codecs.PpmdZipState.init(
                    self.allocator,
                    self.options,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    null,
                ) };
            if (local.method == .xz)
                break :blk .{ .xz = codecs.XzState.init(
                    self.allocator,
                    self.options,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    null,
                ) };
            if (local.method == .zstandard_legacy or local.method == .zstandard)
                break :blk .{ .zstd = codecs.ZstdState.init(
                    self.allocator,
                    self.options,
                    entry_limit,
                    local.compressed_size,
                    local.uncompressed_size,
                    null,
                ) };
            const synthetic: types.Entry = .{
                .name = name,
                .method = local.method,
                .flags = local.flags & ~wire.encrypted_flag,
                .crc32 = local.crc32.?,
                .compressed_size = local.compressed_size.?,
                .uncompressed_size = local.uncompressed_size.?,
                .local_header_offset = self.record_offset,
                .central_header_offset = 0,
                .zip64 = local.zip64,
            };
            break :blk .{ .known = try entry_decoder.Decoder.initWithOptions(
                synthetic,
                self.history,
                .{ .max_output_len = entry_limit },
            ) };
        };

        const record_index = self.directory.records.items.len;
        self.directory.records.appendAssumeCapacity(.{
            .name = name,
            .method = local.method,
            .flags = local.flags,
            .crc32 = local.crc32 orelse 0,
            .compressed_size = outer_compressed_size orelse 0,
            .uncompressed_size = local.uncompressed_size orelse 0,
            .local_header_offset = self.record_offset,
            .zip64_local = local.zip64,
            .uses_descriptor = local.descriptor_layout != null,
        });
        self.directory.retained_metadata_size += name.len;
        self.current_index = record_index;
        self.current_state = state;
        self.current_encryption = encryption_state;
        encryption_state = null;
        self.descriptor_parser.reset();
    }

    fn stepEntryData(
        self: *Self,
        input: []const u8,
        output: []u8,
        input_read: *usize,
        output_written: *usize,
    ) Error!?StepResult.Status {
        if (self.current_encryption == null)
            return self.stepEntryDataPlain(input, output, input_read, output_written);

        var encryption = &self.current_encryption.?;
        while (encryption.header_len < traditional_encryption.header_len and
            input_read.* < input.len)
        {
            encryption.header[encryption.header_len] = encryption.cipher.decryptByte(
                input[input_read.*],
            );
            encryption.header_len += 1;
            input_read.* += 1;
            self.total_input = try checkedAdd(self.total_input, 1);
        }
        if (encryption.header_len != traditional_encryption.header_len) return null;
        if (encryption.header[traditional_encryption.header_random_len] != encryption.check_byte)
            return error.InvalidZipPassword;
        if (input_read.* == input.len) return null;

        const raw_offset = input_read.*;
        const take = @min(input.len - raw_offset, 256);
        var decrypted: [256]u8 = undefined;
        defer std.crypto.secureZero(u8, &decrypted);
        var trial = encryption.cipher;
        defer trial.deinit();
        trial.decrypt(input[raw_offset..][0..take], decrypted[0..take]);
        var committed = encryption.cipher;
        defer committed.deinit();
        var decrypted_read: usize = 0;
        const status = try self.stepEntryDataPlain(
            decrypted[0..take],
            output,
            &decrypted_read,
            output_written,
        );
        input_read.* = try checkedAdd(input_read.*, decrypted_read);
        for (input[raw_offset..][0..decrypted_read]) |byte| _ = committed.decryptByte(byte);
        if (self.current_encryption) |*active| {
            active.cipher.deinit();
            active.cipher = committed;
        }
        return status;
    }

    fn stepEntryDataPlain(
        self: *Self,
        input: []const u8,
        output: []u8,
        input_read: *usize,
        output_written: *usize,
    ) Error!?StepResult.Status {
        const state = &self.current_state.?;
        switch (state.*) {
            .known => |*decoder_state| {
                const stepped = try decoder_state.step(input, output);
                try self.accountEntryProgress(stepped.progress, input_read, output_written);
                if (stepped.status == .done) {
                    try self.completeCurrentEntry();
                    return .entry_done;
                }
                if (stepped.status == .need_output) return .need_output;
                return null;
            },
            .stored_descriptor => |*scanner| {
                const stepped = try scanner.step(input, output);
                try self.accountEntryProgress(stepped.progress, input_read, output_written);
                if (stepped.status == .done) {
                    const parsed = scanner.descriptor().?;
                    var record = &self.directory.records.items[self.current_index.?];
                    record.crc32 = parsed.crc32;
                    record.compressed_size = try u64ToUsize(parsed.compressed_size);
                    record.uncompressed_size = try u64ToUsize(parsed.uncompressed_size);
                    const prefix = scanner.retainedRecordPrefix();
                    if (prefix.len != 0) try self.prepareRecordPrefix(prefix);
                    try self.completeCurrentEntry();
                    return .entry_done;
                }
                if (stepped.status == .need_output) return .need_output;
                return null;
            },
            .deflate_descriptor => |*codec_state| return try self.stepContainerCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
            .shrink => |*codec_state| return try self.stepScannedCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
            .reduce => |*codec_state| return try self.stepScannedCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
            .implode => |*codec_state| return try self.stepScannedCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
            .deflate64 => |*codec_state| return try self.stepContainerCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
            .dcl_implode => |*codec_state| return try self.stepContainerCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
            .bzip2 => |*codec_state| return try self.stepContainerCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
            .lzma => |*codec_state| return try self.stepContainerCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
            .ppmd => |*codec_state| return try self.stepContainerCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
            .xz => |*codec_state| return try self.stepContainerCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
            .zstd => |*codec_state| return try self.stepContainerCodec(
                codec_state,
                input,
                output,
                input_read,
                output_written,
            ),
        }
    }

    fn stepContainerCodec(
        self: *Self,
        state: anytype,
        input: []const u8,
        output: []u8,
        input_read: *usize,
        output_written: *usize,
    ) Error!?StepResult.Status {
        const stepped = try state.step(input, output);
        try self.accountEntryProgress(stepped.progress, input_read, output_written);
        if (stepped.status == .done) return try self.finishContainerCodec(state);
        if (stepped.status == .need_output) return .need_output;
        return null;
    }

    fn stepScannedCodec(
        self: *Self,
        state: anytype,
        input: []const u8,
        output: []u8,
        input_read: *usize,
        output_written: *usize,
    ) Error!?StepResult.Status {
        const stepped = try state.step(input, output);
        try self.accountEntryProgress(stepped.progress, input_read, output_written);
        if (stepped.status == .done) {
            if (state.layout() != null) {
                const parsed = state.descriptorValue() orelse
                    return error.InvalidZipArchive;
                var record = &self.directory.records.items[self.current_index.?];
                record.crc32 = parsed.crc32;
                record.compressed_size = try u64ToUsize(parsed.compressed_size);
                record.uncompressed_size = try u64ToUsize(parsed.uncompressed_size);
                const prefix = state.retainedRecordPrefix();
                if (prefix.len != 0) try self.prepareRecordPrefix(prefix);
                try self.completeCurrentEntry();
            } else {
                try self.validateKnownCodec(
                    state.crc32(),
                    state.actualCompressedSize(),
                    state.outputSize(),
                    &.{},
                );
            }
            return .entry_done;
        }
        if (stepped.status == .need_output) return .need_output;
        return null;
    }

    fn finishContainerCodec(self: *Self, state: anytype) Error!?StepResult.Status {
        const trailing = state.trailingInput();
        const compressed_size = try state.actualCompressedSize();
        if (state.layout()) |layout| {
            try self.beginDescriptor(
                layout,
                state.crc32(),
                compressed_size,
                state.outputSize(),
                trailing,
            );
            return null;
        }
        try self.validateKnownCodec(
            state.crc32(),
            compressed_size,
            state.outputSize(),
            trailing,
        );
        return .entry_done;
    }

    fn validateKnownCodec(
        self: *Self,
        crc32: u32,
        compressed_size: usize,
        uncompressed_size: usize,
        trailing: []const u8,
    ) Error!void {
        if (trailing.len != 0) return error.InvalidZipArchive;
        const record = &self.directory.records.items[self.current_index.?];
        const outer_compressed_size = try checkedAdd(
            compressed_size,
            if (self.current_encryption != null) traditional_encryption.header_len else 0,
        );
        if (record.compressed_size != outer_compressed_size or record.uncompressed_size != uncompressed_size)
            return error.SizeMismatch;
        if (record.crc32 != crc32) return error.ChecksumMismatch;
        try self.completeCurrentEntry();
    }

    fn beginDescriptor(
        self: *Self,
        layout: descriptor.Layout,
        crc32: u32,
        compressed_size: usize,
        uncompressed_size: usize,
        buffered_suffix: []const u8,
    ) Error!void {
        try self.descriptor_parser.begin(
            layout,
            crc32,
            compressed_size,
            uncompressed_size,
            buffered_suffix,
        );
        self.phase = .entry_descriptor;
    }

    fn completeCurrentEntry(self: *Self) Error!void {
        const index = self.current_index orelse return error.InvalidZipArchive;
        try self.directory.complete(index);
        if (self.current_encryption) |*encryption| encryption.deinit();
        self.current_encryption = null;
        if (self.current_state) |*state| state.deinit();
        self.current_state = null;
        if (self.phase != .record_signature) {
            self.phase = .record_signature;
            if (self.control.items.len == 0) self.control_target = 4;
        }
    }

    fn accountEntryProgress(
        self: *Self,
        progress: core.Progress,
        input_read: *usize,
        output_written: *usize,
    ) Error!void {
        input_read.* = try checkedAdd(input_read.*, progress.input_read);
        output_written.* = try checkedAdd(output_written.*, progress.output_written);
        self.total_input = try checkedAdd(self.total_input, progress.input_read);
        self.total_output = try checkedAdd(self.total_output, progress.output_written);
        if (self.total_output > self.options.max_total_output_len)
            return error.OutputLimitExceeded;
    }

    fn fillControl(self: *Self, input: []const u8, input_read: *usize) Error!void {
        const needed = self.control_target - self.control.items.len;
        const take = @min(needed, input.len - input_read.*);
        if (take == 0) return;
        try self.control.appendSlice(self.allocator, input[input_read.*..][0..take]);
        input_read.* += take;
        self.total_input = try checkedAdd(self.total_input, take);
        if (self.directory.central_started and
            (self.phase == .central_fixed or self.phase == .central_variable) and
            (try self.absoluteOffset()) - self.directory.central_offset > self.options.max_central_directory_size)
            return error.OutputLimitExceeded;
    }

    fn setControlTarget(self: *Self, target: usize) Error!void {
        if (target < self.control.items.len or target > self.options.max_control_record_size)
            return error.OutputLimitExceeded;
        self.control_target = target;
        try self.control.ensureTotalCapacity(self.allocator, target);
    }

    fn clearControl(self: *Self) void {
        self.control.clearRetainingCapacity();
        self.control_target = 4;
    }

    fn prepareRecordPrefix(self: *Self, prefix: []const u8) Error!void {
        std.debug.assert(prefix.len == 4);
        self.clearControl();
        try self.control.appendSlice(self.allocator, prefix);
        self.record_offset = (try self.absoluteOffset()) - prefix.len;
        self.phase = .record_signature;
    }

    fn absoluteOffset(self: *const Self) Error!usize {
        return checkedAdd(self.options.initial_offset, self.total_input);
    }

    fn result(input_read: usize, output_written: usize, status: StepResult.Status) StepResult {
        return .{
            .progress = .{ .input_read = input_read, .output_written = output_written },
            .status = status,
        };
    }
};

fn u64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.UnsupportedZipFeature;
}

fn reduceFactor(method: CompressionMethod) ?codecs.ReduceFactor {
    return switch (method) {
        .reduce_1 => .factor_1,
        .reduce_2 => .factor_2,
        .reduce_3 => .factor_3,
        .reduce_4 => .factor_4,
        else => null,
    };
}

fn checkedAdd(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn validateOptions(options: Options) Error!void {
    if (options.max_control_record_size < wire.central_file_header_len)
        return error.OutputLimitExceeded;
}

test {
    _ = descriptor;
    _ = archive_records;
    _ = @import("incremental_reader_tests.zig");
}
