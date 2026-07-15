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
aggregate fields:

- `stream`, `sidecar`
- `status`, `error`
- `mode`
- `recoverability_hint`, `validation_stage`, `frame_index`, `frame_offset`,
  `uncompressed_offset`, `frame_flags`, `frame_mode`
- `stream_bytes`, `sidecar_bytes`, `entries`, `total_uncompressed`, `crc32`

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
      "frame_mode": "deflate"
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
    "vort.header_inspect_smoke",
    "vort.raw_deflate_header_info",
    "vort.wrapped_deflate_header_info",
    "vort.zlib_header_info",
    "vort.gzip_header_info"
  ],
  "cli_failure_hint": "payload_corrupt",
  "report_rows": 1,
  "corrupt_rows": 8
}
```

## `vort.dashboard_index`

Produced by:

```sh
zig build run-dashboard-index
zig build run-dashboard-strict-smoke
python3 tools/dashboard_index.py --strict-header-inspect
```

This schema indexes files in `zig-out`. With `--strict-header-inspect`, index
generation fails when the header inspect artifact is absent, reports `ok=false`,
or has missing required workflows.

Top-level fields:

- `schema`: `vort.dashboard_index`
- `schema_version`: `1`
- `artifact_count`
- `producer_step_covered`
- `producer_step_missing`
- `producer_step_allowed_missing`
- `smoke_gate_covered`
- `smoke_gate_missing`
- `smoke_gate_required_missing`
- `header_inspect_present`, `header_inspect_ok`,
  `header_inspect_required_workflow_count`,
  `header_inspect_missing_workflow_count`,
  `header_inspect_missing_workflows`
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
  "smoke_gate_covered": 1,
  "smoke_gate_missing": [],
  "smoke_gate_required_missing": [],
  "header_inspect_present": false,
  "header_inspect_ok": false,
  "header_inspect_required_workflow_count": 0,
  "header_inspect_missing_workflow_count": 0,
  "header_inspect_missing_workflows": [],
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

## `vort.dashboard_strict_smoke`

Produced by:

```sh
zig build run-dashboard-strict-dashboard
python3 tools/dashboard_strict_smoke.py --summary zig-out/vort-dashboard-strict-smoke.json --markdown zig-out/vort-dashboard-strict-smoke.md
```

This schema summarizes positive and negative smoke checks for dashboard strict
modes: producer coverage, smoke-gate coverage, and header-inspection health.

Example:

```json
{
  "schema": "vort.dashboard_strict_smoke",
  "schema_version": 1,
  "ok": true,
  "check_count": 1,
  "checks": [
    {
      "name": "all_strict_ok",
      "mode": "all",
      "expected_failure": false,
      "expected_output": "dashboard_index=",
      "returncode": 0,
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
| `difference_relations` | list | Optional conditional checks that one integer field equals the difference of two other integer fields. |
| `equality_flag_relations` | list | Optional conditional checks that a boolean field equals the equality result of two integer fields. |
| `count_rules` | object | Optional top-level count fields that must match list lengths or filtered item counts. |
| `dict_sum_rules` | object | Optional top-level count fields that must equal the sum of values in a dict field. |
| `dict_key_enums` | object | Optional dict fields whose keys must be in an allowed string set. |
| `nested_schema_fields` | object | Optional nested object fields that must validate against another schema. |
| `item_collection` | string | Optional nested list field to inspect. |
| `item_fields` | object | Required fields for the first nested item. |
| `item_enums` | object | Optional nested item enum constraints. |
| `item_field_pairs` | object | Optional nested item cross-field equality constraints driven by an allowed map. |
| `item_list_field_pairs` | object | Optional nested item list fields that must equal values from named scalar fields. |
| `collections` | object | Optional map of additional nested list fields to per-item `fields`/`enums`/pair checks. |

Supported type names are `str`, `int`, `bool`, `list`, `dict`, `str?`,
`int?`, and `bool?`. Conditional predicates support `equals`/`not_equals` on a
named field. Numeric relation operators are `eq`, `ne`, `lt`, `le`, `gt`, and
`ge`; `offset` is added to the right-hand field before comparison. Difference
relations compare `left == minuend - subtrahend`, and equality-flag relations
compare `flag == (left == right)`.
