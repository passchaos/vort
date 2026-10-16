//! Per-entry encryption states for the incremental ZIP reader.

const std = @import("std");
const descriptor = @import("descriptor.zig");
const reader_pkware_strong = @import("pkware_strong.zig");
const types = @import("../types.zig");
const wire = @import("../wire.zig");
const traditional_encryption = @import("vail_archive_crypto").zipcrypto;
const winzip_aes = @import("vail_archive_crypto").winzip_aes;

pub const Error = reader_pkware_strong.Error || traditional_encryption.Error ||
    winzip_aes.Error || std.mem.Allocator.Error;

pub const State = union(enum) {
    traditional: TraditionalState,
    winzip_aes: WinZipAesState,
    pkware_strong: reader_pkware_strong.State,

    pub const TraditionalState = struct {
        cipher: traditional_encryption.Cipher,
        header: [traditional_encryption.header_len]u8 = undefined,
        header_len: usize = 0,
        check_byte: u8,
        raw_tail: [wire.zip64_data_descriptor_len]u8 = undefined,
        raw_tail_len: usize = 0,
    };

    pub const WinZipAesState = struct {
        const raw_tail_capacity = winzip_aes.authentication_code_len +
            wire.zip64_data_descriptor_len + 1;

        info: types.WinZipAesInfo,
        header: [winzip_aes.max_salt_len + winzip_aes.password_verifier_len]u8 = undefined,
        header_len: usize = 0,
        cipher: ?winzip_aes.Cipher = null,
        authentication: [winzip_aes.authentication_code_len]u8 = undefined,
        authentication_len: usize = 0,
        raw_tail: [raw_tail_capacity]u8 = undefined,
        raw_tail_len: usize = 0,
        checkpoint: ?winzip_aes.Cipher = null,
    };

    pub fn initTraditional(password: []const u8, check_byte: u8) State {
        return .{ .traditional = .{
            .cipher = traditional_encryption.Cipher.init(password),
            .check_byte = check_byte,
        } };
    }

    pub fn initWinZipAes(info: types.WinZipAesInfo) State {
        return .{ .winzip_aes = .{ .info = info } };
    }

    pub fn initPkwareStrong(
        outer_compressed_size: ?usize,
        descriptor_layout: ?descriptor.Layout,
    ) State {
        return .{ .pkware_strong = reader_pkware_strong.State.init(
            outer_compressed_size,
            descriptor_layout,
        ) };
    }

    pub fn overhead(self: *const State) usize {
        return switch (self.*) {
            .traditional => traditional_encryption.header_len,
            .winzip_aes => |state| state.info.strength.overhead(),
            .pkware_strong => |state| state.headerLen(),
        };
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .traditional => |*state| {
                state.cipher.deinit();
                std.crypto.secureZero(u8, &state.header);
                std.crypto.secureZero(u8, &state.raw_tail);
            },
            .winzip_aes => |*state| {
                if (state.cipher) |*cipher| cipher.deinit();
                if (state.checkpoint) |*checkpoint| checkpoint.deinit();
                std.crypto.secureZero(u8, &state.header);
                std.crypto.secureZero(u8, &state.authentication);
                std.crypto.secureZero(u8, &state.raw_tail);
            },
            .pkware_strong => |*state| state.deinit(allocator),
        }
        self.* = undefined;
    }

    pub fn appendRawTail(self: *State, bytes: []const u8) void {
        return switch (self.*) {
            .traditional => |*state| appendTraditionalRawTail(state, bytes),
            .winzip_aes => |*state| appendWinZipAesRawTail(state, bytes),
            .pkware_strong => unreachable,
        };
    }

    pub fn appendTraditionalRawTail(state: *TraditionalState, bytes: []const u8) void {
        if (bytes.len >= state.raw_tail.len) {
            @memcpy(&state.raw_tail, bytes[bytes.len - state.raw_tail.len ..]);
            state.raw_tail_len = state.raw_tail.len;
            return;
        }
        const discard = state.raw_tail_len + bytes.len -| state.raw_tail.len;
        const retained = state.raw_tail_len - discard;
        std.mem.copyForwards(
            u8,
            state.raw_tail[0..retained],
            state.raw_tail[discard..state.raw_tail_len],
        );
        @memcpy(state.raw_tail[retained..][0..bytes.len], bytes);
        state.raw_tail_len = retained + bytes.len;
    }

    pub fn rawSuffix(self: *const State, len: usize) error{InvalidZipArchive}![]const u8 {
        return switch (self.*) {
            .traditional => |*state| blk: {
                if (len > state.raw_tail_len) return error.InvalidZipArchive;
                break :blk state.raw_tail[state.raw_tail_len - len .. state.raw_tail_len];
            },
            .winzip_aes => |*state| blk: {
                if (len > state.raw_tail_len) return error.InvalidZipArchive;
                break :blk state.raw_tail[state.raw_tail_len - len .. state.raw_tail_len];
            },
            .pkware_strong => unreachable,
        };
    }

    pub fn rollbackWinZipAesTrailing(
        self: *State,
        len: usize,
    ) error{InvalidZipArchive}![]const u8 {
        const state = &self.winzip_aes;
        if (len > state.raw_tail_len or state.checkpoint == null or state.cipher == null)
            return error.InvalidZipArchive;
        var corrected = state.checkpoint.?;
        defer corrected.deinit();
        decryptDiscard(&corrected, state.raw_tail[0 .. state.raw_tail_len - len]);
        state.cipher.?.deinit();
        state.cipher = corrected;
        return state.raw_tail[state.raw_tail_len - len .. state.raw_tail_len];
    }

    pub fn appendWinZipAesRawTail(state: *WinZipAesState, bytes: []const u8) void {
        const capacity = state.raw_tail.len;
        if (bytes.len >= capacity) {
            advanceCheckpoint(state, state.raw_tail[0..state.raw_tail_len]);
            advanceCheckpoint(state, bytes[0 .. bytes.len - capacity]);
            @memcpy(&state.raw_tail, bytes[bytes.len - capacity ..]);
            state.raw_tail_len = capacity;
            return;
        }
        const discard = state.raw_tail_len + bytes.len -| capacity;
        advanceCheckpoint(state, state.raw_tail[0..discard]);
        const retained = state.raw_tail_len - discard;
        std.mem.copyForwards(
            u8,
            state.raw_tail[0..retained],
            state.raw_tail[discard..state.raw_tail_len],
        );
        @memcpy(state.raw_tail[retained..][0..bytes.len], bytes);
        state.raw_tail_len = retained + bytes.len;
    }

    pub fn advanceCheckpoint(state: *WinZipAesState, bytes: []const u8) void {
        if (bytes.len == 0) return;
        decryptDiscard(&state.checkpoint.?, bytes);
    }

    pub fn decryptDiscard(cipher: *winzip_aes.Cipher, bytes: []const u8) void {
        var discarded: [256]u8 = undefined;
        defer std.crypto.secureZero(u8, &discarded);
        var offset: usize = 0;
        while (offset < bytes.len) {
            const take = @min(discarded.len, bytes.len - offset);
            cipher.decrypt(bytes[offset..][0..take], discarded[0..take]);
            offset += take;
        }
    }
};
