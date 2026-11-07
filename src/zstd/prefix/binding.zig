//! Once-usage prefix bookkeeping. Dictionary payload stays caller-owned.
const std = @import("std");

pub const Usage = enum(u1) { persistent, prefix };
pub const Phase = enum(u2) { none, pending, active };
pub const Purpose = enum(u2) { none, call, frame, skippable };
pub const ContentType = enum(u1) { raw, full };
pub const ResetMode = enum { session, parameters, both };
pub const Directive = enum(c_int) { @"continue" = 0, flush = 1, end = 2, _ };

pub const Snapshot = struct {
    phase: Phase = .none,
    pending: bool = false,
    active: bool = false,
    dictionary_id: ?u32 = null,
    content_type: ?ContentType = null,
    used_for: Purpose = .none,
    setter_eligible: bool = true,
    usage: Usage = .persistent,
};

pub fn hasBytes(dictionary: anytype) bool {
    if (@hasField(@TypeOf(dictionary), "standard_bytes")) {
        if (dictionary.standard_bytes) |bytes| return bytes.len != 0;
    }
    return dictionary.content.len != 0;
}

/// The compact phase lives beside the owner's existing dictionary slot.
/// Completing or aborting a prefix session clears that slot rather than
/// changing active back into pending, so clones cannot reattach used bytes.
pub const State = packed struct(u64) {
    id: u32 = 0,
    phase: Phase = .none,
    purpose: Purpose = .none,
    content_type: ContentType = .raw,
    busy: bool = false,
    configured: bool = false,
    reserved: u25 = 0,

    pub fn install(self: *State, dictionary: anytype) void {
        self.phase = if (hasBytes(dictionary)) .pending else .none;
        self.id = if (self.phase == .pending) dictionary.id else 0;
        self.content_type = if (@hasField(@TypeOf(dictionary), "standard_bytes") and dictionary.standard_bytes != null) .full else .raw;
        self.purpose = .none;
        self.configured = self.phase == .pending;
    }

    pub fn activate(self: *State, purpose: Purpose) bool {
        if (self.phase != .pending) return false;
        self.phase = .active;
        self.purpose = purpose;
        return true;
    }

    pub fn complete(self: *State, dictionary: anytype) void {
        if (self.phase == .active) {
            dictionary.* = null;
            self.phase = .none;
            self.id = 0;
            self.configured = false;
        }
        self.busy = false;
    }

    pub fn resetSession(self: *State, dictionary: anytype) void {
        self.complete(dictionary);
        self.busy = false;
    }

    pub fn clear(self: *State, dictionary: anytype) void {
        dictionary.* = null;
        self.* = .{};
    }

    pub fn snapshot(self: State) Snapshot {
        return .{
            .phase = self.phase,
            .pending = self.phase == .pending,
            .active = self.phase == .active,
            .dictionary_id = if (self.phase == .none) null else self.id,
            .content_type = if (self.phase == .none) null else self.content_type,
            .used_for = self.purpose,
            .setter_eligible = !self.busy,
            .usage = if (self.phase == .none) .persistent else .prefix,
        };
    }
};

pub fn Slot(comptime Dictionary: type) type {
    return struct {
        dictionary: ?Dictionary = null,
        state: State = .{},
        const Self = @This();

        pub fn setPrefix(self: *Self, dictionary: Dictionary) void {
            self.dictionary = if (hasBytes(dictionary)) dictionary else null;
            self.state.install(dictionary);
        }
        pub fn setDictionary(self: *Self, dictionary: ?Dictionary) void {
            self.state = .{};
            self.dictionary = dictionary;
            self.state.configured = dictionary != null;
        }
        pub fn clear(self: *Self) void {
            self.state.clear(&self.dictionary);
        }
        pub fn complete(self: *Self) void {
            self.state.complete(&self.dictionary);
        }
        pub fn resetSession(self: *Self) void {
            self.state.resetSession(&self.dictionary);
        }
    };
}

test "Zstd prefix lifecycle binding session resets retain only pending and consumed clones stay cleared" {
    const Dictionary = struct { id: u32, content: []const u8, standard_bytes: ?[]const u8 = null };
    var slot: Slot(Dictionary) = .{};
    slot.setPrefix(.{ .id = 0, .content = "borrowed" });
    slot.resetSession();
    try std.testing.expect(slot.state.snapshot().pending);
    try std.testing.expect(slot.state.activate(.skippable));
    slot.complete();
    var clone = slot;
    clone.resetSession();
    try std.testing.expect(clone.dictionary == null);
    try std.testing.expect(!clone.state.activate(.frame));
    slot.setDictionary(.{ .id = 42, .content = "persistent" });
    slot.setPrefix(.{ .id = 0, .content = "" });
    try std.testing.expect(slot.dictionary == null);
    try std.testing.expect(!slot.state.snapshot().pending);
}
