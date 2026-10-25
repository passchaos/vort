from pathlib import Path
import datetime,hashlib,json,statistics,subprocess,time

base=Path('/tmp/vort-zstd-anchor-cache-20261025')
root=Path('/home/passchaos/project-z/vort-zstd-anchor-cache')
exe=base/'anchor-profile'
corpus=Path('/tmp/vort-wide-bit-final-20261025/next-performance-audit/corpus-preparation')
paths=[str(corpus/(name+'-65536.bin')) for name in ('silesia-xml','silesia-mr','brotli-source')]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def source():return {str(p.relative_to(root)):sha(p) for p in (root/'src').rglob('*.zig')}
before=source()
command=['taskset','-c','8',str(exe)]
for r in range(5):
 for enabled in ([False,True] if r%2==0 else [True,False]):
  command.append('--anchors' if enabled else '--no-anchors')
  command.extend(paths)
metadata={'command':command,'start_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
          'executable_sha256':sha(exe),'source_before':before,
          'scope':'Five alternating full candidate-stage runs per cache setting and input in one process; cached time includes two allocations, hash preparation, length initialization, all suffix queries and emission. Instrumented counts, not public API comparison.'}
monitors=[]
with (base/'experiment-samples.json').open('wb') as log:
 process=subprocess.Popen(command,cwd=root,stdout=log,stderr=subprocess.STDOUT)
 while True:
  monitor=subprocess.run(['ps','-C','zig,clang,clang++,cc1,cc1plus','-o','pid=,comm='],capture_output=True,text=True).stdout.strip()
  monitors.append({'monotonic_ns':time.monotonic_ns(),'compilers':monitor})
  try:code=process.wait(timeout=0.1);break
  except subprocess.TimeoutExpired:pass
after=source();metadata.update(exit_code=code,source_after=after,source_stable=before==after,
 end_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),compiler_observations=len(monitors),
 compiler_observations_with_process=sum(bool(x['compilers']) for x in monitors))
(base/'experiment-result.json').write_text(json.dumps(metadata,indent=2)+'\n')
(base/'experiment-monitor.json').write_text(json.dumps(monitors)+'\n')
assert code==0 and before==after and not metadata['compiler_observations_with_process']
data=json.loads((base/'experiment-samples.json').read_text())
assert len(data['rows'])==30
results=[]
for path in paths:
 uncached=[r for r in data['rows'] if r['path']==path and not r['anchors']]
 cached=[r for r in data['rows'] if r['path']==path and r['anchors']]
 assert len(uncached)==len(cached)==5
 first=uncached[0]
 for row in uncached+cached:
  assert row['wire_sha256']==first['wire_sha256'] and row['encoded_bytes']==first['encoded_bytes']
  for key in ('cost','cost_bound','finder_calls','selected_matches','histogram_scanned_bytes','histogram_updates','cache_state_bytes'):
   assert row['work'][key]==first['work'][key],key
 a=[r['profiled_ns'] for r in uncached];b=[r['profiled_ns'] for r in cached]
 result={'path':path,'input_sha256':first['input_sha256'],'wire_sha256':first['wire_sha256'],
  'uncached_ns':a,'cached_ns':b,'uncached_median_ns':int(statistics.median(a)),
  'cached_median_ns':int(statistics.median(b)),'version_speedup':statistics.median(a)/statistics.median(b),
  'cached_work':cached[0]['work'],'existing_work_unchanged':True}
 results.append(result)
summary={'rows':results,'scope':metadata['scope'],'executable_sha256':metadata['executable_sha256']}
(base/'experiment-analysis.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2),flush=True)
