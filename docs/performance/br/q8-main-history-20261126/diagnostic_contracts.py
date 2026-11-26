"""Replay the frozen Root gate through an archive-backed input adapter."""
import csv
import io
import statistics
from types import SimpleNamespace
import root_profile_gate
from package_io import closed_path, load, require, sha, virtual_source

ORIGIN = '/tmp/vort-br-q8-main-stage.xvvg2kc1'


def gate_on_package(files, report):
    class PackagePath:
        def __init__(self, name):
            self.name = str(name)

        def read_bytes(self):
            return files[closed_path(self.name, ORIGIN)]

        def stat(self):
            return SimpleNamespace(st_size=len(self.read_bytes()))

        def __str__(self):
            return self.name

    # validate() uses Path only for input stat/digest. Stored CLI main is never
    # invoked. This adapter resolves each captured input to archive bytes.
    original = root_profile_gate.Path
    try:
        root_profile_gate.Path = PackagePath
        return root_profile_gate.validate(report, allow_truncated_context_details=True)
    finally:
        root_profile_gate.Path = original


def verify_diagnostic(files, sources, timing):
    manifest = load(files, 'manifest.json')
    require(manifest['source_commit'] == '8ccd54a59da850da724cc4d6ca79a727c659889e' and
            manifest['quality'] == 8 and manifest['mode'] == 'generic' and manifest['window_bits'] == 16 and
            manifest['rounds'] == 3 and manifest['sampling_cpu'] == 2 and manifest['diagnostic_only'] is True and
            manifest['normal_profile_ns_excluded_from_throughput_gates'] is True, 'Diagnostic policy differs')
    source = virtual_source(sources, 'current/src/')
    require({'src/' + name: sha(data) for name, data in source.items()} == load(files, 'source-manifest.json') and
            len(source) == 2200, 'Diagnostic frozen main source differs')
    closure = load(sources, 'source-closure-audit.json')
    original = next(r for r in closure['original_snapshots'] if r['path'] == ORIGIN + '/source.tar')
    require(original['sha256'] == manifest['source_tar_sha256'] and
            original['selected_files_byte_equal_to_original_git_tar'] is True and
            closure['diagnostic_main_src_bytes_equal_to_timing_current_src'] is True, 'Original source/closure binding differs')
    artifacts = load(files, 'artifact-bindings.json')['files']
    for name, record in artifacts.items():
        if name == 'source.tar':
            require(record['sha256'] == original['sha256'] and record['bytes'] == original['bytes'], 'Excluded source tar receipt differs')
        else:
            require(sha(files[name]) == record['sha256'] and len(files[name]) == record['bytes'], 'Diagnostic artifact differs: ' + name)
    build = load(files, 'build/exit.json')
    require(build['returncode'] == 0 and build['zig_version'] == '0.16.0' and
            build['executable_sha256'] == sha(files['install/bin/vort-br-quality-stage-profile']) and
            build['executable_bytes'] == len(files['install/bin/vort-br-quality-stage-profile']), 'Diagnostic build/ELF differs')
    for field, member in [('stdout_sha256', 'build/stdout.log'), ('stderr_sha256', 'build/stderr.log')]:
        require(build[field] == sha(files[member]), 'Diagnostic build logs differ')
    obj = load(files, 'build/record-object.json')
    require(obj['object_sha256'] == sha(files['build/record-optimal-releasefast.o']) and
            obj['source_sha256'] == sha(sources['current/src/br/encoder/record_optimal_object.zig']), 'Record object/source binding differs')
    terminal = load(files, 'profile-exit.json')
    require(terminal['returncode'] == 0 and terminal['diagnostic_only'] is True and
            terminal['profile_sha256'] == sha(files['profile.json']) and
            load(files, 'analyze-exit.json')['returncode'] == 0, 'Diagnostic actual terminal differs')
    report = load(files, 'profile.json')
    require(report['provenance']['executable_sha256'] == build['executable_sha256'], 'Profile ELF provenance differs')
    gate = gate_on_package(files, report)
    require(gate == load(files, 'root-profile-gate.json') and gate['validated_runs'] == 36,
            'Frozen Root gate output differs from package replay')
    gate_rows = {(r['path'], r['round']): r for r in gate['rows']}
    fixtures = {f['input_path']: f for f in manifest['fixtures']}
    require(len(fixtures) == len(report['rows']) == 12, 'Diagnostic corpus differs')
    stage_raw = load(files, 'stage-raw.json')
    require(stage_raw['all_ns_diagnostic_only'] is True and len(stage_raw['rows']) == 36, 'Stage raw inventory differs')
    raw_index = {(r['case'], r['round']): r for r in stage_raw['rows']}
    stages = {key: 0 for key in report['rows'][0]['rounds'][0]['profile']['exclusive_ns']}
    totals = {'trace_runs': 0, 'context_details_truncated_runs': 0, 'proposal_reuses_observed_prefix': 0,
              'successful_wire_materializations': 0, 'lost_wire_materializations': 0,
              'evaluation_attempts': 0, 'outer_ns': 0, 'unaccounted_ns': 0}
    for row in report['rows']:
        fixture = fixtures[row['path']]
        case = fixture['case']
        data, golden = files['fixtures/' + case + '.65536.plain'], files['golden/' + case + '.br']
        require(len(data) == row['input_bytes'] == 65536 and sha(data) == row['input_sha256'] == fixture['sha256'] and
                len(golden) == row['wire_bytes'] == fixture['golden_wire_bytes'] and
                sha(golden) == row['wire_sha256'] == fixture['golden_sha256'] and
                len(row['rounds']) == 3 and row['roundtrip_verified'] is True, 'Profile/golden/input identity differs')
        require(golden == timing['preflight/explicit16-' + case + '-current.br'], 'Fresh main initial wire differs from diagnostic saved gold')
        for run in row['rounds']:
            p = run['profile']
            raw = raw_index[case, run['index']]
            gate_row = gate_rows[row['path'], run['index']]
            details = p['context_details']
            reuse = sum(d['profile']['proposal_reuses'] for d in details)
            contexts = sum(e['stage'] == 'context_proposals' and not e['error_name'] for e in p['events'])
            require(p['events_total'] == p['event_count'] == len(p['events']) and p['events_truncated'] is False,
                    'Event/wire coverage differs')
            require(raw['normal_first'] == run['normal_first'] and raw['normal_ns_diagnostic_only'] == run['normal_ns'] and
                    raw['profile_call_ns_diagnostic_only'] == run['profile_call_ns'] and raw['outer_ns'] == p['outer_elapsed_ns'] and
                    raw['unaccounted_ns'] == p['unaccounted_ns'] and raw['event_count'] == p['event_count'] and
                    raw['context_details_truncated'] == p['context_details_truncated'] and
                    raw['context_details_recorded'] == len(details) and raw['context_proposal_events_full'] == contexts and
                    raw['proposal_reuses_observed_prefix'] == reuse and
                    raw['proposal_reuses_full'] == (None if p['context_details_truncated'] else reuse), 'Context prefix/raw accounting differs')
            for field in ['evaluation_attempts', 'wire_attempts', 'parameter_pairs', 'parameter_counted_candidates',
                          'parameter_physical_emits', 'parameter_skipped_pair_emits']:
                require(raw[field] == p[field], 'Diagnostic work counter differs')
            for field, value in gate_row['physical_wires'].items():
                require(raw[field] == value, 'Physical wire count differs')
            for field, value in p['exclusive_ns'].items():
                require(raw[field + '_exclusive_ns'] == value, 'Exclusive stage counter differs')
                stages[field] += value
            for field, source_field in [('observed_prefix_tree_score_calls', 'tree_score_calls'),
                                        ('observed_prefix_suffix_payload_scores', 'suffix_payload_scores'),
                                        ('observed_prefix_suffix_payload_reuses', 'suffix_payload_reuses'),
                                        ('observed_prefix_cluster_trials', 'cluster_trials')]:
                require(raw[field] == sum(d['profile'][source_field] for d in details), 'Observed prefix work counter differs')
            totals['trace_runs'] += 1
            totals['context_details_truncated_runs'] += p['context_details_truncated']
            totals['proposal_reuses_observed_prefix'] += reuse
            totals['successful_wire_materializations'] += gate_row['physical_wires']['successful_wire_materializations']
            totals['lost_wire_materializations'] += gate_row['physical_wires']['lost_wire_materializations']
            totals['evaluation_attempts'] += p['evaluation_attempts']
            totals['outer_ns'] += p['outer_elapsed_ns']
            totals['unaccounted_ns'] += p['unaccounted_ns']
    summary = load(files, 'summary.json')
    require(totals['trace_runs'] == summary['trace_runs'] == 36 and
            totals['context_details_truncated_runs'] == summary['context_details_truncated_runs'] == 18 and
            totals['proposal_reuses_observed_prefix'] == 87 and totals['successful_wire_materializations'] == 1029 and
            totals['lost_wire_materializations'] == 993 and totals['evaluation_attempts'] == 1746 and
            stages == summary['stage_exclusive_ns_total_over_36_traces'] and totals['outer_ns'] == summary['outer_ns_total'] and
            totals['unaccounted_ns'] == summary['unaccounted_ns_total'] and
            sum(stages.values()) + totals['unaccounted_ns'] == totals['outer_ns'], 'Complete diagnostic summary differs')
    require(summary['diagnostic_only'] is True and summary['normal_profile_ns_excluded_from_throughput_gates'] is True and
            summary['profile_sha256'] == sha(files['profile.json']), 'Diagnostic scope differs')
    per_case = {row['case']: row for row in summary['rows']}
    require(set(per_case) == {fixture['case'] for fixture in fixtures.values()}, 'Diagnostic summary row inventory differs')
    for case, saved in per_case.items():
        records = [raw_index[case, index] for index in range(3)]
        require(saved['rounds'] == 3 and saved['context_details_truncated_any'] ==
                any(r['context_details_truncated'] for r in records) and
                saved['proposal_reuses_full_per_round'] == (None if saved['context_details_truncated_any'] else
                                                            [r['proposal_reuses_full'] for r in records]),
                'Per-case context prefix interpretation differs')
        for field in ['event_count', 'evaluation_attempts', 'wire_attempts', 'context_proposal_events_full',
                      'context_details_recorded', 'proposal_reuses_observed_prefix', 'successful_wire_materializations',
                      'failed_wire_attempts', 'completed_wire_bytes_total', 'lost_wire_materializations',
                      'parameter_pairs', 'parameter_counted_candidates', 'parameter_physical_emits', 'parameter_skipped_pair_emits']:
            values = [r[field] for r in records]
            require(saved[field] == (values[0] if len(set(values)) == 1 else values), 'Per-case diagnostic count differs')
        for saved_field, raw_field in [('normal_ns_median_diagnostic_only', 'normal_ns_diagnostic_only'),
                                       ('profile_call_ns_median_diagnostic_only', 'profile_call_ns_diagnostic_only'),
                                       ('outer_ns_median', 'outer_ns'), ('unaccounted_ns_median', 'unaccounted_ns')]:
            require(saved[saved_field] == statistics.median(r[raw_field] for r in records), 'Per-case median differs')
        require(saved['exclusive_ns_median'] == {field: statistics.median(r[field + '_exclusive_ns'] for r in records)
                                                 for field in stages}, 'Per-case stage medians differ')
    for name in ['stage-exclusive.csv', 'physical-wire-counts.csv']:
        csv_rows = list(csv.DictReader(io.StringIO(files[name].decode())))
        require(len(csv_rows) == 36, 'Diagnostic CSV inventory differs')
        for csv_row in csv_rows:
            raw = raw_index[csv_row['case'], int(csv_row['round'])]
            for field, value in csv_row.items():
                require(value == ('' if raw[field] is None else str(raw[field])), 'Diagnostic CSV data differs')
    decoder = load(files, 'golden-libdecode.json')
    require(decoder['library_version'] == '1.2.0' and decoder['verified_saved_golden_wires'] == 12 and
            decoder['diagnostic_only'] is True, 'Saved golden decode scope differs')
    for library in decoder['libraries']:
        require(sha(files[closed_path(library['path'], ORIGIN)]) == library['sha256'], 'Saved golden reference identity differs')
    require(len(decoder['rows']) == 12, 'Saved golden decode receipt inventory differs')
    for row in decoder['rows']:
        require(row['decode_status'] == 1 and row['decoded_bytes'] == 65536 and row['decoded_equal'] is True and
                row['golden_sha256'] == sha(files['golden/' + row['case'] + '.br']) and
                row['input_sha256'] == sha(files['fixtures/' + row['case'] + '.65536.plain']),
                'Saved golden strict decode receipt differs')
    return {**totals, 'all_events_complete': True, 'stage_exclusive_ns': stages,
            'profile_sha256': sha(files['profile.json']), 'Root_gate_replay': True,
            'fresh_main_initial_wire_bytes_equal_to_saved_diagnostic_gold': True,
            'full_context_reuse_count_for_truncated_runs': None,
            'scope': 'Diagnostics only; prefix reuse87 observed; no full-count extrapolation, memory-traffic claim or throughput acceptance'}


def verify_gate_receipts(files, gate_source):
    receipt = load(files, 'root-gate/receipt.json')
    for name, digest in receipt['files'].items():
        require(sha(files['root-gate/' + name]) == digest, 'Frozen Root gate evidence differs')
    require(files['root-gate/quality_profile_gate.py'] == gate_source and receipt['actual_exit_code'] == 0 and
            receipt['steps_succeeded'] == 3 and receipt['report_tests'] == 24 and receipt['wire_count_tests'] == 11 and
            receipt['actual_main_profile_gate']['exit_code'] == 0 and receipt['actual_main_profile_gate']['runs'] == 36,
            'Root project or actual profile gate terminal differs')
    project = load(files, 'root-gate/project-gate.original-tool-result.json')
    require(project['exit_code'] == 0 and 'Ran 24 tests' in project['output'] and
            'Ran 11 tests' in project['output'] and 'Build Summary: 3/3 steps succeeded' in project['output'],
            'Root project gate original output differs')
    require(load(files, 'profile-gate-exit.json')['returncode'] == 1 and b'uncached baseline calls' in files['profile-gate.stderr'],
            'Original failed gate evidence was lost')
    tests = load(files, 'gate-adapter/tests-exit.json')
    require(tests.get('returncode', tests.get('exit_code')) == 0 and b'Ran 6 tests' in files['gate-adapter/tests.stderr'] and
            load(files, 'gate-adapter/final-gate-exit.json').get('returncode', 0) == 0,
            'Temporary gate adapter six-test evidence differs')
    return {'root_project_steps': 3, 'root_report_tests': 24, 'root_wire_count_tests': 11,
            'tmp_adapter_tests': 6, 'original_gate_exit': 1, 'Root_actual_main_gate_exit': 0,
            'scope': 'Stored actual test/gate receipts and byte-identical frozen gate replay; no test/build/codec rerun'}
