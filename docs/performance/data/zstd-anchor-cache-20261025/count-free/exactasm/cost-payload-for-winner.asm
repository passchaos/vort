
/tmp/vort-zstd-anchor-cache-20261025/count-free/anchor-count-free:     file format elf64-x86-64


Disassembly of section .text:

00000000010f1840 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner>:
 10f1840:	55                   	push   %rbp
 10f1841:	48 89 e5             	mov    %rsp,%rbp
 10f1844:	41 57                	push   %r15
 10f1846:	41 56                	push   %r14
 10f1848:	41 55                	push   %r13
 10f184a:	41 54                	push   %r12
 10f184c:	53                   	push   %rbx
 10f184d:	48 83 e4 e0          	and    $0xffffffffffffffe0,%rsp
 10f1851:	48 81 ec 20 26 00 00 	sub    $0x2620,%rsp
 10f1858:	48 89 7c 24 60       	mov    %rdi,0x60(%rsp)
 10f185d:	48 8b 45 10          	mov    0x10(%rbp),%rax
 10f1861:	48 8b 38             	mov    (%rax),%rdi
 10f1864:	4c 8b 58 08          	mov    0x8(%rax),%r11
 10f1868:	4c 8b 96 00 16 00 00 	mov    0x1600(%rsi),%r10
 10f186f:	49 ff c2             	inc    %r10
 10f1872:	48 c7 c0 ff ff ff ff 	mov    $0xffffffffffffffff,%rax
 10f1879:	4c 0f 44 d0          	cmove  %rax,%r10
 10f187d:	4c 89 96 00 16 00 00 	mov    %r10,0x1600(%rsi)
 10f1884:	80 be f0 15 00 00 00 	cmpb   $0x0,0x15f0(%rsi)
 10f188b:	74 15                	je     10f18a2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x62>
 10f188d:	4c 8b 96 f8 15 00 00 	mov    0x15f8(%rsi),%r10
 10f1894:	49 ff c2             	inc    %r10
 10f1897:	4c 0f 44 d0          	cmove  %rax,%r10
 10f189b:	4c 89 96 f8 15 00 00 	mov    %r10,0x15f8(%rsi)
 10f18a2:	66 41 ba 3b 00       	mov    $0x3b,%r10w
 10f18a7:	4c 89 c8             	mov    %r9,%rax
 10f18aa:	48 29 d0             	sub    %rdx,%rax
 10f18ad:	0f 82 4b 11 00 00    	jb     10f29fe <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11be>
 10f18b3:	48 89 4c 24 40       	mov    %rcx,0x40(%rsp)
 10f18b8:	4c 89 44 24 30       	mov    %r8,0x30(%rsp)
 10f18bd:	48 89 bc 24 00 01 00 	mov    %rdi,0x100(%rsp)
 10f18c4:	00 
 10f18c5:	4c 89 9c 24 80 00 00 	mov    %r11,0x80(%rsp)
 10f18cc:	00 
 10f18cd:	4c 8b 66 08          	mov    0x8(%rsi),%r12
 10f18d1:	4d 29 cc             	sub    %r9,%r12
 10f18d4:	0f 82 24 11 00 00    	jb     10f29fe <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11be>
 10f18da:	48 89 74 24 20       	mov    %rsi,0x20(%rsp)
 10f18df:	49 8d 0c 14          	lea    (%r12,%rdx,1),%rcx
 10f18e3:	48 83 c1 03          	add    $0x3,%rcx
 10f18e7:	49 01 d4             	add    %rdx,%r12
 10f18ea:	48 c1 e9 02          	shr    $0x2,%rcx
 10f18ee:	31 f6                	xor    %esi,%esi
 10f18f0:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 10f18f4:	c5 fc 11 84 24 f0 0f 	vmovups %ymm0,0xff0(%rsp)
 10f18fb:	00 00 
 10f18fd:	c5 fc 11 84 24 d0 0f 	vmovups %ymm0,0xfd0(%rsp)
 10f1904:	00 00 
 10f1906:	49 81 fc 00 04 00 00 	cmp    $0x400,%r12
 10f190d:	40 0f 93 c6          	setae  %sil
 10f1911:	48 8d 74 76 01       	lea    0x1(%rsi,%rsi,2),%rsi
 10f1916:	49 0f 42 cc          	cmovb  %r12,%rcx
 10f191a:	48 89 b4 24 a0 00 00 	mov    %rsi,0xa0(%rsp)
 10f1921:	00 
 10f1922:	0f 83 50 03 00 00    	jae    10f1c78 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x438>
 10f1928:	45 31 ed             	xor    %r13d,%r13d
 10f192b:	48 8d b4 24 d0 0f 00 	lea    0xfd0(%rsp),%rsi
 10f1932:	00 
 10f1933:	f6 84 24 a0 00 00 00 	testb  $0x1,0xa0(%rsp)
 10f193a:	01 
 10f193b:	4c 8b 4c 24 20       	mov    0x20(%rsp),%r9
 10f1940:	74 46                	je     10f1988 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x148>
 10f1942:	4c 89 ef             	mov    %r13,%rdi
 10f1945:	48 c1 e7 04          	shl    $0x4,%rdi
 10f1949:	48 01 f7             	add    %rsi,%rdi
 10f194c:	4c 0f af e9          	imul   %rcx,%r13
 10f1950:	4c 01 e9             	add    %r13,%rcx
 10f1953:	49 39 cc             	cmp    %rcx,%r12
 10f1956:	49 0f 42 cc          	cmovb  %r12,%rcx
 10f195a:	49 39 d5             	cmp    %rdx,%r13
 10f195d:	73 11                	jae    10f1970 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x130>
 10f195f:	44 89 2f             	mov    %r13d,(%rdi)
 10f1962:	48 39 d1             	cmp    %rdx,%rcx
 10f1965:	49 89 d0             	mov    %rdx,%r8
 10f1968:	4c 0f 42 c1          	cmovb  %rcx,%r8
 10f196c:	44 89 47 04          	mov    %r8d,0x4(%rdi)
 10f1970:	48 39 d1             	cmp    %rdx,%rcx
 10f1973:	76 13                	jbe    10f1988 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x148>
 10f1975:	49 39 d5             	cmp    %rdx,%r13
 10f1978:	4c 0f 46 ea          	cmovbe %rdx,%r13
 10f197c:	41 01 c5             	add    %eax,%r13d
 10f197f:	44 89 6f 08          	mov    %r13d,0x8(%rdi)
 10f1983:	01 c1                	add    %eax,%ecx
 10f1985:	89 4f 0c             	mov    %ecx,0xc(%rdi)
 10f1988:	c5 fe 6f 06          	vmovdqu (%rsi),%ymm0
 10f198c:	c5 fc 10 4e 20       	vmovups 0x20(%rsi),%ymm1
 10f1991:	c5 fc 11 8c 24 a0 01 	vmovups %ymm1,0x1a0(%rsp)
 10f1998:	00 00 
 10f199a:	c5 fe 7f 84 24 80 01 	vmovdqu %ymm0,0x180(%rsp)
 10f19a1:	00 00 
 10f19a3:	c4 c1 7e 6f 91 30 10 	vmovdqu 0x1030(%r9),%ymm2
 10f19aa:	00 00 
 10f19ac:	c4 c1 7e 6f 99 50 10 	vmovdqu 0x1050(%r9),%ymm3
 10f19b3:	00 00 
 10f19b5:	c5 fe 7f 94 24 10 02 	vmovdqu %ymm2,0x210(%rsp)
 10f19bc:	00 00 
 10f19be:	c5 fe 7f 9c 24 30 02 	vmovdqu %ymm3,0x230(%rsp)
 10f19c5:	00 00 
 10f19c7:	c5 fe 7f 84 24 50 02 	vmovdqu %ymm0,0x250(%rsp)
 10f19ce:	00 00 
 10f19d0:	49 8d 81 30 10 00 00 	lea    0x1030(%r9),%rax
 10f19d7:	48 89 84 24 e0 00 00 	mov    %rax,0xe0(%rsp)
 10f19de:	00 
 10f19df:	c5 fc 11 8c 24 70 02 	vmovups %ymm1,0x270(%rsp)
 10f19e6:	00 00 
 10f19e8:	b8 08 00 00 00       	mov    $0x8,%eax
 10f19ed:	31 f6                	xor    %esi,%esi
 10f19ef:	45 31 db             	xor    %r11d,%r11d
 10f19f2:	48 89 54 24 68       	mov    %rdx,0x68(%rsp)
 10f19f7:	4c 89 64 24 58       	mov    %r12,0x58(%rsp)
 10f19fc:	eb 38                	jmp    10f1a36 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1f6>
 10f19fe:	66 90                	xchg   %ax,%ax
 10f1a00:	31 c9                	xor    %ecx,%ecx
 10f1a02:	4c 03 74 24 50       	add    0x50(%rsp),%r14
 10f1a07:	4c 03 74 24 28       	add    0x28(%rsp),%r14
 10f1a0c:	49 01 d2             	add    %rdx,%r10
 10f1a0f:	4d 01 f2             	add    %r14,%r10
 10f1a12:	49 01 d8             	add    %rbx,%r8
 10f1a15:	4d 01 d0             	add    %r10,%r8
 10f1a18:	41 29 f9             	sub    %edi,%r9d
 10f1a1b:	44 0f 42 ce          	cmovb  %esi,%r9d
 10f1a1f:	49 01 c9             	add    %rcx,%r9
 10f1a22:	4d 89 cb             	mov    %r9,%r11
 10f1a25:	4d 01 c3             	add    %r8,%r11
 10f1a28:	48 83 c0 10          	add    $0x10,%rax
 10f1a2c:	48 83 f8 48          	cmp    $0x48,%rax
 10f1a30:	0f 84 1c 02 00 00    	je     10f1c52 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x412>
 10f1a36:	48 8b 8c 04 08 02 00 	mov    0x208(%rsp,%rax,1),%rcx
 10f1a3d:	00 
 10f1a3e:	49 89 cf             	mov    %rcx,%r15
 10f1a41:	49 c1 ef 20          	shr    $0x20,%r15
 10f1a45:	4c 8b a4 04 48 02 00 	mov    0x248(%rsp,%rax,1),%r12
 10f1a4c:	00 
 10f1a4d:	48 8b bc 04 50 02 00 	mov    0x250(%rsp,%rax,1),%rdi
 10f1a54:	00 
 10f1a55:	4c 89 e3             	mov    %r12,%rbx
 10f1a58:	48 c1 eb 20          	shr    $0x20,%rbx
 10f1a5c:	49 89 f9             	mov    %rdi,%r9
 10f1a5f:	49 c1 e9 20          	shr    $0x20,%r9
 10f1a63:	39 cb                	cmp    %ecx,%ebx
 10f1a65:	4c 89 5c 24 50       	mov    %r11,0x50(%rsp)
 10f1a6a:	76 24                	jbe    10f1a90 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x250>
 10f1a6c:	45 39 fc             	cmp    %r15d,%r12d
 10f1a6f:	73 4f                	jae    10f1ac0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x280>
 10f1a71:	45 89 e6             	mov    %r12d,%r14d
 10f1a74:	41 29 ce             	sub    %ecx,%r14d
 10f1a77:	44 0f 42 f6          	cmovb  %esi,%r14d
 10f1a7b:	41 39 df             	cmp    %ebx,%r15d
 10f1a7e:	89 da                	mov    %ebx,%edx
 10f1a80:	41 0f 42 d7          	cmovb  %r15d,%edx
 10f1a84:	39 d1                	cmp    %edx,%ecx
 10f1a86:	0f 47 d1             	cmova  %ecx,%edx
 10f1a89:	44 39 ca             	cmp    %r9d,%edx
 10f1a8c:	72 0c                	jb     10f1a9a <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x25a>
 10f1a8e:	eb 35                	jmp    10f1ac5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x285>
 10f1a90:	89 ca                	mov    %ecx,%edx
 10f1a92:	45 31 f6             	xor    %r14d,%r14d
 10f1a95:	44 39 ca             	cmp    %r9d,%edx
 10f1a98:	73 2b                	jae    10f1ac5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x285>
 10f1a9a:	44 39 ff             	cmp    %r15d,%edi
 10f1a9d:	73 26                	jae    10f1ac5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x285>
 10f1a9f:	45 31 c0             	xor    %r8d,%r8d
 10f1aa2:	89 fe                	mov    %edi,%esi
 10f1aa4:	29 d6                	sub    %edx,%esi
 10f1aa6:	41 0f 42 f0          	cmovb  %r8d,%esi
 10f1aaa:	49 01 f6             	add    %rsi,%r14
 10f1aad:	45 39 cf             	cmp    %r9d,%r15d
 10f1ab0:	44 89 ce             	mov    %r9d,%esi
 10f1ab3:	41 0f 42 f7          	cmovb  %r15d,%esi
 10f1ab7:	39 f2                	cmp    %esi,%edx
 10f1ab9:	0f 46 d6             	cmovbe %esi,%edx
 10f1abc:	31 f6                	xor    %esi,%esi
 10f1abe:	eb 05                	jmp    10f1ac5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x285>
 10f1ac0:	89 ca                	mov    %ecx,%edx
 10f1ac2:	45 31 f6             	xor    %r14d,%r14d
 10f1ac5:	4c 8b ac 04 10 02 00 	mov    0x210(%rsp,%rax,1),%r13
 10f1acc:	00 
 10f1acd:	45 89 f8             	mov    %r15d,%r8d
 10f1ad0:	41 29 d0             	sub    %edx,%r8d
 10f1ad3:	44 0f 42 c6          	cmovb  %esi,%r8d
 10f1ad7:	4d 89 eb             	mov    %r13,%r11
 10f1ada:	49 c1 eb 20          	shr    $0x20,%r11
 10f1ade:	44 39 eb             	cmp    %r13d,%ebx
 10f1ae1:	4c 89 44 24 28       	mov    %r8,0x28(%rsp)
 10f1ae6:	76 28                	jbe    10f1b10 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x2d0>
 10f1ae8:	45 39 dc             	cmp    %r11d,%r12d
 10f1aeb:	73 53                	jae    10f1b40 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x300>
 10f1aed:	45 89 e2             	mov    %r12d,%r10d
 10f1af0:	45 29 ea             	sub    %r13d,%r10d
 10f1af3:	44 0f 42 d6          	cmovb  %esi,%r10d
 10f1af7:	41 39 db             	cmp    %ebx,%r11d
 10f1afa:	41 89 d8             	mov    %ebx,%r8d
 10f1afd:	45 0f 42 c3          	cmovb  %r11d,%r8d
 10f1b01:	45 39 c5             	cmp    %r8d,%r13d
 10f1b04:	45 0f 47 c5          	cmova  %r13d,%r8d
 10f1b08:	45 39 c8             	cmp    %r9d,%r8d
 10f1b0b:	72 0e                	jb     10f1b1b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x2db>
 10f1b0d:	eb 37                	jmp    10f1b46 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x306>
 10f1b0f:	90                   	nop
 10f1b10:	45 89 e8             	mov    %r13d,%r8d
 10f1b13:	45 31 d2             	xor    %r10d,%r10d
 10f1b16:	45 39 c8             	cmp    %r9d,%r8d
 10f1b19:	73 2b                	jae    10f1b46 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x306>
 10f1b1b:	44 39 df             	cmp    %r11d,%edi
 10f1b1e:	73 26                	jae    10f1b46 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x306>
 10f1b20:	89 fa                	mov    %edi,%edx
 10f1b22:	44 29 c2             	sub    %r8d,%edx
 10f1b25:	0f 42 d6             	cmovb  %esi,%edx
 10f1b28:	49 01 d2             	add    %rdx,%r10
 10f1b2b:	45 39 cb             	cmp    %r9d,%r11d
 10f1b2e:	44 89 ca             	mov    %r9d,%edx
 10f1b31:	41 0f 42 d3          	cmovb  %r11d,%edx
 10f1b35:	41 39 d0             	cmp    %edx,%r8d
 10f1b38:	44 0f 46 c2          	cmovbe %edx,%r8d
 10f1b3c:	eb 08                	jmp    10f1b46 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x306>
 10f1b3e:	66 90                	xchg   %ax,%ax
 10f1b40:	45 89 e8             	mov    %r13d,%r8d
 10f1b43:	45 31 d2             	xor    %r10d,%r10d
 10f1b46:	44 89 da             	mov    %r11d,%edx
 10f1b49:	44 29 c2             	sub    %r8d,%edx
 10f1b4c:	0f 42 d6             	cmovb  %esi,%edx
 10f1b4f:	45 39 e7             	cmp    %r12d,%r15d
 10f1b52:	76 3c                	jbe    10f1b90 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x350>
 10f1b54:	39 cb                	cmp    %ecx,%ebx
 10f1b56:	0f 86 b4 00 00 00    	jbe    10f1c10 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x3d0>
 10f1b5c:	41 89 c8             	mov    %ecx,%r8d
 10f1b5f:	45 29 e0             	sub    %r12d,%r8d
 10f1b62:	44 0f 42 c6          	cmovb  %esi,%r8d
 10f1b66:	44 39 fb             	cmp    %r15d,%ebx
 10f1b69:	44 89 fe             	mov    %r15d,%esi
 10f1b6c:	0f 42 f3             	cmovb  %ebx,%esi
 10f1b6f:	41 39 f4             	cmp    %esi,%r12d
 10f1b72:	41 0f 47 f4          	cmova  %r12d,%esi
 10f1b76:	41 89 f4             	mov    %esi,%r12d
 10f1b79:	31 f6                	xor    %esi,%esi
 10f1b7b:	44 39 eb             	cmp    %r13d,%ebx
 10f1b7e:	77 18                	ja     10f1b98 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x358>
 10f1b80:	eb 4d                	jmp    10f1bcf <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x38f>
 10f1b82:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10f1b89:	1f 84 00 00 00 00 00 
 10f1b90:	45 31 c0             	xor    %r8d,%r8d
 10f1b93:	44 39 eb             	cmp    %r13d,%ebx
 10f1b96:	76 37                	jbe    10f1bcf <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x38f>
 10f1b98:	45 39 dc             	cmp    %r11d,%r12d
 10f1b9b:	73 32                	jae    10f1bcf <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x38f>
 10f1b9d:	44 89 ee             	mov    %r13d,%esi
 10f1ba0:	44 29 e6             	sub    %r12d,%esi
 10f1ba3:	4c 89 74 24 48       	mov    %r14,0x48(%rsp)
 10f1ba8:	41 be 00 00 00 00    	mov    $0x0,%r14d
 10f1bae:	41 0f 42 f6          	cmovb  %r14d,%esi
 10f1bb2:	4c 8b 74 24 48       	mov    0x48(%rsp),%r14
 10f1bb7:	49 01 f0             	add    %rsi,%r8
 10f1bba:	44 39 db             	cmp    %r11d,%ebx
 10f1bbd:	44 89 de             	mov    %r11d,%esi
 10f1bc0:	0f 42 f3             	cmovb  %ebx,%esi
 10f1bc3:	41 39 f4             	cmp    %esi,%r12d
 10f1bc6:	41 0f 47 f4          	cmova  %r12d,%esi
 10f1bca:	41 89 f4             	mov    %esi,%r12d
 10f1bcd:	31 f6                	xor    %esi,%esi
 10f1bcf:	44 29 e3             	sub    %r12d,%ebx
 10f1bd2:	0f 42 de             	cmovb  %esi,%ebx
 10f1bd5:	41 39 ff             	cmp    %edi,%r15d
 10f1bd8:	76 44                	jbe    10f1c1e <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x3de>
 10f1bda:	44 39 c9             	cmp    %r9d,%ecx
 10f1bdd:	0f 83 1d fe ff ff    	jae    10f1a00 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1c0>
 10f1be3:	29 f9                	sub    %edi,%ecx
 10f1be5:	0f 42 ce             	cmovb  %esi,%ecx
 10f1be8:	45 39 f9             	cmp    %r15d,%r9d
 10f1beb:	45 0f 42 f9          	cmovb  %r9d,%r15d
 10f1bef:	44 39 ff             	cmp    %r15d,%edi
 10f1bf2:	44 0f 47 ff          	cmova  %edi,%r15d
 10f1bf6:	44 89 ff             	mov    %r15d,%edi
 10f1bf9:	44 39 df             	cmp    %r11d,%edi
 10f1bfc:	72 2b                	jb     10f1c29 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x3e9>
 10f1bfe:	e9 ff fd ff ff       	jmp    10f1a02 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1c2>
 10f1c03:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10f1c0a:	84 00 00 00 00 00 
 10f1c10:	45 31 c0             	xor    %r8d,%r8d
 10f1c13:	44 29 e3             	sub    %r12d,%ebx
 10f1c16:	0f 42 de             	cmovb  %esi,%ebx
 10f1c19:	41 39 ff             	cmp    %edi,%r15d
 10f1c1c:	77 bc                	ja     10f1bda <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x39a>
 10f1c1e:	31 c9                	xor    %ecx,%ecx
 10f1c20:	44 39 df             	cmp    %r11d,%edi
 10f1c23:	0f 83 d9 fd ff ff    	jae    10f1a02 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1c2>
 10f1c29:	45 39 cd             	cmp    %r9d,%r13d
 10f1c2c:	0f 83 d0 fd ff ff    	jae    10f1a02 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1c2>
 10f1c32:	41 29 fd             	sub    %edi,%r13d
 10f1c35:	44 0f 42 ee          	cmovb  %esi,%r13d
 10f1c39:	4c 01 e9             	add    %r13,%rcx
 10f1c3c:	45 39 d9             	cmp    %r11d,%r9d
 10f1c3f:	45 0f 42 d9          	cmovb  %r9d,%r11d
 10f1c43:	44 39 df             	cmp    %r11d,%edi
 10f1c46:	44 0f 47 df          	cmova  %edi,%r11d
 10f1c4a:	44 89 df             	mov    %r11d,%edi
 10f1c4d:	e9 b0 fd ff ff       	jmp    10f1a02 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1c2>
 10f1c52:	48 8b 74 24 20       	mov    0x20(%rsp),%rsi
 10f1c57:	4c 03 5e 20          	add    0x20(%rsi),%r11
 10f1c5b:	0f 92 c0             	setb   %al
 10f1c5e:	0f 92 84 24 c0 0f 00 	setb   0xfc0(%rsp)
 10f1c65:	00 
 10f1c66:	84 c0                	test   %al,%al
 10f1c68:	0f 84 d0 00 00 00    	je     10f1d3e <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x4fe>
 10f1c6e:	66 41 ba 3e 00       	mov    $0x3e,%r10w
 10f1c73:	e9 86 0d 00 00       	jmp    10f29fe <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11be>
 10f1c78:	83 e6 fc             	and    $0xfffffffc,%esi
 10f1c7b:	48 8d bc 24 ec 0f 00 	lea    0xfec(%rsp),%rdi
 10f1c82:	00 
 10f1c83:	4c 8d 04 09          	lea    (%rcx,%rcx,1),%r8
 10f1c87:	44 8d 0c 09          	lea    (%rcx,%rcx,1),%r9d
 10f1c8b:	45 31 d2             	xor    %r10d,%r10d
 10f1c8e:	45 31 db             	xor    %r11d,%r11d
 10f1c91:	45 31 ed             	xor    %r13d,%r13d
 10f1c94:	eb 1e                	jmp    10f1cb4 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x474>
 10f1c96:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 10f1c9d:	00 00 00 
 10f1ca0:	49 83 c5 02          	add    $0x2,%r13
 10f1ca4:	48 83 c7 20          	add    $0x20,%rdi
 10f1ca8:	4d 01 ca             	add    %r9,%r10
 10f1cab:	4c 39 ee             	cmp    %r13,%rsi
 10f1cae:	0f 84 77 fc ff ff    	je     10f192b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xeb>
 10f1cb4:	4a 8d 1c 19          	lea    (%rcx,%r11,1),%rbx
 10f1cb8:	49 39 dc             	cmp    %rbx,%r12
 10f1cbb:	49 89 de             	mov    %rbx,%r14
 10f1cbe:	4d 0f 42 f4          	cmovb  %r12,%r14
 10f1cc2:	49 39 d3             	cmp    %rdx,%r11
 10f1cc5:	73 12                	jae    10f1cd9 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x499>
 10f1cc7:	44 89 57 e4          	mov    %r10d,-0x1c(%rdi)
 10f1ccb:	49 39 d6             	cmp    %rdx,%r14
 10f1cce:	49 89 d7             	mov    %rdx,%r15
 10f1cd1:	4d 0f 42 fe          	cmovb  %r14,%r15
 10f1cd5:	44 89 7f e8          	mov    %r15d,-0x18(%rdi)
 10f1cd9:	49 39 d6             	cmp    %rdx,%r14
 10f1cdc:	76 18                	jbe    10f1cf6 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x4b6>
 10f1cde:	49 39 d3             	cmp    %rdx,%r11
 10f1ce1:	49 89 d7             	mov    %rdx,%r15
 10f1ce4:	4d 0f 47 fb          	cmova  %r11,%r15
 10f1ce8:	41 01 c7             	add    %eax,%r15d
 10f1ceb:	44 89 7f ec          	mov    %r15d,-0x14(%rdi)
 10f1cef:	41 01 c6             	add    %eax,%r14d
 10f1cf2:	44 89 77 f0          	mov    %r14d,-0x10(%rdi)
 10f1cf6:	4d 01 c3             	add    %r8,%r11
 10f1cf9:	4d 39 dc             	cmp    %r11,%r12
 10f1cfc:	4d 89 de             	mov    %r11,%r14
 10f1cff:	4d 0f 42 f4          	cmovb  %r12,%r14
 10f1d03:	48 39 d3             	cmp    %rdx,%rbx
 10f1d06:	73 16                	jae    10f1d1e <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x4de>
 10f1d08:	46 8d 3c 11          	lea    (%rcx,%r10,1),%r15d
 10f1d0c:	44 89 7f f4          	mov    %r15d,-0xc(%rdi)
 10f1d10:	49 39 d6             	cmp    %rdx,%r14
 10f1d13:	49 89 d7             	mov    %rdx,%r15
 10f1d16:	4d 0f 42 fe          	cmovb  %r14,%r15
 10f1d1a:	44 89 7f f8          	mov    %r15d,-0x8(%rdi)
 10f1d1e:	49 39 d6             	cmp    %rdx,%r14
 10f1d21:	0f 86 79 ff ff ff    	jbe    10f1ca0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x460>
 10f1d27:	48 39 d3             	cmp    %rdx,%rbx
 10f1d2a:	48 0f 46 da          	cmovbe %rdx,%rbx
 10f1d2e:	01 c3                	add    %eax,%ebx
 10f1d30:	89 5f fc             	mov    %ebx,-0x4(%rdi)
 10f1d33:	41 01 c6             	add    %eax,%r14d
 10f1d36:	44 89 37             	mov    %r14d,(%rdi)
 10f1d39:	e9 62 ff ff ff       	jmp    10f1ca0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x460>
 10f1d3e:	48 8b 46 28          	mov    0x28(%rsi),%rax
 10f1d42:	66 41 ba 3e 00       	mov    $0x3e,%r10w
 10f1d47:	48 ff c0             	inc    %rax
 10f1d4a:	0f 84 ae 0c 00 00    	je     10f29fe <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11be>
 10f1d50:	48 89 84 24 20 01 00 	mov    %rax,0x120(%rsp)
 10f1d57:	00 
 10f1d58:	4c 89 5c 24 50       	mov    %r11,0x50(%rsp)
 10f1d5d:	48 8d 46 30          	lea    0x30(%rsi),%rax
 10f1d61:	48 89 44 24 78       	mov    %rax,0x78(%rsp)
 10f1d66:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 10f1d6d:	00 
 10f1d6e:	c5 fc 10 00          	vmovups (%rax),%ymm0
 10f1d72:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 10f1d77:	c5 fc 11 8c 24 60 01 	vmovups %ymm1,0x160(%rsp)
 10f1d7e:	00 00 
 10f1d80:	c5 fc 11 84 24 40 01 	vmovups %ymm0,0x140(%rsp)
 10f1d87:	00 00 
 10f1d89:	c5 fc 10 84 24 80 01 	vmovups 0x180(%rsp),%ymm0
 10f1d90:	00 00 
 10f1d92:	c5 fc 10 8c 24 a0 01 	vmovups 0x1a0(%rsp),%ymm1
 10f1d99:	00 00 
 10f1d9b:	c5 fc 11 84 24 d0 18 	vmovups %ymm0,0x18d0(%rsp)
 10f1da2:	00 00 
 10f1da4:	c5 fc 11 8c 24 f0 18 	vmovups %ymm1,0x18f0(%rsp)
 10f1dab:	00 00 
 10f1dad:	45 31 f6             	xor    %r14d,%r14d
 10f1db0:	eb 1b                	jmp    10f1dcd <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x58d>
 10f1db2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10f1db9:	1f 84 00 00 00 00 00 
 10f1dc0:	49 ff c6             	inc    %r14
 10f1dc3:	49 83 fe 04          	cmp    $0x4,%r14
 10f1dc7:	0f 84 28 0b 00 00    	je     10f28f5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x10b5>
 10f1dcd:	4d 89 f4             	mov    %r14,%r12
 10f1dd0:	49 c1 e4 0a          	shl    $0xa,%r12
 10f1dd4:	4c 03 64 24 78       	add    0x78(%rsp),%r12
 10f1dd9:	4d 89 f7             	mov    %r14,%r15
 10f1ddc:	49 c1 e7 04          	shl    $0x4,%r15
 10f1de0:	4e 8b 84 3c 40 01 00 	mov    0x140(%rsp,%r15,1),%r8
 10f1de7:	00 
 10f1de8:	4d 89 c1             	mov    %r8,%r9
 10f1deb:	49 c1 e9 20          	shr    $0x20,%r9
 10f1def:	4a 8b 8c 3c d0 18 00 	mov    0x18d0(%rsp,%r15,1),%rcx
 10f1df6:	00 
 10f1df7:	4a 8b 84 3c d8 18 00 	mov    0x18d8(%rsp,%r15,1),%rax
 10f1dfe:	00 
 10f1dff:	48 89 cb             	mov    %rcx,%rbx
 10f1e02:	48 c1 eb 20          	shr    $0x20,%rbx
 10f1e06:	49 89 c3             	mov    %rax,%r11
 10f1e09:	49 c1 eb 20          	shr    $0x20,%r11
 10f1e0d:	44 89 c2             	mov    %r8d,%edx
 10f1e10:	44 39 c3             	cmp    %r8d,%ebx
 10f1e13:	4c 89 44 24 48       	mov    %r8,0x48(%rsp)
 10f1e18:	48 89 4c 24 28       	mov    %rcx,0x28(%rsp)
 10f1e1d:	0f 86 dd 00 00 00    	jbe    10f1f00 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x6c0>
 10f1e23:	44 89 c2             	mov    %r8d,%edx
 10f1e26:	44 39 c9             	cmp    %r9d,%ecx
 10f1e29:	0f 83 b6 01 00 00    	jae    10f1fe5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x7a5>
 10f1e2f:	44 39 44 24 28       	cmp    %r8d,0x28(%rsp)
 10f1e34:	0f 86 b6 00 00 00    	jbe    10f1ef0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x6b0>
 10f1e3a:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f1e3f:	48 8b 11             	mov    (%rcx),%rdx
 10f1e42:	44 89 c7             	mov    %r8d,%edi
 10f1e45:	48 8b 74 24 28       	mov    0x28(%rsp),%rsi
 10f1e4a:	4c 29 c6             	sub    %r8,%rsi
 10f1e4d:	89 f1                	mov    %esi,%ecx
 10f1e4f:	48 ff c9             	dec    %rcx
 10f1e52:	48 83 f9 07          	cmp    $0x7,%rcx
 10f1e56:	73 05                	jae    10f1e5d <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x61d>
 10f1e58:	45 31 d2             	xor    %r10d,%r10d
 10f1e5b:	eb 6c                	jmp    10f1ec9 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x689>
 10f1e5d:	4c 8d 2c 3a          	lea    (%rdx,%rdi,1),%r13
 10f1e61:	89 f1                	mov    %esi,%ecx
 10f1e63:	83 e1 f8             	and    $0xfffffff8,%ecx
 10f1e66:	49 83 c5 07          	add    $0x7,%r13
 10f1e6a:	45 31 d2             	xor    %r10d,%r10d
 10f1e6d:	0f 1f 00             	nopl   (%rax)
 10f1e70:	47 0f b6 44 15 f9    	movzbl -0x7(%r13,%r10,1),%r8d
 10f1e76:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1e7a:	47 0f b6 44 15 fa    	movzbl -0x6(%r13,%r10,1),%r8d
 10f1e80:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1e84:	47 0f b6 44 15 fb    	movzbl -0x5(%r13,%r10,1),%r8d
 10f1e8a:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1e8e:	47 0f b6 44 15 fc    	movzbl -0x4(%r13,%r10,1),%r8d
 10f1e94:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1e98:	47 0f b6 44 15 fd    	movzbl -0x3(%r13,%r10,1),%r8d
 10f1e9e:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1ea2:	47 0f b6 44 15 fe    	movzbl -0x2(%r13,%r10,1),%r8d
 10f1ea8:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1eac:	47 0f b6 44 15 ff    	movzbl -0x1(%r13,%r10,1),%r8d
 10f1eb2:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1eb6:	47 0f b6 44 15 00    	movzbl 0x0(%r13,%r10,1),%r8d
 10f1ebc:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1ec0:	49 83 c2 08          	add    $0x8,%r10
 10f1ec4:	4c 39 d1             	cmp    %r10,%rcx
 10f1ec7:	75 a7                	jne    10f1e70 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x630>
 10f1ec9:	83 e6 07             	and    $0x7,%esi
 10f1ecc:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 10f1ed1:	74 1d                	je     10f1ef0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x6b0>
 10f1ed3:	49 01 fa             	add    %rdi,%r10
 10f1ed6:	4c 01 d2             	add    %r10,%rdx
 10f1ed9:	31 c9                	xor    %ecx,%ecx
 10f1edb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 10f1ee0:	0f b6 3c 0a          	movzbl (%rdx,%rcx,1),%edi
 10f1ee4:	41 ff 0c bc          	decl   (%r12,%rdi,4)
 10f1ee8:	48 ff c1             	inc    %rcx
 10f1eeb:	48 39 ce             	cmp    %rcx,%rsi
 10f1eee:	75 f0                	jne    10f1ee0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x6a0>
 10f1ef0:	41 39 d9             	cmp    %ebx,%r9d
 10f1ef3:	89 da                	mov    %ebx,%edx
 10f1ef5:	41 0f 42 d1          	cmovb  %r9d,%edx
 10f1ef9:	41 39 d0             	cmp    %edx,%r8d
 10f1efc:	41 0f 47 d0          	cmova  %r8d,%edx
 10f1f00:	44 39 da             	cmp    %r11d,%edx
 10f1f03:	0f 83 dc 00 00 00    	jae    10f1fe5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x7a5>
 10f1f09:	44 39 c8             	cmp    %r9d,%eax
 10f1f0c:	0f 83 d3 00 00 00    	jae    10f1fe5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x7a5>
 10f1f12:	89 c6                	mov    %eax,%esi
 10f1f14:	29 d6                	sub    %edx,%esi
 10f1f16:	0f 86 b5 00 00 00    	jbe    10f1fd1 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x791>
 10f1f1c:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f1f21:	48 8b 39             	mov    (%rcx),%rdi
 10f1f24:	41 89 d0             	mov    %edx,%r8d
 10f1f27:	89 f1                	mov    %esi,%ecx
 10f1f29:	ff c9                	dec    %ecx
 10f1f2b:	83 f9 07             	cmp    $0x7,%ecx
 10f1f2e:	4c 89 44 24 38       	mov    %r8,0x38(%rsp)
 10f1f33:	73 05                	jae    10f1f3a <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x6fa>
 10f1f35:	45 31 ed             	xor    %r13d,%r13d
 10f1f38:	eb 6e                	jmp    10f1fa8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x768>
 10f1f3a:	4e 8d 14 07          	lea    (%rdi,%r8,1),%r10
 10f1f3e:	89 f1                	mov    %esi,%ecx
 10f1f40:	83 e1 f8             	and    $0xfffffff8,%ecx
 10f1f43:	49 83 c2 07          	add    $0x7,%r10
 10f1f47:	45 31 ed             	xor    %r13d,%r13d
 10f1f4a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 10f1f50:	47 0f b6 44 2a f9    	movzbl -0x7(%r10,%r13,1),%r8d
 10f1f56:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1f5a:	47 0f b6 44 2a fa    	movzbl -0x6(%r10,%r13,1),%r8d
 10f1f60:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1f64:	47 0f b6 44 2a fb    	movzbl -0x5(%r10,%r13,1),%r8d
 10f1f6a:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1f6e:	47 0f b6 44 2a fc    	movzbl -0x4(%r10,%r13,1),%r8d
 10f1f74:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1f78:	47 0f b6 44 2a fd    	movzbl -0x3(%r10,%r13,1),%r8d
 10f1f7e:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1f82:	47 0f b6 44 2a fe    	movzbl -0x2(%r10,%r13,1),%r8d
 10f1f88:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1f8c:	47 0f b6 44 2a ff    	movzbl -0x1(%r10,%r13,1),%r8d
 10f1f92:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1f96:	47 0f b6 04 2a       	movzbl (%r10,%r13,1),%r8d
 10f1f9b:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1f9f:	49 83 c5 08          	add    $0x8,%r13
 10f1fa3:	4c 39 e9             	cmp    %r13,%rcx
 10f1fa6:	75 a8                	jne    10f1f50 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x710>
 10f1fa8:	83 e6 07             	and    $0x7,%esi
 10f1fab:	74 24                	je     10f1fd1 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x791>
 10f1fad:	4c 03 6c 24 38       	add    0x38(%rsp),%r13
 10f1fb2:	4c 01 ef             	add    %r13,%rdi
 10f1fb5:	31 c9                	xor    %ecx,%ecx
 10f1fb7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 10f1fbe:	00 00 
 10f1fc0:	44 0f b6 04 0f       	movzbl (%rdi,%rcx,1),%r8d
 10f1fc5:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f1fc9:	48 ff c1             	inc    %rcx
 10f1fcc:	48 39 ce             	cmp    %rcx,%rsi
 10f1fcf:	75 ef                	jne    10f1fc0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x780>
 10f1fd1:	45 39 d9             	cmp    %r11d,%r9d
 10f1fd4:	44 89 d9             	mov    %r11d,%ecx
 10f1fd7:	41 0f 42 c9          	cmovb  %r9d,%ecx
 10f1fdb:	39 ca                	cmp    %ecx,%edx
 10f1fdd:	0f 46 d1             	cmovbe %ecx,%edx
 10f1fe0:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 10f1fe5:	4e 8b ac 3c 48 01 00 	mov    0x148(%rsp,%r15,1),%r13
 10f1fec:	00 
 10f1fed:	44 89 ce             	mov    %r9d,%esi
 10f1ff0:	29 d6                	sub    %edx,%esi
 10f1ff2:	0f 86 a8 00 00 00    	jbe    10f20a0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x860>
 10f1ff8:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f1ffd:	48 8b 39             	mov    (%rcx),%rdi
 10f2000:	89 d2                	mov    %edx,%edx
 10f2002:	89 f1                	mov    %esi,%ecx
 10f2004:	ff c9                	dec    %ecx
 10f2006:	83 f9 07             	cmp    $0x7,%ecx
 10f2009:	73 05                	jae    10f2010 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x7d0>
 10f200b:	45 31 d2             	xor    %r10d,%r10d
 10f200e:	eb 68                	jmp    10f2078 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x838>
 10f2010:	4c 8d 3c 17          	lea    (%rdi,%rdx,1),%r15
 10f2014:	89 f1                	mov    %esi,%ecx
 10f2016:	83 e1 f8             	and    $0xfffffff8,%ecx
 10f2019:	49 83 c7 07          	add    $0x7,%r15
 10f201d:	45 31 d2             	xor    %r10d,%r10d
 10f2020:	47 0f b6 44 17 f9    	movzbl -0x7(%r15,%r10,1),%r8d
 10f2026:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f202a:	47 0f b6 44 17 fa    	movzbl -0x6(%r15,%r10,1),%r8d
 10f2030:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f2034:	47 0f b6 44 17 fb    	movzbl -0x5(%r15,%r10,1),%r8d
 10f203a:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f203e:	47 0f b6 44 17 fc    	movzbl -0x4(%r15,%r10,1),%r8d
 10f2044:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f2048:	47 0f b6 44 17 fd    	movzbl -0x3(%r15,%r10,1),%r8d
 10f204e:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f2052:	47 0f b6 44 17 fe    	movzbl -0x2(%r15,%r10,1),%r8d
 10f2058:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f205c:	47 0f b6 44 17 ff    	movzbl -0x1(%r15,%r10,1),%r8d
 10f2062:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f2066:	47 0f b6 04 17       	movzbl (%r15,%r10,1),%r8d
 10f206b:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f206f:	49 83 c2 08          	add    $0x8,%r10
 10f2073:	4c 39 d1             	cmp    %r10,%rcx
 10f2076:	75 a8                	jne    10f2020 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x7e0>
 10f2078:	83 e6 07             	and    $0x7,%esi
 10f207b:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 10f2080:	74 1e                	je     10f20a0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x860>
 10f2082:	49 01 d2             	add    %rdx,%r10
 10f2085:	4c 01 d7             	add    %r10,%rdi
 10f2088:	31 c9                	xor    %ecx,%ecx
 10f208a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 10f2090:	0f b6 14 0f          	movzbl (%rdi,%rcx,1),%edx
 10f2094:	41 ff 0c 94          	decl   (%r12,%rdx,4)
 10f2098:	48 ff c1             	inc    %rcx
 10f209b:	48 39 ce             	cmp    %rcx,%rsi
 10f209e:	75 f0                	jne    10f2090 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x850>
 10f20a0:	4d 89 ef             	mov    %r13,%r15
 10f20a3:	49 c1 ef 20          	shr    $0x20,%r15
 10f20a7:	44 89 ea             	mov    %r13d,%edx
 10f20aa:	44 39 eb             	cmp    %r13d,%ebx
 10f20ad:	0f 86 ed 00 00 00    	jbe    10f21a0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x960>
 10f20b3:	44 89 ea             	mov    %r13d,%edx
 10f20b6:	44 39 7c 24 28       	cmp    %r15d,0x28(%rsp)
 10f20bb:	0f 83 d3 01 00 00    	jae    10f2294 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xa54>
 10f20c1:	44 39 6c 24 28       	cmp    %r13d,0x28(%rsp)
 10f20c6:	0f 86 c4 00 00 00    	jbe    10f2190 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x950>
 10f20cc:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f20d1:	48 8b 11             	mov    (%rcx),%rdx
 10f20d4:	44 89 ef             	mov    %r13d,%edi
 10f20d7:	48 8b 74 24 28       	mov    0x28(%rsp),%rsi
 10f20dc:	4c 29 ee             	sub    %r13,%rsi
 10f20df:	89 f1                	mov    %esi,%ecx
 10f20e1:	48 ff c9             	dec    %rcx
 10f20e4:	48 83 f9 07          	cmp    $0x7,%rcx
 10f20e8:	48 89 7c 24 38       	mov    %rdi,0x38(%rsp)
 10f20ed:	73 05                	jae    10f20f4 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x8b4>
 10f20ef:	45 31 d2             	xor    %r10d,%r10d
 10f20f2:	eb 74                	jmp    10f2168 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x928>
 10f20f4:	48 01 d7             	add    %rdx,%rdi
 10f20f7:	89 f1                	mov    %esi,%ecx
 10f20f9:	83 e1 f8             	and    $0xfffffff8,%ecx
 10f20fc:	48 83 c7 07          	add    $0x7,%rdi
 10f2100:	45 31 d2             	xor    %r10d,%r10d
 10f2103:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10f210a:	84 00 00 00 00 00 
 10f2110:	46 0f b6 44 17 f9    	movzbl -0x7(%rdi,%r10,1),%r8d
 10f2116:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f211a:	46 0f b6 44 17 fa    	movzbl -0x6(%rdi,%r10,1),%r8d
 10f2120:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f2124:	46 0f b6 44 17 fb    	movzbl -0x5(%rdi,%r10,1),%r8d
 10f212a:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f212e:	46 0f b6 44 17 fc    	movzbl -0x4(%rdi,%r10,1),%r8d
 10f2134:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f2138:	46 0f b6 44 17 fd    	movzbl -0x3(%rdi,%r10,1),%r8d
 10f213e:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f2142:	46 0f b6 44 17 fe    	movzbl -0x2(%rdi,%r10,1),%r8d
 10f2148:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f214c:	46 0f b6 44 17 ff    	movzbl -0x1(%rdi,%r10,1),%r8d
 10f2152:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f2156:	46 0f b6 04 17       	movzbl (%rdi,%r10,1),%r8d
 10f215b:	43 ff 0c 84          	decl   (%r12,%r8,4)
 10f215f:	49 83 c2 08          	add    $0x8,%r10
 10f2163:	4c 39 d1             	cmp    %r10,%rcx
 10f2166:	75 a8                	jne    10f2110 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x8d0>
 10f2168:	83 e6 07             	and    $0x7,%esi
 10f216b:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 10f2170:	74 1e                	je     10f2190 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x950>
 10f2172:	4c 03 54 24 38       	add    0x38(%rsp),%r10
 10f2177:	4c 01 d2             	add    %r10,%rdx
 10f217a:	31 c9                	xor    %ecx,%ecx
 10f217c:	0f 1f 40 00          	nopl   0x0(%rax)
 10f2180:	0f b6 3c 0a          	movzbl (%rdx,%rcx,1),%edi
 10f2184:	41 ff 0c bc          	decl   (%r12,%rdi,4)
 10f2188:	48 ff c1             	inc    %rcx
 10f218b:	48 39 ce             	cmp    %rcx,%rsi
 10f218e:	75 f0                	jne    10f2180 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x940>
 10f2190:	41 39 df             	cmp    %ebx,%r15d
 10f2193:	89 da                	mov    %ebx,%edx
 10f2195:	41 0f 42 d7          	cmovb  %r15d,%edx
 10f2199:	41 39 d5             	cmp    %edx,%r13d
 10f219c:	41 0f 47 d5          	cmova  %r13d,%edx
 10f21a0:	44 39 da             	cmp    %r11d,%edx
 10f21a3:	0f 83 eb 00 00 00    	jae    10f2294 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xa54>
 10f21a9:	44 39 f8             	cmp    %r15d,%eax
 10f21ac:	0f 83 e2 00 00 00    	jae    10f2294 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xa54>
 10f21b2:	41 89 c0             	mov    %eax,%r8d
 10f21b5:	41 29 d0             	sub    %edx,%r8d
 10f21b8:	0f 86 c2 00 00 00    	jbe    10f2280 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xa40>
 10f21be:	4c 89 74 24 38       	mov    %r14,0x38(%rsp)
 10f21c3:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f21c8:	48 8b 39             	mov    (%rcx),%rdi
 10f21cb:	89 d6                	mov    %edx,%esi
 10f21cd:	44 89 c1             	mov    %r8d,%ecx
 10f21d0:	ff c9                	dec    %ecx
 10f21d2:	83 f9 07             	cmp    $0x7,%ecx
 10f21d5:	48 89 b4 24 c0 00 00 	mov    %rsi,0xc0(%rsp)
 10f21dc:	00 
 10f21dd:	73 05                	jae    10f21e4 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x9a4>
 10f21df:	45 31 d2             	xor    %r10d,%r10d
 10f21e2:	eb 74                	jmp    10f2258 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xa18>
 10f21e4:	48 8d 0c 37          	lea    (%rdi,%rsi,1),%rcx
 10f21e8:	44 89 c6             	mov    %r8d,%esi
 10f21eb:	83 e6 f8             	and    $0xfffffff8,%esi
 10f21ee:	48 83 c1 07          	add    $0x7,%rcx
 10f21f2:	45 31 d2             	xor    %r10d,%r10d
 10f21f5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 10f21fc:	00 00 00 00 
 10f2200:	46 0f b6 74 11 f9    	movzbl -0x7(%rcx,%r10,1),%r14d
 10f2206:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f220a:	46 0f b6 74 11 fa    	movzbl -0x6(%rcx,%r10,1),%r14d
 10f2210:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f2214:	46 0f b6 74 11 fb    	movzbl -0x5(%rcx,%r10,1),%r14d
 10f221a:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f221e:	46 0f b6 74 11 fc    	movzbl -0x4(%rcx,%r10,1),%r14d
 10f2224:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f2228:	46 0f b6 74 11 fd    	movzbl -0x3(%rcx,%r10,1),%r14d
 10f222e:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f2232:	46 0f b6 74 11 fe    	movzbl -0x2(%rcx,%r10,1),%r14d
 10f2238:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f223c:	46 0f b6 74 11 ff    	movzbl -0x1(%rcx,%r10,1),%r14d
 10f2242:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f2246:	46 0f b6 34 11       	movzbl (%rcx,%r10,1),%r14d
 10f224b:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f224f:	49 83 c2 08          	add    $0x8,%r10
 10f2253:	4c 39 d6             	cmp    %r10,%rsi
 10f2256:	75 a8                	jne    10f2200 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x9c0>
 10f2258:	41 83 e0 07          	and    $0x7,%r8d
 10f225c:	4c 8b 74 24 38       	mov    0x38(%rsp),%r14
 10f2261:	74 1d                	je     10f2280 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xa40>
 10f2263:	4c 03 94 24 c0 00 00 	add    0xc0(%rsp),%r10
 10f226a:	00 
 10f226b:	4c 01 d7             	add    %r10,%rdi
 10f226e:	31 c9                	xor    %ecx,%ecx
 10f2270:	0f b6 34 0f          	movzbl (%rdi,%rcx,1),%esi
 10f2274:	41 ff 0c b4          	decl   (%r12,%rsi,4)
 10f2278:	48 ff c1             	inc    %rcx
 10f227b:	49 39 c8             	cmp    %rcx,%r8
 10f227e:	75 f0                	jne    10f2270 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xa30>
 10f2280:	45 39 df             	cmp    %r11d,%r15d
 10f2283:	44 89 d9             	mov    %r11d,%ecx
 10f2286:	41 0f 42 cf          	cmovb  %r15d,%ecx
 10f228a:	39 ca                	cmp    %ecx,%edx
 10f228c:	0f 46 d1             	cmovbe %ecx,%edx
 10f228f:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 10f2294:	44 89 fe             	mov    %r15d,%esi
 10f2297:	29 d6                	sub    %edx,%esi
 10f2299:	0f 86 e1 00 00 00    	jbe    10f2380 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xb40>
 10f229f:	4c 89 4c 24 38       	mov    %r9,0x38(%rsp)
 10f22a4:	49 89 c1             	mov    %rax,%r9
 10f22a7:	4c 89 f0             	mov    %r14,%rax
 10f22aa:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f22af:	48 8b 39             	mov    (%rcx),%rdi
 10f22b2:	89 d2                	mov    %edx,%edx
 10f22b4:	89 f1                	mov    %esi,%ecx
 10f22b6:	ff c9                	dec    %ecx
 10f22b8:	83 f9 07             	cmp    $0x7,%ecx
 10f22bb:	73 13                	jae    10f22d0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xa90>
 10f22bd:	45 31 d2             	xor    %r10d,%r10d
 10f22c0:	e9 83 00 00 00       	jmp    10f2348 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xb08>
 10f22c5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 10f22cc:	00 00 00 00 
 10f22d0:	48 8d 0c 17          	lea    (%rdi,%rdx,1),%rcx
 10f22d4:	41 89 f0             	mov    %esi,%r8d
 10f22d7:	41 83 e0 f8          	and    $0xfffffff8,%r8d
 10f22db:	48 83 c1 07          	add    $0x7,%rcx
 10f22df:	45 31 d2             	xor    %r10d,%r10d
 10f22e2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10f22e9:	1f 84 00 00 00 00 00 
 10f22f0:	46 0f b6 74 11 f9    	movzbl -0x7(%rcx,%r10,1),%r14d
 10f22f6:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f22fa:	46 0f b6 74 11 fa    	movzbl -0x6(%rcx,%r10,1),%r14d
 10f2300:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f2304:	46 0f b6 74 11 fb    	movzbl -0x5(%rcx,%r10,1),%r14d
 10f230a:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f230e:	46 0f b6 74 11 fc    	movzbl -0x4(%rcx,%r10,1),%r14d
 10f2314:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f2318:	46 0f b6 74 11 fd    	movzbl -0x3(%rcx,%r10,1),%r14d
 10f231e:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f2322:	46 0f b6 74 11 fe    	movzbl -0x2(%rcx,%r10,1),%r14d
 10f2328:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f232c:	46 0f b6 74 11 ff    	movzbl -0x1(%rcx,%r10,1),%r14d
 10f2332:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f2336:	46 0f b6 34 11       	movzbl (%rcx,%r10,1),%r14d
 10f233b:	43 ff 0c b4          	decl   (%r12,%r14,4)
 10f233f:	49 83 c2 08          	add    $0x8,%r10
 10f2343:	4d 39 d0             	cmp    %r10,%r8
 10f2346:	75 a8                	jne    10f22f0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xab0>
 10f2348:	83 e6 07             	and    $0x7,%esi
 10f234b:	49 89 c6             	mov    %rax,%r14
 10f234e:	4c 89 c8             	mov    %r9,%rax
 10f2351:	4c 8b 4c 24 38       	mov    0x38(%rsp),%r9
 10f2356:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 10f235b:	74 23                	je     10f2380 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xb40>
 10f235d:	49 01 d2             	add    %rdx,%r10
 10f2360:	4c 01 d7             	add    %r10,%rdi
 10f2363:	31 c9                	xor    %ecx,%ecx
 10f2365:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 10f236c:	00 00 00 00 
 10f2370:	0f b6 14 0f          	movzbl (%rdi,%rcx,1),%edx
 10f2374:	41 ff 0c 94          	decl   (%r12,%rdx,4)
 10f2378:	48 ff c1             	inc    %rcx
 10f237b:	48 39 ce             	cmp    %rcx,%rsi
 10f237e:	75 f0                	jne    10f2370 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xb30>
 10f2380:	48 8b 74 24 28       	mov    0x28(%rsp),%rsi
 10f2385:	41 39 f1             	cmp    %esi,%r9d
 10f2388:	0f 86 e7 00 00 00    	jbe    10f2475 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xc35>
 10f238e:	44 39 c3             	cmp    %r8d,%ebx
 10f2391:	0f 86 de 01 00 00    	jbe    10f2575 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xd35>
 10f2397:	41 39 f0             	cmp    %esi,%r8d
 10f239a:	0f 86 c0 00 00 00    	jbe    10f2460 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xc20>
 10f23a0:	4c 89 74 24 38       	mov    %r14,0x38(%rsp)
 10f23a5:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f23aa:	48 8b 11             	mov    (%rcx),%rdx
 10f23ad:	48 8b 4c 24 28       	mov    0x28(%rsp),%rcx
 10f23b2:	89 cf                	mov    %ecx,%edi
 10f23b4:	4c 89 c6             	mov    %r8,%rsi
 10f23b7:	48 29 ce             	sub    %rcx,%rsi
 10f23ba:	89 f1                	mov    %esi,%ecx
 10f23bc:	48 ff c9             	dec    %rcx
 10f23bf:	48 83 f9 07          	cmp    $0x7,%rcx
 10f23c3:	73 05                	jae    10f23ca <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xb8a>
 10f23c5:	45 31 d2             	xor    %r10d,%r10d
 10f23c8:	eb 6e                	jmp    10f2438 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xbf8>
 10f23ca:	48 8d 0c 3a          	lea    (%rdx,%rdi,1),%rcx
 10f23ce:	41 89 f0             	mov    %esi,%r8d
 10f23d1:	41 83 e0 f8          	and    $0xfffffff8,%r8d
 10f23d5:	48 83 c1 07          	add    $0x7,%rcx
 10f23d9:	45 31 d2             	xor    %r10d,%r10d
 10f23dc:	0f 1f 40 00          	nopl   0x0(%rax)
 10f23e0:	46 0f b6 74 11 f9    	movzbl -0x7(%rcx,%r10,1),%r14d
 10f23e6:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f23ea:	46 0f b6 74 11 fa    	movzbl -0x6(%rcx,%r10,1),%r14d
 10f23f0:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f23f4:	46 0f b6 74 11 fb    	movzbl -0x5(%rcx,%r10,1),%r14d
 10f23fa:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f23fe:	46 0f b6 74 11 fc    	movzbl -0x4(%rcx,%r10,1),%r14d
 10f2404:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f2408:	46 0f b6 74 11 fd    	movzbl -0x3(%rcx,%r10,1),%r14d
 10f240e:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f2412:	46 0f b6 74 11 fe    	movzbl -0x2(%rcx,%r10,1),%r14d
 10f2418:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f241c:	46 0f b6 74 11 ff    	movzbl -0x1(%rcx,%r10,1),%r14d
 10f2422:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f2426:	46 0f b6 34 11       	movzbl (%rcx,%r10,1),%r14d
 10f242b:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f242f:	49 83 c2 08          	add    $0x8,%r10
 10f2433:	4d 39 d0             	cmp    %r10,%r8
 10f2436:	75 a8                	jne    10f23e0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xba0>
 10f2438:	83 e6 07             	and    $0x7,%esi
 10f243b:	4c 8b 74 24 38       	mov    0x38(%rsp),%r14
 10f2440:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 10f2445:	74 19                	je     10f2460 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xc20>
 10f2447:	49 01 fa             	add    %rdi,%r10
 10f244a:	4c 01 d2             	add    %r10,%rdx
 10f244d:	31 c9                	xor    %ecx,%ecx
 10f244f:	90                   	nop
 10f2450:	0f b6 3c 0a          	movzbl (%rdx,%rcx,1),%edi
 10f2454:	41 ff 04 bc          	incl   (%r12,%rdi,4)
 10f2458:	48 ff c1             	inc    %rcx
 10f245b:	48 39 ce             	cmp    %rcx,%rsi
 10f245e:	75 f0                	jne    10f2450 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xc10>
 10f2460:	44 39 cb             	cmp    %r9d,%ebx
 10f2463:	44 89 c9             	mov    %r9d,%ecx
 10f2466:	0f 42 cb             	cmovb  %ebx,%ecx
 10f2469:	48 8b 54 24 28       	mov    0x28(%rsp),%rdx
 10f246e:	39 ca                	cmp    %ecx,%edx
 10f2470:	0f 47 ca             	cmova  %edx,%ecx
 10f2473:	89 ce                	mov    %ecx,%esi
 10f2475:	44 39 eb             	cmp    %r13d,%ebx
 10f2478:	0f 86 f7 00 00 00    	jbe    10f2575 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xd35>
 10f247e:	44 39 fe             	cmp    %r15d,%esi
 10f2481:	0f 83 ee 00 00 00    	jae    10f2575 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xd35>
 10f2487:	44 89 ea             	mov    %r13d,%edx
 10f248a:	48 89 74 24 28       	mov    %rsi,0x28(%rsp)
 10f248f:	29 f2                	sub    %esi,%edx
 10f2491:	0f 86 c9 00 00 00    	jbe    10f2560 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xd20>
 10f2497:	4c 89 4c 24 38       	mov    %r9,0x38(%rsp)
 10f249c:	49 89 c1             	mov    %rax,%r9
 10f249f:	4c 89 f0             	mov    %r14,%rax
 10f24a2:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f24a7:	48 8b 31             	mov    (%rcx),%rsi
 10f24aa:	8b 7c 24 28          	mov    0x28(%rsp),%edi
 10f24ae:	89 d1                	mov    %edx,%ecx
 10f24b0:	ff c9                	dec    %ecx
 10f24b2:	83 f9 07             	cmp    $0x7,%ecx
 10f24b5:	73 05                	jae    10f24bc <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xc7c>
 10f24b7:	45 31 d2             	xor    %r10d,%r10d
 10f24ba:	eb 6c                	jmp    10f2528 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xce8>
 10f24bc:	48 8d 0c 3e          	lea    (%rsi,%rdi,1),%rcx
 10f24c0:	41 89 d0             	mov    %edx,%r8d
 10f24c3:	41 83 e0 f8          	and    $0xfffffff8,%r8d
 10f24c7:	48 83 c1 07          	add    $0x7,%rcx
 10f24cb:	45 31 d2             	xor    %r10d,%r10d
 10f24ce:	66 90                	xchg   %ax,%ax
 10f24d0:	46 0f b6 74 11 f9    	movzbl -0x7(%rcx,%r10,1),%r14d
 10f24d6:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f24da:	46 0f b6 74 11 fa    	movzbl -0x6(%rcx,%r10,1),%r14d
 10f24e0:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f24e4:	46 0f b6 74 11 fb    	movzbl -0x5(%rcx,%r10,1),%r14d
 10f24ea:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f24ee:	46 0f b6 74 11 fc    	movzbl -0x4(%rcx,%r10,1),%r14d
 10f24f4:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f24f8:	46 0f b6 74 11 fd    	movzbl -0x3(%rcx,%r10,1),%r14d
 10f24fe:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f2502:	46 0f b6 74 11 fe    	movzbl -0x2(%rcx,%r10,1),%r14d
 10f2508:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f250c:	46 0f b6 74 11 ff    	movzbl -0x1(%rcx,%r10,1),%r14d
 10f2512:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f2516:	46 0f b6 34 11       	movzbl (%rcx,%r10,1),%r14d
 10f251b:	43 ff 04 b4          	incl   (%r12,%r14,4)
 10f251f:	49 83 c2 08          	add    $0x8,%r10
 10f2523:	4d 39 d0             	cmp    %r10,%r8
 10f2526:	75 a8                	jne    10f24d0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xc90>
 10f2528:	83 e2 07             	and    $0x7,%edx
 10f252b:	49 89 c6             	mov    %rax,%r14
 10f252e:	4c 89 c8             	mov    %r9,%rax
 10f2531:	4c 8b 4c 24 38       	mov    0x38(%rsp),%r9
 10f2536:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 10f253b:	74 23                	je     10f2560 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xd20>
 10f253d:	49 01 fa             	add    %rdi,%r10
 10f2540:	4c 01 d6             	add    %r10,%rsi
 10f2543:	31 c9                	xor    %ecx,%ecx
 10f2545:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 10f254c:	00 00 00 00 
 10f2550:	0f b6 3c 0e          	movzbl (%rsi,%rcx,1),%edi
 10f2554:	41 ff 04 bc          	incl   (%r12,%rdi,4)
 10f2558:	48 ff c1             	inc    %rcx
 10f255b:	48 39 ca             	cmp    %rcx,%rdx
 10f255e:	75 f0                	jne    10f2550 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xd10>
 10f2560:	44 39 fb             	cmp    %r15d,%ebx
 10f2563:	44 89 f9             	mov    %r15d,%ecx
 10f2566:	0f 42 cb             	cmovb  %ebx,%ecx
 10f2569:	48 8b 54 24 28       	mov    0x28(%rsp),%rdx
 10f256e:	39 ca                	cmp    %ecx,%edx
 10f2570:	0f 47 ca             	cmova  %edx,%ecx
 10f2573:	89 ce                	mov    %ecx,%esi
 10f2575:	29 f3                	sub    %esi,%ebx
 10f2577:	0f 86 c3 00 00 00    	jbe    10f2640 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xe00>
 10f257d:	4d 89 ca             	mov    %r9,%r10
 10f2580:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f2585:	48 8b 11             	mov    (%rcx),%rdx
 10f2588:	89 f6                	mov    %esi,%esi
 10f258a:	89 d9                	mov    %ebx,%ecx
 10f258c:	ff c9                	dec    %ecx
 10f258e:	83 f9 07             	cmp    $0x7,%ecx
 10f2591:	73 0d                	jae    10f25a0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xd60>
 10f2593:	31 ff                	xor    %edi,%edi
 10f2595:	e9 7e 00 00 00       	jmp    10f2618 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xdd8>
 10f259a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 10f25a0:	48 8d 0c 32          	lea    (%rdx,%rsi,1),%rcx
 10f25a4:	41 89 d8             	mov    %ebx,%r8d
 10f25a7:	41 83 e0 f8          	and    $0xfffffff8,%r8d
 10f25ab:	48 83 c1 07          	add    $0x7,%rcx
 10f25af:	31 ff                	xor    %edi,%edi
 10f25b1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10f25b8:	0f 1f 84 00 00 00 00 
 10f25bf:	00 
 10f25c0:	44 0f b6 4c 39 f9    	movzbl -0x7(%rcx,%rdi,1),%r9d
 10f25c6:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f25ca:	44 0f b6 4c 39 fa    	movzbl -0x6(%rcx,%rdi,1),%r9d
 10f25d0:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f25d4:	44 0f b6 4c 39 fb    	movzbl -0x5(%rcx,%rdi,1),%r9d
 10f25da:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f25de:	44 0f b6 4c 39 fc    	movzbl -0x4(%rcx,%rdi,1),%r9d
 10f25e4:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f25e8:	44 0f b6 4c 39 fd    	movzbl -0x3(%rcx,%rdi,1),%r9d
 10f25ee:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f25f2:	44 0f b6 4c 39 fe    	movzbl -0x2(%rcx,%rdi,1),%r9d
 10f25f8:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f25fc:	44 0f b6 4c 39 ff    	movzbl -0x1(%rcx,%rdi,1),%r9d
 10f2602:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f2606:	44 0f b6 0c 39       	movzbl (%rcx,%rdi,1),%r9d
 10f260b:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f260f:	48 83 c7 08          	add    $0x8,%rdi
 10f2613:	49 39 f8             	cmp    %rdi,%r8
 10f2616:	75 a8                	jne    10f25c0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xd80>
 10f2618:	83 e3 07             	and    $0x7,%ebx
 10f261b:	4d 89 d1             	mov    %r10,%r9
 10f261e:	4c 8b 44 24 48       	mov    0x48(%rsp),%r8
 10f2623:	74 1b                	je     10f2640 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xe00>
 10f2625:	48 01 f7             	add    %rsi,%rdi
 10f2628:	48 01 fa             	add    %rdi,%rdx
 10f262b:	31 c9                	xor    %ecx,%ecx
 10f262d:	0f 1f 00             	nopl   (%rax)
 10f2630:	0f b6 34 0a          	movzbl (%rdx,%rcx,1),%esi
 10f2634:	41 ff 04 b4          	incl   (%r12,%rsi,4)
 10f2638:	48 ff c1             	inc    %rcx
 10f263b:	48 39 cb             	cmp    %rcx,%rbx
 10f263e:	75 f0                	jne    10f2630 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xdf0>
 10f2640:	41 39 c1             	cmp    %eax,%r9d
 10f2643:	76 3b                	jbe    10f2680 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xe40>
 10f2645:	45 39 d8             	cmp    %r11d,%r8d
 10f2648:	48 8b 74 24 20       	mov    0x20(%rsp),%rsi
 10f264d:	0f 83 ce 01 00 00    	jae    10f2821 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xfe1>
 10f2653:	41 39 c0             	cmp    %eax,%r8d
 10f2656:	0f 86 d4 00 00 00    	jbe    10f2730 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xef0>
 10f265c:	4c 89 4c 24 38       	mov    %r9,0x38(%rsp)
 10f2661:	48 8b 16             	mov    (%rsi),%rdx
 10f2664:	41 89 c2             	mov    %eax,%r10d
 10f2667:	49 29 c0             	sub    %rax,%r8
 10f266a:	44 89 c1             	mov    %r8d,%ecx
 10f266d:	48 ff c9             	dec    %rcx
 10f2670:	48 83 f9 07          	cmp    $0x7,%rcx
 10f2674:	73 1d                	jae    10f2693 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xe53>
 10f2676:	4c 89 c3             	mov    %r8,%rbx
 10f2679:	31 ff                	xor    %edi,%edi
 10f267b:	e9 88 00 00 00       	jmp    10f2708 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xec8>
 10f2680:	48 8b 74 24 20       	mov    0x20(%rsp),%rsi
 10f2685:	44 39 f8             	cmp    %r15d,%eax
 10f2688:	0f 82 bc 00 00 00    	jb     10f274a <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xf0a>
 10f268e:	e9 8e 01 00 00       	jmp    10f2821 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xfe1>
 10f2693:	4a 8d 0c 12          	lea    (%rdx,%r10,1),%rcx
 10f2697:	4c 89 c3             	mov    %r8,%rbx
 10f269a:	41 83 e0 f8          	and    $0xfffffff8,%r8d
 10f269e:	48 83 c1 07          	add    $0x7,%rcx
 10f26a2:	31 ff                	xor    %edi,%edi
 10f26a4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 10f26ab:	00 00 00 00 00 
 10f26b0:	44 0f b6 4c 39 f9    	movzbl -0x7(%rcx,%rdi,1),%r9d
 10f26b6:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f26ba:	44 0f b6 4c 39 fa    	movzbl -0x6(%rcx,%rdi,1),%r9d
 10f26c0:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f26c4:	44 0f b6 4c 39 fb    	movzbl -0x5(%rcx,%rdi,1),%r9d
 10f26ca:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f26ce:	44 0f b6 4c 39 fc    	movzbl -0x4(%rcx,%rdi,1),%r9d
 10f26d4:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f26d8:	44 0f b6 4c 39 fd    	movzbl -0x3(%rcx,%rdi,1),%r9d
 10f26de:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f26e2:	44 0f b6 4c 39 fe    	movzbl -0x2(%rcx,%rdi,1),%r9d
 10f26e8:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f26ec:	44 0f b6 4c 39 ff    	movzbl -0x1(%rcx,%rdi,1),%r9d
 10f26f2:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f26f6:	44 0f b6 0c 39       	movzbl (%rcx,%rdi,1),%r9d
 10f26fb:	43 ff 04 8c          	incl   (%r12,%r9,4)
 10f26ff:	48 83 c7 08          	add    $0x8,%rdi
 10f2703:	49 39 f8             	cmp    %rdi,%r8
 10f2706:	75 a8                	jne    10f26b0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xe70>
 10f2708:	83 e3 07             	and    $0x7,%ebx
 10f270b:	4c 8b 4c 24 38       	mov    0x38(%rsp),%r9
 10f2710:	74 1e                	je     10f2730 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xef0>
 10f2712:	4c 01 d7             	add    %r10,%rdi
 10f2715:	48 01 fa             	add    %rdi,%rdx
 10f2718:	31 c9                	xor    %ecx,%ecx
 10f271a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 10f2720:	0f b6 3c 0a          	movzbl (%rdx,%rcx,1),%edi
 10f2724:	41 ff 04 bc          	incl   (%r12,%rdi,4)
 10f2728:	48 ff c1             	inc    %rcx
 10f272b:	48 39 cb             	cmp    %rcx,%rbx
 10f272e:	75 f0                	jne    10f2720 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xee0>
 10f2730:	45 39 cb             	cmp    %r9d,%r11d
 10f2733:	45 0f 42 cb          	cmovb  %r11d,%r9d
 10f2737:	44 39 c8             	cmp    %r9d,%eax
 10f273a:	44 0f 47 c8          	cmova  %eax,%r9d
 10f273e:	44 89 c8             	mov    %r9d,%eax
 10f2741:	44 39 f8             	cmp    %r15d,%eax
 10f2744:	0f 83 d7 00 00 00    	jae    10f2821 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xfe1>
 10f274a:	45 39 dd             	cmp    %r11d,%r13d
 10f274d:	0f 83 ce 00 00 00    	jae    10f2821 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xfe1>
 10f2753:	49 89 c2             	mov    %rax,%r10
 10f2756:	41 29 c5             	sub    %eax,%r13d
 10f2759:	0f 86 b1 00 00 00    	jbe    10f2810 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xfd0>
 10f275f:	48 8b 06             	mov    (%rsi),%rax
 10f2762:	44 89 d2             	mov    %r10d,%edx
 10f2765:	44 89 e9             	mov    %r13d,%ecx
 10f2768:	ff c9                	dec    %ecx
 10f276a:	83 f9 07             	cmp    $0x7,%ecx
 10f276d:	73 05                	jae    10f2774 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xf34>
 10f276f:	45 31 c9             	xor    %r9d,%r9d
 10f2772:	eb 74                	jmp    10f27e8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xfa8>
 10f2774:	48 8d 0c 10          	lea    (%rax,%rdx,1),%rcx
 10f2778:	44 89 ef             	mov    %r13d,%edi
 10f277b:	83 e7 f8             	and    $0xfffffff8,%edi
 10f277e:	48 83 c1 07          	add    $0x7,%rcx
 10f2782:	45 31 c9             	xor    %r9d,%r9d
 10f2785:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 10f278c:	00 00 00 00 
 10f2790:	46 0f b6 44 09 f9    	movzbl -0x7(%rcx,%r9,1),%r8d
 10f2796:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f279a:	46 0f b6 44 09 fa    	movzbl -0x6(%rcx,%r9,1),%r8d
 10f27a0:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f27a4:	46 0f b6 44 09 fb    	movzbl -0x5(%rcx,%r9,1),%r8d
 10f27aa:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f27ae:	46 0f b6 44 09 fc    	movzbl -0x4(%rcx,%r9,1),%r8d
 10f27b4:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f27b8:	46 0f b6 44 09 fd    	movzbl -0x3(%rcx,%r9,1),%r8d
 10f27be:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f27c2:	46 0f b6 44 09 fe    	movzbl -0x2(%rcx,%r9,1),%r8d
 10f27c8:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f27cc:	46 0f b6 44 09 ff    	movzbl -0x1(%rcx,%r9,1),%r8d
 10f27d2:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f27d6:	46 0f b6 04 09       	movzbl (%rcx,%r9,1),%r8d
 10f27db:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f27df:	49 83 c1 08          	add    $0x8,%r9
 10f27e3:	4c 39 cf             	cmp    %r9,%rdi
 10f27e6:	75 a8                	jne    10f2790 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xf50>
 10f27e8:	41 83 e5 07          	and    $0x7,%r13d
 10f27ec:	74 22                	je     10f2810 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xfd0>
 10f27ee:	49 01 d1             	add    %rdx,%r9
 10f27f1:	4c 01 c8             	add    %r9,%rax
 10f27f4:	31 c9                	xor    %ecx,%ecx
 10f27f6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 10f27fd:	00 00 00 
 10f2800:	0f b6 14 08          	movzbl (%rax,%rcx,1),%edx
 10f2804:	41 ff 04 94          	incl   (%r12,%rdx,4)
 10f2808:	48 ff c1             	inc    %rcx
 10f280b:	49 39 cd             	cmp    %rcx,%r13
 10f280e:	75 f0                	jne    10f2800 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0xfc0>
 10f2810:	45 39 fb             	cmp    %r15d,%r11d
 10f2813:	45 0f 42 fb          	cmovb  %r11d,%r15d
 10f2817:	45 39 fa             	cmp    %r15d,%r10d
 10f281a:	45 0f 47 fa          	cmova  %r10d,%r15d
 10f281e:	44 89 f8             	mov    %r15d,%eax
 10f2821:	41 29 c3             	sub    %eax,%r11d
 10f2824:	0f 86 96 f5 ff ff    	jbe    10f1dc0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x580>
 10f282a:	48 89 c1             	mov    %rax,%rcx
 10f282d:	48 8b 06             	mov    (%rsi),%rax
 10f2830:	89 ca                	mov    %ecx,%edx
 10f2832:	44 89 d9             	mov    %r11d,%ecx
 10f2835:	ff c9                	dec    %ecx
 10f2837:	83 f9 07             	cmp    $0x7,%ecx
 10f283a:	73 14                	jae    10f2850 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1010>
 10f283c:	45 31 c9             	xor    %r9d,%r9d
 10f283f:	e9 84 00 00 00       	jmp    10f28c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1088>
 10f2844:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 10f284b:	00 00 00 00 00 
 10f2850:	48 8d 0c 10          	lea    (%rax,%rdx,1),%rcx
 10f2854:	44 89 df             	mov    %r11d,%edi
 10f2857:	83 e7 f8             	and    $0xfffffff8,%edi
 10f285a:	48 83 c1 07          	add    $0x7,%rcx
 10f285e:	45 31 c9             	xor    %r9d,%r9d
 10f2861:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10f2868:	0f 1f 84 00 00 00 00 
 10f286f:	00 
 10f2870:	46 0f b6 44 09 f9    	movzbl -0x7(%rcx,%r9,1),%r8d
 10f2876:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f287a:	46 0f b6 44 09 fa    	movzbl -0x6(%rcx,%r9,1),%r8d
 10f2880:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f2884:	46 0f b6 44 09 fb    	movzbl -0x5(%rcx,%r9,1),%r8d
 10f288a:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f288e:	46 0f b6 44 09 fc    	movzbl -0x4(%rcx,%r9,1),%r8d
 10f2894:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f2898:	46 0f b6 44 09 fd    	movzbl -0x3(%rcx,%r9,1),%r8d
 10f289e:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f28a2:	46 0f b6 44 09 fe    	movzbl -0x2(%rcx,%r9,1),%r8d
 10f28a8:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f28ac:	46 0f b6 44 09 ff    	movzbl -0x1(%rcx,%r9,1),%r8d
 10f28b2:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f28b6:	46 0f b6 04 09       	movzbl (%rcx,%r9,1),%r8d
 10f28bb:	43 ff 04 84          	incl   (%r12,%r8,4)
 10f28bf:	49 83 c1 08          	add    $0x8,%r9
 10f28c3:	4c 39 cf             	cmp    %r9,%rdi
 10f28c6:	75 a8                	jne    10f2870 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1030>
 10f28c8:	41 83 e3 07          	and    $0x7,%r11d
 10f28cc:	0f 84 ee f4 ff ff    	je     10f1dc0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x580>
 10f28d2:	49 01 d1             	add    %rdx,%r9
 10f28d5:	4c 01 c8             	add    %r9,%rax
 10f28d8:	31 c9                	xor    %ecx,%ecx
 10f28da:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 10f28e0:	0f b6 14 08          	movzbl (%rax,%rcx,1),%edx
 10f28e4:	41 ff 04 94          	incl   (%r12,%rdx,4)
 10f28e8:	48 ff c1             	inc    %rcx
 10f28eb:	49 39 cb             	cmp    %rcx,%r11
 10f28ee:	75 f0                	jne    10f28e0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x10a0>
 10f28f0:	e9 cb f4 ff ff       	jmp    10f1dc0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x580>
 10f28f5:	c5 fe 6f 84 24 80 01 	vmovdqu 0x180(%rsp),%ymm0
 10f28fc:	00 00 
 10f28fe:	c5 fc 10 8c 24 a0 01 	vmovups 0x1a0(%rsp),%ymm1
 10f2905:	00 00 
 10f2907:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 10f290e:	00 
 10f290f:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 10f2914:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 10f2918:	4c 8b 74 24 58       	mov    0x58(%rsp),%r14
 10f291d:	4c 89 76 10          	mov    %r14,0x10(%rsi)
 10f2921:	48 8b 84 24 a0 00 00 	mov    0xa0(%rsp),%rax
 10f2928:	00 
 10f2929:	48 89 46 18          	mov    %rax,0x18(%rsi)
 10f292d:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 10f2932:	48 89 46 20          	mov    %rax,0x20(%rsi)
 10f2936:	48 8b 84 24 20 01 00 	mov    0x120(%rsp),%rax
 10f293d:	00 
 10f293e:	48 89 46 28          	mov    %rax,0x28(%rsi)
 10f2942:	48 c7 c0 f8 ff ff ff 	mov    $0xfffffffffffffff8,%rax
 10f2949:	45 31 ff             	xor    %r15d,%r15d
 10f294c:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 10f2950:	c5 fe 6f 8c 86 50 04 	vmovdqu 0x450(%rsi,%rax,4),%ymm1
 10f2957:	00 00 
 10f2959:	c5 f5 fe 4c 86 50    	vpaddd 0x50(%rsi,%rax,4),%ymm1,%ymm1
 10f295f:	c5 f5 fe 8c 86 50 08 	vpaddd 0x850(%rsi,%rax,4),%ymm1,%ymm1
 10f2966:	00 00 
 10f2968:	c5 f5 fe 8c 86 50 0c 	vpaddd 0xc50(%rsi,%rax,4),%ymm1,%ymm1
 10f296f:	00 00 
 10f2971:	c5 fe 7f 8c 84 b8 02 	vmovdqu %ymm1,0x2b8(%rsp,%rax,4)
 10f2978:	00 00 
 10f297a:	c5 f5 76 c8          	vpcmpeqd %ymm0,%ymm1,%ymm1
 10f297e:	c5 fc 50 c9          	vmovmskps %ymm1,%ecx
 10f2982:	81 f1 ff 00 00 00    	xor    $0xff,%ecx
 10f2988:	f3 0f b8 c9          	popcnt %ecx,%ecx
 10f298c:	c5 fe 6f 8c 86 70 04 	vmovdqu 0x470(%rsi,%rax,4),%ymm1
 10f2993:	00 00 
 10f2995:	c5 f5 fe 4c 86 70    	vpaddd 0x70(%rsi,%rax,4),%ymm1,%ymm1
 10f299b:	c5 f5 fe 8c 86 70 08 	vpaddd 0x870(%rsi,%rax,4),%ymm1,%ymm1
 10f29a2:	00 00 
 10f29a4:	4c 01 f9             	add    %r15,%rcx
 10f29a7:	c5 f5 fe 8c 86 70 0c 	vpaddd 0xc70(%rsi,%rax,4),%ymm1,%ymm1
 10f29ae:	00 00 
 10f29b0:	c5 fe 7f 8c 84 d8 02 	vmovdqu %ymm1,0x2d8(%rsp,%rax,4)
 10f29b7:	00 00 
 10f29b9:	c5 f5 76 c8          	vpcmpeqd %ymm0,%ymm1,%ymm1
 10f29bd:	c5 fc 50 d1          	vmovmskps %ymm1,%edx
 10f29c1:	81 f2 ff 00 00 00    	xor    $0xff,%edx
 10f29c7:	45 31 ff             	xor    %r15d,%r15d
 10f29ca:	f3 44 0f b8 fa       	popcnt %edx,%r15d
 10f29cf:	49 01 cf             	add    %rcx,%r15
 10f29d2:	48 83 c0 10          	add    $0x10,%rax
 10f29d6:	48 3d f8 00 00 00    	cmp    $0xf8,%rax
 10f29dc:	0f 82 6e ff ff ff    	jb     10f2950 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1110>
 10f29e2:	66 41 ba 3e 00       	mov    $0x3e,%r10w
 10f29e7:	49 81 fe ff ff 0f 00 	cmp    $0xfffff,%r14
 10f29ee:	77 0e                	ja     10f29fe <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11be>
 10f29f0:	c6 84 24 c0 0f 00 00 	movb   $0x0,0xfc0(%rsp)
 10f29f7:	00 
 10f29f8:	31 c0                	xor    %eax,%eax
 10f29fa:	84 c0                	test   %al,%al
 10f29fc:	74 38                	je     10f2a36 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11f6>
 10f29fe:	48 8b 86 80 10 00 00 	mov    0x1080(%rsi),%rax
 10f2a05:	48 ff c0             	inc    %rax
 10f2a08:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 10f2a0f:	48 0f 45 d0          	cmovne %rax,%rdx
 10f2a13:	48 89 96 80 10 00 00 	mov    %rdx,0x1080(%rsi)
 10f2a1a:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 10f2a1f:	66 44 89 50 10       	mov    %r10w,0x10(%rax)
 10f2a24:	48 8d 65 d8          	lea    -0x28(%rbp),%rsp
 10f2a28:	5b                   	pop    %rbx
 10f2a29:	41 5c                	pop    %r12
 10f2a2b:	41 5d                	pop    %r13
 10f2a2d:	41 5e                	pop    %r14
 10f2a2f:	41 5f                	pop    %r15
 10f2a31:	5d                   	pop    %rbp
 10f2a32:	c5 f8 77             	vzeroupper 
 10f2a35:	c3                   	ret    
 10f2a36:	49 81 fe 00 10 00 00 	cmp    $0x1000,%r14
 10f2a3d:	b8 03 00 00 00       	mov    $0x3,%eax
 10f2a42:	48 83 d8 00          	sbb    $0x0,%rax
 10f2a46:	49 83 fe 20          	cmp    $0x20,%r14
 10f2a4a:	b9 01 00 00 00       	mov    $0x1,%ecx
 10f2a4f:	48 0f 43 c8          	cmovae %rax,%rcx
 10f2a53:	49 83 ff 01          	cmp    $0x1,%r15
 10f2a57:	4d 0f 44 f7          	cmove  %r15,%r14
 10f2a5b:	49 01 ce             	add    %rcx,%r14
 10f2a5e:	4c 8d a4 24 e8 21 00 	lea    0x21e8(%rsp),%r12
 10f2a65:	00 
 10f2a66:	48 8d b4 24 98 02 00 	lea    0x298(%rsp),%rsi
 10f2a6d:	00 
 10f2a6e:	ba 00 04 00 00       	mov    $0x400,%edx
 10f2a73:	4c 89 e7             	mov    %r12,%rdi
 10f2a76:	c5 f8 77             	vzeroupper 
 10f2a79:	e8 42 aa 00 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10f2a7e:	4c 8d ac 24 c0 0b 00 	lea    0xbc0(%rsp),%r13
 10f2a85:	00 
 10f2a86:	ba 00 04 00 00       	mov    $0x400,%edx
 10f2a8b:	4c 89 ef             	mov    %r13,%rdi
 10f2a8e:	4c 89 e6             	mov    %r12,%rsi
 10f2a91:	4c 8b 64 24 58       	mov    0x58(%rsp),%r12
 10f2a96:	e8 25 aa 00 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10f2a9b:	4c 89 bc 24 a8 0b 00 	mov    %r15,0xba8(%rsp)
 10f2aa2:	00 
 10f2aa3:	4c 89 a4 24 b0 0b 00 	mov    %r12,0xbb0(%rsp)
 10f2aaa:	00 
 10f2aab:	4c 89 b4 24 b8 0b 00 	mov    %r14,0xbb8(%rsp)
 10f2ab2:	00 
 10f2ab3:	48 8b 45 10          	mov    0x10(%rbp),%rax
 10f2ab7:	80 78 10 00          	cmpb   $0x0,0x10(%rax)
 10f2abb:	4c 89 74 24 50       	mov    %r14,0x50(%rsp)
 10f2ac0:	74 3b                	je     10f2afd <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x12bd>
 10f2ac2:	49 83 ff 02          	cmp    $0x2,%r15
 10f2ac6:	0f 92 c0             	setb   %al
 10f2ac9:	49 83 fc 40          	cmp    $0x40,%r12
 10f2acd:	0f 92 c1             	setb   %cl
 10f2ad0:	08 c1                	or     %al,%cl
 10f2ad2:	80 f9 01             	cmp    $0x1,%cl
 10f2ad5:	48 8b 44 24 20       	mov    0x20(%rsp),%rax
 10f2ada:	75 49                	jne    10f2b25 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x12e5>
 10f2adc:	48 8b 88 10 16 00 00 	mov    0x1610(%rax),%rcx
 10f2ae3:	48 ff c1             	inc    %rcx
 10f2ae6:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 10f2aed:	48 0f 45 d1          	cmovne %rcx,%rdx
 10f2af1:	48 89 90 10 16 00 00 	mov    %rdx,0x1610(%rax)
 10f2af8:	e9 c4 01 00 00       	jmp    10f2cc1 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1481>
 10f2afd:	b8 78 05 00 01       	mov    $0x1000578,%eax
 10f2b02:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 10f2b07:	b8 70 05 00 01       	mov    $0x1000570,%eax
 10f2b0c:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 10f2b11:	48 8b 44 24 20       	mov    0x20(%rsp),%rax
 10f2b16:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f2b1b:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f2b20:	e9 cd 01 00 00       	jmp    10f2cf2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x14b2>
 10f2b25:	80 b8 f0 15 00 00 00 	cmpb   $0x0,0x15f0(%rax)
 10f2b2c:	0f 84 73 01 00 00    	je     10f2ca5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1465>
 10f2b32:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 10f2b36:	48 c7 c7 f8 ff ff ff 	mov    $0xfffffffffffffff8,%rdi
 10f2b3d:	31 f6                	xor    %esi,%esi
 10f2b3f:	c5 e1 ef db          	vpxor  %xmm3,%xmm3,%xmm3
 10f2b43:	c5 d9 ef e4          	vpxor  %xmm4,%xmm4,%xmm4
 10f2b47:	c5 f0 57 c9          	vxorps %xmm1,%xmm1,%xmm1
 10f2b4b:	c5 e9 ef d2          	vpxor  %xmm2,%xmm2,%xmm2
 10f2b4f:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f2b54:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f2b59:	c4 e2 7d 35 ac bc f0 	vpmovzxdq 0xbf0(%rsp,%rdi,4),%ymm5
 10f2b60:	0b 00 00 
 10f2b63:	c5 dd d4 e5          	vpaddq %ymm5,%ymm4,%ymm4
 10f2b67:	c4 e2 7d 35 ac bc e0 	vpmovzxdq 0xbe0(%rsp,%rdi,4),%ymm5
 10f2b6e:	0b 00 00 
 10f2b71:	c5 e5 d4 dd          	vpaddq %ymm5,%ymm3,%ymm3
 10f2b75:	c5 fe 6f ac bc e0 0b 	vmovdqu 0xbe0(%rsp,%rdi,4),%ymm5
 10f2b7c:	00 00 
 10f2b7e:	c5 fe 6f b4 bc 00 0c 	vmovdqu 0xc00(%rsp,%rdi,4),%ymm6
 10f2b85:	00 00 
 10f2b87:	c5 fe 6f bc b8 08 12 	vmovdqu 0x1208(%rax,%rdi,4),%ymm7
 10f2b8e:	00 00 
 10f2b90:	c5 7e 6f 84 b8 28 12 	vmovdqu 0x1228(%rax,%rdi,4),%ymm8
 10f2b97:	00 00 
 10f2b99:	c4 62 45 3f cd       	vpmaxud %ymm5,%ymm7,%ymm9
 10f2b9e:	c5 35 fa cd          	vpsubd %ymm5,%ymm9,%ymm9
 10f2ba2:	c4 43 7d 39 ca 01    	vextracti128 $0x1,%ymm9,%xmm10
 10f2ba8:	c4 42 7d 35 d2       	vpmovzxdq %xmm10,%ymm10
 10f2bad:	c5 ad d4 d2          	vpaddq %ymm2,%ymm10,%ymm2
 10f2bb1:	c4 42 7d 35 c9       	vpmovzxdq %xmm9,%ymm9
 10f2bb6:	c5 b5 d4 c9          	vpaddq %ymm1,%ymm9,%ymm1
 10f2bba:	c5 d5 76 e8          	vpcmpeqd %ymm0,%ymm5,%ymm5
 10f2bbe:	c5 c5 76 f8          	vpcmpeqd %ymm0,%ymm7,%ymm7
 10f2bc2:	c5 c5 ef ed          	vpxor  %ymm5,%ymm7,%ymm5
 10f2bc6:	c5 7c 50 c5          	vmovmskps %ymm5,%r8d
 10f2bca:	41 08 f0             	or     %sil,%r8b
 10f2bcd:	c4 e2 7d 35 ac bc 00 	vpmovzxdq 0xc00(%rsp,%rdi,4),%ymm5
 10f2bd4:	0c 00 00 
 10f2bd7:	c5 e5 d4 dd          	vpaddq %ymm5,%ymm3,%ymm3
 10f2bdb:	c4 e2 7d 35 ac bc 10 	vpmovzxdq 0xc10(%rsp,%rdi,4),%ymm5
 10f2be2:	0c 00 00 
 10f2be5:	c5 dd d4 e5          	vpaddq %ymm5,%ymm4,%ymm4
 10f2be9:	c4 e2 3d 3f ee       	vpmaxud %ymm6,%ymm8,%ymm5
 10f2bee:	c5 d5 fa ee          	vpsubd %ymm6,%ymm5,%ymm5
 10f2bf2:	c4 e2 7d 35 fd       	vpmovzxdq %xmm5,%ymm7
 10f2bf7:	c5 f5 d4 cf          	vpaddq %ymm7,%ymm1,%ymm1
 10f2bfb:	c4 e3 7d 39 ed 01    	vextracti128 $0x1,%ymm5,%xmm5
 10f2c01:	c4 e2 7d 35 ed       	vpmovzxdq %xmm5,%ymm5
 10f2c06:	c5 ed d4 d5          	vpaddq %ymm5,%ymm2,%ymm2
 10f2c0a:	c5 cd 76 e8          	vpcmpeqd %ymm0,%ymm6,%ymm5
 10f2c0e:	c5 bd 76 f0          	vpcmpeqd %ymm0,%ymm8,%ymm6
 10f2c12:	c5 cd ef ed          	vpxor  %ymm5,%ymm6,%ymm5
 10f2c16:	c5 fc 50 f5          	vmovmskps %ymm5,%esi
 10f2c1a:	44 08 c6             	or     %r8b,%sil
 10f2c1d:	48 83 c7 10          	add    $0x10,%rdi
 10f2c21:	48 81 ff f8 00 00 00 	cmp    $0xf8,%rdi
 10f2c28:	0f 82 2b ff ff ff    	jb     10f2b59 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1319>
 10f2c2e:	c5 e5 d4 c4          	vpaddq %ymm4,%ymm3,%ymm0
 10f2c32:	c4 e3 7d 39 c3 01    	vextracti128 $0x1,%ymm0,%xmm3
 10f2c38:	c5 f9 d4 c3          	vpaddq %xmm3,%xmm0,%xmm0
 10f2c3c:	c5 f9 70 d8 ee       	vpshufd $0xee,%xmm0,%xmm3
 10f2c41:	c5 f9 d4 c3          	vpaddq %xmm3,%xmm0,%xmm0
 10f2c45:	c4 c1 f9 7e c0       	vmovq  %xmm0,%r8
 10f2c4a:	49 81 f8 00 00 02 00 	cmp    $0x20000,%r8
 10f2c51:	77 34                	ja     10f2c87 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1447>
 10f2c53:	c5 f5 d4 c2          	vpaddq %ymm2,%ymm1,%ymm0
 10f2c57:	c4 e3 7d 39 c1 01    	vextracti128 $0x1,%ymm0,%xmm1
 10f2c5d:	c5 f9 d4 c1          	vpaddq %xmm1,%xmm0,%xmm0
 10f2c61:	c5 f9 70 c8 ee       	vpshufd $0xee,%xmm0,%xmm1
 10f2c66:	c5 f9 d4 c1          	vpaddq %xmm1,%xmm0,%xmm0
 10f2c6a:	c4 e1 f9 7e c7       	vmovq  %xmm0,%rdi
 10f2c6f:	40 84 f6             	test   %sil,%sil
 10f2c72:	0f 94 84 24 c0 0f 00 	sete   0xfc0(%rsp)
 10f2c79:	00 
 10f2c7a:	48 89 fe             	mov    %rdi,%rsi
 10f2c7d:	48 c1 ee 20          	shr    $0x20,%rsi
 10f2c81:	0f 84 b7 09 00 00    	je     10f363e <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dfe>
 10f2c87:	48 8b b0 28 16 00 00 	mov    0x1628(%rax),%rsi
 10f2c8e:	48 ff c6             	inc    %rsi
 10f2c91:	48 c7 c7 ff ff ff ff 	mov    $0xffffffffffffffff,%rdi
 10f2c98:	48 0f 45 fe          	cmovne %rsi,%rdi
 10f2c9c:	48 89 b8 28 16 00 00 	mov    %rdi,0x1628(%rax)
 10f2ca3:	eb 26                	jmp    10f2ccb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x148b>
 10f2ca5:	48 8b 88 08 16 00 00 	mov    0x1608(%rax),%rcx
 10f2cac:	48 ff c1             	inc    %rcx
 10f2caf:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 10f2cb6:	48 0f 45 d1          	cmovne %rcx,%rdx
 10f2cba:	48 89 90 08 16 00 00 	mov    %rdx,0x1608(%rax)
 10f2cc1:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f2cc6:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f2ccb:	48 c7 44 24 70 00 00 	movq   $0x0,0x70(%rsp)
 10f2cd2:	00 00 
 10f2cd4:	c6 44 24 18 00       	movb   $0x0,0x18(%rsp)
 10f2cd9:	48 8d 74 24 18       	lea    0x18(%rsp),%rsi
 10f2cde:	48 89 74 24 48       	mov    %rsi,0x48(%rsp)
 10f2ce3:	48 8d 74 24 70       	lea    0x70(%rsp),%rsi
 10f2ce8:	48 89 74 24 38       	mov    %rsi,0x38(%rsp)
 10f2ced:	4c 8b 74 24 50       	mov    0x50(%rsp),%r14
 10f2cf2:	48 8b b8 80 10 00 00 	mov    0x1080(%rax),%rdi
 10f2cf9:	48 ff c7             	inc    %rdi
 10f2cfc:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 10f2d03:	48 0f 44 fe          	cmove  %rsi,%rdi
 10f2d07:	48 89 b8 80 10 00 00 	mov    %rdi,0x1080(%rax)
 10f2d0e:	49 83 ff 02          	cmp    $0x2,%r15
 10f2d12:	40 0f 92 c7          	setb   %dil
 10f2d16:	49 83 fc 40          	cmp    $0x40,%r12
 10f2d1a:	41 0f 92 c0          	setb   %r8b
 10f2d1e:	41 08 f8             	or     %dil,%r8b
 10f2d21:	74 13                	je     10f2d36 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x14f6>
 10f2d23:	b0 01                	mov    $0x1,%al
 10f2d25:	89 44 24 28          	mov    %eax,0x28(%rsp)
 10f2d29:	45 31 e4             	xor    %r12d,%r12d
 10f2d2c:	48 8b 7c 24 68       	mov    0x68(%rsp),%rdi
 10f2d31:	e9 b4 06 00 00       	jmp    10f33ea <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1baa>
 10f2d36:	48 8b 88 88 10 00 00 	mov    0x1088(%rax),%rcx
 10f2d3d:	48 ff c1             	inc    %rcx
 10f2d40:	48 0f 44 ce          	cmove  %rsi,%rcx
 10f2d44:	48 89 88 88 10 00 00 	mov    %rcx,0x1088(%rax)
 10f2d4b:	48 8d bc 24 a0 02 00 	lea    0x2a0(%rsp),%rdi
 10f2d52:	00 
 10f2d53:	ba 00 04 00 00       	mov    $0x400,%edx
 10f2d58:	4c 89 ee             	mov    %r13,%rsi
 10f2d5b:	c5 f8 77             	vzeroupper 
 10f2d5e:	e8 5d a7 00 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10f2d63:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 10f2d67:	c5 fe 7f 84 24 a0 06 	vmovdqu %ymm0,0x6a0(%rsp)
 10f2d6e:	00 00 
 10f2d70:	c5 fe 7f 84 24 c0 06 	vmovdqu %ymm0,0x6c0(%rsp)
 10f2d77:	00 00 
 10f2d79:	c5 fe 7f 84 24 e0 06 	vmovdqu %ymm0,0x6e0(%rsp)
 10f2d80:	00 00 
 10f2d82:	c5 fe 7f 84 24 00 07 	vmovdqu %ymm0,0x700(%rsp)
 10f2d89:	00 00 
 10f2d8b:	c5 fe 7f 84 24 20 07 	vmovdqu %ymm0,0x720(%rsp)
 10f2d92:	00 00 
 10f2d94:	c5 fe 7f 84 24 40 07 	vmovdqu %ymm0,0x740(%rsp)
 10f2d9b:	00 00 
 10f2d9d:	c5 fe 7f 84 24 60 07 	vmovdqu %ymm0,0x760(%rsp)
 10f2da4:	00 00 
 10f2da6:	c5 fe 7f 84 24 80 07 	vmovdqu %ymm0,0x780(%rsp)
 10f2dad:	00 00 
 10f2daf:	c5 fe 7f 84 24 a0 07 	vmovdqu %ymm0,0x7a0(%rsp)
 10f2db6:	00 00 
 10f2db8:	c5 fe 7f 84 24 c0 07 	vmovdqu %ymm0,0x7c0(%rsp)
 10f2dbf:	00 00 
 10f2dc1:	c5 fe 7f 84 24 e0 07 	vmovdqu %ymm0,0x7e0(%rsp)
 10f2dc8:	00 00 
 10f2dca:	c5 fe 7f 84 24 00 08 	vmovdqu %ymm0,0x800(%rsp)
 10f2dd1:	00 00 
 10f2dd3:	c5 fe 7f 84 24 20 08 	vmovdqu %ymm0,0x820(%rsp)
 10f2dda:	00 00 
 10f2ddc:	c5 fe 7f 84 24 40 08 	vmovdqu %ymm0,0x840(%rsp)
 10f2de3:	00 00 
 10f2de5:	c5 fe 7f 84 24 60 08 	vmovdqu %ymm0,0x860(%rsp)
 10f2dec:	00 00 
 10f2dee:	c5 fe 7f 84 24 80 08 	vmovdqu %ymm0,0x880(%rsp)
 10f2df5:	00 00 
 10f2df7:	48 c7 84 24 98 02 00 	movq   $0x0,0x298(%rsp)
 10f2dfe:	00 00 00 00 00 
 10f2e03:	c5 fe 7f 84 24 a0 0a 	vmovdqu %ymm0,0xaa0(%rsp)
 10f2e0a:	00 00 
 10f2e0c:	c5 fe 7f 84 24 c0 0a 	vmovdqu %ymm0,0xac0(%rsp)
 10f2e13:	00 00 
 10f2e15:	c5 fe 7f 84 24 e0 0a 	vmovdqu %ymm0,0xae0(%rsp)
 10f2e1c:	00 00 
 10f2e1e:	c5 fe 7f 84 24 00 0b 	vmovdqu %ymm0,0xb00(%rsp)
 10f2e25:	00 00 
 10f2e27:	c5 fe 7f 84 24 20 0b 	vmovdqu %ymm0,0xb20(%rsp)
 10f2e2e:	00 00 
 10f2e30:	c5 fe 7f 84 24 40 0b 	vmovdqu %ymm0,0xb40(%rsp)
 10f2e37:	00 00 
 10f2e39:	c5 fe 7f 84 24 60 0b 	vmovdqu %ymm0,0xb60(%rsp)
 10f2e40:	00 00 
 10f2e42:	c5 fe 7f 84 24 80 0b 	vmovdqu %ymm0,0xb80(%rsp)
 10f2e49:	00 00 
 10f2e4b:	66 c7 84 24 a0 0b 00 	movw   $0x0,0xba0(%rsp)
 10f2e52:	00 00 00 
 10f2e55:	31 c9                	xor    %ecx,%ecx
 10f2e57:	31 c0                	xor    %eax,%eax
 10f2e59:	eb 15                	jmp    10f2e70 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1630>
 10f2e5b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 10f2e60:	48 83 c0 04          	add    $0x4,%rax
 10f2e64:	48 3d 00 01 00 00    	cmp    $0x100,%rax
 10f2e6a:	0f 84 a2 00 00 00    	je     10f2f12 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x16d2>
 10f2e70:	83 bc 84 c0 0b 00 00 	cmpl   $0x0,0xbc0(%rsp,%rax,4)
 10f2e77:	00 
 10f2e78:	74 1a                	je     10f2e94 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1654>
 10f2e7a:	88 84 0c a0 08 00 00 	mov    %al,0x8a0(%rsp,%rcx,1)
 10f2e81:	48 8b 8c 24 98 02 00 	mov    0x298(%rsp),%rcx
 10f2e88:	00 
 10f2e89:	48 ff c1             	inc    %rcx
 10f2e8c:	48 89 8c 24 98 02 00 	mov    %rcx,0x298(%rsp)
 10f2e93:	00 
 10f2e94:	83 bc 84 c4 0b 00 00 	cmpl   $0x0,0xbc4(%rsp,%rax,4)
 10f2e9b:	00 
 10f2e9c:	74 1d                	je     10f2ebb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x167b>
 10f2e9e:	8d 50 01             	lea    0x1(%rax),%edx
 10f2ea1:	88 94 0c a0 08 00 00 	mov    %dl,0x8a0(%rsp,%rcx,1)
 10f2ea8:	48 8b 8c 24 98 02 00 	mov    0x298(%rsp),%rcx
 10f2eaf:	00 
 10f2eb0:	48 ff c1             	inc    %rcx
 10f2eb3:	48 89 8c 24 98 02 00 	mov    %rcx,0x298(%rsp)
 10f2eba:	00 
 10f2ebb:	83 bc 84 c8 0b 00 00 	cmpl   $0x0,0xbc8(%rsp,%rax,4)
 10f2ec2:	00 
 10f2ec3:	74 1d                	je     10f2ee2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x16a2>
 10f2ec5:	8d 50 02             	lea    0x2(%rax),%edx
 10f2ec8:	88 94 0c a0 08 00 00 	mov    %dl,0x8a0(%rsp,%rcx,1)
 10f2ecf:	48 8b 8c 24 98 02 00 	mov    0x298(%rsp),%rcx
 10f2ed6:	00 
 10f2ed7:	48 ff c1             	inc    %rcx
 10f2eda:	48 89 8c 24 98 02 00 	mov    %rcx,0x298(%rsp)
 10f2ee1:	00 
 10f2ee2:	83 bc 84 cc 0b 00 00 	cmpl   $0x0,0xbcc(%rsp,%rax,4)
 10f2ee9:	00 
 10f2eea:	0f 84 70 ff ff ff    	je     10f2e60 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1620>
 10f2ef0:	8d 50 03             	lea    0x3(%rax),%edx
 10f2ef3:	88 94 0c a0 08 00 00 	mov    %dl,0x8a0(%rsp,%rcx,1)
 10f2efa:	48 8b 8c 24 98 02 00 	mov    0x298(%rsp),%rcx
 10f2f01:	00 
 10f2f02:	48 ff c1             	inc    %rcx
 10f2f05:	48 89 8c 24 98 02 00 	mov    %rcx,0x298(%rsp)
 10f2f0c:	00 
 10f2f0d:	e9 4e ff ff ff       	jmp    10f2e60 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1620>
 10f2f12:	48 8d bc 24 98 02 00 	lea    0x298(%rsp),%rdi
 10f2f19:	00 
 10f2f1a:	c5 f8 77             	vzeroupper 
 10f2f1d:	e8 7e 61 fd ff       	call   10c90a0 <zstd.finalizeSmallHuffmanLiteralPlan>
 10f2f22:	84 c0                	test   %al,%al
 10f2f24:	0f 84 28 04 00 00    	je     10f3352 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b12>
 10f2f2a:	4c 8d a4 24 d0 18 00 	lea    0x18d0(%rsp),%r12
 10f2f31:	00 
 10f2f32:	48 8d b4 24 98 02 00 	lea    0x298(%rsp),%rsi
 10f2f39:	00 
 10f2f3a:	ba 10 09 00 00       	mov    $0x910,%edx
 10f2f3f:	4c 89 e7             	mov    %r12,%rdi
 10f2f42:	e8 79 a5 00 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10f2f47:	48 8d bc 24 c0 0f 00 	lea    0xfc0(%rsp),%rdi
 10f2f4e:	00 
 10f2f4f:	ba 10 09 00 00       	mov    $0x910,%edx
 10f2f54:	4c 89 e6             	mov    %r12,%rsi
 10f2f57:	e8 64 a5 00 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10f2f5c:	44 0f b6 b4 24 c8 18 	movzbl 0x18c8(%rsp),%r14d
 10f2f63:	00 00 
 10f2f65:	0f b6 9c 24 c9 18 00 	movzbl 0x18c9(%rsp),%ebx
 10f2f6c:	00 
 10f2f6d:	80 e3 0f             	and    $0xf,%bl
 10f2f70:	c5 fe 6f 8c 24 c8 17 	vmovdqu 0x17c8(%rsp),%ymm1
 10f2f77:	00 00 
 10f2f79:	c5 fe 6f 94 24 e8 17 	vmovdqu 0x17e8(%rsp),%ymm2
 10f2f80:	00 00 
 10f2f82:	c5 fe 6f 9c 24 08 18 	vmovdqu 0x1808(%rsp),%ymm3
 10f2f89:	00 00 
 10f2f8b:	c5 fc 10 84 24 28 18 	vmovups 0x1828(%rsp),%ymm0
 10f2f92:	00 00 
 10f2f94:	c5 fc 29 84 24 c0 00 	vmovaps %ymm0,0xc0(%rsp)
 10f2f9b:	00 00 
 10f2f9d:	c5 fc 10 84 24 48 18 	vmovups 0x1848(%rsp),%ymm0
 10f2fa4:	00 00 
 10f2fa6:	c5 fc 29 84 24 a0 00 	vmovaps %ymm0,0xa0(%rsp)
 10f2fad:	00 00 
 10f2faf:	c5 fc 10 84 24 68 18 	vmovups 0x1868(%rsp),%ymm0
 10f2fb6:	00 00 
 10f2fb8:	c5 fc 29 84 24 80 00 	vmovaps %ymm0,0x80(%rsp)
 10f2fbf:	00 00 
 10f2fc1:	c5 fc 10 84 24 88 18 	vmovups 0x1888(%rsp),%ymm0
 10f2fc8:	00 00 
 10f2fca:	c5 fc 29 84 24 00 01 	vmovaps %ymm0,0x100(%rsp)
 10f2fd1:	00 00 
 10f2fd3:	c5 fe 6f 84 24 a8 18 	vmovdqu 0x18a8(%rsp),%ymm0
 10f2fda:	00 00 
 10f2fdc:	c5 fd 7f 84 24 e0 00 	vmovdqa %ymm0,0xe0(%rsp)
 10f2fe3:	00 00 
 10f2fe5:	48 8b 74 24 20       	mov    0x20(%rsp),%rsi
 10f2fea:	4c 8d ae b8 10 00 00 	lea    0x10b8(%rsi),%r13
 10f2ff1:	80 be d0 11 00 00 00 	cmpb   $0x0,0x11d0(%rsi)
 10f2ff8:	0f 84 ca 00 00 00    	je     10f30c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1888>
 10f2ffe:	44 38 b6 c8 10 00 00 	cmp    %r14b,0x10c8(%rsi)
 10f3005:	0f 85 bd 00 00 00    	jne    10f30c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1888>
 10f300b:	38 9e c9 10 00 00    	cmp    %bl,0x10c9(%rsi)
 10f3011:	0f 85 b1 00 00 00    	jne    10f30c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1888>
 10f3017:	c5 f5 ef 86 ca 10 00 	vpxor  0x10ca(%rsi),%ymm1,%ymm0
 10f301e:	00 
 10f301f:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 10f3024:	0f 85 9e 00 00 00    	jne    10f30c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1888>
 10f302a:	c5 ed ef 86 ea 10 00 	vpxor  0x10ea(%rsi),%ymm2,%ymm0
 10f3031:	00 
 10f3032:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 10f3037:	0f 85 8b 00 00 00    	jne    10f30c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1888>
 10f303d:	c5 e5 ef 86 0a 11 00 	vpxor  0x110a(%rsi),%ymm3,%ymm0
 10f3044:	00 
 10f3045:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 10f304a:	75 7c                	jne    10f30c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1888>
 10f304c:	c5 fd 6f 84 24 c0 00 	vmovdqa 0xc0(%rsp),%ymm0
 10f3053:	00 00 
 10f3055:	c5 fd ef 86 2a 11 00 	vpxor  0x112a(%rsi),%ymm0,%ymm0
 10f305c:	00 
 10f305d:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 10f3062:	75 64                	jne    10f30c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1888>
 10f3064:	c5 fd 6f 84 24 a0 00 	vmovdqa 0xa0(%rsp),%ymm0
 10f306b:	00 00 
 10f306d:	c5 fd ef 86 4a 11 00 	vpxor  0x114a(%rsi),%ymm0,%ymm0
 10f3074:	00 
 10f3075:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 10f307a:	75 4c                	jne    10f30c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1888>
 10f307c:	c5 fd 6f 84 24 80 00 	vmovdqa 0x80(%rsp),%ymm0
 10f3083:	00 00 
 10f3085:	c5 fd ef 86 6a 11 00 	vpxor  0x116a(%rsi),%ymm0,%ymm0
 10f308c:	00 
 10f308d:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 10f3092:	75 34                	jne    10f30c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1888>
 10f3094:	c5 fd 6f 84 24 00 01 	vmovdqa 0x100(%rsp),%ymm0
 10f309b:	00 00 
 10f309d:	c5 fd ef 86 8a 11 00 	vpxor  0x118a(%rsi),%ymm0,%ymm0
 10f30a4:	00 
 10f30a5:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 10f30aa:	75 1c                	jne    10f30c8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1888>
 10f30ac:	c5 fd 6f 84 24 e0 00 	vmovdqa 0xe0(%rsp),%ymm0
 10f30b3:	00 00 
 10f30b5:	c5 fd ef 86 aa 11 00 	vpxor  0x11aa(%rsi),%ymm0,%ymm0
 10f30bc:	00 
 10f30bd:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 10f30c2:	0f 84 f0 09 00 00    	je     10f3ab8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x2278>
 10f30c8:	c5 fd 7f 9c 24 c0 01 	vmovdqa %ymm3,0x1c0(%rsp)
 10f30cf:	00 00 
 10f30d1:	c5 fd 7f 94 24 e0 01 	vmovdqa %ymm2,0x1e0(%rsp)
 10f30d8:	00 00 
 10f30da:	c5 fd 7f 8c 24 20 01 	vmovdqa %ymm1,0x120(%rsp)
 10f30e1:	00 00 
 10f30e3:	48 8b 86 90 10 00 00 	mov    0x1090(%rsi),%rax
 10f30ea:	48 ff c0             	inc    %rax
 10f30ed:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 10f30f4:	48 0f 45 c8          	cmovne %rax,%rcx
 10f30f8:	48 89 8e 90 10 00 00 	mov    %rcx,0x1090(%rsi)
 10f30ff:	4c 8d a4 24 98 02 00 	lea    0x298(%rsp),%r12
 10f3106:	00 
 10f3107:	48 8d b4 24 d0 18 00 	lea    0x18d0(%rsp),%rsi
 10f310e:	00 
 10f310f:	4c 89 e7             	mov    %r12,%rdi
 10f3112:	c5 f8 77             	vzeroupper 
 10f3115:	e8 66 0b 00 00       	call   10f3c80 <zstd.smallHuffmanTreeSerializedLen>
 10f311a:	0f b7 94 24 a8 02 00 	movzwl 0x2a8(%rsp),%edx
 10f3121:	00 
 10f3122:	66 85 d2             	test   %dx,%dx
 10f3125:	0f 85 0c 09 00 00    	jne    10f3a37 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x21f7>
 10f312b:	b0 01                	mov    $0x1,%al
 10f312d:	89 44 24 28          	mov    %eax,0x28(%rsp)
 10f3131:	48 8b 74 24 20       	mov    0x20(%rsp),%rsi
 10f3136:	c6 86 d0 11 00 00 01 	movb   $0x1,0x11d0(%rsi)
 10f313d:	44 88 b6 c8 10 00 00 	mov    %r14b,0x10c8(%rsi)
 10f3144:	88 9e c9 10 00 00    	mov    %bl,0x10c9(%rsi)
 10f314a:	c5 fc 28 84 24 20 01 	vmovaps 0x120(%rsp),%ymm0
 10f3151:	00 00 
 10f3153:	c5 fc 11 86 ca 10 00 	vmovups %ymm0,0x10ca(%rsi)
 10f315a:	00 
 10f315b:	c5 fc 28 84 24 e0 01 	vmovaps 0x1e0(%rsp),%ymm0
 10f3162:	00 00 
 10f3164:	c5 fc 11 86 ea 10 00 	vmovups %ymm0,0x10ea(%rsi)
 10f316b:	00 
 10f316c:	c5 fc 28 84 24 c0 01 	vmovaps 0x1c0(%rsp),%ymm0
 10f3173:	00 00 
 10f3175:	c5 fc 11 86 0a 11 00 	vmovups %ymm0,0x110a(%rsi)
 10f317c:	00 
 10f317d:	c5 fc 28 84 24 c0 00 	vmovaps 0xc0(%rsp),%ymm0
 10f3184:	00 00 
 10f3186:	c5 fc 11 86 2a 11 00 	vmovups %ymm0,0x112a(%rsi)
 10f318d:	00 
 10f318e:	c5 fc 28 84 24 a0 00 	vmovaps 0xa0(%rsp),%ymm0
 10f3195:	00 00 
 10f3197:	c5 fc 11 86 4a 11 00 	vmovups %ymm0,0x114a(%rsi)
 10f319e:	00 
 10f319f:	c5 fc 28 84 24 80 00 	vmovaps 0x80(%rsp),%ymm0
 10f31a6:	00 00 
 10f31a8:	c5 fc 11 86 6a 11 00 	vmovups %ymm0,0x116a(%rsi)
 10f31af:	00 
 10f31b0:	c5 fc 28 84 24 00 01 	vmovaps 0x100(%rsp),%ymm0
 10f31b7:	00 00 
 10f31b9:	c5 fc 11 86 8a 11 00 	vmovups %ymm0,0x118a(%rsi)
 10f31c0:	00 
 10f31c1:	c5 fc 28 84 24 e0 00 	vmovaps 0xe0(%rsp),%ymm0
 10f31c8:	00 00 
 10f31ca:	c5 fc 11 86 aa 11 00 	vmovups %ymm0,0x11aa(%rsi)
 10f31d1:	00 
 10f31d2:	c5 fa 6f 84 24 98 02 	vmovdqu 0x298(%rsp),%xmm0
 10f31d9:	00 00 
 10f31db:	c4 c1 7a 7f 45 00    	vmovdqu %xmm0,0x0(%r13)
 10f31e1:	0f b6 84 24 a0 02 00 	movzbl 0x2a0(%rsp),%eax
 10f31e8:	00 
 10f31e9:	4d 89 e5             	mov    %r12,%r13
 10f31ec:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f31f1:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f31f6:	48 8b 7c 24 68       	mov    0x68(%rsp),%rdi
 10f31fb:	84 c0                	test   %al,%al
 10f31fd:	4c 8b 44 24 58       	mov    0x58(%rsp),%r8
 10f3202:	4c 8b 74 24 50       	mov    0x50(%rsp),%r14
 10f3207:	0f 84 d2 01 00 00    	je     10f33df <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b9f>
 10f320d:	49 8b 5d 00          	mov    0x0(%r13),%rbx
 10f3211:	4c 8b 56 18          	mov    0x18(%rsi),%r10
 10f3215:	45 31 e4             	xor    %r12d,%r12d
 10f3218:	49 83 fa 01          	cmp    $0x1,%r10
 10f321c:	41 b9 06 00 00 00    	mov    $0x6,%r9d
 10f3222:	4d 0f 44 cc          	cmove  %r12,%r9
 10f3226:	4d 85 d2             	test   %r10,%r10
 10f3229:	0f 84 42 01 00 00    	je     10f3371 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b31>
 10f322f:	45 31 db             	xor    %r11d,%r11d
 10f3232:	49 c7 c5 ff ff ff ff 	mov    $0xffffffffffffffff,%r13
 10f3239:	45 31 e4             	xor    %r12d,%r12d
 10f323c:	45 31 ff             	xor    %r15d,%r15d
 10f323f:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 10f3244:	48 89 9c 24 80 00 00 	mov    %rbx,0x80(%rsp)
 10f324b:	00 
 10f324c:	4c 89 bc 24 a0 00 00 	mov    %r15,0xa0(%rsp)
 10f3253:	00 
 10f3254:	4c 89 a4 24 c0 00 00 	mov    %r12,0xc0(%rsp)
 10f325b:	00 
 10f325c:	45 31 f6             	xor    %r14d,%r14d
 10f325f:	31 db                	xor    %ebx,%ebx
 10f3261:	eb 0c                	jmp    10f326f <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1a2f>
 10f3263:	49 ff c6             	inc    %r14
 10f3266:	49 81 fe 00 01 00 00 	cmp    $0x100,%r14
 10f326d:	74 61                	je     10f32d0 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1a90>
 10f326f:	4c 8b 7c 24 78       	mov    0x78(%rsp),%r15
 10f3274:	47 8b 3c b7          	mov    (%r15,%r14,4),%r15d
 10f3278:	4d 85 ff             	test   %r15,%r15
 10f327b:	74 e6                	je     10f3263 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1a23>
 10f327d:	46 0f b6 84 34 c8 17 	movzbl 0x17c8(%rsp,%r14,1),%r8d
 10f3284:	00 00 
 10f3286:	4d 85 c0             	test   %r8,%r8
 10f3289:	0f 84 a2 03 00 00    	je     10f3631 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1df1>
 10f328f:	4c 8b a6 a0 10 00 00 	mov    0x10a0(%rsi),%r12
 10f3296:	49 ff c4             	inc    %r12
 10f3299:	4d 0f 44 e5          	cmove  %r13,%r12
 10f329d:	4c 89 a6 a0 10 00 00 	mov    %r12,0x10a0(%rsi)
 10f32a4:	c6 84 24 98 02 00 00 	movb   $0x0,0x298(%rsp)
 10f32ab:	00 
 10f32ac:	45 84 db             	test   %r11b,%r11b
 10f32af:	0f 85 1d 01 00 00    	jne    10f33d2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b92>
 10f32b5:	4d 0f af c7          	imul   %r15,%r8
 10f32b9:	4c 01 c3             	add    %r8,%rbx
 10f32bc:	0f 92 84 24 98 02 00 	setb   0x298(%rsp)
 10f32c3:	00 
 10f32c4:	4c 8b 44 24 58       	mov    0x58(%rsp),%r8
 10f32c9:	73 98                	jae    10f3263 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1a23>
 10f32cb:	e9 02 01 00 00       	jmp    10f33d2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b92>
 10f32d0:	49 89 de             	mov    %rbx,%r14
 10f32d3:	49 83 c6 08          	add    $0x8,%r14
 10f32d7:	0f 92 84 24 98 02 00 	setb   0x298(%rsp)
 10f32de:	00 
 10f32df:	0f 82 ed 00 00 00    	jb     10f33d2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b92>
 10f32e5:	4c 8b a4 24 c0 00 00 	mov    0xc0(%rsp),%r12
 10f32ec:	00 
 10f32ed:	49 01 dc             	add    %rbx,%r12
 10f32f0:	0f 92 84 24 98 02 00 	setb   0x298(%rsp)
 10f32f7:	00 
 10f32f8:	4c 8b bc 24 a0 00 00 	mov    0xa0(%rsp),%r15
 10f32ff:	00 
 10f3300:	0f 82 cc 00 00 00    	jb     10f33d2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b92>
 10f3306:	49 83 fa 01          	cmp    $0x1,%r10
 10f330a:	48 8b 9c 24 80 00 00 	mov    0x80(%rsp),%rbx
 10f3311:	00 
 10f3312:	74 0d                	je     10f3321 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1ae1>
 10f3314:	49 81 fe ff ff 07 00 	cmp    $0x7ffff,%r14
 10f331b:	0f 87 1c 05 00 00    	ja     10f383d <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1ffd>
 10f3321:	49 c1 ee 03          	shr    $0x3,%r14
 10f3325:	4d 01 f1             	add    %r14,%r9
 10f3328:	0f 92 84 24 98 02 00 	setb   0x298(%rsp)
 10f332f:	00 
 10f3330:	0f 82 9c 00 00 00    	jb     10f33d2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b92>
 10f3336:	49 ff c7             	inc    %r15
 10f3339:	48 81 44 24 78 00 04 	addq   $0x400,0x78(%rsp)
 10f3340:	00 00 
 10f3342:	4d 39 d7             	cmp    %r10,%r15
 10f3345:	4c 8b 74 24 50       	mov    0x50(%rsp),%r14
 10f334a:	0f 85 fc fe ff ff    	jne    10f324c <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1a0c>
 10f3350:	eb 24                	jmp    10f3376 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b36>
 10f3352:	b0 01                	mov    $0x1,%al
 10f3354:	89 44 24 28          	mov    %eax,0x28(%rsp)
 10f3358:	45 31 e4             	xor    %r12d,%r12d
 10f335b:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f3360:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f3365:	48 8b 7c 24 68       	mov    0x68(%rsp),%rdi
 10f336a:	4c 8b 74 24 50       	mov    0x50(%rsp),%r14
 10f336f:	eb 79                	jmp    10f33ea <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1baa>
 10f3371:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 10f3376:	4c 01 cb             	add    %r9,%rbx
 10f3379:	0f 92 84 24 98 02 00 	setb   0x298(%rsp)
 10f3380:	00 
 10f3381:	72 4f                	jb     10f33d2 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b92>
 10f3383:	0f 84 a8 02 00 00    	je     10f3631 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1df1>
 10f3389:	49 09 d8             	or     %rbx,%r8
 10f338c:	be 03 00 00 00       	mov    $0x3,%esi
 10f3391:	49 81 f8 00 04 00 00 	cmp    $0x400,%r8
 10f3398:	72 1c                	jb     10f33b6 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b76>
 10f339a:	be 04 00 00 00       	mov    $0x4,%esi
 10f339f:	49 81 f8 00 40 00 00 	cmp    $0x4000,%r8
 10f33a6:	72 0e                	jb     10f33b6 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b76>
 10f33a8:	be 05 00 00 00       	mov    $0x5,%esi
 10f33ad:	49 81 f8 00 00 04 00 	cmp    $0x40000,%r8
 10f33b4:	73 29                	jae    10f33df <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b9f>
 10f33b6:	c6 84 24 98 02 00 00 	movb   $0x0,0x298(%rsp)
 10f33bd:	00 
 10f33be:	45 31 c0             	xor    %r8d,%r8d
 10f33c1:	45 84 c0             	test   %r8b,%r8b
 10f33c4:	4c 8d ac 24 c0 0b 00 	lea    0xbc0(%rsp),%r13
 10f33cb:	00 
 10f33cc:	0f 84 23 03 00 00    	je     10f36f5 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1eb5>
 10f33d2:	66 ba 3e 00          	mov    $0x3e,%dx
 10f33d6:	66 89 50 10          	mov    %dx,0x10(%rax)
 10f33da:	e9 45 f6 ff ff       	jmp    10f2a24 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11e4>
 10f33df:	45 31 e4             	xor    %r12d,%r12d
 10f33e2:	4c 8d ac 24 c0 0b 00 	lea    0xbc0(%rsp),%r13
 10f33e9:	00 
 10f33ea:	4d 89 ef             	mov    %r13,%r15
 10f33ed:	48 89 bc 24 40 01 00 	mov    %rdi,0x140(%rsp)
 10f33f4:	00 
 10f33f5:	48 89 94 24 d0 18 00 	mov    %rdx,0x18d0(%rsp)
 10f33fc:	00 
 10f33fd:	48 89 8c 24 c0 0f 00 	mov    %rcx,0xfc0(%rsp)
 10f3404:	00 
 10f3405:	48 8d bc 24 98 02 00 	lea    0x298(%rsp),%rdi
 10f340c:	00 
 10f340d:	48 8d b4 24 40 01 00 	lea    0x140(%rsp),%rsi
 10f3414:	00 
 10f3415:	48 8d 8c 24 d0 18 00 	lea    0x18d0(%rsp),%rcx
 10f341c:	00 
 10f341d:	4c 8d 8c 24 c0 0f 00 	lea    0xfc0(%rsp),%r9
 10f3424:	00 
 10f3425:	ba 01 00 00 00       	mov    $0x1,%edx
 10f342a:	41 b8 01 00 00 00    	mov    $0x1,%r8d
 10f3430:	41 56                	push   %r14
 10f3432:	6a 01                	push   $0x1
 10f3434:	c5 f8 77             	vzeroupper 
 10f3437:	e8 04 55 fd ff       	call   10c8940 <zstd.rleSequencePayloadLenForValuesWithLiteralsLen>
 10f343c:	48 83 c4 10          	add    $0x10,%rsp
 10f3440:	0f b7 9c 24 a0 02 00 	movzwl 0x2a0(%rsp),%ebx
 10f3447:	00 
 10f3448:	66 85 db             	test   %bx,%bx
 10f344b:	0f 85 fc 03 00 00    	jne    10f384d <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x200d>
 10f3451:	4c 8b ac 24 98 02 00 	mov    0x298(%rsp),%r13
 10f3458:	00 
 10f3459:	48 8b 44 24 68       	mov    0x68(%rsp),%rax
 10f345e:	48 89 84 24 40 01 00 	mov    %rax,0x140(%rsp)
 10f3465:	00 
 10f3466:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 10f346b:	48 89 84 24 d0 18 00 	mov    %rax,0x18d0(%rsp)
 10f3472:	00 
 10f3473:	48 8b 44 24 30       	mov    0x30(%rsp),%rax
 10f3478:	48 89 84 24 c0 0f 00 	mov    %rax,0xfc0(%rsp)
 10f347f:	00 
 10f3480:	48 8d bc 24 98 02 00 	lea    0x298(%rsp),%rdi
 10f3487:	00 
 10f3488:	48 8d b4 24 40 01 00 	lea    0x140(%rsp),%rsi
 10f348f:	00 
 10f3490:	48 8d 94 24 d0 18 00 	lea    0x18d0(%rsp),%rdx
 10f3497:	00 
 10f3498:	48 8d 8c 24 c0 0f 00 	lea    0xfc0(%rsp),%rcx
 10f349f:	00 
 10f34a0:	4d 89 f0             	mov    %r14,%r8
 10f34a3:	e8 a8 52 fd ff       	call   10c8750 <zstd.predefinedSequencePayloadLenWithLiteralsLen>
 10f34a8:	0f b7 94 24 a0 02 00 	movzwl 0x2a0(%rsp),%edx
 10f34af:	00 
 10f34b0:	85 d2                	test   %edx,%edx
 10f34b2:	0f 85 af 03 00 00    	jne    10f3867 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x2027>
 10f34b8:	48 8b 84 24 98 02 00 	mov    0x298(%rsp),%rax
 10f34bf:	00 
 10f34c0:	4c 39 e8             	cmp    %r13,%rax
 10f34c3:	4c 0f 42 e8          	cmovb  %rax,%r13
 10f34c7:	66 85 db             	test   %bx,%bx
 10f34ca:	4c 0f 45 e8          	cmovne %rax,%r13
 10f34ce:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 10f34d3:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f34d8:	48 8b 54 24 48       	mov    0x48(%rsp),%rdx
 10f34dd:	80 3a 00             	cmpb   $0x0,(%rdx)
 10f34e0:	74 26                	je     10f3508 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1cc8>
 10f34e2:	31 d2                	xor    %edx,%edx
 10f34e4:	48 8b 74 24 38       	mov    0x38(%rsp),%rsi
 10f34e9:	4c 39 2e             	cmp    %r13,(%rsi)
 10f34ec:	0f 97 c2             	seta   %dl
 10f34ef:	48 03 91 40 16 00 00 	add    0x1640(%rcx),%rdx
 10f34f6:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 10f34fd:	48 0f 43 f2          	cmovae %rdx,%rsi
 10f3501:	48 89 b1 40 16 00 00 	mov    %rsi,0x1640(%rcx)
 10f3508:	80 7c 24 28 00       	cmpb   $0x0,0x28(%rsp)
 10f350d:	0f 85 0c 01 00 00    	jne    10f361f <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1ddf>
 10f3513:	31 f6                	xor    %esi,%esi
 10f3515:	31 db                	xor    %ebx,%ebx
 10f3517:	31 d2                	xor    %edx,%edx
 10f3519:	31 ff                	xor    %edi,%edi
 10f351b:	44 8b 84 bc c0 0b 00 	mov    0xbc0(%rsp,%rdi,4),%r8d
 10f3522:	00 
 10f3523:	c6 84 24 98 02 00 00 	movb   $0x0,0x298(%rsp)
 10f352a:	00 
 10f352b:	40 84 f6             	test   %sil,%sil
 10f352e:	0f 85 cf 00 00 00    	jne    10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f3534:	4c 01 c3             	add    %r8,%rbx
 10f3537:	48 81 fb 00 00 02 00 	cmp    $0x20000,%rbx
 10f353e:	0f 87 bf 00 00 00    	ja     10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f3544:	49 83 f8 01          	cmp    $0x1,%r8
 10f3548:	48 83 da ff          	sbb    $0xffffffffffffffff,%rdx
 10f354c:	44 8b 84 bc c4 0b 00 	mov    0xbc4(%rsp,%rdi,4),%r8d
 10f3553:	00 
 10f3554:	c6 84 24 98 02 00 00 	movb   $0x0,0x298(%rsp)
 10f355b:	00 
 10f355c:	40 84 f6             	test   %sil,%sil
 10f355f:	0f 85 9e 00 00 00    	jne    10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f3565:	4c 01 c3             	add    %r8,%rbx
 10f3568:	48 81 fb 00 00 02 00 	cmp    $0x20000,%rbx
 10f356f:	0f 87 8e 00 00 00    	ja     10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f3575:	49 83 f8 01          	cmp    $0x1,%r8
 10f3579:	48 83 da ff          	sbb    $0xffffffffffffffff,%rdx
 10f357d:	44 8b 84 bc c8 0b 00 	mov    0xbc8(%rsp,%rdi,4),%r8d
 10f3584:	00 
 10f3585:	c6 84 24 98 02 00 00 	movb   $0x0,0x298(%rsp)
 10f358c:	00 
 10f358d:	40 84 f6             	test   %sil,%sil
 10f3590:	75 71                	jne    10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f3592:	4c 01 c3             	add    %r8,%rbx
 10f3595:	48 81 fb 00 00 02 00 	cmp    $0x20000,%rbx
 10f359c:	77 65                	ja     10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f359e:	49 83 f8 01          	cmp    $0x1,%r8
 10f35a2:	48 83 da ff          	sbb    $0xffffffffffffffff,%rdx
 10f35a6:	44 8b 84 bc cc 0b 00 	mov    0xbcc(%rsp,%rdi,4),%r8d
 10f35ad:	00 
 10f35ae:	c6 84 24 98 02 00 00 	movb   $0x0,0x298(%rsp)
 10f35b5:	00 
 10f35b6:	40 84 f6             	test   %sil,%sil
 10f35b9:	75 48                	jne    10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f35bb:	4c 01 c3             	add    %r8,%rbx
 10f35be:	48 81 fb 00 00 02 00 	cmp    $0x20000,%rbx
 10f35c5:	77 3c                	ja     10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f35c7:	49 83 f8 01          	cmp    $0x1,%r8
 10f35cb:	48 83 da ff          	sbb    $0xffffffffffffffff,%rdx
 10f35cf:	48 83 c7 04          	add    $0x4,%rdi
 10f35d3:	48 81 ff 00 01 00 00 	cmp    $0x100,%rdi
 10f35da:	0f 85 3b ff ff ff    	jne    10f351b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1cdb>
 10f35e0:	48 8d b2 ff f7 ff ff 	lea    -0x801(%rdx),%rsi
 10f35e7:	48 81 fe 01 f8 ff ff 	cmp    $0xfffffffffffff801,%rsi
 10f35ee:	72 13                	jb     10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f35f0:	c6 84 24 98 02 00 00 	movb   $0x0,0x298(%rsp)
 10f35f7:	00 
 10f35f8:	31 f6                	xor    %esi,%esi
 10f35fa:	40 84 f6             	test   %sil,%sil
 10f35fd:	0f 84 09 01 00 00    	je     10f370c <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1ecc>
 10f3603:	48 8b 91 58 16 00 00 	mov    0x1658(%rcx),%rdx
 10f360a:	48 ff c2             	inc    %rdx
 10f360d:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 10f3614:	48 0f 45 f2          	cmovne %rdx,%rsi
 10f3618:	48 89 b1 58 16 00 00 	mov    %rsi,0x1658(%rcx)
 10f361f:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 10f3625:	4c 89 28             	mov    %r13,(%rax)
 10f3628:	c6 40 08 01          	movb   $0x1,0x8(%rax)
 10f362c:	e9 f3 f3 ff ff       	jmp    10f2a24 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11e4>
 10f3631:	66 ba 3b 00          	mov    $0x3b,%dx
 10f3635:	66 89 50 10          	mov    %dx,0x10(%rax)
 10f3639:	e9 e6 f3 ff ff       	jmp    10f2a24 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11e4>
 10f363e:	0f b6 b4 24 c0 0f 00 	movzbl 0xfc0(%rsp),%esi
 10f3645:	00 
 10f3646:	40 80 e6 01          	and    $0x1,%sil
 10f364a:	40 88 b4 24 d0 18 00 	mov    %sil,0x18d0(%rsp)
 10f3651:	00 
 10f3652:	74 72                	je     10f36c6 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1e86>
 10f3654:	48 8b b0 e0 11 00 00 	mov    0x11e0(%rax),%rsi
 10f365b:	48 85 f6             	test   %rsi,%rsi
 10f365e:	0f 88 23 f6 ff ff    	js     10f2c87 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1447>
 10f3664:	45 31 c9             	xor    %r9d,%r9d
 10f3667:	45 84 c9             	test   %r9b,%r9b
 10f366a:	0f 85 17 f6 ff ff    	jne    10f2c87 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1447>
 10f3670:	44 8b 88 e8 15 00 00 	mov    0x15e8(%rax),%r9d
 10f3677:	4d 89 c2             	mov    %r8,%r10
 10f367a:	4d 29 ca             	sub    %r9,%r10
 10f367d:	4c 01 d6             	add    %r10,%rsi
 10f3680:	0f 90 84 24 c0 0f 00 	seto   0xfc0(%rsp)
 10f3687:	00 
 10f3688:	0f 80 f9 f5 ff ff    	jo     10f2c87 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1447>
 10f368e:	4d 89 ee             	mov    %r13,%r14
 10f3691:	48 8d 04 3f          	lea    (%rdi,%rdi,1),%rax
 10f3695:	48 8d 04 80          	lea    (%rax,%rax,4),%rax
 10f3699:	48 29 c6             	sub    %rax,%rsi
 10f369c:	0f 90 84 24 c0 0f 00 	seto   0xfc0(%rsp)
 10f36a3:	00 
 10f36a4:	0f 81 e1 00 00 00    	jno    10f378b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1f4b>
 10f36aa:	48 8b 44 24 20       	mov    0x20(%rsp),%rax
 10f36af:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f36b4:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f36b9:	4c 8b 64 24 58       	mov    0x58(%rsp),%r12
 10f36be:	4d 89 f5             	mov    %r14,%r13
 10f36c1:	e9 c1 f5 ff ff       	jmp    10f2c87 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1447>
 10f36c6:	f6 84 24 d0 18 00 00 	testb  $0x1,0x18d0(%rsp)
 10f36cd:	01 
 10f36ce:	0f 85 f7 f5 ff ff    	jne    10f2ccb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x148b>
 10f36d4:	48 8b b0 18 16 00 00 	mov    0x1618(%rax),%rsi
 10f36db:	48 ff c6             	inc    %rsi
 10f36de:	48 c7 c7 ff ff ff ff 	mov    $0xffffffffffffffff,%rdi
 10f36e5:	48 0f 45 fe          	cmovne %rsi,%rdi
 10f36e9:	48 89 b8 18 16 00 00 	mov    %rdi,0x1618(%rax)
 10f36f0:	e9 d6 f5 ff ff       	jmp    10f2ccb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x148b>
 10f36f5:	48 01 de             	add    %rbx,%rsi
 10f36f8:	4c 39 f6             	cmp    %r14,%rsi
 10f36fb:	4c 0f 42 f6          	cmovb  %rsi,%r14
 10f36ff:	c7 44 24 28 00 00 00 	movl   $0x0,0x28(%rsp)
 10f3706:	00 
 10f3707:	e9 de fc ff ff       	jmp    10f33ea <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1baa>
 10f370c:	49 39 dc             	cmp    %rbx,%r12
 10f370f:	0f 82 ee fe ff ff    	jb     10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f3715:	48 8d 34 9b          	lea    (%rbx,%rbx,4),%rsi
 10f3719:	48 8d 34 73          	lea    (%rbx,%rsi,2),%rsi
 10f371d:	49 39 f4             	cmp    %rsi,%r12
 10f3720:	0f 87 dd fe ff ff    	ja     10f3603 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1dc3>
 10f3726:	48 89 91 d8 11 00 00 	mov    %rdx,0x11d8(%rcx)
 10f372d:	4c 89 a1 e0 11 00 00 	mov    %r12,0x11e0(%rcx)
 10f3734:	48 8d b9 e8 11 00 00 	lea    0x11e8(%rcx),%rdi
 10f373b:	ba 00 04 00 00       	mov    $0x400,%edx
 10f3740:	49 89 ce             	mov    %rcx,%r14
 10f3743:	4c 89 fe             	mov    %r15,%rsi
 10f3746:	e8 75 9d 00 00       	call   10fd4c0 <compiler_rt.memcpy.memcpyFast>
 10f374b:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 10f3750:	41 89 9e e8 15 00 00 	mov    %ebx,0x15e8(%r14)
 10f3757:	41 c6 86 f0 15 00 00 	movb   $0x1,0x15f0(%r14)
 10f375e:	01 
 10f375f:	49 c7 86 f8 15 00 00 	movq   $0x0,0x15f8(%r14)
 10f3766:	00 00 00 00 
 10f376a:	49 8b 8e 50 16 00 00 	mov    0x1650(%r14),%rcx
 10f3771:	48 ff c1             	inc    %rcx
 10f3774:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 10f377b:	48 0f 45 d1          	cmovne %rcx,%rdx
 10f377f:	49 89 96 50 16 00 00 	mov    %rdx,0x1650(%r14)
 10f3786:	e9 94 fe ff ff       	jmp    10f361f <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1ddf>
 10f378b:	49 39 f0             	cmp    %rsi,%r8
 10f378e:	49 0f 4f f0          	cmovg  %r8,%rsi
 10f3792:	f6 84 24 d0 18 00 00 	testb  $0x1,0x18d0(%rsp)
 10f3799:	01 
 10f379a:	48 8b 44 24 20       	mov    0x20(%rsp),%rax
 10f379f:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f37a4:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f37a9:	4c 8b 64 24 58       	mov    0x58(%rsp),%r12
 10f37ae:	4d 89 f5             	mov    %r14,%r13
 10f37b1:	0f 84 1d ff ff ff    	je     10f36d4 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1e94>
 10f37b7:	48 8b 88 f8 15 00 00 	mov    0x15f8(%rax),%rcx
 10f37be:	4c 8b 80 20 16 00 00 	mov    0x1620(%rax),%r8
 10f37c5:	49 ff c0             	inc    %r8
 10f37c8:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 10f37cf:	4c 0f 44 c2          	cmove  %rdx,%r8
 10f37d3:	4c 89 80 20 16 00 00 	mov    %r8,0x1620(%rax)
 10f37da:	4c 8b 80 68 16 00 00 	mov    0x1668(%rax),%r8
 10f37e1:	49 01 f8             	add    %rdi,%r8
 10f37e4:	4c 0f 42 c2          	cmovb  %rdx,%r8
 10f37e8:	4c 89 80 68 16 00 00 	mov    %r8,0x1668(%rax)
 10f37ef:	4c 8b 80 70 16 00 00 	mov    0x1670(%rax),%r8
 10f37f6:	49 39 f8             	cmp    %rdi,%r8
 10f37f9:	4c 0f 46 c7          	cmovbe %rdi,%r8
 10f37fd:	4c 89 80 70 16 00 00 	mov    %r8,0x1670(%rax)
 10f3804:	4c 8b 80 78 16 00 00 	mov    0x1678(%rax),%r8
 10f380b:	49 39 c8             	cmp    %rcx,%r8
 10f380e:	4c 0f 46 c1          	cmovbe %rcx,%r8
 10f3812:	4c 89 80 78 16 00 00 	mov    %r8,0x1678(%rax)
 10f3819:	48 85 ff             	test   %rdi,%rdi
 10f381c:	74 6e                	je     10f388c <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x204c>
 10f381e:	f3 48 0f bd c7       	lzcnt  %rdi,%rax
 10f3823:	f6 d0                	not    %al
 10f3825:	24 3f                	and    $0x3f,%al
 10f3827:	0f b6 c0             	movzbl %al,%eax
 10f382a:	3c 10                	cmp    $0x10,%al
 10f382c:	bf 10 00 00 00       	mov    $0x10,%edi
 10f3831:	0f 42 f8             	cmovb  %eax,%edi
 10f3834:	40 fe c7             	inc    %dil
 10f3837:	40 0f b6 c7          	movzbl %dil,%eax
 10f383b:	eb 51                	jmp    10f388e <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x204e>
 10f383d:	45 31 e4             	xor    %r12d,%r12d
 10f3840:	4c 8d ac 24 c0 0b 00 	lea    0xbc0(%rsp),%r13
 10f3847:	00 
 10f3848:	e9 1d fb ff ff       	jmp    10f336a <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1b2a>
 10f384d:	66 83 fb 3b          	cmp    $0x3b,%bx
 10f3851:	0f 84 02 fc ff ff    	je     10f3459 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1c19>
 10f3857:	89 da                	mov    %ebx,%edx
 10f3859:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 10f385e:	66 89 50 10          	mov    %dx,0x10(%rax)
 10f3862:	e9 bd f1 ff ff       	jmp    10f2a24 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11e4>
 10f3867:	83 fa 3b             	cmp    $0x3b,%edx
 10f386a:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 10f386f:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f3874:	75 0d                	jne    10f3883 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x2043>
 10f3876:	66 ba 3b 00          	mov    $0x3b,%dx
 10f387a:	66 85 db             	test   %bx,%bx
 10f387d:	0f 84 55 fc ff ff    	je     10f34d8 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x1c98>
 10f3883:	66 89 50 10          	mov    %dx,0x10(%rax)
 10f3887:	e9 98 f1 ff ff       	jmp    10f2a24 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11e4>
 10f388c:	31 c0                	xor    %eax,%eax
 10f388e:	48 8b 7c 24 20       	mov    0x20(%rsp),%rdi
 10f3893:	4c 8b 84 c7 80 16 00 	mov    0x1680(%rdi,%rax,8),%r8
 10f389a:	00 
 10f389b:	49 ff c0             	inc    %r8
 10f389e:	4c 0f 44 c2          	cmove  %rdx,%r8
 10f38a2:	4c 89 84 c7 80 16 00 	mov    %r8,0x1680(%rdi,%rax,8)
 10f38a9:	00 
 10f38aa:	48 85 c9             	test   %rcx,%rcx
 10f38ad:	74 1d                	je     10f38cc <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x208c>
 10f38af:	f3 48 0f bd c1       	lzcnt  %rcx,%rax
 10f38b4:	f6 d0                	not    %al
 10f38b6:	24 3f                	and    $0x3f,%al
 10f38b8:	0f b6 c0             	movzbl %al,%eax
 10f38bb:	3c 0e                	cmp    $0xe,%al
 10f38bd:	b9 0e 00 00 00       	mov    $0xe,%ecx
 10f38c2:	0f 42 c8             	cmovb  %eax,%ecx
 10f38c5:	fe c1                	inc    %cl
 10f38c7:	0f b6 c1             	movzbl %cl,%eax
 10f38ca:	eb 02                	jmp    10f38ce <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x208e>
 10f38cc:	31 c0                	xor    %eax,%eax
 10f38ce:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f38d3:	48 8b 94 c1 10 17 00 	mov    0x1710(%rcx,%rax,8),%rdx
 10f38da:	00 
 10f38db:	48 ff c2             	inc    %rdx
 10f38de:	48 c7 c7 ff ff ff ff 	mov    $0xffffffffffffffff,%rdi
 10f38e5:	48 0f 45 fa          	cmovne %rdx,%rdi
 10f38e9:	48 89 bc c1 10 17 00 	mov    %rdi,0x1710(%rcx,%rax,8)
 10f38f0:	00 
 10f38f1:	c6 84 24 c0 0f 00 00 	movb   $0x0,0xfc0(%rsp)
 10f38f8:	00 
 10f38f9:	31 c0                	xor    %eax,%eax
 10f38fb:	84 c0                	test   %al,%al
 10f38fd:	74 1c                	je     10f391b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x20db>
 10f38ff:	48 8b 44 24 20       	mov    0x20(%rsp),%rax
 10f3904:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f3909:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f390e:	4c 8b 64 24 58       	mov    0x58(%rsp),%r12
 10f3913:	4d 89 f5             	mov    %r14,%r13
 10f3916:	e9 b0 f3 ff ff       	jmp    10f2ccb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x148b>
 10f391b:	31 c0                	xor    %eax,%eax
 10f391d:	4c 8b 64 24 58       	mov    0x58(%rsp),%r12
 10f3922:	49 81 fc 00 04 00 00 	cmp    $0x400,%r12
 10f3929:	0f 93 c0             	setae  %al
 10f392c:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 10f3930:	48 01 f0             	add    %rsi,%rax
 10f3933:	48 83 c0 08          	add    $0x8,%rax
 10f3937:	48 c1 e8 03          	shr    $0x3,%rax
 10f393b:	48 8d 58 06          	lea    0x6(%rax),%rbx
 10f393f:	b9 05 00 00 00       	mov    $0x5,%ecx
 10f3944:	48 89 4c 24 28       	mov    %rcx,0x28(%rsp)
 10f3949:	49 81 fc 00 04 00 00 	cmp    $0x400,%r12
 10f3950:	48 0f 42 d8          	cmovb  %rax,%rbx
 10f3954:	48 8b 44 24 20       	mov    0x20(%rsp),%rax
 10f3959:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f395e:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f3963:	4d 89 f5             	mov    %r14,%r13
 10f3966:	72 2a                	jb     10f3992 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x2152>
 10f3968:	be 06 00 00 00       	mov    $0x6,%esi
 10f396d:	48 89 74 24 28       	mov    %rsi,0x28(%rsp)
 10f3972:	49 81 fc 00 40 00 00 	cmp    $0x4000,%r12
 10f3979:	72 17                	jb     10f3992 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x2152>
 10f397b:	be 07 00 00 00       	mov    $0x7,%esi
 10f3980:	48 89 74 24 28       	mov    %rsi,0x28(%rsp)
 10f3985:	49 81 fc 00 00 04 00 	cmp    $0x40000,%r12
 10f398c:	0f 83 39 f3 ff ff    	jae    10f2ccb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x148b>
 10f3992:	31 f6                	xor    %esi,%esi
 10f3994:	40 84 f6             	test   %sil,%sil
 10f3997:	0f 85 2e f3 ff ff    	jne    10f2ccb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x148b>
 10f399d:	31 f6                	xor    %esi,%esi
 10f399f:	40 84 f6             	test   %sil,%sil
 10f39a2:	0f 85 23 f3 ff ff    	jne    10f2ccb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x148b>
 10f39a8:	48 8d bc 24 98 02 00 	lea    0x298(%rsp),%rdi
 10f39af:	00 
 10f39b0:	48 8b 74 24 68       	mov    0x68(%rsp),%rsi
 10f39b5:	c5 f8 77             	vzeroupper 
 10f39b8:	e8 53 0e 00 00       	call   10f4810 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).sequenceBase>
 10f39bd:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f39c2:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f39c7:	48 8b 44 24 20       	mov    0x20(%rsp),%rax
 10f39cc:	80 bc 24 a0 02 00 00 	cmpb   $0x0,0x2a0(%rsp)
 10f39d3:	00 
 10f39d4:	0f 84 f1 f2 ff ff    	je     10f2ccb <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x148b>
 10f39da:	48 03 5c 24 28       	add    0x28(%rsp),%rbx
 10f39df:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 10f39e4:	48 39 d8             	cmp    %rbx,%rax
 10f39e7:	48 0f 42 d8          	cmovb  %rax,%rbx
 10f39eb:	48 03 9c 24 98 02 00 	add    0x298(%rsp),%rbx
 10f39f2:	00 
 10f39f3:	0f 92 c0             	setb   %al
 10f39f6:	0f 92 84 24 c0 0f 00 	setb   0xfc0(%rsp)
 10f39fd:	00 
 10f39fe:	84 c0                	test   %al,%al
 10f3a00:	74 43                	je     10f3a45 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x2205>
 10f3a02:	c6 44 24 18 00       	movb   $0x0,0x18(%rsp)
 10f3a07:	48 8d 44 24 18       	lea    0x18(%rsp),%rax
 10f3a0c:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 10f3a11:	48 8d 44 24 70       	lea    0x70(%rsp),%rax
 10f3a16:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 10f3a1b:	48 8b 44 24 20       	mov    0x20(%rsp),%rax
 10f3a20:	48 8b 4c 24 30       	mov    0x30(%rsp),%rcx
 10f3a25:	48 8b 54 24 40       	mov    0x40(%rsp),%rdx
 10f3a2a:	4c 8b 64 24 58       	mov    0x58(%rsp),%r12
 10f3a2f:	4d 89 f5             	mov    %r14,%r13
 10f3a32:	e9 b6 f2 ff ff       	jmp    10f2ced <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x14ad>
 10f3a37:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 10f3a3c:	66 89 50 10          	mov    %dx,0x10(%rax)
 10f3a40:	e9 df ef ff ff       	jmp    10f2a24 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11e4>
 10f3a45:	48 89 5c 24 70       	mov    %rbx,0x70(%rsp)
 10f3a4a:	c6 44 24 18 01       	movb   $0x1,0x18(%rsp)
 10f3a4f:	48 8b 45 10          	mov    0x10(%rbp),%rax
 10f3a53:	48 3b 18             	cmp    (%rax),%rbx
 10f3a56:	0f 83 8a 00 00 00    	jae    10f3ae6 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x22a6>
 10f3a5c:	48 3b 9c 24 00 01 00 	cmp    0x100(%rsp),%rbx
 10f3a63:	00 
 10f3a64:	0f 94 c0             	sete   %al
 10f3a67:	48 8b 8c 24 80 00 00 	mov    0x80(%rsp),%rcx
 10f3a6e:	00 
 10f3a6f:	48 39 4c 24 30       	cmp    %rcx,0x30(%rsp)
 10f3a74:	0f 97 c1             	seta   %cl
 10f3a77:	20 c1                	and    %al,%cl
 10f3a79:	48 8d 44 24 18       	lea    0x18(%rsp),%rax
 10f3a7e:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 10f3a83:	48 8d 44 24 70       	lea    0x70(%rsp),%rax
 10f3a88:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 10f3a8d:	80 f9 01             	cmp    $0x1,%cl
 10f3a90:	75 89                	jne    10f3a1b <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x21db>
 10f3a92:	48 8b 44 24 20       	mov    0x20(%rsp),%rax
 10f3a97:	48 8b 88 60 16 00 00 	mov    0x1660(%rax),%rcx
 10f3a9e:	48 ff c1             	inc    %rcx
 10f3aa1:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 10f3aa8:	48 0f 45 d1          	cmovne %rcx,%rdx
 10f3aac:	48 89 90 60 16 00 00 	mov    %rdx,0x1660(%rax)
 10f3ab3:	e9 68 ff ff ff       	jmp    10f3a20 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x21e0>
 10f3ab8:	b0 01                	mov    $0x1,%al
 10f3aba:	89 44 24 28          	mov    %eax,0x28(%rsp)
 10f3abe:	48 8b 86 98 10 00 00 	mov    0x1098(%rsi),%rax
 10f3ac5:	48 ff c0             	inc    %rax
 10f3ac8:	48 c7 c1 ff ff ff ff 	mov    $0xffffffffffffffff,%rcx
 10f3acf:	48 0f 45 c8          	cmovne %rax,%rcx
 10f3ad3:	48 89 8e 98 10 00 00 	mov    %rcx,0x1098(%rsi)
 10f3ada:	0f b6 86 c0 10 00 00 	movzbl 0x10c0(%rsi),%eax
 10f3ae1:	e9 06 f7 ff ff       	jmp    10f31ec <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x19ac>
 10f3ae6:	0f 95 c1             	setne  %cl
 10f3ae9:	48 8b 54 24 30       	mov    0x30(%rsp),%rdx
 10f3aee:	48 3b 50 08          	cmp    0x8(%rax),%rdx
 10f3af2:	0f 96 c0             	setbe  %al
 10f3af5:	08 c8                	or     %cl,%al
 10f3af7:	48 3b 9c 24 00 01 00 	cmp    0x100(%rsp),%rbx
 10f3afe:	00 
 10f3aff:	0f 94 c1             	sete   %cl
 10f3b02:	48 3b 94 24 80 00 00 	cmp    0x80(%rsp),%rdx
 10f3b09:	00 
 10f3b0a:	0f 97 c2             	seta   %dl
 10f3b0d:	84 d1                	test   %dl,%cl
 10f3b0f:	74 21                	je     10f3b32 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x22f2>
 10f3b11:	48 8b 4c 24 20       	mov    0x20(%rsp),%rcx
 10f3b16:	48 8b 91 60 16 00 00 	mov    0x1660(%rcx),%rdx
 10f3b1d:	48 ff c2             	inc    %rdx
 10f3b20:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 10f3b27:	48 0f 45 f2          	cmovne %rdx,%rsi
 10f3b2b:	48 89 b1 60 16 00 00 	mov    %rsi,0x1660(%rcx)
 10f3b32:	84 c0                	test   %al,%al
 10f3b34:	0f 84 cd fe ff ff    	je     10f3a07 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x21c7>
 10f3b3a:	48 8b 44 24 20       	mov    0x20(%rsp),%rax
 10f3b3f:	48 8b 88 80 10 00 00 	mov    0x1080(%rax),%rcx
 10f3b46:	48 ff c1             	inc    %rcx
 10f3b49:	48 c7 c2 ff ff ff ff 	mov    $0xffffffffffffffff,%rdx
 10f3b50:	48 0f 45 d1          	cmovne %rcx,%rdx
 10f3b54:	48 89 90 80 10 00 00 	mov    %rdx,0x1080(%rax)
 10f3b5b:	c5 fa 6f 80 30 16 00 	vmovdqu 0x1630(%rax),%xmm0
 10f3b62:	00 
 10f3b63:	c4 e2 79 59 0d cc c4 	vpbroadcastq -0xb3b34(%rip),%xmm1        # 1040038 <__anon_11221+0x8>
 10f3b6a:	f4 ff 
 10f3b6c:	c5 f9 ef d1          	vpxor  %xmm1,%xmm0,%xmm2
 10f3b70:	c5 e1 76 db          	vpcmpeqd %xmm3,%xmm3,%xmm3
 10f3b74:	c5 f9 fb c3          	vpsubq %xmm3,%xmm0,%xmm0
 10f3b78:	c5 f9 ef c9          	vpxor  %xmm1,%xmm0,%xmm1
 10f3b7c:	c4 e2 69 37 c9       	vpcmpgtq %xmm1,%xmm2,%xmm1
 10f3b81:	c5 f9 eb c1          	vpor   %xmm1,%xmm0,%xmm0
 10f3b85:	c5 fa 7f 80 30 16 00 	vmovdqu %xmm0,0x1630(%rax)
 10f3b8c:	00 
 10f3b8d:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 10f3b91:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 10f3b96:	c5 fa 7f 00          	vmovdqu %xmm0,(%rax)
 10f3b9a:	48 c7 40 10 00 00 00 	movq   $0x0,0x10(%rax)
 10f3ba1:	00 
 10f3ba2:	e9 7d ee ff ff       	jmp    10f2a24 <zstd.literals.winner_cost_cache.Cache(zstd.SingleLiteralCostCodec,.prune).payloadForWinner+0x11e4>

Disassembly of section .vort_zstd_multi_sequence_winner:

Disassembly of section .vort_zstd_wide_sequence:

Disassembly of section .vort_zstd_fse_encode:

Disassembly of section .vort_zstd_dominance:

Disassembly of section .vort_zstd_dense_huffman:
