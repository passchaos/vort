 115b2e8:	48 03 b4 24 28 1a 00 	add    0x1a28(%rsp),%rsi
 115b2ef:	00 
 115b2f0:	0f 92 84 24 f8 10 00 	setb   0x10f8(%rsp)
 115b2f7:	00 
 115b2f8:	0f 83 1b 01 00 00    	jae    115b419 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa79>
 115b2fe:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115b303:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115b308:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115b30d:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115b312:	e9 c3 0d 00 00       	jmp    115c0da <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x173a>

 115b419:	48 89 74 24 38       	mov    %rsi,0x38(%rsp)
 115b41e:	48 8b 84 24 30 1a 00 	mov    0x1a30(%rsp),%rax
 115b425:	00 
 115b426:	48 ff c0             	inc    %rax
 115b429:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115b42e:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115b433:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115b438:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115b43d:	0f 84 97 0c 00 00    	je     115c0da <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x173a>
 115b443:	48 89 84 24 80 01 00 	mov    %rax,0x180(%rsp)
 115b44a:	00 

 115bfc8:	48 8b 74 24 58       	mov    0x58(%rsp),%rsi
 115bfcd:	48 89 b4 24 18 1a 00 	mov    %rsi,0x1a18(%rsp)
 115bfd4:	00 
 115bfd5:	48 8b 84 24 60 01 00 	mov    0x160(%rsp),%rax
 115bfdc:	00 
 115bfdd:	48 89 84 24 20 1a 00 	mov    %rax,0x1a20(%rsp)
 115bfe4:	00 
 115bfe5:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 115bfea:	48 89 84 24 28 1a 00 	mov    %rax,0x1a28(%rsp)
 115bff1:	00 
 115bff2:	48 8b 84 24 80 01 00 	mov    0x180(%rsp),%rax
 115bff9:	00 
 115bffa:	48 89 84 24 30 1a 00 	mov    %rax,0x1a30(%rsp)
 115c001:	00 
