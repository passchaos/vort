const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const codecs = @import("incremental_writer/codecs.zig");
const writer_encryption = @import("incremental_writer/encryption.zig");
const pkware_strong = @import("pkware_strong.zig");
const types = @import("types.zig");
const traditional_encryption = @import("vail_archive_crypto").zipcrypto;
const winzip_aes = @import("vail_archive_crypto").winzip_aes;
const wire = @import("wire.zig");
const zip_writer = @import("writer.zig");
const zstd = @import("../zstd.zig");

pub const CompressionMethod = types.CompressionMethod;
pub const CreatorSystem = types.CreatorSystem;
pub const DosTimestamp = types.DosTimestamp;
pub const ExtendedTimestamp = types.ExtendedTimestamp;
pub const NtfsTimestamp = types.NtfsTimestamp;
pub const Zip64Mode = zip_writer.Zip64Mode;

pub const Error = codecs.Error || writer_encryption.Error || std.mem.Allocator.Error || error{
    InvalidZipEntryName,
    InvalidZipTextEncoding,
    InvalidZipTimestamp,
    UnsupportedZipCompressionMethod,
    Zip32LimitExceeded,
    InvalidZipWriterState,
    ZipWriterPoisoned,
    ConflictingZipEncryption,
};

/// Archive-wide limits and deterministic encoding options.
///
/// `archive_comment` is copied by `initWithOptions`; callers may release or
/// mutate it as soon as initialization returns. `initial_offset` is the number
/// of bytes preceding this archive (for example, a self-extracting prefix).
pub const Options = struct {
    archive_comment: []const u8 = "",
    archive_extra_data: []const u8 = "",
    initial_offset: u64 = 0,
    utf8: bool = true,
    zip64: Zip64Mode = .auto,
    deflate_options: codecs.DeflateOptions = .{},
    /// Maximum input bytes retained for one Deflate planning block, including
    /// lookahead but excluding the fixed 32 KiB history and encoded output.
    max_deflate_buffer_size: usize = 1024 * 1024,
    /// Deflate64 matching policy, total-input and pending-output limits.
    /// Defaults use adaptive fixed/stored blocks with a 128 KiB planning block.
    deflate64_options: codecs.Deflate64Options = .{},
    /// DCL Implode literal/dictionary/matcher policy plus total-input limit.
    dcl_implode_options: codecs.DclImplodeOptions = .{},
    /// Traditional Implode dictionary/literal-tree/matcher and input policy.
    implode_options: codecs.ImplodeOptions = .{},
    /// Bzip2 block size, total-input limit, and pending encoded-output limit.
    bzip2_options: codecs.Bzip2Options = .{},
    /// Zstandard block/window/parser policy. Content-size signaling is derived
    /// from each entry's `expected_size`.
    zstd_options: codecs.ZstdOptions = .{},
    /// Explicit persistent parallel Zstandard policy. Null retains serial
    /// encoding; content-size signaling still follows each entry's pledge.
    zstd_parallel_options: ?codecs.ZstdParallelOptions = null,
    /// Borrowed preset history used by every Zstandard entry. The descriptor
    /// and its bytes must remain stable until `deinit`.
    zstd_dictionary: ?zstd.NativeDictionary = null,
    /// ZIP LZMA properties/dictionary/buffering policy. Method 14 always uses
    /// an end marker; `size_mode` is normalized accordingly.
    lzma_options: codecs.LzmaOptions = .{},
    /// XZ check, block, dictionary, parser, and filter-chain policy. Filters
    /// are copied by initialization and need not outlive the writer.
    xz_options: codecs.XzOptions = .{},
    /// PPMd order/model/restoration plus total-input and pending-output limits.
    ppmd_options: codecs.PpmdOptions = .{},
    /// Shrink input and pending-output limits. The current deterministic
    /// encoder grows through 13 bits and freezes a full dictionary.
    shrink_options: codecs.ShrinkOptions = .{},
    /// Reduce matcher/input policy and optional pre-trained follower table.
    reduce_options: codecs.ReduceOptions = .{},
    max_entries: u64 = std.math.maxInt(u64),
    max_central_directory_size: usize = std.math.maxInt(usize),
    max_uncompressed_size: u64 = std.math.maxInt(u64),
    max_archive_size: u64 = std.math.maxInt(u64),
    /// Return before emitting the next control-record class. This is used by
    /// the split-volume adapter; ordinary callers should keep the default.
    stop_at_record_boundaries: bool = false,
};

/// Metadata for one streaming entry. Every incremental writer method is accepted.
///
/// `name` and `comment` are copied by `beginEntry` and need not remain alive
/// afterward. A non-null `expected_size` is checked when input is accepted and
/// again by `finishEntry` before finalization is requested.
pub const EntryOptions = struct {
    name: []const u8,
    comment: []const u8 = "",
    unicode_name: ?[]const u8 = null,
    unicode_comment: ?[]const u8 = null,
    method: CompressionMethod = .deflate,
    expected_size: ?u64 = null,
    /// Validated MS-DOS modification time; defaults preserve deterministic wire.
    modified: DosTimestamp = .deterministic,
    extended_timestamp: ?ExtendedTimestamp = null,
    ntfs_timestamp: ?NtfsTimestamp = null,
    creator_system: CreatorSystem = .fat,
    internal_attributes: u16 = 0,
    /// Null derives only the conventional DOS directory bit from a trailing `/`.
    external_attributes: ?u32 = null,
    traditional_encryption: ?traditional_encryption.Options = null,
    winzip_aes: ?zip_writer.WinZipAesOptions = null,
    pkware_strong_encryption: ?zip_writer.PkwareStrongEncryptionOptions = null,
};

pub const Phase = enum {
    ready,
    entry_header,
    entry_data,
    entry_descriptor,
    central_directory,
    archive_end,
    done,
    poisoned,
};

/// Resumable ZIP archive writer. A complete payload and already-emitted archive
/// bytes are never retained. Central-directory bytes are retained until
/// `finishArchive`; Deflate additionally keeps one bounded planning block,
/// history/match state, and one encoded pending block. Deflate64 retains one
/// configured planning block, 64 KiB history, and bounded encoded output.
/// Bzip2 retains at most one configured RLE/BWT block plus bounded encoded output.
/// Zstandard retains
/// one configured frame block, bounded rolling history, and pending output.
/// LZMA retains bounded input/lookahead, dictionary history, and range output.
/// XZ retains one configured plaintext block, encoded output, and Index records.
/// PPMd retains one explicitly bounded model arena and pending range bytes.
pub const Writer = struct {
    allocator: std.mem.Allocator,
    options: Options,
    archive_comment: []u8,
    xz_filters: []codecs.XzFilter,
    phase: Phase = .ready,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    central: std.ArrayList(u8) = .empty,
    central_offset: usize = 0,
    current: ?CurrentEntry = null,
    archive_output: u64 = 0,
    total_input: u64 = 0,
    entry_count: u64 = 0,
    any_zip64_entry: bool = false,
    final_central_offset: u64 = 0,
    final_central_size: u64 = 0,
    final_archive_zip64: bool = false,
    finish_entry_requested: bool = false,
    finish_archive_requested: bool = false,

    const Self = @This();
    const CurrentEntry = struct {
        metadata: []u8,
        name_len: usize,
        comment_len: usize,
        unicode_name_len: usize,
        unicode_comment_len: usize,
        method: CompressionMethod,
        expected_size: ?u64,
        local_header_offset: u64,
        zip64: bool,
        modified: DosTimestamp,
        extended_timestamp: ?ExtendedTimestamp,
        ntfs_timestamp: ?NtfsTimestamp,
        creator_system: CreatorSystem,
        internal_attributes: u16,
        external_attributes: ?u32,
        crc: checksum.Crc32Best = checksum.Crc32Best.init(),
        uncompressed_size: u64 = 0,
        compressed_size: u64 = 0,
        codec: codecs.State,
        encryption: ?writer_encryption.State = null,

        fn init(
            allocator: std.mem.Allocator,
            entry_options: EntryOptions,
            local_header_offset: u64,
            zip64: bool,
            codec_options: codecs.Options,
        ) Error!CurrentEntry {
            var codec = try codecs.State.init(
                allocator,
                entry_options.method,
                entry_options.expected_size,
                codec_options,
            );
            errdefer codec.deinit();
            const unicode_name = entry_options.unicode_name orelse "";
            const unicode_comment = entry_options.unicode_comment orelse "";
            const metadata_len = std.math.add(
                usize,
                try checkedAdd(entry_options.name.len, entry_options.comment.len),
                try checkedAdd(unicode_name.len, unicode_comment.len),
            ) catch return error.IntegerOverflow;
            const metadata = try allocator.alloc(u8, metadata_len);
            errdefer allocator.free(metadata);
            var metadata_offset: usize = 0;
            inline for (.{
                entry_options.name,
                entry_options.comment,
                unicode_name,
                unicode_comment,
            }) |value| {
                @memcpy(metadata[metadata_offset..][0..value.len], value);
                metadata_offset += value.len;
            }
            const encryption = if (entry_options.traditional_encryption) |options|
                writer_encryption.State.initTraditional(options, entry_options.modified.time)
            else if (entry_options.winzip_aes) |options|
                try writer_encryption.State.initWinZipAes(options)
            else if (entry_options.pkware_strong_encryption) |options|
                try writer_encryption.State.initPkwareStrong(allocator, options)
            else
                null;
            return .{
                .metadata = metadata,
                .name_len = entry_options.name.len,
                .comment_len = entry_options.comment.len,
                .unicode_name_len = unicode_name.len,
                .unicode_comment_len = unicode_comment.len,
                .method = entry_options.method,
                .expected_size = entry_options.expected_size,
                .local_header_offset = local_header_offset,
                .zip64 = zip64,
                .modified = entry_options.modified,
                .extended_timestamp = entry_options.extended_timestamp,
                .ntfs_timestamp = entry_options.ntfs_timestamp,
                .creator_system = entry_options.creator_system,
                .internal_attributes = entry_options.internal_attributes,
                .external_attributes = entry_options.external_attributes,
                .codec = codec,
                .compressed_size = if (encryption) |*state| state.header().len else 0,
                .encryption = encryption,
            };
        }

        fn name(self: *const CurrentEntry) []const u8 {
            return self.metadata[0..self.name_len];
        }

        fn comment(self: *const CurrentEntry) []const u8 {
            return self.metadata[self.name_len..][0..self.comment_len];
        }

        fn unicodeName(self: *const CurrentEntry) ?[]const u8 {
            if (self.unicode_name_len == 0) return null;
            const offset = self.name_len + self.comment_len;
            return self.metadata[offset..][0..self.unicode_name_len];
        }

        fn unicodeComment(self: *const CurrentEntry) ?[]const u8 {
            if (self.unicode_comment_len == 0) return null;
            const offset = self.name_len + self.comment_len + self.unicode_name_len;
            return self.metadata[offset..][0..self.unicode_comment_len];
        }

        fn encryptionFlag(self: *const CurrentEntry) u16 {
            if (self.encryption) |encryption|
                return wire.encrypted_flag |
                    (if (std.meta.activeTag(encryption) == .pkware_strong)
                        wire.strong_encryption_flag
                    else
                        0);
            return 0;
        }

        fn appendEncryptionHeader(
            self: *const CurrentEntry,
            allocator: std.mem.Allocator,
            output: *std.ArrayList(u8),
        ) Error!void {
            if (self.encryption) |*encryption|
                try output.appendSlice(allocator, encryption.header());
        }

        fn encryptOutput(self: *CurrentEntry, output: []u8) void {
            if (self.encryption) |*encryption| encryption.encryptInPlace(output);
        }

        fn deinit(self: *CurrentEntry, allocator: std.mem.Allocator) void {
            if (self.encryption) |*encryption| encryption.deinit(allocator);
            self.codec.deinit();
            allocator.free(self.metadata);
            self.* = undefined;
        }
    };

    pub const Snapshot = struct {
        phase: Phase,
        input_read: u64,
        output_written: u64,
        current_uncompressed_size: u64,
        current_compressed_size: u64,
        pending_output: usize,
        central_metadata_size: usize,
        entry_count: u64,
        finish_entry_requested: bool,
        finish_archive_requested: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
        if (options.archive_comment.len > std.math.maxInt(u16)) return error.Zip32LimitExceeded;
        if (options.archive_extra_data.len > std.math.maxInt(u32))
            return error.Zip32LimitExceeded;
        if (options.zip64 == .never and options.initial_offset >= std.math.maxInt(u32))
            return error.Zip32LimitExceeded;
        const comment = try allocator.dupe(u8, options.archive_comment);
        errdefer allocator.free(comment);
        const xz_filters = try allocator.dupe(codecs.XzFilter, options.xz_options.filters);
        errdefer allocator.free(xz_filters);
        const max_end_len = try checkedAdd(
            wire.zip64_end_of_central_len + wire.zip64_end_of_central_locator_len + wire.end_of_central_len,
            options.archive_comment.len,
        );
        var pending: std.ArrayList(u8) = .empty;
        errdefer pending.deinit(allocator);
        try pending.ensureTotalCapacity(allocator, max_end_len);
        var central: std.ArrayList(u8) = .empty;
        errdefer central.deinit(allocator);
        try wire.appendArchiveExtraData(
            allocator,
            &central,
            options.archive_extra_data,
        );
        if (central.items.len > options.max_central_directory_size)
            return error.OutputLimitExceeded;
        var owned_options = options;
        owned_options.archive_comment = "";
        owned_options.archive_extra_data = "";
        owned_options.xz_options.filters = xz_filters;
        return .{
            .allocator = allocator,
            .options = owned_options,
            .archive_comment = comment,
            .xz_filters = xz_filters,
            .pending = pending,
            .central = central,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.current) |*entry| entry.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.central.deinit(self.allocator);
        self.allocator.free(self.archive_comment);
        self.allocator.free(self.xz_filters);
        self.* = undefined;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        const uncompressed_size = if (self.current) |entry| entry.uncompressed_size else 0;
        const compressed_size = if (self.current) |entry| entry.compressed_size else 0;
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.archive_output,
            .current_uncompressed_size = uncompressed_size,
            .current_compressed_size = compressed_size,
            .pending_output = self.pending.items.len - self.pending_offset,
            .central_metadata_size = self.central.items.len,
            .entry_count = self.entry_count,
            .finish_entry_requested = self.finish_entry_requested,
            .finish_archive_requested = self.finish_archive_requested,
        };
    }

    /// Request a new entry. This copies its metadata and prepares the local
    /// header, but bytes are only published by `step`.
    pub fn beginEntry(self: *Self, entry_options: EntryOptions) Error!void {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        if (self.phase != .ready or self.finish_archive_requested) return error.InvalidZipWriterState;
        return self.beginEntryInner(entry_options);
    }

    fn beginEntryInner(self: *Self, entry_options: EntryOptions) Error!void {
        try self.validateEntry(entry_options);
        const next_count = std.math.add(u64, self.entry_count, 1) catch return error.IntegerOverflow;
        if (next_count > self.options.max_entries) return error.OutputLimitExceeded;
        if (self.options.zip64 == .never and next_count >= std.math.maxInt(u16))
            return error.Zip32LimitExceeded;

        const local_offset = std.math.add(
            u64,
            self.options.initial_offset,
            self.archive_output,
        ) catch return error.IntegerOverflow;
        const entry_zip64 = try self.chooseEntryZip64(entry_options, local_offset);
        const local_header_len = try checkedAdd(
            try checkedAdd(
                try checkedAdd(wire.local_file_header_len, entry_options.name.len),
                if (entry_zip64) 20 else 0,
            ),
            (if (entry_options.winzip_aes != null) @as(usize, 11) else 0) +
                wire.localTimestampExtraLen(
                    entry_options.extended_timestamp,
                    entry_options.ntfs_timestamp,
                ) + wire.unicodeExtraLen(entry_options.unicode_name),
        );
        const encryption_header_len = if (entry_options.traditional_encryption != null)
            traditional_encryption.header_len
        else if (entry_options.winzip_aes) |aes|
            aes.strength.saltLen() + winzip_aes.password_verifier_len
        else if (entry_options.pkware_strong_encryption) |strong|
            try pkware_strong.streamHeaderLen(strong)
        else
            0;
        const entry_prefix_len = try checkedAdd(
            local_header_len,
            encryption_header_len,
        );
        const descriptor_len = (if (entry_zip64)
            wire.zip64_data_descriptor_len
        else
            wire.data_descriptor_len) +
            (if (entry_options.winzip_aes != null) winzip_aes.authentication_code_len else 0);
        const central_header_len = try checkedAdd(
            try checkedAdd(
                try checkedAdd(wire.central_file_header_len, entry_options.name.len),
                entry_options.comment.len,
            ),
            (if (entry_zip64) @as(usize, 28) else 0) +
                (if (entry_options.winzip_aes != null) @as(usize, 11) else 0) +
                (if (entry_options.pkware_strong_encryption != null) @as(usize, 12) else 0) +
                wire.centralTimestampExtraLen(
                    entry_options.extended_timestamp,
                    entry_options.ntfs_timestamp,
                ) + wire.unicodeExtraLen(entry_options.unicode_name) +
                wire.unicodeExtraLen(entry_options.unicode_comment),
        );
        const local_extra_len = local_header_len - wire.local_file_header_len -
            entry_options.name.len;
        const central_extra_len = central_header_len - wire.central_file_header_len -
            entry_options.name.len - entry_options.comment.len;
        if (local_extra_len > std.math.maxInt(u16) or
            central_extra_len > std.math.maxInt(u16))
        {
            return error.Zip32LimitExceeded;
        }
        if (central_header_len > self.options.max_central_directory_size or
            self.central.items.len > self.options.max_central_directory_size - central_header_len)
            return error.OutputLimitExceeded;
        try self.checkArchiveAddition(entry_prefix_len);

        // Reserve every control record that depends on this entry before any
        // payload byte can be emitted. Capacity changes are harmless if one of
        // these transactional preparations fails; phase remains `ready`.
        try self.pending.ensureTotalCapacity(self.allocator, @max(entry_prefix_len, descriptor_len));
        try self.central.ensureUnusedCapacity(self.allocator, central_header_len);

        var current = try CurrentEntry.init(
            self.allocator,
            entry_options,
            local_offset,
            entry_zip64,
            self.codecOptions(),
        );
        errdefer current.deinit(self.allocator);
        errdefer {
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
        }
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        // Every incremental entry uses a descriptor. For a ZIP64 local header,
        // zero sizes deliberately produce two zero u64 placeholders in the
        // ZIP64 extra while the legacy fields remain 0xffffffff sentinels.
        try wire.appendLocalHeader(self.allocator, &self.pending, .{
            .name = current.name(),
            .comment = current.comment(),
            .unicode_name = current.unicodeName(),
            .unicode_comment = current.unicodeComment(),
            .method = current.method,
            .flags = wire.descriptor_flag | codecs.zipFlags(&current.codec) |
                current.encryptionFlag() |
                (if (self.options.utf8) wire.utf8_flag else 0),
            .crc32 = 0,
            .compressed_size = 0,
            .uncompressed_size = 0,
            .local_header_offset = local_offset,
            .zip64 = entry_zip64,
            .modified = current.modified,
            .extended_timestamp = current.extended_timestamp,
            .ntfs_timestamp = current.ntfs_timestamp,
            .creator_system = current.creator_system,
            .internal_attributes = current.internal_attributes,
            .external_attributes = current.external_attributes,
            .winzip_aes = if (current.encryption) |*encryption|
                encryption.aesInfo()
            else
                null,
            .pkware_strong_encryption = if (current.encryption) |*encryption|
                encryption.pkwareInfo()
            else
                null,
        }, .{ .zip64_size_placeholders = entry_zip64 });
        try current.appendEncryptionHeader(self.allocator, &self.pending);
        std.debug.assert(self.pending.items.len == entry_prefix_len);

        self.current = current;
        self.finish_entry_requested = false;
        self.phase = .entry_header;
    }

    /// Request the active entry's final codec block/footer and data descriptor.
    /// Continue calling `step` with empty input until it returns `.need_input`.
    pub fn finishEntry(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        if (self.phase != .entry_header and self.phase != .entry_data)
            return error.InvalidZipWriterState;
        if (self.finish_entry_requested) return error.InvalidZipWriterState;
        if (self.current.?.expected_size) |expected| {
            if (self.current.?.uncompressed_size != expected) return error.SizeMismatch;
        }
        self.finish_entry_requested = true;
    }

    /// Request the central directory and archive terminator. This is only valid
    /// after every entry descriptor has drained.
    pub fn finishArchive(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        if (self.phase != .ready or self.finish_archive_requested)
            return error.InvalidZipWriterState;
        try self.prepareArchiveFinish();
        self.finish_archive_requested = true;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        return self.stepInner(input, output) catch |err| {
            self.phase = .poisoned;
            return err;
        };
    }

    fn stepInner(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (output.len == 0) {
            if ((self.phase == .ready and !self.finish_archive_requested) or
                (self.phase == .entry_data and !self.finish_entry_requested and input.len == 0))
            {
                if (input.len != 0) return error.InvalidZipWriterState;
                return .{ .status = .need_input };
            }
            return .{ .status = .need_output };
        }

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            switch (self.phase) {
                .ready => {
                    if (input_read != input.len) return error.InvalidZipWriterState;
                    if (!self.finish_archive_requested)
                        return result(input_read, output_written, .need_input);
                    self.phase = .central_directory;
                    continue;
                },
                .entry_header, .entry_descriptor, .archive_end => {
                    const completed_phase = self.phase;
                    try self.drainPending(output, &output_written);
                    if (self.pending_offset != self.pending.items.len)
                        return result(input_read, output_written, .need_output);
                    self.pending.clearRetainingCapacity();
                    self.pending_offset = 0;
                    switch (self.phase) {
                        .entry_header => self.phase = .entry_data,
                        .entry_descriptor => self.phase = .ready,
                        .archive_end => {
                            self.phase = .done;
                            return result(input_read, output_written, .done);
                        },
                        else => unreachable,
                    }
                    if (self.options.stop_at_record_boundaries and
                        completed_phase != .archive_end)
                        return result(input_read, output_written, .need_input);
                    if (output_written == output.len) {
                        const status: core.StepResult.Status = if (self.phase == .ready and !self.finish_archive_requested)
                            .need_input
                        else
                            .need_output;
                        return result(input_read, output_written, status);
                    }
                    continue;
                },
                .entry_data => {
                    const uses_pkware_strong = if (self.current.?.encryption) |encryption|
                        std.meta.activeTag(encryption) == .pkware_strong
                    else
                        false;
                    if (uses_pkware_strong) {
                        if (try self.stepPkwareStrongEntry(
                            input,
                            output,
                            &input_read,
                            &output_written,
                        )) |step_result| return step_result;
                        continue;
                    }
                    if (self.finish_entry_requested) {
                        if (input_read != input.len) return error.TrailingData;
                        if (self.current.?.method == .stored) {
                            try self.finalizeEntry();
                            if (self.options.stop_at_record_boundaries)
                                return result(input_read, output_written, .need_output);
                            continue;
                        }
                        var entry = &self.current.?;
                        entry.codec.finish();
                        const codec_output = output[output_written..][0..self.limitArchiveWrite(output.len - output_written)];
                        if (codec_output.len == 0) return error.OutputLimitExceeded;
                        const encoded = entry.codec.step("", codec_output) catch |err| {
                            try self.accountFailedCodecProgress(entry, "", codec_output, &input_read, &output_written);
                            return err;
                        };
                        entry.encryptOutput(codec_output[0..encoded.progress.output_written]);
                        try self.accountCodecProgress(entry, "", encoded.progress, &input_read, &output_written);
                        if (encoded.status == .done) {
                            try self.finalizeEntry();
                            if (self.options.stop_at_record_boundaries)
                                return result(input_read, output_written, .need_output);
                            continue;
                        }
                        if (encoded.status == .need_output or output_written == output.len)
                            return result(input_read, output_written, .need_output);
                        return error.InvalidBlockPlan;
                    }

                    if (input_read == input.len)
                        return result(input_read, output_written, .need_input);
                    try self.checkInputOffer(input[input_read..].len);
                    var entry = &self.current.?;
                    if (entry.method == .stored) {
                        const wanted = @min(input.len - input_read, output.len - output_written);
                        const take = self.limitArchiveWrite(wanted);
                        if (take == 0) return error.OutputLimitExceeded;
                        const bytes = input[input_read..][0..take];
                        @memcpy(output[output_written..][0..take], bytes);
                        entry.crc.update(bytes);
                        entry.encryptOutput(output[output_written..][0..take]);
                        try self.addEntryInput(entry, take);
                        try self.addArchiveOutput(take);
                        entry.compressed_size = std.math.add(u64, entry.compressed_size, @as(u64, @intCast(take))) catch
                            return error.IntegerOverflow;
                        input_read += take;
                        output_written += take;
                        if (input_read != input.len)
                            return result(input_read, output_written, .need_output);
                        return result(input_read, output_written, .need_input);
                    }

                    const codec_output = output[output_written..][0..self.limitArchiveWrite(output.len - output_written)];
                    if (codec_output.len == 0) return error.OutputLimitExceeded;
                    const encoded = entry.codec.step(
                        input[input_read..],
                        codec_output,
                    ) catch |err| {
                        try self.accountFailedCodecProgress(entry, input[input_read..], codec_output, &input_read, &output_written);
                        return err;
                    };
                    entry.encryptOutput(codec_output[0..encoded.progress.output_written]);
                    const before = input_read;
                    try self.accountCodecProgress(entry, input[input_read..], encoded.progress, &input_read, &output_written);
                    if (encoded.status == .need_output)
                        return result(input_read, output_written, .need_output);
                    if (encoded.status == .done) return error.InvalidBlockPlan;
                    if (input_read == input.len)
                        return result(input_read, output_written, .need_input);
                    if (input_read == before and encoded.progress.output_written == 0)
                        return error.InvalidBlockPlan;
                    continue;
                },
                .central_directory => {
                    if (input_read != input.len) return error.TrailingData;
                    const remaining = self.central.items[self.central_offset..];
                    const wanted = @min(remaining.len, output.len - output_written);
                    const take = self.limitArchiveWrite(wanted);
                    if (take == 0 and remaining.len != 0) {
                        if (output_written == output.len)
                            return result(input_read, output_written, .need_output);
                        return error.OutputLimitExceeded;
                    }
                    @memcpy(output[output_written..][0..take], remaining[0..take]);
                    self.central_offset += take;
                    output_written += take;
                    try self.addArchiveOutput(take);
                    if (self.central_offset != self.central.items.len)
                        return result(input_read, output_written, .need_output);
                    self.central.clearRetainingCapacity();
                    self.central_offset = 0;
                    try self.buildArchiveEnd();
                    if (self.options.stop_at_record_boundaries)
                        return result(input_read, output_written, .need_output);
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    continue;
                },
                .done, .poisoned => unreachable,
            }
        }
    }

    fn stepPkwareStrongEntry(
        self: *Self,
        input: []const u8,
        output: []u8,
        input_read: *usize,
        output_written: *usize,
    ) Error!?core.StepResult {
        var entry = &self.current.?;
        const state = entry.encryption.?.pkwareState().?;
        if (entry.method == .stored) {
            if (self.finish_entry_requested) {
                if (input_read.* != input.len) return error.TrailingData;
                const target = try self.pkwareOutputSlice(output, output_written.*);
                const encrypted = try state.encryptor.finish(target);
                try self.accountPkwareOutput(entry, encrypted.output_written, output_written);
                if (encrypted.status != .done)
                    return result(input_read.*, output_written.*, .need_output);
                try self.finalizeEntry();
                if (self.options.stop_at_record_boundaries)
                    return result(input_read.*, output_written.*, .need_output);
                return null;
            }
            if (input_read.* == input.len)
                return result(input_read.*, output_written.*, .need_input);
            try self.checkInputOffer(input[input_read.*..].len);
            const target = try self.pkwareOutputSlice(output, output_written.*);
            const encrypted = try state.encryptor.update(input[input_read.*..], target);
            const consumed = input[input_read.*..][0..encrypted.input_read];
            entry.crc.update(consumed);
            try self.addEntryInput(entry, encrypted.input_read);
            input_read.* += encrypted.input_read;
            try self.accountPkwareOutput(entry, encrypted.output_written, output_written);
            if (input_read.* != input.len)
                return result(input_read.*, output_written.*, .need_output);
            return result(input_read.*, output_written.*, .need_input);
        }

        while (true) {
            if (state.codec_output_pos < state.codec_output_len) {
                const target = try self.pkwareOutputSlice(output, output_written.*);
                const encrypted = try state.encryptor.update(
                    state.codec_output[state.codec_output_pos..state.codec_output_len],
                    target,
                );
                state.codec_output_pos += encrypted.input_read;
                try self.accountPkwareOutput(entry, encrypted.output_written, output_written);
                if (state.codec_output_pos != state.codec_output_len)
                    return result(input_read.*, output_written.*, .need_output);
                state.codec_output_pos = 0;
                state.codec_output_len = 0;
                continue;
            }

            if (state.codec_done) {
                const target = try self.pkwareOutputSlice(output, output_written.*);
                const encrypted = try state.encryptor.finish(target);
                try self.accountPkwareOutput(entry, encrypted.output_written, output_written);
                if (encrypted.status != .done)
                    return result(input_read.*, output_written.*, .need_output);
                try self.finalizeEntry();
                if (self.options.stop_at_record_boundaries)
                    return result(input_read.*, output_written.*, .need_output);
                return null;
            }

            if (self.finish_entry_requested) {
                if (input_read.* != input.len) return error.TrailingData;
                if (!state.codec_finish_requested) {
                    entry.codec.finish();
                    state.codec_finish_requested = true;
                }
            } else {
                if (input_read.* == input.len)
                    return result(input_read.*, output_written.*, .need_input);
                try self.checkInputOffer(input[input_read.*..].len);
            }

            const offered = if (self.finish_entry_requested) "" else input[input_read.*..];
            const encoded = entry.codec.step(offered, &state.codec_output) catch |err| {
                if (entry.codec.failedProgress()) |progress| {
                    if (progress.input_read > offered.len or progress.output_written > state.codec_output.len)
                        return error.InvalidBlockPlan;
                    entry.crc.update(offered[0..progress.input_read]);
                    try self.addEntryInput(entry, progress.input_read);
                    input_read.* += progress.input_read;
                    // These bytes belong to the codec bridge, not the caller's
                    // encrypted output. Archive accounting waits for encryption.
                    state.codec_output_len = progress.output_written;
                    state.codec_output_pos = 0;
                }
                return err;
            };
            if (encoded.progress.input_read > offered.len or
                encoded.progress.output_written > state.codec_output.len)
                return error.InvalidBlockPlan;
            entry.crc.update(offered[0..encoded.progress.input_read]);
            try self.addEntryInput(entry, encoded.progress.input_read);
            input_read.* += encoded.progress.input_read;
            state.codec_output_len = encoded.progress.output_written;
            state.codec_output_pos = 0;
            if (encoded.status == .done) state.codec_done = true;
            if (encoded.progress.input_read == 0 and encoded.progress.output_written == 0 and
                encoded.status != .done)
            {
                if (!self.finish_entry_requested and input_read.* == input.len)
                    return result(input_read.*, output_written.*, .need_input);
                return error.InvalidBlockPlan;
            }
        }
    }

    fn pkwareOutputSlice(
        self: *const Self,
        output: []u8,
        output_written: usize,
    ) Error![]u8 {
        const available = output.len - output_written;
        const allowed = self.limitArchiveWrite(available);
        if (allowed == 0) {
            if (available == 0) return output[output_written..output_written];
            return error.OutputLimitExceeded;
        }
        return output[output_written..][0..allowed];
    }

    fn accountPkwareOutput(
        self: *Self,
        entry: *CurrentEntry,
        amount: usize,
        output_written: *usize,
    ) Error!void {
        entry.compressed_size = std.math.add(
            u64,
            entry.compressed_size,
            @as(u64, @intCast(amount)),
        ) catch return error.IntegerOverflow;
        try self.addArchiveOutput(amount);
        output_written.* += amount;
    }

    fn validateEntry(self: *const Self, entry: EntryOptions) Error!void {
        if (entry.name.len == 0) return error.InvalidZipEntryName;
        if (!entry.modified.isValid()) return error.InvalidZipTimestamp;
        if (entry.extended_timestamp) |timestamp|
            if (!timestamp.isValid()) return error.InvalidZipTimestamp;
        if ((entry.traditional_encryption != null and entry.winzip_aes != null) or
            (entry.traditional_encryption != null and entry.pkware_strong_encryption != null) or
            (entry.winzip_aes != null and entry.pkware_strong_encryption != null))
            return error.ConflictingZipEncryption;
        if (entry.winzip_aes) |aes|
            if (aes.salt.len != aes.strength.saltLen()) return error.InvalidSaltLength;
        if (entry.pkware_strong_encryption) |strong|
            try pkware_strong.validateOptions(strong);
        if (entry.name.len > std.math.maxInt(u16) or entry.comment.len > std.math.maxInt(u16))
            return error.Zip32LimitExceeded;
        inline for (.{ entry.unicode_name, entry.unicode_comment }) |unicode_text| {
            if (unicode_text) |text| {
                if (self.options.utf8 or text.len == 0 or
                    text.len > std.math.maxInt(u16) - 5 or
                    !std.unicode.utf8ValidateSlice(text))
                {
                    return error.InvalidZipTextEncoding;
                }
            }
        }
        if (entry.expected_size) |expected| {
            if (expected > self.options.max_uncompressed_size) return error.OutputLimitExceeded;
            if (self.options.zip64 == .never and expected >= std.math.maxInt(u32))
                return error.Zip32LimitExceeded;
            if (entry.method == .stored and
                (entry.traditional_encryption != null or entry.winzip_aes != null or
                    entry.pkware_strong_encryption != null))
            {
                const encryption_len: u64 = if (entry.traditional_encryption != null)
                    traditional_encryption.header_len
                else if (entry.winzip_aes != null)
                    entry.winzip_aes.?.strength.overhead()
                else
                    @intCast(try pkware_strong.streamHeaderLen(entry.pkware_strong_encryption.?));
                const encrypted_payload_len = if (entry.pkware_strong_encryption != null)
                    try pkware_strong.encryptedDataLen(expected)
                else
                    expected;
                const compressed_size = std.math.add(u64, encrypted_payload_len, encryption_len) catch
                    return error.IntegerOverflow;
                if (self.options.zip64 == .never and compressed_size >= std.math.maxInt(u32))
                    return error.Zip32LimitExceeded;
            }
        }
        try codecs.validate(entry.method, entry.expected_size, self.codecOptions());
        if (self.options.utf8 and
            (!std.unicode.utf8ValidateSlice(entry.name) or
                !std.unicode.utf8ValidateSlice(entry.comment)))
            return error.InvalidZipTextEncoding;
    }

    fn chooseEntryZip64(self: *const Self, entry: EntryOptions, local_offset: u64) Error!bool {
        if (self.options.zip64 == .always) return true;
        if (self.options.zip64 == .never) {
            if (local_offset >= std.math.maxInt(u32)) return error.Zip32LimitExceeded;
            return false;
        }
        if (local_offset >= std.math.maxInt(u32)) return true;
        const expected = entry.expected_size orelse return true;
        // Streaming codecs have no cheap exact compressed-size bound in this
        // layer; conservatively reserve ZIP64 before their unpatchable header.
        if (entry.method != .stored) return true;
        const encryption_len: u64 = if (entry.traditional_encryption != null)
            traditional_encryption.header_len
        else if (entry.winzip_aes) |aes|
            aes.strength.overhead()
        else if (entry.pkware_strong_encryption) |strong|
            @intCast(try pkware_strong.streamHeaderLen(strong))
        else
            0;
        const encrypted_payload_len = if (entry.pkware_strong_encryption != null)
            try pkware_strong.encryptedDataLen(expected)
        else
            expected;
        const compressed_size = std.math.add(u64, encrypted_payload_len, encryption_len) catch
            return error.IntegerOverflow;
        return compressed_size >= std.math.maxInt(u32);
    }

    fn checkInputOffer(self: *const Self, offered: usize) Error!void {
        const entry = self.current.?;
        const next_entry = std.math.add(u64, entry.uncompressed_size, @as(u64, @intCast(offered))) catch
            return error.IntegerOverflow;
        if (next_entry > self.options.max_uncompressed_size) return error.OutputLimitExceeded;
        if (codecs.inputLimit(entry.method, self.codecOptions())) |limit|
            if (next_entry > std.math.maxInt(usize) or
                next_entry > @as(u64, @intCast(limit)))
                return error.OutputLimitExceeded;
        if (entry.expected_size) |expected| if (next_entry > expected) return error.SizeMismatch;
    }

    fn addEntryInput(self: *Self, entry: *CurrentEntry, amount: usize) Error!void {
        const amount64: u64 = @intCast(amount);
        entry.uncompressed_size = std.math.add(u64, entry.uncompressed_size, amount64) catch
            return error.IntegerOverflow;
        self.total_input = std.math.add(u64, self.total_input, amount64) catch
            return error.IntegerOverflow;
    }

    fn accountFailedCodecProgress(
        self: *Self,
        entry: *CurrentEntry,
        input: []const u8,
        output: []u8,
        input_read: *usize,
        output_written: *usize,
    ) Error!void {
        if (entry.codec.failedProgress()) |progress| {
            if (progress.input_read > input.len or progress.output_written > output.len)
                return error.InvalidBlockPlan;
            entry.encryptOutput(output[0..progress.output_written]);
            try self.accountCodecProgress(entry, input, progress, input_read, output_written);
        }
    }

    fn accountCodecProgress(
        self: *Self,
        entry: *CurrentEntry,
        input: []const u8,
        progress: core.Progress,
        input_read: *usize,
        output_written: *usize,
    ) Error!void {
        if (progress.input_read > input.len) return error.InvalidBlockPlan;
        entry.crc.update(input[0..progress.input_read]);
        try self.addEntryInput(entry, progress.input_read);
        entry.compressed_size = std.math.add(
            u64,
            entry.compressed_size,
            @as(u64, @intCast(progress.output_written)),
        ) catch return error.IntegerOverflow;
        try self.addArchiveOutput(progress.output_written);
        input_read.* += progress.input_read;
        output_written.* += progress.output_written;
    }

    fn codecOptions(self: *const Self) codecs.Options {
        return .{
            .deflate = self.options.deflate_options,
            .max_deflate_buffer_size = self.options.max_deflate_buffer_size,
            .deflate64 = self.options.deflate64_options,
            .dcl_implode = self.options.dcl_implode_options,
            .implode = self.options.implode_options,
            .bzip2 = self.options.bzip2_options,
            .zstd = self.options.zstd_options,
            .zstd_parallel = self.options.zstd_parallel_options,
            .zstd_dictionary = self.options.zstd_dictionary,
            .lzma = self.options.lzma_options,
            .xz = self.options.xz_options,
            .ppmd = self.options.ppmd_options,
            .reduce = self.options.reduce_options,
            .shrink = self.options.shrink_options,
        };
    }

    fn finalizeEntry(self: *Self) Error!void {
        var entry = &self.current.?;
        if (entry.expected_size) |expected| {
            if (entry.uncompressed_size != expected) return error.SizeMismatch;
        }
        const authentication_code = if (entry.encryption) |*encryption|
            encryption.authenticationCode()
        else
            null;
        if (authentication_code != null)
            entry.compressed_size = std.math.add(
                u64,
                entry.compressed_size,
                winzip_aes.authentication_code_len,
            ) catch return error.IntegerOverflow;
        if (!entry.zip64 and
            (entry.uncompressed_size >= std.math.maxInt(u32) or
                entry.compressed_size >= std.math.maxInt(u32) or
                entry.local_header_offset >= std.math.maxInt(u32)))
            return error.Zip32LimitExceeded;

        const record = wire.EncodedEntry{
            .name = entry.name(),
            .comment = entry.comment(),
            .unicode_name = entry.unicodeName(),
            .unicode_comment = entry.unicodeComment(),
            .method = entry.method,
            .flags = wire.descriptor_flag | codecs.zipFlags(&entry.codec) |
                entry.encryptionFlag() |
                (if (self.options.utf8) wire.utf8_flag else 0),
            .crc32 = if (entry.encryption) |*encryption|
                if (encryption.aesInfo()) |aes|
                    if (aes.version == .ae2) 0 else entry.crc.digest()
                else
                    entry.crc.digest()
            else
                entry.crc.digest(),
            .compressed_size = entry.compressed_size,
            .uncompressed_size = entry.uncompressed_size,
            .local_header_offset = entry.local_header_offset,
            .zip64 = entry.zip64,
            .modified = entry.modified,
            .extended_timestamp = entry.extended_timestamp,
            .ntfs_timestamp = entry.ntfs_timestamp,
            .creator_system = entry.creator_system,
            .internal_attributes = entry.internal_attributes,
            .external_attributes = entry.external_attributes,
            .winzip_aes = if (entry.encryption) |*encryption|
                encryption.aesInfo()
            else
                null,
            .pkware_strong_encryption = if (entry.encryption) |*encryption|
                encryption.pkwareInfo()
            else
                null,
        };

        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        if (authentication_code) |code|
            try self.pending.appendSlice(self.allocator, &code);
        try wire.appendDataDescriptor(self.allocator, &self.pending, record);
        try self.checkArchiveAddition(self.pending.items.len);
        const central_start = self.central.items.len;
        errdefer self.central.items.len = central_start;
        try wire.appendCentralHeader(self.allocator, &self.central, record);
        std.debug.assert(self.central.items.len <= self.options.max_central_directory_size);

        self.entry_count = std.math.add(u64, self.entry_count, 1) catch return error.IntegerOverflow;
        self.any_zip64_entry = self.any_zip64_entry or entry.zip64;
        entry.deinit(self.allocator);
        self.current = null;
        self.finish_entry_requested = false;
        self.phase = .entry_descriptor;
    }

    fn prepareArchiveFinish(self: *Self) Error!void {
        const absolute_central_offset = std.math.add(
            u64,
            self.options.initial_offset,
            self.archive_output,
        ) catch return error.IntegerOverflow;
        const central_size: u64 = @intCast(self.central.items.len);
        const zip64 = self.options.zip64 == .always or self.any_zip64_entry or
            self.entry_count >= std.math.maxInt(u16) or
            central_size >= std.math.maxInt(u32) or
            absolute_central_offset >= std.math.maxInt(u32);
        if (zip64 and self.options.zip64 == .never) return error.Zip32LimitExceeded;
        _ = std.math.add(u64, absolute_central_offset, central_size) catch
            return error.IntegerOverflow;
        const archive_end_len = try checkedAdd(
            if (zip64)
                wire.zip64_end_of_central_len + wire.zip64_end_of_central_locator_len + wire.end_of_central_len
            else
                wire.end_of_central_len,
            self.archive_comment.len,
        );
        try self.checkArchiveAddition(try checkedAdd(self.central.items.len, archive_end_len));
        self.final_central_offset = absolute_central_offset;
        self.final_central_size = central_size;
        self.final_archive_zip64 = zip64;
    }

    fn buildArchiveEnd(self: *Self) Error!void {
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        if (self.final_archive_zip64) {
            const zip64_record_offset = std.math.add(
                u64,
                self.final_central_offset,
                self.final_central_size,
            ) catch return error.IntegerOverflow;
            try wire.appendZip64EndAtOffset(
                self.allocator,
                &self.pending,
                zip64_record_offset,
                self.entry_count,
                self.final_central_size,
                self.final_central_offset,
                self.archive_comment,
            );
        } else {
            try wire.appendLegacyEnd(
                self.allocator,
                &self.pending,
                @intCast(self.entry_count),
                @intCast(self.final_central_size),
                @intCast(self.final_central_offset),
                self.archive_comment,
            );
        }
        try self.checkArchiveAddition(self.pending.items.len);
        self.phase = .archive_end;
    }

    fn drainPending(self: *Self, output: []u8, output_written: *usize) Error!void {
        const remaining = self.pending.items[self.pending_offset..];
        const wanted = @min(remaining.len, output.len - output_written.*);
        const take = self.limitArchiveWrite(wanted);
        if (take == 0 and remaining.len != 0) {
            if (output_written.* == output.len) return;
            return error.OutputLimitExceeded;
        }
        @memcpy(output[output_written.*..][0..take], remaining[0..take]);
        self.pending_offset += take;
        output_written.* += take;
        try self.addArchiveOutput(take);
    }

    fn addArchiveOutput(self: *Self, amount: usize) Error!void {
        const amount64: u64 = @intCast(amount);
        const next = std.math.add(u64, self.archive_output, amount64) catch
            return error.IntegerOverflow;
        if (next > self.options.max_archive_size) return error.OutputLimitExceeded;
        self.archive_output = next;
    }

    fn checkArchiveAddition(self: *const Self, amount: usize) Error!void {
        const next = std.math.add(u64, self.archive_output, @as(u64, @intCast(amount))) catch
            return error.IntegerOverflow;
        if (next > self.options.max_archive_size) return error.OutputLimitExceeded;
    }

    fn limitArchiveWrite(self: *const Self, wanted: usize) usize {
        const remaining = self.options.max_archive_size -| self.archive_output;
        return @min(wanted, std.math.cast(usize, remaining) orelse std.math.maxInt(usize));
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{
            .progress = .{ .input_read = input_read, .output_written = output_written },
            .status = status,
        };
    }

    fn checkedAdd(a: usize, b: usize) Error!usize {
        return std.math.add(usize, a, b) catch error.IntegerOverflow;
    }
};

test {
    _ = @import("incremental_writer_tests.zig");
}
