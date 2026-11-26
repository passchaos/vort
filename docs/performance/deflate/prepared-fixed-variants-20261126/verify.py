#!/usr/bin/env python3
"""Offline package verification. No producer, codec or stored argv is run."""
import json
from pathlib import Path
import independent_statistics
from package_io import load, read_packages, require, sha
from provenance_contracts import verify_previous_and_failures, verify_sources_builds, verify_terminal_receipts
from sample_contracts import verify_preflight, verify_samples


def verify_variant(files, common):
    manifest = load(files, 'performance/manifest.json')
    artifact = load(files, 'performance/artifact-hashes.json')
    expected = load(files, 'performance/result.json')
    source = verify_sources_builds(files, common, manifest, artifact)
    terminal = verify_terminal_receipts(files, artifact)
    records = verify_samples(files, manifest, artifact)
    preflight = verify_preflight(files, manifest, artifact)
    statistics = independent_statistics.verify(manifest, records, expected, preflight['exact_wire_bytes_equal'])
    require(statistics['accepted'] is False, 'Historical rejected verdict changed')
    failed = [{key: row[key] for key in ['family', 'role', 'row', 'speedup_geomean', 'paired_95ci']}
              for row in expected['rows'] if not row['floor_pass']]
    return {'accepted': False, 'statistics': statistics, 'failed_floor_rows': failed,
            'source_and_builds': source, 'preflight': preflight, 'terminal_receipts': terminal,
            'memory_scope': 'Timing only; zero heap contracts are separate recorded tests; no measured RSS or memory-performance acceptance'}


def main():
    root = Path(__file__).resolve().parent
    packages, binding = read_packages(root)
    provenance = json.loads((root / 'provenance.json').read_bytes())
    require(sha((root / 'independent_statistics.py').read_bytes()) == provenance['independent_statistics']['sha256'],
            'Copied Root statistics helper differs')
    variants = {label: verify_variant(packages[label + '.tar.gz'], packages['common.tar.gz'])
                for label in ['v2-reserved-sink', 'v3-direct-bits']}
    failures = verify_previous_and_failures(packages)
    summary = json.loads((root / 'summary.json').read_bytes())
    for label, result in variants.items():
        saved = summary['variants'][label]
        require(saved['accepted'] is False and saved['records'] == 540 and saved['statistical_rows'] == 45 and
                saved['raw_sha256'] == result['terminal_receipts']['raw_sha256'] and
                saved['prepared_target_geomean'] == result['statistics']['prepared_target_geomean'] and
                saved['prepared_target_paired_95ci'] == result['statistics']['prepared_target_paired_95ci'] and
                saved['failed_floor_rows'] == result['failed_floor_rows'], 'Published summary differs')
    print(json.dumps({'schema': 'vort.deflate.prepared-fixed-variants.offline-verification.v1',
                      'verified': True, 'variants': variants, 'historical_failures': failures,
                      'archive_members': {name: len(members) for name, members in binding['members'].items()},
                      'scope': 'Package bytes only; archives not extracted; no stored argv, producer, foreign executable/SO, codec, build or timing rerun'},
                     indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
