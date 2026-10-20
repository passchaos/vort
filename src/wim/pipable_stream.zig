//! Incremental path extraction from wimlib pipable WIM byte streams.

const std = @import("std");
const core = @import("../core.zig");
const archive_mod = @import("archive.zig");
const codec = @import("codec.zig");
const format = @import("format.zig");
const image_metadata = @import("metadata.zig");
const pipable = @import("pipable.zig");
const pipable_integrity = @import("pipable_integrity.zig");

pub const Error = archive_mod.Error;

pub const Limits = struct {
    max_metadata_bytes: usize = 256 * 1024 * 1024,
    max_directory_entries: usize = 1024 * 1024,
    max_path_depth: usize = 256,
    max_chunk_bytes: usize = 256 * 1024 * 1024,
    max_integrity_chunks: usize = 1024 * 1024,
};

pub const Options = struct {
    image_index: u32 = 1,
    /// Borrowed for the extractor lifetime.
    path: []const u8,
    /// Named-stream storage, when selected, is borrowed for the extractor lifetime.
    stream: archive_mod.StreamSelector = .default,
    max_output_len: usize,
    /// Continue past the selected blob and validate the terminal integrity table
    /// plus trailing header. The default preserves early-exit extraction.
    verify_integrity: bool = false,
    limits: Limits = .{},
};

pub const PathExtractor = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .leading_header,
    header_bytes: [format.header_size]u8 = undefined,
    header_received: usize = 0,
    blob_header_bytes: [pipable.blob_header_size]u8 = undefined,
    blob_header_received: usize = 0,
    part_header_bytes: [format.header_size]u8 = undefined,
    part_header_received: usize = 0,
    header_value: ?format.Header = null,
    current_part: u16 = 0,
    part_bytes_consumed: u64 = 0,
    current_part_trailing_seen: bool = false,
    terminal_header_seen: bool = false,
    stream_stage: StreamStage = .extra_xml,
    metadata_seen: u32 = 0,
    metadata_bytes: std.ArrayList(u8) = .empty,
    target_sha1: ?[20]u8 = null,
    target_complete: bool = false,
    expected_output_len: ?u64 = null,
    total_output_written: usize = 0,
    resource: ResourceState = .{},
    part_extra_xml_pending: bool = false,
    part_tail_metadata_seen: u2 = 0,
    integrity: pipable_integrity.Verifier,
    tail_prefix: [12]u8 = undefined,
    tail_prefix_received: usize = 0,

    const Phase = enum {
        leading_header,
        blob_header,
        part_header,
        resource,
        tail_prefix,
        integrity_digests,
        done,
    };

    const StreamStage = enum {
        extra_xml,
        metadata,
        files,
    };

    const ResourceRole = enum {
        extra_xml,
        metadata_skip,
        metadata_selected,
        file_skip,
        file_target,
        part_extra_xml_skip,
        lookup_skip,
        final_xml_skip,
    };

    const ResourceMode = enum {
        skip,
        collect_metadata,
        emit_target,
    };

    const BlobHeader = struct {
        uncompressed_size: u64,
        sha1: [20]u8,
        flags: u8,

        fn isCompressed(self: BlobHeader) bool {
            return self.flags & 0x04 != 0;
        }

        fn isMetadata(self: BlobHeader) bool {
            return self.flags & 0x02 != 0;
        }
    };

    const ResourcePhase = enum {
        raw,
        chunk_header,
        chunk_data,
        decoded_output,
        tail_table,
    };

    const ResourceState = struct {
        active: bool = false,
        role: ResourceRole = .extra_xml,
        mode: ResourceMode = .skip,
        phase: ResourcePhase = .raw,
        blob: BlobHeader = undefined,
        remaining_uncompressed: u64 = 0,
        chunk_count: u64 = 0,
        chunk_index: u64 = 0,
        chunk_header: [pipable.chunk_header_size]u8 = undefined,
        chunk_header_received: usize = 0,
        encoded_len: usize = 0,
        encoded_remaining: usize = 0,
        encoded_buffer: ?[]u8 = null,
        encoded_received: usize = 0,
        decoded_buffer: ?[]u8 = null,
        decoded_offset: usize = 0,
        decoded_len: usize = 0,
        tail_remaining: u64 = 0,
        hasher: std.crypto.hash.Sha1 = std.crypto.hash.Sha1.init(.{}),

        fn deinitBuffers(self: *ResourceState, allocator: std.mem.Allocator) void {
            if (self.encoded_buffer) |bytes| allocator.free(bytes);
            if (self.decoded_buffer) |bytes| allocator.free(bytes);
            self.encoded_buffer = null;
            self.decoded_buffer = null;
        }
    };

    const ResourceStep = struct {
        input_read: usize = 0,
        output_written: usize = 0,
        status: Status,

        const Status = enum {
            need_input,
            need_output,
            complete,
        };
    };

    pub fn init(allocator: std.mem.Allocator, options: Options) PathExtractor {
        return .{
            .allocator = allocator,
            .options = options,
            .integrity = pipable_integrity.Verifier.init(
                allocator,
                options.verify_integrity,
                options.limits.max_integrity_chunks,
            ),
        };
    }

    pub fn deinit(self: *PathExtractor) void {
        self.resource.deinitBuffers(self.allocator);
        self.metadata_bytes.deinit(self.allocator);
        self.integrity.deinit();
        self.* = undefined;
    }

    pub fn header(self: *const PathExtractor) ?format.Header {
        return self.header_value;
    }

    pub fn selectedSha1(self: *const PathExtractor) ?[20]u8 {
        return self.target_sha1;
    }

    pub fn expectedOutputLen(self: *const PathExtractor) ?u64 {
        return self.expected_output_len;
    }

    pub fn outputWritten(self: *const PathExtractor) usize {
        return self.total_output_written;
    }

    pub fn step(
        self: *PathExtractor,
        input: []const u8,
        output: []u8,
    ) Error!core.StepResult {
        if (self.phase == .done) return result(0, 0, .done);
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .leading_header => {
                const consumed = fillFixed(
                    &self.header_bytes,
                    &self.header_received,
                    input[input_read..],
                );
                input_read += consumed;
                try self.addPartInput(consumed);
                if (self.header_received != self.header_bytes.len)
                    return result(input_read, output_written, .need_input);
                const parsed = try format.parsePipableLeadingHeader(&self.header_bytes);
                if (parsed.part_number != 1) return error.InvalidWim;
                if (self.options.image_index == 0 or
                    self.options.image_index > parsed.image_count)
                    return error.WimImageNotFound;
                if (parsed.compression != .none and
                    parsed.chunk_size > self.options.limits.max_chunk_bytes)
                    return error.OutputLimitExceeded;
                self.header_value = parsed;
                self.current_part = 1;
                try self.integrity.begin();
                self.phase = .blob_header;
            },
            .blob_header => {
                const before = input_read;
                const consumed = fillFixed(
                    &self.blob_header_bytes,
                    &self.blob_header_received,
                    input[input_read..],
                );
                input_read += consumed;
                try self.addPartInput(consumed);
                try self.integrity.update(input[before..input_read]);
                if (self.blob_header_received != self.blob_header_bytes.len)
                    return result(input_read, output_written, .need_input);
                if (std.mem.eql(
                    u8,
                    self.blob_header_bytes[0..8],
                    &format.pipable_magic,
                )) {
                    if (self.stream_stage != .files) return error.InvalidWim;
                    @memcpy(
                        self.part_header_bytes[0..pipable.blob_header_size],
                        &self.blob_header_bytes,
                    );
                    self.part_header_received = pipable.blob_header_size;
                    self.blob_header_received = 0;
                    self.phase = .part_header;
                    continue;
                }
                const blob = try parseBlobHeader(&self.blob_header_bytes);
                self.blob_header_received = 0;
                const role = try self.classifyBlob(blob);
                try self.startResource(blob, role);
                self.phase = .resource;
            },
            .part_header => {
                const consumed = fillFixed(
                    &self.part_header_bytes,
                    &self.part_header_received,
                    input[input_read..],
                );
                input_read += consumed;
                try self.addPartInput(consumed);
                if (self.part_header_received != self.part_header_bytes.len)
                    return result(input_read, output_written, .need_input);
                try self.acceptPartHeader(&self.part_header_bytes);
                self.part_header_received = 0;
                if (self.phase == .done)
                    return result(input_read, output_written, .done);
                self.phase = .blob_header;
            },
            .resource => {
                const before = input_read;
                const stepped = try self.stepResource(
                    input[input_read..],
                    output[output_written..],
                );
                input_read += stepped.input_read;
                try self.addPartInput(stepped.input_read);
                try self.integrity.update(input[before..input_read]);
                output_written += stepped.output_written;
                switch (stepped.status) {
                    .need_input => return result(input_read, output_written, .need_input),
                    .need_output => return result(input_read, output_written, .need_output),
                    .complete => {
                        try self.finishResource();
                        if (self.phase == .done)
                            return result(input_read, output_written, .done);
                        if (self.phase == .resource) self.phase = .blob_header;
                    },
                }
            },
            .tail_prefix => {
                if (self.tail_prefix_received == 0)
                    self.integrity.table_offset = self.part_bytes_consumed;
                const consumed = fillFixed(
                    &self.tail_prefix,
                    &self.tail_prefix_received,
                    input[input_read..],
                );
                input_read += consumed;
                try self.addPartInput(consumed);
                if (self.tail_prefix_received != self.tail_prefix.len)
                    return result(input_read, output_written, .need_input);
                if (std.mem.eql(u8, self.tail_prefix[0..8], &format.pipable_magic)) {
                    @memcpy(self.part_header_bytes[0..self.tail_prefix.len], &self.tail_prefix);
                    self.part_header_received = self.tail_prefix.len;
                    self.tail_prefix_received = 0;
                    self.integrity.table_len = null;
                    self.integrity.table_offset = null;
                    self.phase = .part_header;
                    continue;
                }
                try self.integrity.startTable(
                    &self.tail_prefix,
                    self.integrity.table_offset.?,
                );
                self.tail_prefix_received = 0;
                self.phase = .integrity_digests;
            },
            .integrity_digests => {
                const consumed = try self.integrity.consumeTable(input[input_read..]);
                input_read += consumed;
                try self.addPartInput(consumed);
                if (!self.integrity.tableComplete())
                    return result(input_read, output_written, .need_input);
                self.part_header_received = 0;
                self.phase = .part_header;
            },
            .done => return result(input_read, output_written, .done),
        };
    }

    pub fn finish(self: *const PathExtractor) Error!void {
        if (self.phase == .done) return;
        if (self.phase == .blob_header and self.blob_header_received == 0 and
            self.terminal_header_seen)
            return error.WimResourceNotFound;
        return error.TruncatedFrame;
    }

    fn classifyBlob(self: *PathExtractor, blob: BlobHeader) Error!ResourceRole {
        return switch (self.stream_stage) {
            .extra_xml => blk: {
                if (!blob.isMetadata()) return error.InvalidWim;
                break :blk .extra_xml;
            },
            .metadata => blk: {
                if (!blob.isMetadata()) return error.InvalidWim;
                break :blk if (self.metadata_seen + 1 == self.options.image_index)
                    .metadata_selected
                else
                    .metadata_skip;
            },
            .files => blk: {
                if (blob.isMetadata()) {
                    if (self.part_extra_xml_pending)
                        break :blk .part_extra_xml_skip;
                    break :blk switch (self.part_tail_metadata_seen) {
                        0 => .lookup_skip,
                        1 => .final_xml_skip,
                        else => return error.InvalidWim,
                    };
                }
                if (self.part_tail_metadata_seen != 0) return error.InvalidWim;
                const target = self.target_sha1 orelse return error.InvalidWim;
                if (!self.target_complete and std.mem.eql(u8, &blob.sha1, &target))
                    break :blk .file_target;
                break :blk .file_skip;
            },
        };
    }

    fn startResource(
        self: *PathExtractor,
        blob: BlobHeader,
        role: ResourceRole,
    ) Error!void {
        std.debug.assert(!self.resource.active);
        const mode: ResourceMode = switch (role) {
            .metadata_selected => .collect_metadata,
            .file_target => .emit_target,
            else => .skip,
        };
        if (mode == .collect_metadata) {
            const size = std.math.cast(usize, blob.uncompressed_size) orelse
                return error.IntegerOverflow;
            if (size > self.options.limits.max_metadata_bytes)
                return error.OutputLimitExceeded;
            self.metadata_bytes.clearRetainingCapacity();
            try self.metadata_bytes.ensureTotalCapacity(self.allocator, size);
        } else if (mode == .emit_target) {
            const size = std.math.cast(usize, blob.uncompressed_size) orelse
                return error.IntegerOverflow;
            if (size > self.options.max_output_len) return error.OutputLimitExceeded;
            self.expected_output_len = blob.uncompressed_size;
        }
        var resource = ResourceState{
            .active = true,
            .role = role,
            .mode = mode,
            .blob = blob,
            .remaining_uncompressed = blob.uncompressed_size,
            .hasher = std.crypto.hash.Sha1.init(.{}),
        };
        if (blob.isCompressed()) {
            const parsed_header = self.header_value.?;
            if (parsed_header.compression == .none or parsed_header.chunk_size == 0)
                return error.InvalidWim;
            const chunk_size: u64 = parsed_header.chunk_size;
            resource.chunk_count = (std.math.add(
                u64,
                blob.uncompressed_size,
                chunk_size - 1,
            ) catch return error.IntegerOverflow) / chunk_size;
            const entry_size: u64 = if (blob.uncompressed_size <= std.math.maxInt(u32)) 4 else 8;
            resource.tail_remaining = std.math.mul(
                u64,
                resource.chunk_count - 1,
                entry_size,
            ) catch return error.IntegerOverflow;
            resource.phase = .chunk_header;
        } else {
            resource.phase = .raw;
        }
        self.resource = resource;
    }

    fn stepResource(
        self: *PathExtractor,
        input: []const u8,
        output: []u8,
    ) Error!ResourceStep {
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.resource.phase) {
            .raw => {
                if (self.resource.remaining_uncompressed == 0)
                    return .{ .input_read = input_read, .output_written = output_written, .status = .complete };
                switch (self.resource.mode) {
                    .skip => {
                        if (input_read == input.len)
                            return .{ .input_read = input_read, .output_written = output_written, .status = .need_input };
                        const take = boundedTake(
                            self.resource.remaining_uncompressed,
                            input.len - input_read,
                        );
                        input_read += take;
                        self.resource.remaining_uncompressed -= take;
                    },
                    .collect_metadata => {
                        if (input_read == input.len)
                            return .{ .input_read = input_read, .output_written = output_written, .status = .need_input };
                        const take = boundedTake(
                            self.resource.remaining_uncompressed,
                            input.len - input_read,
                        );
                        const bytes = input[input_read..][0..take];
                        try self.metadata_bytes.appendSlice(self.allocator, bytes);
                        self.resource.hasher.update(bytes);
                        input_read += take;
                        self.resource.remaining_uncompressed -= take;
                    },
                    .emit_target => {
                        if (output_written == output.len)
                            return .{ .input_read = input_read, .output_written = output_written, .status = .need_output };
                        if (input_read == input.len)
                            return .{ .input_read = input_read, .output_written = output_written, .status = .need_input };
                        const take = @min(
                            boundedTake(
                                self.resource.remaining_uncompressed,
                                input.len - input_read,
                            ),
                            output.len - output_written,
                        );
                        const bytes = input[input_read..][0..take];
                        @memcpy(output[output_written..][0..take], bytes);
                        self.resource.hasher.update(bytes);
                        input_read += take;
                        output_written += take;
                        self.resource.remaining_uncompressed -= take;
                        self.total_output_written = std.math.add(
                            usize,
                            self.total_output_written,
                            take,
                        ) catch return error.IntegerOverflow;
                    },
                }
            },
            .chunk_header => {
                if (self.resource.chunk_index == self.resource.chunk_count) {
                    self.resource.phase = .tail_table;
                    continue;
                }
                input_read += fillFixed(
                    &self.resource.chunk_header,
                    &self.resource.chunk_header_received,
                    input[input_read..],
                );
                if (self.resource.chunk_header_received != pipable.chunk_header_size)
                    return .{ .input_read = input_read, .output_written = output_written, .status = .need_input };
                const encoded_len: usize = format.readU32(&self.resource.chunk_header, 0);
                const decoded_len = boundedTake(
                    self.resource.remaining_uncompressed,
                    self.header_value.?.chunk_size,
                );
                if (encoded_len == 0 or encoded_len > decoded_len)
                    return error.InvalidWim;
                self.resource.chunk_header_received = 0;
                self.resource.encoded_len = encoded_len;
                self.resource.encoded_remaining = encoded_len;
                self.resource.decoded_len = decoded_len;
                if (self.resource.mode != .skip) {
                    self.resource.encoded_buffer = try self.allocator.alloc(u8, encoded_len);
                    self.resource.encoded_received = 0;
                }
                self.resource.phase = .chunk_data;
            },
            .chunk_data => {
                if (self.resource.mode == .skip) {
                    if (self.resource.encoded_remaining != 0) {
                        if (input_read == input.len)
                            return .{ .input_read = input_read, .output_written = output_written, .status = .need_input };
                        const take = @min(
                            self.resource.encoded_remaining,
                            input.len - input_read,
                        );
                        input_read += take;
                        self.resource.encoded_remaining -= take;
                    }
                    if (self.resource.encoded_remaining == 0) {
                        self.completeChunk();
                        continue;
                    }
                } else {
                    const encoded = self.resource.encoded_buffer.?;
                    if (self.resource.encoded_received != encoded.len) {
                        if (input_read == input.len)
                            return .{ .input_read = input_read, .output_written = output_written, .status = .need_input };
                        const take = @min(
                            encoded.len - self.resource.encoded_received,
                            input.len - input_read,
                        );
                        @memcpy(
                            encoded[self.resource.encoded_received..][0..take],
                            input[input_read..][0..take],
                        );
                        self.resource.encoded_received += take;
                        input_read += take;
                    }
                    if (self.resource.encoded_received == encoded.len) {
                        const decoded = try self.allocator.alloc(u8, self.resource.decoded_len);
                        errdefer self.allocator.free(decoded);
                        if (encoded.len == decoded.len) {
                            @memcpy(decoded, encoded);
                        } else {
                            try codec.decodeChunkInto(
                                self.allocator,
                                self.header_value.?.compression,
                                encoded,
                                decoded,
                                self.header_value.?.chunk_size,
                            );
                        }
                        self.allocator.free(encoded);
                        self.resource.encoded_buffer = null;
                        self.resource.hasher.update(decoded);
                        if (self.resource.mode == .collect_metadata) {
                            try self.metadata_bytes.appendSlice(self.allocator, decoded);
                            self.allocator.free(decoded);
                            self.completeChunk();
                            continue;
                        }
                        self.resource.decoded_buffer = decoded;
                        self.resource.decoded_offset = 0;
                        self.resource.phase = .decoded_output;
                    }
                }
            },
            .decoded_output => {
                const decoded = self.resource.decoded_buffer.?;
                if (output_written == output.len)
                    return .{ .input_read = input_read, .output_written = output_written, .status = .need_output };
                const take = @min(
                    decoded.len - self.resource.decoded_offset,
                    output.len - output_written,
                );
                @memcpy(
                    output[output_written..][0..take],
                    decoded[self.resource.decoded_offset..][0..take],
                );
                self.resource.decoded_offset += take;
                output_written += take;
                self.total_output_written = std.math.add(
                    usize,
                    self.total_output_written,
                    take,
                ) catch return error.IntegerOverflow;
                if (self.resource.decoded_offset == decoded.len) {
                    self.allocator.free(decoded);
                    self.resource.decoded_buffer = null;
                    self.completeChunk();
                }
            },
            .tail_table => {
                if (self.resource.tail_remaining == 0)
                    return .{ .input_read = input_read, .output_written = output_written, .status = .complete };
                if (input_read == input.len)
                    return .{ .input_read = input_read, .output_written = output_written, .status = .need_input };
                const take = boundedTake(
                    self.resource.tail_remaining,
                    input.len - input_read,
                );
                input_read += take;
                self.resource.tail_remaining -= take;
            },
        };
    }

    fn completeChunk(self: *PathExtractor) void {
        self.resource.remaining_uncompressed -= self.resource.decoded_len;
        self.resource.chunk_index += 1;
        self.resource.encoded_len = 0;
        self.resource.encoded_remaining = 0;
        self.resource.encoded_received = 0;
        self.resource.decoded_len = 0;
        self.resource.decoded_offset = 0;
        self.resource.phase = .chunk_header;
    }

    fn finishResource(self: *PathExtractor) Error!void {
        const role = self.resource.role;
        const mode = self.resource.mode;
        if (mode != .skip) {
            var actual: [20]u8 = undefined;
            self.resource.hasher.final(&actual);
            if (!std.mem.eql(u8, &actual, &self.resource.blob.sha1))
                return error.ChecksumMismatch;
        }
        self.resource.deinitBuffers(self.allocator);
        self.resource.active = false;
        switch (role) {
            .extra_xml => self.stream_stage = .metadata,
            .metadata_skip, .metadata_selected => {
                self.metadata_seen += 1;
                if (role == .metadata_selected) try self.selectTargetFromMetadata();
                if (self.phase == .done) return;
                if (self.metadata_seen == self.header_value.?.image_count)
                    self.stream_stage = .files;
            },
            .file_skip => {},
            .file_target => {
                if (self.total_output_written != self.expected_output_len.?)
                    return error.SizeMismatch;
                self.target_complete = true;
                if (!self.options.verify_integrity) self.phase = .done;
            },
            .part_extra_xml_skip => self.part_extra_xml_pending = false,
            .lookup_skip => {
                try self.integrity.finishCoverage();
                self.part_tail_metadata_seen = 1;
            },
            .final_xml_skip => {
                self.part_tail_metadata_seen = 2;
                self.phase = .tail_prefix;
            },
        }
    }

    fn selectTargetFromMetadata(self: *PathExtractor) Error!void {
        const owned = try self.metadata_bytes.toOwnedSlice(self.allocator);
        var image = image_metadata.ImageMetadata.fromOwnedBytes(
            self.allocator,
            owned,
        ) catch |err| {
            self.allocator.free(owned);
            return err;
        };
        defer image.deinit();
        const dentry = try image.lookup(
            self.allocator,
            self.options.path,
            self.options.limits.max_directory_entries,
            self.options.limits.max_path_depth,
        );
        const hash = try archive_mod.selectDentryStreamSha1Alloc(
            self.allocator,
            dentry,
            self.options.stream,
        );
        self.target_sha1 = hash;
        if (std.mem.allEqual(u8, &hash, 0)) {
            self.expected_output_len = 0;
            self.target_complete = true;
            if (!self.options.verify_integrity) self.phase = .done;
        }
    }

    fn acceptPartHeader(
        self: *PathExtractor,
        bytes: *const [format.header_size]u8,
    ) Error!void {
        const parsed = try format.parsePipableStreamHeader(bytes);
        const first = self.header_value.?;
        if (parsed.total_parts != first.total_parts or
            !std.mem.eql(u8, &parsed.guid, &first.guid) or
            parsed.version != first.version or
            parsed.compression != first.compression or
            parsed.chunk_size != first.chunk_size or
            parsed.image_count != first.image_count or
            parsed.boot_index != first.boot_index)
            return error.InvalidWim;
        if (parsed.part_number == self.current_part) {
            if (self.current_part_trailing_seen or resourcesAllZero(parsed))
                return error.InvalidWim;
            try self.integrity.validateDeclaration(parsed.integrity_table);
            self.current_part_trailing_seen = true;
            if (parsed.part_number == parsed.total_parts) {
                self.terminal_header_seen = true;
                if (self.target_complete and self.options.verify_integrity)
                    self.phase = .done;
            }
            return;
        }
        if (parsed.part_number != self.current_part + 1 or
            !self.current_part_trailing_seen or !resourcesAllZero(parsed))
            return error.InvalidWim;
        self.current_part = parsed.part_number;
        self.part_bytes_consumed = format.header_size;
        self.current_part_trailing_seen = false;
        self.terminal_header_seen = false;
        self.part_extra_xml_pending = true;
        self.part_tail_metadata_seen = 0;
        try self.integrity.begin();
    }

    fn addPartInput(self: *PathExtractor, count: usize) Error!void {
        self.part_bytes_consumed = std.math.add(
            u64,
            self.part_bytes_consumed,
            @intCast(count),
        ) catch return error.IntegerOverflow;
    }
};

fn parseBlobHeader(bytes: *const [pipable.blob_header_size]u8) Error!PathExtractor.BlobHeader {
    if (format.readU64(bytes, 0) != pipable.blob_magic) return error.InvalidWim;
    const uncompressed_size = format.readU64(bytes, 8);
    if (uncompressed_size == 0) return error.InvalidWim;
    const flags_u32 = format.readU32(bytes, 36);
    if (flags_u32 & ~@as(u32, 0x06) != 0) return error.InvalidWim;
    var sha1: [20]u8 = undefined;
    @memcpy(&sha1, bytes[16..36]);
    return .{
        .uncompressed_size = uncompressed_size,
        .sha1 = sha1,
        .flags = @intCast(flags_u32),
    };
}

fn resourcesAllZero(header: format.Header) bool {
    return header.lookup_table.isZero() and header.xml_data.isZero() and
        header.boot_metadata.isZero() and header.integrity_table.isZero();
}

fn fillFixed(buffer: []u8, received: *usize, input: []const u8) usize {
    const take = @min(buffer.len - received.*, input.len);
    @memcpy(buffer[received.*..][0..take], input[0..take]);
    received.* += take;
    return take;
}

fn boundedTake(remaining: u64, available: usize) usize {
    if (remaining < available) return @intCast(remaining);
    return available;
}

fn result(
    input_read: usize,
    output_written: usize,
    status: core.StepResult.Status,
) core.StepResult {
    return .{
        .progress = .{
            .input_read = input_read,
            .output_written = output_written,
        },
        .status = status,
    };
}
