"""Check frozen source and original build/validation receipts as data."""
import re
from package_io import load, read_tar, require, sha


def verify_provenance(sources, bench, validation):
    baseline = read_tar(sources['baseline-source.tar'], 'r:', directories=True)
    current = {name.removeprefix('current/'): data for name, data in sources.items() if name.startswith('current/')}
    inventory = load(sources, 'source-inventory.json')
    require(len(baseline) == inventory['baseline_files'] == 2992 and len(current) == inventory['current_files'] == 3120 and
            {name: {'bytes': len(data), 'sha256': sha(data)} for name, data in current.items()} == inventory['current_source'],
            'Complete frozen source closure differs')
    require({name: {'bytes': len(data), 'sha256': sha(data)} for name, data in current.items() if name.endswith('.pyc')} ==
            inventory['current_pyc'] and len(inventory['current_pyc']) == 125, 'Generated source pyc identity differs')
    for label, files, name, count in [('old_exact', baseline, 'baseline-source-files.json', 2200),
                                      ('current', current, 'candidate-source-files.json', 2204)]:
        actual = {name: sha(data) for name, data in files.items() if name.startswith('src/')}
        require(len(actual) == count and actual == load(bench, name), 'Registered src identity differs')
    require(load(validation, 'final-source.json') == load(bench, 'candidate-source-files.json'),
            'Validation and bench frozen src differ')
    freeze = load(bench, 'SOURCEFREEZE')
    binding = load(bench, 'candidate-source-binding.json')
    require(sha(validation['final-source.json']) == freeze['source_manifest_sha256'] == binding['source_manifest_sha256'] and
            freeze['source_files'] == binding['files'] == 2204 and binding['root_marker_sha256'] == sha(bench['SOURCEFREEZE']),
            'Root frozen source marker identity differs')
    require('src/deflate/zlib/fixtures/__pycache__/generate_small_cinfo.cpython-310.pyc' in current and
            not any(name.endswith('/final_entropy_bound.zig') for name in current), 'Source epoch or registered pyc was lost')
    for name in ['src/br/encoder/complex_prefix.zig', 'src/br/encoder/literal_context_split.zig',
                 'src/br/encoder/literal_tree_score_cache.zig', 'src/br/encoder/literal_context_split/workspace.zig']:
        require(current[name] == baseline[name], 'Unrelated header/context hypothesis entered local source')
    epoch = load(bench, 'epoch.json')
    require(epoch['source_archive_sha256'] == sha(sources['baseline-source.tar']), 'CF baseline archive SHA differs')
    for name, expected in load(bench, 'artifact-bindings.json')['files'].items():
        if name == 'baseline-source.tar':
            data = sources[name]
        elif name.startswith('sources/current/'):
            data = current[name.removeprefix('sources/current/')]
        elif name.startswith('sources/old_exact/'):
            data = baseline[name.removeprefix('sources/old_exact/')]
        else:
            data = bench[name]
        require(sha(data) == expected['sha256'] and len(data) == expected['bytes'], 'Frozen artifact changed: ' + name)
    for name, expected in load(bench, 'harness-bindings.json')['files'].items():
        require(sha(bench[name]) == expected['sha256'] and len(bench[name]) == expected['bytes'], 'Frozen harness changed')
    settings = load(bench, 'settings.json')
    policy = load(bench, 'policy-frozen.json')
    require({key: value for key, value in settings.items() if key != 'variants'} == policy['settings_without_variants'] and
            settings['variants']['old_exact'] == policy['baseline_source_commit'] == 'cf442dee0144f4c0cc1823474f77c7e8b1685f2e' and
            settings['variants']['current'] == binding['candidate_source_tag'], 'Frozen policy/source roles differ')
    for label, build in load(bench, 'build-results.json').items():
        require(build['success'] is True and build['revision'] == settings['variants'][label] and
                build['executable_sha256'] == sha(bench['bin/' + label]) and len(build['stages']) == 2 and
                all(stage['exit_code'] == 0 for stage in build['stages']) and build['stages'] == load(bench, 'build/' + label + '.json'),
                'Build, source or ELF identity differs')
        for stage in build['stages']:
            require(all(value in stage['command'] for value in ['ReleaseFast', 'x86_64-linux-gnu', 'skylake+pku+sgx']),
                    'Compiler options differ')
    state = load(validation, 'state.json')
    native = load(validation, 'validation/latest-native.original-tool-result.json')
    require(native['exit_code'] == state['native_final']['exit_code'] == 0 and
            '29/29 tests passed' in native['output'] and 'deterministic_real_equal_length_different_wire_pairs=6' in native['output'] and
            state['native_final']['tests'] == 29 and state['native_final']['real_tie_pairs'] == 6,
            'Original Native29/6ties terminal differs')
    wasi = load(validation, 'validation/wasi.stdout')
    require(wasi['status'] == 'ok' and wasi['pointer_bits'] == 32 and len(wasi['results']) == 1 and
            load(validation, 'validation/wasi-exit.json')['exit_code'] == 0 and
            load(validation, 'validation/wasi-build-exit.json')['exit_code'] == 0, 'Actual WASI build/run terminal differs')
    result = wasi['results'][0]
    wasm = validation['validation/distance-incumbent.wasm']
    require(result['exit_code'] == 0 and result['wasm_sha256'] == sha(wasm) and result['wasm_bytes'] == len(wasm) and
            load(validation, 'validation/wasi-exit.json')['wasm_sha256'] == sha(wasm), 'Compiled WASM identity differs')
    output = validation['validation/wasi.stderr'].decode()
    require('All 29 tests passed.' in output and len(re.findall(r'^\d+/29 ', output, re.MULTILINE)) == 29 and
            'deterministic_real_equal_length_different_wire_pairs=6' in output and state['wasi_final']['real_tie_pairs'] == 6,
            'Actual WASI29/6ties output differs')
    failures = load(validation, 'failure-index.json')
    require(failures['no_synthetic_stdout_or_stderr'] is True and
            [row['chunk_id'] for row in failures['failures']] == ['e9d8cb', '9bda3c'] and
            all(row['recorded_exit_code'] == 1 and row['original_tool_result_bytes_available'] is False for row in failures['failures']) and
            'e9d8cb' in state['first_native_compilation'] and '9bda3c' in state['second_native'], 'Original failure indexes differ')
    require(validation['failure-sources/test-before-count-widen.zig'] and
            validation['failure-sources/module-before-reference/adaptive_distance_candidate.zig'] and
            validation['failure-sources/module-before-reference/adaptive_distance_candidate_unit_tests.zig'], 'Failure source backups missing')
    return {'baseline_compile_files': 2992, 'current_compile_files': 3120, 'src_files': {'baseline': 2200, 'current': 2204},
            'generated_current_pyc_files': 125, 'Native_actual_tests': 29, 'Native_real_tie_pairs': 6,
            'WASI_actual_tests': 29, 'WASI_real_tie_pairs': 6, 'compiled_wasm_identity_verified': True,
            'original_failure_chunk_indexes': ['e9d8cb', '9bda3c'], 'historical_failure_output_scope': 'Index-only; complete failed outputs not reconstructed',
            'scope': 'Frozen local source and recorded prerequisite validation; separate global-bound source excluded, no compilation/test/codec rerun'}
