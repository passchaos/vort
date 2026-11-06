const std = @import("std");
const ref = @import("incremental_relaxed/reference.zig");
const h = @import("incremental_relaxed/driver.zig");

pub fn main(init: std.process.Init) !void {
    var counts: h.Counts = .{};
    try @import("incremental_relaxed/footer.zig").run(init.gpa, &counts);
    try @import("incremental_relaxed/members.zig").run(init.gpa, &counts);
    try @import("incremental_relaxed/dictionary.zig").run(init.gpa, &counts);
    try h.require(counts.zero_output_steps > 0 and counts.need_input > 0 and counts.need_output > 0 and counts.done > 0);
    const version = ref.C.zlibVersion();
    if (version == null) return error.LibzVersion;
    var buffer: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writerStreaming(init.io, &buffer);
    try writer.interface.print(
        "incremental_relaxed_interop_reference zlib_version={s}\n" ++
            "incremental_relaxed_interop_ok cases={d} valid_splits={d} footer_matrix={d} partial_footers={d} malformed_payloads={d} tails={d} dictionaries={d} recognized_gzip_headers={d} finish_seals={d} tiny_input_bytes=1 tiny_output_bytes=3 steps={d} zero_output_steps={d} need_input={d} need_output={d} done={d}\n",
        .{ std.mem.span(version), counts.valid_splits + counts.footer_matrix + counts.partial_footers + counts.malformed_payloads + counts.tails + counts.dictionaries + counts.recognized_headers, counts.valid_splits, counts.footer_matrix, counts.partial_footers, counts.malformed_payloads, counts.tails, counts.dictionaries, counts.recognized_headers, counts.finish_seals, counts.steps, counts.zero_output_steps, counts.need_input, counts.need_output, counts.done },
    );
    try writer.interface.flush();
}
