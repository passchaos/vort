 115ccfb:	48 8d 90 ff f7 ff ff 	lea    -0x801(%rax),%rdx
 115cd02:	48 81 fa 01 f8 ff ff 	cmp    $0xfffffffffffff801,%rdx
 115cd09:	0f 82 ae fe ff ff    	jb     115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115cd0f:	c6 84 24 d0 03 00 00 	movb   $0x0,0x3d0(%rsp)
 115cd16:	00 
 115cd17:	45 84 ed             	test   %r13b,%r13b
 115cd1a:	0f 85 9d fe ff ff    	jne    115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115cd20:	4c 39 74 24 38       	cmp    %r14,0x38(%rsp)
 115cd25:	0f 82 92 fe ff ff    	jb     115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115cd2b:	4b 8d 14 b6          	lea    (%r14,%r14,4),%rdx
 115cd2f:	49 8d 14 56          	lea    (%r14,%rdx,2),%rdx
 115cd33:	48 39 54 24 38       	cmp    %rdx,0x38(%rsp)
 115cd38:	0f 87 7f fe ff ff    	ja     115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115cd3e:	48 89 84 24 a8 2b 00 	mov    %rax,0x2ba8(%rsp)
 115cd45:	00 
 115cd46:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 115cd4b:	48 89 84 24 b0 2b 00 	mov    %rax,0x2bb0(%rsp)
 115cd52:	00 
 115cd53:	ba 00 04 00 00       	mov    $0x400,%edx
 115cd58:	48 8b bc 24 d0 00 00 	mov    0xd0(%rsp),%rdi
 115cd5f:	00 
 115cd60:	48 8b b4 24 80 00 00 	mov    0x80(%rsp),%rsi
 115cd67:	00 
 115cd68:	e8 53 12 04 00       	call   119dfc0 <compiler_rt.memcpy.memcpyFast>
 115cd6d:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115cd72:	44 8b 54 24 24       	mov    0x24(%rsp),%r10d
 115cd77:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115cd7e:	79 37 9e 
 115cd81:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115cd86:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115cd8b:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115cd90:	44 89 b4 24 b8 2f 00 	mov    %r14d,0x2fb8(%rsp)
 115cd97:	00 
 115cd98:	c6 84 24 c0 2f 00 00 	movb   $0x1,0x2fc0(%rsp)
 115cd9f:	01 
 115cda0:	e9 18 fe ff ff       	jmp    115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
