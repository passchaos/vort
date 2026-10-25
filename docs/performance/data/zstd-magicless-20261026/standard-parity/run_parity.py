from datetime import datetime,timezone
import hashlib,importlib.util,json,pathlib,subprocess,sys
sys.dont_write_bytecode=True
BASE=pathlib.Path('/tmp/vort-zstd-magicless-20261026')
OUT=BASE/'standard-parity'
OLD=pathlib.Path('/home/passchaos/project-z/vort')
NEW=pathlib.Path('/home/passchaos/project-z/vort-brotli-context-cache')
def identity(path):
 path=pathlib.Path(path);data=path.read_bytes();return {'path':str(path),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
def digest(data):return hashlib.sha256(data).hexdigest()
def verify(path,root,new=False):
 data=json.loads(path.read_text());files=data['source']['files'] if new else data['files'];bad=[]
 for row in files:
  p=root/row['path'];actual=digest(p.read_bytes()) if p.exists() else None
  if actual!=row['sha256']:bad.append({'path':row['path'],'expected':row['sha256'],'actual':actual})
 return {'manifest':identity(path),'files_verified':len(files),'all_files_match':not bad,'differences':bad,'epoch':data['source_epoch'] if new else data['commit']}
def main():
 compile_path=OUT/'compilations.json';compiled=json.loads(compile_path.read_text());assert all(row['exit_code']==0 for row in compiled['compilations'])
 source_before={'old':verify(OUT/'old-source-manifest-pinned.json',OLD),'new':verify(OUT/'new-runtime-source-pinned.json',NEW,True)}
 assert all(row['all_files_match'] for row in source_before.values()),source_before
 spec=importlib.util.spec_from_file_location('magicless_reference',NEW/'tools/zstd/magicless_diff.py');gate=importlib.util.module_from_spec(spec);spec.loader.exec_module(gate)
 ref=gate.Reference(pathlib.Path('/home/passchaos/Work/zstd/lib/libzstd.so.1.6.0'),pathlib.Path('/home/passchaos/Work/zstd/lib/zstd.h'))
 parent_path=BASE/'native-final/differential.json';parent=json.loads(parent_path.read_text());parent_identity=identity(parent_path)
 inputs={}
 for name in ('tiny','random','repeat','json','source','dict-raw','dict-full'):
  source=BASE/'native-final'/(name+'.input');assert identity(source)==parent['inputs'][name];body=source.read_bytes();destination=OUT/(name+'.input');destination.write_bytes(body);inputs[name]={'path':destination,'body':body,'original':identity(source)}
 dictionaries={}
 for kind in ('raw','full'):
  source=BASE/'native-final'/('dictionary-'+kind+'.bin');assert identity(source)==parent['dictionaries'][kind];path=OUT/source.name;body=source.read_bytes();path.write_bytes(body);dictionaries[kind]={'path':path,'body':body,'original':identity(source)}
 cases=[]
 for name in ('tiny','random','repeat','json','source'):
  for selection in ('raw_or_rle','literal_only','fast_compressed'):
   for checksum in (False,True):
    cases.append((name+'-'+selection+'-'+str(int(checksum)),name,{'mode':'native','api':'one_shot','selection':selection,'checksum':checksum,'content_size':checksum},None,'native-selections'))
 for name in ('tiny','repeat'):
  for level in (-1,0,1,3,19):cases.append((name+'-level'+str(level),name,{'mode':'level','api':'one_shot','level':level,'checksum':True,'content_size':True},None,'level-policy'))
 for kind in ('raw','full'):
  for api in ('one_shot','reuse','into','incremental'):
   cases.append(('dictionary-'+kind+'-'+api,'dict-'+kind,{'mode':'native','api':api,'selection':'auto','checksum':True,'content_size':api!='incremental','dictionary_path':str(dictionaries[kind]['path']),'full_dictionary':kind=='full'},kind,'dictionary-output-routes'))
 assert len(cases)==48
 rows=[];commands=[]
 for target in ('native','x86'):
  directory=OUT/target;directory.mkdir(exist_ok=True)
  for name,input_name,c,kind,scope in cases:
   payload=inputs[input_name]['body'];config=directory/(name+'.config.json');config.write_text(json.dumps(c,indent=2)+'\n')
   row={'target':target,'name':name,'scope':scope,'settings':c,'input':identity(inputs[input_name]['path']),'config':identity(config),'dictionary':identity(dictionaries[kind]['path']) if kind else None,'old':None,'new':None,'wire_equal':False,'status':'pending'}
   for version in ('old','new'):
    compilation=next(entry for entry in compiled['compilations'] if entry['version']==version and entry['target']==target);exe=compilation['executable'];assert identity(exe['path'])==exe
    path=directory/(name+'-'+version+'.zst');assert not path.exists(),path
    command=['taskset','-c','10-15',exe['path'],str(inputs[input_name]['path']),str(path),str(config)];proc=subprocess.run(command,capture_output=True,check=False,timeout=120,cwd=NEW)
    stdout=directory/(name+'-'+version+'.stdout');stderr=directory/(name+'-'+version+'.stderr');stdout.write_bytes(proc.stdout);stderr.write_bytes(proc.stderr)
    call={'command':command,'exit_code':proc.returncode,'stdout':identity(stdout),'stderr':identity(stderr)};commands.append(call)
    parsed=None
    if proc.returncode==0:
     try:parsed=json.loads(proc.stdout)
     except json.JSONDecodeError:pass
    record={'executable':exe,'invocation':call,'probe':parsed,'wire':None,'reference_decode':None,'independent_wire':None,'identity_and_old_default_decoders_verified':False}
    if path.exists():
     wire=path.read_bytes();record['wire']=identity(path);record['reference_decode']=ref.decode(wire,payload,'standard',dictionaries[kind]['body'] if kind else b'')
     try:record['independent_wire']=gate.inspect(wire,'standard')
     except AssertionError as failure:record['parser_error']=str(failure)
     record['identity_and_old_default_decoders_verified']=parsed is not None and parsed['error'] is None and parsed['input_sha256']==digest(payload) and parsed['wire_sha256']==digest(wire) and parsed['wire_bytes']==len(wire) and parsed['old_default_alloc_reuse_into_decode_verified'] and parsed['caller_guards_verified']
    row[version]=record
   def valid(record):return record['identity_and_old_default_decoders_verified'] and record['reference_decode']['complete_contents_verified'] and record['independent_wire'] is not None
   if not valid(row['old']):row['status']='old_failure'
   elif not valid(row['new']):row['status']='new_failure'
   else:
    oldwire=pathlib.Path(row['old']['wire']['path']).read_bytes();newwire=pathlib.Path(row['new']['wire']['path']).read_bytes();row['wire_equal']=oldwire==newwire;row['status']='matched' if row['wire_equal'] else 'wire_mismatch'
    if not row['wire_equal']:
     index=next((index for index,pair in enumerate(zip(oldwire,newwire)) if pair[0]!=pair[1]),min(len(oldwire),len(newwire)));row['first_differing_byte']=index;row['old_difference_hex']=oldwire[max(0,index-8):index+16].hex();row['new_difference_hex']=newwire[max(0,index-8):index+16].hex()
   if row['status']!='matched':print(json.dumps({'target':target,'name':name,'status':row['status'],'old_error':row['old']['probe']['error'] if row['old']['probe'] else None,'new_error':row['new']['probe']['error'] if row['new']['probe'] else None}),flush=True)
   rows.append(row)
  print(json.dumps({'target_finished':target,'rows':sum(row['target']==target for row in rows),'matched':sum(row['target']==target and row['status']=='matched' for row in rows)}),flush=True)
 source_after={'old':verify(OUT/'old-source-manifest-pinned.json',OLD),'new':verify(OUT/'new-runtime-source-pinned.json',NEW,True)}
 counts={'comparisons':len(rows),'matched':sum(row['status']=='matched' for row in rows),'wire_mismatches':sum(row['status']=='wire_mismatch' for row in rows),'old_failures':sum(row['status']=='old_failure' for row in rows),'new_failures':sum(row['status']=='new_failure' for row in rows),'independent_full_decodes':sum(record['reference_decode'] is not None for row in rows for record in (row['old'],row['new']))}
 result={'schema':'vort.zstd.standard-legacy-parity.v1','created_utc':datetime.now(timezone.utc).isoformat(),'scope':{'cases_per_target':48,'native_selection_cases_per_target':30,'level_cases_per_target':10,'dictionary_output_cases_per_target':8,'native_selections':['raw_or_rle','literal_only','fast_compressed'],'levels':[-1,0,1,3,19],'dictionary_apis':['one_shot','reuse','into','incremental'],'dictionary_kinds':['raw','full'],'format':'standard/default omitted in same helper','format_bridge_or_feature_backport':False},'counts':counts,'source_before':source_before,'source_after':source_after,'sources_preserved':source_before==source_after,'compilations':compiled,'compilation_manifest':identity(compile_path),'reference':ref.describe(),'original_native_reference_artifacts':parent_identity,'inputs':{name:{'copied':identity(value['path']),'original':value['original']} for name,value in inputs.items()},'dictionaries':{kind:{'copied':identity(value['path']),'original':value['original']} for kind,value in dictionaries.items()},'harness':identity(pathlib.Path(__file__)),'measurement_scope':'Complete wire equality, old-public default alloc/reuse/into decode correctness and independent plaintext; no timing, throughput or resource parity claim.','counterexamples':[row['name']+':'+row['target'] for row in rows if row['status']!='matched'],'rows':rows,'commands':commands}
 path=OUT/'standard-parity.json';path.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'report':str(path),'sha256':identity(path)['sha256'],**counts,'sources_preserved':result['sources_preserved']}),flush=True)
 assert counts['matched']==len(rows) and result['sources_preserved'],counts
if __name__=='__main__':main()
