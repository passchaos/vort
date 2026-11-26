"""Data-only checks of the captured public lifecycle, wires and chronology."""
from datetime import datetime
from package_io import lines, load, require, sha

OPTIONS = {'window_len': 16384, 'min_match': 4, 'max_chain': 32,
           'nice_len': 16, 'max_match': 128, 'max_candidates': 2}
API = {'legacy': 'RawDeflateEncoder.encodeFixedWithOptionsAppend',
       'prepared': 'PreparedRawFixedEncoder.encodeAppend'}


def probe_contract(probe, row, mode, iterations):
    require(probe['schema'] == 'vort.deflate.prepared-fixed-probe.v1' and
            probe['status'] == 'ok' and probe['mode'] == mode and probe['api'] == API[mode],
            'Public probe API or mode differs')
    require(probe['lz77_options'] == OPTIONS and probe['parser'] == 'hash' and
            probe['build_mode'] == 'ReleaseFast' and probe['pointer_bits'] == 64 and
            (probe['target_arch'], probe['target_os'], probe['target_abi']) == ('x86_64', 'linux', 'gnu'),
            'Public probe settings differ')
    require(probe['input_bytes'] == row['size'] and probe['input_sha256'] == row['sha256'] and
            probe['iterations'] == iterations and probe['warm_encode_count'] == 1 and
            probe['prepare_capacity'] == (row['size'] if mode == 'prepared' else 0) and
            probe['caller_output_capacity'] == (9 * row['size'] + 17) // 8,
            'Prepared/caller capacity or workload differs')
    sample = probe['sample']
    require(sample['written'] == probe['wire_bytes'] and
            sample['length_mix'] == probe['wire_bytes'] * iterations and
            (sample['elapsed_ns'] > 0 if iterations else sample['elapsed_ns'] == 0),
            'Public append timed work differs')
    require(probe['allocator'] == 'plain std.process.Init.gpa; no memory profile or allocator observer' and
            probe['timer_scope'] == 'clearRetainingCapacity, complete public append, and length mix only' and
            probe['memory_scope'] == 'allocation contract is independently validated, not measured by this timer',
            'Timer or allocator scope differs')


def verify_samples(files, manifest, artifact):
    rows = {row['id']: row for row in manifest['rows']}
    require(len(rows) == 33 and len(manifest['legacy_control_rows']) == 12 and
            manifest['pairs'] == 6 and manifest['orders'] == ['AB', 'BA', 'AB', 'BA', 'AB', 'BA'],
            'Complete matrix policy differs')
    require(manifest['lz77_options'] == OPTIONS and manifest['parser'] == 'hash' and
            manifest['affinity'] == [2] and manifest['thread_policy'] == 'single' and
            manifest['build_mode'] == 'ReleaseFast' and manifest['target'] == 'x86_64-linux-gnu' and
            manifest['cpu_features'] == 'skylake+pku+sgx' and
            manifest['gate'] == {'prepared_target_gm_min': 1.03, 'paired_95ci_excludes_parity': True,
                                 'all_target_and_control_min': 0.98, 'exact_wire_identity': True},
            'Predeclared performance policy differs')
    policy = manifest['api_policy_correction']
    require(policy['old_api'] == policy['legacy_control_api'] == API['legacy'] and
            policy['prepared_api'] == API['prepared'] and policy['corrected_before_sampling'] is True,
            'Captured public lifecycle policy differs')
    for row in rows.values():
        require('independent_max_candidates64k12' not in row['id'], 'Excluded parser variant entered rowset')
        data = files['performance/inputs/' + row['id']]
        require(len(data) == row['size'] and sha(data) == row['sha256'] and
                row['input'] == manifest['base'] + '/inputs/' + row['id'], 'Input identity differs')
        require(manifest['iterations_by_row'][row['id']] == max(256, ((32 << 20) + row['size'] - 1) // row['size']),
                'Predeclared iteration policy differs')
    records = lines(files, 'performance/samples/raw.jsonl')
    chronology = lines(files, 'performance/chronology.jsonl')
    require(len(records) == len(chronology) == 540, 'Incomplete raw or chronology capture')
    expected = []
    for pair, order in enumerate(manifest['orders']):
        for family, chosen in [('prepared', manifest['rows']),
                               ('legacy', [rows[name] for name in manifest['legacy_control_rows']])]:
            for row in chosen:
                expected.extend((pair, order, family, row['id'], side) for side in order)
    previous_end, previous_utc = 0, None
    for record, event, planned in zip(records, chronology, expected, strict=True):
        require(tuple(record[key] for key in ['pair', 'order', 'family', 'row', 'side']) == planned,
                'Sample chronology sequence differs')
        require({key: value for key, value in record.items() if key not in ['pair', 'order', 'family', 'side']} == event,
                'Chronology payload differs from immutable raw')
        require(record['phase'] == 'timed-public-append' and record['returncode'] == 0 and record['stderr'] == '' and
                json_stdout(record) == record['probe'], 'Sample process receipt differs')
        require(record['monotonic_start_ns'] >= previous_end and
                record['monotonic_end_ns'] > record['monotonic_start_ns'] and
                record['wall_ns'] == record['monotonic_end_ns'] - record['monotonic_start_ns'],
                'Sample monotonic interval differs')
        previous_end = record['monotonic_end_ns']
        start, end = datetime.fromisoformat(record['started_utc']), datetime.fromisoformat(record['ended_utc'])
        require(start <= end and (previous_utc is None or start >= previous_utc), 'Sample UTC order differs')
        previous_utc = end
        row, probe = rows[record['row']], record['probe']
        mode = 'prepared' if record['side'] == 'B' and record['family'] == 'prepared' else 'legacy'
        which = 'old' if record['side'] == 'A' else 'current'
        iterations = manifest['iterations_by_row'][row['id']]
        executable = manifest['base'] + '/build/' + which + '-probe'
        argv = [executable, '--mode', mode, '--input', row['input'], '--iterations', str(iterations)]
        require(record['which'] == which and record['mode'] == mode and
                record['argv'] == ['taskset', '-c', '2'] + argv and probe['argv'] == argv and
                probe['input_path'] == row['input'], 'Captured sample argv differs')
        probe_contract(probe, row, mode, iterations)
        require(record['elf_sha256'] == artifact[which + '_elf_sha256'], 'Sample ELF binding differs')
        wire = files['performance/wires/' + row['id'] + '.' + which + '.' + mode + '.raw']
        require(probe['wire_sha256'] == sha(wire) and probe['wire_bytes'] == len(wire), 'Sample wire identity differs')
    return records


def json_stdout(record):
    import json
    return json.loads(record['stdout'])


def verify_preflight(files, manifest, artifact):
    rows = {row['id']: row for row in manifest['rows']}
    preflight = load(files, 'performance/preflight.json')
    require(len(preflight['rows']) == 33 and preflight['three_side_identity_rows'] == 33 and
            preflight['three_side_wire_files'] == 99 and preflight['timed_samples'] == 0,
            'Copied three-side preflight inventory differs')
    require([item['row'] for item in preflight['rows']] == list(rows), 'Three-side preflight row order differs')
    for report in preflight['rows']:
        row = rows[report['row']]
        require(report['wire_equal'] is True and report['input_sha256'] == row['sha256'], 'Wire gate differs')
        wires = []
        require([(w['which'], w['mode']) for w in report['wires']] ==
                [('old', 'legacy'), ('current', 'legacy'), ('current', 'prepared')], 'Three-side wire order differs')
        for saved in report['wires']:
            member = 'performance/wires/' + row['id'] + '.' + saved['which'] + '.' + saved['mode'] + '.raw'
            data = files[member]
            require(saved['path'] == manifest['base'] + '/wires/' + member.split('/')[-1] and
                    saved['sha256'] == sha(data) and saved['bytes'] == len(data), 'Copied preflight wire differs')
            wires.append(data)
        require(wires[0] == wires[1] == wires[2], 'Exact three-side wire bytes differ')

    result = load(files, 'public-preflight/result.json')
    for key in ['new_wires', 'golden_byte_equal_count', 'Python_raw_decode_count', 'C_raw_decode_count',
                'old_public_decode_count', 'new_public_decode_count']:
        require(result[key] == 66, 'Public preflight count differs: ' + key)
    require(result['rows'] == 33 and result['external_process_records'] == 264 and
            result['timed_samples'] == result['all_iterations'] == 0 and result['all_checks_passed'] is True and
            result['no_retries'] is True and result['source_probe_ELF_unchanged'] is True,
            'Public preflight summary differs')
    expected = [(row['id'], mode) for row in manifest['rows'] for mode in ['legacy', 'prepared']]
    require([(r['row'], r['mode']) for r in result['results']] == expected, 'Public preflight wire inventory differs')
    python = lines(files, 'public-preflight/python-decode.jsonl')
    require([(r['row'], r['mode']) for r in python] == expected, 'Python decode receipt inventory differs')
    for report, decoded in zip(result['results'], python, strict=True):
        row = rows[report['row']]
        data = files['public-preflight/wires/' + row['id'] + '.' + report['mode'] + '.raw']
        golden = files['performance/wires/' + row['id'] + '.old.legacy.raw']
        require(data == golden and report['wire_bytes'] == len(data) and
                report['wire_sha256'] == report['golden_wire_sha256'] == decoded['wire_sha256'] ==
                decoded['golden_wire_sha256'] == sha(data), 'Public/golden wire bytes differ')
        require(report['input_bytes'] == row['size'] and report['input_sha256'] == decoded['input_sha256'] == row['sha256'] and
                report['wire_path'] == decoded['wire_path'] and report['iterations'] == 0 and
                all(report[key] is True for key in ['wire_equal_bytes', 'Python_raw_decode', 'C_raw_decode',
                                                  'old_public_decode', 'new_public_decode']), 'Captured decode verdict differs')
        require(decoded['decoded_equal_bytes'] is True and decoded['wire_equal_bytes'] is True and
                decoded['eof'] is True and decoded['trailing_bytes'] == decoded['unconsumed_bytes'] == 0 and
                decoded['untimed'] is True and decoded['compile_version'] == decoded['runtime_version'] == '1.2.11',
                'Python strict decode receipt differs')
    chronology = lines(files, 'public-preflight/chronology.jsonl')
    roles = ['new-public-encode', 'C-libz-raw-decode', 'old-public-decode', 'new-public-decode']
    require(len(chronology) == 264 and [(r['row'], r['encoder_mode'], r['role']) for r in chronology] ==
            [(row, mode, role) for row, mode in expected for role in roles], 'Public process chronology differs')
    for record in chronology:
        row = rows[record['row']]
        report = record['report']
        require(record['returncode'] == 0 and record['stderr'] == '' and record['untimed'] is True and
                record['retry'] is False and json_stdout(record) == report and report['status'] == 'ok' and
                record['input_sha256'] == row['sha256'], 'Public process receipt differs')
        if record['role'] == 'C-libz-raw-decode':
            wire = files['public-preflight/wires/' + row['id'] + '.' + record['encoder_mode'] + '.raw']
            require(report['schema'] == 'vort.deflate.prepared-fixed-c-libz-verify.v1' and
                    report['input_consumed'] == report['wire_bytes'] == len(wire) and
                    report['output_produced'] == report['output_bytes'] == row['size'] and
                    report['untimed'] is True and report['zlib_compile_version'] == report['zlib_runtime_version'] == '1.2.11',
                    'C full-input decode receipt differs')
        else:
            require(report['iterations'] == report['sample']['elapsed_ns'] == report['sample']['length_mix'] == 0 and
                    report['input_bytes'] == row['size'] and report['input_sha256'] == row['sha256'],
                    'Untimed public process workload differs')
            if record['role'] == 'new-public-encode':
                probe_contract(report, row, record['encoder_mode'], 0)
            else:
                require(report['mode'] == 'verify' and report['api'] == 'codec.decodeRawAuto', 'Public decoder API differs')
    return {'three_side_wires': 99, 'new_wires': 66, 'external_process_records': 264,
            'python_decode_receipts': 66, 'exact_wire_bytes_equal': True,
            'scope': 'Captured strict decoder receipts checked as data; no codec was rerun'}
