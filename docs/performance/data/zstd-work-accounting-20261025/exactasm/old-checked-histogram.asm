 115b283:	48 03 b4 24 f0 0c 00 	add    0xcf0(%rsp),%rsi
 115b28a:	00 
 115b28b:	0f 92 84 24 80 28 00 	setb   0x2880(%rsp)
 115b292:	00 
 115b293:	0f 83 11 01 00 00    	jae    115b3aa <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa0a>
 115b299:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115b29e:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115b2a3:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115b2aa:	79 37 9e 
 115b2ad:	e9 19 01 00 00       	jmp    115b3cb <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa2b>

 115b3aa:	48 8b 84 24 f8 0c 00 	mov    0xcf8(%rsp),%rax
 115b3b1:	00 
 115b3b2:	48 ff c0             	inc    %rax
 115b3b5:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115b3ba:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115b3bf:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115b3c6:	79 37 9e 
 115b3c9:	75 38                	jne    115b403 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa63>
 115b3cb:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 115b3d2:	48 8b 84 24 50 1d 00 	mov    0x1d50(%rsp),%rax
 115b3d9:	00 
 115b3da:	48 ff c0             	inc    %rax
 115b3dd:	48 0f 44 c6          	cmove  %rsi,%rax
 115b3e1:	48 89 84 24 50 1d 00 	mov    %rax,0x1d50(%rsp)
 115b3e8:	00 
 115b3e9:	4c 8b ac 24 c8 00 00 	mov    0xc8(%rsp),%r13
 115b3f0:	00 
 115b3f1:	44 8b 74 24 1c       	mov    0x1c(%rsp),%r14d
 115b3f6:	4c 8b a4 24 98 00 00 	mov    0x98(%rsp),%r12
 115b3fd:	00 
 115b3fe:	e9 7e f9 ff ff       	jmp    115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>

 115bf78:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 115bf7d:	4c 89 bc 24 e0 0c 00 	mov    %r15,0xce0(%rsp)
 115bf84:	00 
 115bf85:	48 8b 84 24 80 01 00 	mov    0x180(%rsp),%rax
 115bf8c:	00 
 115bf8d:	48 89 84 24 e8 0c 00 	mov    %rax,0xce8(%rsp)
 115bf94:	00 
 115bf95:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 115bf9a:	48 89 84 24 f0 0c 00 	mov    %rax,0xcf0(%rsp)
 115bfa1:	00 
 115bfa2:	48 8b 84 24 a0 01 00 	mov    0x1a0(%rsp),%rax
 115bfa9:	00 
 115bfaa:	48 89 84 24 f8 0c 00 	mov    %rax,0xcf8(%rsp)
 115bfb1:	00 
