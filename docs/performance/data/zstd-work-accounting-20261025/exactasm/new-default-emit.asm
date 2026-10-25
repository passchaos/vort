
/home/passchaos/project-z/vort-zstd-work-accounting/.zig-cache/o/cb5827954aa0d116f6d48f2b2bf9daeb/vort-zstd-encode-bench:     file format elf64-x86-64


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
 115a9b1:	48 81 ec 20 cd 02 00 	sub    $0x2cd20,%rsp
 115a9b8:	48 89 bc 24 58 01 00 	mov    %rdi,0x158(%rsp)
 115a9bf:	00 
 115a9c0:	48 8b 45 18          	mov    0x18(%rbp),%rax
 115a9c4:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 115a9c8:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 115a9cc:	48 c7 40 20 00 00 00 	movq   $0x0,0x20(%rax)
 115a9d3:	00 
 115a9d4:	49 83 f8 02          	cmp    $0x2,%r8
 115a9d8:	0f 82 4c 26 00 00    	jb     115d02a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x268a>
 115a9de:	4d 89 c4             	mov    %r8,%r12
 115a9e1:	49 89 d6             	mov    %rdx,%r14
 115a9e4:	48 8b 5d 10          	mov    0x10(%rbp),%rbx
 115a9e8:	0f b6 01             	movzbl (%rcx),%eax
 115a9eb:	ba 01 00 00 00       	mov    $0x1,%edx
 115a9f0:	38 04 11             	cmp    %al,(%rcx,%rdx,1)
 115a9f3:	75 0d                	jne    115aa02 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x62>
 115a9f5:	48 ff c2             	inc    %rdx
 115a9f8:	49 39 d4             	cmp    %rdx,%r12
 115a9fb:	75 f3                	jne    115a9f0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x50>
 115a9fd:	e9 28 26 00 00       	jmp    115d02a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x268a>
 115aa02:	49 83 fc 1f          	cmp    $0x1f,%r12
 115aa06:	0f 86 1e 26 00 00    	jbe    115d02a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x268a>
 115aa0c:	48 89 b4 24 38 01 00 	mov    %rsi,0x138(%rsp)
 115aa13:	00 
 115aa14:	44 89 8c 24 c4 00 00 	mov    %r9d,0xc4(%rsp)
 115aa1b:	00 
 115aa1c:	48 89 4c 24 30       	mov    %rcx,0x30(%rsp)
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
 115ab63:	48 8d bc 24 08 1a 00 	lea    0x1a08(%rsp),%rdi
 115ab6a:	00 
 115ab6b:	ba c8 15 00 00       	mov    $0x15c8,%edx
 115ab70:	31 f6                	xor    %esi,%esi
 115ab72:	c5 f8 77             	vzeroupper 
 115ab75:	e8 26 30 04 00       	call   119dba0 <compiler_rt.memset>
 115ab7a:	4c 89 e0             	mov    %r12,%rax
 115ab7d:	48 c1 e8 20          	shr    $0x20,%rax
 115ab81:	0f 95 c0             	setne  %al
 115ab84:	48 85 db             	test   %rbx,%rbx
 115ab87:	0f 84 47 01 00 00    	je     115acd4 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x334>
 115ab8d:	48 8d bc 24 e0 cc 00 	lea    0xcce0(%rsp),%rdi
 115ab94:	00 
 115ab95:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115ab9a:	4c 89 e2             	mov    %r12,%rdx
 115ab9d:	31 c9                	xor    %ecx,%ecx
 115ab9f:	49 89 d8             	mov    %rbx,%r8
 115aba2:	45 31 c9             	xor    %r9d,%r9d
 115aba5:	e8 56 32 00 00       	call   115de00 <zstd.findBestDuplicateMatchIndexedCancellable>
 115abaa:	0f b7 84 24 08 cd 00 	movzwl 0xcd08(%rsp),%eax
 115abb1:	00 
 115abb2:	66 85 c0             	test   %ax,%ax
 115abb5:	0f 85 7f 24 00 00    	jne    115d03a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x269a>
 115abbb:	80 bc 24 00 cd 00 00 	cmpb   $0x0,0xcd00(%rsp)
 115abc2:	00 
 115abc3:	48 8b 54 24 28       	mov    0x28(%rsp),%rdx
 115abc8:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115abcd:	0f 84 57 24 00 00    	je     115d02a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x268a>
 115abd3:	c5 fe 6f 84 24 e0 cc 	vmovdqu 0xcce0(%rsp),%ymm0
 115abda:	00 00 
 115abdc:	48 8b 84 24 e0 cc 00 	mov    0xcce0(%rsp),%rax
 115abe3:	00 
 115abe4:	48 8b 4d 18          	mov    0x18(%rbp),%rcx
 115abe8:	c5 fe 7f 01          	vmovdqu %ymm0,(%rcx)
 115abec:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 115abf0:	48 89 84 24 e0 3c 00 	mov    %rax,0x3ce0(%rsp)
 115abf7:	00 
 115abf8:	c4 e3 f9 16 c0 01    	vpextrq $0x1,%xmm0,%rax
 115abfe:	c4 e3 fd 00 c8 e9    	vpermq $0xe9,%ymm0,%ymm1
 115ac04:	c5 fa 7f 8c 24 e8 3c 	vmovdqu %xmm1,0x3ce8(%rsp)
 115ac0b:	00 00 
 115ac0d:	c4 e3 7d 39 c1 01    	vextracti128 $0x1,%ymm0,%xmm1
 115ac13:	c4 e1 f9 7e c9       	vmovq  %xmm1,%rcx
 115ac18:	48 01 c1             	add    %rax,%rcx
 115ac1b:	c4 e3 f9 16 84 24 e0 	vpextrq $0x1,%xmm0,0x38e0(%rsp)
 115ac22:	38 00 00 01 
 115ac26:	48 39 d1             	cmp    %rdx,%rcx
 115ac29:	0f 83 fb 23 00 00    	jae    115d02a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x268a>
 115ac2f:	41 be 01 00 00 00    	mov    $0x1,%r14d
 115ac35:	4c 8d bc 24 00 3d 00 	lea    0x3d00(%rsp),%r15
 115ac3c:	00 
 115ac3d:	4c 8d a4 24 e0 cc 00 	lea    0xcce0(%rsp),%r12
 115ac44:	00 
 115ac45:	4c 89 e7             	mov    %r12,%rdi
 115ac48:	49 89 cd             	mov    %rcx,%r13
 115ac4b:	49 89 d8             	mov    %rbx,%r8
 115ac4e:	45 31 c9             	xor    %r9d,%r9d
 115ac51:	c5 f8 77             	vzeroupper 
 115ac54:	e8 a7 31 00 00       	call   115de00 <zstd.findBestDuplicateMatchIndexedCancellable>
 115ac59:	0f b7 84 24 08 cd 00 	movzwl 0xcd08(%rsp),%eax
 115ac60:	00 
 115ac61:	66 85 c0             	test   %ax,%ax
 115ac64:	0f 85 d0 23 00 00    	jne    115d03a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x269a>
 115ac6a:	80 bc 24 00 cd 00 00 	cmpb   $0x0,0xcd00(%rsp)
 115ac71:	00 
 115ac72:	0f 84 ee 23 00 00    	je     115d066 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x26c6>
 115ac78:	c5 fe 6f 84 24 e0 cc 	vmovdqu 0xcce0(%rsp),%ymm0
 115ac7f:	00 00 
 115ac81:	c4 e3 f9 16 c0 01    	vpextrq $0x1,%xmm0,%rax
 115ac87:	4c 29 e8             	sub    %r13,%rax
 115ac8a:	c4 c1 7e 7f 07       	vmovdqu %ymm0,(%r15)
 115ac8f:	4a 89 84 f4 e0 38 00 	mov    %rax,0x38e0(%rsp,%r14,8)
 115ac96:	00 
 115ac97:	49 8d 46 01          	lea    0x1(%r14),%rax
 115ac9b:	c4 e3 fd 00 c8 aa    	vpermq $0xaa,%ymm0,%ymm1
 115aca1:	c5 f1 d4 c0          	vpaddq %xmm0,%xmm1,%xmm0
 115aca5:	c4 e3 f9 16 c1 01    	vpextrq $0x1,%xmm0,%rcx
 115acab:	49 83 fe 7e          	cmp    $0x7e,%r14
 115acaf:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115acb4:	0f 87 b8 23 00 00    	ja     115d072 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x26d2>
 115acba:	49 83 c7 20          	add    $0x20,%r15
 115acbe:	49 89 c6             	mov    %rax,%r14
 115acc1:	48 8b 54 24 28       	mov    0x28(%rsp),%rdx
 115acc6:	48 39 d1             	cmp    %rdx,%rcx
 115acc9:	0f 82 76 ff ff ff    	jb     115ac45 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2a5>
 115accf:	e9 9e 23 00 00       	jmp    115d072 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x26d2>
 115acd4:	89 44 24 7c          	mov    %eax,0x7c(%rsp)
 115acd8:	48 8d 84 24 08 11 00 	lea    0x1108(%rsp),%rax
 115acdf:	00 
 115ace0:	48 89 84 24 b0 00 00 	mov    %rax,0xb0(%rsp)
 115ace7:	00 
 115ace8:	48 8d 84 24 38 2a 00 	lea    0x2a38(%rsp),%rax
 115acef:	00 
 115acf0:	48 89 84 24 88 00 00 	mov    %rax,0x88(%rsp)
 115acf7:	00 
 115acf8:	48 8d 84 24 f8 0c 00 	lea    0xcf8(%rsp),%rax
 115acff:	00 
 115ad00:	48 89 84 24 80 00 00 	mov    %rax,0x80(%rsp)
 115ad07:	00 
 115ad08:	48 8d 84 24 b8 2b 00 	lea    0x2bb8(%rsp),%rax
 115ad0f:	00 
 115ad10:	48 89 84 24 d0 00 00 	mov    %rax,0xd0(%rsp)
 115ad17:	00 
 115ad18:	48 8d 84 24 d8 03 00 	lea    0x3d8(%rsp),%rax
 115ad1f:	00 
 115ad20:	48 89 84 24 f0 00 00 	mov    %rax,0xf0(%rsp)
 115ad27:	00 
 115ad28:	48 8d 84 24 d8 07 00 	lea    0x7d8(%rsp),%rax
 115ad2f:	00 
 115ad30:	48 89 84 24 e8 00 00 	mov    %rax,0xe8(%rsp)
 115ad37:	00 
 115ad38:	48 8d 84 24 d8 0b 00 	lea    0xbd8(%rsp),%rax
 115ad3f:	00 
 115ad40:	48 89 84 24 e0 00 00 	mov    %rax,0xe0(%rsp)
 115ad47:	00 
 115ad48:	48 8d 84 24 88 2a 00 	lea    0x2a88(%rsp),%rax
 115ad4f:	00 
 115ad50:	48 89 84 24 a0 00 00 	mov    %rax,0xa0(%rsp)
 115ad57:	00 
 115ad58:	48 8d 84 24 90 2a 00 	lea    0x2a90(%rsp),%rax
 115ad5f:	00 
 115ad60:	48 89 84 24 c8 00 00 	mov    %rax,0xc8(%rsp)
 115ad67:	00 
 115ad68:	48 8d 84 24 d8 03 00 	lea    0x3d8(%rsp),%rax
 115ad6f:	00 
 115ad70:	48 89 84 24 d8 00 00 	mov    %rax,0xd8(%rsp)
 115ad77:	00 
 115ad78:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115ad7d:	49 8d 44 24 f8       	lea    -0x8(%r12),%rax
 115ad82:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 115ad87:	45 31 ed             	xor    %r13d,%r13d
 115ad8a:	48 c7 44 24 60 00 00 	movq   $0x0,0x60(%rsp)
 115ad91:	00 00 
 115ad93:	31 c0                	xor    %eax,%eax
 115ad95:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 115ad9c:	00 00 00 00 
 115ada0:	48 89 44 24 70       	mov    %rax,0x70(%rsp)
 115ada5:	80 bc 24 c8 2f 00 00 	cmpb   $0x0,0x2fc8(%rsp)
 115adac:	00 
 115adad:	0f 84 2d 21 00 00    	je     115cee0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2540>
 115adb3:	80 7c 24 7c 00       	cmpb   $0x0,0x7c(%rsp)
 115adb8:	4c 8b 74 24 60       	mov    0x60(%rsp),%r14
 115adbd:	0f 85 56 22 00 00    	jne    115d019 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2679>
 115adc3:	ba 00 80 00 00       	mov    $0x8000,%edx
 115adc8:	48 8d bc 24 e0 4c 00 	lea    0x4ce0(%rsp),%rdi
 115adcf:	00 
 115add0:	31 f6                	xor    %esi,%esi
 115add2:	c5 f8 77             	vzeroupper 
 115add5:	e8 c6 2d 04 00       	call   119dba0 <compiler_rt.memset>
 115adda:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115ade1:	79 37 9e 
 115ade4:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115ade9:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115adee:	4d 39 c6             	cmp    %r8,%r14
 115adf1:	0f 87 22 22 00 00    	ja     115d019 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2679>
 115adf7:	48 c7 84 24 90 00 00 	movq   $0xffffffffffffffff,0x90(%rsp)
 115adfe:	00 ff ff ff ff 
 115ae03:	45 31 d2             	xor    %r10d,%r10d
 115ae06:	4d 89 f3             	mov    %r14,%r11
 115ae09:	eb 22                	jmp    115ae2d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x48d>
 115ae0b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 115ae10:	44 89 9c 94 e0 cc 00 	mov    %r11d,0xcce0(%rsp,%rdx,4)
 115ae17:	00 
 115ae18:	c6 84 14 e0 4c 00 00 	movb   $0x1,0x4ce0(%rsp,%rdx,1)
 115ae1f:	01 
 115ae20:	4d 39 c3             	cmp    %r8,%r11
 115ae23:	4d 8d 5b 01          	lea    0x1(%r11),%r11
 115ae27:	0f 84 33 21 00 00    	je     115cf60 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x25c0>
 115ae2d:	4c 89 e0             	mov    %r12,%rax
 115ae30:	4c 29 d8             	sub    %r11,%rax
 115ae33:	45 84 d2             	test   %r10b,%r10b
 115ae36:	74 09                	je     115ae41 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x4a1>
 115ae38:	48 39 c8             	cmp    %rcx,%rax
 115ae3b:	0f 82 28 21 00 00    	jb     115cf69 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x25c9>
 115ae41:	4a 8b 3c 1e          	mov    (%rsi,%r11,1),%rdi
 115ae45:	48 89 fa             	mov    %rdi,%rdx
 115ae48:	49 0f af d1          	imul   %r9,%rdx
 115ae4c:	48 c1 ea 31          	shr    $0x31,%rdx
 115ae50:	80 bc 14 e0 4c 00 00 	cmpb   $0x0,0x4ce0(%rsp,%rdx,1)
 115ae57:	00 
 115ae58:	74 b6                	je     115ae10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x470>
 115ae5a:	8b 9c 94 e0 cc 00 00 	mov    0xcce0(%rsp,%rdx,4),%ebx
 115ae61:	c6 84 14 e0 4c 00 00 	movb   $0x0,0x4ce0(%rsp,%rdx,1)
 115ae68:	00 
 115ae69:	49 39 de             	cmp    %rbx,%r14
 115ae6c:	77 b2                	ja     115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115ae6e:	48 89 da             	mov    %rbx,%rdx
 115ae71:	4c 89 db             	mov    %r11,%rbx
 115ae74:	48 29 d3             	sub    %rdx,%rbx
 115ae77:	48 89 9c 24 98 00 00 	mov    %rbx,0x98(%rsp)
 115ae7e:	00 
 115ae7f:	76 9f                	jbe    115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115ae81:	45 84 d2             	test   %r10b,%r10b
 115ae84:	74 0a                	je     115ae90 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x4f0>
 115ae86:	48 39 c8             	cmp    %rcx,%rax
 115ae89:	77 05                	ja     115ae90 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x4f0>
 115ae8b:	41 b2 01             	mov    $0x1,%r10b
 115ae8e:	eb 90                	jmp    115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115ae90:	48 39 3c 16          	cmp    %rdi,(%rsi,%rdx,1)
 115ae94:	75 8a                	jne    115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115ae96:	44 89 54 24 24       	mov    %r10d,0x24(%rsp)
 115ae9b:	48 89 4c 24 40       	mov    %rcx,0x40(%rsp)
 115aea0:	48 89 f7             	mov    %rsi,%rdi
 115aea3:	4c 89 e6             	mov    %r12,%rsi
 115aea6:	48 89 94 24 50 01 00 	mov    %rdx,0x150(%rsp)
 115aead:	00 
 115aeae:	4c 89 5c 24 50       	mov    %r11,0x50(%rsp)
 115aeb3:	4c 89 d9             	mov    %r11,%rcx
 115aeb6:	c5 f8 77             	vzeroupper 
 115aeb9:	e8 12 56 fb ff       	call   11104d0 <zstd.duplicateMatchLengthAfterAnchor>
 115aebe:	48 83 f8 08          	cmp    $0x8,%rax
 115aec2:	73 28                	jae    115aeec <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x54c>
 115aec4:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115aec9:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115aece:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115aed3:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115aeda:	79 37 9e 
 115aedd:	44 8b 54 24 24       	mov    0x24(%rsp),%r10d
 115aee2:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115aee7:	e9 34 ff ff ff       	jmp    115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115aeec:	44 8b 54 24 24       	mov    0x24(%rsp),%r10d
 115aef1:	45 84 d2             	test   %r10b,%r10b
 115aef4:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115aef9:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115aefe:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115af03:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115af0a:	79 37 9e 
 115af0d:	c5 d9 ef e4          	vpxor  %xmm4,%xmm4,%xmm4
 115af11:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115af16:	74 0f                	je     115af27 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x587>
 115af18:	48 39 c8             	cmp    %rcx,%rax
 115af1b:	0f 82 ff fe ff ff    	jb     115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115af21:	0f 86 f0 03 00 00    	jbe    115b317 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x977>
 115af27:	48 89 44 24 68       	mov    %rax,0x68(%rsp)
 115af2c:	4c 01 d8             	add    %r11,%rax
 115af2f:	48 8b bc 24 10 1a 00 	mov    0x1a10(%rsp),%rdi
 115af36:	00 
 115af37:	48 29 c7             	sub    %rax,%rdi
 115af3a:	0f 82 9a 11 00 00    	jb     115c0da <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x173a>
 115af40:	4d 89 dc             	mov    %r11,%r12
 115af43:	4d 29 f4             	sub    %r14,%r12
 115af46:	4a 8d 0c 27          	lea    (%rdi,%r12,1),%rcx
 115af4a:	48 83 c1 03          	add    $0x3,%rcx
 115af4e:	4c 01 e7             	add    %r12,%rdi
 115af51:	48 c1 e9 02          	shr    $0x2,%rcx
 115af55:	4c 29 e0             	sub    %r12,%rax
 115af58:	31 d2                	xor    %edx,%edx
 115af5a:	48 8b b4 24 b0 00 00 	mov    0xb0(%rsp),%rsi
 115af61:	00 
 115af62:	c5 fe 7f 66 20       	vmovdqu %ymm4,0x20(%rsi)
 115af67:	c5 fe 7f 26          	vmovdqu %ymm4,(%rsi)
 115af6b:	48 81 ff 00 04 00 00 	cmp    $0x400,%rdi
 115af72:	0f 93 c2             	setae  %dl
 115af75:	48 8d 74 52 01       	lea    0x1(%rdx,%rdx,2),%rsi
 115af7a:	48 89 7c 24 58       	mov    %rdi,0x58(%rsp)
 115af7f:	48 0f 42 cf          	cmovb  %rdi,%rcx
 115af83:	48 89 b4 24 60 01 00 	mov    %rsi,0x160(%rsp)
 115af8a:	00 
 115af8b:	0f 83 bd 03 00 00    	jae    115b34e <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x9ae>
 115af91:	31 d2                	xor    %edx,%edx
 115af93:	f6 84 24 60 01 00 00 	testb  $0x1,0x160(%rsp)
 115af9a:	01 
 115af9b:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115afa2:	79 37 9e 
 115afa5:	74 4f                	je     115aff6 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x656>
 115afa7:	48 89 d6             	mov    %rdx,%rsi
 115afaa:	48 c1 e6 04          	shl    $0x4,%rsi
 115afae:	48 8d bc 24 08 11 00 	lea    0x1108(%rsp),%rdi
 115afb5:	00 
 115afb6:	48 01 fe             	add    %rdi,%rsi
 115afb9:	48 0f af d1          	imul   %rcx,%rdx
 115afbd:	48 01 d1             	add    %rdx,%rcx
 115afc0:	48 8b 7c 24 58       	mov    0x58(%rsp),%rdi
 115afc5:	48 39 cf             	cmp    %rcx,%rdi
 115afc8:	48 0f 42 cf          	cmovb  %rdi,%rcx
 115afcc:	4c 39 e2             	cmp    %r12,%rdx
 115afcf:	73 0f                	jae    115afe0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x640>
 115afd1:	89 16                	mov    %edx,(%rsi)
 115afd3:	4c 39 e1             	cmp    %r12,%rcx
 115afd6:	4c 89 e7             	mov    %r12,%rdi
 115afd9:	48 0f 42 f9          	cmovb  %rcx,%rdi
 115afdd:	89 7e 04             	mov    %edi,0x4(%rsi)
 115afe0:	4c 39 e1             	cmp    %r12,%rcx
 115afe3:	76 11                	jbe    115aff6 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x656>
 115afe5:	4c 39 e2             	cmp    %r12,%rdx
 115afe8:	49 0f 46 d4          	cmovbe %r12,%rdx
 115afec:	01 c2                	add    %eax,%edx
 115afee:	89 56 08             	mov    %edx,0x8(%rsi)
 115aff1:	01 c1                	add    %eax,%ecx
 115aff3:	89 4e 0c             	mov    %ecx,0xc(%rsi)
 115aff6:	4c 89 a4 24 a8 00 00 	mov    %r12,0xa8(%rsp)
 115affd:	00 
 115affe:	48 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%rax
 115b005:	00 
 115b006:	c5 fe 6f 00          	vmovdqu (%rax),%ymm0
 115b00a:	c5 fe 6f 48 20       	vmovdqu 0x20(%rax),%ymm1
 115b00f:	c5 fe 7f 8c 24 90 02 	vmovdqu %ymm1,0x290(%rsp)
 115b016:	00 00 
 115b018:	c5 fe 7f 84 24 70 02 	vmovdqu %ymm0,0x270(%rsp)
 115b01f:	00 00 
 115b021:	48 8b 84 24 88 00 00 	mov    0x88(%rsp),%rax
 115b028:	00 
 115b029:	c5 fe 6f 10          	vmovdqu (%rax),%ymm2
 115b02d:	c5 fe 6f 58 20       	vmovdqu 0x20(%rax),%ymm3
 115b032:	c5 fe 7f 94 24 50 03 	vmovdqu %ymm2,0x350(%rsp)
 115b039:	00 00 
 115b03b:	c5 fe 7f 9c 24 70 03 	vmovdqu %ymm3,0x370(%rsp)
 115b042:	00 00 
 115b044:	c5 fe 7f 84 24 90 03 	vmovdqu %ymm0,0x390(%rsp)
 115b04b:	00 00 
 115b04d:	c5 fe 7f 8c 24 b0 03 	vmovdqu %ymm1,0x3b0(%rsp)
 115b054:	00 00 
 115b056:	b8 08 00 00 00       	mov    $0x8,%eax
 115b05b:	31 f6                	xor    %esi,%esi
 115b05d:	eb 46                	jmp    115b0a5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x705>
 115b05f:	90                   	nop
 115b060:	45 31 e4             	xor    %r12d,%r12d
 115b063:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115b068:	4c 8b 54 24 18       	mov    0x18(%rsp),%r10
 115b06d:	4c 03 54 24 38       	add    0x38(%rsp),%r10
 115b072:	4c 03 94 24 00 01 00 	add    0x100(%rsp),%r10
 115b079:	00 
 115b07a:	49 01 cf             	add    %rcx,%r15
 115b07d:	4d 01 d7             	add    %r10,%r15
 115b080:	4c 01 c2             	add    %r8,%rdx
 115b083:	4c 01 fa             	add    %r15,%rdx
 115b086:	29 fe                	sub    %edi,%esi
 115b088:	41 0f 42 f5          	cmovb  %r13d,%esi
 115b08c:	4c 01 e6             	add    %r12,%rsi
 115b08f:	48 01 d6             	add    %rdx,%rsi
 115b092:	48 83 c0 10          	add    $0x10,%rax
 115b096:	48 83 f8 48          	cmp    $0x48,%rax
 115b09a:	44 8b 54 24 24       	mov    0x24(%rsp),%r10d
 115b09f:	0f 84 43 02 00 00    	je     115b2e8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x948>
 115b0a5:	48 89 74 24 38       	mov    %rsi,0x38(%rsp)
 115b0aa:	4c 8b a4 04 48 03 00 	mov    0x348(%rsp,%rax,1),%r12
 115b0b1:	00 
 115b0b2:	4c 8b b4 04 50 03 00 	mov    0x350(%rsp,%rax,1),%r14
 115b0b9:	00 
 115b0ba:	4d 89 e3             	mov    %r12,%r11
 115b0bd:	49 c1 eb 20          	shr    $0x20,%r11
 115b0c1:	48 8b 9c 04 88 03 00 	mov    0x388(%rsp,%rax,1),%rbx
 115b0c8:	00 
 115b0c9:	48 8b bc 04 90 03 00 	mov    0x390(%rsp,%rax,1),%rdi
 115b0d0:	00 
 115b0d1:	49 89 d8             	mov    %rbx,%r8
 115b0d4:	49 c1 e8 20          	shr    $0x20,%r8
 115b0d8:	48 89 fe             	mov    %rdi,%rsi
 115b0db:	48 c1 ee 20          	shr    $0x20,%rsi
 115b0df:	45 39 e0             	cmp    %r12d,%r8d
 115b0e2:	76 2c                	jbe    115b110 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x770>
 115b0e4:	44 39 db             	cmp    %r11d,%ebx
 115b0e7:	73 67                	jae    115b150 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7b0>
 115b0e9:	41 89 da             	mov    %ebx,%r10d
 115b0ec:	45 29 e2             	sub    %r12d,%r10d
 115b0ef:	45 0f 42 d5          	cmovb  %r13d,%r10d
 115b0f3:	45 39 c3             	cmp    %r8d,%r11d
 115b0f6:	44 89 c1             	mov    %r8d,%ecx
 115b0f9:	41 0f 42 cb          	cmovb  %r11d,%ecx
 115b0fd:	41 39 cc             	cmp    %ecx,%r12d
 115b100:	41 0f 47 cc          	cmova  %r12d,%ecx
 115b104:	39 f1                	cmp    %esi,%ecx
 115b106:	72 12                	jb     115b11a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x77a>
 115b108:	eb 36                	jmp    115b140 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7a0>
 115b10a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 115b110:	44 89 e1             	mov    %r12d,%ecx
 115b113:	45 31 d2             	xor    %r10d,%r10d
 115b116:	39 f1                	cmp    %esi,%ecx
 115b118:	73 26                	jae    115b140 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7a0>
 115b11a:	44 39 df             	cmp    %r11d,%edi
 115b11d:	73 21                	jae    115b140 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7a0>
 115b11f:	89 fa                	mov    %edi,%edx
 115b121:	29 ca                	sub    %ecx,%edx
 115b123:	41 0f 42 d5          	cmovb  %r13d,%edx
 115b127:	49 01 d2             	add    %rdx,%r10
 115b12a:	4c 89 54 24 18       	mov    %r10,0x18(%rsp)
 115b12f:	41 39 f3             	cmp    %esi,%r11d
 115b132:	89 f2                	mov    %esi,%edx
 115b134:	41 0f 42 d3          	cmovb  %r11d,%edx
 115b138:	39 d1                	cmp    %edx,%ecx
 115b13a:	0f 46 ca             	cmovbe %edx,%ecx
 115b13d:	eb 1d                	jmp    115b15c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7bc>
 115b13f:	90                   	nop
 115b140:	4c 89 54 24 18       	mov    %r10,0x18(%rsp)
 115b145:	eb 15                	jmp    115b15c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x7bc>
 115b147:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 115b14e:	00 00 
 115b150:	44 89 e1             	mov    %r12d,%ecx
 115b153:	48 c7 44 24 18 00 00 	movq   $0x0,0x18(%rsp)
 115b15a:	00 00 
 115b15c:	44 89 da             	mov    %r11d,%edx
 115b15f:	29 ca                	sub    %ecx,%edx
 115b161:	41 0f 42 d5          	cmovb  %r13d,%edx
 115b165:	48 89 94 24 00 01 00 	mov    %rdx,0x100(%rsp)
 115b16c:	00 
 115b16d:	4d 89 f2             	mov    %r14,%r10
 115b170:	49 c1 ea 20          	shr    $0x20,%r10
 115b174:	45 39 f0             	cmp    %r14d,%r8d
 115b177:	76 27                	jbe    115b1a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x800>
 115b179:	44 39 d3             	cmp    %r10d,%ebx
 115b17c:	73 52                	jae    115b1d0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x830>
 115b17e:	41 89 df             	mov    %ebx,%r15d
 115b181:	45 29 f7             	sub    %r14d,%r15d
 115b184:	45 0f 42 fd          	cmovb  %r13d,%r15d
 115b188:	45 39 c2             	cmp    %r8d,%r10d
 115b18b:	44 89 c2             	mov    %r8d,%edx
 115b18e:	41 0f 42 d2          	cmovb  %r10d,%edx
 115b192:	41 39 d6             	cmp    %edx,%r14d
 115b195:	41 0f 47 d6          	cmova  %r14d,%edx
 115b199:	39 f2                	cmp    %esi,%edx
 115b19b:	72 0d                	jb     115b1aa <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x80a>
 115b19d:	eb 37                	jmp    115b1d6 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x836>
 115b19f:	90                   	nop
 115b1a0:	44 89 f2             	mov    %r14d,%edx
 115b1a3:	45 31 ff             	xor    %r15d,%r15d
 115b1a6:	39 f2                	cmp    %esi,%edx
 115b1a8:	73 2c                	jae    115b1d6 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x836>
 115b1aa:	44 39 d7             	cmp    %r10d,%edi
 115b1ad:	73 27                	jae    115b1d6 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x836>
 115b1af:	89 f9                	mov    %edi,%ecx
 115b1b1:	29 d1                	sub    %edx,%ecx
 115b1b3:	41 0f 42 cd          	cmovb  %r13d,%ecx
 115b1b7:	49 01 cf             	add    %rcx,%r15
 115b1ba:	41 39 f2             	cmp    %esi,%r10d
 115b1bd:	89 f1                	mov    %esi,%ecx
 115b1bf:	41 0f 42 ca          	cmovb  %r10d,%ecx
 115b1c3:	39 ca                	cmp    %ecx,%edx
 115b1c5:	0f 46 d1             	cmovbe %ecx,%edx
 115b1c8:	eb 0c                	jmp    115b1d6 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x836>
 115b1ca:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 115b1d0:	44 89 f2             	mov    %r14d,%edx
 115b1d3:	45 31 ff             	xor    %r15d,%r15d
 115b1d6:	44 89 d1             	mov    %r10d,%ecx
 115b1d9:	29 d1                	sub    %edx,%ecx
 115b1db:	41 0f 42 cd          	cmovb  %r13d,%ecx
 115b1df:	41 39 db             	cmp    %ebx,%r11d
 115b1e2:	76 3c                	jbe    115b220 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x880>
 115b1e4:	45 39 e0             	cmp    %r12d,%r8d
 115b1e7:	0f 86 b3 00 00 00    	jbe    115b2a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x900>
 115b1ed:	44 89 e2             	mov    %r12d,%edx
 115b1f0:	29 da                	sub    %ebx,%edx
 115b1f2:	41 0f 42 d5          	cmovb  %r13d,%edx
 115b1f6:	45 39 d8             	cmp    %r11d,%r8d
 115b1f9:	45 89 dd             	mov    %r11d,%r13d
 115b1fc:	45 0f 42 e8          	cmovb  %r8d,%r13d
 115b200:	44 39 eb             	cmp    %r13d,%ebx
 115b203:	44 0f 47 eb          	cmova  %ebx,%r13d
 115b207:	44 89 eb             	mov    %r13d,%ebx
 115b20a:	45 31 ed             	xor    %r13d,%r13d
 115b20d:	45 39 f0             	cmp    %r14d,%r8d
 115b210:	77 15                	ja     115b227 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x887>
 115b212:	eb 4c                	jmp    115b260 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x8c0>
 115b214:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b21b:	00 00 00 00 00 
 115b220:	31 d2                	xor    %edx,%edx
 115b222:	45 39 f0             	cmp    %r14d,%r8d
 115b225:	76 39                	jbe    115b260 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x8c0>
 115b227:	44 39 d3             	cmp    %r10d,%ebx
 115b22a:	73 34                	jae    115b260 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x8c0>
 115b22c:	45 89 f5             	mov    %r14d,%r13d
 115b22f:	41 29 dd             	sub    %ebx,%r13d
 115b232:	41 b9 00 00 00 00    	mov    $0x0,%r9d
 115b238:	45 0f 42 e9          	cmovb  %r9d,%r13d
 115b23c:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115b243:	79 37 9e 
 115b246:	4c 01 ea             	add    %r13,%rdx
 115b249:	45 39 d0             	cmp    %r10d,%r8d
 115b24c:	45 89 d5             	mov    %r10d,%r13d
 115b24f:	45 0f 42 e8          	cmovb  %r8d,%r13d
 115b253:	44 39 eb             	cmp    %r13d,%ebx
 115b256:	44 0f 47 eb          	cmova  %ebx,%r13d
 115b25a:	44 89 eb             	mov    %r13d,%ebx
 115b25d:	45 31 ed             	xor    %r13d,%r13d
 115b260:	41 29 d8             	sub    %ebx,%r8d
 115b263:	45 0f 42 c5          	cmovb  %r13d,%r8d
 115b267:	41 39 fb             	cmp    %edi,%r11d
 115b26a:	76 42                	jbe    115b2ae <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x90e>
 115b26c:	41 39 f4             	cmp    %esi,%r12d
 115b26f:	0f 83 eb fd ff ff    	jae    115b060 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x6c0>
 115b275:	41 29 fc             	sub    %edi,%r12d
 115b278:	45 0f 42 e5          	cmovb  %r13d,%r12d
 115b27c:	44 39 de             	cmp    %r11d,%esi
 115b27f:	44 0f 42 de          	cmovb  %esi,%r11d
 115b283:	44 39 df             	cmp    %r11d,%edi
 115b286:	44 0f 47 df          	cmova  %edi,%r11d
 115b28a:	44 89 df             	mov    %r11d,%edi
 115b28d:	44 39 d7             	cmp    %r10d,%edi
 115b290:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115b295:	72 28                	jb     115b2bf <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x91f>
 115b297:	e9 cc fd ff ff       	jmp    115b068 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x6c8>
 115b29c:	0f 1f 40 00          	nopl   0x0(%rax)
 115b2a0:	31 d2                	xor    %edx,%edx
 115b2a2:	41 29 d8             	sub    %ebx,%r8d
 115b2a5:	45 0f 42 c5          	cmovb  %r13d,%r8d
 115b2a9:	41 39 fb             	cmp    %edi,%r11d
 115b2ac:	77 be                	ja     115b26c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x8cc>
 115b2ae:	45 31 e4             	xor    %r12d,%r12d
 115b2b1:	44 39 d7             	cmp    %r10d,%edi
 115b2b4:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115b2b9:	0f 83 a9 fd ff ff    	jae    115b068 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x6c8>
 115b2bf:	41 39 f6             	cmp    %esi,%r14d
 115b2c2:	0f 83 a0 fd ff ff    	jae    115b068 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x6c8>
 115b2c8:	41 29 fe             	sub    %edi,%r14d
 115b2cb:	45 0f 42 f5          	cmovb  %r13d,%r14d
 115b2cf:	4d 01 f4             	add    %r14,%r12
 115b2d2:	44 39 d6             	cmp    %r10d,%esi
 115b2d5:	44 0f 42 d6          	cmovb  %esi,%r10d
 115b2d9:	44 39 d7             	cmp    %r10d,%edi
 115b2dc:	44 0f 47 d7          	cmova  %edi,%r10d
 115b2e0:	44 89 d7             	mov    %r10d,%edi
 115b2e3:	e9 80 fd ff ff       	jmp    115b068 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x6c8>
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
 115b317:	4c 3b 9c 24 b8 00 00 	cmp    0xb8(%rsp),%r11
 115b31e:	00 
 115b31f:	0f 82 02 fc ff ff    	jb     115af27 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x587>
 115b325:	48 89 c2             	mov    %rax,%rdx
 115b328:	48 8b 84 24 b8 00 00 	mov    0xb8(%rsp),%rax
 115b32f:	00 
 115b330:	48 2b 84 24 f8 00 00 	sub    0xf8(%rsp),%rax
 115b337:	00 
 115b338:	48 39 84 24 98 00 00 	cmp    %rax,0x98(%rsp)
 115b33f:	00 
 115b340:	48 89 d0             	mov    %rdx,%rax
 115b343:	0f 83 d7 fa ff ff    	jae    115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115b349:	e9 d9 fb ff ff       	jmp    115af27 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x587>
 115b34e:	83 e6 fc             	and    $0xfffffffc,%esi
 115b351:	48 8d 3c 09          	lea    (%rcx,%rcx,1),%rdi
 115b355:	44 8d 04 09          	lea    (%rcx,%rcx,1),%r8d
 115b359:	45 31 c9             	xor    %r9d,%r9d
 115b35c:	45 31 d2             	xor    %r10d,%r10d
 115b35f:	4c 8d 9c 24 24 11 00 	lea    0x1124(%rsp),%r11
 115b366:	00 
 115b367:	31 d2                	xor    %edx,%edx
 115b369:	eb 19                	jmp    115b384 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x9e4>
 115b36b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 115b370:	48 83 c2 02          	add    $0x2,%rdx
 115b374:	49 83 c3 20          	add    $0x20,%r11
 115b378:	4d 01 c1             	add    %r8,%r9
 115b37b:	48 39 d6             	cmp    %rdx,%rsi
 115b37e:	0f 84 0f fc ff ff    	je     115af93 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x5f3>
 115b384:	4a 8d 1c 11          	lea    (%rcx,%r10,1),%rbx
 115b388:	4c 8b 7c 24 58       	mov    0x58(%rsp),%r15
 115b38d:	49 39 df             	cmp    %rbx,%r15
 115b390:	49 89 de             	mov    %rbx,%r14
 115b393:	4d 0f 42 f7          	cmovb  %r15,%r14
 115b397:	4d 39 e2             	cmp    %r12,%r10
 115b39a:	73 12                	jae    115b3ae <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa0e>
 115b39c:	45 89 4b e4          	mov    %r9d,-0x1c(%r11)
 115b3a0:	4d 39 e6             	cmp    %r12,%r14
 115b3a3:	4d 89 e7             	mov    %r12,%r15
 115b3a6:	4d 0f 42 fe          	cmovb  %r14,%r15
 115b3aa:	45 89 7b e8          	mov    %r15d,-0x18(%r11)
 115b3ae:	4d 39 e6             	cmp    %r12,%r14
 115b3b1:	76 18                	jbe    115b3cb <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa2b>
 115b3b3:	4d 39 e2             	cmp    %r12,%r10
 115b3b6:	4d 89 e7             	mov    %r12,%r15
 115b3b9:	4d 0f 47 fa          	cmova  %r10,%r15
 115b3bd:	41 01 c7             	add    %eax,%r15d
 115b3c0:	45 89 7b ec          	mov    %r15d,-0x14(%r11)
 115b3c4:	41 01 c6             	add    %eax,%r14d
 115b3c7:	45 89 73 f0          	mov    %r14d,-0x10(%r11)
 115b3cb:	49 01 fa             	add    %rdi,%r10
 115b3ce:	4c 8b 7c 24 58       	mov    0x58(%rsp),%r15
 115b3d3:	4d 39 d7             	cmp    %r10,%r15
 115b3d6:	4d 89 d6             	mov    %r10,%r14
 115b3d9:	4d 0f 42 f7          	cmovb  %r15,%r14
 115b3dd:	4c 39 e3             	cmp    %r12,%rbx
 115b3e0:	73 16                	jae    115b3f8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xa58>
 115b3e2:	46 8d 3c 09          	lea    (%rcx,%r9,1),%r15d
 115b3e6:	45 89 7b f4          	mov    %r15d,-0xc(%r11)
 115b3ea:	4d 39 e6             	cmp    %r12,%r14
 115b3ed:	4d 89 e7             	mov    %r12,%r15
 115b3f0:	4d 0f 42 fe          	cmovb  %r14,%r15
 115b3f4:	45 89 7b f8          	mov    %r15d,-0x8(%r11)
 115b3f8:	4d 39 e6             	cmp    %r12,%r14
 115b3fb:	0f 86 6f ff ff ff    	jbe    115b370 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x9d0>
 115b401:	4c 39 e3             	cmp    %r12,%rbx
 115b404:	49 0f 46 dc          	cmovbe %r12,%rbx
 115b408:	01 c3                	add    %eax,%ebx
 115b40a:	41 89 5b fc          	mov    %ebx,-0x4(%r11)
 115b40e:	41 01 c6             	add    %eax,%r14d
 115b411:	45 89 33             	mov    %r14d,(%r11)
 115b414:	e9 57 ff ff ff       	jmp    115b370 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x9d0>
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
 115b44b:	48 8b 84 24 88 00 00 	mov    0x88(%rsp),%rax
 115b452:	00 
 115b453:	c5 fc 10 00          	vmovups (%rax),%ymm0
 115b457:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 115b45c:	c5 fc 11 8c 24 50 02 	vmovups %ymm1,0x250(%rsp)
 115b463:	00 00 
 115b465:	c5 fc 11 84 24 30 02 	vmovups %ymm0,0x230(%rsp)
 115b46c:	00 00 
 115b46e:	c5 fe 6f 84 24 70 02 	vmovdqu 0x270(%rsp),%ymm0
 115b475:	00 00 
 115b477:	c5 fe 6f 8c 24 90 02 	vmovdqu 0x290(%rsp),%ymm1
 115b47e:	00 00 
 115b480:	c5 fe 7f 84 24 d0 2f 	vmovdqu %ymm0,0x2fd0(%rsp)
 115b487:	00 00 
 115b489:	c5 fe 7f 8c 24 f0 2f 	vmovdqu %ymm1,0x2ff0(%rsp)
 115b490:	00 00 
 115b492:	48 8b 84 24 08 1a 00 	mov    0x1a08(%rsp),%rax
 115b499:	00 
 115b49a:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 115b49f:	31 c9                	xor    %ecx,%ecx
 115b4a1:	eb 22                	jmp    115b4c5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xb25>
 115b4a3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b4aa:	84 00 00 00 00 00 
 115b4b0:	48 8b 8c 24 c0 01 00 	mov    0x1c0(%rsp),%rcx
 115b4b7:	00 
 115b4b8:	48 ff c1             	inc    %rcx
 115b4bb:	48 83 f9 04          	cmp    $0x4,%rcx
 115b4bf:	0f 84 e0 0a 00 00    	je     115bfa5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1605>
 115b4c5:	49 89 c8             	mov    %rcx,%r8
 115b4c8:	49 c1 e0 0a          	shl    $0xa,%r8
 115b4cc:	48 8d 84 24 38 1a 00 	lea    0x1a38(%rsp),%rax
 115b4d3:	00 
 115b4d4:	49 01 c0             	add    %rax,%r8
 115b4d7:	48 89 8c 24 c0 01 00 	mov    %rcx,0x1c0(%rsp)
 115b4de:	00 
 115b4df:	48 c1 e1 04          	shl    $0x4,%rcx
 115b4e3:	48 8b 84 0c 30 02 00 	mov    0x230(%rsp,%rcx,1),%rax
 115b4ea:	00 
 115b4eb:	48 8b bc 0c 38 02 00 	mov    0x238(%rsp,%rcx,1),%rdi
 115b4f2:	00 
 115b4f3:	49 89 c2             	mov    %rax,%r10
 115b4f6:	49 c1 ea 20          	shr    $0x20,%r10
 115b4fa:	48 8b 9c 0c d0 2f 00 	mov    0x2fd0(%rsp,%rcx,1),%rbx
 115b501:	00 
 115b502:	4c 8b 9c 0c d8 2f 00 	mov    0x2fd8(%rsp,%rcx,1),%r11
 115b509:	00 
 115b50a:	48 89 de             	mov    %rbx,%rsi
 115b50d:	48 c1 ee 20          	shr    $0x20,%rsi
 115b511:	4d 89 d9             	mov    %r11,%r9
 115b514:	49 c1 e9 20          	shr    $0x20,%r9
 115b518:	89 c1                	mov    %eax,%ecx
 115b51a:	39 c6                	cmp    %eax,%esi
 115b51c:	4c 89 9c 24 00 01 00 	mov    %r11,0x100(%rsp)
 115b523:	00 
 115b524:	0f 86 dd 00 00 00    	jbe    115b607 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc67>
 115b52a:	89 c1                	mov    %eax,%ecx
 115b52c:	44 39 d3             	cmp    %r10d,%ebx
 115b52f:	0f 83 bb 01 00 00    	jae    115b6f0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd50>
 115b535:	39 c3                	cmp    %eax,%ebx
 115b537:	0f 86 b4 00 00 00    	jbe    115b5f1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc51>
 115b53d:	41 89 c3             	mov    %eax,%r11d
 115b540:	48 89 d9             	mov    %rbx,%rcx
 115b543:	48 29 c1             	sub    %rax,%rcx
 115b546:	89 ca                	mov    %ecx,%edx
 115b548:	48 ff ca             	dec    %rdx
 115b54b:	48 83 fa 07          	cmp    $0x7,%rdx
 115b54f:	73 05                	jae    115b556 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xbb6>
 115b551:	45 31 f6             	xor    %r14d,%r14d
 115b554:	eb 72                	jmp    115b5c8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc28>
 115b556:	48 8b 54 24 18       	mov    0x18(%rsp),%rdx
 115b55b:	4e 8d 3c 1a          	lea    (%rdx,%r11,1),%r15
 115b55f:	41 89 cc             	mov    %ecx,%r12d
 115b562:	41 83 e4 f8          	and    $0xfffffff8,%r12d
 115b566:	49 83 c7 07          	add    $0x7,%r15
 115b56a:	45 31 f6             	xor    %r14d,%r14d
 115b56d:	0f 1f 00             	nopl   (%rax)
 115b570:	43 0f b6 54 37 f9    	movzbl -0x7(%r15,%r14,1),%edx
 115b576:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b57a:	43 0f b6 54 37 fa    	movzbl -0x6(%r15,%r14,1),%edx
 115b580:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b584:	43 0f b6 54 37 fb    	movzbl -0x5(%r15,%r14,1),%edx
 115b58a:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b58e:	43 0f b6 54 37 fc    	movzbl -0x4(%r15,%r14,1),%edx
 115b594:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b598:	43 0f b6 54 37 fd    	movzbl -0x3(%r15,%r14,1),%edx
 115b59e:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b5a2:	43 0f b6 54 37 fe    	movzbl -0x2(%r15,%r14,1),%edx
 115b5a8:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b5ac:	43 0f b6 54 37 ff    	movzbl -0x1(%r15,%r14,1),%edx
 115b5b2:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b5b6:	43 0f b6 14 37       	movzbl (%r15,%r14,1),%edx
 115b5bb:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b5bf:	49 83 c6 08          	add    $0x8,%r14
 115b5c3:	4d 39 f4             	cmp    %r14,%r12
 115b5c6:	75 a8                	jne    115b570 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xbd0>
 115b5c8:	83 e1 07             	and    $0x7,%ecx
 115b5cb:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115b5d0:	74 1f                	je     115b5f1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc51>
 115b5d2:	4d 01 de             	add    %r11,%r14
 115b5d5:	4c 03 74 24 18       	add    0x18(%rsp),%r14
 115b5da:	31 d2                	xor    %edx,%edx
 115b5dc:	0f 1f 40 00          	nopl   0x0(%rax)
 115b5e0:	45 0f b6 1c 16       	movzbl (%r14,%rdx,1),%r11d
 115b5e5:	43 ff 0c 98          	decl   (%r8,%r11,4)
 115b5e9:	48 ff c2             	inc    %rdx
 115b5ec:	48 39 d1             	cmp    %rdx,%rcx
 115b5ef:	75 ef                	jne    115b5e0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc40>
 115b5f1:	41 39 f2             	cmp    %esi,%r10d
 115b5f4:	89 f1                	mov    %esi,%ecx
 115b5f6:	41 0f 42 ca          	cmovb  %r10d,%ecx
 115b5fa:	39 c8                	cmp    %ecx,%eax
 115b5fc:	0f 47 c8             	cmova  %eax,%ecx
 115b5ff:	4c 8b 9c 24 00 01 00 	mov    0x100(%rsp),%r11
 115b606:	00 
 115b607:	44 39 c9             	cmp    %r9d,%ecx
 115b60a:	0f 83 e0 00 00 00    	jae    115b6f0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd50>
 115b610:	45 39 d3             	cmp    %r10d,%r11d
 115b613:	0f 83 d7 00 00 00    	jae    115b6f0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd50>
 115b619:	41 29 cb             	sub    %ecx,%r11d
 115b61c:	0f 86 bf 00 00 00    	jbe    115b6e1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd41>
 115b622:	41 89 ce             	mov    %ecx,%r14d
 115b625:	44 89 da             	mov    %r11d,%edx
 115b628:	ff ca                	dec    %edx
 115b62a:	83 fa 07             	cmp    $0x7,%edx
 115b62d:	73 05                	jae    115b634 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xc94>
 115b62f:	45 31 ff             	xor    %r15d,%r15d
 115b632:	eb 74                	jmp    115b6a8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd08>
 115b634:	48 8b 54 24 18       	mov    0x18(%rsp),%rdx
 115b639:	4e 8d 24 32          	lea    (%rdx,%r14,1),%r12
 115b63d:	45 89 dd             	mov    %r11d,%r13d
 115b640:	41 83 e5 f8          	and    $0xfffffff8,%r13d
 115b644:	49 83 c4 07          	add    $0x7,%r12
 115b648:	45 31 ff             	xor    %r15d,%r15d
 115b64b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 115b650:	43 0f b6 54 3c f9    	movzbl -0x7(%r12,%r15,1),%edx
 115b656:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b65a:	43 0f b6 54 3c fa    	movzbl -0x6(%r12,%r15,1),%edx
 115b660:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b664:	43 0f b6 54 3c fb    	movzbl -0x5(%r12,%r15,1),%edx
 115b66a:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b66e:	43 0f b6 54 3c fc    	movzbl -0x4(%r12,%r15,1),%edx
 115b674:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b678:	43 0f b6 54 3c fd    	movzbl -0x3(%r12,%r15,1),%edx
 115b67e:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b682:	43 0f b6 54 3c fe    	movzbl -0x2(%r12,%r15,1),%edx
 115b688:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b68c:	43 0f b6 54 3c ff    	movzbl -0x1(%r12,%r15,1),%edx
 115b692:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b696:	43 0f b6 14 3c       	movzbl (%r12,%r15,1),%edx
 115b69b:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b69f:	49 83 c7 08          	add    $0x8,%r15
 115b6a3:	4d 39 fd             	cmp    %r15,%r13
 115b6a6:	75 a8                	jne    115b650 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xcb0>
 115b6a8:	41 83 e3 07          	and    $0x7,%r11d
 115b6ac:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115b6b1:	41 bd 00 00 00 00    	mov    $0x0,%r13d
 115b6b7:	74 28                	je     115b6e1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd41>
 115b6b9:	4d 01 f7             	add    %r14,%r15
 115b6bc:	4c 03 7c 24 18       	add    0x18(%rsp),%r15
 115b6c1:	31 d2                	xor    %edx,%edx
 115b6c3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b6ca:	84 00 00 00 00 00 
 115b6d0:	45 0f b6 34 17       	movzbl (%r15,%rdx,1),%r14d
 115b6d5:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b6d9:	48 ff c2             	inc    %rdx
 115b6dc:	49 39 d3             	cmp    %rdx,%r11
 115b6df:	75 ef                	jne    115b6d0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd30>
 115b6e1:	45 39 ca             	cmp    %r9d,%r10d
 115b6e4:	44 89 ca             	mov    %r9d,%edx
 115b6e7:	41 0f 42 d2          	cmovb  %r10d,%edx
 115b6eb:	39 d1                	cmp    %edx,%ecx
 115b6ed:	0f 46 ca             	cmovbe %edx,%ecx
 115b6f0:	45 89 d3             	mov    %r10d,%r11d
 115b6f3:	41 29 cb             	sub    %ecx,%r11d
 115b6f6:	0f 86 b5 00 00 00    	jbe    115b7b1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xe11>
 115b6fc:	89 c9                	mov    %ecx,%ecx
 115b6fe:	44 89 da             	mov    %r11d,%edx
 115b701:	ff ca                	dec    %edx
 115b703:	83 fa 07             	cmp    $0x7,%edx
 115b706:	73 05                	jae    115b70d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd6d>
 115b708:	45 31 f6             	xor    %r14d,%r14d
 115b70b:	eb 7b                	jmp    115b788 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xde8>
 115b70d:	48 8b 54 24 18       	mov    0x18(%rsp),%rdx
 115b712:	4c 8d 3c 0a          	lea    (%rdx,%rcx,1),%r15
 115b716:	45 89 dc             	mov    %r11d,%r12d
 115b719:	41 83 e4 f8          	and    $0xfffffff8,%r12d
 115b71d:	49 83 c7 07          	add    $0x7,%r15
 115b721:	45 31 f6             	xor    %r14d,%r14d
 115b724:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b72b:	00 00 00 00 00 
 115b730:	43 0f b6 54 37 f9    	movzbl -0x7(%r15,%r14,1),%edx
 115b736:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b73a:	43 0f b6 54 37 fa    	movzbl -0x6(%r15,%r14,1),%edx
 115b740:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b744:	43 0f b6 54 37 fb    	movzbl -0x5(%r15,%r14,1),%edx
 115b74a:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b74e:	43 0f b6 54 37 fc    	movzbl -0x4(%r15,%r14,1),%edx
 115b754:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b758:	43 0f b6 54 37 fd    	movzbl -0x3(%r15,%r14,1),%edx
 115b75e:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b762:	43 0f b6 54 37 fe    	movzbl -0x2(%r15,%r14,1),%edx
 115b768:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b76c:	43 0f b6 54 37 ff    	movzbl -0x1(%r15,%r14,1),%edx
 115b772:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b776:	43 0f b6 14 37       	movzbl (%r15,%r14,1),%edx
 115b77b:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b77f:	49 83 c6 08          	add    $0x8,%r14
 115b783:	4d 39 f4             	cmp    %r14,%r12
 115b786:	75 a8                	jne    115b730 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xd90>
 115b788:	41 83 e3 07          	and    $0x7,%r11d
 115b78c:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115b791:	74 1e                	je     115b7b1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xe11>
 115b793:	49 01 ce             	add    %rcx,%r14
 115b796:	4c 03 74 24 18       	add    0x18(%rsp),%r14
 115b79b:	31 c9                	xor    %ecx,%ecx
 115b79d:	0f 1f 00             	nopl   (%rax)
 115b7a0:	41 0f b6 14 0e       	movzbl (%r14,%rcx,1),%edx
 115b7a5:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b7a9:	48 ff c1             	inc    %rcx
 115b7ac:	49 39 cb             	cmp    %rcx,%r11
 115b7af:	75 ef                	jne    115b7a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xe00>
 115b7b1:	49 89 fb             	mov    %rdi,%r11
 115b7b4:	49 c1 eb 20          	shr    $0x20,%r11
 115b7b8:	89 f9                	mov    %edi,%ecx
 115b7ba:	39 fe                	cmp    %edi,%esi
 115b7bc:	0f 86 ed 00 00 00    	jbe    115b8af <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xf0f>
 115b7c2:	89 f9                	mov    %edi,%ecx
 115b7c4:	44 39 db             	cmp    %r11d,%ebx
 115b7c7:	0f 83 e8 01 00 00    	jae    115b9b5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1015>
 115b7cd:	39 fb                	cmp    %edi,%ebx
 115b7cf:	0f 86 cc 00 00 00    	jbe    115b8a1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xf01>
 115b7d5:	41 89 fe             	mov    %edi,%r14d
 115b7d8:	48 89 d9             	mov    %rbx,%rcx
 115b7db:	48 29 f9             	sub    %rdi,%rcx
 115b7de:	89 ca                	mov    %ecx,%edx
 115b7e0:	48 ff ca             	dec    %rdx
 115b7e3:	48 83 fa 07          	cmp    $0x7,%rdx
 115b7e7:	73 05                	jae    115b7ee <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xe4e>
 115b7e9:	45 31 ff             	xor    %r15d,%r15d
 115b7ec:	eb 7a                	jmp    115b868 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xec8>
 115b7ee:	48 8b 54 24 18       	mov    0x18(%rsp),%rdx
 115b7f3:	4e 8d 24 32          	lea    (%rdx,%r14,1),%r12
 115b7f7:	41 89 cd             	mov    %ecx,%r13d
 115b7fa:	41 83 e5 f8          	and    $0xfffffff8,%r13d
 115b7fe:	49 83 c4 07          	add    $0x7,%r12
 115b802:	45 31 ff             	xor    %r15d,%r15d
 115b805:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 115b80c:	00 00 00 00 
 115b810:	43 0f b6 54 3c f9    	movzbl -0x7(%r12,%r15,1),%edx
 115b816:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b81a:	43 0f b6 54 3c fa    	movzbl -0x6(%r12,%r15,1),%edx
 115b820:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b824:	43 0f b6 54 3c fb    	movzbl -0x5(%r12,%r15,1),%edx
 115b82a:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b82e:	43 0f b6 54 3c fc    	movzbl -0x4(%r12,%r15,1),%edx
 115b834:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b838:	43 0f b6 54 3c fd    	movzbl -0x3(%r12,%r15,1),%edx
 115b83e:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b842:	43 0f b6 54 3c fe    	movzbl -0x2(%r12,%r15,1),%edx
 115b848:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b84c:	43 0f b6 54 3c ff    	movzbl -0x1(%r12,%r15,1),%edx
 115b852:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b856:	43 0f b6 14 3c       	movzbl (%r12,%r15,1),%edx
 115b85b:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115b85f:	49 83 c7 08          	add    $0x8,%r15
 115b863:	4d 39 fd             	cmp    %r15,%r13
 115b866:	75 a8                	jne    115b810 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xe70>
 115b868:	83 e1 07             	and    $0x7,%ecx
 115b86b:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115b870:	41 bd 00 00 00 00    	mov    $0x0,%r13d
 115b876:	74 29                	je     115b8a1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xf01>
 115b878:	4d 01 f7             	add    %r14,%r15
 115b87b:	4c 03 7c 24 18       	add    0x18(%rsp),%r15
 115b880:	31 d2                	xor    %edx,%edx
 115b882:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b889:	1f 84 00 00 00 00 00 
 115b890:	45 0f b6 34 17       	movzbl (%r15,%rdx,1),%r14d
 115b895:	43 ff 0c b0          	decl   (%r8,%r14,4)
 115b899:	48 ff c2             	inc    %rdx
 115b89c:	48 39 d1             	cmp    %rdx,%rcx
 115b89f:	75 ef                	jne    115b890 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xef0>
 115b8a1:	41 39 f3             	cmp    %esi,%r11d
 115b8a4:	89 f1                	mov    %esi,%ecx
 115b8a6:	41 0f 42 cb          	cmovb  %r11d,%ecx
 115b8aa:	39 cf                	cmp    %ecx,%edi
 115b8ac:	0f 47 cf             	cmova  %edi,%ecx
 115b8af:	44 39 c9             	cmp    %r9d,%ecx
 115b8b2:	0f 83 fd 00 00 00    	jae    115b9b5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1015>
 115b8b8:	48 8b 94 24 00 01 00 	mov    0x100(%rsp),%rdx
 115b8bf:	00 
 115b8c0:	44 39 da             	cmp    %r11d,%edx
 115b8c3:	0f 83 ec 00 00 00    	jae    115b9b5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1015>
 115b8c9:	29 ca                	sub    %ecx,%edx
 115b8cb:	0f 86 d0 00 00 00    	jbe    115b9a1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1001>
 115b8d1:	41 89 cf             	mov    %ecx,%r15d
 115b8d4:	41 89 d6             	mov    %edx,%r14d
 115b8d7:	41 ff ce             	dec    %r14d
 115b8da:	41 83 fe 07          	cmp    $0x7,%r14d
 115b8de:	4c 89 bc 24 a0 01 00 	mov    %r15,0x1a0(%rsp)
 115b8e5:	00 
 115b8e6:	73 05                	jae    115b8ed <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xf4d>
 115b8e8:	45 31 e4             	xor    %r12d,%r12d
 115b8eb:	eb 7c                	jmp    115b969 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xfc9>
 115b8ed:	4c 8b 74 24 18       	mov    0x18(%rsp),%r14
 115b8f2:	4f 8d 2c 3e          	lea    (%r14,%r15,1),%r13
 115b8f6:	41 89 d6             	mov    %edx,%r14d
 115b8f9:	41 83 e6 f8          	and    $0xfffffff8,%r14d
 115b8fd:	49 83 c5 07          	add    $0x7,%r13
 115b901:	45 31 e4             	xor    %r12d,%r12d
 115b904:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b90b:	00 00 00 00 00 
 115b910:	47 0f b6 7c 25 f9    	movzbl -0x7(%r13,%r12,1),%r15d
 115b916:	43 ff 0c b8          	decl   (%r8,%r15,4)
 115b91a:	47 0f b6 7c 25 fa    	movzbl -0x6(%r13,%r12,1),%r15d
 115b920:	43 ff 0c b8          	decl   (%r8,%r15,4)
 115b924:	47 0f b6 7c 25 fb    	movzbl -0x5(%r13,%r12,1),%r15d
 115b92a:	43 ff 0c b8          	decl   (%r8,%r15,4)
 115b92e:	47 0f b6 7c 25 fc    	movzbl -0x4(%r13,%r12,1),%r15d
 115b934:	43 ff 0c b8          	decl   (%r8,%r15,4)
 115b938:	47 0f b6 7c 25 fd    	movzbl -0x3(%r13,%r12,1),%r15d
 115b93e:	43 ff 0c b8          	decl   (%r8,%r15,4)
 115b942:	47 0f b6 7c 25 fe    	movzbl -0x2(%r13,%r12,1),%r15d
 115b948:	43 ff 0c b8          	decl   (%r8,%r15,4)
 115b94c:	47 0f b6 7c 25 ff    	movzbl -0x1(%r13,%r12,1),%r15d
 115b952:	43 ff 0c b8          	decl   (%r8,%r15,4)
 115b956:	47 0f b6 7c 25 00    	movzbl 0x0(%r13,%r12,1),%r15d
 115b95c:	43 ff 0c b8          	decl   (%r8,%r15,4)
 115b960:	49 83 c4 08          	add    $0x8,%r12
 115b964:	4d 39 e6             	cmp    %r12,%r14
 115b967:	75 a7                	jne    115b910 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xf70>
 115b969:	83 e2 07             	and    $0x7,%edx
 115b96c:	41 bd 00 00 00 00    	mov    $0x0,%r13d
 115b972:	74 2d                	je     115b9a1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1001>
 115b974:	4c 03 a4 24 a0 01 00 	add    0x1a0(%rsp),%r12
 115b97b:	00 
 115b97c:	4c 03 64 24 18       	add    0x18(%rsp),%r12
 115b981:	45 31 f6             	xor    %r14d,%r14d
 115b984:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115b98b:	00 00 00 00 00 
 115b990:	47 0f b6 3c 34       	movzbl (%r12,%r14,1),%r15d
 115b995:	43 ff 0c b8          	decl   (%r8,%r15,4)
 115b999:	49 ff c6             	inc    %r14
 115b99c:	4c 39 f2             	cmp    %r14,%rdx
 115b99f:	75 ef                	jne    115b990 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xff0>
 115b9a1:	45 39 cb             	cmp    %r9d,%r11d
 115b9a4:	44 89 ca             	mov    %r9d,%edx
 115b9a7:	41 0f 42 d3          	cmovb  %r11d,%edx
 115b9ab:	39 d1                	cmp    %edx,%ecx
 115b9ad:	0f 46 ca             	cmovbe %edx,%ecx
 115b9b0:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115b9b5:	45 89 de             	mov    %r11d,%r14d
 115b9b8:	41 29 ce             	sub    %ecx,%r14d
 115b9bb:	0f 86 c0 00 00 00    	jbe    115ba81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x10e1>
 115b9c1:	89 c9                	mov    %ecx,%ecx
 115b9c3:	44 89 f2             	mov    %r14d,%edx
 115b9c6:	ff ca                	dec    %edx
 115b9c8:	83 fa 07             	cmp    $0x7,%edx
 115b9cb:	73 05                	jae    115b9d2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1032>
 115b9cd:	45 31 ff             	xor    %r15d,%r15d
 115b9d0:	eb 76                	jmp    115ba48 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x10a8>
 115b9d2:	48 8b 54 24 18       	mov    0x18(%rsp),%rdx
 115b9d7:	4c 8d 24 0a          	lea    (%rdx,%rcx,1),%r12
 115b9db:	44 89 f2             	mov    %r14d,%edx
 115b9de:	83 e2 f8             	and    $0xfffffff8,%edx
 115b9e1:	49 83 c4 07          	add    $0x7,%r12
 115b9e5:	45 31 ff             	xor    %r15d,%r15d
 115b9e8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 115b9ef:	00 
 115b9f0:	47 0f b6 6c 3c f9    	movzbl -0x7(%r12,%r15,1),%r13d
 115b9f6:	43 ff 0c a8          	decl   (%r8,%r13,4)
 115b9fa:	47 0f b6 6c 3c fa    	movzbl -0x6(%r12,%r15,1),%r13d
 115ba00:	43 ff 0c a8          	decl   (%r8,%r13,4)
 115ba04:	47 0f b6 6c 3c fb    	movzbl -0x5(%r12,%r15,1),%r13d
 115ba0a:	43 ff 0c a8          	decl   (%r8,%r13,4)
 115ba0e:	47 0f b6 6c 3c fc    	movzbl -0x4(%r12,%r15,1),%r13d
 115ba14:	43 ff 0c a8          	decl   (%r8,%r13,4)
 115ba18:	47 0f b6 6c 3c fd    	movzbl -0x3(%r12,%r15,1),%r13d
 115ba1e:	43 ff 0c a8          	decl   (%r8,%r13,4)
 115ba22:	47 0f b6 6c 3c fe    	movzbl -0x2(%r12,%r15,1),%r13d
 115ba28:	43 ff 0c a8          	decl   (%r8,%r13,4)
 115ba2c:	47 0f b6 6c 3c ff    	movzbl -0x1(%r12,%r15,1),%r13d
 115ba32:	43 ff 0c a8          	decl   (%r8,%r13,4)
 115ba36:	47 0f b6 2c 3c       	movzbl (%r12,%r15,1),%r13d
 115ba3b:	43 ff 0c a8          	decl   (%r8,%r13,4)
 115ba3f:	49 83 c7 08          	add    $0x8,%r15
 115ba43:	4c 39 fa             	cmp    %r15,%rdx
 115ba46:	75 a8                	jne    115b9f0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1050>
 115ba48:	41 83 e6 07          	and    $0x7,%r14d
 115ba4c:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115ba51:	41 bd 00 00 00 00    	mov    $0x0,%r13d
 115ba57:	74 28                	je     115ba81 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x10e1>
 115ba59:	49 01 cf             	add    %rcx,%r15
 115ba5c:	4c 03 7c 24 18       	add    0x18(%rsp),%r15
 115ba61:	31 c9                	xor    %ecx,%ecx
 115ba63:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115ba6a:	84 00 00 00 00 00 
 115ba70:	41 0f b6 14 0f       	movzbl (%r15,%rcx,1),%edx
 115ba75:	41 ff 0c 90          	decl   (%r8,%rdx,4)
 115ba79:	48 ff c1             	inc    %rcx
 115ba7c:	49 39 ce             	cmp    %rcx,%r14
 115ba7f:	75 ef                	jne    115ba70 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x10d0>
 115ba81:	41 39 da             	cmp    %ebx,%r10d
 115ba84:	0f 86 e7 00 00 00    	jbe    115bb71 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x11d1>
 115ba8a:	39 c6                	cmp    %eax,%esi
 115ba8c:	0f 86 cf 01 00 00    	jbe    115bc61 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x12c1>
 115ba92:	39 d8                	cmp    %ebx,%eax
 115ba94:	0f 86 c7 00 00 00    	jbe    115bb61 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x11c1>
 115ba9a:	41 89 de             	mov    %ebx,%r14d
 115ba9d:	48 89 c1             	mov    %rax,%rcx
 115baa0:	48 29 d9             	sub    %rbx,%rcx
 115baa3:	89 ca                	mov    %ecx,%edx
 115baa5:	48 ff ca             	dec    %rdx
 115baa8:	48 83 fa 07          	cmp    $0x7,%rdx
 115baac:	73 05                	jae    115bab3 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1113>
 115baae:	45 31 ff             	xor    %r15d,%r15d
 115bab1:	eb 75                	jmp    115bb28 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1188>
 115bab3:	48 8b 54 24 18       	mov    0x18(%rsp),%rdx
 115bab8:	4e 8d 24 32          	lea    (%rdx,%r14,1),%r12
 115babc:	89 ca                	mov    %ecx,%edx
 115babe:	83 e2 f8             	and    $0xfffffff8,%edx
 115bac1:	49 83 c4 07          	add    $0x7,%r12
 115bac5:	45 31 ff             	xor    %r15d,%r15d
 115bac8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 115bacf:	00 
 115bad0:	47 0f b6 6c 3c f9    	movzbl -0x7(%r12,%r15,1),%r13d
 115bad6:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bada:	47 0f b6 6c 3c fa    	movzbl -0x6(%r12,%r15,1),%r13d
 115bae0:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bae4:	47 0f b6 6c 3c fb    	movzbl -0x5(%r12,%r15,1),%r13d
 115baea:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115baee:	47 0f b6 6c 3c fc    	movzbl -0x4(%r12,%r15,1),%r13d
 115baf4:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115baf8:	47 0f b6 6c 3c fd    	movzbl -0x3(%r12,%r15,1),%r13d
 115bafe:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bb02:	47 0f b6 6c 3c fe    	movzbl -0x2(%r12,%r15,1),%r13d
 115bb08:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bb0c:	47 0f b6 6c 3c ff    	movzbl -0x1(%r12,%r15,1),%r13d
 115bb12:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bb16:	47 0f b6 2c 3c       	movzbl (%r12,%r15,1),%r13d
 115bb1b:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bb1f:	49 83 c7 08          	add    $0x8,%r15
 115bb23:	4c 39 fa             	cmp    %r15,%rdx
 115bb26:	75 a8                	jne    115bad0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1130>
 115bb28:	83 e1 07             	and    $0x7,%ecx
 115bb2b:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115bb30:	41 bd 00 00 00 00    	mov    $0x0,%r13d
 115bb36:	74 29                	je     115bb61 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x11c1>
 115bb38:	4d 01 f7             	add    %r14,%r15
 115bb3b:	4c 03 7c 24 18       	add    0x18(%rsp),%r15
 115bb40:	31 d2                	xor    %edx,%edx
 115bb42:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bb49:	1f 84 00 00 00 00 00 
 115bb50:	45 0f b6 34 17       	movzbl (%r15,%rdx,1),%r14d
 115bb55:	43 ff 04 b0          	incl   (%r8,%r14,4)
 115bb59:	48 ff c2             	inc    %rdx
 115bb5c:	48 39 d1             	cmp    %rdx,%rcx
 115bb5f:	75 ef                	jne    115bb50 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x11b0>
 115bb61:	44 39 d6             	cmp    %r10d,%esi
 115bb64:	44 89 d1             	mov    %r10d,%ecx
 115bb67:	0f 42 ce             	cmovb  %esi,%ecx
 115bb6a:	39 cb                	cmp    %ecx,%ebx
 115bb6c:	0f 47 cb             	cmova  %ebx,%ecx
 115bb6f:	89 cb                	mov    %ecx,%ebx
 115bb71:	39 fe                	cmp    %edi,%esi
 115bb73:	0f 86 e8 00 00 00    	jbe    115bc61 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x12c1>
 115bb79:	44 39 db             	cmp    %r11d,%ebx
 115bb7c:	0f 83 df 00 00 00    	jae    115bc61 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x12c1>
 115bb82:	89 f9                	mov    %edi,%ecx
 115bb84:	29 d9                	sub    %ebx,%ecx
 115bb86:	0f 86 c5 00 00 00    	jbe    115bc51 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x12b1>
 115bb8c:	41 89 de             	mov    %ebx,%r14d
 115bb8f:	89 ca                	mov    %ecx,%edx
 115bb91:	ff ca                	dec    %edx
 115bb93:	83 fa 07             	cmp    $0x7,%edx
 115bb96:	73 05                	jae    115bb9d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x11fd>
 115bb98:	45 31 ff             	xor    %r15d,%r15d
 115bb9b:	eb 7b                	jmp    115bc18 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1278>
 115bb9d:	48 8b 54 24 18       	mov    0x18(%rsp),%rdx
 115bba2:	4e 8d 24 32          	lea    (%rdx,%r14,1),%r12
 115bba6:	89 ca                	mov    %ecx,%edx
 115bba8:	83 e2 f8             	and    $0xfffffff8,%edx
 115bbab:	49 83 c4 07          	add    $0x7,%r12
 115bbaf:	45 31 ff             	xor    %r15d,%r15d
 115bbb2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bbb9:	1f 84 00 00 00 00 00 
 115bbc0:	47 0f b6 6c 3c f9    	movzbl -0x7(%r12,%r15,1),%r13d
 115bbc6:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bbca:	47 0f b6 6c 3c fa    	movzbl -0x6(%r12,%r15,1),%r13d
 115bbd0:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bbd4:	47 0f b6 6c 3c fb    	movzbl -0x5(%r12,%r15,1),%r13d
 115bbda:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bbde:	47 0f b6 6c 3c fc    	movzbl -0x4(%r12,%r15,1),%r13d
 115bbe4:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bbe8:	47 0f b6 6c 3c fd    	movzbl -0x3(%r12,%r15,1),%r13d
 115bbee:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bbf2:	47 0f b6 6c 3c fe    	movzbl -0x2(%r12,%r15,1),%r13d
 115bbf8:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bbfc:	47 0f b6 6c 3c ff    	movzbl -0x1(%r12,%r15,1),%r13d
 115bc02:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bc06:	47 0f b6 2c 3c       	movzbl (%r12,%r15,1),%r13d
 115bc0b:	43 ff 04 a8          	incl   (%r8,%r13,4)
 115bc0f:	49 83 c7 08          	add    $0x8,%r15
 115bc13:	4c 39 fa             	cmp    %r15,%rdx
 115bc16:	75 a8                	jne    115bbc0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1220>
 115bc18:	83 e1 07             	and    $0x7,%ecx
 115bc1b:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115bc20:	41 bd 00 00 00 00    	mov    $0x0,%r13d
 115bc26:	74 29                	je     115bc51 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x12b1>
 115bc28:	4d 01 f7             	add    %r14,%r15
 115bc2b:	4c 03 7c 24 18       	add    0x18(%rsp),%r15
 115bc30:	31 d2                	xor    %edx,%edx
 115bc32:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bc39:	1f 84 00 00 00 00 00 
 115bc40:	45 0f b6 34 17       	movzbl (%r15,%rdx,1),%r14d
 115bc45:	43 ff 04 b0          	incl   (%r8,%r14,4)
 115bc49:	48 ff c2             	inc    %rdx
 115bc4c:	48 39 d1             	cmp    %rdx,%rcx
 115bc4f:	75 ef                	jne    115bc40 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x12a0>
 115bc51:	44 39 de             	cmp    %r11d,%esi
 115bc54:	44 89 d9             	mov    %r11d,%ecx
 115bc57:	0f 42 ce             	cmovb  %esi,%ecx
 115bc5a:	39 cb                	cmp    %ecx,%ebx
 115bc5c:	0f 47 cb             	cmova  %ebx,%ecx
 115bc5f:	89 cb                	mov    %ecx,%ebx
 115bc61:	29 de                	sub    %ebx,%esi
 115bc63:	0f 86 a7 00 00 00    	jbe    115bd10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1370>
 115bc69:	89 d9                	mov    %ebx,%ecx
 115bc6b:	89 f2                	mov    %esi,%edx
 115bc6d:	ff ca                	dec    %edx
 115bc6f:	83 fa 07             	cmp    $0x7,%edx
 115bc72:	73 04                	jae    115bc78 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x12d8>
 115bc74:	31 db                	xor    %ebx,%ebx
 115bc76:	eb 70                	jmp    115bce8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1348>
 115bc78:	48 8b 54 24 18       	mov    0x18(%rsp),%rdx
 115bc7d:	4c 8d 34 0a          	lea    (%rdx,%rcx,1),%r14
 115bc81:	89 f2                	mov    %esi,%edx
 115bc83:	83 e2 f8             	and    $0xfffffff8,%edx
 115bc86:	49 83 c6 07          	add    $0x7,%r14
 115bc8a:	31 db                	xor    %ebx,%ebx
 115bc8c:	0f 1f 40 00          	nopl   0x0(%rax)
 115bc90:	45 0f b6 7c 1e f9    	movzbl -0x7(%r14,%rbx,1),%r15d
 115bc96:	43 ff 04 b8          	incl   (%r8,%r15,4)
 115bc9a:	45 0f b6 7c 1e fa    	movzbl -0x6(%r14,%rbx,1),%r15d
 115bca0:	43 ff 04 b8          	incl   (%r8,%r15,4)
 115bca4:	45 0f b6 7c 1e fb    	movzbl -0x5(%r14,%rbx,1),%r15d
 115bcaa:	43 ff 04 b8          	incl   (%r8,%r15,4)
 115bcae:	45 0f b6 7c 1e fc    	movzbl -0x4(%r14,%rbx,1),%r15d
 115bcb4:	43 ff 04 b8          	incl   (%r8,%r15,4)
 115bcb8:	45 0f b6 7c 1e fd    	movzbl -0x3(%r14,%rbx,1),%r15d
 115bcbe:	43 ff 04 b8          	incl   (%r8,%r15,4)
 115bcc2:	45 0f b6 7c 1e fe    	movzbl -0x2(%r14,%rbx,1),%r15d
 115bcc8:	43 ff 04 b8          	incl   (%r8,%r15,4)
 115bccc:	45 0f b6 7c 1e ff    	movzbl -0x1(%r14,%rbx,1),%r15d
 115bcd2:	43 ff 04 b8          	incl   (%r8,%r15,4)
 115bcd6:	45 0f b6 3c 1e       	movzbl (%r14,%rbx,1),%r15d
 115bcdb:	43 ff 04 b8          	incl   (%r8,%r15,4)
 115bcdf:	48 83 c3 08          	add    $0x8,%rbx
 115bce3:	48 39 da             	cmp    %rbx,%rdx
 115bce6:	75 a8                	jne    115bc90 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x12f0>
 115bce8:	83 e6 07             	and    $0x7,%esi
 115bceb:	74 23                	je     115bd10 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1370>
 115bced:	48 01 cb             	add    %rcx,%rbx
 115bcf0:	48 03 5c 24 18       	add    0x18(%rsp),%rbx
 115bcf5:	31 c9                	xor    %ecx,%ecx
 115bcf7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 115bcfe:	00 00 
 115bd00:	0f b6 14 0b          	movzbl (%rbx,%rcx,1),%edx
 115bd04:	41 ff 04 90          	incl   (%r8,%rdx,4)
 115bd08:	48 ff c1             	inc    %rcx
 115bd0b:	48 39 ce             	cmp    %rcx,%rsi
 115bd0e:	75 f0                	jne    115bd00 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1360>
 115bd10:	48 8b 8c 24 00 01 00 	mov    0x100(%rsp),%rcx
 115bd17:	00 
 115bd18:	41 39 ca             	cmp    %ecx,%r10d
 115bd1b:	0f 86 e8 00 00 00    	jbe    115be09 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1469>
 115bd21:	44 39 c8             	cmp    %r9d,%eax
 115bd24:	0f 83 b7 01 00 00    	jae    115bee1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1541>
 115bd2a:	39 c8                	cmp    %ecx,%eax
 115bd2c:	0f 86 be 00 00 00    	jbe    115bdf0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1450>
 115bd32:	48 8b 94 24 00 01 00 	mov    0x100(%rsp),%rdx
 115bd39:	00 
 115bd3a:	89 d1                	mov    %edx,%ecx
 115bd3c:	48 29 d0             	sub    %rdx,%rax
 115bd3f:	89 c2                	mov    %eax,%edx
 115bd41:	48 ff ca             	dec    %rdx
 115bd44:	48 83 fa 07          	cmp    $0x7,%rdx
 115bd48:	73 04                	jae    115bd4e <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x13ae>
 115bd4a:	31 f6                	xor    %esi,%esi
 115bd4c:	eb 7a                	jmp    115bdc8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1428>
 115bd4e:	48 8b 54 24 18       	mov    0x18(%rsp),%rdx
 115bd53:	48 8d 1c 0a          	lea    (%rdx,%rcx,1),%rbx
 115bd57:	89 c2                	mov    %eax,%edx
 115bd59:	83 e2 f8             	and    $0xfffffff8,%edx
 115bd5c:	48 83 c3 07          	add    $0x7,%rbx
 115bd60:	31 f6                	xor    %esi,%esi
 115bd62:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bd69:	1f 84 00 00 00 00 00 
 115bd70:	44 0f b6 74 33 f9    	movzbl -0x7(%rbx,%rsi,1),%r14d
 115bd76:	43 ff 04 b0          	incl   (%r8,%r14,4)
 115bd7a:	44 0f b6 74 33 fa    	movzbl -0x6(%rbx,%rsi,1),%r14d
 115bd80:	43 ff 04 b0          	incl   (%r8,%r14,4)
 115bd84:	44 0f b6 74 33 fb    	movzbl -0x5(%rbx,%rsi,1),%r14d
 115bd8a:	43 ff 04 b0          	incl   (%r8,%r14,4)
 115bd8e:	44 0f b6 74 33 fc    	movzbl -0x4(%rbx,%rsi,1),%r14d
 115bd94:	43 ff 04 b0          	incl   (%r8,%r14,4)
 115bd98:	44 0f b6 74 33 fd    	movzbl -0x3(%rbx,%rsi,1),%r14d
 115bd9e:	43 ff 04 b0          	incl   (%r8,%r14,4)
 115bda2:	44 0f b6 74 33 fe    	movzbl -0x2(%rbx,%rsi,1),%r14d
 115bda8:	43 ff 04 b0          	incl   (%r8,%r14,4)
 115bdac:	44 0f b6 74 33 ff    	movzbl -0x1(%rbx,%rsi,1),%r14d
 115bdb2:	43 ff 04 b0          	incl   (%r8,%r14,4)
 115bdb6:	44 0f b6 34 33       	movzbl (%rbx,%rsi,1),%r14d
 115bdbb:	43 ff 04 b0          	incl   (%r8,%r14,4)
 115bdbf:	48 83 c6 08          	add    $0x8,%rsi
 115bdc3:	48 39 f2             	cmp    %rsi,%rdx
 115bdc6:	75 a8                	jne    115bd70 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x13d0>
 115bdc8:	83 e0 07             	and    $0x7,%eax
 115bdcb:	74 23                	je     115bdf0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1450>
 115bdcd:	48 01 ce             	add    %rcx,%rsi
 115bdd0:	48 03 74 24 18       	add    0x18(%rsp),%rsi
 115bdd5:	31 c9                	xor    %ecx,%ecx
 115bdd7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 115bdde:	00 00 
 115bde0:	0f b6 14 0e          	movzbl (%rsi,%rcx,1),%edx
 115bde4:	41 ff 04 90          	incl   (%r8,%rdx,4)
 115bde8:	48 ff c1             	inc    %rcx
 115bdeb:	48 39 c8             	cmp    %rcx,%rax
 115bdee:	75 f0                	jne    115bde0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1440>
 115bdf0:	45 39 d1             	cmp    %r10d,%r9d
 115bdf3:	45 0f 42 d1          	cmovb  %r9d,%r10d
 115bdf7:	48 8b 84 24 00 01 00 	mov    0x100(%rsp),%rax
 115bdfe:	00 
 115bdff:	44 39 d0             	cmp    %r10d,%eax
 115be02:	44 0f 47 d0          	cmova  %eax,%r10d
 115be06:	44 89 d1             	mov    %r10d,%ecx
 115be09:	44 39 d9             	cmp    %r11d,%ecx
 115be0c:	0f 83 cf 00 00 00    	jae    115bee1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1541>
 115be12:	44 39 cf             	cmp    %r9d,%edi
 115be15:	0f 83 c6 00 00 00    	jae    115bee1 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1541>
 115be1b:	48 89 cb             	mov    %rcx,%rbx
 115be1e:	29 cf                	sub    %ecx,%edi
 115be20:	0f 86 aa 00 00 00    	jbe    115bed0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1530>
 115be26:	89 d8                	mov    %ebx,%eax
 115be28:	89 f9                	mov    %edi,%ecx
 115be2a:	ff c9                	dec    %ecx
 115be2c:	83 f9 07             	cmp    $0x7,%ecx
 115be2f:	73 04                	jae    115be35 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1495>
 115be31:	31 c9                	xor    %ecx,%ecx
 115be33:	eb 73                	jmp    115bea8 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1508>
 115be35:	48 8b 4c 24 18       	mov    0x18(%rsp),%rcx
 115be3a:	48 8d 34 01          	lea    (%rcx,%rax,1),%rsi
 115be3e:	89 fa                	mov    %edi,%edx
 115be40:	83 e2 f8             	and    $0xfffffff8,%edx
 115be43:	48 83 c6 07          	add    $0x7,%rsi
 115be47:	31 c9                	xor    %ecx,%ecx
 115be49:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 115be50:	44 0f b6 54 0e f9    	movzbl -0x7(%rsi,%rcx,1),%r10d
 115be56:	43 ff 04 90          	incl   (%r8,%r10,4)
 115be5a:	44 0f b6 54 0e fa    	movzbl -0x6(%rsi,%rcx,1),%r10d
 115be60:	43 ff 04 90          	incl   (%r8,%r10,4)
 115be64:	44 0f b6 54 0e fb    	movzbl -0x5(%rsi,%rcx,1),%r10d
 115be6a:	43 ff 04 90          	incl   (%r8,%r10,4)
 115be6e:	44 0f b6 54 0e fc    	movzbl -0x4(%rsi,%rcx,1),%r10d
 115be74:	43 ff 04 90          	incl   (%r8,%r10,4)
 115be78:	44 0f b6 54 0e fd    	movzbl -0x3(%rsi,%rcx,1),%r10d
 115be7e:	43 ff 04 90          	incl   (%r8,%r10,4)
 115be82:	44 0f b6 54 0e fe    	movzbl -0x2(%rsi,%rcx,1),%r10d
 115be88:	43 ff 04 90          	incl   (%r8,%r10,4)
 115be8c:	44 0f b6 54 0e ff    	movzbl -0x1(%rsi,%rcx,1),%r10d
 115be92:	43 ff 04 90          	incl   (%r8,%r10,4)
 115be96:	44 0f b6 14 0e       	movzbl (%rsi,%rcx,1),%r10d
 115be9b:	43 ff 04 90          	incl   (%r8,%r10,4)
 115be9f:	48 83 c1 08          	add    $0x8,%rcx
 115bea3:	48 39 ca             	cmp    %rcx,%rdx
 115bea6:	75 a8                	jne    115be50 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x14b0>
 115bea8:	83 e7 07             	and    $0x7,%edi
 115beab:	74 23                	je     115bed0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1530>
 115bead:	48 01 c1             	add    %rax,%rcx
 115beb0:	48 03 4c 24 18       	add    0x18(%rsp),%rcx
 115beb5:	31 c0                	xor    %eax,%eax
 115beb7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 115bebe:	00 00 
 115bec0:	0f b6 14 01          	movzbl (%rcx,%rax,1),%edx
 115bec4:	41 ff 04 90          	incl   (%r8,%rdx,4)
 115bec8:	48 ff c0             	inc    %rax
 115becb:	48 39 c7             	cmp    %rax,%rdi
 115bece:	75 f0                	jne    115bec0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1520>
 115bed0:	45 39 d9             	cmp    %r11d,%r9d
 115bed3:	45 0f 42 d9          	cmovb  %r9d,%r11d
 115bed7:	44 39 db             	cmp    %r11d,%ebx
 115beda:	44 0f 47 db          	cmova  %ebx,%r11d
 115bede:	44 89 d9             	mov    %r11d,%ecx
 115bee1:	41 29 c9             	sub    %ecx,%r9d
 115bee4:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115bee9:	0f 86 c1 f5 ff ff    	jbe    115b4b0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xb10>
 115beef:	89 c8                	mov    %ecx,%eax
 115bef1:	44 89 c9             	mov    %r9d,%ecx
 115bef4:	ff c9                	dec    %ecx
 115bef6:	83 f9 07             	cmp    $0x7,%ecx
 115bef9:	73 04                	jae    115beff <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x155f>
 115befb:	31 c9                	xor    %ecx,%ecx
 115befd:	eb 71                	jmp    115bf70 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x15d0>
 115beff:	48 8b 4c 24 18       	mov    0x18(%rsp),%rcx
 115bf04:	48 8d 14 01          	lea    (%rcx,%rax,1),%rdx
 115bf08:	44 89 ce             	mov    %r9d,%esi
 115bf0b:	83 e6 f8             	and    $0xfffffff8,%esi
 115bf0e:	48 83 c2 07          	add    $0x7,%rdx
 115bf12:	31 c9                	xor    %ecx,%ecx
 115bf14:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bf1b:	00 00 00 00 00 
 115bf20:	0f b6 7c 0a f9       	movzbl -0x7(%rdx,%rcx,1),%edi
 115bf25:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf29:	0f b6 7c 0a fa       	movzbl -0x6(%rdx,%rcx,1),%edi
 115bf2e:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf32:	0f b6 7c 0a fb       	movzbl -0x5(%rdx,%rcx,1),%edi
 115bf37:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf3b:	0f b6 7c 0a fc       	movzbl -0x4(%rdx,%rcx,1),%edi
 115bf40:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf44:	0f b6 7c 0a fd       	movzbl -0x3(%rdx,%rcx,1),%edi
 115bf49:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf4d:	0f b6 7c 0a fe       	movzbl -0x2(%rdx,%rcx,1),%edi
 115bf52:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf56:	0f b6 7c 0a ff       	movzbl -0x1(%rdx,%rcx,1),%edi
 115bf5b:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf5f:	0f b6 3c 0a          	movzbl (%rdx,%rcx,1),%edi
 115bf63:	41 ff 04 b8          	incl   (%r8,%rdi,4)
 115bf67:	48 83 c1 08          	add    $0x8,%rcx
 115bf6b:	48 39 ce             	cmp    %rcx,%rsi
 115bf6e:	75 b0                	jne    115bf20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1580>
 115bf70:	41 83 e1 07          	and    $0x7,%r9d
 115bf74:	0f 84 36 f5 ff ff    	je     115b4b0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xb10>
 115bf7a:	48 01 c1             	add    %rax,%rcx
 115bf7d:	48 03 4c 24 18       	add    0x18(%rsp),%rcx
 115bf82:	31 c0                	xor    %eax,%eax
 115bf84:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 115bf8b:	00 00 00 00 00 
 115bf90:	0f b6 14 01          	movzbl (%rcx,%rax,1),%edx
 115bf94:	41 ff 04 90          	incl   (%r8,%rdx,4)
 115bf98:	48 ff c0             	inc    %rax
 115bf9b:	49 39 c1             	cmp    %rax,%r9
 115bf9e:	75 f0                	jne    115bf90 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x15f0>
 115bfa0:	e9 0b f5 ff ff       	jmp    115b4b0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0xb10>
 115bfa5:	c5 fc 10 84 24 70 02 	vmovups 0x270(%rsp),%ymm0
 115bfac:	00 00 
 115bfae:	c5 fc 10 8c 24 90 02 	vmovups 0x290(%rsp),%ymm1
 115bfb5:	00 00 
 115bfb7:	48 8b 84 24 88 00 00 	mov    0x88(%rsp),%rax
 115bfbe:	00 
 115bfbf:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 115bfc4:	c5 fc 11 00          	vmovups %ymm0,(%rax)
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
 115c002:	48 c7 c0 f8 ff ff ff 	mov    $0xfffffffffffffff8,%rax
 115c009:	31 db                	xor    %ebx,%ebx
 115c00b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 115c010:	c5 fe 6f 84 84 58 1e 	vmovdqu 0x1e58(%rsp,%rax,4),%ymm0
 115c017:	00 00 
 115c019:	c5 fe 6f 8c 84 78 1e 	vmovdqu 0x1e78(%rsp,%rax,4),%ymm1
 115c020:	00 00 
 115c022:	c5 fd fe 84 84 58 1a 	vpaddd 0x1a58(%rsp,%rax,4),%ymm0,%ymm0
 115c029:	00 00 
 115c02b:	c5 fd fe 84 84 58 22 	vpaddd 0x2258(%rsp,%rax,4),%ymm0,%ymm0
 115c032:	00 00 
 115c034:	c5 fd fe 84 84 58 26 	vpaddd 0x2658(%rsp,%rax,4),%ymm0,%ymm0
 115c03b:	00 00 
 115c03d:	c5 fe 7f 84 84 f0 03 	vmovdqu %ymm0,0x3f0(%rsp,%rax,4)
 115c044:	00 00 
 115c046:	c5 fd 76 c4          	vpcmpeqd %ymm4,%ymm0,%ymm0
 115c04a:	c5 fc 50 c8          	vmovmskps %ymm0,%ecx
 115c04e:	81 f1 ff 00 00 00    	xor    $0xff,%ecx
 115c054:	f3 0f b8 c9          	popcnt %ecx,%ecx
 115c058:	c5 f5 fe 84 84 78 1a 	vpaddd 0x1a78(%rsp,%rax,4),%ymm1,%ymm0
 115c05f:	00 00 
 115c061:	c5 fd fe 84 84 78 22 	vpaddd 0x2278(%rsp,%rax,4),%ymm0,%ymm0
 115c068:	00 00 
 115c06a:	48 01 d9             	add    %rbx,%rcx
 115c06d:	c5 fd fe 84 84 78 26 	vpaddd 0x2678(%rsp,%rax,4),%ymm0,%ymm0
 115c074:	00 00 
 115c076:	c5 fe 7f 84 84 10 04 	vmovdqu %ymm0,0x410(%rsp,%rax,4)
 115c07d:	00 00 
 115c07f:	c5 fd 76 c4          	vpcmpeqd %ymm4,%ymm0,%ymm0
 115c083:	c5 fc 50 d0          	vmovmskps %ymm0,%edx
 115c087:	81 f2 ff 00 00 00    	xor    $0xff,%edx
 115c08d:	31 db                	xor    %ebx,%ebx
 115c08f:	f3 0f b8 da          	popcnt %edx,%ebx
 115c093:	48 01 cb             	add    %rcx,%rbx
 115c096:	48 83 c0 10          	add    $0x10,%rax
 115c09a:	48 3d f8 00 00 00    	cmp    $0xf8,%rax
 115c0a0:	0f 82 6a ff ff ff    	jb     115c010 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1670>
 115c0a6:	48 81 fe ff ff 0f 00 	cmp    $0xfffff,%rsi
 115c0ad:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115c0b2:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115c0b7:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115c0bc:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115c0c3:	79 37 9e 
 115c0c6:	44 8b 54 24 24       	mov    0x24(%rsp),%r10d
 115c0cb:	77 0d                	ja     115c0da <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x173a>
 115c0cd:	c6 84 24 f8 10 00 00 	movb   $0x0,0x10f8(%rsp)
 115c0d4:	00 
 115c0d5:	45 84 ed             	test   %r13b,%r13b
 115c0d8:	74 0a                	je     115c0e4 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1744>
 115c0da:	4c 8b 74 24 60       	mov    0x60(%rsp),%r14
 115c0df:	e9 3c ed ff ff       	jmp    115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115c0e4:	4c 8b 74 24 58       	mov    0x58(%rsp),%r14
 115c0e9:	49 81 fe 00 10 00 00 	cmp    $0x1000,%r14
 115c0f0:	b8 03 00 00 00       	mov    $0x3,%eax
 115c0f5:	48 83 d8 00          	sbb    $0x0,%rax
 115c0f9:	49 83 fe 20          	cmp    $0x20,%r14
 115c0fd:	b9 01 00 00 00       	mov    $0x1,%ecx
 115c102:	48 0f 42 c1          	cmovb  %rcx,%rax
 115c106:	48 83 fb 01          	cmp    $0x1,%rbx
 115c10a:	4d 89 f7             	mov    %r14,%r15
 115c10d:	4c 0f 44 fb          	cmove  %rbx,%r15
 115c111:	49 01 c7             	add    %rax,%r15
 115c114:	ba 00 04 00 00       	mov    $0x400,%edx
 115c119:	48 8b bc 24 80 00 00 	mov    0x80(%rsp),%rdi
 115c120:	00 
 115c121:	48 8d b4 24 d0 03 00 	lea    0x3d0(%rsp),%rsi
 115c128:	00 
 115c129:	c5 f8 77             	vzeroupper 
 115c12c:	e8 8f 1e 04 00       	call   119dfc0 <compiler_rt.memcpy.memcpyFast>
 115c131:	4d 89 f0             	mov    %r14,%r8
 115c134:	c4 41 29 ef d2       	vpxor  %xmm10,%xmm10,%xmm10
 115c139:	48 89 9c 24 e0 0c 00 	mov    %rbx,0xce0(%rsp)
 115c140:	00 
 115c141:	4c 89 b4 24 e8 0c 00 	mov    %r14,0xce8(%rsp)
 115c148:	00 
 115c149:	4c 89 bc 24 f0 0c 00 	mov    %r15,0xcf0(%rsp)
 115c150:	00 
 115c151:	80 7c 24 24 00       	cmpb   $0x0,0x24(%rsp)
 115c156:	4c 89 7c 24 38       	mov    %r15,0x38(%rsp)
 115c15b:	0f 84 2b 03 00 00    	je     115c48c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1aec>
 115c161:	48 83 fb 02          	cmp    $0x2,%rbx
 115c165:	0f 82 1c 03 00 00    	jb     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c16b:	49 83 f8 40          	cmp    $0x40,%r8
 115c16f:	0f 82 12 03 00 00    	jb     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c175:	80 bc 24 c0 2f 00 00 	cmpb   $0x0,0x2fc0(%rsp)
 115c17c:	00 
 115c17d:	0f 84 04 03 00 00    	je     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c183:	c5 e9 ef d2          	vpxor  %xmm2,%xmm2,%xmm2
 115c187:	48 c7 c1 f8 ff ff ff 	mov    $0xfffffffffffffff8,%rcx
 115c18e:	31 c0                	xor    %eax,%eax
 115c190:	c5 e1 ef db          	vpxor  %xmm3,%xmm3,%xmm3
 115c194:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 115c198:	c5 f1 ef c9          	vpxor  %xmm1,%xmm1,%xmm1
 115c19c:	c4 e2 7d 35 a4 8c 28 	vpmovzxdq 0xd28(%rsp,%rcx,4),%ymm4
 115c1a3:	0d 00 00 
 115c1a6:	c5 e5 d4 dc          	vpaddq %ymm4,%ymm3,%ymm3
 115c1aa:	c4 e2 7d 35 a4 8c 18 	vpmovzxdq 0xd18(%rsp,%rcx,4),%ymm4
 115c1b1:	0d 00 00 
 115c1b4:	c5 ed d4 d4          	vpaddq %ymm4,%ymm2,%ymm2
 115c1b8:	c5 fe 6f a4 8c 18 0d 	vmovdqu 0xd18(%rsp,%rcx,4),%ymm4
 115c1bf:	00 00 
 115c1c1:	c5 fe 6f ac 8c 38 0d 	vmovdqu 0xd38(%rsp,%rcx,4),%ymm5
 115c1c8:	00 00 
 115c1ca:	c5 fe 6f b4 8c d8 2b 	vmovdqu 0x2bd8(%rsp,%rcx,4),%ymm6
 115c1d1:	00 00 
 115c1d3:	c5 fe 6f bc 8c f8 2b 	vmovdqu 0x2bf8(%rsp,%rcx,4),%ymm7
 115c1da:	00 00 
 115c1dc:	c4 62 4d 3f c4       	vpmaxud %ymm4,%ymm6,%ymm8
 115c1e1:	c5 3d fa c4          	vpsubd %ymm4,%ymm8,%ymm8
 115c1e5:	c4 43 7d 39 c1 01    	vextracti128 $0x1,%ymm8,%xmm9
 115c1eb:	c4 42 7d 35 c9       	vpmovzxdq %xmm9,%ymm9
 115c1f0:	c5 b5 d4 c9          	vpaddq %ymm1,%ymm9,%ymm1
 115c1f4:	c4 42 7d 35 c0       	vpmovzxdq %xmm8,%ymm8
 115c1f9:	c5 bd d4 c0          	vpaddq %ymm0,%ymm8,%ymm0
 115c1fd:	c5 ad 76 e4          	vpcmpeqd %ymm4,%ymm10,%ymm4
 115c201:	c5 ad 76 f6          	vpcmpeqd %ymm6,%ymm10,%ymm6
 115c205:	c5 cd ef e4          	vpxor  %ymm4,%ymm6,%ymm4
 115c209:	c5 fc 50 d4          	vmovmskps %ymm4,%edx
 115c20d:	08 c2                	or     %al,%dl
 115c20f:	c4 e2 7d 35 a4 8c 38 	vpmovzxdq 0xd38(%rsp,%rcx,4),%ymm4
 115c216:	0d 00 00 
 115c219:	c5 ed d4 d4          	vpaddq %ymm4,%ymm2,%ymm2
 115c21d:	c4 e2 7d 35 a4 8c 48 	vpmovzxdq 0xd48(%rsp,%rcx,4),%ymm4
 115c224:	0d 00 00 
 115c227:	c5 e5 d4 dc          	vpaddq %ymm4,%ymm3,%ymm3
 115c22b:	c4 e2 45 3f e5       	vpmaxud %ymm5,%ymm7,%ymm4
 115c230:	c5 dd fa e5          	vpsubd %ymm5,%ymm4,%ymm4
 115c234:	c4 e2 7d 35 f4       	vpmovzxdq %xmm4,%ymm6
 115c239:	c5 fd d4 c6          	vpaddq %ymm6,%ymm0,%ymm0
 115c23d:	c4 e3 7d 39 e4 01    	vextracti128 $0x1,%ymm4,%xmm4
 115c243:	c4 e2 7d 35 e4       	vpmovzxdq %xmm4,%ymm4
 115c248:	c5 f5 d4 cc          	vpaddq %ymm4,%ymm1,%ymm1
 115c24c:	c5 ad 76 e5          	vpcmpeqd %ymm5,%ymm10,%ymm4
 115c250:	c5 ad 76 ef          	vpcmpeqd %ymm7,%ymm10,%ymm5
 115c254:	c5 d5 ef e4          	vpxor  %ymm4,%ymm5,%ymm4
 115c258:	c5 fc 50 c4          	vmovmskps %ymm4,%eax
 115c25c:	08 d0                	or     %dl,%al
 115c25e:	48 83 c1 10          	add    $0x10,%rcx
 115c262:	48 81 f9 f8 00 00 00 	cmp    $0xf8,%rcx
 115c269:	0f 82 2d ff ff ff    	jb     115c19c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x17fc>
 115c26f:	c5 ed d4 d3          	vpaddq %ymm3,%ymm2,%ymm2
 115c273:	c4 e3 7d 39 d3 01    	vextracti128 $0x1,%ymm2,%xmm3
 115c279:	c5 e9 d4 d3          	vpaddq %xmm3,%xmm2,%xmm2
 115c27d:	c5 f9 70 da ee       	vpshufd $0xee,%xmm2,%xmm3
 115c282:	c5 e9 d4 d3          	vpaddq %xmm3,%xmm2,%xmm2
 115c286:	c4 e1 f9 7e d1       	vmovq  %xmm2,%rcx
 115c28b:	48 81 f9 00 00 02 00 	cmp    $0x20000,%rcx
 115c292:	0f 87 ef 01 00 00    	ja     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c298:	c5 fd d4 c1          	vpaddq %ymm1,%ymm0,%ymm0
 115c29c:	c4 e3 7d 39 c1 01    	vextracti128 $0x1,%ymm0,%xmm1
 115c2a2:	c5 f9 d4 c1          	vpaddq %xmm1,%xmm0,%xmm0
 115c2a6:	c5 f9 70 c8 ee       	vpshufd $0xee,%xmm0,%xmm1
 115c2ab:	c5 f9 d4 c1          	vpaddq %xmm1,%xmm0,%xmm0
 115c2af:	c4 e1 f9 7e c2       	vmovq  %xmm0,%rdx
 115c2b4:	84 c0                	test   %al,%al
 115c2b6:	0f 94 84 24 f8 10 00 	sete   0x10f8(%rsp)
 115c2bd:	00 
 115c2be:	48 89 d0             	mov    %rdx,%rax
 115c2c1:	48 c1 e8 20          	shr    $0x20,%rax
 115c2c5:	0f 85 bc 01 00 00    	jne    115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c2cb:	0f b6 84 24 f8 10 00 	movzbl 0x10f8(%rsp),%eax
 115c2d2:	00 
 115c2d3:	24 01                	and    $0x1,%al
 115c2d5:	88 84 24 d0 2f 00 00 	mov    %al,0x2fd0(%rsp)
 115c2dc:	0f 84 a5 01 00 00    	je     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c2e2:	48 8b 84 24 b0 2b 00 	mov    0x2bb0(%rsp),%rax
 115c2e9:	00 
 115c2ea:	48 85 c0             	test   %rax,%rax
 115c2ed:	0f 88 94 01 00 00    	js     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c2f3:	45 84 ed             	test   %r13b,%r13b
 115c2f6:	0f 85 8b 01 00 00    	jne    115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c2fc:	8b b4 24 b8 2f 00 00 	mov    0x2fb8(%rsp),%esi
 115c303:	48 89 cf             	mov    %rcx,%rdi
 115c306:	48 29 f7             	sub    %rsi,%rdi
 115c309:	48 01 f8             	add    %rdi,%rax
 115c30c:	0f 90 84 24 f8 10 00 	seto   0x10f8(%rsp)
 115c313:	00 
 115c314:	0f 80 6d 01 00 00    	jo     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c31a:	48 01 d2             	add    %rdx,%rdx
 115c31d:	48 8d 14 92          	lea    (%rdx,%rdx,4),%rdx
 115c321:	48 29 d0             	sub    %rdx,%rax
 115c324:	0f 80 5d 01 00 00    	jo     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c32a:	f6 84 24 d0 2f 00 00 	testb  $0x1,0x2fd0(%rsp)
 115c331:	01 
 115c332:	0f 84 4f 01 00 00    	je     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c338:	c6 84 24 f8 10 00 00 	movb   $0x0,0x10f8(%rsp)
 115c33f:	00 
 115c340:	45 84 ed             	test   %r13b,%r13b
 115c343:	74 12                	je     115c357 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x19b7>
 115c345:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115c34a:	45 31 ed             	xor    %r13d,%r13d
 115c34d:	4c 8b 44 24 58       	mov    0x58(%rsp),%r8
 115c352:	e9 30 01 00 00       	jmp    115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c357:	48 39 c1             	cmp    %rax,%rcx
 115c35a:	48 0f 4f c1          	cmovg  %rcx,%rax
 115c35e:	31 c9                	xor    %ecx,%ecx
 115c360:	4c 8b 44 24 58       	mov    0x58(%rsp),%r8
 115c365:	49 81 f8 00 04 00 00 	cmp    $0x400,%r8
 115c36c:	0f 93 c1             	setae  %cl
 115c36f:	48 8d 0c 49          	lea    (%rcx,%rcx,2),%rcx
 115c373:	48 01 c8             	add    %rcx,%rax
 115c376:	48 83 c0 08          	add    $0x8,%rax
 115c37a:	48 c1 e8 03          	shr    $0x3,%rax
 115c37e:	4c 8d 70 06          	lea    0x6(%rax),%r14
 115c382:	41 bf 05 00 00 00    	mov    $0x5,%r15d
 115c388:	49 81 f8 00 04 00 00 	cmp    $0x400,%r8
 115c38f:	4c 0f 42 f0          	cmovb  %rax,%r14
 115c393:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115c398:	41 bd 00 00 00 00    	mov    $0x0,%r13d
 115c39e:	72 22                	jb     115c3c2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1a22>
 115c3a0:	41 bf 06 00 00 00    	mov    $0x6,%r15d
 115c3a6:	49 81 f8 00 40 00 00 	cmp    $0x4000,%r8
 115c3ad:	72 13                	jb     115c3c2 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1a22>
 115c3af:	41 bf 07 00 00 00    	mov    $0x7,%r15d
 115c3b5:	49 81 f8 ff ff 03 00 	cmp    $0x3ffff,%r8
 115c3bc:	0f 87 c5 00 00 00    	ja     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c3c2:	45 84 ed             	test   %r13b,%r13b
 115c3c5:	0f 85 bc 00 00 00    	jne    115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c3cb:	45 84 ed             	test   %r13b,%r13b
 115c3ce:	0f 85 b3 00 00 00    	jne    115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c3d4:	48 8d bc 24 d0 03 00 	lea    0x3d0(%rsp),%rdi
 115c3db:	00 
 115c3dc:	48 8b b4 24 a8 00 00 	mov    0xa8(%rsp),%rsi
 115c3e3:	00 
 115c3e4:	48 8b 94 24 98 00 00 	mov    0x98(%rsp),%rdx
 115c3eb:	00 
 115c3ec:	48 8b 4c 24 68       	mov    0x68(%rsp),%rcx
 115c3f1:	c5 f8 77             	vzeroupper 
 115c3f4:	e8 47 17 00 00       	call   115db40 <zstd.literals.winner_cost_cache.CacheWithAccounting(zstd.SingleLiteralCostCodec,.prune,false).sequenceBase>
 115c3f9:	4c 8b 44 24 58       	mov    0x58(%rsp),%r8
 115c3fe:	80 bc 24 d8 03 00 00 	cmpb   $0x0,0x3d8(%rsp)
 115c405:	00 
 115c406:	74 7f                	je     115c487 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ae7>
 115c408:	4d 01 fe             	add    %r15,%r14
 115c40b:	48 8b 44 24 38       	mov    0x38(%rsp),%rax
 115c410:	4c 39 f0             	cmp    %r14,%rax
 115c413:	4c 0f 42 f0          	cmovb  %rax,%r14
 115c417:	4c 03 b4 24 d0 03 00 	add    0x3d0(%rsp),%r14
 115c41e:	00 
 115c41f:	0f 92 84 24 f8 10 00 	setb   0x10f8(%rsp)
 115c426:	00 
 115c427:	0f 82 18 ff ff ff    	jb     115c345 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x19a5>
 115c42d:	4c 3b b4 24 90 00 00 	cmp    0x90(%rsp),%r14
 115c434:	00 
 115c435:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115c43a:	41 bd 00 00 00 00    	mov    $0x0,%r13d
 115c440:	4c 8b 74 24 60       	mov    0x60(%rsp),%r14
 115c445:	44 8b 54 24 24       	mov    0x24(%rsp),%r10d
 115c44a:	4c 8b 44 24 58       	mov    0x58(%rsp),%r8
 115c44f:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 115c454:	72 36                	jb     115c48c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1aec>
 115c456:	75 0c                	jne    115c464 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1ac4>
 115c458:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 115c45d:	48 39 44 24 40       	cmp    %rax,0x40(%rsp)
 115c462:	72 28                	jb     115c48c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1aec>
 115c464:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115c469:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115c46e:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115c473:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115c47a:	79 37 9e 
 115c47d:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115c482:	e9 99 e9 ff ff       	jmp    115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115c487:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 115c48c:	48 83 fb 02          	cmp    $0x2,%rbx
 115c490:	0f 82 b6 01 00 00    	jb     115c64c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1cac>
 115c496:	49 83 f8 40          	cmp    $0x40,%r8
 115c49a:	0f 82 ac 01 00 00    	jb     115c64c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1cac>
 115c4a0:	ba 00 04 00 00       	mov    $0x400,%edx
 115c4a5:	48 8b bc 24 f0 00 00 	mov    0xf0(%rsp),%rdi
 115c4ac:	00 
 115c4ad:	48 8b b4 24 80 00 00 	mov    0x80(%rsp),%rsi
 115c4b4:	00 
 115c4b5:	c5 f8 77             	vzeroupper 
 115c4b8:	e8 03 1b 04 00       	call   119dfc0 <compiler_rt.memcpy.memcpyFast>
 115c4bd:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 115c4c4:	00 
 115c4c5:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 115c4c9:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 115c4cd:	c5 fe 7f 40 20       	vmovdqu %ymm0,0x20(%rax)
 115c4d2:	c5 fe 7f 40 40       	vmovdqu %ymm0,0x40(%rax)
 115c4d7:	c5 fe 7f 40 60       	vmovdqu %ymm0,0x60(%rax)
 115c4dc:	c5 fe 7f 80 80 00 00 	vmovdqu %ymm0,0x80(%rax)
 115c4e3:	00 
 115c4e4:	c5 fe 7f 80 a0 00 00 	vmovdqu %ymm0,0xa0(%rax)
 115c4eb:	00 
 115c4ec:	c5 fe 7f 80 c0 00 00 	vmovdqu %ymm0,0xc0(%rax)
 115c4f3:	00 
 115c4f4:	c5 fe 7f 80 e0 00 00 	vmovdqu %ymm0,0xe0(%rax)
 115c4fb:	00 
 115c4fc:	c5 fe 7f 80 00 01 00 	vmovdqu %ymm0,0x100(%rax)
 115c503:	00 
 115c504:	c5 fe 7f 80 20 01 00 	vmovdqu %ymm0,0x120(%rax)
 115c50b:	00 
 115c50c:	c5 fe 7f 80 40 01 00 	vmovdqu %ymm0,0x140(%rax)
 115c513:	00 
 115c514:	c5 fe 7f 80 60 01 00 	vmovdqu %ymm0,0x160(%rax)
 115c51b:	00 
 115c51c:	c5 fe 7f 80 80 01 00 	vmovdqu %ymm0,0x180(%rax)
 115c523:	00 
 115c524:	c5 fe 7f 80 a0 01 00 	vmovdqu %ymm0,0x1a0(%rax)
 115c52b:	00 
 115c52c:	c5 fe 7f 80 c0 01 00 	vmovdqu %ymm0,0x1c0(%rax)
 115c533:	00 
 115c534:	c5 fe 7f 80 e0 01 00 	vmovdqu %ymm0,0x1e0(%rax)
 115c53b:	00 
 115c53c:	48 c7 84 24 d0 03 00 	movq   $0x0,0x3d0(%rsp)
 115c543:	00 00 00 00 00 
 115c548:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 115c54f:	00 
 115c550:	c5 fe 7f 80 e0 00 00 	vmovdqu %ymm0,0xe0(%rax)
 115c557:	00 
 115c558:	c5 fe 7f 80 c0 00 00 	vmovdqu %ymm0,0xc0(%rax)
 115c55f:	00 
 115c560:	c5 fe 7f 80 a0 00 00 	vmovdqu %ymm0,0xa0(%rax)
 115c567:	00 
 115c568:	c5 fe 7f 80 80 00 00 	vmovdqu %ymm0,0x80(%rax)
 115c56f:	00 
 115c570:	c5 fe 7f 40 60       	vmovdqu %ymm0,0x60(%rax)
 115c575:	c5 fe 7f 40 40       	vmovdqu %ymm0,0x40(%rax)
 115c57a:	c5 fe 7f 40 20       	vmovdqu %ymm0,0x20(%rax)
 115c57f:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 115c583:	66 c7 80 00 01 00 00 	movw   $0x0,0x100(%rax)
 115c58a:	00 00 
 115c58c:	31 c9                	xor    %ecx,%ecx
 115c58e:	31 c0                	xor    %eax,%eax
 115c590:	48 8d bc 24 d0 03 00 	lea    0x3d0(%rsp),%rdi
 115c597:	00 
 115c598:	eb 10                	jmp    115c5aa <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1c0a>
 115c59a:	48 83 c0 04          	add    $0x4,%rax
 115c59e:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 115c5a4:	0f 84 b7 00 00 00    	je     115c661 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1cc1>
 115c5aa:	83 bc 84 f8 0c 00 00 	cmpl   $0x0,0xcf8(%rsp,%rax,4)
 115c5b1:	00 
 115c5b2:	74 1a                	je     115c5ce <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1c2e>
 115c5b4:	88 84 0c d8 09 00 00 	mov    %al,0x9d8(%rsp,%rcx,1)
 115c5bb:	48 8b 8c 24 d0 03 00 	mov    0x3d0(%rsp),%rcx
 115c5c2:	00 
 115c5c3:	48 ff c1             	inc    %rcx
 115c5c6:	48 89 8c 24 d0 03 00 	mov    %rcx,0x3d0(%rsp)
 115c5cd:	00 
 115c5ce:	83 bc 84 fc 0c 00 00 	cmpl   $0x0,0xcfc(%rsp,%rax,4)
 115c5d5:	00 
 115c5d6:	74 1d                	je     115c5f5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1c55>
 115c5d8:	8d 50 01             	lea    0x1(%rax),%edx
 115c5db:	88 94 0c d8 09 00 00 	mov    %dl,0x9d8(%rsp,%rcx,1)
 115c5e2:	48 8b 8c 24 d0 03 00 	mov    0x3d0(%rsp),%rcx
 115c5e9:	00 
 115c5ea:	48 ff c1             	inc    %rcx
 115c5ed:	48 89 8c 24 d0 03 00 	mov    %rcx,0x3d0(%rsp)
 115c5f4:	00 
 115c5f5:	83 bc 84 00 0d 00 00 	cmpl   $0x0,0xd00(%rsp,%rax,4)
 115c5fc:	00 
 115c5fd:	74 1d                	je     115c61c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1c7c>
 115c5ff:	8d 50 02             	lea    0x2(%rax),%edx
 115c602:	88 94 0c d8 09 00 00 	mov    %dl,0x9d8(%rsp,%rcx,1)
 115c609:	48 8b 8c 24 d0 03 00 	mov    0x3d0(%rsp),%rcx
 115c610:	00 
 115c611:	48 ff c1             	inc    %rcx
 115c614:	48 89 8c 24 d0 03 00 	mov    %rcx,0x3d0(%rsp)
 115c61b:	00 
 115c61c:	83 bc 84 04 0d 00 00 	cmpl   $0x0,0xd04(%rsp,%rax,4)
 115c623:	00 
 115c624:	0f 84 70 ff ff ff    	je     115c59a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1bfa>
 115c62a:	8d 50 03             	lea    0x3(%rax),%edx
 115c62d:	88 94 0c d8 09 00 00 	mov    %dl,0x9d8(%rsp,%rcx,1)
 115c634:	48 8b 8c 24 d0 03 00 	mov    0x3d0(%rsp),%rcx
 115c63b:	00 
 115c63c:	48 ff c1             	inc    %rcx
 115c63f:	48 89 8c 24 d0 03 00 	mov    %rcx,0x3d0(%rsp)
 115c646:	00 
 115c647:	e9 4e ff ff ff       	jmp    115c59a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1bfa>
 115c64c:	b0 01                	mov    $0x1,%al
 115c64e:	89 44 24 18          	mov    %eax,0x18(%rsp)
 115c652:	31 db                	xor    %ebx,%ebx
 115c654:	48 8d bc 24 d0 03 00 	lea    0x3d0(%rsp),%rdi
 115c65b:	00 
 115c65c:	e9 26 04 00 00       	jmp    115ca87 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x20e7>
 115c661:	49 89 ff             	mov    %rdi,%r15
 115c664:	c5 f8 77             	vzeroupper 
 115c667:	e8 34 e4 fb ff       	call   111aaa0 <zstd.finalizeSmallHuffmanLiteralPlan>
 115c66c:	84 c0                	test   %al,%al
 115c66e:	0f 84 ff 03 00 00    	je     115ca73 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x20d3>
 115c674:	b0 01                	mov    $0x1,%al
 115c676:	89 44 24 18          	mov    %eax,0x18(%rsp)
 115c67a:	ba 10 09 00 00       	mov    $0x910,%edx
 115c67f:	48 8d 9c 24 d0 2f 00 	lea    0x2fd0(%rsp),%rbx
 115c686:	00 
 115c687:	48 89 df             	mov    %rbx,%rdi
 115c68a:	4c 89 fe             	mov    %r15,%rsi
 115c68d:	e8 2e 19 04 00       	call   119dfc0 <compiler_rt.memcpy.memcpyFast>
 115c692:	ba 10 09 00 00       	mov    $0x910,%edx
 115c697:	48 8d bc 24 f8 10 00 	lea    0x10f8(%rsp),%rdi
 115c69e:	00 
 115c69f:	48 89 de             	mov    %rbx,%rsi
 115c6a2:	e8 19 19 04 00       	call   119dfc0 <compiler_rt.memcpy.memcpyFast>
 115c6a7:	0f b6 9c 24 00 1a 00 	movzbl 0x1a00(%rsp),%ebx
 115c6ae:	00 
 115c6af:	44 0f b6 b4 24 01 1a 	movzbl 0x1a01(%rsp),%r14d
 115c6b6:	00 00 
 115c6b8:	41 80 e6 0f          	and    $0xf,%r14b
 115c6bc:	c5 fe 6f 8c 24 00 19 	vmovdqu 0x1900(%rsp),%ymm1
 115c6c3:	00 00 
 115c6c5:	c5 fe 6f 94 24 20 19 	vmovdqu 0x1920(%rsp),%ymm2
 115c6cc:	00 00 
 115c6ce:	c5 fe 6f 9c 24 40 19 	vmovdqu 0x1940(%rsp),%ymm3
 115c6d5:	00 00 
 115c6d7:	c5 fc 10 84 24 60 19 	vmovups 0x1960(%rsp),%ymm0
 115c6de:	00 00 
 115c6e0:	c5 fc 29 84 24 00 01 	vmovaps %ymm0,0x100(%rsp)
 115c6e7:	00 00 
 115c6e9:	c5 fc 10 84 24 80 19 	vmovups 0x1980(%rsp),%ymm0
 115c6f0:	00 00 
 115c6f2:	c5 fc 29 84 24 c0 01 	vmovaps %ymm0,0x1c0(%rsp)
 115c6f9:	00 00 
 115c6fb:	c5 fc 10 84 24 a0 19 	vmovups 0x19a0(%rsp),%ymm0
 115c702:	00 00 
 115c704:	c5 fc 29 84 24 a0 01 	vmovaps %ymm0,0x1a0(%rsp)
 115c70b:	00 00 
 115c70d:	c5 fc 10 84 24 c0 19 	vmovups 0x19c0(%rsp),%ymm0
 115c714:	00 00 
 115c716:	c5 fc 29 84 24 60 01 	vmovaps %ymm0,0x160(%rsp)
 115c71d:	00 00 
 115c71f:	c5 fe 6f 84 24 e0 19 	vmovdqu 0x19e0(%rsp),%ymm0
 115c726:	00 00 
 115c728:	c5 fd 7f 84 24 80 01 	vmovdqa %ymm0,0x180(%rsp)
 115c72f:	00 00 
 115c731:	80 bc 24 a0 2b 00 00 	cmpb   $0x0,0x2ba0(%rsp)
 115c738:	00 
 115c739:	4c 89 ff             	mov    %r15,%rdi
 115c73c:	0f 84 e8 00 00 00    	je     115c82a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8a>
 115c742:	38 9c 24 98 2a 00 00 	cmp    %bl,0x2a98(%rsp)
 115c749:	0f 85 db 00 00 00    	jne    115c82a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8a>
 115c74f:	44 38 b4 24 99 2a 00 	cmp    %r14b,0x2a99(%rsp)
 115c756:	00 
 115c757:	0f 85 cd 00 00 00    	jne    115c82a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8a>
 115c75d:	c5 f5 ef 84 24 9a 2a 	vpxor  0x2a9a(%rsp),%ymm1,%ymm0
 115c764:	00 00 
 115c766:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c76b:	0f 85 b9 00 00 00    	jne    115c82a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8a>
 115c771:	c5 ed ef 84 24 ba 2a 	vpxor  0x2aba(%rsp),%ymm2,%ymm0
 115c778:	00 00 
 115c77a:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c77f:	0f 85 a5 00 00 00    	jne    115c82a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8a>
 115c785:	c5 e5 ef 84 24 da 2a 	vpxor  0x2ada(%rsp),%ymm3,%ymm0
 115c78c:	00 00 
 115c78e:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c793:	0f 85 91 00 00 00    	jne    115c82a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8a>
 115c799:	c5 fd 6f 84 24 00 01 	vmovdqa 0x100(%rsp),%ymm0
 115c7a0:	00 00 
 115c7a2:	c5 fd ef 84 24 fa 2a 	vpxor  0x2afa(%rsp),%ymm0,%ymm0
 115c7a9:	00 00 
 115c7ab:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c7b0:	75 78                	jne    115c82a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8a>
 115c7b2:	c5 fd 6f 84 24 c0 01 	vmovdqa 0x1c0(%rsp),%ymm0
 115c7b9:	00 00 
 115c7bb:	c5 fd ef 84 24 1a 2b 	vpxor  0x2b1a(%rsp),%ymm0,%ymm0
 115c7c2:	00 00 
 115c7c4:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c7c9:	75 5f                	jne    115c82a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8a>
 115c7cb:	c5 fd 6f 84 24 a0 01 	vmovdqa 0x1a0(%rsp),%ymm0
 115c7d2:	00 00 
 115c7d4:	c5 fd ef 84 24 3a 2b 	vpxor  0x2b3a(%rsp),%ymm0,%ymm0
 115c7db:	00 00 
 115c7dd:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c7e2:	75 46                	jne    115c82a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8a>
 115c7e4:	c5 fd 6f 84 24 60 01 	vmovdqa 0x160(%rsp),%ymm0
 115c7eb:	00 00 
 115c7ed:	c5 fd ef 84 24 5a 2b 	vpxor  0x2b5a(%rsp),%ymm0,%ymm0
 115c7f4:	00 00 
 115c7f6:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c7fb:	75 2d                	jne    115c82a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1e8a>
 115c7fd:	c5 fd 6f 84 24 80 01 	vmovdqa 0x180(%rsp),%ymm0
 115c804:	00 00 
 115c806:	c5 fd ef 84 24 7a 2b 	vpxor  0x2b7a(%rsp),%ymm0,%ymm0
 115c80d:	00 00 
 115c80f:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 115c814:	48 8b 8c 24 c8 00 00 	mov    0xc8(%rsp),%rcx
 115c81b:	00 
 115c81c:	48 8b 84 24 a0 00 00 	mov    0xa0(%rsp),%rax
 115c823:	00 
 115c824:	0f 84 07 01 00 00    	je     115c931 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1f91>
 115c82a:	c5 fd 7f 9c 24 e0 02 	vmovdqa %ymm3,0x2e0(%rsp)
 115c831:	00 00 
 115c833:	c5 fd 7f 94 24 00 03 	vmovdqa %ymm2,0x300(%rsp)
 115c83a:	00 00 
 115c83c:	c5 fd 7f 8c 24 20 03 	vmovdqa %ymm1,0x320(%rsp)
 115c843:	00 00 
 115c845:	49 89 ff             	mov    %rdi,%r15
 115c848:	48 8d b4 24 d0 2f 00 	lea    0x2fd0(%rsp),%rsi
 115c84f:	00 
 115c850:	c5 f8 77             	vzeroupper 
 115c853:	e8 08 79 ff ff       	call   1154160 <zstd.smallHuffmanTreeSerializedLen>
 115c858:	66 83 bc 24 e0 03 00 	cmpw   $0x0,0x3e0(%rsp)
 115c85f:	00 00 
 115c861:	0f 85 92 05 00 00    	jne    115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c867:	c6 84 24 a0 2b 00 00 	movb   $0x1,0x2ba0(%rsp)
 115c86e:	01 
 115c86f:	88 9c 24 98 2a 00 00 	mov    %bl,0x2a98(%rsp)
 115c876:	44 88 b4 24 99 2a 00 	mov    %r14b,0x2a99(%rsp)
 115c87d:	00 
 115c87e:	c5 fc 28 84 24 20 03 	vmovaps 0x320(%rsp),%ymm0
 115c885:	00 00 
 115c887:	c5 fc 11 84 24 9a 2a 	vmovups %ymm0,0x2a9a(%rsp)
 115c88e:	00 00 
 115c890:	c5 fc 28 84 24 00 03 	vmovaps 0x300(%rsp),%ymm0
 115c897:	00 00 
 115c899:	c5 fc 11 84 24 ba 2a 	vmovups %ymm0,0x2aba(%rsp)
 115c8a0:	00 00 
 115c8a2:	c5 fc 28 84 24 e0 02 	vmovaps 0x2e0(%rsp),%ymm0
 115c8a9:	00 00 
 115c8ab:	c5 fc 11 84 24 da 2a 	vmovups %ymm0,0x2ada(%rsp)
 115c8b2:	00 00 
 115c8b4:	c5 fc 28 84 24 00 01 	vmovaps 0x100(%rsp),%ymm0
 115c8bb:	00 00 
 115c8bd:	c5 fc 11 84 24 fa 2a 	vmovups %ymm0,0x2afa(%rsp)
 115c8c4:	00 00 
 115c8c6:	c5 fc 28 84 24 c0 01 	vmovaps 0x1c0(%rsp),%ymm0
 115c8cd:	00 00 
 115c8cf:	c5 fc 11 84 24 1a 2b 	vmovups %ymm0,0x2b1a(%rsp)
 115c8d6:	00 00 
 115c8d8:	c5 fc 28 84 24 a0 01 	vmovaps 0x1a0(%rsp),%ymm0
 115c8df:	00 00 
 115c8e1:	c5 fc 11 84 24 3a 2b 	vmovups %ymm0,0x2b3a(%rsp)
 115c8e8:	00 00 
 115c8ea:	c5 fc 28 84 24 60 01 	vmovaps 0x160(%rsp),%ymm0
 115c8f1:	00 00 
 115c8f3:	c5 fc 11 84 24 5a 2b 	vmovups %ymm0,0x2b5a(%rsp)
 115c8fa:	00 00 
 115c8fc:	c5 fc 28 84 24 80 01 	vmovaps 0x180(%rsp),%ymm0
 115c903:	00 00 
 115c905:	c5 fc 11 84 24 7a 2b 	vmovups %ymm0,0x2b7a(%rsp)
 115c90c:	00 00 
 115c90e:	c5 fa 6f 84 24 d0 03 	vmovdqu 0x3d0(%rsp),%xmm0
 115c915:	00 00 
 115c917:	48 8b 84 24 a0 00 00 	mov    0xa0(%rsp),%rax
 115c91e:	00 
 115c91f:	c5 fa 7f 00          	vmovdqu %xmm0,(%rax)
 115c923:	48 8b 8c 24 d8 00 00 	mov    0xd8(%rsp),%rcx
 115c92a:	00 
 115c92b:	4c 89 f8             	mov    %r15,%rax
 115c92e:	4c 89 ff             	mov    %r15,%rdi
 115c931:	80 39 00             	cmpb   $0x0,(%rcx)
 115c934:	0f 84 46 01 00 00    	je     115ca80 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x20e0>
 115c93a:	48 8b 00             	mov    (%rax),%rax
 115c93d:	48 8b 94 24 20 1a 00 	mov    0x1a20(%rsp),%rdx
 115c944:	00 
 115c945:	48 83 fa 01          	cmp    $0x1,%rdx
 115c949:	b9 06 00 00 00       	mov    $0x6,%ecx
 115c94e:	49 0f 44 cd          	cmove  %r13,%rcx
 115c952:	48 85 d2             	test   %rdx,%rdx
 115c955:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 115c95a:	0f 84 45 04 00 00    	je     115cda5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2405>
 115c960:	48 8d b4 24 3c 1a 00 	lea    0x1a3c(%rsp),%rsi
 115c967:	00 
 115c968:	31 db                	xor    %ebx,%ebx
 115c96a:	31 ff                	xor    %edi,%edi
 115c96c:	45 31 c9             	xor    %r9d,%r9d
 115c96f:	45 31 c0             	xor    %r8d,%r8d
 115c972:	eb 11                	jmp    115c985 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1fe5>
 115c974:	49 83 c1 02          	add    $0x2,%r9
 115c978:	49 81 f9 00 01 00 00 	cmp    $0x100,%r9
 115c97f:	0f 84 88 00 00 00    	je     115ca0d <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x206d>
 115c985:	46 8b 54 8e fc       	mov    -0x4(%rsi,%r9,4),%r10d
 115c98a:	4d 85 d2             	test   %r10,%r10
 115c98d:	74 38                	je     115c9c7 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2027>
 115c98f:	46 0f b6 9c 0c 00 19 	movzbl 0x1900(%rsp,%r9,1),%r11d
 115c996:	00 00 
 115c998:	4d 85 db             	test   %r11,%r11
 115c99b:	0f 84 58 04 00 00    	je     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c9a1:	c6 84 24 d0 03 00 00 	movb   $0x0,0x3d0(%rsp)
 115c9a8:	00 
 115c9a9:	45 84 ed             	test   %r13b,%r13b
 115c9ac:	0f 85 47 04 00 00    	jne    115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c9b2:	4d 0f af da          	imul   %r10,%r11
 115c9b6:	4d 01 d8             	add    %r11,%r8
 115c9b9:	0f 92 84 24 d0 03 00 	setb   0x3d0(%rsp)
 115c9c0:	00 
 115c9c1:	0f 82 32 04 00 00    	jb     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c9c7:	46 8b 14 8e          	mov    (%rsi,%r9,4),%r10d
 115c9cb:	4d 85 d2             	test   %r10,%r10
 115c9ce:	74 a4                	je     115c974 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1fd4>
 115c9d0:	46 0f b6 9c 0c 01 19 	movzbl 0x1901(%rsp,%r9,1),%r11d
 115c9d7:	00 00 
 115c9d9:	4d 85 db             	test   %r11,%r11
 115c9dc:	0f 84 17 04 00 00    	je     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c9e2:	c6 84 24 d0 03 00 00 	movb   $0x0,0x3d0(%rsp)
 115c9e9:	00 
 115c9ea:	45 84 ed             	test   %r13b,%r13b
 115c9ed:	0f 85 06 04 00 00    	jne    115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115c9f3:	4d 0f af da          	imul   %r10,%r11
 115c9f7:	4d 01 d8             	add    %r11,%r8
 115c9fa:	0f 92 84 24 d0 03 00 	setb   0x3d0(%rsp)
 115ca01:	00 
 115ca02:	0f 83 6c ff ff ff    	jae    115c974 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1fd4>
 115ca08:	e9 ec 03 00 00       	jmp    115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115ca0d:	4d 89 c1             	mov    %r8,%r9
 115ca10:	49 83 c1 08          	add    $0x8,%r9
 115ca14:	0f 92 84 24 d0 03 00 	setb   0x3d0(%rsp)
 115ca1b:	00 
 115ca1c:	0f 82 d7 03 00 00    	jb     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115ca22:	4c 01 c3             	add    %r8,%rbx
 115ca25:	0f 92 84 24 d0 03 00 	setb   0x3d0(%rsp)
 115ca2c:	00 
 115ca2d:	0f 82 c6 03 00 00    	jb     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115ca33:	48 83 fa 01          	cmp    $0x1,%rdx
 115ca37:	74 0d                	je     115ca46 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x20a6>
 115ca39:	49 81 f9 ff ff 07 00 	cmp    $0x7ffff,%r9
 115ca40:	0f 87 0c fc ff ff    	ja     115c652 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1cb2>
 115ca46:	49 c1 e9 03          	shr    $0x3,%r9
 115ca4a:	4c 01 c9             	add    %r9,%rcx
 115ca4d:	0f 92 84 24 d0 03 00 	setb   0x3d0(%rsp)
 115ca54:	00 
 115ca55:	0f 82 9e 03 00 00    	jb     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115ca5b:	48 ff c7             	inc    %rdi
 115ca5e:	48 81 c6 00 04 00 00 	add    $0x400,%rsi
 115ca65:	48 39 d7             	cmp    %rdx,%rdi
 115ca68:	0f 85 fe fe ff ff    	jne    115c96c <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1fcc>
 115ca6e:	e9 34 03 00 00       	jmp    115cda7 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2407>
 115ca73:	b0 01                	mov    $0x1,%al
 115ca75:	89 44 24 18          	mov    %eax,0x18(%rsp)
 115ca79:	31 db                	xor    %ebx,%ebx
 115ca7b:	4c 89 ff             	mov    %r15,%rdi
 115ca7e:	eb 02                	jmp    115ca82 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x20e2>
 115ca80:	31 db                	xor    %ebx,%ebx
 115ca82:	4c 8b 7c 24 38       	mov    0x38(%rsp),%r15
 115ca87:	48 89 5c 24 38       	mov    %rbx,0x38(%rsp)
 115ca8c:	48 8b 84 24 a8 00 00 	mov    0xa8(%rsp),%rax
 115ca93:	00 
 115ca94:	48 89 84 24 30 02 00 	mov    %rax,0x230(%rsp)
 115ca9b:	00 
 115ca9c:	48 8b 84 24 98 00 00 	mov    0x98(%rsp),%rax
 115caa3:	00 
 115caa4:	48 89 84 24 d0 2f 00 	mov    %rax,0x2fd0(%rsp)
 115caab:	00 
 115caac:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 115cab1:	48 89 84 24 f8 10 00 	mov    %rax,0x10f8(%rsp)
 115cab8:	00 
 115cab9:	ba 01 00 00 00       	mov    $0x1,%edx
 115cabe:	41 b8 01 00 00 00    	mov    $0x1,%r8d
 115cac4:	48 8d b4 24 30 02 00 	lea    0x230(%rsp),%rsi
 115cacb:	00 
 115cacc:	48 8d 8c 24 d0 2f 00 	lea    0x2fd0(%rsp),%rcx
 115cad3:	00 
 115cad4:	4c 8d 8c 24 f8 10 00 	lea    0x10f8(%rsp),%r9
 115cadb:	00 
 115cadc:	41 57                	push   %r15
 115cade:	6a 01                	push   $0x1
 115cae0:	c5 f8 77             	vzeroupper 
 115cae3:	e8 38 8b ff ff       	call   1155620 <zstd.rleSequencePayloadLenForValuesWithLiteralsLen>
 115cae8:	48 83 c4 10          	add    $0x10,%rsp
 115caec:	44 0f b7 b4 24 d8 03 	movzwl 0x3d8(%rsp),%r14d
 115caf3:	00 00 
 115caf5:	66 45 85 f6          	test   %r14w,%r14w
 115caf9:	0f 85 41 03 00 00    	jne    115ce40 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x24a0>
 115caff:	48 8b 9c 24 d0 03 00 	mov    0x3d0(%rsp),%rbx
 115cb06:	00 
 115cb07:	48 8b 84 24 a8 00 00 	mov    0xa8(%rsp),%rax
 115cb0e:	00 
 115cb0f:	48 89 84 24 30 02 00 	mov    %rax,0x230(%rsp)
 115cb16:	00 
 115cb17:	48 8b 84 24 98 00 00 	mov    0x98(%rsp),%rax
 115cb1e:	00 
 115cb1f:	48 89 84 24 d0 2f 00 	mov    %rax,0x2fd0(%rsp)
 115cb26:	00 
 115cb27:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 115cb2c:	48 89 84 24 f8 10 00 	mov    %rax,0x10f8(%rsp)
 115cb33:	00 
 115cb34:	ba 01 00 00 00       	mov    $0x1,%edx
 115cb39:	41 b8 01 00 00 00    	mov    $0x1,%r8d
 115cb3f:	48 8d bc 24 d0 03 00 	lea    0x3d0(%rsp),%rdi
 115cb46:	00 
 115cb47:	48 8d b4 24 30 02 00 	lea    0x230(%rsp),%rsi
 115cb4e:	00 
 115cb4f:	48 8d 8c 24 d0 2f 00 	lea    0x2fd0(%rsp),%rcx
 115cb56:	00 
 115cb57:	4c 8d 8c 24 f8 10 00 	lea    0x10f8(%rsp),%r9
 115cb5e:	00 
 115cb5f:	41 57                	push   %r15
 115cb61:	6a 01                	push   $0x1
 115cb63:	e8 b8 85 ff ff       	call   1155120 <zstd.predefinedSequencePayloadLenWithLiteralsLen>
 115cb68:	48 83 c4 10          	add    $0x10,%rsp
 115cb6c:	0f b7 84 24 d8 03 00 	movzwl 0x3d8(%rsp),%eax
 115cb73:	00 
 115cb74:	85 c0                	test   %eax,%eax
 115cb76:	0f 85 f7 02 00 00    	jne    115ce73 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x24d3>
 115cb7c:	48 8b 84 24 d0 03 00 	mov    0x3d0(%rsp),%rax
 115cb83:	00 
 115cb84:	48 39 d8             	cmp    %rbx,%rax
 115cb87:	48 0f 42 d8          	cmovb  %rax,%rbx
 115cb8b:	66 45 85 f6          	test   %r14w,%r14w
 115cb8f:	48 0f 45 d8          	cmovne %rax,%rbx
 115cb93:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115cb98:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115cb9d:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115cba2:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115cba9:	79 37 9e 
 115cbac:	44 8b 54 24 24       	mov    0x24(%rsp),%r10d
 115cbb1:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115cbb6:	80 7c 24 18 00       	cmpb   $0x0,0x18(%rsp)
 115cbbb:	74 66                	je     115cc23 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2283>
 115cbbd:	48 3b 9c 24 90 00 00 	cmp    0x90(%rsp),%rbx
 115cbc4:	00 
 115cbc5:	4c 8b 74 24 60       	mov    0x60(%rsp),%r14
 115cbca:	48 8b 84 24 50 01 00 	mov    0x150(%rsp),%rax
 115cbd1:	00 
 115cbd2:	72 22                	jb     115cbf6 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2256>
 115cbd4:	45 84 d2             	test   %r10b,%r10b
 115cbd7:	0f 84 43 e2 ff ff    	je     115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115cbdd:	48 3b 9c 24 90 00 00 	cmp    0x90(%rsp),%rbx
 115cbe4:	00 
 115cbe5:	0f 85 35 e2 ff ff    	jne    115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115cbeb:	48 3b 4c 24 68       	cmp    0x68(%rsp),%rcx
 115cbf0:	0f 83 2a e2 ff ff    	jae    115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115cbf6:	41 b2 01             	mov    $0x1,%r10b
 115cbf9:	48 89 9c 24 90 00 00 	mov    %rbx,0x90(%rsp)
 115cc00:	00 
 115cc01:	48 8b 4c 24 68       	mov    0x68(%rsp),%rcx
 115cc06:	48 89 9c 24 48 01 00 	mov    %rbx,0x148(%rsp)
 115cc0d:	00 
 115cc0e:	48 89 84 24 f8 00 00 	mov    %rax,0xf8(%rsp)
 115cc15:	00 
 115cc16:	4c 89 9c 24 b8 00 00 	mov    %r11,0xb8(%rsp)
 115cc1d:	00 
 115cc1e:	e9 fd e1 ff ff       	jmp    115ae20 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x480>
 115cc23:	45 31 f6             	xor    %r14d,%r14d
 115cc26:	31 c0                	xor    %eax,%eax
 115cc28:	31 ff                	xor    %edi,%edi
 115cc2a:	8b 94 bc f8 0c 00 00 	mov    0xcf8(%rsp,%rdi,4),%edx
 115cc31:	c6 84 24 d0 03 00 00 	movb   $0x0,0x3d0(%rsp)
 115cc38:	00 
 115cc39:	45 84 ed             	test   %r13b,%r13b
 115cc3c:	0f 85 7b ff ff ff    	jne    115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115cc42:	49 01 d6             	add    %rdx,%r14
 115cc45:	49 81 fe 00 00 02 00 	cmp    $0x20000,%r14
 115cc4c:	0f 87 6b ff ff ff    	ja     115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115cc52:	48 83 fa 01          	cmp    $0x1,%rdx
 115cc56:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 115cc5a:	8b 94 bc fc 0c 00 00 	mov    0xcfc(%rsp,%rdi,4),%edx
 115cc61:	c6 84 24 d0 03 00 00 	movb   $0x0,0x3d0(%rsp)
 115cc68:	00 
 115cc69:	45 84 ed             	test   %r13b,%r13b
 115cc6c:	0f 85 4b ff ff ff    	jne    115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115cc72:	49 01 d6             	add    %rdx,%r14
 115cc75:	49 81 fe 00 00 02 00 	cmp    $0x20000,%r14
 115cc7c:	0f 87 3b ff ff ff    	ja     115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115cc82:	48 83 fa 01          	cmp    $0x1,%rdx
 115cc86:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 115cc8a:	8b 94 bc 00 0d 00 00 	mov    0xd00(%rsp,%rdi,4),%edx
 115cc91:	c6 84 24 d0 03 00 00 	movb   $0x0,0x3d0(%rsp)
 115cc98:	00 
 115cc99:	45 84 ed             	test   %r13b,%r13b
 115cc9c:	0f 85 1b ff ff ff    	jne    115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115cca2:	49 01 d6             	add    %rdx,%r14
 115cca5:	49 81 fe 00 00 02 00 	cmp    $0x20000,%r14
 115ccac:	0f 87 0b ff ff ff    	ja     115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115ccb2:	48 83 fa 01          	cmp    $0x1,%rdx
 115ccb6:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 115ccba:	8b 94 bc 04 0d 00 00 	mov    0xd04(%rsp,%rdi,4),%edx
 115ccc1:	c6 84 24 d0 03 00 00 	movb   $0x0,0x3d0(%rsp)
 115ccc8:	00 
 115ccc9:	45 84 ed             	test   %r13b,%r13b
 115cccc:	0f 85 eb fe ff ff    	jne    115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115ccd2:	49 01 d6             	add    %rdx,%r14
 115ccd5:	49 81 fe 00 00 02 00 	cmp    $0x20000,%r14
 115ccdc:	0f 87 db fe ff ff    	ja     115cbbd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x221d>
 115cce2:	48 83 fa 01          	cmp    $0x1,%rdx
 115cce6:	48 83 d8 ff          	sbb    $0xffffffffffffffff,%rax
 115ccea:	48 83 c7 04          	add    $0x4,%rdi
 115ccee:	48 81 ff 00 01 00 00 	cmp    $0x100,%rdi
 115ccf5:	0f 85 2f ff ff ff    	jne    115cc2a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x228a>
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
 115cda5:	31 db                	xor    %ebx,%ebx
 115cda7:	48 01 c8             	add    %rcx,%rax
 115cdaa:	0f 92 84 24 d0 03 00 	setb   0x3d0(%rsp)
 115cdb1:	00 
 115cdb2:	72 45                	jb     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115cdb4:	74 43                	je     115cdf9 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2459>
 115cdb6:	48 8b 54 24 58       	mov    0x58(%rsp),%rdx
 115cdbb:	48 09 c2             	or     %rax,%rdx
 115cdbe:	b9 03 00 00 00       	mov    $0x3,%ecx
 115cdc3:	48 81 fa 00 04 00 00 	cmp    $0x400,%rdx
 115cdca:	72 20                	jb     115cdec <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x244c>
 115cdcc:	b9 04 00 00 00       	mov    $0x4,%ecx
 115cdd1:	48 81 fa 00 40 00 00 	cmp    $0x4000,%rdx
 115cdd8:	72 12                	jb     115cdec <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x244c>
 115cdda:	b9 05 00 00 00       	mov    $0x5,%ecx
 115cddf:	48 81 fa ff ff 03 00 	cmp    $0x3ffff,%rdx
 115cde6:	0f 87 66 f8 ff ff    	ja     115c652 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x1cb2>
 115cdec:	c6 84 24 d0 03 00 00 	movb   $0x0,0x3d0(%rsp)
 115cdf3:	00 
 115cdf4:	45 84 ed             	test   %r13b,%r13b
 115cdf7:	74 28                	je     115ce21 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2481>
 115cdf9:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115cdfe:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115ce03:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115ce08:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115ce0f:	79 37 9e 
 115ce12:	44 8b 54 24 24       	mov    0x24(%rsp),%r10d
 115ce17:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115ce1c:	e9 b9 f2 ff ff       	jmp    115c0da <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x173a>
 115ce21:	48 01 c1             	add    %rax,%rcx
 115ce24:	4c 39 f9             	cmp    %r15,%rcx
 115ce27:	4c 0f 42 f9          	cmovb  %rcx,%r15
 115ce2b:	c7 44 24 18 00 00 00 	movl   $0x0,0x18(%rsp)
 115ce32:	00 
 115ce33:	48 8d bc 24 d0 03 00 	lea    0x3d0(%rsp),%rdi
 115ce3a:	00 
 115ce3b:	e9 47 fc ff ff       	jmp    115ca87 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x20e7>
 115ce40:	66 41 83 fe 28       	cmp    $0x28,%r14w
 115ce45:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115ce4a:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115ce4f:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115ce54:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115ce5b:	79 37 9e 
 115ce5e:	44 8b 54 24 24       	mov    0x24(%rsp),%r10d
 115ce63:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115ce68:	0f 85 6c f2 ff ff    	jne    115c0da <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x173a>
 115ce6e:	e9 94 fc ff ff       	jmp    115cb07 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2167>
 115ce73:	83 f8 28             	cmp    $0x28,%eax
 115ce76:	75 3d                	jne    115ceb5 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2515>
 115ce78:	66 45 85 f6          	test   %r14w,%r14w
 115ce7c:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115ce81:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115ce86:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115ce8b:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115ce90:	41 bd 00 00 00 00    	mov    $0x0,%r13d
 115ce96:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115ce9d:	79 37 9e 
 115cea0:	44 8b 54 24 24       	mov    0x24(%rsp),%r10d
 115cea5:	4c 8b 5c 24 50       	mov    0x50(%rsp),%r11
 115ceaa:	0f 85 2a f2 ff ff    	jne    115c0da <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x173a>
 115ceb0:	e9 01 fd ff ff       	jmp    115cbb6 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2216>
 115ceb5:	4c 8b 64 24 28       	mov    0x28(%rsp),%r12
 115ceba:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115cebf:	48 8b 4c 24 40       	mov    0x40(%rsp),%rcx
 115cec4:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 115cec9:	45 31 ed             	xor    %r13d,%r13d
 115cecc:	49 b9 15 7c 4a 7f b9 	movabs $0x9e3779b97f4a7c15,%r9
 115ced3:	79 37 9e 
 115ced6:	4c 8b 74 24 60       	mov    0x60(%rsp),%r14
 115cedb:	e9 fd df ff ff       	jmp    115aedd <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x53d>
 115cee0:	48 8d bc 24 b0 02 00 	lea    0x2b0(%rsp),%rdi
 115cee7:	00 
 115cee8:	4c 89 e2             	mov    %r12,%rdx
 115ceeb:	4c 8b 74 24 60       	mov    0x60(%rsp),%r14
 115cef0:	4c 89 f1             	mov    %r14,%rcx
 115cef3:	c5 f8 77             	vzeroupper 
 115cef6:	e8 c5 02 00 00       	call   115d1c0 <zstd.findBestDuplicateMatchIn>
 115cefb:	0f b7 84 24 d8 02 00 	movzwl 0x2d8(%rsp),%eax
 115cf02:	00 
 115cf03:	66 85 c0             	test   %ax,%ax
 115cf06:	0f 85 2e 01 00 00    	jne    115d03a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x269a>
 115cf0c:	80 bc 24 d0 02 00 00 	cmpb   $0x0,0x2d0(%rsp)
 115cf13:	00 
 115cf14:	0f 84 ff 00 00 00    	je     115d019 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2679>
 115cf1a:	c5 fe 6f 84 24 b0 02 	vmovdqu 0x2b0(%rsp),%ymm0
 115cf21:	00 00 
 115cf23:	c5 fe 7f 84 24 10 02 	vmovdqu %ymm0,0x210(%rsp)
 115cf2a:	00 00 
 115cf2c:	4c 8b 84 24 18 02 00 	mov    0x218(%rsp),%r8
 115cf33:	00 
 115cf34:	48 8b 8c 24 20 02 00 	mov    0x220(%rsp),%rcx
 115cf3b:	00 
 115cf3c:	48 8d 84 24 10 02 00 	lea    0x210(%rsp),%rax
 115cf43:	00 
 115cf44:	48 8b 74 24 30       	mov    0x30(%rsp),%rsi
 115cf49:	4c 8b 4c 24 70       	mov    0x70(%rsp),%r9
 115cf4e:	4d 85 c9             	test   %r9,%r9
 115cf51:	0f 85 80 00 00 00    	jne    115cfd7 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2637>
 115cf57:	eb 5a                	jmp    115cfb3 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2613>
 115cf59:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 115cf60:	45 84 d2             	test   %r10b,%r10b
 115cf63:	0f 84 b0 00 00 00    	je     115d019 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2679>
 115cf69:	48 8b 84 24 f8 00 00 	mov    0xf8(%rsp),%rax
 115cf70:	00 
 115cf71:	48 89 84 24 f0 01 00 	mov    %rax,0x1f0(%rsp)
 115cf78:	00 
 115cf79:	4c 8b 84 24 b8 00 00 	mov    0xb8(%rsp),%r8
 115cf80:	00 
 115cf81:	4c 89 84 24 f8 01 00 	mov    %r8,0x1f8(%rsp)
 115cf88:	00 
 115cf89:	48 89 8c 24 00 02 00 	mov    %rcx,0x200(%rsp)
 115cf90:	00 
 115cf91:	48 8b 84 24 48 01 00 	mov    0x148(%rsp),%rax
 115cf98:	00 
 115cf99:	48 89 84 24 08 02 00 	mov    %rax,0x208(%rsp)
 115cfa0:	00 
 115cfa1:	48 8d 84 24 f0 01 00 	lea    0x1f0(%rsp),%rax
 115cfa8:	00 
 115cfa9:	4c 8b 4c 24 70       	mov    0x70(%rsp),%r9
 115cfae:	4d 85 c9             	test   %r9,%r9
 115cfb1:	75 24                	jne    115cfd7 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2637>
 115cfb3:	4d 89 c2             	mov    %r8,%r10
 115cfb6:	4c 8b 00             	mov    (%rax),%r8
 115cfb9:	48 8b 50 18          	mov    0x18(%rax),%rdx
 115cfbd:	48 8b 7d 18          	mov    0x18(%rbp),%rdi
 115cfc1:	4c 89 07             	mov    %r8,(%rdi)
 115cfc4:	4d 89 d0             	mov    %r10,%r8
 115cfc7:	4c 89 57 08          	mov    %r10,0x8(%rdi)
 115cfcb:	48 89 4f 10          	mov    %rcx,0x10(%rdi)
 115cfcf:	48 89 57 18          	mov    %rdx,0x18(%rdi)
 115cfd3:	c6 47 20 01          	movb   $0x1,0x20(%rdi)
 115cfd7:	4c 89 c7             	mov    %r8,%rdi
 115cfda:	4c 29 f7             	sub    %r14,%rdi
 115cfdd:	4c 89 ca             	mov    %r9,%rdx
 115cfe0:	48 c1 e2 05          	shl    $0x5,%rdx
 115cfe4:	c5 fe 6f 00          	vmovdqu (%rax),%ymm0
 115cfe8:	c5 fe 7f 84 14 e0 3c 	vmovdqu %ymm0,0x3ce0(%rsp,%rdx,1)
 115cfef:	00 00 
 115cff1:	4a 89 bc cc e0 38 00 	mov    %rdi,0x38e0(%rsp,%r9,8)
 115cff8:	00 
 115cff9:	4d 8d 71 01          	lea    0x1(%r9),%r14
 115cffd:	4c 01 c1             	add    %r8,%rcx
 115d000:	49 83 f9 7e          	cmp    $0x7e,%r9
 115d004:	77 1b                	ja     115d021 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2681>
 115d006:	48 89 4c 24 60       	mov    %rcx,0x60(%rsp)
 115d00b:	4c 89 f0             	mov    %r14,%rax
 115d00e:	4c 39 e1             	cmp    %r12,%rcx
 115d011:	0f 82 89 dd ff ff    	jb     115ada0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x400>
 115d017:	eb 08                	jmp    115d021 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2681>
 115d019:	4c 89 f1             	mov    %r14,%rcx
 115d01c:	4c 8b 74 24 70       	mov    0x70(%rsp),%r14
 115d021:	4c 89 f0             	mov    %r14,%rax
 115d024:	49 83 fe 02          	cmp    $0x2,%r14
 115d028:	73 48                	jae    115d072 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x26d2>
 115d02a:	0f b6 05 1d 59 ea ff 	movzbl -0x15a6e3(%rip),%eax        # 100294e <__anon_15732+0x2>
 115d031:	88 84 24 f8 10 00 00 	mov    %al,0x10f8(%rsp)
 115d038:	31 c0                	xor    %eax,%eax
 115d03a:	0f b6 8c 24 f8 10 00 	movzbl 0x10f8(%rsp),%ecx
 115d041:	00 
 115d042:	c1 e1 10             	shl    $0x10,%ecx
 115d045:	0f b7 c0             	movzwl %ax,%eax
 115d048:	09 c8                	or     %ecx,%eax
 115d04a:	48 8b 8c 24 58 01 00 	mov    0x158(%rsp),%rcx
 115d051:	00 
 115d052:	89 01                	mov    %eax,(%rcx)
 115d054:	48 8d 65 d8          	lea    -0x28(%rbp),%rsp
 115d058:	5b                   	pop    %rbx
 115d059:	41 5c                	pop    %r12
 115d05b:	41 5d                	pop    %r13
 115d05d:	41 5e                	pop    %r14
 115d05f:	41 5f                	pop    %r15
 115d061:	5d                   	pop    %rbp
 115d062:	c5 f8 77             	vzeroupper 
 115d065:	c3                   	ret    
 115d066:	4c 89 e9             	mov    %r13,%rcx
 115d069:	4c 89 f0             	mov    %r14,%rax
 115d06c:	49 83 fe 02          	cmp    $0x2,%r14
 115d070:	72 b8                	jb     115d02a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x268a>
 115d072:	49 89 cf             	mov    %rcx,%r15
 115d075:	48 83 f8 01          	cmp    $0x1,%rax
 115d079:	75 09                	jne    115d084 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x26e4>
 115d07b:	31 c9                	xor    %ecx,%ecx
 115d07d:	4c 8b 44 24 28       	mov    0x28(%rsp),%r8
 115d082:	eb 76                	jmp    115d0fa <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x275a>
 115d084:	48 89 c2             	mov    %rax,%rdx
 115d087:	48 83 e2 fe          	and    $0xfffffffffffffffe,%rdx
 115d08b:	48 8d b4 24 10 3d 00 	lea    0x3d10(%rsp),%rsi
 115d092:	00 
 115d093:	31 c9                	xor    %ecx,%ecx
 115d095:	4c 8b 44 24 28       	mov    0x28(%rsp),%r8
 115d09a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 115d0a0:	48 8b 7e d8          	mov    -0x28(%rsi),%rdi
 115d0a4:	4c 8b 56 e0          	mov    -0x20(%rsi),%r10
 115d0a8:	4c 89 94 cc e0 4c 00 	mov    %r10,0x4ce0(%rsp,%rcx,8)
 115d0af:	00 
 115d0b0:	49 01 fa             	add    %rdi,%r10
 115d0b3:	48 2b 7e d0          	sub    -0x30(%rsi),%rdi
 115d0b7:	48 89 bc cc d0 03 00 	mov    %rdi,0x3d0(%rsp,%rcx,8)
 115d0be:	00 
 115d0bf:	48 8b 7e f8          	mov    -0x8(%rsi),%rdi
 115d0c3:	4c 8b 0e             	mov    (%rsi),%r9
 115d0c6:	4c 89 8c cc e8 4c 00 	mov    %r9,0x4ce8(%rsp,%rcx,8)
 115d0cd:	00 
 115d0ce:	49 01 f9             	add    %rdi,%r9
 115d0d1:	48 2b 7e f0          	sub    -0x10(%rsi),%rdi
 115d0d5:	4c 89 94 cc e0 cc 00 	mov    %r10,0xcce0(%rsp,%rcx,8)
 115d0dc:	00 
 115d0dd:	48 89 bc cc d8 03 00 	mov    %rdi,0x3d8(%rsp,%rcx,8)
 115d0e4:	00 
 115d0e5:	4c 89 8c cc e8 cc 00 	mov    %r9,0xcce8(%rsp,%rcx,8)
 115d0ec:	00 
 115d0ed:	48 83 c1 02          	add    $0x2,%rcx
 115d0f1:	48 83 c6 40          	add    $0x40,%rsi
 115d0f5:	48 39 ca             	cmp    %rcx,%rdx
 115d0f8:	75 a6                	jne    115d0a0 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2700>
 115d0fa:	a8 01                	test   $0x1,%al
 115d0fc:	74 3a                	je     115d138 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2798>
 115d0fe:	48 89 ca             	mov    %rcx,%rdx
 115d101:	48 c1 e2 05          	shl    $0x5,%rdx
 115d105:	48 8b b4 14 e8 3c 00 	mov    0x3ce8(%rsp,%rdx,1),%rsi
 115d10c:	00 
 115d10d:	48 8b bc 14 f0 3c 00 	mov    0x3cf0(%rsp,%rdx,1),%rdi
 115d114:	00 
 115d115:	48 89 bc cc e0 4c 00 	mov    %rdi,0x4ce0(%rsp,%rcx,8)
 115d11c:	00 
 115d11d:	48 01 f7             	add    %rsi,%rdi
 115d120:	48 2b b4 14 e0 3c 00 	sub    0x3ce0(%rsp,%rdx,1),%rsi
 115d127:	00 
 115d128:	48 89 b4 cc d0 03 00 	mov    %rsi,0x3d0(%rsp,%rcx,8)
 115d12f:	00 
 115d130:	48 89 bc cc e0 cc 00 	mov    %rdi,0xcce0(%rsp,%rcx,8)
 115d137:	00 
 115d138:	4c 8d 94 24 e0 cc 00 	lea    0xcce0(%rsp),%r10
 115d13f:	00 
 115d140:	4c 8d 9c 24 e0 4c 00 	lea    0x4ce0(%rsp),%r11
 115d147:	00 
 115d148:	48 8d 9c 24 d0 03 00 	lea    0x3d0(%rsp),%rbx
 115d14f:	00 
 115d150:	4c 8d b4 24 e0 38 00 	lea    0x38e0(%rsp),%r14
 115d157:	00 
 115d158:	44 0f b6 8c 24 c4 00 	movzbl 0xc4(%rsp),%r9d
 115d15f:	00 00 
 115d161:	48 8d bc 24 f8 10 00 	lea    0x10f8(%rsp),%rdi
 115d168:	00 
 115d169:	48 8b b4 24 38 01 00 	mov    0x138(%rsp),%rsi
 115d170:	00 
 115d171:	48 8b 94 24 40 01 00 	mov    0x140(%rsp),%rdx
 115d178:	00 
 115d179:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 115d17e:	6a 00                	push   $0x0
 115d180:	41 57                	push   %r15
 115d182:	50                   	push   %rax
 115d183:	41 52                	push   %r10
 115d185:	50                   	push   %rax
 115d186:	41 53                	push   %r11
 115d188:	50                   	push   %rax
 115d189:	53                   	push   %rbx
 115d18a:	50                   	push   %rax
 115d18b:	41 56                	push   %r14
 115d18d:	c5 f8 77             	vzeroupper 
 115d190:	e8 fb f4 fe ff       	call   114c690 <zstd.emitBestSequenceCompressedBlockWithScratch>
 115d195:	48 83 c4 50          	add    $0x50,%rsp
 115d199:	0f b7 84 24 f8 10 00 	movzwl 0x10f8(%rsp),%eax
 115d1a0:	00 
 115d1a1:	66 85 c0             	test   %ax,%ax
 115d1a4:	0f 85 90 fe ff ff    	jne    115d03a <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x269a>
 115d1aa:	0f b6 84 24 fa 10 00 	movzbl 0x10fa(%rsp),%eax
 115d1b1:	00 
 115d1b2:	e9 7a fe ff ff       	jmp    115d031 <zstd.emitMultiDuplicateMatchCompressedBlockWithFirst+0x2691>

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
