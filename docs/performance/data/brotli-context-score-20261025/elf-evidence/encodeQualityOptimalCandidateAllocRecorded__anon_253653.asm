
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000128b2d0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653>:
 128b2d0:	55                   	push   %rbp
 128b2d1:	48 89 e5             	mov    %rsp,%rbp
 128b2d4:	41 57                	push   %r15
 128b2d6:	41 56                	push   %r14
 128b2d8:	41 55                	push   %r13
 128b2da:	41 54                	push   %r12
 128b2dc:	53                   	push   %rbx
 128b2dd:	48 81 ec 78 21 00 00 	sub    $0x2178,%rsp
 128b2e4:	49 89 fd             	mov    %rdi,%r13
 128b2e7:	41 f6 40 0e 01       	testb  $0x1,0xe(%r8)
 128b2ec:	0f 84 3d 04 00 00    	je     128b72f <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x45f>
 128b2f2:	4d 89 cf             	mov    %r9,%r15
 128b2f5:	4d 89 c6             	mov    %r8,%r14
 128b2f8:	49 89 cc             	mov    %rcx,%r12
 128b2fb:	48 89 d3             	mov    %rdx,%rbx
 128b2fe:	41 8b 00             	mov    (%r8),%eax
 128b301:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 128b308:	41 0f b6 40 0f       	movzbl 0xf(%r8),%eax
 128b30d:	88 45 c0             	mov    %al,-0x40(%rbp)
 128b310:	41 0f b7 50 0c       	movzwl 0xc(%r8),%edx
 128b315:	41 0f b7 78 0a       	movzwl 0xa(%r8),%edi
 128b31a:	45 0f b7 40 08       	movzwl 0x8(%r8),%r8d
 128b31f:	41 0f b6 41 4e       	movzbl 0x4e(%r9),%eax
 128b324:	24 1f                	and    $0x1f,%al
 128b326:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b32b:	c4 e2 f9 f7 c1       	shlx   %rax,%rcx,%rax
 128b330:	48 83 c0 f0          	add    $0xfffffffffffffff0,%rax
 128b334:	4c 39 e0             	cmp    %r12,%rax
 128b337:	49 0f 43 c4          	cmovae %r12,%rax
 128b33b:	48 3d 00 80 00 00    	cmp    $0x8000,%rax
 128b341:	b9 00 80 00 00       	mov    $0x8000,%ecx
 128b346:	48 0f 42 c8          	cmovb  %rax,%rcx
 128b34a:	48 89 8d 58 ff ff ff 	mov    %rcx,-0xa8(%rbp)
 128b351:	48 89 8d 18 fe ff ff 	mov    %rcx,-0x1e8(%rbp)
 128b358:	4c 89 45 80          	mov    %r8,-0x80(%rbp)
 128b35c:	4c 89 85 20 fe ff ff 	mov    %r8,-0x1e0(%rbp)
 128b363:	48 89 7d 88          	mov    %rdi,-0x78(%rbp)
 128b367:	48 89 bd 28 fe ff ff 	mov    %rdi,-0x1d8(%rbp)
 128b36e:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 128b372:	48 89 95 30 fe ff ff 	mov    %rdx,-0x1d0(%rbp)
 128b379:	c5 fc 28 05 ff 6e d7 	vmovaps -0x289101(%rip),%ymm0        # 1002280 <__anon_252193+0xc0>
 128b380:	ff 
 128b381:	c5 fc 11 85 38 fe ff 	vmovups %ymm0,-0x1c8(%rbp)
 128b388:	ff 
 128b389:	c6 85 58 fe ff ff 00 	movb   $0x0,-0x1a8(%rbp)
 128b390:	48 8d bd 90 fe ff ff 	lea    -0x170(%rbp),%rdi
 128b397:	4c 8d 85 18 fe ff ff 	lea    -0x1e8(%rbp),%r8
 128b39e:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 128b3a2:	48 89 da             	mov    %rbx,%rdx
 128b3a5:	4c 89 e1             	mov    %r12,%rcx
 128b3a8:	c5 f8 77             	vzeroupper 
 128b3ab:	e8 00 a3 fa ff       	call   12356b0 <lz77.optimalPlanAlloc>
 128b3b0:	0f b7 85 b8 fe ff ff 	movzwl -0x148(%rbp),%eax
 128b3b7:	66 85 c0             	test   %ax,%ax
 128b3ba:	0f 85 45 06 00 00    	jne    128ba05 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x735>
 128b3c0:	4c 8b 85 90 fe ff ff 	mov    -0x170(%rbp),%r8
 128b3c7:	4c 8b 8d 98 fe ff ff 	mov    -0x168(%rbp),%r9
 128b3ce:	48 83 bd a8 fe ff ff 	cmpq   $0x0,-0x158(%rbp)
 128b3d5:	00 
 128b3d6:	0f 84 2d 03 00 00    	je     128b709 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x439>
 128b3dc:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 128b3e3:	4c 89 6d b0          	mov    %r13,-0x50(%rbp)
 128b3e7:	48 8d bd 00 ff ff ff 	lea    -0x100(%rbp),%rdi
 128b3ee:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 128b3f2:	4c 89 fe             	mov    %r15,%rsi
 128b3f5:	48 89 da             	mov    %rbx,%rdx
 128b3f8:	4c 89 e1             	mov    %r12,%rcx
 128b3fb:	4c 89 45 a8          	mov    %r8,-0x58(%rbp)
 128b3ff:	4c 89 4d c8          	mov    %r9,-0x38(%rbp)
 128b403:	e8 c8 b5 f8 ff       	call   12169d0 <br.encoder.command_plan.buildAlloc>
 128b408:	44 0f b7 ad 18 ff ff 	movzwl -0xe8(%rbp),%r13d
 128b40f:	ff 
 128b410:	66 45 85 ed          	test   %r13w,%r13w
 128b414:	0f 85 25 07 00 00    	jne    128bb3f <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x86f>
 128b41a:	48 8b 8d 00 ff ff ff 	mov    -0x100(%rbp),%rcx
 128b421:	4c 8b 8d 08 ff ff ff 	mov    -0xf8(%rbp),%r9
 128b428:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128b42c:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 128b433:	ff 
 128b434:	c5 fc 11 85 60 fd ff 	vmovups %ymm0,-0x2a0(%rbp)
 128b43b:	ff 
 128b43c:	c5 fc 11 85 80 fd ff 	vmovups %ymm0,-0x280(%rbp)
 128b443:	ff 
 128b444:	c5 fc 11 85 a0 fd ff 	vmovups %ymm0,-0x260(%rbp)
 128b44b:	ff 
 128b44c:	c5 fc 11 85 b0 fd ff 	vmovups %ymm0,-0x250(%rbp)
 128b453:	ff 
 128b454:	48 8d 85 40 fd ff ff 	lea    -0x2c0(%rbp),%rax
 128b45b:	48 8d bd 38 ff ff ff 	lea    -0xc8(%rbp),%rdi
 128b462:	4c 89 fe             	mov    %r15,%rsi
 128b465:	49 89 cf             	mov    %rcx,%r15
 128b468:	48 89 da             	mov    %rbx,%rdx
 128b46b:	4c 89 e1             	mov    %r12,%rcx
 128b46e:	4d 89 f8             	mov    %r15,%r8
 128b471:	4c 89 4d b8          	mov    %r9,-0x48(%rbp)
 128b475:	ff b5 60 ff ff ff    	push   -0xa0(%rbp)
 128b47b:	50                   	push   %rax
 128b47c:	c5 f8 77             	vzeroupper 
 128b47f:	e8 4c ef f5 ff       	call   11ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>
 128b484:	48 83 c4 10          	add    $0x10,%rsp
 128b488:	44 0f b7 ad 48 ff ff 	movzwl -0xb8(%rbp),%r13d
 128b48f:	ff 
 128b490:	66 45 85 ed          	test   %r13w,%r13w
 128b494:	0f 85 75 05 00 00    	jne    128ba0f <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x73f>
 128b49a:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 128b4a1:	4c 8b ad 40 ff ff ff 	mov    -0xc0(%rbp),%r13
 128b4a8:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 128b4ac:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 128b4b3:	4c 89 ad 78 ff ff ff 	mov    %r13,-0x88(%rbp)
 128b4ba:	f6 45 c0 01          	testb  $0x1,-0x40(%rbp)
 128b4be:	0f 84 8f 02 00 00    	je     128b753 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x483>
 128b4c4:	4c 89 6d c0          	mov    %r13,-0x40(%rbp)
 128b4c8:	48 8d 05 11 6c d7 ff 	lea    -0x2893ef(%rip),%rax        # 10020e0 <__anon_35167>
 128b4cf:	48 8d bd 78 e8 ff ff 	lea    -0x1788(%rbp),%rdi
 128b4d6:	4c 8b 6d d0          	mov    -0x30(%rbp),%r13
 128b4da:	4c 89 ee             	mov    %r13,%rsi
 128b4dd:	48 89 da             	mov    %rbx,%rdx
 128b4e0:	4c 89 e1             	mov    %r12,%rcx
 128b4e3:	4c 89 7d 90          	mov    %r15,-0x70(%rbp)
 128b4e7:	4d 89 f8             	mov    %r15,%r8
 128b4ea:	4c 8b 4d b8          	mov    -0x48(%rbp),%r9
 128b4ee:	50                   	push   %rax
 128b4ef:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 128b4f6:	41 57                	push   %r15
 128b4f8:	e8 53 23 fb ff       	call   123d850 <br.encoder.entropy_feedback.buildWithStartingDistances>
 128b4fd:	48 83 c4 10          	add    $0x10,%rsp
 128b501:	48 8d bd 60 de ff ff 	lea    -0x21a0(%rbp),%rdi
 128b508:	ba 18 0a 00 00       	mov    $0xa18,%edx
 128b50d:	48 8d b5 78 e8 ff ff 	lea    -0x1788(%rbp),%rsi
 128b514:	e8 07 ad 00 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 128b519:	0f b7 85 90 f2 ff ff 	movzwl -0xd70(%rbp),%eax
 128b520:	66 85 c0             	test   %ax,%ax
 128b523:	0f 85 2a 05 00 00    	jne    128ba53 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x783>
 128b529:	48 8d bd 98 f2 ff ff 	lea    -0xd68(%rbp),%rdi
 128b530:	48 8d b5 60 de ff ff 	lea    -0x21a0(%rbp),%rsi
 128b537:	ba 18 0a 00 00       	mov    $0xa18,%edx
 128b53c:	e8 df ac 00 00       	call   1296220 <compiler_rt.memcpy.memcpyFast>
 128b541:	4c 89 bd d0 fd ff ff 	mov    %r15,-0x230(%rbp)
 128b548:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 128b54c:	48 89 85 d8 fd ff ff 	mov    %rax,-0x228(%rbp)
 128b553:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 128b557:	48 89 85 e0 fd ff ff 	mov    %rax,-0x220(%rbp)
 128b55e:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 128b562:	48 89 85 e8 fd ff ff 	mov    %rax,-0x218(%rbp)
 128b569:	c5 fc 28 05 0f 6d d7 	vmovaps -0x2892f1(%rip),%ymm0        # 1002280 <__anon_252193+0xc0>
 128b570:	ff 
 128b571:	c5 fc 11 85 f0 fd ff 	vmovups %ymm0,-0x210(%rbp)
 128b578:	ff 
 128b579:	c6 85 10 fe ff ff 00 	movb   $0x0,-0x1f0(%rbp)
 128b580:	48 8d 85 a8 f2 ff ff 	lea    -0xd58(%rbp),%rax
 128b587:	48 89 85 e0 fe ff ff 	mov    %rax,-0x120(%rbp)
 128b58e:	48 8d 85 a8 f4 ff ff 	lea    -0xb58(%rbp),%rax
 128b595:	48 89 85 e8 fe ff ff 	mov    %rax,-0x118(%rbp)
 128b59c:	c5 f8 10 85 98 f2 ff 	vmovups -0xd68(%rbp),%xmm0
 128b5a3:	ff 
 128b5a4:	c5 f8 11 85 f0 fe ff 	vmovups %xmm0,-0x110(%rbp)
 128b5ab:	ff 
 128b5ac:	48 8d bd 60 fe ff ff 	lea    -0x1a0(%rbp),%rdi
 128b5b3:	4c 8d 85 d0 fd ff ff 	lea    -0x230(%rbp),%r8
 128b5ba:	4c 8d 8d e0 fe ff ff 	lea    -0x120(%rbp),%r9
 128b5c1:	4c 89 ee             	mov    %r13,%rsi
 128b5c4:	48 89 da             	mov    %rbx,%rdx
 128b5c7:	4c 89 e1             	mov    %r12,%rcx
 128b5ca:	c5 f8 77             	vzeroupper 
 128b5cd:	e8 3e eb fa ff       	call   123a110 <lz77.optimalPlanAllocWithCostModel>
 128b5d2:	44 0f b7 ad 88 fe ff 	movzwl -0x178(%rbp),%r13d
 128b5d9:	ff 
 128b5da:	66 45 85 ed          	test   %r13w,%r13w
 128b5de:	0f 85 de 04 00 00    	jne    128bac2 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x7f2>
 128b5e4:	4c 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%r8
 128b5eb:	4c 8b 8d 68 fe ff ff 	mov    -0x198(%rbp),%r9
 128b5f2:	48 83 bd 78 fe ff ff 	cmpq   $0x0,-0x188(%rbp)
 128b5f9:	00 
 128b5fa:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 128b5fe:	0f 84 b8 01 00 00    	je     128b7bc <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x4ec>
 128b604:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 128b60b:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 128b60f:	4c 89 fe             	mov    %r15,%rsi
 128b612:	48 89 da             	mov    %rbx,%rdx
 128b615:	4c 89 e1             	mov    %r12,%rcx
 128b618:	4c 89 45 80          	mov    %r8,-0x80(%rbp)
 128b61c:	4c 89 4d 98          	mov    %r9,-0x68(%rbp)
 128b620:	e8 ab b3 f8 ff       	call   12169d0 <br.encoder.command_plan.buildAlloc>
 128b625:	44 0f b7 ad d8 fe ff 	movzwl -0x128(%rbp),%r13d
 128b62c:	ff 
 128b62d:	66 45 85 ed          	test   %r13w,%r13w
 128b631:	0f 85 56 05 00 00    	jne    128bb8d <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x8bd>
 128b637:	4c 8b 85 c0 fe ff ff 	mov    -0x140(%rbp),%r8
 128b63e:	4c 8b 8d c8 fe ff ff 	mov    -0x138(%rbp),%r9
 128b645:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128b649:	c5 fc 11 85 b0 fc ff 	vmovups %ymm0,-0x350(%rbp)
 128b650:	ff 
 128b651:	c5 fc 11 85 d0 fc ff 	vmovups %ymm0,-0x330(%rbp)
 128b658:	ff 
 128b659:	c5 fc 11 85 f0 fc ff 	vmovups %ymm0,-0x310(%rbp)
 128b660:	ff 
 128b661:	c5 fc 11 85 10 fd ff 	vmovups %ymm0,-0x2f0(%rbp)
 128b668:	ff 
 128b669:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 128b670:	ff 
 128b671:	48 8d 85 b0 fc ff ff 	lea    -0x350(%rbp),%rax
 128b678:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 128b67f:	4c 89 fe             	mov    %r15,%rsi
 128b682:	48 89 da             	mov    %rbx,%rdx
 128b685:	4c 89 e1             	mov    %r12,%rcx
 128b688:	4c 89 85 68 ff ff ff 	mov    %r8,-0x98(%rbp)
 128b68f:	4c 89 4d 88          	mov    %r9,-0x78(%rbp)
 128b693:	ff b5 60 ff ff ff    	push   -0xa0(%rbp)
 128b699:	50                   	push   %rax
 128b69a:	c5 f8 77             	vzeroupper 
 128b69d:	e8 2e ed f5 ff       	call   11ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>
 128b6a2:	48 83 c4 10          	add    $0x10,%rsp
 128b6a6:	44 0f b7 ad 30 ff ff 	movzwl -0xd0(%rbp),%r13d
 128b6ad:	ff 
 128b6ae:	66 45 85 ed          	test   %r13w,%r13w
 128b6b2:	0f 85 a4 04 00 00    	jne    128bb5c <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x88c>
 128b6b8:	4c 8b bd 20 ff ff ff 	mov    -0xe0(%rbp),%r15
 128b6bf:	4c 8b ad 28 ff ff ff 	mov    -0xd8(%rbp),%r13
 128b6c6:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 128b6ca:	49 39 d5             	cmp    %rdx,%r13
 128b6cd:	0f 83 a4 01 00 00    	jae    128b877 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x5a7>
 128b6d3:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b6d7:	48 8b 38             	mov    (%rax),%rdi
 128b6da:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b6de:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b6e2:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 128b6e6:	31 c9                	xor    %ecx,%ecx
 128b6e8:	ff 50 18             	call   *0x18(%rax)
 128b6eb:	4c 89 7d c0          	mov    %r15,-0x40(%rbp)
 128b6ef:	4c 89 bd 70 ff ff ff 	mov    %r15,-0x90(%rbp)
 128b6f6:	4d 89 ef             	mov    %r13,%r15
 128b6f9:	4c 89 ad 78 ff ff ff 	mov    %r13,-0x88(%rbp)
 128b700:	4c 8b 6d b0          	mov    -0x50(%rbp),%r13
 128b704:	e9 9d 01 00 00       	jmp    128b8a6 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x5d6>
 128b709:	4d 85 c9             	test   %r9,%r9
 128b70c:	74 21                	je     128b72f <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x45f>
 128b70e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b712:	48 8b 38             	mov    (%rax),%rdi
 128b715:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b719:	4d 01 c9             	add    %r9,%r9
 128b71c:	4b 8d 14 49          	lea    (%r9,%r9,2),%rdx
 128b720:	4c 89 c6             	mov    %r8,%rsi
 128b723:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b727:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b72c:	ff 50 18             	call   *0x18(%rax)
 128b72f:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128b733:	c4 c1 78 11 45 00    	vmovups %xmm0,0x0(%r13)
 128b739:	49 c7 45 10 00 00 00 	movq   $0x0,0x10(%r13)
 128b740:	00 
 128b741:	48 81 c4 78 21 00 00 	add    $0x2178,%rsp
 128b748:	5b                   	pop    %rbx
 128b749:	41 5c                	pop    %r12
 128b74b:	41 5d                	pop    %r13
 128b74d:	41 5e                	pop    %r14
 128b74f:	41 5f                	pop    %r15
 128b751:	5d                   	pop    %rbp
 128b752:	c3                   	ret    
 128b753:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128b757:	48 85 c9             	test   %rcx,%rcx
 128b75a:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 128b75e:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 128b762:	74 1e                	je     128b782 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x4b2>
 128b764:	49 8b 3e             	mov    (%r14),%rdi
 128b767:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b76b:	48 c1 e1 05          	shl    $0x5,%rcx
 128b76f:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b773:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b777:	4c 89 fe             	mov    %r15,%rsi
 128b77a:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b77f:	ff 50 18             	call   *0x18(%rax)
 128b782:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b786:	48 85 c9             	test   %rcx,%rcx
 128b789:	74 1e                	je     128b7a9 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x4d9>
 128b78b:	49 8b 3e             	mov    (%r14),%rdi
 128b78e:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b792:	48 01 c9             	add    %rcx,%rcx
 128b795:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b799:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b79d:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 128b7a1:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b7a6:	ff 50 18             	call   *0x18(%rax)
 128b7a9:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 128b7af:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128b7b3:	48 89 03             	mov    %rax,(%rbx)
 128b7b6:	4c 89 6b 08          	mov    %r13,0x8(%rbx)
 128b7ba:	eb 85                	jmp    128b741 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x471>
 128b7bc:	4d 85 c9             	test   %r9,%r9
 128b7bf:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 128b7c3:	74 1d                	je     128b7e2 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x512>
 128b7c5:	49 8b 3e             	mov    (%r14),%rdi
 128b7c8:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b7cc:	4d 01 c9             	add    %r9,%r9
 128b7cf:	4b 8d 14 49          	lea    (%r9,%r9,2),%rdx
 128b7d3:	4c 89 c6             	mov    %r8,%rsi
 128b7d6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b7da:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b7df:	ff 50 18             	call   *0x18(%rax)
 128b7e2:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 128b7e9:	48 85 d2             	test   %rdx,%rdx
 128b7ec:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 128b7f0:	4c 8b 65 c0          	mov    -0x40(%rbp),%r12
 128b7f4:	74 1d                	je     128b813 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x543>
 128b7f6:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 128b7fd:	49 8b 3e             	mov    (%r14),%rdi
 128b800:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b804:	48 01 d2             	add    %rdx,%rdx
 128b807:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b80b:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b810:	ff 50 18             	call   *0x18(%rax)
 128b813:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128b817:	48 85 c9             	test   %rcx,%rcx
 128b81a:	74 1e                	je     128b83a <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x56a>
 128b81c:	49 8b 3e             	mov    (%r14),%rdi
 128b81f:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b823:	48 c1 e1 05          	shl    $0x5,%rcx
 128b827:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b82b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b82f:	4c 89 fe             	mov    %r15,%rsi
 128b832:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b837:	ff 50 18             	call   *0x18(%rax)
 128b83a:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b83e:	48 85 c9             	test   %rcx,%rcx
 128b841:	74 1e                	je     128b861 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x591>
 128b843:	49 8b 3e             	mov    (%r14),%rdi
 128b846:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b84a:	48 01 c9             	add    %rcx,%rcx
 128b84d:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b851:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b855:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 128b859:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b85e:	ff 50 18             	call   *0x18(%rax)
 128b861:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 128b867:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128b86b:	48 89 03             	mov    %rax,(%rbx)
 128b86e:	4c 89 63 08          	mov    %r12,0x8(%rbx)
 128b872:	e9 ca fe ff ff       	jmp    128b741 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x471>
 128b877:	4d 85 ed             	test   %r13,%r13
 128b87a:	4c 89 ea             	mov    %r13,%rdx
 128b87d:	4c 8b 6d b0          	mov    -0x50(%rbp),%r13
 128b881:	74 17                	je     128b89a <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x5ca>
 128b883:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b887:	48 8b 38             	mov    (%rax),%rdi
 128b88a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b88e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b892:	4c 89 fe             	mov    %r15,%rsi
 128b895:	31 c9                	xor    %ecx,%ecx
 128b897:	ff 50 18             	call   *0x18(%rax)
 128b89a:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 128b89e:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128b8a2:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 128b8a6:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 128b8ad:	85 c9                	test   %ecx,%ecx
 128b8af:	0f 95 c0             	setne  %al
 128b8b2:	49 39 cc             	cmp    %rcx,%r12
 128b8b5:	0f 96 c1             	setbe  %cl
 128b8b8:	84 c8                	test   %cl,%al
 128b8ba:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b8be:	4c 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%r8
 128b8c5:	74 4c                	je     128b913 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x643>
 128b8c7:	48 8d 85 70 ff ff ff 	lea    -0x90(%rbp),%rax
 128b8ce:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 128b8d2:	48 89 de             	mov    %rbx,%rsi
 128b8d5:	4c 89 e2             	mov    %r12,%rdx
 128b8d8:	4c 89 f1             	mov    %r14,%rcx
 128b8db:	4c 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%r9
 128b8e2:	50                   	push   %rax
 128b8e3:	48 8d 85 98 f2 ff ff 	lea    -0xd68(%rbp),%rax
 128b8ea:	50                   	push   %rax
 128b8eb:	e8 3c 2e 02 00       	call   12ae72c <br.selectQualityCommandStateCandidate>
 128b8f0:	48 83 c4 10          	add    $0x10,%rsp
 128b8f4:	66 85 c0             	test   %ax,%ax
 128b8f7:	0f 85 76 03 00 00    	jne    128bc73 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x9a3>
 128b8fd:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 128b904:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 128b908:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 128b90f:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b913:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 128b917:	48 85 d2             	test   %rdx,%rdx
 128b91a:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 128b91e:	74 26                	je     128b946 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x676>
 128b920:	48 8b 3b             	mov    (%rbx),%rdi
 128b923:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b927:	48 c1 e2 05          	shl    $0x5,%rdx
 128b92b:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 128b92f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b933:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 128b93a:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b93f:	ff 50 18             	call   *0x18(%rax)
 128b942:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b946:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 128b94a:	48 85 d2             	test   %rdx,%rdx
 128b94d:	74 22                	je     128b971 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x6a1>
 128b94f:	48 8b 3b             	mov    (%rbx),%rdi
 128b952:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b956:	48 01 d2             	add    %rdx,%rdx
 128b959:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 128b95d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b961:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 128b965:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b96a:	ff 50 18             	call   *0x18(%rax)
 128b96d:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b971:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 128b978:	48 85 d2             	test   %rdx,%rdx
 128b97b:	74 21                	je     128b99e <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x6ce>
 128b97d:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 128b984:	48 8b 3b             	mov    (%rbx),%rdi
 128b987:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b98b:	48 01 d2             	add    %rdx,%rdx
 128b98e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b992:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b997:	ff 50 18             	call   *0x18(%rax)
 128b99a:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b99e:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128b9a2:	48 85 d2             	test   %rdx,%rdx
 128b9a5:	74 23                	je     128b9ca <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x6fa>
 128b9a7:	48 8b 3b             	mov    (%rbx),%rdi
 128b9aa:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b9ae:	48 c1 e2 05          	shl    $0x5,%rdx
 128b9b2:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 128b9b6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b9ba:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 128b9be:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b9c3:	ff 50 18             	call   *0x18(%rax)
 128b9c6:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b9ca:	48 85 c9             	test   %rcx,%rcx
 128b9cd:	74 1e                	je     128b9ed <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x71d>
 128b9cf:	48 8b 3b             	mov    (%rbx),%rdi
 128b9d2:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b9d6:	48 01 c9             	add    %rcx,%rcx
 128b9d9:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b9dd:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b9e1:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 128b9e5:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b9ea:	ff 50 18             	call   *0x18(%rax)
 128b9ed:	66 41 c7 45 10 00 00 	movw   $0x0,0x10(%r13)
 128b9f4:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 128b9f8:	49 89 45 00          	mov    %rax,0x0(%r13)
 128b9fc:	4d 89 7d 08          	mov    %r15,0x8(%r13)
 128ba00:	e9 3c fd ff ff       	jmp    128b741 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x471>
 128ba05:	66 41 89 45 10       	mov    %ax,0x10(%r13)
 128ba0a:	e9 32 fd ff ff       	jmp    128b741 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x471>
 128ba0f:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128ba13:	48 85 c9             	test   %rcx,%rcx
 128ba16:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 128ba1a:	74 1e                	je     128ba3a <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x76a>
 128ba1c:	48 8b 3b             	mov    (%rbx),%rdi
 128ba1f:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128ba23:	48 c1 e1 05          	shl    $0x5,%rcx
 128ba27:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ba2b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ba2f:	4c 89 fe             	mov    %r15,%rsi
 128ba32:	b9 03 00 00 00       	mov    $0x3,%ecx
 128ba37:	ff 50 18             	call   *0x18(%rax)
 128ba3a:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128ba3e:	48 85 c9             	test   %rcx,%rcx
 128ba41:	0f 84 1e 02 00 00    	je     128bc65 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x995>
 128ba47:	48 8b 3b             	mov    (%rbx),%rdi
 128ba4a:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128ba4e:	e9 fb 01 00 00       	jmp    128bc4e <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x97e>
 128ba53:	89 c3                	mov    %eax,%ebx
 128ba55:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 128ba59:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 128ba5d:	48 85 d2             	test   %rdx,%rdx
 128ba60:	74 18                	je     128ba7a <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x7aa>
 128ba62:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ba66:	48 8b 38             	mov    (%rax),%rdi
 128ba69:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ba6d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ba71:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 128ba75:	31 c9                	xor    %ecx,%ecx
 128ba77:	ff 50 18             	call   *0x18(%rax)
 128ba7a:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128ba7e:	48 85 c9             	test   %rcx,%rcx
 128ba81:	74 22                	je     128baa5 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x7d5>
 128ba83:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ba87:	48 8b 38             	mov    (%rax),%rdi
 128ba8a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ba8e:	48 c1 e1 05          	shl    $0x5,%rcx
 128ba92:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ba96:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ba9a:	4c 89 fe             	mov    %r15,%rsi
 128ba9d:	b9 03 00 00 00       	mov    $0x3,%ecx
 128baa2:	ff 50 18             	call   *0x18(%rax)
 128baa5:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128baa9:	48 85 c9             	test   %rcx,%rcx
 128baac:	0f 84 d0 02 00 00    	je     128bd82 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0xab2>
 128bab2:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bab6:	48 8b 38             	mov    (%rax),%rdi
 128bab9:	48 8b 40 08          	mov    0x8(%rax),%rax
 128babd:	e9 a9 02 00 00       	jmp    128bd6b <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0xa9b>
 128bac2:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 128bac6:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 128bacd:	48 85 d2             	test   %rdx,%rdx
 128bad0:	74 21                	je     128baf3 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x823>
 128bad2:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 128bad9:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128badd:	48 8b 38             	mov    (%rax),%rdi
 128bae0:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bae4:	48 01 d2             	add    %rdx,%rdx
 128bae7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128baeb:	b9 01 00 00 00       	mov    $0x1,%ecx
 128baf0:	ff 50 18             	call   *0x18(%rax)
 128baf3:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 128baf7:	48 85 d2             	test   %rdx,%rdx
 128bafa:	74 18                	je     128bb14 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x844>
 128bafc:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bb00:	48 8b 38             	mov    (%rax),%rdi
 128bb03:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bb07:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bb0b:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 128bb0f:	31 c9                	xor    %ecx,%ecx
 128bb11:	ff 50 18             	call   *0x18(%rax)
 128bb14:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128bb18:	48 85 c9             	test   %rcx,%rcx
 128bb1b:	74 22                	je     128bb3f <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x86f>
 128bb1d:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bb21:	48 8b 38             	mov    (%rax),%rdi
 128bb24:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bb28:	48 c1 e1 05          	shl    $0x5,%rcx
 128bb2c:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bb30:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bb34:	4c 89 fe             	mov    %r15,%rsi
 128bb37:	b9 03 00 00 00       	mov    $0x3,%ecx
 128bb3c:	ff 50 18             	call   *0x18(%rax)
 128bb3f:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128bb43:	48 85 c9             	test   %rcx,%rcx
 128bb46:	0f 84 19 01 00 00    	je     128bc65 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x995>
 128bb4c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bb50:	48 8b 38             	mov    (%rax),%rdi
 128bb53:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bb57:	e9 f2 00 00 00       	jmp    128bc4e <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x97e>
 128bb5c:	48 83 7d 88 00       	cmpq   $0x0,-0x78(%rbp)
 128bb61:	74 2a                	je     128bb8d <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x8bd>
 128bb63:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bb67:	48 8b 38             	mov    (%rax),%rdi
 128bb6a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bb6e:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 128bb72:	48 c1 e1 05          	shl    $0x5,%rcx
 128bb76:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bb7a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bb7e:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 128bb85:	b9 03 00 00 00       	mov    $0x3,%ecx
 128bb8a:	ff 50 18             	call   *0x18(%rax)
 128bb8d:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 128bb92:	74 26                	je     128bbba <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x8ea>
 128bb94:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bb98:	48 8b 38             	mov    (%rax),%rdi
 128bb9b:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bb9f:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128bba3:	48 01 c9             	add    %rcx,%rcx
 128bba6:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bbaa:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bbae:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 128bbb2:	b9 01 00 00 00       	mov    $0x1,%ecx
 128bbb7:	ff 50 18             	call   *0x18(%rax)
 128bbba:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 128bbc1:	48 85 d2             	test   %rdx,%rdx
 128bbc4:	74 21                	je     128bbe7 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x917>
 128bbc6:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 128bbcd:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bbd1:	48 8b 38             	mov    (%rax),%rdi
 128bbd4:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bbd8:	48 01 d2             	add    %rdx,%rdx
 128bbdb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bbdf:	b9 01 00 00 00       	mov    $0x1,%ecx
 128bbe4:	ff 50 18             	call   *0x18(%rax)
 128bbe7:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 128bbec:	74 1c                	je     128bc0a <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x93a>
 128bbee:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bbf2:	48 8b 38             	mov    (%rax),%rdi
 128bbf5:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bbf9:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bbfd:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 128bc01:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 128bc05:	31 c9                	xor    %ecx,%ecx
 128bc07:	ff 50 18             	call   *0x18(%rax)
 128bc0a:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 128bc0f:	74 27                	je     128bc38 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x968>
 128bc11:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bc15:	48 8b 38             	mov    (%rax),%rdi
 128bc18:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bc1c:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128bc20:	48 c1 e1 05          	shl    $0x5,%rcx
 128bc24:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bc28:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bc2c:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 128bc30:	b9 03 00 00 00       	mov    $0x3,%ecx
 128bc35:	ff 50 18             	call   *0x18(%rax)
 128bc38:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 128bc3d:	74 26                	je     128bc65 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x995>
 128bc3f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bc43:	48 8b 38             	mov    (%rax),%rdi
 128bc46:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bc4a:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128bc4e:	48 01 c9             	add    %rcx,%rcx
 128bc51:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bc55:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bc59:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 128bc5d:	b9 01 00 00 00       	mov    $0x1,%ecx
 128bc62:	ff 50 18             	call   *0x18(%rax)
 128bc65:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 128bc69:	66 44 89 68 10       	mov    %r13w,0x10(%rax)
 128bc6e:	e9 ce fa ff ff       	jmp    128b741 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x471>
 128bc73:	89 c3                	mov    %eax,%ebx
 128bc75:	48 83 7d 88 00       	cmpq   $0x0,-0x78(%rbp)
 128bc7a:	74 2a                	je     128bca6 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x9d6>
 128bc7c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bc80:	48 8b 38             	mov    (%rax),%rdi
 128bc83:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bc87:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 128bc8b:	48 c1 e1 05          	shl    $0x5,%rcx
 128bc8f:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bc93:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bc97:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 128bc9e:	b9 03 00 00 00       	mov    $0x3,%ecx
 128bca3:	ff 50 18             	call   *0x18(%rax)
 128bca6:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 128bcab:	74 26                	je     128bcd3 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0xa03>
 128bcad:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bcb1:	48 8b 38             	mov    (%rax),%rdi
 128bcb4:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bcb8:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128bcbc:	48 01 c9             	add    %rcx,%rcx
 128bcbf:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bcc3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bcc7:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 128bccb:	b9 01 00 00 00       	mov    $0x1,%ecx
 128bcd0:	ff 50 18             	call   *0x18(%rax)
 128bcd3:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 128bcda:	48 85 d2             	test   %rdx,%rdx
 128bcdd:	74 21                	je     128bd00 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0xa30>
 128bcdf:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 128bce6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bcea:	48 8b 38             	mov    (%rax),%rdi
 128bced:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bcf1:	48 01 d2             	add    %rdx,%rdx
 128bcf4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bcf8:	b9 01 00 00 00       	mov    $0x1,%ecx
 128bcfd:	ff 50 18             	call   *0x18(%rax)
 128bd00:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 128bd07:	48 85 d2             	test   %rdx,%rdx
 128bd0a:	74 1b                	je     128bd27 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0xa57>
 128bd0c:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128bd13:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bd17:	48 8b 38             	mov    (%rax),%rdi
 128bd1a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bd1e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bd22:	31 c9                	xor    %ecx,%ecx
 128bd24:	ff 50 18             	call   *0x18(%rax)
 128bd27:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 128bd2c:	74 27                	je     128bd55 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0xa85>
 128bd2e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bd32:	48 8b 38             	mov    (%rax),%rdi
 128bd35:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bd39:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128bd3d:	48 c1 e1 05          	shl    $0x5,%rcx
 128bd41:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bd45:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bd49:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 128bd4d:	b9 03 00 00 00       	mov    $0x3,%ecx
 128bd52:	ff 50 18             	call   *0x18(%rax)
 128bd55:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 128bd5a:	74 26                	je     128bd82 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0xab2>
 128bd5c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bd60:	48 8b 38             	mov    (%rax),%rdi
 128bd63:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bd67:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128bd6b:	48 01 c9             	add    %rcx,%rcx
 128bd6e:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bd72:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bd76:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 128bd7a:	b9 01 00 00 00       	mov    $0x1,%ecx
 128bd7f:	ff 50 18             	call   *0x18(%rax)
 128bd82:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 128bd86:	66 89 58 10          	mov    %bx,0x10(%rax)
 128bd8a:	e9 b2 f9 ff ff       	jmp    128b741 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253653+0x471>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
