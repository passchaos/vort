
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000122eb30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509>:
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
 122eca0:	88 45 a8             	mov    %al,-0x58(%rbp)
 122eca3:	84 c0                	test   %al,%al
 122eca5:	4d 8b 8e 60 01 00 00 	mov    0x160(%r14),%r9
 122ecac:	4c 89 8d 78 ff ff ff 	mov    %r9,-0x88(%rbp)
 122ecb3:	49 8b 9e 88 01 00 00 	mov    0x188(%r14),%rbx
 122ecba:	4d 8b 8e d8 01 00 00 	mov    0x1d8(%r14),%r9
 122ecc1:	4c 89 4d 80          	mov    %r9,-0x80(%rbp)
 122ecc5:	4d 8b a6 00 02 00 00 	mov    0x200(%r14),%r12
 122eccc:	41 0f b6 86 58 01 00 	movzbl 0x158(%r14),%eax
 122ecd3:	00 
 122ecd4:	88 45 b3             	mov    %al,-0x4d(%rbp)
 122ecd7:	41 0f b6 86 68 01 00 	movzbl 0x168(%r14),%eax
 122ecde:	00 
 122ecdf:	88 45 aa             	mov    %al,-0x56(%rbp)
 122ece2:	41 0f b6 86 78 01 00 	movzbl 0x178(%r14),%eax
 122ece9:	00 
 122ecea:	88 45 ad             	mov    %al,-0x53(%rbp)
 122eced:	41 0f b6 86 79 01 00 	movzbl 0x179(%r14),%eax
 122ecf4:	00 
 122ecf5:	88 45 b0             	mov    %al,-0x50(%rbp)
 122ecf8:	41 0f b6 96 80 01 00 	movzbl 0x180(%r14),%edx
 122ecff:	00 
 122ed00:	45 0f b6 8e a0 01 00 	movzbl 0x1a0(%r14),%r9d
 122ed07:	00 
 122ed08:	44 88 4d bb          	mov    %r9b,-0x45(%rbp)
 122ed0c:	45 0f b6 8e b0 01 00 	movzbl 0x1b0(%r14),%r9d
 122ed13:	00 
 122ed14:	44 88 4d b8          	mov    %r9b,-0x48(%rbp)
 122ed18:	45 0f b6 8e c0 01 00 	movzbl 0x1c0(%r14),%r9d
 122ed1f:	00 
 122ed20:	44 88 4d b5          	mov    %r9b,-0x4b(%rbp)
 122ed24:	45 0f b6 8e d0 01 00 	movzbl 0x1d0(%r14),%r9d
 122ed2b:	00 
 122ed2c:	44 88 4d b2          	mov    %r9b,-0x4e(%rbp)
 122ed30:	45 0f b6 8e e0 01 00 	movzbl 0x1e0(%r14),%r9d
 122ed37:	00 
 122ed38:	44 88 4d a9          	mov    %r9b,-0x57(%rbp)
 122ed3c:	45 0f b6 8e f0 01 00 	movzbl 0x1f0(%r14),%r9d
 122ed43:	00 
 122ed44:	44 88 4d ac          	mov    %r9b,-0x54(%rbp)
 122ed48:	45 0f b6 8e f1 01 00 	movzbl 0x1f1(%r14),%r9d
 122ed4f:	00 
 122ed50:	44 88 4d af          	mov    %r9b,-0x51(%rbp)
 122ed54:	41 0f b6 86 f8 01 00 	movzbl 0x1f8(%r14),%eax
 122ed5b:	00 
 122ed5c:	45 0f b6 8e 1a 02 00 	movzbl 0x21a(%r14),%r9d
 122ed63:	00 
 122ed64:	44 88 4d a5          	mov    %r9b,-0x5b(%rbp)
 122ed68:	45 0f b6 8e 1b 02 00 	movzbl 0x21b(%r14),%r9d
 122ed6f:	00 
 122ed70:	44 88 4d a4          	mov    %r9b,-0x5c(%rbp)
 122ed74:	45 0f b6 96 1f 02 00 	movzbl 0x21f(%r14),%r10d
 122ed7b:	00 
 122ed7c:	45 0f b6 8e 90 00 00 	movzbl 0x90(%r14),%r9d
 122ed83:	00 
 122ed84:	0f 95 45 a0          	setne  -0x60(%rbp)
 122ed88:	4d 89 ef             	mov    %r13,%r15
 122ed8b:	4d 85 ed             	test   %r13,%r13
 122ed8e:	0f 95 45 c0          	setne  -0x40(%rbp)
 122ed92:	4c 89 9d b8 fe ff ff 	mov    %r11,-0x148(%rbp)
 122ed99:	4d 85 db             	test   %r11,%r11
 122ed9c:	0f 95 45 a1          	setne  -0x5f(%rbp)
 122eda0:	88 55 a7             	mov    %dl,-0x59(%rbp)
 122eda3:	84 d2                	test   %dl,%dl
 122eda5:	0f 95 45 c4          	setne  -0x3c(%rbp)
 122eda9:	40 88 75 c8          	mov    %sil,-0x38(%rbp)
 122edad:	44 88 45 9f          	mov    %r8b,-0x61(%rbp)
 122edb1:	49 89 dd             	mov    %rbx,%r13
 122edb4:	48 85 db             	test   %rbx,%rbx
 122edb7:	0f 95 45 a2          	setne  -0x5e(%rbp)
 122edbb:	40 88 7d be          	mov    %dil,-0x42(%rbp)
 122edbf:	88 45 a6             	mov    %al,-0x5a(%rbp)
 122edc2:	84 c0                	test   %al,%al
 122edc4:	0f 95 45 c2          	setne  -0x3e(%rbp)
 122edc8:	4c 89 e3             	mov    %r12,%rbx
 122edcb:	4d 85 e4             	test   %r12,%r12
 122edce:	0f 95 45 a3          	setne  -0x5d(%rbp)
 122edd2:	41 80 e2 01          	and    $0x1,%r10b
 122edd6:	44 88 55 d0          	mov    %r10b,-0x30(%rbp)
 122edda:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 122edde:	c5 fc 11 85 f0 fd ff 	vmovups %ymm0,-0x210(%rbp)
 122ede5:	ff 
 122ede6:	c5 fc 11 85 10 fe ff 	vmovups %ymm0,-0x1f0(%rbp)
 122eded:	ff 
 122edee:	4c 8b a5 f0 fe ff ff 	mov    -0x110(%rbp),%r12
 122edf5:	45 84 c9             	test   %r9b,%r9b
 122edf8:	0f 84 2e 01 00 00    	je     122ef2c <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x3fc>
 122edfe:	0f b6 95 60 ff ff ff 	movzbl -0xa0(%rbp),%edx
 122ee05:	c4 c1 7c 10 46 4a    	vmovups 0x4a(%r14),%ymm0
 122ee0b:	c4 c1 7c 10 4e 6a    	vmovups 0x6a(%r14),%ymm1
 122ee11:	c5 fc 11 8d 10 fe ff 	vmovups %ymm1,-0x1f0(%rbp)
 122ee18:	ff 
 122ee19:	c5 fc 11 85 f0 fd ff 	vmovups %ymm0,-0x210(%rbp)
 122ee20:	ff 
 122ee21:	41 8b b6 8a 00 00 00 	mov    0x8a(%r14),%esi
 122ee28:	89 b5 7a fe ff ff    	mov    %esi,-0x186(%rbp)
 122ee2e:	41 0f b7 b6 8e 00 00 	movzwl 0x8e(%r14),%esi
 122ee35:	00 
 122ee36:	66 89 b5 7e fe ff ff 	mov    %si,-0x182(%rbp)
 122ee3d:	89 ce                	mov    %ecx,%esi
 122ee3f:	40 80 e6 03          	and    $0x3,%sil
 122ee43:	48 89 b5 60 ff ff ff 	mov    %rsi,-0xa0(%rbp)
 122ee4a:	40 88 b5 77 ff ff ff 	mov    %sil,-0x89(%rbp)
 122ee51:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 122ee58:	48 89 85 30 fe ff ff 	mov    %rax,-0x1d0(%rbp)
 122ee5f:	88 8d 38 fe ff ff    	mov    %cl,-0x1c8(%rbp)
 122ee65:	88 95 39 fe ff ff    	mov    %dl,-0x1c7(%rbp)
 122ee6b:	83 e2 7f             	and    $0x7f,%edx
 122ee6e:	48 89 95 48 ff ff ff 	mov    %rdx,-0xb8(%rbp)
 122ee75:	c4 c1 7c 10 46 4a    	vmovups 0x4a(%r14),%ymm0
 122ee7b:	c4 c1 7c 10 4e 6a    	vmovups 0x6a(%r14),%ymm1
 122ee81:	c5 fc 11 85 3a fe ff 	vmovups %ymm0,-0x1c6(%rbp)
 122ee88:	ff 
 122ee89:	c5 fc 11 8d 5a fe ff 	vmovups %ymm1,-0x1a6(%rbp)
 122ee90:	ff 
 122ee91:	48 8d 7d 8e          	lea    -0x72(%rbp),%rdi
 122ee95:	48 8d b5 30 fe ff ff 	lea    -0x1d0(%rbp),%rsi
 122ee9c:	c5 f8 77             	vzeroupper 
 122ee9f:	e8 cc 13 00 00       	call   1230270 <br.encoder.literal_context_split.Candidate.suffixCutoff>
 122eea4:	b0 01                	mov    $0x1,%al
 122eea6:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 122eead:	0f b7 45 8e          	movzwl -0x72(%rbp),%eax
 122eeb1:	48 89 85 68 ff ff ff 	mov    %rax,-0x98(%rbp)
 122eeb8:	80 7d a8 00          	cmpb   $0x0,-0x58(%rbp)
 122eebc:	0f 84 a0 00 00 00    	je     122ef62 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x432>
 122eec2:	80 7d ab 00          	cmpb   $0x0,-0x55(%rbp)
 122eec6:	0f 85 9e 00 00 00    	jne    122ef6a <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x43a>
 122eecc:	0f b6 55 ae          	movzbl -0x52(%rbp),%edx
 122eed0:	89 d0                	mov    %edx,%eax
 122eed2:	83 e0 01             	and    $0x1,%eax
 122eed5:	48 83 f0 03          	xor    $0x3,%rax
 122eed9:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 122eedd:	f6 c2 01             	test   $0x1,%dl
 122eee0:	0f 85 84 00 00 00    	jne    122ef6a <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x43a>
 122eee6:	f6 45 b1 01          	testb  $0x1,-0x4f(%rbp)
 122eeea:	75 7e                	jne    122ef6a <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x43a>
 122eeec:	b8 06 00 00 00       	mov    $0x6,%eax
 122eef1:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 122eef5:	80 7d b4 00          	cmpb   $0x0,-0x4c(%rbp)
 122eef9:	75 6f                	jne    122ef6a <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x43a>
 122eefb:	b8 05 00 00 00       	mov    $0x5,%eax
 122ef00:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 122ef04:	80 7d b7 00          	cmpb   $0x0,-0x49(%rbp)
 122ef08:	75 60                	jne    122ef6a <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x43a>
 122ef0a:	b8 04 00 00 00       	mov    $0x4,%eax
 122ef0f:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 122ef13:	80 7d ba 00          	cmpb   $0x0,-0x46(%rbp)
 122ef17:	75 51                	jne    122ef6a <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x43a>
 122ef19:	80 7d bd 01          	cmpb   $0x1,-0x43(%rbp)
 122ef1d:	b8 03 00 00 00       	mov    $0x3,%eax
 122ef22:	48 83 d8 00          	sbb    $0x0,%rax
 122ef26:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 122ef2a:	eb 3e                	jmp    122ef6a <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x43a>
 122ef2c:	48 c7 85 60 ff ff ff 	movq   $0x0,-0xa0(%rbp)
 122ef33:	00 00 00 00 
 122ef37:	48 c7 85 68 ff ff ff 	movq   $0x0,-0x98(%rbp)
 122ef3e:	00 00 00 00 
 122ef42:	48 c7 85 48 ff ff ff 	movq   $0x0,-0xb8(%rbp)
 122ef49:	00 00 00 00 
 122ef4d:	48 c7 85 50 ff ff ff 	movq   $0x0,-0xb0(%rbp)
 122ef54:	00 00 00 00 
 122ef58:	80 7d a8 00          	cmpb   $0x0,-0x58(%rbp)
 122ef5c:	0f 85 60 ff ff ff    	jne    122eec2 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x392>
 122ef62:	48 c7 45 90 00 00 00 	movq   $0x0,-0x70(%rbp)
 122ef69:	00 
 122ef6a:	4d 85 ff             	test   %r15,%r15
 122ef6d:	74 09                	je     122ef78 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x448>
 122ef6f:	41 0f b7 47 28       	movzwl 0x28(%r15),%eax
 122ef74:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 122ef78:	80 7d a7 00          	cmpb   $0x0,-0x59(%rbp)
 122ef7c:	74 71                	je     122efef <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x4bf>
 122ef7e:	80 7d aa 00          	cmpb   $0x0,-0x56(%rbp)
 122ef82:	75 76                	jne    122effa <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x4ca>
 122ef84:	0f b6 55 ad          	movzbl -0x53(%rbp),%edx
 122ef88:	89 d0                	mov    %edx,%eax
 122ef8a:	83 e0 01             	and    $0x1,%eax
 122ef8d:	48 83 f0 03          	xor    $0x3,%rax
 122ef91:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 122ef98:	f6 c2 01             	test   $0x1,%dl
 122ef9b:	75 5d                	jne    122effa <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x4ca>
 122ef9d:	f6 45 b0 01          	testb  $0x1,-0x50(%rbp)
 122efa1:	75 57                	jne    122effa <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x4ca>
 122efa3:	b8 06 00 00 00       	mov    $0x6,%eax
 122efa8:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 122efaf:	80 7d b3 00          	cmpb   $0x0,-0x4d(%rbp)
 122efb3:	75 45                	jne    122effa <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x4ca>
 122efb5:	b8 05 00 00 00       	mov    $0x5,%eax
 122efba:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 122efc1:	80 7d b6 00          	cmpb   $0x0,-0x4a(%rbp)
 122efc5:	75 33                	jne    122effa <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x4ca>
 122efc7:	b8 04 00 00 00       	mov    $0x4,%eax
 122efcc:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 122efd3:	80 7d b9 00          	cmpb   $0x0,-0x47(%rbp)
 122efd7:	75 21                	jne    122effa <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x4ca>
 122efd9:	80 7d bc 01          	cmpb   $0x1,-0x44(%rbp)
 122efdd:	b8 03 00 00 00       	mov    $0x3,%eax
 122efe2:	48 83 d8 00          	sbb    $0x0,%rax
 122efe6:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 122efed:	eb 0b                	jmp    122effa <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x4ca>
 122efef:	48 c7 85 78 ff ff ff 	movq   $0x0,-0x88(%rbp)
 122eff6:	00 00 00 00 
 122effa:	4d 85 ed             	test   %r13,%r13
 122effd:	74 0c                	je     122f00b <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x4db>
 122efff:	41 0f b7 45 28       	movzwl 0x28(%r13),%eax
 122f004:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 122f00b:	80 7d a6 00          	cmpb   $0x0,-0x5a(%rbp)
 122f00f:	74 62                	je     122f073 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x543>
 122f011:	80 7d a9 00          	cmpb   $0x0,-0x57(%rbp)
 122f015:	75 64                	jne    122f07b <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x54b>
 122f017:	0f b6 55 ac          	movzbl -0x54(%rbp),%edx
 122f01b:	89 d0                	mov    %edx,%eax
 122f01d:	83 e0 01             	and    $0x1,%eax
 122f020:	48 83 f0 03          	xor    $0x3,%rax
 122f024:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 122f028:	f6 c2 01             	test   $0x1,%dl
 122f02b:	75 4e                	jne    122f07b <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x54b>
 122f02d:	f6 45 af 01          	testb  $0x1,-0x51(%rbp)
 122f031:	75 48                	jne    122f07b <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x54b>
 122f033:	b8 06 00 00 00       	mov    $0x6,%eax
 122f038:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 122f03c:	80 7d b2 00          	cmpb   $0x0,-0x4e(%rbp)
 122f040:	75 39                	jne    122f07b <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x54b>
 122f042:	b8 05 00 00 00       	mov    $0x5,%eax
 122f047:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 122f04b:	80 7d b5 00          	cmpb   $0x0,-0x4b(%rbp)
 122f04f:	75 2a                	jne    122f07b <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x54b>
 122f051:	b8 04 00 00 00       	mov    $0x4,%eax
 122f056:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 122f05a:	80 7d b8 00          	cmpb   $0x0,-0x48(%rbp)
 122f05e:	75 1b                	jne    122f07b <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x54b>
 122f060:	80 7d bb 01          	cmpb   $0x1,-0x45(%rbp)
 122f064:	b8 03 00 00 00       	mov    $0x3,%eax
 122f069:	48 83 d8 00          	sbb    $0x0,%rax
 122f06d:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 122f071:	eb 08                	jmp    122f07b <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x54b>
 122f073:	48 c7 45 80 00 00 00 	movq   $0x0,-0x80(%rbp)
 122f07a:	00 
 122f07b:	48 85 db             	test   %rbx,%rbx
 122f07e:	74 08                	je     122f088 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x558>
 122f080:	0f b7 43 28          	movzwl 0x28(%rbx),%eax
 122f084:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 122f088:	48 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%rax
 122f08f:	49 8d 14 04          	lea    (%r12,%rax,1),%rdx
 122f093:	48 81 c2 b0 00 00 00 	add    $0xb0,%rdx
 122f09a:	48 8b 85 b8 fe ff ff 	mov    -0x148(%rbp),%rax
 122f0a1:	48 85 c0             	test   %rax,%rax
 122f0a4:	74 0d                	je     122f0b3 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x583>
 122f0a6:	0f b7 40 50          	movzwl 0x50(%rax),%eax
 122f0aa:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 122f0b1:	eb 0b                	jmp    122f0be <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x58e>
 122f0b3:	48 c7 85 58 ff ff ff 	movq   $0x0,-0xa8(%rbp)
 122f0ba:	00 00 00 00 
 122f0be:	0f b6 7d c8          	movzbl -0x38(%rbp),%edi
 122f0c2:	44 0f b6 45 9f       	movzbl -0x61(%rbp),%r8d
 122f0c7:	44 0f b6 4d be       	movzbl -0x42(%rbp),%r9d
 122f0cc:	44 0f b6 55 a0       	movzbl -0x60(%rbp),%r10d
 122f0d1:	44 0f b6 5d c0       	movzbl -0x40(%rbp),%r11d
 122f0d6:	0f b6 5d a1          	movzbl -0x5f(%rbp),%ebx
 122f0da:	44 0f b6 7d c4       	movzbl -0x3c(%rbp),%r15d
 122f0df:	44 0f b6 65 a2       	movzbl -0x5e(%rbp),%r12d
 122f0e4:	44 0f b6 6d c2       	movzbl -0x3e(%rbp),%r13d
 122f0e9:	0f b6 45 a3          	movzbl -0x5d(%rbp),%eax
 122f0ed:	0f b6 4d d0          	movzbl -0x30(%rbp),%ecx
 122f0f1:	48 8b b5 48 ff ff ff 	mov    -0xb8(%rbp),%rsi
 122f0f8:	48 89 32             	mov    %rsi,(%rdx)
 122f0fb:	48 8b 75 90          	mov    -0x70(%rbp),%rsi
 122f0ff:	48 89 72 08          	mov    %rsi,0x8(%rdx)
 122f103:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 122f10a:	48 89 72 10          	mov    %rsi,0x10(%rdx)
 122f10e:	48 8b 75 80          	mov    -0x80(%rbp),%rsi
 122f112:	48 89 72 18          	mov    %rsi,0x18(%rdx)
 122f116:	48 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%rsi
 122f11d:	48 89 72 20          	mov    %rsi,0x20(%rdx)
 122f121:	40 88 7a 28          	mov    %dil,0x28(%rdx)
 122f125:	44 88 42 29          	mov    %r8b,0x29(%rdx)
 122f129:	44 88 4a 2a          	mov    %r9b,0x2a(%rdx)
 122f12d:	0f b6 75 a5          	movzbl -0x5b(%rbp),%esi
 122f131:	40 80 e6 03          	and    $0x3,%sil
 122f135:	40 88 72 2b          	mov    %sil,0x2b(%rdx)
 122f139:	0f b6 75 a4          	movzbl -0x5c(%rbp),%esi
 122f13d:	40 80 e6 0f          	and    $0xf,%sil
 122f141:	40 88 72 2c          	mov    %sil,0x2c(%rdx)
 122f145:	48 8b b5 60 ff ff ff 	mov    -0xa0(%rbp),%rsi
 122f14c:	40 88 72 2d          	mov    %sil,0x2d(%rdx)
 122f150:	48 8b b5 50 ff ff ff 	mov    -0xb0(%rbp),%rsi
 122f157:	40 88 72 2e          	mov    %sil,0x2e(%rdx)
 122f15b:	48 8b b5 68 ff ff ff 	mov    -0x98(%rbp),%rsi
 122f162:	66 89 72 2f          	mov    %si,0x2f(%rdx)
 122f166:	c5 fc 10 85 f0 fd ff 	vmovups -0x210(%rbp),%ymm0
 122f16d:	ff 
 122f16e:	c5 fc 10 8d 10 fe ff 	vmovups -0x1f0(%rbp),%ymm1
 122f175:	ff 
 122f176:	c5 fc 11 42 31       	vmovups %ymm0,0x31(%rdx)
 122f17b:	c5 fc 11 4a 51       	vmovups %ymm1,0x51(%rdx)
 122f180:	44 88 52 71          	mov    %r10b,0x71(%rdx)
 122f184:	44 88 5a 72          	mov    %r11b,0x72(%rdx)
 122f188:	88 5a 73             	mov    %bl,0x73(%rdx)
 122f18b:	44 88 7a 74          	mov    %r15b,0x74(%rdx)
 122f18f:	44 88 62 75          	mov    %r12b,0x75(%rdx)
 122f193:	44 88 6a 76          	mov    %r13b,0x76(%rdx)
 122f197:	88 42 77             	mov    %al,0x77(%rdx)
 122f19a:	88 4a 78             	mov    %cl,0x78(%rdx)
 122f19d:	4c 8b a5 98 fe ff ff 	mov    -0x168(%rbp),%r12
 122f1a4:	48 8b 9d a0 fe ff ff 	mov    -0x160(%rbp),%rbx
 122f1ab:	4c 8b ad a8 fe ff ff 	mov    -0x158(%rbp),%r13
 122f1b2:	4c 8b bd b0 fe ff ff 	mov    -0x150(%rbp),%r15
 122f1b9:	4d 01 ef             	add    %r13,%r15
 122f1bc:	73 49                	jae    122f207 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x6d7>
 122f1be:	80 bd 08 ff ff ff 00 	cmpb   $0x0,-0xf8(%rbp)
 122f1c5:	74 24                	je     122f1eb <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x6bb>
 122f1c7:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 122f1ce:	48 69 8d 00 ff ff ff 	imul   $0x118,-0x100(%rbp),%rcx
 122f1d5:	18 01 00 00 
 122f1d9:	48 c7 44 08 68 a1 02 	movq   $0x11202a1,0x68(%rax,%rcx,1)
 122f1e0:	12 01 
 122f1e2:	48 c7 44 08 70 0f 00 	movq   $0xf,0x70(%rax,%rcx,1)
 122f1e9:	00 00 
 122f1eb:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 122f1f2:	c5 f8 77             	vzeroupper 
 122f1f5:	e8 76 7f 04 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 122f1fa:	66 41 c7 44 24 10 43 	movw   $0x43,0x10(%r12)
 122f201:	00 
 122f202:	e9 a4 01 00 00       	jmp    122f3ab <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x87b>
 122f207:	4d 89 ef             	mov    %r13,%r15
 122f20a:	49 c1 ed 03          	shr    $0x3,%r13
 122f20e:	49 83 fd 41          	cmp    $0x41,%r13
 122f212:	b9 40 00 00 00       	mov    $0x40,%ecx
 122f217:	49 0f 43 cd          	cmovae %r13,%rcx
 122f21b:	48 81 f9 00 10 00 00 	cmp    $0x1000,%rcx
 122f222:	41 bd 00 10 00 00    	mov    $0x1000,%r13d
 122f228:	4c 0f 42 e9          	cmovb  %rcx,%r13
 122f22c:	31 c0                	xor    %eax,%eax
 122f22e:	84 c0                	test   %al,%al
 122f230:	0f 85 31 01 00 00    	jne    122f367 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x837>
 122f236:	48 8b 3b             	mov    (%rbx),%rdi
 122f239:	48 8b 43 08          	mov    0x8(%rbx),%rax
 122f23d:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 122f241:	4c 89 ee             	mov    %r13,%rsi
 122f244:	31 d2                	xor    %edx,%edx
 122f246:	48 89 4d 90          	mov    %rcx,-0x70(%rbp)
 122f24a:	c5 f8 77             	vzeroupper 
 122f24d:	ff 10                	call   *(%rax)
 122f24f:	48 85 c0             	test   %rax,%rax
 122f252:	0f 84 0f 01 00 00    	je     122f367 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x837>
 122f258:	4c 8b 55 18          	mov    0x18(%rbp),%r10
 122f25c:	48 89 85 30 ff ff ff 	mov    %rax,-0xd0(%rbp)
 122f263:	48 c7 85 38 ff ff ff 	movq   $0x0,-0xc8(%rbp)
 122f26a:	00 00 00 00 
 122f26e:	4c 89 ad 40 ff ff ff 	mov    %r13,-0xc0(%rbp)
 122f275:	c6 85 f0 fd ff ff 00 	movb   $0x0,-0x210(%rbp)
 122f27c:	c6 45 8e 00          	movb   $0x0,-0x72(%rbp)
 122f280:	48 8d 85 30 ff ff ff 	lea    -0xd0(%rbp),%rax
 122f287:	48 89 85 30 fe ff ff 	mov    %rax,-0x1d0(%rbp)
 122f28e:	66 c7 85 38 fe ff ff 	movw   $0x0,-0x1c8(%rbp)
 122f295:	00 00 
 122f297:	48 8d b5 30 fe ff ff 	lea    -0x1d0(%rbp),%rsi
 122f29e:	48 89 df             	mov    %rbx,%rdi
 122f2a1:	48 8b 95 c8 fe ff ff 	mov    -0x138(%rbp),%rdx
 122f2a8:	4c 89 f9             	mov    %r15,%rcx
 122f2ab:	4c 8b 85 c0 fe ff ff 	mov    -0x140(%rbp),%r8
 122f2b2:	4c 8b 4d 10          	mov    0x10(%rbp),%r9
 122f2b6:	41 56                	push   %r14
 122f2b8:	41 52                	push   %r10
 122f2ba:	e8 81 c7 f8 ff       	call   11bba40 <br.encodeCommandPlanWithOptionsWrite>
 122f2bf:	48 83 c4 10          	add    $0x10,%rsp
 122f2c3:	66 85 c0             	test   %ax,%ax
 122f2c6:	0f 85 f1 00 00 00    	jne    122f3bd <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x88d>
 122f2cc:	48 8d bd 80 fe ff ff 	lea    -0x180(%rbp),%rdi
 122f2d3:	48 8d b5 30 ff ff ff 	lea    -0xd0(%rbp),%rsi
 122f2da:	48 89 da             	mov    %rbx,%rdx
 122f2dd:	e8 ae 7f f8 ff       	call   11b7290 <array_list.Aligned(u8,null).toOwnedSlice>
 122f2e2:	48 89 d8             	mov    %rbx,%rax
 122f2e5:	0f b7 9d 90 fe ff ff 	movzwl -0x170(%rbp),%ebx
 122f2ec:	48 85 db             	test   %rbx,%rbx
 122f2ef:	0f 85 33 01 00 00    	jne    122f428 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x8f8>
 122f2f5:	48 8b 9d 80 fe ff ff 	mov    -0x180(%rbp),%rbx
 122f2fc:	4c 8b b5 88 fe ff ff 	mov    -0x178(%rbp),%r14
 122f303:	80 bd 08 ff ff ff 00 	cmpb   $0x0,-0xf8(%rbp)
 122f30a:	74 3c                	je     122f348 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x818>
 122f30c:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 122f313:	48 8b 8d 00 ff ff ff 	mov    -0x100(%rbp),%rcx
 122f31a:	48 69 d1 18 01 00 00 	imul   $0x118,%rcx,%rdx
 122f321:	4c 89 74 10 58       	mov    %r14,0x58(%rax,%rdx,1)
 122f326:	c6 44 10 60 01       	movb   $0x1,0x60(%rax,%rdx,1)
 122f32b:	48 89 9c c8 d0 32 02 	mov    %rbx,0x232d0(%rax,%rcx,8)
 122f332:	00 
 122f333:	0f b6 95 20 ff ff ff 	movzbl -0xe0(%rbp),%edx
 122f33a:	80 e2 0f             	and    $0xf,%dl
 122f33d:	80 fa 07             	cmp    $0x7,%dl
 122f340:	0f 94 84 08 d3 42 02 	sete   0x242d3(%rax,%rcx,1)
 122f347:	00 
 122f348:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 122f34f:	e8 1c 7e 04 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 122f354:	66 41 c7 44 24 10 00 	movw   $0x0,0x10(%r12)
 122f35b:	00 
 122f35c:	49 89 1c 24          	mov    %rbx,(%r12)
 122f360:	4d 89 74 24 08       	mov    %r14,0x8(%r12)
 122f365:	eb 44                	jmp    122f3ab <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x87b>
 122f367:	80 bd 08 ff ff ff 00 	cmpb   $0x0,-0xf8(%rbp)
 122f36e:	74 24                	je     122f394 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x864>
 122f370:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 122f377:	48 69 8d 00 ff ff ff 	imul   $0x118,-0x100(%rbp),%rcx
 122f37e:	18 01 00 00 
 122f382:	48 c7 44 08 68 b0 f9 	movq   $0x111f9b0,0x68(%rax,%rcx,1)
 122f389:	11 01 
 122f38b:	48 c7 44 08 70 0b 00 	movq   $0xb,0x70(%rax,%rcx,1)
 122f392:	00 00 
 122f394:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 122f39b:	c5 f8 77             	vzeroupper 
 122f39e:	e8 cd 7d 04 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 122f3a3:	66 41 c7 44 24 10 1a 	movw   $0x1a,0x10(%r12)
 122f3aa:	00 
 122f3ab:	48 81 c4 18 02 00 00 	add    $0x218,%rsp
 122f3b2:	5b                   	pop    %rbx
 122f3b3:	41 5c                	pop    %r12
 122f3b5:	41 5d                	pop    %r13
 122f3b7:	41 5e                	pop    %r14
 122f3b9:	41 5f                	pop    %r15
 122f3bb:	5d                   	pop    %rbp
 122f3bc:	c3                   	ret    
 122f3bd:	48 89 d9             	mov    %rbx,%rcx
 122f3c0:	89 c3                	mov    %eax,%ebx
 122f3c2:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 122f3c9:	48 85 d2             	test   %rdx,%rdx
 122f3cc:	74 17                	je     122f3e5 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x8b5>
 122f3ce:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 122f3d5:	48 8b 39             	mov    (%rcx),%rdi
 122f3d8:	48 8b 41 08          	mov    0x8(%rcx),%rax
 122f3dc:	31 c9                	xor    %ecx,%ecx
 122f3de:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 122f3e2:	ff 50 18             	call   *0x18(%rax)
 122f3e5:	80 bd 08 ff ff ff 00 	cmpb   $0x0,-0xf8(%rbp)
 122f3ec:	74 26                	je     122f414 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x8e4>
 122f3ee:	48 69 85 00 ff ff ff 	imul   $0x118,-0x100(%rbp),%rax
 122f3f5:	18 01 00 00 
 122f3f9:	48 8b 8d f0 fe ff ff 	mov    -0x110(%rbp),%rcx
 122f400:	0f b7 d3             	movzwl %bx,%edx
 122f403:	c1 e2 04             	shl    $0x4,%edx
 122f406:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 122f40d:	01 
 122f40e:	c5 f8 11 44 01 68    	vmovups %xmm0,0x68(%rcx,%rax,1)
 122f414:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 122f41b:	e8 50 7d 04 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 122f420:	66 41 89 5c 24 10    	mov    %bx,0x10(%r12)
 122f426:	eb 83                	jmp    122f3ab <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x87b>
 122f428:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 122f42f:	48 85 d2             	test   %rdx,%rdx
 122f432:	74 17                	je     122f44b <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x91b>
 122f434:	48 8b b5 30 ff ff ff 	mov    -0xd0(%rbp),%rsi
 122f43b:	48 8b 38             	mov    (%rax),%rdi
 122f43e:	48 8b 40 08          	mov    0x8(%rax),%rax
 122f442:	31 c9                	xor    %ecx,%ecx
 122f444:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 122f448:	ff 50 18             	call   *0x18(%rax)
 122f44b:	80 bd 08 ff ff ff 00 	cmpb   $0x0,-0xf8(%rbp)
 122f452:	74 25                	je     122f479 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x949>
 122f454:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 122f45b:	48 69 8d 00 ff ff ff 	imul   $0x118,-0x100(%rbp),%rcx
 122f462:	18 01 00 00 
 122f466:	89 da                	mov    %ebx,%edx
 122f468:	c1 e2 04             	shl    $0x4,%edx
 122f46b:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 122f472:	01 
 122f473:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 122f479:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 122f480:	e8 eb 7c 04 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 122f485:	66 41 89 5c 24 10    	mov    %bx,0x10(%r12)
 122f48b:	e9 1b ff ff ff       	jmp    122f3ab <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509+0x87b>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
