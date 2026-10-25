
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120ee00 <br.encoder.literal_context_split.chooseProposals>:
 120ee00:	55                   	push   %rbp
 120ee01:	48 89 e5             	mov    %rsp,%rbp
 120ee04:	41 57                	push   %r15
 120ee06:	41 56                	push   %r14
 120ee08:	41 55                	push   %r13
 120ee0a:	41 54                	push   %r12
 120ee0c:	53                   	push   %rbx
 120ee0d:	48 81 ec 78 0e 02 00 	sub    $0x20e78,%rsp
 120ee14:	4c 89 cb             	mov    %r9,%rbx
 120ee17:	4d 89 c7             	mov    %r8,%r15
 120ee1a:	48 89 8d 30 ff ff ff 	mov    %rcx,-0xd0(%rbp)
 120ee21:	48 89 d0             	mov    %rdx,%rax
 120ee24:	48 89 f2             	mov    %rsi,%rdx
 120ee27:	48 89 bd 28 fe ff ff 	mov    %rdi,-0x1d8(%rbp)
 120ee2e:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 120ee32:	be 08 04 04 00       	mov    $0x40408,%esi
 120ee37:	48 89 95 60 ff ff ff 	mov    %rdx,-0xa0(%rbp)
 120ee3e:	48 89 d7             	mov    %rdx,%rdi
 120ee41:	ba 03 00 00 00       	mov    $0x3,%edx
 120ee46:	48 89 8d 58 ff ff ff 	mov    %rcx,-0xa8(%rbp)
 120ee4d:	48 89 85 50 ff ff ff 	mov    %rax,-0xb0(%rbp)
 120ee54:	ff 10                	call   *(%rax)
 120ee56:	48 85 c0             	test   %rax,%rax
 120ee59:	0f 84 fd 02 00 00    	je     120f15c <br.encoder.literal_context_split.chooseProposals+0x35c>
 120ee5f:	49 89 c4             	mov    %rax,%r12
 120ee62:	ba 08 04 04 00       	mov    $0x40408,%edx
 120ee67:	48 89 c7             	mov    %rax,%rdi
 120ee6a:	31 f6                	xor    %esi,%esi
 120ee6c:	e8 8f 6f 08 00       	call   1295e00 <compiler_rt.memset>
 120ee71:	48 83 7d 10 00       	cmpq   $0x0,0x10(%rbp)
 120ee76:	0f 84 f7 02 00 00    	je     120f173 <br.encoder.literal_context_split.chooseProposals+0x373>
 120ee7c:	4d 8d b4 24 08 00 04 	lea    0x40008(%r12),%r14
 120ee83:	00 
 120ee84:	49 8d 44 24 08       	lea    0x8(%r12),%rax
 120ee89:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 120ee8d:	49 8d 84 24 08 00 01 	lea    0x10008(%r12),%rax
 120ee94:	00 
 120ee95:	48 89 85 18 ff ff ff 	mov    %rax,-0xe8(%rbp)
 120ee9c:	49 8d 84 24 08 00 02 	lea    0x20008(%r12),%rax
 120eea3:	00 
 120eea4:	48 89 85 20 ff ff ff 	mov    %rax,-0xe0(%rbp)
 120eeab:	4c 89 e0             	mov    %r12,%rax
 120eeae:	48 05 08 00 03 00    	add    $0x30008,%rax
 120eeb4:	48 89 85 28 ff ff ff 	mov    %rax,-0xd8(%rbp)
 120eebb:	48 c7 45 c0 00 00 00 	movq   $0x0,-0x40(%rbp)
 120eec2:	00 
 120eec3:	31 c0                	xor    %eax,%eax
 120eec5:	4c 89 65 b0          	mov    %r12,-0x50(%rbp)
 120eec9:	4c 89 b5 40 ff ff ff 	mov    %r14,-0xc0(%rbp)
 120eed0:	48 89 9d 38 ff ff ff 	mov    %rbx,-0xc8(%rbp)
 120eed7:	4c 89 bd 48 ff ff ff 	mov    %r15,-0xb8(%rbp)
 120eede:	eb 23                	jmp    120ef03 <br.encoder.literal_context_split.chooseProposals+0x103>
 120eee0:	4c 01 7d c0          	add    %r15,-0x40(%rbp)
 120eee4:	48 8b 9d 38 ff ff ff 	mov    -0xc8(%rbp),%rbx
 120eeeb:	4c 8b bd 48 ff ff ff 	mov    -0xb8(%rbp),%r15
 120eef2:	48 8b 45 a0          	mov    -0x60(%rbp),%rax
 120eef6:	48 ff c0             	inc    %rax
 120eef9:	48 3b 45 10          	cmp    0x10(%rbp),%rax
 120eefd:	0f 84 62 02 00 00    	je     120f165 <br.encoder.literal_context_split.chooseProposals+0x365>
 120ef03:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 120ef07:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 120ef0b:	48 c1 e0 05          	shl    $0x5,%rax
 120ef0f:	48 8b 0c 03          	mov    (%rbx,%rax,1),%rcx
 120ef13:	48 8b 74 03 08       	mov    0x8(%rbx,%rax,1),%rsi
 120ef18:	48 89 c8             	mov    %rcx,%rax
 120ef1b:	48 01 f0             	add    %rsi,%rax
 120ef1e:	0f 92 85 68 f1 fd ff 	setb   -0x20e98(%rbp)
 120ef25:	0f 82 48 02 00 00    	jb     120f173 <br.encoder.literal_context_split.chooseProposals+0x373>
 120ef2b:	4c 39 f8             	cmp    %r15,%rax
 120ef2e:	0f 87 3f 02 00 00    	ja     120f173 <br.encoder.literal_context_split.chooseProposals+0x373>
 120ef34:	48 39 c8             	cmp    %rcx,%rax
 120ef37:	74 b9                	je     120eef2 <br.encoder.literal_context_split.chooseProposals+0xf2>
 120ef39:	48 89 f2             	mov    %rsi,%rdx
 120ef3c:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 120ef43:	48 8d 34 08          	lea    (%rax,%rcx,1),%rsi
 120ef47:	48 83 fa 01          	cmp    $0x1,%rdx
 120ef4b:	48 83 d2 00          	adc    $0x0,%rdx
 120ef4f:	48 89 95 70 ff ff ff 	mov    %rdx,-0x90(%rbp)
 120ef56:	b8 01 00 00 00       	mov    $0x1,%eax
 120ef5b:	48 29 c8             	sub    %rcx,%rax
 120ef5e:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 120ef62:	48 f7 d9             	neg    %rcx
 120ef65:	45 31 ff             	xor    %r15d,%r15d
 120ef68:	48 89 4d c8          	mov    %rcx,-0x38(%rbp)
 120ef6c:	48 89 75 a8          	mov    %rsi,-0x58(%rbp)
 120ef70:	eb 50                	jmp    120efc2 <br.encoder.literal_context_split.chooseProposals+0x1c2>
 120ef72:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120ef79:	1f 84 00 00 00 00 00 
 120ef80:	41 be 07 00 00 00    	mov    $0x7,%r14d
 120ef86:	49 c1 e6 0a          	shl    $0xa,%r14
 120ef8a:	4c 03 b5 28 ff ff ff 	add    -0xd8(%rbp),%r14
 120ef91:	41 c1 e5 0a          	shl    $0xa,%r13d
 120ef95:	4d 01 f5             	add    %r14,%r13
 120ef98:	41 ff 44 95 00       	incl   0x0(%r13,%rdx,4)
 120ef9d:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 120efa1:	4c 01 f8             	add    %r15,%rax
 120efa4:	48 ff c0             	inc    %rax
 120efa7:	49 89 04 24          	mov    %rax,(%r12)
 120efab:	49 ff c7             	inc    %r15
 120efae:	4c 39 bd 70 ff ff ff 	cmp    %r15,-0x90(%rbp)
 120efb5:	4c 8b b5 40 ff ff ff 	mov    -0xc0(%rbp),%r14
 120efbc:	0f 84 1e ff ff ff    	je     120eee0 <br.encoder.literal_context_split.chooseProposals+0xe0>
 120efc2:	4c 39 f9             	cmp    %r15,%rcx
 120efc5:	75 09                	jne    120efd0 <br.encoder.literal_context_split.chooseProposals+0x1d0>
 120efc7:	31 db                	xor    %ebx,%ebx
 120efc9:	eb 11                	jmp    120efdc <br.encoder.literal_context_split.chooseProposals+0x1dc>
 120efcb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120efd0:	42 0f b6 5c 3e ff    	movzbl -0x1(%rsi,%r15,1),%ebx
 120efd6:	4c 39 7d 90          	cmp    %r15,-0x70(%rbp)
 120efda:	75 04                	jne    120efe0 <br.encoder.literal_context_split.chooseProposals+0x1e0>
 120efdc:	31 c9                	xor    %ecx,%ecx
 120efde:	eb 06                	jmp    120efe6 <br.encoder.literal_context_split.chooseProposals+0x1e6>
 120efe0:	42 0f b6 4c 3e fe    	movzbl -0x2(%rsi,%r15,1),%ecx
 120efe6:	42 0f b6 04 3e       	movzbl (%rsi,%r15,1),%eax
 120efeb:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 120efef:	44 8d 24 85 00 00 00 	lea    0x0(,%rax,4),%r12d
 120eff6:	00 
 120eff7:	43 ff 04 26          	incl   (%r14,%r12,1)
 120effb:	89 d8                	mov    %ebx,%eax
 120effd:	24 3f                	and    $0x3f,%al
 120efff:	0f b6 c0             	movzbl %al,%eax
 120f002:	c1 e0 0a             	shl    $0xa,%eax
 120f005:	48 03 45 98          	add    -0x68(%rbp),%rax
 120f009:	41 ff 04 04          	incl   (%r12,%rax,1)
 120f00d:	89 d8                	mov    %ebx,%eax
 120f00f:	c0 e8 02             	shr    $0x2,%al
 120f012:	0f b6 c0             	movzbl %al,%eax
 120f015:	c1 e0 0a             	shl    $0xa,%eax
 120f018:	48 03 85 18 ff ff ff 	add    -0xe8(%rbp),%rax
 120f01f:	41 ff 04 04          	incl   (%r12,%rax,1)
 120f023:	44 0f b6 eb          	movzbl %bl,%r13d
 120f027:	48 89 4d b8          	mov    %rcx,-0x48(%rbp)
 120f02b:	44 0f b6 f1          	movzbl %cl,%r14d
 120f02f:	bf 02 00 00 00       	mov    $0x2,%edi
 120f034:	44 89 ee             	mov    %r13d,%esi
 120f037:	44 89 f2             	mov    %r14d,%edx
 120f03a:	e8 71 f3 fa ff       	call   11be3b0 <br.encoder.literal_context.value>
 120f03f:	c1 e0 0a             	shl    $0xa,%eax
 120f042:	48 03 85 20 ff ff ff 	add    -0xe0(%rbp),%rax
 120f049:	41 ff 04 04          	incl   (%r12,%rax,1)
 120f04d:	45 84 ed             	test   %r13b,%r13b
 120f050:	74 13                	je     120f065 <br.encoder.literal_context_split.chooseProposals+0x265>
 120f052:	41 81 fd ff 00 00 00 	cmp    $0xff,%r13d
 120f059:	0f 85 91 00 00 00    	jne    120f0f0 <br.encoder.literal_context_split.chooseProposals+0x2f0>
 120f05f:	41 bd 38 00 00 00    	mov    $0x38,%r13d
 120f065:	4c 8b 65 b0          	mov    -0x50(%rbp),%r12
 120f069:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 120f06d:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 120f071:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 120f075:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 120f079:	40 84 ff             	test   %dil,%dil
 120f07c:	0f 84 04 ff ff ff    	je     120ef86 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f082:	41 81 fe ff 00 00 00 	cmp    $0xff,%r14d
 120f089:	0f 84 f1 fe ff ff    	je     120ef80 <br.encoder.literal_context_split.chooseProposals+0x180>
 120f08f:	8d 47 ff             	lea    -0x1(%rdi),%eax
 120f092:	41 be 01 00 00 00    	mov    $0x1,%r14d
 120f098:	3c 0f                	cmp    $0xf,%al
 120f09a:	0f 82 e6 fe ff ff    	jb     120ef86 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f0a0:	8d 47 f0             	lea    -0x10(%rdi),%eax
 120f0a3:	41 be 02 00 00 00    	mov    $0x2,%r14d
 120f0a9:	3c 30                	cmp    $0x30,%al
 120f0ab:	0f 82 d5 fe ff ff    	jb     120ef86 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f0b1:	41 be 03 00 00 00    	mov    $0x3,%r14d
 120f0b7:	40 80 ff 3f          	cmp    $0x3f,%dil
 120f0bb:	0f 8f c5 fe ff ff    	jg     120ef86 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f0c1:	41 be 04 00 00 00    	mov    $0x4,%r14d
 120f0c7:	40 80 ff c0          	cmp    $0xc0,%dil
 120f0cb:	0f 82 b5 fe ff ff    	jb     120ef86 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f0d1:	40 80 c7 40          	add    $0x40,%dil
 120f0d5:	40 80 ff 30          	cmp    $0x30,%dil
 120f0d9:	41 be 06 00 00 00    	mov    $0x6,%r14d
 120f0df:	49 83 de 00          	sbb    $0x0,%r14
 120f0e3:	e9 9e fe ff ff       	jmp    120ef86 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f0e8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120f0ef:	00 
 120f0f0:	8d 43 ff             	lea    -0x1(%rbx),%eax
 120f0f3:	41 bd 08 00 00 00    	mov    $0x8,%r13d
 120f0f9:	3c 0f                	cmp    $0xf,%al
 120f0fb:	4c 8b 65 b0          	mov    -0x50(%rbp),%r12
 120f0ff:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 120f103:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 120f107:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 120f10b:	48 8b 7d b8          	mov    -0x48(%rbp),%rdi
 120f10f:	0f 82 64 ff ff ff    	jb     120f079 <br.encoder.literal_context_split.chooseProposals+0x279>
 120f115:	8d 43 f0             	lea    -0x10(%rbx),%eax
 120f118:	41 bd 10 00 00 00    	mov    $0x10,%r13d
 120f11e:	3c 30                	cmp    $0x30,%al
 120f120:	0f 82 53 ff ff ff    	jb     120f079 <br.encoder.literal_context_split.chooseProposals+0x279>
 120f126:	41 bd 18 00 00 00    	mov    $0x18,%r13d
 120f12c:	80 fb 3f             	cmp    $0x3f,%bl
 120f12f:	0f 8f 44 ff ff ff    	jg     120f079 <br.encoder.literal_context_split.chooseProposals+0x279>
 120f135:	41 bd 20 00 00 00    	mov    $0x20,%r13d
 120f13b:	80 fb c0             	cmp    $0xc0,%bl
 120f13e:	0f 82 35 ff ff ff    	jb     120f079 <br.encoder.literal_context_split.chooseProposals+0x279>
 120f144:	80 c3 40             	add    $0x40,%bl
 120f147:	31 c0                	xor    %eax,%eax
 120f149:	80 fb 30             	cmp    $0x30,%bl
 120f14c:	0f 93 c0             	setae  %al
 120f14f:	4c 8d 2c c5 28 00 00 	lea    0x28(,%rax,8),%r13
 120f156:	00 
 120f157:	e9 1d ff ff ff       	jmp    120f079 <br.encoder.literal_context_split.chooseProposals+0x279>
 120f15c:	66 bb 1a 00          	mov    $0x1a,%bx
 120f160:	e9 ed 00 00 00       	jmp    120f252 <br.encoder.literal_context_split.chooseProposals+0x452>
 120f165:	48 81 7d c0 80 00 00 	cmpq   $0x80,-0x40(%rbp)
 120f16c:	00 
 120f16d:	0f 83 0c 02 00 00    	jae    120f37f <br.encoder.literal_context_split.chooseProposals+0x57f>
 120f173:	ba 08 04 04 00       	mov    $0x40408,%edx
 120f178:	48 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%rdi
 120f17f:	4c 89 e6             	mov    %r12,%rsi
 120f182:	b9 03 00 00 00       	mov    $0x3,%ecx
 120f187:	4c 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%r8
 120f18e:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 120f195:	ff 50 18             	call   *0x18(%rax)
 120f198:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 120f19c:	c5 fc 11 85 40 fc ff 	vmovups %ymm0,-0x3c0(%rbp)
 120f1a3:	ff 
 120f1a4:	c5 fc 11 85 20 fc ff 	vmovups %ymm0,-0x3e0(%rbp)
 120f1ab:	ff 
 120f1ac:	48 c7 85 5e fc ff ff 	movq   $0x0,-0x3a2(%rbp)
 120f1b3:	00 00 00 00 
 120f1b7:	c7 85 78 ff ff ff 00 	movl   $0x0,-0x88(%rbp)
 120f1be:	00 00 00 
 120f1c1:	c7 85 7b ff ff ff 00 	movl   $0x0,-0x85(%rbp)
 120f1c8:	00 00 00 
 120f1cb:	c5 fc 11 85 70 fc ff 	vmovups %ymm0,-0x390(%rbp)
 120f1d2:	ff 
 120f1d3:	c5 fc 11 85 90 fc ff 	vmovups %ymm0,-0x370(%rbp)
 120f1da:	ff 
 120f1db:	48 c7 85 ae fc ff ff 	movq   $0x0,-0x352(%rbp)
 120f1e2:	00 00 00 00 
 120f1e6:	c7 45 80 00 00 00 00 	movl   $0x0,-0x80(%rbp)
 120f1ed:	c7 45 83 00 00 00 00 	movl   $0x0,-0x7d(%rbp)
 120f1f4:	c5 fc 11 85 c0 fc ff 	vmovups %ymm0,-0x340(%rbp)
 120f1fb:	ff 
 120f1fc:	c5 fc 11 85 e0 fc ff 	vmovups %ymm0,-0x320(%rbp)
 120f203:	ff 
 120f204:	48 c7 85 fe fc ff ff 	movq   $0x0,-0x302(%rbp)
 120f20b:	00 00 00 00 
 120f20f:	c7 45 88 00 00 00 00 	movl   $0x0,-0x78(%rbp)
 120f216:	c7 45 8b 00 00 00 00 	movl   $0x0,-0x75(%rbp)
 120f21d:	c7 85 68 ff ff ff 00 	movl   $0x0,-0x98(%rbp)
 120f224:	00 00 00 
 120f227:	66 c7 85 6c ff ff ff 	movw   $0x0,-0x94(%rbp)
 120f22e:	00 00 
 120f230:	45 31 e4             	xor    %r12d,%r12d
 120f233:	31 d2                	xor    %edx,%edx
 120f235:	31 c0                	xor    %eax,%eax
 120f237:	31 f6                	xor    %esi,%esi
 120f239:	31 ff                	xor    %edi,%edi
 120f23b:	45 31 c0             	xor    %r8d,%r8d
 120f23e:	45 31 c9             	xor    %r9d,%r9d
 120f241:	45 31 f6             	xor    %r14d,%r14d
 120f244:	45 31 ed             	xor    %r13d,%r13d
 120f247:	45 31 d2             	xor    %r10d,%r10d
 120f24a:	45 31 db             	xor    %r11d,%r11d
 120f24d:	45 31 ff             	xor    %r15d,%r15d
 120f250:	31 db                	xor    %ebx,%ebx
 120f252:	48 8b 8d 28 fe ff ff 	mov    -0x1d8(%rbp),%rcx
 120f259:	4c 89 21             	mov    %r12,(%rcx)
 120f25c:	88 51 08             	mov    %dl,0x8(%rcx)
 120f25f:	88 41 09             	mov    %al,0x9(%rcx)
 120f262:	c5 fc 10 85 40 fc ff 	vmovups -0x3c0(%rbp),%ymm0
 120f269:	ff 
 120f26a:	c5 fc 11 41 2a       	vmovups %ymm0,0x2a(%rcx)
 120f26f:	48 8b 85 5e fc ff ff 	mov    -0x3a2(%rbp),%rax
 120f276:	48 89 41 48          	mov    %rax,0x48(%rcx)
 120f27a:	c5 fc 10 85 20 fc ff 	vmovups -0x3e0(%rbp),%ymm0
 120f281:	ff 
 120f282:	c5 fc 11 41 0a       	vmovups %ymm0,0xa(%rcx)
 120f287:	40 88 71 50          	mov    %sil,0x50(%rcx)
 120f28b:	8b 85 78 ff ff ff    	mov    -0x88(%rbp),%eax
 120f291:	89 41 51             	mov    %eax,0x51(%rcx)
 120f294:	8b 85 7b ff ff ff    	mov    -0x85(%rbp),%eax
 120f29a:	89 41 54             	mov    %eax,0x54(%rcx)
 120f29d:	48 89 79 58          	mov    %rdi,0x58(%rcx)
 120f2a1:	44 88 41 60          	mov    %r8b,0x60(%rcx)
 120f2a5:	44 88 49 61          	mov    %r9b,0x61(%rcx)
 120f2a9:	c5 fc 10 85 90 fc ff 	vmovups -0x370(%rbp),%ymm0
 120f2b0:	ff 
 120f2b1:	c5 fc 11 81 82 00 00 	vmovups %ymm0,0x82(%rcx)
 120f2b8:	00 
 120f2b9:	48 8b 85 ae fc ff ff 	mov    -0x352(%rbp),%rax
 120f2c0:	48 89 81 a0 00 00 00 	mov    %rax,0xa0(%rcx)
 120f2c7:	c5 fc 10 85 70 fc ff 	vmovups -0x390(%rbp),%ymm0
 120f2ce:	ff 
 120f2cf:	c5 fc 11 41 62       	vmovups %ymm0,0x62(%rcx)
 120f2d4:	44 88 b1 a8 00 00 00 	mov    %r14b,0xa8(%rcx)
 120f2db:	8b 45 80             	mov    -0x80(%rbp),%eax
 120f2de:	89 81 a9 00 00 00    	mov    %eax,0xa9(%rcx)
 120f2e4:	8b 45 83             	mov    -0x7d(%rbp),%eax
 120f2e7:	89 81 ac 00 00 00    	mov    %eax,0xac(%rcx)
 120f2ed:	4c 89 a9 b0 00 00 00 	mov    %r13,0xb0(%rcx)
 120f2f4:	44 88 91 b8 00 00 00 	mov    %r10b,0xb8(%rcx)
 120f2fb:	44 88 99 b9 00 00 00 	mov    %r11b,0xb9(%rcx)
 120f302:	48 8b 85 fe fc ff ff 	mov    -0x302(%rbp),%rax
 120f309:	48 89 81 f8 00 00 00 	mov    %rax,0xf8(%rcx)
 120f310:	c5 fc 10 85 c0 fc ff 	vmovups -0x340(%rbp),%ymm0
 120f317:	ff 
 120f318:	c5 fc 10 8d e0 fc ff 	vmovups -0x320(%rbp),%ymm1
 120f31f:	ff 
 120f320:	c5 fc 11 89 da 00 00 	vmovups %ymm1,0xda(%rcx)
 120f327:	00 
 120f328:	c5 fc 11 81 ba 00 00 	vmovups %ymm0,0xba(%rcx)
 120f32f:	00 
 120f330:	44 88 b9 00 01 00 00 	mov    %r15b,0x100(%rcx)
 120f337:	8b 45 8b             	mov    -0x75(%rbp),%eax
 120f33a:	89 81 04 01 00 00    	mov    %eax,0x104(%rcx)
 120f340:	8b 45 88             	mov    -0x78(%rbp),%eax
 120f343:	89 81 01 01 00 00    	mov    %eax,0x101(%rcx)
 120f349:	66 89 99 08 01 00 00 	mov    %bx,0x108(%rcx)
 120f350:	8b 85 68 ff ff ff    	mov    -0x98(%rbp),%eax
 120f356:	89 81 0a 01 00 00    	mov    %eax,0x10a(%rcx)
 120f35c:	0f b7 85 6c ff ff ff 	movzwl -0x94(%rbp),%eax
 120f363:	66 89 81 0e 01 00 00 	mov    %ax,0x10e(%rcx)
 120f36a:	48 81 c4 78 0e 02 00 	add    $0x20e78,%rsp
 120f371:	5b                   	pop    %rbx
 120f372:	41 5c                	pop    %r12
 120f374:	41 5d                	pop    %r13
 120f376:	41 5e                	pop    %r14
 120f378:	41 5f                	pop    %r15
 120f37a:	5d                   	pop    %rbp
 120f37b:	c5 f8 77             	vzeroupper 
 120f37e:	c3                   	ret    
 120f37f:	31 c0                	xor    %eax,%eax
 120f381:	31 c9                	xor    %ecx,%ecx
 120f383:	eb 18                	jmp    120f39d <br.encoder.literal_context_split.chooseProposals+0x59d>
 120f385:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120f38c:	00 00 00 00 
 120f390:	48 83 c1 04          	add    $0x4,%rcx
 120f394:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 120f39b:	74 6a                	je     120f407 <br.encoder.literal_context_split.chooseProposals+0x607>
 120f39d:	41 83 bc 8c 08 00 04 	cmpl   $0x0,0x40008(%r12,%rcx,4)
 120f3a4:	00 00 
 120f3a6:	74 0c                	je     120f3b4 <br.encoder.literal_context_split.chooseProposals+0x5b4>
 120f3a8:	0f b7 d0             	movzwl %ax,%edx
 120f3ab:	88 8c 15 20 fb ff ff 	mov    %cl,-0x4e0(%rbp,%rdx,1)
 120f3b2:	ff c0                	inc    %eax
 120f3b4:	41 83 bc 8c 0c 00 04 	cmpl   $0x0,0x4000c(%r12,%rcx,4)
 120f3bb:	00 00 
 120f3bd:	74 10                	je     120f3cf <br.encoder.literal_context_split.chooseProposals+0x5cf>
 120f3bf:	0f b7 d0             	movzwl %ax,%edx
 120f3c2:	8d 71 01             	lea    0x1(%rcx),%esi
 120f3c5:	40 88 b4 15 20 fb ff 	mov    %sil,-0x4e0(%rbp,%rdx,1)
 120f3cc:	ff 
 120f3cd:	ff c0                	inc    %eax
 120f3cf:	41 83 bc 8c 10 00 04 	cmpl   $0x0,0x40010(%r12,%rcx,4)
 120f3d6:	00 00 
 120f3d8:	74 10                	je     120f3ea <br.encoder.literal_context_split.chooseProposals+0x5ea>
 120f3da:	0f b7 d0             	movzwl %ax,%edx
 120f3dd:	8d 71 02             	lea    0x2(%rcx),%esi
 120f3e0:	40 88 b4 15 20 fb ff 	mov    %sil,-0x4e0(%rbp,%rdx,1)
 120f3e7:	ff 
 120f3e8:	ff c0                	inc    %eax
 120f3ea:	41 83 bc 8c 14 00 04 	cmpl   $0x0,0x40014(%r12,%rcx,4)
 120f3f1:	00 00 
 120f3f3:	74 9b                	je     120f390 <br.encoder.literal_context_split.chooseProposals+0x590>
 120f3f5:	0f b7 d0             	movzwl %ax,%edx
 120f3f8:	8d 71 03             	lea    0x3(%rcx),%esi
 120f3fb:	40 88 b4 15 20 fb ff 	mov    %sil,-0x4e0(%rbp,%rdx,1)
 120f402:	ff 
 120f403:	ff c0                	inc    %eax
 120f405:	eb 89                	jmp    120f390 <br.encoder.literal_context_split.chooseProposals+0x590>
 120f407:	66 89 85 1e fb ff ff 	mov    %ax,-0x4e2(%rbp)
 120f40e:	4c 8d bd 68 f1 fd ff 	lea    -0x20e98(%rbp),%r15
 120f415:	ba b0 09 02 00       	mov    $0x209b0,%edx
 120f41a:	4c 89 ff             	mov    %r15,%rdi
 120f41d:	31 f6                	xor    %esi,%esi
 120f41f:	e8 dc 69 08 00       	call   1295e00 <compiler_rt.memset>
 120f424:	48 8d bd 08 fd ff ff 	lea    -0x2f8(%rbp),%rdi
 120f42b:	4c 8d ad 1e fb ff ff 	lea    -0x4e2(%rbp),%r13
 120f432:	4c 89 f6             	mov    %r14,%rsi
 120f435:	4c 89 ea             	mov    %r13,%rdx
 120f438:	4c 89 f9             	mov    %r15,%rcx
 120f43b:	e8 30 d2 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostCached__anon_46145>
 120f440:	0f b7 9d 10 fd ff ff 	movzwl -0x2f0(%rbp),%ebx
 120f447:	66 85 db             	test   %bx,%bx
 120f44a:	0f 85 42 09 00 00    	jne    120fd92 <br.encoder.literal_context_split.chooseProposals+0xf92>
 120f450:	4c 8b 8d 08 fd ff ff 	mov    -0x2f8(%rbp),%r9
 120f457:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 120f45b:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 120f462:	ff 
 120f463:	c5 fc 11 85 50 fe ff 	vmovups %ymm0,-0x1b0(%rbp)
 120f46a:	ff 
 120f46b:	48 c7 85 6e fe ff ff 	movq   $0x0,-0x192(%rbp)
 120f472:	00 00 00 00 
 120f476:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 120f47d:	ff 
 120f47e:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 120f485:	ff 
 120f486:	48 c7 85 be fe ff ff 	movq   $0x0,-0x142(%rbp)
 120f48d:	00 00 00 00 
 120f491:	c5 fc 11 85 d0 fe ff 	vmovups %ymm0,-0x130(%rbp)
 120f498:	ff 
 120f499:	c5 fc 11 85 f0 fe ff 	vmovups %ymm0,-0x110(%rbp)
 120f4a0:	ff 
 120f4a1:	48 c7 85 0e ff ff ff 	movq   $0x0,-0xf2(%rbp)
 120f4a8:	00 00 00 00 
 120f4ac:	4d 8b 04 24          	mov    (%r12),%r8
 120f4b0:	48 8d bd 18 fd ff ff 	lea    -0x2e8(%rbp),%rdi
 120f4b7:	31 f6                	xor    %esi,%esi
 120f4b9:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 120f4bd:	4c 89 f1             	mov    %r14,%rcx
 120f4c0:	4c 89 8d 70 ff ff ff 	mov    %r9,-0x90(%rbp)
 120f4c7:	41 57                	push   %r15
 120f4c9:	41 55                	push   %r13
 120f4cb:	c5 f8 77             	vzeroupper 
 120f4ce:	e8 dd dc ff ff       	call   120d1b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230>
 120f4d3:	48 83 c4 10          	add    $0x10,%rsp
 120f4d7:	0f b7 9d 20 fe ff ff 	movzwl -0x1e0(%rbp),%ebx
 120f4de:	66 85 db             	test   %bx,%bx
 120f4e1:	0f 85 99 08 00 00    	jne    120fd80 <br.encoder.literal_context_split.chooseProposals+0xf80>
 120f4e7:	48 8d 95 22 fd ff ff 	lea    -0x2de(%rbp),%rdx
 120f4ee:	0f b6 85 68 fd ff ff 	movzbl -0x298(%rbp),%eax
 120f4f5:	0f b6 b5 c0 fd ff ff 	movzbl -0x240(%rbp),%esi
 120f4fc:	88 85 38 ff ff ff    	mov    %al,-0xc8(%rbp)
 120f502:	84 c0                	test   %al,%al
 120f504:	74 48                	je     120f54e <br.encoder.literal_context_split.chooseProposals+0x74e>
 120f506:	0f b6 85 21 fd ff ff 	movzbl -0x2df(%rbp),%eax
 120f50d:	48 89 45 c8          	mov    %rax,-0x38(%rbp)
 120f511:	0f b6 8d 20 fd ff ff 	movzbl -0x2e0(%rbp),%ecx
 120f518:	48 8b 85 18 fd ff ff 	mov    -0x2e8(%rbp),%rax
 120f51f:	48 89 85 48 ff ff ff 	mov    %rax,-0xb8(%rbp)
 120f526:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 120f52a:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 120f531:	ff 
 120f532:	c5 fc 10 42 20       	vmovups 0x20(%rdx),%ymm0
 120f537:	c5 fc 11 85 50 fe ff 	vmovups %ymm0,-0x1b0(%rbp)
 120f53e:	ff 
 120f53f:	48 8b 42 3e          	mov    0x3e(%rdx),%rax
 120f543:	48 89 85 6e fe ff ff 	mov    %rax,-0x192(%rbp)
 120f54a:	b2 01                	mov    $0x1,%dl
 120f54c:	eb 0c                	jmp    120f55a <br.encoder.literal_context_split.chooseProposals+0x75a>
 120f54e:	31 d2                	xor    %edx,%edx
 120f550:	48 c7 45 c8 00 00 00 	movq   $0x0,-0x38(%rbp)
 120f557:	00 
 120f558:	31 c9                	xor    %ecx,%ecx
 120f55a:	4c 8d 85 7a fd ff ff 	lea    -0x286(%rbp),%r8
 120f561:	44 0f b6 8d 18 fe ff 	movzbl -0x1e8(%rbp),%r9d
 120f568:	ff 
 120f569:	40 88 75 d0          	mov    %sil,-0x30(%rbp)
 120f56d:	40 84 f6             	test   %sil,%sil
 120f570:	74 40                	je     120f5b2 <br.encoder.literal_context_split.chooseProposals+0x7b2>
 120f572:	4c 8b a5 70 fd ff ff 	mov    -0x290(%rbp),%r12
 120f579:	0f b6 b5 78 fd ff ff 	movzbl -0x288(%rbp),%esi
 120f580:	0f b6 bd 79 fd ff ff 	movzbl -0x287(%rbp),%edi
 120f587:	49 8b 40 3e          	mov    0x3e(%r8),%rax
 120f58b:	48 89 85 be fe ff ff 	mov    %rax,-0x142(%rbp)
 120f592:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f597:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f59d:	c5 fc 11 8d a0 fe ff 	vmovups %ymm1,-0x160(%rbp)
 120f5a4:	ff 
 120f5a5:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 120f5ac:	ff 
 120f5ad:	41 b6 01             	mov    $0x1,%r14b
 120f5b0:	eb 07                	jmp    120f5b9 <br.encoder.literal_context_split.chooseProposals+0x7b9>
 120f5b2:	45 31 f6             	xor    %r14d,%r14d
 120f5b5:	31 ff                	xor    %edi,%edi
 120f5b7:	31 f6                	xor    %esi,%esi
 120f5b9:	4c 8d 85 d2 fd ff ff 	lea    -0x22e(%rbp),%r8
 120f5c0:	45 84 c9             	test   %r9b,%r9b
 120f5c3:	48 89 4d 98          	mov    %rcx,-0x68(%rbp)
 120f5c7:	48 89 55 b8          	mov    %rdx,-0x48(%rbp)
 120f5cb:	48 89 75 90          	mov    %rsi,-0x70(%rbp)
 120f5cf:	48 89 7d a8          	mov    %rdi,-0x58(%rbp)
 120f5d3:	44 88 8d 30 ff ff ff 	mov    %r9b,-0xd0(%rbp)
 120f5da:	74 48                	je     120f624 <br.encoder.literal_context_split.chooseProposals+0x824>
 120f5dc:	4c 8b ad c8 fd ff ff 	mov    -0x238(%rbp),%r13
 120f5e3:	0f b6 85 d0 fd ff ff 	movzbl -0x230(%rbp),%eax
 120f5ea:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 120f5ee:	0f b6 85 d1 fd ff ff 	movzbl -0x22f(%rbp),%eax
 120f5f5:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 120f5f9:	49 8b 40 3e          	mov    0x3e(%r8),%rax
 120f5fd:	48 89 85 0e ff ff ff 	mov    %rax,-0xf2(%rbp)
 120f604:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f609:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f60f:	c5 fc 11 8d f0 fe ff 	vmovups %ymm1,-0x110(%rbp)
 120f616:	ff 
 120f617:	c5 fc 11 85 d0 fe ff 	vmovups %ymm0,-0x130(%rbp)
 120f61e:	ff 
 120f61f:	41 b7 01             	mov    $0x1,%r15b
 120f622:	eb 13                	jmp    120f637 <br.encoder.literal_context_split.chooseProposals+0x837>
 120f624:	48 c7 45 a0 00 00 00 	movq   $0x0,-0x60(%rbp)
 120f62b:	00 
 120f62c:	48 c7 45 c0 00 00 00 	movq   $0x0,-0x40(%rbp)
 120f633:	00 
 120f634:	45 31 ff             	xor    %r15d,%r15d
 120f637:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 120f63b:	4c 8b 00             	mov    (%rax),%r8
 120f63e:	48 8d bd 18 fd ff ff 	lea    -0x2e8(%rbp),%rdi
 120f645:	be 01 00 00 00       	mov    $0x1,%esi
 120f64a:	48 8b 95 18 ff ff ff 	mov    -0xe8(%rbp),%rdx
 120f651:	48 8b 8d 40 ff ff ff 	mov    -0xc0(%rbp),%rcx
 120f658:	4c 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%r9
 120f65f:	48 8d 85 68 f1 fd ff 	lea    -0x20e98(%rbp),%rax
 120f666:	50                   	push   %rax
 120f667:	48 8d 85 1e fb ff ff 	lea    -0x4e2(%rbp),%rax
 120f66e:	50                   	push   %rax
 120f66f:	c5 f8 77             	vzeroupper 
 120f672:	e8 39 db ff ff       	call   120d1b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230>
 120f677:	48 83 c4 10          	add    $0x10,%rsp
 120f67b:	0f b7 9d 20 fe ff ff 	movzwl -0x1e0(%rbp),%ebx
 120f682:	66 85 db             	test   %bx,%bx
 120f685:	0f 85 f5 06 00 00    	jne    120fd80 <br.encoder.literal_context_split.chooseProposals+0xf80>
 120f68b:	0f b6 85 c0 fd ff ff 	movzbl -0x240(%rbp),%eax
 120f692:	80 bd 68 fd ff ff 00 	cmpb   $0x0,-0x298(%rbp)
 120f699:	4d 89 e3             	mov    %r12,%r11
 120f69c:	0f 84 9e 00 00 00    	je     120f740 <br.encoder.literal_context_split.chooseProposals+0x940>
 120f6a2:	48 8b 8d 18 fd ff ff 	mov    -0x2e8(%rbp),%rcx
 120f6a9:	0f b6 95 20 fd ff ff 	movzbl -0x2e0(%rbp),%edx
 120f6b0:	0f b6 b5 21 fd ff ff 	movzbl -0x2df(%rbp),%esi
 120f6b7:	80 bd 38 ff ff ff 00 	cmpb   $0x0,-0xc8(%rbp)
 120f6be:	40 0f 94 c7          	sete   %dil
 120f6c2:	4c 8b a5 48 ff ff ff 	mov    -0xb8(%rbp),%r12
 120f6c9:	4c 39 e1             	cmp    %r12,%rcx
 120f6cc:	41 0f 97 c0          	seta   %r8b
 120f6d0:	41 08 f8             	or     %dil,%r8b
 120f6d3:	4c 8b 55 b0          	mov    -0x50(%rbp),%r10
 120f6d7:	75 26                	jne    120f6ff <br.encoder.literal_context_split.chooseProposals+0x8ff>
 120f6d9:	4c 39 e1             	cmp    %r12,%rcx
 120f6dc:	40 0f 94 c7          	sete   %dil
 120f6e0:	41 89 f0             	mov    %esi,%r8d
 120f6e3:	41 80 e0 7f          	and    $0x7f,%r8b
 120f6e7:	4c 8b 4d c8          	mov    -0x38(%rbp),%r9
 120f6eb:	41 80 e1 7f          	and    $0x7f,%r9b
 120f6ef:	45 38 c8             	cmp    %r9b,%r8b
 120f6f2:	41 0f 92 c0          	setb   %r8b
 120f6f6:	41 20 f8             	and    %dil,%r8b
 120f6f9:	41 80 f8 01          	cmp    $0x1,%r8b
 120f6fd:	75 4c                	jne    120f74b <br.encoder.literal_context_split.chooseProposals+0x94b>
 120f6ff:	4c 8d 85 22 fd ff ff 	lea    -0x2de(%rbp),%r8
 120f706:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f70a:	48 89 bd 6e fe ff ff 	mov    %rdi,-0x192(%rbp)
 120f711:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f716:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f71c:	c5 fc 11 8d 50 fe ff 	vmovups %ymm1,-0x1b0(%rbp)
 120f723:	ff 
 120f724:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 120f72b:	ff 
 120f72c:	40 b7 01             	mov    $0x1,%dil
 120f72f:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 120f733:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 120f737:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 120f73b:	49 89 cc             	mov    %rcx,%r12
 120f73e:	eb 0b                	jmp    120f74b <br.encoder.literal_context_split.chooseProposals+0x94b>
 120f740:	4c 8b 55 b0          	mov    -0x50(%rbp),%r10
 120f744:	4c 8b a5 48 ff ff ff 	mov    -0xb8(%rbp),%r12
 120f74b:	0f b6 8d 18 fe ff ff 	movzbl -0x1e8(%rbp),%ecx
 120f752:	84 c0                	test   %al,%al
 120f754:	0f 84 8a 00 00 00    	je     120f7e4 <br.encoder.literal_context_split.chooseProposals+0x9e4>
 120f75a:	48 8b 85 70 fd ff ff 	mov    -0x290(%rbp),%rax
 120f761:	0f b6 95 78 fd ff ff 	movzbl -0x288(%rbp),%edx
 120f768:	0f b6 b5 79 fd ff ff 	movzbl -0x287(%rbp),%esi
 120f76f:	80 7d d0 00          	cmpb   $0x0,-0x30(%rbp)
 120f773:	40 0f 94 c7          	sete   %dil
 120f777:	4c 39 d8             	cmp    %r11,%rax
 120f77a:	41 0f 97 c0          	seta   %r8b
 120f77e:	41 08 f8             	or     %dil,%r8b
 120f781:	75 26                	jne    120f7a9 <br.encoder.literal_context_split.chooseProposals+0x9a9>
 120f783:	4c 39 d8             	cmp    %r11,%rax
 120f786:	40 0f 94 c7          	sete   %dil
 120f78a:	41 89 f0             	mov    %esi,%r8d
 120f78d:	41 80 e0 7f          	and    $0x7f,%r8b
 120f791:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 120f795:	41 80 e1 7f          	and    $0x7f,%r9b
 120f799:	45 38 c8             	cmp    %r9b,%r8b
 120f79c:	41 0f 92 c0          	setb   %r8b
 120f7a0:	41 20 f8             	and    %dil,%r8b
 120f7a3:	41 80 f8 01          	cmp    $0x1,%r8b
 120f7a7:	75 3b                	jne    120f7e4 <br.encoder.literal_context_split.chooseProposals+0x9e4>
 120f7a9:	4c 8d 85 7a fd ff ff 	lea    -0x286(%rbp),%r8
 120f7b0:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f7b4:	48 89 bd be fe ff ff 	mov    %rdi,-0x142(%rbp)
 120f7bb:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f7c0:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f7c6:	c5 fc 11 8d a0 fe ff 	vmovups %ymm1,-0x160(%rbp)
 120f7cd:	ff 
 120f7ce:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 120f7d5:	ff 
 120f7d6:	41 b6 01             	mov    $0x1,%r14b
 120f7d9:	48 89 75 a8          	mov    %rsi,-0x58(%rbp)
 120f7dd:	48 89 55 90          	mov    %rdx,-0x70(%rbp)
 120f7e1:	49 89 c3             	mov    %rax,%r11
 120f7e4:	84 c9                	test   %cl,%cl
 120f7e6:	4c 89 5d d0          	mov    %r11,-0x30(%rbp)
 120f7ea:	0f 84 8e 00 00 00    	je     120f87e <br.encoder.literal_context_split.chooseProposals+0xa7e>
 120f7f0:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 120f7f7:	0f b6 8d d0 fd ff ff 	movzbl -0x230(%rbp),%ecx
 120f7fe:	0f b6 95 d1 fd ff ff 	movzbl -0x22f(%rbp),%edx
 120f805:	80 bd 30 ff ff ff 00 	cmpb   $0x0,-0xd0(%rbp)
 120f80c:	40 0f 94 c6          	sete   %sil
 120f810:	4c 39 e8             	cmp    %r13,%rax
 120f813:	40 0f 97 c7          	seta   %dil
 120f817:	40 08 f7             	or     %sil,%dil
 120f81a:	75 25                	jne    120f841 <br.encoder.literal_context_split.chooseProposals+0xa41>
 120f81c:	4c 39 e8             	cmp    %r13,%rax
 120f81f:	40 0f 94 c6          	sete   %sil
 120f823:	89 d7                	mov    %edx,%edi
 120f825:	40 80 e7 7f          	and    $0x7f,%dil
 120f829:	4c 8b 45 c0          	mov    -0x40(%rbp),%r8
 120f82d:	41 80 e0 7f          	and    $0x7f,%r8b
 120f831:	44 38 c7             	cmp    %r8b,%dil
 120f834:	40 0f 92 c7          	setb   %dil
 120f838:	40 20 f7             	and    %sil,%dil
 120f83b:	40 80 ff 01          	cmp    $0x1,%dil
 120f83f:	75 3d                	jne    120f87e <br.encoder.literal_context_split.chooseProposals+0xa7e>
 120f841:	48 8d bd d2 fd ff ff 	lea    -0x22e(%rbp),%rdi
 120f848:	48 8b 77 3e          	mov    0x3e(%rdi),%rsi
 120f84c:	48 89 b5 0e ff ff ff 	mov    %rsi,-0xf2(%rbp)
 120f853:	c5 fc 10 07          	vmovups (%rdi),%ymm0
 120f857:	c5 fc 10 4f 20       	vmovups 0x20(%rdi),%ymm1
 120f85c:	c5 fc 11 8d f0 fe ff 	vmovups %ymm1,-0x110(%rbp)
 120f863:	ff 
 120f864:	c5 fc 11 85 d0 fe ff 	vmovups %ymm0,-0x130(%rbp)
 120f86b:	ff 
 120f86c:	41 b7 01             	mov    $0x1,%r15b
 120f86f:	49 89 c5             	mov    %rax,%r13
 120f872:	89 c8                	mov    %ecx,%eax
 120f874:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 120f878:	89 d0                	mov    %edx,%eax
 120f87a:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 120f87e:	4d 8b 02             	mov    (%r10),%r8
 120f881:	48 8d bd 18 fd ff ff 	lea    -0x2e8(%rbp),%rdi
 120f888:	be 02 00 00 00       	mov    $0x2,%esi
 120f88d:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 120f894:	48 8b 8d 40 ff ff ff 	mov    -0xc0(%rbp),%rcx
 120f89b:	4c 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%r9
 120f8a2:	48 8d 85 68 f1 fd ff 	lea    -0x20e98(%rbp),%rax
 120f8a9:	50                   	push   %rax
 120f8aa:	48 8d 85 1e fb ff ff 	lea    -0x4e2(%rbp),%rax
 120f8b1:	50                   	push   %rax
 120f8b2:	c5 f8 77             	vzeroupper 
 120f8b5:	e8 f6 d8 ff ff       	call   120d1b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230>
 120f8ba:	48 83 c4 10          	add    $0x10,%rsp
 120f8be:	0f b7 9d 20 fe ff ff 	movzwl -0x1e0(%rbp),%ebx
 120f8c5:	66 85 db             	test   %bx,%bx
 120f8c8:	0f 85 b2 04 00 00    	jne    120fd80 <br.encoder.literal_context_split.chooseProposals+0xf80>
 120f8ce:	0f b6 85 c0 fd ff ff 	movzbl -0x240(%rbp),%eax
 120f8d5:	80 bd 68 fd ff ff 00 	cmpb   $0x0,-0x298(%rbp)
 120f8dc:	0f 84 96 00 00 00    	je     120f978 <br.encoder.literal_context_split.chooseProposals+0xb78>
 120f8e2:	48 8b 8d 18 fd ff ff 	mov    -0x2e8(%rbp),%rcx
 120f8e9:	0f b6 95 20 fd ff ff 	movzbl -0x2e0(%rbp),%edx
 120f8f0:	0f b6 b5 21 fd ff ff 	movzbl -0x2df(%rbp),%esi
 120f8f7:	80 7d b8 00          	cmpb   $0x0,-0x48(%rbp)
 120f8fb:	40 0f 94 c7          	sete   %dil
 120f8ff:	4c 39 e1             	cmp    %r12,%rcx
 120f902:	41 0f 97 c0          	seta   %r8b
 120f906:	41 08 f8             	or     %dil,%r8b
 120f909:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 120f90d:	4c 8b 55 d0          	mov    -0x30(%rbp),%r10
 120f911:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 120f915:	75 20                	jne    120f937 <br.encoder.literal_context_split.chooseProposals+0xb37>
 120f917:	40 b7 01             	mov    $0x1,%dil
 120f91a:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 120f91e:	4c 39 e1             	cmp    %r12,%rcx
 120f921:	75 61                	jne    120f984 <br.encoder.literal_context_split.chooseProposals+0xb84>
 120f923:	48 8b 7d c8          	mov    -0x38(%rbp),%rdi
 120f927:	40 80 e7 7f          	and    $0x7f,%dil
 120f92b:	41 89 f0             	mov    %esi,%r8d
 120f92e:	41 80 e0 7f          	and    $0x7f,%r8b
 120f932:	41 38 f8             	cmp    %dil,%r8b
 120f935:	73 4d                	jae    120f984 <br.encoder.literal_context_split.chooseProposals+0xb84>
 120f937:	4c 8d 85 22 fd ff ff 	lea    -0x2de(%rbp),%r8
 120f93e:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f942:	48 89 bd 6e fe ff ff 	mov    %rdi,-0x192(%rbp)
 120f949:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f94e:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f954:	c5 fc 11 8d 50 fe ff 	vmovups %ymm1,-0x1b0(%rbp)
 120f95b:	ff 
 120f95c:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 120f963:	ff 
 120f964:	40 b7 01             	mov    $0x1,%dil
 120f967:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 120f96b:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 120f96f:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 120f973:	49 89 cc             	mov    %rcx,%r12
 120f976:	eb 0c                	jmp    120f984 <br.encoder.literal_context_split.chooseProposals+0xb84>
 120f978:	4c 8b 4d b0          	mov    -0x50(%rbp),%r9
 120f97c:	4c 8b 55 d0          	mov    -0x30(%rbp),%r10
 120f980:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 120f984:	0f b6 8d 18 fe ff ff 	movzbl -0x1e8(%rbp),%ecx
 120f98b:	84 c0                	test   %al,%al
 120f98d:	74 73                	je     120fa02 <br.encoder.literal_context_split.chooseProposals+0xc02>
 120f98f:	48 8b 85 70 fd ff ff 	mov    -0x290(%rbp),%rax
 120f996:	0f b6 95 78 fd ff ff 	movzbl -0x288(%rbp),%edx
 120f99d:	0f b6 b5 79 fd ff ff 	movzbl -0x287(%rbp),%esi
 120f9a4:	45 84 f6             	test   %r14b,%r14b
 120f9a7:	74 1e                	je     120f9c7 <br.encoder.literal_context_split.chooseProposals+0xbc7>
 120f9a9:	4c 39 d0             	cmp    %r10,%rax
 120f9ac:	77 19                	ja     120f9c7 <br.encoder.literal_context_split.chooseProposals+0xbc7>
 120f9ae:	41 b6 01             	mov    $0x1,%r14b
 120f9b1:	75 4f                	jne    120fa02 <br.encoder.literal_context_split.chooseProposals+0xc02>
 120f9b3:	48 8b 7d a8          	mov    -0x58(%rbp),%rdi
 120f9b7:	40 80 e7 7f          	and    $0x7f,%dil
 120f9bb:	41 89 f0             	mov    %esi,%r8d
 120f9be:	41 80 e0 7f          	and    $0x7f,%r8b
 120f9c2:	41 38 f8             	cmp    %dil,%r8b
 120f9c5:	73 3b                	jae    120fa02 <br.encoder.literal_context_split.chooseProposals+0xc02>
 120f9c7:	4c 8d 85 7a fd ff ff 	lea    -0x286(%rbp),%r8
 120f9ce:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f9d2:	48 89 bd be fe ff ff 	mov    %rdi,-0x142(%rbp)
 120f9d9:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f9de:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f9e4:	c5 fc 11 8d a0 fe ff 	vmovups %ymm1,-0x160(%rbp)
 120f9eb:	ff 
 120f9ec:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 120f9f3:	ff 
 120f9f4:	41 b6 01             	mov    $0x1,%r14b
 120f9f7:	48 89 75 a8          	mov    %rsi,-0x58(%rbp)
 120f9fb:	48 89 55 90          	mov    %rdx,-0x70(%rbp)
 120f9ff:	49 89 c2             	mov    %rax,%r10
 120fa02:	84 c9                	test   %cl,%cl
 120fa04:	74 70                	je     120fa76 <br.encoder.literal_context_split.chooseProposals+0xc76>
 120fa06:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 120fa0d:	0f b6 8d d0 fd ff ff 	movzbl -0x230(%rbp),%ecx
 120fa14:	0f b6 95 d1 fd ff ff 	movzbl -0x22f(%rbp),%edx
 120fa1b:	45 84 ff             	test   %r15b,%r15b
 120fa1e:	74 1c                	je     120fa3c <br.encoder.literal_context_split.chooseProposals+0xc3c>
 120fa20:	4c 39 e8             	cmp    %r13,%rax
 120fa23:	77 17                	ja     120fa3c <br.encoder.literal_context_split.chooseProposals+0xc3c>
 120fa25:	41 b7 01             	mov    $0x1,%r15b
 120fa28:	75 4c                	jne    120fa76 <br.encoder.literal_context_split.chooseProposals+0xc76>
 120fa2a:	44 89 de             	mov    %r11d,%esi
 120fa2d:	40 80 e6 7f          	and    $0x7f,%sil
 120fa31:	89 d7                	mov    %edx,%edi
 120fa33:	40 80 e7 7f          	and    $0x7f,%dil
 120fa37:	40 38 f7             	cmp    %sil,%dil
 120fa3a:	73 3a                	jae    120fa76 <br.encoder.literal_context_split.chooseProposals+0xc76>
 120fa3c:	48 8d bd d2 fd ff ff 	lea    -0x22e(%rbp),%rdi
 120fa43:	48 8b 77 3e          	mov    0x3e(%rdi),%rsi
 120fa47:	48 89 b5 0e ff ff ff 	mov    %rsi,-0xf2(%rbp)
 120fa4e:	c5 fc 10 07          	vmovups (%rdi),%ymm0
 120fa52:	c5 fc 10 4f 20       	vmovups 0x20(%rdi),%ymm1
 120fa57:	c5 fc 11 8d f0 fe ff 	vmovups %ymm1,-0x110(%rbp)
 120fa5e:	ff 
 120fa5f:	c5 fc 11 85 d0 fe ff 	vmovups %ymm0,-0x130(%rbp)
 120fa66:	ff 
 120fa67:	41 b7 01             	mov    $0x1,%r15b
 120fa6a:	49 89 c5             	mov    %rax,%r13
 120fa6d:	89 c8                	mov    %ecx,%eax
 120fa6f:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 120fa73:	41 89 d3             	mov    %edx,%r11d
 120fa76:	4c 89 5d c0          	mov    %r11,-0x40(%rbp)
 120fa7a:	4c 89 55 d0          	mov    %r10,-0x30(%rbp)
 120fa7e:	4d 8b 01             	mov    (%r9),%r8
 120fa81:	48 8d bd 18 fd ff ff 	lea    -0x2e8(%rbp),%rdi
 120fa88:	be 03 00 00 00       	mov    $0x3,%esi
 120fa8d:	48 8b 95 28 ff ff ff 	mov    -0xd8(%rbp),%rdx
 120fa94:	48 8b 8d 40 ff ff ff 	mov    -0xc0(%rbp),%rcx
 120fa9b:	4c 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%r9
 120faa2:	48 8d 85 68 f1 fd ff 	lea    -0x20e98(%rbp),%rax
 120faa9:	50                   	push   %rax
 120faaa:	48 8d 85 1e fb ff ff 	lea    -0x4e2(%rbp),%rax
 120fab1:	50                   	push   %rax
 120fab2:	c5 f8 77             	vzeroupper 
 120fab5:	e8 f6 d6 ff ff       	call   120d1b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230>
 120faba:	48 83 c4 10          	add    $0x10,%rsp
 120fabe:	0f b7 9d 20 fe ff ff 	movzwl -0x1e0(%rbp),%ebx
 120fac5:	66 85 db             	test   %bx,%bx
 120fac8:	0f 85 b2 02 00 00    	jne    120fd80 <br.encoder.literal_context_split.chooseProposals+0xf80>
 120face:	0f b6 85 c0 fd ff ff 	movzbl -0x240(%rbp),%eax
 120fad5:	80 bd 68 fd ff ff 00 	cmpb   $0x0,-0x298(%rbp)
 120fadc:	0f 84 8e 00 00 00    	je     120fb70 <br.encoder.literal_context_split.chooseProposals+0xd70>
 120fae2:	48 8b 8d 18 fd ff ff 	mov    -0x2e8(%rbp),%rcx
 120fae9:	0f b6 95 20 fd ff ff 	movzbl -0x2e0(%rbp),%edx
 120faf0:	44 0f b6 8d 21 fd ff 	movzbl -0x2df(%rbp),%r9d
 120faf7:	ff 
 120faf8:	80 7d b8 00          	cmpb   $0x0,-0x48(%rbp)
 120fafc:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 120fb00:	4c 8b 55 d0          	mov    -0x30(%rbp),%r10
 120fb04:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 120fb08:	74 22                	je     120fb2c <br.encoder.literal_context_split.chooseProposals+0xd2c>
 120fb0a:	4c 39 e1             	cmp    %r12,%rcx
 120fb0d:	77 1d                	ja     120fb2c <br.encoder.literal_context_split.chooseProposals+0xd2c>
 120fb0f:	40 b7 01             	mov    $0x1,%dil
 120fb12:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 120fb16:	75 64                	jne    120fb7c <br.encoder.literal_context_split.chooseProposals+0xd7c>
 120fb18:	48 8b 7d c8          	mov    -0x38(%rbp),%rdi
 120fb1c:	40 80 e7 7f          	and    $0x7f,%dil
 120fb20:	45 89 c8             	mov    %r9d,%r8d
 120fb23:	41 80 e0 7f          	and    $0x7f,%r8b
 120fb27:	41 38 f8             	cmp    %dil,%r8b
 120fb2a:	73 50                	jae    120fb7c <br.encoder.literal_context_split.chooseProposals+0xd7c>
 120fb2c:	4c 8d 85 22 fd ff ff 	lea    -0x2de(%rbp),%r8
 120fb33:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120fb37:	48 89 bd 6e fe ff ff 	mov    %rdi,-0x192(%rbp)
 120fb3e:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120fb43:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120fb49:	c5 fc 11 8d 50 fe ff 	vmovups %ymm1,-0x1b0(%rbp)
 120fb50:	ff 
 120fb51:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 120fb58:	ff 
 120fb59:	40 b7 01             	mov    $0x1,%dil
 120fb5c:	48 89 7d b8          	mov    %rdi,-0x48(%rbp)
 120fb60:	44 89 cf             	mov    %r9d,%edi
 120fb63:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 120fb67:	48 89 55 98          	mov    %rdx,-0x68(%rbp)
 120fb6b:	49 89 cc             	mov    %rcx,%r12
 120fb6e:	eb 0c                	jmp    120fb7c <br.encoder.literal_context_split.chooseProposals+0xd7c>
 120fb70:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 120fb74:	4c 8b 55 d0          	mov    -0x30(%rbp),%r10
 120fb78:	4c 8b 5d c0          	mov    -0x40(%rbp),%r11
 120fb7c:	0f b6 8d 18 fe ff ff 	movzbl -0x1e8(%rbp),%ecx
 120fb83:	84 c0                	test   %al,%al
 120fb85:	74 77                	je     120fbfe <br.encoder.literal_context_split.chooseProposals+0xdfe>
 120fb87:	48 8b 85 70 fd ff ff 	mov    -0x290(%rbp),%rax
 120fb8e:	0f b6 95 78 fd ff ff 	movzbl -0x288(%rbp),%edx
 120fb95:	44 0f b6 8d 79 fd ff 	movzbl -0x287(%rbp),%r9d
 120fb9c:	ff 
 120fb9d:	45 84 f6             	test   %r14b,%r14b
 120fba0:	74 1e                	je     120fbc0 <br.encoder.literal_context_split.chooseProposals+0xdc0>
 120fba2:	4c 39 d0             	cmp    %r10,%rax
 120fba5:	77 19                	ja     120fbc0 <br.encoder.literal_context_split.chooseProposals+0xdc0>
 120fba7:	41 b6 01             	mov    $0x1,%r14b
 120fbaa:	75 52                	jne    120fbfe <br.encoder.literal_context_split.chooseProposals+0xdfe>
 120fbac:	48 8b 7d a8          	mov    -0x58(%rbp),%rdi
 120fbb0:	40 80 e7 7f          	and    $0x7f,%dil
 120fbb4:	45 89 c8             	mov    %r9d,%r8d
 120fbb7:	41 80 e0 7f          	and    $0x7f,%r8b
 120fbbb:	41 38 f8             	cmp    %dil,%r8b
 120fbbe:	73 3e                	jae    120fbfe <br.encoder.literal_context_split.chooseProposals+0xdfe>
 120fbc0:	4c 8d 85 7a fd ff ff 	lea    -0x286(%rbp),%r8
 120fbc7:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120fbcb:	48 89 bd be fe ff ff 	mov    %rdi,-0x142(%rbp)
 120fbd2:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120fbd7:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120fbdd:	c5 fc 11 8d a0 fe ff 	vmovups %ymm1,-0x160(%rbp)
 120fbe4:	ff 
 120fbe5:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 120fbec:	ff 
 120fbed:	41 b6 01             	mov    $0x1,%r14b
 120fbf0:	44 89 cf             	mov    %r9d,%edi
 120fbf3:	48 89 7d a8          	mov    %rdi,-0x58(%rbp)
 120fbf7:	48 89 55 90          	mov    %rdx,-0x70(%rbp)
 120fbfb:	49 89 c2             	mov    %rax,%r10
 120fbfe:	84 c9                	test   %cl,%cl
 120fc00:	4c 89 55 d0          	mov    %r10,-0x30(%rbp)
 120fc04:	74 72                	je     120fc78 <br.encoder.literal_context_split.chooseProposals+0xe78>
 120fc06:	48 8b 85 c8 fd ff ff 	mov    -0x238(%rbp),%rax
 120fc0d:	0f b6 8d d0 fd ff ff 	movzbl -0x230(%rbp),%ecx
 120fc14:	0f b6 95 d1 fd ff ff 	movzbl -0x22f(%rbp),%edx
 120fc1b:	45 84 ff             	test   %r15b,%r15b
 120fc1e:	74 1c                	je     120fc3c <br.encoder.literal_context_split.chooseProposals+0xe3c>
 120fc20:	4c 39 e8             	cmp    %r13,%rax
 120fc23:	77 17                	ja     120fc3c <br.encoder.literal_context_split.chooseProposals+0xe3c>
 120fc25:	41 b7 01             	mov    $0x1,%r15b
 120fc28:	75 4e                	jne    120fc78 <br.encoder.literal_context_split.chooseProposals+0xe78>
 120fc2a:	45 89 d8             	mov    %r11d,%r8d
 120fc2d:	41 80 e0 7f          	and    $0x7f,%r8b
 120fc31:	89 d7                	mov    %edx,%edi
 120fc33:	40 80 e7 7f          	and    $0x7f,%dil
 120fc37:	44 38 c7             	cmp    %r8b,%dil
 120fc3a:	73 3c                	jae    120fc78 <br.encoder.literal_context_split.chooseProposals+0xe78>
 120fc3c:	4c 8d 85 d2 fd ff ff 	lea    -0x22e(%rbp),%r8
 120fc43:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120fc47:	48 89 bd 0e ff ff ff 	mov    %rdi,-0xf2(%rbp)
 120fc4e:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120fc53:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120fc59:	c5 fc 11 8d f0 fe ff 	vmovups %ymm1,-0x110(%rbp)
 120fc60:	ff 
 120fc61:	c5 fc 11 85 d0 fe ff 	vmovups %ymm0,-0x130(%rbp)
 120fc68:	ff 
 120fc69:	41 b7 01             	mov    $0x1,%r15b
 120fc6c:	49 89 c5             	mov    %rax,%r13
 120fc6f:	89 c8                	mov    %ecx,%eax
 120fc71:	48 89 45 a0          	mov    %rax,-0x60(%rbp)
 120fc75:	41 89 d3             	mov    %edx,%r11d
 120fc78:	ba 08 04 04 00       	mov    $0x40408,%edx
 120fc7d:	48 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%rdi
 120fc84:	b9 03 00 00 00       	mov    $0x3,%ecx
 120fc89:	4c 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%r8
 120fc90:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 120fc97:	4c 89 db             	mov    %r11,%rbx
 120fc9a:	c5 f8 77             	vzeroupper 
 120fc9d:	ff 50 18             	call   *0x18(%rax)
 120fca0:	49 89 db             	mov    %rbx,%r11
 120fca3:	48 8b 85 6e fe ff ff 	mov    -0x192(%rbp),%rax
 120fcaa:	48 89 85 5e fc ff ff 	mov    %rax,-0x3a2(%rbp)
 120fcb1:	c5 fc 10 85 30 fe ff 	vmovups -0x1d0(%rbp),%ymm0
 120fcb8:	ff 
 120fcb9:	c5 fc 10 8d 50 fe ff 	vmovups -0x1b0(%rbp),%ymm1
 120fcc0:	ff 
 120fcc1:	c5 fc 11 8d 40 fc ff 	vmovups %ymm1,-0x3c0(%rbp)
 120fcc8:	ff 
 120fcc9:	c5 fc 11 85 20 fc ff 	vmovups %ymm0,-0x3e0(%rbp)
 120fcd0:	ff 
 120fcd1:	c7 85 78 ff ff ff 00 	movl   $0x0,-0x88(%rbp)
 120fcd8:	00 00 00 
 120fcdb:	c7 85 7b ff ff ff 00 	movl   $0x0,-0x85(%rbp)
 120fce2:	00 00 00 
 120fce5:	c5 fc 10 85 80 fe ff 	vmovups -0x180(%rbp),%ymm0
 120fcec:	ff 
 120fced:	c5 fc 11 85 70 fc ff 	vmovups %ymm0,-0x390(%rbp)
 120fcf4:	ff 
 120fcf5:	c5 fc 10 85 a0 fe ff 	vmovups -0x160(%rbp),%ymm0
 120fcfc:	ff 
 120fcfd:	c5 fc 11 85 90 fc ff 	vmovups %ymm0,-0x370(%rbp)
 120fd04:	ff 
 120fd05:	48 8b 85 be fe ff ff 	mov    -0x142(%rbp),%rax
 120fd0c:	48 89 85 ae fc ff ff 	mov    %rax,-0x352(%rbp)
 120fd13:	c7 45 80 00 00 00 00 	movl   $0x0,-0x80(%rbp)
 120fd1a:	c7 45 83 00 00 00 00 	movl   $0x0,-0x7d(%rbp)
 120fd21:	48 8b 85 0e ff ff ff 	mov    -0xf2(%rbp),%rax
 120fd28:	48 89 85 fe fc ff ff 	mov    %rax,-0x302(%rbp)
 120fd2f:	c5 fc 10 85 f0 fe ff 	vmovups -0x110(%rbp),%ymm0
 120fd36:	ff 
 120fd37:	c5 fc 11 85 e0 fc ff 	vmovups %ymm0,-0x320(%rbp)
 120fd3e:	ff 
 120fd3f:	c5 fc 10 85 d0 fe ff 	vmovups -0x130(%rbp),%ymm0
 120fd46:	ff 
 120fd47:	c5 fc 11 85 c0 fc ff 	vmovups %ymm0,-0x340(%rbp)
 120fd4e:	ff 
 120fd4f:	c7 45 8b 00 00 00 00 	movl   $0x0,-0x75(%rbp)
 120fd56:	c7 45 88 00 00 00 00 	movl   $0x0,-0x78(%rbp)
 120fd5d:	31 db                	xor    %ebx,%ebx
 120fd5f:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 120fd63:	48 8b 55 98          	mov    -0x68(%rbp),%rdx
 120fd67:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 120fd6b:	48 8b 7d d0          	mov    -0x30(%rbp),%rdi
 120fd6f:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 120fd73:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 120fd77:	4c 8b 55 a0          	mov    -0x60(%rbp),%r10
 120fd7b:	e9 d2 f4 ff ff       	jmp    120f252 <br.encoder.literal_context_split.chooseProposals+0x452>
 120fd80:	ba 08 04 04 00       	mov    $0x40408,%edx
 120fd85:	48 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%rdi
 120fd8c:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 120fd90:	eb 0f                	jmp    120fda1 <br.encoder.literal_context_split.chooseProposals+0xfa1>
 120fd92:	ba 08 04 04 00       	mov    $0x40408,%edx
 120fd97:	48 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%rdi
 120fd9e:	4c 89 e6             	mov    %r12,%rsi
 120fda1:	b9 03 00 00 00       	mov    $0x3,%ecx
 120fda6:	4c 8b 85 58 ff ff ff 	mov    -0xa8(%rbp),%r8
 120fdad:	48 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%rax
 120fdb4:	ff 50 18             	call   *0x18(%rax)
 120fdb7:	e9 a4 f3 ff ff       	jmp    120f160 <br.encoder.literal_context_split.chooseProposals+0x360>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
