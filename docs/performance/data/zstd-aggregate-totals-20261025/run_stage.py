from pathlib import Path
import datetime,hashlib,json,statistics,subprocess
base=Path('/tmp/vort-zstd-aggregate-totals-20261025')
root=Path('/home/passchaos/project-z/vort-zstd-aggregate-totals')
old=Path('/home/passchaos/project-z/vort-zstd-work-accounting/.zig-cache/o/42dba0c9e137947dfe1bf8b30ef44400/vort-zstd-multi-duplicate-profile')
new=Path(json.loads((base/'profile-executable.json').read_text())['path'])
corpus=Path('/tmp/vort-wide-bit-final-20261025/next-performance-audit/corpus-preparation')
paths=[corpus/(name+'-65536.bin') for name in ('silesia-xml','silesia-mr','brotli-source')]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():return {str(p.relative_to(root)):sha(p) for p in (root/'src').rglob('*.zig')}
before=snapshot();out=base/'stage';out.mkdir(exist_ok=True);runs=[]
for pair in range(3):
 for kind in (['old','new'] if pair%2==0 else ['new','old']):
  exe=old if kind=='old' else new
  command=['taskset','-c','8',str(exe),*[str(p) for p in paths]]
  meta={'pair':pair,'kind':kind,'command':command,'exe_sha256':sha(exe),'start_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
  observations=[]
  with (out/f'{pair}-{kind}.json').open('wb') as log:
   process=subprocess.Popen(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
   while True:
    observations.append(subprocess.run(['ps','-C','zig,clang,clang++,cc1,cc1plus','-o','pid=,comm='],capture_output=True,text=True).stdout.strip())
    try:code=process.wait(timeout=0.1);break
    except subprocess.TimeoutExpired:pass
  meta.update(exit_code=code,compiler_observations=len(observations),compiler_observations_with_process=sum(bool(x) for x in observations),end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
  assert code==0 and not any(observations)
  runs.append(meta)
after=snapshot();assert before==after
rows=[]
for path in paths:
 times={'old':[],'new':[]};reference=None
 for run in runs:
  report=json.loads((out/f"{run['pair']}-{run['kind']}.json").read_text())
  row=next(r for r in report['rows'] if r['path']==str(path))
  if reference is None:reference=row
  assert row['input_sha256']==sha(path) and row['wire_sha256']==reference['wire_sha256'] and row['encoded_bytes']==reference['encoded_bytes']
  for key,value in reference['work'].items():
   if key=='cache_state_bytes':continue
   assert row['work'][key]==value,key
  times[run['kind']].append(row['profiled_ns'])
 rows.append({'path':str(path),'times_ns':times,'old_median_ns':int(statistics.median(times['old'])),'new_median_ns':int(statistics.median(times['new'])),'speedup':statistics.median(times['old'])/statistics.median(times['new']),'all_existing_work_fields_unchanged_except_object_size':True,'wire_unchanged':True})
result={'runs':runs,'rows':rows,'source_before':before,'source_after':after,'source_stable':True,'scope':'Tracked candidate-stage comparison with three alternating version-process pairs, one full stage evaluation per input per process; initialized aggregate and updates included. No whole-API or counter-free speed inference.'}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(rows,indent=2),flush=True)
