#!/usr/bin/env python3
"""Independent source/data verification; no codec or producer is executed."""
import csv
import io
import json
from pathlib import Path
from collections import Counter
from evidence_contracts import verify_capture, verify_receipts, verify_source
from memo_replay import key_of, simulate
from package_io import load, read_packages, require, sha


def verify_requests(evidence, rows):
    summary = load(evidence, 'memo-summary.json')
    require(summary['observation_only'] is True and summary['original_builder_and_candidates_not_skipped'] is True and
            summary['no_natural_huffman_certificate'] is True and summary['no_cross_analysis_frequency_cache'] is True and
            summary['no_throughput_prediction'] is True, 'Opportunity scope differs')
    require(summary['memo'] == '32 entries,16 sets,2way LRU', 'Memo geometry differs')
    saved = {row['case']: row for row in summary['rows']}
    require(len(saved) == 12, 'Memo summary row inventory differs')
    ledger = [json.loads(line) for line in evidence['memo-request-ledger.jsonl'].splitlines()]
    require(len(ledger) == 50850 and load(evidence, 'unknown-scope-requests.json') == [], 'Complete request ledger/unknown scope differs')
    totals = {label: Counter() for label in ['analysis_reset_32x2way', 'quality_operation_retained_32x2way']}
    costs, offset, csv_rows = {}, 0, {}
    count_fields = ['requests', 'additional_hits', 'misses', 'repeat_requests', 'repeat_misses', 'cross_analysis_hits', 'unknown_requests']
    for row_index, (fixture, diagnostic, capture) in enumerate(rows):
        case, records = fixture['case'], capture['records']
        scope_counts, mode_counts, analyses = Counter(), Counter(), set()
        for ordinal, record in enumerate(records):
            require(record['ordinal'] == ordinal and type(record['analysis_ordinal']) is int and record['analysis_ordinal'] >= 1 and
                    record['scope'] in [0, 1, 2] and record['mode'] in [None, 0, 1, 2, 3] and
                    type(record['header_bits']) is int and record['header_bits'] >= 0, 'Header source metadata/ordinal differs')
            key = key_of(record)
            if key in costs:
                require(costs[key] == record['header_bits'], 'Same full canonical key changed exact header cost')
            costs[key] = record['header_bits']
            scope_counts[{0: 'baseline', 1: 'suffix', 2: 'cluster'}[record['scope']]] += 1
            mode_counts[str(record['mode'])] += 1
            analyses.add(record['analysis_ordinal'])
        analysis, a_steps = simulate(records, True)
        operation, o_steps = simulate(records, False)
        report = saved[case]
        require(report['actual_successful_header_requests'] == len(records) and report['analysis_calls'] == capture['analysis_calls'] and
                report['analyses_with_header_requests'] == len(analyses) and report['scope_request_counts'] == dict(scope_counts) and
                report['mode_request_counts'] == dict(mode_counts) and report['analysis_reset_32x2way'] == analysis and
                report['quality_operation_retained_32x2way'] == operation and
                report['additional_operation_hits'] == operation['additional_hits'] - analysis['additional_hits'] and
                report['raw_sha256'] == sha(evidence['capture/header-' + str(row_index) + '.json']),
                'Independent per-input full-key memo counts differ')
        for record, a_step, o_step in zip(records, a_steps, o_steps, strict=True):
            expected = {'case': case, 'raw_key_file': diagnostic['raw_path'], 'raw_ordinal': record['ordinal'],
                        'analysis_ordinal': record['analysis_ordinal'], 'scope': record['scope'], 'mode': record['mode'],
                        'header_bits': record['header_bits'], 'analysis_reset': a_step, 'operation_retained': o_step}
            require(ledger[offset] == expected, 'Independent per-request ledger differs')
            offset += 1
        for label, counts in [('analysis_reset_32x2way', analysis), ('quality_operation_retained_32x2way', operation)]:
            for field in count_fields:
                totals[label][field] += counts[field]
        csv_rows[case] = {'case': case, 'requests': len(records), 'analysis_hits': analysis['additional_hits'],
                          'operation_hits': operation['additional_hits'], 'operation_minus_analysis_hits': operation['additional_hits'] - analysis['additional_hits'],
                          'analysis_repeat_misses': analysis['repeat_misses'], 'operation_repeat_misses': operation['repeat_misses'],
                          'operation_max_repeat_gap_requests': operation['max_repeat_gap_requests'],
                          'operation_max_hit_gap_requests': operation['max_hit_gap_requests'], 'unknown_requests': operation['unknown_requests']}
    require(offset == 50850 and len(costs) == summary['global_observed_distinct_full_keys'] == 33650 and
            summary['all_observed_same_full_key_costs_consistent'] is True and summary['unknown_request_count'] == 0,
            'Complete-key inventory or unknown scope differs')
    for label in totals:
        require(dict(totals[label]) == summary[label + '_total'] and totals[label]['requests'] == 50850 and
                totals[label]['additional_hits'] == 3374 and totals[label]['cross_analysis_hits'] == 0 and totals[label]['unknown_requests'] == 0,
                'Full memo lifetime totals differ')
    require(summary['maximum_operation_hit_fraction'] == max(summary['rows'], key=lambda r: r['quality_operation_retained_32x2way']['additional_hit_fraction'])['case'] and
            summary['maximum_capacity_gap_case'] == max(summary['rows'], key=lambda r: r['quality_operation_retained_32x2way']['repeat_misses'])['case'],
            'Maximum opportunity row differs')
    csv_data = list(csv.DictReader(io.StringIO(evidence['memo-counts.csv'].decode())))
    require([r['case'] for r in csv_data] == [f['case'] for f, _, _ in rows], 'Memo CSV row order differs')
    for row in csv_data:
        require(row == {key: str(value) for key, value in csv_rows[row['case']].items()}, 'Memo CSV count differs')
    require(summary['observer_memory'] == load(evidence, 'diagnostic.json')['observer_memory'], 'Memo observer scope differs')
    return {'successful_requests': 50850, 'distinct_complete_keys': 33650, 'ledger_records': offset,
            'analysis_reset': dict(totals['analysis_reset_32x2way']), 'operation_retained': dict(totals['quality_operation_retained_32x2way']),
            'hit_fraction': 3374 / 50850, 'unknown_scope_requests': 0, 'all_same_full_key_exact_costs_consistent': True,
            'scope': 'Observed actual successful header execution requests; full256u8+stop+policy equality, two independent LRU lifetimes; no speed prediction'}


def verify(root):
    packages, binding = read_packages(root)
    evidence, sources = packages['evidence.tar.gz'], packages['sources.tar.gz']
    source, current = verify_source(sources, evidence)
    receipts = verify_receipts(evidence, sources, current)
    rows, capture = verify_capture(evidence)
    requests = verify_requests(evidence, rows)
    published = json.loads((root / 'summary.json').read_bytes())
    require(published['successful_requests'] == requests['successful_requests'] and
            published['distinct_complete_keys'] == requests['distinct_complete_keys'] and
            published['hits_each_lifetime'] == 3374 and published['cross_analysis_hits'] == 0 and
            published['observer_payload_bytes'] == capture['observer_memory']['payload_bytes'] and
            published['max_observer_used_bytes'] == capture['max_observer_used_bytes'] and
            published['optimization_adopted'] is False and published['throughput_prediction'] is False,
            'Published figures/scope differ')
    return {'schema': 'vort.brotli.complex-header.offline-verification.v1', 'verified': True,
            'source': source, 'original_receipts': receipts, 'capture': capture, 'requests': requests,
            'archive_members': {name: len(members) for name, members in binding['members'].items()},
            'scope': 'Package bytes only; no archive extraction, original-path access, producer import/eval, codec, foreign executable/SO, build or timing rerun',
            'conclusion': 'Opportunity diagnostic only; 32-entry memo not prioritized, no optimization or Huffman certificate adopted'}


if __name__ == '__main__':
    print(json.dumps(verify(Path(__file__).resolve().parent), indent=2, sort_keys=True))
