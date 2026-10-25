
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

0000000001147040 <quality_stage_profile.profilePass>:
 1147040:	55                   	push   %rbp
 1147041:	48 89 e5             	mov    %rsp,%rbp
 1147044:	41 57                	push   %r15
 1147046:	41 56                	push   %r14
 1147048:	41 55                	push   %r13
 114704a:	41 54                	push   %r12
 114704c:	53                   	push   %rbx
 114704d:	48 81 ec d8 01 00 00 	sub    $0x1d8,%rsp
 1147054:	4c 89 8d 50 ff ff ff 	mov    %r9,-0xb0(%rbp)
 114705b:	4d 89 c6             	mov    %r8,%r14
 114705e:	48 89 8d 60 ff ff ff 	mov    %rcx,-0xa0(%rbp)
 1147065:	49 89 d5             	mov    %rdx,%r13
 1147068:	49 89 f7             	mov    %rsi,%r15
 114706b:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 114706f:	48 8b 5d 18          	mov    0x18(%rbp),%rbx
 1147073:	48 8b 02             	mov    (%rdx),%rax
 1147076:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 114707d:	48 8b 42 08          	mov    0x8(%rdx),%rax
 1147081:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 1147088:	48 8b 36             	mov    (%rsi),%rsi
 114708b:	49 8b 47 08          	mov    0x8(%r15),%rax
 114708f:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 1147096:	ba 01 00 00 00       	mov    $0x1,%edx
 114709b:	ff 90 c0 02 00 00    	call   *0x2c0(%rax)
 11470a1:	48 8b 85 f0 fe ff ff 	mov    -0x110(%rbp),%rax
 11470a8:	48 89 85 58 ff ff ff 	mov    %rax,-0xa8(%rbp)
 11470af:	66 c7 83 d0 42 02 00 	movw   $0x100,0x242d0(%rbx)
 11470b6:	00 01 
 11470b8:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11470bc:	c5 f8 11 83 20 30 02 	vmovups %xmm0,0x23020(%rbx)
 11470c3:	00 
 11470c4:	48 c7 83 30 30 02 00 	movq   $0x0,0x23030(%rbx)
 11470cb:	00 00 00 00 
 11470cf:	c6 83 d2 42 02 00 01 	movb   $0x1,0x242d2(%rbx)
 11470d6:	c5 f8 57 c0          	vxorps %xmm0,%xmm0,%xmm0
 11470da:	c5 fc 11 83 38 30 02 	vmovups %ymm0,0x23038(%rbx)
 11470e1:	00 
 11470e2:	c5 fc 11 83 58 30 02 	vmovups %ymm0,0x23058(%rbx)
 11470e9:	00 
 11470ea:	c5 fc 11 83 78 30 02 	vmovups %ymm0,0x23078(%rbx)
 11470f1:	00 
 11470f2:	48 c7 83 98 30 02 00 	movq   $0x1139e8e,0x23098(%rbx)
 11470f9:	8e 9e 13 01 
 11470fd:	c5 fc 11 83 d3 42 02 	vmovups %ymm0,0x242d3(%rbx)
 1147104:	00 
 1147105:	c5 fc 11 83 f3 42 02 	vmovups %ymm0,0x242f3(%rbx)
 114710c:	00 
 114710d:	c5 fc 11 83 13 43 02 	vmovups %ymm0,0x24313(%rbx)
 1147114:	00 
 1147115:	c5 fc 11 83 33 43 02 	vmovups %ymm0,0x24333(%rbx)
 114711c:	00 
 114711d:	c5 fc 11 83 53 43 02 	vmovups %ymm0,0x24353(%rbx)
 1147124:	00 
 1147125:	c5 fc 11 83 73 43 02 	vmovups %ymm0,0x24373(%rbx)
 114712c:	00 
 114712d:	c5 fc 11 83 93 43 02 	vmovups %ymm0,0x24393(%rbx)
 1147134:	00 
 1147135:	c5 fc 11 83 b3 43 02 	vmovups %ymm0,0x243b3(%rbx)
 114713c:	00 
 114713d:	c5 fc 11 83 d3 43 02 	vmovups %ymm0,0x243d3(%rbx)
 1147144:	00 
 1147145:	c5 fc 11 83 f3 43 02 	vmovups %ymm0,0x243f3(%rbx)
 114714c:	00 
 114714d:	c5 fc 11 83 13 44 02 	vmovups %ymm0,0x24413(%rbx)
 1147154:	00 
 1147155:	c5 fc 11 83 33 44 02 	vmovups %ymm0,0x24433(%rbx)
 114715c:	00 
 114715d:	c5 fc 11 83 53 44 02 	vmovups %ymm0,0x24453(%rbx)
 1147164:	00 
 1147165:	c5 fc 11 83 73 44 02 	vmovups %ymm0,0x24473(%rbx)
 114716c:	00 
 114716d:	c5 fc 11 83 93 44 02 	vmovups %ymm0,0x24493(%rbx)
 1147174:	00 
 1147175:	48 8d bb c8 32 02 00 	lea    0x232c8(%rbx),%rdi
 114717c:	c5 fc 11 83 b3 44 02 	vmovups %ymm0,0x244b3(%rbx)
 1147183:	00 
 1147184:	c5 fc 11 83 a0 30 02 	vmovups %ymm0,0x230a0(%rbx)
 114718b:	00 
 114718c:	48 c7 83 c0 30 02 00 	movq   $0x0,0x230c0(%rbx)
 1147193:	00 00 00 00 
 1147197:	ba 08 10 00 00       	mov    $0x1008,%edx
 114719c:	31 f6                	xor    %esi,%esi
 114719e:	c5 f8 77             	vzeroupper 
 11471a1:	e8 9a 81 19 00       	call   12df340 <compiler_rt.memset>
 11471a6:	c4 c1 78 10 07       	vmovups (%r15),%xmm0
 11471ab:	c5 f8 29 85 60 fe ff 	vmovaps %xmm0,-0x1a0(%rbp)
 11471b2:	ff 
 11471b3:	c6 45 d0 00          	movb   $0x0,-0x30(%rbp)
 11471b7:	c6 45 cf 00          	movb   $0x0,-0x31(%rbp)
 11471bb:	4c 89 bd 68 ff ff ff 	mov    %r15,-0x98(%rbp)
 11471c2:	c4 c1 78 10 07       	vmovups (%r15),%xmm0
 11471c7:	c5 f8 29 85 b0 fe ff 	vmovaps %xmm0,-0x150(%rbp)
 11471ce:	ff 
 11471cf:	48 89 9d c0 fe ff ff 	mov    %rbx,-0x140(%rbp)
 11471d6:	44 0f b6 7d d0       	movzbl -0x30(%rbp),%r15d
 11471db:	44 88 bd c8 fe ff ff 	mov    %r15b,-0x138(%rbp)
 11471e2:	44 0f b6 65 cf       	movzbl -0x31(%rbp),%r12d
 11471e7:	44 88 a5 c9 fe ff ff 	mov    %r12b,-0x137(%rbp)
 11471ee:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
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
 1147401:	48 81 f9 a8 f2 11 01 	cmp    $0x111f2a8,%rcx
 1147408:	0f 85 0d 01 00 00    	jne    114751b <quality_stage_profile.profilePass+0x4db>
 114740e:	49 8b 55 00          	mov    0x0(%r13),%rdx
 1147412:	e9 06 01 00 00       	jmp    114751d <quality_stage_profile.profilePass+0x4dd>
 1147417:	4d 85 ff             	test   %r15,%r15
 114741a:	0f 84 f1 00 00 00    	je     1147511 <quality_stage_profile.profilePass+0x4d1>
 1147420:	45 0f b6 77 49       	movzbl 0x49(%r15),%r14d
 1147425:	41 c1 e6 06          	shl    $0x6,%r14d
 1147429:	41 83 ce 1a          	or     $0x1a,%r14d
 114742d:	49 ff 4f 40          	decq   0x40(%r15)
 1147431:	0f 85 2b fe ff ff    	jne    1147262 <quality_stage_profile.profilePass+0x222>
 1147437:	49 8b 47 28          	mov    0x28(%r15),%rax
 114743b:	48 83 f8 50          	cmp    $0x50,%rax
 114743f:	0f 85 c0 02 00 00    	jne    1147705 <quality_stage_profile.profilePass+0x6c5>
 1147445:	49 83 7f 38 00       	cmpq   $0x0,0x38(%r15)
 114744a:	0f 85 12 fe ff ff    	jne    1147262 <quality_stage_profile.profilePass+0x222>
 1147450:	49 8b 3f             	mov    (%r15),%rdi
 1147453:	49 8b 47 08          	mov    0x8(%r15),%rax
 1147457:	49 8b 4f 20          	mov    0x20(%r15),%rcx
 114745b:	48 85 c9             	test   %rcx,%rcx
 114745e:	74 21                	je     1147481 <quality_stage_profile.profilePass+0x441>
 1147460:	c4 c1 78 10 47 10    	vmovups 0x10(%r15),%xmm0
 1147466:	c5 f8 29 45 80       	vmovaps %xmm0,-0x80(%rbp)
 114746b:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 114746f:	48 c7 41 08 00 00 00 	movq   $0x0,0x8(%rcx)
 1147476:	00 
 1147477:	c5 f8 28 45 80       	vmovaps -0x80(%rbp),%xmm0
 114747c:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 1147481:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1147485:	ba 50 00 00 00       	mov    $0x50,%edx
 114748a:	4c 89 fe             	mov    %r15,%rsi
 114748d:	b9 03 00 00 00       	mov    $0x3,%ecx
 1147492:	ff 50 18             	call   *0x18(%rax)
 1147495:	e9 c8 fd ff ff       	jmp    1147262 <quality_stage_profile.profilePass+0x222>
 114749a:	4d 85 ff             	test   %r15,%r15
 114749d:	74 0a                	je     11474a9 <quality_stage_profile.profilePass+0x469>
 114749f:	49 ff 4f 40          	decq   0x40(%r15)
 11474a3:	0f 84 37 01 00 00    	je     11475e0 <quality_stage_profile.profilePass+0x5a0>
 11474a9:	44 89 f1             	mov    %r14d,%ecx
 11474ac:	c1 e1 04             	shl    $0x4,%ecx
 11474af:	48 8b 81 f0 5d 03 01 	mov    0x1035df0(%rcx),%rax
 11474b6:	48 8b 89 f8 5d 03 01 	mov    0x1035df8(%rcx),%rcx
 11474bd:	48 89 83 98 30 02 00 	mov    %rax,0x23098(%rbx)
 11474c4:	48 89 8b a0 30 02 00 	mov    %rcx,0x230a0(%rbx)
 11474cb:	80 bd 28 ff ff ff 00 	cmpb   $0x0,-0xd8(%rbp)
 11474d2:	74 1c                	je     11474f0 <quality_stage_profile.profilePass+0x4b0>
 11474d4:	48 8b 95 10 ff ff ff 	mov    -0xf0(%rbp),%rdx
 11474db:	48 69 b5 20 ff ff ff 	imul   $0x118,-0xe0(%rbp),%rsi
 11474e2:	18 01 00 00 
 11474e6:	48 89 44 32 68       	mov    %rax,0x68(%rdx,%rsi,1)
 11474eb:	48 89 4c 32 70       	mov    %rcx,0x70(%rdx,%rsi,1)
 11474f0:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 11474f7:	e8 74 fc 12 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 11474fc:	66 45 85 f6          	test   %r14w,%r14w
 1147500:	0f 85 b0 fd ff ff    	jne    11472b6 <quality_stage_profile.profilePass+0x276>
 1147506:	e9 fa 02 00 00       	jmp    1147805 <quality_stage_profile.profilePass+0x7c5>
 114750b:	49 8b 4d 08          	mov    0x8(%r13),%rcx
 114750f:	eb 15                	jmp    1147526 <quality_stage_profile.profilePass+0x4e6>
 1147511:	66 41 be 1a 00       	mov    $0x1a,%r14w
 1147516:	e9 47 fd ff ff       	jmp    1147262 <quality_stage_profile.profilePass+0x222>
 114751b:	31 d2                	xor    %edx,%edx
 114751d:	4c 39 fa             	cmp    %r15,%rdx
 1147520:	0f 84 25 01 00 00    	je     114764b <quality_stage_profile.profilePass+0x60b>
 1147526:	48 39 c8             	cmp    %rcx,%rax
 1147529:	74 34                	je     114755f <quality_stage_profile.profilePass+0x51f>
 114752b:	4d 85 e4             	test   %r12,%r12
 114752e:	74 1e                	je     114754e <quality_stage_profile.profilePass+0x50e>
 1147530:	4d 85 ff             	test   %r15,%r15
 1147533:	49 0f 45 ff          	cmovne %r15,%rdi
 1147537:	41 b9 a8 f2 11 01    	mov    $0x111f2a8,%r9d
 114753d:	4c 0f 44 c8          	cmove  %rax,%r9
 1147541:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1147545:	4c 89 e2             	mov    %r12,%rdx
 1147548:	31 c9                	xor    %ecx,%ecx
 114754a:	41 ff 51 18          	call   *0x18(%r9)
 114754e:	48 8d bd 90 fe ff ff 	lea    -0x170(%rbp),%rdi
 1147555:	e8 26 40 06 00       	call   11ab580 <br.encoder.total_budget.Lease.deinit>
 114755a:	e9 b3 fc ff ff       	jmp    1147212 <quality_stage_profile.profilePass+0x1d2>
 114755f:	48 3d f8 f3 11 01    	cmp    $0x111f3f8,%rax
 1147565:	0f 95 c1             	setne  %cl
 1147568:	48 3d 18 f4 11 01    	cmp    $0x111f418,%rax
 114756e:	0f 95 c2             	setne  %dl
 1147571:	20 ca                	and    %cl,%dl
 1147573:	49 3b 7d 00          	cmp    0x0(%r13),%rdi
 1147577:	0f 95 c1             	setne  %cl
 114757a:	20 d1                	and    %dl,%cl
 114757c:	4d 85 ff             	test   %r15,%r15
 114757f:	0f 84 be 00 00 00    	je     1147643 <quality_stage_profile.profilePass+0x603>
 1147585:	84 c9                	test   %cl,%cl
 1147587:	0f 85 b6 00 00 00    	jne    1147643 <quality_stage_profile.profilePass+0x603>
 114758d:	49 8b 47 28          	mov    0x28(%r15),%rax
 1147591:	49 8b 4f 30          	mov    0x30(%r15),%rcx
 1147595:	4c 29 e0             	sub    %r12,%rax
 1147598:	49 89 47 28          	mov    %rax,0x28(%r15)
 114759c:	48 39 c1             	cmp    %rax,%rcx
 114759f:	48 0f 46 c8          	cmovbe %rax,%rcx
 11475a3:	49 89 4f 30          	mov    %rcx,0x30(%r15)
 11475a7:	49 8b 4f 20          	mov    0x20(%r15),%rcx
 11475ab:	48 85 c9             	test   %rcx,%rcx
 11475ae:	0f 84 97 00 00 00    	je     114764b <quality_stage_profile.profilePass+0x60b>
 11475b4:	c4 c1 78 10 47 10    	vmovups 0x10(%r15),%xmm0
 11475ba:	c5 f8 29 45 80       	vmovaps %xmm0,-0x80(%rbp)
 11475bf:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 11475c3:	48 89 41 08          	mov    %rax,0x8(%rcx)
 11475c7:	48 8b 11             	mov    (%rcx),%rdx
 11475ca:	48 39 c2             	cmp    %rax,%rdx
 11475cd:	48 0f 47 c2          	cmova  %rdx,%rax
 11475d1:	48 89 01             	mov    %rax,(%rcx)
 11475d4:	c5 f8 28 45 80       	vmovaps -0x80(%rbp),%xmm0
 11475d9:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 11475de:	eb 6b                	jmp    114764b <quality_stage_profile.profilePass+0x60b>
 11475e0:	49 8b 47 28          	mov    0x28(%r15),%rax
 11475e4:	48 83 f8 50          	cmp    $0x50,%rax
 11475e8:	0f 85 71 01 00 00    	jne    114775f <quality_stage_profile.profilePass+0x71f>
 11475ee:	49 83 7f 38 00       	cmpq   $0x0,0x38(%r15)
 11475f3:	0f 85 b0 fe ff ff    	jne    11474a9 <quality_stage_profile.profilePass+0x469>
 11475f9:	49 8b 3f             	mov    (%r15),%rdi
 11475fc:	49 8b 47 08          	mov    0x8(%r15),%rax
 1147600:	49 8b 4f 20          	mov    0x20(%r15),%rcx
 1147604:	48 85 c9             	test   %rcx,%rcx
 1147607:	74 21                	je     114762a <quality_stage_profile.profilePass+0x5ea>
 1147609:	c4 c1 78 10 47 10    	vmovups 0x10(%r15),%xmm0
 114760f:	c5 f8 29 45 80       	vmovaps %xmm0,-0x80(%rbp)
 1147614:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 1147618:	48 c7 41 08 00 00 00 	movq   $0x0,0x8(%rcx)
 114761f:	00 
 1147620:	c5 f8 28 45 80       	vmovaps -0x80(%rbp),%xmm0
 1147625:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 114762a:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 114762e:	ba 50 00 00 00       	mov    $0x50,%edx
 1147633:	4c 89 fe             	mov    %r15,%rsi
 1147636:	b9 03 00 00 00       	mov    $0x3,%ecx
 114763b:	ff 50 18             	call   *0x18(%rax)
 114763e:	e9 66 fe ff ff       	jmp    11474a9 <quality_stage_profile.profilePass+0x469>
 1147643:	84 c9                	test   %cl,%cl
 1147645:	0f 85 e0 fe ff ff    	jne    114752b <quality_stage_profile.profilePass+0x4eb>
 114764b:	4c 89 a3 a8 30 02 00 	mov    %r12,0x230a8(%rbx)
 1147652:	c6 83 b0 30 02 00 01 	movb   $0x1,0x230b0(%rbx)
 1147659:	80 bb d0 42 02 00 00 	cmpb   $0x0,0x242d0(%rbx)
 1147660:	0f 85 85 00 00 00    	jne    11476eb <quality_stage_profile.profilePass+0x6ab>
 1147666:	80 bb d1 42 02 00 00 	cmpb   $0x0,0x242d1(%rbx)
 114766d:	74 7c                	je     11476eb <quality_stage_profile.profilePass+0x6ab>
 114766f:	48 8d 83 20 30 02 00 	lea    0x23020(%rbx),%rax
 1147676:	48 8b 08             	mov    (%rax),%rcx
 1147679:	48 85 c9             	test   %rcx,%rcx
 114767c:	49 89 f5             	mov    %rsi,%r13
 114767f:	0f 84 34 01 00 00    	je     11477b9 <quality_stage_profile.profilePass+0x779>
 1147685:	48 6b c1 23          	imul   $0x23,%rcx,%rax
 1147689:	eb 0d                	jmp    1147698 <quality_stage_profile.profilePass+0x658>
 114768b:	48 83 c0 dd          	add    $0xffffffffffffffdd,%rax
 114768f:	48 85 c9             	test   %rcx,%rcx
 1147692:	0f 84 21 01 00 00    	je     11477b9 <quality_stage_profile.profilePass+0x779>
 1147698:	80 bc 0b d2 42 02 00 	cmpb   $0x1,0x242d2(%rbx,%rcx,1)
 114769f:	01 
 11476a0:	48 8d 49 ff          	lea    -0x1(%rcx),%rcx
 11476a4:	75 e5                	jne    114768b <quality_stage_profile.profilePass+0x64b>
 11476a6:	0f b6 54 c3 18       	movzbl 0x18(%rbx,%rax,8),%edx
 11476ab:	80 e2 0f             	and    $0xf,%dl
 11476ae:	80 fa 07             	cmp    $0x7,%dl
 11476b1:	75 d8                	jne    114768b <quality_stage_profile.profilePass+0x64b>
 11476b3:	48 83 bc c3 58 ff ff 	cmpq   $0x0,-0xa8(%rbx,%rax,8)
 11476ba:	ff 00 
 11476bc:	75 cd                	jne    114768b <quality_stage_profile.profilePass+0x64b>
 11476be:	80 bc c3 48 ff ff ff 	cmpb   $0x0,-0xb8(%rbx,%rax,8)
 11476c5:	00 
 11476c6:	74 c3                	je     114768b <quality_stage_profile.profilePass+0x64b>
 11476c8:	4c 39 a4 c3 40 ff ff 	cmp    %r12,-0xc0(%rbx,%rax,8)
 11476cf:	ff 
 11476d0:	75 b9                	jne    114768b <quality_stage_profile.profilePass+0x64b>
 11476d2:	4c 39 ac cb d0 32 02 	cmp    %r13,0x232d0(%rbx,%rcx,8)
 11476d9:	00 
 11476da:	75 af                	jne    114768b <quality_stage_profile.profilePass+0x64b>
 11476dc:	48 8b 8c c3 08 ff ff 	mov    -0xf8(%rbx,%rax,8),%rcx
 11476e3:	ff 
 11476e4:	b0 01                	mov    $0x1,%al
 11476e6:	e9 e0 00 00 00       	jmp    11477cb <quality_stage_profile.profilePass+0x78b>
 11476eb:	c7 45 83 00 00 00 00 	movl   $0x0,-0x7d(%rbp)
 11476f2:	c7 45 80 00 00 00 00 	movl   $0x0,-0x80(%rbp)
 11476f9:	31 c0                	xor    %eax,%eax
 11476fb:	31 c9                	xor    %ecx,%ecx
 11476fd:	49 89 f5             	mov    %rsi,%r13
 1147700:	e9 c6 00 00 00       	jmp    11477cb <quality_stage_profile.profilePass+0x78b>
 1147705:	49 8b 4f 20          	mov    0x20(%r15),%rcx
 1147709:	48 85 c9             	test   %rcx,%rcx
 114770c:	0f 84 50 fb ff ff    	je     1147262 <quality_stage_profile.profilePass+0x222>
 1147712:	c4 c1 78 10 47 10    	vmovups 0x10(%r15),%xmm0
 1147718:	c5 f8 29 45 80       	vmovaps %xmm0,-0x80(%rbp)
 114771d:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 1147721:	48 89 41 08          	mov    %rax,0x8(%rcx)
 1147725:	48 8b 11             	mov    (%rcx),%rdx
 1147728:	48 39 c2             	cmp    %rax,%rdx
 114772b:	48 0f 47 c2          	cmova  %rdx,%rax
 114772f:	48 89 01             	mov    %rax,(%rcx)
 1147732:	c5 f8 28 45 80       	vmovaps -0x80(%rbp),%xmm0
 1147737:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 114773c:	49 83 7f 40 00       	cmpq   $0x0,0x40(%r15)
 1147741:	49 c7 47 20 00 00 00 	movq   $0x0,0x20(%r15)
 1147748:	00 
 1147749:	0f 85 13 fb ff ff    	jne    1147262 <quality_stage_profile.profilePass+0x222>
 114774f:	49 83 7f 28 50       	cmpq   $0x50,0x28(%r15)
 1147754:	0f 85 08 fb ff ff    	jne    1147262 <quality_stage_profile.profilePass+0x222>
 114775a:	e9 e6 fc ff ff       	jmp    1147445 <quality_stage_profile.profilePass+0x405>
 114775f:	49 8b 4f 20          	mov    0x20(%r15),%rcx
 1147763:	48 85 c9             	test   %rcx,%rcx
 1147766:	0f 84 3d fd ff ff    	je     11474a9 <quality_stage_profile.profilePass+0x469>
 114776c:	c4 c1 78 10 47 10    	vmovups 0x10(%r15),%xmm0
 1147772:	c5 f8 29 45 80       	vmovaps %xmm0,-0x80(%rbp)
 1147777:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 114777b:	48 89 41 08          	mov    %rax,0x8(%rcx)
 114777f:	48 8b 11             	mov    (%rcx),%rdx
 1147782:	48 39 c2             	cmp    %rax,%rdx
 1147785:	48 0f 47 c2          	cmova  %rdx,%rax
 1147789:	48 89 01             	mov    %rax,(%rcx)
 114778c:	c5 f8 28 45 80       	vmovaps -0x80(%rbp),%xmm0
 1147791:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 1147796:	49 83 7f 40 00       	cmpq   $0x0,0x40(%r15)
 114779b:	49 c7 47 20 00 00 00 	movq   $0x0,0x20(%r15)
 11477a2:	00 
 11477a3:	0f 85 00 fd ff ff    	jne    11474a9 <quality_stage_profile.profilePass+0x469>
 11477a9:	49 83 7f 28 50       	cmpq   $0x50,0x28(%r15)
 11477ae:	0f 85 f5 fc ff ff    	jne    11474a9 <quality_stage_profile.profilePass+0x469>
 11477b4:	e9 35 fe ff ff       	jmp    11475ee <quality_stage_profile.profilePass+0x5ae>
 11477b9:	c7 45 83 00 00 00 00 	movl   $0x0,-0x7d(%rbp)
 11477c0:	c7 45 80 00 00 00 00 	movl   $0x0,-0x80(%rbp)
 11477c7:	31 c0                	xor    %eax,%eax
 11477c9:	31 c9                	xor    %ecx,%ecx
 11477cb:	48 89 8b b8 30 02 00 	mov    %rcx,0x230b8(%rbx)
 11477d2:	88 83 c0 30 02 00    	mov    %al,0x230c0(%rbx)
 11477d8:	8b 45 80             	mov    -0x80(%rbp),%eax
 11477db:	8b 4d 83             	mov    -0x7d(%rbp),%ecx
 11477de:	89 83 c1 30 02 00    	mov    %eax,0x230c1(%rbx)
 11477e4:	89 8b c4 30 02 00    	mov    %ecx,0x230c4(%rbx)
 11477ea:	4d 85 ff             	test   %r15,%r15
 11477ed:	74 0a                	je     11477f9 <quality_stage_profile.profilePass+0x7b9>
 11477ef:	49 ff 4f 40          	decq   0x40(%r15)
 11477f3:	0f 84 d5 00 00 00    	je     11478ce <quality_stage_profile.profilePass+0x88e>
 11477f9:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 1147800:	e8 6b f9 12 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 1147805:	48 8b 85 68 ff ff ff 	mov    -0x98(%rbp),%rax
 114780c:	4c 8b 75 10          	mov    0x10(%rbp),%r14
 1147810:	48 8b 30             	mov    (%rax),%rsi
 1147813:	48 8b 40 08          	mov    0x8(%rax),%rax
 1147817:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 114781e:	ba 01 00 00 00       	mov    $0x1,%edx
 1147823:	ff 90 c0 02 00 00    	call   *0x2c0(%rax)
 1147829:	48 8b 9d f0 fe ff ff 	mov    -0x110(%rbp),%rbx
 1147830:	4d 85 e4             	test   %r12,%r12
 1147833:	b8 01 00 00 00       	mov    $0x1,%eax
 1147838:	4c 89 ef             	mov    %r13,%rdi
 114783b:	48 0f 44 f8          	cmove  %rax,%rdi
 114783f:	4d 85 f6             	test   %r14,%r14
 1147842:	48 8b 95 50 ff ff ff 	mov    -0xb0(%rbp),%rdx
 1147849:	48 0f 44 d0          	cmove  %rax,%rdx
 114784d:	4c 89 e6             	mov    %r12,%rsi
 1147850:	4c 89 f1             	mov    %r14,%rcx
 1147853:	e8 88 ee 0b 00       	call   12066e0 <mem.eqlBytes>
 1147858:	a8 01                	test   $0x1,%al
 114785a:	74 3b                	je     1147897 <quality_stage_profile.profilePass+0x857>
 114785c:	48 2b 9d 58 ff ff ff 	sub    -0xa8(%rbp),%rbx
 1147863:	4d 85 e4             	test   %r12,%r12
 1147866:	74 1d                	je     1147885 <quality_stage_profile.profilePass+0x845>
 1147868:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 114786c:	48 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%rdi
 1147873:	4c 89 ee             	mov    %r13,%rsi
 1147876:	4c 89 e2             	mov    %r12,%rdx
 1147879:	31 c9                	xor    %ecx,%ecx
 114787b:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 1147882:	ff 50 18             	call   *0x18(%rax)
 1147885:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 1147889:	66 c7 40 08 00 00    	movw   $0x0,0x8(%rax)
 114788f:	48 89 18             	mov    %rbx,(%rax)
 1147892:	e9 28 fa ff ff       	jmp    11472bf <quality_stage_profile.profilePass+0x27f>
 1147897:	4d 85 e4             	test   %r12,%r12
 114789a:	74 1d                	je     11478b9 <quality_stage_profile.profilePass+0x879>
 114789c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 11478a0:	48 8b bd 78 ff ff ff 	mov    -0x88(%rbp),%rdi
 11478a7:	4c 89 ee             	mov    %r13,%rsi
 11478aa:	4c 89 e2             	mov    %r12,%rdx
 11478ad:	31 c9                	xor    %ecx,%ecx
 11478af:	48 8b 85 70 ff ff ff 	mov    -0x90(%rbp),%rax
 11478b6:	ff 50 18             	call   *0x18(%rax)
 11478b9:	c5 f8 10 05 cf 8e eb 	vmovups -0x147131(%rip),%xmm0        # 1000790 <__anon_3305>
 11478c0:	ff 
 11478c1:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 11478c5:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 11478c9:	e9 f1 f9 ff ff       	jmp    11472bf <quality_stage_profile.profilePass+0x27f>
 11478ce:	49 8b 47 28          	mov    0x28(%r15),%rax
 11478d2:	48 83 f8 50          	cmp    $0x50,%rax
 11478d6:	75 55                	jne    114792d <quality_stage_profile.profilePass+0x8ed>
 11478d8:	49 83 7f 38 00       	cmpq   $0x0,0x38(%r15)
 11478dd:	0f 85 16 ff ff ff    	jne    11477f9 <quality_stage_profile.profilePass+0x7b9>
 11478e3:	49 8b 3f             	mov    (%r15),%rdi
 11478e6:	49 8b 47 08          	mov    0x8(%r15),%rax
 11478ea:	49 8b 4f 20          	mov    0x20(%r15),%rcx
 11478ee:	48 85 c9             	test   %rcx,%rcx
 11478f1:	74 21                	je     1147914 <quality_stage_profile.profilePass+0x8d4>
 11478f3:	c4 c1 78 10 47 10    	vmovups 0x10(%r15),%xmm0
 11478f9:	c5 f8 29 45 80       	vmovaps %xmm0,-0x80(%rbp)
 11478fe:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 1147902:	48 c7 41 08 00 00 00 	movq   $0x0,0x8(%rcx)
 1147909:	00 
 114790a:	c5 f8 28 45 80       	vmovaps -0x80(%rbp),%xmm0
 114790f:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 1147914:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 1147918:	ba 50 00 00 00       	mov    $0x50,%edx
 114791d:	4c 89 fe             	mov    %r15,%rsi
 1147920:	b9 03 00 00 00       	mov    $0x3,%ecx
 1147925:	ff 50 18             	call   *0x18(%rax)
 1147928:	e9 cc fe ff ff       	jmp    11477f9 <quality_stage_profile.profilePass+0x7b9>
 114792d:	49 8b 4f 20          	mov    0x20(%r15),%rcx
 1147931:	48 85 c9             	test   %rcx,%rcx
 1147934:	0f 84 bf fe ff ff    	je     11477f9 <quality_stage_profile.profilePass+0x7b9>
 114793a:	c4 c1 78 10 47 10    	vmovups 0x10(%r15),%xmm0
 1147940:	c5 f8 29 45 80       	vmovaps %xmm0,-0x80(%rbp)
 1147945:	c6 41 20 01          	movb   $0x1,0x20(%rcx)
 1147949:	48 89 41 08          	mov    %rax,0x8(%rcx)
 114794d:	48 8b 11             	mov    (%rcx),%rdx
 1147950:	48 39 c2             	cmp    %rax,%rdx
 1147953:	48 0f 47 c2          	cmova  %rdx,%rax
 1147957:	48 89 01             	mov    %rax,(%rcx)
 114795a:	c5 f8 28 45 80       	vmovaps -0x80(%rbp),%xmm0
 114795f:	c5 f8 11 41 10       	vmovups %xmm0,0x10(%rcx)
 1147964:	49 83 7f 40 00       	cmpq   $0x0,0x40(%r15)
 1147969:	49 c7 47 20 00 00 00 	movq   $0x0,0x20(%r15)
 1147970:	00 
 1147971:	0f 85 82 fe ff ff    	jne    11477f9 <quality_stage_profile.profilePass+0x7b9>
 1147977:	49 83 7f 28 50       	cmpq   $0x50,0x28(%r15)
 114797c:	0f 85 77 fe ff ff    	jne    11477f9 <quality_stage_profile.profilePass+0x7b9>
 1147982:	e9 51 ff ff ff       	jmp    11478d8 <quality_stage_profile.profilePass+0x898>
 1147987:	89 d1                	mov    %edx,%ecx
 1147989:	c1 e1 04             	shl    $0x4,%ecx
 114798c:	48 8b 81 f0 5d 03 01 	mov    0x1035df0(%rcx),%rax
 1147993:	48 8b 89 f8 5d 03 01 	mov    0x1035df8(%rcx),%rcx
 114799a:	48 89 83 98 30 02 00 	mov    %rax,0x23098(%rbx)
 11479a1:	48 89 8b a0 30 02 00 	mov    %rcx,0x230a0(%rbx)
 11479a8:	80 bd 28 ff ff ff 00 	cmpb   $0x0,-0xd8(%rbp)
 11479af:	49 89 d6             	mov    %rdx,%r14
 11479b2:	0f 85 d6 f8 ff ff    	jne    114728e <quality_stage_profile.profilePass+0x24e>
 11479b8:	e9 ed f8 ff ff       	jmp    11472aa <quality_stage_profile.profilePass+0x26a>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
