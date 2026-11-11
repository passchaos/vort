const builtin = @import("builtin");
const fast_bit_reader = @import("../fast_bit_reader.zig");

/// Identifies the exact executor selected at the shared prepared dispatcher.
/// Inner helper specializations are deliberately not inferred from this tag.
pub const Route = enum {
    flat_literal_tail,
    single_external_literal,
    external_auxiliary_zero_postfix,
    external_auxiliary_postfix,
    external_generic,
    wide9_literal,
    paired_wide_literal,
    wide10_generic_literal,
    generic_prepared,
    small_generic,
};

/// Normal callers pass a comptime-known null route. Diagnostics call the same
/// decisions and executors with a local output tag; token loops do not trace.
pub inline fn execute(
    comptime Codec: type,
    reader: *Codec.Reader,
    output: []u8,
    written: *usize,
    meta_block_len: usize,
    meta_block_end: usize,
    last_distances: *[4]usize,
    window_bits: u5,
    header: *Codec.Header,
    route: ?*Route,
) Codec.Error!void {
    if (header.literal_tree_count >= Codec.clustered_literal_tree_threshold and
        header.literal_tree_count <= Codec.inline_literal_tree_count and
        try Codec.processFlatLiteralTailLookupMetaBlock(reader, output, written, meta_block_end, last_distances, window_bits, header))
    {
        if (route) |selected| selected.* = .flat_literal_tail;
        return;
    }
    if (meta_block_len >= Codec.external_literal_lookup_meta_block_min and
        header.literal_tree_count <= Codec.external_literal_lookup_tree_limit)
    {
        var literal_lookups: [Codec.external_literal_lookup_tree_limit]Codec.ExternalLiteralLookup = undefined;
        try Codec.prepareExternalLiteralLookups(header, &literal_lookups);
        if (builtin.is_test) Codec.recordExternalLiteralLookup();
        if (header.literal_tree_count == 1 and
            header.literal_block.block_type_count == 1 and
            header.command_block.block_type_count == 1 and
            header.distance_tree_count == 1 and
            header.distance_block.block_type_count == 1)
        {
            if (builtin.is_test) Codec.recordSingleTreeExternalLookup();
            var command_lookup = if (header.insert_copy_trees[0].single_symbol) |symbol|
                try Codec.SingleCommandLookup.initSingle(symbol)
            else
                try Codec.SingleCommandLookup.init(&header.insert_copy_trees[0].table);
            var distance_lookup = if (header.distance_trees[0].single_symbol) |symbol|
                try Codec.ExternalDistanceLookup.initSingle(symbol)
            else
                try Codec.ExternalDistanceLookup.init(&header.distance_trees[0].table);
            var fast_reader = fast_bit_reader.Reader.initFrom(reader.*);
            defer fast_reader.syncTo(reader);
            if (route) |selected| selected.* = .single_external_literal;
            return Codec.processSingleTreeExternalLookupCompressedPayload(
                &fast_reader,
                output,
                written,
                meta_block_end,
                last_distances,
                window_bits,
                header,
                &literal_lookups[0],
                &command_lookup,
                &distance_lookup,
            );
        }
        const auxiliary_tail_lookups = Codec.prepareAuxiliaryTailLookups(header);
        var fast_reader = fast_bit_reader.Reader.initFrom(reader.*);
        defer fast_reader.syncTo(reader);
        if (auxiliary_tail_lookups) {
            if (header.npostfix == 0) {
                if (route) |selected| selected.* = .external_auxiliary_zero_postfix;
                return Codec.processExternalLiteralLookupCompressedPayload(true, true, &fast_reader, output, written, meta_block_end, last_distances, window_bits, header, &literal_lookups);
            }
            if (route) |selected| selected.* = .external_auxiliary_postfix;
            return Codec.processExternalLiteralLookupCompressedPayload(true, false, &fast_reader, output, written, meta_block_end, last_distances, window_bits, header, &literal_lookups);
        }
        if (route) |selected| selected.* = .external_generic;
        return Codec.processExternalLiteralLookupCompressedPayload(false, false, &fast_reader, output, written, meta_block_end, last_distances, window_bits, header, &literal_lookups);
    }
    if (meta_block_len >= Codec.external_literal_lookup_meta_block_min) {
        if (header.literal_tree_count <= Codec.external_literal_lookup_middle_tree_limit) {
            if (route) |selected| selected.* = .wide9_literal;
            return Codec.processWideExternalLiteralLookup9MetaBlock(Codec.external_literal_lookup_middle_tree_limit, reader, output, written, meta_block_end, last_distances, window_bits, header);
        }
        if (Codec.prepareAuxiliaryTailLookups(header)) {
            if (route) |selected| selected.* = .paired_wide_literal;
            return Codec.processPairedWideLiteralMetaBlock(reader, output, written, meta_block_end, last_distances, window_bits, header);
        }
        if (route) |selected| selected.* = .wide10_generic_literal;
        return Codec.processWideExternalLiteralLookupMetaBlock(Codec.max_literal_context_trees, reader, output, written, meta_block_end, last_distances, window_bits, header);
    }
    if (route) |selected| selected.* = .generic_prepared;
    return Codec.processDecodedCompressedPayload(reader, output, written, meta_block_end, last_distances, window_bits, header);
}
