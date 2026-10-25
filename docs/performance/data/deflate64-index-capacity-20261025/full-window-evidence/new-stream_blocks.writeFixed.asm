
/tmp/vort-deflate64-index-capacity-20261025/new-index-probe-final:     file format elf64-x86-64


Disassembly of section .text:

00000000010911c0 <deflate64.stream_blocks.writeFixed>:
 10911c0:	55                   	push   %rbp
 10911c1:	48 89 e5             	mov    %rsp,%rbp
 10911c4:	41 57                	push   %r15
 10911c6:	41 56                	push   %r14
 10911c8:	41 55                	push   %r13
 10911ca:	41 54                	push   %r12
 10911cc:	53                   	push   %rbx
 10911cd:	48 83 ec 38          	sub    $0x38,%rsp
 10911d1:	4d 89 cf             	mov    %r9,%r15
 10911d4:	4c 89 45 c0          	mov    %r8,-0x40(%rbp)
 10911d8:	48 89 4d c8          	mov    %rcx,-0x38(%rbp)
 10911dc:	49 89 f5             	mov    %rsi,%r13
 10911df:	48 89 fb             	mov    %rdi,%rbx
 10911e2:	0f b6 45 20          	movzbl 0x20(%rbp),%eax
 10911e6:	83 e0 01             	and    $0x1,%eax
 10911e9:	83 c8 02             	or     $0x2,%eax
 10911ec:	0f b6 4f 1c          	movzbl 0x1c(%rdi),%ecx
 10911f0:	80 e1 07             	and    $0x7,%cl
 10911f3:	c4 e2 71 f7 c0       	shlx   %ecx,%eax,%eax
 10911f8:	0b 47 18             	or     0x18(%rdi),%eax
 10911fb:	89 47 18             	mov    %eax,0x18(%rdi)
 10911fe:	80 c1 03             	add    $0x3,%cl
 1091201:	88 4d d7             	mov    %cl,-0x29(%rbp)
 1091204:	f6 c1 08             	test   $0x8,%cl
 1091207:	0f 84 71 06 00 00    	je     109187e <deflate64.stream_blocks.writeFixed+0x6be>
 109120d:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 1091211:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1091218:	0f 1f 84 00 00 00 00 
 109121f:	00 
 1091220:	48 8b 3b             	mov    (%rbx),%rdi
 1091223:	88 04 37             	mov    %al,(%rdi,%rsi,1)
 1091226:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 109122a:	48 ff c6             	inc    %rsi
 109122d:	48 89 73 10          	mov    %rsi,0x10(%rbx)
 1091231:	8b 43 18             	mov    0x18(%rbx),%eax
 1091234:	c1 e8 08             	shr    $0x8,%eax
 1091237:	89 43 18             	mov    %eax,0x18(%rbx)
 109123a:	80 c1 18             	add    $0x18,%cl
 109123d:	89 cf                	mov    %ecx,%edi
 109123f:	40 80 e7 1f          	and    $0x1f,%dil
 1091243:	40 88 7d d7          	mov    %dil,-0x29(%rbp)
 1091247:	f6 c1 18             	test   $0x18,%cl
 109124a:	89 f9                	mov    %edi,%ecx
 109124c:	75 d2                	jne    1091220 <deflate64.stream_blocks.writeFixed+0x60>
 109124e:	40 80 e7 07          	and    $0x7,%dil
 1091252:	40 88 7b 1c          	mov    %dil,0x1c(%rbx)
 1091256:	4d 85 ff             	test   %r15,%r15
 1091259:	0f 84 32 06 00 00    	je     1091891 <deflate64.stream_blocks.writeFixed+0x6d1>
 109125f:	41 be ff ff ff ff    	mov    $0xffffffff,%r14d
 1091265:	49 89 55 20          	mov    %rdx,0x20(%r13)
 1091269:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 109126d:	4d 89 65 28          	mov    %r12,0x28(%r13)
 1091271:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 1091275:	49 89 45 30          	mov    %rax,0x30(%r13)
 1091279:	4d 89 7d 38          	mov    %r15,0x38(%r13)
 109127d:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 1091281:	ba 00 00 02 00       	mov    $0x20000,%edx
 1091286:	be ff 00 00 00       	mov    $0xff,%esi
 109128b:	e8 20 30 04 00       	call   10d42b0 <compiler_rt.memset>
 1091290:	4d 85 e4             	test   %r12,%r12
 1091293:	0f 84 cc 00 00 00    	je     1091365 <deflate64.stream_blocks.writeFixed+0x1a5>
 1091299:	31 c0                	xor    %eax,%eax
 109129b:	eb 4b                	jmp    10912e8 <deflate64.stream_blocks.writeFixed+0x128>
 109129d:	0f 1f 00             	nopl   (%rax)
 10912a0:	49 03 7d 30          	add    0x30(%r13),%rdi
 10912a4:	0f b6 09             	movzbl (%rcx),%ecx
 10912a7:	0f b6 16             	movzbl (%rsi),%edx
 10912aa:	c1 e1 10             	shl    $0x10,%ecx
 10912ad:	c1 e2 08             	shl    $0x8,%edx
 10912b0:	09 ca                	or     %ecx,%edx
 10912b2:	0f b6 0f             	movzbl (%rdi),%ecx
 10912b5:	09 d1                	or     %edx,%ecx
 10912b7:	69 c9 bd a7 35 1e    	imul   $0x1e35a7bd,%ecx,%ecx
 10912bd:	49 8b 55 18          	mov    0x18(%r13),%rdx
 10912c1:	4c 01 f2             	add    %r14,%rdx
 10912c4:	48 21 c2             	and    %rax,%rdx
 10912c7:	49 8b 75 00          	mov    0x0(%r13),%rsi
 10912cb:	49 8b 7d 10          	mov    0x10(%r13),%rdi
 10912cf:	c1 e9 11             	shr    $0x11,%ecx
 10912d2:	8b 34 8e             	mov    (%rsi,%rcx,4),%esi
 10912d5:	89 34 97             	mov    %esi,(%rdi,%rdx,4)
 10912d8:	49 8b 55 00          	mov    0x0(%r13),%rdx
 10912dc:	89 04 8a             	mov    %eax,(%rdx,%rcx,4)
 10912df:	48 ff c0             	inc    %rax
 10912e2:	48 39 45 c8          	cmp    %rax,-0x38(%rbp)
 10912e6:	74 7d                	je     1091365 <deflate64.stream_blocks.writeFixed+0x1a5>
 10912e8:	48 8d 48 03          	lea    0x3(%rax),%rcx
 10912ec:	49 8b 55 28          	mov    0x28(%r13),%rdx
 10912f0:	49 8b 75 38          	mov    0x38(%r13),%rsi
 10912f4:	48 01 d6             	add    %rdx,%rsi
 10912f7:	48 39 f1             	cmp    %rsi,%rcx
 10912fa:	77 e3                	ja     10912df <deflate64.stream_blocks.writeFixed+0x11f>
 10912fc:	48 89 c1             	mov    %rax,%rcx
 10912ff:	48 29 d1             	sub    %rdx,%rcx
 1091302:	73 2c                	jae    1091330 <deflate64.stream_blocks.writeFixed+0x170>
 1091304:	49 8b 4d 20          	mov    0x20(%r13),%rcx
 1091308:	48 01 c1             	add    %rax,%rcx
 109130b:	48 8d 70 01          	lea    0x1(%rax),%rsi
 109130f:	48 29 d6             	sub    %rdx,%rsi
 1091312:	72 29                	jb     109133d <deflate64.stream_blocks.writeFixed+0x17d>
 1091314:	49 03 75 30          	add    0x30(%r13),%rsi
 1091318:	48 8d 78 02          	lea    0x2(%rax),%rdi
 109131c:	48 29 d7             	sub    %rdx,%rdi
 109131f:	0f 83 7b ff ff ff    	jae    10912a0 <deflate64.stream_blocks.writeFixed+0xe0>
 1091325:	eb 2d                	jmp    1091354 <deflate64.stream_blocks.writeFixed+0x194>
 1091327:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 109132e:	00 00 
 1091330:	49 03 4d 30          	add    0x30(%r13),%rcx
 1091334:	48 8d 70 01          	lea    0x1(%rax),%rsi
 1091338:	48 29 d6             	sub    %rdx,%rsi
 109133b:	73 d7                	jae    1091314 <deflate64.stream_blocks.writeFixed+0x154>
 109133d:	49 8b 75 20          	mov    0x20(%r13),%rsi
 1091341:	48 01 c6             	add    %rax,%rsi
 1091344:	48 ff c6             	inc    %rsi
 1091347:	48 8d 78 02          	lea    0x2(%rax),%rdi
 109134b:	48 29 d7             	sub    %rdx,%rdi
 109134e:	0f 83 4c ff ff ff    	jae    10912a0 <deflate64.stream_blocks.writeFixed+0xe0>
 1091354:	49 8b 55 20          	mov    0x20(%r13),%rdx
 1091358:	48 8d 3c 02          	lea    (%rdx,%rax,1),%rdi
 109135c:	48 83 c7 02          	add    $0x2,%rdi
 1091360:	e9 3f ff ff ff       	jmp    10912a4 <deflate64.stream_blocks.writeFixed+0xe4>
 1091365:	45 31 e4             	xor    %r12d,%r12d
 1091368:	4c 89 7d b8          	mov    %r15,-0x48(%rbp)
 109136c:	eb 12                	jmp    1091380 <deflate64.stream_blocks.writeFixed+0x1c0>
 109136e:	66 90                	xchg   %ax,%ax
 1091370:	49 01 c4             	add    %rax,%r12
 1091373:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 1091377:	4d 39 fc             	cmp    %r15,%r12
 109137a:	0f 83 a2 04 00 00    	jae    1091822 <deflate64.stream_blocks.writeFixed+0x662>
 1091380:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 1091384:	4d 8d 3c 04          	lea    (%r12,%rax,1),%r15
 1091388:	48 8d 7d a8          	lea    -0x58(%rbp),%rdi
 109138c:	4c 89 ee             	mov    %r13,%rsi
 109138f:	4c 89 fa             	mov    %r15,%rdx
 1091392:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 1091396:	4c 8b 45 18          	mov    0x18(%rbp),%r8
 109139a:	e8 61 05 00 00       	call   1091900 <deflate64.stream_match.Matcher.find>
 109139f:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 10913a3:	48 83 fe 03          	cmp    $0x3,%rsi
 10913a7:	b8 01 00 00 00       	mov    $0x1,%eax
 10913ac:	48 0f 43 c6          	cmovae %rsi,%rax
 10913b0:	72 2e                	jb     10913e0 <deflate64.stream_blocks.writeFixed+0x220>
 10913b2:	48 8d 4e fd          	lea    -0x3(%rsi),%rcx
 10913b6:	48 81 fe 03 01 00 00 	cmp    $0x103,%rsi
 10913bd:	0f 82 9d 00 00 00    	jb     1091460 <deflate64.stream_blocks.writeFixed+0x2a0>
 10913c3:	c6 45 d6 10          	movb   $0x10,-0x2a(%rbp)
 10913c7:	be 1d 01 00 00       	mov    $0x11d,%esi
 10913cc:	e9 ee 00 00 00       	jmp    10914bf <deflate64.stream_blocks.writeFixed+0x2ff>
 10913d1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10913d8:	0f 1f 84 00 00 00 00 
 10913df:	00 
 10913e0:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 10913e4:	42 0f b6 0c 21       	movzbl (%rcx,%r12,1),%ecx
 10913e9:	0f b7 94 09 4a 18 01 	movzwl 0x101184a(%rcx,%rcx,1),%edx
 10913f0:	01 
 10913f1:	0f b6 b1 8a 1a 01 01 	movzbl 0x1011a8a(%rcx),%esi
 10913f8:	40 80 e6 0f          	and    $0xf,%sil
 10913fc:	0f b6 4b 1c          	movzbl 0x1c(%rbx),%ecx
 1091400:	80 e1 07             	and    $0x7,%cl
 1091403:	c4 e2 71 f7 d2       	shlx   %ecx,%edx,%edx
 1091408:	0b 53 18             	or     0x18(%rbx),%edx
 109140b:	89 53 18             	mov    %edx,0x18(%rbx)
 109140e:	40 00 f1             	add    %sil,%cl
 1091411:	88 4d d7             	mov    %cl,-0x29(%rbp)
 1091414:	f6 c1 18             	test   $0x18,%cl
 1091417:	74 5c                	je     1091475 <deflate64.stream_blocks.writeFixed+0x2b5>
 1091419:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 109141d:	0f 1f 00             	nopl   (%rax)
 1091420:	48 8b 3b             	mov    (%rbx),%rdi
 1091423:	88 14 37             	mov    %dl,(%rdi,%rsi,1)
 1091426:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 109142a:	48 ff c6             	inc    %rsi
 109142d:	48 89 73 10          	mov    %rsi,0x10(%rbx)
 1091431:	8b 53 18             	mov    0x18(%rbx),%edx
 1091434:	c1 ea 08             	shr    $0x8,%edx
 1091437:	89 53 18             	mov    %edx,0x18(%rbx)
 109143a:	80 c1 18             	add    $0x18,%cl
 109143d:	89 cf                	mov    %ecx,%edi
 109143f:	40 80 e7 1f          	and    $0x1f,%dil
 1091443:	40 88 7d d7          	mov    %dil,-0x29(%rbp)
 1091447:	f6 c1 18             	test   $0x18,%cl
 109144a:	89 f9                	mov    %edi,%ecx
 109144c:	75 d2                	jne    1091420 <deflate64.stream_blocks.writeFixed+0x260>
 109144e:	e9 bd 02 00 00       	jmp    1091710 <deflate64.stream_blocks.writeFixed+0x550>
 1091453:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 109145a:	84 00 00 00 00 00 
 1091460:	48 83 fe 0a          	cmp    $0xa,%rsi
 1091464:	77 16                	ja     109147c <deflate64.stream_blocks.writeFixed+0x2bc>
 1091466:	48 81 c6 fe 00 00 00 	add    $0xfe,%rsi
 109146d:	c6 45 d6 00          	movb   $0x0,-0x2a(%rbp)
 1091471:	31 c9                	xor    %ecx,%ecx
 1091473:	eb 4a                	jmp    10914bf <deflate64.stream_blocks.writeFixed+0x2ff>
 1091475:	89 cf                	mov    %ecx,%edi
 1091477:	e9 94 02 00 00       	jmp    1091710 <deflate64.stream_blocks.writeFixed+0x550>
 109147c:	f3 48 0f bd d1       	lzcnt  %rcx,%rdx
 1091481:	f6 d2                	not    %dl
 1091483:	48 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%rsi
 109148a:	c4 e2 e9 f7 fe       	shlx   %rdx,%rsi,%rdi
 109148f:	80 c2 3e             	add    $0x3e,%dl
 1091492:	48 01 cf             	add    %rcx,%rdi
 1091495:	0f b6 ca             	movzbl %dl,%ecx
 1091498:	89 ca                	mov    %ecx,%edx
 109149a:	83 e2 3f             	and    $0x3f,%edx
 109149d:	c4 e2 f3 f7 f7       	shrx   %rcx,%rdi,%rsi
 10914a2:	41 89 c8             	mov    %ecx,%r8d
 10914a5:	41 80 e0 3f          	and    $0x3f,%r8b
 10914a9:	48 8d 34 96          	lea    (%rsi,%rdx,4),%rsi
 10914ad:	48 81 c6 05 01 00 00 	add    $0x105,%rsi
 10914b4:	80 e1 1f             	and    $0x1f,%cl
 10914b7:	88 4d d6             	mov    %cl,-0x2a(%rbp)
 10914ba:	c4 e2 38 f5 cf       	bzhi   %r8d,%edi,%ecx
 10914bf:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 10914c3:	0f b6 7d d6          	movzbl -0x2a(%rbp),%edi
 10914c7:	0f b7 f6             	movzwl %si,%esi
 10914ca:	41 89 f0             	mov    %esi,%r8d
 10914cd:	47 0f b7 84 00 4a 18 	movzwl 0x101184a(%r8,%r8,1),%r8d
 10914d4:	01 01 
 10914d6:	44 0f b6 8e 8a 1a 01 	movzbl 0x1011a8a(%rsi),%r9d
 10914dd:	01 
 10914de:	41 80 e1 0f          	and    $0xf,%r9b
 10914e2:	0f b6 73 1c          	movzbl 0x1c(%rbx),%esi
 10914e6:	40 80 e6 07          	and    $0x7,%sil
 10914ea:	c4 42 49 f7 c0       	shlx   %esi,%r8d,%r8d
 10914ef:	44 0b 43 18          	or     0x18(%rbx),%r8d
 10914f3:	44 89 43 18          	mov    %r8d,0x18(%rbx)
 10914f7:	44 00 ce             	add    %r9b,%sil
 10914fa:	40 88 75 d7          	mov    %sil,-0x29(%rbp)
 10914fe:	40 f6 c6 18          	test   $0x18,%sil
 1091502:	74 44                	je     1091548 <deflate64.stream_blocks.writeFixed+0x388>
 1091504:	4c 8b 4b 10          	mov    0x10(%rbx),%r9
 1091508:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 109150f:	00 
 1091510:	4c 8b 13             	mov    (%rbx),%r10
 1091513:	47 88 04 0a          	mov    %r8b,(%r10,%r9,1)
 1091517:	4c 8b 4b 10          	mov    0x10(%rbx),%r9
 109151b:	49 ff c1             	inc    %r9
 109151e:	4c 89 4b 10          	mov    %r9,0x10(%rbx)
 1091522:	44 8b 43 18          	mov    0x18(%rbx),%r8d
 1091526:	41 c1 e8 08          	shr    $0x8,%r8d
 109152a:	44 89 43 18          	mov    %r8d,0x18(%rbx)
 109152e:	40 80 c6 18          	add    $0x18,%sil
 1091532:	41 89 f2             	mov    %esi,%r10d
 1091535:	41 80 e2 1f          	and    $0x1f,%r10b
 1091539:	44 88 55 d7          	mov    %r10b,-0x29(%rbp)
 109153d:	40 f6 c6 18          	test   $0x18,%sil
 1091541:	44 89 d6             	mov    %r10d,%esi
 1091544:	75 ca                	jne    1091510 <deflate64.stream_blocks.writeFixed+0x350>
 1091546:	eb 03                	jmp    109154b <deflate64.stream_blocks.writeFixed+0x38b>
 1091548:	41 89 f2             	mov    %esi,%r10d
 109154b:	41 80 e2 07          	and    $0x7,%r10b
 109154f:	44 88 53 1c          	mov    %r10b,0x1c(%rbx)
 1091553:	0f b7 c9             	movzwl %cx,%ecx
 1091556:	44 0f b6 4b 1c       	movzbl 0x1c(%rbx),%r9d
 109155b:	41 80 e1 07          	and    $0x7,%r9b
 109155f:	c4 e2 31 f7 f1       	shlx   %r9d,%ecx,%esi
 1091564:	44 09 c6             	or     %r8d,%esi
 1091567:	89 73 18             	mov    %esi,0x18(%rbx)
 109156a:	41 00 f9             	add    %dil,%r9b
 109156d:	44 89 c9             	mov    %r9d,%ecx
 1091570:	80 e1 1f             	and    $0x1f,%cl
 1091573:	88 4d d7             	mov    %cl,-0x29(%rbp)
 1091576:	41 f6 c1 18          	test   $0x18,%r9b
 109157a:	74 50                	je     10915cc <deflate64.stream_blocks.writeFixed+0x40c>
 109157c:	48 8b 7b 10          	mov    0x10(%rbx),%rdi
 1091580:	4c 8b 03             	mov    (%rbx),%r8
 1091583:	41 88 34 38          	mov    %sil,(%r8,%rdi,1)
 1091587:	48 8b 7b 10          	mov    0x10(%rbx),%rdi
 109158b:	48 ff c7             	inc    %rdi
 109158e:	48 89 7b 10          	mov    %rdi,0x10(%rbx)
 1091592:	8b 73 18             	mov    0x18(%rbx),%esi
 1091595:	c1 ee 08             	shr    $0x8,%esi
 1091598:	89 73 18             	mov    %esi,0x18(%rbx)
 109159b:	80 c1 18             	add    $0x18,%cl
 109159e:	41 89 c8             	mov    %ecx,%r8d
 10915a1:	41 80 e0 1f          	and    $0x1f,%r8b
 10915a5:	44 88 45 d7          	mov    %r8b,-0x29(%rbp)
 10915a9:	f6 c1 18             	test   $0x18,%cl
 10915ac:	44 89 c1             	mov    %r8d,%ecx
 10915af:	75 cf                	jne    1091580 <deflate64.stream_blocks.writeFixed+0x3c0>
 10915b1:	41 80 e0 07          	and    $0x7,%r8b
 10915b5:	44 88 43 1c          	mov    %r8b,0x1c(%rbx)
 10915b9:	48 83 fa 04          	cmp    $0x4,%rdx
 10915bd:	77 1e                	ja     10915dd <deflate64.stream_blocks.writeFixed+0x41d>
 10915bf:	48 81 c2 ff ff 00 00 	add    $0xffff,%rdx
 10915c6:	31 ff                	xor    %edi,%edi
 10915c8:	31 c9                	xor    %ecx,%ecx
 10915ca:	eb 50                	jmp    109161c <deflate64.stream_blocks.writeFixed+0x45c>
 10915cc:	41 89 c8             	mov    %ecx,%r8d
 10915cf:	41 80 e0 07          	and    $0x7,%r8b
 10915d3:	44 88 43 1c          	mov    %r8b,0x1c(%rbx)
 10915d7:	48 83 fa 04          	cmp    $0x4,%rdx
 10915db:	76 e2                	jbe    10915bf <deflate64.stream_blocks.writeFixed+0x3ff>
 10915dd:	48 8d 4a ff          	lea    -0x1(%rdx),%rcx
 10915e1:	f3 48 0f bd c9       	lzcnt  %rcx,%rcx
 10915e6:	f6 d1                	not    %cl
 10915e8:	8d 79 3f             	lea    0x3f(%rcx),%edi
 10915eb:	49 c7 c0 fe ff ff ff 	mov    $0xfffffffffffffffe,%r8
 10915f2:	49 d3 c0             	rol    %cl,%r8
 10915f5:	49 01 d0             	add    %rdx,%r8
 10915f8:	8d 0c 3f             	lea    (%rdi,%rdi,1),%ecx
 10915fb:	0f b6 c9             	movzbl %cl,%ecx
 10915fe:	83 e1 3e             	and    $0x3e,%ecx
 1091601:	c4 c2 c3 f7 d0       	shrx   %rdi,%r8,%rdx
 1091606:	41 89 f9             	mov    %edi,%r9d
 1091609:	41 80 e1 3f          	and    $0x3f,%r9b
 109160d:	48 01 ca             	add    %rcx,%rdx
 1091610:	48 83 c2 02          	add    $0x2,%rdx
 1091614:	c4 c2 30 f5 c8       	bzhi   %r9d,%r8d,%ecx
 1091619:	0f b7 c9             	movzwl %cx,%ecx
 109161c:	40 80 e7 1f          	and    $0x1f,%dil
 1091620:	40 88 7d d4          	mov    %dil,-0x2c(%rbp)
 1091624:	0f b7 d2             	movzwl %dx,%edx
 1091627:	0f b7 94 12 0a 18 01 	movzwl 0x101180a(%rdx,%rdx,1),%edx
 109162e:	01 
 109162f:	44 0f b6 43 1c       	movzbl 0x1c(%rbx),%r8d
 1091634:	41 80 e0 07          	and    $0x7,%r8b
 1091638:	c4 e2 39 f7 d2       	shlx   %r8d,%edx,%edx
 109163d:	09 f2                	or     %esi,%edx
 109163f:	89 53 18             	mov    %edx,0x18(%rbx)
 1091642:	41 80 c0 05          	add    $0x5,%r8b
 1091646:	44 88 45 d7          	mov    %r8b,-0x29(%rbp)
 109164a:	41 f6 c0 08          	test   $0x8,%r8b
 109164e:	74 45                	je     1091695 <deflate64.stream_blocks.writeFixed+0x4d5>
 1091650:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 1091654:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 109165b:	00 00 00 00 00 
 1091660:	4c 8b 0b             	mov    (%rbx),%r9
 1091663:	41 88 14 31          	mov    %dl,(%r9,%rsi,1)
 1091667:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 109166b:	48 ff c6             	inc    %rsi
 109166e:	48 89 73 10          	mov    %rsi,0x10(%rbx)
 1091672:	8b 53 18             	mov    0x18(%rbx),%edx
 1091675:	c1 ea 08             	shr    $0x8,%edx
 1091678:	89 53 18             	mov    %edx,0x18(%rbx)
 109167b:	41 80 c0 18          	add    $0x18,%r8b
 109167f:	45 89 c1             	mov    %r8d,%r9d
 1091682:	41 80 e1 1f          	and    $0x1f,%r9b
 1091686:	44 88 4d d7          	mov    %r9b,-0x29(%rbp)
 109168a:	41 f6 c0 18          	test   $0x18,%r8b
 109168e:	45 89 c8             	mov    %r9d,%r8d
 1091691:	75 cd                	jne    1091660 <deflate64.stream_blocks.writeFixed+0x4a0>
 1091693:	eb 03                	jmp    1091698 <deflate64.stream_blocks.writeFixed+0x4d8>
 1091695:	45 89 c1             	mov    %r8d,%r9d
 1091698:	41 80 e1 07          	and    $0x7,%r9b
 109169c:	44 88 4b 1c          	mov    %r9b,0x1c(%rbx)
 10916a0:	0f b6 73 1c          	movzbl 0x1c(%rbx),%esi
 10916a4:	40 80 e6 07          	and    $0x7,%sil
 10916a8:	c4 e2 49 f7 c9       	shlx   %esi,%ecx,%ecx
 10916ad:	09 d1                	or     %edx,%ecx
 10916af:	89 4b 18             	mov    %ecx,0x18(%rbx)
 10916b2:	40 00 fe             	add    %dil,%sil
 10916b5:	89 f2                	mov    %esi,%edx
 10916b7:	80 e2 1f             	and    $0x1f,%dl
 10916ba:	88 55 d7             	mov    %dl,-0x29(%rbp)
 10916bd:	40 f6 c6 18          	test   $0x18,%sil
 10916c1:	74 3d                	je     1091700 <deflate64.stream_blocks.writeFixed+0x540>
 10916c3:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 10916c7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 10916ce:	00 00 
 10916d0:	48 8b 3b             	mov    (%rbx),%rdi
 10916d3:	88 0c 37             	mov    %cl,(%rdi,%rsi,1)
 10916d6:	48 8b 73 10          	mov    0x10(%rbx),%rsi
 10916da:	48 ff c6             	inc    %rsi
 10916dd:	48 89 73 10          	mov    %rsi,0x10(%rbx)
 10916e1:	8b 4b 18             	mov    0x18(%rbx),%ecx
 10916e4:	c1 e9 08             	shr    $0x8,%ecx
 10916e7:	89 4b 18             	mov    %ecx,0x18(%rbx)
 10916ea:	80 c2 18             	add    $0x18,%dl
 10916ed:	89 d7                	mov    %edx,%edi
 10916ef:	40 80 e7 1f          	and    $0x1f,%dil
 10916f3:	40 88 7d d7          	mov    %dil,-0x29(%rbp)
 10916f7:	f6 c2 18             	test   $0x18,%dl
 10916fa:	89 fa                	mov    %edi,%edx
 10916fc:	75 d2                	jne    10916d0 <deflate64.stream_blocks.writeFixed+0x510>
 10916fe:	eb 10                	jmp    1091710 <deflate64.stream_blocks.writeFixed+0x550>
 1091700:	89 d7                	mov    %edx,%edi
 1091702:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1091709:	1f 84 00 00 00 00 00 
 1091710:	40 80 e7 07          	and    $0x7,%dil
 1091714:	40 88 7b 1c          	mov    %dil,0x1c(%rbx)
 1091718:	31 c9                	xor    %ecx,%ecx
 109171a:	eb 5d                	jmp    1091779 <deflate64.stream_blocks.writeFixed+0x5b9>
 109171c:	0f 1f 40 00          	nopl   0x0(%rax)
 1091720:	4c 8d 4a 02          	lea    0x2(%rdx),%r9
 1091724:	49 29 f9             	sub    %rdi,%r9
 1091727:	4d 03 4d 30          	add    0x30(%r13),%r9
 109172b:	0f b6 36             	movzbl (%rsi),%esi
 109172e:	41 0f b6 38          	movzbl (%r8),%edi
 1091732:	c1 e6 10             	shl    $0x10,%esi
 1091735:	c1 e7 08             	shl    $0x8,%edi
 1091738:	09 f7                	or     %esi,%edi
 109173a:	41 0f b6 31          	movzbl (%r9),%esi
 109173e:	09 fe                	or     %edi,%esi
 1091740:	69 f6 bd a7 35 1e    	imul   $0x1e35a7bd,%esi,%esi
 1091746:	49 8b 7d 18          	mov    0x18(%r13),%rdi
 109174a:	4c 01 f7             	add    %r14,%rdi
 109174d:	48 21 d7             	and    %rdx,%rdi
 1091750:	49 8b 55 00          	mov    0x0(%r13),%rdx
 1091754:	4d 8b 45 10          	mov    0x10(%r13),%r8
 1091758:	c1 ee 11             	shr    $0x11,%esi
 109175b:	8b 14 b2             	mov    (%rdx,%rsi,4),%edx
 109175e:	41 89 14 b8          	mov    %edx,(%r8,%rdi,4)
 1091762:	49 8b 55 00          	mov    0x0(%r13),%rdx
 1091766:	41 8d 3c 0f          	lea    (%r15,%rcx,1),%edi
 109176a:	89 3c b2             	mov    %edi,(%rdx,%rsi,4)
 109176d:	48 ff c1             	inc    %rcx
 1091770:	48 39 c8             	cmp    %rcx,%rax
 1091773:	0f 84 f7 fb ff ff    	je     1091370 <deflate64.stream_blocks.writeFixed+0x1b0>
 1091779:	4a 8d 14 39          	lea    (%rcx,%r15,1),%rdx
 109177d:	48 83 c2 03          	add    $0x3,%rdx
 1091781:	49 8b 7d 28          	mov    0x28(%r13),%rdi
 1091785:	49 8b 75 38          	mov    0x38(%r13),%rsi
 1091789:	48 01 fe             	add    %rdi,%rsi
 109178c:	48 39 f2             	cmp    %rsi,%rdx
 109178f:	77 dc                	ja     109176d <deflate64.stream_blocks.writeFixed+0x5ad>
 1091791:	4a 8d 14 39          	lea    (%rcx,%r15,1),%rdx
 1091795:	48 89 d6             	mov    %rdx,%rsi
 1091798:	48 29 fe             	sub    %rdi,%rsi
 109179b:	73 43                	jae    10917e0 <deflate64.stream_blocks.writeFixed+0x620>
 109179d:	49 8b 75 20          	mov    0x20(%r13),%rsi
 10917a1:	4c 01 fe             	add    %r15,%rsi
 10917a4:	48 01 ce             	add    %rcx,%rsi
 10917a7:	4d 8d 04 0f          	lea    (%r15,%rcx,1),%r8
 10917ab:	49 ff c0             	inc    %r8
 10917ae:	49 39 f8             	cmp    %rdi,%r8
 10917b1:	72 3d                	jb     10917f0 <deflate64.stream_blocks.writeFixed+0x630>
 10917b3:	4c 8d 42 01          	lea    0x1(%rdx),%r8
 10917b7:	49 29 f8             	sub    %rdi,%r8
 10917ba:	4d 03 45 30          	add    0x30(%r13),%r8
 10917be:	4d 8d 0c 0f          	lea    (%r15,%rcx,1),%r9
 10917c2:	49 83 c1 02          	add    $0x2,%r9
 10917c6:	49 39 f9             	cmp    %rdi,%r9
 10917c9:	0f 83 51 ff ff ff    	jae    1091720 <deflate64.stream_blocks.writeFixed+0x560>
 10917cf:	eb 3d                	jmp    109180e <deflate64.stream_blocks.writeFixed+0x64e>
 10917d1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 10917d8:	0f 1f 84 00 00 00 00 
 10917df:	00 
 10917e0:	49 03 75 30          	add    0x30(%r13),%rsi
 10917e4:	4d 8d 04 0f          	lea    (%r15,%rcx,1),%r8
 10917e8:	49 ff c0             	inc    %r8
 10917eb:	49 39 f8             	cmp    %rdi,%r8
 10917ee:	73 c3                	jae    10917b3 <deflate64.stream_blocks.writeFixed+0x5f3>
 10917f0:	4d 8b 45 20          	mov    0x20(%r13),%r8
 10917f4:	4d 01 f8             	add    %r15,%r8
 10917f7:	49 01 c8             	add    %rcx,%r8
 10917fa:	49 ff c0             	inc    %r8
 10917fd:	4d 8d 0c 0f          	lea    (%r15,%rcx,1),%r9
 1091801:	49 83 c1 02          	add    $0x2,%r9
 1091805:	49 39 f9             	cmp    %rdi,%r9
 1091808:	0f 83 12 ff ff ff    	jae    1091720 <deflate64.stream_blocks.writeFixed+0x560>
 109180e:	49 8b 7d 20          	mov    0x20(%r13),%rdi
 1091812:	4c 01 ff             	add    %r15,%rdi
 1091815:	4c 8d 0c 39          	lea    (%rcx,%rdi,1),%r9
 1091819:	49 83 c1 02          	add    $0x2,%r9
 109181d:	e9 09 ff ff ff       	jmp    109172b <deflate64.stream_blocks.writeFixed+0x56b>
 1091822:	0f b6 15 61 03 f8 ff 	movzbl -0x7fc9f(%rip),%edx        # 1011b8a <__anon_18464+0x100>
 1091829:	80 e2 0f             	and    $0xf,%dl
 109182c:	8b 4b 18             	mov    0x18(%rbx),%ecx
 109182f:	0f b6 43 1c          	movzbl 0x1c(%rbx),%eax
 1091833:	24 07                	and    $0x7,%al
 1091835:	00 d0                	add    %dl,%al
 1091837:	88 45 d7             	mov    %al,-0x29(%rbp)
 109183a:	a8 18                	test   $0x18,%al
 109183c:	0f 84 9e 00 00 00    	je     10918e0 <deflate64.stream_blocks.writeFixed+0x720>
 1091842:	48 8b 53 10          	mov    0x10(%rbx),%rdx
 1091846:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 109184d:	00 00 00 
 1091850:	48 8b 33             	mov    (%rbx),%rsi
 1091853:	88 0c 16             	mov    %cl,(%rsi,%rdx,1)
 1091856:	48 8b 53 10          	mov    0x10(%rbx),%rdx
 109185a:	48 ff c2             	inc    %rdx
 109185d:	48 89 53 10          	mov    %rdx,0x10(%rbx)
 1091861:	8b 4b 18             	mov    0x18(%rbx),%ecx
 1091864:	c1 e9 08             	shr    $0x8,%ecx
 1091867:	89 4b 18             	mov    %ecx,0x18(%rbx)
 109186a:	04 18                	add    $0x18,%al
 109186c:	89 c6                	mov    %eax,%esi
 109186e:	40 80 e6 1f          	and    $0x1f,%sil
 1091872:	40 88 75 d7          	mov    %sil,-0x29(%rbp)
 1091876:	a8 18                	test   $0x18,%al
 1091878:	89 f0                	mov    %esi,%eax
 109187a:	75 d4                	jne    1091850 <deflate64.stream_blocks.writeFixed+0x690>
 109187c:	eb 68                	jmp    10918e6 <deflate64.stream_blocks.writeFixed+0x726>
 109187e:	89 cf                	mov    %ecx,%edi
 1091880:	40 80 e7 07          	and    $0x7,%dil
 1091884:	40 88 7b 1c          	mov    %dil,0x1c(%rbx)
 1091888:	4d 85 ff             	test   %r15,%r15
 109188b:	0f 85 ce f9 ff ff    	jne    109125f <deflate64.stream_blocks.writeFixed+0x9f>
 1091891:	0f b6 15 f2 02 f8 ff 	movzbl -0x7fd0e(%rip),%edx        # 1011b8a <__anon_18464+0x100>
 1091898:	80 e2 0f             	and    $0xf,%dl
 109189b:	0f b6 4b 1c          	movzbl 0x1c(%rbx),%ecx
 109189f:	80 e1 07             	and    $0x7,%cl
 10918a2:	00 d1                	add    %dl,%cl
 10918a4:	88 4d d7             	mov    %cl,-0x29(%rbp)
 10918a7:	f6 c1 18             	test   $0x18,%cl
 10918aa:	74 38                	je     10918e4 <deflate64.stream_blocks.writeFixed+0x724>
 10918ac:	48 8b 53 10          	mov    0x10(%rbx),%rdx
 10918b0:	48 8b 33             	mov    (%rbx),%rsi
 10918b3:	88 04 16             	mov    %al,(%rsi,%rdx,1)
 10918b6:	48 8b 53 10          	mov    0x10(%rbx),%rdx
 10918ba:	48 ff c2             	inc    %rdx
 10918bd:	48 89 53 10          	mov    %rdx,0x10(%rbx)
 10918c1:	8b 43 18             	mov    0x18(%rbx),%eax
 10918c4:	c1 e8 08             	shr    $0x8,%eax
 10918c7:	89 43 18             	mov    %eax,0x18(%rbx)
 10918ca:	80 c1 18             	add    $0x18,%cl
 10918cd:	89 ce                	mov    %ecx,%esi
 10918cf:	40 80 e6 1f          	and    $0x1f,%sil
 10918d3:	40 88 75 d7          	mov    %sil,-0x29(%rbp)
 10918d7:	f6 c1 18             	test   $0x18,%cl
 10918da:	89 f1                	mov    %esi,%ecx
 10918dc:	75 d2                	jne    10918b0 <deflate64.stream_blocks.writeFixed+0x6f0>
 10918de:	eb 06                	jmp    10918e6 <deflate64.stream_blocks.writeFixed+0x726>
 10918e0:	89 c6                	mov    %eax,%esi
 10918e2:	eb 02                	jmp    10918e6 <deflate64.stream_blocks.writeFixed+0x726>
 10918e4:	89 ce                	mov    %ecx,%esi
 10918e6:	40 80 e6 07          	and    $0x7,%sil
 10918ea:	40 88 73 1c          	mov    %sil,0x1c(%rbx)
 10918ee:	48 83 c4 38          	add    $0x38,%rsp
 10918f2:	5b                   	pop    %rbx
 10918f3:	41 5c                	pop    %r12
 10918f5:	41 5d                	pop    %r13
 10918f7:	41 5e                	pop    %r14
 10918f9:	41 5f                	pop    %r15
 10918fb:	5d                   	pop    %rbp
 10918fc:	c3                   	ret    
