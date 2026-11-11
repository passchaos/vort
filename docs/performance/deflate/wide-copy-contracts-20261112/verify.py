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
import statistics
import subprocess
import tarfile
BASE='492a0a74535992cd4a7e3ad3182777414c8c0fac'
REY_BASE='8adfb3bae74409bae146fed2ed9b6594a1d3cdb8'
PROBE='2527c72112f19ac34d08d8f199f38e76dc4a9883ad25466f2f83ff193da21f14'
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

def reconstruct(source,addendum,containers):
    require(source['revision']==BASE and len(source['sha256'])==2048,'Original capture registry differs')
    require(sha(json.dumps(source['sha256'],sort_keys=True).encode())==source['digest']=='ca749da163882c8d358b32e95602110b71b4987fafbebc96330dbbb7aaacf529','Capture source digest differs')
    require(addendum['original_registered_count']==2048 and len(addendum['added_build_modules'])==15 and addendum['reconstructed_count']==2063 and 'later main-authored reconstruction' in addendum['artifact_kind'],'Later reconstruction attribution differs')
    hashes=dict(source['sha256']);require(not hashes.keys() & addendum['added_build_modules'].keys(),'Addendum silently overwrites capture registry')
    hashes.update(addendum['added_build_modules'])
    require(sha(json.dumps(hashes,sort_keys=True).encode())==addendum['reconstructed_digest']=='32546e939bea56b5b2122482e0383a2bce3769e4f6146bcf0684d31128692075','Reconstructed inventory digest differs')
    base={n.removeprefix('shared-dispatch/'):b for n,b in containers['baseline_source'].items()}
    base.update(containers['public_linear_overlay'])
    require({n:sha(b) for n,b in base.items()}==hashes,'Reconstructed 2063 source bytes differ')
    binary=containers['baseline_binary']['shared-dispatch/semantic-compare']
    require(sha(binary)==PROBE,'Equivalent baseline probe differs')
    return base,binary

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

def completed_screen(root,archives,base,final,originals):
    raw=archives['nonregression-raw.tar.gz'];smoke=archives['smoke-raw.tar.gz'];deps=archives['screen-runner-dependencies.tar.gz']
    manifests={label:json.loads(raw[label+'.manifest.json']) for label in ['baseline','candidate']}
    candidate=dict(base);candidate.update(final)
    for label,source,probe in [('baseline',base,PROBE),('candidate',candidate,'e8377941221a13c0a0030b10ae083bb73cf17bc58f81ea8d55ad98c5eb66cb5c')]:
        m=manifests[label];require(m['source']['revision']==BASE and {n:sha(b) for n,b in source.items()}==m['source']['sha256'],'Screen frozen source differs: '+label)
        require(sha(json.dumps(m['source']['sha256'],sort_keys=True).encode())==m['source']['digest'] and m['probe_sha256']==probe,'Screen source/probe digest differs')
        r=m['references']['deflate'];require(r['source_revision']=='92e6a0db9fa848d742f9eb286c92afc60f2c3dda' and set(r['file_sha256'].values())=={REFERENCE} and r['flags']=='-O3 -DNDEBUG -march=skylake','Screen pinned reference build differs')
    for name in ['matrix.py','evidence.py','fixtures.py']:require(deps['imports/'+name]==base['tools/decode/'+name],'Screen replay import differs')
    require(b"'/tmp/vort-decode-refresh-20261111.ea193be2/manifest.json'" in deps['imports/pilot.py'] and b'pilot.OUT' in raw['screen.py'],'Screen seed imports differ')
    fixture_binding=json.loads((root/'fixture-replay-bindings.json').read_bytes());fixtures={f['key']:f for f in fixture_binding['fixtures']}
    require(len(fixtures)==fixture_binding['fixture_count']==72 and fixture_binding['original_file_count']==len(fixture_binding['files'])==108 and fixture_binding['original_bytes']==sum(f['bytes'] for f in fixture_binding['files'].values())==371820359,'Fixture replay inventory differs')
    for f in fixtures.values():
        for path_field,hash_field,bytes_field in [('input_path','input_sha256','input_bytes'),('encoded_input_path','encoded_sha256','encoded_bytes')]:require(fixture_binding['files'][f[path_field]]=={'sha256':f[hash_field],'bytes':f[bytes_field]},'Fixture replay binding differs')
    if originals:
        for path,r in fixture_binding['files'].items():
            b=Path(path).read_bytes();require(len(b)==r['bytes'] and sha(b)==r['sha256'],'External original fixture differs: '+path)
    screen_events=json.loads(raw['events.json']);require(len(screen_events)==96,'Incomplete screen events')
    keys={f'deflate_{name}_{size}_{level}_cold':fixtures[f'deflate/{name}/{size}/{level}'] for size in ['65536','1048576'] for name in ['reymont','nci','xml'] for level in [6,9]}
    require(set(e['key'] for e in screen_events)==set(keys),'Selected screen rows differ')
    stats=json.loads(raw['independent-stats.json']);require(raw['independent-stats.json']==(root/'independent-stats.json').read_bytes() and stats['events_sha256']==sha(raw['events.json']) and stats['events']==96,'Independent stats events binding differs')
    row_gm={}
    for key,fixture in keys.items():
        events=[e for e in screen_events if e['key']==key];require(len(events)==8,'Missing outer pair')
        ratios=[]
        for outer in range(4):
            order=['baseline','candidate'] if outer%2==0 else ['candidate','baseline'];pair=events[outer*2:outer*2+2]
            require([e['label'] for e in pair]==order and all(e['pair']==outer for e in pair),'Outer alternating order differs')
            medians={}
            for event in pair:
                stem=f"{key}.{outer}.{event['label']}";require(json.loads(raw[stem+'.json'])==event and not event['before']['compilers'] and not event['after']['compilers'],'Event/host observation binding differs')
                p=validate_child(event,raw,stem,fixture,manifests[event['label']],500 if fixture['size']=='65536' else 100,2,manifests[event['label']]['probe_sha256'])
                medians[event['label']]=statistics.median(x['vort_ns'] for x in p['pairs'])
            ratios.append(medians['baseline']/medians['candidate'])
        gm=math.exp(statistics.mean(math.log(r) for r in ratios));row_gm[key]=gm
        summary=json.loads(raw[key+'.summary.json']);require(summary['speed_ratios']==stats['rows'][key]['ratios']==ratios and math.isclose(summary['geomean'],gm,rel_tol=1e-12) and math.isclose(stats['rows'][key]['geomean'],gm,rel_tol=1e-12),'Independent row recomputation differs')
    gm=math.exp(statistics.mean(math.log(r) for r in row_gm.values()));weak=min(row_gm,key=row_gm.get)
    require(all(r>=0.98 for r in row_gm.values()) and math.isclose(gm,stats['selected_twelve_geomean'],rel_tol=1e-12) and weak==stats['weakest_selected_row'] and math.isclose(row_gm[weak],stats['weakest_geomean'],rel_tol=1e-12),'Selected nonregression summary differs')
    smoke_manifest=json.loads(smoke['manifest.json']);require(smoke_manifest['source']==manifests['candidate']['source'] and smoke_manifest['probe_sha256']==manifests['candidate']['probe_sha256'] and smoke_manifest['config']['rounds']==2 and smoke_manifest['config']['warmup']==0,'Smoke frozen epoch/count differs')
    smoke_events=json.loads(smoke['events.json']);require(len(smoke_events)==72 and {e['task']['fixture']['key'] for e in smoke_events}==set(fixtures),'Smoke does not cover72 frozen wires')
    for event in smoke_events:
        task=event['task'];fixture=fixtures[task['fixture']['key']];require(task=={'fixture':fixture,'lifecycle':'cold','iterations':1},'Smoke fixture/task differs')
        key=fixture['key'].replace('/','_')+'_cold';require(json.loads(smoke[key+'.json'])==event,'Smoke raw event differs')
        validate_child(event,smoke,key,fixture,smoke_manifest,1,0,manifests['candidate']['probe_sha256'])
    require(json.loads(smoke['validation.json'])=={'returncode':0,'events':72,'full_output':True,'input_immutable':True,'guards':True,'exact_consumption':True,'timings_used_for_performance_claims':False},'Smoke terminal validation differs')
    require(b'72/72 frozen Deflate wires passed' in smoke['smoke.log'],'Smoke terminal log absent')
    return {'events':96,'selected_rows':12,'outer_pairs_per_row':4,'child_measured_pairs':2,'child_warmup_pairs':2,'selected_geomean':gm,'weakest_row':weak,'weakest_geomean':row_gm[weak],'all_selected_row_geomeans_at_least_0_98':True,'performance_gain_claimed':False,'smoke_events':72,'smoke_times_are_acceptance_samples':False,'large_fixture_bytes_archived':False,'external_fixture_files_verified':108 if originals else 0,'external_fixture_bytes_verified':371820359 if originals else 0}

def verify(root,originals=False,git_repo=None):
    binding,archives,original_count=inventory(root,originals);containers=reused(root,binding)
    source=json.loads((root/'base-source-registry.json').read_bytes())['source'];addendum=json.loads((root/'build-source-addendum.json').read_bytes())
    base,baseline_binary=reconstruct(source,addendum,containers)
    if originals:
        origin=Path(binding['base_registry_origin']);require(sha(origin.read_bytes())==binding['base_registry_origin_sha256'] and json.loads(origin.read_bytes())['manifest']['source']==source,'Original base registry differs')
    raw=archives['raw-validation.tar.gz'];executables=archives['test-executables.tar.gz']
    before=archives['before-source-overlay.tar.gz'];v1=archives['v1-source-overlay.tar.gz'];final=archives['final-boundary-source-overlay.tar.gz']
    require({n:sha(b) for n,b in before.items()}==json.loads(raw['before-source-sha256.json']),'Before source hashes differ')
    for overlay,name,probe in [(v1,'after-freeze.json','after-compare'),(final,'boundary-freeze.json','boundary-compare')]:
        frozen=json.loads(raw[name]);require({n:sha(b) for n,b in overlay.items()}==frozen['source_sha256'] and sha(executables[probe])==frozen['probe_sha256'],'Frozen epoch/source/probe binding differs')
    require(before['src/deflate/decoder/shortcopy.zig']==base['src/deflate/decoder/shortcopy.zig'],'Before kernel is not frozen baseline')
    require(before['src/deflate/decoder/wide_copy_tests.zig']==v1['src/deflate/decoder/wide_copy_tests.zig'],'V1 silently changes before test')
    require(v1['src/deflate.zig']==final['src/deflate.zig'],'Test wiring differs across candidate epochs')
    require(final['src/deflate/semantic/decoder.zig']==base['src/deflate/semantic/decoder.zig'].replace(b'shortcopy.copyWide(',b'shortcopy.copyWideAtLeast16('),'Final production caller differs beyond validated boundary')
    require(base['src/deflate/semantic/decoder.zig'].count(b'shortcopy.copyWide(')==1,'Original production caller count differs')
    before_loop=before['src/deflate/decoder/shortcopy.zig'].split(b'    var offset: usize = 0;')[1]
    final_loop=final['src/deflate/decoder/shortcopy.zig'].split(b'    var offset: usize = 0;')[1]
    require(before_loop==final_loop and b'pub inline fn copyWideAtLeast16' in final['src/deflate/decoder/shortcopy.zig'],'Original wide-loop body was not retained')
    require(b'if (length < 16)' in v1['src/deflate/decoder/shortcopy.zig'] and b'copyWideAtLeast16(destination, source, length)' in final['src/deflate/decoder/shortcopy.zig'],'Full facade/core boundary differs')
    test=final['src/deflate/decoder/wide_copy_tests.zig'];require(all(t in test for t in [b'.facade => 3',b'.at_least_16 => 16',b'for (0..16) |source_offset|',b'for (0..16) |destination_offset|',b'for (0..16) |offset|',b'[_]bool{ true, false }',b'scalarCopy(',b'expected, &actual']),'Direct scalar/guard contract fixture differs')
    facade=(259-3)*(16*16+16*2);core=(259-16)*(16*16+16*2)
    require((facade,core,facade+core)==(73728,69984,143712),'Contract case arithmetic differs')
    validation=json.loads(raw['boundary-validation.json']);require(raw['boundary-validation.json']==(root/'boundary-validation.json').read_bytes() and sha(raw['boundary-validation.json'])=='fb1ec6fdd19d499330089618794ad984cc8e80c11fe17d491f1a8f3798834792','Final receipt bytes differ')
    require(validation['source_unchanged'] is True and validation['source_sha256']=={n:sha(b) for n,b in final.items()}==json.loads(raw['boundary-source-sha256.json']),'Final validated source differs')
    require((validation['final_facade_cases'],validation['final_at_least16_core_cases'],validation['total_scalar_cases'])==(facade,core,facade+core),'Recorded scalar case counts differ')
    failure=raw['before-safe.log'];require(validation['before_exit_code']==1 and validation['before_log_sha256']==sha(failure) and b'panic: integer overflow' in failure and b'terminated with signal ABRT' in failure,'Before direct low-length failure differs')
    final_runs=[]
    for run in validation['runs']:
        require(run['returncode']==0 and sha(raw[run['raw_log']])==run['log_sha256'] and sha(executables[run['executable']])==run['executable_sha256'],'Final test run binding differs')
        final_runs.append({'label':run['label'],**successful_tests(raw[run['raw_log']],run['tests_passed'])})
    require(len(final_runs)==5 and [r['tests'] for r in final_runs]==[1,1,1,1,736],'Final validation matrix differs')
    v1_runs=[successful_tests(raw[n],1) for n in ['after-debug.log','after-safe.log','after-x86.log','after-wasi-run.log']]
    v1_full=successful_tests(raw['full-safe.log'],736)
    require(raw['after-wasi-build.log']==raw['boundary-wasi-build.log']==b'' and all(b'Build Summary: 7/7 steps succeeded' in raw[n] for n in ['after-compare-build.log','boundary-compare-build.log']),'Archived build success differs')
    codegen=json.loads(raw['codegen-comparison.json']);require(raw['codegen-comparison.json']==(root/'codegen-comparison.json').read_bytes() and 'main-authored derived summary' in codegen['artifact_kind'] and 'original nm/objdump stdout not preserved' in codegen['artifact_kind'],'Codegen attribution differs')
    require(codegen['baseline_probe_sha256']==PROBE and codegen['root_symbol']=='deflate.semantic.linear_entry.aligned','Codegen symbol epoch differs')
    for name,values,probe in [('baseline',(3637,296,6,898,131),None),('initial_full_facade',(3701,312,None,900,122),'after-compare'),('validated_boundary',(3669,296,None,896,131),'boundary-compare')]:
        r=codegen[name]
        require((r['text_bytes'],r['stack_reservation'],r.get('register_pushes'),r['static_instructions_with_padding'],r['negative_rbp_references'])==values,'Message-derived static summary differs')
        if probe:require(r['probe_sha256']==sha(executables[probe]),'Static-summary candidate epoch differs')
    require(sha(containers['reference_library']['deflate/libdeflate.so.0'])==REFERENCE,'Pinned reference library differs')
    screen=completed_screen(root,archives,base,final,originals)
    identity=json.loads((root/'saved-source-commit.json').read_bytes())
    require(identity['commit']==binding['saved_final_source_commit'] and identity['source_sha256']=={n:sha(b) for n,b in final.items()} and 'later saved Git commit identity' in identity['artifact_kind'],'Saved final source identity differs')
    saved_git_count=git_verify(git_repo,identity['commit'],final)
    git_count=git_verify(git_repo,BASE,base)
    return {'schema':'vort.deflate.wide-copy-archive-validation.v1','valid':True,'scope':'offline byte/source/recorded-contract verification; no compiler, codec, sampling or benchmark run','cpu_affinity':sorted(os.sched_getaffinity(0)),'base_revision':BASE,'capture_registry_files':2048,'later_reconstructed_base_inventory_files':2063,'base_git_blobs_verified':git_count,'saved_final_source_commit':identity['commit'],'saved_final_source_git_blobs_verified':saved_git_count,'original_files_verified':original_count,'completed_nonregression_and_smoke':screen,'source_epoch_file_counts':{'before_overlay':len(before),'v1_overlay':len(v1),'final_boundary_overlay':len(final)},'before_direct_low_length_failure_verified':True,'final_facade_scalar_cases':facade,'final_core_scalar_cases':core,'total_scalar_cases':facade+core,'v1_focused_runs':len(v1_runs),'v1_full_safe':v1_full,'final_runs':final_runs,'codegen_original_nm_objdump_preserved':False,'strict_codegen_equivalence_proven':False,'performance_gain_claimed':False,'new_public_wire_defect_claimed':False}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--originals',action='store_true');parser.add_argument('--git-repo',type=Path);args=parser.parse_args()
    print(json.dumps(verify(Path(__file__).resolve().parent,args.originals,args.git_repo),indent=2))
