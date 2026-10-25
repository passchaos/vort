#!/usr/bin/env python3
"""Read-only repository audit. All generated files stay beneath this directory."""
import ctypes
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
BASE = Path('/tmp/vort-br-metadata-full-range-20261025')
OUT = BASE / 'legacy-wire'
OLD = Path('/home/passchaos/project-z/vort')
NEW = Path('/home/passchaos/project-z/vort-brotli-context-cache')
GATE_PATH = NEW / 'tools/br/metadata_diff.py'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identity(path):
    path = Path(path)
    return {'path': str(path), 'sha256': digest(path.read_bytes()), 'bytes': path.stat().st_size}


def verify_manifest(label, root):
    path = OUT / ('source-' + label + '-pinned.json')
    data = json.loads(path.read_text())
    differences = []
    for row in data['files']:
        source = root / row['path']
        if not source.exists() or digest(source.read_bytes()) != row['sha256']:
            differences.append(row['path'])
    return {**identity(path), 'commit': data['commit'], 'files_checked': len(data['files']),
            'all_files_match': not differences, 'differences': differences}


def main():
    original_manifest_identities = {}
    for label in ('old', 'new'):
        source = BASE / (label + '-source-manifest.json')
        original_manifest_identities[label] = identity(source)
        (OUT / ('source-' + label + '-pinned.json')).write_bytes(source.read_bytes())
    spec = importlib.util.spec_from_file_location('metadata_gate', GATE_PATH)
    gate = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gate)
    reference_base = Path('/tmp/vort-br-general-experimental-build')
    reference = gate.Reference(reference_base / 'libbrotlienc.so.1.2.0',
                               reference_base / 'libbrotlidec.so.1.2.0',
                               reference_base / 'libbrotlicommon.so.1.2.0')
    original = (NEW / 'tools/br/metadata_probe.zig').read_bytes()
    bridge_path = OUT / 'metadata_probe.zig'
    bridge = bridge_path.read_bytes()
    needle, replacement = b'br.max_metadata_meta_block_len', b'(@as(usize, 1) << 24)'
    if original.count(needle) != 2 or bridge != original.replace(needle, replacement):
        raise AssertionError('probe bridge changed beyond the two constant references')
    before = {'old': verify_manifest('old', OLD), 'new': verify_manifest('new', NEW)}
    if not all(row['all_files_match'] for row in before.values()):
        raise AssertionError(before)
    compilation = {}
    compiler = Path(shutil.which('zig')).resolve()
    for target, object_dir in [('native', '1ce4443d2778e0b187892cf1213a7bdd'),
                               ('x86', '6f85c63f025a7a6ebabdd39dee54e953')]:
        obj = NEW / '.zig-cache/o' / object_dir / 'vort-br-record-optimal-releasefast.o'
        flags = [] if target == 'native' else ['-target', 'x86-linux-gnu', '-mcpu', 'pentium4']
        command = ['taskset', '-c', '10-15', 'zig', 'build-exe', '-j2', str(obj), '-OReleaseFast', *flags,
                   '--dep', 'br', '-Mroot=' + str(bridge_path), '-OReleaseFast', *flags,
                   '-Mbr=' + str(OLD / 'src/br.zig'), '--cache-dir', str(OUT / ('cache-' + target)),
                   '--global-cache-dir', str(OUT / 'global-cache'), '--name', 'vort-br-metadata-legacy-' + target,
                   '-femit-bin=' + str(OUT / ('probe-' + target))]
        compilation[target] = {'command': command, 'cpu_affinity': '10-15', 'jobs': 2,
                               'executable': identity(OUT / ('probe-' + target)),
                               'record_optimal_object': identity(obj),
                               'log': identity(OUT / ('compile-' + target + '.log'))}
    rows, reports = [], {}
    scope = []
    for target in ('native', 'x86'):
        new_dir = BASE / (target + '-final')
        report_path = new_dir / 'differential.json'
        report = json.loads(report_path.read_text())
        new_exe = Path(report['probe']['path'])
        if identity(new_exe)['sha256'] != report['probe']['sha256']:
            raise AssertionError('new executable identity differs')
        selected = [row for row in report['results'] if row['probe']['metadata_bytes'] <= 65536]
        if len(selected) != 108:
            raise AssertionError(('unexpected final-report selection', target, len(selected)))
        reports[target] = {**identity(report_path), 'total_target_rows': len(report['results']),
                           'selected_rows': len(selected), 'probe': identity(new_exe),
                           'payload': identity(new_dir / report['payload']['file']),
                           'compiled_functional_commit': 'e49fce241781ec4849672ffae410bbad89c701ab',
                           'compiled_source_sha256': report['source']['sha256'],
                           'post_build_test_only_commit': 'b502fc50d81be96dc622ab4ba3998a53403c618c'}
        differences = []
        for entry in report['source']['files']:
            path = NEW / entry['path']
            actual = digest(path.read_bytes()) if path.exists() else None
            if actual != entry['sha256']:
                differences.append({'path': entry['path'], 'compiled_sha256': entry['sha256'], 'current_sha256': actual})
        reports[target]['current_source_differences_from_compiled_source'] = differences
        if any('wide_bit_resources' not in entry['path'] for entry in differences):
            raise AssertionError(('unexpected functional source change since new probe build', target, differences))
        payload = (new_dir / report['payload']['file']).read_bytes()
        if digest(payload) != report['payload']['sha256']:
            raise AssertionError('payload identity differs')
        old_dir = OUT / ('old-' + target)
        logs_dir = OUT / ('logs-' + target)
        supplemental_dir = OUT / ('supplemental-new-' + target)
        for directory in (old_dir, logs_dir, supplemental_dir):
            directory.mkdir(exist_ok=True)
        def invoke(exe, config, metadata_path, wire_path, log_prefix):
            command = ['taskset', '-c', '10-15', str(exe), 'encode', config['codec'], config['api'],
                       str(config['quality']), str(config['window_bits']),
                       'large' if config['large_window'] else 'standard', str(new_dir / 'payload.input'),
                       str(metadata_path), str(wire_path)]
            if wire_path.exists():
                raise AssertionError(('refuse stale output', wire_path))
            result = subprocess.run(command, capture_output=True, timeout=120, check=False, cwd=NEW)
            stdout_path, stderr_path = logs_dir / (log_prefix + '.stdout'), logs_dir / (log_prefix + '.stderr')
            stdout_path.write_bytes(result.stdout)
            stderr_path.write_bytes(result.stderr)
            parsed = None
            if result.returncode == 0:
                try:
                    parsed = json.loads(result.stdout)
                except json.JSONDecodeError:
                    pass
            return {'command': command, 'exit_code': result.returncode, 'stdout': identity(stdout_path),
                    'stderr': identity(stderr_path), 'report': parsed}
        def compare(name, config, length, new_path, new_probe, origin, new_invocation=None):
            metadata_path = new_dir / f'metadata-{length}.input'
            metadata = metadata_path.read_bytes()
            if digest(metadata) != new_probe['metadata_sha256'] or digest(payload) != new_probe['input_sha256']:
                raise AssertionError(('new input identity differs', target, name))
            new_wire = new_path.read_bytes()
            if digest(new_wire) != new_probe['wire_sha256'] or len(new_wire) != new_probe['wire_bytes']:
                raise AssertionError(('new wire identity differs', target, name))
            old_path = old_dir / (name + '.br')
            invocation = invoke(OUT / ('probe-' + target), config, metadata_path, old_path, 'old-' + name)
            old_probe = invocation['report']
            row = {'target': target, 'origin': origin, 'name': name, 'settings': config,
                   'metadata_bytes': length, 'input': identity(new_dir / 'payload.input'),
                   'metadata': identity(metadata_path), 'new_wire': identity(new_path), 'new_probe': new_probe,
                   'old_invocation': invocation, 'new_invocation': new_invocation,
                   'old_wire': None, 'wire_equal': False, 'old_reference_decode': None,
                   'new_reference_decode': reference.decode(new_wire, payload, allow_large=config['large_window'])}
            if old_path.exists():
                old_wire = old_path.read_bytes()
                row['old_wire'] = identity(old_path)
                row['wire_equal'] = old_wire == new_wire
                row['old_reference_decode'] = reference.decode(old_wire, payload, allow_large=config['large_window'])
                if not row['wire_equal']:
                    index = next((index for index, pair in enumerate(zip(old_wire, new_wire)) if pair[0] != pair[1]),
                                 min(len(old_wire), len(new_wire)))
                    row['first_differing_byte'] = index
                    row['old_difference_hex'] = old_wire[max(0, index - 8):index + 16].hex()
                    row['new_difference_hex'] = new_wire[max(0, index - 8):index + 16].hex()
            if invocation['exit_code'] != 0 or old_probe is None or old_probe.get('error') is not None:
                row['status'] = 'legacy_probe_failure'
            elif old_probe['config'] != config:
                row['status'] = 'settings_mismatch'
            elif not row['wire_equal']:
                row['status'] = 'wire_mismatch'
            elif not row['old_reference_decode']['complete_contents_verified'] or not row['new_reference_decode']['complete_contents_verified']:
                row['status'] = 'reference_decode_failure'
            else:
                row['status'] = 'matched'
            rows.append(row)
            if row['status'] != 'matched':
                print(json.dumps({'target': target, 'name': name, 'status': row['status'],
                                  'old_exit': invocation['exit_code'], 'old_error': old_probe.get('error') if old_probe else None}), flush=True)
        keys = set()
        for row in selected:
            config = row['probe']['config']
            length = row['probe']['metadata_bytes']
            keys.add((config['codec'], config['quality'], config['api'], config['large_window'], length))
            compare(row['name'], config, length, new_dir / row['wire_file'], row['probe'], 'existing-final-report')
        supplemental_count = 0
        for codec, quality in [('stored', 0)] + [('planned', quality) for quality in gate.QUALITIES]:
            for api in gate.APIS:
                for large in (False, True):
                    length = 65536
                    config = {'codec': codec, 'quality': quality, 'api': api, 'window_bits': 25 if large else 16,
                              'large_window': large}
                    name = f'{codec}-q{quality}-{api}-{"large25" if large else "standard16"}-meta65536'
                    new_path = supplemental_dir / (name + '.br')
                    invocation = invoke(new_exe, config, new_dir / 'metadata-65536.input', new_path, 'new-' + name)
                    new_probe = invocation['report']
                    if invocation['exit_code'] != 0 or new_probe is None or new_probe.get('error') is not None:
                        rows.append({'target': target, 'origin': 'supplemental-positive-all-public-routes', 'name': name,
                                     'settings': config, 'metadata_bytes': length, 'new_invocation': invocation,
                                     'status': 'new_probe_failure', 'wire_equal': False})
                    else:
                        compare('supplemental-' + name, config, length, new_path, new_probe, 'supplemental-positive-all-public-routes', invocation)
                    supplemental_count += 1
        scope.append({'target': target, 'existing_report_rows': len(selected), 'supplemental_rows': supplemental_count,
                      'existing_report_metadata_lengths': sorted({row['probe']['metadata_bytes'] for row in selected}),
                      'positive_65536_routes': 7 * 6 * 2})
        print(json.dumps({'target_finished': target, 'rows': sum(row['target'] == target for row in rows),
                          'failures': sum(row['target'] == target and row['status'] != 'matched' for row in rows)}), flush=True)
    after = {'old': verify_manifest('old', OLD), 'new': verify_manifest('new', NEW)}
    counters = {'comparisons': len(rows), 'matched': sum(row['status'] == 'matched' for row in rows),
                'wire_mismatches': sum(row['status'] == 'wire_mismatch' for row in rows),
                'legacy_probe_failures': sum(row['status'] == 'legacy_probe_failure' for row in rows),
                'new_probe_failures': sum(row['status'] == 'new_probe_failure' for row in rows),
                'existing_report_comparisons': sum(row['origin'] == 'existing-final-report' for row in rows),
                'supplemental_comparisons': sum(row['origin'] == 'supplemental-positive-all-public-routes' for row in rows),
                'all_rows_matched': all(row['status'] == 'matched' for row in rows)}
    report = {'schema': 'vort.br.metadata-legacy-wire-comparison.v1', 'created_utc': datetime.now(timezone.utc).isoformat(),
              'scope': scope, 'counts': counters, 'source_before': before, 'source_after': after,
              'original_manifest_files': original_manifest_identities,
              'repository_sources_preserved': before == after,
              'probe_bridge': {'original': identity(NEW / 'tools/br/metadata_probe.zig'), 'temporary': identity(bridge_path),
                               'replacement_count': 2, 'original_token': needle.decode(), 'replacement_token': replacement.decode(),
                               'sole_change_verified': bridge == original.replace(needle, replacement),
                               'legacy_supported_max_metadata_len': 65536,
                               'reported_1_shift_24_is_not_old_encoder_capability': True,
                               'scope_note': 'Only metadata lengths <=65536 are compared; the constant is a compile bridge, not a feature backport.'},
              'compiler': identity(compiler), 'compilations': compilation,
              'new_final_reports': reports, 'independent_reference': reference.identity(),
              'comparison_script': identity(Path(__file__)), 'parser_library': identity(GATE_PATH),
              'measurement_scope': 'Functional complete-wire equality and full plaintext only; no throughput or timing measurement.',
              'counterexamples': [row['name'] + ':' + row['target'] for row in rows if row['status'] != 'matched'], 'rows': rows}
    path = BASE / 'legacy-wire-comparison.json'
    path.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'report': str(path), 'sha256': identity(path)['sha256'], **counters}), flush=True)


if __name__ == '__main__':
    main()
