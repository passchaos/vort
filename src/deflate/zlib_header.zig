//! Fixed RFC 1950 header recognition, separate from caller admission policy.

pub fn plausibleCmf(cmf: u8) bool {
    return cmf & 0x0f == 8 and cmf >> 4 <= 7;
}

pub fn recognizes(cmf: u8, flg: u8) bool {
    return plausibleCmf(cmf) and ((@as(u16, cmf) << 8) | flg) % 31 == 0;
}

pub fn windowBits(cmf: u8, flg: u8) error{BadZlibHeader}!u4 {
    if (!recognizes(cmf, flg)) return error.BadZlibHeader;
    return @as(u4, @intCast(cmf >> 4)) + 8;
}

pub fn admitWindow(declared: u4, maximum: u4) error{ InvalidBlockPlan, OutputLimitExceeded }!void {
    if (maximum < 8) return error.InvalidBlockPlan;
    if (declared > maximum) return error.OutputLimitExceeded;
}
