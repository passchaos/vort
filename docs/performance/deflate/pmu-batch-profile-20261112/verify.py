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
BASE='485ca30f2c61dd57673dd04e996a69171081e194'
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


def close(actual,expected,message):
    if isinstance(expected,list):require(len(actual)==len(expected),message);[close(a,e,message) for a,e in zip(actual,expected)]
    elif isinstance(expected,(float,int)):require(math.isclose(actual,expected,rel_tol=1e-12,abs_tol=1e-12),message)
    else:require(actual==expected,message)

def source_epochs(root,binding,archives,containers):
    raw=archives['raw-diagnostics.tar.gz'];freeze=json.loads(raw['source-freeze.json']);common=archives['common-source.tar.gz'];final=archives['final-tool-source.tar.gz'];final_meta=json.loads(raw['final-tool-source.json'])
    require({n:sha(v) for n,v in common.items()}==freeze['common_source_sha256'] and len(common)==10,'Original measurement common10 differs')
    require({n:sha(v) for n,v in final.items()}==final_meta['sha256'] and len(final)==10,'Final tool10 differs')
    changed=sorted(n for n in common if common[n]!=final[n]);require(changed==sorted(final_meta['changed_since_measured_common_source'])==['tools/decode/evidence_test.py','tools/decode/matrix.py'],'Post-measurement source changes silently rebound')
    base={n.removeprefix('shared-dispatch/'):v for n,v in containers['baseline_source'].items()}
    for key in ['public_overlay','wide_overlay','holes_overlay']:base.update(containers[key])
    require(len(base)==2069,'Immutable codec baseline inventory differs');sources={};manifests={}
    for label in ['baseline','owner-word','owner-only']:
        source=dict(base);epoch=freeze['source_epochs'][label.replace('-','_')];source.update(common)
        if label!='baseline':
            overlay=containers['owner_word_overlay' if label=='owner-word' else 'owner_only_overlay']
            for n,h in epoch.items():
                if n not in common:require(sha(overlay[n])==h,'Codec overlay epoch hash differs');source[n]=overlay[n]
        require(all(sha(source[n])==h for n,h in epoch.items()),'Compiled/measurement source freeze differs')
        m=json.loads(raw[label+'.manifest.json']);require(m['source']['revision']==BASE and {n:sha(v) for n,v in source.items()}==m['source']['sha256'] and sha(json.dumps(m['source']['sha256'],sort_keys=True).encode())==m['source']['digest'],'Captured complete source registry differs')
        require(len(source)==(2072 if label=='baseline' else 2074),'Captured source cardinality differs');sources[label]=source;manifests[label]=m
    imports=archives['runner-imports.tar.gz'];require(all(v==sources['baseline'][n] for n,v in imports.items()),'Original runner helper closure differs')
    identity=json.loads((root/'saved-tool-commit.json').read_bytes());require(identity['commit']==binding['final_tool_commit'] and identity['sha256']==final_meta['sha256'],'Saved final-tool Git identity differs')
    for n in ['source-freeze.json','final-tool-source.json','probe-freeze.json','producer-validation.json','paired-summary.json','copy-loop-analysis.json']:require(raw[n]==(root/n).read_bytes(),'Readable frozen receipt differs')
    probes=archives['probes.tar.gz'];probe_freeze=json.loads(raw['probe-freeze.json'])
    for label in manifests:
        b=probes[label+'-compare'];record=probe_freeze[label];require(sha(b)==record['sha256']==manifests[label]['probe_sha256'] and len(b)==record['bytes'] and b'Build Summary: 7/7 steps succeeded' in raw[record['build_log']],'Probe/build/frozen source binding differs')
    refs=containers['reference_libraries']
    for codec,reference in manifests['baseline']['references'].items():
        for path,h in reference['file_sha256'].items():require(sha(refs[('deflate' if codec=='deflate' else codec)+'/'+Path(path).name])==h,'Pinned reference shared-library bytes differ')
    return base,final,manifests

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

def bootstrap(values):
    logs=list(map(math.log,values));rng=random.Random(0x20261112);samples=[]
    for _ in range(2000):samples.append(math.exp(statistics.mean([rng.choice(logs[::2]) for _ in range(2)]+[rng.choice(logs[1::2]) for _ in range(2)])))
    samples.sort();return math.exp(statistics.mean(logs)),[samples[50],samples[1949]]

def pilot(root,archives,manifests):
    raw=archives['raw-diagnostics.tar.gz'];rows=archives['rows.tar.gz'];events=json.loads(raw['events.json']);protocol=json.loads(raw['protocol.json']);summary=json.loads(raw['summary.json']);paired=json.loads(raw['paired-summary.json']);validation=json.loads(raw['validation.json'])
    require(len(events)==144 and sum(e['mode'] is not None for e in events)==96 and validation['event_count']==144 and validation['raw_measured_pairs']==288 and validation['counter_event_count']==96 and validation['codec_changes_adopted'] is False,'Terminal pilot cardinality/adoption differs')
    require(paired['source_events_sha256']==sha(raw['events.json']) and paired['event_count']==144 and paired['counter_processes']==96 and paired['wall_processes']==48 and paired['prototype_adopted'] is False,'Derived paired summary binding differs')
    require(protocol['modes']==[None,'branches','branch-misses'] and protocol['process_sweeps']==4 and protocol['rounds']==protocol['warmup']==2 and len(protocol['tasks'])==4,'Fixed diagnostic protocol differs')
    counter_reads=0;cohort={}
    for task in protocol['tasks']:
        key='deflate_'+task['fixture']['name']+'_'+task['fixture']['size']+'_'+str(task['fixture']['level'])+'_cold';require(key in protocol['keys'],'Protocol row key differs')
        for mode in protocol['modes']:
            name=mode or 'wall-time'
            for sweep in range(4):
                selected=[e for e in events if e['key']==key and e['mode']==mode and e['sweep']==sweep];order=protocol['variants'] if sweep%2==0 else list(reversed(protocol['variants']));require([e['variant'] for e in selected]==order,'Balanced cohort ordering differs')
                for e in selected:
                    label=e['variant'];stem=f'{key}.{name}.{sweep}.{label}';require(json.loads(rows[stem+'.json'])==e and json.loads(rows[stem+'.stdout.raw'])==e['probe'] and rows[stem+'.stderr.raw']==b'','Original event/probe bytes differ')
                    process=json.loads(rows[stem+'.process.json']);require(process=={'returncode':0,'argv':e['argv'],'before':e['before'],'after':e['after']} and not e['before']['compilers'] and not e['after']['compilers'],'Process/exit/compiler observations differ')
                    require(e['task']==task and e['argv'][:3]==['taskset','-c','15'] and e['argv'][3]==manifests[label]['probe'] and e['probe']['provenance']['command']==' '.join(e['argv'][3:]),'Recorded PMU process command differs')
                    require(e['probe']['warmup']==2 and ('--perf-group' in e['argv'])==(mode is not None),'PMU option/warmup differs');counter_reads+=check_report(e['probe'],task,manifests[label],mode);cohort[key,mode,sweep,label]=e
            for label in protocol['variants']:
                selected=[cohort[key,mode,sweep,label] for sweep in range(4)];batches=[p for e in selected for p in e['probe']['pairs']];declared=summary[key][name][label]
                require(declared['processes']==4 and declared['measured_batches']==8,'Aggregate median scope differs');close(declared['wall_ns_per_call_median'],statistics.median(p['vort_ns']/task['iterations'] for p in batches),'Wall per-call median differs')
                if mode:
                    for field in ['cycles','instructions','third_event']:close(declared[field+'_per_call_median'],statistics.median(p['vort_counters'][field]/task['iterations'] for p in batches),'Raw PMU per-call median differs')
                    close(declared['ipc_per_batch_median'],statistics.median(p['vort_counters']['instructions']/p['vort_counters']['cycles'] for p in batches),'Raw IPC median differs');require(declared['third_event_name']==mode,'Third-event label differs')
            data=paired['rows'][key][name];require(data['counter_group']==mode and data['wall_time_for_throughput_gate'] is False and data['counter_control_overhead_in_wall_time']==(mode is not None),'Diagnostic wall-time acceptance scope differs')
            for variant in ['owner-word','owner-only']:
                fields=['wall_ns']+(['cycles','instructions','third_event'] if mode else [])
                for field in fields:
                    ratios=[statistics.median(metric_values(cohort[key,mode,sweep,variant],field))/statistics.median(metric_values(cohort[key,mode,sweep,'baseline'],field)) for sweep in range(4)]
                    gm,ci=bootstrap(ratios);d=data['ratios'][variant][field];close(d['paired_ratios'],ratios,'Independent paired raw ratios differ');close(d['candidate_over_baseline_geomean'],gm,'Independent paired geomean differs');close(d['ci95'],ci,'Independent balanced bootstrap differs')
    require(counter_reads==384,'PMU measured/warmup raw-read total differs')
    return {'pilot_events':144,'wall_control_events':48,'pmu_events':96,'measured_pairs':288,'warmup_pairs':288,'pmu_measured_batches':192,'pmu_warmup_batches':192,'raw_counter_reads_verified':counter_reads,'paired_statistics_recomputed':True,'bootstrap_resamples':2000,'pmu_wall_time_is_throughput_acceptance':False}


def fixture_fields(root,archives,originals):
    d=json.loads((root/'fixture-fields.json').read_bytes());require(d['four_deflate_cases']==4,'Fixture scope differs');fixtures={f['key']:f for f in d['fixtures']}
    for f in fixtures.values():
        for n,h,bn in [('input_path','input_sha256','input_bytes'),('encoded_input_path','encoded_sha256','encoded_bytes')]:require(d['files'][f[n]]=={'sha256':f[h],'bytes':f[bn]},'Original fixture source fields differ')
    if originals:
        for n,r in d['files'].items():b=Path(n).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'],'Scoped external fixture changed')
    return fixtures,len(d['files']),sum(r['bytes'] for r in d['files'].values())

def smoke(archives,manifests,fixtures):
    raw=archives['raw-diagnostics.tar.gz'];events=json.loads(raw['codec-pmu-smoke.json'])['events'];require(len(events)==6,'Other-codec PMU smoke count differs')
    for e in events:
        p=e['probe'];codec=p['codec'];life=p['lifecycle'];group=e['group'];stem=f'codec-smoke-{codec}-{life}-{group}'
        require(e['returncode']==0 and json.loads(raw[stem+'.stdout.raw'])==p and raw[stem+'.stderr.raw']==b'' and e['task']['fixture']==fixtures[e['task']['fixture']['key']],'Other-codec smoke source/exit/probe differs');require(p['warmup']==0 and e['task']['iterations']==2,'Smoke clock/count scope differs');check_report(p,e['task'],manifests['baseline'],group)
    for group in ['branches','branch-misses']:
        stem='hardware-smoke-'+group;p=json.loads(raw[stem+'.stdout.raw']);require(raw[stem+'.stderr.raw']==b'','Initial hardware smoke stderr differs');fixture=next(f for f in fixtures.values() if f['input_sha256']==p['input_sha256'] and f['encoded_sha256']==p['encoded_sha256']);check_report(p,{'fixture':fixture,'lifecycle':'cold','iterations':500},manifests['baseline'],group)
    return {'other_codec_pmu_smoke_events':6,'initial_deflate_hardware_checks':2,'deflate_consumption_verified':True,'zstd_brotli_consumption_api_exposed':False,'smoke_times_used_as_performance':False}


def disassembly(data):
    rows=[];bytes_at={}
    for line in data.decode().splitlines():
        m=re.match(r'^\s*([0-9a-f]+):\s*((?:[0-9a-f]{2}\s+)+)\s*(.*)$',line)
        if m:
            address=int(m[1],16)
            for offset,v in enumerate(m[2].split()):bytes_at[address+offset]=int(v,16)
            if m[3]:rows.append((address,m[3]))
    return rows,bytes_at

def physical(root,archives,manifests,fixtures):
    raw=archives['branch-sampling.tar.gz'];top=archives['raw-diagnostics.tar.gz'];recording=json.loads(raw['recording.json']);bounded=json.loads(raw['bounded-summary.json']);exact=json.loads(raw['exact-ip-validation.json']);loop=json.loads(top['copy-loop-analysis.json'])
    require(len(recording['records'])==4 and bounded['whole_process_percentages_used'] is False and bounded['whole_process_sample_denominator_used'] is False and bounded['timings_are_performance_evidence'] is False,'Bounded physical denominator scope differs')
    totals=[];copy_samples={}
    for record in recording['records']:
        path=Path(record['argv'][record['argv'].index('-o')+1]);name=path.stem;case,variant=name.split('-',1);data=raw[name+'.data'];require(data[:8]==b'PERFILE2' and record['returncode']==0 and record['vort_calls']==2000,'Physical raw data/exit/call binding differs')
        offset,size=struct.unpack_from('<QQ',data,40);end=offset+size;ips=[];flags=[];lost=0
        while offset<end:
            kind,misc,length=struct.unpack_from('<IHH',data,offset);require(length>=8 and offset+length<=end,'Truncated perf record')
            if kind==9:ips.append(struct.unpack_from('<Q',data,offset+8)[0]);flags.append(misc)
            if kind in [2,13]:lost+=1
            offset+=length
        require(offset==end and set(flags)=={0x4002} and lost==0,'Saved sample exact/user flags or recorded loss differs')
        entry=next(e for e in exact['records'] if e['name']==name);dump=raw[name+'.raw-dump.txt'];require(entry['samples']==len(ips) and entry['all_exact_ip'] is True and entry['all_userspace'] is True and entry['lost_records']==0 and entry['raw_dump_sha256']==sha(dump),'Exact-IP validation receipt differs')
        dump_ips=[int(i,16) for i in re.findall(rb'PERF_RECORD_SAMPLE\(IP, 0x4002\): \d+/\d+: 0x([0-9a-f]+) period: 1000',dump)];require(dump_ips==ips and b'PERF_RECORD_LOST' not in dump,'Original raw dump/binary sample records differ')
        parsed=[]
        for line in raw[name+'.samples.txt'].decode().splitlines():
            m=re.match(r'^U\s+(\d+)\s+([0-9a-f]+)\s+(.+) \((.+)\)$',line);require(m is not None,'Unexpected recorded sample text');parsed.append({'misc':'U','period':int(m[1]),'ip':'0x'+m[2],'symbol':m[3],'dso':m[4]})
        require([int(e['ip'],16) for e in parsed]==ips,'Saved text/binary sample IPs differ')
        selected=[]
        for e in parsed:
            symbol=e['symbol'].split('+')[0];domain=None
            if symbol=='deflate.semantic.linear_entry.aligned':domain='ordinary_aligned_payload'
            elif symbol.startswith('deflate.semantic.decoder.SemanticDynamicDecoder.build'):domain='semantic_table_builder'
            elif symbol.startswith('deflate.decodeRawAutoWithDictionaryFromReader'):domain='raw_caller_all_routes'
            elif symbol.startswith('deflate.'):domain='other_deflate_code'
            elif symbol.startswith('huffman.'):domain='huffman_helpers'
            if domain is not None:require(e['dso']==manifests[variant]['probe'],'Bounded DSO mismatch');selected.append({**e,'domain':domain})
        stored=json.loads(raw[name+'.bounded-samples.json']);require(stored==selected,'Independent bounded sample partition differs')
        row=bounded['cases'][case][variant];require(row['samples_sha256']==sha(raw[name+'.samples.txt']) and row['bounded_sample_count']==len(selected) and row['known_vort_api_calls']==2000 and row['sample_period']==1000,'Bounded sample receipt/source differs')
        domains=Counter();symbols=Counter();top_ips=Counter()
        for e in selected:domains[e['domain']]+=e['period'];symbols[e['symbol'].split('+')[0]]+=e['period'];top_ips[e['symbol']]+=e['period']
        require({n:v/2000 for n,v in domains.items()}==row['domains_weighted_samples_per_call'] and dict(symbols)==row['symbol_weights'],'Independent sampled-period/call estimates differ');require([[n,v/2000] for n,v in top_ips.most_common(12)]==row['top_bounded_ips_weighted_samples_per_call'],'Original top-IP period estimates differ')
        attrs=raw[name+'.events.txt'];require(all(token in attrs for token in [b'config: 0x5',b'1000',b'precise_ip: 2',b'exclude_kernel: 1',b'exclude_hv: 1',b'IP|TID|TIME|CALLCHAIN']),'Recorded physical event attributes differ')
        command=json.loads(raw[name+'.command.json']);require(command['argv']==record['argv'] and command['returncode']==0 and record['argv'][:10]==['taskset','-c','15','perf','record','-e','branch-misses:upp','-c','1000','-g'],'Recorded precise command differs')
        p=json.loads(raw[name+'.stdout.raw']);require(sha(raw[name+'.stdout.raw'])==record['report_sha256'],'Physical report hash differs');fixture=next(f for f in fixtures.values() if f['input_sha256']==p['input_sha256'] and f['encoded_sha256']==p['encoded_sha256']);check_report(p,{'fixture':fixture,'lifecycle':'cold','iterations':500},manifests[variant],None)
        offsets=set(loop['samples'][case][variant]['offsets']);count=sum(e['symbol'].split('+')[-1] in offsets and e['symbol'].startswith('deflate.semantic.linear_entry.aligned+') for e in selected);estimate=count*1000/2000
        require(count==loop['samples'][case][variant]['sample_count'] and estimate==loop['samples'][case][variant]['weighted_samples_per_vort_call'],'Copy-loop sampled-IP estimate differs');copy_samples[name]={'samples':count,'weighted_samples_per_call':estimate};totals.append({'name':name,'samples':len(ips),'bounded_samples':len(selected),'exact_user_flags':'0x4002','recorded_lost_events':0})
    byte_sequences=[];static={}
    for variant,name,expected_size,expected_stack in [('baseline','baseline-aligned.objdump.txt',3659,296),('owner-only','owner-only-aligned.objdump.txt',3649,312)]:
        rows,bytes_at=disassembly(top[name]);start=min(bytes_at);stop=max(bytes_at)+1;stack=[int(m[1],16) for a,t in rows if (m:=re.match(r'sub\s+\$0x([0-9a-f]+),%rsp',t))];require(stop-start==expected_size and stack==[expected_stack],'Original scalar text/stack observation differs')
        span=loop['baseline_range' if variant=='baseline' else 'owner_only_range'];a,b=map(lambda x:int(x,16),span);sequence=bytes(bytes_at[i] for i in range(a,b));require(len(sequence)==26 and sequence.hex()==loop['bytes'] and sha(sequence)==loop['sha256']=='dc84e82411b2f8ade64306811733d766d83514546f5b3c359786b07e53b7a743','Exact 26-byte inner-loop identity differs');byte_sequences.append(sequence);static[variant]={'text_bytes':stop-start,'stack_reservation_bytes':stack[0],'instruction_lines':len(rows)}
    require(byte_sequences[0]==byte_sequences[1] and loop['cause_proven'] is False and loop['exact_counters'] is False,'Subset loop equality silently expanded to causal/counter claim')
    require(b'<compare.decodeOnce__anon_5293>:' in top['baseline-decode-once.objdump.txt'] and b'<zstd.' in top['baseline-decode-once.objdump.txt'],'Excluded decodeOnce Zstd identity differs')
    require(sum(t['samples'] for t in totals)==9512,'Saved precise sample cardinality differs')
    return {'records':totals,'total_exact_user_samples':9512,'single_record_per_case_variant':True,'known_calls_per_record':2000,'whole_process_percentages_used':False,'complete_public_decoder_denominator':False,'sample_period_per_call_estimates_are_exact_misses':False,'scalar_static':static,'inner_loop_equal_bytes':26,'inner_loop_sha256':loop['sha256'],'whole_scalar_equivalence_claimed':False,'copy_loop_sample_estimates':copy_samples,'decode_once_5293_domain':'Zstd-excluded','raw_caller_domain':'all routes; not prep-only','cause_proven':False}


def verify(root,originals=False,git_repo=None):
    binding,archives,original_count=inventory(root,originals);containers=reused(root,binding);base,final,manifests=source_epochs(root,binding,archives,containers);fixtures,file_count,fixture_bytes=fixture_fields(root,archives,originals)
    counters=pilot(root,archives,manifests);smokes=smoke(archives,manifests,fixtures);profiles=physical(root,archives,manifests,fixtures);raw=archives['raw-diagnostics.tar.gz'];producer=json.loads(raw['producer-validation.json'])
    for n,h in producer['sha256'].items():require(sha(archives['branch-sampling.tar.gz'][n.removeprefix('branch-sampling/')] if n.startswith('branch-sampling/') else raw[n])==h,'Final producer original-byte binding differs')
    require(producer['zig_contracts']['aggregate_total']==13 and producer['zig_contracts']['exit_code']==0 and b'13/13 tests passed' in raw['unit-build.log'] and b'Ran 8 tests' in raw['unit-build.log'],'Original tool test log scope differs');require(producer['python_evidence_tests']['final']==9 and b'Ran 9 tests' in raw['final-python-gate.log'],'Post-measurement Python gate scope differs')
    baseline_git=git_verify(git_repo,BASE,base);final_git=git_verify(git_repo,binding['final_tool_commit'],final)
    return {'schema':'vort.deflate.pmu-archive-validation.v1','valid':True,'scope':'offline original byte/source/PMU/statistical/sample-record verification; no compiler, test, codec, oracle, perf or benchmark execution','cpu_affinity':sorted(os.sched_getaffinity(0)),'base_revision':BASE,'baseline_git_blobs_verified':baseline_git,'final_tool_commit':binding['final_tool_commit'],'final_tool_git_blobs_verified':final_git,'original_files_verified':original_count,'source_epochs':{'measured_common_files':10,'final_tool_files':10,'post_measurement_changes':['tools/decode/matrix.py','tools/decode/evidence_test.py'],'probe_not_rebuilt_after_marker_fix':True},'cohort_registry_files':{k:len(v['source']['sha256']) for k,v in manifests.items()},'counter_pilot':counters,'codec_smoke':smokes,'physical_profile':profiles,'fixture_tasks_verified':len(fixtures),'external_fixture_files_verified':file_count if originals else 0,'external_fixture_bytes_verified':fixture_bytes if originals else 0,'ordinary_complete_corpus_swept':False,'codec_prototypes_adopted':False,'throughput_or_industry_acceptance_claimed':False}
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--originals',action='store_true');parser.add_argument('--git-repo',type=Path);args=parser.parse_args();print(json.dumps(verify(Path(__file__).resolve().parent,args.originals,args.git_repo),indent=2))
