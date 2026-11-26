"""Bind frozen source, build, validation and historical failures as data."""
from package_io import lines, load, read_tar, require, sha, verify_reference


def verify_build_argv(argv):
    require(argv[:2] == ['zig', 'build-exe'], 'Compiler command differs')
    root = next(i for i, arg in enumerate(argv) if arg.startswith('-Mroot='))
    codec = next(i for i, arg in enumerate(argv) if arg.startswith('-Mcodec='))
    require(root < codec, 'Compiler module order differs')
    for segment in [argv[:root], argv[root + 1:codec]]:
        for flag, value in [('-O', 'ReleaseFast'), ('-target', 'x86_64-linux-gnu'), ('-mcpu', 'skylake+pku+sgx')]:
            require(flag in segment and segment[segment.index(flag) + 1] == value,
                    'Per-module compiler settings differ')


def verify_sources_builds(files, common, manifest, artifact):
    actual = {name.removeprefix('source/'): sha(data) for name, data in files.items() if name.startswith('source/src/')}
    require(len(actual) == 2216 and actual == load(files, 'final-source.json') ==
            load(files, 'performance/source-before.json') == load(files, 'performance/source-after.json'),
            'Frozen source2216 differs')
    require('src/deflate/zlib/fixtures/__pycache__/generate_small_cinfo.cpython-310.pyc' in actual,
            'Frozen bytecode source member was lost')
    source_sha = sha(files['final-source.json'])
    binding = load(files, 'probe-build/source-binding.json')
    require(binding['actual_source'] == actual and binding['source_files'] == 2216 and
            binding['source_manifest_sha256'] == source_sha == artifact['current_source_manifest_sha256'] ==
            manifest['source_binding']['manifest_sha256'], 'Source/build binding differs')
    require(binding['probe_sha256'] == artifact['probe_sha256'] == sha(files['probe.zig']) ==
            sha(files['performance/build/probe.zig']), 'Probe source identity differs')
    for relative, key in [('performance/manifest.json', 'manifest_sha256'),
                          ('performance/campaign.py', 'campaign_sha256'),
                          ('performance/preflight.json', 'preflight_sha256')]:
        require(sha(files[relative]) == artifact[key], 'Campaign artifact differs: ' + relative)
    builds = {}
    for which in ['old', 'current']:
        build = load(files, 'performance/build/' + which + '-build.json')
        binary = files['performance/build/' + which + '-probe']
        require(build['returncode'] == 0 and build['elf_sha256'] == artifact[which + '_elf_sha256'] == sha(binary) and
                build['elf_size'] == len(binary) and build['zig_version'] == '0.16.0', 'Build/ELF identity differs')
        verify_build_argv(build['argv'])
        builds[which] = build
    compile_receipt = load(files, 'probe-build/exit.json')
    require(compile_receipt == builds['current'], 'Current compile receipt copy differs')
    executable = next(name for name in files if name.startswith('probe-build/') and name.endswith('-probe'))
    require(files[executable] == files['performance/build/current-probe'], 'Sampled current ELF differs from preflight ELF')
    for key, member in [('stdout_sha256', 'probe-build/stdout.log'), ('stderr_sha256', 'probe-build/stderr.log')]:
        require(compile_receipt[key] == sha(files[member]), 'Compile output capture differs')
    require(files['performance/build/old-build.json'] == common['baseline/build/old-build.json'] and
            files['performance/build/probe.zig'] == common['baseline/build/probe.zig'], 'Old build/probe copy differs')
    require(sha(common['baseline/old-source.tar']) == artifact['old_source_tar_sha256'] ==
            manifest['old_source_archive_sha256'], 'Old source snapshot identity differs')
    old = read_tar(common['baseline/old-source.tar'], 'r:', directories=True)
    old_manifest = builds['old']['source_manifest']['files']
    expected_old = {'src/' + row['path']: row['sha256'] for row in old_manifest}
    require({name: sha(data) for name, data in old.items() if name.startswith('src/')} == expected_old,
            'Old compiled source snapshot differs')
    for row in old_manifest:
        require(len(old['src/' + row['path']]) == row['size'], 'Old source size differs')
    provenance = load(files, 'public-preflight/provenance.json')
    require(provenance['source_manifest_sha256'] == source_sha and provenance['source_files'] == 2216 and
            provenance['probe_sha256'] == artifact['probe_sha256'] and
            provenance['new_ELF_sha256'] == artifact['current_elf_sha256'] and
            provenance['old_public_decode_ELF_sha256'] == artifact['old_elf_sha256'] and
            provenance['preflight_script_sha256'] == sha(files['public_preflight.py']), 'Preflight source/ELF binding differs')
    for ref in provenance['Python_references'] + provenance['C_references']:
        verify_reference(common, ref)
    for ref in load(files, 'performance/sampling-release.json')['reference_hashes']:
        verify_reference(common, ref)
    codegen = load(files, 'codegen/summary.json')
    require(codegen.get('elf_sha256', codegen.get('ELF_sha256')) == artifact['current_elf_sha256'] and
            codegen['build_returncode'] == 0 and codegen['timing_samples'] == 0, 'Codegen ELF binding differs')
    if 'source_manifest_sha256' in codegen:
        require(codegen['source_manifest_sha256'] == source_sha and codegen['probe_sha256'] == artifact['probe_sha256'],
                'Codegen source identity differs')
    return {'source_files': 2216, 'source_before_after_equal': True, 'source_manifest_sha256': source_sha,
            'old_source_files': len(expected_old), 'old_source_snapshot_verified': True,
            'build_elf_probe_and_codegen_bindings_verified': True,
            'scope': 'Source bytes, stored compiler receipts and codegen identity; no disassembler/compiler executed'}


def verify_terminal_receipts(files, artifact):
    terminal = load(files, 'performance/sample-exit.json')
    require(terminal.get('exit_code', terminal.get('returncode')) == 0 and
            files['performance/sample.stderr'] == b'', 'Complete sampling terminal failed')
    raw_sha = sha(files['performance/samples/raw.jsonl'])
    verified = load(files, 'performance/sample-verification.json')
    require(verified['raw_sha256'] == raw_sha and verified['accepted'] is False and
            verified.get('raw_records', verified.get('records')) == 540,
            'Captured verification result differs')
    if 'stdout_sha256' in terminal:
        require(terminal['stdout_sha256'] == sha(files['performance/sample.stdout']) and
                terminal['stderr_sha256'] == sha(files['performance/sample.stderr']), 'Sampling terminal logs differ')
    native = load(files, 'validation/native-exit.json')
    wasm_build = load(files, 'validation/wasm-build-exit.json')
    wasi_exit = load(files, 'validation/wasi-exit.json')
    require(native['exit_code'] == wasm_build['exit_code'] == wasi_exit['exit_code'] == 0,
            'Variant functional gate terminal failed')
    require(b'All 30 tests passed.' in files['validation/native.stderr'] and
            files['validation/native.stderr'].count(b'...OK\n') == 30, 'Captured native test count differs')
    wasi = load(files, 'validation/wasi.stdout')
    require(wasi['status'] == 'ok' and wasi['pointer_bits'] == 32 and len(wasi['results']) == 1,
            'Captured actual WASI gate differs')
    for result in wasi['results']:
        member = 'validation/' + result['wasm_path'].rsplit('/', 1)[-1]
        require(result['exit_code'] == 0 and result['wasm_sha256'] == sha(files[member]) and
                result['wasm_bytes'] == len(files[member]), 'WASI captured module differs')
    preflight_exit = load(files, 'public-preflight-exit.json')
    require(preflight_exit.get('exit_code', preflight_exit.get('returncode')) == 0, 'Public preflight terminal failed')
    return {'raw_sha256': raw_sha, 'sample_exit_code': 0, 'native_tests': 30,
            'actual_wasi_exit_code': 0, 'wasm_module_hash_verified': True,
            'scope': 'Recorded variant prerequisite gates; no new full-source adoption gate or memory/RSS measurement'}


def verify_previous_and_failures(packages):
    common = packages['common.tar.gz']
    v2, v3 = packages['v2-reserved-sink.tar.gz'], packages['v3-direct-bits.tar.gz']
    baseline = load(common, 'baseline/result.json')
    require(baseline['accepted'] is False and len(lines(common, 'baseline/samples/raw.jsonl')) == 540,
            'Original rejected epoch evidence differs')
    previous = load(v2, 'performance/artifact-hashes.json')['previous_failed_epoch']
    require(previous['result_sha256'] == sha(common['baseline/result.json']) and
            previous['raw_sha256'] == sha(common['baseline/samples/raw.jsonl']), 'V2 prior rejected epoch binding differs')
    for ref in load(v3, 'performance/artifact-hashes.json')['previous_failed_epochs']:
        origin, prefix = (common, 'baseline/') if ref['epoch'] == 'V1' else (v2, 'performance/')
        require(ref['accepted'] is False and ref['result_sha256'] == sha(origin[prefix + 'result.json']) and
                ref['raw_sha256'] == sha(origin[prefix + 'samples/raw.jsonl']), 'V3 previous rejected epoch binding differs')
    require(load(v3, 'baseline-source.json') == load(v2, 'final-source.json'), 'V3 baseline source differs from V2')
    failure = lines(v3, 'performance/launch-failure-permissions/chronology.jsonl')
    require(len(failure) == 1 and failure[0]['returncode'] == 126 and failure[0]['stdout'] == '' and
            'Permission denied' in failure[0]['stderr'] and 'probe' not in failure[0] and
            load(v3, 'performance/launch-failure-permissions/sample-exit.json')['exit_code'] == 1,
            'Initial permission failure capture differs')
    require(b'Permission denied' in v3['performance/launch-failure-permissions/sample.stderr'], 'Permission failure log missing')
    label = load(v3, 'performance/verification-group-name-failure/original-tool-result.json')
    require(label['exit_code'] == 1 and 'ValueError: min() arg is an empty sequence' in label['output'],
            'Historical verifier group-label failure differs')
    require(load(v3, 'performance/verification-exit.json')['exit_code'] == 0 and
            load(v3, 'performance/sample-verification.json')['verifier_sha256'] == sha(v3['verify_screen.py']),
            'Corrected verifier actual exit or identity differs')
    for receipt in ['baseline/refs/c-build-provenance.json', 'baseline/refs/python-zlib.json']:
        for ref in load(common, receipt)['references']:
            verify_reference(common, ref)
    return {'previous_rejected_epoch_bindings_verified': True,
            'v3_permission_failure_preserved': True, 'v3_successful_samples_in_failed_launch': 0,
            'v3_group_label_verifier_failure_preserved': True, 'v3_corrected_verifier_exit_code': 0}
