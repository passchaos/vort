 10bf766:	4c 8d 95 d8 4e fd ff 	lea    -0x2b128(%rbp),%r10
 10bf76d:	48 8d bd 08 ff ff ff 	lea    -0xf8(%rbp),%rdi
 10bf774:	4c 8d 8d 70 e6 ff ff 	lea    -0x1990(%rbp),%r9
 10bf77b:	4c 89 fe             	mov    %r15,%rsi
 10bf77e:	4c 89 f2             	mov    %r14,%rdx
 10bf781:	4c 89 e9             	mov    %r13,%rcx
 10bf784:	4d 89 e0             	mov    %r12,%r8
 10bf787:	41 53                	push   %r11
 10bf789:	50                   	push   %rax
 10bf78a:	41 52                	push   %r10
 10bf78c:	50                   	push   %rax
 10bf78d:	4c 8d 95 d8 4e ff ff 	lea    -0xb128(%rbp),%r10
 10bf794:	41 52                	push   %r10
 10bf796:	50                   	push   %rax
 10bf797:	4c 8d 95 70 fa ff ff 	lea    -0x590(%rbp),%r10
 10bf79e:	41 52                	push   %r10
 10bf7a0:	50                   	push   %rax
 10bf7a1:	c5 f8 77             	vzeroupper 
 10bf7a4:	e8 97 00 00 00       	call   10bf840 <zstd.emitBestSequenceCompressedBlock>
 10bf7a9:	48 83 c4 40          	add    $0x40,%rsp
 10bf7ad:	0f b7 8d 08 ff ff ff 	movzwl -0xf8(%rbp),%ecx
 10bf7b4:	66 85 c9             	test   %cx,%cx
 10bf7b7:	48 8b 45 98          	mov    -0x68(%rbp),%rax
 10bf7bb:	75 0c                	jne    10bf7c9 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x8f9>
 10bf7bd:	0f b6 8d 0a ff ff ff 	movzbl -0xf6(%rbp),%ecx
 10bf7c4:	88 4d d6             	mov    %cl,-0x2a(%rbp)
 10bf7c7:	31 c9                	xor    %ecx,%ecx
 10bf7c9:	41 89 cd             	mov    %ecx,%r13d
 10bf7cc:	48 83 bd 78 ff ff ff 	cmpq   $0x0,-0x88(%rbp)
 10bf7d3:	00 
 10bf7d4:	74 4e                	je     10bf824 <zstd.benchmarkUnprofiledAnchorCandidate__anon_3091+0x954>
 10bf7d6:	4c 8b a5 68 ff ff ff 	mov    -0x98(%rbp),%r12
 10bf7dd:	4c 89 e7             	mov    %r12,%rdi
 10bf7e0:	48 89 c6             	mov    %rax,%rsi
 10bf7e3:	48 8b 95 20 ff ff ff 	mov    -0xe0(%rbp),%rdx
 10bf7ea:	b9 02 00 00 00       	mov    $0x2,%ecx
 10bf7ef:	4c 8b bd 60 ff ff ff 	mov    -0xa0(%rbp),%r15
 10bf7f6:	4d 89 f8             	mov    %r15,%r8
 10bf7f9:	4c 8b b5 58 ff ff ff 	mov    -0xa8(%rbp),%r14
 10bf800:	c5 f8 77             	vzeroupper 
 10bf803:	41 ff 56 18          	call   *0x18(%r14)
 10bf807:	4c 89 e7             	mov    %r12,%rdi
 10bf80a:	48 8b b5 38 ff ff ff 	mov    -0xc8(%rbp),%rsi
 10bf811:	48 8b 95 70 ff ff ff 	mov    -0x90(%rbp),%rdx
 10bf818:	b9 01 00 00 00       	mov    $0x1,%ecx
 10bf81d:	4d 89 f8             	mov    %r15,%r8
 10bf820:	41 ff 56 18          	call   *0x18(%r14)
 10bf824:	0f b6 45 d6          	movzbl -0x2a(%rbp),%eax
 10bf828:	66 44 89 2b          	mov    %r13w,(%rbx)
 10bf82c:	88 43 02             	mov    %al,0x2(%rbx)
