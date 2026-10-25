
/home/passchaos/project-z/vort-zstd-frequency-merge/.zig-cache/o/01eb2d7a175dc1b159e6dfc0b899550d/vort-zstd-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000115a9a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst>:
 115a9a0:	55                   	push   %rbp
 115a9a1:	48 89 e5             	mov    %rsp,%rbp
 115a9a4:	41 57                	push   %r15
 115a9a6:	41 56                	push   %r14
 115a9a8:	41 55                	push   %r13
 115a9aa:	41 54                	push   %r12
 115a9ac:	53                   	push   %rbx
 115a9ad:	48 83 e4 e0          	and    $0xffffffffffffffe0,%rsp
 115a9b1:	48 81 ec e0 ce 02 00 	sub    $0x2cee0,%rsp
 115a9b8:	48 89 bc 24 78 01 00 	mov    %rdi,0x178(%rsp)
 115a9bf:	00 
 115a9c0:	48 8b 45 18          	mov    0x18(%rbp),%rax
 115a9c4:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 115a9c8:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 115a9cc:	48 c7 40 20 00 00 00 	movq   $0x0,0x20(%rax)
 115a9d3:	00 
 115a9d4:	49 83 f8 02          	cmp    $0x2,%r8
 115a9d8:	0f 82 17 2a 00 00    	jb     115d3f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a55>
 115a9de:	4d 89 c5             	mov    %r8,%r13
 115a9e1:	49 89 cc             	mov    %rcx,%r12
 115a9e4:	48 8b 5d 10          	mov    0x10(%rbp),%rbx
 115a9e8:	0f b6 01             	movzbl (%rcx),%eax
 115a9eb:	b9 01 00 00 00       	mov    $0x1,%ecx
 115a9f0:	41 38 04 0c          	cmp    %al,(%r12,%rcx,1)
 115a9f4:	75 0d                	jne    115aa03 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x63>
 115a9f6:	48 ff c1             	inc    %rcx
 115a9f9:	49 39 cd             	cmp    %rcx,%r13
 115a9fc:	75 f2                	jne    115a9f0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x50>
 115a9fe:	e9 f2 29 00 00       	jmp    115d3f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a55>
 115aa03:	49 83 fd 1f          	cmp    $0x1f,%r13
 115aa07:	0f 86 e8 29 00 00    	jbe    115d3f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a55>
 115aa0d:	48 89 b4 24 60 01 00 	mov    %rsi,0x160(%rsp)
 115aa14:	00 
 115aa15:	44 89 8c 24 f0 00 00 	mov    %r9d,0xf0(%rsp)
 115aa1c:	00 
 115aa1d:	48 85 db             	test   %rbx,%rbx
 115aa20:	0f 94 c0             	sete   %al
 115aa23:	49 8d 8d ff ef ff ff 	lea    -0x1001(%r13),%rcx
 115aa2a:	48 81 f9 00 f0 01 00 	cmp    $0x1f000,%rcx
 115aa31:	0f 92 c1             	setb   %cl
 115aa34:	84 c8                	test   %cl,%al
 115aa36:	4c 89 a4 24 98 00 00 	mov    %r12,0x98(%rsp)
 115aa3d:	00 
 115aa3e:	48 89 94 24 68 01 00 	mov    %rdx,0x168(%rsp)
 115aa45:	00 
 115aa46:	74 72                	je     115aaba <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x11a>
 115aa48:	48 8d bc 24 f0 0c 00 	lea    0xcf0(%rsp),%rdi
 115aa4f:	00 
 115aa50:	ba 50 10 00 00       	mov    $0x1050,%edx
 115aa55:	31 f6                	xor    %esi,%esi
 115aa57:	c5 f8 77             	vzeroupper 
 115aa5a:	e8 21 35 04 00       	call   119df80 <compiler_rt.memset>
 115aa5f:	48 8d bc 24 50 1d 00 	lea    0x1d50(%rsp),%rdi
 115aa66:	00 
 115aa67:	ba 10 07 00 00       	mov    $0x710,%edx
 115aa6c:	31 f6                	xor    %esi,%esi
 115aa6e:	e8 0d 35 04 00       	call   119df80 <compiler_rt.memset>
 115aa73:	31 c0                	xor    %eax,%eax
 115aa75:	4c 89 a4 24 d0 0c 00 	mov    %r12,0xcd0(%rsp)
 115aa7c:	00 
 115aa7d:	4c 89 ac 24 d8 0c 00 	mov    %r13,0xcd8(%rsp)
 115aa84:	00 
 115aa85:	48 c7 84 24 e0 0c 00 	movq   $0x0,0xce0(%rsp)
 115aa8c:	00 00 00 00 00 
 115aa91:	48 c7 84 24 e8 0c 00 	movq   $0x1,0xce8(%rsp)
 115aa98:	00 01 00 00 00 
 115aa9d:	4c 89 a4 24 40 1d 00 	mov    %r12,0x1d40(%rsp)
 115aaa4:	00 
 115aaa5:	4c 89 ac 24 48 1d 00 	mov    %r13,0x1d48(%rsp)
 115aaac:	00 
 115aaad:	c6 84 24 60 24 00 00 	movb   $0x1,0x2460(%rsp)
 115aab4:	01 
 115aab5:	e9 63 01 00 00       	jmp    115ac1d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x27d>
 115aaba:	48 8d bc 24 d0 0c 00 	lea    0xcd0(%rsp),%rdi
 115aac1:	00 
 115aac2:	ba 98 17 00 00       	mov    $0x1798,%edx
 115aac7:	31 f6                	xor    %esi,%esi
 115aac9:	c5 f8 77             	vzeroupper 
 115aacc:	e8 af 34 04 00       	call   119df80 <compiler_rt.memset>
 115aad1:	4c 89 e8             	mov    %r13,%rax
 115aad4:	48 c1 e8 20          	shr    $0x20,%rax
 115aad8:	0f 95 c0             	setne  %al
 115aadb:	48 85 db             	test   %rbx,%rbx
 115aade:	0f 84 39 01 00 00    	je     115ac1d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x27d>
 115aae4:	48 8d bc 24 a8 ce 00 	lea    0xcea8(%rsp),%rdi
 115aaeb:	00 
 115aaec:	4c 89 e6             	mov    %r12,%rsi
 115aaef:	4c 89 ea             	mov    %r13,%rdx
 115aaf2:	31 c9                	xor    %ecx,%ecx
 115aaf4:	49 89 d8             	mov    %rbx,%r8
 115aaf7:	45 31 c9             	xor    %r9d,%r9d
 115aafa:	e8 e1 36 00 00       	call   115e1e0 <zstd.findBestDuplicateMatchIndexedCancellable>
 115aaff:	0f b7 84 24 d0 ce 00 	movzwl 0xced0(%rsp),%eax
 115ab06:	00 
 115ab07:	66 85 c0             	test   %ax,%ax
 115ab0a:	0f 85 f5 28 00 00    	jne    115d405 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a65>
 115ab10:	80 bc 24 c8 ce 00 00 	cmpb   $0x0,0xcec8(%rsp)
 115ab17:	00 
 115ab18:	0f 84 d7 28 00 00    	je     115d3f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a55>
 115ab1e:	c5 fe 6f 84 24 a8 ce 	vmovdqu 0xcea8(%rsp),%ymm0
 115ab25:	00 00 
 115ab27:	48 8b 84 24 a8 ce 00 	mov    0xcea8(%rsp),%rax
 115ab2e:	00 
 115ab2f:	48 8b 4d 18          	mov    0x18(%rbp),%rcx
 115ab33:	c5 fe 7f 01          	vmovdqu %ymm0,(%rcx)
 115ab37:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 115ab3b:	48 89 84 24 a8 3e 00 	mov    %rax,0x3ea8(%rsp)
 115ab42:	00 
 115ab43:	c4 e3 f9 16 c0 01    	vpextrq $0x1,%xmm0,%rax
 115ab49:	c4 e3 fd 00 c8 e9    	vpermq $0xe9,%ymm0,%ymm1
 115ab4f:	c5 fa 7f 8c 24 b0 3e 	vmovdqu %xmm1,0x3eb0(%rsp)
 115ab56:	00 00 
 115ab58:	c4 e3 7d 39 c1 01    	vextracti128 $0x1,%ymm0,%xmm1
 115ab5e:	c4 e1 f9 7e c9       	vmovq  %xmm1,%rcx
 115ab63:	48 01 c1             	add    %rax,%rcx
 115ab66:	c4 e3 f9 16 84 24 a8 	vpextrq $0x1,%xmm0,0x3aa8(%rsp)
 115ab6d:	3a 00 00 01 
 115ab71:	4c 39 e9             	cmp    %r13,%rcx
 115ab74:	0f 83 7b 28 00 00    	jae    115d3f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a55>
 115ab7a:	41 be 01 00 00 00    	mov    $0x1,%r14d
 115ab80:	4c 8d bc 24 c8 3e 00 	lea    0x3ec8(%rsp),%r15
 115ab87:	00 
 115ab88:	48 8d bc 24 a8 ce 00 	lea    0xcea8(%rsp),%rdi
 115ab8f:	00 
 115ab90:	48 8b b4 24 98 00 00 	mov    0x98(%rsp),%rsi
 115ab97:	00 
 115ab98:	4c 89 ea             	mov    %r13,%rdx
 115ab9b:	49 89 cc             	mov    %rcx,%r12
 115ab9e:	49 89 d8             	mov    %rbx,%r8
 115aba1:	45 31 c9             	xor    %r9d,%r9d
 115aba4:	c5 f8 77             	vzeroupper 
 115aba7:	e8 34 36 00 00       	call   115e1e0 <zstd.findBestDuplicateMatchIndexedCancellable>
 115abac:	0f b7 84 24 d0 ce 00 	movzwl 0xced0(%rsp),%eax
 115abb3:	00 
 115abb4:	66 85 c0             	test   %ax,%ax
 115abb7:	0f 85 48 28 00 00    	jne    115d405 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a65>
 115abbd:	80 bc 24 c8 ce 00 00 	cmpb   $0x0,0xcec8(%rsp)
 115abc4:	00 
 115abc5:	0f 84 cc 29 00 00    	je     115d597 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2bf7>
 115abcb:	c5 fe 6f 84 24 a8 ce 	vmovdqu 0xcea8(%rsp),%ymm0
 115abd2:	00 00 
 115abd4:	c4 e3 f9 16 c0 01    	vpextrq $0x1,%xmm0,%rax
 115abda:	4c 29 e0             	sub    %r12,%rax
 115abdd:	c4 c1 7e 7f 07       	vmovdqu %ymm0,(%r15)
 115abe2:	4a 89 84 f4 a8 3a 00 	mov    %rax,0x3aa8(%rsp,%r14,8)
 115abe9:	00 
 115abea:	49 8d 46 01          	lea    0x1(%r14),%rax
 115abee:	c4 e3 fd 00 c8 aa    	vpermq $0xaa,%ymm0,%ymm1
 115abf4:	c5 f1 d4 c0          	vpaddq %xmm0,%xmm1,%xmm0
 115abf8:	c4 e3 f9 16 c1 01    	vpextrq $0x1,%xmm0,%rcx
 115abfe:	49 83 fe 7e          	cmp    $0x7e,%r14
 115ac02:	0f 87 29 28 00 00    	ja     115d431 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a91>
 115ac08:	49 83 c7 20          	add    $0x20,%r15
 115ac0c:	49 89 c6             	mov    %rax,%r14
 115ac0f:	4c 39 e9             	cmp    %r13,%rcx
 115ac12:	0f 82 70 ff ff ff    	jb     115ab88 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8>
 115ac18:	e9 14 28 00 00       	jmp    115d431 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a91>
 115ac1d:	48 8d 8c 24 90 28 00 	lea    0x2890(%rsp),%rcx
 115ac24:	00 
 115ac25:	48 89 8c 24 e0 00 00 	mov    %rcx,0xe0(%rsp)
 115ac2c:	00 
 115ac2d:	48 8d 8c 24 00 1d 00 	lea    0x1d00(%rsp),%rcx
 115ac34:	00 
 115ac35:	48 89 8c 24 c0 00 00 	mov    %rcx,0xc0(%rsp)
 115ac3c:	00 
 115ac3d:	48 8d 8c 24 80 24 00 	lea    0x2480(%rsp),%rcx
 115ac44:	00 
 115ac45:	48 89 8c 24 b8 00 00 	mov    %rcx,0xb8(%rsp)
 115ac4c:	00 
 115ac4d:	48 8d 8c 24 b8 1e 00 	lea    0x1eb8(%rsp),%rcx
 115ac54:	00 
 115ac55:	48 89 8c 24 08 01 00 	mov    %rcx,0x108(%rsp)
 115ac5c:	00 
 115ac5d:	48 8d 8c 24 c8 03 00 	lea    0x3c8(%rsp),%rcx
 115ac64:	00 
 115ac65:	48 89 8c 24 28 01 00 	mov    %rcx,0x128(%rsp)
 115ac6c:	00 
 115ac6d:	48 8d 8c 24 c8 07 00 	lea    0x7c8(%rsp),%rcx
 115ac74:	00 
 115ac75:	48 89 8c 24 20 01 00 	mov    %rcx,0x120(%rsp)
 115ac7c:	00 
 115ac7d:	48 8d 8c 24 c8 0b 00 	lea    0xbc8(%rsp),%rcx
 115ac84:	00 
 115ac85:	48 89 8c 24 18 01 00 	mov    %rcx,0x118(%rsp)
 115ac8c:	00 
 115ac8d:	48 8d 8c 24 88 1d 00 	lea    0x1d88(%rsp),%rcx
 115ac94:	00 
 115ac95:	48 89 8c 24 d0 00 00 	mov    %rcx,0xd0(%rsp)
 115ac9c:	00 
 115ac9d:	48 8d 8c 24 90 1d 00 	lea    0x1d90(%rsp),%rcx
 115aca4:	00 
 115aca5:	48 89 8c 24 f8 00 00 	mov    %rcx,0xf8(%rsp)
 115acac:	00 
 115acad:	48 8d 8c 24 c8 03 00 	lea    0x3c8(%rsp),%rcx
 115acb4:	00 
 115acb5:	48 89 8c 24 10 01 00 	mov    %rcx,0x110(%rsp)
 115acbc:	00 
 115acbd:	48 8d 8c 24 20 23 00 	lea    0x2320(%rsp),%rcx
 115acc4:	00 
 115acc5:	48 89 8c 24 00 01 00 	mov    %rcx,0x100(%rsp)
 115accc:	00 
 115accd:	48 8d 8c 24 28 23 00 	lea    0x2328(%rsp),%rcx
 115acd4:	00 
 115acd5:	48 89 4c 24 58       	mov    %rcx,0x58(%rsp)
 115acda:	49 8d 4d f8          	lea    -0x8(%r13),%rcx
 115acde:	48 89 4c 24 30       	mov    %rcx,0x30(%rsp)
 115ace3:	45 31 c9             	xor    %r9d,%r9d
 115ace6:	31 d2                	xor    %edx,%edx
 115ace8:	4c 89 ac 24 c8 00 00 	mov    %r13,0xc8(%rsp)
 115acef:	00 
 115acf0:	89 84 24 f4 00 00 00 	mov    %eax,0xf4(%rsp)
 115acf7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 115acfe:	00 00 
 115ad00:	48 89 94 24 a8 00 00 	mov    %rdx,0xa8(%rsp)
 115ad07:	00 
 115ad08:	80 bc 24 60 24 00 00 	cmpb   $0x0,0x2460(%rsp)
 115ad0f:	00 
 115ad10:	4c 89 4c 24 20       	mov    %r9,0x20(%rsp)
 115ad15:	0f 84 85 25 00 00    	je     115d2a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2900>
 115ad1b:	84 c0                	test   %al,%al
 115ad1d:	0f 85 be 26 00 00    	jne    115d3e1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a41>
 115ad23:	ba 00 80 00 00       	mov    $0x8000,%edx
 115ad28:	48 8d bc 24 a8 4e 00 	lea    0x4ea8(%rsp),%rdi
 115ad2f:	00 
 115ad30:	31 f6                	xor    %esi,%esi
 115ad32:	c5 f8 77             	vzeroupper 
 115ad35:	e8 46 32 04 00       	call   119df80 <compiler_rt.memset>
 115ad3a:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115ad3f:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115ad46:	79 37 9e 
 115ad49:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115ad4e:	49 39 f9             	cmp    %rdi,%r9
 115ad51:	0f 87 8a 26 00 00    	ja     115d3e1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a41>
 115ad57:	48 c7 84 24 a0 00 00 	movq   $0xffffffffffffffff,0xa0(%rsp)
 115ad5e:	00 ff ff ff ff 
 115ad63:	45 31 f6             	xor    %r14d,%r14d
 115ad66:	4d 89 ca             	mov    %r9,%r10
 115ad69:	eb 23                	jmp    115ad8e <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3ee>
 115ad6b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 115ad70:	46 89 94 9c a8 ce 00 	mov    %r10d,0xcea8(%rsp,%r11,4)
 115ad77:	00 
 115ad78:	42 c6 84 1c a8 4e 00 	movb   $0x1,0x4ea8(%rsp,%r11,1)
 115ad7f:	00 01 
 115ad81:	49 39 fa             	cmp    %rdi,%r10
 115ad84:	4d 8d 52 01          	lea    0x1(%r10),%r10
 115ad88:	0f 84 92 25 00 00    	je     115d320 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2980>
 115ad8e:	4c 89 e8             	mov    %r13,%rax
 115ad91:	4c 29 d0             	sub    %r10,%rax
 115ad94:	45 84 f6             	test   %r14b,%r14b
 115ad97:	74 09                	je     115ada2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x402>
 115ad99:	48 39 c8             	cmp    %rcx,%rax
 115ad9c:	0f 82 87 25 00 00    	jb     115d329 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2989>
 115ada2:	4b 8b 34 14          	mov    (%r12,%r10,1),%rsi
 115ada6:	49 89 f3             	mov    %rsi,%r11
 115ada9:	4d 0f af d8          	imul   %r8,%r11
 115adad:	49 c1 eb 31          	shr    $0x31,%r11
 115adb1:	42 80 bc 1c a8 4e 00 	cmpb   $0x0,0x4ea8(%rsp,%r11,1)
 115adb8:	00 00 
 115adba:	74 b4                	je     115ad70 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3d0>
 115adbc:	42 8b 94 9c a8 ce 00 	mov    0xcea8(%rsp,%r11,4),%edx
 115adc3:	00 
 115adc4:	42 c6 84 1c a8 4e 00 	movb   $0x0,0x4ea8(%rsp,%r11,1)
 115adcb:	00 00 
 115adcd:	49 39 d1             	cmp    %rdx,%r9
 115add0:	77 af                	ja     115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115add2:	4c 89 d3             	mov    %r10,%rbx
 115add5:	48 29 d3             	sub    %rdx,%rbx
 115add8:	76 a7                	jbe    115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115adda:	45 84 f6             	test   %r14b,%r14b
 115addd:	74 0a                	je     115ade9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x449>
 115addf:	48 39 c8             	cmp    %rcx,%rax
 115ade2:	77 05                	ja     115ade9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x449>
 115ade4:	41 b6 01             	mov    $0x1,%r14b
 115ade7:	eb 98                	jmp    115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115ade9:	49 39 34 14          	cmp    %rsi,(%r12,%rdx,1)
 115aded:	75 92                	jne    115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115adef:	48 89 4c 24 28       	mov    %rcx,0x28(%rsp)
 115adf4:	4c 89 e7             	mov    %r12,%rdi
 115adf7:	4c 89 ee             	mov    %r13,%rsi
 115adfa:	48 89 94 24 30 01 00 	mov    %rdx,0x130(%rsp)
 115ae01:	00 
 115ae02:	4c 89 54 24 48       	mov    %r10,0x48(%rsp)
 115ae07:	4c 89 d1             	mov    %r10,%rcx
 115ae0a:	c5 f8 77             	vzeroupper 
 115ae0d:	e8 be 56 fb ff       	call   11104d0 <zstd.duplicateMatchLengthAfterAnchor>
 115ae12:	48 83 f8 08          	cmp    $0x8,%rax
 115ae16:	73 23                	jae    115ae3b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x49b>
 115ae18:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115ae1d:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115ae22:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115ae29:	79 37 9e 
 115ae2c:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115ae31:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115ae36:	e9 46 ff ff ff       	jmp    115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115ae3b:	45 84 f6             	test   %r14b,%r14b
 115ae3e:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115ae43:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115ae48:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115ae4f:	79 37 9e 
 115ae52:	c5 d9 ef e4          	vpxor  %xmm4,%xmm4,%xmm4
 115ae56:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115ae5b:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115ae60:	74 0f                	je     115ae71 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x4d1>
 115ae62:	48 39 c8             	cmp    %rcx,%rax
 115ae65:	0f 82 16 ff ff ff    	jb     115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115ae6b:	0f 86 41 04 00 00    	jbe    115b2b2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x912>
 115ae71:	48 89 5c 24 60       	mov    %rbx,0x60(%rsp)
 115ae76:	48 8b b4 24 d0 22 00 	mov    0x22d0(%rsp),%rsi
 115ae7d:	00 
 115ae7e:	48 ff c6             	inc    %rsi
 115ae81:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 115ae88:	48 0f 44 f2          	cmove  %rdx,%rsi
 115ae8c:	48 89 b4 24 d0 22 00 	mov    %rsi,0x22d0(%rsp)
 115ae93:	00 
 115ae94:	80 bc 24 c0 22 00 00 	cmpb   $0x0,0x22c0(%rsp)
 115ae9b:	00 
 115ae9c:	74 17                	je     115aeb5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x515>
 115ae9e:	48 8b b4 24 c8 22 00 	mov    0x22c8(%rsp),%rsi
 115aea5:	00 
 115aea6:	48 ff c6             	inc    %rsi
 115aea9:	48 0f 44 f2          	cmove  %rdx,%rsi
 115aead:	48 89 b4 24 c8 22 00 	mov    %rsi,0x22c8(%rsp)
 115aeb4:	00 
 115aeb5:	4e 8d 24 10          	lea    (%rax,%r10,1),%r12
 115aeb9:	4c 8b 9c 24 d8 0c 00 	mov    0xcd8(%rsp),%r11
 115aec0:	00 
 115aec1:	4d 29 e3             	sub    %r12,%r11
 115aec4:	41 bd 00 00 00 00    	mov    $0x0,%r13d
 115aeca:	44 89 74 24 1c       	mov    %r14d,0x1c(%rsp)
 115aecf:	0f 82 f6 04 00 00    	jb     115b3cb <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa2b>
 115aed5:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 115aeda:	4c 89 d0             	mov    %r10,%rax
 115aedd:	4c 29 c8             	sub    %r9,%rax
 115aee0:	49 8d 0c 03          	lea    (%r11,%rax,1),%rcx
 115aee4:	48 83 c1 03          	add    $0x3,%rcx
 115aee8:	49 01 c3             	add    %rax,%r11
 115aeeb:	48 c1 e9 02          	shr    $0x2,%rcx
 115aeef:	49 29 c4             	sub    %rax,%r12
 115aef2:	31 d2                	xor    %edx,%edx
 115aef4:	48 8b b4 24 e0 00 00 	mov    0xe0(%rsp),%rsi
 115aefb:	00 
 115aefc:	c5 fe 7f 66 20       	vmovdqu %ymm4,0x20(%rsi)
 115af01:	c5 fe 7f 26          	vmovdqu %ymm4,(%rsi)
 115af05:	49 81 fb 00 04 00 00 	cmp    $0x400,%r11
 115af0c:	0f 93 c2             	setae  %dl
 115af0f:	48 8d 74 52 01       	lea    0x1(%rdx,%rdx,2),%rsi
 115af14:	4c 89 5c 24 38       	mov    %r11,0x38(%rsp)
 115af19:	49 0f 42 cb          	cmovb  %r11,%rcx
 115af1d:	48 89 b4 24 80 01 00 	mov    %rsi,0x180(%rsp)
 115af24:	00 
 115af25:	0f 83 b3 03 00 00    	jae    115b2de <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x93e>
 115af2b:	31 d2                	xor    %edx,%edx
 115af2d:	f6 84 24 80 01 00 00 	testb  $0x1,0x180(%rsp)
 115af34:	01 
 115af35:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115af3a:	74 51                	je     115af8d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x5ed>
 115af3c:	48 89 d6             	mov    %rdx,%rsi
 115af3f:	48 c1 e6 04          	shl    $0x4,%rsi
 115af43:	48 8d bc 24 90 28 00 	lea    0x2890(%rsp),%rdi
 115af4a:	00 
 115af4b:	48 01 fe             	add    %rdi,%rsi
 115af4e:	48 0f af d1          	imul   %rcx,%rdx
 115af52:	48 01 d1             	add    %rdx,%rcx
 115af55:	48 8b 7c 24 38       	mov    0x38(%rsp),%rdi
 115af5a:	48 39 cf             	cmp    %rcx,%rdi
 115af5d:	48 0f 42 cf          	cmovb  %rdi,%rcx
 115af61:	48 39 c2             	cmp    %rax,%rdx
 115af64:	73 0f                	jae    115af75 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x5d5>
 115af66:	89 16                	mov    %edx,(%rsi)
 115af68:	48 39 c1             	cmp    %rax,%rcx
 115af6b:	48 89 c7             	mov    %rax,%rdi
 115af6e:	48 0f 42 f9          	cmovb  %rcx,%rdi
 115af72:	89 7e 04             	mov    %edi,0x4(%rsi)
 115af75:	48 39 c1             	cmp    %rax,%rcx
 115af78:	76 13                	jbe    115af8d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x5ed>
 115af7a:	48 39 c2             	cmp    %rax,%rdx
 115af7d:	48 0f 46 d0          	cmovbe %rax,%rdx
 115af81:	44 01 e2             	add    %r12d,%edx
 115af84:	89 56 08             	mov    %edx,0x8(%rsi)
 115af87:	44 01 e1             	add    %r12d,%ecx
 115af8a:	89 4e 0c             	mov    %ecx,0xc(%rsi)
 115af8d:	48 89 84 24 d8 00 00 	mov    %rax,0xd8(%rsp)
 115af94:	00 
 115af95:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 115af9c:	00 
 115af9d:	c5 fc 10 00          	vmovups (%rax),%ymm0
 115afa1:	c5 fe 6f 48 20       	vmovdqu 0x20(%rax),%ymm1
 115afa6:	c5 fe 7f 8c 24 90 02 	vmovdqu %ymm1,0x290(%rsp)
 115afad:	00 00 
 115afaf:	c5 fc 11 84 24 70 02 	vmovups %ymm0,0x270(%rsp)
 115afb6:	00 00 
 115afb8:	48 8b 84 24 c0 00 00 	mov    0xc0(%rsp),%rax
 115afbf:	00 
 115afc0:	c5 fe 6f 10          	vmovdqu (%rax),%ymm2
 115afc4:	c5 fe 6f 58 20       	vmovdqu 0x20(%rax),%ymm3
 115afc9:	c5 fe 7f 94 24 40 03 	vmovdqu %ymm2,0x340(%rsp)
 115afd0:	00 00 
 115afd2:	c5 fe 7f 9c 24 60 03 	vmovdqu %ymm3,0x360(%rsp)
 115afd9:	00 00 
 115afdb:	c5 fc 11 84 24 80 03 	vmovups %ymm0,0x380(%rsp)
 115afe2:	00 00 
 115afe4:	c5 fe 7f 8c 24 a0 03 	vmovdqu %ymm1,0x3a0(%rsp)
 115afeb:	00 00 
 115afed:	b8 08 00 00 00       	mov    $0x8,%eax
 115aff2:	31 f6                	xor    %esi,%esi
 115aff4:	eb 47                	jmp    115b03d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x69d>
 115aff6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 115affd:	00 00 00 
 115b000:	45 31 e4             	xor    %r12d,%r12d
 115b003:	4c 8b 54 24 08       	mov    0x8(%rsp),%r10
 115b008:	4c 03 54 24 40       	add    0x40(%rsp),%r10
 115b00d:	4c 03 54 24 50       	add    0x50(%rsp),%r10
 115b012:	49 01 cf             	add    %rcx,%r15
 115b015:	4d 01 d7             	add    %r10,%r15
 115b018:	4c 01 c2             	add    %r8,%rdx
 115b01b:	4c 01 fa             	add    %r15,%rdx
 115b01e:	29 fe                	sub    %edi,%esi
 115b020:	41 0f 42 f5          	cmovb  %r13d,%esi
 115b024:	4c 01 e6             	add    %r12,%rsi
 115b027:	48 01 d6             	add    %rdx,%rsi
 115b02a:	48 83 c0 10          	add    $0x10,%rax
 115b02e:	48 83 f8 48          	cmp    $0x48,%rax
 115b032:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115b037:	0f 84 46 02 00 00    	je     115b283 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x8e3>
 115b03d:	48 89 74 24 40       	mov    %rsi,0x40(%rsp)
 115b042:	4c 8b a4 04 38 03 00 	mov    0x338(%rsp,%rax,1),%r12
 115b049:	00 
 115b04a:	4c 8b b4 04 40 03 00 	mov    0x340(%rsp,%rax,1),%r14
 115b051:	00 
 115b052:	4d 89 e3             	mov    %r12,%r11
 115b055:	49 c1 eb 20          	shr    $0x20,%r11
 115b059:	48 8b 9c 04 78 03 00 	mov    0x378(%rsp,%rax,1),%rbx
 115b060:	00 
 115b061:	48 8b bc 04 80 03 00 	mov    0x380(%rsp,%rax,1),%rdi
 115b068:	00 
 115b069:	49 89 d8             	mov    %rbx,%r8
 115b06c:	49 c1 e8 20          	shr    $0x20,%r8
 115b070:	48 89 fe             	mov    %rdi,%rsi
 115b073:	48 c1 ee 20          	shr    $0x20,%rsi
 115b077:	45 39 e0             	cmp    %r12d,%r8d
 115b07a:	76 34                	jbe    115b0b0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x710>
 115b07c:	44 39 db             	cmp    %r11d,%ebx
 115b07f:	73 6f                	jae    115b0f0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x750>
 115b081:	41 89 da             	mov    %ebx,%r10d
 115b084:	45 29 e2             	sub    %r12d,%r10d
 115b087:	45 0f 42 d5          	cmovb  %r13d,%r10d
 115b08b:	45 39 c3             	cmp    %r8d,%r11d
 115b08e:	44 89 c1             	mov    %r8d,%ecx
 115b091:	41 0f 42 cb          	cmovb  %r11d,%ecx
 115b095:	41 39 cc             	cmp    %ecx,%r12d
 115b098:	41 0f 47 cc          	cmova  %r12d,%ecx
 115b09c:	39 f1                	cmp    %esi,%ecx
 115b09e:	72 1a                	jb     115b0ba <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x71a>
 115b0a0:	eb 3e                	jmp    115b0e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x740>
 115b0a2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b0a9:	1f 84 00 00 00 00 00 
 115b0b0:	44 89 e1             	mov    %r12d,%ecx
 115b0b3:	45 31 d2             	xor    %r10d,%r10d
 115b0b6:	39 f1                	cmp    %esi,%ecx
 115b0b8:	73 26                	jae    115b0e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x740>
 115b0ba:	44 39 df             	cmp    %r11d,%edi
 115b0bd:	73 21                	jae    115b0e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x740>
 115b0bf:	89 fa                	mov    %edi,%edx
 115b0c1:	29 ca                	sub    %ecx,%edx
 115b0c3:	41 0f 42 d5          	cmovb  %r13d,%edx
 115b0c7:	49 01 d2             	add    %rdx,%r10
 115b0ca:	4c 89 54 24 08       	mov    %r10,0x8(%rsp)
 115b0cf:	41 39 f3             	cmp    %esi,%r11d
 115b0d2:	89 f2                	mov    %esi,%edx
 115b0d4:	41 0f 42 d3          	cmovb  %r11d,%edx
 115b0d8:	39 d1                	cmp    %edx,%ecx
 115b0da:	0f 46 ca             	cmovbe %edx,%ecx
 115b0dd:	eb 1d                	jmp    115b0fc <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x75c>
 115b0df:	90                   	nop
 115b0e0:	4c 89 54 24 08       	mov    %r10,0x8(%rsp)
 115b0e5:	eb 15                	jmp    115b0fc <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x75c>
 115b0e7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 115b0ee:	00 00 
 115b0f0:	44 89 e1             	mov    %r12d,%ecx
 115b0f3:	48 c7 44 24 08 00 00 	movq   $0x0,0x8(%rsp)
 115b0fa:	00 00 
 115b0fc:	44 89 da             	mov    %r11d,%edx
 115b0ff:	29 ca                	sub    %ecx,%edx
 115b101:	41 0f 42 d5          	cmovb  %r13d,%edx
 115b105:	48 89 54 24 50       	mov    %rdx,0x50(%rsp)
 115b10a:	4d 89 f2             	mov    %r14,%r10
 115b10d:	49 c1 ea 20          	shr    $0x20,%r10
 115b111:	45 39 f0             	cmp    %r14d,%r8d
 115b114:	76 2a                	jbe    115b140 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7a0>
 115b116:	44 39 d3             	cmp    %r10d,%ebx
 115b119:	73 55                	jae    115b170 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7d0>
 115b11b:	41 89 df             	mov    %ebx,%r15d
 115b11e:	45 29 f7             	sub    %r14d,%r15d
 115b121:	45 0f 42 fd          	cmovb  %r13d,%r15d
 115b125:	45 39 c2             	cmp    %r8d,%r10d
 115b128:	44 89 c2             	mov    %r8d,%edx
 115b12b:	41 0f 42 d2          	cmovb  %r10d,%edx
 115b12f:	41 39 d6             	cmp    %edx,%r14d
 115b132:	41 0f 47 d6          	cmova  %r14d,%edx
 115b136:	39 f2                	cmp    %esi,%edx
 115b138:	72 10                	jb     115b14a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7aa>
 115b13a:	eb 3a                	jmp    115b176 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7d6>
 115b13c:	0f 1f 40 00          	nopl   0x0(%rax)
 115b140:	44 89 f2             	mov    %r14d,%edx
 115b143:	45 31 ff             	xor    %r15d,%r15d
 115b146:	39 f2                	cmp    %esi,%edx
 115b148:	73 2c                	jae    115b176 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7d6>
 115b14a:	44 39 d7             	cmp    %r10d,%edi
 115b14d:	73 27                	jae    115b176 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7d6>
 115b14f:	89 f9                	mov    %edi,%ecx
 115b151:	29 d1                	sub    %edx,%ecx
 115b153:	41 0f 42 cd          	cmovb  %r13d,%ecx
 115b157:	49 01 cf             	add    %rcx,%r15
 115b15a:	41 39 f2             	cmp    %esi,%r10d
 115b15d:	89 f1                	mov    %esi,%ecx
 115b15f:	41 0f 42 ca          	cmovb  %r10d,%ecx
 115b163:	39 ca                	cmp    %ecx,%edx
 115b165:	0f 46 d1             	cmovbe %ecx,%edx
 115b168:	eb 0c                	jmp    115b176 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7d6>
 115b16a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 115b170:	44 89 f2             	mov    %r14d,%edx
 115b173:	45 31 ff             	xor    %r15d,%r15d
 115b176:	44 89 d1             	mov    %r10d,%ecx
 115b179:	29 d1                	sub    %edx,%ecx
 115b17b:	41 0f 42 cd          	cmovb  %r13d,%ecx
 115b17f:	41 39 db             	cmp    %ebx,%r11d
 115b182:	76 3c                	jbe    115b1c0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x820>
 115b184:	45 39 e0             	cmp    %r12d,%r8d
 115b187:	0f 86 b3 00 00 00    	jbe    115b240 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x8a0>
 115b18d:	44 89 e2             	mov    %r12d,%edx
 115b190:	29 da                	sub    %ebx,%edx
 115b192:	41 0f 42 d5          	cmovb  %r13d,%edx
 115b196:	45 39 d8             	cmp    %r11d,%r8d
 115b199:	45 89 dd             	mov    %r11d,%r13d
 115b19c:	45 0f 42 e8          	cmovb  %r8d,%r13d
 115b1a0:	44 39 eb             	cmp    %r13d,%ebx
 115b1a3:	44 0f 47 eb          	cmova  %ebx,%r13d
 115b1a7:	44 89 eb             	mov    %r13d,%ebx
 115b1aa:	45 31 ed             	xor    %r13d,%r13d
 115b1ad:	45 39 f0             	cmp    %r14d,%r8d
 115b1b0:	77 15                	ja     115b1c7 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x827>
 115b1b2:	eb 47                	jmp    115b1fb <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x85b>
 115b1b4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b1bb:	00 00 00 00 00 
 115b1c0:	31 d2                	xor    %edx,%edx
 115b1c2:	45 39 f0             	cmp    %r14d,%r8d
 115b1c5:	76 34                	jbe    115b1fb <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x85b>
 115b1c7:	44 39 d3             	cmp    %r10d,%ebx
 115b1ca:	73 2f                	jae    115b1fb <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x85b>
 115b1cc:	45 89 f5             	mov    %r14d,%r13d
 115b1cf:	41 29 dd             	sub    %ebx,%r13d
 115b1d2:	41 b9 00 00 00 00    	mov    $0x0,%r9d
 115b1d8:	45 0f 42 e9          	cmovb  %r9d,%r13d
 115b1dc:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115b1e1:	4c 01 ea             	add    %r13,%rdx
 115b1e4:	45 39 d0             	cmp    %r10d,%r8d
 115b1e7:	45 89 d5             	mov    %r10d,%r13d
 115b1ea:	45 0f 42 e8          	cmovb  %r8d,%r13d
 115b1ee:	44 39 eb             	cmp    %r13d,%ebx
 115b1f1:	44 0f 47 eb          	cmova  %ebx,%r13d
 115b1f5:	44 89 eb             	mov    %r13d,%ebx
 115b1f8:	45 31 ed             	xor    %r13d,%r13d
 115b1fb:	41 29 d8             	sub    %ebx,%r8d
 115b1fe:	45 0f 42 c5          	cmovb  %r13d,%r8d
 115b202:	41 39 fb             	cmp    %edi,%r11d
 115b205:	76 47                	jbe    115b24e <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x8ae>
 115b207:	41 39 f4             	cmp    %esi,%r12d
 115b20a:	0f 83 f0 fd ff ff    	jae    115b000 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x660>
 115b210:	41 29 fc             	sub    %edi,%r12d
 115b213:	45 0f 42 e5          	cmovb  %r13d,%r12d
 115b217:	44 39 de             	cmp    %r11d,%esi
 115b21a:	44 0f 42 de          	cmovb  %esi,%r11d
 115b21e:	44 39 df             	cmp    %r11d,%edi
 115b221:	44 0f 47 df          	cmova  %edi,%r11d
 115b225:	44 89 df             	mov    %r11d,%edi
 115b228:	44 39 d7             	cmp    %r10d,%edi
 115b22b:	72 2d                	jb     115b25a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x8ba>
 115b22d:	e9 d1 fd ff ff       	jmp    115b003 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x663>
 115b232:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b239:	1f 84 00 00 00 00 00 
 115b240:	31 d2                	xor    %edx,%edx
 115b242:	41 29 d8             	sub    %ebx,%r8d
 115b245:	45 0f 42 c5          	cmovb  %r13d,%r8d
 115b249:	41 39 fb             	cmp    %edi,%r11d
 115b24c:	77 b9                	ja     115b207 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x867>
 115b24e:	45 31 e4             	xor    %r12d,%r12d
 115b251:	44 39 d7             	cmp    %r10d,%edi
 115b254:	0f 83 a9 fd ff ff    	jae    115b003 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x663>
 115b25a:	41 39 f6             	cmp    %esi,%r14d
 115b25d:	0f 83 a0 fd ff ff    	jae    115b003 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x663>
 115b263:	41 29 fe             	sub    %edi,%r14d
 115b266:	45 0f 42 f5          	cmovb  %r13d,%r14d
 115b26a:	4d 01 f4             	add    %r14,%r12
 115b26d:	44 39 d6             	cmp    %r10d,%esi
 115b270:	44 0f 42 d6          	cmovb  %esi,%r10d
 115b274:	44 39 d7             	cmp    %r10d,%edi
 115b277:	44 0f 47 d7          	cmova  %edi,%r10d
 115b27b:	44 89 d7             	mov    %r10d,%edi
 115b27e:	e9 80 fd ff ff       	jmp    115b003 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x663>
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
 115b2b2:	4c 3b 94 24 e8 00 00 	cmp    0xe8(%rsp),%r10
 115b2b9:	00 
 115b2ba:	0f 82 b1 fb ff ff    	jb     115ae71 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x4d1>
 115b2c0:	48 8b 94 24 e8 00 00 	mov    0xe8(%rsp),%rdx
 115b2c7:	00 
 115b2c8:	48 2b 94 24 38 01 00 	sub    0x138(%rsp),%rdx
 115b2cf:	00 
 115b2d0:	48 39 d3             	cmp    %rdx,%rbx
 115b2d3:	0f 83 a8 fa ff ff    	jae    115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115b2d9:	e9 93 fb ff ff       	jmp    115ae71 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x4d1>
 115b2de:	83 e6 fc             	and    $0xfffffffc,%esi
 115b2e1:	48 8d 3c 09          	lea    (%rcx,%rcx,1),%rdi
 115b2e5:	44 8d 04 09          	lea    (%rcx,%rcx,1),%r8d
 115b2e9:	45 31 c9             	xor    %r9d,%r9d
 115b2ec:	45 31 d2             	xor    %r10d,%r10d
 115b2ef:	4c 8d 9c 24 ac 28 00 	lea    0x28ac(%rsp),%r11
 115b2f6:	00 
 115b2f7:	31 d2                	xor    %edx,%edx
 115b2f9:	eb 19                	jmp    115b314 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x974>
 115b2fb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 115b300:	48 83 c2 02          	add    $0x2,%rdx
 115b304:	49 83 c3 20          	add    $0x20,%r11
 115b308:	4d 01 c1             	add    %r8,%r9
 115b30b:	48 39 d6             	cmp    %rdx,%rsi
 115b30e:	0f 84 19 fc ff ff    	je     115af2d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x58d>
 115b314:	4a 8d 1c 11          	lea    (%rcx,%r10,1),%rbx
 115b318:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 115b31d:	49 39 df             	cmp    %rbx,%r15
 115b320:	49 89 de             	mov    %rbx,%r14
 115b323:	4d 0f 42 f7          	cmovb  %r15,%r14
 115b327:	49 39 c2             	cmp    %rax,%r10
 115b32a:	73 12                	jae    115b33e <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x99e>
 115b32c:	45 89 4b e4          	mov    %r9d,-0x1c(%r11)
 115b330:	49 39 c6             	cmp    %rax,%r14
 115b333:	49 89 c7             	mov    %rax,%r15
 115b336:	4d 0f 42 fe          	cmovb  %r14,%r15
 115b33a:	45 89 7b e8          	mov    %r15d,-0x18(%r11)
 115b33e:	49 39 c6             	cmp    %rax,%r14
 115b341:	76 18                	jbe    115b35b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x9bb>
 115b343:	49 39 c2             	cmp    %rax,%r10
 115b346:	49 89 c7             	mov    %rax,%r15
 115b349:	4d 0f 47 fa          	cmova  %r10,%r15
 115b34d:	45 01 e7             	add    %r12d,%r15d
 115b350:	45 89 7b ec          	mov    %r15d,-0x14(%r11)
 115b354:	45 01 e6             	add    %r12d,%r14d
 115b357:	45 89 73 f0          	mov    %r14d,-0x10(%r11)
 115b35b:	49 01 fa             	add    %rdi,%r10
 115b35e:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 115b363:	4d 39 d7             	cmp    %r10,%r15
 115b366:	4d 89 d6             	mov    %r10,%r14
 115b369:	4d 0f 42 f7          	cmovb  %r15,%r14
 115b36d:	48 39 c3             	cmp    %rax,%rbx
 115b370:	73 16                	jae    115b388 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x9e8>
 115b372:	46 8d 3c 09          	lea    (%rcx,%r9,1),%r15d
 115b376:	45 89 7b f4          	mov    %r15d,-0xc(%r11)
 115b37a:	49 39 c6             	cmp    %rax,%r14
 115b37d:	49 89 c7             	mov    %rax,%r15
 115b380:	4d 0f 42 fe          	cmovb  %r14,%r15
 115b384:	45 89 7b f8          	mov    %r15d,-0x8(%r11)
 115b388:	49 39 c6             	cmp    %rax,%r14
 115b38b:	0f 86 6f ff ff ff    	jbe    115b300 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x960>
 115b391:	48 39 c3             	cmp    %rax,%rbx
 115b394:	48 0f 46 d8          	cmovbe %rax,%rbx
 115b398:	44 01 e3             	add    %r12d,%ebx
 115b39b:	41 89 5b fc          	mov    %ebx,-0x4(%r11)
 115b39f:	45 01 e6             	add    %r12d,%r14d
 115b3a2:	45 89 33             	mov    %r14d,(%r11)
 115b3a5:	e9 56 ff ff ff       	jmp    115b300 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x960>
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
 115b403:	48 89 84 24 a0 01 00 	mov    %rax,0x1a0(%rsp)
 115b40a:	00 
 115b40b:	48 89 74 24 40       	mov    %rsi,0x40(%rsp)
 115b410:	48 8b 84 24 c0 00 00 	mov    0xc0(%rsp),%rax
 115b417:	00 
 115b418:	c5 fc 10 00          	vmovups (%rax),%ymm0
 115b41c:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 115b421:	c5 fc 11 8c 24 50 02 	vmovups %ymm1,0x250(%rsp)
 115b428:	00 00 
 115b42a:	c5 fc 11 84 24 30 02 	vmovups %ymm0,0x230(%rsp)
 115b431:	00 00 
 115b433:	c5 fc 10 84 24 70 02 	vmovups 0x270(%rsp),%ymm0
 115b43a:	00 00 
 115b43c:	c5 fe 6f 8c 24 90 02 	vmovdqu 0x290(%rsp),%ymm1
 115b443:	00 00 
 115b445:	c5 fc 11 84 24 90 31 	vmovups %ymm0,0x3190(%rsp)
 115b44c:	00 00 
 115b44e:	c5 fe 7f 8c 24 b0 31 	vmovdqu %ymm1,0x31b0(%rsp)
 115b455:	00 00 
 115b457:	48 8b 84 24 d0 0c 00 	mov    0xcd0(%rsp),%rax
 115b45e:	00 
 115b45f:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 115b464:	31 c9                	xor    %ecx,%ecx
 115b466:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115b46b:	eb 18                	jmp    115b485 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xae5>
 115b46d:	0f 1f 00             	nopl   (%rax)
 115b470:	48 8b 8c 24 c0 01 00 	mov    0x1c0(%rsp),%rcx
 115b477:	00 
 115b478:	48 ff c1             	inc    %rcx
 115b47b:	48 83 f9 04          	cmp    $0x4,%rcx
 115b47f:	0f 84 d0 0a 00 00    	je     115bf55 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x15b5>
 115b485:	49 89 c8             	mov    %rcx,%r8
 115b488:	49 c1 e0 0a          	shl    $0xa,%r8
 115b48c:	48 8d 84 24 00 0d 00 	lea    0xd00(%rsp),%rax
 115b493:	00 
 115b494:	49 01 c0             	add    %rax,%r8
 115b497:	48 89 8c 24 c0 01 00 	mov    %rcx,0x1c0(%rsp)
 115b49e:	00 
 115b49f:	48 c1 e1 04          	shl    $0x4,%rcx
 115b4a3:	48 8b 84 0c 30 02 00 	mov    0x230(%rsp,%rcx,1),%rax
 115b4aa:	00 
 115b4ab:	4c 8b ac 0c 38 02 00 	mov    0x238(%rsp,%rcx,1),%r13
 115b4b2:	00 
 115b4b3:	49 89 c2             	mov    %rax,%r10
 115b4b6:	49 c1 ea 20          	shr    $0x20,%r10
 115b4ba:	48 8b 9c 0c 90 31 00 	mov    0x3190(%rsp,%rcx,1),%rbx
 115b4c1:	00 
 115b4c2:	48 8b bc 0c 98 31 00 	mov    0x3198(%rsp,%rcx,1),%rdi
 115b4c9:	00 
 115b4ca:	48 89 de             	mov    %rbx,%rsi
 115b4cd:	48 c1 ee 20          	shr    $0x20,%rsi
 115b4d1:	49 89 f9             	mov    %rdi,%r9
 115b4d4:	49 c1 e9 20          	shr    $0x20,%r9
 115b4d8:	89 c1                	mov    %eax,%ecx
 115b4da:	39 c6                	cmp    %eax,%esi
 115b4dc:	48 89 7c 24 50       	mov    %rdi,0x50(%rsp)
 115b4e1:	0f 86 d8 00 00 00    	jbe    115b5bf <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc1f>
 115b4e7:	89 c1                	mov    %eax,%ecx
 115b4e9:	44 39 d3             	cmp    %r10d,%ebx
 115b4ec:	0f 83 ce 01 00 00    	jae    115b6c0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd20>
 115b4f2:	39 c3                	cmp    %eax,%ebx
 115b4f4:	0f 86 b7 00 00 00    	jbe    115b5b1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc11>
 115b4fa:	41 89 c3             	mov    %eax,%r11d
 115b4fd:	48 89 d9             	mov    %rbx,%rcx
 115b500:	48 29 c1             	sub    %rax,%rcx
 115b503:	89 ca                	mov    %ecx,%edx
 115b505:	48 ff ca             	dec    %rdx
 115b508:	48 83 fa 07          	cmp    $0x7,%rdx
 115b50c:	73 05                	jae    115b513 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xb73>
 115b50e:	45 31 f6             	xor    %r14d,%r14d
 115b511:	eb 75                	jmp    115b588 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xbe8>
 115b513:	48 8b 54 24 08       	mov    0x8(%rsp),%rdx
 115b518:	4e 8d 3c 1a          	lea    (%rdx,%r11,1),%r15
 115b51c:	41 89 cc             	mov    %ecx,%r12d
 115b51f:	41 83 e4 f8          	and    $0xfffffff8,%r12d
 115b523:	49 83 c7 07          	add    $0x7,%r15
 115b527:	45 31 f6             	xor    %r14d,%r14d
 115b52a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 115b530:	43 0f b6 54 37 f9    	movzbl -0x7(%r15,%r14,1),%edx
 115b536:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b53a:	43 0f b6 54 37 fa    	movzbl -0x6(%r15,%r14,1),%edx
 115b540:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b544:	43 0f b6 54 37 fb    	movzbl -0x5(%r15,%r14,1),%edx
 115b54a:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b54e:	43 0f b6 54 37 fc    	movzbl -0x4(%r15,%r14,1),%edx
 115b554:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b558:	43 0f b6 54 37 fd    	movzbl -0x3(%r15,%r14,1),%edx
 115b55e:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b562:	43 0f b6 54 37 fe    	movzbl -0x2(%r15,%r14,1),%edx
 115b568:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b56c:	43 0f b6 54 37 ff    	movzbl -0x1(%r15,%r14,1),%edx
 115b572:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b576:	43 0f b6 14 37       	movzbl (%r15,%r14,1),%edx
 115b57b:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b57f:	49 83 c6 08          	add    $0x8,%r14
 115b583:	4d 39 f4             	cmp    %r14,%r12
 115b586:	75 a8                	jne    115b530 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xb90>
 115b588:	83 e1 07             	and    $0x7,%ecx
 115b58b:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115b590:	74 1f                	je     115b5b1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc11>
 115b592:	4d 01 de             	add    %r11,%r14
 115b595:	4c 03 74 24 08       	add    0x8(%rsp),%r14
 115b59a:	31 d2                	xor    %edx,%edx
 115b59c:	0f 1f 40 00          	nopl   0x0(%rax)
 115b5a0:	45 0f b6 1c 16       	movzbl (%r14,%rdx,1),%r11d
 115b5a5:	43 ff 0c 98          	decl   (%r8,%r11,4)
 115b5a9:	48 ff c2             	inc    %rdx
 115b5ac:	48 39 d1             	cmp    %rdx,%rcx
 115b5af:	75 ef                	jne    115b5a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc00>
 115b5b1:	41 39 f2             	cmp    %esi,%r10d
 115b5b4:	89 f1                	mov    %esi,%ecx
 115b5b6:	41 0f 42 ca          	cmovb  %r10d,%ecx
 115b5ba:	39 c8                	cmp    %ecx,%eax
 115b5bc:	0f 47 c8             	cmova  %eax,%ecx
 115b5bf:	44 39 c9             	cmp    %r9d,%ecx
 115b5c2:	0f 83 f8 00 00 00    	jae    115b6c0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd20>
 115b5c8:	44 39 d7             	cmp    %r10d,%edi
 115b5cb:	0f 83 ef 00 00 00    	jae    115b6c0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd20>
 115b5d1:	89 fa                	mov    %edi,%edx
 115b5d3:	29 ca                	sub    %ecx,%edx
 115b5d5:	0f 86 d6 00 00 00    	jbe    115b6b1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd11>
 115b5db:	41 89 ce             	mov    %ecx,%r14d
 115b5de:	41 89 d3             	mov    %edx,%r11d
 115b5e1:	41 ff cb             	dec    %r11d
 115b5e4:	41 83 fb 07          	cmp    $0x7,%r11d
 115b5e8:	4c 89 b4 24 40 01 00 	mov    %r14,0x140(%rsp)
 115b5ef:	00 
 115b5f0:	73 08                	jae    115b5fa <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc5a>
 115b5f2:	45 31 ff             	xor    %r15d,%r15d
 115b5f5:	e9 7e 00 00 00       	jmp    115b678 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xcd8>
 115b5fa:	48 8b 7c 24 08       	mov    0x8(%rsp),%rdi
 115b5ff:	4e 8d 24 37          	lea    (%rdi,%r14,1),%r12
 115b603:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 115b608:	41 89 d3             	mov    %edx,%r11d
 115b60b:	41 83 e3 f8          	and    $0xfffffff8,%r11d
 115b60f:	49 83 c4 07          	add    $0x7,%r12
 115b613:	45 31 ff             	xor    %r15d,%r15d
 115b616:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 115b61d:	00 00 00 
 115b620:	47 0f b6 74 3c f9    	movzbl -0x7(%r12,%r15,1),%r14d
 115b626:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b62a:	47 0f b6 74 3c fa    	movzbl -0x6(%r12,%r15,1),%r14d
 115b630:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b634:	47 0f b6 74 3c fb    	movzbl -0x5(%r12,%r15,1),%r14d
 115b63a:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b63e:	47 0f b6 74 3c fc    	movzbl -0x4(%r12,%r15,1),%r14d
 115b644:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b648:	47 0f b6 74 3c fd    	movzbl -0x3(%r12,%r15,1),%r14d
 115b64e:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b652:	47 0f b6 74 3c fe    	movzbl -0x2(%r12,%r15,1),%r14d
 115b658:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b65c:	47 0f b6 74 3c ff    	movzbl -0x1(%r12,%r15,1),%r14d
 115b662:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b666:	47 0f b6 34 3c       	movzbl (%r12,%r15,1),%r14d
 115b66b:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b66f:	49 83 c7 08          	add    $0x8,%r15
 115b673:	4d 39 fb             	cmp    %r15,%r11
 115b676:	75 a8                	jne    115b620 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc80>
 115b678:	83 e2 07             	and    $0x7,%edx
 115b67b:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115b680:	74 2f                	je     115b6b1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd11>
 115b682:	4c 03 bc 24 40 01 00 	add    0x140(%rsp),%r15
 115b689:	00 
 115b68a:	4c 03 7c 24 08       	add    0x8(%rsp),%r15
 115b68f:	45 31 db             	xor    %r11d,%r11d
 115b692:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b699:	1f 84 00 00 00 00 00 
 115b6a0:	47 0f b6 34 1f       	movzbl (%r15,%r11,1),%r14d
 115b6a5:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b6a9:	49 ff c3             	inc    %r11
 115b6ac:	4c 39 da             	cmp    %r11,%rdx
 115b6af:	75 ef                	jne    115b6a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd00>
 115b6b1:	45 39 ca             	cmp    %r9d,%r10d
 115b6b4:	44 89 ca             	mov    %r9d,%edx
 115b6b7:	41 0f 42 d2          	cmovb  %r10d,%edx
 115b6bb:	39 d1                	cmp    %edx,%ecx
 115b6bd:	0f 46 ca             	cmovbe %edx,%ecx
 115b6c0:	45 89 d3             	mov    %r10d,%r11d
 115b6c3:	41 29 cb             	sub    %ecx,%r11d
 115b6c6:	0f 86 b5 00 00 00    	jbe    115b781 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xde1>
 115b6cc:	89 c9                	mov    %ecx,%ecx
 115b6ce:	44 89 da             	mov    %r11d,%edx
 115b6d1:	ff ca                	dec    %edx
 115b6d3:	83 fa 07             	cmp    $0x7,%edx
 115b6d6:	73 05                	jae    115b6dd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd3d>
 115b6d8:	45 31 f6             	xor    %r14d,%r14d
 115b6db:	eb 7b                	jmp    115b758 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xdb8>
 115b6dd:	48 8b 54 24 08       	mov    0x8(%rsp),%rdx
 115b6e2:	4c 8d 3c 0a          	lea    (%rdx,%rcx,1),%r15
 115b6e6:	44 89 da             	mov    %r11d,%edx
 115b6e9:	83 e2 f8             	and    $0xfffffff8,%edx
 115b6ec:	49 83 c7 07          	add    $0x7,%r15
 115b6f0:	45 31 f6             	xor    %r14d,%r14d
 115b6f3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b6fa:	84 00 00 00 00 00 
 115b700:	47 0f b6 64 37 f9    	movzbl -0x7(%r15,%r14,1),%r12d
 115b706:	43 ff 0c a0          	decl   (%r8,%r12,4)
 115b70a:	47 0f b6 64 37 fa    	movzbl -0x6(%r15,%r14,1),%r12d
 115b710:	43 ff 0c a0          	decl   (%r8,%r12,4)
 115b714:	47 0f b6 64 37 fb    	movzbl -0x5(%r15,%r14,1),%r12d
 115b71a:	43 ff 0c a0          	decl   (%r8,%r12,4)
 115b71e:	47 0f b6 64 37 fc    	movzbl -0x4(%r15,%r14,1),%r12d
 115b724:	43 ff 0c a0          	decl   (%r8,%r12,4)
 115b728:	47 0f b6 64 37 fd    	movzbl -0x3(%r15,%r14,1),%r12d
 115b72e:	43 ff 0c a0          	decl   (%r8,%r12,4)
 115b732:	47 0f b6 64 37 fe    	movzbl -0x2(%r15,%r14,1),%r12d
 115b738:	43 ff 0c a0          	decl   (%r8,%r12,4)
 115b73c:	47 0f b6 64 37 ff    	movzbl -0x1(%r15,%r14,1),%r12d
 115b742:	43 ff 0c a0          	decl   (%r8,%r12,4)
 115b746:	47 0f b6 24 37       	movzbl (%r15,%r14,1),%r12d
 115b74b:	43 ff 0c a0          	decl   (%r8,%r12,4)
 115b74f:	49 83 c6 08          	add    $0x8,%r14
 115b753:	4c 39 f2             	cmp    %r14,%rdx
 115b756:	75 a8                	jne    115b700 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd60>
 115b758:	41 83 e3 07          	and    $0x7,%r11d
 115b75c:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115b761:	74 1e                	je     115b781 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xde1>
 115b763:	49 01 ce             	add    %rcx,%r14
 115b766:	4c 03 74 24 08       	add    0x8(%rsp),%r14
 115b76b:	31 c9                	xor    %ecx,%ecx
 115b76d:	0f 1f 00             	nopl   (%rax)
 115b770:	41 0f b6 14 0e       	movzbl (%r14,%rcx,1),%edx
 115b775:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b779:	48 ff c1             	inc    %rcx
 115b77c:	49 39 cb             	cmp    %rcx,%r11
 115b77f:	75 ef                	jne    115b770 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xdd0>
 115b781:	4d 89 eb             	mov    %r13,%r11
 115b784:	49 c1 eb 20          	shr    $0x20,%r11
 115b788:	44 89 e9             	mov    %r13d,%ecx
 115b78b:	44 39 ee             	cmp    %r13d,%esi
 115b78e:	0f 86 ed 00 00 00    	jbe    115b881 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xee1>
 115b794:	44 89 e9             	mov    %r13d,%ecx
 115b797:	44 39 db             	cmp    %r11d,%ebx
 115b79a:	0f 83 ca 01 00 00    	jae    115b96a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xfca>
 115b7a0:	44 39 eb             	cmp    %r13d,%ebx
 115b7a3:	0f 86 c8 00 00 00    	jbe    115b871 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xed1>
 115b7a9:	45 89 ee             	mov    %r13d,%r14d
 115b7ac:	48 89 d9             	mov    %rbx,%rcx
 115b7af:	4c 29 e9             	sub    %r13,%rcx
 115b7b2:	89 ca                	mov    %ecx,%edx
 115b7b4:	48 ff ca             	dec    %rdx
 115b7b7:	48 83 fa 07          	cmp    $0x7,%rdx
 115b7bb:	4c 89 b4 24 40 01 00 	mov    %r14,0x140(%rsp)
 115b7c2:	00 
 115b7c3:	73 05                	jae    115b7ca <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xe2a>
 115b7c5:	45 31 ff             	xor    %r15d,%r15d
 115b7c8:	eb 6e                	jmp    115b838 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xe98>
 115b7ca:	48 8b 54 24 08       	mov    0x8(%rsp),%rdx
 115b7cf:	4e 8d 24 32          	lea    (%rdx,%r14,1),%r12
 115b7d3:	89 ca                	mov    %ecx,%edx
 115b7d5:	83 e2 f8             	and    $0xfffffff8,%edx
 115b7d8:	49 83 c4 07          	add    $0x7,%r12
 115b7dc:	45 31 ff             	xor    %r15d,%r15d
 115b7df:	90                   	nop
 115b7e0:	47 0f b6 74 3c f9    	movzbl -0x7(%r12,%r15,1),%r14d
 115b7e6:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b7ea:	47 0f b6 74 3c fa    	movzbl -0x6(%r12,%r15,1),%r14d
 115b7f0:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b7f4:	47 0f b6 74 3c fb    	movzbl -0x5(%r12,%r15,1),%r14d
 115b7fa:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b7fe:	47 0f b6 74 3c fc    	movzbl -0x4(%r12,%r15,1),%r14d
 115b804:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b808:	47 0f b6 74 3c fd    	movzbl -0x3(%r12,%r15,1),%r14d
 115b80e:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b812:	47 0f b6 74 3c fe    	movzbl -0x2(%r12,%r15,1),%r14d
 115b818:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b81c:	47 0f b6 74 3c ff    	movzbl -0x1(%r12,%r15,1),%r14d
 115b822:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b826:	47 0f b6 34 3c       	movzbl (%r12,%r15,1),%r14d
 115b82b:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b82f:	49 83 c7 08          	add    $0x8,%r15
 115b833:	4c 39 fa             	cmp    %r15,%rdx
 115b836:	75 a8                	jne    115b7e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xe40>
 115b838:	83 e1 07             	and    $0x7,%ecx
 115b83b:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115b840:	74 2f                	je     115b871 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xed1>
 115b842:	4c 03 bc 24 40 01 00 	add    0x140(%rsp),%r15
 115b849:	00 
 115b84a:	4c 03 7c 24 08       	add    0x8(%rsp),%r15
 115b84f:	31 d2                	xor    %edx,%edx
 115b851:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b858:	0f 1f 84 00 00 00 00 
 115b85f:	00 
 115b860:	45 0f b6 34 17       	movzbl (%r15,%rdx,1),%r14d
 115b865:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b869:	48 ff c2             	inc    %rdx
 115b86c:	48 39 d1             	cmp    %rdx,%rcx
 115b86f:	75 ef                	jne    115b860 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xec0>
 115b871:	41 39 f3             	cmp    %esi,%r11d
 115b874:	89 f1                	mov    %esi,%ecx
 115b876:	41 0f 42 cb          	cmovb  %r11d,%ecx
 115b87a:	41 39 cd             	cmp    %ecx,%r13d
 115b87d:	41 0f 47 cd          	cmova  %r13d,%ecx
 115b881:	44 39 c9             	cmp    %r9d,%ecx
 115b884:	0f 83 e0 00 00 00    	jae    115b96a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xfca>
 115b88a:	44 39 df             	cmp    %r11d,%edi
 115b88d:	0f 83 d7 00 00 00    	jae    115b96a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xfca>
 115b893:	41 89 fe             	mov    %edi,%r14d
 115b896:	41 29 ce             	sub    %ecx,%r14d
 115b899:	0f 86 b2 00 00 00    	jbe    115b951 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xfb1>
 115b89f:	89 cf                	mov    %ecx,%edi
 115b8a1:	44 89 f2             	mov    %r14d,%edx
 115b8a4:	ff ca                	dec    %edx
 115b8a6:	83 fa 07             	cmp    $0x7,%edx
 115b8a9:	48 89 bc 24 40 01 00 	mov    %rdi,0x140(%rsp)
 115b8b0:	00 
 115b8b1:	73 05                	jae    115b8b8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xf18>
 115b8b3:	45 31 e4             	xor    %r12d,%r12d
 115b8b6:	eb 70                	jmp    115b928 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xf88>
 115b8b8:	48 8b 54 24 08       	mov    0x8(%rsp),%rdx
 115b8bd:	4c 8d 3c 3a          	lea    (%rdx,%rdi,1),%r15
 115b8c1:	44 89 f2             	mov    %r14d,%edx
 115b8c4:	83 e2 f8             	and    $0xfffffff8,%edx
 115b8c7:	49 83 c7 07          	add    $0x7,%r15
 115b8cb:	45 31 e4             	xor    %r12d,%r12d
 115b8ce:	66 90                	xchg   %ax,%ax
 115b8d0:	43 0f b6 7c 27 f9    	movzbl -0x7(%r15,%r12,1),%edi
 115b8d6:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b8da:	43 0f b6 7c 27 fa    	movzbl -0x6(%r15,%r12,1),%edi
 115b8e0:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b8e4:	43 0f b6 7c 27 fb    	movzbl -0x5(%r15,%r12,1),%edi
 115b8ea:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b8ee:	43 0f b6 7c 27 fc    	movzbl -0x4(%r15,%r12,1),%edi
 115b8f4:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b8f8:	43 0f b6 7c 27 fd    	movzbl -0x3(%r15,%r12,1),%edi
 115b8fe:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b902:	43 0f b6 7c 27 fe    	movzbl -0x2(%r15,%r12,1),%edi
 115b908:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b90c:	43 0f b6 7c 27 ff    	movzbl -0x1(%r15,%r12,1),%edi
 115b912:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b916:	43 0f b6 3c 27       	movzbl (%r15,%r12,1),%edi
 115b91b:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b91f:	49 83 c4 08          	add    $0x8,%r12
 115b923:	4c 39 e2             	cmp    %r12,%rdx
 115b926:	75 a8                	jne    115b8d0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xf30>
 115b928:	41 83 e6 07          	and    $0x7,%r14d
 115b92c:	74 23                	je     115b951 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xfb1>
 115b92e:	4c 03 a4 24 40 01 00 	add    0x140(%rsp),%r12
 115b935:	00 
 115b936:	4c 03 64 24 08       	add    0x8(%rsp),%r12
 115b93b:	31 d2                	xor    %edx,%edx
 115b93d:	0f 1f 00             	nopl   (%rax)
 115b940:	41 0f b6 3c 14       	movzbl (%r12,%rdx,1),%edi
 115b945:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b949:	48 ff c2             	inc    %rdx
 115b94c:	49 39 d6             	cmp    %rdx,%r14
 115b94f:	75 ef                	jne    115b940 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xfa0>
 115b951:	45 39 cb             	cmp    %r9d,%r11d
 115b954:	44 89 ca             	mov    %r9d,%edx
 115b957:	41 0f 42 d3          	cmovb  %r11d,%edx
 115b95b:	39 d1                	cmp    %edx,%ecx
 115b95d:	0f 46 ca             	cmovbe %edx,%ecx
 115b960:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115b965:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 115b96a:	45 89 de             	mov    %r11d,%r14d
 115b96d:	41 29 ce             	sub    %ecx,%r14d
 115b970:	0f 86 bb 00 00 00    	jbe    115ba31 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1091>
 115b976:	89 c9                	mov    %ecx,%ecx
 115b978:	44 89 f2             	mov    %r14d,%edx
 115b97b:	ff ca                	dec    %edx
 115b97d:	83 fa 07             	cmp    $0x7,%edx
 115b980:	73 05                	jae    115b987 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xfe7>
 115b982:	45 31 ff             	xor    %r15d,%r15d
 115b985:	eb 71                	jmp    115b9f8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1058>
 115b987:	48 8b 54 24 08       	mov    0x8(%rsp),%rdx
 115b98c:	4c 8d 24 0a          	lea    (%rdx,%rcx,1),%r12
 115b990:	44 89 f2             	mov    %r14d,%edx
 115b993:	83 e2 f8             	and    $0xfffffff8,%edx
 115b996:	49 83 c4 07          	add    $0x7,%r12
 115b99a:	45 31 ff             	xor    %r15d,%r15d
 115b99d:	0f 1f 00             	nopl   (%rax)
 115b9a0:	43 0f b6 7c 3c f9    	movzbl -0x7(%r12,%r15,1),%edi
 115b9a6:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b9aa:	43 0f b6 7c 3c fa    	movzbl -0x6(%r12,%r15,1),%edi
 115b9b0:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b9b4:	43 0f b6 7c 3c fb    	movzbl -0x5(%r12,%r15,1),%edi
 115b9ba:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b9be:	43 0f b6 7c 3c fc    	movzbl -0x4(%r12,%r15,1),%edi
 115b9c4:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b9c8:	43 0f b6 7c 3c fd    	movzbl -0x3(%r12,%r15,1),%edi
 115b9ce:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b9d2:	43 0f b6 7c 3c fe    	movzbl -0x2(%r12,%r15,1),%edi
 115b9d8:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b9dc:	43 0f b6 7c 3c ff    	movzbl -0x1(%r12,%r15,1),%edi
 115b9e2:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b9e6:	43 0f b6 3c 3c       	movzbl (%r12,%r15,1),%edi
 115b9eb:	41 ff 0c b8          	decl   (%r8,%rdi,4)
 115b9ef:	49 83 c7 08          	add    $0x8,%r15
 115b9f3:	4c 39 fa             	cmp    %r15,%rdx
 115b9f6:	75 a8                	jne    115b9a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1000>
 115b9f8:	41 83 e6 07          	and    $0x7,%r14d
 115b9fc:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115ba01:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 115ba06:	74 29                	je     115ba31 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1091>
 115ba08:	49 01 cf             	add    %rcx,%r15
 115ba0b:	4c 03 7c 24 08       	add    0x8(%rsp),%r15
 115ba10:	31 c9                	xor    %ecx,%ecx
 115ba12:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115ba19:	1f 84 00 00 00 00 00 
 115ba20:	41 0f b6 14 0f       	movzbl (%r15,%rcx,1),%edx
 115ba25:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115ba29:	48 ff c1             	inc    %rcx
 115ba2c:	49 39 ce             	cmp    %rcx,%r14
 115ba2f:	75 ef                	jne    115ba20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1080>
 115ba31:	41 39 da             	cmp    %ebx,%r10d
 115ba34:	76 2a                	jbe    115ba60 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x10c0>
 115ba36:	39 c6                	cmp    %eax,%esi
 115ba38:	76 39                	jbe    115ba73 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x10d3>
 115ba3a:	39 d8                	cmp    %ebx,%eax
 115ba3c:	0f 86 df 00 00 00    	jbe    115bb21 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1181>
 115ba42:	41 89 de             	mov    %ebx,%r14d
 115ba45:	48 89 c1             	mov    %rax,%rcx
 115ba48:	48 29 d9             	sub    %rbx,%rcx
 115ba4b:	89 ca                	mov    %ecx,%edx
 115ba4d:	48 ff ca             	dec    %rdx
 115ba50:	48 83 fa 07          	cmp    $0x7,%rdx
 115ba54:	73 27                	jae    115ba7d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x10dd>
 115ba56:	45 31 ff             	xor    %r15d,%r15d
 115ba59:	e9 9a 00 00 00       	jmp    115baf8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1158>
 115ba5e:	66 90                	xchg   %ax,%ax
 115ba60:	44 8b 74 24 1c       	mov    0x1c(%rsp),%r14d
 115ba65:	44 39 ee             	cmp    %r13d,%esi
 115ba68:	0f 87 d6 00 00 00    	ja     115bb44 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x11a4>
 115ba6e:	e9 a8 01 00 00       	jmp    115bc1b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x127b>
 115ba73:	44 8b 74 24 1c       	mov    0x1c(%rsp),%r14d
 115ba78:	e9 9e 01 00 00       	jmp    115bc1b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x127b>
 115ba7d:	48 8b 54 24 08       	mov    0x8(%rsp),%rdx
 115ba82:	4e 8d 24 32          	lea    (%rdx,%r14,1),%r12
 115ba86:	89 ca                	mov    %ecx,%edx
 115ba88:	83 e2 f8             	and    $0xfffffff8,%edx
 115ba8b:	49 83 c4 07          	add    $0x7,%r12
 115ba8f:	45 31 ff             	xor    %r15d,%r15d
 115ba92:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115ba99:	1f 84 00 00 00 00 00 
 115baa0:	43 0f b6 7c 3c f9    	movzbl -0x7(%r12,%r15,1),%edi
 115baa6:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115baaa:	43 0f b6 7c 3c fa    	movzbl -0x6(%r12,%r15,1),%edi
 115bab0:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bab4:	43 0f b6 7c 3c fb    	movzbl -0x5(%r12,%r15,1),%edi
 115baba:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115babe:	43 0f b6 7c 3c fc    	movzbl -0x4(%r12,%r15,1),%edi
 115bac4:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bac8:	43 0f b6 7c 3c fd    	movzbl -0x3(%r12,%r15,1),%edi
 115bace:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bad2:	43 0f b6 7c 3c fe    	movzbl -0x2(%r12,%r15,1),%edi
 115bad8:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115badc:	43 0f b6 7c 3c ff    	movzbl -0x1(%r12,%r15,1),%edi
 115bae2:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bae6:	43 0f b6 3c 3c       	movzbl (%r12,%r15,1),%edi
 115baeb:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115baef:	49 83 c7 08          	add    $0x8,%r15
 115baf3:	4c 39 fa             	cmp    %r15,%rdx
 115baf6:	75 a8                	jne    115baa0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1100>
 115baf8:	83 e1 07             	and    $0x7,%ecx
 115bafb:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115bb00:	74 1f                	je     115bb21 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1181>
 115bb02:	4d 01 f7             	add    %r14,%r15
 115bb05:	4c 03 7c 24 08       	add    0x8(%rsp),%r15
 115bb0a:	31 d2                	xor    %edx,%edx
 115bb0c:	0f 1f 40 00          	nopl   0x0(%rax)
 115bb10:	41 0f b6 3c 17       	movzbl (%r15,%rdx,1),%edi
 115bb15:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bb19:	48 ff c2             	inc    %rdx
 115bb1c:	48 39 d1             	cmp    %rdx,%rcx
 115bb1f:	75 ef                	jne    115bb10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1170>
 115bb21:	44 39 d6             	cmp    %r10d,%esi
 115bb24:	44 89 d1             	mov    %r10d,%ecx
 115bb27:	0f 42 ce             	cmovb  %esi,%ecx
 115bb2a:	39 cb                	cmp    %ecx,%ebx
 115bb2c:	0f 47 cb             	cmova  %ebx,%ecx
 115bb2f:	89 cb                	mov    %ecx,%ebx
 115bb31:	44 8b 74 24 1c       	mov    0x1c(%rsp),%r14d
 115bb36:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 115bb3b:	44 39 ee             	cmp    %r13d,%esi
 115bb3e:	0f 86 d7 00 00 00    	jbe    115bc1b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x127b>
 115bb44:	44 39 db             	cmp    %r11d,%ebx
 115bb47:	0f 83 ce 00 00 00    	jae    115bc1b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x127b>
 115bb4d:	44 89 e9             	mov    %r13d,%ecx
 115bb50:	29 d9                	sub    %ebx,%ecx
 115bb52:	0f 86 a9 00 00 00    	jbe    115bc01 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1261>
 115bb58:	41 89 de             	mov    %ebx,%r14d
 115bb5b:	89 ca                	mov    %ecx,%edx
 115bb5d:	ff ca                	dec    %edx
 115bb5f:	83 fa 07             	cmp    $0x7,%edx
 115bb62:	73 05                	jae    115bb69 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x11c9>
 115bb64:	45 31 ff             	xor    %r15d,%r15d
 115bb67:	eb 6f                	jmp    115bbd8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1238>
 115bb69:	48 8b 54 24 08       	mov    0x8(%rsp),%rdx
 115bb6e:	4e 8d 24 32          	lea    (%rdx,%r14,1),%r12
 115bb72:	89 ca                	mov    %ecx,%edx
 115bb74:	83 e2 f8             	and    $0xfffffff8,%edx
 115bb77:	49 83 c4 07          	add    $0x7,%r12
 115bb7b:	45 31 ff             	xor    %r15d,%r15d
 115bb7e:	66 90                	xchg   %ax,%ax
 115bb80:	43 0f b6 7c 3c f9    	movzbl -0x7(%r12,%r15,1),%edi
 115bb86:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bb8a:	43 0f b6 7c 3c fa    	movzbl -0x6(%r12,%r15,1),%edi
 115bb90:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bb94:	43 0f b6 7c 3c fb    	movzbl -0x5(%r12,%r15,1),%edi
 115bb9a:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bb9e:	43 0f b6 7c 3c fc    	movzbl -0x4(%r12,%r15,1),%edi
 115bba4:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bba8:	43 0f b6 7c 3c fd    	movzbl -0x3(%r12,%r15,1),%edi
 115bbae:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bbb2:	43 0f b6 7c 3c fe    	movzbl -0x2(%r12,%r15,1),%edi
 115bbb8:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bbbc:	43 0f b6 7c 3c ff    	movzbl -0x1(%r12,%r15,1),%edi
 115bbc2:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bbc6:	43 0f b6 3c 3c       	movzbl (%r12,%r15,1),%edi
 115bbcb:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bbcf:	49 83 c7 08          	add    $0x8,%r15
 115bbd3:	4c 39 fa             	cmp    %r15,%rdx
 115bbd6:	75 a8                	jne    115bb80 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x11e0>
 115bbd8:	83 e1 07             	and    $0x7,%ecx
 115bbdb:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115bbe0:	74 1f                	je     115bc01 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1261>
 115bbe2:	4d 01 f7             	add    %r14,%r15
 115bbe5:	4c 03 7c 24 08       	add    0x8(%rsp),%r15
 115bbea:	31 d2                	xor    %edx,%edx
 115bbec:	0f 1f 40 00          	nopl   0x0(%rax)
 115bbf0:	41 0f b6 3c 17       	movzbl (%r15,%rdx,1),%edi
 115bbf5:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bbf9:	48 ff c2             	inc    %rdx
 115bbfc:	48 39 d1             	cmp    %rdx,%rcx
 115bbff:	75 ef                	jne    115bbf0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1250>
 115bc01:	44 39 de             	cmp    %r11d,%esi
 115bc04:	44 89 d9             	mov    %r11d,%ecx
 115bc07:	0f 42 ce             	cmovb  %esi,%ecx
 115bc0a:	39 cb                	cmp    %ecx,%ebx
 115bc0c:	0f 47 cb             	cmova  %ebx,%ecx
 115bc0f:	89 cb                	mov    %ecx,%ebx
 115bc11:	44 8b 74 24 1c       	mov    0x1c(%rsp),%r14d
 115bc16:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 115bc1b:	29 de                	sub    %ebx,%esi
 115bc1d:	0f 86 bd 00 00 00    	jbe    115bce0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1340>
 115bc23:	89 d9                	mov    %ebx,%ecx
 115bc25:	89 f2                	mov    %esi,%edx
 115bc27:	ff ca                	dec    %edx
 115bc29:	83 fa 07             	cmp    $0x7,%edx
 115bc2c:	73 04                	jae    115bc32 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1292>
 115bc2e:	31 db                	xor    %ebx,%ebx
 115bc30:	eb 76                	jmp    115bca8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1308>
 115bc32:	48 8b 54 24 08       	mov    0x8(%rsp),%rdx
 115bc37:	4c 8d 34 0a          	lea    (%rdx,%rcx,1),%r14
 115bc3b:	89 f2                	mov    %esi,%edx
 115bc3d:	83 e2 f8             	and    $0xfffffff8,%edx
 115bc40:	49 83 c6 07          	add    $0x7,%r14
 115bc44:	31 db                	xor    %ebx,%ebx
 115bc46:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 115bc4d:	00 00 00 
 115bc50:	41 0f b6 7c 1e f9    	movzbl -0x7(%r14,%rbx,1),%edi
 115bc56:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bc5a:	41 0f b6 7c 1e fa    	movzbl -0x6(%r14,%rbx,1),%edi
 115bc60:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bc64:	41 0f b6 7c 1e fb    	movzbl -0x5(%r14,%rbx,1),%edi
 115bc6a:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bc6e:	41 0f b6 7c 1e fc    	movzbl -0x4(%r14,%rbx,1),%edi
 115bc74:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bc78:	41 0f b6 7c 1e fd    	movzbl -0x3(%r14,%rbx,1),%edi
 115bc7e:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bc82:	41 0f b6 7c 1e fe    	movzbl -0x2(%r14,%rbx,1),%edi
 115bc88:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bc8c:	41 0f b6 7c 1e ff    	movzbl -0x1(%r14,%rbx,1),%edi
 115bc92:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bc96:	41 0f b6 3c 1e       	movzbl (%r14,%rbx,1),%edi
 115bc9b:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bc9f:	48 83 c3 08          	add    $0x8,%rbx
 115bca3:	48 39 da             	cmp    %rbx,%rdx
 115bca6:	75 a8                	jne    115bc50 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x12b0>
 115bca8:	83 e6 07             	and    $0x7,%esi
 115bcab:	44 8b 74 24 1c       	mov    0x1c(%rsp),%r14d
 115bcb0:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 115bcb5:	74 29                	je     115bce0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1340>
 115bcb7:	48 01 cb             	add    %rcx,%rbx
 115bcba:	48 03 5c 24 08       	add    0x8(%rsp),%rbx
 115bcbf:	31 c9                	xor    %ecx,%ecx
 115bcc1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bcc8:	0f 1f 84 00 00 00 00 
 115bccf:	00 
 115bcd0:	0f b6 14 0b          	movzbl (%rbx,%rcx,1),%edx
 115bcd4:	41 ff 04 90          	incl   (%r8,%rdx,4)
 115bcd8:	48 ff c1             	inc    %rcx
 115bcdb:	48 39 ce             	cmp    %rcx,%rsi
 115bcde:	75 f0                	jne    115bcd0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1330>
 115bce0:	41 39 fa             	cmp    %edi,%r10d
 115bce3:	0f 86 d8 00 00 00    	jbe    115bdc1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1421>
 115bce9:	44 39 c8             	cmp    %r9d,%eax
 115bcec:	0f 83 af 01 00 00    	jae    115bea1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1501>
 115bcf2:	39 f8                	cmp    %edi,%eax
 115bcf4:	0f 86 b6 00 00 00    	jbe    115bdb0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1410>
 115bcfa:	89 f9                	mov    %edi,%ecx
 115bcfc:	48 29 f8             	sub    %rdi,%rax
 115bcff:	89 c2                	mov    %eax,%edx
 115bd01:	48 ff ca             	dec    %rdx
 115bd04:	48 83 fa 07          	cmp    $0x7,%rdx
 115bd08:	73 04                	jae    115bd0e <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x136e>
 115bd0a:	31 f6                	xor    %esi,%esi
 115bd0c:	eb 72                	jmp    115bd80 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x13e0>
 115bd0e:	48 8b 54 24 08       	mov    0x8(%rsp),%rdx
 115bd13:	48 8d 1c 0a          	lea    (%rdx,%rcx,1),%rbx
 115bd17:	89 c2                	mov    %eax,%edx
 115bd19:	83 e2 f8             	and    $0xfffffff8,%edx
 115bd1c:	48 83 c3 07          	add    $0x7,%rbx
 115bd20:	31 f6                	xor    %esi,%esi
 115bd22:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bd29:	1f 84 00 00 00 00 00 
 115bd30:	0f b6 7c 33 f9       	movzbl -0x7(%rbx,%rsi,1),%edi
 115bd35:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bd39:	0f b6 7c 33 fa       	movzbl -0x6(%rbx,%rsi,1),%edi
 115bd3e:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bd42:	0f b6 7c 33 fb       	movzbl -0x5(%rbx,%rsi,1),%edi
 115bd47:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bd4b:	0f b6 7c 33 fc       	movzbl -0x4(%rbx,%rsi,1),%edi
 115bd50:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bd54:	0f b6 7c 33 fd       	movzbl -0x3(%rbx,%rsi,1),%edi
 115bd59:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bd5d:	0f b6 7c 33 fe       	movzbl -0x2(%rbx,%rsi,1),%edi
 115bd62:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bd66:	0f b6 7c 33 ff       	movzbl -0x1(%rbx,%rsi,1),%edi
 115bd6b:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bd6f:	0f b6 3c 33          	movzbl (%rbx,%rsi,1),%edi
 115bd73:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bd77:	48 83 c6 08          	add    $0x8,%rsi
 115bd7b:	48 39 f2             	cmp    %rsi,%rdx
 115bd7e:	75 b0                	jne    115bd30 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1390>
 115bd80:	83 e0 07             	and    $0x7,%eax
 115bd83:	48 8b 7c 24 50       	mov    0x50(%rsp),%rdi
 115bd88:	74 26                	je     115bdb0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1410>
 115bd8a:	48 01 ce             	add    %rcx,%rsi
 115bd8d:	48 03 74 24 08       	add    0x8(%rsp),%rsi
 115bd92:	31 c9                	xor    %ecx,%ecx
 115bd94:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bd9b:	00 00 00 00 00 
 115bda0:	0f b6 14 0e          	movzbl (%rsi,%rcx,1),%edx
 115bda4:	41 ff 04 90          	incl   (%r8,%rdx,4)
 115bda8:	48 ff c1             	inc    %rcx
 115bdab:	48 39 c8             	cmp    %rcx,%rax
 115bdae:	75 f0                	jne    115bda0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1400>
 115bdb0:	45 39 d1             	cmp    %r10d,%r9d
 115bdb3:	45 0f 42 d1          	cmovb  %r9d,%r10d
 115bdb7:	44 39 d7             	cmp    %r10d,%edi
 115bdba:	44 0f 47 d7          	cmova  %edi,%r10d
 115bdbe:	44 89 d7             	mov    %r10d,%edi
 115bdc1:	44 39 df             	cmp    %r11d,%edi
 115bdc4:	0f 83 d7 00 00 00    	jae    115bea1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1501>
 115bdca:	45 39 cd             	cmp    %r9d,%r13d
 115bdcd:	0f 83 ce 00 00 00    	jae    115bea1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1501>
 115bdd3:	41 29 fd             	sub    %edi,%r13d
 115bdd6:	0f 86 b4 00 00 00    	jbe    115be90 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x14f0>
 115bddc:	49 89 fa             	mov    %rdi,%r10
 115bddf:	89 f8                	mov    %edi,%eax
 115bde1:	44 89 e9             	mov    %r13d,%ecx
 115bde4:	ff c9                	dec    %ecx
 115bde6:	83 f9 07             	cmp    $0x7,%ecx
 115bde9:	73 04                	jae    115bdef <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x144f>
 115bdeb:	31 c9                	xor    %ecx,%ecx
 115bded:	eb 71                	jmp    115be60 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x14c0>
 115bdef:	48 8b 4c 24 08       	mov    0x8(%rsp),%rcx
 115bdf4:	48 8d 34 01          	lea    (%rcx,%rax,1),%rsi
 115bdf8:	44 89 ea             	mov    %r13d,%edx
 115bdfb:	83 e2 f8             	and    $0xfffffff8,%edx
 115bdfe:	48 83 c6 07          	add    $0x7,%rsi
 115be02:	31 c9                	xor    %ecx,%ecx
 115be04:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115be0b:	00 00 00 00 00 
 115be10:	0f b6 7c 0e f9       	movzbl -0x7(%rsi,%rcx,1),%edi
 115be15:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115be19:	0f b6 7c 0e fa       	movzbl -0x6(%rsi,%rcx,1),%edi
 115be1e:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115be22:	0f b6 7c 0e fb       	movzbl -0x5(%rsi,%rcx,1),%edi
 115be27:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115be2b:	0f b6 7c 0e fc       	movzbl -0x4(%rsi,%rcx,1),%edi
 115be30:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115be34:	0f b6 7c 0e fd       	movzbl -0x3(%rsi,%rcx,1),%edi
 115be39:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115be3d:	0f b6 7c 0e fe       	movzbl -0x2(%rsi,%rcx,1),%edi
 115be42:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115be46:	0f b6 7c 0e ff       	movzbl -0x1(%rsi,%rcx,1),%edi
 115be4b:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115be4f:	0f b6 3c 0e          	movzbl (%rsi,%rcx,1),%edi
 115be53:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115be57:	48 83 c1 08          	add    $0x8,%rcx
 115be5b:	48 39 ca             	cmp    %rcx,%rdx
 115be5e:	75 b0                	jne    115be10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1470>
 115be60:	41 83 e5 07          	and    $0x7,%r13d
 115be64:	4c 89 d7             	mov    %r10,%rdi
 115be67:	74 27                	je     115be90 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x14f0>
 115be69:	48 01 c1             	add    %rax,%rcx
 115be6c:	48 03 4c 24 08       	add    0x8(%rsp),%rcx
 115be71:	31 c0                	xor    %eax,%eax
 115be73:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115be7a:	84 00 00 00 00 00 
 115be80:	0f b6 14 01          	movzbl (%rcx,%rax,1),%edx
 115be84:	41 ff 04 90          	incl   (%r8,%rdx,4)
 115be88:	48 ff c0             	inc    %rax
 115be8b:	49 39 c5             	cmp    %rax,%r13
 115be8e:	75 f0                	jne    115be80 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x14e0>
 115be90:	45 39 d9             	cmp    %r11d,%r9d
 115be93:	45 0f 42 d9          	cmovb  %r9d,%r11d
 115be97:	44 39 df             	cmp    %r11d,%edi
 115be9a:	44 0f 47 df          	cmova  %edi,%r11d
 115be9e:	44 89 df             	mov    %r11d,%edi
 115bea1:	41 29 f9             	sub    %edi,%r9d
 115bea4:	0f 86 c6 f5 ff ff    	jbe    115b470 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xad0>
 115beaa:	89 f8                	mov    %edi,%eax
 115beac:	44 89 c9             	mov    %r9d,%ecx
 115beaf:	ff c9                	dec    %ecx
 115beb1:	83 f9 07             	cmp    $0x7,%ecx
 115beb4:	73 04                	jae    115beba <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x151a>
 115beb6:	31 c9                	xor    %ecx,%ecx
 115beb8:	eb 66                	jmp    115bf20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1580>
 115beba:	48 8b 4c 24 08       	mov    0x8(%rsp),%rcx
 115bebf:	48 8d 14 01          	lea    (%rcx,%rax,1),%rdx
 115bec3:	44 89 ce             	mov    %r9d,%esi
 115bec6:	83 e6 f8             	and    $0xfffffff8,%esi
 115bec9:	48 83 c2 07          	add    $0x7,%rdx
 115becd:	31 c9                	xor    %ecx,%ecx
 115becf:	90                   	nop
 115bed0:	0f b6 7c 0a f9       	movzbl -0x7(%rdx,%rcx,1),%edi
 115bed5:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bed9:	0f b6 7c 0a fa       	movzbl -0x6(%rdx,%rcx,1),%edi
 115bede:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bee2:	0f b6 7c 0a fb       	movzbl -0x5(%rdx,%rcx,1),%edi
 115bee7:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115beeb:	0f b6 7c 0a fc       	movzbl -0x4(%rdx,%rcx,1),%edi
 115bef0:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bef4:	0f b6 7c 0a fd       	movzbl -0x3(%rdx,%rcx,1),%edi
 115bef9:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115befd:	0f b6 7c 0a fe       	movzbl -0x2(%rdx,%rcx,1),%edi
 115bf02:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf06:	0f b6 7c 0a ff       	movzbl -0x1(%rdx,%rcx,1),%edi
 115bf0b:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf0f:	0f b6 3c 0a          	movzbl (%rdx,%rcx,1),%edi
 115bf13:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf17:	48 83 c1 08          	add    $0x8,%rcx
 115bf1b:	48 39 ce             	cmp    %rcx,%rsi
 115bf1e:	75 b0                	jne    115bed0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1530>
 115bf20:	41 83 e1 07          	and    $0x7,%r9d
 115bf24:	0f 84 46 f5 ff ff    	je     115b470 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xad0>
 115bf2a:	48 01 c1             	add    %rax,%rcx
 115bf2d:	48 03 4c 24 08       	add    0x8(%rsp),%rcx
 115bf32:	31 c0                	xor    %eax,%eax
 115bf34:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bf3b:	00 00 00 00 00 
 115bf40:	0f b6 14 01          	movzbl (%rcx,%rax,1),%edx
 115bf44:	41 ff 04 90          	incl   (%r8,%rdx,4)
 115bf48:	48 ff c0             	inc    %rax
 115bf4b:	49 39 c1             	cmp    %rax,%r9
 115bf4e:	75 f0                	jne    115bf40 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x15a0>
 115bf50:	e9 1b f5 ff ff       	jmp    115b470 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xad0>
 115bf55:	c5 fc 10 84 24 70 02 	vmovups 0x270(%rsp),%ymm0
 115bf5c:	00 00 
 115bf5e:	c5 fc 10 8c 24 90 02 	vmovups 0x290(%rsp),%ymm1
 115bf65:	00 00 
 115bf67:	48 8b 84 24 c0 00 00 	mov    0xc0(%rsp),%rax
 115bf6e:	00 
 115bf6f:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 115bf74:	c5 fc 11 00          	vmovups %ymm0,(%rax)
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
 115bfb2:	48 c7 c0 f8 ff ff ff 	mov    $0xfffffffffffffff8,%rax
 115bfb9:	31 db                	xor    %ebx,%ebx
 115bfbb:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 115bfc2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bfc9:	1f 84 00 00 00 00 00 
 115bfd0:	c5 fe 6f 84 84 20 11 	vmovdqu 0x1120(%rsp,%rax,4),%ymm0
 115bfd7:	00 00 
 115bfd9:	c5 fe 6f 8c 84 40 11 	vmovdqu 0x1140(%rsp,%rax,4),%ymm1
 115bfe0:	00 00 
 115bfe2:	c5 fd fe 84 84 20 0d 	vpaddd 0xd20(%rsp,%rax,4),%ymm0,%ymm0
 115bfe9:	00 00 
 115bfeb:	c5 fd fe 84 84 20 15 	vpaddd 0x1520(%rsp,%rax,4),%ymm0,%ymm0
 115bff2:	00 00 
 115bff4:	c5 fd fe 84 84 20 19 	vpaddd 0x1920(%rsp,%rax,4),%ymm0,%ymm0
 115bffb:	00 00 
 115bffd:	c5 fe 7f 84 84 e0 03 	vmovdqu %ymm0,0x3e0(%rsp,%rax,4)
 115c004:	00 00 
 115c006:	c5 fd 76 c4          	vpcmpeqd %ymm4,%ymm0,%ymm0
 115c00a:	c5 fc 50 c8          	vmovmskps %ymm0,%ecx
 115c00e:	81 f1 ff 00 00 00    	xor    $0xff,%ecx
 115c014:	f3 0f b8 c9          	popcnt %ecx,%ecx
 115c018:	c5 f5 fe 84 84 40 0d 	vpaddd 0xd40(%rsp,%rax,4),%ymm1,%ymm0
 115c01f:	00 00 
 115c021:	c5 fd fe 84 84 40 15 	vpaddd 0x1540(%rsp,%rax,4),%ymm0,%ymm0
 115c028:	00 00 
 115c02a:	48 01 d9             	add    %rbx,%rcx
 115c02d:	c5 fd fe 84 84 40 19 	vpaddd 0x1940(%rsp,%rax,4),%ymm0,%ymm0
 115c034:	00 00 
 115c036:	c5 fe 7f 84 84 00 04 	vmovdqu %ymm0,0x400(%rsp,%rax,4)
 115c03d:	00 00 
 115c03f:	c5 fd 76 c4          	vpcmpeqd %ymm4,%ymm0,%ymm0
 115c043:	c5 fc 50 d0          	vmovmskps %ymm0,%edx
 115c047:	81 f2 ff 00 00 00    	xor    $0xff,%edx
 115c04d:	31 db                	xor    %ebx,%ebx
 115c04f:	f3 0f b8 da          	popcnt %edx,%ebx
 115c053:	48 01 cb             	add    %rcx,%rbx
 115c056:	48 83 c0 10          	add    $0x10,%rax
 115c05a:	48 3d f8 00 00 00    	cmp    $0xf8,%rax
 115c060:	0f 82 6a ff ff ff    	jb     115bfd0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1630>
 115c066:	49 81 ff ff ff 0f 00 	cmp    $0xfffff,%r15
 115c06d:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115c072:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115c077:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115c07e:	79 37 9e 
 115c081:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115c086:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115c08b:	0f 87 41 f3 ff ff    	ja     115b3d2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa32>
 115c091:	c6 84 24 80 28 00 00 	movb   $0x0,0x2880(%rsp)
 115c098:	00 
 115c099:	31 c0                	xor    %eax,%eax
 115c09b:	84 c0                	test   %al,%al
 115c09d:	0f 85 2f f3 ff ff    	jne    115b3d2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa32>
 115c0a3:	49 81 ff 00 10 00 00 	cmp    $0x1000,%r15
 115c0aa:	b8 03 00 00 00       	mov    $0x3,%eax
 115c0af:	48 83 d8 00          	sbb    $0x0,%rax
 115c0b3:	49 83 ff 20          	cmp    $0x20,%r15
 115c0b7:	b9 01 00 00 00       	mov    $0x1,%ecx
 115c0bc:	48 0f 42 c1          	cmovb  %rcx,%rax
 115c0c0:	48 83 fb 01          	cmp    $0x1,%rbx
 115c0c4:	4d 89 fd             	mov    %r15,%r13
 115c0c7:	4c 0f 44 eb          	cmove  %rbx,%r13
 115c0cb:	49 01 c5             	add    %rax,%r13
 115c0ce:	ba 00 04 00 00       	mov    $0x400,%edx
 115c0d3:	48 8b bc 24 b8 00 00 	mov    0xb8(%rsp),%rdi
 115c0da:	00 
 115c0db:	48 8d b4 24 c0 03 00 	lea    0x3c0(%rsp),%rsi
 115c0e2:	00 
 115c0e3:	c5 f8 77             	vzeroupper 
 115c0e6:	e8 b5 22 04 00       	call   119e3a0 <compiler_rt.memcpy.memcpyFast>
 115c0eb:	48 89 9c 24 68 24 00 	mov    %rbx,0x2468(%rsp)
 115c0f2:	00 
 115c0f3:	4c 89 bc 24 70 24 00 	mov    %r15,0x2470(%rsp)
 115c0fa:	00 
 115c0fb:	4c 89 6c 24 40       	mov    %r13,0x40(%rsp)
 115c100:	4c 89 ac 24 78 24 00 	mov    %r13,0x2478(%rsp)
 115c107:	00 
 115c108:	48 8d 35 21 63 ea ff 	lea    -0x159cdf(%rip),%rsi        # 1002430 <__anon_1386>
 115c10f:	48 8d 3d 22 63 ea ff 	lea    -0x159cde(%rip),%rdi        # 1002438 <__anon_1386+0x8>
 115c116:	45 84 f6             	test   %r14b,%r14b
 115c119:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115c11e:	0f 84 f1 01 00 00    	je     115c315 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1975>
 115c124:	48 83 fb 02          	cmp    $0x2,%rbx
 115c128:	0f 82 8b 01 00 00    	jb     115c2b9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1919>
 115c12e:	49 83 ff 40          	cmp    $0x40,%r15
 115c132:	0f 82 81 01 00 00    	jb     115c2b9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1919>
 115c138:	80 bc 24 c0 22 00 00 	cmpb   $0x0,0x22c0(%rsp)
 115c13f:	00 
 115c140:	be 00 00 00 00       	mov    $0x0,%esi
 115c145:	48 c7 c7 ff ff ff ff 	mov    $0xffffffffffffffff,%rdi
 115c14c:	c4 41 29 ef d2       	vpxor  %xmm10,%xmm10,%xmm10
 115c151:	0f 84 82 01 00 00    	je     115c2d9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1939>
 115c157:	c5 e9 ef d2          	vpxor  %xmm2,%xmm2,%xmm2
 115c15b:	48 c7 c1 f8 ff ff ff 	mov    $0xfffffffffffffff8,%rcx
 115c162:	31 c0                	xor    %eax,%eax
 115c164:	c5 e1 ef db          	vpxor  %xmm3,%xmm3,%xmm3
 115c168:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 115c16c:	c5 f1 ef c9          	vpxor  %xmm1,%xmm1,%xmm1
 115c170:	c4 e2 7d 35 a4 8c b0 	vpmovzxdq 0x24b0(%rsp,%rcx,4),%ymm4
 115c177:	24 00 00 
 115c17a:	c5 e5 d4 dc          	vpaddq %ymm4,%ymm3,%ymm3
 115c17e:	c4 e2 7d 35 a4 8c a0 	vpmovzxdq 0x24a0(%rsp,%rcx,4),%ymm4
 115c185:	24 00 00 
 115c188:	c5 ed d4 d4          	vpaddq %ymm4,%ymm2,%ymm2
 115c18c:	c5 fe 6f a4 8c a0 24 	vmovdqu 0x24a0(%rsp,%rcx,4),%ymm4
 115c193:	00 00 
 115c195:	c5 fe 6f ac 8c c0 24 	vmovdqu 0x24c0(%rsp,%rcx,4),%ymm5
 115c19c:	00 00 
 115c19e:	c5 fe 6f b4 8c d8 1e 	vmovdqu 0x1ed8(%rsp,%rcx,4),%ymm6
 115c1a5:	00 00 
 115c1a7:	c5 fe 6f bc 8c f8 1e 	vmovdqu 0x1ef8(%rsp,%rcx,4),%ymm7
 115c1ae:	00 00 
 115c1b0:	c4 62 4d 3f c4       	vpmaxud %ymm4,%ymm6,%ymm8
 115c1b5:	c5 3d fa c4          	vpsubd %ymm4,%ymm8,%ymm8
 115c1b9:	c4 43 7d 39 c1 01    	vextracti128 $0x1,%ymm8,%xmm9
 115c1bf:	c4 42 7d 35 c9       	vpmovzxdq %xmm9,%ymm9
 115c1c4:	c5 b5 d4 c9          	vpaddq %ymm1,%ymm9,%ymm1
 115c1c8:	c4 42 7d 35 c0       	vpmovzxdq %xmm8,%ymm8
 115c1cd:	c5 bd d4 c0          	vpaddq %ymm0,%ymm8,%ymm0
 115c1d1:	c5 ad 76 e4          	vpcmpeqd %ymm4,%ymm10,%ymm4
 115c1d5:	c5 ad 76 f6          	vpcmpeqd %ymm6,%ymm10,%ymm6
 115c1d9:	c5 cd ef e4          	vpxor  %ymm4,%ymm6,%ymm4
 115c1dd:	c5 fc 50 d4          	vmovmskps %ymm4,%edx
 115c1e1:	08 c2                	or     %al,%dl
 115c1e3:	c4 e2 7d 35 a4 8c c0 	vpmovzxdq 0x24c0(%rsp,%rcx,4),%ymm4
 115c1ea:	24 00 00 
 115c1ed:	c5 ed d4 d4          	vpaddq %ymm4,%ymm2,%ymm2
 115c1f1:	c4 e2 7d 35 a4 8c d0 	vpmovzxdq 0x24d0(%rsp,%rcx,4),%ymm4
 115c1f8:	24 00 00 
 115c1fb:	c5 e5 d4 dc          	vpaddq %ymm4,%ymm3,%ymm3
 115c1ff:	c4 e2 45 3f e5       	vpmaxud %ymm5,%ymm7,%ymm4
 115c204:	c5 dd fa e5          	vpsubd %ymm5,%ymm4,%ymm4
 115c208:	c4 e2 7d 35 f4       	vpmovzxdq %xmm4,%ymm6
 115c20d:	c5 fd d4 c6          	vpaddq %ymm6,%ymm0,%ymm0
 115c211:	c4 e3 7d 39 e4 01    	vextracti128 $0x1,%ymm4,%xmm4
 115c217:	c4 e2 7d 35 e4       	vpmovzxdq %xmm4,%ymm4
 115c21c:	c5 f5 d4 cc          	vpaddq %ymm4,%ymm1,%ymm1
 115c220:	c5 ad 76 e5          	vpcmpeqd %ymm5,%ymm10,%ymm4
 115c224:	c5 ad 76 ef          	vpcmpeqd %ymm7,%ymm10,%ymm5
 115c228:	c5 d5 ef e4          	vpxor  %ymm4,%ymm5,%ymm4
 115c22c:	c5 fc 50 c4          	vmovmskps %ymm4,%eax
 115c230:	08 d0                	or     %dl,%al
 115c232:	48 83 c1 10          	add    $0x10,%rcx
 115c236:	48 81 f9 f8 00 00 00 	cmp    $0xf8,%rcx
 115c23d:	0f 82 2d ff ff ff    	jb     115c170 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x17d0>
 115c243:	c5 ed d4 d3          	vpaddq %ymm3,%ymm2,%ymm2
 115c247:	c4 e3 7d 39 d3 01    	vextracti128 $0x1,%ymm2,%xmm3
 115c24d:	c5 e9 d4 d3          	vpaddq %xmm3,%xmm2,%xmm2
 115c251:	c5 f9 70 da ee       	vpshufd $0xee,%xmm2,%xmm3
 115c256:	c5 e9 d4 d3          	vpaddq %xmm3,%xmm2,%xmm2
 115c25a:	c4 e1 f9 7e d2       	vmovq  %xmm2,%rdx
 115c25f:	48 81 fa 00 00 02 00 	cmp    $0x20000,%rdx
 115c266:	77 33                	ja     115c29b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x18fb>
 115c268:	c5 fd d4 c1          	vpaddq %ymm1,%ymm0,%ymm0
 115c26c:	c4 e3 7d 39 c1 01    	vextracti128 $0x1,%ymm0,%xmm1
 115c272:	c5 f9 d4 c1          	vpaddq %xmm1,%xmm0,%xmm0
 115c276:	c5 f9 70 c8 ee       	vpshufd $0xee,%xmm0,%xmm1
 115c27b:	c5 f9 d4 c1          	vpaddq %xmm1,%xmm0,%xmm0
 115c27f:	c4 e1 f9 7e c1       	vmovq  %xmm0,%rcx
 115c284:	84 c0                	test   %al,%al
 115c286:	0f 94 84 24 80 28 00 	sete   0x2880(%rsp)
 115c28d:	00 
 115c28e:	48 89 c8             	mov    %rcx,%rax
 115c291:	48 c1 e8 20          	shr    $0x20,%rax
 115c295:	0f 84 6a 0a 00 00    	je     115cd05 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2365>
 115c29b:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115c2a0:	48 8b 84 24 f8 22 00 	mov    0x22f8(%rsp),%rax
 115c2a7:	00 
 115c2a8:	48 ff c0             	inc    %rax
 115c2ab:	48 0f 44 c7          	cmove  %rdi,%rax
 115c2af:	48 89 84 24 f8 22 00 	mov    %rax,0x22f8(%rsp)
 115c2b6:	00 
 115c2b7:	eb 3c                	jmp    115c2f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1955>
 115c2b9:	48 8b 84 24 e0 22 00 	mov    0x22e0(%rsp),%rax
 115c2c0:	00 
 115c2c1:	48 ff c0             	inc    %rax
 115c2c4:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 115c2cb:	48 0f 44 c1          	cmove  %rcx,%rax
 115c2cf:	48 89 84 24 e0 22 00 	mov    %rax,0x22e0(%rsp)
 115c2d6:	00 
 115c2d7:	eb 1c                	jmp    115c2f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1955>
 115c2d9:	48 8b 84 24 d8 22 00 	mov    0x22d8(%rsp),%rax
 115c2e0:	00 
 115c2e1:	48 ff c0             	inc    %rax
 115c2e4:	48 0f 44 c7          	cmove  %rdi,%rax
 115c2e8:	48 89 84 24 d8 22 00 	mov    %rax,0x22d8(%rsp)
 115c2ef:	00 
 115c2f0:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115c2f5:	48 c7 84 24 b0 00 00 	movq   $0x0,0xb0(%rsp)
 115c2fc:	00 00 00 00 00 
 115c301:	c6 04 24 00          	movb   $0x0,(%rsp)
 115c305:	48 8d b4 24 b0 00 00 	lea    0xb0(%rsp),%rsi
 115c30c:	00 
 115c30d:	48 89 e7             	mov    %rsp,%rdi
 115c310:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 115c315:	48 8b 84 24 50 1d 00 	mov    0x1d50(%rsp),%rax
 115c31c:	00 
 115c31d:	48 ff c0             	inc    %rax
 115c320:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 115c327:	48 0f 44 c1          	cmove  %rcx,%rax
 115c32b:	48 89 84 24 50 1d 00 	mov    %rax,0x1d50(%rsp)
 115c332:	00 
 115c333:	48 83 fb 02          	cmp    $0x2,%rbx
 115c337:	48 89 7c 24 08       	mov    %rdi,0x8(%rsp)
 115c33c:	48 89 74 24 50       	mov    %rsi,0x50(%rsp)
 115c341:	0f 82 ca 01 00 00    	jb     115c511 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1b71>
 115c347:	49 83 ff 40          	cmp    $0x40,%r15
 115c34b:	0f 82 c0 01 00 00    	jb     115c511 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1b71>
 115c351:	48 8b 84 24 58 1d 00 	mov    0x1d58(%rsp),%rax
 115c358:	00 
 115c359:	48 ff c0             	inc    %rax
 115c35c:	48 0f 44 c1          	cmove  %rcx,%rax
 115c360:	48 89 84 24 58 1d 00 	mov    %rax,0x1d58(%rsp)
 115c367:	00 
 115c368:	ba 00 04 00 00       	mov    $0x400,%edx
 115c36d:	48 8b bc 24 28 01 00 	mov    0x128(%rsp),%rdi
 115c374:	00 
 115c375:	48 8b b4 24 b8 00 00 	mov    0xb8(%rsp),%rsi
 115c37c:	00 
 115c37d:	c5 f8 77             	vzeroupper 
 115c380:	e8 1b 20 04 00       	call   119e3a0 <compiler_rt.memcpy.memcpyFast>
 115c385:	48 8b 84 24 20 01 00 	mov    0x120(%rsp),%rax
 115c38c:	00 
 115c38d:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 115c391:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 115c395:	c5 fe 7f 40 20       	vmovdqu %ymm0,0x20(%rax)
 115c39a:	c5 fe 7f 40 40       	vmovdqu %ymm0,0x40(%rax)
 115c39f:	c5 fe 7f 40 60       	vmovdqu %ymm0,0x60(%rax)
 115c3a4:	c5 fe 7f 80 80 00 00 	vmovdqu %ymm0,0x80(%rax)
 115c3ab:	00 
 115c3ac:	c5 fe 7f 80 a0 00 00 	vmovdqu %ymm0,0xa0(%rax)
 115c3b3:	00 
 115c3b4:	c5 fe 7f 80 c0 00 00 	vmovdqu %ymm0,0xc0(%rax)
 115c3bb:	00 
 115c3bc:	c5 fe 7f 80 e0 00 00 	vmovdqu %ymm0,0xe0(%rax)
 115c3c3:	00 
 115c3c4:	c5 fe 7f 80 00 01 00 	vmovdqu %ymm0,0x100(%rax)
 115c3cb:	00 
 115c3cc:	c5 fe 7f 80 20 01 00 	vmovdqu %ymm0,0x120(%rax)
 115c3d3:	00 
 115c3d4:	c5 fe 7f 80 40 01 00 	vmovdqu %ymm0,0x140(%rax)
 115c3db:	00 
 115c3dc:	c5 fe 7f 80 60 01 00 	vmovdqu %ymm0,0x160(%rax)
 115c3e3:	00 
 115c3e4:	c5 fe 7f 80 80 01 00 	vmovdqu %ymm0,0x180(%rax)
 115c3eb:	00 
 115c3ec:	c5 fe 7f 80 a0 01 00 	vmovdqu %ymm0,0x1a0(%rax)
 115c3f3:	00 
 115c3f4:	c5 fe 7f 80 c0 01 00 	vmovdqu %ymm0,0x1c0(%rax)
 115c3fb:	00 
 115c3fc:	c5 fe 7f 80 e0 01 00 	vmovdqu %ymm0,0x1e0(%rax)
 115c403:	00 
 115c404:	48 c7 84 24 c0 03 00 	movq   $0x0,0x3c0(%rsp)
 115c40b:	00 00 00 00 00 
 115c410:	48 8b 84 24 18 01 00 	mov    0x118(%rsp),%rax
 115c417:	00 
 115c418:	c5 fe 7f 80 e0 00 00 	vmovdqu %ymm0,0xe0(%rax)
 115c41f:	00 
 115c420:	c5 fe 7f 80 c0 00 00 	vmovdqu %ymm0,0xc0(%rax)
 115c427:	00 
 115c428:	c5 fe 7f 80 a0 00 00 	vmovdqu %ymm0,0xa0(%rax)
 115c42f:	00 
 115c430:	c5 fe 7f 80 80 00 00 	vmovdqu %ymm0,0x80(%rax)
 115c437:	00 
 115c438:	c5 fe 7f 40 60       	vmovdqu %ymm0,0x60(%rax)
 115c43d:	c5 fe 7f 40 40       	vmovdqu %ymm0,0x40(%rax)
 115c442:	c5 fe 7f 40 20       	vmovdqu %ymm0,0x20(%rax)
 115c447:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 115c44b:	66 c7 80 00 01 00 00 	movw   $0x0,0x100(%rax)
 115c452:	00 00 
 115c454:	31 c9                	xor    %ecx,%ecx
 115c456:	31 c0                	xor    %eax,%eax
 115c458:	4c 8b 6c 24 40       	mov    0x40(%rsp),%r13
 115c45d:	eb 10                	jmp    115c46f <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1acf>
 115c45f:	48 83 c0 04          	add    $0x4,%rax
 115c463:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 115c469:	0f 84 c0 00 00 00    	je     115c52f <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1b8f>
 115c46f:	83 bc 84 80 24 00 00 	cmpl   $0x0,0x2480(%rsp,%rax,4)
 115c476:	00 
 115c477:	74 1a                	je     115c493 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1af3>
 115c479:	88 84 0c c8 09 00 00 	mov    %al,0x9c8(%rsp,%rcx,1)
 115c480:	48 8b 8c 24 c0 03 00 	mov    0x3c0(%rsp),%rcx
 115c487:	00 
 115c488:	48 ff c1             	inc    %rcx
 115c48b:	48 89 8c 24 c0 03 00 	mov    %rcx,0x3c0(%rsp)
 115c492:	00 
 115c493:	83 bc 84 84 24 00 00 	cmpl   $0x0,0x2484(%rsp,%rax,4)
 115c49a:	00 
 115c49b:	74 1d                	je     115c4ba <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1b1a>
 115c49d:	8d 50 01             	lea    0x1(%rax),%edx
 115c4a0:	88 94 0c c8 09 00 00 	mov    %dl,0x9c8(%rsp,%rcx,1)
 115c4a7:	48 8b 8c 24 c0 03 00 	mov    0x3c0(%rsp),%rcx
 115c4ae:	00 
 115c4af:	48 ff c1             	inc    %rcx
 115c4b2:	48 89 8c 24 c0 03 00 	mov    %rcx,0x3c0(%rsp)
 115c4b9:	00 
 115c4ba:	83 bc 84 88 24 00 00 	cmpl   $0x0,0x2488(%rsp,%rax,4)
 115c4c1:	00 
 115c4c2:	74 1d                	je     115c4e1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1b41>
 115c4c4:	8d 50 02             	lea    0x2(%rax),%edx
 115c4c7:	88 94 0c c8 09 00 00 	mov    %dl,0x9c8(%rsp,%rcx,1)
 115c4ce:	48 8b 8c 24 c0 03 00 	mov    0x3c0(%rsp),%rcx
 115c4d5:	00 
 115c4d6:	48 ff c1             	inc    %rcx
 115c4d9:	48 89 8c 24 c0 03 00 	mov    %rcx,0x3c0(%rsp)
 115c4e0:	00 
 115c4e1:	83 bc 84 8c 24 00 00 	cmpl   $0x0,0x248c(%rsp,%rax,4)
 115c4e8:	00 
 115c4e9:	0f 84 70 ff ff ff    	je     115c45f <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1abf>
 115c4ef:	8d 50 03             	lea    0x3(%rax),%edx
 115c4f2:	88 94 0c c8 09 00 00 	mov    %dl,0x9c8(%rsp,%rcx,1)
 115c4f9:	48 8b 8c 24 c0 03 00 	mov    0x3c0(%rsp),%rcx
 115c500:	00 
 115c501:	48 ff c1             	inc    %rcx
 115c504:	48 89 8c 24 c0 03 00 	mov    %rcx,0x3c0(%rsp)
 115c50b:	00 
 115c50c:	e9 4e ff ff ff       	jmp    115c45f <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1abf>
 115c511:	41 b7 01             	mov    $0x1,%r15b
 115c514:	48 c7 44 24 60 00 00 	movq   $0x0,0x60(%rsp)
 115c51b:	00 00 
 115c51d:	48 8d bc 24 c0 03 00 	lea    0x3c0(%rsp),%rdi
 115c524:	00 
 115c525:	4c 8b 6c 24 40       	mov    0x40(%rsp),%r13
 115c52a:	e9 7e 04 00 00       	jmp    115c9ad <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x200d>
 115c52f:	48 8d 9c 24 c0 03 00 	lea    0x3c0(%rsp),%rbx
 115c536:	00 
 115c537:	48 89 df             	mov    %rbx,%rdi
 115c53a:	c5 f8 77             	vzeroupper 
 115c53d:	e8 5e e5 fb ff       	call   111aaa0 <zstd.finalizeSmallHuffmanLiteralPlan>
 115c542:	41 b7 01             	mov    $0x1,%r15b
 115c545:	84 c0                	test   %al,%al
 115c547:	0f 84 4f 04 00 00    	je     115c99c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ffc>
 115c54d:	ba 10 09 00 00       	mov    $0x910,%edx
 115c552:	4c 8d b4 24 90 31 00 	lea    0x3190(%rsp),%r14
 115c559:	00 
 115c55a:	4c 89 f7             	mov    %r14,%rdi
 115c55d:	48 89 de             	mov    %rbx,%rsi
 115c560:	e8 3b 1e 04 00       	call   119e3a0 <compiler_rt.memcpy.memcpyFast>
 115c565:	ba 10 09 00 00       	mov    $0x910,%edx
 115c56a:	48 8d bc 24 80 28 00 	lea    0x2880(%rsp),%rdi
 115c571:	00 
 115c572:	4c 89 f6             	mov    %r14,%rsi
 115c575:	e8 26 1e 04 00       	call   119e3a0 <compiler_rt.memcpy.memcpyFast>
 115c57a:	0f b6 9c 24 88 31 00 	movzbl 0x3188(%rsp),%ebx
 115c581:	00 
 115c582:	44 0f b6 b4 24 89 31 	movzbl 0x3189(%rsp),%r14d
 115c589:	00 00 
 115c58b:	41 80 e6 0f          	and    $0xf,%r14b
 115c58f:	c5 fe 6f 8c 24 88 30 	vmovdqu 0x3088(%rsp),%ymm1
 115c596:	00 00 
 115c598:	c5 fe 6f 94 24 a8 30 	vmovdqu 0x30a8(%rsp),%ymm2
 115c59f:	00 00 
 115c5a1:	c5 fe 6f 9c 24 c8 30 	vmovdqu 0x30c8(%rsp),%ymm3
 115c5a8:	00 00 
 115c5aa:	c5 fc 10 84 24 e8 30 	vmovups 0x30e8(%rsp),%ymm0
 115c5b1:	00 00 
 115c5b3:	c5 fc 29 44 24 60    	vmovaps %ymm0,0x60(%rsp)
 115c5b9:	c5 fc 10 84 24 08 31 	vmovups 0x3108(%rsp),%ymm0
 115c5c0:	00 00 
 115c5c2:	c5 fc 29 84 24 c0 01 	vmovaps %ymm0,0x1c0(%rsp)
 115c5c9:	00 00 
 115c5cb:	c5 fc 10 84 24 28 31 	vmovups 0x3128(%rsp),%ymm0
 115c5d2:	00 00 
 115c5d4:	c5 fc 29 84 24 40 01 	vmovaps %ymm0,0x140(%rsp)
 115c5db:	00 00 
 115c5dd:	c5 fc 10 84 24 48 31 	vmovups 0x3148(%rsp),%ymm0
 115c5e4:	00 00 
 115c5e6:	c5 fc 29 84 24 80 01 	vmovaps %ymm0,0x180(%rsp)
 115c5ed:	00 00 
 115c5ef:	c5 fe 6f 84 24 68 31 	vmovdqu 0x3168(%rsp),%ymm0
 115c5f6:	00 00 
 115c5f8:	c5 fd 7f 84 24 a0 01 	vmovdqa %ymm0,0x1a0(%rsp)
 115c5ff:	00 00 
 115c601:	80 bc 24 a0 1e 00 00 	cmpb   $0x0,0x1ea0(%rsp)
 115c608:	00 
 115c609:	0f 84 d1 00 00 00    	je     115c6e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1d40>
 115c60f:	38 9c 24 98 1d 00 00 	cmp    %bl,0x1d98(%rsp)
 115c616:	0f 85 c4 00 00 00    	jne    115c6e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1d40>
 115c61c:	44 38 b4 24 99 1d 00 	cmp    %r14b,0x1d99(%rsp)
 115c623:	00 
 115c624:	0f 85 b6 00 00 00    	jne    115c6e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1d40>
 115c62a:	c5 f5 ef 84 24 9a 1d 	vpxor  0x1d9a(%rsp),%ymm1,%ymm0
 115c631:	00 00 
 115c633:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c638:	0f 85 a2 00 00 00    	jne    115c6e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1d40>
 115c63e:	c5 ed ef 84 24 ba 1d 	vpxor  0x1dba(%rsp),%ymm2,%ymm0
 115c645:	00 00 
 115c647:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c64c:	0f 85 8e 00 00 00    	jne    115c6e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1d40>
 115c652:	c5 e5 ef 84 24 da 1d 	vpxor  0x1dda(%rsp),%ymm3,%ymm0
 115c659:	00 00 
 115c65b:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c660:	75 7e                	jne    115c6e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1d40>
 115c662:	c5 fd 6f 44 24 60    	vmovdqa 0x60(%rsp),%ymm0
 115c668:	c5 fd ef 84 24 fa 1d 	vpxor  0x1dfa(%rsp),%ymm0,%ymm0
 115c66f:	00 00 
 115c671:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c676:	75 68                	jne    115c6e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1d40>
 115c678:	c5 fd 6f 84 24 c0 01 	vmovdqa 0x1c0(%rsp),%ymm0
 115c67f:	00 00 
 115c681:	c5 fd ef 84 24 1a 1e 	vpxor  0x1e1a(%rsp),%ymm0,%ymm0
 115c688:	00 00 
 115c68a:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c68f:	75 4f                	jne    115c6e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1d40>
 115c691:	c5 fd 6f 84 24 40 01 	vmovdqa 0x140(%rsp),%ymm0
 115c698:	00 00 
 115c69a:	c5 fd ef 84 24 3a 1e 	vpxor  0x1e3a(%rsp),%ymm0,%ymm0
 115c6a1:	00 00 
 115c6a3:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c6a8:	75 36                	jne    115c6e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1d40>
 115c6aa:	c5 fd 6f 84 24 80 01 	vmovdqa 0x180(%rsp),%ymm0
 115c6b1:	00 00 
 115c6b3:	c5 fd ef 84 24 5a 1e 	vpxor  0x1e5a(%rsp),%ymm0,%ymm0
 115c6ba:	00 00 
 115c6bc:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c6c1:	75 1d                	jne    115c6e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1d40>
 115c6c3:	c5 fd 6f 84 24 a0 01 	vmovdqa 0x1a0(%rsp),%ymm0
 115c6ca:	00 00 
 115c6cc:	c5 fd ef 84 24 7a 1e 	vpxor  0x1e7a(%rsp),%ymm0,%ymm0
 115c6d3:	00 00 
 115c6d5:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c6da:	0f 84 67 0a 00 00    	je     115d147 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x27a7>
 115c6e0:	c5 fd 7f 9c 24 e0 02 	vmovdqa %ymm3,0x2e0(%rsp)
 115c6e7:	00 00 
 115c6e9:	c5 fd 7f 94 24 00 03 	vmovdqa %ymm2,0x300(%rsp)
 115c6f0:	00 00 
 115c6f2:	c5 fd 7f 8c 24 20 03 	vmovdqa %ymm1,0x320(%rsp)
 115c6f9:	00 00 
 115c6fb:	48 8b 84 24 60 1d 00 	mov    0x1d60(%rsp),%rax
 115c702:	00 
 115c703:	48 ff c0             	inc    %rax
 115c706:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 115c70d:	48 0f 44 c1          	cmove  %rcx,%rax
 115c711:	48 89 84 24 60 1d 00 	mov    %rax,0x1d60(%rsp)
 115c718:	00 
 115c719:	4c 8d ac 24 c0 03 00 	lea    0x3c0(%rsp),%r13
 115c720:	00 
 115c721:	4c 89 ef             	mov    %r13,%rdi
 115c724:	48 8d b4 24 90 31 00 	lea    0x3190(%rsp),%rsi
 115c72b:	00 
 115c72c:	c5 f8 77             	vzeroupper 
 115c72f:	e8 2c 7a ff ff       	call   1154160 <zstd.smallHuffmanTreeSerializedLen>
 115c734:	66 83 bc 24 d0 03 00 	cmpw   $0x0,0x3d0(%rsp)
 115c73b:	00 00 
 115c73d:	0f 85 9f 05 00 00    	jne    115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c743:	c6 84 24 a0 1e 00 00 	movb   $0x1,0x1ea0(%rsp)
 115c74a:	01 
 115c74b:	88 9c 24 98 1d 00 00 	mov    %bl,0x1d98(%rsp)
 115c752:	44 88 b4 24 99 1d 00 	mov    %r14b,0x1d99(%rsp)
 115c759:	00 
 115c75a:	c5 fc 28 84 24 20 03 	vmovaps 0x320(%rsp),%ymm0
 115c761:	00 00 
 115c763:	c5 fc 11 84 24 9a 1d 	vmovups %ymm0,0x1d9a(%rsp)
 115c76a:	00 00 
 115c76c:	c5 fc 28 84 24 00 03 	vmovaps 0x300(%rsp),%ymm0
 115c773:	00 00 
 115c775:	c5 fc 11 84 24 ba 1d 	vmovups %ymm0,0x1dba(%rsp)
 115c77c:	00 00 
 115c77e:	c5 fc 28 84 24 e0 02 	vmovaps 0x2e0(%rsp),%ymm0
 115c785:	00 00 
 115c787:	c5 fc 11 84 24 da 1d 	vmovups %ymm0,0x1dda(%rsp)
 115c78e:	00 00 
 115c790:	c5 fc 28 44 24 60    	vmovaps 0x60(%rsp),%ymm0
 115c796:	c5 fc 11 84 24 fa 1d 	vmovups %ymm0,0x1dfa(%rsp)
 115c79d:	00 00 
 115c79f:	c5 fc 28 84 24 c0 01 	vmovaps 0x1c0(%rsp),%ymm0
 115c7a6:	00 00 
 115c7a8:	c5 fc 11 84 24 1a 1e 	vmovups %ymm0,0x1e1a(%rsp)
 115c7af:	00 00 
 115c7b1:	c5 fc 28 84 24 40 01 	vmovaps 0x140(%rsp),%ymm0
 115c7b8:	00 00 
 115c7ba:	c5 fc 11 84 24 3a 1e 	vmovups %ymm0,0x1e3a(%rsp)
 115c7c1:	00 00 
 115c7c3:	c5 fc 28 84 24 80 01 	vmovaps 0x180(%rsp),%ymm0
 115c7ca:	00 00 
 115c7cc:	c5 fc 11 84 24 5a 1e 	vmovups %ymm0,0x1e5a(%rsp)
 115c7d3:	00 00 
 115c7d5:	c5 fc 28 84 24 a0 01 	vmovaps 0x1a0(%rsp),%ymm0
 115c7dc:	00 00 
 115c7de:	c5 fc 11 84 24 7a 1e 	vmovups %ymm0,0x1e7a(%rsp)
 115c7e5:	00 00 
 115c7e7:	c5 fa 6f 84 24 c0 03 	vmovdqu 0x3c0(%rsp),%xmm0
 115c7ee:	00 00 
 115c7f0:	48 8b 84 24 d0 00 00 	mov    0xd0(%rsp),%rax
 115c7f7:	00 
 115c7f8:	c5 fa 7f 00          	vmovdqu %xmm0,(%rax)
 115c7fc:	48 8b 8c 24 10 01 00 	mov    0x110(%rsp),%rcx
 115c803:	00 
 115c804:	4c 89 e8             	mov    %r13,%rax
 115c807:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115c80c:	80 39 00             	cmpb   $0x0,(%rcx)
 115c80f:	4c 8b 6c 24 38       	mov    0x38(%rsp),%r13
 115c814:	0f 84 fa fc ff ff    	je     115c514 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1b74>
 115c81a:	48 8b 00             	mov    (%rax),%rax
 115c81d:	48 8b 94 24 e8 0c 00 	mov    0xce8(%rsp),%rdx
 115c824:	00 
 115c825:	48 83 fa 01          	cmp    $0x1,%rdx
 115c829:	b9 06 00 00 00       	mov    $0x6,%ecx
 115c82e:	be 00 00 00 00       	mov    $0x0,%esi
 115c833:	48 0f 44 ce          	cmove  %rsi,%rcx
 115c837:	48 85 d2             	test   %rdx,%rdx
 115c83a:	0f 84 48 04 00 00    	je     115cc88 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x22e8>
 115c840:	48 8b b4 24 70 1d 00 	mov    0x1d70(%rsp),%rsi
 115c847:	00 
 115c848:	48 8d bc 24 04 0d 00 	lea    0xd04(%rsp),%rdi
 115c84f:	00 
 115c850:	45 31 c9             	xor    %r9d,%r9d
 115c853:	45 31 c0             	xor    %r8d,%r8d
 115c856:	4c 89 4c 24 60       	mov    %r9,0x60(%rsp)
 115c85b:	45 31 d2             	xor    %r10d,%r10d
 115c85e:	45 31 c9             	xor    %r9d,%r9d
 115c861:	eb 11                	jmp    115c874 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ed4>
 115c863:	49 83 c2 02          	add    $0x2,%r10
 115c867:	49 81 fa 00 01 00 00 	cmp    $0x100,%r10
 115c86e:	0f 84 ba 00 00 00    	je     115c92e <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1f8e>
 115c874:	46 8b 5c 97 fc       	mov    -0x4(%rdi,%r10,4),%r11d
 115c879:	4d 85 db             	test   %r11,%r11
 115c87c:	74 51                	je     115c8cf <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1f2f>
 115c87e:	42 0f b6 9c 14 88 30 	movzbl 0x3088(%rsp,%r10,1),%ebx
 115c885:	00 00 
 115c887:	48 85 db             	test   %rbx,%rbx
 115c88a:	0f 84 52 04 00 00    	je     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c890:	48 ff c6             	inc    %rsi
 115c893:	49 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%r14
 115c89a:	49 0f 44 f6          	cmove  %r14,%rsi
 115c89e:	48 89 b4 24 70 1d 00 	mov    %rsi,0x1d70(%rsp)
 115c8a5:	00 
 115c8a6:	c6 84 24 c0 03 00 00 	movb   $0x0,0x3c0(%rsp)
 115c8ad:	00 
 115c8ae:	45 31 f6             	xor    %r14d,%r14d
 115c8b1:	45 84 f6             	test   %r14b,%r14b
 115c8b4:	0f 85 28 04 00 00    	jne    115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c8ba:	49 0f af db          	imul   %r11,%rbx
 115c8be:	49 01 d9             	add    %rbx,%r9
 115c8c1:	0f 92 84 24 c0 03 00 	setb   0x3c0(%rsp)
 115c8c8:	00 
 115c8c9:	0f 82 13 04 00 00    	jb     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c8cf:	46 8b 1c 97          	mov    (%rdi,%r10,4),%r11d
 115c8d3:	4d 85 db             	test   %r11,%r11
 115c8d6:	74 8b                	je     115c863 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ec3>
 115c8d8:	42 0f b6 9c 14 89 30 	movzbl 0x3089(%rsp,%r10,1),%ebx
 115c8df:	00 00 
 115c8e1:	48 85 db             	test   %rbx,%rbx
 115c8e4:	0f 84 f8 03 00 00    	je     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c8ea:	48 ff c6             	inc    %rsi
 115c8ed:	49 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%r14
 115c8f4:	49 0f 44 f6          	cmove  %r14,%rsi
 115c8f8:	48 89 b4 24 70 1d 00 	mov    %rsi,0x1d70(%rsp)
 115c8ff:	00 
 115c900:	c6 84 24 c0 03 00 00 	movb   $0x0,0x3c0(%rsp)
 115c907:	00 
 115c908:	45 31 f6             	xor    %r14d,%r14d
 115c90b:	45 84 f6             	test   %r14b,%r14b
 115c90e:	0f 85 ce 03 00 00    	jne    115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c914:	49 0f af db          	imul   %r11,%rbx
 115c918:	49 01 d9             	add    %rbx,%r9
 115c91b:	0f 92 84 24 c0 03 00 	setb   0x3c0(%rsp)
 115c922:	00 
 115c923:	0f 83 3a ff ff ff    	jae    115c863 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ec3>
 115c929:	e9 b4 03 00 00       	jmp    115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c92e:	4d 89 ca             	mov    %r9,%r10
 115c931:	49 83 c2 08          	add    $0x8,%r10
 115c935:	0f 92 84 24 c0 03 00 	setb   0x3c0(%rsp)
 115c93c:	00 
 115c93d:	0f 82 9f 03 00 00    	jb     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c943:	4c 8b 5c 24 60       	mov    0x60(%rsp),%r11
 115c948:	4d 01 cb             	add    %r9,%r11
 115c94b:	0f 92 84 24 c0 03 00 	setb   0x3c0(%rsp)
 115c952:	00 
 115c953:	0f 82 89 03 00 00    	jb     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c959:	4d 89 d9             	mov    %r11,%r9
 115c95c:	48 83 fa 01          	cmp    $0x1,%rdx
 115c960:	74 0d                	je     115c96f <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1fcf>
 115c962:	49 81 fa ff ff 07 00 	cmp    $0x7ffff,%r10
 115c969:	0f 87 02 05 00 00    	ja     115ce71 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x24d1>
 115c96f:	49 c1 ea 03          	shr    $0x3,%r10
 115c973:	4c 01 d1             	add    %r10,%rcx
 115c976:	0f 92 84 24 c0 03 00 	setb   0x3c0(%rsp)
 115c97d:	00 
 115c97e:	0f 82 5e 03 00 00    	jb     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115c984:	49 ff c0             	inc    %r8
 115c987:	48 81 c7 00 04 00 00 	add    $0x400,%rdi
 115c98e:	49 39 d0             	cmp    %rdx,%r8
 115c991:	0f 85 bf fe ff ff    	jne    115c856 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1eb6>
 115c997:	e9 ef 02 00 00       	jmp    115cc8b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x22eb>
 115c99c:	48 c7 44 24 60 00 00 	movq   $0x0,0x60(%rsp)
 115c9a3:	00 00 
 115c9a5:	48 89 df             	mov    %rbx,%rdi
 115c9a8:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115c9ad:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 115c9b4:	00 
 115c9b5:	48 89 84 24 30 02 00 	mov    %rax,0x230(%rsp)
 115c9bc:	00 
 115c9bd:	4c 89 a4 24 90 31 00 	mov    %r12,0x3190(%rsp)
 115c9c4:	00 
 115c9c5:	48 89 94 24 80 28 00 	mov    %rdx,0x2880(%rsp)
 115c9cc:	00 
 115c9cd:	ba 01 00 00 00       	mov    $0x1,%edx
 115c9d2:	41 b8 01 00 00 00    	mov    $0x1,%r8d
 115c9d8:	48 8d b4 24 30 02 00 	lea    0x230(%rsp),%rsi
 115c9df:	00 
 115c9e0:	48 8d 8c 24 90 31 00 	lea    0x3190(%rsp),%rcx
 115c9e7:	00 
 115c9e8:	4c 8d 8c 24 80 28 00 	lea    0x2880(%rsp),%r9
 115c9ef:	00 
 115c9f0:	41 55                	push   %r13
 115c9f2:	6a 01                	push   $0x1
 115c9f4:	c5 f8 77             	vzeroupper 
 115c9f7:	e8 24 8c ff ff       	call   1155620 <zstd.rleSequencePayloadLenForValuesWithLiteralsLen>
 115c9fc:	48 83 c4 10          	add    $0x10,%rsp
 115ca00:	44 0f b7 b4 24 c8 03 	movzwl 0x3c8(%rsp),%r14d
 115ca07:	00 00 
 115ca09:	66 45 85 f6          	test   %r14w,%r14w
 115ca0d:	0f 85 32 05 00 00    	jne    115cf45 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x25a5>
 115ca13:	48 8b 9c 24 c0 03 00 	mov    0x3c0(%rsp),%rbx
 115ca1a:	00 
 115ca1b:	48 8b 44 24 10       	mov    0x10(%rsp),%rax
 115ca20:	48 8b 8c 24 d8 00 00 	mov    0xd8(%rsp),%rcx
 115ca27:	00 
 115ca28:	48 89 8c 24 30 02 00 	mov    %rcx,0x230(%rsp)
 115ca2f:	00 
 115ca30:	4c 89 a4 24 90 31 00 	mov    %r12,0x3190(%rsp)
 115ca37:	00 
 115ca38:	48 89 84 24 80 28 00 	mov    %rax,0x2880(%rsp)
 115ca3f:	00 
 115ca40:	ba 01 00 00 00       	mov    $0x1,%edx
 115ca45:	41 b8 01 00 00 00    	mov    $0x1,%r8d
 115ca4b:	48 8d bc 24 c0 03 00 	lea    0x3c0(%rsp),%rdi
 115ca52:	00 
 115ca53:	48 8d b4 24 30 02 00 	lea    0x230(%rsp),%rsi
 115ca5a:	00 
 115ca5b:	48 8d 8c 24 90 31 00 	lea    0x3190(%rsp),%rcx
 115ca62:	00 
 115ca63:	4c 8d 8c 24 80 28 00 	lea    0x2880(%rsp),%r9
 115ca6a:	00 
 115ca6b:	41 55                	push   %r13
 115ca6d:	6a 01                	push   $0x1
 115ca6f:	e8 ac 86 ff ff       	call   1155120 <zstd.predefinedSequencePayloadLenWithLiteralsLen>
 115ca74:	48 83 c4 10          	add    $0x10,%rsp
 115ca78:	0f b7 84 24 c8 03 00 	movzwl 0x3c8(%rsp),%eax
 115ca7f:	00 
 115ca80:	85 c0                	test   %eax,%eax
 115ca82:	0f 85 f0 04 00 00    	jne    115cf78 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x25d8>
 115ca88:	48 8b 84 24 c0 03 00 	mov    0x3c0(%rsp),%rax
 115ca8f:	00 
 115ca90:	48 39 d8             	cmp    %rbx,%rax
 115ca93:	48 0f 42 d8          	cmovb  %rax,%rbx
 115ca97:	66 45 85 f6          	test   %r14w,%r14w
 115ca9b:	48 0f 45 d8          	cmovne %rax,%rbx
 115ca9f:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115caa4:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115caa9:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115cab0:	79 37 9e 
 115cab3:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115cab8:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115cabd:	48 8b 74 24 10       	mov    0x10(%rsp),%rsi
 115cac2:	48 8b 44 24 08       	mov    0x8(%rsp),%rax
 115cac7:	80 38 00             	cmpb   $0x0,(%rax)
 115caca:	4c 8b 9c 24 30 01 00 	mov    0x130(%rsp),%r11
 115cad1:	00 
 115cad2:	74 28                	je     115cafc <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x215c>
 115cad4:	31 c0                	xor    %eax,%eax
 115cad6:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 115cadb:	48 39 1a             	cmp    %rbx,(%rdx)
 115cade:	0f 97 c0             	seta   %al
 115cae1:	48 03 84 24 10 23 00 	add    0x2310(%rsp),%rax
 115cae8:	00 
 115cae9:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 115caf0:	48 0f 42 c2          	cmovb  %rdx,%rax
 115caf4:	48 89 84 24 10 23 00 	mov    %rax,0x2310(%rsp)
 115cafb:	00 
 115cafc:	45 84 ff             	test   %r15b,%r15b
 115caff:	4c 8b ac 24 c8 00 00 	mov    0xc8(%rsp),%r13
 115cb06:	00 
 115cb07:	4c 8b a4 24 98 00 00 	mov    0x98(%rsp),%r12
 115cb0e:	00 
 115cb0f:	0f 85 19 01 00 00    	jne    115cc2e <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x228e>
 115cb15:	45 31 f6             	xor    %r14d,%r14d
 115cb18:	31 c0                	xor    %eax,%eax
 115cb1a:	31 f6                	xor    %esi,%esi
 115cb1c:	8b 94 b4 80 24 00 00 	mov    0x2480(%rsp,%rsi,4),%edx
 115cb23:	c6 84 24 c0 03 00 00 	movb   $0x0,0x3c0(%rsp)
 115cb2a:	00 
 115cb2b:	45 31 ff             	xor    %r15d,%r15d
 115cb2e:	45 84 ff             	test   %r15b,%r15b
 115cb31:	0f 85 d9 00 00 00    	jne    115cc10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2270>
 115cb37:	49 01 d6             	add    %rdx,%r14
 115cb3a:	49 81 fe 00 00 02 00 	cmp    $0x20000,%r14
 115cb41:	0f 87 c9 00 00 00    	ja     115cc10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2270>
 115cb47:	48 83 fa 01          	cmp    $0x1,%rdx
 115cb4b:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 115cb4f:	8b 94 b4 84 24 00 00 	mov    0x2484(%rsp,%rsi,4),%edx
 115cb56:	c6 84 24 c0 03 00 00 	movb   $0x0,0x3c0(%rsp)
 115cb5d:	00 
 115cb5e:	45 31 ff             	xor    %r15d,%r15d
 115cb61:	45 84 ff             	test   %r15b,%r15b
 115cb64:	0f 85 a6 00 00 00    	jne    115cc10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2270>
 115cb6a:	49 01 d6             	add    %rdx,%r14
 115cb6d:	49 81 fe 00 00 02 00 	cmp    $0x20000,%r14
 115cb74:	0f 87 96 00 00 00    	ja     115cc10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2270>
 115cb7a:	48 83 fa 01          	cmp    $0x1,%rdx
 115cb7e:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 115cb82:	8b 94 b4 88 24 00 00 	mov    0x2488(%rsp,%rsi,4),%edx
 115cb89:	c6 84 24 c0 03 00 00 	movb   $0x0,0x3c0(%rsp)
 115cb90:	00 
 115cb91:	45 31 ff             	xor    %r15d,%r15d
 115cb94:	45 84 ff             	test   %r15b,%r15b
 115cb97:	75 77                	jne    115cc10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2270>
 115cb99:	49 01 d6             	add    %rdx,%r14
 115cb9c:	49 81 fe 00 00 02 00 	cmp    $0x20000,%r14
 115cba3:	77 6b                	ja     115cc10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2270>
 115cba5:	48 83 fa 01          	cmp    $0x1,%rdx
 115cba9:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 115cbad:	8b 94 b4 8c 24 00 00 	mov    0x248c(%rsp,%rsi,4),%edx
 115cbb4:	c6 84 24 c0 03 00 00 	movb   $0x0,0x3c0(%rsp)
 115cbbb:	00 
 115cbbc:	45 31 ff             	xor    %r15d,%r15d
 115cbbf:	45 84 ff             	test   %r15b,%r15b
 115cbc2:	75 4c                	jne    115cc10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2270>
 115cbc4:	49 01 d6             	add    %rdx,%r14
 115cbc7:	49 81 fe 00 00 02 00 	cmp    $0x20000,%r14
 115cbce:	77 40                	ja     115cc10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2270>
 115cbd0:	48 83 fa 01          	cmp    $0x1,%rdx
 115cbd4:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 115cbd8:	48 83 c6 04          	add    $0x4,%rsi
 115cbdc:	48 81 fe 00 01 00 00 	cmp    $0x100,%rsi
 115cbe3:	0f 85 33 ff ff ff    	jne    115cb1c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x217c>
 115cbe9:	48 8d 90 ff f7 ff ff 	lea    -0x801(%rax),%rdx
 115cbf0:	48 8b 74 24 58       	mov    0x58(%rsp),%rsi
 115cbf5:	48 81 fa 01 f8 ff ff 	cmp    $0xfffffffffffff801,%rdx
 115cbfc:	72 17                	jb     115cc15 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2275>
 115cbfe:	c6 84 24 c0 03 00 00 	movb   $0x0,0x3c0(%rsp)
 115cc05:	00 
 115cc06:	31 d2                	xor    %edx,%edx
 115cc08:	84 d2                	test   %dl,%dl
 115cc0a:	0f 84 bb 01 00 00    	je     115cdcb <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x242b>
 115cc10:	48 8b 74 24 58       	mov    0x58(%rsp),%rsi
 115cc15:	48 8b 06             	mov    (%rsi),%rax
 115cc18:	48 ff c0             	inc    %rax
 115cc1b:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 115cc22:	48 0f 44 c2          	cmove  %rdx,%rax
 115cc26:	48 89 06             	mov    %rax,(%rsi)
 115cc29:	48 8b 74 24 10       	mov    0x10(%rsp),%rsi
 115cc2e:	48 3b 9c 24 a0 00 00 	cmp    0xa0(%rsp),%rbx
 115cc35:	00 
 115cc36:	44 8b 74 24 1c       	mov    0x1c(%rsp),%r14d
 115cc3b:	72 20                	jb     115cc5d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x22bd>
 115cc3d:	45 84 f6             	test   %r14b,%r14b
 115cc40:	0f 84 3b e1 ff ff    	je     115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115cc46:	48 3b 9c 24 a0 00 00 	cmp    0xa0(%rsp),%rbx
 115cc4d:	00 
 115cc4e:	0f 85 2d e1 ff ff    	jne    115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115cc54:	48 39 f1             	cmp    %rsi,%rcx
 115cc57:	0f 83 24 e1 ff ff    	jae    115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115cc5d:	41 b6 01             	mov    $0x1,%r14b
 115cc60:	48 89 9c 24 a0 00 00 	mov    %rbx,0xa0(%rsp)
 115cc67:	00 
 115cc68:	48 89 f1             	mov    %rsi,%rcx
 115cc6b:	48 89 9c 24 70 01 00 	mov    %rbx,0x170(%rsp)
 115cc72:	00 
 115cc73:	4c 89 9c 24 38 01 00 	mov    %r11,0x138(%rsp)
 115cc7a:	00 
 115cc7b:	4c 89 94 24 e8 00 00 	mov    %r10,0xe8(%rsp)
 115cc82:	00 
 115cc83:	e9 f9 e0 ff ff       	jmp    115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115cc88:	45 31 c9             	xor    %r9d,%r9d
 115cc8b:	48 01 c8             	add    %rcx,%rax
 115cc8e:	0f 92 84 24 c0 03 00 	setb   0x3c0(%rsp)
 115cc95:	00 
 115cc96:	72 4a                	jb     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115cc98:	4c 89 4c 24 60       	mov    %r9,0x60(%rsp)
 115cc9d:	74 43                	je     115cce2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2342>
 115cc9f:	49 09 c5             	or     %rax,%r13
 115cca2:	b9 03 00 00 00       	mov    $0x3,%ecx
 115cca7:	49 81 fd 00 04 00 00 	cmp    $0x400,%r13
 115ccae:	72 20                	jb     115ccd0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2330>
 115ccb0:	b9 04 00 00 00       	mov    $0x4,%ecx
 115ccb5:	49 81 fd 00 40 00 00 	cmp    $0x4000,%r13
 115ccbc:	72 12                	jb     115ccd0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2330>
 115ccbe:	b9 05 00 00 00       	mov    $0x5,%ecx
 115ccc3:	49 81 fd ff ff 03 00 	cmp    $0x3ffff,%r13
 115ccca:	0f 87 a1 01 00 00    	ja     115ce71 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x24d1>
 115ccd0:	c6 84 24 c0 03 00 00 	movb   $0x0,0x3c0(%rsp)
 115ccd7:	00 
 115ccd8:	31 d2                	xor    %edx,%edx
 115ccda:	84 d2                	test   %dl,%dl
 115ccdc:	0f 84 ca 00 00 00    	je     115cdac <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x240c>
 115cce2:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115cce7:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115ccec:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115ccf3:	79 37 9e 
 115ccf6:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115ccfb:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115cd00:	e9 e4 e6 ff ff       	jmp    115b3e9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa49>
 115cd05:	0f b6 84 24 80 28 00 	movzbl 0x2880(%rsp),%eax
 115cd0c:	00 
 115cd0d:	24 01                	and    $0x1,%al
 115cd0f:	88 84 24 90 31 00 00 	mov    %al,0x3190(%rsp)
 115cd16:	74 5e                	je     115cd76 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x23d6>
 115cd18:	48 8b 84 24 b0 1e 00 	mov    0x1eb0(%rsp),%rax
 115cd1f:	00 
 115cd20:	48 85 c0             	test   %rax,%rax
 115cd23:	0f 88 72 f5 ff ff    	js     115c29b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x18fb>
 115cd29:	40 84 f6             	test   %sil,%sil
 115cd2c:	0f 85 69 f5 ff ff    	jne    115c29b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x18fb>
 115cd32:	8b b4 24 b8 22 00 00 	mov    0x22b8(%rsp),%esi
 115cd39:	48 89 d7             	mov    %rdx,%rdi
 115cd3c:	48 29 f7             	sub    %rsi,%rdi
 115cd3f:	48 01 f8             	add    %rdi,%rax
 115cd42:	0f 90 84 24 80 28 00 	seto   0x2880(%rsp)
 115cd49:	00 
 115cd4a:	70 19                	jo     115cd65 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x23c5>
 115cd4c:	48 8d 34 09          	lea    (%rcx,%rcx,1),%rsi
 115cd50:	48 8d 34 b6          	lea    (%rsi,%rsi,4),%rsi
 115cd54:	48 29 f0             	sub    %rsi,%rax
 115cd57:	0f 90 84 24 80 28 00 	seto   0x2880(%rsp)
 115cd5e:	00 
 115cd5f:	0f 81 2c 01 00 00    	jno    115ce91 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x24f1>
 115cd65:	48 c7 c7 ff ff ff ff 	mov    $0xffffffffffffffff,%rdi
 115cd6c:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115cd71:	e9 25 f5 ff ff       	jmp    115c29b <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x18fb>
 115cd76:	f6 84 24 90 31 00 00 	testb  $0x1,0x3190(%rsp)
 115cd7d:	01 
 115cd7e:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115cd83:	0f 85 6c f5 ff ff    	jne    115c2f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1955>
 115cd89:	48 8b 84 24 e8 22 00 	mov    0x22e8(%rsp),%rax
 115cd90:	00 
 115cd91:	48 ff c0             	inc    %rax
 115cd94:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 115cd9b:	48 0f 44 c1          	cmove  %rcx,%rax
 115cd9f:	48 89 84 24 e8 22 00 	mov    %rax,0x22e8(%rsp)
 115cda6:	00 
 115cda7:	e9 49 f5 ff ff       	jmp    115c2f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1955>
 115cdac:	48 01 c1             	add    %rax,%rcx
 115cdaf:	4c 8b 6c 24 40       	mov    0x40(%rsp),%r13
 115cdb4:	4c 39 e9             	cmp    %r13,%rcx
 115cdb7:	4c 0f 42 e9          	cmovb  %rcx,%r13
 115cdbb:	45 31 ff             	xor    %r15d,%r15d
 115cdbe:	48 8d bc 24 c0 03 00 	lea    0x3c0(%rsp),%rdi
 115cdc5:	00 
 115cdc6:	e9 dd fb ff ff       	jmp    115c9a8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2008>
 115cdcb:	48 8b 74 24 58       	mov    0x58(%rsp),%rsi
 115cdd0:	4c 39 74 24 60       	cmp    %r14,0x60(%rsp)
 115cdd5:	0f 82 3a fe ff ff    	jb     115cc15 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2275>
 115cddb:	4b 8d 14 b6          	lea    (%r14,%r14,4),%rdx
 115cddf:	49 8d 14 56          	lea    (%r14,%rdx,2),%rdx
 115cde3:	48 8b 74 24 58       	mov    0x58(%rsp),%rsi
 115cde8:	48 39 54 24 60       	cmp    %rdx,0x60(%rsp)
 115cded:	0f 87 22 fe ff ff    	ja     115cc15 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2275>
 115cdf3:	48 89 84 24 a8 1e 00 	mov    %rax,0x1ea8(%rsp)
 115cdfa:	00 
 115cdfb:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 115ce00:	48 89 84 24 b0 1e 00 	mov    %rax,0x1eb0(%rsp)
 115ce07:	00 
 115ce08:	ba 00 04 00 00       	mov    $0x400,%edx
 115ce0d:	48 8b bc 24 08 01 00 	mov    0x108(%rsp),%rdi
 115ce14:	00 
 115ce15:	48 8b b4 24 b8 00 00 	mov    0xb8(%rsp),%rsi
 115ce1c:	00 
 115ce1d:	e8 7e 15 04 00       	call   119e3a0 <compiler_rt.memcpy.memcpyFast>
 115ce22:	4c 8b 9c 24 30 01 00 	mov    0x130(%rsp),%r11
 115ce29:	00 
 115ce2a:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115ce2f:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115ce34:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115ce3b:	79 37 9e 
 115ce3e:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115ce43:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115ce48:	44 89 b4 24 b8 22 00 	mov    %r14d,0x22b8(%rsp)
 115ce4f:	00 
 115ce50:	c6 84 24 c0 22 00 00 	movb   $0x1,0x22c0(%rsp)
 115ce57:	01 
 115ce58:	48 c7 84 24 c8 22 00 	movq   $0x0,0x22c8(%rsp)
 115ce5f:	00 00 00 00 00 
 115ce64:	48 8b b4 24 00 01 00 	mov    0x100(%rsp),%rsi
 115ce6b:	00 
 115ce6c:	e9 a4 fd ff ff       	jmp    115cc15 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2275>
 115ce71:	48 c7 44 24 60 00 00 	movq   $0x0,0x60(%rsp)
 115ce78:	00 00 
 115ce7a:	48 8d bc 24 c0 03 00 	lea    0x3c0(%rsp),%rdi
 115ce81:	00 
 115ce82:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115ce87:	4c 8b 6c 24 40       	mov    0x40(%rsp),%r13
 115ce8c:	e9 1c fb ff ff       	jmp    115c9ad <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x200d>
 115ce91:	48 39 c2             	cmp    %rax,%rdx
 115ce94:	48 0f 4f c2          	cmovg  %rdx,%rax
 115ce98:	f6 84 24 90 31 00 00 	testb  $0x1,0x3190(%rsp)
 115ce9f:	01 
 115cea0:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115cea5:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115ceaa:	0f 84 d9 fe ff ff    	je     115cd89 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x23e9>
 115ceb0:	31 ff                	xor    %edi,%edi
 115ceb2:	48 8b 94 24 c8 22 00 	mov    0x22c8(%rsp),%rdx
 115ceb9:	00 
 115ceba:	48 8b b4 24 f0 22 00 	mov    0x22f0(%rsp),%rsi
 115cec1:	00 
 115cec2:	48 ff c6             	inc    %rsi
 115cec5:	49 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%r8
 115cecc:	49 0f 44 f0          	cmove  %r8,%rsi
 115ced0:	48 89 b4 24 f0 22 00 	mov    %rsi,0x22f0(%rsp)
 115ced7:	00 
 115ced8:	48 8b b4 24 38 23 00 	mov    0x2338(%rsp),%rsi
 115cedf:	00 
 115cee0:	48 01 ce             	add    %rcx,%rsi
 115cee3:	49 0f 42 f0          	cmovb  %r8,%rsi
 115cee7:	48 89 b4 24 38 23 00 	mov    %rsi,0x2338(%rsp)
 115ceee:	00 
 115ceef:	48 8b b4 24 40 23 00 	mov    0x2340(%rsp),%rsi
 115cef6:	00 
 115cef7:	48 39 ce             	cmp    %rcx,%rsi
 115cefa:	48 0f 46 f1          	cmovbe %rcx,%rsi
 115cefe:	48 89 b4 24 40 23 00 	mov    %rsi,0x2340(%rsp)
 115cf05:	00 
 115cf06:	48 8b b4 24 48 23 00 	mov    0x2348(%rsp),%rsi
 115cf0d:	00 
 115cf0e:	48 39 d6             	cmp    %rdx,%rsi
 115cf11:	48 0f 46 f2          	cmovbe %rdx,%rsi
 115cf15:	48 89 b4 24 48 23 00 	mov    %rsi,0x2348(%rsp)
 115cf1c:	00 
 115cf1d:	48 85 c9             	test   %rcx,%rcx
 115cf20:	0f 84 8d 00 00 00    	je     115cfb3 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2613>
 115cf26:	f3 48 0f bd c9       	lzcnt  %rcx,%rcx
 115cf2b:	f6 d1                	not    %cl
 115cf2d:	80 e1 3f             	and    $0x3f,%cl
 115cf30:	0f b6 c9             	movzbl %cl,%ecx
 115cf33:	80 f9 10             	cmp    $0x10,%cl
 115cf36:	be 10 00 00 00       	mov    $0x10,%esi
 115cf3b:	0f 43 ce             	cmovae %esi,%ecx
 115cf3e:	fe c1                	inc    %cl
 115cf40:	0f b6 c9             	movzbl %cl,%ecx
 115cf43:	eb 70                	jmp    115cfb5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2615>
 115cf45:	66 41 83 fe 28       	cmp    $0x28,%r14w
 115cf4a:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115cf4f:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115cf54:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115cf5b:	79 37 9e 
 115cf5e:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115cf63:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115cf68:	48 8b 44 24 10       	mov    0x10(%rsp),%rax
 115cf6d:	0f 85 76 e4 ff ff    	jne    115b3e9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa49>
 115cf73:	e9 a8 fa ff ff       	jmp    115ca20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2080>
 115cf78:	83 f8 28             	cmp    $0x28,%eax
 115cf7b:	0f 85 8e 01 00 00    	jne    115d10f <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x276f>
 115cf81:	66 45 85 f6          	test   %r14w,%r14w
 115cf85:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115cf8a:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115cf8f:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115cf96:	79 37 9e 
 115cf99:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115cf9e:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115cfa3:	48 8b 74 24 10       	mov    0x10(%rsp),%rsi
 115cfa8:	0f 85 3b e4 ff ff    	jne    115b3e9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa49>
 115cfae:	e9 0f fb ff ff       	jmp    115cac2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2122>
 115cfb3:	31 c9                	xor    %ecx,%ecx
 115cfb5:	48 8b b4 cc 50 23 00 	mov    0x2350(%rsp,%rcx,8),%rsi
 115cfbc:	00 
 115cfbd:	48 ff c6             	inc    %rsi
 115cfc0:	49 0f 44 f0          	cmove  %r8,%rsi
 115cfc4:	48 89 b4 cc 50 23 00 	mov    %rsi,0x2350(%rsp,%rcx,8)
 115cfcb:	00 
 115cfcc:	48 85 d2             	test   %rdx,%rdx
 115cfcf:	74 1f                	je     115cff0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2650>
 115cfd1:	f3 48 0f bd ca       	lzcnt  %rdx,%rcx
 115cfd6:	f6 d1                	not    %cl
 115cfd8:	80 e1 3f             	and    $0x3f,%cl
 115cfdb:	0f b6 c9             	movzbl %cl,%ecx
 115cfde:	80 f9 0e             	cmp    $0xe,%cl
 115cfe1:	ba 0e 00 00 00       	mov    $0xe,%edx
 115cfe6:	0f 43 ca             	cmovae %edx,%ecx
 115cfe9:	fe c1                	inc    %cl
 115cfeb:	0f b6 c9             	movzbl %cl,%ecx
 115cfee:	eb 02                	jmp    115cff2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2652>
 115cff0:	31 c9                	xor    %ecx,%ecx
 115cff2:	48 8b 94 cc e0 23 00 	mov    0x23e0(%rsp,%rcx,8),%rdx
 115cff9:	00 
 115cffa:	48 ff c2             	inc    %rdx
 115cffd:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 115d004:	48 0f 44 d6          	cmove  %rsi,%rdx
 115d008:	48 89 94 cc e0 23 00 	mov    %rdx,0x23e0(%rsp,%rcx,8)
 115d00f:	00 
 115d010:	c6 84 24 80 28 00 00 	movb   $0x0,0x2880(%rsp)
 115d017:	00 
 115d018:	40 84 ff             	test   %dil,%dil
 115d01b:	74 0f                	je     115d02c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x268c>
 115d01d:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115d022:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115d027:	e9 c9 f2 ff ff       	jmp    115c2f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1955>
 115d02c:	31 c9                	xor    %ecx,%ecx
 115d02e:	48 8b 54 24 38       	mov    0x38(%rsp),%rdx
 115d033:	48 81 fa 00 04 00 00 	cmp    $0x400,%rdx
 115d03a:	0f 93 c1             	setae  %cl
 115d03d:	48 8d 0c 49          	lea    (%rcx,%rcx,2),%rcx
 115d041:	48 01 c8             	add    %rcx,%rax
 115d044:	48 83 c0 08          	add    $0x8,%rax
 115d048:	48 c1 e8 03          	shr    $0x3,%rax
 115d04c:	4c 8d 70 06          	lea    0x6(%rax),%r14
 115d050:	41 bd 05 00 00 00    	mov    $0x5,%r13d
 115d056:	48 81 fa 00 04 00 00 	cmp    $0x400,%rdx
 115d05d:	4c 0f 42 f0          	cmovb  %rax,%r14
 115d061:	b8 00 00 00 00       	mov    $0x0,%eax
 115d066:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115d06b:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115d070:	72 26                	jb     115d098 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x26f8>
 115d072:	41 bd 06 00 00 00    	mov    $0x6,%r13d
 115d078:	48 81 7c 24 38 00 40 	cmpq   $0x4000,0x38(%rsp)
 115d07f:	00 00 
 115d081:	72 15                	jb     115d098 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x26f8>
 115d083:	41 bd 07 00 00 00    	mov    $0x7,%r13d
 115d089:	48 81 7c 24 38 ff ff 	cmpq   $0x3ffff,0x38(%rsp)
 115d090:	03 00 
 115d092:	0f 87 5d f2 ff ff    	ja     115c2f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1955>
 115d098:	84 c0                	test   %al,%al
 115d09a:	0f 85 55 f2 ff ff    	jne    115c2f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1955>
 115d0a0:	84 c0                	test   %al,%al
 115d0a2:	0f 85 4d f2 ff ff    	jne    115c2f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1955>
 115d0a8:	48 8d bc 24 c0 03 00 	lea    0x3c0(%rsp),%rdi
 115d0af:	00 
 115d0b0:	48 8b b4 24 d8 00 00 	mov    0xd8(%rsp),%rsi
 115d0b7:	00 
 115d0b8:	4c 89 e2             	mov    %r12,%rdx
 115d0bb:	48 8b 4c 24 10       	mov    0x10(%rsp),%rcx
 115d0c0:	c5 f8 77             	vzeroupper 
 115d0c3:	e8 58 0e 00 00       	call   115df20 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase>
 115d0c8:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115d0cd:	80 bc 24 c8 03 00 00 	cmpb   $0x0,0x3c8(%rsp)
 115d0d4:	00 
 115d0d5:	0f 84 1a f2 ff ff    	je     115c2f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1955>
 115d0db:	4d 01 ee             	add    %r13,%r14
 115d0de:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 115d0e3:	4c 39 f0             	cmp    %r14,%rax
 115d0e6:	4c 0f 42 f0          	cmovb  %rax,%r14
 115d0ea:	4c 03 b4 24 c0 03 00 	add    0x3c0(%rsp),%r14
 115d0f1:	00 
 115d0f2:	0f 92 84 24 80 28 00 	setb   0x2880(%rsp)
 115d0f9:	00 
 115d0fa:	0f 83 8d 00 00 00    	jae    115d18d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x27ed>
 115d100:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115d105:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115d10a:	e9 f2 f1 ff ff       	jmp    115c301 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1961>
 115d10f:	4c 8b ac 24 c8 00 00 	mov    0xc8(%rsp),%r13
 115d116:	00 
 115d117:	4c 8b a4 24 98 00 00 	mov    0x98(%rsp),%r12
 115d11e:	00 
 115d11f:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115d124:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115d129:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115d130:	79 37 9e 
 115d133:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115d138:	44 8b 74 24 1c       	mov    0x1c(%rsp),%r14d
 115d13d:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115d142:	e9 3a dc ff ff       	jmp    115ad81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x3e1>
 115d147:	48 8b 84 24 68 1d 00 	mov    0x1d68(%rsp),%rax
 115d14e:	00 
 115d14f:	48 ff c0             	inc    %rax
 115d152:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 115d159:	48 0f 44 c1          	cmove  %rcx,%rax
 115d15d:	48 89 84 24 68 1d 00 	mov    %rax,0x1d68(%rsp)
 115d164:	00 
 115d165:	48 8b 8c 24 f8 00 00 	mov    0xf8(%rsp),%rcx
 115d16c:	00 
 115d16d:	48 8b 84 24 d0 00 00 	mov    0xd0(%rsp),%rax
 115d174:	00 
 115d175:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115d17a:	80 39 00             	cmpb   $0x0,(%rcx)
 115d17d:	4c 8b 6c 24 38       	mov    0x38(%rsp),%r13
 115d182:	0f 85 92 f6 ff ff    	jne    115c81a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e7a>
 115d188:	e9 87 f3 ff ff       	jmp    115c514 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1b74>
 115d18d:	4c 89 b4 24 b0 00 00 	mov    %r14,0xb0(%rsp)
 115d194:	00 
 115d195:	c6 04 24 01          	movb   $0x1,(%rsp)
 115d199:	48 8d b4 24 b0 00 00 	lea    0xb0(%rsp),%rsi
 115d1a0:	00 
 115d1a1:	48 89 e7             	mov    %rsp,%rdi
 115d1a4:	4c 3b b4 24 a0 00 00 	cmp    0xa0(%rsp),%r14
 115d1ab:	00 
 115d1ac:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115d1b1:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115d1b6:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 115d1bb:	0f 82 54 f1 ff ff    	jb     115c315 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1975>
 115d1c1:	0f 95 c1             	setne  %cl
 115d1c4:	48 3b 54 24 28       	cmp    0x28(%rsp),%rdx
 115d1c9:	0f 96 c0             	setbe  %al
 115d1cc:	08 c8                	or     %cl,%al
 115d1ce:	4c 3b b4 24 a0 00 00 	cmp    0xa0(%rsp),%r14
 115d1d5:	00 
 115d1d6:	75 2a                	jne    115d202 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2862>
 115d1d8:	48 8b 4c 24 10       	mov    0x10(%rsp),%rcx
 115d1dd:	48 3b 4c 24 28       	cmp    0x28(%rsp),%rcx
 115d1e2:	76 1e                	jbe    115d202 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2862>
 115d1e4:	48 8b 8c 24 30 23 00 	mov    0x2330(%rsp),%rcx
 115d1eb:	00 
 115d1ec:	48 ff c1             	inc    %rcx
 115d1ef:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 115d1f6:	48 0f 44 ca          	cmove  %rdx,%rcx
 115d1fa:	48 89 8c 24 30 23 00 	mov    %rcx,0x2330(%rsp)
 115d201:	00 
 115d202:	48 8d b4 24 b0 00 00 	lea    0xb0(%rsp),%rsi
 115d209:	00 
 115d20a:	48 89 e7             	mov    %rsp,%rdi
 115d20d:	84 c0                	test   %al,%al
 115d20f:	48 8b 54 24 10       	mov    0x10(%rsp),%rdx
 115d214:	4c 8b 64 24 60       	mov    0x60(%rsp),%r12
 115d219:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 115d21e:	0f 84 f1 f0 ff ff    	je     115c315 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1975>
 115d224:	48 8b 84 24 00 23 00 	mov    0x2300(%rsp),%rax
 115d22b:	00 
 115d22c:	48 ff c0             	inc    %rax
 115d22f:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 115d236:	48 0f 44 c1          	cmove  %rcx,%rax
 115d23a:	48 89 84 24 00 23 00 	mov    %rax,0x2300(%rsp)
 115d241:	00 
 115d242:	48 8b 84 24 50 1d 00 	mov    0x1d50(%rsp),%rax
 115d249:	00 
 115d24a:	48 ff c0             	inc    %rax
 115d24d:	48 0f 44 c1          	cmove  %rcx,%rax
 115d251:	48 89 84 24 50 1d 00 	mov    %rax,0x1d50(%rsp)
 115d258:	00 
 115d259:	48 8b 84 24 08 23 00 	mov    0x2308(%rsp),%rax
 115d260:	00 
 115d261:	48 ff c0             	inc    %rax
 115d264:	48 0f 44 c1          	cmove  %rcx,%rax
 115d268:	48 89 84 24 08 23 00 	mov    %rax,0x2308(%rsp)
 115d26f:	00 
 115d270:	4c 8b ac 24 c8 00 00 	mov    0xc8(%rsp),%r13
 115d277:	00 
 115d278:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 115d27d:	48 8b 7c 24 30       	mov    0x30(%rsp),%rdi
 115d282:	49 b8 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r8
 115d289:	79 37 9e 
 115d28c:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115d291:	44 8b 74 24 1c       	mov    0x1c(%rsp),%r14d
 115d296:	4c 8b 54 24 48       	mov    0x48(%rsp),%r10
 115d29b:	e9 56 e1 ff ff       	jmp    115b3f6 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa56>
 115d2a0:	48 8d bc 24 b0 02 00 	lea    0x2b0(%rsp),%rdi
 115d2a7:	00 
 115d2a8:	4c 89 e6             	mov    %r12,%rsi
 115d2ab:	4c 89 ea             	mov    %r13,%rdx
 115d2ae:	4c 89 c9             	mov    %r9,%rcx
 115d2b1:	c5 f8 77             	vzeroupper 
 115d2b4:	e8 e7 02 00 00       	call   115d5a0 <zstd.findBestDuplicateMatchIn>
 115d2b9:	0f b7 84 24 d8 02 00 	movzwl 0x2d8(%rsp),%eax
 115d2c0:	00 
 115d2c1:	66 85 c0             	test   %ax,%ax
 115d2c4:	0f 85 3b 01 00 00    	jne    115d405 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a65>
 115d2ca:	80 bc 24 d0 02 00 00 	cmpb   $0x0,0x2d0(%rsp)
 115d2d1:	00 
 115d2d2:	0f 84 ad 02 00 00    	je     115d585 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2be5>
 115d2d8:	c5 fc 10 84 24 b0 02 	vmovups 0x2b0(%rsp),%ymm0
 115d2df:	00 00 
 115d2e1:	c5 fc 11 84 24 10 02 	vmovups %ymm0,0x210(%rsp)
 115d2e8:	00 00 
 115d2ea:	48 8b bc 24 18 02 00 	mov    0x218(%rsp),%rdi
 115d2f1:	00 
 115d2f2:	48 8b 8c 24 20 02 00 	mov    0x220(%rsp),%rcx
 115d2f9:	00 
 115d2fa:	48 8d 84 24 10 02 00 	lea    0x210(%rsp),%rax
 115d301:	00 
 115d302:	4c 8b 84 24 a8 00 00 	mov    0xa8(%rsp),%r8
 115d309:	00 
 115d30a:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 115d30f:	4d 85 c0             	test   %r8,%r8
 115d312:	0f 85 82 00 00 00    	jne    115d39a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x29fa>
 115d318:	eb 5c                	jmp    115d376 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x29d6>
 115d31a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 115d320:	45 84 f6             	test   %r14b,%r14b
 115d323:	0f 84 b8 00 00 00    	je     115d3e1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a41>
 115d329:	48 8b 84 24 38 01 00 	mov    0x138(%rsp),%rax
 115d330:	00 
 115d331:	48 89 84 24 f0 01 00 	mov    %rax,0x1f0(%rsp)
 115d338:	00 
 115d339:	48 8b bc 24 e8 00 00 	mov    0xe8(%rsp),%rdi
 115d340:	00 
 115d341:	48 89 bc 24 f8 01 00 	mov    %rdi,0x1f8(%rsp)
 115d348:	00 
 115d349:	48 89 8c 24 00 02 00 	mov    %rcx,0x200(%rsp)
 115d350:	00 
 115d351:	48 8b 84 24 70 01 00 	mov    0x170(%rsp),%rax
 115d358:	00 
 115d359:	48 89 84 24 08 02 00 	mov    %rax,0x208(%rsp)
 115d360:	00 
 115d361:	48 8d 84 24 f0 01 00 	lea    0x1f0(%rsp),%rax
 115d368:	00 
 115d369:	4c 8b 84 24 a8 00 00 	mov    0xa8(%rsp),%r8
 115d370:	00 
 115d371:	4d 85 c0             	test   %r8,%r8
 115d374:	75 24                	jne    115d39a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x29fa>
 115d376:	49 89 fa             	mov    %rdi,%r10
 115d379:	48 8b 38             	mov    (%rax),%rdi
 115d37c:	48 8b 50 18          	mov    0x18(%rax),%rdx
 115d380:	48 8b 75 18          	mov    0x18(%rbp),%rsi
 115d384:	48 89 3e             	mov    %rdi,(%rsi)
 115d387:	4c 89 d7             	mov    %r10,%rdi
 115d38a:	4c 89 56 08          	mov    %r10,0x8(%rsi)
 115d38e:	48 89 4e 10          	mov    %rcx,0x10(%rsi)
 115d392:	48 89 56 18          	mov    %rdx,0x18(%rsi)
 115d396:	c6 46 20 01          	movb   $0x1,0x20(%rsi)
 115d39a:	48 89 fe             	mov    %rdi,%rsi
 115d39d:	4c 29 ce             	sub    %r9,%rsi
 115d3a0:	4c 89 c2             	mov    %r8,%rdx
 115d3a3:	48 c1 e2 05          	shl    $0x5,%rdx
 115d3a7:	c5 fc 10 00          	vmovups (%rax),%ymm0
 115d3ab:	c5 fc 11 84 14 a8 3e 	vmovups %ymm0,0x3ea8(%rsp,%rdx,1)
 115d3b2:	00 00 
 115d3b4:	4a 89 b4 c4 a8 3a 00 	mov    %rsi,0x3aa8(%rsp,%r8,8)
 115d3bb:	00 
 115d3bc:	4d 8d 70 01          	lea    0x1(%r8),%r14
 115d3c0:	48 01 f9             	add    %rdi,%rcx
 115d3c3:	49 83 f8 7e          	cmp    $0x7e,%r8
 115d3c7:	77 23                	ja     115d3ec <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a4c>
 115d3c9:	49 89 c9             	mov    %rcx,%r9
 115d3cc:	4c 89 f2             	mov    %r14,%rdx
 115d3cf:	4c 39 e9             	cmp    %r13,%rcx
 115d3d2:	8b 84 24 f4 00 00 00 	mov    0xf4(%rsp),%eax
 115d3d9:	0f 82 21 d9 ff ff    	jb     115ad00 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x360>
 115d3df:	eb 0b                	jmp    115d3ec <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a4c>
 115d3e1:	4c 8b b4 24 a8 00 00 	mov    0xa8(%rsp),%r14
 115d3e8:	00 
 115d3e9:	4c 89 c9             	mov    %r9,%rcx
 115d3ec:	4c 89 f0             	mov    %r14,%rax
 115d3ef:	49 83 fe 02          	cmp    $0x2,%r14
 115d3f3:	73 3c                	jae    115d431 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a91>
 115d3f5:	0f b6 05 52 55 ea ff 	movzbl -0x15aaae(%rip),%eax        # 100294e <__anon_15732+0x2>
 115d3fc:	88 84 24 80 28 00 00 	mov    %al,0x2880(%rsp)
 115d403:	31 c0                	xor    %eax,%eax
 115d405:	0f b6 8c 24 80 28 00 	movzbl 0x2880(%rsp),%ecx
 115d40c:	00 
 115d40d:	c1 e1 10             	shl    $0x10,%ecx
 115d410:	0f b7 c0             	movzwl %ax,%eax
 115d413:	09 c8                	or     %ecx,%eax
 115d415:	48 8b 8c 24 78 01 00 	mov    0x178(%rsp),%rcx
 115d41c:	00 
 115d41d:	89 01                	mov    %eax,(%rcx)
 115d41f:	48 8d 65 d8          	lea    -0x28(%rbp),%rsp
 115d423:	5b                   	pop    %rbx
 115d424:	41 5c                	pop    %r12
 115d426:	41 5d                	pop    %r13
 115d428:	41 5e                	pop    %r14
 115d42a:	41 5f                	pop    %r15
 115d42c:	5d                   	pop    %rbp
 115d42d:	c5 f8 77             	vzeroupper 
 115d430:	c3                   	ret    
 115d431:	49 89 cf             	mov    %rcx,%r15
 115d434:	48 83 f8 01          	cmp    $0x1,%rax
 115d438:	75 10                	jne    115d44a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2aaa>
 115d43a:	45 31 d2             	xor    %r10d,%r10d
 115d43d:	48 8b 8c 24 98 00 00 	mov    0x98(%rsp),%rcx
 115d444:	00 
 115d445:	e9 80 00 00 00       	jmp    115d4ca <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2b2a>
 115d44a:	48 89 c2             	mov    %rax,%rdx
 115d44d:	48 83 e2 fe          	and    $0xfffffffffffffffe,%rdx
 115d451:	48 8d b4 24 d8 3e 00 	lea    0x3ed8(%rsp),%rsi
 115d458:	00 
 115d459:	45 31 d2             	xor    %r10d,%r10d
 115d45c:	48 8b 8c 24 98 00 00 	mov    0x98(%rsp),%rcx
 115d463:	00 
 115d464:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115d46b:	00 00 00 00 00 
 115d470:	48 8b 7e d8          	mov    -0x28(%rsi),%rdi
 115d474:	4c 8b 46 e0          	mov    -0x20(%rsi),%r8
 115d478:	4e 89 84 d4 a8 4e 00 	mov    %r8,0x4ea8(%rsp,%r10,8)
 115d47f:	00 
 115d480:	49 01 f8             	add    %rdi,%r8
 115d483:	48 2b 7e d0          	sub    -0x30(%rsi),%rdi
 115d487:	4a 89 bc d4 c0 03 00 	mov    %rdi,0x3c0(%rsp,%r10,8)
 115d48e:	00 
 115d48f:	48 8b 7e f8          	mov    -0x8(%rsi),%rdi
 115d493:	4c 8b 0e             	mov    (%rsi),%r9
 115d496:	4e 89 8c d4 b0 4e 00 	mov    %r9,0x4eb0(%rsp,%r10,8)
 115d49d:	00 
 115d49e:	49 01 f9             	add    %rdi,%r9
 115d4a1:	48 2b 7e f0          	sub    -0x10(%rsi),%rdi
 115d4a5:	4e 89 84 d4 a8 ce 00 	mov    %r8,0xcea8(%rsp,%r10,8)
 115d4ac:	00 
 115d4ad:	4a 89 bc d4 c8 03 00 	mov    %rdi,0x3c8(%rsp,%r10,8)
 115d4b4:	00 
 115d4b5:	4e 89 8c d4 b0 ce 00 	mov    %r9,0xceb0(%rsp,%r10,8)
 115d4bc:	00 
 115d4bd:	49 83 c2 02          	add    $0x2,%r10
 115d4c1:	48 83 c6 40          	add    $0x40,%rsi
 115d4c5:	4c 39 d2             	cmp    %r10,%rdx
 115d4c8:	75 a6                	jne    115d470 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2ad0>
 115d4ca:	a8 01                	test   $0x1,%al
 115d4cc:	74 3a                	je     115d508 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2b68>
 115d4ce:	4c 89 d2             	mov    %r10,%rdx
 115d4d1:	48 c1 e2 05          	shl    $0x5,%rdx
 115d4d5:	48 8b b4 14 b0 3e 00 	mov    0x3eb0(%rsp,%rdx,1),%rsi
 115d4dc:	00 
 115d4dd:	48 8b bc 14 b8 3e 00 	mov    0x3eb8(%rsp,%rdx,1),%rdi
 115d4e4:	00 
 115d4e5:	4a 89 bc d4 a8 4e 00 	mov    %rdi,0x4ea8(%rsp,%r10,8)
 115d4ec:	00 
 115d4ed:	48 01 f7             	add    %rsi,%rdi
 115d4f0:	48 2b b4 14 a8 3e 00 	sub    0x3ea8(%rsp,%rdx,1),%rsi
 115d4f7:	00 
 115d4f8:	4a 89 b4 d4 c0 03 00 	mov    %rsi,0x3c0(%rsp,%r10,8)
 115d4ff:	00 
 115d500:	4a 89 bc d4 a8 ce 00 	mov    %rdi,0xcea8(%rsp,%r10,8)
 115d507:	00 
 115d508:	4c 8d 94 24 a8 ce 00 	lea    0xcea8(%rsp),%r10
 115d50f:	00 
 115d510:	4c 8d 9c 24 a8 4e 00 	lea    0x4ea8(%rsp),%r11
 115d517:	00 
 115d518:	48 8d 9c 24 c0 03 00 	lea    0x3c0(%rsp),%rbx
 115d51f:	00 
 115d520:	4c 8d b4 24 a8 3a 00 	lea    0x3aa8(%rsp),%r14
 115d527:	00 
 115d528:	44 0f b6 8c 24 f0 00 	movzbl 0xf0(%rsp),%r9d
 115d52f:	00 00 
 115d531:	48 8d bc 24 80 28 00 	lea    0x2880(%rsp),%rdi
 115d538:	00 
 115d539:	48 8b b4 24 60 01 00 	mov    0x160(%rsp),%rsi
 115d540:	00 
 115d541:	48 8b 94 24 68 01 00 	mov    0x168(%rsp),%rdx
 115d548:	00 
 115d549:	4d 89 e8             	mov    %r13,%r8
 115d54c:	6a 00                	push   $0x0
 115d54e:	41 57                	push   %r15
 115d550:	50                   	push   %rax
 115d551:	41 52                	push   %r10
 115d553:	50                   	push   %rax
 115d554:	41 53                	push   %r11
 115d556:	50                   	push   %rax
 115d557:	53                   	push   %rbx
 115d558:	50                   	push   %rax
 115d559:	41 56                	push   %r14
 115d55b:	c5 f8 77             	vzeroupper 
 115d55e:	e8 2d f1 fe ff       	call   114c690 <zstd.emitBestSequenceCompressedBlockWithScratch>
 115d563:	48 83 c4 50          	add    $0x50,%rsp
 115d567:	0f b7 84 24 80 28 00 	movzwl 0x2880(%rsp),%eax
 115d56e:	00 
 115d56f:	66 85 c0             	test   %ax,%ax
 115d572:	0f 85 8d fe ff ff    	jne    115d405 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a65>
 115d578:	0f b6 84 24 82 28 00 	movzbl 0x2882(%rsp),%eax
 115d57f:	00 
 115d580:	e9 77 fe ff ff       	jmp    115d3fc <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a5c>
 115d585:	4c 8b b4 24 a8 00 00 	mov    0xa8(%rsp),%r14
 115d58c:	00 
 115d58d:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 115d592:	e9 55 fe ff ff       	jmp    115d3ec <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a4c>
 115d597:	4c 89 e1             	mov    %r12,%rcx
 115d59a:	e9 4d fe ff ff       	jmp    115d3ec <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a4c>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_zstd_huffman_wide_x2:

Disassembly of section .vort_zstd_huffman_only_decode:

Disassembly of section .vort_zstd_frr_decode:

Disassembly of section .vort_zstd_zz_frr_pair:

Disassembly of section .vort_zstd_ffr_decode:

Disassembly of section .vort_zstd_raw_fse_decode:

Disassembly of section .vort_zstd_zz_ffr_pair:

Disassembly of section .vort_zstd_split_zz:

Disassembly of section .vort_zstd_split_wide_literal_decode:

Disassembly of section .vort_zstd_split_dense_literal_decode:

Disassembly of section .vort_zstd_split_literal_decode:

Disassembly of section .vort_zstd_zzz_long_match:

Disassembly of section .vort_zstd_zz_fse_mapped:

Disassembly of section .vort_zstd_fse_256:

Disassembly of section .vort_zstd_fse_counts:

Disassembly of section .vort_zstd_huffman_build:

Disassembly of section .vort_zstd_medium_split:

Disassembly of section .vort_zstd_tiny_raw:

Disassembly of section .vort_zstd_small_frame_decode:

Disassembly of section .vort_zstd_small_sequence_decode:

Disassembly of section .vort_zstd_fast_records:

Disassembly of section .vort_zstd_wide_sequence:

Disassembly of section .vort_zstd_dense_huffman:

Disassembly of section .vort_zstd_fast_encode:

Disassembly of section .vort_zstd_fast_large:

Disassembly of section .vort_zstd_fast_plan:

Disassembly of section .vort_zstd_multi_sequence_winner:

Disassembly of section .vort_zstd_fse_encode:

Disassembly of section .vort_zstd_dominance:

Disassembly of section .vort_zstd_zz_optimal:

Disassembly of section .vort_zstd_single_beam:

Disassembly of section .plt:
