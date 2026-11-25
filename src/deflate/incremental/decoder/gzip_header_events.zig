//! Borrowed, synchronous observation of RFC 1952 member headers.
const std = @import("std");
const Count = @import("../../../core.zig").StreamCount;

pub const Field = enum { extra, filename, comment };

pub const MemberHeader = struct {
    member_index: Count,
    member_offset: Count,
    text: bool,
    mtime: u32,
    extra_flags: u8,
    os: u8,
    has_extra: bool,
    has_filename: bool,
    has_comment: bool,
    has_header_crc: bool,

    pub fn fromFixed(bytes: *const [10]u8, member_index: Count, member_offset: Count) MemberHeader {
        const flags = bytes[3];
        return .{
            .member_index = member_index,
            .member_offset = member_offset,
            .text = flags & 1 != 0,
            .mtime = std.mem.readInt(u32, bytes[4..8], .little),
            .extra_flags = bytes[8],
            .os = bytes[9],
            .has_extra = flags & 0x04 != 0,
            .has_filename = flags & 0x08 != 0,
            .has_comment = flags & 0x10 != 0,
            .has_header_crc = flags & 0x02 != 0,
        };
    }
};

pub const FieldChunk = struct {
    member_index: Count,
    field: Field,
    /// Zero-based byte offset within the field; excludes XLEN and NULs used
    /// as filename/comment terminators. Extra-field bytes are opaque.
    offset: usize,
    /// Nonempty, read-only, and valid only for the synchronous callback.
    bytes: []const u8,
};

pub const Completion = struct {
    member_index: Count,
    /// Absolute compressed input offset immediately after the member header.
    header_end_offset: Count,
};

pub const Event = union(enum) {
    /// Fixed header was recognized; optional fields may still fail validation.
    start: MemberHeader,
    /// Provisional until `complete`. Empty fields are indicated by the
    /// presence flags without a corresponding chunk.
    field: FieldChunk,
    /// Full header (including FHCRC, when present) is valid. No plaintext
    /// from this member has been written yet. This does not verify its body.
    complete: Completion,
};

pub const Observer = struct {
    context: ?*anyopaque = null,
    on_event: *const fn (?*anyopaque, Event) void,

    pub fn emit(self: Observer, event: Event) void {
        self.on_event(self.context, event);
    }

    pub fn emitField(self: Observer, member_index: Count, field: Field, offset: usize, bytes: []const u8) void {
        if (bytes.len != 0) self.emit(.{ .field = .{
            .member_index = member_index,
            .field = field,
            .offset = offset,
            .bytes = bytes,
        } });
    }
};
