 115aa21:	48 85 db             	test   %rbx,%rbx
 115aa24:	0f 94 c0             	sete   %al
 115aa27:	49 8d 8c 24 ff ef ff 	lea    -0x1001(%r12),%rcx
 115aa2e:	ff 
 115aa2f:	48 81 f9 00 f0 01 00 	cmp    $0x1f000,%rcx
 115aa36:	0f 92 c1             	setb   %cl
 115aa39:	84 c8                	test   %cl,%al
 115aa3b:	4c 89 64 24 28       	mov    %r12,0x28(%rsp)
 115aa40:	4c 89 b4 24 40 01 00 	mov    %r14,0x140(%rsp)
 115aa47:	00 
 115aa48:	0f 84 15 01 00 00    	je     115ab63 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1c3>
 115aa4e:	48 8d bc 24 28 1a 00 	lea    0x1a28(%rsp),%rdi
 115aa55:	00 
 115aa56:	c7 44 24 7c 00 00 00 	movl   $0x0,0x7c(%rsp)
 115aa5d:	00 
 115aa5e:	ba 50 10 00 00       	mov    $0x1050,%edx
 115aa63:	31 f6                	xor    %esi,%esi
 115aa65:	c5 f8 77             	vzeroupper 
 115aa68:	e8 33 31 04 00       	call   119dba0 <compiler_rt.memset>
 115aa6d:	48 8d bc 24 88 2a 00 	lea    0x2a88(%rsp),%rdi
 115aa74:	00 
 115aa75:	ba 40 05 00 00       	mov    $0x540,%edx
 115aa7a:	48 89 bc 24 a0 00 00 	mov    %rdi,0xa0(%rsp)
 115aa81:	00 
 115aa82:	31 f6                	xor    %esi,%esi
 115aa84:	e8 17 31 04 00       	call   119dba0 <compiler_rt.memset>
 115aa89:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115aa8e:	48 89 b4 24 08 1a 00 	mov    %rsi,0x1a08(%rsp)
 115aa95:	00 
 115aa96:	4c 89 a4 24 10 1a 00 	mov    %r12,0x1a10(%rsp)
 115aa9d:	00 
 115aa9e:	48 c7 84 24 18 1a 00 	movq   $0x0,0x1a18(%rsp)
 115aaa5:	00 00 00 00 00 
 115aaaa:	48 c7 84 24 20 1a 00 	movq   $0x1,0x1a20(%rsp)
 115aab1:	00 01 00 00 00 
 115aab6:	48 89 b4 24 78 2a 00 	mov    %rsi,0x2a78(%rsp)
 115aabd:	00 
 115aabe:	4c 89 a4 24 80 2a 00 	mov    %r12,0x2a80(%rsp)
 115aac5:	00 
 115aac6:	c6 84 24 c8 2f 00 00 	movb   $0x1,0x2fc8(%rsp)
 115aacd:	01 
 115aace:	48 8d 84 24 08 11 00 	lea    0x1108(%rsp),%rax
 115aad5:	00 
 115aad6:	48 89 84 24 b0 00 00 	mov    %rax,0xb0(%rsp)
 115aadd:	00 
 115aade:	48 8d 84 24 38 2a 00 	lea    0x2a38(%rsp),%rax
 115aae5:	00 
 115aae6:	48 89 84 24 88 00 00 	mov    %rax,0x88(%rsp)
 115aaed:	00 
 115aaee:	48 8d 84 24 f8 0c 00 	lea    0xcf8(%rsp),%rax
 115aaf5:	00 
 115aaf6:	48 89 84 24 80 00 00 	mov    %rax,0x80(%rsp)
 115aafd:	00 
 115aafe:	48 8d 84 24 b8 2b 00 	lea    0x2bb8(%rsp),%rax
 115ab05:	00 
 115ab06:	48 89 84 24 d0 00 00 	mov    %rax,0xd0(%rsp)
 115ab0d:	00 
 115ab0e:	48 8d 84 24 d8 03 00 	lea    0x3d8(%rsp),%rax
 115ab15:	00 
 115ab16:	48 89 84 24 f0 00 00 	mov    %rax,0xf0(%rsp)
 115ab1d:	00 
 115ab1e:	48 8d 84 24 d8 07 00 	lea    0x7d8(%rsp),%rax
 115ab25:	00 
 115ab26:	48 89 84 24 e8 00 00 	mov    %rax,0xe8(%rsp)
 115ab2d:	00 
 115ab2e:	48 8d 84 24 d8 0b 00 	lea    0xbd8(%rsp),%rax
 115ab35:	00 
 115ab36:	48 89 84 24 e0 00 00 	mov    %rax,0xe0(%rsp)
 115ab3d:	00 
 115ab3e:	48 8d 84 24 90 2a 00 	lea    0x2a90(%rsp),%rax
 115ab45:	00 
 115ab46:	48 89 84 24 c8 00 00 	mov    %rax,0xc8(%rsp)
 115ab4d:	00 
 115ab4e:	48 8d 84 24 d8 03 00 	lea    0x3d8(%rsp),%rax
 115ab55:	00 
 115ab56:	48 89 84 24 d8 00 00 	mov    %rax,0xd8(%rsp)
 115ab5d:	00 
 115ab5e:	e9 1a 02 00 00       	jmp    115ad7d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3dd>
