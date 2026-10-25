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
