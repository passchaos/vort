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

 10f328f:	4c 8b a6 a0 10 00 00 	mov    0x10a0(%rsi),%r12
 10f3296:	49 ff c4             	inc    %r12
 10f3299:	4d 0f 44 e5          	cmove  %r13,%r12
 10f329d:	4c 89 a6 a0 10 00 00 	mov    %r12,0x10a0(%rsi)
