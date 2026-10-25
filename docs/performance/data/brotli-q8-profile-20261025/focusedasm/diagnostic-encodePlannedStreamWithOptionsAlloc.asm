
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001299760 <br.encodePlannedStreamWithOptionsAlloc>:
 1299760:	55                   	push   %rbp
 1299761:	48 89 e5             	mov    %rsp,%rbp
 1299764:	41 57                	push   %r15
 1299766:	41 56                	push   %r14
 1299768:	41 54                	push   %r12
 129976a:	53                   	push   %rbx
 129976b:	48 81 ec 50 01 00 00 	sub    $0x150,%rsp
 1299772:	66 b8 43 00          	mov    $0x43,%ax
 1299776:	45 31 c0             	xor    %r8d,%r8d
 1299779:	45 84 c0             	test   %r8b,%r8b
 129977c:	75 15                	jne    1299793 <br.encodePlannedStreamWithOptionsAlloc+0x33>
 129977e:	45 31 c0             	xor    %r8d,%r8d
 1299781:	45 84 c0             	test   %r8b,%r8b
 1299784:	75 0d                	jne    1299793 <br.encodePlannedStreamWithOptionsAlloc+0x33>
 1299786:	66 b8 52 00          	mov    $0x52,%ax
 129978a:	f6 05 29 7d d7 ff 03 	testb  $0x3,-0x2882d7(%rip)        # 10114ba <__anon_3224+0x82>
 1299791:	74 14                	je     12997a7 <br.encodePlannedStreamWithOptionsAlloc+0x47>
 1299793:	66 89 47 10          	mov    %ax,0x10(%rdi)
 1299797:	48 81 c4 50 01 00 00 	add    $0x150,%rsp
 129979e:	5b                   	pop    %rbx
 129979f:	41 5c                	pop    %r12
 12997a1:	41 5e                	pop    %r14
 12997a3:	41 5f                	pop    %r15
 12997a5:	5d                   	pop    %rbp
 12997a6:	c3                   	ret    
 12997a7:	49 89 d7             	mov    %rdx,%r15
 12997aa:	49 89 cc             	mov    %rcx,%r12
 12997ad:	49 89 f6             	mov    %rsi,%r14
 12997b0:	48 8d 85 b8 fe ff ff 	lea    -0x148(%rbp),%rax
 12997b7:	be 38 14 01 01       	mov    $0x1011438,%esi
 12997bc:	48 89 fb             	mov    %rdi,%rbx
 12997bf:	48 89 c7             	mov    %rax,%rdi
 12997c2:	e8 f9 d1 fd ff       	call   12769c0 <br.resolvedQualitySchedule>
 12997c7:	48 89 df             	mov    %rbx,%rdi
 12997ca:	0f b7 85 ec fe ff ff 	movzwl -0x114(%rbp),%eax
 12997d1:	66 85 c0             	test   %ax,%ax
 12997d4:	75 bd                	jne    1299793 <br.encodePlannedStreamWithOptionsAlloc+0x33>
 12997d6:	4c 89 e1             	mov    %r12,%rcx
 12997d9:	49 81 fc 00 00 00 01 	cmp    $0x1000000,%r12
 12997e0:	4c 89 fa             	mov    %r15,%rdx
 12997e3:	77 23                	ja     1299808 <br.encodePlannedStreamWithOptionsAlloc+0xa8>
 12997e5:	0f b6 05 cf 7c d7 ff 	movzbl -0x288331(%rip),%eax        # 10114bb <__anon_3224+0x83>
 12997ec:	24 0c                	and    $0xc,%al
 12997ee:	74 18                	je     1299808 <br.encodePlannedStreamWithOptionsAlloc+0xa8>
 12997f0:	31 c0                	xor    %eax,%eax
 12997f2:	84 c0                	test   %al,%al
 12997f4:	75 0a                	jne    1299800 <br.encodePlannedStreamWithOptionsAlloc+0xa0>
 12997f6:	31 c0                	xor    %eax,%eax
 12997f8:	84 c0                	test   %al,%al
 12997fa:	0f 84 98 01 00 00    	je     1299998 <br.encodePlannedStreamWithOptionsAlloc+0x238>
 1299800:	66 c7 47 10 43 00    	movw   $0x43,0x10(%rdi)
 1299806:	eb 8f                	jmp    1299797 <br.encodePlannedStreamWithOptionsAlloc+0x37>
 1299808:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 129980c:	48 89 4d c0          	mov    %rcx,-0x40(%rbp)
 1299810:	0f b6 05 a7 7c d7 ff 	movzbl -0x288359(%rip),%eax        # 10114be <__anon_3224+0x86>
 1299817:	c6 45 d0 00          	movb   $0x0,-0x30(%rbp)
 129981b:	c6 45 cb 00          	movb   $0x0,-0x35(%rbp)
 129981f:	24 03                	and    $0x3,%al
 1299821:	88 45 cc             	mov    %al,-0x34(%rbp)
 1299824:	48 8d bd b8 fe ff ff 	lea    -0x148(%rbp),%rdi
 129982b:	be 38 14 01 01       	mov    $0x1011438,%esi
 1299830:	e8 8b d1 fd ff       	call   12769c0 <br.resolvedQualitySchedule>
 1299835:	48 89 d9             	mov    %rbx,%rcx
 1299838:	0f b7 95 ec fe ff ff 	movzwl -0x114(%rbp),%edx
 129983f:	66 85 d2             	test   %dx,%dx
 1299842:	0f 85 47 01 00 00    	jne    129998f <br.encodePlannedStreamWithOptionsAlloc+0x22f>
 1299848:	4c 89 f6             	mov    %r14,%rsi
 129984b:	0f b6 85 db fe ff ff 	movzbl -0x125(%rbp),%eax
 1299852:	f6 05 64 7c d7 ff 01 	testb  $0x1,-0x28839c(%rip)        # 10114bd <__anon_3224+0x85>
 1299859:	0f 84 02 01 00 00    	je     1299961 <br.encodePlannedStreamWithOptionsAlloc+0x201>
 129985f:	8d 78 01             	lea    0x1(%rax),%edi
 1299862:	40 80 e7 1f          	and    $0x1f,%dil
 1299866:	66 ba 52 00          	mov    $0x52,%dx
 129986a:	40 80 ff 0b          	cmp    $0xb,%dil
 129986e:	0f 82 1b 01 00 00    	jb     129998f <br.encodePlannedStreamWithOptionsAlloc+0x22f>
 1299874:	0f b7 0d 40 7c d7 ff 	movzwl -0x2883c0(%rip),%ecx        # 10114bb <__anon_3224+0x83>
 129987b:	24 1f                	and    $0x1f,%al
 129987d:	88 45 d8             	mov    %al,-0x28(%rbp)
 1299880:	c5 f8 10 05 b0 7b d7 	vmovups -0x288450(%rip),%xmm0        # 1011438 <__anon_3224>
 1299887:	ff 
 1299888:	c5 f8 29 85 f0 fe ff 	vmovaps %xmm0,-0x110(%rbp)
 129988f:	ff 
 1299890:	48 c7 85 00 ff ff ff 	movq   $0x0,-0x100(%rbp)
 1299897:	00 00 00 00 
 129989b:	c5 fc 10 05 ad 7b d7 	vmovups -0x288453(%rip),%ymm0        # 1011450 <__anon_3224+0x18>
 12998a2:	ff 
 12998a3:	c5 fc 11 85 08 ff ff 	vmovups %ymm0,-0xf8(%rbp)
 12998aa:	ff 
 12998ab:	c5 fc 10 05 bd 7b d7 	vmovups -0x288443(%rip),%ymm0        # 1011470 <__anon_3224+0x38>
 12998b2:	ff 
 12998b3:	c5 fc 11 85 28 ff ff 	vmovups %ymm0,-0xd8(%rbp)
 12998ba:	ff 
 12998bb:	48 c7 85 48 ff ff ff 	movq   $0x0,-0xb8(%rbp)
 12998c2:	00 00 00 00 
 12998c6:	48 c7 85 50 ff ff ff 	movq   $0x1139e8e,-0xb0(%rbp)
 12998cd:	8e 9e 13 01 
 12998d1:	48 c7 85 58 ff ff ff 	movq   $0x0,-0xa8(%rbp)
 12998d8:	00 00 00 00 
 12998dc:	c5 f8 10 05 bc 7b d7 	vmovups -0x288444(%rip),%xmm0        # 10114a0 <__anon_3224+0x68>
 12998e3:	ff 
 12998e4:	c5 f8 29 85 60 ff ff 	vmovaps %xmm0,-0xa0(%rbp)
 12998eb:	ff 
 12998ec:	48 8b 05 bd 7b d7 ff 	mov    -0x288443(%rip),%rax        # 10114b0 <__anon_3224+0x78>
 12998f3:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 12998fa:	0f b6 45 d0          	movzbl -0x30(%rbp),%eax
 12998fe:	88 85 78 ff ff ff    	mov    %al,-0x88(%rbp)
 1299904:	66 89 8d 79 ff ff ff 	mov    %cx,-0x87(%rbp)
 129990b:	0f b6 45 cb          	movzbl -0x35(%rbp),%eax
 129990f:	88 85 7b ff ff ff    	mov    %al,-0x85(%rbp)
 1299915:	0f b6 45 cc          	movzbl -0x34(%rbp),%eax
 1299919:	88 85 7c ff ff ff    	mov    %al,-0x84(%rbp)
 129991f:	66 c7 85 7d ff ff ff 	movw   $0x0,-0x83(%rbp)
 1299926:	00 00 
 1299928:	c6 85 7f ff ff ff ff 	movb   $0xff,-0x81(%rbp)
 129992f:	0f b6 45 d8          	movzbl -0x28(%rbp),%eax
 1299933:	88 45 80             	mov    %al,-0x80(%rbp)
 1299936:	48 8d 7d a0          	lea    -0x60(%rbp),%rdi
 129993a:	48 8d 55 b8          	lea    -0x48(%rbp),%rdx
 129993e:	4c 8d 85 f0 fe ff ff 	lea    -0x110(%rbp),%r8
 1299945:	b9 01 00 00 00       	mov    $0x1,%ecx
 129994a:	c5 f8 77             	vzeroupper 
 129994d:	e8 de 5c 00 00       	call   129f630 <br.encodePlannedStreamChunksWithOptionsAlloc>
 1299952:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 1299956:	48 89 43 10          	mov    %rax,0x10(%rbx)
 129995a:	c5 f8 10 45 a0       	vmovups -0x60(%rbp),%xmm0
 129995f:	eb 5c                	jmp    12999bd <br.encodePlannedStreamWithOptionsAlloc+0x25d>
 1299961:	0f b7 95 dc fe ff ff 	movzwl -0x124(%rbp),%edx
 1299968:	89 d7                	mov    %edx,%edi
 129996a:	c1 ef 08             	shr    $0x8,%edi
 129996d:	24 1f                	and    $0x1f,%al
 129996f:	80 e2 1f             	and    $0x1f,%dl
 1299972:	38 d0                	cmp    %dl,%al
 1299974:	0f 92 c2             	setb   %dl
 1299977:	40 80 e7 1f          	and    $0x1f,%dil
 129997b:	40 38 f8             	cmp    %dil,%al
 129997e:	40 0f 97 c7          	seta   %dil
 1299982:	40 08 d7             	or     %dl,%dil
 1299985:	66 ba 52 00          	mov    $0x52,%dx
 1299989:	0f 84 e5 fe ff ff    	je     1299874 <br.encodePlannedStreamWithOptionsAlloc+0x114>
 129998f:	66 89 51 10          	mov    %dx,0x10(%rcx)
 1299993:	e9 ff fd ff ff       	jmp    1299797 <br.encodePlannedStreamWithOptionsAlloc+0x37>
 1299998:	4c 89 f6             	mov    %r14,%rsi
 129999b:	48 8d 45 88          	lea    -0x78(%rbp),%rax
 129999f:	41 b8 38 14 01 01    	mov    $0x1011438,%r8d
 12999a5:	48 89 fb             	mov    %rdi,%rbx
 12999a8:	48 89 c7             	mov    %rax,%rdi
 12999ab:	e8 70 0e 00 00       	call   129a820 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_248831>
 12999b0:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 12999b4:	48 89 43 10          	mov    %rax,0x10(%rbx)
 12999b8:	c5 f8 10 45 88       	vmovups -0x78(%rbp),%xmm0
 12999bd:	c5 f8 11 03          	vmovups %xmm0,(%rbx)
 12999c1:	e9 d1 fd ff ff       	jmp    1299797 <br.encodePlannedStreamWithOptionsAlloc+0x37>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
