
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000126a190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669>:
 126a190:	55                   	push   %rbp
 126a191:	48 89 e5             	mov    %rsp,%rbp
 126a194:	41 57                	push   %r15
 126a196:	41 56                	push   %r14
 126a198:	41 55                	push   %r13
 126a19a:	41 54                	push   %r12
 126a19c:	53                   	push   %rbx
 126a19d:	48 81 ec d8 41 00 00 	sub    $0x41d8,%rsp
 126a1a4:	4d 89 cf             	mov    %r9,%r15
 126a1a7:	4d 89 c4             	mov    %r8,%r12
 126a1aa:	49 89 cd             	mov    %rcx,%r13
 126a1ad:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 126a1b1:	48 89 7d 98          	mov    %rdi,-0x68(%rbp)
 126a1b5:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126a1b9:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 126a1bd:	c5 fc 11 85 00 fd ff 	vmovups %ymm0,-0x300(%rbp)
 126a1c4:	ff 
 126a1c5:	c5 f8 10 40 10       	vmovups 0x10(%rax),%xmm0
 126a1ca:	c5 f8 29 85 f0 fc ff 	vmovaps %xmm0,-0x310(%rbp)
 126a1d1:	ff 
 126a1d2:	c5 fc 10 40 20       	vmovups 0x20(%rax),%ymm0
 126a1d7:	c5 fc 11 85 70 e9 ff 	vmovups %ymm0,-0x1690(%rbp)
 126a1de:	ff 
 126a1df:	48 8b 4d 28          	mov    0x28(%rbp),%rcx
 126a1e3:	0f b6 50 40          	movzbl 0x40(%rax),%edx
 126a1e7:	88 95 75 ff ff ff    	mov    %dl,-0x8b(%rbp)
 126a1ed:	0f b6 50 45          	movzbl 0x45(%rax),%edx
 126a1f1:	88 95 77 ff ff ff    	mov    %dl,-0x89(%rbp)
 126a1f7:	0f b6 50 49          	movzbl 0x49(%rax),%edx
 126a1fb:	88 95 68 ff ff ff    	mov    %dl,-0x98(%rbp)
 126a201:	0f b6 50 4a          	movzbl 0x4a(%rax),%edx
 126a205:	88 55 d0             	mov    %dl,-0x30(%rbp)
 126a208:	0f b6 50 4b          	movzbl 0x4b(%rax),%edx
 126a20c:	88 55 b0             	mov    %dl,-0x50(%rbp)
 126a20f:	0f b6 50 4c          	movzbl 0x4c(%rax),%edx
 126a213:	88 55 a5             	mov    %dl,-0x5b(%rbp)
 126a216:	0f b6 50 4d          	movzbl 0x4d(%rax),%edx
 126a21a:	88 95 74 ff ff ff    	mov    %dl,-0x8c(%rbp)
 126a220:	0f b6 50 4e          	movzbl 0x4e(%rax),%edx
 126a224:	88 95 76 ff ff ff    	mov    %dl,-0x8a(%rbp)
 126a22a:	0f b6 91 58 01 00 00 	movzbl 0x158(%rcx),%edx
 126a231:	88 95 73 ff ff ff    	mov    %dl,-0x8d(%rbp)
 126a237:	48 89 b5 58 ff ff ff 	mov    %rsi,-0xa8(%rbp)
 126a23e:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 126a242:	44 0f b6 70 48       	movzbl 0x48(%rax),%r14d
 126a247:	48 8b 01             	mov    (%rcx),%rax
 126a24a:	48 89 85 e0 fc ff ff 	mov    %rax,-0x320(%rbp)
 126a251:	48 8b 41 08          	mov    0x8(%rcx),%rax
 126a255:	48 89 85 e8 fc ff ff 	mov    %rax,-0x318(%rbp)
 126a25c:	8b 99 59 01 00 00    	mov    0x159(%rcx),%ebx
 126a262:	c5 fc 11 85 50 e9 ff 	vmovups %ymm0,-0x16b0(%rbp)
 126a269:	ff 
 126a26a:	4c 8b 45 10          	mov    0x10(%rbp),%r8
 126a26e:	48 8d bd 60 c8 ff ff 	lea    -0x37a0(%rbp),%rdi
 126a275:	48 8d b5 50 e9 ff ff 	lea    -0x16b0(%rbp),%rsi
 126a27c:	ba 06 00 00 00       	mov    $0x6,%edx
 126a281:	4c 89 e1             	mov    %r12,%rcx
 126a284:	c5 f8 77             	vzeroupper 
 126a287:	e8 04 d3 00 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 126a28c:	c5 fc 10 85 60 c8 ff 	vmovups -0x37a0(%rbp),%ymm0
 126a293:	ff 
 126a294:	c5 fc 10 8d a0 c8 ff 	vmovups -0x3760(%rbp),%ymm1
 126a29b:	ff 
 126a29c:	c5 fc 11 8d 00 fe ff 	vmovups %ymm1,-0x200(%rbp)
 126a2a3:	ff 
 126a2a4:	c5 fc 10 8d 80 c8 ff 	vmovups -0x3780(%rbp),%ymm1
 126a2ab:	ff 
 126a2ac:	c5 fc 11 8d e0 fd ff 	vmovups %ymm1,-0x220(%rbp)
 126a2b3:	ff 
 126a2b4:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 126a2bb:	ff 
 126a2bc:	41 f6 c6 01          	test   $0x1,%r14b
 126a2c0:	4c 89 7d a8          	mov    %r15,-0x58(%rbp)
 126a2c4:	4c 89 65 90          	mov    %r12,-0x70(%rbp)
 126a2c8:	4c 89 ad 60 ff ff ff 	mov    %r13,-0xa0(%rbp)
 126a2cf:	0f 84 9c 00 00 00    	je     126a371 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1e1>
 126a2d5:	48 8d 85 10 c0 ff ff 	lea    -0x3ff0(%rbp),%rax
 126a2dc:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 126a2e0:	48 8d 85 a0 bf ff ff 	lea    -0x4060(%rbp),%rax
 126a2e7:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 126a2eb:	4c 8d b5 88 c0 ff ff 	lea    -0x3f78(%rbp),%r14
 126a2f2:	4c 89 f9             	mov    %r15,%rcx
 126a2f5:	4c 8d bd 18 c0 ff ff 	lea    -0x3fe8(%rbp),%r15
 126a2fc:	4c 89 ee             	mov    %r13,%rsi
 126a2ff:	4c 8d ad a8 bf ff ff 	lea    -0x4058(%rbp),%r13
 126a306:	c1 eb 10             	shr    $0x10,%ebx
 126a309:	66 89 9d be fd ff ff 	mov    %bx,-0x242(%rbp)
 126a310:	4c 89 e2             	mov    %r12,%rdx
 126a313:	4c 8d a5 38 bf ff ff 	lea    -0x40c8(%rbp),%r12
 126a31a:	48 8d 9d 58 be ff ff 	lea    -0x41a8(%rbp),%rbx
 126a321:	4c 8d 8d be fd ff ff 	lea    -0x242(%rbp),%r9
 126a328:	48 89 df             	mov    %rbx,%rdi
 126a32b:	4c 8b 45 10          	mov    0x10(%rbp),%r8
 126a32f:	c5 f8 77             	vzeroupper 
 126a332:	e8 99 43 ff ff       	call   125e6d0 <br.encoder.literal_block_split.chooseProposals>
 126a337:	48 8d 95 30 bf ff ff 	lea    -0x40d0(%rbp),%rdx
 126a33e:	48 8d 8d c0 be ff ff 	lea    -0x4140(%rbp),%rcx
 126a345:	4c 8d 9d 80 c0 ff ff 	lea    -0x3f80(%rbp),%r11
 126a34c:	4c 8d 95 f8 c0 ff ff 	lea    -0x3f08(%rbp),%r10
 126a353:	4c 8d 8d f0 c0 ff ff 	lea    -0x3f10(%rbp),%r9
 126a35a:	4c 8d 85 c8 be ff ff 	lea    -0x4138(%rbp),%r8
 126a361:	48 8d bd c1 be ff ff 	lea    -0x413f(%rbp),%rdi
 126a368:	48 8d b5 60 c1 ff ff 	lea    -0x3ea0(%rbp),%rsi
 126a36f:	eb 5b                	jmp    126a3cc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x23c>
 126a371:	bb 58 f0 08 01       	mov    $0x108f058,%ebx
 126a376:	be 60 f3 08 01       	mov    $0x108f360,%esi
 126a37b:	41 b9 f0 f2 08 01    	mov    $0x108f2f0,%r9d
 126a381:	41 bb 80 f2 08 01    	mov    $0x108f280,%r11d
 126a387:	b8 10 f2 08 01       	mov    $0x108f210,%eax
 126a38c:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 126a390:	b8 a0 f1 08 01       	mov    $0x108f1a0,%eax
 126a395:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 126a399:	41 b8 c8 f0 08 01    	mov    $0x108f0c8,%r8d
 126a39f:	bf c1 f0 08 01       	mov    $0x108f0c1,%edi
 126a3a4:	b9 c0 f0 08 01       	mov    $0x108f0c0,%ecx
 126a3a9:	41 ba f8 f2 08 01    	mov    $0x108f2f8,%r10d
 126a3af:	41 be 88 f2 08 01    	mov    $0x108f288,%r14d
 126a3b5:	41 bf 18 f2 08 01    	mov    $0x108f218,%r15d
 126a3bb:	41 bd a8 f1 08 01    	mov    $0x108f1a8,%r13d
 126a3c1:	41 bc 38 f1 08 01    	mov    $0x108f138,%r12d
 126a3c7:	ba 30 f1 08 01       	mov    $0x108f130,%edx
 126a3cc:	48 8b 43 60          	mov    0x60(%rbx),%rax
 126a3d0:	48 89 85 d0 f9 ff ff 	mov    %rax,-0x630(%rbp)
 126a3d7:	c5 fc 10 03          	vmovups (%rbx),%ymm0
 126a3db:	c5 fc 10 4b 20       	vmovups 0x20(%rbx),%ymm1
 126a3e0:	c5 fc 10 53 40       	vmovups 0x40(%rbx),%ymm2
 126a3e5:	c5 fc 11 95 b0 f9 ff 	vmovups %ymm2,-0x650(%rbp)
 126a3ec:	ff 
 126a3ed:	c5 fc 11 8d 90 f9 ff 	vmovups %ymm1,-0x670(%rbp)
 126a3f4:	ff 
 126a3f5:	c5 fc 11 85 70 f9 ff 	vmovups %ymm0,-0x690(%rbp)
 126a3fc:	ff 
 126a3fd:	0f b6 09             	movzbl (%rcx),%ecx
 126a400:	0f b6 12             	movzbl (%rdx),%edx
 126a403:	49 8b 44 24 60       	mov    0x60(%r12),%rax
 126a408:	48 89 85 40 fa ff ff 	mov    %rax,-0x5c0(%rbp)
 126a40f:	c4 c1 7c 10 04 24    	vmovups (%r12),%ymm0
 126a415:	c4 c1 7c 10 4c 24 40 	vmovups 0x40(%r12),%ymm1
 126a41c:	c5 fc 11 8d 20 fa ff 	vmovups %ymm1,-0x5e0(%rbp)
 126a423:	ff 
 126a424:	c4 c1 7c 10 4c 24 20 	vmovups 0x20(%r12),%ymm1
 126a42b:	c5 fc 11 8d 00 fa ff 	vmovups %ymm1,-0x600(%rbp)
 126a432:	ff 
 126a433:	c5 fc 11 85 e0 f9 ff 	vmovups %ymm0,-0x620(%rbp)
 126a43a:	ff 
 126a43b:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126a43f:	0f b6 00             	movzbl (%rax),%eax
 126a442:	88 85 1b ff ff ff    	mov    %al,-0xe5(%rbp)
 126a448:	c4 c1 7c 10 45 20    	vmovups 0x20(%r13),%ymm0
 126a44e:	c4 c1 7c 10 4d 40    	vmovups 0x40(%r13),%ymm1
 126a454:	c5 fc 11 85 70 fa ff 	vmovups %ymm0,-0x590(%rbp)
 126a45b:	ff 
 126a45c:	c5 fc 11 8d 90 fa ff 	vmovups %ymm1,-0x570(%rbp)
 126a463:	ff 
 126a464:	c4 c1 7c 10 45 00    	vmovups 0x0(%r13),%ymm0
 126a46a:	49 8b 45 60          	mov    0x60(%r13),%rax
 126a46e:	48 89 85 b0 fa ff ff 	mov    %rax,-0x550(%rbp)
 126a475:	c5 fc 11 85 50 fa ff 	vmovups %ymm0,-0x5b0(%rbp)
 126a47c:	ff 
 126a47d:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126a481:	0f b6 00             	movzbl (%rax),%eax
 126a484:	88 45 a7             	mov    %al,-0x59(%rbp)
 126a487:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 126a48c:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 126a492:	c5 fc 11 85 c0 fa ff 	vmovups %ymm0,-0x540(%rbp)
 126a499:	ff 
 126a49a:	c5 fc 11 8d e0 fa ff 	vmovups %ymm1,-0x520(%rbp)
 126a4a1:	ff 
 126a4a2:	c4 c1 7c 10 47 40    	vmovups 0x40(%r15),%ymm0
 126a4a8:	c5 fc 11 85 00 fb ff 	vmovups %ymm0,-0x500(%rbp)
 126a4af:	ff 
 126a4b0:	49 8b 47 60          	mov    0x60(%r15),%rax
 126a4b4:	48 89 85 20 fb ff ff 	mov    %rax,-0x4e0(%rbp)
 126a4bb:	41 0f b6 03          	movzbl (%r11),%eax
 126a4bf:	88 85 1c ff ff ff    	mov    %al,-0xe4(%rbp)
 126a4c5:	49 8b 46 60          	mov    0x60(%r14),%rax
 126a4c9:	48 89 85 90 fb ff ff 	mov    %rax,-0x470(%rbp)
 126a4d0:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 126a4d5:	c4 c1 7c 10 4e 40    	vmovups 0x40(%r14),%ymm1
 126a4db:	c5 fc 11 8d 70 fb ff 	vmovups %ymm1,-0x490(%rbp)
 126a4e2:	ff 
 126a4e3:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 126a4e9:	c5 fc 11 8d 50 fb ff 	vmovups %ymm1,-0x4b0(%rbp)
 126a4f0:	ff 
 126a4f1:	c5 fc 11 85 30 fb ff 	vmovups %ymm0,-0x4d0(%rbp)
 126a4f8:	ff 
 126a4f9:	41 0f b6 01          	movzbl (%r9),%eax
 126a4fd:	88 85 1d ff ff ff    	mov    %al,-0xe3(%rbp)
 126a503:	49 8b 42 60          	mov    0x60(%r10),%rax
 126a507:	48 89 85 00 fc ff ff 	mov    %rax,-0x400(%rbp)
 126a50e:	c4 c1 7c 10 02       	vmovups (%r10),%ymm0
 126a513:	c4 c1 7c 10 4a 40    	vmovups 0x40(%r10),%ymm1
 126a519:	c5 fc 11 8d e0 fb ff 	vmovups %ymm1,-0x420(%rbp)
 126a520:	ff 
 126a521:	c4 c1 7c 10 4a 20    	vmovups 0x20(%r10),%ymm1
 126a527:	c5 fc 11 8d c0 fb ff 	vmovups %ymm1,-0x440(%rbp)
 126a52e:	ff 
 126a52f:	c5 fc 11 85 a0 fb ff 	vmovups %ymm0,-0x460(%rbp)
 126a536:	ff 
 126a537:	88 95 1a ff ff ff    	mov    %dl,-0xe6(%rbp)
 126a53d:	84 d2                	test   %dl,%dl
 126a53f:	88 4d a6             	mov    %cl,-0x5a(%rbp)
 126a542:	74 44                	je     126a588 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3f8>
 126a544:	49 8b 40 60          	mov    0x60(%r8),%rax
 126a548:	48 89 85 a0 dc ff ff 	mov    %rax,-0x2360(%rbp)
 126a54f:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 126a554:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 126a55a:	c4 c1 7c 10 50 40    	vmovups 0x40(%r8),%ymm2
 126a560:	c5 fc 11 95 80 dc ff 	vmovups %ymm2,-0x2380(%rbp)
 126a567:	ff 
 126a568:	c5 fc 11 8d 60 dc ff 	vmovups %ymm1,-0x23a0(%rbp)
 126a56f:	ff 
 126a570:	c5 fc 11 85 40 dc ff 	vmovups %ymm0,-0x23c0(%rbp)
 126a577:	ff 
 126a578:	c6 85 a8 dc ff ff 01 	movb   $0x1,-0x2358(%rbp)
 126a57f:	48 8d 85 40 dc ff ff 	lea    -0x23c0(%rbp),%rax
 126a586:	eb 4f                	jmp    126a5d7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x447>
 126a588:	48 8b 43 60          	mov    0x60(%rbx),%rax
 126a58c:	48 89 85 60 ea ff ff 	mov    %rax,-0x15a0(%rbp)
 126a593:	c5 fc 10 03          	vmovups (%rbx),%ymm0
 126a597:	c5 fc 10 4b 20       	vmovups 0x20(%rbx),%ymm1
 126a59c:	c5 fc 10 53 40       	vmovups 0x40(%rbx),%ymm2
 126a5a1:	c5 fc 11 95 40 ea ff 	vmovups %ymm2,-0x15c0(%rbp)
 126a5a8:	ff 
 126a5a9:	c5 fc 11 8d 20 ea ff 	vmovups %ymm1,-0x15e0(%rbp)
 126a5b0:	ff 
 126a5b1:	c5 fc 11 85 00 ea ff 	vmovups %ymm0,-0x1600(%rbp)
 126a5b8:	ff 
 126a5b9:	88 8d 68 ea ff ff    	mov    %cl,-0x1598(%rbp)
 126a5bf:	8b 07                	mov    (%rdi),%eax
 126a5c1:	8b 4f 03             	mov    0x3(%rdi),%ecx
 126a5c4:	89 85 69 ea ff ff    	mov    %eax,-0x1597(%rbp)
 126a5ca:	89 8d 6c ea ff ff    	mov    %ecx,-0x1594(%rbp)
 126a5d0:	48 8d 85 00 ea ff ff 	lea    -0x1600(%rbp),%rax
 126a5d7:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 126a5db:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126a5df:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 126a5e3:	4c 8b 65 90          	mov    -0x70(%rbp),%r12
 126a5e7:	4c 8b ad 60 ff ff ff 	mov    -0xa0(%rbp),%r13
 126a5ee:	0f b6 06             	movzbl (%rsi),%eax
 126a5f1:	88 85 1e ff ff ff    	mov    %al,-0xe2(%rbp)
 126a5f7:	b8 68 f3 08 01       	mov    $0x108f368,%eax
 126a5fc:	f6 85 68 ff ff ff 01 	testb  $0x1,-0x98(%rbp)
 126a603:	74 56                	je     126a65b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4cb>
 126a605:	48 8d bd 40 e3 ff ff 	lea    -0x1cc0(%rbp),%rdi
 126a60c:	4c 89 f6             	mov    %r14,%rsi
 126a60f:	4c 89 ea             	mov    %r13,%rdx
 126a612:	4c 89 e1             	mov    %r12,%rcx
 126a615:	4d 89 f8             	mov    %r15,%r8
 126a618:	4c 8b 4d 10          	mov    0x10(%rbp),%r9
 126a61c:	c5 f8 77             	vzeroupper 
 126a61f:	e8 8c 19 ff ff       	call   125bfb0 <br.chooseAdaptiveLiteralSplitAlloc>
 126a624:	0f b7 9d 78 e3 ff ff 	movzwl -0x1c88(%rbp),%ebx
 126a62b:	48 85 db             	test   %rbx,%rbx
 126a62e:	0f 85 c5 81 00 00    	jne    12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 126a634:	c5 fc 10 85 40 e3 ff 	vmovups -0x1cc0(%rbp),%ymm0
 126a63b:	ff 
 126a63c:	c5 fc 10 8d 58 e3 ff 	vmovups -0x1ca8(%rbp),%ymm1
 126a643:	ff 
 126a644:	c5 fc 11 8d 18 dc ff 	vmovups %ymm1,-0x23e8(%rbp)
 126a64b:	ff 
 126a64c:	c5 fc 11 85 00 dc ff 	vmovups %ymm0,-0x2400(%rbp)
 126a653:	ff 
 126a654:	48 8d 85 00 dc ff ff 	lea    -0x2400(%rbp),%rax
 126a65b:	c5 fc 10 40 18       	vmovups 0x18(%rax),%ymm0
 126a660:	c5 fc 11 85 38 ff ff 	vmovups %ymm0,-0xc8(%rbp)
 126a667:	ff 
 126a668:	c5 fc 10 00          	vmovups (%rax),%ymm0
 126a66c:	c5 fc 11 85 20 ff ff 	vmovups %ymm0,-0xe0(%rbp)
 126a673:	ff 
 126a674:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 126a67b:	b9 d0 f3 08 01       	mov    $0x108f3d0,%ecx
 126a680:	0f 84 96 00 00 00    	je     126a71c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x58c>
 126a686:	f6 85 77 ff ff ff 01 	testb  $0x1,-0x89(%rbp)
 126a68d:	0f 84 89 00 00 00    	je     126a71c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x58c>
 126a693:	c5 fc 10 00          	vmovups (%rax),%ymm0
 126a697:	c5 fc 10 48 10       	vmovups 0x10(%rax),%ymm1
 126a69c:	c5 fc 11 8d 30 e9 ff 	vmovups %ymm1,-0x16d0(%rbp)
 126a6a3:	ff 
 126a6a4:	c5 fc 11 85 20 e9 ff 	vmovups %ymm0,-0x16e0(%rbp)
 126a6ab:	ff 
 126a6ac:	48 8d 85 20 e9 ff ff 	lea    -0x16e0(%rbp),%rax
 126a6b3:	48 89 04 24          	mov    %rax,(%rsp)
 126a6b7:	48 8d bd 48 d3 ff ff 	lea    -0x2cb8(%rbp),%rdi
 126a6be:	4c 89 f6             	mov    %r14,%rsi
 126a6c1:	4c 89 ea             	mov    %r13,%rdx
 126a6c4:	4c 89 e1             	mov    %r12,%rcx
 126a6c7:	4d 89 f8             	mov    %r15,%r8
 126a6ca:	4c 8b 4d 10          	mov    0x10(%rbp),%r9
 126a6ce:	c5 f8 77             	vzeroupper 
 126a6d1:	e8 8a ee fe ff       	call   1259560 <br.encoder.literal_joint_context_split.chooseAlloc>
 126a6d6:	0f b7 85 a8 d3 ff ff 	movzwl -0x2c58(%rbp),%eax
 126a6dd:	85 c0                	test   %eax,%eax
 126a6df:	0f 85 1b 6c 00 00    	jne    1271300 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7170>
 126a6e5:	c5 fc 10 85 48 d3 ff 	vmovups -0x2cb8(%rbp),%ymm0
 126a6ec:	ff 
 126a6ed:	c5 fc 10 8d 88 d3 ff 	vmovups -0x2c78(%rbp),%ymm1
 126a6f4:	ff 
 126a6f5:	c5 fc 11 8d 40 c8 ff 	vmovups %ymm1,-0x37c0(%rbp)
 126a6fc:	ff 
 126a6fd:	c5 fc 10 8d 68 d3 ff 	vmovups -0x2c98(%rbp),%ymm1
 126a704:	ff 
 126a705:	c5 fc 11 8d 20 c8 ff 	vmovups %ymm1,-0x37e0(%rbp)
 126a70c:	ff 
 126a70d:	c5 fc 11 85 00 c8 ff 	vmovups %ymm0,-0x3800(%rbp)
 126a714:	ff 
 126a715:	48 8d 8d 00 c8 ff ff 	lea    -0x3800(%rbp),%rcx
 126a71c:	c5 fc 10 41 20       	vmovups 0x20(%rcx),%ymm0
 126a721:	c5 fc 10 49 40       	vmovups 0x40(%rcx),%ymm1
 126a726:	c5 fc 11 8d 60 fe ff 	vmovups %ymm1,-0x1a0(%rbp)
 126a72d:	ff 
 126a72e:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 126a735:	ff 
 126a736:	c5 fc 10 01          	vmovups (%rcx),%ymm0
 126a73a:	c5 fc 11 85 20 fe ff 	vmovups %ymm0,-0x1e0(%rbp)
 126a741:	ff 
 126a742:	c5 fc 10 85 70 e9 ff 	vmovups -0x1690(%rbp),%ymm0
 126a749:	ff 
 126a74a:	c5 fc 11 85 20 fc ff 	vmovups %ymm0,-0x3e0(%rbp)
 126a751:	ff 
 126a752:	0f b6 85 75 ff ff ff 	movzbl -0x8b(%rbp),%eax
 126a759:	24 01                	and    $0x1,%al
 126a75b:	88 85 40 fc ff ff    	mov    %al,-0x3c0(%rbp)
 126a761:	0f b6 85 76 ff ff ff 	movzbl -0x8a(%rbp),%eax
 126a768:	24 1f                	and    $0x1f,%al
 126a76a:	88 85 41 fc ff ff    	mov    %al,-0x3bf(%rbp)
 126a770:	c5 f8 28 85 f0 fc ff 	vmovaps -0x310(%rbp),%xmm0
 126a777:	ff 
 126a778:	c5 f8 29 85 10 fc ff 	vmovaps %xmm0,-0x3f0(%rbp)
 126a77f:	ff 
 126a780:	48 8d 85 10 fc ff ff 	lea    -0x3f0(%rbp),%rax
 126a787:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126a78c:	0f b6 85 74 ff ff ff 	movzbl -0x8c(%rbp),%eax
 126a793:	89 44 24 10          	mov    %eax,0x10(%rsp)
 126a797:	0f b6 45 a5          	movzbl -0x5b(%rbp),%eax
 126a79b:	89 44 24 08          	mov    %eax,0x8(%rsp)
 126a79f:	0f b6 45 b0          	movzbl -0x50(%rbp),%eax
 126a7a3:	89 04 24             	mov    %eax,(%rsp)
 126a7a6:	44 0f b6 85 73 ff ff 	movzbl -0x8d(%rbp),%r8d
 126a7ad:	ff 
 126a7ae:	44 0f b6 4d d0       	movzbl -0x30(%rbp),%r9d
 126a7b3:	48 8d bd 68 c1 ff ff 	lea    -0x3e98(%rbp),%rdi
 126a7ba:	4c 89 f6             	mov    %r14,%rsi
 126a7bd:	4c 89 fa             	mov    %r15,%rdx
 126a7c0:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 126a7c4:	c5 f8 77             	vzeroupper 
 126a7c7:	e8 c4 ac fd ff       	call   1245490 <br.chooseCommandAndDistanceSplitsAlloc>
 126a7cc:	0f b7 9d f8 c7 ff ff 	movzwl -0x3808(%rbp),%ebx
 126a7d3:	48 85 db             	test   %rbx,%rbx
 126a7d6:	0f 85 a0 6a 00 00    	jne    127127c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x70ec>
 126a7dc:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 126a7e3:	48 8d b5 68 c1 ff ff 	lea    -0x3e98(%rbp),%rsi
 126a7ea:	ba 90 06 00 00       	mov    $0x690,%edx
 126a7ef:	e8 6c 4f 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 126a7f4:	c5 fc 10 85 b0 c4 ff 	vmovups -0x3b50(%rbp),%ymm0
 126a7fb:	ff 
 126a7fc:	c5 fc 10 8d d0 c4 ff 	vmovups -0x3b30(%rbp),%ymm1
 126a803:	ff 
 126a804:	c5 fc 10 95 f0 c4 ff 	vmovups -0x3b10(%rbp),%ymm2
 126a80b:	ff 
 126a80c:	c5 fc 11 85 d0 f6 ff 	vmovups %ymm0,-0x930(%rbp)
 126a813:	ff 
 126a814:	c5 fc 11 8d f0 f6 ff 	vmovups %ymm1,-0x910(%rbp)
 126a81b:	ff 
 126a81c:	c5 fc 11 95 10 f7 ff 	vmovups %ymm2,-0x8f0(%rbp)
 126a823:	ff 
 126a824:	48 8b 85 10 c5 ff ff 	mov    -0x3af0(%rbp),%rax
 126a82b:	48 89 85 30 f7 ff ff 	mov    %rax,-0x8d0(%rbp)
 126a832:	0f b6 9d 60 e0 ff ff 	movzbl -0x1fa0(%rbp),%ebx
 126a839:	0f b6 8d d0 e0 ff ff 	movzbl -0x1f30(%rbp),%ecx
 126a840:	c5 fc 10 85 90 c5 ff 	vmovups -0x3a70(%rbp),%ymm0
 126a847:	ff 
 126a848:	c5 fc 11 85 40 f7 ff 	vmovups %ymm0,-0x8c0(%rbp)
 126a84f:	ff 
 126a850:	c5 fc 10 85 b0 c5 ff 	vmovups -0x3a50(%rbp),%ymm0
 126a857:	ff 
 126a858:	c5 fc 11 85 60 f7 ff 	vmovups %ymm0,-0x8a0(%rbp)
 126a85f:	ff 
 126a860:	c5 fc 10 85 d0 c5 ff 	vmovups -0x3a30(%rbp),%ymm0
 126a867:	ff 
 126a868:	c5 fc 11 85 80 f7 ff 	vmovups %ymm0,-0x880(%rbp)
 126a86f:	ff 
 126a870:	48 8b 85 f0 c5 ff ff 	mov    -0x3a10(%rbp),%rax
 126a877:	48 89 85 a0 f7 ff ff 	mov    %rax,-0x860(%rbp)
 126a87e:	44 0f b6 9d 40 e1 ff 	movzbl -0x1ec0(%rbp),%r11d
 126a885:	ff 
 126a886:	44 0f b6 95 b0 e1 ff 	movzbl -0x1e50(%rbp),%r10d
 126a88d:	ff 
 126a88e:	c5 fc 10 85 00 c6 ff 	vmovups -0x3a00(%rbp),%ymm0
 126a895:	ff 
 126a896:	c5 fc 10 8d 20 c6 ff 	vmovups -0x39e0(%rbp),%ymm1
 126a89d:	ff 
 126a89e:	c5 fc 10 95 40 c6 ff 	vmovups -0x39c0(%rbp),%ymm2
 126a8a5:	ff 
 126a8a6:	c5 fc 11 85 b0 f7 ff 	vmovups %ymm0,-0x850(%rbp)
 126a8ad:	ff 
 126a8ae:	c5 fc 11 8d d0 f7 ff 	vmovups %ymm1,-0x830(%rbp)
 126a8b5:	ff 
 126a8b6:	c5 fc 11 95 f0 f7 ff 	vmovups %ymm2,-0x810(%rbp)
 126a8bd:	ff 
 126a8be:	48 8b 85 60 c6 ff ff 	mov    -0x39a0(%rbp),%rax
 126a8c5:	48 89 85 10 f8 ff ff 	mov    %rax,-0x7f0(%rbp)
 126a8cc:	c5 fc 10 85 70 c6 ff 	vmovups -0x3990(%rbp),%ymm0
 126a8d3:	ff 
 126a8d4:	c5 fc 11 85 20 f8 ff 	vmovups %ymm0,-0x7e0(%rbp)
 126a8db:	ff 
 126a8dc:	c5 fc 10 85 90 c6 ff 	vmovups -0x3970(%rbp),%ymm0
 126a8e3:	ff 
 126a8e4:	c5 fc 11 85 40 f8 ff 	vmovups %ymm0,-0x7c0(%rbp)
 126a8eb:	ff 
 126a8ec:	c5 fc 10 85 b0 c6 ff 	vmovups -0x3950(%rbp),%ymm0
 126a8f3:	ff 
 126a8f4:	c5 fc 11 85 60 f8 ff 	vmovups %ymm0,-0x7a0(%rbp)
 126a8fb:	ff 
 126a8fc:	48 8b 85 d0 c6 ff ff 	mov    -0x3930(%rbp),%rax
 126a903:	48 89 85 80 f8 ff ff 	mov    %rax,-0x780(%rbp)
 126a90a:	44 0f b6 8d 20 e2 ff 	movzbl -0x1de0(%rbp),%r9d
 126a911:	ff 
 126a912:	44 0f b6 85 90 e2 ff 	movzbl -0x1d70(%rbp),%r8d
 126a919:	ff 
 126a91a:	48 8b 85 40 c7 ff ff 	mov    -0x38c0(%rbp),%rax
 126a921:	48 89 85 f0 f8 ff ff 	mov    %rax,-0x710(%rbp)
 126a928:	c5 fc 10 85 e0 c6 ff 	vmovups -0x3920(%rbp),%ymm0
 126a92f:	ff 
 126a930:	c5 fc 10 8d 00 c7 ff 	vmovups -0x3900(%rbp),%ymm1
 126a937:	ff 
 126a938:	c5 fc 10 95 20 c7 ff 	vmovups -0x38e0(%rbp),%ymm2
 126a93f:	ff 
 126a940:	c5 fc 11 95 d0 f8 ff 	vmovups %ymm2,-0x730(%rbp)
 126a947:	ff 
 126a948:	c5 fc 11 8d b0 f8 ff 	vmovups %ymm1,-0x750(%rbp)
 126a94f:	ff 
 126a950:	c5 fc 11 85 90 f8 ff 	vmovups %ymm0,-0x770(%rbp)
 126a957:	ff 
 126a958:	48 8b 85 b0 c7 ff ff 	mov    -0x3850(%rbp),%rax
 126a95f:	48 89 85 60 f9 ff ff 	mov    %rax,-0x6a0(%rbp)
 126a966:	c5 fc 10 85 90 c7 ff 	vmovups -0x3870(%rbp),%ymm0
 126a96d:	ff 
 126a96e:	c5 fc 11 85 40 f9 ff 	vmovups %ymm0,-0x6c0(%rbp)
 126a975:	ff 
 126a976:	c5 fc 10 85 70 c7 ff 	vmovups -0x3890(%rbp),%ymm0
 126a97d:	ff 
 126a97e:	c5 fc 11 85 20 f9 ff 	vmovups %ymm0,-0x6e0(%rbp)
 126a985:	ff 
 126a986:	c5 fc 10 85 50 c7 ff 	vmovups -0x38b0(%rbp),%ymm0
 126a98d:	ff 
 126a98e:	c5 fc 11 85 00 f9 ff 	vmovups %ymm0,-0x700(%rbp)
 126a995:	ff 
 126a996:	88 8d f0 fc ff ff    	mov    %cl,-0x310(%rbp)
 126a99c:	84 c9                	test   %cl,%cl
 126a99e:	0f 84 b0 00 00 00    	je     126aa54 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8c4>
 126a9a4:	48 8b 85 80 c5 ff ff 	mov    -0x3a80(%rbp),%rax
 126a9ab:	48 89 85 f0 db ff ff 	mov    %rax,-0x2410(%rbp)
 126a9b2:	c5 fc 10 85 40 c5 ff 	vmovups -0x3ac0(%rbp),%ymm0
 126a9b9:	ff 
 126a9ba:	c5 fc 10 8d 60 c5 ff 	vmovups -0x3aa0(%rbp),%ymm1
 126a9c1:	ff 
 126a9c2:	c5 fc 11 8d d0 db ff 	vmovups %ymm1,-0x2430(%rbp)
 126a9c9:	ff 
 126a9ca:	c5 fc 11 85 b0 db ff 	vmovups %ymm0,-0x2450(%rbp)
 126a9d1:	ff 
 126a9d2:	c5 fc 10 85 20 c5 ff 	vmovups -0x3ae0(%rbp),%ymm0
 126a9d9:	ff 
 126a9da:	c5 fc 11 85 90 db ff 	vmovups %ymm0,-0x2470(%rbp)
 126a9e1:	ff 
 126a9e2:	c6 85 f8 db ff ff 01 	movb   $0x1,-0x2408(%rbp)
 126a9e9:	48 8d 85 90 db ff ff 	lea    -0x2470(%rbp),%rax
 126a9f0:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 126a9f4:	b0 01                	mov    $0x1,%al
 126a9f6:	80 bd 88 dd ff ff 00 	cmpb   $0x0,-0x2278(%rbp)
 126a9fd:	0f 84 c4 00 00 00    	je     126aac7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x937>
 126aa03:	48 8b 8d 38 c2 ff ff 	mov    -0x3dc8(%rbp),%rcx
 126aa0a:	48 89 8d 80 db ff ff 	mov    %rcx,-0x2480(%rbp)
 126aa11:	c5 fc 10 85 d8 c1 ff 	vmovups -0x3e28(%rbp),%ymm0
 126aa18:	ff 
 126aa19:	c5 fc 10 8d f8 c1 ff 	vmovups -0x3e08(%rbp),%ymm1
 126aa20:	ff 
 126aa21:	c5 fc 10 95 18 c2 ff 	vmovups -0x3de8(%rbp),%ymm2
 126aa28:	ff 
 126aa29:	c5 fc 11 95 60 db ff 	vmovups %ymm2,-0x24a0(%rbp)
 126aa30:	ff 
 126aa31:	c5 fc 11 8d 40 db ff 	vmovups %ymm1,-0x24c0(%rbp)
 126aa38:	ff 
 126aa39:	c5 fc 11 85 20 db ff 	vmovups %ymm0,-0x24e0(%rbp)
 126aa40:	ff 
 126aa41:	c6 85 88 db ff ff 01 	movb   $0x1,-0x2478(%rbp)
 126aa48:	48 8d 8d 20 db ff ff 	lea    -0x24e0(%rbp),%rcx
 126aa4f:	e9 ba 00 00 00       	jmp    126ab0e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x97e>
 126aa54:	48 8d 85 b0 c4 ff ff 	lea    -0x3b50(%rbp),%rax
 126aa5b:	48 8b 48 60          	mov    0x60(%rax),%rcx
 126aa5f:	48 89 8d f0 e9 ff ff 	mov    %rcx,-0x1610(%rbp)
 126aa66:	c5 fc 10 00          	vmovups (%rax),%ymm0
 126aa6a:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 126aa6f:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 126aa74:	c5 fc 11 95 d0 e9 ff 	vmovups %ymm2,-0x1630(%rbp)
 126aa7b:	ff 
 126aa7c:	c5 fc 11 8d b0 e9 ff 	vmovups %ymm1,-0x1650(%rbp)
 126aa83:	ff 
 126aa84:	c5 fc 11 85 90 e9 ff 	vmovups %ymm0,-0x1670(%rbp)
 126aa8b:	ff 
 126aa8c:	88 9d f8 e9 ff ff    	mov    %bl,-0x1608(%rbp)
 126aa92:	8b 85 19 c5 ff ff    	mov    -0x3ae7(%rbp),%eax
 126aa98:	8b 8d 1c c5 ff ff    	mov    -0x3ae4(%rbp),%ecx
 126aa9e:	89 85 f9 e9 ff ff    	mov    %eax,-0x1607(%rbp)
 126aaa4:	89 8d fc e9 ff ff    	mov    %ecx,-0x1604(%rbp)
 126aaaa:	84 db                	test   %bl,%bl
 126aaac:	0f 95 c0             	setne  %al
 126aaaf:	48 8d 8d 90 e9 ff ff 	lea    -0x1670(%rbp),%rcx
 126aab6:	48 89 4d c8          	mov    %rcx,-0x38(%rbp)
 126aaba:	80 bd 88 dd ff ff 00 	cmpb   $0x0,-0x2278(%rbp)
 126aac1:	0f 85 3c ff ff ff    	jne    126aa03 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x873>
 126aac7:	c5 fc 10 85 68 c1 ff 	vmovups -0x3e98(%rbp),%ymm0
 126aace:	ff 
 126aacf:	c5 fc 10 8d a8 c1 ff 	vmovups -0x3e58(%rbp),%ymm1
 126aad6:	ff 
 126aad7:	c5 fc 10 95 b8 c1 ff 	vmovups -0x3e48(%rbp),%ymm2
 126aade:	ff 
 126aadf:	c5 fc 11 95 10 c9 ff 	vmovups %ymm2,-0x36f0(%rbp)
 126aae6:	ff 
 126aae7:	c5 fc 11 8d 00 c9 ff 	vmovups %ymm1,-0x3700(%rbp)
 126aaee:	ff 
 126aaef:	c5 fc 10 8d 88 c1 ff 	vmovups -0x3e78(%rbp),%ymm1
 126aaf6:	ff 
 126aaf7:	c5 fc 11 8d e0 c8 ff 	vmovups %ymm1,-0x3720(%rbp)
 126aafe:	ff 
 126aaff:	c5 fc 11 85 c0 c8 ff 	vmovups %ymm0,-0x3740(%rbp)
 126ab06:	ff 
 126ab07:	48 8d 8d c0 c8 ff ff 	lea    -0x3740(%rbp),%rcx
 126ab0e:	48 89 8d 68 ff ff ff 	mov    %rcx,-0x98(%rbp)
 126ab15:	40 b6 01             	mov    $0x1,%sil
 126ab18:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 126ab1c:	80 79 68 00          	cmpb   $0x0,0x68(%rcx)
 126ab20:	75 12                	jne    126ab34 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x9a4>
 126ab22:	48 8b 8d 68 ff ff ff 	mov    -0x98(%rbp),%rcx
 126ab29:	80 79 68 00          	cmpb   $0x0,0x68(%rcx)
 126ab2d:	40 0f 95 c6          	setne  %sil
 126ab31:	40 08 c6             	or     %al,%sil
 126ab34:	0f b6 bd 00 e3 ff ff 	movzbl -0x1d00(%rbp),%edi
 126ab3b:	0f b6 8d 50 ff ff ff 	movzbl -0xb0(%rbp),%ecx
 126ab42:	0f b6 85 f0 df ff ff 	movzbl -0x2010(%rbp),%eax
 126ab49:	40 f6 c6 01          	test   $0x1,%sil
 126ab4d:	75 47                	jne    126ab96 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xa06>
 126ab4f:	84 c9                	test   %cl,%cl
 126ab51:	75 43                	jne    126ab96 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xa06>
 126ab53:	84 c0                	test   %al,%al
 126ab55:	75 3f                	jne    126ab96 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xa06>
 126ab57:	80 bd 38 e3 ff ff 00 	cmpb   $0x0,-0x1cc8(%rbp)
 126ab5e:	75 36                	jne    126ab96 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xa06>
 126ab60:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126ab64:	c5 fc 11 85 d8 df ff 	vmovups %ymm0,-0x2028(%rbp)
 126ab6b:	ff 
 126ab6c:	c5 fc 11 85 c0 df ff 	vmovups %ymm0,-0x2040(%rbp)
 126ab73:	ff 
 126ab74:	c5 fc 11 85 08 e3 ff 	vmovups %ymm0,-0x1cf8(%rbp)
 126ab7b:	ff 
 126ab7c:	c5 fc 11 85 20 e3 ff 	vmovups %ymm0,-0x1ce0(%rbp)
 126ab83:	ff 
 126ab84:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 126ab8b:	0f 85 0b 48 00 00    	jne    126f39c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x520c>
 126ab91:	e9 cd 48 00 00       	jmp    126f463 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x52d3>
 126ab96:	48 8b 55 18          	mov    0x18(%rbp),%rdx
 126ab9a:	c5 fc 10 42 70       	vmovups 0x70(%rdx),%ymm0
 126ab9f:	c5 fc 11 85 f0 fe ff 	vmovups %ymm0,-0x110(%rbp)
 126aba6:	ff 
 126aba7:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 126abab:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 126abb0:	c5 fc 10 52 40       	vmovups 0x40(%rdx),%ymm2
 126abb5:	c5 fc 10 5a 60       	vmovups 0x60(%rdx),%ymm3
 126abba:	c5 fc 11 9d e0 fe ff 	vmovups %ymm3,-0x120(%rbp)
 126abc1:	ff 
 126abc2:	c5 fc 11 95 c0 fe ff 	vmovups %ymm2,-0x140(%rbp)
 126abc9:	ff 
 126abca:	c5 fc 11 8d a0 fe ff 	vmovups %ymm1,-0x160(%rbp)
 126abd1:	ff 
 126abd2:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 126abd9:	ff 
 126abda:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 126abde:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 126abe3:	c5 fc 10 52 40       	vmovups 0x40(%rdx),%ymm2
 126abe8:	c5 fc 10 5a 60       	vmovups 0x60(%rdx),%ymm3
 126abed:	c5 fc 11 85 50 fc ff 	vmovups %ymm0,-0x3b0(%rbp)
 126abf4:	ff 
 126abf5:	c5 fc 11 8d 70 fc ff 	vmovups %ymm1,-0x390(%rbp)
 126abfc:	ff 
 126abfd:	c5 fc 11 95 90 fc ff 	vmovups %ymm2,-0x370(%rbp)
 126ac04:	ff 
 126ac05:	c5 fc 11 9d b0 fc ff 	vmovups %ymm3,-0x350(%rbp)
 126ac0c:	ff 
 126ac0d:	c5 fc 10 42 70       	vmovups 0x70(%rdx),%ymm0
 126ac12:	c5 fc 11 85 c0 fc ff 	vmovups %ymm0,-0x340(%rbp)
 126ac19:	ff 
 126ac1a:	40 f6 c6 01          	test   $0x1,%sil
 126ac1e:	40 88 75 a5          	mov    %sil,-0x5b(%rbp)
 126ac22:	40 88 bd 1f ff ff ff 	mov    %dil,-0xe1(%rbp)
 126ac29:	44 88 85 77 ff ff ff 	mov    %r8b,-0x89(%rbp)
 126ac30:	44 88 8d 76 ff ff ff 	mov    %r9b,-0x8a(%rbp)
 126ac37:	44 88 95 75 ff ff ff 	mov    %r10b,-0x8b(%rbp)
 126ac3e:	44 88 9d 74 ff ff ff 	mov    %r11b,-0x8c(%rbp)
 126ac45:	88 9d 73 ff ff ff    	mov    %bl,-0x8d(%rbp)
 126ac4b:	0f 84 69 01 00 00    	je     126adba <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xc2a>
 126ac51:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126ac55:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126ac5a:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126ac61:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126ac66:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126ac6a:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126ac70:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126ac74:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126ac79:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126ac7d:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126ac82:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126ac86:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126ac8b:	48 8d 85 50 fc ff ff 	lea    -0x3b0(%rbp),%rax
 126ac92:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126ac97:	48 8b 45 10          	mov    0x10(%rbp),%rax
 126ac9b:	48 89 04 24          	mov    %rax,(%rsp)
 126ac9f:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126aca6:	00 00 
 126aca8:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126acaf:	00 00 
 126acb1:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126acb8:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 126acbf:	4c 89 f2             	mov    %r14,%rdx
 126acc2:	4c 89 e9             	mov    %r13,%rcx
 126acc5:	4d 89 e0             	mov    %r12,%r8
 126acc8:	4d 89 f9             	mov    %r15,%r9
 126accb:	c5 f8 77             	vzeroupper 
 126acce:	e8 ad 7e 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126acd3:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126acd7:	48 85 db             	test   %rbx,%rbx
 126acda:	0f 84 55 04 00 00    	je     126b135 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xfa5>
 126ace0:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126ace7:	ff 
 126ace8:	48 8b 45 18          	mov    0x18(%rbp),%rax
 126acec:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 126acf1:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126acf8:	ff 
 126acf9:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126ad00:	ff 
 126ad01:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126ad08:	ff 
 126ad09:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126ad10:	ff 
 126ad11:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 126ad16:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 126ad1b:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 126ad20:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 126ad24:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 126ad2b:	4c 89 f6             	mov    %r14,%rsi
 126ad2e:	c5 f8 77             	vzeroupper 
 126ad31:	e8 4a a5 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 126ad36:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 126ad3d:	74 42                	je     126ad81 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xbf1>
 126ad3f:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 126ad46:	ff 
 126ad47:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 126ad4e:	ff 
 126ad4f:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 126ad56:	ff 
 126ad57:	c5 fc 11 95 c8 d2 ff 	vmovups %ymm2,-0x2d38(%rbp)
 126ad5e:	ff 
 126ad5f:	c5 fc 11 8d b0 d2 ff 	vmovups %ymm1,-0x2d50(%rbp)
 126ad66:	ff 
 126ad67:	c5 fc 11 85 90 d2 ff 	vmovups %ymm0,-0x2d70(%rbp)
 126ad6e:	ff 
 126ad6f:	48 8d bd 90 d2 ff ff 	lea    -0x2d70(%rbp),%rdi
 126ad76:	4c 89 f6             	mov    %r14,%rsi
 126ad79:	c5 f8 77             	vzeroupper 
 126ad7c:	e8 2f a6 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 126ad81:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 126ad88:	0f 84 6b 7a 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 126ad8e:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 126ad95:	ff 
 126ad96:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 126ad9d:	ff 
 126ad9e:	c5 fc 11 8d 40 e8 ff 	vmovups %ymm1,-0x17c0(%rbp)
 126ada5:	ff 
 126ada6:	c5 fc 11 85 30 e8 ff 	vmovups %ymm0,-0x17d0(%rbp)
 126adad:	ff 
 126adae:	48 8d bd 30 e8 ff ff 	lea    -0x17d0(%rbp),%rdi
 126adb5:	e9 34 7a 00 00       	jmp    12727ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x865e>
 126adba:	84 c9                	test   %cl,%cl
 126adbc:	0f 84 71 01 00 00    	je     126af33 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xda3>
 126adc2:	48 8d 85 20 ff ff ff 	lea    -0xe0(%rbp),%rax
 126adc9:	48 89 44 24 28       	mov    %rax,0x28(%rsp)
 126adce:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126add2:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126add7:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126addb:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126ade0:	48 8d 85 50 fc ff ff 	lea    -0x3b0(%rbp),%rax
 126ade7:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126adec:	48 8b 45 10          	mov    0x10(%rbp),%rax
 126adf0:	48 89 04 24          	mov    %rax,(%rsp)
 126adf4:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126adfb:	00 00 
 126adfd:	48 c7 44 24 48 68 ae 	movq   $0x103ae68,0x48(%rsp)
 126ae04:	03 01 
 126ae06:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126ae0d:	00 00 
 126ae0f:	48 c7 44 24 38 f8 ad 	movq   $0x103adf8,0x38(%rsp)
 126ae16:	03 01 
 126ae18:	48 c7 44 24 30 00 00 	movq   $0x0,0x30(%rsp)
 126ae1f:	00 00 
 126ae21:	48 c7 44 24 20 88 ad 	movq   $0x103ad88,0x20(%rsp)
 126ae28:	03 01 
 126ae2a:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126ae31:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 126ae38:	4c 89 f2             	mov    %r14,%rdx
 126ae3b:	4c 89 e9             	mov    %r13,%rcx
 126ae3e:	4d 89 e0             	mov    %r12,%r8
 126ae41:	4d 89 f9             	mov    %r15,%r9
 126ae44:	c5 f8 77             	vzeroupper 
 126ae47:	e8 34 7d 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126ae4c:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126ae50:	48 85 db             	test   %rbx,%rbx
 126ae53:	0f 84 dc 02 00 00    	je     126b135 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xfa5>
 126ae59:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126ae60:	ff 
 126ae61:	48 8b 45 18          	mov    0x18(%rbp),%rax
 126ae65:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 126ae6a:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126ae71:	ff 
 126ae72:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126ae79:	ff 
 126ae7a:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126ae81:	ff 
 126ae82:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126ae89:	ff 
 126ae8a:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 126ae8f:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 126ae94:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 126ae99:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 126ae9d:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 126aea4:	4c 89 f6             	mov    %r14,%rsi
 126aea7:	c5 f8 77             	vzeroupper 
 126aeaa:	e8 d1 a3 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 126aeaf:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 126aeb6:	74 42                	je     126aefa <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xd6a>
 126aeb8:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 126aebf:	ff 
 126aec0:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 126aec7:	ff 
 126aec8:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 126aecf:	ff 
 126aed0:	c5 fc 11 95 68 d2 ff 	vmovups %ymm2,-0x2d98(%rbp)
 126aed7:	ff 
 126aed8:	c5 fc 11 8d 50 d2 ff 	vmovups %ymm1,-0x2db0(%rbp)
 126aedf:	ff 
 126aee0:	c5 fc 11 85 30 d2 ff 	vmovups %ymm0,-0x2dd0(%rbp)
 126aee7:	ff 
 126aee8:	48 8d bd 30 d2 ff ff 	lea    -0x2dd0(%rbp),%rdi
 126aeef:	4c 89 f6             	mov    %r14,%rsi
 126aef2:	c5 f8 77             	vzeroupper 
 126aef5:	e8 b6 a4 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 126aefa:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 126af01:	0f 84 f2 78 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 126af07:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 126af0e:	ff 
 126af0f:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 126af16:	ff 
 126af17:	c5 fc 11 8d 10 e8 ff 	vmovups %ymm1,-0x17f0(%rbp)
 126af1e:	ff 
 126af1f:	c5 fc 11 85 00 e8 ff 	vmovups %ymm0,-0x1800(%rbp)
 126af26:	ff 
 126af27:	48 8d bd 00 e8 ff ff 	lea    -0x1800(%rbp),%rdi
 126af2e:	e9 bb 78 00 00       	jmp    12727ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x865e>
 126af33:	84 c0                	test   %al,%al
 126af35:	0f 84 6b 01 00 00    	je     126b0a6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xf16>
 126af3b:	48 8d 85 c0 df ff ff 	lea    -0x2040(%rbp),%rax
 126af42:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 126af47:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126af4b:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126af51:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126af55:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126af5a:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126af5e:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126af63:	48 8d 85 50 fc ff ff 	lea    -0x3b0(%rbp),%rax
 126af6a:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126af6f:	48 8b 45 10          	mov    0x10(%rbp),%rax
 126af73:	48 89 04 24          	mov    %rax,(%rsp)
 126af77:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126af7e:	00 00 
 126af80:	48 c7 44 24 48 68 ae 	movq   $0x103ae68,0x48(%rsp)
 126af87:	03 01 
 126af89:	48 c7 44 24 38 f8 ad 	movq   $0x103adf8,0x38(%rsp)
 126af90:	03 01 
 126af92:	48 c7 44 24 20 88 ad 	movq   $0x103ad88,0x20(%rsp)
 126af99:	03 01 
 126af9b:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126afa2:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 126afa9:	4c 89 f2             	mov    %r14,%rdx
 126afac:	4c 89 e9             	mov    %r13,%rcx
 126afaf:	4d 89 e0             	mov    %r12,%r8
 126afb2:	4d 89 f9             	mov    %r15,%r9
 126afb5:	c5 f8 77             	vzeroupper 
 126afb8:	e8 c3 7b 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126afbd:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126afc1:	48 85 db             	test   %rbx,%rbx
 126afc4:	0f 84 6b 01 00 00    	je     126b135 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xfa5>
 126afca:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126afd1:	ff 
 126afd2:	48 8b 45 18          	mov    0x18(%rbp),%rax
 126afd6:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 126afdb:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126afe2:	ff 
 126afe3:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126afea:	ff 
 126afeb:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126aff2:	ff 
 126aff3:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126affa:	ff 
 126affb:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 126b000:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 126b005:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 126b00a:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 126b00e:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 126b015:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 126b019:	c5 f8 77             	vzeroupper 
 126b01c:	e8 5f a2 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 126b021:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 126b028:	74 43                	je     126b06d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0xedd>
 126b02a:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 126b031:	ff 
 126b032:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 126b039:	ff 
 126b03a:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 126b041:	ff 
 126b042:	c5 fc 11 95 08 d2 ff 	vmovups %ymm2,-0x2df8(%rbp)
 126b049:	ff 
 126b04a:	c5 fc 11 8d f0 d1 ff 	vmovups %ymm1,-0x2e10(%rbp)
 126b051:	ff 
 126b052:	c5 fc 11 85 d0 d1 ff 	vmovups %ymm0,-0x2e30(%rbp)
 126b059:	ff 
 126b05a:	48 8d bd d0 d1 ff ff 	lea    -0x2e30(%rbp),%rdi
 126b061:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 126b065:	c5 f8 77             	vzeroupper 
 126b068:	e8 43 a3 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 126b06d:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 126b074:	0f 84 7f 77 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 126b07a:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 126b081:	ff 
 126b082:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 126b089:	ff 
 126b08a:	c5 fc 11 8d e0 e7 ff 	vmovups %ymm1,-0x1820(%rbp)
 126b091:	ff 
 126b092:	c5 fc 11 85 d0 e7 ff 	vmovups %ymm0,-0x1830(%rbp)
 126b099:	ff 
 126b09a:	48 8d bd d0 e7 ff ff 	lea    -0x1830(%rbp),%rdi
 126b0a1:	e9 ca 7a 00 00       	jmp    1272b70 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x89e0>
 126b0a6:	48 8d 85 08 e3 ff ff 	lea    -0x1cf8(%rbp),%rax
 126b0ad:	48 89 44 24 50       	mov    %rax,0x50(%rsp)
 126b0b2:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126b0b6:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126b0bc:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126b0c0:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126b0c5:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126b0c9:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126b0ce:	48 8d 85 50 fc ff ff 	lea    -0x3b0(%rbp),%rax
 126b0d5:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126b0da:	48 8b 45 10          	mov    0x10(%rbp),%rax
 126b0de:	48 89 04 24          	mov    %rax,(%rsp)
 126b0e2:	48 c7 44 24 48 68 ae 	movq   $0x103ae68,0x48(%rsp)
 126b0e9:	03 01 
 126b0eb:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126b0f2:	00 00 
 126b0f4:	48 c7 44 24 38 f8 ad 	movq   $0x103adf8,0x38(%rsp)
 126b0fb:	03 01 
 126b0fd:	48 c7 44 24 20 88 ad 	movq   $0x103ad88,0x20(%rsp)
 126b104:	03 01 
 126b106:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126b10d:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 126b114:	4c 89 f2             	mov    %r14,%rdx
 126b117:	4c 89 e9             	mov    %r13,%rcx
 126b11a:	4d 89 e0             	mov    %r12,%r8
 126b11d:	4d 89 f9             	mov    %r15,%r9
 126b120:	c5 f8 77             	vzeroupper 
 126b123:	e8 58 7a 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126b128:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126b12c:	48 85 db             	test   %rbx,%rbx
 126b12f:	0f 85 64 79 00 00    	jne    1272a99 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8909>
 126b135:	48 8b 85 78 ff ff ff 	mov    -0x88(%rbp),%rax
 126b13c:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 126b140:	4c 8b 75 80          	mov    -0x80(%rbp),%r14
 126b144:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126b148:	0f b6 4d a6          	movzbl -0x5a(%rbp),%ecx
 126b14c:	80 bd 1a ff ff ff 00 	cmpb   $0x0,-0xe6(%rbp)
 126b153:	0f 94 c0             	sete   %al
 126b156:	c5 fc 10 85 c0 fc ff 	vmovups -0x340(%rbp),%ymm0
 126b15d:	ff 
 126b15e:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126b165:	ff 
 126b166:	c5 fc 10 85 70 fc ff 	vmovups -0x390(%rbp),%ymm0
 126b16d:	ff 
 126b16e:	c5 fc 10 8d 90 fc ff 	vmovups -0x370(%rbp),%ymm1
 126b175:	ff 
 126b176:	c5 fc 10 95 b0 fc ff 	vmovups -0x350(%rbp),%ymm2
 126b17d:	ff 
 126b17e:	c5 fc 11 95 80 fd ff 	vmovups %ymm2,-0x280(%rbp)
 126b185:	ff 
 126b186:	c5 fc 11 8d 60 fd ff 	vmovups %ymm1,-0x2a0(%rbp)
 126b18d:	ff 
 126b18e:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 126b195:	ff 
 126b196:	c5 fc 10 85 50 fc ff 	vmovups -0x3b0(%rbp),%ymm0
 126b19d:	ff 
 126b19e:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126b1a5:	ff 
 126b1a6:	84 c9                	test   %cl,%cl
 126b1a8:	0f 94 c1             	sete   %cl
 126b1ab:	08 c1                	or     %al,%cl
 126b1ad:	74 29                	je     126b1d8 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1048>
 126b1af:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 126b1b3:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 126b1b7:	4c 89 f3             	mov    %r14,%rbx
 126b1ba:	4c 8b 65 a8          	mov    -0x58(%rbp),%r12
 126b1be:	4c 8b 6d 90          	mov    -0x70(%rbp),%r13
 126b1c2:	80 bd 1b ff ff ff 00 	cmpb   $0x0,-0xe5(%rbp)
 126b1c9:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126b1cd:	0f 85 e4 02 00 00    	jne    126b4b7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1327>
 126b1d3:	e9 92 05 00 00       	jmp    126b76a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15da>
 126b1d8:	48 8b 85 d0 f9 ff ff 	mov    -0x630(%rbp),%rax
 126b1df:	48 89 85 10 db ff ff 	mov    %rax,-0x24f0(%rbp)
 126b1e6:	c5 fc 10 85 70 f9 ff 	vmovups -0x690(%rbp),%ymm0
 126b1ed:	ff 
 126b1ee:	c5 fc 10 8d 90 f9 ff 	vmovups -0x670(%rbp),%ymm1
 126b1f5:	ff 
 126b1f6:	c5 fc 10 95 b0 f9 ff 	vmovups -0x650(%rbp),%ymm2
 126b1fd:	ff 
 126b1fe:	c5 fc 11 95 f0 da ff 	vmovups %ymm2,-0x2510(%rbp)
 126b205:	ff 
 126b206:	c5 fc 11 8d d0 da ff 	vmovups %ymm1,-0x2530(%rbp)
 126b20d:	ff 
 126b20e:	c5 fc 11 85 b0 da ff 	vmovups %ymm0,-0x2550(%rbp)
 126b215:	ff 
 126b216:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126b21d:	ff 
 126b21e:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126b225:	ff 
 126b226:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126b22d:	ff 
 126b22e:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126b235:	ff 
 126b236:	c5 fc 11 85 40 f6 ff 	vmovups %ymm0,-0x9c0(%rbp)
 126b23d:	ff 
 126b23e:	c5 fc 11 8d 60 f6 ff 	vmovups %ymm1,-0x9a0(%rbp)
 126b245:	ff 
 126b246:	c5 fc 11 95 80 f6 ff 	vmovups %ymm2,-0x980(%rbp)
 126b24d:	ff 
 126b24e:	c5 fc 11 9d a0 f6 ff 	vmovups %ymm3,-0x960(%rbp)
 126b255:	ff 
 126b256:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126b25d:	ff 
 126b25e:	c5 fc 11 85 b0 f6 ff 	vmovups %ymm0,-0x950(%rbp)
 126b265:	ff 
 126b266:	c6 85 18 db ff ff 01 	movb   $0x1,-0x24e8(%rbp)
 126b26d:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126b271:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126b276:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126b27d:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126b282:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126b286:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126b28c:	48 8d 85 b0 da ff ff 	lea    -0x2550(%rbp),%rax
 126b293:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126b298:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126b29c:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126b2a1:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126b2a5:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126b2aa:	48 8d 85 40 f6 ff ff 	lea    -0x9c0(%rbp),%rax
 126b2b1:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126b2b6:	4c 89 3c 24          	mov    %r15,(%rsp)
 126b2ba:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126b2c1:	00 00 
 126b2c3:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126b2ca:	00 00 
 126b2cc:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126b2d3:	4c 8b a5 58 ff ff ff 	mov    -0xa8(%rbp),%r12
 126b2da:	4c 89 e6             	mov    %r12,%rsi
 126b2dd:	4c 8b 6d b8          	mov    -0x48(%rbp),%r13
 126b2e1:	4c 89 ea             	mov    %r13,%rdx
 126b2e4:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126b2eb:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126b2ef:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126b2f3:	c5 f8 77             	vzeroupper 
 126b2f6:	e8 85 78 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126b2fb:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126b2ff:	48 85 db             	test   %rbx,%rbx
 126b302:	0f 85 b1 6f 00 00    	jne    12722b9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8129>
 126b308:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126b30f:	48 8b 5d 80          	mov    -0x80(%rbp),%rbx
 126b313:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126b31a:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 126b31e:	48 89 da             	mov    %rbx,%rdx
 126b321:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 126b325:	4d 89 f0             	mov    %r14,%r8
 126b328:	e8 b3 2c fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126b32d:	49 8b 4c 24 10       	mov    0x10(%r12),%rcx
 126b332:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 126b336:	4d 8b 4d 08          	mov    0x8(%r13),%r9
 126b33a:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126b33e:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126b345:	a8 01                	test   $0x1,%al
 126b347:	0f 84 da 00 00 00    	je     126b427 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1297>
 126b34d:	48 85 f6             	test   %rsi,%rsi
 126b350:	4c 8b 65 a8          	mov    -0x58(%rbp),%r12
 126b354:	4c 8b 6d 90          	mov    -0x70(%rbp),%r13
 126b358:	74 51                	je     126b3ab <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x121b>
 126b35a:	48 83 fe 01          	cmp    $0x1,%rsi
 126b35e:	0f 85 20 57 00 00    	jne    1270a84 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x68f4>
 126b364:	31 c0                	xor    %eax,%eax
 126b366:	40 f6 c6 01          	test   $0x1,%sil
 126b36a:	74 3f                	je     126b3ab <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x121b>
 126b36c:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126b373:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126b37a:	00 00 
 126b37c:	41 80 e0 0f          	and    $0xf,%r8b
 126b380:	41 80 f8 07          	cmp    $0x7,%r8b
 126b384:	75 25                	jne    126b3ab <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x121b>
 126b386:	48 01 f2             	add    %rsi,%rdx
 126b389:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126b38d:	74 1c                	je     126b3ab <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x121b>
 126b38f:	4c 39 72 38          	cmp    %r14,0x38(%rdx)
 126b393:	75 16                	jne    126b3ab <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x121b>
 126b395:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 126b399:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126b3a0:	00 
 126b3a1:	75 08                	jne    126b3ab <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x121b>
 126b3a3:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126b3aa:	00 
 126b3ab:	4d 85 f6             	test   %r14,%r14
 126b3ae:	74 11                	je     126b3c1 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1231>
 126b3b0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126b3b4:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 126b3b8:	4c 89 f2             	mov    %r14,%rdx
 126b3bb:	31 c9                	xor    %ecx,%ecx
 126b3bd:	41 ff 51 18          	call   *0x18(%r9)
 126b3c1:	c5 fc 10 85 b0 f6 ff 	vmovups -0x950(%rbp),%ymm0
 126b3c8:	ff 
 126b3c9:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126b3d0:	ff 
 126b3d1:	c5 fc 10 85 40 f6 ff 	vmovups -0x9c0(%rbp),%ymm0
 126b3d8:	ff 
 126b3d9:	c5 fc 10 8d 60 f6 ff 	vmovups -0x9a0(%rbp),%ymm1
 126b3e0:	ff 
 126b3e1:	c5 fc 10 95 80 f6 ff 	vmovups -0x980(%rbp),%ymm2
 126b3e8:	ff 
 126b3e9:	c5 fc 10 9d a0 f6 ff 	vmovups -0x960(%rbp),%ymm3
 126b3f0:	ff 
 126b3f1:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126b3f8:	ff 
 126b3f9:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126b400:	ff 
 126b401:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126b408:	ff 
 126b409:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126b410:	ff 
 126b411:	80 bd 1b ff ff ff 00 	cmpb   $0x0,-0xe5(%rbp)
 126b418:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126b41c:	0f 85 95 00 00 00    	jne    126b4b7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1327>
 126b422:	e9 43 03 00 00       	jmp    126b76a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15da>
 126b427:	48 85 f6             	test   %rsi,%rsi
 126b42a:	4c 8b 65 a8          	mov    -0x58(%rbp),%r12
 126b42e:	4c 8b 6d 90          	mov    -0x70(%rbp),%r13
 126b432:	74 51                	je     126b485 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x12f5>
 126b434:	48 83 fe 01          	cmp    $0x1,%rsi
 126b438:	0f 85 f6 56 00 00    	jne    1270b34 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x69a4>
 126b43e:	31 c0                	xor    %eax,%eax
 126b440:	40 f6 c6 01          	test   $0x1,%sil
 126b444:	74 3f                	je     126b485 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x12f5>
 126b446:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126b44d:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126b454:	00 00 
 126b456:	41 80 e0 0f          	and    $0xf,%r8b
 126b45a:	41 80 f8 07          	cmp    $0x7,%r8b
 126b45e:	75 25                	jne    126b485 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x12f5>
 126b460:	48 01 f2             	add    %rsi,%rdx
 126b463:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126b467:	74 1c                	je     126b485 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x12f5>
 126b469:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126b46d:	75 16                	jne    126b485 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x12f5>
 126b46f:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126b473:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126b47a:	00 
 126b47b:	75 08                	jne    126b485 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x12f5>
 126b47d:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126b484:	00 
 126b485:	48 85 db             	test   %rbx,%rbx
 126b488:	74 11                	je     126b49b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x130b>
 126b48a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126b48e:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126b492:	48 89 da             	mov    %rbx,%rdx
 126b495:	31 c9                	xor    %ecx,%ecx
 126b497:	41 ff 51 18          	call   *0x18(%r9)
 126b49b:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 126b49f:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 126b4a3:	4c 89 f3             	mov    %r14,%rbx
 126b4a6:	80 bd 1b ff ff ff 00 	cmpb   $0x0,-0xe5(%rbp)
 126b4ad:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126b4b1:	0f 84 b3 02 00 00    	je     126b76a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15da>
 126b4b7:	48 8b 85 40 fa ff ff 	mov    -0x5c0(%rbp),%rax
 126b4be:	48 89 85 a0 da ff ff 	mov    %rax,-0x2560(%rbp)
 126b4c5:	c5 fc 10 85 e0 f9 ff 	vmovups -0x620(%rbp),%ymm0
 126b4cc:	ff 
 126b4cd:	c5 fc 10 8d 00 fa ff 	vmovups -0x600(%rbp),%ymm1
 126b4d4:	ff 
 126b4d5:	c5 fc 10 95 20 fa ff 	vmovups -0x5e0(%rbp),%ymm2
 126b4dc:	ff 
 126b4dd:	c5 fc 11 95 80 da ff 	vmovups %ymm2,-0x2580(%rbp)
 126b4e4:	ff 
 126b4e5:	c5 fc 11 8d 60 da ff 	vmovups %ymm1,-0x25a0(%rbp)
 126b4ec:	ff 
 126b4ed:	c5 fc 11 85 40 da ff 	vmovups %ymm0,-0x25c0(%rbp)
 126b4f4:	ff 
 126b4f5:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126b4fc:	ff 
 126b4fd:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126b504:	ff 
 126b505:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126b50c:	ff 
 126b50d:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126b514:	ff 
 126b515:	c5 fc 11 85 b0 f5 ff 	vmovups %ymm0,-0xa50(%rbp)
 126b51c:	ff 
 126b51d:	c5 fc 11 8d d0 f5 ff 	vmovups %ymm1,-0xa30(%rbp)
 126b524:	ff 
 126b525:	c5 fc 11 95 f0 f5 ff 	vmovups %ymm2,-0xa10(%rbp)
 126b52c:	ff 
 126b52d:	c5 fc 11 9d 10 f6 ff 	vmovups %ymm3,-0x9f0(%rbp)
 126b534:	ff 
 126b535:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126b53c:	ff 
 126b53d:	c5 fc 11 85 20 f6 ff 	vmovups %ymm0,-0x9e0(%rbp)
 126b544:	ff 
 126b545:	c6 85 a8 da ff ff 01 	movb   $0x1,-0x2558(%rbp)
 126b54c:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126b550:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126b555:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126b55c:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126b561:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126b565:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126b56b:	48 8d 85 40 da ff ff 	lea    -0x25c0(%rbp),%rax
 126b572:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126b577:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126b57b:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126b580:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126b584:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126b589:	48 8d 85 b0 f5 ff ff 	lea    -0xa50(%rbp),%rax
 126b590:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126b595:	4c 89 3c 24          	mov    %r15,(%rsp)
 126b599:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126b5a0:	00 00 
 126b5a2:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126b5a9:	00 00 
 126b5ab:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126b5b2:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 126b5b9:	4c 89 fe             	mov    %r15,%rsi
 126b5bc:	4c 89 f2             	mov    %r14,%rdx
 126b5bf:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126b5c6:	4d 89 e8             	mov    %r13,%r8
 126b5c9:	4d 89 e1             	mov    %r12,%r9
 126b5cc:	c5 f8 77             	vzeroupper 
 126b5cf:	e8 ac 75 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126b5d4:	44 0f b7 65 88       	movzwl -0x78(%rbp),%r12d
 126b5d9:	4d 85 e4             	test   %r12,%r12
 126b5dc:	0f 85 c1 5d 00 00    	jne    12713a3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7213>
 126b5e2:	4c 8b ad 78 ff ff ff 	mov    -0x88(%rbp),%r13
 126b5e9:	4c 8b 65 80          	mov    -0x80(%rbp),%r12
 126b5ed:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126b5f4:	4c 89 ee             	mov    %r13,%rsi
 126b5f7:	4c 89 e2             	mov    %r12,%rdx
 126b5fa:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 126b5fe:	49 89 d8             	mov    %rbx,%r8
 126b601:	e8 da 29 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126b606:	49 8b 4f 10          	mov    0x10(%r15),%rcx
 126b60a:	49 8b 3e             	mov    (%r14),%rdi
 126b60d:	4d 8b 4e 08          	mov    0x8(%r14),%r9
 126b611:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126b615:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126b61c:	a8 01                	test   $0x1,%al
 126b61e:	0f 84 db 00 00 00    	je     126b6ff <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x156f>
 126b624:	48 85 f6             	test   %rsi,%rsi
 126b627:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126b62b:	74 51                	je     126b67e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x14ee>
 126b62d:	48 83 fe 01          	cmp    $0x1,%rsi
 126b631:	0f 85 7e 3f 00 00    	jne    126f5b5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5425>
 126b637:	31 c0                	xor    %eax,%eax
 126b639:	40 f6 c6 01          	test   $0x1,%sil
 126b63d:	74 3f                	je     126b67e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x14ee>
 126b63f:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126b646:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126b64d:	00 00 
 126b64f:	41 80 e0 0f          	and    $0xf,%r8b
 126b653:	41 80 f8 07          	cmp    $0x7,%r8b
 126b657:	75 25                	jne    126b67e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x14ee>
 126b659:	48 01 f2             	add    %rsi,%rdx
 126b65c:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126b660:	74 1c                	je     126b67e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x14ee>
 126b662:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126b666:	75 16                	jne    126b67e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x14ee>
 126b668:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126b66c:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126b673:	00 
 126b674:	75 08                	jne    126b67e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x14ee>
 126b676:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126b67d:	00 
 126b67e:	48 85 db             	test   %rbx,%rbx
 126b681:	74 11                	je     126b694 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1504>
 126b683:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126b687:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126b68b:	48 89 da             	mov    %rbx,%rdx
 126b68e:	31 c9                	xor    %ecx,%ecx
 126b690:	41 ff 51 18          	call   *0x18(%r9)
 126b694:	c5 fc 10 85 20 f6 ff 	vmovups -0x9e0(%rbp),%ymm0
 126b69b:	ff 
 126b69c:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126b6a3:	ff 
 126b6a4:	c5 fc 10 85 b0 f5 ff 	vmovups -0xa50(%rbp),%ymm0
 126b6ab:	ff 
 126b6ac:	c5 fc 10 8d d0 f5 ff 	vmovups -0xa30(%rbp),%ymm1
 126b6b3:	ff 
 126b6b4:	c5 fc 10 95 f0 f5 ff 	vmovups -0xa10(%rbp),%ymm2
 126b6bb:	ff 
 126b6bc:	c5 fc 10 9d 10 f6 ff 	vmovups -0x9f0(%rbp),%ymm3
 126b6c3:	ff 
 126b6c4:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126b6cb:	ff 
 126b6cc:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126b6d3:	ff 
 126b6d4:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126b6db:	ff 
 126b6dc:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126b6e3:	ff 
 126b6e4:	0f b6 45 a7          	movzbl -0x59(%rbp),%eax
 126b6e8:	84 c0                	test   %al,%al
 126b6ea:	0f 85 8d 00 00 00    	jne    126b77d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15ed>
 126b6f0:	4d 89 ef             	mov    %r13,%r15
 126b6f3:	4c 89 e3             	mov    %r12,%rbx
 126b6f6:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126b6fa:	e9 35 03 00 00       	jmp    126ba34 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x18a4>
 126b6ff:	48 85 f6             	test   %rsi,%rsi
 126b702:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126b706:	74 4d                	je     126b755 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15c5>
 126b708:	48 83 fe 01          	cmp    $0x1,%rsi
 126b70c:	0f 85 52 3f 00 00    	jne    126f664 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x54d4>
 126b712:	31 c0                	xor    %eax,%eax
 126b714:	40 f6 c6 01          	test   $0x1,%sil
 126b718:	74 3b                	je     126b755 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15c5>
 126b71a:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126b721:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126b728:	00 00 
 126b72a:	41 80 e0 0f          	and    $0xf,%r8b
 126b72e:	41 80 f8 07          	cmp    $0x7,%r8b
 126b732:	75 21                	jne    126b755 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15c5>
 126b734:	48 01 f2             	add    %rsi,%rdx
 126b737:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126b73b:	74 18                	je     126b755 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15c5>
 126b73d:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 126b741:	75 12                	jne    126b755 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15c5>
 126b743:	4c 39 ac c1 d0 32 02 	cmp    %r13,0x232d0(%rcx,%rax,8)
 126b74a:	00 
 126b74b:	75 08                	jne    126b755 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15c5>
 126b74d:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126b754:	00 
 126b755:	4d 85 e4             	test   %r12,%r12
 126b758:	74 10                	je     126b76a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x15da>
 126b75a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126b75e:	4c 89 ee             	mov    %r13,%rsi
 126b761:	4c 89 e2             	mov    %r12,%rdx
 126b764:	31 c9                	xor    %ecx,%ecx
 126b766:	41 ff 51 18          	call   *0x18(%r9)
 126b76a:	4c 8b 6d d0          	mov    -0x30(%rbp),%r13
 126b76e:	49 89 dc             	mov    %rbx,%r12
 126b771:	0f b6 45 a7          	movzbl -0x59(%rbp),%eax
 126b775:	84 c0                	test   %al,%al
 126b777:	0f 84 73 ff ff ff    	je     126b6f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1560>
 126b77d:	48 8b 85 b0 fa ff ff 	mov    -0x550(%rbp),%rax
 126b784:	48 89 85 30 da ff ff 	mov    %rax,-0x25d0(%rbp)
 126b78b:	c5 fc 10 85 50 fa ff 	vmovups -0x5b0(%rbp),%ymm0
 126b792:	ff 
 126b793:	c5 fc 10 8d 70 fa ff 	vmovups -0x590(%rbp),%ymm1
 126b79a:	ff 
 126b79b:	c5 fc 10 95 90 fa ff 	vmovups -0x570(%rbp),%ymm2
 126b7a2:	ff 
 126b7a3:	c5 fc 11 95 10 da ff 	vmovups %ymm2,-0x25f0(%rbp)
 126b7aa:	ff 
 126b7ab:	c5 fc 11 8d f0 d9 ff 	vmovups %ymm1,-0x2610(%rbp)
 126b7b2:	ff 
 126b7b3:	c5 fc 11 85 d0 d9 ff 	vmovups %ymm0,-0x2630(%rbp)
 126b7ba:	ff 
 126b7bb:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126b7c2:	ff 
 126b7c3:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126b7ca:	ff 
 126b7cb:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126b7d2:	ff 
 126b7d3:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126b7da:	ff 
 126b7db:	c5 fc 11 85 20 f5 ff 	vmovups %ymm0,-0xae0(%rbp)
 126b7e2:	ff 
 126b7e3:	c5 fc 11 8d 40 f5 ff 	vmovups %ymm1,-0xac0(%rbp)
 126b7ea:	ff 
 126b7eb:	c5 fc 11 95 60 f5 ff 	vmovups %ymm2,-0xaa0(%rbp)
 126b7f2:	ff 
 126b7f3:	c5 fc 11 9d 80 f5 ff 	vmovups %ymm3,-0xa80(%rbp)
 126b7fa:	ff 
 126b7fb:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126b802:	ff 
 126b803:	c5 fc 11 85 90 f5 ff 	vmovups %ymm0,-0xa70(%rbp)
 126b80a:	ff 
 126b80b:	c6 85 38 da ff ff 01 	movb   $0x1,-0x25c8(%rbp)
 126b812:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126b816:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126b81b:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126b822:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126b827:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126b82b:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126b831:	48 8d 85 d0 d9 ff ff 	lea    -0x2630(%rbp),%rax
 126b838:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126b83d:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126b841:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126b846:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126b84a:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126b84f:	48 8d 85 20 f5 ff ff 	lea    -0xae0(%rbp),%rax
 126b856:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126b85b:	4c 89 3c 24          	mov    %r15,(%rsp)
 126b85f:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126b866:	00 00 
 126b868:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126b86f:	00 00 
 126b871:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126b878:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 126b87f:	4c 89 fe             	mov    %r15,%rsi
 126b882:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126b886:	4c 89 f2             	mov    %r14,%rdx
 126b889:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126b890:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126b894:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126b898:	c5 f8 77             	vzeroupper 
 126b89b:	e8 e0 72 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126b8a0:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126b8a4:	48 85 db             	test   %rbx,%rbx
 126b8a7:	0f 85 e3 5b 00 00    	jne    1271490 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7300>
 126b8ad:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126b8b4:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 126b8b8:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126b8bf:	4c 89 e9             	mov    %r13,%rcx
 126b8c2:	49 89 f5             	mov    %rsi,%r13
 126b8c5:	4d 89 e0             	mov    %r12,%r8
 126b8c8:	48 89 55 d0          	mov    %rdx,-0x30(%rbp)
 126b8cc:	48 89 cb             	mov    %rcx,%rbx
 126b8cf:	e8 0c 27 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126b8d4:	49 8b 4f 10          	mov    0x10(%r15),%rcx
 126b8d8:	49 8b 3e             	mov    (%r14),%rdi
 126b8db:	4d 8b 56 08          	mov    0x8(%r14),%r10
 126b8df:	4c 8d 41 20          	lea    0x20(%rcx),%r8
 126b8e3:	4c 8b 89 20 30 02 00 	mov    0x23020(%rcx),%r9
 126b8ea:	a8 01                	test   $0x1,%al
 126b8ec:	0f 84 ca 00 00 00    	je     126b9bc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x182c>
 126b8f2:	4d 85 c9             	test   %r9,%r9
 126b8f5:	4d 89 ef             	mov    %r13,%r15
 126b8f8:	48 89 de             	mov    %rbx,%rsi
 126b8fb:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 126b8ff:	4c 89 e2             	mov    %r12,%rdx
 126b902:	74 57                	je     126b95b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x17cb>
 126b904:	4d 89 c5             	mov    %r8,%r13
 126b907:	4d 89 d4             	mov    %r10,%r12
 126b90a:	49 83 f9 01          	cmp    $0x1,%r9
 126b90e:	0f 85 f8 3d 00 00    	jne    126f70c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x557c>
 126b914:	31 c0                	xor    %eax,%eax
 126b916:	41 f6 c1 01          	test   $0x1,%r9b
 126b91a:	4d 89 e2             	mov    %r12,%r10
 126b91d:	74 3c                	je     126b95b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x17cb>
 126b91f:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126b926:	47 0f b6 84 0d 10 01 	movzbl 0x110(%r13,%r9,1),%r8d
 126b92d:	00 00 
 126b92f:	41 80 e0 0f          	and    $0xf,%r8b
 126b933:	41 80 f8 07          	cmp    $0x7,%r8b
 126b937:	75 22                	jne    126b95b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x17cb>
 126b939:	4d 01 cd             	add    %r9,%r13
 126b93c:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 126b941:	74 18                	je     126b95b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x17cb>
 126b943:	49 39 55 38          	cmp    %rdx,0x38(%r13)
 126b947:	75 12                	jne    126b95b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x17cb>
 126b949:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126b950:	00 
 126b951:	75 08                	jne    126b95b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x17cb>
 126b953:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126b95a:	00 
 126b95b:	48 85 d2             	test   %rdx,%rdx
 126b95e:	74 0a                	je     126b96a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x17da>
 126b960:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126b964:	31 c9                	xor    %ecx,%ecx
 126b966:	41 ff 52 18          	call   *0x18(%r10)
 126b96a:	c5 fc 10 85 90 f5 ff 	vmovups -0xa70(%rbp),%ymm0
 126b971:	ff 
 126b972:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126b979:	ff 
 126b97a:	c5 fc 10 85 20 f5 ff 	vmovups -0xae0(%rbp),%ymm0
 126b981:	ff 
 126b982:	c5 fc 10 8d 40 f5 ff 	vmovups -0xac0(%rbp),%ymm1
 126b989:	ff 
 126b98a:	c5 fc 10 95 60 f5 ff 	vmovups -0xaa0(%rbp),%ymm2
 126b991:	ff 
 126b992:	c5 fc 10 9d 80 f5 ff 	vmovups -0xa80(%rbp),%ymm3
 126b999:	ff 
 126b99a:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126b9a1:	ff 
 126b9a2:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126b9a9:	ff 
 126b9aa:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126b9b1:	ff 
 126b9b2:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126b9b9:	ff 
 126b9ba:	eb 78                	jmp    126ba34 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x18a4>
 126b9bc:	4d 85 c9             	test   %r9,%r9
 126b9bf:	4c 89 ee             	mov    %r13,%rsi
 126b9c2:	49 89 df             	mov    %rbx,%r15
 126b9c5:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126b9c9:	4c 89 e3             	mov    %r12,%rbx
 126b9cc:	74 57                	je     126ba25 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1895>
 126b9ce:	4d 89 c5             	mov    %r8,%r13
 126b9d1:	4d 89 d4             	mov    %r10,%r12
 126b9d4:	49 83 f9 01          	cmp    $0x1,%r9
 126b9d8:	0f 85 ce 3d 00 00    	jne    126f7ac <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x561c>
 126b9de:	31 c0                	xor    %eax,%eax
 126b9e0:	41 f6 c1 01          	test   $0x1,%r9b
 126b9e4:	4d 89 e2             	mov    %r12,%r10
 126b9e7:	74 3c                	je     126ba25 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1895>
 126b9e9:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126b9f0:	47 0f b6 84 0d 10 01 	movzbl 0x110(%r13,%r9,1),%r8d
 126b9f7:	00 00 
 126b9f9:	41 80 e0 0f          	and    $0xf,%r8b
 126b9fd:	41 80 f8 07          	cmp    $0x7,%r8b
 126ba01:	75 22                	jne    126ba25 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1895>
 126ba03:	4d 01 cd             	add    %r9,%r13
 126ba06:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 126ba0b:	74 18                	je     126ba25 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1895>
 126ba0d:	49 39 55 38          	cmp    %rdx,0x38(%r13)
 126ba11:	75 12                	jne    126ba25 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1895>
 126ba13:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126ba1a:	00 
 126ba1b:	75 08                	jne    126ba25 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1895>
 126ba1d:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126ba24:	00 
 126ba25:	48 85 d2             	test   %rdx,%rdx
 126ba28:	74 0a                	je     126ba34 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x18a4>
 126ba2a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126ba2e:	31 c9                	xor    %ecx,%ecx
 126ba30:	41 ff 52 18          	call   *0x18(%r10)
 126ba34:	80 bd 1c ff ff ff 00 	cmpb   $0x0,-0xe4(%rbp)
 126ba3b:	0f 84 98 04 00 00    	je     126bed9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1d49>
 126ba41:	48 8b 85 20 fb ff ff 	mov    -0x4e0(%rbp),%rax
 126ba48:	48 89 85 c0 d9 ff ff 	mov    %rax,-0x2640(%rbp)
 126ba4f:	c5 fc 10 85 c0 fa ff 	vmovups -0x540(%rbp),%ymm0
 126ba56:	ff 
 126ba57:	c5 fc 10 8d e0 fa ff 	vmovups -0x520(%rbp),%ymm1
 126ba5e:	ff 
 126ba5f:	c5 fc 10 95 00 fb ff 	vmovups -0x500(%rbp),%ymm2
 126ba66:	ff 
 126ba67:	c5 fc 11 95 a0 d9 ff 	vmovups %ymm2,-0x2660(%rbp)
 126ba6e:	ff 
 126ba6f:	c5 fc 11 8d 80 d9 ff 	vmovups %ymm1,-0x2680(%rbp)
 126ba76:	ff 
 126ba77:	c5 fc 11 85 60 d9 ff 	vmovups %ymm0,-0x26a0(%rbp)
 126ba7e:	ff 
 126ba7f:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126ba86:	ff 
 126ba87:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126ba8e:	ff 
 126ba8f:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126ba96:	ff 
 126ba97:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126ba9e:	ff 
 126ba9f:	c5 fc 11 85 90 f4 ff 	vmovups %ymm0,-0xb70(%rbp)
 126baa6:	ff 
 126baa7:	c5 fc 11 8d b0 f4 ff 	vmovups %ymm1,-0xb50(%rbp)
 126baae:	ff 
 126baaf:	c5 fc 11 95 d0 f4 ff 	vmovups %ymm2,-0xb30(%rbp)
 126bab6:	ff 
 126bab7:	c5 fc 11 9d f0 f4 ff 	vmovups %ymm3,-0xb10(%rbp)
 126babe:	ff 
 126babf:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126bac6:	ff 
 126bac7:	c5 fc 11 85 00 f5 ff 	vmovups %ymm0,-0xb00(%rbp)
 126bace:	ff 
 126bacf:	c6 85 c8 d9 ff ff 01 	movb   $0x1,-0x2638(%rbp)
 126bad6:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126bada:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126badf:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126bae6:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126baeb:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126baef:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126baf5:	48 8d 85 60 d9 ff ff 	lea    -0x26a0(%rbp),%rax
 126bafc:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126bb01:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126bb05:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126bb0a:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126bb0e:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126bb13:	48 8d 85 90 f4 ff ff 	lea    -0xb70(%rbp),%rax
 126bb1a:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126bb1f:	48 8b 45 10          	mov    0x10(%rbp),%rax
 126bb23:	48 89 04 24          	mov    %rax,(%rsp)
 126bb27:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126bb2e:	00 00 
 126bb30:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126bb37:	00 00 
 126bb39:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126bb40:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 126bb47:	4c 89 ee             	mov    %r13,%rsi
 126bb4a:	4c 89 f2             	mov    %r14,%rdx
 126bb4d:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126bb54:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126bb58:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126bb5c:	c5 f8 77             	vzeroupper 
 126bb5f:	e8 1c 70 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126bb64:	44 0f b7 65 88       	movzwl -0x78(%rbp),%r12d
 126bb69:	4d 85 e4             	test   %r12,%r12
 126bb6c:	0f 85 09 5a 00 00    	jne    127157b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x73eb>
 126bb72:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126bb79:	4c 8b 65 80          	mov    -0x80(%rbp),%r12
 126bb7d:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126bb84:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 126bb88:	4c 89 e2             	mov    %r12,%rdx
 126bb8b:	4c 89 f9             	mov    %r15,%rcx
 126bb8e:	49 89 d8             	mov    %rbx,%r8
 126bb91:	e8 4a 24 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126bb96:	49 8b 4d 10          	mov    0x10(%r13),%rcx
 126bb9a:	49 8b 3e             	mov    (%r14),%rdi
 126bb9d:	4d 8b 4e 08          	mov    0x8(%r14),%r9
 126bba1:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126bba5:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126bbac:	a8 01                	test   $0x1,%al
 126bbae:	0f 84 9b 05 00 00    	je     126c14f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1fbf>
 126bbb4:	48 85 f6             	test   %rsi,%rsi
 126bbb7:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126bbbb:	74 4d                	je     126bc0a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1a7a>
 126bbbd:	48 83 fe 01          	cmp    $0x1,%rsi
 126bbc1:	0f 85 85 3c 00 00    	jne    126f84c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x56bc>
 126bbc7:	31 c0                	xor    %eax,%eax
 126bbc9:	40 f6 c6 01          	test   $0x1,%sil
 126bbcd:	74 3b                	je     126bc0a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1a7a>
 126bbcf:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126bbd6:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126bbdd:	00 00 
 126bbdf:	41 80 e0 0f          	and    $0xf,%r8b
 126bbe3:	41 80 f8 07          	cmp    $0x7,%r8b
 126bbe7:	75 21                	jne    126bc0a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1a7a>
 126bbe9:	48 01 f2             	add    %rsi,%rdx
 126bbec:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126bbf0:	74 18                	je     126bc0a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1a7a>
 126bbf2:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126bbf6:	75 12                	jne    126bc0a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1a7a>
 126bbf8:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 126bbff:	00 
 126bc00:	75 08                	jne    126bc0a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1a7a>
 126bc02:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126bc09:	00 
 126bc0a:	48 85 db             	test   %rbx,%rbx
 126bc0d:	74 10                	je     126bc1f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1a8f>
 126bc0f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126bc13:	4c 89 fe             	mov    %r15,%rsi
 126bc16:	48 89 da             	mov    %rbx,%rdx
 126bc19:	31 c9                	xor    %ecx,%ecx
 126bc1b:	41 ff 51 18          	call   *0x18(%r9)
 126bc1f:	c5 fc 10 85 00 f5 ff 	vmovups -0xb00(%rbp),%ymm0
 126bc26:	ff 
 126bc27:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126bc2e:	ff 
 126bc2f:	c5 fc 10 85 90 f4 ff 	vmovups -0xb70(%rbp),%ymm0
 126bc36:	ff 
 126bc37:	c5 fc 10 8d b0 f4 ff 	vmovups -0xb50(%rbp),%ymm1
 126bc3e:	ff 
 126bc3f:	c5 fc 10 95 d0 f4 ff 	vmovups -0xb30(%rbp),%ymm2
 126bc46:	ff 
 126bc47:	c5 fc 10 9d f0 f4 ff 	vmovups -0xb10(%rbp),%ymm3
 126bc4e:	ff 
 126bc4f:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126bc56:	ff 
 126bc57:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126bc5e:	ff 
 126bc5f:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126bc66:	ff 
 126bc67:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126bc6e:	ff 
 126bc6f:	80 bd 1d ff ff ff 00 	cmpb   $0x0,-0xe3(%rbp)
 126bc76:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 126bc7a:	0f 85 75 02 00 00    	jne    126bef5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1d65>
 126bc80:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 126bc84:	4c 89 e3             	mov    %r12,%rbx
 126bc87:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126bc8b:	80 bd 1e ff ff ff 00 	cmpb   $0x0,-0xe2(%rbp)
 126bc92:	0f 84 af 04 00 00    	je     126c147 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1fb7>
 126bc98:	48 8b 85 00 fc ff ff 	mov    -0x400(%rbp),%rax
 126bc9f:	48 89 85 e0 d8 ff ff 	mov    %rax,-0x2720(%rbp)
 126bca6:	c5 fc 10 85 a0 fb ff 	vmovups -0x460(%rbp),%ymm0
 126bcad:	ff 
 126bcae:	c5 fc 10 8d c0 fb ff 	vmovups -0x440(%rbp),%ymm1
 126bcb5:	ff 
 126bcb6:	c5 fc 10 95 e0 fb ff 	vmovups -0x420(%rbp),%ymm2
 126bcbd:	ff 
 126bcbe:	c5 fc 11 95 c0 d8 ff 	vmovups %ymm2,-0x2740(%rbp)
 126bcc5:	ff 
 126bcc6:	c5 fc 11 8d a0 d8 ff 	vmovups %ymm1,-0x2760(%rbp)
 126bccd:	ff 
 126bcce:	c5 fc 11 85 80 d8 ff 	vmovups %ymm0,-0x2780(%rbp)
 126bcd5:	ff 
 126bcd6:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126bcdd:	ff 
 126bcde:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126bce5:	ff 
 126bce6:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126bced:	ff 
 126bcee:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126bcf5:	ff 
 126bcf6:	c5 fc 11 85 70 f3 ff 	vmovups %ymm0,-0xc90(%rbp)
 126bcfd:	ff 
 126bcfe:	c5 fc 11 8d 90 f3 ff 	vmovups %ymm1,-0xc70(%rbp)
 126bd05:	ff 
 126bd06:	c5 fc 11 95 b0 f3 ff 	vmovups %ymm2,-0xc50(%rbp)
 126bd0d:	ff 
 126bd0e:	c5 fc 11 9d d0 f3 ff 	vmovups %ymm3,-0xc30(%rbp)
 126bd15:	ff 
 126bd16:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126bd1d:	ff 
 126bd1e:	c5 fc 11 85 e0 f3 ff 	vmovups %ymm0,-0xc20(%rbp)
 126bd25:	ff 
 126bd26:	c6 85 e8 d8 ff ff 01 	movb   $0x1,-0x2718(%rbp)
 126bd2d:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126bd31:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126bd36:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126bd3d:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126bd42:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126bd46:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126bd4c:	48 8d 85 80 d8 ff ff 	lea    -0x2780(%rbp),%rax
 126bd53:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126bd58:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126bd5c:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126bd61:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126bd65:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126bd6a:	48 8d 85 70 f3 ff ff 	lea    -0xc90(%rbp),%rax
 126bd71:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126bd76:	48 8b 45 10          	mov    0x10(%rbp),%rax
 126bd7a:	48 89 04 24          	mov    %rax,(%rsp)
 126bd7e:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126bd85:	00 00 
 126bd87:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126bd8e:	00 00 
 126bd90:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126bd97:	4c 8b a5 58 ff ff ff 	mov    -0xa8(%rbp),%r12
 126bd9e:	4c 89 e6             	mov    %r12,%rsi
 126bda1:	4c 89 f2             	mov    %r14,%rdx
 126bda4:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126bdab:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126bdaf:	4d 89 e9             	mov    %r13,%r9
 126bdb2:	c5 f8 77             	vzeroupper 
 126bdb5:	e8 c6 6d 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126bdba:	4d 89 f5             	mov    %r14,%r13
 126bdbd:	44 0f b7 75 88       	movzwl -0x78(%rbp),%r14d
 126bdc2:	4d 85 f6             	test   %r14,%r14
 126bdc5:	0f 85 8c 59 00 00    	jne    1271757 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x75c7>
 126bdcb:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126bdd2:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 126bdd6:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126bddd:	4c 89 f9             	mov    %r15,%rcx
 126bde0:	49 89 f7             	mov    %rsi,%r15
 126bde3:	48 89 55 d0          	mov    %rdx,-0x30(%rbp)
 126bde7:	49 89 d8             	mov    %rbx,%r8
 126bdea:	49 89 ce             	mov    %rcx,%r14
 126bded:	e8 ee 21 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126bdf2:	49 8b 4c 24 10       	mov    0x10(%r12),%rcx
 126bdf7:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 126bdfb:	4d 8b 55 08          	mov    0x8(%r13),%r10
 126bdff:	4c 8d 69 20          	lea    0x20(%rcx),%r13
 126be03:	4c 8b 89 20 30 02 00 	mov    0x23020(%rcx),%r9
 126be0a:	a8 01                	test   $0x1,%al
 126be0c:	0f 84 55 04 00 00    	je     126c267 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x20d7>
 126be12:	4d 85 c9             	test   %r9,%r9
 126be15:	4c 89 f6             	mov    %r14,%rsi
 126be18:	48 89 da             	mov    %rbx,%rdx
 126be1b:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 126be1f:	74 54                	je     126be75 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1ce5>
 126be21:	4c 89 d3             	mov    %r10,%rbx
 126be24:	49 83 f9 01          	cmp    $0x1,%r9
 126be28:	0f 85 be 3c 00 00    	jne    126faec <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x595c>
 126be2e:	31 c0                	xor    %eax,%eax
 126be30:	41 f6 c1 01          	test   $0x1,%r9b
 126be34:	49 89 da             	mov    %rbx,%r10
 126be37:	74 3c                	je     126be75 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1ce5>
 126be39:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126be40:	47 0f b6 84 0d 10 01 	movzbl 0x110(%r13,%r9,1),%r8d
 126be47:	00 00 
 126be49:	41 80 e0 0f          	and    $0xf,%r8b
 126be4d:	41 80 f8 07          	cmp    $0x7,%r8b
 126be51:	75 22                	jne    126be75 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1ce5>
 126be53:	4d 01 cd             	add    %r9,%r13
 126be56:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 126be5b:	74 18                	je     126be75 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1ce5>
 126be5d:	49 39 55 38          	cmp    %rdx,0x38(%r13)
 126be61:	75 12                	jne    126be75 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1ce5>
 126be63:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126be6a:	00 
 126be6b:	75 08                	jne    126be75 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1ce5>
 126be6d:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126be74:	00 
 126be75:	48 85 d2             	test   %rdx,%rdx
 126be78:	74 0a                	je     126be84 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1cf4>
 126be7a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126be7e:	31 c9                	xor    %ecx,%ecx
 126be80:	41 ff 52 18          	call   *0x18(%r10)
 126be84:	c5 fc 10 85 e0 f3 ff 	vmovups -0xc20(%rbp),%ymm0
 126be8b:	ff 
 126be8c:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126be93:	ff 
 126be94:	c5 fc 10 85 70 f3 ff 	vmovups -0xc90(%rbp),%ymm0
 126be9b:	ff 
 126be9c:	c5 fc 10 8d 90 f3 ff 	vmovups -0xc70(%rbp),%ymm1
 126bea3:	ff 
 126bea4:	c5 fc 10 95 b0 f3 ff 	vmovups -0xc50(%rbp),%ymm2
 126beab:	ff 
 126beac:	c5 fc 10 9d d0 f3 ff 	vmovups -0xc30(%rbp),%ymm3
 126beb3:	ff 
 126beb4:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126bebb:	ff 
 126bebc:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126bec3:	ff 
 126bec4:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126becb:	ff 
 126becc:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126bed3:	ff 
 126bed4:	e9 06 04 00 00       	jmp    126c2df <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x214f>
 126bed9:	4c 89 7d d0          	mov    %r15,-0x30(%rbp)
 126bedd:	49 89 dc             	mov    %rbx,%r12
 126bee0:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126bee4:	80 bd 1d ff ff ff 00 	cmpb   $0x0,-0xe3(%rbp)
 126beeb:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 126beef:	0f 84 8b fd ff ff    	je     126bc80 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1af0>
 126bef5:	4c 89 65 b0          	mov    %r12,-0x50(%rbp)
 126bef9:	48 8b 85 90 fb ff ff 	mov    -0x470(%rbp),%rax
 126bf00:	48 89 85 50 d9 ff ff 	mov    %rax,-0x26b0(%rbp)
 126bf07:	c5 fc 10 85 30 fb ff 	vmovups -0x4d0(%rbp),%ymm0
 126bf0e:	ff 
 126bf0f:	c5 fc 10 8d 50 fb ff 	vmovups -0x4b0(%rbp),%ymm1
 126bf16:	ff 
 126bf17:	c5 fc 10 95 70 fb ff 	vmovups -0x490(%rbp),%ymm2
 126bf1e:	ff 
 126bf1f:	c5 fc 11 95 30 d9 ff 	vmovups %ymm2,-0x26d0(%rbp)
 126bf26:	ff 
 126bf27:	c5 fc 11 8d 10 d9 ff 	vmovups %ymm1,-0x26f0(%rbp)
 126bf2e:	ff 
 126bf2f:	c5 fc 11 85 f0 d8 ff 	vmovups %ymm0,-0x2710(%rbp)
 126bf36:	ff 
 126bf37:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126bf3e:	ff 
 126bf3f:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126bf46:	ff 
 126bf47:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126bf4e:	ff 
 126bf4f:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126bf56:	ff 
 126bf57:	c5 fc 11 85 00 f4 ff 	vmovups %ymm0,-0xc00(%rbp)
 126bf5e:	ff 
 126bf5f:	c5 fc 11 8d 20 f4 ff 	vmovups %ymm1,-0xbe0(%rbp)
 126bf66:	ff 
 126bf67:	c5 fc 11 95 40 f4 ff 	vmovups %ymm2,-0xbc0(%rbp)
 126bf6e:	ff 
 126bf6f:	c5 fc 11 9d 60 f4 ff 	vmovups %ymm3,-0xba0(%rbp)
 126bf76:	ff 
 126bf77:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126bf7e:	ff 
 126bf7f:	c5 fc 11 85 70 f4 ff 	vmovups %ymm0,-0xb90(%rbp)
 126bf86:	ff 
 126bf87:	c6 85 58 d9 ff ff 01 	movb   $0x1,-0x26a8(%rbp)
 126bf8e:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126bf92:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126bf97:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126bf9e:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126bfa3:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126bfa7:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126bfad:	48 8d 85 f0 d8 ff ff 	lea    -0x2710(%rbp),%rax
 126bfb4:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126bfb9:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126bfbd:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126bfc2:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126bfc6:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126bfcb:	48 8d 85 00 f4 ff ff 	lea    -0xc00(%rbp),%rax
 126bfd2:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126bfd7:	48 89 0c 24          	mov    %rcx,(%rsp)
 126bfdb:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126bfe2:	00 00 
 126bfe4:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126bfeb:	00 00 
 126bfed:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126bff4:	4d 89 e9             	mov    %r13,%r9
 126bff7:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 126bffe:	4c 89 ee             	mov    %r13,%rsi
 126c001:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126c005:	4c 89 f2             	mov    %r14,%rdx
 126c008:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126c00f:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126c013:	4d 89 cc             	mov    %r9,%r12
 126c016:	c5 f8 77             	vzeroupper 
 126c019:	e8 62 6b 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126c01e:	44 0f b7 7d 88       	movzwl -0x78(%rbp),%r15d
 126c023:	4d 85 ff             	test   %r15,%r15
 126c026:	0f 85 3b 56 00 00    	jne    1271667 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x74d7>
 126c02c:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126c033:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 126c037:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126c03e:	49 89 f7             	mov    %rsi,%r15
 126c041:	48 89 d3             	mov    %rdx,%rbx
 126c044:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 126c048:	4c 8b 45 b0          	mov    -0x50(%rbp),%r8
 126c04c:	e8 8f 1f fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126c051:	49 8b 4d 10          	mov    0x10(%r13),%rcx
 126c055:	49 8b 3e             	mov    (%r14),%rdi
 126c058:	4d 8b 56 08          	mov    0x8(%r14),%r10
 126c05c:	4c 8d 69 20          	lea    0x20(%rcx),%r13
 126c060:	4c 8b 89 20 30 02 00 	mov    0x23020(%rcx),%r9
 126c067:	a8 01                	test   $0x1,%al
 126c069:	0f 84 6d 01 00 00    	je     126c1dc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x204c>
 126c06f:	4d 85 c9             	test   %r9,%r9
 126c072:	74 5c                	je     126c0d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1f40>
 126c074:	4c 89 d6             	mov    %r10,%rsi
 126c077:	49 83 f9 01          	cmp    $0x1,%r9
 126c07b:	0f 85 13 39 00 00    	jne    126f994 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5804>
 126c081:	31 c0                	xor    %eax,%eax
 126c083:	41 f6 c1 01          	test   $0x1,%r9b
 126c087:	49 89 f2             	mov    %rsi,%r10
 126c08a:	74 44                	je     126c0d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1f40>
 126c08c:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126c093:	45 0f b6 84 35 10 01 	movzbl 0x110(%r13,%rsi,1),%r8d
 126c09a:	00 00 
 126c09c:	41 80 e0 0f          	and    $0xf,%r8b
 126c0a0:	41 80 f8 07          	cmp    $0x7,%r8b
 126c0a4:	75 2a                	jne    126c0d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1f40>
 126c0a6:	49 01 f5             	add    %rsi,%r13
 126c0a9:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 126c0ae:	74 20                	je     126c0d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1f40>
 126c0b0:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 126c0b4:	49 39 55 38          	cmp    %rdx,0x38(%r13)
 126c0b8:	75 16                	jne    126c0d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1f40>
 126c0ba:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126c0be:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126c0c5:	00 
 126c0c6:	75 08                	jne    126c0d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1f40>
 126c0c8:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126c0cf:	00 
 126c0d0:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 126c0d4:	48 85 d2             	test   %rdx,%rdx
 126c0d7:	74 0e                	je     126c0e7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1f57>
 126c0d9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126c0dd:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126c0e1:	31 c9                	xor    %ecx,%ecx
 126c0e3:	41 ff 52 18          	call   *0x18(%r10)
 126c0e7:	c5 fc 10 85 70 f4 ff 	vmovups -0xb90(%rbp),%ymm0
 126c0ee:	ff 
 126c0ef:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126c0f6:	ff 
 126c0f7:	c5 fc 10 85 00 f4 ff 	vmovups -0xc00(%rbp),%ymm0
 126c0fe:	ff 
 126c0ff:	c5 fc 10 8d 20 f4 ff 	vmovups -0xbe0(%rbp),%ymm1
 126c106:	ff 
 126c107:	c5 fc 10 95 40 f4 ff 	vmovups -0xbc0(%rbp),%ymm2
 126c10e:	ff 
 126c10f:	c5 fc 10 9d 60 f4 ff 	vmovups -0xba0(%rbp),%ymm3
 126c116:	ff 
 126c117:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126c11e:	ff 
 126c11f:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126c126:	ff 
 126c127:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126c12e:	ff 
 126c12f:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126c136:	ff 
 126c137:	4d 89 e5             	mov    %r12,%r13
 126c13a:	80 bd 1e ff ff ff 00 	cmpb   $0x0,-0xe2(%rbp)
 126c141:	0f 85 51 fb ff ff    	jne    126bc98 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1b08>
 126c147:	49 89 de             	mov    %rbx,%r14
 126c14a:	e9 94 01 00 00       	jmp    126c2e3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2153>
 126c14f:	48 85 f6             	test   %rsi,%rsi
 126c152:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126c156:	74 51                	je     126c1a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2019>
 126c158:	48 83 fe 01          	cmp    $0x1,%rsi
 126c15c:	0f 85 8a 37 00 00    	jne    126f8ec <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x575c>
 126c162:	31 c0                	xor    %eax,%eax
 126c164:	40 f6 c6 01          	test   $0x1,%sil
 126c168:	74 3f                	je     126c1a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2019>
 126c16a:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126c171:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126c178:	00 00 
 126c17a:	41 80 e0 0f          	and    $0xf,%r8b
 126c17e:	41 80 f8 07          	cmp    $0x7,%r8b
 126c182:	75 25                	jne    126c1a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2019>
 126c184:	48 01 f2             	add    %rsi,%rdx
 126c187:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126c18b:	74 1c                	je     126c1a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2019>
 126c18d:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 126c191:	75 16                	jne    126c1a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2019>
 126c193:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126c197:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126c19e:	00 
 126c19f:	75 08                	jne    126c1a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2019>
 126c1a1:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126c1a8:	00 
 126c1a9:	4d 85 e4             	test   %r12,%r12
 126c1ac:	74 11                	je     126c1bf <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x202f>
 126c1ae:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126c1b2:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126c1b6:	4c 89 e2             	mov    %r12,%rdx
 126c1b9:	31 c9                	xor    %ecx,%ecx
 126c1bb:	41 ff 51 18          	call   *0x18(%r9)
 126c1bf:	4c 89 7d d0          	mov    %r15,-0x30(%rbp)
 126c1c3:	49 89 dc             	mov    %rbx,%r12
 126c1c6:	80 bd 1d ff ff ff 00 	cmpb   $0x0,-0xe3(%rbp)
 126c1cd:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 126c1d1:	0f 85 1e fd ff ff    	jne    126bef5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1d65>
 126c1d7:	e9 a4 fa ff ff       	jmp    126bc80 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1af0>
 126c1dc:	4d 85 c9             	test   %r9,%r9
 126c1df:	48 89 da             	mov    %rbx,%rdx
 126c1e2:	74 54                	je     126c238 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x20a8>
 126c1e4:	4c 89 d3             	mov    %r10,%rbx
 126c1e7:	49 83 f9 01          	cmp    $0x1,%r9
 126c1eb:	0f 85 57 38 00 00    	jne    126fa48 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x58b8>
 126c1f1:	31 c0                	xor    %eax,%eax
 126c1f3:	41 f6 c1 01          	test   $0x1,%r9b
 126c1f7:	49 89 da             	mov    %rbx,%r10
 126c1fa:	74 3c                	je     126c238 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x20a8>
 126c1fc:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126c203:	47 0f b6 84 0d 10 01 	movzbl 0x110(%r13,%r9,1),%r8d
 126c20a:	00 00 
 126c20c:	41 80 e0 0f          	and    $0xf,%r8b
 126c210:	41 80 f8 07          	cmp    $0x7,%r8b
 126c214:	75 22                	jne    126c238 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x20a8>
 126c216:	4d 01 cd             	add    %r9,%r13
 126c219:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 126c21e:	74 18                	je     126c238 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x20a8>
 126c220:	49 39 55 38          	cmp    %rdx,0x38(%r13)
 126c224:	75 12                	jne    126c238 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x20a8>
 126c226:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 126c22d:	00 
 126c22e:	75 08                	jne    126c238 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x20a8>
 126c230:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126c237:	00 
 126c238:	48 85 d2             	test   %rdx,%rdx
 126c23b:	74 0d                	je     126c24a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x20ba>
 126c23d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126c241:	4c 89 fe             	mov    %r15,%rsi
 126c244:	31 c9                	xor    %ecx,%ecx
 126c246:	41 ff 52 18          	call   *0x18(%r10)
 126c24a:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 126c24e:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 126c252:	4d 89 e5             	mov    %r12,%r13
 126c255:	80 bd 1e ff ff ff 00 	cmpb   $0x0,-0xe2(%rbp)
 126c25c:	0f 85 36 fa ff ff    	jne    126bc98 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1b08>
 126c262:	e9 e0 fe ff ff       	jmp    126c147 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1fb7>
 126c267:	4d 85 c9             	test   %r9,%r9
 126c26a:	4d 89 f4             	mov    %r14,%r12
 126c26d:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126c271:	74 54                	je     126c2c7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2137>
 126c273:	4d 89 d6             	mov    %r10,%r14
 126c276:	49 83 f9 01          	cmp    $0x1,%r9
 126c27a:	0f 85 0c 39 00 00    	jne    126fb8c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x59fc>
 126c280:	31 c0                	xor    %eax,%eax
 126c282:	41 f6 c1 01          	test   $0x1,%r9b
 126c286:	4d 89 f2             	mov    %r14,%r10
 126c289:	74 3c                	je     126c2c7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2137>
 126c28b:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126c292:	47 0f b6 84 0d 10 01 	movzbl 0x110(%r13,%r9,1),%r8d
 126c299:	00 00 
 126c29b:	41 80 e0 0f          	and    $0xf,%r8b
 126c29f:	41 80 f8 07          	cmp    $0x7,%r8b
 126c2a3:	75 22                	jne    126c2c7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2137>
 126c2a5:	4d 01 cd             	add    %r9,%r13
 126c2a8:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 126c2ad:	74 18                	je     126c2c7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2137>
 126c2af:	49 39 55 38          	cmp    %rdx,0x38(%r13)
 126c2b3:	75 12                	jne    126c2c7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2137>
 126c2b5:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 126c2bc:	00 
 126c2bd:	75 08                	jne    126c2c7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2137>
 126c2bf:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126c2c6:	00 
 126c2c7:	48 85 d2             	test   %rdx,%rdx
 126c2ca:	74 0d                	je     126c2d9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2149>
 126c2cc:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126c2d0:	4c 89 fe             	mov    %r15,%rsi
 126c2d3:	31 c9                	xor    %ecx,%ecx
 126c2d5:	41 ff 52 18          	call   *0x18(%r10)
 126c2d9:	4d 89 e7             	mov    %r12,%r15
 126c2dc:	49 89 de             	mov    %rbx,%r14
 126c2df:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126c2e3:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 126c2ea:	0f 95 c0             	setne  %al
 126c2ed:	84 45 a5             	test   %al,-0x5b(%rbp)
 126c2f0:	48 8b 5d 10          	mov    0x10(%rbp),%rbx
 126c2f4:	0f 84 26 02 00 00    	je     126c520 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2390>
 126c2fa:	4c 89 7d b0          	mov    %r15,-0x50(%rbp)
 126c2fe:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126c305:	ff 
 126c306:	c5 fc 11 85 50 f3 ff 	vmovups %ymm0,-0xcb0(%rbp)
 126c30d:	ff 
 126c30e:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126c315:	ff 
 126c316:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126c31d:	ff 
 126c31e:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126c325:	ff 
 126c326:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126c32d:	ff 
 126c32e:	c5 fc 11 9d 40 f3 ff 	vmovups %ymm3,-0xcc0(%rbp)
 126c335:	ff 
 126c336:	c5 fc 11 95 20 f3 ff 	vmovups %ymm2,-0xce0(%rbp)
 126c33d:	ff 
 126c33e:	c5 fc 11 8d 00 f3 ff 	vmovups %ymm1,-0xd00(%rbp)
 126c345:	ff 
 126c346:	c5 fc 11 85 e0 f2 ff 	vmovups %ymm0,-0xd20(%rbp)
 126c34d:	ff 
 126c34e:	48 8d 85 20 ff ff ff 	lea    -0xe0(%rbp),%rax
 126c355:	48 89 44 24 28       	mov    %rax,0x28(%rsp)
 126c35a:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126c35e:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126c363:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126c367:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126c36c:	48 8d 85 e0 f2 ff ff 	lea    -0xd20(%rbp),%rax
 126c373:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126c378:	48 89 1c 24          	mov    %rbx,(%rsp)
 126c37c:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126c383:	00 00 
 126c385:	48 c7 44 24 48 68 ae 	movq   $0x103ae68,0x48(%rsp)
 126c38c:	03 01 
 126c38e:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126c395:	00 00 
 126c397:	48 c7 44 24 38 f8 ad 	movq   $0x103adf8,0x38(%rsp)
 126c39e:	03 01 
 126c3a0:	48 c7 44 24 30 00 00 	movq   $0x0,0x30(%rsp)
 126c3a7:	00 00 
 126c3a9:	48 c7 44 24 20 88 ad 	movq   $0x103ad88,0x20(%rsp)
 126c3b0:	03 01 
 126c3b2:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126c3b9:	4c 8b a5 58 ff ff ff 	mov    -0xa8(%rbp),%r12
 126c3c0:	4c 89 e6             	mov    %r12,%rsi
 126c3c3:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 126c3c7:	4c 89 fa             	mov    %r15,%rdx
 126c3ca:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126c3d1:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126c3d5:	4d 89 e9             	mov    %r13,%r9
 126c3d8:	c5 f8 77             	vzeroupper 
 126c3db:	e8 a0 67 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126c3e0:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126c3e4:	48 85 db             	test   %rbx,%rbx
 126c3e7:	0f 85 bb 5f 00 00    	jne    12723a8 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8218>
 126c3ed:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126c3f4:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 126c3f8:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126c3ff:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 126c403:	4d 89 f0             	mov    %r14,%r8
 126c406:	49 89 d6             	mov    %rdx,%r14
 126c409:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 126c40d:	4d 89 c5             	mov    %r8,%r13
 126c410:	e8 cb 1b fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126c415:	49 8b 4c 24 10       	mov    0x10(%r12),%rcx
 126c41a:	49 8b 3f             	mov    (%r15),%rdi
 126c41d:	4d 8b 5f 08          	mov    0x8(%r15),%r11
 126c421:	4c 8d 49 20          	lea    0x20(%rcx),%r9
 126c425:	4c 8b b9 20 30 02 00 	mov    0x23020(%rcx),%r15
 126c42c:	a8 01                	test   $0x1,%al
 126c42e:	0f 84 2d 14 00 00    	je     126d861 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x36d1>
 126c434:	4d 85 ff             	test   %r15,%r15
 126c437:	48 8b 5d 10          	mov    0x10(%rbp),%rbx
 126c43b:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 126c43f:	4d 89 f4             	mov    %r14,%r12
 126c442:	74 54                	je     126c498 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2308>
 126c444:	4d 89 de             	mov    %r11,%r14
 126c447:	49 83 ff 01          	cmp    $0x1,%r15
 126c44b:	0f 85 93 47 00 00    	jne    1270be4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a54>
 126c451:	31 c0                	xor    %eax,%eax
 126c453:	41 f6 c7 01          	test   $0x1,%r15b
 126c457:	4d 89 f3             	mov    %r14,%r11
 126c45a:	74 3c                	je     126c498 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2308>
 126c45c:	4c 69 d0 18 01 00 00 	imul   $0x118,%rax,%r10
 126c463:	47 0f b6 84 11 10 01 	movzbl 0x110(%r9,%r10,1),%r8d
 126c46a:	00 00 
 126c46c:	41 80 e0 0f          	and    $0xf,%r8b
 126c470:	41 80 f8 07          	cmp    $0x7,%r8b
 126c474:	75 22                	jne    126c498 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2308>
 126c476:	4d 01 d1             	add    %r10,%r9
 126c479:	41 80 79 40 00       	cmpb   $0x0,0x40(%r9)
 126c47e:	74 18                	je     126c498 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2308>
 126c480:	4d 39 69 38          	cmp    %r13,0x38(%r9)
 126c484:	75 12                	jne    126c498 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2308>
 126c486:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126c48d:	00 
 126c48e:	75 08                	jne    126c498 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2308>
 126c490:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126c497:	00 
 126c498:	4d 85 ed             	test   %r13,%r13
 126c49b:	74 0d                	je     126c4aa <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x231a>
 126c49d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126c4a1:	4c 89 ea             	mov    %r13,%rdx
 126c4a4:	31 c9                	xor    %ecx,%ecx
 126c4a6:	41 ff 53 18          	call   *0x18(%r11)
 126c4aa:	c5 fc 10 85 50 f3 ff 	vmovups -0xcb0(%rbp),%ymm0
 126c4b1:	ff 
 126c4b2:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126c4b9:	ff 
 126c4ba:	c5 fc 10 85 e0 f2 ff 	vmovups -0xd20(%rbp),%ymm0
 126c4c1:	ff 
 126c4c2:	c5 fc 10 8d 00 f3 ff 	vmovups -0xd00(%rbp),%ymm1
 126c4c9:	ff 
 126c4ca:	c5 fc 10 95 20 f3 ff 	vmovups -0xce0(%rbp),%ymm2
 126c4d1:	ff 
 126c4d2:	c5 fc 10 9d 40 f3 ff 	vmovups -0xcc0(%rbp),%ymm3
 126c4d9:	ff 
 126c4da:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126c4e1:	ff 
 126c4e2:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126c4e9:	ff 
 126c4ea:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126c4f1:	ff 
 126c4f2:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126c4f9:	ff 
 126c4fa:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 126c501:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126c505:	75 2d                	jne    126c534 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x23a4>
 126c507:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 126c50b:	4c 89 e3             	mov    %r12,%rbx
 126c50e:	80 bd f8 dd ff ff 00 	cmpb   $0x0,-0x2208(%rbp)
 126c515:	0f 85 9a 02 00 00    	jne    126c7b5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2625>
 126c51b:	e9 f0 09 00 00       	jmp    126cf10 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d80>
 126c520:	4c 89 7d d0          	mov    %r15,-0x30(%rbp)
 126c524:	4d 89 f4             	mov    %r14,%r12
 126c527:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 126c52e:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126c532:	74 d3                	je     126c507 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2377>
 126c534:	4d 89 e5             	mov    %r12,%r13
 126c537:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126c53e:	ff 
 126c53f:	c5 fc 11 85 c0 f2 ff 	vmovups %ymm0,-0xd40(%rbp)
 126c546:	ff 
 126c547:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126c54e:	ff 
 126c54f:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126c556:	ff 
 126c557:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126c55e:	ff 
 126c55f:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126c566:	ff 
 126c567:	c5 fc 11 9d b0 f2 ff 	vmovups %ymm3,-0xd50(%rbp)
 126c56e:	ff 
 126c56f:	c5 fc 11 95 90 f2 ff 	vmovups %ymm2,-0xd70(%rbp)
 126c576:	ff 
 126c577:	c5 fc 11 8d 70 f2 ff 	vmovups %ymm1,-0xd90(%rbp)
 126c57e:	ff 
 126c57f:	c5 fc 11 85 50 f2 ff 	vmovups %ymm0,-0xdb0(%rbp)
 126c586:	ff 
 126c587:	48 8d 85 20 fe ff ff 	lea    -0x1e0(%rbp),%rax
 126c58e:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 126c593:	48 89 44 24 28       	mov    %rax,0x28(%rsp)
 126c598:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126c59c:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126c5a1:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126c5a5:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126c5aa:	48 8d 85 50 f2 ff ff 	lea    -0xdb0(%rbp),%rax
 126c5b1:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126c5b6:	48 89 1c 24          	mov    %rbx,(%rsp)
 126c5ba:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126c5c1:	00 00 
 126c5c3:	48 c7 44 24 48 68 ae 	movq   $0x103ae68,0x48(%rsp)
 126c5ca:	03 01 
 126c5cc:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126c5d3:	00 00 
 126c5d5:	48 c7 44 24 38 f8 ad 	movq   $0x103adf8,0x38(%rsp)
 126c5dc:	03 01 
 126c5de:	48 c7 44 24 20 88 ad 	movq   $0x103ad88,0x20(%rsp)
 126c5e5:	03 01 
 126c5e7:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126c5ee:	4c 8b a5 58 ff ff ff 	mov    -0xa8(%rbp),%r12
 126c5f5:	4c 89 e6             	mov    %r12,%rsi
 126c5f8:	4c 89 f2             	mov    %r14,%rdx
 126c5fb:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126c602:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126c606:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126c60a:	c5 f8 77             	vzeroupper 
 126c60d:	e8 6e 65 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126c612:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126c616:	48 85 db             	test   %rbx,%rbx
 126c619:	0f 85 24 52 00 00    	jne    1271843 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x76b3>
 126c61f:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 126c626:	48 8b 5d 80          	mov    -0x80(%rbp),%rbx
 126c62a:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126c631:	4c 89 fe             	mov    %r15,%rsi
 126c634:	48 89 da             	mov    %rbx,%rdx
 126c637:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 126c63b:	4d 89 e8             	mov    %r13,%r8
 126c63e:	e8 9d 19 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126c643:	49 8b 4c 24 10       	mov    0x10(%r12),%rcx
 126c648:	49 8b 3e             	mov    (%r14),%rdi
 126c64b:	4d 8b 66 08          	mov    0x8(%r14),%r12
 126c64f:	4c 8d 49 20          	lea    0x20(%rcx),%r9
 126c653:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126c65a:	a8 01                	test   $0x1,%al
 126c65c:	0f 84 d0 00 00 00    	je     126c732 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x25a2>
 126c662:	48 85 f6             	test   %rsi,%rsi
 126c665:	74 52                	je     126c6b9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2529>
 126c667:	48 83 fe 01          	cmp    $0x1,%rsi
 126c66b:	0f 85 bb 35 00 00    	jne    126fc2c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a9c>
 126c671:	31 c0                	xor    %eax,%eax
 126c673:	40 f6 c6 01          	test   $0x1,%sil
 126c677:	74 40                	je     126c6b9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2529>
 126c679:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126c680:	45 0f b6 84 31 10 01 	movzbl 0x110(%r9,%rsi,1),%r8d
 126c687:	00 00 
 126c689:	41 80 e0 0f          	and    $0xf,%r8b
 126c68d:	41 80 f8 07          	cmp    $0x7,%r8b
 126c691:	75 26                	jne    126c6b9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2529>
 126c693:	49 01 f1             	add    %rsi,%r9
 126c696:	41 80 79 40 00       	cmpb   $0x0,0x40(%r9)
 126c69b:	74 1c                	je     126c6b9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2529>
 126c69d:	4d 39 69 38          	cmp    %r13,0x38(%r9)
 126c6a1:	75 16                	jne    126c6b9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2529>
 126c6a3:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126c6a7:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126c6ae:	00 
 126c6af:	75 08                	jne    126c6b9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2529>
 126c6b1:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126c6b8:	00 
 126c6b9:	4d 85 ed             	test   %r13,%r13
 126c6bc:	74 12                	je     126c6d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2540>
 126c6be:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126c6c2:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126c6c6:	4c 89 ea             	mov    %r13,%rdx
 126c6c9:	31 c9                	xor    %ecx,%ecx
 126c6cb:	41 ff 54 24 18       	call   *0x18(%r12)
 126c6d0:	c5 fc 10 85 c0 f2 ff 	vmovups -0xd40(%rbp),%ymm0
 126c6d7:	ff 
 126c6d8:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126c6df:	ff 
 126c6e0:	c5 fc 10 85 50 f2 ff 	vmovups -0xdb0(%rbp),%ymm0
 126c6e7:	ff 
 126c6e8:	c5 fc 10 8d 70 f2 ff 	vmovups -0xd90(%rbp),%ymm1
 126c6ef:	ff 
 126c6f0:	c5 fc 10 95 90 f2 ff 	vmovups -0xd70(%rbp),%ymm2
 126c6f7:	ff 
 126c6f8:	c5 fc 10 9d b0 f2 ff 	vmovups -0xd50(%rbp),%ymm3
 126c6ff:	ff 
 126c700:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126c707:	ff 
 126c708:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126c70f:	ff 
 126c710:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126c717:	ff 
 126c718:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126c71f:	ff 
 126c720:	80 bd f8 dd ff ff 00 	cmpb   $0x0,-0x2208(%rbp)
 126c727:	0f 85 88 00 00 00    	jne    126c7b5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2625>
 126c72d:	e9 de 07 00 00       	jmp    126cf10 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d80>
 126c732:	4c 89 65 b0          	mov    %r12,-0x50(%rbp)
 126c736:	48 85 f6             	test   %rsi,%rsi
 126c739:	74 4e                	je     126c789 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x25f9>
 126c73b:	48 83 fe 01          	cmp    $0x1,%rsi
 126c73f:	0f 85 8f 35 00 00    	jne    126fcd4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b44>
 126c745:	31 c0                	xor    %eax,%eax
 126c747:	40 f6 c6 01          	test   $0x1,%sil
 126c74b:	74 3c                	je     126c789 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x25f9>
 126c74d:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126c754:	45 0f b6 84 31 10 01 	movzbl 0x110(%r9,%rsi,1),%r8d
 126c75b:	00 00 
 126c75d:	41 80 e0 0f          	and    $0xf,%r8b
 126c761:	41 80 f8 07          	cmp    $0x7,%r8b
 126c765:	75 22                	jne    126c789 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x25f9>
 126c767:	49 01 f1             	add    %rsi,%r9
 126c76a:	41 80 79 40 00       	cmpb   $0x0,0x40(%r9)
 126c76f:	74 18                	je     126c789 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x25f9>
 126c771:	49 39 59 38          	cmp    %rbx,0x38(%r9)
 126c775:	75 12                	jne    126c789 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x25f9>
 126c777:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 126c77e:	00 
 126c77f:	75 08                	jne    126c789 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x25f9>
 126c781:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126c788:	00 
 126c789:	48 85 db             	test   %rbx,%rbx
 126c78c:	74 13                	je     126c7a1 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2611>
 126c78e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126c792:	4c 89 fe             	mov    %r15,%rsi
 126c795:	48 89 da             	mov    %rbx,%rdx
 126c798:	31 c9                	xor    %ecx,%ecx
 126c79a:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 126c79e:	ff 50 18             	call   *0x18(%rax)
 126c7a1:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 126c7a5:	4c 89 eb             	mov    %r13,%rbx
 126c7a8:	80 bd f8 dd ff ff 00 	cmpb   $0x0,-0x2208(%rbp)
 126c7af:	0f 84 5b 07 00 00    	je     126cf10 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d80>
 126c7b5:	48 8b 85 f0 dd ff ff 	mov    -0x2210(%rbp),%rax
 126c7bc:	48 89 85 70 d8 ff ff 	mov    %rax,-0x2790(%rbp)
 126c7c3:	c5 fc 10 85 90 dd ff 	vmovups -0x2270(%rbp),%ymm0
 126c7ca:	ff 
 126c7cb:	c5 fc 10 8d b0 dd ff 	vmovups -0x2250(%rbp),%ymm1
 126c7d2:	ff 
 126c7d3:	c5 fc 10 95 d0 dd ff 	vmovups -0x2230(%rbp),%ymm2
 126c7da:	ff 
 126c7db:	c5 fc 11 95 50 d8 ff 	vmovups %ymm2,-0x27b0(%rbp)
 126c7e2:	ff 
 126c7e3:	c5 fc 11 8d 30 d8 ff 	vmovups %ymm1,-0x27d0(%rbp)
 126c7ea:	ff 
 126c7eb:	c5 fc 11 85 10 d8 ff 	vmovups %ymm0,-0x27f0(%rbp)
 126c7f2:	ff 
 126c7f3:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126c7fa:	ff 
 126c7fb:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126c802:	ff 
 126c803:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126c80a:	ff 
 126c80b:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126c812:	ff 
 126c813:	c5 fc 11 85 c0 f1 ff 	vmovups %ymm0,-0xe40(%rbp)
 126c81a:	ff 
 126c81b:	c5 fc 11 8d e0 f1 ff 	vmovups %ymm1,-0xe20(%rbp)
 126c822:	ff 
 126c823:	c5 fc 11 95 00 f2 ff 	vmovups %ymm2,-0xe00(%rbp)
 126c82a:	ff 
 126c82b:	c5 fc 11 9d 20 f2 ff 	vmovups %ymm3,-0xde0(%rbp)
 126c832:	ff 
 126c833:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126c83a:	ff 
 126c83b:	c5 fc 11 85 30 f2 ff 	vmovups %ymm0,-0xdd0(%rbp)
 126c842:	ff 
 126c843:	c6 85 78 d8 ff ff 01 	movb   $0x1,-0x2788(%rbp)
 126c84a:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126c84e:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126c853:	48 8d 85 10 d8 ff ff 	lea    -0x27f0(%rbp),%rax
 126c85a:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126c85f:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126c863:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126c869:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126c86d:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126c872:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126c876:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126c87b:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126c87f:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126c884:	48 8d 85 c0 f1 ff ff 	lea    -0xe40(%rbp),%rax
 126c88b:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126c890:	48 8b 45 10          	mov    0x10(%rbp),%rax
 126c894:	48 89 04 24          	mov    %rax,(%rsp)
 126c898:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126c89f:	00 00 
 126c8a1:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126c8a8:	00 00 
 126c8aa:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126c8b1:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 126c8b8:	4c 89 ee             	mov    %r13,%rsi
 126c8bb:	4c 89 f2             	mov    %r14,%rdx
 126c8be:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126c8c5:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126c8c9:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126c8cd:	c5 f8 77             	vzeroupper 
 126c8d0:	e8 ab 62 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126c8d5:	44 0f b7 65 88       	movzwl -0x78(%rbp),%r12d
 126c8da:	4d 85 e4             	test   %r12,%r12
 126c8dd:	0f 85 4c 50 00 00    	jne    127192f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x779f>
 126c8e3:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126c8ea:	4c 8b 65 80          	mov    -0x80(%rbp),%r12
 126c8ee:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126c8f5:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 126c8f9:	4c 89 e2             	mov    %r12,%rdx
 126c8fc:	4c 89 f9             	mov    %r15,%rcx
 126c8ff:	49 89 d8             	mov    %rbx,%r8
 126c902:	e8 d9 16 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126c907:	49 8b 4d 10          	mov    0x10(%r13),%rcx
 126c90b:	49 8b 3e             	mov    (%r14),%rdi
 126c90e:	4d 8b 4e 08          	mov    0x8(%r14),%r9
 126c912:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126c916:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126c91d:	a8 01                	test   $0x1,%al
 126c91f:	0f 84 7f 05 00 00    	je     126cea4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d14>
 126c925:	48 85 f6             	test   %rsi,%rsi
 126c928:	74 4d                	je     126c977 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x27e7>
 126c92a:	48 83 fe 01          	cmp    $0x1,%rsi
 126c92e:	0f 85 48 34 00 00    	jne    126fd7c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5bec>
 126c934:	31 c0                	xor    %eax,%eax
 126c936:	40 f6 c6 01          	test   $0x1,%sil
 126c93a:	74 3b                	je     126c977 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x27e7>
 126c93c:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126c943:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126c94a:	00 00 
 126c94c:	41 80 e0 0f          	and    $0xf,%r8b
 126c950:	41 80 f8 07          	cmp    $0x7,%r8b
 126c954:	75 21                	jne    126c977 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x27e7>
 126c956:	48 01 f2             	add    %rsi,%rdx
 126c959:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126c95d:	74 18                	je     126c977 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x27e7>
 126c95f:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126c963:	75 12                	jne    126c977 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x27e7>
 126c965:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 126c96c:	00 
 126c96d:	75 08                	jne    126c977 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x27e7>
 126c96f:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126c976:	00 
 126c977:	48 85 db             	test   %rbx,%rbx
 126c97a:	74 10                	je     126c98c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x27fc>
 126c97c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126c980:	4c 89 fe             	mov    %r15,%rsi
 126c983:	48 89 da             	mov    %rbx,%rdx
 126c986:	31 c9                	xor    %ecx,%ecx
 126c988:	41 ff 51 18          	call   *0x18(%r9)
 126c98c:	c5 fc 10 85 30 f2 ff 	vmovups -0xdd0(%rbp),%ymm0
 126c993:	ff 
 126c994:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126c99b:	ff 
 126c99c:	c5 fc 10 85 c0 f1 ff 	vmovups -0xe40(%rbp),%ymm0
 126c9a3:	ff 
 126c9a4:	c5 fc 10 8d e0 f1 ff 	vmovups -0xe20(%rbp),%ymm1
 126c9ab:	ff 
 126c9ac:	c5 fc 10 95 00 f2 ff 	vmovups -0xe00(%rbp),%ymm2
 126c9b3:	ff 
 126c9b4:	c5 fc 10 9d 20 f2 ff 	vmovups -0xde0(%rbp),%ymm3
 126c9bb:	ff 
 126c9bc:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126c9c3:	ff 
 126c9c4:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126c9cb:	ff 
 126c9cc:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126c9d3:	ff 
 126c9d4:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126c9db:	ff 
 126c9dc:	80 bd 68 de ff ff 00 	cmpb   $0x0,-0x2198(%rbp)
 126c9e3:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126c9e7:	0f 85 3b 05 00 00    	jne    126cf28 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d98>
 126c9ed:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 126c9f1:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 126c9f5:	4c 89 e3             	mov    %r12,%rbx
 126c9f8:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126c9fc:	80 bd d8 de ff ff 00 	cmpb   $0x0,-0x2128(%rbp)
 126ca03:	0f 84 e5 07 00 00    	je     126d1ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x305e>
 126ca09:	48 8b 85 d0 de ff ff 	mov    -0x2130(%rbp),%rax
 126ca10:	48 89 85 90 d7 ff ff 	mov    %rax,-0x2870(%rbp)
 126ca17:	c5 fc 10 85 70 de ff 	vmovups -0x2190(%rbp),%ymm0
 126ca1e:	ff 
 126ca1f:	c5 fc 10 8d 90 de ff 	vmovups -0x2170(%rbp),%ymm1
 126ca26:	ff 
 126ca27:	c5 fc 10 95 b0 de ff 	vmovups -0x2150(%rbp),%ymm2
 126ca2e:	ff 
 126ca2f:	c5 fc 11 95 70 d7 ff 	vmovups %ymm2,-0x2890(%rbp)
 126ca36:	ff 
 126ca37:	c5 fc 11 8d 50 d7 ff 	vmovups %ymm1,-0x28b0(%rbp)
 126ca3e:	ff 
 126ca3f:	c5 fc 11 85 30 d7 ff 	vmovups %ymm0,-0x28d0(%rbp)
 126ca46:	ff 
 126ca47:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126ca4e:	ff 
 126ca4f:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126ca56:	ff 
 126ca57:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126ca5e:	ff 
 126ca5f:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126ca66:	ff 
 126ca67:	c5 fc 11 85 a0 f0 ff 	vmovups %ymm0,-0xf60(%rbp)
 126ca6e:	ff 
 126ca6f:	c5 fc 11 8d c0 f0 ff 	vmovups %ymm1,-0xf40(%rbp)
 126ca76:	ff 
 126ca77:	c5 fc 11 95 e0 f0 ff 	vmovups %ymm2,-0xf20(%rbp)
 126ca7e:	ff 
 126ca7f:	c5 fc 11 9d 00 f1 ff 	vmovups %ymm3,-0xf00(%rbp)
 126ca86:	ff 
 126ca87:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126ca8e:	ff 
 126ca8f:	c5 fc 11 85 10 f1 ff 	vmovups %ymm0,-0xef0(%rbp)
 126ca96:	ff 
 126ca97:	c6 85 98 d7 ff ff 01 	movb   $0x1,-0x2868(%rbp)
 126ca9e:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126caa2:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126caa7:	48 8d 85 30 d7 ff ff 	lea    -0x28d0(%rbp),%rax
 126caae:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126cab3:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126cab7:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126cabd:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126cac1:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126cac6:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126caca:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126cacf:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126cad3:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126cad8:	48 8d 85 a0 f0 ff ff 	lea    -0xf60(%rbp),%rax
 126cadf:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126cae4:	4c 89 3c 24          	mov    %r15,(%rsp)
 126cae8:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126caef:	00 00 
 126caf1:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126caf8:	00 00 
 126cafa:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126cb01:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 126cb08:	4c 89 fe             	mov    %r15,%rsi
 126cb0b:	4c 89 f2             	mov    %r14,%rdx
 126cb0e:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126cb15:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126cb19:	4d 89 e9             	mov    %r13,%r9
 126cb1c:	c5 f8 77             	vzeroupper 
 126cb1f:	e8 5c 60 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126cb24:	4d 89 f5             	mov    %r14,%r13
 126cb27:	44 0f b7 75 88       	movzwl -0x78(%rbp),%r14d
 126cb2c:	4d 85 f6             	test   %r14,%r14
 126cb2f:	0f 85 d6 4f 00 00    	jne    1271b0b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x797b>
 126cb35:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126cb3c:	4c 8b 65 80          	mov    -0x80(%rbp),%r12
 126cb40:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126cb47:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 126cb4b:	4c 89 e2             	mov    %r12,%rdx
 126cb4e:	4c 8b 75 b0          	mov    -0x50(%rbp),%r14
 126cb52:	4c 89 f1             	mov    %r14,%rcx
 126cb55:	49 89 d8             	mov    %rbx,%r8
 126cb58:	e8 83 14 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126cb5d:	49 8b 4f 10          	mov    0x10(%r15),%rcx
 126cb61:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 126cb65:	4d 8b 4d 08          	mov    0x8(%r13),%r9
 126cb69:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126cb6d:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126cb74:	a8 01                	test   $0x1,%al
 126cb76:	0f 84 e9 08 00 00    	je     126d465 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x32d5>
 126cb7c:	48 85 f6             	test   %rsi,%rsi
 126cb7f:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126cb83:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126cb87:	74 4d                	je     126cbd6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2a46>
 126cb89:	48 83 fe 01          	cmp    $0x1,%rsi
 126cb8d:	0f 85 91 34 00 00    	jne    1270024 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e94>
 126cb93:	31 c0                	xor    %eax,%eax
 126cb95:	40 f6 c6 01          	test   $0x1,%sil
 126cb99:	74 3b                	je     126cbd6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2a46>
 126cb9b:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126cba2:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126cba9:	00 00 
 126cbab:	41 80 e0 0f          	and    $0xf,%r8b
 126cbaf:	41 80 f8 07          	cmp    $0x7,%r8b
 126cbb3:	75 21                	jne    126cbd6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2a46>
 126cbb5:	48 01 f2             	add    %rsi,%rdx
 126cbb8:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126cbbc:	74 18                	je     126cbd6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2a46>
 126cbbe:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126cbc2:	75 12                	jne    126cbd6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2a46>
 126cbc4:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 126cbcb:	00 
 126cbcc:	75 08                	jne    126cbd6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2a46>
 126cbce:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126cbd5:	00 
 126cbd6:	48 85 db             	test   %rbx,%rbx
 126cbd9:	74 10                	je     126cbeb <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2a5b>
 126cbdb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126cbdf:	4c 89 f6             	mov    %r14,%rsi
 126cbe2:	48 89 da             	mov    %rbx,%rdx
 126cbe5:	31 c9                	xor    %ecx,%ecx
 126cbe7:	41 ff 51 18          	call   *0x18(%r9)
 126cbeb:	c5 fc 10 85 10 f1 ff 	vmovups -0xef0(%rbp),%ymm0
 126cbf2:	ff 
 126cbf3:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126cbfa:	ff 
 126cbfb:	c5 fc 10 85 a0 f0 ff 	vmovups -0xf60(%rbp),%ymm0
 126cc02:	ff 
 126cc03:	c5 fc 10 8d c0 f0 ff 	vmovups -0xf40(%rbp),%ymm1
 126cc0a:	ff 
 126cc0b:	c5 fc 10 95 e0 f0 ff 	vmovups -0xf20(%rbp),%ymm2
 126cc12:	ff 
 126cc13:	c5 fc 10 9d 00 f1 ff 	vmovups -0xf00(%rbp),%ymm3
 126cc1a:	ff 
 126cc1b:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126cc22:	ff 
 126cc23:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126cc2a:	ff 
 126cc2b:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126cc32:	ff 
 126cc33:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126cc3a:	ff 
 126cc3b:	80 bd 48 df ff ff 00 	cmpb   $0x0,-0x20b8(%rbp)
 126cc42:	0f 85 be 05 00 00    	jne    126d206 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3076>
 126cc48:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 126cc4c:	4d 89 e5             	mov    %r12,%r13
 126cc4f:	80 bd b8 df ff ff 00 	cmpb   $0x0,-0x2048(%rbp)
 126cc56:	4c 8b 65 b8          	mov    -0x48(%rbp),%r12
 126cc5a:	0f 84 fa 07 00 00    	je     126d45a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x32ca>
 126cc60:	48 8b 85 b0 df ff ff 	mov    -0x2050(%rbp),%rax
 126cc67:	48 89 85 b0 d6 ff ff 	mov    %rax,-0x2950(%rbp)
 126cc6e:	c5 fc 10 85 50 df ff 	vmovups -0x20b0(%rbp),%ymm0
 126cc75:	ff 
 126cc76:	c5 fc 10 8d 70 df ff 	vmovups -0x2090(%rbp),%ymm1
 126cc7d:	ff 
 126cc7e:	c5 fc 10 95 90 df ff 	vmovups -0x2070(%rbp),%ymm2
 126cc85:	ff 
 126cc86:	c5 fc 11 95 90 d6 ff 	vmovups %ymm2,-0x2970(%rbp)
 126cc8d:	ff 
 126cc8e:	c5 fc 11 8d 70 d6 ff 	vmovups %ymm1,-0x2990(%rbp)
 126cc95:	ff 
 126cc96:	c5 fc 11 85 50 d6 ff 	vmovups %ymm0,-0x29b0(%rbp)
 126cc9d:	ff 
 126cc9e:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126cca5:	ff 
 126cca6:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126ccad:	ff 
 126ccae:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126ccb5:	ff 
 126ccb6:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126ccbd:	ff 
 126ccbe:	c5 fc 11 85 80 ef ff 	vmovups %ymm0,-0x1080(%rbp)
 126ccc5:	ff 
 126ccc6:	c5 fc 11 8d a0 ef ff 	vmovups %ymm1,-0x1060(%rbp)
 126cccd:	ff 
 126ccce:	c5 fc 11 95 c0 ef ff 	vmovups %ymm2,-0x1040(%rbp)
 126ccd5:	ff 
 126ccd6:	c5 fc 11 9d e0 ef ff 	vmovups %ymm3,-0x1020(%rbp)
 126ccdd:	ff 
 126ccde:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126cce5:	ff 
 126cce6:	c5 fc 11 85 f0 ef ff 	vmovups %ymm0,-0x1010(%rbp)
 126cced:	ff 
 126ccee:	c6 85 b8 d6 ff ff 01 	movb   $0x1,-0x2948(%rbp)
 126ccf5:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126ccf9:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126ccfe:	48 8d 85 50 d6 ff ff 	lea    -0x29b0(%rbp),%rax
 126cd05:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126cd0a:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126cd0e:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126cd14:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126cd18:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126cd1d:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126cd21:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126cd26:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126cd2a:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126cd2f:	48 8d 85 80 ef ff ff 	lea    -0x1080(%rbp),%rax
 126cd36:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126cd3b:	4c 89 3c 24          	mov    %r15,(%rsp)
 126cd3f:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126cd46:	00 00 
 126cd48:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126cd4f:	00 00 
 126cd51:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126cd58:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 126cd5f:	4c 89 fe             	mov    %r15,%rsi
 126cd62:	4c 89 e2             	mov    %r12,%rdx
 126cd65:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126cd6c:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126cd70:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126cd74:	c5 f8 77             	vzeroupper 
 126cd77:	e8 04 5e 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126cd7c:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126cd80:	48 85 db             	test   %rbx,%rbx
 126cd83:	0f 85 5b 4f 00 00    	jne    1271ce4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7b54>
 126cd89:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126cd90:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 126cd94:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126cd9b:	48 89 f3             	mov    %rsi,%rbx
 126cd9e:	48 89 55 c8          	mov    %rdx,-0x38(%rbp)
 126cda2:	4d 89 e8             	mov    %r13,%r8
 126cda5:	4d 89 f5             	mov    %r14,%r13
 126cda8:	4c 89 f1             	mov    %r14,%rcx
 126cdab:	4d 89 c6             	mov    %r8,%r14
 126cdae:	e8 2d 12 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126cdb3:	49 8b 4f 10          	mov    0x10(%r15),%rcx
 126cdb7:	49 8b 3c 24          	mov    (%r12),%rdi
 126cdbb:	4d 8b 54 24 08       	mov    0x8(%r12),%r10
 126cdc0:	4c 8d 41 20          	lea    0x20(%rcx),%r8
 126cdc4:	4c 8b 89 20 30 02 00 	mov    0x23020(%rcx),%r9
 126cdcb:	a8 01                	test   $0x1,%al
 126cdcd:	0f 84 b5 07 00 00    	je     126d588 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x33f8>
 126cdd3:	4d 85 c9             	test   %r9,%r9
 126cdd6:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126cdda:	49 89 dc             	mov    %rbx,%r12
 126cddd:	4c 89 ee             	mov    %r13,%rsi
 126cde0:	4c 89 f2             	mov    %r14,%rdx
 126cde3:	48 8b 5d c8          	mov    -0x38(%rbp),%rbx
 126cde7:	74 57                	je     126ce40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2cb0>
 126cde9:	4d 89 c5             	mov    %r8,%r13
 126cdec:	4d 89 d6             	mov    %r10,%r14
 126cdef:	49 83 f9 01          	cmp    $0x1,%r9
 126cdf3:	0f 85 c3 34 00 00    	jne    12702bc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x612c>
 126cdf9:	31 c0                	xor    %eax,%eax
 126cdfb:	41 f6 c1 01          	test   $0x1,%r9b
 126cdff:	4d 89 f2             	mov    %r14,%r10
 126ce02:	74 3c                	je     126ce40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2cb0>
 126ce04:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126ce0b:	47 0f b6 84 0d 10 01 	movzbl 0x110(%r13,%r9,1),%r8d
 126ce12:	00 00 
 126ce14:	41 80 e0 0f          	and    $0xf,%r8b
 126ce18:	41 80 f8 07          	cmp    $0x7,%r8b
 126ce1c:	75 22                	jne    126ce40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2cb0>
 126ce1e:	4d 01 cd             	add    %r9,%r13
 126ce21:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 126ce26:	74 18                	je     126ce40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2cb0>
 126ce28:	49 39 55 38          	cmp    %rdx,0x38(%r13)
 126ce2c:	75 12                	jne    126ce40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2cb0>
 126ce2e:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126ce35:	00 
 126ce36:	75 08                	jne    126ce40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2cb0>
 126ce38:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126ce3f:	00 
 126ce40:	48 85 d2             	test   %rdx,%rdx
 126ce43:	74 0a                	je     126ce4f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2cbf>
 126ce45:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126ce49:	31 c9                	xor    %ecx,%ecx
 126ce4b:	41 ff 52 18          	call   *0x18(%r10)
 126ce4f:	c5 fc 10 85 f0 ef ff 	vmovups -0x1010(%rbp),%ymm0
 126ce56:	ff 
 126ce57:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126ce5e:	ff 
 126ce5f:	c5 fc 10 85 80 ef ff 	vmovups -0x1080(%rbp),%ymm0
 126ce66:	ff 
 126ce67:	c5 fc 10 8d a0 ef ff 	vmovups -0x1060(%rbp),%ymm1
 126ce6e:	ff 
 126ce6f:	c5 fc 10 95 c0 ef ff 	vmovups -0x1040(%rbp),%ymm2
 126ce76:	ff 
 126ce77:	c5 fc 10 9d e0 ef ff 	vmovups -0x1020(%rbp),%ymm3
 126ce7e:	ff 
 126ce7f:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126ce86:	ff 
 126ce87:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126ce8e:	ff 
 126ce8f:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126ce96:	ff 
 126ce97:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126ce9e:	ff 
 126ce9f:	e9 60 07 00 00       	jmp    126d604 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3474>
 126cea4:	48 85 f6             	test   %rsi,%rsi
 126cea7:	74 51                	je     126cefa <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d6a>
 126cea9:	48 83 fe 01          	cmp    $0x1,%rsi
 126cead:	0f 85 69 2f 00 00    	jne    126fe1c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c8c>
 126ceb3:	31 c0                	xor    %eax,%eax
 126ceb5:	40 f6 c6 01          	test   $0x1,%sil
 126ceb9:	74 3f                	je     126cefa <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d6a>
 126cebb:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126cec2:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126cec9:	00 00 
 126cecb:	41 80 e0 0f          	and    $0xf,%r8b
 126cecf:	41 80 f8 07          	cmp    $0x7,%r8b
 126ced3:	75 25                	jne    126cefa <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d6a>
 126ced5:	48 01 f2             	add    %rsi,%rdx
 126ced8:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126cedc:	74 1c                	je     126cefa <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d6a>
 126cede:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 126cee2:	75 16                	jne    126cefa <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d6a>
 126cee4:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126cee8:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126ceef:	00 
 126cef0:	75 08                	jne    126cefa <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d6a>
 126cef2:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126cef9:	00 
 126cefa:	4d 85 e4             	test   %r12,%r12
 126cefd:	74 11                	je     126cf10 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d80>
 126ceff:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126cf03:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126cf07:	4c 89 e2             	mov    %r12,%rdx
 126cf0a:	31 c9                	xor    %ecx,%ecx
 126cf0c:	41 ff 51 18          	call   *0x18(%r9)
 126cf10:	4c 89 7d d0          	mov    %r15,-0x30(%rbp)
 126cf14:	49 89 dc             	mov    %rbx,%r12
 126cf17:	80 bd 68 de ff ff 00 	cmpb   $0x0,-0x2198(%rbp)
 126cf1e:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126cf22:	0f 84 c5 fa ff ff    	je     126c9ed <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x285d>
 126cf28:	48 8b 85 60 de ff ff 	mov    -0x21a0(%rbp),%rax
 126cf2f:	48 89 85 00 d8 ff ff 	mov    %rax,-0x2800(%rbp)
 126cf36:	c5 fc 10 85 00 de ff 	vmovups -0x2200(%rbp),%ymm0
 126cf3d:	ff 
 126cf3e:	c5 fc 10 8d 20 de ff 	vmovups -0x21e0(%rbp),%ymm1
 126cf45:	ff 
 126cf46:	c5 fc 10 95 40 de ff 	vmovups -0x21c0(%rbp),%ymm2
 126cf4d:	ff 
 126cf4e:	c5 fc 11 95 e0 d7 ff 	vmovups %ymm2,-0x2820(%rbp)
 126cf55:	ff 
 126cf56:	c5 fc 11 8d c0 d7 ff 	vmovups %ymm1,-0x2840(%rbp)
 126cf5d:	ff 
 126cf5e:	c5 fc 11 85 a0 d7 ff 	vmovups %ymm0,-0x2860(%rbp)
 126cf65:	ff 
 126cf66:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126cf6d:	ff 
 126cf6e:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126cf75:	ff 
 126cf76:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126cf7d:	ff 
 126cf7e:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126cf85:	ff 
 126cf86:	c5 fc 11 85 30 f1 ff 	vmovups %ymm0,-0xed0(%rbp)
 126cf8d:	ff 
 126cf8e:	c5 fc 11 8d 50 f1 ff 	vmovups %ymm1,-0xeb0(%rbp)
 126cf95:	ff 
 126cf96:	c5 fc 11 95 70 f1 ff 	vmovups %ymm2,-0xe90(%rbp)
 126cf9d:	ff 
 126cf9e:	c5 fc 11 9d 90 f1 ff 	vmovups %ymm3,-0xe70(%rbp)
 126cfa5:	ff 
 126cfa6:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126cfad:	ff 
 126cfae:	c5 fc 11 85 a0 f1 ff 	vmovups %ymm0,-0xe60(%rbp)
 126cfb5:	ff 
 126cfb6:	c6 85 08 d8 ff ff 01 	movb   $0x1,-0x27f8(%rbp)
 126cfbd:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126cfc1:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126cfc6:	48 8d 85 a0 d7 ff ff 	lea    -0x2860(%rbp),%rax
 126cfcd:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126cfd2:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126cfd6:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126cfdc:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126cfe0:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126cfe5:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126cfe9:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126cfee:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126cff2:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126cff7:	48 8d 85 30 f1 ff ff 	lea    -0xed0(%rbp),%rax
 126cffe:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126d003:	4c 89 3c 24          	mov    %r15,(%rsp)
 126d007:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126d00e:	00 00 
 126d010:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126d017:	00 00 
 126d019:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126d020:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 126d027:	4c 89 ee             	mov    %r13,%rsi
 126d02a:	4c 89 f2             	mov    %r14,%rdx
 126d02d:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126d034:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126d038:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126d03c:	c5 f8 77             	vzeroupper 
 126d03f:	e8 3c 5b 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126d044:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126d048:	48 85 db             	test   %rbx,%rbx
 126d04b:	0f 85 ce 49 00 00    	jne    1271a1f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x788f>
 126d051:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126d058:	48 8b 5d 80          	mov    -0x80(%rbp),%rbx
 126d05c:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126d063:	48 89 75 b0          	mov    %rsi,-0x50(%rbp)
 126d067:	48 89 da             	mov    %rbx,%rdx
 126d06a:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 126d06e:	4d 89 e0             	mov    %r12,%r8
 126d071:	e8 6a 0f fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126d076:	49 8b 4d 10          	mov    0x10(%r13),%rcx
 126d07a:	49 8b 3e             	mov    (%r14),%rdi
 126d07d:	4d 8b 4e 08          	mov    0x8(%r14),%r9
 126d081:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126d085:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126d08c:	a8 01                	test   $0x1,%al
 126d08e:	0f 84 d2 00 00 00    	je     126d166 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2fd6>
 126d094:	48 85 f6             	test   %rsi,%rsi
 126d097:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126d09b:	74 51                	je     126d0ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2f5e>
 126d09d:	48 83 fe 01          	cmp    $0x1,%rsi
 126d0a1:	0f 85 1d 2e 00 00    	jne    126fec4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5d34>
 126d0a7:	31 c0                	xor    %eax,%eax
 126d0a9:	40 f6 c6 01          	test   $0x1,%sil
 126d0ad:	74 3f                	je     126d0ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2f5e>
 126d0af:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126d0b6:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126d0bd:	00 00 
 126d0bf:	41 80 e0 0f          	and    $0xf,%r8b
 126d0c3:	41 80 f8 07          	cmp    $0x7,%r8b
 126d0c7:	75 25                	jne    126d0ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2f5e>
 126d0c9:	48 01 f2             	add    %rsi,%rdx
 126d0cc:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126d0d0:	74 1c                	je     126d0ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2f5e>
 126d0d2:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 126d0d6:	75 16                	jne    126d0ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2f5e>
 126d0d8:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126d0dc:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126d0e3:	00 
 126d0e4:	75 08                	jne    126d0ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2f5e>
 126d0e6:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126d0ed:	00 
 126d0ee:	4d 85 e4             	test   %r12,%r12
 126d0f1:	74 11                	je     126d104 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2f74>
 126d0f3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126d0f7:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126d0fb:	4c 89 e2             	mov    %r12,%rdx
 126d0fe:	31 c9                	xor    %ecx,%ecx
 126d100:	41 ff 51 18          	call   *0x18(%r9)
 126d104:	c5 fc 10 85 a0 f1 ff 	vmovups -0xe60(%rbp),%ymm0
 126d10b:	ff 
 126d10c:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126d113:	ff 
 126d114:	c5 fc 10 85 30 f1 ff 	vmovups -0xed0(%rbp),%ymm0
 126d11b:	ff 
 126d11c:	c5 fc 10 8d 50 f1 ff 	vmovups -0xeb0(%rbp),%ymm1
 126d123:	ff 
 126d124:	c5 fc 10 95 70 f1 ff 	vmovups -0xe90(%rbp),%ymm2
 126d12b:	ff 
 126d12c:	c5 fc 10 9d 90 f1 ff 	vmovups -0xe70(%rbp),%ymm3
 126d133:	ff 
 126d134:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126d13b:	ff 
 126d13c:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126d143:	ff 
 126d144:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126d14b:	ff 
 126d14c:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126d153:	ff 
 126d154:	80 bd d8 de ff ff 00 	cmpb   $0x0,-0x2128(%rbp)
 126d15b:	0f 85 a8 f8 ff ff    	jne    126ca09 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2879>
 126d161:	e9 88 00 00 00       	jmp    126d1ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x305e>
 126d166:	48 85 f6             	test   %rsi,%rsi
 126d169:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126d16d:	74 51                	je     126d1c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3030>
 126d16f:	48 83 fe 01          	cmp    $0x1,%rsi
 126d173:	0f 85 fb 2d 00 00    	jne    126ff74 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5de4>
 126d179:	31 c0                	xor    %eax,%eax
 126d17b:	40 f6 c6 01          	test   $0x1,%sil
 126d17f:	74 3f                	je     126d1c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3030>
 126d181:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126d188:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126d18f:	00 00 
 126d191:	41 80 e0 0f          	and    $0xf,%r8b
 126d195:	41 80 f8 07          	cmp    $0x7,%r8b
 126d199:	75 25                	jne    126d1c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3030>
 126d19b:	48 01 f2             	add    %rsi,%rdx
 126d19e:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126d1a2:	74 1c                	je     126d1c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3030>
 126d1a4:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126d1a8:	75 16                	jne    126d1c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3030>
 126d1aa:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 126d1ae:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126d1b5:	00 
 126d1b6:	75 08                	jne    126d1c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3030>
 126d1b8:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126d1bf:	00 
 126d1c0:	48 85 db             	test   %rbx,%rbx
 126d1c3:	74 11                	je     126d1d6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3046>
 126d1c5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126d1c9:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 126d1cd:	48 89 da             	mov    %rbx,%rdx
 126d1d0:	31 c9                	xor    %ecx,%ecx
 126d1d2:	41 ff 51 18          	call   *0x18(%r9)
 126d1d6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 126d1da:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 126d1de:	4c 89 e3             	mov    %r12,%rbx
 126d1e1:	80 bd d8 de ff ff 00 	cmpb   $0x0,-0x2128(%rbp)
 126d1e8:	0f 85 1b f8 ff ff    	jne    126ca09 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2879>
 126d1ee:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 126d1f2:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 126d1f6:	49 89 dc             	mov    %rbx,%r12
 126d1f9:	80 bd 48 df ff ff 00 	cmpb   $0x0,-0x20b8(%rbp)
 126d200:	0f 84 42 fa ff ff    	je     126cc48 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2ab8>
 126d206:	48 8b 85 40 df ff ff 	mov    -0x20c0(%rbp),%rax
 126d20d:	48 89 85 20 d7 ff ff 	mov    %rax,-0x28e0(%rbp)
 126d214:	c5 fc 10 85 e0 de ff 	vmovups -0x2120(%rbp),%ymm0
 126d21b:	ff 
 126d21c:	c5 fc 10 8d 00 df ff 	vmovups -0x2100(%rbp),%ymm1
 126d223:	ff 
 126d224:	c5 fc 10 95 20 df ff 	vmovups -0x20e0(%rbp),%ymm2
 126d22b:	ff 
 126d22c:	c5 fc 11 95 00 d7 ff 	vmovups %ymm2,-0x2900(%rbp)
 126d233:	ff 
 126d234:	c5 fc 11 8d e0 d6 ff 	vmovups %ymm1,-0x2920(%rbp)
 126d23b:	ff 
 126d23c:	c5 fc 11 85 c0 d6 ff 	vmovups %ymm0,-0x2940(%rbp)
 126d243:	ff 
 126d244:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126d24b:	ff 
 126d24c:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126d253:	ff 
 126d254:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126d25b:	ff 
 126d25c:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126d263:	ff 
 126d264:	c5 fc 11 85 10 f0 ff 	vmovups %ymm0,-0xff0(%rbp)
 126d26b:	ff 
 126d26c:	c5 fc 11 8d 30 f0 ff 	vmovups %ymm1,-0xfd0(%rbp)
 126d273:	ff 
 126d274:	c5 fc 11 95 50 f0 ff 	vmovups %ymm2,-0xfb0(%rbp)
 126d27b:	ff 
 126d27c:	c5 fc 11 9d 70 f0 ff 	vmovups %ymm3,-0xf90(%rbp)
 126d283:	ff 
 126d284:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126d28b:	ff 
 126d28c:	c5 fc 11 85 80 f0 ff 	vmovups %ymm0,-0xf80(%rbp)
 126d293:	ff 
 126d294:	c6 85 28 d7 ff ff 01 	movb   $0x1,-0x28d8(%rbp)
 126d29b:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 126d29f:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126d2a4:	48 8d 85 c0 d6 ff ff 	lea    -0x2940(%rbp),%rax
 126d2ab:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126d2b0:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126d2b4:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126d2ba:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126d2be:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126d2c3:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126d2c7:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126d2cc:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126d2d0:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126d2d5:	48 8d 85 10 f0 ff ff 	lea    -0xff0(%rbp),%rax
 126d2dc:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126d2e1:	4c 89 3c 24          	mov    %r15,(%rsp)
 126d2e5:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126d2ec:	00 00 
 126d2ee:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126d2f5:	00 00 
 126d2f7:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126d2fe:	4c 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%r14
 126d305:	4c 89 f6             	mov    %r14,%rsi
 126d308:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 126d30c:	4c 89 fa             	mov    %r15,%rdx
 126d30f:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126d316:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126d31a:	4d 89 e9             	mov    %r13,%r9
 126d31d:	c5 f8 77             	vzeroupper 
 126d320:	e8 5b 58 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126d325:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126d329:	48 85 db             	test   %rbx,%rbx
 126d32c:	0f 85 c6 48 00 00    	jne    1271bf8 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7a68>
 126d332:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126d339:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 126d33d:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126d344:	49 89 f5             	mov    %rsi,%r13
 126d347:	48 89 55 b0          	mov    %rdx,-0x50(%rbp)
 126d34b:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 126d34f:	4d 89 e0             	mov    %r12,%r8
 126d352:	49 89 cc             	mov    %rcx,%r12
 126d355:	4c 89 c3             	mov    %r8,%rbx
 126d358:	e8 83 0c fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126d35d:	49 8b 4e 10          	mov    0x10(%r14),%rcx
 126d361:	49 8b 3f             	mov    (%r15),%rdi
 126d364:	4d 8b 57 08          	mov    0x8(%r15),%r10
 126d368:	4c 8d 41 20          	lea    0x20(%rcx),%r8
 126d36c:	4c 8b 89 20 30 02 00 	mov    0x23020(%rcx),%r9
 126d373:	a8 01                	test   $0x1,%al
 126d375:	0f 84 77 01 00 00    	je     126d4f2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3362>
 126d37b:	4d 85 c9             	test   %r9,%r9
 126d37e:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126d382:	4d 89 ee             	mov    %r13,%r14
 126d385:	4c 89 e6             	mov    %r12,%rsi
 126d388:	48 89 da             	mov    %rbx,%rdx
 126d38b:	4c 8b 6d b0          	mov    -0x50(%rbp),%r13
 126d38f:	74 59                	je     126d3ea <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x325a>
 126d391:	4d 89 c4             	mov    %r8,%r12
 126d394:	4c 89 d3             	mov    %r10,%rbx
 126d397:	49 83 f9 01          	cmp    $0x1,%r9
 126d39b:	0f 85 d3 2d 00 00    	jne    1270174 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5fe4>
 126d3a1:	31 c0                	xor    %eax,%eax
 126d3a3:	41 f6 c1 01          	test   $0x1,%r9b
 126d3a7:	49 89 da             	mov    %rbx,%r10
 126d3aa:	74 3e                	je     126d3ea <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x325a>
 126d3ac:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126d3b3:	47 0f b6 84 0c 10 01 	movzbl 0x110(%r12,%r9,1),%r8d
 126d3ba:	00 00 
 126d3bc:	41 80 e0 0f          	and    $0xf,%r8b
 126d3c0:	41 80 f8 07          	cmp    $0x7,%r8b
 126d3c4:	75 24                	jne    126d3ea <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x325a>
 126d3c6:	4d 01 cc             	add    %r9,%r12
 126d3c9:	41 80 7c 24 40 00    	cmpb   $0x0,0x40(%r12)
 126d3cf:	74 19                	je     126d3ea <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x325a>
 126d3d1:	49 39 54 24 38       	cmp    %rdx,0x38(%r12)
 126d3d6:	75 12                	jne    126d3ea <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x325a>
 126d3d8:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126d3df:	00 
 126d3e0:	75 08                	jne    126d3ea <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x325a>
 126d3e2:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126d3e9:	00 
 126d3ea:	48 85 d2             	test   %rdx,%rdx
 126d3ed:	74 0a                	je     126d3f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3269>
 126d3ef:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126d3f3:	31 c9                	xor    %ecx,%ecx
 126d3f5:	41 ff 52 18          	call   *0x18(%r10)
 126d3f9:	c5 fc 10 85 80 f0 ff 	vmovups -0xf80(%rbp),%ymm0
 126d400:	ff 
 126d401:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126d408:	ff 
 126d409:	c5 fc 10 85 10 f0 ff 	vmovups -0xff0(%rbp),%ymm0
 126d410:	ff 
 126d411:	c5 fc 10 8d 30 f0 ff 	vmovups -0xfd0(%rbp),%ymm1
 126d418:	ff 
 126d419:	c5 fc 10 95 50 f0 ff 	vmovups -0xfb0(%rbp),%ymm2
 126d420:	ff 
 126d421:	c5 fc 10 9d 70 f0 ff 	vmovups -0xf90(%rbp),%ymm3
 126d428:	ff 
 126d429:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126d430:	ff 
 126d431:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126d438:	ff 
 126d439:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126d440:	ff 
 126d441:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126d448:	ff 
 126d449:	80 bd b8 df ff ff 00 	cmpb   $0x0,-0x2048(%rbp)
 126d450:	4c 8b 65 b8          	mov    -0x48(%rbp),%r12
 126d454:	0f 85 06 f8 ff ff    	jne    126cc60 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2ad0>
 126d45a:	4d 89 f4             	mov    %r14,%r12
 126d45d:	4c 89 eb             	mov    %r13,%rbx
 126d460:	e9 9f 01 00 00       	jmp    126d604 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3474>
 126d465:	48 85 f6             	test   %rsi,%rsi
 126d468:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126d46c:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126d470:	74 51                	je     126d4c3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3333>
 126d472:	48 83 fe 01          	cmp    $0x1,%rsi
 126d476:	0f 85 50 2c 00 00    	jne    12700cc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f3c>
 126d47c:	31 c0                	xor    %eax,%eax
 126d47e:	40 f6 c6 01          	test   $0x1,%sil
 126d482:	74 3f                	je     126d4c3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3333>
 126d484:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126d48b:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126d492:	00 00 
 126d494:	41 80 e0 0f          	and    $0xf,%r8b
 126d498:	41 80 f8 07          	cmp    $0x7,%r8b
 126d49c:	75 25                	jne    126d4c3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3333>
 126d49e:	48 01 f2             	add    %rsi,%rdx
 126d4a1:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126d4a5:	74 1c                	je     126d4c3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3333>
 126d4a7:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 126d4ab:	75 16                	jne    126d4c3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3333>
 126d4ad:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 126d4b1:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126d4b8:	00 
 126d4b9:	75 08                	jne    126d4c3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3333>
 126d4bb:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126d4c2:	00 
 126d4c3:	4d 85 e4             	test   %r12,%r12
 126d4c6:	74 11                	je     126d4d9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3349>
 126d4c8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126d4cc:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126d4d0:	4c 89 e2             	mov    %r12,%rdx
 126d4d3:	31 c9                	xor    %ecx,%ecx
 126d4d5:	41 ff 51 18          	call   *0x18(%r9)
 126d4d9:	4c 89 75 d0          	mov    %r14,-0x30(%rbp)
 126d4dd:	49 89 dc             	mov    %rbx,%r12
 126d4e0:	80 bd 48 df ff ff 00 	cmpb   $0x0,-0x20b8(%rbp)
 126d4e7:	0f 85 19 fd ff ff    	jne    126d206 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3076>
 126d4ed:	e9 56 f7 ff ff       	jmp    126cc48 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2ab8>
 126d4f2:	4d 85 c9             	test   %r9,%r9
 126d4f5:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126d4f9:	4c 89 ee             	mov    %r13,%rsi
 126d4fc:	4d 89 e6             	mov    %r12,%r14
 126d4ff:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 126d503:	74 57                	je     126d55c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x33cc>
 126d505:	4d 89 c5             	mov    %r8,%r13
 126d508:	4d 89 d4             	mov    %r10,%r12
 126d50b:	49 83 f9 01          	cmp    $0x1,%r9
 126d50f:	0f 85 07 2d 00 00    	jne    127021c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x608c>
 126d515:	31 c0                	xor    %eax,%eax
 126d517:	41 f6 c1 01          	test   $0x1,%r9b
 126d51b:	4d 89 e2             	mov    %r12,%r10
 126d51e:	74 3c                	je     126d55c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x33cc>
 126d520:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126d527:	47 0f b6 84 0d 10 01 	movzbl 0x110(%r13,%r9,1),%r8d
 126d52e:	00 00 
 126d530:	41 80 e0 0f          	and    $0xf,%r8b
 126d534:	41 80 f8 07          	cmp    $0x7,%r8b
 126d538:	75 22                	jne    126d55c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x33cc>
 126d53a:	4d 01 cd             	add    %r9,%r13
 126d53d:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 126d542:	74 18                	je     126d55c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x33cc>
 126d544:	49 39 55 38          	cmp    %rdx,0x38(%r13)
 126d548:	75 12                	jne    126d55c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x33cc>
 126d54a:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126d551:	00 
 126d552:	75 08                	jne    126d55c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x33cc>
 126d554:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126d55b:	00 
 126d55c:	48 85 d2             	test   %rdx,%rdx
 126d55f:	0f 84 37 20 00 00    	je     126f59c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x540c>
 126d565:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126d569:	31 c9                	xor    %ecx,%ecx
 126d56b:	41 ff 52 18          	call   *0x18(%r10)
 126d56f:	49 89 dd             	mov    %rbx,%r13
 126d572:	80 bd b8 df ff ff 00 	cmpb   $0x0,-0x2048(%rbp)
 126d579:	4c 8b 65 b8          	mov    -0x48(%rbp),%r12
 126d57d:	0f 85 dd f6 ff ff    	jne    126cc60 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2ad0>
 126d583:	e9 d2 fe ff ff       	jmp    126d45a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x32ca>
 126d588:	4d 85 c9             	test   %r9,%r9
 126d58b:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126d58f:	48 89 de             	mov    %rbx,%rsi
 126d592:	4d 89 ec             	mov    %r13,%r12
 126d595:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 126d599:	74 57                	je     126d5f2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3462>
 126d59b:	4d 89 c5             	mov    %r8,%r13
 126d59e:	4c 89 d3             	mov    %r10,%rbx
 126d5a1:	49 83 f9 01          	cmp    $0x1,%r9
 126d5a5:	0f 85 b1 2d 00 00    	jne    127035c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x61cc>
 126d5ab:	31 c0                	xor    %eax,%eax
 126d5ad:	41 f6 c1 01          	test   $0x1,%r9b
 126d5b1:	49 89 da             	mov    %rbx,%r10
 126d5b4:	74 3c                	je     126d5f2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3462>
 126d5b6:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126d5bd:	47 0f b6 84 0d 10 01 	movzbl 0x110(%r13,%r9,1),%r8d
 126d5c4:	00 00 
 126d5c6:	41 80 e0 0f          	and    $0xf,%r8b
 126d5ca:	41 80 f8 07          	cmp    $0x7,%r8b
 126d5ce:	75 22                	jne    126d5f2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3462>
 126d5d0:	4d 01 cd             	add    %r9,%r13
 126d5d3:	41 80 7d 40 00       	cmpb   $0x0,0x40(%r13)
 126d5d8:	74 18                	je     126d5f2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3462>
 126d5da:	49 39 55 38          	cmp    %rdx,0x38(%r13)
 126d5de:	75 12                	jne    126d5f2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3462>
 126d5e0:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126d5e7:	00 
 126d5e8:	75 08                	jne    126d5f2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3462>
 126d5ea:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126d5f1:	00 
 126d5f2:	48 85 d2             	test   %rdx,%rdx
 126d5f5:	74 0a                	je     126d601 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3471>
 126d5f7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126d5fb:	31 c9                	xor    %ecx,%ecx
 126d5fd:	41 ff 52 18          	call   *0x18(%r10)
 126d601:	4c 89 f3             	mov    %r14,%rbx
 126d604:	80 bd f0 fc ff ff 00 	cmpb   $0x0,-0x310(%rbp)
 126d60b:	0f 94 c0             	sete   %al
 126d60e:	80 bd 73 ff ff ff 00 	cmpb   $0x0,-0x8d(%rbp)
 126d615:	0f 94 c1             	sete   %cl
 126d618:	08 c1                	or     %al,%cl
 126d61a:	74 08                	je     126d624 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3494>
 126d61c:	49 89 dd             	mov    %rbx,%r13
 126d61f:	e9 4a 03 00 00       	jmp    126d96e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x37de>
 126d624:	48 8b 85 30 f7 ff ff 	mov    -0x8d0(%rbp),%rax
 126d62b:	48 89 85 40 d6 ff ff 	mov    %rax,-0x29c0(%rbp)
 126d632:	c5 fc 10 85 d0 f6 ff 	vmovups -0x930(%rbp),%ymm0
 126d639:	ff 
 126d63a:	c5 fc 10 8d f0 f6 ff 	vmovups -0x910(%rbp),%ymm1
 126d641:	ff 
 126d642:	c5 fc 10 95 10 f7 ff 	vmovups -0x8f0(%rbp),%ymm2
 126d649:	ff 
 126d64a:	c5 fc 11 95 20 d6 ff 	vmovups %ymm2,-0x29e0(%rbp)
 126d651:	ff 
 126d652:	c5 fc 11 8d 00 d6 ff 	vmovups %ymm1,-0x2a00(%rbp)
 126d659:	ff 
 126d65a:	c5 fc 11 85 e0 d5 ff 	vmovups %ymm0,-0x2a20(%rbp)
 126d661:	ff 
 126d662:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126d669:	ff 
 126d66a:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126d671:	ff 
 126d672:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126d679:	ff 
 126d67a:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126d681:	ff 
 126d682:	c5 fc 11 85 f0 ee ff 	vmovups %ymm0,-0x1110(%rbp)
 126d689:	ff 
 126d68a:	c5 fc 11 8d 10 ef ff 	vmovups %ymm1,-0x10f0(%rbp)
 126d691:	ff 
 126d692:	c5 fc 11 95 30 ef ff 	vmovups %ymm2,-0x10d0(%rbp)
 126d699:	ff 
 126d69a:	c5 fc 11 9d 50 ef ff 	vmovups %ymm3,-0x10b0(%rbp)
 126d6a1:	ff 
 126d6a2:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126d6a9:	ff 
 126d6aa:	c5 fc 11 85 60 ef ff 	vmovups %ymm0,-0x10a0(%rbp)
 126d6b1:	ff 
 126d6b2:	c6 85 48 d6 ff ff 01 	movb   $0x1,-0x29b8(%rbp)
 126d6b9:	48 8d 85 e0 d5 ff ff 	lea    -0x2a20(%rbp),%rax
 126d6c0:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126d6c5:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126d6cc:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126d6d1:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126d6d5:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126d6db:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126d6df:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126d6e4:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126d6e8:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126d6ed:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126d6f1:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126d6f6:	48 8d 85 f0 ee ff ff 	lea    -0x1110(%rbp),%rax
 126d6fd:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126d702:	4c 89 3c 24          	mov    %r15,(%rsp)
 126d706:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126d70d:	00 00 
 126d70f:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126d716:	00 00 
 126d718:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126d71f:	4c 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%r14
 126d726:	4c 89 f6             	mov    %r14,%rsi
 126d729:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 126d72d:	4c 89 fa             	mov    %r15,%rdx
 126d730:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126d737:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126d73b:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126d73f:	c5 f8 77             	vzeroupper 
 126d742:	e8 39 54 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126d747:	44 0f b7 6d 88       	movzwl -0x78(%rbp),%r13d
 126d74c:	4d 85 ed             	test   %r13,%r13
 126d74f:	0f 85 42 4d 00 00    	jne    1272497 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8307>
 126d755:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126d75c:	48 8b 55 80          	mov    -0x80(%rbp),%rdx
 126d760:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126d767:	4c 89 e1             	mov    %r12,%rcx
 126d76a:	49 89 f4             	mov    %rsi,%r12
 126d76d:	49 89 d8             	mov    %rbx,%r8
 126d770:	48 89 55 c8          	mov    %rdx,-0x38(%rbp)
 126d774:	49 89 cd             	mov    %rcx,%r13
 126d777:	e8 64 08 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126d77c:	49 8b 4e 10          	mov    0x10(%r14),%rcx
 126d780:	49 8b 3f             	mov    (%r15),%rdi
 126d783:	4d 8b 57 08          	mov    0x8(%r15),%r10
 126d787:	4c 8d 79 20          	lea    0x20(%rcx),%r15
 126d78b:	4c 8b 89 20 30 02 00 	mov    0x23020(%rcx),%r9
 126d792:	a8 01                	test   $0x1,%al
 126d794:	0f 84 5f 01 00 00    	je     126d8f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3769>
 126d79a:	4d 85 c9             	test   %r9,%r9
 126d79d:	4c 89 ee             	mov    %r13,%rsi
 126d7a0:	4c 8b 6d c8          	mov    -0x38(%rbp),%r13
 126d7a4:	48 89 da             	mov    %rbx,%rdx
 126d7a7:	74 54                	je     126d7fd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x366d>
 126d7a9:	4c 89 d3             	mov    %r10,%rbx
 126d7ac:	49 83 f9 01          	cmp    $0x1,%r9
 126d7b0:	0f 85 7e 35 00 00    	jne    1270d34 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6ba4>
 126d7b6:	31 c0                	xor    %eax,%eax
 126d7b8:	41 f6 c1 01          	test   $0x1,%r9b
 126d7bc:	49 89 da             	mov    %rbx,%r10
 126d7bf:	74 3c                	je     126d7fd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x366d>
 126d7c1:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126d7c8:	47 0f b6 84 0f 10 01 	movzbl 0x110(%r15,%r9,1),%r8d
 126d7cf:	00 00 
 126d7d1:	41 80 e0 0f          	and    $0xf,%r8b
 126d7d5:	41 80 f8 07          	cmp    $0x7,%r8b
 126d7d9:	75 22                	jne    126d7fd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x366d>
 126d7db:	4d 01 cf             	add    %r9,%r15
 126d7de:	41 80 7f 40 00       	cmpb   $0x0,0x40(%r15)
 126d7e3:	74 18                	je     126d7fd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x366d>
 126d7e5:	49 39 57 38          	cmp    %rdx,0x38(%r15)
 126d7e9:	75 12                	jne    126d7fd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x366d>
 126d7eb:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126d7f2:	00 
 126d7f3:	75 08                	jne    126d7fd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x366d>
 126d7f5:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126d7fc:	00 
 126d7fd:	48 85 d2             	test   %rdx,%rdx
 126d800:	74 0a                	je     126d80c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x367c>
 126d802:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126d806:	31 c9                	xor    %ecx,%ecx
 126d808:	41 ff 52 18          	call   *0x18(%r10)
 126d80c:	c5 fc 10 85 60 ef ff 	vmovups -0x10a0(%rbp),%ymm0
 126d813:	ff 
 126d814:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126d81b:	ff 
 126d81c:	c5 fc 10 85 f0 ee ff 	vmovups -0x1110(%rbp),%ymm0
 126d823:	ff 
 126d824:	c5 fc 10 8d 10 ef ff 	vmovups -0x10f0(%rbp),%ymm1
 126d82b:	ff 
 126d82c:	c5 fc 10 95 30 ef ff 	vmovups -0x10d0(%rbp),%ymm2
 126d833:	ff 
 126d834:	c5 fc 10 9d 50 ef ff 	vmovups -0x10b0(%rbp),%ymm3
 126d83b:	ff 
 126d83c:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126d843:	ff 
 126d844:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126d84b:	ff 
 126d84c:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126d853:	ff 
 126d854:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126d85b:	ff 
 126d85c:	e9 0d 01 00 00       	jmp    126d96e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x37de>
 126d861:	4d 85 ff             	test   %r15,%r15
 126d864:	48 8b 5d 10          	mov    0x10(%rbp),%rbx
 126d868:	4c 8b 65 b0          	mov    -0x50(%rbp),%r12
 126d86c:	4c 89 f2             	mov    %r14,%rdx
 126d86f:	74 58                	je     126d8c9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3739>
 126d871:	4d 89 de             	mov    %r11,%r14
 126d874:	49 83 ff 01          	cmp    $0x1,%r15
 126d878:	0f 85 0e 34 00 00    	jne    1270c8c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6afc>
 126d87e:	31 c0                	xor    %eax,%eax
 126d880:	41 f6 c7 01          	test   $0x1,%r15b
 126d884:	4d 89 f3             	mov    %r14,%r11
 126d887:	74 40                	je     126d8c9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3739>
 126d889:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126d890:	45 0f b6 84 31 10 01 	movzbl 0x110(%r9,%rsi,1),%r8d
 126d897:	00 00 
 126d899:	41 80 e0 0f          	and    $0xf,%r8b
 126d89d:	41 80 f8 07          	cmp    $0x7,%r8b
 126d8a1:	75 26                	jne    126d8c9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3739>
 126d8a3:	49 01 f1             	add    %rsi,%r9
 126d8a6:	41 80 79 40 00       	cmpb   $0x0,0x40(%r9)
 126d8ab:	74 1c                	je     126d8c9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3739>
 126d8ad:	49 39 51 38          	cmp    %rdx,0x38(%r9)
 126d8b1:	75 16                	jne    126d8c9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3739>
 126d8b3:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126d8b7:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126d8be:	00 
 126d8bf:	75 08                	jne    126d8c9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3739>
 126d8c1:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126d8c8:	00 
 126d8c9:	48 85 d2             	test   %rdx,%rdx
 126d8cc:	74 0e                	je     126d8dc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x374c>
 126d8ce:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126d8d2:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 126d8d6:	31 c9                	xor    %ecx,%ecx
 126d8d8:	41 ff 53 18          	call   *0x18(%r11)
 126d8dc:	4c 89 65 d0          	mov    %r12,-0x30(%rbp)
 126d8e0:	4d 89 ec             	mov    %r13,%r12
 126d8e3:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 126d8ea:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126d8ee:	0f 85 40 ec ff ff    	jne    126c534 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x23a4>
 126d8f4:	e9 0e ec ff ff       	jmp    126c507 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2377>
 126d8f9:	4d 85 c9             	test   %r9,%r9
 126d8fc:	4c 89 e6             	mov    %r12,%rsi
 126d8ff:	4d 89 ec             	mov    %r13,%r12
 126d902:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 126d906:	49 89 dd             	mov    %rbx,%r13
 126d909:	74 54                	je     126d95f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x37cf>
 126d90b:	4c 89 d3             	mov    %r10,%rbx
 126d90e:	49 83 f9 01          	cmp    $0x1,%r9
 126d912:	0f 85 c4 34 00 00    	jne    1270ddc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c4c>
 126d918:	31 c0                	xor    %eax,%eax
 126d91a:	41 f6 c1 01          	test   $0x1,%r9b
 126d91e:	49 89 da             	mov    %rbx,%r10
 126d921:	74 3c                	je     126d95f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x37cf>
 126d923:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 126d92a:	47 0f b6 84 0f 10 01 	movzbl 0x110(%r15,%r9,1),%r8d
 126d931:	00 00 
 126d933:	41 80 e0 0f          	and    $0xf,%r8b
 126d937:	41 80 f8 07          	cmp    $0x7,%r8b
 126d93b:	75 22                	jne    126d95f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x37cf>
 126d93d:	4d 01 cf             	add    %r9,%r15
 126d940:	41 80 7f 40 00       	cmpb   $0x0,0x40(%r15)
 126d945:	74 18                	je     126d95f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x37cf>
 126d947:	49 39 57 38          	cmp    %rdx,0x38(%r15)
 126d94b:	75 12                	jne    126d95f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x37cf>
 126d94d:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126d954:	00 
 126d955:	75 08                	jne    126d95f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x37cf>
 126d957:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126d95e:	00 
 126d95f:	48 85 d2             	test   %rdx,%rdx
 126d962:	74 0a                	je     126d96e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x37de>
 126d964:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126d968:	31 c9                	xor    %ecx,%ecx
 126d96a:	41 ff 52 18          	call   *0x18(%r10)
 126d96e:	80 bd 74 ff ff ff 00 	cmpb   $0x0,-0x8c(%rbp)
 126d975:	0f 84 38 02 00 00    	je     126dbb3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a23>
 126d97b:	4d 89 e7             	mov    %r12,%r15
 126d97e:	48 8b 85 a0 f7 ff ff 	mov    -0x860(%rbp),%rax
 126d985:	48 89 85 d0 d5 ff ff 	mov    %rax,-0x2a30(%rbp)
 126d98c:	c5 fc 10 85 40 f7 ff 	vmovups -0x8c0(%rbp),%ymm0
 126d993:	ff 
 126d994:	c5 fc 10 8d 60 f7 ff 	vmovups -0x8a0(%rbp),%ymm1
 126d99b:	ff 
 126d99c:	c5 fc 10 95 80 f7 ff 	vmovups -0x880(%rbp),%ymm2
 126d9a3:	ff 
 126d9a4:	c5 fc 11 95 b0 d5 ff 	vmovups %ymm2,-0x2a50(%rbp)
 126d9ab:	ff 
 126d9ac:	c5 fc 11 8d 90 d5 ff 	vmovups %ymm1,-0x2a70(%rbp)
 126d9b3:	ff 
 126d9b4:	c5 fc 11 85 70 d5 ff 	vmovups %ymm0,-0x2a90(%rbp)
 126d9bb:	ff 
 126d9bc:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126d9c3:	ff 
 126d9c4:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126d9cb:	ff 
 126d9cc:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126d9d3:	ff 
 126d9d4:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126d9db:	ff 
 126d9dc:	c5 fc 11 85 60 ee ff 	vmovups %ymm0,-0x11a0(%rbp)
 126d9e3:	ff 
 126d9e4:	c5 fc 11 8d 80 ee ff 	vmovups %ymm1,-0x1180(%rbp)
 126d9eb:	ff 
 126d9ec:	c5 fc 11 95 a0 ee ff 	vmovups %ymm2,-0x1160(%rbp)
 126d9f3:	ff 
 126d9f4:	c5 fc 11 9d c0 ee ff 	vmovups %ymm3,-0x1140(%rbp)
 126d9fb:	ff 
 126d9fc:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126da03:	ff 
 126da04:	c5 fc 11 85 d0 ee ff 	vmovups %ymm0,-0x1130(%rbp)
 126da0b:	ff 
 126da0c:	c6 85 d8 d5 ff ff 01 	movb   $0x1,-0x2a28(%rbp)
 126da13:	48 8d 85 70 d5 ff ff 	lea    -0x2a90(%rbp),%rax
 126da1a:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126da1f:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126da26:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126da2b:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126da2f:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126da35:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126da39:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126da3e:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126da42:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126da47:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126da4b:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126da50:	48 8d 85 60 ee ff ff 	lea    -0x11a0(%rbp),%rax
 126da57:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126da5c:	48 8b 45 10          	mov    0x10(%rbp),%rax
 126da60:	48 89 04 24          	mov    %rax,(%rsp)
 126da64:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126da6b:	00 00 
 126da6d:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126da74:	00 00 
 126da76:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126da7d:	4c 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%r14
 126da84:	4c 89 f6             	mov    %r14,%rsi
 126da87:	4c 8b 65 b8          	mov    -0x48(%rbp),%r12
 126da8b:	4c 89 e2             	mov    %r12,%rdx
 126da8e:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126da95:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126da99:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126da9d:	c5 f8 77             	vzeroupper 
 126daa0:	e8 db 50 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126daa5:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126daa9:	48 85 db             	test   %rbx,%rbx
 126daac:	0f 85 1d 43 00 00    	jne    1271dcf <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7c3f>
 126dab2:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126dab9:	48 8b 5d 80          	mov    -0x80(%rbp),%rbx
 126dabd:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126dac4:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 126dac8:	48 89 da             	mov    %rbx,%rdx
 126dacb:	4c 89 f9             	mov    %r15,%rcx
 126dace:	4d 89 e8             	mov    %r13,%r8
 126dad1:	e8 0a 05 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126dad6:	49 8b 4e 10          	mov    0x10(%r14),%rcx
 126dada:	49 8b 3c 24          	mov    (%r12),%rdi
 126dade:	4d 8b 4c 24 08       	mov    0x8(%r12),%r9
 126dae3:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126dae7:	4c 8b b1 20 30 02 00 	mov    0x23020(%rcx),%r14
 126daee:	a8 01                	test   $0x1,%al
 126daf0:	0f 84 c3 00 00 00    	je     126dbb9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a29>
 126daf6:	4d 85 f6             	test   %r14,%r14
 126daf9:	4c 89 fe             	mov    %r15,%rsi
 126dafc:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126db00:	74 4d                	je     126db4f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x39bf>
 126db02:	49 83 fe 01          	cmp    $0x1,%r14
 126db06:	0f 85 f0 28 00 00    	jne    12703fc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x626c>
 126db0c:	31 c0                	xor    %eax,%eax
 126db0e:	41 f6 c6 01          	test   $0x1,%r14b
 126db12:	74 3b                	je     126db4f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x39bf>
 126db14:	4c 69 d0 18 01 00 00 	imul   $0x118,%rax,%r10
 126db1b:	46 0f b6 84 12 10 01 	movzbl 0x110(%rdx,%r10,1),%r8d
 126db22:	00 00 
 126db24:	41 80 e0 0f          	and    $0xf,%r8b
 126db28:	41 80 f8 07          	cmp    $0x7,%r8b
 126db2c:	75 21                	jne    126db4f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x39bf>
 126db2e:	4c 01 d2             	add    %r10,%rdx
 126db31:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126db35:	74 18                	je     126db4f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x39bf>
 126db37:	4c 39 6a 38          	cmp    %r13,0x38(%rdx)
 126db3b:	75 12                	jne    126db4f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x39bf>
 126db3d:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126db44:	00 
 126db45:	75 08                	jne    126db4f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x39bf>
 126db47:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126db4e:	00 
 126db4f:	4d 85 ed             	test   %r13,%r13
 126db52:	74 0d                	je     126db61 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x39d1>
 126db54:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126db58:	4c 89 ea             	mov    %r13,%rdx
 126db5b:	31 c9                	xor    %ecx,%ecx
 126db5d:	41 ff 51 18          	call   *0x18(%r9)
 126db61:	c5 fc 10 85 d0 ee ff 	vmovups -0x1130(%rbp),%ymm0
 126db68:	ff 
 126db69:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126db70:	ff 
 126db71:	c5 fc 10 85 60 ee ff 	vmovups -0x11a0(%rbp),%ymm0
 126db78:	ff 
 126db79:	c5 fc 10 8d 80 ee ff 	vmovups -0x1180(%rbp),%ymm1
 126db80:	ff 
 126db81:	c5 fc 10 95 a0 ee ff 	vmovups -0x1160(%rbp),%ymm2
 126db88:	ff 
 126db89:	c5 fc 10 9d c0 ee ff 	vmovups -0x1140(%rbp),%ymm3
 126db90:	ff 
 126db91:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126db98:	ff 
 126db99:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126dba0:	ff 
 126dba1:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126dba8:	ff 
 126dba9:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126dbb0:	ff 
 126dbb1:	eb 7d                	jmp    126dc30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3aa0>
 126dbb3:	4c 89 65 c8          	mov    %r12,-0x38(%rbp)
 126dbb7:	eb 70                	jmp    126dc29 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a99>
 126dbb9:	4d 85 f6             	test   %r14,%r14
 126dbbc:	74 51                	je     126dc0f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a7f>
 126dbbe:	49 83 fe 01          	cmp    $0x1,%r14
 126dbc2:	0f 85 d4 28 00 00    	jne    127049c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x630c>
 126dbc8:	31 c0                	xor    %eax,%eax
 126dbca:	41 f6 c6 01          	test   $0x1,%r14b
 126dbce:	74 3f                	je     126dc0f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a7f>
 126dbd0:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126dbd7:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126dbde:	00 00 
 126dbe0:	41 80 e0 0f          	and    $0xf,%r8b
 126dbe4:	41 80 f8 07          	cmp    $0x7,%r8b
 126dbe8:	75 25                	jne    126dc0f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a7f>
 126dbea:	48 01 f2             	add    %rsi,%rdx
 126dbed:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126dbf1:	74 1c                	je     126dc0f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a7f>
 126dbf3:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126dbf7:	75 16                	jne    126dc0f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a7f>
 126dbf9:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 126dbfd:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126dc04:	00 
 126dc05:	75 08                	jne    126dc0f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a7f>
 126dc07:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126dc0e:	00 
 126dc0f:	48 85 db             	test   %rbx,%rbx
 126dc12:	74 11                	je     126dc25 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a95>
 126dc14:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126dc18:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 126dc1c:	48 89 da             	mov    %rbx,%rdx
 126dc1f:	31 c9                	xor    %ecx,%ecx
 126dc21:	41 ff 51 18          	call   *0x18(%r9)
 126dc25:	4c 89 7d c8          	mov    %r15,-0x38(%rbp)
 126dc29:	4c 89 eb             	mov    %r13,%rbx
 126dc2c:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126dc30:	80 bd 75 ff ff ff 00 	cmpb   $0x0,-0x8b(%rbp)
 126dc37:	4c 8b 6d b8          	mov    -0x48(%rbp),%r13
 126dc3b:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126dc3f:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126dc43:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126dc4a:	0f 84 ba 02 00 00    	je     126df0a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d7a>
 126dc50:	48 8b 85 10 f8 ff ff 	mov    -0x7f0(%rbp),%rax
 126dc57:	48 89 85 60 d5 ff ff 	mov    %rax,-0x2aa0(%rbp)
 126dc5e:	c5 fc 10 85 b0 f7 ff 	vmovups -0x850(%rbp),%ymm0
 126dc65:	ff 
 126dc66:	c5 fc 10 8d d0 f7 ff 	vmovups -0x830(%rbp),%ymm1
 126dc6d:	ff 
 126dc6e:	c5 fc 10 95 f0 f7 ff 	vmovups -0x810(%rbp),%ymm2
 126dc75:	ff 
 126dc76:	c5 fc 11 95 40 d5 ff 	vmovups %ymm2,-0x2ac0(%rbp)
 126dc7d:	ff 
 126dc7e:	c5 fc 11 8d 20 d5 ff 	vmovups %ymm1,-0x2ae0(%rbp)
 126dc85:	ff 
 126dc86:	c5 fc 11 85 00 d5 ff 	vmovups %ymm0,-0x2b00(%rbp)
 126dc8d:	ff 
 126dc8e:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126dc95:	ff 
 126dc96:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126dc9d:	ff 
 126dc9e:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126dca5:	ff 
 126dca6:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126dcad:	ff 
 126dcae:	c5 fc 11 85 d0 ed ff 	vmovups %ymm0,-0x1230(%rbp)
 126dcb5:	ff 
 126dcb6:	c5 fc 11 8d f0 ed ff 	vmovups %ymm1,-0x1210(%rbp)
 126dcbd:	ff 
 126dcbe:	c5 fc 11 95 10 ee ff 	vmovups %ymm2,-0x11f0(%rbp)
 126dcc5:	ff 
 126dcc6:	c5 fc 11 9d 30 ee ff 	vmovups %ymm3,-0x11d0(%rbp)
 126dccd:	ff 
 126dcce:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126dcd5:	ff 
 126dcd6:	c5 fc 11 85 40 ee ff 	vmovups %ymm0,-0x11c0(%rbp)
 126dcdd:	ff 
 126dcde:	c6 85 68 d5 ff ff 01 	movb   $0x1,-0x2a98(%rbp)
 126dce5:	48 8d 85 00 d5 ff ff 	lea    -0x2b00(%rbp),%rax
 126dcec:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126dcf1:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126dcf8:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126dcfd:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126dd01:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126dd07:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126dd0b:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126dd10:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126dd14:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126dd19:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126dd1d:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126dd22:	48 8d 85 d0 ed ff ff 	lea    -0x1230(%rbp),%rax
 126dd29:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126dd2e:	4c 89 3c 24          	mov    %r15,(%rsp)
 126dd32:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126dd39:	00 00 
 126dd3b:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126dd42:	00 00 
 126dd44:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126dd4b:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 126dd52:	4c 89 fe             	mov    %r15,%rsi
 126dd55:	4c 89 ea             	mov    %r13,%rdx
 126dd58:	c5 f8 77             	vzeroupper 
 126dd5b:	e8 20 4e 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126dd60:	44 0f b7 75 88       	movzwl -0x78(%rbp),%r14d
 126dd65:	4d 85 f6             	test   %r14,%r14
 126dd68:	0f 85 4f 41 00 00    	jne    1271ebd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7d2d>
 126dd6e:	4c 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%r14
 126dd75:	4c 8b 65 80          	mov    -0x80(%rbp),%r12
 126dd79:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126dd80:	4c 89 f6             	mov    %r14,%rsi
 126dd83:	4c 89 e2             	mov    %r12,%rdx
 126dd86:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 126dd8a:	49 89 d8             	mov    %rbx,%r8
 126dd8d:	e8 4e 02 fd ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126dd92:	49 8b 4f 10          	mov    0x10(%r15),%rcx
 126dd96:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 126dd9a:	4d 8b 4d 08          	mov    0x8(%r13),%r9
 126dd9e:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126dda2:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126dda9:	a8 01                	test   $0x1,%al
 126ddab:	0f 84 ee 00 00 00    	je     126de9f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d0f>
 126ddb1:	48 85 f6             	test   %rsi,%rsi
 126ddb4:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126ddb8:	74 51                	je     126de0b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3c7b>
 126ddba:	48 83 fe 01          	cmp    $0x1,%rsi
 126ddbe:	0f 85 80 27 00 00    	jne    1270544 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x63b4>
 126ddc4:	31 c0                	xor    %eax,%eax
 126ddc6:	40 f6 c6 01          	test   $0x1,%sil
 126ddca:	74 3f                	je     126de0b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3c7b>
 126ddcc:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126ddd3:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126ddda:	00 00 
 126dddc:	41 80 e0 0f          	and    $0xf,%r8b
 126dde0:	41 80 f8 07          	cmp    $0x7,%r8b
 126dde4:	75 25                	jne    126de0b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3c7b>
 126dde6:	48 01 f2             	add    %rsi,%rdx
 126dde9:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126dded:	74 1c                	je     126de0b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3c7b>
 126ddef:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126ddf3:	75 16                	jne    126de0b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3c7b>
 126ddf5:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 126ddf9:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126de00:	00 
 126de01:	75 08                	jne    126de0b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3c7b>
 126de03:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126de0a:	00 
 126de0b:	48 85 db             	test   %rbx,%rbx
 126de0e:	74 11                	je     126de21 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3c91>
 126de10:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126de14:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 126de18:	48 89 da             	mov    %rbx,%rdx
 126de1b:	31 c9                	xor    %ecx,%ecx
 126de1d:	41 ff 51 18          	call   *0x18(%r9)
 126de21:	c5 fc 10 85 40 ee ff 	vmovups -0x11c0(%rbp),%ymm0
 126de28:	ff 
 126de29:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126de30:	ff 
 126de31:	c5 fc 10 85 d0 ed ff 	vmovups -0x1230(%rbp),%ymm0
 126de38:	ff 
 126de39:	c5 fc 10 8d f0 ed ff 	vmovups -0x1210(%rbp),%ymm1
 126de40:	ff 
 126de41:	c5 fc 10 95 10 ee ff 	vmovups -0x11f0(%rbp),%ymm2
 126de48:	ff 
 126de49:	c5 fc 10 9d 30 ee ff 	vmovups -0x11d0(%rbp),%ymm3
 126de50:	ff 
 126de51:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126de58:	ff 
 126de59:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126de60:	ff 
 126de61:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126de68:	ff 
 126de69:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126de70:	ff 
 126de71:	80 bd 76 ff ff ff 00 	cmpb   $0x0,-0x8a(%rbp)
 126de78:	0f 85 a0 00 00 00    	jne    126df1e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d8e>
 126de7e:	4c 89 75 c8          	mov    %r14,-0x38(%rbp)
 126de82:	4c 89 e3             	mov    %r12,%rbx
 126de85:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126de89:	80 bd 77 ff ff ff 00 	cmpb   $0x0,-0x89(%rbp)
 126de90:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126de94:	0f 85 58 03 00 00    	jne    126e1f2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4062>
 126de9a:	e9 0a 06 00 00       	jmp    126e4a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4319>
 126de9f:	48 85 f6             	test   %rsi,%rsi
 126dea2:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126dea6:	74 4d                	je     126def5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d65>
 126dea8:	48 83 fe 01          	cmp    $0x1,%rsi
 126deac:	0f 85 42 27 00 00    	jne    12705f4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6464>
 126deb2:	31 c0                	xor    %eax,%eax
 126deb4:	40 f6 c6 01          	test   $0x1,%sil
 126deb8:	74 3b                	je     126def5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d65>
 126deba:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126dec1:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126dec8:	00 00 
 126deca:	41 80 e0 0f          	and    $0xf,%r8b
 126dece:	41 80 f8 07          	cmp    $0x7,%r8b
 126ded2:	75 21                	jne    126def5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d65>
 126ded4:	48 01 f2             	add    %rsi,%rdx
 126ded7:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126dedb:	74 18                	je     126def5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d65>
 126dedd:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 126dee1:	75 12                	jne    126def5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d65>
 126dee3:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 126deea:	00 
 126deeb:	75 08                	jne    126def5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d65>
 126deed:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126def4:	00 
 126def5:	4d 85 e4             	test   %r12,%r12
 126def8:	74 10                	je     126df0a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d7a>
 126defa:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126defe:	4c 89 f6             	mov    %r14,%rsi
 126df01:	4c 89 e2             	mov    %r12,%rdx
 126df04:	31 c9                	xor    %ecx,%ecx
 126df06:	41 ff 51 18          	call   *0x18(%r9)
 126df0a:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 126df0e:	49 89 dc             	mov    %rbx,%r12
 126df11:	80 bd 76 ff ff ff 00 	cmpb   $0x0,-0x8a(%rbp)
 126df18:	0f 84 60 ff ff ff    	je     126de7e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3cee>
 126df1e:	48 8b 85 80 f8 ff ff 	mov    -0x780(%rbp),%rax
 126df25:	48 89 85 f0 d4 ff ff 	mov    %rax,-0x2b10(%rbp)
 126df2c:	c5 fc 10 85 20 f8 ff 	vmovups -0x7e0(%rbp),%ymm0
 126df33:	ff 
 126df34:	c5 fc 10 8d 40 f8 ff 	vmovups -0x7c0(%rbp),%ymm1
 126df3b:	ff 
 126df3c:	c5 fc 10 95 60 f8 ff 	vmovups -0x7a0(%rbp),%ymm2
 126df43:	ff 
 126df44:	c5 fc 11 95 d0 d4 ff 	vmovups %ymm2,-0x2b30(%rbp)
 126df4b:	ff 
 126df4c:	c5 fc 11 8d b0 d4 ff 	vmovups %ymm1,-0x2b50(%rbp)
 126df53:	ff 
 126df54:	c5 fc 11 85 90 d4 ff 	vmovups %ymm0,-0x2b70(%rbp)
 126df5b:	ff 
 126df5c:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126df63:	ff 
 126df64:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126df6b:	ff 
 126df6c:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126df73:	ff 
 126df74:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126df7b:	ff 
 126df7c:	c5 fc 11 85 40 ed ff 	vmovups %ymm0,-0x12c0(%rbp)
 126df83:	ff 
 126df84:	c5 fc 11 8d 60 ed ff 	vmovups %ymm1,-0x12a0(%rbp)
 126df8b:	ff 
 126df8c:	c5 fc 11 95 80 ed ff 	vmovups %ymm2,-0x1280(%rbp)
 126df93:	ff 
 126df94:	c5 fc 11 9d a0 ed ff 	vmovups %ymm3,-0x1260(%rbp)
 126df9b:	ff 
 126df9c:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126dfa3:	ff 
 126dfa4:	c5 fc 11 85 b0 ed ff 	vmovups %ymm0,-0x1250(%rbp)
 126dfab:	ff 
 126dfac:	c6 85 f8 d4 ff ff 01 	movb   $0x1,-0x2b08(%rbp)
 126dfb3:	48 8d 85 90 d4 ff ff 	lea    -0x2b70(%rbp),%rax
 126dfba:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126dfbf:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126dfc6:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126dfcb:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126dfcf:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126dfd5:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126dfd9:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126dfde:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126dfe2:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126dfe7:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126dfeb:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126dff0:	48 8d 85 40 ed ff ff 	lea    -0x12c0(%rbp),%rax
 126dff7:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126dffc:	4c 89 3c 24          	mov    %r15,(%rsp)
 126e000:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126e007:	00 00 
 126e009:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126e010:	00 00 
 126e012:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126e019:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 126e020:	4c 89 fe             	mov    %r15,%rsi
 126e023:	4c 8b 6d b8          	mov    -0x48(%rbp),%r13
 126e027:	4c 89 ea             	mov    %r13,%rdx
 126e02a:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126e031:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126e035:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126e039:	c5 f8 77             	vzeroupper 
 126e03c:	e8 3f 4b 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126e041:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126e045:	48 85 db             	test   %rbx,%rbx
 126e048:	0f 85 5c 3f 00 00    	jne    1271faa <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7e1a>
 126e04e:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126e055:	48 8b 5d 80          	mov    -0x80(%rbp),%rbx
 126e059:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126e060:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 126e064:	48 89 da             	mov    %rbx,%rdx
 126e067:	4c 89 f1             	mov    %r14,%rcx
 126e06a:	4d 89 e0             	mov    %r12,%r8
 126e06d:	e8 6e ff fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126e072:	49 8b 4f 10          	mov    0x10(%r15),%rcx
 126e076:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 126e07a:	4d 8b 4d 08          	mov    0x8(%r13),%r9
 126e07e:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126e082:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126e089:	a8 01                	test   $0x1,%al
 126e08b:	0f 84 d5 00 00 00    	je     126e166 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3fd6>
 126e091:	48 85 f6             	test   %rsi,%rsi
 126e094:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126e098:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126e09c:	74 4d                	je     126e0eb <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3f5b>
 126e09e:	48 83 fe 01          	cmp    $0x1,%rsi
 126e0a2:	0f 85 f4 25 00 00    	jne    127069c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x650c>
 126e0a8:	31 c0                	xor    %eax,%eax
 126e0aa:	40 f6 c6 01          	test   $0x1,%sil
 126e0ae:	74 3b                	je     126e0eb <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3f5b>
 126e0b0:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126e0b7:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126e0be:	00 00 
 126e0c0:	41 80 e0 0f          	and    $0xf,%r8b
 126e0c4:	41 80 f8 07          	cmp    $0x7,%r8b
 126e0c8:	75 21                	jne    126e0eb <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3f5b>
 126e0ca:	48 01 f2             	add    %rsi,%rdx
 126e0cd:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126e0d1:	74 18                	je     126e0eb <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3f5b>
 126e0d3:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 126e0d7:	75 12                	jne    126e0eb <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3f5b>
 126e0d9:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 126e0e0:	00 
 126e0e1:	75 08                	jne    126e0eb <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3f5b>
 126e0e3:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126e0ea:	00 
 126e0eb:	4d 85 e4             	test   %r12,%r12
 126e0ee:	74 10                	je     126e100 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3f70>
 126e0f0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126e0f4:	4c 89 f6             	mov    %r14,%rsi
 126e0f7:	4c 89 e2             	mov    %r12,%rdx
 126e0fa:	31 c9                	xor    %ecx,%ecx
 126e0fc:	41 ff 51 18          	call   *0x18(%r9)
 126e100:	c5 fc 10 85 b0 ed ff 	vmovups -0x1250(%rbp),%ymm0
 126e107:	ff 
 126e108:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126e10f:	ff 
 126e110:	c5 fc 10 85 40 ed ff 	vmovups -0x12c0(%rbp),%ymm0
 126e117:	ff 
 126e118:	c5 fc 10 8d 60 ed ff 	vmovups -0x12a0(%rbp),%ymm1
 126e11f:	ff 
 126e120:	c5 fc 10 95 80 ed ff 	vmovups -0x1280(%rbp),%ymm2
 126e127:	ff 
 126e128:	c5 fc 10 9d a0 ed ff 	vmovups -0x1260(%rbp),%ymm3
 126e12f:	ff 
 126e130:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126e137:	ff 
 126e138:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126e13f:	ff 
 126e140:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126e147:	ff 
 126e148:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126e14f:	ff 
 126e150:	80 bd 77 ff ff ff 00 	cmpb   $0x0,-0x89(%rbp)
 126e157:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126e15b:	0f 85 91 00 00 00    	jne    126e1f2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4062>
 126e161:	e9 43 03 00 00       	jmp    126e4a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4319>
 126e166:	48 85 f6             	test   %rsi,%rsi
 126e169:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126e16d:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126e171:	74 51                	je     126e1c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4034>
 126e173:	48 83 fe 01          	cmp    $0x1,%rsi
 126e177:	0f 85 bf 25 00 00    	jne    127073c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x65ac>
 126e17d:	31 c0                	xor    %eax,%eax
 126e17f:	40 f6 c6 01          	test   $0x1,%sil
 126e183:	74 3f                	je     126e1c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4034>
 126e185:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126e18c:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126e193:	00 00 
 126e195:	41 80 e0 0f          	and    $0xf,%r8b
 126e199:	41 80 f8 07          	cmp    $0x7,%r8b
 126e19d:	75 25                	jne    126e1c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4034>
 126e19f:	48 01 f2             	add    %rsi,%rdx
 126e1a2:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126e1a6:	74 1c                	je     126e1c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4034>
 126e1a8:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126e1ac:	75 16                	jne    126e1c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4034>
 126e1ae:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 126e1b2:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126e1b9:	00 
 126e1ba:	75 08                	jne    126e1c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4034>
 126e1bc:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126e1c3:	00 
 126e1c4:	48 85 db             	test   %rbx,%rbx
 126e1c7:	74 11                	je     126e1da <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x404a>
 126e1c9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126e1cd:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 126e1d1:	48 89 da             	mov    %rbx,%rdx
 126e1d4:	31 c9                	xor    %ecx,%ecx
 126e1d6:	41 ff 51 18          	call   *0x18(%r9)
 126e1da:	4c 89 75 c8          	mov    %r14,-0x38(%rbp)
 126e1de:	4c 89 e3             	mov    %r12,%rbx
 126e1e1:	80 bd 77 ff ff ff 00 	cmpb   $0x0,-0x89(%rbp)
 126e1e8:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126e1ec:	0f 84 b7 02 00 00    	je     126e4a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4319>
 126e1f2:	48 8b 85 f0 f8 ff ff 	mov    -0x710(%rbp),%rax
 126e1f9:	48 89 85 80 d4 ff ff 	mov    %rax,-0x2b80(%rbp)
 126e200:	c5 fc 10 85 90 f8 ff 	vmovups -0x770(%rbp),%ymm0
 126e207:	ff 
 126e208:	c5 fc 10 8d b0 f8 ff 	vmovups -0x750(%rbp),%ymm1
 126e20f:	ff 
 126e210:	c5 fc 10 95 d0 f8 ff 	vmovups -0x730(%rbp),%ymm2
 126e217:	ff 
 126e218:	c5 fc 11 95 60 d4 ff 	vmovups %ymm2,-0x2ba0(%rbp)
 126e21f:	ff 
 126e220:	c5 fc 11 8d 40 d4 ff 	vmovups %ymm1,-0x2bc0(%rbp)
 126e227:	ff 
 126e228:	c5 fc 11 85 20 d4 ff 	vmovups %ymm0,-0x2be0(%rbp)
 126e22f:	ff 
 126e230:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126e237:	ff 
 126e238:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126e23f:	ff 
 126e240:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126e247:	ff 
 126e248:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126e24f:	ff 
 126e250:	c5 fc 11 85 b0 ec ff 	vmovups %ymm0,-0x1350(%rbp)
 126e257:	ff 
 126e258:	c5 fc 11 8d d0 ec ff 	vmovups %ymm1,-0x1330(%rbp)
 126e25f:	ff 
 126e260:	c5 fc 11 95 f0 ec ff 	vmovups %ymm2,-0x1310(%rbp)
 126e267:	ff 
 126e268:	c5 fc 11 9d 10 ed ff 	vmovups %ymm3,-0x12f0(%rbp)
 126e26f:	ff 
 126e270:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126e277:	ff 
 126e278:	c5 fc 11 85 20 ed ff 	vmovups %ymm0,-0x12e0(%rbp)
 126e27f:	ff 
 126e280:	c6 85 88 d4 ff ff 01 	movb   $0x1,-0x2b78(%rbp)
 126e287:	48 8d 85 20 d4 ff ff 	lea    -0x2be0(%rbp),%rax
 126e28e:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126e293:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126e29a:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126e29f:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126e2a3:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126e2a9:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126e2ad:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126e2b2:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126e2b6:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126e2bb:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126e2bf:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126e2c4:	48 8d 85 b0 ec ff ff 	lea    -0x1350(%rbp),%rax
 126e2cb:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126e2d0:	4c 89 3c 24          	mov    %r15,(%rsp)
 126e2d4:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126e2db:	00 00 
 126e2dd:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126e2e4:	00 00 
 126e2e6:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126e2ed:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 126e2f4:	4c 89 fe             	mov    %r15,%rsi
 126e2f7:	4c 89 f2             	mov    %r14,%rdx
 126e2fa:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126e301:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126e305:	4d 89 e9             	mov    %r13,%r9
 126e308:	c5 f8 77             	vzeroupper 
 126e30b:	e8 70 48 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126e310:	4d 89 f5             	mov    %r14,%r13
 126e313:	44 0f b7 75 88       	movzwl -0x78(%rbp),%r14d
 126e318:	4d 85 f6             	test   %r14,%r14
 126e31b:	0f 85 74 3d 00 00    	jne    1272095 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7f05>
 126e321:	4c 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%r14
 126e328:	4c 8b 65 80          	mov    -0x80(%rbp),%r12
 126e32c:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126e333:	4c 89 f6             	mov    %r14,%rsi
 126e336:	4c 89 e2             	mov    %r12,%rdx
 126e339:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 126e33d:	49 89 d8             	mov    %rbx,%r8
 126e340:	e8 9b fc fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126e345:	49 8b 4f 10          	mov    0x10(%r15),%rcx
 126e349:	49 8b 7d 00          	mov    0x0(%r13),%rdi
 126e34d:	4d 8b 4d 08          	mov    0x8(%r13),%r9
 126e351:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126e355:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126e35c:	a8 01                	test   $0x1,%al
 126e35e:	0f 84 d6 00 00 00    	je     126e43a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x42aa>
 126e364:	48 85 f6             	test   %rsi,%rsi
 126e367:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126e36b:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126e36f:	74 51                	je     126e3c2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4232>
 126e371:	48 83 fe 01          	cmp    $0x1,%rsi
 126e375:	0f 85 69 24 00 00    	jne    12707e4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6654>
 126e37b:	31 c0                	xor    %eax,%eax
 126e37d:	40 f6 c6 01          	test   $0x1,%sil
 126e381:	74 3f                	je     126e3c2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4232>
 126e383:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126e38a:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126e391:	00 00 
 126e393:	41 80 e0 0f          	and    $0xf,%r8b
 126e397:	41 80 f8 07          	cmp    $0x7,%r8b
 126e39b:	75 25                	jne    126e3c2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4232>
 126e39d:	48 01 f2             	add    %rsi,%rdx
 126e3a0:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126e3a4:	74 1c                	je     126e3c2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4232>
 126e3a6:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126e3aa:	75 16                	jne    126e3c2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4232>
 126e3ac:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 126e3b0:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126e3b7:	00 
 126e3b8:	75 08                	jne    126e3c2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4232>
 126e3ba:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126e3c1:	00 
 126e3c2:	48 85 db             	test   %rbx,%rbx
 126e3c5:	74 11                	je     126e3d8 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4248>
 126e3c7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126e3cb:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 126e3cf:	48 89 da             	mov    %rbx,%rdx
 126e3d2:	31 c9                	xor    %ecx,%ecx
 126e3d4:	41 ff 51 18          	call   *0x18(%r9)
 126e3d8:	c5 fc 10 85 20 ed ff 	vmovups -0x12e0(%rbp),%ymm0
 126e3df:	ff 
 126e3e0:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126e3e7:	ff 
 126e3e8:	c5 fc 10 85 b0 ec ff 	vmovups -0x1350(%rbp),%ymm0
 126e3ef:	ff 
 126e3f0:	c5 fc 10 8d d0 ec ff 	vmovups -0x1330(%rbp),%ymm1
 126e3f7:	ff 
 126e3f8:	c5 fc 10 95 f0 ec ff 	vmovups -0x1310(%rbp),%ymm2
 126e3ff:	ff 
 126e400:	c5 fc 10 9d 10 ed ff 	vmovups -0x12f0(%rbp),%ymm3
 126e407:	ff 
 126e408:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126e40f:	ff 
 126e410:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126e417:	ff 
 126e418:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126e41f:	ff 
 126e420:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126e427:	ff 
 126e428:	80 bd 1f ff ff ff 00 	cmpb   $0x0,-0xe1(%rbp)
 126e42f:	0f 85 88 00 00 00    	jne    126e4bd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x432d>
 126e435:	e9 29 03 00 00       	jmp    126e763 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x45d3>
 126e43a:	48 85 f6             	test   %rsi,%rsi
 126e43d:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126e441:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126e445:	74 4d                	je     126e494 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4304>
 126e447:	48 83 fe 01          	cmp    $0x1,%rsi
 126e44b:	0f 85 43 24 00 00    	jne    1270894 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6704>
 126e451:	31 c0                	xor    %eax,%eax
 126e453:	40 f6 c6 01          	test   $0x1,%sil
 126e457:	74 3b                	je     126e494 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4304>
 126e459:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126e460:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126e467:	00 00 
 126e469:	41 80 e0 0f          	and    $0xf,%r8b
 126e46d:	41 80 f8 07          	cmp    $0x7,%r8b
 126e471:	75 21                	jne    126e494 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4304>
 126e473:	48 01 f2             	add    %rsi,%rdx
 126e476:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126e47a:	74 18                	je     126e494 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4304>
 126e47c:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 126e480:	75 12                	jne    126e494 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4304>
 126e482:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 126e489:	00 
 126e48a:	75 08                	jne    126e494 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4304>
 126e48c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126e493:	00 
 126e494:	4d 85 e4             	test   %r12,%r12
 126e497:	74 10                	je     126e4a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4319>
 126e499:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126e49d:	4c 89 f6             	mov    %r14,%rsi
 126e4a0:	4c 89 e2             	mov    %r12,%rdx
 126e4a3:	31 c9                	xor    %ecx,%ecx
 126e4a5:	41 ff 51 18          	call   *0x18(%r9)
 126e4a9:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 126e4ad:	49 89 dc             	mov    %rbx,%r12
 126e4b0:	80 bd 1f ff ff ff 00 	cmpb   $0x0,-0xe1(%rbp)
 126e4b7:	0f 84 a6 02 00 00    	je     126e763 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x45d3>
 126e4bd:	48 8b 85 60 f9 ff ff 	mov    -0x6a0(%rbp),%rax
 126e4c4:	48 89 85 10 d4 ff ff 	mov    %rax,-0x2bf0(%rbp)
 126e4cb:	c5 fc 10 85 00 f9 ff 	vmovups -0x700(%rbp),%ymm0
 126e4d2:	ff 
 126e4d3:	c5 fc 10 8d 20 f9 ff 	vmovups -0x6e0(%rbp),%ymm1
 126e4da:	ff 
 126e4db:	c5 fc 10 95 40 f9 ff 	vmovups -0x6c0(%rbp),%ymm2
 126e4e2:	ff 
 126e4e3:	c5 fc 11 95 f0 d3 ff 	vmovups %ymm2,-0x2c10(%rbp)
 126e4ea:	ff 
 126e4eb:	c5 fc 11 8d d0 d3 ff 	vmovups %ymm1,-0x2c30(%rbp)
 126e4f2:	ff 
 126e4f3:	c5 fc 11 85 b0 d3 ff 	vmovups %ymm0,-0x2c50(%rbp)
 126e4fa:	ff 
 126e4fb:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126e502:	ff 
 126e503:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126e50a:	ff 
 126e50b:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126e512:	ff 
 126e513:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126e51a:	ff 
 126e51b:	c5 fc 11 85 20 ec ff 	vmovups %ymm0,-0x13e0(%rbp)
 126e522:	ff 
 126e523:	c5 fc 11 8d 40 ec ff 	vmovups %ymm1,-0x13c0(%rbp)
 126e52a:	ff 
 126e52b:	c5 fc 11 95 60 ec ff 	vmovups %ymm2,-0x13a0(%rbp)
 126e532:	ff 
 126e533:	c5 fc 11 9d 80 ec ff 	vmovups %ymm3,-0x1380(%rbp)
 126e53a:	ff 
 126e53b:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126e542:	ff 
 126e543:	c5 fc 11 85 90 ec ff 	vmovups %ymm0,-0x1370(%rbp)
 126e54a:	ff 
 126e54b:	c6 85 18 d4 ff ff 01 	movb   $0x1,-0x2be8(%rbp)
 126e552:	48 8d 85 b0 d3 ff ff 	lea    -0x2c50(%rbp),%rax
 126e559:	48 89 44 24 48       	mov    %rax,0x48(%rsp)
 126e55e:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126e565:	48 89 44 24 38       	mov    %rax,0x38(%rsp)
 126e56a:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126e56e:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126e574:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126e578:	48 89 44 24 20       	mov    %rax,0x20(%rsp)
 126e57d:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126e581:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126e586:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126e58a:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126e58f:	48 8d 85 20 ec ff ff 	lea    -0x13e0(%rbp),%rax
 126e596:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126e59b:	4c 89 3c 24          	mov    %r15,(%rsp)
 126e59f:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126e5a6:	00 00 
 126e5a8:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126e5af:	00 00 
 126e5b1:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126e5b8:	4d 89 e9             	mov    %r13,%r9
 126e5bb:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 126e5c2:	4c 89 ee             	mov    %r13,%rsi
 126e5c5:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 126e5c9:	4c 89 fa             	mov    %r15,%rdx
 126e5cc:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126e5d3:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126e5d7:	c5 f8 77             	vzeroupper 
 126e5da:	e8 a1 45 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126e5df:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126e5e3:	48 85 db             	test   %rbx,%rbx
 126e5e6:	0f 85 e2 3b 00 00    	jne    12721ce <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x803e>
 126e5ec:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126e5f3:	48 8b 5d 80          	mov    -0x80(%rbp),%rbx
 126e5f7:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126e5fe:	48 89 75 c0          	mov    %rsi,-0x40(%rbp)
 126e602:	48 89 da             	mov    %rbx,%rdx
 126e605:	4c 89 f1             	mov    %r14,%rcx
 126e608:	4d 89 e0             	mov    %r12,%r8
 126e60b:	e8 d0 f9 fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126e610:	49 8b 4d 10          	mov    0x10(%r13),%rcx
 126e614:	49 8b 3f             	mov    (%r15),%rdi
 126e617:	4d 8b 4f 08          	mov    0x8(%r15),%r9
 126e61b:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126e61f:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126e626:	a8 01                	test   $0x1,%al
 126e628:	0f 84 c1 00 00 00    	je     126e6ef <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x455f>
 126e62e:	48 85 f6             	test   %rsi,%rsi
 126e631:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126e635:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126e639:	74 4d                	je     126e688 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x44f8>
 126e63b:	48 83 fe 01          	cmp    $0x1,%rsi
 126e63f:	0f 85 f7 22 00 00    	jne    127093c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x67ac>
 126e645:	31 c0                	xor    %eax,%eax
 126e647:	40 f6 c6 01          	test   $0x1,%sil
 126e64b:	74 3b                	je     126e688 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x44f8>
 126e64d:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126e654:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126e65b:	00 00 
 126e65d:	41 80 e0 0f          	and    $0xf,%r8b
 126e661:	41 80 f8 07          	cmp    $0x7,%r8b
 126e665:	75 21                	jne    126e688 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x44f8>
 126e667:	48 01 f2             	add    %rsi,%rdx
 126e66a:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126e66e:	74 18                	je     126e688 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x44f8>
 126e670:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 126e674:	75 12                	jne    126e688 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x44f8>
 126e676:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 126e67d:	00 
 126e67e:	75 08                	jne    126e688 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x44f8>
 126e680:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126e687:	00 
 126e688:	4d 85 e4             	test   %r12,%r12
 126e68b:	74 10                	je     126e69d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x450d>
 126e68d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126e691:	4c 89 f6             	mov    %r14,%rsi
 126e694:	4c 89 e2             	mov    %r12,%rdx
 126e697:	31 c9                	xor    %ecx,%ecx
 126e699:	41 ff 51 18          	call   *0x18(%r9)
 126e69d:	c5 fc 10 85 90 ec ff 	vmovups -0x1370(%rbp),%ymm0
 126e6a4:	ff 
 126e6a5:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126e6ac:	ff 
 126e6ad:	c5 fc 10 85 20 ec ff 	vmovups -0x13e0(%rbp),%ymm0
 126e6b4:	ff 
 126e6b5:	c5 fc 10 8d 40 ec ff 	vmovups -0x13c0(%rbp),%ymm1
 126e6bc:	ff 
 126e6bd:	c5 fc 10 95 60 ec ff 	vmovups -0x13a0(%rbp),%ymm2
 126e6c4:	ff 
 126e6c5:	c5 fc 10 9d 80 ec ff 	vmovups -0x1380(%rbp),%ymm3
 126e6cc:	ff 
 126e6cd:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126e6d4:	ff 
 126e6d5:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126e6dc:	ff 
 126e6dd:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126e6e4:	ff 
 126e6e5:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126e6ec:	ff 
 126e6ed:	eb 7b                	jmp    126e76a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x45da>
 126e6ef:	48 85 f6             	test   %rsi,%rsi
 126e6f2:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126e6f6:	4c 8b 7d 10          	mov    0x10(%rbp),%r15
 126e6fa:	74 51                	je     126e74d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x45bd>
 126e6fc:	48 83 fe 01          	cmp    $0x1,%rsi
 126e700:	0f 85 d6 22 00 00    	jne    12709dc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x684c>
 126e706:	31 c0                	xor    %eax,%eax
 126e708:	40 f6 c6 01          	test   $0x1,%sil
 126e70c:	74 3f                	je     126e74d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x45bd>
 126e70e:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126e715:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126e71c:	00 00 
 126e71e:	41 80 e0 0f          	and    $0xf,%r8b
 126e722:	41 80 f8 07          	cmp    $0x7,%r8b
 126e726:	75 25                	jne    126e74d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x45bd>
 126e728:	48 01 f2             	add    %rsi,%rdx
 126e72b:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126e72f:	74 1c                	je     126e74d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x45bd>
 126e731:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126e735:	75 16                	jne    126e74d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x45bd>
 126e737:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 126e73b:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126e742:	00 
 126e743:	75 08                	jne    126e74d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x45bd>
 126e745:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126e74c:	00 
 126e74d:	48 85 db             	test   %rbx,%rbx
 126e750:	74 11                	je     126e763 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x45d3>
 126e752:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126e756:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 126e75a:	48 89 da             	mov    %rbx,%rdx
 126e75d:	31 c9                	xor    %ecx,%ecx
 126e75f:	41 ff 51 18          	call   *0x18(%r9)
 126e763:	4c 89 75 c0          	mov    %r14,-0x40(%rbp)
 126e767:	4c 89 e3             	mov    %r12,%rbx
 126e76a:	0f b6 4d a5          	movzbl -0x5b(%rbp),%ecx
 126e76e:	80 f1 01             	xor    $0x1,%cl
 126e771:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 126e778:	0f 94 c0             	sete   %al
 126e77b:	41 89 cc             	mov    %ecx,%r12d
 126e77e:	84 c1                	test   %al,%cl
 126e780:	4c 8b 75 b8          	mov    -0x48(%rbp),%r14
 126e784:	0f 85 72 02 00 00    	jne    126e9fc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x486c>
 126e78a:	80 bd f0 df ff ff 00 	cmpb   $0x0,-0x2010(%rbp)
 126e791:	0f 84 65 02 00 00    	je     126e9fc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x486c>
 126e797:	48 8d 85 c0 df ff ff 	lea    -0x2040(%rbp),%rax
 126e79e:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126e7a5:	ff 
 126e7a6:	c5 fc 11 85 00 ec ff 	vmovups %ymm0,-0x1400(%rbp)
 126e7ad:	ff 
 126e7ae:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126e7b5:	ff 
 126e7b6:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126e7bd:	ff 
 126e7be:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126e7c5:	ff 
 126e7c6:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126e7cd:	ff 
 126e7ce:	c5 fc 11 9d f0 eb ff 	vmovups %ymm3,-0x1410(%rbp)
 126e7d5:	ff 
 126e7d6:	c5 fc 11 95 d0 eb ff 	vmovups %ymm2,-0x1430(%rbp)
 126e7dd:	ff 
 126e7de:	c5 fc 11 8d b0 eb ff 	vmovups %ymm1,-0x1450(%rbp)
 126e7e5:	ff 
 126e7e6:	c5 fc 11 85 90 eb ff 	vmovups %ymm0,-0x1470(%rbp)
 126e7ed:	ff 
 126e7ee:	48 89 44 24 40       	mov    %rax,0x40(%rsp)
 126e7f3:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126e7f7:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126e7fd:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126e801:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126e806:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126e80a:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126e80f:	48 8d 85 90 eb ff ff 	lea    -0x1470(%rbp),%rax
 126e816:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126e81b:	4c 89 3c 24          	mov    %r15,(%rsp)
 126e81f:	48 c7 44 24 50 00 00 	movq   $0x0,0x50(%rsp)
 126e826:	00 00 
 126e828:	48 c7 44 24 48 68 ae 	movq   $0x103ae68,0x48(%rsp)
 126e82f:	03 01 
 126e831:	48 c7 44 24 38 f8 ad 	movq   $0x103adf8,0x38(%rsp)
 126e838:	03 01 
 126e83a:	48 c7 44 24 20 88 ad 	movq   $0x103ad88,0x20(%rsp)
 126e841:	03 01 
 126e843:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126e84a:	4d 89 e9             	mov    %r13,%r9
 126e84d:	4c 8b ad 58 ff ff ff 	mov    -0xa8(%rbp),%r13
 126e854:	4c 89 ee             	mov    %r13,%rsi
 126e857:	4c 89 f2             	mov    %r14,%rdx
 126e85a:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126e861:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126e865:	c5 f8 77             	vzeroupper 
 126e868:	e8 13 43 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126e86d:	44 0f b7 7d 88       	movzwl -0x78(%rbp),%r15d
 126e872:	4d 85 ff             	test   %r15,%r15
 126e875:	0f 85 54 3d 00 00    	jne    12725cf <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x843f>
 126e87b:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126e882:	4c 8b 7d 80          	mov    -0x80(%rbp),%r15
 126e886:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126e88d:	48 89 b5 68 ff ff ff 	mov    %rsi,-0x98(%rbp)
 126e894:	4c 89 fa             	mov    %r15,%rdx
 126e897:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 126e89b:	49 89 d8             	mov    %rbx,%r8
 126e89e:	e8 3d f7 fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126e8a3:	49 8b 4d 10          	mov    0x10(%r13),%rcx
 126e8a7:	49 8b 3e             	mov    (%r14),%rdi
 126e8aa:	4d 8b 4e 08          	mov    0x8(%r14),%r9
 126e8ae:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126e8b2:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126e8b9:	a8 01                	test   $0x1,%al
 126e8bb:	0f 84 c5 00 00 00    	je     126e986 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x47f6>
 126e8c1:	48 85 f6             	test   %rsi,%rsi
 126e8c4:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126e8c8:	74 51                	je     126e91b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x478b>
 126e8ca:	48 83 fe 01          	cmp    $0x1,%rsi
 126e8ce:	0f 85 a8 25 00 00    	jne    1270e7c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6cec>
 126e8d4:	31 c0                	xor    %eax,%eax
 126e8d6:	40 f6 c6 01          	test   $0x1,%sil
 126e8da:	74 3f                	je     126e91b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x478b>
 126e8dc:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126e8e3:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126e8ea:	00 00 
 126e8ec:	41 80 e0 0f          	and    $0xf,%r8b
 126e8f0:	41 80 f8 07          	cmp    $0x7,%r8b
 126e8f4:	75 25                	jne    126e91b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x478b>
 126e8f6:	48 01 f2             	add    %rsi,%rdx
 126e8f9:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126e8fd:	74 1c                	je     126e91b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x478b>
 126e8ff:	48 39 5a 38          	cmp    %rbx,0x38(%rdx)
 126e903:	75 16                	jne    126e91b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x478b>
 126e905:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 126e909:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126e910:	00 
 126e911:	75 08                	jne    126e91b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x478b>
 126e913:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126e91a:	00 
 126e91b:	48 85 db             	test   %rbx,%rbx
 126e91e:	74 11                	je     126e931 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x47a1>
 126e920:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126e924:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 126e928:	48 89 da             	mov    %rbx,%rdx
 126e92b:	31 c9                	xor    %ecx,%ecx
 126e92d:	41 ff 51 18          	call   *0x18(%r9)
 126e931:	c5 fc 10 85 00 ec ff 	vmovups -0x1400(%rbp),%ymm0
 126e938:	ff 
 126e939:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126e940:	ff 
 126e941:	c5 fc 10 85 90 eb ff 	vmovups -0x1470(%rbp),%ymm0
 126e948:	ff 
 126e949:	c5 fc 10 8d b0 eb ff 	vmovups -0x1450(%rbp),%ymm1
 126e950:	ff 
 126e951:	c5 fc 10 95 d0 eb ff 	vmovups -0x1430(%rbp),%ymm2
 126e958:	ff 
 126e959:	c5 fc 10 9d f0 eb ff 	vmovups -0x1410(%rbp),%ymm3
 126e960:	ff 
 126e961:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126e968:	ff 
 126e969:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126e970:	ff 
 126e971:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126e978:	ff 
 126e979:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126e980:	ff 
 126e981:	e9 84 00 00 00       	jmp    126ea0a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x487a>
 126e986:	48 85 f6             	test   %rsi,%rsi
 126e989:	4c 8b 6d a8          	mov    -0x58(%rbp),%r13
 126e98d:	74 54                	je     126e9e3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4853>
 126e98f:	48 83 fe 01          	cmp    $0x1,%rsi
 126e993:	0f 85 8b 25 00 00    	jne    1270f24 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d94>
 126e999:	31 c0                	xor    %eax,%eax
 126e99b:	40 f6 c6 01          	test   $0x1,%sil
 126e99f:	74 42                	je     126e9e3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4853>
 126e9a1:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126e9a8:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126e9af:	00 00 
 126e9b1:	41 80 e0 0f          	and    $0xf,%r8b
 126e9b5:	41 80 f8 07          	cmp    $0x7,%r8b
 126e9b9:	75 28                	jne    126e9e3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4853>
 126e9bb:	48 01 f2             	add    %rsi,%rdx
 126e9be:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126e9c2:	74 1f                	je     126e9e3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4853>
 126e9c4:	4c 39 7a 38          	cmp    %r15,0x38(%rdx)
 126e9c8:	75 19                	jne    126e9e3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4853>
 126e9ca:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 126e9d1:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126e9d8:	00 
 126e9d9:	75 08                	jne    126e9e3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4853>
 126e9db:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126e9e2:	00 
 126e9e3:	4d 85 ff             	test   %r15,%r15
 126e9e6:	74 14                	je     126e9fc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x486c>
 126e9e8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126e9ec:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 126e9f3:	4c 89 fa             	mov    %r15,%rdx
 126e9f6:	31 c9                	xor    %ecx,%ecx
 126e9f8:	41 ff 51 18          	call   *0x18(%r9)
 126e9fc:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 126ea00:	48 89 85 68 ff ff ff 	mov    %rax,-0x98(%rbp)
 126ea07:	49 89 df             	mov    %rbx,%r15
 126ea0a:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 126ea11:	0f 94 c0             	sete   %al
 126ea14:	41 20 c4             	and    %al,%r12b
 126ea17:	80 bd f0 df ff ff 00 	cmpb   $0x0,-0x2010(%rbp)
 126ea1e:	0f 94 c0             	sete   %al
 126ea21:	41 84 c4             	test   %al,%r12b
 126ea24:	0f 85 15 02 00 00    	jne    126ec3f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4aaf>
 126ea2a:	80 bd 38 e3 ff ff 00 	cmpb   $0x0,-0x1cc8(%rbp)
 126ea31:	0f 84 08 02 00 00    	je     126ec3f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4aaf>
 126ea37:	48 8d 85 08 e3 ff ff 	lea    -0x1cf8(%rbp),%rax
 126ea3e:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126ea45:	ff 
 126ea46:	c5 fc 11 85 70 eb ff 	vmovups %ymm0,-0x1490(%rbp)
 126ea4d:	ff 
 126ea4e:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126ea55:	ff 
 126ea56:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126ea5d:	ff 
 126ea5e:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126ea65:	ff 
 126ea66:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126ea6d:	ff 
 126ea6e:	c5 fc 11 9d 60 eb ff 	vmovups %ymm3,-0x14a0(%rbp)
 126ea75:	ff 
 126ea76:	c5 fc 11 95 40 eb ff 	vmovups %ymm2,-0x14c0(%rbp)
 126ea7d:	ff 
 126ea7e:	c5 fc 11 8d 20 eb ff 	vmovups %ymm1,-0x14e0(%rbp)
 126ea85:	ff 
 126ea86:	c5 fc 11 85 00 eb ff 	vmovups %ymm0,-0x1500(%rbp)
 126ea8d:	ff 
 126ea8e:	48 89 44 24 50       	mov    %rax,0x50(%rsp)
 126ea93:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126ea97:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126ea9d:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126eaa1:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126eaa6:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126eaaa:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126eaaf:	48 8d 85 00 eb ff ff 	lea    -0x1500(%rbp),%rax
 126eab6:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126eabb:	48 8b 45 10          	mov    0x10(%rbp),%rax
 126eabf:	48 89 04 24          	mov    %rax,(%rsp)
 126eac3:	48 c7 44 24 48 68 ae 	movq   $0x103ae68,0x48(%rsp)
 126eaca:	03 01 
 126eacc:	48 c7 44 24 40 00 00 	movq   $0x0,0x40(%rsp)
 126ead3:	00 00 
 126ead5:	48 c7 44 24 38 f8 ad 	movq   $0x103adf8,0x38(%rsp)
 126eadc:	03 01 
 126eade:	48 c7 44 24 20 88 ad 	movq   $0x103ad88,0x20(%rsp)
 126eae5:	03 01 
 126eae7:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126eaee:	4c 8b a5 58 ff ff ff 	mov    -0xa8(%rbp),%r12
 126eaf5:	4c 89 e6             	mov    %r12,%rsi
 126eaf8:	4c 89 f2             	mov    %r14,%rdx
 126eafb:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126eb02:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126eb06:	4d 89 e9             	mov    %r13,%r9
 126eb09:	c5 f8 77             	vzeroupper 
 126eb0c:	e8 6f 40 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126eb11:	0f b7 5d 88          	movzwl -0x78(%rbp),%ebx
 126eb15:	48 85 db             	test   %rbx,%rbx
 126eb18:	0f 85 ea 3b 00 00    	jne    1272708 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8578>
 126eb1e:	4c 89 f3             	mov    %r14,%rbx
 126eb21:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126eb28:	4c 8b 6d 80          	mov    -0x80(%rbp),%r13
 126eb2c:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126eb33:	48 89 75 c0          	mov    %rsi,-0x40(%rbp)
 126eb37:	4c 89 ea             	mov    %r13,%rdx
 126eb3a:	4c 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%r14
 126eb41:	4c 89 f1             	mov    %r14,%rcx
 126eb44:	4d 89 f8             	mov    %r15,%r8
 126eb47:	e8 94 f4 fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126eb4c:	49 8b 4c 24 10       	mov    0x10(%r12),%rcx
 126eb51:	48 8b 3b             	mov    (%rbx),%rdi
 126eb54:	4c 8b 4b 08          	mov    0x8(%rbx),%r9
 126eb58:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126eb5c:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126eb63:	a8 01                	test   $0x1,%al
 126eb65:	0f 84 e1 00 00 00    	je     126ec4c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4abc>
 126eb6b:	48 85 f6             	test   %rsi,%rsi
 126eb6e:	74 4d                	je     126ebbd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4a2d>
 126eb70:	48 83 fe 01          	cmp    $0x1,%rsi
 126eb74:	0f 85 5d 24 00 00    	jne    1270fd7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e47>
 126eb7a:	31 c0                	xor    %eax,%eax
 126eb7c:	40 f6 c6 01          	test   $0x1,%sil
 126eb80:	74 3b                	je     126ebbd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4a2d>
 126eb82:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126eb89:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126eb90:	00 00 
 126eb92:	41 80 e0 0f          	and    $0xf,%r8b
 126eb96:	41 80 f8 07          	cmp    $0x7,%r8b
 126eb9a:	75 21                	jne    126ebbd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4a2d>
 126eb9c:	48 01 f2             	add    %rsi,%rdx
 126eb9f:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126eba3:	74 18                	je     126ebbd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4a2d>
 126eba5:	4c 39 7a 38          	cmp    %r15,0x38(%rdx)
 126eba9:	75 12                	jne    126ebbd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4a2d>
 126ebab:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 126ebb2:	00 
 126ebb3:	75 08                	jne    126ebbd <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4a2d>
 126ebb5:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126ebbc:	00 
 126ebbd:	4d 85 ff             	test   %r15,%r15
 126ebc0:	74 10                	je     126ebd2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4a42>
 126ebc2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126ebc6:	4c 89 f6             	mov    %r14,%rsi
 126ebc9:	4c 89 fa             	mov    %r15,%rdx
 126ebcc:	31 c9                	xor    %ecx,%ecx
 126ebce:	41 ff 51 18          	call   *0x18(%r9)
 126ebd2:	c5 fc 10 85 70 eb ff 	vmovups -0x1490(%rbp),%ymm0
 126ebd9:	ff 
 126ebda:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126ebe1:	ff 
 126ebe2:	c5 fc 10 85 00 eb ff 	vmovups -0x1500(%rbp),%ymm0
 126ebe9:	ff 
 126ebea:	c5 fc 10 8d 20 eb ff 	vmovups -0x14e0(%rbp),%ymm1
 126ebf1:	ff 
 126ebf2:	c5 fc 10 95 40 eb ff 	vmovups -0x14c0(%rbp),%ymm2
 126ebf9:	ff 
 126ebfa:	c5 fc 10 9d 60 eb ff 	vmovups -0x14a0(%rbp),%ymm3
 126ec01:	ff 
 126ec02:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126ec09:	ff 
 126ec0a:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126ec11:	ff 
 126ec12:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126ec19:	ff 
 126ec1a:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126ec21:	ff 
 126ec22:	48 8d 95 c0 df ff ff 	lea    -0x2040(%rbp),%rdx
 126ec29:	80 bd f0 df ff ff 00 	cmpb   $0x0,-0x2010(%rbp)
 126ec30:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 126ec34:	0f 85 9d 00 00 00    	jne    126ecd7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4b47>
 126ec3a:	e9 f1 02 00 00       	jmp    126ef30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4da0>
 126ec3f:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 126ec46:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 126ec4a:	eb 70                	jmp    126ecbc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4b2c>
 126ec4c:	48 85 f6             	test   %rsi,%rsi
 126ec4f:	74 51                	je     126eca2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4b12>
 126ec51:	48 83 fe 01          	cmp    $0x1,%rsi
 126ec55:	0f 85 21 24 00 00    	jne    127107c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6eec>
 126ec5b:	31 c0                	xor    %eax,%eax
 126ec5d:	40 f6 c6 01          	test   $0x1,%sil
 126ec61:	74 3f                	je     126eca2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4b12>
 126ec63:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126ec6a:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126ec71:	00 00 
 126ec73:	41 80 e0 0f          	and    $0xf,%r8b
 126ec77:	41 80 f8 07          	cmp    $0x7,%r8b
 126ec7b:	75 25                	jne    126eca2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4b12>
 126ec7d:	48 01 f2             	add    %rsi,%rdx
 126ec80:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126ec84:	74 1c                	je     126eca2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4b12>
 126ec86:	4c 39 6a 38          	cmp    %r13,0x38(%rdx)
 126ec8a:	75 16                	jne    126eca2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4b12>
 126ec8c:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 126ec90:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126ec97:	00 
 126ec98:	75 08                	jne    126eca2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4b12>
 126ec9a:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126eca1:	00 
 126eca2:	4d 85 ed             	test   %r13,%r13
 126eca5:	74 11                	je     126ecb8 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4b28>
 126eca7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126ecab:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 126ecaf:	4c 89 ea             	mov    %r13,%rdx
 126ecb2:	31 c9                	xor    %ecx,%ecx
 126ecb4:	41 ff 51 18          	call   *0x18(%r9)
 126ecb8:	4c 89 75 c0          	mov    %r14,-0x40(%rbp)
 126ecbc:	4d 89 fd             	mov    %r15,%r13
 126ecbf:	48 8d 95 c0 df ff ff 	lea    -0x2040(%rbp),%rdx
 126ecc6:	80 bd f0 df ff ff 00 	cmpb   $0x0,-0x2010(%rbp)
 126eccd:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 126ecd1:	0f 84 59 02 00 00    	je     126ef30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4da0>
 126ecd7:	80 bd 38 e3 ff ff 00 	cmpb   $0x0,-0x1cc8(%rbp)
 126ecde:	0f 84 4c 02 00 00    	je     126ef30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4da0>
 126ece4:	48 8d 85 08 e3 ff ff 	lea    -0x1cf8(%rbp),%rax
 126eceb:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 126ecf2:	ff 
 126ecf3:	c5 fc 11 85 e0 ea ff 	vmovups %ymm0,-0x1520(%rbp)
 126ecfa:	ff 
 126ecfb:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 126ed02:	ff 
 126ed03:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 126ed0a:	ff 
 126ed0b:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 126ed12:	ff 
 126ed13:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 126ed1a:	ff 
 126ed1b:	c5 fc 11 9d d0 ea ff 	vmovups %ymm3,-0x1530(%rbp)
 126ed22:	ff 
 126ed23:	c5 fc 11 95 b0 ea ff 	vmovups %ymm2,-0x1550(%rbp)
 126ed2a:	ff 
 126ed2b:	c5 fc 11 8d 90 ea ff 	vmovups %ymm1,-0x1570(%rbp)
 126ed32:	ff 
 126ed33:	c5 fc 11 85 70 ea ff 	vmovups %ymm0,-0x1590(%rbp)
 126ed3a:	ff 
 126ed3b:	48 89 44 24 50       	mov    %rax,0x50(%rsp)
 126ed40:	48 89 54 24 40       	mov    %rdx,0x40(%rsp)
 126ed45:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126ed49:	c5 f8 11 44 24 28    	vmovups %xmm0,0x28(%rsp)
 126ed4f:	48 8b 45 28          	mov    0x28(%rbp),%rax
 126ed53:	48 89 44 24 18       	mov    %rax,0x18(%rsp)
 126ed58:	48 8b 45 20          	mov    0x20(%rbp),%rax
 126ed5c:	48 89 44 24 10       	mov    %rax,0x10(%rsp)
 126ed61:	48 8d 85 70 ea ff ff 	lea    -0x1590(%rbp),%rax
 126ed68:	48 89 44 24 08       	mov    %rax,0x8(%rsp)
 126ed6d:	48 89 0c 24          	mov    %rcx,(%rsp)
 126ed71:	48 c7 44 24 48 68 ae 	movq   $0x103ae68,0x48(%rsp)
 126ed78:	03 01 
 126ed7a:	48 c7 44 24 38 f8 ad 	movq   $0x103adf8,0x38(%rsp)
 126ed81:	03 01 
 126ed83:	48 c7 44 24 20 88 ad 	movq   $0x103ad88,0x20(%rsp)
 126ed8a:	03 01 
 126ed8c:	48 8d bd 78 ff ff ff 	lea    -0x88(%rbp),%rdi
 126ed93:	48 8b 9d 58 ff ff ff 	mov    -0xa8(%rbp),%rbx
 126ed9a:	48 89 de             	mov    %rbx,%rsi
 126ed9d:	4c 8b 7d b8          	mov    -0x48(%rbp),%r15
 126eda1:	4c 89 fa             	mov    %r15,%rdx
 126eda4:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 126edab:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 126edaf:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 126edb3:	c5 f8 77             	vzeroupper 
 126edb6:	e8 c5 3d 00 00       	call   1272b80 <br.encodeEntropySplitWireCandidateInternalAllocRecorded__anon_231681>
 126edbb:	44 0f b7 65 88       	movzwl -0x78(%rbp),%r12d
 126edc0:	4d 85 e4             	test   %r12,%r12
 126edc3:	0f 85 77 3a 00 00    	jne    1272840 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x86b0>
 126edc9:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 126edd0:	4c 8b 65 80          	mov    -0x80(%rbp),%r12
 126edd4:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126eddb:	49 89 f6             	mov    %rsi,%r14
 126edde:	4c 89 e2             	mov    %r12,%rdx
 126ede1:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 126ede5:	4d 89 e8             	mov    %r13,%r8
 126ede8:	e8 f3 f1 fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126eded:	48 8b 4b 10          	mov    0x10(%rbx),%rcx
 126edf1:	49 8b 3f             	mov    (%r15),%rdi
 126edf4:	4d 8b 4f 08          	mov    0x8(%r15),%r9
 126edf8:	48 8d 51 20          	lea    0x20(%rcx),%rdx
 126edfc:	4c 8b b9 20 30 02 00 	mov    0x23020(%rcx),%r15
 126ee03:	a8 01                	test   $0x1,%al
 126ee05:	0f 84 be 00 00 00    	je     126eec9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4d39>
 126ee0b:	4d 85 ff             	test   %r15,%r15
 126ee0e:	74 51                	je     126ee61 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4cd1>
 126ee10:	49 83 ff 01          	cmp    $0x1,%r15
 126ee14:	0f 85 0a 23 00 00    	jne    1271124 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f94>
 126ee1a:	31 c0                	xor    %eax,%eax
 126ee1c:	41 f6 c7 01          	test   $0x1,%r15b
 126ee20:	74 3f                	je     126ee61 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4cd1>
 126ee22:	48 69 f0 18 01 00 00 	imul   $0x118,%rax,%rsi
 126ee29:	44 0f b6 84 32 10 01 	movzbl 0x110(%rdx,%rsi,1),%r8d
 126ee30:	00 00 
 126ee32:	41 80 e0 0f          	and    $0xf,%r8b
 126ee36:	41 80 f8 07          	cmp    $0x7,%r8b
 126ee3a:	75 25                	jne    126ee61 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4cd1>
 126ee3c:	48 01 f2             	add    %rsi,%rdx
 126ee3f:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126ee43:	74 1c                	je     126ee61 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4cd1>
 126ee45:	4c 39 6a 38          	cmp    %r13,0x38(%rdx)
 126ee49:	75 16                	jne    126ee61 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4cd1>
 126ee4b:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 126ee4f:	48 39 94 c1 d0 32 02 	cmp    %rdx,0x232d0(%rcx,%rax,8)
 126ee56:	00 
 126ee57:	75 08                	jne    126ee61 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4cd1>
 126ee59:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126ee60:	00 
 126ee61:	4d 85 ed             	test   %r13,%r13
 126ee64:	74 11                	je     126ee77 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4ce7>
 126ee66:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126ee6a:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 126ee6e:	4c 89 ea             	mov    %r13,%rdx
 126ee71:	31 c9                	xor    %ecx,%ecx
 126ee73:	41 ff 51 18          	call   *0x18(%r9)
 126ee77:	c5 fc 10 85 e0 ea ff 	vmovups -0x1520(%rbp),%ymm0
 126ee7e:	ff 
 126ee7f:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 126ee86:	ff 
 126ee87:	c5 fc 10 85 70 ea ff 	vmovups -0x1590(%rbp),%ymm0
 126ee8e:	ff 
 126ee8f:	c5 fc 10 8d 90 ea ff 	vmovups -0x1570(%rbp),%ymm1
 126ee96:	ff 
 126ee97:	c5 fc 10 95 b0 ea ff 	vmovups -0x1550(%rbp),%ymm2
 126ee9e:	ff 
 126ee9f:	c5 fc 10 9d d0 ea ff 	vmovups -0x1530(%rbp),%ymm3
 126eea6:	ff 
 126eea7:	c5 fc 11 9d 80 fd ff 	vmovups %ymm3,-0x280(%rbp)
 126eeae:	ff 
 126eeaf:	c5 fc 11 95 60 fd ff 	vmovups %ymm2,-0x2a0(%rbp)
 126eeb6:	ff 
 126eeb7:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 126eebe:	ff 
 126eebf:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 126eec6:	ff 
 126eec7:	eb 6e                	jmp    126ef37 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4da7>
 126eec9:	4d 85 ff             	test   %r15,%r15
 126eecc:	74 4d                	je     126ef1b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4d8b>
 126eece:	49 83 ff 01          	cmp    $0x1,%r15
 126eed2:	0f 85 fc 22 00 00    	jne    12711d4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7044>
 126eed8:	31 c0                	xor    %eax,%eax
 126eeda:	41 f6 c7 01          	test   $0x1,%r15b
 126eede:	74 3b                	je     126ef1b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4d8b>
 126eee0:	4c 69 d0 18 01 00 00 	imul   $0x118,%rax,%r10
 126eee7:	46 0f b6 84 12 10 01 	movzbl 0x110(%rdx,%r10,1),%r8d
 126eeee:	00 00 
 126eef0:	41 80 e0 0f          	and    $0xf,%r8b
 126eef4:	41 80 f8 07          	cmp    $0x7,%r8b
 126eef8:	75 21                	jne    126ef1b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4d8b>
 126eefa:	4c 01 d2             	add    %r10,%rdx
 126eefd:	80 7a 40 00          	cmpb   $0x0,0x40(%rdx)
 126ef01:	74 18                	je     126ef1b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4d8b>
 126ef03:	4c 39 62 38          	cmp    %r12,0x38(%rdx)
 126ef07:	75 12                	jne    126ef1b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4d8b>
 126ef09:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 126ef10:	00 
 126ef11:	75 08                	jne    126ef1b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4d8b>
 126ef13:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126ef1a:	00 
 126ef1b:	4d 85 e4             	test   %r12,%r12
 126ef1e:	74 10                	je     126ef30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4da0>
 126ef20:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126ef24:	4c 89 f6             	mov    %r14,%rsi
 126ef27:	4c 89 e2             	mov    %r12,%rdx
 126ef2a:	31 c9                	xor    %ecx,%ecx
 126ef2c:	41 ff 51 18          	call   *0x18(%r9)
 126ef30:	4c 8b 75 c0          	mov    -0x40(%rbp),%r14
 126ef34:	4d 89 ec             	mov    %r13,%r12
 126ef37:	48 8d bd 00 fd ff ff 	lea    -0x300(%rbp),%rdi
 126ef3e:	4c 89 f6             	mov    %r14,%rsi
 126ef41:	4c 89 e2             	mov    %r12,%rdx
 126ef44:	48 8b 8d e0 fc ff ff 	mov    -0x320(%rbp),%rcx
 126ef4b:	4c 8b 85 e8 fc ff ff 	mov    -0x318(%rbp),%r8
 126ef52:	c5 f8 77             	vzeroupper 
 126ef55:	e8 86 f0 fc ff       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 126ef5a:	a8 01                	test   $0x1,%al
 126ef5c:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 126ef63:	0f 84 ac 02 00 00    	je     126f215 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5085>
 126ef69:	4c 89 75 a8          	mov    %r14,-0x58(%rbp)
 126ef6d:	c5 fc 10 85 90 fd ff 	vmovups -0x270(%rbp),%ymm0
 126ef74:	ff 
 126ef75:	48 8b 45 18          	mov    0x18(%rbp),%rax
 126ef79:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 126ef7e:	c5 fc 10 85 20 fd ff 	vmovups -0x2e0(%rbp),%ymm0
 126ef85:	ff 
 126ef86:	c5 fc 10 8d 40 fd ff 	vmovups -0x2c0(%rbp),%ymm1
 126ef8d:	ff 
 126ef8e:	c5 fc 10 95 60 fd ff 	vmovups -0x2a0(%rbp),%ymm2
 126ef95:	ff 
 126ef96:	c5 fc 10 9d 80 fd ff 	vmovups -0x280(%rbp),%ymm3
 126ef9d:	ff 
 126ef9e:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 126efa3:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 126efa8:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 126efad:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 126efb1:	80 bd f0 df ff ff 00 	cmpb   $0x0,-0x2010(%rbp)
 126efb8:	74 5c                	je     126f016 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4e86>
 126efba:	48 8b 95 c8 df ff ff 	mov    -0x2038(%rbp),%rdx
 126efc1:	4c 8b b5 d0 df ff ff 	mov    -0x2030(%rbp),%r14
 126efc8:	4c 8b bd d8 df ff ff 	mov    -0x2028(%rbp),%r15
 126efcf:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 126efd3:	4c 8b 28             	mov    (%rax),%r13
 126efd6:	48 8b 58 08          	mov    0x8(%rax),%rbx
 126efda:	48 85 d2             	test   %rdx,%rdx
 126efdd:	74 1d                	je     126effc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4e6c>
 126efdf:	48 8b b5 c0 df ff ff 	mov    -0x2040(%rbp),%rsi
 126efe6:	48 c1 e2 02          	shl    $0x2,%rdx
 126efea:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126efee:	4c 89 ef             	mov    %r13,%rdi
 126eff1:	b9 02 00 00 00       	mov    $0x2,%ecx
 126eff6:	c5 f8 77             	vzeroupper 
 126eff9:	ff 53 18             	call   *0x18(%rbx)
 126effc:	4d 85 ff             	test   %r15,%r15
 126efff:	74 15                	je     126f016 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4e86>
 126f001:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f005:	4c 89 ef             	mov    %r13,%rdi
 126f008:	4c 89 f6             	mov    %r14,%rsi
 126f00b:	4c 89 fa             	mov    %r15,%rdx
 126f00e:	31 c9                	xor    %ecx,%ecx
 126f010:	c5 f8 77             	vzeroupper 
 126f013:	ff 53 18             	call   *0x18(%rbx)
 126f016:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126f01a:	48 8d 85 c0 df ff ff 	lea    -0x2040(%rbp),%rax
 126f021:	c5 fc 11 40 18       	vmovups %ymm0,0x18(%rax)
 126f026:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 126f02a:	48 8d 9d 08 e3 ff ff 	lea    -0x1cf8(%rbp),%rbx
 126f031:	80 bd 38 e3 ff ff 00 	cmpb   $0x0,-0x1cc8(%rbp)
 126f038:	74 6b                	je     126f0a5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4f15>
 126f03a:	48 8b 95 10 e3 ff ff 	mov    -0x1cf0(%rbp),%rdx
 126f041:	48 8b b5 18 e3 ff ff 	mov    -0x1ce8(%rbp),%rsi
 126f048:	4c 8b bd 20 e3 ff ff 	mov    -0x1ce0(%rbp),%r15
 126f04f:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 126f053:	4c 8b 28             	mov    (%rax),%r13
 126f056:	4c 8b 70 08          	mov    0x8(%rax),%r14
 126f05a:	48 85 d2             	test   %rdx,%rdx
 126f05d:	74 2a                	je     126f089 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4ef9>
 126f05f:	48 89 75 90          	mov    %rsi,-0x70(%rbp)
 126f063:	48 8b b5 08 e3 ff ff 	mov    -0x1cf8(%rbp),%rsi
 126f06a:	48 c1 e2 02          	shl    $0x2,%rdx
 126f06e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f072:	4c 89 ef             	mov    %r13,%rdi
 126f075:	b9 02 00 00 00       	mov    $0x2,%ecx
 126f07a:	c5 f8 77             	vzeroupper 
 126f07d:	41 ff 56 18          	call   *0x18(%r14)
 126f081:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 126f085:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126f089:	4d 85 ff             	test   %r15,%r15
 126f08c:	74 17                	je     126f0a5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4f15>
 126f08e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f092:	4c 89 ef             	mov    %r13,%rdi
 126f095:	4c 89 fa             	mov    %r15,%rdx
 126f098:	31 c9                	xor    %ecx,%ecx
 126f09a:	c5 f8 77             	vzeroupper 
 126f09d:	41 ff 56 18          	call   *0x18(%r14)
 126f0a1:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126f0a5:	c5 fc 11 43 18       	vmovups %ymm0,0x18(%rbx)
 126f0aa:	c5 fc 11 03          	vmovups %ymm0,(%rbx)
 126f0ae:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 126f0b5:	0f 84 cc 00 00 00    	je     126f187 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4ff7>
 126f0bb:	48 8b 95 28 fe ff ff 	mov    -0x1d8(%rbp),%rdx
 126f0c2:	48 8b b5 30 fe ff ff 	mov    -0x1d0(%rbp),%rsi
 126f0c9:	4c 8b bd 38 fe ff ff 	mov    -0x1c8(%rbp),%r15
 126f0d0:	48 8b 85 50 fe ff ff 	mov    -0x1b0(%rbp),%rax
 126f0d7:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 126f0de:	4c 8b b5 58 fe ff ff 	mov    -0x1a8(%rbp),%r14
 126f0e5:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 126f0ec:	48 89 85 60 ff ff ff 	mov    %rax,-0xa0(%rbp)
 126f0f3:	48 8b 85 68 fe ff ff 	mov    -0x198(%rbp),%rax
 126f0fa:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 126f0fe:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 126f102:	4c 8b 28             	mov    (%rax),%r13
 126f105:	48 8b 58 08          	mov    0x8(%rax),%rbx
 126f109:	48 85 d2             	test   %rdx,%rdx
 126f10c:	74 25                	je     126f133 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4fa3>
 126f10e:	48 89 75 c0          	mov    %rsi,-0x40(%rbp)
 126f112:	48 8b b5 20 fe ff ff 	mov    -0x1e0(%rbp),%rsi
 126f119:	48 c1 e2 02          	shl    $0x2,%rdx
 126f11d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f121:	4c 89 ef             	mov    %r13,%rdi
 126f124:	b9 02 00 00 00       	mov    $0x2,%ecx
 126f129:	c5 f8 77             	vzeroupper 
 126f12c:	ff 53 18             	call   *0x18(%rbx)
 126f12f:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 126f133:	4d 85 ff             	test   %r15,%r15
 126f136:	74 12                	je     126f14a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4fba>
 126f138:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f13c:	4c 89 ef             	mov    %r13,%rdi
 126f13f:	4c 89 fa             	mov    %r15,%rdx
 126f142:	31 c9                	xor    %ecx,%ecx
 126f144:	c5 f8 77             	vzeroupper 
 126f147:	ff 53 18             	call   *0x18(%rbx)
 126f14a:	4d 85 f6             	test   %r14,%r14
 126f14d:	74 19                	je     126f168 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4fd8>
 126f14f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f153:	4c 89 ef             	mov    %r13,%rdi
 126f156:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 126f15d:	4c 89 f2             	mov    %r14,%rdx
 126f160:	31 c9                	xor    %ecx,%ecx
 126f162:	c5 f8 77             	vzeroupper 
 126f165:	ff 53 18             	call   *0x18(%rbx)
 126f168:	48 8b 55 90          	mov    -0x70(%rbp),%rdx
 126f16c:	48 85 d2             	test   %rdx,%rdx
 126f16f:	74 16                	je     126f187 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4ff7>
 126f171:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f175:	4c 89 ef             	mov    %r13,%rdi
 126f178:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 126f17f:	31 c9                	xor    %ecx,%ecx
 126f181:	c5 f8 77             	vzeroupper 
 126f184:	ff 53 18             	call   *0x18(%rbx)
 126f187:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 126f18e:	74 5c                	je     126f1ec <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x505c>
 126f190:	48 8b 95 28 ff ff ff 	mov    -0xd8(%rbp),%rdx
 126f197:	4c 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%r14
 126f19e:	4c 8b bd 38 ff ff ff 	mov    -0xc8(%rbp),%r15
 126f1a5:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 126f1a9:	4c 8b 28             	mov    (%rax),%r13
 126f1ac:	48 8b 58 08          	mov    0x8(%rax),%rbx
 126f1b0:	48 85 d2             	test   %rdx,%rdx
 126f1b3:	74 1d                	je     126f1d2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5042>
 126f1b5:	48 8b b5 20 ff ff ff 	mov    -0xe0(%rbp),%rsi
 126f1bc:	48 c1 e2 02          	shl    $0x2,%rdx
 126f1c0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f1c4:	4c 89 ef             	mov    %r13,%rdi
 126f1c7:	b9 02 00 00 00       	mov    $0x2,%ecx
 126f1cc:	c5 f8 77             	vzeroupper 
 126f1cf:	ff 53 18             	call   *0x18(%rbx)
 126f1d2:	4d 85 ff             	test   %r15,%r15
 126f1d5:	74 15                	je     126f1ec <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x505c>
 126f1d7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f1db:	4c 89 ef             	mov    %r13,%rdi
 126f1de:	4c 89 f6             	mov    %r14,%rsi
 126f1e1:	4c 89 fa             	mov    %r15,%rdx
 126f1e4:	31 c9                	xor    %ecx,%ecx
 126f1e6:	c5 f8 77             	vzeroupper 
 126f1e9:	ff 53 18             	call   *0x18(%rbx)
 126f1ec:	48 8d bd c0 fd ff ff 	lea    -0x240(%rbp),%rdi
 126f1f3:	c5 f8 77             	vzeroupper 
 126f1f6:	e8 75 7f 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 126f1fb:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 126f1ff:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 126f205:	48 8b 4d a8          	mov    -0x58(%rbp),%rcx
 126f209:	48 89 08             	mov    %rcx,(%rax)
 126f20c:	4c 89 60 08          	mov    %r12,0x8(%rax)
 126f210:	e9 da 02 00 00       	jmp    126f4ef <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x535f>
 126f215:	48 8b 48 10          	mov    0x10(%rax),%rcx
 126f219:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 126f21d:	48 8b 38             	mov    (%rax),%rdi
 126f220:	48 8b 40 08          	mov    0x8(%rax),%rax
 126f224:	48 8b b1 20 30 02 00 	mov    0x23020(%rcx),%rsi
 126f22b:	48 85 f6             	test   %rsi,%rsi
 126f22e:	74 51                	je     126f281 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x50f1>
 126f230:	48 83 fe 01          	cmp    $0x1,%rsi
 126f234:	0f 85 c7 02 00 00    	jne    126f501 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5371>
 126f23a:	31 d2                	xor    %edx,%edx
 126f23c:	40 f6 c6 01          	test   $0x1,%sil
 126f240:	74 3f                	je     126f281 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x50f1>
 126f242:	48 8d 71 20          	lea    0x20(%rcx),%rsi
 126f246:	4c 69 c2 18 01 00 00 	imul   $0x118,%rdx,%r8
 126f24d:	46 0f b6 8c 06 10 01 	movzbl 0x110(%rsi,%r8,1),%r9d
 126f254:	00 00 
 126f256:	41 80 e1 0f          	and    $0xf,%r9b
 126f25a:	41 80 f9 07          	cmp    $0x7,%r9b
 126f25e:	75 21                	jne    126f281 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x50f1>
 126f260:	4c 01 c6             	add    %r8,%rsi
 126f263:	80 7e 40 00          	cmpb   $0x0,0x40(%rsi)
 126f267:	74 18                	je     126f281 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x50f1>
 126f269:	4c 39 66 38          	cmp    %r12,0x38(%rsi)
 126f26d:	75 12                	jne    126f281 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x50f1>
 126f26f:	4c 39 b4 d1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rdx,8)
 126f276:	00 
 126f277:	75 08                	jne    126f281 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x50f1>
 126f279:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 126f280:	00 
 126f281:	4d 85 e4             	test   %r12,%r12
 126f284:	74 0f                	je     126f295 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5105>
 126f286:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f28a:	4c 89 f6             	mov    %r14,%rsi
 126f28d:	4c 89 e2             	mov    %r12,%rdx
 126f290:	31 c9                	xor    %ecx,%ecx
 126f292:	ff 50 18             	call   *0x18(%rax)
 126f295:	80 bd f0 df ff ff 00 	cmpb   $0x0,-0x2010(%rbp)
 126f29c:	74 5a                	je     126f2f8 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5168>
 126f29e:	48 8b 95 c8 df ff ff 	mov    -0x2038(%rbp),%rdx
 126f2a5:	48 8b 9d d0 df ff ff 	mov    -0x2030(%rbp),%rbx
 126f2ac:	4c 8b b5 d8 df ff ff 	mov    -0x2028(%rbp),%r14
 126f2b3:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 126f2b7:	4c 8b 38             	mov    (%rax),%r15
 126f2ba:	4c 8b 60 08          	mov    0x8(%rax),%r12
 126f2be:	48 85 d2             	test   %rdx,%rdx
 126f2c1:	74 1c                	je     126f2df <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x514f>
 126f2c3:	48 8b b5 c0 df ff ff 	mov    -0x2040(%rbp),%rsi
 126f2ca:	48 c1 e2 02          	shl    $0x2,%rdx
 126f2ce:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f2d2:	4c 89 ff             	mov    %r15,%rdi
 126f2d5:	b9 02 00 00 00       	mov    $0x2,%ecx
 126f2da:	41 ff 54 24 18       	call   *0x18(%r12)
 126f2df:	4d 85 f6             	test   %r14,%r14
 126f2e2:	74 14                	je     126f2f8 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5168>
 126f2e4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f2e8:	4c 89 ff             	mov    %r15,%rdi
 126f2eb:	48 89 de             	mov    %rbx,%rsi
 126f2ee:	4c 89 f2             	mov    %r14,%rdx
 126f2f1:	31 c9                	xor    %ecx,%ecx
 126f2f3:	41 ff 54 24 18       	call   *0x18(%r12)
 126f2f8:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126f2fc:	48 8d 85 c0 df ff ff 	lea    -0x2040(%rbp),%rax
 126f303:	c5 fc 11 40 18       	vmovups %ymm0,0x18(%rax)
 126f308:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 126f30c:	4c 8d a5 08 e3 ff ff 	lea    -0x1cf8(%rbp),%r12
 126f313:	80 bd 38 e3 ff ff 00 	cmpb   $0x0,-0x1cc8(%rbp)
 126f31a:	74 66                	je     126f382 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x51f2>
 126f31c:	48 8b 95 10 e3 ff ff 	mov    -0x1cf0(%rbp),%rdx
 126f323:	48 8b 9d 18 e3 ff ff 	mov    -0x1ce8(%rbp),%rbx
 126f32a:	4c 8b b5 20 e3 ff ff 	mov    -0x1ce0(%rbp),%r14
 126f331:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 126f335:	4c 8b 38             	mov    (%rax),%r15
 126f338:	4c 8b 68 08          	mov    0x8(%rax),%r13
 126f33c:	48 85 d2             	test   %rdx,%rdx
 126f33f:	74 22                	je     126f363 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x51d3>
 126f341:	48 8b b5 08 e3 ff ff 	mov    -0x1cf8(%rbp),%rsi
 126f348:	48 c1 e2 02          	shl    $0x2,%rdx
 126f34c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f350:	4c 89 ff             	mov    %r15,%rdi
 126f353:	b9 02 00 00 00       	mov    $0x2,%ecx
 126f358:	c5 f8 77             	vzeroupper 
 126f35b:	41 ff 55 18          	call   *0x18(%r13)
 126f35f:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126f363:	4d 85 f6             	test   %r14,%r14
 126f366:	74 1a                	je     126f382 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x51f2>
 126f368:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f36c:	4c 89 ff             	mov    %r15,%rdi
 126f36f:	48 89 de             	mov    %rbx,%rsi
 126f372:	4c 89 f2             	mov    %r14,%rdx
 126f375:	31 c9                	xor    %ecx,%ecx
 126f377:	c5 f8 77             	vzeroupper 
 126f37a:	41 ff 55 18          	call   *0x18(%r13)
 126f37e:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126f382:	c4 c1 7c 11 44 24 18 	vmovups %ymm0,0x18(%r12)
 126f389:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 126f38f:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 126f396:	0f 84 c7 00 00 00    	je     126f463 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x52d3>
 126f39c:	48 8b 95 28 fe ff ff 	mov    -0x1d8(%rbp),%rdx
 126f3a3:	48 8b b5 30 fe ff ff 	mov    -0x1d0(%rbp),%rsi
 126f3aa:	4c 8b a5 38 fe ff ff 	mov    -0x1c8(%rbp),%r12
 126f3b1:	48 8b 85 50 fe ff ff 	mov    -0x1b0(%rbp),%rax
 126f3b8:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 126f3bc:	4c 8b ad 58 fe ff ff 	mov    -0x1a8(%rbp),%r13
 126f3c3:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 126f3ca:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 126f3ce:	4c 8b b5 68 fe ff ff 	mov    -0x198(%rbp),%r14
 126f3d5:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 126f3d9:	4c 8b 38             	mov    (%rax),%r15
 126f3dc:	48 8b 58 08          	mov    0x8(%rax),%rbx
 126f3e0:	48 85 d2             	test   %rdx,%rdx
 126f3e3:	74 31                	je     126f416 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5286>
 126f3e5:	4c 89 b5 60 ff ff ff 	mov    %r14,-0xa0(%rbp)
 126f3ec:	49 89 f6             	mov    %rsi,%r14
 126f3ef:	48 8b b5 20 fe ff ff 	mov    -0x1e0(%rbp),%rsi
 126f3f6:	48 c1 e2 02          	shl    $0x2,%rdx
 126f3fa:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f3fe:	4c 89 ff             	mov    %r15,%rdi
 126f401:	b9 02 00 00 00       	mov    $0x2,%ecx
 126f406:	c5 f8 77             	vzeroupper 
 126f409:	ff 53 18             	call   *0x18(%rbx)
 126f40c:	4c 89 f6             	mov    %r14,%rsi
 126f40f:	4c 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%r14
 126f416:	4d 85 e4             	test   %r12,%r12
 126f419:	74 12                	je     126f42d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x529d>
 126f41b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f41f:	4c 89 ff             	mov    %r15,%rdi
 126f422:	4c 89 e2             	mov    %r12,%rdx
 126f425:	31 c9                	xor    %ecx,%ecx
 126f427:	c5 f8 77             	vzeroupper 
 126f42a:	ff 53 18             	call   *0x18(%rbx)
 126f42d:	4d 85 ed             	test   %r13,%r13
 126f430:	74 16                	je     126f448 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x52b8>
 126f432:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f436:	4c 89 ff             	mov    %r15,%rdi
 126f439:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 126f43d:	4c 89 ea             	mov    %r13,%rdx
 126f440:	31 c9                	xor    %ecx,%ecx
 126f442:	c5 f8 77             	vzeroupper 
 126f445:	ff 53 18             	call   *0x18(%rbx)
 126f448:	4d 85 f6             	test   %r14,%r14
 126f44b:	74 16                	je     126f463 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x52d3>
 126f44d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f451:	4c 89 ff             	mov    %r15,%rdi
 126f454:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 126f458:	4c 89 f2             	mov    %r14,%rdx
 126f45b:	31 c9                	xor    %ecx,%ecx
 126f45d:	c5 f8 77             	vzeroupper 
 126f460:	ff 53 18             	call   *0x18(%rbx)
 126f463:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 126f46a:	74 60                	je     126f4cc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x533c>
 126f46c:	48 8b 95 28 ff ff ff 	mov    -0xd8(%rbp),%rdx
 126f473:	48 8b 9d 30 ff ff ff 	mov    -0xd0(%rbp),%rbx
 126f47a:	4c 8b b5 38 ff ff ff 	mov    -0xc8(%rbp),%r14
 126f481:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 126f485:	4c 8b 38             	mov    (%rax),%r15
 126f488:	4c 8b 60 08          	mov    0x8(%rax),%r12
 126f48c:	48 85 d2             	test   %rdx,%rdx
 126f48f:	74 1f                	je     126f4b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5320>
 126f491:	48 8b b5 20 ff ff ff 	mov    -0xe0(%rbp),%rsi
 126f498:	48 c1 e2 02          	shl    $0x2,%rdx
 126f49c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f4a0:	4c 89 ff             	mov    %r15,%rdi
 126f4a3:	b9 02 00 00 00       	mov    $0x2,%ecx
 126f4a8:	c5 f8 77             	vzeroupper 
 126f4ab:	41 ff 54 24 18       	call   *0x18(%r12)
 126f4b0:	4d 85 f6             	test   %r14,%r14
 126f4b3:	74 17                	je     126f4cc <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x533c>
 126f4b5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126f4b9:	4c 89 ff             	mov    %r15,%rdi
 126f4bc:	48 89 de             	mov    %rbx,%rsi
 126f4bf:	4c 89 f2             	mov    %r14,%rdx
 126f4c2:	31 c9                	xor    %ecx,%ecx
 126f4c4:	c5 f8 77             	vzeroupper 
 126f4c7:	41 ff 54 24 18       	call   *0x18(%r12)
 126f4cc:	48 8d bd c0 fd ff ff 	lea    -0x240(%rbp),%rdi
 126f4d3:	c5 f8 77             	vzeroupper 
 126f4d6:	e8 95 7c 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 126f4db:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 126f4df:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 126f4e3:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 126f4e7:	48 c7 40 10 00 00 00 	movq   $0x0,0x10(%rax)
 126f4ee:	00 
 126f4ef:	48 81 c4 d8 41 00 00 	add    $0x41d8,%rsp
 126f4f6:	5b                   	pop    %rbx
 126f4f7:	41 5c                	pop    %r12
 126f4f9:	41 5d                	pop    %r13
 126f4fb:	41 5e                	pop    %r14
 126f4fd:	41 5f                	pop    %r15
 126f4ff:	5d                   	pop    %rbp
 126f500:	c3                   	ret    
 126f501:	49 89 f0             	mov    %rsi,%r8
 126f504:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126f508:	4c 8d 49 58          	lea    0x58(%rcx),%r9
 126f50c:	31 d2                	xor    %edx,%edx
 126f50e:	eb 14                	jmp    126f524 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5394>
 126f510:	48 83 c2 02          	add    $0x2,%rdx
 126f514:	49 81 c1 30 02 00 00 	add    $0x230,%r9
 126f51b:	49 39 d0             	cmp    %rdx,%r8
 126f51e:	0f 84 18 fd ff ff    	je     126f23c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x50ac>
 126f524:	45 0f b6 91 d8 00 00 	movzbl 0xd8(%r9),%r10d
 126f52b:	00 
 126f52c:	41 80 e2 0f          	and    $0xf,%r10b
 126f530:	41 80 fa 07          	cmp    $0x7,%r10b
 126f534:	75 2a                	jne    126f560 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x53d0>
 126f536:	41 80 79 08 00       	cmpb   $0x0,0x8(%r9)
 126f53b:	74 23                	je     126f560 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x53d0>
 126f53d:	4d 39 21             	cmp    %r12,(%r9)
 126f540:	75 1e                	jne    126f560 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x53d0>
 126f542:	4c 39 b4 d1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rdx,8)
 126f549:	00 
 126f54a:	75 14                	jne    126f560 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x53d0>
 126f54c:	c6 84 11 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rdx,1)
 126f553:	00 
 126f554:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126f55b:	00 00 00 00 00 
 126f560:	45 0f b6 91 f0 01 00 	movzbl 0x1f0(%r9),%r10d
 126f567:	00 
 126f568:	41 80 e2 0f          	and    $0xf,%r10b
 126f56c:	41 80 fa 07          	cmp    $0x7,%r10b
 126f570:	75 9e                	jne    126f510 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5380>
 126f572:	41 80 b9 20 01 00 00 	cmpb   $0x0,0x120(%r9)
 126f579:	00 
 126f57a:	74 94                	je     126f510 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5380>
 126f57c:	4d 39 a1 18 01 00 00 	cmp    %r12,0x118(%r9)
 126f583:	75 8b                	jne    126f510 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5380>
 126f585:	4c 39 b4 d1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rdx,8)
 126f58c:	00 
 126f58d:	75 81                	jne    126f510 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5380>
 126f58f:	c6 84 11 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rdx,1)
 126f596:	00 
 126f597:	e9 74 ff ff ff       	jmp    126f510 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5380>
 126f59c:	49 89 dd             	mov    %rbx,%r13
 126f59f:	80 bd b8 df ff ff 00 	cmpb   $0x0,-0x2048(%rbp)
 126f5a6:	4c 8b 65 b8          	mov    -0x48(%rbp),%r12
 126f5aa:	0f 85 b0 d6 ff ff    	jne    126cc60 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2ad0>
 126f5b0:	e9 a5 de ff ff       	jmp    126d45a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x32ca>
 126f5b5:	49 89 f0             	mov    %rsi,%r8
 126f5b8:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126f5bc:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126f5c0:	31 c0                	xor    %eax,%eax
 126f5c2:	eb 20                	jmp    126f5e4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5454>
 126f5c4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126f5cb:	00 00 00 00 00 
 126f5d0:	48 83 c0 02          	add    $0x2,%rax
 126f5d4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126f5db:	49 39 c0             	cmp    %rax,%r8
 126f5de:	0f 84 55 c0 ff ff    	je     126b639 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x14a9>
 126f5e4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126f5eb:	00 
 126f5ec:	41 80 e3 0f          	and    $0xf,%r11b
 126f5f0:	41 80 fb 07          	cmp    $0x7,%r11b
 126f5f4:	75 2a                	jne    126f620 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5490>
 126f5f6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126f5fb:	74 23                	je     126f620 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5490>
 126f5fd:	49 39 1a             	cmp    %rbx,(%r10)
 126f600:	75 1e                	jne    126f620 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5490>
 126f602:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126f606:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 126f60d:	00 
 126f60e:	75 10                	jne    126f620 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5490>
 126f610:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126f617:	00 
 126f618:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 126f61f:	00 
 126f620:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126f627:	00 
 126f628:	41 80 e3 0f          	and    $0xf,%r11b
 126f62c:	41 80 fb 07          	cmp    $0x7,%r11b
 126f630:	75 9e                	jne    126f5d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5440>
 126f632:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126f639:	00 
 126f63a:	74 94                	je     126f5d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5440>
 126f63c:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 126f643:	75 8b                	jne    126f5d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5440>
 126f645:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126f649:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 126f650:	00 
 126f651:	0f 85 79 ff ff ff    	jne    126f5d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5440>
 126f657:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126f65e:	00 
 126f65f:	e9 6c ff ff ff       	jmp    126f5d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5440>
 126f664:	49 89 f0             	mov    %rsi,%r8
 126f667:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126f66b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126f66f:	31 c0                	xor    %eax,%eax
 126f671:	eb 21                	jmp    126f694 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5504>
 126f673:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 126f67a:	84 00 00 00 00 00 
 126f680:	48 83 c0 02          	add    $0x2,%rax
 126f684:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126f68b:	49 39 c0             	cmp    %rax,%r8
 126f68e:	0f 84 80 c0 ff ff    	je     126b714 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1584>
 126f694:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126f69b:	00 
 126f69c:	41 80 e3 0f          	and    $0xf,%r11b
 126f6a0:	41 80 fb 07          	cmp    $0x7,%r11b
 126f6a4:	75 2a                	jne    126f6d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5540>
 126f6a6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126f6ab:	74 23                	je     126f6d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5540>
 126f6ad:	4d 39 22             	cmp    %r12,(%r10)
 126f6b0:	75 1e                	jne    126f6d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5540>
 126f6b2:	4c 39 ac c1 d0 32 02 	cmp    %r13,0x232d0(%rcx,%rax,8)
 126f6b9:	00 
 126f6ba:	75 14                	jne    126f6d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5540>
 126f6bc:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126f6c3:	00 
 126f6c4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126f6cb:	00 00 00 00 00 
 126f6d0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126f6d7:	00 
 126f6d8:	41 80 e3 0f          	and    $0xf,%r11b
 126f6dc:	41 80 fb 07          	cmp    $0x7,%r11b
 126f6e0:	75 9e                	jne    126f680 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x54f0>
 126f6e2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126f6e9:	00 
 126f6ea:	74 94                	je     126f680 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x54f0>
 126f6ec:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 126f6f3:	75 8b                	jne    126f680 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x54f0>
 126f6f5:	4c 39 ac c1 d8 32 02 	cmp    %r13,0x232d8(%rcx,%rax,8)
 126f6fc:	00 
 126f6fd:	75 81                	jne    126f680 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x54f0>
 126f6ff:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126f706:	00 
 126f707:	e9 74 ff ff ff       	jmp    126f680 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x54f0>
 126f70c:	4d 89 c8             	mov    %r9,%r8
 126f70f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126f713:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126f717:	31 c0                	xor    %eax,%eax
 126f719:	eb 19                	jmp    126f734 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x55a4>
 126f71b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 126f720:	48 83 c0 02          	add    $0x2,%rax
 126f724:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126f72b:	49 39 c0             	cmp    %rax,%r8
 126f72e:	0f 84 e2 c1 ff ff    	je     126b916 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1786>
 126f734:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126f73b:	00 
 126f73c:	41 80 e3 0f          	and    $0xf,%r11b
 126f740:	41 80 fb 07          	cmp    $0x7,%r11b
 126f744:	75 2a                	jne    126f770 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x55e0>
 126f746:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126f74b:	74 23                	je     126f770 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x55e0>
 126f74d:	49 39 12             	cmp    %rdx,(%r10)
 126f750:	75 1e                	jne    126f770 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x55e0>
 126f752:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126f759:	00 
 126f75a:	75 14                	jne    126f770 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x55e0>
 126f75c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126f763:	00 
 126f764:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126f76b:	00 00 00 00 00 
 126f770:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126f777:	00 
 126f778:	41 80 e3 0f          	and    $0xf,%r11b
 126f77c:	41 80 fb 07          	cmp    $0x7,%r11b
 126f780:	75 9e                	jne    126f720 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5590>
 126f782:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126f789:	00 
 126f78a:	74 94                	je     126f720 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5590>
 126f78c:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 126f793:	75 8b                	jne    126f720 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5590>
 126f795:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 126f79c:	00 
 126f79d:	75 81                	jne    126f720 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5590>
 126f79f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126f7a6:	00 
 126f7a7:	e9 74 ff ff ff       	jmp    126f720 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5590>
 126f7ac:	4d 89 c8             	mov    %r9,%r8
 126f7af:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126f7b3:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126f7b7:	31 c0                	xor    %eax,%eax
 126f7b9:	eb 19                	jmp    126f7d4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5644>
 126f7bb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 126f7c0:	48 83 c0 02          	add    $0x2,%rax
 126f7c4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126f7cb:	49 39 c0             	cmp    %rax,%r8
 126f7ce:	0f 84 0c c2 ff ff    	je     126b9e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1850>
 126f7d4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126f7db:	00 
 126f7dc:	41 80 e3 0f          	and    $0xf,%r11b
 126f7e0:	41 80 fb 07          	cmp    $0x7,%r11b
 126f7e4:	75 2a                	jne    126f810 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5680>
 126f7e6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126f7eb:	74 23                	je     126f810 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5680>
 126f7ed:	49 39 12             	cmp    %rdx,(%r10)
 126f7f0:	75 1e                	jne    126f810 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5680>
 126f7f2:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126f7f9:	00 
 126f7fa:	75 14                	jne    126f810 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5680>
 126f7fc:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126f803:	00 
 126f804:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126f80b:	00 00 00 00 00 
 126f810:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126f817:	00 
 126f818:	41 80 e3 0f          	and    $0xf,%r11b
 126f81c:	41 80 fb 07          	cmp    $0x7,%r11b
 126f820:	75 9e                	jne    126f7c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5630>
 126f822:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126f829:	00 
 126f82a:	74 94                	je     126f7c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5630>
 126f82c:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 126f833:	75 8b                	jne    126f7c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5630>
 126f835:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 126f83c:	00 
 126f83d:	75 81                	jne    126f7c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5630>
 126f83f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126f846:	00 
 126f847:	e9 74 ff ff ff       	jmp    126f7c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5630>
 126f84c:	49 89 f0             	mov    %rsi,%r8
 126f84f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126f853:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126f857:	31 c0                	xor    %eax,%eax
 126f859:	eb 19                	jmp    126f874 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x56e4>
 126f85b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 126f860:	48 83 c0 02          	add    $0x2,%rax
 126f864:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126f86b:	49 39 c0             	cmp    %rax,%r8
 126f86e:	0f 84 55 c3 ff ff    	je     126bbc9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1a39>
 126f874:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126f87b:	00 
 126f87c:	41 80 e3 0f          	and    $0xf,%r11b
 126f880:	41 80 fb 07          	cmp    $0x7,%r11b
 126f884:	75 2a                	jne    126f8b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5720>
 126f886:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126f88b:	74 23                	je     126f8b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5720>
 126f88d:	49 39 1a             	cmp    %rbx,(%r10)
 126f890:	75 1e                	jne    126f8b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5720>
 126f892:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 126f899:	00 
 126f89a:	75 14                	jne    126f8b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5720>
 126f89c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126f8a3:	00 
 126f8a4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126f8ab:	00 00 00 00 00 
 126f8b0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126f8b7:	00 
 126f8b8:	41 80 e3 0f          	and    $0xf,%r11b
 126f8bc:	41 80 fb 07          	cmp    $0x7,%r11b
 126f8c0:	75 9e                	jne    126f860 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x56d0>
 126f8c2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126f8c9:	00 
 126f8ca:	74 94                	je     126f860 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x56d0>
 126f8cc:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 126f8d3:	75 8b                	jne    126f860 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x56d0>
 126f8d5:	4c 39 bc c1 d8 32 02 	cmp    %r15,0x232d8(%rcx,%rax,8)
 126f8dc:	00 
 126f8dd:	75 81                	jne    126f860 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x56d0>
 126f8df:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126f8e6:	00 
 126f8e7:	e9 74 ff ff ff       	jmp    126f860 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x56d0>
 126f8ec:	49 89 f0             	mov    %rsi,%r8
 126f8ef:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126f8f3:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126f8f7:	31 c0                	xor    %eax,%eax
 126f8f9:	eb 19                	jmp    126f914 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5784>
 126f8fb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 126f900:	48 83 c0 02          	add    $0x2,%rax
 126f904:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126f90b:	49 39 c0             	cmp    %rax,%r8
 126f90e:	0f 84 50 c8 ff ff    	je     126c164 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1fd4>
 126f914:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126f91b:	00 
 126f91c:	41 80 e3 0f          	and    $0xf,%r11b
 126f920:	41 80 fb 07          	cmp    $0x7,%r11b
 126f924:	75 2a                	jne    126f950 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x57c0>
 126f926:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126f92b:	74 23                	je     126f950 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x57c0>
 126f92d:	4d 39 22             	cmp    %r12,(%r10)
 126f930:	75 1e                	jne    126f950 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x57c0>
 126f932:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126f936:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 126f93d:	00 
 126f93e:	75 10                	jne    126f950 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x57c0>
 126f940:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126f947:	00 
 126f948:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 126f94f:	00 
 126f950:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126f957:	00 
 126f958:	41 80 e3 0f          	and    $0xf,%r11b
 126f95c:	41 80 fb 07          	cmp    $0x7,%r11b
 126f960:	75 9e                	jne    126f900 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5770>
 126f962:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126f969:	00 
 126f96a:	74 94                	je     126f900 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5770>
 126f96c:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 126f973:	75 8b                	jne    126f900 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5770>
 126f975:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126f979:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 126f980:	00 
 126f981:	0f 85 79 ff ff ff    	jne    126f900 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5770>
 126f987:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126f98e:	00 
 126f98f:	e9 6c ff ff ff       	jmp    126f900 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5770>
 126f994:	4d 89 c8             	mov    %r9,%r8
 126f997:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126f99b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126f99f:	31 c0                	xor    %eax,%eax
 126f9a1:	eb 21                	jmp    126f9c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5834>
 126f9a3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 126f9aa:	84 00 00 00 00 00 
 126f9b0:	48 83 c0 02          	add    $0x2,%rax
 126f9b4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126f9bb:	49 39 c0             	cmp    %rax,%r8
 126f9be:	0f 84 bf c6 ff ff    	je     126c083 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1ef3>
 126f9c4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126f9cb:	00 
 126f9cc:	41 80 e3 0f          	and    $0xf,%r11b
 126f9d0:	41 80 fb 07          	cmp    $0x7,%r11b
 126f9d4:	75 2a                	jne    126fa00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5870>
 126f9d6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126f9db:	74 23                	je     126fa00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5870>
 126f9dd:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 126f9e1:	49 39 12             	cmp    %rdx,(%r10)
 126f9e4:	75 1a                	jne    126fa00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5870>
 126f9e6:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126f9ea:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 126f9f1:	00 
 126f9f2:	75 0c                	jne    126fa00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5870>
 126f9f4:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126f9fb:	00 
 126f9fc:	0f 1f 40 00          	nopl   0x0(%rax)
 126fa00:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126fa07:	00 
 126fa08:	41 80 e3 0f          	and    $0xf,%r11b
 126fa0c:	41 80 fb 07          	cmp    $0x7,%r11b
 126fa10:	75 9e                	jne    126f9b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5820>
 126fa12:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126fa19:	00 
 126fa1a:	74 94                	je     126f9b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5820>
 126fa1c:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 126fa20:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 126fa27:	75 87                	jne    126f9b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5820>
 126fa29:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126fa2d:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 126fa34:	00 
 126fa35:	0f 85 75 ff ff ff    	jne    126f9b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5820>
 126fa3b:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126fa42:	00 
 126fa43:	e9 68 ff ff ff       	jmp    126f9b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5820>
 126fa48:	4d 89 c8             	mov    %r9,%r8
 126fa4b:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126fa4f:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126fa53:	31 c0                	xor    %eax,%eax
 126fa55:	eb 1d                	jmp    126fa74 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x58e4>
 126fa57:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 126fa5e:	00 00 
 126fa60:	48 83 c0 02          	add    $0x2,%rax
 126fa64:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126fa6b:	49 39 c0             	cmp    %rax,%r8
 126fa6e:	0f 84 7f c7 ff ff    	je     126c1f3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2063>
 126fa74:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126fa7b:	00 
 126fa7c:	41 80 e3 0f          	and    $0xf,%r11b
 126fa80:	41 80 fb 07          	cmp    $0x7,%r11b
 126fa84:	75 2a                	jne    126fab0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5920>
 126fa86:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126fa8b:	74 23                	je     126fab0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5920>
 126fa8d:	49 39 12             	cmp    %rdx,(%r10)
 126fa90:	75 1e                	jne    126fab0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5920>
 126fa92:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 126fa99:	00 
 126fa9a:	75 14                	jne    126fab0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5920>
 126fa9c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126faa3:	00 
 126faa4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126faab:	00 00 00 00 00 
 126fab0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126fab7:	00 
 126fab8:	41 80 e3 0f          	and    $0xf,%r11b
 126fabc:	41 80 fb 07          	cmp    $0x7,%r11b
 126fac0:	75 9e                	jne    126fa60 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x58d0>
 126fac2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126fac9:	00 
 126faca:	74 94                	je     126fa60 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x58d0>
 126facc:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 126fad3:	75 8b                	jne    126fa60 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x58d0>
 126fad5:	4c 39 bc c1 d8 32 02 	cmp    %r15,0x232d8(%rcx,%rax,8)
 126fadc:	00 
 126fadd:	75 81                	jne    126fa60 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x58d0>
 126fadf:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126fae6:	00 
 126fae7:	e9 74 ff ff ff       	jmp    126fa60 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x58d0>
 126faec:	4d 89 c8             	mov    %r9,%r8
 126faef:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126faf3:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126faf7:	31 c0                	xor    %eax,%eax
 126faf9:	eb 19                	jmp    126fb14 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5984>
 126fafb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 126fb00:	48 83 c0 02          	add    $0x2,%rax
 126fb04:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126fb0b:	49 39 c0             	cmp    %rax,%r8
 126fb0e:	0f 84 1c c3 ff ff    	je     126be30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x1ca0>
 126fb14:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126fb1b:	00 
 126fb1c:	41 80 e3 0f          	and    $0xf,%r11b
 126fb20:	41 80 fb 07          	cmp    $0x7,%r11b
 126fb24:	75 2a                	jne    126fb50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x59c0>
 126fb26:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126fb2b:	74 23                	je     126fb50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x59c0>
 126fb2d:	49 39 12             	cmp    %rdx,(%r10)
 126fb30:	75 1e                	jne    126fb50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x59c0>
 126fb32:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 126fb39:	00 
 126fb3a:	75 14                	jne    126fb50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x59c0>
 126fb3c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126fb43:	00 
 126fb44:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126fb4b:	00 00 00 00 00 
 126fb50:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126fb57:	00 
 126fb58:	41 80 e3 0f          	and    $0xf,%r11b
 126fb5c:	41 80 fb 07          	cmp    $0x7,%r11b
 126fb60:	75 9e                	jne    126fb00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5970>
 126fb62:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126fb69:	00 
 126fb6a:	74 94                	je     126fb00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5970>
 126fb6c:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 126fb73:	75 8b                	jne    126fb00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5970>
 126fb75:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 126fb7c:	00 
 126fb7d:	75 81                	jne    126fb00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5970>
 126fb7f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126fb86:	00 
 126fb87:	e9 74 ff ff ff       	jmp    126fb00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5970>
 126fb8c:	4d 89 c8             	mov    %r9,%r8
 126fb8f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126fb93:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126fb97:	31 c0                	xor    %eax,%eax
 126fb99:	eb 19                	jmp    126fbb4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a24>
 126fb9b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 126fba0:	48 83 c0 02          	add    $0x2,%rax
 126fba4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126fbab:	49 39 c0             	cmp    %rax,%r8
 126fbae:	0f 84 ce c6 ff ff    	je     126c282 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x20f2>
 126fbb4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126fbbb:	00 
 126fbbc:	41 80 e3 0f          	and    $0xf,%r11b
 126fbc0:	41 80 fb 07          	cmp    $0x7,%r11b
 126fbc4:	75 2a                	jne    126fbf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a60>
 126fbc6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126fbcb:	74 23                	je     126fbf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a60>
 126fbcd:	49 39 12             	cmp    %rdx,(%r10)
 126fbd0:	75 1e                	jne    126fbf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a60>
 126fbd2:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 126fbd9:	00 
 126fbda:	75 14                	jne    126fbf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a60>
 126fbdc:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126fbe3:	00 
 126fbe4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126fbeb:	00 00 00 00 00 
 126fbf0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126fbf7:	00 
 126fbf8:	41 80 e3 0f          	and    $0xf,%r11b
 126fbfc:	41 80 fb 07          	cmp    $0x7,%r11b
 126fc00:	75 9e                	jne    126fba0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a10>
 126fc02:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126fc09:	00 
 126fc0a:	74 94                	je     126fba0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a10>
 126fc0c:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 126fc13:	75 8b                	jne    126fba0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a10>
 126fc15:	4c 39 bc c1 d8 32 02 	cmp    %r15,0x232d8(%rcx,%rax,8)
 126fc1c:	00 
 126fc1d:	75 81                	jne    126fba0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a10>
 126fc1f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126fc26:	00 
 126fc27:	e9 74 ff ff ff       	jmp    126fba0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5a10>
 126fc2c:	49 89 f0             	mov    %rsi,%r8
 126fc2f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126fc33:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126fc37:	31 c0                	xor    %eax,%eax
 126fc39:	eb 19                	jmp    126fc54 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ac4>
 126fc3b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 126fc40:	48 83 c0 02          	add    $0x2,%rax
 126fc44:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126fc4b:	49 39 c0             	cmp    %rax,%r8
 126fc4e:	0f 84 1f ca ff ff    	je     126c673 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x24e3>
 126fc54:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126fc5b:	00 
 126fc5c:	41 80 e3 0f          	and    $0xf,%r11b
 126fc60:	41 80 fb 07          	cmp    $0x7,%r11b
 126fc64:	75 2a                	jne    126fc90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b00>
 126fc66:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126fc6b:	74 23                	je     126fc90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b00>
 126fc6d:	4d 39 2a             	cmp    %r13,(%r10)
 126fc70:	75 1e                	jne    126fc90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b00>
 126fc72:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126fc76:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 126fc7d:	00 
 126fc7e:	75 10                	jne    126fc90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b00>
 126fc80:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126fc87:	00 
 126fc88:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 126fc8f:	00 
 126fc90:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126fc97:	00 
 126fc98:	41 80 e3 0f          	and    $0xf,%r11b
 126fc9c:	41 80 fb 07          	cmp    $0x7,%r11b
 126fca0:	75 9e                	jne    126fc40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ab0>
 126fca2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126fca9:	00 
 126fcaa:	74 94                	je     126fc40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ab0>
 126fcac:	4d 39 aa 18 01 00 00 	cmp    %r13,0x118(%r10)
 126fcb3:	75 8b                	jne    126fc40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ab0>
 126fcb5:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126fcb9:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 126fcc0:	00 
 126fcc1:	0f 85 79 ff ff ff    	jne    126fc40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ab0>
 126fcc7:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126fcce:	00 
 126fccf:	e9 6c ff ff ff       	jmp    126fc40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ab0>
 126fcd4:	49 89 f0             	mov    %rsi,%r8
 126fcd7:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126fcdb:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126fcdf:	31 c0                	xor    %eax,%eax
 126fce1:	eb 21                	jmp    126fd04 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b74>
 126fce3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 126fcea:	84 00 00 00 00 00 
 126fcf0:	48 83 c0 02          	add    $0x2,%rax
 126fcf4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126fcfb:	49 39 c0             	cmp    %rax,%r8
 126fcfe:	0f 84 43 ca ff ff    	je     126c747 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x25b7>
 126fd04:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126fd0b:	00 
 126fd0c:	41 80 e3 0f          	and    $0xf,%r11b
 126fd10:	41 80 fb 07          	cmp    $0x7,%r11b
 126fd14:	75 2a                	jne    126fd40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5bb0>
 126fd16:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126fd1b:	74 23                	je     126fd40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5bb0>
 126fd1d:	49 39 1a             	cmp    %rbx,(%r10)
 126fd20:	75 1e                	jne    126fd40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5bb0>
 126fd22:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 126fd29:	00 
 126fd2a:	75 14                	jne    126fd40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5bb0>
 126fd2c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126fd33:	00 
 126fd34:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126fd3b:	00 00 00 00 00 
 126fd40:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126fd47:	00 
 126fd48:	41 80 e3 0f          	and    $0xf,%r11b
 126fd4c:	41 80 fb 07          	cmp    $0x7,%r11b
 126fd50:	75 9e                	jne    126fcf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b60>
 126fd52:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126fd59:	00 
 126fd5a:	74 94                	je     126fcf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b60>
 126fd5c:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 126fd63:	75 8b                	jne    126fcf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b60>
 126fd65:	4c 39 bc c1 d8 32 02 	cmp    %r15,0x232d8(%rcx,%rax,8)
 126fd6c:	00 
 126fd6d:	75 81                	jne    126fcf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b60>
 126fd6f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126fd76:	00 
 126fd77:	e9 74 ff ff ff       	jmp    126fcf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5b60>
 126fd7c:	49 89 f0             	mov    %rsi,%r8
 126fd7f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126fd83:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126fd87:	31 c0                	xor    %eax,%eax
 126fd89:	eb 19                	jmp    126fda4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c14>
 126fd8b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 126fd90:	48 83 c0 02          	add    $0x2,%rax
 126fd94:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126fd9b:	49 39 c0             	cmp    %rax,%r8
 126fd9e:	0f 84 92 cb ff ff    	je     126c936 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x27a6>
 126fda4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126fdab:	00 
 126fdac:	41 80 e3 0f          	and    $0xf,%r11b
 126fdb0:	41 80 fb 07          	cmp    $0x7,%r11b
 126fdb4:	75 2a                	jne    126fde0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c50>
 126fdb6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126fdbb:	74 23                	je     126fde0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c50>
 126fdbd:	49 39 1a             	cmp    %rbx,(%r10)
 126fdc0:	75 1e                	jne    126fde0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c50>
 126fdc2:	4c 39 bc c1 d0 32 02 	cmp    %r15,0x232d0(%rcx,%rax,8)
 126fdc9:	00 
 126fdca:	75 14                	jne    126fde0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c50>
 126fdcc:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126fdd3:	00 
 126fdd4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 126fddb:	00 00 00 00 00 
 126fde0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126fde7:	00 
 126fde8:	41 80 e3 0f          	and    $0xf,%r11b
 126fdec:	41 80 fb 07          	cmp    $0x7,%r11b
 126fdf0:	75 9e                	jne    126fd90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c00>
 126fdf2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126fdf9:	00 
 126fdfa:	74 94                	je     126fd90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c00>
 126fdfc:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 126fe03:	75 8b                	jne    126fd90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c00>
 126fe05:	4c 39 bc c1 d8 32 02 	cmp    %r15,0x232d8(%rcx,%rax,8)
 126fe0c:	00 
 126fe0d:	75 81                	jne    126fd90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c00>
 126fe0f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126fe16:	00 
 126fe17:	e9 74 ff ff ff       	jmp    126fd90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5c00>
 126fe1c:	49 89 f0             	mov    %rsi,%r8
 126fe1f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126fe23:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126fe27:	31 c0                	xor    %eax,%eax
 126fe29:	eb 19                	jmp    126fe44 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5cb4>
 126fe2b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 126fe30:	48 83 c0 02          	add    $0x2,%rax
 126fe34:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126fe3b:	49 39 c0             	cmp    %rax,%r8
 126fe3e:	0f 84 71 d0 ff ff    	je     126ceb5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2d25>
 126fe44:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126fe4b:	00 
 126fe4c:	41 80 e3 0f          	and    $0xf,%r11b
 126fe50:	41 80 fb 07          	cmp    $0x7,%r11b
 126fe54:	75 2a                	jne    126fe80 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5cf0>
 126fe56:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126fe5b:	74 23                	je     126fe80 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5cf0>
 126fe5d:	4d 39 22             	cmp    %r12,(%r10)
 126fe60:	75 1e                	jne    126fe80 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5cf0>
 126fe62:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126fe66:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 126fe6d:	00 
 126fe6e:	75 10                	jne    126fe80 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5cf0>
 126fe70:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126fe77:	00 
 126fe78:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 126fe7f:	00 
 126fe80:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126fe87:	00 
 126fe88:	41 80 e3 0f          	and    $0xf,%r11b
 126fe8c:	41 80 fb 07          	cmp    $0x7,%r11b
 126fe90:	75 9e                	jne    126fe30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ca0>
 126fe92:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126fe99:	00 
 126fe9a:	74 94                	je     126fe30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ca0>
 126fe9c:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 126fea3:	75 8b                	jne    126fe30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ca0>
 126fea5:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126fea9:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 126feb0:	00 
 126feb1:	0f 85 79 ff ff ff    	jne    126fe30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ca0>
 126feb7:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126febe:	00 
 126febf:	e9 6c ff ff ff       	jmp    126fe30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ca0>
 126fec4:	49 89 f0             	mov    %rsi,%r8
 126fec7:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126fecb:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126fecf:	31 c0                	xor    %eax,%eax
 126fed1:	eb 21                	jmp    126fef4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5d64>
 126fed3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 126feda:	84 00 00 00 00 00 
 126fee0:	48 83 c0 02          	add    $0x2,%rax
 126fee4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126feeb:	49 39 c0             	cmp    %rax,%r8
 126feee:	0f 84 b5 d1 ff ff    	je     126d0a9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2f19>
 126fef4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126fefb:	00 
 126fefc:	41 80 e3 0f          	and    $0xf,%r11b
 126ff00:	41 80 fb 07          	cmp    $0x7,%r11b
 126ff04:	75 2a                	jne    126ff30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5da0>
 126ff06:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126ff0b:	74 23                	je     126ff30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5da0>
 126ff0d:	4d 39 22             	cmp    %r12,(%r10)
 126ff10:	75 1e                	jne    126ff30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5da0>
 126ff12:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126ff16:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 126ff1d:	00 
 126ff1e:	75 10                	jne    126ff30 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5da0>
 126ff20:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126ff27:	00 
 126ff28:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 126ff2f:	00 
 126ff30:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126ff37:	00 
 126ff38:	41 80 e3 0f          	and    $0xf,%r11b
 126ff3c:	41 80 fb 07          	cmp    $0x7,%r11b
 126ff40:	75 9e                	jne    126fee0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5d50>
 126ff42:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126ff49:	00 
 126ff4a:	74 94                	je     126fee0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5d50>
 126ff4c:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 126ff53:	75 8b                	jne    126fee0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5d50>
 126ff55:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 126ff59:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 126ff60:	00 
 126ff61:	0f 85 79 ff ff ff    	jne    126fee0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5d50>
 126ff67:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 126ff6e:	00 
 126ff6f:	e9 6c ff ff ff       	jmp    126fee0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5d50>
 126ff74:	49 89 f0             	mov    %rsi,%r8
 126ff77:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 126ff7b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 126ff7f:	31 c0                	xor    %eax,%eax
 126ff81:	eb 21                	jmp    126ffa4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e14>
 126ff83:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 126ff8a:	84 00 00 00 00 00 
 126ff90:	48 83 c0 02          	add    $0x2,%rax
 126ff94:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 126ff9b:	49 39 c0             	cmp    %rax,%r8
 126ff9e:	0f 84 d7 d1 ff ff    	je     126d17b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2feb>
 126ffa4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 126ffab:	00 
 126ffac:	41 80 e3 0f          	and    $0xf,%r11b
 126ffb0:	41 80 fb 07          	cmp    $0x7,%r11b
 126ffb4:	75 2a                	jne    126ffe0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e50>
 126ffb6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 126ffbb:	74 23                	je     126ffe0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e50>
 126ffbd:	49 39 1a             	cmp    %rbx,(%r10)
 126ffc0:	75 1e                	jne    126ffe0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e50>
 126ffc2:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 126ffc6:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 126ffcd:	00 
 126ffce:	75 10                	jne    126ffe0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e50>
 126ffd0:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 126ffd7:	00 
 126ffd8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 126ffdf:	00 
 126ffe0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 126ffe7:	00 
 126ffe8:	41 80 e3 0f          	and    $0xf,%r11b
 126ffec:	41 80 fb 07          	cmp    $0x7,%r11b
 126fff0:	75 9e                	jne    126ff90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e00>
 126fff2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 126fff9:	00 
 126fffa:	74 94                	je     126ff90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e00>
 126fffc:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 1270003:	75 8b                	jne    126ff90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e00>
 1270005:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 1270009:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1270010:	00 
 1270011:	0f 85 79 ff ff ff    	jne    126ff90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e00>
 1270017:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 127001e:	00 
 127001f:	e9 6c ff ff ff       	jmp    126ff90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5e00>
 1270024:	49 89 f0             	mov    %rsi,%r8
 1270027:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 127002b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 127002f:	31 c0                	xor    %eax,%eax
 1270031:	eb 21                	jmp    1270054 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5ec4>
 1270033:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 127003a:	84 00 00 00 00 00 
 1270040:	48 83 c0 02          	add    $0x2,%rax
 1270044:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127004b:	49 39 c0             	cmp    %rax,%r8
 127004e:	0f 84 41 cb ff ff    	je     126cb95 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2a05>
 1270054:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127005b:	00 
 127005c:	41 80 e3 0f          	and    $0xf,%r11b
 1270060:	41 80 fb 07          	cmp    $0x7,%r11b
 1270064:	75 2a                	jne    1270090 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f00>
 1270066:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127006b:	74 23                	je     1270090 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f00>
 127006d:	49 39 1a             	cmp    %rbx,(%r10)
 1270070:	75 1e                	jne    1270090 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f00>
 1270072:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 1270079:	00 
 127007a:	75 14                	jne    1270090 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f00>
 127007c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270083:	00 
 1270084:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127008b:	00 00 00 00 00 
 1270090:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270097:	00 
 1270098:	41 80 e3 0f          	and    $0xf,%r11b
 127009c:	41 80 fb 07          	cmp    $0x7,%r11b
 12700a0:	75 9e                	jne    1270040 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5eb0>
 12700a2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12700a9:	00 
 12700aa:	74 94                	je     1270040 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5eb0>
 12700ac:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 12700b3:	75 8b                	jne    1270040 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5eb0>
 12700b5:	4c 39 b4 c1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rax,8)
 12700bc:	00 
 12700bd:	75 81                	jne    1270040 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5eb0>
 12700bf:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 12700c6:	00 
 12700c7:	e9 74 ff ff ff       	jmp    1270040 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5eb0>
 12700cc:	49 89 f0             	mov    %rsi,%r8
 12700cf:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 12700d3:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 12700d7:	31 c0                	xor    %eax,%eax
 12700d9:	eb 19                	jmp    12700f4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f64>
 12700db:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 12700e0:	48 83 c0 02          	add    $0x2,%rax
 12700e4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 12700eb:	49 39 c0             	cmp    %rax,%r8
 12700ee:	0f 84 8a d3 ff ff    	je     126d47e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x32ee>
 12700f4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 12700fb:	00 
 12700fc:	41 80 e3 0f          	and    $0xf,%r11b
 1270100:	41 80 fb 07          	cmp    $0x7,%r11b
 1270104:	75 2a                	jne    1270130 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5fa0>
 1270106:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127010b:	74 23                	je     1270130 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5fa0>
 127010d:	4d 39 22             	cmp    %r12,(%r10)
 1270110:	75 1e                	jne    1270130 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5fa0>
 1270112:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 1270116:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 127011d:	00 
 127011e:	75 10                	jne    1270130 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5fa0>
 1270120:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270127:	00 
 1270128:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 127012f:	00 
 1270130:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270137:	00 
 1270138:	41 80 e3 0f          	and    $0xf,%r11b
 127013c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270140:	75 9e                	jne    12700e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f50>
 1270142:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270149:	00 
 127014a:	74 94                	je     12700e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f50>
 127014c:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 1270153:	75 8b                	jne    12700e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f50>
 1270155:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 1270159:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1270160:	00 
 1270161:	0f 85 79 ff ff ff    	jne    12700e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f50>
 1270167:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 127016e:	00 
 127016f:	e9 6c ff ff ff       	jmp    12700e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x5f50>
 1270174:	4d 89 c8             	mov    %r9,%r8
 1270177:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 127017b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 127017f:	31 c0                	xor    %eax,%eax
 1270181:	eb 21                	jmp    12701a4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6014>
 1270183:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 127018a:	84 00 00 00 00 00 
 1270190:	48 83 c0 02          	add    $0x2,%rax
 1270194:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127019b:	49 39 c0             	cmp    %rax,%r8
 127019e:	0f 84 ff d1 ff ff    	je     126d3a3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3213>
 12701a4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 12701ab:	00 
 12701ac:	41 80 e3 0f          	and    $0xf,%r11b
 12701b0:	41 80 fb 07          	cmp    $0x7,%r11b
 12701b4:	75 2a                	jne    12701e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6050>
 12701b6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 12701bb:	74 23                	je     12701e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6050>
 12701bd:	49 39 12             	cmp    %rdx,(%r10)
 12701c0:	75 1e                	jne    12701e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6050>
 12701c2:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 12701c9:	00 
 12701ca:	75 14                	jne    12701e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6050>
 12701cc:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12701d3:	00 
 12701d4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 12701db:	00 00 00 00 00 
 12701e0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 12701e7:	00 
 12701e8:	41 80 e3 0f          	and    $0xf,%r11b
 12701ec:	41 80 fb 07          	cmp    $0x7,%r11b
 12701f0:	75 9e                	jne    1270190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6000>
 12701f2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12701f9:	00 
 12701fa:	74 94                	je     1270190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6000>
 12701fc:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 1270203:	75 8b                	jne    1270190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6000>
 1270205:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 127020c:	00 
 127020d:	75 81                	jne    1270190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6000>
 127020f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270216:	00 
 1270217:	e9 74 ff ff ff       	jmp    1270190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6000>
 127021c:	4d 89 c8             	mov    %r9,%r8
 127021f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270223:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270227:	31 c0                	xor    %eax,%eax
 1270229:	eb 19                	jmp    1270244 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x60b4>
 127022b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1270230:	48 83 c0 02          	add    $0x2,%rax
 1270234:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127023b:	49 39 c0             	cmp    %rax,%r8
 127023e:	0f 84 d3 d2 ff ff    	je     126d517 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3387>
 1270244:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127024b:	00 
 127024c:	41 80 e3 0f          	and    $0xf,%r11b
 1270250:	41 80 fb 07          	cmp    $0x7,%r11b
 1270254:	75 2a                	jne    1270280 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x60f0>
 1270256:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127025b:	74 23                	je     1270280 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x60f0>
 127025d:	49 39 12             	cmp    %rdx,(%r10)
 1270260:	75 1e                	jne    1270280 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x60f0>
 1270262:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1270269:	00 
 127026a:	75 14                	jne    1270280 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x60f0>
 127026c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270273:	00 
 1270274:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127027b:	00 00 00 00 00 
 1270280:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270287:	00 
 1270288:	41 80 e3 0f          	and    $0xf,%r11b
 127028c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270290:	75 9e                	jne    1270230 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x60a0>
 1270292:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270299:	00 
 127029a:	74 94                	je     1270230 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x60a0>
 127029c:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 12702a3:	75 8b                	jne    1270230 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x60a0>
 12702a5:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 12702ac:	00 
 12702ad:	75 81                	jne    1270230 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x60a0>
 12702af:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 12702b6:	00 
 12702b7:	e9 74 ff ff ff       	jmp    1270230 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x60a0>
 12702bc:	4d 89 c8             	mov    %r9,%r8
 12702bf:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 12702c3:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 12702c7:	31 c0                	xor    %eax,%eax
 12702c9:	eb 19                	jmp    12702e4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6154>
 12702cb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 12702d0:	48 83 c0 02          	add    $0x2,%rax
 12702d4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 12702db:	49 39 c0             	cmp    %rax,%r8
 12702de:	0f 84 17 cb ff ff    	je     126cdfb <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x2c6b>
 12702e4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 12702eb:	00 
 12702ec:	41 80 e3 0f          	and    $0xf,%r11b
 12702f0:	41 80 fb 07          	cmp    $0x7,%r11b
 12702f4:	75 2a                	jne    1270320 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6190>
 12702f6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 12702fb:	74 23                	je     1270320 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6190>
 12702fd:	49 39 12             	cmp    %rdx,(%r10)
 1270300:	75 1e                	jne    1270320 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6190>
 1270302:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1270309:	00 
 127030a:	75 14                	jne    1270320 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6190>
 127030c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270313:	00 
 1270314:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127031b:	00 00 00 00 00 
 1270320:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270327:	00 
 1270328:	41 80 e3 0f          	and    $0xf,%r11b
 127032c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270330:	75 9e                	jne    12702d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6140>
 1270332:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270339:	00 
 127033a:	74 94                	je     12702d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6140>
 127033c:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 1270343:	75 8b                	jne    12702d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6140>
 1270345:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 127034c:	00 
 127034d:	75 81                	jne    12702d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6140>
 127034f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270356:	00 
 1270357:	e9 74 ff ff ff       	jmp    12702d0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6140>
 127035c:	4d 89 c8             	mov    %r9,%r8
 127035f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270363:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270367:	31 c0                	xor    %eax,%eax
 1270369:	eb 19                	jmp    1270384 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x61f4>
 127036b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1270370:	48 83 c0 02          	add    $0x2,%rax
 1270374:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127037b:	49 39 c0             	cmp    %rax,%r8
 127037e:	0f 84 29 d2 ff ff    	je     126d5ad <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x341d>
 1270384:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127038b:	00 
 127038c:	41 80 e3 0f          	and    $0xf,%r11b
 1270390:	41 80 fb 07          	cmp    $0x7,%r11b
 1270394:	75 2a                	jne    12703c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6230>
 1270396:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127039b:	74 23                	je     12703c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6230>
 127039d:	49 39 12             	cmp    %rdx,(%r10)
 12703a0:	75 1e                	jne    12703c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6230>
 12703a2:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 12703a9:	00 
 12703aa:	75 14                	jne    12703c0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6230>
 12703ac:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12703b3:	00 
 12703b4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 12703bb:	00 00 00 00 00 
 12703c0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 12703c7:	00 
 12703c8:	41 80 e3 0f          	and    $0xf,%r11b
 12703cc:	41 80 fb 07          	cmp    $0x7,%r11b
 12703d0:	75 9e                	jne    1270370 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x61e0>
 12703d2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12703d9:	00 
 12703da:	74 94                	je     1270370 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x61e0>
 12703dc:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 12703e3:	75 8b                	jne    1270370 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x61e0>
 12703e5:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 12703ec:	00 
 12703ed:	75 81                	jne    1270370 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x61e0>
 12703ef:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 12703f6:	00 
 12703f7:	e9 74 ff ff ff       	jmp    1270370 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x61e0>
 12703fc:	4d 89 f0             	mov    %r14,%r8
 12703ff:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270403:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270407:	31 c0                	xor    %eax,%eax
 1270409:	eb 19                	jmp    1270424 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6294>
 127040b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1270410:	48 83 c0 02          	add    $0x2,%rax
 1270414:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127041b:	49 39 c0             	cmp    %rax,%r8
 127041e:	0f 84 ea d6 ff ff    	je     126db0e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x397e>
 1270424:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127042b:	00 
 127042c:	41 80 e3 0f          	and    $0xf,%r11b
 1270430:	41 80 fb 07          	cmp    $0x7,%r11b
 1270434:	75 2a                	jne    1270460 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x62d0>
 1270436:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127043b:	74 23                	je     1270460 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x62d0>
 127043d:	4d 39 2a             	cmp    %r13,(%r10)
 1270440:	75 1e                	jne    1270460 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x62d0>
 1270442:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1270449:	00 
 127044a:	75 14                	jne    1270460 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x62d0>
 127044c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270453:	00 
 1270454:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127045b:	00 00 00 00 00 
 1270460:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270467:	00 
 1270468:	41 80 e3 0f          	and    $0xf,%r11b
 127046c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270470:	75 9e                	jne    1270410 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6280>
 1270472:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270479:	00 
 127047a:	74 94                	je     1270410 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6280>
 127047c:	4d 39 aa 18 01 00 00 	cmp    %r13,0x118(%r10)
 1270483:	75 8b                	jne    1270410 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6280>
 1270485:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 127048c:	00 
 127048d:	75 81                	jne    1270410 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6280>
 127048f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270496:	00 
 1270497:	e9 74 ff ff ff       	jmp    1270410 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6280>
 127049c:	4d 89 f0             	mov    %r14,%r8
 127049f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 12704a3:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 12704a7:	31 c0                	xor    %eax,%eax
 12704a9:	eb 19                	jmp    12704c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6334>
 12704ab:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 12704b0:	48 83 c0 02          	add    $0x2,%rax
 12704b4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 12704bb:	49 39 c0             	cmp    %rax,%r8
 12704be:	0f 84 06 d7 ff ff    	je     126dbca <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3a3a>
 12704c4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 12704cb:	00 
 12704cc:	41 80 e3 0f          	and    $0xf,%r11b
 12704d0:	41 80 fb 07          	cmp    $0x7,%r11b
 12704d4:	75 2a                	jne    1270500 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6370>
 12704d6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 12704db:	74 23                	je     1270500 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6370>
 12704dd:	49 39 1a             	cmp    %rbx,(%r10)
 12704e0:	75 1e                	jne    1270500 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6370>
 12704e2:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 12704e6:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 12704ed:	00 
 12704ee:	75 10                	jne    1270500 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6370>
 12704f0:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12704f7:	00 
 12704f8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 12704ff:	00 
 1270500:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270507:	00 
 1270508:	41 80 e3 0f          	and    $0xf,%r11b
 127050c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270510:	75 9e                	jne    12704b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6320>
 1270512:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270519:	00 
 127051a:	74 94                	je     12704b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6320>
 127051c:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 1270523:	75 8b                	jne    12704b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6320>
 1270525:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 1270529:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 1270530:	00 
 1270531:	0f 85 79 ff ff ff    	jne    12704b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6320>
 1270537:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 127053e:	00 
 127053f:	e9 6c ff ff ff       	jmp    12704b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6320>
 1270544:	49 89 f0             	mov    %rsi,%r8
 1270547:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 127054b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 127054f:	31 c0                	xor    %eax,%eax
 1270551:	eb 21                	jmp    1270574 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x63e4>
 1270553:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 127055a:	84 00 00 00 00 00 
 1270560:	48 83 c0 02          	add    $0x2,%rax
 1270564:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127056b:	49 39 c0             	cmp    %rax,%r8
 127056e:	0f 84 52 d8 ff ff    	je     126ddc6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3c36>
 1270574:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127057b:	00 
 127057c:	41 80 e3 0f          	and    $0xf,%r11b
 1270580:	41 80 fb 07          	cmp    $0x7,%r11b
 1270584:	75 2a                	jne    12705b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6420>
 1270586:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127058b:	74 23                	je     12705b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6420>
 127058d:	49 39 1a             	cmp    %rbx,(%r10)
 1270590:	75 1e                	jne    12705b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6420>
 1270592:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 1270596:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 127059d:	00 
 127059e:	75 10                	jne    12705b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6420>
 12705a0:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12705a7:	00 
 12705a8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 12705af:	00 
 12705b0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 12705b7:	00 
 12705b8:	41 80 e3 0f          	and    $0xf,%r11b
 12705bc:	41 80 fb 07          	cmp    $0x7,%r11b
 12705c0:	75 9e                	jne    1270560 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x63d0>
 12705c2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12705c9:	00 
 12705ca:	74 94                	je     1270560 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x63d0>
 12705cc:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 12705d3:	75 8b                	jne    1270560 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x63d0>
 12705d5:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 12705d9:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 12705e0:	00 
 12705e1:	0f 85 79 ff ff ff    	jne    1270560 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x63d0>
 12705e7:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 12705ee:	00 
 12705ef:	e9 6c ff ff ff       	jmp    1270560 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x63d0>
 12705f4:	49 89 f0             	mov    %rsi,%r8
 12705f7:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 12705fb:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 12705ff:	31 c0                	xor    %eax,%eax
 1270601:	eb 21                	jmp    1270624 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6494>
 1270603:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 127060a:	84 00 00 00 00 00 
 1270610:	48 83 c0 02          	add    $0x2,%rax
 1270614:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127061b:	49 39 c0             	cmp    %rax,%r8
 127061e:	0f 84 90 d8 ff ff    	je     126deb4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3d24>
 1270624:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127062b:	00 
 127062c:	41 80 e3 0f          	and    $0xf,%r11b
 1270630:	41 80 fb 07          	cmp    $0x7,%r11b
 1270634:	75 2a                	jne    1270660 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x64d0>
 1270636:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127063b:	74 23                	je     1270660 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x64d0>
 127063d:	4d 39 22             	cmp    %r12,(%r10)
 1270640:	75 1e                	jne    1270660 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x64d0>
 1270642:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 1270649:	00 
 127064a:	75 14                	jne    1270660 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x64d0>
 127064c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270653:	00 
 1270654:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127065b:	00 00 00 00 00 
 1270660:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270667:	00 
 1270668:	41 80 e3 0f          	and    $0xf,%r11b
 127066c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270670:	75 9e                	jne    1270610 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6480>
 1270672:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270679:	00 
 127067a:	74 94                	je     1270610 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6480>
 127067c:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 1270683:	75 8b                	jne    1270610 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6480>
 1270685:	4c 39 b4 c1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rax,8)
 127068c:	00 
 127068d:	75 81                	jne    1270610 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6480>
 127068f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270696:	00 
 1270697:	e9 74 ff ff ff       	jmp    1270610 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6480>
 127069c:	49 89 f0             	mov    %rsi,%r8
 127069f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 12706a3:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 12706a7:	31 c0                	xor    %eax,%eax
 12706a9:	eb 19                	jmp    12706c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6534>
 12706ab:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 12706b0:	48 83 c0 02          	add    $0x2,%rax
 12706b4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 12706bb:	49 39 c0             	cmp    %rax,%r8
 12706be:	0f 84 e6 d9 ff ff    	je     126e0aa <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3f1a>
 12706c4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 12706cb:	00 
 12706cc:	41 80 e3 0f          	and    $0xf,%r11b
 12706d0:	41 80 fb 07          	cmp    $0x7,%r11b
 12706d4:	75 2a                	jne    1270700 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6570>
 12706d6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 12706db:	74 23                	je     1270700 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6570>
 12706dd:	4d 39 22             	cmp    %r12,(%r10)
 12706e0:	75 1e                	jne    1270700 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6570>
 12706e2:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 12706e9:	00 
 12706ea:	75 14                	jne    1270700 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6570>
 12706ec:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12706f3:	00 
 12706f4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 12706fb:	00 00 00 00 00 
 1270700:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270707:	00 
 1270708:	41 80 e3 0f          	and    $0xf,%r11b
 127070c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270710:	75 9e                	jne    12706b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6520>
 1270712:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270719:	00 
 127071a:	74 94                	je     12706b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6520>
 127071c:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 1270723:	75 8b                	jne    12706b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6520>
 1270725:	4c 39 b4 c1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rax,8)
 127072c:	00 
 127072d:	75 81                	jne    12706b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6520>
 127072f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270736:	00 
 1270737:	e9 74 ff ff ff       	jmp    12706b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6520>
 127073c:	49 89 f0             	mov    %rsi,%r8
 127073f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270743:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270747:	31 c0                	xor    %eax,%eax
 1270749:	eb 19                	jmp    1270764 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x65d4>
 127074b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1270750:	48 83 c0 02          	add    $0x2,%rax
 1270754:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127075b:	49 39 c0             	cmp    %rax,%r8
 127075e:	0f 84 1b da ff ff    	je     126e17f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3fef>
 1270764:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127076b:	00 
 127076c:	41 80 e3 0f          	and    $0xf,%r11b
 1270770:	41 80 fb 07          	cmp    $0x7,%r11b
 1270774:	75 2a                	jne    12707a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6610>
 1270776:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127077b:	74 23                	je     12707a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6610>
 127077d:	49 39 1a             	cmp    %rbx,(%r10)
 1270780:	75 1e                	jne    12707a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6610>
 1270782:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 1270786:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 127078d:	00 
 127078e:	75 10                	jne    12707a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6610>
 1270790:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270797:	00 
 1270798:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 127079f:	00 
 12707a0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 12707a7:	00 
 12707a8:	41 80 e3 0f          	and    $0xf,%r11b
 12707ac:	41 80 fb 07          	cmp    $0x7,%r11b
 12707b0:	75 9e                	jne    1270750 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x65c0>
 12707b2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12707b9:	00 
 12707ba:	74 94                	je     1270750 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x65c0>
 12707bc:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 12707c3:	75 8b                	jne    1270750 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x65c0>
 12707c5:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 12707c9:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 12707d0:	00 
 12707d1:	0f 85 79 ff ff ff    	jne    1270750 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x65c0>
 12707d7:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 12707de:	00 
 12707df:	e9 6c ff ff ff       	jmp    1270750 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x65c0>
 12707e4:	49 89 f0             	mov    %rsi,%r8
 12707e7:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 12707eb:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 12707ef:	31 c0                	xor    %eax,%eax
 12707f1:	eb 21                	jmp    1270814 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6684>
 12707f3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12707fa:	84 00 00 00 00 00 
 1270800:	48 83 c0 02          	add    $0x2,%rax
 1270804:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127080b:	49 39 c0             	cmp    %rax,%r8
 127080e:	0f 84 69 db ff ff    	je     126e37d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x41ed>
 1270814:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127081b:	00 
 127081c:	41 80 e3 0f          	and    $0xf,%r11b
 1270820:	41 80 fb 07          	cmp    $0x7,%r11b
 1270824:	75 2a                	jne    1270850 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x66c0>
 1270826:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127082b:	74 23                	je     1270850 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x66c0>
 127082d:	49 39 1a             	cmp    %rbx,(%r10)
 1270830:	75 1e                	jne    1270850 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x66c0>
 1270832:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 1270836:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 127083d:	00 
 127083e:	75 10                	jne    1270850 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x66c0>
 1270840:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270847:	00 
 1270848:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 127084f:	00 
 1270850:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270857:	00 
 1270858:	41 80 e3 0f          	and    $0xf,%r11b
 127085c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270860:	75 9e                	jne    1270800 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6670>
 1270862:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270869:	00 
 127086a:	74 94                	je     1270800 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6670>
 127086c:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 1270873:	75 8b                	jne    1270800 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6670>
 1270875:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 1270879:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1270880:	00 
 1270881:	0f 85 79 ff ff ff    	jne    1270800 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6670>
 1270887:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 127088e:	00 
 127088f:	e9 6c ff ff ff       	jmp    1270800 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6670>
 1270894:	49 89 f0             	mov    %rsi,%r8
 1270897:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 127089b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 127089f:	31 c0                	xor    %eax,%eax
 12708a1:	eb 21                	jmp    12708c4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6734>
 12708a3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12708aa:	84 00 00 00 00 00 
 12708b0:	48 83 c0 02          	add    $0x2,%rax
 12708b4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 12708bb:	49 39 c0             	cmp    %rax,%r8
 12708be:	0f 84 8f db ff ff    	je     126e453 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x42c3>
 12708c4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 12708cb:	00 
 12708cc:	41 80 e3 0f          	and    $0xf,%r11b
 12708d0:	41 80 fb 07          	cmp    $0x7,%r11b
 12708d4:	75 2a                	jne    1270900 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6770>
 12708d6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 12708db:	74 23                	je     1270900 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6770>
 12708dd:	4d 39 22             	cmp    %r12,(%r10)
 12708e0:	75 1e                	jne    1270900 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6770>
 12708e2:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 12708e9:	00 
 12708ea:	75 14                	jne    1270900 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6770>
 12708ec:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12708f3:	00 
 12708f4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 12708fb:	00 00 00 00 00 
 1270900:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270907:	00 
 1270908:	41 80 e3 0f          	and    $0xf,%r11b
 127090c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270910:	75 9e                	jne    12708b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6720>
 1270912:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270919:	00 
 127091a:	74 94                	je     12708b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6720>
 127091c:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 1270923:	75 8b                	jne    12708b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6720>
 1270925:	4c 39 b4 c1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rax,8)
 127092c:	00 
 127092d:	75 81                	jne    12708b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6720>
 127092f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270936:	00 
 1270937:	e9 74 ff ff ff       	jmp    12708b0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6720>
 127093c:	49 89 f0             	mov    %rsi,%r8
 127093f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270943:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270947:	31 c0                	xor    %eax,%eax
 1270949:	eb 19                	jmp    1270964 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x67d4>
 127094b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1270950:	48 83 c0 02          	add    $0x2,%rax
 1270954:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127095b:	49 39 c0             	cmp    %rax,%r8
 127095e:	0f 84 e3 dc ff ff    	je     126e647 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x44b7>
 1270964:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127096b:	00 
 127096c:	41 80 e3 0f          	and    $0xf,%r11b
 1270970:	41 80 fb 07          	cmp    $0x7,%r11b
 1270974:	75 2a                	jne    12709a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6810>
 1270976:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127097b:	74 23                	je     12709a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6810>
 127097d:	4d 39 22             	cmp    %r12,(%r10)
 1270980:	75 1e                	jne    12709a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6810>
 1270982:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 1270989:	00 
 127098a:	75 14                	jne    12709a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6810>
 127098c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270993:	00 
 1270994:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127099b:	00 00 00 00 00 
 12709a0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 12709a7:	00 
 12709a8:	41 80 e3 0f          	and    $0xf,%r11b
 12709ac:	41 80 fb 07          	cmp    $0x7,%r11b
 12709b0:	75 9e                	jne    1270950 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x67c0>
 12709b2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12709b9:	00 
 12709ba:	74 94                	je     1270950 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x67c0>
 12709bc:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 12709c3:	75 8b                	jne    1270950 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x67c0>
 12709c5:	4c 39 b4 c1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rax,8)
 12709cc:	00 
 12709cd:	75 81                	jne    1270950 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x67c0>
 12709cf:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 12709d6:	00 
 12709d7:	e9 74 ff ff ff       	jmp    1270950 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x67c0>
 12709dc:	49 89 f0             	mov    %rsi,%r8
 12709df:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 12709e3:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 12709e7:	31 c0                	xor    %eax,%eax
 12709e9:	eb 19                	jmp    1270a04 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6874>
 12709eb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 12709f0:	48 83 c0 02          	add    $0x2,%rax
 12709f4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 12709fb:	49 39 c0             	cmp    %rax,%r8
 12709fe:	0f 84 04 dd ff ff    	je     126e708 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4578>
 1270a04:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1270a0b:	00 
 1270a0c:	41 80 e3 0f          	and    $0xf,%r11b
 1270a10:	41 80 fb 07          	cmp    $0x7,%r11b
 1270a14:	75 2a                	jne    1270a40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x68b0>
 1270a16:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1270a1b:	74 23                	je     1270a40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x68b0>
 1270a1d:	49 39 1a             	cmp    %rbx,(%r10)
 1270a20:	75 1e                	jne    1270a40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x68b0>
 1270a22:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 1270a26:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 1270a2d:	00 
 1270a2e:	75 10                	jne    1270a40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x68b0>
 1270a30:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270a37:	00 
 1270a38:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1270a3f:	00 
 1270a40:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270a47:	00 
 1270a48:	41 80 e3 0f          	and    $0xf,%r11b
 1270a4c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270a50:	75 9e                	jne    12709f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6860>
 1270a52:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270a59:	00 
 1270a5a:	74 94                	je     12709f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6860>
 1270a5c:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 1270a63:	75 8b                	jne    12709f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6860>
 1270a65:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 1270a69:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1270a70:	00 
 1270a71:	0f 85 79 ff ff ff    	jne    12709f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6860>
 1270a77:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270a7e:	00 
 1270a7f:	e9 6c ff ff ff       	jmp    12709f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6860>
 1270a84:	49 89 f0             	mov    %rsi,%r8
 1270a87:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270a8b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270a8f:	31 c0                	xor    %eax,%eax
 1270a91:	eb 21                	jmp    1270ab4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6924>
 1270a93:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1270a9a:	84 00 00 00 00 00 
 1270aa0:	48 83 c0 02          	add    $0x2,%rax
 1270aa4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1270aab:	49 39 c0             	cmp    %rax,%r8
 1270aae:	0f 84 b2 a8 ff ff    	je     126b366 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x11d6>
 1270ab4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1270abb:	00 
 1270abc:	41 80 e3 0f          	and    $0xf,%r11b
 1270ac0:	41 80 fb 07          	cmp    $0x7,%r11b
 1270ac4:	75 2a                	jne    1270af0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6960>
 1270ac6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1270acb:	74 23                	je     1270af0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6960>
 1270acd:	4d 39 32             	cmp    %r14,(%r10)
 1270ad0:	75 1e                	jne    1270af0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6960>
 1270ad2:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 1270ad6:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 1270add:	00 
 1270ade:	75 10                	jne    1270af0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6960>
 1270ae0:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270ae7:	00 
 1270ae8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1270aef:	00 
 1270af0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270af7:	00 
 1270af8:	41 80 e3 0f          	and    $0xf,%r11b
 1270afc:	41 80 fb 07          	cmp    $0x7,%r11b
 1270b00:	75 9e                	jne    1270aa0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6910>
 1270b02:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270b09:	00 
 1270b0a:	74 94                	je     1270aa0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6910>
 1270b0c:	4d 39 b2 18 01 00 00 	cmp    %r14,0x118(%r10)
 1270b13:	75 8b                	jne    1270aa0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6910>
 1270b15:	4c 8b 5d b0          	mov    -0x50(%rbp),%r11
 1270b19:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1270b20:	00 
 1270b21:	0f 85 79 ff ff ff    	jne    1270aa0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6910>
 1270b27:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270b2e:	00 
 1270b2f:	e9 6c ff ff ff       	jmp    1270aa0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6910>
 1270b34:	49 89 f0             	mov    %rsi,%r8
 1270b37:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270b3b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270b3f:	31 c0                	xor    %eax,%eax
 1270b41:	eb 21                	jmp    1270b64 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x69d4>
 1270b43:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1270b4a:	84 00 00 00 00 00 
 1270b50:	48 83 c0 02          	add    $0x2,%rax
 1270b54:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1270b5b:	49 39 c0             	cmp    %rax,%r8
 1270b5e:	0f 84 dc a8 ff ff    	je     126b440 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x12b0>
 1270b64:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1270b6b:	00 
 1270b6c:	41 80 e3 0f          	and    $0xf,%r11b
 1270b70:	41 80 fb 07          	cmp    $0x7,%r11b
 1270b74:	75 2a                	jne    1270ba0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a10>
 1270b76:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1270b7b:	74 23                	je     1270ba0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a10>
 1270b7d:	49 39 1a             	cmp    %rbx,(%r10)
 1270b80:	75 1e                	jne    1270ba0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a10>
 1270b82:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 1270b86:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 1270b8d:	00 
 1270b8e:	75 10                	jne    1270ba0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a10>
 1270b90:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270b97:	00 
 1270b98:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1270b9f:	00 
 1270ba0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270ba7:	00 
 1270ba8:	41 80 e3 0f          	and    $0xf,%r11b
 1270bac:	41 80 fb 07          	cmp    $0x7,%r11b
 1270bb0:	75 9e                	jne    1270b50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x69c0>
 1270bb2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270bb9:	00 
 1270bba:	74 94                	je     1270b50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x69c0>
 1270bbc:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 1270bc3:	75 8b                	jne    1270b50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x69c0>
 1270bc5:	4c 8b 5d d0          	mov    -0x30(%rbp),%r11
 1270bc9:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1270bd0:	00 
 1270bd1:	0f 85 79 ff ff ff    	jne    1270b50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x69c0>
 1270bd7:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270bde:	00 
 1270bdf:	e9 6c ff ff ff       	jmp    1270b50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x69c0>
 1270be4:	4d 89 f8             	mov    %r15,%r8
 1270be7:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270beb:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270bef:	31 c0                	xor    %eax,%eax
 1270bf1:	eb 21                	jmp    1270c14 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a84>
 1270bf3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1270bfa:	84 00 00 00 00 00 
 1270c00:	48 83 c0 02          	add    $0x2,%rax
 1270c04:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1270c0b:	49 39 c0             	cmp    %rax,%r8
 1270c0e:	0f 84 3f b8 ff ff    	je     126c453 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x22c3>
 1270c14:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1270c1b:	00 
 1270c1c:	41 80 e3 0f          	and    $0xf,%r11b
 1270c20:	41 80 fb 07          	cmp    $0x7,%r11b
 1270c24:	75 2a                	jne    1270c50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6ac0>
 1270c26:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1270c2b:	74 23                	je     1270c50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6ac0>
 1270c2d:	4d 39 2a             	cmp    %r13,(%r10)
 1270c30:	75 1e                	jne    1270c50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6ac0>
 1270c32:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1270c39:	00 
 1270c3a:	75 14                	jne    1270c50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6ac0>
 1270c3c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270c43:	00 
 1270c44:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1270c4b:	00 00 00 00 00 
 1270c50:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270c57:	00 
 1270c58:	41 80 e3 0f          	and    $0xf,%r11b
 1270c5c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270c60:	75 9e                	jne    1270c00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a70>
 1270c62:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270c69:	00 
 1270c6a:	74 94                	je     1270c00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a70>
 1270c6c:	4d 39 aa 18 01 00 00 	cmp    %r13,0x118(%r10)
 1270c73:	75 8b                	jne    1270c00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a70>
 1270c75:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 1270c7c:	00 
 1270c7d:	75 81                	jne    1270c00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a70>
 1270c7f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270c86:	00 
 1270c87:	e9 74 ff ff ff       	jmp    1270c00 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6a70>
 1270c8c:	4d 89 f8             	mov    %r15,%r8
 1270c8f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270c93:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270c97:	31 c0                	xor    %eax,%eax
 1270c99:	eb 19                	jmp    1270cb4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6b24>
 1270c9b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1270ca0:	48 83 c0 02          	add    $0x2,%rax
 1270ca4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1270cab:	49 39 c0             	cmp    %rax,%r8
 1270cae:	0f 84 cc cb ff ff    	je     126d880 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x36f0>
 1270cb4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1270cbb:	00 
 1270cbc:	41 80 e3 0f          	and    $0xf,%r11b
 1270cc0:	41 80 fb 07          	cmp    $0x7,%r11b
 1270cc4:	75 2a                	jne    1270cf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6b60>
 1270cc6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1270ccb:	74 23                	je     1270cf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6b60>
 1270ccd:	49 39 12             	cmp    %rdx,(%r10)
 1270cd0:	75 1e                	jne    1270cf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6b60>
 1270cd2:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1270cd6:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1270cdd:	00 
 1270cde:	75 10                	jne    1270cf0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6b60>
 1270ce0:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270ce7:	00 
 1270ce8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1270cef:	00 
 1270cf0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270cf7:	00 
 1270cf8:	41 80 e3 0f          	and    $0xf,%r11b
 1270cfc:	41 80 fb 07          	cmp    $0x7,%r11b
 1270d00:	75 9e                	jne    1270ca0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6b10>
 1270d02:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270d09:	00 
 1270d0a:	74 94                	je     1270ca0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6b10>
 1270d0c:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 1270d13:	75 8b                	jne    1270ca0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6b10>
 1270d15:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 1270d19:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 1270d20:	00 
 1270d21:	0f 85 79 ff ff ff    	jne    1270ca0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6b10>
 1270d27:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270d2e:	00 
 1270d2f:	e9 6c ff ff ff       	jmp    1270ca0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6b10>
 1270d34:	4d 89 c8             	mov    %r9,%r8
 1270d37:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270d3b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270d3f:	31 c0                	xor    %eax,%eax
 1270d41:	eb 21                	jmp    1270d64 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6bd4>
 1270d43:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1270d4a:	84 00 00 00 00 00 
 1270d50:	48 83 c0 02          	add    $0x2,%rax
 1270d54:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1270d5b:	49 39 c0             	cmp    %rax,%r8
 1270d5e:	0f 84 54 ca ff ff    	je     126d7b8 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x3628>
 1270d64:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1270d6b:	00 
 1270d6c:	41 80 e3 0f          	and    $0xf,%r11b
 1270d70:	41 80 fb 07          	cmp    $0x7,%r11b
 1270d74:	75 2a                	jne    1270da0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c10>
 1270d76:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1270d7b:	74 23                	je     1270da0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c10>
 1270d7d:	49 39 12             	cmp    %rdx,(%r10)
 1270d80:	75 1e                	jne    1270da0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c10>
 1270d82:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1270d89:	00 
 1270d8a:	75 14                	jne    1270da0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c10>
 1270d8c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270d93:	00 
 1270d94:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1270d9b:	00 00 00 00 00 
 1270da0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270da7:	00 
 1270da8:	41 80 e3 0f          	and    $0xf,%r11b
 1270dac:	41 80 fb 07          	cmp    $0x7,%r11b
 1270db0:	75 9e                	jne    1270d50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6bc0>
 1270db2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270db9:	00 
 1270dba:	74 94                	je     1270d50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6bc0>
 1270dbc:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 1270dc3:	75 8b                	jne    1270d50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6bc0>
 1270dc5:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 1270dcc:	00 
 1270dcd:	75 81                	jne    1270d50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6bc0>
 1270dcf:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270dd6:	00 
 1270dd7:	e9 74 ff ff ff       	jmp    1270d50 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6bc0>
 1270ddc:	4d 89 c8             	mov    %r9,%r8
 1270ddf:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270de3:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270de7:	31 c0                	xor    %eax,%eax
 1270de9:	eb 19                	jmp    1270e04 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c74>
 1270deb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1270df0:	48 83 c0 02          	add    $0x2,%rax
 1270df4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1270dfb:	49 39 c0             	cmp    %rax,%r8
 1270dfe:	0f 84 16 cb ff ff    	je     126d91a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x378a>
 1270e04:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1270e0b:	00 
 1270e0c:	41 80 e3 0f          	and    $0xf,%r11b
 1270e10:	41 80 fb 07          	cmp    $0x7,%r11b
 1270e14:	75 2a                	jne    1270e40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6cb0>
 1270e16:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1270e1b:	74 23                	je     1270e40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6cb0>
 1270e1d:	49 39 12             	cmp    %rdx,(%r10)
 1270e20:	75 1e                	jne    1270e40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6cb0>
 1270e22:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 1270e29:	00 
 1270e2a:	75 14                	jne    1270e40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6cb0>
 1270e2c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270e33:	00 
 1270e34:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 1270e3b:	00 00 00 00 00 
 1270e40:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270e47:	00 
 1270e48:	41 80 e3 0f          	and    $0xf,%r11b
 1270e4c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270e50:	75 9e                	jne    1270df0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c60>
 1270e52:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270e59:	00 
 1270e5a:	74 94                	je     1270df0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c60>
 1270e5c:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 1270e63:	75 8b                	jne    1270df0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c60>
 1270e65:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 1270e6c:	00 
 1270e6d:	75 81                	jne    1270df0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c60>
 1270e6f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270e76:	00 
 1270e77:	e9 74 ff ff ff       	jmp    1270df0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6c60>
 1270e7c:	49 89 f0             	mov    %rsi,%r8
 1270e7f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270e83:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270e87:	31 c0                	xor    %eax,%eax
 1270e89:	eb 19                	jmp    1270ea4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d14>
 1270e8b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1270e90:	48 83 c0 02          	add    $0x2,%rax
 1270e94:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1270e9b:	49 39 c0             	cmp    %rax,%r8
 1270e9e:	0f 84 32 da ff ff    	je     126e8d6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4746>
 1270ea4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1270eab:	00 
 1270eac:	41 80 e3 0f          	and    $0xf,%r11b
 1270eb0:	41 80 fb 07          	cmp    $0x7,%r11b
 1270eb4:	75 2a                	jne    1270ee0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d50>
 1270eb6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1270ebb:	74 23                	je     1270ee0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d50>
 1270ebd:	49 39 1a             	cmp    %rbx,(%r10)
 1270ec0:	75 1e                	jne    1270ee0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d50>
 1270ec2:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 1270ec6:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 1270ecd:	00 
 1270ece:	75 10                	jne    1270ee0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d50>
 1270ed0:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270ed7:	00 
 1270ed8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 1270edf:	00 
 1270ee0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270ee7:	00 
 1270ee8:	41 80 e3 0f          	and    $0xf,%r11b
 1270eec:	41 80 fb 07          	cmp    $0x7,%r11b
 1270ef0:	75 9e                	jne    1270e90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d00>
 1270ef2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270ef9:	00 
 1270efa:	74 94                	je     1270e90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d00>
 1270efc:	49 39 9a 18 01 00 00 	cmp    %rbx,0x118(%r10)
 1270f03:	75 8b                	jne    1270e90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d00>
 1270f05:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 1270f09:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1270f10:	00 
 1270f11:	0f 85 79 ff ff ff    	jne    1270e90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d00>
 1270f17:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270f1e:	00 
 1270f1f:	e9 6c ff ff ff       	jmp    1270e90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6d00>
 1270f24:	49 89 f0             	mov    %rsi,%r8
 1270f27:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270f2b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270f2f:	31 c0                	xor    %eax,%eax
 1270f31:	eb 21                	jmp    1270f54 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6dc4>
 1270f33:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1270f3a:	84 00 00 00 00 00 
 1270f40:	48 83 c0 02          	add    $0x2,%rax
 1270f44:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1270f4b:	49 39 c0             	cmp    %rax,%r8
 1270f4e:	0f 84 47 da ff ff    	je     126e99b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x480b>
 1270f54:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 1270f5b:	00 
 1270f5c:	41 80 e3 0f          	and    $0xf,%r11b
 1270f60:	41 80 fb 07          	cmp    $0x7,%r11b
 1270f64:	75 2a                	jne    1270f90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e00>
 1270f66:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 1270f6b:	74 23                	je     1270f90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e00>
 1270f6d:	4d 39 3a             	cmp    %r15,(%r10)
 1270f70:	75 1e                	jne    1270f90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e00>
 1270f72:	4c 8b 9d 68 ff ff ff 	mov    -0x98(%rbp),%r11
 1270f79:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 1270f80:	00 
 1270f81:	75 0d                	jne    1270f90 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e00>
 1270f83:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1270f8a:	00 
 1270f8b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1270f90:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1270f97:	00 
 1270f98:	41 80 e3 0f          	and    $0xf,%r11b
 1270f9c:	41 80 fb 07          	cmp    $0x7,%r11b
 1270fa0:	75 9e                	jne    1270f40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6db0>
 1270fa2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1270fa9:	00 
 1270faa:	74 94                	je     1270f40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6db0>
 1270fac:	4d 39 ba 18 01 00 00 	cmp    %r15,0x118(%r10)
 1270fb3:	75 8b                	jne    1270f40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6db0>
 1270fb5:	4c 8b 9d 68 ff ff ff 	mov    -0x98(%rbp),%r11
 1270fbc:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1270fc3:	00 
 1270fc4:	0f 85 76 ff ff ff    	jne    1270f40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6db0>
 1270fca:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1270fd1:	00 
 1270fd2:	e9 69 ff ff ff       	jmp    1270f40 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6db0>
 1270fd7:	49 89 f0             	mov    %rsi,%r8
 1270fda:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1270fde:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1270fe2:	31 c0                	xor    %eax,%eax
 1270fe4:	eb 1e                	jmp    1271004 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e74>
 1270fe6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 1270fed:	00 00 00 
 1270ff0:	48 83 c0 02          	add    $0x2,%rax
 1270ff4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 1270ffb:	49 39 c0             	cmp    %rax,%r8
 1270ffe:	0f 84 78 db ff ff    	je     126eb7c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x49ec>
 1271004:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127100b:	00 
 127100c:	41 80 e3 0f          	and    $0xf,%r11b
 1271010:	41 80 fb 07          	cmp    $0x7,%r11b
 1271014:	75 2a                	jne    1271040 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6eb0>
 1271016:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127101b:	74 23                	je     1271040 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6eb0>
 127101d:	4d 39 3a             	cmp    %r15,(%r10)
 1271020:	75 1e                	jne    1271040 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6eb0>
 1271022:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 1271029:	00 
 127102a:	75 14                	jne    1271040 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6eb0>
 127102c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1271033:	00 
 1271034:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127103b:	00 00 00 00 00 
 1271040:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1271047:	00 
 1271048:	41 80 e3 0f          	and    $0xf,%r11b
 127104c:	41 80 fb 07          	cmp    $0x7,%r11b
 1271050:	75 9e                	jne    1270ff0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e60>
 1271052:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1271059:	00 
 127105a:	74 94                	je     1270ff0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e60>
 127105c:	4d 39 ba 18 01 00 00 	cmp    %r15,0x118(%r10)
 1271063:	75 8b                	jne    1270ff0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e60>
 1271065:	4c 39 b4 c1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rax,8)
 127106c:	00 
 127106d:	75 81                	jne    1270ff0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e60>
 127106f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1271076:	00 
 1271077:	e9 74 ff ff ff       	jmp    1270ff0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6e60>
 127107c:	49 89 f0             	mov    %rsi,%r8
 127107f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 1271083:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 1271087:	31 c0                	xor    %eax,%eax
 1271089:	eb 19                	jmp    12710a4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f14>
 127108b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1271090:	48 83 c0 02          	add    $0x2,%rax
 1271094:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127109b:	49 39 c0             	cmp    %rax,%r8
 127109e:	0f 84 b9 db ff ff    	je     126ec5d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4acd>
 12710a4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 12710ab:	00 
 12710ac:	41 80 e3 0f          	and    $0xf,%r11b
 12710b0:	41 80 fb 07          	cmp    $0x7,%r11b
 12710b4:	75 2a                	jne    12710e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f50>
 12710b6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 12710bb:	74 23                	je     12710e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f50>
 12710bd:	4d 39 2a             	cmp    %r13,(%r10)
 12710c0:	75 1e                	jne    12710e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f50>
 12710c2:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 12710c6:	4c 39 9c c1 d0 32 02 	cmp    %r11,0x232d0(%rcx,%rax,8)
 12710cd:	00 
 12710ce:	75 10                	jne    12710e0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f50>
 12710d0:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 12710d7:	00 
 12710d8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 12710df:	00 
 12710e0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 12710e7:	00 
 12710e8:	41 80 e3 0f          	and    $0xf,%r11b
 12710ec:	41 80 fb 07          	cmp    $0x7,%r11b
 12710f0:	75 9e                	jne    1271090 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f00>
 12710f2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12710f9:	00 
 12710fa:	74 94                	je     1271090 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f00>
 12710fc:	4d 39 aa 18 01 00 00 	cmp    %r13,0x118(%r10)
 1271103:	75 8b                	jne    1271090 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f00>
 1271105:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 1271109:	4c 39 9c c1 d8 32 02 	cmp    %r11,0x232d8(%rcx,%rax,8)
 1271110:	00 
 1271111:	0f 85 79 ff ff ff    	jne    1271090 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f00>
 1271117:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 127111e:	00 
 127111f:	e9 6c ff ff ff       	jmp    1271090 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6f00>
 1271124:	4d 89 f8             	mov    %r15,%r8
 1271127:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 127112b:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 127112f:	31 c0                	xor    %eax,%eax
 1271131:	eb 21                	jmp    1271154 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6fc4>
 1271133:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 127113a:	84 00 00 00 00 00 
 1271140:	48 83 c0 02          	add    $0x2,%rax
 1271144:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 127114b:	49 39 c0             	cmp    %rax,%r8
 127114e:	0f 84 c8 dc ff ff    	je     126ee1c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4c8c>
 1271154:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127115b:	00 
 127115c:	41 80 e3 0f          	and    $0xf,%r11b
 1271160:	41 80 fb 07          	cmp    $0x7,%r11b
 1271164:	75 2a                	jne    1271190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7000>
 1271166:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127116b:	74 23                	je     1271190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7000>
 127116d:	4d 39 2a             	cmp    %r13,(%r10)
 1271170:	75 1e                	jne    1271190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7000>
 1271172:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 1271176:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 127117d:	00 
 127117e:	75 10                	jne    1271190 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7000>
 1271180:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1271187:	00 
 1271188:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 127118f:	00 
 1271190:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1271197:	00 
 1271198:	41 80 e3 0f          	and    $0xf,%r11b
 127119c:	41 80 fb 07          	cmp    $0x7,%r11b
 12711a0:	75 9e                	jne    1271140 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6fb0>
 12711a2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 12711a9:	00 
 12711aa:	74 94                	je     1271140 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6fb0>
 12711ac:	4d 39 aa 18 01 00 00 	cmp    %r13,0x118(%r10)
 12711b3:	75 8b                	jne    1271140 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6fb0>
 12711b5:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 12711b9:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 12711c0:	00 
 12711c1:	0f 85 79 ff ff ff    	jne    1271140 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6fb0>
 12711c7:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 12711ce:	00 
 12711cf:	e9 6c ff ff ff       	jmp    1271140 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x6fb0>
 12711d4:	4d 89 f8             	mov    %r15,%r8
 12711d7:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 12711db:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 12711df:	31 c0                	xor    %eax,%eax
 12711e1:	eb 21                	jmp    1271204 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7074>
 12711e3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 12711ea:	84 00 00 00 00 00 
 12711f0:	48 83 c0 02          	add    $0x2,%rax
 12711f4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 12711fb:	49 39 c0             	cmp    %rax,%r8
 12711fe:	0f 84 d6 dc ff ff    	je     126eeda <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x4d4a>
 1271204:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 127120b:	00 
 127120c:	41 80 e3 0f          	and    $0xf,%r11b
 1271210:	41 80 fb 07          	cmp    $0x7,%r11b
 1271214:	75 2a                	jne    1271240 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x70b0>
 1271216:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 127121b:	74 23                	je     1271240 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x70b0>
 127121d:	4d 39 22             	cmp    %r12,(%r10)
 1271220:	75 1e                	jne    1271240 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x70b0>
 1271222:	4c 39 b4 c1 d0 32 02 	cmp    %r14,0x232d0(%rcx,%rax,8)
 1271229:	00 
 127122a:	75 14                	jne    1271240 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x70b0>
 127122c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 1271233:	00 
 1271234:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 127123b:	00 00 00 00 00 
 1271240:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 1271247:	00 
 1271248:	41 80 e3 0f          	and    $0xf,%r11b
 127124c:	41 80 fb 07          	cmp    $0x7,%r11b
 1271250:	75 9e                	jne    12711f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7060>
 1271252:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 1271259:	00 
 127125a:	74 94                	je     12711f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7060>
 127125c:	4d 39 a2 18 01 00 00 	cmp    %r12,0x118(%r10)
 1271263:	75 8b                	jne    12711f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7060>
 1271265:	4c 39 b4 c1 d8 32 02 	cmp    %r14,0x232d8(%rcx,%rax,8)
 127126c:	00 
 127126d:	75 81                	jne    12711f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7060>
 127126f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 1271276:	00 
 1271277:	e9 74 ff ff ff       	jmp    12711f0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7060>
 127127c:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1271283:	74 42                	je     12712c7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7137>
 1271285:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 127128c:	ff 
 127128d:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1271294:	ff 
 1271295:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 127129c:	ff 
 127129d:	c5 fc 11 95 28 d3 ff 	vmovups %ymm2,-0x2cd8(%rbp)
 12712a4:	ff 
 12712a5:	c5 fc 11 8d 10 d3 ff 	vmovups %ymm1,-0x2cf0(%rbp)
 12712ac:	ff 
 12712ad:	c5 fc 11 85 f0 d2 ff 	vmovups %ymm0,-0x2d10(%rbp)
 12712b4:	ff 
 12712b5:	48 8d bd f0 d2 ff ff 	lea    -0x2d10(%rbp),%rdi
 12712bc:	4c 89 f6             	mov    %r14,%rsi
 12712bf:	c5 f8 77             	vzeroupper 
 12712c2:	e8 e9 40 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12712c7:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 12712ce:	0f 84 25 15 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 12712d4:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 12712db:	ff 
 12712dc:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 12712e3:	ff 
 12712e4:	c5 fc 11 8d 70 e8 ff 	vmovups %ymm1,-0x1790(%rbp)
 12712eb:	ff 
 12712ec:	c5 fc 11 85 60 e8 ff 	vmovups %ymm0,-0x17a0(%rbp)
 12712f3:	ff 
 12712f4:	48 8d bd 60 e8 ff ff 	lea    -0x17a0(%rbp),%rdi
 12712fb:	e9 ee 14 00 00       	jmp    12727ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x865e>
 1271300:	83 f8 1a             	cmp    $0x1a,%eax
 1271303:	0f 84 6e 16 00 00    	je     1272977 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x87e7>
 1271309:	83 f8 43             	cmp    $0x43,%eax
 127130c:	0f 85 f6 16 00 00    	jne    1272a08 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8878>
 1271312:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271319:	74 32                	je     127134d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x71bd>
 127131b:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1271322:	ff 
 1271323:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 127132a:	ff 
 127132b:	c5 fc 11 8d d0 e8 ff 	vmovups %ymm1,-0x1730(%rbp)
 1271332:	ff 
 1271333:	c5 fc 11 85 c0 e8 ff 	vmovups %ymm0,-0x1740(%rbp)
 127133a:	ff 
 127133b:	48 8d bd c0 e8 ff ff 	lea    -0x1740(%rbp),%rdi
 1271342:	4c 89 f6             	mov    %r14,%rsi
 1271345:	c5 f8 77             	vzeroupper 
 1271348:	e8 93 7f fe ff       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 127134d:	80 bd f8 fd ff ff 00 	cmpb   $0x0,-0x208(%rbp)
 1271354:	74 24                	je     127137a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x71ea>
 1271356:	48 8b 85 e0 fd ff ff 	mov    -0x220(%rbp),%rax
 127135d:	48 69 8d f0 fd ff ff 	imul   $0x118,-0x210(%rbp),%rcx
 1271364:	18 01 00 00 
 1271368:	48 c7 44 08 68 a1 02 	movq   $0x11202a1,0x68(%rax,%rcx,1)
 127136f:	12 01 
 1271371:	48 c7 44 08 70 0f 00 	movq   $0xf,0x70(%rax,%rcx,1)
 1271378:	00 00 
 127137a:	48 8d bd c0 fd ff ff 	lea    -0x240(%rbp),%rdi
 1271381:	e8 ea 5d 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1271386:	c5 f8 10 05 52 56 e2 	vmovups -0x1da9ae(%rip),%xmm0        # 10969e0 <__anon_233167>
 127138d:	ff 
 127138e:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 1271392:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 1271396:	48 c7 40 10 43 00 00 	movq   $0x43,0x10(%rax)
 127139d:	00 
 127139e:	e9 4c e1 ff ff       	jmp    126f4ef <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x535f>
 12713a3:	4c 89 ff             	mov    %r15,%rdi
 12713a6:	4c 89 f6             	mov    %r14,%rsi
 12713a9:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 12713ad:	48 89 d9             	mov    %rbx,%rcx
 12713b0:	e8 eb 51 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 12713b5:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 12713bc:	ff 
 12713bd:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12713c1:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12713c6:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 12713cd:	ff 
 12713ce:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 12713d5:	ff 
 12713d6:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 12713dd:	ff 
 12713de:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 12713e5:	ff 
 12713e6:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12713eb:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12713f0:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12713f5:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12713f9:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1271400:	4c 89 f6             	mov    %r14,%rsi
 1271403:	c5 f8 77             	vzeroupper 
 1271406:	e8 75 3e fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 127140b:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1271412:	74 43                	je     1271457 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x72c7>
 1271414:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 127141b:	ff 
 127141c:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1271423:	ff 
 1271424:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 127142b:	ff 
 127142c:	c5 fc 11 95 e8 d0 ff 	vmovups %ymm2,-0x2f18(%rbp)
 1271433:	ff 
 1271434:	c5 fc 11 8d d0 d0 ff 	vmovups %ymm1,-0x2f30(%rbp)
 127143b:	ff 
 127143c:	c5 fc 11 85 b0 d0 ff 	vmovups %ymm0,-0x2f50(%rbp)
 1271443:	ff 
 1271444:	48 8d bd b0 d0 ff ff 	lea    -0x2f50(%rbp),%rdi
 127144b:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 127144f:	c5 f8 77             	vzeroupper 
 1271452:	e8 59 3f fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1271457:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 127145e:	0f 84 ca 14 00 00    	je     127292e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x879e>
 1271464:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 127146b:	ff 
 127146c:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1271473:	ff 
 1271474:	c5 fc 11 8d 50 e7 ff 	vmovups %ymm1,-0x18b0(%rbp)
 127147b:	ff 
 127147c:	c5 fc 11 85 40 e7 ff 	vmovups %ymm0,-0x18c0(%rbp)
 1271483:	ff 
 1271484:	48 8d bd 40 e7 ff ff 	lea    -0x18c0(%rbp),%rdi
 127148b:	e9 86 05 00 00       	jmp    1271a16 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7886>
 1271490:	4c 89 ff             	mov    %r15,%rdi
 1271493:	4c 89 f6             	mov    %r14,%rsi
 1271496:	4c 89 ea             	mov    %r13,%rdx
 1271499:	4c 89 e1             	mov    %r12,%rcx
 127149c:	e8 ff 50 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 12714a1:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 12714a8:	ff 
 12714a9:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12714ad:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12714b2:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 12714b9:	ff 
 12714ba:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 12714c1:	ff 
 12714c2:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 12714c9:	ff 
 12714ca:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 12714d1:	ff 
 12714d2:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12714d7:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12714dc:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12714e1:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12714e5:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 12714ec:	4c 89 f6             	mov    %r14,%rsi
 12714ef:	c5 f8 77             	vzeroupper 
 12714f2:	e8 89 3d fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 12714f7:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 12714fe:	74 42                	je     1271542 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x73b2>
 1271500:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1271507:	ff 
 1271508:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 127150f:	ff 
 1271510:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1271517:	ff 
 1271518:	c5 fc 11 95 88 d0 ff 	vmovups %ymm2,-0x2f78(%rbp)
 127151f:	ff 
 1271520:	c5 fc 11 8d 70 d0 ff 	vmovups %ymm1,-0x2f90(%rbp)
 1271527:	ff 
 1271528:	c5 fc 11 85 50 d0 ff 	vmovups %ymm0,-0x2fb0(%rbp)
 127152f:	ff 
 1271530:	48 8d bd 50 d0 ff ff 	lea    -0x2fb0(%rbp),%rdi
 1271537:	4c 89 f6             	mov    %r14,%rsi
 127153a:	c5 f8 77             	vzeroupper 
 127153d:	e8 6e 3e fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1271542:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271549:	0f 84 aa 12 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 127154f:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1271556:	ff 
 1271557:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 127155e:	ff 
 127155f:	c5 fc 11 8d 20 e7 ff 	vmovups %ymm1,-0x18e0(%rbp)
 1271566:	ff 
 1271567:	c5 fc 11 85 10 e7 ff 	vmovups %ymm0,-0x18f0(%rbp)
 127156e:	ff 
 127156f:	48 8d bd 10 e7 ff ff 	lea    -0x18f0(%rbp),%rdi
 1271576:	e9 73 12 00 00       	jmp    12727ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x865e>
 127157b:	4c 89 ef             	mov    %r13,%rdi
 127157e:	4c 89 f6             	mov    %r14,%rsi
 1271581:	4c 89 fa             	mov    %r15,%rdx
 1271584:	48 89 d9             	mov    %rbx,%rcx
 1271587:	e8 14 50 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 127158c:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1271593:	ff 
 1271594:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271598:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 127159d:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 12715a4:	ff 
 12715a5:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 12715ac:	ff 
 12715ad:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 12715b4:	ff 
 12715b5:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 12715bc:	ff 
 12715bd:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12715c2:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12715c7:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12715cc:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12715d0:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 12715d7:	4c 89 f6             	mov    %r14,%rsi
 12715da:	c5 f8 77             	vzeroupper 
 12715dd:	e8 9e 3c fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 12715e2:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 12715e9:	74 43                	je     127162e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x749e>
 12715eb:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 12715f2:	ff 
 12715f3:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 12715fa:	ff 
 12715fb:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1271602:	ff 
 1271603:	c5 fc 11 95 28 d0 ff 	vmovups %ymm2,-0x2fd8(%rbp)
 127160a:	ff 
 127160b:	c5 fc 11 8d 10 d0 ff 	vmovups %ymm1,-0x2ff0(%rbp)
 1271612:	ff 
 1271613:	c5 fc 11 85 f0 cf ff 	vmovups %ymm0,-0x3010(%rbp)
 127161a:	ff 
 127161b:	48 8d bd f0 cf ff ff 	lea    -0x3010(%rbp),%rdi
 1271622:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1271626:	c5 f8 77             	vzeroupper 
 1271629:	e8 82 3d fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 127162e:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271635:	0f 84 f3 12 00 00    	je     127292e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x879e>
 127163b:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1271642:	ff 
 1271643:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 127164a:	ff 
 127164b:	c5 fc 11 8d f0 e6 ff 	vmovups %ymm1,-0x1910(%rbp)
 1271652:	ff 
 1271653:	c5 fc 11 85 e0 e6 ff 	vmovups %ymm0,-0x1920(%rbp)
 127165a:	ff 
 127165b:	48 8d bd e0 e6 ff ff 	lea    -0x1920(%rbp),%rdi
 1271662:	e9 af 03 00 00       	jmp    1271a16 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7886>
 1271667:	4c 89 ef             	mov    %r13,%rdi
 127166a:	4c 89 f6             	mov    %r14,%rsi
 127166d:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 1271671:	48 8b 4d b0          	mov    -0x50(%rbp),%rcx
 1271675:	e8 26 4f 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 127167a:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1271681:	ff 
 1271682:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271686:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 127168b:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1271692:	ff 
 1271693:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 127169a:	ff 
 127169b:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 12716a2:	ff 
 12716a3:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 12716aa:	ff 
 12716ab:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12716b0:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12716b5:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12716ba:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12716be:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 12716c5:	4c 89 f6             	mov    %r14,%rsi
 12716c8:	c5 f8 77             	vzeroupper 
 12716cb:	e8 b0 3b fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 12716d0:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 12716d7:	74 42                	je     127171b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x758b>
 12716d9:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 12716e0:	ff 
 12716e1:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 12716e8:	ff 
 12716e9:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 12716f0:	ff 
 12716f1:	c5 fc 11 95 c8 cf ff 	vmovups %ymm2,-0x3038(%rbp)
 12716f8:	ff 
 12716f9:	c5 fc 11 8d b0 cf ff 	vmovups %ymm1,-0x3050(%rbp)
 1271700:	ff 
 1271701:	c5 fc 11 85 90 cf ff 	vmovups %ymm0,-0x3070(%rbp)
 1271708:	ff 
 1271709:	48 8d bd 90 cf ff ff 	lea    -0x3070(%rbp),%rdi
 1271710:	4c 89 f6             	mov    %r14,%rsi
 1271713:	c5 f8 77             	vzeroupper 
 1271716:	e8 95 3c fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 127171b:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271722:	0f 84 97 0f 00 00    	je     12726bf <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x852f>
 1271728:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 127172f:	ff 
 1271730:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1271737:	ff 
 1271738:	c5 fc 11 8d c0 e6 ff 	vmovups %ymm1,-0x1940(%rbp)
 127173f:	ff 
 1271740:	c5 fc 11 85 b0 e6 ff 	vmovups %ymm0,-0x1950(%rbp)
 1271747:	ff 
 1271748:	48 8d bd b0 e6 ff ff 	lea    -0x1950(%rbp),%rdi
 127174f:	4c 89 f6             	mov    %r14,%rsi
 1271752:	e9 60 0f 00 00       	jmp    12726b7 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8527>
 1271757:	4c 89 e7             	mov    %r12,%rdi
 127175a:	4c 89 ee             	mov    %r13,%rsi
 127175d:	4c 89 fa             	mov    %r15,%rdx
 1271760:	48 89 d9             	mov    %rbx,%rcx
 1271763:	e8 38 4e 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1271768:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 127176f:	ff 
 1271770:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271774:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1271779:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1271780:	ff 
 1271781:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1271788:	ff 
 1271789:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1271790:	ff 
 1271791:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1271798:	ff 
 1271799:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 127179e:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12717a3:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12717a8:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12717ac:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 12717b3:	4c 89 ee             	mov    %r13,%rsi
 12717b6:	c5 f8 77             	vzeroupper 
 12717b9:	e8 c2 3a fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 12717be:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 12717c5:	74 43                	je     127180a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x767a>
 12717c7:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 12717ce:	ff 
 12717cf:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 12717d6:	ff 
 12717d7:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 12717de:	ff 
 12717df:	c5 fc 11 95 68 cf ff 	vmovups %ymm2,-0x3098(%rbp)
 12717e6:	ff 
 12717e7:	c5 fc 11 8d 50 cf ff 	vmovups %ymm1,-0x30b0(%rbp)
 12717ee:	ff 
 12717ef:	c5 fc 11 85 30 cf ff 	vmovups %ymm0,-0x30d0(%rbp)
 12717f6:	ff 
 12717f7:	48 8d bd 30 cf ff ff 	lea    -0x30d0(%rbp),%rdi
 12717fe:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1271802:	c5 f8 77             	vzeroupper 
 1271805:	e8 a6 3b fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 127180a:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271811:	0f 84 6e 09 00 00    	je     1272185 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7ff5>
 1271817:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 127181e:	ff 
 127181f:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1271826:	ff 
 1271827:	c5 fc 11 8d 90 e6 ff 	vmovups %ymm1,-0x1970(%rbp)
 127182e:	ff 
 127182f:	c5 fc 11 85 80 e6 ff 	vmovups %ymm0,-0x1980(%rbp)
 1271836:	ff 
 1271837:	48 8d bd 80 e6 ff ff 	lea    -0x1980(%rbp),%rdi
 127183e:	e9 36 09 00 00       	jmp    1272179 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7fe9>
 1271843:	4c 89 e7             	mov    %r12,%rdi
 1271846:	4c 89 f6             	mov    %r14,%rsi
 1271849:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 127184d:	4c 89 e9             	mov    %r13,%rcx
 1271850:	e8 4b 4d 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1271855:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 127185c:	ff 
 127185d:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271861:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1271866:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 127186d:	ff 
 127186e:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1271875:	ff 
 1271876:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 127187d:	ff 
 127187e:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1271885:	ff 
 1271886:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 127188b:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1271890:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1271895:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1271899:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 12718a0:	4c 89 f6             	mov    %r14,%rsi
 12718a3:	c5 f8 77             	vzeroupper 
 12718a6:	e8 d5 39 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 12718ab:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 12718b2:	74 42                	je     12718f6 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7766>
 12718b4:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 12718bb:	ff 
 12718bc:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 12718c3:	ff 
 12718c4:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 12718cb:	ff 
 12718cc:	c5 fc 11 95 a8 ce ff 	vmovups %ymm2,-0x3158(%rbp)
 12718d3:	ff 
 12718d4:	c5 fc 11 8d 90 ce ff 	vmovups %ymm1,-0x3170(%rbp)
 12718db:	ff 
 12718dc:	c5 fc 11 85 70 ce ff 	vmovups %ymm0,-0x3190(%rbp)
 12718e3:	ff 
 12718e4:	48 8d bd 70 ce ff ff 	lea    -0x3190(%rbp),%rdi
 12718eb:	4c 89 f6             	mov    %r14,%rsi
 12718ee:	c5 f8 77             	vzeroupper 
 12718f1:	e8 ba 3a fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12718f6:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 12718fd:	0f 84 f6 0e 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 1271903:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 127190a:	ff 
 127190b:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1271912:	ff 
 1271913:	c5 fc 11 8d 30 e6 ff 	vmovups %ymm1,-0x19d0(%rbp)
 127191a:	ff 
 127191b:	c5 fc 11 85 20 e6 ff 	vmovups %ymm0,-0x19e0(%rbp)
 1271922:	ff 
 1271923:	48 8d bd 20 e6 ff ff 	lea    -0x19e0(%rbp),%rdi
 127192a:	e9 bf 0e 00 00       	jmp    12727ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x865e>
 127192f:	4c 89 ef             	mov    %r13,%rdi
 1271932:	4c 89 f6             	mov    %r14,%rsi
 1271935:	4c 89 fa             	mov    %r15,%rdx
 1271938:	48 89 d9             	mov    %rbx,%rcx
 127193b:	e8 60 4c 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1271940:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1271947:	ff 
 1271948:	48 8b 45 18          	mov    0x18(%rbp),%rax
 127194c:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1271951:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1271958:	ff 
 1271959:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1271960:	ff 
 1271961:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1271968:	ff 
 1271969:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1271970:	ff 
 1271971:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1271976:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 127197b:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1271980:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1271984:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 127198b:	4c 89 f6             	mov    %r14,%rsi
 127198e:	c5 f8 77             	vzeroupper 
 1271991:	e8 ea 38 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1271996:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 127199d:	74 43                	je     12719e2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7852>
 127199f:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 12719a6:	ff 
 12719a7:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 12719ae:	ff 
 12719af:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 12719b6:	ff 
 12719b7:	c5 fc 11 95 48 ce ff 	vmovups %ymm2,-0x31b8(%rbp)
 12719be:	ff 
 12719bf:	c5 fc 11 8d 30 ce ff 	vmovups %ymm1,-0x31d0(%rbp)
 12719c6:	ff 
 12719c7:	c5 fc 11 85 10 ce ff 	vmovups %ymm0,-0x31f0(%rbp)
 12719ce:	ff 
 12719cf:	48 8d bd 10 ce ff ff 	lea    -0x31f0(%rbp),%rdi
 12719d6:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 12719da:	c5 f8 77             	vzeroupper 
 12719dd:	e8 ce 39 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12719e2:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 12719e9:	0f 84 3f 0f 00 00    	je     127292e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x879e>
 12719ef:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 12719f6:	ff 
 12719f7:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 12719fe:	ff 
 12719ff:	c5 fc 11 8d 00 e6 ff 	vmovups %ymm1,-0x1a00(%rbp)
 1271a06:	ff 
 1271a07:	c5 fc 11 85 f0 e5 ff 	vmovups %ymm0,-0x1a10(%rbp)
 1271a0e:	ff 
 1271a0f:	48 8d bd f0 e5 ff ff 	lea    -0x1a10(%rbp),%rdi
 1271a16:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1271a1a:	e9 07 0f 00 00       	jmp    1272926 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8796>
 1271a1f:	4c 89 ef             	mov    %r13,%rdi
 1271a22:	4c 89 f6             	mov    %r14,%rsi
 1271a25:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 1271a29:	4c 89 e1             	mov    %r12,%rcx
 1271a2c:	e8 6f 4b 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1271a31:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1271a38:	ff 
 1271a39:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271a3d:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1271a42:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1271a49:	ff 
 1271a4a:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1271a51:	ff 
 1271a52:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1271a59:	ff 
 1271a5a:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1271a61:	ff 
 1271a62:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1271a67:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1271a6c:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1271a71:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1271a75:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1271a7c:	4c 89 f6             	mov    %r14,%rsi
 1271a7f:	c5 f8 77             	vzeroupper 
 1271a82:	e8 f9 37 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1271a87:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1271a8e:	74 42                	je     1271ad2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7942>
 1271a90:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1271a97:	ff 
 1271a98:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1271a9f:	ff 
 1271aa0:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1271aa7:	ff 
 1271aa8:	c5 fc 11 95 e8 cd ff 	vmovups %ymm2,-0x3218(%rbp)
 1271aaf:	ff 
 1271ab0:	c5 fc 11 8d d0 cd ff 	vmovups %ymm1,-0x3230(%rbp)
 1271ab7:	ff 
 1271ab8:	c5 fc 11 85 b0 cd ff 	vmovups %ymm0,-0x3250(%rbp)
 1271abf:	ff 
 1271ac0:	48 8d bd b0 cd ff ff 	lea    -0x3250(%rbp),%rdi
 1271ac7:	4c 89 f6             	mov    %r14,%rsi
 1271aca:	c5 f8 77             	vzeroupper 
 1271acd:	e8 de 38 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1271ad2:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271ad9:	0f 84 1a 0d 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 1271adf:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1271ae6:	ff 
 1271ae7:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1271aee:	ff 
 1271aef:	c5 fc 11 8d d0 e5 ff 	vmovups %ymm1,-0x1a30(%rbp)
 1271af6:	ff 
 1271af7:	c5 fc 11 85 c0 e5 ff 	vmovups %ymm0,-0x1a40(%rbp)
 1271afe:	ff 
 1271aff:	48 8d bd c0 e5 ff ff 	lea    -0x1a40(%rbp),%rdi
 1271b06:	e9 e3 0c 00 00       	jmp    12727ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x865e>
 1271b0b:	4c 89 ff             	mov    %r15,%rdi
 1271b0e:	4c 89 ee             	mov    %r13,%rsi
 1271b11:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 1271b15:	48 89 d9             	mov    %rbx,%rcx
 1271b18:	e8 83 4a 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1271b1d:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1271b24:	ff 
 1271b25:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271b29:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1271b2e:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1271b35:	ff 
 1271b36:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1271b3d:	ff 
 1271b3e:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1271b45:	ff 
 1271b46:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1271b4d:	ff 
 1271b4e:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1271b53:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1271b58:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1271b5d:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1271b61:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1271b68:	4c 89 ee             	mov    %r13,%rsi
 1271b6b:	c5 f8 77             	vzeroupper 
 1271b6e:	e8 0d 37 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1271b73:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1271b7a:	74 43                	je     1271bbf <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7a2f>
 1271b7c:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1271b83:	ff 
 1271b84:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1271b8b:	ff 
 1271b8c:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1271b93:	ff 
 1271b94:	c5 fc 11 95 88 cd ff 	vmovups %ymm2,-0x3278(%rbp)
 1271b9b:	ff 
 1271b9c:	c5 fc 11 8d 70 cd ff 	vmovups %ymm1,-0x3290(%rbp)
 1271ba3:	ff 
 1271ba4:	c5 fc 11 85 50 cd ff 	vmovups %ymm0,-0x32b0(%rbp)
 1271bab:	ff 
 1271bac:	48 8d bd 50 cd ff ff 	lea    -0x32b0(%rbp),%rdi
 1271bb3:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1271bb7:	c5 f8 77             	vzeroupper 
 1271bba:	e8 f1 37 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1271bbf:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271bc6:	0f 84 b9 05 00 00    	je     1272185 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7ff5>
 1271bcc:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1271bd3:	ff 
 1271bd4:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1271bdb:	ff 
 1271bdc:	c5 fc 11 8d a0 e5 ff 	vmovups %ymm1,-0x1a60(%rbp)
 1271be3:	ff 
 1271be4:	c5 fc 11 85 90 e5 ff 	vmovups %ymm0,-0x1a70(%rbp)
 1271beb:	ff 
 1271bec:	48 8d bd 90 e5 ff ff 	lea    -0x1a70(%rbp),%rdi
 1271bf3:	e9 81 05 00 00       	jmp    1272179 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7fe9>
 1271bf8:	4c 89 f7             	mov    %r14,%rdi
 1271bfb:	4c 89 fe             	mov    %r15,%rsi
 1271bfe:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 1271c02:	4c 89 e1             	mov    %r12,%rcx
 1271c05:	e8 96 49 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1271c0a:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1271c11:	ff 
 1271c12:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271c16:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1271c1b:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1271c22:	ff 
 1271c23:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1271c2a:	ff 
 1271c2b:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1271c32:	ff 
 1271c33:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1271c3a:	ff 
 1271c3b:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1271c40:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1271c45:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1271c4a:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1271c4e:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1271c55:	4c 89 fe             	mov    %r15,%rsi
 1271c58:	c5 f8 77             	vzeroupper 
 1271c5b:	e8 20 36 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1271c60:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1271c67:	74 42                	je     1271cab <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7b1b>
 1271c69:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1271c70:	ff 
 1271c71:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1271c78:	ff 
 1271c79:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1271c80:	ff 
 1271c81:	c5 fc 11 95 28 cd ff 	vmovups %ymm2,-0x32d8(%rbp)
 1271c88:	ff 
 1271c89:	c5 fc 11 8d 10 cd ff 	vmovups %ymm1,-0x32f0(%rbp)
 1271c90:	ff 
 1271c91:	c5 fc 11 85 f0 cc ff 	vmovups %ymm0,-0x3310(%rbp)
 1271c98:	ff 
 1271c99:	48 8d bd f0 cc ff ff 	lea    -0x3310(%rbp),%rdi
 1271ca0:	4c 89 fe             	mov    %r15,%rsi
 1271ca3:	c5 f8 77             	vzeroupper 
 1271ca6:	e8 05 37 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1271cab:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271cb2:	0f 84 41 0b 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 1271cb8:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1271cbf:	ff 
 1271cc0:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1271cc7:	ff 
 1271cc8:	c5 fc 11 8d 70 e5 ff 	vmovups %ymm1,-0x1a90(%rbp)
 1271ccf:	ff 
 1271cd0:	c5 fc 11 85 60 e5 ff 	vmovups %ymm0,-0x1aa0(%rbp)
 1271cd7:	ff 
 1271cd8:	48 8d bd 60 e5 ff ff 	lea    -0x1aa0(%rbp),%rdi
 1271cdf:	e9 ab 07 00 00       	jmp    127248f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x82ff>
 1271ce4:	4c 89 ff             	mov    %r15,%rdi
 1271ce7:	4c 89 e6             	mov    %r12,%rsi
 1271cea:	4c 89 f2             	mov    %r14,%rdx
 1271ced:	4c 89 e9             	mov    %r13,%rcx
 1271cf0:	e8 ab 48 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1271cf5:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1271cfc:	ff 
 1271cfd:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271d01:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1271d06:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1271d0d:	ff 
 1271d0e:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1271d15:	ff 
 1271d16:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1271d1d:	ff 
 1271d1e:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1271d25:	ff 
 1271d26:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1271d2b:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1271d30:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1271d35:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1271d39:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1271d40:	4c 89 e6             	mov    %r12,%rsi
 1271d43:	c5 f8 77             	vzeroupper 
 1271d46:	e8 35 35 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1271d4b:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1271d52:	74 42                	je     1271d96 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7c06>
 1271d54:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1271d5b:	ff 
 1271d5c:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1271d63:	ff 
 1271d64:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1271d6b:	ff 
 1271d6c:	c5 fc 11 95 c8 cc ff 	vmovups %ymm2,-0x3338(%rbp)
 1271d73:	ff 
 1271d74:	c5 fc 11 8d b0 cc ff 	vmovups %ymm1,-0x3350(%rbp)
 1271d7b:	ff 
 1271d7c:	c5 fc 11 85 90 cc ff 	vmovups %ymm0,-0x3370(%rbp)
 1271d83:	ff 
 1271d84:	48 8d bd 90 cc ff ff 	lea    -0x3370(%rbp),%rdi
 1271d8b:	4c 89 e6             	mov    %r12,%rsi
 1271d8e:	c5 f8 77             	vzeroupper 
 1271d91:	e8 1a 36 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1271d96:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271d9d:	0f 84 56 0a 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 1271da3:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1271daa:	ff 
 1271dab:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1271db2:	ff 
 1271db3:	c5 fc 11 8d 40 e5 ff 	vmovups %ymm1,-0x1ac0(%rbp)
 1271dba:	ff 
 1271dbb:	c5 fc 11 85 30 e5 ff 	vmovups %ymm0,-0x1ad0(%rbp)
 1271dc2:	ff 
 1271dc3:	48 8d bd 30 e5 ff ff 	lea    -0x1ad0(%rbp),%rdi
 1271dca:	e9 e6 00 00 00       	jmp    1271eb5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7d25>
 1271dcf:	4c 89 f7             	mov    %r14,%rdi
 1271dd2:	4c 89 e6             	mov    %r12,%rsi
 1271dd5:	4c 89 fa             	mov    %r15,%rdx
 1271dd8:	4c 89 e9             	mov    %r13,%rcx
 1271ddb:	e8 c0 47 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1271de0:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1271de7:	ff 
 1271de8:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271dec:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1271df1:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1271df8:	ff 
 1271df9:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1271e00:	ff 
 1271e01:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1271e08:	ff 
 1271e09:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1271e10:	ff 
 1271e11:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1271e16:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1271e1b:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1271e20:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1271e24:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1271e2b:	4c 89 e6             	mov    %r12,%rsi
 1271e2e:	c5 f8 77             	vzeroupper 
 1271e31:	e8 4a 34 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1271e36:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1271e3d:	74 42                	je     1271e81 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7cf1>
 1271e3f:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1271e46:	ff 
 1271e47:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1271e4e:	ff 
 1271e4f:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1271e56:	ff 
 1271e57:	c5 fc 11 95 08 cc ff 	vmovups %ymm2,-0x33f8(%rbp)
 1271e5e:	ff 
 1271e5f:	c5 fc 11 8d f0 cb ff 	vmovups %ymm1,-0x3410(%rbp)
 1271e66:	ff 
 1271e67:	c5 fc 11 85 d0 cb ff 	vmovups %ymm0,-0x3430(%rbp)
 1271e6e:	ff 
 1271e6f:	48 8d bd d0 cb ff ff 	lea    -0x3430(%rbp),%rdi
 1271e76:	4c 89 e6             	mov    %r12,%rsi
 1271e79:	c5 f8 77             	vzeroupper 
 1271e7c:	e8 2f 35 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1271e81:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271e88:	0f 84 6b 09 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 1271e8e:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1271e95:	ff 
 1271e96:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1271e9d:	ff 
 1271e9e:	c5 fc 11 8d e0 e4 ff 	vmovups %ymm1,-0x1b20(%rbp)
 1271ea5:	ff 
 1271ea6:	c5 fc 11 85 d0 e4 ff 	vmovups %ymm0,-0x1b30(%rbp)
 1271ead:	ff 
 1271eae:	48 8d bd d0 e4 ff ff 	lea    -0x1b30(%rbp),%rdi
 1271eb5:	4c 89 e6             	mov    %r12,%rsi
 1271eb8:	e9 34 09 00 00       	jmp    12727f1 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8661>
 1271ebd:	4c 89 ff             	mov    %r15,%rdi
 1271ec0:	4c 89 ee             	mov    %r13,%rsi
 1271ec3:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 1271ec7:	48 89 d9             	mov    %rbx,%rcx
 1271eca:	e8 d1 46 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1271ecf:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1271ed6:	ff 
 1271ed7:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271edb:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1271ee0:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1271ee7:	ff 
 1271ee8:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1271eef:	ff 
 1271ef0:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1271ef7:	ff 
 1271ef8:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1271eff:	ff 
 1271f00:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1271f05:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1271f0a:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1271f0f:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1271f13:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1271f1a:	4c 89 ee             	mov    %r13,%rsi
 1271f1d:	c5 f8 77             	vzeroupper 
 1271f20:	e8 5b 33 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1271f25:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1271f2c:	74 43                	je     1271f71 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7de1>
 1271f2e:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1271f35:	ff 
 1271f36:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1271f3d:	ff 
 1271f3e:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1271f45:	ff 
 1271f46:	c5 fc 11 95 a8 cb ff 	vmovups %ymm2,-0x3458(%rbp)
 1271f4d:	ff 
 1271f4e:	c5 fc 11 8d 90 cb ff 	vmovups %ymm1,-0x3470(%rbp)
 1271f55:	ff 
 1271f56:	c5 fc 11 85 70 cb ff 	vmovups %ymm0,-0x3490(%rbp)
 1271f5d:	ff 
 1271f5e:	48 8d bd 70 cb ff ff 	lea    -0x3490(%rbp),%rdi
 1271f65:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1271f69:	c5 f8 77             	vzeroupper 
 1271f6c:	e8 3f 34 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1271f71:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1271f78:	0f 84 07 02 00 00    	je     1272185 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7ff5>
 1271f7e:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1271f85:	ff 
 1271f86:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1271f8d:	ff 
 1271f8e:	c5 fc 11 8d b0 e4 ff 	vmovups %ymm1,-0x1b50(%rbp)
 1271f95:	ff 
 1271f96:	c5 fc 11 85 a0 e4 ff 	vmovups %ymm0,-0x1b60(%rbp)
 1271f9d:	ff 
 1271f9e:	48 8d bd a0 e4 ff ff 	lea    -0x1b60(%rbp),%rdi
 1271fa5:	e9 cf 01 00 00       	jmp    1272179 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7fe9>
 1271faa:	4c 89 ff             	mov    %r15,%rdi
 1271fad:	4c 89 ee             	mov    %r13,%rsi
 1271fb0:	4c 89 f2             	mov    %r14,%rdx
 1271fb3:	4c 89 e1             	mov    %r12,%rcx
 1271fb6:	e8 e5 45 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1271fbb:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1271fc2:	ff 
 1271fc3:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1271fc7:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1271fcc:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1271fd3:	ff 
 1271fd4:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1271fdb:	ff 
 1271fdc:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1271fe3:	ff 
 1271fe4:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1271feb:	ff 
 1271fec:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1271ff1:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1271ff6:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1271ffb:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1271fff:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1272006:	4c 89 ee             	mov    %r13,%rsi
 1272009:	c5 f8 77             	vzeroupper 
 127200c:	e8 6f 32 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1272011:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1272018:	74 42                	je     127205c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7ecc>
 127201a:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1272021:	ff 
 1272022:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1272029:	ff 
 127202a:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1272031:	ff 
 1272032:	c5 fc 11 95 48 cb ff 	vmovups %ymm2,-0x34b8(%rbp)
 1272039:	ff 
 127203a:	c5 fc 11 8d 30 cb ff 	vmovups %ymm1,-0x34d0(%rbp)
 1272041:	ff 
 1272042:	c5 fc 11 85 10 cb ff 	vmovups %ymm0,-0x34f0(%rbp)
 1272049:	ff 
 127204a:	48 8d bd 10 cb ff ff 	lea    -0x34f0(%rbp),%rdi
 1272051:	4c 89 ee             	mov    %r13,%rsi
 1272054:	c5 f8 77             	vzeroupper 
 1272057:	e8 54 33 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 127205c:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1272063:	0f 84 90 07 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 1272069:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1272070:	ff 
 1272071:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1272078:	ff 
 1272079:	c5 fc 11 8d 80 e4 ff 	vmovups %ymm1,-0x1b80(%rbp)
 1272080:	ff 
 1272081:	c5 fc 11 85 70 e4 ff 	vmovups %ymm0,-0x1b90(%rbp)
 1272088:	ff 
 1272089:	48 8d bd 70 e4 ff ff 	lea    -0x1b90(%rbp),%rdi
 1272090:	e9 0b 03 00 00       	jmp    12723a0 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8210>
 1272095:	4c 89 ff             	mov    %r15,%rdi
 1272098:	4c 89 ee             	mov    %r13,%rsi
 127209b:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 127209f:	48 89 d9             	mov    %rbx,%rcx
 12720a2:	e8 f9 44 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 12720a7:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 12720ae:	ff 
 12720af:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12720b3:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12720b8:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 12720bf:	ff 
 12720c0:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 12720c7:	ff 
 12720c8:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 12720cf:	ff 
 12720d0:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 12720d7:	ff 
 12720d8:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12720dd:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12720e2:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12720e7:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12720eb:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 12720f2:	4c 89 ee             	mov    %r13,%rsi
 12720f5:	c5 f8 77             	vzeroupper 
 12720f8:	e8 83 31 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 12720fd:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1272104:	74 43                	je     1272149 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7fb9>
 1272106:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 127210d:	ff 
 127210e:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1272115:	ff 
 1272116:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 127211d:	ff 
 127211e:	c5 fc 11 95 e8 ca ff 	vmovups %ymm2,-0x3518(%rbp)
 1272125:	ff 
 1272126:	c5 fc 11 8d d0 ca ff 	vmovups %ymm1,-0x3530(%rbp)
 127212d:	ff 
 127212e:	c5 fc 11 85 b0 ca ff 	vmovups %ymm0,-0x3550(%rbp)
 1272135:	ff 
 1272136:	48 8d bd b0 ca ff ff 	lea    -0x3550(%rbp),%rdi
 127213d:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1272141:	c5 f8 77             	vzeroupper 
 1272144:	e8 67 32 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1272149:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1272150:	74 33                	je     1272185 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x7ff5>
 1272152:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1272159:	ff 
 127215a:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1272161:	ff 
 1272162:	c5 fc 11 8d 50 e4 ff 	vmovups %ymm1,-0x1bb0(%rbp)
 1272169:	ff 
 127216a:	c5 fc 11 85 40 e4 ff 	vmovups %ymm0,-0x1bc0(%rbp)
 1272171:	ff 
 1272172:	48 8d bd 40 e4 ff ff 	lea    -0x1bc0(%rbp),%rdi
 1272179:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 127217d:	c5 f8 77             	vzeroupper 
 1272180:	e8 5b 71 fe ff       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 1272185:	80 bd f8 fd ff ff 00 	cmpb   $0x0,-0x208(%rbp)
 127218c:	74 26                	je     12721b4 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8024>
 127218e:	48 8b 85 e0 fd ff ff 	mov    -0x220(%rbp),%rax
 1272195:	48 69 8d f0 fd ff ff 	imul   $0x118,-0x210(%rbp),%rcx
 127219c:	18 01 00 00 
 12721a0:	44 89 f2             	mov    %r14d,%edx
 12721a3:	c1 e2 04             	shl    $0x4,%edx
 12721a6:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 12721ad:	01 
 12721ae:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 12721b4:	48 8d bd c0 fd ff ff 	lea    -0x240(%rbp),%rdi
 12721bb:	e8 b0 4f 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 12721c0:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 12721c4:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 12721c9:	e9 21 d3 ff ff       	jmp    126f4ef <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x535f>
 12721ce:	4c 89 ef             	mov    %r13,%rdi
 12721d1:	4c 89 fe             	mov    %r15,%rsi
 12721d4:	4c 89 f2             	mov    %r14,%rdx
 12721d7:	4c 89 e1             	mov    %r12,%rcx
 12721da:	e8 c1 43 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 12721df:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 12721e6:	ff 
 12721e7:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12721eb:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12721f0:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 12721f7:	ff 
 12721f8:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 12721ff:	ff 
 1272200:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1272207:	ff 
 1272208:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 127220f:	ff 
 1272210:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1272215:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 127221a:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 127221f:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1272223:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 127222a:	4c 89 fe             	mov    %r15,%rsi
 127222d:	c5 f8 77             	vzeroupper 
 1272230:	e8 4b 30 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1272235:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 127223c:	74 42                	je     1272280 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x80f0>
 127223e:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1272245:	ff 
 1272246:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 127224d:	ff 
 127224e:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1272255:	ff 
 1272256:	c5 fc 11 95 88 ca ff 	vmovups %ymm2,-0x3578(%rbp)
 127225d:	ff 
 127225e:	c5 fc 11 8d 70 ca ff 	vmovups %ymm1,-0x3590(%rbp)
 1272265:	ff 
 1272266:	c5 fc 11 85 50 ca ff 	vmovups %ymm0,-0x35b0(%rbp)
 127226d:	ff 
 127226e:	48 8d bd 50 ca ff ff 	lea    -0x35b0(%rbp),%rdi
 1272275:	4c 89 fe             	mov    %r15,%rsi
 1272278:	c5 f8 77             	vzeroupper 
 127227b:	e8 30 31 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1272280:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1272287:	0f 84 6c 05 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 127228d:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1272294:	ff 
 1272295:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 127229c:	ff 
 127229d:	c5 fc 11 8d 20 e4 ff 	vmovups %ymm1,-0x1be0(%rbp)
 12722a4:	ff 
 12722a5:	c5 fc 11 85 10 e4 ff 	vmovups %ymm0,-0x1bf0(%rbp)
 12722ac:	ff 
 12722ad:	48 8d bd 10 e4 ff ff 	lea    -0x1bf0(%rbp),%rdi
 12722b4:	e9 d6 01 00 00       	jmp    127248f <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x82ff>
 12722b9:	4c 89 e7             	mov    %r12,%rdi
 12722bc:	4c 89 ee             	mov    %r13,%rsi
 12722bf:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 12722c3:	4c 89 f1             	mov    %r14,%rcx
 12722c6:	e8 d5 42 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 12722cb:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 12722d2:	ff 
 12722d3:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12722d7:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12722dc:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 12722e3:	ff 
 12722e4:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 12722eb:	ff 
 12722ec:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 12722f3:	ff 
 12722f4:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 12722fb:	ff 
 12722fc:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1272301:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1272306:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 127230b:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 127230f:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1272316:	4c 89 ee             	mov    %r13,%rsi
 1272319:	c5 f8 77             	vzeroupper 
 127231c:	e8 5f 2f fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1272321:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1272328:	74 42                	je     127236c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x81dc>
 127232a:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1272331:	ff 
 1272332:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1272339:	ff 
 127233a:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1272341:	ff 
 1272342:	c5 fc 11 95 48 d1 ff 	vmovups %ymm2,-0x2eb8(%rbp)
 1272349:	ff 
 127234a:	c5 fc 11 8d 30 d1 ff 	vmovups %ymm1,-0x2ed0(%rbp)
 1272351:	ff 
 1272352:	c5 fc 11 85 10 d1 ff 	vmovups %ymm0,-0x2ef0(%rbp)
 1272359:	ff 
 127235a:	48 8d bd 10 d1 ff ff 	lea    -0x2ef0(%rbp),%rdi
 1272361:	4c 89 ee             	mov    %r13,%rsi
 1272364:	c5 f8 77             	vzeroupper 
 1272367:	e8 44 30 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 127236c:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1272373:	0f 84 80 04 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 1272379:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1272380:	ff 
 1272381:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1272388:	ff 
 1272389:	c5 fc 11 8d 80 e7 ff 	vmovups %ymm1,-0x1880(%rbp)
 1272390:	ff 
 1272391:	c5 fc 11 85 70 e7 ff 	vmovups %ymm0,-0x1890(%rbp)
 1272398:	ff 
 1272399:	48 8d bd 70 e7 ff ff 	lea    -0x1890(%rbp),%rdi
 12723a0:	4c 89 ee             	mov    %r13,%rsi
 12723a3:	e9 49 04 00 00       	jmp    12727f1 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8661>
 12723a8:	4c 89 e7             	mov    %r12,%rdi
 12723ab:	4c 89 fe             	mov    %r15,%rsi
 12723ae:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 12723b2:	4c 89 f1             	mov    %r14,%rcx
 12723b5:	e8 e6 41 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 12723ba:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 12723c1:	ff 
 12723c2:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12723c6:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12723cb:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 12723d2:	ff 
 12723d3:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 12723da:	ff 
 12723db:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 12723e2:	ff 
 12723e3:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 12723ea:	ff 
 12723eb:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12723f0:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12723f5:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12723fa:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12723fe:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1272405:	4c 89 fe             	mov    %r15,%rsi
 1272408:	c5 f8 77             	vzeroupper 
 127240b:	e8 70 2e fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1272410:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1272417:	74 42                	je     127245b <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x82cb>
 1272419:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1272420:	ff 
 1272421:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1272428:	ff 
 1272429:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1272430:	ff 
 1272431:	c5 fc 11 95 08 cf ff 	vmovups %ymm2,-0x30f8(%rbp)
 1272438:	ff 
 1272439:	c5 fc 11 8d f0 ce ff 	vmovups %ymm1,-0x3110(%rbp)
 1272440:	ff 
 1272441:	c5 fc 11 85 d0 ce ff 	vmovups %ymm0,-0x3130(%rbp)
 1272448:	ff 
 1272449:	48 8d bd d0 ce ff ff 	lea    -0x3130(%rbp),%rdi
 1272450:	4c 89 fe             	mov    %r15,%rsi
 1272453:	c5 f8 77             	vzeroupper 
 1272456:	e8 55 2f fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 127245b:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1272462:	0f 84 91 03 00 00    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 1272468:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 127246f:	ff 
 1272470:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1272477:	ff 
 1272478:	c5 fc 11 8d 60 e6 ff 	vmovups %ymm1,-0x19a0(%rbp)
 127247f:	ff 
 1272480:	c5 fc 11 85 50 e6 ff 	vmovups %ymm0,-0x19b0(%rbp)
 1272487:	ff 
 1272488:	48 8d bd 50 e6 ff ff 	lea    -0x19b0(%rbp),%rdi
 127248f:	4c 89 fe             	mov    %r15,%rsi
 1272492:	e9 5a 03 00 00       	jmp    12727f1 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8661>
 1272497:	4c 89 f7             	mov    %r14,%rdi
 127249a:	4c 89 fe             	mov    %r15,%rsi
 127249d:	4c 89 e2             	mov    %r12,%rdx
 12724a0:	48 89 d9             	mov    %rbx,%rcx
 12724a3:	e8 f8 40 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 12724a8:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 12724af:	ff 
 12724b0:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12724b4:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12724b9:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 12724c0:	ff 
 12724c1:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 12724c8:	ff 
 12724c9:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 12724d0:	ff 
 12724d1:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 12724d8:	ff 
 12724d9:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12724de:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12724e3:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12724e8:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12724ec:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 12724f3:	4c 89 fe             	mov    %r15,%rsi
 12724f6:	c5 f8 77             	vzeroupper 
 12724f9:	e8 82 2d fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 12724fe:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1272505:	74 43                	je     127254a <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x83ba>
 1272507:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 127250e:	ff 
 127250f:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1272516:	ff 
 1272517:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 127251e:	ff 
 127251f:	c5 fc 11 95 68 cc ff 	vmovups %ymm2,-0x3398(%rbp)
 1272526:	ff 
 1272527:	c5 fc 11 8d 50 cc ff 	vmovups %ymm1,-0x33b0(%rbp)
 127252e:	ff 
 127252f:	c5 fc 11 85 30 cc ff 	vmovups %ymm0,-0x33d0(%rbp)
 1272536:	ff 
 1272537:	48 8d bd 30 cc ff ff 	lea    -0x33d0(%rbp),%rdi
 127253e:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1272542:	c5 f8 77             	vzeroupper 
 1272545:	e8 66 2e fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 127254a:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1272551:	74 33                	je     1272586 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x83f6>
 1272553:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 127255a:	ff 
 127255b:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1272562:	ff 
 1272563:	c5 fc 11 8d 10 e5 ff 	vmovups %ymm1,-0x1af0(%rbp)
 127256a:	ff 
 127256b:	c5 fc 11 85 00 e5 ff 	vmovups %ymm0,-0x1b00(%rbp)
 1272572:	ff 
 1272573:	48 8d bd 00 e5 ff ff 	lea    -0x1b00(%rbp),%rdi
 127257a:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 127257e:	c5 f8 77             	vzeroupper 
 1272581:	e8 5a 6d fe ff       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 1272586:	80 bd f8 fd ff ff 00 	cmpb   $0x0,-0x208(%rbp)
 127258d:	74 26                	je     12725b5 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8425>
 127258f:	48 8b 85 e0 fd ff ff 	mov    -0x220(%rbp),%rax
 1272596:	48 69 8d f0 fd ff ff 	imul   $0x118,-0x210(%rbp),%rcx
 127259d:	18 01 00 00 
 12725a1:	44 89 ea             	mov    %r13d,%edx
 12725a4:	c1 e2 04             	shl    $0x4,%edx
 12725a7:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 12725ae:	01 
 12725af:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 12725b5:	48 8d bd c0 fd ff ff 	lea    -0x240(%rbp),%rdi
 12725bc:	e8 af 4b 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 12725c1:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 12725c5:	66 44 89 68 10       	mov    %r13w,0x10(%rax)
 12725ca:	e9 20 cf ff ff       	jmp    126f4ef <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x535f>
 12725cf:	4c 89 ef             	mov    %r13,%rdi
 12725d2:	4c 89 f6             	mov    %r14,%rsi
 12725d5:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 12725d9:	48 89 d9             	mov    %rbx,%rcx
 12725dc:	e8 bf 3f 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 12725e1:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 12725e8:	ff 
 12725e9:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12725ed:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12725f2:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 12725f9:	ff 
 12725fa:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1272601:	ff 
 1272602:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1272609:	ff 
 127260a:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1272611:	ff 
 1272612:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1272617:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 127261c:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1272621:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1272625:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 127262c:	4c 89 f6             	mov    %r14,%rsi
 127262f:	c5 f8 77             	vzeroupper 
 1272632:	e8 49 2c fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1272637:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 127263e:	74 43                	je     1272683 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x84f3>
 1272640:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1272647:	ff 
 1272648:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 127264f:	ff 
 1272650:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1272657:	ff 
 1272658:	c5 fc 11 95 28 ca ff 	vmovups %ymm2,-0x35d8(%rbp)
 127265f:	ff 
 1272660:	c5 fc 11 8d 10 ca ff 	vmovups %ymm1,-0x35f0(%rbp)
 1272667:	ff 
 1272668:	c5 fc 11 85 f0 c9 ff 	vmovups %ymm0,-0x3610(%rbp)
 127266f:	ff 
 1272670:	48 8d bd f0 c9 ff ff 	lea    -0x3610(%rbp),%rdi
 1272677:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 127267b:	c5 f8 77             	vzeroupper 
 127267e:	e8 2d 2d fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1272683:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 127268a:	74 33                	je     12726bf <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x852f>
 127268c:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1272693:	ff 
 1272694:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 127269b:	ff 
 127269c:	c5 fc 11 8d f0 e3 ff 	vmovups %ymm1,-0x1c10(%rbp)
 12726a3:	ff 
 12726a4:	c5 fc 11 85 e0 e3 ff 	vmovups %ymm0,-0x1c20(%rbp)
 12726ab:	ff 
 12726ac:	48 8d bd e0 e3 ff ff 	lea    -0x1c20(%rbp),%rdi
 12726b3:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 12726b7:	c5 f8 77             	vzeroupper 
 12726ba:	e8 21 6c fe ff       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 12726bf:	80 bd f8 fd ff ff 00 	cmpb   $0x0,-0x208(%rbp)
 12726c6:	74 26                	je     12726ee <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x855e>
 12726c8:	48 8b 85 e0 fd ff ff 	mov    -0x220(%rbp),%rax
 12726cf:	48 69 8d f0 fd ff ff 	imul   $0x118,-0x210(%rbp),%rcx
 12726d6:	18 01 00 00 
 12726da:	44 89 fa             	mov    %r15d,%edx
 12726dd:	c1 e2 04             	shl    $0x4,%edx
 12726e0:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 12726e7:	01 
 12726e8:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 12726ee:	48 8d bd c0 fd ff ff 	lea    -0x240(%rbp),%rdi
 12726f5:	e8 76 4a 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 12726fa:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 12726fe:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 1272703:	e9 e7 cd ff ff       	jmp    126f4ef <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x535f>
 1272708:	4c 89 e7             	mov    %r12,%rdi
 127270b:	4c 89 f6             	mov    %r14,%rsi
 127270e:	48 8b 95 68 ff ff ff 	mov    -0x98(%rbp),%rdx
 1272715:	4c 89 f9             	mov    %r15,%rcx
 1272718:	e8 83 3e 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 127271d:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1272724:	ff 
 1272725:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1272729:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 127272e:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1272735:	ff 
 1272736:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 127273d:	ff 
 127273e:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1272745:	ff 
 1272746:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 127274d:	ff 
 127274e:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1272753:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1272758:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 127275d:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1272761:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1272768:	4c 89 f6             	mov    %r14,%rsi
 127276b:	c5 f8 77             	vzeroupper 
 127276e:	e8 0d 2b fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1272773:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 127277a:	74 42                	je     12727be <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x862e>
 127277c:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1272783:	ff 
 1272784:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 127278b:	ff 
 127278c:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1272793:	ff 
 1272794:	c5 fc 11 95 c8 c9 ff 	vmovups %ymm2,-0x3638(%rbp)
 127279b:	ff 
 127279c:	c5 fc 11 8d b0 c9 ff 	vmovups %ymm1,-0x3650(%rbp)
 12727a3:	ff 
 12727a4:	c5 fc 11 85 90 c9 ff 	vmovups %ymm0,-0x3670(%rbp)
 12727ab:	ff 
 12727ac:	48 8d bd 90 c9 ff ff 	lea    -0x3670(%rbp),%rdi
 12727b3:	4c 89 f6             	mov    %r14,%rsi
 12727b6:	c5 f8 77             	vzeroupper 
 12727b9:	e8 f2 2b fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12727be:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 12727c5:	74 32                	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 12727c7:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 12727ce:	ff 
 12727cf:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 12727d6:	ff 
 12727d7:	c5 fc 11 8d c0 e3 ff 	vmovups %ymm1,-0x1c40(%rbp)
 12727de:	ff 
 12727df:	c5 fc 11 85 b0 e3 ff 	vmovups %ymm0,-0x1c50(%rbp)
 12727e6:	ff 
 12727e7:	48 8d bd b0 e3 ff ff 	lea    -0x1c50(%rbp),%rdi
 12727ee:	4c 89 f6             	mov    %r14,%rsi
 12727f1:	c5 f8 77             	vzeroupper 
 12727f4:	e8 e7 6a fe ff       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 12727f9:	80 bd f8 fd ff ff 00 	cmpb   $0x0,-0x208(%rbp)
 1272800:	74 25                	je     1272827 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8697>
 1272802:	48 8b 85 e0 fd ff ff 	mov    -0x220(%rbp),%rax
 1272809:	48 69 8d f0 fd ff ff 	imul   $0x118,-0x210(%rbp),%rcx
 1272810:	18 01 00 00 
 1272814:	89 da                	mov    %ebx,%edx
 1272816:	c1 e2 04             	shl    $0x4,%edx
 1272819:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 1272820:	01 
 1272821:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 1272827:	48 8d bd c0 fd ff ff 	lea    -0x240(%rbp),%rdi
 127282e:	e8 3d 49 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1272833:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 1272837:	66 89 58 10          	mov    %bx,0x10(%rax)
 127283b:	e9 af cc ff ff       	jmp    126f4ef <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x535f>
 1272840:	48 89 df             	mov    %rbx,%rdi
 1272843:	4c 89 fe             	mov    %r15,%rsi
 1272846:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 127284a:	4c 89 e9             	mov    %r13,%rcx
 127284d:	e8 4e 3d 00 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 1272852:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1272859:	ff 
 127285a:	48 8b 45 18          	mov    0x18(%rbp),%rax
 127285e:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1272863:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 127286a:	ff 
 127286b:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1272872:	ff 
 1272873:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 127287a:	ff 
 127287b:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1272882:	ff 
 1272883:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1272888:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 127288d:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1272892:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1272896:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 127289d:	4c 89 fe             	mov    %r15,%rsi
 12728a0:	c5 f8 77             	vzeroupper 
 12728a3:	e8 d8 29 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 12728a8:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 12728af:	74 42                	je     12728f3 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8763>
 12728b1:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 12728b8:	ff 
 12728b9:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 12728c0:	ff 
 12728c1:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 12728c8:	ff 
 12728c9:	c5 fc 11 95 68 c9 ff 	vmovups %ymm2,-0x3698(%rbp)
 12728d0:	ff 
 12728d1:	c5 fc 11 8d 50 c9 ff 	vmovups %ymm1,-0x36b0(%rbp)
 12728d8:	ff 
 12728d9:	c5 fc 11 85 30 c9 ff 	vmovups %ymm0,-0x36d0(%rbp)
 12728e0:	ff 
 12728e1:	48 8d bd 30 c9 ff ff 	lea    -0x36d0(%rbp),%rdi
 12728e8:	4c 89 fe             	mov    %r15,%rsi
 12728eb:	c5 f8 77             	vzeroupper 
 12728ee:	e8 bd 2a fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 12728f3:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 12728fa:	74 32                	je     127292e <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x879e>
 12728fc:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1272903:	ff 
 1272904:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 127290b:	ff 
 127290c:	c5 fc 11 8d 90 e3 ff 	vmovups %ymm1,-0x1c70(%rbp)
 1272913:	ff 
 1272914:	c5 fc 11 85 80 e3 ff 	vmovups %ymm0,-0x1c80(%rbp)
 127291b:	ff 
 127291c:	48 8d bd 80 e3 ff ff 	lea    -0x1c80(%rbp),%rdi
 1272923:	4c 89 fe             	mov    %r15,%rsi
 1272926:	c5 f8 77             	vzeroupper 
 1272929:	e8 b2 69 fe ff       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 127292e:	80 bd f8 fd ff ff 00 	cmpb   $0x0,-0x208(%rbp)
 1272935:	74 26                	je     127295d <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x87cd>
 1272937:	48 8b 85 e0 fd ff ff 	mov    -0x220(%rbp),%rax
 127293e:	48 69 8d f0 fd ff ff 	imul   $0x118,-0x210(%rbp),%rcx
 1272945:	18 01 00 00 
 1272949:	44 89 e2             	mov    %r12d,%edx
 127294c:	c1 e2 04             	shl    $0x4,%edx
 127294f:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 1272956:	01 
 1272957:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 127295d:	48 8d bd c0 fd ff ff 	lea    -0x240(%rbp),%rdi
 1272964:	e8 07 48 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1272969:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 127296d:	66 44 89 60 10       	mov    %r12w,0x10(%rax)
 1272972:	e9 78 cb ff ff       	jmp    126f4ef <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x535f>
 1272977:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 127297e:	74 32                	je     12729b2 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8822>
 1272980:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1272987:	ff 
 1272988:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 127298f:	ff 
 1272990:	c5 fc 11 8d 00 e9 ff 	vmovups %ymm1,-0x1700(%rbp)
 1272997:	ff 
 1272998:	c5 fc 11 85 f0 e8 ff 	vmovups %ymm0,-0x1710(%rbp)
 127299f:	ff 
 12729a0:	48 8d bd f0 e8 ff ff 	lea    -0x1710(%rbp),%rdi
 12729a7:	4c 89 f6             	mov    %r14,%rsi
 12729aa:	c5 f8 77             	vzeroupper 
 12729ad:	e8 2e 69 fe ff       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 12729b2:	80 bd f8 fd ff ff 00 	cmpb   $0x0,-0x208(%rbp)
 12729b9:	74 24                	je     12729df <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x884f>
 12729bb:	48 8b 85 e0 fd ff ff 	mov    -0x220(%rbp),%rax
 12729c2:	48 69 8d f0 fd ff ff 	imul   $0x118,-0x210(%rbp),%rcx
 12729c9:	18 01 00 00 
 12729cd:	48 c7 44 08 68 b0 f9 	movq   $0x111f9b0,0x68(%rax,%rcx,1)
 12729d4:	11 01 
 12729d6:	48 c7 44 08 70 0b 00 	movq   $0xb,0x70(%rax,%rcx,1)
 12729dd:	00 00 
 12729df:	48 8d bd c0 fd ff ff 	lea    -0x240(%rbp),%rdi
 12729e6:	e8 85 47 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 12729eb:	c5 f8 10 05 ad c9 e1 	vmovups -0x1e3653(%rip),%xmm0        # 108f3a0 <__anon_205612>
 12729f2:	ff 
 12729f3:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 12729f7:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 12729fb:	48 c7 40 10 1a 00 00 	movq   $0x1a,0x10(%rax)
 1272a02:	00 
 1272a03:	e9 e7 ca ff ff       	jmp    126f4ef <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x535f>
 1272a08:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1272a0f:	74 32                	je     1272a43 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x88b3>
 1272a11:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1272a18:	ff 
 1272a19:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1272a20:	ff 
 1272a21:	c5 fc 11 8d a0 e8 ff 	vmovups %ymm1,-0x1760(%rbp)
 1272a28:	ff 
 1272a29:	c5 fc 11 85 90 e8 ff 	vmovups %ymm0,-0x1770(%rbp)
 1272a30:	ff 
 1272a31:	48 8d bd 90 e8 ff ff 	lea    -0x1770(%rbp),%rdi
 1272a38:	4c 89 f6             	mov    %r14,%rsi
 1272a3b:	c5 f8 77             	vzeroupper 
 1272a3e:	e8 9d 68 fe ff       	call   12592e0 <br.encoder.block_split_plan.Plan.deinit>
 1272a43:	80 bd f8 fd ff ff 00 	cmpb   $0x0,-0x208(%rbp)
 1272a4a:	74 24                	je     1272a70 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x88e0>
 1272a4c:	48 8b 85 e0 fd ff ff 	mov    -0x220(%rbp),%rax
 1272a53:	48 69 8d f0 fd ff ff 	imul   $0x118,-0x210(%rbp),%rcx
 1272a5a:	18 01 00 00 
 1272a5e:	48 c7 44 08 68 24 bb 	movq   $0x112bb24,0x68(%rax,%rcx,1)
 1272a65:	12 01 
 1272a67:	48 c7 44 08 70 10 00 	movq   $0x10,0x70(%rax,%rcx,1)
 1272a6e:	00 00 
 1272a70:	48 8d bd c0 fd ff ff 	lea    -0x240(%rbp),%rdi
 1272a77:	e8 f4 46 00 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1272a7c:	c5 f8 10 05 34 c9 e1 	vmovups -0x1e36cc(%rip),%xmm0        # 108f3b8 <__anon_205615>
 1272a83:	ff 
 1272a84:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 1272a88:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 1272a8c:	48 c7 40 10 52 00 00 	movq   $0x52,0x10(%rax)
 1272a93:	00 
 1272a94:	e9 56 ca ff ff       	jmp    126f4ef <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x535f>
 1272a99:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 1272aa0:	ff 
 1272aa1:	48 8b 45 18          	mov    0x18(%rbp),%rax
 1272aa5:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1272aaa:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 1272ab1:	ff 
 1272ab2:	c5 fc 10 8d a0 fe ff 	vmovups -0x160(%rbp),%ymm1
 1272ab9:	ff 
 1272aba:	c5 fc 10 95 c0 fe ff 	vmovups -0x140(%rbp),%ymm2
 1272ac1:	ff 
 1272ac2:	c5 fc 10 9d e0 fe ff 	vmovups -0x120(%rbp),%ymm3
 1272ac9:	ff 
 1272aca:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1272acf:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1272ad4:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1272ad9:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1272add:	48 8d bd b0 dc ff ff 	lea    -0x2350(%rbp),%rdi
 1272ae4:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1272ae8:	c5 f8 77             	vzeroupper 
 1272aeb:	e8 90 27 fd ff       	call   1245280 <br.EntropySymbolSplits.deinit>
 1272af0:	80 bd 78 fe ff ff 00 	cmpb   $0x0,-0x188(%rbp)
 1272af7:	74 43                	je     1272b3c <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x89ac>
 1272af9:	c5 fc 10 85 20 fe ff 	vmovups -0x1e0(%rbp),%ymm0
 1272b00:	ff 
 1272b01:	c5 fc 10 8d 40 fe ff 	vmovups -0x1c0(%rbp),%ymm1
 1272b08:	ff 
 1272b09:	c5 fc 10 95 58 fe ff 	vmovups -0x1a8(%rbp),%ymm2
 1272b10:	ff 
 1272b11:	c5 fc 11 95 a8 d1 ff 	vmovups %ymm2,-0x2e58(%rbp)
 1272b18:	ff 
 1272b19:	c5 fc 11 8d 90 d1 ff 	vmovups %ymm1,-0x2e70(%rbp)
 1272b20:	ff 
 1272b21:	c5 fc 11 85 70 d1 ff 	vmovups %ymm0,-0x2e90(%rbp)
 1272b28:	ff 
 1272b29:	48 8d bd 70 d1 ff ff 	lea    -0x2e90(%rbp),%rdi
 1272b30:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1272b34:	c5 f8 77             	vzeroupper 
 1272b37:	e8 74 28 fd ff       	call   12453b0 <br.encoder.literal_entropy_plan.Plan.deinit>
 1272b3c:	80 bd 50 ff ff ff 00 	cmpb   $0x0,-0xb0(%rbp)
 1272b43:	0f 84 b0 fc ff ff    	je     12727f9 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8669>
 1272b49:	c5 fc 10 85 20 ff ff 	vmovups -0xe0(%rbp),%ymm0
 1272b50:	ff 
 1272b51:	c5 fc 10 8d 30 ff ff 	vmovups -0xd0(%rbp),%ymm1
 1272b58:	ff 
 1272b59:	c5 fc 11 8d b0 e7 ff 	vmovups %ymm1,-0x1850(%rbp)
 1272b60:	ff 
 1272b61:	c5 fc 11 85 a0 e7 ff 	vmovups %ymm0,-0x1860(%rbp)
 1272b68:	ff 
 1272b69:	48 8d bd a0 e7 ff ff 	lea    -0x1860(%rbp),%rdi
 1272b70:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 1272b74:	e9 78 fc ff ff       	jmp    12727f1 <br.encodeEntropySplitCandidateAllocRecorded__anon_231669+0x8661>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
