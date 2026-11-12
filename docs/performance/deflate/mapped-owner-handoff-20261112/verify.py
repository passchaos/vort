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
import statistics
import subprocess
import tarfile
BASE='7aaa936142aafdebe8351962e8c49059571d42c5'
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
        containers[key]=unpack(path,links=(key=='reference_library'))
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

def validate_child(event,raw,key,fixture,manifest,iterations,warmup,expected_probe):
    require(event['returncode']==0 and raw[key+'.stderr.raw']==b'','Child exit/stderr differs')
    p=json.loads(raw[key+'.stdout.raw']);require(p==event['probe'],'Raw child report/event differs')
    require(p['schema']=='vort.decode-compare.v1' and p['codec']=='deflate' and p['lifecycle']=='cold' and p['lifecycle_match']=='matched-cold','Child public lifecycle differs')
    require(p['vort_api']=='decodeRawDeflate' and p['reference_api']=='libdeflate_alloc_decompressor+libdeflate_deflate_decompress_ex+libdeflate_free_decompressor','Child API lifecycle differs')
    require(p['iterations']==iterations and p['rounds']==2 and p['warmup']==warmup,'Child counts differ')
    for field in ['input_path','encoded_input_path','input_bytes','encoded_bytes','input_sha256']:
        require(p[field]==fixture[field],'Child fixture '+field+' differs')
    require(p['encoded_sha256']==fixture['encoded_sha256'],'Child wire differs')
    reference=manifest['references']['deflate']
    require(p['reference_version']==reference['version']=='1.26' and p['reference_version_origin']=='declared-pinned-header' and p['reference_paths']==[reference['path']],'Child reference differs')
    require({n for n in p['loaded_shared_library_paths'] if Path(n).name.startswith('libdeflate.so')}=={reference['path']},'Child loaded reference differs')
    require(p['exact_consumption']=={'vort':True,'reference':True} and all(p['validation'][n] is True for n in ['every_iteration_count','full_output_per_batch','guards_per_batch','input_unchanged_per_batch','exact_consumption_per_batch']),'Child content/count/guards/consumption differs')
    require(p['alignment']=={'guard_bytes':64,'input_mod64':0,'encoded_mod64':0,'vort_output_mod64':0,'reference_output_mod64':0},'Child alignment differs')
    provenance=p['provenance'];require(provenance['executable_sha256']==expected_probe and provenance['optimize']=='ReleaseFast' and provenance['zig_version']=='0.16.0' and provenance['target_cpu']=='skylake+pku+sgx' and provenance['cpu_affinity']=='15' and provenance['benchmark_threads']==provenance['affinity_cpu_count']==1,'Child source/build/CPU/thread differs')
    argv=['taskset','-c','15',manifest['probe'],'--codec','deflate','--input',fixture['input_path'],'--encoded-input',fixture['encoded_input_path'],'--iterations',str(iterations),'--rounds','2','--warmup',str(warmup),'--lifecycle','cold','--reference',reference['path'],'--reference-version','1.26']
    require(event['argv']==argv and provenance['command']==' '.join(argv[3:]),'Child command differs')
    for field,start,count in [('warmup_pairs',0,warmup),('pairs',warmup,2)]:
        require(len(p[field])==count,'Child paired count differs')
        for i,pair in enumerate(p[field]):require(pair['pair_id']==start+i and pair['first']==('vort' if i%2==0 else 'reference') and pair['vort_mix']==pair['reference_mix']==iterations*(fixture['input_bytes']+fixture['input_first_byte']),'Child pair order/returned count differs')
    for side in ['vort','reference']:require(p['summary'][side+'_median_ns']==statistics.median(pair[side+'_ns'] for pair in p['pairs']),'Child raw median differs')
    return p


def baseline_and_epochs(root,binding,archives,containers):
    base={n.removeprefix('shared-dispatch/'):b for n,b in containers['baseline_source'].items()}
    for key in ['public_linear_overlay','wide_boundary_overlay','distance_holes_overlay']:base.update(containers[key])
    screen=archives['screen-raw.tar.gz'];manifests={label:json.loads(screen[label+'.manifest.json']) for label in ['baseline','owner-word','owner-only']}
    require(len(base)==2069 and {n:sha(b) for n,b in base.items()}==manifests['baseline']['source']['sha256'],'Reused immutable baseline source differs')
    require(sha(containers['baseline_binary']['after-compare'])==PROBE,'Reused baseline probe differs')
    require(sha(containers['reference_library']['deflate/libdeflate.so.0'])==REFERENCE,'Exact libdeflate reference differs')
    raw=archives['raw-validation.tar.gz'];epochs={}
    for directory,receipt,count in [('timing-source','timing-freeze.json',7),('handoff-v1-source','handoff-v1-freeze.json',9),('handoff-v2-source','handoff-v2-source.json',9),('owner-only-source','owner-only-source.json',5)]:
        overlay=archives[directory+'-overlay.tar.gz'];frozen=json.loads(raw[receipt]);require(len(overlay)==count and {n:sha(b) for n,b in overlay.items()}==frozen['source_sha256'],'Frozen source epoch differs: '+directory);epochs[directory]=overlay
        require(raw[receipt]==(root/receipt).read_bytes(),'Readable source receipt differs')
    production=['src/deflate.zig','src/deflate/semantic/decoder.zig','src/deflate/semantic/linear_entry.zig','src/deflate/semantic/mapped_owner.zig','src/deflate/semantic/mapped_match_word.zig']
    for epoch in ['handoff-v1-source','handoff-v2-source']:
        require(all(epochs[epoch][n]==epochs['timing-source'][n] for n in production),'Timing production silently rebound to later tests')
    v1=epochs['handoff-v1-source'];v2=epochs['handoff-v2-source'];test='src/deflate/semantic/mapped_handoff_tests.zig'
    require(all(v1[n]==v2[n] for n in v1 if n!=test),'V2 changes beyond one corrected test module')
    corrected=v2[test].replace(b'            // The compact tail scans missing codes through width 15. A short\n            // unpadded suffix cannot finish that scan and preserves truncation.\n',b'')
    corrected=corrected.replace(b'if (!padded and width < 15) error.TruncatedFrame else error.InvalidHuffmanCode',b'error.InvalidHuffmanCode').replace(b'if (padded) error.InvalidHuffmanCode else error.TruncatedFrame',b'error.InvalidHuffmanCode')
    require(corrected==v1[test],'V2 fixture correction changes wire production or executor')
    owner=epochs['owner-only-source'];require(all(owner[n]==epochs['timing-source'][n] for n in production if n!='src/deflate.zig'),'Owner-only control changes shared production')
    scalar=epochs['timing-source']['src/deflate.zig'].replace(b'.decodeMappedBuffered(reader, output, out_offset, borrow)',b'.decodeBuffered(reader, output, out_offset, decoder)')
    require(scalar==owner['src/deflate.zig'],'Owner-only facade difference exceeds entry selection')
    sources={'baseline':base,'owner-word':{**base,**v2},'owner-only':{**base,**owner}}
    expected={'baseline':(2069,PROBE),'owner-word':(2075,OWNER_WORD),'owner-only':(2071,OWNER_ONLY)}
    for label,source in sources.items():
        m=manifests[label];count,probe=expected[label]
        require(m['source']['revision']==BASE and len(source)==count and {n:sha(b) for n,b in source.items()}==m['source']['sha256'] and sha(json.dumps(m['source']['sha256'],sort_keys=True).encode())==m['source']['digest'],'Captured complete source registry differs: '+label)
        require(m['probe_sha256']==probe,'Variant captured probe differs')
    imports=archives['runner-imports.tar.gz']
    require(all(b==base[n] for n,b in imports.items()),'Frozen runner import closure differs from baseline Git source')
    prior=binding['prior_fixture_manifest'];path=root.parents[3]/prior['archive']['path'];require(sha(path.read_bytes())==prior['archive']['sha256'],'Prior fixture manifest container differs')
    previous=unpack(path)[prior['member']];require(sha(previous)==prior['sha256']==json.loads(screen['protocol.json'])['prior_fixture_manifest_sha256'],'Original seed manifest bytes differ')
    for n in ['distance-hole-existing9.deflate','distance-hole-existing10.deflate','distance-hole-missing10.deflate']:
        require(containers['small_fixtures']['repo-testdata/'+n]==base['src/deflate/semantic/testdata/'+n],'Reused tiny fixture bytes differ')
    return base,epochs,manifests

def test_epochs(root,archives,epochs):
    raw=archives['raw-validation.tar.gz'];binaries=archives['retained-probes-tests.tar.gz'];producer=json.loads(raw['producer-validation.json']);v1=json.loads(raw['handoff-v1-freeze.json'])
    require(sha(raw['producer-validation.json'])=='a7e2374c6875aeda19ed7315606503fd1edc969c135489dd951ea25bfd60920a' and raw['producer-validation.json']==(root/'producer-validation.json').read_bytes(),'Final producer receipt bytes differ')
    for n,h in v1['files'].items():require(sha(raw[n] if n in raw else binaries[n])==h,'Original failed-epoch file binding differs')
    failures={}
    for n in ['handoff-safe.log','handoff-debug.log']:
        text=raw[n].decode();rows=re.findall(r'^(\d+)/(\d+) (.*?)\.\.\.(.*?)(?=^\d+/\d+ |\Z)',text,re.M|re.S)
        require(len(rows)==105 and [int(r[0]) for r in rows]==list(range(1,106)) and text.count('expected error.InvalidHuffmanCode, found error.TruncatedFrame')==2 and '103 passed; 0 skipped; 2 failed.' in text,'Original 103/105 failed tests differ')
        failures[n]={'reported_passed':103,'reported_failed':2,'error':'wanted InvalidHuffmanCode; old scalar returned TruncatedFrame'}
    require(b'import of file outside module path' in raw['owner-safe.log'],'Excluded initial constructor import error absent')
    successful={}
    for n,count in [('handoff-safe-v2.log',105),('handoff-debug-v2.log',105),('handoff-x86-v2.log',105),('owner-safe-v2.log',11),('public-safe.log',8),('holes-safe.log',10),('full-safe.log',738)]:
        successful[n]=successful_tests(raw[n],count)
    for n in ['handoff-safe-v2.log','handoff-debug-v2.log','handoff-x86-v2.log']:require(successful[n]['anonymous_import_tests']==2 and successful[n]['named_tests']==103,'Corrected shim aggregate/import classification differs')
    modules={'mapped_owner_tests':8,'mapped_handoff_tests':6,'mapped_full_width_tests':3}
    text=raw['handoff-safe-v2.log'].decode()
    for module,count in modules.items():
        source=epochs['handoff-v2-source']['src/deflate/semantic/'+module+'.zig'];require(len(re.findall(rb'^test "',source,re.M))==count and len(re.findall(r'^\d+/105 deflate\.semantic\.'+module+r'\.test\.',text,re.M))==count,'New test-declaration count differs')
    require(producer['new_test_decl_counts']==modules and not any(m.encode() in raw['full-safe.log'] for m in modules),'Full Deflate root silently includes shim tests')
    wasm=producer['tests']['wasm32_wasi_ReleaseSafe'];require(wasm['exit_code']==0 and wasm['runtime_tested'] is False and raw[wasm['log']]==b'' and '-fno-emit-bin' in wasm['command'],'WASI compile/runtime scope differs')
    for n,h in producer['sha256'].items():require(sha(raw[n] if n in raw else binaries[n])==h,'Producer frozen file hash differs')
    require(sha(binaries['candidate-compare'])==OWNER_WORD and sha(binaries['owner-only-compare'])==OWNER_ONLY,'Prototype probe identity differs')
    require(json.loads(raw['timing-freeze.json'])['probe_sha256']==OWNER_WORD and 'both variants rejected' in producer['adoption'],'Original timing identity or final adoption differs')
    require(producer['performance']['events']==192 and producer['performance']['process_pairs']==96 and producer['performance']['raw_measured_vort_reference_pairs']==producer['performance']['raw_warmup_vort_reference_pairs']==384,'Producer pair-count scope differs')
    return {'original_failed':failures,'corrected_and_supporting_runs':successful,'new_test_declarations':modules,'new_test_declarations_total':17,'full_deflate_shim_tests':0,'wasi_compiled_only':True,'wasi_runtime_tested':False,'full_safe_exit_handle_observation':'terminal log and producer observation; old unified handle unavailable'}

def instructions(data):
    rows=[];byte_rows=[]
    for line in data.decode().splitlines():
        m=re.match(r'^\s*([0-9a-f]+):\s*((?:[0-9a-f]{2}\s+)+)\s*(.*)$',line)
        if m:
            address=int(m[1],16);count=len(m[2].split());byte_rows.append((address,count))
            if m[3]:rows.append((address,m[3]))
    return rows,byte_rows

def static_audit(root,archives):
    raw=archives['raw-static-audit.tar.gz'];audit=json.loads(raw['codegen-audit.json'])
    require(sha(raw['codegen-audit.json'])=='cbd115ee7fa00cd651135e228c1ff6b0d583e8ddde6b809a98407c0a05d97b34' and raw['codegen-audit.json']==(root/'codegen-audit.json').read_bytes(),'Original static audit receipt differs')
    require('raw disassembly newly recaptured by main on CPU0' in audit['authorship'],'Static recapture authorship differs')
    for n,h in audit['raw_sha256'].items():require(sha(raw[n])==h,'Raw nm/objdump identity differs')
    parsed={}
    for key,name,probe in [('baseline','baseline-aligned.objdump.txt',PROBE),('owner_word','candidate-mapped.objdump.txt',OWNER_WORD)]:
        r=audit[key];rows,byte_rows=instructions(raw[name]);start=int(r['start'],16);stop=int(r['stop'],16)
        require(r['sha256']==probe and stop-start==r['symbol_bytes'] and min(a for a,n in byte_rows)==start and max(a+n for a,n in byte_rows)==stop,'Static symbol byte range/probe differs')
        pushes=sum(t.startswith('push') for a,t in rows);rbp=sum(bool(re.search(r'-0x[0-9a-f]+\(%rbp\)',t)) for a,t in rows)
        stacks=[int(m.group(1),16) for a,t in rows if (m:=re.match(r'sub\s+\$0x([0-9a-f]+),%rsp',t))]
        counts=[sum(t.split()[0]==op for a,t in rows) for op in ['shrx','shlx','bzhi','call']]
        require(len(rows)==r['static_instruction_lines_including_padding'] and pushes==r['pushes'] and rbp==r['negative_rbp_operand_references'] and stacks==[r['local_stack_reservation_bytes']] and counts==r['shrx_shlx_bzhi_call_sites'],'Independent static counters differ')
        parsed[key]={'symbol_bytes':stop-start,'stack_reservation_bytes':stacks[0],'pushes':pushes,'instruction_lines':len(rows),'negative_rbp_references':rbp,'static_shift_call_sites':counts}
    nm=raw['candidate.nm.txt'].decode();symbol=audit['owner_word']['symbol'];require(re.search(r'^0*113fe80\s+0*e91\s+[tT]\s+'+re.escape(symbol)+r'$',nm,re.M),'Mapped symbol nm size/address differs')
    require(not re.search(r'\sdeflate\.semantic\.linear_entry\.aligned$',nm,re.M),'Candidate unexpectedly emits private old full-width symbol')
    rows,_=instructions(raw['candidate-mapped.objdump.txt']);ops={a:t for a,t in rows}
    for address in audit['post_refill_length_from_cl']:require('%cl,' in ops[int(address,16)],'Separately live normalized length not present in original disassembly')
    require('%edx,%r8d' in ops[int(audit['post_refill_distance_from_word'],16)] and 'two values' in audit['live_copy_state'],'Packed word versus normalized length scope differs')
    require(parsed['owner_word']['symbol_bytes']-parsed['baseline']['symbol_bytes']==70 and parsed['owner_word']['stack_reservation_bytes']-parsed['baseline']['stack_reservation_bytes']==16,'Whole-symbol text/stack deltas differ')
    return {'raw_capture':'new main CPU0 nm/objdump capture','parsed':parsed,'text_delta_bytes':70,'stack_delta_bytes':16,'carried_match_values':2,'single_carried_value_proven':False,'runtime_spill_reduction_proven':False,'private_full_width_correctness_from_candidate_disassembly':False}

def fixture_descriptors(root,binding,originals):
    d=json.loads((root/'fixture-replay-bindings.json').read_bytes());reference=binding['fixture_descriptor_reuse'];require(sha((root/'fixture-replay-bindings.json').read_bytes())==reference['sha256'],'Reused ordinary fixture descriptor bytes differ')
    fixtures={f['key']:f for f in d['fixtures']};require(len(fixtures)==72 and len(d['files'])==108 and sum(r['bytes'] for r in d['files'].values())==371820359,'Ordinary fixture inventory differs')
    for f in fixtures.values():
        for n,h,bn in [('input_path','input_sha256','input_bytes'),('encoded_input_path','encoded_sha256','encoded_bytes')]:require(d['files'][f[n]]=={'sha256':f[h],'bytes':f[bn]},'Fixture descriptor binding differs')
    if originals:
        for n,r in d['files'].items():
            b=Path(n).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'],'External original fixture differs')
    return fixtures

def bootstrap_ratios(rows):
    rng=random.Random(0x20261112);logs=[[math.log(v) for v in row] for row in rows];center=math.exp(statistics.mean(statistics.mean(row) for row in logs));samples=[]
    for _ in range(2000):
        means=[]
        for row in logs:
            ab=row[::2];ba=row[1::2];draw=[rng.choice(ab) for _ in ab]+[rng.choice(ba) for _ in ba];means.append(statistics.mean(draw))
        samples.append(math.exp(statistics.mean(means)))
    samples.sort();return center,[samples[50],samples[1949]]

def screen_and_smoke(root,archives,manifests,fixtures):
    raw=archives['screen-raw.tar.gz'];smoke=archives['smoke-raw.tar.gz'];events=json.loads(raw['events.json']);protocol=json.loads(raw['protocol.json']);summary=json.loads(raw['summary.json']);independent=json.loads(archives['raw-validation.tar.gz']['independent-statistics.json'])
    require(sha(archives['raw-validation.tar.gz']['independent-statistics.json'])=='3c10d3fd09f9f63a41a6dffbf4020d66e22f845d1c121cf1a38cc4a692937c5c' and archives['raw-validation.tar.gz']['independent-statistics.json']==(root/'independent-statistics.json').read_bytes(),'Final independent statistics bytes differ')
    require(len(events)==192 and independent['event_count']==192 and independent['events_sha256']==sha(raw['events.json']),'Terminal screen event identity differs')
    require(protocol['variants']==['baseline','owner-word','owner-only'] and protocol['process_pairs_per_variant']==4 and protocol['sample_rounds_per_process']==2 and len(protocol['tasks'])==12,'Screen protocol counts differ')
    require(protocol['gates']=={'target_speed_min':1.2,'controls_speed_min':0.98,'aggregate_speed_min':1.03},'Protocol target/control gates differ')
    tasks={f"deflate_{t['fixture']['name']}_{t['fixture']['size']}_{t['fixture']['level']}_cold":t for t in protocol['tasks']}
    require(set(tasks)=={e['key'] for e in events},'Selected row coverage differs')
    computed={};loads=[];compiler_count=0
    for variant in ['owner-word','owner-only']:
        ratios_by_row={};geomeans={}
        for key,task in tasks.items():
            fixture=fixtures[task['fixture']['key']];require(task['fixture']==fixture and task['iterations']==(500 if fixture['size']=='65536' else 100) and task['lifecycle']=='cold','Selected task input/iterations differs')
            row=[e for e in events if e['key']==key and e['variant']==variant];require(len(row)==8,'Incomplete row/variant process events');ratios=[]
            for outer in range(4):
                pair=row[outer*2:outer*2+2];order=['baseline',variant] if outer%2==0 else [variant,'baseline'];require([e['label'] for e in pair]==order and all(e['pair']==outer for e in pair),'AB/BA process order differs');medians={}
                for event in pair:
                    stem=f"{key}.{variant}.{outer}.{event['label']}";require(json.loads(raw[stem+'.json'])==event,'Original per-process event differs')
                    for boundary in ['before','after']:
                        compiler_count+=len(event[boundary]['compilers']);loads.append(event[boundary]['load'][0]);require(not event[boundary]['compilers'],'Compiler observation recorded at process boundary')
                    label=event['label'];p=validate_child(event,raw,stem,fixture,manifests[label],task['iterations'],2,manifests[label]['probe_sha256']);medians[label]=statistics.median(r['vort_ns'] for r in p['pairs'])
                ratios.append(medians['baseline']/medians[variant])
            gm=math.exp(statistics.mean(map(math.log,ratios)));ratios_by_row[key]=ratios;geomeans[key]=gm;declared=json.loads(raw[key+'.summary.json'])[variant]
            require(declared['speed_ratios']==ratios and declared['speed_geomean']==gm and independent['statistics'][variant]['row_speed_geomeans'][key]==gm,'Independent row medians/ratios differ')
        gm,ci=bootstrap_ratios(list(ratios_by_row.values()));weakest=min((v,k) for k,v in geomeans.items());target=geomeans[protocol['target']];s=summary[variant]
        require(s['speed_geomean']==gm and s['ci95']==ci and s['weakest']==list(weakest) and s['target']==target and s['rows']==12 and s['seed']==0x20261112,'Independent aggregate/bootstrap/target statistics differ')
        target_pass=target>=1.2;controls_pass=weakest[0]>=0.98;aggregate_pass=gm>=1.03 and ci[0]>1
        require((s['target_pass'],s['controls_pass'],s['aggregate_pass'])==(target_pass,controls_pass,aggregate_pass) and s['dedicated_host_acceptance'] is False and not (target_pass and controls_pass and aggregate_pass),'Rejected-variant gate result differs')
        i=independent['statistics'][variant];require(i['speed_geomean']==gm and i['target']==target and i['weakest']==list(weakest),'Main independent grouped statistics differ')
        for size in ['65536','1048576']:require(i['size_'+size]==math.exp(statistics.mean(math.log(v) for k,v in geomeans.items() if '_'+size+'_' in k)),'Independent size-group geomean differs')
        computed[variant]={'geomean':gm,'ci95':ci,'target':target,'weakest':list(weakest),'row_geomeans':geomeans,'target_pass':target_pass,'controls_pass':controls_pass,'aggregate_pass':aggregate_pass,'decision':'REJECT'}
    require(compiler_count==independent['compiler_observations']==0 and [min(loads),max(loads)]==independent['load1_range'] and independent['raw_measured_pair_count']==384 and independent['process_pair_count']==96,'Recorded compiler/load/pair scope differs')
    smoke_events=json.loads(smoke['events.json']);validation=json.loads(smoke['validation.json']);require(len(smoke_events)==144 and validation=={'returncode':0,'events':144,'wires_per_variant':72,'full_output':True,'exact_consumption':True,'guards':True,'immutable_input':True,'timings_used_for_performance_claims':False},'Both-variant smoke terminal validation differs')
    for variant in ['owner-word','owner-only']:
        m=json.loads(smoke[variant+'.manifest.json']);require(m['source']==manifests[variant]['source'] and m['probe_sha256']==manifests[variant]['probe_sha256'],'Smoke/source epoch differs');selected=[e for e in smoke_events if e['variant']==variant];require(len(selected)==72 and {e['task']['fixture']['key'] for e in selected}==set(fixtures),'Smoke72-wire coverage differs')
        for event in selected:
            task=event['task'];fixture=fixtures[task['fixture']['key']];require(task=={'fixture':fixture,'lifecycle':'cold','iterations':1},'Smoke task differs');stem=variant+'.'+fixture['key'].replace('/','_')+'_cold';require(json.loads(smoke[stem+'.json'])==event and not event['before']['compilers'] and not event['after']['compilers'],'Smoke event/host binding differs');validate_child(event,smoke,stem,fixture,m,1,0,m['probe_sha256'])
    producer=json.loads(archives['raw-validation.tar.gz']['producer-validation.json']);require(sha(smoke['validation.json'])==producer['smoke_validation_sha256'],'Producer smoke receipt binding differs')
    decision=json.loads((root/'decision.json').read_bytes());require(decision['variants']==summary and decision['adoption']=={'owner-word':False,'owner-only':False},'Final rejected decision scope differs')
    return {'events':192,'process_pairs':96,'pairs_per_variant':48,'raw_measured_vort_reference_pairs':384,'raw_warmup_vort_reference_pairs':384,'compiler_observations':0,'load1_range':[min(loads),max(loads)],'bootstrap_resamples':2000,'bootstrap_seed':0x20261112,'variants':computed,'smoke_events':144,'smoke_wires_per_variant':72,'smoke_times_are_performance_samples':False,'dedicated_host_acceptance':False,'full_industry_matrix':False}

def verify(root,originals=False,git_repo=None):
    binding,archives,original_count=inventory(root,originals);containers=reused(root,binding);base,epochs,manifests=baseline_and_epochs(root,binding,archives,containers)
    tests=test_epochs(root,archives,epochs);static=static_audit(root,archives);fixtures=fixture_descriptors(root,binding,originals);statistics=screen_and_smoke(root,archives,manifests,fixtures);git_count=git_verify(git_repo,BASE,base)
    return {'schema':'vort.deflate.mapped-owner-archive-validation.v1','valid':True,'scope':'offline byte/source/recorded-test/static-counter/statistics verification; no compiler, test, codec, oracle or benchmark execution','cpu_affinity':sorted(os.sched_getaffinity(0)),'base_revision':BASE,'baseline_git_blobs_verified':git_count,'prototype_modified_files_are_uncommitted_overlays':True,'original_files_verified':original_count,'source_overlay_files':{n:len(v) for n,v in epochs.items()},'capture_registry_files':{'baseline':2069,'owner-word':2075,'owner-only':2071},'original_timing_replay_inventory_files':len({**base,**epochs['timing-source']}),'timing_inventory_is_archive_reconstruction':True,'test_epochs':tests,'static_audit':static,'screen_and_smoke':statistics,'ordinary_fixture_bytes_archived':False,'external_fixture_files_verified':108 if originals else 0,'external_fixture_bytes_verified':371820359 if originals else 0,'prototype_adopted':False}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--originals',action='store_true');parser.add_argument('--git-repo',type=Path);args=parser.parse_args();print(json.dumps(verify(Path(__file__).resolve().parent,args.originals,args.git_repo),indent=2))
