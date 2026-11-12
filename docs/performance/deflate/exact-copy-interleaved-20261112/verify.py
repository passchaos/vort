"""Offline byte and recorded-contract verification; run with taskset -c 0."""
import argparse
import gzip
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import random
import struct
from collections import Counter
import statistics
import subprocess
import tarfile
BASE='21e4a1d0c0323c7db2317fd6e7cda4c5069e8e1d'
PROBE='65b75eeec00bf7933d0baa3886e6097fc7275a813d72190f601be286944cce96'
OWNER_WORD='2d2d18228696054e15296b760b2a7c5060a0e746032c20d119130eea339f2258'
OWNER_ONLY='a081724939d287ef018fa650cd5e65b7e13b9829020b3bbd658fada02e0c6e16'
REFERENCE='1261b5e2461c0a12995439abea25e042de4f2d899c5f26fb738b023dc2cbff28'
def require(value,message):
    if not value:raise ValueError(message)
def sha(data):return hashlib.sha256(data).hexdigest()
def unpack(path,mode=None,links=False):
    data=path.read_bytes()
    require(data[:4]==b'\x1f\x8b\x08\x00' and data[4:8]==bytes(4),'Gzip metadata differs: '+str(path))
    files,symlinks={},{}
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(data)),mode='r:') as archive:
        members=archive.getmembers()
        require([m.name for m in members]==sorted({m.name for m in members}),'Unsorted/duplicate archive members')
        for m in members:
            require(not m.name.startswith('/') and '..' not in Path(m.name).parts and m.uid==m.gid==m.mtime==0 and m.uname==m.gname=='','Archive metadata differs')
            if links and m.issym():
                require('/' not in m.linkname and m.linkname!='..','Unsafe reference SONAME link');symlinks[m.name]=m.linkname
            else:
                require(m.isfile() and (mode is None or m.mode==mode),'Archive type/mode differs')
                files[m.name]=archive.extractfile(m).read()
    require(all(str(Path(n).parent/t) in files for n,t in symlinks.items()),'Dangling reference SONAME link')
    return files

def inventory(root,originals):
    require(sorted(os.sched_getaffinity(0))==[0],'Archive verifier must run on CPU0')
    checksum=root/'SHA256SUMS'
    if checksum.exists():
        hashes={n:h for h,n in (line.split('  ',1) for line in checksum.read_text().splitlines())}
        require(set(hashes)=={p.name for p in root.iterdir() if p.is_file() and p!=checksum},'Checksum inventory differs')
        require(all(sha((root/n).read_bytes())==h for n,h in hashes.items()),'Final checksum differs')
    binding=json.loads((root/'archive-bindings.json').read_bytes())
    require(binding['base_revision']==BASE and binding['archive_cpu']==0,'Archive epoch/CPU differs')
    archives={};original_count=0
    for n,r in binding['archives'].items():
        data=unpack(root/n,r['mode']);archives[n]=data
        require({k:sha(v) for k,v in data.items()}==r['files'],'Archive member bytes differ: '+n)
        if originals:
            for member,path in r['origins'].items():
                require(Path(path).read_bytes()==data[member],'Original bytes differ: '+path);original_count+=1
    return binding,archives,original_count

def reused(root,binding):
    repo=root.parents[3];containers={}
    for key,r in binding['reuse'].items():
        if 'sha256' not in r:continue
        path=repo/r['path'];require(sha(path.read_bytes())==r['sha256'],'Reused container differs: '+key)
        containers[key]=unpack(path,links=(key=='reference_libraries'))
    return containers

def git_verify(repo,revision,files):
    if repo is None:return 0
    names=list(files)
    result=subprocess.run(['git','cat-file','--batch'],cwd=repo,input=''.join(revision+':'+n+'\n' for n in names).encode(),capture_output=True,check=True)
    offset=0
    for name in names:
        end=result.stdout.index(b'\n',offset);header=result.stdout[offset:end].split();offset=end+1
        require(len(header)==3 and header[1]==b'blob','Frozen Git blob absent: '+name)
        size=int(header[2]);require(result.stdout[offset:offset+size]==files[name],'Frozen Git bytes differ: '+name);offset+=size+1
    return len(names)

def successful_tests(log,count):
    text=log.decode();rows=re.findall(r'^(\d+)/(\d+) (.*?)\.\.\.(.*?)(?=^\d+/\d+ |^All |\Z)',text,re.M|re.S)
    require(len(rows)==count and [int(r[0]) for r in rows]==list(range(1,count+1)) and all(int(r[1])==count for r in rows),'Successful test rows differ')
    require(all(r[3].rstrip().endswith('OK') for r in rows) and text.endswith(f'All {count} tests passed.\n'),'Terminal test success absent')
    imports=sum(bool(re.search(r'\.test_[0-9]+$',r[2])) for r in rows)
    return {'tests':count,'anonymous_import_tests':imports,'named_tests':count-imports}


def check_pmu(report,mode):
    pairs=report['warmup_pairs']+report['pairs']
    if mode is None:
        require(report['pmu'] is None and report['sampling_mode']=='paired-wall-time' and all(p.get('vort_counters') is None and p.get('reference_counters') is None for p in pairs),'Undeclared/mixed wall counters');return 0
    pmu=report['pmu'];hardware=pmu['hardware'];require(report['sampling_mode']=='pmu-diagnostic-with-batch-control-overhead' and pmu['group']==mode.replace('-','_'),'PMU diagnostic mode differs')
    require(pmu['scope']=='Vort public decode batch and loop/count/mix bookkeeping; userspace boundary ioctl setup; timers and full validation outside counters' and pmu['thread_policy']=='calling-thread-only; no inheritance','Counter scope differs')
    require(pmu['exclude_kernel'] is True and pmu['exclude_hypervisor'] is True and pmu['scaled'] is False and pmu['reference_counted'] is False and pmu['header_time_scope']=='cumulative per open group; reset clears counts only','Counter privilege/scaling/time scope differs')
    require(hardware['events']==['cycles','instructions',mode] and hardware['hardware_configs']==[0,1,4 if mode=='branches' else 5] and hardware['read_format']==15 and hardware['pid_argument']==0 and hardware['cpu_argument']==-1,'Raw PMU hardware configuration differs')
    require(hardware['disabled_at_open'] is True and hardware['inherit'] is False and hardware['exclude_kernel'] is True and hardware['exclude_hv'] is True and hardware['values_scaled'] is False and hardware['strict_full_running_time'] is True,'PMU hardware scheduling policy differs')
    expected_ids=None;previous_enabled=0
    def u64(x,positive=False):return type(x) is int and (0<x if positive else 0<=x) and x<1<<64
    for p in pairs:
        c=p['vort_counters'];words=c['raw_words'];ids=c['event_ids'];require(len(words)==9 and all(u64(w) for w in words) and words[0]==3,'Incomplete nine-word raw group read')
        require(len(ids)==3 and all(u64(i,True) for i in ids) and len(set(ids))==3,'Invalid raw event IDs')
        if expected_ids is None:expected_ids=ids
        require(ids==expected_ids,'IDs changed across same-FD batches');observed=dict(zip(words[4::2],words[3::2]));require(len(observed)==3 and set(observed)==set(ids),'Raw group IDs missing/duplicated')
        for field,i in zip(['cycles','instructions','third_event'],ids):require(u64(c[field],field!='third_event') and observed[i]==c[field],'Semantic/raw PMU count mismatch')
        require(u64(c['time_enabled'],True) and u64(c['time_running'],True) and c['time_enabled']==words[1] and c['time_running']==words[2] and c['time_enabled']==c['time_running'] and c['time_enabled']>previous_enabled,'Raw full-running/cumulative header time mismatch')
        previous_enabled=c['time_enabled'];require(p.get('reference_counters') is None,'Reference counted in Vort counter domain')
    return len(pairs)

def check_report(p,task,manifest,mode):
    fixture=task['fixture'];require(p['schema']=='vort.decode-compare.v1' and p['codec']==fixture['codec'] and p['lifecycle']==task['lifecycle'] and p['iterations']==task['iterations'] and p['rounds']==2,'Probe task/lifecycle/count differs')
    for field in ['input_path','encoded_input_path','input_bytes','encoded_bytes','input_sha256','encoded_sha256']:require(p[field]==fixture[field],'Probe fixture field differs')
    require(all(p['validation'][n] is True for n in ['every_iteration_count','full_output_per_batch','guards_per_batch','input_unchanged_per_batch']),'Recorded full-content/count/guard validation missing')
    consumed=fixture['codec']=='deflate';require(p['exact_consumption']=={'vort':consumed,'reference':consumed} and p['validation']['exact_consumption_per_batch']==consumed,'Codec consumption API scope differs')
    require(p['validation']['prepared_priming']==(task['lifecycle']=='prepared'),'Prepared priming scope differs')
    provenance=p['provenance'];require(provenance['executable_sha256']==manifest['probe_sha256'] and provenance['optimize']=='ReleaseFast' and provenance['target_cpu']=='skylake+pku+sgx' and provenance['cpu_affinity']=='15' and provenance['benchmark_threads']==provenance['affinity_cpu_count']==1 and provenance['zig_version']=='0.16.0','Probe/CPU/build provenance differs')
    require(p['reference_version']==manifest['references'][fixture['codec']]['version'],'Reference version differs')
    require(p['alignment']=={'guard_bytes':64,'input_mod64':0,'encoded_mod64':0,'vort_output_mod64':0,'reference_output_mod64':0},'Guard/alignment schema differs')
    for field,start,count in [('warmup_pairs',0,p['warmup']),('pairs',p['warmup'],2)]:
        require(len(p[field])==count,'Raw paired count differs')
        for index,pair in enumerate(p[field]):require(pair['pair_id']==start+index and pair['first']==('vort' if (start+index)%2==0 else 'reference') and pair['vort_mix']==pair['reference_mix']==task['iterations']*(fixture['input_bytes']+fixture['input_first_byte']),'Raw pair order/output count differs')
    for side in ['vort','reference']:require(p['summary'][side+'_median_ns']==statistics.median(r[side+'_ns'] for r in p['pairs']),'Raw process median differs')
    return check_pmu(p,mode)

def metric_values(event,field):
    if field=='wall_ns':return [p['vort_ns']/event['task']['iterations'] for p in event['probe']['pairs']]
    return [p['vort_counters'][field]/event['task']['iterations'] for p in event['probe']['pairs']]


def close(a,b,message):
    if isinstance(b,list):require(len(a)==len(b),message);[close(x,y,message) for x,y in zip(a,b)]
    elif isinstance(b,(int,float)):require(math.isclose(a,b,rel_tol=1e-12,abs_tol=1e-12),message)
    else:require(a==b,message)


PROBE='a69c106fec63a70490be2dd57a76e233ddbaaaadcb37439d2d6abab52897a91f'
def bootstrap_rows(rows):
    rng=random.Random(0x20261112);logs=[list(map(math.log,row)) for row in rows];center=math.exp(statistics.mean(statistics.mean(row) for row in logs));samples=[]
    for _ in range(2000):samples.append(math.exp(statistics.mean(statistics.mean([rng.choice(r[::2]) for _ in range(2)]+[rng.choice(r[1::2]) for _ in range(2)]) for r in logs)))
    samples.sort();return center,samples

def baseline_and_sources(root,binding,archives,containers,originals):
    base={n.removeprefix('shared-dispatch/'):v for n,v in containers['baseline_source'].items()}
    for key in ['public_overlay','wide_overlay','holes_overlay','tools_overlay']:base.update(containers[key])
    refresh=json.loads(containers['refresh_raw']['manifest.json']);require(refresh['source']['revision']==BASE and {n:sha(v) for n,v in base.items()}==refresh['source']['sha256'] and len(base)==2072,'Frozen current baseline source differs')
    baseline=containers['baseline_probe']['baseline-compare'];require(sha(baseline)==PROBE,'Accepted refresh baseline probe differs')
    require(sha(containers['reference_libraries']['deflate/libdeflate.so.0'])==REFERENCE,'Exact libdeflate bytes differ')
    imports=archives['runner-imports.tar.gz'];require(all(v==base[n] for n,v in imports.items()),'Immutable helper closure differs')
    shared=archives['shared-test-source.tar.gz'];manifests={};source_counts={}
    for version in ['v1','v2','v3']:
        raw=archives[version+'-raw.tar.gz'];full={**base,**shared,**archives[version+'-kernel-source.tar.gz']};snap=binding['source_snapshots'][version];freeze=json.loads(raw[snap['receipt']])['source_sha256']
        if version=='v1':freeze={**freeze,**json.loads(raw['page-source-freeze.json'])['source_sha256']}
        require(all(sha(full[n])==h for n,h in freeze.items()),'Exact source epoch freeze differs')
        if originals:
            for n,path in snap['origins'].items():require(Path(path).read_bytes()==full[n],'Original frozen source byte differs')
        require(full['src/deflate.zig']==base['src/deflate.zig'] and full['src/deflate/semantic/decoder.zig']==base['src/deflate/semantic/decoder.zig'],'Caller/error/reader source changed')
        manifests[version]={}
        for label,source in [('baseline',base),('control',full)]:
            m=json.loads(raw[label+'.manifest.json']);require(m['source']['revision']==BASE and {n:sha(v) for n,v in source.items()}==m['source']['sha256'] and sha(json.dumps(m['source']['sha256'],sort_keys=True).encode())==m['source']['digest'],'Captured source registry differs')
            pf=json.loads(raw['probe-freeze.json'])[label];binary=baseline if label=='baseline' else archives['performance-probes.tar.gz'][version+'/control-compare'];require(sha(binary)==pf['sha256']==m['probe_sha256'] and len(binary)==pf['bytes'],'Variant exact binary epoch differs');manifests[version][label]=m
            if originals:require(Path(m['probe']).read_bytes()==binary,'Original probe changed')
        require(len(full)==2075,'Captured candidate source count differs');source_counts[version]=len(full)
    full=archives['full-cold.tar.gz'];full_manifests={label:json.loads(full[label+'.manifest.json']) for label in ['baseline','control']}
    require(all(full_manifests[label]['source']==manifests['v3'][label]['source'] and full_manifests[label]['probe_sha256']==manifests['v3'][label]['probe_sha256'] for label in full_manifests),'Expanded full-cold source/probe epoch rebound')
    return base,manifests,full_manifests,source_counts


def fixture_registry(root,binding,originals):
    data=(root/'fixture-replay-bindings.json').read_bytes();require(sha(data)==binding['fixture_descriptor_reuse']['sha256'],'Original ordinary fixture descriptor differs');j=json.loads(data);fixtures={f['key']:f for f in j['fixtures']};require(len(fixtures)==72 and len(j['files'])==108,'Original72-wire descriptor count differs')
    if originals:
        for n,r in j['files'].items():b=Path(n).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'],'Original frozen input differs')
    return fixtures


def campaign(raw,rows,manifests,fixtures,full=False):
    events=json.loads(raw['events.json']);protocol=json.loads(raw['protocol.json']);summary=json.loads(raw['summary.json']);ind=json.loads(raw['independent-statistics.json']);expected=576 if full else 160;require(len(events)==expected and protocol['process_sweeps']==4 and protocol['rounds']==protocol['warmup']==2,'Effective expanded/sample protocol differs')
    require(ind['source_events_sha256']==sha(raw['events.json']) and ind.get('events',ind.get('event_count'))==expected and ind['adopted'] is False,'Main independent raw-event identity differs')
    require(len(protocol['tasks'])==(72 if full else 12) and protocol['variants']==['baseline','control'],'Effective task scope differs')
    if full:require(protocol['modes']==[None] and protocol['pmu_keys']==[] and ind['raw_measured_pairs']==ind['raw_warmup_pairs']==1152 and ind['rounds_per_process']==2,'Full-cold actual two-round/warmup/PMU scope differs')
    else:require(sum(e['mode'] is not None for e in events)==64,'Small screen PMU scope differs')
    table={};speed={};pmu_reads=0
    for task in protocol['tasks']:
        f=task['fixture'];key=f['key'].replace('/','_')+'_cold';require(f==fixtures[f['key']] and task['lifecycle']=='cold','Frozen row fixture/lifecycle differs')
        for mode in (protocol['modes'] if key in protocol['pmu_keys'] else [None]):
            name=mode or 'wall-time'
            for sweep in range(4):
                selected=[e for e in events if e['key']==key and e['mode']==mode and e['sweep']==sweep];require([e['variant'] for e in selected]==(['baseline','control'] if sweep%2==0 else ['control','baseline']),'Recorded AB/BA process ordering differs')
                for e in selected:
                    variant=e['variant'];stem=f'{key}.{name}.{sweep}.{variant}';require(json.loads(rows[stem+'.json'])==e and json.loads(rows[stem+'.stdout.raw'])==e['probe'] and rows[stem+'.stderr.raw']==b'','Original report/stdout/stderr differs')
                    require(json.loads(rows[stem+'.process.json'])=={'returncode':0,'argv':e['argv'],'before':e['before'],'after':e['after']} and not e['before']['compilers'] and not e['after']['compilers'],'Original process/exit/compiler observations differ')
                    require(e['task']==task and e['probe']['warmup']==2 and e['argv'][:3]==['taskset','-c','15'] and e['argv'][3]==manifests[variant]['probe'] and e['probe']['provenance']['command']==' '.join(e['argv'][3:]),'Original invocation/source binding differs');pmu_reads+=check_report(e['probe'],task,manifests[variant],mode);table[key,mode,sweep,variant]=e
            for variant in ['baseline','control']:
                batches=[p for sweep in range(4) for p in table[key,mode,sweep,variant]['probe']['pairs']];d=summary[key][name][variant];require(d['processes']==4 and d['measured_batches']==8,'Batch aggregation count differs');close(d['wall_ns_per_call_median'],statistics.median(p['vort_ns']/task['iterations'] for p in batches),'Raw per-call wall median differs')
                if mode:
                    for metric in ['cycles','instructions','third_event']:close(d[metric+'_per_call_median'],statistics.median(p['vort_counters'][metric]/task['iterations'] for p in batches),'Raw PMU aggregate differs')
                    close(d['ipc_per_batch_median'],statistics.median(p['vort_counters']['instructions']/p['vort_counters']['cycles'] for p in batches),'Raw PMU IPC differs')
            if mode is None:
                ratios=[statistics.median(p['vort_ns'] for p in table[key,mode,sweep,'baseline']['probe']['pairs'])/statistics.median(p['vort_ns'] for p in table[key,mode,sweep,'control']['probe']['pairs']) for sweep in range(4)];gm=math.exp(statistics.mean(map(math.log,ratios)));close(ind['rows'][key]['paired_speed_ratios'],ratios,'Independent paired ratios differ');close(ind['rows'][key]['speed_geomean'],gm,'Independent row GM differs');speed[key]=ratios
            elif 'pmu' in ind:
                for metric in ['cycles','instructions','third_event']:
                    ratios=[statistics.median(metric_values(table[key,mode,sweep,'control'],metric))/statistics.median(metric_values(table[key,mode,sweep,'baseline'],metric)) for sweep in range(4)];d=ind['pmu'][key+'_'+mode][metric];close(d['paired_ratios'],ratios,'Independent PMU process ratios differ');close(d.get('candidate_over_baseline_geomean',d.get('candidate_over_baseline')),math.exp(statistics.mean(map(math.log,ratios))),'Independent PMU GM differs')
    order=ind['row_order'] if full else list(speed);require(order==list(speed),'Independent fixed-row ordering differs');gm,boot=bootstrap_rows([speed[k] for k in order]);close(ind['speed_geomean'],gm,'Independent campaign GM differs')
    # Full recompute explicitly uses upper index1950. Retain the observed small
    # screen finite-bootstrap endpoint rather than normalizing old results.
    possible=[1950] if full else [1949,1950];upper=next((i for i in possible if math.isclose(boot[i],ind['ci95'][1],rel_tol=1e-12,abs_tol=1e-12)),None);require(upper is not None,'Original upper bootstrap endpoint differs');close(ind['ci95'],[boot[50],boot[upper]],'Independent balanced CI differs')
    weak=sorted((math.exp(statistics.mean(map(math.log,r))),k) for k,r in speed.items());close(ind['weakest'],list(weak[0]),'Independent weakest row differs')
    if full:
        below=[[v,k] for v,k in weak if v<.98];close(ind['controls_below_098'],below,'Full control regressions differ');require(len(below)==9 and ind['gates']=={'aggregate_103':False,'confidence_excludes_parity':True,'controls_098':False} and gm<1.03,'Final full-cold rejection gates differ')
        for size in ['65536','1048576','full']:close(ind['size_groups'][size],math.exp(statistics.mean(math.log(v) for v,k in weak if fixtures[table[k,None,0,'baseline']['task']['fixture']['key']]['size']==size)),'Expanded size-group GM differs')
    else:require(pmu_reads==256,'Small PMU reads differ');below=[[v,k] for v,k in weak if v<.98]
    return {'events':expected,'rows':len(speed),'rounds':2,'warmup':2,'process_sweeps':4,'measured_pairs':expected*2,'warmup_pairs':expected*2,'speed_geomean':gm,'ci95':ind['ci95'],'weakest':list(weak[0]),'controls_below_098':below,'bootstrap_upper_order_index':upper,'pmu_events':0 if full else 64,'adopted':False}


def source_and_test_logs(archives):
    results={}
    for version in ['v1','v2','v3']:
        raw=archives[version+'-raw.tar.gz'];tests={'kernel':successful_tests(raw['kernel-safe.log'],3),'full_deflate':successful_tests(raw['full-safe.log'],738),'pages_safe':successful_tests(raw['pages-safe.log'],1)}
        if version=='v1':tests['pages_debug']=successful_tests(raw['pages-debug.log'],1);tests['pages_x86']=successful_tests(raw['pages-x86.log'],1)
        require(tests['kernel']['anonymous_import_tests']==1 and tests['kernel']['named_tests']==2,'Kernel/import aggregate scope differs');require(b'Build Summary: 7/7 steps succeeded' in raw['build.log'],'Successful variant build receipt absent');results[version]=tests
    return {'runs':results,'linux_guard_page_exact_span_cases':1996,'kernel_public_facade_lengths':'3..258','validated_core_lengths':'16..258','private_lengths_above_258_tested':False}


def smoke(archives,version,manifest,fixtures):
    raw=archives[version+'-smoke.tar.gz'];m=json.loads(raw['manifest.json']);require(m['source']==manifest['source'] and m['probe_sha256']==manifest['probe_sha256'],'Smoke source epoch differs');events=json.loads(raw['events.json']);require(len(events)==72 and {e['task']['fixture']['key'] for e in events}==set(fixtures),'Original72-wire smoke scope differs')
    for e in events:
        task=e['task'];f=fixtures[task['fixture']['key']];key=f['key'].replace('/','_')+'_cold';require(task=={'fixture':f,'lifecycle':'cold','iterations':1} and e['returncode']==0 and json.loads(raw[key+'.json'])==e and json.loads(raw[key+'.stdout.raw'])==e['probe'] and raw[key+'.stderr.raw']==b'' and e['probe']['warmup']==0,'Raw smoke report/task differs');check_report(e['probe'],task,m,None)
    validation=json.loads(raw['validation.json']);require(validation['events']==72 and validation['full_output'] is validation['exact_consumption'] is validation['guards'] is validation['input_immutable'] is validation['timings_not_performance'] is True,'Completed smoke output/consumption/guard scope differs');return {'wires':72,'timings_are_performance_evidence':False}


def static_evidence(root,binding,archives,containers,originals):
    raw=archives['original-codegen.tar.gz'];reported=json.loads((root/'codegen-reported.json').read_bytes());probes=archives['performance-probes.tar.gz'];results={}
    for key in ['baseline','v1','v2','v3']:
        data=raw[key+'.txt'];source=binding['codegen_original_sources'][key];require(sha(data)==source['sha256'],'Original codegen tool bytes differ')
        if originals:require(Path(source['source']).read_bytes()==data,'Original codegen source artifact changed')
        rows=[];bytes_at={}
        for line in data.decode().splitlines():
            m=re.match(r'^\s*([0-9a-f]+):\s*((?:[0-9a-f]{2}\s+)+)\s*(.*)$',line)
            if m:
                address=int(m[1],16);values=bytes.fromhex(m[2]);bytes_at.update({address+i:v for i,v in enumerate(values)})
                if m[3]:rows.append((address,m[3]))
        count=len(rows);size=max(bytes_at)-min(bytes_at)+1;stacks=[int(m[1],16) for a,t in rows if (m:=re.match(r'sub\s+\$0x([0-9a-f]+),%rsp',t))];vector=sum(t.split()[0].startswith('v') and ('%rbp' in t or '%rsp' in t) for a,t in rows);expected=reported['rows'][key];require(size==expected['text_bytes'] and stacks==[expected['stack_bytes']] and count==expected['instructions'],'Reported static scalar table differs')
        require(vector==expected['vector_stack_references'],'Static vector-stack operand count differs')
        binary=containers['baseline_probe']['baseline-compare'] if key=='baseline' else probes[key+'/control-compare'];offset=struct.unpack_from('<Q',binary,40)[0];entry,num=struct.unpack_from('<HH',binary,58);sections=[struct.unpack_from('<IIQQQQIIQQ',binary,offset+i*entry) for i in range(num)];start=min(bytes_at);section=next(s for s in sections if s[3]<=start and start+size<=s[3]+s[5]);p=section[4]+start-section[3];require(binary[p:p+size]==bytes(bytes_at[i] for i in range(start,start+size)),'Original disassembly/probe epoch differs');results[key]={'text_bytes':size,'stack_bytes':stacks[0],'instructions':count,'vector_stack_references':vector}
    return {'original_agent_artifacts':4,'counters':results,'vector_stack_is_dynamic_spill_count':False,'private_above_258_contract_proven':False}


def verify(root,originals=False,git_repo=None):
    binding,archives,count=inventory(root,originals);containers=reused(root,binding);base,manifests,full_m,source_counts=baseline_and_sources(root,binding,archives,containers,originals);fixtures=fixture_registry(root,binding,originals);small={};smokes={}
    for version in ['v1','v2','v3']:small[version]=campaign(archives[version+'-raw.tar.gz'],archives[version+'-rows.tar.gz'],manifests[version],fixtures);smokes[version]=smoke(archives,version,manifests[version]['control'],fixtures)
    full_data=archives['full-cold.tar.gz'];full_raw={n:v for n,v in full_data.items() if not n.startswith('rows/')};full_rows={n.removeprefix('rows/'):v for n,v in full_data.items() if n.startswith('rows/')};require(full_raw['independent-statistics.json']==(root/'full-cold-independent-statistics.json').read_bytes() and b'boot[1950]' in full_raw['recompute.py'],'Original final full-cold derivative/method differs');full=campaign(full_raw,full_rows,full_m,fixtures,True)
    identities=json.loads((root/'test-binary-identities.json').read_bytes())['tests'];require(len(identities)==11,'Test executable identity index incomplete')
    for name,record in identities.items():
        version=record['source_epoch'];member=record['raw_log_member'].split(':',1)[1];require(version in ['v1','v2','v3'] and member in archives[version+'-raw.tar.gz'] and len(record['sha256'])==64 and record['bytes']>0 and record['compiler_argv'] is None,'Original test binary/log/build metadata differs')
        if originals:require(sha(Path(record['original_file']).read_bytes())==record['sha256'],'External original test binary hash differs')
    tests=source_and_test_logs(archives);static=static_evidence(root,binding,archives,containers,originals);git=git_verify(git_repo,BASE,base)
    return {'schema':'vort.deflate.exact-copy-archive-validation.v1','valid':True,'scope':'offline original-byte/source/probe/recorded-test/ordering/raw-ratio/bootstrap validation; no compiler,test,codec,oracle,perf or benchmark execution','cpu_affinity':sorted(os.sched_getaffinity(0)),'source_revision':BASE,'baseline_git_blobs_verified':git,'original_files_verified':count,'candidate_source_registry_files':source_counts,'small_screens':small,'full_cold_final':full,'smoke':smokes,'functional_test_scope':tests,'static_evidence':static,'external_fixture_files_verified':108 if originals else 0,'big_source_and_corpus_not_duplicated':True,'test_executable_bytes_archived':False,'test_executable_identity_records':11,'codec_adoption':{'v1':False,'v2':False,'v3':False},'all_three_variants_rejected':True,'dedicated_host_acceptance':False}
if __name__=='__main__':
    a=argparse.ArgumentParser(description=__doc__);a.add_argument('--originals',action='store_true');a.add_argument('--git-repo',type=Path);p=a.parse_args();print(json.dumps(verify(Path(__file__).resolve().parent,p.originals,p.git_repo),indent=2))
