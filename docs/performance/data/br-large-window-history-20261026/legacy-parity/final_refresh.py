#!/usr/bin/env python3
"""Run only final new probes against retained, identity-bound legacy wires."""
import argparse
from datetime import datetime, timezone
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
BASE = Path('/tmp/vort-br-large-window-history-20261026')
PRIOR = BASE / 'legacy-parity/legacy-parity.json'
OUT = BASE / 'legacy-parity/final-refresh'
ROOT = Path('/home/passchaos/project-z/vort-brotli-context-cache')
FINAL_BR_SHA = '5e5d9e46e8aa7086d0cab12879137aad5238396bbe2a0e603481501daa8532a6'
PROBE_SHA = '0539f2716aefe6594c37cc61e12094b5b5b322f5473cd6ecbc0ae73c9b1504b3'


def require(condition, context):
    if not condition:
        raise AssertionError(context)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identity(path):
    path = Path(path)
    data = path.read_bytes()
    return {'path': str(path), 'bytes': len(data), 'sha256': digest(data)}


def bound_file(row):
    path = Path(row['path'])
    body = path.read_bytes()
    require(digest(body) == row['sha256'] and len(body) == row['bytes'], ('retained file identity differs', path))
    return body


def actual_sources(target, label, compiled):
    records, differences = [], []
    for row in compiled['files']:
        path = ROOT / row['path']
        body = path.read_bytes() if path.exists() else None
        actual = digest(body) if body is not None else None
        records.append({'path': row['path'], 'sha256': actual})
        if actual != row['sha256']:
            difference = {'path': row['path'], 'compiled_sha256': row['sha256'], 'actual_sha256': actual}
            if body is not None:
                snapshot = OUT / target / ('source-' + label) / row['path']
                snapshot.parent.mkdir(parents=True, exist_ok=True)
                snapshot.write_bytes(body)
                difference['actual_source_text'] = identity(snapshot)
            differences.append(difference)
    source_sha = digest(json.dumps(records, sort_keys=True).encode())
    result = {'files': records, 'source_sha256': source_sha, 'differences_from_compiled_source': differences}
    path = OUT / target / ('source-' + label + '.json')
    path.write_text(json.dumps(result, indent=2) + '\n')
    return {**identity(path), 'source_sha256': source_sha, 'differences_from_compiled_source': differences}


def run(target, qa_epoch):
    directory = OUT / target
    directory.mkdir(parents=True, exist_ok=True)
    prior_identity = identity(PRIOR)
    prior = json.loads(PRIOR.read_text())
    rows = [row for row in prior['rows'] if row['target'] == target]
    require(len(rows) == 108 and all(row['status'] == 'matched' for row in rows), 'prior retained comparison scope')
    report_path = BASE / (target + '-fixed/differential.json')
    final_identity = identity(report_path)
    final = json.loads(report_path.read_text())
    require(final['counts']['cases'] == 450 and final['counts']['passed'] == 450 and final['counts']['failed'] == 0,
            ('final probe parent gate must have passed', target, final['counts']))
    require(final['source_epoch'] == 'root-5e5d9e46', 'final executable source epoch')
    compiled = {row['path']: row['sha256'] for row in final['source']['files']}
    require(compiled['src/br.zig'] == FINAL_BR_SHA and compiled['tools/br/large_history_probe.zig'] == PROBE_SHA,
            'final compiled root/probe source identity')
    require(identity(ROOT / 'src/br.zig')['sha256'] == FINAL_BR_SHA and
            identity(ROOT / 'tools/br/large_history_probe.zig')['sha256'] == PROBE_SHA,
            'current final runtime source identity differs')
    exe = Path(final['probe']['path'])
    require(identity(exe) == final['probe'], 'final new executable identity differs')
    (directory / 'parent-final-report-pinned.json').write_bytes(report_path.read_bytes())
    source_before = actual_sources(target, 'before', final['source'])
    module_path = ROOT / 'tools/br/metadata_diff.py'
    spec = importlib.util.spec_from_file_location('metadata_gate', module_path)
    gate = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(gate)
    libraries = Path('/tmp/vort-br-general-experimental-build')
    reference = gate.Reference(libraries / 'libbrotlienc.so.1.2.0', libraries / 'libbrotlidec.so.1.2.0',
                               libraries / 'libbrotlicommon.so.1.2.0')
    results, commands = [], []
    for original in rows:
        name, c = original['name'], original['settings']
        payload = bound_file(original['input'])
        old_wire = bound_file(original['old']['wire'])
        config_path = directory / (name + '.config.json')
        config_path.write_text(json.dumps(c, indent=2) + '\n')
        wire_path = directory / (name + '.br')
        require(not wire_path.exists(), ('refuse stale final output', wire_path))
        command = ['taskset', '-c', '10-15', str(exe), original['input']['path'], str(wire_path), str(config_path)]
        process = subprocess.run(command, capture_output=True, check=False, timeout=120, cwd=ROOT)
        stdout_path, stderr_path = directory / (name + '.stdout'), directory / (name + '.stderr')
        stdout_path.write_bytes(process.stdout)
        stderr_path.write_bytes(process.stderr)
        invocation = {'command': command, 'exit_code': process.returncode, 'stdout': identity(stdout_path), 'stderr': identity(stderr_path)}
        commands.append(invocation)
        entry = {'name': name, 'target': target, 'scope': original['scope'], 'settings': c,
                 'input': original['input'], 'config': identity(config_path), 'retained_old_wire': original['old']['wire'],
                 'retained_old_probe_epoch': prior['old_source_before']['commit'],
                 'new_invocation': invocation, 'new_probe': None, 'new_wire': None, 'reference_decode': None,
                 'wire_equal': False, 'status': 'pending'}
        try:
            require(process.returncode == 0, (name, 'final probe exit', process.returncode))
            new = json.loads(process.stdout)
            entry['new_probe'] = new
            require(new['error'] is None and new['config'] == c, (name, 'final probe settings/error', new['error']))
            new_wire = wire_path.read_bytes()
            entry['new_wire'] = identity(wire_path)
            require(new['input_sha256'] == digest(payload) and new['input_bytes'] == len(payload) and
                    new['wire_sha256'] == digest(new_wire) and new['wire_bytes'] == len(new_wire) and
                    new['self_decode_verified'] and new['borrowed_input_verified'], 'final probe identity/full contents')
            entry['wire_equal'] = old_wire == new_wire
            if not entry['wire_equal']:
                index = next((i for i, pair in enumerate(zip(old_wire, new_wire)) if pair[0] != pair[1]), min(len(old_wire), len(new_wire)))
                entry['first_differing_byte'] = index
                entry['old_difference_hex'] = old_wire[max(0, index - 8):index + 16].hex()
                entry['new_difference_hex'] = new_wire[max(0, index - 8):index + 16].hex()
            decoded = reference.decode(new_wire, payload, allow_large=c['large_window'])
            entry['reference_decode'] = decoded
            require(decoded['complete_contents_verified'], 'final independent complete plaintext')
            require(entry['wire_equal'], (name, 'final wire differs from retained old wire'))
            if 'reset' in original['old']:
                old_reset = bound_file(original['old']['reset']['wire'])
                reset_path = Path(str(wire_path) + '.reset.br')
                new_reset = reset_path.read_bytes()
                suffix = payload[-min(len(payload), 258):]
                reset_decode = reference.decode(new_reset, suffix, allow_large=c['large_window'])
                entry['reset'] = {'retained_old_wire': original['old']['reset']['wire'], 'new_wire': identity(reset_path),
                                  'wire_equal': old_reset == new_reset, 'reference_decode': reset_decode}
                require(new['new_stream_matches_fresh_wire'] and new['reset_wire_sha256'] == digest(new_reset) and
                        new['reset_input_sha256'] == digest(suffix) and old_reset == new_reset and reset_decode['complete_contents_verified'],
                        (name, 'final reset wire parity/full contents'))
            entry['status'] = 'matched'
        except (AssertionError, json.JSONDecodeError, OSError) as error:
            entry['status'], entry['failure'] = 'failed', str(error)
            print(json.dumps({'target': target, 'case': name, 'failure': str(error)}), flush=True)
        results.append(entry)
    source_after = actual_sources(target, 'after', final['source'])
    require(identity(PRIOR) == prior_identity, 'prior parity report changed during refresh')
    require(identity(exe) == final['probe'] and identity(report_path) == final_identity, 'final executable or parent report changed')
    counts = {'comparisons': len(results), 'matched': sum(row['status'] == 'matched' for row in results),
              'counterexamples': sum(row['status'] != 'matched' for row in results),
              'new_main_reference_decodes': sum(row['reference_decode'] is not None for row in results),
              'reset_comparisons': sum('reset' in row for row in results),
              'new_reset_reference_decodes': sum('reset' in row for row in results),
              'old_probe_executions': 0, 'old_reference_decodes': 0, 'compilations': 0}
    result = {'schema': 'vort.br.large-history-final-parity.v1', 'created_utc': datetime.now(timezone.utc).isoformat(),
              'target': target, 'source_epoch': final['source_epoch'], 'parent_qa_epoch': qa_epoch,
              'prior_parity': prior_identity, 'prior_parity_epoch_preserved': True,
              'retained_old_source': prior['old_source_before'], 'retained_old_executable': prior['compilations'][target]['executable'],
              'final_new_executable': identity(exe), 'parent_final_report': final_identity,
              'parent_final_report_pinned': identity(directory / 'parent-final-report-pinned.json'),
              'compiled_source': final['source'], 'actual_source_before': source_before, 'actual_source_after': source_after,
              'actual_sources_preserved': source_before['source_sha256'] == source_after['source_sha256'],
              'final_runtime_root_sha256': FINAL_BR_SHA, 'frozen_probe_sha256': PROBE_SHA,
              'reference': reference.identity(), 'harness': identity(Path(__file__)),
              'scope': prior['scope'], 'measurement_scope': 'Only final new probe executions; retained old bytes/hashes; full plaintext reference verification; no compilation, old probe execution, or timing measurement.',
              'counts': counts, 'counterexamples': [row['name'] for row in results if row['status'] != 'matched'],
              'rows': results, 'commands': commands}
    path = OUT / (target + '-final-parity.json')
    path.write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps({'report': str(path), 'sha256': identity(path)['sha256'], **counts}), flush=True)


def aggregate():
    paths = [OUT / (target + '-final-parity.json') for target in ('native', 'x86')]
    records = [json.loads(path.read_text()) for path in paths]
    require(all(row['counts']['comparisons'] == 108 for row in records), 'final target comparison counts')
    counts = {key: sum(row['counts'][key] for row in records) for key in records[0]['counts']}
    require(counts['comparisons'] == 216 and counts['new_main_reference_decodes'] == 216 and
            counts['reset_comparisons'] == 120 and counts['new_reset_reference_decodes'] == 120, 'final combined scope')
    report = {'schema': 'vort.br.large-history-final-parity-combined.v1', 'created_utc': datetime.now(timezone.utc).isoformat(),
              'source_epoch': 'root-5e5d9e46', 'prior_parity': identity(PRIOR), 'targets': [identity(path) for path in paths],
              'counts': counts, 'all_rows_matched': all(not row['counterexamples'] for row in records),
              'actual_sources_preserved_by_target': {row['target']: row['actual_sources_preserved'] for row in records},
              'measurement_scope': 'Final new-only runtime refresh against retained legacy artifacts; original earlier-epoch parity report remains untouched.',
              'counterexamples': [{row['target']: row['counterexamples']} for row in records if row['counterexamples']]}
    path = OUT / 'final-parity.json'
    path.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'report': str(path), 'sha256': identity(path)['sha256'], **counts}), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', choices=('native', 'x86'))
    parser.add_argument('--qa-epoch', default='finalQA7931')
    parser.add_argument('--aggregate', action='store_true')
    args = parser.parse_args()
    if args.aggregate:
        aggregate()
    else:
        require(args.target is not None, '--target is required')
        run(args.target, args.qa_epoch)
