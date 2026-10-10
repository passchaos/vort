const builtin = @import("builtin");

pub const large_window = switch (builtin.object_format) {
    .elf => ".vort_br_large_window",
    .macho => "__TEXT,__vort_br_lgwin",
    .coff => ".text$vort_br_large_window",
    else => ".text",
};

pub const wide_literal_lookup9 = switch (builtin.object_format) {
    .elf => ".vort_br_wide_lookup9",
    .macho => "__TEXT,__vort_br_w9",
    .coff => ".text$vort_br_wide9",
    else => ".text",
};

pub const wide_literal_lookup10_auxiliary = switch (builtin.object_format) {
    .elf => ".vort_br_wide_lookup10_aux",
    .macho => "__TEXT,__vort_br_w10",
    .coff => ".text$vort_br_wide10_aux",
    else => ".text",
};
