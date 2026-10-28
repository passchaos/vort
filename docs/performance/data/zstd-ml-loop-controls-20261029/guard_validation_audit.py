#!/usr/bin/env python3
"""Audit archived maximum-guard evidence; --decode uses the frozen libzstd oracle."""
import argparse
import ctypes
import difflib
import hashlib
import json
import re
import sys
import tarfile
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parent
EDGE = 'src/zstd/match/hq_parser/search_edges.zig'
BINARY_NAMES = {'baseline-runner', 'candidate-runner', 'huffman-x2.o'}
REFERENCE_NAME = 'maximum-guard-reference-decode.json'
REPORT_NAME = 'maximum-guard-audit-report.json'
sys.dont_write_bytecode = True


def sha(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def archive_files(path, expected_sha):
    assert sha(path.read_bytes()) == expected_sha, path
    with tarfile.open(path) as archive:
        members = archive.getmembers()
        assert all(m.isfile() or m.isdir() for m in members)
        assert len({m.name for m in members}) == len(members)
        assert all(not m.name.startswith('/') and '..' not in Path(m.name).parts for m in members)
        return {m.name: archive.extractfile(m).read() for m in members if m.isfile()}


def median_fraction(values):
    values = sorted(values)
    n = len(values)
    return Fraction(values[n // 2]) if n % 2 else Fraction(values[n // 2 - 1] + values[n // 2], 2)


def verify_source(files, baseline, index):
    original = baseline[EDGE]
    assert original == files['baseline-source/' + EDGE]
    git_blob = hashlib.sha1(b'blob ' + str(len(original)).encode() + b'\0' + original).hexdigest()
    assert git_blob == index['shared_baseline']['edge_git_blob_sha1']
    anchor = b'                    for (prices.ml_bases, prices.ml_bits, 0..)'
    added = b'                    const first_endpoint: usize = if (self.parameters.strategy == .btopt) 17 else 66;\n                    if (maximum <= first_endpoint) continue;\n'
    assert original.count(anchor) == 1
    candidate = files['candidate-source/' + EDGE]
    assert candidate == original.replace(anchor, added + anchor)
    expected_diff = ''.join(difflib.unified_diff(original.decode().splitlines(True), candidate.decode().splitlines(True), fromfile='baseline/' + EDGE, tofile='candidate/' + EDGE))
    assert files['source.diff'].decode() == expected_diff
    hashes = json.loads(files['contracts/source_hashes.json'])
    assert len(hashes) == 6
    assert all(sha(files['contracts/' + name]) == digest for name, digest in hashes.items())
    assert candidate == files['contracts/' + EDGE]
    assert original == files['contracts/src/zstd/match/hq_parser/ml_loop_guard_reference.zig']
    assert files['contract-wrapper.zig'] == files['candidate-source/src/ml_guard_contracts.zig']
    prices = baseline['src/zstd/match/hq_parser/prices.zig'].decode()
    arrays = [list(map(int, re.search(r'pub const ' + name + r' = .*?\{([^}]+)\}', prices).group(1).split(','))) for name in ['ml_bases', 'ml_bits']]
    bases, bits = arrays
    endpoints = {}
    for cutoff, upper_enabled, label in [(16, False, 'btopt'), (64, True, 'other_sampled_strategies')]:
        eligible = [endpoint for base, width in zip(bases, bits) for endpoint in ([base, base + (1 << width) - 1] if upper_enabled else [base]) if endpoint > cutoff]
        endpoints[label] = min(eligible)
    assert endpoints == {'btopt': 17, 'other_sampled_strategies': 66}
    trace = files['contracts/src/zstd/match/hq_parser/ml_loop_guard_tests/trace.zig'].decode()
    assert 'for (1..131076)' in trace and '[_]usize{ 3, 7, 17, 65, 131, 255 }' in trace
    assert 'inline for (.{ false, true })' in trace and 'expectEqualSlices' in trace
    validation = json.loads(files['contracts/validation.json'])
    expected_commands = ["zig test src/zstd_ml_loop_guard_tests.zig -ODebug --test-filter 'Zstd HQ search ML loop guard'", "zig test src/zstd_ml_loop_guard_tests.zig -OReleaseFast --test-filter 'Zstd HQ search ML loop guard'", "zig test src/zstd_ml_loop_guard_tests.zig -ODebug -target x86-linux --test-filter 'Zstd HQ search ML loop guard'"]
    assert [run['command'] for run in validation['runs']] == expected_commands
    assert [run['session_id'] for run in validation['runs']] == [57247, 64836, 20409]
    assert all(run['exit_code'] == 0 and run['passed'] == run['total'] == 7 and run['observed_terminal_output'] == 'All 7 tests passed.\n' for run in validation['runs'])
    assert validation['fmt']['exit_code'] == 0
    assert 'Wasm bridge prepared, not executed by this subtask.' in validation['notes']
    return {'exact_source_guard_added_lines': 2, 'contract_source_hashes_verified': 6, 'eligible_endpoint_minima': endpoints, 'contract_target_records_verified': 3, 'recorded_tests_per_target': 7, 'recorded_trace_pairs_per_run': 131075 * 6 * 2, 'wasm_executed': False}


def verify_screen(files, inputs):
    result = json.loads(files['results.json'])
    assert result['rounds'] == 2 and result['affinity'] == '2'
    assert len(result['rows']) == len(result['commands']) == 24 and len(result['summary']) == 6
    seen = set()
    for row, command in zip(result['rows'], result['commands']):
        key = (row['round'], row['case'], row['strategy'], row['mode'])
        assert key not in seen
        seen.add(key)
        prefix = f"runs/{row['round']}/{row['case']}-{row['strategy']}/{row['mode']}"
        assert json.loads(files[prefix + '.json']) == row
        stdout = json.loads(files[prefix + '.stdout'])
        assert all(row[k] == value for k, value in stdout.items())
        assert command[:3] == ['taskset', '-c', '2'] and len(command) == 8
        assert Path(command[3]).name == row['mode'] + '-runner'
        assert Path(command[4]).name == row['case'] + '-4096'
        assert command[5].endswith('/' + prefix + '.zst') and command[6:] == [row['strategy'], 'none']
        wire = files[prefix + '.zst']
        assert row['wire_bytes'] == len(wire) and row['wire_sha256'] == sha(wire)
        data = inputs[row['case'] + '-4096']
        assert row['input_bytes'] == len(data) == 4096 and row['input_sha256'] == sha(data)
        assert row['ordinary_ns'] > 0 and row['profile_ns'] > 0
        assert row['profiled_wire_equal'] and row['native_decode_verified'] and not row['dictionary_decode_verified']
        assert row['optimize'] == 'ReleaseFast' and row['profile']['resolved_strategy'] == row['strategy']
        assert row['profile']['hq_used'] and row['profile']['hq_passes'] > 0
        stderr = files[prefix + '.stderr'].decode()
        assert f"ordinary_complete_ns={row['ordinary_ns']}" in stderr
        assert f"profile_complete_ns={row['profile_ns']}" in stderr
    pairs, summaries = 0, []
    for summary in result['summary']:
        ordinary = {'baseline': [], 'candidate': []}
        profiles = {'baseline': [], 'candidate': []}
        paired_ratios, orders = [], []
        all_profiles, all_wires = [], []
        for rd in range(2):
            prefix = f"runs/{rd}/{summary['case']}-{summary['strategy']}/"
            a, b = [json.loads(files[prefix + mode + '.json']) for mode in ['baseline', 'candidate']]
            assert a['profile'] == b['profile']
            assert files[prefix + 'baseline.zst'] == files[prefix + 'candidate.zst']
            all_profiles += [a['profile'], b['profile']]
            all_wires += [files[prefix + 'baseline.zst'], files[prefix + 'candidate.zst']]
            paired_ratios.append(float(Fraction(b['ordinary_ns'], a['ordinary_ns'])))
            for mode, row in [('baseline', a), ('candidate', b)]:
                ordinary[mode].append(row['ordinary_ns'])
                profiles[mode].append(row['profile_ns'])
            order = [row['mode'] for row in result['rows'] if row['round'] == rd and row['case'] == summary['case'] and row['strategy'] == summary['strategy']]
            assert sorted(order) == ['baseline', 'candidate']
            orders.append(order)
            pairs += 1
        assert orders[1] == list(reversed(orders[0]))
        assert all(p == all_profiles[0] for p in all_profiles)
        assert all(w == all_wires[0] for w in all_wires)
        assert ordinary['baseline'] == summary['baseline_ns'] and ordinary['candidate'] == summary['candidate_ns']
        ratio = median_fraction(ordinary['candidate']) / median_fraction(ordinary['baseline'])
        assert float(ratio) == summary['median_ratio'] and paired_ratios == summary['paired_ratios']
        assert len(all_wires[0]) == summary['wire_bytes'] and sha(all_wires[0]) == summary['wire_sha256']
        assert summary['transitions'] == all_profiles[0]['optimal_transitions']
        assert summary['price_evaluations'] == all_profiles[0]['price_evaluations']
        assert summary['refinement_passes'] == all_profiles[0]['refinement_passes']
        summaries.append({'case': summary['case'], 'strategy': summary['strategy'], 'baseline_ns': ordinary['baseline'], 'candidate_ns': ordinary['candidate'], 'baseline_profile_ns': profiles['baseline'], 'candidate_profile_ns': profiles['candidate'], 'paired_ratios': paired_ratios, 'median_ratio': float(ratio), 'median_ratio_exact': str(ratio), 'round_orders': orders, 'wire_bytes': summary['wire_bytes'], 'wire_sha256': summary['wire_sha256']})
    assert result['validation'] == {'ordinary_encodes': 24, 'native_decodes': 48, 'full_wire_equal': True, 'full_profile_equal': True, 'debug_smoke_tests': 6}
    assert result['decision'] == 'not adopted from mixed exploratory results; no further variants'
    return {'ordinary_rows_verified': 24, 'wire_profile_pairs_verified': pairs, 'recorded_native_decodes': 48, 'ratio_method': 'median(candidate_ns)/median(baseline_ns), independently computed with Fraction', 'summaries': summaries, 'decision': result['decision']}


def verify_original_manifest(files, index):
    manifest = json.loads(files['artifact-manifest.json'])
    assert len(manifest['artifacts']) == 117
    archived, identities = 0, index['binary_and_object_identities']
    for entry in manifest['artifacts']:
        if entry['path'] in BINARY_NAMES:
            assert identities[entry['path']] == {'bytes': entry['bytes'], 'sha256': entry['sha256'], 'archived': False}
            assert entry['path'] not in files
        else:
            data = files[entry['path']]
            assert len(data) == entry['bytes'] and sha(data) == entry['sha256']
            archived += 1
    initial = json.loads(files['original-evidence-audit.json'])
    assert initial == index['original_manifests']
    assert initial['screen_original_manifest']['artifacts_verified'] == 117
    assert initial['reused_baseline_original_manifest']['artifacts_verified'] == 118
    assert not initial['contracts_original_manifest']['present']
    assert len(json.loads(files['baseline-provenance/artifact-manifest.json'])['artifacts']) == 118
    compiler = json.loads(files['compiler-and-identities.json'])
    command = json.loads(files['compile-command.json'])
    assert compiler['compile_command'] == command
    assert command[:3] == ['taskset', '-c', '4,6']
    assert '-fllvm' in command and '-OReleaseFast' in command and '-mcpu=skylake' in command
    assert not any(arg.startswith('-ffast-math') for arg in command)
    terminal = json.loads(files['compile-terminal.json'])
    assert terminal['command'] == command and terminal['exit_code'] == 0 and terminal['baseline_reused_identity_verified']
    assert terminal['binary_sha256'] == {mode: identities[mode + '-runner']['sha256'] for mode in ['baseline', 'candidate']}
    prior = json.loads(files['baseline-provenance/compile-terminal.json'])
    assert prior['exit_codes'][0] == 0 and prior['commands'][0] == compiler['reused_baseline_compile_command']
    assert prior['binary_sha256']['baseline'] == identities['baseline-runner']['sha256']
    smoke = json.loads(files['smoke-terminal.json'])
    assert smoke['exit_code'] == 0 and smoke['tests_passed'] == 6
    codegen = json.loads(files['codegen.json'])
    assert codegen == json.loads(files['results.json'])['codegen']
    assert codegen['baseline'][0]['bytes'] == 628 and codegen['candidate'][0]['bytes'] == 672
    for mode in ['baseline', 'candidate']:
        asm = files[mode + '-loop.asm'].decode()
        symbol = codegen[mode][0]['symbol']
        assert symbol in asm
        instructions = [line.split('\t')[1].split() for line in asm.splitlines() if re.match(r'^\s*[0-9a-f]+:\t', line)]
        assert all(re.fullmatch(r'[0-9a-f]{2}', byte) for instruction in instructions for byte in instruction)
        assert sum(map(len, instructions)) == codegen[mode][0]['bytes']
    return {'screen_original_manifest_artifacts_archived': archived, 'binary_object_identities_preserved': 3, 'recorded_candidate_compile_exit_code': 0, 'recorded_smoke_passed': 6, 'loop_codegen_bytes': {'baseline': 628, 'candidate': 672}}


def decode_reference(files, inputs, index):
    reference = index['reference_library']
    library = Path(reference['path'])
    assert sha(library.read_bytes()) == reference['sha256']
    zstd = ctypes.CDLL(str(library))
    zstd.ZSTD_versionNumber.restype = ctypes.c_uint
    assert zstd.ZSTD_versionNumber() == reference['version_number'] == 10600
    zstd.ZSTD_decompress.argtypes = [ctypes.c_void_p, ctypes.c_size_t, ctypes.c_void_p, ctypes.c_size_t]
    zstd.ZSTD_decompress.restype = ctypes.c_size_t
    zstd.ZSTD_isError.argtypes = [ctypes.c_size_t]
    zstd.ZSTD_isError.restype = ctypes.c_uint
    rows = []
    for name in sorted(n for n in files if n.endswith('.zst')):
        wire = files[name]
        case = Path(name).parent.name.rsplit('-', 1)[0]
        expected = inputs[case + '-4096']
        destination, source = ctypes.create_string_buffer(len(expected)), ctypes.create_string_buffer(wire)
        size = zstd.ZSTD_decompress(destination, len(expected), source, len(wire))
        assert not zstd.ZSTD_isError(size), name
        decoded = destination.raw[:size]
        assert decoded == expected and size == 4096, name
        rows.append({'wire': name, 'wire_bytes': len(wire), 'wire_sha256': sha(wire), 'input': case + '-4096', 'decoded_bytes': size, 'decoded_sha256': sha(decoded), 'exact_input_equal': True})
    assert len(rows) == 24
    return {'schema_version': 1, 'library_path': str(library), 'library_sha256': reference['sha256'], 'version_number': 10600, 'dictionary': None, 'wire_count': 24, 'rows': rows}


def verify_reference_record(record, files, inputs, index):
    assert record['version_number'] == 10600 and record['wire_count'] == len(record['rows']) == 24
    assert record['library_sha256'] == index['reference_library']['sha256'] and record['dictionary'] is None
    assert {row['wire'] for row in record['rows']} == {name for name in files if name.endswith('.zst')}
    for row in record['rows']:
        assert row['wire_bytes'] == len(files[row['wire']]) and row['wire_sha256'] == sha(files[row['wire']])
        assert row['decoded_bytes'] == len(inputs[row['input']]) == 4096
        assert row['decoded_sha256'] == sha(inputs[row['input']]) and row['exact_input_equal']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--decode', action='store_true', help='decode all 24 archived wires with exact local libzstd 1.6.0')
    parser.add_argument('--write-records', action='store_true', help='write owned maximum-guard audit/reference JSON records')
    args = parser.parse_args()
    assert not args.write_records or args.decode
    index = json.loads((ROOT / 'maximum-guard-index.json').read_bytes())
    parent = json.loads((ROOT / 'manifest.json').read_bytes())
    assert index['revision'] == parent['revision']
    assert index['shared_baseline']['sha256'] == parent['baseline_source_sha256']
    baseline = archive_files(ROOT / 'baseline-source.tar.xz', index['shared_baseline']['sha256'])
    assert len(baseline) == index['shared_baseline']['member_count'] == 1536
    assert set(baseline) == set(parent['baseline_members'])
    assert all(sha(baseline[name]) == digest for name, digest in parent['baseline_members'].items())
    inputs = archive_files(ROOT / 'inputs.tar.xz', index['shared_inputs']['sha256'])
    assert set(inputs) == set(index['shared_inputs']['members'])
    assert all(sha(inputs[name]) == entry['sha256'] and len(inputs[name]) == entry['bytes'] for name, entry in index['shared_inputs']['members'].items())
    entry = index['archive']
    assert entry['name'] == 'maximum-guard.tar.xz'
    assert (ROOT / entry['name']).stat().st_size == entry['bytes']
    files = archive_files(ROOT / entry['name'], entry['sha256'])
    assert set(files) == set(entry['members'])
    assert all(sha(files[name]) == metadata['sha256'] and len(files[name]) == metadata['bytes'] for name, metadata in entry['members'].items())
    assert all(not data.startswith(b'\x7fELF') for data in files.values())
    for name, metadata in index.get('external_artifacts', {}).items():
        data = (ROOT / name).read_bytes()
        assert len(data) == metadata['bytes'] and sha(data) == metadata['sha256']
    source = verify_source(files, baseline, index)
    screen = verify_screen(files, inputs)
    original = verify_original_manifest(files, index)
    reference = decode_reference(files, inputs, index) if args.decode else json.loads((ROOT / REFERENCE_NAME).read_bytes())
    verify_reference_record(reference, files, inputs, index)
    report = {'schema_version': 1, 'archive_sha256': entry['sha256'], 'archive_members_verified': len(files), 'baseline_source_members_verified': len(baseline), 'source': source, 'screen': screen, 'original_evidence': original, 'reference_decodes_verified': 24, 'reference_record_sha256': sha(json_bytes(reference)), 'reference_version_number': 10600, 'new_compilation_or_performance_rounds': 0}
    if args.write_records:
        (ROOT / REFERENCE_NAME).write_bytes(json_bytes(reference))
        (ROOT / REPORT_NAME).write_bytes(json_bytes(report))
    elif (ROOT / REPORT_NAME).exists():
        assert json.loads((ROOT / REPORT_NAME).read_bytes()) == report
    print(json.dumps({k: v for k, v in report.items() if k != 'screen'}, indent=2))
    print(json.dumps({'ordinary_rows_verified': screen['ordinary_rows_verified'], 'wire_profile_pairs_verified': screen['wire_profile_pairs_verified'], 'median_ratios_recomputed': len(screen['summaries']), 'decision': screen['decision']}, indent=2))


if __name__ == '__main__':
    main()
