#!/usr/bin/env python3
"""Verify retained round4ctx pilot outputs only. No codec/producer imports or execution.

Use --map OLD=LOCAL for additional preserved roots/files after relocation.
The recorded epoch root is automatically mapped to the supplied epoch path.
"""
import argparse
import hashlib
import json
import math
from datetime import datetime
from functools import lru_cache
from pathlib import Path


def eq(x,y,label):
    if x!=y: raise ValueError(f'{label}: {repr(x)[:240]} != {repr(y)[:240]}')
def ok(x,label):
    if not x: raise ValueError(label)
def js(p): return json.loads(p.read_bytes())
@lru_cache(None)
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def when(s): return datetime.fromisoformat(s)
def gm(values):
    v=list(values); return math.exp(math.fsum(math.log(x) for x in v)/len(v))
def num(a,b,label): ok(math.isclose(a,b,rel_tol=1e-13,abs_tol=1e-13),(label,a,b))


def verify(root, mappings):
    read=lambda name:js(root/name)
    ready=read('BUILD_SOURCE_READY.json'); original=ready['epoch_root']; aliases=[(original,root),*mappings]; aliases.sort(key=lambda x:-len(Path(x[0]).parts))
    def local(s):
        p=Path(s)
        for old,new in aliases:
            try: return new/p.relative_to(old)
            except ValueError: pass
        return p
    variants=['baseline','candidate']; protocol=read('protocols/main-pilot.json'); seal=read('pilot-readiness-seal.json'); r=read('pilot-release.json'); raw=read('pilot/run-manifest.json'); report=read('pilot-summary.json'); status=read('pilot-execution-status.json'); pf=read('preflight-results.json')
    eq((r['epoch_root'],r['issued_by'],r['purpose'],r['phase'],r['released'],r['global_heavy_terminal'],r['narrow_gates_accepted'],r['full_gate_passed']),(original,'/root','diagnostic-only','pilot',True,True,True,False),'explicit diagnostic Root release, not full gate')
    eq((raw['release'],raw['release_sha256'],raw['protocol']),(r,sha(root/'pilot-release.json'),protocol),'retained actual manifest release and protocol')
    eq((sha(root/'pilot-readiness-seal.json'),sha(root/'protocols/main-pilot.json'),sha(root/'pilot-only.py')),(r['readiness_seal_sha256'],r['protocol_sha256'],r['sampler_sha256']),'preregistered release bindings; no producer import')
    eq((seal['protocol_sha256'],seal['sampler_sha256'],seal['build_preflight_bindings_sha256'],seal['HEAVY']), (r['protocol_sha256'],r['sampler_sha256'],sha(root/'build-preflight-bindings.json'),0),'sealed build and protocol')
    ok(when(pf['completed_utc'])<when(seal['sealed_utc'])<when(r['issued_utc'])<=when(raw['started_utc'])<when(raw['completed_utc']),'preflight/seal/release/run chronology')
    eq((protocol['pairs'],protocol['processes'],protocol['rounds'],protocol['timed_calls'],protocol['CI'],protocol['GM_min'],protocol['every_row_point_floor'],protocol['no_retry_until_pass'],protocol['full_gate_passed']),(24,48,2,48,None,1.03,.98,True,False),'predeclared diagnostic point gates')
    eq((raw['completed'],raw['terminal'],raw['full_gate_passed'],raw['merge_eligible'],status['HEAVY'],status['completed_pairs'],status['timed_processes_completed'],status['terminal']), (True,True,False,False,0,24,48,True),'terminal pilot producer and child counts')
    ok('failure' not in raw,'no failed/retried pilot manifest')
    binds=read('build-preflight-bindings.json')['files']; checked={}
    def sealed(rel):
        file=root/rel; a=binds[rel]; eq((file.stat().st_size,sha(file)),(a['bytes'],a['sha256']),('build/preflight artifact',rel)); checked[rel]=a['sha256'];return file
    for name in ('BUILD_SOURCE_READY.json','NARROW_GATES_READY.json','assets/baseline-source-proof.json','baseline46d-source-files.json','candidate-source-files.json','source-live-before-freeze.json','source-live-after-freeze.json','harness/probe.zig','harness/provenance.zig','preflight-results.json','decoder-receipt.json','build-results.json','bin/candidate'): sealed(name)
    cs=sha(root/'candidate-source-files.json');bs=sha(root/'baseline46d-source-files.json')
    eq((r['candidate_source_manifest_sha256'],raw['source_manifest_sha256'],seal['candidate_source_manifest_sha256'],ready['candidate_source_manifest_sha256']), (cs,)*4,'candidate released exact source registry')
    eq((sha(root/'source-live-before-freeze.json'),sha(root/'source-live-after-freeze.json')), (cs,cs),'before/after source identity')
    registries={'baseline':(read('baseline46d-source-files.json'),local(ready['baseline_actual_git_export_tree'])),'candidate':(read('candidate-source-files.json'),local(ready['candidate_src_tree']))}
    for var,(reg,folder) in registries.items():
        eq(set(reg),{str(p.relative_to(folder)) for p in (folder/'src').rglob('*') if p.is_file()},('exact source inventory',var))
        for file,h in reg.items(): eq(sha(folder/file),h,('frozen source bytes',var,file))
    source_proof=read('assets/baseline-source-proof.json')
    eq((source_proof['semantic_revision'],source_proof['actual_old_snapshot_identity'],source_proof['actual_ELF'],source_proof['source_equality'],source_proof['not_a_new_HEAD_build'],len(source_proof['mismatches']),source_proof['tracked_src_files'],len(source_proof['records'])),(ready['baseline_actual_git_revision'],protocol['baseline_actual_old_build'],protocol['baseline_ELF'],True,True,0,len(registries['baseline'][0]),len(registries['baseline'][0])),'real retained baseline build vs equal Git source')
    build=next(b for b in read('build-results.json')['stages'] if b['stage']=='candidate')
    retained_build=js(local(source_proof['actual_old_build_receipt']))
    ex={'baseline':(protocol['baseline_ELF'],ready['baseline_actual_git_revision'],source_proof['actual_ELF_sha256']), 'candidate':(original+'/bin/candidate',ready['candidate_revision'],build['output_sha256'])}
    for var,receipt in (('baseline',retained_build),('candidate',build)):
        elf,_,h=ex[var]; file=local(elf)
        eq((receipt['actual_exit_code'],receipt['output'],receipt['output_sha256'],file.read_bytes()[:4],sha(file)), (0,elf,h,b'\x7fELF',h),('actual ELF/build before vs retained bytes',var))
    eq((ex['baseline'][2],ex['candidate'][2]),(seal['baseline_ELF_sha256'],seal['candidate_ELF_sha256']),'pre-release two ELF identities')
    probe=read('harness/probe-bindings.json')
    eq(sha(sealed(probe['new_control_probe'])),ready['generic_probe_sha256'],'separate generic control probe')
    for rec in (retained_build,build):
        for flag,expected in (('-Mroot=',probe['main_probe_sha256']),('-Mprovenance=',probe['provenance_sha256'])):
            f=next(v[len(flag):] for v in rec['argv'] if v.startswith(flag)); eq(sha(local(f)),expected,'same actual main probe and provenance bytes')

    eq((pf['processes'],pf['timed_samples'],pf['all_wire_peer_memcmp_and_external_decode_passed'],pf['success']),(84,0,True,True),'terminal untimed preflight assertions')
    init={(x['case'],x['variant']):x for x in pf['rows'] if x['family']=='main'}; pa={(x['case'],x['variant']):x for x in pf['attempts'] if x['family']=='main'}
    eq(len(init),24,'primary untimed wires')
    eq(set(init),set(pa),'same untimed process/wire identities')
    fixtures={x['case']:x for x in read('fixtures-method.json')};eq(list(fixtures),protocol['case_order'],'frozen 12 fixture order'); eq(len(fixtures),12,'fixed corpus rows')
    wire={}; inputs={}
    for c,f in fixtures.items():
        inp=local(f['path']); eq((inp.stat().st_size,sha(inp)),(65536,f['sha256']),'full 64 KiB input bytes'); inputs[c]=f['sha256']
        for var in variants:
            item=init[c,var]; attempt=pa[c,var]; stem=f'preflight/main/{c}-{var}'
            out,br=[sealed(stem+ext) for ext in ('.json','.br')]
            eq((attempt['actual_exit_code'],attempt['output'],attempt['wire'],item['wire_path']), (0,original+'/'+stem+'.json',original+'/'+stem+'.br',original+'/'+stem+'.br'),'actual untimed attempt binding')
            eq((item['wire_bytes'],item['wire_sha256'],item['input_sha256'],item['iterations'],item['samples'],item['complete_external_decode']), (br.stat().st_size,sha(br),f['sha256'],0,0,True),'current complete initial wire bytes + retained decode assertion')
            raw0=js(out); eq((raw0['iterations'],raw0['samples'],raw0['warm_wire_bytes'],raw0['warm_wire_sha256'],raw0['provenance']['executable_sha256']),(0,[],item['wire_bytes'],item['wire_sha256'],ex[var][2]),'retained untimed child output')
            wire[c,var]=(item['wire_bytes'],item['wire_sha256'])
        eq(local(init[c,'baseline']['wire_path']).read_bytes(),local(init[c,'candidate']['wire_path']).read_bytes(),'paired full initial wires exact')
    vp=read('decoder-receipt.json');eq((vp['actual_version'],set(vp['mapped_brotli_paths'])),('1.2.0',{v['path'] for v in vp['libraries'].values()}),'pinned reference version/map assertion')
    scopes=('Continuous owned allocating public encode, wire-length mix and free. SHA256 and cross-library decode validate only the initial complete wire, outside timing.', 'initial_wire_only; timed outputs check lengths/mix, not complete SHA256')
    schedule=[(i,c) for i in range(2) for c in fixtures]; eq([(p['round'],p['case']) for p in raw['pairs']],schedule,'all 24 planned pairs in order')
    eq(len(raw['attempts']),48,'48 attempts without retries'); attempt=iter(raw['attempts']); files={}; ratios={c:[] for c in fixtures}; arithmetic_ns={v:[] for v in variants}; paired=[]
    for p in raw['pairs']:
        rnd,c=p['round'],p['case']; order=variants if rnd==0 else variants[::-1]; eq(p['order'],order,'observed balanced AB/BA'); ns={}
        for var in order:
            item=next(attempt); stem=f'pilot/runs/{rnd:02d}-{c}-{var}'; fp=original+'/'+stem+'.json'; elf,rev,h=ex[var]
            eq((item['round'],item['case'],item['variant'],item['actual_exit_code']),(rnd,c,var,0),'actual attempted child order and exit')
            cmd=['taskset','-c','2',elf,'--input',fixtures[c]['path'],'--output',fp,'--source-revision',rev,'--iterations','1','--window','16']
            eq(item['argv'],cmd,'owning generic probe actual argv')
            for key,ext in (('output','.json'),('stdout','.stdout'),('stderr','.stderr')):
                rel=stem+ext;eq(item[key],original+'/'+rel,'actual retained attempt path');ok(rel not in files,'unique child paths');files[rel]=sha(root/rel)
                if key!='output': eq((root/rel).stat().st_size,0,'retained empty stdout/stderr')
            child=read(stem+'.json'); prov=child['provenance']
            eq((child['schema'],child['source_revision'],child['input_path'],child['input_bytes'],child['input_sha256'],child['quality'],child['mode'],child['requested_window_bits'],child['allocator'],child['warmup_owned_encode_free_calls'],child['iterations']),('vort.q8-source-history-ab.process.v1',rev,fixtures[c]['path'],65536,inputs[c],8,'generic',16,'std.process.Init.gpa',1,1),'source input public q8 settings warm1 timed1')
            eq([prov[k] for k in ('executable_sha256','command','optimize','zig_version','target_arch','target_os','target_abi','target_cpu','cpu_affinity','affinity_cpu_count','benchmark_threads','codec_thread_policy')],[h,' '.join(cmd[3:]),'ReleaseFast','0.16.0','x86_64','linux','gnu','skylake+pku+sgx','2',1,1,'single'],'source/ELF/probe CPU metadata')
            eq((child['timing_scope'],child['wire_identity_scope']),scopes,'continuous warm/owned encode + mix + free; initial-only full SHA')
            size,digest=wire[c,var]; eq((child['warm_wire_bytes'],child['warm_wire_sha256']),(size,digest),'every timed process binds preflight initial wire')
            eq(len(child['samples']),1,'single retained timed call'); sample=child['samples'][0]; t=sample['owned_encode_free_ns']; ok(type(t) is int and t>0,'positive recorded raw ns')
            eq((sample['index'],sample['wire_bytes'],sample['mix']),(0,size,size),'full timed length and mix validation')
            eq(p['processes'][var],{'path':fp,'raw_ns':[t]},'producer manifest raw recorded ns identical')
            ns[var]=math.fsum([t]); arithmetic_ns[var].append(t)
        ratio=ns['baseline']/ns['candidate']; ratios[c].append(ratio);paired.append(dict(case=c,round=rnd,order=order,ns=ns,throughput_ratio=ratio))
    eq(set(files),{str(p.relative_to(root)) for p in (root/'pilot/runs').iterdir()},'all 144 raw child sidecars retained, no retries/omissions')
    rows={c:gm(a) for c,a in ratios.items()}; overall=gm(rows.values()); floor=all(v>=.98 for v in rows.values()); gate=overall>=1.03 and floor
    eq(set(rows),set(report['primary_row_GMs']),'all 12 row summaries')
    for c,v in rows.items(): num(v,report['primary_row_GMs'][c],c)
    for field in ('primary_GM','all_sample_equal_row_GM_secondary'): num(overall,report[field],field)
    eq((report['all_primary_row_point_floors_pass'],report['point_screen_pass'],report['CI'],report['merge_eligible'],report['adoption_allowed'],report['full_gate_passed'],report['pairs'],report['processes'],report['completed']),(floor,gate,None,False,False,False,24,48,True),'preregistered rejection; explicit null CI/no merge')
    metadata=('protocols/main-pilot.json','pilot-only.py','pilot-readiness-seal.json','pilot-release.json','pilot/run-manifest.json','pilot-summary.json','pilot-execution-status.json','fixtures-method.json','build-preflight-bindings.json')
    low,high=min(rows,key=rows.get),max(rows,key=rows.get)
    return {'schema':'vort.round4ctx-pilot-independent-replay.v1','verification':'pass','HEAVY':0,'epoch_original':original,'phase':'pilot','purpose':'diagnostic only; two AB/BA pairs per row; no CI, formal inference, or merge acceptance','point_screen':'pass' if gate else 'reject','required_point_GM_floor':1.03,'required_each_row_floor':.98,'CI':None,'pairs':24,'processes':48,'actual_child_exit_zero':48,'no_retries_or_filtered_samples':True,'run_boundary_utc':[raw['started_utc'],raw['completed_utc']],'chronology_scope':'manifest schedule and ordered attempts; no per-child timestamp was retained','source_files':{v:len(reg) for v,(reg,_) in registries.items()},'source_manifest_sha256':{'baseline':bs,'candidate':cs},'ELF_sha256':{v:x[2] for v,x in ex.items()},'input_sha256':inputs,'full_paired_initial_untimed_wires':24,'preflight_decode_scope':'sealed successful external decoder assertions; no decoder executed by verifier','timing_scope':scopes[0],'arithmetic_call_mean_ns_by_variant':{v:math.fsum(xs)/len(xs) for v,xs in arithmetic_ns.items()},'GM':overall,'elapsed_ratio':1/overall,'rows_below_point_floor':sum(v<.98 for v in rows.values()),'row_GMs':rows,'lowest_row':{'case':low,'value':rows[low]},'highest_row':{'case':high,'value':rows[high]},'raw_pairs':paired,'receipt_sha256':{k:sha(root/k) for k in metadata},'sealed_build_preflight_sha256':checked,'raw_child_file_sha256':files}


def main():
    cli=argparse.ArgumentParser(description=__doc__);cli.add_argument('epoch',type=Path);cli.add_argument('--receipt',type=Path,required=True);cli.add_argument('--map',action='append',default=[],metavar='OLD=LOCAL');a=cli.parse_args()
    remap=[(lhs,Path(rhs).resolve()) for lhs,rhs in (m.split('=',1) for m in a.map)]; report=verify(a.epoch.resolve(),remap)
    with a.receipt.open('x') as f: json.dump(report,f,indent=2,sort_keys=True); f.write('\n')
    print(json.dumps({k:report[k] for k in ('verification','HEAVY','point_screen','pairs','processes','GM','elapsed_ratio','CI','rows_below_point_floor','lowest_row','highest_row')},indent=2))

if __name__=='__main__': main()
