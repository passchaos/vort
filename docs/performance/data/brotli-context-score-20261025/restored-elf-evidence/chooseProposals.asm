
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/ee59b567d9fa359fa365d21c6dd4ba7f/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120ee50 <br.encoder.literal_context_split.chooseProposals>:
 120ee50:	55                   	push   %rbp
 120ee51:	48 89 e5             	mov    %rsp,%rbp
 120ee54:	41 57                	push   %r15
 120ee56:	41 56                	push   %r14
 120ee58:	41 55                	push   %r13
 120ee5a:	41 54                	push   %r12
 120ee5c:	53                   	push   %rbx
 120ee5d:	48 81 ec b8 04 00 00 	sub    $0x4b8,%rsp
 120ee64:	4c 89 cb             	mov    %r9,%rbx
 120ee67:	4d 89 c7             	mov    %r8,%r15
 120ee6a:	48 89 4d 88          	mov    %rcx,-0x78(%rbp)
 120ee6e:	48 89 d0             	mov    %rdx,%rax
 120ee71:	48 89 f2             	mov    %rsi,%rdx
 120ee74:	48 89 bd 18 fd ff ff 	mov    %rdi,-0x2e8(%rbp)
 120ee7b:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 120ee7f:	be 08 04 04 00       	mov    $0x40408,%esi
 120ee84:	48 89 95 58 ff ff ff 	mov    %rdx,-0xa8(%rbp)
 120ee8b:	48 89 d7             	mov    %rdx,%rdi
 120ee8e:	ba 03 00 00 00       	mov    $0x3,%edx
 120ee93:	48 89 8d 50 ff ff ff 	mov    %rcx,-0xb0(%rbp)
 120ee9a:	48 89 85 48 ff ff ff 	mov    %rax,-0xb8(%rbp)
 120eea1:	ff 10                	call   *(%rax)
 120eea3:	48 85 c0             	test   %rax,%rax
 120eea6:	0f 84 f0 02 00 00    	je     120f19c <br.encoder.literal_context_split.chooseProposals+0x34c>
 120eeac:	49 89 c4             	mov    %rax,%r12
 120eeaf:	ba 08 04 04 00       	mov    $0x40408,%edx
 120eeb4:	48 89 c7             	mov    %rax,%rdi
 120eeb7:	31 f6                	xor    %esi,%esi
 120eeb9:	e8 82 6f 08 00       	call   1295e40 <compiler_rt.memset>
 120eebe:	48 83 7d 10 00       	cmpq   $0x0,0x10(%rbp)
 120eec3:	0f 84 ea 02 00 00    	je     120f1b3 <br.encoder.literal_context_split.chooseProposals+0x363>
 120eec9:	4d 8d b4 24 08 00 04 	lea    0x40008(%r12),%r14
 120eed0:	00 
 120eed1:	49 8d 44 24 08       	lea    0x8(%r12),%rax
 120eed6:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 120eeda:	49 8d 84 24 08 00 01 	lea    0x10008(%r12),%rax
 120eee1:	00 
 120eee2:	48 89 85 18 ff ff ff 	mov    %rax,-0xe8(%rbp)
 120eee9:	49 8d 84 24 08 00 02 	lea    0x20008(%r12),%rax
 120eef0:	00 
 120eef1:	48 89 85 20 ff ff ff 	mov    %rax,-0xe0(%rbp)
 120eef8:	4c 89 e0             	mov    %r12,%rax
 120eefb:	48 05 08 00 03 00    	add    $0x30008,%rax
 120ef01:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 120ef08:	48 c7 45 b8 00 00 00 	movq   $0x0,-0x48(%rbp)
 120ef0f:	00 
 120ef10:	31 c0                	xor    %eax,%eax
 120ef12:	4c 89 65 a0          	mov    %r12,-0x60(%rbp)
 120ef16:	4c 89 b5 38 ff ff ff 	mov    %r14,-0xc8(%rbp)
 120ef1d:	48 89 9d 30 ff ff ff 	mov    %rbx,-0xd0(%rbp)
 120ef24:	4c 89 bd 40 ff ff ff 	mov    %r15,-0xc0(%rbp)
 120ef2b:	eb 26                	jmp    120ef53 <br.encoder.literal_context_split.chooseProposals+0x103>
 120ef2d:	0f 1f 00             	nopl   (%rax)
 120ef30:	4c 01 7d b8          	add    %r15,-0x48(%rbp)
 120ef34:	48 8b 9d 30 ff ff ff 	mov    -0xd0(%rbp),%rbx
 120ef3b:	4c 8b bd 40 ff ff ff 	mov    -0xc0(%rbp),%r15
 120ef42:	48 8b 45 80          	mov    -0x80(%rbp),%rax
 120ef46:	48 ff c0             	inc    %rax
 120ef49:	48 3b 45 10          	cmp    0x10(%rbp),%rax
 120ef4d:	0f 84 52 02 00 00    	je     120f1a5 <br.encoder.literal_context_split.chooseProposals+0x355>
 120ef53:	48 89 45 80          	mov    %rax,-0x80(%rbp)
 120ef57:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 120ef5b:	48 c1 e0 05          	shl    $0x5,%rax
 120ef5f:	48 8b 0c 03          	mov    (%rbx,%rax,1),%rcx
 120ef63:	48 8b 74 03 08       	mov    0x8(%rbx,%rax,1),%rsi
 120ef68:	48 89 c8             	mov    %rcx,%rax
 120ef6b:	48 01 f0             	add    %rsi,%rax
 120ef6e:	0f 92 85 08 fe ff ff 	setb   -0x1f8(%rbp)
 120ef75:	0f 82 38 02 00 00    	jb     120f1b3 <br.encoder.literal_context_split.chooseProposals+0x363>
 120ef7b:	4c 39 f8             	cmp    %r15,%rax
 120ef7e:	0f 87 2f 02 00 00    	ja     120f1b3 <br.encoder.literal_context_split.chooseProposals+0x363>
 120ef84:	48 39 c8             	cmp    %rcx,%rax
 120ef87:	74 b9                	je     120ef42 <br.encoder.literal_context_split.chooseProposals+0xf2>
 120ef89:	48 89 f2             	mov    %rsi,%rdx
 120ef8c:	48 8b 45 88          	mov    -0x78(%rbp),%rax
 120ef90:	48 8d 34 08          	lea    (%rax,%rcx,1),%rsi
 120ef94:	48 83 fa 01          	cmp    $0x1,%rdx
 120ef98:	48 83 d2 00          	adc    $0x0,%rdx
 120ef9c:	48 89 55 90          	mov    %rdx,-0x70(%rbp)
 120efa0:	b8 01 00 00 00       	mov    $0x1,%eax
 120efa5:	48 29 c8             	sub    %rcx,%rax
 120efa8:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 120efac:	48 f7 d9             	neg    %rcx
 120efaf:	45 31 ff             	xor    %r15d,%r15d
 120efb2:	48 89 4d c0          	mov    %rcx,-0x40(%rbp)
 120efb6:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 120efba:	eb 43                	jmp    120efff <br.encoder.literal_context_split.chooseProposals+0x1af>
 120efbc:	0f 1f 40 00          	nopl   0x0(%rax)
 120efc0:	41 be 07 00 00 00    	mov    $0x7,%r14d
 120efc6:	49 c1 e6 0a          	shl    $0xa,%r14
 120efca:	4c 03 b5 28 ff ff ff 	add    -0xd8(%rbp),%r14
 120efd1:	41 c1 e5 0a          	shl    $0xa,%r13d
 120efd5:	4d 01 f5             	add    %r14,%r13
 120efd8:	41 ff 44 95 00       	incl   0x0(%r13,%rdx,4)
 120efdd:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 120efe1:	4c 01 f8             	add    %r15,%rax
 120efe4:	48 ff c0             	inc    %rax
 120efe7:	49 89 04 24          	mov    %rax,(%r12)
 120efeb:	49 ff c7             	inc    %r15
 120efee:	4c 39 7d 90          	cmp    %r15,-0x70(%rbp)
 120eff2:	4c 8b b5 38 ff ff ff 	mov    -0xc8(%rbp),%r14
 120eff9:	0f 84 31 ff ff ff    	je     120ef30 <br.encoder.literal_context_split.chooseProposals+0xe0>
 120efff:	4c 39 f9             	cmp    %r15,%rcx
 120f002:	75 0c                	jne    120f010 <br.encoder.literal_context_split.chooseProposals+0x1c0>
 120f004:	31 db                	xor    %ebx,%ebx
 120f006:	eb 14                	jmp    120f01c <br.encoder.literal_context_split.chooseProposals+0x1cc>
 120f008:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120f00f:	00 
 120f010:	42 0f b6 5c 3e ff    	movzbl -0x1(%rsi,%r15,1),%ebx
 120f016:	4c 39 7d 98          	cmp    %r15,-0x68(%rbp)
 120f01a:	75 04                	jne    120f020 <br.encoder.literal_context_split.chooseProposals+0x1d0>
 120f01c:	31 c9                	xor    %ecx,%ecx
 120f01e:	eb 06                	jmp    120f026 <br.encoder.literal_context_split.chooseProposals+0x1d6>
 120f020:	42 0f b6 4c 3e fe    	movzbl -0x2(%rsi,%r15,1),%ecx
 120f026:	42 0f b6 04 3e       	movzbl (%rsi,%r15,1),%eax
 120f02b:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 120f02f:	44 8d 24 85 00 00 00 	lea    0x0(,%rax,4),%r12d
 120f036:	00 
 120f037:	43 ff 04 26          	incl   (%r14,%r12,1)
 120f03b:	89 d8                	mov    %ebx,%eax
 120f03d:	24 3f                	and    $0x3f,%al
 120f03f:	0f b6 c0             	movzbl %al,%eax
 120f042:	c1 e0 0a             	shl    $0xa,%eax
 120f045:	48 03 45 a8          	add    -0x58(%rbp),%rax
 120f049:	41 ff 04 04          	incl   (%r12,%rax,1)
 120f04d:	89 d8                	mov    %ebx,%eax
 120f04f:	c0 e8 02             	shr    $0x2,%al
 120f052:	0f b6 c0             	movzbl %al,%eax
 120f055:	c1 e0 0a             	shl    $0xa,%eax
 120f058:	48 03 85 18 ff ff ff 	add    -0xe8(%rbp),%rax
 120f05f:	41 ff 04 04          	incl   (%r12,%rax,1)
 120f063:	44 0f b6 eb          	movzbl %bl,%r13d
 120f067:	48 89 4d b0          	mov    %rcx,-0x50(%rbp)
 120f06b:	44 0f b6 f1          	movzbl %cl,%r14d
 120f06f:	bf 02 00 00 00       	mov    $0x2,%edi
 120f074:	44 89 ee             	mov    %r13d,%esi
 120f077:	44 89 f2             	mov    %r14d,%edx
 120f07a:	e8 31 f3 fa ff       	call   11be3b0 <br.encoder.literal_context.value>
 120f07f:	c1 e0 0a             	shl    $0xa,%eax
 120f082:	48 03 85 20 ff ff ff 	add    -0xe0(%rbp),%rax
 120f089:	41 ff 04 04          	incl   (%r12,%rax,1)
 120f08d:	45 84 ed             	test   %r13b,%r13b
 120f090:	74 13                	je     120f0a5 <br.encoder.literal_context_split.chooseProposals+0x255>
 120f092:	41 81 fd ff 00 00 00 	cmp    $0xff,%r13d
 120f099:	0f 85 91 00 00 00    	jne    120f130 <br.encoder.literal_context_split.chooseProposals+0x2e0>
 120f09f:	41 bd 38 00 00 00    	mov    $0x38,%r13d
 120f0a5:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 120f0a9:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 120f0ad:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 120f0b1:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 120f0b5:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 120f0b9:	40 84 ff             	test   %dil,%dil
 120f0bc:	0f 84 04 ff ff ff    	je     120efc6 <br.encoder.literal_context_split.chooseProposals+0x176>
 120f0c2:	41 81 fe ff 00 00 00 	cmp    $0xff,%r14d
 120f0c9:	0f 84 f1 fe ff ff    	je     120efc0 <br.encoder.literal_context_split.chooseProposals+0x170>
 120f0cf:	8d 47 ff             	lea    -0x1(%rdi),%eax
 120f0d2:	41 be 01 00 00 00    	mov    $0x1,%r14d
 120f0d8:	3c 0f                	cmp    $0xf,%al
 120f0da:	0f 82 e6 fe ff ff    	jb     120efc6 <br.encoder.literal_context_split.chooseProposals+0x176>
 120f0e0:	8d 47 f0             	lea    -0x10(%rdi),%eax
 120f0e3:	41 be 02 00 00 00    	mov    $0x2,%r14d
 120f0e9:	3c 30                	cmp    $0x30,%al
 120f0eb:	0f 82 d5 fe ff ff    	jb     120efc6 <br.encoder.literal_context_split.chooseProposals+0x176>
 120f0f1:	41 be 03 00 00 00    	mov    $0x3,%r14d
 120f0f7:	40 80 ff 3f          	cmp    $0x3f,%dil
 120f0fb:	0f 8f c5 fe ff ff    	jg     120efc6 <br.encoder.literal_context_split.chooseProposals+0x176>
 120f101:	41 be 04 00 00 00    	mov    $0x4,%r14d
 120f107:	40 80 ff c0          	cmp    $0xc0,%dil
 120f10b:	0f 82 b5 fe ff ff    	jb     120efc6 <br.encoder.literal_context_split.chooseProposals+0x176>
 120f111:	40 80 c7 40          	add    $0x40,%dil
 120f115:	40 80 ff 30          	cmp    $0x30,%dil
 120f119:	41 be 06 00 00 00    	mov    $0x6,%r14d
 120f11f:	49 83 de 00          	sbb    $0x0,%r14
 120f123:	e9 9e fe ff ff       	jmp    120efc6 <br.encoder.literal_context_split.chooseProposals+0x176>
 120f128:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120f12f:	00 
 120f130:	8d 43 ff             	lea    -0x1(%rbx),%eax
 120f133:	41 bd 08 00 00 00    	mov    $0x8,%r13d
 120f139:	3c 0f                	cmp    $0xf,%al
 120f13b:	4c 8b 65 a0          	mov    -0x60(%rbp),%r12
 120f13f:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 120f143:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 120f147:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 120f14b:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 120f14f:	0f 82 64 ff ff ff    	jb     120f0b9 <br.encoder.literal_context_split.chooseProposals+0x269>
 120f155:	8d 43 f0             	lea    -0x10(%rbx),%eax
 120f158:	41 bd 10 00 00 00    	mov    $0x10,%r13d
 120f15e:	3c 30                	cmp    $0x30,%al
 120f160:	0f 82 53 ff ff ff    	jb     120f0b9 <br.encoder.literal_context_split.chooseProposals+0x269>
 120f166:	41 bd 18 00 00 00    	mov    $0x18,%r13d
 120f16c:	80 fb 3f             	cmp    $0x3f,%bl
 120f16f:	0f 8f 44 ff ff ff    	jg     120f0b9 <br.encoder.literal_context_split.chooseProposals+0x269>
 120f175:	41 bd 20 00 00 00    	mov    $0x20,%r13d
 120f17b:	80 fb c0             	cmp    $0xc0,%bl
 120f17e:	0f 82 35 ff ff ff    	jb     120f0b9 <br.encoder.literal_context_split.chooseProposals+0x269>
 120f184:	80 c3 40             	add    $0x40,%bl
 120f187:	31 c0                	xor    %eax,%eax
 120f189:	80 fb 30             	cmp    $0x30,%bl
 120f18c:	0f 93 c0             	setae  %al
 120f18f:	4c 8d 2c c5 28 00 00 	lea    0x28(,%rax,8),%r13
 120f196:	00 
 120f197:	e9 1d ff ff ff       	jmp    120f0b9 <br.encoder.literal_context_split.chooseProposals+0x269>
 120f19c:	66 bb 1a 00          	mov    $0x1a,%bx
 120f1a0:	e9 f9 00 00 00       	jmp    120f29e <br.encoder.literal_context_split.chooseProposals+0x44e>
 120f1a5:	48 81 7d b8 80 00 00 	cmpq   $0x80,-0x48(%rbp)
 120f1ac:	00 
 120f1ad:	0f 83 24 02 00 00    	jae    120f3d7 <br.encoder.literal_context_split.chooseProposals+0x587>
 120f1b3:	ba 08 04 04 00       	mov    $0x40408,%edx
 120f1b8:	48 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%rdi
 120f1bf:	4c 89 e6             	mov    %r12,%rsi
 120f1c2:	b9 03 00 00 00       	mov    $0x3,%ecx
 120f1c7:	4c 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%r8
 120f1ce:	48 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%rax
 120f1d5:	ff 50 18             	call   *0x18(%rax)
 120f1d8:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 120f1dc:	c5 fc 11 85 50 fc ff 	vmovups %ymm0,-0x3b0(%rbp)
 120f1e3:	ff 
 120f1e4:	c5 fc 11 85 30 fc ff 	vmovups %ymm0,-0x3d0(%rbp)
 120f1eb:	ff 
 120f1ec:	48 c7 85 6e fc ff ff 	movq   $0x0,-0x392(%rbp)
 120f1f3:	00 00 00 00 
 120f1f7:	c7 85 68 ff ff ff 00 	movl   $0x0,-0x98(%rbp)
 120f1fe:	00 00 00 
 120f201:	c7 85 6b ff ff ff 00 	movl   $0x0,-0x95(%rbp)
 120f208:	00 00 00 
 120f20b:	c5 fc 11 85 80 fc ff 	vmovups %ymm0,-0x380(%rbp)
 120f212:	ff 
 120f213:	c5 fc 11 85 a0 fc ff 	vmovups %ymm0,-0x360(%rbp)
 120f21a:	ff 
 120f21b:	48 c7 85 be fc ff ff 	movq   $0x0,-0x342(%rbp)
 120f222:	00 00 00 00 
 120f226:	c7 85 70 ff ff ff 00 	movl   $0x0,-0x90(%rbp)
 120f22d:	00 00 00 
 120f230:	c7 85 73 ff ff ff 00 	movl   $0x0,-0x8d(%rbp)
 120f237:	00 00 00 
 120f23a:	c5 fc 11 85 d0 fc ff 	vmovups %ymm0,-0x330(%rbp)
 120f241:	ff 
 120f242:	c5 fc 11 85 f0 fc ff 	vmovups %ymm0,-0x310(%rbp)
 120f249:	ff 
 120f24a:	48 c7 85 0e fd ff ff 	movq   $0x0,-0x2f2(%rbp)
 120f251:	00 00 00 00 
 120f255:	c7 85 78 ff ff ff 00 	movl   $0x0,-0x88(%rbp)
 120f25c:	00 00 00 
 120f25f:	c7 85 7b ff ff ff 00 	movl   $0x0,-0x85(%rbp)
 120f266:	00 00 00 
 120f269:	c7 85 60 ff ff ff 00 	movl   $0x0,-0xa0(%rbp)
 120f270:	00 00 00 
 120f273:	66 c7 85 64 ff ff ff 	movw   $0x0,-0x9c(%rbp)
 120f27a:	00 00 
 120f27c:	45 31 e4             	xor    %r12d,%r12d
 120f27f:	31 d2                	xor    %edx,%edx
 120f281:	31 c0                	xor    %eax,%eax
 120f283:	31 f6                	xor    %esi,%esi
 120f285:	45 31 c0             	xor    %r8d,%r8d
 120f288:	31 ff                	xor    %edi,%edi
 120f28a:	45 31 c9             	xor    %r9d,%r9d
 120f28d:	45 31 f6             	xor    %r14d,%r14d
 120f290:	45 31 ed             	xor    %r13d,%r13d
 120f293:	45 31 d2             	xor    %r10d,%r10d
 120f296:	45 31 db             	xor    %r11d,%r11d
 120f299:	45 31 ff             	xor    %r15d,%r15d
 120f29c:	31 db                	xor    %ebx,%ebx
 120f29e:	48 8b 8d 18 fd ff ff 	mov    -0x2e8(%rbp),%rcx
 120f2a5:	4c 89 21             	mov    %r12,(%rcx)
 120f2a8:	88 51 08             	mov    %dl,0x8(%rcx)
 120f2ab:	88 41 09             	mov    %al,0x9(%rcx)
 120f2ae:	c5 fc 10 85 50 fc ff 	vmovups -0x3b0(%rbp),%ymm0
 120f2b5:	ff 
 120f2b6:	c5 fc 11 41 2a       	vmovups %ymm0,0x2a(%rcx)
 120f2bb:	48 8b 85 6e fc ff ff 	mov    -0x392(%rbp),%rax
 120f2c2:	48 89 41 48          	mov    %rax,0x48(%rcx)
 120f2c6:	c5 fc 10 85 30 fc ff 	vmovups -0x3d0(%rbp),%ymm0
 120f2cd:	ff 
 120f2ce:	c5 fc 11 41 0a       	vmovups %ymm0,0xa(%rcx)
 120f2d3:	40 88 71 50          	mov    %sil,0x50(%rcx)
 120f2d7:	8b 85 68 ff ff ff    	mov    -0x98(%rbp),%eax
 120f2dd:	89 41 51             	mov    %eax,0x51(%rcx)
 120f2e0:	8b 85 6b ff ff ff    	mov    -0x95(%rbp),%eax
 120f2e6:	89 41 54             	mov    %eax,0x54(%rcx)
 120f2e9:	4c 89 41 58          	mov    %r8,0x58(%rcx)
 120f2ed:	40 88 79 60          	mov    %dil,0x60(%rcx)
 120f2f1:	44 88 49 61          	mov    %r9b,0x61(%rcx)
 120f2f5:	c5 fc 10 85 a0 fc ff 	vmovups -0x360(%rbp),%ymm0
 120f2fc:	ff 
 120f2fd:	c5 fc 11 81 82 00 00 	vmovups %ymm0,0x82(%rcx)
 120f304:	00 
 120f305:	48 8b 85 be fc ff ff 	mov    -0x342(%rbp),%rax
 120f30c:	48 89 81 a0 00 00 00 	mov    %rax,0xa0(%rcx)
 120f313:	c5 fc 10 85 80 fc ff 	vmovups -0x380(%rbp),%ymm0
 120f31a:	ff 
 120f31b:	c5 fc 11 41 62       	vmovups %ymm0,0x62(%rcx)
 120f320:	44 88 b1 a8 00 00 00 	mov    %r14b,0xa8(%rcx)
 120f327:	8b 85 70 ff ff ff    	mov    -0x90(%rbp),%eax
 120f32d:	89 81 a9 00 00 00    	mov    %eax,0xa9(%rcx)
 120f333:	8b 85 73 ff ff ff    	mov    -0x8d(%rbp),%eax
 120f339:	89 81 ac 00 00 00    	mov    %eax,0xac(%rcx)
 120f33f:	4c 89 a9 b0 00 00 00 	mov    %r13,0xb0(%rcx)
 120f346:	44 88 91 b8 00 00 00 	mov    %r10b,0xb8(%rcx)
 120f34d:	44 88 99 b9 00 00 00 	mov    %r11b,0xb9(%rcx)
 120f354:	48 8b 85 0e fd ff ff 	mov    -0x2f2(%rbp),%rax
 120f35b:	48 89 81 f8 00 00 00 	mov    %rax,0xf8(%rcx)
 120f362:	c5 fc 10 85 d0 fc ff 	vmovups -0x330(%rbp),%ymm0
 120f369:	ff 
 120f36a:	c5 fc 10 8d f0 fc ff 	vmovups -0x310(%rbp),%ymm1
 120f371:	ff 
 120f372:	c5 fc 11 89 da 00 00 	vmovups %ymm1,0xda(%rcx)
 120f379:	00 
 120f37a:	c5 fc 11 81 ba 00 00 	vmovups %ymm0,0xba(%rcx)
 120f381:	00 
 120f382:	44 88 b9 00 01 00 00 	mov    %r15b,0x100(%rcx)
 120f389:	8b 85 7b ff ff ff    	mov    -0x85(%rbp),%eax
 120f38f:	89 81 04 01 00 00    	mov    %eax,0x104(%rcx)
 120f395:	8b 85 78 ff ff ff    	mov    -0x88(%rbp),%eax
 120f39b:	89 81 01 01 00 00    	mov    %eax,0x101(%rcx)
 120f3a1:	66 89 99 08 01 00 00 	mov    %bx,0x108(%rcx)
 120f3a8:	8b 85 60 ff ff ff    	mov    -0xa0(%rbp),%eax
 120f3ae:	89 81 0a 01 00 00    	mov    %eax,0x10a(%rcx)
 120f3b4:	0f b7 85 64 ff ff ff 	movzwl -0x9c(%rbp),%eax
 120f3bb:	66 89 81 0e 01 00 00 	mov    %ax,0x10e(%rcx)
 120f3c2:	48 81 c4 b8 04 00 00 	add    $0x4b8,%rsp
 120f3c9:	5b                   	pop    %rbx
 120f3ca:	41 5c                	pop    %r12
 120f3cc:	41 5d                	pop    %r13
 120f3ce:	41 5e                	pop    %r14
 120f3d0:	41 5f                	pop    %r15
 120f3d2:	5d                   	pop    %rbp
 120f3d3:	c5 f8 77             	vzeroupper 
 120f3d6:	c3                   	ret    
 120f3d7:	31 c0                	xor    %eax,%eax
 120f3d9:	31 c9                	xor    %ecx,%ecx
 120f3db:	eb 10                	jmp    120f3ed <br.encoder.literal_context_split.chooseProposals+0x59d>
 120f3dd:	0f 1f 00             	nopl   (%rax)
 120f3e0:	48 83 c1 04          	add    $0x4,%rcx
 120f3e4:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 120f3eb:	74 6a                	je     120f457 <br.encoder.literal_context_split.chooseProposals+0x607>
 120f3ed:	41 83 bc 8c 08 00 04 	cmpl   $0x0,0x40008(%r12,%rcx,4)
 120f3f4:	00 00 
 120f3f6:	74 0c                	je     120f404 <br.encoder.literal_context_split.chooseProposals+0x5b4>
 120f3f8:	0f b7 d0             	movzwl %ax,%edx
 120f3fb:	88 8c 15 30 fb ff ff 	mov    %cl,-0x4d0(%rbp,%rdx,1)
 120f402:	ff c0                	inc    %eax
 120f404:	41 83 bc 8c 0c 00 04 	cmpl   $0x0,0x4000c(%r12,%rcx,4)
 120f40b:	00 00 
 120f40d:	74 10                	je     120f41f <br.encoder.literal_context_split.chooseProposals+0x5cf>
 120f40f:	0f b7 d0             	movzwl %ax,%edx
 120f412:	8d 71 01             	lea    0x1(%rcx),%esi
 120f415:	40 88 b4 15 30 fb ff 	mov    %sil,-0x4d0(%rbp,%rdx,1)
 120f41c:	ff 
 120f41d:	ff c0                	inc    %eax
 120f41f:	41 83 bc 8c 10 00 04 	cmpl   $0x0,0x40010(%r12,%rcx,4)
 120f426:	00 00 
 120f428:	74 10                	je     120f43a <br.encoder.literal_context_split.chooseProposals+0x5ea>
 120f42a:	0f b7 d0             	movzwl %ax,%edx
 120f42d:	8d 71 02             	lea    0x2(%rcx),%esi
 120f430:	40 88 b4 15 30 fb ff 	mov    %sil,-0x4d0(%rbp,%rdx,1)
 120f437:	ff 
 120f438:	ff c0                	inc    %eax
 120f43a:	41 83 bc 8c 14 00 04 	cmpl   $0x0,0x40014(%r12,%rcx,4)
 120f441:	00 00 
 120f443:	74 9b                	je     120f3e0 <br.encoder.literal_context_split.chooseProposals+0x590>
 120f445:	0f b7 d0             	movzwl %ax,%edx
 120f448:	8d 71 03             	lea    0x3(%rcx),%esi
 120f44b:	40 88 b4 15 30 fb ff 	mov    %sil,-0x4d0(%rbp,%rdx,1)
 120f452:	ff 
 120f453:	ff c0                	inc    %eax
 120f455:	eb 89                	jmp    120f3e0 <br.encoder.literal_context_split.chooseProposals+0x590>
 120f457:	66 89 85 2e fb ff ff 	mov    %ax,-0x4d2(%rbp)
 120f45e:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 120f465:	4c 8d bd 2e fb ff ff 	lea    -0x4d2(%rbp),%r15
 120f46c:	4c 89 f6             	mov    %r14,%rsi
 120f46f:	4c 89 fa             	mov    %r15,%rdx
 120f472:	e8 f9 d1 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46128>
 120f477:	0f b7 9d 10 fe ff ff 	movzwl -0x1f0(%rbp),%ebx
 120f47e:	66 85 db             	test   %bx,%bx
 120f481:	0f 85 5d 09 00 00    	jne    120fde4 <br.encoder.literal_context_split.chooseProposals+0xf94>
 120f487:	4c 8b 8d 08 fe ff ff 	mov    -0x1f8(%rbp),%r9
 120f48e:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 120f492:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 120f499:	ff 
 120f49a:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 120f4a1:	ff 
 120f4a2:	48 c7 85 5e fd ff ff 	movq   $0x0,-0x2a2(%rbp)
 120f4a9:	00 00 00 00 
 120f4ad:	c5 fc 11 85 70 fd ff 	vmovups %ymm0,-0x290(%rbp)
 120f4b4:	ff 
 120f4b5:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 120f4bc:	ff 
 120f4bd:	48 c7 85 ae fd ff ff 	movq   $0x0,-0x252(%rbp)
 120f4c4:	00 00 00 00 
 120f4c8:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 120f4cf:	ff 
 120f4d0:	c5 fc 11 85 e0 fd ff 	vmovups %ymm0,-0x220(%rbp)
 120f4d7:	ff 
 120f4d8:	48 c7 85 fe fd ff ff 	movq   $0x0,-0x202(%rbp)
 120f4df:	00 00 00 00 
 120f4e3:	4d 8b 04 24          	mov    (%r12),%r8
 120f4e7:	4c 89 3c 24          	mov    %r15,(%rsp)
 120f4eb:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 120f4f2:	31 f6                	xor    %esi,%esi
 120f4f4:	48 8b 55 a8          	mov    -0x58(%rbp),%rdx
 120f4f8:	4c 89 f1             	mov    %r14,%rcx
 120f4fb:	4c 89 4d 80          	mov    %r9,-0x80(%rbp)
 120f4ff:	c5 f8 77             	vzeroupper 
 120f502:	e8 79 d7 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191>
 120f507:	0f b7 9d 10 ff ff ff 	movzwl -0xf0(%rbp),%ebx
 120f50e:	66 85 db             	test   %bx,%bx
 120f511:	0f 85 bb 08 00 00    	jne    120fdd2 <br.encoder.literal_context_split.chooseProposals+0xf82>
 120f517:	48 8d 95 12 fe ff ff 	lea    -0x1ee(%rbp),%rdx
 120f51e:	44 0f b6 a5 58 fe ff 	movzbl -0x1a8(%rbp),%r12d
 120f525:	ff 
 120f526:	0f b6 b5 b0 fe ff ff 	movzbl -0x150(%rbp),%esi
 120f52d:	45 84 e4             	test   %r12b,%r12b
 120f530:	74 48                	je     120f57a <br.encoder.literal_context_split.chooseProposals+0x72a>
 120f532:	0f b6 85 11 fe ff ff 	movzbl -0x1ef(%rbp),%eax
 120f539:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 120f53d:	0f b6 8d 10 fe ff ff 	movzbl -0x1f0(%rbp),%ecx
 120f544:	48 8b 85 08 fe ff ff 	mov    -0x1f8(%rbp),%rax
 120f54b:	48 89 85 40 ff ff ff 	mov    %rax,-0xc0(%rbp)
 120f552:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 120f556:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 120f55d:	ff 
 120f55e:	c5 fc 10 42 20       	vmovups 0x20(%rdx),%ymm0
 120f563:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 120f56a:	ff 
 120f56b:	48 8b 42 3e          	mov    0x3e(%rdx),%rax
 120f56f:	48 89 85 5e fd ff ff 	mov    %rax,-0x2a2(%rbp)
 120f576:	b2 01                	mov    $0x1,%dl
 120f578:	eb 0c                	jmp    120f586 <br.encoder.literal_context_split.chooseProposals+0x736>
 120f57a:	31 d2                	xor    %edx,%edx
 120f57c:	48 c7 45 a8 00 00 00 	movq   $0x0,-0x58(%rbp)
 120f583:	00 
 120f584:	31 c9                	xor    %ecx,%ecx
 120f586:	4c 8d 8d 6a fe ff ff 	lea    -0x196(%rbp),%r9
 120f58d:	44 0f b6 95 08 ff ff 	movzbl -0xf8(%rbp),%r10d
 120f594:	ff 
 120f595:	41 89 f6             	mov    %esi,%r14d
 120f598:	40 84 f6             	test   %sil,%sil
 120f59b:	74 44                	je     120f5e1 <br.encoder.literal_context_split.chooseProposals+0x791>
 120f59d:	48 8b bd 60 fe ff ff 	mov    -0x1a0(%rbp),%rdi
 120f5a4:	0f b6 b5 68 fe ff ff 	movzbl -0x198(%rbp),%esi
 120f5ab:	44 0f b6 85 69 fe ff 	movzbl -0x197(%rbp),%r8d
 120f5b2:	ff 
 120f5b3:	49 8b 41 3e          	mov    0x3e(%r9),%rax
 120f5b7:	48 89 85 ae fd ff ff 	mov    %rax,-0x252(%rbp)
 120f5be:	c4 c1 7c 10 01       	vmovups (%r9),%ymm0
 120f5c3:	c4 c1 7c 10 49 20    	vmovups 0x20(%r9),%ymm1
 120f5c9:	c5 fc 11 8d 90 fd ff 	vmovups %ymm1,-0x270(%rbp)
 120f5d0:	ff 
 120f5d1:	c5 fc 11 85 70 fd ff 	vmovups %ymm0,-0x290(%rbp)
 120f5d8:	ff 
 120f5d9:	b0 01                	mov    $0x1,%al
 120f5db:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 120f5df:	eb 0d                	jmp    120f5ee <br.encoder.literal_context_split.chooseProposals+0x79e>
 120f5e1:	31 f6                	xor    %esi,%esi
 120f5e3:	45 31 c0             	xor    %r8d,%r8d
 120f5e6:	48 c7 45 d0 00 00 00 	movq   $0x0,-0x30(%rbp)
 120f5ed:	00 
 120f5ee:	48 89 75 b0          	mov    %rsi,-0x50(%rbp)
 120f5f2:	48 8d b5 c2 fe ff ff 	lea    -0x13e(%rbp),%rsi
 120f5f9:	45 84 d2             	test   %r10b,%r10b
 120f5fc:	48 89 4d 88          	mov    %rcx,-0x78(%rbp)
 120f600:	48 89 55 c0          	mov    %rdx,-0x40(%rbp)
 120f604:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 120f608:	4c 89 45 98          	mov    %r8,-0x68(%rbp)
 120f60c:	44 88 95 30 ff ff ff 	mov    %r10b,-0xd0(%rbp)
 120f613:	74 46                	je     120f65b <br.encoder.literal_context_split.chooseProposals+0x80b>
 120f615:	4c 8b ad b8 fe ff ff 	mov    -0x148(%rbp),%r13
 120f61c:	0f b6 85 c0 fe ff ff 	movzbl -0x140(%rbp),%eax
 120f623:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 120f627:	0f b6 85 c1 fe ff ff 	movzbl -0x13f(%rbp),%eax
 120f62e:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 120f632:	48 8b 46 3e          	mov    0x3e(%rsi),%rax
 120f636:	48 89 85 fe fd ff ff 	mov    %rax,-0x202(%rbp)
 120f63d:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 120f641:	c5 fc 10 4e 20       	vmovups 0x20(%rsi),%ymm1
 120f646:	c5 fc 11 8d e0 fd ff 	vmovups %ymm1,-0x220(%rbp)
 120f64d:	ff 
 120f64e:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 120f655:	ff 
 120f656:	41 b7 01             	mov    $0x1,%r15b
 120f659:	eb 13                	jmp    120f66e <br.encoder.literal_context_split.chooseProposals+0x81e>
 120f65b:	48 c7 45 90 00 00 00 	movq   $0x0,-0x70(%rbp)
 120f662:	00 
 120f663:	48 c7 45 c8 00 00 00 	movq   $0x0,-0x38(%rbp)
 120f66a:	00 
 120f66b:	45 31 ff             	xor    %r15d,%r15d
 120f66e:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 120f672:	4c 8b 00             	mov    (%rax),%r8
 120f675:	48 8d 85 2e fb ff ff 	lea    -0x4d2(%rbp),%rax
 120f67c:	48 89 04 24          	mov    %rax,(%rsp)
 120f680:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 120f687:	be 01 00 00 00       	mov    $0x1,%esi
 120f68c:	48 8b 95 18 ff ff ff 	mov    -0xe8(%rbp),%rdx
 120f693:	48 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%rcx
 120f69a:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 120f69e:	c5 f8 77             	vzeroupper 
 120f6a1:	e8 da d5 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191>
 120f6a6:	0f b7 9d 10 ff ff ff 	movzwl -0xf0(%rbp),%ebx
 120f6ad:	66 85 db             	test   %bx,%bx
 120f6b0:	0f 85 1c 07 00 00    	jne    120fdd2 <br.encoder.literal_context_split.chooseProposals+0xf82>
 120f6b6:	0f b6 85 b0 fe ff ff 	movzbl -0x150(%rbp),%eax
 120f6bd:	80 bd 58 fe ff ff 00 	cmpb   $0x0,-0x1a8(%rbp)
 120f6c4:	0f 84 a6 00 00 00    	je     120f770 <br.encoder.literal_context_split.chooseProposals+0x920>
 120f6ca:	48 8b 8d 08 fe ff ff 	mov    -0x1f8(%rbp),%rcx
 120f6d1:	0f b6 95 10 fe ff ff 	movzbl -0x1f0(%rbp),%edx
 120f6d8:	0f b6 b5 11 fe ff ff 	movzbl -0x1ef(%rbp),%esi
 120f6df:	45 84 e4             	test   %r12b,%r12b
 120f6e2:	40 0f 94 c7          	sete   %dil
 120f6e6:	4c 8b a5 40 ff ff ff 	mov    -0xc0(%rbp),%r12
 120f6ed:	4c 39 e1             	cmp    %r12,%rcx
 120f6f0:	41 0f 97 c0          	seta   %r8b
 120f6f4:	41 08 f8             	or     %dil,%r8b
 120f6f7:	4c 8b 55 a0          	mov    -0x60(%rbp),%r10
 120f6fb:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 120f6ff:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 120f703:	75 2a                	jne    120f72f <br.encoder.literal_context_split.chooseProposals+0x8df>
 120f705:	4c 39 e1             	cmp    %r12,%rcx
 120f708:	40 0f 94 c7          	sete   %dil
 120f70c:	41 89 f0             	mov    %esi,%r8d
 120f70f:	41 80 e0 7f          	and    $0x7f,%r8b
 120f713:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 120f717:	41 80 e1 7f          	and    $0x7f,%r9b
 120f71b:	45 38 c8             	cmp    %r9b,%r8b
 120f71e:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 120f722:	41 0f 92 c0          	setb   %r8b
 120f726:	41 20 f8             	and    %dil,%r8b
 120f729:	41 80 f8 01          	cmp    $0x1,%r8b
 120f72d:	75 54                	jne    120f783 <br.encoder.literal_context_split.chooseProposals+0x933>
 120f72f:	4c 8d 85 12 fe ff ff 	lea    -0x1ee(%rbp),%r8
 120f736:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f73a:	48 89 bd 5e fd ff ff 	mov    %rdi,-0x2a2(%rbp)
 120f741:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f746:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f74c:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 120f753:	ff 
 120f754:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 120f75b:	ff 
 120f75c:	40 b7 01             	mov    $0x1,%dil
 120f75f:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 120f763:	48 89 75 a8          	mov    %rsi,-0x58(%rbp)
 120f767:	48 89 55 88          	mov    %rdx,-0x78(%rbp)
 120f76b:	49 89 cc             	mov    %rcx,%r12
 120f76e:	eb 13                	jmp    120f783 <br.encoder.literal_context_split.chooseProposals+0x933>
 120f770:	4c 8b 55 a0          	mov    -0x60(%rbp),%r10
 120f774:	4c 8b a5 40 ff ff ff 	mov    -0xc0(%rbp),%r12
 120f77b:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 120f77f:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 120f783:	0f b6 8d 08 ff ff ff 	movzbl -0xf8(%rbp),%ecx
 120f78a:	84 c0                	test   %al,%al
 120f78c:	0f 84 95 00 00 00    	je     120f827 <br.encoder.literal_context_split.chooseProposals+0x9d7>
 120f792:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 120f799:	0f b6 b5 68 fe ff ff 	movzbl -0x198(%rbp),%esi
 120f7a0:	0f b6 95 69 fe ff ff 	movzbl -0x197(%rbp),%edx
 120f7a7:	45 84 f6             	test   %r14b,%r14b
 120f7aa:	40 0f 94 c7          	sete   %dil
 120f7ae:	48 3b 45 b8          	cmp    -0x48(%rbp),%rax
 120f7b2:	41 0f 97 c0          	seta   %r8b
 120f7b6:	41 08 f8             	or     %dil,%r8b
 120f7b9:	75 2b                	jne    120f7e6 <br.encoder.literal_context_split.chooseProposals+0x996>
 120f7bb:	48 3b 45 b8          	cmp    -0x48(%rbp),%rax
 120f7bf:	40 0f 94 c7          	sete   %dil
 120f7c3:	41 89 d0             	mov    %edx,%r8d
 120f7c6:	41 80 e0 7f          	and    $0x7f,%r8b
 120f7ca:	4c 8b 4d 98          	mov    -0x68(%rbp),%r9
 120f7ce:	41 80 e1 7f          	and    $0x7f,%r9b
 120f7d2:	45 38 c8             	cmp    %r9b,%r8b
 120f7d5:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 120f7d9:	41 0f 92 c0          	setb   %r8b
 120f7dd:	41 20 f8             	and    %dil,%r8b
 120f7e0:	41 80 f8 01          	cmp    $0x1,%r8b
 120f7e4:	75 41                	jne    120f827 <br.encoder.literal_context_split.chooseProposals+0x9d7>
 120f7e6:	4c 8d 85 6a fe ff ff 	lea    -0x196(%rbp),%r8
 120f7ed:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f7f1:	48 89 bd ae fd ff ff 	mov    %rdi,-0x252(%rbp)
 120f7f8:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f7fd:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f803:	c5 fc 11 8d 90 fd ff 	vmovups %ymm1,-0x270(%rbp)
 120f80a:	ff 
 120f80b:	c5 fc 11 85 70 fd ff 	vmovups %ymm0,-0x290(%rbp)
 120f812:	ff 
 120f813:	40 b7 01             	mov    $0x1,%dil
 120f816:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 120f81a:	41 89 f1             	mov    %esi,%r9d
 120f81d:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 120f821:	89 d0                	mov    %edx,%eax
 120f823:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 120f827:	84 c9                	test   %cl,%cl
 120f829:	4c 89 4d b0          	mov    %r9,-0x50(%rbp)
 120f82d:	0f 84 8a 00 00 00    	je     120f8bd <br.encoder.literal_context_split.chooseProposals+0xa6d>
 120f833:	48 8b 85 b8 fe ff ff 	mov    -0x148(%rbp),%rax
 120f83a:	0f b6 8d c0 fe ff ff 	movzbl -0x140(%rbp),%ecx
 120f841:	0f b6 95 c1 fe ff ff 	movzbl -0x13f(%rbp),%edx
 120f848:	80 bd 30 ff ff ff 00 	cmpb   $0x0,-0xd0(%rbp)
 120f84f:	40 0f 94 c6          	sete   %sil
 120f853:	4c 39 e8             	cmp    %r13,%rax
 120f856:	40 0f 97 c7          	seta   %dil
 120f85a:	40 08 f7             	or     %sil,%dil
 120f85d:	75 24                	jne    120f883 <br.encoder.literal_context_split.chooseProposals+0xa33>
 120f85f:	4c 39 e8             	cmp    %r13,%rax
 120f862:	40 0f 94 c6          	sete   %sil
 120f866:	89 d7                	mov    %edx,%edi
 120f868:	40 80 e7 7f          	and    $0x7f,%dil
 120f86c:	45 89 d8             	mov    %r11d,%r8d
 120f86f:	41 80 e0 7f          	and    $0x7f,%r8b
 120f873:	44 38 c7             	cmp    %r8b,%dil
 120f876:	40 0f 92 c7          	setb   %dil
 120f87a:	40 20 f7             	and    %sil,%dil
 120f87d:	40 80 ff 01          	cmp    $0x1,%dil
 120f881:	75 3a                	jne    120f8bd <br.encoder.literal_context_split.chooseProposals+0xa6d>
 120f883:	48 8d bd c2 fe ff ff 	lea    -0x13e(%rbp),%rdi
 120f88a:	48 8b 77 3e          	mov    0x3e(%rdi),%rsi
 120f88e:	48 89 b5 fe fd ff ff 	mov    %rsi,-0x202(%rbp)
 120f895:	c5 fc 10 07          	vmovups (%rdi),%ymm0
 120f899:	c5 fc 10 4f 20       	vmovups 0x20(%rdi),%ymm1
 120f89e:	c5 fc 11 8d e0 fd ff 	vmovups %ymm1,-0x220(%rbp)
 120f8a5:	ff 
 120f8a6:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 120f8ad:	ff 
 120f8ae:	41 b7 01             	mov    $0x1,%r15b
 120f8b1:	49 89 c5             	mov    %rax,%r13
 120f8b4:	89 c8                	mov    %ecx,%eax
 120f8b6:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 120f8ba:	41 89 d3             	mov    %edx,%r11d
 120f8bd:	4c 89 5d c8          	mov    %r11,-0x38(%rbp)
 120f8c1:	4d 8b 02             	mov    (%r10),%r8
 120f8c4:	48 8d 85 2e fb ff ff 	lea    -0x4d2(%rbp),%rax
 120f8cb:	48 89 04 24          	mov    %rax,(%rsp)
 120f8cf:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 120f8d6:	be 02 00 00 00       	mov    $0x2,%esi
 120f8db:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 120f8e2:	48 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%rcx
 120f8e9:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 120f8ed:	c5 f8 77             	vzeroupper 
 120f8f0:	e8 8b d3 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191>
 120f8f5:	0f b7 9d 10 ff ff ff 	movzwl -0xf0(%rbp),%ebx
 120f8fc:	66 85 db             	test   %bx,%bx
 120f8ff:	0f 85 cd 04 00 00    	jne    120fdd2 <br.encoder.literal_context_split.chooseProposals+0xf82>
 120f905:	0f b6 85 b0 fe ff ff 	movzbl -0x150(%rbp),%eax
 120f90c:	80 bd 58 fe ff ff 00 	cmpb   $0x0,-0x1a8(%rbp)
 120f913:	0f 84 96 00 00 00    	je     120f9af <br.encoder.literal_context_split.chooseProposals+0xb5f>
 120f919:	48 8b 8d 08 fe ff ff 	mov    -0x1f8(%rbp),%rcx
 120f920:	0f b6 95 10 fe ff ff 	movzbl -0x1f0(%rbp),%edx
 120f927:	0f b6 b5 11 fe ff ff 	movzbl -0x1ef(%rbp),%esi
 120f92e:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 120f932:	40 0f 94 c7          	sete   %dil
 120f936:	4c 39 e1             	cmp    %r12,%rcx
 120f939:	41 0f 97 c0          	seta   %r8b
 120f93d:	41 08 f8             	or     %dil,%r8b
 120f940:	4c 8b 4d a0          	mov    -0x60(%rbp),%r9
 120f944:	4c 8b 55 90          	mov    -0x70(%rbp),%r10
 120f948:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 120f94c:	75 20                	jne    120f96e <br.encoder.literal_context_split.chooseProposals+0xb1e>
 120f94e:	40 b7 01             	mov    $0x1,%dil
 120f951:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 120f955:	4c 39 e1             	cmp    %r12,%rcx
 120f958:	75 61                	jne    120f9bb <br.encoder.literal_context_split.chooseProposals+0xb6b>
 120f95a:	48 8b 7d a8          	mov    -0x58(%rbp),%rdi
 120f95e:	40 80 e7 7f          	and    $0x7f,%dil
 120f962:	41 89 f0             	mov    %esi,%r8d
 120f965:	41 80 e0 7f          	and    $0x7f,%r8b
 120f969:	41 38 f8             	cmp    %dil,%r8b
 120f96c:	73 4d                	jae    120f9bb <br.encoder.literal_context_split.chooseProposals+0xb6b>
 120f96e:	4c 8d 85 12 fe ff ff 	lea    -0x1ee(%rbp),%r8
 120f975:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f979:	48 89 bd 5e fd ff ff 	mov    %rdi,-0x2a2(%rbp)
 120f980:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f985:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f98b:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 120f992:	ff 
 120f993:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 120f99a:	ff 
 120f99b:	40 b7 01             	mov    $0x1,%dil
 120f99e:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 120f9a2:	48 89 75 a8          	mov    %rsi,-0x58(%rbp)
 120f9a6:	48 89 55 88          	mov    %rdx,-0x78(%rbp)
 120f9aa:	49 89 cc             	mov    %rcx,%r12
 120f9ad:	eb 0c                	jmp    120f9bb <br.encoder.literal_context_split.chooseProposals+0xb6b>
 120f9af:	4c 8b 4d a0          	mov    -0x60(%rbp),%r9
 120f9b3:	4c 8b 55 90          	mov    -0x70(%rbp),%r10
 120f9b7:	4c 8b 5d c8          	mov    -0x38(%rbp),%r11
 120f9bb:	0f b6 8d 08 ff ff ff 	movzbl -0xf8(%rbp),%ecx
 120f9c2:	84 c0                	test   %al,%al
 120f9c4:	0f 84 80 00 00 00    	je     120fa4a <br.encoder.literal_context_split.chooseProposals+0xbfa>
 120f9ca:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 120f9d1:	0f b6 b5 68 fe ff ff 	movzbl -0x198(%rbp),%esi
 120f9d8:	0f b6 95 69 fe ff ff 	movzbl -0x197(%rbp),%edx
 120f9df:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 120f9e3:	74 23                	je     120fa08 <br.encoder.literal_context_split.chooseProposals+0xbb8>
 120f9e5:	48 3b 45 b8          	cmp    -0x48(%rbp),%rax
 120f9e9:	77 1d                	ja     120fa08 <br.encoder.literal_context_split.chooseProposals+0xbb8>
 120f9eb:	40 b7 01             	mov    $0x1,%dil
 120f9ee:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 120f9f2:	75 56                	jne    120fa4a <br.encoder.literal_context_split.chooseProposals+0xbfa>
 120f9f4:	48 8b 7d 98          	mov    -0x68(%rbp),%rdi
 120f9f8:	40 80 e7 7f          	and    $0x7f,%dil
 120f9fc:	41 89 d0             	mov    %edx,%r8d
 120f9ff:	41 80 e0 7f          	and    $0x7f,%r8b
 120fa03:	41 38 f8             	cmp    %dil,%r8b
 120fa06:	73 42                	jae    120fa4a <br.encoder.literal_context_split.chooseProposals+0xbfa>
 120fa08:	4c 8d 85 6a fe ff ff 	lea    -0x196(%rbp),%r8
 120fa0f:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120fa13:	48 89 bd ae fd ff ff 	mov    %rdi,-0x252(%rbp)
 120fa1a:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120fa1f:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120fa25:	c5 fc 11 8d 90 fd ff 	vmovups %ymm1,-0x270(%rbp)
 120fa2c:	ff 
 120fa2d:	c5 fc 11 85 70 fd ff 	vmovups %ymm0,-0x290(%rbp)
 120fa34:	ff 
 120fa35:	40 b7 01             	mov    $0x1,%dil
 120fa38:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 120fa3c:	48 89 75 b0          	mov    %rsi,-0x50(%rbp)
 120fa40:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 120fa44:	89 d0                	mov    %edx,%eax
 120fa46:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 120fa4a:	84 c9                	test   %cl,%cl
 120fa4c:	74 6d                	je     120fabb <br.encoder.literal_context_split.chooseProposals+0xc6b>
 120fa4e:	48 8b 85 b8 fe ff ff 	mov    -0x148(%rbp),%rax
 120fa55:	0f b6 8d c0 fe ff ff 	movzbl -0x140(%rbp),%ecx
 120fa5c:	0f b6 95 c1 fe ff ff 	movzbl -0x13f(%rbp),%edx
 120fa63:	45 84 ff             	test   %r15b,%r15b
 120fa66:	74 1c                	je     120fa84 <br.encoder.literal_context_split.chooseProposals+0xc34>
 120fa68:	4c 39 e8             	cmp    %r13,%rax
 120fa6b:	77 17                	ja     120fa84 <br.encoder.literal_context_split.chooseProposals+0xc34>
 120fa6d:	41 b7 01             	mov    $0x1,%r15b
 120fa70:	75 49                	jne    120fabb <br.encoder.literal_context_split.chooseProposals+0xc6b>
 120fa72:	44 89 de             	mov    %r11d,%esi
 120fa75:	40 80 e6 7f          	and    $0x7f,%sil
 120fa79:	89 d7                	mov    %edx,%edi
 120fa7b:	40 80 e7 7f          	and    $0x7f,%dil
 120fa7f:	40 38 f7             	cmp    %sil,%dil
 120fa82:	73 37                	jae    120fabb <br.encoder.literal_context_split.chooseProposals+0xc6b>
 120fa84:	48 8d bd c2 fe ff ff 	lea    -0x13e(%rbp),%rdi
 120fa8b:	48 8b 77 3e          	mov    0x3e(%rdi),%rsi
 120fa8f:	48 89 b5 fe fd ff ff 	mov    %rsi,-0x202(%rbp)
 120fa96:	c5 fc 10 07          	vmovups (%rdi),%ymm0
 120fa9a:	c5 fc 10 4f 20       	vmovups 0x20(%rdi),%ymm1
 120fa9f:	c5 fc 11 8d e0 fd ff 	vmovups %ymm1,-0x220(%rbp)
 120faa6:	ff 
 120faa7:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 120faae:	ff 
 120faaf:	41 b7 01             	mov    $0x1,%r15b
 120fab2:	49 89 c5             	mov    %rax,%r13
 120fab5:	41 89 ca             	mov    %ecx,%r10d
 120fab8:	41 89 d3             	mov    %edx,%r11d
 120fabb:	4c 89 5d c8          	mov    %r11,-0x38(%rbp)
 120fabf:	4c 89 55 90          	mov    %r10,-0x70(%rbp)
 120fac3:	4d 8b 01             	mov    (%r9),%r8
 120fac6:	48 8d 85 2e fb ff ff 	lea    -0x4d2(%rbp),%rax
 120facd:	48 89 04 24          	mov    %rax,(%rsp)
 120fad1:	48 8d bd 08 fe ff ff 	lea    -0x1f8(%rbp),%rdi
 120fad8:	be 03 00 00 00       	mov    $0x3,%esi
 120fadd:	48 8b 95 28 ff ff ff 	mov    -0xd8(%rbp),%rdx
 120fae4:	48 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%rcx
 120faeb:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 120faef:	c5 f8 77             	vzeroupper 
 120faf2:	e8 89 d1 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46191>
 120faf7:	0f b7 9d 10 ff ff ff 	movzwl -0xf0(%rbp),%ebx
 120fafe:	66 85 db             	test   %bx,%bx
 120fb01:	0f 85 cb 02 00 00    	jne    120fdd2 <br.encoder.literal_context_split.chooseProposals+0xf82>
 120fb07:	0f b6 85 b0 fe ff ff 	movzbl -0x150(%rbp),%eax
 120fb0e:	80 bd 58 fe ff ff 00 	cmpb   $0x0,-0x1a8(%rbp)
 120fb15:	0f 84 8e 00 00 00    	je     120fba9 <br.encoder.literal_context_split.chooseProposals+0xd59>
 120fb1b:	48 8b 8d 08 fe ff ff 	mov    -0x1f8(%rbp),%rcx
 120fb22:	0f b6 95 10 fe ff ff 	movzbl -0x1f0(%rbp),%edx
 120fb29:	44 0f b6 8d 11 fe ff 	movzbl -0x1ef(%rbp),%r9d
 120fb30:	ff 
 120fb31:	80 7d c0 00          	cmpb   $0x0,-0x40(%rbp)
 120fb35:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 120fb39:	4c 8b 55 90          	mov    -0x70(%rbp),%r10
 120fb3d:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 120fb41:	74 22                	je     120fb65 <br.encoder.literal_context_split.chooseProposals+0xd15>
 120fb43:	4c 39 e1             	cmp    %r12,%rcx
 120fb46:	77 1d                	ja     120fb65 <br.encoder.literal_context_split.chooseProposals+0xd15>
 120fb48:	40 b7 01             	mov    $0x1,%dil
 120fb4b:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 120fb4f:	75 64                	jne    120fbb5 <br.encoder.literal_context_split.chooseProposals+0xd65>
 120fb51:	48 8b 7d a8          	mov    -0x58(%rbp),%rdi
 120fb55:	40 80 e7 7f          	and    $0x7f,%dil
 120fb59:	45 89 c8             	mov    %r9d,%r8d
 120fb5c:	41 80 e0 7f          	and    $0x7f,%r8b
 120fb60:	41 38 f8             	cmp    %dil,%r8b
 120fb63:	73 50                	jae    120fbb5 <br.encoder.literal_context_split.chooseProposals+0xd65>
 120fb65:	4c 8d 85 12 fe ff ff 	lea    -0x1ee(%rbp),%r8
 120fb6c:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120fb70:	48 89 bd 5e fd ff ff 	mov    %rdi,-0x2a2(%rbp)
 120fb77:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120fb7c:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120fb82:	c5 fc 11 8d 40 fd ff 	vmovups %ymm1,-0x2c0(%rbp)
 120fb89:	ff 
 120fb8a:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 120fb91:	ff 
 120fb92:	40 b7 01             	mov    $0x1,%dil
 120fb95:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 120fb99:	44 89 cf             	mov    %r9d,%edi
 120fb9c:	48 89 7d a8          	mov    %rdi,-0x58(%rbp)
 120fba0:	48 89 55 88          	mov    %rdx,-0x78(%rbp)
 120fba4:	49 89 cc             	mov    %rcx,%r12
 120fba7:	eb 0c                	jmp    120fbb5 <br.encoder.literal_context_split.chooseProposals+0xd65>
 120fba9:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 120fbad:	4c 8b 55 90          	mov    -0x70(%rbp),%r10
 120fbb1:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 120fbb5:	0f b6 8d 08 ff ff ff 	movzbl -0xf8(%rbp),%ecx
 120fbbc:	84 c0                	test   %al,%al
 120fbbe:	0f 84 84 00 00 00    	je     120fc48 <br.encoder.literal_context_split.chooseProposals+0xdf8>
 120fbc4:	48 8b 85 60 fe ff ff 	mov    -0x1a0(%rbp),%rax
 120fbcb:	44 0f b6 8d 68 fe ff 	movzbl -0x198(%rbp),%r9d
 120fbd2:	ff 
 120fbd3:	0f b6 95 69 fe ff ff 	movzbl -0x197(%rbp),%edx
 120fbda:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 120fbde:	74 23                	je     120fc03 <br.encoder.literal_context_split.chooseProposals+0xdb3>
 120fbe0:	48 3b 45 b8          	cmp    -0x48(%rbp),%rax
 120fbe4:	77 1d                	ja     120fc03 <br.encoder.literal_context_split.chooseProposals+0xdb3>
 120fbe6:	40 b7 01             	mov    $0x1,%dil
 120fbe9:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 120fbed:	75 59                	jne    120fc48 <br.encoder.literal_context_split.chooseProposals+0xdf8>
 120fbef:	48 8b 7d 98          	mov    -0x68(%rbp),%rdi
 120fbf3:	40 80 e7 7f          	and    $0x7f,%dil
 120fbf7:	41 89 d0             	mov    %edx,%r8d
 120fbfa:	41 80 e0 7f          	and    $0x7f,%r8b
 120fbfe:	41 38 f8             	cmp    %dil,%r8b
 120fc01:	73 45                	jae    120fc48 <br.encoder.literal_context_split.chooseProposals+0xdf8>
 120fc03:	4c 8d 85 6a fe ff ff 	lea    -0x196(%rbp),%r8
 120fc0a:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120fc0e:	48 89 bd ae fd ff ff 	mov    %rdi,-0x252(%rbp)
 120fc15:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120fc1a:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120fc20:	c5 fc 11 8d 90 fd ff 	vmovups %ymm1,-0x270(%rbp)
 120fc27:	ff 
 120fc28:	c5 fc 11 85 70 fd ff 	vmovups %ymm0,-0x290(%rbp)
 120fc2f:	ff 
 120fc30:	40 b7 01             	mov    $0x1,%dil
 120fc33:	48 89 7d d0          	mov    %rdi,-0x30(%rbp)
 120fc37:	44 89 cf             	mov    %r9d,%edi
 120fc3a:	48 89 7d b0          	mov    %rdi,-0x50(%rbp)
 120fc3e:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 120fc42:	89 d0                	mov    %edx,%eax
 120fc44:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 120fc48:	84 c9                	test   %cl,%cl
 120fc4a:	74 6f                	je     120fcbb <br.encoder.literal_context_split.chooseProposals+0xe6b>
 120fc4c:	48 8b 85 b8 fe ff ff 	mov    -0x148(%rbp),%rax
 120fc53:	0f b6 8d c0 fe ff ff 	movzbl -0x140(%rbp),%ecx
 120fc5a:	0f b6 95 c1 fe ff ff 	movzbl -0x13f(%rbp),%edx
 120fc61:	45 84 ff             	test   %r15b,%r15b
 120fc64:	74 1c                	je     120fc82 <br.encoder.literal_context_split.chooseProposals+0xe32>
 120fc66:	4c 39 e8             	cmp    %r13,%rax
 120fc69:	77 17                	ja     120fc82 <br.encoder.literal_context_split.chooseProposals+0xe32>
 120fc6b:	41 b7 01             	mov    $0x1,%r15b
 120fc6e:	75 4b                	jne    120fcbb <br.encoder.literal_context_split.chooseProposals+0xe6b>
 120fc70:	45 89 f0             	mov    %r14d,%r8d
 120fc73:	41 80 e0 7f          	and    $0x7f,%r8b
 120fc77:	89 d7                	mov    %edx,%edi
 120fc79:	40 80 e7 7f          	and    $0x7f,%dil
 120fc7d:	44 38 c7             	cmp    %r8b,%dil
 120fc80:	73 39                	jae    120fcbb <br.encoder.literal_context_split.chooseProposals+0xe6b>
 120fc82:	4c 8d 85 c2 fe ff ff 	lea    -0x13e(%rbp),%r8
 120fc89:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120fc8d:	48 89 bd fe fd ff ff 	mov    %rdi,-0x202(%rbp)
 120fc94:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120fc99:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120fc9f:	c5 fc 11 8d e0 fd ff 	vmovups %ymm1,-0x220(%rbp)
 120fca6:	ff 
 120fca7:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 120fcae:	ff 
 120fcaf:	41 b7 01             	mov    $0x1,%r15b
 120fcb2:	49 89 c5             	mov    %rax,%r13
 120fcb5:	41 89 ca             	mov    %ecx,%r10d
 120fcb8:	41 89 d6             	mov    %edx,%r14d
 120fcbb:	ba 08 04 04 00       	mov    $0x40408,%edx
 120fcc0:	48 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%rdi
 120fcc7:	b9 03 00 00 00       	mov    $0x3,%ecx
 120fccc:	4c 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%r8
 120fcd3:	48 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%rax
 120fcda:	4c 89 d3             	mov    %r10,%rbx
 120fcdd:	c5 f8 77             	vzeroupper 
 120fce0:	ff 50 18             	call   *0x18(%rax)
 120fce3:	4d 89 f3             	mov    %r14,%r11
 120fce6:	49 89 da             	mov    %rbx,%r10
 120fce9:	48 8b 85 5e fd ff ff 	mov    -0x2a2(%rbp),%rax
 120fcf0:	48 89 85 6e fc ff ff 	mov    %rax,-0x392(%rbp)
 120fcf7:	c5 fc 10 85 20 fd ff 	vmovups -0x2e0(%rbp),%ymm0
 120fcfe:	ff 
 120fcff:	c5 fc 10 8d 40 fd ff 	vmovups -0x2c0(%rbp),%ymm1
 120fd06:	ff 
 120fd07:	c5 fc 11 8d 50 fc ff 	vmovups %ymm1,-0x3b0(%rbp)
 120fd0e:	ff 
 120fd0f:	c5 fc 11 85 30 fc ff 	vmovups %ymm0,-0x3d0(%rbp)
 120fd16:	ff 
 120fd17:	c7 85 68 ff ff ff 00 	movl   $0x0,-0x98(%rbp)
 120fd1e:	00 00 00 
 120fd21:	c7 85 6b ff ff ff 00 	movl   $0x0,-0x95(%rbp)
 120fd28:	00 00 00 
 120fd2b:	c5 fc 10 85 70 fd ff 	vmovups -0x290(%rbp),%ymm0
 120fd32:	ff 
 120fd33:	c5 fc 11 85 80 fc ff 	vmovups %ymm0,-0x380(%rbp)
 120fd3a:	ff 
 120fd3b:	c5 fc 10 85 90 fd ff 	vmovups -0x270(%rbp),%ymm0
 120fd42:	ff 
 120fd43:	c5 fc 11 85 a0 fc ff 	vmovups %ymm0,-0x360(%rbp)
 120fd4a:	ff 
 120fd4b:	48 8b 85 ae fd ff ff 	mov    -0x252(%rbp),%rax
 120fd52:	48 89 85 be fc ff ff 	mov    %rax,-0x342(%rbp)
 120fd59:	c7 85 70 ff ff ff 00 	movl   $0x0,-0x90(%rbp)
 120fd60:	00 00 00 
 120fd63:	c7 85 73 ff ff ff 00 	movl   $0x0,-0x8d(%rbp)
 120fd6a:	00 00 00 
 120fd6d:	48 8b 85 fe fd ff ff 	mov    -0x202(%rbp),%rax
 120fd74:	48 89 85 0e fd ff ff 	mov    %rax,-0x2f2(%rbp)
 120fd7b:	c5 fc 10 85 e0 fd ff 	vmovups -0x220(%rbp),%ymm0
 120fd82:	ff 
 120fd83:	c5 fc 11 85 f0 fc ff 	vmovups %ymm0,-0x310(%rbp)
 120fd8a:	ff 
 120fd8b:	c5 fc 10 85 c0 fd ff 	vmovups -0x240(%rbp),%ymm0
 120fd92:	ff 
 120fd93:	c5 fc 11 85 d0 fc ff 	vmovups %ymm0,-0x330(%rbp)
 120fd9a:	ff 
 120fd9b:	c7 85 7b ff ff ff 00 	movl   $0x0,-0x85(%rbp)
 120fda2:	00 00 00 
 120fda5:	c7 85 78 ff ff ff 00 	movl   $0x0,-0x88(%rbp)
 120fdac:	00 00 00 
 120fdaf:	31 db                	xor    %ebx,%ebx
 120fdb1:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 120fdb5:	48 8b 55 88          	mov    -0x78(%rbp),%rdx
 120fdb9:	48 8b 75 c0          	mov    -0x40(%rbp),%rsi
 120fdbd:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 120fdc1:	4c 8b 45 b8          	mov    -0x48(%rbp),%r8
 120fdc5:	4c 8b 4d 98          	mov    -0x68(%rbp),%r9
 120fdc9:	4c 8b 75 d0          	mov    -0x30(%rbp),%r14
 120fdcd:	e9 cc f4 ff ff       	jmp    120f29e <br.encoder.literal_context_split.chooseProposals+0x44e>
 120fdd2:	ba 08 04 04 00       	mov    $0x40408,%edx
 120fdd7:	48 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%rdi
 120fdde:	48 8b 75 a0          	mov    -0x60(%rbp),%rsi
 120fde2:	eb 0f                	jmp    120fdf3 <br.encoder.literal_context_split.chooseProposals+0xfa3>
 120fde4:	ba 08 04 04 00       	mov    $0x40408,%edx
 120fde9:	48 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%rdi
 120fdf0:	4c 89 e6             	mov    %r12,%rsi
 120fdf3:	b9 03 00 00 00       	mov    $0x3,%ecx
 120fdf8:	4c 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%r8
 120fdff:	48 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%rax
 120fe06:	ff 50 18             	call   *0x18(%rax)
 120fe09:	e9 92 f3 ff ff       	jmp    120f1a0 <br.encoder.literal_context_split.chooseProposals+0x350>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
