
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/d54ab236499589e8c9225c90450b9b10/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120ee50 <br.encoder.literal_context_split.chooseProposals>:
 120ee50:	55                   	push   %rbp
 120ee51:	48 89 e5             	mov    %rsp,%rbp
 120ee54:	41 57                	push   %r15
 120ee56:	41 56                	push   %r14
 120ee58:	41 55                	push   %r13
 120ee5a:	41 54                	push   %r12
 120ee5c:	53                   	push   %rbx
 120ee5d:	48 81 ec d8 03 00 00 	sub    $0x3d8,%rsp
 120ee64:	4d 89 ce             	mov    %r9,%r14
 120ee67:	4c 89 45 80          	mov    %r8,-0x80(%rbp)
 120ee6b:	48 89 4d 88          	mov    %rcx,-0x78(%rbp)
 120ee6f:	48 89 95 60 ff ff ff 	mov    %rdx,-0xa0(%rbp)
 120ee76:	48 89 fb             	mov    %rdi,%rbx
 120ee79:	48 8b 3e             	mov    (%rsi),%rdi
 120ee7c:	48 8b 46 08          	mov    0x8(%rsi),%rax
 120ee80:	48 8b 4d 08          	mov    0x8(%rbp),%rcx
 120ee84:	be 08 04 04 00       	mov    $0x40408,%esi
 120ee89:	48 89 bd 58 ff ff ff 	mov    %rdi,-0xa8(%rbp)
 120ee90:	ba 03 00 00 00       	mov    $0x3,%edx
 120ee95:	48 89 8d 50 ff ff ff 	mov    %rcx,-0xb0(%rbp)
 120ee9c:	48 89 85 48 ff ff ff 	mov    %rax,-0xb8(%rbp)
 120eea3:	ff 10                	call   *(%rax)
 120eea5:	48 85 c0             	test   %rax,%rax
 120eea8:	0f 84 fe 02 00 00    	je     120f1ac <br.encoder.literal_context_split.chooseProposals+0x35c>
 120eeae:	49 89 c7             	mov    %rax,%r15
 120eeb1:	ba 08 04 04 00       	mov    $0x40408,%edx
 120eeb6:	48 89 c7             	mov    %rax,%rdi
 120eeb9:	31 f6                	xor    %esi,%esi
 120eebb:	e8 e0 6d 08 00       	call   1295ca0 <compiler_rt.memset>
 120eec0:	4d 85 f6             	test   %r14,%r14
 120eec3:	0f 84 f8 02 00 00    	je     120f1c1 <br.encoder.literal_context_split.chooseProposals+0x371>
 120eec9:	4d 8d a7 08 00 04 00 	lea    0x40008(%r15),%r12
 120eed0:	49 8d 47 08          	lea    0x8(%r15),%rax
 120eed4:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 120eedb:	49 8d 87 08 00 01 00 	lea    0x10008(%r15),%rax
 120eee2:	48 89 85 30 ff ff ff 	mov    %rax,-0xd0(%rbp)
 120eee9:	49 8d 87 08 00 02 00 	lea    0x20008(%r15),%rax
 120eef0:	48 89 85 38 ff ff ff 	mov    %rax,-0xc8(%rbp)
 120eef7:	4c 89 f8             	mov    %r15,%rax
 120eefa:	48 05 08 00 03 00    	add    $0x30008,%rax
 120ef00:	48 89 85 40 ff ff ff 	mov    %rax,-0xc0(%rbp)
 120ef07:	48 c7 45 b8 00 00 00 	movq   $0x0,-0x48(%rbp)
 120ef0e:	00 
 120ef0f:	31 c0                	xor    %eax,%eax
 120ef11:	48 89 9d 68 ff ff ff 	mov    %rbx,-0x98(%rbp)
 120ef18:	4c 89 7d a8          	mov    %r15,-0x58(%rbp)
 120ef1c:	4c 89 a5 38 fe ff ff 	mov    %r12,-0x1c8(%rbp)
 120ef23:	4c 89 b5 78 ff ff ff 	mov    %r14,-0x88(%rbp)
 120ef2a:	eb 26                	jmp    120ef52 <br.encoder.literal_context_split.chooseProposals+0x102>
 120ef2c:	0f 1f 40 00          	nopl   0x0(%rax)
 120ef30:	4c 01 75 b8          	add    %r14,-0x48(%rbp)
 120ef34:	48 8b 9d 68 ff ff ff 	mov    -0x98(%rbp),%rbx
 120ef3b:	4c 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%r14
 120ef42:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 120ef46:	48 ff c0             	inc    %rax
 120ef49:	4c 39 f0             	cmp    %r14,%rax
 120ef4c:	0f 84 65 02 00 00    	je     120f1b7 <br.encoder.literal_context_split.chooseProposals+0x367>
 120ef52:	48 89 45 98          	mov    %rax,-0x68(%rbp)
 120ef56:	48 8d 04 40          	lea    (%rax,%rax,2),%rax
 120ef5a:	48 c1 e0 05          	shl    $0x5,%rax
 120ef5e:	48 8b 4d 80          	mov    -0x80(%rbp),%rcx
 120ef62:	48 8b 14 01          	mov    (%rcx,%rax,1),%rdx
 120ef66:	48 8b 74 01 08       	mov    0x8(%rcx,%rax,1),%rsi
 120ef6b:	48 89 d0             	mov    %rdx,%rax
 120ef6e:	48 01 f0             	add    %rsi,%rax
 120ef71:	0f 92 85 18 fd ff ff 	setb   -0x2e8(%rbp)
 120ef78:	0f 82 43 02 00 00    	jb     120f1c1 <br.encoder.literal_context_split.chooseProposals+0x371>
 120ef7e:	48 3b 45 88          	cmp    -0x78(%rbp),%rax
 120ef82:	0f 87 39 02 00 00    	ja     120f1c1 <br.encoder.literal_context_split.chooseProposals+0x371>
 120ef88:	48 39 d0             	cmp    %rdx,%rax
 120ef8b:	74 b5                	je     120ef42 <br.encoder.literal_context_split.chooseProposals+0xf2>
 120ef8d:	48 89 f1             	mov    %rsi,%rcx
 120ef90:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 120ef97:	48 8d 34 10          	lea    (%rax,%rdx,1),%rsi
 120ef9b:	48 83 f9 01          	cmp    $0x1,%rcx
 120ef9f:	48 83 d1 00          	adc    $0x0,%rcx
 120efa3:	48 89 4d a0          	mov    %rcx,-0x60(%rbp)
 120efa7:	b8 01 00 00 00       	mov    $0x1,%eax
 120efac:	48 29 d0             	sub    %rdx,%rax
 120efaf:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 120efb3:	48 f7 da             	neg    %rdx
 120efb6:	45 31 f6             	xor    %r14d,%r14d
 120efb9:	48 89 55 c0          	mov    %rdx,-0x40(%rbp)
 120efbd:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 120efc1:	eb 4a                	jmp    120f00d <br.encoder.literal_context_split.chooseProposals+0x1bd>
 120efc3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120efca:	84 00 00 00 00 00 
 120efd0:	41 bd 07 00 00 00    	mov    $0x7,%r13d
 120efd6:	49 c1 e5 0a          	shl    $0xa,%r13
 120efda:	4c 03 ad 40 ff ff ff 	add    -0xc0(%rbp),%r13
 120efe1:	41 c1 e4 0a          	shl    $0xa,%r12d
 120efe5:	4d 01 ec             	add    %r13,%r12
 120efe8:	41 ff 04 8c          	incl   (%r12,%rcx,4)
 120efec:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 120eff0:	4c 01 f0             	add    %r14,%rax
 120eff3:	48 ff c0             	inc    %rax
 120eff6:	49 89 07             	mov    %rax,(%r15)
 120eff9:	49 ff c6             	inc    %r14
 120effc:	4c 39 75 a0          	cmp    %r14,-0x60(%rbp)
 120f000:	4c 8b a5 38 fe ff ff 	mov    -0x1c8(%rbp),%r12
 120f007:	0f 84 23 ff ff ff    	je     120ef30 <br.encoder.literal_context_split.chooseProposals+0xe0>
 120f00d:	4c 39 f2             	cmp    %r14,%rdx
 120f010:	75 0e                	jne    120f020 <br.encoder.literal_context_split.chooseProposals+0x1d0>
 120f012:	31 db                	xor    %ebx,%ebx
 120f014:	eb 16                	jmp    120f02c <br.encoder.literal_context_split.chooseProposals+0x1dc>
 120f016:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120f01d:	00 00 00 
 120f020:	42 0f b6 5c 36 ff    	movzbl -0x1(%rsi,%r14,1),%ebx
 120f026:	4c 39 75 90          	cmp    %r14,-0x70(%rbp)
 120f02a:	75 04                	jne    120f030 <br.encoder.literal_context_split.chooseProposals+0x1e0>
 120f02c:	31 c9                	xor    %ecx,%ecx
 120f02e:	eb 06                	jmp    120f036 <br.encoder.literal_context_split.chooseProposals+0x1e6>
 120f030:	42 0f b6 4c 36 fe    	movzbl -0x2(%rsi,%r14,1),%ecx
 120f036:	42 0f b6 04 36       	movzbl (%rsi,%r14,1),%eax
 120f03b:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 120f03f:	44 8d 3c 85 00 00 00 	lea    0x0(,%rax,4),%r15d
 120f046:	00 
 120f047:	43 ff 04 3c          	incl   (%r12,%r15,1)
 120f04b:	89 d8                	mov    %ebx,%eax
 120f04d:	24 3f                	and    $0x3f,%al
 120f04f:	0f b6 c0             	movzbl %al,%eax
 120f052:	c1 e0 0a             	shl    $0xa,%eax
 120f055:	48 03 85 70 ff ff ff 	add    -0x90(%rbp),%rax
 120f05c:	41 ff 04 07          	incl   (%r15,%rax,1)
 120f060:	89 d8                	mov    %ebx,%eax
 120f062:	c0 e8 02             	shr    $0x2,%al
 120f065:	0f b6 c0             	movzbl %al,%eax
 120f068:	c1 e0 0a             	shl    $0xa,%eax
 120f06b:	48 03 85 30 ff ff ff 	add    -0xd0(%rbp),%rax
 120f072:	41 ff 04 07          	incl   (%r15,%rax,1)
 120f076:	44 0f b6 e3          	movzbl %bl,%r12d
 120f07a:	48 89 4d b0          	mov    %rcx,-0x50(%rbp)
 120f07e:	44 0f b6 e9          	movzbl %cl,%r13d
 120f082:	bf 02 00 00 00       	mov    $0x2,%edi
 120f087:	44 89 e6             	mov    %r12d,%esi
 120f08a:	44 89 ea             	mov    %r13d,%edx
 120f08d:	e8 1e f3 fa ff       	call   11be3b0 <br.encoder.literal_context.value>
 120f092:	c1 e0 0a             	shl    $0xa,%eax
 120f095:	48 03 85 38 ff ff ff 	add    -0xc8(%rbp),%rax
 120f09c:	41 ff 04 07          	incl   (%r15,%rax,1)
 120f0a0:	45 84 e4             	test   %r12b,%r12b
 120f0a3:	74 13                	je     120f0b8 <br.encoder.literal_context_split.chooseProposals+0x268>
 120f0a5:	41 81 fc ff 00 00 00 	cmp    $0xff,%r12d
 120f0ac:	0f 85 8e 00 00 00    	jne    120f140 <br.encoder.literal_context_split.chooseProposals+0x2f0>
 120f0b2:	41 bc 38 00 00 00    	mov    $0x38,%r12d
 120f0b8:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 120f0bc:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 120f0c0:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 120f0c4:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 120f0c8:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 120f0cc:	40 84 ff             	test   %dil,%dil
 120f0cf:	0f 84 01 ff ff ff    	je     120efd6 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f0d5:	41 81 fd ff 00 00 00 	cmp    $0xff,%r13d
 120f0dc:	0f 84 ee fe ff ff    	je     120efd0 <br.encoder.literal_context_split.chooseProposals+0x180>
 120f0e2:	8d 47 ff             	lea    -0x1(%rdi),%eax
 120f0e5:	41 bd 01 00 00 00    	mov    $0x1,%r13d
 120f0eb:	3c 0f                	cmp    $0xf,%al
 120f0ed:	0f 82 e3 fe ff ff    	jb     120efd6 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f0f3:	8d 47 f0             	lea    -0x10(%rdi),%eax
 120f0f6:	41 bd 02 00 00 00    	mov    $0x2,%r13d
 120f0fc:	3c 30                	cmp    $0x30,%al
 120f0fe:	0f 82 d2 fe ff ff    	jb     120efd6 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f104:	41 bd 03 00 00 00    	mov    $0x3,%r13d
 120f10a:	40 80 ff 3f          	cmp    $0x3f,%dil
 120f10e:	0f 8f c2 fe ff ff    	jg     120efd6 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f114:	41 bd 04 00 00 00    	mov    $0x4,%r13d
 120f11a:	40 80 ff c0          	cmp    $0xc0,%dil
 120f11e:	0f 82 b2 fe ff ff    	jb     120efd6 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f124:	40 80 c7 40          	add    $0x40,%dil
 120f128:	40 80 ff 30          	cmp    $0x30,%dil
 120f12c:	41 bd 06 00 00 00    	mov    $0x6,%r13d
 120f132:	49 83 dd 00          	sbb    $0x0,%r13
 120f136:	e9 9b fe ff ff       	jmp    120efd6 <br.encoder.literal_context_split.chooseProposals+0x186>
 120f13b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120f140:	8d 43 ff             	lea    -0x1(%rbx),%eax
 120f143:	41 bc 08 00 00 00    	mov    $0x8,%r12d
 120f149:	3c 0f                	cmp    $0xf,%al
 120f14b:	4c 8b 7d a8          	mov    -0x58(%rbp),%r15
 120f14f:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 120f153:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 120f157:	48 8b 4d d0          	mov    -0x30(%rbp),%rcx
 120f15b:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 120f15f:	0f 82 67 ff ff ff    	jb     120f0cc <br.encoder.literal_context_split.chooseProposals+0x27c>
 120f165:	8d 43 f0             	lea    -0x10(%rbx),%eax
 120f168:	41 bc 10 00 00 00    	mov    $0x10,%r12d
 120f16e:	3c 30                	cmp    $0x30,%al
 120f170:	0f 82 56 ff ff ff    	jb     120f0cc <br.encoder.literal_context_split.chooseProposals+0x27c>
 120f176:	41 bc 18 00 00 00    	mov    $0x18,%r12d
 120f17c:	80 fb 3f             	cmp    $0x3f,%bl
 120f17f:	0f 8f 47 ff ff ff    	jg     120f0cc <br.encoder.literal_context_split.chooseProposals+0x27c>
 120f185:	41 bc 20 00 00 00    	mov    $0x20,%r12d
 120f18b:	80 fb c0             	cmp    $0xc0,%bl
 120f18e:	0f 82 38 ff ff ff    	jb     120f0cc <br.encoder.literal_context_split.chooseProposals+0x27c>
 120f194:	80 c3 40             	add    $0x40,%bl
 120f197:	31 c0                	xor    %eax,%eax
 120f199:	80 fb 30             	cmp    $0x30,%bl
 120f19c:	0f 93 c0             	setae  %al
 120f19f:	4c 8d 24 c5 28 00 00 	lea    0x28(,%rax,8),%r12
 120f1a6:	00 
 120f1a7:	e9 20 ff ff ff       	jmp    120f0cc <br.encoder.literal_context_split.chooseProposals+0x27c>
 120f1ac:	66 c7 83 08 01 00 00 	movw   $0x1a,0x108(%rbx)
 120f1b3:	1a 00 
 120f1b5:	eb 6e                	jmp    120f225 <br.encoder.literal_context_split.chooseProposals+0x3d5>
 120f1b7:	48 81 7d b8 80 00 00 	cmpq   $0x80,-0x48(%rbp)
 120f1be:	00 
 120f1bf:	73 79                	jae    120f23a <br.encoder.literal_context_split.chooseProposals+0x3ea>
 120f1c1:	ba 08 04 04 00       	mov    $0x40408,%edx
 120f1c6:	48 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%rdi
 120f1cd:	4c 89 fe             	mov    %r15,%rsi
 120f1d0:	b9 03 00 00 00       	mov    $0x3,%ecx
 120f1d5:	4c 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%r8
 120f1dc:	48 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%rax
 120f1e3:	ff 50 18             	call   *0x18(%rax)
 120f1e6:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 120f1ea:	c5 fc 11 83 f0 00 00 	vmovups %ymm0,0xf0(%rbx)
 120f1f1:	00 
 120f1f2:	c5 fc 11 83 e0 00 00 	vmovups %ymm0,0xe0(%rbx)
 120f1f9:	00 
 120f1fa:	c5 fc 11 83 c0 00 00 	vmovups %ymm0,0xc0(%rbx)
 120f201:	00 
 120f202:	c5 fc 11 83 a0 00 00 	vmovups %ymm0,0xa0(%rbx)
 120f209:	00 
 120f20a:	c5 fc 11 83 80 00 00 	vmovups %ymm0,0x80(%rbx)
 120f211:	00 
 120f212:	c5 fc 11 43 60       	vmovups %ymm0,0x60(%rbx)
 120f217:	c5 fc 11 43 40       	vmovups %ymm0,0x40(%rbx)
 120f21c:	c5 fc 11 43 20       	vmovups %ymm0,0x20(%rbx)
 120f221:	c5 fc 11 03          	vmovups %ymm0,(%rbx)
 120f225:	48 81 c4 d8 03 00 00 	add    $0x3d8,%rsp
 120f22c:	5b                   	pop    %rbx
 120f22d:	41 5c                	pop    %r12
 120f22f:	41 5d                	pop    %r13
 120f231:	41 5e                	pop    %r14
 120f233:	41 5f                	pop    %r15
 120f235:	5d                   	pop    %rbp
 120f236:	c5 f8 77             	vzeroupper 
 120f239:	c3                   	ret    
 120f23a:	31 c0                	xor    %eax,%eax
 120f23c:	31 c9                	xor    %ecx,%ecx
 120f23e:	eb 0d                	jmp    120f24d <br.encoder.literal_context_split.chooseProposals+0x3fd>
 120f240:	48 83 c1 04          	add    $0x4,%rcx
 120f244:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 120f24b:	74 6a                	je     120f2b7 <br.encoder.literal_context_split.chooseProposals+0x467>
 120f24d:	41 83 bc 8f 08 00 04 	cmpl   $0x0,0x40008(%r15,%rcx,4)
 120f254:	00 00 
 120f256:	74 0c                	je     120f264 <br.encoder.literal_context_split.chooseProposals+0x414>
 120f258:	0f b7 d0             	movzwl %ax,%edx
 120f25b:	88 8c 15 18 fc ff ff 	mov    %cl,-0x3e8(%rbp,%rdx,1)
 120f262:	ff c0                	inc    %eax
 120f264:	41 83 bc 8f 0c 00 04 	cmpl   $0x0,0x4000c(%r15,%rcx,4)
 120f26b:	00 00 
 120f26d:	74 10                	je     120f27f <br.encoder.literal_context_split.chooseProposals+0x42f>
 120f26f:	0f b7 d0             	movzwl %ax,%edx
 120f272:	8d 71 01             	lea    0x1(%rcx),%esi
 120f275:	40 88 b4 15 18 fc ff 	mov    %sil,-0x3e8(%rbp,%rdx,1)
 120f27c:	ff 
 120f27d:	ff c0                	inc    %eax
 120f27f:	41 83 bc 8f 10 00 04 	cmpl   $0x0,0x40010(%r15,%rcx,4)
 120f286:	00 00 
 120f288:	74 10                	je     120f29a <br.encoder.literal_context_split.chooseProposals+0x44a>
 120f28a:	0f b7 d0             	movzwl %ax,%edx
 120f28d:	8d 71 02             	lea    0x2(%rcx),%esi
 120f290:	40 88 b4 15 18 fc ff 	mov    %sil,-0x3e8(%rbp,%rdx,1)
 120f297:	ff 
 120f298:	ff c0                	inc    %eax
 120f29a:	41 83 bc 8f 14 00 04 	cmpl   $0x0,0x40014(%r15,%rcx,4)
 120f2a1:	00 00 
 120f2a3:	74 9b                	je     120f240 <br.encoder.literal_context_split.chooseProposals+0x3f0>
 120f2a5:	0f b7 d0             	movzwl %ax,%edx
 120f2a8:	8d 71 03             	lea    0x3(%rcx),%esi
 120f2ab:	40 88 b4 15 18 fc ff 	mov    %sil,-0x3e8(%rbp,%rdx,1)
 120f2b2:	ff 
 120f2b3:	ff c0                	inc    %eax
 120f2b5:	eb 89                	jmp    120f240 <br.encoder.literal_context_split.chooseProposals+0x3f0>
 120f2b7:	66 89 85 16 fc ff ff 	mov    %ax,-0x3ea(%rbp)
 120f2be:	48 8d bd 18 fd ff ff 	lea    -0x2e8(%rbp),%rdi
 120f2c5:	4c 8d b5 16 fc ff ff 	lea    -0x3ea(%rbp),%r14
 120f2cc:	4c 89 e6             	mov    %r12,%rsi
 120f2cf:	4c 89 f2             	mov    %r14,%rdx
 120f2d2:	e8 99 d3 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46116>
 120f2d7:	0f b7 9d 20 fd ff ff 	movzwl -0x2e0(%rbp),%ebx
 120f2de:	66 85 db             	test   %bx,%bx
 120f2e1:	0f 85 a3 09 00 00    	jne    120fc8a <br.encoder.literal_context_split.chooseProposals+0xe3a>
 120f2e7:	4c 8b 8d 18 fd ff ff 	mov    -0x2e8(%rbp),%r9
 120f2ee:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 120f2f2:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 120f2f9:	ff 
 120f2fa:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 120f301:	ff 
 120f302:	48 c7 85 7e fe ff ff 	movq   $0x0,-0x182(%rbp)
 120f309:	00 00 00 00 
 120f30d:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 120f314:	ff 
 120f315:	c5 fc 11 85 b0 fe ff 	vmovups %ymm0,-0x150(%rbp)
 120f31c:	ff 
 120f31d:	48 c7 85 ce fe ff ff 	movq   $0x0,-0x132(%rbp)
 120f324:	00 00 00 00 
 120f328:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 120f32f:	ff 
 120f330:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 120f337:	ff 
 120f338:	48 c7 85 1e ff ff ff 	movq   $0x0,-0xe2(%rbp)
 120f33f:	00 00 00 00 
 120f343:	4d 8b 07             	mov    (%r15),%r8
 120f346:	4c 89 34 24          	mov    %r14,(%rsp)
 120f34a:	48 8d bd 28 fd ff ff 	lea    -0x2d8(%rbp),%rdi
 120f351:	31 f6                	xor    %esi,%esi
 120f353:	48 8b 95 70 ff ff ff 	mov    -0x90(%rbp),%rdx
 120f35a:	4d 89 e5             	mov    %r12,%r13
 120f35d:	4c 89 e1             	mov    %r12,%rcx
 120f360:	4c 89 8d 70 ff ff ff 	mov    %r9,-0x90(%rbp)
 120f367:	c5 f8 77             	vzeroupper 
 120f36a:	e8 11 d9 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46179>
 120f36f:	44 0f b7 a5 30 fe ff 	movzwl -0x1d0(%rbp),%r12d
 120f376:	ff 
 120f377:	66 45 85 e4          	test   %r12w,%r12w
 120f37b:	0f 85 cf 08 00 00    	jne    120fc50 <br.encoder.literal_context_split.chooseProposals+0xe00>
 120f381:	48 8d 95 32 fd ff ff 	lea    -0x2ce(%rbp),%rdx
 120f388:	0f b6 85 d0 fd ff ff 	movzbl -0x230(%rbp),%eax
 120f38f:	b3 01                	mov    $0x1,%bl
 120f391:	80 bd 78 fd ff ff 00 	cmpb   $0x0,-0x288(%rbp)
 120f398:	74 4d                	je     120f3e7 <br.encoder.literal_context_split.chooseProposals+0x597>
 120f39a:	48 8b 8d 28 fd ff ff 	mov    -0x2d8(%rbp),%rcx
 120f3a1:	48 89 4d d0          	mov    %rcx,-0x30(%rbp)
 120f3a5:	0f b6 8d 30 fd ff ff 	movzbl -0x2d0(%rbp),%ecx
 120f3ac:	89 4d 98             	mov    %ecx,-0x68(%rbp)
 120f3af:	0f b6 8d 31 fd ff ff 	movzbl -0x2cf(%rbp),%ecx
 120f3b6:	89 4d c0             	mov    %ecx,-0x40(%rbp)
 120f3b9:	48 8b 4a 3e          	mov    0x3e(%rdx),%rcx
 120f3bd:	48 89 8d 7e fe ff ff 	mov    %rcx,-0x182(%rbp)
 120f3c4:	c5 fc 10 02          	vmovups (%rdx),%ymm0
 120f3c8:	c5 fc 10 4a 20       	vmovups 0x20(%rdx),%ymm1
 120f3cd:	c5 fc 11 8d 60 fe ff 	vmovups %ymm1,-0x1a0(%rbp)
 120f3d4:	ff 
 120f3d5:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 120f3dc:	ff 
 120f3dd:	b1 01                	mov    $0x1,%cl
 120f3df:	89 4d 90             	mov    %ecx,-0x70(%rbp)
 120f3e2:	45 31 f6             	xor    %r14d,%r14d
 120f3e5:	eb 18                	jmp    120f3ff <br.encoder.literal_context_split.chooseProposals+0x5af>
 120f3e7:	c7 45 90 00 00 00 00 	movl   $0x0,-0x70(%rbp)
 120f3ee:	41 b6 01             	mov    $0x1,%r14b
 120f3f1:	c7 45 c0 00 00 00 00 	movl   $0x0,-0x40(%rbp)
 120f3f8:	c7 45 98 00 00 00 00 	movl   $0x0,-0x68(%rbp)
 120f3ff:	4c 89 e9             	mov    %r13,%rcx
 120f402:	48 8d b5 8a fd ff ff 	lea    -0x276(%rbp),%rsi
 120f409:	0f b6 95 28 fe ff ff 	movzbl -0x1d8(%rbp),%edx
 120f410:	84 c0                	test   %al,%al
 120f412:	0f 84 a8 00 00 00    	je     120f4c0 <br.encoder.literal_context_split.chooseProposals+0x670>
 120f418:	48 8b 85 80 fd ff ff 	mov    -0x280(%rbp),%rax
 120f41f:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 120f423:	0f b6 85 88 fd ff ff 	movzbl -0x278(%rbp),%eax
 120f42a:	89 45 80             	mov    %eax,-0x80(%rbp)
 120f42d:	0f b6 85 89 fd ff ff 	movzbl -0x277(%rbp),%eax
 120f434:	89 45 c8             	mov    %eax,-0x38(%rbp)
 120f437:	48 8b 46 3e          	mov    0x3e(%rsi),%rax
 120f43b:	48 89 85 ce fe ff ff 	mov    %rax,-0x132(%rbp)
 120f442:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 120f446:	c5 fc 10 4e 20       	vmovups 0x20(%rsi),%ymm1
 120f44b:	c5 fc 11 8d b0 fe ff 	vmovups %ymm1,-0x150(%rbp)
 120f452:	ff 
 120f453:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 120f45a:	ff 
 120f45b:	b0 01                	mov    $0x1,%al
 120f45d:	31 db                	xor    %ebx,%ebx
 120f45f:	89 85 60 ff ff ff    	mov    %eax,-0xa0(%rbp)
 120f465:	48 8d b5 e2 fd ff ff 	lea    -0x21e(%rbp),%rsi
 120f46c:	84 d2                	test   %dl,%dl
 120f46e:	74 71                	je     120f4e1 <br.encoder.literal_context_split.chooseProposals+0x691>
 120f470:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 120f477:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 120f47b:	0f b6 85 e0 fd ff ff 	movzbl -0x220(%rbp),%eax
 120f482:	89 45 88             	mov    %eax,-0x78(%rbp)
 120f485:	0f b6 85 e1 fd ff ff 	movzbl -0x21f(%rbp),%eax
 120f48c:	89 45 a0             	mov    %eax,-0x60(%rbp)
 120f48f:	48 8b 46 3e          	mov    0x3e(%rsi),%rax
 120f493:	48 89 85 1e ff ff ff 	mov    %rax,-0xe2(%rbp)
 120f49a:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 120f49e:	c5 fc 10 4e 20       	vmovups 0x20(%rsi),%ymm1
 120f4a3:	c5 fc 11 8d 00 ff ff 	vmovups %ymm1,-0x100(%rbp)
 120f4aa:	ff 
 120f4ab:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 120f4b2:	ff 
 120f4b3:	b0 01                	mov    $0x1,%al
 120f4b5:	89 85 78 ff ff ff    	mov    %eax,-0x88(%rbp)
 120f4bb:	45 31 ff             	xor    %r15d,%r15d
 120f4be:	eb 3c                	jmp    120f4fc <br.encoder.literal_context_split.chooseProposals+0x6ac>
 120f4c0:	c7 45 80 00 00 00 00 	movl   $0x0,-0x80(%rbp)
 120f4c7:	c7 45 c8 00 00 00 00 	movl   $0x0,-0x38(%rbp)
 120f4ce:	31 c0                	xor    %eax,%eax
 120f4d0:	89 85 60 ff ff ff    	mov    %eax,-0xa0(%rbp)
 120f4d6:	48 8d b5 e2 fd ff ff 	lea    -0x21e(%rbp),%rsi
 120f4dd:	84 d2                	test   %dl,%dl
 120f4df:	75 8f                	jne    120f470 <br.encoder.literal_context_split.chooseProposals+0x620>
 120f4e1:	41 b7 01             	mov    $0x1,%r15b
 120f4e4:	c7 45 88 00 00 00 00 	movl   $0x0,-0x78(%rbp)
 120f4eb:	c7 45 a0 00 00 00 00 	movl   $0x0,-0x60(%rbp)
 120f4f2:	c7 85 78 ff ff ff 00 	movl   $0x0,-0x88(%rbp)
 120f4f9:	00 00 00 
 120f4fc:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 120f500:	4c 8b 00             	mov    (%rax),%r8
 120f503:	48 8d 85 16 fc ff ff 	lea    -0x3ea(%rbp),%rax
 120f50a:	48 89 04 24          	mov    %rax,(%rsp)
 120f50e:	48 8d bd 28 fd ff ff 	lea    -0x2d8(%rbp),%rdi
 120f515:	be 01 00 00 00       	mov    $0x1,%esi
 120f51a:	48 8b 95 30 ff ff ff 	mov    -0xd0(%rbp),%rdx
 120f521:	4c 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%r9
 120f528:	c5 f8 77             	vzeroupper 
 120f52b:	e8 50 d7 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46179>
 120f530:	44 0f b7 a5 30 fe ff 	movzwl -0x1d0(%rbp),%r12d
 120f537:	ff 
 120f538:	66 45 85 e4          	test   %r12w,%r12w
 120f53c:	0f 85 0e 07 00 00    	jne    120fc50 <br.encoder.literal_context_split.chooseProposals+0xe00>
 120f542:	0f b6 85 d0 fd ff ff 	movzbl -0x230(%rbp),%eax
 120f549:	80 bd 78 fd ff ff 00 	cmpb   $0x0,-0x288(%rbp)
 120f550:	0f 84 92 00 00 00    	je     120f5e8 <br.encoder.literal_context_split.chooseProposals+0x798>
 120f556:	4c 8b 95 28 fd ff ff 	mov    -0x2d8(%rbp),%r10
 120f55d:	0f b6 95 30 fd ff ff 	movzbl -0x2d0(%rbp),%edx
 120f564:	0f b6 b5 31 fd ff ff 	movzbl -0x2cf(%rbp),%esi
 120f56b:	4c 3b 55 d0          	cmp    -0x30(%rbp),%r10
 120f56f:	40 0f 97 c7          	seta   %dil
 120f573:	41 08 fe             	or     %dil,%r14b
 120f576:	4c 89 e9             	mov    %r13,%rcx
 120f579:	4c 8d 9d 16 fc ff ff 	lea    -0x3ea(%rbp),%r11
 120f580:	75 27                	jne    120f5a9 <br.encoder.literal_context_split.chooseProposals+0x759>
 120f582:	4c 3b 55 d0          	cmp    -0x30(%rbp),%r10
 120f586:	40 0f 94 c7          	sete   %dil
 120f58a:	41 89 f0             	mov    %esi,%r8d
 120f58d:	41 80 e0 7f          	and    $0x7f,%r8b
 120f591:	44 8b 4d c0          	mov    -0x40(%rbp),%r9d
 120f595:	41 80 e1 7f          	and    $0x7f,%r9b
 120f599:	45 38 c8             	cmp    %r9b,%r8b
 120f59c:	41 0f 92 c0          	setb   %r8b
 120f5a0:	41 20 f8             	and    %dil,%r8b
 120f5a3:	41 80 f8 01          	cmp    $0x1,%r8b
 120f5a7:	75 49                	jne    120f5f2 <br.encoder.literal_context_split.chooseProposals+0x7a2>
 120f5a9:	4c 8d 85 32 fd ff ff 	lea    -0x2ce(%rbp),%r8
 120f5b0:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f5b4:	48 89 bd 7e fe ff ff 	mov    %rdi,-0x182(%rbp)
 120f5bb:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f5c0:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f5c6:	c5 fc 11 8d 60 fe ff 	vmovups %ymm1,-0x1a0(%rbp)
 120f5cd:	ff 
 120f5ce:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 120f5d5:	ff 
 120f5d6:	40 b7 01             	mov    $0x1,%dil
 120f5d9:	89 7d 90             	mov    %edi,-0x70(%rbp)
 120f5dc:	89 75 c0             	mov    %esi,-0x40(%rbp)
 120f5df:	89 55 98             	mov    %edx,-0x68(%rbp)
 120f5e2:	4c 89 55 d0          	mov    %r10,-0x30(%rbp)
 120f5e6:	eb 0a                	jmp    120f5f2 <br.encoder.literal_context_split.chooseProposals+0x7a2>
 120f5e8:	4c 89 e9             	mov    %r13,%rcx
 120f5eb:	4c 8d 9d 16 fc ff ff 	lea    -0x3ea(%rbp),%r11
 120f5f2:	44 0f b6 95 28 fe ff 	movzbl -0x1d8(%rbp),%r10d
 120f5f9:	ff 
 120f5fa:	84 c0                	test   %al,%al
 120f5fc:	0f 84 8b 00 00 00    	je     120f68d <br.encoder.literal_context_split.chooseProposals+0x83d>
 120f602:	48 8b 85 80 fd ff ff 	mov    -0x280(%rbp),%rax
 120f609:	0f b6 b5 88 fd ff ff 	movzbl -0x278(%rbp),%esi
 120f610:	0f b6 95 89 fd ff ff 	movzbl -0x277(%rbp),%edx
 120f617:	48 3b 45 b0          	cmp    -0x50(%rbp),%rax
 120f61b:	40 0f 97 c7          	seta   %dil
 120f61f:	40 08 fb             	or     %dil,%bl
 120f622:	75 27                	jne    120f64b <br.encoder.literal_context_split.chooseProposals+0x7fb>
 120f624:	48 3b 45 b0          	cmp    -0x50(%rbp),%rax
 120f628:	40 0f 94 c7          	sete   %dil
 120f62c:	41 89 d0             	mov    %edx,%r8d
 120f62f:	41 80 e0 7f          	and    $0x7f,%r8b
 120f633:	44 8b 4d c8          	mov    -0x38(%rbp),%r9d
 120f637:	41 80 e1 7f          	and    $0x7f,%r9b
 120f63b:	45 38 c8             	cmp    %r9b,%r8b
 120f63e:	41 0f 92 c0          	setb   %r8b
 120f642:	41 20 f8             	and    %dil,%r8b
 120f645:	41 80 f8 01          	cmp    $0x1,%r8b
 120f649:	75 42                	jne    120f68d <br.encoder.literal_context_split.chooseProposals+0x83d>
 120f64b:	4c 8d 85 8a fd ff ff 	lea    -0x276(%rbp),%r8
 120f652:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f656:	48 89 bd ce fe ff ff 	mov    %rdi,-0x132(%rbp)
 120f65d:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f662:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f668:	c5 fc 11 8d b0 fe ff 	vmovups %ymm1,-0x150(%rbp)
 120f66f:	ff 
 120f670:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 120f677:	ff 
 120f678:	40 b7 01             	mov    $0x1,%dil
 120f67b:	89 bd 60 ff ff ff    	mov    %edi,-0xa0(%rbp)
 120f681:	89 75 80             	mov    %esi,-0x80(%rbp)
 120f684:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 120f688:	89 d0                	mov    %edx,%eax
 120f68a:	89 45 c8             	mov    %eax,-0x38(%rbp)
 120f68d:	45 84 d2             	test   %r10b,%r10b
 120f690:	0f 84 8c 00 00 00    	je     120f722 <br.encoder.literal_context_split.chooseProposals+0x8d2>
 120f696:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 120f69d:	44 0f b6 8d e0 fd ff 	movzbl -0x220(%rbp),%r9d
 120f6a4:	ff 
 120f6a5:	0f b6 95 e1 fd ff ff 	movzbl -0x21f(%rbp),%edx
 120f6ac:	48 3b 45 b8          	cmp    -0x48(%rbp),%rax
 120f6b0:	40 0f 97 c6          	seta   %sil
 120f6b4:	41 08 f7             	or     %sil,%r15b
 120f6b7:	75 26                	jne    120f6df <br.encoder.literal_context_split.chooseProposals+0x88f>
 120f6b9:	48 3b 45 b8          	cmp    -0x48(%rbp),%rax
 120f6bd:	40 0f 94 c6          	sete   %sil
 120f6c1:	89 d7                	mov    %edx,%edi
 120f6c3:	40 80 e7 7f          	and    $0x7f,%dil
 120f6c7:	44 8b 45 a0          	mov    -0x60(%rbp),%r8d
 120f6cb:	41 80 e0 7f          	and    $0x7f,%r8b
 120f6cf:	44 38 c7             	cmp    %r8b,%dil
 120f6d2:	40 0f 92 c7          	setb   %dil
 120f6d6:	40 20 f7             	and    %sil,%dil
 120f6d9:	40 80 ff 01          	cmp    $0x1,%dil
 120f6dd:	75 43                	jne    120f722 <br.encoder.literal_context_split.chooseProposals+0x8d2>
 120f6df:	48 8d bd e2 fd ff ff 	lea    -0x21e(%rbp),%rdi
 120f6e6:	48 8b 77 3e          	mov    0x3e(%rdi),%rsi
 120f6ea:	48 89 b5 1e ff ff ff 	mov    %rsi,-0xe2(%rbp)
 120f6f1:	c5 fc 10 07          	vmovups (%rdi),%ymm0
 120f6f5:	c5 fc 10 4f 20       	vmovups 0x20(%rdi),%ymm1
 120f6fa:	c5 fc 11 8d 00 ff ff 	vmovups %ymm1,-0x100(%rbp)
 120f701:	ff 
 120f702:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 120f709:	ff 
 120f70a:	40 b6 01             	mov    $0x1,%sil
 120f70d:	89 b5 78 ff ff ff    	mov    %esi,-0x88(%rbp)
 120f713:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 120f717:	44 89 c8             	mov    %r9d,%eax
 120f71a:	89 45 88             	mov    %eax,-0x78(%rbp)
 120f71d:	89 d0                	mov    %edx,%eax
 120f71f:	89 45 a0             	mov    %eax,-0x60(%rbp)
 120f722:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 120f726:	4c 8b 00             	mov    (%rax),%r8
 120f729:	4c 89 1c 24          	mov    %r11,(%rsp)
 120f72d:	48 8d bd 28 fd ff ff 	lea    -0x2d8(%rbp),%rdi
 120f734:	be 02 00 00 00       	mov    $0x2,%esi
 120f739:	48 8b 95 38 ff ff ff 	mov    -0xc8(%rbp),%rdx
 120f740:	4c 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%r9
 120f747:	c5 f8 77             	vzeroupper 
 120f74a:	e8 31 d5 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46179>
 120f74f:	44 0f b7 a5 30 fe ff 	movzwl -0x1d0(%rbp),%r12d
 120f756:	ff 
 120f757:	66 45 85 e4          	test   %r12w,%r12w
 120f75b:	0f 85 ef 04 00 00    	jne    120fc50 <br.encoder.literal_context_split.chooseProposals+0xe00>
 120f761:	0f b6 85 d0 fd ff ff 	movzbl -0x230(%rbp),%eax
 120f768:	80 bd 78 fd ff ff 00 	cmpb   $0x0,-0x288(%rbp)
 120f76f:	0f 84 9a 00 00 00    	je     120f80f <br.encoder.literal_context_split.chooseProposals+0x9bf>
 120f775:	4c 8b 95 28 fd ff ff 	mov    -0x2d8(%rbp),%r10
 120f77c:	0f b6 95 30 fd ff ff 	movzbl -0x2d0(%rbp),%edx
 120f783:	0f b6 b5 31 fd ff ff 	movzbl -0x2cf(%rbp),%esi
 120f78a:	80 7d 90 00          	cmpb   $0x0,-0x70(%rbp)
 120f78e:	40 0f 94 c7          	sete   %dil
 120f792:	4c 3b 55 d0          	cmp    -0x30(%rbp),%r10
 120f796:	41 0f 97 c0          	seta   %r8b
 120f79a:	41 08 f8             	or     %dil,%r8b
 120f79d:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 120f7a1:	44 8b 9d 60 ff ff ff 	mov    -0xa0(%rbp),%r11d
 120f7a8:	8b 9d 78 ff ff ff    	mov    -0x88(%rbp),%ebx
 120f7ae:	4c 8d b5 16 fc ff ff 	lea    -0x3ea(%rbp),%r14
 120f7b5:	75 19                	jne    120f7d0 <br.encoder.literal_context_split.chooseProposals+0x980>
 120f7b7:	4c 3b 55 d0          	cmp    -0x30(%rbp),%r10
 120f7bb:	75 6a                	jne    120f827 <br.encoder.literal_context_split.chooseProposals+0x9d7>
 120f7bd:	8b 7d c0             	mov    -0x40(%rbp),%edi
 120f7c0:	40 80 e7 7f          	and    $0x7f,%dil
 120f7c4:	41 89 f0             	mov    %esi,%r8d
 120f7c7:	41 80 e0 7f          	and    $0x7f,%r8b
 120f7cb:	41 38 f8             	cmp    %dil,%r8b
 120f7ce:	73 57                	jae    120f827 <br.encoder.literal_context_split.chooseProposals+0x9d7>
 120f7d0:	4c 8d 85 32 fd ff ff 	lea    -0x2ce(%rbp),%r8
 120f7d7:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f7db:	48 89 bd 7e fe ff ff 	mov    %rdi,-0x182(%rbp)
 120f7e2:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f7e7:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f7ed:	c5 fc 11 8d 60 fe ff 	vmovups %ymm1,-0x1a0(%rbp)
 120f7f4:	ff 
 120f7f5:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 120f7fc:	ff 
 120f7fd:	40 b7 01             	mov    $0x1,%dil
 120f800:	89 7d 90             	mov    %edi,-0x70(%rbp)
 120f803:	89 75 c0             	mov    %esi,-0x40(%rbp)
 120f806:	89 55 98             	mov    %edx,-0x68(%rbp)
 120f809:	4c 89 55 d0          	mov    %r10,-0x30(%rbp)
 120f80d:	eb 18                	jmp    120f827 <br.encoder.literal_context_split.chooseProposals+0x9d7>
 120f80f:	4c 8b 4d a8          	mov    -0x58(%rbp),%r9
 120f813:	44 8b 9d 60 ff ff ff 	mov    -0xa0(%rbp),%r11d
 120f81a:	8b 9d 78 ff ff ff    	mov    -0x88(%rbp),%ebx
 120f820:	4c 8d b5 16 fc ff ff 	lea    -0x3ea(%rbp),%r14
 120f827:	44 0f b6 95 28 fe ff 	movzbl -0x1d8(%rbp),%r10d
 120f82e:	ff 
 120f82f:	84 c0                	test   %al,%al
 120f831:	74 71                	je     120f8a4 <br.encoder.literal_context_split.chooseProposals+0xa54>
 120f833:	48 8b 85 80 fd ff ff 	mov    -0x280(%rbp),%rax
 120f83a:	0f b6 b5 88 fd ff ff 	movzbl -0x278(%rbp),%esi
 120f841:	0f b6 95 89 fd ff ff 	movzbl -0x277(%rbp),%edx
 120f848:	45 84 db             	test   %r11b,%r11b
 120f84b:	74 1b                	je     120f868 <br.encoder.literal_context_split.chooseProposals+0xa18>
 120f84d:	48 3b 45 b0          	cmp    -0x50(%rbp),%rax
 120f851:	77 15                	ja     120f868 <br.encoder.literal_context_split.chooseProposals+0xa18>
 120f853:	75 4f                	jne    120f8a4 <br.encoder.literal_context_split.chooseProposals+0xa54>
 120f855:	8b 7d c8             	mov    -0x38(%rbp),%edi
 120f858:	40 80 e7 7f          	and    $0x7f,%dil
 120f85c:	41 89 d0             	mov    %edx,%r8d
 120f85f:	41 80 e0 7f          	and    $0x7f,%r8b
 120f863:	41 38 f8             	cmp    %dil,%r8b
 120f866:	73 3c                	jae    120f8a4 <br.encoder.literal_context_split.chooseProposals+0xa54>
 120f868:	4c 8d 85 8a fd ff ff 	lea    -0x276(%rbp),%r8
 120f86f:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f873:	48 89 bd ce fe ff ff 	mov    %rdi,-0x132(%rbp)
 120f87a:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f87f:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f885:	c5 fc 11 8d b0 fe ff 	vmovups %ymm1,-0x150(%rbp)
 120f88c:	ff 
 120f88d:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 120f894:	ff 
 120f895:	41 b3 01             	mov    $0x1,%r11b
 120f898:	89 75 80             	mov    %esi,-0x80(%rbp)
 120f89b:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 120f89f:	89 d0                	mov    %edx,%eax
 120f8a1:	89 45 c8             	mov    %eax,-0x38(%rbp)
 120f8a4:	45 84 d2             	test   %r10b,%r10b
 120f8a7:	74 70                	je     120f919 <br.encoder.literal_context_split.chooseProposals+0xac9>
 120f8a9:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 120f8b0:	44 0f b6 85 e0 fd ff 	movzbl -0x220(%rbp),%r8d
 120f8b7:	ff 
 120f8b8:	0f b6 95 e1 fd ff ff 	movzbl -0x21f(%rbp),%edx
 120f8bf:	84 db                	test   %bl,%bl
 120f8c1:	74 1a                	je     120f8dd <br.encoder.literal_context_split.chooseProposals+0xa8d>
 120f8c3:	48 3b 45 b8          	cmp    -0x48(%rbp),%rax
 120f8c7:	77 14                	ja     120f8dd <br.encoder.literal_context_split.chooseProposals+0xa8d>
 120f8c9:	75 4e                	jne    120f919 <br.encoder.literal_context_split.chooseProposals+0xac9>
 120f8cb:	8b 75 a0             	mov    -0x60(%rbp),%esi
 120f8ce:	40 80 e6 7f          	and    $0x7f,%sil
 120f8d2:	89 d7                	mov    %edx,%edi
 120f8d4:	40 80 e7 7f          	and    $0x7f,%dil
 120f8d8:	40 38 f7             	cmp    %sil,%dil
 120f8db:	73 3c                	jae    120f919 <br.encoder.literal_context_split.chooseProposals+0xac9>
 120f8dd:	48 8d bd e2 fd ff ff 	lea    -0x21e(%rbp),%rdi
 120f8e4:	48 8b 77 3e          	mov    0x3e(%rdi),%rsi
 120f8e8:	48 89 b5 1e ff ff ff 	mov    %rsi,-0xe2(%rbp)
 120f8ef:	c5 fc 10 07          	vmovups (%rdi),%ymm0
 120f8f3:	c5 fc 10 4f 20       	vmovups 0x20(%rdi),%ymm1
 120f8f8:	c5 fc 11 8d 00 ff ff 	vmovups %ymm1,-0x100(%rbp)
 120f8ff:	ff 
 120f900:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 120f907:	ff 
 120f908:	b3 01                	mov    $0x1,%bl
 120f90a:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 120f90e:	44 89 c0             	mov    %r8d,%eax
 120f911:	89 45 88             	mov    %eax,-0x78(%rbp)
 120f914:	89 d0                	mov    %edx,%eax
 120f916:	89 45 a0             	mov    %eax,-0x60(%rbp)
 120f919:	45 89 df             	mov    %r11d,%r15d
 120f91c:	4d 8b 01             	mov    (%r9),%r8
 120f91f:	4c 89 34 24          	mov    %r14,(%rsp)
 120f923:	48 8d bd 28 fd ff ff 	lea    -0x2d8(%rbp),%rdi
 120f92a:	be 03 00 00 00       	mov    $0x3,%esi
 120f92f:	48 8b 95 40 ff ff ff 	mov    -0xc0(%rbp),%rdx
 120f936:	4c 89 e9             	mov    %r13,%rcx
 120f939:	4c 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%r9
 120f940:	c5 f8 77             	vzeroupper 
 120f943:	e8 38 d3 ff ff       	call   120cc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46179>
 120f948:	44 0f b7 a5 30 fe ff 	movzwl -0x1d0(%rbp),%r12d
 120f94f:	ff 
 120f950:	66 45 85 e4          	test   %r12w,%r12w
 120f954:	0f 85 f6 02 00 00    	jne    120fc50 <br.encoder.literal_context_split.chooseProposals+0xe00>
 120f95a:	0f b6 85 d0 fd ff ff 	movzbl -0x230(%rbp),%eax
 120f961:	80 bd 78 fd ff ff 00 	cmpb   $0x0,-0x288(%rbp)
 120f968:	0f 84 0b 01 00 00    	je     120fa79 <br.encoder.literal_context_split.chooseProposals+0xc29>
 120f96e:	48 8b 8d 28 fd ff ff 	mov    -0x2d8(%rbp),%rcx
 120f975:	0f b6 95 30 fd ff ff 	movzbl -0x2d0(%rbp),%edx
 120f97c:	44 0f b6 8d 31 fd ff 	movzbl -0x2cf(%rbp),%r9d
 120f983:	ff 
 120f984:	44 8b 75 90          	mov    -0x70(%rbp),%r14d
 120f988:	45 84 f6             	test   %r14b,%r14b
 120f98b:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 120f98f:	74 1b                	je     120f9ac <br.encoder.literal_context_split.chooseProposals+0xb5c>
 120f991:	48 3b 4d d0          	cmp    -0x30(%rbp),%rcx
 120f995:	77 15                	ja     120f9ac <br.encoder.literal_context_split.chooseProposals+0xb5c>
 120f997:	75 50                	jne    120f9e9 <br.encoder.literal_context_split.chooseProposals+0xb99>
 120f999:	8b 7d c0             	mov    -0x40(%rbp),%edi
 120f99c:	40 80 e7 7f          	and    $0x7f,%dil
 120f9a0:	45 89 c8             	mov    %r9d,%r8d
 120f9a3:	41 80 e0 7f          	and    $0x7f,%r8b
 120f9a7:	41 38 f8             	cmp    %dil,%r8b
 120f9aa:	73 3d                	jae    120f9e9 <br.encoder.literal_context_split.chooseProposals+0xb99>
 120f9ac:	4c 8d 85 32 fd ff ff 	lea    -0x2ce(%rbp),%r8
 120f9b3:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120f9b7:	48 89 bd 7e fe ff ff 	mov    %rdi,-0x182(%rbp)
 120f9be:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120f9c3:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120f9c9:	c5 fc 11 8d 60 fe ff 	vmovups %ymm1,-0x1a0(%rbp)
 120f9d0:	ff 
 120f9d1:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 120f9d8:	ff 
 120f9d9:	41 b6 01             	mov    $0x1,%r14b
 120f9dc:	44 89 cf             	mov    %r9d,%edi
 120f9df:	89 7d c0             	mov    %edi,-0x40(%rbp)
 120f9e2:	89 55 98             	mov    %edx,-0x68(%rbp)
 120f9e5:	48 89 4d d0          	mov    %rcx,-0x30(%rbp)
 120f9e9:	0f b6 8d 28 fe ff ff 	movzbl -0x1d8(%rbp),%ecx
 120f9f0:	84 c0                	test   %al,%al
 120f9f2:	41 89 dc             	mov    %ebx,%r12d
 120f9f5:	0f 84 98 00 00 00    	je     120fa93 <br.encoder.literal_context_split.chooseProposals+0xc43>
 120f9fb:	48 8b 85 80 fd ff ff 	mov    -0x280(%rbp),%rax
 120fa02:	44 0f b6 8d 88 fd ff 	movzbl -0x278(%rbp),%r9d
 120fa09:	ff 
 120fa0a:	0f b6 95 89 fd ff ff 	movzbl -0x277(%rbp),%edx
 120fa11:	45 84 ff             	test   %r15b,%r15b
 120fa14:	48 8b 9d 68 ff ff ff 	mov    -0x98(%rbp),%rbx
 120fa1b:	74 1b                	je     120fa38 <br.encoder.literal_context_split.chooseProposals+0xbe8>
 120fa1d:	48 3b 45 b0          	cmp    -0x50(%rbp),%rax
 120fa21:	77 15                	ja     120fa38 <br.encoder.literal_context_split.chooseProposals+0xbe8>
 120fa23:	75 75                	jne    120fa9a <br.encoder.literal_context_split.chooseProposals+0xc4a>
 120fa25:	8b 7d c8             	mov    -0x38(%rbp),%edi
 120fa28:	40 80 e7 7f          	and    $0x7f,%dil
 120fa2c:	41 89 d0             	mov    %edx,%r8d
 120fa2f:	41 80 e0 7f          	and    $0x7f,%r8b
 120fa33:	41 38 f8             	cmp    %dil,%r8b
 120fa36:	73 62                	jae    120fa9a <br.encoder.literal_context_split.chooseProposals+0xc4a>
 120fa38:	4c 8d 85 8a fd ff ff 	lea    -0x276(%rbp),%r8
 120fa3f:	49 8b 78 3e          	mov    0x3e(%r8),%rdi
 120fa43:	48 89 bd ce fe ff ff 	mov    %rdi,-0x132(%rbp)
 120fa4a:	c4 c1 7c 10 00       	vmovups (%r8),%ymm0
 120fa4f:	c4 c1 7c 10 48 20    	vmovups 0x20(%r8),%ymm1
 120fa55:	c5 fc 11 8d b0 fe ff 	vmovups %ymm1,-0x150(%rbp)
 120fa5c:	ff 
 120fa5d:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 120fa64:	ff 
 120fa65:	41 b7 01             	mov    $0x1,%r15b
 120fa68:	44 89 cf             	mov    %r9d,%edi
 120fa6b:	89 7d 80             	mov    %edi,-0x80(%rbp)
 120fa6e:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 120fa72:	89 d0                	mov    %edx,%eax
 120fa74:	89 45 c8             	mov    %eax,-0x38(%rbp)
 120fa77:	eb 21                	jmp    120fa9a <br.encoder.literal_context_split.chooseProposals+0xc4a>
 120fa79:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 120fa7d:	44 8b 75 90          	mov    -0x70(%rbp),%r14d
 120fa81:	0f b6 8d 28 fe ff ff 	movzbl -0x1d8(%rbp),%ecx
 120fa88:	84 c0                	test   %al,%al
 120fa8a:	41 89 dc             	mov    %ebx,%r12d
 120fa8d:	0f 85 68 ff ff ff    	jne    120f9fb <br.encoder.literal_context_split.chooseProposals+0xbab>
 120fa93:	48 8b 9d 68 ff ff ff 	mov    -0x98(%rbp),%rbx
 120fa9a:	84 c9                	test   %cl,%cl
 120fa9c:	74 75                	je     120fb13 <br.encoder.literal_context_split.chooseProposals+0xcc3>
 120fa9e:	48 8b 85 d8 fd ff ff 	mov    -0x228(%rbp),%rax
 120faa5:	0f b6 8d e0 fd ff ff 	movzbl -0x220(%rbp),%ecx
 120faac:	0f b6 95 e1 fd ff ff 	movzbl -0x21f(%rbp),%edx
 120fab3:	45 84 e4             	test   %r12b,%r12b
 120fab6:	4c 8d 8d e2 fd ff ff 	lea    -0x21e(%rbp),%r9
 120fabd:	74 1d                	je     120fadc <br.encoder.literal_context_split.chooseProposals+0xc8c>
 120fabf:	48 3b 45 b8          	cmp    -0x48(%rbp),%rax
 120fac3:	77 17                	ja     120fadc <br.encoder.literal_context_split.chooseProposals+0xc8c>
 120fac5:	75 4c                	jne    120fb13 <br.encoder.literal_context_split.chooseProposals+0xcc3>
 120fac7:	8b 7d a0             	mov    -0x60(%rbp),%edi
 120faca:	41 89 f8             	mov    %edi,%r8d
 120facd:	41 80 e0 7f          	and    $0x7f,%r8b
 120fad1:	89 d7                	mov    %edx,%edi
 120fad3:	40 80 e7 7f          	and    $0x7f,%dil
 120fad7:	44 38 c7             	cmp    %r8b,%dil
 120fada:	73 37                	jae    120fb13 <br.encoder.literal_context_split.chooseProposals+0xcc3>
 120fadc:	49 8b 79 3e          	mov    0x3e(%r9),%rdi
 120fae0:	48 89 bd 1e ff ff ff 	mov    %rdi,-0xe2(%rbp)
 120fae7:	c4 c1 7c 10 01       	vmovups (%r9),%ymm0
 120faec:	c4 c1 7c 10 49 20    	vmovups 0x20(%r9),%ymm1
 120faf2:	c5 fc 11 8d 00 ff ff 	vmovups %ymm1,-0x100(%rbp)
 120faf9:	ff 
 120fafa:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 120fb01:	ff 
 120fb02:	41 b4 01             	mov    $0x1,%r12b
 120fb05:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 120fb09:	89 c8                	mov    %ecx,%eax
 120fb0b:	89 45 88             	mov    %eax,-0x78(%rbp)
 120fb0e:	89 d0                	mov    %edx,%eax
 120fb10:	89 45 a0             	mov    %eax,-0x60(%rbp)
 120fb13:	ba 08 04 04 00       	mov    $0x40408,%edx
 120fb18:	48 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%rdi
 120fb1f:	b9 03 00 00 00       	mov    $0x3,%ecx
 120fb24:	4c 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%r8
 120fb2b:	48 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%rax
 120fb32:	c5 f8 77             	vzeroupper 
 120fb35:	ff 50 18             	call   *0x18(%rax)
 120fb38:	66 c7 83 08 01 00 00 	movw   $0x0,0x108(%rbx)
 120fb3f:	00 00 
 120fb41:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 120fb45:	48 89 03             	mov    %rax,(%rbx)
 120fb48:	8b 45 98             	mov    -0x68(%rbp),%eax
 120fb4b:	88 43 08             	mov    %al,0x8(%rbx)
 120fb4e:	8b 45 c0             	mov    -0x40(%rbp),%eax
 120fb51:	88 43 09             	mov    %al,0x9(%rbx)
 120fb54:	c5 fc 10 85 40 fe ff 	vmovups -0x1c0(%rbp),%ymm0
 120fb5b:	ff 
 120fb5c:	c5 fc 11 43 0a       	vmovups %ymm0,0xa(%rbx)
 120fb61:	c5 fc 10 85 60 fe ff 	vmovups -0x1a0(%rbp),%ymm0
 120fb68:	ff 
 120fb69:	c5 fc 11 43 2a       	vmovups %ymm0,0x2a(%rbx)
 120fb6e:	48 8b 85 7e fe ff ff 	mov    -0x182(%rbp),%rax
 120fb75:	48 89 43 48          	mov    %rax,0x48(%rbx)
 120fb79:	44 88 73 50          	mov    %r14b,0x50(%rbx)
 120fb7d:	c7 43 51 00 00 00 00 	movl   $0x0,0x51(%rbx)
 120fb84:	c7 43 54 00 00 00 00 	movl   $0x0,0x54(%rbx)
 120fb8b:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 120fb8f:	48 89 43 58          	mov    %rax,0x58(%rbx)
 120fb93:	8b 45 80             	mov    -0x80(%rbp),%eax
 120fb96:	88 43 60             	mov    %al,0x60(%rbx)
 120fb99:	8b 45 c8             	mov    -0x38(%rbp),%eax
 120fb9c:	88 43 61             	mov    %al,0x61(%rbx)
 120fb9f:	c5 fc 10 85 90 fe ff 	vmovups -0x170(%rbp),%ymm0
 120fba6:	ff 
 120fba7:	c5 fc 10 8d b0 fe ff 	vmovups -0x150(%rbp),%ymm1
 120fbae:	ff 
 120fbaf:	c5 fc 11 43 62       	vmovups %ymm0,0x62(%rbx)
 120fbb4:	c5 fc 11 8b 82 00 00 	vmovups %ymm1,0x82(%rbx)
 120fbbb:	00 
 120fbbc:	48 8b 85 ce fe ff ff 	mov    -0x132(%rbp),%rax
 120fbc3:	48 89 83 a0 00 00 00 	mov    %rax,0xa0(%rbx)
 120fbca:	44 88 bb a8 00 00 00 	mov    %r15b,0xa8(%rbx)
 120fbd1:	c7 83 a9 00 00 00 00 	movl   $0x0,0xa9(%rbx)
 120fbd8:	00 00 00 
 120fbdb:	c7 83 ac 00 00 00 00 	movl   $0x0,0xac(%rbx)
 120fbe2:	00 00 00 
 120fbe5:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 120fbe9:	48 89 83 b0 00 00 00 	mov    %rax,0xb0(%rbx)
 120fbf0:	8b 45 88             	mov    -0x78(%rbp),%eax
 120fbf3:	88 83 b8 00 00 00    	mov    %al,0xb8(%rbx)
 120fbf9:	8b 45 a0             	mov    -0x60(%rbp),%eax
 120fbfc:	88 83 b9 00 00 00    	mov    %al,0xb9(%rbx)
 120fc02:	48 8b 85 1e ff ff ff 	mov    -0xe2(%rbp),%rax
 120fc09:	48 89 83 f8 00 00 00 	mov    %rax,0xf8(%rbx)
 120fc10:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 120fc17:	ff 
 120fc18:	c5 fc 11 83 da 00 00 	vmovups %ymm0,0xda(%rbx)
 120fc1f:	00 
 120fc20:	c5 fc 10 85 e0 fe ff 	vmovups -0x120(%rbp),%ymm0
 120fc27:	ff 
 120fc28:	c5 fc 11 83 ba 00 00 	vmovups %ymm0,0xba(%rbx)
 120fc2f:	00 
 120fc30:	44 88 a3 00 01 00 00 	mov    %r12b,0x100(%rbx)
 120fc37:	c7 83 04 01 00 00 00 	movl   $0x0,0x104(%rbx)
 120fc3e:	00 00 00 
 120fc41:	c7 83 01 01 00 00 00 	movl   $0x0,0x101(%rbx)
 120fc48:	00 00 00 
 120fc4b:	e9 d5 f5 ff ff       	jmp    120f225 <br.encoder.literal_context_split.chooseProposals+0x3d5>
 120fc50:	ba 08 04 04 00       	mov    $0x40408,%edx
 120fc55:	48 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%rdi
 120fc5c:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 120fc60:	b9 03 00 00 00       	mov    $0x3,%ecx
 120fc65:	4c 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%r8
 120fc6c:	48 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%rax
 120fc73:	ff 50 18             	call   *0x18(%rax)
 120fc76:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 120fc7d:	66 44 89 a0 08 01 00 	mov    %r12w,0x108(%rax)
 120fc84:	00 
 120fc85:	e9 9b f5 ff ff       	jmp    120f225 <br.encoder.literal_context_split.chooseProposals+0x3d5>
 120fc8a:	ba 08 04 04 00       	mov    $0x40408,%edx
 120fc8f:	48 8b bd 58 ff ff ff 	mov    -0xa8(%rbp),%rdi
 120fc96:	4c 89 fe             	mov    %r15,%rsi
 120fc99:	b9 03 00 00 00       	mov    $0x3,%ecx
 120fc9e:	4c 8b 85 50 ff ff ff 	mov    -0xb0(%rbp),%r8
 120fca5:	48 8b 85 48 ff ff ff 	mov    -0xb8(%rbp),%rax
 120fcac:	ff 50 18             	call   *0x18(%rax)
 120fcaf:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 120fcb6:	66 89 98 08 01 00 00 	mov    %bx,0x108(%rax)
 120fcbd:	e9 63 f5 ff ff       	jmp    120f225 <br.encoder.literal_context_split.chooseProposals+0x3d5>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
