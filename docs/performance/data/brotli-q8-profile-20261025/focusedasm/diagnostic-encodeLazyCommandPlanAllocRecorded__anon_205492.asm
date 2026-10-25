
/home/passchaos/project-z/vort-brotli-q8-profile/.zig-cache/o/f67ed575467f368cf1ce021440d4e813/vort-br-quality-stage-profile:     file format elf64-x86-64


Disassembly of section .text:

000000000123e5d0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492>:
 123e5d0:	55                   	push   %rbp
 123e5d1:	48 89 e5             	mov    %rsp,%rbp
 123e5d4:	41 57                	push   %r15
 123e5d6:	41 56                	push   %r14
 123e5d8:	41 55                	push   %r13
 123e5da:	41 54                	push   %r12
 123e5dc:	53                   	push   %rbx
 123e5dd:	48 81 ec 38 1d 00 00 	sub    $0x1d38,%rsp
 123e5e4:	4d 89 c7             	mov    %r8,%r15
 123e5e7:	49 89 cd             	mov    %rcx,%r13
 123e5ea:	49 89 f4             	mov    %rsi,%r12
 123e5ed:	48 89 fb             	mov    %rdi,%rbx
 123e5f0:	49 83 f9 02          	cmp    $0x2,%r9
 123e5f4:	48 89 75 c8          	mov    %rsi,-0x38(%rbp)
 123e5f8:	48 89 4d 98          	mov    %rcx,-0x68(%rbp)
 123e5fc:	48 89 7d c0          	mov    %rdi,-0x40(%rbp)
 123e600:	48 89 55 a0          	mov    %rdx,-0x60(%rbp)
 123e604:	0f 85 b6 01 00 00    	jne    123e7c0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x1f0>
 123e60a:	41 80 7f 58 01       	cmpb   $0x1,0x58(%r15)
 123e60f:	0f 85 ab 01 00 00    	jne    123e7c0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x1f0>
 123e615:	41 f6 47 59 03       	testb  $0x3,0x59(%r15)
 123e61a:	0f 85 a0 01 00 00    	jne    123e7c0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x1f0>
 123e620:	49 83 7f 10 03       	cmpq   $0x3,0x10(%r15)
 123e625:	0f 85 95 01 00 00    	jne    123e7c0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x1f0>
 123e62b:	48 8d bd 88 f3 ff ff 	lea    -0xc78(%rbp),%rdi
 123e632:	41 b9 02 00 00 00    	mov    $0x2,%r9d
 123e638:	4c 89 e6             	mov    %r12,%rsi
 123e63b:	4c 89 e9             	mov    %r13,%rcx
 123e63e:	4d 89 f8             	mov    %r15,%r8
 123e641:	ff 75 18             	push   0x18(%rbp)
 123e644:	ff 75 10             	push   0x10(%rbp)
 123e647:	e8 64 72 02 00       	call   12658b0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502>
 123e64c:	48 83 c4 10          	add    $0x10,%rsp
 123e650:	0f b7 85 e8 f4 ff ff 	movzwl -0xb18(%rbp),%eax
 123e657:	66 85 c0             	test   %ax,%ax
 123e65a:	0f 85 03 08 00 00    	jne    123ee63 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x893>
 123e660:	48 8d bd 60 fa ff ff 	lea    -0x5a0(%rbp),%rdi
 123e667:	48 8d b5 88 f3 ff ff 	lea    -0xc78(%rbp),%rsi
 123e66e:	ba 60 01 00 00       	mov    $0x160,%edx
 123e673:	e8 e8 10 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123e678:	48 8b 85 60 fa ff ff 	mov    -0x5a0(%rbp),%rax
 123e67f:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 123e683:	48 8b 85 68 fa ff ff 	mov    -0x598(%rbp),%rax
 123e68a:	48 89 45 d0          	mov    %rax,-0x30(%rbp)
 123e68e:	48 c7 85 68 ff ff ff 	movq   $0x0,-0x98(%rbp)
 123e695:	00 00 00 00 
 123e699:	48 8d 85 68 ff ff ff 	lea    -0x98(%rbp),%rax
 123e6a0:	48 8d bd b8 fe ff ff 	lea    -0x148(%rbp),%rdi
 123e6a7:	48 8d b5 a8 ee ff ff 	lea    -0x1158(%rbp),%rsi
 123e6ae:	ba 02 00 00 00       	mov    $0x2,%edx
 123e6b3:	41 b9 02 00 00 00    	mov    $0x2,%r9d
 123e6b9:	4c 89 e9             	mov    %r13,%rcx
 123e6bc:	4c 89 7d 90          	mov    %r15,-0x70(%rbp)
 123e6c0:	4d 89 f8             	mov    %r15,%r8
 123e6c3:	6a 01                	push   $0x1
 123e6c5:	50                   	push   %rax
 123e6c6:	e8 65 fc ff ff       	call   123e330 <br.encoder.command_plan.withoutCopiesInto>
 123e6cb:	48 83 c4 10          	add    $0x10,%rsp
 123e6cf:	0f b7 9d c8 fe ff ff 	movzwl -0x138(%rbp),%ebx
 123e6d6:	66 85 db             	test   %bx,%bx
 123e6d9:	0f 85 e5 07 00 00    	jne    123eec4 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x8f4>
 123e6df:	4c 8b b5 b8 fe ff ff 	mov    -0x148(%rbp),%r14
 123e6e6:	4c 8b bd c0 fe ff ff 	mov    -0x140(%rbp),%r15
 123e6ed:	48 8d bd 20 f2 ff ff 	lea    -0xde0(%rbp),%rdi
 123e6f4:	4c 89 e6             	mov    %r12,%rsi
 123e6f7:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 123e6fb:	4c 89 e9             	mov    %r13,%rcx
 123e6fe:	4d 89 f0             	mov    %r14,%r8
 123e701:	4d 89 f9             	mov    %r15,%r9
 123e704:	ff 75 18             	push   0x18(%rbp)
 123e707:	ff 75 10             	push   0x10(%rbp)
 123e70a:	e8 a1 71 02 00       	call   12658b0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502>
 123e70f:	48 83 c4 10          	add    $0x10,%rsp
 123e713:	0f b7 9d 80 f3 ff ff 	movzwl -0xc80(%rbp),%ebx
 123e71a:	66 85 db             	test   %bx,%bx
 123e71d:	0f 85 a1 07 00 00    	jne    123eec4 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x8f4>
 123e723:	48 8d 9d f0 f4 ff ff 	lea    -0xb10(%rbp),%rbx
 123e72a:	48 8d b5 20 f2 ff ff 	lea    -0xde0(%rbp),%rsi
 123e731:	ba 60 01 00 00       	mov    $0x160,%edx
 123e736:	48 89 df             	mov    %rbx,%rdi
 123e739:	e8 22 10 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123e73e:	4c 8b ad f0 f4 ff ff 	mov    -0xb10(%rbp),%r13
 123e745:	4c 8b a5 f8 f4 ff ff 	mov    -0xb08(%rbp),%r12
 123e74c:	4c 3b 65 d0          	cmp    -0x30(%rbp),%r12
 123e750:	0f 83 58 05 00 00    	jae    123ecae <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6de>
 123e756:	48 83 ec 08          	sub    $0x8,%rsp
 123e75a:	48 8d bd 30 ff ff ff 	lea    -0xd0(%rbp),%rdi
 123e761:	48 8b 75 c8          	mov    -0x38(%rbp),%rsi
 123e765:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 123e769:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 123e76d:	4d 89 f0             	mov    %r14,%r8
 123e770:	4d 89 f9             	mov    %r15,%r9
 123e773:	53                   	push   %rbx
 123e774:	ff 75 18             	push   0x18(%rbp)
 123e777:	ff 75 10             	push   0x10(%rbp)
 123e77a:	e8 a1 0a 00 00       	call   123f220 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540>
 123e77f:	48 83 c4 20          	add    $0x20,%rsp
 123e783:	44 0f b7 b5 40 ff ff 	movzwl -0xc0(%rbp),%r14d
 123e78a:	ff 
 123e78b:	66 45 85 f6          	test   %r14w,%r14w
 123e78f:	0f 84 12 06 00 00    	je     123eda7 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x7d7>
 123e795:	4d 85 e4             	test   %r12,%r12
 123e798:	0f 84 5c 06 00 00    	je     123edfa <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x82a>
 123e79e:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 123e7a2:	49 8b 3f             	mov    (%r15),%rdi
 123e7a5:	49 8b 47 08          	mov    0x8(%r15),%rax
 123e7a9:	48 8b 5d 08          	mov    0x8(%rbp),%rbx
 123e7ad:	4c 89 ee             	mov    %r13,%rsi
 123e7b0:	4c 89 e2             	mov    %r12,%rdx
 123e7b3:	31 c9                	xor    %ecx,%ecx
 123e7b5:	49 89 d8             	mov    %rbx,%r8
 123e7b8:	ff 50 18             	call   *0x18(%rax)
 123e7bb:	e9 42 06 00 00       	jmp    123ee02 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x832>
 123e7c0:	48 8d bd 90 fe ff ff 	lea    -0x170(%rbp),%rdi
 123e7c7:	4c 89 fe             	mov    %r15,%rsi
 123e7ca:	4d 89 ce             	mov    %r9,%r14
 123e7cd:	4c 89 ca             	mov    %r9,%rdx
 123e7d0:	e8 2b 07 00 00       	call   123ef00 <br.encoder.short_match_candidates.collect>
 123e7d5:	48 8b 85 90 fe ff ff 	mov    -0x170(%rbp),%rax
 123e7dc:	48 89 85 70 ff ff ff 	mov    %rax,-0x90(%rbp)
 123e7e3:	48 85 c0             	test   %rax,%rax
 123e7e6:	0f 84 82 03 00 00    	je     123eb6e <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x59e>
 123e7ec:	48 8d bd 28 fd ff ff 	lea    -0x2d8(%rbp),%rdi
 123e7f3:	4c 89 e6             	mov    %r12,%rsi
 123e7f6:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 123e7fa:	4c 89 e9             	mov    %r13,%rcx
 123e7fd:	4d 89 f8             	mov    %r15,%r8
 123e800:	4d 89 f1             	mov    %r14,%r9
 123e803:	ff 75 18             	push   0x18(%rbp)
 123e806:	ff 75 10             	push   0x10(%rbp)
 123e809:	e8 a2 70 02 00       	call   12658b0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502>
 123e80e:	48 83 c4 10          	add    $0x10,%rsp
 123e812:	0f b7 85 88 fe ff ff 	movzwl -0x178(%rbp),%eax
 123e819:	66 85 c0             	test   %ax,%ax
 123e81c:	0f 85 41 06 00 00    	jne    123ee63 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x893>
 123e822:	48 8b 85 28 fd ff ff 	mov    -0x2d8(%rbp),%rax
 123e829:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 123e82d:	48 8b 85 30 fd ff ff 	mov    -0x2d0(%rbp),%rax
 123e834:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 123e838:	48 8d b5 38 fd ff ff 	lea    -0x2c8(%rbp),%rsi
 123e83f:	48 8d bd 50 f6 ff ff 	lea    -0x9b0(%rbp),%rdi
 123e846:	ba 50 01 00 00       	mov    $0x150,%edx
 123e84b:	e8 10 0f 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123e850:	4d 89 f1             	mov    %r14,%r9
 123e853:	44 89 c8             	mov    %r9d,%eax
 123e856:	83 e0 03             	and    $0x3,%eax
 123e859:	48 89 85 78 ff ff ff 	mov    %rax,-0x88(%rbp)
 123e860:	4c 89 f3             	mov    %r14,%rbx
 123e863:	48 83 e3 fc          	and    $0xfffffffffffffffc,%rbx
 123e867:	31 f6                	xor    %esi,%esi
 123e869:	4c 89 75 80          	mov    %r14,-0x80(%rbp)
 123e86d:	4c 89 7d 90          	mov    %r15,-0x70(%rbp)
 123e871:	4c 89 7d 88          	mov    %r15,-0x78(%rbp)
 123e875:	66 66 2e 0f 1f 84 00 	data16 cs nopw 0x0(%rax,%rax,1)
 123e87c:	00 00 00 00 
 123e880:	4d 85 c9             	test   %r9,%r9
 123e883:	0f 84 b7 00 00 00    	je     123e940 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x370>
 123e889:	0f b7 84 75 98 fe ff 	movzwl -0x168(%rbp,%rsi,2),%eax
 123e890:	ff 
 123e891:	31 c9                	xor    %ecx,%ecx
 123e893:	45 31 d2             	xor    %r10d,%r10d
 123e896:	49 83 f9 04          	cmp    $0x4,%r9
 123e89a:	73 4d                	jae    123e8e9 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x319>
 123e89c:	48 83 bd 78 ff ff ff 	cmpq   $0x0,-0x88(%rbp)
 123e8a3:	00 
 123e8a4:	0f 84 99 00 00 00    	je     123e943 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x373>
 123e8aa:	48 8b 95 78 ff ff ff 	mov    -0x88(%rbp),%rdx
 123e8b1:	eb 15                	jmp    123e8c8 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x2f8>
 123e8b3:	66 66 66 66 2e 0f 1f 	data16 data16 data16 cs nopw 0x0(%rax,%rax,1)
 123e8ba:	84 00 00 00 00 00 
 123e8c0:	48 ff c1             	inc    %rcx
 123e8c3:	48 ff ca             	dec    %rdx
 123e8c6:	74 7b                	je     123e943 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x373>
 123e8c8:	0f a3 c8             	bt     %ecx,%eax
 123e8cb:	73 f3                	jae    123e8c0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x2f0>
 123e8cd:	4a 89 8c d5 48 ff ff 	mov    %rcx,-0xb8(%rbp,%r10,8)
 123e8d4:	ff 
 123e8d5:	49 ff c2             	inc    %r10
 123e8d8:	eb e6                	jmp    123e8c0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x2f0>
 123e8da:	66 0f 1f 44 00 00    	nopw   0x0(%rax,%rax,1)
 123e8e0:	48 83 c1 04          	add    $0x4,%rcx
 123e8e4:	48 39 cb             	cmp    %rcx,%rbx
 123e8e7:	74 b3                	je     123e89c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x2cc>
 123e8e9:	0f a3 c8             	bt     %ecx,%eax
 123e8ec:	73 0b                	jae    123e8f9 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x329>
 123e8ee:	4a 89 8c d5 48 ff ff 	mov    %rcx,-0xb8(%rbp,%r10,8)
 123e8f5:	ff 
 123e8f6:	49 ff c2             	inc    %r10
 123e8f9:	48 8d 51 01          	lea    0x1(%rcx),%rdx
 123e8fd:	0f a3 d0             	bt     %edx,%eax
 123e900:	73 0b                	jae    123e90d <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x33d>
 123e902:	4a 89 94 d5 48 ff ff 	mov    %rdx,-0xb8(%rbp,%r10,8)
 123e909:	ff 
 123e90a:	49 ff c2             	inc    %r10
 123e90d:	48 8d 51 02          	lea    0x2(%rcx),%rdx
 123e911:	0f a3 d0             	bt     %edx,%eax
 123e914:	73 0b                	jae    123e921 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x351>
 123e916:	4a 89 94 d5 48 ff ff 	mov    %rdx,-0xb8(%rbp,%r10,8)
 123e91d:	ff 
 123e91e:	49 ff c2             	inc    %r10
 123e921:	48 8d 51 03          	lea    0x3(%rcx),%rdx
 123e925:	0f a3 d0             	bt     %edx,%eax
 123e928:	73 b6                	jae    123e8e0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x310>
 123e92a:	4a 89 94 d5 48 ff ff 	mov    %rdx,-0xb8(%rbp,%r10,8)
 123e931:	ff 
 123e932:	49 ff c2             	inc    %r10
 123e935:	eb a9                	jmp    123e8e0 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x310>
 123e937:	66 0f 1f 84 00 00 00 	nopw   0x0(%rax,%rax,1)
 123e93e:	00 00 
 123e940:	45 31 d2             	xor    %r10d,%r10d
 123e943:	48 89 75 d0          	mov    %rsi,-0x30(%rbp)
 123e947:	ba 10 00 00 00       	mov    $0x10,%edx
 123e94c:	48 8d bd 00 ff ff ff 	lea    -0x100(%rbp),%rdi
 123e953:	48 8d b5 a8 e2 ff ff 	lea    -0x1d58(%rbp),%rsi
 123e95a:	4c 89 e9             	mov    %r13,%rcx
 123e95d:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 123e961:	4d 89 cf             	mov    %r9,%r15
 123e964:	41 52                	push   %r10
 123e966:	48 8d 85 48 ff ff ff 	lea    -0xb8(%rbp),%rax
 123e96d:	50                   	push   %rax
 123e96e:	e8 bd f9 ff ff       	call   123e330 <br.encoder.command_plan.withoutCopiesInto>
 123e973:	48 83 c4 10          	add    $0x10,%rsp
 123e977:	44 0f b7 b5 10 ff ff 	movzwl -0xf0(%rbp),%r14d
 123e97e:	ff 
 123e97f:	66 45 85 f6          	test   %r14w,%r14w
 123e983:	0f 85 ca 03 00 00    	jne    123ed53 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x783>
 123e989:	4c 8b b5 00 ff ff ff 	mov    -0x100(%rbp),%r14
 123e990:	4c 89 e9             	mov    %r13,%rcx
 123e993:	4c 8b ad 08 ff ff ff 	mov    -0xf8(%rbp),%r13
 123e99a:	48 8d bd c0 fb ff ff 	lea    -0x440(%rbp),%rdi
 123e9a1:	4c 89 e6             	mov    %r12,%rsi
 123e9a4:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 123e9a8:	4d 89 f0             	mov    %r14,%r8
 123e9ab:	4d 89 e9             	mov    %r13,%r9
 123e9ae:	ff 75 18             	push   0x18(%rbp)
 123e9b1:	ff 75 10             	push   0x10(%rbp)
 123e9b4:	e8 f7 6e 02 00       	call   12658b0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502>
 123e9b9:	48 83 c4 10          	add    $0x10,%rsp
 123e9bd:	44 0f b7 a5 20 fd ff 	movzwl -0x2e0(%rbp),%r12d
 123e9c4:	ff 
 123e9c5:	66 45 85 e4          	test   %r12w,%r12w
 123e9c9:	0f 85 a9 03 00 00    	jne    123ed78 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x7a8>
 123e9cf:	48 8b 85 c0 fb ff ff 	mov    -0x440(%rbp),%rax
 123e9d6:	48 89 45 b8          	mov    %rax,-0x48(%rbp)
 123e9da:	4c 8b a5 c8 fb ff ff 	mov    -0x438(%rbp),%r12
 123e9e1:	ba 50 01 00 00       	mov    $0x150,%edx
 123e9e6:	48 8d bd 68 ef ff ff 	lea    -0x1098(%rbp),%rdi
 123e9ed:	48 8d b5 d0 fb ff ff 	lea    -0x430(%rbp),%rsi
 123e9f4:	e8 67 0d 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123e9f9:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 123e9fd:	49 39 d4             	cmp    %rdx,%r12
 123ea00:	73 6e                	jae    123ea70 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x4a0>
 123ea02:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123ea06:	48 8b 38             	mov    (%rax),%rdi
 123ea09:	48 8b 40 08          	mov    0x8(%rax),%rax
 123ea0d:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ea11:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 123ea15:	31 c9                	xor    %ecx,%ecx
 123ea17:	ff 50 18             	call   *0x18(%rax)
 123ea1a:	ba 50 01 00 00       	mov    $0x150,%edx
 123ea1f:	48 8d bd 50 f6 ff ff 	lea    -0x9b0(%rbp),%rdi
 123ea26:	48 8d b5 68 ef ff ff 	lea    -0x1098(%rbp),%rsi
 123ea2d:	e8 2e 0d 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123ea32:	4c 89 e8             	mov    %r13,%rax
 123ea35:	48 c1 e0 05          	shl    $0x5,%rax
 123ea39:	48 8d 14 40          	lea    (%rax,%rax,2),%rdx
 123ea3d:	48 8d bd a8 e8 ff ff 	lea    -0x1758(%rbp),%rdi
 123ea44:	4c 89 f6             	mov    %r14,%rsi
 123ea47:	e8 14 0d 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123ea4c:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 123ea50:	48 89 45 a8          	mov    %rax,-0x58(%rbp)
 123ea54:	4c 89 65 b0          	mov    %r12,-0x50(%rbp)
 123ea58:	48 8d 85 a8 e8 ff ff 	lea    -0x1758(%rbp),%rax
 123ea5f:	48 89 45 88          	mov    %rax,-0x78(%rbp)
 123ea63:	4c 89 6d 80          	mov    %r13,-0x80(%rbp)
 123ea67:	eb 27                	jmp    123ea90 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x4c0>
 123ea69:	0f 1f 80 00 00 00 00 	nopl   0x0(%rax)
 123ea70:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 123ea74:	4d 85 e4             	test   %r12,%r12
 123ea77:	74 17                	je     123ea90 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x4c0>
 123ea79:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123ea7d:	48 8b 38             	mov    (%rax),%rdi
 123ea80:	48 8b 40 08          	mov    0x8(%rax),%rax
 123ea84:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ea88:	4c 89 e2             	mov    %r12,%rdx
 123ea8b:	31 c9                	xor    %ecx,%ecx
 123ea8d:	ff 50 18             	call   *0x18(%rax)
 123ea90:	4c 8b 6d 98          	mov    -0x68(%rbp),%r13
 123ea94:	4d 89 f9             	mov    %r15,%r9
 123ea97:	48 8b 75 d0          	mov    -0x30(%rbp),%rsi
 123ea9b:	48 ff c6             	inc    %rsi
 123ea9e:	48 3b b5 70 ff ff ff 	cmp    -0x90(%rbp),%rsi
 123eaa5:	4c 8b 65 c8          	mov    -0x38(%rbp),%r12
 123eaa9:	0f 85 d1 fd ff ff    	jne    123e880 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x2b0>
 123eaaf:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 123eab3:	48 89 85 00 f9 ff ff 	mov    %rax,-0x700(%rbp)
 123eaba:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 123eabe:	48 89 85 08 f9 ff ff 	mov    %rax,-0x6f8(%rbp)
 123eac5:	48 8d bd 10 f9 ff ff 	lea    -0x6f0(%rbp),%rdi
 123eacc:	48 8d b5 50 f6 ff ff 	lea    -0x9b0(%rbp),%rsi
 123ead3:	ba 50 01 00 00       	mov    $0x150,%edx
 123ead8:	e8 83 0c 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123eadd:	48 83 ec 08          	sub    $0x8,%rsp
 123eae1:	48 8d 85 00 f9 ff ff 	lea    -0x700(%rbp),%rax
 123eae8:	48 8d bd e8 fe ff ff 	lea    -0x118(%rbp),%rdi
 123eaef:	4c 89 e6             	mov    %r12,%rsi
 123eaf2:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 123eaf6:	4c 89 e9             	mov    %r13,%rcx
 123eaf9:	4c 8b 45 88          	mov    -0x78(%rbp),%r8
 123eafd:	4c 8b 4d 80          	mov    -0x80(%rbp),%r9
 123eb01:	50                   	push   %rax
 123eb02:	ff 75 18             	push   0x18(%rbp)
 123eb05:	ff 75 10             	push   0x10(%rbp)
 123eb08:	e8 13 07 00 00       	call   123f220 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540>
 123eb0d:	48 83 c4 20          	add    $0x20,%rsp
 123eb11:	0f b7 9d f8 fe ff ff 	movzwl -0x108(%rbp),%ebx
 123eb18:	66 85 db             	test   %bx,%bx
 123eb1b:	0f 85 4b 03 00 00    	jne    123ee6c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x89c>
 123eb21:	48 8b 9d e8 fe ff ff 	mov    -0x118(%rbp),%rbx
 123eb28:	48 85 db             	test   %rbx,%rbx
 123eb2b:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 123eb2f:	0f 84 34 01 00 00    	je     123ec69 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x699>
 123eb35:	4c 8b b5 f0 fe ff ff 	mov    -0x110(%rbp),%r14
 123eb3c:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 123eb40:	48 85 d2             	test   %rdx,%rdx
 123eb43:	74 16                	je     123eb5b <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x58b>
 123eb45:	49 8b 3c 24          	mov    (%r12),%rdi
 123eb49:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 123eb4e:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123eb52:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 123eb56:	31 c9                	xor    %ecx,%ecx
 123eb58:	ff 50 18             	call   *0x18(%rax)
 123eb5b:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 123eb62:	49 89 1f             	mov    %rbx,(%r15)
 123eb65:	4d 89 77 08          	mov    %r14,0x8(%r15)
 123eb69:	e9 2e 01 00 00       	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>
 123eb6e:	48 8d bd b8 f0 ff ff 	lea    -0xf48(%rbp),%rdi
 123eb75:	4c 89 e6             	mov    %r12,%rsi
 123eb78:	4c 89 f3             	mov    %r14,%rbx
 123eb7b:	4d 89 fe             	mov    %r15,%r14
 123eb7e:	4c 8b 7d a0          	mov    -0x60(%rbp),%r15
 123eb82:	4c 89 fa             	mov    %r15,%rdx
 123eb85:	4c 89 e9             	mov    %r13,%rcx
 123eb88:	4d 89 f0             	mov    %r14,%r8
 123eb8b:	49 89 d9             	mov    %rbx,%r9
 123eb8e:	48 8b 45 18          	mov    0x18(%rbp),%rax
 123eb92:	50                   	push   %rax
 123eb93:	48 8b 45 10          	mov    0x10(%rbp),%rax
 123eb97:	50                   	push   %rax
 123eb98:	e8 13 6d 02 00       	call   12658b0 <br.encodePreferredCommandPlanAllocRecorded__anon_205502>
 123eb9d:	48 83 c4 10          	add    $0x10,%rsp
 123eba1:	0f b7 85 18 f2 ff ff 	movzwl -0xde8(%rbp),%eax
 123eba8:	66 85 c0             	test   %ax,%ax
 123ebab:	0f 85 e8 02 00 00    	jne    123ee99 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x8c9>
 123ebb1:	48 8d bd a0 f7 ff ff 	lea    -0x860(%rbp),%rdi
 123ebb8:	48 8d b5 b8 f0 ff ff 	lea    -0xf48(%rbp),%rsi
 123ebbf:	ba 60 01 00 00       	mov    $0x160,%edx
 123ebc4:	e8 97 0b 0a 00       	call   12df760 <compiler_rt.memcpy.memcpyFast>
 123ebc9:	48 8b 8d a0 f7 ff ff 	mov    -0x860(%rbp),%rcx
 123ebd0:	48 89 4d b8          	mov    %rcx,-0x48(%rbp)
 123ebd4:	48 8b 8d a8 f7 ff ff 	mov    -0x858(%rbp),%rcx
 123ebdb:	48 89 4d d0          	mov    %rcx,-0x30(%rbp)
 123ebdf:	48 83 ec 08          	sub    $0x8,%rsp
 123ebe3:	48 8d bd d0 fe ff ff 	lea    -0x130(%rbp),%rdi
 123ebea:	4c 89 e6             	mov    %r12,%rsi
 123ebed:	4c 89 fa             	mov    %r15,%rdx
 123ebf0:	4c 89 e9             	mov    %r13,%rcx
 123ebf3:	4d 89 f0             	mov    %r14,%r8
 123ebf6:	49 89 d9             	mov    %rbx,%r9
 123ebf9:	48 8d 85 a0 f7 ff ff 	lea    -0x860(%rbp),%rax
 123ec00:	50                   	push   %rax
 123ec01:	ff 75 18             	push   0x18(%rbp)
 123ec04:	ff 75 10             	push   0x10(%rbp)
 123ec07:	e8 14 06 00 00       	call   123f220 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540>
 123ec0c:	48 83 c4 20          	add    $0x20,%rsp
 123ec10:	0f b7 9d e0 fe ff ff 	movzwl -0x120(%rbp),%ebx
 123ec17:	66 85 db             	test   %bx,%bx
 123ec1a:	0f 85 86 02 00 00    	jne    123eea6 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x8d6>
 123ec20:	48 8b 9d d0 fe ff ff 	mov    -0x130(%rbp),%rbx
 123ec27:	48 85 db             	test   %rbx,%rbx
 123ec2a:	74 55                	je     123ec81 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6b1>
 123ec2c:	4c 8b a5 d8 fe ff ff 	mov    -0x128(%rbp),%r12
 123ec33:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 123ec37:	48 85 d2             	test   %rdx,%rdx
 123ec3a:	74 18                	je     123ec54 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x684>
 123ec3c:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123ec40:	48 8b 38             	mov    (%rax),%rdi
 123ec43:	48 8b 40 08          	mov    0x8(%rax),%rax
 123ec47:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ec4b:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 123ec4f:	31 c9                	xor    %ecx,%ecx
 123ec51:	ff 50 18             	call   *0x18(%rax)
 123ec54:	4c 8b 6d c0          	mov    -0x40(%rbp),%r13
 123ec58:	66 41 c7 45 10 00 00 	movw   $0x0,0x10(%r13)
 123ec5f:	49 89 5d 00          	mov    %rbx,0x0(%r13)
 123ec63:	4d 89 65 08          	mov    %r12,0x8(%r13)
 123ec67:	eb 33                	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>
 123ec69:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 123ec70:	48 8b 45 a8          	mov    -0x58(%rbp),%rax
 123ec74:	49 89 07             	mov    %rax,(%r15)
 123ec77:	48 8b 45 b0          	mov    -0x50(%rbp),%rax
 123ec7b:	49 89 47 08          	mov    %rax,0x8(%r15)
 123ec7f:	eb 1b                	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>
 123ec81:	4c 8b 6d c0          	mov    -0x40(%rbp),%r13
 123ec85:	66 41 c7 45 10 00 00 	movw   $0x0,0x10(%r13)
 123ec8c:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 123ec90:	49 89 45 00          	mov    %rax,0x0(%r13)
 123ec94:	48 8b 45 d0          	mov    -0x30(%rbp),%rax
 123ec98:	49 89 45 08          	mov    %rax,0x8(%r13)
 123ec9c:	48 81 c4 38 1d 00 00 	add    $0x1d38,%rsp
 123eca3:	5b                   	pop    %rbx
 123eca4:	41 5c                	pop    %r12
 123eca6:	41 5d                	pop    %r13
 123eca8:	41 5e                	pop    %r14
 123ecaa:	41 5f                	pop    %r15
 123ecac:	5d                   	pop    %rbp
 123ecad:	c3                   	ret    
 123ecae:	4d 85 e4             	test   %r12,%r12
 123ecb1:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 123ecb5:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 123ecb9:	74 16                	je     123ecd1 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x701>
 123ecbb:	49 8b 3e             	mov    (%r14),%rdi
 123ecbe:	49 8b 46 08          	mov    0x8(%r14),%rax
 123ecc2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ecc6:	4c 89 ee             	mov    %r13,%rsi
 123ecc9:	4c 89 e2             	mov    %r12,%rdx
 123eccc:	31 c9                	xor    %ecx,%ecx
 123ecce:	ff 50 18             	call   *0x18(%rax)
 123ecd1:	48 83 ec 08          	sub    $0x8,%rsp
 123ecd5:	48 8d bd 18 ff ff ff 	lea    -0xe8(%rbp),%rdi
 123ecdc:	41 b9 02 00 00 00    	mov    $0x2,%r9d
 123ece2:	4c 89 f6             	mov    %r14,%rsi
 123ece5:	48 8b 55 a0          	mov    -0x60(%rbp),%rdx
 123ece9:	48 8b 4d 98          	mov    -0x68(%rbp),%rcx
 123eced:	4c 8b 45 90          	mov    -0x70(%rbp),%r8
 123ecf1:	48 8d 85 60 fa ff ff 	lea    -0x5a0(%rbp),%rax
 123ecf8:	50                   	push   %rax
 123ecf9:	ff 75 18             	push   0x18(%rbp)
 123ecfc:	ff 75 10             	push   0x10(%rbp)
 123ecff:	e8 1c 05 00 00       	call   123f220 <br.encodeEntropySplitCandidateAllocRecorded__anon_205540>
 123ed04:	48 83 c4 20          	add    $0x20,%rsp
 123ed08:	0f b7 9d 28 ff ff ff 	movzwl -0xd8(%rbp),%ebx
 123ed0f:	66 85 db             	test   %bx,%bx
 123ed12:	0f 85 ac 01 00 00    	jne    123eec4 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x8f4>
 123ed18:	48 8b 9d 18 ff ff ff 	mov    -0xe8(%rbp),%rbx
 123ed1f:	48 85 db             	test   %rbx,%rbx
 123ed22:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 123ed26:	0f 84 b7 00 00 00    	je     123ede3 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x813>
 123ed2c:	4c 89 f0             	mov    %r14,%rax
 123ed2f:	4c 8b b5 20 ff ff ff 	mov    -0xe0(%rbp),%r14
 123ed36:	48 85 d2             	test   %rdx,%rdx
 123ed39:	0f 84 1c fe ff ff    	je     123eb5b <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x58b>
 123ed3f:	48 8b 38             	mov    (%rax),%rdi
 123ed42:	48 8b 40 08          	mov    0x8(%rax),%rax
 123ed46:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ed4a:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 123ed4e:	e9 03 fe ff ff       	jmp    123eb56 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x586>
 123ed53:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 123ed57:	48 85 d2             	test   %rdx,%rdx
 123ed5a:	0f 84 b9 00 00 00    	je     123ee19 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x849>
 123ed60:	49 8b 3c 24          	mov    (%r12),%rdi
 123ed64:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 123ed69:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ed6d:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 123ed71:	31 c9                	xor    %ecx,%ecx
 123ed73:	e9 9e 00 00 00       	jmp    123ee16 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x846>
 123ed78:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 123ed7c:	48 85 d2             	test   %rdx,%rdx
 123ed7f:	74 18                	je     123ed99 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x7c9>
 123ed81:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123ed85:	48 8b 38             	mov    (%rax),%rdi
 123ed88:	48 8b 40 08          	mov    0x8(%rax),%rax
 123ed8c:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ed90:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 123ed94:	31 c9                	xor    %ecx,%ecx
 123ed96:	ff 50 18             	call   *0x18(%rax)
 123ed99:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 123ed9d:	66 44 89 60 10       	mov    %r12w,0x10(%rax)
 123eda2:	e9 f5 fe ff ff       	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>
 123eda7:	48 8b 9d 30 ff ff ff 	mov    -0xd0(%rbp),%rbx
 123edae:	48 85 db             	test   %rbx,%rbx
 123edb1:	4c 8b 7d c0          	mov    -0x40(%rbp),%r15
 123edb5:	74 70                	je     123ee27 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x857>
 123edb7:	48 8b 85 38 ff ff ff 	mov    -0xc8(%rbp),%rax
 123edbe:	48 89 45 b0          	mov    %rax,-0x50(%rbp)
 123edc2:	4d 85 e4             	test   %r12,%r12
 123edc5:	74 69                	je     123ee30 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x860>
 123edc7:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 123edcb:	49 8b 3e             	mov    (%r14),%rdi
 123edce:	49 8b 46 08          	mov    0x8(%r14),%rax
 123edd2:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123edd6:	4c 89 ee             	mov    %r13,%rsi
 123edd9:	4c 89 e2             	mov    %r12,%rdx
 123eddc:	31 c9                	xor    %ecx,%ecx
 123edde:	ff 50 18             	call   *0x18(%rax)
 123ede1:	eb 51                	jmp    123ee34 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x864>
 123ede3:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 123edea:	48 8b 45 b8          	mov    -0x48(%rbp),%rax
 123edee:	49 89 07             	mov    %rax,(%r15)
 123edf1:	49 89 57 08          	mov    %rdx,0x8(%r15)
 123edf5:	e9 a2 fe ff ff       	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>
 123edfa:	48 8b 5d 08          	mov    0x8(%rbp),%rbx
 123edfe:	4c 8b 7d c8          	mov    -0x38(%rbp),%r15
 123ee02:	49 8b 3f             	mov    (%r15),%rdi
 123ee05:	49 8b 47 08          	mov    0x8(%r15),%rax
 123ee09:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 123ee0d:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 123ee11:	31 c9                	xor    %ecx,%ecx
 123ee13:	49 89 d8             	mov    %rbx,%r8
 123ee16:	ff 50 18             	call   *0x18(%rax)
 123ee19:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 123ee1d:	66 44 89 70 10       	mov    %r14w,0x10(%rax)
 123ee22:	e9 75 fe ff ff       	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>
 123ee27:	4c 89 eb             	mov    %r13,%rbx
 123ee2a:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 123ee2e:	eb 08                	jmp    123ee38 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x868>
 123ee30:	4c 8b 75 c8          	mov    -0x38(%rbp),%r14
 123ee34:	4c 8b 65 b0          	mov    -0x50(%rbp),%r12
 123ee38:	49 8b 3e             	mov    (%r14),%rdi
 123ee3b:	49 8b 46 08          	mov    0x8(%r14),%rax
 123ee3f:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ee43:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 123ee47:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 123ee4b:	31 c9                	xor    %ecx,%ecx
 123ee4d:	ff 50 18             	call   *0x18(%rax)
 123ee50:	66 41 c7 47 10 00 00 	movw   $0x0,0x10(%r15)
 123ee57:	49 89 1f             	mov    %rbx,(%r15)
 123ee5a:	4d 89 67 08          	mov    %r12,0x8(%r15)
 123ee5e:	e9 39 fe ff ff       	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>
 123ee63:	66 89 43 10          	mov    %ax,0x10(%rbx)
 123ee67:	e9 30 fe ff ff       	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>
 123ee6c:	48 8b 55 b0          	mov    -0x50(%rbp),%rdx
 123ee70:	48 85 d2             	test   %rdx,%rdx
 123ee73:	4c 8b 75 c0          	mov    -0x40(%rbp),%r14
 123ee77:	74 16                	je     123ee8f <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x8bf>
 123ee79:	49 8b 3c 24          	mov    (%r12),%rdi
 123ee7d:	49 8b 44 24 08       	mov    0x8(%r12),%rax
 123ee82:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123ee86:	48 8b 75 a8          	mov    -0x58(%rbp),%rsi
 123ee8a:	31 c9                	xor    %ecx,%ecx
 123ee8c:	ff 50 18             	call   *0x18(%rax)
 123ee8f:	66 41 89 5e 10       	mov    %bx,0x10(%r14)
 123ee94:	e9 03 fe ff ff       	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>
 123ee99:	48 8b 4d c0          	mov    -0x40(%rbp),%rcx
 123ee9d:	66 89 41 10          	mov    %ax,0x10(%rcx)
 123eea1:	e9 f6 fd ff ff       	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>
 123eea6:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 123eeaa:	48 85 d2             	test   %rdx,%rdx
 123eead:	74 38                	je     123eee7 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x917>
 123eeaf:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123eeb3:	48 8b 38             	mov    (%rax),%rdi
 123eeb6:	48 8b 40 08          	mov    0x8(%rax),%rax
 123eeba:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123eebe:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 123eec2:	eb 1e                	jmp    123eee2 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x912>
 123eec4:	48 83 7d d0 00       	cmpq   $0x0,-0x30(%rbp)
 123eec9:	74 1c                	je     123eee7 <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x917>
 123eecb:	48 8b 45 c8          	mov    -0x38(%rbp),%rax
 123eecf:	48 8b 38             	mov    (%rax),%rdi
 123eed2:	48 8b 40 08          	mov    0x8(%rax),%rax
 123eed6:	4c 8b 45 08          	mov    0x8(%rbp),%r8
 123eeda:	48 8b 75 b8          	mov    -0x48(%rbp),%rsi
 123eede:	48 8b 55 d0          	mov    -0x30(%rbp),%rdx
 123eee2:	31 c9                	xor    %ecx,%ecx
 123eee4:	ff 50 18             	call   *0x18(%rax)
 123eee7:	48 8b 45 c0          	mov    -0x40(%rbp),%rax
 123eeeb:	66 89 58 10          	mov    %bx,0x10(%rax)
 123eeef:	e9 a8 fd ff ff       	jmp    123ec9c <br.encodeLazyCommandPlanAllocRecorded__anon_205492+0x6cc>

Disassembly of section .vort_br_dictionary_index:

Disassembly of section .vort_br_adaptive_split:

Disassembly of section .vort_br_distance_params:

Disassembly of section .vort_br_command_state:

Disassembly of section .vort_br_wide_lookup10_aux:

Disassembly of section .vort_br_paired_literal:

Disassembly of section .vort_br_wide_lookup9:
