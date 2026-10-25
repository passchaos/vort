from pathlib import Path
import datetime,hashlib,json,statistics,subprocess,time
base=Path('/tmp/vort-br-context-alphabet-20261025');root=Path('/home/passchaos/project-z/vort-brotli-context-cache');exe=Path(json.loads(base.joinpath('micro-executable.json').read_text())['path']);out=base/'microbench';out.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():
 paths=list((root/'src').rglob('*'))+list((root/'tools').rglob('*'))+[root/'build.zig',root/'build.zig.zon']
 return {str(p.relative_to(root)):sha(p) for p in paths if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
before=snapshot();exesha=sha(exe);command=['taskset','-c','8',str(exe),'50000'];started=datetime.datetime.now(datetime.timezone.utc).isoformat();monitors=[]
with out.joinpath('samples.json').open('wb') as report,out.joinpath('run.log').open('wb') as log:
 process=subprocess.Popen(command,cwd=root,stdout=report,stderr=log)
 while True:
  monitors.append(dict(monotonic_ns=time.monotonic_ns(),compilers=subprocess.run(['ps','-C','zig,clang,clang++,cc1,cc1plus','-o','pid=,comm='],capture_output=True,text=True).stdout.strip()))
  try:code=process.wait(timeout=.1);break
  except subprocess.TimeoutExpired:pass
after=snapshot();meta=dict(command=command,exit_code=code,source_before=before,source_after=after,source_stable=before==after,executable_sha256=exesha,executable_stable=exesha==sha(exe),start_utc=started,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),compiler_observations=len(monitors),compiler_observations_with_process=sum(bool(m['compilers']) for m in monitors))
out.joinpath('result.json').write_text(json.dumps(meta,indent=2)+'\n');out.joinpath('compiler-monitor.json').write_text(json.dumps(monitors)+'\n');assert code==0 and before==after and meta['executable_stable'] and meta['compiler_observations_with_process']==0,out.joinpath('run.log').read_text()
r=json.loads(out.joinpath('samples.json').read_text());assert r['schema']=='vort.brotli.literal-alphabet-bench.v1' and r['iterations']==50000 and r['input_pool_size']==32 and r['exact_outputs_equal'];assert r['provenance']['executable_sha256']==exesha
expected={'small16','threshold64','medium96','boundary128','dense_mixed','dense_ties','ascending_weights','sparse_dense_support'};assert len(r['rows'])==len(expected) and {x['case'] for x in r['rows']}==set(expected)
for row in r['rows']:
 assert len(row['input_sha256'])==64
 assert len(row['rounds'])==5
 assert all(x['reference_first']==(i%2==0) and x['reference_ns']>0 and x['candidate_ns']>0 for i,x in enumerate(row['rounds']))
 for field in ['reference','candidate']:assert row[field+'_median_ns']==statistics.median(x[field+'_ns'] for x in row['rounds'])
 row['speedup']=row['reference_median_ns']/row['candidate_median_ns'];print(row['case'],row['speedup'],row['reference_median_ns']/r['iterations'],row['candidate_median_ns']/r['iterations'])
out.joinpath('gate-result.json').write_text(json.dumps(dict(valid=True,rows=r['rows'],scope='All8families/32poolslots verified outside timers, sameprocess five alternating rounds complete supported-symbol alphabet collection/rank and checksum calls. Point comparison, not public encoder throughput.'),indent=2)+'\n')
