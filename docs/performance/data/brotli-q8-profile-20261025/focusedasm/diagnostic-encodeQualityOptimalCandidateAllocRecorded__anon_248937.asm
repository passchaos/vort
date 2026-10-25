
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000129d5a0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937>:
 129d5a0:	55                   	push   %rbp
 129d5a1:	48 89 e5             	mov    %rsp,%rbp
 129d5a4:	41 57                	push   %r15
 129d5a6:	41 56                	push   %r14
 129d5a8:	41 55                	push   %r13
 129d5aa:	41 54                	push   %r12
 129d5ac:	53                   	push   %rbx
 129d5ad:	48 81 ec 78 21 00 00 	sub    $0x2178,%rsp
 129d5b4:	49 89 fd             	mov    %rdi,%r13
 129d5b7:	41 f6 40 0e 01       	testb  $0x1,0xe(%r8)
 129d5bc:	0f 84 3a 04 00 00    	je     129d9fc <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x45c>
 129d5c2:	4d 89 cf             	mov    %r9,%r15
 129d5c5:	4d 89 c6             	mov    %r8,%r14
 129d5c8:	49 89 cc             	mov    %rcx,%r12
 129d5cb:	48 89 d3             	mov    %rdx,%rbx
 129d5ce:	41 8b 00             	mov    (%r8),%eax
 129d5d1:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 129d5d8:	41 0f b6 40 0f       	movzbl 0xf(%r8),%eax
 129d5dd:	88 45 c0             	mov    %al,-0x40(%rbp)
 129d5e0:	41 0f b7 50 0c       	movzwl 0xc(%r8),%edx
 129d5e5:	41 0f b7 78 0a       	movzwl 0xa(%r8),%edi
 129d5ea:	45 0f b7 40 08       	movzwl 0x8(%r8),%r8d
 129d5ef:	41 0f b6 41 4e       	movzbl 0x4e(%r9),%eax
 129d5f4:	24 1f                	and    $0x1f,%al
 129d5f6:	b9 01 00 00 00       	mov    $0x1,%ecx
 129d5fb:	c4 e2 f9 f7 c1       	shlx   %rax,%rcx,%rax
 129d600:	48 83 c0 f0          	add    $0xfffffffffffffff0,%rax
 129d604:	4c 39 e0             	cmp    %r12,%rax
 129d607:	49 0f 43 c4          	cmovae %r12,%rax
 129d60b:	48 3d 00 80 00 00    	cmp    $0x8000,%rax
 129d611:	b9 00 80 00 00       	mov    $0x8000,%ecx
 129d616:	48 0f 42 c8          	cmovb  %rax,%rcx
 129d61a:	48 89 8d 58 ff ff ff 	mov    %rcx,-0xa8(%rbp)
 129d621:	48 89 8d 18 fe ff ff 	mov    %rcx,-0x1e8(%rbp)
 129d628:	4c 89 45 80          	mov    %r8,-0x80(%rbp)
 129d62c:	4c 89 85 20 fe ff ff 	mov    %r8,-0x1e0(%rbp)
 129d633:	48 89 7d 88          	mov    %rdi,-0x78(%rbp)
 129d637:	48 89 bd 28 fe ff ff 	mov    %rdi,-0x1d8(%rbp)
 129d63e:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 129d642:	48 89 95 30 fe ff ff 	mov    %rdx,-0x1d0(%rbp)
 129d649:	c5 fc 28 05 8f 2e d6 	vmovaps -0x29d171(%rip),%ymm0        # 10004e0 <__anon_248258+0xa0>
 129d650:	ff 
 129d651:	c5 fc 11 85 38 fe ff 	vmovups %ymm0,-0x1c8(%rbp)
 129d658:	ff 
 129d659:	c6 85 58 fe ff ff 00 	movb   $0x0,-0x1a8(%rbp)
 129d660:	48 8d bd 90 fe ff ff 	lea    -0x170(%rbp),%rdi
 129d667:	4c 8d 85 18 fe ff ff 	lea    -0x1e8(%rbp),%r8
 129d66e:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 129d672:	48 89 da             	mov    %rbx,%rdx
 129d675:	4c 89 e1             	mov    %r12,%rcx
 129d678:	c5 f8 77             	vzeroupper 
 129d67b:	e8 70 b5 f9 ff       	call   1238bf0 <lz77.optimalPlanAlloc>
 129d680:	0f b7 85 b8 fe ff ff 	movzwl -0x148(%rbp),%eax
 129d687:	66 85 c0             	test   %ax,%ax
 129d68a:	0f 85 42 06 00 00    	jne    129dcd2 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x732>
 129d690:	4c 8b 85 90 fe ff ff 	mov    -0x170(%rbp),%r8
 129d697:	4c 8b 8d 98 fe ff ff 	mov    -0x168(%rbp),%r9
 129d69e:	48 83 bd a8 fe ff ff 	cmpq   $0x0,-0x158(%rbp)
 129d6a5:	00 
 129d6a6:	0f 84 2a 03 00 00    	je     129d9d6 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x436>
 129d6ac:	4c 89 bd 60 ff ff ff 	mov    %r15,-0xa0(%rbp)
 129d6b3:	4c 89 6d b0          	mov    %r13,-0x50(%rbp)
 129d6b7:	48 8d bd 00 ff ff ff 	lea    -0x100(%rbp),%rdi
 129d6be:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 129d6c2:	4c 89 fe             	mov    %r15,%rsi
 129d6c5:	48 89 da             	mov    %rbx,%rdx
 129d6c8:	4c 89 e1             	mov    %r12,%rcx
 129d6cb:	4c 89 45 a8          	mov    %r8,-0x58(%rbp)
 129d6cf:	4c 89 4d c8          	mov    %r9,-0x38(%rbp)
 129d6d3:	e8 58 23 f1 ff       	call   11afa30 <br.encoder.command_plan.buildAlloc>
 129d6d8:	44 0f b7 ad 18 ff ff 	movzwl -0xe8(%rbp),%r13d
 129d6df:	ff 
 129d6e0:	66 45 85 ed          	test   %r13w,%r13w
 129d6e4:	0f 85 22 07 00 00    	jne    129de0c <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x86c>
 129d6ea:	48 8b 8d 00 ff ff ff 	mov    -0x100(%rbp),%rcx
 129d6f1:	4c 8b 8d 08 ff ff ff 	mov    -0xf8(%rbp),%r9
 129d6f8:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129d6fc:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 129d703:	ff 
 129d704:	c5 fc 11 85 60 fd ff 	vmovups %ymm0,-0x2a0(%rbp)
 129d70b:	ff 
 129d70c:	c5 fc 11 85 80 fd ff 	vmovups %ymm0,-0x280(%rbp)
 129d713:	ff 
 129d714:	c5 fc 11 85 a0 fd ff 	vmovups %ymm0,-0x260(%rbp)
 129d71b:	ff 
 129d71c:	c5 fc 11 85 b0 fd ff 	vmovups %ymm0,-0x250(%rbp)
 129d723:	ff 
 129d724:	48 8d 85 40 fd ff ff 	lea    -0x2c0(%rbp),%rax
 129d72b:	48 8d bd 38 ff ff ff 	lea    -0xc8(%rbp),%rdi
 129d732:	4c 89 fe             	mov    %r15,%rsi
 129d735:	49 89 cf             	mov    %rcx,%r15
 129d738:	48 89 da             	mov    %rbx,%rdx
 129d73b:	4c 89 e1             	mov    %r12,%rcx
 129d73e:	4d 89 f8             	mov    %r15,%r8
 129d741:	4c 89 4d b8          	mov    %r9,-0x48(%rbp)
 129d745:	ff b5 60 ff ff ff    	push   -0xa0(%rbp)
 129d74b:	50                   	push   %rax
 129d74c:	c5 f8 77             	vzeroupper 
 129d74f:	e8 7c 0e fa ff       	call   123e5d0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492>
 129d754:	48 83 c4 10          	add    $0x10,%rsp
 129d758:	44 0f b7 ad 48 ff ff 	movzwl -0xb8(%rbp),%r13d
 129d75f:	ff 
 129d760:	66 45 85 ed          	test   %r13w,%r13w
 129d764:	0f 85 72 05 00 00    	jne    129dcdc <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x73c>
 129d76a:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 129d771:	4c 8b ad 40 ff ff ff 	mov    -0xc0(%rbp),%r13
 129d778:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 129d77c:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 129d783:	4c 89 ad 78 ff ff ff 	mov    %r13,-0x88(%rbp)
 129d78a:	f6 45 c0 01          	testb  $0x1,-0x40(%rbp)
 129d78e:	0f 84 8c 02 00 00    	je     129da20 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x480>
 129d794:	4c 89 6d c0          	mov    %r13,-0x40(%rbp)
 129d798:	48 8d bd 78 e8 ff ff 	lea    -0x1788(%rbp),%rdi
 129d79f:	4c 8b 6d d0          	mov    -0x30(%rbp),%r13
 129d7a3:	4c 89 ee             	mov    %r13,%rsi
 129d7a6:	48 89 da             	mov    %rbx,%rdx
 129d7a9:	4c 89 e1             	mov    %r12,%rcx
 129d7ac:	4c 89 7d 90          	mov    %r15,-0x70(%rbp)
 129d7b0:	4d 89 f8             	mov    %r15,%r8
 129d7b3:	4c 8b 4d b8          	mov    -0x48(%rbp),%r9
 129d7b7:	68 80 03 00 01       	push   $0x1000380
 129d7bc:	4c 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%r15
 129d7c3:	41 57                	push   %r15
 129d7c5:	e8 66 a1 fc ff       	call   1267930 <br.encoder.entropy_feedback.buildWithStartingDistances>
 129d7ca:	48 83 c4 10          	add    $0x10,%rsp
 129d7ce:	48 8d bd 60 de ff ff 	lea    -0x21a0(%rbp),%rdi
 129d7d5:	ba 18 0a 00 00       	mov    $0xa18,%edx
 129d7da:	48 8d b5 78 e8 ff ff 	lea    -0x1788(%rbp),%rsi
 129d7e1:	e8 7a 1f 04 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 129d7e6:	0f b7 85 90 f2 ff ff 	movzwl -0xd70(%rbp),%eax
 129d7ed:	66 85 c0             	test   %ax,%ax
 129d7f0:	0f 85 2a 05 00 00    	jne    129dd20 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x780>
 129d7f6:	48 8d bd 98 f2 ff ff 	lea    -0xd68(%rbp),%rdi
 129d7fd:	48 8d b5 60 de ff ff 	lea    -0x21a0(%rbp),%rsi
 129d804:	ba 18 0a 00 00       	mov    $0xa18,%edx
 129d809:	e8 52 1f 04 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 129d80e:	4c 89 bd d0 fd ff ff 	mov    %r15,-0x230(%rbp)
 129d815:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 129d819:	48 89 85 d8 fd ff ff 	mov    %rax,-0x228(%rbp)
 129d820:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 129d824:	48 89 85 e0 fd ff ff 	mov    %rax,-0x220(%rbp)
 129d82b:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 129d82f:	48 89 85 e8 fd ff ff 	mov    %rax,-0x218(%rbp)
 129d836:	c5 fc 28 05 a2 2c d6 	vmovaps -0x29d35e(%rip),%ymm0        # 10004e0 <__anon_248258+0xa0>
 129d83d:	ff 
 129d83e:	c5 fc 11 85 f0 fd ff 	vmovups %ymm0,-0x210(%rbp)
 129d845:	ff 
 129d846:	c6 85 10 fe ff ff 00 	movb   $0x0,-0x1f0(%rbp)
 129d84d:	48 8d 85 a8 f2 ff ff 	lea    -0xd58(%rbp),%rax
 129d854:	48 89 85 e0 fe ff ff 	mov    %rax,-0x120(%rbp)
 129d85b:	48 8d 85 a8 f4 ff ff 	lea    -0xb58(%rbp),%rax
 129d862:	48 89 85 e8 fe ff ff 	mov    %rax,-0x118(%rbp)
 129d869:	c5 f8 10 85 98 f2 ff 	vmovups -0xd68(%rbp),%xmm0
 129d870:	ff 
 129d871:	c5 f8 11 85 f0 fe ff 	vmovups %xmm0,-0x110(%rbp)
 129d878:	ff 
 129d879:	48 8d bd 60 fe ff ff 	lea    -0x1a0(%rbp),%rdi
 129d880:	4c 8d 85 d0 fd ff ff 	lea    -0x230(%rbp),%r8
 129d887:	4c 8d 8d e0 fe ff ff 	lea    -0x120(%rbp),%r9
 129d88e:	4c 89 ee             	mov    %r13,%rsi
 129d891:	48 89 da             	mov    %rbx,%rdx
 129d894:	4c 89 e1             	mov    %r12,%rcx
 129d897:	c5 f8 77             	vzeroupper 
 129d89a:	e8 a1 c2 f9 ff       	call   1239b40 <lz77.optimalPlanAllocWithCostModel>
 129d89f:	44 0f b7 ad 88 fe ff 	movzwl -0x178(%rbp),%r13d
 129d8a6:	ff 
 129d8a7:	66 45 85 ed          	test   %r13w,%r13w
 129d8ab:	0f 85 de 04 00 00    	jne    129dd8f <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x7ef>
 129d8b1:	4c 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%r8
 129d8b8:	4c 8b 8d 68 fe ff ff 	mov    -0x198(%rbp),%r9
 129d8bf:	48 83 bd 78 fe ff ff 	cmpq   $0x0,-0x188(%rbp)
 129d8c6:	00 
 129d8c7:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 129d8cb:	0f 84 b8 01 00 00    	je     129da89 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x4e9>
 129d8d1:	48 8d bd c0 fe ff ff 	lea    -0x140(%rbp),%rdi
 129d8d8:	4c 8b 7d d0          	mov    -0x30(%rbp),%r15
 129d8dc:	4c 89 fe             	mov    %r15,%rsi
 129d8df:	48 89 da             	mov    %rbx,%rdx
 129d8e2:	4c 89 e1             	mov    %r12,%rcx
 129d8e5:	4c 89 45 80          	mov    %r8,-0x80(%rbp)
 129d8e9:	4c 89 4d 98          	mov    %r9,-0x68(%rbp)
 129d8ed:	e8 3e 21 f1 ff       	call   11afa30 <br.encoder.command_plan.buildAlloc>
 129d8f2:	44 0f b7 ad d8 fe ff 	movzwl -0x128(%rbp),%r13d
 129d8f9:	ff 
 129d8fa:	66 45 85 ed          	test   %r13w,%r13w
 129d8fe:	0f 85 56 05 00 00    	jne    129de5a <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x8ba>
 129d904:	4c 8b 85 c0 fe ff ff 	mov    -0x140(%rbp),%r8
 129d90b:	4c 8b 8d c8 fe ff ff 	mov    -0x138(%rbp),%r9
 129d912:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129d916:	c5 fc 11 85 b0 fc ff 	vmovups %ymm0,-0x350(%rbp)
 129d91d:	ff 
 129d91e:	c5 fc 11 85 d0 fc ff 	vmovups %ymm0,-0x330(%rbp)
 129d925:	ff 
 129d926:	c5 fc 11 85 f0 fc ff 	vmovups %ymm0,-0x310(%rbp)
 129d92d:	ff 
 129d92e:	c5 fc 11 85 10 fd ff 	vmovups %ymm0,-0x2f0(%rbp)
 129d935:	ff 
 129d936:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 129d93d:	ff 
 129d93e:	48 8d 85 b0 fc ff ff 	lea    -0x350(%rbp),%rax
 129d945:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 129d94c:	4c 89 fe             	mov    %r15,%rsi
 129d94f:	48 89 da             	mov    %rbx,%rdx
 129d952:	4c 89 e1             	mov    %r12,%rcx
 129d955:	4c 89 85 68 ff ff ff 	mov    %r8,-0x98(%rbp)
 129d95c:	4c 89 4d 88          	mov    %r9,-0x78(%rbp)
 129d960:	ff b5 60 ff ff ff    	push   -0xa0(%rbp)
 129d966:	50                   	push   %rax
 129d967:	c5 f8 77             	vzeroupper 
 129d96a:	e8 61 0c fa ff       	call   123e5d0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492>
 129d96f:	48 83 c4 10          	add    $0x10,%rsp
 129d973:	44 0f b7 ad 30 ff ff 	movzwl -0xd0(%rbp),%r13d
 129d97a:	ff 
 129d97b:	66 45 85 ed          	test   %r13w,%r13w
 129d97f:	0f 85 a4 04 00 00    	jne    129de29 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x889>
 129d985:	4c 8b bd 20 ff ff ff 	mov    -0xe0(%rbp),%r15
 129d98c:	4c 8b ad 28 ff ff ff 	mov    -0xd8(%rbp),%r13
 129d993:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129d997:	49 39 d5             	cmp    %rdx,%r13
 129d99a:	0f 83 a4 01 00 00    	jae    129db44 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x5a4>
 129d9a0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129d9a4:	48 8b 38             	mov    (%rax),%rdi
 129d9a7:	48 8b 40 08          	mov    0x8(%rax),%rax
 129d9ab:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129d9af:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129d9b3:	31 c9                	xor    %ecx,%ecx
 129d9b5:	ff 50 18             	call   *0x18(%rax)
 129d9b8:	4c 89 7d c0          	mov    %r15,-0x40(%rbp)
 129d9bc:	4c 89 bd 70 ff ff ff 	mov    %r15,-0x90(%rbp)
 129d9c3:	4d 89 ef             	mov    %r13,%r15
 129d9c6:	4c 89 ad 78 ff ff ff 	mov    %r13,-0x88(%rbp)
 129d9cd:	4c 8b 6d b0          	mov    -0x50(%rbp),%r13
 129d9d1:	e9 9d 01 00 00       	jmp    129db73 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x5d3>
 129d9d6:	4d 85 c9             	test   %r9,%r9
 129d9d9:	74 21                	je     129d9fc <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x45c>
 129d9db:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129d9df:	48 8b 38             	mov    (%rax),%rdi
 129d9e2:	48 8b 40 08          	mov    0x8(%rax),%rax
 129d9e6:	4d 01 c9             	add    %r9,%r9
 129d9e9:	4b 8d 14 49          	lea    (%r9,%r9,2),%rdx
 129d9ed:	4c 89 c6             	mov    %r8,%rsi
 129d9f0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129d9f4:	b9 01 00 00 00       	mov    $0x1,%ecx
 129d9f9:	ff 50 18             	call   *0x18(%rax)
 129d9fc:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 129da00:	c4 c1 78 11 45 00    	vmovups %xmm0,0x0(%r13)
 129da06:	49 c7 45 10 00 00 00 	movq   $0x0,0x10(%r13)
 129da0d:	00 
 129da0e:	48 81 c4 78 21 00 00 	add    $0x2178,%rsp
 129da15:	5b                   	pop    %rbx
 129da16:	41 5c                	pop    %r12
 129da18:	41 5d                	pop    %r13
 129da1a:	41 5e                	pop    %r14
 129da1c:	41 5f                	pop    %r15
 129da1e:	5d                   	pop    %rbp
 129da1f:	c3                   	ret    
 129da20:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 129da24:	48 85 c9             	test   %rcx,%rcx
 129da27:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 129da2b:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 129da2f:	74 1e                	je     129da4f <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x4af>
 129da31:	49 8b 3e             	mov    (%r14),%rdi
 129da34:	49 8b 46 08          	mov    0x8(%r14),%rax
 129da38:	48 c1 e1 05          	shl    $0x5,%rcx
 129da3c:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129da40:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129da44:	4c 89 fe             	mov    %r15,%rsi
 129da47:	b9 03 00 00 00       	mov    $0x3,%ecx
 129da4c:	ff 50 18             	call   *0x18(%rax)
 129da4f:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129da53:	48 85 c9             	test   %rcx,%rcx
 129da56:	74 1e                	je     129da76 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x4d6>
 129da58:	49 8b 3e             	mov    (%r14),%rdi
 129da5b:	49 8b 46 08          	mov    0x8(%r14),%rax
 129da5f:	48 01 c9             	add    %rcx,%rcx
 129da62:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129da66:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129da6a:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 129da6e:	b9 01 00 00 00       	mov    $0x1,%ecx
 129da73:	ff 50 18             	call   *0x18(%rax)
 129da76:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 129da7c:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 129da80:	48 89 03             	mov    %rax,(%rbx)
 129da83:	4c 89 6b 08          	mov    %r13,0x8(%rbx)
 129da87:	eb 85                	jmp    129da0e <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x46e>
 129da89:	4d 85 c9             	test   %r9,%r9
 129da8c:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 129da90:	74 1d                	je     129daaf <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x50f>
 129da92:	49 8b 3e             	mov    (%r14),%rdi
 129da95:	49 8b 46 08          	mov    0x8(%r14),%rax
 129da99:	4d 01 c9             	add    %r9,%r9
 129da9c:	4b 8d 14 49          	lea    (%r9,%r9,2),%rdx
 129daa0:	4c 89 c6             	mov    %r8,%rsi
 129daa3:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129daa7:	b9 01 00 00 00       	mov    $0x1,%ecx
 129daac:	ff 50 18             	call   *0x18(%rax)
 129daaf:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 129dab6:	48 85 d2             	test   %rdx,%rdx
 129dab9:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 129dabd:	4c 8b 65 c0          	mov    -0x40(%rbp),%r12
 129dac1:	74 1d                	je     129dae0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x540>
 129dac3:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 129daca:	49 8b 3e             	mov    (%r14),%rdi
 129dacd:	49 8b 46 08          	mov    0x8(%r14),%rax
 129dad1:	48 01 d2             	add    %rdx,%rdx
 129dad4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dad8:	b9 01 00 00 00       	mov    $0x1,%ecx
 129dadd:	ff 50 18             	call   *0x18(%rax)
 129dae0:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 129dae4:	48 85 c9             	test   %rcx,%rcx
 129dae7:	74 1e                	je     129db07 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x567>
 129dae9:	49 8b 3e             	mov    (%r14),%rdi
 129daec:	49 8b 46 08          	mov    0x8(%r14),%rax
 129daf0:	48 c1 e1 05          	shl    $0x5,%rcx
 129daf4:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129daf8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dafc:	4c 89 fe             	mov    %r15,%rsi
 129daff:	b9 03 00 00 00       	mov    $0x3,%ecx
 129db04:	ff 50 18             	call   *0x18(%rax)
 129db07:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129db0b:	48 85 c9             	test   %rcx,%rcx
 129db0e:	74 1e                	je     129db2e <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x58e>
 129db10:	49 8b 3e             	mov    (%r14),%rdi
 129db13:	49 8b 46 08          	mov    0x8(%r14),%rax
 129db17:	48 01 c9             	add    %rcx,%rcx
 129db1a:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129db1e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129db22:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 129db26:	b9 01 00 00 00       	mov    $0x1,%ecx
 129db2b:	ff 50 18             	call   *0x18(%rax)
 129db2e:	66 c7 43 10 00 00    	movw   $0x0,0x10(%rbx)
 129db34:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 129db38:	48 89 03             	mov    %rax,(%rbx)
 129db3b:	4c 89 63 08          	mov    %r12,0x8(%rbx)
 129db3f:	e9 ca fe ff ff       	jmp    129da0e <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x46e>
 129db44:	4d 85 ed             	test   %r13,%r13
 129db47:	4c 89 ea             	mov    %r13,%rdx
 129db4a:	4c 8b 6d b0          	mov    -0x50(%rbp),%r13
 129db4e:	74 17                	je     129db67 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x5c7>
 129db50:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129db54:	48 8b 38             	mov    (%rax),%rdi
 129db57:	48 8b 40 08          	mov    0x8(%rax),%rax
 129db5b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129db5f:	4c 89 fe             	mov    %r15,%rsi
 129db62:	31 c9                	xor    %ecx,%ecx
 129db64:	ff 50 18             	call   *0x18(%rax)
 129db67:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 129db6b:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 129db6f:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 129db73:	48 8b 8d 50 ff ff ff 	mov    -0xb0(%rbp),%rcx
 129db7a:	85 c9                	test   %ecx,%ecx
 129db7c:	0f 95 c0             	setne  %al
 129db7f:	49 39 cc             	cmp    %rcx,%r12
 129db82:	0f 96 c1             	setbe  %cl
 129db85:	84 c8                	test   %cl,%al
 129db87:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129db8b:	4c 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%r8
 129db92:	74 4c                	je     129dbe0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x640>
 129db94:	48 8d 85 70 ff ff ff 	lea    -0x90(%rbp),%rax
 129db9b:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 129db9f:	48 89 de             	mov    %rbx,%rsi
 129dba2:	4c 89 e2             	mov    %r12,%rdx
 129dba5:	4c 89 f1             	mov    %r14,%rcx
 129dba8:	4c 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%r9
 129dbaf:	50                   	push   %rax
 129dbb0:	48 8d 85 98 f2 ff ff 	lea    -0xd68(%rbp),%rax
 129dbb7:	50                   	push   %rax
 129dbb8:	e8 33 90 05 00       	call   12f6bf0 <br.selectQualityCommandStateCandidate>
 129dbbd:	48 83 c4 10          	add    $0x10,%rsp
 129dbc1:	66 85 c0             	test   %ax,%ax
 129dbc4:	0f 85 76 03 00 00    	jne    129df40 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x9a0>
 129dbca:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 129dbd1:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 129dbd5:	4c 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%r15
 129dbdc:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129dbe0:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 129dbe4:	48 85 d2             	test   %rdx,%rdx
 129dbe7:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 129dbeb:	74 26                	je     129dc13 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x673>
 129dbed:	48 8b 3b             	mov    (%rbx),%rdi
 129dbf0:	48 8b 43 08          	mov    0x8(%rbx),%rax
 129dbf4:	48 c1 e2 05          	shl    $0x5,%rdx
 129dbf8:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 129dbfc:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dc00:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 129dc07:	b9 03 00 00 00       	mov    $0x3,%ecx
 129dc0c:	ff 50 18             	call   *0x18(%rax)
 129dc0f:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129dc13:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 129dc17:	48 85 d2             	test   %rdx,%rdx
 129dc1a:	74 22                	je     129dc3e <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x69e>
 129dc1c:	48 8b 3b             	mov    (%rbx),%rdi
 129dc1f:	48 8b 43 08          	mov    0x8(%rbx),%rax
 129dc23:	48 01 d2             	add    %rdx,%rdx
 129dc26:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 129dc2a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dc2e:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 129dc32:	b9 01 00 00 00       	mov    $0x1,%ecx
 129dc37:	ff 50 18             	call   *0x18(%rax)
 129dc3a:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129dc3e:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 129dc45:	48 85 d2             	test   %rdx,%rdx
 129dc48:	74 21                	je     129dc6b <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x6cb>
 129dc4a:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 129dc51:	48 8b 3b             	mov    (%rbx),%rdi
 129dc54:	48 8b 43 08          	mov    0x8(%rbx),%rax
 129dc58:	48 01 d2             	add    %rdx,%rdx
 129dc5b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dc5f:	b9 01 00 00 00       	mov    $0x1,%ecx
 129dc64:	ff 50 18             	call   *0x18(%rax)
 129dc67:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129dc6b:	48 8b 55 b8          	mov    -0x48(%rbp),%rdx
 129dc6f:	48 85 d2             	test   %rdx,%rdx
 129dc72:	74 23                	je     129dc97 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x6f7>
 129dc74:	48 8b 3b             	mov    (%rbx),%rdi
 129dc77:	48 8b 43 08          	mov    0x8(%rbx),%rax
 129dc7b:	48 c1 e2 05          	shl    $0x5,%rdx
 129dc7f:	48 8d 14 52          	lea    (%rdx,%rdx,2),%rdx
 129dc83:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dc87:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 129dc8b:	b9 03 00 00 00       	mov    $0x3,%ecx
 129dc90:	ff 50 18             	call   *0x18(%rax)
 129dc93:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129dc97:	48 85 c9             	test   %rcx,%rcx
 129dc9a:	74 1e                	je     129dcba <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x71a>
 129dc9c:	48 8b 3b             	mov    (%rbx),%rdi
 129dc9f:	48 8b 43 08          	mov    0x8(%rbx),%rax
 129dca3:	48 01 c9             	add    %rcx,%rcx
 129dca6:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129dcaa:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dcae:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 129dcb2:	b9 01 00 00 00       	mov    $0x1,%ecx
 129dcb7:	ff 50 18             	call   *0x18(%rax)
 129dcba:	66 41 c7 45 10 00 00 	movw   $0x0,0x10(%r13)
 129dcc1:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 129dcc5:	49 89 45 00          	mov    %rax,0x0(%r13)
 129dcc9:	4d 89 7d 08          	mov    %r15,0x8(%r13)
 129dccd:	e9 3c fd ff ff       	jmp    129da0e <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x46e>
 129dcd2:	66 41 89 45 10       	mov    %ax,0x10(%r13)
 129dcd7:	e9 32 fd ff ff       	jmp    129da0e <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x46e>
 129dcdc:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 129dce0:	48 85 c9             	test   %rcx,%rcx
 129dce3:	48 8b 5d d0          	mov    -0x30(%rbp),%rbx
 129dce7:	74 1e                	je     129dd07 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x767>
 129dce9:	48 8b 3b             	mov    (%rbx),%rdi
 129dcec:	48 8b 43 08          	mov    0x8(%rbx),%rax
 129dcf0:	48 c1 e1 05          	shl    $0x5,%rcx
 129dcf4:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129dcf8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dcfc:	4c 89 fe             	mov    %r15,%rsi
 129dcff:	b9 03 00 00 00       	mov    $0x3,%ecx
 129dd04:	ff 50 18             	call   *0x18(%rax)
 129dd07:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129dd0b:	48 85 c9             	test   %rcx,%rcx
 129dd0e:	0f 84 1e 02 00 00    	je     129df32 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x992>
 129dd14:	48 8b 3b             	mov    (%rbx),%rdi
 129dd17:	48 8b 43 08          	mov    0x8(%rbx),%rax
 129dd1b:	e9 fb 01 00 00       	jmp    129df1b <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x97b>
 129dd20:	89 c3                	mov    %eax,%ebx
 129dd22:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 129dd26:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129dd2a:	48 85 d2             	test   %rdx,%rdx
 129dd2d:	74 18                	je     129dd47 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x7a7>
 129dd2f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129dd33:	48 8b 38             	mov    (%rax),%rdi
 129dd36:	48 8b 40 08          	mov    0x8(%rax),%rax
 129dd3a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dd3e:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129dd42:	31 c9                	xor    %ecx,%ecx
 129dd44:	ff 50 18             	call   *0x18(%rax)
 129dd47:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 129dd4b:	48 85 c9             	test   %rcx,%rcx
 129dd4e:	74 22                	je     129dd72 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x7d2>
 129dd50:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129dd54:	48 8b 38             	mov    (%rax),%rdi
 129dd57:	48 8b 40 08          	mov    0x8(%rax),%rax
 129dd5b:	48 c1 e1 05          	shl    $0x5,%rcx
 129dd5f:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129dd63:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dd67:	4c 89 fe             	mov    %r15,%rsi
 129dd6a:	b9 03 00 00 00       	mov    $0x3,%ecx
 129dd6f:	ff 50 18             	call   *0x18(%rax)
 129dd72:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129dd76:	48 85 c9             	test   %rcx,%rcx
 129dd79:	0f 84 d0 02 00 00    	je     129e04f <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0xaaf>
 129dd7f:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129dd83:	48 8b 38             	mov    (%rax),%rdi
 129dd86:	48 8b 40 08          	mov    0x8(%rax),%rax
 129dd8a:	e9 a9 02 00 00       	jmp    129e038 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0xa98>
 129dd8f:	4c 8b 7d 90          	mov    -0x70(%rbp),%r15
 129dd93:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 129dd9a:	48 85 d2             	test   %rdx,%rdx
 129dd9d:	74 21                	je     129ddc0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x820>
 129dd9f:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 129dda6:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129ddaa:	48 8b 38             	mov    (%rax),%rdi
 129ddad:	48 8b 40 08          	mov    0x8(%rax),%rax
 129ddb1:	48 01 d2             	add    %rdx,%rdx
 129ddb4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129ddb8:	b9 01 00 00 00       	mov    $0x1,%ecx
 129ddbd:	ff 50 18             	call   *0x18(%rax)
 129ddc0:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129ddc4:	48 85 d2             	test   %rdx,%rdx
 129ddc7:	74 18                	je     129dde1 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x841>
 129ddc9:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129ddcd:	48 8b 38             	mov    (%rax),%rdi
 129ddd0:	48 8b 40 08          	mov    0x8(%rax),%rax
 129ddd4:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129ddd8:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129dddc:	31 c9                	xor    %ecx,%ecx
 129ddde:	ff 50 18             	call   *0x18(%rax)
 129dde1:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 129dde5:	48 85 c9             	test   %rcx,%rcx
 129dde8:	74 22                	je     129de0c <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x86c>
 129ddea:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129ddee:	48 8b 38             	mov    (%rax),%rdi
 129ddf1:	48 8b 40 08          	mov    0x8(%rax),%rax
 129ddf5:	48 c1 e1 05          	shl    $0x5,%rcx
 129ddf9:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129ddfd:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129de01:	4c 89 fe             	mov    %r15,%rsi
 129de04:	b9 03 00 00 00       	mov    $0x3,%ecx
 129de09:	ff 50 18             	call   *0x18(%rax)
 129de0c:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129de10:	48 85 c9             	test   %rcx,%rcx
 129de13:	0f 84 19 01 00 00    	je     129df32 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x992>
 129de19:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129de1d:	48 8b 38             	mov    (%rax),%rdi
 129de20:	48 8b 40 08          	mov    0x8(%rax),%rax
 129de24:	e9 f2 00 00 00       	jmp    129df1b <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x97b>
 129de29:	48 83 7d 88 00       	cmpq   $0x0,-0x78(%rbp)
 129de2e:	74 2a                	je     129de5a <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x8ba>
 129de30:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129de34:	48 8b 38             	mov    (%rax),%rdi
 129de37:	48 8b 40 08          	mov    0x8(%rax),%rax
 129de3b:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 129de3f:	48 c1 e1 05          	shl    $0x5,%rcx
 129de43:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129de47:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129de4b:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 129de52:	b9 03 00 00 00       	mov    $0x3,%ecx
 129de57:	ff 50 18             	call   *0x18(%rax)
 129de5a:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 129de5f:	74 26                	je     129de87 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x8e7>
 129de61:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129de65:	48 8b 38             	mov    (%rax),%rdi
 129de68:	48 8b 40 08          	mov    0x8(%rax),%rax
 129de6c:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 129de70:	48 01 c9             	add    %rcx,%rcx
 129de73:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129de77:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129de7b:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 129de7f:	b9 01 00 00 00       	mov    $0x1,%ecx
 129de84:	ff 50 18             	call   *0x18(%rax)
 129de87:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 129de8e:	48 85 d2             	test   %rdx,%rdx
 129de91:	74 21                	je     129deb4 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x914>
 129de93:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 129de9a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129de9e:	48 8b 38             	mov    (%rax),%rdi
 129dea1:	48 8b 40 08          	mov    0x8(%rax),%rax
 129dea5:	48 01 d2             	add    %rdx,%rdx
 129dea8:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129deac:	b9 01 00 00 00       	mov    $0x1,%ecx
 129deb1:	ff 50 18             	call   *0x18(%rax)
 129deb4:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 129deb9:	74 1c                	je     129ded7 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x937>
 129debb:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129debf:	48 8b 38             	mov    (%rax),%rdi
 129dec2:	48 8b 40 08          	mov    0x8(%rax),%rax
 129dec6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129deca:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 129dece:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 129ded2:	31 c9                	xor    %ecx,%ecx
 129ded4:	ff 50 18             	call   *0x18(%rax)
 129ded7:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 129dedc:	74 27                	je     129df05 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x965>
 129dede:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129dee2:	48 8b 38             	mov    (%rax),%rdi
 129dee5:	48 8b 40 08          	mov    0x8(%rax),%rax
 129dee9:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 129deed:	48 c1 e1 05          	shl    $0x5,%rcx
 129def1:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129def5:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129def9:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 129defd:	b9 03 00 00 00       	mov    $0x3,%ecx
 129df02:	ff 50 18             	call   *0x18(%rax)
 129df05:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 129df0a:	74 26                	je     129df32 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x992>
 129df0c:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129df10:	48 8b 38             	mov    (%rax),%rdi
 129df13:	48 8b 40 08          	mov    0x8(%rax),%rax
 129df17:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129df1b:	48 01 c9             	add    %rcx,%rcx
 129df1e:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129df22:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129df26:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 129df2a:	b9 01 00 00 00       	mov    $0x1,%ecx
 129df2f:	ff 50 18             	call   *0x18(%rax)
 129df32:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 129df36:	66 44 89 68 10       	mov    %r13w,0x10(%rax)
 129df3b:	e9 ce fa ff ff       	jmp    129da0e <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x46e>
 129df40:	89 c3                	mov    %eax,%ebx
 129df42:	48 83 7d 88 00       	cmpq   $0x0,-0x78(%rbp)
 129df47:	74 2a                	je     129df73 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x9d3>
 129df49:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129df4d:	48 8b 38             	mov    (%rax),%rdi
 129df50:	48 8b 40 08          	mov    0x8(%rax),%rax
 129df54:	48 8b 4d 88          	mov    -0x78(%rbp),%rcx
 129df58:	48 c1 e1 05          	shl    $0x5,%rcx
 129df5c:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129df60:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129df64:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 129df6b:	b9 03 00 00 00       	mov    $0x3,%ecx
 129df70:	ff 50 18             	call   *0x18(%rax)
 129df73:	48 83 7d 98 00       	cmpq   $0x0,-0x68(%rbp)
 129df78:	74 26                	je     129dfa0 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0xa00>
 129df7a:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129df7e:	48 8b 38             	mov    (%rax),%rdi
 129df81:	48 8b 40 08          	mov    0x8(%rax),%rax
 129df85:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 129df89:	48 01 c9             	add    %rcx,%rcx
 129df8c:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129df90:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129df94:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 129df98:	b9 01 00 00 00       	mov    $0x1,%ecx
 129df9d:	ff 50 18             	call   *0x18(%rax)
 129dfa0:	48 8b 95 a0 f2 ff ff 	mov    -0xd60(%rbp),%rdx
 129dfa7:	48 85 d2             	test   %rdx,%rdx
 129dfaa:	74 21                	je     129dfcd <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0xa2d>
 129dfac:	48 8b b5 98 f2 ff ff 	mov    -0xd68(%rbp),%rsi
 129dfb3:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129dfb7:	48 8b 38             	mov    (%rax),%rdi
 129dfba:	48 8b 40 08          	mov    0x8(%rax),%rax
 129dfbe:	48 01 d2             	add    %rdx,%rdx
 129dfc1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dfc5:	b9 01 00 00 00       	mov    $0x1,%ecx
 129dfca:	ff 50 18             	call   *0x18(%rax)
 129dfcd:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 129dfd4:	48 85 d2             	test   %rdx,%rdx
 129dfd7:	74 1b                	je     129dff4 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0xa54>
 129dfd9:	48 8b b5 70 ff ff ff 	mov    -0x90(%rbp),%rsi
 129dfe0:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129dfe4:	48 8b 38             	mov    (%rax),%rdi
 129dfe7:	48 8b 40 08          	mov    0x8(%rax),%rax
 129dfeb:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129dfef:	31 c9                	xor    %ecx,%ecx
 129dff1:	ff 50 18             	call   *0x18(%rax)
 129dff4:	48 83 7d b8 00       	cmpq   $0x0,-0x48(%rbp)
 129dff9:	74 27                	je     129e022 <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0xa82>
 129dffb:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129dfff:	48 8b 38             	mov    (%rax),%rdi
 129e002:	48 8b 40 08          	mov    0x8(%rax),%rax
 129e006:	48 8b 4d b8          	mov    -0x48(%rbp),%rcx
 129e00a:	48 c1 e1 05          	shl    $0x5,%rcx
 129e00e:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129e012:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129e016:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 129e01a:	b9 03 00 00 00       	mov    $0x3,%ecx
 129e01f:	ff 50 18             	call   *0x18(%rax)
 129e022:	48 83 7d c8 00       	cmpq   $0x0,-0x38(%rbp)
 129e027:	74 26                	je     129e04f <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0xaaf>
 129e029:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 129e02d:	48 8b 38             	mov    (%rax),%rdi
 129e030:	48 8b 40 08          	mov    0x8(%rax),%rax
 129e034:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 129e038:	48 01 c9             	add    %rcx,%rcx
 129e03b:	48 8d 14 49          	lea    (%rcx,%rcx,2),%rdx
 129e03f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 129e043:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 129e047:	b9 01 00 00 00       	mov    $0x1,%ecx
 129e04c:	ff 50 18             	call   *0x18(%rax)
 129e04f:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 129e053:	66 89 58 10          	mov    %bx,0x10(%rax)
 129e057:	e9 b2 f9 ff ff       	jmp    129da0e <br.encodeQualityOptimalCandidateAllocRecorded__anon_248937+0x46e>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
