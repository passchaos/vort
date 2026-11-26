"""Independent data-only replay of the two-pair global entropy-bound pilot."""
from datetime import datetime
import math
from package_io import bench_member, load, require, sha

ORIGIN = '/tmp/vort-br-global-entropy-bound-ab.lf41tsx3/benchmark'


def process(bench, settings, fixture, label, member, iterations):
    raw, command = load(bench, member), load(bench, member.removesuffix('.json') + '.command.json')
    expected = ['taskset', '-c', '2', ORIGIN + '/bin/' + label, '--input', fixture['path'], '--output', ORIGIN + '/' + member,
                '--source-revision', settings['variants'][label], '--iterations', str(iterations), '--window', '16']
    if iterations == 0:
        expected += ['--wire-output', ORIGIN + '/' + member.removesuffix('.json') + '.br']
    require(command['command'] == expected and command['exit_code'] == 0 and command['elapsed_seconds'] > 0 and
            raw['provenance']['command'] == ' '.join(expected[3:]), 'Captured pilot process command/exit differs')
    require(bench[member.removesuffix('.json') + '.stdout'] == bench[member.removesuffix('.json') + '.stderr'] == b'',
            'Captured process stream output differs')
    require(raw['schema'] == 'vort.q8-source-history-ab.process.v1' and raw['source_revision'] == settings['variants'][label] and
            raw['input_path'] == fixture['path'] and raw['input_bytes'] == fixture['bytes'] == 65536 and
            raw['input_sha256'] == fixture['sha256'] and raw['allocator'] == 'std.process.Init.gpa' and
            (raw['quality'], raw['mode'], raw['requested_window_bits']) == (8, 'generic', 16) and
            raw['iterations'] == iterations and raw['warmup_owned_encode_free_calls'] == 1 and len(raw['samples']) == iterations,
            'Allocating public process lifecycle/options differ')
    p = raw['provenance']
    require((p['optimize'], p['zig_version'], p['target_arch'], p['target_os'], p['target_abi'], p['target_cpu'],
             p['cpu_affinity'], p['affinity_cpu_count'], p['benchmark_threads'], p['codec_thread_policy']) ==
            ('ReleaseFast', '0.16.0', 'x86_64', 'linux', 'gnu', 'skylake+pku+sgx', '2', 1, 1, 'single') and
            p['executable_sha256'] == sha(bench['bin/' + label]), 'Process target/thread/ELF differs')
    require(raw['timing_scope'] == 'Continuous owned allocating public encode, wire-length mix and free. SHA256 and cross-library decode validate only the initial complete wire, outside timing.' and
            raw['wire_identity_scope'] == 'initial_wire_only; timed outputs check lengths/mix, not complete SHA256', 'Timer scope differs')
    for sample in raw['samples']:
        require(sample['index'] == 0 and type(sample['owned_encode_free_ns']) is int and sample['owned_encode_free_ns'] > 0 and
                sample['owned_encode_free_ns'] <= command['elapsed_seconds'] * 1e9 and
                sample['wire_bytes'] == sample['mix'] == raw['warm_wire_bytes'], 'Timed raw length/mix differs')
    return raw, command


def verify_pilot(bench):
    settings = load(bench, 'settings.json')
    require(settings['primary_options'] == {'quality': 8, 'mode': 'generic', 'window_bits': 16} and
            settings['automatic_default_lane'] is False and settings['lane'] == 'explicit16' and
            settings['pilot']['total_pairs'] == 24 and settings['pilot']['total_processes'] == 48 and
            settings['acceptance_gate'] == {'target_speedup_gm_min': 1.03, 'primary_matrix_paired_CI_excludes_parity': True,
                                             'all_row_speedup_floor': 0.98, 'wire_exact': True}, 'Frozen pilot/gate policy differs')
    fixtures = load(bench, 'fixtures.json')
    require(len(fixtures) == 12 and len({f['case'] for f in fixtures}) == 12, 'Pilot input matrix differs')
    indexed = {f['case']: f for f in fixtures}
    pre = load(bench, 'preflight-summary.json')
    require(pre['all_CF_candidate_fullwire_equal'] is True and pre['lanes'] == ['explicit16'] and len(pre['rows']) == 24,
            'Fixed wire preflight matrix differs')
    saved_wire = {}
    pre_files = set()
    for fixture in fixtures:
        require(sha(bench[bench_member(fixture['path'])]) == fixture['sha256'] and len(bench[bench_member(fixture['path'])]) == 65536,
                'Full fixture bytes differ')
        golden = bench[bench_member(fixture['golden_path'])]
        for label in ['old_exact', 'current']:
            name = 'preflight/explicit16-' + fixture['case'] + '-' + label + '.json'
            raw, _ = process(bench, settings, fixture, label, name, 0)
            pre_files.update(name.removesuffix('.json') + '.' + extension for extension in ['json', 'command.json', 'br', 'stdout', 'stderr'])
            row = next(r for r in pre['rows'] if r['case'] == fixture['case'] and r['variant'] == label)
            wire = bench[name.removesuffix('.json') + '.br']
            require(wire == golden and sha(wire) == row['wire_sha256'] == raw['warm_wire_sha256'] and
                    len(wire) == row['wire_bytes'] == raw['warm_wire_bytes'] and row['pinned_decode_verified'] is True and
                    row['actual_window_bits'] == 16 and not wire[0] & 1, 'Complete CF/candidate/C2 wire identity differs')
            saved_wire[fixture['case'], label] = row
    require({name for name in bench if name.startswith('preflight/')} == pre_files, 'Preflight sidecar set differs')
    decoder = load(bench, 'decoder-binding.json')
    # This independent global epoch records one decoder-binding.json. Do not
    # substitute a local epoch's before-pilot file that is absent here.
    for item in [decoder]:
        require(item['version'] == '1.2.0' and item['version_number'] == 0x01002000, 'Pinned reference version differs')
        for record in item['files']:
            data = bench[bench_member(record['path'])]
            require(sha(data) == record['sha256'] and len(data) == record['bytes'], 'Pinned decoder library bytes differ')
    release = load(bench, 'HEAVY0')
    terminal = load(bench, 'pilot-exit.json')
    require(release['phase'] == 'pilot' and release['timing_authorized'] is True and release['HEAVY'] == 0 and
            release['source_files'] == 2211 and terminal['exit_code'] == 0 and
            terminal['expected_pairs'] == 24 and terminal.get('expected_processes', terminal.get('expected_calls')) == 48 and bench['pilot.stderr'] == b'',
            'Pilot Root release/actual terminal differs')
    start = datetime.fromisoformat(terminal['started_utc']).timestamp()
    end = datetime.fromisoformat(terminal['completed_utc']).timestamp()
    require(datetime.fromisoformat(release['utc']).timestamp() <= start <= end, 'Release/pilot chronology differs')
    manifest = load(bench, 'pilot/run-manifest.json')
    require(manifest['phase'] == 'pilot' and 'completed' in manifest and manifest['settings'] == settings and
            [(p['round'], p['case']) for p in manifest['pairs']] == [(r, f['case']) for r in [0, 1] for f in fixtures],
            'Pilot schedule or terminal differs')
    ratios, by_case, expected_files, checks = [], {f['case']: [] for f in fixtures}, set(), []
    for pair in manifest['pairs']:
        order = ['old_exact', 'current'] if pair['round'] == 0 else ['current', 'old_exact']
        require(pair['order'] == order and pair['lane'] == 'explicit16', 'AB/BA order differs')
        times = {}
        previous_end = None
        for label in order:
            member = bench_member(pair['processes'][label]['path'])
            require(member == 'pilot/runs/explicit16-' + str(pair['round']).zfill(2) + '-' + pair['case'] + '-' + label + '.json',
                    'Pilot raw path differs')
            raw, command = process(bench, settings, indexed[pair['case']], label, member, 1)
            require(start <= command['started_unix'] <= end and command['started_unix'] + command['elapsed_seconds'] <= end + 0.001 and
                    (previous_end is None or command['started_unix'] >= previous_end - 0.001), 'Pilot interval/order differs')
            previous_end = command['started_unix'] + command['elapsed_seconds']
            ns = raw['samples'][0]['owned_encode_free_ns']
            wire = saved_wire[pair['case'], label]
            require(pair['processes'][label]['raw_ns'] == [ns] and raw['warm_wire_sha256'] == wire['wire_sha256'] and
                    raw['warm_wire_bytes'] == wire['wire_bytes'], 'Pilot initial-wire/raw binding differs')
            expected_files.update(member.removesuffix('.json') + '.' + suffix for suffix in ['json', 'command.json', 'stdout', 'stderr'])
            times[label] = ns
            checks.append({'case': pair['case'], 'round': pair['round'], 'variant': label, 'path': ORIGIN + '/' + member,
                           'source_revision': raw['source_revision'], 'ELF_sha256': raw['provenance']['executable_sha256'],
                           'input_sha256': raw['input_sha256'], 'warm_wire_sha256': raw['warm_wire_sha256'], 'raw_ns': ns, 'checks_pass': True})
        ratio = times['old_exact'] / times['current']
        ratios.append(ratio)
        by_case[pair['case']].append(ratio)
    require(len(ratios) == 24 and {name for name in bench if name.startswith('pilot/runs/')} == expected_files,
            'Complete 24pair/48process capture differs')
    gm = math.exp(math.fsum(math.log(r) for r in ratios) / 24)
    rows = [{'case': case, 'pairs': 2, 'speedup_geomean': math.exp(math.fsum(math.log(r) for r in values) / 2),
             'raw_speedups': values} for case, values in by_case.items()]
    reported = load(bench, 'pilot-summary.json')
    require(reported['pairs'] == 24 and reported['process_records'] == 48 and reported['completed'] is True and
            math.isclose(gm, reported['target_speedup_geomean'], rel_tol=1e-12) and reported['CI'] is None and
            reported['ROI_point_estimate_positive'] is False and gm < 1.03 and reported['wire_exact'] is True,
            'Global pilot rejection/CI scope differs')
    for actual, saved in zip(rows, reported['rows'], strict=True):
        require(actual['case'] == saved['case'] and actual['raw_speedups'] == saved['raw_speedups'] and
                math.isclose(actual['speedup_geomean'], saved['speedup_geomean'], rel_tol=1e-12) and
                saved['floor_pass'] == (actual['speedup_geomean'] >= 0.98), 'Per-row pilot statistic differs')
    require(all(row['speedup_geomean'] >= 0.98 for row in rows) and reported['all_row_floor_pass'] is True, 'Pilot row floors differ')
    independent = load(bench, 'pilot-independent-verification.json')
    require(independent['all_checks_pass'] is True and independent['pairs'] == 24 and independent['processes'] == 48 and
            independent['process_checks'] == checks and math.isclose(independent['independent_target_speedup_GM'], gm, rel_tol=1e-12) and
            independent['CI'] is None and independent['standalone_local_gate_accept'] is False and
            independent['full_approved_exists'] is False and independent['full_matrix_started'] is False, 'Original independent receipt differs')
    for path, digest in independent['raw_file_sha256'].items():
        require(sha(bench[bench_member(path)]) == digest, 'Independent raw SHA binding differs')
    verification_exit = load(bench, 'pilot-verifier-exit.json')
    require(verification_exit['returncode'] == 0 and verification_exit['verifier_sha256'] == sha(bench['verify_pilot_independent.py']) and
            verification_exit['result_sha256'] == sha(bench['pilot-independent-verification.json']), 'Original independent verifier actual exit/hash differs')
    require(load(bench, 'full-absence.json') == {'FULL_APPROVED': False, 'run-manifest.json': False, 'runs_files': 0,
                                               'scope': 'Captured absence at archival time; not authorization'}, 'Full absence inventory differs')
    require(not any(name == 'FULL_APPROVED' or name == 'run-manifest.json' or name.startswith('runs/') for name in bench),
            'Global archive contains approved/full output')
    return {'pairs': 24, 'processes': 48, 'point_estimate_speedup_GM': gm, 'all_row_floor_pass': True,
            'CI': None, 'accepted': False, 'full_approved': False, 'full_started': False,
            'complete_initial_wires': 24, 'rows': rows, 'pilot_wall_seconds': end - start,
            'scope': 'Descriptive two-pair pilot only, initial fullwire/decode receipts and timed length/mix; no formal CI or performance recovery claim'}
