"""Verify source epochs, stored build terminals, wires and observer scope."""
import re
from package_io import captured_member, load, read_tar, require, sha


def function_bytes(data, name):
    text = data.decode()
    match = re.search(r'\bfn\s+' + re.escape(name) + r'\s*\(', text)
    require(match is not None, 'Unchanged function missing')
    opening = text.index('{', match.start())
    depth, end = 1, opening + 1
    while depth:
        if text[end] == '{':
            depth += 1
        elif text[end] == '}':
            depth -= 1
        end += 1
    return text[match.start():end].encode()


def verify_source(sources, evidence):
    baseline = read_tar(sources['source-baseline.tar'], 'r:', directories=True)
    manifest = load(evidence, 'manifest.json')
    require(sha(sources['source-baseline.tar']) == manifest['source_baseline_tar_sha256'] and
            len(sources['source-baseline.tar']) == manifest['source_baseline_tar_bytes'] and
            {name: sha(data) for name, data in baseline.items()} == load(evidence, 'baseline-files.json'),
            'Frozen baseline compile closure differs')
    for name in baseline:
        require(name in ['build.zig', 'build.zig.zon'] or name.startswith(('src/', 'build/', 'tools/')),
                'Baseline includes non-compile input')
    current = dict(baseline)
    deltas = load(evidence, 'instrumentation-files.json')
    require(len(deltas) == 6 and len({r['path'] for r in deltas}) == 6, 'Instrumentation delta inventory differs')
    for record in deltas:
        name = record['path']
        before = sha(baseline[name]) if name in baseline else None
        data = sources['overlay/' + name]
        require(before == record['old_sha256'] and sha(data) == record['new_sha256'], 'Instrumentation bytes differ')
        current[name] = data
    epoch = load(sources, 'source-epochs.json')
    require(len(baseline) == epoch['baseline_files'] == 2992 and len(current) == epoch['candidate_files'] == 2995 and
            {name: {'bytes': len(data), 'sha256': sha(data)} for name, data in current.items()} == epoch['candidate'],
            'Candidate source reconstruction differs')
    require(not any('adaptive_distance_candidate' in name for name in current), 'Separate optimization epoch entered archive')
    fix = load(evidence, 'io-compatibility-fix.json')
    driver = current['tools/br/complex_header_diagnostic.zig']
    old_driver = sources[epoch['attempt1_driver_path']]
    require(driver.count(b'.limited(65537)') == 1 and old_driver == driver.replace(b'.limited(65537)', b'.limited(65536)') and
            sha(driver) == fix['new_driver_sha256'] and sha(old_driver) == fix['old_driver_sha256'] == epoch['attempt1_driver_sha256'],
            'First/final driver EOF-limit epoch differs')
    require(fix['original_error'] == 'StreamTooLong' and fix['original_codec_calls'] == 0 and
            fix['input_size_contract'] == 65536 and fix['observer_capacity_unchanged'] == 131072 and
            fix['codec_source_unchanged'] is True and b'if (input.len != 65536)' in driver,
            'EOF failure/correction scope differs')
    for record in load(evidence, 'builder-unchanged-proof.json'):
        before, after = baseline[record['path']], current[record['path']]
        if 'function' in record:
            before, after = function_bytes(before, record['function']), function_bytes(after, record['function'])
            require(record['exact_body_unchanged'] is True, 'Builder unchanged-body flag differs')
        else:
            require(record['whole_file_unchanged'] is True, 'Builder/cache unchanged-file flag differs')
        require(before == after and sha(after) == record['sha256'], 'Original builder/cache proof differs')
    vail = read_tar(sources['vail-dependency.tar'], 'r:', directories=True)
    require(all(sources['vail/' + name] == data for name, data in vail.items()), 'Vail dependency bytes differ')
    return {'baseline_compile_files': len(baseline), 'final_compile_files': len(current), 'instrumentation_files': 6,
            'baseline_and_overlay_verified': True, 'unchanged_builder_and_cache_hashes_verified': True,
            'first_driver_reconstructed_to_original_SHA': True,
            'scope': 'Frozen8ccd compile closure and observer instrumentation; separate adaptive-distance epoch excluded'}, current


def verify_receipts(evidence, sources, current):
    for name, record in load(evidence, 'artifact-bindings.json')['files'].items():
        if name.startswith('source/'):
            data = current[name.removeprefix('source/')]
        elif name in ['source-baseline.tar', 'vail-dependency.tar']:
            data = sources[name]
        else:
            data = evidence[name]
        require(len(data) == record['bytes'] and sha(data) == record['sha256'], 'Captured artifact binding differs: ' + name)
    for prefix, binary in [('build/attempt1/', 'build/attempt1/diagnostic.elf'),
                           ('build/', 'install/bin/vort-br-complex-header-observe')]:
        terminal = load(evidence, prefix + 'exit.json')
        require(terminal['returncode'] == 0 and terminal['executable_sha256'] == sha(evidence[binary]) and
                terminal['executable_bytes'] == len(evidence[binary]), 'Build/ELF epoch identity differs')
        for field, suffix in [('stdout_sha256', 'stdout.log'), ('stderr_sha256', 'stderr.log')]:
            require(terminal[field] == sha(evidence[prefix + suffix]), 'Build terminal log differs')
        for option in ['-Dtarget=x86_64-linux-gnu', '-Dcpu=skylake+pku+sgx', '-Doptimize=ReleaseFast',
                       'build-br-complex-header-observe']:
            require(option in terminal['argv'], 'Builder options differ')
    failed = load(evidence, 'capture-attempt1/capture-exit.json')
    require(failed['returncode'] == 1 and b'StreamTooLong' in evidence['capture-attempt1/capture.stderr'] and
            failed['stderr_sha256'] == sha(evidence['capture-attempt1/capture.stderr']), 'Original pre-codec failure differs')
    for receipt, stdout, stderr in [('capture-exit.json', 'capture.stdout', 'capture.stderr'),
                                    ('analysis-exit.json', 'analysis.stdout', 'analysis.stderr'),
                                    ('memo-tests-exit.json', 'memo-tests.stdout', 'memo-tests.stderr')]:
        terminal = load(evidence, receipt)
        require(terminal['returncode'] == 0 and terminal['stdout_sha256'] == sha(evidence[stdout]) and
                terminal['stderr_sha256'] == sha(evidence[stderr]), 'Actual terminal/log identity differs')
    require(b'Ran 4 tests' in evidence['memo-tests.stderr'] and b'\nOK\n' in evidence['memo-tests.stderr'],
            'Original four exact-key tests output differs')
    require(load(evidence, 'capture-exit.json')['diagnostic_sha256'] == sha(evidence['diagnostic.json']),
            'Diagnostic output differs from actual capture receipt')
    return {'build_epochs': 2, 'successful_capture_actual_exit': 0, 'original_capture_exit': 1,
            'original_capture_codec_calls': 0, 'analysis_actual_exit': 0, 'original_python_exact_key_tests': 4,
            'scope': 'Stored original tests/build/capture terminals only; no programs or tests were rerun'}


def verify_capture(evidence):
    manifest = load(evidence, 'manifest.json')
    report = load(evidence, 'diagnostic.json')
    require(manifest['source_commit'] == '8ccd54a59da850da724cc4d6ca79a727c659889e' and
            manifest['quality'] == report['quality'] == 8 and manifest['mode'] == report['mode'] == 'generic' and
            manifest['window_bits'] == report['window_bits'] == 16 and manifest['rounds_per_row'] == 1 and
            manifest['observation_only'] is True and manifest['original_builder_and_all_candidates_execute'] is True and
            report['diagnostic_only'] is True, 'Header observation policy differs')
    provenance = report['provenance']
    require((provenance['optimize'], provenance['target_arch'], provenance['target_os'], provenance['target_abi'],
             provenance['target_cpu'], provenance['zig_version'], provenance['cpu_affinity'], provenance['affinity_cpu_count'],
             provenance['benchmark_threads'], provenance['codec_thread_policy']) ==
            ('ReleaseFast', 'x86_64', 'linux', 'gnu', 'skylake+pku+sgx', '0.16.0', '2', 1, 1, 'single'),
            'Diagnostic CPU/build policy differs')
    require(provenance['executable_sha256'] == manifest['final_executable_sha256'] ==
            sha(evidence['install/bin/vort-br-complex-header-observe']), 'Observer ELF identity differs')
    memory = report['observer_memory']
    require(memory == {'capacity_per_row': 131072, 'record_bytes': 280, 'payload_bytes': 36700160,
                       'inline_owner_bytes': 56, 'tls_pointer_bytes': 8, 'profile_state_bytes_separate': 178464,
                       'scope': 'Caller diagnostic requested heap; excludes allocator bookkeeping and I/O/JSON. No encoder resource improvement.'},
            'Observer allocation scope differs')
    fixtures = manifest['fixtures']
    verification = load(evidence, 'capture-verification.json')
    require(len(fixtures) == len(report['rows']) == len(verification['rows']) == 12 and
            len({f['case'] for f in fixtures}) == 12, 'Complete normal/trace corpus differs')
    rows = []
    expected_files = set()
    for index, (fixture, row, checked) in enumerate(zip(fixtures, report['rows'], verification['rows'], strict=True)):
        case = fixture['case']
        raw_name = 'capture/header-' + str(index) + '.json'
        raw = load(evidence, raw_name)
        expected_files.update([raw_name, 'capture/normal-' + str(index) + '.br', 'capture/trace-' + str(index) + '.br'])
        normal, trace, gold = [evidence[name] for name in ['capture/normal-' + str(index) + '.br',
                                                         'capture/trace-' + str(index) + '.br', 'golden/' + case + '.br']]
        data = evidence['fixtures/' + case + '.plain']
        require(normal == trace == gold and sha(gold) == row['wire_sha256'] == fixture['golden_sha256'] == checked['wire_sha256'] and
                len(gold) == row['wire_bytes'] == fixture['golden_wire_bytes'] and
                sha(data) == row['input_sha256'] == fixture['sha256'] == checked['input_sha256'] and
                len(data) == row['input_bytes'] == fixture['bytes'] == 65536, 'Normal/trace/gold/input bytes differ')
        require(captured_member(row['raw_path']) == raw_name and row['input_path'] == fixture['input_path'] and
                row['golden_path'] == fixture['golden_path'] and checked['case'] == case and
                checked['normal_trace_gold_fullbyte_equal'] is True and checked['normal_trace_roundtrip_asserted'] is True and
                row['normal_trace_oracle_fullbyte_equal'] is True and row['normal_trace_roundtrip'] is True,
                'Capture wire/roundtrip assertion differs')
        require(raw['schema'] == 'vort.brotli.complex-header-requests.v1' and raw['policy_id'] == 1 and raw['failures'] == 0 and
                raw['requests'] == row['request_count'] == checked['requests'] == len(raw['records']) and
                raw['analysis_calls'] == row['analysis_calls'] and checked['raw_sha256'] == sha(evidence[raw_name]) and
                checked['payload_used_bytes'] == len(raw['records']) * memory['record_bytes'], 'Header capture completeness differs')
        rows.append((fixture, row, raw))
    require({name for name in evidence if name.startswith('capture/')} == expected_files, 'Raw capture file inventory differs')
    require(verification['all_requests_captured'] is True and verification['overflows'] == verification['header_failures'] == 0 and
            verification['capacity_payload_bytes'] == memory['payload_bytes'] == 131072 * 280 and
            verification['max_used_payload_bytes'] == max(len(raw['records']) * 280 for _, _, raw in rows) == 2599800 and
            verification['caller_diagnostic_storage_only'] is True, 'Observer capacity/used bytes differ')
    return rows, {'normal_wires': 12, 'trace_wires': 12, 'full_byte_gold_equality': True,
                  'recorded_roundtrips': 24, 'observer_memory': memory, 'max_observer_used_bytes': 2599800,
                  'scope': 'Captured complete wire/roundtrip assertions; caller observer heap only, no codec resource measurement'}
