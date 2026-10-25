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
