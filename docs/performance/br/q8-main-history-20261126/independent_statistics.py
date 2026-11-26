#!/usr/bin/env python3
"""Independent q8 archived-data replay; no codec, ELF, git, or producer execution.

`reduce_statistics(pairs, sizes)` is a pure callable. Each pair has case, round,
order (old_exact/current) and ns (variant->elapsed integer); sizes maps cases
and variants to initial-wire byte lengths. Imports perform no I/O.
"""
import argparse
import csv
import datetime as dt
import hashlib
import itertools
import json
import math
import os
from pathlib import Path
from random import Random
from statistics import median
import tarfile

VARIANTS = ('old_exact', 'current')
REVISIONS = dict(zip(VARIANTS, ('0a673757ea6a1e88b90794ad44dce1a8a824f371', '8ccd54a59da850da724cc4d6ca79a727c659889e')))
LANE = 'explicit16'
WEAK = {'dickens', 'mozilla', 'nci'}
DRAWS = 20_000


def check(predicate, what):
    if not predicate:
        raise ValueError(str(what))


def same(x, y, what):
    check(type(x) is type(y) and x == y, (what, x, y))


def close(x, y, what):
    check(isinstance(x, (float, int)) and isinstance(y, (float, int)) and math.isclose(x, y, rel_tol=1e-12, abs_tol=1e-12), (what, x, y))


def avg(seq):
    seq = tuple(seq)
    return math.fsum(seq) / len(seq)


def gm(seq):
    return math.exp(avg(map(math.log, seq)))


def percentiles(log_draws):
    ordered = sorted(log_draws)
    return [math.exp(ordered[int((len(ordered) - 1) * q)]) for q in (.025, .975)]


def reduce_statistics(pairs, sizes):
    """Replay all primary and weak rounds; retain every raw observation."""
    by_case = {k: {} for k in sorted(sizes)}
    check(len(by_case) == 12 and WEAK <= set(by_case), 'fixed corpus geometry')
    for p in pairs:
        r = p['round']
        check(r not in by_case[p['case']], ('duplicate pair', p))
        same(tuple(p['order']), VARIANTS if r % 2 == 0 else VARIANTS[::-1], ('AB/BA', p))
        check(set(p['ns']) == set(VARIANTS) and all(type(n) is int and n > 0 for n in p['ns'].values()), ('pair times', p))
        by_case[p['case']][r] = p
    rows = {}
    matrix_log_blocks = [math.fsum(math.log(by_case[c][r]['ns']['current'] / by_case[c][r]['ns']['old_exact']) for c in by_case) for r in range(6)]
    for c, grouped in by_case.items():
        rounds = 12 if c in WEAK else 6
        same(set(grouped), set(range(rounds)), ('case round coverage', c))
        ps = [grouped[r] for r in range(rounds)]
        ratios = [p['ns']['current'] / p['ns']['old_exact'] for p in ps]
        strata = [tuple(math.log(x) for x in ratios[s::2]) for s in (0, 1)]
        rand = Random(c + LANE)
        ci = percentiles(avg(itertools.chain.from_iterable((rand.choice(group) for _ in group) for group in strata)) for _ in range(DRAWS))
        old, current = [median(p['ns'][v] for p in ps) for v in VARIANTS]
        rows[c] = {'pairs': rounds, 'old_first_pairs': rounds//2, 'current_first_pairs': rounds//2,
                   'old_per_call_median_ns': old, 'current_per_call_median_ns': current,
                   'ratio_of_median_ns_current_over_old': current/old,
                   'encoded_bytes_current_over_old': sizes[c]['current']/sizes[c]['old_exact'],
                   'paired_geomean_ns_current_over_old': gm(ratios),
                   'paired_ratio_bootstrap_95pct_ci': ci,
                   'primary_six_round_paired_geomean': gm(ratios[:6]),
                   'raw_pairs': [{'round': p['round'], 'order': list(p['order']), 'old_ns': p['ns']['old_exact'], 'current_ns': p['ns']['current'], 'current_over_old_ns_ratio': ratio} for p, ratio in zip(ps, ratios)]}
    rand = Random('matrix-' + LANE)
    strata = (tuple(matrix_log_blocks[::2]), tuple(matrix_log_blocks[1::2]))
    ci = percentiles(avg(itertools.chain.from_iterable((rand.choice(group) for _ in group) for group in strata)) / len(rows) for _ in range(DRAWS))
    return rows, {'lane': LANE, 'rows': len(rows), 'primary_rounds': 6,
                  'geomean_encoded_bytes_current_over_old': gm(row['encoded_bytes_current_over_old'] for row in rows.values()),
                  'paired_geomean_ns_current_over_old': math.exp(avg(matrix_log_blocks)/len(rows)),
                  'paired_round_block_bootstrap_95pct_ci': ci}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_hash(path):
    h = hashlib.sha256()
    with path.open('rb') as file:
        for block in iter(lambda: file.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def utc(text):
    return dt.datetime.fromisoformat(text).timestamp()


def tree_compare(observed, expected, at='summary'):
    if type(expected) is dict:
        same(set(observed), set(expected), at)
        for k, v in expected.items():
            tree_compare(observed[k], v, f'{at}.{k}')
    elif type(expected) is list:
        same(len(observed), len(expected), at)
        for i, v in enumerate(expected):
            tree_compare(observed[i], v, f'{at}[{i}]')
    elif type(expected) is float:
        close(observed, expected, at)
    else:
        same(observed, expected, at)


def verify_epoch(base, prior_override=None):
    """Read existing bytes only; absolute archived commands are checked literally."""
    load = lambda name: json.loads((base / name).read_bytes())
    origin = load('sampling-command.json')['cwd']
    absolute = lambda name: f'{origin}/{name}'
    root = load('ROOT-HEAVY0.json')
    release = load('heavy-release.json')
    preflight = load('preflight-binding.json')
    settings = load('settings.json')
    source = load('input-source-binding.json')
    host = load(root['host'])
    builds = load('build-results.json')
    sampler = load('sampling-command.json')
    stopped = load('sampling-exit.json')
    reducer = load('analysis-exit.json')
    manifest = load('run-manifest.json')
    summary = load('summary.json')
    ff = load('preflight-summary.json')
    pre_wires = {(r['case'], r['variant']): r for r in ff['rows']}
    fixtures = {row['case']: row for row in load('fixtures.json')}
    identities = set(itertools.product(fixtures, VARIANTS))
    before_checks = {(r['case'], r['variant']): r for r in root['full_byte_checks']}
    same(set(pre_wires), identities, 'complete 24 initial wires')
    same(set(before_checks), identities, 'complete Root full-byte binding')
    same(len(ff['rows']), 24, 'initial row count')
    same(len(root['full_byte_checks']), 24, 'Root row count')
    same(ff['lanes'], [LANE], 'actual lane')
    same(len(fixtures), 12, 'fixtures')
    same(root['HEAVY'], 0, 'global gate observation')
    same(root['timing_authorized'], True, 'global authorization')
    same(release['HEAVY'], 0, 'construction wave last receipt')
    same(release['timing_authorized'], False, 'construction wave did not authorize timing')
    same(utc(root['utc']), utc(host['utc']), 'Root snapshot ties')
    same((host['benchmark_cpu'], host['SMT_siblings'], host['other_relevant_processes']), (2, '2,10', []), 'Root CPU and scope')
    check(utc(release['last_heavy_stop']) < utc(root['utc']), 'build/preflight ends before release')
    same(root['settings_sha256'], file_hash(base/'settings.json'), 'settings before/after')
    same(root['preflight_binding_sha256'], file_hash(base/'preflight-binding.json'), 'preflight before/after')
    same(release['preflight_binding_sha256'], root['preflight_binding_sha256'], 'preflight gate agreement')
    same(preflight['source_binding_sha256'], file_hash(base/'input-source-binding.json'), 'source metadata before/after')
    same(preflight['settings'], settings, 'preflight settings')
    same(preflight['measured_samples'], 0, 'preflight no timing')
    same(settings['variants'], REVISIONS, 'source pins')
    same(settings['primary_options'], {'quality': 8, 'mode': 'generic', 'window_bits': 16}, 'requested public options')
    same((settings['target'], settings['cpu'], settings['sampling_cpu'], settings['codec_threads'], settings['rounds'], settings['weak_rows_additional_rounds'], settings['initial_iterations']), ('x86_64-linux-gnu', 'skylake+pku+sgx', 2, 1, 6, 6, 1), 'fixed measurement policy')
    same(sampler['argv'], ['env', '-u', 'LD_LIBRARY_PATH', 'PYTHONDONTWRITEBYTECODE=1', '/usr/bin/python3', absolute('run.py')], 'sampler argv')
    same(stopped, {**sampler, 'completed_utc': stopped['completed_utc'], 'exit_code': 0}, 'actual sampler exit metadata')
    same((sampler['root_release'], sampler['sampling_plan_pairs'], sampler['timed_calls']), ('ROOT-HEAVY0.json', 90, 180), 'sampler full matrix')
    same(reducer['argv'], ['/usr/bin/python3', absolute('analyze.py')], 'original reducer argv without executing it')
    same((reducer['cwd'], reducer['exit_code']), (origin, 0), 'original reducer terminal exit')
    start, end = [utc(stopped[key]) for key in ('started_utc', 'completed_utc')]
    check(utc(root['utc']) < start < end <= utc(reducer['started_utc']) <= utc(reducer['completed_utc']), 'release/sampling/analysis chronology')
    same(manifest['settings'], settings, 'manifest settings')
    same(summary['source_revisions'], settings['variants'], 'summary sources')
    same((summary['host_scope'], summary['timer_scope']), (settings['host_scope'], settings['timing_scope']), 'inherited scope, not rewritten')
    same((summary['total_pairs'], summary['total_timed_calls']), (90, 180), 'summary totals')
    check(start <= manifest['started']['unix_time'] <= manifest['completed']['unix_time'] <= end, 'manifest interval in actual sampler interval')

    # Explicit first-stage/source-file and independently emitted ELF identities.
    for var, rev in REVISIONS.items():
        bind = source['isolated_source'][var]
        record = preflight['probes'][var]
        mf_name = f'{var}-src-manifest.json'
        archive_name = f'source/{var}-src.tar'
        same((bind['archive_path'], bind['source_manifest_path'], bind['extraction']), (absolute(archive_name), absolute(mf_name), absolute(f'sources/{var}')), ('isolated source paths', var))
        same(bind['command'], ['git', 'archive', '--format=tar', rev, 'src'], ('immutable archive argv', var))
        same(file_hash(base/mf_name), bind['source_manifest_sha256'], ('source manifest digest', var))
        same((file_hash(base/archive_name), (base/archive_name).stat().st_size), (bind['archive_sha256'], bind['archive_bytes']), ('original source archive', var))
        source_files = load(mf_name)
        same((source_files['revision'], source_files['src_tree'], len(source_files['files'])), (rev, bind['src_tree'], bind['files']), ('source registry', var))
        sr = base / 'sources' / var
        same(set(source_files['files']), {str(f.relative_to(sr)) for f in (sr/'src').rglob('*') if f.is_file()}, ('source set after sampling', var))
        for name, row in source_files['files'].items():
            data = (sr/name).read_bytes()
            git_blob = hashlib.sha1(f'blob {len(data)}\0'.encode() + data).hexdigest()
            same((len(data), digest(data), git_blob), (row['bytes'], row['sha256'], row['git_blob_sha1']), ('source bytes after sampling', var, name))
        exe = base / 'bin' / var
        obj = base / 'build' / f'{var}-record.o'
        check(exe.read_bytes()[:4] == b'\x7fELF' and os.access(exe, os.X_OK), ('executable ELF', var))
        same((builds[var]['revision'], builds[var]['success'], builds[var]['executable_sha256']), (rev, True, file_hash(exe)), ('build outcome', var))
        same((record['revision'], record['src_tree'], record['source_manifest_sha256'], record['executable_sha256'], record['record_object_sha256'], record['record_object_bytes']), (rev, bind['src_tree'], bind['source_manifest_sha256'], file_hash(exe), file_hash(obj), obj.stat().st_size), ('preflight/post source ELF object binding', var))
        target = ['-O', 'ReleaseFast', '-target', settings['target'], '-mcpu', settings['cpu']]
        prefix = ['taskset', '-c', str(VARIANTS.index(var)), 'zig']
        o = absolute(f'build/{var}-record.o'); codec = absolute(f'sources/{var}/src')
        expected = [prefix+['build-obj']+target+[f'{codec}/br/encoder/record_optimal_object.zig',f'-femit-bin={o}'], prefix+['build-exe',o,'-lc']+target+['--dep','vort_br','--dep','provenance','-Mroot='+absolute('probe.zig')]+target+[f'-Mvort_br={codec}/br.zig']+target+['-Mprovenance='+absolute('provenance.zig'),'-femit-bin='+absolute(f'bin/{var}')]]
        stages = builds[var]['stages']
        same(stages, load(f'build/{var}.json'), ('build sidecar ledger', var))
        same([st['command'] for st in stages], expected, ('complete build argv', var))
        check(all(st['exit_code']==0 and st['elapsed_seconds']>0 and 'reused_completed_object' not in st and st['started_unix']+st['elapsed_seconds'] < start for st in stages), ('build chronology', var))
    for k, v in source['scripts'].items():
        same(file_hash(base/k), v, ('shared harness identity', k))
        same((base/k).read_bytes(), (base/'archive/scripts'/k).read_bytes(), ('harness exact prior bytes', k))

    before_decoder_name = root['prior_decoder_binding']
    same(before_decoder_name, 'pre-sampling-decoder-binding.json', 'preserved pre-sampling decoder file')
    before_decoder, after_decoder = load(before_decoder_name), load('decoder-binding.json')
    for d in (before_decoder, after_decoder):
        same((d['version'], d['version_number']), ('1.2.0', 0x1002000), 'pinned decoder version')
        same({Path(f['path']).name:f['sha256'] for f in d['files']}, source['references'], 'decoder/common identities')
        for f in d['files']:
            name=Path(f['path']).name; file=base/'references'/name
            same((f['path'], f['sha256'], f['bytes']), (absolute(f'references/{name}'), file_hash(file), file.stat().st_size), ('loaded and retained reference file', name))
        same({line.split()[-1] for line in d['mapped_libraries']}, {f['path'] for f in d['files']}, 'exact mapped Brotli paths')
    same({k:v for k,v in before_decoder.items() if k!='mapped_libraries'}, {k:v for k,v in after_decoder.items() if k!='mapped_libraries'}, 'decoder identity fields stable across runner rebind')
    same([(line.split()[1], line.split()[2], line.split()[-1]) for line in before_decoder['mapped_libraries']], [(line.split()[1], line.split()[2], line.split()[-1]) for line in after_decoder['mapped_libraries']], 'mapped DSO perms, offsets and paths; not ASLR addresses')

    def process(rel, var, c, iterations, exit_time):
        exp = pre_wires[c,var]
        f = fixtures[c]
        value, side = load(rel+'.json'), load(rel+'.command.json')
        expected_argv = ['taskset','-c','2',absolute(f'bin/{var}'),'--input',f['path'],'--output',absolute(rel+'.json'),'--source-revision',REVISIONS[var],'--iterations',str(iterations),'--window','16']
        if not iterations:
            expected_argv += ['--wire-output',absolute(rel+'.br')]
        same(side['command'], expected_argv, ('process argv', rel))
        same(side['exit_code'], 0, ('process actual exit', rel))
        finish = side['started_unix']+side['elapsed_seconds']
        check(0 < side['elapsed_seconds'] and finish <= exit_time, ('process interval', rel))
        for s in ('stdout','stderr'):
            same((base/f'{rel}.{s}').read_bytes(), b'', ('untouched process '+s, rel))
        same((value['schema'], value['source_revision'], value['allocator'], value['quality'], value['mode'], value['requested_window_bits'], value['warmup_owned_encode_free_calls'], value['iterations']), ('vort.q8-source-history-ab.process.v1', REVISIONS[var], 'std.process.Init.gpa', 8, 'generic', 16, 1, iterations), ('process options', rel))
        same((value['input_path'], value['input_bytes'], value['input_sha256']), (f['path'], f['bytes'], f['sha256']), ('process full input', rel))
        same((value['warm_wire_bytes'], value['warm_wire_sha256']), (exp['wire_bytes'], exp['wire_sha256']), ('process initial wire', rel))
        same(value['timing_scope'], 'Continuous owned allocating public encode, wire-length mix and free. SHA256 and cross-library decode validate only the initial complete wire, outside timing.', ('process timer', rel))
        same(value['wire_identity_scope'], 'initial_wire_only; timed outputs check lengths/mix, not complete SHA256', ('process comparison scope', rel))
        same(value['provenance'], {'provenance_version':1, 'optimize':'ReleaseFast','zig_version':'0.16.0','target_arch':'x86_64','target_os':'linux','target_abi':'gnu','target_cpu':'skylake+pku+sgx','cpu_model':host['model'],'cpu_affinity':'2','affinity_cpu_count':1,'benchmark_threads':1,'codec_thread_policy':'single','executable_sha256':preflight['probes'][var]['executable_sha256'],'command':' '.join(expected_argv[3:])}, ('process executable and CPU identity', rel))
        same(len(value['samples']), iterations, ('process sample count', rel))
        for timing in value['samples']:
            same(timing, {'index':0,'owned_encode_free_ns':timing['owned_encode_free_ns'],'wire_bytes':exp['wire_bytes'],'mix':exp['wire_bytes']}, ('timed length/mix', rel))
            check(type(timing['owned_encode_free_ns']) is int and 0 < timing['owned_encode_free_ns'] <= side['elapsed_seconds']*1e9, ('positive, scoped sampled ns', rel))
        return side['started_unix'], finish, value['samples']

    prev_path = Path(prior_override or source['archive_path'])
    same(file_hash(prev_path), source['archive_sha256'], 'exact previous raw archive')
    file_map: dict[str,list[str]] = {'preflight': [], 'runs': []}
    sizes = {c: {} for c in fixtures}
    with tarfile.open(prev_path, 'r:gz') as prior:
        for c, f in fixtures.items():
            input_rel=f'fixtures/{c}.65536.plain'; b=(base/input_rel).read_bytes()
            same((f['path'], f['bytes'], f['sha256']), (absolute(input_rel), 65536, digest(b)), ('fixture bytes', c))
            same(b==prior.extractfile(input_rel).read(), True, ('original full fixture equals new fixture', c))
            for var in VARIANTS:
                rel=f'preflight/{LANE}-{c}-{var}'; rec=pre_wires[c,var]; old=(base/(rel+'.br')).read_bytes()
                same((rec['lane'],rec['input_bytes'],rec['input_sha256'],rec['wire_bytes'],rec['wire_sha256'],rec['actual_window_bits'],rec['pinned_decode_verified']), (LANE,65536,f['sha256'],len(old),digest(old),16,True), ('archived cross-decode assertion and wire metadata', rel))
                same(old[0] & 1, 0, ('actual window16 header bit', rel))
                same(old==prior.extractfile(rel+'.br').read(), True, ('full-byte previous-epoch golden', rel))
                chk=before_checks[c,var]
                same((chk['full_byte_equal_to_prior'],chk['sha256']), (True,digest(old)), ('Root full-byte result stable', rel))
                same(preflight['cases'][c][var], {**rec,'matches_prior_epoch_same_label_wire':True,'executable_sha256':preflight['probes'][var]['executable_sha256']}, ('preflight frozen row', rel))
                process(rel,var,c,0,utc(root['utc']))
                file_map['preflight'] += [f'{rel}.{e}' for e in ('br','json','stdout','stderr','command.json')]
                sizes[c][var] = len(old)

    schedule=[(r,c) for r in range(12) for c in fixtures if r<6 or c in WEAK]
    same([(p['round'],p['case']) for p in manifest['pairs']], schedule, 'all 90 pairs, chronological planned row/round order')
    normalized=[]; end_of_last=manifest['started']['unix_time']; host_rows=[manifest['started']]
    for pair in manifest['pairs']:
        c, r = pair['case'], pair['round']; expect_order=VARIANTS if r%2==0 else VARIANTS[::-1]
        same((pair['lane'],pair['order']), (LANE,list(expect_order)), ('complete balanced order', r,c))
        same(set(pair['processes']), set(VARIANTS), ('both processes present', r,c))
        host_point=pair['host_before']; host_rows.append(host_point)
        check(end_of_last <= host_point['unix_time'] <= end, ('pair begins after previous process', r,c))
        end_of_last=host_point['unix_time']; ns={}
        for v in expect_order:
            rel=f'runs/{LANE}-{r:02d}-{c}-{v}'
            started, finished, sample = process(rel,v,c,1,end)
            check(end_of_last <= started <= finished <= manifest['completed']['unix_time'], ('AB/BA process chronology', r,c,v))
            end_of_last=finished; ns[v]=sample[0]['owned_encode_free_ns']
            same(pair['processes'][v], {'path':absolute(rel+'.json'),'raw_ns':[ns[v]]}, ('raw ns and manifest binding', c,r,v))
            file_map['runs'] += [f'{rel}.{e}' for e in ('json','stdout','stderr','command.json')]
        normalized.append({'case':c,'round':r,'order':pair['order'],'ns':ns})
    host_rows.append(manifest['completed'])
    for folder, names in file_map.items():
        same({str(p.relative_to(base)) for p in (base/folder).iterdir()}, set(names), ('no missing/extra retained raw sidecars',folder))
        same(len(set(names)), len(names), ('no duplicate raw path',folder))

    replay, matrix = reduce_statistics(normalized, sizes)
    tree_compare(summary['matrix'], [matrix], 'fixed matrix GM, sizes and seeded 20k CI')
    same([r['case'] for r in summary['rows']], sorted(fixtures), 'summary row identity and order')
    for row in summary['rows']:
        c=row['case']; x=replay[c]; f=fixtures[c]; before=pre_wires[c,'old_exact']; after=pre_wires[c,'current']
        tree_compare(row,{**x, 'case':c,'lane':LANE,'input_bytes':f['bytes'],'input_sha256':f['sha256'],
                         'old_encoded_bytes':before['wire_bytes'],'current_encoded_bytes':after['wire_bytes'],
                         'old_wire_sha256':before['wire_sha256'],'current_wire_sha256':after['wire_sha256'],
                         'old_actual_window_bits':16,'current_actual_window_bits':16}, ('per-row exact and derived summary', c))
    with (base/'raw-pairs.csv').open(newline='') as file:
        raw_reader=csv.reader(file); header=next(raw_reader)
        same(header,['lane','case','round','order','old_ns','current_ns','current_over_old_ns_ratio'],'raw CSV columns')
        csv_rows=list(raw_reader)
    csv_expected=[(c,p) for c in replay for p in replay[c]['raw_pairs']]
    same(len(csv_rows), len(csv_expected), 'all raw CSV rows')
    for r,(case,pair) in zip(csv_rows,csv_expected):
        same(r[:6],[LANE,case,str(pair['round']),'/'.join(pair['order']),str(pair['old_ns']),str(pair['current_ns'])],('raw CSV exact ns',case,pair['round']))
        same(float(r[6]),pair['current_over_old_ns_ratio'],('raw CSV ratio',case,pair['round']))
    for log in ('sampling.stderr','analysis.stderr'):
        same((base/log).read_bytes(), b'', ('terminal stderr',log))
    same((base/'sampling.stdout').read_text().splitlines()[-1], 'Campaign complete 90 pairs', 'terminal producer line')
    same(sum(line.startswith('pair ') for line in (base/'sampling.stdout').read_text().splitlines()),90,'all live reported pairs')

    host_scope={'root_release_utc':root['utc'],'root_HEAVY_at_release':root['HEAVY'],'root_relevant_processes_at_release':host['other_relevant_processes'],'benchmark_cpu':host['benchmark_cpu'],'smt_siblings':host['SMT_siblings'],'host':host['model'],'kernel':host['kernel'],'governor':host['governor'],
                'actual_started_utc':stopped['started_utc'],'actual_completed_utc':stopped['completed_utc'],'actual_span_seconds':end-start,'runner_snapshot_count':len(host_rows),
                'runner_snapshots_with_collector_matches':sum(bool(v['collector_processes']) for v in host_rows), 'runner_load1_range':[min(float(v['loadavg'].split()[0]) for v in host_rows),max(float(v['loadavg'].split()[0]) for v in host_rows)],
                'inherited_summary_host_scope_unmodified':summary['host_scope'],'inherited_summary_statistics_scope_unmodified':summary['statistics_scope'],
                'interpretation':'Root authorized after the recorded HEAVY=0 boundary and the exact old/main campaign completed on temporarily reserved development-host CPU2. Snapshots and filtered process observations do not establish continuous absence of interference. Fixed-scope historical source measurements, not industry leadership, dedicated-host acceptance or a controlled attribution to an intervening commit.'}
    heads=['ROOT-HEAVY0.json','root-host-before.json','heavy-release.json','heavy-events.log','build-results.json','input-source-binding.json','settings.json','fixtures.json','preflight-binding.json','preflight-summary.json',before_decoder_name,'decoder-binding.json','sampling-command.json','sampling-exit.json','sampling.stdout','sampling.stderr','run-manifest.json','analysis-exit.json','analysis.stdout','analysis.stderr','summary.json','raw-pairs.csv']
    files=sorted(heads+file_map['preflight']+file_map['runs'])
    return {'schema':'vort.q8-main-history-independent-replay.v1','status':'pass','HEAVY':0,'verification_scope':'Existing plain data/hashed source, wire, reference and ELF bytes only; no runtime library invocation, producer import/eval, compiler, or timing. Decode validity reuses the original before-timing assertion, not a rerun.',
            'preflight_complete_initial_wires':24,'verified_full_byte_prior_epoch_wire_matches':24,'retained_all_pairs_no_trimming':len(normalized),'retained_all_timed_calls':2*len(normalized),'all_12_primary_rows_slower':all(r['primary_six_round_paired_geomean']>1 for r in replay.values()),'all_positive_pairs_current_slower':sum(p['ns']['current']>p['ns']['old_exact'] for p in normalized),
            'source_elf_object_provenance_preflight_and_sampling':preflight['probes'],'prior_reference_sha256':source['references'],'decoder_pre_and_runner_bindings_retained':True,'decoder_maps_aslr_addresses_differ':before_decoder['mapped_libraries']!=after_decoder['mapped_libraries'],
            'matrix':matrix,'row_stats':{k:{f:v for f,v in row.items() if f!='raw_pairs'} for k,row in replay.items()},
            'bootstrap':{'draws':DRAWS,'matrix_seed':'matrix-'+LANE,'case_seed':'case+'+LANE,'matrix_scope':'AB/BA-order strata, three resampled full corpus blocks per order, only the primary six; case CI uses all row pairs within order; no trimmed/outlier samples'},
            'host_annotation':host_scope,'raw_and_relevant_receipt_sha256':{n:file_hash(base/n) for n in files}}


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('epoch',type=Path)
    ap.add_argument('--prior-archive',type=Path,help='Alternative path to the same hash-bound earlier raw.tar.gz')
    ap.add_argument('--receipt',type=Path,help='Write to a new file only')
    ap.add_argument('--host-annotation',type=Path,help='Write separate host annotation to a new file only')
    args=ap.parse_args()
    result=verify_epoch(args.epoch.resolve(),args.prior_archive)
    if args.receipt:
        with args.receipt.open('x') as f: json.dump(result,f,indent=2,sort_keys=True); f.write('\n')
    if args.host_annotation:
        with args.host_annotation.open('x') as f: json.dump(result['host_annotation'],f,indent=2,sort_keys=True); f.write('\n')
    print(json.dumps({k:result[k] for k in ('status','matrix','preflight_complete_initial_wires','retained_all_pairs_no_trimming','retained_all_timed_calls','all_12_primary_rows_slower','all_positive_pairs_current_slower','host_annotation')},indent=2))


if __name__ == '__main__':
    main()
