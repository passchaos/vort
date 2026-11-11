"""Offline byte and recorded-contract verification; run with taskset -c 0."""
import argparse
import gzip
import hashlib
import io
import json
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

def profile_report(raw,fixtures,iterations,key,samples,period,root_percent,reference_percent):
    document=json.loads(raw['manifest.json']);m,t=document['manifest'],document['task'];p=json.loads(raw['stdout.raw']);v=json.loads(raw['capture-validation.json']);execution=json.loads(raw['execution.json'])
    require(json.loads(raw['command.json'])==document['argv']==execution['argv']==m.get('profile_argv',document['argv']),'Capture command binding differs')
    require(execution['returncode']==v['returncode']==0 and v['raw_json_valid'] is True,'Capture was not successful')
    require(not execution['before']['compilers'] and not execution['after']['compilers'],'Capture boundary compiler observation differs')
    require(v['source_files']==len(m['source']['sha256']) and v['probe_sha256']==m['probe_sha256']==PROBE,'Capture source/probe binding differs')
    for field,name in [('profile_sha256',next(n for n in raw if n.endswith('.data'))),('stdout_sha256','stdout.raw'),('stderr_sha256','stderr.raw'),('capture_script_sha256','capture.py')]:require(v[field]==sha(raw[name]),'Capture hash differs: '+field)
    fixture=t['fixture'];require(fixture['key']==key and t['iterations']==iterations and t['lifecycle']=='cold','Capture task differs')
    for path_field,hash_field,bytes_field in [('input_path','input_sha256','input_bytes'),('encoded_input_path','encoded_sha256','encoded_bytes')]:
        b=fixtures[Path(fixture[path_field]).name];require(sha(b)==fixture[hash_field] and len(b)==fixture[bytes_field],'Captured fixture differs')
    require(fixtures[Path(fixture['input_path']).name][0]==fixture['input_first_byte'],'Fixture first byte differs')
    require(p['input_sha256']==fixture['input_sha256'] and p['encoded_sha256']==fixture['encoded_sha256'] and p['input_bytes']==fixture['input_bytes'] and p['encoded_bytes']==fixture['encoded_bytes'],'Probe fixture binding differs')
    require(p['codec']=='deflate' and p['lifecycle']=='cold' and p['lifecycle_match']=='matched-cold' and p['vort_api']=='decodeRawDeflate','Public-call lifecycle differs')
    require(p['reference_api']=='libdeflate_alloc_decompressor+libdeflate_deflate_decompress_ex+libdeflate_free_decompressor','Reference lifecycle differs')
    r=m['references']['deflate'];require(p['reference_version']==r['version']=='1.26' and p['reference_version_origin']=='declared-pinned-header','Reference version differs')
    require(r['source_revision']=='92e6a0db9fa848d742f9eb286c92afc60f2c3dda' and r['flags']=='-O3 -DNDEBUG -march=skylake' and set(r['file_sha256'].values())=={REFERENCE},'Reference source/build bytes differ')
    require(p['reference_paths']==[r['path']] and {n for n in p['loaded_shared_library_paths'] if Path(n).name.startswith('libdeflate.so')}=={r['path']},'Mapped reference closure differs')
    require(p['exact_consumption']=={'vort':True,'reference':True} and all(p['validation'][n] is True for n in ['every_iteration_count','full_output_per_batch','guards_per_batch','input_unchanged_per_batch','exact_consumption_per_batch']),'Output/count/guard/consumption validation differs')
    require(p['alignment']=={'guard_bytes':64,'input_mod64':0,'encoded_mod64':0,'vort_output_mod64':0,'reference_output_mod64':0},'Alignment differs')
    provenance=p['provenance'];require(provenance['executable_sha256']==PROBE and provenance['optimize']=='ReleaseFast' and provenance['zig_version']=='0.16.0' and provenance['target_cpu']=='skylake+pku+sgx' and provenance['target_arch']=='x86_64' and provenance['target_os']=='linux' and provenance['target_abi']=='gnu' and provenance['cpu_affinity']=='15' and provenance['benchmark_threads']==provenance['affinity_cpu_count']==1,'Target/thread provenance differs')
    require(p['iterations']==iterations and p['rounds']==p['warmup']==2,'Pair counts differ')
    for field,start in [('warmup_pairs',0),('pairs',2)]:
        require(len(p[field])==2,'Missing paired output')
        for i,pair in enumerate(p[field]):require(pair['pair_id']==start+i and pair['first']==('vort' if i==0 else 'reference') and pair['vort_mix']==pair['reference_mix']==iterations*(fixture['input_bytes']+fixture['input_first_byte']),'Order/output count differs')
    for side in ['vort','reference']:require(p['summary'][side+'_median_ns']==statistics.median(pair[side+'_ns'] for pair in p['pairs']),'Recorded profile median differs')
    data=raw[next(n for n in raw if n.endswith('.data'))];require(data[:8]==b'PERFILE2' and f'({samples} samples)'.encode() in raw['stderr.raw'],'Perf identity/sample count differs')
    physical=raw['symbols-physical.txt'];require(f'Event count (approx.): {period}'.encode() in physical and b'Total Lost Samples: 0' in physical and raw['symbols-physical.stderr']==b'','Physical report totals differ')
    require(re.search(fr'{root_percent:.2f}%.*deflate\.semantic\.linear_entry\.aligned'.encode(),physical) and re.search(fr'{reference_percent:.2f}%.*deflate_decompress_bmi2'.encode(),physical),'Whole-process physical percentages differ')
    require(b'Build Summary: 7/7 steps succeeded' in raw['baseline-build.log'],'Capture build did not retain 7/7 success')
    argv=document['argv'];require(argv[:8]==['perf','record','-e','cycles:u','-F','199','--call-graph','dwarf,65528'] and argv[argv.index('--')+1:argv.index('--')+4]==['taskset','-c','15'],'Recorded sampling policy differs')
    return m,p

def verify(root,originals=False,git_repo=None):
    binding,archives,original_count=inventory(root,originals);containers=reused(root,binding)
    raw=archives['nci-raw-profile.tar.gz'];fixtures=archives['nci-fixture-bytes.tar.gz'];deps=archives['nci-runner-dependencies.tar.gz'];extra=archives['build-source-addendum.tar.gz']
    require(raw['capture-validation.json']==(root/'capture-validation.json').read_bytes(),'Readable original capture receipt differs')
    addendum=json.loads(extra['build-source-addendum.json']);require(extra['build-source-addendum.json']==(root/'build-source-addendum.json').read_bytes(),'Readable reconstruction receipt differs')
    m,p=profile_report(raw,fixtures,60000,'deflate/nci/65536/9',1244,30057120959,46.93,36.18)
    base,binary=reconstruct(m['source'],addendum,containers)
    require({n:sha(b) for n,b in extra.items() if n!='build-source-addendum.json'}==addendum['added_build_modules'],'Added build module bytes differ')
    for name in ['evidence.py','fixtures.py','matrix.py']:require(deps[name]==base['tools/decode/'+name],'Capture imported helper differs')
    require(b"'/tmp/vort-zstd-sao-profile-20261112.093d5b9c/manifest.json'" in raw['capture.py'],'Capture seed origin differs')
    require(sha(containers['reference_library']['deflate/libdeflate.so.0'])==REFERENCE,'Pinned libdeflate shared library differs')
    if originals:require(Path(binding['nci_binary_original']).read_bytes()==binary,'Original equivalent baseline probe differs')
    repo=root.parents[3];r=binding['reuse']['reymont_packet'];old=repo/r['path']
    require(set(r['files'])=={f.name for f in old.iterdir() if f.is_file()} and all(sha((old/n).read_bytes())==h for n,h in r['files'].items()),'Previously archived Reymont packet changed')
    oldbind=json.loads((old/'archive-bindings.json').read_bytes());oldraw=unpack(old/'raw-profile.tar.gz');oldfixtures=unpack(old/'fixture-bytes.tar.gz');olddeps=unpack(old/'runner-dependencies.tar.gz')
    for name,files in [('raw-profile.tar.gz',oldraw),('fixture-bytes.tar.gz',oldfixtures),('runner-dependencies.tar.gz',olddeps)]:require({n:sha(b) for n,b in files.items()}==oldbind['archives'][name]['files'],'Reused original Reymont members differ')
    reym,reyprobe=profile_report(oldraw,oldfixtures,30000,'deflate/reymont/65536/6',2681,65407305645,58.02,36.53)
    oldbase={n.removeprefix('shared-dispatch/'):b for n,b in containers['baseline_source'].items()}
    require(reym['source']['revision']==REY_BASE and len(reym['source']['sha256'])==2062 and {n:sha(b) for n,b in oldbase.items()}==reym['source']['sha256'],'Reymont source epoch differs')
    require(sha(json.dumps(reym['source']['sha256'],sort_keys=True).encode())==reym['source']['digest'],'Reymont source digest differs')
    require(deps['seed-manifest.json']==olddeps['seed-manifest.json'],'Shared exact seed manifest differs')
    region_bytes=(root/'regions.json').read_bytes();require(sha(region_bytes)==binding['derived_regions_sha256']=='2c3301f87447e43bca7a531bf653d9007ffcb5d3e6cf1af390d6262a5691b920','Derived region summary bytes differ')
    if originals:require(Path(binding['derived_regions_origin']).read_bytes()==region_bytes,'Original main-authored region summary differs')
    regions=json.loads(region_bytes)
    require('main-authored derived summary' in regions['artifact_kind'] and 'no original partitioning script/nm stdout file claimed' in regions['artifact_kind'],'Region artifact attribution differs')
    require(regions['probe_sha256']==PROBE and regions['root_range']==[18084160,18087797] and regions['root_symbol']=='deflate.semantic.linear_entry.aligned','Region symbol epoch differs')
    require(regions['columns']==['literal','match_fields','consume_preload_refill','short_copy','wide_setup_kernel_fallback','entry_dispatch','copy_dispatch_rle','loop_limits','prologue_cold_tail_error'],'Region partition names differ')
    reports=[]
    for r,annotation,expected,stack,count,total,whole in [(regions['profiles'][0],archives['reymont-offline-annotate.tar.gz'],[28.58,23.7,19.26,12.79,4.31,6.62,2.13,2.3,0.25],[6.37,0.97,3.73],1554,2681,58.02),(regions['profiles'][1],raw,[23.84,15.99,17.8,7.25,20.79,6.26,3.79,3.47,0.86],[6.93,0.36,2.6],578,1244,46.93)]:
        require(r['region_percentages']==expected and r['stack_mov_load_store_cmp_percent']==stack and r['root_samples']==count and r['capture_samples']==total and r['root_whole_process_percent']==whole,'Derived region values differ')
        require(abs(sum(expected)-r['rounded_sum'])<1e-10 and 'overlapping' in r['stack_scope'],'Rounded region totals/overlapping stack attribution differ')
        require(sha(annotation['annotate-physical.txt'])==r['annotate_sha256'] and sha(annotation['annotate-physical.stderr'])==r['annotate_stderr_sha256'] and annotation['annotate-physical.stderr']==b'','Offline annotate byte binding differs')
        require(f'({count} samples, percent: local period)'.encode() in annotation['annotate-physical.txt'] and b'<deflate.semantic.linear_entry.aligned>:' in annotation['annotate-physical.txt'],'Annotate denominator/symbol differs')
        reports.append({'label':r['label'],'root_samples':count,'capture_samples':total,'whole_process_root_percent':whole,'rounded_region_sum':r['rounded_sum'],'stack_statistics_overlap_partition':True})
    git_count=git_verify(git_repo,BASE,base);rey_git_count=git_verify(git_repo,REY_BASE,oldbase)
    return {'schema':'vort.deflate.match-path-profile-archive-validation.v1','valid':True,'scope':'offline byte/source/recorded-statistics verification; no compiler, codec, sampling or benchmark run','cpu_affinity':sorted(os.sched_getaffinity(0)),'nci_revision':BASE,'reymont_revision':REY_BASE,'original_nci_capture_registry_files':2048,'later_reconstructed_nci_inventory_files':2063,'reymont_source_registry_files':2062,'nci_git_blobs_verified':git_count,'reymont_git_blobs_verified':rey_git_count,'original_files_verified':original_count,'nci_fixture_bytes':sum(map(len,fixtures.values())),'profiles':reports,'complete_vort_only_denominator':False,'codec_heap_measured':False,'profile_clocks_are_acceptance_samples':False,'region_original_partitioning_script_preserved':False}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--originals',action='store_true');parser.add_argument('--git-repo',type=Path);args=parser.parse_args()
    print(json.dumps(verify(Path(__file__).resolve().parent,args.originals,args.git_repo),indent=2))
