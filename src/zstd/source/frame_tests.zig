const common = @import("frame_tests/common.zig");
const header = @import("frame_tests/header.zig");
const block = @import("frame_tests/block.zig");

pub const FrameFormat = common.FrameFormat;
pub const SliceHeaderResult = common.SliceHeaderResult;
pub const SliceBlockKind = common.SliceBlockKind;
pub const SliceBlockResult = common.SliceBlockResult;

pub fn contracts(comptime Support: type) !void {
    try header.contracts(Support);
    try block.contracts(Support);
}
