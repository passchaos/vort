//! Deterministic smoke runner for the incremental Zstd decoder fuzz driver.
//!
//! Each seed independently selects a generated wire, a mutation, decoder
//! options and a caller step schedule; `drive` enforces progress accounting,
//! output canaries, resource caps, sticky errors, reset reuse and one-shot
//! differential agreement. A violated invariant aborts the process non-zero,
//! so this binary doubles as a CI smoke and a manual regression probe.
const std = @import("std");
const zstd = @import("zstd");

const Counters = struct {
    accepted: usize = 0,
    rejected: usize = 0,
    incomplete: usize = 0,

    fn add(self: *Counters, result: zstd.incremental_fuzz.SeedResult) void {
        switch (result) {
            .accepted => self.accepted += 1,
            .rejected => self.rejected += 1,
            .incomplete => self.incomplete += 1,
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const driver = zstd.incremental_fuzz;
    var counters = Counters{};

    // The fixed seed matrix covers every regime, format, policy and payload
    // shape; named seeds additionally pin a couple of wide/deterministic paths.
    for (driver.smoke_seeds) |seed| {
        counters.add(try driver.drive(init.gpa, &seed));
    }
    counters.add(try driver.drive(init.gpa, "vort-incremental-fuzz-multiblock"));
    counters.add(try driver.drive(init.gpa, "vort-incremental-fuzz-text"));

    const total = driver.smoke_seeds.len + 2;
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        "zstd incremental fuzz smoke: seeds={d} accepted={d} rejected={d} incomplete={d}\n",
        .{ total, counters.accepted, counters.rejected, counters.incomplete },
    );
    try stdout.flush();
}
