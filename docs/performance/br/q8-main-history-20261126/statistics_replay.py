"""Use Archimedes' pure reducer on package-validated raw observations."""
import independent_statistics
from package_io import load, require, sha


def verify_statistics(files):
    manifest = load(files, 'run-manifest.json')
    summary = load(files, 'summary.json')
    sizes = {}
    for row in load(files, 'preflight-summary.json')['rows']:
        sizes.setdefault(row['case'], {})[row['variant']] = row['wire_bytes']
    pairs = [{'case': pair['case'], 'round': pair['round'], 'order': pair['order'],
              'ns': {name: side['raw_ns'][0] for name, side in pair['processes'].items()}}
             for pair in manifest['pairs']]
    rows, matrix = independent_statistics.reduce_statistics(pairs, sizes)
    independent_statistics.tree_compare(summary['matrix'], [matrix], 'package matrix and deterministic CI')
    require([r['case'] for r in summary['rows']] == sorted(rows), 'Summary row order differs')
    for saved in summary['rows']:
        for field, value in rows[saved['case']].items():
            independent_statistics.tree_compare(saved[field], value, 'package row statistic ' + field)
    receipt = load(files, 'independent-verification.json')
    require(receipt['status'] == 'pass' and receipt['retained_all_pairs_no_trimming'] == len(pairs) == 90 and
            receipt['retained_all_timed_calls'] == 180 and receipt['preflight_complete_initial_wires'] == 24,
            'Independent verification receipt differs')
    independent_statistics.tree_compare(receipt['matrix'], matrix, 'independent saved matrix')
    for case, result in rows.items():
        independent_statistics.tree_compare(receipt['row_stats'][case],
                                           {k: v for k, v in result.items() if k != 'raw_pairs'},
                                           'independent saved row')
    for member, digest in receipt['raw_and_relevant_receipt_sha256'].items():
        require(sha(files[member]) == digest, 'Independent receipt-bound raw changed: ' + member)
    require(receipt['all_12_primary_rows_slower'] is True and
            all(row['primary_six_round_paired_geomean'] > 1 for row in rows.values()) and
            receipt['all_positive_pairs_current_slower'] == sum(p['ns']['current'] > p['ns']['old_exact'] for p in pairs) == 90,
            'Ratio direction or slower-row interpretation differs')
    host = load(files, 'independent-host-scope.json')
    require(receipt['host_annotation'] == host and host['inherited_summary_host_scope_unmodified'] == summary['host_scope'] and
            host['inherited_summary_statistics_scope_unmodified'] == summary['statistics_scope'] and
            host['root_HEAVY_at_release'] == 0 and host['runner_snapshot_count'] == 92 and
            host['runner_snapshots_with_collector_matches'] == 0, 'Independent host annotation differs')
    return {'pairs': 90, 'timed_calls': 180, 'matrix': matrix,
            'all_12_primary_rows_slower': True, 'all_90_pairs_current_slower': True,
            'independent_receipt_and_raw_hashes_verified': True,
            'ratio_direction': 'current elapsed / exact-old elapsed; above1 means current is slower',
            'host_annotation': host,
            'scope': 'Archimedes pure data reducer; no producer import/eval, codec, library or timing rerun'}
