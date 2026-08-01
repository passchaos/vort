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
    "vort.raw_deflate_header_info",
    "vort.wrapped_deflate_header_info",
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
main dashboard index.

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
not depend on platform-specific per-argument limits. Schema version `2` makes
that coverage count required for healthy reports.

Example:

```json
{
  "schema": "vort.python_zlib_diff_smoke",
  "schema_version": 2,
  "ok": true,
  "payloads": 11,
  "large_file_payloads": 1,
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
case counts from the frame and dictionary probe executables, adds a
`coverage` list keyed by codec (`lz4`/`zstd`) and surface (`frame`/`dictionary`),
and adds a `capabilities` list for cross-cutting library behaviors such as
lib-generated frames, incremental drains, chunked split input, reusable chunked
decoder drains, dictionaries, malformed input, checksums, Huffman literals,
sequence tables, and block APIs.

Example:

```json
{
  "schema": "vort.native_codec_probes",
  "schema_version": 1,
  "ok": true,
  "capability_count": 15,
  "coverage_count": 4,
  "probe_count": 4,
  "total_cases": 246,
  "capabilities": [
    {
      "capability": "lib-generated",
      "cases": 126,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "native-generated",
      "cases": 216,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "incremental",
      "cases": 133,
      "ok": true,
      "ok_probe_count": 4,
      "present": true,
      "probe_count": 4
    },
    {
      "capability": "chunked",
      "cases": 129,
      "ok": true,
      "ok_probe_count": 4,
      "present": true,
      "probe_count": 4
    },
    {
      "capability": "reusable-chunked",
      "cases": 126,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "fse-repeat",
      "cases": 6,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "dictionary",
      "cases": 133,
      "ok": true,
      "ok_probe_count": 3,
      "present": true,
      "probe_count": 3
    },
    {
      "capability": "dictionary-set",
      "cases": 109,
      "ok": true,
      "ok_probe_count": 3,
      "present": true,
      "probe_count": 3
    },
    {
      "capability": "skippable",
      "cases": 216,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "malformed",
      "cases": 218,
      "ok": true,
      "ok_probe_count": 3,
      "present": true,
      "probe_count": 3
    },
    {
      "capability": "checksum",
      "cases": 219,
      "ok": true,
      "ok_probe_count": 4,
      "present": true,
      "probe_count": 4
    },
    {
      "capability": "bounded-limits",
      "cases": 220,
      "ok": true,
      "ok_probe_count": 4,
      "present": true,
      "probe_count": 4
    },
    {
      "capability": "huffman",
      "cases": 113,
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1
    },
    {
      "capability": "sequence-tables",
      "cases": 120,
      "ok": true,
      "ok_probe_count": 2,
      "present": true,
      "probe_count": 2
    },
    {
      "capability": "block",
      "cases": 103,
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1
    }
  ],
  "coverage": [
    {
      "cases": 103,
      "codec": "lz4",
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1,
      "surface": "frame"
    },
    {
      "cases": 8,
      "codec": "lz4",
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1,
      "surface": "dictionary"
    },
    {
      "cases": 113,
      "codec": "zstd",
      "ok": true,
      "ok_probe_count": 1,
      "present": true,
      "probe_count": 1,
      "surface": "frame"
    },
    {
      "cases": 22,
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
      "cases": 103,
      "marker": "lz4_native_probe",
      "output": "lz4_native_probe_ok cases=103\nlz4_native_probe_coverage capability=block cases=103\nlz4_native_probe_coverage capability=bounded-limits cases=103\nlz4_native_probe_coverage capability=checksum cases=103\nlz4_native_probe_coverage capability=chunked cases=63\nlz4_native_probe_coverage capability=reusable-chunked cases=63\nlz4_native_probe_coverage capability=dictionary cases=103\nlz4_native_probe_coverage capability=dictionary-set cases=103\nlz4_native_probe_coverage capability=incremental cases=63\nlz4_native_probe_coverage capability=lib-generated cases=63\nlz4_native_probe_coverage capability=malformed cases=103\nlz4_native_probe_coverage capability=native-generated cases=103\nlz4_native_probe_coverage capability=skippable cases=103\n",
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
        "block": 103,
        "bounded-limits": 103,
        "checksum": 103,
        "chunked": 63,
        "dictionary": 103,
        "dictionary-set": 103,
        "incremental": 63,
        "lib-generated": 63,
        "malformed": 103,
        "native-generated": 103,
        "reusable-chunked": 63,
        "skippable": 103
      },
      "reported_capability_count": 12
    },
    {
      "label": "lz4-native-dictionary-probe",
      "executable": "zig-out/bin/lz4-native-dictionary-probe",
      "ok": true,
      "returncode": 0,
      "cases": 8,
      "marker": "lz4_native_dictionary_probe",
      "output": "lz4_native_dictionary_probe_ok cases=8\nlz4_native_dictionary_probe_coverage capability=bounded-limits cases=1\nlz4_native_dictionary_probe_coverage capability=checksum cases=1\nlz4_native_dictionary_probe_coverage capability=chunked cases=1\nlz4_native_dictionary_probe_coverage capability=dictionary cases=8\nlz4_native_dictionary_probe_coverage capability=dictionary-set cases=3\nlz4_native_dictionary_probe_coverage capability=incremental cases=3\n",
      "reported_capabilities": [
        "bounded-limits",
        "checksum",
        "chunked",
        "dictionary",
        "dictionary-set",
        "incremental"
      ],
      "reported_capability_cases": {
        "bounded-limits": 1,
        "checksum": 1,
        "chunked": 1,
        "dictionary": 8,
        "dictionary-set": 3,
        "incremental": 3
      },
      "reported_capability_count": 6
    },
    {
      "label": "zstd-native-frame-probe",
      "executable": "zig-out/bin/zstd-native-frame-probe",
      "ok": true,
      "returncode": 0,
      "cases": 113,
      "marker": "zstd_native_frame_probe",
      "output": "zstd_native_frame_probe_ok cases=113\nzstd_native_frame_probe_coverage capability=bounded-limits cases=113\nzstd_native_frame_probe_coverage capability=checksum cases=113\nzstd_native_frame_probe_coverage capability=chunked cases=63\nzstd_native_frame_probe_coverage capability=reusable-chunked cases=63\nzstd_native_frame_probe_coverage capability=fse-repeat cases=3\nzstd_native_frame_probe_coverage capability=huffman cases=113\nzstd_native_frame_probe_coverage capability=incremental cases=63\nzstd_native_frame_probe_coverage capability=lib-generated cases=63\nzstd_native_frame_probe_coverage capability=malformed cases=113\nzstd_native_frame_probe_coverage capability=native-generated cases=113\nzstd_native_frame_probe_coverage capability=sequence-tables cases=113\nzstd_native_frame_probe_coverage capability=skippable cases=113\n",
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
        "bounded-limits": 113,
        "checksum": 113,
        "chunked": 63,
        "fse-repeat": 3,
        "huffman": 113,
        "incremental": 63,
        "lib-generated": 63,
        "malformed": 113,
        "native-generated": 113,
        "reusable-chunked": 63,
        "sequence-tables": 113,
        "skippable": 113
      },
      "reported_capability_count": 12
    },
    {
      "label": "zstd-native-dictionary-probe",
      "executable": "zig-out/bin/zstd-native-dictionary-probe",
      "ok": true,
      "returncode": 0,
      "cases": 22,
      "marker": "zstd_native_dictionary_probe",
      "output": "zstd_native_dictionary_probe_ok cases=22\nzstd_native_dictionary_probe_coverage capability=bounded-limits cases=3\nzstd_native_dictionary_probe_coverage capability=checksum cases=2\nzstd_native_dictionary_probe_coverage capability=chunked cases=2\nzstd_native_dictionary_probe_coverage capability=dictionary cases=22\nzstd_native_dictionary_probe_coverage capability=dictionary-set cases=3\nzstd_native_dictionary_probe_coverage capability=fse-repeat cases=3\nzstd_native_dictionary_probe_coverage capability=incremental cases=4\nzstd_native_dictionary_probe_coverage capability=malformed cases=2\nzstd_native_dictionary_probe_coverage capability=sequence-tables cases=7\n",
      "reported_capabilities": [
        "bounded-limits",
        "checksum",
        "chunked",
        "dictionary",
        "dictionary-set",
        "fse-repeat",
        "incremental",
        "malformed",
        "sequence-tables"
      ],
      "reported_capability_cases": {
        "bounded-limits": 3,
        "checksum": 2,
        "chunked": 2,
        "dictionary": 22,
        "dictionary-set": 3,
        "fse-repeat": 3,
        "incremental": 4,
        "malformed": 2,
        "sequence-tables": 7
      },
      "reported_capability_count": 9
    }
  ]
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
- `missing_sidecar_corrupt_artifact`
- `sidecar_corrupt_failed`
- `missing_huffman_length_artifact`
- `huffman_length_failed`
- `missing_fuzz_corpus_artifact`
- `fuzz_corpus_failed`
- `missing_fuzz_coverage_artifact`
- `fuzz_coverage_failed`
- `missing_decode_stage_artifact`
- `decode_stage_failed`
- `missing_python_zlib_diff_artifact`
- `python_zlib_diff_failed`
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
- `native_tier_range_*` fields summarize direct-API seekability tier range benchmark summaries.
- `native_tier_corpus_discovery_*` fields summarize standard-corpus discovery
  inputs for the native tier range benchmark and now participate in aggregate
  `validation_healthy`.
- `header_inspect_present`, `header_inspect_ok`, `header_inspect_healthy`,
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
  `dashboard_strict_check_count`, `dashboard_strict_mode_count`,
  `dashboard_strict_expected_failure_count`, `dashboard_strict_matched_count`,
  `dashboard_strict_expected_mode_count`, `dashboard_strict_missing_mode_count`,
  `dashboard_strict_missing_checks`, `dashboard_strict_missing_expected_failures`,
  `dashboard_strict_missing_matched`, `dashboard_strict_missing_modes`
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
  `huffman_length_package_merge_worst_gap_bits`
- `fuzz_corpus_present`, `fuzz_corpus_ok`,
  `fuzz_corpus_coverage_present`, `fuzz_corpus_coverage_ok`,
  `fuzz_corpus_healthy`, `fuzz_corpus_cases`,
  `fuzz_corpus_matched_rows`, `fuzz_corpus_unmatched_rows`,
  `fuzz_corpus_exact_error_expectations`,
  `fuzz_corpus_mode_count_rows`, `fuzz_corpus_error_count_rows`,
  `fuzz_corpus_coverage_mode_requirements`,
  `fuzz_corpus_coverage_error_requirements`
- `decode_stage_present`, `decode_stage_ok`, `decode_stage_healthy`,
  `decode_stage_rows`, `decode_stage_error_rows`,
  `decode_stage_matched_error_rows`, `decode_stage_unmatched_error_rows`
- `python_zlib_diff_present`, `python_zlib_diff_ok`,
  `python_zlib_diff_healthy`, `python_zlib_diff_payloads`,
  `python_zlib_diff_large_file_payloads`,
  `python_zlib_diff_match_heavy_payloads`,
  `python_zlib_diff_dynamic_payloads`, `python_zlib_diff_dictionary_cases`,
  `python_zlib_diff_zlib_dict_encode_cases`,
  `python_zlib_diff_raw_dict_encode_cases`,
  `python_zlib_diff_malformed_wrapper_cases`,
  `python_zlib_diff_malformed_deflate_cases`, `python_zlib_diff_cli_successes`,
  `python_zlib_diff_expected_failures`
- `native_codec_probes_present`, `native_codec_probes_ok`,
  `native_codec_probes_healthy`, `native_codec_probes_probe_count`,
  `native_codec_probes_ok_probe_count`,
  `native_codec_probes_capability_count`,
  `native_codec_probes_ok_capability_count`,
  `native_codec_probes_lib_generated_cases`,
  `native_codec_probes_incremental_cases`,
  `native_codec_probes_chunked_cases`,
  `native_codec_probes_reusable_chunked_cases`,
  `native_codec_probes_dictionary_cases`,
  `native_codec_probes_malformed_cases`,
  `native_codec_probes_total_cases`
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
    "missing_sidecar_corrupt_artifact",
    "missing_huffman_length_artifact",
    "missing_fuzz_corpus_artifact",
    "missing_fuzz_coverage_artifact",
    "missing_decode_stage_artifact",
    "missing_python_zlib_diff_artifact",
    "missing_native_tier_corpus_discovery_artifact"
  ],
  "header_inspect_present": false,
  "header_inspect_ok": false,
  "header_inspect_healthy": false,
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
  "dashboard_strict_mode_count": 0,
  "dashboard_strict_expected_failure_count": 0,
  "dashboard_strict_matched_count": 0,
  "dashboard_strict_expected_mode_count": 0,
  "dashboard_strict_missing_mode_count": 0,
  "dashboard_strict_missing_checks": 0,
  "dashboard_strict_missing_expected_failures": 0,
  "dashboard_strict_missing_matched": 0,
  "dashboard_strict_missing_modes": [],
  "sidecar_corrupt_present": false,
  "sidecar_corrupt_healthy": false,
  "sidecar_corrupt_rows": 0,
  "sidecar_corrupt_metadata_ok_rows": 0,
  "sidecar_corrupt_full_rejected_rows": 0,
  "sidecar_corrupt_metadata_failed_rows": 0,
  "sidecar_corrupt_full_not_rejected_rows": 0,
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
  "fuzz_corpus_present": false,
  "fuzz_corpus_ok": false,
  "fuzz_corpus_coverage_present": false,
  "fuzz_corpus_coverage_ok": false,
  "fuzz_corpus_healthy": false,
  "fuzz_corpus_cases": 0,
  "fuzz_corpus_matched_rows": 0,
  "fuzz_corpus_unmatched_rows": 0,
  "fuzz_corpus_exact_error_expectations": 0,
  "fuzz_corpus_mode_count_rows": 0,
  "fuzz_corpus_error_count_rows": 0,
  "fuzz_corpus_coverage_mode_requirements": 0,
  "fuzz_corpus_coverage_error_requirements": 0,
  "decode_stage_present": false,
  "decode_stage_ok": false,
  "decode_stage_healthy": false,
  "decode_stage_rows": 0,
  "decode_stage_error_rows": 0,
  "decode_stage_matched_error_rows": 0,
  "decode_stage_unmatched_error_rows": 0,
  "python_zlib_diff_present": false,
  "python_zlib_diff_ok": false,
  "python_zlib_diff_healthy": false,
  "python_zlib_diff_payloads": 0,
  "python_zlib_diff_large_file_payloads": 0,
  "python_zlib_diff_match_heavy_payloads": 0,
  "python_zlib_diff_dynamic_payloads": 0,
  "python_zlib_diff_dictionary_cases": 0,
  "python_zlib_diff_zlib_dict_encode_cases": 0,
  "python_zlib_diff_raw_dict_encode_cases": 0,
  "python_zlib_diff_malformed_wrapper_cases": 0,
  "python_zlib_diff_malformed_deflate_cases": 0,
  "python_zlib_diff_cli_successes": 0,
  "python_zlib_diff_expected_failures": 0,
  "native_codec_probes_present": false,
  "native_codec_probes_ok": false,
  "native_codec_probes_healthy": false,
  "native_codec_probes_probe_count": 0,
  "native_codec_probes_ok_probe_count": 0,
  "native_codec_probes_capability_count": 0,
  "native_codec_probes_ok_capability_count": 0,
  "native_codec_probes_lib_generated_cases": 0,
  "native_codec_probes_incremental_cases": 0,
  "native_codec_probes_chunked_cases": 0,
  "native_codec_probes_reusable_chunked_cases": 0,
  "native_codec_probes_dictionary_cases": 0,
  "native_codec_probes_malformed_cases": 0,
  "native_codec_probes_total_cases": 0,
  "native_tier_range_present": true,
  "native_tier_range_healthy": true,
  "native_tier_range_summary_count": 3,
  "native_tier_range_ok_count": 3,
  "native_tier_range_rows": 24,
  "native_tier_range_fixture_count": 8,
  "native_tier_range_enforced_count": 1,
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
      "mode": "strict-header-inspect",
      "min_checks": 3,
      "min_expected_failures": 3,
      "min_matched": 3
    },
    {
      "mode": "native-tier-range-health",
      "min_checks": 3,
      "min_expected_failures": 0,
      "min_matched": 3
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
      "reason": "missing_dashboard_strict_modes",
      "check": "validation_missing_dashboard_strict_modes",
      "fixture": "missing_dashboard_strict_modes"
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
native-tier range health-field coverage, and aggregate validation-health
failures. Each check records the expected output
marker, actual truncated output, original output length, truncation limit/flag,
and process return code for CI diagnostics. `mode_counts` groups checks by
strict mode for a compact dashboard overview, while `expected_modes` defines the
minimum required coverage per strict mode, `mode_requirements` reports
actual/minimum/delta values, and `missing_modes` reports unmet requirements.
`validation_unhealthy_reason_checks` records one isolated negative fixture for
each `vort.dashboard_index.validation_unhealthy_reasons` enum value so new
aggregate health reasons must be backed by real failing dashboard inputs before
the smoke artifact can pass. The expected reason/check/fixture matrix lives in
`tools/dashboard_strict_validation_reasons.json`; the `strict-validation-health`
mode minimums must cover every configured reason, currently 23. A synthetic long-output check
keeps the truncation path covered so `actual_output_truncated=true` is exercised
in CI.

Example:

```json
{
  "schema": "vort.dashboard_strict_smoke",
  "schema_version": 1,
  "ok": true,
  "check_count": 4,
  "mode_count": 2,
  "expected_mode_count": 2,
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
      "mode": "native-tier-range-health",
      "min_checks": 3,
      "min_expected_failures": 0,
      "min_matched": 3
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
      "mode": "native-tier-range-health",
      "checks": 3,
      "min_checks": 3,
      "missing_checks": 0,
      "expected_failures": 0,
      "min_expected_failures": 0,
      "missing_expected_failures": 0,
      "matched": 3,
      "min_matched": 3,
      "missing_matched": 0
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
      "mode": "native-tier-range-health",
      "checks": 3,
      "expected_failures": 0,
      "matched": 3
    }
  ],
  "checks": [
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
    },
    {
      "name": "failed_native_tier_range_summary",
      "mode": "native-tier-range-health",
      "expected_failure": false,
      "expected_output": "dashboard_index=",
      "actual_output": "dashboard_index=ok",
      "actual_output_bytes": 18,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
    {
      "name": "missing_native_tier_range_source",
      "mode": "native-tier-range-health",
      "expected_failure": false,
      "expected_output": "dashboard_index=",
      "actual_output": "dashboard_index=ok",
      "actual_output_bytes": 18,
      "actual_output_limit": 240,
      "actual_output_truncated": false,
      "returncode": 0,
      "matched": true
    },
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
    }
  ],
  "validation_unhealthy_reason_checks": [
    {
      "reason": "missing_dashboard_strict_modes",
      "check": "validation_missing_dashboard_strict_modes",
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

This smoke report gates the allocation report by requiring selected
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
options, including strict rejection, relaxed success, dictionary-aware zlib
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
CSV/Markdown artifacts. The gate checks
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
and why the CSV was absent when no input cases were available. `source_mode` is
`discovered` for automatic local standard-corpus discovery and `paths` when the
caller supplies explicit `--paths`.

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
representative PNG-like zlib decode paths. It includes non-interlaced and Adam7
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
