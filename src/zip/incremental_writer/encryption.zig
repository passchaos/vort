//! Per-entry encryption states for the incremental ZIP writer.

const std = @import("std");
const pkware_strong = @import("../pkware_strong.zig");
const types = @import("../types.zig");
const wire = @import("../wire.zig");
const zip_writer = @import("../writer.zig");
const traditional_encryption = @import("vail_archive_crypto").zipcrypto;
const winzip_aes = @import("vail_archive_crypto").winzip_aes;

pub const Error = pkware_strong.Error || winzip_aes.Error || std.mem.Allocator.Error;

pub const State = union(enum) {
    traditional: TraditionalState,
    winzip_aes: WinZipAesState,
    pkware_strong: PkwareStrongState,

    pub const TraditionalState = struct {
        cipher: traditional_encryption.Cipher,
        header: [traditional_encryption.header_len]u8,
    };

    pub const WinZipAesState = struct {
        cipher: winzip_aes.Cipher,
        header: [winzip_aes.max_salt_len + winzip_aes.password_verifier_len]u8,
        header_len: usize,
        info: types.WinZipAesInfo,
    };

    pub const PkwareStrongState = struct {
        encryptor: @import("vail_archive_crypto").pkware_strong_stream.Encryptor,
        header: []u8,
        info: types.PkwareStrongEncryptionInfo,
        codec_output: [256]u8 = undefined,
        codec_output_pos: usize = 0,
        codec_output_len: usize = 0,
        codec_finish_requested: bool = false,
        codec_done: bool = false,
    };

    pub fn initTraditional(options: traditional_encryption.Options) State {
        var cipher = traditional_encryption.Cipher.init(options.password);
        var header_bytes: [traditional_encryption.header_len]u8 = undefined;
        cipher.encrypt(
            &options.header_random,
            header_bytes[0..traditional_encryption.header_random_len],
        );
        header_bytes[traditional_encryption.header_random_len] = cipher.encryptByte(
            @truncate(wire.deterministic_dos_time >> 8),
        );
        return .{ .traditional = .{ .cipher = cipher, .header = header_bytes } };
    }

    pub fn initWinZipAes(options: zip_writer.WinZipAesOptions) Error!State {
        var cipher = try winzip_aes.Cipher.init(
            options.password,
            options.salt,
            options.strength,
        );
        errdefer cipher.deinit();
        var header_bytes: [winzip_aes.max_salt_len + winzip_aes.password_verifier_len]u8 = undefined;
        @memcpy(header_bytes[0..options.salt.len], options.salt);
        header_bytes[options.salt.len..][0..winzip_aes.password_verifier_len].* =
            cipher.passwordVerifier();
        return .{ .winzip_aes = .{
            .cipher = cipher,
            .header = header_bytes,
            .header_len = options.salt.len + winzip_aes.password_verifier_len,
            .info = .{ .version = options.version, .strength = options.strength },
        } };
    }

    pub fn initPkwareStrong(
        allocator: std.mem.Allocator,
        options: zip_writer.PkwareStrongEncryptionOptions,
    ) Error!State {
        var prepared = try pkware_strong.prepareStreamEncryptAlloc(allocator, options);
        errdefer prepared.deinit(allocator);
        const header_bytes = prepared.header;
        const encryptor = prepared.encryptor;
        prepared = undefined;
        return .{ .pkware_strong = .{
            .encryptor = encryptor,
            .header = header_bytes,
            .info = .{ .strength = options.strength },
        } };
    }

    pub fn header(self: *const State) []const u8 {
        return switch (self.*) {
            .traditional => |*state| &state.header,
            .winzip_aes => |*state| state.header[0..state.header_len],
            .pkware_strong => |state| state.header,
        };
    }

    pub fn encryptInPlace(self: *State, output: []u8) void {
        switch (self.*) {
            .traditional => |*state| {
                for (output) |*byte| byte.* = state.cipher.encryptByte(byte.*);
            },
            .winzip_aes => |*state| state.cipher.encrypt(output, output),
            .pkware_strong => unreachable,
        }
    }

    pub fn authenticationCode(self: *const State) ?[winzip_aes.authentication_code_len]u8 {
        return switch (self.*) {
            .traditional => null,
            .winzip_aes => |*state| state.cipher.authenticationCode(),
            .pkware_strong => null,
        };
    }

    pub fn aesInfo(self: *const State) ?types.WinZipAesInfo {
        return switch (self.*) {
            .traditional => null,
            .winzip_aes => |state| state.info,
            .pkware_strong => null,
        };
    }

    pub fn pkwareInfo(self: *const State) ?types.PkwareStrongEncryptionInfo {
        return switch (self.*) {
            .pkware_strong => |state| state.info,
            else => null,
        };
    }

    pub fn pkwareState(self: *State) ?*PkwareStrongState {
        return switch (self.*) {
            .pkware_strong => |*state| state,
            else => null,
        };
    }

    pub fn deinit(self: *State, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .traditional => |*state| {
                state.cipher.deinit();
                std.crypto.secureZero(u8, &state.header);
            },
            .winzip_aes => |*state| {
                state.cipher.deinit();
                std.crypto.secureZero(u8, &state.header);
            },
            .pkware_strong => |*state| {
                state.encryptor.deinit();
                std.crypto.secureZero(u8, state.header);
                allocator.free(state.header);
                std.crypto.secureZero(u8, &state.codec_output);
            },
        }
        self.* = undefined;
    }
};
