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
import csv
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
    repo=root.parents[2];containers={}
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



PROBE='a69c106fec63a70490be2dd57a76e233ddbaaaadcb37439d2d6abab52897a91f'
def close(a,b,message):
    if isinstance(b,list):require(len(a)==len(b),message);[close(x,y,message) for x,y in zip(a,b)]
    elif isinstance(b,(int,float)):require(math.isclose(a,b,rel_tol=1e-12,abs_tol=1e-12),message)
    else:require(a==b,message)

def source_and_reuse(root,binding,archives,containers):
    raw=archives['raw-refresh.tar.gz'];m=json.loads(raw['manifest.json']);base={n.removeprefix('shared-dispatch/'):v for n,v in containers['baseline_source'].items()}
    for key in ['public_overlay','wide_overlay','holes_overlay','tools_overlay']:base.update(containers[key])
    require(m['source']['revision']==BASE and len(base)==2072 and {n:sha(v) for n,v in base.items()}==m['source']['sha256'] and sha(json.dumps(m['source']['sha256'],sort_keys=True).encode())==m['source']['digest'],'Current captured immutable source differs')
    require(sha(archives['probe.tar.gz']['baseline-compare'])==m['probe_sha256']==PROBE and b'Build Summary: 7/7 steps succeeded' in archives['probe-build.tar.gz']['baseline-build.log'],'Current source/probe/build binding differs')
    require(all(v==base[n] for n,v in archives['runner-imports.tar.gz'].items()),'Immutable current runner helper closure differs')
    repo=root.parents[2];old=binding['old_fixture_manifest'];path=repo/old['path'];require(sha(path.read_bytes())==old['sha256'],'Accepted old fixture manifest bytes differ');before=json.loads(path.read_bytes())
    require({f['key']:f for f in before['fixtures']}=={f['key']:f for f in m['fixtures']} and len(m['fixtures'])==216,'Original216 wire fields regenerated or changed')
    seed=binding['old_runner_seed'];path=repo/seed['path'];require(sha(path.read_bytes())==seed['sha256'],'Old fixture seed container differs');seed_doc=json.loads(unpack(path)[seed['member']]);require({f['key']:f for f in seed_doc['fixtures']}=={f['key']:f for f in m['fixtures']},'Original refresh fixture seed differs')
    require(json.loads(raw['references.json'])==m['references'],'Original reference metadata differs')
    for codec,ref in m['references'].items():
        for path,h in ref['file_sha256'].items():require(sha(containers['reference_libraries'][codec+'/'+Path(path).name])==h,'Reference shared-library bytes differ')
    require(raw['startup-affinity.log']==b'Benchmark CPU is outside available affinity\n' and b'os.sched_setaffinity(0,{0})' in raw['refresh.py'] and b'matrix.freeze=frozen_fixture_reuse' in raw['refresh.py'],'Recorded setup affinity/frozen-wire method differs')
    for n in ['summary.json','aggregate-summary.json','producer-validation.json']:require(raw[n]==(root/n).read_bytes(),'Readable original derivative/producer differs')
    return m,base

def task_id(task):return task['fixture']['key'].replace('/','_')+'_'+task['lifecycle']

def expected_argv(task,m):
    f=task['fixture'];argv=['taskset','-c','15',m['probe'],'--codec',f['codec'],'--input',f['input_path'],'--encoded-input',f['encoded_input_path'],'--iterations',str(task['iterations']),'--rounds','6','--warmup','2','--lifecycle',task['lifecycle']];ref=m['references'][f['codec']]
    if f['codec']=='brotli':
        for role in ['encoder','decoder','common']:argv+=['--brotli-'+role,ref[role]]
    else:
        argv+=['--reference',ref['path']]
        if f['codec']=='deflate':argv+=['--reference-version',ref['version']]
    return argv

def validate_report(p,task,m):
    f=task['fixture'];codec=f['codec'];life=task['lifecycle'];require(p['schema']=='vort.decode-compare.v1' and p['codec']==codec and p['lifecycle']==life and p['iterations']==task['iterations'] and p['rounds']==6 and p['warmup']==2,'Raw row task/sample counts differ')
    for field in ['input_path','encoded_input_path','input_bytes','encoded_bytes','input_sha256','encoded_sha256']:require(p[field]==f[field],'Raw fixture field differs')
    match='reference-only-prepared' if codec=='deflate' and life=='prepared' else 'matched-'+life;require(p['lifecycle_match']==match,'Unmatched prepared Deflate mislabeled')
    apis={('deflate','cold'):('decodeRawDeflate','libdeflate_alloc_decompressor+libdeflate_deflate_decompress_ex+libdeflate_free_decompressor'),('deflate','prepared'):('decodeRawDeflate','libdeflate_deflate_decompress_ex;retained-decompressor'),('zstd','cold'):('decodeFrameInto','ZSTD_decompress'),('zstd','prepared'):('NativeFrameDecoder.decodeIntoSlice','ZSTD_decompressDCtx;retained-DCtx'),('brotli','cold'):('brDecodeStreamInto','BrotliDecoderDecompress;one-shot-state-and-internal-heap-per-call')}
    require((p['vort_api'],p['reference_api'])==apis[codec,life],'Declared current API lifecycle differs')
    ref=m['references'][codec];paths=[ref[r] for r in ['encoder','decoder','common']] if codec=='brotli' else [ref['path']];require(p['reference_paths']==paths and p['reference_version']==ref['version'],'Reference version/path differs')
    prefix={'deflate':('libdeflate.so',),'zstd':('libzstd.so',),'brotli':('libbrotlienc.so','libbrotlidec.so','libbrotlicommon.so')}[codec];require({n for n in p['loaded_shared_library_paths'] if Path(n).name.startswith(prefix)}==set(paths),'Mapped foreign library closure differs')
    require(p['reference_version_origin']=='declared-pinned-header' if codec=='deflate' else p['reference_version_origin'].startswith('queried-'),'Reference version origin differs')
    if codec=='brotli':require(p['brotli_encoder_abi_version']==p['brotli_decoder_abi_version']==16785408,'Brotli queried ABI version differs')
    provenance=p['provenance'];require(provenance['executable_sha256']==PROBE and provenance['optimize']=='ReleaseFast' and provenance['zig_version']=='0.16.0' and provenance['cpu_model']==m['environment']['cpu_model'] and provenance['cpu_affinity']=='15' and provenance['target_cpu']=='skylake+pku+sgx' and provenance['target_arch']=='x86_64' and provenance['target_os']=='linux' and provenance['target_abi']=='gnu' and provenance['benchmark_threads']==provenance['affinity_cpu_count']==1 and provenance['codec_thread_policy']=='single','Current probe/build/CPU policy differs')
    require(p['alignment']=={'guard_bytes':64,'input_mod64':0,'encoded_mod64':0,'vort_output_mod64':0,'reference_output_mod64':0} and all(p['validation'][n] is True for n in ['every_iteration_count','full_output_per_batch','guards_per_batch','input_unchanged_per_batch']),'Raw full-output/count/guard/input validation differs')
    exact=codec=='deflate';require(p['exact_consumption']=={'vort':exact,'reference':exact} and p['validation']['exact_consumption_per_batch']==exact and p['validation']['prepared_priming']==(life=='prepared'),'Consumption/priming API scope differs')
    require(p['sampling_mode']=='paired-wall-time' and p['pmu'] is None,'PMU/experimental sampling mixed into current ranking')
    for field,count,start in [('warmup_pairs',2,0),('pairs',6,2)]:
        require(len(p[field])==count,'Dropped raw pairs')
        for i,r in enumerate(p[field]):require(r['pair_id']==start+i and r['first']==('vort' if (start+i)%2==0 else 'reference') and type(r['vort_ns']) is int and r['vort_ns']>0 and type(r['reference_ns']) is int and r['reference_ns']>0 and r['vort_mix']==r['reference_mix']==task['iterations']*(f['input_bytes']+f['input_first_byte'])%(1<<64) and r.get('vort_counters') is None and r.get('reference_counters') is None,'Raw pair order/count/duration scope differs')
    for side in ['vort','reference']:require(p['summary'][side+'_median_ns']==statistics.median(r[side+'_ns'] for r in p['pairs']),'Raw row median differs')


def row_records(archives,m):
    raw=archives['raw-refresh.tar.gz'];files=archives['raw-rows.tar.gz'];hosts=[json.loads(line) for line in raw['host-observations.jsonl'].splitlines()];require(len(hosts)==360 and len(m['tasks'])==360 and len(files)==1800,'Completed raw/host row cardinality differs');host_map={Path(h['argv'][h['argv'].index('-o')+1]).name.removesuffix('.rss.txt'):h for h in hosts};rows={}
    csv_rows=list(csv.DictReader(io.StringIO(raw['matrix.csv'].decode())));require(len(csv_rows)==360,'CSV row cardinality differs')
    for task,cell in zip(m['tasks'],csv_rows):
        key=task_id(task);row=json.loads(files[key+'.json']);p=json.loads(files[key+'.stdout.raw']);require(row['task']==task and row['probe']==p and files[key+'.stderr.raw']==files[key+'.stderr.txt']==b'','Original row/stdout/stderr bytes differ');validate_report(p,task,m)
        argv=expected_argv(task,m);require(row['argv']==argv and p['provenance']['command']==' '.join(argv[3:]),'Original invocation differs');rss=int(files[key+'.rss.txt'].strip());require(row['rss_kib']==rss>0 and row['rss_scope']=='whole isolated child including loaded libraries, input/output buffers, validation and contexts; not codec-only heap','RSS value/scope differs')
        h=host_map[key];require(h['returncode']==0 and h['argv'][h['argv'].index('taskset'):]==argv and not h['before']['compilers'] and not h['after']['compilers'],'Host/exit/compiler boundary binding differs')
        f=task['fixture'];expected={'codec':f['codec'],'name':f['name'],'size':f['size'],'level':str(f['level']),'lifecycle':task['lifecycle'],'input_bytes':str(f['input_bytes']),'encoded_bytes':str(f['encoded_bytes']),'rss_kib':str(rss)}
        require(all(cell[n]==v for n,v in expected.items()),'CSV source/dimension/RSS fields differ');close(float(cell['vort_median_ns']),p['summary']['vort_median_ns'],'CSV Vort median differs');close(float(cell['reference_median_ns']),p['summary']['reference_median_ns'],'CSV reference median differs');close(float(cell['time_ratio']),p['summary']['vort_median_ns']/p['summary']['reference_median_ns'],'CSV median-ratio differs');rows[key]=row
    require(set(rows)==set(host_map),'Extra/missing host observations');return rows


def bootstrap(reports,seed):
    rng=random.Random(seed);strata=[[[math.log(p['vort_ns']/p['reference_ns']) for p in report['pairs'] if p['first']==order] for order in ['vort','reference']] for report in reports];center=math.exp(statistics.mean(statistics.mean(a+b) for a,b in strata));samples=[]
    for _ in range(2000):samples.append(math.exp(statistics.mean(statistics.mean([rng.choice(a) for _ in a]+[rng.choice(b) for _ in b]) for a,b in strata)))
    samples.sort();return {'time_ratio_geomean':center,'throughput_ratio_geomean':1/center,'ci95':[samples[50],samples[1950]],'method':'order-stratified paired log-ratio bootstrap; fixed rows','seed':seed,'resamples':2000}

def derived_statistics(root,archives,m,rows):
    raw=archives['raw-refresh.tar.gz'];summary=json.loads(raw['summary.json']);aggregate=json.loads(raw['aggregate-summary.json']);original_order=raw['aggregate-row-order.json'];require(original_order==(root/'aggregate-row-order.json').read_bytes() and sha(original_order)=='1a01e325f13d1bd4e4ef855bfad2639c88c7d857206488bd7860e23dd08c38e7','Original aggregate row-order bytes differ');order_document=json.loads(original_order);order={'aggregate_order':[n.removesuffix('.json') for n in order_document['rows']],'aggregate_seed':0x20261112};require(order_document['ci_regenerated_exactly'] is True,'Original ordering provenance differs')
    require(summary['complete'] is True and summary['completed_rows']==summary['expected_rows']==360 and summary['sampling_mode']=='paired-wall-time' and summary['perf_group'] is None,'Current matrix completion/sampling scope differs')
    size_groups={}
    for task in m['tasks']:
        f=task['fixture'];key=f['codec']+'/'+task['lifecycle']+'/'+f['size'];size_groups.setdefault(key,[]).append(rows[task_id(task)]['probe'])
    for index,(key,reports) in enumerate(sorted(size_groups.items())):
        expected=bootstrap(reports,0x20261111+index);actual=summary['groups'][key]
        for n,v in expected.items():close(actual[n],v,'Committed size-group raw bootstrap differs')
        require(actual['rows']==24,'Size-group count differs');weak=max(math.exp(statistics.mean(math.log(p['vort_ns']/p['reference_ns']) for p in r['pairs'])) for r in reports);close(actual['weakest_time_ratio'],weak,'Size-group weakest paired ratio differs')
    require(len(order['aggregate_order'])==360 and set(order['aggregate_order'])==set(rows) and order['aggregate_seed']==0x20261112,'Recorded aggregate source-glob order differs');groups={}
    for key in order['aggregate_order']:
        row=rows[key];f=row['task']['fixture'];group=f['codec']+'/'+row['task']['lifecycle'];groups.setdefault(group,[]).append(row)
    for key,records in groups.items():
        expected=bootstrap([r['probe'] for r in records],0x20261112);actual=aggregate['groups'][key]
        for n,v in expected.items():close(actual[n],v,'All-row aggregate raw bootstrap differs')
        require(actual['rows']==72,'Full lifecycle-group count differs');worst=max((math.exp(statistics.mean(math.log(p['vort_ns']/p['reference_ns']) for p in r['probe']['pairs'])),r['task']['fixture']['key']) for r in records);d=aggregate['weakest'][key];require(d['key']==worst[1],'Weakest whole-group row key differs');close(d['time_ratio'],worst[0],'Weakest group time ratio differs');close(d['throughput_ratio'],1/worst[0],'Weakest group throughput ratio differs')
    require(aggregate['source_revision']==BASE and aggregate['source_digest']==m['source']['digest'] and aggregate['probe_sha256']==PROBE and aggregate['rows']==360 and aggregate['measured_pairs']==2160 and aggregate['warmup_pairs']==720,'Aggregate current source/cardinality binding differs')
    return {'groups':aggregate['groups'],'weakest':aggregate['weakest'],'size_group_count':15,'aggregate_group_count':5,'aggregate_seed_each_group':0x20261112,'size_group_base_seed':0x20261111,'aggregate_order':'recorded original source-directory glob order','statistics_recomputed_from_all_raw_pairs':True}


def fixture_registry(root,m,originals):
    fields=json.loads((root/'fixture-fields.json').read_bytes());require(fields['fixtures']==m['fixtures'] and fields['encoded_fixtures']==216 and fields['plain_files']==36 and len(fields['files'])==252 and fields['regenerated'] is False,'Original frozen216-wire/36-plain registry differs')
    for f in fields['fixtures']:
        for n,h,bn in [('input_path','input_sha256','input_bytes'),('encoded_input_path','encoded_sha256','encoded_bytes')]:require(fields['files'][f[n]]=={'sha256':f[h],'bytes':f[bn]},'Original fixture size/hash fields differ')
    if originals:
        for n,r in fields['files'].items():data=Path(n).read_bytes();require(len(data)==r['bytes'] and sha(data)==r['sha256'],'Original captured fixture bytes differ')
    return sum(r['bytes'] for r in fields['files'].values())


def verify(root,originals=False,git_repo=None):
    binding,archives,count=inventory(root,originals);containers=reused(root,binding);m,base=source_and_reuse(root,binding,archives,containers);rows=row_records(archives,m);stats=derived_statistics(root,archives,m,rows);fixture_bytes=fixture_registry(root,m,originals);git=git_verify(git_repo,BASE,base)
    producer=json.loads(archives['raw-refresh.tar.gz']['producer-validation.json'])
    raw=archives['raw-refresh.tar.gz'];require(sha(raw['producer-validation.json'])=='a5f3101b2c1a7c2c07111bbb509e9e2ac6c3ae3406b08b4847256b58201bb4d4','Final original producer receipt differs')
    for n,h in producer['sha256'].items():require(sha(raw[n])==h,'Final producer raw-byte binding differs')
    require(producer['source_revision']==BASE and producer['source_digest']==m['source']['digest'] and producer['probe_sha256']==PROBE and producer['complete_rows']==360 and producer['measured_pairs']==2160 and producer['warmup_pairs']==720 and producer['codec_candidates_included'] is False and producer['dedicated_host_acceptance'] is False,'Final producer source/count/acceptance scope differs')
    return {'schema':'vort.modern-decode-refresh-archive-validation.v1','valid':True,'scope':'offline source/raw pair/statistical bootstrap/recorded lifecycle/probe/fixture/library/RSS/host identity verification; no compiler,test,codec,oracle,perf or benchmark execution','cpu_affinity':sorted(os.sched_getaffinity(0)),'source_revision':BASE,'source_registry_files':2072,'source_git_blobs_verified':git,'probe_sha256':PROBE,'original_files_verified':count,'completed_rows':360,'measured_pairs':2160,'warmup_pairs':720,'fixtures':{'old_wires':216,'old_plain_files':36,'external_files_verified':252 if originals else 0,'external_bytes_verified':fixture_bytes if originals else 0,'regenerated':False},'statistics':stats,'lifecycle_scopes':{'cold':'matched for all three codecs','zstd_prepared':'matched retained contexts','deflate_prepared':'reference-only retention; Vort stays decodeRawDeflate','brotli_prepared':'not included'},'rss_scope':'whole isolated child, not codec-only heap','host_scope':'development host powersave; boundary ticks do not locate timed-batch overlap','startup_affinity_failure_preserved':True,'no_current_copy_trial_code_included':True,'historical_codec_gain_attribution':False,'dedicated_host_or_industry_acceptance':False}
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--originals',action='store_true');parser.add_argument('--git-repo',type=Path);a=parser.parse_args();print(json.dumps(verify(Path(__file__).resolve().parent,a.originals,a.git_repo),indent=2))
