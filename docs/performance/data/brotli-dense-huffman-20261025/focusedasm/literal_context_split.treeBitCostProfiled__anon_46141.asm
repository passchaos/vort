
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/7cab685de62cdb93856431f8e3ddb813/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120e0b0 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141>:
 120e0b0:	55                   	push   %rbp
 120e0b1:	48 89 e5             	mov    %rsp,%rbp
 120e0b4:	41 57                	push   %r15
 120e0b6:	41 56                	push   %r14
 120e0b8:	41 55                	push   %r13
 120e0ba:	41 54                	push   %r12
 120e0bc:	53                   	push   %rbx
 120e0bd:	48 81 ec b8 06 00 00 	sub    $0x6b8,%rsp
 120e0c4:	48 c7 85 20 f9 ff ff 	movq   $0x0,-0x6e0(%rbp)
 120e0cb:	00 00 00 00 
 120e0cf:	0f b7 02             	movzwl (%rdx),%eax
 120e0d2:	48 85 c0             	test   %rax,%rax
 120e0d5:	0f 84 5c 01 00 00    	je     120e237 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x187>
 120e0db:	48 89 f3             	mov    %rsi,%rbx
 120e0de:	45 31 e4             	xor    %r12d,%r12d
 120e0e1:	45 31 ff             	xor    %r15d,%r15d
 120e0e4:	31 c9                	xor    %ecx,%ecx
 120e0e6:	eb 28                	jmp    120e110 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x60>
 120e0e8:	45 31 e4             	xor    %r12d,%r12d
 120e0eb:	41 ff c7             	inc    %r15d
 120e0ee:	66 42 89 b4 65 28 f9 	mov    %si,-0x6d8(%rbp,%r12,2)
 120e0f5:	ff ff 
 120e0f7:	4c 8b a5 20 f9 ff ff 	mov    -0x6e0(%rbp),%r12
 120e0fe:	49 ff c4             	inc    %r12
 120e101:	4c 89 a5 20 f9 ff ff 	mov    %r12,-0x6e0(%rbp)
 120e108:	48 ff c1             	inc    %rcx
 120e10b:	48 39 c1             	cmp    %rax,%rcx
 120e10e:	74 4f                	je     120e15f <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0xaf>
 120e110:	0f b6 74 0a 02       	movzbl 0x2(%rdx,%rcx,1),%esi
 120e115:	44 8b 04 b3          	mov    (%rbx,%rsi,4),%r8d
 120e119:	45 85 c0             	test   %r8d,%r8d
 120e11c:	74 ea                	je     120e108 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x58>
 120e11e:	45 0f b7 cf          	movzwl %r15w,%r9d
 120e122:	42 88 b4 0d 2e fb ff 	mov    %sil,-0x4d2(%rbp,%r9,1)
 120e129:	ff 
 120e12a:	4d 85 e4             	test   %r12,%r12
 120e12d:	74 bc                	je     120e0eb <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x3b>
 120e12f:	49 81 fc 00 01 00 00 	cmp    $0x100,%r12
 120e136:	0f 84 fb 00 00 00    	je     120e237 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x187>
 120e13c:	0f 1f 40 00          	nopl   0x0(%rax)
 120e140:	46 0f b7 8c 65 26 f9 	movzwl -0x6da(%rbp,%r12,2),%r9d
 120e147:	ff ff 
 120e149:	46 3b 04 8b          	cmp    (%rbx,%r9,4),%r8d
 120e14d:	76 9c                	jbe    120e0eb <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x3b>
 120e14f:	49 ff cc             	dec    %r12
 120e152:	66 46 89 8c 65 2a f9 	mov    %r9w,-0x6d6(%rbp,%r12,2)
 120e159:	ff ff 
 120e15b:	75 e3                	jne    120e140 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x90>
 120e15d:	eb 89                	jmp    120e0e8 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x38>
 120e15f:	4d 85 e4             	test   %r12,%r12
 120e162:	0f 84 cf 00 00 00    	je     120e237 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x187>
 120e168:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 120e16c:	48 8d bd 2e fc ff ff 	lea    -0x3d2(%rbp),%rdi
 120e173:	48 8d b5 20 f9 ff ff 	lea    -0x6e0(%rbp),%rsi
 120e17a:	48 89 da             	mov    %rbx,%rdx
 120e17d:	e8 9e 70 f6 ff       	call   1175220 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths>
 120e182:	0f b7 85 2e fc ff ff 	movzwl -0x3d2(%rbp),%eax
 120e189:	66 85 c0             	test   %ax,%ax
 120e18c:	0f 85 14 05 00 00    	jne    120e6a6 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x5f6>
 120e192:	c5 fc 10 85 10 fd ff 	vmovups -0x2f0(%rbp),%ymm0
 120e199:	ff 
 120e19a:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 120e1a1:	ff 
 120e1a2:	c5 fc 10 85 f0 fc ff 	vmovups -0x310(%rbp),%ymm0
 120e1a9:	ff 
 120e1aa:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 120e1b1:	ff 
 120e1b2:	c5 fc 10 85 d0 fc ff 	vmovups -0x330(%rbp),%ymm0
 120e1b9:	ff 
 120e1ba:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 120e1c1:	ff 
 120e1c2:	c5 fc 10 85 b0 fc ff 	vmovups -0x350(%rbp),%ymm0
 120e1c9:	ff 
 120e1ca:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 120e1d1:	ff 
 120e1d2:	c5 fc 10 85 30 fc ff 	vmovups -0x3d0(%rbp),%ymm0
 120e1d9:	ff 
 120e1da:	c5 fc 10 8d 70 fc ff 	vmovups -0x390(%rbp),%ymm1
 120e1e1:	ff 
 120e1e2:	c5 fc 10 95 90 fc ff 	vmovups -0x370(%rbp),%ymm2
 120e1e9:	ff 
 120e1ea:	c5 fc 11 95 40 fe ff 	vmovups %ymm2,-0x1c0(%rbp)
 120e1f1:	ff 
 120e1f2:	c5 fc 11 8d 20 fe ff 	vmovups %ymm1,-0x1e0(%rbp)
 120e1f9:	ff 
 120e1fa:	c5 fc 10 8d 50 fc ff 	vmovups -0x3b0(%rbp),%ymm1
 120e201:	ff 
 120e202:	c5 fc 11 8d 00 fe ff 	vmovups %ymm1,-0x200(%rbp)
 120e209:	ff 
 120e20a:	c5 fc 11 85 e0 fd ff 	vmovups %ymm0,-0x220(%rbp)
 120e211:	ff 
 120e212:	66 45 85 ff          	test   %r15w,%r15w
 120e216:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 120e21a:	74 36                	je     120e252 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x1a2>
 120e21c:	45 0f b7 c7          	movzwl %r15w,%r8d
 120e220:	44 89 c2             	mov    %r8d,%edx
 120e223:	83 e2 03             	and    $0x3,%edx
 120e226:	66 41 83 ff 04       	cmp    $0x4,%r15w
 120e22b:	73 37                	jae    120e264 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x1b4>
 120e22d:	31 f6                	xor    %esi,%esi
 120e22f:	45 31 ff             	xor    %r15d,%r15d
 120e232:	e9 c6 00 00 00       	jmp    120e2fd <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x24d>
 120e237:	66 c7 47 08 1f 00    	movw   $0x1f,0x8(%rdi)
 120e23d:	48 81 c4 b8 06 00 00 	add    $0x6b8,%rsp
 120e244:	5b                   	pop    %rbx
 120e245:	41 5c                	pop    %r12
 120e247:	41 5d                	pop    %r13
 120e249:	41 5e                	pop    %r14
 120e24b:	41 5f                	pop    %r15
 120e24d:	5d                   	pop    %rbp
 120e24e:	c5 f8 77             	vzeroupper 
 120e251:	c3                   	ret    
 120e252:	49 83 fc 05          	cmp    $0x5,%r12
 120e256:	0f 83 3d 04 00 00    	jae    120e699 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x5e9>
 120e25c:	45 31 ff             	xor    %r15d,%r15d
 120e25f:	e9 e4 00 00 00       	jmp    120e348 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x298>
 120e264:	44 89 c1             	mov    %r8d,%ecx
 120e267:	83 e1 fc             	and    $0xfffffffc,%ecx
 120e26a:	31 f6                	xor    %esi,%esi
 120e26c:	45 31 ff             	xor    %r15d,%r15d
 120e26f:	90                   	nop
 120e270:	0f b6 bc 35 2e fb ff 	movzbl -0x4d2(%rbp,%rsi,1),%edi
 120e277:	ff 
 120e278:	44 8b 0c bb          	mov    (%rbx,%rdi,4),%r9d
 120e27c:	0f b6 bc 3d e0 fd ff 	movzbl -0x220(%rbp,%rdi,1),%edi
 120e283:	ff 
 120e284:	83 e7 0f             	and    $0xf,%edi
 120e287:	49 0f af f9          	imul   %r9,%rdi
 120e28b:	4c 01 ff             	add    %r15,%rdi
 120e28e:	44 0f b6 8c 35 2f fb 	movzbl -0x4d1(%rbp,%rsi,1),%r9d
 120e295:	ff ff 
 120e297:	46 8b 14 8b          	mov    (%rbx,%r9,4),%r10d
 120e29b:	46 0f b6 8c 0d e0 fd 	movzbl -0x220(%rbp,%r9,1),%r9d
 120e2a2:	ff ff 
 120e2a4:	41 83 e1 0f          	and    $0xf,%r9d
 120e2a8:	4d 0f af ca          	imul   %r10,%r9
 120e2ac:	44 0f b6 94 35 30 fb 	movzbl -0x4d0(%rbp,%rsi,1),%r10d
 120e2b3:	ff ff 
 120e2b5:	46 8b 1c 93          	mov    (%rbx,%r10,4),%r11d
 120e2b9:	46 0f b6 94 15 e0 fd 	movzbl -0x220(%rbp,%r10,1),%r10d
 120e2c0:	ff ff 
 120e2c2:	41 83 e2 0f          	and    $0xf,%r10d
 120e2c6:	4d 0f af d3          	imul   %r11,%r10
 120e2ca:	4d 01 ca             	add    %r9,%r10
 120e2cd:	49 01 fa             	add    %rdi,%r10
 120e2d0:	0f b6 bc 35 31 fb ff 	movzbl -0x4cf(%rbp,%rsi,1),%edi
 120e2d7:	ff 
 120e2d8:	44 8b 0c bb          	mov    (%rbx,%rdi,4),%r9d
 120e2dc:	44 0f b6 bc 3d e0 fd 	movzbl -0x220(%rbp,%rdi,1),%r15d
 120e2e3:	ff ff 
 120e2e5:	41 83 e7 0f          	and    $0xf,%r15d
 120e2e9:	4d 0f af f9          	imul   %r9,%r15
 120e2ed:	4d 01 d7             	add    %r10,%r15
 120e2f0:	48 83 c6 04          	add    $0x4,%rsi
 120e2f4:	48 39 f1             	cmp    %rsi,%rcx
 120e2f7:	0f 85 73 ff ff ff    	jne    120e270 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x1c0>
 120e2fd:	48 85 d2             	test   %rdx,%rdx
 120e300:	74 40                	je     120e342 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x292>
 120e302:	48 8d 8d 2c fb ff ff 	lea    -0x4d4(%rbp),%rcx
 120e309:	48 01 f1             	add    %rsi,%rcx
 120e30c:	48 83 c1 02          	add    $0x2,%rcx
 120e310:	31 f6                	xor    %esi,%esi
 120e312:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e319:	1f 84 00 00 00 00 00 
 120e320:	0f b6 3c 31          	movzbl (%rcx,%rsi,1),%edi
 120e324:	44 8b 0c bb          	mov    (%rbx,%rdi,4),%r9d
 120e328:	0f b6 bc 3d e0 fd ff 	movzbl -0x220(%rbp,%rdi,1),%edi
 120e32f:	ff 
 120e330:	83 e7 0f             	and    $0xf,%edi
 120e333:	49 0f af f9          	imul   %r9,%rdi
 120e337:	49 01 ff             	add    %rdi,%r15
 120e33a:	48 ff c6             	inc    %rsi
 120e33d:	48 39 f2             	cmp    %rsi,%rdx
 120e340:	75 de                	jne    120e320 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x270>
 120e342:	49 83 fc 05          	cmp    $0x5,%r12
 120e346:	73 22                	jae    120e36a <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x2ba>
 120e348:	31 c9                	xor    %ecx,%ecx
 120e34a:	49 83 fc 04          	cmp    $0x4,%r12
 120e34e:	0f 94 c1             	sete   %cl
 120e351:	4a 8d 0c e1          	lea    (%rcx,%r12,8),%rcx
 120e355:	48 83 c1 04          	add    $0x4,%rcx
 120e359:	49 01 cf             	add    %rcx,%r15
 120e35c:	66 c7 40 08 00 00    	movw   $0x0,0x8(%rax)
 120e362:	4c 89 38             	mov    %r15,(%rax)
 120e365:	e9 d3 fe ff ff       	jmp    120e23d <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x18d>
 120e36a:	48 c7 45 a0 02 00 00 	movq   $0x2,-0x60(%rbp)
 120e371:	00 
 120e372:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 120e376:	c5 fc 11 85 70 ff ff 	vmovups %ymm0,-0x90(%rbp)
 120e37d:	ff 
 120e37e:	c5 fc 11 85 60 ff ff 	vmovups %ymm0,-0xa0(%rbp)
 120e385:	ff 
 120e386:	c5 fc 11 85 40 ff ff 	vmovups %ymm0,-0xc0(%rbp)
 120e38d:	ff 
 120e38e:	c5 fc 11 85 20 ff ff 	vmovups %ymm0,-0xe0(%rbp)
 120e395:	ff 
 120e396:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 120e39d:	ff 
 120e39e:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 120e3a5:	ff 
 120e3a6:	4c 89 c0             	mov    %r8,%rax
 120e3a9:	48 f7 d8             	neg    %rax
 120e3ac:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 120e3b0:	48 c7 45 c0 00 00 00 	movq   $0x0,-0x40(%rbp)
 120e3b7:	00 
 120e3b8:	48 c7 45 b8 00 00 00 	movq   $0x0,-0x48(%rbp)
 120e3bf:	00 
 120e3c0:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%rbp)
 120e3c7:	48 c7 45 b0 00 00 00 	movq   $0x0,-0x50(%rbp)
 120e3ce:	00 
 120e3cf:	c7 45 d0 00 00 00 00 	movl   $0x0,-0x30(%rbp)
 120e3d6:	31 ff                	xor    %edi,%edi
 120e3d8:	45 31 c9             	xor    %r9d,%r9d
 120e3db:	45 31 ed             	xor    %r13d,%r13d
 120e3de:	44 0f b6 b4 3d 2e fb 	movzbl -0x4d2(%rbp,%rdi,1),%r14d
 120e3e5:	ff ff 
 120e3e7:	4d 39 ce             	cmp    %r9,%r14
 120e3ea:	0f 82 98 02 00 00    	jb     120e688 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x5d8>
 120e3f0:	42 0f b6 94 35 e0 fd 	movzbl -0x220(%rbp,%r14,1),%edx
 120e3f7:	ff ff 
 120e3f9:	48 89 d6             	mov    %rdx,%rsi
 120e3fc:	48 83 e6 0f          	and    $0xf,%rsi
 120e400:	0f 84 82 02 00 00    	je     120e688 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x5d8>
 120e406:	4c 89 f1             	mov    %r14,%rcx
 120e409:	4c 29 c9             	sub    %r9,%rcx
 120e40c:	76 17                	jbe    120e425 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x375>
 120e40e:	48 83 f9 02          	cmp    $0x2,%rcx
 120e412:	0f 87 91 00 00 00    	ja     120e4a9 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x3f9>
 120e418:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 120e41c:	01 c8                	add    %ecx,%eax
 120e41e:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 120e422:	49 01 cd             	add    %rcx,%r13
 120e425:	48 8d 5f 01          	lea    0x1(%rdi),%rbx
 120e429:	41 b9 01 00 00 00    	mov    $0x1,%r9d
 120e42f:	4c 39 c3             	cmp    %r8,%rbx
 120e432:	0f 83 d7 00 00 00    	jae    120e50f <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x45f>
 120e438:	4d 89 c1             	mov    %r8,%r9
 120e43b:	49 29 f9             	sub    %rdi,%r9
 120e43e:	48 8d 85 2f fb ff ff 	lea    -0x4d1(%rbp),%rax
 120e445:	48 01 c7             	add    %rax,%rdi
 120e448:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 120e44c:	4c 8d 1c 18          	lea    (%rax,%rbx,1),%r11
 120e450:	80 e2 0f             	and    $0xf,%dl
 120e453:	31 c9                	xor    %ecx,%ecx
 120e455:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120e45c:	00 00 00 00 
 120e460:	44 0f b6 24 0f       	movzbl (%rdi,%rcx,1),%r12d
 120e465:	4d 39 e6             	cmp    %r12,%r14
 120e468:	0f 83 1a 02 00 00    	jae    120e688 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x5d8>
 120e46e:	46 0f b6 94 25 e0 fd 	movzbl -0x220(%rbp,%r12,1),%r10d
 120e475:	ff ff 
 120e477:	41 f6 c2 0f          	test   $0xf,%r10b
 120e47b:	0f 84 07 02 00 00    	je     120e688 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x5d8>
 120e481:	49 8d 46 01          	lea    0x1(%r14),%rax
 120e485:	4c 39 e0             	cmp    %r12,%rax
 120e488:	75 7c                	jne    120e506 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x456>
 120e48a:	41 80 e2 0f          	and    $0xf,%r10b
 120e48e:	41 38 d2             	cmp    %dl,%r10b
 120e491:	75 73                	jne    120e506 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x456>
 120e493:	48 ff c1             	inc    %rcx
 120e496:	4c 89 d8             	mov    %r11,%rax
 120e499:	4d 89 e6             	mov    %r12,%r14
 120e49c:	48 01 c8             	add    %rcx,%rax
 120e49f:	75 bf                	jne    120e460 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x3b0>
 120e4a1:	4d 89 e6             	mov    %r12,%r14
 120e4a4:	4c 89 c7             	mov    %r8,%rdi
 120e4a7:	eb 69                	jmp    120e512 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x462>
 120e4a9:	41 b9 01 00 00 00    	mov    $0x1,%r9d
 120e4af:	83 f9 0b             	cmp    $0xb,%ecx
 120e4b2:	72 32                	jb     120e4e6 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x436>
 120e4b4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e4bb:	00 00 00 00 00 
 120e4c0:	44 8d 51 05          	lea    0x5(%rcx),%r10d
 120e4c4:	41 83 e2 07          	and    $0x7,%r10d
 120e4c8:	4c 29 d1             	sub    %r10,%rcx
 120e4cb:	48 83 c1 fd          	add    $0xfffffffffffffffd,%rcx
 120e4cf:	49 89 ca             	mov    %rcx,%r10
 120e4d2:	49 c1 ea 03          	shr    $0x3,%r10
 120e4d6:	49 83 c2 02          	add    $0x2,%r10
 120e4da:	49 ff c1             	inc    %r9
 120e4dd:	48 83 f9 47          	cmp    $0x47,%rcx
 120e4e1:	4c 89 d1             	mov    %r10,%rcx
 120e4e4:	77 da                	ja     120e4c0 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x410>
 120e4e6:	44 01 4d d0          	add    %r9d,-0x30(%rbp)
 120e4ea:	4d 01 cd             	add    %r9,%r13
 120e4ed:	4c 01 4d b0          	add    %r9,-0x50(%rbp)
 120e4f1:	48 8d 5f 01          	lea    0x1(%rdi),%rbx
 120e4f5:	41 b9 01 00 00 00    	mov    $0x1,%r9d
 120e4fb:	4c 39 c3             	cmp    %r8,%rbx
 120e4fe:	0f 82 34 ff ff ff    	jb     120e438 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x388>
 120e504:	eb 09                	jmp    120e50f <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x45f>
 120e506:	48 01 cb             	add    %rcx,%rbx
 120e509:	48 ff c1             	inc    %rcx
 120e50c:	49 89 c9             	mov    %rcx,%r9
 120e50f:	48 89 df             	mov    %rbx,%rdi
 120e512:	8b 8c b5 48 ff ff ff 	mov    -0xb8(%rbp,%rsi,4),%ecx
 120e519:	ff c1                	inc    %ecx
 120e51b:	89 8c b5 48 ff ff ff 	mov    %ecx,-0xb8(%rbp,%rsi,4)
 120e522:	49 8d 55 01          	lea    0x1(%r13),%rdx
 120e526:	49 83 f9 02          	cmp    $0x2,%r9
 120e52a:	72 62                	jb     120e58e <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x4de>
 120e52c:	49 8d 59 ff          	lea    -0x1(%r9),%rbx
 120e530:	49 83 f9 03          	cmp    $0x3,%r9
 120e534:	77 1d                	ja     120e553 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x4a3>
 120e536:	01 d9                	add    %ebx,%ecx
 120e538:	89 8c b5 48 ff ff ff 	mov    %ecx,-0xb8(%rbp,%rsi,4)
 120e53f:	4d 01 cd             	add    %r9,%r13
 120e542:	49 ff c6             	inc    %r14
 120e545:	4d 89 f1             	mov    %r14,%r9
 120e548:	4c 39 c7             	cmp    %r8,%rdi
 120e54b:	0f 82 8d fe ff ff    	jb     120e3de <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x32e>
 120e551:	eb 4d                	jmp    120e5a0 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x4f0>
 120e553:	b9 01 00 00 00       	mov    $0x1,%ecx
 120e558:	48 83 fb 07          	cmp    $0x7,%rbx
 120e55c:	72 26                	jb     120e584 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x4d4>
 120e55e:	66 90                	xchg   %ax,%ax
 120e560:	8d 73 01             	lea    0x1(%rbx),%esi
 120e563:	83 e6 03             	and    $0x3,%esi
 120e566:	48 29 f3             	sub    %rsi,%rbx
 120e569:	48 83 c3 fd          	add    $0xfffffffffffffffd,%rbx
 120e56d:	48 89 de             	mov    %rbx,%rsi
 120e570:	48 c1 ee 02          	shr    $0x2,%rsi
 120e574:	48 83 c6 02          	add    $0x2,%rsi
 120e578:	48 ff c1             	inc    %rcx
 120e57b:	48 83 fb 13          	cmp    $0x13,%rbx
 120e57f:	48 89 f3             	mov    %rsi,%rbx
 120e582:	77 dc                	ja     120e560 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x4b0>
 120e584:	01 4d d4             	add    %ecx,-0x2c(%rbp)
 120e587:	48 01 ca             	add    %rcx,%rdx
 120e58a:	48 01 4d b8          	add    %rcx,-0x48(%rbp)
 120e58e:	49 89 d5             	mov    %rdx,%r13
 120e591:	49 ff c6             	inc    %r14
 120e594:	4d 89 f1             	mov    %r14,%r9
 120e597:	4c 39 c7             	cmp    %r8,%rdi
 120e59a:	0f 82 3e fe ff ff    	jb     120e3de <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x32e>
 120e5a0:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 120e5a4:	89 85 48 ff ff ff    	mov    %eax,-0xb8(%rbp)
 120e5aa:	8b 45 d0             	mov    -0x30(%rbp),%eax
 120e5ad:	89 45 8c             	mov    %eax,-0x74(%rbp)
 120e5b0:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 120e5b4:	48 89 85 f0 fe ff ff 	mov    %rax,-0x110(%rbp)
 120e5bb:	8b 45 d4             	mov    -0x2c(%rbp),%eax
 120e5be:	89 45 88             	mov    %eax,-0x78(%rbp)
 120e5c1:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 120e5c5:	48 89 85 e8 fe ff ff 	mov    %rax,-0x118(%rbp)
 120e5cc:	4c 89 ad e0 fe ff ff 	mov    %r13,-0x120(%rbp)
 120e5d3:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 120e5da:	ff 
 120e5db:	c5 fc 10 8d 20 ff ff 	vmovups -0xe0(%rbp),%ymm1
 120e5e2:	ff 
 120e5e3:	c5 fc 10 95 60 ff ff 	vmovups -0xa0(%rbp),%ymm2
 120e5ea:	ff 
 120e5eb:	c5 fc 11 85 50 fd ff 	vmovups %ymm0,-0x2b0(%rbp)
 120e5f2:	ff 
 120e5f3:	c5 fc 11 8d 70 fd ff 	vmovups %ymm1,-0x290(%rbp)
 120e5fa:	ff 
 120e5fb:	c5 fc 11 95 b0 fd ff 	vmovups %ymm2,-0x250(%rbp)
 120e602:	ff 
 120e603:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 120e60a:	48 89 85 30 fd ff ff 	mov    %rax,-0x2d0(%rbp)
 120e611:	48 8b 85 e8 fe ff ff 	mov    -0x118(%rbp),%rax
 120e618:	48 89 85 38 fd ff ff 	mov    %rax,-0x2c8(%rbp)
 120e61f:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 120e626:	48 89 85 40 fd ff ff 	mov    %rax,-0x2c0(%rbp)
 120e62d:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 120e634:	48 89 85 48 fd ff ff 	mov    %rax,-0x2b8(%rbp)
 120e63b:	c5 fc 10 85 40 ff ff 	vmovups -0xc0(%rbp),%ymm0
 120e642:	ff 
 120e643:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 120e64a:	ff 
 120e64b:	c5 fc 10 85 70 ff ff 	vmovups -0x90(%rbp),%ymm0
 120e652:	ff 
 120e653:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 120e65a:	ff 
 120e65b:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 120e65f:	48 8d 75 a0          	lea    -0x60(%rbp),%rsi
 120e663:	48 8d 95 30 fd ff ff 	lea    -0x2d0(%rbp),%rdx
 120e66a:	c5 f8 77             	vzeroupper 
 120e66d:	e8 5e 8d f6 ff       	call   11773d0 <br.encoder.complex_prefix.finishBitCost__anon_36316>
 120e672:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 120e676:	0f b7 4d 98          	movzwl -0x68(%rbp),%ecx
 120e67a:	66 85 c9             	test   %cx,%cx
 120e67d:	75 1e                	jne    120e69d <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x5ed>
 120e67f:	48 8b 4d 90          	mov    -0x70(%rbp),%rcx
 120e683:	e9 d1 fc ff ff       	jmp    120e359 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x2a9>
 120e688:	66 b9 1f 00          	mov    $0x1f,%cx
 120e68c:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 120e690:	66 89 48 08          	mov    %cx,0x8(%rax)
 120e694:	e9 a4 fb ff ff       	jmp    120e23d <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x18d>
 120e699:	66 b9 1f 00          	mov    $0x1f,%cx
 120e69d:	66 89 48 08          	mov    %cx,0x8(%rax)
 120e6a1:	e9 97 fb ff ff       	jmp    120e23d <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x18d>
 120e6a6:	48 8b 4d c8          	mov    -0x38(%rbp),%rcx
 120e6aa:	66 89 41 08          	mov    %ax,0x8(%rcx)
 120e6ae:	e9 8a fb ff ff       	jmp    120e23d <br.encoder.literal_context_split.treeBitCostProfiled__anon_46141+0x18d>

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
