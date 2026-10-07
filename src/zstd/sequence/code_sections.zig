const builtin = @import("builtin");

pub const long_match_decode = switch (builtin.object_format) {
    .elf => ".vort_zstd_zzz_long_match",
    .macho => "__TEXT,__vort_zstd_lm",
    .coff => ".text$zzz_vort_zstd_long_match",
    else => ".text",
};
