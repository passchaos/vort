#!/usr/bin/env python3
"""Verify retained q8 focused-gate data only; no build or test execution."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import tarfile

REGISTRY_SHA = {
    1: 'a5a9d0b9bf0c519578f250147b9c237c80e976cdd2e868b63ef892c2e8259093',
    2: 'd191786db04e960755ed88389d555094ecd19ac47c0448b4d2ad38f47c99ea99',
    3: '15ec471070715e1e936e1f40849a6bf6ecded01f8b4987defd783c6af4ac90f7',
    4: '7b65820bd87c29b37cc21d4b0d2b5867781064ab067c3c7c731bbef445d7a9a8',
    5: 'dd21162bfc7912cbc932781c9ccafd6ea7e2017b5d62037e11cdd7645b629eaf',
}
BUILDS = range(1, 6)
FUNCTIONAL = (2, 3, 5)
TARGETS = ('native', 'wasi')
GATE_FILES = ('receipt.json', 'stdout.log', 'stderr.log', 'source-before.json', 'source-after.json')
WASI_JS = 'tools/br/deferred_preferred_wasm_gate.js'
TEST_SOURCE = 'src/br/encoder/deferred_preferred_tests.zig'
BUILD_ARGV = ['taskset', '-c', '6,7', 'zig', 'build', '-j2', 'build-br-deferred-preferred', '-Doptimize=ReleaseSafe', '--summary', 'all']


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    with path.open('rb') as f:
        return sha_stream(f)


def sha_stream(file):
    h = hashlib.sha256()
    for block in iter(lambda: file.read(1024 * 1024), b''):
        h.update(block)
    return h.hexdigest()


def read(path):
    return json.loads(path.read_bytes())


def safe_name(name):
    p = PurePosixPath(name)
    return bool(p.parts) and not p.is_absolute() and '..' not in p.parts and str(p) == name


def build_release(i):
    return 'build-only-release.json' if i == 1 else f'build-only-v{i}-release.json'


def originals():
    labels = [f'build-only-v{i}' for i in BUILDS] + [f'functional-v{i}-{t}' for i in FUNCTIONAL for t in TARGETS]
    return {f'evidence/{g}/{f}' for g in labels for f in GATE_FILES} | {
        'source/' + name for name in (
            *(f'source-frozen-build-v{i}.json' for i in BUILDS), 'v1-reconstructed-source-proof.json',
            'v1-source-preservation.json', 'v2-preserved-identities.json', 'v3-preserved-identities.json',
        )
    } | {'evidence/authorization/' + name for name in (
        'plan.json', *(build_release(i) for i in BUILDS),
        *(f'functional-v{i}-{x}.json' for i in FUNCTIONAL for x in ('release', 'results')),
    )}


def inventory(root):
    wanted = originals() | {'capture.json', 'README.md', 'verify.py', 'source-overlay.tar.gz', 'historical-source-deltas.tar.gz'}
    if (root / 'verification-receipt.json').exists():
        wanted.add('verification-receipt.json')
    for name in sorted(wanted):
        require((root / name).is_file(), f'Missing required focused-gate/package artifact: {name}')
    paths = list(root.rglob('*'))
    require(all(not p.is_symlink() for p in paths), 'Unexpected symlink in the package')
    require({p.relative_to(root).as_posix() for p in paths if p.is_file()} == wanted | {'SHA256SUMS'}, 'Package inventory differs')
    checks = {}
    for line in (root / 'SHA256SUMS').read_text().splitlines():
        h, name = line.split('  ', 1)
        require(safe_name(name) and name not in checks and re.fullmatch('[0-9a-f]{64}', h), 'Invalid or duplicate SHA256SUMS entry')
        checks[name] = h
    require(set(checks) == wanted, 'Checksum inventory differs')
    for name in wanted:
        require(sha(root / name) == checks[name], f'SHA-256 mismatch: {name}')
    return len(wanted)


def archive(root, meta, expected):
    path = root / meta['name']
    require((sha(path), path.stat().st_size, len(expected)) == (meta['sha256'], meta['bytes'], meta['files']), 'Compressed source inventory binding differs')
    seen = set()
    with tarfile.open(path, 'r|gz') as tar:
        for item in tar:
            name = item.name
            require(item.isreg() and safe_name(name) and name in expected and name not in seen, f'Unexpected source member: {name}')
            require(sha_stream(tar.extractfile(item)) == expected[name], f'Frozen member SHA mismatch: {name}')
            seen.add(name)
    require(seen == set(expected), 'Incomplete source overlay inventory')


def verify_sources(root, capture):
    manifests = {i: root / f'source/source-frozen-build-v{i}.json' for i in BUILDS}
    for i, path in manifests.items():
        require(sha(path) == REGISTRY_SHA[i], f'Frozen registry changed: v{i}')
    regs = {i: read(path) for i, path in manifests.items()}
    require(all(len(reg) == 2257 and set(reg) == set(regs[5]) for reg in regs.values()) and WASI_JS in regs[5], 'Frozen closure or additional WASI runner JS missing')
    meta = capture['source_overlay']
    require(meta['name'] == 'source-overlay.tar.gz' and meta['manifest_sha256'] == REGISTRY_SHA[5] and meta['includes_extra_WASI_runner_JS'] is True, 'v5 source identity differs')
    archive(root, meta, regs[5])
    expected = {f'v{i}/{p}': h for i in (1, 2, 3, 4) for p, h in regs[i].items() if regs[5][p] != h}
    delta = capture['historical_deltas']
    require(delta['name'] == 'historical-source-deltas.tar.gz' and {k: v['sha256'] for k, v in delta['members'].items()} == expected, 'Historical source delta metadata differs')
    old_proof = read(root / 'source/v1-reconstructed-source-proof.json')
    v1_original = read(root / 'source/v1-source-preservation.json')
    reconstructed = {'src/br.zig', 'src/br/encoder/command_group_selection.zig'}
    require(set(old_proof) == set(v1_original) == reconstructed and {k for k in regs[1] if regs[1][k] != regs[2][k]} == reconstructed, 'Unexpected v1/v2 changed files')
    for p in reconstructed:
        item = delta['members']['v1/' + p]
        require(item['role'] == 'exact-reconstruction-not-original-copy' and (item['sha256'], item['bytes']) == (old_proof[p]['sha256'], old_proof[p]['bytes']) and
                v1_original[p]['expected_v1_sha256'] == item['sha256'] and v1_original[p]['exact_v1_source_saved'] is False,
                f'Wrong reconstructed-v1 identity claim: {p}')
    require(regs[1][TEST_SOURCE] == regs[2][TEST_SOURCE] and delta['members']['v1/' + TEST_SOURCE]['role'] == 'same-hash-shared-with-v2-original-copy', 'v1 test source is not original matching v2 data')
    for i in (2, 3):
        originals_i = read(root / f'source/v{i}-preserved-identities.json')
        for p in ('src/br.zig', TEST_SOURCE):
            record = delta['members'][f'v{i}/{p}']
            require(record['role'] == 'original-preserved-source-copy' and record['sha256'] == originals_i[p]['sha256'], f'Historical preserved source differs: v{i}/{p}')
    require(delta['members']['v4/' + TEST_SOURCE]['role'] == 'original-preserved-source-copy', 'v4 failed test source is not the preserved original')
    archive(root, delta, expected)
    return regs, len(expected)


def verify_gate(root, directory, i, release, expected_exit):
    folder = root / 'evidence' / directory
    receipt = read(folder / 'receipt.json')
    require(receipt['actual_exit_code'] == expected_exit and receipt['source_unchanged'] is True and receipt['started_unix'] < receipt['ended_unix'], f'Original terminal receipt differs: {directory}')
    require(receipt['source_manifest_sha256'] == REGISTRY_SHA[i] and
            all(sha(folder / f'source-{side}.json') == REGISTRY_SHA[i] for side in ('before', 'after')),
            f'Original before/after source maps differ: {directory}')
    for stream in ('stdout', 'stderr'):
        require(sha(folder / f'{stream}.log') == receipt[f'{stream}_sha256'], f'Original process stream differs: {directory}/{stream}')
    require(sha(release) == receipt['release_sha256'], f'Original stage release identity differs: {directory}')
    return receipt, (folder / 'stderr.log').read_text()


def verify_outcomes(root, regs):
    auth = root / 'evidence/authorization'
    summary = {}
    for i in BUILDS:
        release = auth / build_release(i)
        r = read(release)
        gate = f'build-only-v{i}'
        expected = int(i in (1, 4))
        receipt, log = verify_gate(root, gate, i, release, expected)
        terminal = 'Build Summary: 4/9 steps succeeded (2 failed)' if expected else 'Build Summary: 9/9 steps succeeded'
        require(terminal in log and receipt['argv'] == r['argv'] == BUILD_ARGV and receipt['launch_error'] is None and
                receipt['codec_execution'] is False and receipt['timing_execution'] is False and r['timing_released'] is False and
                r['codec_execution_released'] is False and r['source_manifest_sha256'] == REGISTRY_SHA[i],
                f'Original compile-only scope or terminal result differs: {gate}')
        if i == 1:
            require('error: 6 compilation errors' in log and 'invalid left-hand side to assignment' in log, 'Original v1 compiler failure absent')
        if i == 4:
            require("operator == not allowed for type 'error{InvalidBlockPlan}!?anyerror'" in log, 'Original v4 compiler failure absent')
        summary[gate] = {'actual_exit_code': expected, 'summary': terminal}
    for i in FUNCTIONAL:
        release_path = auth / f'functional-v{i}-release.json'
        release = read(release_path)
        report = read(auth / f'functional-v{i}-results.json')
        expected_exit = int(i != 5)
        require(report['completed'] is True and report['success'] is (not expected_exit) and len(report['stages']) == 2 and report['throughput_or_resource_benchmark'] is False and
                release['build_receipt_sha256'] == sha(root / f'evidence/build-only-v{i}/receipt.json') and release['source_manifest_sha256'] == REGISTRY_SHA[i] and
                release['timing_released'] is False and release['resource_benchmark_released'] is False,
                f'Original functional result/release scope differs: v{i}')
        for j, kind in enumerate(TARGETS):
            label = f'functional-v{i}-{kind}'
            receipt, log = verify_gate(root, label, i, release_path, expected_exit)
            require(receipt == report['stages'][j] and receipt['target'] == kind and receipt['argv'] == release['commands'][kind] and receipt['throughput_or_RSS_measurement'] is False,
                    f'Original functional raw result/argv binding differs: {label}')
            if kind == 'wasi':
                require(receipt['argv'][3] == 'node' and receipt['argv'][4].endswith(WASI_JS), 'Original WASI runner invocation not retained')
            if i in (2, 3):
                old = read(root / f'source/v{i}-preserved-identities.json')
                require(old[kind]['sha256'] == release['artifacts'][kind]['sha256'], f'Original rejected artifact digest differs: {label}')
                failure = 'FAIL (TestUnexpectedResult)' if i == 2 else 'FAIL (InvalidBlockPlan)'
                require('39 passed; 0 skipped; 1 failed.' in log and failure in log, f'Original focused failure absent: {label}')
            else:
                require('All 40 tests passed.' in log and re.search(r'4/40 br.test.Brotli deferred preferred public wire and error checkpoints', log), f'Original v5 focused 40/40 or contract witness absent: {label}')
                if kind == 'wasi':
                    runner = read(root / f'evidence/{label}/stdout.log')
                    require((runner['target'], runner['tests_passed'], runner['exit_code'], runner['measured_stack'], runner['wasm_sha256']) == ('wasm32-wasi', 40, 0, False, release['artifacts']['wasi']['sha256']), 'Actual v5 WASI run receipt/wasm identity/scope differs')
            summary[label] = {'actual_exit_code': expected_exit, 'tests_passed': 39 if expected_exit else 40, 'tests_observed': 40}
    return summary


def verify(root):
    count = inventory(root)
    capture = read(root / 'capture.json')
    original = capture['original_files_copied_byte_for_byte']
    require(set(original) == originals(), 'Original capture index differs')
    for name, record in original.items():
        path = root / name
        require((path.stat().st_size, sha(path)) == (record['bytes'], record['sha256']), f'Original byte capture identity differs: {name}')
    require(all(capture[key] is False for key in ('memoryGate', 'industryLeadership', 'broader_gate_included', 'executables_included')), 'Unexpected performance/broader scope promotion')
    regs, legacy_files = verify_sources(root, capture)
    return {'schema': 'vort.br.deferred-preferred.offline-verification.v1', 'status': 'pass', 'inventory_files': count,
            'focused_gates': verify_outcomes(root, regs), 'v5_source_registry_sha256': REGISTRY_SHA[5], 'v5_source_members': len(regs[5]),
            'additional_wasi_js_sha256': regs[5][WASI_JS], 'historical_changed_members': legacy_files,
            'v1_two_reconstructed_members_are_not_original_copies': True, 'broader_gate_validated': False, 'memoryGate': False,
            'performance_acceptance': False, 'industryLeadership': False, 'codec_build_producer_or_original_paths_executed': False}


def main():
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('--root', type=Path, default=Path(__file__).resolve().parent)
    args = cli.parse_args()
    try:
        print(json.dumps(verify(args.root.resolve()), indent=2, sort_keys=True))
    except (OSError, ValueError, KeyError, tarfile.TarError) as exc:
        cli.exit(1, f'Verification failed: {exc}\n')


if __name__ == '__main__':
    main()
