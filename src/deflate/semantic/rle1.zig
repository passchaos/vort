const builtin = @import("builtin");

/// Keep the PNG filter-0 distance-one decoder outside ordinary DEFLATE text.
/// The wider literal table is intentionally limited to this measured shape;
/// isolating its code prevents unrelated PNG/DEFLATE functions from moving.
pub const text_section = switch (builtin.object_format) {
    .elf => ".vort_png_rle1",
    .macho => "__TEXT,__vort_png_rle1",
    .coff => ".text$vort_png_rle1",
    else => ".text",
};
