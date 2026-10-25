from pathlib import Path
import datetime,hashlib,json,statistics,subprocess,time
base=Path('/tmp/vort-zstd-work-accounting-20261025')
root=Path('/home/passchaos/project-z/vort-zstd-work-accounting')
old=Path('/home/passchaos/project-z/vort-zstd-anchor-cache/.zig-cache/o/cb65c150ad435ec3299a71a1ad71caff/vort-zstd-encode-bench')
new=Path(json.loads((base/'candidate-executable.json').read_text())['path'])
reference=Path('/home/passchaos/Work/zstd/lib/obj/conf_5c583a1f84006a106cd7292ce5d65f11/dynamic/libzstd.so.1.6.0')
corpus=Path('/tmp/vort-wide-bit-final-20261025/next-performance-audit/corpus-preparation')
inputs=[corpus/(name+'-65536.bin') for name in ('silesia-mr','silesia-xml','brotli-source')]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def snapshot():return {str(p.relative_to(root)):sha(p) for p in (root/'src').rglob('*.zig')}
before=snapshot();out=base/'repeated-focus';out.mkdir(exist_ok=True)
results=[]
for pair in range(3):
 for kind in (['old','new'] if pair%2==0 else ['new','old']):
  exe=old if kind=='old' else new
  name=f'{pair}-{kind}'
  command=['taskset','-c','8',str(exe),'--level','3','--rounds','5','--iterations','1','--limit','65536','--libzstd',str(reference),'--samples-json',str(out/(name+'.json')),'--csv',str(out/(name+'.csv'))]
  for path in inputs:command.extend(['--path',str(path)])
  meta={'pair':pair,'kind':kind,'command':command,'start_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'exe_sha256':sha(exe)}
  monitors=[]
  with (out/(name+'.log')).open('wb') as log:
   process=subprocess.Popen(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
   while True:
    monitors.append(subprocess.run(['ps','-C','zig,clang,clang++,cc1,cc1plus','-o','pid=,comm='],capture_output=True,text=True).stdout.strip())
    try:code=process.wait(timeout=0.1);break
    except subprocess.TimeoutExpired:pass
  meta.update(exit_code=code,end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),compiler_observations=len(monitors),compiler_observations_with_process=sum(bool(x) for x in monitors))
  assert code==0 and not any(monitors)
  results.append(meta)
after=snapshot();assert after==before
summary=[]
for name in ('silesia-mr','silesia-xml','brotli-source'):
 values={'old':[],'new':[]};wires=None
 for run in results:
  data=json.loads((out/(f"{run['pair']}-{run['kind']}.json")).read_text())
  row=next(row for row in data['rows'] if row['input_sha256']==sha(corpus/(name+'-65536.bin')))
  if wires is None:wires=row['wires']
  assert row['wires']==wires
  times=[r['vort_ns'] for r in row['rounds']];assert row['summary']['vort_median_ns']==int(statistics.median(times))
  values[run['kind']].append(row['summary']['vort_median_ns'])
 summary.append({'input':name,'process_medians_ns':values,'median_of_process_medians_old_ns':int(statistics.median(values['old'])),'median_of_process_medians_new_ns':int(statistics.median(values['new'])),'version_point_speedup':statistics.median(values['old'])/statistics.median(values['new']),'pair_speedups':[a/b for a,b in zip(values['old'],values['new'])],'wire_unchanged':True})
report={'runs':results,'rows':summary,'source_before':before,'source_after':after,'source_stable':True,'reference_sha256':sha(reference),'scope':'Three alternating version-process pairs for three fixed64KiB workloads, five Vort/reference rounds per row/process. Median of process medians supplements one-process14-row screen; no all-platform or confidence-interval claim.'}
(out/'result.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(summary,indent=2),flush=True)
