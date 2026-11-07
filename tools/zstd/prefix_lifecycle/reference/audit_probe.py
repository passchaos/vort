#!/usr/bin/env python3
"""Retained Hooke audit; only library and testdata paths are parameterized."""
import ctypes as C, json, random, struct, hashlib, contextlib, sys
from pathlib import Path
LIB=sys.argv[1]
z=C.CDLL(LIB)
V=C.c_void_p; S=C.c_size_t; I=C.c_int; U=C.c_uint; Q=C.c_ulonglong
def api(name,args,res=S):
 f=getattr(z,name);f.argtypes=args;f.restype=res;return f
api('ZSTD_versionString',[],C.c_char_p)
api('ZSTD_isError',[S],U);api('ZSTD_getErrorName',[S],C.c_char_p)
for side in ['C','D']:
 api('ZSTD_create'+side+'Ctx',[],V);api('ZSTD_free'+side+'Ctx',[V])
 api('ZSTD_'+side+'Ctx_reset',[V,I]);api('ZSTD_'+side+'Ctx_setParameter',[V,I,I])
 api('ZSTD_'+side+'Ctx_loadDictionary',[V,V,S])
 api('ZSTD_'+side+'Ctx_refPrefix',[V,V,S])
 api('ZSTD_'+side+'Ctx_refPrefix_advanced',[V,V,S,I])
api('ZSTD_CCtx_setPledgedSrcSize',[V,Q])
api('ZSTD_compressBound',[S])
api('ZSTD_compress2',[V,V,S,V,S]);api('ZSTD_decompressDCtx',[V,V,S,V,S])
class In(C.Structure):_fields_=[('src',V),('size',S),('pos',S)]
class Out(C.Structure):_fields_=[('dst',V),('size',S),('pos',S)]
api('ZSTD_compressStream2',[V,C.POINTER(Out),C.POINTER(In),I])
api('ZSTD_decompressStream',[V,C.POINTER(Out),C.POINTER(In)])
api('ZSTD_getDictID_fromFrame',[V,S],U)
held=[]
def buf(data):
 b=C.create_string_buffer(data or b'\0');held.append(b);return b
def err(r):return z.ZSTD_getErrorName(r).decode() if z.ZSTD_isError(r) else None
def result(r,**kw):
 d={'ret':int(r),'error':err(r)};d.update(kw);return d
records=[]
def emit(label,data):
 row={'case':label,**data};records.append(row);print(json.dumps(row,sort_keys=True),flush=True)
def must(r):
 if err(r):raise RuntimeError(err(r))
 return r
@contextlib.contextmanager
def ctx(side,fmt=0):
 c=getattr(z,'ZSTD_create'+side+'Ctx')()
 try:
  if side=='C':
   must(z.ZSTD_CCtx_setParameter(c,100,3));must(z.ZSTD_CCtx_setParameter(c,201,1))
   must(z.ZSTD_CCtx_setParameter(c,10,fmt))
  else:must(z.ZSTD_DCtx_setParameter(c,1000,fmt))
  yield c
 finally:getattr(z,'ZSTD_free'+side+'Ctx')(c)
def prefix(side,c,data,kind=1,null=False,size=None):
 p=None if null else buf(data)
 n=len(data) if size is None else size
 if kind=='default':return getattr(z,'ZSTD_'+side+'Ctx_refPrefix')(c,p,n)
 return getattr(z,'ZSTD_'+side+'Ctx_refPrefix_advanced')(c,p,n,kind)
def load(side,c,data):return getattr(z,'ZSTD_'+side+'Ctx_loadDictionary')(c,buf(data),len(data))
def enc(c,data,capacity=None):
 out=C.create_string_buffer(z.ZSTD_compressBound(len(data)) if capacity is None else max(capacity,1))
 n=z.ZSTD_compress2(c,out,len(out) if capacity is None else capacity,buf(data),len(data))
 return result(n),out.raw[:n] if not err(n) else b''
def dec(c,data,expected,capacity=None):
 cap=max(1,len(expected)*2+1024) if capacity is None else capacity
 out=C.create_string_buffer(max(1,cap))
 n=z.ZSTD_decompressDCtx(c,out,cap,buf(data),len(data))
 return result(n,correct=(not err(n) and out.raw[:n]==expected)),out.raw[:n] if not err(n) else b''
def dcall(c,data,cap=1000000):
 src=buf(data);dst=C.create_string_buffer(max(1,cap));ib=In(C.cast(src,V),len(data),0);ob=Out(C.cast(dst,V),cap,0)
 n=z.ZSTD_decompressStream(c,C.byref(ob),C.byref(ib))
 return result(n,input=int(ib.pos),output=int(ob.pos)),dst.raw[:ob.pos]
def ddrive(c,data,expected,chunk=1,outcap=113):
 off=0;partpos=0;total=b'';frames=0;calls=0;last=None
 while off<len(data) or (last is not None and not err(last['ret']) and last['ret']!=0):
  available=data[off:off+chunk]
  r,out=dcall(c,available,outcap);calls+=1;last=r;off+=r['input'];total+=out
  if err(r['ret']):break
  if r['ret']==0:frames+=1
  if r['input']==0 and r['output']==0:
   if off==len(data):break
   raise RuntimeError('no progress '+str(r))
  if calls>200000:raise RuntimeError('too many calls')
 return {**last,'accepted':off,'total_output':len(total),'correct':total==expected,'frames':frames,'calls':calls}
def ccall(c,data,op=0,cap=1000000):
 src=buf(data);dst=C.create_string_buffer(max(1,cap));ib=In(C.cast(src,V),len(data),0);ob=Out(C.cast(dst,V),cap,0)
 n=z.ZSTD_compressStream2(c,C.byref(ob),C.byref(ib),op)
 return result(n,input=int(ib.pos),output=int(ob.pos)),dst.raw[:ob.pos]
def cdrive(c,data):
 r,head=ccall(c,data,0,101)
 if err(r['ret']):return r,b''
 off=r['input'];parts=[head]
 while off<len(data):
  r,part=ccall(c,data[off:],0,101);off+=r['input'];parts.append(part)
  if err(r['ret']):return r,b''
 while True:
  r,part=ccall(c,b'',2,101);parts.append(part)
  if err(r['ret']) or r['ret']==0:return r,b''.join(parts)
def frame(prefix_data,payload,kind='default',fmt=0):
 with ctx('C',fmt) as c:
  must(prefix('C',c,prefix_data,kind));r,b=enc(c,payload);must(r['ret']);return b
def noframe(payload,fmt=0):
 with ctx('C',fmt) as c:
  r,b=enc(c,payload);must(r['ret']);return b
A=random.Random(81).randbytes(16384);B=random.Random(82).randbytes(16384)
PA=A[-4096:]*2;PB=B[-4096:]*2
root=Path(sys.argv[2])
FULL=bytes.fromhex((root/'libzstd-trained-repeat.dict.hex').read_text())
REF=bytes.fromhex((root/'libzstd-trained-repeat.frame.hex').read_text())
with ctx('D') as d:
 must(load('D',d,FULL));r,PF=dec(d,REF,b'',1000000);must(r['ret'])
SKIP=struct.pack('<II',0x184d2a53,3)+b'xyz'
SKIP0=struct.pack('<II',0x184d2a50,0)
families=[('raw',A,PA,'default'),('full_default_RAW',FULL,PF,'default'),('full_advanced_FULL',FULL,PF,2)]
emit('environment',{'version':z.ZSTD_versionString().decode(),'lib':LIB,'raw_prefix':len(A),'raw_payload':len(PA),'full_dict':len(FULL),'full_payload':len(PF)})

for name,p,payload,kind in families:
 for fmt in [0,1]:
  f=frame(p,payload,kind,fmt);f0=noframe(payload,fmt)
  with ctx('D',fmt) as d:
   must(prefix('D',d,p,kind));ok,_=dec(d,f,payload);again,_=dec(d,f,payload)
  with ctx('D',fmt) as d:missing,_=dec(d,f,payload)
  with ctx('C',fmt) as c:
   must(prefix('C',c,p,kind));r,f1=enc(c,payload);r2,f2=enc(c,payload)
  emit(name+'.baseline.'+str(fmt),{'prefix_frame':len(f),'plain_frame':len(f0),'first':ok,'second':again,'missing':missing,'encoder_first_same':f1==f,'encoder_second_plain':f2==f0})

for name,p,payload,kind in [families[0],families[2]]:
 for fmt in [0,1]:
  f=frame(p,payload,kind,fmt)
  with ctx('D',fmt) as d:
   must(prefix('D',d,p,kind));r,_=dec(d,f+f,payload*2);after,_=dec(d,f,payload)
  emit(name+'.concat.oneshot.'+str(fmt),{'concat':r,'after':after})
  for chunk in [1,len(f)*2]:
   with ctx('D',fmt) as d:
    must(prefix('D',d,p,kind));r=ddrive(d,f+f,payload*2,chunk,113)
   emit(name+'.concat.stream.'+str(fmt)+'.'+str(chunk),r)
  for skip,label in [(SKIP,'payload'),(SKIP0,'empty')]:
   with ctx('D',fmt) as d:
    must(prefix('D',d,p,kind));r,_=dec(d,skip+f,payload);must(z.ZSTD_DCtx_reset(d,1));after,_=dec(d,f,payload)
   emit(name+'.skip_'+label+'.oneshot_join.'+str(fmt),{'joined':r,'after_session_reset':after})
   with ctx('D',fmt) as d:
    must(prefix('D',d,p,kind));r,_=dec(d,skip,b'');after,_=dec(d,f,payload)
   emit(name+'.skip_'+label+'.oneshot_separate.'+str(fmt),{'skip':r,'data':after})
   for chunk in [1,len(skip)+len(f)]:
    with ctx('D',fmt) as d:
     must(prefix('D',d,p,kind));r=ddrive(d,skip+f,payload,chunk,113);must(z.ZSTD_DCtx_reset(d,1));after,_=dec(d,f,payload)
    emit(name+'.skip_'+label+'.stream_join.'+str(fmt)+'.'+str(chunk),{'joined':r,'after_session_reset':after})
with ctx('C') as c:
 must(prefix('C',c,A,'default'));r,empty=enc(c,b'');r2,nextf=enc(c,PA)
 emit('encoder.empty_data_frame_consumes',{'empty':r,'next_plain':nextf==noframe(PA)})

for name,p,payload,kind in [families[0],families[2]]:
 for fmt in [0,1]:
  f=frame(p,payload,kind,fmt);baseline=noframe(payload,fmt)
  for label,data,null,size in [('NULL_zero',b'',True,0),('empty_nonnull',b'',False,0),('NULL_nonzero',b'',True,37),('nonnull_zero',p,False,0)]:
   with ctx('C',fmt) as c:
    must(load('C',c,p));setr=prefix('C',c,data,kind,null,size);r,cleared=enc(c,payload)
   with ctx('D',fmt) as d:
    must(load('D',d,p));setd=prefix('D',d,data,kind,null,size);r2,_=dec(d,f,payload)
   emit(name+'.clear.'+str(fmt)+'.'+label,{'C_ref':result(setr),'C_encode':r,'C_plain':cleared==baseline,'D_ref':result(setd),'D_decode':r2})
  for directive in [1,2,3]:
   with ctx('C',fmt) as c:
    must(prefix('C',c,p,kind));reset=z.ZSTD_CCtx_reset(c,directive)
    must(z.ZSTD_CCtx_setParameter(c,100,3));must(z.ZSTD_CCtx_setParameter(c,201,1));must(z.ZSTD_CCtx_setParameter(c,10,fmt))
    r,b=enc(c,payload)
   with ctx('D',fmt) as d:
    must(prefix('D',d,p,kind));dr=z.ZSTD_DCtx_reset(d,directive)
    must(z.ZSTD_DCtx_setParameter(d,1000,fmt));r2,_=dec(d,f,payload)
   emit(name+'.reset_pending.'+str(fmt)+'.'+str(directive),{'C_reset':result(reset),'C_prefix_frame':b==f,'C_plain_frame':b==baseline,'D_reset':result(dr),'D_decode':r2})
# Replace persistent RAW A with once B: old dictionary must not return.
for fmt in [0,1]:
 fa=frame(A,PA,'default',fmt);fb=frame(B,PB,'default',fmt)
 with ctx('C',fmt) as c:
  must(load('C',c,A));must(prefix('C',c,B,'default'));r,b=enc(c,PB);r2,b2=enc(c,PA)
 with ctx('D',fmt) as d:
  must(load('D',d,A));must(prefix('D',d,B,'default'));first,_=dec(d,fb,PB);second,_=dec(d,fa,PA)
 emit('replace_persistent_RAW.'+str(fmt),{'C_first_B':b==fb,'C_after_plain_A':b2==noframe(PA,fmt),'D_B':first,'D_after_A':second})
 # Replace persistent full dictionary with a default-RAW prefix using same bytes.
 ff=frame(FULL,PF,2,fmt);fr=frame(FULL,PF,'default',fmt)
 with ctx('D',fmt) as d:
  must(load('D',d,FULL));must(prefix('D',d,FULL,'default'));first,_=dec(d,fr,PF);second,_=dec(d,ff,PF)
 emit('replace_persistent_FULL_with_defaultRAW.'+str(fmt),{'D_RAW':first,'D_after_FULL':second})
 # Replace one prefix by another, then replace prefix with persistent dictionary.
 with ctx('D',fmt) as d:
  must(prefix('D',d,A,'default'));must(prefix('D',d,B,'default'));first,_=dec(d,fb,PB);must(load('D',d,A));second,_=dec(d,fa,PA);third,_=dec(d,fa,PA)
 with ctx('C',fmt) as c:
  must(prefix('C',c,A,'default'));must(prefix('C',c,B,'default'));r,b=enc(c,PB);must(load('C',c,A));r2,b2=enc(c,PA);r3,b3=enc(c,PA)
 emit('replace_prefix_and_load_persistent.'+str(fmt),{'D_B':first,'D_loaded_A_1':second,'D_loaded_A_2':third,'C_B':b==fb,'C_loaded_A_1':b2==fa,'C_loaded_A_2':b3==fa})
# FULL validity is validated at different times.
for side in ['C','D']:
 with ctx(side) as c:
  must(load(side,c,A));r=prefix(side,c,b'not a full dictionary',2)
  if side=='C':
   follow,b=enc(c,PA);must(z.ZSTD_CCtx_reset(c,1));again,b2=enc(c,PA)
   emit('invalid_FULL.'+side,{'ref':result(r),'follow':follow,'after_reset':again,'after_plain':b2==noframe(PA)})
  else:
   fa=frame(A,PA);follow,_=dec(c,fa,PA)
   emit('invalid_FULL.'+side,{'ref':result(r),'old_persistent_after':follow})

def hlen(f,fmt):
 base=0 if fmt else 4;d=f[base];single=bool(d&32)
 return base+1+(0 if single else 1)+[0,1,2,4][d&3]+([1,2,4,8][d>>6] if (d>>6 or single) else 0)
for name,p,payload,kind in [families[0],families[2]]:
 for fmt in [0,1]:
  f=frame(p,payload,kind,fmt)
  invalid=(b'\xff'+f[1:]) if fmt else (b'BAD!'+f[4:])
  badsum=f[:-1]+bytes([f[-1]^1])
  for label,data in [('empty_input',b''),('bad_header',invalid),('bad_checksum',badsum),('truncated',f[:-1])]:
   with ctx('D',fmt) as d:
    must(prefix('D',d,p,kind));first,_=dec(d,data,payload);reset=z.ZSTD_DCtx_reset(d,1);after,_=dec(d,f,payload)
   emit(name+'.D.oneshot_error.'+str(fmt)+'.'+label,{'first':first,'reset':result(reset),'after':after})
   with ctx('D',fmt) as d:
    must(prefix('D',d,p,kind));first=ddrive(d,data,payload,1,113) if data else dcall(d,b'',113)[0];reset=z.ZSTD_DCtx_reset(d,1);after,_=dec(d,f,payload)
   emit(name+'.D.stream_error.'+str(fmt)+'.'+label,{'first':first,'reset':result(reset),'after':after})
  for label,data in [('partial_header',f[:hlen(f,fmt)-1]),('complete_header',f[:hlen(f,fmt)])]:
   with ctx('D',fmt) as d:
    must(prefix('D',d,p,kind));first,_=dcall(d,data,113);replace=prefix('D',d,p,kind);rp=z.ZSTD_DCtx_reset(d,2);rs=z.ZSTD_DCtx_reset(d,1);after,_=dec(d,f,payload)
   emit(name+'.D.active.'+str(fmt)+'.'+label,{'first':first,'ref_again':result(replace),'reset_parameters':result(rp),'reset_session':result(rs),'after':after})
  # Compression destination error occurs after prefix consumption.
  with ctx('C',fmt) as c:
   must(prefix('C',c,p,kind));first,_=enc(c,payload,1);must(z.ZSTD_CCtx_reset(c,1));after,b=enc(c,payload)
  emit(name+'.C.oneshot_small_output.'+str(fmt),{'first':first,'after':after,'after_plain':b==noframe(payload,fmt)})
  for label,data in [('empty_continue',b''),('partial_input',payload[:37])]:
   with ctx('C',fmt) as c:
    must(prefix('C',c,p,kind));first,_=ccall(c,data,0,113);replace=prefix('C',c,p,kind);rp=z.ZSTD_CCtx_reset(c,2);rs=z.ZSTD_CCtx_reset(c,1);after,b=enc(c,payload)
   emit(name+'.C.active.'+str(fmt)+'.'+label,{'first':first,'ref_again':result(replace),'reset_parameters':result(rp),'reset_session':result(rs),'after_plain':b==noframe(payload,fmt),'after_prefix':b==f})
  # An illegal directive is rejected before stream initialization.
  with ctx('C',fmt) as c:
   must(prefix('C',c,p,kind));first,_=ccall(c,payload,99,113);must(z.ZSTD_CCtx_reset(c,1));after,b=enc(c,payload)
  emit(name+'.C.invalid_directive.'+str(fmt),{'first':first,'after_prefix':b==f})
  # A mismatched pledge is a fatal error during an initialized stream.
  with ctx('C',fmt) as c:
   must(prefix('C',c,p,kind));must(z.ZSTD_CCtx_setPledgedSrcSize(c,len(payload)+1))
   start,_=ccall(c,payload,0,113);finish,_=ccall(c,b'',2,113)
   must(z.ZSTD_CCtx_reset(c,1));after,b=enc(c,payload)
  emit(name+'.C.bad_pledge.'+str(fmt),{'start':start,'finish':finish,'after_plain':b==noframe(payload,fmt)})

api('ZSTD_writeSkippableFrame',[V,S,V,S,U])
for side in ['C','D']:
 api('ZSTD_'+side+'Ctx_getParameter',[V,I,C.POINTER(I)])
def query(side,c,param):
 val=I();r=getattr(z,'ZSTD_'+side+'Ctx_getParameter')(c,param,C.byref(val));must(r);return val.value
for name,p,payload,kind in [families[0],families[2]]:
 for fmt in [0,1]:
  f=frame(p,payload,kind,fmt)
  with ctx('C',fmt) as c:
   must(prefix('C',c,p,kind));r,b=cdrive(c,payload);after,b2=cdrive(c,payload)
  with ctx('D',fmt) as d:
   must(prefix('D',d,p,kind));first=ddrive(d,f,payload,1,113);afterd=ddrive(d,f,payload,1,113)
  with ctx('C',fmt) as plainctx:
   _,plainstream=cdrive(plainctx,payload)
  with ctx('D',fmt) as checkctx:
   must(prefix('D',checkctx,p,kind));firstdec,_=dec(checkctx,b,payload)
  emit(name+'.stream_success_reuse.'+str(fmt),{'C_first':r,'C_first_decodes':firstdec,'C_second_plain':b2==plainstream,'D_first':first,'D_second':afterd})
  with ctx('D',fmt) as d:
   must(prefix('D',d,p,kind));independent=ddrive(d,noframe(b'',fmt),b'',1,113);dependent=ddrive(d,f,payload,1,113)
  emit(name+'.D.empty_data_consumes.'+str(fmt),{'empty_data':independent,'following':dependent})
  # A standalone metadata writer has no CCtx and does not consume its pending prefix.
  with ctx('C',fmt) as c:
   must(prefix('C',c,p,kind));out=C.create_string_buffer(64)
   written=z.ZSTD_writeSkippableFrame(out,len(out),buf(b'xyz'),3,3)
   r,b=enc(c,payload)
  emit(name+'.C.standalone_skippable.'+str(fmt),{'skip_writer':result(written),'next_prefix_frame':b==f})
# Default RAW interpretation refuses the full-entropy reference, while advanced FULL works.
for kind in ['default',1,0,2]:
 with ctx('D') as d:
  r=prefix('D',d,FULL,kind);decoded,_=dec(d,REF,PF)
 emit('full_reference_interpretation.'+str(kind),{'ref':result(r),'decode':decoded})
for side in ['C','D']:
 for directive in [1,2,3]:
  with ctx(side,1) as c:
   must(prefix(side,c,A,'default'));r=getattr(z,'ZSTD_'+side+'Ctx_reset')(c,directive)
   mode=query(side,c,10 if side=='C' else 1000)
  emit('reset_format.'+side+'.'+str(directive),{'reset':result(r),'format':mode})
# initDStream explicitly clears dictionaries, unlike session-only reset.
api('ZSTD_initDStream',[V]);api('ZSTD_resetDStream',[V])
fa=frame(A,PA)
for name in ['ZSTD_initDStream','ZSTD_resetDStream']:
 with ctx('D') as d:
  must(prefix('D',d,A,'default'));r=getattr(z,name)(d);decoded,_=dec(d,fa,PA)
 emit(name+'.pending_prefix',{'reset':result(r),'decode':decoded})

for name,p,payload,kind in [families[0],families[2]]:
 f=frame(p,payload,kind,0)
 for label,data in [('concat',f+f),('skip_then_data',SKIP+f)]:
  with ctx('D') as d:
   must(prefix('D',d,p,kind));first,out=dcall(d,data,1000000);second,out2=dcall(d,data[first['input']:],1000000)
  emit(name+'.D.full_buffer.'+label,{'first':first,'first_correct':out==(payload if label=='concat' else b''),'second':second})
 # FULL and RAW stream dictionary replacement remains rejected until frame closes.
 with ctx('D') as d:
  must(prefix('D',d,p,kind));hlen0=(7 if name=='raw' else 11)
  start,out=dcall(d,f[:hlen0],113);reject=prefix('D',d,B,'default');end=ddrive(d,f[hlen0:],payload,1,113)
  accepted=prefix('D',d,p,kind);again=ddrive(d,f,payload,1,113)
 emit(name+'.D.rearm_after_success',{'start':start,'mid_ref':result(reject),'finish':end,'end_ref':result(accepted),'again':again})
 with ctx('C') as c:
  must(prefix('C',c,p,kind));first,_=ccall(c,payload,0,113);reject=prefix('C',c,B,'default')
  r,part=ccall(c,b'',2,1000000)
  accepted=prefix('C',c,p,kind);newr,newb=enc(c,payload)
 emit(name+'.C.rearm_after_success',{'start':first,'mid_ref':result(reject),'finish':r,'end_ref':result(accepted),'again_prefix_frame':newb==f})
 # Persistent dictionaries survive a checksum failure and session reset.
 with ctx('D') as d:
  must(load('D',d,p));bad=f[:-1]+bytes([f[-1]^1]);r=ddrive(d,bad,payload,1,113);must(z.ZSTD_DCtx_reset(d,1));good,_=dec(d,f,payload)
 emit(name+'.D.persistent_after_error',{'bad':r,'after_session_reset':good})

fa=frame(A,PA);fb=frame(B,PB)
for method in ['oneshot','stream']:
 with ctx('D') as d:
  must(prefix('D',d,A,'default'))
  first=dec(d,b'BAD!'+fa[4:],PA)[0] if method=='oneshot' else dcall(d,b'BAD!'+fa[4:],113)[0]
  replaced=prefix('D',d,B,'default');reset=z.ZSTD_DCtx_reset(d,1);cleared=prefix('D',d,b'', 'default',True,0)
 emit('D.ref_after_bad_header.'+method,{'error_call':first,'ref_before_reset':result(replaced),'reset':result(reset),'clear_after_reset':result(cleared)})
for label in ['output_too_small','invalid_directive']:
 with ctx('C') as c:
  must(prefix('C',c,A,'default'))
  first=enc(c,PA,1)[0] if label=='output_too_small' else ccall(c,PA,99,113)[0]
  replaced=prefix('C',c,B,'default');reset=z.ZSTD_CCtx_reset(c,1)
 emit('C.ref_after_error.'+label,{'error_call':first,'ref_before_reset':result(replaced),'reset':result(reset)})
for side in ['C','D']:
 with ctx(side) as c:
  must(prefix(side,c,A,'default'))
  start=ccall(c,b'',0,113)[0] if side=='C' else dcall(c,fa[:1],113)[0]
  cleared=prefix(side,c,b'','default',True,0)
 emit('clear_NULL_while_active.'+side,{'start':start,'clear':result(cleared)})

by={r['case']:r for r in records}
assert by['environment']['version']=='1.6.0'
for r in records:
 case=r['case']
 if '.baseline.' in case:
  assert r['first']['correct'] and not r['second']['correct'] and not r['missing']['correct']
  assert r['encoder_first_same'] and r['encoder_second_plain']
 if '.reset_pending.' in case:
  pending=case.endswith('.1');assert r['C_prefix_frame']==pending and r['D_decode']['correct']==pending
 if '.clear.' in case:
  assert r['C_ref']['ret']==0 and r['D_ref']['ret']==0 and r['C_plain'] and not r['D_decode']['correct']
 if '.stream_success_reuse.' in case:
  assert r['C_first_decodes']['correct'] and r['C_second_plain'] and r['D_first']['correct'] and r['D_second']['error']
 if '.D.stream_error.' in case and case.endswith('.bad_header'):
  assert r['first']['error'] and r['after']['correct']
 if '.D.stream_error.' in case and case.endswith('.bad_checksum'):
  assert r['first']['error'] and not r['after']['correct']
 if '.C.active.' in case:
  assert r['ref_again']['error'] and r['reset_parameters']['error'] and r['after_plain']
for family in ['raw','full_advanced_FULL']:
 assert by[family+'.concat.oneshot.0']['concat']['correct']
 assert by[family+'.concat.stream.0.1']['error']
 assert by[family+'.skip_payload.oneshot_join.0']['joined']['correct']
 assert by[family+'.skip_payload.stream_join.0.1']['joined']['error']
 assert by[family+'.skip_empty.stream_join.0.1']['joined']['error']
 assert by[family+'.D.active.0.partial_header']['after']['correct']
 assert not by[family+'.D.active.0.complete_header']['after']['correct']
assert not by['full_reference_interpretation.default']['decode']['correct']
assert by['full_reference_interpretation.2']['decode']['correct']
emit('probe_summary',{'checks':'passed','case_count':len(records),'failed_assertions':0})
