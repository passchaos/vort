#!/usr/bin/env python3
"""Functional old/new policy audit; no repository mutations or timing claims."""
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
BASE = Path('/tmp/vort-br-large-window-history-20261026')
OUT = BASE / 'legacy-parity'
OLD = Path('/home/passchaos/project-z/vort')
NEW = Path('/home/passchaos/project-z/vort-brotli-context-cache')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identity(path):
    path = Path(path)
    data = path.read_bytes()
    return {'path': str(path), 'bytes': len(data), 'sha256': digest(data)}


def old_identity():
    path = OUT / 'old-source-manifest-pinned.json'
    manifest = json.loads(path.read_text())
    differences = []
    for row in manifest['files']:
        source = OLD / row['path']
        if not source.exists() or digest(source.read_bytes()) != row['sha256']:
            differences.append(row['path'])
    return {**identity(path), 'commit': manifest['commit'], 'files_checked': len(manifest['files']),
            'all_files_match': not differences, 'differences': differences}


def actual_new_source(label, compiled):
    rows, differences = [], []
    source_dir = OUT / ('actual-new-source-' + label)
    source_dir.mkdir(exist_ok=True)
    for row in compiled['files']:
        path = NEW / row['path']
        body = path.read_bytes() if path.exists() else None
        current = digest(body) if body is not None else None
        rows.append({'path': row['path'], 'sha256': current})
        if current != row['sha256']:
            changed = {'path': row['path'], 'compiled_sha256': row['sha256'], 'actual_sha256': current}
            if body is not None:
                snapshot = source_dir / row['path']
                snapshot.parent.mkdir(parents=True, exist_ok=True)
                snapshot.write_bytes(body)
                changed['actual_source_text'] = identity(snapshot)
            differences.append(changed)
    result = {'schema': 'vort.br.actual-source-snapshot.v1', 'label': label,
              'files': rows, 'differences_from_compiled_probe_source': differences,
              'sha256': digest(json.dumps(rows, sort_keys=True).encode())}
    path = OUT / ('actual-new-source-' + label + '.json')
    path.write_text(json.dumps(result, indent=2) + '\n')
    return {**identity(path), 'source_sha256': result['sha256'], 'differences_from_compiled_probe_source': differences}


def settings(api, level, quality, width, large, prefix):
    return {'api': api, 'level': level, 'quality': quality, 'window_bits': width,
            'large_window': large, 'block_len': 0 if api == 'one_shot' else 32768,
            'input_chunk': 32768, 'prefix_len': prefix, 'event': 'none',
            'exercise_new_stream': api in ('reusable', 'incremental'), 'max_total_working_memory': None}


def matrix(prefix):
    modes = [('q' + str(q), 'fast', q) for q in (2, 3, 4, 8, 10, 11)] + [
        ('legacy-fast', 'fast', None), ('legacy-balanced', 'balanced', None), ('legacy-ratio', 'ratio', None)]
    for label, level, quality in modes:
        for api in ('chunks', 'reusable', 'incremental', 'one_shot'):
            yield 'standard16-' + label + '-' + api, 'standard16', settings(api, level, quality, 16, False, prefix)
    for quality in (0, 1):
        for width in (17, 25, 30):
            for api in ('chunks', 'reusable', 'incremental'):
                yield f'large-q{quality}-w{width}-{api}', 'large-block-local-q0-q1', settings(api, 'fast', quality, width, True, prefix)


def main():
    original_path = NEW / 'tools/br/large_history_probe.zig'
    copied_path = OUT / 'large_history_probe.zig'
    if copied_path.read_bytes() != original_path.read_bytes():
        raise AssertionError('old probe must be the unchanged new probe source')
    old_before = old_identity()
    if not old_before['all_files_match']:
        raise AssertionError(old_before)
    reports = {target: json.loads((OUT / (target + '-new-report-pinned.json')).read_text()) for target in ('native', 'x86')}
    if reports['native']['source'] != reports['x86']['source']:
        raise AssertionError('compiled new probe sources differ by target')
    new_before = actual_new_source('before', reports['native']['source'])
    spec = importlib.util.spec_from_file_location('metadata_gate', NEW / 'tools/br/metadata_diff.py')
    gate = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gate)
    reference_dir = Path('/tmp/vort-br-general-experimental-build')
    reference = gate.Reference(reference_dir / 'libbrotlienc.so.1.2.0', reference_dir / 'libbrotlidec.so.1.2.0',
                               reference_dir / 'libbrotlicommon.so.1.2.0')
    seed = 0x6A91BE31
    random = bytearray()
    for _ in range(70000):
        seed = (seed * 1664525 + 1013904223) & 0xffffffff
        random.append(seed >> 24)
    inputs = {'far70000': bytes(random) + bytes(random[:258]),
              'tiny': (b'Large Window unchanged-policy parity.\x00\xff' * 4)[:128]}
    for name, data in inputs.items():
        (OUT / (name + '.input')).write_bytes(data)
    compilations, rows, commands, new_probe_pins = {}, [], [], {}
    for target, object_dir in [('native', '1ce4443d2778e0b187892cf1213a7bdd'),
                               ('x86', '6f85c63f025a7a6ebabdd39dee54e953')]:
        report = reports[target]
        new_probe = Path(report['probe']['path'])
        if identity(new_probe)['sha256'] != report['probe']['sha256']:
            raise AssertionError('new probe executable differs from pinned report')
        new_probe_pins[target] = {'probe': identity(new_probe), 'source_epoch': report['source_epoch'],
                                  'compiled_source_sha256': report['source']['sha256'],
                                  'report': identity(OUT / (target + '-new-report-pinned.json')),
                                  'report_counts': report['counts'],
                                  'scope_note': 'These executables were compiled for root31f3/qa5d86 before the later legacy-fast 64KiB fix; compared stream block size is 32768.'}
        obj = NEW / '.zig-cache/o' / object_dir / 'vort-br-record-optimal-releasefast.o'
        flags = [] if target == 'native' else ['-target', 'x86-linux-gnu', '-mcpu', 'pentium4']
        compile_command = ['taskset', '-c', '10-15', 'zig', 'build-exe', '-j2', str(obj), '-OReleaseFast', *flags,
                           '--dep', 'br', '-Mroot=' + str(copied_path), '-OReleaseFast', *flags,
                           '-Mbr=' + str(OLD / 'src/br.zig'), '--cache-dir', str(OUT / ('cache-' + target)),
                           '--global-cache-dir', str(OUT / 'global-cache'), '--name', 'vort-br-large-history-legacy-' + target,
                           '-femit-bin=' + str(OUT / ('probe-' + target))]
        compilations[target] = {'command': compile_command, 'executable': identity(OUT / ('probe-' + target)),
                               'log': identity(OUT / ('compile-' + target + '.log')), 'record_optimal_object': identity(obj),
                               'record_optimal_source': identity(OLD / 'src/br/encoder/record_optimal_object.zig'),
                               'cpu_affinity': '10-15', 'jobs': 2}
        directory = OUT / target
        directory.mkdir(exist_ok=True)
        for input_name, payload in inputs.items():
            configs = list(matrix(70000 if input_name == 'far70000' else 0))
            if len(configs) != 54:
                raise AssertionError('unexpected policy matrix')
            for case_name, scope, config in configs:
                name = input_name + '-' + case_name
                config_path = directory / (name + '.config.json')
                config_path.write_text(json.dumps(config, indent=2) + '\n')
                row = {'target': target, 'name': name, 'scope': scope, 'settings': config,
                       'input': identity(OUT / (input_name + '.input')), 'config': identity(config_path),
                       'old': None, 'new': None, 'wire_equal': False, 'status': 'pending'}
                for side, exe in [('old', OUT / ('probe-' + target)), ('new', new_probe)]:
                    wire_path = directory / (name + '-' + side + '.br')
                    if wire_path.exists():
                        raise AssertionError(('refuse stale wire', wire_path))
                    command = ['taskset', '-c', '10-15', str(exe), str(OUT / (input_name + '.input')),
                               str(wire_path), str(config_path)]
                    result = subprocess.run(command, capture_output=True, timeout=120, check=False, cwd=NEW)
                    stdout_path, stderr_path = directory / (name + '-' + side + '.stdout'), directory / (name + '-' + side + '.stderr')
                    stdout_path.write_bytes(result.stdout)
                    stderr_path.write_bytes(result.stderr)
                    invocation = {'command': command, 'exit_code': result.returncode, 'stdout': identity(stdout_path), 'stderr': identity(stderr_path)}
                    commands.append(invocation)
                    parsed = None
                    try:
                        parsed = json.loads(result.stdout) if result.returncode == 0 else None
                    except json.JSONDecodeError:
                        pass
                    record = {'invocation': invocation, 'probe': parsed, 'wire': None, 'reference_decode': None}
                    if wire_path.exists():
                        wire = wire_path.read_bytes()
                        record['wire'] = identity(wire_path)
                        record['reference_decode'] = reference.decode(wire, payload, allow_large=config['large_window'])
                        record['identity_verified'] = parsed is not None and parsed['config'] == config and parsed['input_sha256'] == digest(payload) and parsed['wire_sha256'] == digest(wire) and parsed['wire_bytes'] == len(wire)
                    reset_path = Path(str(wire_path) + '.reset.br')
                    if reset_path.exists():
                        reset = reset_path.read_bytes()
                        record['reset'] = {'wire': identity(reset_path),
                                           'reference_decode': reference.decode(reset, payload[-min(len(payload), 258):], allow_large=config['large_window'])}
                    row[side] = record
                old, new = row['old'], row['new']
                def success(record):
                    return record['invocation']['exit_code'] == 0 and record['probe'] is not None and record['probe']['error'] is None and record['wire'] is not None and record.get('identity_verified') and record['reference_decode']['complete_contents_verified']
                if not success(old):
                    row['status'] = 'old_probe_or_decode_failure'
                elif not success(new):
                    row['status'] = 'new_probe_or_decode_failure'
                else:
                    old_wire, new_wire = Path(old['wire']['path']).read_bytes(), Path(new['wire']['path']).read_bytes()
                    row['wire_equal'] = old_wire == new_wire
                    row['status'] = 'matched' if row['wire_equal'] else 'wire_mismatch'
                    if not row['wire_equal']:
                        index = next((i for i, pair in enumerate(zip(old_wire, new_wire)) if pair[0] != pair[1]), min(len(old_wire), len(new_wire)))
                        row['first_differing_byte'] = index
                        row['old_difference_hex'] = old_wire[max(0, index - 8):index + 16].hex()
                        row['new_difference_hex'] = new_wire[max(0, index - 8):index + 16].hex()
                    if 'reset' in old or 'reset' in new:
                        row['reset_wire_equal'] = 'reset' in old and 'reset' in new and Path(old['reset']['wire']['path']).read_bytes() == Path(new['reset']['wire']['path']).read_bytes()
                        row['reset_complete_contents_verified'] = 'reset' in old and 'reset' in new and old['reset']['reference_decode']['complete_contents_verified'] and new['reset']['reference_decode']['complete_contents_verified']
                        if not row['reset_wire_equal'] or not row['reset_complete_contents_verified']:
                            row['status'] = 'reset_wire_or_decode_failure'
                rows.append(row)
                if row['status'] != 'matched':
                    print(json.dumps({'target': target, 'case': name, 'status': row['status'],
                                      'old_error': old['probe']['error'] if old['probe'] else None,
                                      'new_error': new['probe']['error'] if new['probe'] else None}), flush=True)
        print(json.dumps({'target_completed': target, 'comparisons': sum(row['target'] == target for row in rows),
                          'matched': sum(row['target'] == target and row['status'] == 'matched' for row in rows)}), flush=True)
    old_after = old_identity()
    new_after = actual_new_source('after', reports['native']['source'])
    counts = {'comparisons': len(rows), 'matched': sum(row['status'] == 'matched' for row in rows),
              'counterexamples': sum(row['status'] != 'matched' for row in rows),
              'wire_mismatches': sum(row['status'] == 'wire_mismatch' for row in rows),
              'old_failures': sum(row['status'] == 'old_probe_or_decode_failure' for row in rows),
              'new_failures': sum(row['status'] == 'new_probe_or_decode_failure' for row in rows),
              'main_reference_decodes': sum(record['reference_decode'] is not None for row in rows for record in (row['old'], row['new'])),
              'reset_comparisons': sum('reset_wire_equal' in row for row in rows),
              'reset_reference_decodes': sum('reset' in record for row in rows for record in (row['old'], row['new']))}
    report = {'schema': 'vort.br.large-history-legacy-parity.v1', 'created_utc': datetime.now(timezone.utc).isoformat(),
              'scope': {'inputs': list(inputs), 'standard16_modes': ['q2', 'q3', 'q4', 'q8', 'q10', 'q11', 'legacy-fast', 'legacy-balanced', 'legacy-ratio'],
                        'standard16_apis': ['chunks', 'reusable', 'incremental', 'one_shot'],
                        'large_window_quality_controls': [0, 1], 'large_window_widths': [17, 25, 30],
                        'large_window_apis': ['chunks', 'reusable', 'incremental'],
                        'stream_block_and_input_chunk_len': 32768, 'one_shot_block_size': None,
                        'settings_per_input_target': 54, 'inputs_per_target': 2, 'target_count': 2,
                        'changed_q2_plus_large_history_is_outside_parity_scope': True},
              'counts': counts, 'old_source_before': old_before, 'old_source_after': old_after,
              'old_sources_preserved': old_before == old_after,
              'new_compiled_probe_identity': new_probe_pins, 'new_actual_source_before': new_before,
              'new_actual_source_after': new_after, 'new_actual_sources_preserved': new_before['source_sha256'] == new_after['source_sha256'],
              'new_actual_source_is_not_compiled_executable_identity': True,
              'unchanged_probe': {'original': identity(original_path), 'temporary': identity(copied_path), 'byte_identical': original_path.read_bytes() == copied_path.read_bytes()},
              'compiler': identity(Path(shutil.which('zig')).resolve()), 'compilations': compilations,
              'reference': reference.identity(), 'harness': identity(Path(__file__)),
              'measurement_scope': 'Functional wire equality and independent complete plaintext only; numerical memory profiles are recorded but resource parity is not claimed; no timing measurement.',
              'counterexamples': [row['name'] + ':' + row['target'] for row in rows if row['status'] != 'matched'],
              'rows': rows, 'commands': commands}
    path = OUT / 'legacy-parity.json'
    path.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'report': str(path), 'sha256': identity(path)['sha256'], **counts}), flush=True)


if __name__ == '__main__':
    main()
