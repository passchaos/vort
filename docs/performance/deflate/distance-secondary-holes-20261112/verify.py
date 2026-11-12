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
BASE='c19f5cddea3f5806ac48ebc7578f9ff8bc665b05'
PROBE='e8377941221a13c0a0030b10ae083bb73cf17bc58f81ea8d55ad98c5eb66cb5c'
AFTER_PROBE='65b75eeec00bf7933d0baa3886e6097fc7275a813d72190f601be286944cce96'
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

def completed_screen(root,archives,base,final,originals):
    raw=archives['nonregression-raw.tar.gz'];smoke=archives['smoke-raw.tar.gz'];deps=archives['screen-runner-dependencies.tar.gz']
    manifests={label:json.loads(raw[label+'.manifest.json']) for label in ['baseline','candidate']}
    candidate=dict(base);candidate.update(final)
    for label,source,probe in [('baseline',base,PROBE),('candidate',candidate,AFTER_PROBE)]:
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
    require(all(r>=0.98 for r in row_gm.values()) and math.isclose(gm,stats['selected_geomean'],rel_tol=1e-12) and weak==stats['weakest_row'] and math.isclose(row_gm[weak],stats['weakest_geomean'],rel_tol=1e-12),'Selected nonregression summary differs')
    smoke_manifest=json.loads(smoke['manifest.json']);require(smoke_manifest['source']==manifests['candidate']['source'] and smoke_manifest['probe_sha256']==manifests['candidate']['probe_sha256'] and smoke_manifest['config']['rounds']==2 and smoke_manifest['config']['warmup']==0,'Smoke frozen epoch/count differs')
    smoke_events=json.loads(smoke['events.json']);require(len(smoke_events)==72 and {e['task']['fixture']['key'] for e in smoke_events}==set(fixtures),'Smoke does not cover72 frozen wires')
    for event in smoke_events:
        task=event['task'];fixture=fixtures[task['fixture']['key']];require(task=={'fixture':fixture,'lifecycle':'cold','iterations':1},'Smoke fixture/task differs')
        key=fixture['key'].replace('/','_')+'_cold';require(json.loads(smoke[key+'.json'])==event,'Smoke raw event differs')
        validate_child(event,smoke,key,fixture,smoke_manifest,1,0,manifests['candidate']['probe_sha256'])
    require(json.loads(smoke['validation.json'])=={'returncode':0,'events':72,'full_output':True,'input_immutable':True,'guards':True,'exact_consumption':True,'timings_used_for_performance_claims':False},'Smoke terminal validation differs')
    require(b'72/72 frozen Deflate wires passed' in smoke['smoke.log'],'Smoke terminal log absent')
    return {'events':96,'selected_rows':12,'outer_pairs_per_row':4,'child_measured_pairs':2,'child_warmup_pairs':2,'selected_geomean':gm,'weakest_row':weak,'weakest_geomean':row_gm[weak],'all_selected_row_geomeans_at_least_0_98':True,'performance_gain_claimed':False,'smoke_events':72,'smoke_times_are_acceptance_samples':False,'large_fixture_bytes_archived':False,'external_fixture_files_verified':108 if originals else 0,'external_fixture_bytes_verified':371820359 if originals else 0}


def reconstructed_base(containers,source):
    base={n.removeprefix('shared-dispatch/'):b for n,b in containers['baseline_source'].items()}
    base.update(containers['public_linear_overlay']);base.update(containers['wide_boundary_overlay'])
    require(source['revision']==BASE and len(source['sha256'])==2064 and {n:sha(b) for n,b in base.items()}==source['sha256'],'Immutable baseline registry/source differs')
    require(sha(json.dumps(source['sha256'],sort_keys=True).encode())==source['digest']=='5d3bf586c4048ec945c55d3e769dc46313e6256668188a4319ba75ffdab062ef','Baseline registry digest differs')
    require(sha(containers['baseline_binary']['boundary-compare'])==PROBE,'Baseline probe bytes differ')
    require(sha(containers['reference_library']['deflate/libdeflate.so.0'])==REFERENCE,'Pinned reference library differs')
    return base

def sources_and_contracts(archives,base,validation):
    before=archives['before-v2-source-overlay.tar.gz'];final=archives['final-source-overlay.tar.gz'];initial=archives['initial-test-source.tar.gz']['initial-test-source.zig'];modes1=archives['modes-v1-source.tar.gz']['distance_holes_modes.zig'];raw=archives['raw-validation.tar.gz']
    require(len(before)==5 and len(final)==9 and {n:sha(b) for n,b in before.items()}==json.loads(raw['before-source-sha256.json']),'Before-v2 source identity differs')
    require({n:sha(b) for n,b in final.items()}==json.loads(raw['after-source-sha256.json'])==validation['source_sha256'] and validation['source_unchanged'] is True,'Final9 source identity differs')
    test_name='src/deflate/semantic/distance_holes_tests.zig';require(before[test_name]==final[test_name],'Public fixture source differs across before/final')
    require(initial.replace(b'(if (seed_block) history_len else 0)',b'@as(usize, if (seed_block) history_len else 0)')==before[test_name],'Initial test correction differs beyond usize cast')
    for name in ['before-fast.log','before-safe.log','before-debug.log']:
        log=raw[name];require(b"error: value with comptime-only type 'comptime_int' depends on runtime control flow" in log and b'if (seed_block) history_len else 0' in log,'Initial excluded compile-error log differs')
    for name in ['src/deflate/semantic/decoder.zig','src/deflate/semantic/rolling_decoder.zig']:require(before[name]==base[name],'Before semantic production differs from frozen Git baseline')
    semantic=base['src/deflate/semantic/decoder.zig']
    semantic=semantic.replace(b'            self.distance_secondary_len += size;\n',b'            self.distance_secondary_len += size;\n            // Incomplete distance alphabets are accepted. Every allocated\n            // suffix slot must therefore have a defined invalid-code sentinel\n            // before the existing codes populate their repeated entries.\n            @memset(self.distance_secondary[start..][0..size], 0);\n')
    semantic=semantic.replace(b'            if (symbol >= distance_table.len) return error.InvalidHuffmanCode;\n',b'            if (symbol >= distance_table.len) return error.InvalidHuffmanCode;\n            if ((secondary & 0x0f) == 0) return error.InvalidHuffmanCode;\n')
    require(semantic==final['src/deflate/semantic/decoder.zig'],'Allocated suffix clearing/shared consumer guard differs')
    rolling=base['src/deflate/semantic/rolling_decoder.zig'].replace(b'            if (symbol >= tables.distance_table.len) return error.InvalidHuffmanCode;\n',b'            if (symbol >= tables.distance_table.len) return error.InvalidHuffmanCode;\n            if ((secondary & 0xf) == 0) return error.InvalidHuffmanCode;\n')
    require(rolling==final['src/deflate/semantic/rolling_decoder.zig'],'Rolling consumer guard differs')
    def remove_test_blocks(data):
        text=data.decode();start=text.index('test "Deflate long distance secondary hole contracts"');end=text.index('test "deflate portable secondary lookups',start);return (text[:start]+text[end:]).encode()
    require(remove_test_blocks(before['src/deflate.zig'])==base['src/deflate.zig'],'Before Deflate production differs beyond test wiring')
    facade=base['src/deflate.zig'].replace(b'            distance_code_bits = @truncate(secondary & 0x0f);\n',b'            distance_code_bits = @truncate(secondary & 0x0f);\n            if (distance_code_bits == 0) return error.InvalidHuffmanCode;\n')
    require(remove_test_blocks(final['src/deflate.zig'])==facade,'Sink zero-width guard differs beyond test wiring')
    require(before['src/root.zig']==final['src/root.zig'],'Root test wiring changed across epochs')
    root_test=b'\ntest "root long distance secondary hole contracts" {\n    try @import("deflate/semantic/distance_holes_tests.zig").contracts(@This());\n}\n'
    require(final['src/root.zig'].replace(root_test,b'')==base['src/root.zig'],'Root differs beyond one duplicate contract aggregate')
    public=final[test_name];modes=final['src/deflate/semantic/distance_holes_modes.zig']
    require(sha(public)=='f08692f8e653f11732860acc30e1b2afd0679469b0afcaf4c4b1fa906c8e0eaa' and sha(modes)=='335715541e33d4e3a3ce5c92b1bbe0284d72902ab369046bf769c8bc1b763365','Frozen contract module hashes differ')
    public_checks=[b'[_]bool{ false, true }',b'[_]Token{ .existing9, .existing10 }',b'makeWire(true, 0, .missing10)',b'makeWire(false, 0, .missing10)',b'@as(usize, 2436)',b'@as(usize, 305)',b'@as(@TypeOf(start), 1150)',b'@as(@TypeOf(start), 1114)',b'.{ 137, 154, 137, 170 }',b'.{ 9, 26, 9, null }',b'try std.testing.expectEqual(wire.bare().len, decoded.input_read)',b'try std.testing.expectEqual(expected_output_len, decoded.output_written)',b'no rollback or',b'for (storage[guard_len + output_len ..])']
    require(all(x in public for x in public_checks),'Public fixture shape/guard/output/unused-tail method differs')
    mode_checks=[b'const token_start = 2402;',b'[_]Mode{ .ordinary, .non_overlap, .window, .sink }',b'[_]usize{ ring.capacity - 64, ring.capacity - prefix_len - 1 }',b'base != 0',b'output_limit - prefix_len >= 262',b'token_start), reader.bitPosition()',b'No\n        // secondary slot is read, altered, or artificially poisoned',b'Output bytes inside unused capacity have no untouched-tail or error']
    require(all(x in modes for x in mode_checks),'Direct mode/reader/guard/no-poison method differs')
    require(b'[_]Mode{ .ordinary, .window, .sink }' in modes1 and b'.non_overlap' not in modes1,'Intermediate mode15 scope differs')
    require(validation['public_cases']==6 and validation['direct_mode_cases']==18,'Recorded public/direct case counts differ')
    require((2*2+2,4*3+2*3,3*3+2*3)==(6,18,15),'Contract count derivation differs')
    return before,final

def oracle_and_fixtures(root,archives,binding,final):
    small=archives['small-fixtures-oracle.tar.gz'];raw=archives['raw-validation.tar.gz'];worker=json.loads(small['worker/oracle.json']);main=json.loads(raw['oracle-replay.json'])
    require(raw['oracle-replay.json']==(root/'oracle-replay.json').read_bytes()==raw['oracle-replay.log'],'New independent oracle stdout/readable receipt differs')
    require(main['artifact_kind']=='new main-authored independent replay, not recovered worker stdout' and main['zlib_runtime']==worker['zlib_runtime']=='1.2.11','Independent/worker oracle attribution differs')
    script=raw['oracle_replay.py'];require(all(x in script for x in [b'class Reader:',b'def table(lengths):',b'def symbol(reader,t):',b'for width in range(1,maximum+1):',b'code|=reader.read(1)',b'assert output==b\'a\'*131',b'zlib.decompress(data,-15)']),'Independent canonical oracle method differs')
    require(len(main['rows'])==6 and len(worker['rows'])==8,'Oracle retained row scopes differ')
    expected_output=sha(b'a'*131);accepted=0;rejected=0
    for row in main['rows']:
        name=row['name'];padded=small['worker/padded/'+name];old=next(r for r in worker['rows'] if r['name']+'.deflate'==name)
        require(row['sha256']==sha(padded) and len(padded)==row['padded_bytes']==old['padded_bytes'],'Padded oracle hash/size differs')
        bare=small['derived-bare/'+name];derived=binding['derived_bare_slices']['derived-bare/'+name]
        require(bare==padded[:old['wire_bytes']] and padded[old['wire_bytes']:]==bytes(16) and sha(bare)==old['sha256']==derived['sha256'] and len(bare)==old['wire_bytes']==derived['wire_bytes'],'Bare/padded hash scopes differ')
        require(row['zlib']==old['zlib']=='Error -3 while decompressing data: invalid distances set','Different eager zlib contract evidence differs')
        expected_headers=[{'start':0,'payload':1150,'hlit':258,'hdist':11,'hclen':19},{'start':1288,'payload':2402,'hlit':258,'hdist':2,'hclen':19}] if name.startswith('two-block') else [{'start':0,'payload':1114,'hlit':258,'hdist':2,'hclen':19}]
        if 'headers' in old:require(old['headers']==expected_headers,'Worker canonical block/header metadata differs')
        else:require(old['subset']=='rejected','Missing worker header metadata attribution differs')
        if row['result']=='accepted':
            accepted+=1;require(old['subset']=='accepted' and row['output_bytes']==old['output']==131 and row['output_sha256']==expected_output and row['input_read']==old['input_read'],'Accepted subset oracle receipt differs')
        else:
            rejected+=1;require(old['subset']=='rejected' and row['error']==old['reason'] and row['error'] in ['missing Huffman code at bit 1262','missing Huffman code at bit 2422'],'Missing-code oracle receipt differs')
    require((accepted,rejected)==(4,2),'Main independent oracle subset counts differ')
    for repo_name,worker_name in [('distance-hole-existing9.deflate','two-block-existing9.deflate'),('distance-hole-existing10.deflate','two-block-existing10.deflate'),('distance-hole-missing10.deflate','two-block-missing10.deflate')]:
        b=small['repo-testdata/'+repo_name];require(b==small['worker/padded/'+worker_name]==final['src/deflate/semantic/testdata/'+repo_name],'Frozen repo fixture bytes differ')
    malformed=small['derived-bare/two-block-missing10.deflate'];require(len(malformed)==305 and sha(malformed)=='e21b04b1f406dca371ddf196b9a28cb24428e4321649a0928a595e44e4c02bf4','Public stale-slot malformed bare witness differs')
    require(next(r for r in worker['rows'] if r['name']=='single-no-history-missing10')['wire_bytes']==144,'Separate worker no-history metadata differs')
    return {'main_independent_rows':6,'accepted_subset_cases':4,'missing_code_cases':2,'worker_retained_rows':8,'worker_saved_padded_fixtures':6,'worker_original_script_preserved':False,'worker_extra_two_rows_have_saved_fixture_bytes':False,'main_oracle_single_missing_has_128_literal_prefix':True,'public_zig_single_missing_has_no_history':True,'oracle_reexecuted_during_archive_verification':False,'malformed_bare_bytes':len(malformed),'zlib_eager_header_contract_differs':True}

def verify(root,originals=False,git_repo=None):
    binding,archives,original_count=inventory(root,originals);containers=reused(root,binding);raw=archives['raw-validation.tar.gz'];exes=archives['retained-executables.tar.gz']
    require(sha(raw['validation.json'])=='d339d1b40b89c655563c861f2a9802693d733cc7c8ad96335481887e45767340' and raw['validation.json']==(root/'validation.json').read_bytes(),'Original final validation receipt differs')
    validation=json.loads(raw['validation.json']);require(validation['base_revision']=='c19f5cdd','Original receipt base epoch differs')
    base=reconstructed_base(containers,json.loads(archives['nonregression-raw.tar.gz']['baseline.manifest.json'])['source'])
    before,final=sources_and_contracts(archives,base,validation)
    oracle=oracle_and_fixtures(root,archives,binding,final)
    before_rows={}
    for label,output in [('debug',143),('fast',131)]:
        receipt=validation['before'][label];log=raw[receipt['log']]
        require(receipt['returncode']==1 and receipt['malformed_success_input_read']==305 and receipt['malformed_success_output_written']==output,'Before malformed acceptance receipt differs')
        require(f'expected error.InvalidHuffmanCode, found .{{ .input_read = 305, .output_written = {output} }}'.encode() in log and b'7 passed; 0 skipped; 1 failed.' in log and b'failed with exit code 1:' in log,'Before malformed public acceptance log differs')
        before_rows[label]={'returncode':1,'malformed_input_read':305,'malformed_output_written':output,'tests_passed':7,'tests_failed':1}
    receipt=validation['before']['safe'];require(receipt['returncode']==0,'Before Safe seed result differs');before_rows['safe']={'returncode':0,**successful_tests(raw[receipt['log']],8),'scope':'this seed correctly rejects; no all-mode old failure claim'}
    require(sha(exes['after-compare'])==validation['comparison_sha256']==AFTER_PROBE,'Final comparator bytes differ')
    freeze=json.loads(raw['compare-freeze.json']);require(freeze['source_sha256']==validation['source_sha256'] and freeze['probe_sha256']==AFTER_PROBE,'Final source/probe freeze differs')
    require(b'Build Summary: 7/7 steps succeeded' in raw['final-compare-build.log'],'Comparator build success receipt absent')
    final_runs=[]
    for run in validation['runs']:
        require(run['returncode']==0 and sha(raw[run['log']])==run['log_sha256'] and sha(exes[run['executable']])==run['executable_sha256'],'Final executable/log binding differs')
        counts=successful_tests(raw[run['log']],run['tests_passed']);final_runs.append({'label':run['label'],**counts})
        if run['tests_passed']==10:require(counts['named_tests']==2 and counts['anonymous_import_tests']==8,'Deflate filtered aggregates/imports differ')
        elif run['tests_passed']==92:require(counts['named_tests']==3 and counts['anonymous_import_tests']==89,'Root filtered aggregates/imports differ')
    require(len(final_runs)==10 and [r['tests'] for r in final_runs]==[10]*5+[92]*4+[738],'Final terminal validation matrix differs')
    intermediate_runs={}
    for name,data in raw.items():
        if name.startswith(('after-','modes-')) and name.endswith('.log'):
            match=re.search(rb'All (\d+) tests passed\.\n$',data)
            if match:intermediate_runs[name]=successful_tests(data,int(match[1]))
    screen=completed_screen(root,archives,base,final,originals)
    require(validation['nonregression']==json.loads(raw['independent-stats.json']) and validation['smoke']==json.loads(archives['smoke-raw.tar.gz']['validation.json']),'Original combined validation scope differs')
    saved_commit=None;saved_git_count=0
    identity_path=root/'saved-source-commit.json'
    if identity_path.exists():
        identity=json.loads(identity_path.read_bytes());require(identity['source_sha256']==validation['source_sha256'] and identity['commit']==binding['saved_final_source_commit'] and 'later saved Git commit identity' in identity['artifact_kind'],'Later saved final-source commit identity differs')
        saved_commit=identity['commit'];saved_git_count=git_verify(git_repo,saved_commit,final)
    git_count=git_verify(git_repo,BASE,base)
    return {'schema':'vort.deflate.distance-secondary-hole-archive-validation.v1','valid':True,'scope':'offline original-byte/source/recorded-contract/statistics verification; no compiler, codec, test, oracle or benchmark execution','cpu_affinity':sorted(os.sched_getaffinity(0)),'base_revision':BASE,'baseline_registry_files':2064,'final_registry_files':2069,'complete_compiler_input_claim':False,'baseline_git_blobs_verified':git_count,'saved_final_source_commit':saved_commit,'saved_final_source_git_blobs_verified':saved_git_count,'original_files_verified':original_count,'source_overlay_files':{'before_v2':len(before),'final':len(final)},'initial_compile_failures_excluded':3,'before_v2':before_rows,'public_cases':6,'root_duplicate_public_calls':6,'direct_mode_cases':18,'intermediate_direct_mode_cases':15,'final_runs':final_runs,'intermediate_success_logs':intermediate_runs,'oracle':oracle,'completed_nonregression_and_smoke':screen,'performance_gain_claimed':False,'unmatched_before_debug_binary_used_for_claims':False}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--originals',action='store_true');parser.add_argument('--git-repo',type=Path);args=parser.parse_args()
    print(json.dumps(verify(Path(__file__).resolve().parent,args.originals,args.git_repo),indent=2))
