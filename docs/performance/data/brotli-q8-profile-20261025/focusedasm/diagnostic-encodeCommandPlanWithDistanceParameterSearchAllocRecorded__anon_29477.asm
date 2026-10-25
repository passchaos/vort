
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000123b600 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477>:
 123b600:	55                   	push   %rbp
 123b601:	48 89 e5             	mov    %rsp,%rbp
 123b604:	41 57                	push   %r15
 123b606:	41 56                	push   %r14
 123b608:	41 55                	push   %r13
 123b60a:	41 54                	push   %r12
 123b60c:	53                   	push   %rbx
 123b60d:	48 81 ec 08 05 00 00 	sub    $0x508,%rsp
 123b614:	4c 89 4d 88          	mov    %r9,-0x78(%rbp)
 123b618:	4c 89 c0             	mov    %r8,%rax
 123b61b:	48 89 4d 98          	mov    %rcx,-0x68(%rbp)
 123b61f:	48 89 55 a8          	mov    %rdx,-0x58(%rbp)
 123b623:	48 89 7d c8          	mov    %rdi,-0x38(%rbp)
 123b627:	4c 8b 45 10          	mov    0x10(%rbp),%r8
 123b62b:	48 8b 5d 20          	mov    0x20(%rbp),%rbx
 123b62f:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 123b633:	c5 fc 11 85 20 fd ff 	vmovups %ymm0,-0x2e0(%rbp)
 123b63a:	ff 
 123b63b:	44 0f b6 bb f8 01 00 	movzbl 0x1f8(%rbx),%r15d
 123b642:	00 
 123b643:	48 8b 8b 00 02 00 00 	mov    0x200(%rbx),%rcx
 123b64a:	48 89 4d c0          	mov    %rcx,-0x40(%rbp)
 123b64e:	44 0f b6 ab 1b 02 00 	movzbl 0x21b(%rbx),%r13d
 123b655:	00 
 123b656:	44 0f b6 b3 25 02 00 	movzbl 0x225(%rbx),%r14d
 123b65d:	00 
 123b65e:	48 89 75 b0          	mov    %rsi,-0x50(%rbp)
 123b662:	c5 fc 10 06          	vmovups (%rsi),%ymm0
 123b666:	44 0f b6 a3 1a 02 00 	movzbl 0x21a(%rbx),%r12d
 123b66d:	00 
 123b66e:	c5 fc 11 85 00 fd ff 	vmovups %ymm0,-0x300(%rbp)
 123b675:	ff 
 123b676:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 123b67d:	48 8d b5 00 fd ff ff 	lea    -0x300(%rbp),%rsi
 123b684:	ba 08 00 00 00       	mov    $0x8,%edx
 123b689:	48 89 45 90          	mov    %rax,-0x70(%rbp)
 123b68d:	48 89 c1             	mov    %rax,%rcx
 123b690:	c5 f8 77             	vzeroupper 
 123b693:	e8 f8 be 03 00       	call   1277590 <br.encoder.quality_profile.Active.begin>
 123b698:	41 f6 c4 03          	test   $0x3,%r12b
 123b69c:	0f 85 70 03 00 00    	jne    123ba12 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x412>
 123b6a2:	41 80 e5 0f          	and    $0xf,%r13b
 123b6a6:	0f 85 66 03 00 00    	jne    123ba12 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x412>
 123b6ac:	41 f6 c6 01          	test   $0x1,%r14b
 123b6b0:	0f 84 5c 03 00 00    	je     123ba12 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x412>
 123b6b6:	45 84 ff             	test   %r15b,%r15b
 123b6b9:	0f 85 53 03 00 00    	jne    123ba12 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x412>
 123b6bf:	48 83 7d c0 00       	cmpq   $0x0,-0x40(%rbp)
 123b6c4:	0f 85 48 03 00 00    	jne    123ba12 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x412>
 123b6ca:	4c 8b 6d 18          	mov    0x18(%rbp),%r13
 123b6ce:	c4 c1 7c 10 45 70    	vmovups 0x70(%r13),%ymm0
 123b6d4:	c5 fc 11 85 b0 fd ff 	vmovups %ymm0,-0x250(%rbp)
 123b6db:	ff 
 123b6dc:	c4 c1 7c 10 45 00    	vmovups 0x0(%r13),%ymm0
 123b6e2:	c4 c1 7c 10 4d 20    	vmovups 0x20(%r13),%ymm1
 123b6e8:	c4 c1 7c 10 55 40    	vmovups 0x40(%r13),%ymm2
 123b6ee:	c4 c1 7c 10 5d 60    	vmovups 0x60(%r13),%ymm3
 123b6f4:	c5 fc 11 9d a0 fd ff 	vmovups %ymm3,-0x260(%rbp)
 123b6fb:	ff 
 123b6fc:	c5 fc 11 95 80 fd ff 	vmovups %ymm2,-0x280(%rbp)
 123b703:	ff 
 123b704:	c5 fc 11 8d 60 fd ff 	vmovups %ymm1,-0x2a0(%rbp)
 123b70b:	ff 
 123b70c:	c5 fc 11 85 40 fd ff 	vmovups %ymm0,-0x2c0(%rbp)
 123b713:	ff 
 123b714:	c4 c1 7c 10 45 00    	vmovups 0x0(%r13),%ymm0
 123b71a:	c4 c1 7c 10 4d 20    	vmovups 0x20(%r13),%ymm1
 123b720:	c4 c1 7c 10 55 40    	vmovups 0x40(%r13),%ymm2
 123b726:	c4 c1 7c 10 5d 60    	vmovups 0x60(%r13),%ymm3
 123b72c:	c5 fc 11 85 60 fe ff 	vmovups %ymm0,-0x1a0(%rbp)
 123b733:	ff 
 123b734:	c5 fc 11 8d 80 fe ff 	vmovups %ymm1,-0x180(%rbp)
 123b73b:	ff 
 123b73c:	c5 fc 11 95 a0 fe ff 	vmovups %ymm2,-0x160(%rbp)
 123b743:	ff 
 123b744:	c5 fc 11 9d c0 fe ff 	vmovups %ymm3,-0x140(%rbp)
 123b74b:	ff 
 123b74c:	c4 c1 7c 10 45 70    	vmovups 0x70(%r13),%ymm0
 123b752:	c5 fc 11 85 d0 fe ff 	vmovups %ymm0,-0x130(%rbp)
 123b759:	ff 
 123b75a:	48 83 ec 08          	sub    $0x8,%rsp
 123b75e:	48 8d 85 60 fe ff ff 	lea    -0x1a0(%rbp),%rax
 123b765:	48 8d bd 08 ff ff ff 	lea    -0xf8(%rbp),%rdi
 123b76c:	48 8b 75 b0          	mov    -0x50(%rbp),%rsi
 123b770:	4c 8b 65 a8          	mov    -0x58(%rbp),%r12
 123b774:	4c 89 e2             	mov    %r12,%rdx
 123b777:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 123b77b:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 123b77f:	4c 8b 75 88          	mov    -0x78(%rbp),%r14
 123b783:	4d 89 f1             	mov    %r14,%r9
 123b786:	53                   	push   %rbx
 123b787:	50                   	push   %rax
 123b788:	48 8b 45 10          	mov    0x10(%rbp),%rax
 123b78c:	50                   	push   %rax
 123b78d:	c5 f8 77             	vzeroupper 
 123b790:	e8 9b 33 ff ff       	call   122eb30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509>
 123b795:	48 83 c4 20          	add    $0x20,%rsp
 123b799:	44 0f b7 bd 18 ff ff 	movzwl -0xe8(%rbp),%r15d
 123b7a0:	ff 
 123b7a1:	4d 85 ff             	test   %r15,%r15
 123b7a4:	0f 85 62 05 00 00    	jne    123bd0c <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x70c>
 123b7aa:	4c 8b bd 08 ff ff ff 	mov    -0xf8(%rbp),%r15
 123b7b1:	4c 89 f2             	mov    %r14,%rdx
 123b7b4:	4c 8b b5 10 ff ff ff 	mov    -0xf0(%rbp),%r14
 123b7bb:	48 8d 7d ba          	lea    -0x46(%rbp),%rdi
 123b7bf:	4c 89 e6             	mov    %r12,%rsi
 123b7c2:	48 8b 4d 10          	mov    0x10(%rbp),%rcx
 123b7c6:	49 89 d8             	mov    %rbx,%r8
 123b7c9:	e8 02 5e ff ff       	call   12315d0 <br.chooseDistanceParameterAlternativeAlloc>
 123b7ce:	44 0f b7 65 ba       	movzwl -0x46(%rbp),%r12d
 123b7d3:	4d 85 e4             	test   %r12,%r12
 123b7d6:	0f 85 79 05 00 00    	jne    123bd55 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x755>
 123b7dc:	80 7d be 00          	cmpb   $0x0,-0x42(%rbp)
 123b7e0:	0f 84 8f 02 00 00    	je     123ba75 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x475>
 123b7e6:	4c 89 75 c0          	mov    %r14,-0x40(%rbp)
 123b7ea:	4c 89 7d a0          	mov    %r15,-0x60(%rbp)
 123b7ee:	44 0f b7 75 bc       	movzwl -0x44(%rbp),%r14d
 123b7f3:	4c 8d a5 d8 fa ff ff 	lea    -0x528(%rbp),%r12
 123b7fa:	ba 1a 02 00 00       	mov    $0x21a,%edx
 123b7ff:	4c 89 e7             	mov    %r12,%rdi
 123b802:	48 89 de             	mov    %rbx,%rsi
 123b805:	e8 56 3f 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123b80a:	0f b7 83 1c 02 00 00 	movzwl 0x21c(%rbx),%eax
 123b811:	66 89 85 f4 fc ff ff 	mov    %ax,-0x30c(%rbp)
 123b818:	0f b6 83 1e 02 00 00 	movzbl 0x21e(%rbx),%eax
 123b81f:	88 85 f6 fc ff ff    	mov    %al,-0x30a(%rbp)
 123b825:	48 8b 83 20 02 00 00 	mov    0x220(%rbx),%rax
 123b82c:	c6 45 d7 00          	movb   $0x0,-0x29(%rbp)
 123b830:	c5 fc 10 85 40 fd ff 	vmovups -0x2c0(%rbp),%ymm0
 123b837:	ff 
 123b838:	c5 fc 10 8d 60 fd ff 	vmovups -0x2a0(%rbp),%ymm1
 123b83f:	ff 
 123b840:	c5 fc 10 95 80 fd ff 	vmovups -0x280(%rbp),%ymm2
 123b847:	ff 
 123b848:	c5 fc 11 85 d0 fd ff 	vmovups %ymm0,-0x230(%rbp)
 123b84f:	ff 
 123b850:	c5 fc 11 8d f0 fd ff 	vmovups %ymm1,-0x210(%rbp)
 123b857:	ff 
 123b858:	c5 fc 10 85 a0 fd ff 	vmovups -0x260(%rbp),%ymm0
 123b85f:	ff 
 123b860:	c5 fc 11 95 10 fe ff 	vmovups %ymm2,-0x1f0(%rbp)
 123b867:	ff 
 123b868:	c5 fc 11 85 30 fe ff 	vmovups %ymm0,-0x1d0(%rbp)
 123b86f:	ff 
 123b870:	c5 fc 10 85 b0 fd ff 	vmovups -0x250(%rbp),%ymm0
 123b877:	ff 
 123b878:	c5 fc 11 85 40 fe ff 	vmovups %ymm0,-0x1c0(%rbp)
 123b87f:	ff 
 123b880:	66 44 89 b5 f2 fc ff 	mov    %r14w,-0x30e(%rbp)
 123b887:	ff 
 123b888:	0f b6 4d d7          	movzbl -0x29(%rbp),%ecx
 123b88c:	88 8d f7 fc ff ff    	mov    %cl,-0x309(%rbp)
 123b892:	48 89 85 f8 fc ff ff 	mov    %rax,-0x308(%rbp)
 123b899:	48 83 ec 08          	sub    $0x8,%rsp
 123b89d:	48 8d 85 d0 fd ff ff 	lea    -0x230(%rbp),%rax
 123b8a4:	48 8d bd f0 fe ff ff 	lea    -0x110(%rbp),%rdi
 123b8ab:	4c 8b 7d b0          	mov    -0x50(%rbp),%r15
 123b8af:	4c 89 fe             	mov    %r15,%rsi
 123b8b2:	4c 8b 75 a8          	mov    -0x58(%rbp),%r14
 123b8b6:	4c 89 f2             	mov    %r14,%rdx
 123b8b9:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 123b8bd:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 123b8c1:	4c 8b 4d 88          	mov    -0x78(%rbp),%r9
 123b8c5:	41 54                	push   %r12
 123b8c7:	50                   	push   %rax
 123b8c8:	ff 75 10             	push   0x10(%rbp)
 123b8cb:	c5 f8 77             	vzeroupper 
 123b8ce:	e8 5d 32 ff ff       	call   122eb30 <br.encodeCommandPlanWithOptionsAllocRecorded__anon_29509>
 123b8d3:	48 83 c4 20          	add    $0x20,%rsp
 123b8d7:	0f b7 9d 00 ff ff ff 	movzwl -0x100(%rbp),%ebx
 123b8de:	48 85 db             	test   %rbx,%rbx
 123b8e1:	0f 85 ca 04 00 00    	jne    123bdb1 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x7b1>
 123b8e7:	48 8b b5 f0 fe ff ff 	mov    -0x110(%rbp),%rsi
 123b8ee:	48 8b 95 f8 fe ff ff 	mov    -0x108(%rbp),%rdx
 123b8f5:	48 8d bd 20 fd ff ff 	lea    -0x2e0(%rbp),%rdi
 123b8fc:	49 89 f5             	mov    %rsi,%r13
 123b8ff:	49 89 d4             	mov    %rdx,%r12
 123b902:	48 8b 4d a0          	mov    -0x60(%rbp),%rcx
 123b906:	48 89 cb             	mov    %rcx,%rbx
 123b909:	4c 8b 45 c0          	mov    -0x40(%rbp),%r8
 123b90d:	e8 ce 26 00 00       	call   123dfe0 <br.encoder.quality_profile.Active.prefer>
 123b912:	49 8b 4f 10          	mov    0x10(%r15),%rcx
 123b916:	49 8b 3e             	mov    (%r14),%rdi
 123b919:	4d 8b 5e 08          	mov    0x8(%r14),%r11
 123b91d:	4c 8d 71 20          	lea    0x20(%rcx),%r14
 123b921:	4c 8b 89 20 30 02 00 	mov    0x23020(%rcx),%r9
 123b928:	a8 01                	test   $0x1,%al
 123b92a:	0f 84 ad 01 00 00    	je     123badd <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x4dd>
 123b930:	4d 85 c9             	test   %r9,%r9
 123b933:	48 89 de             	mov    %rbx,%rsi
 123b936:	4d 89 e7             	mov    %r12,%r15
 123b939:	48 8b 55 c0          	mov    -0x40(%rbp),%rdx
 123b93d:	4c 8b 65 18          	mov    0x18(%rbp),%r12
 123b941:	74 54                	je     123b997 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x397>
 123b943:	4c 89 db             	mov    %r11,%rbx
 123b946:	49 83 f9 01          	cmp    $0x1,%r9
 123b94a:	0f 85 72 02 00 00    	jne    123bbc2 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x5c2>
 123b950:	31 c0                	xor    %eax,%eax
 123b952:	41 f6 c1 01          	test   $0x1,%r9b
 123b956:	49 89 db             	mov    %rbx,%r11
 123b959:	74 3c                	je     123b997 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x397>
 123b95b:	4c 69 c8 18 01 00 00 	imul   $0x118,%rax,%r9
 123b962:	47 0f b6 84 0e 10 01 	movzbl 0x110(%r14,%r9,1),%r8d
 123b969:	00 00 
 123b96b:	41 80 e0 0f          	and    $0xf,%r8b
 123b96f:	41 80 f8 07          	cmp    $0x7,%r8b
 123b973:	75 22                	jne    123b997 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x397>
 123b975:	4d 01 ce             	add    %r9,%r14
 123b978:	41 80 7e 40 00       	cmpb   $0x0,0x40(%r14)
 123b97d:	74 18                	je     123b997 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x397>
 123b97f:	49 39 56 38          	cmp    %rdx,0x38(%r14)
 123b983:	75 12                	jne    123b997 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x397>
 123b985:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 123b98c:	00 
 123b98d:	75 08                	jne    123b997 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x397>
 123b98f:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 123b996:	00 
 123b997:	48 85 d2             	test   %rdx,%rdx
 123b99a:	74 0a                	je     123b9a6 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x3a6>
 123b99c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123b9a0:	31 c9                	xor    %ecx,%ecx
 123b9a2:	41 ff 53 18          	call   *0x18(%r11)
 123b9a6:	c5 fc 10 85 40 fe ff 	vmovups -0x1c0(%rbp),%ymm0
 123b9ad:	ff 
 123b9ae:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 123b9b5:	c5 fc 10 85 d0 fd ff 	vmovups -0x230(%rbp),%ymm0
 123b9bc:	ff 
 123b9bd:	c5 fc 10 8d f0 fd ff 	vmovups -0x210(%rbp),%ymm1
 123b9c4:	ff 
 123b9c5:	c5 fc 10 95 10 fe ff 	vmovups -0x1f0(%rbp),%ymm2
 123b9cc:	ff 
 123b9cd:	c5 fc 10 9d 30 fe ff 	vmovups -0x1d0(%rbp),%ymm3
 123b9d4:	ff 
 123b9d5:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 123b9dc:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 123b9e3:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 123b9ea:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 123b9f0:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 123b9f7:	c5 f8 77             	vzeroupper 
 123b9fa:	e8 71 b7 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123b9ff:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123ba03:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 123ba09:	4c 89 28             	mov    %r13,(%rax)
 123ba0c:	4c 89 78 08          	mov    %r15,0x8(%rax)
 123ba10:	eb 51                	jmp    123ba63 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x463>
 123ba12:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 123ba19:	74 24                	je     123ba3f <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x43f>
 123ba1b:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 123ba22:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 123ba29:	18 01 00 00 
 123ba2d:	48 c7 44 08 68 24 bb 	movq   $0x112bb24,0x68(%rax,%rcx,1)
 123ba34:	12 01 
 123ba36:	48 c7 44 08 70 10 00 	movq   $0x10,0x70(%rax,%rcx,1)
 123ba3d:	00 00 
 123ba3f:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 123ba46:	e8 25 b7 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123ba4b:	c5 f8 10 05 65 39 e5 	vmovups -0x1ac69b(%rip),%xmm0        # 108f3b8 <__anon_205615>
 123ba52:	ff 
 123ba53:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123ba57:	c5 f8 11 00          	vmovups %xmm0,(%rax)
 123ba5b:	48 c7 40 10 52 00 00 	movq   $0x52,0x10(%rax)
 123ba62:	00 
 123ba63:	48 81 c4 08 05 00 00 	add    $0x508,%rsp
 123ba6a:	5b                   	pop    %rbx
 123ba6b:	41 5c                	pop    %r12
 123ba6d:	41 5d                	pop    %r13
 123ba6f:	41 5e                	pop    %r14
 123ba71:	41 5f                	pop    %r15
 123ba73:	5d                   	pop    %rbp
 123ba74:	c3                   	ret    
 123ba75:	c5 fc 10 85 d0 fe ff 	vmovups -0x130(%rbp),%ymm0
 123ba7c:	ff 
 123ba7d:	c4 c1 7c 11 45 70    	vmovups %ymm0,0x70(%r13)
 123ba83:	c5 fc 10 85 60 fe ff 	vmovups -0x1a0(%rbp),%ymm0
 123ba8a:	ff 
 123ba8b:	c5 fc 10 8d 80 fe ff 	vmovups -0x180(%rbp),%ymm1
 123ba92:	ff 
 123ba93:	c5 fc 10 95 a0 fe ff 	vmovups -0x160(%rbp),%ymm2
 123ba9a:	ff 
 123ba9b:	c5 fc 10 9d c0 fe ff 	vmovups -0x140(%rbp),%ymm3
 123baa2:	ff 
 123baa3:	c4 c1 7c 11 5d 60    	vmovups %ymm3,0x60(%r13)
 123baa9:	c4 c1 7c 11 55 40    	vmovups %ymm2,0x40(%r13)
 123baaf:	c4 c1 7c 11 4d 20    	vmovups %ymm1,0x20(%r13)
 123bab5:	c4 c1 7c 11 45 00    	vmovups %ymm0,0x0(%r13)
 123babb:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 123bac2:	c5 f8 77             	vzeroupper 
 123bac5:	e8 a6 b6 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123baca:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123bace:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 123bad4:	4c 89 38             	mov    %r15,(%rax)
 123bad7:	4c 89 70 08          	mov    %r14,0x8(%rax)
 123badb:	eb 86                	jmp    123ba63 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x463>
 123badd:	4d 85 c9             	test   %r9,%r9
 123bae0:	4c 89 e2             	mov    %r12,%rdx
 123bae3:	4c 8b 65 18          	mov    0x18(%rbp),%r12
 123bae7:	74 54                	je     123bb3d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x53d>
 123bae9:	4d 89 df             	mov    %r11,%r15
 123baec:	49 83 f9 01          	cmp    $0x1,%r9
 123baf0:	0f 85 76 01 00 00    	jne    123bc6c <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x66c>
 123baf6:	31 c0                	xor    %eax,%eax
 123baf8:	41 f6 c1 01          	test   $0x1,%r9b
 123bafc:	4d 89 fb             	mov    %r15,%r11
 123baff:	74 3c                	je     123bb3d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x53d>
 123bb01:	4c 69 d0 18 01 00 00 	imul   $0x118,%rax,%r10
 123bb08:	47 0f b6 84 16 10 01 	movzbl 0x110(%r14,%r10,1),%r8d
 123bb0f:	00 00 
 123bb11:	41 80 e0 0f          	and    $0xf,%r8b
 123bb15:	41 80 f8 07          	cmp    $0x7,%r8b
 123bb19:	75 22                	jne    123bb3d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x53d>
 123bb1b:	4d 01 d6             	add    %r10,%r14
 123bb1e:	41 80 7e 40 00       	cmpb   $0x0,0x40(%r14)
 123bb23:	74 18                	je     123bb3d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x53d>
 123bb25:	49 39 56 38          	cmp    %rdx,0x38(%r14)
 123bb29:	75 12                	jne    123bb3d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x53d>
 123bb2b:	4c 39 ac c1 d0 32 02 	cmp    %r13,0x232d0(%rcx,%rax,8)
 123bb32:	00 
 123bb33:	75 08                	jne    123bb3d <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x53d>
 123bb35:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 123bb3c:	00 
 123bb3d:	48 85 d2             	test   %rdx,%rdx
 123bb40:	74 0d                	je     123bb4f <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x54f>
 123bb42:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123bb46:	4c 89 ee             	mov    %r13,%rsi
 123bb49:	31 c9                	xor    %ecx,%ecx
 123bb4b:	41 ff 53 18          	call   *0x18(%r11)
 123bb4f:	c5 fc 10 85 d0 fe ff 	vmovups -0x130(%rbp),%ymm0
 123bb56:	ff 
 123bb57:	c4 c1 7c 11 44 24 70 	vmovups %ymm0,0x70(%r12)
 123bb5e:	c5 fc 10 85 60 fe ff 	vmovups -0x1a0(%rbp),%ymm0
 123bb65:	ff 
 123bb66:	c5 fc 10 8d 80 fe ff 	vmovups -0x180(%rbp),%ymm1
 123bb6d:	ff 
 123bb6e:	c5 fc 10 95 a0 fe ff 	vmovups -0x160(%rbp),%ymm2
 123bb75:	ff 
 123bb76:	c5 fc 10 9d c0 fe ff 	vmovups -0x140(%rbp),%ymm3
 123bb7d:	ff 
 123bb7e:	c4 c1 7c 11 5c 24 60 	vmovups %ymm3,0x60(%r12)
 123bb85:	c4 c1 7c 11 54 24 40 	vmovups %ymm2,0x40(%r12)
 123bb8c:	c4 c1 7c 11 4c 24 20 	vmovups %ymm1,0x20(%r12)
 123bb93:	c4 c1 7c 11 04 24    	vmovups %ymm0,(%r12)
 123bb99:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 123bba0:	c5 f8 77             	vzeroupper 
 123bba3:	e8 c8 b5 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123bba8:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123bbac:	66 c7 40 10 00 00    	movw   $0x0,0x10(%rax)
 123bbb2:	48 89 18             	mov    %rbx,(%rax)
 123bbb5:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123bbb9:	48 89 48 08          	mov    %rcx,0x8(%rax)
 123bbbd:	e9 a1 fe ff ff       	jmp    123ba63 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x463>
 123bbc2:	4d 89 c8             	mov    %r9,%r8
 123bbc5:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 123bbc9:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 123bbcd:	31 c0                	xor    %eax,%eax
 123bbcf:	eb 23                	jmp    123bbf4 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x5f4>
 123bbd1:	66 66 66 66 66 66 2e 	data16 data16 data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 123bbd8:	0f 1f 84 00 00 00 00 
 123bbdf:	00 
 123bbe0:	48 83 c0 02          	add    $0x2,%rax
 123bbe4:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 123bbeb:	49 39 c0             	cmp    %rax,%r8
 123bbee:	0f 84 5e fd ff ff    	je     123b952 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x352>
 123bbf4:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 123bbfb:	00 
 123bbfc:	41 80 e3 0f          	and    $0xf,%r11b
 123bc00:	41 80 fb 07          	cmp    $0x7,%r11b
 123bc04:	75 2a                	jne    123bc30 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x630>
 123bc06:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 123bc0b:	74 23                	je     123bc30 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x630>
 123bc0d:	49 39 12             	cmp    %rdx,(%r10)
 123bc10:	75 1e                	jne    123bc30 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x630>
 123bc12:	48 39 b4 c1 d0 32 02 	cmp    %rsi,0x232d0(%rcx,%rax,8)
 123bc19:	00 
 123bc1a:	75 14                	jne    123bc30 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x630>
 123bc1c:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 123bc23:	00 
 123bc24:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 123bc2b:	00 00 00 00 00 
 123bc30:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 123bc37:	00 
 123bc38:	41 80 e3 0f          	and    $0xf,%r11b
 123bc3c:	41 80 fb 07          	cmp    $0x7,%r11b
 123bc40:	75 9e                	jne    123bbe0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x5e0>
 123bc42:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 123bc49:	00 
 123bc4a:	74 94                	je     123bbe0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x5e0>
 123bc4c:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 123bc53:	75 8b                	jne    123bbe0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x5e0>
 123bc55:	48 39 b4 c1 d8 32 02 	cmp    %rsi,0x232d8(%rcx,%rax,8)
 123bc5c:	00 
 123bc5d:	75 81                	jne    123bbe0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x5e0>
 123bc5f:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 123bc66:	00 
 123bc67:	e9 74 ff ff ff       	jmp    123bbe0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x5e0>
 123bc6c:	4d 89 c8             	mov    %r9,%r8
 123bc6f:	49 83 e0 fe          	and    $0xfffffffffffffffe,%r8
 123bc73:	4c 8d 51 58          	lea    0x58(%rcx),%r10
 123bc77:	31 c0                	xor    %eax,%eax
 123bc79:	eb 19                	jmp    123bc94 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x694>
 123bc7b:	0f 1f 44 00 00       	nopl   0x0(%rax,%rax,1)
 123bc80:	48 83 c0 02          	add    $0x2,%rax
 123bc84:	49 81 c2 30 02 00 00 	add    $0x230,%r10
 123bc8b:	49 39 c0             	cmp    %rax,%r8
 123bc8e:	0f 84 64 fe ff ff    	je     123baf8 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x4f8>
 123bc94:	45 0f b6 9a d8 00 00 	movzbl 0xd8(%r10),%r11d
 123bc9b:	00 
 123bc9c:	41 80 e3 0f          	and    $0xf,%r11b
 123bca0:	41 80 fb 07          	cmp    $0x7,%r11b
 123bca4:	75 2a                	jne    123bcd0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x6d0>
 123bca6:	41 80 7a 08 00       	cmpb   $0x0,0x8(%r10)
 123bcab:	74 23                	je     123bcd0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x6d0>
 123bcad:	49 39 12             	cmp    %rdx,(%r10)
 123bcb0:	75 1e                	jne    123bcd0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x6d0>
 123bcb2:	4c 39 ac c1 d0 32 02 	cmp    %r13,0x232d0(%rcx,%rax,8)
 123bcb9:	00 
 123bcba:	75 14                	jne    123bcd0 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x6d0>
 123bcbc:	c6 84 01 d3 42 02 00 	movb   $0x0,0x242d3(%rcx,%rax,1)
 123bcc3:	00 
 123bcc4:	66 66 66 2e 0f 1f 84 	data16 data16 cs nopw 0x0(%rax,%rax,1)
 123bccb:	00 00 00 00 00 
 123bcd0:	45 0f b6 9a f0 01 00 	movzbl 0x1f0(%r10),%r11d
 123bcd7:	00 
 123bcd8:	41 80 e3 0f          	and    $0xf,%r11b
 123bcdc:	41 80 fb 07          	cmp    $0x7,%r11b
 123bce0:	75 9e                	jne    123bc80 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x680>
 123bce2:	41 80 ba 20 01 00 00 	cmpb   $0x0,0x120(%r10)
 123bce9:	00 
 123bcea:	74 94                	je     123bc80 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x680>
 123bcec:	49 39 92 18 01 00 00 	cmp    %rdx,0x118(%r10)
 123bcf3:	75 8b                	jne    123bc80 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x680>
 123bcf5:	4c 39 ac c1 d8 32 02 	cmp    %r13,0x232d8(%rcx,%rax,8)
 123bcfc:	00 
 123bcfd:	75 81                	jne    123bc80 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x680>
 123bcff:	c6 84 01 d4 42 02 00 	movb   $0x0,0x242d4(%rcx,%rax,1)
 123bd06:	00 
 123bd07:	e9 74 ff ff ff       	jmp    123bc80 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x680>
 123bd0c:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 123bd13:	74 26                	je     123bd3b <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x73b>
 123bd15:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 123bd1c:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 123bd23:	18 01 00 00 
 123bd27:	44 89 fa             	mov    %r15d,%edx
 123bd2a:	c1 e2 04             	shl    $0x4,%edx
 123bd2d:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 123bd34:	01 
 123bd35:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 123bd3b:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 123bd42:	e8 29 b4 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123bd47:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123bd4b:	66 44 89 78 10       	mov    %r15w,0x10(%rax)
 123bd50:	e9 0e fd ff ff       	jmp    123ba63 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x463>
 123bd55:	48 8b 7d b0          	mov    -0x50(%rbp),%rdi
 123bd59:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 123bd5d:	4c 89 fa             	mov    %r15,%rdx
 123bd60:	4c 89 f1             	mov    %r14,%rcx
 123bd63:	e8 38 a8 03 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 123bd68:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 123bd6f:	74 26                	je     123bd97 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x797>
 123bd71:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 123bd78:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 123bd7f:	18 01 00 00 
 123bd83:	44 89 e2             	mov    %r12d,%edx
 123bd86:	c1 e2 04             	shl    $0x4,%edx
 123bd89:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 123bd90:	01 
 123bd91:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 123bd97:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 123bd9e:	e8 cd b3 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123bda3:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123bda7:	66 44 89 60 10       	mov    %r12w,0x10(%rax)
 123bdac:	e9 b2 fc ff ff       	jmp    123ba63 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x463>
 123bdb1:	4c 89 ff             	mov    %r15,%rdi
 123bdb4:	4c 89 f6             	mov    %r14,%rsi
 123bdb7:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 123bdbb:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123bdbf:	e8 dc a7 03 00       	call   12765a0 <br.freeQualityRecorded__anon_28969>
 123bdc4:	80 bd 58 ff ff ff 00 	cmpb   $0x0,-0xa8(%rbp)
 123bdcb:	74 25                	je     123bdf2 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x7f2>
 123bdcd:	48 8b 85 40 ff ff ff 	mov    -0xc0(%rbp),%rax
 123bdd4:	48 69 8d 50 ff ff ff 	imul   $0x118,-0xb0(%rbp),%rcx
 123bddb:	18 01 00 00 
 123bddf:	89 da                	mov    %ebx,%edx
 123bde1:	c1 e2 04             	shl    $0x4,%edx
 123bde4:	c5 f8 10 82 f0 5d 03 	vmovups 0x1035df0(%rdx),%xmm0
 123bdeb:	01 
 123bdec:	c5 f8 11 44 08 68    	vmovups %xmm0,0x68(%rax,%rcx,1)
 123bdf2:	48 8d bd 20 ff ff ff 	lea    -0xe0(%rbp),%rdi
 123bdf9:	e8 72 b3 03 00       	call   1277170 <br.encoder.quality_profile.Scope.finish>
 123bdfe:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123be02:	66 89 58 10          	mov    %bx,0x10(%rax)
 123be06:	e9 58 fc ff ff       	jmp    123ba63 <br.encodeCommandPlanWithDistanceParameterSearchAllocRecorded__anon_29477+0x463>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
