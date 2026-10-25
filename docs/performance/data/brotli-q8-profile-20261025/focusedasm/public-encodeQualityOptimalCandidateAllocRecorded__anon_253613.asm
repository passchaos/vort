
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000128b170 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613>:
 128b170:	55                   	push   %rbp
 128b171:	48 89 e5             	mov    %rsp,%rbp
 128b174:	41 57                	push   %r15
 128b176:	41 56                	push   %r14
 128b178:	41 55                	push   %r13
 128b17a:	41 54                	push   %r12
 128b17c:	53                   	push   %rbx
 128b17d:	48 81 ec 78 21 00 00 	sub    $0x2178,%rsp
 128b184:	49 89 fd             	mov    %rdi,%r13
 128b187:	41 f6 40 0e 01       	testb  $0x1,0xe(%r8)
 128b18c:	0f 84 3d 04 00 00    	je     128b5cf <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x45f>
 128b192:	4d 89 cf             	mov    %r9,%r15
 128b195:	4d 89 c6             	mov    %r8,%r14
 128b198:	49 89 cc             	mov    %rcx,%r12
 128b19b:	48 89 d3             	mov    %rdx,%rbx
 128b19e:	41 8b 00             	mov    (%r8),%eax
 128b1a1:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 128b1a8:	41 0f b6 40 0f       	movzbl 0xf(%r8),%eax
 128b1ad:	88 45 c0             	mov    %al,-0x40(%rbp)
 128b1b0:	41 0f b7 50 0c       	movzwl 0xc(%r8),%edx
 128b1b5:	41 0f b7 78 0a       	movzwl 0xa(%r8),%edi
 128b1ba:	45 0f b7 40 08       	movzwl 0x8(%r8),%r8d
 128b1bf:	41 0f b6 41 4e       	movzbl 0x4e(%r9),%eax
 128b1c4:	24 1f                	and    $0x1f,%al
 128b1c6:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b1cb:	c4 e2 f9 f7 c1       	shlx   %rax,%rcx,%rax
 128b1d0:	48 83 c0 f0          	add    $0xfffffffffffffff0,%rax
 128b1d4:	4c 39 e0             	cmp    %r12,%rax
 128b1d7:	49 0f 43 c4          	cmovae %r12,%rax
 128b1db:	48 3d 00 80 00 00    	cmp    $0x8000,%rax
 128b1e1:	b9 00 80 00 00       	mov    $0x8000,%ecx
 128b1e6:	48 0f 42 c8          	cmovb  %rax,%rcx
 128b1ea:	48 89 8d 58 ff ff ff 	mov    %rcx,-0xa8(%rbp)
 128b1f1:	48 89 8d 18 fe ff ff 	mov    %rcx,-0x1e8(%rbp)
 128b1f8:	4c 89 45 80          	mov    %r8,-0x80(%rbp)
 128b1fc:	4c 89 85 20 fe ff ff 	mov    %r8,-0x1e0(%rbp)
 128b203:	48 89 7d 88          	mov    %rdi,-0x78(%rbp)
 128b207:	48 89 bd 28 fe ff ff 	mov    %rdi,-0x1d8(%rbp)
 128b20e:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 128b212:	48 89 95 30 fe ff ff 	mov    %rdx,-0x1d0(%rbp)
 128b219:	c5 fc 28 05 5f 70 d7 	vmovaps -0x288fa1(%rip),%ymm0        # 1002280 <__anon_252153+0xc0>
 128b220:	ff 
 128b221:	c5 fc 11 85 38 fe ff 	vmovups %ymm0,-0x1c8(%rbp)
 128b228:	ff 
 128b229:	c6 85 58 fe ff ff 00 	movb   $0x0,-0x1a8(%rbp)
 128b230:	48 8d bd 90 fe ff ff 	lea    -0x170(%rbp),%rdi
 128b237:	4c 8d 85 18 fe ff ff 	lea    -0x1e8(%rbp),%r8
 128b23e:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 128b242:	48 89 da             	mov    %rbx,%rdx
 128b245:	4c 89 e1             	mov    %r12,%rcx
 128b248:	c5 f8 77             	vzeroupper 
 128b24b:	e8 50 a3 fa ff       	call   12355a0 <lz77.optimalPlanAlloc>
 128b250:	0f b7 85 b8 fe ff ff 	movzwl -0x148(%rbp),%eax
 128b257:	66 85 c0             	test   %ax,%ax
 128b25a:	0f 85 45 06 00 00    	jne    128b8a5 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x735>
 128b260:	4c 8b 85 90 fe ff ff 	mov    -0x170(%rbp),%r8
 128b267:	4c 8b 8d 98 fe ff ff 	mov    -0x168(%rbp),%r9
 128b26e:	48 83 bd a8 fe ff ff 	cmpq   $0x0,-0x158(%rbp)
 128b275:	00 
 128b276:	0f 84 2d 03 00 00    	je     128b5a9 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x439>
 128b27c:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 128b283:	4c 89 6d b0          	mov    %r13,-0x50(%rbp)
 128b287:	48 8d bd 00 ff ff ff 	lea    -0x100(%rbp),%rdi
 128b28e:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 128b292:	4c 89 fe             	mov    %r15,%rsi
 128b295:	48 89 da             	mov    %rbx,%rdx
 128b298:	4c 89 e1             	mov    %r12,%rcx
 128b29b:	4c 89 45 a8          	mov    %r8,-0x58(%rbp)
 128b29f:	4c 89 4d c8          	mov    %r9,-0x38(%rbp)
 128b2a3:	e8 28 b6 f8 ff       	call   12168d0 <br.encoder.command_plan.buildAlloc>
 128b2a8:	44 0f b7 ad 18 ff ff 	movzwl -0xe8(%rbp),%r13d
 128b2af:	ff 
 128b2b0:	66 45 85 ed          	test   %r13w,%r13w
 128b2b4:	0f 85 25 07 00 00    	jne    128b9df <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x86f>
 128b2ba:	48 8b 8d 00 ff ff ff 	mov    -0x100(%rbp),%rcx
 128b2c1:	4c 8b 8d 08 ff ff ff 	mov    -0xf8(%rbp),%r9
 128b2c8:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128b2cc:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 128b2d3:	ff 
 128b2d4:	c5 fc 11 85 60 fd ff 	vmovups %ymm0,-0x2a0(%rbp)
 128b2db:	ff 
 128b2dc:	c5 fc 11 85 80 fd ff 	vmovups %ymm0,-0x280(%rbp)
 128b2e3:	ff 
 128b2e4:	c5 fc 11 85 a0 fd ff 	vmovups %ymm0,-0x260(%rbp)
 128b2eb:	ff 
 128b2ec:	c5 fc 11 85 b0 fd ff 	vmovups %ymm0,-0x250(%rbp)
 128b2f3:	ff 
 128b2f4:	48 8d 85 40 fd ff ff 	lea    -0x2c0(%rbp),%rax
 128b2fb:	48 8d bd 38 ff ff ff 	lea    -0xc8(%rbp),%rdi
 128b302:	4c 89 fe             	mov    %r15,%rsi
 128b305:	49 89 cf             	mov    %rcx,%r15
 128b308:	48 89 da             	mov    %rbx,%rdx
 128b30b:	4c 89 e1             	mov    %r12,%rcx
 128b30e:	4d 89 f8             	mov    %r15,%r8
 128b311:	4c 89 4d b8          	mov    %r9,-0x48(%rbp)
 128b315:	ff b5 60 ff ff ff    	push   -0xa0(%rbp)
 128b31b:	50                   	push   %rax
 128b31c:	c5 f8 77             	vzeroupper 
 128b31f:	e8 ac f0 f5 ff       	call   11ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>
 128b324:	48 83 c4 10          	add    $0x10,%rsp
 128b328:	44 0f b7 ad 48 ff ff 	movzwl -0xb8(%rbp),%r13d
 128b32f:	ff 
 128b330:	66 45 85 ed          	test   %r13w,%r13w
 128b334:	0f 85 75 05 00 00    	jne    128b8af <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x73f>
 128b33a:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 128b341:	4c 8b ad 40 ff ff ff 	mov    -0xc0(%rbp),%r13
 128b348:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 128b34c:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 128b353:	4c 89 ad 78 ff ff ff 	mov    %r13,-0x88(%rbp)
 128b35a:	f6 45 c0 01          	testb  $0x1,-0x40(%rbp)
 128b35e:	0f 84 8f 02 00 00    	je     128b5f3 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x483>
 128b364:	4c 89 6d c0          	mov    %r13,-0x40(%rbp)
 128b368:	48 8d 05 71 6d d7 ff 	lea    -0x28928f(%rip),%rax        # 10020e0 <__anon_35167>
 128b36f:	48 8d bd 78 e8 ff ff 	lea    -0x1788(%rbp),%rdi
 128b376:	4c 8b 6d d0          	mov    -0x30(%rbp),%r13
 128b37a:	4c 89 ee             	mov    %r13,%rsi
 128b37d:	48 89 da             	mov    %rbx,%rdx
 128b380:	4c 89 e1             	mov    %r12,%rcx
 128b383:	4c 89 7d 90          	mov    %r15,-0x70(%rbp)
 128b387:	4d 89 f8             	mov    %r15,%r8
 128b38a:	4c 8b 4d b8          	mov    -0x48(%rbp),%r9
 128b38e:	50                   	push   %rax
 128b38f:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 128b396:	41 57                	push   %r15
 128b398:	e8 a3 23 fb ff       	call   123d740 <br.encoder.entropy_feedback.buildWithStartingDistances>
 128b39d:	48 83 c4 10          	add    $0x10,%rsp
 128b3a1:	48 8d bd 60 de ff ff 	lea    -0x21a0(%rbp),%rdi
 128b3a8:	ba 18 0a 00 00       	mov    $0xa18,%edx
 128b3ad:	48 8d b5 78 e8 ff ff 	lea    -0x1788(%rbp),%rsi
 128b3b4:	e8 07 ad 00 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 128b3b9:	0f b7 85 90 f2 ff ff 	movzwl -0xd70(%rbp),%eax
 128b3c0:	66 85 c0             	test   %ax,%ax
 128b3c3:	0f 85 2a 05 00 00    	jne    128b8f3 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x783>
 128b3c9:	48 8d bd 98 f2 ff ff 	lea    -0xd68(%rbp),%rdi
 128b3d0:	48 8d b5 60 de ff ff 	lea    -0x21a0(%rbp),%rsi
 128b3d7:	ba 18 0a 00 00       	mov    $0xa18,%edx
 128b3dc:	e8 df ac 00 00       	call   12960c0 <compiler_rt.memcpy.memcpyFast>
 128b3e1:	4c 89 bd d0 fd ff ff 	mov    %r15,-0x230(%rbp)
 128b3e8:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 128b3ec:	48 89 85 d8 fd ff ff 	mov    %rax,-0x228(%rbp)
 128b3f3:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 128b3f7:	48 89 85 e0 fd ff ff 	mov    %rax,-0x220(%rbp)
 128b3fe:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 128b402:	48 89 85 e8 fd ff ff 	mov    %rax,-0x218(%rbp)
 128b409:	c5 fc 28 05 6f 6e d7 	vmovaps -0x289191(%rip),%ymm0        # 1002280 <__anon_252153+0xc0>
 128b410:	ff 
 128b411:	c5 fc 11 85 f0 fd ff 	vmovups %ymm0,-0x210(%rbp)
 128b418:	ff 
 128b419:	c6 85 10 fe ff ff 00 	movb   $0x0,-0x1f0(%rbp)
 128b420:	48 8d 85 a8 f2 ff ff 	lea    -0xd58(%rbp),%rax
 128b427:	48 89 85 e0 fe ff ff 	mov    %rax,-0x120(%rbp)
 128b42e:	48 8d 85 a8 f4 ff ff 	lea    -0xb58(%rbp),%rax
 128b435:	48 89 85 e8 fe ff ff 	mov    %rax,-0x118(%rbp)
 128b43c:	c5 f8 10 85 98 f2 ff 	vmovups -0xd68(%rbp),%xmm0
 128b443:	ff 
 128b444:	c5 f8 11 85 f0 fe ff 	vmovups %xmm0,-0x110(%rbp)
 128b44b:	ff 
 128b44c:	48 8d bd 60 fe ff ff 	lea    -0x1a0(%rbp),%rdi
 128b453:	4c 8d 85 d0 fd ff ff 	lea    -0x230(%rbp),%r8
 128b45a:	4c 8d 8d e0 fe ff ff 	lea    -0x120(%rbp),%r9
 128b461:	4c 89 ee             	mov    %r13,%rsi
 128b464:	48 89 da             	mov    %rbx,%rdx
 128b467:	4c 89 e1             	mov    %r12,%rcx
 128b46a:	c5 f8 77             	vzeroupper 
 128b46d:	e8 8e eb fa ff       	call   123a000 <lz77.optimalPlanAllocWithCostModel>
 128b472:	44 0f b7 ad 88 fe ff 	movzwl -0x178(%rbp),%r13d
 128b479:	ff 
 128b47a:	66 45 85 ed          	test   %r13w,%r13w
 128b47e:	0f 85 de 04 00 00    	jne    128b962 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x7f2>
 128b484:	4c 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%r8
 128b48b:	4c 8b 8d 68 fe ff ff 	mov    -0x198(%rbp),%r9
 128b492:	48 83 bd 78 fe ff ff 	cmpq   $0x0,-0x188(%rbp)
 128b499:	00 
 128b49a:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 128b49e:	0f 84 b8 01 00 00    	je     128b65c <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x4ec>
 128b4a4:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 128b4ab:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 128b4af:	4c 89 fe             	mov    %r15,%rsi
 128b4b2:	48 89 da             	mov    %rbx,%rdx
 128b4b5:	4c 89 e1             	mov    %r12,%rcx
 128b4b8:	4c 89 45 80          	mov    %r8,-0x80(%rbp)
 128b4bc:	4c 89 4d 98          	mov    %r9,-0x68(%rbp)
 128b4c0:	e8 0b b4 f8 ff       	call   12168d0 <br.encoder.command_plan.buildAlloc>
 128b4c5:	44 0f b7 ad d8 fe ff 	movzwl -0x128(%rbp),%r13d
 128b4cc:	ff 
 128b4cd:	66 45 85 ed          	test   %r13w,%r13w
 128b4d1:	0f 85 56 05 00 00    	jne    128ba2d <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x8bd>
 128b4d7:	4c 8b 85 c0 fe ff ff 	mov    -0x140(%rbp),%r8
 128b4de:	4c 8b 8d c8 fe ff ff 	mov    -0x138(%rbp),%r9
 128b4e5:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128b4e9:	c5 fc 11 85 b0 fc ff 	vmovups %ymm0,-0x350(%rbp)
 128b4f0:	ff 
 128b4f1:	c5 fc 11 85 d0 fc ff 	vmovups %ymm0,-0x330(%rbp)
 128b4f8:	ff 
 128b4f9:	c5 fc 11 85 f0 fc ff 	vmovups %ymm0,-0x310(%rbp)
 128b500:	ff 
 128b501:	c5 fc 11 85 10 fd ff 	vmovups %ymm0,-0x2f0(%rbp)
 128b508:	ff 
 128b509:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 128b510:	ff 
 128b511:	48 8d 85 b0 fc ff ff 	lea    -0x350(%rbp),%rax
 128b518:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 128b51f:	4c 89 fe             	mov    %r15,%rsi
 128b522:	48 89 da             	mov    %rbx,%rdx
 128b525:	4c 89 e1             	mov    %r12,%rcx
 128b528:	4c 89 85 68 ff ff ff 	mov    %r8,-0x98(%rbp)
 128b52f:	4c 89 4d 88          	mov    %r9,-0x78(%rbp)
 128b533:	ff b5 60 ff ff ff    	push   -0xa0(%rbp)
 128b539:	50                   	push   %rax
 128b53a:	c5 f8 77             	vzeroupper 
 128b53d:	e8 8e ee f5 ff       	call   11ea3d0 <br.encodeLazyCommandPlanAllocRecorded__anon_43465>
 128b542:	48 83 c4 10          	add    $0x10,%rsp
 128b546:	44 0f b7 ad 30 ff ff 	movzwl -0xd0(%rbp),%r13d
 128b54d:	ff 
 128b54e:	66 45 85 ed          	test   %r13w,%r13w
 128b552:	0f 85 a4 04 00 00    	jne    128b9fc <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x88c>
 128b558:	4c 8b bd 20 ff ff ff 	mov    -0xe0(%rbp),%r15
 128b55f:	4c 8b ad 28 ff ff ff 	mov    -0xd8(%rbp),%r13
 128b566:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 128b56a:	49 39 d5             	cmp    %rdx,%r13
 128b56d:	0f 83 a4 01 00 00    	jae    128b717 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x5a7>
 128b573:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b577:	48 8b 38             	mov    (%rax),%rdi
 128b57a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b57e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b582:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 128b586:	31 c9                	xor    %ecx,%ecx
 128b588:	ff 50 18             	call   *0x18(%rax)
 128b58b:	4c 89 7d c0          	mov    %r15,-0x40(%rbp)
 128b58f:	4c 89 bd 70 ff ff ff 	mov    %r15,-0x90(%rbp)
 128b596:	4d 89 ef             	mov    %r13,%r15
 128b599:	4c 89 ad 78 ff ff ff 	mov    %r13,-0x88(%rbp)
 128b5a0:	4c 8b 6d b0          	mov    -0x50(%rbp),%r13
 128b5a4:	e9 9d 01 00 00       	jmp    128b746 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x5d6>
 128b5a9:	4d 85 c9             	test   %r9,%r9
 128b5ac:	74 21                	je     128b5cf <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x45f>
 128b5ae:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b5b2:	48 8b 38             	mov    (%rax),%rdi
 128b5b5:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b5b9:	4d 01 c9             	add    %r9,%r9
 128b5bc:	4b 8d 14 49          	lea    (%r9,%r9,2),%rdx
 128b5c0:	4c 89 c6             	mov    %r8,%rsi
 128b5c3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b5c7:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b5cc:	ff 50 18             	call   *0x18(%rax)
 128b5cf:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 128b5d3:	c4 c1 78 11 45 00    	vmovups %xmm0,0x0(%r13)
 128b5d9:	49 c7 45 10 00 00 00 	movq   $0x0,0x10(%r13)
 128b5e0:	00 
 128b5e1:	48 81 c4 78 21 00 00 	add    $0x2178,%rsp
 128b5e8:	5b                   	pop    %rbx
 128b5e9:	41 5c                	pop    %r12
 128b5eb:	41 5d                	pop    %r13
 128b5ed:	41 5e                	pop    %r14
 128b5ef:	41 5f                	pop    %r15
 128b5f1:	5d                   	pop    %rbp
 128b5f2:	c3                   	ret    
 128b5f3:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128b5f7:	48 85 c9             	test   %rcx,%rcx
 128b5fa:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 128b5fe:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 128b602:	74 1e                	je     128b622 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x4b2>
 128b604:	49 8b 3e             	mov    (%r14),%rdi
 128b607:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b60b:	48 c1 e1 05          	shl    $0x5,%rcx
 128b60f:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b613:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b617:	4c 89 fe             	mov    %r15,%rsi
 128b61a:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b61f:	ff 50 18             	call   *0x18(%rax)
 128b622:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b626:	48 85 c9             	test   %rcx,%rcx
 128b629:	74 1e                	je     128b649 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x4d9>
 128b62b:	49 8b 3e             	mov    (%r14),%rdi
 128b62e:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b632:	48 01 c9             	add    %rcx,%rcx
 128b635:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b639:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b63d:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 128b641:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b646:	ff 50 18             	call   *0x18(%rax)
 128b649:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 128b64f:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128b653:	48 89 03             	mov    %rax,(%rbx)
 128b656:	4c 89 6b 08          	mov    %r13,0x8(%rbx)
 128b65a:	eb 85                	jmp    128b5e1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x471>
 128b65c:	4d 85 c9             	test   %r9,%r9
 128b65f:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 128b663:	74 1d                	je     128b682 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x512>
 128b665:	49 8b 3e             	mov    (%r14),%rdi
 128b668:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b66c:	4d 01 c9             	add    %r9,%r9
 128b66f:	4b 8d 14 49          	lea    (%r9,%r9,2),%rdx
 128b673:	4c 89 c6             	mov    %r8,%rsi
 128b676:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b67a:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b67f:	ff 50 18             	call   *0x18(%rax)
 128b682:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 128b689:	48 85 d2             	test   %rdx,%rdx
 128b68c:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 128b690:	4c 8b 65 c0          	mov    -0x40(%rbp),%r12
 128b694:	74 1d                	je     128b6b3 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x543>
 128b696:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 128b69d:	49 8b 3e             	mov    (%r14),%rdi
 128b6a0:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b6a4:	48 01 d2             	add    %rdx,%rdx
 128b6a7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b6ab:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b6b0:	ff 50 18             	call   *0x18(%rax)
 128b6b3:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128b6b7:	48 85 c9             	test   %rcx,%rcx
 128b6ba:	74 1e                	je     128b6da <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x56a>
 128b6bc:	49 8b 3e             	mov    (%r14),%rdi
 128b6bf:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b6c3:	48 c1 e1 05          	shl    $0x5,%rcx
 128b6c7:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b6cb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b6cf:	4c 89 fe             	mov    %r15,%rsi
 128b6d2:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b6d7:	ff 50 18             	call   *0x18(%rax)
 128b6da:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b6de:	48 85 c9             	test   %rcx,%rcx
 128b6e1:	74 1e                	je     128b701 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x591>
 128b6e3:	49 8b 3e             	mov    (%r14),%rdi
 128b6e6:	49 8b 46 08          	mov    0x8(%r14),%rax
 128b6ea:	48 01 c9             	add    %rcx,%rcx
 128b6ed:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b6f1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b6f5:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 128b6f9:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b6fe:	ff 50 18             	call   *0x18(%rax)
 128b701:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 128b707:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128b70b:	48 89 03             	mov    %rax,(%rbx)
 128b70e:	4c 89 63 08          	mov    %r12,0x8(%rbx)
 128b712:	e9 ca fe ff ff       	jmp    128b5e1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x471>
 128b717:	4d 85 ed             	test   %r13,%r13
 128b71a:	4c 89 ea             	mov    %r13,%rdx
 128b71d:	4c 8b 6d b0          	mov    -0x50(%rbp),%r13
 128b721:	74 17                	je     128b73a <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x5ca>
 128b723:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b727:	48 8b 38             	mov    (%rax),%rdi
 128b72a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b72e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b732:	4c 89 fe             	mov    %r15,%rsi
 128b735:	31 c9                	xor    %ecx,%ecx
 128b737:	ff 50 18             	call   *0x18(%rax)
 128b73a:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 128b73e:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 128b742:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 128b746:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 128b74d:	85 c9                	test   %ecx,%ecx
 128b74f:	0f 95 c0             	setne  %al
 128b752:	49 39 cc             	cmp    %rcx,%r12
 128b755:	0f 96 c1             	setbe  %cl
 128b758:	84 c8                	test   %cl,%al
 128b75a:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b75e:	4c 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%r8
 128b765:	74 4c                	je     128b7b3 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x643>
 128b767:	48 8d 85 70 ff ff ff 	lea    -0x90(%rbp),%rax
 128b76e:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 128b772:	48 89 de             	mov    %rbx,%rsi
 128b775:	4c 89 e2             	mov    %r12,%rdx
 128b778:	4c 89 f1             	mov    %r14,%rcx
 128b77b:	4c 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%r9
 128b782:	50                   	push   %rax
 128b783:	48 8d 85 98 f2 ff ff 	lea    -0xd68(%rbp),%rax
 128b78a:	50                   	push   %rax
 128b78b:	e8 3c 2e 02 00       	call   12ae5cc <br.selectQualityCommandStateCandidate>
 128b790:	48 83 c4 10          	add    $0x10,%rsp
 128b794:	66 85 c0             	test   %ax,%ax
 128b797:	0f 85 76 03 00 00    	jne    128bb13 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x9a3>
 128b79d:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 128b7a4:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 128b7a8:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 128b7af:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b7b3:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 128b7b7:	48 85 d2             	test   %rdx,%rdx
 128b7ba:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 128b7be:	74 26                	je     128b7e6 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x676>
 128b7c0:	48 8b 3b             	mov    (%rbx),%rdi
 128b7c3:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b7c7:	48 c1 e2 05          	shl    $0x5,%rdx
 128b7cb:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 128b7cf:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b7d3:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 128b7da:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b7df:	ff 50 18             	call   *0x18(%rax)
 128b7e2:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b7e6:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 128b7ea:	48 85 d2             	test   %rdx,%rdx
 128b7ed:	74 22                	je     128b811 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x6a1>
 128b7ef:	48 8b 3b             	mov    (%rbx),%rdi
 128b7f2:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b7f6:	48 01 d2             	add    %rdx,%rdx
 128b7f9:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 128b7fd:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b801:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 128b805:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b80a:	ff 50 18             	call   *0x18(%rax)
 128b80d:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b811:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 128b818:	48 85 d2             	test   %rdx,%rdx
 128b81b:	74 21                	je     128b83e <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x6ce>
 128b81d:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 128b824:	48 8b 3b             	mov    (%rbx),%rdi
 128b827:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b82b:	48 01 d2             	add    %rdx,%rdx
 128b82e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b832:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b837:	ff 50 18             	call   *0x18(%rax)
 128b83a:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b83e:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 128b842:	48 85 d2             	test   %rdx,%rdx
 128b845:	74 23                	je     128b86a <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x6fa>
 128b847:	48 8b 3b             	mov    (%rbx),%rdi
 128b84a:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b84e:	48 c1 e2 05          	shl    $0x5,%rdx
 128b852:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 128b856:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b85a:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 128b85e:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b863:	ff 50 18             	call   *0x18(%rax)
 128b866:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b86a:	48 85 c9             	test   %rcx,%rcx
 128b86d:	74 1e                	je     128b88d <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x71d>
 128b86f:	48 8b 3b             	mov    (%rbx),%rdi
 128b872:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b876:	48 01 c9             	add    %rcx,%rcx
 128b879:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b87d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b881:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 128b885:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b88a:	ff 50 18             	call   *0x18(%rax)
 128b88d:	66 41 c7 45 10 00 00 	movw   $0x0,0x10(%r13)
 128b894:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 128b898:	49 89 45 00          	mov    %rax,0x0(%r13)
 128b89c:	4d 89 7d 08          	mov    %r15,0x8(%r13)
 128b8a0:	e9 3c fd ff ff       	jmp    128b5e1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x471>
 128b8a5:	66 41 89 45 10       	mov    %ax,0x10(%r13)
 128b8aa:	e9 32 fd ff ff       	jmp    128b5e1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x471>
 128b8af:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128b8b3:	48 85 c9             	test   %rcx,%rcx
 128b8b6:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 128b8ba:	74 1e                	je     128b8da <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x76a>
 128b8bc:	48 8b 3b             	mov    (%rbx),%rdi
 128b8bf:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b8c3:	48 c1 e1 05          	shl    $0x5,%rcx
 128b8c7:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b8cb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b8cf:	4c 89 fe             	mov    %r15,%rsi
 128b8d2:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b8d7:	ff 50 18             	call   *0x18(%rax)
 128b8da:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b8de:	48 85 c9             	test   %rcx,%rcx
 128b8e1:	0f 84 1e 02 00 00    	je     128bb05 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x995>
 128b8e7:	48 8b 3b             	mov    (%rbx),%rdi
 128b8ea:	48 8b 43 08          	mov    0x8(%rbx),%rax
 128b8ee:	e9 fb 01 00 00       	jmp    128baee <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x97e>
 128b8f3:	89 c3                	mov    %eax,%ebx
 128b8f5:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 128b8f9:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 128b8fd:	48 85 d2             	test   %rdx,%rdx
 128b900:	74 18                	je     128b91a <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x7aa>
 128b902:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b906:	48 8b 38             	mov    (%rax),%rdi
 128b909:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b90d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b911:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 128b915:	31 c9                	xor    %ecx,%ecx
 128b917:	ff 50 18             	call   *0x18(%rax)
 128b91a:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128b91e:	48 85 c9             	test   %rcx,%rcx
 128b921:	74 22                	je     128b945 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x7d5>
 128b923:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b927:	48 8b 38             	mov    (%rax),%rdi
 128b92a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b92e:	48 c1 e1 05          	shl    $0x5,%rcx
 128b932:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b936:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b93a:	4c 89 fe             	mov    %r15,%rsi
 128b93d:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b942:	ff 50 18             	call   *0x18(%rax)
 128b945:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b949:	48 85 c9             	test   %rcx,%rcx
 128b94c:	0f 84 d0 02 00 00    	je     128bc22 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0xab2>
 128b952:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b956:	48 8b 38             	mov    (%rax),%rdi
 128b959:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b95d:	e9 a9 02 00 00       	jmp    128bc0b <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0xa9b>
 128b962:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 128b966:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 128b96d:	48 85 d2             	test   %rdx,%rdx
 128b970:	74 21                	je     128b993 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x823>
 128b972:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 128b979:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b97d:	48 8b 38             	mov    (%rax),%rdi
 128b980:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b984:	48 01 d2             	add    %rdx,%rdx
 128b987:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b98b:	b9 01 00 00 00       	mov    $0x1,%ecx
 128b990:	ff 50 18             	call   *0x18(%rax)
 128b993:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 128b997:	48 85 d2             	test   %rdx,%rdx
 128b99a:	74 18                	je     128b9b4 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x844>
 128b99c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b9a0:	48 8b 38             	mov    (%rax),%rdi
 128b9a3:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b9a7:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b9ab:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 128b9af:	31 c9                	xor    %ecx,%ecx
 128b9b1:	ff 50 18             	call   *0x18(%rax)
 128b9b4:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128b9b8:	48 85 c9             	test   %rcx,%rcx
 128b9bb:	74 22                	je     128b9df <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x86f>
 128b9bd:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b9c1:	48 8b 38             	mov    (%rax),%rdi
 128b9c4:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b9c8:	48 c1 e1 05          	shl    $0x5,%rcx
 128b9cc:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128b9d0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128b9d4:	4c 89 fe             	mov    %r15,%rsi
 128b9d7:	b9 03 00 00 00       	mov    $0x3,%ecx
 128b9dc:	ff 50 18             	call   *0x18(%rax)
 128b9df:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128b9e3:	48 85 c9             	test   %rcx,%rcx
 128b9e6:	0f 84 19 01 00 00    	je     128bb05 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x995>
 128b9ec:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128b9f0:	48 8b 38             	mov    (%rax),%rdi
 128b9f3:	48 8b 40 08          	mov    0x8(%rax),%rax
 128b9f7:	e9 f2 00 00 00       	jmp    128baee <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x97e>
 128b9fc:	48 83 7d 88 00       	cmpq   $0x0,-0x78(%rbp)
 128ba01:	74 2a                	je     128ba2d <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x8bd>
 128ba03:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ba07:	48 8b 38             	mov    (%rax),%rdi
 128ba0a:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ba0e:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 128ba12:	48 c1 e1 05          	shl    $0x5,%rcx
 128ba16:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ba1a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ba1e:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 128ba25:	b9 03 00 00 00       	mov    $0x3,%ecx
 128ba2a:	ff 50 18             	call   *0x18(%rax)
 128ba2d:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 128ba32:	74 26                	je     128ba5a <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x8ea>
 128ba34:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ba38:	48 8b 38             	mov    (%rax),%rdi
 128ba3b:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ba3f:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128ba43:	48 01 c9             	add    %rcx,%rcx
 128ba46:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128ba4a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ba4e:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 128ba52:	b9 01 00 00 00       	mov    $0x1,%ecx
 128ba57:	ff 50 18             	call   *0x18(%rax)
 128ba5a:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 128ba61:	48 85 d2             	test   %rdx,%rdx
 128ba64:	74 21                	je     128ba87 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x917>
 128ba66:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 128ba6d:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ba71:	48 8b 38             	mov    (%rax),%rdi
 128ba74:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ba78:	48 01 d2             	add    %rdx,%rdx
 128ba7b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ba7f:	b9 01 00 00 00       	mov    $0x1,%ecx
 128ba84:	ff 50 18             	call   *0x18(%rax)
 128ba87:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 128ba8c:	74 1c                	je     128baaa <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x93a>
 128ba8e:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128ba92:	48 8b 38             	mov    (%rax),%rdi
 128ba95:	48 8b 40 08          	mov    0x8(%rax),%rax
 128ba99:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128ba9d:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 128baa1:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 128baa5:	31 c9                	xor    %ecx,%ecx
 128baa7:	ff 50 18             	call   *0x18(%rax)
 128baaa:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 128baaf:	74 27                	je     128bad8 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x968>
 128bab1:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bab5:	48 8b 38             	mov    (%rax),%rdi
 128bab8:	48 8b 40 08          	mov    0x8(%rax),%rax
 128babc:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128bac0:	48 c1 e1 05          	shl    $0x5,%rcx
 128bac4:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bac8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bacc:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 128bad0:	b9 03 00 00 00       	mov    $0x3,%ecx
 128bad5:	ff 50 18             	call   *0x18(%rax)
 128bad8:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 128badd:	74 26                	je     128bb05 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x995>
 128badf:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bae3:	48 8b 38             	mov    (%rax),%rdi
 128bae6:	48 8b 40 08          	mov    0x8(%rax),%rax
 128baea:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128baee:	48 01 c9             	add    %rcx,%rcx
 128baf1:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128baf5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128baf9:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 128bafd:	b9 01 00 00 00       	mov    $0x1,%ecx
 128bb02:	ff 50 18             	call   *0x18(%rax)
 128bb05:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 128bb09:	66 44 89 68 10       	mov    %r13w,0x10(%rax)
 128bb0e:	e9 ce fa ff ff       	jmp    128b5e1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x471>
 128bb13:	89 c3                	mov    %eax,%ebx
 128bb15:	48 83 7d 88 00       	cmpq   $0x0,-0x78(%rbp)
 128bb1a:	74 2a                	je     128bb46 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x9d6>
 128bb1c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bb20:	48 8b 38             	mov    (%rax),%rdi
 128bb23:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bb27:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 128bb2b:	48 c1 e1 05          	shl    $0x5,%rcx
 128bb2f:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bb33:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bb37:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 128bb3e:	b9 03 00 00 00       	mov    $0x3,%ecx
 128bb43:	ff 50 18             	call   *0x18(%rax)
 128bb46:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 128bb4b:	74 26                	je     128bb73 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0xa03>
 128bb4d:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bb51:	48 8b 38             	mov    (%rax),%rdi
 128bb54:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bb58:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 128bb5c:	48 01 c9             	add    %rcx,%rcx
 128bb5f:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bb63:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bb67:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 128bb6b:	b9 01 00 00 00       	mov    $0x1,%ecx
 128bb70:	ff 50 18             	call   *0x18(%rax)
 128bb73:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 128bb7a:	48 85 d2             	test   %rdx,%rdx
 128bb7d:	74 21                	je     128bba0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0xa30>
 128bb7f:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 128bb86:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bb8a:	48 8b 38             	mov    (%rax),%rdi
 128bb8d:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bb91:	48 01 d2             	add    %rdx,%rdx
 128bb94:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bb98:	b9 01 00 00 00       	mov    $0x1,%ecx
 128bb9d:	ff 50 18             	call   *0x18(%rax)
 128bba0:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 128bba7:	48 85 d2             	test   %rdx,%rdx
 128bbaa:	74 1b                	je     128bbc7 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0xa57>
 128bbac:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 128bbb3:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bbb7:	48 8b 38             	mov    (%rax),%rdi
 128bbba:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bbbe:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bbc2:	31 c9                	xor    %ecx,%ecx
 128bbc4:	ff 50 18             	call   *0x18(%rax)
 128bbc7:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 128bbcc:	74 27                	je     128bbf5 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0xa85>
 128bbce:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bbd2:	48 8b 38             	mov    (%rax),%rdi
 128bbd5:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bbd9:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 128bbdd:	48 c1 e1 05          	shl    $0x5,%rcx
 128bbe1:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bbe5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bbe9:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 128bbed:	b9 03 00 00 00       	mov    $0x3,%ecx
 128bbf2:	ff 50 18             	call   *0x18(%rax)
 128bbf5:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 128bbfa:	74 26                	je     128bc22 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0xab2>
 128bbfc:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 128bc00:	48 8b 38             	mov    (%rax),%rdi
 128bc03:	48 8b 40 08          	mov    0x8(%rax),%rax
 128bc07:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 128bc0b:	48 01 c9             	add    %rcx,%rcx
 128bc0e:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 128bc12:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 128bc16:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 128bc1a:	b9 01 00 00 00       	mov    $0x1,%ecx
 128bc1f:	ff 50 18             	call   *0x18(%rax)
 128bc22:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 128bc26:	66 89 58 10          	mov    %bx,0x10(%rax)
 128bc2a:	e9 b2 f9 ff ff       	jmp    128b5e1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_253613+0x471>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
