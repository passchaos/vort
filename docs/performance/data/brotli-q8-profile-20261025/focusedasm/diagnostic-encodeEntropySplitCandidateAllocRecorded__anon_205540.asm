
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000123f220 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540>:
 123f220:	55                   	push   %rbp
 123f221:	48 89 e5             	mov    %rsp,%rbp
 123f224:	41 57                	push   %r15
 123f226:	41 56                	push   %r14
 123f228:	41 55                	push   %r13
 123f22a:	41 54                	push   %r12
 123f22c:	53                   	push   %rbx
 123f22d:	48 81 ec d8 40 00 00 	sub    $0x40d8,%rsp
 123f234:	4d 89 ca             	mov    %r9,%r10
 123f237:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 123f23b:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 123f23f:	48 8b 7d 20          	mov    0x20(%rbp),%rdi
 123f243:	48 8b 75 18          	mov    0x18(%rbp),%rsi
 123f247:	c5 f8 10 46 10       	vmovups 0x10(%rsi),%xmm0
 123f24c:	c5 f8 29 85 70 fd ff 	vmovaps %xmm0,-0x290(%rbp)
 123f253:	ff 
 123f254:	c5 fc 10 46 20       	vmovups 0x20(%rsi),%ymm0
 123f259:	c5 fc 11 85 f0 e9 ff 	vmovups %ymm0,-0x1610(%rbp)
 123f260:	ff 
 123f261:	0f b6 46 40          	movzbl 0x40(%rsi),%eax
 123f265:	88 45 9e             	mov    %al,-0x62(%rbp)
 123f268:	0f b6 46 45          	movzbl 0x45(%rsi),%eax
 123f26c:	88 85 2a ff ff ff    	mov    %al,-0xd6(%rbp)
 123f272:	44 0f b6 4e 49       	movzbl 0x49(%rsi),%r9d
 123f277:	0f b6 46 4a          	movzbl 0x4a(%rsi),%eax
 123f27b:	88 45 c6             	mov    %al,-0x3a(%rbp)
 123f27e:	0f b6 46 4b          	movzbl 0x4b(%rsi),%eax
 123f282:	88 45 9a             	mov    %al,-0x66(%rbp)
 123f285:	0f b6 46 4c          	movzbl 0x4c(%rsi),%eax
 123f289:	88 45 9b             	mov    %al,-0x65(%rbp)
 123f28c:	0f b6 46 4d          	movzbl 0x4d(%rsi),%eax
 123f290:	88 45 9d             	mov    %al,-0x63(%rbp)
 123f293:	0f b6 46 4e          	movzbl 0x4e(%rsi),%eax
 123f297:	88 45 9f             	mov    %al,-0x61(%rbp)
 123f29a:	48 8b 47 08          	mov    0x8(%rdi),%rax
 123f29e:	48 89 85 68 fd ff ff 	mov    %rax,-0x298(%rbp)
 123f2a5:	f6 46 48 01          	testb  $0x1,0x48(%rsi)
 123f2a9:	0f b6 87 58 01 00 00 	movzbl 0x158(%rdi),%eax
 123f2b0:	88 45 9c             	mov    %al,-0x64(%rbp)
 123f2b3:	4c 89 95 78 ff ff ff 	mov    %r10,-0x88(%rbp)
 123f2ba:	4c 89 45 90          	mov    %r8,-0x70(%rbp)
 123f2be:	48 89 4d 88          	mov    %rcx,-0x78(%rbp)
 123f2c2:	48 89 55 c8          	mov    %rdx,-0x38(%rbp)
 123f2c6:	0f 84 bd 00 00 00    	je     123f389 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x169>
 123f2cc:	48 8d 85 80 c1 ff ff 	lea    -0x3e80(%rbp),%rax
 123f2d3:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 123f2da:	48 8d 85 10 c1 ff ff 	lea    -0x3ef0(%rbp),%rax
 123f2e1:	48 89 85 68 ff ff ff 	mov    %rax,-0x98(%rbp)
 123f2e8:	48 8d 85 a0 c0 ff ff 	lea    -0x3f60(%rbp),%rax
 123f2ef:	48 89 85 88 fd ff ff 	mov    %rax,-0x278(%rbp)
 123f2f6:	48 8d 85 f8 c1 ff ff 	lea    -0x3e08(%rbp),%rax
 123f2fd:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 123f301:	4c 8d a5 88 c1 ff ff 	lea    -0x3e78(%rbp),%r12
 123f308:	4c 8d bd 18 c1 ff ff 	lea    -0x3ee8(%rbp),%r15
 123f30f:	4c 8d ad a8 c0 ff ff 	lea    -0x3f58(%rbp),%r13
 123f316:	0f b7 87 5b 01 00 00 	movzwl 0x15b(%rdi),%eax
 123f31d:	66 89 85 2e fe ff ff 	mov    %ax,-0x1d2(%rbp)
 123f324:	4c 8d b5 38 c0 ff ff 	lea    -0x3fc8(%rbp),%r14
 123f32b:	48 8d 9d 58 bf ff ff 	lea    -0x40a8(%rbp),%rbx
 123f332:	44 88 4d c7          	mov    %r9b,-0x39(%rbp)
 123f336:	4c 8d 8d 2e fe ff ff 	lea    -0x1d2(%rbp),%r9
 123f33d:	48 89 df             	mov    %rbx,%rdi
 123f340:	48 89 d6             	mov    %rdx,%rsi
 123f343:	48 89 ca             	mov    %rcx,%rdx
 123f346:	4c 89 c1             	mov    %r8,%rcx
 123f349:	4d 89 d0             	mov    %r10,%r8
 123f34c:	c5 f8 77             	vzeroupper 
 123f34f:	e8 7c f3 01 00       	call   125e6d0 <br.encoder.literal_block_split.chooseProposals>
 123f354:	48 8d b5 30 c0 ff ff 	lea    -0x3fd0(%rbp),%rsi
 123f35b:	48 8d 8d c0 bf ff ff 	lea    -0x4040(%rbp),%rcx
 123f362:	4c 8d 9d f0 c1 ff ff 	lea    -0x3e10(%rbp),%r11
 123f369:	4c 8d 95 c8 bf ff ff 	lea    -0x4038(%rbp),%r10
 123f370:	4c 8d 85 c1 bf ff ff 	lea    -0x403f(%rbp),%r8
 123f377:	48 8d bd 60 c2 ff ff 	lea    -0x3da0(%rbp),%rdi
 123f37e:	44 0f b6 4d c7       	movzbl -0x39(%rbp),%r9d
 123f383:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 123f387:	eb 6b                	jmp    123f3f4 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1d4>
 123f389:	bb 58 f0 08 01       	mov    $0x108f058,%ebx
 123f38e:	bf 60 f3 08 01       	mov    $0x108f360,%edi
 123f393:	41 bb f0 f2 08 01    	mov    $0x108f2f0,%r11d
 123f399:	b8 80 f2 08 01       	mov    $0x108f280,%eax
 123f39e:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 123f3a5:	b8 10 f2 08 01       	mov    $0x108f210,%eax
 123f3aa:	48 89 85 68 ff ff ff 	mov    %rax,-0x98(%rbp)
 123f3b1:	b8 a0 f1 08 01       	mov    $0x108f1a0,%eax
 123f3b6:	48 89 85 88 fd ff ff 	mov    %rax,-0x278(%rbp)
 123f3bd:	41 ba c8 f0 08 01    	mov    $0x108f0c8,%r10d
 123f3c3:	41 b8 c1 f0 08 01    	mov    $0x108f0c1,%r8d
 123f3c9:	b9 c0 f0 08 01       	mov    $0x108f0c0,%ecx
 123f3ce:	b8 f8 f2 08 01       	mov    $0x108f2f8,%eax
 123f3d3:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 123f3d7:	41 bc 88 f2 08 01    	mov    $0x108f288,%r12d
 123f3dd:	41 bf 18 f2 08 01    	mov    $0x108f218,%r15d
 123f3e3:	41 bd a8 f1 08 01    	mov    $0x108f1a8,%r13d
 123f3e9:	41 be 38 f1 08 01    	mov    $0x108f138,%r14d
 123f3ef:	be 30 f1 08 01       	mov    $0x108f130,%esi
 123f3f4:	48 8b 43 60          	mov    0x60(%rbx),%rax
 123f3f8:	48 89 85 50 fa ff ff 	mov    %rax,-0x5b0(%rbp)
 123f3ff:	c5 fc 10 03          	vmovups (%rbx),%ymm0
 123f403:	c5 fc 10 4b 20       	vmovups 0x20(%rbx),%ymm1
 123f408:	c5 fc 10 53 40       	vmovups 0x40(%rbx),%ymm2
 123f40d:	c5 fc 11 95 30 fa ff 	vmovups %ymm2,-0x5d0(%rbp)
 123f414:	ff 
 123f415:	c5 fc 11 8d 10 fa ff 	vmovups %ymm1,-0x5f0(%rbp)
 123f41c:	ff 
 123f41d:	c5 fc 11 85 f0 f9 ff 	vmovups %ymm0,-0x610(%rbp)
 123f424:	ff 
 123f425:	0f b6 09             	movzbl (%rcx),%ecx
 123f428:	0f b6 36             	movzbl (%rsi),%esi
 123f42b:	49 8b 46 60          	mov    0x60(%r14),%rax
 123f42f:	48 89 85 c0 fa ff ff 	mov    %rax,-0x540(%rbp)
 123f436:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 123f43b:	c4 c1 7c 10 4e 40    	vmovups 0x40(%r14),%ymm1
 123f441:	c5 fc 11 8d a0 fa ff 	vmovups %ymm1,-0x560(%rbp)
 123f448:	ff 
 123f449:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 123f44f:	c5 fc 11 8d 80 fa ff 	vmovups %ymm1,-0x580(%rbp)
 123f456:	ff 
 123f457:	c5 fc 11 85 60 fa ff 	vmovups %ymm0,-0x5a0(%rbp)
 123f45e:	ff 
 123f45f:	48 8b 85 88 fd ff ff 	mov    -0x278(%rbp),%rax
 123f466:	0f b6 00             	movzbl (%rax),%eax
 123f469:	88 85 2b ff ff ff    	mov    %al,-0xd5(%rbp)
 123f46f:	c4 c1 7c 10 45 20    	vmovups 0x20(%r13),%ymm0
 123f475:	c4 c1 7c 10 4d 40    	vmovups 0x40(%r13),%ymm1
 123f47b:	c5 fc 11 85 f0 fa ff 	vmovups %ymm0,-0x510(%rbp)
 123f482:	ff 
 123f483:	c5 fc 11 8d 10 fb ff 	vmovups %ymm1,-0x4f0(%rbp)
 123f48a:	ff 
 123f48b:	c4 c1 7c 10 45 00    	vmovups 0x0(%r13),%ymm0
 123f491:	49 8b 45 60          	mov    0x60(%r13),%rax
 123f495:	48 89 85 30 fb ff ff 	mov    %rax,-0x4d0(%rbp)
 123f49c:	c5 fc 11 85 d0 fa ff 	vmovups %ymm0,-0x530(%rbp)
 123f4a3:	ff 
 123f4a4:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 123f4ab:	0f b6 00             	movzbl (%rax),%eax
 123f4ae:	88 85 2c ff ff ff    	mov    %al,-0xd4(%rbp)
 123f4b4:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 123f4b9:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 123f4bf:	c5 fc 11 85 40 fb ff 	vmovups %ymm0,-0x4c0(%rbp)
 123f4c6:	ff 
 123f4c7:	c5 fc 11 8d 60 fb ff 	vmovups %ymm1,-0x4a0(%rbp)
 123f4ce:	ff 
 123f4cf:	c4 c1 7c 10 47 40    	vmovups 0x40(%r15),%ymm0
 123f4d5:	c5 fc 11 85 80 fb ff 	vmovups %ymm0,-0x480(%rbp)
 123f4dc:	ff 
 123f4dd:	49 8b 47 60          	mov    0x60(%r15),%rax
 123f4e1:	48 89 85 a0 fb ff ff 	mov    %rax,-0x460(%rbp)
 123f4e8:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 123f4ef:	0f b6 00             	movzbl (%rax),%eax
 123f4f2:	88 85 2d ff ff ff    	mov    %al,-0xd3(%rbp)
 123f4f8:	49 8b 44 24 60       	mov    0x60(%r12),%rax
 123f4fd:	48 89 85 10 fc ff ff 	mov    %rax,-0x3f0(%rbp)
 123f504:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 123f50a:	c4 c1 7c 10 4c 24 40 	vmovups 0x40(%r12),%ymm1
 123f511:	c5 fc 11 8d f0 fb ff 	vmovups %ymm1,-0x410(%rbp)
 123f518:	ff 
 123f519:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 123f520:	c5 fc 11 8d d0 fb ff 	vmovups %ymm1,-0x430(%rbp)
 123f527:	ff 
 123f528:	c5 fc 11 85 b0 fb ff 	vmovups %ymm0,-0x450(%rbp)
 123f52f:	ff 
 123f530:	41 0f b6 03          	movzbl (%r11),%eax
 123f534:	88 85 2e ff ff ff    	mov    %al,-0xd2(%rbp)
 123f53a:	4c 8b 5d 80          	mov    -0x80(%rbp),%r11
 123f53e:	49 8b 43 60          	mov    0x60(%r11),%rax
 123f542:	48 89 85 80 fc ff ff 	mov    %rax,-0x380(%rbp)
 123f549:	c4 c1 7c 10 03       	vmovups (%r11),%ymm0
 123f54e:	c4 c1 7c 10 4b 40    	vmovups 0x40(%r11),%ymm1
 123f554:	c5 fc 11 8d 60 fc ff 	vmovups %ymm1,-0x3a0(%rbp)
 123f55b:	ff 
 123f55c:	c4 c1 7c 10 4b 20    	vmovups 0x20(%r11),%ymm1
 123f562:	c5 fc 11 8d 40 fc ff 	vmovups %ymm1,-0x3c0(%rbp)
 123f569:	ff 
 123f56a:	c5 fc 11 85 20 fc ff 	vmovups %ymm0,-0x3e0(%rbp)
 123f571:	ff 
 123f572:	40 88 b5 88 fd ff ff 	mov    %sil,-0x278(%rbp)
 123f579:	40 84 f6             	test   %sil,%sil
 123f57c:	88 4d c7             	mov    %cl,-0x39(%rbp)
 123f57f:	74 44                	je     123f5c5 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3a5>
 123f581:	49 8b 42 60          	mov    0x60(%r10),%rax
 123f585:	48 89 85 40 dd ff ff 	mov    %rax,-0x22c0(%rbp)
 123f58c:	c4 c1 7c 10 02       	vmovups (%r10),%ymm0
 123f591:	c4 c1 7c 10 4a 20    	vmovups 0x20(%r10),%ymm1
 123f597:	c4 c1 7c 10 52 40    	vmovups 0x40(%r10),%ymm2
 123f59d:	c5 fc 11 95 20 dd ff 	vmovups %ymm2,-0x22e0(%rbp)
 123f5a4:	ff 
 123f5a5:	c5 fc 11 8d 00 dd ff 	vmovups %ymm1,-0x2300(%rbp)
 123f5ac:	ff 
 123f5ad:	c5 fc 11 85 e0 dc ff 	vmovups %ymm0,-0x2320(%rbp)
 123f5b4:	ff 
 123f5b5:	c6 85 48 dd ff ff 01 	movb   $0x1,-0x22b8(%rbp)
 123f5bc:	48 8d 85 e0 dc ff ff 	lea    -0x2320(%rbp),%rax
 123f5c3:	eb 51                	jmp    123f616 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3f6>
 123f5c5:	48 8b 43 60          	mov    0x60(%rbx),%rax
 123f5c9:	48 89 85 e0 ea ff ff 	mov    %rax,-0x1520(%rbp)
 123f5d0:	c5 fc 10 03          	vmovups (%rbx),%ymm0
 123f5d4:	c5 fc 10 4b 20       	vmovups 0x20(%rbx),%ymm1
 123f5d9:	c5 fc 10 53 40       	vmovups 0x40(%rbx),%ymm2
 123f5de:	c5 fc 11 95 c0 ea ff 	vmovups %ymm2,-0x1540(%rbp)
 123f5e5:	ff 
 123f5e6:	c5 fc 11 8d a0 ea ff 	vmovups %ymm1,-0x1560(%rbp)
 123f5ed:	ff 
 123f5ee:	c5 fc 11 85 80 ea ff 	vmovups %ymm0,-0x1580(%rbp)
 123f5f5:	ff 
 123f5f6:	88 8d e8 ea ff ff    	mov    %cl,-0x1518(%rbp)
 123f5fc:	41 8b 00             	mov    (%r8),%eax
 123f5ff:	41 8b 48 03          	mov    0x3(%r8),%ecx
 123f603:	89 85 e9 ea ff ff    	mov    %eax,-0x1517(%rbp)
 123f609:	89 8d ec ea ff ff    	mov    %ecx,-0x1514(%rbp)
 123f60f:	48 8d 85 80 ea ff ff 	lea    -0x1580(%rbp),%rax
 123f616:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 123f61a:	4c 8b ad 78 ff ff ff 	mov    -0x88(%rbp),%r13
 123f621:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 123f625:	4c 8b 65 88          	mov    -0x78(%rbp),%r12
 123f629:	44 0f b6 3f          	movzbl (%rdi),%r15d
 123f62d:	b8 68 f3 08 01       	mov    $0x108f368,%eax
 123f632:	41 f6 c1 01          	test   $0x1,%r9b
 123f636:	74 57                	je     123f68f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x46f>
 123f638:	48 8d bd e0 e3 ff ff 	lea    -0x1c20(%rbp),%rdi
 123f63f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123f643:	4c 89 e1             	mov    %r12,%rcx
 123f646:	4d 89 f0             	mov    %r14,%r8
 123f649:	4d 89 e9             	mov    %r13,%r9
 123f64c:	c5 f8 77             	vzeroupper 
 123f64f:	e8 5c c9 01 00       	call   125bfb0 <br.chooseAdaptiveLiteralSplitAlloc>
 123f654:	0f b7 85 18 e4 ff ff 	movzwl -0x1be8(%rbp),%eax
 123f65b:	66 85 c0             	test   %ax,%ax
 123f65e:	0f 85 49 39 00 00    	jne    1242fad <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3d8d>
 123f664:	c5 fc 10 85 e0 e3 ff 	vmovups -0x1c20(%rbp),%ymm0
 123f66b:	ff 
 123f66c:	c5 fc 10 8d f8 e3 ff 	vmovups -0x1c08(%rbp),%ymm1
 123f673:	ff 
 123f674:	c5 fc 11 8d b8 dc ff 	vmovups %ymm1,-0x2348(%rbp)
 123f67b:	ff 
 123f67c:	c5 fc 11 85 a0 dc ff 	vmovups %ymm0,-0x2360(%rbp)
 123f683:	ff 
 123f684:	48 8d 85 a0 dc ff ff 	lea    -0x2360(%rbp),%rax
 123f68b:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 123f68f:	c5 fc 10 40 18       	vmovups 0x18(%rax),%ymm0
 123f694:	c5 fc 11 85 48 ff ff 	vmovups %ymm0,-0xb8(%rbp)
 123f69b:	ff 
 123f69c:	c5 fc 10 00          	vmovups (%rax),%ymm0
 123f6a0:	c5 fc 11 85 30 ff ff 	vmovups %ymm0,-0xd0(%rbp)
 123f6a7:	ff 
 123f6a8:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 123f6af:	b9 d0 f3 08 01       	mov    $0x108f3d0,%ecx
 123f6b4:	0f 84 93 00 00 00    	je     123f74d <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52d>
 123f6ba:	f6 85 2a ff ff ff 01 	testb  $0x1,-0xd6(%rbp)
 123f6c1:	0f 84 86 00 00 00    	je     123f74d <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52d>
 123f6c7:	c5 fc 10 00          	vmovups (%rax),%ymm0
 123f6cb:	c5 fc 10 48 10       	vmovups 0x10(%rax),%ymm1
 123f6d0:	c5 fc 11 8d d0 e9 ff 	vmovups %ymm1,-0x1630(%rbp)
 123f6d7:	ff 
 123f6d8:	c5 fc 11 85 c0 e9 ff 	vmovups %ymm0,-0x1640(%rbp)
 123f6df:	ff 
 123f6e0:	48 8d 85 c0 e9 ff ff 	lea    -0x1640(%rbp),%rax
 123f6e7:	48 89 04 24          	mov    %rax,(%rsp)
 123f6eb:	48 8d bd e8 d3 ff ff 	lea    -0x2c18(%rbp),%rdi
 123f6f2:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123f6f6:	4c 89 e1             	mov    %r12,%rcx
 123f6f9:	4d 89 f0             	mov    %r14,%r8
 123f6fc:	4d 89 e9             	mov    %r13,%r9
 123f6ff:	c5 f8 77             	vzeroupper 
 123f702:	e8 59 9e 01 00       	call   1259560 <br.encoder.literal_joint_context_split.chooseAlloc>
 123f707:	0f b7 85 48 d4 ff ff 	movzwl -0x2bb8(%rbp),%eax
 123f70e:	85 c0                	test   %eax,%eax
 123f710:	0f 85 a4 38 00 00    	jne    1242fba <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3d9a>
 123f716:	c5 fc 10 85 e8 d3 ff 	vmovups -0x2c18(%rbp),%ymm0
 123f71d:	ff 
 123f71e:	c5 fc 10 8d 28 d4 ff 	vmovups -0x2bd8(%rbp),%ymm1
 123f725:	ff 
 123f726:	c5 fc 11 8d 40 c9 ff 	vmovups %ymm1,-0x36c0(%rbp)
 123f72d:	ff 
 123f72e:	c5 fc 10 8d 08 d4 ff 	vmovups -0x2bf8(%rbp),%ymm1
 123f735:	ff 
 123f736:	c5 fc 11 8d 20 c9 ff 	vmovups %ymm1,-0x36e0(%rbp)
 123f73d:	ff 
 123f73e:	c5 fc 11 85 00 c9 ff 	vmovups %ymm0,-0x3700(%rbp)
 123f745:	ff 
 123f746:	48 8d 8d 00 c9 ff ff 	lea    -0x3700(%rbp),%rcx
 123f74d:	c5 fc 10 41 20       	vmovups 0x20(%rcx),%ymm0
 123f752:	c5 fc 10 49 40       	vmovups 0x40(%rcx),%ymm1
 123f757:	c5 fc 11 8d 70 fe ff 	vmovups %ymm1,-0x190(%rbp)
 123f75e:	ff 
 123f75f:	c5 fc 11 85 50 fe ff 	vmovups %ymm0,-0x1b0(%rbp)
 123f766:	ff 
 123f767:	c5 fc 10 01          	vmovups (%rcx),%ymm0
 123f76b:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 123f772:	ff 
 123f773:	c5 fc 10 85 f0 e9 ff 	vmovups -0x1610(%rbp),%ymm0
 123f77a:	ff 
 123f77b:	c5 fc 11 85 a0 fc ff 	vmovups %ymm0,-0x360(%rbp)
 123f782:	ff 
 123f783:	0f b6 45 9e          	movzbl -0x62(%rbp),%eax
 123f787:	24 01                	and    $0x1,%al
 123f789:	88 85 c0 fc ff ff    	mov    %al,-0x340(%rbp)
 123f78f:	0f b6 45 9f          	movzbl -0x61(%rbp),%eax
 123f793:	24 1f                	and    $0x1f,%al
 123f795:	88 85 c1 fc ff ff    	mov    %al,-0x33f(%rbp)
 123f79b:	c5 f8 28 85 70 fd ff 	vmovaps -0x290(%rbp),%xmm0
 123f7a2:	ff 
 123f7a3:	c5 f8 29 85 90 fc ff 	vmovaps %xmm0,-0x370(%rbp)
 123f7aa:	ff 
 123f7ab:	48 8d 85 90 fc ff ff 	lea    -0x370(%rbp),%rax
 123f7b2:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 123f7b7:	0f b6 45 9d          	movzbl -0x63(%rbp),%eax
 123f7bb:	89 44 24 10          	mov    %eax,0x10(%rsp)
 123f7bf:	0f b6 45 9b          	movzbl -0x65(%rbp),%eax
 123f7c3:	89 44 24 08          	mov    %eax,0x8(%rsp)
 123f7c7:	0f b6 45 9a          	movzbl -0x66(%rbp),%eax
 123f7cb:	89 04 24             	mov    %eax,(%rsp)
 123f7ce:	44 0f b6 45 9c       	movzbl -0x64(%rbp),%r8d
 123f7d3:	44 0f b6 4d c6       	movzbl -0x3a(%rbp),%r9d
 123f7d8:	48 8d bd 68 c2 ff ff 	lea    -0x3d98(%rbp),%rdi
 123f7df:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123f7e3:	4c 89 f2             	mov    %r14,%rdx
 123f7e6:	4c 89 e9             	mov    %r13,%rcx
 123f7e9:	c5 f8 77             	vzeroupper 
 123f7ec:	e8 9f 5c 00 00       	call   1245490 <br.chooseCommandAndDistanceSplitsAlloc>
 123f7f1:	0f b7 9d f8 c8 ff ff 	movzwl -0x3708(%rbp),%ebx
 123f7f8:	66 85 db             	test   %bx,%bx
 123f7fb:	0f 85 27 37 00 00    	jne    1242f28 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3d08>
 123f801:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 123f808:	48 8d b5 68 c2 ff ff 	lea    -0x3d98(%rbp),%rsi
 123f80f:	ba 90 06 00 00       	mov    $0x690,%edx
 123f814:	e8 47 ff 09 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123f819:	c5 fc 10 85 b0 c5 ff 	vmovups -0x3a50(%rbp),%ymm0
 123f820:	ff 
 123f821:	c5 fc 10 8d d0 c5 ff 	vmovups -0x3a30(%rbp),%ymm1
 123f828:	ff 
 123f829:	c5 fc 10 95 f0 c5 ff 	vmovups -0x3a10(%rbp),%ymm2
 123f830:	ff 
 123f831:	c5 fc 11 85 50 f7 ff 	vmovups %ymm0,-0x8b0(%rbp)
 123f838:	ff 
 123f839:	c5 fc 11 8d 70 f7 ff 	vmovups %ymm1,-0x890(%rbp)
 123f840:	ff 
 123f841:	c5 fc 11 95 90 f7 ff 	vmovups %ymm2,-0x870(%rbp)
 123f848:	ff 
 123f849:	48 8b 85 10 c6 ff ff 	mov    -0x39f0(%rbp),%rax
 123f850:	48 89 85 b0 f7 ff ff 	mov    %rax,-0x850(%rbp)
 123f857:	0f b6 9d 00 e1 ff ff 	movzbl -0x1f00(%rbp),%ebx
 123f85e:	0f b6 95 70 e1 ff ff 	movzbl -0x1e90(%rbp),%edx
 123f865:	c5 fc 10 85 90 c6 ff 	vmovups -0x3970(%rbp),%ymm0
 123f86c:	ff 
 123f86d:	c5 fc 11 85 c0 f7 ff 	vmovups %ymm0,-0x840(%rbp)
 123f874:	ff 
 123f875:	c5 fc 10 85 b0 c6 ff 	vmovups -0x3950(%rbp),%ymm0
 123f87c:	ff 
 123f87d:	c5 fc 11 85 e0 f7 ff 	vmovups %ymm0,-0x820(%rbp)
 123f884:	ff 
 123f885:	c5 fc 10 85 d0 c6 ff 	vmovups -0x3930(%rbp),%ymm0
 123f88c:	ff 
 123f88d:	c5 fc 11 85 00 f8 ff 	vmovups %ymm0,-0x800(%rbp)
 123f894:	ff 
 123f895:	48 8b 85 f0 c6 ff ff 	mov    -0x3910(%rbp),%rax
 123f89c:	48 89 85 20 f8 ff ff 	mov    %rax,-0x7e0(%rbp)
 123f8a3:	44 0f b6 9d e0 e1 ff 	movzbl -0x1e20(%rbp),%r11d
 123f8aa:	ff 
 123f8ab:	44 0f b6 95 50 e2 ff 	movzbl -0x1db0(%rbp),%r10d
 123f8b2:	ff 
 123f8b3:	c5 fc 10 85 00 c7 ff 	vmovups -0x3900(%rbp),%ymm0
 123f8ba:	ff 
 123f8bb:	c5 fc 10 8d 20 c7 ff 	vmovups -0x38e0(%rbp),%ymm1
 123f8c2:	ff 
 123f8c3:	c5 fc 10 95 40 c7 ff 	vmovups -0x38c0(%rbp),%ymm2
 123f8ca:	ff 
 123f8cb:	c5 fc 11 85 30 f8 ff 	vmovups %ymm0,-0x7d0(%rbp)
 123f8d2:	ff 
 123f8d3:	c5 fc 11 8d 50 f8 ff 	vmovups %ymm1,-0x7b0(%rbp)
 123f8da:	ff 
 123f8db:	c5 fc 11 95 70 f8 ff 	vmovups %ymm2,-0x790(%rbp)
 123f8e2:	ff 
 123f8e3:	48 8b 85 60 c7 ff ff 	mov    -0x38a0(%rbp),%rax
 123f8ea:	48 89 85 90 f8 ff ff 	mov    %rax,-0x770(%rbp)
 123f8f1:	c5 fc 10 85 70 c7 ff 	vmovups -0x3890(%rbp),%ymm0
 123f8f8:	ff 
 123f8f9:	c5 fc 11 85 a0 f8 ff 	vmovups %ymm0,-0x760(%rbp)
 123f900:	ff 
 123f901:	c5 fc 10 85 90 c7 ff 	vmovups -0x3870(%rbp),%ymm0
 123f908:	ff 
 123f909:	c5 fc 11 85 c0 f8 ff 	vmovups %ymm0,-0x740(%rbp)
 123f910:	ff 
 123f911:	c5 fc 10 85 b0 c7 ff 	vmovups -0x3850(%rbp),%ymm0
 123f918:	ff 
 123f919:	c5 fc 11 85 e0 f8 ff 	vmovups %ymm0,-0x720(%rbp)
 123f920:	ff 
 123f921:	48 8b 85 d0 c7 ff ff 	mov    -0x3830(%rbp),%rax
 123f928:	48 89 85 00 f9 ff ff 	mov    %rax,-0x700(%rbp)
 123f92f:	44 0f b6 8d c0 e2 ff 	movzbl -0x1d40(%rbp),%r9d
 123f936:	ff 
 123f937:	44 0f b6 85 30 e3 ff 	movzbl -0x1cd0(%rbp),%r8d
 123f93e:	ff 
 123f93f:	48 8b 85 40 c8 ff ff 	mov    -0x37c0(%rbp),%rax
 123f946:	48 89 85 70 f9 ff ff 	mov    %rax,-0x690(%rbp)
 123f94d:	c5 fc 10 85 e0 c7 ff 	vmovups -0x3820(%rbp),%ymm0
 123f954:	ff 
 123f955:	c5 fc 10 8d 00 c8 ff 	vmovups -0x3800(%rbp),%ymm1
 123f95c:	ff 
 123f95d:	c5 fc 10 95 20 c8 ff 	vmovups -0x37e0(%rbp),%ymm2
 123f964:	ff 
 123f965:	c5 fc 11 95 50 f9 ff 	vmovups %ymm2,-0x6b0(%rbp)
 123f96c:	ff 
 123f96d:	c5 fc 11 8d 30 f9 ff 	vmovups %ymm1,-0x6d0(%rbp)
 123f974:	ff 
 123f975:	c5 fc 11 85 10 f9 ff 	vmovups %ymm0,-0x6f0(%rbp)
 123f97c:	ff 
 123f97d:	48 8b 85 b0 c8 ff ff 	mov    -0x3750(%rbp),%rax
 123f984:	48 89 85 e0 f9 ff ff 	mov    %rax,-0x620(%rbp)
 123f98b:	c5 fc 10 85 90 c8 ff 	vmovups -0x3770(%rbp),%ymm0
 123f992:	ff 
 123f993:	c5 fc 11 85 c0 f9 ff 	vmovups %ymm0,-0x640(%rbp)
 123f99a:	ff 
 123f99b:	c5 fc 10 85 70 c8 ff 	vmovups -0x3790(%rbp),%ymm0
 123f9a2:	ff 
 123f9a3:	c5 fc 11 85 a0 f9 ff 	vmovups %ymm0,-0x660(%rbp)
 123f9aa:	ff 
 123f9ab:	c5 fc 10 85 50 c8 ff 	vmovups -0x37b0(%rbp),%ymm0
 123f9b2:	ff 
 123f9b3:	c5 fc 11 85 80 f9 ff 	vmovups %ymm0,-0x680(%rbp)
 123f9ba:	ff 
 123f9bb:	84 d2                	test   %dl,%dl
 123f9bd:	0f 84 be 00 00 00    	je     123fa81 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x861>
 123f9c3:	48 8b 85 80 c6 ff ff 	mov    -0x3980(%rbp),%rax
 123f9ca:	48 89 85 90 dc ff ff 	mov    %rax,-0x2370(%rbp)
 123f9d1:	c5 fc 10 85 40 c6 ff 	vmovups -0x39c0(%rbp),%ymm0
 123f9d8:	ff 
 123f9d9:	c5 fc 10 8d 60 c6 ff 	vmovups -0x39a0(%rbp),%ymm1
 123f9e0:	ff 
 123f9e1:	c5 fc 11 8d 70 dc ff 	vmovups %ymm1,-0x2390(%rbp)
 123f9e8:	ff 
 123f9e9:	c5 fc 11 85 50 dc ff 	vmovups %ymm0,-0x23b0(%rbp)
 123f9f0:	ff 
 123f9f1:	c5 fc 10 85 20 c6 ff 	vmovups -0x39e0(%rbp),%ymm0
 123f9f8:	ff 
 123f9f9:	c5 fc 11 85 30 dc ff 	vmovups %ymm0,-0x23d0(%rbp)
 123fa00:	ff 
 123fa01:	c6 85 98 dc ff ff 01 	movb   $0x1,-0x2368(%rbp)
 123fa08:	48 8d 85 30 dc ff ff 	lea    -0x23d0(%rbp),%rax
 123fa0f:	48 89 85 68 ff ff ff 	mov    %rax,-0x98(%rbp)
 123fa16:	b0 01                	mov    $0x1,%al
 123fa18:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 123fa1c:	80 bd 28 de ff ff 00 	cmpb   $0x0,-0x21d8(%rbp)
 123fa23:	44 88 bd 2f ff ff ff 	mov    %r15b,-0xd1(%rbp)
 123fa2a:	0f 84 d2 00 00 00    	je     123fb02 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x8e2>
 123fa30:	48 8b 8d 38 c3 ff ff 	mov    -0x3cc8(%rbp),%rcx
 123fa37:	48 89 8d 20 dc ff ff 	mov    %rcx,-0x23e0(%rbp)
 123fa3e:	c5 fc 10 85 d8 c2 ff 	vmovups -0x3d28(%rbp),%ymm0
 123fa45:	ff 
 123fa46:	c5 fc 10 8d f8 c2 ff 	vmovups -0x3d08(%rbp),%ymm1
 123fa4d:	ff 
 123fa4e:	c5 fc 10 95 18 c3 ff 	vmovups -0x3ce8(%rbp),%ymm2
 123fa55:	ff 
 123fa56:	c5 fc 11 95 00 dc ff 	vmovups %ymm2,-0x2400(%rbp)
 123fa5d:	ff 
 123fa5e:	c5 fc 11 8d e0 db ff 	vmovups %ymm1,-0x2420(%rbp)
 123fa65:	ff 
 123fa66:	c5 fc 11 85 c0 db ff 	vmovups %ymm0,-0x2440(%rbp)
 123fa6d:	ff 
 123fa6e:	c6 85 28 dc ff ff 01 	movb   $0x1,-0x23d8(%rbp)
 123fa75:	48 8d 8d c0 db ff ff 	lea    -0x2440(%rbp),%rcx
 123fa7c:	e9 c8 00 00 00       	jmp    123fb49 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x929>
 123fa81:	48 8d 85 b0 c5 ff ff 	lea    -0x3a50(%rbp),%rax
 123fa88:	48 8b 48 60          	mov    0x60(%rax),%rcx
 123fa8c:	48 89 8d 70 ea ff ff 	mov    %rcx,-0x1590(%rbp)
 123fa93:	c5 fc 10 00          	vmovups (%rax),%ymm0
 123fa97:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 123fa9c:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 123faa1:	c5 fc 11 95 50 ea ff 	vmovups %ymm2,-0x15b0(%rbp)
 123faa8:	ff 
 123faa9:	c5 fc 11 8d 30 ea ff 	vmovups %ymm1,-0x15d0(%rbp)
 123fab0:	ff 
 123fab1:	c5 fc 11 85 10 ea ff 	vmovups %ymm0,-0x15f0(%rbp)
 123fab8:	ff 
 123fab9:	88 9d 78 ea ff ff    	mov    %bl,-0x1588(%rbp)
 123fabf:	8b 85 19 c6 ff ff    	mov    -0x39e7(%rbp),%eax
 123fac5:	8b 8d 1c c6 ff ff    	mov    -0x39e4(%rbp),%ecx
 123facb:	89 85 79 ea ff ff    	mov    %eax,-0x1587(%rbp)
 123fad1:	89 8d 7c ea ff ff    	mov    %ecx,-0x1584(%rbp)
 123fad7:	84 db                	test   %bl,%bl
 123fad9:	0f 95 c0             	setne  %al
 123fadc:	48 8d 8d 10 ea ff ff 	lea    -0x15f0(%rbp),%rcx
 123fae3:	48 89 8d 68 ff ff ff 	mov    %rcx,-0x98(%rbp)
 123faea:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 123faee:	80 bd 28 de ff ff 00 	cmpb   $0x0,-0x21d8(%rbp)
 123faf5:	44 88 bd 2f ff ff ff 	mov    %r15b,-0xd1(%rbp)
 123fafc:	0f 85 2e ff ff ff    	jne    123fa30 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x810>
 123fb02:	c5 fc 10 85 68 c2 ff 	vmovups -0x3d98(%rbp),%ymm0
 123fb09:	ff 
 123fb0a:	c5 fc 10 8d a8 c2 ff 	vmovups -0x3d58(%rbp),%ymm1
 123fb11:	ff 
 123fb12:	c5 fc 10 95 b8 c2 ff 	vmovups -0x3d48(%rbp),%ymm2
 123fb19:	ff 
 123fb1a:	c5 fc 11 95 b0 c9 ff 	vmovups %ymm2,-0x3650(%rbp)
 123fb21:	ff 
 123fb22:	c5 fc 11 8d a0 c9 ff 	vmovups %ymm1,-0x3660(%rbp)
 123fb29:	ff 
 123fb2a:	c5 fc 10 8d 88 c2 ff 	vmovups -0x3d78(%rbp),%ymm1
 123fb31:	ff 
 123fb32:	c5 fc 11 8d 80 c9 ff 	vmovups %ymm1,-0x3680(%rbp)
 123fb39:	ff 
 123fb3a:	c5 fc 11 85 60 c9 ff 	vmovups %ymm0,-0x36a0(%rbp)
 123fb41:	ff 
 123fb42:	48 8d 8d 60 c9 ff ff 	lea    -0x36a0(%rbp),%rcx
 123fb49:	48 89 8d 70 ff ff ff 	mov    %rcx,-0x90(%rbp)
 123fb50:	41 b7 01             	mov    $0x1,%r15b
 123fb53:	48 8b 4d 80          	mov    -0x80(%rbp),%rcx
 123fb57:	80 79 68 00          	cmpb   $0x0,0x68(%rcx)
 123fb5b:	75 12                	jne    123fb6f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x94f>
 123fb5d:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 123fb64:	80 79 68 00          	cmpb   $0x0,0x68(%rcx)
 123fb68:	41 0f 95 c7          	setne  %r15b
 123fb6c:	41 08 c7             	or     %al,%r15b
 123fb6f:	0f b6 bd a0 e3 ff ff 	movzbl -0x1c60(%rbp),%edi
 123fb76:	0f b6 8d 60 ff ff ff 	movzbl -0xa0(%rbp),%ecx
 123fb7d:	0f b6 85 90 e0 ff ff 	movzbl -0x1f70(%rbp),%eax
 123fb84:	41 f6 c7 01          	test   $0x1,%r15b
 123fb88:	75 47                	jne    123fbd1 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x9b1>
 123fb8a:	84 c9                	test   %cl,%cl
 123fb8c:	75 43                	jne    123fbd1 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x9b1>
 123fb8e:	84 c0                	test   %al,%al
 123fb90:	75 3f                	jne    123fbd1 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x9b1>
 123fb92:	80 bd d8 e3 ff ff 00 	cmpb   $0x0,-0x1c28(%rbp)
 123fb99:	75 36                	jne    123fbd1 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x9b1>
 123fb9b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 123fb9f:	c5 fc 11 85 78 e0 ff 	vmovups %ymm0,-0x1f88(%rbp)
 123fba6:	ff 
 123fba7:	c5 fc 11 85 60 e0 ff 	vmovups %ymm0,-0x1fa0(%rbp)
 123fbae:	ff 
 123fbaf:	c5 fc 11 85 a8 e3 ff 	vmovups %ymm0,-0x1c58(%rbp)
 123fbb6:	ff 
 123fbb7:	c5 fc 11 85 c0 e3 ff 	vmovups %ymm0,-0x1c40(%rbp)
 123fbbe:	ff 
 123fbbf:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 123fbc6:	0f 85 33 2f 00 00    	jne    1242aff <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x38df>
 123fbcc:	e9 ef 2f 00 00       	jmp    1242bc0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x39a0>
 123fbd1:	88 95 70 fd ff ff    	mov    %dl,-0x290(%rbp)
 123fbd7:	48 8b 55 10          	mov    0x10(%rbp),%rdx
 123fbdb:	c5 fc 10 42 70       	vmovups 0x70(%rdx),%ymm0
 123fbe0:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 123fbe7:	ff 
 123fbe8:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 123fbec:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 123fbf1:	c5 fc 10 52 40       	vmovups 0x40(%rdx),%ymm2
 123fbf6:	c5 fc 10 5a 60       	vmovups 0x60(%rdx),%ymm3
 123fbfb:	c5 fc 11 9d f0 fe ff 	vmovups %ymm3,-0x110(%rbp)
 123fc02:	ff 
 123fc03:	c5 fc 11 95 d0 fe ff 	vmovups %ymm2,-0x130(%rbp)
 123fc0a:	ff 
 123fc0b:	c5 fc 11 8d b0 fe ff 	vmovups %ymm1,-0x150(%rbp)
 123fc12:	ff 
 123fc13:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 123fc1a:	ff 
 123fc1b:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 123fc1f:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 123fc24:	c5 fc 10 52 40       	vmovups 0x40(%rdx),%ymm2
 123fc29:	c5 fc 10 5a 60       	vmovups 0x60(%rdx),%ymm3
 123fc2e:	c5 fc 11 85 d0 fc ff 	vmovups %ymm0,-0x330(%rbp)
 123fc35:	ff 
 123fc36:	c5 fc 11 8d f0 fc ff 	vmovups %ymm1,-0x310(%rbp)
 123fc3d:	ff 
 123fc3e:	c5 fc 11 95 10 fd ff 	vmovups %ymm2,-0x2f0(%rbp)
 123fc45:	ff 
 123fc46:	c5 fc 11 9d 30 fd ff 	vmovups %ymm3,-0x2d0(%rbp)
 123fc4d:	ff 
 123fc4e:	c5 fc 10 42 70       	vmovups 0x70(%rdx),%ymm0
 123fc53:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 123fc5a:	ff 
 123fc5b:	41 f6 c7 01          	test   $0x1,%r15b
 123fc5f:	44 88 7d c6          	mov    %r15b,-0x3a(%rbp)
 123fc63:	40 88 7d 9f          	mov    %dil,-0x61(%rbp)
 123fc67:	44 88 45 9e          	mov    %r8b,-0x62(%rbp)
 123fc6b:	44 88 4d 9d          	mov    %r9b,-0x63(%rbp)
 123fc6f:	44 88 55 9c          	mov    %r10b,-0x64(%rbp)
 123fc73:	44 88 5d 9b          	mov    %r11b,-0x65(%rbp)
 123fc77:	88 5d 9a             	mov    %bl,-0x66(%rbp)
 123fc7a:	0f 84 5c 01 00 00    	je     123fddc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0xbbc>
 123fc80:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 123fc87:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 123fc8c:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 123fc93:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 123fc98:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 123fc9c:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 123fca2:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 123fca6:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 123fcab:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 123fcb0:	48 8b 45 18          	mov    0x18(%rbp),%rax
 123fcb4:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 123fcb9:	48 8d 85 d0 fc ff ff 	lea    -0x330(%rbp),%rax
 123fcc0:	48 89 04 24          	mov    %rax,(%rsp)
 123fcc4:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 123fccb:	00 00 
 123fccd:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 123fcd4:	00 00 
 123fcd6:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 123fcda:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123fcde:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 123fce2:	4c 89 e1             	mov    %r12,%rcx
 123fce5:	4d 89 f0             	mov    %r14,%r8
 123fce8:	4d 89 e9             	mov    %r13,%r9
 123fceb:	c5 f8 77             	vzeroupper 
 123fcee:	e8 6d 4b 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 123fcf3:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 123fcf7:	66 85 db             	test   %bx,%bx
 123fcfa:	0f 84 1b 04 00 00    	je     124011b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0xefb>
 123fd00:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 123fd07:	ff 
 123fd08:	48 8b 45 10          	mov    0x10(%rbp),%rax
 123fd0c:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 123fd11:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 123fd18:	ff 
 123fd19:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 123fd20:	ff 
 123fd21:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 123fd28:	ff 
 123fd29:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 123fd30:	ff 
 123fd31:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 123fd36:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 123fd3b:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 123fd40:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 123fd44:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 123fd4b:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123fd4f:	c5 f8 77             	vzeroupper 
 123fd52:	e8 29 55 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 123fd57:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 123fd5e:	74 43                	je     123fda3 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0xb83>
 123fd60:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 123fd67:	ff 
 123fd68:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 123fd6f:	ff 
 123fd70:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 123fd77:	ff 
 123fd78:	c5 fc 11 95 68 d3 ff 	vmovups %ymm2,-0x2c98(%rbp)
 123fd7f:	ff 
 123fd80:	c5 fc 11 8d 50 d3 ff 	vmovups %ymm1,-0x2cb0(%rbp)
 123fd87:	ff 
 123fd88:	c5 fc 11 85 30 d3 ff 	vmovups %ymm0,-0x2cd0(%rbp)
 123fd8f:	ff 
 123fd90:	48 8d bd 30 d3 ff ff 	lea    -0x2cd0(%rbp),%rdi
 123fd97:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123fd9b:	c5 f8 77             	vzeroupper 
 123fd9e:	e8 0d 56 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 123fda3:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 123fdaa:	0f 84 2c 48 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 123fdb0:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 123fdb7:	ff 
 123fdb8:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 123fdbf:	ff 
 123fdc0:	c5 fc 11 8d e0 e8 ff 	vmovups %ymm1,-0x1720(%rbp)
 123fdc7:	ff 
 123fdc8:	c5 fc 11 85 d0 e8 ff 	vmovups %ymm0,-0x1730(%rbp)
 123fdcf:	ff 
 123fdd0:	48 8d bd d0 e8 ff ff 	lea    -0x1730(%rbp),%rdi
 123fdd7:	e9 f4 47 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 123fddc:	84 c9                	test   %cl,%cl
 123fdde:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 123fde2:	0f 84 5d 01 00 00    	je     123ff45 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0xd25>
 123fde8:	48 8d 85 30 ff ff ff 	lea    -0xd0(%rbp),%rax
 123fdef:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 123fdf4:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 123fdf9:	48 8b 45 18          	mov    0x18(%rbp),%rax
 123fdfd:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 123fe02:	48 8d 85 d0 fc ff ff 	lea    -0x330(%rbp),%rax
 123fe09:	48 89 04 24          	mov    %rax,(%rsp)
 123fe0d:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 123fe14:	00 00 
 123fe16:	48 c7 44 24 40 68 ae 	movq   $0x103ae68,0x40(%rsp)
 123fe1d:	03 01 
 123fe1f:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 123fe26:	00 00 
 123fe28:	48 c7 44 24 30 f8 ad 	movq   $0x103adf8,0x30(%rsp)
 123fe2f:	03 01 
 123fe31:	48 c7 44 24 28 00 00 	movq   $0x0,0x28(%rsp)
 123fe38:	00 00 
 123fe3a:	48 c7 44 24 18 88 ad 	movq   $0x103ad88,0x18(%rsp)
 123fe41:	03 01 
 123fe43:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 123fe47:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123fe4b:	4c 89 e1             	mov    %r12,%rcx
 123fe4e:	4d 89 f0             	mov    %r14,%r8
 123fe51:	4d 89 e9             	mov    %r13,%r9
 123fe54:	c5 f8 77             	vzeroupper 
 123fe57:	e8 04 4a 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 123fe5c:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 123fe60:	66 85 db             	test   %bx,%bx
 123fe63:	0f 84 b2 02 00 00    	je     124011b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0xefb>
 123fe69:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 123fe70:	ff 
 123fe71:	48 8b 45 10          	mov    0x10(%rbp),%rax
 123fe75:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 123fe7a:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 123fe81:	ff 
 123fe82:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 123fe89:	ff 
 123fe8a:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 123fe91:	ff 
 123fe92:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 123fe99:	ff 
 123fe9a:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 123fe9f:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 123fea4:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 123fea9:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 123fead:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 123feb4:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123feb8:	c5 f8 77             	vzeroupper 
 123febb:	e8 c0 53 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 123fec0:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 123fec7:	74 43                	je     123ff0c <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0xcec>
 123fec9:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 123fed0:	ff 
 123fed1:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 123fed8:	ff 
 123fed9:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 123fee0:	ff 
 123fee1:	c5 fc 11 95 08 d3 ff 	vmovups %ymm2,-0x2cf8(%rbp)
 123fee8:	ff 
 123fee9:	c5 fc 11 8d f0 d2 ff 	vmovups %ymm1,-0x2d10(%rbp)
 123fef0:	ff 
 123fef1:	c5 fc 11 85 d0 d2 ff 	vmovups %ymm0,-0x2d30(%rbp)
 123fef8:	ff 
 123fef9:	48 8d bd d0 d2 ff ff 	lea    -0x2d30(%rbp),%rdi
 123ff00:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123ff04:	c5 f8 77             	vzeroupper 
 123ff07:	e8 a4 54 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 123ff0c:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 123ff13:	0f 84 c3 46 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 123ff19:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 123ff20:	ff 
 123ff21:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 123ff28:	ff 
 123ff29:	c5 fc 11 8d b0 e8 ff 	vmovups %ymm1,-0x1750(%rbp)
 123ff30:	ff 
 123ff31:	c5 fc 11 85 a0 e8 ff 	vmovups %ymm0,-0x1760(%rbp)
 123ff38:	ff 
 123ff39:	48 8d bd a0 e8 ff ff 	lea    -0x1760(%rbp),%rdi
 123ff40:	e9 8b 46 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 123ff45:	84 c0                	test   %al,%al
 123ff47:	0f 84 55 01 00 00    	je     12400a2 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0xe82>
 123ff4d:	48 8d 85 60 e0 ff ff 	lea    -0x1fa0(%rbp),%rax
 123ff54:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 123ff59:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 123ff5d:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 123ff63:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 123ff68:	48 8b 45 18          	mov    0x18(%rbp),%rax
 123ff6c:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 123ff71:	48 8d 85 d0 fc ff ff 	lea    -0x330(%rbp),%rax
 123ff78:	48 89 04 24          	mov    %rax,(%rsp)
 123ff7c:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 123ff83:	00 00 
 123ff85:	48 c7 44 24 40 68 ae 	movq   $0x103ae68,0x40(%rsp)
 123ff8c:	03 01 
 123ff8e:	48 c7 44 24 30 f8 ad 	movq   $0x103adf8,0x30(%rsp)
 123ff95:	03 01 
 123ff97:	48 c7 44 24 18 88 ad 	movq   $0x103ad88,0x18(%rsp)
 123ff9e:	03 01 
 123ffa0:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 123ffa4:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123ffa8:	4c 89 e1             	mov    %r12,%rcx
 123ffab:	4d 89 f0             	mov    %r14,%r8
 123ffae:	4d 89 e9             	mov    %r13,%r9
 123ffb1:	c5 f8 77             	vzeroupper 
 123ffb4:	e8 a7 48 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 123ffb9:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 123ffbd:	66 85 db             	test   %bx,%bx
 123ffc0:	0f 84 55 01 00 00    	je     124011b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0xefb>
 123ffc6:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 123ffcd:	ff 
 123ffce:	48 8b 45 10          	mov    0x10(%rbp),%rax
 123ffd2:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 123ffd7:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 123ffde:	ff 
 123ffdf:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 123ffe6:	ff 
 123ffe7:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 123ffee:	ff 
 123ffef:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 123fff6:	ff 
 123fff7:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 123fffc:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1240001:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1240006:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 124000a:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1240011:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1240015:	c5 f8 77             	vzeroupper 
 1240018:	e8 63 52 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 124001d:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1240024:	74 43                	je     1240069 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0xe49>
 1240026:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 124002d:	ff 
 124002e:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1240035:	ff 
 1240036:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 124003d:	ff 
 124003e:	c5 fc 11 95 a8 d2 ff 	vmovups %ymm2,-0x2d58(%rbp)
 1240045:	ff 
 1240046:	c5 fc 11 8d 90 d2 ff 	vmovups %ymm1,-0x2d70(%rbp)
 124004d:	ff 
 124004e:	c5 fc 11 85 70 d2 ff 	vmovups %ymm0,-0x2d90(%rbp)
 1240055:	ff 
 1240056:	48 8d bd 70 d2 ff ff 	lea    -0x2d90(%rbp),%rdi
 124005d:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1240061:	c5 f8 77             	vzeroupper 
 1240064:	e8 47 53 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1240069:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1240070:	0f 84 66 45 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 1240076:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 124007d:	ff 
 124007e:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1240085:	ff 
 1240086:	c5 fc 11 8d 80 e8 ff 	vmovups %ymm1,-0x1780(%rbp)
 124008d:	ff 
 124008e:	c5 fc 11 85 70 e8 ff 	vmovups %ymm0,-0x1790(%rbp)
 1240095:	ff 
 1240096:	48 8d bd 70 e8 ff ff 	lea    -0x1790(%rbp),%rdi
 124009d:	e9 2e 45 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 12400a2:	48 8d 85 a8 e3 ff ff 	lea    -0x1c58(%rbp),%rax
 12400a9:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 12400ae:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 12400b2:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 12400b8:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 12400bd:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12400c1:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 12400c6:	48 8d 85 d0 fc ff ff 	lea    -0x330(%rbp),%rax
 12400cd:	48 89 04 24          	mov    %rax,(%rsp)
 12400d1:	48 c7 44 24 40 68 ae 	movq   $0x103ae68,0x40(%rsp)
 12400d8:	03 01 
 12400da:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 12400e1:	00 00 
 12400e3:	48 c7 44 24 30 f8 ad 	movq   $0x103adf8,0x30(%rsp)
 12400ea:	03 01 
 12400ec:	48 c7 44 24 18 88 ad 	movq   $0x103ad88,0x18(%rsp)
 12400f3:	03 01 
 12400f5:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 12400f9:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12400fd:	4c 89 e1             	mov    %r12,%rcx
 1240100:	4d 89 f0             	mov    %r14,%r8
 1240103:	4d 89 e9             	mov    %r13,%r9
 1240106:	c5 f8 77             	vzeroupper 
 1240109:	e8 52 47 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 124010e:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 1240112:	66 85 db             	test   %bx,%bx
 1240115:	0f 85 80 45 00 00    	jne    124469b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x547b>
 124011b:	4c 8b 7d a0          	mov    -0x60(%rbp),%r15
 124011f:	4c 8b 75 a8          	mov    -0x58(%rbp),%r14
 1240123:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1240127:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 124012b:	0f b6 4d c7          	movzbl -0x39(%rbp),%ecx
 124012f:	80 bd 88 fd ff ff 00 	cmpb   $0x0,-0x278(%rbp)
 1240136:	0f 94 c0             	sete   %al
 1240139:	c5 fc 10 85 40 fd ff 	vmovups -0x2c0(%rbp),%ymm0
 1240140:	ff 
 1240141:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1240148:	ff 
 1240149:	c5 fc 10 85 f0 fc ff 	vmovups -0x310(%rbp),%ymm0
 1240150:	ff 
 1240151:	c5 fc 10 8d 10 fd ff 	vmovups -0x2f0(%rbp),%ymm1
 1240158:	ff 
 1240159:	c5 fc 10 95 30 fd ff 	vmovups -0x2d0(%rbp),%ymm2
 1240160:	ff 
 1240161:	c5 fc 11 95 f0 fd ff 	vmovups %ymm2,-0x210(%rbp)
 1240168:	ff 
 1240169:	c5 fc 11 8d d0 fd ff 	vmovups %ymm1,-0x230(%rbp)
 1240170:	ff 
 1240171:	c5 fc 11 85 b0 fd ff 	vmovups %ymm0,-0x250(%rbp)
 1240178:	ff 
 1240179:	c5 fc 10 85 d0 fc ff 	vmovups -0x330(%rbp),%ymm0
 1240180:	ff 
 1240181:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1240188:	ff 
 1240189:	84 c9                	test   %cl,%cl
 124018b:	0f 94 c1             	sete   %cl
 124018e:	08 c1                	or     %al,%cl
 1240190:	0f 84 b2 01 00 00    	je     1240348 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1128>
 1240196:	4d 89 fc             	mov    %r15,%r12
 1240199:	4c 89 f3             	mov    %r14,%rbx
 124019c:	80 bd 2b ff ff ff 00 	cmpb   $0x0,-0xd5(%rbp)
 12401a3:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 12401a7:	0f 84 44 0c 00 00    	je     1240df1 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1bd1>
 12401ad:	48 8b 85 c0 fa ff ff 	mov    -0x540(%rbp),%rax
 12401b4:	48 89 85 40 db ff ff 	mov    %rax,-0x24c0(%rbp)
 12401bb:	c5 fc 10 85 60 fa ff 	vmovups -0x5a0(%rbp),%ymm0
 12401c2:	ff 
 12401c3:	c5 fc 10 8d 80 fa ff 	vmovups -0x580(%rbp),%ymm1
 12401ca:	ff 
 12401cb:	c5 fc 10 95 a0 fa ff 	vmovups -0x560(%rbp),%ymm2
 12401d2:	ff 
 12401d3:	c5 fc 11 95 20 db ff 	vmovups %ymm2,-0x24e0(%rbp)
 12401da:	ff 
 12401db:	c5 fc 11 8d 00 db ff 	vmovups %ymm1,-0x2500(%rbp)
 12401e2:	ff 
 12401e3:	c5 fc 11 85 e0 da ff 	vmovups %ymm0,-0x2520(%rbp)
 12401ea:	ff 
 12401eb:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 12401f2:	ff 
 12401f3:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 12401fa:	ff 
 12401fb:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1240202:	ff 
 1240203:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124020a:	ff 
 124020b:	c5 fc 11 85 30 f6 ff 	vmovups %ymm0,-0x9d0(%rbp)
 1240212:	ff 
 1240213:	c5 fc 11 8d 50 f6 ff 	vmovups %ymm1,-0x9b0(%rbp)
 124021a:	ff 
 124021b:	c5 fc 11 95 70 f6 ff 	vmovups %ymm2,-0x990(%rbp)
 1240222:	ff 
 1240223:	c5 fc 11 9d 90 f6 ff 	vmovups %ymm3,-0x970(%rbp)
 124022a:	ff 
 124022b:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1240232:	ff 
 1240233:	c5 fc 11 85 a0 f6 ff 	vmovups %ymm0,-0x960(%rbp)
 124023a:	ff 
 124023b:	c6 85 48 db ff ff 01 	movb   $0x1,-0x24b8(%rbp)
 1240242:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 1240249:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 124024e:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 1240255:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 124025a:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 124025e:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1240264:	48 8d 85 e0 da ff ff 	lea    -0x2520(%rbp),%rax
 124026b:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1240270:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1240275:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1240279:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 124027e:	48 8d 85 30 f6 ff ff 	lea    -0x9d0(%rbp),%rax
 1240285:	48 89 04 24          	mov    %rax,(%rsp)
 1240289:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1240290:	00 00 
 1240292:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1240299:	00 00 
 124029b:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 124029f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12402a3:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 12402a7:	4d 89 f0             	mov    %r14,%r8
 12402aa:	4d 89 e9             	mov    %r13,%r9
 12402ad:	c5 f8 77             	vzeroupper 
 12402b0:	e8 ab 45 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 12402b5:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 12402ba:	66 45 85 f6          	test   %r14w,%r14w
 12402be:	0f 85 61 2d 00 00    	jne    1243025 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3e05>
 12402c4:	4c 8b 6d a0          	mov    -0x60(%rbp),%r13
 12402c8:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 12402cc:	49 39 df             	cmp    %rbx,%r15
 12402cf:	0f 83 08 02 00 00    	jae    12404dd <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x12bd>
 12402d5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12402d9:	48 8b 38             	mov    (%rax),%rdi
 12402dc:	48 8b 40 08          	mov    0x8(%rax),%rax
 12402e0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12402e4:	4c 89 e6             	mov    %r12,%rsi
 12402e7:	48 89 da             	mov    %rbx,%rdx
 12402ea:	31 c9                	xor    %ecx,%ecx
 12402ec:	ff 50 18             	call   *0x18(%rax)
 12402ef:	c5 fc 10 85 a0 f6 ff 	vmovups -0x960(%rbp),%ymm0
 12402f6:	ff 
 12402f7:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 12402fe:	ff 
 12402ff:	c5 fc 10 85 30 f6 ff 	vmovups -0x9d0(%rbp),%ymm0
 1240306:	ff 
 1240307:	c5 fc 10 8d 50 f6 ff 	vmovups -0x9b0(%rbp),%ymm1
 124030e:	ff 
 124030f:	c5 fc 10 95 70 f6 ff 	vmovups -0x990(%rbp),%ymm2
 1240316:	ff 
 1240317:	c5 fc 10 9d 90 f6 ff 	vmovups -0x970(%rbp),%ymm3
 124031e:	ff 
 124031f:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1240326:	ff 
 1240327:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 124032e:	ff 
 124032f:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1240336:	ff 
 1240337:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 124033e:	ff 
 124033f:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 1240343:	e9 be 01 00 00       	jmp    1240506 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x12e6>
 1240348:	48 8b 85 50 fa ff ff 	mov    -0x5b0(%rbp),%rax
 124034f:	48 89 85 b0 db ff ff 	mov    %rax,-0x2450(%rbp)
 1240356:	c5 fc 10 85 f0 f9 ff 	vmovups -0x610(%rbp),%ymm0
 124035d:	ff 
 124035e:	c5 fc 10 8d 10 fa ff 	vmovups -0x5f0(%rbp),%ymm1
 1240365:	ff 
 1240366:	c5 fc 10 95 30 fa ff 	vmovups -0x5d0(%rbp),%ymm2
 124036d:	ff 
 124036e:	c5 fc 11 95 90 db ff 	vmovups %ymm2,-0x2470(%rbp)
 1240375:	ff 
 1240376:	c5 fc 11 8d 70 db ff 	vmovups %ymm1,-0x2490(%rbp)
 124037d:	ff 
 124037e:	c5 fc 11 85 50 db ff 	vmovups %ymm0,-0x24b0(%rbp)
 1240385:	ff 
 1240386:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124038d:	ff 
 124038e:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1240395:	ff 
 1240396:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 124039d:	ff 
 124039e:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 12403a5:	ff 
 12403a6:	c5 fc 11 85 c0 f6 ff 	vmovups %ymm0,-0x940(%rbp)
 12403ad:	ff 
 12403ae:	c5 fc 11 8d e0 f6 ff 	vmovups %ymm1,-0x920(%rbp)
 12403b5:	ff 
 12403b6:	c5 fc 11 95 00 f7 ff 	vmovups %ymm2,-0x900(%rbp)
 12403bd:	ff 
 12403be:	c5 fc 11 9d 20 f7 ff 	vmovups %ymm3,-0x8e0(%rbp)
 12403c5:	ff 
 12403c6:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 12403cd:	ff 
 12403ce:	c5 fc 11 85 30 f7 ff 	vmovups %ymm0,-0x8d0(%rbp)
 12403d5:	ff 
 12403d6:	c6 85 b8 db ff ff 01 	movb   $0x1,-0x2448(%rbp)
 12403dd:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 12403e4:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 12403e9:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 12403f0:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 12403f5:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 12403f9:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 12403ff:	48 8d 85 50 db ff ff 	lea    -0x24b0(%rbp),%rax
 1240406:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 124040b:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1240410:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1240414:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1240419:	48 8d 85 c0 f6 ff ff 	lea    -0x940(%rbp),%rax
 1240420:	48 89 04 24          	mov    %rax,(%rsp)
 1240424:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 124042b:	00 00 
 124042d:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1240434:	00 00 
 1240436:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 124043a:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124043e:	4c 89 e1             	mov    %r12,%rcx
 1240441:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 1240445:	4d 89 e9             	mov    %r13,%r9
 1240448:	c5 f8 77             	vzeroupper 
 124044b:	e8 10 44 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1240450:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 1240454:	66 85 db             	test   %bx,%bx
 1240457:	0f 85 89 3b 00 00    	jne    1243fe6 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4dc6>
 124045d:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 1240461:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 1240465:	4c 39 f3             	cmp    %r14,%rbx
 1240468:	0f 83 45 09 00 00    	jae    1240db3 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1b93>
 124046e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1240472:	48 8b 38             	mov    (%rax),%rdi
 1240475:	48 8b 40 08          	mov    0x8(%rax),%rax
 1240479:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124047d:	4c 89 fe             	mov    %r15,%rsi
 1240480:	4c 89 f2             	mov    %r14,%rdx
 1240483:	31 c9                	xor    %ecx,%ecx
 1240485:	ff 50 18             	call   *0x18(%rax)
 1240488:	c5 fc 10 85 30 f7 ff 	vmovups -0x8d0(%rbp),%ymm0
 124048f:	ff 
 1240490:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1240497:	ff 
 1240498:	c5 fc 10 85 c0 f6 ff 	vmovups -0x940(%rbp),%ymm0
 124049f:	ff 
 12404a0:	c5 fc 10 8d e0 f6 ff 	vmovups -0x920(%rbp),%ymm1
 12404a7:	ff 
 12404a8:	c5 fc 10 95 00 f7 ff 	vmovups -0x900(%rbp),%ymm2
 12404af:	ff 
 12404b0:	c5 fc 10 9d 20 f7 ff 	vmovups -0x8e0(%rbp),%ymm3
 12404b7:	ff 
 12404b8:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 12404bf:	ff 
 12404c0:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 12404c7:	ff 
 12404c8:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 12404cf:	ff 
 12404d0:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 12404d7:	ff 
 12404d8:	e9 fb 08 00 00       	jmp    1240dd8 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1bb8>
 12404dd:	4d 85 ff             	test   %r15,%r15
 12404e0:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 12404e4:	74 1a                	je     1240500 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x12e0>
 12404e6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12404ea:	48 8b 38             	mov    (%rax),%rdi
 12404ed:	48 8b 40 08          	mov    0x8(%rax),%rax
 12404f1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12404f5:	4c 89 ee             	mov    %r13,%rsi
 12404f8:	4c 89 fa             	mov    %r15,%rdx
 12404fb:	31 c9                	xor    %ecx,%ecx
 12404fd:	ff 50 18             	call   *0x18(%rax)
 1240500:	4d 89 e5             	mov    %r12,%r13
 1240503:	49 89 df             	mov    %rbx,%r15
 1240506:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 124050a:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 124050e:	80 bd 2c ff ff ff 00 	cmpb   $0x0,-0xd4(%rbp)
 1240515:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 1240519:	0f 84 e9 08 00 00    	je     1240e08 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1be8>
 124051f:	48 8b 85 30 fb ff ff 	mov    -0x4d0(%rbp),%rax
 1240526:	48 89 85 d0 da ff ff 	mov    %rax,-0x2530(%rbp)
 124052d:	c5 fc 10 85 d0 fa ff 	vmovups -0x530(%rbp),%ymm0
 1240534:	ff 
 1240535:	c5 fc 10 8d f0 fa ff 	vmovups -0x510(%rbp),%ymm1
 124053c:	ff 
 124053d:	c5 fc 10 95 10 fb ff 	vmovups -0x4f0(%rbp),%ymm2
 1240544:	ff 
 1240545:	c5 fc 11 95 b0 da ff 	vmovups %ymm2,-0x2550(%rbp)
 124054c:	ff 
 124054d:	c5 fc 11 8d 90 da ff 	vmovups %ymm1,-0x2570(%rbp)
 1240554:	ff 
 1240555:	c5 fc 11 85 70 da ff 	vmovups %ymm0,-0x2590(%rbp)
 124055c:	ff 
 124055d:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1240564:	ff 
 1240565:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124056c:	ff 
 124056d:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1240574:	ff 
 1240575:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124057c:	ff 
 124057d:	c5 fc 11 85 a0 f5 ff 	vmovups %ymm0,-0xa60(%rbp)
 1240584:	ff 
 1240585:	c5 fc 11 8d c0 f5 ff 	vmovups %ymm1,-0xa40(%rbp)
 124058c:	ff 
 124058d:	c5 fc 11 95 e0 f5 ff 	vmovups %ymm2,-0xa20(%rbp)
 1240594:	ff 
 1240595:	c5 fc 11 9d 00 f6 ff 	vmovups %ymm3,-0xa00(%rbp)
 124059c:	ff 
 124059d:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 12405a4:	ff 
 12405a5:	c5 fc 11 85 10 f6 ff 	vmovups %ymm0,-0x9f0(%rbp)
 12405ac:	ff 
 12405ad:	c6 85 d8 da ff ff 01 	movb   $0x1,-0x2528(%rbp)
 12405b4:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 12405bb:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 12405c0:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 12405c7:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 12405cc:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 12405d0:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 12405d6:	48 8d 85 70 da ff ff 	lea    -0x2590(%rbp),%rax
 12405dd:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 12405e2:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 12405e7:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12405eb:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 12405f0:	48 8d 85 a0 f5 ff ff 	lea    -0xa60(%rbp),%rax
 12405f7:	48 89 04 24          	mov    %rax,(%rsp)
 12405fb:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1240602:	00 00 
 1240604:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 124060b:	00 00 
 124060d:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1240611:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1240615:	4d 89 f0             	mov    %r14,%r8
 1240618:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 124061f:	c5 f8 77             	vzeroupper 
 1240622:	e8 39 42 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1240627:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 124062b:	66 85 db             	test   %bx,%bx
 124062e:	0f 85 ec 2a 00 00    	jne    1243120 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3f00>
 1240634:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 1240638:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 124063c:	4c 39 fb             	cmp    %r15,%rbx
 124063f:	73 6c                	jae    12406ad <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x148d>
 1240641:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1240645:	48 8b 38             	mov    (%rax),%rdi
 1240648:	48 8b 40 08          	mov    0x8(%rax),%rax
 124064c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1240650:	4c 89 ee             	mov    %r13,%rsi
 1240653:	4c 89 fa             	mov    %r15,%rdx
 1240656:	31 c9                	xor    %ecx,%ecx
 1240658:	ff 50 18             	call   *0x18(%rax)
 124065b:	c5 fc 10 85 10 f6 ff 	vmovups -0x9f0(%rbp),%ymm0
 1240662:	ff 
 1240663:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 124066a:	ff 
 124066b:	c5 fc 10 85 a0 f5 ff 	vmovups -0xa60(%rbp),%ymm0
 1240672:	ff 
 1240673:	c5 fc 10 8d c0 f5 ff 	vmovups -0xa40(%rbp),%ymm1
 124067a:	ff 
 124067b:	c5 fc 10 95 e0 f5 ff 	vmovups -0xa20(%rbp),%ymm2
 1240682:	ff 
 1240683:	c5 fc 10 9d 00 f6 ff 	vmovups -0xa00(%rbp),%ymm3
 124068a:	ff 
 124068b:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1240692:	ff 
 1240693:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 124069a:	ff 
 124069b:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 12406a2:	ff 
 12406a3:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 12406aa:	ff 
 12406ab:	eb 25                	jmp    12406d2 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x14b2>
 12406ad:	48 85 db             	test   %rbx,%rbx
 12406b0:	74 1a                	je     12406cc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x14ac>
 12406b2:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12406b6:	48 8b 38             	mov    (%rax),%rdi
 12406b9:	48 8b 40 08          	mov    0x8(%rax),%rax
 12406bd:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12406c1:	4c 89 e6             	mov    %r12,%rsi
 12406c4:	48 89 da             	mov    %rbx,%rdx
 12406c7:	31 c9                	xor    %ecx,%ecx
 12406c9:	ff 50 18             	call   *0x18(%rax)
 12406cc:	4d 89 ec             	mov    %r13,%r12
 12406cf:	4c 89 fb             	mov    %r15,%rbx
 12406d2:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 12406d6:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 12406da:	80 bd 2d ff ff ff 00 	cmpb   $0x0,-0xd3(%rbp)
 12406e1:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 12406e8:	0f 84 34 07 00 00    	je     1240e22 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1c02>
 12406ee:	48 8b 85 a0 fb ff ff 	mov    -0x460(%rbp),%rax
 12406f5:	48 89 85 60 da ff ff 	mov    %rax,-0x25a0(%rbp)
 12406fc:	c5 fc 10 85 40 fb ff 	vmovups -0x4c0(%rbp),%ymm0
 1240703:	ff 
 1240704:	c5 fc 10 8d 60 fb ff 	vmovups -0x4a0(%rbp),%ymm1
 124070b:	ff 
 124070c:	c5 fc 10 95 80 fb ff 	vmovups -0x480(%rbp),%ymm2
 1240713:	ff 
 1240714:	c5 fc 11 95 40 da ff 	vmovups %ymm2,-0x25c0(%rbp)
 124071b:	ff 
 124071c:	c5 fc 11 8d 20 da ff 	vmovups %ymm1,-0x25e0(%rbp)
 1240723:	ff 
 1240724:	c5 fc 11 85 00 da ff 	vmovups %ymm0,-0x2600(%rbp)
 124072b:	ff 
 124072c:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1240733:	ff 
 1240734:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124073b:	ff 
 124073c:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1240743:	ff 
 1240744:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124074b:	ff 
 124074c:	c5 fc 11 85 10 f5 ff 	vmovups %ymm0,-0xaf0(%rbp)
 1240753:	ff 
 1240754:	c5 fc 11 8d 30 f5 ff 	vmovups %ymm1,-0xad0(%rbp)
 124075b:	ff 
 124075c:	c5 fc 11 95 50 f5 ff 	vmovups %ymm2,-0xab0(%rbp)
 1240763:	ff 
 1240764:	c5 fc 11 9d 70 f5 ff 	vmovups %ymm3,-0xa90(%rbp)
 124076b:	ff 
 124076c:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1240773:	ff 
 1240774:	c5 fc 11 85 80 f5 ff 	vmovups %ymm0,-0xa80(%rbp)
 124077b:	ff 
 124077c:	c6 85 68 da ff ff 01 	movb   $0x1,-0x2598(%rbp)
 1240783:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 124078a:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 124078f:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 1240796:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 124079b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 124079f:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 12407a5:	48 8d 85 00 da ff ff 	lea    -0x2600(%rbp),%rax
 12407ac:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 12407b1:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 12407b6:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12407ba:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 12407bf:	48 8d 85 10 f5 ff ff 	lea    -0xaf0(%rbp),%rax
 12407c6:	48 89 04 24          	mov    %rax,(%rsp)
 12407ca:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 12407d1:	00 00 
 12407d3:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 12407da:	00 00 
 12407dc:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 12407e0:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12407e4:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 12407e8:	4d 89 f0             	mov    %r14,%r8
 12407eb:	c5 f8 77             	vzeroupper 
 12407ee:	e8 6d 40 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 12407f3:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 12407f8:	66 45 85 f6          	test   %r14w,%r14w
 12407fc:	0f 85 19 2a 00 00    	jne    124321b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3ffb>
 1240802:	4c 8b 6d a0          	mov    -0x60(%rbp),%r13
 1240806:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 124080a:	49 39 df             	cmp    %rbx,%r15
 124080d:	73 70                	jae    124087f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x165f>
 124080f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1240813:	48 8b 38             	mov    (%rax),%rdi
 1240816:	48 8b 40 08          	mov    0x8(%rax),%rax
 124081a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124081e:	4c 89 e6             	mov    %r12,%rsi
 1240821:	48 89 da             	mov    %rbx,%rdx
 1240824:	31 c9                	xor    %ecx,%ecx
 1240826:	ff 50 18             	call   *0x18(%rax)
 1240829:	c5 fc 10 85 80 f5 ff 	vmovups -0xa80(%rbp),%ymm0
 1240830:	ff 
 1240831:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1240838:	ff 
 1240839:	c5 fc 10 85 10 f5 ff 	vmovups -0xaf0(%rbp),%ymm0
 1240840:	ff 
 1240841:	c5 fc 10 8d 30 f5 ff 	vmovups -0xad0(%rbp),%ymm1
 1240848:	ff 
 1240849:	c5 fc 10 95 50 f5 ff 	vmovups -0xab0(%rbp),%ymm2
 1240850:	ff 
 1240851:	c5 fc 10 9d 70 f5 ff 	vmovups -0xa90(%rbp),%ymm3
 1240858:	ff 
 1240859:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1240860:	ff 
 1240861:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1240868:	ff 
 1240869:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1240870:	ff 
 1240871:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1240878:	ff 
 1240879:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 124087d:	eb 29                	jmp    12408a8 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1688>
 124087f:	4d 85 ff             	test   %r15,%r15
 1240882:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 1240886:	74 1a                	je     12408a2 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1682>
 1240888:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 124088c:	48 8b 38             	mov    (%rax),%rdi
 124088f:	48 8b 40 08          	mov    0x8(%rax),%rax
 1240893:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1240897:	4c 89 ee             	mov    %r13,%rsi
 124089a:	4c 89 fa             	mov    %r15,%rdx
 124089d:	31 c9                	xor    %ecx,%ecx
 124089f:	ff 50 18             	call   *0x18(%rax)
 12408a2:	4d 89 e5             	mov    %r12,%r13
 12408a5:	49 89 df             	mov    %rbx,%r15
 12408a8:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 12408ac:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 12408b0:	80 bd 2e ff ff ff 00 	cmpb   $0x0,-0xd2(%rbp)
 12408b7:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 12408bb:	0f 84 78 05 00 00    	je     1240e39 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1c19>
 12408c1:	48 8b 85 10 fc ff ff 	mov    -0x3f0(%rbp),%rax
 12408c8:	48 89 85 f0 d9 ff ff 	mov    %rax,-0x2610(%rbp)
 12408cf:	c5 fc 10 85 b0 fb ff 	vmovups -0x450(%rbp),%ymm0
 12408d6:	ff 
 12408d7:	c5 fc 10 8d d0 fb ff 	vmovups -0x430(%rbp),%ymm1
 12408de:	ff 
 12408df:	c5 fc 10 95 f0 fb ff 	vmovups -0x410(%rbp),%ymm2
 12408e6:	ff 
 12408e7:	c5 fc 11 95 d0 d9 ff 	vmovups %ymm2,-0x2630(%rbp)
 12408ee:	ff 
 12408ef:	c5 fc 11 8d b0 d9 ff 	vmovups %ymm1,-0x2650(%rbp)
 12408f6:	ff 
 12408f7:	c5 fc 11 85 90 d9 ff 	vmovups %ymm0,-0x2670(%rbp)
 12408fe:	ff 
 12408ff:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1240906:	ff 
 1240907:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124090e:	ff 
 124090f:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1240916:	ff 
 1240917:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124091e:	ff 
 124091f:	c5 fc 11 85 80 f4 ff 	vmovups %ymm0,-0xb80(%rbp)
 1240926:	ff 
 1240927:	c5 fc 11 8d a0 f4 ff 	vmovups %ymm1,-0xb60(%rbp)
 124092e:	ff 
 124092f:	c5 fc 11 95 c0 f4 ff 	vmovups %ymm2,-0xb40(%rbp)
 1240936:	ff 
 1240937:	c5 fc 11 9d e0 f4 ff 	vmovups %ymm3,-0xb20(%rbp)
 124093e:	ff 
 124093f:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1240946:	ff 
 1240947:	c5 fc 11 85 f0 f4 ff 	vmovups %ymm0,-0xb10(%rbp)
 124094e:	ff 
 124094f:	c6 85 f8 d9 ff ff 01 	movb   $0x1,-0x2608(%rbp)
 1240956:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 124095d:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 1240962:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 1240969:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 124096e:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1240972:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1240978:	48 8d 85 90 d9 ff ff 	lea    -0x2670(%rbp),%rax
 124097f:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1240984:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1240989:	48 8b 45 18          	mov    0x18(%rbp),%rax
 124098d:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1240992:	48 8d 85 80 f4 ff ff 	lea    -0xb80(%rbp),%rax
 1240999:	48 89 04 24          	mov    %rax,(%rsp)
 124099d:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 12409a4:	00 00 
 12409a6:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 12409ad:	00 00 
 12409af:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 12409b3:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12409b7:	4d 89 f0             	mov    %r14,%r8
 12409ba:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 12409c1:	c5 f8 77             	vzeroupper 
 12409c4:	e8 97 3e 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 12409c9:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 12409cd:	66 85 db             	test   %bx,%bx
 12409d0:	0f 85 40 29 00 00    	jne    1243316 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x40f6>
 12409d6:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 12409da:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 12409de:	4c 39 fb             	cmp    %r15,%rbx
 12409e1:	73 6c                	jae    1240a4f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x182f>
 12409e3:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12409e7:	48 8b 38             	mov    (%rax),%rdi
 12409ea:	48 8b 40 08          	mov    0x8(%rax),%rax
 12409ee:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12409f2:	4c 89 ee             	mov    %r13,%rsi
 12409f5:	4c 89 fa             	mov    %r15,%rdx
 12409f8:	31 c9                	xor    %ecx,%ecx
 12409fa:	ff 50 18             	call   *0x18(%rax)
 12409fd:	c5 fc 10 85 f0 f4 ff 	vmovups -0xb10(%rbp),%ymm0
 1240a04:	ff 
 1240a05:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1240a0c:	ff 
 1240a0d:	c5 fc 10 85 80 f4 ff 	vmovups -0xb80(%rbp),%ymm0
 1240a14:	ff 
 1240a15:	c5 fc 10 8d a0 f4 ff 	vmovups -0xb60(%rbp),%ymm1
 1240a1c:	ff 
 1240a1d:	c5 fc 10 95 c0 f4 ff 	vmovups -0xb40(%rbp),%ymm2
 1240a24:	ff 
 1240a25:	c5 fc 10 9d e0 f4 ff 	vmovups -0xb20(%rbp),%ymm3
 1240a2c:	ff 
 1240a2d:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1240a34:	ff 
 1240a35:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1240a3c:	ff 
 1240a3d:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1240a44:	ff 
 1240a45:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1240a4c:	ff 
 1240a4d:	eb 25                	jmp    1240a74 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1854>
 1240a4f:	48 85 db             	test   %rbx,%rbx
 1240a52:	74 1a                	je     1240a6e <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x184e>
 1240a54:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1240a58:	48 8b 38             	mov    (%rax),%rdi
 1240a5b:	48 8b 40 08          	mov    0x8(%rax),%rax
 1240a5f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1240a63:	4c 89 e6             	mov    %r12,%rsi
 1240a66:	48 89 da             	mov    %rbx,%rdx
 1240a69:	31 c9                	xor    %ecx,%ecx
 1240a6b:	ff 50 18             	call   *0x18(%rax)
 1240a6e:	4d 89 ec             	mov    %r13,%r12
 1240a71:	4c 89 fb             	mov    %r15,%rbx
 1240a74:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1240a78:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1240a7c:	80 bd 2f ff ff ff 00 	cmpb   $0x0,-0xd1(%rbp)
 1240a83:	4c 8b ad 78 ff ff ff 	mov    -0x88(%rbp),%r13
 1240a8a:	0f 84 c3 03 00 00    	je     1240e53 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1c33>
 1240a90:	48 8b 85 80 fc ff ff 	mov    -0x380(%rbp),%rax
 1240a97:	48 89 85 80 d9 ff ff 	mov    %rax,-0x2680(%rbp)
 1240a9e:	c5 fc 10 85 20 fc ff 	vmovups -0x3e0(%rbp),%ymm0
 1240aa5:	ff 
 1240aa6:	c5 fc 10 8d 40 fc ff 	vmovups -0x3c0(%rbp),%ymm1
 1240aad:	ff 
 1240aae:	c5 fc 10 95 60 fc ff 	vmovups -0x3a0(%rbp),%ymm2
 1240ab5:	ff 
 1240ab6:	c5 fc 11 95 60 d9 ff 	vmovups %ymm2,-0x26a0(%rbp)
 1240abd:	ff 
 1240abe:	c5 fc 11 8d 40 d9 ff 	vmovups %ymm1,-0x26c0(%rbp)
 1240ac5:	ff 
 1240ac6:	c5 fc 11 85 20 d9 ff 	vmovups %ymm0,-0x26e0(%rbp)
 1240acd:	ff 
 1240ace:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1240ad5:	ff 
 1240ad6:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1240add:	ff 
 1240ade:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1240ae5:	ff 
 1240ae6:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1240aed:	ff 
 1240aee:	c5 fc 11 85 f0 f3 ff 	vmovups %ymm0,-0xc10(%rbp)
 1240af5:	ff 
 1240af6:	c5 fc 11 8d 10 f4 ff 	vmovups %ymm1,-0xbf0(%rbp)
 1240afd:	ff 
 1240afe:	c5 fc 11 95 30 f4 ff 	vmovups %ymm2,-0xbd0(%rbp)
 1240b05:	ff 
 1240b06:	c5 fc 11 9d 50 f4 ff 	vmovups %ymm3,-0xbb0(%rbp)
 1240b0d:	ff 
 1240b0e:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1240b15:	ff 
 1240b16:	c5 fc 11 85 60 f4 ff 	vmovups %ymm0,-0xba0(%rbp)
 1240b1d:	ff 
 1240b1e:	c6 85 88 d9 ff ff 01 	movb   $0x1,-0x2678(%rbp)
 1240b25:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 1240b2c:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 1240b31:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 1240b38:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1240b3d:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1240b41:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1240b47:	48 8d 85 20 d9 ff ff 	lea    -0x26e0(%rbp),%rax
 1240b4e:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1240b53:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1240b58:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1240b5c:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1240b61:	48 8d 85 f0 f3 ff ff 	lea    -0xc10(%rbp),%rax
 1240b68:	48 89 04 24          	mov    %rax,(%rsp)
 1240b6c:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1240b73:	00 00 
 1240b75:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1240b7c:	00 00 
 1240b7e:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1240b82:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1240b86:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 1240b8a:	4d 89 f0             	mov    %r14,%r8
 1240b8d:	4d 89 e9             	mov    %r13,%r9
 1240b90:	c5 f8 77             	vzeroupper 
 1240b93:	e8 c8 3c 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1240b98:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 1240b9d:	66 45 85 f6          	test   %r14w,%r14w
 1240ba1:	0f 85 6a 28 00 00    	jne    1243411 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x41f1>
 1240ba7:	4c 8b 7d a0          	mov    -0x60(%rbp),%r15
 1240bab:	4c 8b 75 a8          	mov    -0x58(%rbp),%r14
 1240baf:	49 39 de             	cmp    %rbx,%r14
 1240bb2:	73 6c                	jae    1240c20 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1a00>
 1240bb4:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1240bb8:	48 8b 38             	mov    (%rax),%rdi
 1240bbb:	48 8b 40 08          	mov    0x8(%rax),%rax
 1240bbf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1240bc3:	4c 89 e6             	mov    %r12,%rsi
 1240bc6:	48 89 da             	mov    %rbx,%rdx
 1240bc9:	31 c9                	xor    %ecx,%ecx
 1240bcb:	ff 50 18             	call   *0x18(%rax)
 1240bce:	c5 fc 10 85 60 f4 ff 	vmovups -0xba0(%rbp),%ymm0
 1240bd5:	ff 
 1240bd6:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1240bdd:	ff 
 1240bde:	c5 fc 10 85 f0 f3 ff 	vmovups -0xc10(%rbp),%ymm0
 1240be5:	ff 
 1240be6:	c5 fc 10 8d 10 f4 ff 	vmovups -0xbf0(%rbp),%ymm1
 1240bed:	ff 
 1240bee:	c5 fc 10 95 30 f4 ff 	vmovups -0xbd0(%rbp),%ymm2
 1240bf5:	ff 
 1240bf6:	c5 fc 10 9d 50 f4 ff 	vmovups -0xbb0(%rbp),%ymm3
 1240bfd:	ff 
 1240bfe:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1240c05:	ff 
 1240c06:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1240c0d:	ff 
 1240c0e:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1240c15:	ff 
 1240c16:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1240c1d:	ff 
 1240c1e:	eb 25                	jmp    1240c45 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1a25>
 1240c20:	4d 85 f6             	test   %r14,%r14
 1240c23:	74 1a                	je     1240c3f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1a1f>
 1240c25:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1240c29:	48 8b 38             	mov    (%rax),%rdi
 1240c2c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1240c30:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1240c34:	4c 89 fe             	mov    %r15,%rsi
 1240c37:	4c 89 f2             	mov    %r14,%rdx
 1240c3a:	31 c9                	xor    %ecx,%ecx
 1240c3c:	ff 50 18             	call   *0x18(%rax)
 1240c3f:	4d 89 e7             	mov    %r12,%r15
 1240c42:	49 89 de             	mov    %rbx,%r14
 1240c45:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1240c49:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1240c4d:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1240c54:	0f 95 c0             	setne  %al
 1240c57:	84 45 c6             	test   %al,-0x3a(%rbp)
 1240c5a:	0f 84 0c 02 00 00    	je     1240e6c <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1c4c>
 1240c60:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1240c67:	ff 
 1240c68:	c5 fc 11 85 d0 f3 ff 	vmovups %ymm0,-0xc30(%rbp)
 1240c6f:	ff 
 1240c70:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1240c77:	ff 
 1240c78:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1240c7f:	ff 
 1240c80:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1240c87:	ff 
 1240c88:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1240c8f:	ff 
 1240c90:	c5 fc 11 9d c0 f3 ff 	vmovups %ymm3,-0xc40(%rbp)
 1240c97:	ff 
 1240c98:	c5 fc 11 95 a0 f3 ff 	vmovups %ymm2,-0xc60(%rbp)
 1240c9f:	ff 
 1240ca0:	c5 fc 11 8d 80 f3 ff 	vmovups %ymm1,-0xc80(%rbp)
 1240ca7:	ff 
 1240ca8:	c5 fc 11 85 60 f3 ff 	vmovups %ymm0,-0xca0(%rbp)
 1240caf:	ff 
 1240cb0:	48 8d 85 30 ff ff ff 	lea    -0xd0(%rbp),%rax
 1240cb7:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 1240cbc:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1240cc1:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1240cc5:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1240cca:	48 8d 85 60 f3 ff ff 	lea    -0xca0(%rbp),%rax
 1240cd1:	48 89 04 24          	mov    %rax,(%rsp)
 1240cd5:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1240cdc:	00 00 
 1240cde:	48 c7 44 24 40 68 ae 	movq   $0x103ae68,0x40(%rsp)
 1240ce5:	03 01 
 1240ce7:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1240cee:	00 00 
 1240cf0:	48 c7 44 24 30 f8 ad 	movq   $0x103adf8,0x30(%rsp)
 1240cf7:	03 01 
 1240cf9:	48 c7 44 24 28 00 00 	movq   $0x0,0x28(%rsp)
 1240d00:	00 00 
 1240d02:	48 c7 44 24 18 88 ad 	movq   $0x103ad88,0x18(%rsp)
 1240d09:	03 01 
 1240d0b:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1240d0f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1240d13:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 1240d17:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 1240d1b:	4d 89 e9             	mov    %r13,%r9
 1240d1e:	c5 f8 77             	vzeroupper 
 1240d21:	e8 3a 3b 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1240d26:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 1240d2a:	66 85 db             	test   %bx,%bx
 1240d2d:	0f 85 ae 33 00 00    	jne    12440e1 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4ec1>
 1240d33:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 1240d37:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 1240d3b:	4d 39 f5             	cmp    %r14,%r13
 1240d3e:	0f 83 b5 0b 00 00    	jae    12418f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x26d9>
 1240d44:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1240d48:	48 8b 38             	mov    (%rax),%rdi
 1240d4b:	48 8b 40 08          	mov    0x8(%rax),%rax
 1240d4f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1240d53:	4c 89 fe             	mov    %r15,%rsi
 1240d56:	4c 89 f2             	mov    %r14,%rdx
 1240d59:	31 c9                	xor    %ecx,%ecx
 1240d5b:	ff 50 18             	call   *0x18(%rax)
 1240d5e:	c5 fc 10 85 d0 f3 ff 	vmovups -0xc30(%rbp),%ymm0
 1240d65:	ff 
 1240d66:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1240d6d:	ff 
 1240d6e:	c5 fc 10 85 60 f3 ff 	vmovups -0xca0(%rbp),%ymm0
 1240d75:	ff 
 1240d76:	c5 fc 10 8d 80 f3 ff 	vmovups -0xc80(%rbp),%ymm1
 1240d7d:	ff 
 1240d7e:	c5 fc 10 95 a0 f3 ff 	vmovups -0xc60(%rbp),%ymm2
 1240d85:	ff 
 1240d86:	c5 fc 10 9d c0 f3 ff 	vmovups -0xc40(%rbp),%ymm3
 1240d8d:	ff 
 1240d8e:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1240d95:	ff 
 1240d96:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1240d9d:	ff 
 1240d9e:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1240da5:	ff 
 1240da6:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1240dad:	ff 
 1240dae:	e9 6b 0b 00 00       	jmp    124191e <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x26fe>
 1240db3:	48 85 db             	test   %rbx,%rbx
 1240db6:	74 1a                	je     1240dd2 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1bb2>
 1240db8:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1240dbc:	48 8b 38             	mov    (%rax),%rdi
 1240dbf:	48 8b 40 08          	mov    0x8(%rax),%rax
 1240dc3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1240dc7:	4c 89 e6             	mov    %r12,%rsi
 1240dca:	48 89 da             	mov    %rbx,%rdx
 1240dcd:	31 c9                	xor    %ecx,%ecx
 1240dcf:	ff 50 18             	call   *0x18(%rax)
 1240dd2:	4d 89 fc             	mov    %r15,%r12
 1240dd5:	4c 89 f3             	mov    %r14,%rbx
 1240dd8:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1240ddc:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1240de0:	80 bd 2b ff ff ff 00 	cmpb   $0x0,-0xd5(%rbp)
 1240de7:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 1240deb:	0f 85 bc f3 ff ff    	jne    12401ad <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0xf8d>
 1240df1:	4d 89 e5             	mov    %r12,%r13
 1240df4:	49 89 df             	mov    %rbx,%r15
 1240df7:	80 bd 2c ff ff ff 00 	cmpb   $0x0,-0xd4(%rbp)
 1240dfe:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 1240e02:	0f 85 17 f7 ff ff    	jne    124051f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x12ff>
 1240e08:	4d 89 ec             	mov    %r13,%r12
 1240e0b:	4c 89 fb             	mov    %r15,%rbx
 1240e0e:	80 bd 2d ff ff ff 00 	cmpb   $0x0,-0xd3(%rbp)
 1240e15:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 1240e1c:	0f 85 cc f8 ff ff    	jne    12406ee <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x14ce>
 1240e22:	4d 89 e5             	mov    %r12,%r13
 1240e25:	49 89 df             	mov    %rbx,%r15
 1240e28:	80 bd 2e ff ff ff 00 	cmpb   $0x0,-0xd2(%rbp)
 1240e2f:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 1240e33:	0f 85 88 fa ff ff    	jne    12408c1 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x16a1>
 1240e39:	4d 89 ec             	mov    %r13,%r12
 1240e3c:	4c 89 fb             	mov    %r15,%rbx
 1240e3f:	80 bd 2f ff ff ff 00 	cmpb   $0x0,-0xd1(%rbp)
 1240e46:	4c 8b ad 78 ff ff ff 	mov    -0x88(%rbp),%r13
 1240e4d:	0f 85 3d fc ff ff    	jne    1240a90 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1870>
 1240e53:	4d 89 e7             	mov    %r12,%r15
 1240e56:	49 89 de             	mov    %rbx,%r14
 1240e59:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1240e60:	0f 95 c0             	setne  %al
 1240e63:	84 45 c6             	test   %al,-0x3a(%rbp)
 1240e66:	0f 85 f4 fd ff ff    	jne    1240c60 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1a40>
 1240e6c:	4d 89 fc             	mov    %r15,%r12
 1240e6f:	4d 89 f5             	mov    %r14,%r13
 1240e72:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1240e79:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 1240e7d:	0f 84 b4 0a 00 00    	je     1241937 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2717>
 1240e83:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1240e8a:	ff 
 1240e8b:	c5 fc 11 85 40 f3 ff 	vmovups %ymm0,-0xcc0(%rbp)
 1240e92:	ff 
 1240e93:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1240e9a:	ff 
 1240e9b:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1240ea2:	ff 
 1240ea3:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1240eaa:	ff 
 1240eab:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1240eb2:	ff 
 1240eb3:	c5 fc 11 9d 30 f3 ff 	vmovups %ymm3,-0xcd0(%rbp)
 1240eba:	ff 
 1240ebb:	c5 fc 11 95 10 f3 ff 	vmovups %ymm2,-0xcf0(%rbp)
 1240ec2:	ff 
 1240ec3:	c5 fc 11 8d f0 f2 ff 	vmovups %ymm1,-0xd10(%rbp)
 1240eca:	ff 
 1240ecb:	c5 fc 11 85 d0 f2 ff 	vmovups %ymm0,-0xd30(%rbp)
 1240ed2:	ff 
 1240ed3:	48 8d 85 30 fe ff ff 	lea    -0x1d0(%rbp),%rax
 1240eda:	48 89 44 24 28       	mov    %rax,0x28(%rsp)
 1240edf:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 1240ee4:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1240ee9:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1240eed:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1240ef2:	48 8d 85 d0 f2 ff ff 	lea    -0xd30(%rbp),%rax
 1240ef9:	48 89 04 24          	mov    %rax,(%rsp)
 1240efd:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1240f04:	00 00 
 1240f06:	48 c7 44 24 40 68 ae 	movq   $0x103ae68,0x40(%rsp)
 1240f0d:	03 01 
 1240f0f:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1240f16:	00 00 
 1240f18:	48 c7 44 24 30 f8 ad 	movq   $0x103adf8,0x30(%rsp)
 1240f1f:	03 01 
 1240f21:	48 c7 44 24 18 88 ad 	movq   $0x103ad88,0x18(%rsp)
 1240f28:	03 01 
 1240f2a:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1240f2e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1240f32:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 1240f36:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 1240f3d:	c5 f8 77             	vzeroupper 
 1240f40:	e8 1b 39 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1240f45:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 1240f49:	66 85 db             	test   %bx,%bx
 1240f4c:	0f 85 ba 25 00 00    	jne    124350c <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x42ec>
 1240f52:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 1240f56:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 1240f5a:	4c 39 eb             	cmp    %r13,%rbx
 1240f5d:	73 6c                	jae    1240fcb <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1dab>
 1240f5f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1240f63:	48 8b 38             	mov    (%rax),%rdi
 1240f66:	48 8b 40 08          	mov    0x8(%rax),%rax
 1240f6a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1240f6e:	4c 89 e6             	mov    %r12,%rsi
 1240f71:	4c 89 ea             	mov    %r13,%rdx
 1240f74:	31 c9                	xor    %ecx,%ecx
 1240f76:	ff 50 18             	call   *0x18(%rax)
 1240f79:	c5 fc 10 85 40 f3 ff 	vmovups -0xcc0(%rbp),%ymm0
 1240f80:	ff 
 1240f81:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1240f88:	ff 
 1240f89:	c5 fc 10 85 d0 f2 ff 	vmovups -0xd30(%rbp),%ymm0
 1240f90:	ff 
 1240f91:	c5 fc 10 8d f0 f2 ff 	vmovups -0xd10(%rbp),%ymm1
 1240f98:	ff 
 1240f99:	c5 fc 10 95 10 f3 ff 	vmovups -0xcf0(%rbp),%ymm2
 1240fa0:	ff 
 1240fa1:	c5 fc 10 9d 30 f3 ff 	vmovups -0xcd0(%rbp),%ymm3
 1240fa8:	ff 
 1240fa9:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1240fb0:	ff 
 1240fb1:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1240fb8:	ff 
 1240fb9:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1240fc0:	ff 
 1240fc1:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1240fc8:	ff 
 1240fc9:	eb 25                	jmp    1240ff0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1dd0>
 1240fcb:	48 85 db             	test   %rbx,%rbx
 1240fce:	74 1a                	je     1240fea <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1dca>
 1240fd0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1240fd4:	48 8b 38             	mov    (%rax),%rdi
 1240fd7:	48 8b 40 08          	mov    0x8(%rax),%rax
 1240fdb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1240fdf:	4c 89 f6             	mov    %r14,%rsi
 1240fe2:	48 89 da             	mov    %rbx,%rdx
 1240fe5:	31 c9                	xor    %ecx,%ecx
 1240fe7:	ff 50 18             	call   *0x18(%rax)
 1240fea:	4d 89 e6             	mov    %r12,%r14
 1240fed:	4c 89 eb             	mov    %r13,%rbx
 1240ff0:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1240ff4:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1240ff8:	80 bd 98 de ff ff 00 	cmpb   $0x0,-0x2168(%rbp)
 1240fff:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 1241006:	4c 8b 65 88          	mov    -0x78(%rbp),%r12
 124100a:	0f 84 45 09 00 00    	je     1241955 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2735>
 1241010:	48 8b 85 90 de ff ff 	mov    -0x2170(%rbp),%rax
 1241017:	48 89 85 10 d9 ff ff 	mov    %rax,-0x26f0(%rbp)
 124101e:	c5 fc 10 85 30 de ff 	vmovups -0x21d0(%rbp),%ymm0
 1241025:	ff 
 1241026:	c5 fc 10 8d 50 de ff 	vmovups -0x21b0(%rbp),%ymm1
 124102d:	ff 
 124102e:	c5 fc 10 95 70 de ff 	vmovups -0x2190(%rbp),%ymm2
 1241035:	ff 
 1241036:	c5 fc 11 95 f0 d8 ff 	vmovups %ymm2,-0x2710(%rbp)
 124103d:	ff 
 124103e:	c5 fc 11 8d d0 d8 ff 	vmovups %ymm1,-0x2730(%rbp)
 1241045:	ff 
 1241046:	c5 fc 11 85 b0 d8 ff 	vmovups %ymm0,-0x2750(%rbp)
 124104d:	ff 
 124104e:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1241055:	ff 
 1241056:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124105d:	ff 
 124105e:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1241065:	ff 
 1241066:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124106d:	ff 
 124106e:	c5 fc 11 85 40 f2 ff 	vmovups %ymm0,-0xdc0(%rbp)
 1241075:	ff 
 1241076:	c5 fc 11 8d 60 f2 ff 	vmovups %ymm1,-0xda0(%rbp)
 124107d:	ff 
 124107e:	c5 fc 11 95 80 f2 ff 	vmovups %ymm2,-0xd80(%rbp)
 1241085:	ff 
 1241086:	c5 fc 11 9d a0 f2 ff 	vmovups %ymm3,-0xd60(%rbp)
 124108d:	ff 
 124108e:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1241095:	ff 
 1241096:	c5 fc 11 85 b0 f2 ff 	vmovups %ymm0,-0xd50(%rbp)
 124109d:	ff 
 124109e:	c6 85 18 d9 ff ff 01 	movb   $0x1,-0x26e8(%rbp)
 12410a5:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 12410ac:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 12410b1:	48 8d 85 b0 d8 ff ff 	lea    -0x2750(%rbp),%rax
 12410b8:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 12410bd:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 12410c1:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 12410c7:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 12410cb:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 12410d0:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 12410d5:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12410d9:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 12410de:	48 8d 85 40 f2 ff ff 	lea    -0xdc0(%rbp),%rax
 12410e5:	48 89 04 24          	mov    %rax,(%rsp)
 12410e9:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 12410f0:	00 00 
 12410f2:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 12410f9:	00 00 
 12410fb:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 12410ff:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1241103:	4c 89 e1             	mov    %r12,%rcx
 1241106:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 124110a:	c5 f8 77             	vzeroupper 
 124110d:	e8 4e 37 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1241112:	44 0f b7 7d b0       	movzwl -0x50(%rbp),%r15d
 1241117:	66 45 85 ff          	test   %r15w,%r15w
 124111b:	0f 85 e6 24 00 00    	jne    1243607 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x43e7>
 1241121:	4c 8b 6d a0          	mov    -0x60(%rbp),%r13
 1241125:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 1241129:	49 39 df             	cmp    %rbx,%r15
 124112c:	73 6c                	jae    124119a <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1f7a>
 124112e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1241132:	48 8b 38             	mov    (%rax),%rdi
 1241135:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241139:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124113d:	4c 89 f6             	mov    %r14,%rsi
 1241140:	48 89 da             	mov    %rbx,%rdx
 1241143:	31 c9                	xor    %ecx,%ecx
 1241145:	ff 50 18             	call   *0x18(%rax)
 1241148:	c5 fc 10 85 b0 f2 ff 	vmovups -0xd50(%rbp),%ymm0
 124114f:	ff 
 1241150:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1241157:	ff 
 1241158:	c5 fc 10 85 40 f2 ff 	vmovups -0xdc0(%rbp),%ymm0
 124115f:	ff 
 1241160:	c5 fc 10 8d 60 f2 ff 	vmovups -0xda0(%rbp),%ymm1
 1241167:	ff 
 1241168:	c5 fc 10 95 80 f2 ff 	vmovups -0xd80(%rbp),%ymm2
 124116f:	ff 
 1241170:	c5 fc 10 9d a0 f2 ff 	vmovups -0xd60(%rbp),%ymm3
 1241177:	ff 
 1241178:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 124117f:	ff 
 1241180:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1241187:	ff 
 1241188:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 124118f:	ff 
 1241190:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1241197:	ff 
 1241198:	eb 25                	jmp    12411bf <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1f9f>
 124119a:	4d 85 ff             	test   %r15,%r15
 124119d:	74 1a                	je     12411b9 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1f99>
 124119f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12411a3:	48 8b 38             	mov    (%rax),%rdi
 12411a6:	48 8b 40 08          	mov    0x8(%rax),%rax
 12411aa:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12411ae:	4c 89 ee             	mov    %r13,%rsi
 12411b1:	4c 89 fa             	mov    %r15,%rdx
 12411b4:	31 c9                	xor    %ecx,%ecx
 12411b6:	ff 50 18             	call   *0x18(%rax)
 12411b9:	4d 89 f5             	mov    %r14,%r13
 12411bc:	49 89 df             	mov    %rbx,%r15
 12411bf:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 12411c3:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 12411c7:	80 bd 08 df ff ff 00 	cmpb   $0x0,-0x20f8(%rbp)
 12411ce:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 12411d2:	0f 84 94 07 00 00    	je     124196c <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x274c>
 12411d8:	48 8b 85 00 df ff ff 	mov    -0x2100(%rbp),%rax
 12411df:	48 89 85 a0 d8 ff ff 	mov    %rax,-0x2760(%rbp)
 12411e6:	c5 fc 10 85 a0 de ff 	vmovups -0x2160(%rbp),%ymm0
 12411ed:	ff 
 12411ee:	c5 fc 10 8d c0 de ff 	vmovups -0x2140(%rbp),%ymm1
 12411f5:	ff 
 12411f6:	c5 fc 10 95 e0 de ff 	vmovups -0x2120(%rbp),%ymm2
 12411fd:	ff 
 12411fe:	c5 fc 11 95 80 d8 ff 	vmovups %ymm2,-0x2780(%rbp)
 1241205:	ff 
 1241206:	c5 fc 11 8d 60 d8 ff 	vmovups %ymm1,-0x27a0(%rbp)
 124120d:	ff 
 124120e:	c5 fc 11 85 40 d8 ff 	vmovups %ymm0,-0x27c0(%rbp)
 1241215:	ff 
 1241216:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124121d:	ff 
 124121e:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1241225:	ff 
 1241226:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 124122d:	ff 
 124122e:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1241235:	ff 
 1241236:	c5 fc 11 85 b0 f1 ff 	vmovups %ymm0,-0xe50(%rbp)
 124123d:	ff 
 124123e:	c5 fc 11 8d d0 f1 ff 	vmovups %ymm1,-0xe30(%rbp)
 1241245:	ff 
 1241246:	c5 fc 11 95 f0 f1 ff 	vmovups %ymm2,-0xe10(%rbp)
 124124d:	ff 
 124124e:	c5 fc 11 9d 10 f2 ff 	vmovups %ymm3,-0xdf0(%rbp)
 1241255:	ff 
 1241256:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 124125d:	ff 
 124125e:	c5 fc 11 85 20 f2 ff 	vmovups %ymm0,-0xde0(%rbp)
 1241265:	ff 
 1241266:	c6 85 a8 d8 ff ff 01 	movb   $0x1,-0x2758(%rbp)
 124126d:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 1241274:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 1241279:	48 8d 85 40 d8 ff ff 	lea    -0x27c0(%rbp),%rax
 1241280:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1241285:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1241289:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 124128f:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1241293:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1241298:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 124129d:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12412a1:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 12412a6:	48 8d 85 b0 f1 ff ff 	lea    -0xe50(%rbp),%rax
 12412ad:	48 89 04 24          	mov    %rax,(%rsp)
 12412b1:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 12412b8:	00 00 
 12412ba:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 12412c1:	00 00 
 12412c3:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 12412c7:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12412cb:	4c 89 e1             	mov    %r12,%rcx
 12412ce:	4d 89 f0             	mov    %r14,%r8
 12412d1:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 12412d8:	c5 f8 77             	vzeroupper 
 12412db:	e8 80 35 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 12412e0:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 12412e4:	66 85 db             	test   %bx,%bx
 12412e7:	0f 85 26 24 00 00    	jne    1243713 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x44f3>
 12412ed:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 12412f1:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 12412f5:	4c 39 fb             	cmp    %r15,%rbx
 12412f8:	73 6c                	jae    1241366 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2146>
 12412fa:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12412fe:	48 8b 38             	mov    (%rax),%rdi
 1241301:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241305:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1241309:	4c 89 ee             	mov    %r13,%rsi
 124130c:	4c 89 fa             	mov    %r15,%rdx
 124130f:	31 c9                	xor    %ecx,%ecx
 1241311:	ff 50 18             	call   *0x18(%rax)
 1241314:	c5 fc 10 85 20 f2 ff 	vmovups -0xde0(%rbp),%ymm0
 124131b:	ff 
 124131c:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1241323:	ff 
 1241324:	c5 fc 10 85 b0 f1 ff 	vmovups -0xe50(%rbp),%ymm0
 124132b:	ff 
 124132c:	c5 fc 10 8d d0 f1 ff 	vmovups -0xe30(%rbp),%ymm1
 1241333:	ff 
 1241334:	c5 fc 10 95 f0 f1 ff 	vmovups -0xe10(%rbp),%ymm2
 124133b:	ff 
 124133c:	c5 fc 10 9d 10 f2 ff 	vmovups -0xdf0(%rbp),%ymm3
 1241343:	ff 
 1241344:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 124134b:	ff 
 124134c:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1241353:	ff 
 1241354:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 124135b:	ff 
 124135c:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1241363:	ff 
 1241364:	eb 25                	jmp    124138b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x216b>
 1241366:	48 85 db             	test   %rbx,%rbx
 1241369:	74 1a                	je     1241385 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2165>
 124136b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 124136f:	48 8b 38             	mov    (%rax),%rdi
 1241372:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241376:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124137a:	4c 89 e6             	mov    %r12,%rsi
 124137d:	48 89 da             	mov    %rbx,%rdx
 1241380:	31 c9                	xor    %ecx,%ecx
 1241382:	ff 50 18             	call   *0x18(%rax)
 1241385:	4d 89 ec             	mov    %r13,%r12
 1241388:	4c 89 fb             	mov    %r15,%rbx
 124138b:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 124138f:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1241393:	80 bd 78 df ff ff 00 	cmpb   $0x0,-0x2088(%rbp)
 124139a:	4c 8b ad 78 ff ff ff 	mov    -0x88(%rbp),%r13
 12413a1:	0f 84 df 05 00 00    	je     1241986 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2766>
 12413a7:	48 8b 85 70 df ff ff 	mov    -0x2090(%rbp),%rax
 12413ae:	48 89 85 30 d8 ff ff 	mov    %rax,-0x27d0(%rbp)
 12413b5:	c5 fc 10 85 10 df ff 	vmovups -0x20f0(%rbp),%ymm0
 12413bc:	ff 
 12413bd:	c5 fc 10 8d 30 df ff 	vmovups -0x20d0(%rbp),%ymm1
 12413c4:	ff 
 12413c5:	c5 fc 10 95 50 df ff 	vmovups -0x20b0(%rbp),%ymm2
 12413cc:	ff 
 12413cd:	c5 fc 11 95 10 d8 ff 	vmovups %ymm2,-0x27f0(%rbp)
 12413d4:	ff 
 12413d5:	c5 fc 11 8d f0 d7 ff 	vmovups %ymm1,-0x2810(%rbp)
 12413dc:	ff 
 12413dd:	c5 fc 11 85 d0 d7 ff 	vmovups %ymm0,-0x2830(%rbp)
 12413e4:	ff 
 12413e5:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 12413ec:	ff 
 12413ed:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 12413f4:	ff 
 12413f5:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 12413fc:	ff 
 12413fd:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1241404:	ff 
 1241405:	c5 fc 11 85 20 f1 ff 	vmovups %ymm0,-0xee0(%rbp)
 124140c:	ff 
 124140d:	c5 fc 11 8d 40 f1 ff 	vmovups %ymm1,-0xec0(%rbp)
 1241414:	ff 
 1241415:	c5 fc 11 95 60 f1 ff 	vmovups %ymm2,-0xea0(%rbp)
 124141c:	ff 
 124141d:	c5 fc 11 9d 80 f1 ff 	vmovups %ymm3,-0xe80(%rbp)
 1241424:	ff 
 1241425:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 124142c:	ff 
 124142d:	c5 fc 11 85 90 f1 ff 	vmovups %ymm0,-0xe70(%rbp)
 1241434:	ff 
 1241435:	c6 85 38 d8 ff ff 01 	movb   $0x1,-0x27c8(%rbp)
 124143c:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 1241443:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 1241448:	48 8d 85 d0 d7 ff ff 	lea    -0x2830(%rbp),%rax
 124144f:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1241454:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1241458:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 124145e:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1241462:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1241467:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 124146c:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1241470:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1241475:	48 8d 85 20 f1 ff ff 	lea    -0xee0(%rbp),%rax
 124147c:	48 89 04 24          	mov    %rax,(%rsp)
 1241480:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1241487:	00 00 
 1241489:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1241490:	00 00 
 1241492:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1241496:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124149a:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 124149e:	4d 89 f0             	mov    %r14,%r8
 12414a1:	4d 89 e9             	mov    %r13,%r9
 12414a4:	c5 f8 77             	vzeroupper 
 12414a7:	e8 b4 33 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 12414ac:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 12414b1:	66 45 85 f6          	test   %r14w,%r14w
 12414b5:	0f 85 53 23 00 00    	jne    124380e <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x45ee>
 12414bb:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 12414bf:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 12414c3:	49 39 df             	cmp    %rbx,%r15
 12414c6:	73 6c                	jae    1241534 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2314>
 12414c8:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12414cc:	48 8b 38             	mov    (%rax),%rdi
 12414cf:	48 8b 40 08          	mov    0x8(%rax),%rax
 12414d3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12414d7:	4c 89 e6             	mov    %r12,%rsi
 12414da:	48 89 da             	mov    %rbx,%rdx
 12414dd:	31 c9                	xor    %ecx,%ecx
 12414df:	ff 50 18             	call   *0x18(%rax)
 12414e2:	c5 fc 10 85 90 f1 ff 	vmovups -0xe70(%rbp),%ymm0
 12414e9:	ff 
 12414ea:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 12414f1:	ff 
 12414f2:	c5 fc 10 85 20 f1 ff 	vmovups -0xee0(%rbp),%ymm0
 12414f9:	ff 
 12414fa:	c5 fc 10 8d 40 f1 ff 	vmovups -0xec0(%rbp),%ymm1
 1241501:	ff 
 1241502:	c5 fc 10 95 60 f1 ff 	vmovups -0xea0(%rbp),%ymm2
 1241509:	ff 
 124150a:	c5 fc 10 9d 80 f1 ff 	vmovups -0xe80(%rbp),%ymm3
 1241511:	ff 
 1241512:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1241519:	ff 
 124151a:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1241521:	ff 
 1241522:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1241529:	ff 
 124152a:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1241531:	ff 
 1241532:	eb 25                	jmp    1241559 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2339>
 1241534:	4d 85 ff             	test   %r15,%r15
 1241537:	74 1a                	je     1241553 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2333>
 1241539:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 124153d:	48 8b 38             	mov    (%rax),%rdi
 1241540:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241544:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1241548:	4c 89 f6             	mov    %r14,%rsi
 124154b:	4c 89 fa             	mov    %r15,%rdx
 124154e:	31 c9                	xor    %ecx,%ecx
 1241550:	ff 50 18             	call   *0x18(%rax)
 1241553:	4d 89 e6             	mov    %r12,%r14
 1241556:	49 89 df             	mov    %rbx,%r15
 1241559:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 124155d:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1241561:	80 bd e8 df ff ff 00 	cmpb   $0x0,-0x2018(%rbp)
 1241568:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 124156c:	0f 84 2b 04 00 00    	je     124199d <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x277d>
 1241572:	48 8b 85 e0 df ff ff 	mov    -0x2020(%rbp),%rax
 1241579:	48 89 85 c0 d7 ff ff 	mov    %rax,-0x2840(%rbp)
 1241580:	c5 fc 10 85 80 df ff 	vmovups -0x2080(%rbp),%ymm0
 1241587:	ff 
 1241588:	c5 fc 10 8d a0 df ff 	vmovups -0x2060(%rbp),%ymm1
 124158f:	ff 
 1241590:	c5 fc 10 95 c0 df ff 	vmovups -0x2040(%rbp),%ymm2
 1241597:	ff 
 1241598:	c5 fc 11 95 a0 d7 ff 	vmovups %ymm2,-0x2860(%rbp)
 124159f:	ff 
 12415a0:	c5 fc 11 8d 80 d7 ff 	vmovups %ymm1,-0x2880(%rbp)
 12415a7:	ff 
 12415a8:	c5 fc 11 85 60 d7 ff 	vmovups %ymm0,-0x28a0(%rbp)
 12415af:	ff 
 12415b0:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 12415b7:	ff 
 12415b8:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 12415bf:	ff 
 12415c0:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 12415c7:	ff 
 12415c8:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 12415cf:	ff 
 12415d0:	c5 fc 11 85 90 f0 ff 	vmovups %ymm0,-0xf70(%rbp)
 12415d7:	ff 
 12415d8:	c5 fc 11 8d b0 f0 ff 	vmovups %ymm1,-0xf50(%rbp)
 12415df:	ff 
 12415e0:	c5 fc 11 95 d0 f0 ff 	vmovups %ymm2,-0xf30(%rbp)
 12415e7:	ff 
 12415e8:	c5 fc 11 9d f0 f0 ff 	vmovups %ymm3,-0xf10(%rbp)
 12415ef:	ff 
 12415f0:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 12415f7:	ff 
 12415f8:	c5 fc 11 85 00 f1 ff 	vmovups %ymm0,-0xf00(%rbp)
 12415ff:	ff 
 1241600:	c6 85 c8 d7 ff ff 01 	movb   $0x1,-0x2838(%rbp)
 1241607:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 124160e:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 1241613:	48 8d 85 60 d7 ff ff 	lea    -0x28a0(%rbp),%rax
 124161a:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 124161f:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1241623:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1241629:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 124162d:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1241632:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1241637:	48 8b 45 18          	mov    0x18(%rbp),%rax
 124163b:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1241640:	48 8d 85 90 f0 ff ff 	lea    -0xf70(%rbp),%rax
 1241647:	48 89 04 24          	mov    %rax,(%rsp)
 124164b:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1241652:	00 00 
 1241654:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 124165b:	00 00 
 124165d:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1241661:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1241665:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 1241669:	4d 89 e9             	mov    %r13,%r9
 124166c:	c5 f8 77             	vzeroupper 
 124166f:	e8 ec 31 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1241674:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 1241678:	66 85 db             	test   %bx,%bx
 124167b:	0f 85 88 22 00 00    	jne    1243909 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x46e9>
 1241681:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 1241685:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 1241689:	4d 39 fd             	cmp    %r15,%r13
 124168c:	73 6c                	jae    12416fa <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x24da>
 124168e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1241692:	48 8b 38             	mov    (%rax),%rdi
 1241695:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241699:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124169d:	4c 89 f6             	mov    %r14,%rsi
 12416a0:	4c 89 fa             	mov    %r15,%rdx
 12416a3:	31 c9                	xor    %ecx,%ecx
 12416a5:	ff 50 18             	call   *0x18(%rax)
 12416a8:	c5 fc 10 85 00 f1 ff 	vmovups -0xf00(%rbp),%ymm0
 12416af:	ff 
 12416b0:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 12416b7:	ff 
 12416b8:	c5 fc 10 85 90 f0 ff 	vmovups -0xf70(%rbp),%ymm0
 12416bf:	ff 
 12416c0:	c5 fc 10 8d b0 f0 ff 	vmovups -0xf50(%rbp),%ymm1
 12416c7:	ff 
 12416c8:	c5 fc 10 95 d0 f0 ff 	vmovups -0xf30(%rbp),%ymm2
 12416cf:	ff 
 12416d0:	c5 fc 10 9d f0 f0 ff 	vmovups -0xf10(%rbp),%ymm3
 12416d7:	ff 
 12416d8:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 12416df:	ff 
 12416e0:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 12416e7:	ff 
 12416e8:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 12416ef:	ff 
 12416f0:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 12416f7:	ff 
 12416f8:	eb 25                	jmp    124171f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x24ff>
 12416fa:	4d 85 ed             	test   %r13,%r13
 12416fd:	74 1a                	je     1241719 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x24f9>
 12416ff:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1241703:	48 8b 38             	mov    (%rax),%rdi
 1241706:	48 8b 40 08          	mov    0x8(%rax),%rax
 124170a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124170e:	4c 89 e6             	mov    %r12,%rsi
 1241711:	4c 89 ea             	mov    %r13,%rdx
 1241714:	31 c9                	xor    %ecx,%ecx
 1241716:	ff 50 18             	call   *0x18(%rax)
 1241719:	4d 89 f4             	mov    %r14,%r12
 124171c:	4d 89 fd             	mov    %r15,%r13
 124171f:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1241723:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1241727:	80 bd 58 e0 ff ff 00 	cmpb   $0x0,-0x1fa8(%rbp)
 124172e:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 1241732:	0f 84 7c 02 00 00    	je     12419b4 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2794>
 1241738:	48 8b 85 50 e0 ff ff 	mov    -0x1fb0(%rbp),%rax
 124173f:	48 89 85 50 d7 ff ff 	mov    %rax,-0x28b0(%rbp)
 1241746:	c5 fc 10 85 f0 df ff 	vmovups -0x2010(%rbp),%ymm0
 124174d:	ff 
 124174e:	c5 fc 10 8d 10 e0 ff 	vmovups -0x1ff0(%rbp),%ymm1
 1241755:	ff 
 1241756:	c5 fc 10 95 30 e0 ff 	vmovups -0x1fd0(%rbp),%ymm2
 124175d:	ff 
 124175e:	c5 fc 11 95 30 d7 ff 	vmovups %ymm2,-0x28d0(%rbp)
 1241765:	ff 
 1241766:	c5 fc 11 8d 10 d7 ff 	vmovups %ymm1,-0x28f0(%rbp)
 124176d:	ff 
 124176e:	c5 fc 11 85 f0 d6 ff 	vmovups %ymm0,-0x2910(%rbp)
 1241775:	ff 
 1241776:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124177d:	ff 
 124177e:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1241785:	ff 
 1241786:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 124178d:	ff 
 124178e:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1241795:	ff 
 1241796:	c5 fc 11 85 00 f0 ff 	vmovups %ymm0,-0x1000(%rbp)
 124179d:	ff 
 124179e:	c5 fc 11 8d 20 f0 ff 	vmovups %ymm1,-0xfe0(%rbp)
 12417a5:	ff 
 12417a6:	c5 fc 11 95 40 f0 ff 	vmovups %ymm2,-0xfc0(%rbp)
 12417ad:	ff 
 12417ae:	c5 fc 11 9d 60 f0 ff 	vmovups %ymm3,-0xfa0(%rbp)
 12417b5:	ff 
 12417b6:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 12417bd:	ff 
 12417be:	c5 fc 11 85 70 f0 ff 	vmovups %ymm0,-0xf90(%rbp)
 12417c5:	ff 
 12417c6:	c6 85 58 d7 ff ff 01 	movb   $0x1,-0x28a8(%rbp)
 12417cd:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 12417d4:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 12417d9:	48 8d 85 f0 d6 ff ff 	lea    -0x2910(%rbp),%rax
 12417e0:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 12417e5:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 12417e9:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 12417ef:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 12417f3:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 12417f8:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 12417fd:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1241801:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1241806:	48 8d 85 00 f0 ff ff 	lea    -0x1000(%rbp),%rax
 124180d:	48 89 04 24          	mov    %rax,(%rsp)
 1241811:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1241818:	00 00 
 124181a:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1241821:	00 00 
 1241823:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1241827:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124182b:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 124182f:	4d 89 f0             	mov    %r14,%r8
 1241832:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 1241839:	c5 f8 77             	vzeroupper 
 124183c:	e8 1f 30 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1241841:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 1241845:	66 85 db             	test   %bx,%bx
 1241848:	0f 85 b6 21 00 00    	jne    1243a04 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x47e4>
 124184e:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 1241852:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 1241856:	4d 39 ef             	cmp    %r13,%r15
 1241859:	73 6c                	jae    12418c7 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x26a7>
 124185b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 124185f:	48 8b 38             	mov    (%rax),%rdi
 1241862:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241866:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124186a:	4c 89 e6             	mov    %r12,%rsi
 124186d:	4c 89 ea             	mov    %r13,%rdx
 1241870:	31 c9                	xor    %ecx,%ecx
 1241872:	ff 50 18             	call   *0x18(%rax)
 1241875:	c5 fc 10 85 70 f0 ff 	vmovups -0xf90(%rbp),%ymm0
 124187c:	ff 
 124187d:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1241884:	ff 
 1241885:	c5 fc 10 85 00 f0 ff 	vmovups -0x1000(%rbp),%ymm0
 124188c:	ff 
 124188d:	c5 fc 10 8d 20 f0 ff 	vmovups -0xfe0(%rbp),%ymm1
 1241894:	ff 
 1241895:	c5 fc 10 95 40 f0 ff 	vmovups -0xfc0(%rbp),%ymm2
 124189c:	ff 
 124189d:	c5 fc 10 9d 60 f0 ff 	vmovups -0xfa0(%rbp),%ymm3
 12418a4:	ff 
 12418a5:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 12418ac:	ff 
 12418ad:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 12418b4:	ff 
 12418b5:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 12418bc:	ff 
 12418bd:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 12418c4:	ff 
 12418c5:	eb 25                	jmp    12418ec <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x26cc>
 12418c7:	4d 85 ff             	test   %r15,%r15
 12418ca:	74 1a                	je     12418e6 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x26c6>
 12418cc:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12418d0:	48 8b 38             	mov    (%rax),%rdi
 12418d3:	48 8b 40 08          	mov    0x8(%rax),%rax
 12418d7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12418db:	48 89 de             	mov    %rbx,%rsi
 12418de:	4c 89 fa             	mov    %r15,%rdx
 12418e1:	31 c9                	xor    %ecx,%ecx
 12418e3:	ff 50 18             	call   *0x18(%rax)
 12418e6:	4c 89 e3             	mov    %r12,%rbx
 12418e9:	4d 89 ef             	mov    %r13,%r15
 12418ec:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 12418f0:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 12418f4:	e9 c1 00 00 00       	jmp    12419ba <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x279a>
 12418f9:	4d 85 ed             	test   %r13,%r13
 12418fc:	74 1a                	je     1241918 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x26f8>
 12418fe:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1241902:	48 8b 38             	mov    (%rax),%rdi
 1241905:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241909:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124190d:	4c 89 e6             	mov    %r12,%rsi
 1241910:	4c 89 ea             	mov    %r13,%rdx
 1241913:	31 c9                	xor    %ecx,%ecx
 1241915:	ff 50 18             	call   *0x18(%rax)
 1241918:	4d 89 fc             	mov    %r15,%r12
 124191b:	4d 89 f5             	mov    %r14,%r13
 124191e:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1241922:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1241926:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 124192d:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 1241931:	0f 85 4c f5 ff ff    	jne    1240e83 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1c63>
 1241937:	4d 89 e6             	mov    %r12,%r14
 124193a:	4c 89 eb             	mov    %r13,%rbx
 124193d:	80 bd 98 de ff ff 00 	cmpb   $0x0,-0x2168(%rbp)
 1241944:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 124194b:	4c 8b 65 88          	mov    -0x78(%rbp),%r12
 124194f:	0f 85 bb f6 ff ff    	jne    1241010 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1df0>
 1241955:	4d 89 f5             	mov    %r14,%r13
 1241958:	49 89 df             	mov    %rbx,%r15
 124195b:	80 bd 08 df ff ff 00 	cmpb   $0x0,-0x20f8(%rbp)
 1241962:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 1241966:	0f 85 6c f8 ff ff    	jne    12411d8 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x1fb8>
 124196c:	4d 89 ec             	mov    %r13,%r12
 124196f:	4c 89 fb             	mov    %r15,%rbx
 1241972:	80 bd 78 df ff ff 00 	cmpb   $0x0,-0x2088(%rbp)
 1241979:	4c 8b ad 78 ff ff ff 	mov    -0x88(%rbp),%r13
 1241980:	0f 85 21 fa ff ff    	jne    12413a7 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2187>
 1241986:	4d 89 e6             	mov    %r12,%r14
 1241989:	49 89 df             	mov    %rbx,%r15
 124198c:	80 bd e8 df ff ff 00 	cmpb   $0x0,-0x2018(%rbp)
 1241993:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 1241997:	0f 85 d5 fb ff ff    	jne    1241572 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2352>
 124199d:	4d 89 f4             	mov    %r14,%r12
 12419a0:	4d 89 fd             	mov    %r15,%r13
 12419a3:	80 bd 58 e0 ff ff 00 	cmpb   $0x0,-0x1fa8(%rbp)
 12419aa:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 12419ae:	0f 85 84 fd ff ff    	jne    1241738 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2518>
 12419b4:	4c 89 e3             	mov    %r12,%rbx
 12419b7:	4d 89 ef             	mov    %r13,%r15
 12419ba:	80 bd 70 fd ff ff 00 	cmpb   $0x0,-0x290(%rbp)
 12419c1:	0f 94 c0             	sete   %al
 12419c4:	80 7d 9a 00          	cmpb   $0x0,-0x66(%rbp)
 12419c8:	0f 94 c1             	sete   %cl
 12419cb:	08 c1                	or     %al,%cl
 12419cd:	4c 8b 65 88          	mov    -0x78(%rbp),%r12
 12419d1:	0f 84 a6 01 00 00    	je     1241b7d <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x295d>
 12419d7:	49 89 de             	mov    %rbx,%r14
 12419da:	4d 89 fd             	mov    %r15,%r13
 12419dd:	80 7d 9b 00          	cmpb   $0x0,-0x65(%rbp)
 12419e1:	0f 84 ad 0a 00 00    	je     1242494 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3274>
 12419e7:	48 8b 85 20 f8 ff ff 	mov    -0x7e0(%rbp),%rax
 12419ee:	48 89 85 70 d6 ff ff 	mov    %rax,-0x2990(%rbp)
 12419f5:	c5 fc 10 85 c0 f7 ff 	vmovups -0x840(%rbp),%ymm0
 12419fc:	ff 
 12419fd:	c5 fc 10 8d e0 f7 ff 	vmovups -0x820(%rbp),%ymm1
 1241a04:	ff 
 1241a05:	c5 fc 10 95 00 f8 ff 	vmovups -0x800(%rbp),%ymm2
 1241a0c:	ff 
 1241a0d:	c5 fc 11 95 50 d6 ff 	vmovups %ymm2,-0x29b0(%rbp)
 1241a14:	ff 
 1241a15:	c5 fc 11 8d 30 d6 ff 	vmovups %ymm1,-0x29d0(%rbp)
 1241a1c:	ff 
 1241a1d:	c5 fc 11 85 10 d6 ff 	vmovups %ymm0,-0x29f0(%rbp)
 1241a24:	ff 
 1241a25:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1241a2c:	ff 
 1241a2d:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1241a34:	ff 
 1241a35:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1241a3c:	ff 
 1241a3d:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1241a44:	ff 
 1241a45:	c5 fc 11 85 e0 ee ff 	vmovups %ymm0,-0x1120(%rbp)
 1241a4c:	ff 
 1241a4d:	c5 fc 11 8d 00 ef ff 	vmovups %ymm1,-0x1100(%rbp)
 1241a54:	ff 
 1241a55:	c5 fc 11 95 20 ef ff 	vmovups %ymm2,-0x10e0(%rbp)
 1241a5c:	ff 
 1241a5d:	c5 fc 11 9d 40 ef ff 	vmovups %ymm3,-0x10c0(%rbp)
 1241a64:	ff 
 1241a65:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1241a6c:	ff 
 1241a6d:	c5 fc 11 85 50 ef ff 	vmovups %ymm0,-0x10b0(%rbp)
 1241a74:	ff 
 1241a75:	c6 85 78 d6 ff ff 01 	movb   $0x1,-0x2988(%rbp)
 1241a7c:	48 8d 85 10 d6 ff ff 	lea    -0x29f0(%rbp),%rax
 1241a83:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 1241a88:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 1241a8f:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1241a94:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1241a98:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1241a9e:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1241aa2:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1241aa7:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1241aac:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1241ab0:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1241ab5:	48 8d 85 e0 ee ff ff 	lea    -0x1120(%rbp),%rax
 1241abc:	48 89 04 24          	mov    %rax,(%rsp)
 1241ac0:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1241ac7:	00 00 
 1241ac9:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1241ad0:	00 00 
 1241ad2:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1241ad6:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1241ada:	4c 89 e1             	mov    %r12,%rcx
 1241add:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 1241ae1:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 1241ae8:	c5 f8 77             	vzeroupper 
 1241aeb:	e8 70 2d 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1241af0:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 1241af4:	66 85 db             	test   %bx,%bx
 1241af7:	0f 85 02 20 00 00    	jne    1243aff <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x48df>
 1241afd:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 1241b01:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 1241b05:	4c 39 eb             	cmp    %r13,%rbx
 1241b08:	0f 83 06 02 00 00    	jae    1241d14 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2af4>
 1241b0e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1241b12:	48 8b 38             	mov    (%rax),%rdi
 1241b15:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241b19:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1241b1d:	4c 89 f6             	mov    %r14,%rsi
 1241b20:	4c 89 ea             	mov    %r13,%rdx
 1241b23:	31 c9                	xor    %ecx,%ecx
 1241b25:	ff 50 18             	call   *0x18(%rax)
 1241b28:	c5 fc 10 85 50 ef ff 	vmovups -0x10b0(%rbp),%ymm0
 1241b2f:	ff 
 1241b30:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1241b37:	ff 
 1241b38:	c5 fc 10 85 e0 ee ff 	vmovups -0x1120(%rbp),%ymm0
 1241b3f:	ff 
 1241b40:	c5 fc 10 8d 00 ef ff 	vmovups -0x1100(%rbp),%ymm1
 1241b47:	ff 
 1241b48:	c5 fc 10 95 20 ef ff 	vmovups -0x10e0(%rbp),%ymm2
 1241b4f:	ff 
 1241b50:	c5 fc 10 9d 40 ef ff 	vmovups -0x10c0(%rbp),%ymm3
 1241b57:	ff 
 1241b58:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1241b5f:	ff 
 1241b60:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1241b67:	ff 
 1241b68:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1241b6f:	ff 
 1241b70:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1241b77:	ff 
 1241b78:	e9 bc 01 00 00       	jmp    1241d39 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2b19>
 1241b7d:	48 8b 85 b0 f7 ff ff 	mov    -0x850(%rbp),%rax
 1241b84:	48 89 85 e0 d6 ff ff 	mov    %rax,-0x2920(%rbp)
 1241b8b:	c5 fc 10 85 50 f7 ff 	vmovups -0x8b0(%rbp),%ymm0
 1241b92:	ff 
 1241b93:	c5 fc 10 8d 70 f7 ff 	vmovups -0x890(%rbp),%ymm1
 1241b9a:	ff 
 1241b9b:	c5 fc 10 95 90 f7 ff 	vmovups -0x870(%rbp),%ymm2
 1241ba2:	ff 
 1241ba3:	c5 fc 11 95 c0 d6 ff 	vmovups %ymm2,-0x2940(%rbp)
 1241baa:	ff 
 1241bab:	c5 fc 11 8d a0 d6 ff 	vmovups %ymm1,-0x2960(%rbp)
 1241bb2:	ff 
 1241bb3:	c5 fc 11 85 80 d6 ff 	vmovups %ymm0,-0x2980(%rbp)
 1241bba:	ff 
 1241bbb:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1241bc2:	ff 
 1241bc3:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1241bca:	ff 
 1241bcb:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1241bd2:	ff 
 1241bd3:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1241bda:	ff 
 1241bdb:	c5 fc 11 85 70 ef ff 	vmovups %ymm0,-0x1090(%rbp)
 1241be2:	ff 
 1241be3:	c5 fc 11 8d 90 ef ff 	vmovups %ymm1,-0x1070(%rbp)
 1241bea:	ff 
 1241beb:	c5 fc 11 95 b0 ef ff 	vmovups %ymm2,-0x1050(%rbp)
 1241bf2:	ff 
 1241bf3:	c5 fc 11 9d d0 ef ff 	vmovups %ymm3,-0x1030(%rbp)
 1241bfa:	ff 
 1241bfb:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1241c02:	ff 
 1241c03:	c5 fc 11 85 e0 ef ff 	vmovups %ymm0,-0x1020(%rbp)
 1241c0a:	ff 
 1241c0b:	c6 85 e8 d6 ff ff 01 	movb   $0x1,-0x2918(%rbp)
 1241c12:	48 8d 85 80 d6 ff ff 	lea    -0x2980(%rbp),%rax
 1241c19:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 1241c1e:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 1241c25:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1241c2a:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1241c2e:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1241c34:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1241c38:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1241c3d:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1241c42:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1241c46:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1241c4b:	48 8d 85 70 ef ff ff 	lea    -0x1090(%rbp),%rax
 1241c52:	48 89 04 24          	mov    %rax,(%rsp)
 1241c56:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1241c5d:	00 00 
 1241c5f:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1241c66:	00 00 
 1241c68:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1241c6c:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1241c70:	4c 89 e1             	mov    %r12,%rcx
 1241c73:	4d 89 f0             	mov    %r14,%r8
 1241c76:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 1241c7d:	c5 f8 77             	vzeroupper 
 1241c80:	e8 db 2b 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1241c85:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 1241c8a:	66 45 85 f6          	test   %r14w,%r14w
 1241c8e:	0f 85 48 25 00 00    	jne    12441dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4fbc>
 1241c94:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 1241c98:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 1241c9c:	4d 39 fd             	cmp    %r15,%r13
 1241c9f:	0f 83 b8 07 00 00    	jae    124245d <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x323d>
 1241ca5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1241ca9:	48 8b 38             	mov    (%rax),%rdi
 1241cac:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241cb0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1241cb4:	48 89 de             	mov    %rbx,%rsi
 1241cb7:	4c 89 fa             	mov    %r15,%rdx
 1241cba:	31 c9                	xor    %ecx,%ecx
 1241cbc:	ff 50 18             	call   *0x18(%rax)
 1241cbf:	c5 fc 10 85 e0 ef ff 	vmovups -0x1020(%rbp),%ymm0
 1241cc6:	ff 
 1241cc7:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1241cce:	ff 
 1241ccf:	c5 fc 10 85 70 ef ff 	vmovups -0x1090(%rbp),%ymm0
 1241cd6:	ff 
 1241cd7:	c5 fc 10 8d 90 ef ff 	vmovups -0x1070(%rbp),%ymm1
 1241cde:	ff 
 1241cdf:	c5 fc 10 95 b0 ef ff 	vmovups -0x1050(%rbp),%ymm2
 1241ce6:	ff 
 1241ce7:	c5 fc 10 9d d0 ef ff 	vmovups -0x1030(%rbp),%ymm3
 1241cee:	ff 
 1241cef:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1241cf6:	ff 
 1241cf7:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1241cfe:	ff 
 1241cff:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1241d06:	ff 
 1241d07:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1241d0e:	ff 
 1241d0f:	e9 6e 07 00 00       	jmp    1242482 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3262>
 1241d14:	48 85 db             	test   %rbx,%rbx
 1241d17:	74 1a                	je     1241d33 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2b13>
 1241d19:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1241d1d:	48 8b 38             	mov    (%rax),%rdi
 1241d20:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241d24:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1241d28:	4c 89 e6             	mov    %r12,%rsi
 1241d2b:	48 89 da             	mov    %rbx,%rdx
 1241d2e:	31 c9                	xor    %ecx,%ecx
 1241d30:	ff 50 18             	call   *0x18(%rax)
 1241d33:	4d 89 f4             	mov    %r14,%r12
 1241d36:	4c 89 eb             	mov    %r13,%rbx
 1241d39:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1241d3d:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1241d41:	80 7d 9c 00          	cmpb   $0x0,-0x64(%rbp)
 1241d45:	4c 8b ad 78 ff ff ff 	mov    -0x88(%rbp),%r13
 1241d4c:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 1241d50:	0f 84 59 07 00 00    	je     12424af <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x328f>
 1241d56:	48 8b 85 90 f8 ff ff 	mov    -0x770(%rbp),%rax
 1241d5d:	48 89 85 00 d6 ff ff 	mov    %rax,-0x2a00(%rbp)
 1241d64:	c5 fc 10 85 30 f8 ff 	vmovups -0x7d0(%rbp),%ymm0
 1241d6b:	ff 
 1241d6c:	c5 fc 10 8d 50 f8 ff 	vmovups -0x7b0(%rbp),%ymm1
 1241d73:	ff 
 1241d74:	c5 fc 10 95 70 f8 ff 	vmovups -0x790(%rbp),%ymm2
 1241d7b:	ff 
 1241d7c:	c5 fc 11 95 e0 d5 ff 	vmovups %ymm2,-0x2a20(%rbp)
 1241d83:	ff 
 1241d84:	c5 fc 11 8d c0 d5 ff 	vmovups %ymm1,-0x2a40(%rbp)
 1241d8b:	ff 
 1241d8c:	c5 fc 11 85 a0 d5 ff 	vmovups %ymm0,-0x2a60(%rbp)
 1241d93:	ff 
 1241d94:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1241d9b:	ff 
 1241d9c:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1241da3:	ff 
 1241da4:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1241dab:	ff 
 1241dac:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1241db3:	ff 
 1241db4:	c5 fc 11 85 50 ee ff 	vmovups %ymm0,-0x11b0(%rbp)
 1241dbb:	ff 
 1241dbc:	c5 fc 11 8d 70 ee ff 	vmovups %ymm1,-0x1190(%rbp)
 1241dc3:	ff 
 1241dc4:	c5 fc 11 95 90 ee ff 	vmovups %ymm2,-0x1170(%rbp)
 1241dcb:	ff 
 1241dcc:	c5 fc 11 9d b0 ee ff 	vmovups %ymm3,-0x1150(%rbp)
 1241dd3:	ff 
 1241dd4:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1241ddb:	ff 
 1241ddc:	c5 fc 11 85 c0 ee ff 	vmovups %ymm0,-0x1140(%rbp)
 1241de3:	ff 
 1241de4:	c6 85 08 d6 ff ff 01 	movb   $0x1,-0x29f8(%rbp)
 1241deb:	48 8d 85 a0 d5 ff ff 	lea    -0x2a60(%rbp),%rax
 1241df2:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 1241df7:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 1241dfe:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1241e03:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1241e07:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1241e0d:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1241e11:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1241e16:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1241e1b:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1241e1f:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1241e24:	48 8d 85 50 ee ff ff 	lea    -0x11b0(%rbp),%rax
 1241e2b:	48 89 04 24          	mov    %rax,(%rsp)
 1241e2f:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1241e36:	00 00 
 1241e38:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1241e3f:	00 00 
 1241e41:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1241e45:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1241e49:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 1241e4d:	4d 89 e9             	mov    %r13,%r9
 1241e50:	c5 f8 77             	vzeroupper 
 1241e53:	e8 08 2a 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1241e58:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 1241e5d:	66 45 85 f6          	test   %r14w,%r14w
 1241e61:	0f 85 93 1d 00 00    	jne    1243bfa <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x49da>
 1241e67:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 1241e6b:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 1241e6f:	49 39 df             	cmp    %rbx,%r15
 1241e72:	73 6c                	jae    1241ee0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2cc0>
 1241e74:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1241e78:	48 8b 38             	mov    (%rax),%rdi
 1241e7b:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241e7f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1241e83:	4c 89 e6             	mov    %r12,%rsi
 1241e86:	48 89 da             	mov    %rbx,%rdx
 1241e89:	31 c9                	xor    %ecx,%ecx
 1241e8b:	ff 50 18             	call   *0x18(%rax)
 1241e8e:	c5 fc 10 85 c0 ee ff 	vmovups -0x1140(%rbp),%ymm0
 1241e95:	ff 
 1241e96:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1241e9d:	ff 
 1241e9e:	c5 fc 10 85 50 ee ff 	vmovups -0x11b0(%rbp),%ymm0
 1241ea5:	ff 
 1241ea6:	c5 fc 10 8d 70 ee ff 	vmovups -0x1190(%rbp),%ymm1
 1241ead:	ff 
 1241eae:	c5 fc 10 95 90 ee ff 	vmovups -0x1170(%rbp),%ymm2
 1241eb5:	ff 
 1241eb6:	c5 fc 10 9d b0 ee ff 	vmovups -0x1150(%rbp),%ymm3
 1241ebd:	ff 
 1241ebe:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1241ec5:	ff 
 1241ec6:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1241ecd:	ff 
 1241ece:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1241ed5:	ff 
 1241ed6:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1241edd:	ff 
 1241ede:	eb 25                	jmp    1241f05 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2ce5>
 1241ee0:	4d 85 ff             	test   %r15,%r15
 1241ee3:	74 1a                	je     1241eff <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2cdf>
 1241ee5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1241ee9:	48 8b 38             	mov    (%rax),%rdi
 1241eec:	48 8b 40 08          	mov    0x8(%rax),%rax
 1241ef0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1241ef4:	4c 89 f6             	mov    %r14,%rsi
 1241ef7:	4c 89 fa             	mov    %r15,%rdx
 1241efa:	31 c9                	xor    %ecx,%ecx
 1241efc:	ff 50 18             	call   *0x18(%rax)
 1241eff:	4d 89 e6             	mov    %r12,%r14
 1241f02:	49 89 df             	mov    %rbx,%r15
 1241f05:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1241f09:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1241f0d:	80 7d 9d 00          	cmpb   $0x0,-0x63(%rbp)
 1241f11:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 1241f15:	0f 84 a8 05 00 00    	je     12424c3 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x32a3>
 1241f1b:	48 8b 85 00 f9 ff ff 	mov    -0x700(%rbp),%rax
 1241f22:	48 89 85 90 d5 ff ff 	mov    %rax,-0x2a70(%rbp)
 1241f29:	c5 fc 10 85 a0 f8 ff 	vmovups -0x760(%rbp),%ymm0
 1241f30:	ff 
 1241f31:	c5 fc 10 8d c0 f8 ff 	vmovups -0x740(%rbp),%ymm1
 1241f38:	ff 
 1241f39:	c5 fc 10 95 e0 f8 ff 	vmovups -0x720(%rbp),%ymm2
 1241f40:	ff 
 1241f41:	c5 fc 11 95 70 d5 ff 	vmovups %ymm2,-0x2a90(%rbp)
 1241f48:	ff 
 1241f49:	c5 fc 11 8d 50 d5 ff 	vmovups %ymm1,-0x2ab0(%rbp)
 1241f50:	ff 
 1241f51:	c5 fc 11 85 30 d5 ff 	vmovups %ymm0,-0x2ad0(%rbp)
 1241f58:	ff 
 1241f59:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1241f60:	ff 
 1241f61:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1241f68:	ff 
 1241f69:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1241f70:	ff 
 1241f71:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1241f78:	ff 
 1241f79:	c5 fc 11 85 c0 ed ff 	vmovups %ymm0,-0x1240(%rbp)
 1241f80:	ff 
 1241f81:	c5 fc 11 8d e0 ed ff 	vmovups %ymm1,-0x1220(%rbp)
 1241f88:	ff 
 1241f89:	c5 fc 11 95 00 ee ff 	vmovups %ymm2,-0x1200(%rbp)
 1241f90:	ff 
 1241f91:	c5 fc 11 9d 20 ee ff 	vmovups %ymm3,-0x11e0(%rbp)
 1241f98:	ff 
 1241f99:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1241fa0:	ff 
 1241fa1:	c5 fc 11 85 30 ee ff 	vmovups %ymm0,-0x11d0(%rbp)
 1241fa8:	ff 
 1241fa9:	c6 85 98 d5 ff ff 01 	movb   $0x1,-0x2a68(%rbp)
 1241fb0:	48 8d 85 30 d5 ff ff 	lea    -0x2ad0(%rbp),%rax
 1241fb7:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 1241fbc:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 1241fc3:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1241fc8:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1241fcc:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1241fd2:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1241fd6:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1241fdb:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1241fe0:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1241fe4:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1241fe9:	48 8d 85 c0 ed ff ff 	lea    -0x1240(%rbp),%rax
 1241ff0:	48 89 04 24          	mov    %rax,(%rsp)
 1241ff4:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1241ffb:	00 00 
 1241ffd:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1242004:	00 00 
 1242006:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 124200a:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124200e:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 1242012:	4d 89 e9             	mov    %r13,%r9
 1242015:	c5 f8 77             	vzeroupper 
 1242018:	e8 43 28 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 124201d:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 1242021:	66 85 db             	test   %bx,%bx
 1242024:	0f 85 cb 1c 00 00    	jne    1243cf5 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4ad5>
 124202a:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 124202e:	48 8b 5d a8          	mov    -0x58(%rbp),%rbx
 1242032:	4c 39 fb             	cmp    %r15,%rbx
 1242035:	73 6c                	jae    12420a3 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2e83>
 1242037:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 124203b:	48 8b 38             	mov    (%rax),%rdi
 124203e:	48 8b 40 08          	mov    0x8(%rax),%rax
 1242042:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242046:	4c 89 f6             	mov    %r14,%rsi
 1242049:	4c 89 fa             	mov    %r15,%rdx
 124204c:	31 c9                	xor    %ecx,%ecx
 124204e:	ff 50 18             	call   *0x18(%rax)
 1242051:	c5 fc 10 85 30 ee ff 	vmovups -0x11d0(%rbp),%ymm0
 1242058:	ff 
 1242059:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1242060:	ff 
 1242061:	c5 fc 10 85 c0 ed ff 	vmovups -0x1240(%rbp),%ymm0
 1242068:	ff 
 1242069:	c5 fc 10 8d e0 ed ff 	vmovups -0x1220(%rbp),%ymm1
 1242070:	ff 
 1242071:	c5 fc 10 95 00 ee ff 	vmovups -0x1200(%rbp),%ymm2
 1242078:	ff 
 1242079:	c5 fc 10 9d 20 ee ff 	vmovups -0x11e0(%rbp),%ymm3
 1242080:	ff 
 1242081:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1242088:	ff 
 1242089:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1242090:	ff 
 1242091:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1242098:	ff 
 1242099:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 12420a0:	ff 
 12420a1:	eb 25                	jmp    12420c8 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2ea8>
 12420a3:	48 85 db             	test   %rbx,%rbx
 12420a6:	74 1a                	je     12420c2 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2ea2>
 12420a8:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12420ac:	48 8b 38             	mov    (%rax),%rdi
 12420af:	48 8b 40 08          	mov    0x8(%rax),%rax
 12420b3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12420b7:	4c 89 e6             	mov    %r12,%rsi
 12420ba:	48 89 da             	mov    %rbx,%rdx
 12420bd:	31 c9                	xor    %ecx,%ecx
 12420bf:	ff 50 18             	call   *0x18(%rax)
 12420c2:	4d 89 f4             	mov    %r14,%r12
 12420c5:	4c 89 fb             	mov    %r15,%rbx
 12420c8:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 12420cc:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 12420d0:	80 7d 9e 00          	cmpb   $0x0,-0x62(%rbp)
 12420d4:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 12420d8:	0f 84 f9 03 00 00    	je     12424d7 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x32b7>
 12420de:	48 8b 85 70 f9 ff ff 	mov    -0x690(%rbp),%rax
 12420e5:	48 89 85 20 d5 ff ff 	mov    %rax,-0x2ae0(%rbp)
 12420ec:	c5 fc 10 85 10 f9 ff 	vmovups -0x6f0(%rbp),%ymm0
 12420f3:	ff 
 12420f4:	c5 fc 10 8d 30 f9 ff 	vmovups -0x6d0(%rbp),%ymm1
 12420fb:	ff 
 12420fc:	c5 fc 10 95 50 f9 ff 	vmovups -0x6b0(%rbp),%ymm2
 1242103:	ff 
 1242104:	c5 fc 11 95 00 d5 ff 	vmovups %ymm2,-0x2b00(%rbp)
 124210b:	ff 
 124210c:	c5 fc 11 8d e0 d4 ff 	vmovups %ymm1,-0x2b20(%rbp)
 1242113:	ff 
 1242114:	c5 fc 11 85 c0 d4 ff 	vmovups %ymm0,-0x2b40(%rbp)
 124211b:	ff 
 124211c:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1242123:	ff 
 1242124:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124212b:	ff 
 124212c:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1242133:	ff 
 1242134:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124213b:	ff 
 124213c:	c5 fc 11 85 30 ed ff 	vmovups %ymm0,-0x12d0(%rbp)
 1242143:	ff 
 1242144:	c5 fc 11 8d 50 ed ff 	vmovups %ymm1,-0x12b0(%rbp)
 124214b:	ff 
 124214c:	c5 fc 11 95 70 ed ff 	vmovups %ymm2,-0x1290(%rbp)
 1242153:	ff 
 1242154:	c5 fc 11 9d 90 ed ff 	vmovups %ymm3,-0x1270(%rbp)
 124215b:	ff 
 124215c:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1242163:	ff 
 1242164:	c5 fc 11 85 a0 ed ff 	vmovups %ymm0,-0x1260(%rbp)
 124216b:	ff 
 124216c:	c6 85 28 d5 ff ff 01 	movb   $0x1,-0x2ad8(%rbp)
 1242173:	48 8d 85 c0 d4 ff ff 	lea    -0x2b40(%rbp),%rax
 124217a:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 124217f:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 1242186:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 124218b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 124218f:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1242195:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 1242199:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 124219e:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 12421a3:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12421a7:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 12421ac:	48 8d 85 30 ed ff ff 	lea    -0x12d0(%rbp),%rax
 12421b3:	48 89 04 24          	mov    %rax,(%rsp)
 12421b7:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 12421be:	00 00 
 12421c0:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 12421c7:	00 00 
 12421c9:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 12421cd:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12421d1:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 12421d5:	4d 89 e9             	mov    %r13,%r9
 12421d8:	c5 f8 77             	vzeroupper 
 12421db:	e8 80 26 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 12421e0:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 12421e5:	66 45 85 f6          	test   %r14w,%r14w
 12421e9:	0f 85 01 1c 00 00    	jne    1243df0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4bd0>
 12421ef:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 12421f3:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 12421f7:	49 39 df             	cmp    %rbx,%r15
 12421fa:	73 6c                	jae    1242268 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3048>
 12421fc:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242200:	48 8b 38             	mov    (%rax),%rdi
 1242203:	48 8b 40 08          	mov    0x8(%rax),%rax
 1242207:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124220b:	4c 89 e6             	mov    %r12,%rsi
 124220e:	48 89 da             	mov    %rbx,%rdx
 1242211:	31 c9                	xor    %ecx,%ecx
 1242213:	ff 50 18             	call   *0x18(%rax)
 1242216:	c5 fc 10 85 a0 ed ff 	vmovups -0x1260(%rbp),%ymm0
 124221d:	ff 
 124221e:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1242225:	ff 
 1242226:	c5 fc 10 85 30 ed ff 	vmovups -0x12d0(%rbp),%ymm0
 124222d:	ff 
 124222e:	c5 fc 10 8d 50 ed ff 	vmovups -0x12b0(%rbp),%ymm1
 1242235:	ff 
 1242236:	c5 fc 10 95 70 ed ff 	vmovups -0x1290(%rbp),%ymm2
 124223d:	ff 
 124223e:	c5 fc 10 9d 90 ed ff 	vmovups -0x1270(%rbp),%ymm3
 1242245:	ff 
 1242246:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 124224d:	ff 
 124224e:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1242255:	ff 
 1242256:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 124225d:	ff 
 124225e:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1242265:	ff 
 1242266:	eb 25                	jmp    124228d <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x306d>
 1242268:	4d 85 ff             	test   %r15,%r15
 124226b:	74 1a                	je     1242287 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3067>
 124226d:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242271:	48 8b 38             	mov    (%rax),%rdi
 1242274:	48 8b 40 08          	mov    0x8(%rax),%rax
 1242278:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124227c:	4c 89 f6             	mov    %r14,%rsi
 124227f:	4c 89 fa             	mov    %r15,%rdx
 1242282:	31 c9                	xor    %ecx,%ecx
 1242284:	ff 50 18             	call   *0x18(%rax)
 1242287:	4d 89 e6             	mov    %r12,%r14
 124228a:	49 89 df             	mov    %rbx,%r15
 124228d:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1242291:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1242295:	80 7d 9f 00          	cmpb   $0x0,-0x61(%rbp)
 1242299:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 124229d:	0f 84 48 02 00 00    	je     12424eb <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x32cb>
 12422a3:	48 8b 85 e0 f9 ff ff 	mov    -0x620(%rbp),%rax
 12422aa:	48 89 85 b0 d4 ff ff 	mov    %rax,-0x2b50(%rbp)
 12422b1:	c5 fc 10 85 80 f9 ff 	vmovups -0x680(%rbp),%ymm0
 12422b8:	ff 
 12422b9:	c5 fc 10 8d a0 f9 ff 	vmovups -0x660(%rbp),%ymm1
 12422c0:	ff 
 12422c1:	c5 fc 10 95 c0 f9 ff 	vmovups -0x640(%rbp),%ymm2
 12422c8:	ff 
 12422c9:	c5 fc 11 95 90 d4 ff 	vmovups %ymm2,-0x2b70(%rbp)
 12422d0:	ff 
 12422d1:	c5 fc 11 8d 70 d4 ff 	vmovups %ymm1,-0x2b90(%rbp)
 12422d8:	ff 
 12422d9:	c5 fc 11 85 50 d4 ff 	vmovups %ymm0,-0x2bb0(%rbp)
 12422e0:	ff 
 12422e1:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 12422e8:	ff 
 12422e9:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 12422f0:	ff 
 12422f1:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 12422f8:	ff 
 12422f9:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1242300:	ff 
 1242301:	c5 fc 11 85 a0 ec ff 	vmovups %ymm0,-0x1360(%rbp)
 1242308:	ff 
 1242309:	c5 fc 11 8d c0 ec ff 	vmovups %ymm1,-0x1340(%rbp)
 1242310:	ff 
 1242311:	c5 fc 11 95 e0 ec ff 	vmovups %ymm2,-0x1320(%rbp)
 1242318:	ff 
 1242319:	c5 fc 11 9d 00 ed ff 	vmovups %ymm3,-0x1300(%rbp)
 1242320:	ff 
 1242321:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1242328:	ff 
 1242329:	c5 fc 11 85 10 ed ff 	vmovups %ymm0,-0x12f0(%rbp)
 1242330:	ff 
 1242331:	c6 85 b8 d4 ff ff 01 	movb   $0x1,-0x2b48(%rbp)
 1242338:	48 8d 85 50 d4 ff ff 	lea    -0x2bb0(%rbp),%rax
 124233f:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 1242344:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 124234b:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1242350:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1242354:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 124235a:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 124235e:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 1242363:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1242368:	48 8b 45 18          	mov    0x18(%rbp),%rax
 124236c:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1242371:	48 8d 85 a0 ec ff ff 	lea    -0x1360(%rbp),%rax
 1242378:	48 89 04 24          	mov    %rax,(%rsp)
 124237c:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 1242383:	00 00 
 1242385:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 124238c:	00 00 
 124238e:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1242392:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1242396:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 124239a:	4d 89 e9             	mov    %r13,%r9
 124239d:	c5 f8 77             	vzeroupper 
 12423a0:	e8 bb 24 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 12423a5:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 12423a9:	66 85 db             	test   %bx,%bx
 12423ac:	0f 85 39 1b 00 00    	jne    1243eeb <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4ccb>
 12423b2:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 12423b6:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 12423ba:	4d 39 fd             	cmp    %r15,%r13
 12423bd:	73 6c                	jae    124242b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x320b>
 12423bf:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12423c3:	48 8b 38             	mov    (%rax),%rdi
 12423c6:	48 8b 40 08          	mov    0x8(%rax),%rax
 12423ca:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12423ce:	4c 89 f6             	mov    %r14,%rsi
 12423d1:	4c 89 fa             	mov    %r15,%rdx
 12423d4:	31 c9                	xor    %ecx,%ecx
 12423d6:	ff 50 18             	call   *0x18(%rax)
 12423d9:	c5 fc 10 85 10 ed ff 	vmovups -0x12f0(%rbp),%ymm0
 12423e0:	ff 
 12423e1:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 12423e8:	ff 
 12423e9:	c5 fc 10 85 a0 ec ff 	vmovups -0x1360(%rbp),%ymm0
 12423f0:	ff 
 12423f1:	c5 fc 10 8d c0 ec ff 	vmovups -0x1340(%rbp),%ymm1
 12423f8:	ff 
 12423f9:	c5 fc 10 95 e0 ec ff 	vmovups -0x1320(%rbp),%ymm2
 1242400:	ff 
 1242401:	c5 fc 10 9d 00 ed ff 	vmovups -0x1300(%rbp),%ymm3
 1242408:	ff 
 1242409:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1242410:	ff 
 1242411:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1242418:	ff 
 1242419:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1242420:	ff 
 1242421:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1242428:	ff 
 1242429:	eb 25                	jmp    1242450 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3230>
 124242b:	4d 85 ed             	test   %r13,%r13
 124242e:	74 1a                	je     124244a <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x322a>
 1242430:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242434:	48 8b 38             	mov    (%rax),%rdi
 1242437:	48 8b 40 08          	mov    0x8(%rax),%rax
 124243b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124243f:	4c 89 e6             	mov    %r12,%rsi
 1242442:	4c 89 ea             	mov    %r13,%rdx
 1242445:	31 c9                	xor    %ecx,%ecx
 1242447:	ff 50 18             	call   *0x18(%rax)
 124244a:	4d 89 f4             	mov    %r14,%r12
 124244d:	4d 89 fd             	mov    %r15,%r13
 1242450:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1242454:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1242458:	e9 94 00 00 00       	jmp    12424f1 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x32d1>
 124245d:	4d 85 ed             	test   %r13,%r13
 1242460:	74 1a                	je     124247c <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x325c>
 1242462:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242466:	48 8b 38             	mov    (%rax),%rdi
 1242469:	48 8b 40 08          	mov    0x8(%rax),%rax
 124246d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242471:	4c 89 f6             	mov    %r14,%rsi
 1242474:	4c 89 ea             	mov    %r13,%rdx
 1242477:	31 c9                	xor    %ecx,%ecx
 1242479:	ff 50 18             	call   *0x18(%rax)
 124247c:	49 89 de             	mov    %rbx,%r14
 124247f:	4d 89 fd             	mov    %r15,%r13
 1242482:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1242486:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 124248a:	80 7d 9b 00          	cmpb   $0x0,-0x65(%rbp)
 124248e:	0f 85 53 f5 ff ff    	jne    12419e7 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x27c7>
 1242494:	4d 89 f4             	mov    %r14,%r12
 1242497:	4c 89 eb             	mov    %r13,%rbx
 124249a:	80 7d 9c 00          	cmpb   $0x0,-0x64(%rbp)
 124249e:	4c 8b ad 78 ff ff ff 	mov    -0x88(%rbp),%r13
 12424a5:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 12424a9:	0f 85 a7 f8 ff ff    	jne    1241d56 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2b36>
 12424af:	4d 89 e6             	mov    %r12,%r14
 12424b2:	49 89 df             	mov    %rbx,%r15
 12424b5:	80 7d 9d 00          	cmpb   $0x0,-0x63(%rbp)
 12424b9:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 12424bd:	0f 85 58 fa ff ff    	jne    1241f1b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2cfb>
 12424c3:	4d 89 f4             	mov    %r14,%r12
 12424c6:	4c 89 fb             	mov    %r15,%rbx
 12424c9:	80 7d 9e 00          	cmpb   $0x0,-0x62(%rbp)
 12424cd:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 12424d1:	0f 85 07 fc ff ff    	jne    12420de <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x2ebe>
 12424d7:	4d 89 e6             	mov    %r12,%r14
 12424da:	49 89 df             	mov    %rbx,%r15
 12424dd:	80 7d 9f 00          	cmpb   $0x0,-0x61(%rbp)
 12424e1:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 12424e5:	0f 85 b8 fd ff ff    	jne    12422a3 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3083>
 12424eb:	4d 89 f4             	mov    %r14,%r12
 12424ee:	4d 89 fd             	mov    %r15,%r13
 12424f1:	44 0f b6 75 c6       	movzbl -0x3a(%rbp),%r14d
 12424f6:	41 80 f6 01          	xor    $0x1,%r14b
 12424fa:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1242501:	0f 94 c0             	sete   %al
 1242504:	41 84 c6             	test   %al,%r14b
 1242507:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 124250b:	0f 85 51 01 00 00    	jne    1242662 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3442>
 1242511:	80 bd 90 e0 ff ff 00 	cmpb   $0x0,-0x1f70(%rbp)
 1242518:	0f 84 44 01 00 00    	je     1242662 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3442>
 124251e:	48 8d 85 60 e0 ff ff 	lea    -0x1fa0(%rbp),%rax
 1242525:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 124252c:	ff 
 124252d:	c5 fc 11 85 80 ec ff 	vmovups %ymm0,-0x1380(%rbp)
 1242534:	ff 
 1242535:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124253c:	ff 
 124253d:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1242544:	ff 
 1242545:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 124254c:	ff 
 124254d:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1242554:	ff 
 1242555:	c5 fc 11 9d 70 ec ff 	vmovups %ymm3,-0x1390(%rbp)
 124255c:	ff 
 124255d:	c5 fc 11 95 50 ec ff 	vmovups %ymm2,-0x13b0(%rbp)
 1242564:	ff 
 1242565:	c5 fc 11 8d 30 ec ff 	vmovups %ymm1,-0x13d0(%rbp)
 124256c:	ff 
 124256d:	c5 fc 11 85 10 ec ff 	vmovups %ymm0,-0x13f0(%rbp)
 1242574:	ff 
 1242575:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 124257a:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 124257e:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1242584:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 1242589:	48 8b 45 18          	mov    0x18(%rbp),%rax
 124258d:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1242592:	48 8d 85 10 ec ff ff 	lea    -0x13f0(%rbp),%rax
 1242599:	48 89 04 24          	mov    %rax,(%rsp)
 124259d:	48 c7 44 24 48 00 00 	movq   $0x0,0x48(%rsp)
 12425a4:	00 00 
 12425a6:	48 c7 44 24 40 68 ae 	movq   $0x103ae68,0x40(%rsp)
 12425ad:	03 01 
 12425af:	48 c7 44 24 30 f8 ad 	movq   $0x103adf8,0x30(%rsp)
 12425b6:	03 01 
 12425b8:	48 c7 44 24 18 88 ad 	movq   $0x103ad88,0x18(%rsp)
 12425bf:	03 01 
 12425c1:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 12425c5:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12425c9:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 12425cd:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 12425d4:	c5 f8 77             	vzeroupper 
 12425d7:	e8 84 22 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 12425dc:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 12425e0:	66 85 db             	test   %bx,%bx
 12425e3:	0f 85 ee 1c 00 00    	jne    12442d7 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x50b7>
 12425e9:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 12425ed:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 12425f1:	4d 39 ef             	cmp    %r13,%r15
 12425f4:	73 74                	jae    124266a <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x344a>
 12425f6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12425fa:	48 8b 38             	mov    (%rax),%rdi
 12425fd:	48 8b 40 08          	mov    0x8(%rax),%rax
 1242601:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242605:	4c 89 e6             	mov    %r12,%rsi
 1242608:	4c 89 ea             	mov    %r13,%rdx
 124260b:	31 c9                	xor    %ecx,%ecx
 124260d:	ff 50 18             	call   *0x18(%rax)
 1242610:	c5 fc 10 85 80 ec ff 	vmovups -0x1380(%rbp),%ymm0
 1242617:	ff 
 1242618:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 124261f:	ff 
 1242620:	c5 fc 10 85 10 ec ff 	vmovups -0x13f0(%rbp),%ymm0
 1242627:	ff 
 1242628:	c5 fc 10 8d 30 ec ff 	vmovups -0x13d0(%rbp),%ymm1
 124262f:	ff 
 1242630:	c5 fc 10 95 50 ec ff 	vmovups -0x13b0(%rbp),%ymm2
 1242637:	ff 
 1242638:	c5 fc 10 9d 70 ec ff 	vmovups -0x1390(%rbp),%ymm3
 124263f:	ff 
 1242640:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 1242647:	ff 
 1242648:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 124264f:	ff 
 1242650:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 1242657:	ff 
 1242658:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 124265f:	ff 
 1242660:	eb 2d                	jmp    124268f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x346f>
 1242662:	4c 89 e3             	mov    %r12,%rbx
 1242665:	4d 89 ef             	mov    %r13,%r15
 1242668:	eb 31                	jmp    124269b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x347b>
 124266a:	4d 85 ff             	test   %r15,%r15
 124266d:	74 1a                	je     1242689 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3469>
 124266f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242673:	48 8b 38             	mov    (%rax),%rdi
 1242676:	48 8b 40 08          	mov    0x8(%rax),%rax
 124267a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124267e:	48 89 de             	mov    %rbx,%rsi
 1242681:	4c 89 fa             	mov    %r15,%rdx
 1242684:	31 c9                	xor    %ecx,%ecx
 1242686:	ff 50 18             	call   *0x18(%rax)
 1242689:	4c 89 e3             	mov    %r12,%rbx
 124268c:	4d 89 ef             	mov    %r13,%r15
 124268f:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1242693:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 1242697:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 124269b:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12426a2:	0f 94 c0             	sete   %al
 12426a5:	41 20 c6             	and    %al,%r14b
 12426a8:	80 bd 90 e0 ff ff 00 	cmpb   $0x0,-0x1f70(%rbp)
 12426af:	0f 94 c0             	sete   %al
 12426b2:	41 84 c6             	test   %al,%r14b
 12426b5:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 12426bc:	4c 8b 65 88          	mov    -0x78(%rbp),%r12
 12426c0:	0f 85 4f 01 00 00    	jne    1242815 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x35f5>
 12426c6:	80 bd d8 e3 ff ff 00 	cmpb   $0x0,-0x1c28(%rbp)
 12426cd:	0f 84 42 01 00 00    	je     1242815 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x35f5>
 12426d3:	48 8d 85 a8 e3 ff ff 	lea    -0x1c58(%rbp),%rax
 12426da:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 12426e1:	ff 
 12426e2:	c5 fc 11 85 f0 eb ff 	vmovups %ymm0,-0x1410(%rbp)
 12426e9:	ff 
 12426ea:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 12426f1:	ff 
 12426f2:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 12426f9:	ff 
 12426fa:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1242701:	ff 
 1242702:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1242709:	ff 
 124270a:	c5 fc 11 9d e0 eb ff 	vmovups %ymm3,-0x1420(%rbp)
 1242711:	ff 
 1242712:	c5 fc 11 95 c0 eb ff 	vmovups %ymm2,-0x1440(%rbp)
 1242719:	ff 
 124271a:	c5 fc 11 8d a0 eb ff 	vmovups %ymm1,-0x1460(%rbp)
 1242721:	ff 
 1242722:	c5 fc 11 85 80 eb ff 	vmovups %ymm0,-0x1480(%rbp)
 1242729:	ff 
 124272a:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 124272f:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1242733:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 1242739:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 124273e:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1242742:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 1242747:	48 8d 85 80 eb ff ff 	lea    -0x1480(%rbp),%rax
 124274e:	48 89 04 24          	mov    %rax,(%rsp)
 1242752:	48 c7 44 24 40 68 ae 	movq   $0x103ae68,0x40(%rsp)
 1242759:	03 01 
 124275b:	48 c7 44 24 38 00 00 	movq   $0x0,0x38(%rsp)
 1242762:	00 00 
 1242764:	48 c7 44 24 30 f8 ad 	movq   $0x103adf8,0x30(%rsp)
 124276b:	03 01 
 124276d:	48 c7 44 24 18 88 ad 	movq   $0x103ad88,0x18(%rsp)
 1242774:	03 01 
 1242776:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 124277a:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124277e:	4c 89 e1             	mov    %r12,%rcx
 1242781:	c5 f8 77             	vzeroupper 
 1242784:	e8 d7 20 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 1242789:	44 0f b7 75 b0       	movzwl -0x50(%rbp),%r14d
 124278e:	66 45 85 f6          	test   %r14w,%r14w
 1242792:	0f 85 3a 1c 00 00    	jne    12443d2 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x51b2>
 1242798:	4c 8b 75 a0          	mov    -0x60(%rbp),%r14
 124279c:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 12427a0:	4d 39 fd             	cmp    %r15,%r13
 12427a3:	0f 83 87 00 00 00    	jae    1242830 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3610>
 12427a9:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12427ad:	48 8b 38             	mov    (%rax),%rdi
 12427b0:	48 8b 40 08          	mov    0x8(%rax),%rax
 12427b4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12427b8:	48 89 de             	mov    %rbx,%rsi
 12427bb:	4c 89 fa             	mov    %r15,%rdx
 12427be:	31 c9                	xor    %ecx,%ecx
 12427c0:	ff 50 18             	call   *0x18(%rax)
 12427c3:	c5 fc 10 85 f0 eb ff 	vmovups -0x1410(%rbp),%ymm0
 12427ca:	ff 
 12427cb:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 12427d2:	ff 
 12427d3:	c5 fc 10 85 80 eb ff 	vmovups -0x1480(%rbp),%ymm0
 12427da:	ff 
 12427db:	c5 fc 10 8d a0 eb ff 	vmovups -0x1460(%rbp),%ymm1
 12427e2:	ff 
 12427e3:	c5 fc 10 95 c0 eb ff 	vmovups -0x1440(%rbp),%ymm2
 12427ea:	ff 
 12427eb:	c5 fc 10 9d e0 eb ff 	vmovups -0x1420(%rbp),%ymm3
 12427f2:	ff 
 12427f3:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 12427fa:	ff 
 12427fb:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 1242802:	ff 
 1242803:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 124280a:	ff 
 124280b:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 1242812:	ff 
 1242813:	eb 40                	jmp    1242855 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3635>
 1242815:	49 89 de             	mov    %rbx,%r14
 1242818:	4d 89 fd             	mov    %r15,%r13
 124281b:	48 8d 8d 60 e0 ff ff 	lea    -0x1fa0(%rbp),%rcx
 1242822:	80 bd 90 e0 ff ff 00 	cmpb   $0x0,-0x1f70(%rbp)
 1242829:	75 46                	jne    1242871 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3651>
 124282b:	e9 31 04 00 00       	jmp    1242c61 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3a41>
 1242830:	4d 85 ed             	test   %r13,%r13
 1242833:	74 1a                	je     124284f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x362f>
 1242835:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242839:	48 8b 38             	mov    (%rax),%rdi
 124283c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1242840:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242844:	4c 89 f6             	mov    %r14,%rsi
 1242847:	4c 89 ea             	mov    %r13,%rdx
 124284a:	31 c9                	xor    %ecx,%ecx
 124284c:	ff 50 18             	call   *0x18(%rax)
 124284f:	49 89 de             	mov    %rbx,%r14
 1242852:	4d 89 fd             	mov    %r15,%r13
 1242855:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1242859:	48 8b 75 20          	mov    0x20(%rbp),%rsi
 124285d:	48 8d 8d 60 e0 ff ff 	lea    -0x1fa0(%rbp),%rcx
 1242864:	80 bd 90 e0 ff ff 00 	cmpb   $0x0,-0x1f70(%rbp)
 124286b:	0f 84 f0 03 00 00    	je     1242c61 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3a41>
 1242871:	80 bd d8 e3 ff ff 00 	cmpb   $0x0,-0x1c28(%rbp)
 1242878:	0f 84 e3 03 00 00    	je     1242c61 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3a41>
 124287e:	48 8d 85 a8 e3 ff ff 	lea    -0x1c58(%rbp),%rax
 1242885:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 124288c:	ff 
 124288d:	c5 fc 11 85 60 eb ff 	vmovups %ymm0,-0x14a0(%rbp)
 1242894:	ff 
 1242895:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124289c:	ff 
 124289d:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 12428a4:	ff 
 12428a5:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 12428ac:	ff 
 12428ad:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 12428b4:	ff 
 12428b5:	c5 fc 11 9d 50 eb ff 	vmovups %ymm3,-0x14b0(%rbp)
 12428bc:	ff 
 12428bd:	c5 fc 11 95 30 eb ff 	vmovups %ymm2,-0x14d0(%rbp)
 12428c4:	ff 
 12428c5:	c5 fc 11 8d 10 eb ff 	vmovups %ymm1,-0x14f0(%rbp)
 12428cc:	ff 
 12428cd:	c5 fc 11 85 f0 ea ff 	vmovups %ymm0,-0x1510(%rbp)
 12428d4:	ff 
 12428d5:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 12428da:	48 89 4c 24 38       	mov    %rcx,0x38(%rsp)
 12428df:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 12428e3:	c5 f8 11 44 24 20    	vmovups %xmm0,0x20(%rsp)
 12428e9:	48 89 74 24 10       	mov    %rsi,0x10(%rsp)
 12428ee:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12428f2:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 12428f7:	48 8d 85 f0 ea ff ff 	lea    -0x1510(%rbp),%rax
 12428fe:	48 89 04 24          	mov    %rax,(%rsp)
 1242902:	48 c7 44 24 40 68 ae 	movq   $0x103ae68,0x40(%rsp)
 1242909:	03 01 
 124290b:	48 c7 44 24 30 f8 ad 	movq   $0x103adf8,0x30(%rsp)
 1242912:	03 01 
 1242914:	48 c7 44 24 18 88 ad 	movq   $0x103ad88,0x18(%rsp)
 124291b:	03 01 
 124291d:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 1242921:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1242925:	4c 89 e1             	mov    %r12,%rcx
 1242928:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 124292c:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 1242933:	c5 f8 77             	vzeroupper 
 1242936:	e8 25 1f 00 00       	call   1244860 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_205684>
 124293b:	0f b7 5d b0          	movzwl -0x50(%rbp),%ebx
 124293f:	66 85 db             	test   %bx,%bx
 1242942:	0f 85 96 1b 00 00    	jne    12444de <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52be>
 1242948:	48 8b 5d a0          	mov    -0x60(%rbp),%rbx
 124294c:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 1242950:	4d 39 ef             	cmp    %r13,%r15
 1242953:	0f 83 e9 02 00 00    	jae    1242c42 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3a22>
 1242959:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 124295d:	48 8b 38             	mov    (%rax),%rdi
 1242960:	48 8b 40 08          	mov    0x8(%rax),%rax
 1242964:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242968:	4c 89 f6             	mov    %r14,%rsi
 124296b:	4c 89 ea             	mov    %r13,%rdx
 124296e:	31 c9                	xor    %ecx,%ecx
 1242970:	ff 50 18             	call   *0x18(%rax)
 1242973:	c5 fc 10 85 60 eb ff 	vmovups -0x14a0(%rbp),%ymm0
 124297a:	ff 
 124297b:	c5 fc 11 85 00 fe ff 	vmovups %ymm0,-0x200(%rbp)
 1242982:	ff 
 1242983:	c5 fc 10 85 f0 ea ff 	vmovups -0x1510(%rbp),%ymm0
 124298a:	ff 
 124298b:	c5 fc 10 8d 10 eb ff 	vmovups -0x14f0(%rbp),%ymm1
 1242992:	ff 
 1242993:	c5 fc 10 95 30 eb ff 	vmovups -0x14d0(%rbp),%ymm2
 124299a:	ff 
 124299b:	c5 fc 10 9d 50 eb ff 	vmovups -0x14b0(%rbp),%ymm3
 12429a2:	ff 
 12429a3:	c5 fc 11 9d f0 fd ff 	vmovups %ymm3,-0x210(%rbp)
 12429aa:	ff 
 12429ab:	c5 fc 11 95 d0 fd ff 	vmovups %ymm2,-0x230(%rbp)
 12429b2:	ff 
 12429b3:	c5 fc 11 8d b0 fd ff 	vmovups %ymm1,-0x250(%rbp)
 12429ba:	ff 
 12429bb:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 12429c2:	ff 
 12429c3:	4c 3b bd 68 fd ff ff 	cmp    -0x298(%rbp),%r15
 12429ca:	0f 82 a4 02 00 00    	jb     1242c74 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3a54>
 12429d0:	4d 85 ff             	test   %r15,%r15
 12429d3:	74 1d                	je     12429f2 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x37d2>
 12429d5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12429d9:	48 8b 38             	mov    (%rax),%rdi
 12429dc:	48 8b 40 08          	mov    0x8(%rax),%rax
 12429e0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12429e4:	48 89 de             	mov    %rbx,%rsi
 12429e7:	4c 89 fa             	mov    %r15,%rdx
 12429ea:	31 c9                	xor    %ecx,%ecx
 12429ec:	c5 f8 77             	vzeroupper 
 12429ef:	ff 50 18             	call   *0x18(%rax)
 12429f2:	80 bd 90 e0 ff ff 00 	cmpb   $0x0,-0x1f70(%rbp)
 12429f9:	74 60                	je     1242a5b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x383b>
 12429fb:	48 8b 95 68 e0 ff ff 	mov    -0x1f98(%rbp),%rdx
 1242a02:	48 8b 9d 70 e0 ff ff 	mov    -0x1f90(%rbp),%rbx
 1242a09:	4c 8b b5 78 e0 ff ff 	mov    -0x1f88(%rbp),%r14
 1242a10:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242a14:	4c 8b 38             	mov    (%rax),%r15
 1242a17:	4c 8b 60 08          	mov    0x8(%rax),%r12
 1242a1b:	48 85 d2             	test   %rdx,%rdx
 1242a1e:	74 1f                	je     1242a3f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x381f>
 1242a20:	48 8b b5 60 e0 ff ff 	mov    -0x1fa0(%rbp),%rsi
 1242a27:	48 c1 e2 02          	shl    $0x2,%rdx
 1242a2b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242a2f:	4c 89 ff             	mov    %r15,%rdi
 1242a32:	b9 02 00 00 00       	mov    $0x2,%ecx
 1242a37:	c5 f8 77             	vzeroupper 
 1242a3a:	41 ff 54 24 18       	call   *0x18(%r12)
 1242a3f:	4d 85 f6             	test   %r14,%r14
 1242a42:	74 17                	je     1242a5b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x383b>
 1242a44:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242a48:	4c 89 ff             	mov    %r15,%rdi
 1242a4b:	48 89 de             	mov    %rbx,%rsi
 1242a4e:	4c 89 f2             	mov    %r14,%rdx
 1242a51:	31 c9                	xor    %ecx,%ecx
 1242a53:	c5 f8 77             	vzeroupper 
 1242a56:	41 ff 54 24 18       	call   *0x18(%r12)
 1242a5b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1242a5f:	48 8d 85 60 e0 ff ff 	lea    -0x1fa0(%rbp),%rax
 1242a66:	c5 fc 11 40 18       	vmovups %ymm0,0x18(%rax)
 1242a6b:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1242a6f:	4c 8d a5 a8 e3 ff ff 	lea    -0x1c58(%rbp),%r12
 1242a76:	80 bd d8 e3 ff ff 00 	cmpb   $0x0,-0x1c28(%rbp)
 1242a7d:	74 66                	je     1242ae5 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x38c5>
 1242a7f:	48 8b 95 b0 e3 ff ff 	mov    -0x1c50(%rbp),%rdx
 1242a86:	48 8b 9d b8 e3 ff ff 	mov    -0x1c48(%rbp),%rbx
 1242a8d:	4c 8b b5 c0 e3 ff ff 	mov    -0x1c40(%rbp),%r14
 1242a94:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242a98:	4c 8b 38             	mov    (%rax),%r15
 1242a9b:	4c 8b 68 08          	mov    0x8(%rax),%r13
 1242a9f:	48 85 d2             	test   %rdx,%rdx
 1242aa2:	74 22                	je     1242ac6 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x38a6>
 1242aa4:	48 8b b5 a8 e3 ff ff 	mov    -0x1c58(%rbp),%rsi
 1242aab:	48 c1 e2 02          	shl    $0x2,%rdx
 1242aaf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242ab3:	4c 89 ff             	mov    %r15,%rdi
 1242ab6:	b9 02 00 00 00       	mov    $0x2,%ecx
 1242abb:	c5 f8 77             	vzeroupper 
 1242abe:	41 ff 55 18          	call   *0x18(%r13)
 1242ac2:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1242ac6:	4d 85 f6             	test   %r14,%r14
 1242ac9:	74 1a                	je     1242ae5 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x38c5>
 1242acb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242acf:	4c 89 ff             	mov    %r15,%rdi
 1242ad2:	48 89 de             	mov    %rbx,%rsi
 1242ad5:	4c 89 f2             	mov    %r14,%rdx
 1242ad8:	31 c9                	xor    %ecx,%ecx
 1242ada:	c5 f8 77             	vzeroupper 
 1242add:	41 ff 55 18          	call   *0x18(%r13)
 1242ae1:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1242ae5:	c4 c1 7c 11 44 24 18 	vmovups %ymm0,0x18(%r12)
 1242aec:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 1242af2:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1242af9:	0f 84 c1 00 00 00    	je     1242bc0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x39a0>
 1242aff:	48 8b 95 38 fe ff ff 	mov    -0x1c8(%rbp),%rdx
 1242b06:	48 8b b5 40 fe ff ff 	mov    -0x1c0(%rbp),%rsi
 1242b0d:	4c 8b a5 48 fe ff ff 	mov    -0x1b8(%rbp),%r12
 1242b14:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 1242b1b:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 1242b1f:	4c 8b ad 68 fe ff ff 	mov    -0x198(%rbp),%r13
 1242b26:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 1242b2d:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 1242b31:	4c 8b b5 78 fe ff ff 	mov    -0x188(%rbp),%r14
 1242b38:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242b3c:	4c 8b 38             	mov    (%rax),%r15
 1242b3f:	48 8b 58 08          	mov    0x8(%rax),%rbx
 1242b43:	48 85 d2             	test   %rdx,%rdx
 1242b46:	74 2b                	je     1242b73 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3953>
 1242b48:	4c 89 75 90          	mov    %r14,-0x70(%rbp)
 1242b4c:	49 89 f6             	mov    %rsi,%r14
 1242b4f:	48 8b b5 30 fe ff ff 	mov    -0x1d0(%rbp),%rsi
 1242b56:	48 c1 e2 02          	shl    $0x2,%rdx
 1242b5a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242b5e:	4c 89 ff             	mov    %r15,%rdi
 1242b61:	b9 02 00 00 00       	mov    $0x2,%ecx
 1242b66:	c5 f8 77             	vzeroupper 
 1242b69:	ff 53 18             	call   *0x18(%rbx)
 1242b6c:	4c 89 f6             	mov    %r14,%rsi
 1242b6f:	4c 8b 75 90          	mov    -0x70(%rbp),%r14
 1242b73:	4d 85 e4             	test   %r12,%r12
 1242b76:	74 12                	je     1242b8a <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x396a>
 1242b78:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242b7c:	4c 89 ff             	mov    %r15,%rdi
 1242b7f:	4c 89 e2             	mov    %r12,%rdx
 1242b82:	31 c9                	xor    %ecx,%ecx
 1242b84:	c5 f8 77             	vzeroupper 
 1242b87:	ff 53 18             	call   *0x18(%rbx)
 1242b8a:	4d 85 ed             	test   %r13,%r13
 1242b8d:	74 16                	je     1242ba5 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3985>
 1242b8f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242b93:	4c 89 ff             	mov    %r15,%rdi
 1242b96:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 1242b9a:	4c 89 ea             	mov    %r13,%rdx
 1242b9d:	31 c9                	xor    %ecx,%ecx
 1242b9f:	c5 f8 77             	vzeroupper 
 1242ba2:	ff 53 18             	call   *0x18(%rbx)
 1242ba5:	4d 85 f6             	test   %r14,%r14
 1242ba8:	74 16                	je     1242bc0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x39a0>
 1242baa:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242bae:	4c 89 ff             	mov    %r15,%rdi
 1242bb1:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 1242bb5:	4c 89 f2             	mov    %r14,%rdx
 1242bb8:	31 c9                	xor    %ecx,%ecx
 1242bba:	c5 f8 77             	vzeroupper 
 1242bbd:	ff 53 18             	call   *0x18(%rbx)
 1242bc0:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1242bc7:	74 60                	je     1242c29 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3a09>
 1242bc9:	48 8b 95 38 ff ff ff 	mov    -0xc8(%rbp),%rdx
 1242bd0:	48 8b 9d 40 ff ff ff 	mov    -0xc0(%rbp),%rbx
 1242bd7:	4c 8b b5 48 ff ff ff 	mov    -0xb8(%rbp),%r14
 1242bde:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242be2:	4c 8b 38             	mov    (%rax),%r15
 1242be5:	4c 8b 60 08          	mov    0x8(%rax),%r12
 1242be9:	48 85 d2             	test   %rdx,%rdx
 1242bec:	74 1f                	je     1242c0d <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x39ed>
 1242bee:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 1242bf5:	48 c1 e2 02          	shl    $0x2,%rdx
 1242bf9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242bfd:	4c 89 ff             	mov    %r15,%rdi
 1242c00:	b9 02 00 00 00       	mov    $0x2,%ecx
 1242c05:	c5 f8 77             	vzeroupper 
 1242c08:	41 ff 54 24 18       	call   *0x18(%r12)
 1242c0d:	4d 85 f6             	test   %r14,%r14
 1242c10:	74 17                	je     1242c29 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3a09>
 1242c12:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242c16:	4c 89 ff             	mov    %r15,%rdi
 1242c19:	48 89 de             	mov    %rbx,%rsi
 1242c1c:	4c 89 f2             	mov    %r14,%rdx
 1242c1f:	31 c9                	xor    %ecx,%ecx
 1242c21:	c5 f8 77             	vzeroupper 
 1242c24:	41 ff 54 24 18       	call   *0x18(%r12)
 1242c29:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1242c2d:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1242c31:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 1242c35:	48 c7 40 10 00 00 00 	movq   $0x0,0x10(%rax)
 1242c3c:	00 
 1242c3d:	e9 d1 02 00 00       	jmp    1242f13 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cf3>
 1242c42:	4d 85 ff             	test   %r15,%r15
 1242c45:	74 1a                	je     1242c61 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3a41>
 1242c47:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242c4b:	48 8b 38             	mov    (%rax),%rdi
 1242c4e:	48 8b 40 08          	mov    0x8(%rax),%rax
 1242c52:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242c56:	48 89 de             	mov    %rbx,%rsi
 1242c59:	4c 89 fa             	mov    %r15,%rdx
 1242c5c:	31 c9                	xor    %ecx,%ecx
 1242c5e:	ff 50 18             	call   *0x18(%rax)
 1242c61:	4c 89 f3             	mov    %r14,%rbx
 1242c64:	4d 89 ef             	mov    %r13,%r15
 1242c67:	4c 3b bd 68 fd ff ff 	cmp    -0x298(%rbp),%r15
 1242c6e:	0f 83 5c fd ff ff    	jae    12429d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x37b0>
 1242c74:	48 89 5d c8          	mov    %rbx,-0x38(%rbp)
 1242c78:	c5 fc 10 85 00 fe ff 	vmovups -0x200(%rbp),%ymm0
 1242c7f:	ff 
 1242c80:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1242c84:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1242c89:	c5 fc 10 85 90 fd ff 	vmovups -0x270(%rbp),%ymm0
 1242c90:	ff 
 1242c91:	c5 fc 10 8d b0 fd ff 	vmovups -0x250(%rbp),%ymm1
 1242c98:	ff 
 1242c99:	c5 fc 10 95 d0 fd ff 	vmovups -0x230(%rbp),%ymm2
 1242ca0:	ff 
 1242ca1:	c5 fc 10 9d f0 fd ff 	vmovups -0x210(%rbp),%ymm3
 1242ca8:	ff 
 1242ca9:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1242cae:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1242cb3:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1242cb8:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1242cbc:	80 bd 90 e0 ff ff 00 	cmpb   $0x0,-0x1f70(%rbp)
 1242cc3:	74 5e                	je     1242d23 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3b03>
 1242cc5:	48 8b 95 68 e0 ff ff 	mov    -0x1f98(%rbp),%rdx
 1242ccc:	48 8b 9d 70 e0 ff ff 	mov    -0x1f90(%rbp),%rbx
 1242cd3:	4c 8b b5 78 e0 ff ff 	mov    -0x1f88(%rbp),%r14
 1242cda:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242cde:	4c 8b 20             	mov    (%rax),%r12
 1242ce1:	4c 8b 68 08          	mov    0x8(%rax),%r13
 1242ce5:	48 85 d2             	test   %rdx,%rdx
 1242ce8:	74 1e                	je     1242d08 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3ae8>
 1242cea:	48 8b b5 60 e0 ff ff 	mov    -0x1fa0(%rbp),%rsi
 1242cf1:	48 c1 e2 02          	shl    $0x2,%rdx
 1242cf5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242cf9:	4c 89 e7             	mov    %r12,%rdi
 1242cfc:	b9 02 00 00 00       	mov    $0x2,%ecx
 1242d01:	c5 f8 77             	vzeroupper 
 1242d04:	41 ff 55 18          	call   *0x18(%r13)
 1242d08:	4d 85 f6             	test   %r14,%r14
 1242d0b:	74 16                	je     1242d23 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3b03>
 1242d0d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242d11:	4c 89 e7             	mov    %r12,%rdi
 1242d14:	48 89 de             	mov    %rbx,%rsi
 1242d17:	4c 89 f2             	mov    %r14,%rdx
 1242d1a:	31 c9                	xor    %ecx,%ecx
 1242d1c:	c5 f8 77             	vzeroupper 
 1242d1f:	41 ff 55 18          	call   *0x18(%r13)
 1242d23:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1242d27:	48 8d 85 60 e0 ff ff 	lea    -0x1fa0(%rbp),%rax
 1242d2e:	c5 fc 11 40 18       	vmovups %ymm0,0x18(%rax)
 1242d33:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1242d37:	4c 8d ad a8 e3 ff ff 	lea    -0x1c58(%rbp),%r13
 1242d3e:	80 bd d8 e3 ff ff 00 	cmpb   $0x0,-0x1c28(%rbp)
 1242d45:	74 69                	je     1242db0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3b90>
 1242d47:	48 8b 95 b0 e3 ff ff 	mov    -0x1c50(%rbp),%rdx
 1242d4e:	48 8b b5 b8 e3 ff ff 	mov    -0x1c48(%rbp),%rsi
 1242d55:	4c 8b b5 c0 e3 ff ff 	mov    -0x1c40(%rbp),%r14
 1242d5c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242d60:	4c 8b 20             	mov    (%rax),%r12
 1242d63:	48 8b 58 08          	mov    0x8(%rax),%rbx
 1242d67:	48 85 d2             	test   %rdx,%rdx
 1242d6a:	74 29                	je     1242d95 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3b75>
 1242d6c:	48 89 75 88          	mov    %rsi,-0x78(%rbp)
 1242d70:	48 8b b5 a8 e3 ff ff 	mov    -0x1c58(%rbp),%rsi
 1242d77:	48 c1 e2 02          	shl    $0x2,%rdx
 1242d7b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242d7f:	4c 89 e7             	mov    %r12,%rdi
 1242d82:	b9 02 00 00 00       	mov    $0x2,%ecx
 1242d87:	c5 f8 77             	vzeroupper 
 1242d8a:	ff 53 18             	call   *0x18(%rbx)
 1242d8d:	48 8b 75 88          	mov    -0x78(%rbp),%rsi
 1242d91:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1242d95:	4d 85 f6             	test   %r14,%r14
 1242d98:	74 16                	je     1242db0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3b90>
 1242d9a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242d9e:	4c 89 e7             	mov    %r12,%rdi
 1242da1:	4c 89 f2             	mov    %r14,%rdx
 1242da4:	31 c9                	xor    %ecx,%ecx
 1242da6:	c5 f8 77             	vzeroupper 
 1242da9:	ff 53 18             	call   *0x18(%rbx)
 1242dac:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1242db0:	c4 c1 7c 11 45 18    	vmovups %ymm0,0x18(%r13)
 1242db6:	c4 c1 7c 11 45 00    	vmovups %ymm0,0x0(%r13)
 1242dbc:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1242dc3:	0f 84 ce 00 00 00    	je     1242e97 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3c77>
 1242dc9:	48 8b 95 38 fe ff ff 	mov    -0x1c8(%rbp),%rdx
 1242dd0:	48 8b b5 40 fe ff ff 	mov    -0x1c0(%rbp),%rsi
 1242dd7:	4c 8b b5 48 fe ff ff 	mov    -0x1b8(%rbp),%r14
 1242dde:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 1242de5:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 1242dec:	48 8b 9d 68 fe ff ff 	mov    -0x198(%rbp),%rbx
 1242df3:	48 8b 85 70 fe ff ff 	mov    -0x190(%rbp),%rax
 1242dfa:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 1242dfe:	48 8b 85 78 fe ff ff 	mov    -0x188(%rbp),%rax
 1242e05:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 1242e09:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242e0d:	4c 8b 28             	mov    (%rax),%r13
 1242e10:	4c 8b 60 08          	mov    0x8(%rax),%r12
 1242e14:	48 85 d2             	test   %rdx,%rdx
 1242e17:	74 27                	je     1242e40 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3c20>
 1242e19:	48 89 75 80          	mov    %rsi,-0x80(%rbp)
 1242e1d:	48 8b b5 30 fe ff ff 	mov    -0x1d0(%rbp),%rsi
 1242e24:	48 c1 e2 02          	shl    $0x2,%rdx
 1242e28:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242e2c:	4c 89 ef             	mov    %r13,%rdi
 1242e2f:	b9 02 00 00 00       	mov    $0x2,%ecx
 1242e34:	c5 f8 77             	vzeroupper 
 1242e37:	41 ff 54 24 18       	call   *0x18(%r12)
 1242e3c:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 1242e40:	4d 85 f6             	test   %r14,%r14
 1242e43:	74 14                	je     1242e59 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3c39>
 1242e45:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242e49:	4c 89 ef             	mov    %r13,%rdi
 1242e4c:	4c 89 f2             	mov    %r14,%rdx
 1242e4f:	31 c9                	xor    %ecx,%ecx
 1242e51:	c5 f8 77             	vzeroupper 
 1242e54:	41 ff 54 24 18       	call   *0x18(%r12)
 1242e59:	48 85 db             	test   %rbx,%rbx
 1242e5c:	74 1b                	je     1242e79 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3c59>
 1242e5e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242e62:	4c 89 ef             	mov    %r13,%rdi
 1242e65:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 1242e6c:	48 89 da             	mov    %rbx,%rdx
 1242e6f:	31 c9                	xor    %ecx,%ecx
 1242e71:	c5 f8 77             	vzeroupper 
 1242e74:	41 ff 54 24 18       	call   *0x18(%r12)
 1242e79:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 1242e7d:	48 85 d2             	test   %rdx,%rdx
 1242e80:	74 15                	je     1242e97 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3c77>
 1242e82:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242e86:	4c 89 ef             	mov    %r13,%rdi
 1242e89:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 1242e8d:	31 c9                	xor    %ecx,%ecx
 1242e8f:	c5 f8 77             	vzeroupper 
 1242e92:	41 ff 54 24 18       	call   *0x18(%r12)
 1242e97:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1242e9e:	74 5e                	je     1242efe <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cde>
 1242ea0:	48 8b 95 38 ff ff ff 	mov    -0xc8(%rbp),%rdx
 1242ea7:	48 8b 9d 40 ff ff ff 	mov    -0xc0(%rbp),%rbx
 1242eae:	4c 8b b5 48 ff ff ff 	mov    -0xb8(%rbp),%r14
 1242eb5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1242eb9:	4c 8b 20             	mov    (%rax),%r12
 1242ebc:	4c 8b 68 08          	mov    0x8(%rax),%r13
 1242ec0:	48 85 d2             	test   %rdx,%rdx
 1242ec3:	74 1e                	je     1242ee3 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cc3>
 1242ec5:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 1242ecc:	48 c1 e2 02          	shl    $0x2,%rdx
 1242ed0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242ed4:	4c 89 e7             	mov    %r12,%rdi
 1242ed7:	b9 02 00 00 00       	mov    $0x2,%ecx
 1242edc:	c5 f8 77             	vzeroupper 
 1242edf:	41 ff 55 18          	call   *0x18(%r13)
 1242ee3:	4d 85 f6             	test   %r14,%r14
 1242ee6:	74 16                	je     1242efe <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cde>
 1242ee8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1242eec:	4c 89 e7             	mov    %r12,%rdi
 1242eef:	48 89 de             	mov    %rbx,%rsi
 1242ef2:	4c 89 f2             	mov    %r14,%rdx
 1242ef5:	31 c9                	xor    %ecx,%ecx
 1242ef7:	c5 f8 77             	vzeroupper 
 1242efa:	41 ff 55 18          	call   *0x18(%r13)
 1242efe:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1242f02:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 1242f08:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 1242f0c:	48 89 08             	mov    %rcx,(%rax)
 1242f0f:	4c 89 78 08          	mov    %r15,0x8(%rax)
 1242f13:	48 81 c4 d8 40 00 00 	add    $0x40d8,%rsp
 1242f1a:	5b                   	pop    %rbx
 1242f1b:	41 5c                	pop    %r12
 1242f1d:	41 5d                	pop    %r13
 1242f1f:	41 5e                	pop    %r14
 1242f21:	41 5f                	pop    %r15
 1242f23:	5d                   	pop    %rbp
 1242f24:	c5 f8 77             	vzeroupper 
 1242f27:	c3                   	ret    
 1242f28:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1242f2f:	74 43                	je     1242f74 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3d54>
 1242f31:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1242f38:	ff 
 1242f39:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1242f40:	ff 
 1242f41:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1242f48:	ff 
 1242f49:	c5 fc 11 95 c8 d3 ff 	vmovups %ymm2,-0x2c38(%rbp)
 1242f50:	ff 
 1242f51:	c5 fc 11 8d b0 d3 ff 	vmovups %ymm1,-0x2c50(%rbp)
 1242f58:	ff 
 1242f59:	c5 fc 11 85 90 d3 ff 	vmovups %ymm0,-0x2c70(%rbp)
 1242f60:	ff 
 1242f61:	48 8d bd 90 d3 ff ff 	lea    -0x2c70(%rbp),%rdi
 1242f68:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1242f6c:	c5 f8 77             	vzeroupper 
 1242f6f:	e8 3c 24 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1242f74:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1242f7b:	0f 84 5b 16 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 1242f81:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1242f88:	ff 
 1242f89:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1242f90:	ff 
 1242f91:	c5 fc 11 8d 10 e9 ff 	vmovups %ymm1,-0x16f0(%rbp)
 1242f98:	ff 
 1242f99:	c5 fc 11 85 00 e9 ff 	vmovups %ymm0,-0x1700(%rbp)
 1242fa0:	ff 
 1242fa1:	48 8d bd 00 e9 ff ff 	lea    -0x1700(%rbp),%rdi
 1242fa8:	e9 23 16 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 1242fad:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 1242fb1:	66 89 41 10          	mov    %ax,0x10(%rcx)
 1242fb5:	e9 59 ff ff ff       	jmp    1242f13 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cf3>
 1242fba:	83 f8 1a             	cmp    $0x1a,%eax
 1242fbd:	0f 84 26 16 00 00    	je     12445e9 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53c9>
 1242fc3:	83 f8 43             	cmp    $0x43,%eax
 1242fc6:	0f 85 76 16 00 00    	jne    1244642 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x5422>
 1242fcc:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1242fd3:	74 33                	je     1243008 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3de8>
 1242fd5:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1242fdc:	ff 
 1242fdd:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1242fe4:	ff 
 1242fe5:	c5 fc 11 8d 70 e9 ff 	vmovups %ymm1,-0x1690(%rbp)
 1242fec:	ff 
 1242fed:	c5 fc 11 85 60 e9 ff 	vmovups %ymm0,-0x16a0(%rbp)
 1242ff4:	ff 
 1242ff5:	48 8d bd 60 e9 ff ff 	lea    -0x16a0(%rbp),%rdi
 1242ffc:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243000:	c5 f8 77             	vzeroupper 
 1243003:	e8 d8 62 01 00       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 1243008:	c5 f8 10 05 d0 39 e5 	vmovups -0x1ac630(%rip),%xmm0        # 10969e0 <__anon_233167>
 124300f:	ff 
 1243010:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1243014:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 1243018:	48 c7 40 10 43 00 00 	movq   $0x43,0x10(%rax)
 124301f:	00 
 1243020:	e9 ee fe ff ff       	jmp    1242f13 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cf3>
 1243025:	48 85 db             	test   %rbx,%rbx
 1243028:	74 1a                	je     1243044 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3e24>
 124302a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 124302e:	48 8b 38             	mov    (%rax),%rdi
 1243031:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243035:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243039:	4c 89 e6             	mov    %r12,%rsi
 124303c:	48 89 da             	mov    %rbx,%rdx
 124303f:	31 c9                	xor    %ecx,%ecx
 1243041:	ff 50 18             	call   *0x18(%rax)
 1243044:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 124304b:	ff 
 124304c:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243050:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243055:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124305c:	ff 
 124305d:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243064:	ff 
 1243065:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 124306c:	ff 
 124306d:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243074:	ff 
 1243075:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 124307a:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 124307f:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243084:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243088:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 124308f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243093:	c5 f8 77             	vzeroupper 
 1243096:	e8 e5 21 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 124309b:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 12430a2:	74 43                	je     12430e7 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3ec7>
 12430a4:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 12430ab:	ff 
 12430ac:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 12430b3:	ff 
 12430b4:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 12430bb:	ff 
 12430bc:	c5 fc 11 95 88 d1 ff 	vmovups %ymm2,-0x2e78(%rbp)
 12430c3:	ff 
 12430c4:	c5 fc 11 8d 70 d1 ff 	vmovups %ymm1,-0x2e90(%rbp)
 12430cb:	ff 
 12430cc:	c5 fc 11 85 50 d1 ff 	vmovups %ymm0,-0x2eb0(%rbp)
 12430d3:	ff 
 12430d4:	48 8d bd 50 d1 ff ff 	lea    -0x2eb0(%rbp),%rdi
 12430db:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12430df:	c5 f8 77             	vzeroupper 
 12430e2:	e8 c9 22 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12430e7:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12430ee:	0f 84 dc 13 00 00    	je     12444d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52b0>
 12430f4:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12430fb:	ff 
 12430fc:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1243103:	ff 
 1243104:	c5 fc 11 8d f0 e7 ff 	vmovups %ymm1,-0x1810(%rbp)
 124310b:	ff 
 124310c:	c5 fc 11 85 e0 e7 ff 	vmovups %ymm0,-0x1820(%rbp)
 1243113:	ff 
 1243114:	48 8d bd e0 e7 ff ff 	lea    -0x1820(%rbp),%rdi
 124311b:	e9 a4 13 00 00       	jmp    12444c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52a4>
 1243120:	4d 85 ff             	test   %r15,%r15
 1243123:	74 1a                	je     124313f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3f1f>
 1243125:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243129:	48 8b 38             	mov    (%rax),%rdi
 124312c:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243130:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243134:	4c 89 ee             	mov    %r13,%rsi
 1243137:	4c 89 fa             	mov    %r15,%rdx
 124313a:	31 c9                	xor    %ecx,%ecx
 124313c:	ff 50 18             	call   *0x18(%rax)
 124313f:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243146:	ff 
 1243147:	48 8b 45 10          	mov    0x10(%rbp),%rax
 124314b:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243150:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243157:	ff 
 1243158:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124315f:	ff 
 1243160:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243167:	ff 
 1243168:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124316f:	ff 
 1243170:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243175:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 124317a:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 124317f:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243183:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 124318a:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124318e:	c5 f8 77             	vzeroupper 
 1243191:	e8 ea 20 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243196:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 124319d:	74 43                	je     12431e2 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3fc2>
 124319f:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 12431a6:	ff 
 12431a7:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 12431ae:	ff 
 12431af:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 12431b6:	ff 
 12431b7:	c5 fc 11 95 28 d1 ff 	vmovups %ymm2,-0x2ed8(%rbp)
 12431be:	ff 
 12431bf:	c5 fc 11 8d 10 d1 ff 	vmovups %ymm1,-0x2ef0(%rbp)
 12431c6:	ff 
 12431c7:	c5 fc 11 85 f0 d0 ff 	vmovups %ymm0,-0x2f10(%rbp)
 12431ce:	ff 
 12431cf:	48 8d bd f0 d0 ff ff 	lea    -0x2f10(%rbp),%rdi
 12431d6:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12431da:	c5 f8 77             	vzeroupper 
 12431dd:	e8 ce 21 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12431e2:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12431e9:	0f 84 ed 13 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 12431ef:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12431f6:	ff 
 12431f7:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12431fe:	ff 
 12431ff:	c5 fc 11 8d c0 e7 ff 	vmovups %ymm1,-0x1840(%rbp)
 1243206:	ff 
 1243207:	c5 fc 11 85 b0 e7 ff 	vmovups %ymm0,-0x1850(%rbp)
 124320e:	ff 
 124320f:	48 8d bd b0 e7 ff ff 	lea    -0x1850(%rbp),%rdi
 1243216:	e9 b5 13 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 124321b:	48 85 db             	test   %rbx,%rbx
 124321e:	74 1a                	je     124323a <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x401a>
 1243220:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243224:	48 8b 38             	mov    (%rax),%rdi
 1243227:	48 8b 40 08          	mov    0x8(%rax),%rax
 124322b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124322f:	4c 89 e6             	mov    %r12,%rsi
 1243232:	48 89 da             	mov    %rbx,%rdx
 1243235:	31 c9                	xor    %ecx,%ecx
 1243237:	ff 50 18             	call   *0x18(%rax)
 124323a:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243241:	ff 
 1243242:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243246:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 124324b:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243252:	ff 
 1243253:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124325a:	ff 
 124325b:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243262:	ff 
 1243263:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124326a:	ff 
 124326b:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243270:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243275:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 124327a:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 124327e:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243285:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243289:	c5 f8 77             	vzeroupper 
 124328c:	e8 ef 1f 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243291:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243298:	74 43                	je     12432dd <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x40bd>
 124329a:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 12432a1:	ff 
 12432a2:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 12432a9:	ff 
 12432aa:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 12432b1:	ff 
 12432b2:	c5 fc 11 95 c8 d0 ff 	vmovups %ymm2,-0x2f38(%rbp)
 12432b9:	ff 
 12432ba:	c5 fc 11 8d b0 d0 ff 	vmovups %ymm1,-0x2f50(%rbp)
 12432c1:	ff 
 12432c2:	c5 fc 11 85 90 d0 ff 	vmovups %ymm0,-0x2f70(%rbp)
 12432c9:	ff 
 12432ca:	48 8d bd 90 d0 ff ff 	lea    -0x2f70(%rbp),%rdi
 12432d1:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12432d5:	c5 f8 77             	vzeroupper 
 12432d8:	e8 d3 20 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12432dd:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12432e4:	0f 84 e6 11 00 00    	je     12444d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52b0>
 12432ea:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12432f1:	ff 
 12432f2:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12432f9:	ff 
 12432fa:	c5 fc 11 8d 90 e7 ff 	vmovups %ymm1,-0x1870(%rbp)
 1243301:	ff 
 1243302:	c5 fc 11 85 80 e7 ff 	vmovups %ymm0,-0x1880(%rbp)
 1243309:	ff 
 124330a:	48 8d bd 80 e7 ff ff 	lea    -0x1880(%rbp),%rdi
 1243311:	e9 ae 11 00 00       	jmp    12444c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52a4>
 1243316:	4d 85 ff             	test   %r15,%r15
 1243319:	74 1a                	je     1243335 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4115>
 124331b:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 124331f:	48 8b 38             	mov    (%rax),%rdi
 1243322:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243326:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124332a:	4c 89 ee             	mov    %r13,%rsi
 124332d:	4c 89 fa             	mov    %r15,%rdx
 1243330:	31 c9                	xor    %ecx,%ecx
 1243332:	ff 50 18             	call   *0x18(%rax)
 1243335:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 124333c:	ff 
 124333d:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243341:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243346:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124334d:	ff 
 124334e:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243355:	ff 
 1243356:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 124335d:	ff 
 124335e:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243365:	ff 
 1243366:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 124336b:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243370:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243375:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243379:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243380:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243384:	c5 f8 77             	vzeroupper 
 1243387:	e8 f4 1e 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 124338c:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243393:	74 43                	je     12433d8 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x41b8>
 1243395:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 124339c:	ff 
 124339d:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 12433a4:	ff 
 12433a5:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 12433ac:	ff 
 12433ad:	c5 fc 11 95 68 d0 ff 	vmovups %ymm2,-0x2f98(%rbp)
 12433b4:	ff 
 12433b5:	c5 fc 11 8d 50 d0 ff 	vmovups %ymm1,-0x2fb0(%rbp)
 12433bc:	ff 
 12433bd:	c5 fc 11 85 30 d0 ff 	vmovups %ymm0,-0x2fd0(%rbp)
 12433c4:	ff 
 12433c5:	48 8d bd 30 d0 ff ff 	lea    -0x2fd0(%rbp),%rdi
 12433cc:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12433d0:	c5 f8 77             	vzeroupper 
 12433d3:	e8 d8 1f 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12433d8:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12433df:	0f 84 f7 11 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 12433e5:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12433ec:	ff 
 12433ed:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12433f4:	ff 
 12433f5:	c5 fc 11 8d 60 e7 ff 	vmovups %ymm1,-0x18a0(%rbp)
 12433fc:	ff 
 12433fd:	c5 fc 11 85 50 e7 ff 	vmovups %ymm0,-0x18b0(%rbp)
 1243404:	ff 
 1243405:	48 8d bd 50 e7 ff ff 	lea    -0x18b0(%rbp),%rdi
 124340c:	e9 bf 11 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 1243411:	48 85 db             	test   %rbx,%rbx
 1243414:	74 1a                	je     1243430 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4210>
 1243416:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 124341a:	48 8b 38             	mov    (%rax),%rdi
 124341d:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243421:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243425:	4c 89 e6             	mov    %r12,%rsi
 1243428:	48 89 da             	mov    %rbx,%rdx
 124342b:	31 c9                	xor    %ecx,%ecx
 124342d:	ff 50 18             	call   *0x18(%rax)
 1243430:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243437:	ff 
 1243438:	48 8b 45 10          	mov    0x10(%rbp),%rax
 124343c:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243441:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243448:	ff 
 1243449:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243450:	ff 
 1243451:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243458:	ff 
 1243459:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243460:	ff 
 1243461:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243466:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 124346b:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243470:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243474:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 124347b:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124347f:	c5 f8 77             	vzeroupper 
 1243482:	e8 f9 1d 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243487:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 124348e:	74 43                	je     12434d3 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x42b3>
 1243490:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1243497:	ff 
 1243498:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 124349f:	ff 
 12434a0:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 12434a7:	ff 
 12434a8:	c5 fc 11 95 08 d0 ff 	vmovups %ymm2,-0x2ff8(%rbp)
 12434af:	ff 
 12434b0:	c5 fc 11 8d f0 cf ff 	vmovups %ymm1,-0x3010(%rbp)
 12434b7:	ff 
 12434b8:	c5 fc 11 85 d0 cf ff 	vmovups %ymm0,-0x3030(%rbp)
 12434bf:	ff 
 12434c0:	48 8d bd d0 cf ff ff 	lea    -0x3030(%rbp),%rdi
 12434c7:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12434cb:	c5 f8 77             	vzeroupper 
 12434ce:	e8 dd 1e 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12434d3:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12434da:	0f 84 f0 0f 00 00    	je     12444d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52b0>
 12434e0:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12434e7:	ff 
 12434e8:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12434ef:	ff 
 12434f0:	c5 fc 11 8d 30 e7 ff 	vmovups %ymm1,-0x18d0(%rbp)
 12434f7:	ff 
 12434f8:	c5 fc 11 85 20 e7 ff 	vmovups %ymm0,-0x18e0(%rbp)
 12434ff:	ff 
 1243500:	48 8d bd 20 e7 ff ff 	lea    -0x18e0(%rbp),%rdi
 1243507:	e9 b8 0f 00 00       	jmp    12444c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52a4>
 124350c:	4d 85 ed             	test   %r13,%r13
 124350f:	74 1a                	je     124352b <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x430b>
 1243511:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243515:	48 8b 38             	mov    (%rax),%rdi
 1243518:	48 8b 40 08          	mov    0x8(%rax),%rax
 124351c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243520:	4c 89 e6             	mov    %r12,%rsi
 1243523:	4c 89 ea             	mov    %r13,%rdx
 1243526:	31 c9                	xor    %ecx,%ecx
 1243528:	ff 50 18             	call   *0x18(%rax)
 124352b:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243532:	ff 
 1243533:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243537:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 124353c:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243543:	ff 
 1243544:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124354b:	ff 
 124354c:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243553:	ff 
 1243554:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124355b:	ff 
 124355c:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243561:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243566:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 124356b:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 124356f:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243576:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124357a:	c5 f8 77             	vzeroupper 
 124357d:	e8 fe 1c 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243582:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243589:	74 43                	je     12435ce <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x43ae>
 124358b:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1243592:	ff 
 1243593:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 124359a:	ff 
 124359b:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 12435a2:	ff 
 12435a3:	c5 fc 11 95 48 cf ff 	vmovups %ymm2,-0x30b8(%rbp)
 12435aa:	ff 
 12435ab:	c5 fc 11 8d 30 cf ff 	vmovups %ymm1,-0x30d0(%rbp)
 12435b2:	ff 
 12435b3:	c5 fc 11 85 10 cf ff 	vmovups %ymm0,-0x30f0(%rbp)
 12435ba:	ff 
 12435bb:	48 8d bd 10 cf ff ff 	lea    -0x30f0(%rbp),%rdi
 12435c2:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12435c6:	c5 f8 77             	vzeroupper 
 12435c9:	e8 e2 1d 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12435ce:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12435d5:	0f 84 01 10 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 12435db:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12435e2:	ff 
 12435e3:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12435ea:	ff 
 12435eb:	c5 fc 11 8d d0 e6 ff 	vmovups %ymm1,-0x1930(%rbp)
 12435f2:	ff 
 12435f3:	c5 fc 11 85 c0 e6 ff 	vmovups %ymm0,-0x1940(%rbp)
 12435fa:	ff 
 12435fb:	48 8d bd c0 e6 ff ff 	lea    -0x1940(%rbp),%rdi
 1243602:	e9 c9 0f 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 1243607:	48 85 db             	test   %rbx,%rbx
 124360a:	74 1a                	je     1243626 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4406>
 124360c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243610:	48 8b 38             	mov    (%rax),%rdi
 1243613:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243617:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124361b:	4c 89 f6             	mov    %r14,%rsi
 124361e:	48 89 da             	mov    %rbx,%rdx
 1243621:	31 c9                	xor    %ecx,%ecx
 1243623:	ff 50 18             	call   *0x18(%rax)
 1243626:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 124362d:	ff 
 124362e:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243632:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243637:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124363e:	ff 
 124363f:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243646:	ff 
 1243647:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 124364e:	ff 
 124364f:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243656:	ff 
 1243657:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 124365c:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243661:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243666:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 124366a:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243671:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243675:	c5 f8 77             	vzeroupper 
 1243678:	e8 03 1c 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 124367d:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243684:	74 43                	je     12436c9 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x44a9>
 1243686:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 124368d:	ff 
 124368e:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1243695:	ff 
 1243696:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 124369d:	ff 
 124369e:	c5 fc 11 95 e8 ce ff 	vmovups %ymm2,-0x3118(%rbp)
 12436a5:	ff 
 12436a6:	c5 fc 11 8d d0 ce ff 	vmovups %ymm1,-0x3130(%rbp)
 12436ad:	ff 
 12436ae:	c5 fc 11 85 b0 ce ff 	vmovups %ymm0,-0x3150(%rbp)
 12436b5:	ff 
 12436b6:	48 8d bd b0 ce ff ff 	lea    -0x3150(%rbp),%rdi
 12436bd:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12436c1:	c5 f8 77             	vzeroupper 
 12436c4:	e8 e7 1c 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12436c9:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12436d0:	74 33                	je     1243705 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x44e5>
 12436d2:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12436d9:	ff 
 12436da:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12436e1:	ff 
 12436e2:	c5 fc 11 8d a0 e6 ff 	vmovups %ymm1,-0x1960(%rbp)
 12436e9:	ff 
 12436ea:	c5 fc 11 85 90 e6 ff 	vmovups %ymm0,-0x1970(%rbp)
 12436f1:	ff 
 12436f2:	48 8d bd 90 e6 ff ff 	lea    -0x1970(%rbp),%rdi
 12436f9:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12436fd:	c5 f8 77             	vzeroupper 
 1243700:	e8 db 5b 01 00       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 1243705:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1243709:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 124370e:	e9 00 f8 ff ff       	jmp    1242f13 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cf3>
 1243713:	4d 85 ff             	test   %r15,%r15
 1243716:	74 1a                	je     1243732 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4512>
 1243718:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 124371c:	48 8b 38             	mov    (%rax),%rdi
 124371f:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243723:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243727:	4c 89 ee             	mov    %r13,%rsi
 124372a:	4c 89 fa             	mov    %r15,%rdx
 124372d:	31 c9                	xor    %ecx,%ecx
 124372f:	ff 50 18             	call   *0x18(%rax)
 1243732:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243739:	ff 
 124373a:	48 8b 45 10          	mov    0x10(%rbp),%rax
 124373e:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243743:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124374a:	ff 
 124374b:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243752:	ff 
 1243753:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 124375a:	ff 
 124375b:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243762:	ff 
 1243763:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243768:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 124376d:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243772:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243776:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 124377d:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243781:	c5 f8 77             	vzeroupper 
 1243784:	e8 f7 1a 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243789:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243790:	74 43                	je     12437d5 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x45b5>
 1243792:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1243799:	ff 
 124379a:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 12437a1:	ff 
 12437a2:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 12437a9:	ff 
 12437aa:	c5 fc 11 95 88 ce ff 	vmovups %ymm2,-0x3178(%rbp)
 12437b1:	ff 
 12437b2:	c5 fc 11 8d 70 ce ff 	vmovups %ymm1,-0x3190(%rbp)
 12437b9:	ff 
 12437ba:	c5 fc 11 85 50 ce ff 	vmovups %ymm0,-0x31b0(%rbp)
 12437c1:	ff 
 12437c2:	48 8d bd 50 ce ff ff 	lea    -0x31b0(%rbp),%rdi
 12437c9:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12437cd:	c5 f8 77             	vzeroupper 
 12437d0:	e8 db 1b 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12437d5:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12437dc:	0f 84 fa 0d 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 12437e2:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12437e9:	ff 
 12437ea:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12437f1:	ff 
 12437f2:	c5 fc 11 8d 70 e6 ff 	vmovups %ymm1,-0x1990(%rbp)
 12437f9:	ff 
 12437fa:	c5 fc 11 85 60 e6 ff 	vmovups %ymm0,-0x19a0(%rbp)
 1243801:	ff 
 1243802:	48 8d bd 60 e6 ff ff 	lea    -0x19a0(%rbp),%rdi
 1243809:	e9 c2 0d 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 124380e:	48 85 db             	test   %rbx,%rbx
 1243811:	74 1a                	je     124382d <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x460d>
 1243813:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243817:	48 8b 38             	mov    (%rax),%rdi
 124381a:	48 8b 40 08          	mov    0x8(%rax),%rax
 124381e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243822:	4c 89 e6             	mov    %r12,%rsi
 1243825:	48 89 da             	mov    %rbx,%rdx
 1243828:	31 c9                	xor    %ecx,%ecx
 124382a:	ff 50 18             	call   *0x18(%rax)
 124382d:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243834:	ff 
 1243835:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243839:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 124383e:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243845:	ff 
 1243846:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124384d:	ff 
 124384e:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243855:	ff 
 1243856:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124385d:	ff 
 124385e:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243863:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243868:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 124386d:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243871:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243878:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124387c:	c5 f8 77             	vzeroupper 
 124387f:	e8 fc 19 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243884:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 124388b:	74 43                	je     12438d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x46b0>
 124388d:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1243894:	ff 
 1243895:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 124389c:	ff 
 124389d:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 12438a4:	ff 
 12438a5:	c5 fc 11 95 28 ce ff 	vmovups %ymm2,-0x31d8(%rbp)
 12438ac:	ff 
 12438ad:	c5 fc 11 8d 10 ce ff 	vmovups %ymm1,-0x31f0(%rbp)
 12438b4:	ff 
 12438b5:	c5 fc 11 85 f0 cd ff 	vmovups %ymm0,-0x3210(%rbp)
 12438bc:	ff 
 12438bd:	48 8d bd f0 cd ff ff 	lea    -0x3210(%rbp),%rdi
 12438c4:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12438c8:	c5 f8 77             	vzeroupper 
 12438cb:	e8 e0 1a 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12438d0:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12438d7:	0f 84 f3 0b 00 00    	je     12444d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52b0>
 12438dd:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12438e4:	ff 
 12438e5:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12438ec:	ff 
 12438ed:	c5 fc 11 8d 40 e6 ff 	vmovups %ymm1,-0x19c0(%rbp)
 12438f4:	ff 
 12438f5:	c5 fc 11 85 30 e6 ff 	vmovups %ymm0,-0x19d0(%rbp)
 12438fc:	ff 
 12438fd:	48 8d bd 30 e6 ff ff 	lea    -0x19d0(%rbp),%rdi
 1243904:	e9 bb 0b 00 00       	jmp    12444c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52a4>
 1243909:	4d 85 ff             	test   %r15,%r15
 124390c:	74 1a                	je     1243928 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4708>
 124390e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243912:	48 8b 38             	mov    (%rax),%rdi
 1243915:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243919:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 124391d:	4c 89 f6             	mov    %r14,%rsi
 1243920:	4c 89 fa             	mov    %r15,%rdx
 1243923:	31 c9                	xor    %ecx,%ecx
 1243925:	ff 50 18             	call   *0x18(%rax)
 1243928:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 124392f:	ff 
 1243930:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243934:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243939:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243940:	ff 
 1243941:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243948:	ff 
 1243949:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243950:	ff 
 1243951:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243958:	ff 
 1243959:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 124395e:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243963:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243968:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 124396c:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243973:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243977:	c5 f8 77             	vzeroupper 
 124397a:	e8 01 19 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 124397f:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243986:	74 43                	je     12439cb <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x47ab>
 1243988:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 124398f:	ff 
 1243990:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1243997:	ff 
 1243998:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 124399f:	ff 
 12439a0:	c5 fc 11 95 c8 cd ff 	vmovups %ymm2,-0x3238(%rbp)
 12439a7:	ff 
 12439a8:	c5 fc 11 8d b0 cd ff 	vmovups %ymm1,-0x3250(%rbp)
 12439af:	ff 
 12439b0:	c5 fc 11 85 90 cd ff 	vmovups %ymm0,-0x3270(%rbp)
 12439b7:	ff 
 12439b8:	48 8d bd 90 cd ff ff 	lea    -0x3270(%rbp),%rdi
 12439bf:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12439c3:	c5 f8 77             	vzeroupper 
 12439c6:	e8 e5 19 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12439cb:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12439d2:	0f 84 04 0c 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 12439d8:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12439df:	ff 
 12439e0:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12439e7:	ff 
 12439e8:	c5 fc 11 8d 10 e6 ff 	vmovups %ymm1,-0x19f0(%rbp)
 12439ef:	ff 
 12439f0:	c5 fc 11 85 00 e6 ff 	vmovups %ymm0,-0x1a00(%rbp)
 12439f7:	ff 
 12439f8:	48 8d bd 00 e6 ff ff 	lea    -0x1a00(%rbp),%rdi
 12439ff:	e9 cc 0b 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 1243a04:	4d 85 ed             	test   %r13,%r13
 1243a07:	74 1a                	je     1243a23 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4803>
 1243a09:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243a0d:	48 8b 38             	mov    (%rax),%rdi
 1243a10:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243a14:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243a18:	4c 89 e6             	mov    %r12,%rsi
 1243a1b:	4c 89 ea             	mov    %r13,%rdx
 1243a1e:	31 c9                	xor    %ecx,%ecx
 1243a20:	ff 50 18             	call   *0x18(%rax)
 1243a23:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243a2a:	ff 
 1243a2b:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243a2f:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243a34:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243a3b:	ff 
 1243a3c:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243a43:	ff 
 1243a44:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243a4b:	ff 
 1243a4c:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243a53:	ff 
 1243a54:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243a59:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243a5e:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243a63:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243a67:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243a6e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243a72:	c5 f8 77             	vzeroupper 
 1243a75:	e8 06 18 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243a7a:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243a81:	74 43                	je     1243ac6 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x48a6>
 1243a83:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1243a8a:	ff 
 1243a8b:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1243a92:	ff 
 1243a93:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1243a9a:	ff 
 1243a9b:	c5 fc 11 95 68 cd ff 	vmovups %ymm2,-0x3298(%rbp)
 1243aa2:	ff 
 1243aa3:	c5 fc 11 8d 50 cd ff 	vmovups %ymm1,-0x32b0(%rbp)
 1243aaa:	ff 
 1243aab:	c5 fc 11 85 30 cd ff 	vmovups %ymm0,-0x32d0(%rbp)
 1243ab2:	ff 
 1243ab3:	48 8d bd 30 cd ff ff 	lea    -0x32d0(%rbp),%rdi
 1243aba:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243abe:	c5 f8 77             	vzeroupper 
 1243ac1:	e8 ea 18 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1243ac6:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1243acd:	0f 84 09 0b 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 1243ad3:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1243ada:	ff 
 1243adb:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1243ae2:	ff 
 1243ae3:	c5 fc 11 8d e0 e5 ff 	vmovups %ymm1,-0x1a20(%rbp)
 1243aea:	ff 
 1243aeb:	c5 fc 11 85 d0 e5 ff 	vmovups %ymm0,-0x1a30(%rbp)
 1243af2:	ff 
 1243af3:	48 8d bd d0 e5 ff ff 	lea    -0x1a30(%rbp),%rdi
 1243afa:	e9 d1 0a 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 1243aff:	4d 85 ed             	test   %r13,%r13
 1243b02:	74 1a                	je     1243b1e <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x48fe>
 1243b04:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243b08:	48 8b 38             	mov    (%rax),%rdi
 1243b0b:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243b0f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243b13:	4c 89 f6             	mov    %r14,%rsi
 1243b16:	4c 89 ea             	mov    %r13,%rdx
 1243b19:	31 c9                	xor    %ecx,%ecx
 1243b1b:	ff 50 18             	call   *0x18(%rax)
 1243b1e:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243b25:	ff 
 1243b26:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243b2a:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243b2f:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243b36:	ff 
 1243b37:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243b3e:	ff 
 1243b3f:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243b46:	ff 
 1243b47:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243b4e:	ff 
 1243b4f:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243b54:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243b59:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243b5e:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243b62:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243b69:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243b6d:	c5 f8 77             	vzeroupper 
 1243b70:	e8 0b 17 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243b75:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243b7c:	74 43                	je     1243bc1 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x49a1>
 1243b7e:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1243b85:	ff 
 1243b86:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1243b8d:	ff 
 1243b8e:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1243b95:	ff 
 1243b96:	c5 fc 11 95 a8 cc ff 	vmovups %ymm2,-0x3358(%rbp)
 1243b9d:	ff 
 1243b9e:	c5 fc 11 8d 90 cc ff 	vmovups %ymm1,-0x3370(%rbp)
 1243ba5:	ff 
 1243ba6:	c5 fc 11 85 70 cc ff 	vmovups %ymm0,-0x3390(%rbp)
 1243bad:	ff 
 1243bae:	48 8d bd 70 cc ff ff 	lea    -0x3390(%rbp),%rdi
 1243bb5:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243bb9:	c5 f8 77             	vzeroupper 
 1243bbc:	e8 ef 17 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1243bc1:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1243bc8:	0f 84 0e 0a 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 1243bce:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1243bd5:	ff 
 1243bd6:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1243bdd:	ff 
 1243bde:	c5 fc 11 8d 80 e5 ff 	vmovups %ymm1,-0x1a80(%rbp)
 1243be5:	ff 
 1243be6:	c5 fc 11 85 70 e5 ff 	vmovups %ymm0,-0x1a90(%rbp)
 1243bed:	ff 
 1243bee:	48 8d bd 70 e5 ff ff 	lea    -0x1a90(%rbp),%rdi
 1243bf5:	e9 d6 09 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 1243bfa:	48 85 db             	test   %rbx,%rbx
 1243bfd:	74 1a                	je     1243c19 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x49f9>
 1243bff:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243c03:	48 8b 38             	mov    (%rax),%rdi
 1243c06:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243c0a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243c0e:	4c 89 e6             	mov    %r12,%rsi
 1243c11:	48 89 da             	mov    %rbx,%rdx
 1243c14:	31 c9                	xor    %ecx,%ecx
 1243c16:	ff 50 18             	call   *0x18(%rax)
 1243c19:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243c20:	ff 
 1243c21:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243c25:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243c2a:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243c31:	ff 
 1243c32:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243c39:	ff 
 1243c3a:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243c41:	ff 
 1243c42:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243c49:	ff 
 1243c4a:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243c4f:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243c54:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243c59:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243c5d:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243c64:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243c68:	c5 f8 77             	vzeroupper 
 1243c6b:	e8 10 16 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243c70:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243c77:	74 43                	je     1243cbc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4a9c>
 1243c79:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1243c80:	ff 
 1243c81:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1243c88:	ff 
 1243c89:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1243c90:	ff 
 1243c91:	c5 fc 11 95 48 cc ff 	vmovups %ymm2,-0x33b8(%rbp)
 1243c98:	ff 
 1243c99:	c5 fc 11 8d 30 cc ff 	vmovups %ymm1,-0x33d0(%rbp)
 1243ca0:	ff 
 1243ca1:	c5 fc 11 85 10 cc ff 	vmovups %ymm0,-0x33f0(%rbp)
 1243ca8:	ff 
 1243ca9:	48 8d bd 10 cc ff ff 	lea    -0x33f0(%rbp),%rdi
 1243cb0:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243cb4:	c5 f8 77             	vzeroupper 
 1243cb7:	e8 f4 16 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1243cbc:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1243cc3:	0f 84 07 08 00 00    	je     12444d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52b0>
 1243cc9:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1243cd0:	ff 
 1243cd1:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1243cd8:	ff 
 1243cd9:	c5 fc 11 8d 50 e5 ff 	vmovups %ymm1,-0x1ab0(%rbp)
 1243ce0:	ff 
 1243ce1:	c5 fc 11 85 40 e5 ff 	vmovups %ymm0,-0x1ac0(%rbp)
 1243ce8:	ff 
 1243ce9:	48 8d bd 40 e5 ff ff 	lea    -0x1ac0(%rbp),%rdi
 1243cf0:	e9 cf 07 00 00       	jmp    12444c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52a4>
 1243cf5:	4d 85 ff             	test   %r15,%r15
 1243cf8:	74 1a                	je     1243d14 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4af4>
 1243cfa:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243cfe:	48 8b 38             	mov    (%rax),%rdi
 1243d01:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243d05:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243d09:	4c 89 f6             	mov    %r14,%rsi
 1243d0c:	4c 89 fa             	mov    %r15,%rdx
 1243d0f:	31 c9                	xor    %ecx,%ecx
 1243d11:	ff 50 18             	call   *0x18(%rax)
 1243d14:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243d1b:	ff 
 1243d1c:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243d20:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243d25:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243d2c:	ff 
 1243d2d:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243d34:	ff 
 1243d35:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243d3c:	ff 
 1243d3d:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243d44:	ff 
 1243d45:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243d4a:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243d4f:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243d54:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243d58:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243d5f:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243d63:	c5 f8 77             	vzeroupper 
 1243d66:	e8 15 15 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243d6b:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243d72:	74 43                	je     1243db7 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4b97>
 1243d74:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1243d7b:	ff 
 1243d7c:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1243d83:	ff 
 1243d84:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1243d8b:	ff 
 1243d8c:	c5 fc 11 95 e8 cb ff 	vmovups %ymm2,-0x3418(%rbp)
 1243d93:	ff 
 1243d94:	c5 fc 11 8d d0 cb ff 	vmovups %ymm1,-0x3430(%rbp)
 1243d9b:	ff 
 1243d9c:	c5 fc 11 85 b0 cb ff 	vmovups %ymm0,-0x3450(%rbp)
 1243da3:	ff 
 1243da4:	48 8d bd b0 cb ff ff 	lea    -0x3450(%rbp),%rdi
 1243dab:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243daf:	c5 f8 77             	vzeroupper 
 1243db2:	e8 f9 15 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1243db7:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1243dbe:	0f 84 18 08 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 1243dc4:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1243dcb:	ff 
 1243dcc:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1243dd3:	ff 
 1243dd4:	c5 fc 11 8d 20 e5 ff 	vmovups %ymm1,-0x1ae0(%rbp)
 1243ddb:	ff 
 1243ddc:	c5 fc 11 85 10 e5 ff 	vmovups %ymm0,-0x1af0(%rbp)
 1243de3:	ff 
 1243de4:	48 8d bd 10 e5 ff ff 	lea    -0x1af0(%rbp),%rdi
 1243deb:	e9 e0 07 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 1243df0:	48 85 db             	test   %rbx,%rbx
 1243df3:	74 1a                	je     1243e0f <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4bef>
 1243df5:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243df9:	48 8b 38             	mov    (%rax),%rdi
 1243dfc:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243e00:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243e04:	4c 89 e6             	mov    %r12,%rsi
 1243e07:	48 89 da             	mov    %rbx,%rdx
 1243e0a:	31 c9                	xor    %ecx,%ecx
 1243e0c:	ff 50 18             	call   *0x18(%rax)
 1243e0f:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243e16:	ff 
 1243e17:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243e1b:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243e20:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243e27:	ff 
 1243e28:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243e2f:	ff 
 1243e30:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243e37:	ff 
 1243e38:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243e3f:	ff 
 1243e40:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243e45:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243e4a:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243e4f:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243e53:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243e5a:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243e5e:	c5 f8 77             	vzeroupper 
 1243e61:	e8 1a 14 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243e66:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243e6d:	74 43                	je     1243eb2 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4c92>
 1243e6f:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1243e76:	ff 
 1243e77:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1243e7e:	ff 
 1243e7f:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1243e86:	ff 
 1243e87:	c5 fc 11 95 88 cb ff 	vmovups %ymm2,-0x3478(%rbp)
 1243e8e:	ff 
 1243e8f:	c5 fc 11 8d 70 cb ff 	vmovups %ymm1,-0x3490(%rbp)
 1243e96:	ff 
 1243e97:	c5 fc 11 85 50 cb ff 	vmovups %ymm0,-0x34b0(%rbp)
 1243e9e:	ff 
 1243e9f:	48 8d bd 50 cb ff ff 	lea    -0x34b0(%rbp),%rdi
 1243ea6:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243eaa:	c5 f8 77             	vzeroupper 
 1243ead:	e8 fe 14 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1243eb2:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1243eb9:	0f 84 11 06 00 00    	je     12444d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52b0>
 1243ebf:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1243ec6:	ff 
 1243ec7:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1243ece:	ff 
 1243ecf:	c5 fc 11 8d f0 e4 ff 	vmovups %ymm1,-0x1b10(%rbp)
 1243ed6:	ff 
 1243ed7:	c5 fc 11 85 e0 e4 ff 	vmovups %ymm0,-0x1b20(%rbp)
 1243ede:	ff 
 1243edf:	48 8d bd e0 e4 ff ff 	lea    -0x1b20(%rbp),%rdi
 1243ee6:	e9 d9 05 00 00       	jmp    12444c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52a4>
 1243eeb:	4d 85 ff             	test   %r15,%r15
 1243eee:	74 1a                	je     1243f0a <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4cea>
 1243ef0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243ef4:	48 8b 38             	mov    (%rax),%rdi
 1243ef7:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243efb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243eff:	4c 89 f6             	mov    %r14,%rsi
 1243f02:	4c 89 fa             	mov    %r15,%rdx
 1243f05:	31 c9                	xor    %ecx,%ecx
 1243f07:	ff 50 18             	call   *0x18(%rax)
 1243f0a:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1243f11:	ff 
 1243f12:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1243f16:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1243f1b:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1243f22:	ff 
 1243f23:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1243f2a:	ff 
 1243f2b:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1243f32:	ff 
 1243f33:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1243f3a:	ff 
 1243f3b:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1243f40:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1243f45:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1243f4a:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1243f4e:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1243f55:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243f59:	c5 f8 77             	vzeroupper 
 1243f5c:	e8 1f 13 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1243f61:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1243f68:	74 43                	je     1243fad <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4d8d>
 1243f6a:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1243f71:	ff 
 1243f72:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1243f79:	ff 
 1243f7a:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1243f81:	ff 
 1243f82:	c5 fc 11 95 28 cb ff 	vmovups %ymm2,-0x34d8(%rbp)
 1243f89:	ff 
 1243f8a:	c5 fc 11 8d 10 cb ff 	vmovups %ymm1,-0x34f0(%rbp)
 1243f91:	ff 
 1243f92:	c5 fc 11 85 f0 ca ff 	vmovups %ymm0,-0x3510(%rbp)
 1243f99:	ff 
 1243f9a:	48 8d bd f0 ca ff ff 	lea    -0x3510(%rbp),%rdi
 1243fa1:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1243fa5:	c5 f8 77             	vzeroupper 
 1243fa8:	e8 03 14 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1243fad:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1243fb4:	0f 84 22 06 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 1243fba:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1243fc1:	ff 
 1243fc2:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1243fc9:	ff 
 1243fca:	c5 fc 11 8d c0 e4 ff 	vmovups %ymm1,-0x1b40(%rbp)
 1243fd1:	ff 
 1243fd2:	c5 fc 11 85 b0 e4 ff 	vmovups %ymm0,-0x1b50(%rbp)
 1243fd9:	ff 
 1243fda:	48 8d bd b0 e4 ff ff 	lea    -0x1b50(%rbp),%rdi
 1243fe1:	e9 ea 05 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 1243fe6:	4d 85 f6             	test   %r14,%r14
 1243fe9:	74 1a                	je     1244005 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4de5>
 1243feb:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 1243fef:	48 8b 38             	mov    (%rax),%rdi
 1243ff2:	48 8b 40 08          	mov    0x8(%rax),%rax
 1243ff6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1243ffa:	4c 89 fe             	mov    %r15,%rsi
 1243ffd:	4c 89 f2             	mov    %r14,%rdx
 1244000:	31 c9                	xor    %ecx,%ecx
 1244002:	ff 50 18             	call   *0x18(%rax)
 1244005:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 124400c:	ff 
 124400d:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1244011:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1244016:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124401d:	ff 
 124401e:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1244025:	ff 
 1244026:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 124402d:	ff 
 124402e:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1244035:	ff 
 1244036:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 124403b:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1244040:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1244045:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1244049:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1244050:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1244054:	c5 f8 77             	vzeroupper 
 1244057:	e8 24 12 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 124405c:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1244063:	74 43                	je     12440a8 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4e88>
 1244065:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 124406c:	ff 
 124406d:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1244074:	ff 
 1244075:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 124407c:	ff 
 124407d:	c5 fc 11 95 e8 d1 ff 	vmovups %ymm2,-0x2e18(%rbp)
 1244084:	ff 
 1244085:	c5 fc 11 8d d0 d1 ff 	vmovups %ymm1,-0x2e30(%rbp)
 124408c:	ff 
 124408d:	c5 fc 11 85 b0 d1 ff 	vmovups %ymm0,-0x2e50(%rbp)
 1244094:	ff 
 1244095:	48 8d bd b0 d1 ff ff 	lea    -0x2e50(%rbp),%rdi
 124409c:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12440a0:	c5 f8 77             	vzeroupper 
 12440a3:	e8 08 13 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12440a8:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12440af:	0f 84 27 05 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 12440b5:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12440bc:	ff 
 12440bd:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12440c4:	ff 
 12440c5:	c5 fc 11 8d 20 e8 ff 	vmovups %ymm1,-0x17e0(%rbp)
 12440cc:	ff 
 12440cd:	c5 fc 11 85 10 e8 ff 	vmovups %ymm0,-0x17f0(%rbp)
 12440d4:	ff 
 12440d5:	48 8d bd 10 e8 ff ff 	lea    -0x17f0(%rbp),%rdi
 12440dc:	e9 ef 04 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 12440e1:	4d 85 f6             	test   %r14,%r14
 12440e4:	74 1a                	je     1244100 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4ee0>
 12440e6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12440ea:	48 8b 38             	mov    (%rax),%rdi
 12440ed:	48 8b 40 08          	mov    0x8(%rax),%rax
 12440f1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12440f5:	4c 89 fe             	mov    %r15,%rsi
 12440f8:	4c 89 f2             	mov    %r14,%rdx
 12440fb:	31 c9                	xor    %ecx,%ecx
 12440fd:	ff 50 18             	call   *0x18(%rax)
 1244100:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1244107:	ff 
 1244108:	48 8b 45 10          	mov    0x10(%rbp),%rax
 124410c:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1244111:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1244118:	ff 
 1244119:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1244120:	ff 
 1244121:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1244128:	ff 
 1244129:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1244130:	ff 
 1244131:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1244136:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 124413b:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1244140:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1244144:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 124414b:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124414f:	c5 f8 77             	vzeroupper 
 1244152:	e8 29 11 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1244157:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 124415e:	74 43                	je     12441a3 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4f83>
 1244160:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1244167:	ff 
 1244168:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 124416f:	ff 
 1244170:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1244177:	ff 
 1244178:	c5 fc 11 95 a8 cf ff 	vmovups %ymm2,-0x3058(%rbp)
 124417f:	ff 
 1244180:	c5 fc 11 8d 90 cf ff 	vmovups %ymm1,-0x3070(%rbp)
 1244187:	ff 
 1244188:	c5 fc 11 85 70 cf ff 	vmovups %ymm0,-0x3090(%rbp)
 124418f:	ff 
 1244190:	48 8d bd 70 cf ff ff 	lea    -0x3090(%rbp),%rdi
 1244197:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124419b:	c5 f8 77             	vzeroupper 
 124419e:	e8 0d 12 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12441a3:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12441aa:	0f 84 2c 04 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 12441b0:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12441b7:	ff 
 12441b8:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12441bf:	ff 
 12441c0:	c5 fc 11 8d 00 e7 ff 	vmovups %ymm1,-0x1900(%rbp)
 12441c7:	ff 
 12441c8:	c5 fc 11 85 f0 e6 ff 	vmovups %ymm0,-0x1910(%rbp)
 12441cf:	ff 
 12441d0:	48 8d bd f0 e6 ff ff 	lea    -0x1910(%rbp),%rdi
 12441d7:	e9 f4 03 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 12441dc:	4d 85 ff             	test   %r15,%r15
 12441df:	74 1a                	je     12441fb <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x4fdb>
 12441e1:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12441e5:	48 8b 38             	mov    (%rax),%rdi
 12441e8:	48 8b 40 08          	mov    0x8(%rax),%rax
 12441ec:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12441f0:	48 89 de             	mov    %rbx,%rsi
 12441f3:	4c 89 fa             	mov    %r15,%rdx
 12441f6:	31 c9                	xor    %ecx,%ecx
 12441f8:	ff 50 18             	call   *0x18(%rax)
 12441fb:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1244202:	ff 
 1244203:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1244207:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 124420c:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1244213:	ff 
 1244214:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124421b:	ff 
 124421c:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1244223:	ff 
 1244224:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124422b:	ff 
 124422c:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1244231:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1244236:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 124423b:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 124423f:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1244246:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124424a:	c5 f8 77             	vzeroupper 
 124424d:	e8 2e 10 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1244252:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1244259:	74 43                	je     124429e <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x507e>
 124425b:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1244262:	ff 
 1244263:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 124426a:	ff 
 124426b:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1244272:	ff 
 1244273:	c5 fc 11 95 08 cd ff 	vmovups %ymm2,-0x32f8(%rbp)
 124427a:	ff 
 124427b:	c5 fc 11 8d f0 cc ff 	vmovups %ymm1,-0x3310(%rbp)
 1244282:	ff 
 1244283:	c5 fc 11 85 d0 cc ff 	vmovups %ymm0,-0x3330(%rbp)
 124428a:	ff 
 124428b:	48 8d bd d0 cc ff ff 	lea    -0x3330(%rbp),%rdi
 1244292:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1244296:	c5 f8 77             	vzeroupper 
 1244299:	e8 12 11 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 124429e:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12442a5:	0f 84 25 02 00 00    	je     12444d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52b0>
 12442ab:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12442b2:	ff 
 12442b3:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12442ba:	ff 
 12442bb:	c5 fc 11 8d b0 e5 ff 	vmovups %ymm1,-0x1a50(%rbp)
 12442c2:	ff 
 12442c3:	c5 fc 11 85 a0 e5 ff 	vmovups %ymm0,-0x1a60(%rbp)
 12442ca:	ff 
 12442cb:	48 8d bd a0 e5 ff ff 	lea    -0x1a60(%rbp),%rdi
 12442d2:	e9 ed 01 00 00       	jmp    12444c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52a4>
 12442d7:	4d 85 ed             	test   %r13,%r13
 12442da:	74 1a                	je     12442f6 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x50d6>
 12442dc:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12442e0:	48 8b 38             	mov    (%rax),%rdi
 12442e3:	48 8b 40 08          	mov    0x8(%rax),%rax
 12442e7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12442eb:	4c 89 e6             	mov    %r12,%rsi
 12442ee:	4c 89 ea             	mov    %r13,%rdx
 12442f1:	31 c9                	xor    %ecx,%ecx
 12442f3:	ff 50 18             	call   *0x18(%rax)
 12442f6:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 12442fd:	ff 
 12442fe:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1244302:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1244307:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 124430e:	ff 
 124430f:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1244316:	ff 
 1244317:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 124431e:	ff 
 124431f:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1244326:	ff 
 1244327:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 124432c:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1244331:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1244336:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 124433a:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1244341:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1244345:	c5 f8 77             	vzeroupper 
 1244348:	e8 33 0f 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 124434d:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 1244354:	74 43                	je     1244399 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x5179>
 1244356:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 124435d:	ff 
 124435e:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1244365:	ff 
 1244366:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 124436d:	ff 
 124436e:	c5 fc 11 95 c8 ca ff 	vmovups %ymm2,-0x3538(%rbp)
 1244375:	ff 
 1244376:	c5 fc 11 8d b0 ca ff 	vmovups %ymm1,-0x3550(%rbp)
 124437d:	ff 
 124437e:	c5 fc 11 85 90 ca ff 	vmovups %ymm0,-0x3570(%rbp)
 1244385:	ff 
 1244386:	48 8d bd 90 ca ff ff 	lea    -0x3570(%rbp),%rdi
 124438d:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1244391:	c5 f8 77             	vzeroupper 
 1244394:	e8 17 10 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1244399:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12443a0:	0f 84 36 02 00 00    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 12443a6:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12443ad:	ff 
 12443ae:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12443b5:	ff 
 12443b6:	c5 fc 11 8d 90 e4 ff 	vmovups %ymm1,-0x1b70(%rbp)
 12443bd:	ff 
 12443be:	c5 fc 11 85 80 e4 ff 	vmovups %ymm0,-0x1b80(%rbp)
 12443c5:	ff 
 12443c6:	48 8d bd 80 e4 ff ff 	lea    -0x1b80(%rbp),%rdi
 12443cd:	e9 fe 01 00 00       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>
 12443d2:	4d 85 ff             	test   %r15,%r15
 12443d5:	74 1a                	je     12443f1 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x51d1>
 12443d7:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12443db:	48 8b 38             	mov    (%rax),%rdi
 12443de:	48 8b 40 08          	mov    0x8(%rax),%rax
 12443e2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12443e6:	48 89 de             	mov    %rbx,%rsi
 12443e9:	4c 89 fa             	mov    %r15,%rdx
 12443ec:	31 c9                	xor    %ecx,%ecx
 12443ee:	ff 50 18             	call   *0x18(%rax)
 12443f1:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 12443f8:	ff 
 12443f9:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12443fd:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1244402:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1244409:	ff 
 124440a:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 1244411:	ff 
 1244412:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1244419:	ff 
 124441a:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 1244421:	ff 
 1244422:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1244427:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 124442c:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1244431:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1244435:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 124443c:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1244440:	c5 f8 77             	vzeroupper 
 1244443:	e8 38 0e 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1244448:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 124444f:	74 43                	je     1244494 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x5274>
 1244451:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1244458:	ff 
 1244459:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 1244460:	ff 
 1244461:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1244468:	ff 
 1244469:	c5 fc 11 95 68 ca ff 	vmovups %ymm2,-0x3598(%rbp)
 1244470:	ff 
 1244471:	c5 fc 11 8d 50 ca ff 	vmovups %ymm1,-0x35b0(%rbp)
 1244478:	ff 
 1244479:	c5 fc 11 85 30 ca ff 	vmovups %ymm0,-0x35d0(%rbp)
 1244480:	ff 
 1244481:	48 8d bd 30 ca ff ff 	lea    -0x35d0(%rbp),%rdi
 1244488:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124448c:	c5 f8 77             	vzeroupper 
 124448f:	e8 1c 0f 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1244494:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 124449b:	74 33                	je     12444d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52b0>
 124449d:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12444a4:	ff 
 12444a5:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12444ac:	ff 
 12444ad:	c5 fc 11 8d 60 e4 ff 	vmovups %ymm1,-0x1ba0(%rbp)
 12444b4:	ff 
 12444b5:	c5 fc 11 85 50 e4 ff 	vmovups %ymm0,-0x1bb0(%rbp)
 12444bc:	ff 
 12444bd:	48 8d bd 50 e4 ff ff 	lea    -0x1bb0(%rbp),%rdi
 12444c4:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12444c8:	c5 f8 77             	vzeroupper 
 12444cb:	e8 10 4e 01 00       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 12444d0:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 12444d4:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 12444d9:	e9 35 ea ff ff       	jmp    1242f13 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cf3>
 12444de:	4d 85 ed             	test   %r13,%r13
 12444e1:	74 1a                	je     12444fd <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x52dd>
 12444e3:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 12444e7:	48 8b 38             	mov    (%rax),%rdi
 12444ea:	48 8b 40 08          	mov    0x8(%rax),%rax
 12444ee:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12444f2:	4c 89 f6             	mov    %r14,%rsi
 12444f5:	4c 89 ea             	mov    %r13,%rdx
 12444f8:	31 c9                	xor    %ecx,%ecx
 12444fa:	ff 50 18             	call   *0x18(%rax)
 12444fd:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 1244504:	ff 
 1244505:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1244509:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 124450e:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 1244515:	ff 
 1244516:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 124451d:	ff 
 124451e:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 1244525:	ff 
 1244526:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 124452d:	ff 
 124452e:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1244533:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1244538:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 124453d:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1244541:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 1244548:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124454c:	c5 f8 77             	vzeroupper 
 124454f:	e8 2c 0d 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 1244554:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 124455b:	74 43                	je     12445a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x5380>
 124455d:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1244564:	ff 
 1244565:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 124456c:	ff 
 124456d:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1244574:	ff 
 1244575:	c5 fc 11 95 08 ca ff 	vmovups %ymm2,-0x35f8(%rbp)
 124457c:	ff 
 124457d:	c5 fc 11 8d f0 c9 ff 	vmovups %ymm1,-0x3610(%rbp)
 1244584:	ff 
 1244585:	c5 fc 11 85 d0 c9 ff 	vmovups %ymm0,-0x3630(%rbp)
 124458c:	ff 
 124458d:	48 8d bd d0 c9 ff ff 	lea    -0x3630(%rbp),%rdi
 1244594:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1244598:	c5 f8 77             	vzeroupper 
 124459b:	e8 10 0e 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12445a0:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12445a7:	74 33                	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 12445a9:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12445b0:	ff 
 12445b1:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 12445b8:	ff 
 12445b9:	c5 fc 11 8d 30 e4 ff 	vmovups %ymm1,-0x1bd0(%rbp)
 12445c0:	ff 
 12445c1:	c5 fc 11 85 20 e4 ff 	vmovups %ymm0,-0x1be0(%rbp)
 12445c8:	ff 
 12445c9:	48 8d bd 20 e4 ff ff 	lea    -0x1be0(%rbp),%rdi
 12445d0:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12445d4:	c5 f8 77             	vzeroupper 
 12445d7:	e8 04 4d 01 00       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 12445dc:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 12445e0:	66 89 58 10          	mov    %bx,0x10(%rax)
 12445e4:	e9 2a e9 ff ff       	jmp    1242f13 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cf3>
 12445e9:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 12445f0:	74 33                	je     1244625 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x5405>
 12445f2:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 12445f9:	ff 
 12445fa:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 1244601:	ff 
 1244602:	c5 fc 11 8d a0 e9 ff 	vmovups %ymm1,-0x1660(%rbp)
 1244609:	ff 
 124460a:	c5 fc 11 85 90 e9 ff 	vmovups %ymm0,-0x1670(%rbp)
 1244611:	ff 
 1244612:	48 8d bd 90 e9 ff ff 	lea    -0x1670(%rbp),%rdi
 1244619:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 124461d:	c5 f8 77             	vzeroupper 
 1244620:	e8 bb 4c 01 00       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 1244625:	c5 f8 10 05 73 ad e4 	vmovups -0x1b528d(%rip),%xmm0        # 108f3a0 <__anon_205612>
 124462c:	ff 
 124462d:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 1244631:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 1244635:	48 c7 40 10 1a 00 00 	movq   $0x1a,0x10(%rax)
 124463c:	00 
 124463d:	e9 d1 e8 ff ff       	jmp    1242f13 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cf3>
 1244642:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1244649:	74 33                	je     124467e <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x545e>
 124464b:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1244652:	ff 
 1244653:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 124465a:	ff 
 124465b:	c5 fc 11 8d 40 e9 ff 	vmovups %ymm1,-0x16c0(%rbp)
 1244662:	ff 
 1244663:	c5 fc 11 85 30 e9 ff 	vmovups %ymm0,-0x16d0(%rbp)
 124466a:	ff 
 124466b:	48 8d bd 30 e9 ff ff 	lea    -0x16d0(%rbp),%rdi
 1244672:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1244676:	c5 f8 77             	vzeroupper 
 1244679:	e8 62 4c 01 00       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 124467e:	c5 f8 10 05 32 ad e4 	vmovups -0x1b52ce(%rip),%xmm0        # 108f3b8 <__anon_205615>
 1244685:	ff 
 1244686:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 124468a:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 124468e:	48 c7 40 10 52 00 00 	movq   $0x52,0x10(%rax)
 1244695:	00 
 1244696:	e9 78 e8 ff ff       	jmp    1242f13 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x3cf3>
 124469b:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 12446a2:	ff 
 12446a3:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12446a7:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12446ac:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 12446b3:	ff 
 12446b4:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 12446bb:	ff 
 12446bc:	c5 fc 10 95 d0 fe ff 	vmovups -0x130(%rbp),%ymm2
 12446c3:	ff 
 12446c4:	c5 fc 10 9d f0 fe ff 	vmovups -0x110(%rbp),%ymm3
 12446cb:	ff 
 12446cc:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12446d1:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12446d6:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12446db:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12446df:	48 8d bd 50 dd ff ff 	lea    -0x22b0(%rbp),%rdi
 12446e6:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 12446ea:	c5 f8 77             	vzeroupper 
 12446ed:	e8 8e 0b 00 00       	call   1245280 <br.EntropySymbolSplits.deinit>
 12446f2:	80 bd 88 fe ff ff 00 	cmpb   $0x0,-0x178(%rbp)
 12446f9:	74 43                	je     124473e <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x551e>
 12446fb:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 1244702:	ff 
 1244703:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 124470a:	ff 
 124470b:	c5 fc 10 95 68 fe ff 	vmovups -0x198(%rbp),%ymm2
 1244712:	ff 
 1244713:	c5 fc 11 95 48 d2 ff 	vmovups %ymm2,-0x2db8(%rbp)
 124471a:	ff 
 124471b:	c5 fc 11 8d 30 d2 ff 	vmovups %ymm1,-0x2dd0(%rbp)
 1244722:	ff 
 1244723:	c5 fc 11 85 10 d2 ff 	vmovups %ymm0,-0x2df0(%rbp)
 124472a:	ff 
 124472b:	48 8d bd 10 d2 ff ff 	lea    -0x2df0(%rbp),%rdi
 1244732:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1244736:	c5 f8 77             	vzeroupper 
 1244739:	e8 72 0c 00 00       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 124473e:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 1244745:	0f 84 91 fe ff ff    	je     12445dc <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53bc>
 124474b:	c5 fc 10 85 30 ff ff 	vmovups -0xd0(%rbp),%ymm0
 1244752:	ff 
 1244753:	c5 fc 10 8d 40 ff ff 	vmovups -0xc0(%rbp),%ymm1
 124475a:	ff 
 124475b:	c5 fc 11 8d 50 e8 ff 	vmovups %ymm1,-0x17b0(%rbp)
 1244762:	ff 
 1244763:	c5 fc 11 85 40 e8 ff 	vmovups %ymm0,-0x17c0(%rbp)
 124476a:	ff 
 124476b:	48 8d bd 40 e8 ff ff 	lea    -0x17c0(%rbp),%rdi
 1244772:	e9 59 fe ff ff       	jmp    12445d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540+0x53b0>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
