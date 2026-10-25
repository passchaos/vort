
/home/passchaos/project-z/vort-brotli-context-cache/.zig-cache/o/78f0aed58c7f51384364cb890565eb73/vort-br-planned-encode-bench:     file format elf64-x86-64


Disassembly of section .text:

000000000120d1b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230>:
 120d1b0:	55                   	push   %rbp
 120d1b1:	48 89 e5             	mov    %rsp,%rbp
 120d1b4:	41 57                	push   %r15
 120d1b6:	41 56                	push   %r14
 120d1b8:	41 55                	push   %r13
 120d1ba:	41 54                	push   %r12
 120d1bc:	53                   	push   %rbx
 120d1bd:	48 81 ec a8 d5 02 00 	sub    $0x2d5a8,%rsp
 120d1c4:	4c 89 8d f0 fe ff ff 	mov    %r9,-0x110(%rbp)
 120d1cb:	4c 89 c3             	mov    %r8,%rbx
 120d1ce:	49 89 cf             	mov    %rcx,%r15
 120d1d1:	49 89 d6             	mov    %rdx,%r14
 120d1d4:	89 b5 54 ff ff ff    	mov    %esi,-0xac(%rbp)
 120d1da:	48 89 bd 38 ff ff ff 	mov    %rdi,-0xc8(%rbp)
 120d1e1:	4c 8b 6d 10          	mov    0x10(%rbp),%r13
 120d1e5:	48 8d bd b0 f6 ff ff 	lea    -0x950(%rbp),%rdi
 120d1ec:	ba 00 04 00 00       	mov    $0x400,%edx
 120d1f1:	31 f6                	xor    %esi,%esi
 120d1f3:	e8 08 8c 08 00       	call   1295e00 <compiler_rt.memset>
 120d1f8:	45 31 c9             	xor    %r9d,%r9d
 120d1fb:	49 89 d8             	mov    %rbx,%r8
 120d1fe:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 120d202:	c5 fe 7f 85 20 fd ff 	vmovdqu %ymm0,-0x2e0(%rbp)
 120d209:	ff 
 120d20a:	c5 fe 7f 85 40 fd ff 	vmovdqu %ymm0,-0x2c0(%rbp)
 120d211:	ff 
 120d212:	48 c7 85 5e fd ff ff 	movq   $0x0,-0x2a2(%rbp)
 120d219:	00 00 00 00 
 120d21d:	49 8d 45 02          	lea    0x2(%r13),%rax
 120d221:	48 89 85 48 ff ff ff 	mov    %rax,-0xb8(%rbp)
 120d228:	4c 8d 15 d9 26 ec ff 	lea    -0x13d927(%rip),%r10        # 10cf908 <br.encoder.literal_context_split.precomputed_suffix_map_costs>
 120d22f:	4c 89 f3             	mov    %r14,%rbx
 120d232:	31 ff                	xor    %edi,%edi
 120d234:	48 c7 85 60 ff ff ff 	movq   $0x0,-0xa0(%rbp)
 120d23b:	00 00 00 00 
 120d23f:	31 c0                	xor    %eax,%eax
 120d241:	48 c7 85 28 ff ff ff 	movq   $0x0,-0xd8(%rbp)
 120d248:	00 00 00 00 
 120d24c:	48 c7 85 30 ff ff ff 	movq   $0x0,-0xd0(%rbp)
 120d253:	00 00 00 00 
 120d257:	4c 89 85 f8 fe ff ff 	mov    %r8,-0x108(%rbp)
 120d25e:	eb 61                	jmp    120d2c1 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x111>
 120d260:	0f b6 55 d0          	movzbl -0x30(%rbp),%edx
 120d264:	48 89 95 30 ff ff ff 	mov    %rdx,-0xd0(%rbp)
 120d26b:	0f b6 55 c7          	movzbl -0x39(%rbp),%edx
 120d26f:	48 89 95 28 ff ff ff 	mov    %rdx,-0xd8(%rbp)
 120d276:	c5 fe 6f 85 b0 fb ff 	vmovdqu -0x450(%rbp),%ymm0
 120d27d:	ff 
 120d27e:	c5 fe 6f 8d d0 fb ff 	vmovdqu -0x430(%rbp),%ymm1
 120d285:	ff 
 120d286:	c5 fe 7f 85 20 fd ff 	vmovdqu %ymm0,-0x2e0(%rbp)
 120d28d:	ff 
 120d28e:	c5 fe 7f 8d 40 fd ff 	vmovdqu %ymm1,-0x2c0(%rbp)
 120d295:	ff 
 120d296:	b2 01                	mov    $0x1,%dl
 120d298:	48 89 95 60 ff ff ff 	mov    %rdx,-0xa0(%rbp)
 120d29f:	48 89 8d 20 ff ff ff 	mov    %rcx,-0xe0(%rbp)
 120d2a6:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120d2ad:	00 00 00 
 120d2b0:	48 81 c3 00 04 00 00 	add    $0x400,%rbx
 120d2b7:	48 83 ff 3f          	cmp    $0x3f,%rdi
 120d2bb:	0f 84 08 03 00 00    	je     120d5c9 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x419>
 120d2c1:	49 89 fc             	mov    %rdi,%r12
 120d2c4:	ba 03 00 00 00       	mov    $0x3,%edx
 120d2c9:	31 c9                	xor    %ecx,%ecx
 120d2cb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120d2d0:	8b 74 93 f4          	mov    -0xc(%rbx,%rdx,4),%esi
 120d2d4:	01 b4 95 a4 f6 ff ff 	add    %esi,-0x95c(%rbp,%rdx,4)
 120d2db:	48 01 f1             	add    %rsi,%rcx
 120d2de:	8b 74 93 f8          	mov    -0x8(%rbx,%rdx,4),%esi
 120d2e2:	01 b4 95 a8 f6 ff ff 	add    %esi,-0x958(%rbp,%rdx,4)
 120d2e9:	8b 7c 93 fc          	mov    -0x4(%rbx,%rdx,4),%edi
 120d2ed:	01 bc 95 ac f6 ff ff 	add    %edi,-0x954(%rbp,%rdx,4)
 120d2f4:	48 01 fe             	add    %rdi,%rsi
 120d2f7:	48 01 f1             	add    %rsi,%rcx
 120d2fa:	8b 34 93             	mov    (%rbx,%rdx,4),%esi
 120d2fd:	01 b4 95 b0 f6 ff ff 	add    %esi,-0x950(%rbp,%rdx,4)
 120d304:	48 01 f1             	add    %rsi,%rcx
 120d307:	48 83 c2 04          	add    $0x4,%rdx
 120d30b:	48 81 fa 03 01 00 00 	cmp    $0x103,%rdx
 120d312:	75 bc                	jne    120d2d0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x120>
 120d314:	49 8d 7c 24 01       	lea    0x1(%r12),%rdi
 120d319:	49 01 c9             	add    %rcx,%r9
 120d31c:	0f 94 c2             	sete   %dl
 120d31f:	4d 39 c1             	cmp    %r8,%r9
 120d322:	40 0f 94 c6          	sete   %sil
 120d326:	40 08 d6             	or     %dl,%sil
 120d329:	75 85                	jne    120d2b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x100>
 120d32b:	48 85 c9             	test   %rcx,%rcx
 120d32e:	0f 95 c1             	setne  %cl
 120d331:	84 c0                	test   %al,%al
 120d333:	0f 94 c0             	sete   %al
 120d336:	08 c8                	or     %cl,%al
 120d338:	0f 84 88 01 00 00    	je     120d4c6 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x316>
 120d33e:	48 89 bd 70 ff ff ff 	mov    %rdi,-0x90(%rbp)
 120d345:	4c 89 8d 40 ff ff ff 	mov    %r9,-0xc0(%rbp)
 120d34c:	ba 00 04 00 00       	mov    $0x400,%edx
 120d351:	48 8d bd 38 6c fe ff 	lea    -0x193c8(%rbp),%rdi
 120d358:	31 f6                	xor    %esi,%esi
 120d35a:	c5 f8 77             	vzeroupper 
 120d35d:	e8 9e 8a 08 00       	call   1295e00 <compiler_rt.memset>
 120d362:	41 0f b7 45 00       	movzwl 0x0(%r13),%eax
 120d367:	48 85 c0             	test   %rax,%rax
 120d36a:	48 8b 4d 18          	mov    0x18(%rbp),%rcx
 120d36e:	0f 84 ce 00 00 00    	je     120d442 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x292>
 120d374:	66 83 f8 04          	cmp    $0x4,%ax
 120d378:	73 08                	jae    120d382 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1d2>
 120d37a:	45 31 c0             	xor    %r8d,%r8d
 120d37d:	e9 83 00 00 00       	jmp    120d405 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x255>
 120d382:	89 c2                	mov    %eax,%edx
 120d384:	83 e2 fc             	and    $0xfffffffc,%edx
 120d387:	45 31 c0             	xor    %r8d,%r8d
 120d38a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 120d390:	43 0f b6 74 05 02    	movzbl 0x2(%r13,%r8,1),%esi
 120d396:	c1 e6 02             	shl    $0x2,%esi
 120d399:	41 8b 3c 37          	mov    (%r15,%rsi,1),%edi
 120d39d:	2b bc 35 b0 f6 ff ff 	sub    -0x950(%rbp,%rsi,1),%edi
 120d3a4:	89 bc 35 38 6c fe ff 	mov    %edi,-0x193c8(%rbp,%rsi,1)
 120d3ab:	43 0f b6 74 05 03    	movzbl 0x3(%r13,%r8,1),%esi
 120d3b1:	c1 e6 02             	shl    $0x2,%esi
 120d3b4:	41 8b 3c 37          	mov    (%r15,%rsi,1),%edi
 120d3b8:	2b bc 35 b0 f6 ff ff 	sub    -0x950(%rbp,%rsi,1),%edi
 120d3bf:	89 bc 35 38 6c fe ff 	mov    %edi,-0x193c8(%rbp,%rsi,1)
 120d3c6:	43 0f b6 74 05 04    	movzbl 0x4(%r13,%r8,1),%esi
 120d3cc:	c1 e6 02             	shl    $0x2,%esi
 120d3cf:	41 8b 3c 37          	mov    (%r15,%rsi,1),%edi
 120d3d3:	2b bc 35 b0 f6 ff ff 	sub    -0x950(%rbp,%rsi,1),%edi
 120d3da:	89 bc 35 38 6c fe ff 	mov    %edi,-0x193c8(%rbp,%rsi,1)
 120d3e1:	43 0f b6 74 05 05    	movzbl 0x5(%r13,%r8,1),%esi
 120d3e7:	c1 e6 02             	shl    $0x2,%esi
 120d3ea:	41 8b 3c 37          	mov    (%r15,%rsi,1),%edi
 120d3ee:	2b bc 35 b0 f6 ff ff 	sub    -0x950(%rbp,%rsi,1),%edi
 120d3f5:	89 bc 35 38 6c fe ff 	mov    %edi,-0x193c8(%rbp,%rsi,1)
 120d3fc:	49 83 c0 04          	add    $0x4,%r8
 120d400:	4c 39 c2             	cmp    %r8,%rdx
 120d403:	75 8b                	jne    120d390 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1e0>
 120d405:	83 e0 03             	and    $0x3,%eax
 120d408:	74 38                	je     120d442 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x292>
 120d40a:	4c 03 85 48 ff ff ff 	add    -0xb8(%rbp),%r8
 120d411:	31 d2                	xor    %edx,%edx
 120d413:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120d41a:	84 00 00 00 00 00 
 120d420:	41 0f b6 34 10       	movzbl (%r8,%rdx,1),%esi
 120d425:	c1 e6 02             	shl    $0x2,%esi
 120d428:	41 8b 3c 37          	mov    (%r15,%rsi,1),%edi
 120d42c:	2b bc 35 b0 f6 ff ff 	sub    -0x950(%rbp,%rsi,1),%edi
 120d433:	89 bc 35 38 6c fe ff 	mov    %edi,-0x193c8(%rbp,%rsi,1)
 120d43a:	48 ff c2             	inc    %rdx
 120d43d:	48 39 d0             	cmp    %rdx,%rax
 120d440:	75 de                	jne    120d420 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x270>
 120d442:	48 8d bd d8 f3 ff ff 	lea    -0xc28(%rbp),%rdi
 120d449:	48 8d b5 b0 f6 ff ff 	lea    -0x950(%rbp),%rsi
 120d450:	4c 89 ea             	mov    %r13,%rdx
 120d453:	49 89 cd             	mov    %rcx,%r13
 120d456:	e8 15 f2 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostCached__anon_46145>
 120d45b:	0f b7 85 e0 f3 ff ff 	movzwl -0xc20(%rbp),%eax
 120d462:	66 85 c0             	test   %ax,%ax
 120d465:	0f 85 2c 18 00 00    	jne    120ec97 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1ae7>
 120d46b:	4c 89 e9             	mov    %r13,%rcx
 120d46e:	4c 8b ad d8 f3 ff ff 	mov    -0xc28(%rbp),%r13
 120d475:	48 8d bd 38 6c ff ff 	lea    -0x93c8(%rbp),%rdi
 120d47c:	48 8d b5 38 6c fe ff 	lea    -0x193c8(%rbp),%rsi
 120d483:	48 8b 55 10          	mov    0x10(%rbp),%rdx
 120d487:	e8 e4 f1 ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostCached__anon_46145>
 120d48c:	0f b7 85 40 6c ff ff 	movzwl -0x93c0(%rbp),%eax
 120d493:	66 85 c0             	test   %ax,%ax
 120d496:	0f 85 fb 17 00 00    	jne    120ec97 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1ae7>
 120d49c:	4d 89 eb             	mov    %r13,%r11
 120d49f:	4c 03 9d 38 6c ff ff 	add    -0x93c8(%rbp),%r11
 120d4a6:	4c 8b 6d 10          	mov    0x10(%rbp),%r13
 120d4aa:	4c 8b 85 f8 fe ff ff 	mov    -0x108(%rbp),%r8
 120d4b1:	4c 8b 8d 40 ff ff ff 	mov    -0xc0(%rbp),%r9
 120d4b8:	4c 8d 15 49 24 ec ff 	lea    -0x13dbb7(%rip),%r10        # 10cf908 <br.encoder.literal_context_split.precomputed_suffix_map_costs>
 120d4bf:	48 8b bd 70 ff ff ff 	mov    -0x90(%rbp),%rdi
 120d4c6:	31 c0                	xor    %eax,%eax
 120d4c8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120d4cf:	00 
 120d4d0:	4c 39 e0             	cmp    %r12,%rax
 120d4d3:	0f 97 84 05 38 6c fe 	seta   -0x193c8(%rbp,%rax,1)
 120d4da:	ff 
 120d4db:	0f 93 84 05 39 6c fe 	setae  -0x193c7(%rbp,%rax,1)
 120d4e2:	ff 
 120d4e3:	48 8d 48 02          	lea    0x2(%rax),%rcx
 120d4e7:	4c 39 e1             	cmp    %r12,%rcx
 120d4ea:	0f 97 84 05 3a 6c fe 	seta   -0x193c6(%rbp,%rax,1)
 120d4f1:	ff 
 120d4f2:	48 8d 48 03          	lea    0x3(%rax),%rcx
 120d4f6:	4c 39 e1             	cmp    %r12,%rcx
 120d4f9:	0f 97 84 05 3b 6c fe 	seta   -0x193c5(%rbp,%rax,1)
 120d500:	ff 
 120d501:	48 8d 48 04          	lea    0x4(%rax),%rcx
 120d505:	4c 39 e1             	cmp    %r12,%rcx
 120d508:	0f 97 84 05 3c 6c fe 	seta   -0x193c4(%rbp,%rax,1)
 120d50f:	ff 
 120d510:	48 8d 48 05          	lea    0x5(%rax),%rcx
 120d514:	4c 39 e1             	cmp    %r12,%rcx
 120d517:	0f 97 84 05 3d 6c fe 	seta   -0x193c3(%rbp,%rax,1)
 120d51e:	ff 
 120d51f:	48 8d 48 06          	lea    0x6(%rax),%rcx
 120d523:	4c 39 e1             	cmp    %r12,%rcx
 120d526:	0f 97 84 05 3e 6c fe 	seta   -0x193c2(%rbp,%rax,1)
 120d52d:	ff 
 120d52e:	48 8d 48 07          	lea    0x7(%rax),%rcx
 120d532:	4c 39 e1             	cmp    %r12,%rcx
 120d535:	0f 97 84 05 3f 6c fe 	seta   -0x193c1(%rbp,%rax,1)
 120d53c:	ff 
 120d53d:	48 83 c0 08          	add    $0x8,%rax
 120d541:	48 83 f8 40          	cmp    $0x40,%rax
 120d545:	75 89                	jne    120d4d0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x320>
 120d547:	8b 85 54 ff ff ff    	mov    -0xac(%rbp),%eax
 120d54d:	24 03                	and    $0x3,%al
 120d54f:	88 45 d0             	mov    %al,-0x30(%rbp)
 120d552:	c6 45 c7 02          	movb   $0x2,-0x39(%rbp)
 120d556:	c5 fe 6f 85 38 6c fe 	vmovdqu -0x193c8(%rbp),%ymm0
 120d55d:	ff 
 120d55e:	c5 fe 6f 8d 58 6c fe 	vmovdqu -0x193a8(%rbp),%ymm1
 120d565:	ff 
 120d566:	c5 fe 7f 85 b0 fb ff 	vmovdqu %ymm0,-0x450(%rbp)
 120d56d:	ff 
 120d56e:	c5 fe 7f 8d d0 fb ff 	vmovdqu %ymm1,-0x430(%rbp)
 120d575:	ff 
 120d576:	49 8b 04 fa          	mov    (%r10,%rdi,8),%rax
 120d57a:	4c 01 d8             	add    %r11,%rax
 120d57d:	48 8b 95 f0 fe ff ff 	mov    -0x110(%rbp),%rdx
 120d584:	48 29 c2             	sub    %rax,%rdx
 120d587:	b9 00 00 00 00       	mov    $0x0,%ecx
 120d58c:	48 0f 43 ca          	cmovae %rdx,%rcx
 120d590:	b0 01                	mov    $0x1,%al
 120d592:	48 81 f9 80 00 00 00 	cmp    $0x80,%rcx
 120d599:	0f 82 11 fd ff ff    	jb     120d2b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x100>
 120d59f:	b0 01                	mov    $0x1,%al
 120d5a1:	80 bd 60 ff ff ff 00 	cmpb   $0x0,-0xa0(%rbp)
 120d5a8:	0f 84 b2 fc ff ff    	je     120d260 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xb0>
 120d5ae:	48 3b 8d 20 ff ff ff 	cmp    -0xe0(%rbp),%rcx
 120d5b5:	0f 87 a5 fc ff ff    	ja     120d260 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xb0>
 120d5bb:	b1 01                	mov    $0x1,%cl
 120d5bd:	48 89 8d 60 ff ff ff 	mov    %rcx,-0xa0(%rbp)
 120d5c4:	e9 e7 fc ff ff       	jmp    120d2b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x100>
 120d5c9:	48 8b 85 5e fd ff ff 	mov    -0x2a2(%rbp),%rax
 120d5d0:	48 89 85 ce fc ff ff 	mov    %rax,-0x332(%rbp)
 120d5d7:	c5 fe 6f 85 20 fd ff 	vmovdqu -0x2e0(%rbp),%ymm0
 120d5de:	ff 
 120d5df:	c5 fe 6f 8d 40 fd ff 	vmovdqu -0x2c0(%rbp),%ymm1
 120d5e6:	ff 
 120d5e7:	c5 fe 7f 8d b0 fc ff 	vmovdqu %ymm1,-0x350(%rbp)
 120d5ee:	ff 
 120d5ef:	c5 fe 7f 85 90 fc ff 	vmovdqu %ymm0,-0x370(%rbp)
 120d5f6:	ff 
 120d5f7:	c5 fe 7f 85 70 fd ff 	vmovdqu %ymm0,-0x290(%rbp)
 120d5fe:	ff 
 120d5ff:	c5 fe 7f 8d 90 fd ff 	vmovdqu %ymm1,-0x270(%rbp)
 120d606:	ff 
 120d607:	c5 fe 7f 85 c0 fd ff 	vmovdqu %ymm0,-0x240(%rbp)
 120d60e:	ff 
 120d60f:	48 89 85 ae fd ff ff 	mov    %rax,-0x252(%rbp)
 120d616:	c5 fe 7f 8d e0 fd ff 	vmovdqu %ymm1,-0x220(%rbp)
 120d61d:	ff 
 120d61e:	48 89 85 fe fd ff ff 	mov    %rax,-0x202(%rbp)
 120d625:	49 83 c6 04          	add    $0x4,%r14
 120d629:	31 c0                	xor    %eax,%eax
 120d62b:	eb 17                	jmp    120d644 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x494>
 120d62d:	0f 1f 00             	nopl   (%rax)
 120d630:	48 ff c0             	inc    %rax
 120d633:	49 81 c6 00 04 00 00 	add    $0x400,%r14
 120d63a:	48 83 f8 40          	cmp    $0x40,%rax
 120d63e:	0f 84 a5 00 00 00    	je     120d6e9 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x539>
 120d644:	48 69 d0 08 05 00 00 	imul   $0x508,%rax,%rdx
 120d64b:	48 8d 0c 2a          	lea    (%rdx,%rbp,1),%rcx
 120d64f:	48 81 c1 38 2a fd ff 	add    $0xfffffffffffd2a38,%rcx
 120d656:	66 c7 84 15 3c 2e fd 	movw   $0x0,-0x2d1c4(%rbp,%rdx,1)
 120d65d:	ff 00 00 
 120d660:	c7 84 15 38 2e fd ff 	movl   $0x0,-0x2d1c8(%rbp,%rdx,1)
 120d667:	00 00 00 00 
 120d66b:	31 f6                	xor    %esi,%esi
 120d66d:	31 d2                	xor    %edx,%edx
 120d66f:	eb 1c                	jmp    120d68d <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x4dd>
 120d671:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120d678:	0f 1f 84 00 00 00 00 
 120d67f:	00 
 120d680:	48 83 c2 02          	add    $0x2,%rdx
 120d684:	48 81 fa 00 01 00 00 	cmp    $0x100,%rdx
 120d68b:	74 a3                	je     120d630 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x480>
 120d68d:	41 8b 7c 96 fc       	mov    -0x4(%r14,%rdx,4),%edi
 120d692:	85 ff                	test   %edi,%edi
 120d694:	74 22                	je     120d6b8 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x508>
 120d696:	0f b7 f6             	movzwl %si,%esi
 120d699:	88 94 31 06 04 00 00 	mov    %dl,0x406(%rcx,%rsi,1)
 120d6a0:	89 3c b1             	mov    %edi,(%rcx,%rsi,4)
 120d6a3:	8b b1 04 04 00 00    	mov    0x404(%rcx),%esi
 120d6a9:	ff c6                	inc    %esi
 120d6ab:	66 89 b1 04 04 00 00 	mov    %si,0x404(%rcx)
 120d6b2:	01 b9 00 04 00 00    	add    %edi,0x400(%rcx)
 120d6b8:	41 8b 3c 96          	mov    (%r14,%rdx,4),%edi
 120d6bc:	85 ff                	test   %edi,%edi
 120d6be:	74 c0                	je     120d680 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x4d0>
 120d6c0:	0f b7 f6             	movzwl %si,%esi
 120d6c3:	44 8d 42 01          	lea    0x1(%rdx),%r8d
 120d6c7:	44 88 84 31 06 04 00 	mov    %r8b,0x406(%rcx,%rsi,1)
 120d6ce:	00 
 120d6cf:	89 3c b1             	mov    %edi,(%rcx,%rsi,4)
 120d6d2:	8b b1 04 04 00 00    	mov    0x404(%rcx),%esi
 120d6d8:	ff c6                	inc    %esi
 120d6da:	66 89 b1 04 04 00 00 	mov    %si,0x404(%rcx)
 120d6e1:	01 b9 00 04 00 00    	add    %edi,0x400(%rcx)
 120d6e7:	eb 97                	jmp    120d680 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x4d0>
 120d6e9:	48 8d bd 38 ec ff ff 	lea    -0x13c8(%rbp),%rdi
 120d6f0:	ba a0 07 00 00       	mov    $0x7a0,%edx
 120d6f5:	31 f6                	xor    %esi,%esi
 120d6f7:	c5 f8 77             	vzeroupper 
 120d6fa:	e8 01 87 08 00       	call   1295e00 <compiler_rt.memset>
 120d6ff:	48 8b 8d 30 ff ff ff 	mov    -0xd0(%rbp),%rcx
 120d706:	88 4d d3             	mov    %cl,-0x2d(%rbp)
 120d709:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 120d710:	88 45 d7             	mov    %al,-0x29(%rbp)
 120d713:	48 8b 95 60 ff ff ff 	mov    -0xa0(%rbp),%rdx
 120d71a:	88 55 d6             	mov    %dl,-0x2a(%rbp)
 120d71d:	88 4d d2             	mov    %cl,-0x2e(%rbp)
 120d720:	88 45 d5             	mov    %al,-0x2b(%rbp)
 120d723:	88 55 d4             	mov    %dl,-0x2c(%rbp)
 120d726:	49 c7 c4 ff ff ff ff 	mov    $0xffffffffffffffff,%r12
 120d72d:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 120d734:	48 89 85 18 ff ff ff 	mov    %rax,-0xe8(%rbp)
 120d73b:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 120d742:	31 c0                	xor    %eax,%eax
 120d744:	eb 1e                	jmp    120d764 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x5b4>
 120d746:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120d74d:	00 00 00 
 120d750:	48 8b 85 d8 fe ff ff 	mov    -0x128(%rbp),%rax
 120d757:	48 ff c0             	inc    %rax
 120d75a:	48 83 f8 0b          	cmp    $0xb,%rax
 120d75e:	0f 84 46 15 00 00    	je     120ecaa <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1afa>
 120d764:	48 89 85 d8 fe ff ff 	mov    %rax,-0x128(%rbp)
 120d76b:	48 8d 0d 86 1a e3 ff 	lea    -0x1ce57a(%rip),%rcx        # 103f1f8 <__anon_46270>
 120d772:	4c 8b 14 c1          	mov    (%rcx,%rax,8),%r10
 120d776:	49 83 fa 40          	cmp    $0x40,%r10
 120d77a:	77 d4                	ja     120d750 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x5a0>
 120d77c:	4c 89 d0             	mov    %r10,%rax
 120d77f:	48 c1 e0 0a          	shl    $0xa,%rax
 120d783:	48 89 85 d0 fe ff ff 	mov    %rax,-0x130(%rbp)
 120d78a:	4a 8d 1c 95 00 00 00 	lea    0x0(,%r10,4),%rbx
 120d791:	00 
 120d792:	49 83 fa 21          	cmp    $0x21,%r10
 120d796:	b9 00 00 00 00       	mov    $0x0,%ecx
 120d79b:	48 83 d1 01          	adc    $0x1,%rcx
 120d79f:	49 83 fa 11          	cmp    $0x11,%r10
 120d7a3:	b8 04 00 00 00       	mov    $0x4,%eax
 120d7a8:	48 0f 42 c8          	cmovb  %rax,%rcx
 120d7ac:	48 89 8d b0 fe ff ff 	mov    %rcx,-0x150(%rbp)
 120d7b3:	49 8d 42 ff          	lea    -0x1(%r10),%rax
 120d7b7:	48 89 85 40 ff ff ff 	mov    %rax,-0xc0(%rbp)
 120d7be:	44 89 d0             	mov    %r10d,%eax
 120d7c1:	83 e0 7e             	and    $0x7e,%eax
 120d7c4:	48 89 85 b8 fe ff ff 	mov    %rax,-0x148(%rbp)
 120d7cb:	4b 8d 04 52          	lea    (%r10,%r10,2),%rax
 120d7cf:	48 89 85 c0 fe ff ff 	mov    %rax,-0x140(%rbp)
 120d7d6:	4b 8d 04 12          	lea    (%r10,%r10,1),%rax
 120d7da:	48 89 85 c8 fe ff ff 	mov    %rax,-0x138(%rbp)
 120d7e1:	b0 01                	mov    $0x1,%al
 120d7e3:	89 85 50 ff ff ff    	mov    %eax,-0xb0(%rbp)
 120d7e9:	31 c0                	xor    %eax,%eax
 120d7eb:	4c 89 95 58 ff ff ff 	mov    %r10,-0xa8(%rbp)
 120d7f2:	48 89 9d e8 fe ff ff 	mov    %rbx,-0x118(%rbp)
 120d7f9:	eb 50                	jmp    120d84b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x69b>
 120d7fb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120d800:	c6 45 c8 00          	movb   $0x0,-0x38(%rbp)
 120d804:	c6 45 c6 00          	movb   $0x0,-0x3a(%rbp)
 120d808:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 120d80c:	c5 fe 7f 85 e0 fc ff 	vmovdqu %ymm0,-0x320(%rbp)
 120d813:	ff 
 120d814:	c5 fe 7f 85 00 fd ff 	vmovdqu %ymm0,-0x300(%rbp)
 120d81b:	ff 
 120d81c:	c7 85 68 ff ff ff 00 	movl   $0x0,-0x98(%rbp)
 120d823:	00 00 00 
 120d826:	66 c7 85 6c ff ff ff 	movw   $0x0,-0x94(%rbp)
 120d82d:	00 00 
 120d82f:	b8 01 00 00 00       	mov    $0x1,%eax
 120d834:	f6 85 50 ff ff ff 01 	testb  $0x1,-0xb0(%rbp)
 120d83b:	c7 85 50 ff ff ff 00 	movl   $0x0,-0xb0(%rbp)
 120d842:	00 00 00 
 120d845:	0f 84 05 ff ff ff    	je     120d750 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x5a0>
 120d84b:	48 8d 0d fe 19 e3 ff 	lea    -0x1ce602(%rip),%rcx        # 103f250 <__anon_46276>
 120d852:	0f b6 04 08          	movzbl (%rax,%rcx,1),%eax
 120d856:	48 8d 8d 38 2e fd ff 	lea    -0x2d1c8(%rbp),%rcx
 120d85d:	31 ff                	xor    %edi,%edi
 120d85f:	31 d2                	xor    %edx,%edx
 120d861:	eb 1e                	jmp    120d881 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x6d1>
 120d863:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120d86a:	84 00 00 00 00 00 
 120d870:	48 83 c2 04          	add    $0x4,%rdx
 120d874:	48 81 c1 20 14 00 00 	add    $0x1420,%rcx
 120d87b:	48 83 fa 40          	cmp    $0x40,%rdx
 120d87f:	74 5f                	je     120d8e0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x730>
 120d881:	83 39 00             	cmpl   $0x0,(%rcx)
 120d884:	74 0a                	je     120d890 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x6e0>
 120d886:	88 94 3d 60 fe ff ff 	mov    %dl,-0x1a0(%rbp,%rdi,1)
 120d88d:	48 ff c7             	inc    %rdi
 120d890:	83 b9 08 05 00 00 00 	cmpl   $0x0,0x508(%rcx)
 120d897:	74 0e                	je     120d8a7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x6f7>
 120d899:	8d 72 01             	lea    0x1(%rdx),%esi
 120d89c:	40 88 b4 3d 60 fe ff 	mov    %sil,-0x1a0(%rbp,%rdi,1)
 120d8a3:	ff 
 120d8a4:	48 ff c7             	inc    %rdi
 120d8a7:	83 b9 10 0a 00 00 00 	cmpl   $0x0,0xa10(%rcx)
 120d8ae:	74 0e                	je     120d8be <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x70e>
 120d8b0:	8d 72 02             	lea    0x2(%rdx),%esi
 120d8b3:	40 88 b4 3d 60 fe ff 	mov    %sil,-0x1a0(%rbp,%rdi,1)
 120d8ba:	ff 
 120d8bb:	48 ff c7             	inc    %rdi
 120d8be:	83 b9 18 0f 00 00 00 	cmpl   $0x0,0xf18(%rcx)
 120d8c5:	74 a9                	je     120d870 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x6c0>
 120d8c7:	8d 72 03             	lea    0x3(%rdx),%esi
 120d8ca:	40 88 b4 3d 60 fe ff 	mov    %sil,-0x1a0(%rbp,%rdi,1)
 120d8d1:	ff 
 120d8d2:	48 ff c7             	inc    %rdi
 120d8d5:	eb 99                	jmp    120d870 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x6c0>
 120d8d7:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 120d8de:	00 00 
 120d8e0:	4c 39 d7             	cmp    %r10,%rdi
 120d8e3:	0f 82 17 ff ff ff    	jb     120d800 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x650>
 120d8e9:	c5 f9 ef c0          	vpxor  %xmm0,%xmm0,%xmm0
 120d8ed:	c5 fe 7f 45 a0       	vmovdqu %ymm0,-0x60(%rbp)
 120d8f2:	c5 fe 7f 45 80       	vmovdqu %ymm0,-0x80(%rbp)
 120d8f7:	48 89 bd 78 ff ff ff 	mov    %rdi,-0x88(%rbp)
 120d8fe:	48 85 ff             	test   %rdi,%rdi
 120d901:	0f 84 99 01 00 00    	je     120daa0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x8f0>
 120d907:	a8 01                	test   $0x1,%al
 120d909:	74 18                	je     120d923 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x773>
 120d90b:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 120d912:	48 83 fe 04          	cmp    $0x4,%rsi
 120d916:	0f 83 81 00 00 00    	jae    120d99d <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x7ed>
 120d91c:	31 c9                	xor    %ecx,%ecx
 120d91e:	e9 68 01 00 00       	jmp    120da8b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x8db>
 120d923:	48 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%rdi
 120d92a:	48 83 ff 04          	cmp    $0x4,%rdi
 120d92e:	0f 83 74 12 00 00    	jae    120eba8 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x19f8>
 120d934:	31 f6                	xor    %esi,%esi
 120d936:	48 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%rdi
 120d93d:	83 e7 03             	and    $0x3,%edi
 120d940:	0f 84 5a 01 00 00    	je     120daa0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x8f0>
 120d946:	4c 89 d1             	mov    %r10,%rcx
 120d949:	48 0f af ce          	imul   %rsi,%rcx
 120d94d:	48 01 ee             	add    %rbp,%rsi
 120d950:	48 81 c6 60 fe ff ff 	add    $0xfffffffffffffe60,%rsi
 120d957:	45 31 c0             	xor    %r8d,%r8d
 120d95a:	eb 20                	jmp    120d97c <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x7cc>
 120d95c:	0f 1f 40 00          	nopl   0x0(%rax)
 120d960:	48 89 c8             	mov    %rcx,%rax
 120d963:	31 d2                	xor    %edx,%edx
 120d965:	49 f7 f3             	div    %r11
 120d968:	42 88 44 0d 80       	mov    %al,-0x80(%rbp,%r9,1)
 120d96d:	49 ff c0             	inc    %r8
 120d970:	4c 01 d1             	add    %r10,%rcx
 120d973:	4c 39 c7             	cmp    %r8,%rdi
 120d976:	0f 84 24 01 00 00    	je     120daa0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x8f0>
 120d97c:	46 0f b6 0c 06       	movzbl (%rsi,%r8,1),%r9d
 120d981:	48 89 c8             	mov    %rcx,%rax
 120d984:	4c 8b 9d 78 ff ff ff 	mov    -0x88(%rbp),%r11
 120d98b:	4c 09 d8             	or     %r11,%rax
 120d98e:	48 c1 e8 20          	shr    $0x20,%rax
 120d992:	75 cc                	jne    120d960 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x7b0>
 120d994:	89 c8                	mov    %ecx,%eax
 120d996:	31 d2                	xor    %edx,%edx
 120d998:	41 f7 f3             	div    %r11d
 120d99b:	eb cb                	jmp    120d968 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x7b8>
 120d99d:	48 83 e6 fc          	and    $0xfffffffffffffffc,%rsi
 120d9a1:	31 c9                	xor    %ecx,%ecx
 120d9a3:	eb 21                	jmp    120d9c6 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x816>
 120d9a5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120d9ac:	00 00 00 00 
 120d9b0:	31 d2                	xor    %edx,%edx
 120d9b2:	49 f7 f2             	div    %r10
 120d9b5:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120d9b9:	48 83 c1 04          	add    $0x4,%rcx
 120d9bd:	48 39 ce             	cmp    %rcx,%rsi
 120d9c0:	0f 84 c5 00 00 00    	je     120da8b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x8db>
 120d9c6:	0f b6 bc 0d 60 fe ff 	movzbl -0x1a0(%rbp,%rcx,1),%edi
 120d9cd:	ff 
 120d9ce:	48 89 c8             	mov    %rcx,%rax
 120d9d1:	4c 09 d0             	or     %r10,%rax
 120d9d4:	48 c1 e8 20          	shr    $0x20,%rax
 120d9d8:	74 16                	je     120d9f0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x840>
 120d9da:	48 89 c8             	mov    %rcx,%rax
 120d9dd:	31 d2                	xor    %edx,%edx
 120d9df:	49 f7 f2             	div    %r10
 120d9e2:	eb 13                	jmp    120d9f7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x847>
 120d9e4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 120d9eb:	00 00 00 00 00 
 120d9f0:	89 c8                	mov    %ecx,%eax
 120d9f2:	31 d2                	xor    %edx,%edx
 120d9f4:	41 f7 f2             	div    %r10d
 120d9f7:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120d9fb:	48 8d 41 01          	lea    0x1(%rcx),%rax
 120d9ff:	0f b6 bc 0d 61 fe ff 	movzbl -0x19f(%rbp,%rcx,1),%edi
 120da06:	ff 
 120da07:	48 89 c2             	mov    %rax,%rdx
 120da0a:	4c 09 d2             	or     %r10,%rdx
 120da0d:	48 c1 ea 20          	shr    $0x20,%rdx
 120da11:	74 0d                	je     120da20 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x870>
 120da13:	31 d2                	xor    %edx,%edx
 120da15:	49 f7 f2             	div    %r10
 120da18:	eb 0b                	jmp    120da25 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x875>
 120da1a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 120da20:	31 d2                	xor    %edx,%edx
 120da22:	41 f7 f2             	div    %r10d
 120da25:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120da29:	48 8d 41 02          	lea    0x2(%rcx),%rax
 120da2d:	0f b6 bc 0d 62 fe ff 	movzbl -0x19e(%rbp,%rcx,1),%edi
 120da34:	ff 
 120da35:	48 89 c2             	mov    %rax,%rdx
 120da38:	4c 09 d2             	or     %r10,%rdx
 120da3b:	48 c1 ea 20          	shr    $0x20,%rdx
 120da3f:	74 0f                	je     120da50 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x8a0>
 120da41:	31 d2                	xor    %edx,%edx
 120da43:	49 f7 f2             	div    %r10
 120da46:	eb 0d                	jmp    120da55 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x8a5>
 120da48:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120da4f:	00 
 120da50:	31 d2                	xor    %edx,%edx
 120da52:	41 f7 f2             	div    %r10d
 120da55:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120da59:	48 8d 41 03          	lea    0x3(%rcx),%rax
 120da5d:	0f b6 bc 0d 63 fe ff 	movzbl -0x19d(%rbp,%rcx,1),%edi
 120da64:	ff 
 120da65:	48 89 c2             	mov    %rax,%rdx
 120da68:	4c 09 d2             	or     %r10,%rdx
 120da6b:	48 c1 ea 20          	shr    $0x20,%rdx
 120da6f:	0f 85 3b ff ff ff    	jne    120d9b0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x800>
 120da75:	31 d2                	xor    %edx,%edx
 120da77:	41 f7 f2             	div    %r10d
 120da7a:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120da7e:	48 83 c1 04          	add    $0x4,%rcx
 120da82:	48 39 ce             	cmp    %rcx,%rsi
 120da85:	0f 85 3b ff ff ff    	jne    120d9c6 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x816>
 120da8b:	48 8b b5 78 ff ff ff 	mov    -0x88(%rbp),%rsi
 120da92:	83 e6 03             	and    $0x3,%esi
 120da95:	0f 85 6d 01 00 00    	jne    120dc08 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xa58>
 120da9b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120daa0:	48 8d bd 38 6c fe ff 	lea    -0x193c8(%rbp),%rdi
 120daa7:	31 f6                	xor    %esi,%esi
 120daa9:	48 8b 95 d0 fe ff ff 	mov    -0x130(%rbp),%rdx
 120dab0:	c5 f8 77             	vzeroupper 
 120dab3:	e8 48 83 08 00       	call   1295e00 <compiler_rt.memset>
 120dab8:	48 8d bd b0 fa ff ff 	lea    -0x550(%rbp),%rdi
 120dabf:	31 f6                	xor    %esi,%esi
 120dac1:	48 89 da             	mov    %rbx,%rdx
 120dac4:	e8 37 83 08 00       	call   1295e00 <compiler_rt.memset>
 120dac9:	48 8d 85 3e 2e fd ff 	lea    -0x2d1c2(%rbp),%rax
 120dad0:	48 8d 8d 38 2a fd ff 	lea    -0x2d5c8(%rbp),%rcx
 120dad7:	31 d2                	xor    %edx,%edx
 120dad9:	eb 36                	jmp    120db11 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x961>
 120dadb:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120dae0:	48 01 ef             	add    %rbp,%rdi
 120dae3:	48 81 c7 38 2a fd ff 	add    $0xfffffffffffd2a38,%rdi
 120daea:	8b bf 00 04 00 00    	mov    0x400(%rdi),%edi
 120daf0:	01 bc b5 b0 fa ff ff 	add    %edi,-0x550(%rbp,%rsi,4)
 120daf7:	48 ff c2             	inc    %rdx
 120dafa:	48 81 c1 08 05 00 00 	add    $0x508,%rcx
 120db01:	48 05 08 05 00 00    	add    $0x508,%rax
 120db07:	48 83 fa 40          	cmp    $0x40,%rdx
 120db0b:	0f 84 1f 01 00 00    	je     120dc30 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xa80>
 120db11:	48 69 fa 08 05 00 00 	imul   $0x508,%rdx,%rdi
 120db18:	0f b6 74 15 80       	movzbl -0x80(%rbp,%rdx,1),%esi
 120db1d:	44 0f b7 84 3d 3c 2e 	movzwl -0x2d1c4(%rbp,%rdi,1),%r8d
 120db24:	fd ff 
 120db26:	4d 85 c0             	test   %r8,%r8
 120db29:	74 b5                	je     120dae0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x930>
 120db2b:	41 89 f1             	mov    %esi,%r9d
 120db2e:	41 c1 e1 0a          	shl    $0xa,%r9d
 120db32:	49 01 e9             	add    %rbp,%r9
 120db35:	49 81 c1 38 6c fe ff 	add    $0xfffffffffffe6c38,%r9
 120db3c:	66 41 83 f8 04       	cmp    $0x4,%r8w
 120db41:	73 0d                	jae    120db50 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x9a0>
 120db43:	45 31 d2             	xor    %r10d,%r10d
 120db46:	eb 68                	jmp    120dbb0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xa00>
 120db48:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120db4f:	00 
 120db50:	45 89 c3             	mov    %r8d,%r11d
 120db53:	41 83 e3 fc          	and    $0xfffffffc,%r11d
 120db57:	45 31 d2             	xor    %r10d,%r10d
 120db5a:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 120db60:	42 0f b6 9c 11 06 04 	movzbl 0x406(%rcx,%r10,1),%ebx
 120db67:	00 00 
 120db69:	46 8b 34 91          	mov    (%rcx,%r10,4),%r14d
 120db6d:	45 01 34 99          	add    %r14d,(%r9,%rbx,4)
 120db71:	42 0f b6 9c 11 07 04 	movzbl 0x407(%rcx,%r10,1),%ebx
 120db78:	00 00 
 120db7a:	46 8b 74 91 04       	mov    0x4(%rcx,%r10,4),%r14d
 120db7f:	45 01 34 99          	add    %r14d,(%r9,%rbx,4)
 120db83:	42 0f b6 9c 11 08 04 	movzbl 0x408(%rcx,%r10,1),%ebx
 120db8a:	00 00 
 120db8c:	46 8b 74 91 08       	mov    0x8(%rcx,%r10,4),%r14d
 120db91:	45 01 34 99          	add    %r14d,(%r9,%rbx,4)
 120db95:	42 0f b6 9c 11 09 04 	movzbl 0x409(%rcx,%r10,1),%ebx
 120db9c:	00 00 
 120db9e:	46 8b 74 91 0c       	mov    0xc(%rcx,%r10,4),%r14d
 120dba3:	45 01 34 99          	add    %r14d,(%r9,%rbx,4)
 120dba7:	49 83 c2 04          	add    $0x4,%r10
 120dbab:	4d 39 d3             	cmp    %r10,%r11
 120dbae:	75 b0                	jne    120db60 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x9b0>
 120dbb0:	41 83 e0 03          	and    $0x3,%r8d
 120dbb4:	0f 84 26 ff ff ff    	je     120dae0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x930>
 120dbba:	4e 8d 1c 91          	lea    (%rcx,%r10,4),%r11
 120dbbe:	49 01 c2             	add    %rax,%r10
 120dbc1:	31 db                	xor    %ebx,%ebx
 120dbc3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120dbca:	84 00 00 00 00 00 
 120dbd0:	45 0f b6 34 1a       	movzbl (%r10,%rbx,1),%r14d
 120dbd5:	45 8b 3c 9b          	mov    (%r11,%rbx,4),%r15d
 120dbd9:	47 01 3c b1          	add    %r15d,(%r9,%r14,4)
 120dbdd:	48 ff c3             	inc    %rbx
 120dbe0:	49 39 d8             	cmp    %rbx,%r8
 120dbe3:	75 eb                	jne    120dbd0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xa20>
 120dbe5:	e9 f6 fe ff ff       	jmp    120dae0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x930>
 120dbea:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 120dbf0:	48 89 c8             	mov    %rcx,%rax
 120dbf3:	31 d2                	xor    %edx,%edx
 120dbf5:	49 f7 f2             	div    %r10
 120dbf8:	88 54 3d 80          	mov    %dl,-0x80(%rbp,%rdi,1)
 120dbfc:	48 ff c1             	inc    %rcx
 120dbff:	48 ff ce             	dec    %rsi
 120dc02:	0f 84 98 fe ff ff    	je     120daa0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x8f0>
 120dc08:	0f b6 bc 0d 60 fe ff 	movzbl -0x1a0(%rbp,%rcx,1),%edi
 120dc0f:	ff 
 120dc10:	48 89 c8             	mov    %rcx,%rax
 120dc13:	4c 09 d0             	or     %r10,%rax
 120dc16:	48 c1 e8 20          	shr    $0x20,%rax
 120dc1a:	75 d4                	jne    120dbf0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xa40>
 120dc1c:	89 c8                	mov    %ecx,%eax
 120dc1e:	31 d2                	xor    %edx,%edx
 120dc20:	41 f7 f2             	div    %r10d
 120dc23:	eb d3                	jmp    120dbf8 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xa48>
 120dc25:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120dc2c:	00 00 00 00 
 120dc30:	41 0f b7 45 00       	movzwl 0x0(%r13),%eax
 120dc35:	48 89 85 00 ff ff ff 	mov    %rax,-0x100(%rbp)
 120dc3c:	41 89 c6             	mov    %eax,%r14d
 120dc3f:	41 83 e6 fe          	and    $0xfffffffe,%r14d
 120dc43:	31 c9                	xor    %ecx,%ecx
 120dc45:	48 8d 1d 8c 19 e3 ff 	lea    -0x1ce674(%rip),%rbx        # 103f5d8 <__anon_72592>
 120dc4c:	4c 89 b5 08 ff ff ff 	mov    %r14,-0xf8(%rbp)
 120dc53:	eb 2b                	jmp    120dc80 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xad0>
 120dc55:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120dc5c:	00 00 00 00 
 120dc60:	48 8b 8d a8 fe ff ff 	mov    -0x158(%rbp),%rcx
 120dc67:	48 ff c1             	inc    %rcx
 120dc6a:	48 3b 8d b0 fe ff ff 	cmp    -0x150(%rbp),%rcx
 120dc71:	0f 95 c0             	setne  %al
 120dc74:	84 85 e0 fe ff ff    	test   %al,-0x120(%rbp)
 120dc7a:	0f 84 c0 06 00 00    	je     120e340 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1190>
 120dc80:	48 89 8d a8 fe ff ff 	mov    %rcx,-0x158(%rbp)
 120dc87:	48 83 bd 00 ff ff ff 	cmpq   $0x0,-0x100(%rbp)
 120dc8e:	00 
 120dc8f:	0f 84 8b 01 00 00    	je     120de20 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xc70>
 120dc95:	31 d2                	xor    %edx,%edx
 120dc97:	eb 24                	jmp    120dcbd <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xb0d>
 120dc99:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 120dca0:	89 c9                	mov    %ecx,%ecx
 120dca2:	0f b7 3c 4b          	movzwl (%rbx,%rcx,2),%edi
 120dca6:	29 f8                	sub    %edi,%eax
 120dca8:	66 42 89 04 46       	mov    %ax,(%rsi,%r8,2)
 120dcad:	48 ff c2             	inc    %rdx
 120dcb0:	48 3b 95 58 ff ff ff 	cmp    -0xa8(%rbp),%rdx
 120dcb7:	0f 84 63 01 00 00    	je     120de20 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xc70>
 120dcbd:	48 89 d1             	mov    %rdx,%rcx
 120dcc0:	48 c1 e1 0a          	shl    $0xa,%rcx
 120dcc4:	8b b4 95 b0 fa ff ff 	mov    -0x550(%rbp,%rdx,4),%esi
 120dccb:	49 89 d0             	mov    %rdx,%r8
 120dcce:	49 c1 e0 09          	shl    $0x9,%r8
 120dcd2:	48 8d 86 00 01 00 00 	lea    0x100(%rsi),%rax
 120dcd9:	0f bd c0             	bsr    %eax,%eax
 120dcdc:	c4 c2 f9 f7 fc       	shlx   %rax,%r12,%rdi
 120dce1:	48 01 fe             	add    %rdi,%rsi
 120dce4:	48 81 c6 00 01 00 00 	add    $0x100,%rsi
 120dceb:	48 c1 e6 08          	shl    $0x8,%rsi
 120dcef:	c4 e2 fb f7 f6       	shrx   %rax,%rsi,%rsi
 120dcf4:	c1 e0 08             	shl    $0x8,%eax
 120dcf7:	48 01 f0             	add    %rsi,%rax
 120dcfa:	48 8d 3c 29          	lea    (%rcx,%rbp,1),%rdi
 120dcfe:	48 81 c7 38 6c fe ff 	add    $0xfffffffffffe6c38,%rdi
 120dd05:	49 8d 34 28          	lea    (%r8,%rbp,1),%rsi
 120dd09:	48 81 c6 38 6c ff ff 	add    $0xffffffffffff6c38,%rsi
 120dd10:	83 bd 00 ff ff ff 01 	cmpl   $0x1,-0x100(%rbp)
 120dd17:	75 47                	jne    120dd60 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xbb0>
 120dd19:	45 31 c0             	xor    %r8d,%r8d
 120dd1c:	f6 85 00 ff ff ff 01 	testb  $0x1,-0x100(%rbp)
 120dd23:	74 88                	je     120dcad <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xafd>
 120dd25:	47 0f b6 44 05 02    	movzbl 0x2(%r13,%r8,1),%r8d
 120dd2b:	42 8b 3c 87          	mov    (%rdi,%r8,4),%edi
 120dd2f:	48 8d 4f 01          	lea    0x1(%rdi),%rcx
 120dd33:	48 81 ff 00 10 00 00 	cmp    $0x1000,%rdi
 120dd3a:	0f 82 60 ff ff ff    	jb     120dca0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xaf0>
 120dd40:	0f bd f9             	bsr    %ecx,%edi
 120dd43:	c4 42 c1 f7 cc       	shlx   %rdi,%r12,%r9
 120dd48:	49 01 c9             	add    %rcx,%r9
 120dd4b:	49 c1 e1 08          	shl    $0x8,%r9
 120dd4f:	c4 c2 c3 f7 c9       	shrx   %rdi,%r9,%rcx
 120dd54:	c1 e7 08             	shl    $0x8,%edi
 120dd57:	48 01 cf             	add    %rcx,%rdi
 120dd5a:	e9 47 ff ff ff       	jmp    120dca6 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xaf6>
 120dd5f:	90                   	nop
 120dd60:	45 31 c0             	xor    %r8d,%r8d
 120dd63:	eb 25                	jmp    120dd8a <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xbda>
 120dd65:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120dd6c:	00 00 00 00 
 120dd70:	89 c9                	mov    %ecx,%ecx
 120dd72:	44 0f b7 14 4b       	movzwl (%rbx,%rcx,2),%r10d
 120dd77:	89 c1                	mov    %eax,%ecx
 120dd79:	44 29 d1             	sub    %r10d,%ecx
 120dd7c:	66 42 89 0c 4e       	mov    %cx,(%rsi,%r9,2)
 120dd81:	49 83 c0 02          	add    $0x2,%r8
 120dd85:	4d 39 c6             	cmp    %r8,%r14
 120dd88:	74 92                	je     120dd1c <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xb6c>
 120dd8a:	47 0f b6 4c 05 02    	movzbl 0x2(%r13,%r8,1),%r9d
 120dd90:	42 8b 0c 8f          	mov    (%rdi,%r9,4),%ecx
 120dd94:	48 81 f9 ff 0f 00 00 	cmp    $0xfff,%rcx
 120dd9b:	77 13                	ja     120ddb0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xc00>
 120dd9d:	44 0f b7 54 4b 02    	movzwl 0x2(%rbx,%rcx,2),%r10d
 120dda3:	eb 2b                	jmp    120ddd0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xc20>
 120dda5:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 120ddac:	00 00 00 00 
 120ddb0:	ff c1                	inc    %ecx
 120ddb2:	44 0f bd d1          	bsr    %ecx,%r10d
 120ddb6:	c4 42 a9 f7 dc       	shlx   %r10,%r12,%r11
 120ddbb:	89 c9                	mov    %ecx,%ecx
 120ddbd:	4c 01 d9             	add    %r11,%rcx
 120ddc0:	48 c1 e1 08          	shl    $0x8,%rcx
 120ddc4:	c4 e2 ab f7 c9       	shrx   %r10,%rcx,%rcx
 120ddc9:	41 c1 e2 08          	shl    $0x8,%r10d
 120ddcd:	49 01 ca             	add    %rcx,%r10
 120ddd0:	89 c1                	mov    %eax,%ecx
 120ddd2:	44 29 d1             	sub    %r10d,%ecx
 120ddd5:	66 42 89 0c 4e       	mov    %cx,(%rsi,%r9,2)
 120ddda:	47 0f b6 4c 05 03    	movzbl 0x3(%r13,%r8,1),%r9d
 120dde0:	46 8b 14 8f          	mov    (%rdi,%r9,4),%r10d
 120dde4:	49 8d 4a 01          	lea    0x1(%r10),%rcx
 120dde8:	49 81 fa 00 10 00 00 	cmp    $0x1000,%r10
 120ddef:	0f 82 7b ff ff ff    	jb     120dd70 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xbc0>
 120ddf5:	44 0f bd d1          	bsr    %ecx,%r10d
 120ddf9:	c4 42 a9 f7 dc       	shlx   %r10,%r12,%r11
 120ddfe:	49 01 cb             	add    %rcx,%r11
 120de01:	49 c1 e3 08          	shl    $0x8,%r11
 120de05:	c4 c2 ab f7 cb       	shrx   %r10,%r11,%rcx
 120de0a:	41 c1 e2 08          	shl    $0x8,%r10d
 120de0e:	49 01 ca             	add    %rcx,%r10
 120de11:	e9 61 ff ff ff       	jmp    120dd77 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xbc7>
 120de16:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120de1d:	00 00 00 
 120de20:	48 c7 85 e0 fe ff ff 	movq   $0x0,-0x120(%rbp)
 120de27:	00 00 00 00 
 120de2b:	31 c9                	xor    %ecx,%ecx
 120de2d:	eb 47                	jmp    120de76 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xcc6>
 120de2f:	90                   	nop
 120de30:	48 8d 1d a1 17 e3 ff 	lea    -0x1ce85f(%rip),%rbx        # 103f5d8 <__anon_72592>
 120de37:	4c 8b b5 08 ff ff ff 	mov    -0xf8(%rbp),%r14
 120de3e:	8b 87 00 04 00 00    	mov    0x400(%rdi),%eax
 120de44:	42 29 84 85 b0 fa ff 	sub    %eax,-0x550(%rbp,%r8,4)
 120de4b:	ff 
 120de4c:	01 84 95 b0 fa ff ff 	add    %eax,-0x550(%rbp,%rdx,4)
 120de53:	41 88 12             	mov    %dl,(%r10)
 120de56:	b0 01                	mov    $0x1,%al
 120de58:	48 89 85 e0 fe ff ff 	mov    %rax,-0x120(%rbp)
 120de5f:	48 8b 8d f8 fe ff ff 	mov    -0x108(%rbp),%rcx
 120de66:	48 ff c1             	inc    %rcx
 120de69:	48 3b 8d 78 ff ff ff 	cmp    -0x88(%rbp),%rcx
 120de70:	0f 84 ea fd ff ff    	je     120dc60 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xab0>
 120de76:	44 0f b6 bc 0d 60 fe 	movzbl -0x1a0(%rbp,%rcx,1),%r15d
 120de7d:	ff ff 
 120de7f:	49 69 f7 08 05 00 00 	imul   $0x508,%r15,%rsi
 120de86:	48 8d 3c 2e          	lea    (%rsi,%rbp,1),%rdi
 120de8a:	48 81 c7 38 2a fd ff 	add    $0xfffffffffffd2a38,%rdi
 120de91:	0f b7 84 35 3c 2e fd 	movzwl -0x2d1c4(%rbp,%rsi,1),%eax
 120de98:	ff 
 120de99:	48 85 c0             	test   %rax,%rax
 120de9c:	48 89 8d f8 fe ff ff 	mov    %rcx,-0x108(%rbp)
 120dea3:	48 89 b5 a0 fe ff ff 	mov    %rsi,-0x160(%rbp)
 120deaa:	74 14                	je     120dec0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xd10>
 120deac:	66 83 f8 08          	cmp    $0x8,%ax
 120deb0:	73 5e                	jae    120df10 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xd60>
 120deb2:	31 d2                	xor    %edx,%edx
 120deb4:	45 31 e4             	xor    %r12d,%r12d
 120deb7:	e9 5a 01 00 00       	jmp    120e016 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xe66>
 120debc:	0f 1f 40 00          	nopl   0x0(%rax)
 120dec0:	4c 89 bd 48 ff ff ff 	mov    %r15,-0xb8(%rbp)
 120dec7:	31 d2                	xor    %edx,%edx
 120dec9:	48 8b 8d 48 ff ff ff 	mov    -0xb8(%rbp),%rcx
 120ded0:	44 0f b6 44 0d 80    	movzbl -0x80(%rbp,%rcx,1),%r8d
 120ded6:	4c 39 c2             	cmp    %r8,%rdx
 120ded9:	4c 8b 6d 10          	mov    0x10(%rbp),%r13
 120dedd:	49 c7 c4 ff ff ff ff 	mov    $0xffffffffffffffff,%r12
 120dee4:	48 8d 1d ed 16 e3 ff 	lea    -0x1ce913(%rip),%rbx        # 103f5d8 <__anon_72592>
 120deeb:	4c 8b b5 08 ff ff ff 	mov    -0xf8(%rbp),%r14
 120def2:	0f 84 67 ff ff ff    	je     120de5f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xcaf>
 120def8:	4c 8d 14 29          	lea    (%rcx,%rbp,1),%r10
 120defc:	49 83 c2 80          	add    $0xffffffffffffff80,%r10
 120df00:	48 85 c0             	test   %rax,%rax
 120df03:	0f 85 27 03 00 00    	jne    120e230 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1080>
 120df09:	e9 30 ff ff ff       	jmp    120de3e <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xc8e>
 120df0e:	66 90                	xchg   %ax,%ax
 120df10:	41 89 c0             	mov    %eax,%r8d
 120df13:	41 83 e0 f8          	and    $0xfffffff8,%r8d
 120df17:	31 d2                	xor    %edx,%edx
 120df19:	45 31 e4             	xor    %r12d,%r12d
 120df1c:	0f 1f 40 00          	nopl   0x0(%rax)
 120df20:	0f b6 8c 17 06 04 00 	movzbl 0x406(%rdi,%rdx,1),%ecx
 120df27:	00 
 120df28:	44 8b 0c 97          	mov    (%rdi,%rdx,4),%r9d
 120df2c:	44 8b 54 97 04       	mov    0x4(%rdi,%rdx,4),%r10d
 120df31:	0f b7 8c 4d 38 6c ff 	movzwl -0x93c8(%rbp,%rcx,2),%ecx
 120df38:	ff 
 120df39:	49 0f af c9          	imul   %r9,%rcx
 120df3d:	4c 01 e1             	add    %r12,%rcx
 120df40:	44 0f b6 8c 17 07 04 	movzbl 0x407(%rdi,%rdx,1),%r9d
 120df47:	00 00 
 120df49:	46 0f b7 8c 4d 38 6c 	movzwl -0x93c8(%rbp,%r9,2),%r9d
 120df50:	ff ff 
 120df52:	4d 0f af ca          	imul   %r10,%r9
 120df56:	44 0f b6 94 17 08 04 	movzbl 0x408(%rdi,%rdx,1),%r10d
 120df5d:	00 00 
 120df5f:	44 8b 5c 97 08       	mov    0x8(%rdi,%rdx,4),%r11d
 120df64:	46 0f b7 94 55 38 6c 	movzwl -0x93c8(%rbp,%r10,2),%r10d
 120df6b:	ff ff 
 120df6d:	4d 0f af d3          	imul   %r11,%r10
 120df71:	4d 01 ca             	add    %r9,%r10
 120df74:	49 01 ca             	add    %rcx,%r10
 120df77:	0f b6 8c 17 09 04 00 	movzbl 0x409(%rdi,%rdx,1),%ecx
 120df7e:	00 
 120df7f:	44 8b 4c 97 0c       	mov    0xc(%rdi,%rdx,4),%r9d
 120df84:	0f b7 8c 4d 38 6c ff 	movzwl -0x93c8(%rbp,%rcx,2),%ecx
 120df8b:	ff 
 120df8c:	49 0f af c9          	imul   %r9,%rcx
 120df90:	44 0f b6 8c 17 0a 04 	movzbl 0x40a(%rdi,%rdx,1),%r9d
 120df97:	00 00 
 120df99:	44 8b 5c 97 10       	mov    0x10(%rdi,%rdx,4),%r11d
 120df9e:	46 0f b7 8c 4d 38 6c 	movzwl -0x93c8(%rbp,%r9,2),%r9d
 120dfa5:	ff ff 
 120dfa7:	4d 0f af cb          	imul   %r11,%r9
 120dfab:	49 01 c9             	add    %rcx,%r9
 120dfae:	0f b6 8c 17 0b 04 00 	movzbl 0x40b(%rdi,%rdx,1),%ecx
 120dfb5:	00 
 120dfb6:	44 8b 5c 97 14       	mov    0x14(%rdi,%rdx,4),%r11d
 120dfbb:	0f b7 8c 4d 38 6c ff 	movzwl -0x93c8(%rbp,%rcx,2),%ecx
 120dfc2:	ff 
 120dfc3:	49 0f af cb          	imul   %r11,%rcx
 120dfc7:	4c 01 c9             	add    %r9,%rcx
 120dfca:	4c 01 d1             	add    %r10,%rcx
 120dfcd:	44 0f b6 8c 17 0c 04 	movzbl 0x40c(%rdi,%rdx,1),%r9d
 120dfd4:	00 00 
 120dfd6:	44 8b 54 97 18       	mov    0x18(%rdi,%rdx,4),%r10d
 120dfdb:	46 0f b7 8c 4d 38 6c 	movzwl -0x93c8(%rbp,%r9,2),%r9d
 120dfe2:	ff ff 
 120dfe4:	4d 0f af ca          	imul   %r10,%r9
 120dfe8:	44 0f b6 94 17 0d 04 	movzbl 0x40d(%rdi,%rdx,1),%r10d
 120dfef:	00 00 
 120dff1:	44 8b 5c 97 1c       	mov    0x1c(%rdi,%rdx,4),%r11d
 120dff6:	46 0f b7 a4 55 38 6c 	movzwl -0x93c8(%rbp,%r10,2),%r12d
 120dffd:	ff ff 
 120dfff:	4d 0f af e3          	imul   %r11,%r12
 120e003:	4d 01 cc             	add    %r9,%r12
 120e006:	49 01 cc             	add    %rcx,%r12
 120e009:	48 83 c2 08          	add    $0x8,%rdx
 120e00d:	49 39 d0             	cmp    %rdx,%r8
 120e010:	0f 85 0a ff ff ff    	jne    120df20 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xd70>
 120e016:	41 89 c0             	mov    %eax,%r8d
 120e019:	41 83 e0 07          	and    $0x7,%r8d
 120e01d:	74 41                	je     120e060 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xeb0>
 120e01f:	48 8d 0c 96          	lea    (%rsi,%rdx,4),%rcx
 120e023:	4c 8d 14 29          	lea    (%rcx,%rbp,1),%r10
 120e027:	49 81 c2 38 2a fd ff 	add    $0xfffffffffffd2a38,%r10
 120e02e:	48 8d 8d 3e 2e fd ff 	lea    -0x2d1c2(%rbp),%rcx
 120e035:	48 01 ca             	add    %rcx,%rdx
 120e038:	48 01 f2             	add    %rsi,%rdx
 120e03b:	45 31 c9             	xor    %r9d,%r9d
 120e03e:	66 90                	xchg   %ax,%ax
 120e040:	42 0f b6 0c 0a       	movzbl (%rdx,%r9,1),%ecx
 120e045:	47 8b 1c 8a          	mov    (%r10,%r9,4),%r11d
 120e049:	0f b7 8c 4d 38 6c ff 	movzwl -0x93c8(%rbp,%rcx,2),%ecx
 120e050:	ff 
 120e051:	49 0f af cb          	imul   %r11,%rcx
 120e055:	49 01 cc             	add    %rcx,%r12
 120e058:	49 ff c1             	inc    %r9
 120e05b:	4d 39 c8             	cmp    %r9,%r8
 120e05e:	75 e0                	jne    120e040 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xe90>
 120e060:	48 83 bd 40 ff ff ff 	cmpq   $0x0,-0xc0(%rbp)
 120e067:	00 
 120e068:	0f 84 a2 01 00 00    	je     120e210 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1060>
 120e06e:	4c 89 bd 48 ff ff ff 	mov    %r15,-0xb8(%rbp)
 120e075:	41 89 c2             	mov    %eax,%r10d
 120e078:	41 83 e2 f8          	and    $0xfffffff8,%r10d
 120e07c:	48 8d 8d 3e 2e fd ff 	lea    -0x2d1c2(%rbp),%rcx
 120e083:	48 01 f1             	add    %rsi,%rcx
 120e086:	48 89 8d 70 ff ff ff 	mov    %rcx,-0x90(%rbp)
 120e08d:	31 d2                	xor    %edx,%edx
 120e08f:	31 db                	xor    %ebx,%ebx
 120e091:	eb 25                	jmp    120e0b8 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xf08>
 120e093:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e09a:	84 00 00 00 00 00 
 120e0a0:	4d 39 e3             	cmp    %r12,%r11
 120e0a3:	4d 0f 42 e3          	cmovb  %r11,%r12
 120e0a7:	48 0f 42 d3          	cmovb  %rbx,%rdx
 120e0ab:	48 3b 9d 40 ff ff ff 	cmp    -0xc0(%rbp),%rbx
 120e0b2:	0f 84 11 fe ff ff    	je     120dec9 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xd19>
 120e0b8:	48 ff c3             	inc    %rbx
 120e0bb:	48 89 d9             	mov    %rbx,%rcx
 120e0be:	48 c1 e1 09          	shl    $0x9,%rcx
 120e0c2:	4c 8d 2c 29          	lea    (%rcx,%rbp,1),%r13
 120e0c6:	49 81 c5 38 6c ff ff 	add    $0xffffffffffff6c38,%r13
 120e0cd:	45 31 ff             	xor    %r15d,%r15d
 120e0d0:	45 31 db             	xor    %r11d,%r11d
 120e0d3:	66 83 f8 08          	cmp    $0x8,%ax
 120e0d7:	0f 82 e7 00 00 00    	jb     120e1c4 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1014>
 120e0dd:	0f 1f 00             	nopl   (%rax)
 120e0e0:	42 0f b6 8c 3f 06 04 	movzbl 0x406(%rdi,%r15,1),%ecx
 120e0e7:	00 00 
 120e0e9:	46 8b 0c bf          	mov    (%rdi,%r15,4),%r9d
 120e0ed:	42 8b 74 bf 04       	mov    0x4(%rdi,%r15,4),%esi
 120e0f2:	41 0f b7 4c 4d 00    	movzwl 0x0(%r13,%rcx,2),%ecx
 120e0f8:	49 0f af c9          	imul   %r9,%rcx
 120e0fc:	4c 01 d9             	add    %r11,%rcx
 120e0ff:	46 0f b6 8c 3f 07 04 	movzbl 0x407(%rdi,%r15,1),%r9d
 120e106:	00 00 
 120e108:	47 0f b7 4c 4d 00    	movzwl 0x0(%r13,%r9,2),%r9d
 120e10e:	4c 0f af ce          	imul   %rsi,%r9
 120e112:	42 0f b6 b4 3f 08 04 	movzbl 0x408(%rdi,%r15,1),%esi
 120e119:	00 00 
 120e11b:	46 8b 74 bf 08       	mov    0x8(%rdi,%r15,4),%r14d
 120e120:	45 0f b7 5c 75 00    	movzwl 0x0(%r13,%rsi,2),%r11d
 120e126:	4d 0f af de          	imul   %r14,%r11
 120e12a:	4d 01 cb             	add    %r9,%r11
 120e12d:	49 01 cb             	add    %rcx,%r11
 120e130:	42 0f b6 8c 3f 09 04 	movzbl 0x409(%rdi,%r15,1),%ecx
 120e137:	00 00 
 120e139:	42 8b 74 bf 0c       	mov    0xc(%rdi,%r15,4),%esi
 120e13e:	41 0f b7 4c 4d 00    	movzwl 0x0(%r13,%rcx,2),%ecx
 120e144:	48 0f af ce          	imul   %rsi,%rcx
 120e148:	42 0f b6 b4 3f 0a 04 	movzbl 0x40a(%rdi,%r15,1),%esi
 120e14f:	00 00 
 120e151:	46 8b 4c bf 10       	mov    0x10(%rdi,%r15,4),%r9d
 120e156:	41 0f b7 74 75 00    	movzwl 0x0(%r13,%rsi,2),%esi
 120e15c:	49 0f af f1          	imul   %r9,%rsi
 120e160:	48 01 ce             	add    %rcx,%rsi
 120e163:	42 0f b6 8c 3f 0b 04 	movzbl 0x40b(%rdi,%r15,1),%ecx
 120e16a:	00 00 
 120e16c:	46 8b 4c bf 14       	mov    0x14(%rdi,%r15,4),%r9d
 120e171:	41 0f b7 4c 4d 00    	movzwl 0x0(%r13,%rcx,2),%ecx
 120e177:	49 0f af c9          	imul   %r9,%rcx
 120e17b:	48 01 f1             	add    %rsi,%rcx
 120e17e:	4c 01 d9             	add    %r11,%rcx
 120e181:	42 0f b6 b4 3f 0c 04 	movzbl 0x40c(%rdi,%r15,1),%esi
 120e188:	00 00 
 120e18a:	46 8b 4c bf 18       	mov    0x18(%rdi,%r15,4),%r9d
 120e18f:	41 0f b7 74 75 00    	movzwl 0x0(%r13,%rsi,2),%esi
 120e195:	49 0f af f1          	imul   %r9,%rsi
 120e199:	46 0f b6 8c 3f 0d 04 	movzbl 0x40d(%rdi,%r15,1),%r9d
 120e1a0:	00 00 
 120e1a2:	46 8b 74 bf 1c       	mov    0x1c(%rdi,%r15,4),%r14d
 120e1a7:	47 0f b7 5c 4d 00    	movzwl 0x0(%r13,%r9,2),%r11d
 120e1ad:	4d 0f af de          	imul   %r14,%r11
 120e1b1:	49 01 f3             	add    %rsi,%r11
 120e1b4:	49 01 cb             	add    %rcx,%r11
 120e1b7:	49 83 c7 08          	add    $0x8,%r15
 120e1bb:	4d 39 fa             	cmp    %r15,%r10
 120e1be:	0f 85 1c ff ff ff    	jne    120e0e0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xf30>
 120e1c4:	a8 07                	test   $0x7,%al
 120e1c6:	0f 84 d4 fe ff ff    	je     120e0a0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xef0>
 120e1cc:	4e 8d 0c bf          	lea    (%rdi,%r15,4),%r9
 120e1d0:	4c 03 bd 70 ff ff ff 	add    -0x90(%rbp),%r15
 120e1d7:	31 c9                	xor    %ecx,%ecx
 120e1d9:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 120e1e0:	41 0f b6 34 0f       	movzbl (%r15,%rcx,1),%esi
 120e1e5:	45 8b 34 89          	mov    (%r9,%rcx,4),%r14d
 120e1e9:	41 0f b7 74 75 00    	movzwl 0x0(%r13,%rsi,2),%esi
 120e1ef:	49 0f af f6          	imul   %r14,%rsi
 120e1f3:	49 01 f3             	add    %rsi,%r11
 120e1f6:	48 ff c1             	inc    %rcx
 120e1f9:	49 39 c8             	cmp    %rcx,%r8
 120e1fc:	75 e2                	jne    120e1e0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1030>
 120e1fe:	e9 9d fe ff ff       	jmp    120e0a0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xef0>
 120e203:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e20a:	84 00 00 00 00 00 
 120e210:	46 0f b6 44 3d 80    	movzbl -0x80(%rbp,%r15,1),%r8d
 120e216:	4d 85 c0             	test   %r8,%r8
 120e219:	49 c7 c4 ff ff ff ff 	mov    $0xffffffffffffffff,%r12
 120e220:	0f 84 39 fc ff ff    	je     120de5f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xcaf>
 120e226:	4d 8d 14 2f          	lea    (%r15,%rbp,1),%r10
 120e22a:	49 83 c2 80          	add    $0xffffffffffffff80,%r10
 120e22e:	31 d2                	xor    %edx,%edx
 120e230:	44 89 c1             	mov    %r8d,%ecx
 120e233:	c1 e1 0a             	shl    $0xa,%ecx
 120e236:	4c 8d 1c 29          	lea    (%rcx,%rbp,1),%r11
 120e23a:	49 81 c3 38 6c fe ff 	add    $0xfffffffffffe6c38,%r11
 120e241:	48 89 d1             	mov    %rdx,%rcx
 120e244:	48 c1 e1 0a          	shl    $0xa,%rcx
 120e248:	48 8d 1c 29          	lea    (%rcx,%rbp,1),%rbx
 120e24c:	48 81 c3 38 6c fe ff 	add    $0xfffffffffffe6c38,%rbx
 120e253:	8d 48 ff             	lea    -0x1(%rax),%ecx
 120e256:	66 83 f9 03          	cmp    $0x3,%cx
 120e25a:	73 05                	jae    120e261 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x10b1>
 120e25c:	45 31 f6             	xor    %r14d,%r14d
 120e25f:	eb 77                	jmp    120e2d8 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1128>
 120e261:	41 89 c7             	mov    %eax,%r15d
 120e264:	41 83 e7 fc          	and    $0xfffffffc,%r15d
 120e268:	45 31 f6             	xor    %r14d,%r14d
 120e26b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 120e270:	42 0f b6 8c 37 06 04 	movzbl 0x406(%rdi,%r14,1),%ecx
 120e277:	00 00 
 120e279:	42 8b 34 b7          	mov    (%rdi,%r14,4),%esi
 120e27d:	c1 e1 02             	shl    $0x2,%ecx
 120e280:	41 29 34 0b          	sub    %esi,(%r11,%rcx,1)
 120e284:	01 34 0b             	add    %esi,(%rbx,%rcx,1)
 120e287:	42 0f b6 8c 37 07 04 	movzbl 0x407(%rdi,%r14,1),%ecx
 120e28e:	00 00 
 120e290:	42 8b 74 b7 04       	mov    0x4(%rdi,%r14,4),%esi
 120e295:	c1 e1 02             	shl    $0x2,%ecx
 120e298:	41 29 34 0b          	sub    %esi,(%r11,%rcx,1)
 120e29c:	01 34 0b             	add    %esi,(%rbx,%rcx,1)
 120e29f:	42 0f b6 8c 37 08 04 	movzbl 0x408(%rdi,%r14,1),%ecx
 120e2a6:	00 00 
 120e2a8:	42 8b 74 b7 08       	mov    0x8(%rdi,%r14,4),%esi
 120e2ad:	c1 e1 02             	shl    $0x2,%ecx
 120e2b0:	41 29 34 0b          	sub    %esi,(%r11,%rcx,1)
 120e2b4:	01 34 0b             	add    %esi,(%rbx,%rcx,1)
 120e2b7:	42 0f b6 8c 37 09 04 	movzbl 0x409(%rdi,%r14,1),%ecx
 120e2be:	00 00 
 120e2c0:	42 8b 74 b7 0c       	mov    0xc(%rdi,%r14,4),%esi
 120e2c5:	c1 e1 02             	shl    $0x2,%ecx
 120e2c8:	41 29 34 0b          	sub    %esi,(%r11,%rcx,1)
 120e2cc:	01 34 0b             	add    %esi,(%rbx,%rcx,1)
 120e2cf:	49 83 c6 04          	add    $0x4,%r14
 120e2d3:	4d 39 f7             	cmp    %r14,%r15
 120e2d6:	75 98                	jne    120e270 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x10c0>
 120e2d8:	83 e0 03             	and    $0x3,%eax
 120e2db:	0f 84 4f fb ff ff    	je     120de30 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xc80>
 120e2e1:	4c 8b 8d a0 fe ff ff 	mov    -0x160(%rbp),%r9
 120e2e8:	4b 8d 0c b1          	lea    (%r9,%r14,4),%rcx
 120e2ec:	48 01 e9             	add    %rbp,%rcx
 120e2ef:	48 81 c1 38 2a fd ff 	add    $0xfffffffffffd2a38,%rcx
 120e2f6:	48 8d b5 3e 2e fd ff 	lea    -0x2d1c2(%rbp),%rsi
 120e2fd:	49 01 f6             	add    %rsi,%r14
 120e300:	4d 01 ce             	add    %r9,%r14
 120e303:	45 31 c9             	xor    %r9d,%r9d
 120e306:	66 2e 0f 1f 84 00 00 	cs nopw 0x0(%rax,%rax,1)
 120e30d:	00 00 00 
 120e310:	43 0f b6 34 0e       	movzbl (%r14,%r9,1),%esi
 120e315:	46 8b 3c 89          	mov    (%rcx,%r9,4),%r15d
 120e319:	c1 e6 02             	shl    $0x2,%esi
 120e31c:	45 29 3c 33          	sub    %r15d,(%r11,%rsi,1)
 120e320:	44 01 3c 33          	add    %r15d,(%rbx,%rsi,1)
 120e324:	49 ff c1             	inc    %r9
 120e327:	4c 39 c8             	cmp    %r9,%rax
 120e32a:	75 e4                	jne    120e310 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1160>
 120e32c:	e9 ff fa ff ff       	jmp    120de30 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0xc80>
 120e331:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e338:	0f 1f 84 00 00 00 00 
 120e33f:	00 
 120e340:	c5 fd 76 c0          	vpcmpeqd %ymm0,%ymm0,%ymm0
 120e344:	c5 fe 7f 85 30 fe ff 	vmovdqu %ymm0,-0x1d0(%rbp)
 120e34b:	ff 
 120e34c:	c5 fe 7f 85 10 fe ff 	vmovdqu %ymm0,-0x1f0(%rbp)
 120e353:	ff 
 120e354:	48 83 bd 58 ff ff ff 	cmpq   $0x1,-0xa8(%rbp)
 120e35b:	01 
 120e35c:	0f 85 8e 01 00 00    	jne    120e4f0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1340>
 120e362:	31 db                	xor    %ebx,%ebx
 120e364:	45 31 ff             	xor    %r15d,%r15d
 120e367:	48 8b 75 18          	mov    0x18(%rbp),%rsi
 120e36b:	f6 85 58 ff ff ff 01 	testb  $0x1,-0xa8(%rbp)
 120e372:	49 c7 c4 ff ff ff ff 	mov    $0xffffffffffffffff,%r12
 120e379:	74 57                	je     120e3d2 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1222>
 120e37b:	44 8b b4 9d b0 fa ff 	mov    -0x550(%rbp,%rbx,4),%r14d
 120e382:	ff 
 120e383:	45 85 f6             	test   %r14d,%r14d
 120e386:	74 4a                	je     120e3d2 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1222>
 120e388:	44 88 bc 1d 10 fe ff 	mov    %r15b,-0x1f0(%rbp,%rbx,1)
 120e38f:	ff 
 120e390:	49 39 df             	cmp    %rbx,%r15
 120e393:	74 3a                	je     120e3cf <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x121f>
 120e395:	4c 89 f8             	mov    %r15,%rax
 120e398:	48 c1 e0 0a          	shl    $0xa,%rax
 120e39c:	48 8d 3c 28          	lea    (%rax,%rbp,1),%rdi
 120e3a0:	48 81 c7 38 6c fe ff 	add    $0xfffffffffffe6c38,%rdi
 120e3a7:	48 c1 e3 0a          	shl    $0xa,%rbx
 120e3ab:	48 8d 34 2b          	lea    (%rbx,%rbp,1),%rsi
 120e3af:	48 81 c6 38 6c fe ff 	add    $0xfffffffffffe6c38,%rsi
 120e3b6:	ba 00 04 00 00       	mov    $0x400,%edx
 120e3bb:	c5 f8 77             	vzeroupper 
 120e3be:	e8 cd 7a 08 00       	call   1295e90 <compiler_rt.memmove.memmoveFast>
 120e3c3:	48 8b 75 18          	mov    0x18(%rbp),%rsi
 120e3c7:	46 89 b4 bd b0 fa ff 	mov    %r14d,-0x550(%rbp,%r15,4)
 120e3ce:	ff 
 120e3cf:	49 ff c7             	inc    %r15
 120e3d2:	49 83 ff 02          	cmp    $0x2,%r15
 120e3d6:	4c 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%r10
 120e3dd:	48 8b 9d e8 fe ff ff 	mov    -0x118(%rbp),%rbx
 120e3e4:	0f 82 16 f4 ff ff    	jb     120d800 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x650>
 120e3ea:	b8 03 00 00 00       	mov    $0x3,%eax
 120e3ef:	48 8d 8d 38 2e fd ff 	lea    -0x2d1c8(%rbp),%rcx
 120e3f6:	eb 2e                	jmp    120e426 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1276>
 120e3f8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120e3ff:	00 
 120e400:	0f b6 54 05 80       	movzbl -0x80(%rbp,%rax,1),%edx
 120e405:	0f b6 94 15 10 fe ff 	movzbl -0x1f0(%rbp,%rdx,1),%edx
 120e40c:	ff 
 120e40d:	88 54 05 80          	mov    %dl,-0x80(%rbp,%rax,1)
 120e411:	48 83 c0 04          	add    $0x4,%rax
 120e415:	48 81 c1 20 14 00 00 	add    $0x1420,%rcx
 120e41c:	48 83 f8 43          	cmp    $0x43,%rax
 120e420:	0f 84 ca 01 00 00    	je     120e5f0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1440>
 120e426:	83 39 00             	cmpl   $0x0,(%rcx)
 120e429:	74 75                	je     120e4a0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x12f0>
 120e42b:	0f b6 94 05 7d ff ff 	movzbl -0x83(%rbp,%rax,1),%edx
 120e432:	ff 
 120e433:	0f b6 94 15 10 fe ff 	movzbl -0x1f0(%rbp,%rdx,1),%edx
 120e43a:	ff 
 120e43b:	88 94 05 7d ff ff ff 	mov    %dl,-0x83(%rbp,%rax,1)
 120e442:	83 b9 08 05 00 00 00 	cmpl   $0x0,0x508(%rcx)
 120e449:	74 67                	je     120e4b2 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1302>
 120e44b:	0f b6 94 05 7e ff ff 	movzbl -0x82(%rbp,%rax,1),%edx
 120e452:	ff 
 120e453:	0f b6 94 15 10 fe ff 	movzbl -0x1f0(%rbp,%rdx,1),%edx
 120e45a:	ff 
 120e45b:	88 94 05 7e ff ff ff 	mov    %dl,-0x82(%rbp,%rax,1)
 120e462:	83 b9 10 0a 00 00 00 	cmpl   $0x0,0xa10(%rcx)
 120e469:	74 59                	je     120e4c4 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1314>
 120e46b:	0f b6 94 05 7f ff ff 	movzbl -0x81(%rbp,%rax,1),%edx
 120e472:	ff 
 120e473:	0f b6 94 15 10 fe ff 	movzbl -0x1f0(%rbp,%rdx,1),%edx
 120e47a:	ff 
 120e47b:	88 94 05 7f ff ff ff 	mov    %dl,-0x81(%rbp,%rax,1)
 120e482:	83 b9 18 0f 00 00 00 	cmpl   $0x0,0xf18(%rcx)
 120e489:	0f 85 71 ff ff ff    	jne    120e400 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1250>
 120e48f:	eb 49                	jmp    120e4da <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x132a>
 120e491:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e498:	0f 1f 84 00 00 00 00 
 120e49f:	00 
 120e4a0:	31 d2                	xor    %edx,%edx
 120e4a2:	88 94 05 7d ff ff ff 	mov    %dl,-0x83(%rbp,%rax,1)
 120e4a9:	83 b9 08 05 00 00 00 	cmpl   $0x0,0x508(%rcx)
 120e4b0:	75 99                	jne    120e44b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x129b>
 120e4b2:	31 d2                	xor    %edx,%edx
 120e4b4:	88 94 05 7e ff ff ff 	mov    %dl,-0x82(%rbp,%rax,1)
 120e4bb:	83 b9 10 0a 00 00 00 	cmpl   $0x0,0xa10(%rcx)
 120e4c2:	75 a7                	jne    120e46b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x12bb>
 120e4c4:	31 d2                	xor    %edx,%edx
 120e4c6:	88 94 05 7f ff ff ff 	mov    %dl,-0x81(%rbp,%rax,1)
 120e4cd:	83 b9 18 0f 00 00 00 	cmpl   $0x0,0xf18(%rcx)
 120e4d4:	0f 85 26 ff ff ff    	jne    120e400 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1250>
 120e4da:	31 d2                	xor    %edx,%edx
 120e4dc:	e9 2c ff ff ff       	jmp    120e40d <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x125d>
 120e4e1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e4e8:	0f 1f 84 00 00 00 00 
 120e4ef:	00 
 120e4f0:	4c 8d a5 38 70 fe ff 	lea    -0x18fc8(%rbp),%r12
 120e4f7:	31 db                	xor    %ebx,%ebx
 120e4f9:	45 31 ff             	xor    %r15d,%r15d
 120e4fc:	48 8b 75 18          	mov    0x18(%rbp),%rsi
 120e500:	eb 29                	jmp    120e52b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x137b>
 120e502:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120e509:	1f 84 00 00 00 00 00 
 120e510:	49 ff c7             	inc    %r15
 120e513:	48 83 c3 02          	add    $0x2,%rbx
 120e517:	49 81 c4 00 08 00 00 	add    $0x800,%r12
 120e51e:	48 39 9d b8 fe ff ff 	cmp    %rbx,-0x148(%rbp)
 120e525:	0f 84 40 fe ff ff    	je     120e36b <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x11bb>
 120e52b:	44 8b b4 9d b0 fa ff 	mov    -0x550(%rbp,%rbx,4),%r14d
 120e532:	ff 
 120e533:	45 85 f6             	test   %r14d,%r14d
 120e536:	74 10                	je     120e548 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1398>
 120e538:	44 88 bc 1d 10 fe ff 	mov    %r15b,-0x1f0(%rbp,%rbx,1)
 120e53f:	ff 
 120e540:	4c 39 fb             	cmp    %r15,%rbx
 120e543:	75 1b                	jne    120e560 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x13b0>
 120e545:	49 ff c7             	inc    %r15
 120e548:	44 8b b4 9d b4 fa ff 	mov    -0x54c(%rbp,%rbx,4),%r14d
 120e54f:	ff 
 120e550:	45 85 f6             	test   %r14d,%r14d
 120e553:	75 52                	jne    120e5a7 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x13f7>
 120e555:	eb bc                	jmp    120e513 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1363>
 120e557:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 120e55e:	00 00 
 120e560:	4c 89 f8             	mov    %r15,%rax
 120e563:	48 c1 e0 0a          	shl    $0xa,%rax
 120e567:	48 8d 3c 28          	lea    (%rax,%rbp,1),%rdi
 120e56b:	48 81 c7 38 6c fe ff 	add    $0xfffffffffffe6c38,%rdi
 120e572:	49 8d b4 24 00 fc ff 	lea    -0x400(%r12),%rsi
 120e579:	ff 
 120e57a:	ba 00 04 00 00       	mov    $0x400,%edx
 120e57f:	c5 f8 77             	vzeroupper 
 120e582:	e8 09 79 08 00       	call   1295e90 <compiler_rt.memmove.memmoveFast>
 120e587:	48 8b 75 18          	mov    0x18(%rbp),%rsi
 120e58b:	46 89 b4 bd b0 fa ff 	mov    %r14d,-0x550(%rbp,%r15,4)
 120e592:	ff 
 120e593:	49 ff c7             	inc    %r15
 120e596:	44 8b b4 9d b4 fa ff 	mov    -0x54c(%rbp,%rbx,4),%r14d
 120e59d:	ff 
 120e59e:	45 85 f6             	test   %r14d,%r14d
 120e5a1:	0f 84 6c ff ff ff    	je     120e513 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1363>
 120e5a7:	48 8d 43 01          	lea    0x1(%rbx),%rax
 120e5ab:	44 88 bc 1d 11 fe ff 	mov    %r15b,-0x1ef(%rbp,%rbx,1)
 120e5b2:	ff 
 120e5b3:	4c 39 f8             	cmp    %r15,%rax
 120e5b6:	0f 84 54 ff ff ff    	je     120e510 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1360>
 120e5bc:	4c 89 f8             	mov    %r15,%rax
 120e5bf:	48 c1 e0 0a          	shl    $0xa,%rax
 120e5c3:	48 8d 3c 28          	lea    (%rax,%rbp,1),%rdi
 120e5c7:	48 81 c7 38 6c fe ff 	add    $0xfffffffffffe6c38,%rdi
 120e5ce:	ba 00 04 00 00       	mov    $0x400,%edx
 120e5d3:	4c 89 e6             	mov    %r12,%rsi
 120e5d6:	c5 f8 77             	vzeroupper 
 120e5d9:	e8 b2 78 08 00       	call   1295e90 <compiler_rt.memmove.memmoveFast>
 120e5de:	48 8b 75 18          	mov    0x18(%rbp),%rsi
 120e5e2:	46 89 b4 bd b0 fa ff 	mov    %r14d,-0x550(%rbp,%r15,4)
 120e5e9:	ff 
 120e5ea:	e9 21 ff ff ff       	jmp    120e510 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1360>
 120e5ef:	90                   	nop
 120e5f0:	4c 89 f8             	mov    %r15,%rax
 120e5f3:	48 b9 25 23 22 84 e4 	movabs $0xcbf29ce484222325,%rcx
 120e5fa:	9c f2 cb 
 120e5fd:	48 31 c8             	xor    %rcx,%rax
 120e600:	48 ba b3 01 00 00 00 	movabs $0x100000001b3,%rdx
 120e607:	01 00 00 
 120e60a:	48 0f af c2          	imul   %rdx,%rax
 120e60e:	0f b6 4d 80          	movzbl -0x80(%rbp),%ecx
 120e612:	48 31 c1             	xor    %rax,%rcx
 120e615:	48 0f af ca          	imul   %rdx,%rcx
 120e619:	0f b6 45 81          	movzbl -0x7f(%rbp),%eax
 120e61d:	48 31 c8             	xor    %rcx,%rax
 120e620:	48 0f af c2          	imul   %rdx,%rax
 120e624:	0f b6 4d 82          	movzbl -0x7e(%rbp),%ecx
 120e628:	48 31 c1             	xor    %rax,%rcx
 120e62b:	48 0f af ca          	imul   %rdx,%rcx
 120e62f:	0f b6 45 83          	movzbl -0x7d(%rbp),%eax
 120e633:	48 31 c8             	xor    %rcx,%rax
 120e636:	48 0f af c2          	imul   %rdx,%rax
 120e63a:	0f b6 4d 84          	movzbl -0x7c(%rbp),%ecx
 120e63e:	48 31 c1             	xor    %rax,%rcx
 120e641:	48 0f af ca          	imul   %rdx,%rcx
 120e645:	0f b6 45 85          	movzbl -0x7b(%rbp),%eax
 120e649:	48 31 c8             	xor    %rcx,%rax
 120e64c:	48 0f af c2          	imul   %rdx,%rax
 120e650:	0f b6 4d 86          	movzbl -0x7a(%rbp),%ecx
 120e654:	48 31 c1             	xor    %rax,%rcx
 120e657:	48 0f af ca          	imul   %rdx,%rcx
 120e65b:	0f b6 45 87          	movzbl -0x79(%rbp),%eax
 120e65f:	48 31 c8             	xor    %rcx,%rax
 120e662:	48 0f af c2          	imul   %rdx,%rax
 120e666:	0f b6 4d 88          	movzbl -0x78(%rbp),%ecx
 120e66a:	48 31 c1             	xor    %rax,%rcx
 120e66d:	48 0f af ca          	imul   %rdx,%rcx
 120e671:	0f b6 45 89          	movzbl -0x77(%rbp),%eax
 120e675:	48 31 c8             	xor    %rcx,%rax
 120e678:	48 0f af c2          	imul   %rdx,%rax
 120e67c:	0f b6 4d 8a          	movzbl -0x76(%rbp),%ecx
 120e680:	48 31 c1             	xor    %rax,%rcx
 120e683:	48 0f af ca          	imul   %rdx,%rcx
 120e687:	0f b6 45 8b          	movzbl -0x75(%rbp),%eax
 120e68b:	48 31 c8             	xor    %rcx,%rax
 120e68e:	48 0f af c2          	imul   %rdx,%rax
 120e692:	0f b6 4d 8c          	movzbl -0x74(%rbp),%ecx
 120e696:	48 31 c1             	xor    %rax,%rcx
 120e699:	48 0f af ca          	imul   %rdx,%rcx
 120e69d:	0f b6 45 8d          	movzbl -0x73(%rbp),%eax
 120e6a1:	48 31 c8             	xor    %rcx,%rax
 120e6a4:	48 0f af c2          	imul   %rdx,%rax
 120e6a8:	0f b6 4d 8e          	movzbl -0x72(%rbp),%ecx
 120e6ac:	48 31 c1             	xor    %rax,%rcx
 120e6af:	48 0f af ca          	imul   %rdx,%rcx
 120e6b3:	0f b6 45 8f          	movzbl -0x71(%rbp),%eax
 120e6b7:	48 31 c8             	xor    %rcx,%rax
 120e6ba:	48 0f af c2          	imul   %rdx,%rax
 120e6be:	0f b6 4d 90          	movzbl -0x70(%rbp),%ecx
 120e6c2:	48 31 c1             	xor    %rax,%rcx
 120e6c5:	48 0f af ca          	imul   %rdx,%rcx
 120e6c9:	0f b6 45 91          	movzbl -0x6f(%rbp),%eax
 120e6cd:	48 31 c8             	xor    %rcx,%rax
 120e6d0:	48 0f af c2          	imul   %rdx,%rax
 120e6d4:	0f b6 4d 92          	movzbl -0x6e(%rbp),%ecx
 120e6d8:	48 31 c1             	xor    %rax,%rcx
 120e6db:	48 0f af ca          	imul   %rdx,%rcx
 120e6df:	0f b6 45 93          	movzbl -0x6d(%rbp),%eax
 120e6e3:	48 31 c8             	xor    %rcx,%rax
 120e6e6:	48 0f af c2          	imul   %rdx,%rax
 120e6ea:	0f b6 4d 94          	movzbl -0x6c(%rbp),%ecx
 120e6ee:	48 31 c1             	xor    %rax,%rcx
 120e6f1:	48 0f af ca          	imul   %rdx,%rcx
 120e6f5:	0f b6 45 95          	movzbl -0x6b(%rbp),%eax
 120e6f9:	48 31 c8             	xor    %rcx,%rax
 120e6fc:	48 0f af c2          	imul   %rdx,%rax
 120e700:	0f b6 4d 96          	movzbl -0x6a(%rbp),%ecx
 120e704:	48 31 c1             	xor    %rax,%rcx
 120e707:	48 0f af ca          	imul   %rdx,%rcx
 120e70b:	0f b6 45 97          	movzbl -0x69(%rbp),%eax
 120e70f:	48 31 c8             	xor    %rcx,%rax
 120e712:	48 0f af c2          	imul   %rdx,%rax
 120e716:	0f b6 4d 98          	movzbl -0x68(%rbp),%ecx
 120e71a:	48 31 c1             	xor    %rax,%rcx
 120e71d:	48 0f af ca          	imul   %rdx,%rcx
 120e721:	0f b6 45 99          	movzbl -0x67(%rbp),%eax
 120e725:	48 31 c8             	xor    %rcx,%rax
 120e728:	48 0f af c2          	imul   %rdx,%rax
 120e72c:	0f b6 4d 9a          	movzbl -0x66(%rbp),%ecx
 120e730:	48 31 c1             	xor    %rax,%rcx
 120e733:	48 0f af ca          	imul   %rdx,%rcx
 120e737:	0f b6 45 9b          	movzbl -0x65(%rbp),%eax
 120e73b:	48 31 c8             	xor    %rcx,%rax
 120e73e:	48 0f af c2          	imul   %rdx,%rax
 120e742:	0f b6 4d 9c          	movzbl -0x64(%rbp),%ecx
 120e746:	48 31 c1             	xor    %rax,%rcx
 120e749:	48 0f af ca          	imul   %rdx,%rcx
 120e74d:	0f b6 45 9d          	movzbl -0x63(%rbp),%eax
 120e751:	48 31 c8             	xor    %rcx,%rax
 120e754:	48 0f af c2          	imul   %rdx,%rax
 120e758:	0f b6 4d 9e          	movzbl -0x62(%rbp),%ecx
 120e75c:	48 31 c1             	xor    %rax,%rcx
 120e75f:	48 0f af ca          	imul   %rdx,%rcx
 120e763:	0f b6 45 9f          	movzbl -0x61(%rbp),%eax
 120e767:	48 31 c8             	xor    %rcx,%rax
 120e76a:	48 0f af c2          	imul   %rdx,%rax
 120e76e:	0f b6 4d a0          	movzbl -0x60(%rbp),%ecx
 120e772:	48 31 c1             	xor    %rax,%rcx
 120e775:	48 0f af ca          	imul   %rdx,%rcx
 120e779:	0f b6 45 a1          	movzbl -0x5f(%rbp),%eax
 120e77d:	48 31 c8             	xor    %rcx,%rax
 120e780:	48 0f af c2          	imul   %rdx,%rax
 120e784:	0f b6 4d a2          	movzbl -0x5e(%rbp),%ecx
 120e788:	48 31 c1             	xor    %rax,%rcx
 120e78b:	48 0f af ca          	imul   %rdx,%rcx
 120e78f:	0f b6 45 a3          	movzbl -0x5d(%rbp),%eax
 120e793:	48 31 c8             	xor    %rcx,%rax
 120e796:	48 0f af c2          	imul   %rdx,%rax
 120e79a:	0f b6 4d a4          	movzbl -0x5c(%rbp),%ecx
 120e79e:	48 31 c1             	xor    %rax,%rcx
 120e7a1:	48 0f af ca          	imul   %rdx,%rcx
 120e7a5:	0f b6 45 a5          	movzbl -0x5b(%rbp),%eax
 120e7a9:	48 31 c8             	xor    %rcx,%rax
 120e7ac:	48 0f af c2          	imul   %rdx,%rax
 120e7b0:	0f b6 4d a6          	movzbl -0x5a(%rbp),%ecx
 120e7b4:	48 31 c1             	xor    %rax,%rcx
 120e7b7:	48 0f af ca          	imul   %rdx,%rcx
 120e7bb:	0f b6 45 a7          	movzbl -0x59(%rbp),%eax
 120e7bf:	48 31 c8             	xor    %rcx,%rax
 120e7c2:	48 0f af c2          	imul   %rdx,%rax
 120e7c6:	0f b6 4d a8          	movzbl -0x58(%rbp),%ecx
 120e7ca:	48 31 c1             	xor    %rax,%rcx
 120e7cd:	48 0f af ca          	imul   %rdx,%rcx
 120e7d1:	0f b6 45 a9          	movzbl -0x57(%rbp),%eax
 120e7d5:	48 31 c8             	xor    %rcx,%rax
 120e7d8:	48 0f af c2          	imul   %rdx,%rax
 120e7dc:	0f b6 4d aa          	movzbl -0x56(%rbp),%ecx
 120e7e0:	48 31 c1             	xor    %rax,%rcx
 120e7e3:	48 0f af ca          	imul   %rdx,%rcx
 120e7e7:	0f b6 45 ab          	movzbl -0x55(%rbp),%eax
 120e7eb:	48 31 c8             	xor    %rcx,%rax
 120e7ee:	48 0f af c2          	imul   %rdx,%rax
 120e7f2:	0f b6 4d ac          	movzbl -0x54(%rbp),%ecx
 120e7f6:	48 31 c1             	xor    %rax,%rcx
 120e7f9:	48 0f af ca          	imul   %rdx,%rcx
 120e7fd:	0f b6 45 ad          	movzbl -0x53(%rbp),%eax
 120e801:	48 31 c8             	xor    %rcx,%rax
 120e804:	48 0f af c2          	imul   %rdx,%rax
 120e808:	0f b6 4d ae          	movzbl -0x52(%rbp),%ecx
 120e80c:	48 31 c1             	xor    %rax,%rcx
 120e80f:	48 0f af ca          	imul   %rdx,%rcx
 120e813:	0f b6 45 af          	movzbl -0x51(%rbp),%eax
 120e817:	48 31 c8             	xor    %rcx,%rax
 120e81a:	48 0f af c2          	imul   %rdx,%rax
 120e81e:	0f b6 4d b0          	movzbl -0x50(%rbp),%ecx
 120e822:	48 31 c1             	xor    %rax,%rcx
 120e825:	48 0f af ca          	imul   %rdx,%rcx
 120e829:	0f b6 45 b1          	movzbl -0x4f(%rbp),%eax
 120e82d:	48 31 c8             	xor    %rcx,%rax
 120e830:	48 0f af c2          	imul   %rdx,%rax
 120e834:	0f b6 4d b2          	movzbl -0x4e(%rbp),%ecx
 120e838:	48 31 c1             	xor    %rax,%rcx
 120e83b:	48 0f af ca          	imul   %rdx,%rcx
 120e83f:	0f b6 45 b3          	movzbl -0x4d(%rbp),%eax
 120e843:	48 31 c8             	xor    %rcx,%rax
 120e846:	48 0f af c2          	imul   %rdx,%rax
 120e84a:	0f b6 4d b4          	movzbl -0x4c(%rbp),%ecx
 120e84e:	48 31 c1             	xor    %rax,%rcx
 120e851:	48 0f af ca          	imul   %rdx,%rcx
 120e855:	0f b6 45 b5          	movzbl -0x4b(%rbp),%eax
 120e859:	48 31 c8             	xor    %rcx,%rax
 120e85c:	48 0f af c2          	imul   %rdx,%rax
 120e860:	0f b6 4d b6          	movzbl -0x4a(%rbp),%ecx
 120e864:	48 31 c1             	xor    %rax,%rcx
 120e867:	48 0f af ca          	imul   %rdx,%rcx
 120e86b:	0f b6 45 b7          	movzbl -0x49(%rbp),%eax
 120e86f:	48 31 c8             	xor    %rcx,%rax
 120e872:	48 0f af c2          	imul   %rdx,%rax
 120e876:	0f b6 4d b8          	movzbl -0x48(%rbp),%ecx
 120e87a:	48 31 c1             	xor    %rax,%rcx
 120e87d:	48 0f af ca          	imul   %rdx,%rcx
 120e881:	0f b6 45 b9          	movzbl -0x47(%rbp),%eax
 120e885:	48 31 c8             	xor    %rcx,%rax
 120e888:	48 0f af c2          	imul   %rdx,%rax
 120e88c:	0f b6 4d ba          	movzbl -0x46(%rbp),%ecx
 120e890:	48 31 c1             	xor    %rax,%rcx
 120e893:	48 0f af ca          	imul   %rdx,%rcx
 120e897:	0f b6 45 bb          	movzbl -0x45(%rbp),%eax
 120e89b:	48 31 c8             	xor    %rcx,%rax
 120e89e:	48 0f af c2          	imul   %rdx,%rax
 120e8a2:	0f b6 4d bc          	movzbl -0x44(%rbp),%ecx
 120e8a6:	48 31 c1             	xor    %rax,%rcx
 120e8a9:	48 0f af ca          	imul   %rdx,%rcx
 120e8ad:	0f b6 45 bd          	movzbl -0x43(%rbp),%eax
 120e8b1:	48 31 c8             	xor    %rcx,%rax
 120e8b4:	48 0f af c2          	imul   %rdx,%rax
 120e8b8:	0f b6 4d be          	movzbl -0x42(%rbp),%ecx
 120e8bc:	48 31 c1             	xor    %rax,%rcx
 120e8bf:	48 0f af ca          	imul   %rdx,%rcx
 120e8c3:	44 0f b6 75 bf       	movzbl -0x41(%rbp),%r14d
 120e8c8:	49 31 ce             	xor    %rcx,%r14
 120e8cb:	4c 0f af f2          	imul   %rdx,%r14
 120e8cf:	48 8b 9d c8 f3 ff ff 	mov    -0xc38(%rbp),%rbx
 120e8d6:	48 85 db             	test   %rbx,%rbx
 120e8d9:	4c 89 bd 70 ff ff ff 	mov    %r15,-0x90(%rbp)
 120e8e0:	74 5d                	je     120e93f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x178f>
 120e8e2:	c5 fe 6f 45 80       	vmovdqu -0x80(%rbp),%ymm0
 120e8e7:	c5 fe 6f 4d a0       	vmovdqu -0x60(%rbp),%ymm1
 120e8ec:	48 8d 85 38 ec ff ff 	lea    -0x13c8(%rbp),%rax
 120e8f3:	48 89 d9             	mov    %rbx,%rcx
 120e8f6:	eb 11                	jmp    120e909 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1759>
 120e8f8:	0f 1f 84 00 00 00 00 	nopl   0x0(%rax,%rax,1)
 120e8ff:	00 
 120e900:	48 83 c0 58          	add    $0x58,%rax
 120e904:	48 ff c9             	dec    %rcx
 120e907:	74 36                	je     120e93f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x178f>
 120e909:	4c 39 30             	cmp    %r14,(%rax)
 120e90c:	75 f2                	jne    120e900 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1750>
 120e90e:	0f b6 50 10          	movzbl 0x10(%rax),%edx
 120e912:	83 e2 7f             	and    $0x7f,%edx
 120e915:	49 39 d7             	cmp    %rdx,%r15
 120e918:	75 e6                	jne    120e900 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1750>
 120e91a:	c5 fd ef 50 11       	vpxor  0x11(%rax),%ymm0,%ymm2
 120e91f:	c5 f5 ef 58 31       	vpxor  0x31(%rax),%ymm1,%ymm3
 120e924:	c5 ed eb d3          	vpor   %ymm3,%ymm2,%ymm2
 120e928:	c4 e2 7d 17 d2       	vptest %ymm2,%ymm2
 120e92d:	75 d1                	jne    120e900 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1750>
 120e92f:	4c 8b 78 08          	mov    0x8(%rax),%r15
 120e933:	48 ff 85 d0 f3 ff ff 	incq   -0xc30(%rbp)
 120e93a:	e9 d2 00 00 00       	jmp    120ea11 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1861>
 120e93f:	4c 8d a5 38 6c fe ff 	lea    -0x193c8(%rbp),%r12
 120e946:	4d 89 fd             	mov    %r15,%r13
 120e949:	45 31 ff             	xor    %r15d,%r15d
 120e94c:	48 89 f1             	mov    %rsi,%rcx
 120e94f:	90                   	nop
 120e950:	48 8d bd 50 fe ff ff 	lea    -0x1b0(%rbp),%rdi
 120e957:	4c 89 e6             	mov    %r12,%rsi
 120e95a:	48 8b 55 10          	mov    0x10(%rbp),%rdx
 120e95e:	c5 f8 77             	vzeroupper 
 120e961:	e8 0a dd ff ff       	call   120c670 <br.encoder.literal_context_split.treeBitCostCached__anon_46145>
 120e966:	0f b7 85 58 fe ff ff 	movzwl -0x1a8(%rbp),%eax
 120e96d:	66 85 c0             	test   %ax,%ax
 120e970:	0f 85 21 03 00 00    	jne    120ec97 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1ae7>
 120e976:	4c 03 bd 50 fe ff ff 	add    -0x1b0(%rbp),%r15
 120e97d:	49 81 c4 00 04 00 00 	add    $0x400,%r12
 120e984:	49 ff cd             	dec    %r13
 120e987:	48 8b 4d 18          	mov    0x18(%rbp),%rcx
 120e98b:	75 c3                	jne    120e950 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x17a0>
 120e98d:	48 8d bd d8 f3 ff ff 	lea    -0xc28(%rbp),%rdi
 120e994:	48 8d 75 80          	lea    -0x80(%rbp),%rsi
 120e998:	48 8b 95 70 ff ff ff 	mov    -0x90(%rbp),%rdx
 120e99f:	e8 bc 64 f7 ff       	call   1184e60 <br.encoder.context_map.choose>
 120e9a4:	0f b7 85 a8 f6 ff ff 	movzwl -0x958(%rbp),%eax
 120e9ab:	66 85 c0             	test   %ax,%ax
 120e9ae:	0f 85 e3 02 00 00    	jne    120ec97 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1ae7>
 120e9b4:	4c 03 bd 80 f4 ff ff 	add    -0xb80(%rbp),%r15
 120e9bb:	48 6b c3 58          	imul   $0x58,%rbx,%rax
 120e9bf:	4c 89 b4 05 38 ec ff 	mov    %r14,-0x13c8(%rbp,%rax,1)
 120e9c6:	ff 
 120e9c7:	48 8b 8d 70 ff ff ff 	mov    -0x90(%rbp),%rcx
 120e9ce:	80 e1 7f             	and    $0x7f,%cl
 120e9d1:	88 8c 05 48 ec ff ff 	mov    %cl,-0x13b8(%rbp,%rax,1)
 120e9d8:	c5 fc 10 45 80       	vmovups -0x80(%rbp),%ymm0
 120e9dd:	c5 fc 11 84 05 49 ec 	vmovups %ymm0,-0x13b7(%rbp,%rax,1)
 120e9e4:	ff ff 
 120e9e6:	c5 fe 6f 45 a0       	vmovdqu -0x60(%rbp),%ymm0
 120e9eb:	c5 fe 7f 84 05 69 ec 	vmovdqu %ymm0,-0x1397(%rbp,%rax,1)
 120e9f2:	ff ff 
 120e9f4:	4c 89 bc 05 40 ec ff 	mov    %r15,-0x13c0(%rbp,%rax,1)
 120e9fb:	ff 
 120e9fc:	48 ff c3             	inc    %rbx
 120e9ff:	48 89 9d c8 f3 ff ff 	mov    %rbx,-0xc38(%rbp)
 120ea06:	4c 8b 6d 10          	mov    0x10(%rbp),%r13
 120ea0a:	49 c7 c4 ff ff ff ff 	mov    $0xffffffffffffffff,%r12
 120ea11:	48 8b 8d f0 fe ff ff 	mov    -0x110(%rbp),%rcx
 120ea18:	4c 29 f9             	sub    %r15,%rcx
 120ea1b:	b8 00 00 00 00       	mov    $0x0,%eax
 120ea20:	48 0f 43 c1          	cmovae %rcx,%rax
 120ea24:	48 3d 80 00 00 00    	cmp    $0x80,%rax
 120ea2a:	4c 8b 95 58 ff ff ff 	mov    -0xa8(%rbp),%r10
 120ea31:	48 8b 9d e8 fe ff ff 	mov    -0x118(%rbp),%rbx
 120ea38:	48 8b bd 70 ff ff ff 	mov    -0x90(%rbp),%rdi
 120ea3f:	0f 82 bb ed ff ff    	jb     120d800 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x650>
 120ea45:	8b 8d 54 ff ff ff    	mov    -0xac(%rbp),%ecx
 120ea4b:	80 e1 03             	and    $0x3,%cl
 120ea4e:	88 4d c8             	mov    %cl,-0x38(%rbp)
 120ea51:	40 80 e7 7f          	and    $0x7f,%dil
 120ea55:	c5 fe 6f 45 80       	vmovdqu -0x80(%rbp),%ymm0
 120ea5a:	c5 fe 6f 4d a0       	vmovdqu -0x60(%rbp),%ymm1
 120ea5f:	c5 fe 7f 85 e0 fc ff 	vmovdqu %ymm0,-0x320(%rbp)
 120ea66:	ff 
 120ea67:	c5 fe 7f 8d 00 fd ff 	vmovdqu %ymm1,-0x300(%rbp)
 120ea6e:	ff 
 120ea6f:	c5 fe 7f 85 40 fc ff 	vmovdqu %ymm0,-0x3c0(%rbp)
 120ea76:	ff 
 120ea77:	c5 fe 7f 8d 60 fc ff 	vmovdqu %ymm1,-0x3a0(%rbp)
 120ea7e:	ff 
 120ea7f:	40 88 7d c6          	mov    %dil,-0x3a(%rbp)
 120ea83:	0f b7 95 6c ff ff ff 	movzwl -0x94(%rbp),%edx
 120ea8a:	48 8d b5 80 fc ff ff 	lea    -0x380(%rbp),%rsi
 120ea91:	66 89 56 04          	mov    %dx,0x4(%rsi)
 120ea95:	8b 95 68 ff ff ff    	mov    -0x98(%rbp),%edx
 120ea9b:	89 16                	mov    %edx,(%rsi)
 120ea9d:	80 7d d4 00          	cmpb   $0x0,-0x2c(%rbp)
 120eaa1:	74 17                	je     120eaba <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x190a>
 120eaa3:	48 3b 85 10 ff ff ff 	cmp    -0xf0(%rbp),%rax
 120eaaa:	77 0e                	ja     120eaba <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x190a>
 120eaac:	75 4c                	jne    120eafa <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x194a>
 120eaae:	0f b6 55 d5          	movzbl -0x2b(%rbp),%edx
 120eab2:	80 e2 7f             	and    $0x7f,%dl
 120eab5:	40 38 d7             	cmp    %dl,%dil
 120eab8:	73 40                	jae    120eafa <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x194a>
 120eaba:	48 8b 95 7e fc ff ff 	mov    -0x382(%rbp),%rdx
 120eac1:	48 89 95 fe fd ff ff 	mov    %rdx,-0x202(%rbp)
 120eac8:	c5 fe 6f 85 40 fc ff 	vmovdqu -0x3c0(%rbp),%ymm0
 120eacf:	ff 
 120ead0:	c5 fe 6f 8d 60 fc ff 	vmovdqu -0x3a0(%rbp),%ymm1
 120ead7:	ff 
 120ead8:	c5 fe 7f 8d e0 fd ff 	vmovdqu %ymm1,-0x220(%rbp)
 120eadf:	ff 
 120eae0:	c5 fe 7f 85 c0 fd ff 	vmovdqu %ymm0,-0x240(%rbp)
 120eae7:	ff 
 120eae8:	c6 45 d4 01          	movb   $0x1,-0x2c(%rbp)
 120eaec:	40 88 7d d5          	mov    %dil,-0x2b(%rbp)
 120eaf0:	88 4d d2             	mov    %cl,-0x2e(%rbp)
 120eaf3:	48 89 85 10 ff ff ff 	mov    %rax,-0xf0(%rbp)
 120eafa:	49 83 fa 10          	cmp    $0x10,%r10
 120eafe:	0f 87 2b ed ff ff    	ja     120d82f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x67f>
 120eb04:	c5 fe 6f 85 e0 fc ff 	vmovdqu -0x320(%rbp),%ymm0
 120eb0b:	ff 
 120eb0c:	c5 fe 6f 8d 00 fd ff 	vmovdqu -0x300(%rbp),%ymm1
 120eb13:	ff 
 120eb14:	c5 fe 7f 8d 10 fc ff 	vmovdqu %ymm1,-0x3f0(%rbp)
 120eb1b:	ff 
 120eb1c:	c5 fe 7f 85 f0 fb ff 	vmovdqu %ymm0,-0x410(%rbp)
 120eb23:	ff 
 120eb24:	0f b7 95 6c ff ff ff 	movzwl -0x94(%rbp),%edx
 120eb2b:	48 8d b5 30 fc ff ff 	lea    -0x3d0(%rbp),%rsi
 120eb32:	66 89 56 04          	mov    %dx,0x4(%rsi)
 120eb36:	8b 95 68 ff ff ff    	mov    -0x98(%rbp),%edx
 120eb3c:	89 16                	mov    %edx,(%rsi)
 120eb3e:	80 7d d6 00          	cmpb   $0x0,-0x2a(%rbp)
 120eb42:	74 1f                	je     120eb63 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x19b3>
 120eb44:	48 3b 85 18 ff ff ff 	cmp    -0xe8(%rbp),%rax
 120eb4b:	77 16                	ja     120eb63 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x19b3>
 120eb4d:	0f 85 dc ec ff ff    	jne    120d82f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x67f>
 120eb53:	0f b6 55 d7          	movzbl -0x29(%rbp),%edx
 120eb57:	80 e2 7f             	and    $0x7f,%dl
 120eb5a:	40 38 d7             	cmp    %dl,%dil
 120eb5d:	0f 83 cc ec ff ff    	jae    120d82f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x67f>
 120eb63:	48 8b 95 2e fc ff ff 	mov    -0x3d2(%rbp),%rdx
 120eb6a:	48 89 95 ae fd ff ff 	mov    %rdx,-0x252(%rbp)
 120eb71:	c5 fe 6f 85 f0 fb ff 	vmovdqu -0x410(%rbp),%ymm0
 120eb78:	ff 
 120eb79:	c5 fe 6f 8d 10 fc ff 	vmovdqu -0x3f0(%rbp),%ymm1
 120eb80:	ff 
 120eb81:	c5 fe 7f 8d 90 fd ff 	vmovdqu %ymm1,-0x270(%rbp)
 120eb88:	ff 
 120eb89:	c5 fe 7f 85 70 fd ff 	vmovdqu %ymm0,-0x290(%rbp)
 120eb90:	ff 
 120eb91:	c6 45 d6 01          	movb   $0x1,-0x2a(%rbp)
 120eb95:	40 88 7d d7          	mov    %dil,-0x29(%rbp)
 120eb99:	88 4d d3             	mov    %cl,-0x2d(%rbp)
 120eb9c:	48 89 85 18 ff ff ff 	mov    %rax,-0xe8(%rbp)
 120eba3:	e9 87 ec ff ff       	jmp    120d82f <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x67f>
 120eba8:	48 83 e7 fc          	and    $0xfffffffffffffffc,%rdi
 120ebac:	31 c9                	xor    %ecx,%ecx
 120ebae:	31 f6                	xor    %esi,%esi
 120ebb0:	eb 28                	jmp    120ebda <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1a2a>
 120ebb2:	66 66 66 66 66 2e 0f 	data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 120ebb9:	1f 84 00 00 00 00 00 
 120ebc0:	31 d2                	xor    %edx,%edx
 120ebc2:	49 f7 f1             	div    %r9
 120ebc5:	42 88 44 05 80       	mov    %al,-0x80(%rbp,%r8,1)
 120ebca:	48 83 c6 04          	add    $0x4,%rsi
 120ebce:	48 01 d9             	add    %rbx,%rcx
 120ebd1:	48 39 f7             	cmp    %rsi,%rdi
 120ebd4:	0f 84 5c ed ff ff    	je     120d936 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x786>
 120ebda:	44 0f b6 84 35 60 fe 	movzbl -0x1a0(%rbp,%rsi,1),%r8d
 120ebe1:	ff ff 
 120ebe3:	48 89 c8             	mov    %rcx,%rax
 120ebe6:	4c 8b 8d 78 ff ff ff 	mov    -0x88(%rbp),%r9
 120ebed:	4c 09 c8             	or     %r9,%rax
 120ebf0:	48 c1 e8 20          	shr    $0x20,%rax
 120ebf4:	74 0a                	je     120ec00 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1a50>
 120ebf6:	48 89 c8             	mov    %rcx,%rax
 120ebf9:	31 d2                	xor    %edx,%edx
 120ebfb:	49 f7 f1             	div    %r9
 120ebfe:	eb 07                	jmp    120ec07 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1a57>
 120ec00:	89 c8                	mov    %ecx,%eax
 120ec02:	31 d2                	xor    %edx,%edx
 120ec04:	41 f7 f1             	div    %r9d
 120ec07:	42 88 44 05 80       	mov    %al,-0x80(%rbp,%r8,1)
 120ec0c:	44 0f b6 84 35 61 fe 	movzbl -0x19f(%rbp,%rsi,1),%r8d
 120ec13:	ff ff 
 120ec15:	49 8d 04 0a          	lea    (%r10,%rcx,1),%rax
 120ec19:	48 89 c2             	mov    %rax,%rdx
 120ec1c:	4c 09 ca             	or     %r9,%rdx
 120ec1f:	48 c1 ea 20          	shr    $0x20,%rdx
 120ec23:	74 0b                	je     120ec30 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1a80>
 120ec25:	31 d2                	xor    %edx,%edx
 120ec27:	49 f7 f1             	div    %r9
 120ec2a:	eb 09                	jmp    120ec35 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1a85>
 120ec2c:	0f 1f 40 00          	nopl   0x0(%rax)
 120ec30:	31 d2                	xor    %edx,%edx
 120ec32:	41 f7 f1             	div    %r9d
 120ec35:	42 88 44 05 80       	mov    %al,-0x80(%rbp,%r8,1)
 120ec3a:	44 0f b6 84 35 62 fe 	movzbl -0x19e(%rbp,%rsi,1),%r8d
 120ec41:	ff ff 
 120ec43:	48 8b 85 c8 fe ff ff 	mov    -0x138(%rbp),%rax
 120ec4a:	48 01 c8             	add    %rcx,%rax
 120ec4d:	48 89 c2             	mov    %rax,%rdx
 120ec50:	4c 09 ca             	or     %r9,%rdx
 120ec53:	48 c1 ea 20          	shr    $0x20,%rdx
 120ec57:	74 07                	je     120ec60 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1ab0>
 120ec59:	31 d2                	xor    %edx,%edx
 120ec5b:	49 f7 f1             	div    %r9
 120ec5e:	eb 05                	jmp    120ec65 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1ab5>
 120ec60:	31 d2                	xor    %edx,%edx
 120ec62:	41 f7 f1             	div    %r9d
 120ec65:	42 88 44 05 80       	mov    %al,-0x80(%rbp,%r8,1)
 120ec6a:	44 0f b6 84 35 63 fe 	movzbl -0x19d(%rbp,%rsi,1),%r8d
 120ec71:	ff ff 
 120ec73:	48 8b 85 c0 fe ff ff 	mov    -0x140(%rbp),%rax
 120ec7a:	48 01 c8             	add    %rcx,%rax
 120ec7d:	48 89 c2             	mov    %rax,%rdx
 120ec80:	4c 09 ca             	or     %r9,%rdx
 120ec83:	48 c1 ea 20          	shr    $0x20,%rdx
 120ec87:	0f 85 33 ff ff ff    	jne    120ebc0 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1a10>
 120ec8d:	31 d2                	xor    %edx,%edx
 120ec8f:	41 f7 f1             	div    %r9d
 120ec92:	e9 2e ff ff ff       	jmp    120ebc5 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1a15>
 120ec97:	48 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%rcx
 120ec9e:	66 89 81 08 01 00 00 	mov    %ax,0x108(%rcx)
 120eca5:	e9 3b 01 00 00       	jmp    120ede5 <br.encoder.literal_context_split.chooseModeFromHistograms__anon_46230+0x1c35>
 120ecaa:	48 8b 8d 38 ff ff ff 	mov    -0xc8(%rbp),%rcx
 120ecb1:	66 c7 81 08 01 00 00 	movw   $0x0,0x108(%rcx)
 120ecb8:	00 00 
 120ecba:	48 8b 85 20 ff ff ff 	mov    -0xe0(%rbp),%rax
 120ecc1:	48 89 01             	mov    %rax,(%rcx)
 120ecc4:	48 8b 85 30 ff ff ff 	mov    -0xd0(%rbp),%rax
 120eccb:	88 41 08             	mov    %al,0x8(%rcx)
 120ecce:	48 8b 85 28 ff ff ff 	mov    -0xd8(%rbp),%rax
 120ecd5:	88 41 09             	mov    %al,0x9(%rcx)
 120ecd8:	c5 fc 10 85 90 fc ff 	vmovups -0x370(%rbp),%ymm0
 120ecdf:	ff 
 120ece0:	c5 fc 11 41 0a       	vmovups %ymm0,0xa(%rcx)
 120ece5:	c5 fc 10 85 b0 fc ff 	vmovups -0x350(%rbp),%ymm0
 120ecec:	ff 
 120eced:	c5 fc 11 41 2a       	vmovups %ymm0,0x2a(%rcx)
 120ecf2:	48 8b 85 ce fc ff ff 	mov    -0x332(%rbp),%rax
 120ecf9:	48 89 41 48          	mov    %rax,0x48(%rcx)
 120ecfd:	48 8b 85 60 ff ff ff 	mov    -0xa0(%rbp),%rax
 120ed04:	88 41 50             	mov    %al,0x50(%rcx)
 120ed07:	c7 41 51 00 00 00 00 	movl   $0x0,0x51(%rcx)
 120ed0e:	c7 41 54 00 00 00 00 	movl   $0x0,0x54(%rcx)
 120ed15:	48 8b 85 18 ff ff ff 	mov    -0xe8(%rbp),%rax
 120ed1c:	48 89 41 58          	mov    %rax,0x58(%rcx)
 120ed20:	0f b6 45 d3          	movzbl -0x2d(%rbp),%eax
 120ed24:	88 41 60             	mov    %al,0x60(%rcx)
 120ed27:	0f b6 45 d7          	movzbl -0x29(%rbp),%eax
 120ed2b:	88 41 61             	mov    %al,0x61(%rcx)
 120ed2e:	c5 fc 10 85 70 fd ff 	vmovups -0x290(%rbp),%ymm0
 120ed35:	ff 
 120ed36:	c5 fe 6f 8d 90 fd ff 	vmovdqu -0x270(%rbp),%ymm1
 120ed3d:	ff 
 120ed3e:	c5 fc 11 41 62       	vmovups %ymm0,0x62(%rcx)
 120ed43:	c5 fe 7f 89 82 00 00 	vmovdqu %ymm1,0x82(%rcx)
 120ed4a:	00 
 120ed4b:	48 8b 85 ae fd ff ff 	mov    -0x252(%rbp),%rax
 120ed52:	48 89 81 a0 00 00 00 	mov    %rax,0xa0(%rcx)
 120ed59:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 120ed5d:	88 81 a8 00 00 00    	mov    %al,0xa8(%rcx)
 120ed63:	c7 81 ac 00 00 00 00 	movl   $0x0,0xac(%rcx)
 120ed6a:	00 00 00 
 120ed6d:	c7 81 a9 00 00 00 00 	movl   $0x0,0xa9(%rcx)
 120ed74:	00 00 00 
 120ed77:	48 8b 85 10 ff ff ff 	mov    -0xf0(%rbp),%rax
 120ed7e:	48 89 81 b0 00 00 00 	mov    %rax,0xb0(%rcx)
 120ed85:	0f b6 45 d2          	movzbl -0x2e(%rbp),%eax
 120ed89:	88 81 b8 00 00 00    	mov    %al,0xb8(%rcx)
 120ed8f:	0f b6 45 d5          	movzbl -0x2b(%rbp),%eax
 120ed93:	88 81 b9 00 00 00    	mov    %al,0xb9(%rcx)
 120ed99:	48 8b 85 fe fd ff ff 	mov    -0x202(%rbp),%rax
 120eda0:	48 89 81 f8 00 00 00 	mov    %rax,0xf8(%rcx)
 120eda7:	c5 fc 10 85 e0 fd ff 	vmovups -0x220(%rbp),%ymm0
 120edae:	ff 
 120edaf:	c5 fc 11 81 da 00 00 	vmovups %ymm0,0xda(%rcx)
 120edb6:	00 
 120edb7:	c5 fe 6f 85 c0 fd ff 	vmovdqu -0x240(%rbp),%ymm0
 120edbe:	ff 
 120edbf:	c5 fe 7f 81 ba 00 00 	vmovdqu %ymm0,0xba(%rcx)
 120edc6:	00 
 120edc7:	0f b6 45 d4          	movzbl -0x2c(%rbp),%eax
 120edcb:	88 81 00 01 00 00    	mov    %al,0x100(%rcx)
 120edd1:	c7 81 04 01 00 00 00 	movl   $0x0,0x104(%rcx)
 120edd8:	00 00 00 
 120eddb:	c7 81 01 01 00 00 00 	movl   $0x0,0x101(%rcx)
 120ede2:	00 00 00 
 120ede5:	48 81 c4 a8 d5 02 00 	add    $0x2d5a8,%rsp
 120edec:	5b                   	pop    %rbx
 120eded:	41 5c                	pop    %r12
 120edef:	41 5d                	pop    %r13
 120edf1:	41 5e                	pop    %r14
 120edf3:	41 5f                	pop    %r15
 120edf5:	5d                   	pop    %rbp
 120edf6:	c5 f8 77             	vzeroupper 
 120edf9:	c3                   	ret    

Disassembly of section .init:

Disassembly of section .fini:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_large_window:

Disassembly of section .plt:
