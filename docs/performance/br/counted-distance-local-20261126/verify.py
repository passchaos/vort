#!/usr/bin/env python3
"""Verify standalone local rejection entirely from the sealed package."""
import json
from pathlib import Path
from package_io import read_packages, require
from provenance import verify_provenance
from pilot import verify_pilot


def verify(root):
    packages, binding = read_packages(root)
    source = verify_provenance(packages['sources.tar.gz'], packages['bench.tar.gz'], packages['validation.tar.gz'])
    pilot = verify_pilot(packages['bench.tar.gz'])
    summary = json.loads((root / 'summary.json').read_bytes())
    require(summary['point_estimate_speedup_GM'] == 1.0138217623027224 and summary['standalone_accepted'] is False and
            summary['CI'] is None and summary['full_approved'] is False and summary['full_started'] is False,
            'Published rejection scope differs')
    return {'schema': 'vort.brotli.counted-distance-local.offline-verification.v1', 'verified': True,
            'provenance': source, 'pilot': pilot,
            'archive_members': {name: len(members) for name, members in binding['members'].items()},
            'scope': 'Package bytes only, no extraction/original-path access/producer eval/codec/foreign/build/timing execution',
            'conclusion': 'Standalone local pilot rejected, no formal CI, full not approved; separate global-bound source excluded'}


if __name__ == '__main__':
    print(json.dumps(verify(Path(__file__).resolve().parent), indent=2, sort_keys=True))
