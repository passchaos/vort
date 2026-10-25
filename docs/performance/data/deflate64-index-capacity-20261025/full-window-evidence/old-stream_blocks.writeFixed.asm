
/tmp/vort-deflate64-index-capacity-20261025/old-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

0000000001091260 <deflate64.stream_blocks.writeFixed>:
 1091260:	55                   	push   %rbp
 1091261:	48 89 e5             	mov    %rsp,%rbp
 1091264:	41 57                	push   %r15
 1091266:	41 56                	push   %r14
 1091268:	41 55                	push   %r13
 109126a:	41 54                	push   %r12
 109126c:	53                   	push   %rbx
 109126d:	48 83 ec 28          	sub    $0x28,%rsp
 1091271:	4d 89 cc             	mov    %r9,%r12
 1091274:	4c 89 45 c0          	mov    %r8,-0x40(%rbp)
 1091278:	48 89 4d c8          	mov    %rcx,-0x38(%rbp)
 109127c:	49 89 f5             	mov    %rsi,%r13
 109127f:	48 89 fb             	mov    %rdi,%rbx
 1091282:	0f b6 45 20          	movzbl 0x20(%rbp),%eax
 1091286:	83 e0 01             	and    $0x1,%eax
 1091289:	83 c8 02             	or     $0x2,%eax
 109128c:	0f b6 4f 1c          	movzbl 0x1c(%rdi),%ecx
 1091290:	80 e1 07             	and    $0x7,%cl
 1091293:	c4 e2 71 f7 c0       	shlx   %ecx,%eax,%eax
 1091298:	0b 47 18             	or     0x18(%rdi),%eax
 109129b:	89 47 18             	mov    %eax,0x18(%rdi)
 109129e:	80 c1 03             	add    $0x3,%cl
 10912a1:	88 4d d7             	mov    %cl,-0x29(%rbp)
 10912a4:	f6 c1 08             	test   $0x8,%cl
 10912a7:	0f 84 41 06 00 00    	je     10918ee <deflate64.stream_blocks.writeFixed+0x68e>
 10912ad:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 10912b1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10912b8:	0f 1f 84 00 00 00 00 
 10912bf:	00 
 10912c0:	48 8b 3b             	mov    (%rbx),%rdi
 10912c3:	88 04 37             	mov    %al,(%rdi,%rsi,1)
 10912c6:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 10912ca:	48 ff c6             	inc    %rsi
 10912cd:	48 89 73 10          	mov    %rsi,0x10(%rbx)
 10912d1:	8b 43 18             	mov    0x18(%rbx),%eax
 10912d4:	c1 e8 08             	shr    $0x8,%eax
 10912d7:	89 43 18             	mov    %eax,0x18(%rbx)
 10912da:	80 c1 18             	add    $0x18,%cl
 10912dd:	89 cf                	mov    %ecx,%edi
 10912df:	40 80 e7 1f          	and    $0x1f,%dil
 10912e3:	40 88 7d d7          	mov    %dil,-0x29(%rbp)
 10912e7:	f6 c1 18             	test   $0x18,%cl
 10912ea:	89 f9                	mov    %edi,%ecx
 10912ec:	75 d2                	jne    10912c0 <deflate64.stream_blocks.writeFixed+0x60>
 10912ee:	40 80 e7 07          	and    $0x7,%dil
 10912f2:	40 88 7b 1c          	mov    %dil,0x1c(%rbx)
 10912f6:	4d 85 e4             	test   %r12,%r12
 10912f9:	0f 84 02 06 00 00    	je     1091901 <deflate64.stream_blocks.writeFixed+0x6a1>
 10912ff:	49 89 55 20          	mov    %rdx,0x20(%r13)
 1091303:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 1091307:	4d 89 75 28          	mov    %r14,0x28(%r13)
 109130b:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 109130f:	49 89 45 30          	mov    %rax,0x30(%r13)
 1091313:	4d 89 65 38          	mov    %r12,0x38(%r13)
 1091317:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 109131b:	ba 00 00 02 00       	mov    $0x20000,%edx
 1091320:	be ff 00 00 00       	mov    $0xff,%esi
 1091325:	e8 96 2d 04 00       	call   10d40c0 <compiler_rt.memset>
 109132a:	4d 85 f6             	test   %r14,%r14
 109132d:	0f 84 c2 00 00 00    	je     10913f5 <deflate64.stream_blocks.writeFixed+0x195>
 1091333:	31 c0                	xor    %eax,%eax
 1091335:	eb 47                	jmp    109137e <deflate64.stream_blocks.writeFixed+0x11e>
 1091337:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 109133e:	00 00 
 1091340:	49 03 7d 30          	add    0x30(%r13),%rdi
 1091344:	0f b6 09             	movzbl (%rcx),%ecx
 1091347:	0f b6 16             	movzbl (%rsi),%edx
 109134a:	c1 e1 10             	shl    $0x10,%ecx
 109134d:	c1 e2 08             	shl    $0x8,%edx
 1091350:	09 ca                	or     %ecx,%edx
 1091352:	0f b6 0f             	movzbl (%rdi),%ecx
 1091355:	09 d1                	or     %edx,%ecx
 1091357:	69 c9 bd a7 35 1e    	imul   $0x1e35a7bd,%ecx,%ecx
 109135d:	49 8b 55 00          	mov    0x0(%r13),%rdx
 1091361:	49 8b 75 10          	mov    0x10(%r13),%rsi
 1091365:	c1 e9 11             	shr    $0x11,%ecx
 1091368:	8b 14 8a             	mov    (%rdx,%rcx,4),%edx
 109136b:	89 14 86             	mov    %edx,(%rsi,%rax,4)
 109136e:	49 8b 55 00          	mov    0x0(%r13),%rdx
 1091372:	89 04 8a             	mov    %eax,(%rdx,%rcx,4)
 1091375:	48 ff c0             	inc    %rax
 1091378:	48 39 45 c8          	cmp    %rax,-0x38(%rbp)
 109137c:	74 77                	je     10913f5 <deflate64.stream_blocks.writeFixed+0x195>
 109137e:	48 8d 48 03          	lea    0x3(%rax),%rcx
 1091382:	49 8b 55 28          	mov    0x28(%r13),%rdx
 1091386:	49 8b 75 38          	mov    0x38(%r13),%rsi
 109138a:	48 01 d6             	add    %rdx,%rsi
 109138d:	48 39 f1             	cmp    %rsi,%rcx
 1091390:	77 e3                	ja     1091375 <deflate64.stream_blocks.writeFixed+0x115>
 1091392:	48 89 c1             	mov    %rax,%rcx
 1091395:	48 29 d1             	sub    %rdx,%rcx
 1091398:	73 26                	jae    10913c0 <deflate64.stream_blocks.writeFixed+0x160>
 109139a:	49 8b 4d 20          	mov    0x20(%r13),%rcx
 109139e:	48 01 c1             	add    %rax,%rcx
 10913a1:	48 8d 70 01          	lea    0x1(%rax),%rsi
 10913a5:	48 29 d6             	sub    %rdx,%rsi
 10913a8:	72 23                	jb     10913cd <deflate64.stream_blocks.writeFixed+0x16d>
 10913aa:	49 03 75 30          	add    0x30(%r13),%rsi
 10913ae:	48 8d 78 02          	lea    0x2(%rax),%rdi
 10913b2:	48 29 d7             	sub    %rdx,%rdi
 10913b5:	73 89                	jae    1091340 <deflate64.stream_blocks.writeFixed+0xe0>
 10913b7:	eb 2b                	jmp    10913e4 <deflate64.stream_blocks.writeFixed+0x184>
 10913b9:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 10913c0:	49 03 4d 30          	add    0x30(%r13),%rcx
 10913c4:	48 8d 70 01          	lea    0x1(%rax),%rsi
 10913c8:	48 29 d6             	sub    %rdx,%rsi
 10913cb:	73 dd                	jae    10913aa <deflate64.stream_blocks.writeFixed+0x14a>
 10913cd:	49 8b 75 20          	mov    0x20(%r13),%rsi
 10913d1:	48 01 c6             	add    %rax,%rsi
 10913d4:	48 ff c6             	inc    %rsi
 10913d7:	48 8d 78 02          	lea    0x2(%rax),%rdi
 10913db:	48 29 d7             	sub    %rdx,%rdi
 10913de:	0f 83 5c ff ff ff    	jae    1091340 <deflate64.stream_blocks.writeFixed+0xe0>
 10913e4:	49 8b 55 20          	mov    0x20(%r13),%rdx
 10913e8:	48 8d 3c 02          	lea    (%rdx,%rax,1),%rdi
 10913ec:	48 83 c7 02          	add    $0x2,%rdi
 10913f0:	e9 4f ff ff ff       	jmp    1091344 <deflate64.stream_blocks.writeFixed+0xe4>
 10913f5:	45 31 f6             	xor    %r14d,%r14d
 10913f8:	eb 12                	jmp    109140c <deflate64.stream_blocks.writeFixed+0x1ac>
 10913fa:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 1091400:	49 01 c6             	add    %rax,%r14
 1091403:	4d 39 e6             	cmp    %r12,%r14
 1091406:	0f 83 86 04 00 00    	jae    1091892 <deflate64.stream_blocks.writeFixed+0x632>
 109140c:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1091410:	4d 8d 3c 06          	lea    (%r14,%rax,1),%r15
 1091414:	48 8d 7d b0          	lea    -0x50(%rbp),%rdi
 1091418:	4c 89 ee             	mov    %r13,%rsi
 109141b:	4c 89 fa             	mov    %r15,%rdx
 109141e:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 1091422:	4c 8b 45 18          	mov    0x18(%rbp),%r8
 1091426:	e8 45 05 00 00       	call   1091970 <deflate64.stream_match.Matcher.find>
 109142b:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 109142f:	48 83 fe 03          	cmp    $0x3,%rsi
 1091433:	b8 01 00 00 00       	mov    $0x1,%eax
 1091438:	48 0f 43 c6          	cmovae %rsi,%rax
 109143c:	72 22                	jb     1091460 <deflate64.stream_blocks.writeFixed+0x200>
 109143e:	48 8d 4e fd          	lea    -0x3(%rsi),%rcx
 1091442:	48 81 fe 03 01 00 00 	cmp    $0x103,%rsi
 1091449:	0f 82 91 00 00 00    	jb     10914e0 <deflate64.stream_blocks.writeFixed+0x280>
 109144f:	c6 45 d6 10          	movb   $0x10,-0x2a(%rbp)
 1091453:	be 1d 01 00 00       	mov    $0x11d,%esi
 1091458:	e9 e2 00 00 00       	jmp    109153f <deflate64.stream_blocks.writeFixed+0x2df>
 109145d:	0f 1f 00             	nopl   (%rax)
 1091460:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 1091464:	42 0f b6 0c 31       	movzbl (%rcx,%r14,1),%ecx
 1091469:	0f b7 94 09 4a 18 01 	movzwl 0x101184a(%rcx,%rcx,1),%edx
 1091470:	01 
 1091471:	0f b6 b1 8a 1a 01 01 	movzbl 0x1011a8a(%rcx),%esi
 1091478:	40 80 e6 0f          	and    $0xf,%sil
 109147c:	0f b6 4b 1c          	movzbl 0x1c(%rbx),%ecx
 1091480:	80 e1 07             	and    $0x7,%cl
 1091483:	c4 e2 71 f7 d2       	shlx   %ecx,%edx,%edx
 1091488:	0b 53 18             	or     0x18(%rbx),%edx
 109148b:	89 53 18             	mov    %edx,0x18(%rbx)
 109148e:	40 00 f1             	add    %sil,%cl
 1091491:	88 4d d7             	mov    %cl,-0x29(%rbp)
 1091494:	f6 c1 18             	test   $0x18,%cl
 1091497:	74 5c                	je     10914f5 <deflate64.stream_blocks.writeFixed+0x295>
 1091499:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 109149d:	0f 1f 00             	nopl   (%rax)
 10914a0:	48 8b 3b             	mov    (%rbx),%rdi
 10914a3:	88 14 37             	mov    %dl,(%rdi,%rsi,1)
 10914a6:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 10914aa:	48 ff c6             	inc    %rsi
 10914ad:	48 89 73 10          	mov    %rsi,0x10(%rbx)
 10914b1:	8b 53 18             	mov    0x18(%rbx),%edx
 10914b4:	c1 ea 08             	shr    $0x8,%edx
 10914b7:	89 53 18             	mov    %edx,0x18(%rbx)
 10914ba:	80 c1 18             	add    $0x18,%cl
 10914bd:	89 cf                	mov    %ecx,%edi
 10914bf:	40 80 e7 1f          	and    $0x1f,%dil
 10914c3:	40 88 7d d7          	mov    %dil,-0x29(%rbp)
 10914c7:	f6 c1 18             	test   $0x18,%cl
 10914ca:	89 f9                	mov    %edi,%ecx
 10914cc:	75 d2                	jne    10914a0 <deflate64.stream_blocks.writeFixed+0x240>
 10914ce:	e9 bd 02 00 00       	jmp    1091790 <deflate64.stream_blocks.writeFixed+0x530>
 10914d3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10914da:	84 00 00 00 00 00 
 10914e0:	48 83 fe 0a          	cmp    $0xa,%rsi
 10914e4:	77 16                	ja     10914fc <deflate64.stream_blocks.writeFixed+0x29c>
 10914e6:	48 81 c6 fe 00 00 00 	add    $0xfe,%rsi
 10914ed:	c6 45 d6 00          	movb   $0x0,-0x2a(%rbp)
 10914f1:	31 c9                	xor    %ecx,%ecx
 10914f3:	eb 4a                	jmp    109153f <deflate64.stream_blocks.writeFixed+0x2df>
 10914f5:	89 cf                	mov    %ecx,%edi
 10914f7:	e9 94 02 00 00       	jmp    1091790 <deflate64.stream_blocks.writeFixed+0x530>
 10914fc:	f3 48 0f bd d1       	lzcnt  %rcx,%rdx
 1091501:	f6 d2                	not    %dl
 1091503:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 109150a:	c4 e2 e9 f7 fe       	shlx   %rdx,%rsi,%rdi
 109150f:	80 c2 3e             	add    $0x3e,%dl
 1091512:	48 01 cf             	add    %rcx,%rdi
 1091515:	0f b6 ca             	movzbl %dl,%ecx
 1091518:	89 ca                	mov    %ecx,%edx
 109151a:	83 e2 3f             	and    $0x3f,%edx
 109151d:	c4 e2 f3 f7 f7       	shrx   %rcx,%rdi,%rsi
 1091522:	41 89 c8             	mov    %ecx,%r8d
 1091525:	41 80 e0 3f          	and    $0x3f,%r8b
 1091529:	48 8d 34 96          	lea    (%rsi,%rdx,4),%rsi
 109152d:	48 81 c6 05 01 00 00 	add    $0x105,%rsi
 1091534:	80 e1 1f             	and    $0x1f,%cl
 1091537:	88 4d d6             	mov    %cl,-0x2a(%rbp)
 109153a:	c4 e2 38 f5 cf       	bzhi   %r8d,%edi,%ecx
 109153f:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 1091543:	0f b6 7d d6          	movzbl -0x2a(%rbp),%edi
 1091547:	0f b7 f6             	movzwl %si,%esi
 109154a:	41 89 f0             	mov    %esi,%r8d
 109154d:	47 0f b7 84 00 4a 18 	movzwl 0x101184a(%r8,%r8,1),%r8d
 1091554:	01 01 
 1091556:	44 0f b6 8e 8a 1a 01 	movzbl 0x1011a8a(%rsi),%r9d
 109155d:	01 
 109155e:	41 80 e1 0f          	and    $0xf,%r9b
 1091562:	0f b6 73 1c          	movzbl 0x1c(%rbx),%esi
 1091566:	40 80 e6 07          	and    $0x7,%sil
 109156a:	c4 42 49 f7 c0       	shlx   %esi,%r8d,%r8d
 109156f:	44 0b 43 18          	or     0x18(%rbx),%r8d
 1091573:	44 89 43 18          	mov    %r8d,0x18(%rbx)
 1091577:	44 00 ce             	add    %r9b,%sil
 109157a:	40 88 75 d7          	mov    %sil,-0x29(%rbp)
 109157e:	40 f6 c6 18          	test   $0x18,%sil
 1091582:	74 44                	je     10915c8 <deflate64.stream_blocks.writeFixed+0x368>
 1091584:	4c 8b 4b 10          	mov    0x10(%rbx),%r9
 1091588:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 109158f:	00 
 1091590:	4c 8b 13             	mov    (%rbx),%r10
 1091593:	47 88 04 0a          	mov    %r8b,(%r10,%r9,1)
 1091597:	4c 8b 4b 10          	mov    0x10(%rbx),%r9
 109159b:	49 ff c1             	inc    %r9
 109159e:	4c 89 4b 10          	mov    %r9,0x10(%rbx)
 10915a2:	44 8b 43 18          	mov    0x18(%rbx),%r8d
 10915a6:	41 c1 e8 08          	shr    $0x8,%r8d
 10915aa:	44 89 43 18          	mov    %r8d,0x18(%rbx)
 10915ae:	40 80 c6 18          	add    $0x18,%sil
 10915b2:	41 89 f2             	mov    %esi,%r10d
 10915b5:	41 80 e2 1f          	and    $0x1f,%r10b
 10915b9:	44 88 55 d7          	mov    %r10b,-0x29(%rbp)
 10915bd:	40 f6 c6 18          	test   $0x18,%sil
 10915c1:	44 89 d6             	mov    %r10d,%esi
 10915c4:	75 ca                	jne    1091590 <deflate64.stream_blocks.writeFixed+0x330>
 10915c6:	eb 03                	jmp    10915cb <deflate64.stream_blocks.writeFixed+0x36b>
 10915c8:	41 89 f2             	mov    %esi,%r10d
 10915cb:	41 80 e2 07          	and    $0x7,%r10b
 10915cf:	44 88 53 1c          	mov    %r10b,0x1c(%rbx)
 10915d3:	0f b7 c9             	movzwl %cx,%ecx
 10915d6:	44 0f b6 4b 1c       	movzbl 0x1c(%rbx),%r9d
 10915db:	41 80 e1 07          	and    $0x7,%r9b
 10915df:	c4 e2 31 f7 f1       	shlx   %r9d,%ecx,%esi
 10915e4:	44 09 c6             	or     %r8d,%esi
 10915e7:	89 73 18             	mov    %esi,0x18(%rbx)
 10915ea:	41 00 f9             	add    %dil,%r9b
 10915ed:	44 89 c9             	mov    %r9d,%ecx
 10915f0:	80 e1 1f             	and    $0x1f,%cl
 10915f3:	88 4d d7             	mov    %cl,-0x29(%rbp)
 10915f6:	41 f6 c1 18          	test   $0x18,%r9b
 10915fa:	74 50                	je     109164c <deflate64.stream_blocks.writeFixed+0x3ec>
 10915fc:	48 8b 7b 10          	mov    0x10(%rbx),%rdi
 1091600:	4c 8b 03             	mov    (%rbx),%r8
 1091603:	41 88 34 38          	mov    %sil,(%r8,%rdi,1)
 1091607:	48 8b 7b 10          	mov    0x10(%rbx),%rdi
 109160b:	48 ff c7             	inc    %rdi
 109160e:	48 89 7b 10          	mov    %rdi,0x10(%rbx)
 1091612:	8b 73 18             	mov    0x18(%rbx),%esi
 1091615:	c1 ee 08             	shr    $0x8,%esi
 1091618:	89 73 18             	mov    %esi,0x18(%rbx)
 109161b:	80 c1 18             	add    $0x18,%cl
 109161e:	41 89 c8             	mov    %ecx,%r8d
 1091621:	41 80 e0 1f          	and    $0x1f,%r8b
 1091625:	44 88 45 d7          	mov    %r8b,-0x29(%rbp)
 1091629:	f6 c1 18             	test   $0x18,%cl
 109162c:	44 89 c1             	mov    %r8d,%ecx
 109162f:	75 cf                	jne    1091600 <deflate64.stream_blocks.writeFixed+0x3a0>
 1091631:	41 80 e0 07          	and    $0x7,%r8b
 1091635:	44 88 43 1c          	mov    %r8b,0x1c(%rbx)
 1091639:	48 83 fa 04          	cmp    $0x4,%rdx
 109163d:	77 1e                	ja     109165d <deflate64.stream_blocks.writeFixed+0x3fd>
 109163f:	48 81 c2 ff ff 00 00 	add    $0xffff,%rdx
 1091646:	31 ff                	xor    %edi,%edi
 1091648:	31 c9                	xor    %ecx,%ecx
 109164a:	eb 50                	jmp    109169c <deflate64.stream_blocks.writeFixed+0x43c>
 109164c:	41 89 c8             	mov    %ecx,%r8d
 109164f:	41 80 e0 07          	and    $0x7,%r8b
 1091653:	44 88 43 1c          	mov    %r8b,0x1c(%rbx)
 1091657:	48 83 fa 04          	cmp    $0x4,%rdx
 109165b:	76 e2                	jbe    109163f <deflate64.stream_blocks.writeFixed+0x3df>
 109165d:	48 8d 4a ff          	lea    -0x1(%rdx),%rcx
 1091661:	f3 48 0f bd c9       	lzcnt  %rcx,%rcx
 1091666:	f6 d1                	not    %cl
 1091668:	8d 79 3f             	lea    0x3f(%rcx),%edi
 109166b:	49 c7 c0 fe ff ff ff 	mov    $0xfffffffffffffffe,%r8
 1091672:	49 d3 c0             	rol    %cl,%r8
 1091675:	49 01 d0             	add    %rdx,%r8
 1091678:	8d 0c 3f             	lea    (%rdi,%rdi,1),%ecx
 109167b:	0f b6 c9             	movzbl %cl,%ecx
 109167e:	83 e1 3e             	and    $0x3e,%ecx
 1091681:	c4 c2 c3 f7 d0       	shrx   %rdi,%r8,%rdx
 1091686:	41 89 f9             	mov    %edi,%r9d
 1091689:	41 80 e1 3f          	and    $0x3f,%r9b
 109168d:	48 01 ca             	add    %rcx,%rdx
 1091690:	48 83 c2 02          	add    $0x2,%rdx
 1091694:	c4 c2 30 f5 c8       	bzhi   %r9d,%r8d,%ecx
 1091699:	0f b7 c9             	movzwl %cx,%ecx
 109169c:	40 80 e7 1f          	and    $0x1f,%dil
 10916a0:	40 88 7d d4          	mov    %dil,-0x2c(%rbp)
 10916a4:	0f b7 d2             	movzwl %dx,%edx
 10916a7:	0f b7 94 12 0a 18 01 	movzwl 0x101180a(%rdx,%rdx,1),%edx
 10916ae:	01 
 10916af:	44 0f b6 43 1c       	movzbl 0x1c(%rbx),%r8d
 10916b4:	41 80 e0 07          	and    $0x7,%r8b
 10916b8:	c4 e2 39 f7 d2       	shlx   %r8d,%edx,%edx
 10916bd:	09 f2                	or     %esi,%edx
 10916bf:	89 53 18             	mov    %edx,0x18(%rbx)
 10916c2:	41 80 c0 05          	add    $0x5,%r8b
 10916c6:	44 88 45 d7          	mov    %r8b,-0x29(%rbp)
 10916ca:	41 f6 c0 08          	test   $0x8,%r8b
 10916ce:	74 45                	je     1091715 <deflate64.stream_blocks.writeFixed+0x4b5>
 10916d0:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 10916d4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 10916db:	00 00 00 00 00 
 10916e0:	4c 8b 0b             	mov    (%rbx),%r9
 10916e3:	41 88 14 31          	mov    %dl,(%r9,%rsi,1)
 10916e7:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 10916eb:	48 ff c6             	inc    %rsi
 10916ee:	48 89 73 10          	mov    %rsi,0x10(%rbx)
 10916f2:	8b 53 18             	mov    0x18(%rbx),%edx
 10916f5:	c1 ea 08             	shr    $0x8,%edx
 10916f8:	89 53 18             	mov    %edx,0x18(%rbx)
 10916fb:	41 80 c0 18          	add    $0x18,%r8b
 10916ff:	45 89 c1             	mov    %r8d,%r9d
 1091702:	41 80 e1 1f          	and    $0x1f,%r9b
 1091706:	44 88 4d d7          	mov    %r9b,-0x29(%rbp)
 109170a:	41 f6 c0 18          	test   $0x18,%r8b
 109170e:	45 89 c8             	mov    %r9d,%r8d
 1091711:	75 cd                	jne    10916e0 <deflate64.stream_blocks.writeFixed+0x480>
 1091713:	eb 03                	jmp    1091718 <deflate64.stream_blocks.writeFixed+0x4b8>
 1091715:	45 89 c1             	mov    %r8d,%r9d
 1091718:	41 80 e1 07          	and    $0x7,%r9b
 109171c:	44 88 4b 1c          	mov    %r9b,0x1c(%rbx)
 1091720:	0f b6 73 1c          	movzbl 0x1c(%rbx),%esi
 1091724:	40 80 e6 07          	and    $0x7,%sil
 1091728:	c4 e2 49 f7 c9       	shlx   %esi,%ecx,%ecx
 109172d:	09 d1                	or     %edx,%ecx
 109172f:	89 4b 18             	mov    %ecx,0x18(%rbx)
 1091732:	40 00 fe             	add    %dil,%sil
 1091735:	89 f2                	mov    %esi,%edx
 1091737:	80 e2 1f             	and    $0x1f,%dl
 109173a:	88 55 d7             	mov    %dl,-0x29(%rbp)
 109173d:	40 f6 c6 18          	test   $0x18,%sil
 1091741:	74 3d                	je     1091780 <deflate64.stream_blocks.writeFixed+0x520>
 1091743:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 1091747:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 109174e:	00 00 
 1091750:	48 8b 3b             	mov    (%rbx),%rdi
 1091753:	88 0c 37             	mov    %cl,(%rdi,%rsi,1)
 1091756:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 109175a:	48 ff c6             	inc    %rsi
 109175d:	48 89 73 10          	mov    %rsi,0x10(%rbx)
 1091761:	8b 4b 18             	mov    0x18(%rbx),%ecx
 1091764:	c1 e9 08             	shr    $0x8,%ecx
 1091767:	89 4b 18             	mov    %ecx,0x18(%rbx)
 109176a:	80 c2 18             	add    $0x18,%dl
 109176d:	89 d7                	mov    %edx,%edi
 109176f:	40 80 e7 1f          	and    $0x1f,%dil
 1091773:	40 88 7d d7          	mov    %dil,-0x29(%rbp)
 1091777:	f6 c2 18             	test   $0x18,%dl
 109177a:	89 fa                	mov    %edi,%edx
 109177c:	75 d2                	jne    1091750 <deflate64.stream_blocks.writeFixed+0x4f0>
 109177e:	eb 10                	jmp    1091790 <deflate64.stream_blocks.writeFixed+0x530>
 1091780:	89 d7                	mov    %edx,%edi
 1091782:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1091789:	1f 84 00 00 00 00 00 
 1091790:	40 80 e7 07          	and    $0x7,%dil
 1091794:	40 88 7b 1c          	mov    %dil,0x1c(%rbx)
 1091798:	31 c9                	xor    %ecx,%ecx
 109179a:	eb 56                	jmp    10917f2 <deflate64.stream_blocks.writeFixed+0x592>
 109179c:	0f 1f 40 00          	nopl   0x0(%rax)
 10917a0:	4c 8d 4a 02          	lea    0x2(%rdx),%r9
 10917a4:	49 29 f9             	sub    %rdi,%r9
 10917a7:	4d 03 4d 30          	add    0x30(%r13),%r9
 10917ab:	0f b6 36             	movzbl (%rsi),%esi
 10917ae:	41 0f b6 38          	movzbl (%r8),%edi
 10917b2:	c1 e6 10             	shl    $0x10,%esi
 10917b5:	c1 e7 08             	shl    $0x8,%edi
 10917b8:	09 f7                	or     %esi,%edi
 10917ba:	41 0f b6 31          	movzbl (%r9),%esi
 10917be:	09 fe                	or     %edi,%esi
 10917c0:	69 f6 bd a7 35 1e    	imul   $0x1e35a7bd,%esi,%esi
 10917c6:	0f b7 d2             	movzwl %dx,%edx
 10917c9:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 10917cd:	4d 8b 45 10          	mov    0x10(%r13),%r8
 10917d1:	c1 ee 11             	shr    $0x11,%esi
 10917d4:	8b 3c b7             	mov    (%rdi,%rsi,4),%edi
 10917d7:	41 89 3c 90          	mov    %edi,(%r8,%rdx,4)
 10917db:	49 8b 55 00          	mov    0x0(%r13),%rdx
 10917df:	41 8d 3c 0f          	lea    (%r15,%rcx,1),%edi
 10917e3:	89 3c b2             	mov    %edi,(%rdx,%rsi,4)
 10917e6:	48 ff c1             	inc    %rcx
 10917e9:	48 39 c8             	cmp    %rcx,%rax
 10917ec:	0f 84 0e fc ff ff    	je     1091400 <deflate64.stream_blocks.writeFixed+0x1a0>
 10917f2:	4a 8d 14 39          	lea    (%rcx,%r15,1),%rdx
 10917f6:	48 83 c2 03          	add    $0x3,%rdx
 10917fa:	49 8b 7d 28          	mov    0x28(%r13),%rdi
 10917fe:	49 8b 75 38          	mov    0x38(%r13),%rsi
 1091802:	48 01 fe             	add    %rdi,%rsi
 1091805:	48 39 f2             	cmp    %rsi,%rdx
 1091808:	77 dc                	ja     10917e6 <deflate64.stream_blocks.writeFixed+0x586>
 109180a:	4a 8d 14 39          	lea    (%rcx,%r15,1),%rdx
 109180e:	48 89 d6             	mov    %rdx,%rsi
 1091811:	48 29 fe             	sub    %rdi,%rsi
 1091814:	73 3a                	jae    1091850 <deflate64.stream_blocks.writeFixed+0x5f0>
 1091816:	49 8b 75 20          	mov    0x20(%r13),%rsi
 109181a:	4c 01 fe             	add    %r15,%rsi
 109181d:	48 01 ce             	add    %rcx,%rsi
 1091820:	4d 8d 04 0f          	lea    (%r15,%rcx,1),%r8
 1091824:	49 ff c0             	inc    %r8
 1091827:	49 39 f8             	cmp    %rdi,%r8
 109182a:	72 34                	jb     1091860 <deflate64.stream_blocks.writeFixed+0x600>
 109182c:	4c 8d 42 01          	lea    0x1(%rdx),%r8
 1091830:	49 29 f8             	sub    %rdi,%r8
 1091833:	4d 03 45 30          	add    0x30(%r13),%r8
 1091837:	4d 8d 0c 0f          	lea    (%r15,%rcx,1),%r9
 109183b:	49 83 c1 02          	add    $0x2,%r9
 109183f:	49 39 f9             	cmp    %rdi,%r9
 1091842:	0f 83 58 ff ff ff    	jae    10917a0 <deflate64.stream_blocks.writeFixed+0x540>
 1091848:	eb 34                	jmp    109187e <deflate64.stream_blocks.writeFixed+0x61e>
 109184a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 1091850:	49 03 75 30          	add    0x30(%r13),%rsi
 1091854:	4d 8d 04 0f          	lea    (%r15,%rcx,1),%r8
 1091858:	49 ff c0             	inc    %r8
 109185b:	49 39 f8             	cmp    %rdi,%r8
 109185e:	73 cc                	jae    109182c <deflate64.stream_blocks.writeFixed+0x5cc>
 1091860:	4d 8b 45 20          	mov    0x20(%r13),%r8
 1091864:	4d 01 f8             	add    %r15,%r8
 1091867:	49 01 c8             	add    %rcx,%r8
 109186a:	49 ff c0             	inc    %r8
 109186d:	4d 8d 0c 0f          	lea    (%r15,%rcx,1),%r9
 1091871:	49 83 c1 02          	add    $0x2,%r9
 1091875:	49 39 f9             	cmp    %rdi,%r9
 1091878:	0f 83 22 ff ff ff    	jae    10917a0 <deflate64.stream_blocks.writeFixed+0x540>
 109187e:	49 8b 7d 20          	mov    0x20(%r13),%rdi
 1091882:	4c 01 ff             	add    %r15,%rdi
 1091885:	4c 8d 0c 39          	lea    (%rcx,%rdi,1),%r9
 1091889:	49 83 c1 02          	add    $0x2,%r9
 109188d:	e9 19 ff ff ff       	jmp    10917ab <deflate64.stream_blocks.writeFixed+0x54b>
 1091892:	0f b6 15 f1 02 f8 ff 	movzbl -0x7fd0f(%rip),%edx        # 1011b8a <__anon_18462+0x100>
 1091899:	80 e2 0f             	and    $0xf,%dl
 109189c:	8b 4b 18             	mov    0x18(%rbx),%ecx
 109189f:	0f b6 43 1c          	movzbl 0x1c(%rbx),%eax
 10918a3:	24 07                	and    $0x7,%al
 10918a5:	00 d0                	add    %dl,%al
 10918a7:	88 45 d7             	mov    %al,-0x29(%rbp)
 10918aa:	a8 18                	test   $0x18,%al
 10918ac:	0f 84 9e 00 00 00    	je     1091950 <deflate64.stream_blocks.writeFixed+0x6f0>
 10918b2:	48 8b 53 10          	mov    0x10(%rbx),%rdx
 10918b6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 10918bd:	00 00 00 
 10918c0:	48 8b 33             	mov    (%rbx),%rsi
 10918c3:	88 0c 16             	mov    %cl,(%rsi,%rdx,1)
 10918c6:	48 8b 53 10          	mov    0x10(%rbx),%rdx
 10918ca:	48 ff c2             	inc    %rdx
 10918cd:	48 89 53 10          	mov    %rdx,0x10(%rbx)
 10918d1:	8b 4b 18             	mov    0x18(%rbx),%ecx
 10918d4:	c1 e9 08             	shr    $0x8,%ecx
 10918d7:	89 4b 18             	mov    %ecx,0x18(%rbx)
 10918da:	04 18                	add    $0x18,%al
 10918dc:	89 c6                	mov    %eax,%esi
 10918de:	40 80 e6 1f          	and    $0x1f,%sil
 10918e2:	40 88 75 d7          	mov    %sil,-0x29(%rbp)
 10918e6:	a8 18                	test   $0x18,%al
 10918e8:	89 f0                	mov    %esi,%eax
 10918ea:	75 d4                	jne    10918c0 <deflate64.stream_blocks.writeFixed+0x660>
 10918ec:	eb 68                	jmp    1091956 <deflate64.stream_blocks.writeFixed+0x6f6>
 10918ee:	89 cf                	mov    %ecx,%edi
 10918f0:	40 80 e7 07          	and    $0x7,%dil
 10918f4:	40 88 7b 1c          	mov    %dil,0x1c(%rbx)
 10918f8:	4d 85 e4             	test   %r12,%r12
 10918fb:	0f 85 fe f9 ff ff    	jne    10912ff <deflate64.stream_blocks.writeFixed+0x9f>
 1091901:	0f b6 15 82 02 f8 ff 	movzbl -0x7fd7e(%rip),%edx        # 1011b8a <__anon_18462+0x100>
 1091908:	80 e2 0f             	and    $0xf,%dl
 109190b:	0f b6 4b 1c          	movzbl 0x1c(%rbx),%ecx
 109190f:	80 e1 07             	and    $0x7,%cl
 1091912:	00 d1                	add    %dl,%cl
 1091914:	88 4d d7             	mov    %cl,-0x29(%rbp)
 1091917:	f6 c1 18             	test   $0x18,%cl
 109191a:	74 38                	je     1091954 <deflate64.stream_blocks.writeFixed+0x6f4>
 109191c:	48 8b 53 10          	mov    0x10(%rbx),%rdx
 1091920:	48 8b 33             	mov    (%rbx),%rsi
 1091923:	88 04 16             	mov    %al,(%rsi,%rdx,1)
 1091926:	48 8b 53 10          	mov    0x10(%rbx),%rdx
 109192a:	48 ff c2             	inc    %rdx
 109192d:	48 89 53 10          	mov    %rdx,0x10(%rbx)
 1091931:	8b 43 18             	mov    0x18(%rbx),%eax
 1091934:	c1 e8 08             	shr    $0x8,%eax
 1091937:	89 43 18             	mov    %eax,0x18(%rbx)
 109193a:	80 c1 18             	add    $0x18,%cl
 109193d:	89 ce                	mov    %ecx,%esi
 109193f:	40 80 e6 1f          	and    $0x1f,%sil
 1091943:	40 88 75 d7          	mov    %sil,-0x29(%rbp)
 1091947:	f6 c1 18             	test   $0x18,%cl
 109194a:	89 f1                	mov    %esi,%ecx
 109194c:	75 d2                	jne    1091920 <deflate64.stream_blocks.writeFixed+0x6c0>
 109194e:	eb 06                	jmp    1091956 <deflate64.stream_blocks.writeFixed+0x6f6>
 1091950:	89 c6                	mov    %eax,%esi
 1091952:	eb 02                	jmp    1091956 <deflate64.stream_blocks.writeFixed+0x6f6>
 1091954:	89 ce                	mov    %ecx,%esi
 1091956:	40 80 e6 07          	and    $0x7,%sil
 109195a:	40 88 73 1c          	mov    %sil,0x1c(%rbx)
 109195e:	48 83 c4 28          	add    $0x28,%rsp
 1091962:	5b                   	pop    %rbx
 1091963:	41 5c                	pop    %r12
 1091965:	41 5d                	pop    %r13
 1091967:	41 5e                	pop    %r14
 1091969:	41 5f                	pop    %r15
 109196b:	5d                   	pop    %rbp
 109196c:	c3                   	ret    
