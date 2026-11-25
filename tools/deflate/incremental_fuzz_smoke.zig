//! Deterministic smoke runner for the incremental Deflate decoder fuzz driver.
//! Each seed selects a zlib/gzip wrapper, a stored/fixed/best wire, a mutation,
//! decoder options and a caller step schedule; `drive` enforces progress
//! accounting, output canaries, sticky errors, reset reuse and one-shot
//! differential agreement. A violated invariant aborts non-zero, so this
//! binary doubles as a CI smoke and a manual regression probe.
const std = @import("std");
const deflate = @import("deflate");

const Counters = struct {
    accepted: usize = 0,
    rejected: usize = 0,
    incomplete: usize = 0,

    fn add(self: *Counters, result: deflate.incremental_fuzz.SeedResult) void {
        switch (result) {
            .accepted => self.accepted += 1,
            .rejected => self.rejected += 1,
            .incomplete => self.incomplete += 1,
        }
    }
};

pub fn main(init: std.process.Init) !void {
    const driver = deflate.incremental_fuzz;
    var counters = Counters{};

    // The fixed seed matrix covers every wrapper, regime, wire kind and
    // payload shape; named seeds pin a couple of wide/deterministic paths.
    for (driver.smoke_seeds) |seed| {
        counters.add(try driver.drive(init.gpa, &seed));
    }
    counters.add(try driver.drive(init.gpa, "vort-deflate-incremental-fuzz-multiblock"));
    counters.add(try driver.drive(init.gpa, "vort-deflate-incremental-fuzz-text"));

    const total = driver.smoke_seeds.len + 2;
    var stdout_buffer: [256]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writerStreaming(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;
    try stdout.print(
        "deflate incremental fuzz smoke: seeds={d} accepted={d} rejected={d} incomplete={d}\n",
        .{ total, counters.accepted, counters.rejected, counters.incomplete },
    );
    try stdout.flush();
}
