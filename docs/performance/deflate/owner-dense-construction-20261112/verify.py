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
BASE='cf47832821e0dce4261ab9d1cc6d56505bd121a3'
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

def sources(root,archives,containers):
    base={n.removeprefix('shared-dispatch/'):v for n,v in containers['baseline_source'].items()}
    for key in ['public_overlay','wide_overlay','holes_overlay','tools_overlay']:base.update(containers[key])
    raw=archives['raw-evidence.tar.gz'];v1=archives['source-v1.tar.gz'];v2=archives['source-v2.tar.gz'];f1=json.loads(raw['source-freeze.json']);f2=json.loads(raw['source-v2-freeze.json'])
    require(len(v1)==len(v2)==10 and {n:sha(v) for n,v in v1.items()}==f1['source_sha256'] and {n:sha(v) for n,v in v2.items()}==f2['source_sha256'],'Separate v1/v2 frozen source identity differs')
    changed=sorted(n for n in v1 if v1[n]!=v2[n]);require(changed==sorted(f2['changed_from_v1'])==['src/huffman/dense_decode_init.zig','src/huffman/dense_decode_init_tests.zig'],'V2 source changes silently widened')
    for n in ['src/deflate/semantic/decoder.zig','src/deflate/semantic/linear_entry.zig','src/huffman.zig']:require(v1[n]==v2[n]==base[n],'Original huffman/init/scalar source changed')
    helper=v2['src/huffman/dense_decode_init.zig'];test=v2['src/huffman/dense_decode_init_tests.zig'];require(b'if (comptime capacity == 0)' in helper and b'resetEmpty(destination);' in helper and b'fn resetEmpty' in helper and b'huffman.HuffmanTable(capacity){}' in test and b'if (comptime capacity != 0) try expectDecode' in test,'V2 zero-capacity/static oracle scope differs')
    failed=raw['dense-safe.log'];require(failed.count(b'error: cannot index into empty array')==2 and b'src/huffman.zig:179' in failed and b'src/huffman/dense_decode_init.zig:37' in failed,'V1 original oracle/candidate compile failure differs')
    manifests={};full={'baseline':base,'control':{**base,**v2}};probes=archives['probes-tests.tar.gz'];pf=json.loads(raw['probe-v2-freeze.json'])['probes']
    for label,source in full.items():
        m=json.loads(raw[label+'.manifest.json']);require(m['source']['revision']==BASE and {n:sha(v) for n,v in source.items()}==m['source']['sha256'] and len(source)==(2072 if label=='baseline' else 2078) and sha(json.dumps(m['source']['sha256'],sort_keys=True).encode())==m['source']['digest'],'Frozen measured v2 registry differs')
        binary=probes[label+'-compare'];require(sha(binary)==pf[label]['sha256']==m['probe_sha256'] and len(binary)==pf[label]['bytes'],'V2 new cohort probe binding differs');manifests[label]=m
    require(b'Build Summary: 7/7 steps succeeded' in raw['build.log'] and b'Build Summary: 7/7 steps succeeded' in raw['build-v2.log'],'V1/v2 original build success differs')
    require(all(v==base[n] for n,v in archives['runner-imports.tar.gz'].items()),'Immutable helper closure differs');require(sha(containers['reference_libraries']['deflate/libdeflate.so.0'])==REFERENCE,'Exact libdeflate reference differs')
    for n in ['source-freeze.json','source-v2-freeze.json','probe-v2-freeze.json','v1-validation.json','agent-static-originals.json','codegen-audit.json','producer-validation.json','independent-statistics.json']:require(raw[n]==(root/n).read_bytes(),'Readable frozen receipt differs')
    first=json.loads(raw['v1-validation.json']);require('no timing measured' in first['scope'],'V1 timing scope differs')
    for n,h in first['sha256'].items():require(sha(raw[n] if n in raw else probes[n])==h,'Original v1 artifact hash differs')
    require(sha(probes['candidate-v1-compare'])!=pf['control']['sha256'],'V1 probe silently rebound to v2')
    return base,v1,v2,manifests

def disassembly(data):
    rows=[];bytes_at={}
    for line in data.decode().splitlines():
        m=re.match(r'^\s*([0-9a-f]+):\s*((?:[0-9a-f]{2}\s+)+)\s*(.*)$',line)
        if m:
            a=int(m[1],16);values=bytes.fromhex(m[2]);bytes_at.update({a+i:v for i,v in enumerate(values)})
            if m[3]:rows.append((a,values,m[3]))
    return rows,bytes_at

def elf_sections(data):
    require(data[:6]==b'\x7fELF\x02\x01','Expected preserved little-endian ELF64 probe');offset=struct.unpack_from('<Q',data,40)[0];entry,count=struct.unpack_from('<HH',data,58)
    return [struct.unpack_from('<IIQQQQIIQQ',data,offset+i*entry) for i in range(count)]

def elf_address(data,sections,address,length):
    section=next(s for s in sections if s[3]<=address and address+length<=s[3]+s[5]);offset=section[4]+address-section[3];return data[offset:offset+length]

def caller_symbol(data,sections):
    found=[]
    for section in sections:
        if section[1]!=2:continue
        text=sections[section[6]];names=data[text[4]:text[4]+text[5]]
        for offset in range(section[4],section[4]+section[5],section[9]):
            s=struct.unpack_from('<IBBHQQ',data,offset);end=names.find(b'\0',s[0]);name=names[s[0]:end].decode()
            if name.startswith('deflate.decodeRawAutoWithDictionaryFromReader'):found.append((name,s[4],s[5]))
    require(len(found)==1,'Caller symbol selection ambiguous');return found[0]

def static_audit(archives,binding,containers,originals):
    raw=archives['raw-evidence.tar.gz'];audit=json.loads(raw['codegen-audit.json']);origin=json.loads(raw['agent-static-originals.json']);artifacts=archives['agent-static-originals.tar.gz'];probes=archives['probes-tests.tar.gz']
    require('original tool files retained' in audit['authorship'] and 'exact original agent tool artifact bytes' in origin['scope'],'Original-agent/main-derived provenance differs')
    # Adapt names locally; the original main JSON bytes are never changed.
    audit={**audit,'control_sha256':audit['dense_v2_sha256'],'control_scalar_range':audit['dense_scalar_range'],'stack_reservation_bytes':audit['stack_bytes'],'static_instructions_including_padding':audit['instructions_static'],'conditional_jumps':audit['cond_jumps'],'negative_rbp_operand_refs':audit['negative_rbp_references'],'different_symbol_bytes':audit['raw_byte_differences'],'nonrelocation_byte_differences':audit['nonrelocation_byte_differences'],'direct_function_relative_branch_targets_match':audit['direct_branch_relative_targets_match'],'jump_table_function_relative_targets':audit['jump_table_relative_targets'],'helper_bodies_compared':audit['all_helper_bodies_compared'],'source_scalar_bytes_retained':True}
    masked=[];raw_codes=[];branches=[];results={};callers=[]
    for index,label in enumerate(['baseline','control']):
        artifact_name='baseline.txt' if label=='baseline' else 'dense-v2.txt';artifact=artifacts[artifact_name];record=origin['files'][artifact_name];require(sha(artifact)==record['sha256'],'Original agent copied artifact differs')
        if originals:require(Path(record['source']).read_bytes()==artifact,'Original agent tool source artifact differs')
        rows,bytes_at=disassembly(artifact);start,stop=map(lambda x:int(x,16),audit[label+'_scalar_range']);code=bytes(bytes_at[i] for i in range(start,stop));normalized=bytearray(code);counts={'call_rel32':0,'rip_disp32':0};direct=[]
        for address,values,text in rows:
            if text.startswith('call') and values[0]==0xe8:require(len(values)==5,'Unexpected rel32 call');normalized[address-start+1:address-start+5]=bytes(4);counts['call_rel32']+=1
            elif '(%rip)' in text:require(text.startswith('lea') and len(values)==7,'Unexpected RIP-displacement form');normalized[address-start+len(values)-4:address-start+len(values)]=bytes(4);counts['rip_disp32']+=1
            match=re.match(r'^(j\w+)\s+([0-9a-f]+)\s+<',text)
            if match:direct.append((address-start,match[1],int(match[2],16)-start))
        stack=[int(m[1],16) for a,v,t in rows if (m:=re.match(r'sub\s+\$0x([0-9a-f]+),%rsp',t))];pushes=sum(t.startswith('push') for a,v,t in rows);jcc=sum(t.split()[0].startswith('j') and t.split()[0]!='jmp' for a,v,t in rows);jmp=sum(t.split()[0]=='jmp' for a,v,t in rows);rbp=sum(bool(re.search(r'-0x[0-9a-f]+\(%rbp\)',t)) for a,v,t in rows)
        require(len(code)==audit['symbol_bytes'][index]==3659 and len(rows)==audit['static_instructions_including_padding'][index]==897 and stack==[audit['stack_reservation_bytes'][index]]==[296] and pushes==6 and jcc==audit['conditional_jumps'][index]==90 and jmp==audit['jmp'][index]==43 and rbp==audit['negative_rbp_operand_refs'][index]==131 and counts==audit['masked_fields']=={'call_rel32':8,'rip_disp32':17},'Independent whole-scalar static counters differ')
        binary=probes[label+'-compare'];require(sha(binary)==audit[label+'_sha256'],'Static original probe binding differs');sections=elf_sections(binary);require(elf_address(binary,sections,start,len(code))==code,'Original disassembly bytes differ from probe ELF')
        wanted=bytes.fromhex(audit['jump_table_raw_words'][index]);candidates=[]
        for a,values,text in rows:
            m=re.search(r'# ([0-9a-f]+) <',text)
            if '(%rip)' in text and m and elf_address(binary,sections,int(m[1],16),16)==wanted:candidates.append(int(m[1],16))
        require(len(candidates)==1,'Actual jump table selection ambiguous');address=candidates[0];targets=[address+v-start for v in struct.unpack('<4i',elf_address(binary,sections,address,16))];require(targets==list(map(lambda x:int(x,16),audit['jump_table_function_relative_targets']))==[0x931,0x8c0,0x950,0xccc],'Actual four jump-table targets differ')
        name,address,size=caller_symbol(binary,sections);prologue=elf_address(binary,sections,address,40);location=prologue.find(b'\x48\x81\xec');require(location>=0,'Caller stack prologue missing');reservation=struct.unpack_from('<I',prologue,location+3)[0];require(size==audit['caller_bytes'][index] and reservation==audit['caller_stack_bytes'][index],'Derived caller text/stack scope differs');callers.append({'symbol':name,'text_bytes':size,'stack_reservation_bytes':reservation,'scope':'all caller routes; helpers/body equivalence not established'})
        masked.append(normalized);raw_codes.append(code);branches.append(direct);results[label]={'text_bytes':len(code),'stack_bytes':296,'instructions_with_padding':897,'jcc':jcc,'jmp':jmp,'negative_rbp_references':rbp,'masked_fields':counts,'jump_table_relative_targets':[hex(v) for v in targets]}
    require(sum(a!=b for a,b in zip(*raw_codes))==audit['different_symbol_bytes']==43 and masked[0]==masked[1] and branches[0]==branches[1] and audit['nonrelocation_byte_differences']==0 and audit['direct_function_relative_branch_targets_match'] is True,'Normalized scalar/self-branch equality differs')
    require(audit['helper_bodies_compared'] is False and audit['source_scalar_bytes_retained'] is True,'Normalized mask scope silently widened')
    prior=json.loads(containers['previous_owner_audit']['codegen-audit.json']);require(prior['caller_bytes'][1]==audit['previous_owner_caller_bytes']==39054 and prior['caller_stack_bytes'][1]==audit['previous_owner_caller_stack_bytes']==82168,'Prior committed owner-control caller scope differs')
    require(audit['whole_operation_cause_proven'] is False,'Scalar mask equality expanded to causal claim')
    return {'raw_authorship':'two exact original agent tool artifacts; main summary separately derived','scalar':results,'unmasked_different_bytes':43,'nonrelocation_different_bytes':0,'normalized_scalar_sha256':sha(masked[0]),'direct_relative_branches_match':True,'caller':callers,'helper_bodies_fully_compared':False,'whole_binary_or_timing_equal_claimed':False}

def fixed_bootstrap(rows):
    rng=random.Random(0x20261112);logs=[list(map(math.log,r)) for r in rows];gm=math.exp(statistics.mean(statistics.mean(r) for r in logs));samples=[]
    for _ in range(2000):samples.append(math.exp(statistics.mean(statistics.mean([rng.choice(r[::2]) for _ in range(2)]+[rng.choice(r[1::2]) for _ in range(2)]) for r in logs)))
    samples.sort();return gm,[samples[50],samples[1949]]

def measurements(root,archives,manifests,fixtures):
    raw=archives['raw-evidence.tar.gz'];rows=archives['rows.tar.gz'];events=json.loads(raw['events.json']);protocol=json.loads(raw['protocol.json']);summary=json.loads(raw['summary.json']);ind=json.loads(raw['independent-statistics.json']);validation=json.loads(raw['validation.json'])
    require(len(events)==160 and ind['events']==160 and ind['ordinary_wall_events']==96 and ind['pmu_events']==64 and ind['source_events_sha256']==sha(raw['events.json']) and ind['adopted'] is False,'Terminal independent event/scope binding differs')
    require(validation['event_count']==160 and validation['raw_measured_pairs']==320 and validation['counter_event_count']==64 and validation['compiler_observations']==0 and validation['scalar_source_retained'] is True and protocol['variants']==['baseline','control'] and len(protocol['tasks'])==12 and protocol['process_sweeps']==4,'Terminal protocol scope differs')
    table={};speed_rows={};reads=0
    for task in protocol['tasks']:
        f=task['fixture'];key='deflate_'+f['name']+'_'+f['size']+'_'+str(f['level'])+'_cold';require(f==fixtures[f['key']],'Protocol fixture differs')
        for mode in protocol['modes'] if key in protocol['pmu_keys'] else [None]:
            label=mode or 'wall-time'
            for sweep in range(4):
                subset=[e for e in events if e['key']==key and e['mode']==mode and e['sweep']==sweep];require([e['variant'] for e in subset]==(['baseline','control'] if sweep%2==0 else ['control','baseline']),'Balanced process ordering differs')
                for e in subset:
                    variant=e['variant'];stem=f'{key}.{label}.{sweep}.{variant}';require(json.loads(rows[stem+'.json'])==e and json.loads(rows[stem+'.stdout.raw'])==e['probe'] and rows[stem+'.stderr.raw']==b'','Raw process event/probe differs')
                    require(json.loads(rows[stem+'.process.json'])=={'returncode':0,'argv':e['argv'],'before':e['before'],'after':e['after']} and not e['before']['compilers'] and not e['after']['compilers'],'Process exit/compiler observations differ')
                    require(e['task']==task and e['probe']['warmup']==2 and e['argv'][:3]==['taskset','-c','15'] and e['argv'][3]==manifests[variant]['probe'] and e['probe']['provenance']['command']==' '.join(e['argv'][3:]),'Recorded command/source task differs');reads+=check_report(e['probe'],task,manifests[variant],mode);table[key,mode,sweep,variant]=e
            for variant in ['baseline','control']:
                batches=[p for sweep in range(4) for p in table[key,mode,sweep,variant]['probe']['pairs']];d=summary[key][label][variant];require(d['processes']==4 and d['measured_batches']==8,'Median process count differs');close(d['wall_ns_per_call_median'],statistics.median(p['vort_ns']/task['iterations'] for p in batches),'Raw wall median differs')
                if mode:
                    for field in ['cycles','instructions','third_event']:close(d[field+'_per_call_median'],statistics.median(p['vort_counters'][field]/task['iterations'] for p in batches),'Counter per-call median differs')
                    close(d['ipc_per_batch_median'],statistics.median(p['vort_counters']['instructions']/p['vort_counters']['cycles'] for p in batches),'IPC median differs')
            if mode is None:
                ratios=[statistics.median(p['vort_ns'] for p in table[key,mode,sweep,'baseline']['probe']['pairs'])/statistics.median(p['vort_ns'] for p in table[key,mode,sweep,'control']['probe']['pairs']) for sweep in range(4)];gm=math.exp(statistics.mean(map(math.log,ratios)));close(ind['rows'][key]['paired_speed_ratios'],ratios,'Independent ordinary raw ratios differ');close(ind['rows'][key]['speed_geomean'],gm,'Independent row GM differs');speed_rows[key]=ratios
            else:
                for field in ['cycles','instructions','third_event']:
                    ratios=[statistics.median(metric_values(table[key,mode,sweep,'control'],field))/statistics.median(metric_values(table[key,mode,sweep,'baseline'],field)) for sweep in range(4)];d=ind['pmu'][key+'_'+mode][field];close(d['paired_ratios'],ratios,'Independent PMU raw ratios differ');close(d['candidate_over_baseline_geomean'],math.exp(statistics.mean(map(math.log,ratios))),'Independent PMU GM differs')
    gm,ci=fixed_bootstrap(list(speed_rows.values()));close(ind['ordinary_speed_geomean'],gm,'Independent aggregate GM differs');close(ind['speed_ci95'],ci,'Independent fixed-row bootstrap differs');weak=min((math.exp(statistics.mean(map(math.log,v))),k) for k,v in speed_rows.items());close(ind['weakest'],list(weak),'Weakest row differs');close(ind['target_reymont64K_L6'],math.exp(statistics.mean(map(math.log,speed_rows['deflate_reymont_65536_6_cold']))),'Target row differs')
    require(gm<1.03 and ind['dedicated_host_acceptance'] is False and reads==256,'No-adoption/counter scope differs')
    return {'events':160,'ordinary_wall_events':96,'pmu_events':64,'measured_pairs':320,'warmup_pairs':320,'raw_pmu_reads':256,'ordinary_geomean':gm,'ci95':ci,'weakest':list(weak),'target':ind['target_reymont64K_L6'],'bootstrap_resamples':2000,'adopted':False,'pmu_wall_times_are_acceptance':False}

def fixture_registry(root,binding,originals):
    path=root/'fixture-replay-bindings.json';require(sha(path.read_bytes())==binding['fixture_descriptor_reuse']['sha256'],'Existing ordinary fixture descriptor differs');d=json.loads(path.read_bytes());fixtures={f['key']:f for f in d['fixtures']};require(len(fixtures)==72 and len(d['files'])==108,'Existing72-wire scope differs')
    if originals:
        for n,r in d['files'].items():b=Path(n).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'],'Original frozen ordinary input differs')
    return fixtures

def wire_smoke(archives,manifests,fixtures):
    raw=archives['smoke.tar.gz'];m=json.loads(raw['manifest.json']);require(m['source']==manifests['control']['source'] and m['probe_sha256']==manifests['control']['probe_sha256'],'Smoke source/probe epoch differs');events=json.loads(raw['events.json']);require(len(events)==72 and {e['task']['fixture']['key'] for e in events}==set(fixtures),'72-wire coverage differs')
    for e in events:
        t=e['task'];f=fixtures[t['fixture']['key']];key='deflate_'+f['name']+'_'+f['size']+'_'+str(f['level'])+'_cold';require(t=={'fixture':f,'lifecycle':'cold','iterations':1} and e['returncode']==0 and json.loads(raw[key+'.json'])==e and json.loads(raw[key+'.stdout.raw'])==e['probe'] and raw[key+'.stderr.raw']==b'' and e['probe']['warmup']==0 and not e['before']['compilers'] and not e['after']['compilers'],'Wire smoke event/exit/source scope differs');check_report(e['probe'],t,m,None)
    require(json.loads(raw['validation.json'])=={'events':72,'full_output':True,'exact_consumption':True,'guards':True,'input_immutable':True,'times_not_performance_evidence':True},'Smoke completion scope differs')
    return {'wires':72,'full_output_exact_consumption_guards_immutable_input':True,'timings_are_performance_evidence':False}

def verify(root,originals=False,git_repo=None):
    binding,archives,count=inventory(root,originals);containers=reused(root,binding);base,v1,v2,manifests=sources(root,archives,containers);raw=archives['raw-evidence.tar.gz'];producer=json.loads(raw['producer-validation.json'])
    for n,h in producer['sha256'].items():require(sha(archives['smoke.tar.gz']['validation.json'] if n=='smoke/validation.json' else raw[n])==h,'Final producer original-byte binding differs')
    tests={n:successful_tests(raw[n],number) for n,number in [('dense-safe-v2.log',90),('dense-x86-v2.log',90),('owner-safe-v2.log',96),('full-safe-v2.log',738),('owner-safe.log',96),('full-safe.log',738)]}
    require(tests['dense-safe-v2.log']['named_tests']==tests['dense-x86-v2.log']['named_tests']==88 and tests['dense-safe-v2.log']['anonymous_import_tests']==2,'Dense90 log classification differs')
    require(tests['owner-safe-v2.log']['named_tests']==94 and tests['owner-safe-v2.log']['anonymous_import_tests']==2,'Owner96 log classification differs')
    require(len(re.findall(rb'^test "',v2['src/huffman/dense_decode_init_tests.zig'],re.M))==6 and raw['dense-safe-v2.log'].count(b'dense_decode_init_tests.test.')==6 and raw['owner-safe-v2.log'].count(b'mapped_owner_tests.test.')==8,'Focused new test-declaration count differs')
    require(b'dense_decode_init_tests.test.' not in raw['full-safe-v2.log'] and b'mapped_owner_tests.test.' not in raw['full-safe-v2.log'],'Full Deflate root scope differs')
    require(producer['runtime_allocation_probe_performed'] is False and producer['v2_tests']['exit_codes']==0 and producer['measured_events']==160,'Test/allocation/measurement scope differs')
    fixtures=fixture_registry(root,binding,originals);metrics=measurements(root,archives,manifests,fixtures);smoke=wire_smoke(archives,manifests,fixtures);static=static_audit(archives,binding,containers,originals);git=git_verify(git_repo,BASE,base)
    return {'schema':'vort.deflate.owner-dense-archive-validation.v1','valid':True,'scope':'offline original byte/source/static mask/self-target/recorded-test/statistics/smoke verification; no compiler,test,codec,oracle,perf or benchmark execution','cpu_affinity':sorted(os.sched_getaffinity(0)),'base_revision':BASE,'baseline_git_blobs_verified':git,'source_registry_files':{'baseline':2072,'v2_control':2078},'source_epochs':{'v1_files':10,'v2_files':10,'only_v2_changes':['dense_decode_init.zig','dense_decode_init_tests.zig'],'v1_zero_capacity_failure':'old oracle and candidate empty-array indexing; no timing reused','original_huffman_init_decoder_entry_bytes_unchanged':True},'original_files_verified':count,'tests':tests,'new_dense_test_declarations':6,'new_owner_test_declarations':8,'runtime_allocation_probe_performed':False,'measurements':metrics,'smoke':smoke,'static_audit':static,'external_original_fixture_files_verified':108 if originals else 0,'ordinary_fixture_bytes_duplicated':False,'helper_owner_core_adopted':False}
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--originals',action='store_true');parser.add_argument('--git-repo',type=Path);a=parser.parse_args();print(json.dumps(verify(Path(__file__).resolve().parent,a.originals,a.git_repo),indent=2))
