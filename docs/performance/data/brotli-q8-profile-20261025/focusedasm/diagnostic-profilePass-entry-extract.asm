 11471f5:	48 8d b5 b0 fe ff ff 	lea    -0x150(%rbp),%rsi
 11471fc:	31 d2                	xor    %edx,%edx
 11471fe:	4c 89 f1             	mov    %r14,%rcx
 1147201:	45 31 c0             	xor    %r8d,%r8d
 1147204:	e8 87 03 13 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 1147209:	49 81 fe 01 00 01 00 	cmp    $0x10001,%r14
 1147210:	72 30                	jb     1147242 <quality_stage_profile.profilePass+0x202>
 1147212:	48 c7 83 98 30 02 00 	movq   $0x112bb24,0x23098(%rbx)
 1147219:	24 bb 12 01 
 114721d:	48 c7 83 a0 30 02 00 	movq   $0x10,0x230a0(%rbx)
 1147224:	10 00 00 00 
 1147228:	66 41 be 52 00       	mov    $0x52,%r14w
 114722d:	80 bd 28 ff ff ff 00 	cmpb   $0x0,-0xd8(%rbp)
 1147234:	74 74                	je     11472aa <quality_stage_profile.profilePass+0x26a>
 1147236:	b8 24 bb 12 01       	mov    $0x112bb24,%eax
 114723b:	b9 10 00 00 00       	mov    $0x10,%ecx
 1147240:	eb 4c                	jmp    114728e <quality_stage_profile.profilePass+0x24e>
 1147242:	66 b9 43 00          	mov    $0x43,%cx
 1147246:	31 c0                	xor    %eax,%eax
 1147248:	84 c0                	test   %al,%al
 114724a:	75 13                	jne    114725f <quality_stage_profile.profilePass+0x21f>
 114724c:	31 c0                	xor    %eax,%eax
 114724e:	84 c0                	test   %al,%al
 1147250:	75 0d                	jne    114725f <quality_stage_profile.profilePass+0x21f>
 1147252:	66 b9 52 00          	mov    $0x52,%cx
 1147256:	f6 05 5d a2 ec ff 03 	testb  $0x3,-0x135da3(%rip)        # 10114ba <__anon_3224+0x82>
 114725d:	74 72                	je     11472d1 <quality_stage_profile.profilePass+0x291>
 114725f:	49 89 ce             	mov    %rcx,%r14
 1147262:	41 0f b7 ce          	movzwl %r14w,%ecx
 1147266:	c1 e1 04             	shl    $0x4,%ecx
 1147269:	48 8b 81 f0 5d 03 01 	mov    0x1035df0(%rcx),%rax
 1147270:	48 8b 89 f8 5d 03 01 	mov    0x1035df8(%rcx),%rcx
 1147277:	48 89 83 98 30 02 00 	mov    %rax,0x23098(%rbx)
 114727e:	48 89 8b a0 30 02 00 	mov    %rcx,0x230a0(%rbx)
 1147285:	80 bd 28 ff ff ff 00 	cmpb   $0x0,-0xd8(%rbp)
 114728c:	74 1c                	je     11472aa <quality_stage_profile.profilePass+0x26a>
 114728e:	48 8b 95 10 ff ff ff 	mov    -0xf0(%rbp),%rdx
 1147295:	48 69 b5 20 ff ff ff 	imul   $0x118,-0xe0(%rbp),%rsi
 114729c:	18 01 00 00 
 11472a0:	48 89 44 32 68       	mov    %rax,0x68(%rdx,%rsi,1)
 11472a5:	48 89 4c 32 70       	mov    %rcx,0x70(%rdx,%rsi,1)
 11472aa:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 11472b1:	e8 ba fe 12 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11472b6:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 11472ba:	66 44 89 70 08       	mov    %r14w,0x8(%rax)
 11472bf:	48 81 c4 d8 01 00 00 	add    $0x1d8,%rsp
 11472c6:	5b                   	pop    %rbx
 11472c7:	41 5c                	pop    %r12
 11472c9:	41 5d                	pop    %r13
 11472cb:	41 5e                	pop    %r14
 11472cd:	41 5f                	pop    %r15
 11472cf:	5d                   	pop    %rbp
 11472d0:	c3                   	ret    
 11472d1:	48 8d 7d 80          	lea    -0x80(%rbp),%rdi
 11472d5:	be 38 14 01 01       	mov    $0x1011438,%esi
 11472da:	e8 e1 f6 12 00       	call   12769c0 <br.resolvedQualitySchedule>
 11472df:	0f b7 45 b4          	movzwl -0x4c(%rbp),%eax
 11472e3:	48 89 c1             	mov    %rax,%rcx
 11472e6:	66 85 c0             	test   %ax,%ax
 11472e9:	0f 85 70 ff ff ff    	jne    114725f <quality_stage_profile.profilePass+0x21f>
 11472ef:	c5 f8 10 03          	vmovups (%rbx),%xmm0
 11472f3:	c5 f8 29 85 50 fe ff 	vmovaps %xmm0,-0x1b0(%rbp)
 11472fa:	ff 
 11472fb:	48 8b 4b 10          	mov    0x10(%rbx),%rcx
 11472ff:	48 8d bd 18 fe ff ff 	lea    -0x1e8(%rbp),%rdi
 1147306:	48 8d 95 50 fe ff ff 	lea    -0x1b0(%rbp),%rdx
 114730d:	4c 89 ee             	mov    %r13,%rsi
 1147310:	45 31 c0             	xor    %r8d,%r8d
 1147313:	e8 48 fc 12 00       	call   1276f60 <br.encoder.total_budget.Lease.init>
 1147318:	0f b7 95 38 fe ff ff 	movzwl -0x1c8(%rbp),%edx
 114731f:	48 85 d2             	test   %rdx,%rdx
 1147322:	0f 85 5f 06 00 00    	jne    1147987 <quality_stage_profile.profilePass+0x947>
 1147328:	c5 fc 10 85 18 fe ff 	vmovups -0x1e8(%rbp),%ymm0
 114732f:	ff 
 1147330:	c5 fc 11 85 90 fe ff 	vmovups %ymm0,-0x170(%rbp)
 1147337:	ff 
 1147338:	c5 f8 28 85 60 fe ff 	vmovaps -0x1a0(%rbp),%xmm0
 114733f:	ff 
 1147340:	c5 f8 29 85 70 fe ff 	vmovaps %xmm0,-0x190(%rbp)
 1147347:	ff 
 1147348:	48 89 9d 80 fe ff ff 	mov    %rbx,-0x180(%rbp)
 114734f:	44 88 bd 88 fe ff ff 	mov    %r15b,-0x178(%rbp)
 1147356:	44 88 a5 89 fe ff ff 	mov    %r12b,-0x177(%rbp)
 114735d:	4c 8b bd a0 fe ff ff 	mov    -0x160(%rbp),%r15
 1147364:	4d 85 ff             	test   %r15,%r15
 1147367:	74 0e                	je     1147377 <quality_stage_profile.profilePass+0x337>
 1147369:	4c 89 7d 80          	mov    %r15,-0x80(%rbp)
 114736d:	48 c7 45 88 a8 f2 11 	movq   $0x111f2a8,-0x78(%rbp)
 1147374:	01 
 1147375:	eb 0d                	jmp    1147384 <quality_stage_profile.profilePass+0x344>
 1147377:	c5 f8 10 85 18 fe ff 	vmovups -0x1e8(%rbp),%xmm0
 114737e:	ff 
 114737f:	c5 f8 29 45 80       	vmovaps %xmm0,-0x80(%rbp)
 1147384:	48 8b 8d 60 ff ff ff 	mov    -0xa0(%rbp),%rcx
 114738b:	48 8d 45 80          	lea    -0x80(%rbp),%rax
 114738f:	c5 f8 10 00          	vmovups (%rax),%xmm0
 1147393:	c5 f8 29 85 40 fe ff 	vmovaps %xmm0,-0x1c0(%rbp)
 114739a:	ff 
 114739b:	48 8d bd d8 fe ff ff 	lea    -0x128(%rbp),%rdi
 11473a2:	48 8d b5 70 fe ff ff 	lea    -0x190(%rbp),%rsi
 11473a9:	48 8d 95 40 fe ff ff 	lea    -0x1c0(%rbp),%rdx
 11473b0:	41 b9 38 14 01 01    	mov    $0x1011438,%r9d
 11473b6:	4d 89 f0             	mov    %r14,%r8
 11473b9:	c5 f8 77             	vzeroupper 
 11473bc:	e8 1f ca 06 00       	call   11b3de0 <br.encodePlannedStreamQualityWithOptionsAllocRecorded__anon_28584>
 11473c1:	44 0f b7 b5 e8 fe ff 	movzwl -0x118(%rbp),%r14d
 11473c8:	ff 
 11473c9:	41 83 fe 1a          	cmp    $0x1a,%r14d
 11473cd:	74 48                	je     1147417 <quality_stage_profile.profilePass+0x3d7>
 11473cf:	45 85 f6             	test   %r14d,%r14d
 11473d2:	0f 85 c2 00 00 00    	jne    114749a <quality_stage_profile.profilePass+0x45a>
 11473d8:	48 8b b5 d8 fe ff ff 	mov    -0x128(%rbp),%rsi
 11473df:	4c 8b a5 e0 fe ff ff 	mov    -0x120(%rbp),%r12
 11473e6:	48 8b bd 90 fe ff ff 	mov    -0x170(%rbp),%rdi
 11473ed:	48 8b 85 98 fe ff ff 	mov    -0x168(%rbp),%rax
 11473f4:	4d 85 ff             	test   %r15,%r15
 11473f7:	0f 84 0e 01 00 00    	je     114750b <quality_stage_profile.profilePass+0x4cb>
 11473fd:	49 8b 4d 08          	mov    0x8(%r13),%rcx
