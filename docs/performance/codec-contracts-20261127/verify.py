#!/usr/bin/env python3
"""Offline verifier for archived source bytes and recorded codec test receipts."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import tarfile

INITIAL_SHA = '336ed33932ffcbf49d666eefe13fd926d72f29207002cfe4c423e38504de8813'
FINAL_SHA = 'beb79f99ed3809717dee3d3a3438247f835c45f012bfbb3aeab6cab6e6b0955f'
CLONE = 'src/tests/deflate_clone/encoder.zig'
API = 'src/deflate/incremental/encoder/'
SOURCE_REQUIRED = {
    CLONE, 'src/deflate.zig', 'src/io/requested_heap_budget.zig',
    *(API + f for f in ('fixed.zig', 'stored.zig', 'zlib_fixed.zig', 'gzip_fixed.zig', 'resource_budget.zig')),
}
WHOLE = ['taskset', '-c', '0-15', 'zig', 'build', '-j2', 'test', 'check', 'check-wasm', '-Doptimize=ReleaseSafe', '--summary', 'all']
GATES = {
    'whole-initial': (WHOLE, 1, '417/419 steps succeeded (1 failed); 6107/6110 tests passed (2 skipped, 1 failed)'),
    'whole-final': (WHOLE, 0, '419/419 steps succeeded; 6108/6110 tests passed (2 skipped)'),
    'clone-native': (['taskset', '-c', '6,7', 'zig', 'build', '-j2', 'test-deflate-clone', '-Doptimize=ReleaseSafe', '--summary', 'all'], 0, '9/9 steps succeeded; 104/104 tests passed'),
    'clone-wasi': (['taskset', '-c', '10,11', 'zig', 'build', '-j2', 'test-deflate-clone-wasm', '-Doptimize=ReleaseSafe', '--summary', 'all'], 0, '9/9 steps succeeded'),
}
GATE_FILES = ('receipt.json', 'stdout.log', 'stderr.log', 'source-before.json', 'source-after.json')
SOURCE_FILES = ('source/candidate-before-clone.json', 'source/candidate-after-clone.json', 'source/encoder-before-clone.zig', 'source/clone-types-only.diff')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def hash_file(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def read_json(path):
    return json.loads(path.read_bytes())


def relative_name(name):
    path = PurePosixPath(name)
    return bool(path.parts) and not path.is_absolute() and '..' not in path.parts and str(path) == name


def verify_inventory(root):
    expected = {f'evidence/{g}/{f}' for g in GATES for f in GATE_FILES} | set(SOURCE_FILES)
    expected |= {'capture.json', 'source-overlay.tar.gz', 'README.md', 'verify.py'}
    for name in expected:
        require((root / name).is_file(), f'Missing required gate or package artifact: {name}')
    for path in root.rglob('*'):
        require(not path.is_symlink(), f'Unexpected package symlink: {path.relative_to(root)}')
    if (root / 'verification-receipt.json').exists():
        expected.add('verification-receipt.json')
    require({p.relative_to(root).as_posix() for p in root.rglob('*') if p.is_file()} == expected | {'SHA256SUMS'}, 'Package inventory differs')
    recorded = {}
    for line in (root / 'SHA256SUMS').read_text().splitlines():
        h, name = line.split('  ', 1)
        require(relative_name(name) and name not in recorded and re.fullmatch('[0-9a-f]{64}', h), 'Invalid/duplicate SHA256SUMS member')
        recorded[name] = h
    require(set(recorded) == expected, 'SHA256SUMS inventory differs')
    for name in expected:
        require(hash_file(root / name) == recorded[name], f'SHA-256 mismatch: {name}')
    return len(recorded)


def verify_overlay(path, registry):
    seen, selected = set(), {}
    with tarfile.open(path, 'r|gz') as tar:
        for member in tar:
            name = member.name
            require(relative_name(name) and member.isreg() and name in registry and name not in seen,
                    f'Unexpected or duplicate source member: {name}')
            seen.add(name)
            reader = tar.extractfile(member)
            if name in SOURCE_REQUIRED:
                payload = reader.read()
                selected[name] = payload.decode()
                h = digest(payload)
            else:
                hasher = hashlib.sha256()
                for chunk in iter(lambda: reader.read(1024 * 1024), b''):
                    hasher.update(chunk)
                h = hasher.hexdigest()
            require(h == registry[name], f'Frozen source member SHA differs: {name}')
    require(seen == set(registry) and SOURCE_REQUIRED <= set(selected), 'Incomplete frozen source overlay')
    return selected


def verify_clone(root, before, after, source):
    require(set(before) == set(after) and {k for k in before if before[k] != after[k]} == {CLONE}, 'The complete registry delta is not the sole clone-test change')
    old = (root / SOURCE_FILES[2]).read_bytes()
    require(digest(old) == before[CLONE], 'Original clone test is not bound to the prior registry')
    changed = source[CLONE]
    delta = ''.join(difflib.unified_diff(old.decode().splitlines(keepends=True), changed.splitlines(keepends=True), 'old/' + CLONE, 'fresh/' + CLONE))
    require(delta.encode() == (root / SOURCE_FILES[3]).read_bytes(), 'Retained test-only patch does not reproduce the registry-bound files')
    require('const ExpectedCloneError = if (E == D.RawDeflateIncrementalStoredEncoder)' in changed and
            'try std.testing.expectEqual(ExpectedCloneError, E.CloneError);' in changed and
            'try std.testing.expectEqual(error.OutOfMemory, err);' in changed, 'Clone error-set and physical OOM assertions changed')
    errors = {'OutOfMemory', 'IntegerOverflow', 'InvalidBlockPlan', 'WorkingMemoryLimitExceeded'}
    for expr, text in [(r'ExpectedCloneError = if \(E == D.RawDeflateIncrementalStoredEncoder\)\s+std.mem.Allocator.Error\s+else\s+error\{([^}]+)\}', changed),
                       (r'pub const Error = error\{([^}]+)\}', source['src/io/requested_heap_budget.zig'])]:
        m = re.search(expr, text)
        require(m is not None and {s.strip() for s in m[1].split(',')} == errors, 'Exact Fixed/Best clone error members differ')
    cases = {'RawDeflateIncrementalStoredEncoder', *(f'{wrapper}Incremental{mode}Encoder' for wrapper in ('RawDeflate', 'Zlib', 'Gzip') for mode in ('Fixed', 'Best'))}
    require(set(re.findall(r'\.\{ D\.(\w+), Kind\.\w+ \},', changed)) == cases and 'try branch(D, entry[0], allocator, entry[1]);' in changed, 'Expected Stored plus six actual Fixed/Best clone branches')
    require(all(f'pub const {e} =' in source['src/deflate.zig'] for e in cases), 'Actual public encoder classes missing')
    for name, clause in (('stored.zig', 'std.mem.Allocator.Error'), ('fixed.zig', 'std.mem.Allocator.Error || resource_budget.Error'), ('zlib_fixed.zig', 'Codec.RawEncoder.CloneError || std.mem.Allocator.Error'), ('gzip_fixed.zig', 'Codec.RawEncoder.CloneError || std.mem.Allocator.Error')):
        require(f'pub const CloneError = {clause};' in source[API + name], f'Actual clone type path differs: {name}')
    require('pub const Error = shared.Error;' in source[API + 'resource_budget.zig'], 'Actual shared budget error alias differs')
    return {'test_source': CLONE, 'before_sha256': before[CLONE], 'after_sha256': after[CLONE], 'fixed_best_count': 6, 'stored_error_set': ['OutOfMemory'], 'fixed_best_error_set': sorted(errors)}


def verify_gates(root, before, after):
    results = {}
    selected = {}
    for label, (argv, code, summary) in GATES.items():
        folder = root / 'evidence' / label
        receipt = read_json(folder / 'receipt.json')
        require(receipt['argv'] == argv and receipt['actual_exit_code'] == code and receipt['source_unchanged'] is True and
                receipt['started_unix'] < receipt['ended_unix'], f'Original process receipt differs: {label}')
        start_bytes = (folder / 'source-before.json').read_bytes()
        require(start_bytes == (folder / 'source-after.json').read_bytes(), f'Selected source changed within gate: {label}')
        selected[label] = json.loads(start_bytes)
        expected = before if label == 'whole-initial' else after
        require(len(selected[label]) == (29 if label == 'whole-initial' else 30) and
                all(expected.get(k) == h for k, h in selected[label].items()), f'Selective source gate registry mismatch: {label}')
        log = (folder / 'stderr.log').read_text()
        require(re.findall(r'^Build Summary: (.*)$', log, re.M) == [summary], f'Original summary differs: {label}')
        if label == 'whole-initial':
            require("error: 'deflate.test.Deflate clone safe copy contracts' failed:" in log and
                    'expected type error{OutOfMemory}, found type error{IntegerOverflow,InvalidBlockPlan,OutOfMemory,WorkingMemoryLimitExceeded}' in log,
                    'Missing original clone type failure')
        if label == 'whole-final':
            for token in ('test success', 'check success', '+- check-wasm success'):
                require(token in log, 'Missing final validated step: ' + token)
        if label == 'clone-wasi':
            for token in ('run node success', 'vort-deflate-clone-wasm-tests ReleaseSafe wasm32-wasi success', 'vort-deflate-clone-wasm-public-tests ReleaseFast wasm32-wasi success'):
                require(token in log, 'Missing original executed WASI evidence: ' + token)
        results[label] = {'actual_exit_code': code, 'summary': summary, 'source_files_selected': len(selected[label])}
    require(set(selected['whole-final']) - set(selected['whole-initial']) == {CLONE} and
            all(selected['whole-final'][k] == h for k, h in selected['whole-initial'].items()) and
            selected['clone-native'] == selected['clone-wasi'] == selected['whole-final'], 'Inconsistent original gate source selection')
    return results


def verify(root):
    files = verify_inventory(root)
    capture = read_json(root / 'capture.json')
    require(set(capture['original_files_copied_byte_for_byte']) == {f'evidence/{g}/{f}' for g in GATES for f in GATE_FILES} | set(SOURCE_FILES), 'Original capture inventory differs')
    for name, record in capture['original_files_copied_byte_for_byte'].items():
        p = root / name
        require((p.stat().st_size, hash_file(p)) == (record['bytes'], record['sha256']), f'Original capture identity differs: {name}')
    old, current = (root / name for name in SOURCE_FILES[:2])
    require((hash_file(old), hash_file(current)) == (INITIAL_SHA, FINAL_SHA), 'Frozen source manifest anchors differ')
    before, after = read_json(old), read_json(current)
    overlay = root / 'source-overlay.tar.gz'
    meta = capture['final_frozen_source_overlay']
    require((meta['file'], meta['manifest'], meta['files'], meta['bytes'], meta['sha256'], len(after)) == (overlay.name, SOURCE_FILES[1], 2267, overlay.stat().st_size, hash_file(overlay), 2267), 'Overlay binding differs')
    selected = verify_overlay(overlay, after)
    clone = verify_clone(root, before, after, selected)
    results = verify_gates(root, before, after)
    return {'schema': 'vort.codec-contracts-20261127.offline-verification.v1', 'status': 'pass', 'inventory_files': files,
            'frozen_files_verified': len(after), 'manifest_sha256': FINAL_SHA, 'clone_contract': clone, 'gates': results,
            'performance_or_pending_warm_matrix_validated': False, 'codec_build_timing_or_original_paths_used': False}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=Path(__file__).resolve().parent)
    args = p.parse_args()
    try:
        print(json.dumps(verify(args.root.resolve()), indent=2, sort_keys=True))
    except (ValueError, KeyError, OSError, tarfile.TarError) as error:
        p.exit(1, f'Verification failed: {error}\n')


if __name__ == '__main__':
    main()
