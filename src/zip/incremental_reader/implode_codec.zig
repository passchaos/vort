const std = @import("std");
const core = @import("../../core.zig");
const implode = @import("../implode.zig");
const terminal = @import("terminal_byte_codec.zig");

pub const Error = implode.Error || terminal.Error;

const Codec = struct {
    pub const Config = u16;
    pub const Workspace = implode.IncrementalWorkspace;
    pub const Decoder = implode.IncrementalDecoder;
    pub const Error = implode.Error;

    pub fn initDecoder(
        workspace: *Workspace,
        flags: Config,
        entry_limit: core.StreamCount,
        expected_output_len: ?core.StreamCount,
    ) @This().Error!Decoder {
        return Decoder.initWithOptions(workspace, flags, .{
            .max_output_len = core.stream_count.bounded(entry_limit, std.math.maxInt(usize)),
            .expected_output_len = try terminal.toOptionalLocal(expected_output_len),
        });
    }

    pub fn truncatedError() implode.Error {
        return error.TruncatedImplodeInput;
    }
};

pub const State = terminal.State(Codec);
