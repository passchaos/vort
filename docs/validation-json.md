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

## `vort.dashboard_index`

Produced by:

```sh
zig build run-dashboard-index
```

This schema indexes files in `zig-out`.

Top-level fields:

- `schema`: `vort.dashboard_index`
- `schema_version`: `1`
- `artifact_count`
- `artifacts`

Each artifact includes:

- `name`, `path`, `category`, `format`
- `producer_step`
- `size_bytes`, `mtime_utc`
- JSON summary fields when applicable: `schema`, `schema_version`, `rows`, `ok`

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
| `exact` | object | Map from exact artifact filename to producer command. |
| `contains` | array | Ordered fallback rules for filename substring matches. |

Each `contains` rule has:

| field | type | meaning |
| --- | --- | --- |
| `match` | string | Substring to search for in the artifact filename. |
| `producer_step` | string | Command shown in the Markdown index and JSON manifest. |

Resolution order:

1. Exact filename match in `exact`.
2. First matching rule in `contains`.
3. Built-in fallback mappings in `tools/dashboard_index.py`.
4. Empty `producer_step` when no rule matches.
