const std = @import("std");
const legacy_common = @import("legacy_common.zig");
const rar15 = @import("rar15.zig");
const rar20 = @import("rar20.zig");

pub const Method = enum { rar15, rar20 };

pub const Error = rar15.Error || rar20.Error || std.mem.Allocator.Error || error{
    InvalidRarLegacySolidDictionary,
    RarLegacySessionPoisoned,
};

const max_shared_history: usize = 1024 * 1024;
const min_shared_history: usize = 256 * 1024;

/// Coordinates the shared RAR1.5/2.x solid window and distance registers while
/// leaving adaptive Huffman and audio/table state in their respective decoder.
pub const Session = struct {
    allocator: std.mem.Allocator,
    rar15_session: rar15.Session,
    rar20_session: rar20.Session,
    history: std.ArrayList(u8) = .empty,
    common: legacy_common.CommonState = .{},
    window_size: usize = 0,
    history_limit: usize = 0,
    active_method: ?Method = null,
    initialized: bool = false,
    poisoned: bool = false,

    pub fn init(allocator: std.mem.Allocator) Session {
        return .{
            .allocator = allocator,
            .rar15_session = rar15.Session.init(allocator),
            .rar20_session = rar20.Session.init(allocator),
        };
    }

    pub fn deinit(self: *Session) void {
        self.rar15_session.deinit();
        self.rar20_session.deinit();
        self.history.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Session) void {
        self.rar15_session.reset();
        self.rar20_session.reset();
        self.history.clearRetainingCapacity();
        self.common = .{};
        self.window_size = 0;
        self.history_limit = 0;
        self.active_method = null;
        self.initialized = false;
        self.poisoned = false;
    }

    pub fn canContinue(self: *const Session) bool {
        return self.initialized and !self.poisoned;
    }

    pub fn activeMethod(self: *const Session) ?Method {
        return self.active_method;
    }

    pub fn decodeMemberInto(
        self: *Session,
        method: Method,
        input: []const u8,
        output: []u8,
        dictionary_size: usize,
        solid: bool,
    ) Error!void {
        if (self.poisoned) return error.RarLegacySessionPoisoned;
        const declared_window = try windowSize(method, dictionary_size);
        if (!solid) {
            self.reset();
            self.window_size = declared_window;
            self.history_limit = @min(declared_window, max_shared_history);
        } else {
            if (!self.initialized) return switch (method) {
                .rar15 => error.MissingRar15SolidState,
                .rar20 => error.MissingRar20SolidState,
            };
            if (declared_window > self.window_size)
                return error.InvalidRarLegacySolidDictionary;
        }
        errdefer self.poisoned = true;

        if (solid and self.active_method != method) switch (method) {
            .rar15 => try self.rar15_session.synchronizeSolid(
                self.history.items,
                self.common,
            ),
            .rar20 => try self.rar20_session.synchronizeSolid(
                self.history.items,
                self.common,
                self.history_limit,
            ),
        };

        switch (method) {
            .rar15 => {
                try self.rar15_session.decodeMemberInto(input, output, solid);
                self.common = self.rar15_session.commonState();
                self.initialized = self.rar15_session.canContinue();
            },
            .rar20 => {
                try self.rar20_session.decodeMemberInto(
                    input,
                    output,
                    self.history_limit,
                    solid,
                );
                self.common = self.rar20_session.commonState();
                self.initialized = self.rar20_session.canContinue();
            },
        }
        try self.history.appendSlice(self.allocator, output);
        self.trimHistory();
        self.active_method = method;
        self.poisoned = false;
    }

    fn trimHistory(self: *Session) void {
        if (self.history.items.len <= self.history_limit) return;
        const discard = self.history.items.len - self.history_limit;
        @memmove(
            self.history.items[0..self.history_limit],
            self.history.items[discard..],
        );
        self.history.items.len = self.history_limit;
    }
};

fn windowSize(method: Method, dictionary_size: usize) Error!usize {
    return switch (method) {
        .rar15 => if (dictionary_size == 64 * 1024)
            min_shared_history
        else
            error.InvalidRarLegacySolidDictionary,
        .rar20 => if (dictionary_size >= 64 * 1024 and
            dictionary_size <= 4 * 1024 * 1024 and std.math.isPowerOfTwo(dictionary_size))
            @max(dictionary_size, min_shared_history)
        else
            error.InvalidRarLegacySolidDictionary,
    };
}
