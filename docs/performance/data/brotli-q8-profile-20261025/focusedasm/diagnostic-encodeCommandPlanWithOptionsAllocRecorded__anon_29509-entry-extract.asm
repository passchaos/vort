 122eb30:	55                   	push   %rbp
 122eb31:	48 89 e5             	mov    %rsp,%rbp
 122eb34:	41 57                	push   %r15
 122eb36:	41 56                	push   %r14
 122eb38:	41 55                	push   %r13
 122eb3a:	41 54                	push   %r12
 122eb3c:	53                   	push   %rbx
 122eb3d:	48 81 ec 18 02 00 00 	sub    $0x218,%rsp
 122eb44:	4c 89 8d c0 fe ff ff 	mov    %r9,-0x140(%rbp)
 122eb4b:	4d 89 c5             	mov    %r8,%r13
 122eb4e:	48 89 8d c8 fe ff ff 	mov    %rcx,-0x138(%rbp)
 122eb55:	48 89 d3             	mov    %rdx,%rbx
 122eb58:	49 89 fc             	mov    %rdi,%r12
 122eb5b:	4c 8b 75 20          	mov    0x20(%rbp),%r14
 122eb5f:	4c 8b 45 10          	mov    0x10(%rbp),%r8
 122eb63:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 122eb67:	c5 fc 11 85 d0 fd ff 	vmovups %ymm0,-0x230(%rbp)
 122eb6e:	ff 
 122eb6f:	4d 8b be 08 02 00 00 	mov    0x208(%r14),%r15
 122eb76:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 122eb7d:	48 8d b5 d0 fd ff ff 	lea    -0x230(%rbp),%rsi
 122eb84:	ba 07 00 00 00       	mov    $0x7,%edx
 122eb89:	4c 89 e9             	mov    %r13,%rcx
 122eb8c:	c5 f8 77             	vzeroupper 
 122eb8f:	e8 fc 89 04 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 122eb94:	80 bd 08 ff ff ff 00 	cmpb   $0x0,-0xf8(%rbp)
 122eb9b:	0f 84 18 06 00 00    	je     122f1b9 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x689>
 122eba1:	4c 89 bd b0 fe ff ff 	mov    %r15,-0x150(%rbp)
 122eba8:	4c 89 ad a8 fe ff ff 	mov    %r13,-0x158(%rbp)
 122ebaf:	48 89 9d a0 fe ff ff 	mov    %rbx,-0x160(%rbp)
 122ebb6:	4c 89 a5 98 fe ff ff 	mov    %r12,-0x168(%rbp)
 122ebbd:	48 69 85 00 ff ff ff 	imul   $0x118,-0x100(%rbp),%rax
 122ebc4:	18 01 00 00 
 122ebc8:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 122ebcf:	49 8b 46 40          	mov    0x40(%r14),%rax
 122ebd3:	48 89 85 68 ff ff ff 	mov    %rax,-0x98(%rbp)
 122ebda:	41 0f b6 4e 48       	movzbl 0x48(%r14),%ecx
 122ebdf:	41 0f b6 46 49       	movzbl 0x49(%r14),%eax
 122ebe4:	88 85 60 ff ff ff    	mov    %al,-0xa0(%rbp)
 122ebea:	41 0f b6 86 a8 00 00 	movzbl 0xa8(%r14),%eax
 122ebf1:	00 
 122ebf2:	88 45 bd             	mov    %al,-0x43(%rbp)
 122ebf5:	41 0f b6 86 b8 00 00 	movzbl 0xb8(%r14),%eax
 122ebfc:	00 
 122ebfd:	88 45 ba             	mov    %al,-0x46(%rbp)
 122ec00:	41 0f b6 86 c8 00 00 	movzbl 0xc8(%r14),%eax
 122ec07:	00 
 122ec08:	88 45 b7             	mov    %al,-0x49(%rbp)
 122ec0b:	41 0f b6 86 d8 00 00 	movzbl 0xd8(%r14),%eax
 122ec12:	00 
 122ec13:	88 45 b4             	mov    %al,-0x4c(%rbp)
 122ec16:	49 8b b6 e0 00 00 00 	mov    0xe0(%r14),%rsi
 122ec1d:	48 89 75 90          	mov    %rsi,-0x70(%rbp)
 122ec21:	41 0f b6 86 e8 00 00 	movzbl 0xe8(%r14),%eax
 122ec28:	00 
 122ec29:	88 45 ab             	mov    %al,-0x55(%rbp)
 122ec2c:	41 0f b6 86 f8 00 00 	movzbl 0xf8(%r14),%eax
 122ec33:	00 
 122ec34:	88 45 ae             	mov    %al,-0x52(%rbp)
 122ec37:	41 0f b6 86 f9 00 00 	movzbl 0xf9(%r14),%eax
 122ec3e:	00 
 122ec3f:	88 45 b1             	mov    %al,-0x4f(%rbp)
 122ec42:	41 0f b6 86 00 01 00 	movzbl 0x100(%r14),%eax
 122ec49:	00 
 122ec4a:	4d 8b ae 08 01 00 00 	mov    0x108(%r14),%r13
 122ec51:	4d 8b 9e 10 01 00 00 	mov    0x110(%r14),%r11
 122ec58:	41 0f b6 b6 28 01 00 	movzbl 0x128(%r14),%esi
 122ec5f:	00 
 122ec60:	40 88 75 bc          	mov    %sil,-0x44(%rbp)
 122ec64:	41 0f b6 b6 38 01 00 	movzbl 0x138(%r14),%esi
 122ec6b:	00 
 122ec6c:	40 88 75 b9          	mov    %sil,-0x47(%rbp)
 122ec70:	41 0f b6 b6 48 01 00 	movzbl 0x148(%r14),%esi
 122ec77:	00 
 122ec78:	40 88 75 b6          	mov    %sil,-0x4a(%rbp)
 122ec7c:	41 0f b6 b6 19 02 00 	movzbl 0x219(%r14),%esi
 122ec83:	00 
 122ec84:	45 0f b6 86 21 02 00 	movzbl 0x221(%r14),%r8d
 122ec8b:	00 
 122ec8c:	41 0f b6 be 25 02 00 	movzbl 0x225(%r14),%edi
 122ec93:	00 
 122ec94:	40 80 e6 1f          	and    $0x1f,%sil
 122ec98:	41 80 e0 01          	and    $0x1,%r8b
 122ec9c:	40 80 e7 01          	and    $0x1,%dil
