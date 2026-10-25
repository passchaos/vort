
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120c670 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116>:
 120c670:	55                   	push   %rbp
 120c671:	48 89 e5             	mov    %rsp,%rbp
 120c674:	41 57                	push   %r15
 120c676:	41 56                	push   %r14
 120c678:	41 55                	push   %r13
 120c67a:	41 54                	push   %r12
 120c67c:	53                   	push   %rbx
 120c67d:	48 81 ec b8 06 00 00 	sub    $0x6b8,%rsp
 120c684:	48 c7 85 20 f9 ff ff 	movq   $0x0,-0x6e0(%rbp)
 120c68b:	00 00 00 00 
 120c68f:	0f b7 02             	movzwl (%rdx),%eax
 120c692:	48 85 c0             	test   %rax,%rax
 120c695:	0f 84 5c 01 00 00    	je     120c7f7 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x187>
 120c69b:	48 89 f3             	mov    %rsi,%rbx
 120c69e:	45 31 e4             	xor    %r12d,%r12d
 120c6a1:	45 31 ff             	xor    %r15d,%r15d
 120c6a4:	31 c9                	xor    %ecx,%ecx
 120c6a6:	eb 28                	jmp    120c6d0 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x60>
 120c6a8:	45 31 e4             	xor    %r12d,%r12d
 120c6ab:	41 ff c7             	inc    %r15d
 120c6ae:	66 42 89 b4 65 28 f9 	mov    %si,-0x6d8(%rbp,%r12,2)
 120c6b5:	ff ff 
 120c6b7:	4c 8b a5 20 f9 ff ff 	mov    -0x6e0(%rbp),%r12
 120c6be:	49 ff c4             	inc    %r12
 120c6c1:	4c 89 a5 20 f9 ff ff 	mov    %r12,-0x6e0(%rbp)
 120c6c8:	48 ff c1             	inc    %rcx
 120c6cb:	48 39 c1             	cmp    %rax,%rcx
 120c6ce:	74 4f                	je     120c71f <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0xaf>
 120c6d0:	0f b6 74 0a 02       	movzbl 0x2(%rdx,%rcx,1),%esi
 120c6d5:	44 8b 04 b3          	mov    (%rbx,%rsi,4),%r8d
 120c6d9:	45 85 c0             	test   %r8d,%r8d
 120c6dc:	74 ea                	je     120c6c8 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x58>
 120c6de:	45 0f b7 cf          	movzwl %r15w,%r9d
 120c6e2:	42 88 b4 0d 2e fb ff 	mov    %sil,-0x4d2(%rbp,%r9,1)
 120c6e9:	ff 
 120c6ea:	4d 85 e4             	test   %r12,%r12
 120c6ed:	74 bc                	je     120c6ab <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x3b>
 120c6ef:	49 81 fc 00 01 00 00 	cmp    $0x100,%r12
 120c6f6:	0f 84 fb 00 00 00    	je     120c7f7 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x187>
 120c6fc:	0f 1f 40 00          	nopl   0x0(%rax)
 120c700:	46 0f b7 8c 65 26 f9 	movzwl -0x6da(%rbp,%r12,2),%r9d
 120c707:	ff ff 
 120c709:	46 3b 04 8b          	cmp    (%rbx,%r9,4),%r8d
 120c70d:	76 9c                	jbe    120c6ab <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x3b>
 120c70f:	49 ff cc             	dec    %r12
 120c712:	66 46 89 8c 65 2a f9 	mov    %r9w,-0x6d6(%rbp,%r12,2)
 120c719:	ff ff 
 120c71b:	75 e3                	jne    120c700 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x90>
 120c71d:	eb 89                	jmp    120c6a8 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x38>
 120c71f:	4d 85 e4             	test   %r12,%r12
 120c722:	0f 84 cf 00 00 00    	je     120c7f7 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x187>
 120c728:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 120c72c:	48 8d bd 2e fc ff ff 	lea    -0x3d2(%rbp),%rdi
 120c733:	48 8d b5 20 f9 ff ff 	lea    -0x6e0(%rbp),%rsi
 120c73a:	48 89 da             	mov    %rbx,%rdx
 120c73d:	e8 8e 8a f6 ff       	call   11751d0 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths>
 120c742:	0f b7 85 2e fc ff ff 	movzwl -0x3d2(%rbp),%eax
 120c749:	66 85 c0             	test   %ax,%ax
 120c74c:	0f 85 14 05 00 00    	jne    120cc66 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x5f6>
 120c752:	c5 fc 10 85 10 fd ff 	vmovups -0x2f0(%rbp),%ymm0
 120c759:	ff 
 120c75a:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 120c761:	ff 
 120c762:	c5 fc 10 85 f0 fc ff 	vmovups -0x310(%rbp),%ymm0
 120c769:	ff 
 120c76a:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 120c771:	ff 
 120c772:	c5 fc 10 85 d0 fc ff 	vmovups -0x330(%rbp),%ymm0
 120c779:	ff 
 120c77a:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 120c781:	ff 
 120c782:	c5 fc 10 85 b0 fc ff 	vmovups -0x350(%rbp),%ymm0
 120c789:	ff 
 120c78a:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 120c791:	ff 
 120c792:	c5 fc 10 85 30 fc ff 	vmovups -0x3d0(%rbp),%ymm0
 120c799:	ff 
 120c79a:	c5 fc 10 8d 70 fc ff 	vmovups -0x390(%rbp),%ymm1
 120c7a1:	ff 
 120c7a2:	c5 fc 10 95 90 fc ff 	vmovups -0x370(%rbp),%ymm2
 120c7a9:	ff 
 120c7aa:	c5 fc 11 95 40 fe ff 	vmovups %ymm2,-0x1c0(%rbp)
 120c7b1:	ff 
 120c7b2:	c5 fc 11 8d 20 fe ff 	vmovups %ymm1,-0x1e0(%rbp)
 120c7b9:	ff 
 120c7ba:	c5 fc 10 8d 50 fc ff 	vmovups -0x3b0(%rbp),%ymm1
 120c7c1:	ff 
 120c7c2:	c5 fc 11 8d 00 fe ff 	vmovups %ymm1,-0x200(%rbp)
 120c7c9:	ff 
 120c7ca:	c5 fc 11 85 e0 fd ff 	vmovups %ymm0,-0x220(%rbp)
 120c7d1:	ff 
 120c7d2:	66 45 85 ff          	test   %r15w,%r15w
 120c7d6:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 120c7da:	74 36                	je     120c812 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x1a2>
 120c7dc:	45 0f b7 c7          	movzwl %r15w,%r8d
 120c7e0:	44 89 c2             	mov    %r8d,%edx
 120c7e3:	83 e2 03             	and    $0x3,%edx
 120c7e6:	66 41 83 ff 04       	cmp    $0x4,%r15w
 120c7eb:	73 37                	jae    120c824 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x1b4>
 120c7ed:	31 f6                	xor    %esi,%esi
 120c7ef:	45 31 ff             	xor    %r15d,%r15d
 120c7f2:	e9 c6 00 00 00       	jmp    120c8bd <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x24d>
 120c7f7:	66 c7 47 08 1f 00    	movw   $0x1f,0x8(%rdi)
 120c7fd:	48 81 c4 b8 06 00 00 	add    $0x6b8,%rsp
 120c804:	5b                   	pop    %rbx
 120c805:	41 5c                	pop    %r12
 120c807:	41 5d                	pop    %r13
 120c809:	41 5e                	pop    %r14
 120c80b:	41 5f                	pop    %r15
 120c80d:	5d                   	pop    %rbp
 120c80e:	c5 f8 77             	vzeroupper 
 120c811:	c3                   	ret    
 120c812:	49 83 fc 05          	cmp    $0x5,%r12
 120c816:	0f 83 3d 04 00 00    	jae    120cc59 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x5e9>
 120c81c:	45 31 ff             	xor    %r15d,%r15d
 120c81f:	e9 e4 00 00 00       	jmp    120c908 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x298>
 120c824:	44 89 c1             	mov    %r8d,%ecx
 120c827:	83 e1 fc             	and    $0xfffffffc,%ecx
 120c82a:	31 f6                	xor    %esi,%esi
 120c82c:	45 31 ff             	xor    %r15d,%r15d
 120c82f:	90                   	nop
 120c830:	0f b6 bc 35 2e fb ff 	movzbl -0x4d2(%rbp,%rsi,1),%edi
 120c837:	ff 
 120c838:	44 8b 0c bb          	mov    (%rbx,%rdi,4),%r9d
 120c83c:	0f b6 bc 3d e0 fd ff 	movzbl -0x220(%rbp,%rdi,1),%edi
 120c843:	ff 
 120c844:	83 e7 0f             	and    $0xf,%edi
 120c847:	49 0f af f9          	imul   %r9,%rdi
 120c84b:	4c 01 ff             	add    %r15,%rdi
 120c84e:	44 0f b6 8c 35 2f fb 	movzbl -0x4d1(%rbp,%rsi,1),%r9d
 120c855:	ff ff 
 120c857:	46 8b 14 8b          	mov    (%rbx,%r9,4),%r10d
 120c85b:	46 0f b6 8c 0d e0 fd 	movzbl -0x220(%rbp,%r9,1),%r9d
 120c862:	ff ff 
 120c864:	41 83 e1 0f          	and    $0xf,%r9d
 120c868:	4d 0f af ca          	imul   %r10,%r9
 120c86c:	44 0f b6 94 35 30 fb 	movzbl -0x4d0(%rbp,%rsi,1),%r10d
 120c873:	ff ff 
 120c875:	46 8b 1c 93          	mov    (%rbx,%r10,4),%r11d
 120c879:	46 0f b6 94 15 e0 fd 	movzbl -0x220(%rbp,%r10,1),%r10d
 120c880:	ff ff 
 120c882:	41 83 e2 0f          	and    $0xf,%r10d
 120c886:	4d 0f af d3          	imul   %r11,%r10
 120c88a:	4d 01 ca             	add    %r9,%r10
 120c88d:	49 01 fa             	add    %rdi,%r10
 120c890:	0f b6 bc 35 31 fb ff 	movzbl -0x4cf(%rbp,%rsi,1),%edi
 120c897:	ff 
 120c898:	44 8b 0c bb          	mov    (%rbx,%rdi,4),%r9d
 120c89c:	44 0f b6 bc 3d e0 fd 	movzbl -0x220(%rbp,%rdi,1),%r15d
 120c8a3:	ff ff 
 120c8a5:	41 83 e7 0f          	and    $0xf,%r15d
 120c8a9:	4d 0f af f9          	imul   %r9,%r15
 120c8ad:	4d 01 d7             	add    %r10,%r15
 120c8b0:	48 83 c6 04          	add    $0x4,%rsi
 120c8b4:	48 39 f1             	cmp    %rsi,%rcx
 120c8b7:	0f 85 73 ff ff ff    	jne    120c830 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x1c0>
 120c8bd:	48 85 d2             	test   %rdx,%rdx
 120c8c0:	74 40                	je     120c902 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x292>
 120c8c2:	48 8d 8d 2c fb ff ff 	lea    -0x4d4(%rbp),%rcx
 120c8c9:	48 01 f1             	add    %rsi,%rcx
 120c8cc:	48 83 c1 02          	add    $0x2,%rcx
 120c8d0:	31 f6                	xor    %esi,%esi
 120c8d2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120c8d9:	1f 84 00 00 00 00 00 
 120c8e0:	0f b6 3c 31          	movzbl (%rcx,%rsi,1),%edi
 120c8e4:	44 8b 0c bb          	mov    (%rbx,%rdi,4),%r9d
 120c8e8:	0f b6 bc 3d e0 fd ff 	movzbl -0x220(%rbp,%rdi,1),%edi
 120c8ef:	ff 
 120c8f0:	83 e7 0f             	and    $0xf,%edi
 120c8f3:	49 0f af f9          	imul   %r9,%rdi
 120c8f7:	49 01 ff             	add    %rdi,%r15
 120c8fa:	48 ff c6             	inc    %rsi
 120c8fd:	48 39 f2             	cmp    %rsi,%rdx
 120c900:	75 de                	jne    120c8e0 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x270>
 120c902:	49 83 fc 05          	cmp    $0x5,%r12
 120c906:	73 22                	jae    120c92a <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x2ba>
 120c908:	31 c9                	xor    %ecx,%ecx
 120c90a:	49 83 fc 04          	cmp    $0x4,%r12
 120c90e:	0f 94 c1             	sete   %cl
 120c911:	4a 8d 0c e1          	lea    (%rcx,%r12,8),%rcx
 120c915:	48 83 c1 04          	add    $0x4,%rcx
 120c919:	49 01 cf             	add    %rcx,%r15
 120c91c:	66 c7 40 08 00 00    	movw   $0x0,0x8(%rax)
 120c922:	4c 89 38             	mov    %r15,(%rax)
 120c925:	e9 d3 fe ff ff       	jmp    120c7fd <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x18d>
 120c92a:	48 c7 45 a0 02 00 00 	movq   $0x2,-0x60(%rbp)
 120c931:	00 
 120c932:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 120c936:	c5 fc 11 85 70 ff ff 	vmovups %ymm0,-0x90(%rbp)
 120c93d:	ff 
 120c93e:	c5 fc 11 85 60 ff ff 	vmovups %ymm0,-0xa0(%rbp)
 120c945:	ff 
 120c946:	c5 fc 11 85 40 ff ff 	vmovups %ymm0,-0xc0(%rbp)
 120c94d:	ff 
 120c94e:	c5 fc 11 85 20 ff ff 	vmovups %ymm0,-0xe0(%rbp)
 120c955:	ff 
 120c956:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 120c95d:	ff 
 120c95e:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 120c965:	ff 
 120c966:	4c 89 c0             	mov    %r8,%rax
 120c969:	48 f7 d8             	neg    %rax
 120c96c:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 120c970:	48 c7 45 c0 00 00 00 	movq   $0x0,-0x40(%rbp)
 120c977:	00 
 120c978:	48 c7 45 b8 00 00 00 	movq   $0x0,-0x48(%rbp)
 120c97f:	00 
 120c980:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%rbp)
 120c987:	48 c7 45 b0 00 00 00 	movq   $0x0,-0x50(%rbp)
 120c98e:	00 
 120c98f:	c7 45 d0 00 00 00 00 	movl   $0x0,-0x30(%rbp)
 120c996:	31 ff                	xor    %edi,%edi
 120c998:	45 31 c9             	xor    %r9d,%r9d
 120c99b:	45 31 ed             	xor    %r13d,%r13d
 120c99e:	44 0f b6 b4 3d 2e fb 	movzbl -0x4d2(%rbp,%rdi,1),%r14d
 120c9a5:	ff ff 
 120c9a7:	4d 39 ce             	cmp    %r9,%r14
 120c9aa:	0f 82 98 02 00 00    	jb     120cc48 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x5d8>
 120c9b0:	42 0f b6 94 35 e0 fd 	movzbl -0x220(%rbp,%r14,1),%edx
 120c9b7:	ff ff 
 120c9b9:	48 89 d6             	mov    %rdx,%rsi
 120c9bc:	48 83 e6 0f          	and    $0xf,%rsi
 120c9c0:	0f 84 82 02 00 00    	je     120cc48 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x5d8>
 120c9c6:	4c 89 f1             	mov    %r14,%rcx
 120c9c9:	4c 29 c9             	sub    %r9,%rcx
 120c9cc:	76 17                	jbe    120c9e5 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x375>
 120c9ce:	48 83 f9 02          	cmp    $0x2,%rcx
 120c9d2:	0f 87 91 00 00 00    	ja     120ca69 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x3f9>
 120c9d8:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 120c9dc:	01 c8                	add    %ecx,%eax
 120c9de:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 120c9e2:	49 01 cd             	add    %rcx,%r13
 120c9e5:	48 8d 5f 01          	lea    0x1(%rdi),%rbx
 120c9e9:	41 b9 01 00 00 00    	mov    $0x1,%r9d
 120c9ef:	4c 39 c3             	cmp    %r8,%rbx
 120c9f2:	0f 83 d7 00 00 00    	jae    120cacf <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x45f>
 120c9f8:	4d 89 c1             	mov    %r8,%r9
 120c9fb:	49 29 f9             	sub    %rdi,%r9
 120c9fe:	48 8d 85 2f fb ff ff 	lea    -0x4d1(%rbp),%rax
 120ca05:	48 01 c7             	add    %rax,%rdi
 120ca08:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 120ca0c:	4c 8d 1c 18          	lea    (%rax,%rbx,1),%r11
 120ca10:	80 e2 0f             	and    $0xf,%dl
 120ca13:	31 c9                	xor    %ecx,%ecx
 120ca15:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120ca1c:	00 00 00 00 
 120ca20:	44 0f b6 24 0f       	movzbl (%rdi,%rcx,1),%r12d
 120ca25:	4d 39 e6             	cmp    %r12,%r14
 120ca28:	0f 83 1a 02 00 00    	jae    120cc48 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x5d8>
 120ca2e:	46 0f b6 94 25 e0 fd 	movzbl -0x220(%rbp,%r12,1),%r10d
 120ca35:	ff ff 
 120ca37:	41 f6 c2 0f          	test   $0xf,%r10b
 120ca3b:	0f 84 07 02 00 00    	je     120cc48 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x5d8>
 120ca41:	49 8d 46 01          	lea    0x1(%r14),%rax
 120ca45:	4c 39 e0             	cmp    %r12,%rax
 120ca48:	75 7c                	jne    120cac6 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x456>
 120ca4a:	41 80 e2 0f          	and    $0xf,%r10b
 120ca4e:	41 38 d2             	cmp    %dl,%r10b
 120ca51:	75 73                	jne    120cac6 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x456>
 120ca53:	48 ff c1             	inc    %rcx
 120ca56:	4c 89 d8             	mov    %r11,%rax
 120ca59:	4d 89 e6             	mov    %r12,%r14
 120ca5c:	48 01 c8             	add    %rcx,%rax
 120ca5f:	75 bf                	jne    120ca20 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x3b0>
 120ca61:	4d 89 e6             	mov    %r12,%r14
 120ca64:	4c 89 c7             	mov    %r8,%rdi
 120ca67:	eb 69                	jmp    120cad2 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x462>
 120ca69:	41 b9 01 00 00 00    	mov    $0x1,%r9d
 120ca6f:	83 f9 0b             	cmp    $0xb,%ecx
 120ca72:	72 32                	jb     120caa6 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x436>
 120ca74:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 120ca7b:	00 00 00 00 00 
 120ca80:	44 8d 51 05          	lea    0x5(%rcx),%r10d
 120ca84:	41 83 e2 07          	and    $0x7,%r10d
 120ca88:	4c 29 d1             	sub    %r10,%rcx
 120ca8b:	48 83 c1 fd          	add    $0xfffffffffffffffd,%rcx
 120ca8f:	49 89 ca             	mov    %rcx,%r10
 120ca92:	49 c1 ea 03          	shr    $0x3,%r10
 120ca96:	49 83 c2 02          	add    $0x2,%r10
 120ca9a:	49 ff c1             	inc    %r9
 120ca9d:	48 83 f9 47          	cmp    $0x47,%rcx
 120caa1:	4c 89 d1             	mov    %r10,%rcx
 120caa4:	77 da                	ja     120ca80 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x410>
 120caa6:	44 01 4d d0          	add    %r9d,-0x30(%rbp)
 120caaa:	4d 01 cd             	add    %r9,%r13
 120caad:	4c 01 4d b0          	add    %r9,-0x50(%rbp)
 120cab1:	48 8d 5f 01          	lea    0x1(%rdi),%rbx
 120cab5:	41 b9 01 00 00 00    	mov    $0x1,%r9d
 120cabb:	4c 39 c3             	cmp    %r8,%rbx
 120cabe:	0f 82 34 ff ff ff    	jb     120c9f8 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x388>
 120cac4:	eb 09                	jmp    120cacf <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x45f>
 120cac6:	48 01 cb             	add    %rcx,%rbx
 120cac9:	48 ff c1             	inc    %rcx
 120cacc:	49 89 c9             	mov    %rcx,%r9
 120cacf:	48 89 df             	mov    %rbx,%rdi
 120cad2:	8b 8c b5 48 ff ff ff 	mov    -0xb8(%rbp,%rsi,4),%ecx
 120cad9:	ff c1                	inc    %ecx
 120cadb:	89 8c b5 48 ff ff ff 	mov    %ecx,-0xb8(%rbp,%rsi,4)
 120cae2:	49 8d 55 01          	lea    0x1(%r13),%rdx
 120cae6:	49 83 f9 02          	cmp    $0x2,%r9
 120caea:	72 62                	jb     120cb4e <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x4de>
 120caec:	49 8d 59 ff          	lea    -0x1(%r9),%rbx
 120caf0:	49 83 f9 03          	cmp    $0x3,%r9
 120caf4:	77 1d                	ja     120cb13 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x4a3>
 120caf6:	01 d9                	add    %ebx,%ecx
 120caf8:	89 8c b5 48 ff ff ff 	mov    %ecx,-0xb8(%rbp,%rsi,4)
 120caff:	4d 01 cd             	add    %r9,%r13
 120cb02:	49 ff c6             	inc    %r14
 120cb05:	4d 89 f1             	mov    %r14,%r9
 120cb08:	4c 39 c7             	cmp    %r8,%rdi
 120cb0b:	0f 82 8d fe ff ff    	jb     120c99e <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x32e>
 120cb11:	eb 4d                	jmp    120cb60 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x4f0>
 120cb13:	b9 01 00 00 00       	mov    $0x1,%ecx
 120cb18:	48 83 fb 07          	cmp    $0x7,%rbx
 120cb1c:	72 26                	jb     120cb44 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x4d4>
 120cb1e:	66 90                	xchg   %ax,%ax
 120cb20:	8d 73 01             	lea    0x1(%rbx),%esi
 120cb23:	83 e6 03             	and    $0x3,%esi
 120cb26:	48 29 f3             	sub    %rsi,%rbx
 120cb29:	48 83 c3 fd          	add    $0xfffffffffffffffd,%rbx
 120cb2d:	48 89 de             	mov    %rbx,%rsi
 120cb30:	48 c1 ee 02          	shr    $0x2,%rsi
 120cb34:	48 83 c6 02          	add    $0x2,%rsi
 120cb38:	48 ff c1             	inc    %rcx
 120cb3b:	48 83 fb 13          	cmp    $0x13,%rbx
 120cb3f:	48 89 f3             	mov    %rsi,%rbx
 120cb42:	77 dc                	ja     120cb20 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x4b0>
 120cb44:	01 4d d4             	add    %ecx,-0x2c(%rbp)
 120cb47:	48 01 ca             	add    %rcx,%rdx
 120cb4a:	48 01 4d b8          	add    %rcx,-0x48(%rbp)
 120cb4e:	49 89 d5             	mov    %rdx,%r13
 120cb51:	49 ff c6             	inc    %r14
 120cb54:	4d 89 f1             	mov    %r14,%r9
 120cb57:	4c 39 c7             	cmp    %r8,%rdi
 120cb5a:	0f 82 3e fe ff ff    	jb     120c99e <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x32e>
 120cb60:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 120cb64:	89 85 48 ff ff ff    	mov    %eax,-0xb8(%rbp)
 120cb6a:	8b 45 d0             	mov    -0x30(%rbp),%eax
 120cb6d:	89 45 8c             	mov    %eax,-0x74(%rbp)
 120cb70:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 120cb74:	48 89 85 f0 fe ff ff 	mov    %rax,-0x110(%rbp)
 120cb7b:	8b 45 d4             	mov    -0x2c(%rbp),%eax
 120cb7e:	89 45 88             	mov    %eax,-0x78(%rbp)
 120cb81:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 120cb85:	48 89 85 e8 fe ff ff 	mov    %rax,-0x118(%rbp)
 120cb8c:	4c 89 ad e0 fe ff ff 	mov    %r13,-0x120(%rbp)
 120cb93:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 120cb9a:	ff 
 120cb9b:	c5 fc 10 8d 20 ff ff 	vmovups -0xe0(%rbp),%ymm1
 120cba2:	ff 
 120cba3:	c5 fc 10 95 60 ff ff 	vmovups -0xa0(%rbp),%ymm2
 120cbaa:	ff 
 120cbab:	c5 fc 11 85 50 fd ff 	vmovups %ymm0,-0x2b0(%rbp)
 120cbb2:	ff 
 120cbb3:	c5 fc 11 8d 70 fd ff 	vmovups %ymm1,-0x290(%rbp)
 120cbba:	ff 
 120cbbb:	c5 fc 11 95 b0 fd ff 	vmovups %ymm2,-0x250(%rbp)
 120cbc2:	ff 
 120cbc3:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 120cbca:	48 89 85 30 fd ff ff 	mov    %rax,-0x2d0(%rbp)
 120cbd1:	48 8b 85 e8 fe ff ff 	mov    -0x118(%rbp),%rax
 120cbd8:	48 89 85 38 fd ff ff 	mov    %rax,-0x2c8(%rbp)
 120cbdf:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 120cbe6:	48 89 85 40 fd ff ff 	mov    %rax,-0x2c0(%rbp)
 120cbed:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 120cbf4:	48 89 85 48 fd ff ff 	mov    %rax,-0x2b8(%rbp)
 120cbfb:	c5 fc 10 85 40 ff ff 	vmovups -0xc0(%rbp),%ymm0
 120cc02:	ff 
 120cc03:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 120cc0a:	ff 
 120cc0b:	c5 fc 10 85 70 ff ff 	vmovups -0x90(%rbp),%ymm0
 120cc12:	ff 
 120cc13:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 120cc1a:	ff 
 120cc1b:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 120cc1f:	48 8d 75 a0          	lea    -0x60(%rbp),%rsi
 120cc23:	48 8d 95 30 fd ff ff 	lea    -0x2d0(%rbp),%rdx
 120cc2a:	c5 f8 77             	vzeroupper 
 120cc2d:	e8 ce 9f f6 ff       	call   1176c00 <br.encoder.complex_prefix.finishBitCost__anon_36314>
 120cc32:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 120cc36:	0f b7 4d 98          	movzwl -0x68(%rbp),%ecx
 120cc3a:	66 85 c9             	test   %cx,%cx
 120cc3d:	75 1e                	jne    120cc5d <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x5ed>
 120cc3f:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 120cc43:	e9 d1 fc ff ff       	jmp    120c919 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x2a9>
 120cc48:	66 b9 1f 00          	mov    $0x1f,%cx
 120cc4c:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 120cc50:	66 89 48 08          	mov    %cx,0x8(%rax)
 120cc54:	e9 a4 fb ff ff       	jmp    120c7fd <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x18d>
 120cc59:	66 b9 1f 00          	mov    $0x1f,%cx
 120cc5d:	66 89 48 08          	mov    %cx,0x8(%rax)
 120cc61:	e9 97 fb ff ff       	jmp    120c7fd <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x18d>
 120cc66:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 120cc6a:	66 89 41 08          	mov    %ax,0x8(%rcx)
 120cc6e:	e9 8a fb ff ff       	jmp    120c7fd <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116+0x18d>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
