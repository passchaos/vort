#!/usr/bin/env python3
"""Verify package-only source, raw observations, gate and independent statistics."""
from pathlib import Path
import json
from package_io import load, read_packages, require, sha
from timing_contracts import verify_timing
from statistics_replay import verify_statistics
from diagnostic_contracts import verify_diagnostic, verify_gate_receipts


def verify(root):
    packages, binding = read_packages(root)
    timing, diagnostic, sources = [packages[name + '.tar.gz'] for name in ['timing', 'diagnostic', 'sources']]
    require((root / 'independent_statistics.py').read_bytes() == timing['independent-verify.py'],
            'Pure independent statistics helper copy differs')
    gate_source = (root / 'root_profile_gate.py').read_bytes()
    gate = verify_gate_receipts(diagnostic, gate_source)
    timing_capture, _ = verify_timing(timing, sources)
    statistics = verify_statistics(timing)
    diagnosis = verify_diagnostic(diagnostic, sources, timing)
    published = json.loads((root / 'summary.json').read_bytes())
    require(published['timing']['current_over_old_elapsed_geomean'] == load(timing, 'summary.json')['matrix'][0]['paired_geomean_ns_current_over_old'] and
            published['timing']['pairs'] == 90 and published['diagnostic']['trace_runs'] == 36 and
            published['diagnostic']['observed_prefix_reuses'] == 87 and
            published['diagnostic']['physical_wires'] == 1029 and published['diagnostic']['lost_wires'] == 993 and
            published['performance_acceptance'] == 'Not established; historical regression observation and separate diagnostics',
            'Published scope or figures differ')
    return {'schema': 'vort.brotli.q8-main-history.offline-verification.v1', 'verified': True,
            'timing_capture': timing_capture, 'independent_statistics': statistics,
            'diagnostic': diagnosis, 'gate_receipts': gate,
            'archive_members': {name: len(members) for name, members in binding['members'].items()},
            'scope': 'Package bytes only, archives not extracted; no stored argv, producer, codec, foreign executable/SO, compiler or timing run',
            'performance_acceptance': 'Not established; historical regression observation and separate diagnostics'}


if __name__ == '__main__':
    print(json.dumps(verify(Path(__file__).resolve().parent), indent=2, sort_keys=True))
