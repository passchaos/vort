const reduce = @import("../reduce.zig");
const terminal = @import("terminal_byte_codec.zig");

pub const Factor = reduce.Factor;
pub const Error = reduce.Error || terminal.Error;

const Codec = struct {
    pub const Config = Factor;
    pub const Workspace = reduce.IncrementalWorkspace;
    pub const Decoder = reduce.IncrementalDecoder;
    pub const Error = reduce.Error;

    pub fn initDecoder(
        workspace: *Workspace,
        factor: Config,
        entry_limit: usize,
        expected_output_len: ?usize,
    ) Decoder {
        return Decoder.initWithOptions(workspace, factor, .{
            .max_output_len = entry_limit,
            .expected_output_len = expected_output_len,
        });
    }

    pub fn truncatedError() reduce.Error {
        return error.TruncatedReduceInput;
    }
};

pub const State = terminal.State(Codec);
