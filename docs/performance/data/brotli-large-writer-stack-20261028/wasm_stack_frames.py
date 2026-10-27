import json, pathlib, sys
b=pathlib.Path(sys.argv[1]).read_bytes()
def u(data,pos):
 v=0;shift=0
 while True:
  n=data[pos];pos+=1;v|=(n&127)<<shift
  if not n&128:return v,pos
  shift+=7
def st(data,pos):
 n,pos=u(data,pos);return data[pos:pos+n].decode(),pos+n
sections=[];i=8
while i<len(b):
 sid=b[i];sz,j=u(b,i+1);sections.append((sid,j,b[j:j+sz]));i=j+sz
names={};imports=0
for sid,off,data in sections:
 if sid==0:
  label,i=st(data,0)
  if label!='name':continue
  while i<len(data):
   sub=data[i];sz,j=u(data,i+1);end=j+sz
   if sub==1:
    n,j=u(data,j)
    for _ in range(n):
     idx,j=u(data,j);name,j=st(data,j);names[idx]=name
   i=end
 if sid==2:
  n,i=u(data,0)
  for _ in range(n):
   mod,i=st(data,i);name,i=st(data,i);kind=data[i];i+=1
   if kind==0:_,i=u(data,i);imports+=1
   else:raise ValueError(kind)
frames=[]
for sid,off,data in sections:
 if sid!=10:continue
 n,i=u(data,0)
 for idx in range(imports,imports+n):
  sz,j=u(data,i);body=data[j:j+sz];i=j+sz
  k,pos=u(body,0)
  for _ in range(k):_,pos=u(body,pos);pos+=1
  name=names.get(idx,'');frame=0
  if body[pos]==0x23:
   _,q=u(body,pos+1)
   if body[q]==0x41:
    frame,q=u(body,q+1)
    if body[q]!=0x6b:frame=0
  frames.append(dict(name=name, index=idx, frame_bytes=frame, code_bytes=sz))
selected=[f for f in frames if any(s in f['name'] for s in ['encodeCommandPlanWithLargeWindowWrite','br.encodeCommandPlanWithOptionsWrite','writeHqPlannedStreamMetaBlock'])]
print(json.dumps(selected,indent=2))
