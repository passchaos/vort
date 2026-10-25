 12775ae:	4c 8b 97 28 30 02 00 	mov    0x23028(%rdi),%r10
 12775b5:	48 8b 87 c8 32 02 00 	mov    0x232c8(%rdi),%rax
 12775bc:	48 85 c0             	test   %rax,%rax
 12775bf:	74 1a                	je     12775db <br.encoder.quality_profile.Active.begin+0x4b>
 12775c1:	48 c1 e0 04          	shl    $0x4,%rax
 12775c5:	48 8b 84 07 b8 30 02 	mov    0x230b8(%rdi,%rax,1),%rax
 12775cc:	00 
 12775cd:	48 89 45 c0          	mov    %rax,-0x40(%rbp)
 12775d1:	c6 45 c8 01          	movb   $0x1,-0x38(%rbp)
 12775d5:	4c 8d 7d c0          	lea    -0x40(%rbp),%r15
 12775d9:	eb 06                	jmp    12775e1 <br.encoder.quality_profile.Active.begin+0x51>
 12775db:	41 bf 70 0a 00 01    	mov    $0x1000a70,%r15d
 12775e1:	48 8b 06             	mov    (%rsi),%rax
 12775e4:	4c 8b 4e 08          	mov    0x8(%rsi),%r9
 12775e8:	c4 c1 78 10 07       	vmovups (%r15),%xmm0
 12775ed:	c5 f8 29 45 a0       	vmovaps %xmm0,-0x60(%rbp)
 12775f2:	80 e2 0f             	and    $0xf,%dl
 12775f5:	88 55 e0             	mov    %dl,-0x20(%rbp)
 12775f8:	41 80 e6 03          	and    $0x3,%r14b
 12775fc:	44 88 75 dd          	mov    %r14b,-0x23(%rbp)
 1277600:	41 80 e3 01          	and    $0x1,%r11b
 1277604:	44 88 5d de          	mov    %r11b,-0x22(%rbp)
 1277608:	4d 89 d3             	mov    %r10,%r11
 127760b:	49 ff c3             	inc    %r11
 127760e:	49 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%r14
 1277615:	4d 0f 45 f3          	cmovne %r11,%r14
 1277619:	4c 89 b7 28 30 02 00 	mov    %r14,0x23028(%rdi)
 1277620:	4c 8b 9f 20 30 02 00 	mov    0x23020(%rdi),%r11
 1277627:	4c 8b 77 18          	mov    0x18(%rdi),%r14
 127762b:	49 81 fe 00 02 00 00 	cmp    $0x200,%r14
 1277632:	41 bf 00 02 00 00    	mov    $0x200,%r15d
 1277638:	4d 0f 42 fe          	cmovb  %r14,%r15
 127763c:	4d 39 fb             	cmp    %r15,%r11
 127763f:	0f 83 d9 00 00 00    	jae    127771e <br.encoder.quality_profile.Active.begin+0x18e>
 1277645:	4d 69 f3 18 01 00 00 	imul   $0x118,%r11,%r14
 127764c:	4e 89 54 37 20       	mov    %r10,0x20(%rdi,%r14,1)
 1277651:	c5 f8 28 45 a0       	vmovaps -0x60(%rbp),%xmm0
 1277656:	c4 a1 78 11 44 37 28 	vmovups %xmm0,0x28(%rdi,%r14,1)

 127770e:	48 ff 87 20 30 02 00 	incq   0x23020(%rdi)
 1277715:	b1 01                	mov    $0x1,%cl
 1277717:	80 fa 07             	cmp    $0x7,%dl
 127771a:	74 21                	je     127773d <br.encoder.quality_profile.Active.begin+0x1ad>
 127771c:	eb 3b                	jmp    1277759 <br.encoder.quality_profile.Active.begin+0x1c9>
 127771e:	c6 87 d0 42 02 00 01 	movb   $0x1,0x242d0(%rdi)
 1277725:	c7 45 d7 00 00 00 00 	movl   $0x0,-0x29(%rbp)
 127772c:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%rbp)
 1277733:	31 c9                	xor    %ecx,%ecx
 1277735:	45 31 db             	xor    %r11d,%r11d
 1277738:	80 fa 07             	cmp    $0x7,%dl
 127773b:	75 1c                	jne    1277759 <br.encoder.quality_profile.Active.begin+0x1c9>
 127773d:	4c 8b 87 30 30 02 00 	mov    0x23030(%rdi),%r8
 1277744:	49 ff c0             	inc    %r8
 1277747:	49 c7 c6 ff ff ff ff 	mov    $0xffffffffffffffff,%r14
 127774e:	4d 0f 45 f0          	cmovne %r8,%r14
 1277752:	4c 89 b7 30 30 02 00 	mov    %r14,0x23030(%rdi)
 1277759:	4c 8b 87 c8 32 02 00 	mov    0x232c8(%rdi),%r8
 1277760:	49 83 f8 20          	cmp    $0x20,%r8
 1277764:	73 2d                	jae    1277793 <br.encoder.quality_profile.Active.begin+0x203>
 1277766:	4c 89 45 b0          	mov    %r8,-0x50(%rbp)
 127776a:	c6 45 b8 01          	movb   $0x1,-0x48(%rbp)
 127776e:	49 c1 e0 04          	shl    $0x4,%r8
 1277772:	4e 89 94 07 c8 30 02 	mov    %r10,0x230c8(%rdi,%r8,1)
 1277779:	00 
 127777a:	4a c7 84 07 d0 30 02 	movq   $0x0,0x230d0(%rdi,%r8,1)
 1277781:	00 00 00 00 00 
 1277786:	48 ff 87 c8 32 02 00 	incq   0x232c8(%rdi)
 127778d:	48 8d 7d b0          	lea    -0x50(%rbp),%rdi
 1277791:	eb 0c                	jmp    127779f <br.encoder.quality_profile.Active.begin+0x20f>
 1277793:	c6 87 d2 42 02 00 00 	movb   $0x0,0x242d2(%rdi)
 127779a:	bf 70 0a 00 01       	mov    $0x1000a70,%edi

 12777c7:	48 8d 7d 90          	lea    -0x70(%rbp),%rdi
 12777cb:	48 89 c6             	mov    %rax,%rsi
 12777ce:	ba 01 00 00 00       	mov    $0x1,%edx
 12777d3:	c5 f8 77             	vzeroupper 
 12777d6:	41 ff 91 c0 02 00 00 	call   *0x2c0(%r9)
 12777dd:	c5 f8 28 45 90       	vmovaps -0x70(%rbp),%xmm0
 12777e2:	c5 f8 29 03          	vmovaps %xmm0,(%rbx)
