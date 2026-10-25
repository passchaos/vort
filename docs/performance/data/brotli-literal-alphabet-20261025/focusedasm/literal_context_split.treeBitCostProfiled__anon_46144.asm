
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/1928ccf0f65566cb15f468f5a8857ce6/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120e0e0 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144>:
 120e0e0:	55                   	push   %rbp
 120e0e1:	48 89 e5             	mov    %rsp,%rbp
 120e0e4:	41 57                	push   %r15
 120e0e6:	41 56                	push   %r14
 120e0e8:	41 55                	push   %r13
 120e0ea:	41 54                	push   %r12
 120e0ec:	53                   	push   %rbx
 120e0ed:	48 81 ec b8 06 00 00 	sub    $0x6b8,%rsp
 120e0f4:	49 89 f6             	mov    %rsi,%r14
 120e0f7:	48 89 fb             	mov    %rdi,%rbx
 120e0fa:	44 0f b7 0a          	movzwl (%rdx),%r9d
 120e0fe:	48 83 c2 02          	add    $0x2,%rdx
 120e102:	49 83 f9 3f          	cmp    $0x3f,%r9
 120e106:	0f 87 93 00 00 00    	ja     120e19f <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0xbf>
 120e10c:	48 c7 85 20 f9 ff ff 	movq   $0x0,-0x6e0(%rbp)
 120e113:	00 00 00 00 
 120e117:	66 b8 1f 00          	mov    $0x1f,%ax
 120e11b:	4d 85 c9             	test   %r9,%r9
 120e11e:	0f 84 e3 05 00 00    	je     120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e124:	31 c9                	xor    %ecx,%ecx
 120e126:	31 f6                	xor    %esi,%esi
 120e128:	31 ff                	xor    %edi,%edi
 120e12a:	eb 26                	jmp    120e152 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x72>
 120e12c:	31 c9                	xor    %ecx,%ecx
 120e12e:	ff c6                	inc    %esi
 120e130:	66 44 89 84 4d 28 f9 	mov    %r8w,-0x6d8(%rbp,%rcx,2)
 120e137:	ff ff 
 120e139:	48 8b 8d 20 f9 ff ff 	mov    -0x6e0(%rbp),%rcx
 120e140:	48 ff c1             	inc    %rcx
 120e143:	48 89 8d 20 f9 ff ff 	mov    %rcx,-0x6e0(%rbp)
 120e14a:	48 ff c7             	inc    %rdi
 120e14d:	4c 39 cf             	cmp    %r9,%rdi
 120e150:	74 73                	je     120e1c5 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0xe5>
 120e152:	44 0f b6 04 3a       	movzbl (%rdx,%rdi,1),%r8d
 120e157:	47 8b 14 86          	mov    (%r14,%r8,4),%r10d
 120e15b:	45 85 d2             	test   %r10d,%r10d
 120e15e:	74 ea                	je     120e14a <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x6a>
 120e160:	44 0f b7 de          	movzwl %si,%r11d
 120e164:	46 88 84 1d 30 fc ff 	mov    %r8b,-0x3d0(%rbp,%r11,1)
 120e16b:	ff 
 120e16c:	48 85 c9             	test   %rcx,%rcx
 120e16f:	74 bd                	je     120e12e <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x4e>
 120e171:	48 81 f9 00 01 00 00 	cmp    $0x100,%rcx
 120e178:	0f 84 89 05 00 00    	je     120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e17e:	66 90                	xchg   %ax,%ax
 120e180:	44 0f b7 9c 4d 26 f9 	movzwl -0x6da(%rbp,%rcx,2),%r11d
 120e187:	ff ff 
 120e189:	47 3b 14 9e          	cmp    (%r14,%r11,4),%r10d
 120e18d:	76 9f                	jbe    120e12e <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x4e>
 120e18f:	48 ff c9             	dec    %rcx
 120e192:	66 44 89 9c 4d 2a f9 	mov    %r11w,-0x6d6(%rbp,%rcx,2)
 120e199:	ff ff 
 120e19b:	75 e3                	jne    120e180 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0xa0>
 120e19d:	eb 8d                	jmp    120e12c <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x4c>
 120e19f:	48 8d 8d 20 f9 ff ff 	lea    -0x6e0(%rbp),%rcx
 120e1a6:	4c 8d 85 2e fc ff ff 	lea    -0x3d2(%rbp),%r8
 120e1ad:	4c 89 f7             	mov    %r14,%rdi
 120e1b0:	48 89 d6             	mov    %rdx,%rsi
 120e1b3:	4c 89 ca             	mov    %r9,%rdx
 120e1b6:	e8 25 50 00 00       	call   12131e0 <br.encoder.literal_alphabet.buildLargeSupport__anon_72625>
 120e1bb:	66 85 c0             	test   %ax,%ax
 120e1be:	74 15                	je     120e1d5 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0xf5>
 120e1c0:	e9 42 05 00 00       	jmp    120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e1c5:	66 89 b5 2e fc ff ff 	mov    %si,-0x3d2(%rbp)
 120e1cc:	48 85 c9             	test   %rcx,%rcx
 120e1cf:	0f 84 32 05 00 00    	je     120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e1d5:	48 8d bd 2c fb ff ff 	lea    -0x4d4(%rbp),%rdi
 120e1dc:	48 8d b5 20 f9 ff ff 	lea    -0x6e0(%rbp),%rsi
 120e1e3:	4c 89 f2             	mov    %r14,%rdx
 120e1e6:	e8 65 70 f6 ff       	call   1175250 <br.encoder.command_plan.PrefixAlphabetFor(256).codeLengths>
 120e1eb:	0f b7 85 2c fb ff ff 	movzwl -0x4d4(%rbp),%eax
 120e1f2:	66 85 c0             	test   %ax,%ax
 120e1f5:	0f 85 0c 05 00 00    	jne    120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e1fb:	c5 fc 10 85 0e fc ff 	vmovups -0x3f2(%rbp),%ymm0
 120e202:	ff 
 120e203:	c5 fc 11 85 c0 fe ff 	vmovups %ymm0,-0x140(%rbp)
 120e20a:	ff 
 120e20b:	c5 fc 10 85 ee fb ff 	vmovups -0x412(%rbp),%ymm0
 120e212:	ff 
 120e213:	c5 fc 11 85 a0 fe ff 	vmovups %ymm0,-0x160(%rbp)
 120e21a:	ff 
 120e21b:	c5 fc 10 85 ce fb ff 	vmovups -0x432(%rbp),%ymm0
 120e222:	ff 
 120e223:	c5 fc 11 85 80 fe ff 	vmovups %ymm0,-0x180(%rbp)
 120e22a:	ff 
 120e22b:	c5 fc 10 85 ae fb ff 	vmovups -0x452(%rbp),%ymm0
 120e232:	ff 
 120e233:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 120e23a:	ff 
 120e23b:	c5 fc 10 85 2e fb ff 	vmovups -0x4d2(%rbp),%ymm0
 120e242:	ff 
 120e243:	c5 fc 10 8d 4e fb ff 	vmovups -0x4b2(%rbp),%ymm1
 120e24a:	ff 
 120e24b:	c5 fc 10 95 6e fb ff 	vmovups -0x492(%rbp),%ymm2
 120e252:	ff 
 120e253:	c5 fc 10 9d 8e fb ff 	vmovups -0x472(%rbp),%ymm3
 120e25a:	ff 
 120e25b:	c5 fc 11 9d 40 fe ff 	vmovups %ymm3,-0x1c0(%rbp)
 120e262:	ff 
 120e263:	c5 fc 11 95 20 fe ff 	vmovups %ymm2,-0x1e0(%rbp)
 120e26a:	ff 
 120e26b:	c5 fc 11 8d 00 fe ff 	vmovups %ymm1,-0x200(%rbp)
 120e272:	ff 
 120e273:	c5 fc 11 85 e0 fd ff 	vmovups %ymm0,-0x220(%rbp)
 120e27a:	ff 
 120e27b:	0f b7 bd 2e fc ff ff 	movzwl -0x3d2(%rbp),%edi
 120e282:	48 85 ff             	test   %rdi,%rdi
 120e285:	74 15                	je     120e29c <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x1bc>
 120e287:	89 f9                	mov    %edi,%ecx
 120e289:	83 e1 03             	and    $0x3,%ecx
 120e28c:	66 83 ff 04          	cmp    $0x4,%di
 120e290:	73 23                	jae    120e2b5 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x1d5>
 120e292:	31 d2                	xor    %edx,%edx
 120e294:	45 31 ff             	xor    %r15d,%r15d
 120e297:	e9 b1 00 00 00       	jmp    120e34d <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x26d>
 120e29c:	48 8b 85 20 f9 ff ff 	mov    -0x6e0(%rbp),%rax
 120e2a3:	48 83 f8 05          	cmp    $0x5,%rax
 120e2a7:	0f 83 56 04 00 00    	jae    120e703 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x623>
 120e2ad:	45 31 ff             	xor    %r15d,%r15d
 120e2b0:	e9 ea 00 00 00       	jmp    120e39f <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x2bf>
 120e2b5:	89 f8                	mov    %edi,%eax
 120e2b7:	83 e0 fc             	and    $0xfffffffc,%eax
 120e2ba:	31 d2                	xor    %edx,%edx
 120e2bc:	45 31 ff             	xor    %r15d,%r15d
 120e2bf:	90                   	nop
 120e2c0:	0f b6 b4 15 30 fc ff 	movzbl -0x3d0(%rbp,%rdx,1),%esi
 120e2c7:	ff 
 120e2c8:	45 8b 04 b6          	mov    (%r14,%rsi,4),%r8d
 120e2cc:	0f b6 b4 35 e0 fd ff 	movzbl -0x220(%rbp,%rsi,1),%esi
 120e2d3:	ff 
 120e2d4:	83 e6 0f             	and    $0xf,%esi
 120e2d7:	49 0f af f0          	imul   %r8,%rsi
 120e2db:	4c 01 fe             	add    %r15,%rsi
 120e2de:	44 0f b6 84 15 31 fc 	movzbl -0x3cf(%rbp,%rdx,1),%r8d
 120e2e5:	ff ff 
 120e2e7:	47 8b 0c 86          	mov    (%r14,%r8,4),%r9d
 120e2eb:	46 0f b6 84 05 e0 fd 	movzbl -0x220(%rbp,%r8,1),%r8d
 120e2f2:	ff ff 
 120e2f4:	41 83 e0 0f          	and    $0xf,%r8d
 120e2f8:	4d 0f af c1          	imul   %r9,%r8
 120e2fc:	44 0f b6 8c 15 32 fc 	movzbl -0x3ce(%rbp,%rdx,1),%r9d
 120e303:	ff ff 
 120e305:	47 8b 14 8e          	mov    (%r14,%r9,4),%r10d
 120e309:	46 0f b6 8c 0d e0 fd 	movzbl -0x220(%rbp,%r9,1),%r9d
 120e310:	ff ff 
 120e312:	41 83 e1 0f          	and    $0xf,%r9d
 120e316:	4d 0f af ca          	imul   %r10,%r9
 120e31a:	4d 01 c1             	add    %r8,%r9
 120e31d:	49 01 f1             	add    %rsi,%r9
 120e320:	0f b6 b4 15 33 fc ff 	movzbl -0x3cd(%rbp,%rdx,1),%esi
 120e327:	ff 
 120e328:	45 8b 04 b6          	mov    (%r14,%rsi,4),%r8d
 120e32c:	44 0f b6 bc 35 e0 fd 	movzbl -0x220(%rbp,%rsi,1),%r15d
 120e333:	ff ff 
 120e335:	41 83 e7 0f          	and    $0xf,%r15d
 120e339:	4d 0f af f8          	imul   %r8,%r15
 120e33d:	4d 01 cf             	add    %r9,%r15
 120e340:	48 83 c2 04          	add    $0x4,%rdx
 120e344:	48 39 d0             	cmp    %rdx,%rax
 120e347:	0f 85 73 ff ff ff    	jne    120e2c0 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x1e0>
 120e34d:	48 85 c9             	test   %rcx,%rcx
 120e350:	74 40                	je     120e392 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x2b2>
 120e352:	48 8d 85 2e fc ff ff 	lea    -0x3d2(%rbp),%rax
 120e359:	48 01 d0             	add    %rdx,%rax
 120e35c:	48 83 c0 02          	add    $0x2,%rax
 120e360:	31 d2                	xor    %edx,%edx
 120e362:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e369:	1f 84 00 00 00 00 00 
 120e370:	0f b6 34 10          	movzbl (%rax,%rdx,1),%esi
 120e374:	45 8b 04 b6          	mov    (%r14,%rsi,4),%r8d
 120e378:	0f b6 b4 35 e0 fd ff 	movzbl -0x220(%rbp,%rsi,1),%esi
 120e37f:	ff 
 120e380:	83 e6 0f             	and    $0xf,%esi
 120e383:	49 0f af f0          	imul   %r8,%rsi
 120e387:	49 01 f7             	add    %rsi,%r15
 120e38a:	48 ff c2             	inc    %rdx
 120e38d:	48 39 d1             	cmp    %rdx,%rcx
 120e390:	75 de                	jne    120e370 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x290>
 120e392:	48 8b 85 20 f9 ff ff 	mov    -0x6e0(%rbp),%rax
 120e399:	48 83 f8 05          	cmp    $0x5,%rax
 120e39d:	73 22                	jae    120e3c1 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x2e1>
 120e39f:	31 c9                	xor    %ecx,%ecx
 120e3a1:	48 83 f8 04          	cmp    $0x4,%rax
 120e3a5:	0f 94 c1             	sete   %cl
 120e3a8:	48 8d 04 c1          	lea    (%rcx,%rax,8),%rax
 120e3ac:	48 83 c0 04          	add    $0x4,%rax
 120e3b0:	49 01 c7             	add    %rax,%r15
 120e3b3:	66 c7 43 08 00 00    	movw   $0x0,0x8(%rbx)
 120e3b9:	4c 89 3b             	mov    %r15,(%rbx)
 120e3bc:	e9 4a 03 00 00       	jmp    120e70b <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x62b>
 120e3c1:	48 89 5d b0          	mov    %rbx,-0x50(%rbp)
 120e3c5:	48 c7 45 a0 02 00 00 	movq   $0x2,-0x60(%rbp)
 120e3cc:	00 
 120e3cd:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 120e3d1:	c5 fc 11 85 70 ff ff 	vmovups %ymm0,-0x90(%rbp)
 120e3d8:	ff 
 120e3d9:	c5 fc 11 85 60 ff ff 	vmovups %ymm0,-0xa0(%rbp)
 120e3e0:	ff 
 120e3e1:	c5 fc 11 85 40 ff ff 	vmovups %ymm0,-0xc0(%rbp)
 120e3e8:	ff 
 120e3e9:	c5 fc 11 85 20 ff ff 	vmovups %ymm0,-0xe0(%rbp)
 120e3f0:	ff 
 120e3f1:	c5 fc 11 85 00 ff ff 	vmovups %ymm0,-0x100(%rbp)
 120e3f8:	ff 
 120e3f9:	c5 fc 11 85 e0 fe ff 	vmovups %ymm0,-0x120(%rbp)
 120e400:	ff 
 120e401:	48 89 f8             	mov    %rdi,%rax
 120e404:	48 f7 d8             	neg    %rax
 120e407:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 120e40b:	48 c7 45 c8 00 00 00 	movq   $0x0,-0x38(%rbp)
 120e412:	00 
 120e413:	48 c7 45 c0 00 00 00 	movq   $0x0,-0x40(%rbp)
 120e41a:	00 
 120e41b:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%rbp)
 120e422:	48 c7 45 b8 00 00 00 	movq   $0x0,-0x48(%rbp)
 120e429:	00 
 120e42a:	c7 45 d0 00 00 00 00 	movl   $0x0,-0x30(%rbp)
 120e431:	31 f6                	xor    %esi,%esi
 120e433:	45 31 c0             	xor    %r8d,%r8d
 120e436:	45 31 e4             	xor    %r12d,%r12d
 120e439:	44 0f b6 94 35 30 fc 	movzbl -0x3d0(%rbp,%rsi,1),%r10d
 120e440:	ff ff 
 120e442:	4d 39 c2             	cmp    %r8,%r10
 120e445:	0f 82 ae 02 00 00    	jb     120e6f9 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x619>
 120e44b:	46 0f b6 ac 15 e0 fd 	movzbl -0x220(%rbp,%r10,1),%r13d
 120e452:	ff ff 
 120e454:	4c 89 e9             	mov    %r13,%rcx
 120e457:	48 83 e1 0f          	and    $0xf,%rcx
 120e45b:	0f 84 98 02 00 00    	je     120e6f9 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x619>
 120e461:	4c 89 d0             	mov    %r10,%rax
 120e464:	4c 29 c0             	sub    %r8,%rax
 120e467:	76 17                	jbe    120e480 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x3a0>
 120e469:	48 83 f8 02          	cmp    $0x2,%rax
 120e46d:	0f 87 94 00 00 00    	ja     120e507 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x427>
 120e473:	48 8b 55 c8          	mov    -0x38(%rbp),%rdx
 120e477:	01 c2                	add    %eax,%edx
 120e479:	48 89 55 c8          	mov    %rdx,-0x38(%rbp)
 120e47d:	49 01 c4             	add    %rax,%r12
 120e480:	4c 8d 5e 01          	lea    0x1(%rsi),%r11
 120e484:	41 b8 01 00 00 00    	mov    $0x1,%r8d
 120e48a:	49 39 fb             	cmp    %rdi,%r11
 120e48d:	0f 83 dd 00 00 00    	jae    120e570 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x490>
 120e493:	49 89 f8             	mov    %rdi,%r8
 120e496:	49 29 f0             	sub    %rsi,%r8
 120e499:	48 8d 85 31 fc ff ff 	lea    -0x3cf(%rbp),%rax
 120e4a0:	48 01 c6             	add    %rax,%rsi
 120e4a3:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 120e4a7:	4e 8d 0c 18          	lea    (%rax,%r11,1),%r9
 120e4ab:	41 80 e5 0f          	and    $0xf,%r13b
 120e4af:	31 c0                	xor    %eax,%eax
 120e4b1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e4b8:	0f 1f 84 00 00 00 00 
 120e4bf:	00 
 120e4c0:	44 0f b6 34 06       	movzbl (%rsi,%rax,1),%r14d
 120e4c5:	4d 39 f2             	cmp    %r14,%r10
 120e4c8:	0f 83 2b 02 00 00    	jae    120e6f9 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x619>
 120e4ce:	42 0f b6 94 35 e0 fd 	movzbl -0x220(%rbp,%r14,1),%edx
 120e4d5:	ff ff 
 120e4d7:	f6 c2 0f             	test   $0xf,%dl
 120e4da:	0f 84 19 02 00 00    	je     120e6f9 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x619>
 120e4e0:	49 8d 5a 01          	lea    0x1(%r10),%rbx
 120e4e4:	4c 39 f3             	cmp    %r14,%rbx
 120e4e7:	75 7b                	jne    120e564 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x484>
 120e4e9:	80 e2 0f             	and    $0xf,%dl
 120e4ec:	44 38 ea             	cmp    %r13b,%dl
 120e4ef:	75 73                	jne    120e564 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x484>
 120e4f1:	48 ff c0             	inc    %rax
 120e4f4:	4c 89 ca             	mov    %r9,%rdx
 120e4f7:	4d 89 f2             	mov    %r14,%r10
 120e4fa:	48 01 c2             	add    %rax,%rdx
 120e4fd:	75 c1                	jne    120e4c0 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x3e0>
 120e4ff:	4d 89 f2             	mov    %r14,%r10
 120e502:	48 89 fe             	mov    %rdi,%rsi
 120e505:	eb 6c                	jmp    120e573 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x493>
 120e507:	41 b8 01 00 00 00    	mov    $0x1,%r8d
 120e50d:	83 f8 0b             	cmp    $0xb,%eax
 120e510:	72 32                	jb     120e544 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x464>
 120e512:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e519:	1f 84 00 00 00 00 00 
 120e520:	8d 50 05             	lea    0x5(%rax),%edx
 120e523:	83 e2 07             	and    $0x7,%edx
 120e526:	48 29 d0             	sub    %rdx,%rax
 120e529:	48 83 c0 fd          	add    $0xfffffffffffffffd,%rax
 120e52d:	48 89 c2             	mov    %rax,%rdx
 120e530:	48 c1 ea 03          	shr    $0x3,%rdx
 120e534:	48 83 c2 02          	add    $0x2,%rdx
 120e538:	49 ff c0             	inc    %r8
 120e53b:	48 83 f8 47          	cmp    $0x47,%rax
 120e53f:	48 89 d0             	mov    %rdx,%rax
 120e542:	77 dc                	ja     120e520 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x440>
 120e544:	44 01 45 d0          	add    %r8d,-0x30(%rbp)
 120e548:	4d 01 c4             	add    %r8,%r12
 120e54b:	4c 01 45 b8          	add    %r8,-0x48(%rbp)
 120e54f:	4c 8d 5e 01          	lea    0x1(%rsi),%r11
 120e553:	41 b8 01 00 00 00    	mov    $0x1,%r8d
 120e559:	49 39 fb             	cmp    %rdi,%r11
 120e55c:	0f 82 31 ff ff ff    	jb     120e493 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x3b3>
 120e562:	eb 0c                	jmp    120e570 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x490>
 120e564:	49 01 c3             	add    %rax,%r11
 120e567:	48 ff c0             	inc    %rax
 120e56a:	49 89 c0             	mov    %rax,%r8
 120e56d:	0f 1f 00             	nopl   (%rax)
 120e570:	4c 89 de             	mov    %r11,%rsi
 120e573:	8b 84 8d 48 ff ff ff 	mov    -0xb8(%rbp,%rcx,4),%eax
 120e57a:	ff c0                	inc    %eax
 120e57c:	89 84 8d 48 ff ff ff 	mov    %eax,-0xb8(%rbp,%rcx,4)
 120e583:	4d 8d 5c 24 01       	lea    0x1(%r12),%r11
 120e588:	49 83 f8 02          	cmp    $0x2,%r8
 120e58c:	72 71                	jb     120e5ff <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x51f>
 120e58e:	4d 8d 68 ff          	lea    -0x1(%r8),%r13
 120e592:	49 83 f8 03          	cmp    $0x3,%r8
 120e596:	77 1e                	ja     120e5b6 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x4d6>
 120e598:	44 01 e8             	add    %r13d,%eax
 120e59b:	89 84 8d 48 ff ff ff 	mov    %eax,-0xb8(%rbp,%rcx,4)
 120e5a2:	4d 01 c4             	add    %r8,%r12
 120e5a5:	49 ff c2             	inc    %r10
 120e5a8:	4d 89 d0             	mov    %r10,%r8
 120e5ab:	48 39 fe             	cmp    %rdi,%rsi
 120e5ae:	0f 82 85 fe ff ff    	jb     120e439 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x359>
 120e5b4:	eb 5b                	jmp    120e611 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x531>
 120e5b6:	b8 01 00 00 00       	mov    $0x1,%eax
 120e5bb:	49 83 fd 07          	cmp    $0x7,%r13
 120e5bf:	72 34                	jb     120e5f5 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x515>
 120e5c1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e5c8:	0f 1f 84 00 00 00 00 
 120e5cf:	00 
 120e5d0:	41 8d 4d 01          	lea    0x1(%r13),%ecx
 120e5d4:	83 e1 03             	and    $0x3,%ecx
 120e5d7:	49 29 cd             	sub    %rcx,%r13
 120e5da:	49 83 c5 fd          	add    $0xfffffffffffffffd,%r13
 120e5de:	4c 89 e9             	mov    %r13,%rcx
 120e5e1:	48 c1 e9 02          	shr    $0x2,%rcx
 120e5e5:	48 83 c1 02          	add    $0x2,%rcx
 120e5e9:	48 ff c0             	inc    %rax
 120e5ec:	49 83 fd 13          	cmp    $0x13,%r13
 120e5f0:	49 89 cd             	mov    %rcx,%r13
 120e5f3:	77 db                	ja     120e5d0 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x4f0>
 120e5f5:	01 45 d4             	add    %eax,-0x2c(%rbp)
 120e5f8:	49 01 c3             	add    %rax,%r11
 120e5fb:	48 01 45 c0          	add    %rax,-0x40(%rbp)
 120e5ff:	4d 89 dc             	mov    %r11,%r12
 120e602:	49 ff c2             	inc    %r10
 120e605:	4d 89 d0             	mov    %r10,%r8
 120e608:	48 39 fe             	cmp    %rdi,%rsi
 120e60b:	0f 82 28 fe ff ff    	jb     120e439 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x359>
 120e611:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 120e615:	89 85 48 ff ff ff    	mov    %eax,-0xb8(%rbp)
 120e61b:	8b 45 d0             	mov    -0x30(%rbp),%eax
 120e61e:	89 45 8c             	mov    %eax,-0x74(%rbp)
 120e621:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 120e625:	48 89 85 f0 fe ff ff 	mov    %rax,-0x110(%rbp)
 120e62c:	8b 45 d4             	mov    -0x2c(%rbp),%eax
 120e62f:	89 45 88             	mov    %eax,-0x78(%rbp)
 120e632:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 120e636:	48 89 85 e8 fe ff ff 	mov    %rax,-0x118(%rbp)
 120e63d:	4c 89 a5 e0 fe ff ff 	mov    %r12,-0x120(%rbp)
 120e644:	c5 fc 10 85 00 ff ff 	vmovups -0x100(%rbp),%ymm0
 120e64b:	ff 
 120e64c:	c5 fc 10 8d 20 ff ff 	vmovups -0xe0(%rbp),%ymm1
 120e653:	ff 
 120e654:	c5 fc 10 95 60 ff ff 	vmovups -0xa0(%rbp),%ymm2
 120e65b:	ff 
 120e65c:	c5 fc 11 85 50 fd ff 	vmovups %ymm0,-0x2b0(%rbp)
 120e663:	ff 
 120e664:	c5 fc 11 8d 70 fd ff 	vmovups %ymm1,-0x290(%rbp)
 120e66b:	ff 
 120e66c:	c5 fc 11 95 b0 fd ff 	vmovups %ymm2,-0x250(%rbp)
 120e673:	ff 
 120e674:	48 8b 85 e0 fe ff ff 	mov    -0x120(%rbp),%rax
 120e67b:	48 89 85 30 fd ff ff 	mov    %rax,-0x2d0(%rbp)
 120e682:	48 8b 85 e8 fe ff ff 	mov    -0x118(%rbp),%rax
 120e689:	48 89 85 38 fd ff ff 	mov    %rax,-0x2c8(%rbp)
 120e690:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 120e697:	48 89 85 40 fd ff ff 	mov    %rax,-0x2c0(%rbp)
 120e69e:	48 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%rax
 120e6a5:	48 89 85 48 fd ff ff 	mov    %rax,-0x2b8(%rbp)
 120e6ac:	c5 fc 10 85 40 ff ff 	vmovups -0xc0(%rbp),%ymm0
 120e6b3:	ff 
 120e6b4:	c5 fc 11 85 90 fd ff 	vmovups %ymm0,-0x270(%rbp)
 120e6bb:	ff 
 120e6bc:	c5 fc 10 85 70 ff ff 	vmovups -0x90(%rbp),%ymm0
 120e6c3:	ff 
 120e6c4:	c5 fc 11 85 c0 fd ff 	vmovups %ymm0,-0x240(%rbp)
 120e6cb:	ff 
 120e6cc:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 120e6d0:	48 8d 75 a0          	lea    -0x60(%rbp),%rsi
 120e6d4:	48 8d 95 30 fd ff ff 	lea    -0x2d0(%rbp),%rdx
 120e6db:	c5 f8 77             	vzeroupper 
 120e6de:	e8 1d 8d f6 ff       	call   1177400 <br.encoder.complex_prefix.finishBitCost__anon_36316>
 120e6e3:	0f b7 45 98          	movzwl -0x68(%rbp),%eax
 120e6e7:	66 85 c0             	test   %ax,%ax
 120e6ea:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 120e6ee:	75 17                	jne    120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e6f0:	48 8b 45 90          	mov    -0x70(%rbp),%rax
 120e6f4:	e9 b7 fc ff ff       	jmp    120e3b0 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x2d0>
 120e6f9:	66 b8 1f 00          	mov    $0x1f,%ax
 120e6fd:	48 8b 5d b0          	mov    -0x50(%rbp),%rbx
 120e701:	eb 04                	jmp    120e707 <br.encoder.literal_context_split.treeBitCostProfiled__anon_46144+0x627>
 120e703:	66 b8 1f 00          	mov    $0x1f,%ax
 120e707:	66 89 43 08          	mov    %ax,0x8(%rbx)
 120e70b:	48 81 c4 b8 06 00 00 	add    $0x6b8,%rsp
 120e712:	5b                   	pop    %rbx
 120e713:	41 5c                	pop    %r12
 120e715:	41 5d                	pop    %r13
 120e717:	41 5e                	pop    %r14
 120e719:	41 5f                	pop    %r15
 120e71b:	5d                   	pop    %rbp
 120e71c:	c5 f8 77             	vzeroupper 
 120e71f:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
