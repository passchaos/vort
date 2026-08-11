# Validation JSON schemas

Vort validation tools emit machine-readable JSON for CI and scripts. These
schemas are intentionally small and versioned. Consumers should gate on both
`schema` and `schema_version` before interpreting fields.

Compatibility rules for version `1`:

- New optional fields may be added without changing `schema_version`.
- Existing field names and meanings should remain stable.
- A breaking rename, type change, or semantic change requires a new
  `schema_version`.
- Numeric byte offsets are zero-based.
- Nullable numeric fields are encoded as JSON `null` when the validation failure
  happened before a frame was identified.

## `vort.validation_report`

Produced by:

```sh
zig build run -- verify-vort-sidecar-index-file <stream> <sidecar> [full|metadata] json
zig build run -- verify-vort-embedded-index-file <stream> [full|metadata] json
```

Fields:

| field | type | meaning |
| --- | --- | --- |
| `schema` | string | Always `vort.validation_report`. |
| `schema_version` | integer | Currently `1`. |
| `target` | string | `sidecar` or `embedded`. |
| `ok` | boolean | Whether validation succeeded. |
| `mode` | string | `metadata` or `full`. |
| `stage` | string | Validation stage at failure, or the default stage when `ok=true`. |
| `error` | string | Error name, empty when `ok=true`. |
| `recoverability_hint` | string | `none`, `index_mismatch`, `payload_corrupt`, `retry_with_dictionary`, or `truncated_input`. |
| `frame_index` | integer/null | Index entry that failed. |
| `frame_offset` | integer/null | Compressed stream byte offset of the failed frame. |
| `uncompressed_offset` | integer/null | Uncompressed byte offset represented by the failed frame. |
| `frame_flags` | integer/null | Native frame mode flag. |
| `frame_mode` | string | Human-readable frame mode such as `store`, `deflate`, `rle`, `dictionary_patch`, `dictionary_deflate`, or `ldm`. |
| `frame_count` | integer | Number of indexed frames summarized on successful validation, otherwise `0`. |
| `total_uncompressed` | integer | Total indexed uncompressed byte count on successful validation, otherwise `0`. |
| `combined_checksum` | integer/null | CRC-32 composed from indexed per-frame CRCs on successful validation. |
| `stream_bytes` | integer | Input stream byte length read by the CLI. |
| `sidecar_bytes` | integer/null | Sidecar byte length, or `null` for embedded-index validation. |

Example failure:

```json
{
  "schema": "vort.validation_report",
  "schema_version": 1,
  "target": "sidecar",
  "ok": false,
  "mode": "full",
  "stage": "payload_decode",
  "error": "ChecksumMismatch",
  "recoverability_hint": "payload_corrupt",
  "frame_index": 0,
  "frame_offset": 0,
  "uncompressed_offset": 0,
  "frame_flags": 1,
  "frame_mode": "deflate",
  "frame_count": 0,
  "total_uncompressed": 0,
  "combined_checksum": null,
  "stream_bytes": 2868,
  "sidecar_bytes": 128
}
```

## `vort.sidecar_verify_report`

Produced by:

```sh
zig build run-sidecar-verify-report -- --json <out.json> <stream> <sidecar>
```

Top-level fields:

| field | type | meaning |
| --- | --- | --- |
| `schema` | string | Always `vort.sidecar_verify_report`. |
| `schema_version` | integer | Currently `1`. |
| `rows` | integer | Number of report rows. |
| `ok_rows` | integer | Rows with `status=ok`. |
| `error_rows` | integer | Rows with `status=error`. |
| `total_stream_bytes` | integer | Sum of stream bytes over rows. |
| `total_sidecar_bytes` | integer | Sum of sidecar bytes over rows. |
| `total_entries` | integer | Sum of decoded sidecar index entries over rows. |
| `total_uncompressed_bytes` | integer | Sum of indexed uncompressed bytes over rows. |
| `items` | array | Per-pair validation rows. |

Each item includes the `vort.validation_report` context fields plus path and
aggregate fields. Successful rows expose both `total_uncompressed` and the
combined checksum summary computed from indexed frame CRCs.

- `stream`, `sidecar`
- `status`, `error`
- `mode`
- `recoverability_hint`, `validation_stage`, `frame_index`, `frame_offset`,
  `uncompressed_offset`, `frame_flags`, `frame_mode`
- `stream_bytes`, `sidecar_bytes`, `entries`, `total_uncompressed`,
  `combined_checksum`, `crc32`

Example:

```json
{
  "schema": "vort.sidecar_verify_report",
  "schema_version": 1,
  "rows": 1,
  "ok_rows": 0,
  "error_rows": 1,
  "items": [
    {
      "stream": "/tmp/bad.vort",
      "sidecar": "/tmp/bad.vidx",
      "mode": "full",
      "status": "error",
      "error": "ChecksumMismatch",
      "recoverability_hint": "payload_corrupt",
      "validation_stage": "payload_decode",
      "frame_index": 0,
      "frame_offset": 0,
      "uncompressed_offset": 0,
      "frame_flags": 1,
      "frame_mode": "deflate",
      "stream_bytes": 2868,
      "sidecar_bytes": 128,
      "entries": 1,
      "total_uncompressed": 4096,
      "combined_checksum": null,
      "crc32": 1234567890
    }
  ]
}
```

## `vort.sidecar_corrupt_smoke_report`

Produced by:

```sh
zig build run-sidecar-verify-report -- --self-test-corrupt --json <out.json>
zig build run-sidecar-corrupt-dashboard
```

Fields:

| field | type | meaning |
| --- | --- | --- |
| `schema` | string | Always `vort.sidecar_corrupt_smoke_report`. |
| `schema_version` | integer | Currently `1`. |
| `rows` | integer | Number of corrupt-payload cases. |
| `metadata_ok_rows` | integer | Cases accepted by metadata-only validation. |
| `full_rejected_rows` | integer | Cases rejected by full validation. |
| `items` | array | Case-level results. |

Each item contains:

- `case`
- `metadata_ok`
- `full_rejected`
- `full_error`
- `stream_bytes`
- `sidecar_bytes`

Example:

```json
{
  "schema": "vort.sidecar_corrupt_smoke_report",
  "schema_version": 1,
  "rows": 1,
  "metadata_ok_rows": 1,
  "full_rejected_rows": 1,
  "items": [
    {
      "case": "deflate",
      "metadata_ok": true,
      "full_rejected": true,
      "full_error": "TruncatedFrame",
      "stream_bytes": 44,
      "sidecar_bytes": 48
    }
  ]
}
```

## `vort.header_inspect_smoke`

Produced by:

```sh
zig build run-header-inspect-dashboard
```

This schema summarizes the CLI smoke that inspects raw DEFLATE, zlib, and gzip
headers through both hex and file workflows. It is intended to keep format
metadata diagnostics covered by CI and dashboard artifacts. The same build step
also writes `zig-out/vort-header-inspect-smoke.md` for human-readable review,
including per-format success totals plus grouped success and malformed-header
tables. Raw dynamic rows include compact RLE16/RLE17/RLE18 counts in their
human-readable detail. Long hex samples are shortened in Markdown only; JSON `sample` and
`argv` fields remain complete for replay.

Important fields:

- `schema`: `vort.header_inspect_smoke`
- `schema_version`: `1`
- `ok`: whether the smoke passed
- `case_count`, `raw_cases`, `zlib_cases`, `gzip_cases`
  (checked against the `cases` array by the schema manifest)
- `command_coverage`, `command_count`, `command_successes`, `command_failures`:
  per-command success/failure rows and totals, checked against `cases` and
  `negative_items` by the schema manifest
- `workflow_coverage`, `workflow_count`, `workflow_successes`,
  `required_workflows`, `required_workflow_count`, `missing_workflows`,
  `missing_workflow_count`, `help_workflows`, `help_workflow_count`: hex/file
  coverage rows plus the required and CLI-help-advertised coverage matrices;
  smoke fails if any required workflow is missing or if help and config diverge
- `negative_cases`, `raw_negative_cases`, `zlib_negative_cases`,
  `gzip_negative_cases`: malformed header cases expected to fail inspection
- `negative_error_counts`: malformed header failures grouped by expected error
- `negative_items`: case-level format/command/sample/argv/error matches for malformed headers
  (`command` and `expected_error` are enum-checked by the schema manifest)
- `dictionary_cases`: zlib FDICT/DICTID cases covered
- `optional_header_cases`, `fhcrc_cases`: gzip optional-header/FHCRC cases covered
- `cases`: case-level metadata including enum-checked `name`, human-readable
  `detail`, replayable `command`/`sample`/`argv`, format, JSON `schema_name`,
  byte size, data offset, and feature booleans. The manifest cross-checks `format` against `schema_name`
  and `schema_name` against the replay command; zlib/gzip cases may point at
  `vort.raw_deflate_header_info` when the replay command inspects the wrapped
  deflate payload.

Example:

```json
{
  "schema": "vort.header_inspect_smoke",
  "schema_version": 1,
  "ok": true,
  "case_count": 1,
  "raw_cases": 0,
  "zlib_cases": 1,
  "gzip_cases": 0,
  "command_count": 2,
  "command_successes": 1,
  "command_failures": 1,
  "workflow_count": 1,
  "workflow_successes": 1,
  "required_workflow_count": 1,
  "missing_workflow_count": 0,
  "help_workflow_count": 1,
  "help_workflows": [
    {
      "command": "inspect-zlib-header-hex",
      "workflow": "hex",
      "format": "zlib"
    }
  ],
  "required_workflows": [
    {
      "command": "inspect-zlib-header-hex",
      "workflow": "hex",
      "format": "zlib"
    }
  ],
  "missing_workflows": [],
  "workflow_coverage": [
    {
      "command": "inspect-zlib-header-hex",
      "workflow": "hex",
      "format": "zlib",
      "successes": 1
    }
  ],
  "command_coverage": [
    {
      "command": "inspect-raw-header-hex",
      "format": "raw",
      "successes": 0,
      "failures": 1
    },
    {
      "command": "inspect-zlib-header-hex",
      "format": "zlib",
      "successes": 1,
      "failures": 0
    }
  ],
  "negative_cases": 1,
  "negative_error_counts": {
    "InvalidDeflateBlockType": 1
  },
  "raw_negative_cases": 1,
  "zlib_negative_cases": 0,
  "gzip_negative_cases": 0,
  "negative_items": [
    {
      "name": "raw_reserved_btype",
      "format": "raw",
      "command": "inspect-raw-header-hex",
      "sample": "07",
      "argv": ["inspect-raw-header-hex", "07"],
      "expected_error": "InvalidDeflateBlockType",
      "matched": true
    }
  ],
  "dictionary_cases": 1,
  "optional_header_cases": 0,
  "fhcrc_cases": 0,
  "cases": [
    {
      "name": "zlib_dictionary",
      "schema_name": "vort.zlib_header_info",
      "command": "inspect-zlib-header-hex",
      "sample": "78bb08610235cb4027013a2e067d",
      "argv": ["inspect-zlib-header-hex", "78bb08610235cb4027013a2e067d"],
      "detail": "FDICT",
      "format": "zlib",
      "bytes": 14,
      "data_offset": 6,
      "has_dictionary": true,
      "has_optional_fields": false,
      "header_crc": false
    }
  ]
}
```

## `vort.header_inspect_required_workflows`

Consumed by:

```sh
python3 tools/header_inspect_smoke.py zig-out/bin/vort
zig build run-header-inspect-smoke
```

This schema defines the required hex/file workflow coverage matrix for public
header-inspection CLI commands. Keeping the matrix in a small JSON file makes new
inspect commands reviewable without editing the smoke script logic. The docs
checker also cross-checks this matrix against the header-inspect command enums in
`tools/validation_json_schema_manifest.json` so the required coverage config and
schema expectations cannot drift silently.

Example:

```json
{
  "schema": "vort.header_inspect_required_workflows",
  "schema_version": 1,
  "required_workflows": [
    {
      "command": "inspect-zlib-header-hex",
      "workflow": "hex",
      "format": "zlib"
    }
  ]
}
```

## `vort.raw_deflate_header_info`

Produced by:

```sh
zig build run -- inspect-raw-header-hex cb48cdc9c90700 json
```

This schema is the machine-readable form of raw DEFLATE first-block header
inspection. It reports BFINAL, BTYPE, the bit/byte offsets where the
block-specific payload begins, how many header bits were consumed by the
lightweight inspection, dynamic-block HLIT/HDIST/HCLEN, code-length-code
lengths and RLE operation counts, literal/distance code-length zero/non-zero
counts, max-bit summaries, and bit-length histograms when BTYPE is `dynamic`,
and stored-block LEN/NLEN diagnostics when BTYPE is `stored`.

Example:

```json
{
  "schema": "vort.raw_deflate_header_info",
  "schema_version": 1,
  "compressed_bytes": 7,
  "final": true,
  "block_type": "fixed",
  "data_bit_offset": 3,
  "data_byte_offset": 1,
  "header_bits_consumed": 3,
  "header_bytes_consumed": 1,
  "dynamic_hlit": null,
  "dynamic_hdist": null,
  "dynamic_hclen": null,
  "dynamic_code_length_count": null,
  "dynamic_code_length_lengths": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  "dynamic_code_length_repeat_prev": null,
  "dynamic_code_length_repeat_zero_short": null,
  "dynamic_code_length_repeat_zero_long": null,
  "dynamic_literal_nonzero": null,
  "dynamic_literal_zero": null,
  "dynamic_literal_max_bits": null,
  "dynamic_literal_length_histogram": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  "dynamic_distance_nonzero": null,
  "dynamic_distance_zero": null,
  "dynamic_distance_max_bits": null,
  "dynamic_distance_length_histogram": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
  "dynamic_has_eob": null,
  "dynamic_lengths_bit_offset": null,
  "dynamic_lengths_byte_offset": null,
  "stored_len": null,
  "stored_nlen": null,
  "stored_payload_offset": null
}
```

## `vort.wrapped_deflate_header_info`

Produced by:

```sh
zig build run -- inspect-zlib-deflate-header-hex 7801cb48cdc9c90700062c0215 json
zig build run -- inspect-zlib-dict-deflate-header-hex 78f908610235cb4027013a2e067d "hello " json
zig build run -- inspect-zlib-deflate-header-file /tmp/vort.zlib json
zig build run -- inspect-zlib-dict-deflate-header-file /tmp/vort-dict.zlib /tmp/vort.dict json
zig build run -- inspect-gzip-deflate-header-file /tmp/vort.gz json
zig build run -- inspect-gzip-deflate-header-file /tmp/vort-cat.gz json  # first member
zig build run -- inspect-gzip-deflate-header-file /tmp/vort-cat.gz json 1
```

This schema wraps `vort.raw_deflate_header_info` with the zlib/gzip header
context needed to locate the inner DEFLATE payload. It records the wrapper type,
scope, member index, total wrapper bytes, byte offset where the DEFLATE payload
starts, remaining bytes after that offset, and the nested raw header object.
`deflate_span_kind` is currently `header_tail`: `deflate_bytes` is the byte count
after the wrapper header; for zlib inputs that includes the Adler-32 footer, and
for concatenated gzip inputs that includes the selected member footer and later
members. `exact_deflate_bytes` is the wrapper-neutral exact raw DEFLATE payload
length when the inspection can decode enough context to find the payload end;
for zlib FDICT streams inspected without a dictionary it is `null`. For zlib
streams without a preset dictionary requirement, `stream_deflate_bytes` reports
the same exact raw DEFLATE payload length before the 4-byte Adler-32 footer, and
`stream_*adler32*` fields report stored-vs-computed
checksum diagnostics. These zlib stream diagnostics are `null` when the stream
requires a preset dictionary and the header-only command has no dictionary bytes;
use `inspect-zlib-dict-deflate-header-*` to supply the dictionary and emit full
stream diagnostics for FDICT streams. For gzip, `member_deflate_bytes` is the selected member's
exact raw DEFLATE payload length, `member_footer_offset` points at its 8-byte
trailer, and `member_end_offset` is the exclusive end offset
(`member_footer_offset + 8`). `member_output_bytes` is the exact decoded payload
byte count used for the inspected member's ISIZE comparison. Gzip member trailer
diagnostics also include the stored CRC-32/ISIZE values, Vort's decoded
CRC-32/ISIZE values, and boolean match flags. A false match flag is diagnostic:
header inspection still reports the selected member even when the zlib or gzip
footer checksum/size disagrees with the decoded payload. Gzip member-specific
fields are `null` for zlib, and zlib stream-specific fields are `null` for gzip.
The optional `member_index` argument selects the gzip member to inspect and
defaults to `0`; member traversal uses the previous member's decoded raw DEFLATE
byte length plus the gzip trailer.

Example:

```json
{
  "schema": "vort.wrapped_deflate_header_info",
  "schema_version": 1,
  "wrapper": "zlib",
  "scope": "zlib_stream",
  "member_index": 0,
  "member_offset": 0,
  "wrapper_bytes": 13,
  "deflate_offset": 2,
  "deflate_bytes": 11,
  "deflate_span_kind": "header_tail",
  "exact_deflate_bytes": 7,
  "stream_deflate_bytes": 7,
  "stream_output_bytes": 5,
  "stream_footer_offset": 9,
  "stream_end_offset": 13,
  "stream_footer_adler32": 103547413,
  "stream_adler32": 103547413,
  "stream_adler32_matches": true,
  "member_deflate_bytes": null,
  "member_output_bytes": null,
  "member_footer_offset": null,
  "member_end_offset": null,
  "member_footer_crc32": null,
  "member_crc32": null,
  "member_crc32_matches": null,
  "member_footer_isize": null,
  "member_isize": null,
  "member_isize_matches": null,
  "raw_header": {
    "schema": "vort.raw_deflate_header_info",
    "schema_version": 1,
    "compressed_bytes": 11,
    "final": true,
    "block_type": "fixed",
    "data_bit_offset": 3,
    "data_byte_offset": 1,
    "header_bits_consumed": 3,
    "header_bytes_consumed": 1,
    "stored_len": null,
    "stored_nlen": null,
    "stored_payload_offset": null,
    "dynamic_hlit": null,
    "dynamic_hdist": null,
    "dynamic_hclen": null,
    "dynamic_code_length_count": null,
    "dynamic_code_length_lengths": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    "dynamic_code_length_repeat_prev": null,
    "dynamic_code_length_repeat_zero_short": null,
    "dynamic_code_length_repeat_zero_long": null,
    "dynamic_literal_nonzero": null,
    "dynamic_literal_zero": null,
    "dynamic_literal_max_bits": null,
    "dynamic_literal_length_histogram": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    "dynamic_distance_nonzero": null,
    "dynamic_distance_zero": null,
    "dynamic_distance_max_bits": null,
    "dynamic_distance_length_histogram": [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    "dynamic_has_eob": null,
    "dynamic_lengths_bit_offset": null,
    "dynamic_lengths_byte_offset": null
  }
}
```

## `vort.zlib_header_info`

Produced by:

```sh
zig build run -- inspect-zlib-header-hex 7801cb48cdc9c90700062c0215 json
```

This schema is the machine-readable form of zlib wrapper header inspection.
It reports CMF/FLG-derived fields and an optional DICTID without validating the
caller-provided dictionary bytes.

Example:

```json
{
  "schema": "vort.zlib_header_info",
  "schema_version": 1,
  "compressed_bytes": 13,
  "data_offset": 2,
  "cmf": 120,
  "flg": 1,
  "compression_method": 8,
  "window_bits": 15,
  "window_size": 32768,
  "fcheck": 1,
  "uses_dictionary": false,
  "flevel": 0,
  "dictionary_id": null
}
```

## `vort.gzip_header_info`

Produced by:

```sh
zig build run -- inspect-gzip-header-hex 1f8b0800000000000403cb48cdc9c9070086a6103605000000 json
```

This schema is the machine-readable form of gzip wrapper header inspection.
It includes base header fields and optional FEXTRA/FNAME/FCOMMENT/FHCRC
metadata after FHCRC validation when present.

Example:

```json
{
  "schema": "vort.gzip_header_info",
  "schema_version": 1,
  "compressed_bytes": 25,
  "data_offset": 10,
  "flags": 0,
  "text": false,
  "mtime": 0,
  "xfl": 4,
  "os": 3,
  "extra_present": false,
  "extra_len": 0,
  "extra_hex": null,
  "filename": null,
  "comment": null,
  "header_crc": null
}
```

## `vort.validation_json_smoke`

Produced by:

```sh
zig build run-validation-json-dashboard
```

This schema summarizes the validation JSON smoke test that parses the other
validation schemas.

Important fields:

- `schema`: `vort.validation_json_smoke`
- `schema_version`: `1`
- `ok`: whether the smoke passed
- `checked_schemas`: schemas successfully parsed
- `cli_success_ok`, `cli_failure_ok`, `cli_failure_hint`
- `report_rows`, `corrupt_rows`

Example:

```json
{
  "schema": "vort.validation_json_smoke",
  "schema_version": 1,
  "ok": true,
  "checked_schemas": [
    "vort.validation_report",
    "vort.sidecar_verify_report",
    "vort.sidecar_corrupt_smoke_report",
    "vort.br_static_dictionary_required_coverage",
    "vort.dashboard_strict_expected_modes",
    "vort.dashboard_strict_validation_reasons",
    "vort.dashboard_strict_smoke",
    "vort.dashboard_producers",
    "vort.dashboard_producers_negative_smoke",
    "vort.dashboard_producers_required_artifacts",
    "vort.dashboard_producers_required_smoke",
    "vort.fuzz_corpus_report",
    "vort.fuzz_corpus_expected_coverage",
    "vort.fuzz_corpus_coverage_smoke",
    "vort.dashboard_category_expected_artifacts",
    "vort.dashboard_category_negative_smoke",
    "vort.dashboard_config_index",
    "vort.dashboard_config_index_negative_smoke",
    "vort.dashboard_config_index_smoke",
    "vort.dashboard_index",
    "vort.header_inspect_smoke",
    "vort.header_inspect_required_workflows",
    "vort.validation_json_docs_negative_smoke",
    "vort.lz4_native_stream_summary",
    "vort.lz4_native_stream_summary_error",
    "vort.raw_deflate_header_info",
    "vort.wrapped_deflate_header_info",
    "vort.zstd_native_stream_summary",
    "vort.zstd_native_stream_summary_error",
    "vort.zlib_header_info",
    "vort.gzip_header_info"
  ],
  "cli_success_ok": true,
  "cli_failure_ok": false,
  "cli_failure_hint": "payload_corrupt",
  "report_rows": 1,
  "corrupt_rows": 8
}
```

## `vort.dashboard_config_index`

Consumed by:

```sh
zig build run-dashboard-config-index-smoke
python3 tools/dashboard_config_index_smoke.py
```

This schema indexes dashboard-related external configuration files. Each row
records the config path, schema name, documentation section, validation build
step, and consumer script. The config-index smoke verifies that every indexed
file exists, has the expected schema, is represented in this document, has a
manifest schema entry, and points at an existing consumer.

Example:

```json
{
  "schema": "vort.dashboard_config_index",
  "schema_version": 1,
  "config_count": 1,
  "configs": [
    {
      "path": "tools/dashboard_category_expected_artifacts.json",
      "schema_name": "vort.dashboard_category_expected_artifacts",
      "docs_section": "## `vort.dashboard_category_expected_artifacts`",
      "validation_step": "zig build run-dashboard-category-smoke",
      "consumer": "tools/dashboard_category_smoke.py"
    }
  ]
}
```

## `vort.dashboard_config_index_negative_smoke`

Produced by:

```sh
zig build run-dashboard-config-index-negative-smoke
python3 tools/dashboard_config_index_negative_smoke.py --summary zig-out/vort-dashboard-config-index-negative-smoke.json
```

This schema summarizes negative checks for the dashboard config index. The smoke
feeds intentionally drifted index files to `tools/dashboard_config_index_smoke.py`
and verifies that missing config paths, schema mismatches, missing docs sections,
missing build steps, missing consumers, and schemas not covered by
`vort.validation_json_smoke.checked_schemas` fail with the expected diagnostic.

Example:

```json
{
  "schema": "vort.dashboard_config_index_negative_smoke",
  "schema_version": 1,
  "ok": true,
  "case_count": 1,
  "cases": [
    {
      "name": "missing_config_path",
      "expected_failure": true,
      "expected_output": "\"path_exists\": false",
      "actual_output": "... \"path_exists\": false ...",
      "actual_output_bytes": 120,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 1,
      "matched": true
    }
  ]
}
```

## `vort.dashboard_config_index_smoke`

Produced by:

```sh
zig build run-dashboard-config-index-smoke
python3 tools/dashboard_config_index_smoke.py --summary zig-out/vort-dashboard-config-index-smoke.json
```

This schema summarizes the config-index validation. Each row records whether the
file path exists, whether the file schema matches the indexed schema name,
whether the schema exists in the shared manifest, whether the docs section is
present, whether the validation step is present in `build.zig`, whether the
consumer script exists, and whether `vort.validation_json_smoke.checked_schemas`
allows the config schema.

Example:

```json
{
  "schema": "vort.dashboard_config_index_smoke",
  "schema_version": 1,
  "ok": true,
  "config_count": 1,
  "configs": [
    {
      "path": "tools/dashboard_category_expected_artifacts.json",
      "schema_name": "vort.dashboard_category_expected_artifacts",
      "docs_section": "## `vort.dashboard_category_expected_artifacts`",
      "validation_step": "zig build run-dashboard-category-smoke",
      "consumer": "tools/dashboard_category_smoke.py",
      "path_exists": true,
      "schema_matches": true,
      "manifest_schema_present": true,
      "docs_section_present": true,
      "validation_step_present": true,
      "consumer_exists": true,
      "validation_json_smoke_checked": true,
      "matched": true
    }
  ]
}
```

## `vort.br_static_dictionary_candidate_report`

Produced by:

```sh
zig build run-br-static-dictionary-candidate-report
zig build run-br-static-dictionary-candidate-report-smoke
zig build run-br-static-dictionary-candidate-report-upstream80 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-candidate-report-upstream128 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-candidate-report-upstream256 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-candidate-report-upstream512 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-candidate-report-upstream1024 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-candidate-report-upstream2048 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-candidate-report-upstream4096 -- --brotli-common-dir <path>
```

This schema reports additional Brotli static-dictionary tuples that can be
derived from the current source anchors and the minimal transform subset already
understood by Vort. It can also use a local upstream Brotli `common/` checkout
with a bounded `--source-limit` to include more raw dictionary words in the
candidate pool; `run-br-static-dictionary-candidate-report-upstream80` is an
opt-in retained report for a local source-limit 80 slice, with an analogous
`upstream128`, `upstream256`, `upstream512`, `upstream1024`, `upstream2048`, and `upstream4096` steps for
larger local slices. It is a planning artifact for expanding coverage from source
data rather than hand-picking tuple literals. The report includes transform-kind
and copy-length summaries so generated backlog size is visible without scanning
every candidate row.

Example:

```json
{
  "schema": "vort.br_static_dictionary_candidate_report",
  "schema_version": 1,
  "source_mode": "anchors",
  "source_limit": 0,
  "source_entry_count": 64,
  "anchor_raw_word_count": 50,
  "upstream_raw_word_count": 0,
  "raw_word_count": 50,
  "transform_count": 6,
  "candidate_count": 1,
  "kind_rows": [
    {
      "transform_kind": "affix_identity",
      "candidate_count": 1
    }
  ],
  "length_rows": [
    {
      "copy_len": 7,
      "candidate_count": 1
    }
  ],
  "candidates": [
    {
      "transform": 1,
      "copy_len": 7,
      "word_index": 37,
      "raw_word": "history",
      "transformed_word": "history ",
      "transform_kind": "affix_identity"
    }
  ]
}
```

## `vort.br_static_dictionary_candidate_upstream_smoke`

Produced by:

```sh
zig build run-br-static-dictionary-candidate-upstream-smoke
python3 tools/br_static_dictionary_candidate_upstream_smoke.py --summary zig-out/vort-br-static-dictionary-candidate-upstream-smoke.json --json zig-out/vort-br-static-dictionary-candidates-upstream.json
```

This schema summarizes a portable smoke for candidate-report upstream mode. The
smoke creates a tiny temporary Brotli `common/` fixture, asks the candidate
report to merge a bounded set of raw dictionary words from that fixture, and
checks that known transformed candidates appear in the generated report. The
build step also retains the generated upstream candidate JSON/Markdown artifacts
for dashboard review.

Example:

```json
{
  "schema": "vort.br_static_dictionary_candidate_upstream_smoke",
  "schema_version": 1,
  "ok": true,
  "source_mode": "upstream",
  "source_limit": 8,
  "source_entry_count": 83,
  "anchor_raw_word_count": 63,
  "upstream_raw_word_count": 8,
  "raw_word_count": 71,
  "candidate_count": 343,
  "stdout": "br_static_dictionary_candidate_report=ok source_entries=83 raw_words=71 candidates=343"
}
```

## `vort.br_static_dictionary_source_anchors`

Consumed by:

```sh
zig build run-br-static-dictionary-source-audit
python3 tools/br_static_dictionary_source_audit.py --anchors tools/br_static_dictionary_source_anchors.json
```

This schema ties every retained Brotli static-dictionary tuple to the raw RFC
dictionary word it came from and the small transform operation currently
implemented by Vort. The audit script cross-checks these anchors against
`src/br.zig`; when a local upstream Brotli checkout is available it can also
verify the raw words and transformed outputs against `common/dictionary_inc.h`
and `common/transform.c`.

Example:

```json
{
  "schema": "vort.br_static_dictionary_source_anchors",
  "schema_version": 1,
  "entry_count": 1,
  "source": "RFC 7932 Brotli static dictionary data as exposed by upstream common/dictionary_inc.h and common/transform.c",
  "entries": [
    {
      "transform": 9,
      "copy_len": 7,
      "word_index": 37,
      "raw_word": "history",
      "transformed_word": "History",
      "transform_kind": "uppercase_first"
    }
  ]
}
```

## `vort.br_static_dictionary_source_audit`

Produced by:

```sh
zig build run-br-static-dictionary-source-audit
python3 tools/br_static_dictionary_source_audit.py --summary zig-out/vort-br-static-dictionary-source-audit.json
```

This schema summarizes the source-anchor audit for the retained Brotli
static-dictionary subset. It reports whether the Zig decoder table and anchor
fixture agree, whether the generated Zig table matches `src/br.zig`, how many
transforms and lengths are covered, and whether an optional local upstream
Brotli source checkout was used for byte-level verification.

Example:

```json
{
  "schema": "vort.br_static_dictionary_source_audit",
  "schema_version": 1,
  "ok": true,
  "entry_count": 64,
  "anchor_count": 64,
  "transform_count": 6,
  "length_count": 8,
  "operation_counts": {
    "affix_identity": 9,
    "identity": 47,
    "omit_last_1": 3,
    "uppercase_first": 5
  },
  "generated_table_matches_source": true,
  "generated_zig_bytes": 5242,
  "generated_zig_path": "zig-out/vort-br-static-dictionary-generated.zig",
  "source_checked": false,
  "source_dir": ""
}
```

## `vort.br_static_dictionary_source_audit_negative_smoke`

Produced by:

```sh
zig build run-br-static-dictionary-source-audit-negative-smoke
python3 tools/br_static_dictionary_source_audit_negative_smoke.py --summary zig-out/vort-br-static-dictionary-source-audit-negative-smoke.json
```

This schema summarizes negative fixtures for the Brotli static-dictionary
source-anchor audit. Each case mutates the anchor fixture, the parsed Zig source,
or the optional upstream Brotli source path and verifies that the audit fails
with the expected diagnostic instead of accepting drift silently.

Example:

```json
{
  "schema": "vort.br_static_dictionary_source_audit_negative_smoke",
  "schema_version": 1,
  "ok": true,
  "case_count": 1,
  "cases": [
    {
      "name": "generated_order_mismatch",
      "expected_output": "generated Zig table order/content differs",
      "returncode": 1,
      "matched": true
    }
  ]
}
```

## `vort.br_static_dictionary_node_probe`

Produced by:

```sh
zig build run-br-static-dictionary-node-probe
zig build run-br-static-dictionary-node-probe-wide
zig build run-br-static-dictionary-node-probe-full
zig build run-br-static-dictionary-node-probe-upstream
zig build run-br-static-dictionary-node-probe-upstream80 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream128 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream256 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream512 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream1024-0-1024 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream1024-1024-2048 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream1024-2048-3072 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream1024-3072-4096 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream1024-4096-5120 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream1024-5120-6144 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream1024-6144-tail -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream2048-6137-7161 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream2048-7161-8185 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream2048-8185-9209 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream2048-9209-10233 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream2048-10233-11257 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream2048-11257-12281 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream2048-12281-tail -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-12223-13247 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-13247-14271 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-14271-15295 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-15295-16319 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-16319-17343 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-17343-18367 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-18367-19391 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-19391-20415 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-20415-21439 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-21439-22463 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-22463-23487 -- --brotli-common-dir <path>
zig build run-br-static-dictionary-node-probe-upstream4096-23487-tail -- --brotli-common-dir <path>
python3 tools/br_static_dictionary_node_probe.py <vort-cli> --json zig-out/vort-br-static-dictionary-node-probe.json --start-index 0 --limit 48
python3 tools/br_static_dictionary_node_probe.py <vort-cli> --json /tmp/probe.json --start-index 1024 --limit 1024
```

This schema records a bounded Node-backed probe over generated Brotli
static-dictionary candidates. For each candidate payload, Node emits a Brotli
quality-5 frame and Vort attempts to decode that exact frame, so future coverage
work can distinguish candidates already accepted by the current decoder from
Node-generated frames that still require new source tuples or transforms. The
standard build step requires all default probed frames to decode successfully;
the wide step raises the retained probe prefix to 160 candidates, and the full
step probes every generated candidate and now fails if any default full-probe
candidate remains a size winner, making unpromoted high-value candidates visible
in routine validation. The upstream step probes the portable upstream-candidate
fixture generated by
`run-br-static-dictionary-candidate-upstream-smoke`; the upstream80 step probes
a local upstream source-limit 80 slice when a Brotli checkout path is supplied,
and `upstream128` / `upstream256` / `upstream512` repeat the same flow for larger local slices, while the `upstream1024-*` steps probe large source-limit 1024 reports in 1024-row windows (`0-1024`, `1024-2048`, `2048-3072`, `3072-4096`, `4096-5120`, `5120-6144`, and the final `6144-tail`); the `upstream2048-*` steps continue from the first changed candidate index in windows (`6137-7161`, `7161-8185`, `8185-9209`, `9209-10233`, `10233-11257`, `11257-12281`, and `12281-tail`). The `upstream256` and `upstream512` probes also fail on unpromoted size winners once their current source-limit slices are clean. The report also summarizes
probed rows by transform kind and by compressed-size class, and lists the
`smaller` rows separately, and copies the candidate report source metadata so
high-value candidates can be triaged without scanning every candidate row or
inferring which source slice produced the probe.

Example:

```json
{
  "schema": "vort.br_static_dictionary_node_probe",
  "schema_version": 1,
  "ok": true,
  "candidate_count": 296,
  "candidate_source_mode": "anchors",
  "candidate_source_limit": 0,
  "candidate_source_entry_count": 83,
  "candidate_anchor_raw_word_count": 63,
  "candidate_upstream_raw_word_count": 0,
  "candidate_raw_word_count": 63,
  "all_candidates": false,
  "start_index": 0,
  "limit": 1,
  "quality": 5,
  "lgwin": 10,
  "probed_count": 1,
  "node_decode_successes": 1,
  "vort_decode_successes": 1,
  "vort_decode_failures": 0,
  "kind_rows": [
    {
      "transform_kind": "affix_identity",
      "probed_count": 1,
      "node_decode_successes": 1,
      "vort_decode_successes": 1,
      "vort_decode_failures": 0
    }
  ],
  "size_rows": [
    {
      "size_class": "larger",
      "probed_count": 1
    }
  ],
  "size_winner_count": 0,
  "size_winner_rows": [],
  "rows": [
    {
      "index": 0,
      "transform": 1,
      "copy_len": 5,
      "word_index": 35,
      "raw_word": "about",
      "candidate_word": "about ",
      "transform_kind": "affix_identity",
      "quality": 5,
      "lgwin": 10,
      "payload_bytes": 6,
      "br_bytes": 11,
      "size_delta_bytes": 5,
      "size_class": "larger",
      "br_hex": "2114000461626f75742003",
      "node_ok": true,
      "vort_ok": true,
      "classification": "vort_accepts_node_frame",
      "error": ""
    }
  ]
}
```

## `vort.br_static_dictionary_required_coverage`

Consumed by:

```sh
zig build run-br-static-dictionary-report-smoke
python3 tools/br_static_dictionary_report_smoke.py --required tools/br_static_dictionary_required_coverage.json
```

This schema stores the representative Brotli static-dictionary tuples that the
coverage smoke must find in the generated report. Keeping these tuples in data
lets coverage requirements grow without editing the smoke script.

Example:

```json
{
  "schema": "vort.br_static_dictionary_required_coverage",
  "schema_version": 1,
  "entries": [
    {
      "transform": 0,
      "copy_len": 16,
      "word_index": 52,
      "word": "large number of ",
      "reason": "representative identity dictionary tuple",
      "source_case": "node-static-dictionary-large-number-of-q5-lgwin10",
      "category": "phrase"
    }
  ]
}
```

## `vort.br_static_dictionary_report`

Produced by:

```sh
zig build run-br-static-dictionary-report-dashboard
zig build run-br-static-dictionary-report-smoke
```

This schema describes the retained Brotli static-dictionary subset currently
implemented by Vort. Each entry identifies a supported RFC transform index, copy
length, dictionary word index, transformed word byte length, and transformed
word bytes. Dashboard aggregate health cross-checks this JSON against the CSV,
Markdown summary, and negative smoke artifact before static-dictionary coverage
is considered healthy. The report is intentionally a subset manifest rather than
a claim of complete Brotli dictionary support.

Example:

```json
{
  "schema": "vort.br_static_dictionary_report",
  "schema_version": 1,
  "entry_count": 2,
  "transform_count": 2,
  "length_count": 1,
  "category_counts": {
    "identity": 1,
    "transform": 1,
    "phrase": 0
  },
  "matrix_rows": [
    {
      "transform": 0,
      "identity": 1,
      "transform_entries": 0,
      "phrase": 0,
      "total": 1
    },
    {
      "transform": 12,
      "identity": 0,
      "transform_entries": 1,
      "phrase": 0,
      "total": 1
    }
  ],
  "entries": [
    {
      "transform": 0,
      "copy_len": 5,
      "word_index": 43,
      "word_bytes": 5,
      "word": "words"
    },
    {
      "transform": 12,
      "copy_len": 5,
      "word_index": 43,
      "word_bytes": 4,
      "word": "word"
    }
  ]
}
```

## `vort.br_static_dictionary_report_negative_smoke`

Produced by:

```sh
zig build run-br-static-dictionary-report-negative-smoke
python3 tools/br_static_dictionary_report_negative_smoke.py --summary zig-out/vort-br-static-dictionary-report-negative-smoke.json
```

This schema summarizes negative fixtures for the Brotli static-dictionary report
smoke. Each case intentionally corrupts one report invariant and records whether
the validator failed with the expected diagnostic.

Example:

```json
{
  "schema": "vort.br_static_dictionary_report_negative_smoke",
  "schema_version": 1,
  "ok": true,
  "case_count": 1,
  "cases": [
    {
      "name": "invalid_category",
      "expected_output": "category invalid",
      "returncode": 1,
      "matched": true
    }
  ]
}
```

## `vort.dashboard_category_expected_artifacts`

Consumed by:

```sh
zig build run-dashboard-category-smoke
python3 tools/dashboard_category_smoke.py zig-out/vort-dashboard-index.json
```

This schema defines representative dashboard artifacts whose categories should
not regress. Required validation artifacts must be present and carry producer and
smoke-gate metadata; optional benchmark/corpus/native/other examples still
exercise the classifier even when the corresponding expensive dashboard was not
generated in a narrow smoke run. Lightweight corpus/ratio artifacts such as the
level-report CSV/Markdown dashboard can also require presence so dashboard
indexing keeps covering their producer and smoke-gate metadata.

Example:

```json
{
  "schema": "vort.dashboard_category_expected_artifacts",
  "schema_version": 1,
  "expected_artifacts": [
    {
      "name": "vort-rust-deflate-benchmark-summary.md",
      "category": "benchmark",
      "require_present": false,
      "require_producer_step": false,
      "require_smoke_gate": false
    }
  ]
}
```

## `vort.dashboard_category_negative_smoke`

Produced by:

```sh
zig build run-dashboard-category-negative-smoke
python3 tools/dashboard_category_negative_smoke.py --summary zig-out/vort-dashboard-category-negative-smoke.json
```

This schema summarizes negative checks for the dashboard category expectation
matrix. The smoke feeds intentionally drifted category configs or manifest rows
to `tools/dashboard_category_smoke.py` and verifies that classifier mismatches,
missing required artifacts, bad manifest categories, and missing producer/smoke
metadata all fail with the expected diagnostic.

Example:

```json
{
  "schema": "vort.dashboard_category_negative_smoke",
  "schema_version": 1,
  "ok": true,
  "case_count": 1,
  "cases": [
    {
      "name": "classifier_category_mismatch",
      "expected_failure": true,
      "expected_output": "classifier category='benchmark', expected 'validation'",
      "actual_output": "vort-rust-deflate-benchmark-summary.md classifier category='benchmark', expected 'validation'",
      "actual_output_bytes": 92,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 1,
      "matched": true
    }
  ]
}
```

## `vort.validation_json_docs_negative_smoke`

Produced by:

```sh
zig build run-validation-json-docs-negative-smoke
python3 tools/validation_json_docs_negative_smoke.py --summary zig-out/vort-validation-json-docs-negative-smoke.json
```

This schema summarizes negative checks for the validation JSON docs checker. The
smoke creates intentionally drifted copies of dashboard strict mode/reason
configs and malformed summary examples, then verifies that the generic manifest
checker or the cross-config consistency checks reject them with the expected
diagnostic. This protects the external dashboard strict config files from
becoming inert documentation instead of enforced gates.

Example:

```json
{
  "schema": "vort.validation_json_docs_negative_smoke",
  "schema_version": 1,
  "ok": true,
  "case_count": 1,
  "cases": [
    {
      "name": "missing_reason_config",
      "expected_failure": true,
      "expected_error": "differs from dashboard index enum",
      "actual_error": "dashboard strict validation reason config differs from dashboard index enum",
      "matched": true
    }
  ]
}
```

## `vort.dashboard_producers_negative_smoke`

Produced by:

```sh
zig build run-dashboard-producers-negative-smoke
python3 tools/dashboard_producers_negative_smoke.py --summary zig-out/vort-dashboard-producers-negative-smoke.json
```

This schema summarizes negative and control checks for dashboard producer-map
configuration. The smoke creates small throwaway dashboard artifact directories
and verifies that `tools/dashboard_index.py` rejects expected-format mismatches,
missing producer mappings, and missing required smoke gates, while still
accepting explicit `allow_missing.exact` and substring `contains` producer rules.

Example:

```json
{
  "schema": "vort.dashboard_producers_negative_smoke",
  "schema_version": 1,
  "ok": true,
  "case_count": 1,
  "cases": [
    {
      "name": "missing_producer_step",
      "expected_failure": true,
      "expected_output": "dashboard_index_missing_producers=vort-validation-producer-unmapped.json",
      "actual_output": "dashboard_index_missing_producers=vort-validation-producer-unmapped.json",
      "actual_output_bytes": 76,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 1,
      "matched": true
    }
  ]
}
```

## `vort.dashboard_producers_required_artifacts`

Consumed by:

```sh
zig build run-dashboard-producers-required-smoke
python3 tools/dashboard_producers_required_smoke.py
```

This schema defines the expected exact artifact coverage for
`tools/dashboard_producers.json`. Each row records the artifact filename,
producer command, expected file format, smoke gate, and whether the artifact must
appear in `required_smoke_gates`. The docs checker compares this config with the
actual producer map so adding or removing a known dashboard artifact cannot
silently skip producer/smoke metadata.

Example:

```json
{
  "schema": "vort.dashboard_producers_required_artifacts",
  "schema_version": 1,
  "required_artifacts": [
    {
      "name": "vort-validation-json-smoke.json",
      "producer_step": "zig build run-validation-json-dashboard",
      "expected_format": "json",
      "smoke_gate": "zig build run-validation-json-dashboard",
      "required_smoke_gate": true
    }
  ]
}
```

## `vort.fuzz_corpus_expected_coverage`

Consumed by:

```sh
zig build run-fuzz-corpus-coverage-smoke
python3 tools/fuzz_corpus_coverage_smoke.py --coverage tools/fuzz_corpus_expected_coverage.json
```

This schema stores minimum coverage requirements for the retained wrapper fuzz
corpus dashboard. It makes important wrapper/error combinations contractual so a
future corpus edit cannot silently drop malformed-input coverage.

Example:

```json
{
  "schema": "vort.fuzz_corpus_expected_coverage",
  "schema_version": 1,
  "mode_requirements": [
    {
      "mode": "deflate",
      "min_cases": 2,
      "min_accepted": 1,
      "min_rejected": 1,
      "min_exact_error_expectations": 1,
      "min_matched_rows": 2
    }
  ],
  "error_requirements": [
    {
      "mode": "deflate",
      "error": "TrailingData",
      "min_count": 1
    }
  ]
}
```

## `vort.fuzz_corpus_coverage_smoke`

Produced by:

```sh
zig build run-fuzz-corpus-coverage-smoke
python3 tools/fuzz_corpus_coverage_smoke.py --summary zig-out/vort-fuzz-corpus-coverage-smoke.json
```

This schema records the actual mode/error coverage observed in a
`vort.fuzz_corpus_report` compared with `vort.fuzz_corpus_expected_coverage`.
Rows are marked `matched=false` when actual coverage falls below the configured
minimum.

Example:

```json
{
  "schema": "vort.fuzz_corpus_coverage_smoke",
  "schema_version": 1,
  "ok": true,
  "report": "zig-out/vort-deflate-wrapper-fuzz-corpus.json",
  "coverage": "tools/fuzz_corpus_expected_coverage.json",
  "mode_requirement_count": 1,
  "error_requirement_count": 1,
  "mode_requirements": [
    {
      "mode": "deflate",
      "min_cases": 2,
      "actual_cases": 2,
      "min_accepted": 1,
      "actual_accepted": 1,
      "min_rejected": 1,
      "actual_rejected": 1,
      "min_exact_error_expectations": 1,
      "actual_exact_error_expectations": 1,
      "min_matched_rows": 2,
      "actual_matched_rows": 2,
      "matched": true
    }
  ],
  "error_requirements": [
    {
      "mode": "deflate",
      "error": "TrailingData",
      "min_count": 1,
      "actual_count": 1,
      "matched": true
    }
  ]
}
```

## `vort.fuzz_corpus_report`

Produced by:

```sh
zig build run-deflate-wrapper-fuzz-corpus-dashboard
```

This schema summarizes the hex-sample fuzz corpus harness when it is run in
artifact mode. The fixed dashboard step currently retains the raw/zlib/gzip
wrapper corpus so exact malformed-input error expectations are visible in the
main dashboard index. Dashboard aggregate health also cross-checks retained
Markdown summary/sample rows against the JSON report, and the native corpus
health additionally verifies its coverage-smoke matched rows.

Important fields:

- `schema`: `vort.fuzz_corpus_report`
- `schema_version`: `1`
- `ok`: whether every recorded row matched its expected outcome/error
- `mode`: single mode name or `mixed` when the corpus switches modes
- `cases`, `accepted`, `rejected`
- `exact_error_expectations`: rows with a non-empty `expected_error`
- `matched_rows`: rows whose outcome and exact error matched expectations
- `mode_counts`: per-format aggregate cases, accept/reject counts, exact-error expectations, and matched rows
- `error_counts`: per-format aggregate actual error-name counts for rejected samples
- `items`: per-sample rows with mode, input size, expected outcome/error,
  actual outcome/error, and `matched`

Example:

```json
{
  "schema": "vort.fuzz_corpus_report",
  "schema_version": 1,
  "ok": true,
  "mode": "mixed",
  "cases": 2,
  "accepted": 1,
  "rejected": 1,
  "exact_error_expectations": 1,
  "matched_rows": 2,
  "mode_count_rows": 1,
  "error_count_rows": 1,
  "mode_counts": [
    {
      "mode": "deflate",
      "cases": 2,
      "accepted": 1,
      "rejected": 1,
      "exact_error_expectations": 1,
      "matched_rows": 2
    }
  ],
  "error_counts": [
    {
      "mode": "deflate",
      "error": "TrailingData",
      "count": 1
    }
  ],
  "items": [
    {
      "index": 0,
      "mode": "deflate",
      "input_bytes": 3,
      "expected": "accept",
      "expected_error": "",
      "outcome": "accepted",
      "actual_error": "",
      "matched": true
    },
    {
      "index": 1,
      "mode": "deflate",
      "input_bytes": 4,
      "expected": "reject",
      "expected_error": "TrailingData",
      "outcome": "rejected",
      "actual_error": "TrailingData",
      "matched": true
    }
  ]
}
```

## `vort.deflate_decode_stage_report`

Produced by:

```sh
zig build run-deflate-decode-stage-report-dashboard
```

This schema summarizes the decode-stage dashboard as machine-readable JSON. It
keeps the throughput rows and the representative malformed/truncated/checksum
error-path smoke rows under the same schema checker used by the dashboard index.
`ok=true` requires at least one timing row, at least one error-path row, and all
error-path rows to match their expected error names.

Example:

```json
{
  "schema": "vort.deflate_decode_stage_report",
  "schema_version": 1,
  "ok": true,
  "rows": 1,
  "error_rows": 1,
  "matched_error_rows": 1,
  "unmatched_error_rows": 0,
  "items": [
    {
      "case": "tiny",
      "input_bytes": 28,
      "zlib_bytes": 36,
      "gzip_bytes": 48,
      "raw_bytes": 30,
      "raw_block_type": "fixed",
      "raw_header_bits": 3,
      "raw_header_bytes": 1,
      "dynamic_hlit": 0,
      "dynamic_hdist": 0,
      "dynamic_hclen": 0,
      "dynamic_literal_nonzero": 0,
      "dynamic_literal_zero": 0,
      "dynamic_literal_max_bits": 0,
      "dynamic_distance_nonzero": 0,
      "dynamic_distance_zero": 0,
      "dynamic_distance_max_bits": 0,
      "iterations": 10000,
      "repeat": 1,
      "raw_mib_s": 1.0,
      "raw_exact_mib_s": 1.0,
      "raw_into_mib_s": 1.0,
      "zlib_mib_s": 1.0,
      "zlib_exact_mib_s": 1.0,
      "zlib_into_mib_s": 1.0,
      "zlib_into_no_adler_mib_s": 1.0,
      "zlib_into_no_adler_over_strict": 1.0,
      "gzip_mib_s": 1.0,
      "gzip_no_crc_mib_s": 1.0,
      "gzip_no_crc_over_strict": 1.0,
      "gzip_exact_mib_s": 1.0,
      "gzip_exact_no_crc_mib_s": 1.0,
      "gzip_exact_no_crc_over_strict": 1.0,
      "gzip_into_mib_s": 1.0,
      "gzip_into_no_crc_mib_s": 1.0,
      "gzip_into_no_crc_over_strict": 1.0,
      "gzip_into_no_isize_mib_s": 1.0,
      "gzip_into_no_isize_over_strict": 1.0,
      "gzip_into_relaxed_mib_s": 1.0,
      "gzip_into_relaxed_over_strict": 1.0,
      "adler32_mib_s": 1.0,
      "zlib_adler_time_ratio": 1.0,
      "crc32_mib_s": 1.0,
      "gzip_crc_time_ratio": 1.0,
      "raw_stored_mib_s": 0.0,
      "raw_stored_exact_mib_s": 0.0,
      "raw_stored_into_mib_s": 0.0,
      "zlib_stored_mib_s": 0.0,
      "zlib_stored_exact_mib_s": 0.0,
      "zlib_stored_into_mib_s": 0.0,
      "gzip_stored_mib_s": 0.0,
      "gzip_stored_exact_mib_s": 0.0,
      "gzip_stored_into_mib_s": 0.0,
      "zlib_wrapper_time_ratio": 1.0,
      "zlib_wrapper_exact_time_ratio": 1.0,
      "zlib_wrapper_into_time_ratio": 1.0,
      "gzip_wrapper_time_ratio": 1.0,
      "gzip_wrapper_exact_time_ratio": 1.0,
      "gzip_wrapper_into_time_ratio": 1.0,
      "raw_alloc_exact_time_ratio": 1.0,
      "raw_alloc_into_time_ratio": 1.0,
      "zlib_alloc_exact_time_ratio": 1.0,
      "zlib_alloc_into_time_ratio": 1.0,
      "gzip_alloc_exact_time_ratio": 1.0,
      "gzip_alloc_into_time_ratio": 1.0,
      "raw_stored_alloc_time_ratio": 0.0,
      "zlib_stored_alloc_time_ratio": 0.0,
      "gzip_stored_alloc_time_ratio": 0.0,
      "raw_stored_alloc_exact_time_ratio": 0.0,
      "zlib_stored_alloc_exact_time_ratio": 0.0,
      "gzip_stored_alloc_exact_time_ratio": 0.0,
      "mix": 123
    }
  ],
  "error_items": [
    {
      "case": "zlib-bad-adler",
      "wrapper": "zlib",
      "input_bytes": 11,
      "expected_error": "ChecksumMismatch",
      "actual_error": "ChecksumMismatch",
      "matched": true
    }
  ]
}
```

## `vort.dashboard_producers_required_smoke`

Produced by:

```sh
zig build run-dashboard-producers-required-smoke
python3 tools/dashboard_producers_required_smoke.py --summary zig-out/vort-dashboard-producers-required-smoke.json
```

This schema summarizes the required-artifact comparison between
`tools/dashboard_producers_required_artifacts.json` and
`tools/dashboard_producers.json`. It records actual versus configured producer
step, expected format, smoke gate, and required-smoke-gate membership for every
required artifact.

Example:

```json
{
  "schema": "vort.dashboard_producers_required_smoke",
  "schema_version": 1,
  "ok": true,
  "artifact_count": 1,
  "required_smoke_gate_count": 1,
  "cases": [
    {
      "name": "vort-validation-json-smoke.json",
      "producer_step": "zig build run-validation-json-dashboard",
      "configured_producer_step": "zig build run-validation-json-dashboard",
      "expected_format": "json",
      "configured_expected_format": "json",
      "smoke_gate": "zig build run-validation-json-dashboard",
      "configured_smoke_gate": "zig build run-validation-json-dashboard",
      "required_smoke_gate": true,
      "configured_required_smoke_gate": true,
      "matched": true
    }
  ]
}
```

## `vort.python_zlib_diff_smoke`

Produced by:

```sh
zig build run-python-zlib-diff-dashboard
python3 tools/python_zlib_diff.py zig-out/bin/vort --summary zig-out/vort-python-zlib-diff-smoke.json
```

This schema summarizes the black-box Python `zlib` differential smoke. It keeps
raw/zlib/gzip decode vectors, dynamic/adaptive encode vectors, preset-dictionary
decode/encode vectors, file-command vectors, and expected-failure checks visible
to dashboard health gates without parsing console text. `large_file_payloads`
counts corpus entries routed through file-based CLI commands so the harness does
not depend on platform-specific per-argument limits. `file_hex_encode_cases`
counts raw/zlib/gzip file-to-hex encoder outputs decoded by Python so the
dashboard can distinguish file-transport coverage from command-specific
file-hex encoder coverage. Schema version `3` makes both coverage counts
required for healthy reports.

Example:

```json
{
  "schema": "vort.python_zlib_diff_smoke",
  "schema_version": 3,
  "ok": true,
  "payloads": 11,
  "large_file_payloads": 1,
  "file_hex_encode_cases": 3,
  "match_heavy_payloads": 3,
  "dynamic_payloads": 3,
  "dictionary_cases": 3,
  "zlib_dict_encode_cases": 6,
  "raw_dict_encode_cases": 5,
  "malformed_wrapper_cases": 8,
  "malformed_deflate_cases": 10,
  "cli_successes": 100,
  "expected_failures": 20
}
```

## `vort.native_codec_probes`

Produced by:

```sh
zig build run-native-codec-probes-dashboard
python3 tools/native_codec_probes_dashboard.py --json zig-out/vort-native-codec-probes.json --markdown zig-out/vort-native-codec-probes.md zig-out/bin/lz4-native-probe zig-out/bin/lz4-native-dictionary-probe zig-out/bin/zstd-native-frame-probe zig-out/bin/zstd-native-dictionary-probe
```

This schema summarizes the library-level native LZ4/Zstd probes, retains the
case counts from the frame and dictionary probe executables, and the dashboard
aggregate health cross-checks the retained Markdown tables against the JSON
coverage/capability/probe rows. It adds a
`coverage` list keyed by codec (`lz4`/`zstd`) and surface (`frame`/`dictionary`),
and adds a `capabilities` list for cross-cutting library behaviors such as
lib-generated frames, incremental drains, chunked split input, reusable chunked
decoder drains, dictionaries, dictionary training, malformed input, checksums,
Huffman literals, sequence tables, and block APIs. Each probe row also records
`timed_out` and `timeout_seconds`; the dashboard treats a timeout as a failed
probe and still writes JSON/Markdown artifacts so CI failures show which probe
exceeded its budget.

Example:

```json
{
  "schema": "vort.native_codec_probes",
  "schema_version": 1,
  "ok": true,
  "capability_count": 16,
  "coverage_count": 4,
  "probe_count": 4,
  "total_cases": 386,
  "capabilities": [
    {
      "capability": "lib-generated",
      "cases": 187,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "native-generated",
      "cases": 350,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "incremental",
      "cases": 204,
      "ok": true,
      "ok_probe_count": 4,
      "present": true,
      "probe_count": 4
    },
    {
      "capability": "chunked",
      "cases": 200,
      "ok": true,
      "ok_probe_count": 4,
      "present": true,
      "probe_count": 4
    },
    {
      "capability": "reusable-chunked",
      "cases": 197,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "fse-repeat",
      "cases": 8,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "dictionary",
      "cases": 149,
      "ok": true,
      "ok_probe_count": 3,
      "present": true,
      "probe_count": 3
    },
    {
      "capability": "dictionary-training",
      "cases": 2,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "dictionary-set",
      "cases": 121,
      "ok": true,
      "ok_probe_count": 3,
      "present": true,
      "probe_count": 3
    },
    {
      "capability": "skippable",
      "cases": 350,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "malformed",
      "cases": 352,
      "ok": true,
      "ok_probe_count": 3,
      "present": true,
      "probe_count": 3
    },
    {
      "capability": "checksum",
      "cases": 357,
      "ok": true,
      "ok_probe_count": 4,
      "present": true,
      "probe_count": 4
    },
    {
      "capability": "bounded-limits",
      "cases": 354,
      "ok": true,
      "ok_probe_count": 4,
      "present": true,
      "probe_count": 4
    },
    {
      "capability": "huffman",
      "cases": 237,
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1
    },
    {
      "capability": "sequence-tables",
      "cases": 244,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "block",
      "cases": 113,
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1
    }
  ],
  "coverage": [
    {
      "cases": 113,
      "codec": "lz4",
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1,
      "surface": "frame"
    },
    {
      "cases": 11,
      "codec": "lz4",
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1,
      "surface": "dictionary"
    },
    {
      "cases": 237,
      "codec": "zstd",
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1,
      "surface": "frame"
    },
    {
      "cases": 25,
      "codec": "zstd",
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1,
      "surface": "dictionary"
    }
  ],
  "probes": [
    {
      "label": "lz4-native-probe",
      "executable": "zig-out/bin/lz4-native-probe",
      "ok": true,
      "returncode": 0,
      "timed_out": false,
      "timeout_seconds": 120.0,
      "cases": 113,
      "marker": "lz4_native_probe",
      "output": "lz4_native_probe_ok cases=113\nlz4_native_probe_coverage capability=block cases=113\nlz4_native_probe_coverage capability=bounded-limits cases=113\nlz4_native_probe_coverage capability=checksum cases=113\nlz4_native_probe_coverage capability=chunked cases=63\nlz4_native_probe_coverage capability=reusable-chunked cases=63\nlz4_native_probe_coverage capability=dictionary cases=113\nlz4_native_probe_coverage capability=dictionary-set cases=113\nlz4_native_probe_coverage capability=incremental cases=63\nlz4_native_probe_coverage capability=lib-generated cases=63\nlz4_native_probe_coverage capability=malformed cases=113\nlz4_native_probe_coverage capability=native-generated cases=113\nlz4_native_probe_coverage capability=skippable cases=113\n",
      "reported_capabilities": [
        "block",
        "bounded-limits",
        "checksum",
        "chunked",
        "dictionary",
        "dictionary-set",
        "incremental",
        "lib-generated",
        "malformed",
        "native-generated",
        "reusable-chunked",
        "skippable"
      ],
      "reported_capability_cases": {
        "block": 113,
        "bounded-limits": 113,
        "checksum": 113,
        "chunked": 63,
        "dictionary": 113,
        "dictionary-set": 113,
        "incremental": 63,
        "lib-generated": 63,
        "malformed": 113,
        "native-generated": 113,
        "reusable-chunked": 63,
        "skippable": 113
      },
      "reported_capability_count": 12
    },
    {
      "label": "lz4-native-dictionary-probe",
      "executable": "zig-out/bin/lz4-native-dictionary-probe",
      "ok": true,
      "returncode": 0,
      "timed_out": false,
      "timeout_seconds": 120.0,
      "cases": 11,
      "marker": "lz4_native_dictionary_probe",
      "output": "lz4_native_dictionary_probe_ok cases=11\nlz4_native_dictionary_probe_coverage capability=bounded-limits cases=1\nlz4_native_dictionary_probe_coverage capability=checksum cases=3\nlz4_native_dictionary_probe_coverage capability=chunked cases=1\nlz4_native_dictionary_probe_coverage capability=dictionary cases=11\nlz4_native_dictionary_probe_coverage capability=dictionary-training cases=1\nlz4_native_dictionary_probe_coverage capability=dictionary-set cases=4\nlz4_native_dictionary_probe_coverage capability=incremental cases=3\n",
      "reported_capabilities": [
        "bounded-limits",
        "checksum",
        "chunked",
        "dictionary",
        "dictionary-set",
        "dictionary-training",
        "incremental"
      ],
      "reported_capability_cases": {
        "bounded-limits": 1,
        "checksum": 3,
        "chunked": 1,
        "dictionary": 11,
        "dictionary-set": 4,
        "dictionary-training": 1,
        "incremental": 3
      },
      "reported_capability_count": 7
    },
    {
      "label": "zstd-native-frame-probe",
      "executable": "zig-out/bin/zstd-native-frame-probe",
      "ok": true,
      "returncode": 0,
      "timed_out": false,
      "timeout_seconds": 120.0,
      "cases": 237,
      "marker": "zstd_native_frame_probe",
      "output": "zstd_native_frame_probe_ok cases=237\nzstd_native_frame_probe_coverage capability=bounded-limits cases=237\nzstd_native_frame_probe_coverage capability=checksum cases=237\nzstd_native_frame_probe_coverage capability=chunked cases=134\nzstd_native_frame_probe_coverage capability=reusable-chunked cases=134\nzstd_native_frame_probe_coverage capability=fse-repeat cases=5\nzstd_native_frame_probe_coverage capability=huffman cases=237\nzstd_native_frame_probe_coverage capability=incremental cases=134\nzstd_native_frame_probe_coverage capability=lib-generated cases=124\nzstd_native_frame_probe_coverage capability=malformed cases=237\nzstd_native_frame_probe_coverage capability=native-generated cases=237\nzstd_native_frame_probe_coverage capability=sequence-tables cases=237\nzstd_native_frame_probe_coverage capability=skippable cases=237\n",
      "reported_capabilities": [
        "bounded-limits",
        "checksum",
        "chunked",
        "fse-repeat",
        "huffman",
        "incremental",
        "lib-generated",
        "malformed",
        "native-generated",
        "reusable-chunked",
        "sequence-tables",
        "skippable"
      ],
      "reported_capability_cases": {
        "bounded-limits": 237,
        "checksum": 237,
        "chunked": 134,
        "fse-repeat": 5,
        "huffman": 237,
        "incremental": 134,
        "lib-generated": 124,
        "malformed": 237,
        "native-generated": 237,
        "reusable-chunked": 134,
        "sequence-tables": 237,
        "skippable": 237
      },
      "reported_capability_count": 12
    },
    {
      "label": "zstd-native-dictionary-probe",
      "executable": "zig-out/bin/zstd-native-dictionary-probe",
      "ok": true,
      "returncode": 0,
      "timed_out": false,
      "timeout_seconds": 120.0,
      "cases": 25,
      "marker": "zstd_native_dictionary_probe",
      "output": "zstd_native_dictionary_probe_ok cases=25\nzstd_native_dictionary_probe_coverage capability=bounded-limits cases=3\nzstd_native_dictionary_probe_coverage capability=checksum cases=4\nzstd_native_dictionary_probe_coverage capability=chunked cases=2\nzstd_native_dictionary_probe_coverage capability=dictionary cases=25\nzstd_native_dictionary_probe_coverage capability=dictionary-training cases=1\nzstd_native_dictionary_probe_coverage capability=dictionary-set cases=4\nzstd_native_dictionary_probe_coverage capability=fse-repeat cases=3\nzstd_native_dictionary_probe_coverage capability=incremental cases=4\nzstd_native_dictionary_probe_coverage capability=malformed cases=2\nzstd_native_dictionary_probe_coverage capability=sequence-tables cases=7\n",
      "reported_capabilities": [
        "bounded-limits",
        "checksum",
        "chunked",
        "dictionary",
        "dictionary-set",
        "dictionary-training",
        "fse-repeat",
        "incremental",
        "malformed",
        "sequence-tables"
      ],
      "reported_capability_cases": {
        "bounded-limits": 3,
        "checksum": 4,
        "chunked": 2,
        "dictionary": 25,
        "dictionary-set": 4,
        "dictionary-training": 1,
        "fse-repeat": 3,
        "incremental": 4,
        "malformed": 2,
        "sequence-tables": 7
      },
      "reported_capability_count": 10
    }
  ]
}
```

## `vort.native_summary_error_dashboard`

Produced by:

```sh
zig build run-native-summary-error-dashboard
```

This retained artifact records representative structured error JSON emitted by
the LZ4 and Zstd native summary CLIs. It aggregates error and phase counts plus
offset ranges so dashboards can track whether malformed-stream failures are
covered without scraping process error traces.

Example:

```json
{
  "schema": "vort.native_summary_error_dashboard",
  "schema_version": 1,
  "ok": true,
  "case_count": 1,
  "lz4_case_count": 1,
  "zstd_case_count": 0,
  "error_counts": {
    "ChecksumMismatch": 1,
    "CorruptFrame": 1
  },
  "phase_counts": {
    "magic": 1
  },
  "lz4_error_counts": {
    "CorruptFrame": 1
  },
  "zstd_error_counts": {},
  "lz4_phase_counts": {
    "magic": 1
  },
  "zstd_phase_counts": {},
  "required_codec_phases": {
    "lz4": ["magic", "frame_header", "skippable_payload", "frame_body", "frame_checksum", "frame"],
    "zstd": ["magic", "frame_header", "skippable_payload", "frame_body", "frame_checksum", "frame"]
  },
  "offset_min": 0,
  "offset_max": 0,
  "lz4_offset_min": 0,
  "lz4_offset_max": 0,
  "zstd_offset_min": 0,
  "zstd_offset_max": 0,
  "phase_offset_ranges": {
    "magic": {
      "min": 0,
      "max": 0
    }
  },
  "cases": [
    {
      "name": "lz4_bad_magic",
      "codec": "lz4",
      "schema": "vort.lz4_native_stream_summary_error",
      "schema_version": 1,
      "ok": false,
      "compressed_bytes": 7,
      "error": "CorruptFrame",
      "phase": "magic",
      "offset": 0
    }
  ]
}
```

## `vort.native_summary_error_negative_smoke`

Produced by:

```sh
zig build run-native-summary-error-negative-smoke
```

This retained smoke proves that native summary error dashboard aggregates are
not accepted when `case_count`, `error_counts`, `phase_counts`,
`phase_offset_ranges`, per-codec offset ranges, per-codec error/phase counts,
per-case schema/ok invariants drift away from the `cases` payload, case names
are duplicated, or a required codec/phase combination is missing.

Example:

```json
{
  "schema": "vort.native_summary_error_negative_smoke",
  "schema_version": 1,
  "ok": true,
  "case_count": 1,
  "cases": [
    {
      "name": "bad_error_counts",
      "expected_failure": true,
      "expected_error": "error_counts mismatch",
      "actual_error": "error_counts mismatch: expected {'CorruptFrame': 1}, got {'CorruptFrame': 2}",
      "matched": true
    }
  ]
}
```

## `vort.lz4_native_stream_summary`

Produced by:

```sh
zig build run -- summary-lz4-native-file /tmp/vort-readme.lz4 json
```

This schema is the machine-readable form of the LZ4 native stream summary CLI.
It reports data-frame, skippable-frame, checksum-frame, block-checksum-frame,
Dictionary_ID-frame, content-size-frame, declared content-byte, block-type,
compressed-payload, and skippable-payload counts without decoding the stream
payload. The retained dashboard fixture includes a hand-built Dictionary_ID
raw-block frame with a block checksum so dashboard health checks keep optional
LZ4 frame metadata covered even before the public CLI exposes a dictionary-aware
LZ4 encoder command.

Example:

```json
{
  "schema": "vort.lz4_native_stream_summary",
  "schema_version": 1,
  "compressed_bytes": 64,
  "frame_count": 2,
  "skippable_frame_count": 1,
  "content_size_frame_count": 2,
  "checksum_frame_count": 2,
  "block_checksum_frame_count": 0,
  "dictionary_id_frame_count": 0,
  "declared_content_bytes": 6,
  "block_count": 2,
  "compressed_block_count": 0,
  "raw_block_count": 2,
  "payload_bytes": 6,
  "skippable_payload_bytes": 16
}
```

## `vort.lz4_native_stream_summary_error`

Produced by:

```sh
zig build run -- summary-lz4-native-file /tmp/bad.lz4 json
```

This schema is emitted to stdout with a non-zero exit status when the LZ4 native
stream summary CLI is asked for JSON output and encounters malformed or
truncated input. It lets black-box probes and future dashboards consume the
summary failure as structured data rather than scraping Zig error traces. The
`phase` and `offset` fields provide a coarse parser location for triage; `phase`
is one of `magic`, `frame_header`, `frame_body`, `frame_checksum`,
`skippable_header`, `skippable_payload`, `stream`, or `frame`.

Example:

```json
{
  "schema": "vort.lz4_native_stream_summary_error",
  "schema_version": 1,
  "ok": false,
  "compressed_bytes": 7,
  "error": "CorruptFrame",
  "phase": "magic",
  "offset": 0
}
```

## `vort.zstd_native_stream_summary`

Produced by:

```sh
zig build run-zstd-native-summary-dashboard
zig build run -- summary-zstd-native-file /tmp/vort-readme.zst json
```

This schema is the machine-readable form of the Zstd native stream summary CLI.
It reports data-frame, skippable-frame, checksum-frame, Dictionary_ID-frame,
content-size-frame, declared content-byte, block-type, compressed-payload, and
skippable-payload counts without decoding the stream payload.

Example:

```json
{
  "schema": "vort.zstd_native_stream_summary",
  "schema_version": 1,
  "compressed_bytes": 64,
  "frame_count": 3,
  "skippable_frame_count": 1,
  "checksum_frame_count": 1,
  "dictionary_id_frame_count": 1,
  "content_size_frame_count": 3,
  "declared_content_bytes": 9,
  "block_count": 3,
  "compressed_block_count": 0,
  "rle_block_count": 0,
  "raw_block_count": 3,
  "payload_bytes": 9,
  "skippable_payload_bytes": 16
}
```

## `vort.zstd_native_stream_summary_error`

Produced by:

```sh
zig build run -- summary-zstd-native-file /tmp/bad.zst json
```

This schema is emitted to stdout with a non-zero exit status when the Zstd native
stream summary CLI is asked for JSON output and encounters malformed or
truncated input. It mirrors the LZ4 summary error schema so native-summary
probes can validate both success and failure paths without relying on stderr
formatting. The `phase` and `offset` fields provide a coarse parser location
for triage; `phase` is one of `magic`, `frame_header`, `frame_body`,
`frame_checksum`, `skippable_header`, `skippable_payload`, `stream`, or
`frame`.

Example:

```json
{
  "schema": "vort.zstd_native_stream_summary_error",
  "schema_version": 1,
  "ok": false,
  "compressed_bytes": 7,
  "error": "InvalidMagic",
  "phase": "magic",
  "offset": 0
}
```

## `vort.dashboard_index`

Produced by:

```sh
zig build run-dashboard-index
zig build run-dashboard-strict-smoke
python3 tools/dashboard_index.py --strict-header-inspect --strict-validation-health
```

This schema indexes files in `zig-out`. With `--strict-header-inspect`, index
generation fails when the header inspect artifact is absent, reports `ok=false`,
or has missing required workflows. With `--strict-validation-health`, generation
fails whenever the aggregate `validation_healthy` field is false and reports the
`validation_unhealthy_reasons` list with specific missing/failed artifact or coverage reasons.
The generated Markdown index also includes `Dashboard artifact inventory`, `Validation unhealthy reasons`,
`Producer and smoke-gate coverage`, `Dashboard strict mode coverage`, `Dashboard
configuration coverage`, `Validation JSON schema coverage`, `Header
inspect coverage`, `Sidecar corrupt smoke coverage`, `Huffman length oracle
coverage`, `Native allocation coverage`, `Python zlib differential coverage`,
`Decode-stage smoke coverage`, `Fuzz corpus coverage`, `Native stream summary
coverage`, `Deflate extra-bit benchmark coverage`, `Dictionary decode benchmark coverage`,
`PNG scanline benchmark coverage`, `Chunked zlib benchmark coverage`,
`PNG streaming zlib benchmark coverage`, `Deflate dynamic decode profile coverage`,
`Native library benchmark coverage`, `Native tier corpus discovery`,
`Native codec probe coverage`, `Native codec
probe executables`, `Native summary error codec coverage`, and `Native summary error phase offsets` tables
so artifact inventory, aggregate validation health, producer/smoke-gate coverage, dashboard strict
gate coverage, dashboard configuration guardrails, validation schema smoke coverage, header-format coverage, corrupt-sidecar rejection coverage,
sidecar corrupt Markdown/JSON drift checks, Huffman optimality, zstd comparison gate coverage, deflate extra-bit benchmark coverage, dictionary decode benchmark coverage, PNG scanline benchmark coverage, chunked zlib benchmark coverage, PNG streaming zlib benchmark coverage, deflate dynamic decode profile coverage, native library benchmark coverage, native fuzz corpus coverage, static dictionary coverage, PNG scratch coverage, zlib relaxed compatibility coverage, native allocation coverage, zlib differential coverage,
decode-stage error matching, fuzz corpus matching, native stream metadata
coverage, native tier corpus discovery, codec probe status, LZ4/Zstd
structured-error counts, phase counts, required phases, missing phases, and phase
offset ranges are visible during dashboard review without opening the retained
JSON artifacts.
Current unhealthy reason values are:

- `missing_producer_steps`
- `missing_required_smoke_gates`
- `missing_header_inspect_artifact`
- `header_inspect_failed`
- `missing_header_workflows`
- `header_inspect_undercovered`
- `missing_dashboard_strict_artifact`
- `dashboard_strict_failed`
- `missing_dashboard_strict_modes`
- `missing_dashboard_configuration_artifact`
- `dashboard_configuration_failed`
- `missing_validation_json_smoke_artifact`
- `validation_json_failed`
- `missing_validation_json_docs_negative_artifact`
- `validation_json_docs_negative_failed`
- `missing_sidecar_corrupt_artifact`
- `sidecar_corrupt_failed`
- `missing_huffman_length_artifact`
- `huffman_length_failed`
- `missing_checksum_bench_artifact`
- `checksum_bench_failed`
- `missing_chunk_cursor_bench_artifact`
- `chunk_cursor_bench_failed`
- `missing_deflate_match_copy_bench_artifact`
- `deflate_match_copy_bench_failed`
- `missing_deflate_huffman_build_bench_artifact`
- `deflate_huffman_build_bench_failed`
- `missing_deflate_huffman_lookup_bench_artifact`
- `deflate_huffman_lookup_bench_failed`
- `missing_deflate_chunked_huffman_bench_artifact`
- `deflate_chunked_huffman_bench_failed`
- `missing_deflate_extra_bits_bench_artifact`
- `deflate_extra_bits_bench_failed`
- `missing_dictionary_decode_bench_artifact`
- `dictionary_decode_bench_failed`
- `missing_png_scanline_bench_artifact`
- `png_scanline_bench_failed`
- `missing_chunked_zlib_bench_artifact`
- `chunked_zlib_bench_failed`
- `missing_png_streaming_zlib_bench_artifact`
- `png_streaming_zlib_bench_failed`
- `missing_deflate_dynamic_decode_profile_artifact`
- `deflate_dynamic_decode_profile_failed`
- `missing_fuzz_corpus_artifact`
- `fuzz_corpus_failed`
- `missing_fuzz_coverage_artifact`
- `fuzz_coverage_failed`
- `missing_native_fuzz_corpus_artifact`
- `native_fuzz_corpus_failed`
- `missing_native_fuzz_coverage_artifact`
- `native_fuzz_coverage_failed`
- `missing_png_scratch_artifact`
- `png_scratch_failed`
- `missing_zlib_relaxed_artifact`
- `zlib_relaxed_failed`
- `missing_snappy_report_artifact`
- `snappy_report_failed`
- `missing_native_allocation_artifact`
- `native_allocation_failed`
- `missing_native_library_bench_artifact`
- `native_library_bench_failed`
- `missing_decode_stage_artifact`
- `decode_stage_failed`
- `missing_python_zlib_diff_artifact`
- `python_zlib_diff_failed`
- `missing_native_codec_probes_artifact`
- `native_codec_probes_failed`
- `missing_zstd_compare_artifact`
- `zstd_compare_failed`
- `missing_br_static_dictionary_artifact`
- `br_static_dictionary_failed`
- `missing_native_summary_error_dashboard_artifact`
- `native_summary_error_dashboard_undercovered`
- `missing_native_summary_error_negative_artifact`
- `native_summary_error_negative_failed`
- `missing_lz4_native_summary_artifact`
- `lz4_native_summary_undercovered`
- `missing_zstd_native_summary_artifact`
- `zstd_native_summary_undercovered`
- `missing_native_tier_range_artifact`
- `native_tier_range_failed`
- `missing_native_tier_corpus_discovery_artifact`
- `native_tier_corpus_discovery_failed`

Top-level fields:

- `schema`: `vort.dashboard_index`
- `schema_version`: `1`
- `artifact_count`
- `producer_step_covered`
- `producer_step_missing`
- `producer_healthy`
- `producer_step_allowed_missing`
- `smoke_gate_covered`
- `smoke_gate_missing`
- `smoke_gate_healthy`
- `smoke_gate_required_missing`
- `validation_healthy`
- `validation_unhealthy_reasons`
- `sidecar_corrupt_*` fields summarize corrupt-payload smoke JSON coverage and
  now require the retained Markdown table to match every JSON `items` row
  (`case`, metadata/full booleans, error name, stream bytes, and sidecar bytes)
  before aggregate validation health can pass.
- `native_tier_range_*` fields summarize direct-API seekability tier range benchmark summaries,
  including the gate JSON summaries, required CSV row/shape/throughput
  coverage fields (`native_tier_range_csv_*`), and summary-vs-CSV drift
  counters for rows, fixtures, tiers, CSV paths, per-tier stream/index totals,
  and per-tier minimum throughput floors.
- `native_tier_corpus_discovery_*` fields summarize standard-corpus discovery
  inputs for the native tier range benchmark, including drift counters that
  cross-check selected cases and byte sizes against the standard-corpus summary
  and CSV companion, and now participate in aggregate `validation_healthy`.
- `header_inspect_present`, `header_inspect_ok`, `header_inspect_healthy`,
  `header_inspect_markdown_present`, `header_inspect_report_rows`,
  `header_inspect_negative_item_rows`, `header_inspect_command_coverage_rows`,
  `header_inspect_workflow_coverage_rows`,
  `header_inspect_required_workflow_rows`, `header_inspect_help_workflow_rows`,
  `header_inspect_report_count_mismatch`, `header_inspect_markdown_rows`,
  `header_inspect_markdown_matched`, `header_inspect_markdown_unmatched`,
  `header_inspect_case_count`, `header_inspect_raw_cases`,
  `header_inspect_zlib_cases`, `header_inspect_gzip_cases`,
  `header_inspect_negative_cases`, `header_inspect_raw_negative_cases`,
  `header_inspect_zlib_negative_cases`, `header_inspect_gzip_negative_cases`,
  `header_inspect_command_count`, `header_inspect_command_successes`,
  `header_inspect_command_failures`, `header_inspect_workflow_count`,
  `header_inspect_workflow_successes`, `header_inspect_dictionary_cases`,
  `header_inspect_optional_header_cases`, `header_inspect_fhcrc_cases`,
  `header_inspect_required_workflow_count`,
  `header_inspect_missing_workflow_count`,
  `header_inspect_missing_workflows`
- `dashboard_strict_present`, `dashboard_strict_ok`, `dashboard_strict_healthy`,
  `dashboard_strict_check_count`, `dashboard_strict_check_rows`,
  `dashboard_strict_mode_count`, `dashboard_strict_mode_count_rows`,
  `dashboard_strict_expected_failure_count`, `dashboard_strict_matched_count`,
  `dashboard_strict_expected_mode_count`, `dashboard_strict_expected_mode_rows`,
  `dashboard_strict_mode_requirement_rows`,
  `dashboard_strict_validation_reason_rows`,
  `dashboard_strict_report_count_mismatch`,
  `dashboard_strict_missing_mode_count`, `dashboard_strict_missing_checks`,
  `dashboard_strict_missing_expected_failures`,
  `dashboard_strict_missing_matched`, `dashboard_strict_missing_modes`,
  `dashboard_strict_markdown_present`, `dashboard_strict_markdown_rows`,
  `dashboard_strict_markdown_matched`, `dashboard_strict_markdown_unmatched`
- `dashboard_configuration_healthy`, `dashboard_config_index_present`,
  `dashboard_config_index_ok`, `dashboard_config_index_config_count`,
  `dashboard_config_index_config_rows`, `dashboard_config_index_matched`,
  `dashboard_config_index_unmatched`, `dashboard_config_index_count_mismatch`,
  `dashboard_config_index_row_unmatched`,
  `dashboard_config_index_negative_present`,
  `dashboard_config_index_negative_ok`,
  `dashboard_config_index_negative_case_count`,
  `dashboard_config_index_negative_rows`,
  `dashboard_config_index_negative_matched`,
  `dashboard_config_index_negative_unmatched`,
  `dashboard_config_index_negative_count_mismatch`,
  `dashboard_config_index_negative_row_unmatched`,
  `dashboard_category_negative_present`, `dashboard_category_negative_ok`,
  `dashboard_category_negative_case_count`, `dashboard_category_negative_rows`,
  `dashboard_category_negative_matched`,
  `dashboard_category_negative_unmatched`,
  `dashboard_category_negative_count_mismatch`,
  `dashboard_category_negative_row_unmatched`,
  `dashboard_producers_required_present`,
  `dashboard_producers_required_ok`,
  `dashboard_producers_required_artifact_count`,
  `dashboard_producers_required_rows`,
  `dashboard_producers_required_matched`,
  `dashboard_producers_required_unmatched`,
  `dashboard_producers_required_count_mismatch`,
  `dashboard_producers_required_row_unmatched`,
  `dashboard_producers_required_smoke_gate_count`,
  `dashboard_producers_negative_present`, `dashboard_producers_negative_ok`,
  `dashboard_producers_negative_case_count`, `dashboard_producers_negative_rows`,
  `dashboard_producers_negative_matched`,
  `dashboard_producers_negative_unmatched`,
  `dashboard_producers_negative_count_mismatch`,
  `dashboard_producers_negative_row_unmatched`
- `validation_json_present`, `validation_json_ok`, `validation_json_healthy`,
  `validation_json_checked_schema_count`,
  `validation_json_checked_schema_unique_count`,
  `validation_json_checked_schema_duplicate_count`,
  `validation_json_cli_success_ok`,
  `validation_json_cli_failure_ok`, `validation_json_cli_failure_hint`,
  `validation_json_report_rows`, `validation_json_corrupt_rows`,
  `validation_json_docs_negative_present`,
  `validation_json_docs_negative_ok`,
  `validation_json_docs_negative_case_count`,
  `validation_json_docs_negative_rows`,
  `validation_json_docs_negative_matched`,
  `validation_json_docs_negative_unmatched`,
  `validation_json_docs_negative_count_mismatch`,
  `validation_json_docs_negative_row_unmatched`
- `sidecar_corrupt_present`, `sidecar_corrupt_healthy`,
  `sidecar_corrupt_rows`, `sidecar_corrupt_metadata_ok_rows`,
  `sidecar_corrupt_full_rejected_rows`,
  `sidecar_corrupt_metadata_failed_rows`,
  `sidecar_corrupt_full_not_rejected_rows`
- `huffman_length_present`, `huffman_length_healthy`,
  `huffman_length_row_count`, `huffman_length_optimal_rows`,
  `huffman_length_non_optimal_rows`, `huffman_length_malformed_rows`,
  `huffman_length_worst_gap_bits`,
  `huffman_length_package_merge_optimal_rows`,
  `huffman_length_package_merge_non_optimal_rows`,
  `huffman_length_package_merge_worst_gap_bits`,
  `huffman_length_markdown_present`,
  `huffman_length_markdown_summary_rows`,
  `huffman_length_markdown_matched`,
  `huffman_length_markdown_unmatched`,
  `huffman_length_markdown_case_rows`,
  `huffman_length_markdown_case_matched`,
  `huffman_length_markdown_case_unmatched`
- `level_report_present`, `level_report_healthy`,
  `level_report_rows`, `level_report_expected_rows`,
  `level_report_positive_rows`, `level_report_shape_rows`,
  `level_report_token_accounting_rows`, `level_report_ratio_rows`,
  `level_report_roundtrip_rows`, `level_report_missing_pairs`,
  `level_report_markdown_present`, `level_report_markdown_summary_rows`,
  `level_report_markdown_matched`, `level_report_markdown_unmatched`,
  `level_report_markdown_detail_rows`,
  `level_report_markdown_detail_matched`,
  `level_report_markdown_detail_unmatched`
- `dynamic_plan_present`, `dynamic_plan_healthy`,
  `dynamic_plan_source_count`, `dynamic_plan_expected_source_count`,
  `dynamic_plan_rows`, `dynamic_plan_expected_rows`,
  `dynamic_plan_positive_rows`, `dynamic_plan_token_accounting_rows`,
  `dynamic_plan_histogram_rows`, `dynamic_plan_ratio_rows`,
  `dynamic_plan_slack_rows`, `dynamic_plan_wrapper_rows`,
  `dynamic_plan_malformed_rows`, `dynamic_plan_missing_sources`,
  `dynamic_plan_missing_paths`
- `checksum_bench_present`, `checksum_bench_healthy`,
  `checksum_bench_rows`, `checksum_bench_expected_rows`,
  `checksum_bench_positive_rows`, `checksum_bench_workload_rows`,
  `checksum_bench_throughput_rows`, `checksum_bench_crc32_mix_groups`,
  `checksum_bench_crc32c_mix_groups`, `checksum_bench_missing_algorithms`
- `chunk_cursor_bench_present`, `chunk_cursor_bench_healthy`,
  `chunk_cursor_bench_rows`, `chunk_cursor_bench_expected_rows`,
  `chunk_cursor_bench_positive_rows`, `chunk_cursor_bench_shape_rows`,
  `chunk_cursor_bench_throughput_rows`,
  `chunk_cursor_bench_checksum_matched_cases`,
  `chunk_cursor_bench_missing_pairs`
- `deflate_match_copy_bench_present`, `deflate_match_copy_bench_healthy`,
  `deflate_match_copy_bench_rows`, `deflate_match_copy_bench_expected_rows`,
  `deflate_match_copy_bench_positive_rows`,
  `deflate_match_copy_bench_expected_class_rows`,
  `deflate_match_copy_bench_output_bytes_rows`,
  `deflate_match_copy_bench_throughput_rows`,
  `deflate_match_copy_bench_checksum_matched_cases`,
  `deflate_match_copy_bench_missing_pairs`
- `deflate_huffman_build_bench_present`,
  `deflate_huffman_build_bench_healthy`, `deflate_huffman_build_bench_rows`,
  `deflate_huffman_build_bench_expected_rows`,
  `deflate_huffman_build_bench_positive_rows`,
  `deflate_huffman_build_bench_lookup_rows`,
  `deflate_huffman_build_bench_throughput_rows`,
  `deflate_huffman_build_bench_checksum_variant_cases`,
  `deflate_huffman_build_bench_missing_pairs`
- `deflate_huffman_lookup_bench_present`,
  `deflate_huffman_lookup_bench_healthy`,
  `deflate_huffman_lookup_bench_rows`,
  `deflate_huffman_lookup_bench_expected_rows`,
  `deflate_huffman_lookup_bench_positive_rows`,
  `deflate_huffman_lookup_bench_lookup_rows`,
  `deflate_huffman_lookup_bench_throughput_rows`,
  `deflate_huffman_lookup_bench_checksum_matched_cases`,
  `deflate_huffman_lookup_bench_missing_pairs`
- `deflate_chunked_huffman_bench_present`,
  `deflate_chunked_huffman_bench_healthy`,
  `deflate_chunked_huffman_bench_rows`,
  `deflate_chunked_huffman_bench_expected_rows`,
  `deflate_chunked_huffman_bench_positive_rows`,
  `deflate_chunked_huffman_bench_shape_rows`,
  `deflate_chunked_huffman_bench_buffered_zero_chunk_rows`,
  `deflate_chunked_huffman_bench_chunk_count_rows`,
  `deflate_chunked_huffman_bench_throughput_rows`,
  `deflate_chunked_huffman_bench_checksum_matched_cases`,
  `deflate_chunked_huffman_bench_missing_pairs`
- `deflate_extra_bits_bench_present`,
  `deflate_extra_bits_bench_healthy`,
  `deflate_extra_bits_bench_rows`,
  `deflate_extra_bits_bench_expected_rows`,
  `deflate_extra_bits_bench_positive_rows`,
  `deflate_extra_bits_bench_shape_rows`,
  `deflate_extra_bits_bench_throughput_rows`,
  `deflate_extra_bits_bench_checksum_matched_cases`,
  `deflate_extra_bits_bench_paired_checksum_rows`,
  `deflate_extra_bits_bench_expected_paired_checksum_rows`,
  `deflate_extra_bits_bench_missing_pairs`
- `dictionary_decode_bench_present`,
  `dictionary_decode_bench_healthy`, `dictionary_decode_bench_rows`,
  `dictionary_decode_bench_expected_rows`,
  `dictionary_decode_bench_positive_rows`,
  `dictionary_decode_bench_shape_rows`,
  `dictionary_decode_bench_output_size_rows`,
  `dictionary_decode_bench_throughput_rows`,
  `dictionary_decode_bench_checksum_matched_payloads`,
  `dictionary_decode_bench_missing_pairs`
- `png_scanline_bench_present`, `png_scanline_bench_healthy`,
  `png_scanline_bench_rows`, `png_scanline_bench_expected_rows`,
  `png_scanline_bench_positive_rows`, `png_scanline_bench_shape_rows`,
  `png_scanline_bench_io_match_rows`,
  `png_scanline_bench_throughput_rows`,
  `png_scanline_bench_checksum_matched_bpps`,
  `png_scanline_bench_missing_pairs`
- `chunked_zlib_bench_present`, `chunked_zlib_bench_healthy`,
  `chunked_zlib_bench_rows`, `chunked_zlib_bench_expected_rows`,
  `chunked_zlib_bench_positive_rows`, `chunked_zlib_bench_shape_rows`,
  `chunked_zlib_bench_chunk_count_rows`, `chunked_zlib_bench_ratio_rows`,
  `chunked_zlib_bench_missing_cases`,
  `chunked_zlib_bench_markdown_present`,
  `chunked_zlib_bench_markdown_rows`,
  `chunked_zlib_bench_markdown_matched`,
  `chunked_zlib_bench_markdown_unmatched`
- `png_streaming_zlib_bench_present`, `png_streaming_zlib_bench_healthy`,
  `png_streaming_zlib_bench_rows`,
  `png_streaming_zlib_bench_expected_rows`,
  `png_streaming_zlib_bench_positive_rows`,
  `png_streaming_zlib_bench_shape_rows`,
  `png_streaming_zlib_bench_image_size_rows`,
  `png_streaming_zlib_bench_chunk_count_rows`,
  `png_streaming_zlib_bench_ratio_rows`,
  `png_streaming_zlib_bench_missing_cases`
- `deflate_dynamic_decode_profile_present`,
  `deflate_dynamic_decode_profile_healthy`,
  `deflate_dynamic_decode_profile_rows`,
  `deflate_dynamic_decode_profile_required_rows`,
  `deflate_dynamic_decode_profile_positive_rows`,
  `deflate_dynamic_decode_profile_histogram_rows`,
  `deflate_dynamic_decode_profile_lookup_rows`,
  `deflate_dynamic_decode_profile_match_class_rows`,
  `deflate_dynamic_decode_profile_ratio_rows`,
  `deflate_dynamic_decode_profile_chunked_window_rows`,
  `deflate_dynamic_decode_profile_missing_cases`
- `native_library_bench_present`, `native_library_bench_healthy`,
  `native_library_bench_rows`, `native_library_bench_expected_rows`,
  `native_library_bench_positive_rows`,
  `native_library_bench_throughput_rows`,
  `native_library_bench_iteration_rows`,
  `native_library_bench_improvement_checks`,
  `native_library_bench_expected_improvement_checks`,
  `native_library_bench_missing_pairs`
- `fuzz_corpus_present`, `fuzz_corpus_ok`,
  `fuzz_corpus_coverage_present`, `fuzz_corpus_coverage_ok`,
  `fuzz_corpus_markdown_present`, `fuzz_corpus_healthy`,
  `fuzz_corpus_cases`, `fuzz_corpus_accepted`, `fuzz_corpus_rejected`,
  `fuzz_corpus_report_rows`, `fuzz_corpus_report_count_mismatch`,
  `fuzz_corpus_matched_rows`, `fuzz_corpus_unmatched_rows`,
  `fuzz_corpus_exact_error_expectations`,
  `fuzz_corpus_mode_count_rows`, `fuzz_corpus_error_count_rows`,
  `fuzz_corpus_coverage_mode_requirements`,
  `fuzz_corpus_coverage_error_requirements`,
  `fuzz_corpus_coverage_mode_matched`,
  `fuzz_corpus_coverage_error_matched`,
  `fuzz_corpus_coverage_unmatched`, `fuzz_corpus_markdown_rows`,
  `fuzz_corpus_markdown_matched`, `fuzz_corpus_markdown_unmatched`
- `decode_stage_present`, `decode_stage_ok`, `decode_stage_healthy`,
  `decode_stage_rows`, `decode_stage_error_rows`,
  `decode_stage_report_rows`, `decode_stage_error_item_rows`,
  `decode_stage_report_count_mismatch`,
  `decode_stage_matched_error_rows`, `decode_stage_unmatched_error_rows`,
  `decode_stage_csv_present`, `decode_stage_csv_rows`,
  `decode_stage_csv_positive_rows`, `decode_stage_csv_header_rows`,
  `decode_stage_csv_dynamic_rows`, `decode_stage_csv_fixed_rows`,
  `decode_stage_csv_stored_rows`, `decode_stage_csv_missing_cases`,
  `decode_stage_markdown_present`, `decode_stage_markdown_rows`,
  `decode_stage_markdown_matched`, `decode_stage_markdown_unmatched`
- `native_fuzz_corpus_present`, `native_fuzz_corpus_coverage_present`,
  `native_fuzz_corpus_markdown_present`, `native_fuzz_corpus_healthy`,
  `native_fuzz_corpus_cases`, `native_fuzz_corpus_accepted`,
  `native_fuzz_corpus_rejected`, `native_fuzz_corpus_report_rows`,
  `native_fuzz_corpus_report_count_mismatch`,
  `native_fuzz_corpus_matched_rows`, `native_fuzz_corpus_unmatched_rows`,
  `native_fuzz_corpus_exact_error_expectations`,
  `native_fuzz_corpus_mode_count_rows`, `native_fuzz_corpus_error_count_rows`,
  `native_fuzz_corpus_coverage_mode_requirements`,
  `native_fuzz_corpus_coverage_error_requirements`,
  `native_fuzz_corpus_coverage_mode_matched`,
  `native_fuzz_corpus_coverage_error_matched`,
  `native_fuzz_corpus_coverage_unmatched`,
  `native_fuzz_corpus_markdown_rows`,
  `native_fuzz_corpus_markdown_matched`,
  `native_fuzz_corpus_markdown_unmatched`
- `br_static_dictionary_present`,
  `br_static_dictionary_candidate_markdown_present`,
  `br_static_dictionary_candidate_markdown_summary_rows`,
  `br_static_dictionary_candidate_markdown_matched`,
  `br_static_dictionary_candidate_markdown_unmatched`,
  `br_static_dictionary_candidate_markdown_sample_rows`,
  `br_static_dictionary_candidate_markdown_sample_matched`,
  `br_static_dictionary_candidate_markdown_sample_unmatched`,
  `br_static_dictionary_upstream_present`,
  `br_static_dictionary_upstream_report_present`,
  `br_static_dictionary_upstream_report_candidate_count`,
  `br_static_dictionary_upstream_report_raw_word_count`,
  `br_static_dictionary_upstream_report_upstream_raw_word_count`,
  `br_static_dictionary_upstream_markdown_present`,
  `br_static_dictionary_upstream_markdown_summary_rows`,
  `br_static_dictionary_upstream_markdown_matched`,
  `br_static_dictionary_upstream_markdown_unmatched`,
  `br_static_dictionary_upstream_markdown_sample_rows`,
  `br_static_dictionary_upstream_markdown_sample_matched`,
  `br_static_dictionary_upstream_markdown_sample_unmatched`,
  `br_static_dictionary_node_present`,
  `br_static_dictionary_node_markdown_present`,
  `br_static_dictionary_node_markdown_summary_rows`,
  `br_static_dictionary_node_markdown_matched`,
  `br_static_dictionary_node_markdown_unmatched`,
  `br_static_dictionary_node_markdown_rows`,
  `br_static_dictionary_node_markdown_matched_rows`,
  `br_static_dictionary_node_markdown_unmatched_rows`,
  `br_static_dictionary_audit_present`,
  `br_static_dictionary_negative_present`, `br_static_dictionary_healthy`,
  `br_static_dictionary_candidate_count`, `br_static_dictionary_raw_word_count`,
  `br_static_dictionary_upstream_candidate_count`,
  `br_static_dictionary_upstream_raw_word_count`,
  `br_static_dictionary_node_probed_count`,
  `br_static_dictionary_node_decode_successes`,
  `br_static_dictionary_node_size_winner_count`,
  `br_static_dictionary_audit_entry_count`,
  `br_static_dictionary_audit_anchor_count`,
  `br_static_dictionary_audit_generated_zig_bytes`,
  `br_static_dictionary_negative_case_count`,
  `br_static_dictionary_negative_matched`,
  `br_static_dictionary_report_present`,
  `br_static_dictionary_report_csv_present`,
  `br_static_dictionary_report_markdown_present`,
  `br_static_dictionary_report_negative_present`,
  `br_static_dictionary_core_healthy`,
  `br_static_dictionary_report_healthy`,
  `br_static_dictionary_report_entry_count`,
  `br_static_dictionary_report_json_entries`,
  `br_static_dictionary_report_transform_count`,
  `br_static_dictionary_report_length_count`,
  `br_static_dictionary_report_identity_count`,
  `br_static_dictionary_report_transform_entry_count`,
  `br_static_dictionary_report_phrase_count`,
  `br_static_dictionary_report_category_total`,
  `br_static_dictionary_report_category_mismatch_rows`,
  `br_static_dictionary_report_matrix_rows`,
  `br_static_dictionary_report_matrix_total`,
  `br_static_dictionary_report_matrix_mismatch_rows`,
  `br_static_dictionary_report_csv_rows`,
  `br_static_dictionary_report_csv_matched`,
  `br_static_dictionary_report_csv_unmatched`,
  `br_static_dictionary_report_markdown_summary_rows`,
  `br_static_dictionary_report_markdown_matched`,
  `br_static_dictionary_report_markdown_unmatched`,
  `br_static_dictionary_report_markdown_matrix_rows`,
  `br_static_dictionary_report_markdown_matrix_matched`,
  `br_static_dictionary_report_markdown_matrix_unmatched`,
  `br_static_dictionary_report_markdown_entry_rows`,
  `br_static_dictionary_report_markdown_entry_matched`,
  `br_static_dictionary_report_markdown_entry_unmatched`,
  `br_static_dictionary_report_negative_case_count`,
  `br_static_dictionary_report_negative_matched`,
  `br_static_dictionary_report_negative_unmatched`
- `png_scratch_present`, `png_scratch_markdown_present`,
  `png_scratch_healthy`, `png_scratch_case_count`,
  `png_scratch_report_rows`, `png_scratch_report_count_mismatch`,
  `png_scratch_row_consistent_count`, `png_scratch_row_inconsistent_count`,
  `png_scratch_adam7_cases`, `png_scratch_stored_achieved`,
  `png_scratch_fixed_achieved`, `png_scratch_total_zlib_scratch`,
  `png_scratch_total_streaming_savings`, `png_scratch_max_working_scratch`,
  `png_scratch_max_streaming_working_scratch`,
  `png_scratch_max_fixed_dynamic_streaming_working_scratch`,
  `png_scratch_min_streaming_ratio`, `png_scratch_markdown_rows`,
  `png_scratch_markdown_matched`, `png_scratch_markdown_unmatched`
- `zlib_relaxed_present`, `zlib_relaxed_markdown_present`,
  `zlib_relaxed_healthy`, `zlib_relaxed_gate_present`,
  `zlib_relaxed_gate_ok`, `zlib_relaxed_gate_check_count`,
  `zlib_relaxed_gate_expected_checks`,
  `zlib_relaxed_gate_passed_count`, `zlib_relaxed_gate_failed_checks`,
  `zlib_relaxed_gate_report_matched`,
  `zlib_relaxed_gate_report_unmatched`,
  `zlib_relaxed_strict_rejections`, `zlib_relaxed_successes`,
  `zlib_relaxed_dictionary_successes`,
  `zlib_relaxed_concatenated_successes`,
  `zlib_relaxed_decoder_successes`, `zlib_relaxed_limited_rejections`,
  `gzip_relaxed_strict_rejections`, `gzip_relaxed_successes`,
  `gzip_relaxed_concatenated_successes`, `gzip_relaxed_decoder_successes`,
  `gzip_relaxed_limited_rejections`, `zlib_relaxed_markdown_rows`,
  `zlib_relaxed_markdown_matched`, `zlib_relaxed_markdown_unmatched`
- `snappy_report_present`, `snappy_report_healthy`, `snappy_report_rows`,
  `snappy_report_expected_rows`, `snappy_report_positive_timing_rows`,
  `snappy_report_ratio_rows`, `snappy_report_throughput_rows`,
  `snappy_report_repetitive_shrunk_rows`,
  `snappy_report_reusable_size_matched_cases`,
  `snappy_report_reusable_checksum_matched_cases`,
  `snappy_report_missing_pairs`
- `zstd_compare_present`, `zstd_compare_standard_present`,
  `zstd_compare_block_sweep_present`, `zstd_compare_healthy`,
  `zstd_compare_rows`, `zstd_compare_standard_rows`,
  `zstd_compare_block_sweep_rows`, `zstd_compare_native_ratio`,
  `zstd_compare_native_stream_ratio`, `zstd_compare_standard_native_ratio`,
  `zstd_compare_standard_native_stream_ratio`, `zstd_compare_decode_vs_zstd`,
  `zstd_compare_standard_decode_vs_zstd`, `zstd_compare_best_block_len`,
  `zstd_compare_best_range_decode_mib_s`,
  `zstd_compare_best_range_decode_full_input_mib_s`,
  `zstd_compare_csv_present_count`,
  `zstd_compare_csv_expected_present_count`, `zstd_compare_csv_rows`,
  `zstd_compare_csv_expected_rows`, `zstd_compare_csv_matched_rows`,
  `zstd_compare_csv_unmatched_rows`, `zstd_compare_markdown_present_count`,
  `zstd_compare_markdown_expected_present_count`,
  `zstd_compare_markdown_summary_rows`, `zstd_compare_markdown_matched`,
  `zstd_compare_markdown_unmatched`, `zstd_compare_markdown_detail_rows`,
  `zstd_compare_markdown_detail_matched`,
  `zstd_compare_markdown_detail_unmatched`
- `native_allocation_present`, `native_allocation_smoke_present`,
  `native_allocation_negative_present`, `native_allocation_markdown_present`,
  `native_allocation_healthy`, `native_allocation_report_case_count`,
  `native_allocation_report_rows`,
  `native_allocation_report_count_mismatch`,
  `native_allocation_report_balanced_rows`,
  `native_allocation_report_duplicate_cases`,
  `native_allocation_report_unbalanced_rows`,
  `native_allocation_required_zero_allocation_cases`,
  `native_allocation_zero_allocation_matched`,
  `native_allocation_zero_report_matched`,
  `native_allocation_zero_report_unmatched`,
  `native_allocation_required_budget_cases`,
  `native_allocation_budget_matched`,
  `native_allocation_budget_report_matched`,
  `native_allocation_budget_report_unmatched`,
  `native_allocation_smoke_classified_cases`,
  `native_allocation_smoke_classification_overlap`,
  `native_allocation_smoke_classification_missing`,
  `native_allocation_smoke_classification_extra`,
  `native_allocation_negative_case_count`,
  `native_allocation_negative_matched`,
  `native_allocation_negative_unmatched`, `native_allocation_markdown_rows`,
  `native_allocation_markdown_matched`,
  `native_allocation_markdown_unmatched`
- `python_zlib_diff_present`, `python_zlib_diff_ok`,
  `python_zlib_diff_healthy`, `python_zlib_diff_payloads`,
  `python_zlib_diff_large_file_payloads`,
  `python_zlib_diff_file_hex_encode_cases`,
  `python_zlib_diff_match_heavy_payloads`,
  `python_zlib_diff_dynamic_payloads`, `python_zlib_diff_dictionary_cases`,
  `python_zlib_diff_zlib_dict_encode_cases`,
  `python_zlib_diff_raw_dict_encode_cases`,
  `python_zlib_diff_dictionary_encode_cases`,
  `python_zlib_diff_malformed_wrapper_cases`,
  `python_zlib_diff_malformed_deflate_cases`, `python_zlib_diff_malformed_cases`,
  `python_zlib_diff_cli_successes`, `python_zlib_diff_expected_failures`,
  `python_zlib_diff_cli_total_outcomes`,
  `python_zlib_diff_file_hex_expected_cases`,
  `python_zlib_diff_file_hex_case_mismatch`,
  `python_zlib_diff_cli_success_floor`, `python_zlib_diff_cli_success_shortfall`,
  `python_zlib_diff_expected_failure_floor`,
  `python_zlib_diff_expected_failure_shortfall`,
  `python_zlib_diff_cli_outcome_floor`,
  `python_zlib_diff_cli_outcome_shortfall`
- `native_codec_probes_present`, `native_codec_probes_ok`,
  `native_codec_probes_markdown_present`, `native_codec_probes_healthy`,
  `native_codec_probes_probe_count`, `native_codec_probes_ok_probe_count`,
  `native_codec_probes_timed_out_probes`,
  `native_codec_probes_coverage_rows`,
  `native_codec_probes_coverage_ok_rows`,
  `native_codec_probes_coverage_case_sum`,
  `native_codec_probes_capability_count`,
  `native_codec_probes_ok_capability_count`,
  `native_codec_probes_lib_generated_cases`,
  `native_codec_probes_incremental_cases`,
  `native_codec_probes_chunked_cases`,
  `native_codec_probes_reusable_chunked_cases`,
  `native_codec_probes_fse_repeat_cases`,
  `native_codec_probes_dictionary_cases`,
  `native_codec_probes_malformed_cases`,
  `native_codec_probes_total_cases`,
  `native_codec_probes_zstd_frame_cases`,
  `native_codec_probes_zstd_dictionary_cases`,
  `native_codec_probes_markdown_rows`,
  `native_codec_probes_markdown_matched`,
  `native_codec_probes_markdown_unmatched`
- `native_summary_error_present`, `native_summary_error_healthy`,
  `native_summary_error_case_count`, `native_summary_error_case_rows`,
  `native_summary_error_case_count_mismatch`,
  `native_summary_error_lz4_case_count`,
  `native_summary_error_zstd_case_count`,
  `native_summary_error_codec_case_count_mismatch`,
  `native_summary_error_checksum_mismatch_count`,
  `native_summary_error_corrupt_frame_count`,
  `native_summary_error_truncated_frame_count`,
  `native_summary_error_magic_phase_count`,
  `native_summary_error_skippable_payload_phase_count`,
  `native_summary_error_frame_body_phase_count`,
  `native_summary_error_frame_checksum_phase_count`,
  `native_summary_error_frame_phase_count`,
  `native_summary_error_error_counts`, `native_summary_error_phase_counts`,
  `native_summary_error_lz4_error_counts`, `native_summary_error_zstd_error_counts`,
  `native_summary_error_lz4_phase_counts`, `native_summary_error_zstd_phase_counts`,
  `native_summary_error_offset_min`, `native_summary_error_offset_max`,
  `native_summary_error_lz4_offset_min`, `native_summary_error_lz4_offset_max`,
  `native_summary_error_zstd_offset_min`, `native_summary_error_zstd_offset_max`,
  `native_summary_error_error_count_mismatch`,
  `native_summary_error_phase_count_mismatch`,
  `native_summary_error_codec_error_count_mismatch`,
  `native_summary_error_codec_phase_count_mismatch`,
  `native_summary_error_offset_range_mismatch`,
  `native_summary_error_phase_offset_ranges`,
  `native_summary_error_required_codec_phases`,
  `native_summary_error_lz4_missing_phases`,
  `native_summary_error_zstd_missing_phases`
- `native_summary_error_negative_present`,
  `native_summary_error_negative_healthy`,
  `native_summary_error_negative_case_count`
- `lz4_native_summary_present`, `lz4_native_summary_healthy`,
  `lz4_native_summary_frame_count`,
  `lz4_native_summary_skippable_frame_count`,
  `lz4_native_summary_checksum_frame_count`,
  `lz4_native_summary_block_checksum_frame_count`,
  `lz4_native_summary_dictionary_id_frame_count`,
  `lz4_native_summary_content_size_frame_count`,
  `lz4_native_summary_declared_content_bytes`,
  `lz4_native_summary_block_count`, `lz4_native_summary_raw_block_count`,
  `lz4_native_summary_compressed_block_count`,
  `lz4_native_summary_compressed_bytes`,
  `lz4_native_summary_payload_bytes`,
  `lz4_native_summary_skippable_payload_bytes`,
  `lz4_native_summary_block_count_mismatch`,
  `lz4_native_summary_declared_payload_slack_bytes`,
  `lz4_native_summary_metadata_frame_overflow`,
  `lz4_native_summary_checksum_frame_overflow`,
  `lz4_native_summary_block_checksum_frame_overflow`
- `zstd_native_summary_present`, `zstd_native_summary_healthy`,
  `zstd_native_summary_frame_count`,
  `zstd_native_summary_skippable_frame_count`,
  `zstd_native_summary_checksum_frame_count`,
  `zstd_native_summary_dictionary_id_frame_count`,
  `zstd_native_summary_content_size_frame_count`,
  `zstd_native_summary_declared_content_bytes`,
  `zstd_native_summary_block_count`, `zstd_native_summary_raw_block_count`,
  `zstd_native_summary_rle_block_count`,
  `zstd_native_summary_compressed_block_count`,
  `zstd_native_summary_compressed_bytes`,
  `zstd_native_summary_payload_bytes`,
  `zstd_native_summary_skippable_payload_bytes`,
  `zstd_native_summary_block_count_mismatch`,
  `zstd_native_summary_declared_payload_slack_bytes`,
  `zstd_native_summary_metadata_frame_overflow`,
  `zstd_native_summary_checksum_frame_overflow`,
  `zstd_native_summary_block_checksum_frame_overflow`
- `artifacts`

Each artifact includes:

- `name`, `path`, `category`, `format`
- `expected_format`
- `producer_step`
- `producer_missing_allowed`
- `smoke_gate`
- `size_bytes`, `mtime_utc`
- JSON summary fields when applicable: `schema`, `schema_version`, `rows`, `ok`
- Header-inspect artifact coverage fields when applicable:
  `required_workflow_count`, `missing_workflow_count`

Example:

```json
{
  "schema": "vort.dashboard_index",
  "schema_version": 1,
  "artifact_count": 1,
  "producer_step_covered": 1,
  "producer_step_missing": [],
  "producer_step_allowed_missing": [],
  "producer_healthy": true,
  "smoke_gate_covered": 1,
  "smoke_gate_missing": [],
  "smoke_gate_healthy": true,
  "smoke_gate_required_missing": [],
  "validation_healthy": false,
  "validation_unhealthy_reasons": [
    "missing_header_inspect_artifact",
    "missing_dashboard_strict_artifact",
    "missing_dashboard_configuration_artifact",
    "missing_validation_json_smoke_artifact",
    "missing_validation_json_docs_negative_artifact",
    "missing_sidecar_corrupt_artifact",
    "missing_huffman_length_artifact",
    "missing_checksum_bench_artifact",
    "missing_chunk_cursor_bench_artifact",
    "missing_deflate_match_copy_bench_artifact",
    "missing_deflate_huffman_build_bench_artifact",
    "missing_deflate_huffman_lookup_bench_artifact",
    "missing_deflate_chunked_huffman_bench_artifact",
    "missing_deflate_extra_bits_bench_artifact",
    "missing_dictionary_decode_bench_artifact",
    "missing_png_scanline_bench_artifact",
    "missing_chunked_zlib_bench_artifact",
    "missing_png_streaming_zlib_bench_artifact",
    "missing_deflate_dynamic_decode_profile_artifact",
    "missing_fuzz_corpus_artifact",
    "missing_fuzz_coverage_artifact",
    "missing_native_fuzz_corpus_artifact",
    "missing_native_fuzz_coverage_artifact",
    "missing_png_scratch_artifact",
    "missing_zlib_relaxed_artifact",
    "missing_snappy_report_artifact",
    "missing_native_allocation_artifact",
    "missing_native_library_bench_artifact",
    "missing_decode_stage_artifact",
    "missing_python_zlib_diff_artifact",
    "missing_native_codec_probes_artifact",
    "missing_zstd_compare_artifact",
    "missing_br_static_dictionary_artifact",
    "missing_native_summary_error_dashboard_artifact",
    "missing_native_summary_error_negative_artifact",
    "missing_lz4_native_summary_artifact",
    "missing_zstd_native_summary_artifact",
    "missing_native_tier_range_artifact",
    "missing_native_tier_corpus_discovery_artifact"
  ],
  "header_inspect_present": false,
  "header_inspect_ok": false,
  "header_inspect_healthy": false,
  "header_inspect_markdown_present": false,
  "header_inspect_report_rows": 0,
  "header_inspect_negative_item_rows": 0,
  "header_inspect_command_coverage_rows": 0,
  "header_inspect_workflow_coverage_rows": 0,
  "header_inspect_required_workflow_rows": 0,
  "header_inspect_help_workflow_rows": 0,
  "header_inspect_report_count_mismatch": 0,
  "header_inspect_markdown_rows": 0,
  "header_inspect_markdown_matched": 0,
  "header_inspect_markdown_unmatched": 0,
  "header_inspect_case_count": 0,
  "header_inspect_raw_cases": 0,
  "header_inspect_zlib_cases": 0,
  "header_inspect_gzip_cases": 0,
  "header_inspect_negative_cases": 0,
  "header_inspect_raw_negative_cases": 0,
  "header_inspect_zlib_negative_cases": 0,
  "header_inspect_gzip_negative_cases": 0,
  "header_inspect_command_count": 0,
  "header_inspect_command_successes": 0,
  "header_inspect_command_failures": 0,
  "header_inspect_workflow_count": 0,
  "header_inspect_workflow_successes": 0,
  "header_inspect_dictionary_cases": 0,
  "header_inspect_optional_header_cases": 0,
  "header_inspect_fhcrc_cases": 0,
  "header_inspect_required_workflow_count": 0,
  "header_inspect_missing_workflow_count": 0,
  "header_inspect_missing_workflows": [],
  "dashboard_strict_present": false,
  "dashboard_strict_ok": false,
  "dashboard_strict_healthy": false,
  "dashboard_strict_check_count": 0,
  "dashboard_strict_check_rows": 0,
  "dashboard_strict_mode_count": 0,
  "dashboard_strict_mode_count_rows": 0,
  "dashboard_strict_expected_failure_count": 0,
  "dashboard_strict_matched_count": 0,
  "dashboard_strict_expected_mode_count": 0,
  "dashboard_strict_expected_mode_rows": 0,
  "dashboard_strict_mode_requirement_rows": 0,
  "dashboard_strict_validation_reason_rows": 0,
  "dashboard_strict_report_count_mismatch": 0,
  "dashboard_strict_missing_mode_count": 0,
  "dashboard_strict_missing_checks": 0,
  "dashboard_strict_missing_expected_failures": 0,
  "dashboard_strict_missing_matched": 0,
  "dashboard_strict_missing_modes": [],
  "dashboard_strict_markdown_present": false,
  "dashboard_strict_markdown_rows": 0,
  "dashboard_strict_markdown_matched": 0,
  "dashboard_strict_markdown_unmatched": 0,
  "dashboard_configuration_healthy": false,
  "dashboard_config_index_present": false,
  "dashboard_config_index_ok": false,
  "dashboard_config_index_config_count": 0,
  "dashboard_config_index_config_rows": 0,
  "dashboard_config_index_matched": 0,
  "dashboard_config_index_unmatched": 0,
  "dashboard_config_index_count_mismatch": 0,
  "dashboard_config_index_row_unmatched": 0,
  "dashboard_config_index_negative_present": false,
  "dashboard_config_index_negative_ok": false,
  "dashboard_config_index_negative_case_count": 0,
  "dashboard_config_index_negative_rows": 0,
  "dashboard_config_index_negative_matched": 0,
  "dashboard_config_index_negative_unmatched": 0,
  "dashboard_config_index_negative_count_mismatch": 0,
  "dashboard_config_index_negative_row_unmatched": 0,
  "dashboard_category_negative_present": false,
  "dashboard_category_negative_ok": false,
  "dashboard_category_negative_case_count": 0,
  "dashboard_category_negative_rows": 0,
  "dashboard_category_negative_matched": 0,
  "dashboard_category_negative_unmatched": 0,
  "dashboard_category_negative_count_mismatch": 0,
  "dashboard_category_negative_row_unmatched": 0,
  "dashboard_producers_required_present": false,
  "dashboard_producers_required_ok": false,
  "dashboard_producers_required_artifact_count": 0,
  "dashboard_producers_required_rows": 0,
  "dashboard_producers_required_matched": 0,
  "dashboard_producers_required_unmatched": 0,
  "dashboard_producers_required_count_mismatch": 0,
  "dashboard_producers_required_row_unmatched": 0,
  "dashboard_producers_required_smoke_gate_count": 0,
  "dashboard_producers_negative_present": false,
  "dashboard_producers_negative_ok": false,
  "dashboard_producers_negative_case_count": 0,
  "dashboard_producers_negative_rows": 0,
  "dashboard_producers_negative_matched": 0,
  "dashboard_producers_negative_unmatched": 0,
  "dashboard_producers_negative_count_mismatch": 0,
  "dashboard_producers_negative_row_unmatched": 0,
  "validation_json_present": false,
  "validation_json_ok": false,
  "validation_json_healthy": false,
  "validation_json_checked_schema_count": 0,
  "validation_json_checked_schema_unique_count": 0,
  "validation_json_checked_schema_duplicate_count": 0,
  "validation_json_cli_success_ok": false,
  "validation_json_cli_failure_ok": false,
  "validation_json_cli_failure_hint": "",
  "validation_json_report_rows": 0,
  "validation_json_corrupt_rows": 0,
  "validation_json_docs_negative_present": false,
  "validation_json_docs_negative_ok": false,
  "validation_json_docs_negative_case_count": 0,
  "validation_json_docs_negative_rows": 0,
  "validation_json_docs_negative_matched": 0,
  "validation_json_docs_negative_unmatched": 0,
  "validation_json_docs_negative_count_mismatch": 0,
  "validation_json_docs_negative_row_unmatched": 0,
  "sidecar_corrupt_present": false,
  "sidecar_corrupt_healthy": false,
  "sidecar_corrupt_rows": 0,
  "sidecar_corrupt_metadata_ok_rows": 0,
  "sidecar_corrupt_full_rejected_rows": 0,
  "sidecar_corrupt_metadata_failed_rows": 0,
  "sidecar_corrupt_full_not_rejected_rows": 0,
  "sidecar_corrupt_item_rows": 0,
  "sidecar_corrupt_item_count_mismatch": 0,
  "sidecar_corrupt_markdown_present": false,
  "sidecar_corrupt_markdown_rows": 0,
  "sidecar_corrupt_markdown_matched": 0,
  "sidecar_corrupt_markdown_unmatched": 0,
  "huffman_length_present": false,
  "huffman_length_healthy": false,
  "huffman_length_row_count": 0,
  "huffman_length_optimal_rows": 0,
  "huffman_length_non_optimal_rows": 0,
  "huffman_length_malformed_rows": 0,
  "huffman_length_worst_gap_bits": 0,
  "huffman_length_package_merge_optimal_rows": 0,
  "huffman_length_package_merge_non_optimal_rows": 0,
  "huffman_length_package_merge_worst_gap_bits": 0,
  "huffman_length_markdown_present": false,
  "huffman_length_markdown_summary_rows": 0,
  "huffman_length_markdown_matched": 0,
  "huffman_length_markdown_unmatched": 0,
  "huffman_length_markdown_case_rows": 0,
  "huffman_length_markdown_case_matched": 0,
  "huffman_length_markdown_case_unmatched": 0,
  "level_report_present": false,
  "level_report_healthy": false,
  "level_report_rows": 0,
  "level_report_expected_rows": 0,
  "level_report_positive_rows": 0,
  "level_report_shape_rows": 0,
  "level_report_token_accounting_rows": 0,
  "level_report_ratio_rows": 0,
  "level_report_roundtrip_rows": 0,
  "level_report_missing_pairs": [],
  "level_report_markdown_present": false,
  "level_report_markdown_summary_rows": 0,
  "level_report_markdown_matched": 0,
  "level_report_markdown_unmatched": 0,
  "level_report_markdown_detail_rows": 0,
  "level_report_markdown_detail_matched": 0,
  "level_report_markdown_detail_unmatched": 0,
  "dynamic_plan_present": false,
  "dynamic_plan_healthy": false,
  "dynamic_plan_source_count": 0,
  "dynamic_plan_expected_source_count": 0,
  "dynamic_plan_rows": 0,
  "dynamic_plan_expected_rows": 0,
  "dynamic_plan_positive_rows": 0,
  "dynamic_plan_token_accounting_rows": 0,
  "dynamic_plan_histogram_rows": 0,
  "dynamic_plan_ratio_rows": 0,
  "dynamic_plan_slack_rows": 0,
  "dynamic_plan_wrapper_rows": 0,
  "dynamic_plan_malformed_rows": 0,
  "dynamic_plan_missing_sources": [],
  "dynamic_plan_missing_paths": [],
  "checksum_bench_present": false,
  "checksum_bench_healthy": false,
  "checksum_bench_rows": 0,
  "checksum_bench_expected_rows": 0,
  "checksum_bench_positive_rows": 0,
  "checksum_bench_workload_rows": 0,
  "checksum_bench_throughput_rows": 0,
  "checksum_bench_crc32_mix_groups": 0,
  "checksum_bench_crc32c_mix_groups": 0,
  "checksum_bench_missing_algorithms": [],
  "chunk_cursor_bench_present": false,
  "chunk_cursor_bench_healthy": false,
  "chunk_cursor_bench_rows": 0,
  "chunk_cursor_bench_expected_rows": 0,
  "chunk_cursor_bench_positive_rows": 0,
  "chunk_cursor_bench_shape_rows": 0,
  "chunk_cursor_bench_throughput_rows": 0,
  "chunk_cursor_bench_checksum_matched_cases": 0,
  "chunk_cursor_bench_missing_pairs": [],
  "deflate_match_copy_bench_present": false,
  "deflate_match_copy_bench_healthy": false,
  "deflate_match_copy_bench_rows": 0,
  "deflate_match_copy_bench_expected_rows": 0,
  "deflate_match_copy_bench_positive_rows": 0,
  "deflate_match_copy_bench_expected_class_rows": 0,
  "deflate_match_copy_bench_output_bytes_rows": 0,
  "deflate_match_copy_bench_throughput_rows": 0,
  "deflate_match_copy_bench_checksum_matched_cases": 0,
  "deflate_match_copy_bench_missing_pairs": [],
  "deflate_huffman_build_bench_present": false,
  "deflate_huffman_build_bench_healthy": false,
  "deflate_huffman_build_bench_rows": 0,
  "deflate_huffman_build_bench_expected_rows": 0,
  "deflate_huffman_build_bench_positive_rows": 0,
  "deflate_huffman_build_bench_lookup_rows": 0,
  "deflate_huffman_build_bench_throughput_rows": 0,
  "deflate_huffman_build_bench_checksum_variant_cases": 0,
  "deflate_huffman_build_bench_missing_pairs": [],
  "deflate_huffman_lookup_bench_present": false,
  "deflate_huffman_lookup_bench_healthy": false,
  "deflate_huffman_lookup_bench_rows": 0,
  "deflate_huffman_lookup_bench_expected_rows": 0,
  "deflate_huffman_lookup_bench_positive_rows": 0,
  "deflate_huffman_lookup_bench_lookup_rows": 0,
  "deflate_huffman_lookup_bench_throughput_rows": 0,
  "deflate_huffman_lookup_bench_checksum_matched_cases": 0,
  "deflate_huffman_lookup_bench_missing_pairs": [],
  "deflate_chunked_huffman_bench_present": false,
  "deflate_chunked_huffman_bench_healthy": false,
  "deflate_chunked_huffman_bench_rows": 0,
  "deflate_chunked_huffman_bench_expected_rows": 0,
  "deflate_chunked_huffman_bench_positive_rows": 0,
  "deflate_chunked_huffman_bench_shape_rows": 0,
  "deflate_chunked_huffman_bench_buffered_zero_chunk_rows": 0,
  "deflate_chunked_huffman_bench_chunk_count_rows": 0,
  "deflate_chunked_huffman_bench_throughput_rows": 0,
  "deflate_chunked_huffman_bench_checksum_matched_cases": 0,
  "deflate_chunked_huffman_bench_missing_pairs": [],
  "deflate_extra_bits_bench_present": false,
  "deflate_extra_bits_bench_healthy": false,
  "deflate_extra_bits_bench_rows": 0,
  "deflate_extra_bits_bench_expected_rows": 0,
  "deflate_extra_bits_bench_positive_rows": 0,
  "deflate_extra_bits_bench_shape_rows": 0,
  "deflate_extra_bits_bench_throughput_rows": 0,
  "deflate_extra_bits_bench_checksum_matched_cases": 0,
  "deflate_extra_bits_bench_paired_checksum_rows": 0,
  "deflate_extra_bits_bench_expected_paired_checksum_rows": 0,
  "deflate_extra_bits_bench_missing_pairs": [],
  "dictionary_decode_bench_present": false,
  "dictionary_decode_bench_healthy": false,
  "dictionary_decode_bench_rows": 0,
  "dictionary_decode_bench_expected_rows": 0,
  "dictionary_decode_bench_positive_rows": 0,
  "dictionary_decode_bench_shape_rows": 0,
  "dictionary_decode_bench_output_size_rows": 0,
  "dictionary_decode_bench_throughput_rows": 0,
  "dictionary_decode_bench_checksum_matched_payloads": 0,
  "dictionary_decode_bench_missing_pairs": [],
  "png_scanline_bench_present": false,
  "png_scanline_bench_healthy": false,
  "png_scanline_bench_rows": 0,
  "png_scanline_bench_expected_rows": 0,
  "png_scanline_bench_positive_rows": 0,
  "png_scanline_bench_shape_rows": 0,
  "png_scanline_bench_io_match_rows": 0,
  "png_scanline_bench_throughput_rows": 0,
  "png_scanline_bench_checksum_matched_bpps": 0,
  "png_scanline_bench_missing_pairs": [],
  "chunked_zlib_bench_present": false,
  "chunked_zlib_bench_healthy": false,
  "chunked_zlib_bench_rows": 0,
  "chunked_zlib_bench_expected_rows": 0,
  "chunked_zlib_bench_positive_rows": 0,
  "chunked_zlib_bench_shape_rows": 0,
  "chunked_zlib_bench_chunk_count_rows": 0,
  "chunked_zlib_bench_ratio_rows": 0,
  "chunked_zlib_bench_missing_cases": [],
  "chunked_zlib_bench_markdown_present": false,
  "chunked_zlib_bench_markdown_rows": 0,
  "chunked_zlib_bench_markdown_matched": 0,
  "chunked_zlib_bench_markdown_unmatched": 0,
  "png_streaming_zlib_bench_present": false,
  "png_streaming_zlib_bench_healthy": false,
  "png_streaming_zlib_bench_rows": 0,
  "png_streaming_zlib_bench_expected_rows": 0,
  "png_streaming_zlib_bench_positive_rows": 0,
  "png_streaming_zlib_bench_shape_rows": 0,
  "png_streaming_zlib_bench_image_size_rows": 0,
  "png_streaming_zlib_bench_chunk_count_rows": 0,
  "png_streaming_zlib_bench_ratio_rows": 0,
  "png_streaming_zlib_bench_missing_cases": [],
  "deflate_dynamic_decode_profile_present": false,
  "deflate_dynamic_decode_profile_healthy": false,
  "deflate_dynamic_decode_profile_rows": 0,
  "deflate_dynamic_decode_profile_required_rows": 0,
  "deflate_dynamic_decode_profile_positive_rows": 0,
  "deflate_dynamic_decode_profile_histogram_rows": 0,
  "deflate_dynamic_decode_profile_lookup_rows": 0,
  "deflate_dynamic_decode_profile_match_class_rows": 0,
  "deflate_dynamic_decode_profile_ratio_rows": 0,
  "deflate_dynamic_decode_profile_chunked_window_rows": 0,
  "deflate_dynamic_decode_profile_missing_cases": [],
  "native_library_bench_present": false,
  "native_library_bench_healthy": false,
  "native_library_bench_rows": 0,
  "native_library_bench_expected_rows": 0,
  "native_library_bench_positive_rows": 0,
  "native_library_bench_throughput_rows": 0,
  "native_library_bench_iteration_rows": 0,
  "native_library_bench_improvement_checks": 0,
  "native_library_bench_expected_improvement_checks": 0,
  "native_library_bench_missing_pairs": [],
  "fuzz_corpus_present": false,
  "fuzz_corpus_ok": false,
  "fuzz_corpus_coverage_present": false,
  "fuzz_corpus_coverage_ok": false,
  "fuzz_corpus_markdown_present": false,
  "fuzz_corpus_healthy": false,
  "fuzz_corpus_cases": 0,
  "fuzz_corpus_accepted": 0,
  "fuzz_corpus_rejected": 0,
  "fuzz_corpus_report_rows": 0,
  "fuzz_corpus_report_count_mismatch": 0,
  "fuzz_corpus_matched_rows": 0,
  "fuzz_corpus_unmatched_rows": 0,
  "fuzz_corpus_exact_error_expectations": 0,
  "fuzz_corpus_mode_count_rows": 0,
  "fuzz_corpus_error_count_rows": 0,
  "fuzz_corpus_coverage_mode_requirements": 0,
  "fuzz_corpus_coverage_error_requirements": 0,
  "fuzz_corpus_coverage_mode_matched": 0,
  "fuzz_corpus_coverage_error_matched": 0,
  "fuzz_corpus_coverage_unmatched": 0,
  "fuzz_corpus_markdown_rows": 0,
  "fuzz_corpus_markdown_matched": 0,
  "fuzz_corpus_markdown_unmatched": 0,
  "decode_stage_present": false,
  "decode_stage_ok": false,
  "decode_stage_healthy": false,
  "decode_stage_rows": 0,
  "decode_stage_error_rows": 0,
  "decode_stage_report_rows": 0,
  "decode_stage_error_item_rows": 0,
  "decode_stage_report_count_mismatch": 0,
  "decode_stage_matched_error_rows": 0,
  "decode_stage_unmatched_error_rows": 0,
  "decode_stage_csv_present": false,
  "decode_stage_csv_rows": 0,
  "decode_stage_csv_positive_rows": 0,
  "decode_stage_csv_header_rows": 0,
  "decode_stage_csv_dynamic_rows": 0,
  "decode_stage_csv_fixed_rows": 0,
  "decode_stage_csv_stored_rows": 0,
  "decode_stage_csv_missing_cases": [],
  "decode_stage_markdown_present": false,
  "decode_stage_markdown_rows": 0,
  "decode_stage_markdown_matched": 0,
  "decode_stage_markdown_unmatched": 0,
  "native_fuzz_corpus_present": false,
  "native_fuzz_corpus_coverage_present": false,
  "native_fuzz_corpus_markdown_present": false,
  "native_fuzz_corpus_healthy": false,
  "native_fuzz_corpus_cases": 0,
  "native_fuzz_corpus_accepted": 0,
  "native_fuzz_corpus_rejected": 0,
  "native_fuzz_corpus_report_rows": 0,
  "native_fuzz_corpus_report_count_mismatch": 0,
  "native_fuzz_corpus_matched_rows": 0,
  "native_fuzz_corpus_unmatched_rows": 0,
  "native_fuzz_corpus_exact_error_expectations": 0,
  "native_fuzz_corpus_mode_count_rows": 0,
  "native_fuzz_corpus_error_count_rows": 0,
  "native_fuzz_corpus_coverage_mode_requirements": 0,
  "native_fuzz_corpus_coverage_error_requirements": 0,
  "native_fuzz_corpus_coverage_mode_matched": 0,
  "native_fuzz_corpus_coverage_error_matched": 0,
  "native_fuzz_corpus_coverage_unmatched": 0,
  "native_fuzz_corpus_markdown_rows": 0,
  "native_fuzz_corpus_markdown_matched": 0,
  "native_fuzz_corpus_markdown_unmatched": 0,
  "br_static_dictionary_present": false,
  "br_static_dictionary_candidate_markdown_present": false,
  "br_static_dictionary_candidate_markdown_summary_rows": 0,
  "br_static_dictionary_candidate_markdown_matched": 0,
  "br_static_dictionary_candidate_markdown_unmatched": 0,
  "br_static_dictionary_candidate_markdown_sample_rows": 0,
  "br_static_dictionary_candidate_markdown_sample_matched": 0,
  "br_static_dictionary_candidate_markdown_sample_unmatched": 0,
  "br_static_dictionary_upstream_present": false,
  "br_static_dictionary_upstream_report_present": false,
  "br_static_dictionary_upstream_report_candidate_count": 0,
  "br_static_dictionary_upstream_report_raw_word_count": 0,
  "br_static_dictionary_upstream_report_upstream_raw_word_count": 0,
  "br_static_dictionary_upstream_markdown_present": false,
  "br_static_dictionary_upstream_markdown_summary_rows": 0,
  "br_static_dictionary_upstream_markdown_matched": 0,
  "br_static_dictionary_upstream_markdown_unmatched": 0,
  "br_static_dictionary_upstream_markdown_sample_rows": 0,
  "br_static_dictionary_upstream_markdown_sample_matched": 0,
  "br_static_dictionary_upstream_markdown_sample_unmatched": 0,
  "br_static_dictionary_node_present": false,
  "br_static_dictionary_node_markdown_present": false,
  "br_static_dictionary_node_markdown_summary_rows": 0,
  "br_static_dictionary_node_markdown_matched": 0,
  "br_static_dictionary_node_markdown_unmatched": 0,
  "br_static_dictionary_node_markdown_rows": 0,
  "br_static_dictionary_node_markdown_matched_rows": 0,
  "br_static_dictionary_node_markdown_unmatched_rows": 0,
  "br_static_dictionary_audit_present": false,
  "br_static_dictionary_negative_present": false,
  "br_static_dictionary_healthy": false,
  "br_static_dictionary_candidate_count": 0,
  "br_static_dictionary_raw_word_count": 0,
  "br_static_dictionary_upstream_candidate_count": 0,
  "br_static_dictionary_upstream_raw_word_count": 0,
  "br_static_dictionary_node_probed_count": 0,
  "br_static_dictionary_node_decode_successes": 0,
  "br_static_dictionary_node_size_winner_count": 0,
  "br_static_dictionary_audit_entry_count": 0,
  "br_static_dictionary_audit_anchor_count": 0,
  "br_static_dictionary_audit_generated_zig_bytes": 0,
  "br_static_dictionary_negative_case_count": 0,
  "br_static_dictionary_negative_matched": 0,
  "br_static_dictionary_report_present": false,
  "br_static_dictionary_report_csv_present": false,
  "br_static_dictionary_report_markdown_present": false,
  "br_static_dictionary_report_negative_present": false,
  "br_static_dictionary_core_healthy": false,
  "br_static_dictionary_report_healthy": false,
  "br_static_dictionary_report_entry_count": 0,
  "br_static_dictionary_report_json_entries": 0,
  "br_static_dictionary_report_transform_count": 0,
  "br_static_dictionary_report_length_count": 0,
  "br_static_dictionary_report_identity_count": 0,
  "br_static_dictionary_report_transform_entry_count": 0,
  "br_static_dictionary_report_phrase_count": 0,
  "br_static_dictionary_report_category_total": 0,
  "br_static_dictionary_report_category_mismatch_rows": 0,
  "br_static_dictionary_report_matrix_rows": 0,
  "br_static_dictionary_report_matrix_total": 0,
  "br_static_dictionary_report_matrix_mismatch_rows": 0,
  "br_static_dictionary_report_csv_rows": 0,
  "br_static_dictionary_report_csv_matched": 0,
  "br_static_dictionary_report_csv_unmatched": 0,
  "br_static_dictionary_report_markdown_summary_rows": 0,
  "br_static_dictionary_report_markdown_matched": 0,
  "br_static_dictionary_report_markdown_unmatched": 0,
  "br_static_dictionary_report_markdown_matrix_rows": 0,
  "br_static_dictionary_report_markdown_matrix_matched": 0,
  "br_static_dictionary_report_markdown_matrix_unmatched": 0,
  "br_static_dictionary_report_markdown_entry_rows": 0,
  "br_static_dictionary_report_markdown_entry_matched": 0,
  "br_static_dictionary_report_markdown_entry_unmatched": 0,
  "br_static_dictionary_report_negative_case_count": 0,
  "br_static_dictionary_report_negative_matched": 0,
  "br_static_dictionary_report_negative_unmatched": 0,
  "png_scratch_present": false,
  "png_scratch_markdown_present": false,
  "png_scratch_healthy": false,
  "png_scratch_case_count": 0,
  "png_scratch_report_rows": 0,
  "png_scratch_report_count_mismatch": 0,
  "png_scratch_row_consistent_count": 0,
  "png_scratch_row_inconsistent_count": 0,
  "png_scratch_adam7_cases": 0,
  "png_scratch_stored_achieved": 0,
  "png_scratch_fixed_achieved": 0,
  "png_scratch_total_zlib_scratch": 0,
  "png_scratch_total_streaming_savings": 0,
  "png_scratch_max_working_scratch": 0,
  "png_scratch_max_streaming_working_scratch": 0,
  "png_scratch_max_fixed_dynamic_streaming_working_scratch": 0,
  "png_scratch_min_streaming_ratio": 0,
  "png_scratch_markdown_rows": 0,
  "png_scratch_markdown_matched": 0,
  "png_scratch_markdown_unmatched": 0,
  "zlib_relaxed_present": false,
  "zlib_relaxed_markdown_present": false,
  "zlib_relaxed_healthy": false,
  "zlib_relaxed_gate_present": false,
  "zlib_relaxed_gate_ok": false,
  "zlib_relaxed_gate_check_count": 0,
  "zlib_relaxed_gate_expected_checks": 0,
  "zlib_relaxed_gate_passed_count": 0,
  "zlib_relaxed_gate_failed_checks": [],
  "zlib_relaxed_gate_report_matched": 0,
  "zlib_relaxed_gate_report_unmatched": 0,
  "zlib_relaxed_strict_rejections": 0,
  "zlib_relaxed_successes": 0,
  "zlib_relaxed_dictionary_successes": 0,
  "zlib_relaxed_concatenated_successes": 0,
  "zlib_relaxed_decoder_successes": 0,
  "zlib_relaxed_limited_rejections": 0,
  "gzip_relaxed_strict_rejections": 0,
  "gzip_relaxed_successes": 0,
  "gzip_relaxed_concatenated_successes": 0,
  "gzip_relaxed_decoder_successes": 0,
  "gzip_relaxed_limited_rejections": 0,
  "zlib_relaxed_markdown_rows": 0,
  "zlib_relaxed_markdown_matched": 0,
  "zlib_relaxed_markdown_unmatched": 0,
  "snappy_report_present": false,
  "snappy_report_healthy": false,
  "snappy_report_rows": 0,
  "snappy_report_expected_rows": 0,
  "snappy_report_positive_timing_rows": 0,
  "snappy_report_ratio_rows": 0,
  "snappy_report_throughput_rows": 0,
  "snappy_report_repetitive_shrunk_rows": 0,
  "snappy_report_reusable_size_matched_cases": 0,
  "snappy_report_reusable_checksum_matched_cases": 0,
  "snappy_report_missing_pairs": [],
  "zstd_compare_present": false,
  "zstd_compare_standard_present": false,
  "zstd_compare_block_sweep_present": false,
  "zstd_compare_healthy": false,
  "zstd_compare_rows": 0,
  "zstd_compare_standard_rows": 0,
  "zstd_compare_block_sweep_rows": 0,
  "zstd_compare_native_ratio": 0.0,
  "zstd_compare_native_stream_ratio": 0.0,
  "zstd_compare_standard_native_ratio": 0.0,
  "zstd_compare_standard_native_stream_ratio": 0.0,
  "zstd_compare_decode_vs_zstd": 0.0,
  "zstd_compare_standard_decode_vs_zstd": 0.0,
  "zstd_compare_best_block_len": 0,
  "zstd_compare_best_range_decode_mib_s": 0.0,
  "zstd_compare_best_range_decode_full_input_mib_s": 0.0,
  "zstd_compare_csv_present_count": 0,
  "zstd_compare_csv_expected_present_count": 0,
  "zstd_compare_csv_rows": 0,
  "zstd_compare_csv_expected_rows": 0,
  "zstd_compare_csv_matched_rows": 0,
  "zstd_compare_csv_unmatched_rows": 0,
  "zstd_compare_markdown_present_count": 0,
  "zstd_compare_markdown_expected_present_count": 0,
  "zstd_compare_markdown_summary_rows": 0,
  "zstd_compare_markdown_matched": 0,
  "zstd_compare_markdown_unmatched": 0,
  "zstd_compare_markdown_detail_rows": 0,
  "zstd_compare_markdown_detail_matched": 0,
  "zstd_compare_markdown_detail_unmatched": 0,
  "native_allocation_present": false,
  "native_allocation_smoke_present": false,
  "native_allocation_negative_present": false,
  "native_allocation_markdown_present": false,
  "native_allocation_healthy": false,
  "native_allocation_report_case_count": 0,
  "native_allocation_report_rows": 0,
  "native_allocation_report_count_mismatch": 0,
  "native_allocation_report_balanced_rows": 0,
  "native_allocation_report_duplicate_cases": 0,
  "native_allocation_report_unbalanced_rows": 0,
  "native_allocation_required_zero_allocation_cases": 0,
  "native_allocation_zero_allocation_matched": 0,
  "native_allocation_zero_report_matched": 0,
  "native_allocation_zero_report_unmatched": 0,
  "native_allocation_required_budget_cases": 0,
  "native_allocation_budget_matched": 0,
  "native_allocation_budget_report_matched": 0,
  "native_allocation_budget_report_unmatched": 0,
  "native_allocation_smoke_classified_cases": 0,
  "native_allocation_smoke_classification_overlap": 0,
  "native_allocation_smoke_classification_missing": 0,
  "native_allocation_smoke_classification_extra": 0,
  "native_allocation_negative_case_count": 0,
  "native_allocation_negative_matched": 0,
  "native_allocation_negative_unmatched": 0,
  "native_allocation_markdown_rows": 0,
  "native_allocation_markdown_matched": 0,
  "native_allocation_markdown_unmatched": 0,
  "python_zlib_diff_present": false,
  "python_zlib_diff_ok": false,
  "python_zlib_diff_healthy": false,
  "python_zlib_diff_payloads": 0,
  "python_zlib_diff_large_file_payloads": 0,
  "python_zlib_diff_file_hex_encode_cases": 0,
  "python_zlib_diff_match_heavy_payloads": 0,
  "python_zlib_diff_dynamic_payloads": 0,
  "python_zlib_diff_dictionary_cases": 0,
  "python_zlib_diff_zlib_dict_encode_cases": 0,
  "python_zlib_diff_raw_dict_encode_cases": 0,
  "python_zlib_diff_dictionary_encode_cases": 0,
  "python_zlib_diff_malformed_wrapper_cases": 0,
  "python_zlib_diff_malformed_deflate_cases": 0,
  "python_zlib_diff_malformed_cases": 0,
  "python_zlib_diff_cli_successes": 0,
  "python_zlib_diff_expected_failures": 0,
  "python_zlib_diff_cli_total_outcomes": 0,
  "python_zlib_diff_file_hex_expected_cases": 0,
  "python_zlib_diff_file_hex_case_mismatch": 0,
  "python_zlib_diff_cli_success_floor": 0,
  "python_zlib_diff_cli_success_shortfall": 0,
  "python_zlib_diff_expected_failure_floor": 0,
  "python_zlib_diff_expected_failure_shortfall": 0,
  "python_zlib_diff_cli_outcome_floor": 0,
  "python_zlib_diff_cli_outcome_shortfall": 0,
  "native_codec_probes_present": false,
  "native_codec_probes_ok": false,
  "native_codec_probes_markdown_present": false,
  "native_codec_probes_healthy": false,
  "native_codec_probes_probe_count": 0,
  "native_codec_probes_ok_probe_count": 0,
  "native_codec_probes_timed_out_probes": 0,
  "native_codec_probes_coverage_rows": 0,
  "native_codec_probes_coverage_ok_rows": 0,
  "native_codec_probes_coverage_case_sum": 0,
  "native_codec_probes_capability_count": 0,
  "native_codec_probes_ok_capability_count": 0,
  "native_codec_probes_lib_generated_cases": 0,
  "native_codec_probes_incremental_cases": 0,
  "native_codec_probes_chunked_cases": 0,
  "native_codec_probes_reusable_chunked_cases": 0,
  "native_codec_probes_fse_repeat_cases": 0,
  "native_codec_probes_dictionary_cases": 0,
  "native_codec_probes_malformed_cases": 0,
  "native_codec_probes_total_cases": 0,
  "native_codec_probes_zstd_frame_cases": 0,
  "native_codec_probes_zstd_dictionary_cases": 0,
  "native_codec_probes_markdown_rows": 0,
  "native_codec_probes_markdown_matched": 0,
  "native_codec_probes_markdown_unmatched": 0,
  "native_summary_error_present": false,
  "native_summary_error_healthy": false,
  "native_summary_error_case_count": 0,
  "native_summary_error_case_rows": 0,
  "native_summary_error_case_count_mismatch": 0,
  "native_summary_error_lz4_case_count": 0,
  "native_summary_error_zstd_case_count": 0,
  "native_summary_error_codec_case_count_mismatch": 0,
  "native_summary_error_checksum_mismatch_count": 0,
  "native_summary_error_corrupt_frame_count": 0,
  "native_summary_error_truncated_frame_count": 0,
  "native_summary_error_magic_phase_count": 0,
  "native_summary_error_skippable_payload_phase_count": 0,
  "native_summary_error_frame_body_phase_count": 0,
  "native_summary_error_frame_checksum_phase_count": 0,
  "native_summary_error_frame_phase_count": 0,
  "native_summary_error_error_counts": {},
  "native_summary_error_phase_counts": {},
  "native_summary_error_lz4_error_counts": {},
  "native_summary_error_zstd_error_counts": {},
  "native_summary_error_lz4_phase_counts": {},
  "native_summary_error_zstd_phase_counts": {},
  "native_summary_error_offset_min": 0,
  "native_summary_error_offset_max": 0,
  "native_summary_error_lz4_offset_min": 0,
  "native_summary_error_lz4_offset_max": 0,
  "native_summary_error_zstd_offset_min": 0,
  "native_summary_error_zstd_offset_max": 0,
  "native_summary_error_error_count_mismatch": 0,
  "native_summary_error_phase_count_mismatch": 0,
  "native_summary_error_codec_error_count_mismatch": 0,
  "native_summary_error_codec_phase_count_mismatch": 0,
  "native_summary_error_offset_range_mismatch": 0,
  "native_summary_error_phase_offset_ranges": {},
  "native_summary_error_required_codec_phases": {},
  "native_summary_error_lz4_missing_phases": [],
  "native_summary_error_zstd_missing_phases": [],
  "native_summary_error_negative_present": false,
  "native_summary_error_negative_healthy": false,
  "native_summary_error_negative_case_count": 0,
  "lz4_native_summary_present": false,
  "lz4_native_summary_healthy": false,
  "lz4_native_summary_frame_count": 0,
  "lz4_native_summary_skippable_frame_count": 0,
  "lz4_native_summary_checksum_frame_count": 0,
  "lz4_native_summary_block_checksum_frame_count": 0,
  "lz4_native_summary_dictionary_id_frame_count": 0,
  "lz4_native_summary_content_size_frame_count": 0,
  "lz4_native_summary_declared_content_bytes": 0,
  "lz4_native_summary_block_count": 0,
  "lz4_native_summary_raw_block_count": 0,
  "lz4_native_summary_compressed_block_count": 0,
  "lz4_native_summary_compressed_bytes": 0,
  "lz4_native_summary_payload_bytes": 0,
  "lz4_native_summary_skippable_payload_bytes": 0,
  "lz4_native_summary_block_count_mismatch": 0,
  "lz4_native_summary_declared_payload_slack_bytes": 0,
  "lz4_native_summary_metadata_frame_overflow": 0,
  "lz4_native_summary_checksum_frame_overflow": 0,
  "lz4_native_summary_block_checksum_frame_overflow": 0,
  "zstd_native_summary_present": false,
  "zstd_native_summary_healthy": false,
  "zstd_native_summary_frame_count": 0,
  "zstd_native_summary_skippable_frame_count": 0,
  "zstd_native_summary_checksum_frame_count": 0,
  "zstd_native_summary_dictionary_id_frame_count": 0,
  "zstd_native_summary_content_size_frame_count": 0,
  "zstd_native_summary_declared_content_bytes": 0,
  "zstd_native_summary_block_count": 0,
  "zstd_native_summary_raw_block_count": 0,
  "zstd_native_summary_rle_block_count": 0,
  "zstd_native_summary_compressed_block_count": 0,
  "zstd_native_summary_compressed_bytes": 0,
  "zstd_native_summary_payload_bytes": 0,
  "zstd_native_summary_skippable_payload_bytes": 0,
  "zstd_native_summary_block_count_mismatch": 0,
  "zstd_native_summary_declared_payload_slack_bytes": 0,
  "zstd_native_summary_metadata_frame_overflow": 0,
  "zstd_native_summary_checksum_frame_overflow": 0,
  "zstd_native_summary_block_checksum_frame_overflow": 0,
  "native_tier_range_present": true,
  "native_tier_range_healthy": true,
  "native_tier_range_summary_count": 3,
  "native_tier_range_ok_count": 3,
  "native_tier_range_rows": 24,
  "native_tier_range_fixture_count": 8,
  "native_tier_range_enforced_count": 1,
  "native_tier_range_csv_present_count": 3,
  "native_tier_range_csv_healthy_count": 3,
  "native_tier_range_csv_rows": 24,
  "native_tier_range_csv_positive_rows": 24,
  "native_tier_range_csv_shape_rows": 24,
  "native_tier_range_csv_throughput_rows": 24,
  "native_tier_range_csv_missing_sources": [],
  "native_tier_range_csv_missing_pairs": [],
  "native_tier_range_built_in_summary_count": 1,
  "native_tier_range_project_files_summary_count": 1,
  "native_tier_range_standard_corpus_summary_count": 1,
  "native_tier_range_custom_summary_count": 0,
  "native_tier_range_legacy_summary_count": 0,
  "native_tier_range_built_in_rows": 9,
  "native_tier_range_project_files_rows": 6,
  "native_tier_range_standard_corpus_rows": 9,
  "native_tier_range_custom_rows": 0,
  "native_tier_range_legacy_rows": 0,
  "native_tier_range_missing_sources": [],
  "native_tier_range_source_count_mismatch": 0,
  "native_tier_range_summary_csv_row_mismatch": 0,
  "native_tier_range_summary_csv_fixture_mismatch": 0,
  "native_tier_range_summary_csv_tier_mismatch": 0,
  "native_tier_range_summary_csv_path_mismatch": 0,
  "native_tier_range_summary_csv_stream_bytes_mismatch": 0,
  "native_tier_range_summary_csv_index_entries_mismatch": 0,
  "native_tier_range_summary_csv_min_range_mismatch": 0,
  "native_tier_range_summary_csv_min_full_mismatch": 0,
  "native_tier_range_summary_csv_mismatch_total": 0,
  "native_tier_corpus_discovery_present": false,
  "native_tier_corpus_discovery_ok": false,
  "native_tier_corpus_discovery_healthy": false,
  "native_tier_corpus_discovery_source_mode": "",
  "native_tier_corpus_discovery_full": false,
  "native_tier_corpus_discovery_limit": null,
  "native_tier_corpus_discovery_candidate_count": 0,
  "native_tier_corpus_discovery_source_count": 0,
  "native_tier_corpus_discovery_sources": [],
  "native_tier_corpus_discovery_selected_case_count": 0,
  "native_tier_corpus_discovery_selected_cases": [],
  "native_tier_corpus_discovery_csv": "",
  "native_tier_corpus_discovery_missing_reason": "missing_discovery_artifact",
  "native_tier_corpus_discovery_selected_case_mismatch": 0,
  "native_tier_corpus_discovery_csv_path_mismatch": 0,
  "native_tier_corpus_discovery_summary_fixture_mismatch": 0,
  "native_tier_corpus_discovery_csv_fixture_mismatch": 0,
  "native_tier_corpus_discovery_csv_byte_mismatch": 0,
  "native_tier_corpus_discovery_mismatch_total": 0,
  "native_tier_range_source_details": [
    {
      "source": "built_in",
      "summary_count": 1,
      "ok_count": 1,
      "rows": 9,
      "fixture_count": 3,
      "enforced_count": 1,
      "missing": false,
      "min_range_mib_s_by_tier": {
        "seek_fast": 87.39,
        "balanced": 26.48,
        "ratio": 24.0
      },
      "range_mib_s_floor_by_tier": {
        "seek_fast": 60.0,
        "balanced": 16.0,
        "ratio": 12.0
      }
    },
    {
      "source": "project_files",
      "summary_count": 1,
      "ok_count": 1,
      "rows": 6,
      "fixture_count": 2,
      "enforced_count": 1,
      "missing": false,
      "min_range_mib_s_by_tier": {
        "seek_fast": 52.58,
        "balanced": 12.29,
        "ratio": 5.65
      },
      "range_mib_s_floor_by_tier": {
        "seek_fast": 40.0,
        "balanced": 8.0,
        "ratio": 4.0
      }
    },
    {
      "source": "standard_corpus",
      "summary_count": 1,
      "ok_count": 1,
      "rows": 9,
      "fixture_count": 3,
      "enforced_count": 1,
      "missing": false,
      "min_range_mib_s_by_tier": {
        "seek_fast": 37.93,
        "balanced": 8.51,
        "ratio": 4.15
      },
      "range_mib_s_floor_by_tier": {
        "seek_fast": 30.0,
        "balanced": 6.5,
        "ratio": 3.5
      }
    },
    {
      "source": "custom",
      "summary_count": 0,
      "ok_count": 0,
      "rows": 0,
      "fixture_count": 0,
      "enforced_count": 0,
      "missing": false,
      "min_range_mib_s_by_tier": {
        "seek_fast": 0.0,
        "balanced": 0.0,
        "ratio": 0.0
      },
      "range_mib_s_floor_by_tier": {
        "seek_fast": 0.0,
        "balanced": 0.0,
        "ratio": 0.0
      }
    },
    {
      "source": "legacy",
      "summary_count": 0,
      "ok_count": 0,
      "rows": 0,
      "fixture_count": 0,
      "enforced_count": 0,
      "missing": false,
      "min_range_mib_s_by_tier": {
        "seek_fast": 0.0,
        "balanced": 0.0,
        "ratio": 0.0
      },
      "range_mib_s_floor_by_tier": {
        "seek_fast": 0.0,
        "balanced": 0.0,
        "ratio": 0.0
      }
    }
  ],
  "native_tier_range_seek_fast_min_range_mib_s": 52.58,
  "native_tier_range_balanced_min_range_mib_s": 12.29,
  "native_tier_range_ratio_min_range_mib_s": 5.65,
  "native_tier_range_seek_fast_min_full_input_mib_s": 732.08,
  "native_tier_range_balanced_min_full_input_mib_s": 257.77,
  "native_tier_range_ratio_min_full_input_mib_s": 179.72,
  "artifacts": [
    {
      "name": "vort-validation-json-smoke.json",
      "path": "vort-validation-json-smoke.json",
      "category": "validation",
      "format": "json",
      "expected_format": "json",
      "producer_step": "zig build run-validation-json-dashboard",
      "producer_missing_allowed": false,
      "smoke_gate": "zig build run-validation-json-dashboard",
      "required_workflow_count": null,
      "missing_workflow_count": null,
      "size_bytes": 349,
      "mtime_utc": "2026-07-13T11:00:55Z",
      "schema": "vort.validation_json_smoke",
      "schema_version": 1,
      "ok": true
    }
  ]
}
```

## `vort.dashboard_strict_expected_modes`

Consumed by:

```sh
python3 tools/dashboard_strict_smoke.py
zig build run-dashboard-strict-smoke
```

This schema defines the required per-mode coverage matrix for dashboard strict
mode smoke tests. Keeping it external makes strict-gate coverage expectations
reviewable without editing the smoke script logic. The docs checker cross-checks
this config against the dashboard strict smoke mode enums in
`tools/validation_json_schema_manifest.json` so mode expectations cannot drift
silently.

Example:

```json
{
  "schema": "vort.dashboard_strict_expected_modes",
  "schema_version": 1,
  "expected_modes": [
    {
      "mode": "dashboard-markdown",
      "min_checks": 20,
      "min_expected_failures": 0,
      "min_matched": 20
    },
    {
      "mode": "strict-validation-health",
      "min_checks": 87,
      "min_expected_failures": 87,
      "min_matched": 87
    },
    {
      "mode": "native-tier-range-health",
      "min_checks": 5,
      "min_expected_failures": 0,
      "min_matched": 5
    }
  ]
}
```

## `vort.dashboard_strict_validation_reasons`

Consumed by:

```sh
python3 tools/dashboard_strict_smoke.py
zig build run-dashboard-strict-smoke
```

This schema defines the required fine-grained `--strict-validation-health`
negative fixture matrix for dashboard strict smoke tests. Keeping it external
makes reason coverage reviewable without editing the smoke script. The docs
checker validates this config against both
`vort.dashboard_index.validation_unhealthy_reasons` and the
`vort.dashboard_strict_smoke.validation_unhealthy_reason_checks` enums so every
published unhealthy reason has a configured check name and fixture strategy.

Example:

```json
{
  "schema": "vort.dashboard_strict_validation_reasons",
  "schema_version": 1,
  "expected_reasons": [
    {
      "reason": "missing_lz4_native_summary_artifact",
      "check": "validation_missing_lz4_native_summary_artifact",
      "fixture": "missing_lz4_native_summary_artifact"
    },
    {
      "reason": "lz4_native_summary_undercovered",
      "check": "validation_lz4_native_summary_undercovered",
      "fixture": "lz4_native_summary_undercovered"
    },
    {
      "reason": "missing_zstd_native_summary_artifact",
      "check": "validation_missing_zstd_native_summary_artifact",
      "fixture": "missing_zstd_native_summary_artifact"
    },
    {
      "reason": "missing_dashboard_configuration_artifact",
      "check": "validation_missing_dashboard_configuration_artifact",
      "fixture": "missing_dashboard_configuration_artifact"
    },
    {
      "reason": "dashboard_configuration_failed",
      "check": "validation_dashboard_configuration_failed",
      "fixture": "dashboard_configuration_failed"
    },
    {
      "reason": "missing_validation_json_smoke_artifact",
      "check": "validation_missing_validation_json_smoke_artifact",
      "fixture": "missing_validation_json_smoke_artifact"
    }
  ]
}
```

## `vort.dashboard_strict_smoke`

Produced by:

```sh
zig build run-dashboard-strict-dashboard
python3 tools/dashboard_strict_smoke.py --summary zig-out/vort-dashboard-strict-smoke.json --markdown zig-out/vort-dashboard-strict-smoke.md
```

This schema summarizes positive and negative smoke checks for dashboard strict
modes: producer coverage, smoke-gate coverage, header-inspection health,
native-tier range health-field coverage, dashboard Markdown review-surface
coverage, and aggregate validation-health failures. Each check records the expected output
marker, actual truncated output, original output length, truncation limit/flag,
and process return code for CI diagnostics. `mode_counts` groups checks by
strict mode for a compact dashboard overview, while `expected_modes` defines the
minimum required coverage per strict mode, `mode_requirements` reports
actual/minimum/delta values, and `missing_modes` reports unmet requirements.
`validation_unhealthy_reason_checks` records one isolated negative fixture for
each `vort.dashboard_index.validation_unhealthy_reasons` enum value so new
aggregate health reasons must be backed by real failing dashboard inputs before
the smoke artifact can pass. The expected reason/check/fixture matrix lives in
`tools/dashboard_strict_validation_reasons.json`; the retained
`strict-validation-health` mode minimums must cover every configured reason,
currently 87. Dashboard aggregate health also reads the retained
`vort-dashboard-strict-smoke.md` companion and requires its mode, requirement,
validation-reason, and check rows to match the JSON counts before
`dashboard_strict_healthy` can pass. The `dashboard-markdown` mode verifies that important human-facing
sections, including artifact inventory, aggregate validation health, producer/smoke-gate
coverage, dashboard strict gate coverage, dashboard configuration coverage, validation JSON schema coverage, header inspect coverage, corrupt-sidecar
rejection coverage, Huffman optimality, compression level report coverage, dynamic plan CSV coverage, deflate extra-bit benchmark coverage, dictionary decode benchmark coverage, PNG scanline benchmark coverage, chunked zlib benchmark coverage, PNG streaming zlib benchmark coverage, deflate dynamic decode profile coverage, native library benchmark coverage, zstd comparison gate coverage, native fuzz corpus coverage, static dictionary coverage, PNG scratch coverage, zlib relaxed compatibility coverage, native allocation coverage, Python zlib
differential coverage, decode-stage error matching, fuzz corpus matching, native
stream metadata coverage, native tier corpus discovery, native summary error
codec/phase-offset tables, native codec probe coverage/capability tables, and
the native-tier range source table, remain present in the generated dashboard
index. The abbreviated example below shows a
one-reason slice. A synthetic long-output check keeps the truncation path
covered so `actual_output_truncated=true` is exercised in CI.

Example:

```json
{
  "schema": "vort.dashboard_strict_smoke",
  "schema_version": 1,
  "ok": true,
  "check_count": 26,
  "mode_count": 4,
  "expected_mode_count": 4,
  "missing_mode_count": 0,
  "validation_unhealthy_reason_count": 1,
  "expected_modes": [
    {
      "mode": "all",
      "min_checks": 1,
      "min_expected_failures": 0,
      "min_matched": 1
    },
    {
      "mode": "dashboard-markdown",
      "min_checks": 20,
      "min_expected_failures": 0,
      "min_matched": 20
    },
    {
      "mode": "strict-validation-health",
      "min_checks": 87,
      "min_expected_failures": 87,
      "min_matched": 87
    },
    {
      "mode": "native-tier-range-health",
      "min_checks": 5,
      "min_expected_failures": 0,
      "min_matched": 5
    }
  ],
  "missing_modes": [],
  "mode_requirements": [
    {
      "mode": "all",
      "checks": 1,
      "min_checks": 1,
      "missing_checks": 0,
      "expected_failures": 0,
      "min_expected_failures": 0,
      "missing_expected_failures": 0,
      "matched": 1,
      "min_matched": 1,
      "missing_matched": 0
    },
    {
      "mode": "dashboard-markdown",
      "checks": 23,
      "min_checks": 20,
      "missing_checks": 0,
      "expected_failures": 0,
      "min_expected_failures": 0,
      "missing_expected_failures": 0,
      "matched": 23,
      "min_matched": 20,
      "missing_matched": 0
    },
    {
      "mode": "strict-validation-health",
      "checks": 1,
      "min_checks": 87,
      "missing_checks": 86,
      "expected_failures": 1,
      "min_expected_failures": 87,
      "missing_expected_failures": 86,
      "matched": 1,
      "min_matched": 87,
      "missing_matched": 86
    },
    {
      "mode": "native-tier-range-health",
      "checks": 1,
      "min_checks": 5,
      "missing_checks": 4,
      "expected_failures": 0,
      "min_expected_failures": 0,
      "missing_expected_failures": 0,
      "matched": 1,
      "min_matched": 5,
      "missing_matched": 4
    }
  ],
  "mode_counts": [
    {
      "mode": "all",
      "checks": 1,
      "expected_failures": 0,
      "matched": 1
    },
    {
      "mode": "dashboard-markdown",
      "checks": 23,
      "expected_failures": 0,
      "matched": 23
    },
    {
      "mode": "strict-validation-health",
      "checks": 1,
      "expected_failures": 1,
      "matched": 1
    },
    {
      "mode": "native-tier-range-health",
      "checks": 1,
      "expected_failures": 0,
      "matched": 1
    }
  ],
  "checks": [
    {
      "name": "all_strict_ok",
      "mode": "all",
      "expected_failure": false,
      "expected_output": "dashboard_index=",
      "actual_output": "dashboard_index=zig-out/vort-dashboard-index.md ...",
      "actual_output_bytes": 45,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "dashboard_artifact_inventory_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "dashboard artifact inventory markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "validation_unhealthy_reasons_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "validation unhealthy reasons markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "producer_smoke_gate_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "producer smoke gate markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "dashboard_strict_mode_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "dashboard strict mode markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "dashboard_configuration_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "dashboard configuration markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "validation_json_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "validation json schema markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "native_summary_success_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "native summary success markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "native_summary_error_markdown_tables",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "native summary error markdown tables",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "native_tier_range_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "native tier range markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "native_tier_discovery_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "native tier discovery markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "native_codec_probe_markdown_tables",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "native codec probe markdown tables",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "header_inspect_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "header inspect markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "sidecar_corrupt_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "sidecar corrupt markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "huffman_length_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "huffman length markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "zstd_compare_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "zstd compare markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "native_fuzz_corpus_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "native fuzz corpus markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "static_dictionary_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "static dictionary markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "png_scratch_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "png scratch markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "zlib_relaxed_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "zlib relaxed markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "native_allocation_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "native allocation markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "python_zlib_diff_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "python zlib diff markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "decode_stage_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "decode stage markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "fuzz_corpus_markdown_table",
      "mode": "dashboard-markdown",
      "expected_failure": false,
      "expected_output": "fuzz corpus markdown table",
      "actual_output": "0:ok",
      "actual_output_bytes": 4,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "validation_missing_lz4_native_summary_artifact",
      "mode": "strict-validation-health",
      "expected_failure": true,
      "expected_output": "dashboard_index_validation_unhealthy=missing_lz4_native_summary_artifact",
      "actual_output": "dashboard_index_validation_unhealthy=missing_lz4_native_summary_artifact",
      "actual_output_bytes": 74,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 1,
      "matched": true
    },
    {
      "name": "missing_native_tier_range_summary",
      "mode": "native-tier-range-health",
      "expected_failure": false,
      "expected_output": "dashboard_index=",
      "actual_output": "dashboard_index=ok",
      "actual_output_bytes": 18,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    }
  ],
  "validation_unhealthy_reason_checks": [
    {
      "reason": "missing_lz4_native_summary_artifact",
      "check": "validation_missing_lz4_native_summary_artifact",
      "matched": true
    }
  ]
}
```

## `vort.dashboard_producers`

Consumed by:

```sh
zig build run-dashboard-index
python3 tools/dashboard_index.py --producer-map tools/dashboard_producers.json
```

This schema maps known dashboard artifact names to the build command that
regenerates them. The mapping is intentionally external to
`tools/dashboard_index.py` so new artifacts can be documented without changing
the scanner logic.

Top-level fields:

| field | type | meaning |
| --- | --- | --- |
| `schema` | string | Always `vort.dashboard_producers`. |
| `schema_version` | integer | Currently `1`. |
| `allow_missing` | object | Optional allowlist for temporary artifacts without producer mappings. |
| `artifact_metadata` | object | Optional per-artifact metadata such as expected format and smoke gate. |
| `exact` | object | Map from exact artifact filename to producer command. |
| `contains` | array | Ordered fallback rules for filename substring matches. |
| `required_smoke_gates` | array | Artifact filenames that must have a non-empty `smoke_gate` when strict smoke-gate checks run. |

Each `contains` rule has:

| field | type | meaning |
| --- | --- | --- |
| `match` | string | Substring to search for in the artifact filename. |
| `producer_step` | string | Command shown in the Markdown index and JSON manifest. |

Producer resolution order:

1. Exact filename match in `exact`.
2. First matching rule in `contains`.
3. Built-in fallback mappings in `tools/dashboard_index.py`.
4. Empty `producer_step` when no rule matches.

Strict producer coverage ignores missing mappings that match
`allow_missing.exact` or `allow_missing.contains`, but still records them in the
dashboard manifest as `producer_missing_allowed=true`.
When `artifact_metadata.<name>.expected_format` is present, the dashboard index
checks it against the artifact filename suffix. `smoke_gate` is copied into the
dashboard manifest to show the validation command associated with that artifact.
`required_smoke_gates` drives `--strict-smoke-gates`, causing dashboard index
generation to fail when a required artifact is absent or lacks a smoke gate.
`tools/dashboard_producers_required_artifacts.json` is a schema-checked coverage
matrix for exact producer mappings; `zig build run-dashboard-producers-required-smoke`
verifies that every configured artifact still has matching producer, format, and
smoke-gate metadata.

Example:

```json
{
  "schema": "vort.dashboard_producers",
  "schema_version": 1,
  "allow_missing": {
    "exact": [],
    "contains": [
      "scratch"
    ]
  },
  "required_smoke_gates": [
    "vort-validation-json-smoke.json"
  ],
  "artifact_metadata": {
    "vort-validation-json-smoke.json": {
      "expected_format": "json",
      "smoke_gate": "zig build run-validation-json-dashboard"
    }
  },
  "exact": {
    "vort-validation-json-smoke.json": "zig build run-validation-json-dashboard"
  },
  "contains": [
    {
      "match": "native-parallel",
      "producer_step": "zig build -Doptimize=ReleaseFast bench-native-parallel"
    }
  ]
}
```

## `vort.native_allocation_report`

Produced by:

```sh
zig build run-native-allocation-report-dashboard
```

This report records allocator activity for representative native decode paths so
caller-owned APIs and allocation preflight optimizations have a retained
regression baseline. It includes AnyDecoder, ZlibDecoder, GzipDecoder, deflate,
LDM, and dictionary-deflate range plus validation rows that prove caller-owned index,
payload, and patch scratch buffers
sized through the public range and validation preflight helpers keep full-frame,
embedded/sidecar partial, auto, and self-contained range decode plus embedded
and sidecar deflate/LDM validation/report-producing validation paths allocation-free.

Top-level fields:

| field | type | meaning |
| --- | --- | --- |
| `schema` | string | Always `vort.native_allocation_report`. |
| `schema_version` | integer | Currently `1`. |
| `case_count` | integer | Number of rows in `cases`. |
| `cases` | list | Allocation measurements for individual decode paths. |

Each `cases` item includes:

| field | type | meaning |
| --- | --- | --- |
| `case` | string | Stable case label. |
| `input_bytes` | integer | Encoded input size. |
| `output_bytes` | integer | Decoded output bytes, or zero for reject/validation cases. |
| `allocations` | integer | Allocation calls observed by the counting allocator. |
| `deallocations` | integer | Free calls observed by the counting allocator. |
| `allocated_bytes` | integer | Bytes allocated by the measured path. |
| `freed_bytes` | integer | Bytes freed by the measured path. |

Example:

```json
{
  "schema": "vort.native_allocation_report",
  "schema_version": 1,
  "case_count": 2,
  "cases": [
    {
      "case": "concat_alloc",
      "input_bytes": 79,
      "output_bytes": 49,
      "allocations": 1,
      "deallocations": 1,
      "allocated_bytes": 49,
      "freed_bytes": 49
    },
    {
      "case": "concat_into",
      "input_bytes": 79,
      "output_bytes": 49,
      "allocations": 0,
      "deallocations": 0,
      "allocated_bytes": 0,
      "freed_bytes": 0
    }
  ]
}
```

## `vort.native_allocation_smoke`

Produced by:

```sh
zig build run-native-allocation-smoke
```

Dashboard aggregate health also cross-checks the retained Markdown companion
against the JSON allocation report and verifies that smoke rows still match the
measured report rows. This smoke report gates the allocation report by requiring selected
caller-owned/native decode paths to remain zero-allocation, including AnyDecoder,
ZlibDecoder chunk/dictionary/varied-PNG scanline decode and PNG filter reconstruction,
the PNG zlib scanline row pipeline, fixed/dynamic contiguous/chunked streaming
PNG row and full-image decode, streaming Adam7 decode including sub-byte/RGBA16 rows, full-image PNG zlib decode including sub-byte rows,
PNG Adam7 metadata/placement and interlaced full-image decode/corrupt rejects including zlib wrapper failures and packed sub-byte/16-bit RGBA rows, GzipDecoder single-member and concatenated
chunk scratch decode, embedded and sidecar partial deflate/LDM range decode, embedded/sidecar
deflate/LDM validation, and dictionary-deflate range/validation with caller-owned
payload/patch scratch.

Top-level fields:

| field | type | meaning |
| --- | --- | --- |
| `schema` | string | Always `vort.native_allocation_smoke`. |
| `schema_version` | integer | Currently `1`. |
| `ok` | boolean | True when every required zero-allocation case matched. |
| `report` | string | Native allocation report path that was checked. |
| `required_zero_allocation_cases` | integer | Number of zero-allocation case rows checked. |
| `required_budget_cases` | integer | Number of allocation-budget case rows checked. |
| `cases` | list | Per-case zero-allocation gate results. |
| `budget_cases` | list | Per-case allocation-budget gate results. |

Each `cases` item includes:

| field | type | meaning |
| --- | --- | --- |
| `case` | string | Case label from the native allocation report. |
| `present` | boolean | Whether the case row existed in the report. |
| `allocations` | integer | Observed allocation count. |
| `deallocations` | integer | Observed deallocation count. |
| `allocated_bytes` | integer | Observed allocated byte count. |
| `freed_bytes` | integer | Observed freed byte count. |
| `matched` | boolean | True when the case was present and all allocation counters were zero. |

Each `budget_cases` item includes the same `case`, `present`, `allocations`,
`allocated_bytes`, and `matched` fields plus:

| field | type | meaning |
| --- | --- | --- |
| `max_allocations` | integer | Maximum allowed allocation calls for the case. |
| `max_deallocations` | integer | Maximum allowed deallocation calls for the case. |
| `max_allocated_bytes` | integer | Maximum allowed allocated bytes for the case. |
| `max_freed_bytes` | integer | Maximum allowed freed bytes for the case. |
| `balanced` | boolean | True when allocation/free counts and bytes match exactly. |

Example:

```json
{
  "schema": "vort.native_allocation_smoke",
  "schema_version": 1,
  "ok": true,
  "report": "zig-out/vort-native-allocation-report.json",
  "required_zero_allocation_cases": 1,
  "required_budget_cases": 1,
  "cases": [
    {
      "case": "concat_into",
      "present": true,
      "allocations": 0,
      "deallocations": 0,
      "allocated_bytes": 0,
      "freed_bytes": 0,
      "matched": true
    }
  ],
  "budget_cases": [
    {
      "case": "concat_alloc",
      "present": true,
      "allocations": 1,
      "deallocations": 1,
      "allocated_bytes": 49,
      "freed_bytes": 49,
      "max_allocations": 1,
      "max_deallocations": 1,
      "max_allocated_bytes": 49,
      "max_freed_bytes": 49,
      "balanced": true,
      "matched": true
    }
  ]
}
```

## `vort.zlib_relaxed_report`

Produced by:

```sh
zig build run-zlib-relaxed-report  # writes JSON and Markdown artifacts
zig build run-zlib-relaxed-report-gate
```

This schema records direct public-API coverage for relaxed zlib and gzip decode
options. Dashboard aggregate health cross-checks the retained Markdown metric
table and the gate checks against the JSON report before relaxed wrapper
coverage can pass. The report includes strict rejection, relaxed success, dictionary-aware zlib
decode, zlib/gzip concatenated decode, caller-owned `ZlibDecoder` and
`GzipDecoder` options coverage, and output-limit rejection behavior.

Example:

```json
{
  "schema": "vort.zlib_relaxed_report",
  "schema_version": 4,
  "strict_rejections": 2,
  "relaxed_successes": 5,
  "dictionary_successes": 2,
  "zlib_concatenated_successes": 3,
  "zlib_decoder_successes": 8,
  "limited_rejections": 1,
  "gzip_strict_rejections": 3,
  "gzip_relaxed_successes": 9,
  "gzip_concatenated_successes": 4,
  "gzip_decoder_successes": 4,
  "gzip_limited_rejections": 1
}
```

## `vort.zstd_compare_block_sweep_gate`

Produced by:

```sh
zig build run-zstd-compare-block-sweep-gate
```

This schema records the validation summary for retained native block-length
sweep artifacts. The gate validates the CSV field layout, requires one `TOTAL`
row per swept block length, verifies the complete path/block matrix, checks the
native-best, native-stream, and native-embedded byte/ratio math, verifies
centered range-decode timing aggregates, checks public seekability tier labels
for 8/32/64 KiB rows, and records the block length/tier that produced the
smallest total native stream in the smoke.

Example:

```json
{
  "schema": "vort.zstd_compare_block_sweep_gate",
  "schema_version": 1,
  "ok": true,
  "rows": 20,
  "data_rows": 15,
  "total_rows": 5,
  "path_count": 3,
  "block_len_count": 5,
  "block_lens": [
    4096,
    8192,
    16384,
    32768,
    65536
  ],
  "source_mode": "standard-suite",
  "size_mode": "bounded-128KiB",
  "case_limit": "3",
  "optimize": "Debug",
  "best_block_len": 65536,
  "best_seekability_tier": "ratio",
  "best_native_stream_bytes": 110784,
  "best_native_stream_ratio": 1.0077044125271746,
  "best_range_decode_mib_s": 0.9161919264686623,
  "best_range_decode_full_input_mib_s": 29.318141646997194,
  "best_stream_over_native_best": 1.0242319462293021,
  "best_stream_over_native_best_bytes": 2621,
  "best_embedded_over_native_stream": 1.0025996533795494,
  "best_embedded_over_native_stream_bytes": 288,
  "csv": "zig-out/vort-zstd-compare-block-sweep.csv",
  "markdown": "zig-out/vort-zstd-compare-block-sweep.md"
}
```

## `vort.zstd_compare_gate`

Produced by:

```sh
zig build run-zstd-compare-gate
zig build run-zstd-compare-standard-gate
zig build run-zstd-compare-standard-releasefast-gate
```

This schema records the validation summary for retained `vort-zstd-compare*`
CSV/Markdown artifacts. Dashboard aggregate health also cross-checks the retained CSV/Markdown companions against these gate summaries. The gate checks
the CSV schema, requires one `TOTAL` aggregate row, verifies the aggregate byte
and ratio math for raw fixed, single-frame native best, blocked native stream,
and embedded-index native stream Vort rows, verifies the stream-fragmentation
and embedded-index overhead split, verifies decode throughput aggregate math,
and verifies that Markdown output retains key run metadata and decode columns.

Example:

```json
{
  "schema": "vort.zstd_compare_gate",
  "schema_version": 1,
  "ok": true,
  "rows": 3,
  "data_rows": 2,
  "decode_repeats": 3,
  "native_block_len": 8192,
  "source_mode": "default-samples",
  "size_mode": "full",
  "case_limit": "none",
  "optimize": "Debug",
  "total_ratio": 1.029971390945007,
  "total_native_best_ratio": 1.0221379592207438,
  "total_native_stream_ratio": 1.1469279324281367,
  "total_native_ratio": 1.1658189909631715,
  "total_stream_over_native_best": 1.1220872114978786,
  "total_stream_over_native_best_bytes": 5496,
  "total_stream_over_native_best_pct": 12.20872114978786,
  "total_embedded_over_native_stream": 1.0164710074634253,
  "total_embedded_over_native_stream_bytes": 832,
  "total_embedded_over_native_stream_pct": 1.6471007463425336,
  "total_embedded_over_native_best": 1.1405691183330742,
  "total_embedded_over_native_best_bytes": 6328,
  "total_embedded_over_native_best_pct": 14.056911833307417,
  "total_zstd_decode_mib_s": 60.75841159051128,
  "total_vort_raw_fixed_decode_mib_s": 54.451816466413895,
  "total_vort_decode_vs_zstd": 0.8962021066876887,
  "total_vort_native_best_decode_mib_s": 42.214172386767345,
  "total_vort_native_best_decode_vs_zstd": 0.6947872941655372,
  "total_vort_native_decode_mib_s": 29.058765310493605,
  "total_vort_native_decode_vs_zstd": 0.47826736331322645,
  "csv": "zig-out/vort-zstd-compare.csv",
  "markdown": "zig-out/vort-zstd-compare.md"
}
```

## `vort.native_tier_range_bench_gate`

Produced by:

```sh
zig build run-native-tier-range-bench-gate
zig build run-native-tier-range-files-bench-gate
zig build run-native-tier-range-corpus-bench-gate
```

This schema records the validation summary for native seekability tier range
benchmark CSV artifacts. It captures the fixture/tier matrix size, whether
ReleaseFast throughput floors were enforced, per-tier minimum centered range
throughput, per-tier minimum full-input-equivalent throughput, and aggregate
stream/index sizes. The `source` field identifies whether a summary came from
the built-in smoke fixtures, project files, discoverable standard corpus rows,
or a caller-provided custom matrix; the dashboard uses these buckets to keep
seekability evidence from silently collapsing back to a single source.

Example:

```json
{
  "schema": "vort.native_tier_range_bench_gate",
  "schema_version": 1,
  "source": "project_files",
  "ok": true,
  "rows": 6,
  "fixture_count": 2,
  "tier_count": 3,
  "fixtures": [
    "README.md",
    "roadmap.md"
  ],
  "tiers": [
    "seek_fast",
    "balanced",
    "ratio"
  ],
  "enforce_throughput": true,
  "allow_any_fixtures": false,
  "min_range_mib_s_by_tier": {
    "seek_fast": 52.580107,
    "balanced": 12.292282,
    "ratio": 5.648135
  },
  "min_full_input_mib_s_by_tier": {
    "seek_fast": 732.078195,
    "balanced": 257.766141,
    "ratio": 179.718533
  },
  "range_mib_s_floor_by_tier": {
    "seek_fast": 40.0,
    "balanced": 8.0,
    "ratio": 4.0
  },
  "total_stream_bytes_by_tier": {
    "seek_fast": 51345,
    "balanced": 46313,
    "ratio": 45478
  },
  "total_index_entries_by_tier": {
    "seek_fast": 20,
    "balanced": 5,
    "ratio": 3
  },
  "csv": "zig-out/vort-native-tier-range-files-bench.csv"
}
```


## `vort.native_tier_range_corpus_discovery`

Produced by:

```sh
zig build run-native-tier-range-corpus-bench-gate
python3 tools/native_tier_range_corpus_report.py <bench-exe> --summary <out.json>
```

This schema records the corpus discovery side of the native tier range corpus
benchmark. It is intentionally separate from `vort.native_tier_range_bench_gate`:
the bench gate validates CSV shape and throughput, while this artifact explains
which standard-corpus paths were discovered, which bounded rows were selected,
and why the CSV was absent when no input cases were available. Dashboard health
cross-checks the selected labels and byte sizes against the retained
standard-corpus summary/CSV pair so stale discovery metadata cannot pass after
the benchmark matrix changes. `source_mode` is `discovered` for automatic local
standard-corpus discovery and `paths` when the caller supplies explicit
`--paths`.

Example:

```json
{
  "schema": "vort.native_tier_range_corpus_discovery",
  "schema_version": 1,
  "ok": true,
  "source_mode": "discovered",
  "full": false,
  "limit": 3,
  "candidate_count": 5,
  "source_count": 1,
  "sources": [
    "/home/passchaos/Work/zlib-rs/silesia-small.tar"
  ],
  "selected_case_count": 3,
  "selected_cases": [
    {
      "label": "ooffice-128k",
      "bytes": 131072
    },
    {
      "label": "nci-128k",
      "bytes": 131072
    },
    {
      "label": "mozilla-128k",
      "bytes": 131072
    }
  ],
  "csv": "zig-out/vort-native-tier-range-corpus-bench.csv",
  "missing_reason": ""
}
```

## `vort.png_scratch_report`

Produced by:

```sh
zig build run-png-scratch-report-dashboard
```

This report records caller-owned scratch and output footprint baselines for
representative PNG-like zlib decode paths. Dashboard aggregate health also
cross-checks the retained Markdown table against the JSON rows and verifies
per-row scratch arithmetic. It includes non-interlaced and Adam7
cases across RGB8, packed indexed rows, and RGBA16 so future incremental inflate
work can prove peak `zlib_scratch_bytes` reductions against a stable baseline.
The status columns make the milestone split explicit: stored-deflate scanline
streaming is already usable, and fixed/dynamic Huffman IDAT scanline streaming
is available for non-interlaced and Adam7 payloads, including chunked IDAT,
through the 32 KiB history-window decoder.

Top-level fields:

| field | type | meaning |
| --- | --- | --- |
| `schema` | string | Always `vort.png_scratch_report`. |
| `schema_version` | integer | Currently `1`. |
| `case_count` | integer | Number of rows in `cases`. |
| `cases` | list | Scratch footprint rows. |

Each `cases` item includes:

| field | type | meaning |
| --- | --- | --- |
| `case` | string | Stable case label. |
| `interlace` | string | `none` or `adam7`. |
| `width` / `height` | integer | PNG-like dimensions. |
| `bit_depth` | integer | PNG bit depth. |
| `color_type` | string | PNG color type name. |
| `stored_streaming_status` | string | Current stored-deflate PNG scanline streaming status; `achieved` for these baseline rows. |
| `fixed_dynamic_streaming_status` | string | Current fixed/dynamic Huffman PNG scanline streaming status; `achieved` for non-interlaced and Adam7 contiguous/chunked zlib rows. |
| `zlib_scratch_bytes` | integer | Exact decoded IDAT/zlib payload scratch. |
| `filtered_row_scratch_bytes` | integer | One filtered row scratch. |
| `previous_row_scratch_bytes` | integer | Previous reconstructed row scratch. |
| `fixed_dynamic_history_scratch_bytes` | integer | Caller-owned DEFLATE history window used by fixed/dynamic streaming scanline decode, currently 32768 bytes. |
| `image_output_bytes` | integer | Final reconstructed image output bytes. |
| `working_scratch_bytes` | integer | Sum of zlib, filtered-row, and previous-row scratch. |
| `streaming_working_scratch_bytes` | integer | Row-only working scratch after stored/streaming decode removes full zlib payload scratch. |
| `fixed_dynamic_streaming_working_scratch_bytes` | integer | Fixed/dynamic streaming working scratch: history window plus filtered and previous row scratch. |
| `streaming_scratch_savings_bytes` | integer | Working-scratch bytes saved by that target; currently equal to `zlib_scratch_bytes`. |
| `streaming_scratch_ratio_x10000` | integer | Target working scratch divided by current working scratch, scaled by 10000. |
| `total_caller_owned_bytes` | integer | Working scratch plus output bytes. |
| `streaming_total_caller_owned_bytes` | integer | Row-only streaming working scratch plus output bytes. |
| `fixed_dynamic_streaming_total_caller_owned_bytes` | integer | Fixed/dynamic streaming working scratch plus output bytes. |

Example:

```json
{
  "schema": "vort.png_scratch_report",
  "schema_version": 1,
  "case_count": 1,
  "cases": [
    {
      "case": "png_rgb8_noninterlaced",
      "interlace": "none",
      "width": 5,
      "height": 5,
      "bit_depth": 8,
      "color_type": "truecolor",
      "stored_streaming_status": "achieved",
      "fixed_dynamic_streaming_status": "achieved",
      "zlib_scratch_bytes": 80,
      "filtered_row_scratch_bytes": 15,
      "previous_row_scratch_bytes": 15,
      "fixed_dynamic_history_scratch_bytes": 32768,
      "image_output_bytes": 75,
      "working_scratch_bytes": 110,
      "streaming_working_scratch_bytes": 30,
      "fixed_dynamic_streaming_working_scratch_bytes": 32798,
      "streaming_scratch_savings_bytes": 80,
      "streaming_scratch_ratio_x10000": 2727,
      "total_caller_owned_bytes": 185,
      "streaming_total_caller_owned_bytes": 105,
      "fixed_dynamic_streaming_total_caller_owned_bytes": 32873
    }
  ]
}
```

## `vort.native_allocation_negative_smoke`

Produced by:

```sh
zig build run-native-allocation-negative-smoke
```

This report proves the native allocation smoke gate fails on representative bad
reports, including over-budget allocation counts, missing required cases, and
allocation/free imbalance.

Top-level fields:

| field | type | meaning |
| --- | --- | --- |
| `schema` | string | Always `vort.native_allocation_negative_smoke`. |
| `schema_version` | integer | Currently `1`. |
| `ok` | boolean | True when all negative cases failed as expected. |
| `case_count` | integer | Number of negative cases. |
| `cases` | list | Per-case negative smoke results. |

Each `cases` item includes:

| field | type | meaning |
| --- | --- | --- |
| `name` | string | Stable negative case label. |
| `expected_failure` | boolean | Always true for these negative cases. |
| `returncode` | integer | Process return code from the smoke gate. |
| `matched` | boolean | True when the gate failed and mentioned the expected case. |

Example:

```json
{
  "schema": "vort.native_allocation_negative_smoke",
  "schema_version": 1,
  "ok": true,
  "case_count": 1,
  "cases": [
    {
      "name": "over_budget",
      "expected_failure": true,
      "returncode": 1,
      "matched": true
    }
  ]
}
```

## `vort.validation_json_schema_manifest`

Consumed by:

```sh
zig build run-validation-json-docs-check
python3 tools/validation_json_docs_check.py
```

This schema defines the fields, simple type checks, and enum values that the
documentation checker applies to the examples in this file. It keeps the checker
logic generic while allowing schema expectations to evolve in a data file.

Top-level fields:

| field | type | meaning |
| --- | --- | --- |
| `schema` | string | Always `vort.validation_json_schema_manifest`. |
| `schema_version` | integer | Currently `1`. |
| `schemas` | object | Map from schema name to validation expectations. |

Each schema entry can contain:

| field | type | meaning |
| --- | --- | --- |
| `fields` | object | Required top-level fields mapped to type names. |
| `enums` | object | Optional top-level string enum constraints. |
| `field_pairs` | object | Optional top-level cross-field equality constraints driven by an allowed map. |
| `conditional_fields` | list | Optional conditional null/non-null constraints, currently driven by simple field equality predicates. |
| `numeric_relations` | list | Optional conditional integer comparisons between two fields, with an optional right-hand offset. |
| `boolean_formula_rules` | object | Optional top-level boolean fields derived from `all` boolean fields, `positive` integer fields, and `zero` integer/list fields. |
| `difference_relations` | list | Optional conditional checks that one integer field equals the difference of two other integer fields. |
| `equality_flag_relations` | list | Optional conditional checks that a boolean field equals the equality result of two integer fields. |
| `count_rules` | object | Optional top-level count fields that must match list lengths or filtered item counts. |
| `dict_sum_rules` | object | Optional top-level count fields that must equal the sum of values in a dict field. |
| `dict_key_enums` | object | Optional dict fields whose keys must be in an allowed string set. |
| `list_item_enums` | object | Optional list fields whose scalar items must be in an allowed string set. |
| `nested_schema_fields` | object | Optional nested object fields that must validate against another schema. |
| `item_collection` | string | Optional nested list field to inspect. |
| `item_fields` | object | Required fields for the first nested item. |
| `item_enums` | object | Optional nested item enum constraints. |
| `item_field_pairs` | object | Optional nested item cross-field equality constraints driven by an allowed map. |
| `item_list_field_pairs` | object | Optional nested item list fields that must equal values from named scalar fields. |
| `collections` | object | Optional map of additional nested list fields to per-item `fields`/`enums`/pair checks. |

Supported type names are `str`, `int`, `float`, `bool`, `list`, `dict`,
`str?`, `int?`, `float?`, and `bool?`. Conditional predicates support `equals`/`not_equals` on a
named field. Numeric relation operators are `eq`, `ne`, `lt`, `le`, `gt`, and
`ge`; `offset` is added to the right-hand field before comparison. Difference
relations compare `left == minuend - subtrahend`, equality-flag relations
compare `flag == (left == right)`, and boolean formula rules compare a target
boolean to the conjunction of named boolean fields plus zero-valued integer or
empty-list fields; `positive` fields must be integers greater than zero.
