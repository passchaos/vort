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
