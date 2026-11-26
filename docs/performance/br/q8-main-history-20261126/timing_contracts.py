"""Verify allocating public q8 capture metadata, input and initial wire bytes."""
import csv
from datetime import datetime
import io
from package_io import closed_path, load, require, sha, virtual_source

ORIGIN = '/tmp/vort-q8-main-ab.cHiG58'
REVISIONS = {'old_exact': '0a673757ea6a1e88b90794ad44dce1a8a824f371',
             'current': '8ccd54a59da850da724cc4d6ca79a727c659889e'}


def verify_process(files, name, fixture, iterations, member):
    record = load(files, member)
    command_member = member.removesuffix('.json') + '.command.json'
    command = load(files, command_member)
    provenance = record['provenance']
    require(record['schema'] == 'vort.q8-source-history-ab.process.v1' and record['source_revision'] == REVISIONS[name],
            'Source revision or process schema differs')
    require(record['allocator'] == 'std.process.Init.gpa' and record['quality'] == 8 and record['mode'] == 'generic' and
            record['requested_window_bits'] == 16 and record['iterations'] == iterations and
            record['warmup_owned_encode_free_calls'] == 1, 'Public allocating q8 lifecycle differs')
    require(record['timing_scope'] == 'Continuous owned allocating public encode, wire-length mix and free. SHA256 and cross-library decode validate only the initial complete wire, outside timing.' and
            record['wire_identity_scope'] == 'initial_wire_only; timed outputs check lengths/mix, not complete SHA256',
            'Captured timer scope differs')
    require(record['input_path'] == fixture['path'] and record['input_bytes'] == fixture['bytes'] == 65536 and
            record['input_sha256'] == fixture['sha256'], 'Process input differs')
    require((provenance['optimize'], provenance['target_arch'], provenance['target_os'], provenance['target_abi'],
             provenance['target_cpu'], provenance['zig_version'], provenance['cpu_affinity'],
             provenance['affinity_cpu_count'], provenance['benchmark_threads'], provenance['codec_thread_policy']) ==
            ('ReleaseFast', 'x86_64', 'linux', 'gnu', 'skylake+pku+sgx', '0.16.0', '2', 1, 1, 'single'),
            'Captured CPU/build/thread policy differs')
    builds = load(files, 'build-results.json')
    require(provenance['executable_sha256'] == builds[name]['executable_sha256'] == sha(files['bin/' + name]),
            'Process ELF differs')
    argv = ['taskset', '-c', '2', ORIGIN + '/bin/' + name, '--input', fixture['path'], '--output', ORIGIN + '/' + member,
            '--source-revision', REVISIONS[name], '--iterations', str(iterations), '--window', '16']
    if iterations == 0:
        argv += ['--wire-output', ORIGIN + '/' + member.removesuffix('.json') + '.br']
    require(command['exit_code'] == 0 and command['command'] == argv and command['elapsed_seconds'] > 0 and
            provenance['command'] == ' '.join(argv[3:]), 'Captured process argv differs')
    stem = member.removesuffix('.json')
    require(files[stem + '.stderr'] == files[stem + '.stdout'] == b'', 'Unexpected process stream output')
    require(len(record['samples']) == iterations, 'Process sample count differs')
    for index, sample in enumerate(record['samples']):
        require(sample['index'] == index and sample['owned_encode_free_ns'] > 0 and
                sample['wire_bytes'] == sample['mix'] == record['warm_wire_bytes'], 'Timed length/mix contract differs')
    return record, command


def verify_timing(files, sources):
    settings = load(files, 'settings.json')
    require(settings['variants'] == REVISIONS and settings['primary_options'] == {'quality': 8, 'mode': 'generic', 'window_bits': 16} and
            settings['rounds'] == settings['weak_rows_additional_rounds'] == 6 and settings['initial_iterations'] == 1 and
            settings['target'] == 'x86_64-linux-gnu' and settings['cpu'] == 'skylake+pku+sgx' and
            settings['sampling_cpu'] == 2 and settings['codec_threads'] == 1, 'Original q8 sampling policy differs')
    source = load(files, 'input-source-binding.json')
    builds = load(files, 'build-results.json')
    binding = load(files, 'preflight-binding.json')
    for name, count in [('current', 2200), ('old_exact', 1690)]:
        manifest = load(files, name + '-src-manifest.json')
        src = virtual_source(sources, name + '/src/')
        actual = {'src/' + key: sha(data) for key, data in src.items()}
        require(len(actual) == count and set(actual) == set(manifest['files']) and manifest['revision'] == REVISIONS[name],
                'Frozen compiled source universe differs')
        for member, record in manifest['files'].items():
            require(actual[member] == record['sha256'] and len(sources[name + '/' + member]) == record['bytes'],
                    'Frozen compiled source bytes differ')
        meta = source['isolated_source'][name]
        require(meta['source_manifest_sha256'] == sha(files[name + '-src-manifest.json']) and meta['revision'] == REVISIONS[name] and
                meta['src_tree'] == manifest['src_tree'] and meta['files'] == count, 'Source manifest binding differs')
        build = builds[name]
        require(build['success'] is True and build['revision'] == REVISIONS[name] and
                build['executable_sha256'] == sha(files['bin/' + name]) and
                len(build['stages']) == 2 and all(s['exit_code'] == 0 for s in build['stages']), 'Build terminal differs')
        obj = files['build/' + name + '-record.o']
        require(binding['probes'][name]['record_object_sha256'] == sha(obj) and
                binding['probes'][name]['record_object_bytes'] == len(obj), 'Linked object identity differs')
        for stage in build['stages']:
            require(all(value in stage['command'] for value in ['ReleaseFast', settings['target'], settings['cpu']]),
                    'Compiler settings differ')
        argv = build['stages'][1]['command']
        require(ORIGIN + '/build/' + name + '-record.o' in argv and
                '-Mvort_br=' + ORIGIN + '/sources/' + name + '/src/br.zig' in argv and
                '-Mroot=' + ORIGIN + '/probe.zig' in argv and '-Mprovenance=' + ORIGIN + '/provenance.zig' in argv,
                'Compiler input closure differs')
    for member, digest in source['scripts'].items():
        require(sha(files[member]) == digest, 'Archived common harness changed')
    decoder = load(files, 'decoder-binding.json')
    require(decoder['version'] == '1.2.0' and decoder['version_number'] == 0x1002000, 'Pinned decoder version differs')
    for reference in decoder['files']:
        member = closed_path(reference['path'], ORIGIN)
        require(sha(files[member]) == reference['sha256'] and len(files[member]) == reference['bytes'], 'Pinned reference bytes differ')
    for name, digest in source['references'].items():
        require(sha(files['references/' + name]) == digest, 'Pinned decoder closure differs')
    fixtures = load(files, 'fixtures.json')
    require(len(fixtures) == 12 and len({f['case'] for f in fixtures}) == 12, 'Input matrix differs')
    indexed = {f['case']: f for f in fixtures}
    for fixture in fixtures:
        data = files['fixtures/' + fixture['case'] + '.65536.plain']
        require(len(data) == fixture['bytes'] == 65536 and sha(data) == fixture['sha256'], 'Input bytes differ')
    preflight = load(files, 'preflight-summary.json')
    require(preflight['lanes'] == ['explicit16'] and len(preflight['rows']) == 24, 'Initial wire preflight incomplete')
    pinned = {}
    prior = load(files, 'prior-wire-audit.json')
    require(prior['archive_sha256'] == source['archive_sha256'] and len(prior['retained_members']) == 24,
            'Prior initial-wire dependency archive binding differs')
    for row in preflight['rows']:
        case, name = row['case'], row['variant']
        member = 'preflight/explicit16-' + case + '-' + name + '.json'
        record, _ = verify_process(files, name, indexed[case], 0, member)
        wire = files[member.removesuffix('.json') + '.br']
        require(row['wire_sha256'] == record['warm_wire_sha256'] == sha(wire) and
                row['wire_bytes'] == record['warm_wire_bytes'] == len(wire) and row['actual_window_bits'] == 16 and
                row['input_sha256'] == indexed[case]['sha256'] and row['pinned_decode_verified'] is True,
                'Complete initial wire/decode receipt differs')
        require(binding['cases'][case][name]['wire_sha256'] == sha(wire) and
                binding['cases'][case][name]['matches_prior_epoch_same_label_wire'] is True, 'Prior wire binding differs')
        previous = files['prior-wires/' + member.removesuffix('.json').rsplit('/', 1)[-1] + '.br']
        require(wire == previous and prior['retained_members'][member.removesuffix('.json') + '.br'] ==
                {'bytes': len(wire), 'sha256': sha(wire)}, 'New/prior complete wire bytes differ')
        pinned[case, name] = row
    expected_preflight = {'preflight/explicit16-' + f['case'] + '-' + name + '.' + extension
                          for f in fixtures for name in REVISIONS
                          for extension in ['json', 'command.json', 'br', 'stdout', 'stderr']}
    require({name for name in files if name.startswith('preflight/')} == expected_preflight,
            'Initial wire process sidecar inventory differs')
    manifest = load(files, 'run-manifest.json')
    require('completed' in manifest and manifest['settings'] == settings and len(manifest['pairs']) == 90,
            'Completed timing matrix differs')
    expected = [(round_index, f['case']) for round_index in range(12) for f in fixtures
                if round_index < 6 or f['case'] in ['dickens', 'mozilla', 'nci']]
    require([(p['round'], p['case']) for p in manifest['pairs']] == expected, 'Sampling sequence differs')
    raw_csv = list(csv.DictReader(io.StringIO(files['raw-pairs.csv'].decode())))
    require(len(raw_csv) == 90, 'Raw paired CSV incomplete')
    csv_index = {(r['case'], int(r['round'])): r for r in raw_csv}
    process_records = {}
    expected_sidecars = set()
    previous_end = 0
    for pair in manifest['pairs']:
        order = ['old_exact', 'current'] if pair['round'] % 2 == 0 else ['current', 'old_exact']
        require(pair['lane'] == 'explicit16' and pair['order'] == order and set(pair['processes']) == set(REVISIONS),
                'Interleaved pair order differs')
        for name in order:
            captured = pair['processes'][name]
            member = closed_path(captured['path'], ORIGIN)
            require(member == 'runs/explicit16-' + str(pair['round']).zfill(2) + '-' + pair['case'] + '-' + name + '.json',
                    'Timed process path differs from schedule')
            record, command = verify_process(files, name, indexed[pair['case']], 1, member)
            require(captured['raw_ns'] == [record['samples'][0]['owned_encode_free_ns']] and
                    (record['warm_wire_bytes'], record['warm_wire_sha256']) ==
                    (pinned[pair['case'], name]['wire_bytes'], pinned[pair['case'], name]['wire_sha256']),
                    'Timed sample/initial wire binding differs')
            require(command['started_unix'] >= previous_end, 'Captured timed process order overlaps')
            previous_end = command['started_unix'] + command['elapsed_seconds']
            process_records[member] = record
            expected_sidecars.update(member.removesuffix('.json') + '.' + extension
                                     for extension in ['json', 'command.json', 'stdout', 'stderr'])
        row = csv_index[pair['case'], pair['round']]
        old, current = pair['processes']['old_exact']['raw_ns'][0], pair['processes']['current']['raw_ns'][0]
        require(row['lane'] == pair['lane'] and row['order'] == '/'.join(order) and int(row['old_ns']) == old and
                int(row['current_ns']) == current and float(row['current_over_old_ns_ratio']) == current / old,
                'Raw CSV pair differs from captured data')
    require(len(process_records) == 180, 'Timed process records incomplete')
    require({name for name in files if name.startswith('runs/')} == expected_sidecars,
            'Timed process raw sidecar inventory differs')
    for name in ['sampling-exit.json', 'analysis-exit.json']:
        require(load(files, name)['exit_code'] == 0, 'Sampling/analysis actual terminal failed')
    require(files['sampling.stderr'] == files['analysis.stderr'] == b'', 'Sampling/analysis stderr differs')
    release = load(files, 'ROOT-HEAVY0.json')
    require(release['HEAVY'] == 0 and release['timing_authorized'] is True and
            release['settings_sha256'] == sha(files['settings.json']) and
            release['preflight_binding_sha256'] == sha(files['preflight-binding.json']), 'Root sampling release binding differs')
    terminal = load(files, 'sampling-exit.json')
    duration = (datetime.fromisoformat(terminal['completed_utc']) - datetime.fromisoformat(terminal['started_utc'])).total_seconds()
    return {'pairs': 90, 'timed_calls': 180, 'complete_initial_wires': 24, 'source_files': {'current': 2200, 'old_exact': 1690},
            'sampling_actual_exit_code': 0, 'analysis_actual_exit_code': 0, 'sampling_wall_seconds': duration,
            'root_HEAVY0_authorization_verified': True, 'scope': 'Allocating public encode/mix/free; timed length/mix only; captured pinned initial-wire decode, no codec rerun'}, process_records
