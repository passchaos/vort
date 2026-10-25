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
