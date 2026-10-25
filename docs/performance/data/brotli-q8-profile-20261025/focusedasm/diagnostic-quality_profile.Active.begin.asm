
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001277590 <br.encoder.quality_profile.Active.begin>:
 1277590:	55                   	push   %rbp
 1277591:	48 89 e5             	mov    %rsp,%rbp
 1277594:	41 57                	push   %r15
 1277596:	41 56                	push   %r14
 1277598:	53                   	push   %rbx
 1277599:	48 83 ec 58          	sub    $0x58,%rsp
 127759d:	48 89 fb             	mov    %rdi,%rbx
 12775a0:	48 8b 7e 10          	mov    0x10(%rsi),%rdi
 12775a4:	44 0f b6 76 18       	movzbl 0x18(%rsi),%r14d
 12775a9:	44 0f b6 5e 19       	movzbl 0x19(%rsi),%r11d
 12775ae:	4c 8b 97 28 30 02 00 	mov    0x23028(%rdi),%r10
 12775b5:	48 8b 87 c8 32 02 00 	mov    0x232c8(%rdi),%rax
 12775bc:	48 85 c0             	test   %rax,%rax
 12775bf:	74 1a                	je     12775db <br.encoder.quality_profile.Active.begin+0x4b>
 12775c1:	48 c1 e0 04          	shl    $0x4,%rax
 12775c5:	48 8b 84 07 b8 30 02 	mov    0x230b8(%rdi,%rax,1),%rax
 12775cc:	00 
 12775cd:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 12775d1:	c6 45 c8 01          	movb   $0x1,-0x38(%rbp)
 12775d5:	4c 8d 7d c0          	lea    -0x40(%rbp),%r15
 12775d9:	eb 06                	jmp    12775e1 <br.encoder.quality_profile.Active.begin+0x51>
 12775db:	41 bf 70 0a 00 01    	mov    $0x1000a70,%r15d
 12775e1:	48 8b 06             	mov    (%rsi),%rax
 12775e4:	4c 8b 4e 08          	mov    0x8(%rsi),%r9
 12775e8:	c4 c1 78 10 07       	vmovups (%r15),%xmm0
 12775ed:	c5 f8 29 45 a0       	vmovaps %xmm0,-0x60(%rbp)
 12775f2:	80 e2 0f             	and    $0xf,%dl
 12775f5:	88 55 e0             	mov    %dl,-0x20(%rbp)
 12775f8:	41 80 e6 03          	and    $0x3,%r14b
 12775fc:	44 88 75 dd          	mov    %r14b,-0x23(%rbp)
 1277600:	41 80 e3 01          	and    $0x1,%r11b
 1277604:	44 88 5d de          	mov    %r11b,-0x22(%rbp)
 1277608:	4d 89 d3             	mov    %r10,%r11
 127760b:	49 ff c3             	inc    %r11
 127760e:	49 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%r14
 1277615:	4d 0f 45 f3          	cmovne %r11,%r14
 1277619:	4c 89 b7 28 30 02 00 	mov    %r14,0x23028(%rdi)
 1277620:	4c 8b 9f 20 30 02 00 	mov    0x23020(%rdi),%r11
 1277627:	4c 8b 77 18          	mov    0x18(%rdi),%r14
 127762b:	49 81 fe 00 02 00 00 	cmp    $0x200,%r14
 1277632:	41 bf 00 02 00 00    	mov    $0x200,%r15d
 1277638:	4d 0f 42 fe          	cmovb  %r14,%r15
 127763c:	4d 39 fb             	cmp    %r15,%r11
 127763f:	0f 83 d9 00 00 00    	jae    127771e <br.encoder.quality_profile.Active.begin+0x18e>
 1277645:	4d 69 f3 18 01 00 00 	imul   $0x118,%r11,%r14
 127764c:	4e 89 54 37 20       	mov    %r10,0x20(%rdi,%r14,1)
 1277651:	c5 f8 28 45 a0       	vmovaps -0x60(%rbp),%xmm0
 1277656:	c4 a1 78 11 44 37 28 	vmovups %xmm0,0x28(%rdi,%r14,1)
 127765d:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1277661:	c4 a1 78 11 44 37 38 	vmovups %xmm0,0x38(%rdi,%r14,1)
 1277668:	4a 89 4c 37 48       	mov    %rcx,0x48(%rdi,%r14,1)
 127766d:	4e 89 44 37 50       	mov    %r8,0x50(%rdi,%r14,1)
 1277672:	c4 a1 78 11 44 37 58 	vmovups %xmm0,0x58(%rdi,%r14,1)
 1277679:	4a c7 44 37 68 8e 9e 	movq   $0x1139e8e,0x68(%rdi,%r14,1)
 1277680:	13 01 
 1277682:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1277686:	c4 a1 7c 11 44 37 70 	vmovups %ymm0,0x70(%rdi,%r14,1)
 127768d:	c4 a1 7c 11 84 37 90 	vmovups %ymm0,0x90(%rdi,%r14,1)
 1277694:	00 00 00 
 1277697:	c5 fc 10 05 39 79 e1 	vmovups -0x1e86c7(%rip),%ymm0        # 108efd8 <__anon_27426>
 127769e:	ff 
 127769f:	c4 a1 7c 11 84 37 b0 	vmovups %ymm0,0xb0(%rdi,%r14,1)
 12776a6:	00 00 00 
 12776a9:	c5 fc 10 05 47 79 e1 	vmovups -0x1e86b9(%rip),%ymm0        # 108eff8 <__anon_27426+0x20>
 12776b0:	ff 
 12776b1:	c4 a1 7c 11 84 37 d0 	vmovups %ymm0,0xd0(%rdi,%r14,1)
 12776b8:	00 00 00 
 12776bb:	c5 fc 10 05 55 79 e1 	vmovups -0x1e86ab(%rip),%ymm0        # 108f018 <__anon_27426+0x40>
 12776c2:	ff 
 12776c3:	c4 a1 7c 11 84 37 f0 	vmovups %ymm0,0xf0(%rdi,%r14,1)
 12776ca:	00 00 00 
 12776cd:	c5 fc 10 05 63 79 e1 	vmovups -0x1e869d(%rip),%ymm0        # 108f038 <__anon_27426+0x60>
 12776d4:	ff 
 12776d5:	c4 a1 7c 11 84 37 10 	vmovups %ymm0,0x110(%rdi,%r14,1)
 12776dc:	01 00 00 
 12776df:	0f b6 4d e0          	movzbl -0x20(%rbp),%ecx
 12776e3:	42 88 8c 37 30 01 00 	mov    %cl,0x130(%rdi,%r14,1)
 12776ea:	00 
 12776eb:	0f b6 4d dd          	movzbl -0x23(%rbp),%ecx
 12776ef:	42 88 8c 37 31 01 00 	mov    %cl,0x131(%rdi,%r14,1)
 12776f6:	00 
 12776f7:	0f b6 4d de          	movzbl -0x22(%rbp),%ecx
 12776fb:	42 88 8c 37 32 01 00 	mov    %cl,0x132(%rdi,%r14,1)
 1277702:	00 
 1277703:	66 42 c7 84 37 33 01 	movw   $0x0,0x133(%rdi,%r14,1)
 127770a:	00 00 00 00 
 127770e:	48 ff 87 20 30 02 00 	incq   0x23020(%rdi)
 1277715:	b1 01                	mov    $0x1,%cl
 1277717:	80 fa 07             	cmp    $0x7,%dl
 127771a:	74 21                	je     127773d <br.encoder.quality_profile.Active.begin+0x1ad>
 127771c:	eb 3b                	jmp    1277759 <br.encoder.quality_profile.Active.begin+0x1c9>
 127771e:	c6 87 d0 42 02 00 01 	movb   $0x1,0x242d0(%rdi)
 1277725:	c7 45 d7 00 00 00 00 	movl   $0x0,-0x29(%rbp)
 127772c:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%rbp)
 1277733:	31 c9                	xor    %ecx,%ecx
 1277735:	45 31 db             	xor    %r11d,%r11d
 1277738:	80 fa 07             	cmp    $0x7,%dl
 127773b:	75 1c                	jne    1277759 <br.encoder.quality_profile.Active.begin+0x1c9>
 127773d:	4c 8b 87 30 30 02 00 	mov    0x23030(%rdi),%r8
 1277744:	49 ff c0             	inc    %r8
 1277747:	49 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%r14
 127774e:	4d 0f 45 f0          	cmovne %r8,%r14
 1277752:	4c 89 b7 30 30 02 00 	mov    %r14,0x23030(%rdi)
 1277759:	4c 8b 87 c8 32 02 00 	mov    0x232c8(%rdi),%r8
 1277760:	49 83 f8 20          	cmp    $0x20,%r8
 1277764:	73 2d                	jae    1277793 <br.encoder.quality_profile.Active.begin+0x203>
 1277766:	4c 89 45 b0          	mov    %r8,-0x50(%rbp)
 127776a:	c6 45 b8 01          	movb   $0x1,-0x48(%rbp)
 127776e:	49 c1 e0 04          	shl    $0x4,%r8
 1277772:	4e 89 94 07 c8 30 02 	mov    %r10,0x230c8(%rdi,%r8,1)
 1277779:	00 
 127777a:	4a c7 84 07 d0 30 02 	movq   $0x0,0x230d0(%rdi,%r8,1)
 1277781:	00 00 00 00 00 
 1277786:	48 ff 87 c8 32 02 00 	incq   0x232c8(%rdi)
 127778d:	48 8d 7d b0          	lea    -0x50(%rbp),%rdi
 1277791:	eb 0c                	jmp    127779f <br.encoder.quality_profile.Active.begin+0x20f>
 1277793:	c6 87 d2 42 02 00 00 	movb   $0x0,0x242d2(%rdi)
 127779a:	bf 70 0a 00 01       	mov    $0x1000a70,%edi
 127779f:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 12777a3:	c5 fc 11 43 10       	vmovups %ymm0,0x10(%rbx)
 12777a8:	88 53 50             	mov    %dl,0x50(%rbx)
 12777ab:	4c 89 5b 30          	mov    %r11,0x30(%rbx)
 12777af:	88 4b 38             	mov    %cl,0x38(%rbx)
 12777b2:	8b 4d d4             	mov    -0x2c(%rbp),%ecx
 12777b5:	8b 55 d7             	mov    -0x29(%rbp),%edx
 12777b8:	89 53 3c             	mov    %edx,0x3c(%rbx)
 12777bb:	89 4b 39             	mov    %ecx,0x39(%rbx)
 12777be:	c5 f8 10 07          	vmovups (%rdi),%xmm0
 12777c2:	c5 f8 11 43 40       	vmovups %xmm0,0x40(%rbx)
 12777c7:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 12777cb:	48 89 c6             	mov    %rax,%rsi
 12777ce:	ba 01 00 00 00       	mov    $0x1,%edx
 12777d3:	c5 f8 77             	vzeroupper 
 12777d6:	41 ff 91 c0 02 00 00 	call   *0x2c0(%r9)
 12777dd:	c5 f8 28 45 90       	vmovaps -0x70(%rbp),%xmm0
 12777e2:	c5 f8 29 03          	vmovaps %xmm0,(%rbx)
 12777e6:	48 83 c4 58          	add    $0x58,%rsp
 12777ea:	5b                   	pop    %rbx
 12777eb:	41 5e                	pop    %r14
 12777ed:	41 5f                	pop    %r15
 12777ef:	5d                   	pop    %rbp
 12777f0:	c3                   	ret    

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
