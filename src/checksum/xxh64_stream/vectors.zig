//! Frozen independent XXH64 vectors and constructive large-length checkpoints.
pub const Vector = struct { seed: u64, bytes: []const u8, expected: u64 };
pub const vectors = [_]Vector{
    .{ .seed = 0x0, .bytes = "", .expected = 0xef46db3751d8e999 },
    .{ .seed = 0x0, .bytes = "a", .expected = 0xd24ec4f1a98c6e5b },
    .{ .seed = 0x0, .bytes = "abc", .expected = 0x44bc2cf5ad770999 },
    .{ .seed = 0x0, .bytes = "message digest", .expected = 0x066ed728fceeb3be },
    .{ .seed = 0x0, .bytes = "abcdefghijklmnopqrstuvwxyz", .expected = 0xcfe1f278fa89835c },
    .{ .seed = 0x1, .bytes = "", .expected = 0xd5afba1336a3be4b },
    .{ .seed = 0x1, .bytes = "a", .expected = 0xdec2bc81c3cd46c6 },
    .{ .seed = 0x1, .bytes = "abc", .expected = 0xbea9ca8199328908 },
    .{ .seed = 0x1, .bytes = "message digest", .expected = 0xcba434b6417dd0fd },
    .{ .seed = 0x1, .bytes = "abcdefghijklmnopqrstuvwxyz", .expected = 0x58058c6ec112e95e },
    .{ .seed = 0x123456789abcdef, .bytes = "", .expected = 0x51e24c0e9077a48c },
    .{ .seed = 0x123456789abcdef, .bytes = "a", .expected = 0x63a379f532ba23d4 },
    .{ .seed = 0x123456789abcdef, .bytes = "abc", .expected = 0x1fc03ef74cebaa7d },
    .{ .seed = 0x123456789abcdef, .bytes = "message digest", .expected = 0x32b08277dfabf4a4 },
    .{ .seed = 0x123456789abcdef, .bytes = "abcdefghijklmnopqrstuvwxyz", .expected = 0x7838bf386b77f9e0 },
    .{ .seed = 0xffffffffffffffff, .bytes = "", .expected = 0x298f4c84b24f5380 },
    .{ .seed = 0xffffffffffffffff, .bytes = "a", .expected = 0x60c43759873ece62 },
    .{ .seed = 0xffffffffffffffff, .bytes = "abc", .expected = 0x28306e589cc02176 },
    .{ .seed = 0xffffffffffffffff, .bytes = "message digest", .expected = 0x989586faefaf1e78 },
    .{ .seed = 0xffffffffffffffff, .bytes = "abcdefghijklmnopqrstuvwxyz", .expected = 0xff6af998d28aca95 },
};
pub const Large = struct { seed: u64, stripe: [32]u8, before: u64, after: u64, exact: u64 };
pub const large = [_]Large{
    .{ .seed = 0x0, .stripe = .{ 0x00, 0x22, 0x6c, 0x1d, 0x6f, 0x85, 0x6e, 0xd8, 0x49, 0x21, 0x4c, 0xe4, 0x35, 0x06, 0xb4, 0xaf, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x9a, 0xb3, 0x52, 0xb0, 0xac, 0x87, 0xb8, 0xf8 }, .before = 0xdf58cf37dc00b095, .after = 0xc0269e70681841e6, .exact = 0x553f8a53d28f87d6 },
    .{ .seed = 0x123456789abcdef, .stripe = .{ 0x96, 0x47, 0xca, 0xfd, 0xcf, 0x4e, 0x16, 0x87, 0xdf, 0x46, 0xaa, 0xc4, 0x96, 0xcf, 0x5b, 0x5e, 0x96, 0x25, 0x5e, 0xe0, 0x60, 0xc9, 0xa7, 0xae, 0xdf, 0x24, 0x3e, 0xa7, 0x27, 0x4a, 0xed, 0x85 }, .before = 0xf844031ec4591fa4, .after = 0x1ba732b75b99a2b0, .exact = 0x1b39b4eb2e60120e },
};
