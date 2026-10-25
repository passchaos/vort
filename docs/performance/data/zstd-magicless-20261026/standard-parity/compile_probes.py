import hashlib,json,pathlib,shutil,subprocess
BASE=pathlib.Path('/tmp/vort-zstd-magicless-20261026')
OUT=BASE/'standard-parity'
OLD=pathlib.Path('/home/passchaos/project-z/vort')
NEW=pathlib.Path('/home/passchaos/project-z/vort-brotli-context-cache')
def identity(path):
 body=path.read_bytes();return {'path':str(path),'bytes':len(body),'sha256':hashlib.sha256(body).hexdigest()}
old_path=BASE/'old-source-manifest.json';old=json.loads(old_path.read_text())
for row in old['files']:assert identity(OLD/row['path'])['sha256']==row['sha256'],row['path']
(OUT/'old-source-manifest-pinned.json').write_bytes(old_path.read_bytes())
new_path=BASE/'native-final/differential.json';new=json.loads(new_path.read_text())
for row in new['source']['files']:assert identity(NEW/row['path'])['sha256']==row['sha256'],row['path']
(OUT/'new-runtime-source-pinned.json').write_text(json.dumps({'source_epoch':new['source_epoch'],'source':new['source'],'parent_report':identity(new_path)},indent=2)+'\n')
processes=[]
for version,root in [('old',OLD),('new',NEW)]:
 for target,objdir in [('native','33e32ed78a23709c26493c240025d76d'),('x86','d4e3f7d5e4df68349b39c68fe7936c3c')]:
  obj=NEW/'.zig-cache/o'/objdir/'vort-zstd-huffman-x2-releasefast.o'
  flags=[] if target=='native' else ['-target','x86-linux-gnu','-mcpu','baseline']
  name=version+'-'+target;exe=OUT/('probe-'+name);log=OUT/('compile-'+name+'.log')
  command=['taskset','-c','10-15','zig','build-exe','-j1','-OReleaseFast',*flags,'--dep','zstd','-Mroot='+str(OUT/'standard_probe.zig'),str(obj),'-OReleaseFast',*flags,'-Mzstd='+str(root/'src/zstd.zig'),'--cache-dir',str(OUT/('cache-'+name)),'--global-cache-dir',str(OUT/'global-cache'),'--name','vort-standard-parity-'+name,'-femit-bin='+str(exe)]
  handle=log.open('wb');process=subprocess.Popen(command,cwd=NEW,stdout=handle,stderr=subprocess.STDOUT)
  processes.append((process,handle,{'version':version,'target':target,'command':command,'log_path':log,'exe_path':exe,'object':identity(obj)}))
rows=[]
for process,handle,row in processes:
 code=process.wait();handle.close();row['exit_code']=code;row['log']=identity(row.pop('log_path'));exe=row.pop('exe_path');row['executable']=identity(exe) if exe.exists() else None;rows.append(row)
 print(json.dumps({'version':row['version'],'target':row['target'],'exit_code':code,'log':row['log'],'executable':row['executable']}),flush=True)
result={'same_helper':identity(OUT/'standard_probe.zig'),'helper_has_no_new_format_api_or_bridge':True,'compiler':identity(pathlib.Path(shutil.which('zig')).resolve()),'cpu_affinity':'10-15','concurrent_compiles':4,'jobs_per_compile':1,'old_source':identity(OUT/'old-source-manifest-pinned.json'),'new_source':identity(OUT/'new-runtime-source-pinned.json'),'compilations':rows}
(OUT/'compilations.json').write_text(json.dumps(result,indent=2)+'\n')
assert all(row['exit_code']==0 for row in rows),rows
