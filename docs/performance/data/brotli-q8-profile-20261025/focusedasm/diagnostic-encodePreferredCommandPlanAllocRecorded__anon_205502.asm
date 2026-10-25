
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

00000000012658b0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502>:
 12658b0:	55                   	push   %rbp
 12658b1:	48 89 e5             	mov    %rsp,%rbp
 12658b4:	41 57                	push   %r15
 12658b6:	41 56                	push   %r14
 12658b8:	41 55                	push   %r13
 12658ba:	41 54                	push   %r12
 12658bc:	53                   	push   %rbx
 12658bd:	48 83 e4 e0          	and    $0xffffffffffffffe0,%rsp
 12658c1:	48 81 ec c0 10 00 00 	sub    $0x10c0,%rsp
 12658c8:	4c 89 84 24 b0 00 00 	mov    %r8,0xb0(%rsp)
 12658cf:	00 
 12658d0:	48 89 8c 24 a8 00 00 	mov    %rcx,0xa8(%rsp)
 12658d7:	00 
 12658d8:	48 89 94 24 d0 00 00 	mov    %rdx,0xd0(%rsp)
 12658df:	00 
 12658e0:	48 89 74 24 40       	mov    %rsi,0x40(%rsp)
 12658e5:	48 89 7c 24 58       	mov    %rdi,0x58(%rsp)
 12658ea:	48 8b 45 18          	mov    0x18(%rbp),%rax
 12658ee:	48 8b 08             	mov    (%rax),%rcx
 12658f1:	48 89 8c 24 f0 00 00 	mov    %rcx,0xf0(%rsp)
 12658f8:	00 
 12658f9:	48 8b 48 08          	mov    0x8(%rax),%rcx
 12658fd:	48 89 8c 24 e8 00 00 	mov    %rcx,0xe8(%rsp)
 1265904:	00 
 1265905:	48 8b 48 10          	mov    0x10(%rax),%rcx
 1265909:	48 89 8c 24 e0 00 00 	mov    %rcx,0xe0(%rsp)
 1265910:	00 
 1265911:	48 8b 48 18          	mov    0x18(%rax),%rcx
 1265915:	48 89 8c 24 d8 00 00 	mov    %rcx,0xd8(%rsp)
 126591c:	00 
 126591d:	c5 fe 6f 40 20       	vmovdqu 0x20(%rax),%ymm0
 1265922:	c5 fe 7f 84 24 f0 03 	vmovdqu %ymm0,0x3f0(%rsp)
 1265929:	00 00 
 126592b:	0f b6 78 40          	movzbl 0x40(%rax),%edi
 126592f:	40 88 7c 24 20       	mov    %dil,0x20(%rsp)
 1265934:	0f b6 70 41          	movzbl 0x41(%rax),%esi
 1265938:	0f b6 48 42          	movzbl 0x42(%rax),%ecx
 126593c:	44 0f b6 58 43       	movzbl 0x43(%rax),%r11d
 1265941:	44 0f b6 60 44       	movzbl 0x44(%rax),%r12d
 1265946:	44 0f b6 40 46       	movzbl 0x46(%rax),%r8d
 126594b:	44 0f b6 50 47       	movzbl 0x47(%rax),%r10d
 1265950:	0f b6 50 4e          	movzbl 0x4e(%rax),%edx
 1265954:	40 f6 c6 01          	test   $0x1,%sil
 1265958:	4c 89 8c 24 b8 00 00 	mov    %r9,0xb8(%rsp)
 126595f:	00 
 1265960:	0f 84 bf 01 00 00    	je     1265b25 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x275>
 1265966:	48 83 c0 20          	add    $0x20,%rax
 126596a:	c5 fe 6f 00          	vmovdqu (%rax),%ymm0
 126596e:	c5 fe 7f 84 24 20 01 	vmovdqu %ymm0,0x120(%rsp)
 1265975:	00 00 
 1265977:	89 d0                	mov    %edx,%eax
 1265979:	24 1f                	and    $0x1f,%al
 126597b:	88 44 24 3f          	mov    %al,0x3f(%rsp)
 126597f:	4d 85 c9             	test   %r9,%r9
 1265982:	0f 84 9d 01 00 00    	je     1265b25 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x275>
 1265988:	44 88 9c 24 00 01 00 	mov    %r11b,0x100(%rsp)
 126598f:	00 
 1265990:	88 4c 24 70          	mov    %cl,0x70(%rsp)
 1265994:	40 88 74 24 78       	mov    %sil,0x78(%rsp)
 1265999:	44 88 94 24 40 01 00 	mov    %r10b,0x140(%rsp)
 12659a0:	00 
 12659a1:	44 88 84 24 60 01 00 	mov    %r8b,0x160(%rsp)
 12659a8:	00 
 12659a9:	40 88 bc 24 90 00 00 	mov    %dil,0x90(%rsp)
 12659b0:	00 
 12659b1:	44 88 64 24 30       	mov    %r12b,0x30(%rsp)
 12659b6:	88 54 24 1f          	mov    %dl,0x1f(%rsp)
 12659ba:	0f b6 05 1f 6d dd ff 	movzbl -0x2292e1(%rip),%eax        # 103c6e0 <__anon_30440>
 12659c1:	48 8b 9c 24 28 01 00 	mov    0x128(%rsp),%rbx
 12659c8:	00 
 12659c9:	4d 89 ce             	mov    %r9,%r14
 12659cc:	4c 8b ac 24 30 01 00 	mov    0x130(%rsp),%r13
 12659d3:	00 
 12659d4:	4c 8b a4 24 38 01 00 	mov    0x138(%rsp),%r12
 12659db:	00 
 12659dc:	31 f6                	xor    %esi,%esi
 12659de:	0f b6 4c 24 3f       	movzbl 0x3f(%rsp),%ecx
 12659e3:	89 4c 24 48          	mov    %ecx,0x48(%rsp)
 12659e7:	24 0f                	and    $0xf,%al
 12659e9:	88 44 24 1e          	mov    %al,0x1e(%rsp)
 12659ed:	4c 8b bc 24 b0 00 00 	mov    0xb0(%rsp),%r15
 12659f4:	00 
 12659f5:	eb 28                	jmp    1265a1f <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x16f>
 12659f7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 12659fe:	00 00 
 1265a00:	4c 89 e1             	mov    %r12,%rcx
 1265a03:	4d 89 ec             	mov    %r13,%r12
 1265a06:	49 89 dd             	mov    %rbx,%r13
 1265a09:	4c 89 eb             	mov    %r13,%rbx
 1265a0c:	4d 89 e5             	mov    %r12,%r13
 1265a0f:	49 83 c7 60          	add    $0x60,%r15
 1265a13:	49 89 cc             	mov    %rcx,%r12
 1265a16:	49 ff ce             	dec    %r14
 1265a19:	0f 84 10 01 00 00    	je     1265b2f <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x27f>
 1265a1f:	c4 c1 7e 6f 07       	vmovdqu (%r15),%ymm0
 1265a24:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1265a2a:	c4 c1 7c 10 57 40    	vmovups 0x40(%r15),%ymm2
 1265a30:	c5 fc 11 94 24 00 02 	vmovups %ymm2,0x200(%rsp)
 1265a37:	00 00 
 1265a39:	c5 fc 11 8c 24 e0 01 	vmovups %ymm1,0x1e0(%rsp)
 1265a40:	00 00 
 1265a42:	c5 fe 7f 84 24 c0 01 	vmovdqu %ymm0,0x1c0(%rsp)
 1265a49:	00 00 
 1265a4b:	f6 84 24 18 02 00 00 	testb  $0x1,0x218(%rsp)
 1265a52:	01 
 1265a53:	74 ab                	je     1265a00 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x150>
 1265a55:	0f b6 84 24 19 02 00 	movzbl 0x219(%rsp),%eax
 1265a5c:	00 
 1265a5d:	24 03                	and    $0x3,%al
 1265a5f:	3c 02                	cmp    $0x2,%al
 1265a61:	74 9d                	je     1265a00 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x150>
 1265a63:	48 89 74 24 60       	mov    %rsi,0x60(%rsp)
 1265a68:	48 8d bc 24 b0 01 00 	lea    0x1b0(%rsp),%rdi
 1265a6f:	00 
 1265a70:	48 8d b4 24 c0 01 00 	lea    0x1c0(%rsp),%rsi
 1265a77:	00 
 1265a78:	8b 54 24 48          	mov    0x48(%rsp),%edx
 1265a7c:	48 8b 8c 24 e0 00 00 	mov    0xe0(%rsp),%rcx
 1265a83:	00 
 1265a84:	4c 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%r8
 1265a8b:	00 
 1265a8c:	c5 f8 77             	vzeroupper 
 1265a8f:	e8 3c be f9 ff       	call   12018d0 <br.commandWireDistance>
 1265a94:	0f b7 84 24 b8 01 00 	movzwl 0x1b8(%rsp),%eax
 1265a9b:	00 
 1265a9c:	66 85 c0             	test   %ax,%ax
 1265a9f:	0f 85 a7 16 00 00    	jne    126714c <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x189c>
 1265aa5:	48 8b b4 24 b0 01 00 	mov    0x1b0(%rsp),%rsi
 1265aac:	00 
 1265aad:	48 8d 7c 24 6e       	lea    0x6e(%rsp),%rdi
 1265ab2:	48 89 74 24 50       	mov    %rsi,0x50(%rsp)
 1265ab7:	48 8d 94 24 20 01 00 	lea    0x120(%rsp),%rdx
 1265abe:	00 
 1265abf:	e8 dc b7 f9 ff       	call   12012a0 <br.decoder.distance_history.symbolForDistance>
 1265ac4:	0f b6 4c 24 6f       	movzbl 0x6f(%rsp),%ecx
 1265ac9:	48 8b 74 24 60       	mov    0x60(%rsp),%rsi
 1265ace:	48 8d 46 01          	lea    0x1(%rsi),%rax
 1265ad2:	84 c9                	test   %cl,%cl
 1265ad4:	74 1f                	je     1265af5 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x245>
 1265ad6:	0f b6 54 24 6e       	movzbl 0x6e(%rsp),%edx
 1265adb:	80 e2 0f             	and    $0xf,%dl
 1265ade:	3a 54 24 1e          	cmp    0x1e(%rsp),%dl
 1265ae2:	75 11                	jne    1265af5 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x245>
 1265ae4:	4c 89 e1             	mov    %r12,%rcx
 1265ae7:	4d 89 ec             	mov    %r13,%r12
 1265aea:	49 89 dd             	mov    %rbx,%r13
 1265aed:	48 89 c6             	mov    %rax,%rsi
 1265af0:	e9 14 ff ff ff       	jmp    1265a09 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x159>
 1265af5:	84 c9                	test   %cl,%cl
 1265af7:	48 0f 45 f0          	cmovne %rax,%rsi
 1265afb:	48 89 9c 24 20 01 00 	mov    %rbx,0x120(%rsp)
 1265b02:	00 
 1265b03:	4c 89 ac 24 28 01 00 	mov    %r13,0x128(%rsp)
 1265b0a:	00 
 1265b0b:	4c 89 a4 24 30 01 00 	mov    %r12,0x130(%rsp)
 1265b12:	00 
 1265b13:	48 8b 4c 24 50       	mov    0x50(%rsp),%rcx
 1265b18:	48 89 8c 24 38 01 00 	mov    %rcx,0x138(%rsp)
 1265b1f:	00 
 1265b20:	e9 e4 fe ff ff       	jmp    1265a09 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x159>
 1265b25:	c7 44 24 38 00 00 00 	movl   $0x0,0x38(%rsp)
 1265b2c:	00 
 1265b2d:	eb 43                	jmp    1265b72 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x2c2>
 1265b2f:	48 83 fe 40          	cmp    $0x40,%rsi
 1265b33:	0f 93 c0             	setae  %al
 1265b36:	89 44 24 38          	mov    %eax,0x38(%rsp)
 1265b3a:	0f b6 54 24 1f       	movzbl 0x1f(%rsp),%edx
 1265b3f:	44 0f b6 64 24 30    	movzbl 0x30(%rsp),%r12d
 1265b45:	0f b6 bc 24 90 00 00 	movzbl 0x90(%rsp),%edi
 1265b4c:	00 
 1265b4d:	44 0f b6 84 24 60 01 	movzbl 0x160(%rsp),%r8d
 1265b54:	00 00 
 1265b56:	44 0f b6 94 24 40 01 	movzbl 0x140(%rsp),%r10d
 1265b5d:	00 00 
 1265b5f:	0f b6 74 24 78       	movzbl 0x78(%rsp),%esi
 1265b64:	0f b6 4c 24 70       	movzbl 0x70(%rsp),%ecx
 1265b69:	44 0f b6 9c 24 00 01 	movzbl 0x100(%rsp),%r11d
 1265b70:	00 00 
 1265b72:	45 84 db             	test   %r11b,%r11b
 1265b75:	0f 95 c0             	setne  %al
 1265b78:	0f b6 c9             	movzbl %cl,%ecx
 1265b7b:	40 0f b6 f6          	movzbl %sil,%esi
 1265b7f:	0f 45 f1             	cmovne %ecx,%esi
 1265b82:	89 74 24 60          	mov    %esi,0x60(%rsp)
 1265b86:	20 c1                	and    %al,%cl
 1265b88:	89 8c 24 f8 00 00 00 	mov    %ecx,0xf8(%rsp)
 1265b8f:	75 2d                	jne    1265bbe <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x30e>
 1265b91:	80 7c 24 38 00       	cmpb   $0x0,0x38(%rsp)
 1265b96:	75 26                	jne    1265bbe <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x30e>
 1265b98:	41 bf 30 ad 03 01    	mov    $0x103ad30,%r15d
 1265b9e:	41 bd 39 ad 03 01    	mov    $0x103ad39,%r13d
 1265ba4:	b8 38 ad 03 01       	mov    $0x103ad38,%eax
 1265ba9:	48 89 44 24 50       	mov    %rax,0x50(%rsp)
 1265bae:	bb 81 ad 03 01       	mov    $0x103ad81,%ebx
 1265bb3:	41 be 80 ad 03 01    	mov    $0x103ad80,%r14d
 1265bb9:	e9 f0 00 00 00       	jmp    1265cae <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x3fe>
 1265bbe:	4c 8d b4 24 68 04 00 	lea    0x468(%rsp),%r14
 1265bc5:	00 
 1265bc6:	48 8d 9c 24 69 04 00 	lea    0x469(%rsp),%rbx
 1265bcd:	00 
 1265bce:	48 8d 84 24 20 04 00 	lea    0x420(%rsp),%rax
 1265bd5:	00 
 1265bd6:	48 89 44 24 50       	mov    %rax,0x50(%rsp)
 1265bdb:	4c 8d ac 24 21 04 00 	lea    0x421(%rsp),%r13
 1265be2:	00 
 1265be3:	31 c0                	xor    %eax,%eax
 1265be5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 1265bec:	00 00 00 00 
 1265bf0:	48 83 f8 38          	cmp    $0x38,%rax
 1265bf4:	0f 93 84 04 c0 01 00 	setae  0x1c0(%rsp,%rax,1)
 1265bfb:	00 
 1265bfc:	0f 93 84 04 c1 01 00 	setae  0x1c1(%rsp,%rax,1)
 1265c03:	00 
 1265c04:	0f 93 84 04 c2 01 00 	setae  0x1c2(%rsp,%rax,1)
 1265c0b:	00 
 1265c0c:	0f 93 84 04 c3 01 00 	setae  0x1c3(%rsp,%rax,1)
 1265c13:	00 
 1265c14:	0f 93 84 04 c4 01 00 	setae  0x1c4(%rsp,%rax,1)
 1265c1b:	00 
 1265c1c:	0f 93 84 04 c5 01 00 	setae  0x1c5(%rsp,%rax,1)
 1265c23:	00 
 1265c24:	0f 93 84 04 c6 01 00 	setae  0x1c6(%rsp,%rax,1)
 1265c2b:	00 
 1265c2c:	0f 93 84 04 c7 01 00 	setae  0x1c7(%rsp,%rax,1)
 1265c33:	00 
 1265c34:	48 83 c0 08          	add    $0x8,%rax
 1265c38:	48 83 f8 40          	cmp    $0x40,%rax
 1265c3c:	75 b2                	jne    1265bf0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x340>
 1265c3e:	45 84 d2             	test   %r10b,%r10b
 1265c41:	41 0f b6 c0          	movzbl %r8b,%eax
 1265c45:	b9 02 00 00 00       	mov    $0x2,%ecx
 1265c4a:	0f 45 c8             	cmovne %eax,%ecx
 1265c4d:	80 e1 03             	and    $0x3,%cl
 1265c50:	88 8c 24 98 00 00 00 	mov    %cl,0x98(%rsp)
 1265c57:	c5 fe 6f 84 24 c0 01 	vmovdqu 0x1c0(%rsp),%ymm0
 1265c5e:	00 00 
 1265c60:	c5 fc 10 8c 24 e0 01 	vmovups 0x1e0(%rsp),%ymm1
 1265c67:	00 00 
 1265c69:	c5 fe 7f 84 24 22 04 	vmovdqu %ymm0,0x422(%rsp)
 1265c70:	00 00 
 1265c72:	c5 fc 11 8c 24 42 04 	vmovups %ymm1,0x442(%rsp)
 1265c79:	00 00 
 1265c7b:	c6 84 24 a5 00 00 00 	movb   $0x2,0xa5(%rsp)
 1265c82:	02 
 1265c83:	48 c7 84 24 18 04 00 	movq   $0x0,0x418(%rsp)
 1265c8a:	00 00 00 00 00 
 1265c8f:	88 8c 24 20 04 00 00 	mov    %cl,0x420(%rsp)
 1265c96:	c6 84 24 21 04 00 00 	movb   $0x2,0x421(%rsp)
 1265c9d:	02 
 1265c9e:	c6 84 24 68 04 00 00 	movb   $0x1,0x468(%rsp)
 1265ca5:	01 
 1265ca6:	4c 8d bc 24 18 04 00 	lea    0x418(%rsp),%r15
 1265cad:	00 
 1265cae:	c5 fc 10 84 24 f0 03 	vmovups 0x3f0(%rsp),%ymm0
 1265cb5:	00 00 
 1265cb7:	c5 fc 11 84 24 28 07 	vmovups %ymm0,0x728(%rsp)
 1265cbe:	00 00 
 1265cc0:	40 80 e7 01          	and    $0x1,%dil
 1265cc4:	40 88 bc 24 29 09 00 	mov    %dil,0x929(%rsp)
 1265ccb:	00 
 1265ccc:	48 c7 84 24 18 07 00 	movq   $0x0,0x718(%rsp)
 1265cd3:	00 00 00 00 00 
 1265cd8:	8b 44 24 38          	mov    0x38(%rsp),%eax
 1265cdc:	88 84 24 2d 09 00 00 	mov    %al,0x92d(%rsp)
 1265ce3:	c6 84 24 2c 09 00 00 	movb   $0x0,0x92c(%rsp)
 1265cea:	00 
 1265ceb:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 1265cf0:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 1265cf6:	c5 fc 11 84 24 48 07 	vmovups %ymm0,0x748(%rsp)
 1265cfd:	00 00 
 1265cff:	c5 fc 11 8c 24 68 07 	vmovups %ymm1,0x768(%rsp)
 1265d06:	00 00 
 1265d08:	c4 c1 7c 10 47 38    	vmovups 0x38(%r15),%ymm0
 1265d0e:	c5 fc 11 84 24 80 07 	vmovups %ymm0,0x780(%rsp)
 1265d15:	00 00 
 1265d17:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 1265d1b:	c5 fc 11 84 24 f0 08 	vmovups %ymm0,0x8f0(%rsp)
 1265d22:	00 00 
 1265d24:	c5 fc 11 84 24 e0 08 	vmovups %ymm0,0x8e0(%rsp)
 1265d2b:	00 00 
 1265d2d:	c5 fc 11 84 24 c0 08 	vmovups %ymm0,0x8c0(%rsp)
 1265d34:	00 00 
 1265d36:	c5 fc 11 84 24 a0 08 	vmovups %ymm0,0x8a0(%rsp)
 1265d3d:	00 00 
 1265d3f:	c5 fc 11 84 24 80 08 	vmovups %ymm0,0x880(%rsp)
 1265d46:	00 00 
 1265d48:	c5 fc 11 84 24 60 08 	vmovups %ymm0,0x860(%rsp)
 1265d4f:	00 00 
 1265d51:	c5 fc 11 84 24 40 08 	vmovups %ymm0,0x840(%rsp)
 1265d58:	00 00 
 1265d5a:	c5 fc 11 84 24 20 08 	vmovups %ymm0,0x820(%rsp)
 1265d61:	00 00 
 1265d63:	c5 fc 11 84 24 00 08 	vmovups %ymm0,0x800(%rsp)
 1265d6a:	00 00 
 1265d6c:	c5 fc 11 84 24 e0 07 	vmovups %ymm0,0x7e0(%rsp)
 1265d73:	00 00 
 1265d75:	c5 fc 11 84 24 c0 07 	vmovups %ymm0,0x7c0(%rsp)
 1265d7c:	00 00 
 1265d7e:	c5 fc 11 84 24 a0 07 	vmovups %ymm0,0x7a0(%rsp)
 1265d85:	00 00 
 1265d87:	c6 84 24 20 09 00 00 	movb   $0x38,0x920(%rsp)
 1265d8e:	38 
 1265d8f:	c6 84 24 28 09 00 00 	movb   $0x0,0x928(%rsp)
 1265d96:	00 
 1265d97:	0f b7 05 92 51 dd ff 	movzwl -0x22ae6e(%rip),%eax        # 103af30 <__anon_29470>
 1265d9e:	66 89 84 24 22 09 00 	mov    %ax,0x922(%rsp)
 1265da5:	00 
 1265da6:	80 e2 1f             	and    $0x1f,%dl
 1265da9:	88 54 24 1f          	mov    %dl,0x1f(%rsp)
 1265dad:	88 94 24 21 09 00 00 	mov    %dl,0x921(%rsp)
 1265db4:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 1265dbb:	00 
 1265dbc:	48 89 84 24 08 07 00 	mov    %rax,0x708(%rsp)
 1265dc3:	00 
 1265dc4:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 1265dcb:	00 
 1265dcc:	48 89 84 24 10 07 00 	mov    %rax,0x710(%rsp)
 1265dd3:	00 
 1265dd4:	c7 84 24 24 09 00 00 	movl   $0x1000101,0x924(%rsp)
 1265ddb:	01 01 00 01 
 1265ddf:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 1265de6:	00 
 1265de7:	48 89 84 24 18 09 00 	mov    %rax,0x918(%rsp)
 1265dee:	00 
 1265def:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 1265df6:	00 
 1265df7:	48 89 84 24 10 09 00 	mov    %rax,0x910(%rsp)
 1265dfe:	00 
 1265dff:	66 c7 84 24 2a 09 00 	movw   $0x0,0x92a(%rsp)
 1265e06:	00 00 00 
 1265e09:	48 c7 84 24 20 07 00 	movq   $0x0,0x720(%rsp)
 1265e10:	00 00 00 00 00 
 1265e15:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1265e19:	c5 fc 10 40 70       	vmovups 0x70(%rax),%ymm0
 1265e1e:	c5 fc 11 84 24 e0 04 	vmovups %ymm0,0x4e0(%rsp)
 1265e25:	00 00 
 1265e27:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1265e2b:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1265e30:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1265e35:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 1265e3a:	c5 fc 11 9c 24 d0 04 	vmovups %ymm3,0x4d0(%rsp)
 1265e41:	00 00 
 1265e43:	c5 fc 11 94 24 b0 04 	vmovups %ymm2,0x4b0(%rsp)
 1265e4a:	00 00 
 1265e4c:	c5 fc 11 8c 24 90 04 	vmovups %ymm1,0x490(%rsp)
 1265e53:	00 00 
 1265e55:	c5 fc 11 84 24 70 04 	vmovups %ymm0,0x470(%rsp)
 1265e5c:	00 00 
 1265e5e:	c5 fc 10 00          	vmovups (%rax),%ymm0
 1265e62:	c5 fc 10 48 20       	vmovups 0x20(%rax),%ymm1
 1265e67:	c5 fc 10 50 40       	vmovups 0x40(%rax),%ymm2
 1265e6c:	c5 fc 10 58 60       	vmovups 0x60(%rax),%ymm3
 1265e71:	c5 fc 11 84 24 50 05 	vmovups %ymm0,0x550(%rsp)
 1265e78:	00 00 
 1265e7a:	c5 fc 11 8c 24 70 05 	vmovups %ymm1,0x570(%rsp)
 1265e81:	00 00 
 1265e83:	c5 fc 11 94 24 90 05 	vmovups %ymm2,0x590(%rsp)
 1265e8a:	00 00 
 1265e8c:	c5 fc 11 9c 24 b0 05 	vmovups %ymm3,0x5b0(%rsp)
 1265e93:	00 00 
 1265e95:	c5 fe 6f 40 70       	vmovdqu 0x70(%rax),%ymm0
 1265e9a:	c5 fe 7f 84 24 c0 05 	vmovdqu %ymm0,0x5c0(%rsp)
 1265ea1:	00 00 
 1265ea3:	48 8d 84 24 08 07 00 	lea    0x708(%rsp),%rax
 1265eaa:	00 
 1265eab:	4c 8d 94 24 50 05 00 	lea    0x550(%rsp),%r10
 1265eb2:	00 
 1265eb3:	48 8d bc 24 a8 03 00 	lea    0x3a8(%rsp),%rdi
 1265eba:	00 
 1265ebb:	48 8b 74 24 40       	mov    0x40(%rsp),%rsi
 1265ec0:	48 8b 94 24 d0 00 00 	mov    0xd0(%rsp),%rdx
 1265ec7:	00 
 1265ec8:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1265ecf:	00 
 1265ed0:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 1265ed7:	00 
 1265ed8:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 1265edf:	00 
 1265ee0:	50                   	push   %rax
 1265ee1:	41 52                	push   %r10
 1265ee3:	c5 f8 77             	vzeroupper 
 1265ee6:	e8 35 12 f5 ff       	call   11b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>
 1265eeb:	48 83 c4 10          	add    $0x10,%rsp
 1265eef:	0f b7 84 24 b8 03 00 	movzwl 0x3b8(%rsp),%eax
 1265ef6:	00 
 1265ef7:	66 85 c0             	test   %ax,%ax
 1265efa:	0f 85 4c 12 00 00    	jne    126714c <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x189c>
 1265f00:	48 8b 84 24 a8 03 00 	mov    0x3a8(%rsp),%rax
 1265f07:	00 
 1265f08:	48 89 44 24 70       	mov    %rax,0x70(%rsp)
 1265f0d:	48 8b 84 24 b0 03 00 	mov    0x3b0(%rsp),%rax
 1265f14:	00 
 1265f15:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 1265f1a:	c5 fc 10 84 24 50 05 	vmovups 0x550(%rsp),%ymm0
 1265f21:	00 00 
 1265f23:	c5 fc 10 8c 24 70 05 	vmovups 0x570(%rsp),%ymm1
 1265f2a:	00 00 
 1265f2c:	c5 fc 10 94 24 90 05 	vmovups 0x590(%rsp),%ymm2
 1265f33:	00 00 
 1265f35:	c5 fc 10 9c 24 b0 05 	vmovups 0x5b0(%rsp),%ymm3
 1265f3c:	00 00 
 1265f3e:	c5 fc 11 84 24 20 02 	vmovups %ymm0,0x220(%rsp)
 1265f45:	00 00 
 1265f47:	c5 fc 11 8c 24 40 02 	vmovups %ymm1,0x240(%rsp)
 1265f4e:	00 00 
 1265f50:	c5 fc 11 94 24 60 02 	vmovups %ymm2,0x260(%rsp)
 1265f57:	00 00 
 1265f59:	c5 fc 11 9c 24 80 02 	vmovups %ymm3,0x280(%rsp)
 1265f60:	00 00 
 1265f62:	c5 fc 10 84 24 c0 05 	vmovups 0x5c0(%rsp),%ymm0
 1265f69:	00 00 
 1265f6b:	c5 fc 11 84 24 90 02 	vmovups %ymm0,0x290(%rsp)
 1265f72:	00 00 
 1265f74:	49 8b 07             	mov    (%r15),%rax
 1265f77:	48 89 44 24 78       	mov    %rax,0x78(%rsp)
 1265f7c:	48 8b 44 24 50       	mov    0x50(%rsp),%rax
 1265f81:	0f b6 00             	movzbl (%rax),%eax
 1265f84:	88 44 24 48          	mov    %al,0x48(%rsp)
 1265f88:	41 0f b6 45 00       	movzbl 0x0(%r13),%eax
 1265f8d:	88 44 24 1e          	mov    %al,0x1e(%rsp)
 1265f91:	c4 c1 7c 10 45 01    	vmovups 0x1(%r13),%ymm0
 1265f97:	c5 fc 29 84 24 80 01 	vmovaps %ymm0,0x180(%rsp)
 1265f9e:	00 00 
 1265fa0:	c4 c1 7e 6f 45 21    	vmovdqu 0x21(%r13),%ymm0
 1265fa6:	c5 fd 7f 84 24 00 01 	vmovdqa %ymm0,0x100(%rsp)
 1265fad:	00 00 
 1265faf:	41 0f b7 45 45       	movzwl 0x45(%r13),%eax
 1265fb4:	66 89 44 24 2c       	mov    %ax,0x2c(%rsp)
 1265fb9:	41 8b 45 41          	mov    0x41(%r13),%eax
 1265fbd:	89 44 24 28          	mov    %eax,0x28(%rsp)
 1265fc1:	45 0f b6 1e          	movzbl (%r14),%r11d
 1265fc5:	8b 03                	mov    (%rbx),%eax
 1265fc7:	8b 4b 03             	mov    0x3(%rbx),%ecx
 1265fca:	89 84 24 88 00 00 00 	mov    %eax,0x88(%rsp)
 1265fd1:	89 8c 24 8b 00 00 00 	mov    %ecx,0x8b(%rsp)
 1265fd8:	45 84 db             	test   %r11b,%r11b
 1265fdb:	74 1e                	je     1265ffb <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x74b>
 1265fdd:	4c 8d b4 24 fe 00 00 	lea    0xfe(%rsp),%r14
 1265fe4:	00 
 1265fe5:	4c 89 f7             	mov    %r14,%rdi
 1265fe8:	4c 89 fe             	mov    %r15,%rsi
 1265feb:	44 89 db             	mov    %r11d,%ebx
 1265fee:	c5 f8 77             	vzeroupper 
 1265ff1:	e8 7a a2 fc ff       	call   1230270 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 1265ff6:	41 89 db             	mov    %ebx,%r11d
 1265ff9:	eb 06                	jmp    1266001 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x751>
 1265ffb:	41 be 8a 38 08 01    	mov    $0x108388a,%r14d
 1266001:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 1266008:	00 
 1266009:	45 0f b7 36          	movzwl (%r14),%r14d
 126600d:	44 22 64 24 60       	and    0x60(%rsp),%r12b
 1266012:	41 f6 c4 01          	test   $0x1,%r12b
 1266016:	66 44 89 74 24 26    	mov    %r14w,0x26(%rsp)
 126601c:	74 73                	je     1266091 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x7e1>
 126601e:	45 89 dc             	mov    %r11d,%r12d
 1266021:	48 8d bc 24 90 0f 00 	lea    0xf90(%rsp),%rdi
 1266028:	00 
 1266029:	48 8b 74 24 40       	mov    0x40(%rsp),%rsi
 126602e:	48 8b 94 24 d0 00 00 	mov    0xd0(%rsp),%rdx
 1266035:	00 
 1266036:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 126603d:	00 
 126603e:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 1266045:	00 
 1266046:	c5 f8 77             	vzeroupper 
 1266049:	e8 e2 e9 ff ff       	call   1264a30 <br.encoder.literal_context_split.chooseProposals>
 126604e:	0f b7 9c 24 98 10 00 	movzwl 0x1098(%rsp),%ebx
 1266055:	00 
 1266056:	66 85 db             	test   %bx,%bx
 1266059:	0f 85 fe 10 00 00    	jne    126715d <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x18ad>
 126605f:	4c 8d ac 24 e0 0e 00 	lea    0xee0(%rsp),%r13
 1266066:	00 
 1266067:	4c 8d bc 24 38 0f 00 	lea    0xf38(%rsp),%r15
 126606e:	00 
 126606f:	4c 8d b4 24 88 0e 00 	lea    0xe88(%rsp),%r14
 1266076:	00 
 1266077:	48 8d b4 24 90 0f 00 	lea    0xf90(%rsp),%rsi
 126607e:	00 
 126607f:	ba 08 01 00 00       	mov    $0x108,%edx
 1266084:	4c 89 f7             	mov    %r14,%rdi
 1266087:	e8 d4 96 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 126608c:	45 89 e3             	mov    %r12d,%r11d
 126608f:	eb 12                	jmp    12660a3 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x7f3>
 1266091:	41 be 30 37 09 01    	mov    $0x1093730,%r14d
 1266097:	41 bf e0 37 09 01    	mov    $0x10937e0,%r15d
 126609d:	41 bd 88 37 09 01    	mov    $0x1093788,%r13d
 12660a3:	48 8b 5c 24 70       	mov    0x70(%rsp),%rbx
 12660a8:	41 b8 38 38 09 01    	mov    $0x1093838,%r8d
 12660ae:	f6 44 24 60 01       	testb  $0x1,0x60(%rsp)
 12660b3:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 12660ba:	00 00 
 12660bc:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 12660c3:	00 00 
 12660c5:	0f 84 8d 00 00 00    	je     1266158 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x8a8>
 12660cb:	c4 c1 7c 10 06       	vmovups (%r14),%ymm0
 12660d0:	c4 c1 7c 10 4e 38    	vmovups 0x38(%r14),%ymm1
 12660d6:	c5 fc 11 8c 24 b8 0d 	vmovups %ymm1,0xdb8(%rsp)
 12660dd:	00 00 
 12660df:	c4 c1 7c 10 4e 20    	vmovups 0x20(%r14),%ymm1
 12660e5:	c5 fc 11 8c 24 a0 0d 	vmovups %ymm1,0xda0(%rsp)
 12660ec:	00 00 
 12660ee:	c5 fc 11 84 24 80 0d 	vmovups %ymm0,0xd80(%rsp)
 12660f5:	00 00 
 12660f7:	c4 c1 7c 10 45 00    	vmovups 0x0(%r13),%ymm0
 12660fd:	c4 c1 7c 10 4d 20    	vmovups 0x20(%r13),%ymm1
 1266103:	c4 c1 7c 10 55 38    	vmovups 0x38(%r13),%ymm2
 1266109:	c5 fc 11 84 24 d8 0d 	vmovups %ymm0,0xdd8(%rsp)
 1266110:	00 00 
 1266112:	c5 fc 11 8c 24 f8 0d 	vmovups %ymm1,0xdf8(%rsp)
 1266119:	00 00 
 126611b:	c5 fc 11 94 24 10 0e 	vmovups %ymm2,0xe10(%rsp)
 1266122:	00 00 
 1266124:	c4 c1 7c 10 07       	vmovups (%r15),%ymm0
 1266129:	c4 c1 7c 10 4f 20    	vmovups 0x20(%r15),%ymm1
 126612f:	c5 fc 11 84 24 30 0e 	vmovups %ymm0,0xe30(%rsp)
 1266136:	00 00 
 1266138:	c4 c1 7e 6f 47 38    	vmovdqu 0x38(%r15),%ymm0
 126613e:	c5 fc 11 8c 24 50 0e 	vmovups %ymm1,0xe50(%rsp)
 1266145:	00 00 
 1266147:	c5 fe 7f 84 24 68 0e 	vmovdqu %ymm0,0xe68(%rsp)
 126614e:	00 00 
 1266150:	4c 8d 84 24 80 0d 00 	lea    0xd80(%rsp),%r8
 1266157:	00 
 1266158:	45 31 ed             	xor    %r13d,%r13d
 126615b:	48 c7 84 24 c8 00 00 	movq   $0x0,0xc8(%rsp)
 1266162:	00 00 00 00 00 
 1266167:	45 31 ff             	xor    %r15d,%r15d
 126616a:	4c 89 84 24 90 00 00 	mov    %r8,0x90(%rsp)
 1266171:	00 
 1266172:	e9 bf 00 00 00       	jmp    1266236 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x986>
 1266177:	4c 8b 7c 24 50       	mov    0x50(%rsp),%r15
 126617c:	49 83 ff 02          	cmp    $0x2,%r15
 1266180:	0f 87 ae 0e 00 00    	ja     1267034 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x1784>
 1266186:	4b 8d 04 bf          	lea    (%r15,%r15,4),%rax
 126618a:	48 c1 e0 04          	shl    $0x4,%rax
 126618e:	48 8b 4c 24 60       	mov    0x60(%rsp),%rcx
 1266193:	48 89 8c 04 b8 02 00 	mov    %rcx,0x2b8(%rsp,%rax,1)
 126619a:	00 
 126619b:	44 88 b4 04 c0 02 00 	mov    %r14b,0x2c0(%rsp,%rax,1)
 12661a2:	00 
 12661a3:	44 88 a4 04 c1 02 00 	mov    %r12b,0x2c1(%rsp,%rax,1)
 12661aa:	00 
 12661ab:	c5 fc 28 84 24 60 01 	vmovaps 0x160(%rsp),%ymm0
 12661b2:	00 00 
 12661b4:	c5 fc 11 84 04 c2 02 	vmovups %ymm0,0x2c2(%rsp,%rax,1)
 12661bb:	00 00 
 12661bd:	c5 fd 6f 84 24 40 01 	vmovdqa 0x140(%rsp),%ymm0
 12661c4:	00 00 
 12661c6:	c5 fe 7f 84 04 e2 02 	vmovdqu %ymm0,0x2e2(%rsp,%rax,1)
 12661cd:	00 00 
 12661cf:	8b 8c 24 80 00 00 00 	mov    0x80(%rsp),%ecx
 12661d6:	89 8c 04 02 03 00 00 	mov    %ecx,0x302(%rsp,%rax,1)
 12661dd:	0f b7 8c 24 84 00 00 	movzwl 0x84(%rsp),%ecx
 12661e4:	00 
 12661e5:	66 89 8c 04 06 03 00 	mov    %cx,0x306(%rsp,%rax,1)
 12661ec:	00 
 12661ed:	49 ff c7             	inc    %r15
 12661f0:	41 89 db             	mov    %ebx,%r11d
 12661f3:	48 8b 5c 24 70       	mov    0x70(%rsp),%rbx
 12661f8:	c5 fd 6f a4 24 00 01 	vmovdqa 0x100(%rsp),%ymm4
 12661ff:	00 00 
 1266201:	c5 fd 6f ac 24 80 01 	vmovdqa 0x180(%rsp),%ymm5
 1266208:	00 00 
 126620a:	4c 8b 84 24 90 00 00 	mov    0x90(%rsp),%r8
 1266211:	00 
 1266212:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 1266219:	1f 84 00 00 00 00 00 
 1266220:	4d 85 ed             	test   %r13,%r13
 1266223:	0f 84 b7 00 00 00    	je     12662e0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xa30>
 1266229:	49 ff c5             	inc    %r13
 126622c:	49 83 fd 03          	cmp    $0x3,%r13
 1266230:	0f 84 f2 07 00 00    	je     1266a28 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x1178>
 1266236:	49 6b c5 58          	imul   $0x58,%r13,%rax
 126623a:	41 80 7c 00 50 00    	cmpb   $0x0,0x50(%r8,%rax,1)
 1266240:	74 de                	je     1266220 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x970>
 1266242:	49 8b 0c 00          	mov    (%r8,%rax,1),%rcx
 1266246:	48 89 4c 24 60       	mov    %rcx,0x60(%rsp)
 126624b:	45 0f b6 74 00 08    	movzbl 0x8(%r8,%rax,1),%r14d
 1266251:	45 0f b6 64 00 09    	movzbl 0x9(%r8,%rax,1),%r12d
 1266257:	c4 c1 7e 6f 74 00 0a 	vmovdqu 0xa(%r8,%rax,1),%ymm6
 126625e:	c4 c1 7e 6f 7c 00 2a 	vmovdqu 0x2a(%r8,%rax,1),%ymm7
 1266265:	49 8d 44 00 4a       	lea    0x4a(%r8,%rax,1),%rax
 126626a:	0f b7 48 04          	movzwl 0x4(%rax),%ecx
 126626e:	66 89 8c 24 84 00 00 	mov    %cx,0x84(%rsp)
 1266275:	00 
 1266276:	8b 08                	mov    (%rax),%ecx
 1266278:	89 8c 24 80 00 00 00 	mov    %ecx,0x80(%rsp)
 126627f:	45 84 db             	test   %r11b,%r11b
 1266282:	0f 84 a8 00 00 00    	je     1266330 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xa80>
 1266288:	44 89 f2             	mov    %r14d,%edx
 126628b:	80 e2 03             	and    $0x3,%dl
 126628e:	0f b6 74 24 48       	movzbl 0x48(%rsp),%esi
 1266293:	40 80 e6 03          	and    $0x3,%sil
 1266297:	31 c9                	xor    %ecx,%ecx
 1266299:	40 38 f2             	cmp    %sil,%dl
 126629c:	75 2e                	jne    12662cc <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xa1c>
 126629e:	0f b6 54 24 1e       	movzbl 0x1e(%rsp),%edx
 12662a3:	80 e2 7f             	and    $0x7f,%dl
 12662a6:	44 89 e6             	mov    %r12d,%esi
 12662a9:	40 80 e6 7f          	and    $0x7f,%sil
 12662ad:	40 38 d6             	cmp    %dl,%sil
 12662b0:	75 1a                	jne    12662cc <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xa1c>
 12662b2:	c5 cd 74 c5          	vpcmpeqb %ymm5,%ymm6,%ymm0
 12662b6:	c5 fd d7 d0          	vpmovmskb %ymm0,%edx
 12662ba:	f7 d2                	not    %edx
 12662bc:	85 d2                	test   %edx,%edx
 12662be:	75 0c                	jne    12662cc <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xa1c>
 12662c0:	c5 c5 ef c4          	vpxor  %ymm4,%ymm7,%ymm0
 12662c4:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 12662c9:	0f 94 c1             	sete   %cl
 12662cc:	4d 85 ff             	test   %r15,%r15
 12662cf:	75 66                	jne    1266337 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xa87>
 12662d1:	e9 7f 00 00 00       	jmp    1266355 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xaa5>
 12662d6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 12662dd:	00 00 00 
 12662e0:	0f b7 44 24 2c       	movzwl 0x2c(%rsp),%eax
 12662e5:	66 89 84 24 a0 00 00 	mov    %ax,0xa0(%rsp)
 12662ec:	00 
 12662ed:	8b 44 24 28          	mov    0x28(%rsp),%eax
 12662f1:	89 84 24 9c 00 00 00 	mov    %eax,0x9c(%rsp)
 12662f8:	45 84 db             	test   %r11b,%r11b
 12662fb:	0f 84 80 05 00 00    	je     1266881 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xfd1>
 1266301:	4c 89 7c 24 50       	mov    %r15,0x50(%rsp)
 1266306:	44 0f b6 64 24 1e    	movzbl 0x1e(%rsp),%r12d
 126630c:	4c 8b 7c 24 30       	mov    0x30(%rsp),%r15
 1266311:	48 8b 44 24 78       	mov    0x78(%rsp),%rax
 1266316:	48 89 44 24 60       	mov    %rax,0x60(%rsp)
 126631b:	44 0f b6 74 24 48    	movzbl 0x48(%rsp),%r14d
 1266321:	e9 f5 05 00 00       	jmp    126691b <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x106b>
 1266326:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 126632d:	00 00 00 
 1266330:	31 c9                	xor    %ecx,%ecx
 1266332:	4d 85 ff             	test   %r15,%r15
 1266335:	74 1e                	je     1266355 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xaa5>
 1266337:	49 83 ff 01          	cmp    $0x1,%r15
 126633b:	0f 85 b7 03 00 00    	jne    12666f8 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xe48>
 1266341:	31 d2                	xor    %edx,%edx
 1266343:	41 f6 c7 01          	test   $0x1,%r15b
 1266347:	4c 8b 84 24 90 00 00 	mov    0x90(%rsp),%r8
 126634e:	00 
 126634f:	0f 85 84 04 00 00    	jne    12667d9 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xf29>
 1266355:	f6 c1 01             	test   $0x1,%cl
 1266358:	0f 85 c2 fe ff ff    	jne    1266220 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x970>
 126635e:	c5 fd 7f ac 24 80 01 	vmovdqa %ymm5,0x180(%rsp)
 1266365:	00 00 
 1266367:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 126636e:	00 00 
 1266370:	48 89 5c 24 70       	mov    %rbx,0x70(%rsp)
 1266375:	4c 89 7c 24 50       	mov    %r15,0x50(%rsp)
 126637a:	44 89 db             	mov    %r11d,%ebx
 126637d:	c5 fc 10 84 24 e0 04 	vmovups 0x4e0(%rsp),%ymm0
 1266384:	00 00 
 1266386:	c5 fc 11 84 24 50 06 	vmovups %ymm0,0x650(%rsp)
 126638d:	00 00 
 126638f:	c5 fc 10 84 24 70 04 	vmovups 0x470(%rsp),%ymm0
 1266396:	00 00 
 1266398:	c5 fc 10 8c 24 90 04 	vmovups 0x490(%rsp),%ymm1
 126639f:	00 00 
 12663a1:	c5 fc 10 94 24 b0 04 	vmovups 0x4b0(%rsp),%ymm2
 12663a8:	00 00 
 12663aa:	c5 fc 10 9c 24 d0 04 	vmovups 0x4d0(%rsp),%ymm3
 12663b1:	00 00 
 12663b3:	c5 fc 11 9c 24 40 06 	vmovups %ymm3,0x640(%rsp)
 12663ba:	00 00 
 12663bc:	c5 fc 11 94 24 20 06 	vmovups %ymm2,0x620(%rsp)
 12663c3:	00 00 
 12663c5:	c5 fc 11 8c 24 00 06 	vmovups %ymm1,0x600(%rsp)
 12663cc:	00 00 
 12663ce:	c5 fc 11 84 24 e0 05 	vmovups %ymm0,0x5e0(%rsp)
 12663d5:	00 00 
 12663d7:	0f b6 4c 24 20       	movzbl 0x20(%rsp),%ecx
 12663dc:	c5 fe 6f 84 24 f0 03 	vmovdqu 0x3f0(%rsp),%ymm0
 12663e3:	00 00 
 12663e5:	48 8d b4 24 e2 0b 00 	lea    0xbe2(%rsp),%rsi
 12663ec:	00 
 12663ed:	c5 fe 7f 46 96       	vmovdqu %ymm0,-0x6a(%rsi)
 12663f2:	0f b7 50 04          	movzwl 0x4(%rax),%edx
 12663f6:	66 89 56 04          	mov    %dx,0x4(%rsi)
 12663fa:	8b 00                	mov    (%rax),%eax
 12663fc:	89 06                	mov    %eax,(%rsi)
 12663fe:	88 8c 24 79 0d 00 00 	mov    %cl,0xd79(%rsp)
 1266405:	48 c7 84 24 68 0b 00 	movq   $0x0,0xb68(%rsp)
 126640c:	00 00 00 00 00 
 1266411:	8b 44 24 38          	mov    0x38(%rsp),%eax
 1266415:	88 84 24 7d 0d 00 00 	mov    %al,0xd7d(%rsp)
 126641c:	c6 84 24 7c 0d 00 00 	movb   $0x0,0xd7c(%rsp)
 1266423:	00 
 1266424:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 1266429:	48 89 84 24 98 0b 00 	mov    %rax,0xb98(%rsp)
 1266430:	00 
 1266431:	44 88 b4 24 a0 0b 00 	mov    %r14b,0xba0(%rsp)
 1266438:	00 
 1266439:	44 88 a4 24 a1 0b 00 	mov    %r12b,0xba1(%rsp)
 1266440:	00 
 1266441:	c5 fd 7f b4 24 60 01 	vmovdqa %ymm6,0x160(%rsp)
 1266448:	00 00 
 126644a:	c5 fe 7f b4 24 a2 0b 	vmovdqu %ymm6,0xba2(%rsp)
 1266451:	00 00 
 1266453:	c5 fd 7f bc 24 40 01 	vmovdqa %ymm7,0x140(%rsp)
 126645a:	00 00 
 126645c:	c5 fe 7f bc 24 c2 0b 	vmovdqu %ymm7,0xbc2(%rsp)
 1266463:	00 00 
 1266465:	c6 84 24 e8 0b 00 00 	movb   $0x1,0xbe8(%rsp)
 126646c:	01 
 126646d:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1266471:	c5 fe 7f 86 5e 01 00 	vmovdqu %ymm0,0x15e(%rsi)
 1266478:	00 
 1266479:	c5 fe 7f 86 4e 01 00 	vmovdqu %ymm0,0x14e(%rsi)
 1266480:	00 
 1266481:	c5 fe 7f 86 2e 01 00 	vmovdqu %ymm0,0x12e(%rsi)
 1266488:	00 
 1266489:	c5 fe 7f 86 0e 01 00 	vmovdqu %ymm0,0x10e(%rsi)
 1266490:	00 
 1266491:	c5 fe 7f 86 ee 00 00 	vmovdqu %ymm0,0xee(%rsi)
 1266498:	00 
 1266499:	c5 fe 7f 86 ce 00 00 	vmovdqu %ymm0,0xce(%rsi)
 12664a0:	00 
 12664a1:	c5 fe 7f 86 ae 00 00 	vmovdqu %ymm0,0xae(%rsi)
 12664a8:	00 
 12664a9:	c5 fe 7f 86 8e 00 00 	vmovdqu %ymm0,0x8e(%rsi)
 12664b0:	00 
 12664b1:	c5 fe 7f 46 6e       	vmovdqu %ymm0,0x6e(%rsi)
 12664b6:	c5 fe 7f 46 4e       	vmovdqu %ymm0,0x4e(%rsi)
 12664bb:	c5 fe 7f 46 2e       	vmovdqu %ymm0,0x2e(%rsi)
 12664c0:	c5 fe 7f 46 0e       	vmovdqu %ymm0,0xe(%rsi)
 12664c5:	c6 84 24 70 0d 00 00 	movb   $0x38,0xd70(%rsp)
 12664cc:	38 
 12664cd:	c6 84 24 78 0d 00 00 	movb   $0x0,0xd78(%rsp)
 12664d4:	00 
 12664d5:	0f b7 05 54 4a dd ff 	movzwl -0x22b5ac(%rip),%eax        # 103af30 <__anon_29470>
 12664dc:	66 89 84 24 72 0d 00 	mov    %ax,0xd72(%rsp)
 12664e3:	00 
 12664e4:	0f b6 44 24 1f       	movzbl 0x1f(%rsp),%eax
 12664e9:	88 84 24 71 0d 00 00 	mov    %al,0xd71(%rsp)
 12664f0:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 12664f7:	00 
 12664f8:	48 89 84 24 58 0b 00 	mov    %rax,0xb58(%rsp)
 12664ff:	00 
 1266500:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 1266507:	00 
 1266508:	48 89 84 24 60 0b 00 	mov    %rax,0xb60(%rsp)
 126650f:	00 
 1266510:	c7 84 24 74 0d 00 00 	movl   $0x1000101,0xd74(%rsp)
 1266517:	01 01 00 01 
 126651b:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 1266522:	00 
 1266523:	48 89 84 24 68 0d 00 	mov    %rax,0xd68(%rsp)
 126652a:	00 
 126652b:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 1266532:	00 
 1266533:	48 89 84 24 60 0d 00 	mov    %rax,0xd60(%rsp)
 126653a:	00 
 126653b:	66 c7 84 24 7a 0d 00 	movw   $0x0,0xd7a(%rsp)
 1266542:	00 00 00 
 1266545:	48 c7 84 24 70 0b 00 	movq   $0x0,0xb70(%rsp)
 126654c:	00 00 00 00 00 
 1266551:	48 8d bc 24 c0 03 00 	lea    0x3c0(%rsp),%rdi
 1266558:	00 
 1266559:	48 8b 74 24 40       	mov    0x40(%rsp),%rsi
 126655e:	48 8b 94 24 d0 00 00 	mov    0xd0(%rsp),%rdx
 1266565:	00 
 1266566:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 126656d:	00 
 126656e:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 1266575:	00 
 1266576:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 126657d:	00 
 126657e:	48 8d 84 24 58 0b 00 	lea    0xb58(%rsp),%rax
 1266585:	00 
 1266586:	50                   	push   %rax
 1266587:	48 8d 84 24 e8 05 00 	lea    0x5e8(%rsp),%rax
 126658e:	00 
 126658f:	50                   	push   %rax
 1266590:	c5 f8 77             	vzeroupper 
 1266593:	e8 88 0b f5 ff       	call   11b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>
 1266598:	48 83 c4 10          	add    $0x10,%rsp
 126659c:	44 0f b7 bc 24 d0 03 	movzwl 0x3d0(%rsp),%r15d
 12665a3:	00 00 
 12665a5:	66 45 85 ff          	test   %r15w,%r15w
 12665a9:	0f 85 67 0b 00 00    	jne    1267116 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x1866>
 12665af:	48 8b b4 24 c0 03 00 	mov    0x3c0(%rsp),%rsi
 12665b6:	00 
 12665b7:	4c 8b bc 24 c8 03 00 	mov    0x3c8(%rsp),%r15
 12665be:	00 
 12665bf:	48 8b 54 24 30       	mov    0x30(%rsp),%rdx
 12665c4:	49 39 d7             	cmp    %rdx,%r15
 12665c7:	0f 83 89 02 00 00    	jae    1266856 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xfa6>
 12665cd:	48 89 b4 24 c0 00 00 	mov    %rsi,0xc0(%rsp)
 12665d4:	00 
 12665d5:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 12665da:	48 8b 38             	mov    (%rax),%rdi
 12665dd:	48 8b 40 08          	mov    0x8(%rax),%rax
 12665e1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 12665e5:	48 8b 74 24 70       	mov    0x70(%rsp),%rsi
 12665ea:	31 c9                	xor    %ecx,%ecx
 12665ec:	4c 89 44 24 30       	mov    %r8,0x30(%rsp)
 12665f1:	ff 50 18             	call   *0x18(%rax)
 12665f4:	c5 fc 10 84 24 50 06 	vmovups 0x650(%rsp),%ymm0
 12665fb:	00 00 
 12665fd:	c5 fc 11 84 24 90 02 	vmovups %ymm0,0x290(%rsp)
 1266604:	00 00 
 1266606:	c5 fe 6f 84 24 e0 05 	vmovdqu 0x5e0(%rsp),%ymm0
 126660d:	00 00 
 126660f:	c5 fc 10 8c 24 00 06 	vmovups 0x600(%rsp),%ymm1
 1266616:	00 00 
 1266618:	c5 fc 10 94 24 20 06 	vmovups 0x620(%rsp),%ymm2
 126661f:	00 00 
 1266621:	c5 fc 10 9c 24 40 06 	vmovups 0x640(%rsp),%ymm3
 1266628:	00 00 
 126662a:	c5 fc 11 9c 24 80 02 	vmovups %ymm3,0x280(%rsp)
 1266631:	00 00 
 1266633:	c5 fc 11 94 24 60 02 	vmovups %ymm2,0x260(%rsp)
 126663a:	00 00 
 126663c:	c5 fc 11 8c 24 40 02 	vmovups %ymm1,0x240(%rsp)
 1266643:	00 00 
 1266645:	c5 fe 7f 84 24 20 02 	vmovdqu %ymm0,0x220(%rsp)
 126664c:	00 00 
 126664e:	84 db                	test   %bl,%bl
 1266650:	41 b3 01             	mov    $0x1,%r11b
 1266653:	0f 84 35 02 00 00    	je     126688e <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xfde>
 1266659:	48 8b 54 24 50       	mov    0x50(%rsp),%rdx
 126665e:	48 83 fa 03          	cmp    $0x3,%rdx
 1266662:	4c 8b 84 24 90 00 00 	mov    0x90(%rsp),%r8
 1266669:	00 
 126666a:	c5 fd 6f ac 24 60 01 	vmovdqa 0x160(%rsp),%ymm5
 1266671:	00 00 
 1266673:	c5 fd 6f a4 24 40 01 	vmovdqa 0x140(%rsp),%ymm4
 126667a:	00 00 
 126667c:	0f 83 d0 09 00 00    	jae    1267052 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x17a2>
 1266682:	48 8d 04 92          	lea    (%rdx,%rdx,4),%rax
 1266686:	48 c1 e0 04          	shl    $0x4,%rax
 126668a:	48 8b 4c 24 78       	mov    0x78(%rsp),%rcx
 126668f:	48 89 8c 04 b8 02 00 	mov    %rcx,0x2b8(%rsp,%rax,1)
 1266696:	00 
 1266697:	0f b6 4c 24 48       	movzbl 0x48(%rsp),%ecx
 126669c:	88 8c 04 c0 02 00 00 	mov    %cl,0x2c0(%rsp,%rax,1)
 12666a3:	0f b6 4c 24 1e       	movzbl 0x1e(%rsp),%ecx
 12666a8:	88 8c 04 c1 02 00 00 	mov    %cl,0x2c1(%rsp,%rax,1)
 12666af:	c5 fc 28 84 24 80 01 	vmovaps 0x180(%rsp),%ymm0
 12666b6:	00 00 
 12666b8:	c5 fc 11 84 04 c2 02 	vmovups %ymm0,0x2c2(%rsp,%rax,1)
 12666bf:	00 00 
 12666c1:	c5 fd 6f 84 24 00 01 	vmovdqa 0x100(%rsp),%ymm0
 12666c8:	00 00 
 12666ca:	c5 fe 7f 84 04 e2 02 	vmovdqu %ymm0,0x2e2(%rsp,%rax,1)
 12666d1:	00 00 
 12666d3:	8b 4c 24 28          	mov    0x28(%rsp),%ecx
 12666d7:	89 8c 04 02 03 00 00 	mov    %ecx,0x302(%rsp,%rax,1)
 12666de:	0f b7 4c 24 2c       	movzwl 0x2c(%rsp),%ecx
 12666e3:	66 89 8c 04 06 03 00 	mov    %cx,0x306(%rsp,%rax,1)
 12666ea:	00 
 12666eb:	48 ff c2             	inc    %rdx
 12666ee:	48 89 54 24 50       	mov    %rdx,0x50(%rsp)
 12666f3:	e9 ba 01 00 00       	jmp    12668b2 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x1002>
 12666f8:	4c 89 fe             	mov    %r15,%rsi
 12666fb:	48 83 e6 fe          	and    $0xfffffffffffffffe,%rsi
 12666ff:	48 8d bc 24 c0 02 00 	lea    0x2c0(%rsp),%rdi
 1266706:	00 
 1266707:	31 d2                	xor    %edx,%edx
 1266709:	eb 19                	jmp    1266724 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xe74>
 126670b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 1266710:	48 83 c2 02          	add    $0x2,%rdx
 1266714:	48 81 c7 a0 00 00 00 	add    $0xa0,%rdi
 126671b:	48 39 d6             	cmp    %rdx,%rsi
 126671e:	0f 84 1f fc ff ff    	je     1266343 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xa93>
 1266724:	41 b0 01             	mov    $0x1,%r8b
 1266727:	f6 c1 01             	test   $0x1,%cl
 126672a:	b1 01                	mov    $0x1,%cl
 126672c:	75 4b                	jne    1266779 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xec9>
 126672e:	45 89 f1             	mov    %r14d,%r9d
 1266731:	41 80 e1 03          	and    $0x3,%r9b
 1266735:	44 0f b6 17          	movzbl (%rdi),%r10d
 1266739:	41 80 e2 03          	and    $0x3,%r10b
 126673d:	45 31 c0             	xor    %r8d,%r8d
 1266740:	45 38 d1             	cmp    %r10b,%r9b
 1266743:	75 34                	jne    1266779 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xec9>
 1266745:	44 0f b6 4f 01       	movzbl 0x1(%rdi),%r9d
 126674a:	41 80 e1 7f          	and    $0x7f,%r9b
 126674e:	45 89 e2             	mov    %r12d,%r10d
 1266751:	41 80 e2 7f          	and    $0x7f,%r10b
 1266755:	45 38 ca             	cmp    %r9b,%r10b
 1266758:	75 1f                	jne    1266779 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xec9>
 126675a:	c5 cd 74 47 02       	vpcmpeqb 0x2(%rdi),%ymm6,%ymm0
 126675f:	c5 7d d7 c8          	vpmovmskb %ymm0,%r9d
 1266763:	41 f7 d1             	not    %r9d
 1266766:	45 85 c9             	test   %r9d,%r9d
 1266769:	75 0e                	jne    1266779 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xec9>
 126676b:	c5 c5 ef 47 22       	vpxor  0x22(%rdi),%ymm7,%ymm0
 1266770:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1266775:	41 0f 94 c0          	sete   %r8b
 1266779:	45 84 c0             	test   %r8b,%r8b
 126677c:	75 92                	jne    1266710 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xe60>
 126677e:	45 89 f0             	mov    %r14d,%r8d
 1266781:	41 80 e0 03          	and    $0x3,%r8b
 1266785:	44 0f b6 4f 50       	movzbl 0x50(%rdi),%r9d
 126678a:	41 80 e1 03          	and    $0x3,%r9b
 126678e:	31 c9                	xor    %ecx,%ecx
 1266790:	45 38 c8             	cmp    %r9b,%r8b
 1266793:	0f 85 77 ff ff ff    	jne    1266710 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xe60>
 1266799:	44 0f b6 47 51       	movzbl 0x51(%rdi),%r8d
 126679e:	41 80 e0 7f          	and    $0x7f,%r8b
 12667a2:	45 89 e1             	mov    %r12d,%r9d
 12667a5:	41 80 e1 7f          	and    $0x7f,%r9b
 12667a9:	45 38 c1             	cmp    %r8b,%r9b
 12667ac:	0f 85 5e ff ff ff    	jne    1266710 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xe60>
 12667b2:	c5 cd 74 47 52       	vpcmpeqb 0x52(%rdi),%ymm6,%ymm0
 12667b7:	c5 7d d7 c0          	vpmovmskb %ymm0,%r8d
 12667bb:	41 f7 d0             	not    %r8d
 12667be:	45 85 c0             	test   %r8d,%r8d
 12667c1:	0f 85 49 ff ff ff    	jne    1266710 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xe60>
 12667c7:	c5 c5 ef 47 72       	vpxor  0x72(%rdi),%ymm7,%ymm0
 12667cc:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 12667d1:	0f 94 c1             	sete   %cl
 12667d4:	e9 37 ff ff ff       	jmp    1266710 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xe60>
 12667d9:	84 c9                	test   %cl,%cl
 12667db:	0f 85 3f fa ff ff    	jne    1266220 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x970>
 12667e1:	48 8d 0c 92          	lea    (%rdx,%rdx,4),%rcx
 12667e5:	48 c1 e1 04          	shl    $0x4,%rcx
 12667e9:	48 8d 14 0c          	lea    (%rsp,%rcx,1),%rdx
 12667ed:	48 81 c2 b8 02 00 00 	add    $0x2b8,%rdx
 12667f4:	44 89 f6             	mov    %r14d,%esi
 12667f7:	40 80 e6 03          	and    $0x3,%sil
 12667fb:	0f b6 7a 08          	movzbl 0x8(%rdx),%edi
 12667ff:	40 80 e7 03          	and    $0x3,%dil
 1266803:	40 38 fe             	cmp    %dil,%sil
 1266806:	0f 85 52 fb ff ff    	jne    126635e <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xaae>
 126680c:	0f b6 72 09          	movzbl 0x9(%rdx),%esi
 1266810:	40 80 e6 7f          	and    $0x7f,%sil
 1266814:	44 89 e7             	mov    %r12d,%edi
 1266817:	40 80 e7 7f          	and    $0x7f,%dil
 126681b:	40 38 f7             	cmp    %sil,%dil
 126681e:	0f 85 3a fb ff ff    	jne    126635e <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xaae>
 1266824:	c5 cd 74 42 0a       	vpcmpeqb 0xa(%rdx),%ymm6,%ymm0
 1266829:	c5 fd d7 d0          	vpmovmskb %ymm0,%edx
 126682d:	f7 d2                	not    %edx
 126682f:	85 d2                	test   %edx,%edx
 1266831:	0f 85 27 fb ff ff    	jne    126635e <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xaae>
 1266837:	c5 c5 ef 84 0c e2 02 	vpxor  0x2e2(%rsp,%rcx,1),%ymm7,%ymm0
 126683e:	00 00 
 1266840:	c4 e2 7d 17 c0       	vptest %ymm0,%ymm0
 1266845:	0f 94 c1             	sete   %cl
 1266848:	f6 c1 01             	test   $0x1,%cl
 126684b:	0f 84 0d fb ff ff    	je     126635e <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0xaae>
 1266851:	e9 ca f9 ff ff       	jmp    1266220 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x970>
 1266856:	4d 85 ff             	test   %r15,%r15
 1266859:	0f 84 18 f9 ff ff    	je     1266177 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x8c7>
 126685f:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 1266864:	48 8b 38             	mov    (%rax),%rdi
 1266867:	48 8b 40 08          	mov    0x8(%rax),%rax
 126686b:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 126686f:	4c 89 fa             	mov    %r15,%rdx
 1266872:	31 c9                	xor    %ecx,%ecx
 1266874:	ff 50 18             	call   *0x18(%rax)
 1266877:	48 8b 54 24 30       	mov    0x30(%rsp),%rdx
 126687c:	e9 f6 f8 ff ff       	jmp    1266177 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x8c7>
 1266881:	b8 8a 38 08 01       	mov    $0x108388a,%eax
 1266886:	45 31 db             	xor    %r11d,%r11d
 1266889:	e9 8d 01 00 00       	jmp    1266a1b <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x116b>
 126688e:	b0 01                	mov    $0x1,%al
 1266890:	48 89 84 24 c8 00 00 	mov    %rax,0xc8(%rsp)
 1266897:	00 
 1266898:	4c 8b 84 24 90 00 00 	mov    0x90(%rsp),%r8
 126689f:	00 
 12668a0:	c5 fd 6f ac 24 60 01 	vmovdqa 0x160(%rsp),%ymm5
 12668a7:	00 00 
 12668a9:	c5 fd 6f a4 24 40 01 	vmovdqa 0x140(%rsp),%ymm4
 12668b0:	00 00 
 12668b2:	48 8b 9c 24 c0 00 00 	mov    0xc0(%rsp),%rbx
 12668b9:	00 
 12668ba:	0f b7 84 24 84 00 00 	movzwl 0x84(%rsp),%eax
 12668c1:	00 
 12668c2:	66 89 44 24 2c       	mov    %ax,0x2c(%rsp)
 12668c7:	8b 84 24 80 00 00 00 	mov    0x80(%rsp),%eax
 12668ce:	89 44 24 28          	mov    %eax,0x28(%rsp)
 12668d2:	4d 85 ed             	test   %r13,%r13
 12668d5:	74 23                	je     12668fa <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x104a>
 12668d7:	44 88 74 24 48       	mov    %r14b,0x48(%rsp)
 12668dc:	48 8b 44 24 60       	mov    0x60(%rsp),%rax
 12668e1:	48 89 44 24 78       	mov    %rax,0x78(%rsp)
 12668e6:	4c 89 7c 24 30       	mov    %r15,0x30(%rsp)
 12668eb:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 12668f0:	4c 8b 7c 24 50       	mov    0x50(%rsp),%r15
 12668f5:	e9 2f f9 ff ff       	jmp    1266229 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x979>
 12668fa:	0f b7 84 24 84 00 00 	movzwl 0x84(%rsp),%eax
 1266901:	00 
 1266902:	66 89 84 24 a0 00 00 	mov    %ax,0xa0(%rsp)
 1266909:	00 
 126690a:	8b 84 24 80 00 00 00 	mov    0x80(%rsp),%eax
 1266911:	89 84 24 9c 00 00 00 	mov    %eax,0x9c(%rsp)
 1266918:	41 b3 01             	mov    $0x1,%r11b
 126691b:	44 89 f1             	mov    %r14d,%ecx
 126691e:	80 e1 03             	and    $0x3,%cl
 1266921:	b8 8a 38 08 01       	mov    $0x108388a,%eax
 1266926:	80 f9 02             	cmp    $0x2,%cl
 1266929:	0f 85 ce 00 00 00    	jne    12669fd <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x114d>
 126692f:	4c 89 7c 24 48       	mov    %r15,0x48(%rsp)
 1266934:	4c 8b 7c 24 60       	mov    0x60(%rsp),%r15
 1266939:	4c 89 bc 24 00 05 00 	mov    %r15,0x500(%rsp)
 1266940:	00 
 1266941:	44 88 b4 24 08 05 00 	mov    %r14b,0x508(%rsp)
 1266948:	00 
 1266949:	44 88 a4 24 09 05 00 	mov    %r12b,0x509(%rsp)
 1266950:	00 
 1266951:	c5 fe 7f ac 24 0a 05 	vmovdqu %ymm5,0x50a(%rsp)
 1266958:	00 00 
 126695a:	c5 fe 7f a4 24 2a 05 	vmovdqu %ymm4,0x52a(%rsp)
 1266961:	00 00 
 1266963:	0f b7 84 24 a0 00 00 	movzwl 0xa0(%rsp),%eax
 126696a:	00 
 126696b:	48 8d 8c 24 4a 05 00 	lea    0x54a(%rsp),%rcx
 1266972:	00 
 1266973:	66 89 41 04          	mov    %ax,0x4(%rcx)
 1266977:	8b 84 24 9c 00 00 00 	mov    0x9c(%rsp),%eax
 126697e:	89 01                	mov    %eax,(%rcx)
 1266980:	48 8d bc 24 a6 00 00 	lea    0xa6(%rsp),%rdi
 1266987:	00 
 1266988:	48 89 9c 24 c0 00 00 	mov    %rbx,0xc0(%rsp)
 126698f:	00 
 1266990:	48 8d b4 24 00 05 00 	lea    0x500(%rsp),%rsi
 1266997:	00 
 1266998:	44 89 db             	mov    %r11d,%ebx
 126699b:	c5 fd 7f ac 24 60 01 	vmovdqa %ymm5,0x160(%rsp)
 12669a2:	00 00 
 12669a4:	c5 fd 7f a4 24 40 01 	vmovdqa %ymm4,0x140(%rsp)
 12669ab:	00 00 
 12669ad:	c5 f8 77             	vzeroupper 
 12669b0:	e8 bb 98 fc ff       	call   1230270 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 12669b5:	4c 8b 84 24 90 00 00 	mov    0x90(%rsp),%r8
 12669bc:	00 
 12669bd:	41 89 db             	mov    %ebx,%r11d
 12669c0:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 12669c5:	c5 fd 6f ac 24 60 01 	vmovdqa 0x160(%rsp),%ymm5
 12669cc:	00 00 
 12669ce:	c5 fd 6f a4 24 40 01 	vmovdqa 0x140(%rsp),%ymm4
 12669d5:	00 00 
 12669d7:	48 8b 9c 24 c0 00 00 	mov    0xc0(%rsp),%rbx
 12669de:	00 
 12669df:	48 8b 44 24 48       	mov    0x48(%rsp),%rax
 12669e4:	48 89 44 24 30       	mov    %rax,0x30(%rsp)
 12669e9:	4c 89 7c 24 78       	mov    %r15,0x78(%rsp)
 12669ee:	44 88 74 24 48       	mov    %r14b,0x48(%rsp)
 12669f3:	48 8d 84 24 a6 00 00 	lea    0xa6(%rsp),%rax
 12669fa:	00 
 12669fb:	eb 19                	jmp    1266a16 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x1166>
 12669fd:	44 88 64 24 1e       	mov    %r12b,0x1e(%rsp)
 1266a02:	4c 89 7c 24 30       	mov    %r15,0x30(%rsp)
 1266a07:	48 8b 4c 24 60       	mov    0x60(%rsp),%rcx
 1266a0c:	48 89 4c 24 78       	mov    %rcx,0x78(%rsp)
 1266a11:	44 88 74 24 48       	mov    %r14b,0x48(%rsp)
 1266a16:	4c 8b 7c 24 50       	mov    0x50(%rsp),%r15
 1266a1b:	0f b7 00             	movzwl (%rax),%eax
 1266a1e:	66 89 44 24 26       	mov    %ax,0x26(%rsp)
 1266a23:	e9 01 f8 ff ff       	jmp    1266229 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x979>
 1266a28:	8b 44 24 38          	mov    0x38(%rsp),%eax
 1266a2c:	8b 8c 24 f8 00 00 00 	mov    0xf8(%rsp),%ecx
 1266a33:	08 c8                	or     %cl,%al
 1266a35:	0f 84 ef 03 00 00    	je     1266e2a <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x157a>
 1266a3b:	84 c9                	test   %cl,%cl
 1266a3d:	4c 8b 8c 24 b8 00 00 	mov    0xb8(%rsp),%r9
 1266a44:	00 
 1266a45:	0f b6 74 24 1f       	movzbl 0x1f(%rsp),%esi
 1266a4a:	75 36                	jne    1266a82 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x11d2>
 1266a4c:	b9 64 00 00 00       	mov    $0x64,%ecx
 1266a51:	48 8b 44 24 30       	mov    0x30(%rsp),%rax
 1266a56:	48 f7 e1             	mul    %rcx
 1266a59:	70 27                	jo     1266a82 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x11d2>
 1266a5b:	c6 84 24 c0 01 00 00 	movb   $0x0,0x1c0(%rsp)
 1266a62:	00 
 1266a63:	31 c9                	xor    %ecx,%ecx
 1266a65:	84 c9                	test   %cl,%cl
 1266a67:	75 19                	jne    1266a82 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x11d2>
 1266a69:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1266a70:	00 
 1266a71:	48 c1 e1 04          	shl    $0x4,%rcx
 1266a75:	48 8d 0c 89          	lea    (%rcx,%rcx,4),%rcx
 1266a79:	48 39 c8             	cmp    %rcx,%rax
 1266a7c:	0f 86 22 06 00 00    	jbe    12670a4 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x17f4>
 1266a82:	c5 fd 7f ac 24 80 01 	vmovdqa %ymm5,0x180(%rsp)
 1266a89:	00 00 
 1266a8b:	c5 fd 7f a4 24 00 01 	vmovdqa %ymm4,0x100(%rsp)
 1266a92:	00 00 
 1266a94:	49 89 dd             	mov    %rbx,%r13
 1266a97:	45 89 de             	mov    %r11d,%r14d
 1266a9a:	c5 fc 10 84 24 e0 04 	vmovups 0x4e0(%rsp),%ymm0
 1266aa1:	00 00 
 1266aa3:	c5 fc 11 84 24 e0 06 	vmovups %ymm0,0x6e0(%rsp)
 1266aaa:	00 00 
 1266aac:	c5 fc 10 84 24 70 04 	vmovups 0x470(%rsp),%ymm0
 1266ab3:	00 00 
 1266ab5:	c5 fc 10 8c 24 90 04 	vmovups 0x490(%rsp),%ymm1
 1266abc:	00 00 
 1266abe:	c5 fc 10 94 24 b0 04 	vmovups 0x4b0(%rsp),%ymm2
 1266ac5:	00 00 
 1266ac7:	c5 fc 10 9c 24 d0 04 	vmovups 0x4d0(%rsp),%ymm3
 1266ace:	00 00 
 1266ad0:	c5 fc 11 9c 24 d0 06 	vmovups %ymm3,0x6d0(%rsp)
 1266ad7:	00 00 
 1266ad9:	c5 fc 11 94 24 b0 06 	vmovups %ymm2,0x6b0(%rsp)
 1266ae0:	00 00 
 1266ae2:	c5 fc 11 8c 24 90 06 	vmovups %ymm1,0x690(%rsp)
 1266ae9:	00 00 
 1266aeb:	c5 fc 11 84 24 70 06 	vmovups %ymm0,0x670(%rsp)
 1266af2:	00 00 
 1266af4:	0f b6 44 24 20       	movzbl 0x20(%rsp),%eax
 1266af9:	c5 fe 6f 84 24 f0 03 	vmovdqu 0x3f0(%rsp),%ymm0
 1266b00:	00 00 
 1266b02:	c5 fe 7f 84 24 50 09 	vmovdqu %ymm0,0x950(%rsp)
 1266b09:	00 00 
 1266b0b:	88 84 24 51 0b 00 00 	mov    %al,0xb51(%rsp)
 1266b12:	48 c7 84 24 40 09 00 	movq   $0x0,0x940(%rsp)
 1266b19:	00 00 00 00 00 
 1266b1e:	66 c7 84 24 54 0b 00 	movw   $0x0,0xb54(%rsp)
 1266b25:	00 00 00 
 1266b28:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1266b2c:	c5 fe 7f 84 24 70 09 	vmovdqu %ymm0,0x970(%rsp)
 1266b33:	00 00 
 1266b35:	c5 fe 7f 84 24 90 09 	vmovdqu %ymm0,0x990(%rsp)
 1266b3c:	00 00 
 1266b3e:	c5 fe 7f 84 24 b0 09 	vmovdqu %ymm0,0x9b0(%rsp)
 1266b45:	00 00 
 1266b47:	c5 fe 7f 84 24 d0 09 	vmovdqu %ymm0,0x9d0(%rsp)
 1266b4e:	00 00 
 1266b50:	c5 fe 7f 84 24 f0 09 	vmovdqu %ymm0,0x9f0(%rsp)
 1266b57:	00 00 
 1266b59:	c5 fe 7f 84 24 10 0a 	vmovdqu %ymm0,0xa10(%rsp)
 1266b60:	00 00 
 1266b62:	c5 fe 7f 84 24 30 0a 	vmovdqu %ymm0,0xa30(%rsp)
 1266b69:	00 00 
 1266b6b:	c5 fe 7f 84 24 50 0a 	vmovdqu %ymm0,0xa50(%rsp)
 1266b72:	00 00 
 1266b74:	c5 fe 7f 84 24 70 0a 	vmovdqu %ymm0,0xa70(%rsp)
 1266b7b:	00 00 
 1266b7d:	c5 fe 7f 84 24 90 0a 	vmovdqu %ymm0,0xa90(%rsp)
 1266b84:	00 00 
 1266b86:	c5 fe 7f 84 24 b0 0a 	vmovdqu %ymm0,0xab0(%rsp)
 1266b8d:	00 00 
 1266b8f:	c5 fe 7f 84 24 d0 0a 	vmovdqu %ymm0,0xad0(%rsp)
 1266b96:	00 00 
 1266b98:	c5 fe 7f 84 24 f0 0a 	vmovdqu %ymm0,0xaf0(%rsp)
 1266b9f:	00 00 
 1266ba1:	c5 fe 7f 84 24 10 0b 	vmovdqu %ymm0,0xb10(%rsp)
 1266ba8:	00 00 
 1266baa:	48 c7 84 24 30 0b 00 	movq   $0x0,0xb30(%rsp)
 1266bb1:	00 00 00 00 00 
 1266bb6:	c6 84 24 48 0b 00 00 	movb   $0x38,0xb48(%rsp)
 1266bbd:	38 
 1266bbe:	c6 84 24 50 0b 00 00 	movb   $0x0,0xb50(%rsp)
 1266bc5:	00 
 1266bc6:	0f b7 05 63 43 dd ff 	movzwl -0x22bc9d(%rip),%eax        # 103af30 <__anon_29470>
 1266bcd:	66 89 84 24 4a 0b 00 	mov    %ax,0xb4a(%rsp)
 1266bd4:	00 
 1266bd5:	40 88 b4 24 49 0b 00 	mov    %sil,0xb49(%rsp)
 1266bdc:	00 
 1266bdd:	48 8b 84 24 f0 00 00 	mov    0xf0(%rsp),%rax
 1266be4:	00 
 1266be5:	48 89 84 24 30 09 00 	mov    %rax,0x930(%rsp)
 1266bec:	00 
 1266bed:	48 8b 84 24 e8 00 00 	mov    0xe8(%rsp),%rax
 1266bf4:	00 
 1266bf5:	48 89 84 24 38 09 00 	mov    %rax,0x938(%rsp)
 1266bfc:	00 
 1266bfd:	c7 84 24 4c 0b 00 00 	movl   $0x1000101,0xb4c(%rsp)
 1266c04:	01 01 00 01 
 1266c08:	48 8b 84 24 e0 00 00 	mov    0xe0(%rsp),%rax
 1266c0f:	00 
 1266c10:	48 89 84 24 40 0b 00 	mov    %rax,0xb40(%rsp)
 1266c17:	00 
 1266c18:	48 8b 84 24 d8 00 00 	mov    0xd8(%rsp),%rax
 1266c1f:	00 
 1266c20:	48 89 84 24 38 0b 00 	mov    %rax,0xb38(%rsp)
 1266c27:	00 
 1266c28:	66 c7 84 24 52 0b 00 	movw   $0x0,0xb52(%rsp)
 1266c2f:	00 00 00 
 1266c32:	48 c7 84 24 48 09 00 	movq   $0x0,0x948(%rsp)
 1266c39:	00 00 00 00 00 
 1266c3e:	48 8d 84 24 30 09 00 	lea    0x930(%rsp),%rax
 1266c45:	00 
 1266c46:	4c 8d 94 24 70 06 00 	lea    0x670(%rsp),%r10
 1266c4d:	00 
 1266c4e:	48 8d bc 24 d8 03 00 	lea    0x3d8(%rsp),%rdi
 1266c55:	00 
 1266c56:	48 8b 74 24 40       	mov    0x40(%rsp),%rsi
 1266c5b:	48 8b 94 24 d0 00 00 	mov    0xd0(%rsp),%rdx
 1266c62:	00 
 1266c63:	48 8b 8c 24 a8 00 00 	mov    0xa8(%rsp),%rcx
 1266c6a:	00 
 1266c6b:	4c 8b 84 24 b0 00 00 	mov    0xb0(%rsp),%r8
 1266c72:	00 
 1266c73:	50                   	push   %rax
 1266c74:	41 52                	push   %r10
 1266c76:	c5 f8 77             	vzeroupper 
 1266c79:	e8 a2 04 f5 ff       	call   11b7120 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_30089>
 1266c7e:	48 83 c4 10          	add    $0x10,%rsp
 1266c82:	0f b7 9c 24 e8 03 00 	movzwl 0x3e8(%rsp),%ebx
 1266c89:	00 
 1266c8a:	66 85 db             	test   %bx,%bx
 1266c8d:	0f 85 eb 04 00 00    	jne    126717e <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x18ce>
 1266c93:	4c 89 fb             	mov    %r15,%rbx
 1266c96:	4c 8b a4 24 d8 03 00 	mov    0x3d8(%rsp),%r12
 1266c9d:	00 
 1266c9e:	4c 8b bc 24 e0 03 00 	mov    0x3e0(%rsp),%r15
 1266ca5:	00 
 1266ca6:	4c 8b 4c 24 30       	mov    0x30(%rsp),%r9
 1266cab:	4d 39 f9             	cmp    %r15,%r9
 1266cae:	0f 83 dc 02 00 00    	jae    1266f90 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x16e0>
 1266cb4:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 1266cb9:	48 8b 38             	mov    (%rax),%rdi
 1266cbc:	48 8b 40 08          	mov    0x8(%rax),%rax
 1266cc0:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1266cc4:	4c 89 e6             	mov    %r12,%rsi
 1266cc7:	4c 89 fa             	mov    %r15,%rdx
 1266cca:	31 c9                	xor    %ecx,%ecx
 1266ccc:	4d 89 cf             	mov    %r9,%r15
 1266ccf:	ff 50 18             	call   *0x18(%rax)
 1266cd2:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 1266cd9:	00 00 
 1266cdb:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1266cdf:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1266ce4:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 1266ceb:	00 00 
 1266ced:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 1266cf4:	00 00 
 1266cf6:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 1266cfd:	00 00 
 1266cff:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 1266d06:	00 00 
 1266d08:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1266d0d:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1266d12:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1266d17:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1266d1b:	48 8b 54 24 58       	mov    0x58(%rsp),%rdx
 1266d20:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 1266d27:	00 00 
 1266d29:	4c 89 2a             	mov    %r13,(%rdx)
 1266d2c:	4c 89 7a 08          	mov    %r15,0x8(%rdx)
 1266d30:	8b 44 24 38          	mov    0x38(%rsp),%eax
 1266d34:	88 82 58 01 00 00    	mov    %al,0x158(%rdx)
 1266d3a:	48 8b 44 24 78       	mov    0x78(%rsp),%rax
 1266d3f:	48 89 42 10          	mov    %rax,0x10(%rdx)
 1266d43:	0f b6 44 24 48       	movzbl 0x48(%rsp),%eax
 1266d48:	88 42 18             	mov    %al,0x18(%rdx)
 1266d4b:	0f b6 44 24 1e       	movzbl 0x1e(%rsp),%eax
 1266d50:	88 42 19             	mov    %al,0x19(%rdx)
 1266d53:	c5 fc 28 84 24 80 01 	vmovaps 0x180(%rsp),%ymm0
 1266d5a:	00 00 
 1266d5c:	c5 fc 11 42 1a       	vmovups %ymm0,0x1a(%rdx)
 1266d61:	c5 fc 28 84 24 00 01 	vmovaps 0x100(%rsp),%ymm0
 1266d68:	00 00 
 1266d6a:	c5 fc 11 42 3a       	vmovups %ymm0,0x3a(%rdx)
 1266d6f:	8b 44 24 28          	mov    0x28(%rsp),%eax
 1266d73:	89 42 5a             	mov    %eax,0x5a(%rdx)
 1266d76:	0f b7 44 24 2c       	movzwl 0x2c(%rsp),%eax
 1266d7b:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 1266d7f:	44 88 72 60          	mov    %r14b,0x60(%rdx)
 1266d83:	8b 84 24 88 00 00 00 	mov    0x88(%rsp),%eax
 1266d8a:	8b 8c 24 8b 00 00 00 	mov    0x8b(%rsp),%ecx
 1266d91:	89 42 61             	mov    %eax,0x61(%rdx)
 1266d94:	89 4a 64             	mov    %ecx,0x64(%rdx)
 1266d97:	c5 fc 10 84 24 b8 02 	vmovups 0x2b8(%rsp),%ymm0
 1266d9e:	00 00 
 1266da0:	c5 fc 10 8c 24 d8 02 	vmovups 0x2d8(%rsp),%ymm1
 1266da7:	00 00 
 1266da9:	c5 fc 10 94 24 f8 02 	vmovups 0x2f8(%rsp),%ymm2
 1266db0:	00 00 
 1266db2:	c5 fc 10 9c 24 18 03 	vmovups 0x318(%rsp),%ymm3
 1266db9:	00 00 
 1266dbb:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 1266dc0:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 1266dc7:	00 
 1266dc8:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 1266dcf:	00 
 1266dd0:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 1266dd7:	00 
 1266dd8:	c5 fc 10 84 24 38 03 	vmovups 0x338(%rsp),%ymm0
 1266ddf:	00 00 
 1266de1:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 1266de8:	00 
 1266de9:	c5 fc 10 84 24 58 03 	vmovups 0x358(%rsp),%ymm0
 1266df0:	00 00 
 1266df2:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 1266df9:	00 
 1266dfa:	c5 fc 10 84 24 78 03 	vmovups 0x378(%rsp),%ymm0
 1266e01:	00 00 
 1266e03:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 1266e0a:	00 
 1266e0b:	c5 fe 6f 84 24 88 03 	vmovdqu 0x388(%rsp),%ymm0
 1266e12:	00 00 
 1266e14:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 1266e1b:	00 
 1266e1c:	80 e3 03             	and    $0x3,%bl
 1266e1f:	88 9a 59 01 00 00    	mov    %bl,0x159(%rdx)
 1266e25:	e9 45 01 00 00       	jmp    1266f6f <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x16bf>
 1266e2a:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 1266e31:	00 00 
 1266e33:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1266e37:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1266e3c:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 1266e43:	00 00 
 1266e45:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 1266e4c:	00 00 
 1266e4e:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 1266e55:	00 00 
 1266e57:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 1266e5e:	00 00 
 1266e60:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1266e65:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1266e6a:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1266e6f:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 1266e73:	48 8b 54 24 58       	mov    0x58(%rsp),%rdx
 1266e78:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 1266e7f:	00 00 
 1266e81:	48 89 1a             	mov    %rbx,(%rdx)
 1266e84:	48 8b 44 24 30       	mov    0x30(%rsp),%rax
 1266e89:	48 89 42 08          	mov    %rax,0x8(%rdx)
 1266e8d:	c6 82 58 01 00 00 00 	movb   $0x0,0x158(%rdx)
 1266e94:	48 8b 44 24 78       	mov    0x78(%rsp),%rax
 1266e99:	48 89 42 10          	mov    %rax,0x10(%rdx)
 1266e9d:	0f b6 44 24 48       	movzbl 0x48(%rsp),%eax
 1266ea2:	88 42 18             	mov    %al,0x18(%rdx)
 1266ea5:	0f b6 44 24 1e       	movzbl 0x1e(%rsp),%eax
 1266eaa:	88 42 19             	mov    %al,0x19(%rdx)
 1266ead:	c5 fe 7f 6a 1a       	vmovdqu %ymm5,0x1a(%rdx)
 1266eb2:	c5 fe 7f 62 3a       	vmovdqu %ymm4,0x3a(%rdx)
 1266eb7:	8b 44 24 28          	mov    0x28(%rsp),%eax
 1266ebb:	89 42 5a             	mov    %eax,0x5a(%rdx)
 1266ebe:	0f b7 44 24 2c       	movzwl 0x2c(%rsp),%eax
 1266ec3:	66 89 42 5e          	mov    %ax,0x5e(%rdx)
 1266ec7:	44 88 5a 60          	mov    %r11b,0x60(%rdx)
 1266ecb:	8b 84 24 88 00 00 00 	mov    0x88(%rsp),%eax
 1266ed2:	8b 8c 24 8b 00 00 00 	mov    0x8b(%rsp),%ecx
 1266ed9:	89 42 61             	mov    %eax,0x61(%rdx)
 1266edc:	89 4a 64             	mov    %ecx,0x64(%rdx)
 1266edf:	c5 fc 10 84 24 b8 02 	vmovups 0x2b8(%rsp),%ymm0
 1266ee6:	00 00 
 1266ee8:	c5 fc 10 8c 24 d8 02 	vmovups 0x2d8(%rsp),%ymm1
 1266eef:	00 00 
 1266ef1:	c5 fc 10 94 24 f8 02 	vmovups 0x2f8(%rsp),%ymm2
 1266ef8:	00 00 
 1266efa:	c5 fc 10 9c 24 18 03 	vmovups 0x318(%rsp),%ymm3
 1266f01:	00 00 
 1266f03:	c5 fc 11 42 68       	vmovups %ymm0,0x68(%rdx)
 1266f08:	c5 fc 11 8a 88 00 00 	vmovups %ymm1,0x88(%rdx)
 1266f0f:	00 
 1266f10:	c5 fc 11 92 a8 00 00 	vmovups %ymm2,0xa8(%rdx)
 1266f17:	00 
 1266f18:	c5 fc 11 9a c8 00 00 	vmovups %ymm3,0xc8(%rdx)
 1266f1f:	00 
 1266f20:	c5 fc 10 84 24 38 03 	vmovups 0x338(%rsp),%ymm0
 1266f27:	00 00 
 1266f29:	c5 fc 11 82 e8 00 00 	vmovups %ymm0,0xe8(%rdx)
 1266f30:	00 
 1266f31:	c5 fc 10 84 24 58 03 	vmovups 0x358(%rsp),%ymm0
 1266f38:	00 00 
 1266f3a:	c5 fc 11 82 08 01 00 	vmovups %ymm0,0x108(%rdx)
 1266f41:	00 
 1266f42:	c5 fc 10 84 24 78 03 	vmovups 0x378(%rsp),%ymm0
 1266f49:	00 00 
 1266f4b:	c5 fc 11 82 28 01 00 	vmovups %ymm0,0x128(%rdx)
 1266f52:	00 
 1266f53:	c5 fe 6f 84 24 88 03 	vmovdqu 0x388(%rsp),%ymm0
 1266f5a:	00 00 
 1266f5c:	c5 fe 7f 82 38 01 00 	vmovdqu %ymm0,0x138(%rdx)
 1266f63:	00 
 1266f64:	41 80 e7 03          	and    $0x3,%r15b
 1266f68:	44 88 ba 59 01 00 00 	mov    %r15b,0x159(%rdx)
 1266f6f:	48 8b 84 24 c8 00 00 	mov    0xc8(%rsp),%rax
 1266f76:	00 
 1266f77:	24 01                	and    $0x1,%al
 1266f79:	88 82 5a 01 00 00    	mov    %al,0x15a(%rdx)
 1266f7f:	0f b7 44 24 26       	movzwl 0x26(%rsp),%eax
 1266f84:	66 89 82 5b 01 00 00 	mov    %ax,0x15b(%rdx)
 1266f8b:	e9 02 01 00 00       	jmp    1267092 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x17e2>
 1266f90:	4d 85 c9             	test   %r9,%r9
 1266f93:	74 1b                	je     1266fb0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x1700>
 1266f95:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 1266f9a:	48 8b 38             	mov    (%rax),%rdi
 1266f9d:	48 8b 40 08          	mov    0x8(%rax),%rax
 1266fa1:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1266fa5:	4c 89 ee             	mov    %r13,%rsi
 1266fa8:	4c 89 ca             	mov    %r9,%rdx
 1266fab:	31 c9                	xor    %ecx,%ecx
 1266fad:	ff 50 18             	call   *0x18(%rax)
 1266fb0:	c5 fc 10 84 24 e0 06 	vmovups 0x6e0(%rsp),%ymm0
 1266fb7:	00 00 
 1266fb9:	48 8b 45 10          	mov    0x10(%rbp),%rax
 1266fbd:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 1266fc2:	c5 fe 6f 84 24 70 06 	vmovdqu 0x670(%rsp),%ymm0
 1266fc9:	00 00 
 1266fcb:	c5 fc 10 8c 24 90 06 	vmovups 0x690(%rsp),%ymm1
 1266fd2:	00 00 
 1266fd4:	c5 fc 10 94 24 b0 06 	vmovups 0x6b0(%rsp),%ymm2
 1266fdb:	00 00 
 1266fdd:	c5 fc 10 9c 24 d0 06 	vmovups 0x6d0(%rsp),%ymm3
 1266fe4:	00 00 
 1266fe6:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 1266feb:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 1266ff0:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 1266ff5:	c5 fe 7f 00          	vmovdqu %ymm0,(%rax)
 1266ff9:	48 8b 44 24 58       	mov    0x58(%rsp),%rax
 1266ffe:	66 c7 80 60 01 00 00 	movw   $0x0,0x160(%rax)
 1267005:	00 00 
 1267007:	4c 89 20             	mov    %r12,(%rax)
 126700a:	4c 89 78 08          	mov    %r15,0x8(%rax)
 126700e:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 1267012:	c5 fe 7f 40 10       	vmovdqu %ymm0,0x10(%rax)
 1267017:	c5 fe 7f 40 30       	vmovdqu %ymm0,0x30(%rax)
 126701c:	c5 fe 7f 40 48       	vmovdqu %ymm0,0x48(%rax)
 1267021:	c7 80 58 01 00 00 00 	movl   $0x0,0x158(%rax)
 1267028:	00 00 00 
 126702b:	c6 80 5c 01 00 00 00 	movb   $0x0,0x15c(%rax)
 1267032:	eb 5e                	jmp    1267092 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x17e2>
 1267034:	48 85 d2             	test   %rdx,%rdx
 1267037:	74 42                	je     126707b <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x17cb>
 1267039:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 126703e:	48 8b 38             	mov    (%rax),%rdi
 1267041:	48 8b 40 08          	mov    0x8(%rax),%rax
 1267045:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1267049:	48 8b 74 24 70       	mov    0x70(%rsp),%rsi
 126704e:	31 c9                	xor    %ecx,%ecx
 1267050:	eb 23                	jmp    1267075 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x17c5>
 1267052:	4d 85 ff             	test   %r15,%r15
 1267055:	48 8b b4 24 c0 00 00 	mov    0xc0(%rsp),%rsi
 126705c:	00 
 126705d:	74 1c                	je     126707b <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x17cb>
 126705f:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 1267064:	48 8b 38             	mov    (%rax),%rdi
 1267067:	48 8b 40 08          	mov    0x8(%rax),%rax
 126706b:	4c 89 fa             	mov    %r15,%rdx
 126706e:	31 c9                	xor    %ecx,%ecx
 1267070:	4c 8b 44 24 30       	mov    0x30(%rsp),%r8
 1267075:	c5 f8 77             	vzeroupper 
 1267078:	ff 50 18             	call   *0x18(%rax)
 126707b:	be 40 39 09 01       	mov    $0x1093940,%esi
 1267080:	ba 68 01 00 00       	mov    $0x168,%edx
 1267085:	48 8b 7c 24 58       	mov    0x58(%rsp),%rdi
 126708a:	c5 f8 77             	vzeroupper 
 126708d:	e8 ce 86 07 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 1267092:	48 8d 65 d8          	lea    -0x28(%rbp),%rsp
 1267096:	5b                   	pop    %rbx
 1267097:	41 5c                	pop    %r12
 1267099:	41 5d                	pop    %r13
 126709b:	41 5e                	pop    %r14
 126709d:	41 5f                	pop    %r15
 126709f:	5d                   	pop    %rbp
 12670a0:	c5 f8 77             	vzeroupper 
 12670a3:	c3                   	ret    
 12670a4:	c5 fc 10 84 24 90 02 	vmovups 0x290(%rsp),%ymm0
 12670ab:	00 00 
 12670ad:	48 8b 45 10          	mov    0x10(%rbp),%rax
 12670b1:	c5 fc 11 40 70       	vmovups %ymm0,0x70(%rax)
 12670b6:	c5 fc 10 84 24 20 02 	vmovups 0x220(%rsp),%ymm0
 12670bd:	00 00 
 12670bf:	c5 fc 10 8c 24 40 02 	vmovups 0x240(%rsp),%ymm1
 12670c6:	00 00 
 12670c8:	c5 fc 10 94 24 60 02 	vmovups 0x260(%rsp),%ymm2
 12670cf:	00 00 
 12670d1:	c5 fc 10 9c 24 80 02 	vmovups 0x280(%rsp),%ymm3
 12670d8:	00 00 
 12670da:	c5 fc 11 58 60       	vmovups %ymm3,0x60(%rax)
 12670df:	c5 fc 11 50 40       	vmovups %ymm2,0x40(%rax)
 12670e4:	c5 fc 11 48 20       	vmovups %ymm1,0x20(%rax)
 12670e9:	c5 fc 11 00          	vmovups %ymm0,(%rax)
 12670ed:	48 8b 54 24 58       	mov    0x58(%rsp),%rdx
 12670f2:	66 c7 82 60 01 00 00 	movw   $0x0,0x160(%rdx)
 12670f9:	00 00 
 12670fb:	48 89 1a             	mov    %rbx,(%rdx)
 12670fe:	48 8b 44 24 30       	mov    0x30(%rsp),%rax
 1267103:	48 89 42 08          	mov    %rax,0x8(%rdx)
 1267107:	8b 44 24 38          	mov    0x38(%rsp),%eax
 126710b:	88 82 58 01 00 00    	mov    %al,0x158(%rdx)
 1267111:	e9 7e fd ff ff       	jmp    1266e94 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x15e4>
 1267116:	48 8b 54 24 30       	mov    0x30(%rsp),%rdx
 126711b:	48 85 d2             	test   %rdx,%rdx
 126711e:	74 1a                	je     126713a <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x188a>
 1267120:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 1267125:	48 8b 38             	mov    (%rax),%rdi
 1267128:	48 8b 40 08          	mov    0x8(%rax),%rax
 126712c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1267130:	48 8b 74 24 70       	mov    0x70(%rsp),%rsi
 1267135:	31 c9                	xor    %ecx,%ecx
 1267137:	ff 50 18             	call   *0x18(%rax)
 126713a:	48 8b 44 24 58       	mov    0x58(%rsp),%rax
 126713f:	66 44 89 b8 60 01 00 	mov    %r15w,0x160(%rax)
 1267146:	00 
 1267147:	e9 46 ff ff ff       	jmp    1267092 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x17e2>
 126714c:	48 8b 4c 24 58       	mov    0x58(%rsp),%rcx
 1267151:	66 89 81 60 01 00 00 	mov    %ax,0x160(%rcx)
 1267158:	e9 35 ff ff ff       	jmp    1267092 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x17e2>
 126715d:	48 8b 54 24 30       	mov    0x30(%rsp),%rdx
 1267162:	48 85 d2             	test   %rdx,%rdx
 1267165:	74 39                	je     12671a0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x18f0>
 1267167:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 126716c:	48 8b 38             	mov    (%rax),%rdi
 126716f:	48 8b 40 08          	mov    0x8(%rax),%rax
 1267173:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1267177:	48 8b 74 24 70       	mov    0x70(%rsp),%rsi
 126717c:	eb 1d                	jmp    126719b <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x18eb>
 126717e:	48 8b 54 24 30       	mov    0x30(%rsp),%rdx
 1267183:	48 85 d2             	test   %rdx,%rdx
 1267186:	74 18                	je     12671a0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x18f0>
 1267188:	48 8b 44 24 40       	mov    0x40(%rsp),%rax
 126718d:	48 8b 38             	mov    (%rax),%rdi
 1267190:	48 8b 40 08          	mov    0x8(%rax),%rax
 1267194:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1267198:	4c 89 ee             	mov    %r13,%rsi
 126719b:	31 c9                	xor    %ecx,%ecx
 126719d:	ff 50 18             	call   *0x18(%rax)
 12671a0:	48 8b 44 24 58       	mov    0x58(%rsp),%rax
 12671a5:	66 89 98 60 01 00 00 	mov    %bx,0x160(%rax)
 12671ac:	e9 e1 fe ff ff       	jmp    1267092 <br.encodePreferredCommandPlanAllocRecorded__anon_205502+0x17e2>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
