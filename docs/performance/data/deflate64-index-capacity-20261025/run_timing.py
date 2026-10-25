from pathlib import Path
import datetime,hashlib,json,statistics,math,subprocess,time
base=Path('/tmp/vort-deflate64-index-capacity-20261025');root=Path('/home/passchaos/project-z/vort-brotli-context-cache');oldroot=Path('/home/passchaos/project-z/vort');out=base/'timing-pairs';out.mkdir(exist_ok=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot(tree):
 paths=list((tree/'src').rglob('*'))+list((tree/'tools').rglob('*'))+[tree/'build.zig',tree/'build.zig.zon']
 return {str(p.relative_to(tree)):sha(p) for p in paths if p.is_file() and '__pycache__' not in p.parts and p.suffix!='.pyc'}
before={str(t):snapshot(t) for t in [oldroot,root]};exe_hash={label:sha(base/(label+'-index-probe-final')) for label in ['old','new']};runs=[];monitors=[];started=datetime.datetime.now(datetime.timezone.utc).isoformat()
for pair in range(3):
 for label in (['old','new'] if pair%2==0 else ['new','old']):
  exe=base/(label+'-index-probe-final');command=['taskset','-c','8',str(exe),'--iterations','100']
  with out.joinpath(f'{pair}-{label}.json').open('wb') as samples,out.joinpath(f'{pair}-{label}.log').open('wb') as log:
   process=subprocess.Popen(command,cwd=root,stdout=samples,stderr=log)
   while True:
    monitors.append(dict(pair=pair,label=label,monotonic_ns=time.monotonic_ns(),compilers=subprocess.run(['ps','-C','zig,clang,clang++,cc1,cc1plus','-o','pid=,comm='],capture_output=True,text=True).stdout.strip()))
    try:code=process.wait(timeout=.1);break
    except subprocess.TimeoutExpired:pass
  assert code==0,out.joinpath(f'{pair}-{label}.log').read_text();runs.append(dict(pair=pair,label=label,command=command,exit_code=code,samples_sha256=sha(out/f'{pair}-{label}.json')))
after={str(t):snapshot(t) for t in [oldroot,root]};assert before==after;assert all(sha(base/(label+'-index-probe-final'))==digest for label,digest in exe_hash.items());assert all(not m['compilers'] for m in monitors)
reports={(row['pair'],row['label']):json.loads(out.joinpath(f"{row['pair']}-{row['label']}.json").read_text()) for row in runs};rows=[]
for index,old in enumerate(reports[(0,'old')]['one_shot']):
 ratios=[];oldmed=[];newmed=[]
 for pair in range(3):
  a=reports[(pair,'old')]['one_shot'][index];b=reports[(pair,'new')]['one_shot'][index];assert a['name']==b['name'] and (a['input_bytes'],a['input_sha256'],a['wire_bytes'],a['wire_sha256'])==(b['input_bytes'],b['input_sha256'],b['wire_bytes'],b['wire_sha256'])
  for row in (a,b):
   t=row['timing'];assert t['iterations']==100 and len(t['rounds_ns'])==5 and t['median_ns']==statistics.median(t['rounds_ns']) and t['minimum_ns']==min(t['rounds_ns']);assert t['median_ns']>0
  assert a['timing']['mix']==b['timing']['mix'];oldmed.append(a['timing']['median_ns']/100);newmed.append(b['timing']['median_ns']/100);ratios.append(a['timing']['median_ns']/b['timing']['median_ns'])
 rows.append(dict(case=old['name'],ratios=ratios,old_median_ns_per_call=oldmed,new_median_ns_per_call=newmed,median_point_speedup=statistics.median(ratios),geomean_point_speedup=math.exp(statistics.mean(map(math.log,ratios)))))
meta=dict(start_utc=started,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),runs=runs,rows=rows,source_before=before,source_after=after,source_stable=True,executable_sha256=exe_hash,compiler_observations=len(monitors),compiler_observations_with_process=0,scope='Three alternating old/new process pairs; each case100 complete one-shot allocate/encode/checksum/free calls per5raw rounds through plain allocator. Resource tracking/decoder/input preparation excluded from timer; no competitor/all-platform/statistical significance claim.')
out.joinpath('compiler-monitor.json').write_text(json.dumps(monitors)+'\n');out.joinpath('result.json').write_text(json.dumps(meta,indent=2)+'\n');print(rows,flush=True)
