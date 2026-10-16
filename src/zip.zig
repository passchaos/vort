const std = @import("std");
const bzip2 = @import("bzip2.zig");
const core = @import("core.zig");
const checksum = @import("checksum.zig");
const dcl_implode = @import("zip/dcl_implode.zig");
const dcl_implode_incremental_encoder = @import("zip/dcl_implode/incremental_encoder.zig");
const dcl_implode_incremental_encoder_tests = @import("zip/dcl_implode_incremental_encoder_tests.zig");
const dcl_implode_incremental_tests = @import("zip/dcl_implode_incremental_tests.zig");
const deflate = @import("deflate.zig");
const deflate64 = @import("deflate64.zig");
const lzma = @import("lzma.zig");
const implode = @import("zip/implode.zig");
const implode_incremental_encoder = @import("zip/implode/incremental_encoder.zig");
const implode_incremental_encoder_tests = @import("zip/implode_incremental_encoder_tests.zig");
const implode_incremental_tests = @import("zip/implode_incremental_tests.zig");
const ppmd8 = @import("ppmd8.zig");
const pkware_strong = @import("zip/pkware_strong.zig");
const xz = @import("xz.zig");
const zstd = @import("zstd.zig");
const records = @import("zip/records.zig");
const reduce = @import("zip/reduce.zig");
const reduce_incremental_encoder = @import("zip/reduce/incremental_encoder.zig");
const reduce_incremental_encoder_tests = @import("zip/reduce_incremental_encoder_tests.zig");
const reduce_incremental_tests = @import("zip/reduce_incremental_tests.zig");
const shrink = @import("zip/shrink.zig");
const shrink_incremental_tests = @import("zip/shrink_incremental_tests.zig");
const shrink_incremental_encoder_tests = @import("zip/shrink_incremental_encoder_tests.zig");
const split = @import("zip/split.zig");
const split_incremental_reader = @import("zip/split_incremental_reader.zig");
const split_incremental_writer = @import("zip/split_incremental_writer.zig");
const split_incremental_writer_tests = @import("zip/split_incremental_writer_tests.zig");
const pkware_strong_tests = @import("zip/pkware_strong_tests.zig");
const split_writer = @import("zip/split_writer.zig");
const traditional_encryption = @import("vail_archive_crypto").zipcrypto;
const winzip_aes = @import("vail_archive_crypto").winzip_aes;
const types = @import("zip/types.zig");
const wire = @import("zip/wire.zig");
pub const writer = @import("zip/writer.zig");
pub const incremental_writer = @import("zip/incremental_writer.zig");
pub const incremental_entry_decoder = @import("zip/incremental_entry_decoder.zig");
pub const incremental_reader = @import("zip/incremental_reader.zig");

pub const Error = writer.Error || split.Error || split_writer.Error || split_incremental_writer.Error || bzip2.Error || dcl_implode.Error || deflate64.Error || implode.Error || lzma.Error || ppmd8.Error || reduce.Error || shrink.Error || xz.Error || zstd.Error || error{
    InvalidZipArchive,
    UnsupportedZipFeature,
    EncryptedZipEntry,
    UnsupportedZipCompressionMethod,
    ZipEntryNotFound,
    ZipEntryRequiresAllocator,
    PasswordRequired,
};

const local_file_signature: u32 = 0x0403_4b50;
const central_file_signature: u32 = 0x0201_4b50;
const end_of_central_signature: u32 = 0x0605_4b50;
const end_of_central_len: usize = 22;

pub const CompressionMethod = writer.CompressionMethod;
pub const CreatorSystem = types.CreatorSystem;
pub const DosTimestamp = types.DosTimestamp;
pub const ExtendedTimestamp = types.ExtendedTimestamp;
pub const NtfsTimestamp = types.NtfsTimestamp;
pub const fileTimeFromUnixSeconds = types.fileTimeFromUnixSeconds;
pub const fileTimeToUnixSeconds = types.fileTimeToUnixSeconds;
pub const unixExternalAttributes = types.unixExternalAttributes;
pub const Zip64Mode = writer.Zip64Mode;
pub const EncodeEntry = writer.EncodeEntry;
pub const EncodeOptions = writer.EncodeOptions;
pub const TraditionalEncryptionOptions = traditional_encryption.Options;
pub const WinZipAesOptions = writer.WinZipAesOptions;
pub const WinZipAesStrength = types.WinZipAesStrength;
pub const WinZipAesVendorVersion = types.WinZipAesVendorVersion;
pub const WinZipAesInfo = types.WinZipAesInfo;
pub const PkwareStrongEncryptionOptions = writer.PkwareStrongEncryptionOptions;
pub const PkwareStrongEncryptionStrength = types.PkwareStrongEncryptionStrength;
pub const PkwareStrongEncryptionInfo = types.PkwareStrongEncryptionInfo;
pub const SplitOptions = split.Options;
pub const SplitNormalizedStream = split.NormalizedStream;
pub const SplitPartSource = split.PartSource;
pub const SplitNormalizedSourceStream = split.NormalizedSourceStream;
pub const SplitIncrementalReader = split_incremental_reader.Reader;
pub const SplitIncrementalReaderOptions = split_incremental_reader.Options;
pub const SplitIncrementalReaderError = split_incremental_reader.Error;
pub const SplitEncodeOptions = split_writer.Options;
pub const SplitEncodedArchive = split_writer.EncodedArchive;
pub const SplitWriterError = split_writer.Error;
pub const SplitIncrementalWriter = split_incremental_writer.Writer;
pub const SplitIncrementalWriterOptions = split_incremental_writer.Options;
pub const SplitIncrementalWriterStepResult = split_incremental_writer.StepResult;
pub const SplitIncrementalWriterError = split_incremental_writer.Error;
pub const IncrementalWriter = incremental_writer.Writer;
pub const IncrementalWriterError = incremental_writer.Error;
pub const IncrementalWriterOptions = incremental_writer.Options;
pub const IncrementalEntryOptions = incremental_writer.EntryOptions;
pub const IncrementalWriterPhase = incremental_writer.Phase;
pub const IncrementalEntryDecoder = incremental_entry_decoder.Decoder;
pub const OwnedIncrementalEntryDecoder = incremental_entry_decoder.OwnedDecoder;
pub const IncrementalEntryDecoderError = incremental_entry_decoder.Error;
pub const IncrementalEntryDecoderOptions = incremental_entry_decoder.Options;
pub const IncrementalEntryDecoderPhase = incremental_entry_decoder.Phase;
pub const IncrementalReader = incremental_reader.Reader;
pub const IncrementalReaderError = incremental_reader.Error;
pub const IncrementalReaderOptions = incremental_reader.Options;
pub const IncrementalReaderPhase = incremental_reader.Phase;
pub const IncrementalReaderStepResult = incremental_reader.StepResult;
pub const IncrementalReaderEntryInfo = incremental_reader.EntryInfo;
pub const DclImplodeDictionary = dcl_implode.Dictionary;
pub const DclImplodeOptions = dcl_implode.Options;
pub const DclImplodeIncrementalDecoder = dcl_implode.IncrementalDecoder;
pub const DclImplodeIncrementalEncoder = dcl_implode_incremental_encoder.Encoder;
pub const ShrinkIncrementalDecoder = shrink.IncrementalDecoder;
pub const ShrinkIncrementalWorkspace = shrink.IncrementalWorkspace;
pub const ShrinkIncrementalEncoder = shrink.IncrementalEncoder;
pub const ReduceIncrementalDecoder = reduce.IncrementalDecoder;
pub const ReduceIncrementalWorkspace = reduce.IncrementalWorkspace;
pub const ReduceIncrementalEncoder = reduce_incremental_encoder.Encoder;
pub const ReduceFollowerTable = reduce.FollowerTable;
pub const trainReduceFollowerTable = reduce.trainFollowerTable;
pub const ReduceFactor = reduce.Factor;
pub const ImplodeDictionary = implode.Dictionary;
pub const ImplodeOptions = implode.Options;
pub const ImplodeIncrementalDecoder = implode.IncrementalDecoder;
pub const ImplodeIncrementalWorkspace = implode.IncrementalWorkspace;
pub const ImplodeIncrementalEncoder = implode_incremental_encoder.Encoder;
pub const encodeAlloc = writer.encodeAlloc;
pub const encodeAppend = writer.encodeAppend;
pub const encodeSplitAlloc = split_writer.encodeAlloc;

test "ZIP incremental writer test suite" {
    _ = incremental_writer;
}

test "ZIP incremental entry decoder test suite" {
    _ = incremental_entry_decoder;
}

test "ZIP incremental reader test suite" {
    _ = incremental_reader;
}

test "ZIP DCL Implode incremental test suite" {
    _ = dcl_implode_incremental_tests;
}

test "ZIP DCL Implode incremental encoder test suite" {
    _ = dcl_implode_incremental_encoder_tests;
}

test "ZIP Shrink incremental test suite" {
    _ = shrink_incremental_tests;
}

test "ZIP Shrink incremental encoder test suite" {
    _ = shrink_incremental_encoder_tests;
}

test "ZIP Reduce incremental test suite" {
    _ = reduce_incremental_tests;
}

test "ZIP Reduce incremental encoder test suite" {
    _ = reduce_incremental_encoder_tests;
}

test "ZIP Legacy Implode incremental test suite" {
    _ = implode_incremental_tests;
}

test "ZIP Legacy Implode incremental encoder test suite" {
    _ = implode_incremental_encoder_tests;
}

test "ZIP Traditional ZipCrypto test suite" {
    _ = traditional_encryption;
}

test "ZIP WinZip AES test suite" {
    _ = winzip_aes;
}

test "ZIP PKWARE Strong Encryption crypto suite" {
    _ = pkware_strong;
    _ = pkware_strong_tests;
}

pub const DecodeOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_dictionary_size: usize = 64 * 1024 * 1024,
    password: ?[]const u8 = null,
};

pub const Entry = types.Entry;

pub const Archive = struct {
    bytes: []const u8,
    entry_count: usize,
    central_directory_offset: usize,
    central_directory_size: usize,
    comment: []const u8,
    zip64: bool,

    pub fn iterator(self: Archive) Iterator {
        return .{
            .archive = self,
            .offset = self.central_directory_offset,
            .remaining = self.entry_count,
        };
    }

    pub fn entryAt(self: Archive, index: usize) Error!Entry {
        if (index >= self.entry_count) return error.RangeOutOfBounds;
        var it = self.iterator();
        var current: usize = 0;
        while (try it.next()) |entry| : (current += 1)
            if (current == index) return entry;
        return error.InvalidZipArchive;
    }

    pub fn find(self: Archive, name: []const u8) Error!?Entry {
        var it = self.iterator();
        while (try it.next()) |entry|
            if (std.mem.eql(u8, entry.preferredName(), name)) return entry;
        return self.findRaw(name);
    }

    pub fn findRaw(self: Archive, name: []const u8) Error!?Entry {
        var it = self.iterator();
        while (try it.next()) |entry|
            if (std.mem.eql(u8, entry.name, name)) return entry;
        return null;
    }

    pub fn entriesAlloc(self: Archive, allocator: std.mem.Allocator) ![]Entry {
        const entries = try allocator.alloc(Entry, self.entry_count);
        errdefer allocator.free(entries);
        var it = self.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1) entries[index] = entry;
        if (index != entries.len) return error.InvalidZipArchive;
        return entries;
    }

    pub fn extractInto(self: Archive, entry: Entry, output: []u8) Error!usize {
        return self.extractIntoOptionalAllocator(null, entry, output, .{}) catch |err| switch (err) {
            error.OutOfMemory => unreachable,
            else => |zip_error| return zip_error,
        };
    }

    /// Returns the checksum- and size-described compressed payload after
    /// validating that the local header agrees with the canonical central
    /// entry. The returned slice borrows the archive bytes.
    pub fn compressedData(self: Archive, entry: Entry) Error![]const u8 {
        const canonical = (try parseCentralEntry(self, entry.central_header_offset)).entry;
        if (!sameEntry(entry, canonical)) return error.InvalidZipArchive;
        return localCompressedData(self, canonical);
    }

    pub fn extractIntoWithAllocator(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        output: []u8,
    ) !usize {
        return self.extractIntoOptionalAllocator(allocator, entry, output, .{});
    }

    pub fn extractIntoWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        output: []u8,
        options: DecodeOptions,
    ) !usize {
        return self.extractIntoOptionalAllocator(allocator, entry, output, options);
    }

    fn extractIntoOptionalAllocator(
        self: Archive,
        allocator: ?std.mem.Allocator,
        entry: Entry,
        output: []u8,
        options: DecodeOptions,
    ) !usize {
        const parsed = try parseCentralEntry(self, entry.central_header_offset);
        const canonical = parsed.entry;
        if (canonical.uncompressed_size > options.max_output_len)
            return error.OutputLimitExceeded;
        if (output.len < canonical.uncompressed_size) return error.OutputTooSmall;
        if (canonical.isEncrypted() and allocator == null)
            return error.EncryptedZipEntry;
        const local_payload = try localPayloadData(self, canonical, true);
        var decrypted: ?[]u8 = null;
        defer if (decrypted) |bytes| {
            std.crypto.secureZero(u8, bytes);
            if (allocator) |scratch_allocator|
                scratch_allocator.free(bytes)
            else
                unreachable;
        };
        const compressed = if (canonical.isEncrypted()) encrypted: {
            const scratch_allocator = allocator orelse return error.ZipEntryRequiresAllocator;
            const password = options.password orelse return error.PasswordRequired;
            const bytes = if (canonical.winzip_aes) |aes|
                try winzip_aes.decryptAlloc(
                    scratch_allocator,
                    local_payload.data,
                    password,
                    aes.strength,
                )
            else if (canonical.pkware_strong_encryption) |strong|
                try pkware_strong.decryptAlloc(
                    scratch_allocator,
                    local_payload.data,
                    password,
                    strong.strength,
                    canonical.crc32,
                    canonical.uncompressed_size,
                )
            else traditional: {
                if (canonical.flags & (1 << 6) != 0) return error.UnsupportedZipFeature;
                const check_byte: u8 = if (canonical.flags & wire.descriptor_flag != 0)
                    @truncate(local_payload.dos_time >> 8)
                else
                    @truncate(canonical.crc32 >> 24);
                break :traditional try traditional_encryption.decryptAlloc(
                    scratch_allocator,
                    local_payload.data,
                    password,
                    check_byte,
                );
            };
            decrypted = bytes;
            break :encrypted bytes;
        } else local_payload.data;
        const target = output[0..canonical.uncompressed_size];
        switch (canonical.method) {
            .stored => {
                if (compressed.len != canonical.uncompressed_size) return error.InvalidZipArchive;
                @memcpy(target, compressed);
            },
            .shrink => try shrink.decodeInto(compressed, target),
            .reduce_1, .reduce_2, .reduce_3, .reduce_4 => try reduce.decodeInto(
                compressed,
                target,
                reduceFactor(canonical.method).?,
            ),
            .implode => try implode.decodeInto(compressed, target, canonical.flags),
            .deflate => {
                const decoded = try deflate.decodeRawAuto(compressed, target);
                if (decoded.input_read != compressed.len) return error.InvalidZipArchive;
                if (decoded.output_written != target.len) return error.SizeMismatch;
            },
            .deflate64 => {
                const decoded = try deflate64.decodeInto(compressed, target);
                if (decoded.input_read != compressed.len) return error.InvalidZipArchive;
                if (decoded.output_written != target.len) return error.SizeMismatch;
            },
            .dcl_implode => try dcl_implode.decodeInto(compressed, target),
            .bzip2 => {
                const scratch_allocator = allocator orelse return error.ZipEntryRequiresAllocator;
                const written = try bzip2.decodeInto(scratch_allocator, compressed, target);
                if (written != target.len) return error.SizeMismatch;
            },
            .lzma => {
                const scratch_allocator = allocator orelse return error.ZipEntryRequiresAllocator;
                const written = try lzma.decodeZipPayloadInto(
                    scratch_allocator,
                    compressed,
                    target.len,
                    target,
                    options.max_dictionary_size,
                    canonical.flags & 0x0002 != 0,
                );
                if (written != target.len) return error.SizeMismatch;
            },
            .xz => {
                const scratch_allocator = allocator orelse return error.ZipEntryRequiresAllocator;
                const written = try xz.decodeInto(scratch_allocator, compressed, target);
                if (written != target.len) return error.SizeMismatch;
            },
            .ppmd => {
                const scratch_allocator = allocator orelse return error.ZipEntryRequiresAllocator;
                try ppmd8.decodeZipInto(
                    scratch_allocator,
                    compressed,
                    target,
                    options.max_dictionary_size,
                );
            },
            .zstandard_legacy, .zstandard => {
                const written = try zstd.decodeFrameIntoExactSize(compressed, target, target.len);
                if (written != target.len) return error.SizeMismatch;
            },
            else => return error.UnsupportedZipCompressionMethod,
        }
        const verify_crc = if (canonical.winzip_aes) |aes| aes.version == .ae1 else true;
        if (verify_crc and checksum.crc32Best(target) != canonical.crc32)
            return error.ChecksumMismatch;
        return target.len;
    }

    pub fn extractAlloc(self: Archive, allocator: std.mem.Allocator, entry: Entry) ![]u8 {
        return self.extractAllocLimited(allocator, entry, std.math.maxInt(usize));
    }

    pub fn extractAllocLimited(self: Archive, allocator: std.mem.Allocator, entry: Entry, max_output_len: usize) ![]u8 {
        return self.extractAllocWithOptions(allocator, entry, .{ .max_output_len = max_output_len });
    }

    pub fn extractAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        entry: Entry,
        options: DecodeOptions,
    ) ![]u8 {
        if (entry.uncompressed_size > options.max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, entry.uncompressed_size);
        errdefer allocator.free(output);
        const written = try self.extractIntoWithOptions(allocator, entry, output, options);
        if (written != output.len) return error.SizeMismatch;
        return output;
    }

    pub fn extractByNameAlloc(self: Archive, allocator: std.mem.Allocator, name: []const u8) ![]u8 {
        return self.extractByNameAllocLimited(allocator, name, std.math.maxInt(usize));
    }

    pub fn extractByNameAllocLimited(self: Archive, allocator: std.mem.Allocator, name: []const u8, max_output_len: usize) ![]u8 {
        const entry = (try self.find(name)) orelse return error.ZipEntryNotFound;
        return self.extractAllocLimited(allocator, entry, max_output_len);
    }

    pub fn extractByNameAllocWithOptions(
        self: Archive,
        allocator: std.mem.Allocator,
        name: []const u8,
        options: DecodeOptions,
    ) ![]u8 {
        const entry = (try self.find(name)) orelse return error.ZipEntryNotFound;
        return self.extractAllocWithOptions(allocator, entry, options);
    }
};

/// Allocator-owned single-disk view of an ordered split/multi-disk ZIP set.
/// `archive` borrows `bytes` and remains valid until `deinit`.
pub const SplitArchive = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    archive: Archive,

    pub fn deinit(self: *SplitArchive) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

/// Validates and joins explicitly ordered split/multi-disk ZIP slices, then
/// rewrites only disk-local metadata into the owned single-disk view.
pub fn parseSplitArchiveAlloc(
    allocator: std.mem.Allocator,
    ordered_parts: []const []const u8,
    options: SplitOptions,
) !SplitArchive {
    const bytes = try split.normalizeAlloc(allocator, ordered_parts, options);
    errdefer allocator.free(bytes);
    return .{
        .allocator = allocator,
        .bytes = bytes,
        .archive = try parse(bytes),
    };
}

pub const Iterator = struct {
    archive: Archive,
    offset: usize,
    remaining: usize,

    pub fn next(self: *Iterator) Error!?Entry {
        if (self.remaining == 0) return null;
        const parsed = try parseCentralEntry(self.archive, self.offset);
        self.offset = parsed.next_offset;
        self.remaining -= 1;
        return parsed.entry;
    }
};

pub fn parse(bytes: []const u8) Error!Archive {
    const directory = try records.parseDirectory(bytes);
    return .{
        .bytes = bytes,
        .entry_count = directory.entry_count,
        .central_directory_offset = directory.central_directory_offset,
        .central_directory_size = directory.central_directory_size,
        .comment = directory.comment,
        .zip64 = directory.zip64,
    };
}

pub fn extractEntryInto(bytes: []const u8, index: usize, output: []u8) Error!usize {
    const archive = try parse(bytes);
    return archive.extractInto(try archive.entryAt(index), output);
}

pub fn extractEntryIntoWithAllocator(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    index: usize,
    output: []u8,
) !usize {
    const archive = try parse(bytes);
    return archive.extractIntoWithAllocator(allocator, try archive.entryAt(index), output);
}

pub fn extractEntryIntoWithOptions(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    index: usize,
    output: []u8,
    options: DecodeOptions,
) !usize {
    const archive = try parse(bytes);
    return archive.extractIntoWithOptions(allocator, try archive.entryAt(index), output, options);
}

pub fn extractEntryAlloc(allocator: std.mem.Allocator, bytes: []const u8, index: usize) ![]u8 {
    const archive = try parse(bytes);
    return archive.extractAlloc(allocator, try archive.entryAt(index));
}

pub fn extractEntryAllocLimited(allocator: std.mem.Allocator, bytes: []const u8, index: usize, max_output_len: usize) ![]u8 {
    const archive = try parse(bytes);
    return archive.extractAllocLimited(allocator, try archive.entryAt(index), max_output_len);
}

pub fn extractEntryAllocWithOptions(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    index: usize,
    options: DecodeOptions,
) ![]u8 {
    const archive = try parse(bytes);
    return archive.extractAllocWithOptions(allocator, try archive.entryAt(index), options);
}

pub fn extractByNameAlloc(allocator: std.mem.Allocator, bytes: []const u8, name: []const u8) ![]u8 {
    return (try parse(bytes)).extractByNameAlloc(allocator, name);
}

pub fn extractByNameAllocLimited(allocator: std.mem.Allocator, bytes: []const u8, name: []const u8, max_output_len: usize) ![]u8 {
    return (try parse(bytes)).extractByNameAllocLimited(allocator, name, max_output_len);
}

pub fn extractByNameAllocWithOptions(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    name: []const u8,
    options: DecodeOptions,
) ![]u8 {
    return (try parse(bytes)).extractByNameAllocWithOptions(allocator, name, options);
}

const ParsedCentralEntry = struct { entry: Entry, next_offset: usize };

const LocalMetadata = struct {
    extended: ?ExtendedTimestamp,
    ntfs: ?NtfsTimestamp,
    unicode_name: ?[]const u8,
};

fn parseLocalMetadata(archive: Archive, offset: usize) Error!LocalMetadata {
    if (try readU32(archive.bytes, offset) != local_file_signature)
        return error.InvalidZipArchive;
    const fixed_end = try checkedEnd(
        offset,
        wire.local_file_header_len,
        archive.central_directory_offset,
    );
    const name_len: usize = try readU16(archive.bytes, offset + 26);
    const extra_len: usize = try readU16(archive.bytes, offset + 28);
    const name_end = try checkedEnd(
        fixed_end,
        name_len,
        archive.central_directory_offset,
    );
    const extra_end = try checkedEnd(
        name_end,
        extra_len,
        archive.central_directory_offset,
    );
    const extra = archive.bytes[name_end..extra_end];
    const raw_name = archive.bytes[fixed_end..name_end];
    return .{
        .extended = try records.parseExtendedTimestampExtra(extra, .local),
        .ntfs = try records.parseNtfsTimestampExtra(extra),
        .unicode_name = try records.parseUnicodePathExtra(extra, raw_name),
    };
}

fn parseCentralEntry(archive: Archive, offset: usize) Error!ParsedCentralEntry {
    const central_end = try checkedEnd(archive.central_directory_offset, archive.central_directory_size, archive.bytes.len);
    if (offset < archive.central_directory_offset or offset >= central_end) return error.InvalidZipArchive;
    if (try readU32(archive.bytes, offset) != central_file_signature) return error.InvalidZipArchive;
    _ = try checkedEnd(offset, 46, central_end);

    const version_made_by = try readU16(archive.bytes, offset + 4);
    const flags = try readU16(archive.bytes, offset + 8);
    const version_needed = try readU16(archive.bytes, offset + 6);
    const method_raw = try readU16(archive.bytes, offset + 10);
    const wire_method: CompressionMethod = @enumFromInt(method_raw);
    const modified: DosTimestamp = .{
        .time = try readU16(archive.bytes, offset + 12),
        .date = try readU16(archive.bytes, offset + 14),
    };
    const crc = try readU32(archive.bytes, offset + 16);
    const compressed_u32 = try readU32(archive.bytes, offset + 20);
    const uncompressed_u32 = try readU32(archive.bytes, offset + 24);
    const name_len: usize = try readU16(archive.bytes, offset + 28);
    const extra_len: usize = try readU16(archive.bytes, offset + 30);
    const comment_len: usize = try readU16(archive.bytes, offset + 32);
    const disk_start_u16 = try readU16(archive.bytes, offset + 34);
    const internal_attributes = try readU16(archive.bytes, offset + 36);
    const external_attributes = try readU32(archive.bytes, offset + 38);
    const local_offset_u32 = try readU32(archive.bytes, offset + 42);

    const name_start = offset + 46;
    const name_end = try checkedEnd(name_start, name_len, central_end);
    const extra_end = try checkedEnd(name_end, extra_len, central_end);
    const next_offset = try checkedEnd(extra_end, comment_len, central_end);
    const values = try records.resolveCentralEntry(
        archive.bytes[name_end..extra_end],
        compressed_u32,
        uncompressed_u32,
        local_offset_u32,
        disk_start_u16,
    );
    const parsed_aes = try records.parseWinZipAesExtra(archive.bytes[name_end..extra_end]);
    const raw_name = archive.bytes[name_start..name_end];
    const raw_comment = archive.bytes[extra_end..next_offset];
    const central_unicode_name = try records.parseUnicodePathExtra(
        archive.bytes[name_end..extra_end],
        raw_name,
    );
    const unicode_comment = try records.parseUnicodeCommentExtra(
        archive.bytes[name_end..extra_end],
        raw_comment,
    );
    const central_extended_timestamp = try records.parseExtendedTimestampExtra(
        archive.bytes[name_end..extra_end],
        .central,
    );
    const central_ntfs_timestamp = try records.parseNtfsTimestampExtra(
        archive.bytes[name_end..extra_end],
    );
    const parsed_strong = try records.parsePkwareStrongEncryptionExtra(
        archive.bytes[name_end..extra_end],
    );
    if ((wire_method == .aes) != (parsed_aes != null)) return error.InvalidZipArchive;
    if (parsed_aes != null and flags & wire.encrypted_flag == 0)
        return error.InvalidZipArchive;
    if (parsed_aes != null and parsed_strong != null) return error.InvalidZipArchive;
    const strong_flag = flags & wire.strong_encryption_flag != 0;
    if (strong_flag != (parsed_strong != null) or
        (strong_flag and flags & wire.encrypted_flag == 0))
        return error.InvalidZipArchive;
    const method = if (parsed_aes) |aes| aes.actual_method else wire_method;
    if (parsed_aes != null and version_needed < wire.version_51)
        return error.InvalidZipArchive;
    if (parsed_strong != null and version_needed < wire.version_51)
        return error.InvalidZipArchive;
    if (values.zip64 and version_needed < 45) return error.InvalidZipArchive;
    if (method == .bzip2 and version_needed < 46) return error.InvalidZipArchive;
    if (method == .lzma and version_needed < 63) return error.InvalidZipArchive;
    if (method == .ppmd and version_needed < 63) return error.InvalidZipArchive;
    if (isZstandardMethod(method) and version_needed < 63)
        return error.InvalidZipArchive;
    if (values.local_header_offset >= archive.central_directory_offset) return error.InvalidZipArchive;
    const local_metadata = try parseLocalMetadata(
        archive,
        values.local_header_offset,
    );
    const extended_timestamp = try records.mergeExtendedTimestamps(
        local_metadata.extended,
        central_extended_timestamp,
    );
    const ntfs_timestamp = try records.mergeNtfsTimestamps(
        local_metadata.ntfs,
        central_ntfs_timestamp,
    );
    const unicode_name = try records.mergeUnicodeText(
        local_metadata.unicode_name,
        central_unicode_name,
    );

    return .{
        .entry = .{
            .name = raw_name,
            .comment = raw_comment,
            .unicode_name = unicode_name,
            .unicode_comment = unicode_comment,
            .method = method,
            .flags = flags,
            .crc32 = crc,
            .compressed_size = values.compressed_size,
            .uncompressed_size = values.uncompressed_size,
            .local_header_offset = values.local_header_offset,
            .central_header_offset = offset,
            .zip64 = values.zip64,
            .modified = modified,
            .extended_timestamp = extended_timestamp,
            .ntfs_timestamp = ntfs_timestamp,
            .version_made_by = version_made_by,
            .internal_attributes = internal_attributes,
            .external_attributes = external_attributes,
            .winzip_aes = if (parsed_aes) |aes| aes.info else null,
            .pkware_strong_encryption = parsed_strong,
        },
        .next_offset = next_offset,
    };
}

const LocalPayload = struct {
    data: []const u8,
    dos_time: u16,
};

fn localCompressedData(archive: Archive, entry: Entry) Error![]const u8 {
    return (try localPayloadData(archive, entry, false)).data;
}

fn localPayloadData(
    archive: Archive,
    entry: Entry,
    allow_encrypted: bool,
) Error!LocalPayload {
    const offset = entry.local_header_offset;
    if (try readU32(archive.bytes, offset) != local_file_signature) return error.InvalidZipArchive;
    _ = try checkedEnd(offset, 30, archive.central_directory_offset);
    const local_flags = try readU16(archive.bytes, offset + 6);
    const local_version_needed = try readU16(archive.bytes, offset + 4);
    const local_method: CompressionMethod = @enumFromInt(try readU16(archive.bytes, offset + 8));
    const local_dos_time = try readU16(archive.bytes, offset + 10);
    const local_dos_date = try readU16(archive.bytes, offset + 12);
    const local_crc = try readU32(archive.bytes, offset + 14);
    const local_compressed = try readU32(archive.bytes, offset + 18);
    const local_uncompressed = try readU32(archive.bytes, offset + 22);
    const name_len: usize = try readU16(archive.bytes, offset + 26);
    const extra_len: usize = try readU16(archive.bytes, offset + 28);
    const name_start = offset + 30;
    const name_end = try checkedEnd(name_start, name_len, archive.central_directory_offset);
    const local_extra_start = name_end;
    const data_start = try checkedEnd(local_extra_start, extra_len, archive.central_directory_offset);
    const local_aes = try records.parseWinZipAesExtra(archive.bytes[local_extra_start..data_start]);
    const local_extended_timestamp = try records.parseExtendedTimestampExtra(
        archive.bytes[local_extra_start..data_start],
        .local,
    );
    const local_ntfs_timestamp = try records.parseNtfsTimestampExtra(
        archive.bytes[local_extra_start..data_start],
    );
    const local_unicode_name = try records.parseUnicodePathExtra(
        archive.bytes[local_extra_start..data_start],
        archive.bytes[name_start..name_end],
    );
    const local_strong = try records.parsePkwareStrongEncryptionExtra(
        archive.bytes[local_extra_start..data_start],
    );
    if (local_strong != null) return error.InvalidZipArchive;
    if ((local_method == .aes) != (local_aes != null)) return error.InvalidZipArchive;
    if (entry.winzip_aes) |expected_aes| {
        const actual_aes = local_aes orelse return error.InvalidZipArchive;
        if (!std.meta.eql(expected_aes, actual_aes.info) or actual_aes.actual_method != entry.method)
            return error.InvalidZipArchive;
    } else if (local_aes != null or local_method != entry.method) {
        return error.InvalidZipArchive;
    }
    const compared_flags: u16 = 0x0049 | switch (entry.method) {
        .lzma => @as(u16, 0x0002),
        .implode => @as(u16, 0x0006),
        else => @as(u16, 0),
    };
    if ((local_flags ^ entry.flags) & compared_flags != 0) return error.InvalidZipArchive;
    if (local_flags & wire.encrypted_flag != 0 and !allow_encrypted)
        return error.EncryptedZipEntry;

    if (!std.mem.eql(u8, archive.bytes[name_start..name_end], entry.name) or
        local_dos_time != entry.modified.time or local_dos_date != entry.modified.date)
        return error.InvalidZipArchive;
    _ = try records.mergeExtendedTimestamps(
        local_extended_timestamp,
        entry.extended_timestamp,
    );
    _ = try records.mergeNtfsTimestamps(local_ntfs_timestamp, entry.ntfs_timestamp);
    _ = try records.mergeUnicodeText(local_unicode_name, entry.unicode_name);
    const data_end = try checkedEnd(data_start, entry.compressed_size, archive.central_directory_offset);
    if ((local_compressed == std.math.maxInt(u32) or local_uncompressed == std.math.maxInt(u32)) and
        local_version_needed < 45) return error.InvalidZipArchive;
    if (entry.method == .bzip2 and local_version_needed < 46) return error.InvalidZipArchive;
    if (entry.method == .lzma and local_version_needed < 63) return error.InvalidZipArchive;
    if (entry.method == .ppmd and local_version_needed < 63) return error.InvalidZipArchive;
    if (entry.winzip_aes != null and local_version_needed < wire.version_51)
        return error.InvalidZipArchive;
    if (entry.pkware_strong_encryption != null and local_version_needed < wire.version_51)
        return error.InvalidZipArchive;
    if (isZstandardMethod(entry.method) and local_version_needed < 63)
        return error.InvalidZipArchive;
    if (local_flags & 0x0008 == 0) {
        const local_sizes = try records.resolveLocalSizes(
            archive.bytes[name_end..data_start],
            local_compressed,
            local_uncompressed,
        );
        if (local_crc != entry.crc32 or
            local_sizes.compressed_size != entry.compressed_size or
            local_sizes.uncompressed_size != entry.uncompressed_size)
            return error.InvalidZipArchive;
    }
    return .{
        .data = archive.bytes[data_start..data_end],
        .dos_time = local_dos_time,
    };
}

fn sameEntry(a: Entry, b: Entry) bool {
    return std.mem.eql(u8, a.name, b.name) and
        std.mem.eql(u8, a.comment, b.comment) and
        optionalSlicesEqual(a.unicode_name, b.unicode_name) and
        optionalSlicesEqual(a.unicode_comment, b.unicode_comment) and
        a.method == b.method and
        a.flags == b.flags and
        a.crc32 == b.crc32 and
        a.compressed_size == b.compressed_size and
        a.uncompressed_size == b.uncompressed_size and
        a.local_header_offset == b.local_header_offset and
        a.central_header_offset == b.central_header_offset and
        a.zip64 == b.zip64 and
        std.meta.eql(a.modified, b.modified) and
        std.meta.eql(a.extended_timestamp, b.extended_timestamp) and
        std.meta.eql(a.ntfs_timestamp, b.ntfs_timestamp) and
        a.version_made_by == b.version_made_by and
        a.internal_attributes == b.internal_attributes and
        a.external_attributes == b.external_attributes and
        std.meta.eql(a.winzip_aes, b.winzip_aes) and
        std.meta.eql(a.pkware_strong_encryption, b.pkware_strong_encryption);
}

fn optionalSlicesEqual(a: ?[]const u8, b: ?[]const u8) bool {
    if (a == null or b == null) return a == null and b == null;
    return std.mem.eql(u8, a.?, b.?);
}

fn readU16(bytes: []const u8, offset: usize) Error!u16 {
    _ = try checkedEnd(offset, 2, bytes.len);
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn isZstandardMethod(method: CompressionMethod) bool {
    return method == .zstandard_legacy or method == .zstandard;
}

fn reduceFactor(method: CompressionMethod) ?reduce.Factor {
    return switch (method) {
        .reduce_1 => .factor_1,
        .reduce_2 => .factor_2,
        .reduce_3 => .factor_3,
        .reduce_4 => .factor_4,
        else => null,
    };
}

fn readU32(bytes: []const u8, offset: usize) Error!u32 {
    _ = try checkedEnd(offset, 4, bytes.len);
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = std.math.add(usize, start, len) catch return error.InvalidZipArchive;
    if (end > limit) return error.InvalidZipArchive;
    return end;
}

const TestEntry = struct {
    name: []const u8,
    payload: []const u8,
    compressed: []const u8,
    method: u16,
    flags: u16,
    local_offset: usize,
};

fn appendU16(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u16) !void {
    var bytes: [2]u8 = undefined;
    std.mem.writeInt(u16, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendU32(out: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u32) !void {
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    try out.appendSlice(allocator, &bytes);
}

fn appendTestLocal(out: *std.ArrayList(u8), allocator: std.mem.Allocator, entry: *TestEntry) !void {
    entry.local_offset = out.items.len;
    const descriptor = entry.flags & 0x0008 != 0;
    try appendU32(out, allocator, local_file_signature);
    try appendU16(out, allocator, 20);
    try appendU16(out, allocator, entry.flags);
    try appendU16(out, allocator, entry.method);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU32(out, allocator, if (descriptor) 0 else checksum.crc32(entry.payload));
    try appendU32(out, allocator, if (descriptor) 0 else @intCast(entry.compressed.len));
    try appendU32(out, allocator, if (descriptor) 0 else @intCast(entry.payload.len));
    try appendU16(out, allocator, @intCast(entry.name.len));
    try appendU16(out, allocator, 0);
    try out.appendSlice(allocator, entry.name);
    try out.appendSlice(allocator, entry.compressed);
    if (descriptor) {
        try appendU32(out, allocator, 0x0807_4b50);
        try appendU32(out, allocator, checksum.crc32(entry.payload));
        try appendU32(out, allocator, @intCast(entry.compressed.len));
        try appendU32(out, allocator, @intCast(entry.payload.len));
    }
}

fn appendTestCentral(out: *std.ArrayList(u8), allocator: std.mem.Allocator, entry: TestEntry) !void {
    try appendU32(out, allocator, central_file_signature);
    try appendU16(out, allocator, 20);
    try appendU16(out, allocator, 20);
    try appendU16(out, allocator, entry.flags);
    try appendU16(out, allocator, entry.method);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU32(out, allocator, checksum.crc32(entry.payload));
    try appendU32(out, allocator, @intCast(entry.compressed.len));
    try appendU32(out, allocator, @intCast(entry.payload.len));
    try appendU16(out, allocator, @intCast(entry.name.len));
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU16(out, allocator, 0);
    try appendU32(out, allocator, 0);
    try appendU32(out, allocator, @intCast(entry.local_offset));
    try out.appendSlice(allocator, entry.name);
}

test "ZIP parses and extracts stored and descriptor-backed deflate entries" {
    const allocator = std.testing.allocator;
    const stored_payload = "hello zip";
    const deflated_payload = "deflated payload " ** 32;
    const compressed = try deflate.encodeRawFixedAlloc(allocator, deflated_payload);
    defer allocator.free(compressed);
    var entries = [_]TestEntry{
        .{ .name = "hello.txt", .payload = stored_payload, .compressed = stored_payload, .method = 0, .flags = 0, .local_offset = 0 },
        .{ .name = "data.bin", .payload = deflated_payload, .compressed = compressed, .method = 8, .flags = 0x0008, .local_offset = 0 },
    };
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(allocator);
    for (&entries) |*entry| try appendTestLocal(&bytes, allocator, entry);
    const central_offset = bytes.items.len;
    for (entries) |entry| try appendTestCentral(&bytes, allocator, entry);
    const central_size = bytes.items.len - central_offset;
    try appendU32(&bytes, allocator, end_of_central_signature);
    try appendU16(&bytes, allocator, 0);
    try appendU16(&bytes, allocator, 0);
    try appendU16(&bytes, allocator, entries.len);
    try appendU16(&bytes, allocator, entries.len);
    try appendU32(&bytes, allocator, @intCast(central_size));
    try appendU32(&bytes, allocator, @intCast(central_offset));
    try appendU16(&bytes, allocator, 4);
    try bytes.appendSlice(allocator, "test");

    const archive = try parse(bytes.items);
    try std.testing.expectEqual(@as(usize, 2), archive.entry_count);
    try std.testing.expectEqualStrings("test", archive.comment);
    const listed = try archive.entriesAlloc(allocator);
    defer allocator.free(listed);
    try std.testing.expectEqualStrings("hello.txt", listed[0].name);
    try std.testing.expectEqual(CompressionMethod.stored, listed[0].method);
    try std.testing.expectEqualStrings("data.bin", listed[1].name);
    try std.testing.expectEqual(CompressionMethod.deflate, listed[1].method);

    var stored_output: [stored_payload.len]u8 = undefined;
    try std.testing.expectEqual(stored_payload.len, try archive.extractInto(listed[0], &stored_output));
    try std.testing.expectEqualSlices(u8, stored_payload, &stored_output);
    const decoded = try archive.extractByNameAlloc(allocator, "data.bin");
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, deflated_payload, decoded);
    try std.testing.expectError(error.OutputTooSmall, archive.extractInto(listed[1], stored_output[0..]));
    try std.testing.expectError(error.OutputLimitExceeded, archive.extractAllocLimited(allocator, listed[1], deflated_payload.len - 1));
    try std.testing.expectError(error.ZipEntryNotFound, archive.extractByNameAlloc(allocator, "missing"));
    try std.testing.expectError(error.RangeOutOfBounds, archive.entryAt(2));

    var corrupt = try allocator.dupe(u8, bytes.items);
    defer allocator.free(corrupt);
    corrupt[listed[1].central_header_offset + 16] ^= 1;
    const corrupt_archive = try parse(corrupt);
    const corrupt_entry = try corrupt_archive.entryAt(1);
    var corrupt_output: [deflated_payload.len]u8 = undefined;
    try std.testing.expectError(error.ChecksumMismatch, corrupt_archive.extractInto(corrupt_entry, &corrupt_output));

    var encrypted = try allocator.dupe(u8, bytes.items);
    defer allocator.free(encrypted);
    encrypted[entries[0].local_offset + 6] |= 1;
    encrypted[listed[0].central_header_offset + 8] |= 1;
    const encrypted_archive = try parse(encrypted);
    const encrypted_entry = try encrypted_archive.entryAt(0);
    var encrypted_output: [stored_payload.len]u8 = undefined;
    try std.testing.expectError(error.EncryptedZipEntry, encrypted_archive.extractInto(encrypted_entry, &encrypted_output));

    var unsupported = try allocator.dupe(u8, bytes.items);
    defer allocator.free(unsupported);
    std.mem.writeInt(u16, unsupported[entries[0].local_offset + 8 ..][0..2], 200, .little);
    std.mem.writeInt(u16, unsupported[listed[0].central_header_offset + 10 ..][0..2], 200, .little);
    const unsupported_archive = try parse(unsupported);
    const unsupported_entry = try unsupported_archive.entryAt(0);
    try std.testing.expectError(error.UnsupportedZipCompressionMethod, unsupported_archive.extractInto(unsupported_entry, &encrypted_output));

    var zip64 = try allocator.dupe(u8, bytes.items);
    defer allocator.free(zip64);
    std.mem.writeInt(u32, zip64[listed[0].central_header_offset + 20 ..][0..4], std.math.maxInt(u32), .little);
    const zip64_archive = try parse(zip64);
    try std.testing.expectError(error.InvalidZipArchive, zip64_archive.entryAt(0));

    var mismatched_name = try allocator.dupe(u8, bytes.items);
    defer allocator.free(mismatched_name);
    mismatched_name[entries[0].local_offset + 30] ^= 1;
    const mismatch_archive = try parse(mismatched_name);
    const mismatch_entry = try mismatch_archive.entryAt(0);
    try std.testing.expectError(error.InvalidZipArchive, mismatch_archive.extractInto(mismatch_entry, &encrypted_output));
}

test "ZIP rejects unsupported archive and entry features" {
    try std.testing.expectError(error.InvalidZipArchive, parse("not a zip"));

    var empty: [end_of_central_len]u8 = @splat(0);
    std.mem.writeInt(u32, empty[0..4], end_of_central_signature, .little);
    const archive = try parse(&empty);
    try std.testing.expectEqual(@as(usize, 0), archive.entry_count);

    std.mem.writeInt(u16, empty[4..6], 1, .little);
    try std.testing.expectError(error.UnsupportedZipFeature, parse(&empty));
}

test "ZIP writer deterministically round trips multiple stored and deflate entries" {
    const allocator = std.testing.allocator;
    const deflated_payload = "deterministic ZIP writer payload\n" ** 64;
    const lzma_payload = "deterministic ZIP LZMA payload\n" ** 64;
    const entries = [_]EncodeEntry{
        .{ .name = "plain.bin", .data = "\x00stored\xff", .method = .stored, .comment = "stored entry" },
        .{ .name = "utf8-目录/data.txt", .data = deflated_payload, .method = .deflate },
        .{ .name = "lzma.txt", .data = lzma_payload, .method = .lzma },
        .{ .name = "empty/", .data = "", .method = .stored },
    };
    const options = EncodeOptions{
        .archive_comment = "vort deterministic archive",
        .data_descriptor = true,
    };
    const first = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(first);
    const second = try encodeAlloc(allocator, &entries, options);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);

    const archive = try parse(first);
    try std.testing.expectEqual(@as(usize, entries.len), archive.entry_count);
    try std.testing.expectEqualStrings(options.archive_comment, archive.comment);
    var it = archive.iterator();
    var index: usize = 0;
    while (try it.next()) |entry| : (index += 1) {
        try std.testing.expectEqualStrings(entries[index].name, entry.name);
        try std.testing.expectEqualStrings(entries[index].comment, entry.comment);
        try std.testing.expectEqual(entries[index].method, entry.method);
        try std.testing.expect(entry.flags & 0x0008 != 0);
        try std.testing.expect(entry.flags & 0x0800 != 0);
        if (entry.method == .lzma) {
            try std.testing.expect(entry.flags & 0x0002 != 0);
            try std.testing.expectEqual(@as(u16, 63), try readU16(first, entry.local_header_offset + 4));
        }
        try std.testing.expectEqual(@as(u16, 0), try readU16(first, entry.local_header_offset + 10));
        try std.testing.expectEqual(@as(u16, 0x0021), try readU16(first, entry.local_header_offset + 12));
        const decoded = try archive.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, entries[index].data, decoded);
    }
    try std.testing.expectEqual(entries.len, index);
}

test "ZIP entry metadata round trips comments timestamps and Unix attributes" {
    const allocator = std.testing.allocator;
    try std.testing.expectEqual(@as(u64, 0), try fileTimeFromUnixSeconds(-11_644_473_600));
    try std.testing.expectEqual(@as(i64, -11_644_473_600), try fileTimeToUnixSeconds(0));
    try std.testing.expectError(
        error.InvalidZipTimestamp,
        fileTimeFromUnixSeconds(-11_644_473_601),
    );
    const central_only_extended = [_]u8{
        0x55, 0x54, 0x05, 0x00, 0x03, 0x01, 0x00, 0x00, 0x00,
    };
    const parsed_central_extended = (try records.parseExtendedTimestampExtra(
        &central_only_extended,
        .central,
    )).?;
    try std.testing.expectEqual(@as(?i64, 1), parsed_central_extended.modified);
    try std.testing.expectEqual(@as(?i64, null), parsed_central_extended.accessed);
    try std.testing.expectError(
        error.InvalidZipArchive,
        records.parseExtendedTimestampExtra(&central_only_extended, .local),
    );
    const invalid_extended_flags = [_]u8{ 0x55, 0x54, 0x01, 0x00, 0x08 };
    try std.testing.expectError(
        error.InvalidZipArchive,
        records.parseExtendedTimestampExtra(&invalid_extended_flags, .central),
    );
    const invalid_extended_trailing = [_]u8{
        0x55, 0x54, 0x06, 0x00, 0x01, 1, 0, 0, 0, 0xff,
    };
    try std.testing.expectError(
        error.InvalidZipArchive,
        records.parseExtendedTimestampExtra(&invalid_extended_trailing, .local),
    );
    const duplicate_extended = central_only_extended ++ central_only_extended;
    try std.testing.expectError(
        error.InvalidZipArchive,
        records.parseExtendedTimestampExtra(&duplicate_extended, .central),
    );
    const invalid_ntfs = [_]u8{
        0x0a, 0x00, 0x08, 0x00, 0, 0, 0, 0, 1, 0, 0, 0,
    };
    try std.testing.expectError(
        error.InvalidZipArchive,
        records.parseNtfsTimestampExtra(&invalid_ntfs),
    );
    const truncated_unicode_path = [_]u8{
        0x75, 0x70, 0x04, 0x00, 1, 0, 0, 0,
    };
    try std.testing.expectError(
        error.InvalidZipArchive,
        records.parseUnicodePathExtra(&truncated_unicode_path, "raw"),
    );
    try std.testing.expectError(
        error.InvalidZipTimestamp,
        DosTimestamp.fromComponents(.{
            .year = 2023,
            .month = 2,
            .day = 29,
            .hour = 0,
            .minute = 0,
            .second = 0,
        }),
    );
    const modified = try DosTimestamp.fromComponents(.{
        .year = 2026,
        .month = 10,
        .day = 17,
        .hour = 1,
        .minute = 23,
        .second = 45,
    });
    const extended: ExtendedTimestamp = .{
        .modified = 1_700_000_001,
        .accessed = 1_700_000_002,
        .created = -1,
    };
    const ntfs: NtfsTimestamp = .{
        .modified = try fileTimeFromUnixSeconds(1_700_000_011),
        .accessed = try fileTimeFromUnixSeconds(1_700_000_002),
        .created = try fileTimeFromUnixSeconds(-1),
    };
    try std.testing.expectEqual(
        @as(i64, 1_700_000_011),
        try fileTimeToUnixSeconds(ntfs.modified),
    );
    const entries = [_]EncodeEntry{
        .{
            .name = "legacy-regular.txt",
            .unicode_name = "目录/常规.txt",
            .data = "metadata payload",
            .method = .stored,
            .comment = "entry comment",
            .unicode_comment = "条目注释",
            .modified = modified,
            .extended_timestamp = extended,
            .ntfs_timestamp = ntfs,
            .creator_system = .unix,
            .internal_attributes = 1,
            .external_attributes = unixExternalAttributes(0o100640),
        },
        .{
            .name = "legacy-link",
            .unicode_name = "链接",
            .data = "legacy-regular.txt",
            .method = .stored,
            .comment = "symbolic link",
            .modified = modified,
            .extended_timestamp = .{ .modified = 1_600_000_001 },
            .creator_system = .unix,
            .external_attributes = unixExternalAttributes(0o120777),
        },
        .{
            .name = "legacy-directory/",
            .unicode_name = "目录/",
            .data = "",
            .method = .stored,
            .modified = modified,
            .ntfs_timestamp = ntfs,
            .creator_system = .unix,
            .external_attributes = unixExternalAttributes(0o040755),
        },
    };

    inline for (.{ Zip64Mode.never, .always }) |zip64_mode| {
        inline for (.{ false, true }) |descriptor_mode| {
            const bytes = try encodeAlloc(allocator, &entries, .{
                .zip64 = zip64_mode,
                .data_descriptor = descriptor_mode,
                .utf8 = false,
            });
            defer allocator.free(bytes);
            const archive = try parse(bytes);
            try std.testing.expect((try archive.find("目录/常规.txt")) != null);
            try std.testing.expect((try archive.findRaw(entries[0].name)) != null);
            try std.testing.expect((try archive.findRaw("目录/常规.txt")) == null);
            for (entries, 0..) |expected, index| {
                const entry = try archive.entryAt(index);
                try std.testing.expectEqualStrings(expected.comment, entry.comment);
                try std.testing.expectEqualStrings(expected.unicode_name.?, entry.unicode_name.?);
                if (expected.unicode_comment) |unicode_comment| {
                    try std.testing.expectEqualStrings(unicode_comment, entry.unicode_comment.?);
                } else {
                    try std.testing.expect(entry.unicode_comment == null);
                }
                try std.testing.expectEqualStrings(
                    expected.unicode_name orelse expected.name,
                    entry.preferredName(),
                );
                try std.testing.expectEqualStrings(
                    expected.unicode_comment orelse expected.comment,
                    entry.preferredComment(),
                );
                try std.testing.expectEqual(modified, entry.modified);
                try std.testing.expectEqual(expected.extended_timestamp, entry.extended_timestamp);
                try std.testing.expectEqual(expected.ntfs_timestamp, entry.ntfs_timestamp);
                if (index == 0)
                    try std.testing.expectEqual(@as(?i64, 1_700_000_011), entry.modifiedUnixSeconds());
                try std.testing.expectEqual(CreatorSystem.unix, entry.creatorSystem());
                try std.testing.expectEqual(expected.internal_attributes, entry.internal_attributes);
                try std.testing.expectEqual(expected.external_attributes.?, entry.external_attributes);
                try std.testing.expectEqual(
                    @as(?u16, @truncate(expected.external_attributes.? >> 16)),
                    entry.unixMode(),
                );
                try std.testing.expectEqual(index == 1, entry.isSymbolicLink());
                try std.testing.expectEqual(index == 2, entry.isDirectory());
                if (index == 0) {
                    const local_name_len: usize = try readU16(
                        bytes,
                        entry.local_header_offset + 26,
                    );
                    const local_extra_len: usize = try readU16(
                        bytes,
                        entry.local_header_offset + 28,
                    );
                    const local_extra_start = entry.local_header_offset +
                        wire.local_file_header_len + local_name_len;
                    const local_extra = bytes[local_extra_start..][0..local_extra_len];
                    try std.testing.expectEqual(
                        @as(usize, 13),
                        (try records.findExtra(
                            local_extra,
                            wire.extended_timestamp_extra_id,
                        )).?.len,
                    );
                    try std.testing.expectEqual(
                        @as(usize, 32),
                        (try records.findExtra(
                            local_extra,
                            wire.ntfs_timestamp_extra_id,
                        )).?.len,
                    );

                    const central_name_len: usize = try readU16(
                        bytes,
                        entry.central_header_offset + 28,
                    );
                    const central_extra_len: usize = try readU16(
                        bytes,
                        entry.central_header_offset + 30,
                    );
                    const central_extra_start = entry.central_header_offset +
                        wire.central_file_header_len + central_name_len;
                    const central_extra = bytes[central_extra_start..][0..central_extra_len];
                    const central_extended = (try records.findExtra(
                        central_extra,
                        wire.extended_timestamp_extra_id,
                    )).?;
                    try std.testing.expectEqual(@as(usize, 5), central_extended.len);
                    try std.testing.expectEqual(@as(u8, 0x07), central_extended[0]);
                    try std.testing.expectEqual(
                        @as(usize, 32),
                        (try records.findExtra(
                            central_extra,
                            wire.ntfs_timestamp_extra_id,
                        )).?.len,
                    );
                    const local_unicode = (try records.findExtra(
                        local_extra,
                        wire.unicode_path_extra_id,
                    )).?;
                    const central_unicode = (try records.findExtra(
                        central_extra,
                        wire.unicode_path_extra_id,
                    )).?;
                    const central_unicode_comment = (try records.findExtra(
                        central_extra,
                        wire.unicode_comment_extra_id,
                    )).?;
                    for ([_][]const u8{ local_unicode, central_unicode }) |payload| {
                        try std.testing.expectEqual(@as(u8, 1), payload[0]);
                        try std.testing.expectEqual(
                            checksum.crc32Best(entry.name),
                            std.mem.readInt(u32, payload[1..5], .little),
                        );
                        try std.testing.expectEqualStrings(entry.unicode_name.?, payload[5..]);
                    }
                    try std.testing.expectEqual(
                        checksum.crc32Best(entry.comment),
                        std.mem.readInt(u32, central_unicode_comment[1..5], .little),
                    );
                    try std.testing.expectEqualStrings(
                        entry.unicode_comment.?,
                        central_unicode_comment[5..],
                    );

                    const local_unicode_offset = @intFromPtr(local_unicode.ptr) -
                        @intFromPtr(bytes.ptr);
                    const central_unicode_offset = @intFromPtr(central_unicode.ptr) -
                        @intFromPtr(bytes.ptr);
                    const unicode_field = bytes[central_unicode_offset - 4 .. central_unicode_offset + central_unicode.len];
                    const duplicate_unicode = try std.mem.concat(
                        allocator,
                        u8,
                        &.{ unicode_field, unicode_field },
                    );
                    defer allocator.free(duplicate_unicode);
                    try std.testing.expectError(
                        error.InvalidZipArchive,
                        records.parseUnicodePathExtra(duplicate_unicode, entry.name),
                    );
                    var ignored_crc = try allocator.dupe(u8, bytes);
                    defer allocator.free(ignored_crc);
                    ignored_crc[local_unicode_offset + 1] ^= 1;
                    ignored_crc[central_unicode_offset + 1] ^= 1;
                    const ignored_crc_entry = try (try parse(ignored_crc)).entryAt(0);
                    try std.testing.expect(ignored_crc_entry.unicode_name == null);
                    try std.testing.expectEqualStrings(
                        entries[0].name,
                        ignored_crc_entry.preferredName(),
                    );

                    var ignored_version = try allocator.dupe(u8, bytes);
                    defer allocator.free(ignored_version);
                    ignored_version[local_unicode_offset] = 2;
                    ignored_version[central_unicode_offset] = 2;
                    const ignored_version_entry = try (try parse(ignored_version)).entryAt(0);
                    try std.testing.expect(ignored_version_entry.unicode_name == null);

                    var authoritative_utf8 = try allocator.dupe(u8, bytes);
                    defer allocator.free(authoritative_utf8);
                    const local_flags = std.mem.readInt(
                        u16,
                        authoritative_utf8[entry.local_header_offset + 6 ..][0..2],
                        .little,
                    ) | wire.utf8_flag;
                    const central_flags = std.mem.readInt(
                        u16,
                        authoritative_utf8[entry.central_header_offset + 8 ..][0..2],
                        .little,
                    ) | wire.utf8_flag;
                    std.mem.writeInt(
                        u16,
                        authoritative_utf8[entry.local_header_offset + 6 ..][0..2],
                        local_flags,
                        .little,
                    );
                    std.mem.writeInt(
                        u16,
                        authoritative_utf8[entry.central_header_offset + 8 ..][0..2],
                        central_flags,
                        .little,
                    );
                    const authoritative_entry = try (try parse(authoritative_utf8)).entryAt(0);
                    try std.testing.expectEqualStrings(
                        entries[0].name,
                        authoritative_entry.preferredName(),
                    );

                    var conflicting_unicode = try allocator.dupe(u8, bytes);
                    defer allocator.free(conflicting_unicode);
                    conflicting_unicode[central_unicode_offset + central_unicode.len - 1] ^= 1;
                    try std.testing.expectError(
                        error.InvalidZipArchive,
                        (try parse(conflicting_unicode)).entryAt(0),
                    );

                    var invalid_unicode = try allocator.dupe(u8, bytes);
                    defer allocator.free(invalid_unicode);
                    invalid_unicode[central_unicode_offset + 5] = 0xff;
                    try std.testing.expectError(
                        error.InvalidZipArchive,
                        (try parse(invalid_unicode)).entryAt(0),
                    );
                    var corrupt_timestamp = try allocator.dupe(u8, bytes);
                    defer allocator.free(corrupt_timestamp);
                    const timestamp_offset = @intFromPtr(central_extended.ptr) -
                        @intFromPtr(bytes.ptr);
                    corrupt_timestamp[timestamp_offset + 1] ^= 1;
                    const corrupt_timestamp_archive = try parse(corrupt_timestamp);
                    try std.testing.expectError(
                        error.InvalidZipArchive,
                        corrupt_timestamp_archive.entryAt(0),
                    );
                }
                const decoded = try archive.extractAlloc(allocator, entry);
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, expected.data, decoded);
            }
            const components = try (try archive.entryAt(0)).modified.components();
            try std.testing.expectEqual(@as(u8, 44), components.second);

            var corrupt = try allocator.dupe(u8, bytes);
            defer allocator.free(corrupt);
            const first = try archive.entryAt(0);
            corrupt[first.local_header_offset + 10] ^= 1;
            const corrupt_archive = try parse(corrupt);
            const corrupt_entry = try corrupt_archive.entryAt(0);
            try std.testing.expectError(
                error.InvalidZipArchive,
                corrupt_archive.compressedData(corrupt_entry),
            );
        }
    }

    const invalid = [_]EncodeEntry{.{
        .name = "invalid-time",
        .data = "",
        .modified = .{ .time = 0xffff, .date = 0 },
    }};
    try std.testing.expectError(
        error.InvalidZipTimestamp,
        encodeAlloc(allocator, &invalid, .{}),
    );
    const invalid_extended = [_]EncodeEntry{.{
        .name = "invalid-extended-time",
        .data = "",
        .extended_timestamp = .{},
    }};
    try std.testing.expectError(
        error.InvalidZipTimestamp,
        encodeAlloc(allocator, &invalid_extended, .{}),
    );
    const conflicting_encoding = [_]EncodeEntry{.{
        .name = "legacy-name",
        .unicode_name = "Unicode 名称",
        .data = "",
    }};
    try std.testing.expectError(
        error.InvalidZipTextEncoding,
        encodeAlloc(allocator, &conflicting_encoding, .{}),
    );
    const invalid_unicode = [_]EncodeEntry{.{
        .name = "legacy-name",
        .unicode_name = "\xff",
        .data = "",
    }};
    try std.testing.expectError(
        error.InvalidZipTextEncoding,
        encodeAlloc(allocator, &invalid_unicode, .{ .utf8 = false }),
    );
}

test "ZIP writer and reader round trip Traditional ZipCrypto entries" {
    const allocator = std.testing.allocator;
    const password = "zip-password-密码";
    const modified = try DosTimestamp.fromComponents(.{
        .year = 2022,
        .month = 11,
        .day = 12,
        .hour = 21,
        .minute = 34,
        .second = 56,
    });
    const stored_payload = "encrypted stored payload";
    const deflated_payload = "encrypted Deflate payload\n" ** 97;
    const entries = [_]EncodeEntry{
        .{
            .name = "encrypted-stored.bin",
            .data = stored_payload,
            .method = .stored,
            .modified = modified,
            .traditional_encryption = .{
                .password = password,
                .header_random = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            },
        },
        .{
            .name = "encrypted-deflate.txt",
            .data = deflated_payload,
            .method = .deflate,
            .traditional_encryption = .{
                .password = password,
                .header_random = .{ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 },
            },
        },
    };

    inline for (.{ false, true }) |descriptor| {
        const options = EncodeOptions{ .data_descriptor = descriptor };
        const bytes = try encodeAlloc(allocator, &entries, options);
        defer allocator.free(bytes);
        const repeated = try encodeAlloc(allocator, &entries, options);
        defer allocator.free(repeated);
        try std.testing.expectEqualSlices(u8, bytes, repeated);

        const archive = try parse(bytes);
        for (entries, 0..) |expected, index| {
            const entry = try archive.entryAt(index);
            try std.testing.expect(entry.isEncrypted());
            try std.testing.expectEqual(descriptor, entry.flags & wire.descriptor_flag != 0);
            try std.testing.expect(entry.compressed_size >= traditional_encryption.header_len);
            try std.testing.expectError(error.EncryptedZipEntry, archive.compressedData(entry));
            try std.testing.expectError(
                error.PasswordRequired,
                archive.extractAllocWithOptions(allocator, entry, .{}),
            );
            try std.testing.expectError(
                error.InvalidZipPassword,
                archive.extractAllocWithOptions(allocator, entry, .{ .password = "wrong" }),
            );
            const decoded = try archive.extractAllocWithOptions(
                allocator,
                entry,
                .{ .password = password },
            );
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, expected.data, decoded);
        }

        var corrupt = try allocator.dupe(u8, bytes);
        defer allocator.free(corrupt);
        const first = try archive.entryAt(0);
        const data_offset = first.local_header_offset + wire.local_file_header_len + first.name.len;
        corrupt[data_offset + traditional_encryption.header_random_len] ^= 1;
        const corrupt_archive = try parse(corrupt);
        const corrupt_entry = try corrupt_archive.entryAt(0);
        try std.testing.expectError(
            error.InvalidZipPassword,
            corrupt_archive.extractAllocWithOptions(
                allocator,
                corrupt_entry,
                .{ .password = password },
            ),
        );

        var corrupt_body = try allocator.dupe(u8, bytes);
        defer allocator.free(corrupt_body);
        corrupt_body[data_offset + traditional_encryption.header_len] ^= 1;
        const corrupt_body_archive = try parse(corrupt_body);
        const corrupt_body_entry = try corrupt_body_archive.entryAt(0);
        try std.testing.expectError(
            error.ChecksumMismatch,
            corrupt_body_archive.extractAllocWithOptions(
                allocator,
                corrupt_body_entry,
                .{ .password = password },
            ),
        );
    }
}

test "ZIP writer and reader round trip WinZip AES entries" {
    const allocator = std.testing.allocator;
    const password = "WinZip AES password 密码";
    const stored_payload = "authenticated stored payload";
    const deflated_payload = "authenticated Deflate payload\n" ** 73;
    const bzip2_payload = "authenticated Bzip2 payload\n" ** 61;
    const salt128 = [_]u8{0x11} ** 8;
    const salt192 = [_]u8{0x22} ** 12;
    const salt256 = [_]u8{0x33} ** 16;
    const entries = [_]EncodeEntry{
        .{
            .name = "aes/stored.bin",
            .data = stored_payload,
            .method = .stored,
            .winzip_aes = .{
                .password = password,
                .strength = .aes128,
                .salt = &salt128,
                .version = .ae1,
            },
        },
        .{
            .name = "aes/deflate.txt",
            .data = deflated_payload,
            .method = .deflate,
            .winzip_aes = .{
                .password = password,
                .strength = .aes192,
                .salt = &salt192,
                .version = .ae2,
            },
        },
        .{
            .name = "aes/bzip2.txt",
            .data = bzip2_payload,
            .method = .bzip2,
            .winzip_aes = .{
                .password = password,
                .strength = .aes256,
                .salt = &salt256,
                .version = .ae1,
            },
        },
    };

    inline for (.{ false, true }) |descriptor| {
        inline for (.{ Zip64Mode.never, Zip64Mode.always }) |zip64_mode| {
            const bytes = try encodeAlloc(allocator, &entries, .{
                .data_descriptor = descriptor,
                .zip64 = zip64_mode,
            });
            defer allocator.free(bytes);
            const archive = try parse(bytes);
            for (entries, 0..) |expected, index| {
                const entry = try archive.entryAt(index);
                try std.testing.expect(entry.isEncrypted());
                try std.testing.expect(entry.isWinZipAes());
                try std.testing.expectEqual(expected.method, entry.method);
                try std.testing.expectEqual(expected.winzip_aes.?.strength, entry.winzip_aes.?.strength);
                try std.testing.expectEqual(expected.winzip_aes.?.version, entry.winzip_aes.?.version);
                try std.testing.expectEqual(@as(u16, 99), try readU16(bytes, entry.local_header_offset + 8));
                try std.testing.expect((try readU16(bytes, entry.local_header_offset + 4)) >= wire.version_51);
                try std.testing.expectEqual(
                    if (entry.winzip_aes.?.version == .ae2)
                        @as(u32, 0)
                    else
                        checksum.crc32Best(expected.data),
                    entry.crc32,
                );
                try std.testing.expectError(error.EncryptedZipEntry, archive.compressedData(entry));
                try std.testing.expectError(
                    error.PasswordRequired,
                    archive.extractAllocWithOptions(allocator, entry, .{}),
                );
                try std.testing.expectError(
                    error.InvalidZipPassword,
                    archive.extractAllocWithOptions(allocator, entry, .{ .password = "wrong" }),
                );
                const decoded = try archive.extractAllocWithOptions(
                    allocator,
                    entry,
                    .{ .password = password },
                );
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, expected.data, decoded);
            }

            const first = try archive.entryAt(0);
            const local_name_len: usize = try readU16(bytes, first.local_header_offset + 26);
            const local_extra_len: usize = try readU16(bytes, first.local_header_offset + 28);
            const data_offset = first.local_header_offset + wire.local_file_header_len +
                local_name_len + local_extra_len;
            const corrupt = try allocator.dupe(u8, bytes);
            defer allocator.free(corrupt);
            corrupt[data_offset + first.compressed_size - 1] ^= 1;
            const corrupt_archive = try parse(corrupt);
            const corrupt_entry = try corrupt_archive.entryAt(0);
            try std.testing.expectError(
                error.InvalidAuthenticationCode,
                corrupt_archive.extractAllocWithOptions(
                    allocator,
                    corrupt_entry,
                    .{ .password = password },
                ),
            );
        }
    }

    const conflict = [_]EncodeEntry{.{
        .name = "conflict.bin",
        .data = "conflict",
        .traditional_encryption = .{
            .password = password,
            .header_random = .{0} ** traditional_encryption.header_random_len,
        },
        .winzip_aes = .{
            .password = password,
            .salt = &salt256,
        },
    }};
    try std.testing.expectError(
        error.ConflictingZipEncryption,
        encodeAlloc(allocator, &conflict, .{}),
    );
}

test "ZIP extracts Rust zip WinZip AES reference entries" {
    const allocator = std.testing.allocator;
    const fixture_hex = std.mem.trim(
        u8,
        @embedFile("zip/testdata/winzip-aes-rust.zip.hex"),
        " \t\r\n",
    );
    const fixture = try allocator.alloc(u8, fixture_hex.len / 2);
    defer allocator.free(fixture);
    _ = try std.fmt.hexToBytes(fixture, fixture_hex);
    const expected = [_]struct {
        name: []const u8,
        data: []const u8,
        method: CompressionMethod,
        strength: WinZipAesStrength,
        version: WinZipAesVendorVersion,
    }{
        .{
            .name = "aes128-stored.txt",
            .data = "Rust AES-128 stored reference payload longer than twenty bytes.",
            .method = .stored,
            .strength = .aes128,
            .version = .ae1,
        },
        .{
            .name = "aes192-deflate.txt",
            .data = "Rust AES-192 Deflate reference payload. Rust AES-192 Deflate reference payload.",
            .method = .deflate,
            .strength = .aes192,
            .version = .ae1,
        },
        .{
            .name = "aes256-small.txt",
            .data = "small",
            .method = .stored,
            .strength = .aes256,
            .version = .ae2,
        },
    };
    const archive = try parse(fixture);
    try std.testing.expectEqual(expected.len, archive.entry_count);
    for (expected, 0..) |reference, index| {
        const entry = try archive.entryAt(index);
        try std.testing.expectEqualStrings(reference.name, entry.name);
        try std.testing.expectEqual(reference.method, entry.method);
        try std.testing.expectEqual(reference.strength, entry.winzip_aes.?.strength);
        try std.testing.expectEqual(reference.version, entry.winzip_aes.?.version);
        try std.testing.expectError(
            error.InvalidZipPassword,
            archive.extractAllocWithOptions(allocator, entry, .{ .password = "wrong" }),
        );
        const decoded = try archive.extractAllocWithOptions(
            allocator,
            entry,
            .{ .password = "rust-reference-password" },
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, reference.data, decoded);
    }
}

const SplitTestFixture = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    parts: [3][]const u8,

    fn deinit(self: *SplitTestFixture) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

const EmptySplitTestFixture = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    parts: [2][]const u8,

    fn deinit(self: *EmptySplitTestFixture) void {
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

const SplitPartSourceContext = struct {
    parts: []const []const u8,
    active_disk: ?usize = null,
    switches: usize = 0,
    releases: usize = 0,
    reads: usize = 0,
    max_read: usize = std.math.maxInt(usize),
    fail_after: ?usize = null,

    fn readAt(
        context: *anyopaque,
        disk: usize,
        offset: usize,
        output: []u8,
    ) error{PartSourceReadFailed}!usize {
        const self: *SplitPartSourceContext = @ptrCast(@alignCast(context));
        if (self.fail_after) |limit| if (self.reads >= limit)
            return error.PartSourceReadFailed;
        self.reads += 1;
        if (disk >= self.parts.len or offset > self.parts[disk].len)
            return error.PartSourceReadFailed;
        if (self.active_disk != disk) {
            if (self.active_disk != null) self.releases += 1;
            self.active_disk = disk;
            self.switches += 1;
        }
        const amount = @min(
            output.len,
            @min(self.max_read, self.parts[disk].len - offset),
        );
        @memcpy(output[0..amount], self.parts[disk][offset..][0..amount]);
        return amount;
    }
};

const SplitTestCut = enum {
    descriptor,
    central_directory,
};

fn drainSplitIncrementalReader(reader: *SplitIncrementalReader) !void {
    var calls: usize = 0;
    while (true) {
        var output: [4096]u8 = undefined;
        const result = try reader.step(&output);
        calls += 1;
        if (calls > 1024 * 1024) return error.TestUnexpectedResult;
        if (result.status == .done) break;
        if (result.status == .need_input) return error.TestUnexpectedResult;
        if (result.progress.input_read == 0 and
            result.progress.output_written == 0 and
            result.status != .entry_header and
            result.status != .entry_done)
            return error.TestUnexpectedResult;
    }
    try reader.finish();
}

const SplitOwnedAllocationTest = struct {
    fn run(
        allocator: std.mem.Allocator,
        parts: []const []const u8,
    ) !void {
        var archive = try parseSplitArchiveAlloc(allocator, parts, .{});
        defer archive.deinit();
    }
};

const SplitReaderAllocationTest = struct {
    fn run(
        allocator: std.mem.Allocator,
        parts: []const []const u8,
    ) !void {
        var reader = try SplitIncrementalReader.initAlloc(
            allocator,
            parts,
            .{ .input_buffer_size = 257 },
        );
        defer reader.deinit();
        try drainSplitIncrementalReader(&reader);
    }
};

const SplitWriterAllocationTest = struct {
    fn run(allocator: std.mem.Allocator) !void {
        const entries = [_]EncodeEntry{.{
            .name = "oom.bin",
            .data = "split writer allocation coverage" ** 4,
            .method = .stored,
        }};
        var encoded = try encodeSplitAlloc(allocator, &entries, .{
            .max_part_size = 80,
        });
        defer encoded.deinit();
    }
};

fn makeSplitTestFixture(
    allocator: std.mem.Allocator,
    source: []const u8,
    cut: SplitTestCut,
) !SplitTestFixture {
    const archive = try parse(source);
    const first = try archive.entryAt(0);
    const second = try archive.entryAt(1);
    const first_name_len: usize = try readU16(source, first.local_header_offset + 26);
    const first_extra_len: usize = try readU16(source, first.local_header_offset + 28);
    const first_data = first.local_header_offset + wire.local_file_header_len +
        first_name_len + first_extra_len;
    const first_descriptor = first_data + first.compressed_size;

    const bytes = try allocator.alloc(u8, source.len + 4);
    errdefer allocator.free(bytes);
    std.mem.writeInt(u32, bytes[0..4], wire.data_descriptor_signature, .little);
    @memcpy(bytes[4..], source);
    const cut1 = 4 + first_data + first.compressed_size / 2;
    const cut2 = switch (cut) {
        .descriptor => 4 + first_descriptor + 5,
        .central_directory => 4 + second.central_header_offset,
    };
    const virtual_central = 4 + archive.central_directory_offset;
    const virtual_central_end = virtual_central + archive.central_directory_size;
    if (cut1 <= 4 or cut1 >= cut2) return error.TestUnexpectedResult;
    switch (cut) {
        .descriptor => if (cut2 >= virtual_central) return error.TestUnexpectedResult,
        .central_directory => if (cut2 <= virtual_central or cut2 >= virtual_central_end)
            return error.TestUnexpectedResult,
    }
    const bases = [3]usize{ 0, cut1, cut2 };

    var iterator = archive.iterator();
    while (try iterator.next()) |entry| {
        const central = 4 + entry.central_header_offset;
        const virtual_local = 4 + entry.local_header_offset;
        const disk: usize = if (virtual_local < cut1)
            0
        else if (virtual_local < cut2)
            1
        else
            2;
        const relative_local = virtual_local - bases[disk];
        std.mem.writeInt(u16, bytes[central + 34 ..][0..2], @intCast(disk), .little);
        if (entry.zip64) {
            const name_len: usize = std.mem.readInt(u16, bytes[central + 28 ..][0..2], .little);
            const extra_len: usize = std.mem.readInt(u16, bytes[central + 30 ..][0..2], .little);
            const extra = bytes[central + wire.central_file_header_len + name_len ..][0..extra_len];
            if (extra.len < 28 or
                std.mem.readInt(u16, extra[0..2], .little) != wire.zip64_extra_id or
                std.mem.readInt(u16, extra[2..4], .little) < 24)
                return error.InvalidZipArchive;
            std.mem.writeInt(u64, extra[20..28], relative_local, .little);
        } else {
            std.mem.writeInt(u32, bytes[central + 42 ..][0..4], @intCast(relative_local), .little);
        }
    }

    const source_eocd = source.len - wire.end_of_central_len - archive.comment.len;
    const eocd = source_eocd + 4;
    const central_disk: usize = if (virtual_central < cut1)
        0
    else if (virtual_central < cut2)
        1
    else
        2;
    const central_offset = virtual_central - bases[central_disk];
    var entries_on_end_disk: usize = 0;
    var central_iterator = archive.iterator();
    while (try central_iterator.next()) |entry| {
        if (4 + entry.central_header_offset >= cut2)
            entries_on_end_disk += 1;
    }
    if (archive.zip64) {
        const source_locator = source_eocd - wire.zip64_end_of_central_locator_len;
        const locator = source_locator + 4;
        const source_zip64 = std.math.cast(
            usize,
            std.mem.readInt(u64, source[source_locator + 8 ..][0..8], .little),
        ) orelse return error.UnsupportedZipFeature;
        const zip64 = source_zip64 + 4;
        std.mem.writeInt(u32, bytes[zip64 + 16 ..][0..4], 2, .little);
        std.mem.writeInt(u32, bytes[zip64 + 20 ..][0..4], @intCast(central_disk), .little);
        std.mem.writeInt(u64, bytes[zip64 + 24 ..][0..8], entries_on_end_disk, .little);
        std.mem.writeInt(
            u64,
            bytes[zip64 + 48 ..][0..8],
            central_offset,
            .little,
        );
        std.mem.writeInt(u32, bytes[locator + 4 ..][0..4], 2, .little);
        std.mem.writeInt(u64, bytes[locator + 8 ..][0..8], zip64 - cut2, .little);
        std.mem.writeInt(u32, bytes[locator + 16 ..][0..4], 3, .little);
    } else {
        std.mem.writeInt(u16, bytes[eocd + 4 ..][0..2], 2, .little);
        std.mem.writeInt(u16, bytes[eocd + 6 ..][0..2], @intCast(central_disk), .little);
        std.mem.writeInt(u16, bytes[eocd + 8 ..][0..2], @intCast(entries_on_end_disk), .little);
        std.mem.writeInt(
            u32,
            bytes[eocd + 16 ..][0..4],
            @intCast(central_offset),
            .little,
        );
    }
    return .{
        .allocator = allocator,
        .bytes = bytes,
        .parts = .{ bytes[0..cut1], bytes[cut1..cut2], bytes[cut2..] },
    };
}

fn makeEmptySplitTestFixture(
    allocator: std.mem.Allocator,
    zip64_mode: Zip64Mode,
) !EmptySplitTestFixture {
    const source = try encodeAlloc(allocator, &.{}, .{ .zip64 = zip64_mode });
    defer allocator.free(source);
    const archive = try parse(source);
    const bytes = try allocator.alloc(u8, source.len + 4);
    errdefer allocator.free(bytes);
    std.mem.writeInt(u32, bytes[0..4], wire.data_descriptor_signature, .little);
    @memcpy(bytes[4..], source);
    const source_eocd = source.len - wire.end_of_central_len - archive.comment.len;
    const eocd = source_eocd + 4;
    if (archive.zip64) {
        const source_locator = source_eocd - wire.zip64_end_of_central_locator_len;
        const locator = source_locator + 4;
        const source_zip64 = std.math.cast(
            usize,
            std.mem.readInt(u64, source[source_locator + 8 ..][0..8], .little),
        ) orelse return error.UnsupportedZipFeature;
        const zip64 = source_zip64 + 4;
        std.mem.writeInt(u32, bytes[zip64 + 16 ..][0..4], 1, .little);
        std.mem.writeInt(u32, bytes[zip64 + 20 ..][0..4], 1, .little);
        std.mem.writeInt(u64, bytes[zip64 + 48 ..][0..8], 0, .little);
        std.mem.writeInt(u32, bytes[locator + 4 ..][0..4], 1, .little);
        std.mem.writeInt(u64, bytes[locator + 8 ..][0..8], source_zip64, .little);
        std.mem.writeInt(u32, bytes[locator + 16 ..][0..4], 2, .little);
    } else {
        std.mem.writeInt(u16, bytes[eocd + 4 ..][0..2], 1, .little);
        std.mem.writeInt(u16, bytes[eocd + 6 ..][0..2], 1, .little);
        std.mem.writeInt(u32, bytes[eocd + 16 ..][0..4], 0, .little);
    }
    return .{
        .allocator = allocator,
        .bytes = bytes,
        .parts = .{ bytes[0..4], bytes[4..] },
    };
}

test "ZIP split archive normalization round trips cross-disk entries" {
    const allocator = std.testing.allocator;
    const large = "split ZIP payload crosses disk boundaries\n" ** 4096;
    const archive_comment = "split archive comment";
    const entries = [_]EncodeEntry{
        .{ .name = "large.txt", .data = large, .method = .deflate },
        .{ .name = "tail.bin", .data = "tail entry", .method = .stored },
    };
    inline for (.{ Zip64Mode.never, .always }) |zip64_mode| {
        const source = try encodeAlloc(allocator, &entries, .{
            .archive_comment = archive_comment,
            .data_descriptor = true,
            .zip64 = zip64_mode,
        });
        defer allocator.free(source);
        inline for (.{ SplitTestCut.descriptor, .central_directory }) |cut| {
            var fixture = try makeSplitTestFixture(allocator, source, cut);
            defer fixture.deinit();
            var split_archive = try parseSplitArchiveAlloc(
                allocator,
                &fixture.parts,
                .{},
            );
            defer split_archive.deinit();
            try std.testing.expectEqual(entries.len, split_archive.archive.entry_count);
            try std.testing.expectEqualSlices(
                u8,
                archive_comment,
                split_archive.archive.comment,
            );
            for (entries, 0..) |expected, index| {
                const decoded = try split_archive.archive.extractAlloc(
                    allocator,
                    try split_archive.archive.entryAt(index),
                );
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, expected.data, decoded);
            }
            try std.testing.expectEqual(
                @as(u32, wire.data_descriptor_signature),
                std.mem.readInt(u32, split_archive.bytes[0..4], .little),
            );

            var normalized_stream = try SplitNormalizedStream.initAlloc(
                allocator,
                &fixture.parts,
                .{},
            );
            defer normalized_stream.deinit();
            try std.testing.expectEqual(split_archive.bytes.len, normalized_stream.len());
            try std.testing.expect(normalized_stream.patchCount() != 0);
            try std.testing.expectEqual(
                (try split_archive.archive.entryAt(0)).local_header_offset,
                normalized_stream.firstRecordOffset(),
            );
            var stream_offset: usize = 0;
            var stream_scratch: [7]u8 = undefined;
            while (stream_offset < normalized_stream.len()) {
                const written = try normalized_stream.readAt(stream_offset, &stream_scratch);
                try std.testing.expect(written != 0);
                try std.testing.expectEqualSlices(
                    u8,
                    split_archive.bytes[stream_offset..][0..written],
                    stream_scratch[0..written],
                );
                stream_offset += written;
            }
            try std.testing.expectEqual(
                @as(usize, 0),
                try normalized_stream.readAt(normalized_stream.len(), &stream_scratch),
            );
            try std.testing.expectError(
                error.RangeOutOfBounds,
                normalized_stream.readAt(normalized_stream.len() + 1, &stream_scratch),
            );

            inline for (.{ @as(usize, 3), 257 }) |input_buffer_size| {
                var stream_reader = try SplitIncrementalReader.initAlloc(
                    allocator,
                    &fixture.parts,
                    .{
                        .reader_options = .{ .initial_offset = 1234 },
                        .input_buffer_size = input_buffer_size,
                    },
                );
                defer stream_reader.deinit();
                try std.testing.expectEqual(fixture.bytes.len, stream_reader.normalizedLength());
                try std.testing.expect(stream_reader.metadataPatchCount() != 0);
                var streamed: std.ArrayList(u8) = .empty;
                defer streamed.deinit(allocator);
                var header_count: usize = 0;
                var done_count: usize = 0;
                var calls: usize = 0;
                while (true) {
                    var output: [5]u8 = undefined;
                    const result = try stream_reader.step(&output);
                    try streamed.appendSlice(
                        allocator,
                        output[0..result.progress.output_written],
                    );
                    calls += 1;
                    if (calls > large.len + 1024) return error.TestUnexpectedResult;
                    switch (result.status) {
                        .entry_header => {
                            try std.testing.expect(header_count < entries.len);
                            try std.testing.expectEqualSlices(
                                u8,
                                entries[header_count].name,
                                stream_reader.currentEntry().?.name,
                            );
                            header_count += 1;
                        },
                        .entry_done => done_count += 1,
                        .done => break,
                        .need_input => return error.TestUnexpectedResult,
                        .need_output => {},
                    }
                }
                try stream_reader.finish();
                try std.testing.expectEqualSlices(
                    u8,
                    archive_comment,
                    stream_reader.archiveComment(),
                );
                try std.testing.expectEqual(entries.len, header_count);
                try std.testing.expectEqual(entries.len, done_count);
                try std.testing.expectEqual(large.len + entries[1].data.len, streamed.items.len);
                try std.testing.expectEqualSlices(u8, large, streamed.items[0..large.len]);
                try std.testing.expectEqualSlices(u8, entries[1].data, streamed.items[large.len..]);
            }

            var limited_reader = try SplitIncrementalReader.initAlloc(
                allocator,
                &fixture.parts,
                .{
                    .reader_options = .{ .max_total_output_len = large.len - 1 },
                    .input_buffer_size = 31,
                },
            );
            defer limited_reader.deinit();
            try std.testing.expectError(
                error.OutputLimitExceeded,
                drainSplitIncrementalReader(&limited_reader),
            );
            try std.testing.expectError(
                error.OutputLimitExceeded,
                SplitIncrementalReader.initAlloc(allocator, &fixture.parts, .{
                    .input_buffer_size = 0,
                }),
            );

            try std.testing.expectError(
                error.OutputLimitExceeded,
                SplitNormalizedStream.initAlloc(allocator, &fixture.parts, .{
                    .max_entries = 1,
                }),
            );
            if (zip64_mode == .never and cut == .descriptor) {
                try std.testing.checkAllAllocationFailures(
                    allocator,
                    SplitOwnedAllocationTest.run,
                    .{fixture.parts[0..]},
                );
                try std.testing.checkAllAllocationFailures(
                    allocator,
                    SplitReaderAllocationTest.run,
                    .{fixture.parts[0..]},
                );
            }

            const reordered = [_][]const u8{ fixture.parts[1], fixture.parts[0], fixture.parts[2] };
            try std.testing.expectError(
                error.InvalidZipDiskOrder,
                parseSplitArchiveAlloc(allocator, &reordered, .{}),
            );
            const missing = [_][]const u8{ fixture.parts[0], fixture.parts[2] };
            try std.testing.expectError(
                error.InvalidZipDiskOrder,
                parseSplitArchiveAlloc(allocator, &missing, .{}),
            );
            try std.testing.expectError(
                error.OutputLimitExceeded,
                parseSplitArchiveAlloc(allocator, &fixture.parts, .{
                    .max_archive_size = fixture.bytes.len - 1,
                }),
            );
            try std.testing.expectError(
                error.OutputLimitExceeded,
                parseSplitArchiveAlloc(allocator, &fixture.parts, .{ .max_parts = 2 }),
            );
            const with_empty = [_][]const u8{ fixture.parts[0], "", fixture.parts[2] };
            try std.testing.expectError(
                error.InvalidZipArchive,
                parseSplitArchiveAlloc(allocator, &with_empty, .{}),
            );
            const single = [_][]const u8{fixture.parts[0]};
            try std.testing.expectError(
                error.InvalidZipArchive,
                parseSplitArchiveAlloc(allocator, &single, .{}),
            );

            std.mem.writeInt(u32, fixture.bytes[0..4], 0, .little);
            try std.testing.expectError(
                error.InvalidZipDiskOrder,
                parseSplitArchiveAlloc(allocator, &fixture.parts, .{}),
            );
            var marker_optional = try parseSplitArchiveAlloc(allocator, &fixture.parts, .{
                .require_split_signature = false,
            });
            marker_optional.deinit();
        }
    }
}

test "ZIP split incremental reader streams WinZip AES and ZipCrypto entries" {
    const allocator = std.testing.allocator;
    const password = "split encryption password 密码";
    const aes_payload = "split WinZip AES payload crosses disks\n" ** 257;
    const traditional_payload = "split Traditional ZipCrypto tail";
    const salt = [_]u8{0x5a} ** 16;
    const entries = [_]EncodeEntry{
        .{
            .name = "aes-crossing.txt",
            .data = aes_payload,
            .method = .deflate,
            .winzip_aes = .{
                .password = password,
                .strength = .aes256,
                .salt = &salt,
                .version = .ae2,
            },
        },
        .{
            .name = "zipcrypto-tail.bin",
            .data = traditional_payload,
            .method = .stored,
            .traditional_encryption = .{
                .password = password,
                .header_random = .{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
            },
        },
    };
    const source = try encodeAlloc(allocator, &entries, .{
        .data_descriptor = true,
        .zip64 = .always,
    });
    defer allocator.free(source);
    var fixture = try makeSplitTestFixture(allocator, source, .descriptor);
    defer fixture.deinit();

    var reader = try SplitIncrementalReader.initAlloc(
        allocator,
        &fixture.parts,
        .{
            .reader_options = .{ .password = password },
            .input_buffer_size = 17,
        },
    );
    defer reader.deinit();
    var decoded: std.ArrayList(u8) = .empty;
    defer decoded.deinit(allocator);
    var headers: usize = 0;
    var completed: usize = 0;
    while (true) {
        var output: [23]u8 = undefined;
        const result = try reader.step(&output);
        try decoded.appendSlice(allocator, output[0..result.progress.output_written]);
        switch (result.status) {
            .entry_header => headers += 1,
            .entry_done => completed += 1,
            .done => break,
            .need_output => {},
            .need_input => return error.TestUnexpectedResult,
        }
    }
    try reader.finish();
    try std.testing.expectEqual(entries.len, headers);
    try std.testing.expectEqual(entries.len, completed);
    try std.testing.expectEqual(aes_payload.len + traditional_payload.len, decoded.items.len);
    try std.testing.expectEqualSlices(u8, aes_payload, decoded.items[0..aes_payload.len]);
    try std.testing.expectEqualSlices(u8, traditional_payload, decoded.items[aes_payload.len..]);

    var missing_password = try SplitIncrementalReader.initAlloc(
        allocator,
        &fixture.parts,
        .{ .input_buffer_size = 19 },
    );
    defer missing_password.deinit();
    try std.testing.expectError(
        error.PasswordRequired,
        drainSplitIncrementalReader(&missing_password),
    );

    var wrong_password = try SplitIncrementalReader.initAlloc(
        allocator,
        &fixture.parts,
        .{
            .reader_options = .{ .password = "wrong" },
            .input_buffer_size = 19,
        },
    );
    defer wrong_password.deinit();
    try std.testing.expectError(
        error.InvalidZipPassword,
        drainSplitIncrementalReader(&wrong_password),
    );

    var part_lengths = [_]usize{
        fixture.parts[0].len,
        fixture.parts[1].len,
        fixture.parts[2].len,
    };
    var source_context: SplitPartSourceContext = .{
        .parts = &fixture.parts,
        .max_read = 5,
    };
    var source_reader = try SplitIncrementalReader.initSourceAlloc(
        allocator,
        .{
            .context = &source_context,
            .part_lengths = &part_lengths,
            .read_at = SplitPartSourceContext.readAt,
        },
        .{
            .reader_options = .{ .password = password },
            .input_buffer_size = 13,
        },
    );
    defer source_reader.deinit();
    try drainSplitIncrementalReader(&source_reader);
}

test "ZIP split archive accepts empty ZIP32 and ZIP64 disk sets" {
    inline for (.{ Zip64Mode.never, .always }) |zip64_mode| {
        var fixture = try makeEmptySplitTestFixture(std.testing.allocator, zip64_mode);
        defer fixture.deinit();
        var owned = try parseSplitArchiveAlloc(
            std.testing.allocator,
            &fixture.parts,
            .{},
        );
        defer owned.deinit();
        try std.testing.expectEqual(@as(usize, 0), owned.archive.entry_count);
        var reader = try SplitIncrementalReader.initAlloc(
            std.testing.allocator,
            &fixture.parts,
            .{ .input_buffer_size = 1 },
        );
        defer reader.deinit();
        var output: [1]u8 = undefined;
        const result = try reader.step(&output);
        try std.testing.expectEqual(IncrementalReaderStepResult.Status.done, result.status);
        try std.testing.expectEqual(@as(usize, 0), result.progress.output_written);
        try reader.finish();
    }
}

test "ZIP split source reader loads parts on demand and propagates failures" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{
        .{
            .name = "source-crossing.txt",
            .data = "on-demand split source payload\n" ** 257,
            .method = .deflate,
        },
        .{
            .name = "source-tail.bin",
            .data = "on-demand tail",
            .method = .stored,
        },
    };
    const source = try encodeAlloc(allocator, &entries, .{
        .archive_comment = "source callback",
        .data_descriptor = true,
        .zip64 = .always,
    });
    defer allocator.free(source);
    var fixture = try makeSplitTestFixture(allocator, source, .central_directory);
    defer fixture.deinit();
    var part_lengths = [_]usize{
        fixture.parts[0].len,
        fixture.parts[1].len,
        fixture.parts[2].len,
    };
    var context: SplitPartSourceContext = .{
        .parts = &fixture.parts,
        .max_read = 3,
    };
    var normalized = try SplitNormalizedSourceStream.initAlloc(
        allocator,
        .{
            .context = &context,
            .part_lengths = &part_lengths,
            .read_at = SplitPartSourceContext.readAt,
        },
        .{},
    );
    defer normalized.deinit();
    part_lengths = @splat(0);
    var owned = try parseSplitArchiveAlloc(allocator, &fixture.parts, .{});
    defer owned.deinit();
    var offset: usize = 0;
    var scratch: [7]u8 = undefined;
    while (offset < normalized.len()) {
        const written = try normalized.readAt(offset, &scratch);
        try std.testing.expect(written != 0);
        try std.testing.expectEqualSlices(
            u8,
            owned.bytes[offset..][0..written],
            scratch[0..written],
        );
        offset += written;
    }
    try std.testing.expect(context.reads > normalized.patchCount());
    try std.testing.expect(context.switches > fixture.parts.len);
    try std.testing.expectEqual(context.switches - 1, context.releases);

    part_lengths = .{
        fixture.parts[0].len,
        fixture.parts[1].len,
        fixture.parts[2].len,
    };
    context = .{ .parts = &fixture.parts, .max_read = 3 };
    var reader = try SplitIncrementalReader.initSourceAlloc(
        allocator,
        .{
            .context = &context,
            .part_lengths = &part_lengths,
            .read_at = SplitPartSourceContext.readAt,
        },
        .{ .input_buffer_size = 11 },
    );
    defer reader.deinit();
    try drainSplitIncrementalReader(&reader);
    try std.testing.expect(context.switches > fixture.parts.len);
    try std.testing.expectEqual(context.switches - 1, context.releases);

    var failing_context: SplitPartSourceContext = .{
        .parts = &fixture.parts,
        .fail_after = 0,
    };
    try std.testing.expectError(
        error.PartSourceReadFailed,
        SplitIncrementalReader.initSourceAlloc(
            allocator,
            .{
                .context = &failing_context,
                .part_lengths = &part_lengths,
                .read_at = SplitPartSourceContext.readAt,
            },
            .{},
        ),
    );

    var short_marker_lengths = part_lengths;
    short_marker_lengths[0] = 3;
    try std.testing.expectError(
        error.InvalidZipDiskOrder,
        SplitIncrementalReader.initSourceAlloc(
            allocator,
            .{
                .context = &context,
                .part_lengths = &short_marker_lengths,
                .read_at = SplitPartSourceContext.readAt,
            },
            .{},
        ),
    );

    context = .{ .parts = &fixture.parts };
    var failing_reader = try SplitIncrementalReader.initSourceAlloc(
        allocator,
        .{
            .context = &context,
            .part_lengths = &part_lengths,
            .read_at = SplitPartSourceContext.readAt,
        },
        .{},
    );
    defer failing_reader.deinit();
    context.fail_after = context.reads;
    var output: [16]u8 = undefined;
    try std.testing.expectError(
        error.PartSourceReadFailed,
        failing_reader.step(&output),
    );
}

test "ZIP split writer plans standard atomic records and round trips" {
    const allocator = std.testing.allocator;
    const payload = try allocator.alloc(u8, 128 * 1024);
    defer allocator.free(payload);
    var state: u32 = 0x51a7_2026;
    var block: usize = 0;
    while (block < payload.len / 128) : (block += 1) {
        for (0..64) |index| {
            state = state *% 1_664_525 +% 1_013_904_223;
            const value: u8 = @truncate(state >> 24);
            payload[block * 128 + index] = value;
            payload[block * 128 + 64 + index] = value;
        }
    }
    const modified = try DosTimestamp.fromComponents(.{
        .year = 2020,
        .month = 5,
        .day = 6,
        .hour = 7,
        .minute = 8,
        .second = 9,
    });
    const entries = [_]EncodeEntry{
        .{ .name = "crossing.bin", .data = payload, .method = .deflate },
        .{
            .name = "tail.bin",
            .unicode_name = "尾部.bin",
            .data = "split writer stored tail" ** 97,
            .method = .stored,
            .comment = "split metadata",
            .unicode_comment = "分卷元数据",
            .modified = modified,
            .extended_timestamp = .{ .modified = 1_590_000_001 },
            .ntfs_timestamp = .{
                .modified = try fileTimeFromUnixSeconds(1_590_000_001),
                .accessed = try fileTimeFromUnixSeconds(1_590_000_002),
                .created = try fileTimeFromUnixSeconds(1_590_000_003),
            },
            .creator_system = .unix,
            .external_attributes = unixExternalAttributes(0o100644),
        },
    };
    inline for (.{ false, true }) |descriptor| {
        inline for (.{ Zip64Mode.never, .always }) |zip64_mode| {
            const options: SplitEncodeOptions = .{
                .zip_options = .{
                    .archive_comment = "split writer comment",
                    .data_descriptor = descriptor,
                    .zip64 = zip64_mode,
                    .utf8 = false,
                },
                .max_part_size = 4096,
            };
            var encoded = try encodeSplitAlloc(allocator, &entries, options);
            defer encoded.deinit();
            var repeated = try encodeSplitAlloc(allocator, &entries, options);
            defer repeated.deinit();
            try std.testing.expect(encoded.parts.len > 2);
            try std.testing.expectEqual(encoded.parts.len, repeated.parts.len);
            try std.testing.expectEqualSlices(u8, encoded.bytes, repeated.bytes);
            for (encoded.parts, repeated.parts) |part, repeated_part| {
                try std.testing.expect(part.len <= options.max_part_size);
                try std.testing.expectEqual(part.len, repeated_part.len);
            }
            try std.testing.expectEqual(
                @as(u32, wire.data_descriptor_signature),
                std.mem.readInt(u32, encoded.parts[0][0..4], .little),
            );

            var archive = try parseSplitArchiveAlloc(allocator, encoded.parts, .{});
            defer archive.deinit();
            try std.testing.expectEqual(entries.len, archive.archive.entry_count);
            try std.testing.expectEqualSlices(
                u8,
                "split writer comment",
                archive.archive.comment,
            );
            for (entries, 0..) |expected, index| {
                const entry = try archive.archive.entryAt(index);
                const decoded = try archive.archive.extractAlloc(
                    allocator,
                    entry,
                );
                defer allocator.free(decoded);
                try std.testing.expectEqualSlices(u8, expected.data, decoded);
                try std.testing.expectEqualStrings(expected.comment, entry.comment);
                if (expected.unicode_name) |unicode_name|
                    try std.testing.expectEqualStrings(unicode_name, entry.preferredName());
            }
            var stream_reader = try SplitIncrementalReader.initAlloc(
                allocator,
                encoded.parts,
                .{ .input_buffer_size = 127 },
            );
            defer stream_reader.deinit();
            try drainSplitIncrementalReader(&stream_reader);
            const streamed_tail = stream_reader.entryAt(1).?;
            try std.testing.expectEqualStrings("split metadata", streamed_tail.comment.?);
            try std.testing.expectEqualStrings("尾部.bin", streamed_tail.preferredName());
            try std.testing.expectEqualStrings("分卷元数据", streamed_tail.preferredComment().?);
            try std.testing.expectEqual(modified, streamed_tail.modified);
            try std.testing.expectEqual(entries[1].extended_timestamp, streamed_tail.extended_timestamp);
            try std.testing.expectEqual(entries[1].ntfs_timestamp, streamed_tail.ntfs_timestamp);
            try std.testing.expectEqual(@as(?u16, 0o100644), streamed_tail.unixMode());
        }
    }

    var single = try encodeSplitAlloc(allocator, &entries, .{
        .zip_options = .{ .utf8 = false },
        .max_part_size = 1024 * 1024,
    });
    defer single.deinit();
    try std.testing.expectEqual(@as(usize, 1), single.parts.len);
    const single_archive = try parse(single.parts[0]);
    try std.testing.expectEqual(entries.len, single_archive.entry_count);

    inline for (.{ Zip64Mode.never, .always }) |zip64_mode| {
        var empty = try encodeSplitAlloc(allocator, &.{}, .{
            .zip_options = .{ .zip64 = zip64_mode },
            .max_part_size = 128,
        });
        defer empty.deinit();
        try std.testing.expectEqual(@as(usize, 1), empty.parts.len);
        try std.testing.expectEqual(
            @as(usize, 0),
            (try parse(empty.parts[0])).entry_count,
        );
    }

    try std.testing.expectError(
        error.InvalidZipSplitSize,
        encodeSplitAlloc(allocator, &entries, .{
            .zip_options = .{ .utf8 = false },
            .max_part_size = 3,
        }),
    );
    try std.testing.expectError(
        error.InvalidZipSplitSize,
        encodeSplitAlloc(allocator, &entries, .{
            .zip_options = .{ .utf8 = false },
            .max_part_size = 16,
        }),
    );
    try std.testing.expectError(
        error.ZipSplitLimitExceeded,
        encodeSplitAlloc(allocator, &entries, .{
            .zip_options = .{ .utf8 = false },
            .max_part_size = 4096,
            .max_parts = 1,
        }),
    );
    try std.testing.expectError(
        error.OutputLimitExceeded,
        encodeSplitAlloc(allocator, &entries, .{
            .zip_options = .{ .utf8 = false },
            .max_archive_size = 1,
        }),
    );
    try std.testing.expectError(
        error.ZipSplitLimitExceeded,
        encodeSplitAlloc(allocator, &entries, .{
            .zip_options = .{ .utf8 = false },
            .max_parts = @as(usize, std.math.maxInt(u16)) + 1,
        }),
    );
    try std.testing.checkAllAllocationFailures(
        allocator,
        SplitWriterAllocationTest.run,
        .{},
    );
}

test "ZIP split writer composes WinZip AES and ZipCrypto" {
    const allocator = std.testing.allocator;
    const password = "split writer encryption password";
    const salt = [_]u8{0xa5} ** 16;
    const entries = [_]EncodeEntry{
        .{
            .name = "aes.txt",
            .data = "split writer authenticated data" ** 43,
            .method = .deflate,
            .winzip_aes = .{
                .password = password,
                .salt = &salt,
                .strength = .aes256,
                .version = .ae2,
            },
        },
        .{
            .name = "legacy.bin",
            .data = "split writer encrypted stored tail" ** 11,
            .method = .stored,
            .traditional_encryption = .{
                .password = password,
                .header_random = .{ 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0 },
            },
        },
    };
    var encoded = try encodeSplitAlloc(allocator, &entries, .{
        .zip_options = .{
            .data_descriptor = true,
            .zip64 = .always,
        },
        .max_part_size = 128,
    });
    defer encoded.deinit();
    try std.testing.expect(encoded.parts.len > 2);
    var archive = try parseSplitArchiveAlloc(allocator, encoded.parts, .{});
    defer archive.deinit();
    for (entries, 0..) |expected, index| {
        const entry = try archive.archive.entryAt(index);
        try std.testing.expect(entry.isEncrypted());
        try std.testing.expectError(
            error.InvalidZipPassword,
            archive.archive.extractAllocWithOptions(
                allocator,
                entry,
                .{ .password = "wrong" },
            ),
        );
        const decoded = try archive.archive.extractAllocWithOptions(
            allocator,
            entry,
            .{ .password = password },
        );
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, expected.data, decoded);
    }
    var stream_reader = try SplitIncrementalReader.initAlloc(
        allocator,
        encoded.parts,
        .{
            .reader_options = .{ .password = password },
            .input_buffer_size = 29,
        },
    );
    defer stream_reader.deinit();
    try drainSplitIncrementalReader(&stream_reader);
}

test "ZIP split incremental writer test suite" {
    _ = split_incremental_writer_tests;
}

test "ZIP writer appends a valid archive after a prefix and rejects inputs transactionally" {
    const allocator = std.testing.allocator;
    const entries = [_]EncodeEntry{
        .{ .name = "payload.txt", .data = "prefixed archive", .method = .stored },
    };
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(allocator);
    try out.appendSlice(allocator, "MZ-prefix");
    const prefix_len = out.items.len;
    const written = try encodeAppend(allocator, &out, &entries, .{ .utf8 = false });
    try std.testing.expectEqual(out.items.len - prefix_len, written);

    const archive = try parse(out.items);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(prefix_len, entry.local_header_offset);
    try std.testing.expectEqual(@as(u16, 0), entry.flags & 0x0808);
    const decoded = try archive.extractAlloc(allocator, entry);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(entries[0].data, decoded);

    const before = try allocator.dupe(u8, out.items);
    defer allocator.free(before);
    const invalid_name = [_]EncodeEntry{.{ .name = "", .data = "invalid" }};
    try std.testing.expectError(error.InvalidZipEntryName, encodeAppend(allocator, &out, &invalid_name, .{}));
    try std.testing.expectEqualSlices(u8, before, out.items);

    const invalid_utf8_name = [_]u8{0xff};
    const invalid_utf8 = [_]EncodeEntry{.{ .name = &invalid_utf8_name, .data = "invalid" }};
    try std.testing.expectError(error.InvalidZipTextEncoding, encodeAppend(allocator, &out, &invalid_utf8, .{}));
    try std.testing.expectEqualSlices(u8, before, out.items);

    const unsupported = [_]EncodeEntry{.{
        .name = "unsupported.bin",
        .data = "invalid",
        .method = @enumFromInt(99),
    }};
    try std.testing.expectError(error.UnsupportedZipCompressionMethod, encodeAppend(allocator, &out, &unsupported, .{}));
    try std.testing.expectEqualSlices(u8, before, out.items);
}

test "ZIP writer emits and parses an empty archive" {
    const bytes = try encodeAlloc(std.testing.allocator, &.{}, .{});
    defer std.testing.allocator.free(bytes);
    const archive = try parse(bytes);
    try std.testing.expectEqual(@as(usize, 0), archive.entry_count);
    try std.testing.expectEqual(@as(usize, 0), archive.central_directory_size);
}

test "ZIP64 writer emits forced records and round trips descriptor and header sizes" {
    const allocator = std.testing.allocator;
    const payload = "forced ZIP64 payload " ** 32;
    const entries = [_]EncodeEntry{
        .{ .name = "stored.bin", .data = "zip64 stored", .method = .stored },
        .{ .name = "compressed.txt", .data = payload, .method = .deflate },
    };

    inline for (.{ false, true }) |descriptor| {
        const bytes = try encodeAlloc(allocator, &entries, .{
            .archive_comment = "zip64",
            .data_descriptor = descriptor,
            .zip64 = .always,
        });
        defer allocator.free(bytes);
        const archive = try parse(bytes);
        try std.testing.expect(archive.zip64);
        try std.testing.expectEqual(entries.len, archive.entry_count);
        try std.testing.expectEqualStrings("zip64", archive.comment);

        var it = archive.iterator();
        var index: usize = 0;
        while (try it.next()) |entry| : (index += 1) {
            try std.testing.expect(entry.zip64);
            try std.testing.expectEqual(std.math.maxInt(u32), try readU32(bytes, entry.central_header_offset + 20));
            try std.testing.expectEqual(std.math.maxInt(u32), try readU32(bytes, entry.central_header_offset + 24));
            try std.testing.expectEqual(std.math.maxInt(u32), try readU32(bytes, entry.central_header_offset + 42));
            const decoded = try archive.extractAlloc(allocator, entry);
            defer allocator.free(decoded);
            try std.testing.expectEqualSlices(u8, entries[index].data, decoded);
        }
        try std.testing.expectEqual(entries.len, index);

        const eocd_offset = bytes.len - end_of_central_len - archive.comment.len;
        try std.testing.expectEqual(@as(u32, 0x0706_4b50), try readU32(bytes, eocd_offset - 20));
        const zip64_record_offset: usize = @intCast(std.mem.readInt(u64, bytes[eocd_offset - 12 ..][0..8], .little));
        try std.testing.expectEqual(@as(u32, 0x0606_4b50), try readU32(bytes, zip64_record_offset));
        try std.testing.expectEqual(std.math.maxInt(u16), try readU16(bytes, eocd_offset + 10));
        try std.testing.expectEqual(std.math.maxInt(u32), try readU32(bytes, eocd_offset + 12));
        try std.testing.expectEqual(std.math.maxInt(u32), try readU32(bytes, eocd_offset + 16));
    }
}

test "ZIP writer auto promotes the ZIP32 entry-count sentinel" {
    const allocator = std.testing.allocator;
    const entries = try allocator.alloc(EncodeEntry, std.math.maxInt(u16));
    defer allocator.free(entries);
    for (entries) |*entry| entry.* = .{ .name = "x", .data = "", .method = .stored };

    const bytes = try encodeAlloc(allocator, entries, .{});
    defer allocator.free(bytes);
    const archive = try parse(bytes);
    try std.testing.expect(archive.zip64);
    try std.testing.expectEqual(entries.len, archive.entry_count);
    const first = try archive.entryAt(0);
    const last = try archive.entryAt(entries.len - 1);
    try std.testing.expect(!first.zip64);
    try std.testing.expect(!last.zip64);
    try std.testing.expectEqualStrings("x", last.name);
}

test "ZIP method 1 Shrink writer round trips without extraction scratch" {
    const allocator = std.testing.allocator;
    const payload = "Shrunk ZIP entry with legacy LZW.\n" ** 256;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-shrink.txt",
        .data = payload,
        .method = .shrink,
    }};
    const bytes = try encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(bytes);
    const archive = try parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.shrink, entry.method);
    try std.testing.expect(entry.compressed_size < entry.uncompressed_size);
    var output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try archive.extractInto(entry, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "ZIP method 1 extracts an Apache Commons Compress Shrink fixture" {
    const allocator = std.testing.allocator;
    // Apache Commons Compress src/test/resources/SHRUNK.ZIP.
    // SHA-256: 7403088a3219165f6de8d76abd2daf03bdcf72458dfa14713fc2b34d0293fb4e.
    const fixture_hex = std.mem.trim(
        u8,
        @embedFile("zip/testdata/commons-compress-shrunk.zip.hex"),
        "\r\n \t",
    );
    const fixture = try allocator.alloc(u8, fixture_hex.len / 2);
    defer allocator.free(fixture);
    _ = try std.fmt.hexToBytes(fixture, fixture_hex);
    const archive = try parse(fixture);
    try std.testing.expectEqual(@as(usize, 2), archive.entry_count);
    const expected = [_][]const u8{
        "<?xml version = '1.0'?>\n<!DOCTYPE connections>\n<connections>\n</connections>\n",
        "<?xml version = '1.0'?>\n<!DOCTYPE connections>\n<meinxml>\n    <leer />\n</meinxml>\n",
    };
    for (expected, 0..) |payload, index| {
        const entry = try archive.entryAt(index);
        try std.testing.expectEqual(CompressionMethod.shrink, entry.method);
        const decoded = try archive.extractAlloc(allocator, entry);
        defer allocator.free(decoded);
        try std.testing.expectEqualSlices(u8, payload, decoded);
    }
}

test "ZIP methods 2 through 5 Reduce writer round trip all factors" {
    const allocator = std.testing.allocator;
    const payload = ("Reduced ZIP follower-set payload.\n" ** 256) ++
        ([_]u8{ 0, 1, 2, 3, 4, 5, 144 } ** 128);
    inline for (.{
        CompressionMethod.reduce_1,
        .reduce_2,
        .reduce_3,
        .reduce_4,
    }) |method| {
        const entries = [_]EncodeEntry{.{
            .name = "compressed-with-reduce.txt",
            .data = payload,
            .method = method,
        }};
        const bytes = try encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
        defer allocator.free(bytes);
        const archive = try parse(bytes);
        const entry = try archive.entryAt(0);
        try std.testing.expectEqual(method, entry.method);
        try std.testing.expect(entry.compressed_size < entry.uncompressed_size);
        var output: [payload.len]u8 = undefined;
        try std.testing.expectEqual(payload.len, try archive.extractInto(entry, &output));
        try std.testing.expectEqualSlices(u8, payload, &output);
    }
}

test "ZIP method 6 Implode writer round trips all flag modes" {
    const allocator = std.testing.allocator;
    const payload = "Imploded ZIP entry with Shannon-Fano trees.\n" ** 256;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-implode.txt",
        .data = payload,
        .method = .implode,
    }};
    inline for (.{ implode.Dictionary.small_4k, .large_8k }) |dictionary| {
        inline for (.{ false, true }) |literal_tree| {
            const options = EncodeOptions{
                .data_descriptor = true,
                .implode_options = .{
                    .dictionary = dictionary,
                    .literal_tree = literal_tree,
                },
            };
            const bytes = try encodeAlloc(allocator, &entries, options);
            defer allocator.free(bytes);
            const archive = try parse(bytes);
            const entry = try archive.entryAt(0);
            try std.testing.expectEqual(CompressionMethod.implode, entry.method);
            try std.testing.expectEqual(options.implode_options.flags(), entry.flags & 0x0006);
            try std.testing.expect(entry.compressed_size < entry.uncompressed_size);
            var output: [payload.len]u8 = undefined;
            try std.testing.expectEqual(payload.len, try archive.extractInto(entry, &output));
            try std.testing.expectEqualSlices(u8, payload, &output);
        }
    }
}

test "ZIP method 6 extracts Apache Commons Compress Implode fixtures" {
    const allocator = std.testing.allocator;
    const Fixture = struct {
        encoded: []const u8,
        name: []const u8,
        size: usize,
        flags: u16,
    };
    const fixtures = [_]Fixture{
        .{
            // src/test/resources/imploding-4Kdict-2trees.zip
            // SHA-256: cde0fbf261fb6f18339b2159c530462bc91220d9b43cd090b303d5b663b3f0bb.
            .encoded = @embedFile("zip/testdata/commons-compress-implode-4k-2trees.zip.b64"),
            .name = "HEADER.TXT",
            .size = 818,
            .flags = 0,
        },
        .{
            // src/test/resources/imploding-8Kdict-3trees.zip
            // SHA-256: 88d2bf6cf1e2f9604be7639ab67218e9a6ed946d0919b29cfff699c5bbc6c5fa.
            .encoded = @embedFile("zip/testdata/commons-compress-implode-8k-3trees.zip.b64"),
            .name = "LICENSE.TXT",
            .size = 11_560,
            .flags = 0x0006,
        },
    };
    const decoder = std.base64.standard.decoderWithIgnore("\r\n \t");
    for (fixtures) |fixture| {
        const encoded_size = decoder.calcSizeUpperBound(fixture.encoded.len);
        const storage = try allocator.alloc(u8, encoded_size);
        defer allocator.free(storage);
        const decoded_size = try decoder.decode(storage, fixture.encoded);
        const archive = try parse(storage[0..decoded_size]);
        const entry = (try archive.find(fixture.name)).?;
        try std.testing.expectEqual(CompressionMethod.implode, entry.method);
        try std.testing.expectEqual(fixture.flags, entry.flags & 0x0006);
        try std.testing.expectEqual(fixture.size, entry.uncompressed_size);
        const payload = try archive.extractAlloc(allocator, entry);
        defer allocator.free(payload);
        try std.testing.expectEqual(fixture.size, payload.len);
    }
}

test "ZIP method 10 DCL Implode writer round trips all header modes" {
    const allocator = std.testing.allocator;
    const payload = ("DCL Imploded ZIP entry with fixed Huffman tables.\n" ** 256) ++
        ([_]u8{ 0, 1, 2, 3, 4, 5 } ** 128);
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-dcl-implode.txt",
        .data = payload,
        .method = .dcl_implode,
    }};
    inline for (.{ false, true }) |literal_coded| {
        inline for (std.meta.tags(dcl_implode.Dictionary)) |dictionary| {
            const options = EncodeOptions{
                .data_descriptor = true,
                .dcl_implode_options = .{
                    .literal_coded = literal_coded,
                    .dictionary = dictionary,
                },
            };
            const bytes = try encodeAlloc(allocator, &entries, options);
            defer allocator.free(bytes);
            const archive = try parse(bytes);
            const entry = try archive.entryAt(0);
            try std.testing.expectEqual(CompressionMethod.dcl_implode, entry.method);
            try std.testing.expect(entry.compressed_size < entry.uncompressed_size);
            var output: [payload.len]u8 = undefined;
            try std.testing.expectEqual(payload.len, try archive.extractInto(entry, &output));
            try std.testing.expectEqualSlices(u8, payload, &output);
        }
    }
}

test "ZIP method 12 round trips through the allocating Bzip2 extraction path" {
    const allocator = std.testing.allocator;
    const payload = "Bzip2-compressed ZIP entry " ** 128;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-bzip2.txt",
        .data = payload,
        .method = .bzip2,
    }};
    const bytes = try encodeAlloc(allocator, &entries, .{
        .data_descriptor = true,
        .bzip2_options = .{ .block_size_100k = 1 },
    });
    defer allocator.free(bytes);

    const archive = try parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.bzip2, entry.method);
    try std.testing.expectEqual(@as(u16, 46), try readU16(bytes, entry.local_header_offset + 4));
    try std.testing.expectEqual(@as(u16, 46), try readU16(bytes, entry.central_header_offset + 6));

    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.ZipEntryRequiresAllocator, archive.extractInto(entry, &output));
    try std.testing.expectEqual(payload.len, try archive.extractIntoWithAllocator(allocator, entry, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);

    const allocated = try archive.extractAlloc(allocator, entry);
    defer allocator.free(allocated);
    try std.testing.expectEqualSlices(u8, payload, allocated);
}

test "ZIP method 9 extracts a 7-Zip Deflate64 reference entry" {
    const allocator = std.testing.allocator;
    const payload = "Deflate64 ZIP reference\n" ** 32;
    const compressed_hex = "e5c8a10d00200c4541cf141d8230010687c611f2aa08a261ff74907ff23a7ef7a7555b635ae004ef50e45ffe353e01";
    var compressed: [compressed_hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&compressed, compressed_hex);
    var entry = TestEntry{
        .name = "reference.txt",
        .payload = payload,
        .compressed = &compressed,
        .method = @intFromEnum(CompressionMethod.deflate64),
        .flags = 0,
        .local_offset = 0,
    };
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(allocator);
    try appendTestLocal(&bytes, allocator, &entry);
    const central_offset = bytes.items.len;
    try appendTestCentral(&bytes, allocator, entry);
    const central_size = bytes.items.len - central_offset;
    try appendU32(&bytes, allocator, end_of_central_signature);
    try appendU16(&bytes, allocator, 0);
    try appendU16(&bytes, allocator, 0);
    try appendU16(&bytes, allocator, 1);
    try appendU16(&bytes, allocator, 1);
    try appendU32(&bytes, allocator, @intCast(central_size));
    try appendU32(&bytes, allocator, @intCast(central_offset));
    try appendU16(&bytes, allocator, 0);

    const archive = try parse(bytes.items);
    const parsed = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.deflate64, parsed.method);
    var output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try archive.extractInto(parsed, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "ZIP method 9 writer emits Deflate64 and round trips without extraction scratch" {
    const allocator = std.testing.allocator;
    const payload = "Deflate64-compressed ZIP entry " ** 128;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-deflate64.txt",
        .data = payload,
        .method = .deflate64,
    }};
    const bytes = try encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(bytes);

    const archive = try parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.deflate64, entry.method);
    try std.testing.expectEqual(@as(u16, 21), try readU16(bytes, entry.local_header_offset + 4));
    try std.testing.expectEqual(@as(u16, 21), try readU16(bytes, entry.central_header_offset + 6));
    try std.testing.expect(entry.compressed_size < entry.uncompressed_size);

    var output: [payload.len]u8 = undefined;
    try std.testing.expectEqual(payload.len, try archive.extractInto(entry, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "ZIP method 14 writer round trips through the allocating LZMA path" {
    const allocator = std.testing.allocator;
    const payload = "LZMA-compressed ZIP entry " ** 128;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-lzma.txt",
        .data = payload,
        .method = .lzma,
    }};
    const bytes = try encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(bytes);

    const archive = try parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.lzma, entry.method);
    try std.testing.expect(entry.flags & 0x0002 != 0);
    try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.local_header_offset + 4));
    try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.central_header_offset + 6));

    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.ZipEntryRequiresAllocator, archive.extractInto(entry, &output));
    try std.testing.expectEqual(payload.len, try archive.extractIntoWithAllocator(allocator, entry, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "ZIP method 98 PPMd writer round trips restore modes and memory limits" {
    const allocator = std.testing.allocator;
    const payload = "PPMd8-compressed ZIP entry " ** 256;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-ppmd.txt",
        .data = payload,
        .method = .ppmd,
    }};
    inline for (.{ ppmd8.RestoreMethod.restart, .cut_off }) |restore_method| {
        const bytes = try encodeAlloc(allocator, &entries, .{
            .data_descriptor = true,
            .ppmd_options = .{
                .order = if (restore_method == .restart) 8 else 12,
                .memory_size = 1024 * 1024,
                .restore_method = restore_method,
            },
        });
        defer allocator.free(bytes);
        const archive = try parse(bytes);
        const entry = try archive.entryAt(0);
        try std.testing.expectEqual(CompressionMethod.ppmd, entry.method);
        try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.local_header_offset + 4));
        try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.central_header_offset + 6));
        var output: [payload.len]u8 = undefined;
        try std.testing.expectError(error.ZipEntryRequiresAllocator, archive.extractInto(entry, &output));
        try std.testing.expectEqual(
            payload.len,
            try archive.extractIntoWithOptions(allocator, entry, &output, .{
                .max_dictionary_size = 1024 * 1024,
            }),
        );
        try std.testing.expectEqualSlices(u8, payload, &output);
        try std.testing.expectError(
            error.OutputLimitExceeded,
            archive.extractIntoWithOptions(allocator, entry, &output, .{
                .max_dictionary_size = 1024 * 1024 - 1,
            }),
        );
    }
}

test "ZIP method 95 writer round trips through the allocating XZ path" {
    const allocator = std.testing.allocator;
    const payload = "XZ-compressed ZIP entry " ** 128;
    const entries = [_]EncodeEntry{.{
        .name = "compressed-with-xz.txt",
        .data = payload,
        .method = .xz,
    }};
    const bytes = try encodeAlloc(allocator, &entries, .{ .data_descriptor = true });
    defer allocator.free(bytes);

    const archive = try parse(bytes);
    const entry = try archive.entryAt(0);
    try std.testing.expectEqual(CompressionMethod.xz, entry.method);
    try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.local_header_offset + 4));
    try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.central_header_offset + 6));

    var output: [payload.len]u8 = undefined;
    try std.testing.expectError(error.ZipEntryRequiresAllocator, archive.extractInto(entry, &output));
    try std.testing.expectEqual(payload.len, try archive.extractIntoWithAllocator(allocator, entry, &output));
    try std.testing.expectEqualSlices(u8, payload, &output);
}

test "ZIP methods 20 and 93 round trip through the caller-owned Zstandard path" {
    const allocator = std.testing.allocator;
    const payload = "Zstandard-compressed ZIP entry " ** 128;
    inline for (.{ CompressionMethod.zstandard_legacy, .zstandard }) |method| {
        const entries = [_]EncodeEntry{.{
            .name = "compressed-with-zstd.txt",
            .data = payload,
            .method = method,
        }};
        const bytes = try encodeAlloc(allocator, &entries, .{
            .data_descriptor = true,
            .zstd_level = 3,
            .zstd_options = .{ .content_checksum = true },
        });
        defer allocator.free(bytes);

        const archive = try parse(bytes);
        const entry = try archive.entryAt(0);
        try std.testing.expectEqual(method, entry.method);
        try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.local_header_offset + 4));
        try std.testing.expectEqual(@as(u16, 63), try readU16(bytes, entry.central_header_offset + 6));
        var output: [payload.len]u8 = undefined;
        try std.testing.expectEqual(payload.len, try archive.extractInto(entry, &output));
        try std.testing.expectEqualSlices(u8, payload, &output);

        if (method == .zstandard_legacy) {
            const bad_central_version = try allocator.dupe(u8, bytes);
            defer allocator.free(bad_central_version);
            std.mem.writeInt(u16, bad_central_version[entry.central_header_offset + 6 ..][0..2], 62, .little);
            const bad_central_archive = try parse(bad_central_version);
            try std.testing.expectError(error.InvalidZipArchive, bad_central_archive.entryAt(0));

            const bad_local_version = try allocator.dupe(u8, bytes);
            defer allocator.free(bad_local_version);
            std.mem.writeInt(u16, bad_local_version[entry.local_header_offset + 4 ..][0..2], 62, .little);
            const bad_local_archive = try parse(bad_local_version);
            const bad_local_entry = try bad_local_archive.entryAt(0);
            try std.testing.expectError(error.InvalidZipArchive, bad_local_archive.extractInto(bad_local_entry, &output));
        }
    }
}
