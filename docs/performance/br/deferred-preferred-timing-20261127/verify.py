#!/usr/bin/env python3
"""Stream and replay completed q8 evidence only. Never load an ELF or codec."""
import argparse
from datetime import datetime
import hashlib
import json
import math
from pathlib import Path, PurePosixPath
from random import Random
import re
import tarfile

PHASES = {'primary': ['baseline', 'candidate'], 'history': ['historical0a', 'candidate'], 'reference': ['reference', 'candidate']}
RAW_FIELDS = ('output', 'wire', 'stdout', 'stderr')
TIMER = 'Continuous owned allocating public encode, wire-length mix and free. SHA256 and cross-library decode validate only the initial complete wire, outside timing.'
WIRE_SCOPE = 'initial_wire_only; timed outputs check lengths/mix, not complete SHA256'
ANCHORS = {'candidate': 'dd21162bfc7912cbc932781c9ccafd6ea7e2017b5d62037e11cdd7645b629eaf', 'baseline': '1636c421524e522632fe051876ee42d1a19223c59d1f030102aff0252e4d51ef', 'historical0a': 'd4267c354cc90b139c4239f4ae1091e91b2e7ac4ffd3e09432ae0e2317309103'}


def check(condition, message):
    if not condition:
        raise ValueError(message)


def sha_stream(file):
    h = hashlib.sha256()
    for data in iter(lambda: file.read(1024 * 1024), b''):
        h.update(data)
    return h.hexdigest()


def sha_file(path):
    with path.open('rb') as f:
        return sha_stream(f)


def avg(values):
    a = list(values)
    return math.fsum(a)/len(a)


def gm(values):
    return math.exp(avg(map(math.log, values)))


def moment(x):
    return datetime.fromisoformat(x)


def near(a, b):
    return math.isclose(a, b, rel_tol=1e-13, abs_tol=1e-13)


def inventory(root):
    wanted = {'README.md', 'verify.py', 'capture.json', 'originals.tar.gz', 'source-closure.tar.gz'}
    if (root/'verification-receipt.json').is_file():
        wanted.add('verification-receipt.json')
    check({p.name for p in root.iterdir()} == wanted | {'SHA256SUMS'} and all(p.is_file() and not p.is_symlink() for p in root.iterdir()), 'Missing/extra package file')
    identities = dict(s.split('  ',1)[::-1] for s in (root/'SHA256SUMS').read_text().splitlines())
    check(set(identities) == wanted, 'Checksum inventory differs')
    for f, s in identities.items():
        check(sha_file(root/f) == s, 'SHA-256 mismatch: '+f)


def stream_tar(root, meta, members, values=None):
    path = root/meta['name']; seen = set()
    check(sha_file(path) == meta['sha256'] and path.stat().st_size == meta['bytes'] and len(members) == meta['members'], 'Archive identity differs: '+path.name)
    with tarfile.open(path,'r|gz') as tar:
        for member in tar:
            name = member.name
            check(member.isreg() and not PurePosixPath(name).is_absolute() and '..' not in PurePosixPath(name).parts and name in members and name not in seen, 'Unexpected raw/archive member: '+name)
            seen.add(name); data = tar.extractfile(member)
            if values is not None and (name.endswith(('.json','.py','.zig','.log','.stdout','.stderr')) or name.endswith('CMakeCache.txt')):
                blob = data.read(); values[name] = blob; h = hashlib.sha256(blob).hexdigest()
            else:
                h = sha_stream(data)
            expected = members[name]
            check(h == expected['sha256'] and ('bytes' not in expected or member.size == expected['bytes']), 'Original tar member identity differs: '+name)
    check(seen == set(members), 'Incomplete archive inventory')


class Data:
    def __init__(self, root):
        self.capture = json.loads((root/'capture.json').read_bytes()); self.origin = self.capture['epoch_original']
        self.index = self.capture['original_path_to_archive_member']; self.blobs = {}
        check(len({x['member'] for x in self.index.values()}) == len(self.index), 'Duplicate mapped original member')
        stream_tar(root, self.capture['originals'], {x['member']:x for x in self.index.values()}, self.blobs)
        members = set()
        for name, info in self.capture['source_registries'].items():
            path = info['original_manifest']; check(self.sha(path) == info['sha256'] == ANCHORS[name], 'Frozen source registry identity differs')
            reg = self.read_abs(path); reg = reg['files'] if 'files' in reg else reg
            check(len(reg) == info['files'], 'Frozen source registry count differs')
            if name == 'candidate':
                check('tools/br/deferred_preferred_wasm_gate.js' in reg and len(reg)==2257, 'Candidate runner JS/source closure missing')
            members.update(r['sha256'] if isinstance(r,dict) else r for r in reg.values())
        check(set(self.capture['source_registries']) == set(ANCHORS), 'Frozen registry set differs')
        stream_tar(root, self.capture['source_contents'], {h:{'sha256':h} for h in members})

    def path(self, rel): return self.origin + '/' + rel
    def sha(self, path): return self.index[path]['sha256']
    def size(self, path): return self.index[path]['bytes']
    def bytes(self, path): return self.blobs[self.index[path]['member']]
    def read_abs(self, path): return json.loads(self.bytes(path))
    def read(self, rel): return self.read_abs(self.path(rel))


def ref_identity(v, pins, warm=False):
    names = {x['path']:x for x in pins['libraries'].values()}
    if warm:
        lib_keys = ('libraries','proc_self_maps','actual_version','encoder_version','decoder_version','library_file_sha256_verified_before_decode','loaded_three_library_closure_verified_before_decode')
    else:
        lib_keys = ('reference_libraries','reference_proc_self_maps','reference_actual_version','reference_encoder_version','reference_decoder_version','reference_library_sha256_verified_before_warmup','reference_brotli_closure_verified_before_warmup')
    libs,maps,version,enc,dec,sha_ok,maps_ok = (v[k] for k in lib_keys)
    check((version,enc,dec,sha_ok,maps_ok)==('1.2.0',0x1002000,0x1002000,True,True) and {x['path']:x for x in libs}==names, 'Reference per-child version or three-library bytes differ')
    check({line.split()[-1] for line in maps.splitlines() if 'libbrotli' in line} == set(names), 'Reference loaded Brotli closure differs')


def child(d, phase, row, variant, a, n, bin, pins):
    check(a['actual_exit_code']==0 and a['launch_state']=='exited' and a['recorded_before_launch'] and not a.get('launch_exception'), 'Nonterminal/failed original child')
    for k in RAW_FIELDS:
        check(d.sha(a[k])==a[k+'_sha256'], 'Original child artifact hash differs: '+k)
    cmd = ['taskset','-c','2',bin['ELF'],'--input',row['input']['path'],'--output',a['output'],'--wire-output',a['wire'],'--source-revision',bin['revision'],'--iterations',str(n),'--window','16']
    if variant == 'reference':
        for flag,name in (('encoder','libbrotlienc.so.1.2.0'),('decoder','libbrotlidec.so.1.2.0'),('common','libbrotlicommon.so.1.2.0')):
            cmd += ['--libbrotli-'+flag,pins['libraries'][name]['path']]
    check(a['argv']==cmd, 'Original child argv switched inputs/options')
    v=d.read_abs(a['output']); pr=v['provenance']; inp=row['input']
    check((v['source_revision'],v['input_path'],v['input_sha256'],v['input_bytes'],v['allocator'],v['quality'],v['mode'],v['requested_window_bits'],v['warmup_owned_encode_free_calls'],v['iterations'],v['timing_scope'],v['wire_identity_scope']) == (bin['revision'],inp['path'],inp['sha256'],inp['bytes'],'std.process.Init.gpa',8,'generic',16,1,n,TIMER,WIRE_SCOPE), 'Source/input/public owning API contract differs')
    check((pr['optimize'],pr['target_arch'],pr['target_abi'],pr['target_os'],pr['target_cpu'],pr['cpu_affinity'],pr['benchmark_threads'],pr['codec_thread_policy'],pr['executable_sha256'],pr['command']) == ('ReleaseFast','x86_64','gnu','linux','skylake+pku+sgx','2',1,'single',bin['sha256'],' '.join(cmd[3:])), 'Original actual target/CPU/ELF/argv metadata differs')
    check((v['warm_wire_bytes'],v['warm_wire_sha256'])==(d.size(a['wire']),d.sha(a['wire'])), 'Actual warm wire differs from process report')
    samples=v['samples']; check(len(samples)==n, 'Expected every raw call')
    ns=[]
    for i,s in enumerate(samples):
        size=v['warm_wire_bytes']; t=s['owned_encode_free_ns']; check(type(t) is int and t>0 and (s['index'],s['wire_bytes'],s['mix'])==(i,size,(i+1)*size),'Original timed length/mix/sample differs'); ns.append(t)
    if variant=='reference': ref_identity(v,pins)
    return ns, v


def audit_phase(d, phase, variants, bins, pins):
    load=lambda n:d.read(phase+'/'+n)
    protocol,m,pf,release,summary,stats=(load(n) for n in ('protocol.json','run-manifest.json','preflight.json','release.json','summary.json','statistics-receipt.json'))
    order=protocol['row_order']; rows={r['key']:r for r in protocol['rows']}; plan=[(r,c) for r in range(6) for c in order]
    check(protocol['variants']==variants and len(order)==len(rows)==12 and list(rows)==order and protocol['rounds']==6 and protocol['pairs']==72 and protocol['processes']==144 and not protocol['weak_extra_rows'] and protocol['all_raw_calls_retained'] and not protocol['minimum_selection'] and not protocol['retry_filter_drop_allowed'], 'Fixed six-round preregistration differs')
    check([(j['round'],j['key'],j['row']) for j in protocol['jobs']]==[(r,c,rows[c]) for r,c in plan], 'Declared exact jobs differ')
    check(m['completed'] and m['terminal'] and not m['original_old_samples_used'] and not m.get('failure') and len(m['attempts'])==144 and [(p['round'],p['key']) for p in m['pairs']]==plan, 'Incomplete/retried/foreign timing phase')
    check(m['release']==release and m['release_sha256']==d.sha(d.path(phase+'/release.json')) and m['protocol_sha256']==d.sha(d.path(phase+'/protocol.json')) and release['protocol_sha256']==m['protocol_sha256'] and release['preflight_sha256']==d.sha(d.path(phase+'/preflight.json')) and release['issued_by']=='/root' and release['released'] and release['timing_released'] and release['global_heavy_terminal'], 'Actual protocol/release/preflight not bound')
    for key, f in (('sampler_sha256','sampler.py'),('guard_sha256','release_guard.py'),('contracts_sha256','contracts.py'),('reducer_sha256','reduce.py'),('whole_brotli_gate_sha256','whole-brotli-gate.json'),('source_identities_sha256','source-identities.json'),('root_ready_promotion_sha256','root-ready-v2-promotion.json'),('preparation_closure_sha256','preparation-closure.json'),('execution_bindings_sha256','execution-bindings.json')):
        check(release[key]==d.sha(d.path(f)), 'Release artifact binding differs: '+f)
    check(release['quiet_snapshot_sha256']==d.sha(release['quiet_snapshot_path']), 'Recorded final quiet snapshot differs')
    check(pf['completed'] and pf['passed'] and pf['timed_samples']==0 and [(a['key'],a['variant']) for a in pf['attempts']]==[(c,v) for c in order for v in variants], 'Incomplete original warm0 children')
    warm={}
    for a in pf['attempts']:
        c,v=a['key'],a['variant']; row=rows[c]; inp=row['input']; check(row['iterations']==1 and row['family']=='primary' and row['quality']==8 and row['window_bits']==16 and row['control'] is None and inp['bytes']==65536 and d.size(inp['path'])==65536 and d.sha(inp['path'])==inp['sha256'], 'Registered q8 64 KiB input differs')
        _,val=child(d,phase,row,v,a,0,bins[v],pins); path=a['decoder_receipt_path']; decode=d.read_abs(path)
        check(a['decoder_receipt_sha256']==d.sha(path) and decode['actual_exit_code']==0 and decode['complete_decode_passed'] is True and decode['full_input_consumed'] is True and decode['trailing_bytes']==0 and (decode['wire_path'],decode['wire_sha256'],decode['decoded_sha256'],decode['decoded_bytes'])==(a['wire'],val['warm_wire_sha256'],inp['sha256'],inp['bytes']), 'Original complete decoder receipt differs')
        ref_identity(decode['decoder_identity'],pins,True)
        warm[c,v]=(val['warm_wire_bytes'],val['warm_wire_sha256'])
    ratios={c:[] for c in order}; seen=set(); child_iter=iter(m['attempts']); end=moment(m['started_utc']); check(moment(release['issued_utc'])<=end, 'Release occurred after timing')
    for pair in m['pairs']:
        c,r=pair['key'],pair['round']; actual=variants if r%2==0 else variants[::-1]; mean={}
        check(pair['order']==actual and set(pair['processes'])==set(actual), 'AB/BA order differs')
        for v in actual:
            a=next(child_iter); check((a['key'],a['round'],a['variant'])==(c,r,v),'Original child pair slot differs')
            start, stop=moment(a['started_utc']),moment(a['ended_utc']); check(end<=start<=stop,'Original child chronology differs'); end=stop
            for field,suffix in (('output','.json'),('wire','.wire'),('stdout','.stdout'),('stderr','.stderr')):
                x=d.path(f'{phase}/runs/{r:02d}-{c}-{v}{suffix}'); check(a[field]==x and x not in seen,'Original raw file replaced/reused'); seen.add(x)
            ns,val=child(d,phase,rows[c],v,a,1,bins[v],pins); size,digest=warm[c,v]; mean[v]=avg(ns)
            check((val['warm_wire_bytes'],val['warm_wire_sha256'])==(size,digest) and pair['processes'][v]=={'path':a['output'],'raw_ns':ns,'mean_ns':mean[v],'warm_wire_bytes':size,'warm_wire_sha256':digest},'Original raw ns or retained warm identity differs')
        ratios[c].append(mean[variants[0]]/mean[variants[1]])
    check(end<=moment(m['ended_utc']) and seen=={f for f in d.index if f.startswith(d.path(phase+'/runs/'))},'Missing, extra, or retried raw file')
    if phase=='primary': check(all(warm[c,variants[0]]==warm[c,variants[1]] for c in order),'Primary peer full wire differs')
    check(stats['actual_exit_code']==0 and stats['raw_manifest_sha256']==d.sha(d.path(phase+'/run-manifest.json')) and stats['stdout_sha256']==d.sha(d.path(phase+'/summary.json')) and stats['reducer_sha256']==d.sha(d.path('reduce.py')) and stats['raw_proof_sha256']==d.sha(d.path('raw_proof.py')) and stats['stderr_sha256']==d.sha(d.path(phase+'/statistics.stderr')),'Retained original statistics receipt differs')
    points={c:gm(v) for c,v in ratios.items()}; logs={c:list(map(math.log,v)) for c,v in ratios.items()}
    policy=protocol['bootstrap']; check(policy['draws']==20000 and policy['draws_each_stratum']==3 and policy['strata']=={'AB':[0,2,4],'BA':[1,3,5]},'Bootstrap protocol changed')
    rng=Random(policy['seed']); row_draw={c:[] for c in order}; matrix=[]; blocks=[avg(logs[c][r] for c in order) for r in range(6)]
    for _ in range(20000):
        draw=[rng.choice((0,2,4)) for _ in range(3)]+[rng.choice((1,3,5)) for _ in range(3)]
        matrix.append(avg(blocks[r] for r in draw))
        for c in order: row_draw[c].append(avg(logs[c][r] for r in draw))
    def ci(x):
        s=sorted(x); return [math.exp(s[j]) for j in (499,19499)]
    bounds=ci(matrix); point=gm(points.values()); gate=phase=='primary' and point>=1.03 and bounds[0]>1 and min(points.values())>=.98
    check(near(point,summary['GM']) and all(near(x,y) for x,y in zip(bounds,summary['paired_round_block_CI95'])) and gate is summary['primary_gate_pass'] and not summary['adoption_allowed'], 'Preregistered matrix result differs')
    for c in order:
        row=summary['rows'][c]; check(ratios[c]==row['raw_paired_speedups'] and near(points[c],row['GM']) and all(near(x,y) for x,y in zip(ci(row_draw[c]),row['clustered_CI95'])), 'Original paired row result differs: '+c)
    return {'actual_pairs':len(plan),'actual_timed_calls':len(seen)//4,'GM':point,'CI':bounds,'elapsed':1/point,'wire_ratio':gm(warm[c,variants[1]][0]/warm[c,variants[0]][0] for c in order),'primary_gate_pass':gate}


def verify(root):
    inventory(root); d=Data(root); bind=d.read('execution-bindings.json')['families']['primary']; pins=d.read('reference-pins.json')
    for name, b in bind.items():
        check(d.sha(b['ELF'])==b['sha256'] and not b['pending'],'Actual ELF bytes differ: '+name)
        path=b.get('actual_build_receipt',b.get('original_actual_build_receipt'))
        receipt=d.read_abs(path)
        check(d.sha(path)==b.get('actual_build_receipt_sha256',b.get('original_actual_build_receipt_sha256')),'Actual ELF build receipt digest differs: '+name)
        if name=='historical0a':
            proof=d.read_abs(b['exact_source_proof'])
            check(isinstance(receipt,list) and len(receipt)==2 and all(stage['exit_code']==0 for stage in receipt) and proof['not_a_new_build'] and proof['exact_git_revision']==b['revision'] and proof['reused_ELF_sha256']==b['sha256'] and proof['source_manifest_sha256']==ANCHORS[name] and d.sha(b['exact_source_proof'])==b['exact_source_proof_sha256'],'Historical two-stage build or reuse proof differs')
        else:
            check(receipt['actual_exit_code']==0 and (receipt['output'],receipt['output_sha256'])==(b['ELF'],b['sha256']),'Actual new ELF build differs: '+name)
        harness='harness/reference-process.zig' if name=='reference' else 'harness/probe.zig'
        check(d.sha(d.path(harness))==b['harness_sha256'],'Matched actual harness SHA differs')
    for p in pins['libraries'].values(): check((d.sha(p['path']),d.size(p['path']))==(p['sha256'],p['bytes']),'Pinned retained runtime library bytes differ')
    check(not any(p.startswith(d.path('controls/runs/')) or p==d.path('controls/run-manifest.json') for p in d.index) and d.capture['controls_timed'] is False,'Unexpected controls timing')
    outcomes={p:audit_phase(d,p,v,bind,pins) for p,v in PHASES.items()}
    check(not outcomes['primary']['primary_gate_pass'] and near(outcomes['primary']['GM'],1.0147036801576106),'Expected actual primary rejection differs')
    return {'status':'pass','outcomes':outcomes,'controls_timed':False,'adoption_allowed':False,'performance_acceptance':False,'industryLeadership':False,'bootstrap_replayed_data_only':True,'codec_build_C_library_or_timing_executed':False,'original_paths_used_as_archive_keys_only':True}


def main():
    p=argparse.ArgumentParser(description=__doc__); p.add_argument('--root',type=Path,default=Path(__file__).resolve().parent); a=p.parse_args()
    try:
        print(json.dumps(verify(a.root.resolve()),indent=2,sort_keys=True))
    except (ValueError, KeyError, OSError, tarfile.TarError) as e:
        p.exit(1,f'Verification failed: {e}\n')


if __name__=='__main__': main()
