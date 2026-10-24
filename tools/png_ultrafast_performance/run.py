#!/usr/bin/env python3
"""Full immutable 15-image/adaptive+Up paired core-change benchmark."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import statistics
import subprocess
import sys
from datetime import datetime, timezone

BASELINE = Path('/nav_env/Temp/imx-png-stream-real-baseline')
sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]

def sha(path):
    value = hashlib.sha256()
    with Path(path).open('rb') as source:
        for block in iter(lambda: source.read(1 << 20), b''): value.update(block)
    return value.hexdigest()

def run(command):
    result = subprocess.run([str(x) for x in command], capture_output=True, text=True)
    if result.returncode: raise RuntimeError(str(command) + '\n' + result.stdout + result.stderr)
    return json.loads(next(line for line in (result.stdout + result.stderr).splitlines() if line.startswith('{')))

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('phase', choices=['validate', 'bench'])
    parser.add_argument('--old', type=Path, required=True)
    parser.add_argument('--new', type=Path, required=True)
    parser.add_argument('--output-dir', type=Path, default=Path('/nav_env/Temp/vort-png-ultrafast-performance/full-real'))
    parser.add_argument('--cpu', type=int, default=13)
    parser.add_argument('--rounds', type=int, default=4)
    args = parser.parse_args()
    output = args.output_dir.resolve()
    if not output.is_relative_to(Path('/nav_env/Temp').resolve()): raise ValueError('artifacts must remain in Temp')
    output.mkdir(parents=True, exist_ok=True)
    validation = json.loads((BASELINE / 'validation.json').read_text())
    raw = json.loads((BASELINE / 'raw-manifest.json').read_text())
    if len(validation['cases']) != 30 or len(raw['entries']) != 15 or raw['raw_bytes'] != 90083998: raise ValueError('immutable full corpus changed')
    for entry in raw['entries']:
        if sha(entry['raw']) != entry['raw_sha256']: raise ValueError('raw fixture changed')
    rust = BASELINE / 'rust-target/release/rust-stream'
    binaries = {'old_core': args.old.resolve(), 'new_core': args.new.resolve(), 'rust_stream': rust}
    def command(case, implementation, mode, iterations=1, destination='-'):
        entry = case['entry']
        common = [entry['raw'], entry['width'], entry['height'], entry['color'], case['filter'], iterations, destination]
        if implementation == 'rust_stream': return [rust, mode, *common]
        return [binaries[implementation], mode, 'stream', *common]
    if args.phase == 'validate':
        from importlib.util import spec_from_file_location, module_from_spec
        spec = spec_from_file_location('immutable_baseline', BASELINE / 'tools/run.py')
        helper = module_from_spec(spec); spec.loader.exec_module(helper)
        cases = []
        for case in validation['cases']:
            entry = case['entry']; path = output / (entry['name'] + '.' + case['filter'] + '.png')
            run(command(case, 'new_core', 'dump', destination=path))
            observed = helper.inspect(path, entry)
            expected = case['implementations']['imx_stream']
            if observed['png_sha256'] != expected['png_sha256']: raise ValueError('baseline stream bytes changed: ' + case['fixture'])
            for decoder, label in [(helper.LIBPNG, 'libpng'), (helper.RUST_DECODE, 'image-png')]:
                pixels = output / ('decode.' + label); metadata = output / ('decode.' + label + '.json')
                argv = [decoder, path, pixels] if label == 'libpng' else [decoder, path, pixels, 'identity', metadata]
                subprocess.run([str(x) for x in argv], capture_output=True, check=True)
                if pixels.stat().st_size != entry['raw_bytes'] or sha(pixels) != entry['raw_sha256']: raise ValueError('independent decoder mismatch')
                pixels.unlink()
            cases.append({'fixture': case['fixture'], 'filter': case['filter'], 'byte_exact_baseline': True, 'both_decoders_exact': True, **observed})
            print('real_core_validate=' + case['fixture'] + '/' + case['filter'] + ' bytes+decoders=exact', flush=True)
        (output / 'validation.json').write_text(json.dumps(cases, indent=2) + '\n')
        return
    if args.rounds < 3 or args.rounds > 5 or args.cpu not in os.sched_getaffinity(0): raise ValueError('3-5 rounds on available CPU required')
    if len(json.loads((output / 'validation.json').read_text())) != 30: raise ValueError('validate the full corpus before timing')
    calibration = json.loads((BASELINE / 'calibration.json').read_text())
    samples = []
    for round_index in range(args.rounds):
        cases = list(enumerate(validation['cases']))
        if round_index % 2: cases.reverse()
        for index, case in cases:
            iterations = calibration[index]['iterations']
            order = ['old_core', 'new_core', 'rust_stream'] if round_index % 2 == 0 else ['rust_stream', 'new_core', 'old_core']
            for implementation in order:
                argv = ['taskset', '-c', args.cpu, *command(case, implementation, 'time', iterations)]
                started = datetime.now(timezone.utc).isoformat()
                value = run(argv)
                size = case['implementations']['rust_stream' if implementation == 'rust_stream' else 'imx_stream']['png_bytes']
                if value['input_bytes'] != case['entry']['raw_bytes'] or value['output_bytes_total'] != size * iterations: raise ValueError('timed corpus or output size changed')
                samples.append({**value, 'round': round_index, 'fixture': case['fixture'], 'filter': case['filter'], 'implementation': implementation,
                                'command': [str(x) for x in argv], 'started_utc': started})
            (output / 'samples.json').write_text(json.dumps(samples, indent=2) + '\n')
        print('real_core_round=' + str(round_index) + ' cases=30 complete', flush=True)
    rows = []
    for case in validation['cases']:
        times = {name: statistics.median(s['elapsed_ns'] / s['iterations'] for s in samples if s['fixture'] == case['fixture'] and s['filter'] == case['filter'] and s['implementation'] == name) for name in binaries}
        rows.append({'fixture': case['fixture'], 'filter': case['filter'], 'ns': times, 'speedup': times['old_core'] / times['new_core'], 'new_vs_rust': times['rust_stream'] / times['new_core'], 'old_vs_rust': times['rust_stream'] / times['old_core']})
    groups = {}
    for label in ['all', 'adaptive', 'up']:
        selected = [row for row in rows if label == 'all' or row['filter'] == label]
        totals = {name: sum(row['ns'][name] for row in selected) for name in binaries}
        groups[label] = {'cases': len(selected), 'geomean_speedup': math.exp(statistics.mean(math.log(row['speedup']) for row in selected)),
                         'aggregate_speedup': totals['old_core'] / totals['new_core'], 'geomean_new_vs_rust': math.exp(statistics.mean(math.log(row['new_vs_rust']) for row in selected)),
                         'geomean_old_vs_rust': math.exp(statistics.mean(math.log(row['old_vs_rust']) for row in selected)), 'total_ns': totals}
    report = {'schema': 'vort.png_incremental_ultrafast_full_real.v1', 'rounds': args.rounds, 'cpu': args.cpu, 'cases': 30, 'raw_bytes_once': 90083998,
              'sink': 'fresh owned encoded output; full PNG row encode/finish/destroy in timer; no input/decode/hash/file I/O in timer',
              'only_changed_component': 'Vort incremental ultrafast core; both imx binaries use the same immutable consumer source and benchmark harness',
              'binary_sha256': {name: sha(path) for name, path in binaries.items()}, 'raw_manifest_sha256': sha(BASELINE / 'raw-manifest.json'),
              'harness_sha256': sha(ROOT / 'tools/png_ultrafast_performance/imx_bench.zig'), 'groups': groups, 'rows': rows}
    (output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(groups, indent=2))

if __name__ == '__main__': main()
